import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:itc_institute_admin/generalmethods/GeneralMethods.dart';
import 'package:itc_institute_admin/itc_logic/firebase/company_cloud.dart';
import 'package:itc_institute_admin/itc_logic/firebase/general_cloud.dart';
import 'package:itc_institute_admin/model/companyForm.dart';
import 'package:itc_institute_admin/model/internship_model.dart';
import 'package:itc_institute_admin/view/home/industrailTraining/EditIndustrialTraining.dart';
import 'package:itc_institute_admin/view/home/industrailTraining/fileDetails.dart';
import 'package:itc_institute_admin/view/home/industrailTraining/specificITApplicationLists.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../model/company.dart';

class InternshipDetailsPage extends StatefulWidget {
  final IndustrialTraining internship;

  const InternshipDetailsPage({super.key, required this.internship});

  @override
  State<InternshipDetailsPage> createState() => _InternshipDetailsPageState();
}

class _InternshipDetailsPageState extends State<InternshipDetailsPage> {
  bool _isExpanded = false;
  bool _showFullDescription = false;
  late IndustrialTraining _internship;
  final Company_Cloud company_cloud = Company_Cloud();
  final ITCFirebaseLogic itcFirebaseLogic = ITCFirebaseLogic();

  @override
  void initState() {
    super.initState();
    _internship = widget.internship;
    _incrementViewCount();
  }

  Future<void> _incrementViewCount() async {
    // You could implement view count increment logic here
    // For example: Firestore update
  }

  String _formatDateTime(DateTime? date) {
    if (date == null) return 'Not specified';
    return DateFormat('MMM dd, yyyy - hh:mm a').format(date);
  }

  Future<void> _launchEmail(String email) async {
    final uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot launch email client'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));

    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 16, // Below status bar
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.check, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'Copied to clipboard',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);

