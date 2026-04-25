import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:itc_institute_admin/backgroundTask/backgroundTask.dart';
import 'package:itc_institute_admin/backgroundTask/backgroundTaskRegistry.dart';
import 'package:itc_institute_admin/backgroundTask/widget/migrationStatusWidget.dart';
import 'package:itc_institute_admin/generalmethods/GeneralMethods.dart';
import 'package:itc_institute_admin/itc_logic/firebase/company_cloud.dart';
import 'package:itc_institute_admin/model/student.dart';
import 'package:itc_institute_admin/model/company.dart';
import 'package:itc_institute_admin/model/traineeRecord.dart';
import 'package:itc_institute_admin/view/home/student/studentDetails.dart';
import 'package:url_launcher/url_launcher.dart';
import '../itc_logic/firebase/general_cloud.dart';
import '../itc_logic/service/tranineeService.dart';
import '../migrationService/migrationService.dart';
import '../model/studentApplication.dart';
import 'home/industrailTraining/applications/studentApplicationsPage.dart';
import 'home/studentList/traineeDetailsPage.dart';
import 'package:path_provider/path_provider.dart';

class StudentListPage extends StatefulWidget {
  final Company company;
  final bool isAuthority;

  const StudentListPage({Key? key, required this.company, required this.isAuthority})
      : super(key: key);

  @override
  State<StudentListPage> createState() => _StudentListPageState();
}

class _StudentListPageState extends State<StudentListPage> {
  late final TraineeService _traineeService;
  final ITCFirebaseLogic _itcFirebaseLogic = ITCFirebaseLogic(FirebaseAuth.instance.currentUser!.uid);
  final BackgroundTaskManager backgroundTaskManager = BackgroundTaskManager();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // All trainee lists
  List<TraineeRecord> _pendingTrainees = [];
  List<TraineeRecord> _currentTrainees = [];
  List<TraineeRecord> _upcomingTrainees = [];
  List<TraineeRecord> _rejectedTrainees = [];
  List<TraineeRecord> _completedTrainees = [];
  List<TraineeRecord> _onHoldTrainees = [];
  List<TraineeRecord> _withdrawnTrainees = [];
  List<TraineeRecord> _terminatedTrainees = [];

  // Selected view type
  String _selectedView = 'Active Trainees';

  // Search functionality
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Combined list for display
  List<TraineeRecord> _displayTrainees = [];

  bool _isLoading = true;
  String _error = '';

  // View options with icons and colors
  final List<Map<String, dynamic>> _viewOptions = [
    {
      'label': 'Active Trainees',
      'shortLabel': 'Active',
      'icon': Icons.work,
      'color': Colors.blue,
      'count': 0,
    },
    {
      'label': 'Pending Applications',
      'shortLabel': 'Pending',
      'icon': Icons.pending_actions,
      'color': Colors.orange,
      'count': 0,
    },
    {
      'label': 'On-Hold Trainees',
      'shortLabel': 'On Hold',
      'icon': Icons.pause_circle,
      'color': Colors.purple,
      'count': 0,
    },
    {
      'label': 'Upcoming Trainees',
      'shortLabel': 'Upcoming',
      'icon': Icons.schedule,
      'color': Colors.teal,
      'count': 0,
    },
    {
      'label': 'Completed Trainees',
      'shortLabel': 'Completed',
      'icon': Icons.check_circle,
      'color': Colors.green,
      'count': 0,
    },
    {
      'label': 'Rejected Applications',
      'shortLabel': 'Rejected',
      'icon': Icons.cancel,
      'color': Colors.red,
      'count': 0,
    },
    {
      'label': 'Withdrawn Trainees',
      'shortLabel': 'Withdrawn',
      'icon': Icons.exit_to_app,
      'color': Colors.grey,
      'count': 0,
    },
    {
      'label': 'Terminated Trainees',
      'shortLabel': 'Terminated',
      'icon': Icons.gavel,
      'color': Colors.brown,
      'count': 0,
    },
  ];

