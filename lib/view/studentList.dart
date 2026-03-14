import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
   StudentListPage({Key? key, required this.company,required this.isAuthority}) : super(key: key);

  @override
  State<StudentListPage> createState() => _StudentListPageState();
}

class _StudentListPageState extends State<StudentListPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late final TraineeService _traineeService;
  final ITCFirebaseLogic _itcFirebaseLogic = ITCFirebaseLogic(FirebaseAuth.instance.currentUser!.uid);
  BackgroundTaskManager backgroundTaskManager = BackgroundTaskManager();
  TaskStatus? taskStatus = BackgroundTaskRegistry.getLatestMigrationTask();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  List<TraineeRecord> _pendingTrainees = [];
  List<TraineeRecord> _currentTrainees = [];
  List<TraineeRecord> _upcomingTrainees = [];
  List<TraineeRecord> _rejectedTrainees = [];
  List<TraineeRecord> _completedTrainees = [];
  List<TraineeRecord> _onHoldTrainees = [];

  // For each tab - store TraineeRecords instead of Students
  Map<int, List<TraineeRecord>> _filteredTrainees = {
    0: [], // Pending
    1: [], // Current
    2: [], // On-Hold
    3: [], // Upcoming
    4: [], // Rejected
    5: [], // Completed
  };

  Map<int, String> _searchQueries = {
    0: '',
    1: '',
    2: '',
    3: '',
    4: '',
    5: '',
  };

  Map<int, TextEditingController> _searchControllers = {
    0: TextEditingController(),
    1: TextEditingController(),
    2: TextEditingController(),
    3: TextEditingController(),
    4: TextEditingController(),
    5: TextEditingController(),
  };

  bool _isLoading = true;
  String _error = '';

  // Tab labels and icons - ADDED REJECTED AND COMPLETED
  final List<String> _tabLabels = [
    'Pending Applications',
    'Current Trainees',
    'On-Hold Trainees',
    'Upcoming Trainees',
    'Rejected Applications',
    'Completed Trainees',
  ];

  final List<IconData> _tabIcons = [
    Icons.pending_actions,
    Icons.work,
    Icons.pause,
    Icons.schedule,
    Icons.cancel,
    Icons.check_circle,
  ];

  double _previousAnimationValue = 0.0;


  String migrationStatus = "";
  @override
  void initState() {
    super.initState();
    _traineeService = TraineeService(FirebaseAuth.instance.currentUser!.uid);
    _tabController = TabController(length: 6, vsync: this); // Changed to 6
    _previousAnimationValue = _tabController.animation!.value;
    _tabController.addListener(() {
      _handleTabScroll();
    });
    _loadTrainees();
  }

  void _handleTabScroll() {
    final currentValue = _tabController.animation!.value;

    // Check the direction
    if (currentValue > _previousAnimationValue) {
      // Scrolling from left to right (positive delta in animation value)
      print("Scrolling from left to right");
      setState(() {

      });
      // Perform your action here
    } else if (currentValue < _previousAnimationValue) {
      // Scrolling from right to left (negative delta in animation value)
      print("Scrolling from right to left");
      setState(() {

      });
      // Perform your action here
    }

    _previousAnimationValue = currentValue;
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

      _onHoldTrainees = await _traineeService.getTraineesByStatus(
          companyId: companyId,
          status:TraineeStatus.onHold,
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
      _filteredTrainees[2] = List.from(_onHoldTrainees);
      _filteredTrainees[3] = List.from(_upcomingTrainees);
      _filteredTrainees[4] = List.from(_rejectedTrainees);
      _filteredTrainees[5] = List.from(_completedTrainees);

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
        baseList = _onHoldTrainees;
        break;
      case 3:
        baseList = _upcomingTrainees;
        break;
      case 4:
        baseList = _rejectedTrainees;
        break;
      case 5:
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
    GeneralMethods.navigateTo(context,TraineeDetailPage(
      isAuthority: widget.isAuthority,
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
        setState(() {
          _loadTrainees();
        });
      }
    } catch (e,s) {
      debugPrintStack(stackTrace: s);
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
        debugPrint("trainee record is ${trainee.toString()}");

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
      case 2: return 'No On-Hold trainees';
      case 3: return 'No upcoming trainees';
      case 4: return 'No rejected applications';
      case 5: return 'No completed trainees';

      default: return 'No trainees found';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return DefaultTabController(
      key: _scaffoldKey,
      length: 6,
      child: Scaffold(
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
            Expanded(
              child: CustomScrollView(
                slivers: [
                  // Stats for current tab - as a Sliver
                  SliverToBoxAdapter(
                    child: _buildTabStats(_tabController.index),
                  ),

                  // Search bar for current tab - as a Sliver
                  SliverToBoxAdapter(
                    child: _buildSearchBar(_tabController.index),
                  ),

                  // Trainee list for current tab
                  SliverFillRemaining(
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
            ),
          ],
        ),
    ));
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
    final messenger = ScaffoldMessenger.of(context);

    try {
      final data = await _traineeService.exportTraineeData(widget.company.id);

      if (!mounted) return;

      // Generate the report
      String report = _generateTraineeReport(data);

      // Save to file
      final String filePath = await _saveReportToFile(report);

      // Show success message with options
      messenger.showSnackBar(
        SnackBar(
          content: Text('Report saved: ${data.length} trainees'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'VIEW',
            textColor: Colors.white,
            onPressed: () {
              _showReportDialog(report, filePath);
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

  Future<String> _saveReportToFile(String report) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'trainee_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.txt';
      final file = File('${directory.path}/$fileName');

      await file.writeAsString(report);

      debugPrint('Report saved to: ${file.path}');
      return file.path;
    } catch (e) {
      debugPrint('Error saving report to file: $e');
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
                  color: isDark
                      ? Colors.green.withOpacity(0.2)  // Dark mode version
                      : Colors.green.shade50,           // Light mode version
                  child: Row(
                    children: [
                      Icon(
                          Icons.check_circle,
                          color: isDark ? Colors.green.shade300 : Colors.green,
                          size: 16
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
                    color: isDark
                        ? Colors.grey.shade900   // Dark background for dark mode
                        : Colors.grey.shade50,    // Light background for light mode
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark
                          ? Colors.grey.shade700
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      child: SelectableText(
                        report,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: isDark ? Colors.white : Colors.black, // Text color based on theme
                          backgroundColor: Colors.transparent, // Explicitly transparent
                        ),
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
      case 2: return _onHoldTrainees.length;
      case 3: return _upcomingTrainees.length;
      case 4: return _rejectedTrainees.length;
      case 5: return _completedTrainees.length;
      default: return 0;
    }
  }

  String _getStatusLabel(int tabIndex) {
    switch (tabIndex) {
      case 0: return 'Pending';
      case 1: return 'Active';
      case 2: return 'On-Hold';
      case 3: return 'Upcoming';
      case 4: return 'Rejected';
      case 5: return 'Completed';
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