import 'package:flutter/material.dart';
import 'package:itc_institute_admin/generalmethods/GeneralMethods.dart';
import 'package:itc_institute_admin/itc_logic/firebase/Student_cloud.dart';
import 'package:itc_institute_admin/itc_logic/firebase/company_cloud.dart';
import 'package:itc_institute_admin/itc_logic/firebase/general_cloud.dart';
import 'package:itc_institute_admin/view/home/studentApplications/studentApplicationDetail.dart';

import '../../../../itc_logic/notification/fireStoreNotification.dart';
import '../../../../itc_logic/notification/notitification_service.dart';
import '../../../../model/student.dart';
import '../../../../model/studentApplication.dart';

class StudentApplicationsPage extends StatefulWidget {
  final String companyId;
  final String studentUid;

  const StudentApplicationsPage({
    Key? key,
    required this.companyId,
    required this.studentUid,
  }) : super(key: key);

  @override
  _StudentApplicationsPageState createState() => _StudentApplicationsPageState();
}

class _StudentApplicationsPageState extends State<StudentApplicationsPage> {
  late Company_Cloud _applicationService;
  List<StudentApplication> _applications = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  final NotificationService notificationService = NotificationService();
  final FireStoreNotification fireStoreNotification = FireStoreNotification();

  @override
  void initState() {
    super.initState();
    _applicationService = Company_Cloud(); // Initialize your service
    _loadApplications();
  }

  Future<void> _loadApplications() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final applications = await _applicationService.getAllApplicationsForStudent(
        widget.companyId,
        widget.studentUid,
      );