  @override
  void initState() {
    super.initState();
    _traineeService = TraineeService(FirebaseAuth.instance.currentUser!.uid);
    _loadTrainees();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTrainees() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final companyId = widget.company.id;
      final companyIds = widget.company.originalAuthority?.linkedCompanies ?? [];

      // Load all trainee categories in parallel for better performance
      final results = await Future.wait([
        _traineeService.getTraineesByStatus(
          companyId: companyId,
          status: TraineeStatus.pending,
          isAuthority: widget.isAuthority,
          companyIds: companyIds,
        ),
        _traineeService.getCurrentTrainees(
          companyId: companyId,
          isAuthority: widget.isAuthority,
          companyIds: companyIds,
        ),
        _traineeService.getTraineesByStatus(
          companyId: companyId,
          status: TraineeStatus.onHold,
          isAuthority: widget.isAuthority,
          companyIds: companyIds,
        ),
        _traineeService.getUpcomingTrainees(
          companyId: companyId,
          isAuthority: widget.isAuthority,
          companyIds: companyIds,
        ),
        _traineeService.getTraineesByStatus(
          companyId: companyId,
          status: TraineeStatus.rejected,
          isAuthority: widget.isAuthority,
          companyIds: companyIds,
        ),
        _traineeService.getTraineesByStatus(
          companyId: companyId,
          status: TraineeStatus.completed,
          isAuthority: widget.isAuthority,
          companyIds: companyIds,
        ),
        _traineeService.getTraineesByStatus(
          companyId: companyId,
          status: TraineeStatus.withdrawn,
          isAuthority: widget.isAuthority,
          companyIds: companyIds,
        ),
        _traineeService.getTraineesByStatus(
          companyId: companyId,
          status: TraineeStatus.terminated,
          isAuthority: widget.isAuthority,
          companyIds: companyIds,
        ),
      ]);

      _pendingTrainees = results[0];
      _currentTrainees = results[1];
      _onHoldTrainees = results[2];
      _upcomingTrainees = results[3];
      _rejectedTrainees = results[4];
      _completedTrainees = results[5];
      _withdrawnTrainees = results[6];
      _terminatedTrainees = results[7];

      // Update counts in view options
      _updateViewCounts();

      // Set initial display to active trainees (prioritized)
      _updateDisplayList();

      setState(() {
        _isLoading = false;
      });

      debugPrint("Loaded: ${_currentTrainees.length} active, "
          "${_pendingTrainees.length} pending, "
          "${_onHoldTrainees.length} on-hold, "
          "${_upcomingTrainees.length} upcoming, "
          "${_completedTrainees.length} completed, "
          "${_rejectedTrainees.length} rejected, "
          "${_withdrawnTrainees.length} withdrawn, "
          "${_terminatedTrainees.length} terminated");
    } catch (e, stackTrace) {
      debugPrint("Error in _loadTrainees: $e");
      debugPrint("Stack trace: $stackTrace");
      setState(() {
        _error = 'Failed to load trainees: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _updateViewCounts() {
    for (var option in _viewOptions) {
      switch (option['label']) {
        case 'Active Trainees':
          option['count'] = _currentTrainees.length;
          break;
        case 'Pending Applications':
          option['count'] = _pendingTrainees.length;
          break;
        case 'On-Hold Trainees':
          option['count'] = _onHoldTrainees.length;
          break;
        case 'Upcoming Trainees':
          option['count'] = _upcomingTrainees.length;
          break;
        case 'Completed Trainees':
          option['count'] = _completedTrainees.length;
          break;
        case 'Rejected Applications':
          option['count'] = _rejectedTrainees.length;
          break;
        case 'Withdrawn Trainees':
          option['count'] = _withdrawnTrainees.length;
          break;
        case 'Terminated Trainees':
          option['count'] = _terminatedTrainees.length;
          break;
      }
    }
  }

  void _updateDisplayList() {
    List<TraineeRecord> sourceList;

    switch (_selectedView) {
      case 'Active Trainees':
        sourceList = _currentTrainees;
        break;
      case 'Pending Applications':
        sourceList = _pendingTrainees;
        break;
      case 'On-Hold Trainees':
        sourceList = _onHoldTrainees;
        break;
      case 'Upcoming Trainees':
        sourceList = _upcomingTrainees;
        break;
      case 'Completed Trainees':
        sourceList = _completedTrainees;
        break;
      case 'Rejected Applications':
        sourceList = _rejectedTrainees;
        break;
      case 'Withdrawn Trainees':
        sourceList = _withdrawnTrainees;
        break;
      case 'Terminated Trainees':
        sourceList = _terminatedTrainees;
        break;
      default:
        sourceList = _currentTrainees;
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      _displayTrainees = sourceList.where((trainee) {
        final name = trainee.studentName.toLowerCase();
        final department = trainee.department.toLowerCase();
        final query = _searchQuery.toLowerCase();

        return name.contains(query) ||
            department.contains(query);
      }).toList();
    } else {
      _displayTrainees = List.from(sourceList);
    }

    // Sort active trainees by priority (progress, days remaining, etc.)
    if (_selectedView == 'Active Trainees') {
      _displayTrainees.sort((a, b) {
        // Prioritize by progress (higher first)
        if (a.progress != b.progress) {
          return b.progress.compareTo(a.progress);
        }
        // Then by days remaining (lower first - urgent)
        if (a.daysRemaining != null && b.daysRemaining != null) {
          return a.daysRemaining!.compareTo(b.daysRemaining!);
        }
        return 0;
      });
    }

    setState(() {});
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
    _updateDisplayList();
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
    });
    _updateDisplayList();
  }

  void _showTraineeDetails(TraineeRecord trainee) {
    GeneralMethods.navigateTo(
      context,
      TraineeDetailPage(
        isAuthority: widget.isAuthority,
        trainee: trainee,
        tabIndex: _getTabIndexFromView(),
        traineeService: _traineeService,
        onStatusChanged: _loadTrainees,
      ),
    );
  }

  int _getTabIndexFromView() {
    switch (_selectedView) {
      case 'Pending Applications': return 0;
      case 'Active Trainees': return 1;
      case 'On-Hold Trainees': return 2;
      case 'Upcoming Trainees': return 3;
      case 'Rejected Applications': return 4;
      case 'Completed Trainees': return 5;
      default: return 1;
    }
  }

