import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:itc_institute_admin/theme/app_theme.dart';
import '../../../generalmethods/GeneralMethods.dart';
import '../../../itc_logic/firebase/general_cloud.dart';
import '../../../itc_logic/service/tranineeService.dart';
import '../../../model/company.dart';
import '../../../model/student.dart';
import '../../../model/traineeRecord.dart';
import '../student/studentDetails.dart';

class TraineeDetailPage extends StatefulWidget {
  final TraineeRecord trainee;
  final int tabIndex;
  final TraineeService traineeService;
  final VoidCallback onStatusChanged;

  const TraineeDetailPage({
    Key? key,
    required this.trainee,
    required this.tabIndex,
    required this.traineeService,
    required this.onStatusChanged,
  }) : super(key: key);

  @override
  State<TraineeDetailPage> createState() => _TraineeDetailPageState();
}

class _TraineeDetailPageState extends State<TraineeDetailPage> {
  Student? _student;
  Company? _company;
  bool _loadingStudent = true;
  bool _loadingCompany = true;
  final ScrollController _scrollController = ScrollController();
  bool _isHeaderExpanded = true;

  @override
  void initState() {
    super.initState();
    _loadStudentDetails();
    _loadCompanyDetails();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.offset > 100 && _isHeaderExpanded) {
      setState(() => _isHeaderExpanded = false);
    } else if (_scrollController.offset <= 100 && !_isHeaderExpanded) {
      setState(() => _isHeaderExpanded = true);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
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

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Custom App Bar with expanded header
          SliverAppBar(
            expandedHeight: _isHeaderExpanded ? 280 : 120,
            pinned: true,
            stretch: true,
            backgroundColor: statusColor,
            foregroundColor: Colors.white,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: _showActionMenu,
              ),
              IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: _showMoreOptions,
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: _isHeaderExpanded
                  ? null
                  : Text(
                trainee.studentName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      statusColor,
                      statusColor.withOpacity(0.7),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Profile Section
                        Row(
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
                              child: InkWell(
                                onTap: () async {
                                  Student? student = await ITCFirebaseLogic(FirebaseAuth.instance.currentUser!.uid)
                                      .getStudent(trainee.studentId);
                                  if (student == null) {
                                    Fluttertoast.showToast(msg: "Student Record not found");
                                    return;
                                  }
                                  GeneralMethods.navigateTo(context, StudentProfilePage(student: student));
                                },
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
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Content
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Company Information Card
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

                // Student Information
                // Student Information
                _buildSection(
                  context,
                  title: 'Student Information',
                  icon: Icons.school,
                  children: [
                    if (_loadingStudent)
                      _buildLoadingStudentInfoVertical(context)
                    else if (_student != null)
                      Column(
                        children: [
                          _buildVerticalInfoTile(
                            context,
                            label: 'Full Name',
                            value: _student!.fullName,
                            icon: Icons.person,
                            color: Colors.blue,
                          ),
                          const SizedBox(height: 8),
                          _buildVerticalInfoTile(
                            context,
                            label: 'Email',
                            value: _student!.email,
                            icon: Icons.email,
                            color: Colors.red,
                          ),
                          if (_student!.phoneNumber.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _buildVerticalInfoTile(
                              context,
                              label: 'Phone',
                              value: _student!.phoneNumber,
                              icon: Icons.phone,
                              color: Colors.green,
                            ),
                          ],
                          if (_student!.institution.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _buildVerticalInfoTile(
                              context,
                              label: 'Institution',
                              value: _student!.institution,
                              icon: Icons.school,
                              color: Colors.purple,
                            ),
                          ],
                          if (_student!.courseOfStudy.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _buildVerticalInfoTile(
                              context,
                              label: 'Course',
                              value: _student!.courseOfStudy,
                              icon: Icons.menu_book,
                              color: Colors.orange,
                            ),
                          ],
                          if (_student!.level.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _buildVerticalInfoTile(
                              context,
                              label: 'Level',
                              value: '${_student!.level} Level',
                              icon: Icons.grade,
                              color: Colors.teal,
                            ),
                          ],
                          if (_student!.cgpa > 0) ...[
                            const SizedBox(height: 8),
                            _buildVerticalInfoTile(
                              context,
                              label: 'CGPA',
                              value: _student!.cgpa.toStringAsFixed(2),
                              icon: Icons.star,
                              color: Colors.amber,
                            ),
                          ],
                        ],
                      )
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
                    children: trainee.notes.entries.map((entry) =>
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
                    ).toList(),
                  ),

                const SizedBox(height: 40), // Extra bottom padding
              ]),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(context, statusColor),
    );
  }

  Widget _buildVerticalInfoTile(
      BuildContext context, {
        required String label,
        required String value,
        required IconData icon,
        required Color color,
      }) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingStudentInfoVertical(BuildContext context) {
    return Column(
      children: List.generate(7, (index) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _buildLoadingVerticalTile(context),
      )),
    );
  }

