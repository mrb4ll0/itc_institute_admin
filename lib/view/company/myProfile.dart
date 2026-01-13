import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:itc_institute_admin/model/company.dart';
import 'package:itc_institute_admin/itc_logic/firebase/general_cloud.dart';
import 'package:intl/intl.dart';
import 'package:itc_institute_admin/notification/view/companyFormUploadPage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:itc_institute_admin/view/company/companyEdit.dart';

import '../../auth/login_view.dart';
import '../../generalmethods/GeneralMethods.dart';
import '../../itc_logic/help_support/help.dart';
import '../../notification/view/companyFormsList.dart';
import '../home/aboutITConnect.dart'; // Add this import

class CompanyMyProfilePage extends StatefulWidget {
  final Company company;
  final Function(Company) onProfileUpdated; // Callback for when profile is updated

  const CompanyMyProfilePage({
    Key? key,
    required this.company,
    required this.onProfileUpdated,
  }) : super(key: key);

  @override
  _CompanyMyProfilePageState createState() => _CompanyMyProfilePageState();
}

class _CompanyMyProfilePageState extends State<CompanyMyProfilePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ITCFirebaseLogic _firebaseLogic = ITCFirebaseLogic();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Navigate to edit page
  void _navigateToEditPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CompanyEditPage(
          company: widget.company,
          onSave: (updatedCompany) {
            // Update parent widget with new company data
            widget.onProfileUpdated(updatedCompany);
            // Show success message
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Profile updated successfully'),
                backgroundColor: Colors.green,
              ),
            );
            // Refresh local state
            setState(() {});
          },
          onCancel: () {
            Navigator.pop(context);
          },
        ),
      ),
    );
  }



  // Share profile functionality (for recruitment)
  void _shareProfile() {
    final shareText = 'Check out ${widget.company.name} - ${widget.company.industry} company. ${widget.company.description.isNotEmpty ? widget.company.description.substring(0, 10) + '...' : ''}';
    Fluttertoast.showToast(msg: "Feature not available yet ");
    return;
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Copy Profile Link'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Link copied to clipboard')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share via...'),
              onTap: () {
                Navigator.pop(context);
                // Implement native share
              },
            ),
            ListTile(
              leading: const Icon(Icons.qr_code),
              title: const Text('Generate QR Code'),
              onTap: () {
                Navigator.pop(context);
                // Generate QR code for profile
              },
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  // Export company data (for records/backup)
  void _exportCompanyData() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Company Data'),
        content: const Text('Choose format to export your company information'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Export as PDF
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Exporting as PDF...')),
              );
            },
            child: const Text('PDF'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Export as Excel
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Exporting as Excel...')),
              );
            },
            child: const Text('Excel'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      height: 220, // Slightly taller for better visual
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withOpacity(0.8),
            theme.colorScheme.primary.withOpacity(0.6),
          ],
        ),
      ),
      child: Stack(
        children: [
          // Decorative elements
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -20,
            left: -20,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
            ),
          ),

          // Profile content
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Company Logo with edit overlay
                GestureDetector(
                  onTap: _navigateToEditPage,
                  child: Stack(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 4,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: widget.company.logoURL.isNotEmpty
                            ? ClipRRect(
                          borderRadius: BorderRadius.circular(50),
                          child: Image.network(
                            widget.company.logoURL,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: theme.colorScheme.surface,
                                child: Icon(
                                  Icons.business,
                                  size: 40,
                                  color: theme.colorScheme.primary,
                                ),
                              );
                            },
                          ),
                        )
                            : Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.business,
                            size: 40,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.edit,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 16),

                // Company info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.company.name,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.4),
                                    blurRadius: 6,
                                    offset: const Offset(1, 1),
                                  ),
                                ],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (widget.company.isVerified)
                            Icon(
                              Icons.verified,
                              color: Colors.yellow,
                              size: 24,
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.company.industry,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white.withOpacity(0.95),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 16,
                            color: Colors.white.withOpacity(0.9),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${widget.company.state}, ${widget.company.localGovernment}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white.withOpacity(0.9),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'My Company Profile',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white.withOpacity(0.8),
                          fontStyle: FontStyle.italic,
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
    );
  }

  Widget _buildActionButtons(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _navigateToEditPage,
              icon: const Icon(Icons.edit, size: 18),
              label: const Text('Edit Profile'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _shareProfile,
              icon: const Icon(Icons.share, size: 18),
              label: const Text('Share'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: _exportCompanyData,
            icon: const Icon(Icons.download),
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.surfaceVariant,
              padding: const EdgeInsets.all(12),
            ),
            tooltip: 'Export Data',
          ),
        ],
      ),
    );
  }

  // Updated Tab Bar with different tabs for my profile
  Widget _buildTabBar(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.dividerColor),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: theme.colorScheme.primary,
        unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
        indicatorColor: theme.colorScheme.primary,
        indicatorWeight: 3,
        tabs: const [
          Tab(icon: Icon(Icons.dashboard), text: 'Dashboard'),
          Tab(icon: Icon(Icons.info), text: 'Profile Info'), // NEW TAB
          Tab(icon: Icon(Icons.people), text: 'Trainees'),
          Tab(icon: Icon(Icons.analytics), text: 'Analytics'),
          Tab(icon: Icon(Icons.settings), text: 'Settings'),
        ],
      ),
    );
  }

  // Dashboard Tab - Shows overview with stats
  Widget _buildDashboardTab(ThemeData theme) {
    final traineesCount = widget.company.potentialtrainee.length;
    final formCount = widget.company.forms?.length ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome message
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back, ${widget.company.name}!',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.company.description.isNotEmpty
                        ? widget.company.description
                        : 'Complete your company profile to attract more trainees',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Quick Stats
          Text(
            'Quick Stats',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.people,
                  label: 'Trainees',
                  value: traineesCount.toString(),
                  color: Colors.blue,
                  theme: theme,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.description,
                  label: 'Forms',
                  value: formCount.toString(),
                  color: Colors.green,
                  theme: theme,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Profile Completeness
          Text(
            'Profile Completeness',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Complete your profile to get verified',
                        style: theme.textTheme.bodyMedium,
                      ),
                      Text(
                        '${_calculateProfileCompleteness()}%',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: _calculateProfileCompleteness() / 100,
                    backgroundColor: theme.colorScheme.surfaceVariant,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _buildCompletenessItems(theme),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Quick Actions
          Text(
            'Quick Actions',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 1.5,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              _buildActionCard(
                icon: Icons.edit,
                label: 'Update Logo',
                color: Colors.blue,
                onTap: _navigateToEditPage,
                theme: theme,
              ),
              _buildActionCard(
                icon: Icons.description,
                label: 'Upload Forms',
                color: Colors.green,
                onTap: () {
                  // Navigate to forms upload
                  GeneralMethods.navigateTo(context, CompanyFormUploadPage(companyId: widget.company.id, companyName: widget.company.name,));
                },
                theme: theme,
              ),
              _buildActionCard(
                icon: Icons.people,
                label: 'View Trainees',
                color: Colors.orange,
                onTap: () {
                  _tabController.index = 1; // Switch to trainees tab
                },
                theme: theme,
              ),
              _buildActionCard(
                icon: Icons.share,
                label: 'Share Profile',
                color: Colors.purple,
                onTap: _shareProfile,
                theme: theme,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Trainees Tab - Enhanced for company owner
  Widget _buildTraineesTab(ThemeData theme) {
    final trainees = widget.company.potentialtrainee;

    if (trainees.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 80,
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
            ),
            const SizedBox(height: 20),
            Text(
              'No Trainees Yet',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Start attracting trainees by completing your company profile and posting opportunities',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _navigateToEditPage,
              icon: const Icon(Icons.edit),
              label: const Text('Complete Profile'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'My Trainees (${trainees.length})',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  // Export trainees list
                },
                icon: const Icon(Icons.download, size: 16),
                label: const Text('Export List'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: trainees.length,
            itemBuilder: (context, index) {
              final trainee = trainees[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                    child: Icon(
                      Icons.person,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  title: Text(
                    trainee.toString(),
                    style: theme.textTheme.bodyLarge,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Trainee ID: ${trainee.toString().substring(0, 8)}...',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Potential',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.blue,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    // Navigate to trainee profile
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // Analytics Tab - For company insights
  Widget _buildAnalyticsTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Company Analytics',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Profile Views',
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 150,
                    decoration: BoxDecoration(
                      border: Border.all(color: theme.dividerColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        'Analytics dashboard coming soon',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Trainee Engagement',
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    leading: const Icon(Icons.people, color: Colors.blue),
                    title: const Text('Total Trainees'),
                    trailing: Text(
                      widget.company.potentialtrainee.length.toString(),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.trending_up, color: Colors.green),
                    title: const Text('Profile Completion'),
                    trailing: Text(
                      '${_calculateProfileCompleteness()}%',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Settings Tab - Account management
  Widget _buildSettingsTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Account Settings',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.notifications),
                  title: const Text('Notification Settings'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    // Navigate to notification settings
                  },
                ),
                const Divider(height: 0),
                ListTile(
                  leading: const Icon(Icons.privacy_tip),
                  title: const Text('Privacy Settings'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    // Navigate to privacy settings
                  },
                ),
                const Divider(height: 0),
                ListTile(
                  leading: const Icon(Icons.security),
                  title: const Text('Security'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    // Navigate to security settings
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.format_color_text_outlined),
                  title: const Text('IT Forms'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    // Navigate to help
                    GeneralMethods.navigateTo(context, CompanyFormsListPage(company: widget.company,));
                  },
                ),
              ],
            ),
          ),
const SizedBox(height: 20),

          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.help),
                  title: const Text('Help & Support'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    // Navigate to help
                    GeneralMethods.navigateTo(context, CompanyHelpPage());
                  },
                ),
                const Divider(height: 0),
                ListTile(
                  leading: const Icon(Icons.info),
                  title: const Text('About IT Connect'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    // Navigate to about
                    GeneralMethods.navigateTo(context, AboutITConnectPage());
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Account actions
          Card(
            color: Colors.red.withOpacity(0.05),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.logout, color: theme.colorScheme.error),
                  title: Text(
                    'Logout',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                  onTap: ()async {
                    // Logout logic
                   await showLogoutDialog(context);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> showLogoutDialog(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await logout();
      GeneralMethods.replaceNavigationTo(context, const LoginScreen());
    }
  }
  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
    await GoogleSignIn().signOut();
  }

  // Helper methods
  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required ThemeData theme,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _calculateProfileCompleteness() {
    int score = 0;
    if (widget.company.logoURL.isNotEmpty) score += 20;
    if (widget.company.description.isNotEmpty) score += 20;
    if (widget.company.industry.isNotEmpty) score += 15;
    if (widget.company.address.isNotEmpty) score += 15;
    if (widget.company.state.isNotEmpty) score += 15;
    if (widget.company.localGovernment.isNotEmpty) score += 15;
    return score;
  }

  List<Widget> _buildCompletenessItems(ThemeData theme) {
    return [
      _buildCompletenessItem('Logo', widget.company.logoURL.isNotEmpty, theme),
      _buildCompletenessItem('Description', widget.company.description.isNotEmpty, theme),
      _buildCompletenessItem('Industry', widget.company.industry.isNotEmpty, theme),
      _buildCompletenessItem('Address', widget.company.address.isNotEmpty, theme),
      _buildCompletenessItem('State', widget.company.state.isNotEmpty, theme),
      _buildCompletenessItem('Local Govt', widget.company.localGovernment.isNotEmpty, theme),
    ];
  }

  Widget _buildCompletenessItem(String label, bool completed, ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          completed ? Icons.check_circle : Icons.radio_button_unchecked,
          color: completed ? Colors.green : theme.colorScheme.onSurfaceVariant,
          size: 16,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: completed ? Colors.green : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  // NEW: Profile Info Tab - Shows ALL company information
  Widget _buildProfileInfoTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Basic Information Section
          _buildSectionHeader('Basic Information', Icons.business, theme),
          _buildInfoCard(theme, [
            _buildInfoRow('Company Name', widget.company.name, Icons.business_outlined),
            _buildInfoRow('Industry', widget.company.industry, Icons.category),
            _buildInfoRow('Registration Number', widget.company.registrationNumber, Icons.app_registration),
            _buildInfoRow('Description', widget.company.description, Icons.description, isMultiline: true),
          ]),

          const SizedBox(height: 24),

          // Contact Information Section
          _buildSectionHeader('Contact Information', Icons.contact_mail, theme),
          _buildInfoCard(theme, [
            _buildInfoRow('Email', widget.company.email, Icons.email),
            _buildInfoRow('Phone Number', widget.company.phoneNumber, Icons.phone),
          ]),

          const SizedBox(height: 24),

          // Location Information Section
          _buildSectionHeader('Location Information', Icons.location_on, theme),
          _buildInfoCard(theme, [
            _buildInfoRow('Address', widget.company.address, Icons.home, isMultiline: true),
            _buildInfoRow('Local Government', widget.company.localGovernment, Icons.account_balance),
            _buildInfoRow('State', widget.company.state, Icons.map),
          ]),

          const SizedBox(height: 24),

          // Account Status Section
          _buildSectionHeader('Account Status', Icons.verified_user, theme),
          _buildStatusGrid(theme),

          const SizedBox(height: 24),

          // Technical Information Section
          _buildSectionHeader('Technical Information', Icons.code, theme),
          _buildInfoCard(theme, [
            _buildInfoRow('Company ID', widget.company.id, Icons.fingerprint),
            _buildInfoRow('Role', widget.company.role, Icons.people_alt),
            _buildInfoRow('FCM Token', _truncateText(widget.company.fcmToken, 20), Icons.notifications),
            if (widget.company.updatedAt != null)
              _buildInfoRow(
                'Last Updated',
                DateFormat('MMM dd, yyyy • hh:mm a').format(widget.company.updatedAt!),
                Icons.update,
              ),
          ]),

          const SizedBox(height: 24),

          // Documents Section
          if (widget.company.forms != null && widget.company.forms!.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader('Uploaded Documents', Icons.description, theme),
                _buildDocumentsList(theme),
                const SizedBox(height: 24),
              ],
            ),

          // Trainees Count
          _buildSectionHeader('Trainee Information', Icons.people, theme),
          _buildInfoCard(theme, [
            _buildInfoRow(
              'Potential Trainees',
              widget.company.potentialtrainee.length.toString(),
              Icons.group,
            ),
          ]),

          const SizedBox(height: 32),

          // Edit Profile Button
          Center(
            child: ElevatedButton.icon(
              onPressed: _navigateToEditPage,
              icon: const Icon(Icons.edit),
              label: const Text('Edit Company Profile'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(ThemeData theme, List<Widget> children) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon, {bool isMultiline = false}) {
    if (value.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                isMultiline
                    ? Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                )
                    : Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusGrid(ThemeData theme) {
    final statuses = [
      _buildStatusItem('Active', widget.company.isActive, Colors.green, Icons.check_circle),
      _buildStatusItem('Verified', widget.company.isVerified, Colors.blue, Icons.verified),
      _buildStatusItem('Approved', widget.company.isApproved, Colors.green, Icons.thumb_up),
      _buildStatusItem('Pending', widget.company.isPending, Colors.orange, Icons.pending),
      _buildStatusItem('Rejected', widget.company.isRejected, Colors.red, Icons.thumb_down),
      _buildStatusItem('Blocked', widget.company.isBlocked, Colors.red, Icons.block),
      _buildStatusItem('Suspended', widget.company.isSuspended, Colors.orange, Icons.pause_circle),
      _buildStatusItem('Banned', widget.company.isBanned, Colors.red, Icons.do_not_disturb),
      _buildStatusItem('Muted', widget.company.isMuted, Colors.orange, Icons.volume_off),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 3,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: statuses,
    );
  }

  Widget _buildStatusItem(String label, bool isActive, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isActive ? color.withOpacity(0.1) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive ? color.withOpacity(0.3) : Colors.grey.shade300,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: isActive ? color : Colors.grey,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: isActive ? color : Colors.grey,
              ),
            ),
          ),
          Icon(
            isActive ? Icons.check : Icons.close,
            size: 16,
            color: isActive ? color : Colors.grey,
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsList(ThemeData theme) {
    final documents = widget.company.forms!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${documents.length} Document${documents.length > 1 ? 's' : ''}',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...documents.asMap().entries.map((entry) {
              final index = entry.key;
              final url = entry.value;
              final fileName = url.downloadUrl?.split('/').last;

              return ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.insert_drive_file, size: 20),
                ),
                title: Text(
                  'Document ${index + 1}: ${_truncateText(fileName??"not specified", 30)}',
                  style: theme.textTheme.bodyMedium,
                ),
                subtitle: Text(
                  _truncateText(url.fileName??url.downloadUrl??"", 40),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.download),
                  onPressed: () {
                    // Download document
                  },
                ),
                onTap: () {
                  // Open document
                },
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  String _truncateText(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 230,
              floating: false,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: _buildHeader(theme),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () {
                    _tabController.index = 4; // Switch to settings tab
                  },
                  tooltip: 'Settings',
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: _buildActionButtons(theme),
            ),
            SliverPersistentHeader(
              delegate: _SliverAppBarDelegate(
                child: _buildTabBar(theme),
              ),
              pinned: true,
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildDashboardTab(theme),      // Index 0
            _buildProfileInfoTab(theme),    // Index 1 - NEW
            _buildTraineesTab(theme),       // Index 2
            _buildAnalyticsTab(theme),      // Index 3
            _buildSettingsTab(theme),       // Index 4
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToEditPage,
        child: const Icon(Icons.edit),
        tooltip: 'Edit Profile',
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _SliverAppBarDelegate({required this.child});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: Theme.of(context).colorScheme.background, child: child);
  }

  @override
  double get maxExtent => 70;

  @override
  double get minExtent => 55;

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return child != oldDelegate.child;
  }
}