import 'dart:convert';
import 'dart:typed_data';  // For Uint8List
import 'dart:ui' as ui;    // For ImageByteFormat
import 'dart:async';       // For FutureOr if needed
import 'dart:io';          // For File operations
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' hide Uint8List;
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:intl/intl.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:itc_institute_admin/theme/app_theme.dart';
import 'package:itc_institute_admin/traineeRecord/traineeRecordService.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../../generalmethods/GeneralMethods.dart';
import '../../../itc_logic/firebase/general_cloud.dart';
import '../../../itc_logic/service/tranineeService.dart';
import '../../../model/company.dart';
import '../../../model/student.dart';
import '../../../model/traineeRecord.dart';
import '../../../notification/firebase/Firebase_push_notifications.dart';
import '../student/studentDetails.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';

class TraineeDetailPage extends StatefulWidget {
  final TraineeRecord trainee;
  final int tabIndex;
  final TraineeService traineeService;
  final VoidCallback onStatusChanged;
  final isAuthority;

  const TraineeDetailPage({
    Key? key,
    required this.trainee,
    required this.tabIndex,
    required this.traineeService,
    required this.onStatusChanged,
    required this.isAuthority
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
                                  trainee.statusDescription??trainee.holdReason,
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
            // ListTile(
            //   leading: const Icon(Icons.delete, color: Colors.red),
            //   title: const Text('Delete', style: TextStyle(color: Colors.red)),
            //   onTap: () {
            //     Navigator.pop(context);
            //     _confirmDelete();
            //   },
            // ),
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Update Trainee Status',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Current Status: ${widget.trainee.status.displayName}',
                style: TextStyle(
                  color: widget.trainee.status.color,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),

              // Status Selection
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    _buildStatusOption(
                      context,
                      status: TraineeStatus.pending,
                      icon: Icons.pending_actions,
                      description: 'Awaiting review and approval',
                      show: true,
                    ),
                    _buildStatusOption(
                      context,
                      status: TraineeStatus.accepted,
                      icon: Icons.check_circle_outline,
                      description: 'Approved, waiting to start',
                      show: true,
                    ),
                    _buildStatusOption(
                      context,
                      status: TraineeStatus.active,
                      icon: Icons.play_circle,
                      description: 'Currently training',
                      show: true,
                    ),
                    _buildStatusOption(
                      context,
                      status: TraineeStatus.onHold,
                      icon: Icons.pause_circle,
                      description: 'Temporarily paused',
                      show: true,
                    ),
                    _buildStatusOption(
                      context,
                      status: TraineeStatus.completed,
                      icon: Icons.check_circle,
                      description: 'Successfully finished training',
                      show: true,
                    ),

                    // Divider for end states
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider(),
                    ),

                    _buildStatusOption(
                      context,
                      status: TraineeStatus.withdrawn,
                      icon: Icons.exit_to_app,
                      description: 'Student voluntarily left the program',
                      show: true,
                    ),
                    _buildStatusOption(
                      context,
                      status: TraineeStatus.terminated,
                      icon: Icons.cancel,
                      description: 'Removed by admin/company',
                      show: true,
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

  Widget _buildStatusOption(
      BuildContext context, {
        required TraineeStatus status,
        required IconData icon,
        required String description,
        required bool show,
      }) {
    if (!show) return const SizedBox.shrink();

    final isSelected = widget.trainee.status == status;
    final color = status.color;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? color : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: () => _confirmStatusUpdate(context, status),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      status.displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle, color: color),
            ],
          ),
        ),
      ),
    );
  }

  String _withdrawalReason = '';
  String _terminationReason = '';
  String _holdReason = '';

