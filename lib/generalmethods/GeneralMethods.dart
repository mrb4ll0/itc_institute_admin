import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
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

    //debugPrint("imageUrl is $imageUrl");
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

  static bool isImageUrl(String url) {
    final imageExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'];
    return imageExtensions.any((ext) => url.toLowerCase().contains(ext));
  }

  static bool contentIsOnlyImageUrl(String content, List<String> images) {
    if (content.isEmpty) return false;

    // Check if content is exactly one of the image URLs
    if (images.contains(content)) return true;

    // Check if content looks like an image URL
    if (isImageUrl(content)) {
      // Check if it's similar to our image URLs (Firebase Storage URLs often have query params)
      return images.any((imageUrl) =>
      content.contains(imageUrl.split('?').first) ||
          imageUrl.contains(content.split('?').first));
    }

    return false;
  }

 static DateTime? parseDate(dynamic value) {
    if (value == null) return null;

    try {
      // Direct DateTime
      if (value is DateTime) return value;

      // Firestore Timestamp
      if (value is Timestamp) return value.toDate();

      // Firestore timestamp as Map
      if (value is Map<String, dynamic>) {
        if (value.containsKey('_seconds')) {
          final seconds = value['_seconds'] as int? ?? 0;
          final nanoseconds = value['_nanoseconds'] as int? ?? 0;
          return DateTime.fromMillisecondsSinceEpoch(
            seconds * 1000 + (nanoseconds ~/ 1000000),
          );
        }
      }

      // Numeric timestamp
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      if (value is double) return DateTime.fromMillisecondsSinceEpoch(value.toInt());

      // String - try ISO 8601 first
      if (value is String) {
        if (value.isEmpty) return null;

        // Try ISO 8601
        try {
          return DateTime.parse(value);
        } catch (_) {
          // Try numeric string
          final milliseconds = int.tryParse(value);
          if (milliseconds != null) {
            return DateTime.fromMillisecondsSinceEpoch(milliseconds);
          }
          return null;
        }
      }

      return null;
    } catch (e) {
      debugPrint('Date parsing error: $e');
      return null;
    }
  }


  static String? parseDateToString(dynamic value, {String format = 'dd-MM-yyyy'}) {
    if (value == null) return null;

    try {
      DateTime? dateTime;

      // Direct DateTime
      if (value is DateTime) {
        dateTime = value;
      }
      // Firestore Timestamp
      else if (value is Timestamp) {
        dateTime = value.toDate();
      }
      // Firestore timestamp as Map
      else if (value is Map<String, dynamic>) {
        if (value.containsKey('_seconds')) {
          final seconds = value['_seconds'] as int? ?? 0;
          final nanoseconds = value['_nanoseconds'] as int? ?? 0;
          dateTime = DateTime.fromMillisecondsSinceEpoch(
            seconds * 1000 + (nanoseconds ~/ 1000000),
          );
        }
      }
      // Numeric timestamp
      else if (value is int) {
        dateTime = DateTime.fromMillisecondsSinceEpoch(value);
      }
      else if (value is double) {
        dateTime = DateTime.fromMillisecondsSinceEpoch(value.toInt());
      }
      // String - try ISO 8601 first
      else if (value is String) {
        if (value.isEmpty) return null;

        // Try ISO 8601
        try {
          dateTime = DateTime.parse(value);
        } catch (_) {
          // Try numeric string
          final milliseconds = int.tryParse(value);
          if (milliseconds != null) {
            dateTime = DateTime.fromMillisecondsSinceEpoch(milliseconds);
          }
        }
      }

      // If we successfully parsed a DateTime, format it using intl
      if (dateTime != null) {
        final formatter = DateFormat(format);
        return formatter.format(dateTime);
      }

      return null;
    } catch (e) {
      debugPrint('Date parsing error: $e');
      return null;
    }
  }

  static String? parseDateTimeToString(dynamic value, {String format = 'dd-MM-yyyy hh:mm:ss a'}) {
    if (value == null) return null;

    try {
      DateTime? dateTime;

      // Direct DateTime
      if (value is DateTime) {
        dateTime = value;
      }
      // Firestore Timestamp
      else if (value is Timestamp) {
        dateTime = value.toDate();
      }
      // Firestore timestamp as Map
      else if (value is Map<String, dynamic>) {
        if (value.containsKey('_seconds')) {
          final seconds = value['_seconds'] as int? ?? 0;
          final nanoseconds = value['_nanoseconds'] as int? ?? 0;
          dateTime = DateTime.fromMillisecondsSinceEpoch(
            seconds * 1000 + (nanoseconds ~/ 1000000),
          );
        }
      }
      // Numeric timestamp
      else if (value is int) {
        dateTime = DateTime.fromMillisecondsSinceEpoch(value);
      }
      else if (value is double) {
        dateTime = DateTime.fromMillisecondsSinceEpoch(value.toInt());
      }
      // String - try ISO 8601 first
      else if (value is String) {
        if (value.isEmpty) return null;

        // Try ISO 8601
        try {
          dateTime = DateTime.parse(value);
        } catch (_) {
          // Try numeric string
          final milliseconds = int.tryParse(value);
          if (milliseconds != null) {
            dateTime = DateTime.fromMillisecondsSinceEpoch(milliseconds);
          }
        }
      }

      // If we successfully parsed a DateTime, format it using intl
      if (dateTime != null) {
        final formatter = DateFormat(format);
        return formatter.format(dateTime);
      }

      return null;
    } catch (e) {
      debugPrint('Date parsing error: $e');
      return null;
    }
  }

  static bool isSmallScreen(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width < 600;
  }

  /// Method 2: Check if screen is medium (typically tablets)
  static bool isMediumScreen(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= 600 && width < 1200;
  }

  /// Method 3: Check if screen is large (typically desktops)
  static bool isLargeScreen(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= 1200;
  }

  /// Method 4: Get screen dimensions as a tuple/map
  static Map<String, double> getScreenDimensions(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;
    final viewInsets = MediaQuery.of(context).viewInsets;

    return {
      'width': size.width,
      'height': size.height,
      'availableHeight': size.height - padding.top - padding.bottom - viewInsets.bottom,
      'availableWidth': size.width - padding.left - padding.right,
      'statusBarHeight': padding.top,
      'bottomBarHeight': padding.bottom,
    };
  }

  /// Method 5: Get responsive value based on screen size
  static T responsiveValue<T>({
    required BuildContext context,
    required T small,
    T? medium,
    T? large,
  }) {
    if (isLargeScreen(context) && large != null) {
      return large;
    } else if (isMediumScreen(context) && medium != null) {
      return medium;
    } else {
      return small;
    }
  }

  /// Method 6: Get screen width
  static double getScreenWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  /// Method 7: Get screen height
  static double getScreenHeight(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }

  /// Method 8: Get available screen height (accounting for keyboard and system bars)
  static double getAvailableHeight(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;
    final viewInsets = MediaQuery.of(context).viewInsets;
    return size.height - padding.top - padding.bottom - viewInsets.bottom;
  }

  /// Method 9: Get screen size category as string
  static String getScreenSizeCategory(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (width < 360) {
      return 'Very Small Phone';
    } else if (width < 600) {
      return 'Phone';
    } else if (width < 900) {
      return 'Small Tablet';
    } else if (width < 1200) {
      return 'Large Tablet';
    } else if (width < 1600) {
      return 'Desktop';
    } else {
      return 'Large Desktop';
    }
  }


  // Add these methods to your GeneralMethods class

