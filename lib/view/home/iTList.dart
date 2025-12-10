import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:itc_institute_admin/generalmethods/GeneralMethods.dart';
import 'package:itc_institute_admin/itc_logic/firebase/company_cloud.dart';

import '../../model/internship_model.dart';
import 'industrailTraining/ITDetails.dart';
import 'industrailTraining/newIndustrialTraining.dart';

class IndustrialTrainingPostsPage extends StatefulWidget {
  const IndustrialTrainingPostsPage({super.key});

  @override
  State<IndustrialTrainingPostsPage> createState() =>
      _IndustrialTrainingPostsPageState();
}

class _IndustrialTrainingPostsPageState
    extends State<IndustrialTrainingPostsPage>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  bool _showSearchBar = false;
  final Company_Cloud companyCloud = Company_Cloud();
  late Stream<List<IndustrialTraining>> _internshipsStream;
  late StreamSubscription<List<IndustrialTraining>> _internshipsSubscription;
  int postCount = 0;
  @override
  bool get wantKeepAlive => true;
  @override
  void initState() {
    super.initState();
    _internshipsStream = companyCloud.getCurrentCompanyInternships(
      FirebaseAuth.instance.currentUser!.uid,
    );

    _internshipsSubscription = _internshipsStream.listen((internships) {
      if (mounted) {
        setState(() {
          postCount = internships.length;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: isDark
          ? colorScheme.surfaceContainerHighest
          : colorScheme.surfaceContainerLowest,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar
            _buildTopAppBar(context),

            // Search Bar (Conditional)
            if (_showSearchBar) _buildSearchBar(context),
            Align(
              alignment: Alignment.center,
              child: Text(
                '$postCount Post',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),

            // Training Posts List
            Expanded(
              child: StreamBuilder<List<IndustrialTraining>>(
                stream: _internshipsStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildLoadingState(context);
                  }

                  if (snapshot.hasError) {
                    debugPrint(snapshot.error.toString());
                    return _buildErrorState(context, snapshot.error!);
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return _buildEmptyState(context);
                  }

                  List<IndustrialTraining> internships = snapshot.data!;

                  // Apply search filter if search is active
                  if (_showSearchBar && _searchController.text.isNotEmpty) {
                    internships = _filterInternships(
                      internships,
                      _searchController.text,
                    );
                  }
                  postCount = internships.length ?? 0;
                  return _buildPostsList(context, internships);
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _createNewInternship();
        },
        backgroundColor: const Color(0xFF005A9C),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTopAppBar(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      height: 56,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: colorScheme.outline.withOpacity(0.1)),
        ),
        color: colorScheme.surface.withOpacity(0.8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Industrial Training Posts',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.search, color: colorScheme.onSurfaceVariant),
                  onPressed: () {
                    setState(() {
                      _showSearchBar = !_showSearchBar;
                      if (!_showSearchBar) {
                        _searchController.clear();
                      }
                    });
                  },
                ),
                IconButton(
                  icon: Icon(
                    Icons.refresh,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () {
                    // Force refresh
                    setState(() {
                      _internshipsStream = companyCloud
                          .getCurrentCompanyInternships(
                            FirebaseAuth.instance.currentUser!.uid,
                          );
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark
                ? colorScheme.outline.withOpacity(0.3)
                : colorScheme.outline.withOpacity(0.2),
          ),
          color: isDark
              ? colorScheme.surfaceContainerHigh
              : colorScheme.surfaceContainer,
        ),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Icon(
                Icons.search,
                size: 20,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {}); // Rebuild to apply filter
                  },
                  decoration: InputDecoration(
                    hintText: 'Search by title, company, or industry...',
                    hintStyle: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: TextStyle(color: colorScheme.onSurface, fontSize: 14),
                ),
              ),
            ),
            if (_searchController.text.isNotEmpty)
              IconButton(
                icon: Icon(
                  Icons.clear,
                  size: 20,
                  color: colorScheme.onSurfaceVariant,
                ),
                onPressed: () {
                  setState(() {
                    _searchController.clear();
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostsList(
    BuildContext context,
    List<IndustrialTraining> internships,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;
    postCount = internships.length ?? 0;

    return Container(
      color: isDark
          ? colorScheme.surfaceContainerHigh
          : colorScheme.surfaceContainerLowest,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemCount: internships.length,
        itemBuilder: (context, index) {
          final post = internships[index];
          return _buildPostCard(context, post);
        },
      ),
    );
  }

  Widget _buildPostCard(BuildContext context, IndustrialTraining post) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    debugPrint("applciations count ${post.applications.length}");
    return Card(
      elevation: 0,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // Navigate to internship details
          debugPrint("Internship Details Page");
          GeneralMethods.navigateTo(
            context,
            InternshipDetailsPage(internship: post),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.title,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.business,
                              size: 16,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                post.company.name,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.category,
                              size: 16,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              post.industry,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.people,
                              size: 16,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Row(
                              children: [
                                Text(
                                  '${post.applicationsCount} ${post.applicationsCount == 1 ? 'Applicant' : 'Applicants'}',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant
                                        .withOpacity(0.6),
                                  ),
                                ),
                                SizedBox(width: 10),
                                Text(
                                  '${GeneralMethods.calculateSlot(post.intake.toString(), post.applicationsCount.toString())} Slot left',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant
                                        .withOpacity(0.6),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        if (post.startDate != null && post.endDate != null)
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 16,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${_formatDate(post.startDate!)} - ${_formatDate(post.endDate!)}',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 8),
                        if (post.description.isNotEmpty)
                          Text(
                            post.description,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    children: [
                      InkWell(
                        onTap: () {},
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: _getStatusColor(
                              post.status,
                            ).withOpacity(0.1),
                            border: Border.all(
                              color: _getStatusColor(
                                post.status,
                              ).withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _getStatusIcon(post.status),
                                size: 14,
                                color: _getStatusColor(post.status),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _getStatusText(post.status),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: _getStatusColor(post.status),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 10),
                      IconButton(
                        onPressed: () {
                          _viewInternshipDetails(context, post);
                        },
                        icon: Icon(Icons.remove_red_eye_outlined),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (post.stipendAvailable != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: Colors.green.withOpacity(0.1),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.monetization_on,
                            size: 14,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            post.stipend ?? 'Stipend Provided',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.green,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: colorScheme.primary.withOpacity(0.1),
                    ),
                    child: Text(
                      '${_getDurationText(post.duration)}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Loading internships...',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'Error Loading Posts',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w500,
                color: colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _internshipsStream = companyCloud.getAllCompanyInternships();
                });
              },
              icon: Icon(Icons.refresh),
              label: Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: isDark
                    ? colorScheme.surfaceContainerHigh
                    : colorScheme.surfaceContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.description,
                size: 32,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No Internships Yet',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the + button to create your first\nindustrial training opportunity.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return const Color(0xFF10B981); // Green
      case 'closed':
        return const Color(0xFFEF4444); // Red
      case 'filled':
        return const Color(0xFF6B7280); // Gray
      default:
        return const Color(0xFF6B7280); // Default gray
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return Icons.lock_open;
      case 'closed':
        return Icons.lock;
      case 'filled':
        return Icons.check_circle;
      default:
        return Icons.help_outline;
    }
  }

  String _getStatusText(String status) {
    return status.toUpperCase();
  }

  String _getDurationText(Map<String, dynamic>? duration) {
    if (duration == null || duration.isEmpty) return 'Duration not specified';

    final weeks = duration['weeks'] as int?;
    final months = duration['months'] as int?;

    if (weeks != null) return '$weeks ${weeks == 1 ? 'week' : 'weeks'}';
    if (months != null) return '$months ${months == 1 ? 'month' : 'months'}';

    return 'Duration not specified';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  List<IndustrialTraining> _filterInternships(
    List<IndustrialTraining> internships,
    String query,
  ) {
    final lowercaseQuery = query.toLowerCase();
    return internships.where((internship) {
      return internship.title.toLowerCase().contains(lowercaseQuery) ||
          internship.company.name.toLowerCase().contains(lowercaseQuery) ||
          internship.industry.toLowerCase().contains(lowercaseQuery) ||
          internship.description.toLowerCase().contains(lowercaseQuery);
    }).toList();
  }

  void _viewInternshipDetails(
    BuildContext context,
    IndustrialTraining internship,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(internship.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Company', internship.company.name),
              _buildDetailRow('Industry', internship.industry),
              _buildDetailRow('Status', internship.status.toUpperCase()),
              if (internship.startDate != null && internship.endDate != null)
                _buildDetailRow(
                  'Duration',
                  '${_formatDate(internship.startDate!)} - ${_formatDate(internship.endDate!)}',
                ),
              _buildDetailRow(
                'Duration',
                _getDurationText(internship.duration),
              ),
              _buildDetailRow(
                'Applications',
                '${internship.applicationsCount} applications',
              ),
              if (internship.stipendAvailable != null)
                _buildDetailRow('Stipend', internship.stipend ?? 'Provided'),
              _buildDetailRow('Eligibility', internship.eligibilityCriteria),
              const SizedBox(height: 12),
              const Text(
                'Description:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(internship.description),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _createNewInternship() {
    GeneralMethods.navigateTo(context, const CreateIndustrialTrainingPage());
  }
}