  Future<void> _updateTraineeStatus({
    required TraineeRecord trainee,
    required TraineeStatus newStatus,
    String? reason,
  }) async {
    try {
      final success = await _traineeService.updateTraineeStatus(
        traineeId: trainee.id,
        newStatus: newStatus,
        reason: reason,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status updated to ${newStatus.displayName}'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        _loadTrainees();
      }
    } catch (e, s) {
      debugPrintStack(stackTrace: s);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Future<void> _handleApplicationDecision({
    required TraineeRecord trainee,
    required bool accept,
    String? reason,
  }) async {
    try {
      final application = await _getApplicationForTrainee(trainee);

      if (application == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cannot find application details'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      final status = accept ? 'accepted' : 'rejected';
      final finalReason = reason ?? (accept ? 'Application accepted' : 'Application rejected');

      final success = await _traineeService.updateApplicationStatusWithTraineeSync(
        isAuthority: widget.isAuthority,
        companyId: trainee.companyId,
        internshipId: application.internship.id!,
        studentId: trainee.studentId,
        applicationId: trainee.applicationId!,
        status: status,
        reason: finalReason,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Application $status'),
            backgroundColor: accept ? Colors.green : Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadTrainees();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update application: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<StudentApplication?> _getApplicationForTrainee(TraineeRecord trainee) async {
    try {
      if (trainee.applicationId == null) return null;

      final applications = await _traineeService.getPendingApplications(trainee.companyId);
      return applications.firstWhere(
            (app) => app.id == trainee.applicationId,
        orElse: () => applications.firstWhere(
              (app) => app.student.uid == trainee.studentId,
        ),
      );
    } catch (e) {
      debugPrint('Error getting application for trainee: $e');
      return null;
    }
  }

  Map<String, dynamic> _getCurrentViewOption() {
    return _viewOptions.firstWhere(
          (option) => option['label'] == _selectedView,
      orElse: () => _viewOptions[0],
    );
  }

  String _getDisplayLabel() {
    final current = _getCurrentViewOption();
    return current['shortLabel'] ?? current['label'];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentView = _getCurrentViewOption();
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Trainee Management',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              widget.company.name,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.brightness == Brightness.dark
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onPrimary,
              ),
            ),
          ],
        ),
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        actions: [
          // Responsive actions - hide some on very small screens
          if (!isSmallScreen) ...[
            IconButton(
              icon: const Icon(Icons.analytics),
              onPressed: _showStatistics,
              tooltip: 'Statistics',
            ),
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: _exportData,
              tooltip: 'Export Data',
            ),
          ] else
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'stats') {
                  _showStatistics();
                } else if (value == 'export') {
                  _exportData();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'stats',
                  child: Row(
                    children: [
                      Icon(Icons.analytics, size: 20),
                      SizedBox(width: 8),
                      Text('Statistics'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'export',
                  child: Row(
                    children: [
                      Icon(Icons.download, size: 20),
                      SizedBox(width: 8),
                      Text('Export Data'),
                    ],
                  ),
                ),
              ],
            ),
          MigrationStatusIcon(onRefresh: startMigration),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTrainees,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState(theme)
          : _error.isNotEmpty
          ? _buildErrorState(theme)
          : Column(
        children: [
          // Stats Overview Cards - Responsive layout
          _buildStatsOverview(theme, isSmallScreen),

          // View Selector and Search Bar - Stack on small screens
          _buildViewSelector(theme, currentView, isSmallScreen),

          // Trainee List
          Expanded(
            child: _displayTrainees.isEmpty
                ? _buildEmptyState(theme, currentView)
                : _buildTraineeList(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsOverview(ThemeData theme, bool isSmallScreen) {
    final totalActive = _currentTrainees.length;
    final totalPending = _pendingTrainees.length;
    final totalCompleted = _completedTrainees.length;
    final totalOnHold = _onHoldTrainees.length;

    if (isSmallScreen) {
      // Horizontal scrollable list for small screens
      return Container(
        height: 100,
        padding: const EdgeInsets.all(16),
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            _buildSmallStatCard(theme, 'Active', totalActive.toString(), Icons.work, Colors.blue),
            const SizedBox(width: 12),
            _buildSmallStatCard(theme, 'Pending', totalPending.toString(), Icons.pending_actions, Colors.orange),
            const SizedBox(width: 12),
            _buildSmallStatCard(theme, 'Completed', totalCompleted.toString(), Icons.check_circle, Colors.green),
            const SizedBox(width: 12),
            _buildSmallStatCard(theme, 'On Hold', totalOnHold.toString(), Icons.pause_circle, Colors.purple),
          ],
        ),
      );
    }

    // Original grid layout for larger screens
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(child: _buildStatCard(theme, label:'Active', value:totalActive.toString(), icon:Icons.work,color: Colors.blue)),
          const SizedBox(width: 12),
          Expanded(child: _buildStatCard(theme, label:'Pending', value:totalPending.toString(),icon: Icons.pending_actions, color:Colors.orange,)),
          const SizedBox(width: 12),
          Expanded(child: _buildStatCard(theme, label: 'Completed', value:totalCompleted.toString(), icon:Icons.check_circle, color:Colors.green)),
          const SizedBox(width: 12),
          Expanded(child: _buildStatCard(theme, label: 'On Hold', value:totalOnHold.toString(), icon:Icons.pause_circle,color: Colors.purple)),
        ],
      ),
    );
  }

  Widget _buildSmallStatCard(ThemeData theme, String label, String value, IconData icon, Color color) {
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: 100,
      height: 100, // Fixed height
      padding: EdgeInsets.zero, // Remove padding from container
      decoration: BoxDecoration(
        color: isDark ? theme.cardColor : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(4), // Move padding here
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.max, // Use max to fill the space
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 12),
            ),
            const SizedBox(height: 2),

            // Value text
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            // Label text
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
      ThemeData theme, {
        required String label,
        required String value,
        required IconData icon,
        required Color color,
      }) {
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? theme.cardColor : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewSelector(ThemeData theme, Map<String, dynamic> currentView, bool isSmallScreen) {
    final isDark = theme.brightness == Brightness.dark;

    if (isSmallScreen) {
      // Stack vertically on small screens
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            // View Dropdown - Full width
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isDark ? theme.cardColor : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedView,
                  isExpanded: true,
                  icon: Icon(
                    Icons.arrow_drop_down,
                    color: theme.iconTheme.color,
                  ),
                  style: theme.textTheme.bodyMedium,
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedView = newValue;
                      });
                      _updateDisplayList();
                    }
                  },
                  items: _viewOptions.map<DropdownMenuItem<String>>((option) {
                    return DropdownMenuItem<String>(
                      value: option['label'],
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: (option['color'] as Color).withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              option['icon'],
                              color: option['color'],
                              size: 14,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              option['shortLabel'] ?? option['label'],
                              style: theme.textTheme.bodyMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (option['count'] > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: option['color'].withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                option['count'].toString(),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: option['color'],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Search Bar
            Container(
              height: 48,
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? theme.cardColor : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Icon(
                    Icons.search,
                    color: theme.iconTheme.color?.withOpacity(0.5),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: 'Search...',
                        hintStyle: theme.textTheme.bodySmall?.copyWith(
                          color: theme.hintColor,
                        ),
                        border: InputBorder.none,
                      ),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    IconButton(
                      icon: Icon(
                        Icons.clear,
                        size: 18,
                        color: theme.iconTheme.color,
                      ),
                      onPressed: _clearSearch,
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Original side-by-side layout for larger screens
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // View Dropdown
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isDark ? theme.cardColor : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedView,
                  isExpanded: true,
                  icon: Icon(
                    Icons.arrow_drop_down,
                    color: theme.iconTheme.color,
                  ),
                  style: theme.textTheme.bodyMedium,
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedView = newValue;
                      });
                      _updateDisplayList();
                    }
                  },
                  items: _viewOptions.map<DropdownMenuItem<String>>((option) {
                    return DropdownMenuItem<String>(
                      value: option['label'],
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: (option['color'] as Color).withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              option['icon'],
                              color: option['color'],
                              size: 14,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              option['label'],
                              style: theme.textTheme.bodyMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (option['count'] > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: option['color'].withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                option['count'].toString(),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: option['color'],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Search Bar
          Expanded(
            flex: 3,
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: isDark ? theme.cardColor : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Icon(
                    Icons.search,
                    color: theme.iconTheme.color?.withOpacity(0.5),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: 'Search by name, department...',
                        hintStyle: theme.textTheme.bodySmall?.copyWith(
                          color: theme.hintColor,
                        ),
                        border: InputBorder.none,
                      ),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    IconButton(
                      icon: Icon(
                        Icons.clear,
                        size: 18,
                        color: theme.iconTheme.color,
                      ),
                      onPressed: _clearSearch,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTraineeList(ThemeData theme) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _displayTrainees.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final trainee = _displayTrainees[index];

        return TraineeCard(
          onDoubleTab: () {
            GeneralMethods.navigateTo(
              context,
              SpecificStudentApplicationsPage(
                companyId: trainee.companyId,
                studentUid: trainee.studentId,
                studentName: trainee.studentName,
                isAuthority: widget.isAuthority,
                companyIds: widget.company.originalAuthority?.linkedCompanies ?? [],
              ),
            );
          },
          trainee: trainee,
          isDark: theme.brightness == Brightness.dark,
          tabIndex: _getTabIndexFromView(),
          onTap: () => _showTraineeDetails(trainee),
          onAccept: _selectedView == 'Pending Applications'
              ? () => _handleApplicationDecision(
            trainee: trainee,
            accept: true,
          )
              : null,
          onReject: _selectedView == 'Pending Applications'
              ? () => _handleApplicationDecision(
            trainee: trainee,
            accept: false,
          )
              : null,
          onStartTraining: _selectedView == 'On-Hold Trainees' || _selectedView == 'Upcoming Trainees'
              ? () => _updateTraineeStatus(
            trainee: trainee,
            newStatus: TraineeStatus.active,
            reason: 'Training started/resumed',
          )
              : null,
          onCompleteTraining: _selectedView == 'Active Trainees'
              ? () => _updateTraineeStatus(
            trainee: trainee,
            newStatus: TraineeStatus.completed,
            reason: 'Training completed successfully',
          )
              : null,
        );
      },
    );
  }

  Widget _buildEmptyState(ThemeData theme, Map<String, dynamic> currentView) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: currentView['color'].withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _searchQuery.isNotEmpty ? Icons.search_off : currentView['icon'],
              size: 64,
              color: currentView['color'],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'No matching trainees found'
                : 'No ${_selectedView.toLowerCase()}',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try adjusting your search criteria'
                : 'There are no trainees in this category',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Loading trainees...',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Error Loading Trainees',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadTrainees,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  // Keep all your existing methods below (_showStatistics, _syncWithApplication, etc.)
  void startMigration() async {
    final migrationService = MigrationService(FirebaseAuth.instance.currentUser!.uid);
    unawaited(
      migrationService.startMigration().catchError((e, s) {
        debugPrint("background Task failed with error $e");
        debugPrintStack(stackTrace: s);
      }),
    );
  }

  Future<void> _showStatistics() async {
    try {
      final stats = await _traineeService.getTraineeStatistics(widget.company.id);

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Training Statistics'),
          content: Container(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatItem('Total Trainees', stats['total']?.toString() ?? '0'),
                  _buildStatItem('Pending', stats['pending']?.toString() ?? '0'),
                  _buildStatItem('Accepted', stats['accepted']?.toString() ?? '0'),
                  _buildStatItem('Active', stats['active']?.toString() ?? '0'),
                  _buildStatItem('Completed', stats['completed']?.toString() ?? '0'),
                  _buildStatItem('Terminated/Rejected', stats['terminated']?.toString() ?? '0'),
                  _buildStatItem('Withdrawn', stats['withdrawn']?.toString() ?? '0'),
                  const Divider(),
                  _buildStatItem('Average Progress', '${stats['averageProgress'] ?? '0'}%'),
                  _buildStatItem('Completion Rate', '${stats['completionRate'] ?? '0'}%'),
                  _buildStatItem('Active Rate', '${stats['activeRate'] ?? '0'}%'),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load statistics: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _syncWithApplication() async {
     return;
    try {
      setState(() {
        _isLoading = true;
        _error = '';
      });
      await _traineeService.syncTraineesFromApplications(
        widget.company.id,
        widget.isAuthority,
      );
      _loadTrainees();
    } catch (error, stack) {
      debugPrint("error $error");
      debugPrintStack(stackTrace: stack);
    }
  }

  Future<void> _exportData() async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      final data = await _traineeService.exportTraineeData(widget.company.id);

      if (!mounted) return;

      // Generate the report
      String report = _generateTraineeReport(data);

      // Save to file
      final String filePath = await _saveReportToFile(report);

       if(filePath == 'not-found')
         {
           Fluttertoast.showToast(msg: "File not found");
           return;
         }

      // Show success message with options
      messenger.showSnackBar(
        SnackBar(
          content: Text('Report saved: ${data.length} trainees'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'VIEW',
            textColor: Colors.white,
            onPressed: () async {
              // Close the snackbar first
              ScaffoldMessenger.of(context).hideCurrentSnackBar();

              // Open the file in file explorer
              await _openFileInExplorer(filePath);
            },
          ),
        ),
      );
    } catch (e, s) {
      debugPrintStack(stackTrace: s);

      if (!mounted) return;

      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to export data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }


  Future<void> _openFileInExplorer(String filePath) async {
    try {
      final file = File(filePath);

      if (!await file.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('File not found'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // For Android, we need to ensure the file is accessible
      if (Platform.isAndroid) {
        // On Android, we can use the file:// scheme
        final uri = Uri.file(filePath);
        debugPrint("canluanch ${await canLaunchUrl(uri)}");

        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        } else {
          // Fallback: Show a dialog with the file path
          _showFileLocationDialog(filePath);
        }
      } else if (Platform.isIOS) {
        // On iOS, files are sandboxed, so we might need to share instead
        final uri = Uri.file(filePath);

        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        } else {
          _showShareOption(filePath);
        }
      } else {
        // For other platforms (Windows, macOS, Linux)
        final uri = Uri.file(filePath);
        await launchUrl(uri);
      }
    } catch (e, s) {
      debugPrint('Error opening file: $e');
      debugPrintStack(stackTrace: s);

      if (mounted) {
        // Fallback: Show dialog with file path
        _showFileLocationDialog(filePath);
      }
    }
  }

  void _showFileLocationDialog(String filePath) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('File Location'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('File saved at:'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                filePath,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              // Copy to clipboard
              _copyToClipboard(filePath);
              Navigator.pop(context);
            },
            child: const Text('Copy Path'),
          ),
        ],
      ),
    );
  }

  void _showShareOption(String filePath) {
    // For iOS, you might want to use the share package
    // But for now, show the file location
    _showFileLocationDialog(filePath);
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Path copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }
  Widget _buildStatItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  String _generateTraineeReport(List<Map<String, dynamic>> trainees) {
    final StringBuffer report = StringBuffer();

    // Header
    report.writeln("TRAINEE MANAGEMENT REPORT");
    report.writeln("Generated: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}");
    report.writeln("Company: ${widget.company.name}");
    report.writeln("Total Trainees: ${trainees.length}");
    report.writeln("=" * 80);
    report.writeln();

    // Statistics by status
    final statusCount = <String, int>{};
    for (var trainee in trainees) {
      final status = trainee['status'] as String;
      statusCount[status] = (statusCount[status] ?? 0) + 1;
    }

    report.writeln("STATUS SUMMARY:");
    statusCount.forEach((status, count) {
      report.writeln("  $status: $count");
    });
    report.writeln();

    // Department distribution
    final deptCount = <String, int>{};
    for (var trainee in trainees) {
      final dept = trainee['department'] as String? ?? 'Not Assigned';
      deptCount[dept] = (deptCount[dept] ?? 0) + 1;
    }

    report.writeln("DEPARTMENT DISTRIBUTION:");
    deptCount.forEach((dept, count) {
      report.writeln("  $dept: $count");
    });
    report.writeln();

    // Progress statistics
    double totalProgress = 0;
    int completedCount = 0;
    int inProgressCount = 0;
    int notStartedCount = 0;

    for (var trainee in trainees) {
      final progress = trainee['progress'] as double? ?? 0;
      totalProgress += progress;

      if (progress >= 100) {
        completedCount++;
      } else if (progress > 0) {
        inProgressCount++;
      } else {
        notStartedCount++;
      }
    }

    report.writeln("PROGRESS SUMMARY:");
    report.writeln("  Average Progress: ${(totalProgress / trainees.length).toStringAsFixed(1)}%");
    report.writeln("  Completed (100%): $completedCount");
    report.writeln("  In Progress (>0%): $inProgressCount");
    report.writeln("  Not Started (0%): $notStartedCount");
    report.writeln();

    // Detailed trainee list
    report.writeln("DETAILED TRAINEE LIST:");
    report.writeln("-" * 80);

    for (int i = 0; i < trainees.length; i++) {
      final t = trainees[i];
      report.writeln("${i + 1}. ${t['studentName']}");
      report.writeln("   ID: ${t['studentId']}");
      report.writeln("   Status: ${t['status']}");
      report.writeln("   Department: ${t['department'] ?? 'N/A'}");
      report.writeln("   Role: ${t['role'] ?? 'N/A'}");
      report.writeln("   Progress: ${t['progress']}%");

      if (t['startDate'] != null) {
        report.writeln("   Start Date: ${DateFormat('yyyy-MM-dd').format(DateTime.parse(t['startDate']))}");
      }
      if (t['endDate'] != null) {
        report.writeln("   End Date: ${DateFormat('yyyy-MM-dd').format(DateTime.parse(t['endDate']))}");
      }

      report.writeln("   Supervisors: ${(t['supervisors'] as List?)?.length ?? 0}");
      report.writeln("   Milestones: ${t['milestones']}");
      report.writeln("   Evaluations: ${t['evaluations']}");
      report.writeln("   Last Updated: ${DateFormat('yyyy-MM-dd').format(DateTime.parse(t['updatedAt']))}");
      report.writeln();
    }

    return report.toString();
  }

  Future<String> _saveReportToFile(String report) async {
    try {
      final directory = await getExternalStorageDirectory();
       if(directory == null)
         {
           Fluttertoast.showToast(msg: "Directory not found");
           return "not-found";
         }
      debugPrint("directory path ${directory?.path}");
      final fileName = 'trainee_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.txt';
      final file = File('${directory?.path}/$fileName');
      await file.writeAsString(report);
      return file.path;
    } catch (e) {
      debugPrint('Error saving report: $e');
      return '';
    }
  }

  void _showReportDialog(String report, String filePath) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Trainee Report',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        content: Container(
          width: double.maxFinite,
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            children: [
              if (filePath.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(8),
                  color: isDark ? Colors.green.withOpacity(0.2) : Colors.green.shade50,
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: isDark ? Colors.green.shade300 : Colors.green,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Saved to: $filePath',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? Colors.green.shade300 : Colors.green.shade900,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: SelectableText(
                      report,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: TextStyle(
                color: isDark ? Colors.blue.shade300 : Colors.blue,
              ),
            ),
          ),
          if (filePath.isNotEmpty)
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('File location: $filePath'),
                    duration: const Duration(seconds: 3),
                  ),
                );
              },
              child: Text(
                'File Location',
                style: TextStyle(
                  color: isDark ? Colors.blue.shade300 : Colors.blue,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class TraineeCard extends StatelessWidget {
  final TraineeRecord trainee;
  final bool isDark;
  final int tabIndex;
  final VoidCallback onTap;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onStartTraining;
  final VoidCallback? onCompleteTraining;
  final VoidCallback? onDoubleTab;

  const TraineeCard({
    Key? key,
    required this.trainee,
    required this.isDark,
    required this.tabIndex,
    required this.onTap,
    this.onAccept,
    this.onReject,
    this.onStartTraining,
    this.onCompleteTraining,
    this.onDoubleTab
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = trainee.status.color;
    final statusText = trainee.status.displayName;
    final statusIcon = trainee.status.icon;
    debugPrint("status trainee is ${trainee.status.displayName}");

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: InkWell(
        onTap: onTap,
        onDoubleTap: onDoubleTab,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                theme.colorScheme.surface.withOpacity(0.8),
                theme.colorScheme.surface,
              ]
                  : [
                Colors.white,
                theme.colorScheme.primaryContainer.withOpacity(0.3),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row - Profile and Company Badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Image with status badge
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: statusColor,
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: statusColor.withOpacity(0.3),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: GeneralMethods.generateUserAvatar(
                              username: trainee.studentName,
                              imageUrl: trainee.imageUrl,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: -2,
                          right: -2,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: theme.colorScheme.surface,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: statusColor.withOpacity(0.5),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: Icon(
                              statusIcon,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(width: 16),

                    // Trainee Info - UPDATED for better name display
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Name and Status Row - UPDATED layout
                          LayoutBuilder(
                            builder: (context, constraints) {
                              // Check if we have enough width for both name and status badge
                              final nameText = Text(
                                trainee.studentName,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : theme.colorScheme.onSurface,
                                ),
                              );

                              // Measure the name text width
                              final namePainter = TextPainter(
                                text: TextSpan(
                                  text: trainee.studentName,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                maxLines: 1,
                                textDirection: Directionality.of(context),
                              )..layout(maxWidth: constraints.maxWidth - 100); // Leave room for status badge

                              // If name is too long, stack vertically
                              if (namePainter.didExceedMaxLines) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    InkWell(
                                      onTap: () async {
                                        Student? student = await ITCFirebaseLogic(FirebaseAuth.instance.currentUser!.uid).getStudent(trainee.studentId);
                                        if(student == null) {
                                          Fluttertoast.showToast(msg: "Student Record not found");
                                          return;
                                        }
                                        GeneralMethods.navigateTo(context, StudentProfilePage(student: student));
                                      },
                                      child: Text(
                                        trainee.studentName,
                                        style: theme.textTheme.titleLarge?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.white : theme.colorScheme.onSurface,
                                          fontSize: 18, // Slightly smaller on constrained screens
                                        ),
                                        maxLines: 2, // Allow name to wrap to 2 lines
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: statusColor.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(30),
                                        border: Border.all(
                                          color: statusColor.withOpacity(0.5),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            statusIcon,
                                            size: 14,
                                            color: statusColor,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            statusText,
                                            style: theme.textTheme.labelMedium?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: statusColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              } else {
                                // Enough space for horizontal layout
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: InkWell(
                                        onTap: () async {
                                          Student? student = await ITCFirebaseLogic(FirebaseAuth.instance.currentUser!.uid).getStudent(trainee.studentId);
                                          if(student == null) {
                                            Fluttertoast.showToast(msg: "Student Record not found");
                                            return;
                                          }
                                          GeneralMethods.navigateTo(context, StudentProfilePage(student: student));
                                        },
                                        child: Text(
                                          trainee.studentName,
                                          style: theme.textTheme.titleLarge?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? Colors.white : theme.colorScheme.onSurface,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: statusColor.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(30),
                                        border: Border.all(
                                          color: statusColor.withOpacity(0.5),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            statusIcon,
                                            size: 14,
                                            color: statusColor,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            statusText,
                                            style: theme.textTheme.labelMedium?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: statusColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }
                            },
                          ),

                          const SizedBox(height: 8),

                          // Company Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.business,
                                  size: 14,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    trainee.companyName,
                                    style: theme.textTheme.labelMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: theme.colorScheme.primary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Department and Role
                          if (trainee.department.isNotEmpty || trainee.role.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.secondary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.work_outline,
                                    size: 14,
                                    color: theme.colorScheme.secondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      '${trainee.department}${trainee.role.isNotEmpty ? ' • ${trainee.role}' : ''}',
                                      style: theme.textTheme.labelMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: theme.colorScheme.secondary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Progress Bar (if progress > 0)
                if (trainee.progress > 0) ...[
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: trainee.progress / 100,
                            backgroundColor: theme.colorScheme.surfaceVariant,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _getProgressColor(trainee.progress),
                            ),
                            minHeight: 8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${trainee.progress.toStringAsFixed(0)}%',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: _getProgressColor(trainee.progress),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                // Info Chips Grid - UPDATED to use Flexible chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // Date Range Chip
                    if (trainee.startDate != null && trainee.endDate != null)
                      _buildInfoChip(
                        context,
                        icon: Icons.date_range,
                        label:
                        '${DateFormat('MMM dd').format(trainee.startDate!)} - ${DateFormat('MMM dd, yyyy').format(trainee.endDate!)}',
                        color: theme.colorScheme.primary,
                      ),

                    // Duration Chip
                    if (trainee.durationInDays != null)
                      _buildInfoChip(
                        context,
                        icon: Icons.timelapse,
                        label: '${trainee.durationInDays} days',
                        color: theme.colorScheme.secondary,
                      ),

                    // Days Remaining Chip
                    if (trainee.daysRemaining != null && trainee.isActive)
                      _buildInfoChip(
                        context,
                        icon: Icons.hourglass_bottom,
                        label: '${trainee.daysRemaining} days left',
                        color: trainee.daysRemaining! < 7
                            ? Colors.orange
                            : Colors.green,
                      ),

                    // Days Elapsed Chip
                    if (trainee.daysElapsed != null && trainee.isActive)
                      _buildInfoChip(
                        context,
                        icon: Icons.timer,
                        label: '${trainee.daysElapsed} days active',
                        color: Colors.blue,
                      ),

                    // Supervisors Chip
                    if (trainee.supervisorIds.isNotEmpty)
                      _buildInfoChip(
                        context,
                        icon: Icons.supervisor_account,
                        label:
                        '${trainee.supervisorIds.length} supervisor${trainee.supervisorIds.length > 1 ? 's' : ''}',
                        color: Colors.purple,
                      ),

                    // Status Description Chip
                    _buildInfoChip(
                      context,
                      icon: trainee.needsStatusUpdate
                          ? Icons.warning_amber
                          : Icons.info_outline,
                      label: trainee.statusDescription,
                      color: trainee.needsStatusUpdate
                          ? Colors.orange
                          : Colors.grey,
                    ),
                  ],
                ),

                // Action Buttons
                if (_getActionButtons(context).isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: _getActionButtons(context).map((button) {
                      if (button is Expanded) {
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: _getActionButtons(context).indexOf(button) < _getActionButtons(context).length - 1 ? 8 : 0,
                            ),
                            child: (button.child as Widget),
                          ),
                        );
                      }
                      return button;
                    }).toList(),
                  ),
                ],

                // Notes Indicator (if there are notes)
                if (trainee.notes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.outline.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.note_alt_outlined,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${trainee.notes.length} note${trainee.notes.length > 1 ? 's' : ''}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _getActionButtons(context) {
    switch (tabIndex) {
      case 0: // Pending
        return [
          Expanded(
            child: ElevatedButton(
              onPressed: onAccept,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text('Accept'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton(
              onPressed: onReject,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text('Reject'),
            ),
          ),
        ];

      case 1: // Current (Active)
        return [
          Expanded(
            child: ElevatedButton(
              onPressed: onCompleteTraining,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text('Complete'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                // View progress or other action
                Fluttertoast.showToast(
                    msg: 'This feature will be available in the next version',
                    toastLength: Toast.LENGTH_SHORT);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.blue,
                side: const BorderSide(color: Colors.blue),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text('View Progress'),
            ),
          ),
        ];

      case 2: // On-Hold Trainees 👈 NEW CASE
        return [
          Expanded(
            child: ElevatedButton(
              onPressed: onStartTraining, // Resume training
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.play_arrow, size: 18),
                  SizedBox(width: 4),
                  Text('Resume'),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                // Show hold reason dialog
                _showHoldReasonDialog(context);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.orange,
                side: const BorderSide(color: Colors.orange),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.info_outline, size: 18),
                  SizedBox(width: 4),
                  Text('Hold Reason'),
                ],
              ),
            ),
          ),
        ];

      case 3: // Upcoming (Accepted)
        return [
          Expanded(
            child: ElevatedButton(
              onPressed: onStartTraining,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text('Start Training'),
            ),
          ),
        ];

      case 4: // Rejected
        return [
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                // Show rejection reason
                _showRejectionReasonDialog(context);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.info_outline, size: 18),
                  SizedBox(width: 4),
                  Text('View Reason'),
                ],
              ),
            ),
          ),
        ];

      case 5: // Completed
        return [
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                // View completion details
                _showCompletionDetailsDialog(context);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.green,
                side: const BorderSide(color: Colors.green),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.assignment_turned_in, size: 18),
                  SizedBox(width: 4),
                  Text('View Details'),
                ],
              ),
            ),
          ),
        ];

      default:
        return [];
    }
  }

