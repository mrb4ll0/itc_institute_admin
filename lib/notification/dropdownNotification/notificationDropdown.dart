// notificationDropdown.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';
import '../../itc_logic/firebase/company_cloud.dart';
import '../../itc_logic/idservice/globalIdService.dart';
import '../../model/localNotification.dart';
import '../view/NotificationPage.dart';

class NotificationDropdownWidget extends StatefulWidget {
  final String companyId;
  final VoidCallback onDismiss;
  final VoidCallback onToggle;

  const NotificationDropdownWidget({
    Key? key,
    required this.companyId,
    required this.onDismiss,
    required this.onToggle,
  }) : super(key: key);

  @override
  State<NotificationDropdownWidget> createState() => _NotificationDropdownWidgetState();
}

class _NotificationDropdownWidgetState extends State<NotificationDropdownWidget> {
  bool _isExpanded = false;
  bool _isVisible = true;
  final Company_Cloud _companyCloud = Company_Cloud(GlobalIdService.firestoreId);

  void _toggleVisibility() {
    setState(() {
      _isVisible = !_isVisible;
    });
    widget.onToggle();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    if (!_isVisible) {
      return const SizedBox.shrink();
    }

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 360,
        constraints: BoxConstraints(
          maxHeight: _isExpanded ? 480 : 380,
        ),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: colorScheme.outline.withOpacity(0.1),
                  ),
                ),
              ),
              child: Row(
                children: [
                  // Toggle visibility button
                  Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.keyboard_arrow_up,
                        size: 18,
                        color: colorScheme.onSurface,
                      ),
                      onPressed: _toggleVisibility,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      tooltip: 'Hide dropdown',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.notifications_none,
                    size: 20,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Notifications',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  // Expand/Collapse button
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isExpanded = !_isExpanded;
                      });
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      _isExpanded ? 'Show less' : 'Show more',
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Close button
                  IconButton(
                    icon: Icon(Icons.close, size: 18),
                    onPressed: widget.onDismiss,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    color: colorScheme.onSurface.withOpacity(0.5),
                  ),
                ],
              ),
            ),

            // Notifications List
            Flexible(
              child: StreamBuilder<List<CompanyNotification>>(
                stream: _companyCloud.getCompanyNotificationsStream(widget.companyId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildLoadingState();
                  }

                  if (snapshot.hasError) {
                    return _buildErrorState(snapshot.error.toString());
                  }

                  final notifications = snapshot.data ?? [];

                  if (notifications.isEmpty) {
                    return _buildEmptyState();
                  }

                  // Sort: unread first, then by date
                  notifications.sort((a, b) {
                    if (a.isRead != b.isRead) {
                      return a.isRead ? 1 : -1;
                    }
                    return b.createdAt.compareTo(a.createdAt);
                  });

                  // Limit based on expanded state
                  int maxItems = _isExpanded ? 5 : 3;
                  final displayNotifications = notifications.take(maxItems).toList();

                  // Count unread for badge
                  final unreadCount = notifications.where((n) => !n.isRead).length;

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Unread count header
                      if (unreadCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: colorScheme.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '$unreadCount unread notification${unreadCount > 1 ? 's' : ''}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: displayNotifications.length,
                        separatorBuilder: (context, index) => Divider(
                          height: 0.5,
                          color: colorScheme.outline.withOpacity(0.1),
                        ),
                        itemBuilder: (context, index) {
                          final notification = displayNotifications[index];
                          return _buildNotificationItem(notification);
                        },
                      ),
                    ],
                  );
                },
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: colorScheme.outline.withOpacity(0.1),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: _markAllAsRead,
                    style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Mark all read',
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      widget.onDismiss();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CompanyNotificationsPage(
                            companyId: widget.companyId,
                          ),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'View all',
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationItem(CompanyNotification notification) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: () => _onNotificationTap(notification),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: !notification.isRead
              ? colorScheme.primary.withOpacity(0.05)
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _getNotificationColor(notification.type, colorScheme).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getNotificationIcon(notification.type),
                size: 18,
                color: _getNotificationColor(notification.type, colorScheme),
              ),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: !notification.isRead ? FontWeight.w700 : FontWeight.w500,
                            color: colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (notification.isImportant)
                        Icon(
                          Icons.star_rounded,
                          color: Colors.amber,
                          size: 12,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.message,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.6),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTimeAgo(notification.createdAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.4),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            // Unread indicator
            if (!notification.isRead)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(left: 8),
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Loading notifications...',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 32,
            color: colorScheme.error,
          ),
          const SizedBox(height: 8),
          Text(
            'Error loading notifications',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none_rounded,
            size: 48,
            color: colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 12),
          Text(
            'No notifications',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  // Helper Methods
  Color _getNotificationColor(NotificationType type, ColorScheme colorScheme) {
    switch (type) {
      case NotificationType.newApplication:
        return Colors.green;
      case NotificationType.applicationUpdate:
        return Colors.blue;
      case NotificationType.studentMessage:
        return Colors.purple;
      case NotificationType.studentDocument:
        return Colors.orange;
      case NotificationType.systemAlert:
        return Colors.red;
      case NotificationType.payment:
        return Colors.teal;
      case NotificationType.reminder:
        return Colors.amber;
      default:
        return colorScheme.primary;
    }
  }

  IconData _getNotificationIcon(NotificationType type) {
    switch (type) {
      case NotificationType.newApplication:
        return Icons.person_add_alt_1_rounded;
      case NotificationType.applicationUpdate:
        return Icons.update_rounded;
      case NotificationType.studentMessage:
        return Icons.message_rounded;
      case NotificationType.studentDocument:
        return Icons.description_rounded;
      case NotificationType.systemAlert:
        return Icons.warning_amber_rounded;
      case NotificationType.payment:
        return Icons.payments_rounded;
      case NotificationType.reminder:
        return Icons.notifications_active_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 30) {
      return DateFormat('MMM d').format(date);
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  // Actions
  Future<void> _markAllAsRead() async {
    try {
      await _companyCloud.markAllNotificationsAsRead(widget.companyId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('All notifications marked as read'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error marking all as read: $e');
    }
  }

  void _onNotificationTap(CompanyNotification notification) async {
    // Mark as read if not already
    if (!notification.isRead) {
      await _companyCloud.markNotificationAsRead(widget.companyId, notification.id);
    }

    // Dismiss dropdown
    widget.onDismiss();

    // Navigate to full notifications page
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CompanyNotificationsPage(
          companyId: widget.companyId,
        ),
      ),
    );
  }
}