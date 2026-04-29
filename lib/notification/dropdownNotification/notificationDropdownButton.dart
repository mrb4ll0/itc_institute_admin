// notification_dropdown_button.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notificationDropDownService.dart';
import 'notificationDropdown.dart';

class NotificationDropdownButton extends StatefulWidget {
  final String companyId;

  const NotificationDropdownButton({
    Key? key,
    required this.companyId,
  }) : super(key: key);

  @override
  State<NotificationDropdownButton> createState() => _NotificationDropdownButtonState();
}

class _NotificationDropdownButtonState extends State<NotificationDropdownButton>
    with TickerProviderStateMixin {
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();
  bool _isDropdownOpen = false;
  bool _isDropdownVisible = true;
  int _notificationCount = 0;

  // Animation controllers for bell dancing
  late AnimationController _bellController;
  late AnimationController _pulseController;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();

    // Listen to notification count
    NotificationDropdownService().unreadCountStream.listen((count) {
      if (mounted) {
        setState(() {
          _notificationCount = count;
        });
        // Animate bell when new notification arrives
        if (count > 0) {
          _startBellDance();
        }
      }
    });

    // Listen to dropdown trigger from service (new notifications)
    NotificationDropdownService().showDropdownStream.listen((show) {
      if (show && mounted && !_isDropdownOpen) {
        _showDropdown();
      }
    });

    // Initialize animation controllers
    _bellController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _bellController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _isAnimating = false;
        });
      }
    });
  }

  void _startBellDance() {
    if (_isAnimating) return;
    setState(() {
      _isAnimating = true;
    });
    _bellController.reset();
    _bellController.forward();

    // Start pulsing for unread notifications
    if (_notificationCount > 0 && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (_notificationCount == 0 && _pulseController.isAnimating) {
      _pulseController.stop();
    }
  }

  void _toggleDropdown() {
    if (_isDropdownOpen) {
      _hideDropdown();
    } else {
      _showDropdown();
    }
  }

  void _showDropdown() {
    if (_isDropdownOpen) return;
    _isDropdownOpen = true;
    _isDropdownVisible = true;

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Background tap to close
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _hideDropdown,
              child: Container(color: Colors.transparent),
            ),
          ),
          // Dropdown content
          Positioned(
            child: CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: const Offset(-270, 50),
              child: NotificationDropdownWidget(
                companyId: widget.companyId,
                onDismiss: _hideDropdown,
                onToggle: _handleToggleVisibility,
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    NotificationDropdownService().markDropdownAsShown();
  }

  void _handleToggleVisibility() {
    setState(() {
      _isDropdownVisible = !_isDropdownVisible;
    });

    if (!_isDropdownVisible) {
      _hideDropdown();
    }
  }

  void _hideDropdown() {
    if (!_isDropdownOpen) return;
    _isDropdownOpen = false;
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _bellController.dispose();
    _pulseController.dispose();
    _hideDropdown();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasUnread = _notificationCount > 0;

    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onTap: _toggleDropdown,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Animated Bell Icon
            AnimatedBuilder(
              animation: Listenable.merge([_bellController, _pulseController]),
              builder: (context, child) {
                final tapProgress = _bellController.value;
                final pulseProgress = _pulseController.value;
                final isTapping = _bellController.isAnimating;

                double angle;
                double scale;

                if (isTapping) {
                  // Dancing animation for new notifications
                  angle = sin(tapProgress * 20) * (1 - tapProgress) * 1.2;
                  scale = 1.0 + (1 - tapProgress) * 0.4 * sin(tapProgress * 15).abs();
                } else if (hasUnread && _pulseController.isAnimating) {
                  // Continuous gentle sway for unread notifications
                  angle = sin(pulseProgress * 6 * 3.14159) * 0.25;
                  scale = 1.0 + sin(pulseProgress * 6 * 3.14159).abs() * 0.1;
                } else {
                  angle = 0;
                  scale = 1.0;
                }

                return Transform.rotate(
                  angle: angle,
                  child: Transform.scale(
                    scale: scale,
                    child: IconButton(
                      icon: Icon(
                        Icons.notifications_none_outlined,
                        color: isDark ? Colors.white : Colors.blueGrey[800],
                        size: 24,
                      ),
                      onPressed: _toggleDropdown,
                    ),
                  ),
                );
              },
            ),
            // Badge - Show number for 2+, red dot for 1 unread
            if (_notificationCount > 0)
              Positioned(
                top: 4,
                right: 4,
                child: _notificationCount == 1
                    ? Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                )
                    : Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    _notificationCount > 99 ? '99+' : '$_notificationCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            // Pulsing ring effect for unread notifications (only for 1+)
            if (hasUnread && _pulseController.isAnimating)
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final pulseValue = _pulseController.value;
                  final ringScale = 1 + pulseValue * 0.3;
                  final ringOpacity = (1 - pulseValue) * 0.5;

                  return Positioned(
                    top: 8,
                    right: 8,
                    child: IgnorePointer(
                      child: Container(
                        width: 20,
                        height: 20,
                        child: Transform.scale(
                          scale: ringScale,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.red.withOpacity(ringOpacity),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}