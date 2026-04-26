import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:itc_institute_admin/auth/login_view.dart';
import 'package:itc_institute_admin/generalmethods/GeneralMethods.dart';
import 'package:itc_institute_admin/itc_logic/firebase/Student_cloud.dart';
import 'package:itc_institute_admin/itc_logic/help_support/help.dart';
import 'package:itc_institute_admin/model/AuthorityRule.dart';
import 'package:itc_institute_admin/model/authorityCompanyMapper.dart';
import 'package:itc_institute_admin/notification/view/NotificationPage.dart';
import 'package:itc_institute_admin/view/acceptanceLetter.dart';
import 'package:itc_institute_admin/view/authority/CompanyAuthoritySpecificationPage.dart';
import 'package:itc_institute_admin/view/authorityRule/authorityRule.dart';
import 'package:itc_institute_admin/view/company/myProfile.dart';
import 'package:itc_institute_admin/view/home/LinkedCompaniesScreen.dart';
import 'package:itc_institute_admin/view/home/chat/chartPage.dart';
import 'package:itc_institute_admin/view/home/chatListPage.dart';
import 'package:itc_institute_admin/view/home/companyAuthority/myAuthority.dart';
import 'package:itc_institute_admin/view/home/companyDashBoard.dart';
import 'package:itc_institute_admin/view/home/studentApplicationPage.dart';
import 'package:itc_institute_admin/view/home/themePage.dart';
import 'package:itc_institute_admin/view/home/tweet_view.dart';
import 'package:itc_institute_admin/view/studentList.dart';
import 'package:provider/provider.dart';
import '../../itc_logic/firebase/AuthorityRulesHelper.dart';
import '../../itc_logic/firebase/StudentAcceptanceRepository.dart';
import '../../itc_logic/firebase/authority_cloud.dart';
import '../../itc_logic/firebase/company_cloud.dart';
import '../../itc_logic/firebase/general_cloud.dart';
import '../../itc_logic/firebase/message/message_service.dart';
import '../../itc_logic/firebase/provider/theme_provider.dart';
import '../../itc_logic/idservice/globalIdService.dart';
import '../../itc_logic/service/tranineeService.dart';
import '../../model/authority.dart';
import '../../model/company.dart';
import '../CompanyAuthoritySpecificationDialog.dart';
import '../accountClaim/accountClaim.dart';
import '../authorityRule/service/ruleService.dart';
import '../authorityRule/views/authoriityViewModel.dart';
import '../company/companyEdit.dart';
import '../minimalStudentAcceptanceRule/studentAcceptanceRule.dart';
import 'dialog/pendingCompanyDialog.dart';
import 'iTList.dart';

class CompanyDashboardController extends StatefulWidget {
  final Company tweetCompany;
  const CompanyDashboardController({super.key, required this.tweetCompany});


  @override
  State<CompanyDashboardController> createState() =>
      _CompanyDashboardControllerState();
}

