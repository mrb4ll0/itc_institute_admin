// image_cache_service.dart
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'dart:typed_data';

class ImageCacheService {
  static final ImageCacheService _instance = ImageCacheService._internal();
  factory ImageCacheService() => _instance;
  ImageCacheService._internal();

  final Map<String, String> _cachedPaths = {};

  Future<String?> getCachedImagePath(String imageUrl) async {
    // Check memory cache first
    if (_cachedPaths.containsKey(imageUrl)) {
      return _cachedPaths[imageUrl];
    }

    // Check local file system
    final fileName = _getFileNameFromUrl(imageUrl);
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/chat_images/$fileName';
    final file = File(filePath);

    if (await file.exists()) {
      _cachedPaths[imageUrl] = filePath;
      return filePath;
    }

    return null;
  }

  Future<String> downloadAndCacheImage(String imageUrl) async {
    try {
      final fileName = _getFileNameFromUrl(imageUrl);
      final directory = await getApplicationDocumentsDirectory();
      final imageDir = Directory('${directory.path}/chat_images');

      if (!await imageDir.exists()) {
        await imageDir.create(recursive: true);
      }

      final filePath = '${imageDir.path}/$fileName';
      final file = File(filePath);

      if (await file.exists()) {
        _cachedPaths[imageUrl] = filePath;
        return filePath;
      }

      // Download image
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);
        _cachedPaths[imageUrl] = filePath;
        return filePath;
      }

      return imageUrl; // Fallback to network URL
    } catch (e) {
      debugPrint('Failed to cache image: $e');
      return imageUrl; // Fallback to network URL
    }
  }

  Future<void> precacheImageIfNeeded(String imageUrl) async {
    final cachedPath = await getCachedImagePath(imageUrl);
    if (cachedPath == null) {
      await downloadAndCacheImage(imageUrl);
    }
  }

  String _getFileNameFromUrl(String url) {
    // Create a unique filename from URL
    final bytes = url.codeUnits;
    final hash = bytes.fold(0, (prev, element) => (prev + element) % 1000000);
    final extension = url.contains('.jpg') ? '.jpg' :
    url.contains('.png') ? '.png' :
    url.contains('.jpeg') ? '.jpeg' : '.img';
    return 'img_$hash$extension';
  }
}