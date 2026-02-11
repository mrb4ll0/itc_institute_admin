import 'dart:io';
import 'dart:isolate';
import 'package:itc_institute_admin/generalmethods/GeneralMethods.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';

import 'package:intl/intl.dart';

// models/acceptance_letter_data.dart
import 'package:intl/intl.dart';

import '../firebase_cloud_storage/firebase_cloud.dart';

class AcceptanceLetterData {
  final String id;
  final String studentName;
  final String studentId;
  final String institutionName;
  final String institutionAddress;
  final String institutionPhone;
  final String institutionEmail;
  final String authorityName;
  final String companyName;
  final String companyAddress;
  final DateTime startDate;
  final DateTime endDate;
  final String authorizedSignatoryName;
  final String authorizedSignatoryPosition;
  final DateTime createdAt;

  // New fields for Firestore storage
  final String? internshipId;
  final String? internshipTitle;
  final String? companyId;
  final String? applicationId;
  final String? fileUrl;
  final String? status; // 'draft', 'sent', 'accepted', 'rejected', 'withdrawn'
  final DateTime? sentAt;
  final DateTime? acceptedAt;
  final DateTime? rejectedAt;
  final DateTime? updatedAt;
  final String? reason; // For rejection/withdrawal
  final bool? isAuthorityGenerated;

  AcceptanceLetterData({
    required this.id,
    required this.studentName,
    required this.studentId,
    required this.institutionName,
    required this.institutionAddress,
    required this.institutionPhone,
    required this.institutionEmail,
    required this.authorityName,
    required this.companyName,
    required this.companyAddress,
    required this.startDate,
    required this.endDate,
    required this.authorizedSignatoryName,
    required this.authorizedSignatoryPosition,
    DateTime? createdAt,

    // New optional fields
    this.internshipId,
    this.internshipTitle,
    this.companyId,
    this.applicationId,
    this.fileUrl,
    this.status = 'draft',
    this.sentAt,
    this.acceptedAt,
    this.rejectedAt,
    this.updatedAt,
    this.reason,
    this.isAuthorityGenerated = true,
  }) : createdAt = createdAt ?? DateTime.now();

  // Named constructor with defaults
  factory AcceptanceLetterData.create({
    required String studentName,
    required String studentId,
    required String companyName,
    String? id,
    String? institutionName,
    String? institutionAddress,
    String? institutionPhone,
    String? institutionEmail,
    String? authorityName,
    String? companyAddress,
    DateTime? startDate,
    DateTime? endDate,
    String? authorizedSignatoryName,
    String? authorizedSignatoryPosition,

    // New optional parameters
    String? internshipId,
    String? internshipTitle,
    String? companyId,
    String? applicationId,
    String? fileUrl,
    String? status,
    bool? isAuthorityGenerated,
  }) {
    return AcceptanceLetterData(
      id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      studentName: studentName,
      studentId: studentId,
      institutionName: institutionName ?? '',
      institutionAddress: institutionAddress ?? '',
      institutionPhone: institutionPhone ?? '',
      institutionEmail: institutionEmail ?? '',
      authorityName: authorityName ?? '',
      companyName: companyName,
      companyAddress: companyAddress ?? '',
      startDate: startDate ?? DateTime.now().add(const Duration(days: 30)),
      endDate: endDate ?? DateTime.now().add(const Duration(days: 210)),
      authorizedSignatoryName: authorizedSignatoryName ?? '',
      authorizedSignatoryPosition: authorizedSignatoryPosition ?? '',

      // New fields
      internshipId: internshipId,
      internshipTitle: internshipTitle,
      companyId: companyId,
      applicationId: applicationId,
      fileUrl: fileUrl,
      status: status ?? 'draft',
      isAuthorityGenerated: isAuthorityGenerated ?? true,
    );
  }