  Widget _buildLoadingVerticalTile(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Icon placeholder
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const ShimmerLoading(
              child: SizedBox.expand(),
            ),
          ),
          const SizedBox(width: 12),
          // Text placeholders
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Label shimmer
                Container(
                  width: 80,
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
                  width: double.infinity,
                  height: 16,
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
    );
  }

  Widget _buildBottomBar(BuildContext context, Color statusColor) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
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
                onPressed: _navigateToAction,
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
    );
  }

  void _showActionMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.edit_note),
              title: const Text('Update Status'),
              onTap: () {
                Navigator.pop(context);
                _navigateToStatusUpdate();
              },
            ),
            ListTile(
              leading: const Icon(Icons.message),
              title: const Text('Send Message'),
              onTap: () {
                Navigator.pop(context);
                _navigateToMessage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.schedule),
              title: const Text('Schedule Meeting'),
              onTap: () {
                Navigator.pop(context);
                _navigateToSchedule();
              },
            ),
            ListTile(
              leading: const Icon(Icons.assignment),
              title: const Text('Assign Task'),
              onTap: () {
                Navigator.pop(context);
                _navigateToAssignTask();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.share, color: Colors.blue),
              title: const Text('Share Profile'),
              onTap: () {
                Navigator.pop(context);
                _shareProfile();
              },
            ),
            ListTile(
              leading: const Icon(Icons.download, color: Colors.green),
              title: const Text('Export Data'),
              onTap: () {
                Navigator.pop(context);
                _exportData();
              },
            ),
            ListTile(
              leading: const Icon(Icons.archive, color: Colors.orange),
              title: const Text('Archive'),
              onTap: () {
                Navigator.pop(context);
                _archiveTrainee();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToAction() {
    // Navigate to action page
    Fluttertoast.showToast(msg: "Feature will be available in the next version");
  }

  void _navigateToStatusUpdate() {
    // Navigate to status update page
  }

  void _navigateToMessage() {
    // Navigate to messaging
  }

  void _navigateToSchedule() {
    // Navigate to scheduling
  }

  void _navigateToAssignTask() {
    // Navigate to task assignment
  }

  void _shareProfile() {
    // Share profile logic
  }

  void _exportData() {
    // Export data logic
  }

  void _archiveTrainee() {
    // Archive logic
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Trainee'),
        content: const Text('Are you sure you want to delete this trainee? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
              // Perform delete
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ==================== HELPER WIDGETS ====================

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
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

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

  Widget _buildInfoGrid(BuildContext context, List<Widget> tiles) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Use a fixed height approach instead of aspect ratio
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: (constraints.maxWidth / 2 - 12) / 60, // 60px fixed height
          children: tiles,
        );
      },
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 12, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 10,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                    fontSize: 12,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon placeholder
          Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const ShimmerLoading(
              child: SizedBox.expand(),
            ),
          ),
          // Text placeholders column
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Label shimmer
                Container(
                  width: 50,
                  height: 8,
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: const ShimmerLoading(
                    child: SizedBox.expand(),
                  ),
                ),
                // Value shimmer
                Container(
                  width: 70,
                  height: 10,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(2),
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

// ShimmerLoading class
class ShimmerLoading extends StatefulWidget {
  final Widget child;

  const ShimmerLoading({Key? key, required this.child}) : super(key: key);

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with TickerProviderStateMixin {
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