import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

class FirebaseUploader {
  final FirebaseStorage storage = FirebaseStorage.instance;

  Future<String?> uploadFile(File file, String userId, String category) async {
    try {
      final originalName = path.basename(file.path);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${timestamp}_$originalName';

      // Human-readable path
      final readablePath = 'uploads/$userId/$category/$fileName';
      final ref = storage.ref().child(readablePath);

      final uploadTask = ref.putFile(file);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e, stackTrace) {
      debugPrint('Error uploading file: $e');
      debugPrint('$stackTrace');
      return null;
    }
  }

  /// Upload multiple local files in bulk to a single category in Firebase Storage.
  /// This method runs all uploads in parallel for better performance.
  /// Returns a list of download URLs for successfully uploaded files.
  Future<List<String>> uploadMultipleFiles(
    List<File> files,
    String userId,
    String category,
  ) async {
    try {
      // Map each file to an upload task (a Future)
      final uploadTasks = files
          .map((file) => uploadFile(file, userId, category))
          .toList();

      // Wait for all the upload tasks to complete
      final results = await Future.wait(uploadTasks);

      // Filter out any nulls from failed uploads and return the list of URLs
      final downloadUrls = results.whereType<String>().toList();

      return downloadUrls;
    } catch (e, stackTrace) {
      debugPrint('Error uploading multiple files: $e');
      debugPrint('$stackTrace');
      return []; // Return an empty list if a critical error occurs
    }
  }

  /// Upload multiple files, each to its own specified category.
  ///
  /// This is useful for application processes where you have different types of
  /// documents (e.g., ID card, IT letter) that need to be stored in separate
  /// folders in Firebase Storage.
  ///
  /// Takes a map where keys are the category names (e.g., 'id_cards') and
  /// values are the list of files for that category.
  ///
  /// Returns a map with the same category keys, but with values being a list
  /// of the download URLs for the uploaded files.
  Future<Map<String, List<String>>> uploadCategorizedFiles(
    String userId,
    Map<String, List<File>> filesByCategory,
  ) async {
    final Map<String, List<String>> uploadedUrls = {};

    try {
      // Iterate over each category and its corresponding files
      for (final entry in filesByCategory.entries) {
        final category = entry.key;
        final files = entry.value;

        if (files.isNotEmpty) {
          // Use the existing 'uploadMultipleFiles' to handle the batch upload for the current category.
          // This is efficient as it uploads all files for a single category in parallel.
          final downloadUrls = await uploadMultipleFiles(
            files,
            userId,
            category,
          );
          uploadedUrls[category] = downloadUrls;
        }
      }
      return uploadedUrls;
    } catch (e, stackTrace) {
      debugPrint('Error uploading categorized files: $e');
      debugPrint('$stackTrace');
      // Return the map of what was successfully uploaded before the error
      return uploadedUrls;
    }
  }

  /// Upload from a public file URL by downloading and then uploading
  Future<String?> uploadFromUrl(String fileUrl) async {
    try {
      final httpClient = HttpClient();
      final request = await httpClient.getUrl(Uri.parse(fileUrl));
      final response = await request.close();

      if (response.statusCode == 200) {
        final bytes = await consolidateHttpClientResponseBytes(response);
        final fileName = path.basename(fileUrl);
        final ref = storage.ref().child('uploads/$fileName');

        final uploadTask = ref.putData(bytes);
        final snapshot = await uploadTask.whenComplete(() {});
        final downloadUrl = await snapshot.ref.getDownloadURL();
        return downloadUrl;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  /// Delete a file from Firebase Storage
  Future<bool> deleteFile(String fileUrl) async {
    try {
      final ref = storage.refFromURL(fileUrl);
      await ref.delete();
      return true;
    } catch (e) {
      return false;
    }
  }
}