      setState(() {
        _applications = applications;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Failed to load applications: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _updateApplicationStatus(
      StudentApplication application,
      String newStatus,
      ) async {
    try {
      setState(() {
        application.applicationStatus = newStatus;
        application.applicationDate = DateTime.now();
      });

      GeneralMethods.showMessageDialog(context, 'Updating application status...');

      // Call your update method here
      await _applicationService.updateApplicationStatus(
        companyId: widget.companyId,
        internshipId: application.internship.id??"",
        studentId: application.student.uid,
          status: newStatus,
        application: application
      );
       Student student = application.student;
      bool
      notificationSent = await notificationService.sendNotificationToUser(
        fcmToken: student.fcmToken ?? "",
        title: application.internship.company.name,
        body:
        "Your application for ${application.internship.title} is ${GeneralMethods.normalizeApplicationStatus(newStatus).toUpperCase()}",
      );

      await fireStoreNotification.sendNotificationToStudent(
        studentUid: student.uid,
        title: application.internship.company.name,
        body:
        "Your application for ${application.internship.title} is ${GeneralMethods.normalizeApplicationStatus(newStatus).toUpperCase()}",
      );
      if (!notificationSent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send notification'),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Notification sent successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Application ${newStatus.toLowerCase()}d successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // Revert on error
      setState(() {
        application.applicationStatus = 'pending';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildStatusChip(String status) {
    Color backgroundColor;
    Color textColor;
    String displayText;

    switch (status.toLowerCase()) {
      case 'accepted':
        backgroundColor = Colors.green.shade100;
        textColor = Colors.green.shade800;
        displayText = 'Accepted';
        break;
      case 'rejected':
        backgroundColor = Colors.red.shade100;
        textColor = Colors.red.shade800;
        displayText = 'Rejected';
        break;
      case 'pending':
        backgroundColor = Colors.orange.shade100;
        textColor = Colors.orange.shade800;
        displayText = 'Pending';
        break;
      case 'under_review':
        backgroundColor = Colors.blue.shade100;
        textColor = Colors.blue.shade800;
        displayText = 'Under Review';
        break;
      default:
        backgroundColor = Colors.grey.shade100;
        textColor = Colors.grey.shade800;
        displayText = status;
    }

    return Chip(
      label: Text(
        displayText,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
      ),
      backgroundColor: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  Widget _buildActionButtons(StudentApplication application) {
    if (application.applicationStatus.toLowerCase() != 'pending') {
      return Container(); // No buttons for non-pending applications
    }

    return Row(
      children: [
        ElevatedButton.icon(
          onPressed: () => _showAcceptConfirmation(application),
          icon: const Icon(Icons.check_circle, size: 18),
          label: const Text('Accept'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: () => _showRejectConfirmation(application),
          icon: const Icon(Icons.cancel, size: 18),
          label: const Text('Reject'),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.red),
            foregroundColor: Colors.red,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  void _showAcceptConfirmation(StudentApplication application) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Accept Application'),
        content: Text(
          'Are you sure you want to accept this application for '
              '${application.internship.title }?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateApplicationStatus(application, 'accepted');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  void _showRejectConfirmation(StudentApplication application) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Application'),
        content: Text(
          'Are you sure you want to reject this application for '
              '${application.internship.title}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateApplicationStatus(application, 'rejected');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  Widget _buildApplicationCard(StudentApplication application) {
    return InkWell(
      onTap: ()
      {
        GeneralMethods.navigateTo(context, StudentApplicationDetailsPage(application: application));
      },
      child: Card(
        elevation: 2,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      application.internship.title ,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _buildStatusChip(application.applicationStatus ),
                ],
              ),

              const SizedBox(height: 12),

              if (application.internship != null &&
                  application.internship.description != null)
                Text(
                  application.internship.description ?? '',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 14,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),

              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (application.applicationDate != null)
                        Text(
                          'Applied: ${_formatDate(application.applicationDate!)}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      if (application.applicationDate != null)
                        Text(
                          'Updated: ${_formatDate(application.applicationDate!)}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),

                  _buildActionButtons(application),
                ],
              ),

              if (application.internship != null &&
                  application.internship.location != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 14,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        application.internship.location ?? '',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.description,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 20),
          Text(
            'No Applications Found',
            style: TextStyle(
              fontSize: 20,
              color: Colors.grey[600],
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'This student has not applied to any internships yet.',
            style: TextStyle(
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _loadApplications,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 80,
            color: Colors.red[300],
          ),
          const SizedBox(height: 20),
          Text(
            'Something went wrong',
            style: TextStyle(
              fontSize: 20,
              color: Colors.grey[600],
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              _errorMessage,
              style: TextStyle(color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _loadApplications,
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 20),
          Text('Loading applications...'),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Applications'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loadApplications,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _hasError
          ? _buildErrorState()
          : _applications.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
        onRefresh: _loadApplications,
        child: ListView.separated(
          itemCount: _applications.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            return _buildApplicationCard(_applications[index]);
          },
        ),
      ),
      floatingActionButton: _applications.isNotEmpty
          ? FloatingActionButton.extended(
        onPressed: () {
          // Show statistics or export
          _showStats();
        },
        icon: const Icon(Icons.analytics),
        label: const Text('Stats'),
        backgroundColor: Colors.blue,
      )
          : null,
    );
  }

  void _showStats() {
    final pendingCount = _applications
        .where((app) => app.applicationStatus.toLowerCase() == 'pending')
        .length;
    final acceptedCount = _applications
        .where((app) => app.applicationStatus.toLowerCase() == 'accepted')
        .length;
    final rejectedCount = _applications
        .where((app) => app.applicationStatus.toLowerCase() == 'rejected')
        .length;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Application Statistics'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatItem('Total Applications', _applications.length, Icons.list),
            _buildStatItem('Pending', pendingCount, Icons.pending, Colors.orange),
            _buildStatItem('Accepted', acceptedCount, Icons.check_circle, Colors.green),
            _buildStatItem('Rejected', rejectedCount, Icons.cancel, Colors.red),
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

  Widget _buildStatItem(String label, int count, IconData icon, [Color? color]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color ?? Colors.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color ?? Colors.blue,
            ),
          ),
        ],
      ),
    );
  }
}