// ==================== DIALOG METHODS ====================

  /// Show success dialog
  static void showSuccessDialog(
      BuildContext context,
      String message, {
        String title = 'Success',
        VoidCallback? onOkPressed,
        Duration autoDismissDuration = const Duration(seconds: 2),
        bool autoDismiss = true,
      }) {
    _showStyledDialog(
      context: context,
      title: title,
      message: message,
      icon: Icons.check_circle,
      iconColor: Colors.green,
      backgroundColor: Colors.white,
      onOkPressed: onOkPressed,
      autoDismiss: autoDismiss,
      autoDismissDuration: autoDismissDuration,
    );
  }

  /// Show error dialog
  static void showErrorDialog(
      BuildContext context,
      String message, {
        String title = 'Error',
        VoidCallback? onOkPressed,
        Duration autoDismissDuration = const Duration(seconds: 3),
        bool autoDismiss = false,
      }) {
    _showStyledDialog(
      context: context,
      title: title,
      message: message,
      icon: Icons.error,
      iconColor: Colors.red,
      backgroundColor: Colors.white,
      onOkPressed: onOkPressed,
      autoDismiss: autoDismiss,
      autoDismissDuration: autoDismissDuration,
    );
  }

  /// Show warning dialog
  static void showWarningDialog(
      BuildContext context,
      String message, {
        String title = 'Warning',
        VoidCallback? onOkPressed,
        VoidCallback? onCancelPressed,
        Duration autoDismissDuration = const Duration(seconds: 3),
        bool autoDismiss = false,
      }) {
    _showStyledDialog(
      context: context,
      title: title,
      message: message,
      icon: Icons.warning,
      iconColor: Colors.orange,
      backgroundColor: Colors.white,
      onOkPressed: onOkPressed,
      onCancelPressed: onCancelPressed,
      autoDismiss: autoDismiss,
      autoDismissDuration: autoDismissDuration,
    );
  }

  /// Show info dialog
  static void showInfoDialog(
      BuildContext context,
      String message, {
        String title = 'Information',
        VoidCallback? onOkPressed,
        Duration autoDismissDuration = const Duration(seconds: 2),
        bool autoDismiss = true,
      }) {
    _showStyledDialog(
      context: context,
      title: title,
      message: message,
      icon: Icons.info,
      iconColor: Colors.blue,
      backgroundColor: Colors.white,
      onOkPressed: onOkPressed,
      autoDismiss: autoDismiss,
      autoDismissDuration: autoDismissDuration,
    );
  }

  /// Show confirmation dialog (Yes/No)
  static Future<bool?> showConfirmationDialog(
      BuildContext context,
      String message, {
        String title = 'Confirm',
        String confirmText = 'Yes',
        String cancelText = 'No',
        IconData? icon,
        Color confirmColor = Colors.red,
        Color cancelColor = Colors.grey,
      }) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: confirmColor, size: 28),
                const SizedBox(width: 12),
              ],
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(foregroundColor: cancelColor),
              child: Text(cancelText),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: confirmColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(confirmText),
            ),
          ],
        );
      },
    );
  }

  /// Show loading dialog with custom message
  static void showLoadingDialog(
      BuildContext context, {
        String message = 'Loading...',
        bool barrierDismissible = false,
      }) {
    showDialog(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (BuildContext context) {
        return PopScope(
          canPop: !barrierDismissible,
          child: Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      message,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Show custom dialog with actions
  static Future<T?> showCustomDialog<T>({
    required BuildContext context,
    required String title,
    required String message,
    String? positiveButtonText,
    VoidCallback? onPositivePressed,
    String? negativeButtonText,
    VoidCallback? onNegativePressed,
    String? neutralButtonText,
    VoidCallback? onNeutralPressed,
    IconData? icon,
    Color? iconColor,
    bool barrierDismissible = true,
    List<Widget>? additionalContent,
  }) async {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: iconColor ?? Colors.blue, size: 28),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message, style: const TextStyle(fontSize: 16)),
              if (additionalContent != null) ...additionalContent,
            ],
          ),
          actions: [
            if (negativeButtonText != null)
              TextButton(
                onPressed: () {
                  if (onNegativePressed != null) {
                    onNegativePressed();
                  } else {
                    Navigator.of(context).pop();
                  }
                },
                child: Text(negativeButtonText),
              ),
            if (neutralButtonText != null)
              TextButton(
                onPressed: () {
                  if (onNeutralPressed != null) {
                    onNeutralPressed();
                  } else {
                    Navigator.of(context).pop();
                  }
                },
                child: Text(neutralButtonText),
              ),
            if (positiveButtonText != null)
              ElevatedButton(
                onPressed: () {
                  if (onPositivePressed != null) {
                    onPositivePressed();
                  } else {
                    Navigator.of(context).pop();
                  }
                },
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(positiveButtonText),
              ),
          ],
        );
      },
    );
  }

  /// Show violation/warning dialog (for form validation, policy violations, etc.)
  static void showViolationDialog(
      BuildContext context,
      String message, {
        String title = 'Violation',
        String? violationType, // e.g., 'Password Policy', 'Terms & Conditions', etc.
        VoidCallback? onOkPressed,
        VoidCallback? onViewDetails,
      }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(Icons.gavel, color: Colors.red, size: 28),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Violation',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (violationType != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    violationType,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Text(
                message,
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
          actions: [
            if (onViewDetails != null)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  onViewDetails();
                },
                style: TextButton.styleFrom(foregroundColor: Colors.blue),
                child: const Text('View Details'),
              ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                if (onOkPressed != null) onOkPressed();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  /// Show snackbar (lightweight alternative to dialog)
  static void showSnackBar(
      BuildContext context,
      String message, {
        Duration duration = const Duration(seconds: 3),
        Color? backgroundColor,
        IconData? icon,
      }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        duration: duration,
        backgroundColor: backgroundColor ?? Colors.black87,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  /// Show success snackbar
  static void showSuccessSnackBar(BuildContext context, String message) {
    showSnackBar(
      context,
      message,
      backgroundColor: Colors.green,
      icon: Icons.check_circle,
    );
  }

  /// Show error snackbar
  static void showErrorSnackBar(BuildContext context, String message) {
    showSnackBar(
      context,
      message,
      backgroundColor: Colors.red,
      icon: Icons.error,
    );
  }

  /// Show warning snackbar
  static void showWarningSnackBar(BuildContext context, String message) {
    showSnackBar(
      context,
      message,
      backgroundColor: Colors.orange,
      icon: Icons.warning,
    );
  }

  /// Show info snackbar
  static void showInfoSnackBar(BuildContext context, String message) {
    showSnackBar(
      context,
      message,
      backgroundColor: Colors.blue,
      icon: Icons.info,
    );
  }

  /// Show bottom sheet dialog
  static Future<T?> showBottomSheetDialog<T>(
      BuildContext context, {
        required Widget child,
        String? title,
        bool isDismissible = true,
        double initialChildSize = 0.5,
        double minChildSize = 0.25,
        double maxChildSize = 0.9,
      }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      isDismissible: isDismissible,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: initialChildSize,
          minChildSize: minChildSize,
          maxChildSize: maxChildSize,
          builder: (_, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  if (title != null) ...[
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Divider(height: 24),
                  ],
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      child: child,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

// ==================== PRIVATE HELPER METHOD ====================

  /// Private method to show styled dialog (used by success, error, warning, info)
  static void _showStyledDialog({
    required BuildContext context,
    required String title,
    required String message,
    required IconData icon,
    required Color iconColor,
    required Color backgroundColor,
    VoidCallback? onOkPressed,
    VoidCallback? onCancelPressed,
    bool autoDismiss = false,
    Duration autoDismissDuration = const Duration(seconds: 2),
  }) {
    showDialog(
      context: context,
      barrierDismissible: autoDismiss,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: backgroundColor,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (onCancelPressed != null) ...[
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          onCancelPressed();
                        },
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                    ],
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        if (onOkPressed != null) onOkPressed();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: iconColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (autoDismiss) {
      Future.delayed(autoDismissDuration, () {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
    }
  }

  // Simple permanent lock dialog using your existing error dialog
  static void showPermanentLockDialog({
    required BuildContext context,
    required String reason,
  }) {
    showErrorDialog(
      context,
      'Your account has been permanently locked.\n\nReason: $reason\n\nPlease contact support for assistance.',
      title: 'Account Locked',
    );
  }

// Simple temporary lock dialog using your existing warning dialog
  static void showTemporaryLockDialog({
    required BuildContext context,
    required String reason,
    required int remainingSeconds,
  }) {
    final hours = remainingSeconds ~/ 3600;
    final minutes = (remainingSeconds % 3600) ~/ 60;
    final seconds = remainingSeconds % 60;

    String timeText;
    if (hours > 0) {
      timeText = '$hours hour${hours > 1 ? 's' : ''}';
    } else if (minutes > 0) {
      timeText = '$minutes minute${minutes > 1 ? 's' : ''}';
    } else {
      timeText = '$seconds second${seconds > 1 ? 's' : ''}';
    }

    showWarningDialog(
      context,
      'Your account has been temporarily locked.\n\nReason: $reason\n\nTime remaining: $timeText\n\nPlease try again later.',
      title: 'Account Locked',
    );
  }

  /// Format duration into human-readable time remaining
  /// Examples:
  /// - 1 day, 5 hours
  /// - 3 hours, 30 minutes
  /// - 45 minutes, 20 seconds
  /// - 30 seconds
  static String formatTimeRemaining(Duration duration) {
    if (duration.isNegative) return "0 seconds";

    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    if (days > 0) {
      if (hours > 0) {
        return "$days day${days > 1 ? 's' : ''}, $hours hour${hours > 1 ? 's' : ''}";
      }
      return "$days day${days > 1 ? 's' : ''}";
    }

    if (hours > 0) {
      if (minutes > 0) {
        return "$hours hour${hours > 1 ? 's' : ''}, $minutes minute${minutes > 1 ? 's' : ''}";
      }
      return "$hours hour${hours > 1 ? 's' : ''}";
    }

    if (minutes > 0) {
      if (seconds > 0) {
        return "$minutes minute${minutes > 1 ? 's' : ''}, $seconds second${seconds > 1 ? 's' : ''}";
      }
      return "$minutes minute${minutes > 1 ? 's' : ''}";
    }

    return "$seconds second${seconds != 1 ? 's' : ''}";
  }

  /// Format seconds directly
  static String formatSecondsRemaining(int seconds) {
    if (seconds <= 0) return "0 seconds";
    return formatTimeRemaining(Duration(seconds: seconds));
  }

  /// Get remaining seconds safely (ensures non-negative)
  static int getRemainingSeconds(int seconds) {
    return seconds > 0 ? seconds : 0;
  }

  /// Get remaining seconds from DateTime
  static int getRemainingSecondsFromDateTime(DateTime? expiryTime) {
    if (expiryTime == null) return 0;
    final seconds = expiryTime.difference(DateTime.now()).inSeconds;
    return seconds > 0 ? seconds : 0;
  }

  /// Get remaining seconds from dynamic type (DateTime, String, Timestamp, or int)
  static int getRemainingSecondsSafe(dynamic value) {
    if (value == null) return 0;

    // If already an int
    if (value is int) {
      return value > 0 ? value : 0;
    }

    // If DateTime
    if (value is DateTime) {
      final seconds = value.difference(DateTime.now()).inSeconds;
      return seconds > 0 ? seconds : 0;
    }

    // If String
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) {
        final seconds = parsed.difference(DateTime.now()).inSeconds;
        return seconds > 0 ? seconds : 0;
      }
    }

    // If Firebase Timestamp
    if (value is Timestamp) {
      final seconds = value.toDate().difference(DateTime.now()).inSeconds;
      return seconds > 0 ? seconds : 0;
    }

    return 0;
  }
}

