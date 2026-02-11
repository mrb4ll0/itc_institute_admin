import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:itc_institute_admin/itc_logic/firebase/general_cloud.dart';
import 'package:itc_institute_admin/itc_logic/notification/fireStoreNotification.dart';
import 'package:itc_institute_admin/model/authorityCompanyMapper.dart';
import 'package:itc_institute_admin/model/userProfile.dart';
import 'package:itc_institute_admin/view/company/companyDetailPage.dart';
import 'package:itc_institute_admin/view/home/student/studentDetails.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../extensions/extensions.dart';
import '../../../generalmethods/GeneralMethods.dart';
import '../../../itc_logic/firebase/AuthorityRulesHelper.dart';
import '../../../itc_logic/firebase/company_cloud.dart';
import '../../../itc_logic/notification/notitification_service.dart';
import '../../../letterGenerator/GenerateAcceptanceLetter.dart';
import '../../../model/authority.dart';
import '../../../model/company.dart';
import '../../../model/student.dart';
import '../../../model/studentApplication.dart';
import '../industrailTraining/fileDetails.dart';

class StudentApplicationDetailsPage extends StatefulWidget {
  final StudentApplication application;
  final bool isAuthority;


  const StudentApplicationDetailsPage({super.key, required this.application,required this.isAuthority});

  @override
  State<StudentApplicationDetailsPage> createState() =>
      _StudentApplicationDetailsPageState();
}

