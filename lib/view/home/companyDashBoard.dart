import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';
import 'package:itc_institute_admin/generalmethods/GeneralMethods.dart';
import 'package:itc_institute_admin/itc_logic/firebase/ActionLogger.dart';
import 'package:itc_institute_admin/itc_logic/firebase/activeStudentCloud.dart';
import 'package:itc_institute_admin/itc_logic/firebase/company_cloud.dart';
import 'package:itc_institute_admin/itc_logic/firebase/general_cloud.dart';
import 'package:itc_institute_admin/model/authorityCompanyMapper.dart';
import 'package:itc_institute_admin/view/home/industrailTraining/newIndustrialTraining.dart';

import '../../model/RecentActions.dart';
import '../../model/authority.dart';
import '../../model/company.dart';
import '../../model/student.dart';
import '../recentActions/recentActionsList.dart';

class Companydashboard extends StatefulWidget {
    final bool isAuthority;
  const Companydashboard({super.key, required this.isAuthority});

  @override
  State<Companydashboard> createState() => _CompanydashboardState();
}

class _CompanydashboardState extends State<Companydashboard>
    with AutomaticKeepAliveClientMixin {
  Company? _company;
  bool _isLoading = true;
  String _error = '';
  int _selectedTab = 0; // 0: Applications, 1: Trainings, 2: Supervisors, 3: Accepted
  late List<Application> studentApplications;
  int newApplicationCounts = 0;

  late int activeApplicationsCounts = 0;
  late int supervisorCount = 0;
  late int totalCompany = 0;
  late int acceptedApplicationCount = 0;
  final Company_Cloud company_cloud = new Company_Cloud();
  final ActiveTrainingService activeTrainingService = ActiveTrainingService();

  final TextEditingController _searchController = TextEditingController();

  final ActionLogger _actionLogger = ActionLogger();
  // Add these for refresh functionality
  bool _isRefreshing = false;
  bool _isDataLoaded = false;
  DateTime? _lastRefreshTime;

  @override
  void initState() {
    super.initState();
    debugPrint(" isAuthority ${widget.isAuthority}");
    if (!_isDataLoaded) {
      _loadCompanyData();
    }
  }

  Future<void> refreshData() async {
    // Prevent multiple simultaneous refreshes
    if (_isRefreshing) return;

    // Debounce: Don't refresh more than once every 3 seconds
    final now = DateTime.now();
    if (_lastRefreshTime != null &&
        now.difference(_lastRefreshTime!) < Duration(seconds: 3)) {
      return;
    }

    setState(() {
      _isRefreshing = true;
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('No user is currently logged in.');
      }

      String companyId = currentUser.uid;
      Authority? authority = await ITCFirebaseLogic().getAuthority(companyId);

      // Load all data in parallel for better performance
      final results = await Future.wait([
        ITCFirebaseLogic().getCompany(companyId),
        company_cloud.getTotalNewApplications(companyId,isAuthority: widget.isAuthority,companyIds: authority == null?[]:authority.linkedCompanies),
        company_cloud.getTotalAcceptedApplications(companyId,isAuthority: widget.isAuthority, companyIds:authority == null?[]:authority.linkedCompanies),
        activeTrainingService.getActiveTraineesCount(companyId,isAuthority: widget.isAuthority,companyIds: authority?.linkedCompanies?? []),
      ]);

      _company = results[0] as Company?;
      if(_company == null)
      {

        if(authority != null)
        {
          _company = AuthorityCompanyMapper.createCompanyFromAuthority(
              authority: authority);
        }
      }

      int totalApplication = await company_cloud.getTotalAcceptedApplications(
          companyId,
          isAuthority: widget.isAuthority,
          companyIds: _company?.originalAuthority?.linkedCompanies??[]
      );

      setState(() {

        newApplicationCounts = results[2] as int;
        acceptedApplicationCount = results[3] as int == 0? totalApplication:results[3] as int;

          activeApplicationsCounts = 0;

        supervisorCount = 0;
        _isRefreshing = false;
        _error = '';
        _isDataLoaded = true;
        _lastRefreshTime = DateTime.now();
      });

      // Show success feedback
      _showRefreshSuccess();
    } catch (e,s) {
      debugPrint("error is $e");
      debugPrintStack(stackTrace: s);
      setState(() {
        _error = 'Failed to refresh: $e';
        _isRefreshing = false;
      });

      // Show error feedback
      _showRefreshError(e);
    }
  }

  void _showRefreshSuccess() {
    // Optional: haptic feedback
    // HapticFeedback.lightImpact();

    // Show a subtle success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text('Dashboard refreshed'),
          ],
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(16),
      ),
    );
  }

  void _showRefreshError(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                error.toString().contains('Exception')
                    ? 'Refresh failed. Please check your connection.'
                    : 'Refresh failed: ${error.toString().length > 50 ? error.toString().substring(0, 50) + '...' : error}',
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: refreshData,
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;

  Future<void> _loadCompanyData() async {
    // Don't reload if already loading and data is loaded
    if (_isLoading && _isDataLoaded) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('No user is currently logged in.');
      }
      String companyId = currentUser.uid;
      Company? company;
       company = await ITCFirebaseLogic().getCompany(companyId);
       if(company == null)
         {
           Authority? authority = await ITCFirebaseLogic().getAuthority(companyId);
           if(authority != null) {
             company = AuthorityCompanyMapper.createCompanyFromAuthority(
                 authority: authority);
           }
         }
      int newApps = await company_cloud.getTotalNewApplications(companyId, isAuthority: widget.isAuthority,companyIds: company?.originalAuthority?.linkedCompanies??[]);
      int acceptedApps = await company_cloud.getTotalAcceptedApplications(
        companyId,
        isAuthority: widget.isAuthority,
        companyIds: company?.originalAuthority?.linkedCompanies??[]
      );
      int currentStudents = await activeTrainingService.getActiveTraineesCount(
        companyId,
        isAuthority: widget.isAuthority,
          companyIds: company?.originalAuthority?.linkedCompanies??[]
      );

      totalCompany = 1;

      debugPrint("currentStudents count $currentStudents");
      debugPrint("acceptedApps count $acceptedApps");
      debugPrint("new applications $newApps");

      setState(() {
        _company = company;
        newApplicationCounts = newApps;
        activeApplicationsCounts = currentStudents;
        acceptedApplicationCount = acceptedApps;
        supervisorCount = 0;
        _isLoading = false;
        _error = '';
        _isDataLoaded = true; // Mark as loaded
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load company data: $e';
        _isLoading = false;
        _isDataLoaded = false; // Allow retry
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return _buildLoading();
    }

    if (_error.isNotEmpty) {
      return _buildError();
    }

    if (_company == null) {
      return _buildNoCompany();
    }

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF101622)
          : const Color(0xFFf6f6f8),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: refreshData,
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height,
              ),
              child: Column(
                children: [
                  // Top App Bar
                  _buildTopAppBar(context),

                  // Announcement Banner
                  _buildAnnouncementBanner(),

                  // Stats Cards
                  _buildStatsCards(),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Align(
                        alignment: Alignment.topLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(
                            left: 13.0,
                            top: 8,
                            bottom: 8,
                          ),
                          child: Text(
                            "Recent Actions ",
                            style: TextStyle(fontSize: 20),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(onPressed: (){
                          GeneralMethods.navigateTo(context, RecentActionsFullPage(companyId: _company?.id??"",companyName: _company?.name??"",));
                        }, child: Text("See All",style: TextStyle(color: Colors.blue),)),
                      )
                    ],
                  ),
                  // List Content
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.6,
                    child: _buildListContent(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: GeneralMethods.getUniqueHeroTag(),
        onPressed: () {
          GeneralMethods.navigateTo(context, CreateIndustrialTrainingPage(isAuthority: widget.isAuthority));
        },
        backgroundColor: const Color(0xFF135bec),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildTopAppBar(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      color: isDark ? const Color(0xFF101622) : const Color(0xFFf6f6f8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${widget.isAuthority? 'Authority':'Company'} Dashboard',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementBanner() {
    if (_company == null) return SizedBox.shrink();
    return _CompanyAnnouncementBanner(company: _company!);
  }

  Widget _buildStatsCards() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _buildStatCard(
            title: 'New Applications',
            value: newApplicationCounts.toString()??"0",
          ),
          _buildStatCard(
            title: 'Active Trainings',
            value: activeApplicationsCounts.toString(),
          ),
          widget.isAuthority?
          _buildStatCard(
            title: 'Companies',
            value: _company?.originalAuthority?.linkedCompanies.length.toString()??'0',
          ):_buildStatCard(
            title: 'Supervisors',
            value: supervisorCount.toString(),
          ),
          _buildStatCard(
            title: 'Accepted',
            value: acceptedApplicationCount.toString(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({required String title, required String value}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: const BoxConstraints(minWidth: 158),
      child: Card(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Icon(
                Icons.search,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: _getSearchHint(),
                    hintStyle: TextStyle(
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade500,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getSearchHint() {
    switch (_selectedTab) {
      case 0:
        return 'Search applications...';
      case 1:
        return 'Search trainings...';
      case 2:
        return 'Search supervisors...';
      case 3:
        return 'Search accepted...';
      default:
        return 'Search...';
    }
  }

  Widget _buildListContent() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final cardColor = isDark ? Colors.white.withOpacity(0.05) : Colors.white;
    final borderColor = isDark ? Colors.grey.shade800 : Colors.grey.shade200;

    return StreamBuilder<List<RecentAction>>(
      stream: _actionLogger.streamCompanyActions(_company!.id,isAuthority: widget.isAuthority),
      builder: (context, actionStream) {
        if (actionStream.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }

        if (actionStream.hasError) {
          return _buildErrorWidget(
            context: context,
            error: actionStream.error,
            onRetry: () {
              setState(() {
                // Trigger rebuild
              });
            },
          );
        }

        if (!actionStream.hasData || actionStream.data!.isEmpty) {
          return _buildEmptyState(context: context);
        }

        final recentActions = actionStream.data!;

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {});
          },
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: recentActions.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final action = recentActions[index];
              return _buildActionCard(
                action,
                isDark,
                textColor,
                subTextColor,
                cardColor,
                borderColor,
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildActionCard(
      RecentAction action,
      bool isDark,
      Color textColor,
      Color subTextColor,
      Color cardColor,
      Color borderColor,
      ) {
    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      elevation: isDark ? 0 : 2,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: borderColor, width: 1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with action type and time
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _getActionColor(action.actionType).withOpacity(0.1),
                border: Border(
                  bottom: BorderSide(color: borderColor, width: 1),
                ),
              ),
              child: Row(
                children: [
                  // Action icon
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _getActionColor(action.actionType),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      action.actionIcon,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Action type and entity
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _capitalize(action.actionType),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _getActionColor(action.actionType),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              action.entityIcon,
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _capitalize(action.entityType),
                              style: TextStyle(
                                fontSize: 12,
                                color: subTextColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Timestamp
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        action.timeAgo,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: subTextColor,
                        ),
                      ),
                      Text(
                        action.formattedTime,
                        style: TextStyle(
                          fontSize: 11,
                          color: subTextColor.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Main content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Description
                  Text(
                    action.description,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),

                  // Entity details
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.black.withOpacity(0.3)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Entity',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: subTextColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                action.entityName,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: textColor,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Container(height: 30, width: 1, color: borderColor),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ID',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: subTextColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                action.entityId.length > 20
                                    ? '${action.entityId.substring(0, 20)}...'
                                    : action.entityId,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: textColor.withOpacity(0.8),
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // User info
                  Row(
                    children: [
                      // User avatar/icon
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _getUserRoleColor(
                            action.userRole,
                          ).withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            _getUserAvatarText(action.userName),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _getUserRoleColor(action.userRole),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // User details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              action.userName,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getUserRoleColor(
                                      action.userRole,
                                    ).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: _getUserRoleColor(
                                        action.userRole,
                                      ).withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    action.userRole.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: _getUserRoleColor(action.userRole),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    action.userEmail,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: subTextColor,
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
                    ],
                  ),

                  // Changes section (if any)
                  if (action.hasChanges) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.blue.withOpacity(0.1)
                            : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.change_circle_outlined,
                                size: 14,
                                color: Colors.blue,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Changes Made',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ..._buildChangesList(action.changes!, textColor),
                        ],
                      ),
                    ),
                  ],

                  // Metadata section (if any)
                  if (action.metadata != null &&
                      action.metadata!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        _showMetadataDialog(action);
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 14,
                            color: subTextColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'View Details',
                            style: TextStyle(fontSize: 12, color: subTextColor),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildChangesList(
      Map<String, dynamic> changes,
      Color textColor,
      ) {
    return changes.entries.map((entry) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(top: 6),
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 12,
                    color: textColor.withOpacity(0.8),
                  ),
                  children: [
                    TextSpan(
                      text: '${_capitalize(entry.key)}: ',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    TextSpan(text: entry.value.toString()),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  void _showMetadataDialog(RecentAction action) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Action Details'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow('Action Type', _capitalize(action.actionType)),
                _buildDetailRow('Entity Type', _capitalize(action.entityType)),
                _buildDetailRow('Entity ID', action.entityId),
                _buildDetailRow('Entity Name', action.entityName),
                _buildDetailRow('User', action.userName),
                _buildDetailRow('User Role', action.userRole),
                _buildDetailRow('User Email', action.userEmail),
                _buildDetailRow('Description', action.description),
                _buildDetailRow('Date', action.formattedDate),
                _buildDetailRow('Time', action.formattedTime),
                if (action.ipAddress.isNotEmpty)
                  _buildDetailRow('IP Address', action.ipAddress),
                if (action.userAgent.isNotEmpty)
                  _buildDetailRow('User Agent', action.userAgent),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Color _getActionColor(String actionType) {
    switch (actionType) {
      case 'created':
        return Colors.green;
      case 'updated':
        return Colors.blue;
      case 'deleted':
        return Colors.red;
      case 'approved':
        return Colors.green.shade700;
      case 'rejected':
        return Colors.orange;
      case 'viewed':
        return Colors.purple;
      case 'uploaded':
        return Colors.teal;
      case 'downloaded':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  Color _getUserRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Colors.red;
      case 'company':
        return Colors.blue;
      case 'student':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getUserAvatarText(String userName) {
    if (userName.isEmpty) return '?';
    final parts = userName.split(' ');
    if (parts.length > 1) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return userName[0].toUpperCase();
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Loading recent activities...',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({required BuildContext context}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No recent activities',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Activities will appear here as they happen',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {});
            },
            icon: Icon(Icons.refresh),
            label: Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget({
    required BuildContext context,
    required Object? error,
    VoidCallback? onRetry,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
          const SizedBox(height: 16),
          Text(
            'Error loading activities',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.red.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error?.toString() ?? 'Unknown error occurred',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          if (onRetry != null)
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: Icon(Icons.refresh),
              label: Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
        ],
      ),
    );
  }

  Color _getStatusColor(ApplicationStatus status) {
    switch (status) {
      case ApplicationStatus.accepted:
        return const Color(0xFF34C759); // Green
      case ApplicationStatus.pending:
        return const Color(0xFFFFCC00); // Yellow
      case ApplicationStatus.rejected:
        return const Color(0xFFFF3B30); // Red
    }
  }

  Widget _buildLoading() {
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF101622)
          : const Color(0xFFf6f6f8),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Loading Company Dashboard...',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF101622)
          : const Color(0xFFf6f6f8),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: const Color(0xFFFF3B30),
              ),
              const SizedBox(height: 16),
              Text(
                'An Error Occurred',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _error,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadCompanyData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF135bec),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoCompany() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF101622)
          : const Color(0xFFf6f6f8),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.business_center_outlined,
                size: 80,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
              ),
              const SizedBox(height: 20),
              Text(
                'Company Profile Required',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Please complete your company profile setup to access the dashboard.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () {
                  // Navigate to registration
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF135bec),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 15,
                  ),
                ),
                child: const Text('Set Up Profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showProfileDialog() {
    final company = _company;
    if (company == null) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: isDark ? const Color(0xFF1a2232) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: CircleAvatar(
                      radius: 40,
                      backgroundImage: company.logoURL.isNotEmpty
                          ? NetworkImage(company.logoURL)
                          : null,
                      backgroundColor: const Color(0xFF135bec).withOpacity(0.1),
                      child: company.logoURL.isEmpty
                          ? Icon(
                        Icons.business,
                        size: 40,
                        color: const Color(0xFF135bec),
                      )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildProfileInfoRow('Company Name:', company.name),
                  _buildProfileInfoRow('Industry:', company.industry),
                  _buildProfileInfoRow('Email:', company.email),
                  _buildProfileInfoRow('Phone:', company.phoneNumber),
                  _buildProfileInfoRow('Address:', company.address),
                  _buildProfileInfoRow(
                    'Registration:',
                    company.registrationNumber,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          // Navigate to edit profile
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF135bec),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Edit Profile'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileInfoRow(String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : 'Not provided',
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      // Navigate to login screen
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error logging out: $e'),
          backgroundColor: const Color(0xFFFF3B30),
        ),
      );
    }
  }
}

// Helper classes
enum ApplicationStatus { accepted, pending, rejected }

class Application {
  final String name;
  final String university;
  final ApplicationStatus status;
  final String avatarUrl;

  Application({
    required this.name,
    required this.university,
    required this.status,
    required this.avatarUrl,
  });
}

class _CompanyAnnouncementBanner extends StatefulWidget {
  final Company company;
  const _CompanyAnnouncementBanner({required this.company});

  @override
  State<_CompanyAnnouncementBanner> createState() =>
      _CompanyAnnouncementBannerState();
}

class _CompanyAnnouncementBannerState
    extends State<_CompanyAnnouncementBanner> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_dismissed) return SizedBox.shrink();
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('announcements')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _announcementBanner(
            title: 'Loading...',
            body: 'Checking for admin announcements.',
            createdAt: null,
            isDark: isDark,
            onClose: () async {
              setState(() => _dismissed = true);
            },
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _announcementBanner(
            title: 'No admin announcement yet',
            body: 'Stay tuned for updates from your admin.',
            createdAt: null,
            isDark: isDark,
            onClose: () async {
              setState(() => _dismissed = true);
            },
          );
        }
        final doc = snapshot.data!.docs.first;
        final announcementId = doc.id;
        final data = doc.data();
        final title = data['title'] ?? '';
        final body = data['body'] ?? '';
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        if (title.isEmpty && body.isEmpty) {
          return _announcementBanner(
            title: 'No admin announcement yet',
            body: 'Stay tuned for updates from your admin.',
            createdAt: null,
            isDark: isDark,
            onClose: () async {
              setState(() => _dismissed = true);
            },
          );
        }
        return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: FirebaseFirestore.instance
              .collection('companies')
              .doc(widget.company.id)
              .collection('seen_announcements')
              .doc(announcementId)
              .get(),
          builder: (context, seenSnapshot) {
            return _announcementBanner(
              title: title,
              body: body,
              createdAt: createdAt,
              isDark: isDark,
              onClose: () async {
                setState(() => _dismissed = true);
              },
            );
          },
        );
      },
    );
  }
}