    // Remove after 2 seconds
    Future.delayed(Duration(seconds: 2), () {
      overlayEntry.remove();
    });
  }

  void _toggleStatus() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Change Internship Status'),
        content: Text('Are you sure you want to change the status?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              String status = widget.internship.status.toLowerCase() == 'open'
                  ? 'closed'
                  : 'open';
              await _updateStatus(status);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Status updated successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _editInternship() {
    GeneralMethods.navigateTo(
      context,
      EditIndustrialTrainingPage(training: widget.internship),
    );
  }

  void _deleteInternship() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Internship'),
        content: Text(
          'Are you sure you want to delete this internship? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await company_cloud.deleteInternship(widget.internship);
              Navigator.pop(context);
              Navigator.pop(context); // Go back to previous page
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Internship deleted successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip() {
    final status = _internship.status.toLowerCase();
    Color backgroundColor;
    Color textColor;
    IconData icon;

    switch (status) {
      case 'open':
        backgroundColor = Colors.green.withOpacity(0.1);
        textColor = Colors.green;
        icon = Icons.check_circle_outline;
        break;
      case 'closed':
        backgroundColor = Colors.red.withOpacity(0.1);
        textColor = Colors.red;
        icon = Icons.cancel_outlined;
        break;
      case 'filled':
        backgroundColor = Colors.blue.withOpacity(0.1);
        textColor = Colors.blue;
        icon = Icons.people_outline;
        break;
      default:
        backgroundColor = Colors.grey.withOpacity(0.1);
        textColor = Colors.grey;
        icon = Icons.help_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: textColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 6),
          Text(
            _internship.status.toUpperCase(),
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    bool copyable = false,
  }) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (copyable)
                    GestureDetector(
                      onTap: () => _copyToClipboard(value),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              value,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.content_copy,
                            size: 14,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    )
                  else
                    Text(
                      value,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
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

  Widget _buildStatsCard() {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatItem(
                  icon: Icons.people_alt_outlined,
                  label: 'Intake',
                  value: _internship.intake.toString(),
                  color: Colors.blue,
                ),
                _buildStatItem(
                  icon: Icons.description_outlined,
                  label: 'Applications',
                  value: _internship.applicationsCount.toString(),
                  color: Colors.green,
                ),
                _buildStatItem(
                  icon: Icons.check_circle_outline,
                  label: 'Accepted',
                  value: _internship.acceptedApplications.length.toString(),
                  color: Colors.purple,
                ),
                _buildStatItem(
                  icon: Icons.visibility_outlined,
                  label: 'Views',
                  value: _internship.viewCount.toString(),
                  color: Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: _internship.applicationsCount / _internship.intake,
              backgroundColor: theme.colorScheme.surfaceVariant,
              color: theme.colorScheme.primary,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Fill Rate',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  '${((_internship.applicationCount / _internship.intake) * 100).toStringAsFixed(1)}%',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildSkillChip(String skill) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
        ),
      ),
      child: Text(
        skill,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildAttachmentCard() {
    // We'll load universal forms separately
    // For now, just show internship attachments
    return FutureBuilder<Company?>(
      future: _loadCompanyData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingAttachmentCard();
        }

        final company = snapshot.data;
        final universalForms = company?.forms ?? [];
        final specificForms = _internship.files ?? _internship.attachmentUrls;

        // If no forms at all, return empty
        if (universalForms.isEmpty && specificForms.isEmpty) {
          return const SizedBox();
        }

        return _buildAttachmentCardContent(
          context,
          universalForms: universalForms,
          specificForms: specificForms,
          companyName: company?.name ?? 'Company',
        );
      },
    );
  }

  Future<Company?> _loadCompanyData() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return null;

      return await itcFirebaseLogic.getCompany(currentUser.uid);
    } catch (e) {
      debugPrint('Error loading company data: $e');
      return null;
    }
  }

  Widget _buildLoadingAttachmentCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.attach_file,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Loading Forms...',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentCardContent(
    BuildContext context, {
    required List<CompanyForm> universalForms,
    required List<dynamic> specificForms,
    required String companyName,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.attach_file,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Forms & Attachments',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if ( specificForms.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${ specificForms.length}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // Internship-Specific Forms Section
            if (specificForms.isNotEmpty)
              _buildFormsSection(
                context,
                title: 'IT-Specific Forms',
                subtitle: 'Forms specific to this IT position',
                forms: specificForms,
                icon: Icons.assignment,
                isUniversal: false,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormsSection(
    BuildContext context, {
    required String title,
    required String subtitle,
    required List<dynamic> forms,
    required IconData icon,
    required bool isUniversal,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isUniversal
                    ? Colors.blue.withOpacity(0.1)
                    : Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 20,
                color: isUniversal
                    ? Colors.blue
                    : Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (isUniversal)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Universal',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: Colors.blue,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${forms.length}',
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Forms List

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: forms.map((item) {
            debugPrint("form is $item");
            if (item is CompanyForm) {
              return _buildFormItem(
                context,
                (item).downloadUrl??"",
                isUniversal: isUniversal,
              );
            }

            if (item is String) {
              return _buildFormItem(
                context,
                item, 
                isUniversal: isUniversal,
              );
            }


            return const SizedBox.shrink();
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildFormItem(
    BuildContext context,
    String url, {
    bool isUniversal = false,
  }) {
    final fileName = url.split('/').last;
    final fileType = _getFileTypeFromUrl(url);

    Color getFileColor() {
      if (isUniversal) return Colors.blue;

      if (fileType == 'pdf') return Colors.red;
      if (fileType == 'image') return Colors.green;
      if (fileType == 'document') return Colors.blue;
      if (fileType == 'spreadsheet') return Colors.green;
      return Theme.of(context).colorScheme.primary;
    }

    IconData getFileIcon() {
      if (isUniversal) return Icons.business_center;

      if (fileType == 'pdf') return Icons.picture_as_pdf;
      if (fileType == 'image') return Icons.image;
      if (fileType == 'document') return Icons.description;
      if (fileType == 'spreadsheet') return Icons.table_chart;
      return Icons.insert_drive_file;
    }

    String getFileTypeName() {
      if (fileType == 'pdf') return 'PDF Form';
      if (fileType == 'image') return 'Image';
      if (fileType == 'document') return 'Document';
      if (fileType == 'spreadsheet') return 'Spreadsheet';
      return 'File';
    }

    return GestureDetector(
      onTap: () {
        // Open form with full-screen viewer
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => FullScreenViewer(
              firebasePath: url,
              fileName: fileName,
              fileType: fileType,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: getFileColor().withOpacity(0.3),
            width: isUniversal ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: getFileColor().withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(getFileIcon(), size: 18, color: getFileColor()),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 140,
                  child: Text(
                    fileName,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                      overflow: TextOverflow.ellipsis,
                      color: isUniversal ? Colors.blue : null,
                    ),
                    maxLines: 2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isUniversal ? 'Company Form' : getFileTypeName(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: getFileColor(),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getFileTypeFromUrl(String url) {
    final fileName = url.toLowerCase();

    if (fileName.contains('.pdf')) return 'pdf';
    if (fileName.contains('.jpg') || fileName.contains('.jpeg')) return 'image';
    if (fileName.contains('.png')) return 'image';
    if (fileName.contains('.gif')) return 'image';
    if (fileName.contains('.doc') || fileName.contains('.docx'))
      return 'document';
    if (fileName.contains('.xls') || fileName.contains('.xlsx'))
      return 'spreadsheet';
    return 'file';
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot open URL'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? theme.colorScheme.surfaceContainerHighest
          : theme.colorScheme.surfaceContainerLowest,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // App Bar with hero image
            SliverAppBar(
              expandedHeight: 200,
              pinned: true,
              floating: true,
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  _internship.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        theme.colorScheme.primary.withOpacity(0.8),
                        theme.colorScheme.primary.withOpacity(0.3),
                      ],
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.work_outline,
                      size: 64,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: _editInternship,
                  tooltip: 'Edit Internship',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _deleteInternship,
                  tooltip: 'Delete Internship',
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    if (value == 'share') {
                      // Share internship
                    } else if (value == 'status') {
                      _toggleStatus();
                    } else if (value == 'export') {
                      // Export data
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'share',
                      child: Row(
                        children: [
                          Icon(Icons.share, size: 20),
                          SizedBox(width: 8),
                          Text('Share'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'status',
                      child: Row(
                        children: [
                          Icon(Icons.change_circle_outlined, size: 20),
                          SizedBox(width: 8),
                          Text('Change Status'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'export',
                      child: Row(
                        children: [
                          Icon(Icons.download_outlined, size: 20),
                          SizedBox(width: 8),
                          Text('Export Data'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Main Content
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Company Header
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: theme.colorScheme.surfaceVariant,
                              image: _internship.companyLogoUrl != null
                                  ? DecorationImage(
                                      image: NetworkImage(
                                        _internship.companyLogoUrl ??
                                            _internship.company.logoURL,
                                      ),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: _internship.companyLogoUrl == null
                                ? Icon(
                                    Icons.business,
                                    size: 32,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _internship.company.name,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _internship.industry ??
                                      _internship.company.industry,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.location_on_outlined,
                                      size: 14,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        _internship.location,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          _buildStatusChip(),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Stats Card
                  _buildStatsCard(),

                  const SizedBox(height: 16),

                  // Description Section
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Description',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _internship.description,
                            style: theme.textTheme.bodyMedium,
                            maxLines: _showFullDescription ? null : 3,
                            overflow: _showFullDescription
                                ? TextOverflow.clip
                                : TextOverflow.ellipsis,
                          ),
                          if (_internship.description.length > 150)
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _showFullDescription = !_showFullDescription;
                                });
                              },
                              child: Text(
                                _showFullDescription
                                    ? 'Show Less'
                                    : 'Read More',
                                style: TextStyle(
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Key Information Grid
                  const SizedBox(height: 16),

                  // Requirements Section
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Requirements & Eligibility',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Skills
                          if (_internship.requiredSkills.isNotEmpty)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Required Skills',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w500,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: _internship.requiredSkills
                                      .split(',')
                                      .map(
                                        (skill) =>
                                            _buildSkillChip(skill.trim()),
                                      )
                                      .toList(),
                                ),
                                const SizedBox(height: 16),
                              ],
                            ),

                          // Eligibility Criteria
                          if (_internship.eligibilityCriteria.isNotEmpty)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Eligibility Criteria',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w500,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _internship.eligibilityCriteria,
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ],
                            ),

                          // Aptitude Test
                          Container(
                            margin: const EdgeInsets.only(top: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceVariant,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _internship.aptitudeTestRequired
                                      ? Icons.check_circle
                                      : Icons.cancel,
                                  color: _internship.aptitudeTestRequired
                                      ? Colors.green
                                      : Colors.red,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _internship.aptitudeTestRequired
                                        ? 'Aptitude Test Required'
                                        : 'No Aptitude Test Required',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Contact Information
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.contact_page_outlined,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Contact Information',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildInfoCard(
                            icon: Icons.person_outline,
                            title: 'Contact Person',
                            value: _internship.contactPerson,
                            copyable: true,
                          ),
                          const SizedBox(height: 8),
                          _buildInfoCard(
                            icon: Icons.email_outlined,
                            title: 'Department',
                            value: _internship.department,
                          ),
                          const SizedBox(height: 8),
                          _buildInfoCard(
                            icon: Icons.calendar_today,
                            title: 'Posted On',
                            value: _formatDateTime(_internship.postedAt),
                          ),
                          const SizedBox(height: 8),
                          _buildInfoCard(
                            icon: Icons.update,
                            title: 'Last Updated',
                            value: _formatDateTime(_internship.updatedAt),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Attachments Section
                  _buildAttachmentCard(),

                  const SizedBox(height: 16),

                  // Metadata Section
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Metadata',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceVariant,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  'ID: ${_internship.id?.substring(0, 8)}...',
                                  style: theme.textTheme.labelSmall,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceVariant,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  _internship.isTemplate
                                      ? 'Template'
                                      : 'Single Use',
                                  style: theme.textTheme.labelSmall,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceVariant,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  _internship.isUniversalForm
                                      ? 'Universal Form'
                                      : 'Custom Form',
                                  style: theme.textTheme.labelSmall,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                ]),
              ),
            ),
          ],
        ),
      ),

      // Floating Action Buttons
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (_internship.isOpen)
            FloatingActionButton.extended(
              onPressed: () {
                debugPrint("internship details page post id ${widget.internship.id}");
                GeneralMethods.navigateTo(
                  context,
                  SpecificITStudentApplicationsPage(
                    itId: widget.internship.id ?? "",
                  ),
                );
              },
              icon: const Icon(Icons.people_outline),
              label: const Text('Applicants'),
              backgroundColor: theme.colorScheme.primary,
            ),
          // const SizedBox(height: 16),
          // FloatingActionButton(
          //   onPressed: () {
          //     // Share internship
          //   },
          //   child: const Icon(Icons.share_outlined),
          // ),
        ],
      ),
    );
  }

  _updateStatus(String status) async {
    await company_cloud.updateInternshipStatus(widget.internship, status);
    setState(() {
      widget.internship.status = status;
    });
  }
}
