import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../itc_logic/firebase/company_cloud.dart';
import '../../model/localNotification.dart';


class CompanyNotificationsPage extends StatefulWidget {
  final String companyId;

  const CompanyNotificationsPage({
    Key? key,
    required this.companyId,
  }) : super(key: key);

  @override
  State<CompanyNotificationsPage> createState() => _CompanyNotificationsPageState();
}

class _CompanyNotificationsPageState extends State<CompanyNotificationsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Company_Cloud _companyCloud = Company_Cloud(FirebaseAuth.instance.currentUser!.uid);
  final ScrollController _scrollController = ScrollController();
  bool _showFAB = true;
  String _selectedFilter = 'all';

  final List<String> _filters = [
    'all',
    'unread',
    'applications',
    'students',
    'system',
    'reminders'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _scrollController.addListener(() {
      if (_scrollController.position.userScrollDirection == ScrollDirection.reverse) {
        if (_showFAB) setState(() => _showFAB = false);
      } else if (_scrollController.position.userScrollDirection == ScrollDirection.forward) {
        if (!_showFAB) setState(() => _showFAB = true);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: NestedScrollView(
        controller: _scrollController,
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            // Header
            SliverAppBar(
              pinned: true,
              floating: true,
              snap: true,
              expandedHeight: 160,
              backgroundColor: colorScheme.surface,
              elevation: 0,
              leading: IconButton(
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: colorScheme.onSurface,
                ),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                IconButton(

                  icon: Icon(
                    Icons.more_vert_rounded,
                    color: colorScheme.onSurface,
                  ),
                  onPressed: null,//_showSettingsMenu,
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        colorScheme.primary.withOpacity(0.15),
                        colorScheme.surface,
                      ],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: 24,
                      right: 24,
                      bottom: 16,
                      top: 80,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Notifications',
                          style: textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Stay updated with all company activities',
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Filter Chips
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              sliver: SliverToBoxAdapter(
                child: SizedBox(
                  height: 48,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _filters.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final filter = _filters[index];
                      final isSelected = _selectedFilter == filter;
                      return FilterChip(
                        label: Text(
                          _getFilterLabel(filter),
                          style: TextStyle(
                            color: isSelected ? Colors.white : colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _selectedFilter = selected ? filter : 'all';
                          });
                        },
                        backgroundColor: colorScheme.surfaceVariant,
                        selectedColor: colorScheme.primary,
                        checkmarkColor: Colors.white,
                        shape: StadiumBorder(
                          side: BorderSide(
                            color: isSelected ? Colors.transparent : colorScheme.outline.withOpacity(0.2),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

            // Tabs
            SliverPersistentHeader(
              pinned: true,
              delegate: _StickyTabBarDelegate(
                child: Container(
                  color: colorScheme.surface,
                  child: TabBar(
                    controller: _tabController,
                    labelColor: colorScheme.primary,
                    unselectedLabelColor: colorScheme.onSurface.withOpacity(0.5),
                    indicatorColor: colorScheme.primary,
                    indicatorWeight: 3,
                    indicatorPadding: const EdgeInsets.symmetric(horizontal: 8),
                    labelStyle: textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    tabs: const [
                      Tab(text: 'All'),
                      Tab(text: 'Unread'),
                      Tab(text: 'Important'),
                    ],
                  ),
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildNotificationsList('all'),
            _buildNotificationsList('unread'),
            _buildNotificationsList('important'),
          ],
        ),
      ),
      floatingActionButton: _showFAB
          ? FloatingActionButton.extended(
        onPressed: _markAllAsRead,
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        icon: const Icon(Icons.done_all_rounded),
        label: const Text('Mark All Read'),
      )
          : null,
    );
  }

  Widget _buildNotificationsList(String tabType) {
    return StreamBuilder<List<CompanyNotification>>(
      stream: _companyCloud.getCompanyNotificationsStream(widget.companyId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }

        if (snapshot.hasError) {
          return _buildErrorState(snapshot.error.toString());
        }

        final notifications = snapshot.data ?? [];

        // Apply filters
        List<CompanyNotification> filteredNotifications = _filterNotifications(notifications, tabType);

        if (filteredNotifications.isEmpty) {
          return _buildEmptyState(tabType);
        }

        return RefreshIndicator(
          onRefresh: () async {
            // Force refresh if needed
            setState(() {});
          },
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: filteredNotifications.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              return _buildNotificationItem(filteredNotifications[index]);
            },
          ),
        );
      },
    );
  }

  List<CompanyNotification> _filterNotifications(
      List<CompanyNotification> notifications,
      String tabType,
      ) {
    List<CompanyNotification> filtered = notifications;

    // Apply tab filter
    switch (tabType) {
      case 'unread':
        filtered = filtered.where((n) => !n.isRead).toList();
        break;
      case 'important':
        filtered = filtered.where((n) => n.isImportant).toList();
        break;
    }

    // Apply category filter
    if (_selectedFilter != 'all') {
      filtered = filtered.where((n) {
        switch (_selectedFilter) {
          case 'applications':
            return n.type == NotificationType.newApplication ||
                n.type == NotificationType.applicationUpdate;
          case 'students':
            return n.type == NotificationType.studentMessage ||
                n.type == NotificationType.studentDocument;
          case 'system':
            return n.type == NotificationType.systemAlert ||
                n.type == NotificationType.payment;
          case 'reminders':
            return n.type == NotificationType.reminder;
          case 'unread':
            return !n.isRead;
          default:
            return true;
        }
      }).toList();
    }

    // Sort by date (newest first)
    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return filtered;
  }

  Widget _buildNotificationItem(CompanyNotification notification) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: colorScheme.error,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(
          Icons.delete_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
      confirmDismiss: (direction) async {
        return await _showDeleteConfirmation(notification);
      },
      onDismissed: (direction) {
        _companyCloud.deleteNotification(widget.companyId, notification.id);
      },
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _onNotificationTap(notification),
          onLongPress: () => _showNotificationOptions(notification),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: notification.isRead
                  ? colorScheme.surfaceVariant.withOpacity(0.3)
                  : colorScheme.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: notification.isRead
                    ? colorScheme.outline.withOpacity(0.1)
                    : colorScheme.primary.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _getNotificationColor(notification.type, colorScheme),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getNotificationIcon(notification.type),
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: notification.isRead
                                    ? FontWeight.w600
                                    : FontWeight.w800,
                                color: colorScheme.onSurface,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (notification.isImportant)
                            Icon(
                              Icons.star_rounded,
                              color: Colors.amber,
                              size: 16,
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.message,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.7),
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getNotificationColor(
                                notification.type,
                                colorScheme,
                              ).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _getNotificationTypeLabel(notification.type),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: _getNotificationColor(
                                  notification.type,
                                  colorScheme,
                                ),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            _formatTimeAgo(notification.createdAt),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurface.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Unread indicator
                if (!notification.isRead)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildErrorState(String error) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: colorScheme.error,
            ),
            const SizedBox(height: 24),
            Text(
              'Unable to load notifications',
              style: theme.textTheme.titleLarge?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              error,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => setState(() {}),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String tabType) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    String title;
    String message;
    IconData icon;

    switch (tabType) {
      case 'unread':
        title = 'No Unread Notifications';
        message = 'You\'re all caught up!';
        icon = Icons.done_all_rounded;
        break;
      case 'important':
        title = 'No Important Notifications';
        message = 'No important notifications at the moment';
        icon = Icons.star_outline_rounded;
        break;
      default:
        title = 'No Notifications';
        message = 'Notifications will appear here';
        icon = Icons.notifications_none_rounded;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 72,
              color: colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.6),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.4),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Helper Methods

  String _getFilterLabel(String filter) {
    switch (filter) {
      case 'all': return 'All';
      case 'unread': return 'Unread';
      case 'applications': return 'Applications';
      case 'students': return 'Students';
      case 'system': return 'System';
      case 'reminders': return 'Reminders';
      default: return filter;
    }
  }

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

  String _getNotificationTypeLabel(NotificationType type) {
    switch (type) {
      case NotificationType.newApplication:
        return 'New Application';
      case NotificationType.applicationUpdate:
        return 'Application Update';
      case NotificationType.studentMessage:
        return 'Student Message';
      case NotificationType.studentDocument:
        return 'Document';
      case NotificationType.systemAlert:
        return 'System Alert';
      case NotificationType.payment:
        return 'Payment';
      case NotificationType.reminder:
        return 'Reminder';
      default:
        return 'Notification';
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

  // Action Methods

  Future<void> _markAllAsRead() async {
    try {
      await _companyCloud.markAllNotificationsAsRead(widget.companyId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('All notifications marked as read'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  void _onNotificationTap(CompanyNotification notification) async {
    // Mark as read
    if (!notification.isRead) {
      await _companyCloud.markNotificationAsRead(
        widget.companyId,
        notification.id,
      );
    }

    // Navigate based on notification type
    switch (notification.type) {
      case NotificationType.newApplication:
      case NotificationType.applicationUpdate:
      // Navigate to application details
        break;
      case NotificationType.studentMessage:
      // Navigate to chat
        break;
      case NotificationType.studentDocument:
      // Open document
        break;
      default:
      // Show notification details
        _showNotificationDetails(notification);
    }
  }

  void _showNotificationDetails(CompanyNotification notification) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => NotificationDetailSheet(
        notification: notification,
        companyId: widget.companyId,
        companyCloud: _companyCloud,
      ),
    );
  }

  Future<void> _showNotificationOptions(CompanyNotification notification) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => NotificationOptionsSheet(
        notification: notification,
      ),
    );

    if (result != null) {
      switch (result) {
        case 'mark_read':
          await _companyCloud.markNotificationAsRead(
            widget.companyId,
            notification.id,
          );
          break;
        case 'mark_unread':
          await _companyCloud.markNotificationAsUnread(
            widget.companyId,
            notification.id,
          );
          break;
        case 'important':
          await _companyCloud.toggleNotificationImportant(
            widget.companyId,
            notification.id,
            !notification.isImportant,
          );
          break;
        case 'delete':
          await _companyCloud.deleteNotification(
            widget.companyId,
            notification.id,
          );
          break;
      }
    }
  }

  Future<bool?> _showDeleteConfirmation(CompanyNotification notification) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Notification'),
        content: Text(
          'Are you sure you want to delete "${notification.title}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showSettingsMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => NotificationSettingsSheet(
        companyId: widget.companyId,
        companyCloud: _companyCloud,
      ),
    );
  }
}

// Sticky Tab Bar Delegate
class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _StickyTabBarDelegate({required this.child});

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  double get maxExtent => 48;

  @override
  double get minExtent => 48;

  @override
  bool shouldRebuild(_StickyTabBarDelegate oldDelegate) {
    return child != oldDelegate.child;
  }
}

// Notification Detail Sheet
class NotificationDetailSheet extends StatelessWidget {
  final CompanyNotification notification;
  final String companyId;
  final Company_Cloud companyCloud;

  const NotificationDetailSheet({
    Key? key,
    required this.notification,
    required this.companyId,
    required this.companyCloud,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.onSurface.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: _getNotificationColor(notification.type, colorScheme),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        _getNotificationIcon(notification.type),
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            notification.title,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            DateFormat('MMM d, yyyy • h:mm a').format(notification.createdAt),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Text(
                  'Details',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  notification.message,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.8),
                    height: 1.6,
                  ),
                ),
                if (notification.data.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Additional Information',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...notification.data.entries.map((entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${entry.key}: ',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            entry.value.toString(),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ),
                    if (!notification.isRead)
                      const SizedBox(width: 12),
                    if (!notification.isRead)
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            companyCloud.markNotificationAsRead(companyId, notification.id);
                            Navigator.pop(context);
                          },
                          child: const Text('Mark as Read'),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getNotificationColor(NotificationType type, ColorScheme colorScheme) {
    switch (type) {
      case NotificationType.newApplication: return Colors.green;
      case NotificationType.applicationUpdate: return Colors.blue;
      case NotificationType.studentMessage: return Colors.purple;
      case NotificationType.studentDocument: return Colors.orange;
      case NotificationType.systemAlert: return Colors.red;
      case NotificationType.payment: return Colors.teal;
      case NotificationType.reminder: return Colors.amber;
      default: return colorScheme.primary;
    }
  }

  IconData _getNotificationIcon(NotificationType type) {
    switch (type) {
      case NotificationType.newApplication: return Icons.person_add_alt_1_rounded;
      case NotificationType.applicationUpdate: return Icons.update_rounded;
      case NotificationType.studentMessage: return Icons.message_rounded;
      case NotificationType.studentDocument: return Icons.description_rounded;
      case NotificationType.systemAlert: return Icons.warning_amber_rounded;
      case NotificationType.payment: return Icons.payments_rounded;
      case NotificationType.reminder: return Icons.notifications_active_rounded;
      default: return Icons.notifications_rounded;
    }
  }
}

// Notification Options Sheet
class NotificationOptionsSheet extends StatelessWidget {
  final CompanyNotification notification;

  const NotificationOptionsSheet({
    Key? key,
    required this.notification,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Notification Options',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 20),
          _buildOptionItem(
            context,
            icon: notification.isRead
                ? Icons.mark_email_unread_rounded
                : Icons.mark_email_read_rounded,
            title: notification.isRead ? 'Mark as Unread' : 'Mark as Read',
            value: notification.isRead ? 'mark_unread' : 'mark_read',
          ),
          _buildOptionItem(
            context,
            icon: notification.isImportant
                ? Icons.star_outline_rounded
                : Icons.star_rounded,
            title: notification.isImportant ? 'Remove Important' : 'Mark Important',
            value: 'important',
          ),
          _buildOptionItem(
            context,
            icon: Icons.delete_outline_rounded,
            title: 'Delete Notification',
            value: 'delete',
            color: colorScheme.error,
          ),
          const SizedBox(height: 20),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Center(child: Text('Cancel')),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionItem(
      BuildContext context, {
        required IconData icon,
        required String title,
        required String value,
        Color? color,
      }) {
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        icon,
        color: color ?? theme.colorScheme.onSurface,
      ),
      title: Text(
        title,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: color ?? theme.colorScheme.onSurface,
        ),
      ),
      onTap: () => Navigator.pop(context, value),
    );
  }
}

