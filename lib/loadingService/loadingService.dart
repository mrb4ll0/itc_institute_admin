// loading_overlay.dart
import 'package:flutter/material.dart';

class LoadingOverlay {
  static OverlayEntry? _overlayEntry;
  static int _loadingCount = 0;

  static void show(BuildContext context, {String? message}) {
    _loadingCount++;

    if (_overlayEntry == null) {
      _overlayEntry = OverlayEntry(
        builder: (context) => _buildOverlay(message),
      );

      final overlay = Overlay.of(context);
      overlay.insert(_overlayEntry!);
    }
  }

  static void hide() {
    _loadingCount--;

    if (_loadingCount <= 0 && _overlayEntry != null) {
      _overlayEntry?.remove();
      _overlayEntry = null;
      _loadingCount = 0;
    }
  }

  static Widget _buildOverlay(String? message) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Material(
        color: Colors.transparent,
        child: Container(
          height: 3,
          color: Colors.transparent,
          child: LinearProgressIndicator(
            backgroundColor: Colors.transparent,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
          ),
        ),
      ),
    );
  }
}