import 'dart:io';
import 'dart:typed_data';

import 'package:blur_detection/blur_detection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_document_scanner/flutter_document_scanner.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;

class DocumentScannerService {
  /// Scans a document, converts it to PDF, and returns the local file path.
  Future<String?> scanAndExportToPdf(BuildContext context) async {
    try {
      final controller = DocumentScannerController();

      Uint8List? scannedImageBytes;

      // Navigate to a new screen to display the scanner
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(title: Text('Scan Document')),
            body: DocumentScanner(
              controller: controller,
              onSave: (Uint8List imageBytes) {
                scannedImageBytes = imageBytes;
                Navigator.of(context).pop();
              },
            ),
          ),
        ),
      );

      if (scannedImageBytes == null) return null;

      // TEMP save the scanned image to a file for blur detection
      final tempDir = await getTemporaryDirectory();
      final tempImageFile = File('${tempDir.path}/temp_scan.png');
      await tempImageFile.writeAsBytes(scannedImageBytes!);

      // Check blur
      final isBlurred = await BlurDetectionService.isImageBlurred(
        tempImageFile,
      );
      if (isBlurred) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("The scanned image is blurry. Please scan again."),
            backgroundColor: Colors.red,
          ),
        );
        return null; // You can also show a dialog here
      }

      // Convert scanned image to PDF

      final pdf = pw.Document();
      final image = pw.MemoryImage(scannedImageBytes!);

      pdf.addPage(
        pw.Page(build: (context) => pw.Center(child: pw.Image(image))),
      );

      // Save the PDF file locally
      final dir = await getApplicationDocumentsDirectory();
      final pdfFile = File(
        '${dir.path}/scanned_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      await pdfFile.writeAsBytes(await pdf.save());

      return pdfFile.path;
    } catch (e) {
      print('Error scanning or generating PDF: $e');
      return null;
    }
  }
}