  // Convert to map for Firebase/Firestore
  Map<String, dynamic> toMap() {
    return {
      // Original fields
      'id': id,
      'studentName': studentName,
      'studentId': studentId,
      'institutionName': institutionName,
      'institutionAddress': institutionAddress,
      'institutionPhone': institutionPhone,
      'institutionEmail': institutionEmail,
      'authorityName': authorityName,
      'companyName': companyName,
      'companyAddress': companyAddress,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'authorizedSignatoryName': authorizedSignatoryName,
      'authorizedSignatoryPosition': authorizedSignatoryPosition,
      'createdAt': createdAt.toIso8601String(),

      // New fields for Firestore
      'internshipId': internshipId,
      'internshipTitle': internshipTitle,
      'companyId': companyId,
      'applicationId': applicationId,
      'fileUrl': fileUrl ?? '',
      'status': status ?? 'draft',
      'sentAt': sentAt?.toIso8601String(),
      'acceptedAt': acceptedAt?.toIso8601String(),
      'rejectedAt': rejectedAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'reason': reason ?? '',
      'isAuthorityGenerated': isAuthorityGenerated ?? true,
    };
  }

  // Create from map
  factory AcceptanceLetterData.fromMap(Map<String, dynamic> map) {
    return AcceptanceLetterData(
      id: map['id'] ?? '',
      studentName: map['studentName'] ?? '',
      studentId: map['studentId'] ?? '',
      institutionName: map['institutionName'] ?? '',
      institutionAddress: map['institutionAddress'] ?? '',
      institutionPhone: map['institutionPhone'] ?? '',
      institutionEmail: map['institutionEmail'] ?? '',
      authorityName: map['authorityName'] ?? '',
      companyName: map['companyName'] ?? '',
      companyAddress: map['companyAddress'] ?? '',
      startDate: DateTime.parse(map['startDate']),
      endDate: DateTime.parse(map['endDate']),
      authorizedSignatoryName: map['authorizedSignatoryName'] ?? '',
      authorizedSignatoryPosition: map['authorizedSignatoryPosition'] ?? '',

      // Parse dates if they exist
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt']) : DateTime.now(),

      // New fields
      internshipId: map['internshipId'],
      internshipTitle: map['internshipTitle'],
      companyId: map['companyId'],
      applicationId: map['applicationId'],
      fileUrl: map['fileUrl'],
      status: map['status'] ?? 'draft',
      sentAt: GeneralMethods.parseDate(map['sentAt']),
      acceptedAt: GeneralMethods.parseDate(map['acceptedAt']) ,
      rejectedAt: GeneralMethods.parseDate(map['rejectedAt']) ,
      updatedAt: GeneralMethods.parseDate(map['updatedAt']) ,
      reason: map['reason'],
      isAuthorityGenerated: map['isAuthorityGenerated'] ?? true,
    );
  }

  // Copy with method for updates
  AcceptanceLetterData copyWith({
    String? id,
    String? studentName,
    String? studentId,
    String? institutionName,
    String? institutionAddress,
    String? institutionPhone,
    String? institutionEmail,
    String? authorityName,
    String? companyName,
    String? companyAddress,
    DateTime? startDate,
    DateTime? endDate,
    String? authorizedSignatoryName,
    String? authorizedSignatoryPosition,
    DateTime? createdAt,

    // New fields
    String? internshipId,
    String? internshipTitle,
    String? companyId,
    String? applicationId,
    String? fileUrl,
    String? status,
    DateTime? sentAt,
    DateTime? acceptedAt,
    DateTime? rejectedAt,
    DateTime? updatedAt,
    String? reason,
    bool? isAuthorityGenerated,
  }) {
    return AcceptanceLetterData(
      id: id ?? this.id,
      studentName: studentName ?? this.studentName,
      studentId: studentId ?? this.studentId,
      institutionName: institutionName ?? this.institutionName,
      institutionAddress: institutionAddress ?? this.institutionAddress,
      institutionPhone: institutionPhone ?? this.institutionPhone,
      institutionEmail: institutionEmail ?? this.institutionEmail,
      authorityName: authorityName ?? this.authorityName,
      companyName: companyName ?? this.companyName,
      companyAddress: companyAddress ?? this.companyAddress,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      authorizedSignatoryName: authorizedSignatoryName ?? this.authorizedSignatoryName,
      authorizedSignatoryPosition: authorizedSignatoryPosition ?? this.authorizedSignatoryPosition,
      createdAt: createdAt ?? this.createdAt,

      // New fields
      internshipId: internshipId ?? this.internshipId,
      internshipTitle: internshipTitle ?? this.internshipTitle,
      companyId: companyId ?? this.companyId,
      applicationId: applicationId ?? this.applicationId,
      fileUrl: fileUrl ?? this.fileUrl,
      status: status ?? this.status,
      sentAt: sentAt ?? this.sentAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      rejectedAt: rejectedAt ?? this.rejectedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      reason: reason ?? this.reason,
      isAuthorityGenerated: isAuthorityGenerated ?? this.isAuthorityGenerated,
    );
  }

