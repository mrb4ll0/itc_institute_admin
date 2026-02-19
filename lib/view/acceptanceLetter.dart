import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:itc_institute_admin/generalmethods/GeneralMethods.dart';
import 'package:itc_institute_admin/view/home/industrailTraining/fileDetails.dart';

import '../itc_logic/firebase/company_cloud.dart';
import '../letterGenerator/GenerateAcceptanceLetter.dart';

class AcceptanceLettersPage extends StatefulWidget {
  final String userRole; // 'student' or 'company' or 'authority'
  final List<String> companyId; // Optional, for company view
  final String? studentId; // Optional, for student view

  const AcceptanceLettersPage({
    super.key,
    required this.userRole,
    required this.companyId,
    this.studentId,
  });

  @override
  State<AcceptanceLettersPage> createState() => _AcceptanceLettersPageState();
}

class _AcceptanceLettersPageState extends State<AcceptanceLettersPage> {
  final Company_Cloud _companyCloud = Company_Cloud(FirebaseAuth.instance.currentUser!.uid);
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _selectedFilter = 'all'; // 'all', 'sent', 'accepted', 'rejected'
  String _selectedSort = 'newest'; // 'newest', 'oldest', 'name'

  // Cache for the stream to avoid multiple listeners
  Stream<List<AcceptanceLetterData>>? _cachedStream;
  List<String>? _lastCompanyIds;

