import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:itc_institute_admin/backgroundTask/backgroundTask.dart';
import 'package:itc_institute_admin/backgroundTask/backgroundTaskRegistry.dart';

import '../../migrationService/migrationService.dart';


class MigrationPopupMenu extends StatefulWidget {
  final Widget child;
  final VoidCallback? onRefresh;

  const MigrationPopupMenu({
    Key? key,
    required this.child,
    this.onRefresh,
  }) : super(key: key);

  @override
  _MigrationPopupMenuState createState() => _MigrationPopupMenuState();
}

class _MigrationPopupMenuState extends State<MigrationPopupMenu> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;
  bool _isStartingMigration = false;

  @override
  void dispose() {
    _closeMenu();
    super.dispose();
  }

  void _toggleMenu() {
    if (_isOpen) {
      _closeMenu();
    } else {
      _openMenu();
    }
  }

  void _openMenu() {
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _isOpen = true);
  }

  void _closeMenu() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    setState(() => _isOpen = false);
  }

  OverlayEntry _createOverlayEntry() {
    RenderBox renderBox = context.findRenderObject() as RenderBox;
    var size = renderBox.size;
    var offset = renderBox.localToGlobal(Offset.zero);

    return OverlayEntry(
      builder: (context) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _closeMenu,
        child: Stack(
          children: [
            Positioned(
              left: offset.dx,
              top: offset.dy + size.height + 5,
              child: CompositedTransformFollower(
                link: _layerLink,
                showWhenUnlinked: false,
                offset: Offset(-(250 - size.width), size.height + 5),
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(12),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 280),
                    child: IntrinsicWidth(
                      child: _MigrationMenuContent(
                        onClose: _closeMenu,
                        onRefresh: widget.onRefresh,
                        onMigrationStart: () async {
                          setState(() => _isStartingMigration = true);
                          await MigrationService(FirebaseAuth.instance.currentUser!.uid).startMigration();
                          setState(() => _isStartingMigration = false);
                          _closeMenu();
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onTap: _toggleMenu,
        child: widget.child,
      ),
    );
  }
}

class _MigrationMenuContent extends StatelessWidget {
  final VoidCallback onClose;
  final VoidCallback? onRefresh;
  final VoidCallback onMigrationStart;

  const _MigrationMenuContent({
    Key? key,
    required this.onClose,
    this.onRefresh,
    required this.onMigrationStart,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final task = BackgroundTaskRegistry.getLatestMigrationTask();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF1a2232) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _getHeaderColor(task?.status),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _getHeaderIcon(task?.status),
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getHeaderText(task?.status),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 18),
                  onPressed: onClose,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // Status Details
          if (task != null) ...[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusRow('Status', task.status, task.statusColor),
                  const SizedBox(height: 8),
                  _buildStatusRow('Started', _formatDate(task.createdAt)),
                  if (task.updatedAt != null)
                    _buildStatusRow('Last Update', _formatDate(task.updatedAt!)),
                  _buildStatusRow('Duration', task.duration),

                  if (task.metadata.isNotEmpty && task.status == 'running') ...[
                    const Divider(height: 24),
                    const Text(
                      'Progress',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    if (task.metadata.containsKey('progress'))
                      Column(
                        children: [
                          LinearProgressIndicator(
                            value: (task.metadata['progress'] ?? 0) / 100,
                            backgroundColor: Colors.grey.shade300,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              task.status == 'running' ? Colors.orange : Colors.green,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${task.metadata['progress']}% complete',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    if (task.metadata.containsKey('completedCompanies'))
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Companies: ${task.metadata['completedCompanies']}/${task.metadata['totalCompanies']}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                  ],

                  if (task.status == 'completed' && task.result != null) ...[
                    const Divider(height: 24),
                    const Text(
                      'Result',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      task.result.toString(),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],

                  if (task.status == 'failed' && task.error != null) ...[
                    const Divider(height: 24),
                    const Text(
                      'Error',
                      style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      task.error!,
                      style: const TextStyle(fontSize: 12, color: Colors.red),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],

          // Action Buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                ),
              ),
            ),
            child: Row(
              children: [
                if (task == null || task.status == 'completed' || task.status == 'failed')
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onMigrationStart,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Run Migration'),
                    ),
                  ),
                if (task?.status == 'running') ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        // Optional: Add cancel functionality
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      onClose();
                      onRefresh?.call();
                    },
                    child: const Text('Refresh List'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, [Color? valueColor]) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  String _getHeaderText(String? status) {
    if (status == null) return 'No Migration History';
    switch (status) {
      case 'queued': return 'Migration Queued';
      case 'running': return 'Migration in Progress';
      case 'completed': return 'Migration Completed';
      case 'failed': return 'Migration Failed';
      case 'cancelled': return 'Migration Cancelled';
      default: return 'Migration Status';
    }
  }

  IconData _getHeaderIcon(String? status) {
    if (status == null) return Icons.sync;
    switch (status) {
      case 'queued': return Icons.hourglass_empty;
      case 'running': return Icons.sync;
      case 'completed': return Icons.check_circle;
      case 'failed': return Icons.error;
      case 'cancelled': return Icons.cancel;
      default: return Icons.info;
    }
  }

  Color _getHeaderColor(String? status) {
    if (status == null) return Colors.grey;
    switch (status) {
      case 'queued': return Colors.orange;
      case 'running': return Colors.blue;
      case 'completed': return Colors.green;
      case 'failed': return Colors.red;
      case 'cancelled': return Colors.grey;
      default: return Colors.blue;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} hours ago';
    } else {
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
  }
}

extension on TaskStatus {
  Color get statusColor {
    switch (status) {
      case 'queued': return Colors.orange;
      case 'running': return Colors.blue;
      case 'completed': return Colors.green;
      case 'failed': return Colors.red;
      case 'cancelled': return Colors.grey;
      default: return Colors.grey;
    }
  }
}