  // Getters for formatted data
  String get durationText {
    final durationInDays = endDate.difference(startDate).inDays;
    return durationInDays >= 30
        ? '${(durationInDays / 30).floor()} months'
        : '$durationInDays days';
  }

  String get formattedCurrentDate => DateFormat('dd MMMM yyyy').format(DateTime.now());
  String get formattedStartDate => DateFormat('dd MMMM yyyy').format(startDate);
  String get formattedEndDate => DateFormat('dd MMMM yyyy').format(endDate);

  // Helper methods for status
  bool get isDraft => status == 'draft';
  bool get isSent => status == 'sent';
  bool get isAccepted => status == 'accepted';
  bool get isRejected => status == 'rejected';
  bool get isWithdrawn => status == 'withdrawn';

  String get statusDisplayText {
    switch (status) {
      case 'draft':
        return 'Draft';
      case 'sent':
        return 'Sent';
      case 'accepted':
        return 'Accepted';
      case 'rejected':
        return 'Rejected';
      case 'withdrawn':
        return 'Withdrawn';
      default:
        return 'Unknown';
    }
  }
}



Future<String> generateAcceptancePdf(AcceptanceLetterData data,String tempPath) async {
  final pdf = pw.Document();


  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(50),
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header with Institution Info
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text(
                    data.authorityName,
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    data.institutionAddress,
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                  pw.Text(
                    '${data.institutionPhone} | ${data.institutionEmail}',
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 30),

            // Date
            pw.Text(
              'Date: ${data.formattedCurrentDate}',
              style: const pw.TextStyle(fontSize: 12),
            ),

            pw.SizedBox(height: 20),

            // Recipient Address
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'To:',
                  style:  pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  'The Manager / HR Department',
                  style: const pw.TextStyle(fontSize: 12),
                ),
                pw.Text(
                  data.companyName,
                  style: const pw.TextStyle(fontSize: 12),
                ),
                if (data.companyAddress.isNotEmpty)
                  pw.Text(
                    data.companyAddress,
                    style: const pw.TextStyle(fontSize: 12),
                  ),
              ],
            ),

            pw.SizedBox(height: 20),

            // Subject
            pw.Text(
              'Subject: Introduction and Confirmation of Industrial Training Placement for ${data.studentName}',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.indigo,
              ),
            ),

            pw.SizedBox(height: 20),

            // Salutation
            pw.Text(
              'Dear Sir/Madam,',
              style: const pw.TextStyle(fontSize: 12),
            ),

            pw.SizedBox(height: 15),

            // Body Content - Paragraph 1
            pw.Paragraph(
              text: 'We write to formally introduce and confirm the placement of ${data.studentName}, Registration Number ${data.studentId}, a student of ${data.institutionName} at . This student has been approved and cleared by ${data.authorityName} to undertake the mandatory Industrial Training program at your esteemed organization.',
              style: const pw.TextStyle(fontSize: 12, lineSpacing: 1.5),
            ),

            pw.SizedBox(height: 10),

            // Body Content - Paragraph 2
            pw.Paragraph(
              text: 'The training is scheduled to commence on ${data.formattedStartDate} and conclude on ${data.formattedEndDate}, spanning a period of ${data.durationText}. The objective is to provide the student with practical, hands-on experience relevant to their academic discipline.',
              style: const pw.TextStyle(fontSize: 12, lineSpacing: 1.5),
            ),

            pw.SizedBox(height: 10),

            // Body Content - Paragraph 3
            pw.Paragraph(
              text: 'We kindly request that you grant ${data.studentName} the opportunity to complete this training under your supervision and guidance. The student has been instructed to present this letter to you as official confirmation of their approved status and readiness to begin.',
              style: const pw.TextStyle(fontSize: 12, lineSpacing: 1.5),
            ),

            pw.SizedBox(height: 10),

            // Body Content - Paragraph 4
            pw.Paragraph(
              text: 'We are confident that the student will be a diligent and valuable addition to your team during this period. Should you require any further verification or wish to discuss the training arrangement, please contact us at ${data.institutionEmail} or ${data.institutionPhone}.',
              style: const pw.TextStyle(fontSize: 12, lineSpacing: 1.5),
            ),

            pw.SizedBox(height: 10),

            // Body Content - Paragraph 5
            pw.Paragraph(
              text: 'Thank you for your continued partnership in shaping the future of our students. We appreciate your support and look forward to a fruitful collaboration.',
              style: const pw.TextStyle(fontSize: 12, lineSpacing: 1.5),
            ),

            pw.SizedBox(height: 30),

            // Closing and Signature
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Yours faithfully,',
                  style: const pw.TextStyle(fontSize: 12),
                ),

                pw.SizedBox(height: 40),

                // Signature Line
                pw.Text(
                  '__________________________',
                  style: const pw.TextStyle(fontSize: 12),
                ),
                pw.Text(
                  data.authorizedSignatoryName,
                  style:  pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  data.authorizedSignatoryPosition,
                  style: const pw.TextStyle(fontSize: 12),
                ),
                pw.Text(
                  data.authorityName,
                  style: const pw.TextStyle(fontSize: 12),
                ),
              ],
            ),

            pw.SizedBox(height: 20),

            // CC Note
            pw.Text(
              'CC: ${data.studentName}',
              style:  pw.TextStyle(fontSize: 11, fontStyle: pw.FontStyle.italic),
            ),
            pw.Text(
              '(For Student\'s Records and Presentation to Company)',
              style:  pw.TextStyle(fontSize: 11, fontStyle: pw.FontStyle.italic),
            ),
          ],
        );
      },
    ),
  );

  final filePath = "$tempPath/acceptance_letter_${data.studentId}_${DateTime.now().millisecondsSinceEpoch}.pdf";
  final file = File(filePath);
  await file.writeAsBytes(await pdf.save());

  return filePath;
}




Future<String> runPdfGeneration(AcceptanceLetterData data, {
  required String userId,
}) async {
  final dir = await getTemporaryDirectory();
  final tempPath = dir.path;

  // Generate PDF in isolate
  final pdfPath = await Isolate.run(() {
    // Call a modified version of generateAcceptancePdf that accepts tempPath
    return generateAcceptancePdf(data, tempPath);
  });


  // Create File object
  final pdfFile = File(pdfPath);

  // Upload to Firebase using your uploader
  final uploader = FirebaseUploader();
  final pdfUrl = await uploader.uploadFile(
    pdfFile,
    userId,
    'acceptance_letters',
  );

  // Delete local file after upload
  await pdfFile.delete();

  // Return the Firebase URL
  return pdfUrl ??"";
}