  @override
  void dispose() {
    _cachedStream = null;
    _lastCompanyIds = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: StreamBuilder<List<AcceptanceLetterData>>(
        stream: _getAcceptanceLettersStream(),
        builder: (context, snapshot) {
          return Column(
            children: [
              // Custom App Bar
              CustomAppBar(
                title: 'Acceptance Letters',
                showBackButton: true,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.filter_list),
                    onPressed: _showFilterDialog,
                  ),
                  IconButton(
                    icon: const Icon(Icons.sort),
                    onPressed: _showSortDialog,
                  ),
                ],
              ),

              // Statistics Cards (Top Section)
              _buildStatisticsCards(snapshot, theme, colorScheme),

              // Filter Chips
              _buildFilterChips(colorScheme),

              // Main Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _buildAcceptanceLettersList(snapshot, theme, colorScheme),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatisticsCards(
      AsyncSnapshot<List<AcceptanceLetterData>> snapshot,
      ThemeData theme,
      ColorScheme colorScheme,
      ) {
    if (!snapshot.hasData) {
      return const SizedBox(height: 100);
    }

    if (snapshot.data == null) {
      return Container();
    }

    final letters = snapshot.data!;

    final total = letters.length;
    final accepted = letters.where((letter) => letter.isAccepted).length;
    final pending = letters.where((letter) => letter.isSent).length;
    final rejected = letters.where((letter) => letter.isRejected).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatCard(
            count: total,
            label: 'Total',
            color: colorScheme.primary,
            icon: Icons.description,
            theme: theme,
          ),
          _buildStatCard(
            count: pending,
            label: 'Pending',
            color: colorScheme.secondary,
            icon: Icons.access_time,
            theme: theme,
          ),
          _buildStatCard(
            count: accepted,
            label: 'Accepted',
            color: Colors.green, // Success color
            icon: Icons.check_circle,
            theme: theme,
          ),
          _buildStatCard(
            count: rejected,
            label: 'Rejected',
            color: colorScheme.error,
            icon: Icons.cancel,
            theme: theme,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required int count,
    required String label,
    required Color color,
    required IconData icon,
    required ThemeData theme,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: theme.hintColor,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChips(ColorScheme colorScheme) {
    final filters = [
      {'value': 'all', 'label': 'All'},
      {'value': 'sent', 'label': 'Sent'},
      {'value': 'accepted', 'label': 'Accepted'},
      {'value': 'rejected', 'label': 'Rejected'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: filters.map((filter) {
          final isSelected = _selectedFilter == filter['value'];
          final chipColor = isSelected ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.1);
          final textColor = isSelected ? colorScheme.onPrimary : colorScheme.onSurface;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(filter['label'] as String),
              labelStyle: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w500,
              ),
              backgroundColor: chipColor,
              selected: isSelected,
              selectedColor: colorScheme.primary,
              checkmarkColor: colorScheme.onPrimary,
              onSelected: (selected) {
                setState(() {
                  _selectedFilter = filter['value'] as String;
                });
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAcceptanceLettersList(
      AsyncSnapshot<List<AcceptanceLetterData>> snapshot,
      ThemeData theme,
      ColorScheme colorScheme,
      ) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return Center(child: CircularProgressIndicator(color: colorScheme.primary));
    }

    if (snapshot.data == null) {
      return Center(
        child: Text(
          "No Letter to display",
          style: TextStyle(color: theme.hintColor),
        ),
      );
    }

    if (snapshot.hasError) {
      return Center(
        child: Text(
          'Error: ${snapshot.error}',
          style: TextStyle(color: colorScheme.error),
        ),
      );
    }

    if (!snapshot.hasData || snapshot.data!.isEmpty) {
      return EmptyState(
        icon: Icons.description,
        title: 'No Acceptance Letters',
        message: _getEmptyStateMessage(),
        actionText: 'Go Back',
        onAction: () => Navigator.pop(context),
        theme: theme,
      );
    }

    var letters = snapshot.data!;

    // Apply filter
    if (_selectedFilter != 'all') {
      letters = letters.where((letter) => letter.status == _selectedFilter).toList();
    }

    // Apply sorting
    letters = _sortLetters(letters);

    return ListView.separated(
      itemCount: letters.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final letter = letters[index];
        return _buildAcceptanceLetterCard(letter, theme, colorScheme);
      },
    );
  }

  Widget _buildAcceptanceLetterCard(
      AcceptanceLetterData letter,
      ThemeData theme,
      ColorScheme colorScheme,
      ) {
    final statusColor = _getStatusColor(letter.status, colorScheme);

    return GestureDetector(
      onTap: () {
        _showAcceptanceLetterDetail(letter, theme, colorScheme);
      },
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status Icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getStatusIcon(letter.status),
                  color: statusColor,
                  size: 20,
                ),
              ),

              const SizedBox(width: 16),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            letter.companyName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: theme.textTheme.titleLarge?.color,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            letter.statusDisplayText,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Student/Company Info
                    if (widget.userRole == 'company')
                      Text(
                        'Student: ${letter.studentName}',
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.hintColor,
                        ),
                      )
                    else
                      Text(
                        'Company: ${letter.companyName}',
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.hintColor,
                        ),
                      ),

                    const SizedBox(height: 4),

                    // Internship Title
                    if (letter.internshipTitle != null && letter.internshipTitle!.isNotEmpty)
                      Text(
                        'Internship: ${letter.internshipTitle}',
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.hintColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                    const SizedBox(height: 4),

                    // Duration
                    Text(
                      '${DateFormat('MMM dd, yyyy').format(letter.startDate)} - ${DateFormat('MMM dd, yyyy').format(letter.endDate)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.hintColor,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Bottom Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Date
                        Row(
                          children: [
                            Icon(Icons.calendar_today, size: 14, color: theme.hintColor),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat('MMM dd, yyyy').format(letter.createdAt),
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.hintColor,
                              ),
                            ),
                          ],
                        ),

                        // Actions
                        if (widget.userRole == 'student' && letter.isSent)
                          _buildStudentActions(letter, colorScheme)
                        else if (widget.userRole == 'company')
                          _buildCompanyActions(letter, theme),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudentActions(AcceptanceLetterData letter, ColorScheme colorScheme) {
    return Row(
      children: [
        ElevatedButton.icon(
          onPressed: () => _updateLetterStatus(letter, 'accepted'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          icon: const Icon(Icons.check, size: 16),
          label: const Text('Accept'),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: () => _updateLetterStatus(letter, 'rejected'),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: colorScheme.error),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          icon: const Icon(Icons.close, size: 16),
          label: const Text('Reject'),
        ),
      ],
    );
  }

  Widget _buildCompanyActions(AcceptanceLetterData letter, ThemeData theme) {
    return Row(
      children: [
        // View PDF Button
        IconButton(
          onPressed: () {
            if (letter.fileUrl != null && letter.fileUrl!.isNotEmpty) {
              _viewPdf(letter.fileUrl!);
            }
          },
          icon: Icon(Icons.picture_as_pdf, color: theme.colorScheme.primary),
          tooltip: 'View PDF',
        ),

        // More options
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: theme.colorScheme.onSurface),
          onSelected: (value) {
            if (value == 'resend') {
              _resendLetter(letter);
            } else if (value == 'delete') {
              _deleteLetter(letter);
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'resend',
              child: Row(
                children: [
                  Icon(Icons.send, size: 20, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text('Resend'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: theme.colorScheme.error, size: 20),
                  const SizedBox(width: 8),
                  Text('Delete'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Helper Methods
  Stream<List<AcceptanceLetterData>> _getAcceptanceLettersStream() {
    // Get current company IDs
    final currentCompanyIds = widget.companyId;

    // Check if we can reuse cached stream
    if (_cachedStream != null && _listEquals(_lastCompanyIds, currentCompanyIds)) {
      return _cachedStream!;
    }

    // Get new stream
    final newStream = _companyCloud.getCompanyAcceptanceLetters(currentCompanyIds);

    // Make it a broadcast stream so multiple widgets can listen
    _cachedStream = newStream.asBroadcastStream(
      onListen: (subscription) {
        debugPrint("Stream listener added");
      },
      onCancel: (subscription) {
        debugPrint("Stream listener removed");
      },
    );

    // Cache the company IDs
    _lastCompanyIds = List.from(currentCompanyIds);

    return _cachedStream!;
  }

  bool _listEquals(List<String>? a, List<String>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  List<AcceptanceLetterData> _sortLetters(List<AcceptanceLetterData> letters) {
    switch (_selectedSort) {
      case 'newest':
        letters.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 'oldest':
        letters.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case 'name':
        letters.sort((a, b) => a.studentName.compareTo(b.studentName));
        break;
    }
    return letters;
  }

  Color _getStatusColor(String? status, [ColorScheme? colorScheme]) {
    final scheme = colorScheme ?? Theme.of(context).colorScheme;

    switch (status) {
      case 'draft':
        return scheme.onSurface.withOpacity(0.6);
      case 'sent':
        return scheme.secondary;
      case 'accepted':
        return Colors.green; // Success color
      case 'rejected':
        return scheme.error;
      case 'withdrawn':
        return scheme.secondary;
      default:
        return scheme.onSurface.withOpacity(0.6);
    }
  }

  IconData _getStatusIcon(String? status) {
    switch (status) {
      case 'draft':
        return Icons.drafts;
      case 'sent':
        return Icons.send;
      case 'accepted':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'withdrawn':
        return Icons.undo;
      default:
        return Icons.description;
    }
  }

  String _getEmptyStateMessage() {
    switch (_selectedFilter) {
      case 'sent':
        return 'No sent acceptance letters found';
      case 'accepted':
        return 'No accepted letters found';
      case 'rejected':
        return 'No rejected letters found';
      default:
        return widget.userRole == 'student'
            ? 'You haven\'t received any acceptance letters yet'
            : 'No acceptance letters have been sent yet';
    }
  }

  // Action Methods
  void _updateLetterStatus(AcceptanceLetterData letter, String status) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${status.capitalize()} Acceptance Letter'),
        content: status == 'rejected'
            ? TextField(
          decoration: InputDecoration(
            labelText: 'Reason for rejection',
            border: OutlineInputBorder(),
            labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          ),
          maxLines: 3,
          onChanged: (value) {
            // Store reason
          },
        )
            : Text('Are you sure you want to $status this acceptance letter?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                // await _companyCloud.updateAcceptanceLetterStatus(
                //   acceptanceLetterId: letter.id,
                //   companyId: letter.companyId!,
                //   studentId: letter.studentId,
                //   status: status,
                //   isAuthority: widget.userRole == 'authority',
                // );
                // ScaffoldMessenger.of(context).showSnackBar(
                //   SnackBar(
                //     content: Text('Letter $status successfully'),
                //     backgroundColor: status == 'accepted' ? Colors.green : Theme.of(context).colorScheme.error,
                //   ),
                // );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: status == 'accepted' ? Colors.green : Theme.of(context).colorScheme.error,
            ),
            child: Text(status.capitalize()),
          ),
        ],
      ),
    );
  }

  void _viewPdf(String pdfUrl) {

    // showDialog(
    //   context: context,
    //   builder: (context) => AlertDialog(
    //     title: const Text('View PDF'),
    //     content: const Text('Opening PDF viewer...'),
    //     actions: [
    //       TextButton(
    //         onPressed: () => Navigator.pop(context),
    //         child: const Text('Close'),
    //       ),
    //     ],
    //   ),
    // );

    GeneralMethods.navigateTo(context,FullScreenViewer(firebasePath: pdfUrl,));
  }

  void _resendLetter(AcceptanceLetterData letter) async {
    // Implement resend logic
  }

  void _deleteLetter(AcceptanceLetterData letter) async {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Acceptance Letter'),
        content: const Text('Are you sure you want to delete this acceptance letter? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Implement delete logic
            },
            style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAcceptanceLetterDetail(
      AcceptanceLetterData letter,
      ThemeData theme,
      ColorScheme colorScheme,
      ) {
    // Navigate to detail page or show bottom sheet
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => AcceptanceLetterDetailSheet(
        letter: letter,
        theme: theme,
        colorScheme: colorScheme,
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Letters'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildFilterOption('all', 'All Letters'),
            _buildFilterOption('sent', 'Sent'),
            _buildFilterOption('accepted', 'Accepted'),
            _buildFilterOption('rejected', 'Rejected'),
            _buildFilterOption('withdrawn', 'Withdrawn'),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterOption(String value, String label) {
    return RadioListTile<String>(
      title: Text(label),
      value: value,
      groupValue: _selectedFilter,
      onChanged: (newValue) {
        setState(() {
          _selectedFilter = newValue!;
        });
        Navigator.pop(context);
      },
    );
  }

  void _showSortDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sort By'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSortOption('newest', 'Newest First'),
            _buildSortOption('oldest', 'Oldest First'),
            _buildSortOption('name', 'Name (A-Z)'),
            _buildSortOption('status', 'Status'),
          ],
        ),
      ),
    );
  }

  Widget _buildSortOption(String value, String label) {
    return RadioListTile<String>(
      title: Text(label),
      value: value,
      groupValue: _selectedSort,
      onChanged: (newValue) {
        setState(() {
          _selectedSort = newValue!;
        });
        Navigator.pop(context);
      },
    );
  }
}

// Extension for string capitalization
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}

// Detail Sheet Widget
class AcceptanceLetterDetailSheet extends StatelessWidget {
  final AcceptanceLetterData letter;
  final ThemeData theme;
  final ColorScheme colorScheme;

  const AcceptanceLetterDetailSheet({
    super.key,
    required this.letter,
    required this.theme,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Acceptance Letter Details',
                style: theme.textTheme.titleLarge,
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close, color: colorScheme.onSurface),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Details
          _buildDetailRow('Student Name', letter.studentName, theme),
          _buildDetailRow('Company', letter.companyName, theme),
          if (letter.internshipTitle != null)
            _buildDetailRow('Internship', letter.internshipTitle!, theme),
          _buildDetailRow(
            'Duration',
            '${DateFormat('MMM dd, yyyy').format(letter.startDate)} - ${DateFormat('MMM dd, yyyy').format(letter.endDate)}',
            theme,
          ),
          _buildDetailRow('Status', letter.statusDisplayText, theme),
          _buildDetailRow('Generated On', DateFormat('MMM dd, yyyy').format(letter.createdAt), theme),

          if (letter.sentAt != null)
            _buildDetailRow('Sent On', DateFormat('MMM dd, yyyy').format(letter.sentAt!), theme),

          if (letter.acceptedAt != null)
            _buildDetailRow('Accepted On', DateFormat('MMM dd, yyyy').format(letter.acceptedAt!), theme),

          if (letter.rejectedAt != null)
            _buildDetailRow('Rejected On', DateFormat('MMM dd, yyyy').format(letter.rejectedAt!), theme),

          if (letter.reason != null && letter.reason!.isNotEmpty)
            _buildDetailRow('Reason', letter.reason!, theme),

          const SizedBox(height: 32),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {

                    // View PDF
                    GeneralMethods.navigateTo(context,FullScreenViewer(firebasePath: letter.fileUrl,));
                  },
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('View PDF'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    // Download PDF
                    GeneralMethods.navigateTo(context,FullScreenViewer(firebasePath: letter.fileUrl,));
                  },
                  icon: const Icon(Icons.download),
                  label: const Text('Download'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: theme.hintColor,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: theme.textTheme.titleLarge?.color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Empty State Widget
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionText;
  final VoidCallback? onAction;
  final ThemeData theme;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionText,
    this.onAction,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 80,
              color: theme.hintColor.withOpacity(0.3),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: theme.hintColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: theme.hintColor,
              ),
            ),
            if (actionText != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onAction,
                child: Text(actionText!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBackButton;
  final List<Widget>? actions;
  final Color? backgroundColor;
  final Color? textColor;
  final Widget? leading;
  final double elevation;
  final bool centerTitle;
  final VoidCallback? onBackPressed;

  const CustomAppBar({
    super.key,
    required this.title,
    this.showBackButton = true,
    this.actions,
    this.backgroundColor,
    this.textColor,
    this.leading,
    this.elevation = 2,
    this.centerTitle = false,
    this.onBackPressed,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppBar(
      backgroundColor: backgroundColor ?? colorScheme.primary,
      foregroundColor: textColor ?? colorScheme.onPrimary,
      elevation: elevation,
      centerTitle: centerTitle,
      automaticallyImplyLeading: showBackButton,
      leading: showBackButton
          ? (leading ??
          IconButton(
            icon: Icon(Icons.arrow_back, color: textColor ?? colorScheme.onPrimary),
            onPressed: onBackPressed ?? () => Navigator.of(context).pop(),
          ))
          : null,
      title: Text(
        title,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textColor ?? colorScheme.onPrimary,
        ),
      ),
      actions: actions,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(15),
        ),
      ),
    );
  }
}