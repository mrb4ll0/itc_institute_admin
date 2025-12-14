import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:itc_institute_admin/auth/login_view.dart';
import 'package:itc_institute_admin/generalmethods/GeneralMethods.dart';
import 'package:itc_institute_admin/view/home/chatListPage.dart';
import 'package:itc_institute_admin/view/home/companyDashBoard.dart';
import 'package:itc_institute_admin/view/home/studentApplicationPage.dart';
import 'package:itc_institute_admin/view/home/tweet_view.dart';

import '../../itc_logic/firebase/general_cloud.dart';
import '../../model/company.dart';
import 'iTList.dart';

class CompanyDashboardController extends StatefulWidget {
  final Company tweetCompany;
  const CompanyDashboardController({super.key, required this.tweetCompany});

  @override
  State<CompanyDashboardController> createState() =>
      _CompanyDashboardControllerState();
}

class _CompanyDashboardControllerState
    extends State<CompanyDashboardController> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  Company? _company;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _pages = [
      const Companydashboard(),
      const StudentApplicationsPage(),
      const IndustrialTrainingPostsPage(),
      TweetView(company: widget.tweetCompany),
      const ChatListPage(),
    ];
    _loadCompany();
  }

  Future<void> _loadCompany() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final company = await ITCFirebaseLogic().getCompany(currentUser.uid);
        setState(() {
          _company = company;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading company: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _onBottomNavTapped(int index) {
    _pageController.jumpToPage(index);
  }

  List<Widget> _pages = [];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Show loading while company data is being fetched
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Company Portal'), elevation: 0),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Company Portal'),
        elevation: 0,
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
      ),
      drawer: _company != null
          ? _buildDrawer(theme, _company!)
          : _buildEmptyDrawer(theme),
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        children: _pages,
      ),
      bottomNavigationBar: _buildBottomNavigationBar(theme),
    );
  }

  Widget _buildDrawer(ThemeData theme, Company company) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(company.name),
            accountEmail: Text(company.email),
            currentAccountPicture: CircleAvatar(
              backgroundColor: theme.colorScheme.onPrimary,
              child: GeneralMethods.generateUserAvatar(
                username: company.name,
                imageUrl: company.logoURL,
              ),
            ),
            decoration: BoxDecoration(color: theme.colorScheme.primary),
          ),
          _buildDrawerItem(
            icon: Icons.edit,
            text: 'Edit Profile',
            onTap: () {},
          ),
          _buildDrawerItem(
            icon: Icons.settings,
            text: 'Settings',
            onTap: () {},
          ),
          _buildDrawerItem(
            icon: Icons.help_outline,
            text: 'Help & Support',
            onTap: () {},
          ),
          _buildDrawerItem(icon: Icons.nightlight, text: 'Theme', onTap: () {}),
          const Divider(),
          _buildDrawerItem(
            icon: Icons.logout,
            text: 'Logout',
            onTap: () async {
              await showLogoutDialog(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyDrawer(ThemeData theme) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: const Text('Company Portal'),
            accountEmail: const Text('Loading...'),
            currentAccountPicture: CircleAvatar(
              backgroundColor: theme.colorScheme.onPrimary,
              child: const Icon(Icons.business),
            ),
            decoration: BoxDecoration(color: theme.colorScheme.primary),
          ),
          ListTile(
            leading: const Icon(Icons.error),
            title: const Text('No Company Data'),
            subtitle: const Text('Please contact support'),
          ),
          const Divider(),
          _buildDrawerItem(
            icon: Icons.logout,
            text: 'Logout',
            onTap: () async {
              await showLogoutDialog(context);
            },
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

  ListTile _buildDrawerItem({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return ListTile(leading: Icon(icon), title: Text(text), onTap: onTap);
  }

  Widget _buildBottomNavigationBar(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onBottomNavTapped,
        type: BottomNavigationBarType.fixed,
        backgroundColor: theme.bottomNavigationBarTheme.backgroundColor,
        selectedItemColor: theme.bottomNavigationBarTheme.selectedItemColor,
        unselectedItemColor: theme.bottomNavigationBarTheme.unselectedItemColor,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.description_outlined),
            activeIcon: Icon(Icons.description),
            label: 'Applications',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt_outlined),
            activeIcon: Icon(Icons.list_alt),
            label: 'IT List',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.feedback_sharp),
            activeIcon: Icon(Icons.message),
            label: 'Feeds',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.message_outlined),
            activeIcon: Icon(Icons.message),
            label: 'Messages',
          ),
        ],
      ),
    );
  }
}
