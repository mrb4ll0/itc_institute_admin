import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firestore_lazy_loading_totalxsoftware/firestore_lazy_loading_totalxsoftware.dart';
import 'package:intl/intl.dart';

import '../../model/RecentActions.dart';



class RecentActionsFullPage extends StatefulWidget {
  final String companyId;
  final String companyName;

  const RecentActionsFullPage({
    super.key,
    required this.companyId,
    required this.companyName,
  });

  @override
  State<RecentActionsFullPage> createState() => _RecentActionsFullPageState();
}

class _RecentActionsFullPageState extends State<RecentActionsFullPage> {
  // FirestoreLazyLoadingTotalxsoftware instance
  final FirestoreLazyLoadingTotalxsoftware _lazyLoading =
  FirestoreLazyLoadingTotalxsoftware();

  // List to hold fetched data
  final List<RecentAction> _recentActions = [];
  bool _isNoMoreData = false;
  bool _isLoading = false;
  bool _isInitialLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  void _initData() {
    _lazyLoading.fetchInitData(
      context,
      query: FirebaseFirestore.instance.collection("users").doc("companies")
          .collection('companies')
          .doc(widget.companyId)
          .collection('recentActions')
          .orderBy('timestamp', descending: true),
      limit: 10,
      noMoreData: (value) {
        if (mounted) {
          setState(() {
            _isNoMoreData = value;
          });
        }
      },
      onLoading: (value) {
        if (mounted) {
          setState(() {
            _isLoading = value;
            if (_isInitialLoading && !value) {
              _isInitialLoading = false;
            }
          });
        }
      },
      onData: (data) {
        if (mounted) {
          setState(() {
            for (var element in data) {
              try {
                final action = RecentAction.fromFirestore(element);
                _recentActions.add(action);
              } catch (e) {
                debugPrint('Error parsing action: $e');
              }
            }
          });
        }
      },
    );
  }

  Future<void> _refreshData() async {
    setState(() {
      _recentActions.clear();
      _isNoMoreData = false;
      _isInitialLoading = true;
      _errorMessage = null;
    });

    // Reset and reinitialize
    _lazyLoading.clear();
    _initData();
  }

