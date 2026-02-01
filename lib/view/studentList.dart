import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:itc_institute_admin/generalmethods/GeneralMethods.dart';
import 'package:itc_institute_admin/itc_logic/firebase/company_cloud.dart';
import 'package:itc_institute_admin/model/student.dart';
import 'package:itc_institute_admin/model/company.dart';
import 'package:itc_institute_admin/model/traineeRecord.dart';
import '../itc_logic/firebase/general_cloud.dart';
import '../itc_logic/service/tranineeService.dart';
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
  final TraineeService _traineeService = TraineeService();
  final ITCFirebaseLogic _itcFirebaseLogic = ITCFirebaseLogic();

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this); // Changed to 5
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
    final Color statusColor = trainee.status.color;
    final String statusText = trainee.status.displayName;
    final IconData statusIcon = trainee.status.icon;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        onDoubleTap: onDoubleTab,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Image with status badge
                  Stack(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.blue.shade100,
                        ),
                        child: GeneralMethods.generateUserAvatar(
                          username: trainee.studentName,
                          imageUrl: trainee.imageUrl,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: Icon(
                            statusIcon,
                            size: 12,
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
                        // Name and Status
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                trainee.studentName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: statusColor.withOpacity(0.3)),
                              ),
                              child: Text(
                                statusText,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: statusColor,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 4),

                        // Department and Role
                        if (trainee.department.isNotEmpty || trainee.role.isNotEmpty)
                          Text(
                            '${trainee.department}${trainee.role.isNotEmpty ? ' • ${trainee.role}' : ''}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),

                        const SizedBox(height: 8),

                        // Dates and Progress
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (trainee.startDate != null)
                              _buildInfoChip(
                                'Starts: ${DateFormat('MMM dd, yyyy').format(trainee.startDate!)}',
                                Icons.calendar_today,
                                Colors.blue,
                              ),
                            if (trainee.endDate != null)
                              _buildInfoChip(
                                'Ends: ${DateFormat('MMM dd, yyyy').format(trainee.endDate!)}',
                                Icons.calendar_today_outlined,
                                Colors.blue,
                              ),
                            if (trainee.progress > 0)
                              _buildInfoChip(
                                'Progress: ${trainee.progress.toStringAsFixed(0)}%',
                                Icons.timeline,
                                _getProgressColor(trainee.progress),
                              ),
                            if (trainee.daysRemaining != null && trainee.isActive)
                              _buildInfoChip(
                                '${trainee.daysRemaining} days left',
                                Icons.timer,
                                Colors.orange,
                              ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // Supervisors
                        if (trainee.supervisorIds.isNotEmpty)
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              const Icon(Icons.supervisor_account, size: 12, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                '${trainee.supervisorIds.length} supervisor${trainee.supervisorIds.length > 1 ? 's' : ''}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),

              // Action buttons based on tab
              if (tabIndex == 0 || tabIndex == 2 || tabIndex == 1)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    children: [],
                  ),
                ),
            ],
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

  Widget _buildInfoChip(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
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
  bool _loadingStudent = true;

  @override
  void initState() {
    super.initState();
    _loadStudentDetails();
  }

  Future<void> _loadStudentDetails() async {
    try {
      final student = await ITCFirebaseLogic().getStudent(widget.trainee.studentId);
      setState(() {
        _student = student;
        _loadingStudent = false;
      });
    } catch (e) {
      setState(() {
        _loadingStudent = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final trainee = widget.trainee;
    final statusColor = trainee.status.color;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with status
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  // Profile Image
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    child: GeneralMethods.generateUserAvatar(username: trainee.studentName,imageUrl:trainee.imageUrl),
                  ),

                  const SizedBox(width: 16),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trainee.studentName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (_student?.email != null)
                          Text(
                            _student!.email,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            trainee.status.displayName,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Training Information
                    _buildSection(
                      title: 'Training Information',
                      icon: Icons.work_history,
                      children: [
                        if (trainee.department.isNotEmpty)
                          _buildInfoRow('Department', trainee.department),
                        if (trainee.role.isNotEmpty)
                          _buildInfoRow('Role', trainee.role),
                        if (trainee.startDate != null)
                          _buildInfoRow(
                            'Start Date',
                            DateFormat('MMM dd, yyyy').format(trainee.startDate!),
                          ),
                        if (trainee.endDate != null)
                          _buildInfoRow(
                            'End Date',
                            DateFormat('MMM dd, yyyy').format(trainee.endDate!),
                          ),
                        if (trainee.actualStartDate != null)
                          _buildInfoRow(
                            'Actual Start',
                            DateFormat('MMM dd, yyyy').format(trainee.actualStartDate!),
                          ),
                        if (trainee.actualEndDate != null)
                          _buildInfoRow(
                            'Actual End',
                            DateFormat('MMM dd, yyyy').format(trainee.actualEndDate!),
                          ),
                        if (trainee.durationInDays != null)
                          _buildInfoRow('Duration', '${trainee.durationInDays} days'),
                        if (trainee.progress > 0)
                          _buildInfoRow('Progress', '${trainee.progress.toStringAsFixed(0)}%'),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Student Information
                    if (_student != null)
                      _buildSection(
                        title: 'Student Information',
                        icon: Icons.school,
                        children: [
                          _buildInfoRow('Name', _student!.fullName),
                          _buildInfoRow('Email', _student!.email),
                          if (_student!.phoneNumber.isNotEmpty)
                            _buildInfoRow('Phone', _student!.phoneNumber),
                          if (_student!.institution.isNotEmpty)
                            _buildInfoRow('Institution', _student!.institution),
                          if (_student!.courseOfStudy.isNotEmpty)
                            _buildInfoRow('Course', _student!.courseOfStudy),
                          if (_student!.level.isNotEmpty)
                            _buildInfoRow('Level', '${_student!.level} Level'),
                          if (_student!.cgpa > 0)
                            _buildInfoRow('CGPA', _student!.cgpa.toStringAsFixed(2)),
                        ],
                      ),

                    const SizedBox(height: 16),

                    // Supervisors
                    if (trainee.supervisorIds.isNotEmpty)
                      _buildSection(
                        title: 'Supervisors',
                        icon: Icons.supervisor_account,
                        children: [
                          for (final supervisorId in trainee.supervisorIds)
                            ListTile(
                              leading: CircleAvatar(
                                child: Text(supervisorId.substring(0, 2).toUpperCase()),
                              ),
                              title: Text('Supervisor ID: $supervisorId'),
                              subtitle: Text('Click to view details'),
                              onTap: () {
                                // Navigate to supervisor details
                              },
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: Colors.blue),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}