class _StudentApplicationDetailsPageState
    extends State<StudentApplicationDetailsPage> {
  final DateFormat _dateFormat = DateFormat('dd MMM yyyy');
  final DateFormat _dateTimeFormat = DateFormat('dd MMM yyyy, hh:mm a');
  final Company_Cloud company_cloud = Company_Cloud();
  final NotificationService notificationService = NotificationService();
  final FireStoreNotification fireStoreNotification = FireStoreNotification();
  bool canAcceptOrReject = false;
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    canAcceptOrReject = widget.isAuthority?true:AuthorityRulesHelper.canAcceptStudents(FirebaseAuth.instance.currentUser!.uid);
    loadAuthority();
  }
  
  Authority? authority;
  loadAuthority()async
  {
    authority = await ITCFirebaseLogic().getAuthority(FirebaseAuth.instance.currentUser!.uid);
  }
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final application = widget.application;
    final student = application.student;
    final internship = application.internship;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Application Details'),
        actions: [
          // Status change actions
          if (application.applicationStatus.toLowerCase() == 'pending' && (widget.isAuthority? true:canAcceptOrReject ) ) ...[
            PopupMenuButton<String>(
              onSelected: (value) =>
                  _handleApplicationAction(context, application, value),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'accepted',
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green),
                      SizedBox(width: 8),
                      Text('Accept'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'rejected',
                  child: Row(
                    children: [
                      Icon(Icons.cancel, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Reject'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Application Status Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _getStatusColor(
                  application.applicationStatus,
                ).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _getStatusColor(
                    application.applicationStatus,
                  ).withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _getStatusIcon(application.applicationStatus),
                    color: _getStatusColor(application.applicationStatus),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          application.internship.title,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${application.student.fullName} • ${_dateTimeFormat.format(application.applicationDate)}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(
                        application.applicationStatus,
                      ).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _getStatusColor(application.applicationStatus),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      application.applicationStatus.toUpperCase(),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: _getStatusColor(application.applicationStatus),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Internship Details Section
            _buildSectionTitle('Internship Details'),
            InkWell(
              onTap: ()async
              {
                final itcFirebaseAuthority = ITCFirebaseLogic();
                String uid = FirebaseAuth.instance.currentUser!.uid;
                Company? company = await itcFirebaseAuthority.getCompany(uid);
                if(company == null)
                  {
                    Authority? authority = await itcFirebaseAuthority.getAuthority(uid);
                    if(authority != null)
                      {
                        company = AuthorityCompanyMapper.createCompanyFromAuthority(authority: authority);
                      }
                  }
                if(company == null || internship.company.id == uid)
                  {
                    return;
                  }
                GeneralMethods.navigateTo(context, CompanyDetailPage(company: internship.company, user: UserConverter(company)));
              },
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Company Info
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundImage: internship.company.logoURL.isNotEmpty
                                ? NetworkImage(internship.company.logoURL)
                                : null,
                            backgroundColor: colorScheme.surfaceVariant,
                            child: internship.company.logoURL.isEmpty
                                ? const Icon(Icons.business)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  internship.company.name,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  internship.title,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Internship Details Grid
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: 3,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 8,
                        children: [
                          _buildDetailItem(
                            icon: Icons.work_outline,
                            label: 'Industry',
                            value: internship.company.industry,
                          ),
                          _buildDetailItem(
                            icon: Icons.calendar_today,
                            label: 'Status',
                            value: internship.status,
                          ),
                          if (internship.duration?['selectedDuration'] != null)
                            _buildDetailItem(
                              icon: Icons.access_time,
                              label: 'Duration',
                              value: internship.duration!['selectedDuration'],
                            ),
                          if (internship.stipendAvailable != null)
                            _buildDetailItem(
                              icon: Icons.attach_money,
                              label: 'Stipend',
                              value: internship.stipend ?? 'Negotiable',
                            ),
                          if (internship.startDate != null)
                            _buildDetailItem(
                              icon: Icons.date_range,
                              label: 'Start Date',
                              value: _dateFormat.format(internship.startDate!),
                            ),
                          if (internship.endDate != null)
                            _buildDetailItem(
                              icon: Icons.date_range,
                              label: 'End Date',
                              value: _dateFormat.format(internship.endDate!),
                            ),
                        ],
                      ),

                      // Description
                      if (internship.description.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Description',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          internship.description,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],

                      // Eligibility Criteria
                      if (internship.eligibilityCriteria.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Eligibility Criteria',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          internship.eligibilityCriteria,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Student Details Section
            _buildSectionTitle('Applicant Information'),
            InkWell(
              onTap: () {
                GeneralMethods.navigateTo(
                  context,
                  StudentProfilePage(student: student),
                );
              },
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Student Profile
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 32,
                            backgroundImage: student.imageUrl.isNotEmpty
                                ? NetworkImage(student.imageUrl)
                                : null,
                            backgroundColor: colorScheme.surfaceVariant,
                            child: student.imageUrl.isEmpty
                                ? Text(
                                    student.fullName[0].toUpperCase(),
                                    style: const TextStyle(fontSize: 20),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  student.fullName,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  student.email,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  student.phoneNumber,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Educational Information Grid
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: 3,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 8,
                        children: [
                          _buildDetailItem(
                            icon: Icons.school_outlined,
                            label: 'Institution',
                            value: student.institution,
                          ),
                          _buildDetailItem(
                            icon: Icons.book_outlined,
                            label: 'Course of Study',
                            value: student.courseOfStudy,
                          ),
                          _buildDetailItem(
                            icon: Icons.people_outline,
                            label: 'Department',
                            value: student.department,
                          ),
                          _buildDetailItem(
                            icon: Icons.grade_outlined,
                            label: 'Level',
                            value: student.level,
                          ),
                          _buildDetailItem(
                            icon: Icons.badge_outlined,
                            label: 'Matric No.',
                            value: student.matricNumber,
                          ),
                          _buildDetailItem(
                            icon: Icons.grading,
                            label: 'CGPA',
                            value: student.cgpa.toStringAsFixed(2),
                          ),
                          if (student.admissionDate != null)
                            _buildDetailItem(
                              icon: Icons.login,
                              label: 'Admission Date',
                              value: _dateFormat.format(student.admissionDate!),
                            ),
                          if (student.expectedGraduationDate != null)
                            _buildDetailItem(
                              icon: Icons.logout,
                              label: 'Expected Graduation',
                              value: _dateFormat.format(
                                student.expectedGraduationDate!,
                              ),
                            ),
                        ],
                      ),

                      // Skills Section
                      if (student.skills.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Skills',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: student.skills
                              .map(
                                (skill) => Chip(
                                  label: Text(skill),
                                  backgroundColor: colorScheme.surfaceVariant,
                                ),
                              )
                              .toList(),
                        ),
                      ],

                      // Portfolio URLs
                      if (student.linkedinUrl != null ||
                          student.githubUrl != null ||
                          student.portfolioUrl != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Portfolio Links',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            if (student.linkedinUrl != null)
                              ActionChip(
                                avatar: const Icon(Icons.person),
                                label: const Text('LinkedIn'),
                                onPressed: () =>
                                    _launchUrl(student.linkedinUrl!),
                              ),
                            if (student.githubUrl != null)
                              ActionChip(
                                avatar: const Icon(Icons.code),
                                label: const Text('GitHub'),
                                onPressed: () => _launchUrl(student.githubUrl!),
                              ),
                            if (student.portfolioUrl != null)
                              ActionChip(
                                avatar: const Icon(Icons.public),
                                label: const Text('Portfolio'),
                                onPressed: () =>
                                    _launchUrl(student.portfolioUrl!),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Application Duration Details
            if (application.durationDetails.isNotEmpty) ...[
              _buildSectionTitle('Proposed Training Duration'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: 3,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 8,
                        children: [
                          if (application.durationDetails['startDate'] != null)
                            _buildDetailItem(
                              icon: Icons.play_arrow,
                              label: 'Proposed Start',
                              value: _dateFormat.format(
                                DateTime.parse(
                                  application.durationDetails['startDate'],
                                ),
                              ),
                            ),
                          if (application.durationDetails['endDate'] != null)
                            _buildDetailItem(
                              icon: Icons.stop,
                              label: 'Proposed End',
                              value: _dateFormat.format(
                                DateTime.parse(
                                  application.durationDetails['endDate'],
                                ),
                              ),
                            ),
                          if (application.durationDetails['selectedDuration'] !=
                              null)
                            _buildDetailItem(
                              icon: Icons.timelapse,
                              label: 'Duration',
                              value: application
                                  .durationDetails['selectedDuration'],
                            ),
                          if (application.durationDetails['durationInDays'] !=
                              null)
                            _buildDetailItem(
                              icon: Icons.today,
                              label: 'Total Days',
                              value:
                                  '${application.durationDetails['durationInDays']} days',
                            ),
                        ],
                      ),
                      if (application.durationDetails['description'] != null &&
                          application.durationDetails['description']
                              .toString()
                              .isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Additional Notes',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          application.durationDetails['description'].toString(),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Documents Section
            _buildSectionTitle('Required Documents'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // ID Card
                    _buildDocumentTile(
                      icon: Icons.badge,
                      title: 'Student ID Card',
                      url: application.idCardUrl,
                    ),
                    const Divider(),

                    // IT Letter
                    _buildDocumentTile(
                      icon: Icons.article,
                      title: 'Industrial Training Letter',
                      url: application.itLetterUrl,
                    ),
                    const Divider(),

                    // Additional Forms
                    if (application.attachedFormUrls.isNotEmpty) ...[
                      Text(
                        'Additional Forms',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...application.attachedFormUrls.asMap().entries.map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _buildDocumentTile(
                            icon: Icons.attach_file,
                            title: 'Form ${entry.key + 1}',
                            url: entry.value,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Action Buttons
            if (application.applicationStatus.toLowerCase() == 'pending' && (widget.isAuthority?true: canAcceptOrReject ))
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _handleApplicationAction(
                        context,
                        widget.application,
                        'rejected',
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Colors.red.shade400),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.cancel, color: Colors.red),
                          const SizedBox(width: 8),
                          Text(
                            'Reject',
                            style: TextStyle(color: Colors.red.shade400),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _handleApplicationAction(
                        context,
                        widget.application,
                        'accepted',
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.green,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle, color: Colors.white),
                          SizedBox(width: 8),
                          Text('Accept', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildDetailItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.outline),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentTile({
    required IconData icon,
    required String title,
    required String url,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title, style: Theme.of(context).textTheme.bodyMedium),
      trailing: url.isNotEmpty
          ? IconButton(
              icon: const Icon(Icons.visibility),
              onPressed: () => GeneralMethods.navigateTo(
                context,
                FullScreenViewer(
                  firebasePath: url,
                  fileType: GeneralMethods.getFileTypeFromUrl(url),
                ),
              ),
              tooltip: 'View Document',
            )
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Not Provided',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
    );
  }

  Color _getStatusColor(String status) {
    debugPrint("status is $status");
    switch (status.toLowerCase().trim()) {
      case 'accepted':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return Icons.check_circle;
      case 'pending':
        return Icons.pending;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
  }

  Future<void> _launchUrl(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open: $url'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handleApplicationAction(
    BuildContext context,
    StudentApplication application,
    String action,
  ) {
    // Implement your action logic here
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${action.capitalize()} Application'),
        content: Text('Are you sure you want to $action this application?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Update application status

              GeneralMethods.showLoading(
                context,
                message: "Updating application status",
              );

              
              
              await company_cloud.updateApplicationStatus(
                isAuthority: widget.isAuthority,
                companyId: FirebaseAuth.instance.currentUser!.uid,
                internshipId: application.internship!.id!,
                studentId: application.student.uid,
                status: action,
                application: application,
              );
              Student student = application.student;
              var pdfUrl = '';

              if(widget.isAuthority) {
                AcceptanceLetterData acceptanceLetterData = AcceptanceLetterData(
                    id: application.id,
                    studentName: student.fullName,
                    studentId: student.uid,
                    institutionName: student.institution,
                    institutionAddress: "",
                    institutionPhone: "",
                    institutionEmail: "",
                    authorityName: authority?.name ?? "",
                    companyName: application.internship.company.name,
                    companyAddress: application.internship.company.address,
                    startDate: application.durationDetails['startDate'],
                    endDate: application.durationDetails['endDate'],
                    authorizedSignatoryName: authority?.name ?? "",
                    acceptedAt: DateTime.now(),
                    authorizedSignatoryPosition: "");
                pdfUrl =
                await runPdfGeneration(acceptanceLetterData, userId: student.uid,);

                await Company_Cloud().storeAcceptanceLetter(
                    studentId: application.student.uid,
                    acceptanceLetterData: acceptanceLetterData,
                    internshipId: application.internship.id!,
                    internshipTitle: application.internship.title,
                    companyId: application.internship.company.id,
                    applicationId: application.id,
                    pdfFileUrl: pdfUrl,
                    isAuthority: widget.isAuthority);

              }
              
              bool
              notificationSent = await notificationService.sendNotificationToUser(
                fcmToken: student.fcmToken ?? "",
                title: application.internship.company.name,
                body:
                    "Your application for ${application.internship.title} is ${GeneralMethods.normalizeApplicationStatus(action).toUpperCase()}",
              );

              await fireStoreNotification.sendNotificationToStudent(
                studentUid: student.uid,
                title: application.internship.company.name,
                imageUrl: pdfUrl,
                body:
                    "Your application for ${application.internship.title} is ${GeneralMethods.normalizeApplicationStatus(action).toUpperCase()}",
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

              GeneralMethods.hideLoading(context);
              Navigator.pop(context); // Close confirmation dialog
              Navigator.pop(context); // Close details dialog
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Application ${action}ed successfully'),
                  backgroundColor: action == 'accept'
                      ? Colors.green
                      : Colors.red,
                ),
              );
              setState(() {
                application.applicationStatus = action;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: action == 'accept' ? Colors.green : Colors.red,
            ),
            child: Text(action.capitalize()),
          ),
        ],
      ),
    );
  }
}