  @override
  void dispose() {
    _lazyLoading.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF0f172a) : const Color(0xFFf8fafc);
    final textColor = isDark ? Colors.white : Colors.black;
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Recent Activities',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _refreshData,
            icon: Icon(Icons.refresh_rounded, color: textColor),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildContent(isDark, textColor, subTextColor),
    );
  }

  Widget _buildContent(bool isDark, Color textColor, Color? subTextColor) {
    if (_errorMessage != null && _recentActions.isEmpty) {
      return _buildErrorWidget();
    }

    if (_isInitialLoading) {
      return _buildInitialLoading();
    }

    if (_recentActions.isEmpty && !_isLoading) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      color: isDark ? Colors.blueAccent : Colors.blue,
      backgroundColor: isDark ? Colors.grey[900] : Colors.grey[100],
      child: CustomScrollView(
        controller: _lazyLoading.scrollController,
        slivers: [
          // Header with stats
          _buildHeaderSliver(isDark, textColor, subTextColor),

          // Loading indicator for initial load
          if (_isLoading && _recentActions.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),

          // Actions list
          if (_recentActions.isNotEmpty)
            SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) {
                  final action = _recentActions[index];
                  return _buildActionCard(action, isDark, textColor, subTextColor);
                },
                childCount: _recentActions.length,
              ),
            ),

          // Bottom loading indicator
          SliverToBoxAdapter(
            child: _lazyLoading.bottomLoadingIndicator(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [

                      const CircularProgressIndicator()
                  ],
                ),
              ),
            ),
          ),
          // Extra padding at bottom
          const SliverToBoxAdapter(
            child: SizedBox(height: 80),
          ),
        ],
      ),
    );
  }

  SliverToBoxAdapter _buildHeaderSliver(
      bool isDark,
      Color textColor,
      Color? subTextColor
      ) {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
              const Color(0xFF1e1b4b),
              const Color(0xFF312e81),
            ]
                : [
              const Color(0xFFe0e7ff),
              const Color(0xFFc7d2fe),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.3)
                  : Colors.grey.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF3730a3) : const Color(0xFF4f46e5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.history_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.companyName,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Recent Activities',
                    style: TextStyle(
                      fontSize: 14,
                      color: subTextColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '${_recentActions.length} ',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                          ),
                        ),
                        TextSpan(
                          text: 'activities loaded',
                          style: TextStyle(
                            fontSize: 14,
                            color: subTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF3730a3).withOpacity(0.5)
                    : const Color(0xFF4f46e5).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _isNoMoreData ? 'All Loaded' : 'Loading...',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFFa5b4fc) : const Color(0xFF4f46e5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
      RecentAction action,
      bool isDark,
      Color textColor,
      Color? subTextColor,
      ) {
    final cardColor = isDark ? const Color(0xFF1e293b) : Colors.white;
    final borderColor = isDark ? Colors.grey[800] : Colors.grey[200];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.3) : Colors.grey.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: borderColor!, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            _showActionDetails(action);
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with action type and time
                Row(
                  children: [
                    // Action icon
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _getActionColor(action.actionType).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getActionIcon(action.actionType),
                        color: _getActionColor(action.actionType),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Action details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _capitalize(action.actionType),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'on ${_capitalize(action.entityType)}',
                            style: TextStyle(
                              fontSize: 13,
                              color: subTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Timestamp
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          action.timeAgo,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: subTextColor,
                          ),
                        ),
                        Text(
                          DateFormat('MMM dd, hh:mm a').format(action.timestamp),
                          style: TextStyle(
                            fontSize: 11,
                            color: subTextColor?.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Description
                Text(
                  action.description,
                  style: TextStyle(
                    fontSize: 14,
                    color: textColor.withOpacity(0.9),
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 12),

                // Entity info
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black.withOpacity(0.2) : Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Entity',
                              style: TextStyle(
                                fontSize: 11,
                                color: subTextColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              action.entityName,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        height: 30,
                        width: 1,
                        color: borderColor,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'User',
                              style: TextStyle(
                                fontSize: 11,
                                color: subTextColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              action.userName,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // View details link
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Tap to view details →',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.blue[300] : Colors.blue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInitialLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(height: 16),
          Text(
            'Loading recent activities...',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history_toggle_off_rounded,
              size: 80,
              color: subTextColor,
            ),
            const SizedBox(height: 24),
            Text(
              'No Recent Activities',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Recent activities from ${widget.companyName} will appear here',
              style: TextStyle(
                fontSize: 16,
                color: subTextColor,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _refreshData,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Refresh'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.blueAccent : Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to Load Activities',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage ?? 'An unknown error occurred',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _refreshData,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.blueAccent : Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showActionDetails(RecentAction action) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: isDark ? const Color(0xFF1e293b) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: _getActionColor(action.actionType).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _getActionIcon(action.actionType),
                          color: _getActionColor(action.actionType),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _capitalize(action.actionType),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            Text(
                              '${_capitalize(action.entityType)} • ${action.timeAgo}',
                              style: TextStyle(
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Description
                  Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.grey[400] : Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    action.description,
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark ? Colors.white : Colors.black,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Details Grid
                  GridView.count(
                    shrinkWrap: true,
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 3,
                    children: [
                      _buildDetailItem(
                        'Entity Type',
                        _capitalize(action.entityType),
                        isDark,
                      ),
                      _buildDetailItem(
                        'Entity Name',
                        action.entityName,
                        isDark,
                      ),
                      _buildDetailItem(
                        'Entity ID',
                        action.entityId,
                        isDark,
                        isId: true,
                      ),
                      _buildDetailItem(
                        'User',
                        action.userName,
                        isDark,
                      ),
                      _buildDetailItem(
                        'User Role',
                        action.userRole,
                        isDark,
                      ),
                      _buildDetailItem(
                        'Date & Time',
                        DateFormat('MMM dd, yyyy • hh:mm a').format(action.timestamp),
                        isDark,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Close button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? Colors.blueAccent : Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailItem(String label, String value, bool isDark, {bool isId = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black,
            fontFamily: isId ? 'monospace' : null,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  IconData _getActionIcon(String actionType) {
    switch (actionType.toLowerCase()) {
      case 'create':
      case 'created':
        return Icons.add_circle_outline_rounded;
      case 'update':
      case 'updated':
        return Icons.edit_outlined;
      case 'delete':
      case 'deleted':
        return Icons.delete_outline_rounded;
      case 'upload':
      case 'uploaded':
        return Icons.cloud_upload_outlined;
      case 'approve':
      case 'approved':
        return Icons.check_circle_outline_rounded;
      case 'reject':
      case 'rejected':
        return Icons.cancel_outlined;
      default:
        return Icons.history_rounded;
    }
  }

  Color _getActionColor(String actionType) {
    switch (actionType.toLowerCase()) {
      case 'create':
      case 'created':
        return Colors.green;
      case 'update':
      case 'updated':
        return Colors.blue;
      case 'delete':
      case 'deleted':
        return Colors.red;
      case 'upload':
      case 'uploaded':
        return Colors.purple;
      case 'approve':
      case 'approved':
        return Colors.teal;
      case 'reject':
      case 'rejected':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
}