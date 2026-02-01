import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:itc_institute_admin/generalmethods/GeneralMethods.dart';
import 'package:itc_institute_admin/itc_logic/firebase/ActionLogger.dart';
import 'package:itc_institute_admin/itc_logic/firebase/company_cloud.dart';
import 'package:itc_institute_admin/itc_logic/firebase/general_cloud.dart';
import 'package:itc_institute_admin/itc_logic/notification/fireStoreNotification.dart';
import 'package:itc_institute_admin/itc_logic/notification/notitification_service.dart';
import 'package:itc_institute_admin/model/studentApplication.dart';
import 'package:itc_institute_admin/view/home/industrailTraining/applications/studentApplicationsPage.dart';
import 'industrailTraining/applications/studentWithLatestApplication.dart';
import 'industrailTraining/newIndustrialTraining.dart';

// Import the new model and service

class StudentApplicationsPage extends StatefulWidget {
  final bool isAuthority;
    final List<String> companyIds;
  const StudentApplicationsPage({super.key,required this.isAuthority, required this.companyIds});

  @override
  State<StudentApplicationsPage> createState() =>
      _StudentApplicationsPageState();
}

class _StudentApplicationsPageState extends State<StudentApplicationsPage>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  final Company_Cloud company_cloud = Company_Cloud();
  final NotificationService notificationService = NotificationService();
  ActionLogger actionLogger = ActionLogger();
  final ITCFirebaseLogic _itcFirebaseLogic = ITCFirebaseLogic();
  int applicationCount = 0;
  final Company_Cloud companyCloud = Company_Cloud();
  bool _isRefreshing = false;
  bool _isDataLoaded = false;
  DateTime? _lastRefreshTime;

  // Updated: Use new model
  final Company_Cloud _companyApplicationsService =
  Company_Cloud();
  List<StudentWithLatestApplication> _allStudents = [];
  List<StudentWithLatestApplication> _filteredStudents = [];
  String _searchQuery = '';
  ApplicationStatus? _selectedStatus;
  String? _selectedPeriod;
  String? _selectedSupervisor;

  // Pagination variables
  int _currentPage = 1;
  final int _pageSize = 15;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  final GlobalKey _statusFilterKey = GlobalKey();
  final GlobalKey _periodFilterKey = GlobalKey();
  final GlobalKey _supervisorFilterKey = GlobalKey();
  final FireStoreNotification fireStoreNotification = FireStoreNotification();

  bool _showFilters = false;
  final List<String> _statusOptions = [
    'All',
    'Pending',
    'Accepted',
    'Rejected',
  ];
  final List<String> _periodOptions = [
    'All',
    'Last 7 days',
    'Last 30 days',
    'Last 90 days',
  ];
  List<String> _supervisorOptions = ['All'];

  @override
  bool get wantKeepAlive => true;

  @override
  initState() {
    super.initState();
    _loadSupervisors();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      String companyId = currentUser.uid;

      // Get students with their latest applications
      final studentsStream = _companyApplicationsService
          .streamStudentsWithLatestApplications(companyId,isAuthority: widget.isAuthority, companyIds: widget.companyIds);

      final students = await studentsStream.first;

      if (mounted) {
        setState(() {
          _allStudents = students;
          _isDataLoaded = true;
          _applyFilters();
          // Calculate total application count
          applicationCount = _allStudents.fold(
              0,
                  (sum, student) => sum + student.totalApplications
          );
        });
      }
    } catch (e) {
      debugPrint("Error loading initial data: $e");
    }
  }

  Future<void> _loadMoreData() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Simulate loading more data (in real app, implement pagination in service)
      await Future.delayed(Duration(seconds: 1));

      // In a real app, you would load the next page here
      // For now, we'll just show that we've loaded all data
      setState(() {
        _hasMore = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      debugPrint("Error loading more data: $e");
      setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _loadSupervisors() async {
    try {
      // Load unique supervisors from applications
      _supervisorOptions = [
        'All',
        'Supervisor A',
        'Supervisor B',
        'Supervisor C',
      ];
    } catch (e) {
      debugPrint("Error loading supervisors: $e");
    }
  }

  Future<void> refreshData() async {
    if (_isRefreshing) return;

    final now = DateTime.now();
    if (_lastRefreshTime != null &&
        now.difference(_lastRefreshTime!) < Duration(seconds: 3)) {
      return;
    }

    setState(() {
      _isRefreshing = true;
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('No user is currently logged in.');
      }

      String companyId = currentUser.uid;

      // Get fresh data
      final studentsStream = _companyApplicationsService
          .streamStudentsWithLatestApplications(companyId,isAuthority: widget.isAuthority, companyIds: widget.companyIds);

      final students = await studentsStream.first;

      setState(() {
        _allStudents = students;
        _applyFilters();
        _isRefreshing = false;
        _isDataLoaded = true;
        _lastRefreshTime = DateTime.now();
        // Reset pagination
        _currentPage = 1;
        _hasMore = students.length >= _pageSize;
        // Calculate total application count
        applicationCount = _allStudents.fold(
            0,
                (sum, student) => sum + student.totalApplications
        );
      });

      _showRefreshSuccess();
    } catch (e) {
      setState(() {
        _isRefreshing = false;
      });

      _showRefreshError(e);
    }
  }

  void _applyFilters() {
    List<StudentWithLatestApplication> filtered = List.from(_allStudents);

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((student) {
        final studentName = student.studentName.toLowerCase();
        final institution = student.studentInstitution.toLowerCase();
        final course = student.studentCourse.toLowerCase();
        final internshipTitle = student.internshipTitle?.toLowerCase() ?? '';
        final query = _searchQuery.toLowerCase();

        return studentName.contains(query) ||
            institution.contains(query) ||
            course.contains(query) ||
            internshipTitle.contains(query);
      }).toList();
    }

    // Apply status filter
    if (_selectedStatus != null) {
      filtered = filtered.where((student) {
        final appStatus = student.latestApplication?.applicationStatus;
        if (appStatus == null) return false;
        return GeneralMethods.normalizeApplicationStatus(
          appStatus.toLowerCase(),
        ) ==
            _selectedStatus.toString().split('.').last.toLowerCase();
      }).toList();
    }

    // Apply period filter
    if (_selectedPeriod != null && _selectedPeriod != 'All') {
      final now = DateTime.now();
      DateTime cutoffDate;

      switch (_selectedPeriod) {
        case 'Last 7 days':
          cutoffDate = now.subtract(Duration(days: 7));
          break;
        case 'Last 30 days':
          cutoffDate = now.subtract(Duration(days: 30));
          break;
        case 'Last 90 days':
          cutoffDate = now.subtract(Duration(days: 90));
          break;
        default:
          cutoffDate = now.subtract(Duration(days: 365));
      }

      filtered = filtered.where((student) {
        return student.lastApplicationDate?.isAfter(cutoffDate) ?? false;
      }).toList();
    }

    // Apply supervisor filter
    if (_selectedSupervisor != null && _selectedSupervisor != 'All') {
      filtered = filtered.where((student) {
        // Replace with actual supervisor field
        return true;
      }).toList();
    }

    setState(() {
      _filteredStudents = filtered;
    });
  }

  void _showRefreshSuccess() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text('Applications refreshed'),
          ],
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(16),
      ),
    );
  }

  void _showRefreshError(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                error.toString().contains('Exception')
                    ? 'Refresh failed. Please check your connection.'
                    : 'Refresh failed: ${error.toString().length > 50 ? error.toString().substring(0, 50) + '...' : error}',
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: refreshData,
        ),
      ),
    );
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
        child: RefreshIndicator(
          onRefresh: refreshData,
          child: CustomScrollView(
            slivers: [
              // Top App Bar
              SliverAppBar(
                floating: true,
                snap: true,
                expandedHeight: 60,
                flexibleSpace: _buildTopAppBar(context),
              ),

              // Search and Filters Section
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    _buildSearchSection(context),
                    _buildFilterChips(context),
                  ],
                ),
              ),

              // Students List
              _buildStudentsList(context),

              // Load More Indicator
              SliverToBoxAdapter(
                child: _buildLoadMoreIndicator(),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: GeneralMethods.getUniqueHeroTag(),
        onPressed: () {
          GeneralMethods.navigateTo(context, CreateIndustrialTrainingPage(isAuthority: widget.isAuthority,));
        },
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTopAppBar(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? colorScheme.outline.withOpacity(0.1)
                : colorScheme.outline.withOpacity(0.08),
          ),
        ),
        color: isDark
            ? colorScheme.surfaceContainerHighest.withOpacity(0.8)
            : colorScheme.surfaceContainerLowest.withOpacity(0.8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Icon(
                    Icons.people_outline,
                    color: colorScheme.primary,
                    size: 24,
                  ),
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Student Applications',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        '${_allStudents.length} students • $applicationCount total applications',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_hasActiveFilters())
              IconButton(
                icon: Icon(Icons.filter_alt, color: colorScheme.primary),
                onPressed: () {
                  setState(() {
                    _showFilters = !_showFilters;
                  });
                },
                tooltip: 'Toggle filters',
              ),
            IconButton(
              icon: Icon(Icons.more_horiz, color: colorScheme.onSurfaceVariant),
              onPressed: () {
                _showMoreOptions(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchSection(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: isDark
              ? colorScheme.surfaceContainerHigh
              : colorScheme.surfaceContainer,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
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
                  decoration: InputDecoration(
                    hintText: 'Search student, university, or position...',
                    hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: TextStyle(color: colorScheme.onSurface),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                      _applyFilters();
                    });
                  },
                ),
              ),
            ),
            if (_searchQuery.isNotEmpty)
              IconButton(
                icon: Icon(Icons.clear, size: 18),
                onPressed: () {
                  setState(() {
                    _searchController.clear();
                    _searchQuery = '';
                    _applyFilters();
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Main Filter Button
            GestureDetector(
              onTap: () => _showFilterDialog(context),
              child: Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: _hasActiveFilters()
                      ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                      : Theme.of(context).colorScheme.surfaceContainer,
                  border: Border.all(
                    color: _hasActiveFilters()
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outline.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.filter_list,
                      size: 18,
                      color: _hasActiveFilters()
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Filters',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: _hasActiveFilters()
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (_hasActiveFilters())
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Status Filter
            _buildFilterChipWithMenu(
              context,
              key: _statusFilterKey,
              icon: Icons.arrow_drop_down,
              label: 'Status',
              getCurrentValue: () =>
              _selectedStatus?.toString().split('.').last ?? 'All',
              options: _statusOptions,
              onSelected: (value) {
                setState(() {
                  _selectedStatus = value == 'All'
                      ? null
                      : _stringToApplicationStatus(value);
                  _applyFilters();
                });
              },
            ),
            const SizedBox(width: 8),

            // Period Filter
            _buildFilterChipWithMenu(
              context,
              key: _periodFilterKey,
              icon: Icons.arrow_drop_down,
              label: 'Period',
              getCurrentValue: () => _selectedPeriod ?? 'All',
              options: _periodOptions,
              onSelected: (value) {
                setState(() {
                  _selectedPeriod = value == 'All' ? null : value;
                  _applyFilters();
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChipWithMenu(
      BuildContext context, {
        required GlobalKey key,
        required IconData icon,
        required String label,
        required String Function() getCurrentValue,
        required List<String> options,
        required Function(String) onSelected,
      }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final currentValue = getCurrentValue();
    final isActive = currentValue != 'All';

    return GestureDetector(
      onTap: () {
        _showMenuForChip(context, key, options, currentValue, onSelected);
      },
      child: Container(
        key: key,
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isActive
              ? colorScheme.primary.withOpacity(0.1)
              : colorScheme.surfaceContainer,
          border: Border.all(
            color: isActive
                ? colorScheme.primary
                : colorScheme.outline.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isActive
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              isActive ? currentValue : label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: isActive
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentsList(BuildContext context) {
    if (!_isDataLoaded) {
      return SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_filteredStudents.isEmpty && _isDataLoaded) {
      return SliverFillRemaining(
        child: _buildEmptyState(context),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
            (context, index) {
          if (index < _filteredStudents.length) {
            final student = _filteredStudents[index];
            return _buildStudentCard(context, student);
          }
          return null;
        },
        childCount: _filteredStudents.length,
      ),
    );
  }

  Widget _buildStudentCard(
      BuildContext context,
      StudentWithLatestApplication student,
      ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.surfaceContainerHighest
            : colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            _navigateToStudentApplications(student);
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Student Header
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Student Avatar
                    CircleAvatar(
                      radius: 24,
                      backgroundImage: student.studentImageUrl != null
                          ? NetworkImage(student.studentImageUrl!)
                          : null,
                      backgroundColor: colorScheme.surfaceContainer,
                      child: student.studentImageUrl == null
                          ? Text(
                        student.studentName[0].toUpperCase(),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                          : null,
                    ),
                    SizedBox(width: 12),

                    // Student Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            student.studentName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            student.studentInstitution,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            '${student.studentCourse} • ${student.studentLevel}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Application Count Badge
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        student.applicationsInfo,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 12),

                // Latest Application Info
                if (student.hasApplication)
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black.withOpacity(0.2) : colorScheme.surfaceVariant.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Application Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                student.internshipTitle!,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: student.statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: student.statusColor.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    student.statusIcon,
                                    size: 12,
                                    color: student.statusColor,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    student.internshipStatus!,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: student.statusColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 8),

                        // Application Details
                        if (student.startDate != null || student.duration != null)
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 14,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              SizedBox(width: 6),
                              if (student.startDate != null && student.endDate != null)
                                Expanded(
                                  child: Text(
                                    '${_formatDate(student.startDate!)} - ${_formatDate(student.endDate!)}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              if (student.duration != null)
                                Text(
                                  ' • ${student.duration}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),

                        SizedBox(height: 4),

                        // Last Applied
                        Row(
                          children: [
                            Icon(
                              Icons.access_time_outlined,
                              size: 14,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Last applied ${student.formattedLastDate}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black.withOpacity(0.2) : colorScheme.surfaceVariant.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'No applications submitted',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),

                SizedBox(height: 12),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          _navigateToStudentApplications(student);
                        },
                        icon: Icon(Icons.list_alt_outlined, size: 16),
                        label: Text('View All Applications'),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: colorScheme.outline.withOpacity(0.3),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    if (student.hasApplication)
                      OutlinedButton.icon(
                        onPressed: () {
                          _showApplicationDetails(context, student);
                        },
                        icon: Icon(Icons.visibility_outlined, size: 16),
                        label: Text('Details'),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: colorScheme.primary.withOpacity(0.3),
                          ),
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

  Widget _buildLoadMoreIndicator() {
    if (!_hasMore && _filteredStudents.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Text(
            'All students loaded',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    if (_isLoadingMore) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_hasMore && _filteredStudents.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: ElevatedButton.icon(
            onPressed: _loadMoreData,
            icon: Icon(Icons.expand_more_rounded),
            label: Text('Load More Students'),
          ),
        ),
      );
    }

    return SizedBox();
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: colorScheme.outline,
            ),
            SizedBox(height: 16),
            Text(
              _hasActiveFilters()
                  ? 'No students match your filters'
                  : 'No student applications yet',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Text(
              _hasActiveFilters()
                  ? 'Try adjusting your filters to see more results'
                  : 'Student applications will appear here when submitted',
              style: TextStyle(
                color: colorScheme.outline,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            if (_hasActiveFilters())
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _searchQuery = '';
                    _selectedStatus = null;
                    _selectedPeriod = null;
                    _selectedSupervisor = null;
                    _searchController.clear();
                    _applyFilters();
                  });
                },
                icon: Icon(Icons.clear_all, size: 18),
                label: Text('Clear All Filters'),
              ),
            if (!_hasActiveFilters())
              ElevatedButton.icon(
                onPressed: refreshData,
                icon: Icon(Icons.refresh, size: 18),
                label: Text('Refresh'),
              ),
          ],
        ),
      ),
    );
  }

  void _navigateToStudentApplications(StudentWithLatestApplication student) {
    // Navigate to page showing all applications for this student
    GeneralMethods.navigateTo(context, SpecificStudentApplicationsPage(isAuthority: widget.isAuthority,companyId: student.latestApplication?.internship.company.id??"", studentUid: student.student.uid,companyIds: widget.companyIds,));
  }

  void _showApplicationDetails(
      BuildContext context,
      StudentWithLatestApplication student,
      ) {
    if (student.latestApplication == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Application Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Student Info
              ListTile(
                leading: CircleAvatar(
                  backgroundImage: student.studentImageUrl != null
                      ? NetworkImage(student.studentImageUrl!)
                      : null,
                  child: student.studentImageUrl == null
                      ? Text(student.studentName[0])
                      : null,
                ),
                title: Text(student.studentName),
                subtitle: Text('${student.totalApplications} applications'),
              ),

              Divider(),

              // Latest Application
              if (student.hasApplication) ...[
                Text(
                  'Latest Application',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 8),
                _buildDetailRow('Position', student.internshipTitle ?? 'N/A'),
                _buildDetailRow('Status', student.internshipStatus ?? 'N/A'),
                if (student.startDate != null)
                  _buildDetailRow('Start Date', _formatDate(student.startDate!)),
                if (student.endDate != null)
                  _buildDetailRow('End Date', _formatDate(student.endDate!)),
                _buildDetailRow('Applied', student.formattedLastDate),
                SizedBox(height: 8),
              ],

              // Student Details
              Text(
                'Student Details',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              _buildDetailRow('Institution', student.studentInstitution),
              _buildDetailRow('Course', student.studentCourse),
              _buildDetailRow('Level', student.studentLevel),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToStudentApplications(student);
            },
            child: Text('View All Applications'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showMoreOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.refresh),
                title: Text('Refresh'),
                onTap: () {
                  Navigator.pop(context);
                  refreshData();
                },
              ),
              ListTile(
                leading: Icon(Icons.sort),
                title: Text('Sort by'),
                onTap: () {
                  Navigator.pop(context);
                  _showSortOptions(context);
                },
              ),
              if (_hasActiveFilters())
                ListTile(
                  leading: Icon(Icons.clear_all, color: Colors.red),
                  title: Text(
                    'Clear all filters',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _searchQuery = '';
                      _selectedStatus = null;
                      _selectedPeriod = null;
                      _selectedSupervisor = null;
                      _searchController.clear();
                      _applyFilters();
                    });
                  },
                ),
              ListTile(
                leading: Icon(Icons.close),
                title: Text('Cancel'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSortOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Sort By',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ListTile(
                leading: Icon(Icons.sort_by_alpha),
                title: Text('Name (A-Z)'),
                onTap: () {
                  Navigator.pop(context);
                  _sortStudentsByName(true);
                },
              ),
              ListTile(
                leading: Icon(Icons.sort_by_alpha),
                title: Text('Name (Z-A)'),
                onTap: () {
                  Navigator.pop(context);
                  _sortStudentsByName(false);
                },
              ),
              ListTile(
                leading: Icon(Icons.date_range),
                title: Text('Recently Applied'),
                onTap: () {
                  Navigator.pop(context);
                  _sortStudentsByDate(true);
                },
              ),
              ListTile(
                leading: Icon(Icons.date_range),
                title: Text('Oldest Applied'),
                onTap: () {
                  Navigator.pop(context);
                  _sortStudentsByDate(false);
                },
              ),
              ListTile(
                leading: Icon(Icons.close),
                title: Text('Cancel'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  void _sortStudentsByName(bool ascending) {
    setState(() {
      _filteredStudents.sort((a, b) {
        return ascending
            ? a.studentName.compareTo(b.studentName)
            : b.studentName.compareTo(a.studentName);
      });
    });
  }

  void _sortStudentsByDate(bool recentFirst) {
    setState(() {
      _filteredStudents.sort((a, b) {
        final dateA = a.lastApplicationDate ?? DateTime(1900);
        final dateB = b.lastApplicationDate ?? DateTime(1900);
        return recentFirst
            ? dateB.compareTo(dateA)
            : dateA.compareTo(dateB);
      });
    });
  }

  bool _hasActiveFilters() {
    return _searchQuery.isNotEmpty ||
        _selectedStatus != null ||
        (_selectedPeriod != null && _selectedPeriod != 'All') ||
        (_selectedSupervisor != null && _selectedSupervisor != 'All');
  }

  ApplicationStatus _stringToApplicationStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return ApplicationStatus.pending;
      case 'accepted':
        return ApplicationStatus.accepted;
      case 'rejected':
        return ApplicationStatus.rejected;
      default:
        return ApplicationStatus.pending;
    }
  }

  void _showMenuForChip(
      BuildContext context,
      GlobalKey key,
      List<String> options,
      String currentValue,
      Function(String) onSelected,
      ) {
    final RenderBox renderBox =
    key.currentContext?.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + renderBox.size.height + 4,
        offset.dx + renderBox.size.width,
        offset.dy + renderBox.size.height + 4,
      ),
      items: options.map((option) {
        return PopupMenuItem<String>(
          value: option,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(option),
              if (option == currentValue)
                Icon(
                  Icons.check,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
            ],
          ),
        );
      }).toList(),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ).then((selectedValue) {
      if (selectedValue != null) {
        onSelected(selectedValue);
      }
    });
  }

  void _showFilterDialog(BuildContext context) {
    // Keep existing _showFilterDialog implementation, but update to work with new model
    showDialog(
      context: context,
      builder: (context) {
        ApplicationStatus? tempStatus = _selectedStatus;
        String? tempPeriod = _selectedPeriod;
        String? tempSupervisor = _selectedSupervisor;

        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              insetPadding: const EdgeInsets.all(20),
              child: Container(
                constraints: BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Filter Options',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, size: 20),
                            onPressed: () => Navigator.pop(context),
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFilterSection(
                            context,
                            title: 'Status',
                            options: _statusOptions,
                            selectedValue:
                            tempStatus?.toString().split('.').last ?? 'All',
                            onChanged: (value) {
                              setState(() {
                                tempStatus = value == 'All'
                                    ? null
                                    : _stringToApplicationStatus(value);
                              });
                            },
                          ),
                          SizedBox(height: 16),
                          _buildFilterSection(
                            context,
                            title: 'Period',
                            options: _periodOptions,
                            selectedValue: tempPeriod ?? 'All',
                            onChanged: (value) {
                              setState(() {
                                tempPeriod = value == 'All' ? null : value;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: Theme.of(context).dividerColor,
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text('Cancel'),
                          ),
                          SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _selectedStatus = tempStatus;
                                _selectedPeriod = tempPeriod;
                                _selectedSupervisor = tempSupervisor;
                                _applyFilters();
                              });
                              Navigator.pop(context);
                            },
                            child: Text('Apply'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Keep existing helper methods (they remain the same)
  Color _getStatusColor(ApplicationStatus status) {
    switch (status) {
      case ApplicationStatus.accepted:
        return Colors.green;
      case ApplicationStatus.pending:
        return Colors.orange;
      case ApplicationStatus.rejected:
        return Colors.red;
    }
  }

// ... (keep all other existing methods that don't need changes)

  Widget _buildFilterSection(
      BuildContext context, {
        required String title,
        required List<String> options,
        required String selectedValue,
        required Function(String) onChanged,
      }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final isSelected = selectedValue == option;
            return FilterChip(
              label: Text(option),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  onChanged(option);
                }
              },
              selectedColor: colorScheme.primary.withOpacity(0.2),
              checkmarkColor: colorScheme.primary,
              labelStyle: theme.textTheme.labelMedium?.copyWith(
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

}