class _CompanyDashboardControllerState
    extends State<CompanyDashboardController> with TickerProviderStateMixin{
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  Company? _company;
  bool _isLoading = true;

  // Add AuthorityService instance
  final AuthorityService _authorityService = AuthorityService(GlobalIdService.firestoreId);

  @override
  void initState() {
    super.initState();

    _pages = [
      TweetView(company: widget.tweetCompany),
       StudentApplicationsPage(isAuthority: widget.tweetCompany.originalAuthority != null, companyIds: widget.tweetCompany.originalAuthority?.linkedCompanies??[],),
       IndustrialTrainingPostsPage(isAuthority: widget.tweetCompany.originalAuthority != null, companyIds: widget.tweetCompany.originalAuthority?.linkedCompanies??[],),
       MessagesView(),
    ];

      WidgetsBinding.instance.addPostFrameCallback(
            (_) async {

              if(widget.tweetCompany.originalAuthority != null)
              {
                showPendingCompaniesDialog(context, widget.tweetCompany.originalAuthority!);

              }
              await loadAuthorityRules();
              await _loadCompany();

              if (_company != null &&
                  (_company!.isUnderAuthority == false) &&
                  widget.tweetCompany.originalAuthority == null) {
                checkAndShowAuthoritySpecificationDialog(
                  context: context,
                  company: _company!,
                  firebaseLogic: ITCFirebaseLogic(GlobalIdService.firestoreId),
                );
              }


            }

      );

  }

  loadAuthorityRules()async
  {
    final repo = StudentAcceptanceRepository();

// Fetch rule first
    AuthorityRule? rule = await repo.fetchRule(widget.tweetCompany.originalAuthority != null?widget.tweetCompany.id:widget.tweetCompany.authorityId??"");
    debugPrint("authorityRule ${rule?.toMap()}");
    if (rule != null) {
      AuthorityRulesHelper.initRule(rule);

      // Preload all companies under this authority
      await AuthorityRulesHelper.preloadCompanies(rule.authorityId!);
    }
  }

  Future<void> _loadCompany() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      Company? company ;
      if (currentUser != null) {
         company = await ITCFirebaseLogic(GlobalIdService.firestoreId).getCompany(GlobalIdService.firestoreId);
         if(company == null)
           {
             Authority? authority = await ITCFirebaseLogic(GlobalIdService.firestoreId).getAuthority(GlobalIdService.firestoreId);
              if(authority != null)
                {
                  company = AuthorityCompanyMapper.createCompanyFromAuthority(authority: authority);
                }
           }
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Show loading while company data is being fetched
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "IT Connect",
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              _AnimatedTitle()
            ],
          ),
        ), elevation: 0,actions: [
          _AnimatedNotificationBell()],),
        body: const Center(child: CircularProgressIndicator()),
      );
    }


    return Scaffold(
      appBar: AppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "IT Connect",
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              _AnimatedTitle()
            ],
          ),
        ),
        actions: [_AnimatedNotificationBell()],
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
            onDetailsPressed: ()
            {
              GeneralMethods.navigateTo(context, CompanyMyProfilePage(company: company, isAuthority: widget.tweetCompany.originalAuthority != null,
              onProfileUpdated: (updatedCompany)
                {
                   company = updatedCompany;
                },));
            },
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
            onTap: () {
               if(_company == null)
                 {
                   Fluttertoast.showToast(msg: "Company not found , kindly logout and login ");
                   return;
                 }
              navigateToEditCompany(_company!);
            },
          ),_buildDrawerItem(
            icon: Icons.people,
            text: 'Student List',
            onTap: () {
               if(_company == null)
                 {
                   Fluttertoast.showToast(msg: "Company not found , kindly logout and login ");
                   return;
                 }
              GeneralMethods.navigateTo(context, StudentListPage(company: _company!,isAuthority: widget.tweetCompany.originalAuthority != null));
            },
          ),_buildDrawerItem(
            icon: Icons.people,
            text: 'Acceptance Letters',
            onTap: () {
               if(_company == null)
                 {
                   Fluttertoast.showToast(msg: "Company not found , kindly logout and login ");
                   return;
                 }
              GeneralMethods.navigateTo(context, AcceptanceLettersPage(userRole: widget.tweetCompany.role, companyId: widget.tweetCompany.originalAuthority?.linkedCompanies??[widget.tweetCompany.id],));
            },
          ),
          ?widget.tweetCompany.originalAuthority!=null? _buildDrawerItem(
            icon: Icons.people,
            text: 'Company List',
            onTap: () {
               if(_company == null)
                 {
                   Fluttertoast.showToast(msg: "Company not found , kindly logout and login ");
                   return;
                 }
              GeneralMethods.navigateTo(context, AuthorityCompaniesScreen(authorityId: _company?.originalAuthority?.id??"", authorityName: _company?.name??""));
            },
          ):null,
          _buildDrawerItem(
            icon: Icons.settings,
            text: 'Settings',
            onTap: () {
              GeneralMethods.navigateTo(context, CompanyMyProfilePage(company: company, isAuthority:widget.tweetCompany.originalAuthority != null,onProfileUpdated: (company)
              {

              }));
            },
          ),
          _buildDrawerItem(
            icon: Icons.verified_user,
            text: 'Claim Account',
            onTap: () {
              GeneralMethods.navigateTo(context, AccountClaimPage());
            },
          ),if(false)_buildDrawerItem(
            icon: Icons.rule,
            text: 'Set Rule',
            onTap: () {
              GeneralMethods.navigateTo(
                context,
                ChangeNotifierProvider(
                  create: (context) => AuthorityViewModel(
                    ruleService: MockRuleService(), // Create instance directly
                  ),
                  child: AuthorityRulesPage(authorityId: company.id),
                ),
              );
            },
          ),
          ?widget.tweetCompany.originalAuthority!=null? _buildDrawerItem(
            icon: Icons.rule,
            text: 'Set Rule',
            onTap: () {


              if(widget.tweetCompany.originalAuthority == null)
                {
                  Fluttertoast.showToast(msg: "Authority not found , kindly logout and login ");
                  return;
                }
              GeneralMethods.navigateTo(
                context,
                ChangeNotifierProvider(
                  create: (_) => StudentAcceptanceViewModel(),
                  child: StudentAcceptanceControlPage(
                    authorityId: widget.tweetCompany.id,
                    companies: widget.tweetCompany.originalAuthority?.linkedCompanies??[],
                  ),
                ),
              );
            },
          ):Container(),
          _buildDrawerItem(
            icon: Icons.help_outline,
            text: 'Help & Support',
            onTap: () {
              debugPrint("help and support ");
              GeneralMethods.navigateTo(context, CompanyHelpPage());
            },
          ),
          _buildDrawerItem(icon: Icons.nightlight, text: 'Theme', onTap: () {
            GeneralMethods.navigateTo(context,ThemeSettingsPage());
          }),
          if(company.isUnderAuthority)_buildDrawerItem(icon: Icons.admin_panel_settings_sharp, text: 'Authority', onTap: () async
          {
            if(company == null)
              {
                Fluttertoast.showToast(msg: "Authority not found , kindly logout and login or link your Account to authority");
                return;
              }
             Authority? authority = await ITCFirebaseLogic(GlobalIdService.firestoreId).getAuthority(company.authorityId??"");
              if(authority == null)
                {
                  Fluttertoast.showToast(msg: "INTERNAL ERROR: Authority not found");
                  return;
                }
            GeneralMethods.navigateTo(context,AuthorityPage(authority: authority, isCompanyLinked: company.isUnderAuthority,
            onChatPressed: ()
              {
                GeneralMethods.navigateTo(context, ChatDetailsPage(
                  receiverAvatarUrl: authority.logoURL??"",
                  receiverName: authority.name,
                  receiverId: authority.id,
                  receiverRole: "Authority",
                  receiverData: authority,
                ));
              },));
          }),
          widget.tweetCompany.originalAuthority != null?Container():
          _buildDrawerItem(
            icon: Icons.link,
            text: _getAuthorityMenuItemText(),
            onTap: () async {
              // Close drawer first
              Navigator.pop(context);

              // Use _company if available, otherwise use widget.tweetCompany
              final currentCompany = _company ?? widget.tweetCompany;

              // Small delay to ensure drawer is closed
              await Future.delayed(const Duration(milliseconds: 300));

              if (mounted) {
               GeneralMethods.navigateTo(context, CompanyAuthoritySpecificationPage(company: company, firebaseLogic: ITCFirebaseLogic(GlobalIdService.firestoreId??"")));
              }
            },
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

  // ============ NEW METHOD: Handle Authority Specification ============
  Future<void> _handleAuthoritySpecification(Company company) async {
    try {
      debugPrint('Opening authority specification dialog for: ${company.name}');

      // Check if dialog should be shown (optional, but good practice)
      final shouldShowDialog = await _authorityService.needsAuthoritySpecificationDialog(company.id);

      if (!mounted) return;

      // // Always allow manual access, but show appropriate message
      // if (!shouldShowDialog && company.isUnderAuthority) {
      //   // Company already has authority - show current status
      //   _showCurrentAuthorityStatus(company);
      //   return;
      // }

      // Show the dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => CompanyAuthoritySpecificationDialog(
          company: company,
          onSpecificationComplete: () {
            if (mounted) {
              // Refresh company data
              _loadCompany();

              // Show success message
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Authority specification updated successfully!'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          }, firebaseLogic: ITCFirebaseLogic(GlobalIdService.firestoreId),
        ),
      );
    } catch (e, stack) {
      debugPrint('Error showing authority dialog: $e');
      debugPrint('Stack trace: $stack');

      if (mounted) {
        // Show error dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Error'),
            content: Text('Failed to open authority dialog: ${e.toString()}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  // ============ HELPER: Get appropriate menu item text ============
  String _getAuthorityMenuItemText() {
    final company = _company ?? widget.tweetCompany;

    if (company.isUnderAuthority) {
      return 'Change Authority Link';
    } else if (company.authorityLinkStatus == 'PREVIOUSLY_LINKED') {
      return 'Specify Authority Relationship';
    } else if (company.authorityLinkStatus == 'STANDALONE') {
      return 'Link to Authority';
    } else {
      return 'Set Authority Relationship';
    }
  }

  // ============ HELPER: Show current authority status ============
  void _showCurrentAuthorityStatus(Company company) {
    String message;
    Color color;

    if (company.isUnderAuthority) {
      message = 'Currently linked to: ${company.authorityName ?? "Authority"}';
      color = Colors.blue;
    } else if (company.authorityLinkStatus == 'STANDALONE') {
      message = 'Company is set as standalone';
      color = Colors.green;
    } else if (company.authorityLinkStatus == 'PREVIOUSLY_LINKED') {
      message = 'Previously linked to authority - you can update your status';
      color = Colors.orange;
    } else {
      message = 'No authority relationship set';
      color = Colors.grey;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }


  void navigateToEditCompany(Company company) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CompanyEditPage(
          company: company,
          onSave: (updatedCompany) {
            // Update your local state
            setState(() {
              // Replace company in your list
            });
            Navigator.pop(context);
          },
          onCancel: () {
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  Widget _buildEmptyDrawer(ThemeData theme) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName:  Text('${widget.tweetCompany.originalAuthority == null? 'Company': 'Authority'} Portal'),
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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.scaffoldBackgroundColor,
            theme.cardColor,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ModernTabItem(
                icon: Icons.people,
                label: 'Community',
                isSelected: _currentIndex == 0,
                onTap: () => _onBottomNavTapped(0),
                gradient: const LinearGradient(
                  colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                scaleAnimation: CurvedAnimation(
                  parent: AnimationController(
                    duration: const Duration(milliseconds: 200),
                    vsync: this,
                  )..forward(),
                  curve: Curves.easeOutBack,
                ),
                onFetchCount: ()async
                {
                  return await Future.value(99);
                }, // No badge for community
              ),
              _ModernTabItem(
                icon: Icons.description_outlined,
                label: 'Applications',
                isSelected: _currentIndex == 1,
                onTap: () => _onBottomNavTapped(1),
                gradient: const LinearGradient(
                  colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                scaleAnimation: CurvedAnimation(
                  parent: AnimationController(
                    duration: const Duration(milliseconds: 200),
                    vsync: this,
                  )..forward(),
                  curve: Curves.easeOutBack,
                ),
                onFetchCount: _fetchPendingApplicationsCount, // Shows pending count
              ),
              _ModernTabItem(
                icon: Icons.list_alt_outlined,
                label: 'IT List',
                isSelected: _currentIndex == 2,
                onTap: () => _onBottomNavTapped(2),
                gradient: const LinearGradient(
                  colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                scaleAnimation: CurvedAnimation(
                  parent: AnimationController(
                    duration: const Duration(milliseconds: 200),
                    vsync: this,
                  )..forward(),
                  curve: Curves.easeOutBack,
                ),
                onFetchCount: _fetchActiveInternshipsCount, // Shows active internships
              ),
              _ModernTabItem(
                icon: Icons.message_outlined,
                label: 'Messages',
                isSelected: _currentIndex == 3,
                onTap: () => _onBottomNavTapped(3),
                gradient: const LinearGradient(
                  colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                scaleAnimation: CurvedAnimation(
                  parent: AnimationController(
                    duration: const Duration(milliseconds: 200),
                    vsync: this,
                  )..forward(),
                  curve: Curves.easeOutBack,
                ),
                onFetchCount: _fetchUnreadMessagesCount, // Shows unread messages
              ),
            ],
          ),
        ),
      ),
    );
  }


// 1. Get pending applications count
  Future<int> _fetchPendingApplicationsCount() async {
    try {
      final companyCloud = Company_Cloud(GlobalIdService.firestoreId);
      final companyId = _company?.id ?? widget.tweetCompany.id;

      final pendingCount = await companyCloud.getTotalNewApplications(
        companyId,
        isAuthority: widget.tweetCompany.originalAuthority != null,
        companyIds: widget.tweetCompany.originalAuthority?.linkedCompanies ?? [],
      );

      return pendingCount;
    } catch (e) {
      debugPrint('Error fetching pending applications count: $e');
      return 0;
    }
  }

  Future<int> _fetchActiveInternshipsCount() async {
    try {
      final companyCloud = Company_Cloud(GlobalIdService.firestoreId);
      final companyId = _company?.id ?? widget.tweetCompany.id;

      // Get internships for the company/authority
      final activeCount = await companyCloud.getPendingInternshipsCount(companyId);
      return activeCount;
    } catch (e) {
      debugPrint('Error fetching active internships count: $e');
      return 0;
    }
  }

// 3. Get unread messages count
  Future<int> _fetchUnreadMessagesCount() async {
    try {
      final currentUserId = GlobalIdService.firestoreId;
      if (currentUserId == null) return 0;

      final chatService = ChatService(currentUserId);
      final unreadCount = await chatService.getUnreadMessagesCountEfficient(currentUserId);
      return unreadCount;
    } catch (e) {
      debugPrint('Error fetching unread messages count: $e');
      return 0;
    }
  }

// 4. Alternative: Get total accepted applications count (if you want to show that instead)
  Future<int> _fetchAcceptedApplicationsCount() async {
    try {
      final companyCloud = Company_Cloud(GlobalIdService.firestoreId);
      final companyId = _company?.id ?? widget.tweetCompany.id;

      final acceptedCount = await companyCloud.getTotalAcceptedApplications(
        companyId,
        isAuthority: widget.tweetCompany.originalAuthority != null,
        companyIds: widget.tweetCompany.originalAuthority?.linkedCompanies ?? [],
      );

      return acceptedCount;
    } catch (e) {
      debugPrint('Error fetching accepted applications count: $e');
      return 0;
    }
  }

// 5. Get total completed internships count
  Future<int> _fetchCompletedInternshipsCount() async {
    try {
      final companyCloud = Company_Cloud(GlobalIdService.firestoreId);
      final companyId = _company?.id ?? widget.tweetCompany.id;

      final internships = await companyCloud.getCurrentCompanyInternshipsFuture(companyId);

      final completedCount = internships.where((internship) {
        final status = internship.status?.toLowerCase() ?? '';
        return status == 'completed' || status == 'closed';
      }).length;

      return completedCount;
    } catch (e) {
      debugPrint('Error fetching completed internships count: $e');
      return 0;
    }
  }

// 6. Get total applications count (all statuses)
  Future<int> _fetchTotalApplicationsCount() async {
    try {
      final companyCloud = Company_Cloud(GlobalIdService.firestoreId);
      final companyId = _company?.id ?? widget.tweetCompany.id;

      final totalCount = await companyCloud.getTotalApplications(companyId);

      return totalCount;
    } catch (e) {
      debugPrint('Error fetching total applications count: $e');
      return 0;
    }
  }

// 7. Get current/ongoing trainees count (using TraineeService)
  Future<int> _fetchCurrentTraineesCount() async {
    try {
      final currentUserId = GlobalIdService.firestoreId;
      if (currentUserId == null) return 0;

      final traineeService = TraineeService(currentUserId);
      final companyId = _company?.id ?? widget.tweetCompany.id;

      final currentTrainees = await traineeService.getCurrentTrainees(
        companyId: companyId,
        isAuthority: widget.tweetCompany.originalAuthority != null,
        companyIds: widget.tweetCompany.originalAuthority?.linkedCompanies ?? [],
      );

      return currentTrainees.length;
    } catch (e) {
      debugPrint('Error fetching current trainees count: $e');
      return 0;
    }
  }

}
class _AnimatedTitle extends StatefulWidget {
  const _AnimatedTitle();

  @override
  State<_AnimatedTitle> createState() => __AnimatedTitleState();
}

class __AnimatedTitleState extends State<_AnimatedTitle>
    with TickerProviderStateMixin {
  late Timer _timer;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  int _currentIndex = 0;

  final List<String> quotes = [
    "Bridge to Industry",
    "Learn. Connect. Grow",
    "Your IT Journey Starts Here",
    "Connect to Your Future",
    "Where Students Become Pros",
    "Building Tech Careers",
    "From Campus to Career",
    "Your IT Bridge to Success",
    "Code. Connect. Career.",
    "Tomorrow's Tech Leaders",
    "Internship Made Simple",
    "Connect, Learn, Excel",
    "Your Gateway to Industry",
    "Shape Your IT Future",
  ];

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Start with visible text
    _animationController.value = 1.0;

    // Change quote every 5 seconds with fade effect
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        // Fade out
        _animationController.reverse().then((_) {
          // Change text
          setState(() {
            _currentIndex = (_currentIndex + 1) % quotes.length;
          });
          // Fade in
          _animationController.forward();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Text(
        quotes[_currentIndex],
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _ModernTabItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final LinearGradient gradient;
  final Animation<double> scaleAnimation;
  final Future<int>? Function()? onFetchCount; // Optional async method to fetch count
  final VoidCallback? onAction; // Optional action to perform when tapped

  const _ModernTabItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.gradient,
    required this.scaleAnimation,
    this.onFetchCount,
    this.onAction,
  });

  @override
  State<_ModernTabItem> createState() => _ModernTabItemState();
}

class _ModernTabItemState extends State<_ModernTabItem> {
  int _badgeCount = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchBadgeCount();
  }

  @override
  void didUpdateWidget(_ModernTabItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-fetch when tab becomes selected or if the widget updates
    if (widget.isSelected != oldWidget.isSelected && widget.isSelected) {
      _fetchBadgeCount();
    }
  }

  Future<void> _fetchBadgeCount() async {
    if (widget.onFetchCount == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final count = await widget.onFetchCount!();
      if (mounted) {
        setState(() {
          _badgeCount = count ?? 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching badge count: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _handleTap() {
    // Execute custom action if provided
    if (widget.onAction != null) {
      widget.onAction!();
    }
    // Execute the original onTap
    widget.onTap();
    // Refresh badge count when tapped
    _fetchBadgeCount();
  }

  String _getBadgeText() {
    if (_badgeCount >= 100) {
      return '99+';
    }
    return _badgeCount.toString();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: widget.scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: widget.isSelected ? widget.scaleAnimation.value : 1.0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              decoration: BoxDecoration(
                gradient: widget.isSelected ? widget.gradient : null,
                color: widget.isSelected ? null : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                boxShadow: widget.isSelected
                    ? [
                  BoxShadow(
                    color: widget.gradient.colors.first.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
                    : null,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon with badge
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: widget.isSelected
                              ? Colors.white.withOpacity(0.2)
                              : (isDark ? Colors.grey[800] : Colors.grey[100]),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          widget.icon,
                          size: 20,
                          color: widget.isSelected
                              ? Colors.white
                              : (isDark ? Colors.grey[400] : Colors.grey[600]),
                        ),
                      ),
                      // Badge
                      if (_badgeCount > 0)
                        Positioned(
                          top: -4,
                          right: -4,
                          child: _buildBadge(),
                        ),
                      // Loading indicator
                      if (_isLoading)
                        Positioned(
                          top: -4,
                          right: -4,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: const BoxDecoration(
                              color: Colors.orange,
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: SizedBox(
                                width: 8,
                                height: 8,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight:
                      widget.isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: widget.isSelected
                          ? Colors.white
                          : (isDark ? Colors.grey[400] : Colors.grey[600]),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBadge() {
    final badgeText = _getBadgeText();
    // Adjust padding based on text length
    final isThreeDigits = badgeText == '99+';

    return Container(
      padding: EdgeInsets.all(isThreeDigits ? 2 : 3),
      decoration: const BoxDecoration(
        color: Colors.red,
        shape: BoxShape.circle,
      ),
      constraints: BoxConstraints(
        minWidth: isThreeDigits ? 20 : 16,
        minHeight: isThreeDigits ? 20 : 16,
      ),
      child: Center(
        child: Text(
          badgeText,
          style: TextStyle(
            color: Colors.white,
            fontSize: isThreeDigits ? 7 : 8,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}


class _AnimatedNotificationBell extends StatefulWidget {
  @override
  _AnimatedNotificationBellState createState() =>
      _AnimatedNotificationBellState();
}

class _AnimatedNotificationBellState extends State<_AnimatedNotificationBell>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _pulseController; // For continuous pulse
  int _notificationCount = 3;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();

    // Controller for tap animation
    _controller = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );

    // Controller for continuous attention-seeking animation
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true); // Loops continuously

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _isAnimating = false;
        });
      }
    });
  }

  void _startDancing() {
    if (_isAnimating) return;
    setState(() {
      _isAnimating = true;
    });
    _controller.reset();
    _controller.forward();
  }

  void _handleNotificationTap() async {
    _startDancing();
    String id = GlobalIdService.firestoreId??"";
    await Future.delayed(const Duration(milliseconds: 150));
    if (mounted) {
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              CompanyNotificationsPage(companyId: id),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeInOut;
            var tween =
            Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            var offsetAnimation = animation.drive(tween);
            return SlideTransition(position: offsetAnimation, child: child);
          },
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.themeMode == ThemeMode.dark;

    return GestureDetector(
      onTap: _handleNotificationTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Continuous animation + tap animation combined
          AnimatedBuilder(
            animation: Listenable.merge([_controller, _pulseController]),
            builder: (context, child) {
              // Get values from both animations
              final tapProgress = _controller.value;
              final pulseProgress = _pulseController.value;

              // Combine animations: tap animation overrides pulse when active
              final isTapping = _controller.isAnimating;

              double angle;
              double scale;

              if (isTapping) {
                // Extreme dancing - like a real bell ringing hard
                angle = sin(tapProgress * 20) *
                    (1 - tapProgress) *
                    1.2; // Much bigger rotation
                scale = 1.0 +
                    (1 - tapProgress) *
                        0.4 *
                        sin(tapProgress * 15).abs(); // Bigger bounce
              } else {
                // Continuous attention-grabbing dance
                angle =
                    sin(pulseProgress * 6 * 3.14159) * 0.25; // Bigger wobble
                scale = 1.0 +
                    sin(pulseProgress * 6 * 3.14159).abs() *
                        0.2; // Bigger pulse
              }

              return Transform.rotate(
                angle: angle,
                child: Transform.scale(
                  scale: scale.clamp(0.9, 1.1),
                  child: IconButton(
                    icon: Icon(
                      Icons.notifications_none_outlined,
                      color: isDark ? Colors.white : Colors.blueGrey[800],
                    ),
                    onPressed: _handleNotificationTap,
                  ),
                ),
              );
            },
          ),
          // Pulsing ring effect for attention
          if (_notificationCount > 0)
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final pulseValue = _pulseController.value;
                final ringScale = 1 + pulseValue * 0.3;
                final ringOpacity = (1 - pulseValue) * 0.5;

                return Positioned(
                  top: 8,
                  right: 8,
                  child: IgnorePointer(
                    child: Container(
                      width: 18,
                      height: 18,
                      child: Transform.scale(
                        scale: ringScale,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.red.withOpacity(ringOpacity),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          // Badge
          Positioned(
            top: 8,
            right: 8,
            child: _notificationCount > 0
                ? TweenAnimationBuilder(
              tween: Tween<double>(begin: 0.5, end: 1),
              duration: const Duration(milliseconds: 300),
              builder: (context, double scale, child) {
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      _notificationCount > 99
                          ? '99+'
                          : '$_notificationCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              },
            )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
