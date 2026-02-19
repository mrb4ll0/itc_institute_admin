import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:itc_institute_admin/backgroundTask/backgroundTask.dart';
import 'package:itc_institute_admin/backgroundTask/backgroundTaskRegistry.dart';
import 'package:itc_institute_admin/backgroundTask/widget/migrationStatusWidget.dart';
import 'package:itc_institute_admin/generalmethods/GeneralMethods.dart';
import 'package:itc_institute_admin/itc_logic/firebase/company_cloud.dart';
import 'package:itc_institute_admin/model/student.dart';
import 'package:itc_institute_admin/model/company.dart';
import 'package:itc_institute_admin/model/traineeRecord.dart';
import '../itc_logic/firebase/general_cloud.dart';
import '../itc_logic/service/tranineeService.dart';
import '../migrationService/migrationService.dart';
import '../model/studentApplication.dart';
import 'home/industrailTraining/applications/studentApplicationsPage.dart';


class StudentListPage extends StatefulWidget {
  final Company company;
  final bool isAuthority;
  const StudentListPage({Key? key, required this.company,required this.isAuthority}) : super(key: key);

  @override
  State<StudentListPage> createState() => _StudentListPageState();
}

class _StudentListPageState extends State<StudentListPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late final TraineeService _traineeService;
  final ITCFirebaseLogic _itcFirebaseLogic = ITCFirebaseLogic(FirebaseAuth.instance.currentUser!.uid);
  BackgroundTaskManager backgroundTaskManager = BackgroundTaskManager();
  TaskStatus? taskStatus = BackgroundTaskRegistry.getLatestMigrationTask();

  List<TraineeRecord> _pendingTrainees = [];
  List<TraineeRecord> _currentTrainees = [];
  List<TraineeRecord> _upcomingTrainees = [];
  List<TraineeRecord> _rejectedTrainees = [];
  List<TraineeRecord> _completedTrainees = [];

  // For each tab - store TraineeRecords instead of Students
  Map<int, List<TraineeRecord>> _filteredTrainees = {
    0: [], // Pending
    1: [], // Current
    2: [], // Upcoming
    3: [], // Rejected
    4: [], // Completed
  };

  Map<int, String> _searchQueries = {
    0: '',
    1: '',
    2: '',
    3: '',
    4: '',
  };

  Map<int, TextEditingController> _searchControllers = {
    0: TextEditingController(),
    1: TextEditingController(),
    2: TextEditingController(),
    3: TextEditingController(),
    4: TextEditingController(),
  };

  bool _isLoading = true;
  String _error = '';

  // Tab labels and icons - ADDED REJECTED AND COMPLETED
  final List<String> _tabLabels = [
    'Pending Applications',
    'Current Trainees',
    'Upcoming Trainees',
    'Rejected Applications',
    'Completed Trainees',
  ];

  final List<IconData> _tabIcons = [
    Icons.pending_actions,
    Icons.work,
    Icons.schedule,
    Icons.cancel,
    Icons.check_circle,
  ];

  String migrationStatus = "";
  @override
  void initState() {
    super.initState();
    _traineeService = TraineeService(FirebaseAuth.instance.currentUser!.uid);
    _tabController = TabController(length: 5, vsync: this); // Changed to 5
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        // Update the stats and search bar for the new tab
        setState(() {
        });

      }
    });
    _loadTrainees();
  }



  @override
  void dispose() {
    _tabController.dispose();
    _searchControllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  Future<void> _loadTrainees() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final companyId = widget.company.id;

      // Load all trainee categories
      _pendingTrainees = await _traineeService.getTraineesByStatus(
          companyId: companyId,
          status:TraineeStatus.pending,
        isAuthority: widget.isAuthority,
        companyIds: widget.company.originalAuthority?.linkedCompanies??[]
      );


      _currentTrainees = await _traineeService.getCurrentTrainees(companyId: companyId,isAuthority: widget.isAuthority,
          companyIds: widget.company.originalAuthority?.linkedCompanies??[]);
      _upcomingTrainees = await _traineeService.getUpcomingTrainees(companyId: companyId,isAuthority: widget.isAuthority,
          companyIds: widget.company.originalAuthority?.linkedCompanies??[]);
      _rejectedTrainees = await _traineeService.getTraineesByStatus(
          companyId: companyId,
          status:TraineeStatus.rejected,
          isAuthority: widget.isAuthority,
          companyIds: widget.company.originalAuthority?.linkedCompanies??[]
      );
      _completedTrainees = await _traineeService.getTraineesByStatus(
          companyId:  companyId,
          status:TraineeStatus.completed,
          isAuthority: widget.isAuthority,
          companyIds: widget.company.originalAuthority?.linkedCompanies??[]
      );

      debugPrint("Loaded: ${_pendingTrainees.length} pending, "
          "${_currentTrainees.length} current, "
          "${_upcomingTrainees.length} upcoming, "
          "${_rejectedTrainees.length} rejected, "
          "${_completedTrainees.length} completed");

      // Initialize filtered lists
      _filteredTrainees[0] = List.from(_pendingTrainees);
      _filteredTrainees[1] = List.from(_currentTrainees);
      _filteredTrainees[2] = List.from(_upcomingTrainees);
      _filteredTrainees[3] = List.from(_rejectedTrainees);
      _filteredTrainees[4] = List.from(_completedTrainees);

      setState(() {
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      debugPrint("Error in _loadTrainees: $e");
      debugPrint("Stack trace: $stackTrace");
      setState(() {
        _error = 'Failed to load trainees: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _filterTrainees(int tabIndex) {
    List<TraineeRecord> baseList;
    switch (tabIndex) {
      case 0:
        baseList = _pendingTrainees;
        break;
      case 1:
        baseList = _currentTrainees;
        break;
      case 2:
        baseList = _upcomingTrainees;
        break;
      case 3:
        baseList = _rejectedTrainees;
        break;
      case 4:
        baseList = _completedTrainees;
        break;
      default:
        baseList = [];
    }

    final query = _searchQueries[tabIndex] ?? '';
    List<TraineeRecord> filtered = baseList;

    // Apply search filter
    if (query.isNotEmpty) {
      filtered = filtered.where((trainee) {
        final name = trainee.studentName.toLowerCase();
        final searchQuery = query.toLowerCase();
        return name.contains(searchQuery);
      }).toList();
    }

    setState(() {
      _filteredTrainees[tabIndex] = filtered;
    });
  }

  void _onSearchChanged(String query, int tabIndex) {
    setState(() {
      _searchQueries[tabIndex] = query;
    });
    _filterTrainees(tabIndex);
  }

  void _clearSearch(int tabIndex) {
    _searchControllers[tabIndex]?.clear();
    setState(() {
      _searchQueries[tabIndex] = '';
    });
    _filterTrainees(tabIndex);
  }

  void _showTraineeDetails(TraineeRecord trainee, int tabIndex) {
    showDialog(
      context: context,
      builder: (context) => TraineeDetailDialog(
        trainee: trainee,
        tabIndex: tabIndex,
        traineeService: _traineeService,
        onStatusChanged: () {
          _loadTrainees();
        },
      ),
    );
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

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status updated to ${newStatus.displayName}'),
            backgroundColor: Colors.green,
          ),
        );
        _loadTrainees();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleApplicationDecision({
    required TraineeRecord trainee,
    required bool accept,
    String? reason,
  }) async {
    try {
      // First, get the application details
      final application = await _getApplicationForTrainee(trainee);

      if (application == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot find application details'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final status = accept ? 'accepted' : 'rejected';
      final finalReason = reason ?? (accept ? 'Application accepted' : 'Application rejected');
      debugPrint("application title ${application.internship.title}");

      final success = await _traineeService.updateApplicationStatusWithTraineeSync(
        isAuthority: widget.isAuthority,
        companyId: trainee.companyId,
        internshipId: application.internship.id!,
        studentId: trainee.studentId,
        applicationId: trainee.applicationId!,
        status: status,
        reason: finalReason,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Application $status'),
            backgroundColor: accept ? Colors.green : Colors.orange,
          ),
        );
        _loadTrainees();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update application: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<StudentApplication?> _getApplicationForTrainee(TraineeRecord trainee) async {
    try {
      if (trainee.applicationId == null) return null;

      // You'll need to implement this method based on your Company_Cloud
      // This is a placeholder - adjust according to your actual structure
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

  Widget _buildSearchBar(int tabIndex) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final query = _searchQueries[tabIndex] ?? '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 48,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          Icon(
            Icons.search,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _searchControllers[tabIndex],
              onChanged: (value) => _onSearchChanged(value, tabIndex),
              decoration: InputDecoration(
                hintText: 'Search ${_tabLabels[tabIndex].toLowerCase()}...',
                hintStyle: TextStyle(
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
                border: InputBorder.none,
              ),
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
          if (query.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear, size: 20),
              onPressed: () => _clearSearch(tabIndex),
            ),
        ],
      ),
    );
  }

  Widget _buildTabContent(int tabIndex) {
    final trainees = _filteredTrainees[tabIndex] ?? [];

    if (trainees.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchQueries[tabIndex]?.isNotEmpty == true
                  ? Icons.search_off
                  : _getEmptyIcon(tabIndex),
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQueries[tabIndex]?.isNotEmpty == true
                  ? 'No matching trainees found'
                  : _getEmptyMessage(tabIndex),
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            if (_searchQueries[tabIndex]?.isNotEmpty == true)
              Text(
                'Try adjusting your search',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                ),
              ),
          ],
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: trainees.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final trainee = trainees[index];
        return TraineeCard(
          onDoubleTab: ()
          {
            GeneralMethods.navigateTo(context, SpecificStudentApplicationsPage(companyId: trainee.companyId,studentUid: trainee.studentId,isAuthority: widget.isAuthority,companyIds: widget.company.originalAuthority?.linkedCompanies??[]));
          },
          trainee: trainee,
          isDark: isDark,
          tabIndex: tabIndex,
          onTap: () => _showTraineeDetails(trainee, tabIndex),
          onAccept: tabIndex == 0 ? () => _handleApplicationDecision(
            trainee: trainee,
            accept: true,
          ) : null,
          onReject: tabIndex == 0 ? () => _handleApplicationDecision(
            trainee: trainee,
            accept: false,
          ) : null,
          onStartTraining: tabIndex == 2 ? () => _updateTraineeStatus(
            trainee: trainee,
            newStatus: TraineeStatus.active,
            reason: 'Training started',
          ) : null,
          onCompleteTraining: tabIndex == 1 ? () => _updateTraineeStatus(
            trainee: trainee,
            newStatus: TraineeStatus.completed,
            reason: 'Training completed successfully',
          ) : null,
        );
      },
    );
  }

  IconData _getEmptyIcon(int tabIndex) {
    switch (tabIndex) {
      case 0: return Icons.pending_actions;
      case 1: return Icons.work_outline;
      case 2: return Icons.schedule_outlined;
      case 3: return Icons.cancel_outlined;
      case 4: return Icons.check_circle_outline;
      default: return Icons.people_outline;
    }
  }

  String _getEmptyMessage(int tabIndex) {
    switch (tabIndex) {
      case 0: return 'No pending applications';
      case 1: return 'No current trainees';
      case 2: return 'No upcoming trainees';
      case 3: return 'No rejected applications';
      case 4: return 'No completed trainees';
      default: return 'No trainees found';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF101622) : const Color(0xFFf6f6f8),
      appBar: AppBar(
        title: Text('Trainee Management - ${widget.company.name}'),
        backgroundColor: isDark ? const Color(0xFF1a2232) : Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true, // Added because we have more tabs
          tabs: [
            for (int i = 0; i < 5; i++)
              Tab(
                icon: Icon(_tabIcons[i]),
                text: _tabLabels[i],
              ),
          ],
          indicatorColor: Colors.blue,
          labelColor: Colors.blue,
          unselectedLabelColor: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTrainees,
            tooltip: 'Refresh',
          ),

          MigrationStatusIcon(
            onRefresh: startMigration,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'stats') {
                _showStatistics();
              } else if (value == 'export') {
                _exportData();
              } else if (value == 'sync') {
                _syncWithApplication();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'stats',
                child: Row(
                  children: [
                    Icon(Icons.analytics, size: 20),
                    SizedBox(width: 8),
                    Text('View Statistics'),
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
const PopupMenuItem(
                value: 'sync',
                child: Row(
                  children: [
                    Icon(Icons.download, size: 20),
                    SizedBox(width: 8),
                    Text('Sync with application'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _error.isNotEmpty
          ? _buildErrorState()
          : Column(
        children: [
          // Stats for current tab
          _buildTabStats(_tabController.index),

          // Search bar for current tab
          _buildSearchBar(_tabController.index),

          // Trainee list for current tab
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                for (int i = 0; i < 5; i++)
                  RefreshIndicator(
                    onRefresh: _loadTrainees,
                    child: _buildTabContent(i),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  startMigration()async
  {
    final migrationService = MigrationService(FirebaseAuth.instance.currentUser!.uid);
    unawaited( migrationService.startMigration().catchError((e,s)
    {
      debugPrint("background Task failed with error $e");
      debugPrintStack(stackTrace: s);
    }));
  }

  Future<void> _showStatistics() async {
    try {
      final stats = await _traineeService.getTraineeStatistics(widget.company.id);

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
                  const Divider(),
                  _buildStatItem('Supervised', stats['supervisedCount']?.toString() ?? '0'),
                  _buildStatItem('Unsupervised', stats['unsupervisedCount']?.toString() ?? '0'),
                  _buildStatItem('Overdue', stats['overdueCount']?.toString() ?? '0'),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load statistics: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _syncWithApplication() async {
    try {
      setState(() {
        _isLoading = true;
        _error = '';
      });
      await _traineeService.syncTraineesFromApplications(widget.company.id,widget.isAuthority);
    setState(() {
      _loadTrainees();
    });
  }
    catch(error,stack)
    {
      debugPrint("error $error");
      debugPrintStack(stackTrace: stack);
    }

  }

  Future<void> _exportData() async {
    try {
      final data = await _traineeService.exportTraineeData(widget.company.id);
      // Here you would implement actual export logic
      // For now, just show a success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exported ${data.length} records'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to export data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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

  Widget _buildTabStats(int tabIndex) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalCount = _getTotalCount(tabIndex);
    final filteredCount = _filteredTrainees[tabIndex]?.length ?? 0;
    final hasSearch = _searchQueries[tabIndex]?.isNotEmpty == true;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1a2232) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildStatItemWidget(
            hasSearch ? 'Filtered' : 'Total',
            hasSearch ? filteredCount.toString() : totalCount.toString(),
            _tabIcons[tabIndex],
          ),
          if (hasSearch)
            _buildStatItemWidget(
              'Total',
              totalCount.toString(),
              Icons.filter_list,
            ),
          _buildStatItemWidget(
            'Status',
            _getStatusLabel(tabIndex),
            Icons.info,
          ),
        ],
      ),
    );
  }

  int _getTotalCount(int tabIndex) {
    switch (tabIndex) {
      case 0: return _pendingTrainees.length;
      case 1: return _currentTrainees.length;
      case 2: return _upcomingTrainees.length;
      case 3: return _rejectedTrainees.length;
      case 4: return _completedTrainees.length;
      default: return 0;
    }
  }

  String _getStatusLabel(int tabIndex) {
    switch (tabIndex) {
      case 0: return 'Pending';
      case 1: return 'Active';
      case 2: return 'Upcoming';
      case 3: return 'Rejected';
      case 4: return 'Completed';
      default: return '';
    }
  }

  Widget _buildStatItemWidget(String label, String value, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.blue, size: 20),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Loading trainees...',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Error Loading Trainees',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.red.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadTrainees,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
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

                    // Trainee Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Name and Status Row
                          Row(
                            children: [
                              Expanded(
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
                                Expanded(
                                  child: Text(
                                    trainee.companyName,
                                    style: theme.textTheme.labelMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: theme.colorScheme.primary,
                                    ),
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

                // Info Chips Grid
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
                if (_getActionButtons().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: _getActionButtons().map((button) {
                      return Expanded(
                        child: button,
                      );
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
  List<Widget> _getActionButtons() {
    switch (tabIndex) {
      case 0: // Pending
        return [
          Expanded(
            child: ElevatedButton(
              onPressed: onAccept,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
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
              ),
              child: const Text('Reject'),
            ),
          ),
        ];

      case 2: // Upcoming (Accepted)
        return [
          Expanded(
            child: ElevatedButton(
              onPressed: onStartTraining,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Start Training'),
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
              ),
              child: const Text('Complete'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                // View progress or other action
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.blue,
                side: const BorderSide(color: Colors.blue),
              ),
              child: const Text('View Progress'),
            ),
          ),
        ];

      default:
        return [];
    }
  }

  Widget _buildInfoChip(
      BuildContext context, {
        required IconData icon,
        required String label,
        required Color color,
      }) {
    final theme = Theme.of(context);

    return Container(
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

class TraineeDetailDialog extends StatefulWidget {
  final TraineeRecord trainee;
  final int tabIndex;
  final TraineeService traineeService;
  final VoidCallback onStatusChanged;

  const TraineeDetailDialog({
    Key? key,
    required this.trainee,
    required this.tabIndex,
    required this.traineeService,
    required this.onStatusChanged,
  }) : super(key: key);

  @override
  State<TraineeDetailDialog> createState() => _TraineeDetailDialogState();
}

class _TraineeDetailDialogState extends State<TraineeDetailDialog> {
  Student? _student;
  Company? _company;
  bool _loadingStudent = true;
  bool _loadingCompany = true;

  @override
  void initState() {
    super.initState();
    _loadStudentDetails();
    _loadCompanyDetails();
  }

  Future<void> _loadStudentDetails() async {
    try {
      final student = await ITCFirebaseLogic(FirebaseAuth.instance.currentUser!.uid)
          .getStudent(widget.trainee.studentId);
      if (mounted) {
        setState(() {
          _student = student;
          _loadingStudent = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingStudent = false;
        });
      }
    }
  }

  Future<void> _loadCompanyDetails() async {
    try {
      final company = await ITCFirebaseLogic(FirebaseAuth.instance.currentUser!.uid)
          .getCompany(widget.trainee.companyId);
      if (mounted) {
        setState(() {
          _company = company;
          _loadingCompany = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingCompany = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trainee = widget.trainee;
    final statusColor = trainee.status.color;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      elevation: 8,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 700, maxWidth: 500),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.surface,
              theme.colorScheme.surfaceVariant.withOpacity(0.3),
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with gradient overlay
            Stack(
              children: [
                Container(
                  height: 180,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        statusColor,
                        statusColor.withOpacity(0.7),
                      ],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                ),

                // Profile Section
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 20,
                  child: Row(
                    children: [
                      // Profile Image with border
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 4,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 10,
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

                      const SizedBox(width: 16),

                      // Name and Status
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              trainee.studentName,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.3),
                                    offset: const Offset(0, 2),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (_loadingStudent)
                              Container(
                                width: 120,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const ShimmerLoading(
                                  child: SizedBox.expand(),
                                ),
                              )
                            else if (_student?.email != null)
                              Text(
                                _student!.email,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.white70,
                                ),
                              ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    trainee.status.icon,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    trainee.status.displayName,
                                    style: theme.textTheme.labelMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
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
                ),
              ],
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Company Information Card with Loading State
                    _buildSection(
                      context,
                      title: 'Company Information',
                      icon: Icons.business,
                      children: [
                        if (_loadingCompany)
                          _buildLoadingCompanyCard(context)
                        else if (_company != null)
                          _buildCompanyCard(context, _company!)
                        else
                          _buildErrorCard(
                            context,
                            'Failed to load company information',
                          ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Training Information
                    _buildSection(
                      context,
                      title: 'Training Information',
                      icon: Icons.work_history,
                      children: [
                        _buildInfoGrid(context, [
                          if (trainee.department.isNotEmpty)
                            _buildInfoTile(
                              context,
                              label: 'Department',
                              value: trainee.department,
                              icon: Icons.category,
                              color: theme.colorScheme.primary,
                            ),
                          if (trainee.role.isNotEmpty)
                            _buildInfoTile(
                              context,
                              label: 'Role',
                              value: trainee.role,
                              icon: Icons.work,
                              color: theme.colorScheme.secondary,
                            ),
                          if (trainee.startDate != null)
                            _buildInfoTile(
                              context,
                              label: 'Start Date',
                              value: DateFormat('MMM dd, yyyy').format(trainee.startDate!),
                              icon: Icons.calendar_today,
                              color: Colors.green,
                            ),
                          if (trainee.endDate != null)
                            _buildInfoTile(
                              context,
                              label: 'End Date',
                              value: DateFormat('MMM dd, yyyy').format(trainee.endDate!),
                              icon: Icons.calendar_today_outlined,
                              color: Colors.orange,
                            ),
                          if (trainee.actualStartDate != null)
                            _buildInfoTile(
                              context,
                              label: 'Actual Start',
                              value: DateFormat('MMM dd, yyyy').format(trainee.actualStartDate!),
                              icon: Icons.play_circle,
                              color: Colors.blue,
                            ),
                          if (trainee.actualEndDate != null)
                            _buildInfoTile(
                              context,
                              label: 'Actual End',
                              value: DateFormat('MMM dd, yyyy').format(trainee.actualEndDate!),
                              icon: Icons.stop_circle,
                              color: Colors.purple,
                            ),
                          if (trainee.durationInDays != null)
                            _buildInfoTile(
                              context,
                              label: 'Duration',
                              value: '${trainee.durationInDays} days',
                              icon: Icons.timelapse,
                              color: Colors.teal,
                            ),
                        ]),

                        const SizedBox(height: 16),

                        // Progress Section
                        if (trainee.progress > 0) ...[
                          _buildProgressIndicator(context),
                          const SizedBox(height: 16),
                        ],

                        // Status Description
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: trainee.needsStatusUpdate
                                  ? Colors.orange
                                  : theme.colorScheme.outline.withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                trainee.needsStatusUpdate
                                    ? Icons.warning_amber
                                    : Icons.info_outline,
                                color: trainee.needsStatusUpdate
                                    ? Colors.orange
                                    : theme.colorScheme.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Status Info',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    Text(
                                      trainee.statusDescription,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w500,
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

                    const SizedBox(height: 20),

                    // Student Information with Loading State
                    _buildSection(
                      context,
                      title: 'Student Information',
                      icon: Icons.school,
                      children: [
                        if (_loadingStudent)
                          _buildLoadingStudentInfo(context)
                        else if (_student != null)
                          _buildInfoGrid(context, [
                            _buildInfoTile(
                              context,
                              label: 'Full Name',
                              value: _student!.fullName,
                              icon: Icons.person,
                              color: Colors.blue,
                            ),
                            _buildInfoTile(
                              context,
                              label: 'Email',
                              value: _student!.email,
                              icon: Icons.email,
                              color: Colors.red,
                            ),
                            if (_student!.phoneNumber.isNotEmpty)
                              _buildInfoTile(
                                context,
                                label: 'Phone',
                                value: _student!.phoneNumber,
                                icon: Icons.phone,
                                color: Colors.green,
                              ),
                            if (_student!.institution.isNotEmpty)
                              _buildInfoTile(
                                context,
                                label: 'Institution',
                                value: _student!.institution,
                                icon: Icons.school,
                                color: Colors.purple,
                              ),
                            if (_student!.courseOfStudy.isNotEmpty)
                              _buildInfoTile(
                                context,
                                label: 'Course',
                                value: _student!.courseOfStudy,
                                icon: Icons.menu_book,
                                color: Colors.orange,
                              ),
                            if (_student!.level.isNotEmpty)
                              _buildInfoTile(
                                context,
                                label: 'Level',
                                value: '${_student!.level} Level',
                                icon: Icons.grade,
                                color: Colors.teal,
                              ),
                            if (_student!.cgpa > 0)
                              _buildInfoTile(
                                context,
                                label: 'CGPA',
                                value: _student!.cgpa.toStringAsFixed(2),
                                icon: Icons.star,
                                color: Colors.amber,
                              ),
                          ])
                        else
                          _buildErrorCard(
                            context,
                            'Failed to load student information',
                          ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Supervisors Section
                    if (trainee.supervisorIds.isNotEmpty)
                      _buildSection(
                        context,
                        title: 'Supervisors',
                        icon: Icons.supervisor_account,
                        children: [
                          ...trainee.supervisorIds.map((supervisorId) =>
                              _buildSupervisorTile(context, supervisorId)
                          ),
                        ],
                      ),

                    const SizedBox(height: 20),

                    // Notes Section
                    if (trainee.notes.isNotEmpty)
                      _buildSection(
                        context,
                        title: 'Notes',
                        icon: Icons.note_alt,
                        children: [
                          ...trainee.notes.entries.map((entry) =>
                              Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      entry.key,
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      entry.value.toString(),
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),

            // Action Buttons
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      label: const Text('Close'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Navigate to edit or take action
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('Take Action'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: statusColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
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

  // Loading widget for company card
  Widget _buildLoadingCompanyCard(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Company logo shimmer
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const ShimmerLoading(
                  child: SizedBox.expand(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Company name shimmer
                    Container(
                      width: double.infinity,
                      height: 20,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const ShimmerLoading(
                        child: SizedBox.expand(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Industry shimmer
                    Container(
                      width: 100,
                      height: 14,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const ShimmerLoading(
                        child: SizedBox.expand(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Website shimmer
          Container(
            width: double.infinity,
            height: 16,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const ShimmerLoading(
              child: SizedBox.expand(),
            ),
          ),
          // Phone shimmer
          Container(
            width: double.infinity,
            height: 16,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const ShimmerLoading(
              child: SizedBox.expand(),
            ),
          ),
          // Address shimmer
          Container(
            width: double.infinity,
            height: 16,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const ShimmerLoading(
              child: SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }

  // Loading widget for student info grid
  Widget _buildLoadingStudentInfo(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 2.2,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      children: List.generate(6, (index) => _buildLoadingInfoTile(context)),
    );
  }

  Widget _buildLoadingInfoTile(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Label shimmer
          Container(
            width: 60,
            height: 12,
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const ShimmerLoading(
              child: SizedBox.expand(),
            ),
          ),
          // Value shimmer
          Container(
            width: 80,
            height: 14,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const ShimmerLoading(
              child: SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }

  // Error card widget
  Widget _buildErrorCard(BuildContext context, String message) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.error.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: theme.colorScheme.error,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
      BuildContext context, {
        required String title,
        required IconData icon,
        required List<Widget> children,
      }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 18,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildCompanyCard(BuildContext context, Company company) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary.withOpacity(0.1),
            theme.colorScheme.secondary.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    company.name.substring(0, 2).toUpperCase(),
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      company.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (company.industry.isNotEmpty)
                      Text(
                        company.industry,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (company.phoneNumber.isNotEmpty)
            _buildDetailRow(
              context,
              icon: Icons.phone,
              label: company.phoneNumber,
              color: theme.colorScheme.secondary,
            ),
          if (company.address.isNotEmpty)
            _buildDetailRow(
              context,
              icon: Icons.location_on,
              label: company.address,
              color: Colors.green,
            ),
          if (company.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              company.description,
              style: theme.textTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(
      BuildContext context, {
        required IconData icon,
        required String label,
        required Color color,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoGrid(BuildContext context, List<Widget> tiles) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 2.2,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      children: tiles,
    );
  }

  Widget _buildInfoTile(
      BuildContext context, {
        required String label,
        required String value,
        required IconData icon,
        required Color color,
      }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(BuildContext context) {
    final theme = Theme.of(context);
    final progress = widget.trainee.progress;
    final color = _getProgressColor(progress);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Training Progress',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${progress.toStringAsFixed(0)}%',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress / 100,
            backgroundColor: theme.colorScheme.surfaceVariant,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildSupervisorTile(BuildContext context, String supervisorId) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
            child: Text(
              supervisorId.substring(0, 2).toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Supervisor',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  'ID: $supervisorId',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.visibility_outlined,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            onPressed: () {
              // Navigate to supervisor details
            },
          ),
        ],
      ),
    );
  }

  Color _getProgressColor(double progress) {
    if (progress >= 75) return Colors.green;
    if (progress >= 50) return Colors.blue;
    if (progress >= 25) return Colors.orange;
    return Colors.red;
  }
}


class ShimmerLoading extends StatefulWidget {
  final Widget child;

  const ShimmerLoading({Key? key, required this.child}) : super(key: key);

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(_animation.value - 1, 0),
              end: Alignment(_animation.value, 0),
              colors: [
                Colors.grey.shade300,
                Colors.white,
                Colors.grey.shade300,
              ],
              stops: const [0.2, 0.5, 0.8],
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: widget.child,
        );
      },
    );
  }
}