// Helper methods for dialogs
  void _showHoldReasonDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hold Reason'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This trainee was placed on hold for:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Text(
                trainee.holdReason.isNotEmpty
                    ? trainee.holdReason
                    : 'No specific reason provided',
                style: const TextStyle(fontSize: 14),
              ),
            ),
            if (trainee.holdStartDate != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    'Hold Date: ${DateFormat('MMM dd, yyyy').format(trainee.holdStartDate!)}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showRejectionReasonDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rejection Reason'),
        content: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red.withOpacity(0.3)),
          ),
          child: Text(
            trainee.statusDescription.isNotEmpty
                ? trainee.statusDescription
                : 'No specific reason provided',
            style: const TextStyle(fontSize: 14),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showCompletionDetailsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Completion Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (trainee.actualEndDate != null) ...[
              Row(
                children: [
                  Icon(Icons.event, size: 16, color: Colors.green),
                  const SizedBox(width: 8),
                  Text(
                    'Completed: ${DateFormat('MMM dd, yyyy').format(trainee.actualEndDate!)}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            const Divider(),
            Row(
              children: [
                Icon(Icons.trending_up, size: 16, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Final Progress: ${trainee.progress.toStringAsFixed(0)}%',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
            if (trainee.statusDescription.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Notes:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(trainee.statusDescription),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(
      BuildContext context, {
        required IconData icon,
        required String label,
        required Color color,
      }) {
    final theme = Theme.of(context);

    return IntrinsicWidth(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: color,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getProgressColor(double progress) {
    if (progress >= 75) return Colors.green;
    if (progress >= 50) return Colors.blue;
    if (progress >= 25) return Colors.orange;
    return Colors.red;
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
    bool isOutlined = false,
  }) {
    if (isOutlined) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      );
    }

    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
        elevation: 2,
      ),
    );
  }
}