Widget _announcementBanner({
  required String title,
  required String body,
  DateTime? createdAt,
  required bool isDark,
  required Future<void> Function() onClose,
}) {
  return Builder(
    builder: (context) => GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) {
            return Dialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              child: Container(
                constraints: BoxConstraints(maxHeight: 400, minWidth: 300),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.campaign,
                            color: Color(0xFF2196F3), size: 28),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Color(0xFF1565C0),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Text(
                          body,
                          style: TextStyle(
                            fontSize: 15,
                            color: Color(0xFF1976D2),
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                    if (createdAt != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: Row(
                          children: [
                            Icon(Icons.access_time,
                                size: 14, color: Color(0xFF64B5F6)),
                            const SizedBox(width: 4),
                            Text(
                              'Posted: ' +
                                  DateFormat('yMMMd H:mm').format(createdAt),
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64B5F6),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text('Close',
                            style: TextStyle(
                                color: Color(0xFF2196F3),
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2196F3), width: 1),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2196F3).withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.campaign, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title.isNotEmpty)
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF1565C0),
                      ),
                    ),
                  if (body.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF1976D2),
                          height: 1.4,
                        ),
                      ),
                    ),
                  if (createdAt != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Row(
                        children: [
                          Icon(Icons.access_time,
                              size: 12, color: const Color(0xFF64B5F6)),
                          const SizedBox(width: 4),
                          Text(
                            'Posted: ' +
                                DateFormat('yMMMd H:mm').format(createdAt),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64B5F6),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF2196F3).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                icon:
                Icon(Icons.close, color: const Color(0xFF2196F3), size: 18),
                onPressed: () async {
                  await onClose();
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> signOut() async {
  final GoogleSignIn googleSignIn = GoogleSignIn();

  // Sign out from Google
  try {
    await googleSignIn.signOut();
  } catch (e) {
    print("Google sign out error: $e");
  }

  // Sign out from Firebase
  await FirebaseAuth.instance.signOut();
}