// In your confirmation dialog
  void _confirmStatusUpdate(BuildContext context, TraineeStatus newStatus) {
    // Close the bottom sheet
    Navigator.pop(context);

    // Show confirmation dialog with appropriate fields
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Update to ${newStatus.displayName}?'),
        content: StatefulBuilder(
          builder: (context, setState) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Changing from ${widget.trainee.status.displayName} to ${newStatus.displayName}',
                ),
                const SizedBox(height: 16),
            
                // Status-specific content
                if (newStatus == TraineeStatus.completed) ...[
                  _buildInfoBox(
                    color: Colors.green,
                    icon: Icons.check,
                    message: 'Training will be marked as complete. End date set to today.',
                  ),
                ],
            
                if (newStatus == TraineeStatus.withdrawn) ...[
                  _buildInfoBox(
                    color: Colors.orange,
                    icon: Icons.warning,
                    message: 'Student has voluntarily withdrawn from the program.',
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Withdrawal Reason:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Enter reason for withdrawal (e.g., personal, academic, etc.)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onChanged: (value) => _withdrawalReason = value,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.info, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Student record will be preserved for future reference.',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
            
                if (newStatus == TraineeStatus.onHold) ...[
                  _buildInfoBox(
                    color: Colors.blue,
                    icon: Icons.pause,
                    message: 'Training will be paused. You can resume at any time.',
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Hold Reason:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Enter reason for placing on hold',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onChanged: (value) => _holdReason = value,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.info, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Student progress will be saved and can be resumed later.',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
            
                if (newStatus == TraineeStatus.terminated) ...[
                  _buildInfoBox(
                    color: Colors.red,
                    icon: Icons.warning,
                    message: 'This is an involuntary removal from the program.',
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Termination Reason:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Enter reason for termination (e.g., policy violation, etc.)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onChanged: (value) => _terminationReason = value,
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              // Clear reasons
              _withdrawalReason = '';
              _terminationReason = '';
              _holdReason = '';
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _performStatusUpdate(newStatus);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: newStatus.color,
              foregroundColor: Colors.white,
            ),
            child: Text('Update to ${newStatus.displayName}'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBox({
    required Color color,
    required IconData icon,
    required String message,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }


  Future<void> _performStatusUpdate(TraineeStatus newStatus) async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final trainee = widget.trainee;
      final now = DateTime.now();

      // Determine the reason based on status
      String? reason;
      Map<String, dynamic>? additionalData;

      switch (newStatus) {
        case TraineeStatus.withdrawn:
          reason = _withdrawalReason.isNotEmpty ? _withdrawalReason : null;
          break;
        case TraineeStatus.terminated:
          reason = _terminationReason.isNotEmpty ? _terminationReason : null;
          break;
        case TraineeStatus.onHold:
          reason = _holdReason.isNotEmpty ? _holdReason : null;
          // You can add any additional data for onHold if needed
          additionalData = {
            'holdDate': now,
          };
          break;
        default:
          reason = null;
          break;
      }

      // Use the service to update the status
      final success = await TraineeService(FirebaseAuth.instance.currentUser!.uid)
          .updateTraineeStatus(
        traineeId: trainee.id,
        newStatus: newStatus,
        reason: reason,
        additionalData: additionalData,
      );

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      if (success) {
        // Send notifications
        await _sendStatusChangeNotifications(newStatus);

        // Show success message
        Fluttertoast.showToast(
          msg: "Status updated to ${newStatus.displayName}",
          backgroundColor: newStatus.color,
          textColor: Colors.white,
        );

        // Refresh parent screen
        widget.onStatusChanged();

        // Log the change
        await _logStatusChange(newStatus);
      } else {
        Fluttertoast.showToast(
          msg: "Failed to update status",
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }

      // Clear reasons after use
      _withdrawalReason = '';
      _terminationReason = '';
      _holdReason = '';

    } catch (e, s) {
      debugPrintStack(stackTrace: s);
      if (mounted) Navigator.pop(context);
      Fluttertoast.showToast(
        msg: "Failed to update status: $e",
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );

      // Clear reasons even on error
      _withdrawalReason = '';
      _terminationReason = '';
      _holdReason = '';
    }
  }

// Helper method to send notifications
  Future<void> _sendStatusChangeNotifications(TraineeStatus newStatus) async {
    try {
      // Get the current user's name/email for the notification
      final currentUser = FirebaseAuth.instance.currentUser;
      final actorName = currentUser?.displayName ?? currentUser?.email ?? 'Admin';
      Student? student = await ITCFirebaseLogic(currentUser!.uid).getStudent(widget.trainee.studentId);
      if(student == null)
        {
          Fluttertoast.showToast(msg: "An Error occure while getting student Information");
          return;
        }

      // Create notification for the trainee (if you have their FCM token)
      if (student.fcmToken != null) {
        await NotificationService().sendNotificationToUser(
          fcmToken: student.fcmToken!,
          title: 'Status Update',
          body: 'Your status has been updated to ${newStatus.displayName}',
          data: {
            'type': 'status_update',
            'status': newStatus.name,
            'traineeId': widget.trainee.id,
          },
        );
      }

      // Log notification in Firestore (optional)
      await FirebaseFirestore.instance.collection('notifications').add({
        'traineeId': widget.trainee.id,
        'traineeName': student.fullName,
        'status': newStatus.name,
        'actor': actorName,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });

    } catch (e) {
      debugPrint('Error sending notifications: $e');
      // Don't throw - notification failure shouldn't break the status update
    }
  }


  String _buildStatusDescription(TraineeStatus newStatus) {
    final now = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

    switch (newStatus) {
      case TraineeStatus.active:
        return 'Training started on $now';
        case TraineeStatus.rejected:
        return 'Training Rejected on $now';
        case TraineeStatus.withdrawn:
        return 'Training Withdrawn on $now';
      case TraineeStatus.completed:
        return 'Training completed on $now';
      case TraineeStatus.onHold:
        return 'Training paused on $now';
        case TraineeStatus.accepted:
        return 'Training Accepted on $now';
      case TraineeStatus.terminated:
        return _terminationReason.isNotEmpty
            ? 'Terminated on $now: $_terminationReason'
            : 'Terminated on $now';
      case TraineeStatus.pending:
        return 'Status reset to pending on $now';
    }
  }


  Future<void> _logStatusChange(TraineeStatus newStatus) async {
    final logEntry = {
      'traineeId': widget.trainee.studentId,
      'studentName': widget.trainee.studentName,
      'oldStatus': widget.trainee.status.toString(),
      'newStatus': newStatus.toString(),
      'changedBy': FirebaseAuth.instance.currentUser?.uid,
      'changedAt': DateTime.now().toIso8601String(),
      'reason': _terminationReason,
    };

    // Save to Firebase or local log
    print('Status change logged: $logEntry');
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
    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
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
              title: const Text('Share as Summary'),
              subtitle: const Text('Basic trainee information'),
              onTap: () => _shareAsSummary(),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
              title: const Text('Export as PDF'),
              subtitle: const Text('Full profile with all details'),
              onTap: () => _exportAsPDF(),
            ),
            ListTile(
              leading: const Icon(Icons.qr_code, color: Colors.black),
              title: const Text('Generate QR Code'),
              subtitle: const Text('Quick access to profile'),
              onTap: () => _generateQRCode(),
            ),
            ListTile(
              leading: const Icon(Icons.email, color: Colors.green),
              title: const Text('Send via Email'),
              subtitle: const Text('Share profile link'),
              onTap: () => _shareViaEmail(),
            ),
            ListTile(
              leading: const Icon(Icons.copy, color: Colors.purple),
              title: const Text('Copy Profile Link'),
              subtitle: const Text('Copy to clipboard'),
              onTap: () => _copyProfileLink(),
            ),
          ],
        ),
      ),
    );
  }

  void _shareAsSummary() {
    final trainee = widget.trainee;

    String summary = '''
Trainee Profile Summary
═══════════════════════

👤 Student: ${trainee.studentName}
📊 Status: ${trainee.status.displayName}
🏢 Company: ${_company?.name ?? 'Loading...'}
📅 Department: ${trainee.department}
💼 Role: ${trainee.role}

📆 Training Period:
  Start: ${trainee.startDate != null ? DateFormat('yyyy-MM-dd').format(trainee.startDate!) : 'N/A'}
  End: ${trainee.endDate != null ? DateFormat('yyyy-MM-dd').format(trainee.endDate!) : 'N/A'}
  
📈 Progress: ${trainee.progress.toStringAsFixed(0)}%

━━━━━━━━━━━━━━━━━━━━━━
Shared from ITC Institute Admin
''';

    Share.share(summary, subject: 'Trainee Profile: ${trainee.studentName}');
  }

  Future<void> _exportAsPDF() async {
    try {
      Fluttertoast.showToast(msg: "Generating PDF...");

      // Generate PDF with complete trainee information
      final pdf = await _generateTraineePDF();

      // Save PDF to device
      if (await _requestStoragePermission()) {
        final output = await getTemporaryDirectory();
        final file = File('${output.path}/trainee_${widget.trainee.studentId}.pdf');
        await file.writeAsBytes(await pdf.save());

        // Share the PDF
        final xFile = XFile(file.path);
        await Share.shareXFiles(
          [xFile],
          text: 'Trainee Profile: ${widget.trainee.studentName}',
          subject: 'Trainee Profile PDF',
        );
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Failed to generate PDF: $e");
    }
  }

  void _generateQRCode() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Trainee QR Code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: QrImageView(
                data: _generateProfileLink(),
                version: QrVersions.auto,
                size: 200,
                backgroundColor: Colors.white,
                embeddedImage: const AssetImage('assets/logo_small.png'),
                embeddedImageStyle: QrEmbeddedImageStyle(
                  size: const Size(40, 40),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.trainee.studentName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              widget.trainee.status.displayName,
              style: TextStyle(color: widget.trainee.status.color),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () => _shareQRCode(),
            icon: const Icon(Icons.share),
            label: const Text('Share QR'),
          ),
        ],
      ),
    );
  }

  void _shareQRCode() async {
    try {
      // Close the QR code dialog first
      Navigator.pop(context);

      Fluttertoast.showToast(msg: "Preparing QR code...");

      // Generate the QR code as an image
      final qrCodeImage = await _generateQRCodeImage();

      // Save to temporary file
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/trainee_qr_${widget.trainee.studentId}.png';
      final file = File(filePath);
      await file.writeAsBytes(qrCodeImage as List<int>);

      // Share the image
      final xFile = XFile(filePath);
      await Share.shareXFiles(
        [xFile],
        text: 'QR Code for Trainee: ${widget.trainee.studentName}',
        subject: 'Trainee QR Code',
      );

      // Optional: Clean up temp file after sharing
      // file.delete();

    } catch (e) {
      Fluttertoast.showToast(msg: "Failed to share QR code: $e");

      // Fallback: Share just the text/link instead
 //     _shareProfileLinkAsFallback();
    }
  }

  Future<Uint8List> _generateQRCodeImage() async {
    final qrCodeData = _generateProfileLink();

    final qrPainter = QrPainter(
      data: qrCodeData,
      version: QrVersions.auto,
      gapless: false,
      color: Colors.black,
    );

    final ui.Image image = await qrPainter.toImage(300); // Use ui.Image
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png); // Use ui.ImageByteFormat

    return byteData!.buffer.asUint8List();
  }
  void _shareViaEmail() async {
    final trainee = widget.trainee;
    final student = _student;

    final emailBody = '''
<html>
<body>
<h2>Trainee Profile: ${trainee.studentName}</h2>

<h3>Training Information</h3>
<ul>
  <li><strong>Status:</strong> ${trainee.status.displayName}</li>
  <li><strong>Company:</strong> ${_company?.name ?? 'N/A'}</li>
  <li><strong>Department:</strong> ${trainee.department}</li>
  <li><strong>Role:</strong> ${trainee.role}</li>
  <li><strong>Period:</strong> ${trainee.startDate != null ? DateFormat('yyyy-MM-dd').format(trainee.startDate!) : 'N/A'} to ${trainee.endDate != null ? DateFormat('yyyy-MM-dd').format(trainee.endDate!) : 'N/A'}</li>
  <li><strong>Progress:</strong> ${trainee.progress.toStringAsFixed(0)}%</li>
</ul>

<h3>Student Information</h3>
<ul>
  <li><strong>Email:</strong> ${student?.email ?? 'N/A'}</li>
  <li><strong>Phone:</strong> ${student?.phoneNumber ?? 'N/A'}</li>
  <li><strong>Institution:</strong> ${student?.institution ?? 'N/A'}</li>
  <li><strong>Course:</strong> ${student?.courseOfStudy ?? 'N/A'}</li>
</ul>

<hr>
<p>View full profile in the ITC Institute Admin app.</p>
</body>
</html>
''';

    final email = Email(
      subject: 'Trainee Profile: ${trainee.studentName}',
      body: emailBody,
      isHTML: true,
    );

    await FlutterEmailSender.send(email);
  }

  void _copyProfileLink() {
    final link = _generateProfileLink();

    Clipboard.setData(ClipboardData(text: link));

    Fluttertoast.showToast(
      msg: "Profile link copied to clipboard",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
    );

    // Show snackbar as well
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Profile link copied'),
        action: SnackBarAction(
          label: 'Share',
          onPressed: _shareAsSummary,
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _generateProfileLink() {
    // This could be a deep link to the app
    return 'itc-institute://trainee/${widget.trainee.studentId}';

    // Or a web URL if you have a web portal
    // return 'https://admin.itcinstitute.com/trainee/${widget.trainee.studentId}';
  }

  Future<bool> _requestStoragePermission() async {
    if (await Permission.storage.request().isGranted) {
      return true;
    }

    if (await Permission.storage.request().isPermanentlyDenied) {
      openAppSettings();
      return false;
    }

    return false;
  }
  Future<pw.Document> _generateTraineePDF() async {
    final pdf = pw.Document();
    final trainee = widget.trainee;

    pdf.addPage(
      pw.Page(  // Add pw. prefix here
        build: (pw.Context context) => pw.Center(  // Add pw. prefix
          child: pw.Column(  // Add pw. prefix
            mainAxisAlignment: pw.MainAxisAlignment.center,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Trainee Profile',
                  style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)
              ),
              pw.SizedBox(height: 20),
              pw.Text('Student: ${trainee.studentName}'),
              pw.Text('Status: ${trainee.status.displayName}'),
              pw.SizedBox(height: 10),

              if (_company != null) ...[
                pw.Text('Company Information',
                    style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)
                ),
                pw.Text('Name: ${_company!.name}'),
                if (_company!.industry.isNotEmpty)
                  pw.Text('Industry: ${_company!.industry}'),
                if (_company!.phoneNumber.isNotEmpty)
                  pw.Text('Phone: ${_company!.phoneNumber}'),
                if (_company!.address.isNotEmpty)
                  pw.Text('Address: ${_company!.address}'),
                pw.SizedBox(height: 10),
              ],

              pw.Text('Training Information',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)
              ),
              pw.Text('Department: ${trainee.department}'),
              pw.Text('Role: ${trainee.role}'),
              if (trainee.startDate != null && trainee.endDate != null)
                pw.Text('Period: ${DateFormat('yyyy-MM-dd').format(trainee.startDate!)} - ${DateFormat('yyyy-MM-dd').format(trainee.endDate!)}'),
              pw.Text('Progress: ${trainee.progress.toStringAsFixed(0)}%'),
              pw.Text('Status: ${trainee.statusDescription}'),
              pw.SizedBox(height: 10),

              if (_student != null) ...[
                pw.Text('Student Information',
                    style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)
                ),
                pw.Text('Email: ${_student!.email}'),
                if (_student!.phoneNumber.isNotEmpty)
                  pw.Text('Phone: ${_student!.phoneNumber}'),
                if (_student!.institution.isNotEmpty)
                  pw.Text('Institution: ${_student!.institution}'),
                if (_student!.courseOfStudy.isNotEmpty)
                  pw.Text('Course: ${_student!.courseOfStudy}'),
              ],
            ],
          ),
        ),
      ),
    );

    return pdf;
  }

  void _exportData() {
    showModalBottomSheet(
      isScrollControlled: true,
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
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Export Trainee Data',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
              title: const Text('Export as PDF'),
              subtitle: const Text('Complete profile with all details'),
              onTap: () {
                Navigator.pop(context);
                _exportAsPDF(); // Reuse your existing PDF export
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart, color: Colors.green),
              title: const Text('Export as CSV'),
              subtitle: const Text('For spreadsheets and data analysis'),
              onTap: () {
                Navigator.pop(context);
                _exportAsCSV();
              },
            ),
            ListTile(
              leading: const Icon(Icons.description, color: Colors.blue),
              title: const Text('Export as JSON'),
              subtitle: const Text('For developers and API integration'),
              onTap: () {
                Navigator.pop(context);
                _exportAsJSON();
              },
            ),
            ListTile(
              leading: const Icon(Icons.share, color: Colors.purple),
              title: const Text('Export Summary'),
              subtitle: const Text('Quick text summary'),
              onTap: () {
                Navigator.pop(context);
                _shareAsSummary(); // Reuse your existing summary share
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _exportAsCSV() async {
    try {
      Fluttertoast.showToast(msg: "Generating CSV...");

      final trainee = widget.trainee;

      // Create CSV content
      StringBuffer csv = StringBuffer();

      // Headers
      csv.writeln('Category,Field,Value');

      // Basic Info
      csv.writeln('Basic,Student Name,${_escapeCSV(trainee.studentName)}');
      csv.writeln('Basic,Status,${trainee.status.displayName}');

      // Company Info
      if (_company != null) {
        csv.writeln('Company,Company Name,${_escapeCSV(_company!.name)}');
        csv.writeln('Company,Industry,${_escapeCSV(_company!.industry)}');
        csv.writeln('Company,Phone,${_escapeCSV(_company!.phoneNumber)}');
        csv.writeln('Company,Address,${_escapeCSV(_company!.address)}');
      }

      // Training Info
      csv.writeln('Training,Department,${_escapeCSV(trainee.department)}');
      csv.writeln('Training,Role,${_escapeCSV(trainee.role)}');
      if (trainee.startDate != null) {
        csv.writeln('Training,Start Date,${DateFormat('yyyy-MM-dd').format(trainee.startDate!)}');
      }
      if (trainee.endDate != null) {
        csv.writeln('Training,End Date,${DateFormat('yyyy-MM-dd').format(trainee.endDate!)}');
      }
      csv.writeln('Training,Progress,${trainee.progress.toStringAsFixed(0)}%');
      csv.writeln('Training,Status Description,${_escapeCSV(trainee.statusDescription)}');

      // Student Info
      if (_student != null) {
        csv.writeln('Student,Email,${_escapeCSV(_student!.email)}');
        csv.writeln('Student,Phone,${_escapeCSV(_student!.phoneNumber)}');
        csv.writeln('Student,Institution,${_escapeCSV(_student!.institution)}');
        csv.writeln('Student,Course,${_escapeCSV(_student!.courseOfStudy)}');
        csv.writeln('Student,Level,${_student!.level}');
        if (_student!.cgpa > 0) {
          csv.writeln('Student,CGPA,${_student!.cgpa.toStringAsFixed(2)}');
        }
      }

      // Notes
      if (trainee.notes.isNotEmpty) {
        trainee.notes.forEach((key, value) {
          csv.writeln('Note,${_escapeCSV(key)},${_escapeCSV(value.toString())}');
        });
      }

      // Save CSV file
      if (await _requestStoragePermission()) {
        final output = await getTemporaryDirectory();
        final fileName = 'trainee_${widget.trainee.studentId}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
        final file = File('${output.path}/$fileName');
        await file.writeAsString(csv.toString());

        // Share the CSV
        final xFile = XFile(file.path);
        await Share.shareXFiles(
          [xFile],
          text: 'Trainee Data: ${widget.trainee.studentName}',
          subject: 'Trainee Export CSV',
        );

        Fluttertoast.showToast(msg: "CSV exported successfully");
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Failed to export CSV: $e");
    }
  }

  String _escapeCSV(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
  Future<void> _exportAsJSON() async {
    try {
      Fluttertoast.showToast(msg: "Generating JSON...");

      final trainee = widget.trainee;

      // Create JSON object
      Map<String, dynamic> jsonData = {
        'traineeId': trainee.studentId,
        'studentName': trainee.studentName,
        'status': trainee.status.displayName,
        'statusCode': trainee.status.toString(),
        'statusDescription': trainee.statusDescription,
        'needsStatusUpdate': trainee.needsStatusUpdate,
        'progress': trainee.progress,
        'department': trainee.department,
        'role': trainee.role,
        'imageUrl': trainee.imageUrl,
        'supervisorIds': trainee.supervisorIds,
        'notes': trainee.notes,
        'dates': {
          'startDate': trainee.startDate?.toIso8601String(),
          'endDate': trainee.endDate?.toIso8601String(),
          'actualStartDate': trainee.actualStartDate?.toIso8601String(),
          'actualEndDate': trainee.actualEndDate?.toIso8601String(),
        },
        'durationInDays': trainee.durationInDays,
        'company': _company != null ? {
          'id': _company!.id,
          'name': _company!.name,
          'industry': _company!.industry,
          'phoneNumber': _company!.phoneNumber,
          'address': _company!.address,
          'email': _company!.email,
        } : null,
        'student': _student != null ? {
          'id': _student!.uid,
          'fullName': _student!.fullName,
          'email': _student!.email,
          'phoneNumber': _student!.phoneNumber,
          'institution': _student!.institution,
          'courseOfStudy': _student!.courseOfStudy,
          'level': _student!.level,
          'cgpa': _student!.cgpa,
        } : null,
        'exportedAt': DateTime.now().toIso8601String(),
      };

      // Convert to pretty JSON
      String jsonString = const JsonEncoder.withIndent('  ').convert(jsonData);

      // Save JSON file
      if (await _requestStoragePermission()) {
        final output = await getTemporaryDirectory();
        final fileName = 'trainee_${widget.trainee.studentId}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.json';
        final file = File('${output.path}/$fileName');
        await file.writeAsString(jsonString);

        // Share the JSON
        final xFile = XFile(file.path);
        await Share.shareXFiles(
          [xFile],
          text: 'Trainee JSON Data: ${widget.trainee.studentName}',
          subject: 'Trainee Export JSON',
        );

        Fluttertoast.showToast(msg: "JSON exported successfully");
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Failed to export JSON: $e");
    }
  }

  void _archiveTrainee() {
    // Archive logic
    Fluttertoast.showToast(msg: "Feature will be available in the next version");
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
              Fluttertoast.showToast(msg: "Feature will be available in the next version");
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