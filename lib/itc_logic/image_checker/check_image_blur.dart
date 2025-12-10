
import 'dart:io';

import 'package:blur_detection/blur_detection.dart';
import 'package:file_picker/file_picker.dart';

Future<bool> checkImageBlur(PlatformFile pickedFile) async {
  if (pickedFile.path == null) return true; // Treat as blurred if path is null
  final file = File(pickedFile.path!);
  return await BlurDetectionService.isImageBlurred(file);
}