// Notification Settings Sheet
class NotificationSettingsSheet extends StatefulWidget {
  final String companyId;
  final Company_Cloud companyCloud;

  const NotificationSettingsSheet({
    Key? key,
    required this.companyId,
    required this.companyCloud,
  }) : super(key: key);

  @override
  State<NotificationSettingsSheet> createState() => _NotificationSettingsSheetState();
}

class _NotificationSettingsSheetState extends State<NotificationSettingsSheet> {
  bool _pushEnabled = true;
  bool _emailEnabled = false;
  bool _soundEnabled = true;
  bool _vibrateEnabled = true;
  bool _newApplications = true;
  bool _applicationUpdates = true;
  bool _studentMessages = true;
  bool _systemAlerts = true;
  bool _paymentNotifications = true;
  bool _reminders = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Notification Settings',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Customize how you receive notifications',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 24),

          // Delivery Methods
          _buildSectionTitle('Delivery Methods'),
          _buildSettingSwitch(
            'Push Notifications',
            _pushEnabled,
                (value) => setState(() => _pushEnabled = value),
          ),
          _buildSettingSwitch(
            'Email Notifications',
            _emailEnabled,
                (value) => setState(() => _emailEnabled = value),
          ),

          const SizedBox(height: 24),

          // Notification Behavior
          _buildSectionTitle('Notification Behavior'),
          _buildSettingSwitch(
            'Sound',
            _soundEnabled,
                (value) => setState(() => _soundEnabled = value),
          ),
          _buildSettingSwitch(
            'Vibration',
            _vibrateEnabled,
                (value) => setState(() => _vibrateEnabled = value),
          ),

          const SizedBox(height: 24),

          // Notification Types
          _buildSectionTitle('Notification Types'),
          _buildSettingSwitch(
            'New Applications',
            _newApplications,
                (value) => setState(() => _newApplications = value),
          ),
          _buildSettingSwitch(
            'Application Updates',
            _applicationUpdates,
                (value) => setState(() => _applicationUpdates = value),
          ),
          _buildSettingSwitch(
            'Student Messages',
            _studentMessages,
                (value) => setState(() => _studentMessages = value),
          ),
          _buildSettingSwitch(
            'System Alerts',
            _systemAlerts,
                (value) => setState(() => _systemAlerts = value),
          ),
          _buildSettingSwitch(
            'Payment Notifications',
            _paymentNotifications,
                (value) => setState(() => _paymentNotifications = value),
          ),
          _buildSettingSwitch(
            'Reminders',
            _reminders,
                (value) => setState(() => _reminders = value),
          ),

          const SizedBox(height: 32),

          ElevatedButton(
            onPressed: _saveSettings,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
            child: const Text('Save Settings'),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
        ),
      ),
    );
  }

  Widget _buildSettingSwitch(
      String title,
      bool value,
      ValueChanged<bool> onChanged,
      ) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      value: value,
      onChanged: onChanged,
    );
  }

  void _saveSettings() {
    // Save settings to Firestore
    final settings = {
      'pushEnabled': _pushEnabled,
      'emailEnabled': _emailEnabled,
      'soundEnabled': _soundEnabled,
      'vibrateEnabled': _vibrateEnabled,
      'newApplications': _newApplications,
      'applicationUpdates': _applicationUpdates,
      'studentMessages': _studentMessages,
      'systemAlerts': _systemAlerts,
      'paymentNotifications': _paymentNotifications,
      'reminders': _reminders,
      'updatedAt': DateTime.now(),
    };

    widget.companyCloud.updateNotificationSettings(widget.companyId, settings);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Settings saved successfully'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );

    Navigator.pop(context);
  }
}