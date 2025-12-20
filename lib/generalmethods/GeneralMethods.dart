import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class GeneralMethods {
  static String calculateDateDifferenceFromString(String? start, String? end) {
    if (start == null || start.isEmpty || end == null || end.isEmpty) {
      return 'Not set';
    }

    try {
      final startDate = DateTime.parse(start);
      final endDate = DateTime.parse(end);

      // Swap if startDate is after endDate
      DateTime s = startDate;
      DateTime e = endDate;
      if (s.isAfter(e)) {
        final temp = s;
        s = e;
        e = temp;
      }

      final difference = e.difference(s).inDays;

      if (difference == 0) return '0 days';
      if (difference == 1) return '1 day';
      return '$difference days';
    } catch (e) {
      // Parsing failed
      return 'Not set';
    }
  }

  static Widget _buildInitialsAvatar(String username, double radius) {
    // Generate initials avatar
    String initials = '';
    final parts = username.trim().split(' ');
    if (parts.isNotEmpty) {
      initials = parts.length == 1
          ? parts[0][0]
          : (parts[0][0] + (parts.length > 1 ? parts[1][0] : ''));
    }
    initials = initials.toUpperCase();

    // Generate a consistent color from username
    final hash = username.codeUnits.fold(0, (prev, element) => prev + element);
    final rng = Random(hash);
    final bgColor = Color.fromARGB(
      255,
      100 + rng.nextInt(156),
      100 + rng.nextInt(156),
      100 + rng.nextInt(156),
    );

    return CircleAvatar(
      radius: radius,
      backgroundColor: bgColor,
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.8,
        ),
      ),
    );
  }

  static Widget generateUserAvatar({
    required String username,
    String? imageUrl,
    double radius = 30,
  }) {
    // If image URL is provided, try to load it
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey[200], // Fallback background
        child: ClipOval(
          child: Image.network(
            imageUrl,
            fit: BoxFit.cover,
            width: radius * 2,
            height: radius * 2,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              // On error, display the initials avatar
              return _buildInitialsAvatar(username, radius);
            },
          ),
        ),
      );
    }

    // Otherwise, generate initials avatar directly
    return _buildInitialsAvatar(username, radius);
  }

  static void showMessageDialog(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.blueAccent, // noticeable color
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.info_outline, color: Colors.white, size: 36),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    Future.delayed(duration, () {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });
  }

  static void navigateTo(context, widget) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => widget));
  }

  static void replaceNavigationTo(context, widget) {
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (context) => widget));
  }

  Future<void> _launchUrl(context, String url) async {
    try {
      // Check if it's a Firebase Storage URL
      if (url.contains('firebasestorage.googleapis.com')) {
        // For Firebase Storage URLs, we need to handle them differently
        await _handleFirebaseStorageUrl(context, url);
      } else if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch URL';
      }
    } catch (e) {
      // Show a snackbar or dialog with download option
      await _showDownloadDialog(context, url);
    }
  }

  Future<void> _handleFirebaseStorageUrl(context, String url) async {
    // Option 1: Try to launch with default browser
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }

    // Option 2: Show download dialog
    await _showDownloadDialog(context, url);
  }

  Future<void> _showDownloadDialog(BuildContext context, String url) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Open Document'),
        content: const Text('Choose how you want to view this document:'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          // Open in browser
          TextButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await launchUrl(
                Uri.parse(url),
                mode: LaunchMode.externalApplication,
              );
            },
            icon: const Icon(Icons.public),
            label: const Text('Open in Browser'),
          ),
          // Copy link
          TextButton.icon(
            onPressed: () {
              Navigator.pop(context);
              Clipboard.setData(ClipboardData(text: url));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Link copied to clipboard')),
              );
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copy Link'),
          ),
        ],
      ),
    );
  }

  // Quick show loading
  static void showLoading(
    BuildContext context, {
    String message = 'Loading...',
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
              if (message.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(message, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Quick hide loading
  static void hideLoading(BuildContext context) {
    Navigator.of(context, rootNavigator: true).pop();
  }

  // Show loading during async operation
  static Future<T> showLoadingWhile<T>(
    BuildContext context,
    Future<T> future, {
    String message = 'Loading...',
  }) async {
    showLoading(context, message: message);
    try {
      final result = await future;
      hideLoading(context);
      return result;
    } catch (e) {
      hideLoading(context);
      rethrow;
    }
  }

  static int calculateSlot(String intake, String applicationCount) {
    try {
      // Convert strings to integers
      final intakeInt = int.tryParse(intake);
      final applicationCountInt = int.tryParse(applicationCount);

      // Check if conversion was successful
      if (intakeInt == null || applicationCountInt == null) {
        return 0;
      }

      // Calculate available slots
      final result = intakeInt - applicationCountInt;

      // Ensure result is not negative
      return result >= 0 ? result : 0;
    } catch (e) {
      // Log error for debugging
      debugPrint('Error calculating slot: $e');
      return 0;
    }
  }

  /// Extracts a clean filename from a Firebase Storage URL
  static String getFileNameFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      String fileName = uri.pathSegments.last;

      fileName = Uri.decodeComponent(fileName);

      // Remove query parameters if any
      if (fileName.contains('?')) {
        fileName = fileName.split('?').first;
      }

      return fileName;
    } catch (e) {
      // Fallback: return timestamp if something goes wrong
      return DateTime.now().millisecondsSinceEpoch.toString();
    }
  }

  /// Fixes invalid Firebase Storage URLs and converts them to valid download URLs.
  /// Works even if the stored URL is badly formatted.
  static String fixFirebaseStorageUrl(String url) {
    if (url.isEmpty) return url;

    String fixed = url.trim();

    // --- 1. Fix wrong domain ".firebasestorage.app" → ".appspot.com" ---
    if (fixed.contains('firebasestorage.app')) {
      fixed = fixed.replaceAll('firebasestorage.app', 'appspot.com');
    }

    // --- 2. Fix incorrectly encoded "%2F" segments ---
    fixed = fixed.replaceAll('%2F', '/');

    // --- 3. Ensure the URL is using the Firebase Storage REST format ---
    if (!fixed.contains('alt=media')) {
      if (fixed.contains('?')) {
        fixed = '$fixed&alt=media';
      } else {
        fixed = '$fixed?alt=media';
      }
    }

    return fixed;
  }

  static String getFileTypeFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final path = uri.path.toLowerCase();

      // Common image formats
      final imageExtensions = [
        '.jpg',
        '.jpeg',
        '.png',
        '.gif',
        '.bmp',
        '.webp',
        '.svg',
        '.ico',
        '.tiff',
        '.tif',
      ];

      // Common document formats
      final documentExtensions = [
        '.pdf',
        '.doc',
        '.docx',
        '.txt',
        '.rtf',
        '.odt',
      ];

      // Common spreadsheet formats
      final spreadsheetExtensions = ['.xls', '.xlsx', '.csv', '.ods'];

      // Common presentation formats
      final presentationExtensions = ['.ppt', '.pptx', '.odp'];

      // Common audio formats
      final audioExtensions = [
        '.mp3',
        '.wav',
        '.aac',
        '.ogg',
        '.flac',
        '.m4a',
        '.wma',
      ];

      // Common video formats
      final videoExtensions = [
        '.mp4',
        '.avi',
        '.mov',
        '.wmv',
        '.flv',
        '.mkv',
        '.webm',
        '.m4v',
      ];

      // Archive formats
      final archiveExtensions = ['.zip', '.rar', '.7z', '.tar', '.gz'];

      // Check each category
      for (final ext in imageExtensions) {
        if (path.endsWith(ext)) return 'image';
      }

      for (final ext in documentExtensions) {
        if (path.endsWith(ext)) return 'document';
      }

      for (final ext in spreadsheetExtensions) {
        if (path.endsWith(ext)) return 'spreadsheet';
      }

      for (final ext in presentationExtensions) {
        if (path.endsWith(ext)) return 'presentation';
      }

      for (final ext in audioExtensions) {
        if (path.endsWith(ext)) return 'audio';
      }

      for (final ext in videoExtensions) {
        if (path.endsWith(ext)) return 'video';
      }

      for (final ext in archiveExtensions) {
        if (path.endsWith(ext)) return 'archive';
      }

      // Check specific file types
      if (path.endsWith('.pdf')) return 'pdf';
      if (path.endsWith('.exe') ||
          path.endsWith('.apk') ||
          path.endsWith('.dmg'))
        return 'executable';
      if (path.endsWith('.html') || path.endsWith('.htm')) return 'webpage';

      return 'unknown';
    } catch (e) {
      debugPrint("Error parsing file type from URL: $e");
      return 'unknown';
    }
  }

  static String normalizeApplicationStatus(String status) {
    final lowerStatus = status.toLowerCase().trim();

    switch (lowerStatus) {
      case 'accept':
      case 'accepted':
      case 'approved':
        return 'accepted';
      case 'reject':
      case 'rejected':
      case 'declined':
      case 'denied':
        return 'rejected';
      case 'pend':
      case 'pending':
      case 'review':
      case 'under review':
      case 'processing':
      case 'in progress':
      case 'applied':
        return 'pending';
      default:
        return 'pending'; // Default fallback
    }
  }
  static String getUniqueHeroTag() {
    return 'fab_${DateTime.now().millisecondsSinceEpoch}_${Random()}';
  }

}
