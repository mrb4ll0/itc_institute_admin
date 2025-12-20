import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:itc_institute_admin/generalmethods/GeneralMethods.dart';
import 'package:itc_institute_admin/itc_logic/firebase/ActionLogger.dart';
import 'package:itc_institute_admin/itc_logic/firebase/company_cloud.dart';
import 'package:itc_institute_admin/itc_logic/firebase/general_cloud.dart';
import 'package:itc_institute_admin/itc_logic/notification/fireStoreNotification.dart';
import 'package:itc_institute_admin/itc_logic/notification/notitification_service.dart';
import 'package:itc_institute_admin/model/studentApplication.dart';
import 'package:itc_institute_admin/view/home/studentApplications/studentApplicationDetail.dart';

import '../../../extensions/extensions.dart';
import '../../../model/student.dart';

class SpecificITStudentApplicationsPage extends StatefulWidget {
  final String itId;
  const SpecificITStudentApplicationsPage({super.key, required this.itId});

  @override
  State<SpecificITStudentApplicationsPage> createState() =>
      _SpecificITStudentApplicationsPageState();
}

class _SpecificITStudentApplicationsPageState
    extends State<SpecificITStudentApplicationsPage>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  final Company_Cloud company_cloud = Company_Cloud();
  final NotificationService notificationService = NotificationService();
  ActionLogger actionLogger = ActionLogger();
  final ITCFirebaseLogic _itcFirebaseLogic = ITCFirebaseLogic();
  int applicationCount = 0;
  final Company_Cloud companyCloud = Company_Cloud();
  bool _isRefreshing = false;
  bool _isDataLoaded = false;
  DateTime? _lastRefreshTime;
  Stream<List<StudentApplication>?>? _cachedApplications;
  List<StudentApplication> _allApplications = [];
  List<StudentApplication> _filteredApplications = [];
  String _searchQuery = '';
  ApplicationStatus? _selectedStatus;
  String? _selectedPeriod;
  String? _selectedSupervisor;
  final FireStoreNotification fireStoreNotification = FireStoreNotification();

  final GlobalKey _statusFilterKey = GlobalKey();
  final GlobalKey _periodFilterKey = GlobalKey();
  final GlobalKey _supervisorFilterKey = GlobalKey();

  // Add these after your existing state variables
  bool _showFilters = false;
  final List<String> _statusOptions = [
    'All',
    'Pending',
    'Accepted',
    'Rejected',
  ];
  final List<String> _periodOptions = [
    'All',
    'Last 7 days',
    'Last 30 days',
    'Last 90 days',
  ];
  List<String> _supervisorOptions = ['All'];

  @override
  bool get wantKeepAlive => true;

  @override
  initState() {
    super.initState();
    _loadSupervisors();
    _loadInitialData();
    setState(() {});
  }

  Future<void> _loadInitialData() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      String companyId = currentUser.uid;

      // Get initial data without showing loading indicator
      final applicationsStream = company_cloud
          .getBasicApplicationsForInternshipStream(companyId, widget.itId);

      final applications = await applicationsStream.first;

      if (mounted) {
        setState(() {
          _allApplications = applications ?? [];
          _cachedApplications = applicationsStream;
          _isDataLoaded = true;
          _applyFilters(); // Apply any existing filters
        });
      }
    } catch (e) {
      debugPrint("Error loading initial data: $e");
    }
  }

  Future<void> _loadSupervisors() async {
    try {
      // Load unique supervisors from applications
      // You'll need to implement this based on your data structure
      // For now, using a placeholder
      _supervisorOptions = [
        'All',
        'Supervisor A',
        'Supervisor B',
        'Supervisor C',
      ];
    } catch (e) {
      debugPrint("Error loading supervisors: $e");
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

      // Get the stream first
      final applicationsStream = company_cloud
          .studentInternshipApplicationsForCompanyStream(companyId);

      // Extract the data from the stream ONCE to populate _allApplications
      final applications = await applicationsStream.first;

      setState(() {
        _allApplications = applications ?? [];
        _cachedApplications =
            applicationsStream; // Keep the stream for real-time updates
        _applyFilters(); // Apply filters to the newly loaded data
        _isRefreshing = false;
        _isDataLoaded = true;
        _lastRefreshTime = DateTime.now();
      });

      // Show success feedback
      _showRefreshSuccess();
    } catch (e) {
      setState(() {
        _isRefreshing = false;
      });

      // Show error feedback
      _showRefreshError(e);
    }
  }

  void _applyFilters() {
    List<StudentApplication> filtered = List.from(_allApplications);

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((app) {
        final studentName = app.student.fullName.toLowerCase();
        final institution = app.student.institution.toLowerCase();
        final course = app.student.courseOfStudy.toLowerCase();
        final internshipTitle = app.internship?.title.toLowerCase() ?? '';
        final query = _searchQuery.toLowerCase();

        return studentName.contains(query) ||
            institution.contains(query) ||
            course.contains(query) ||
            internshipTitle.contains(query);
      }).toList();
    }

    // Apply status filter
    if (_selectedStatus != null) {
      filtered = filtered.where((app) {
        return app.applicationStatus.toLowerCase() ==
            _selectedStatus.toString().split('.').last.toLowerCase();
      }).toList();
    }

    // Apply period filter
    if (_selectedPeriod != null && _selectedPeriod != 'All') {
      final now = DateTime.now();
      DateTime cutoffDate;

      switch (_selectedPeriod) {
        case 'Last 7 days':
          cutoffDate = now.subtract(Duration(days: 7));
          break;
        case 'Last 30 days':
          cutoffDate = now.subtract(Duration(days: 30));
          break;
        case 'Last 90 days':
          cutoffDate = now.subtract(Duration(days: 90));
          break;
        default:
          cutoffDate = now.subtract(Duration(days: 365)); // Default to 1 year
      }

      filtered = filtered.where((app) {
        return app.applicationDate.isAfter(cutoffDate);
      }).toList();
    }

    // Apply supervisor filter (you'll need to adjust this based on your data structure)
    if (_selectedSupervisor != null && _selectedSupervisor != 'All') {
      filtered = filtered.where((app) {
        // Replace with actual supervisor field in your application model
        // For now, using a placeholder
        return true; // app.supervisor == _selectedSupervisor;
      }).toList();
    }

    setState(() {
      _filteredApplications = filtered;
      applicationCount = filtered.length;
    });
  }

  void _showRefreshSuccess() {
    // Show a subtle success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text('Applications refreshed'),
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
  Widget build(BuildContext context) {
    super.build(context);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: isDark
          ? colorScheme.surfaceContainerHighest
          : colorScheme.surfaceContainerLowest,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: refreshData,
          child: Column(
            children: [
              // Top App Bar
              _buildTopAppBar(context),

              // Search Section
              _buildSearchSection(context),

              // Filter Chips
              _buildFilterChips(context),

              // Applications List
              Expanded(child: _buildApplicationsList(context)),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: GeneralMethods.getUniqueHeroTag(),
        onPressed: () {
          // Add new application
        },
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTopAppBar(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    return Container(
      height: 56,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? colorScheme.outline.withOpacity(0.1)
                : colorScheme.outline.withOpacity(0.08),
          ),
        ),
        color: isDark
            ? colorScheme.surfaceContainerHighest.withOpacity(0.8)
            : colorScheme.surfaceContainerLowest.withOpacity(0.8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            const SizedBox(width: 10),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: Icon(Icons.arrow_back),
                    ),
                    Text(
                      'Applications',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Row(
              children: [
                if (_hasActiveFilters())
                  IconButton(
                    icon: Icon(Icons.filter_alt, color: colorScheme.primary),
                    onPressed: () {
                      setState(() {
                        _showFilters = !_showFilters;
                      });
                    },
                    tooltip: 'Toggle filters',
                  ),
                Text(applicationCount.toString()),
                IconButton(
                  icon: Icon(Icons.more_horiz, color: colorScheme.primary),
                  onPressed: () {
                    _showMoreOptions(context);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showMoreOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.refresh),
                title: Text('Refresh'),
                onTap: () {
                  Navigator.pop(context);
                  refreshData();
                },
              ),
              ListTile(
                leading: Icon(Icons.sort),
                title: Text('Sort by'),
                onTap: () {
                  Navigator.pop(context);
                  //_showSortOptions(context);
                },
              ),
              if (_hasActiveFilters())
                ListTile(
                  leading: Icon(Icons.clear_all, color: Colors.red),
                  title: Text(
                    'Clear all filters',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _searchQuery = '';
                      _selectedStatus = null;
                      _selectedPeriod = null;
                      _selectedSupervisor = null;
                      _searchController.clear();
                      _applyFilters();
                    });
                  },
                ),
              ListTile(
                leading: Icon(Icons.close),
                title: Text('Cancel'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchSection(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: isDark
              ? colorScheme.surfaceContainerHigh
              : colorScheme.surfaceContainer,
        ),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Icon(
                Icons.search,
                size: 20,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by name, university, or course...',
                    hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: TextStyle(color: colorScheme.onSurface),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                      _applyFilters();
                    });
                  },
                ),
              ),
            ),
            if (_searchQuery.isNotEmpty)
              IconButton(
                icon: Icon(Icons.clear, size: 18),
                onPressed: () {
                  setState(() {
                    _searchController.clear();
                    _searchQuery = '';
                    _applyFilters();
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Main Filter Button (opens dialog)
            GestureDetector(
              onTap: () {
                _showFilterDialog(context);
              },
              child: Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: _hasActiveFilters()
                      ? colorScheme.primary.withOpacity(0.1)
                      : colorScheme.surfaceContainer,
                  border: Border.all(
                    color: _hasActiveFilters()
                        ? colorScheme.primary
                        : colorScheme.outline.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.filter_list,
                      size: 18,
                      color: _hasActiveFilters()
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Filters',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: _hasActiveFilters()
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (_hasActiveFilters())
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Status Filter Chip with GlobalKey
            _buildFilterChipWithMenu(
              context,
              key: _statusFilterKey,
              icon: Icons.arrow_drop_down,
              label: 'Status',
              getCurrentValue: () =>
                  _selectedStatus?.toString().split('.').last ?? 'All',
              options: _statusOptions,
              onSelected: (value) {
                setState(() {
                  _selectedStatus = value == 'All'
                      ? null
                      : _stringToApplicationStatus(value);
                  _applyFilters();
                });
              },
            ),
            const SizedBox(width: 8),

            // Period Filter Chip with GlobalKey
            _buildFilterChipWithMenu(
              context,
              key: _periodFilterKey,
              icon: Icons.arrow_drop_down,
              label: 'Period',
              getCurrentValue: () => _selectedPeriod ?? 'All',
              options: _periodOptions,
              onSelected: (value) {
                setState(() {
                  _selectedPeriod = value == 'All' ? null : value;
                  _applyFilters();
                });
              },
            ),
            const SizedBox(width: 8),

            // Supervisor Filter Chip with GlobalKey
            _buildFilterChipWithMenu(
              context,
              key: _supervisorFilterKey,
              icon: Icons.arrow_drop_down,
              label: 'Supervisor',
              getCurrentValue: () => _selectedSupervisor ?? 'All',
              options: _supervisorOptions,
              onSelected: (value) {
                setState(() {
                  _selectedSupervisor = value == 'All' ? null : value;
                  _applyFilters();
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChipWithMenu(
    BuildContext context, {
    required GlobalKey key,
    required IconData icon,
    required String label,
    required String Function() getCurrentValue,
    required List<String> options,
    required Function(String) onSelected,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final currentValue = getCurrentValue();
    final isActive = currentValue != 'All';

    return GestureDetector(
      onTap: () {
        _showMenuForChip(context, key, options, currentValue, onSelected);
      },
      child: Container(
        key: key,
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isActive
              ? colorScheme.primary.withOpacity(0.1)
              : colorScheme.surfaceContainer,
          border: Border.all(
            color: isActive
                ? colorScheme.primary
                : colorScheme.outline.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isActive
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              isActive ? currentValue : label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: isActive
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMenuForChip(
    BuildContext context,
    GlobalKey key,
    List<String> options,
    String currentValue,
    Function(String) onSelected,
  ) {
    final RenderBox renderBox =
        key.currentContext?.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + renderBox.size.height + 4, // Add a small gap
        offset.dx + renderBox.size.width,
        offset.dy + renderBox.size.height + 4,
      ),
      items: options.map((option) {
        return PopupMenuItem<String>(
          value: option,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(option),
              if (option == currentValue)
                Icon(
                  Icons.check,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
            ],
          ),
        );
      }).toList(),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ).then((selectedValue) {
      if (selectedValue != null) {
        onSelected(selectedValue);
      }
    });
  }

  bool _hasActiveFilters() {
    return _searchQuery.isNotEmpty ||
        _selectedStatus != null ||
        (_selectedPeriod != null && _selectedPeriod != 'All') ||
        (_selectedSupervisor != null && _selectedSupervisor != 'All');
  }

  Widget _buildStatusFilterChip(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return PopupMenuButton<String>(
      onSelected: (value) {
        setState(() {
          if (value == 'All') {
            _selectedStatus = null;
          } else {
            _selectedStatus = _stringToApplicationStatus(value);
          }
          _applyFilters();
        });
      },
      itemBuilder: (context) {
        return _statusOptions.map((status) {
          return PopupMenuItem<String>(
            value: status,
            child: Row(
              children: [
                if (_selectedStatus != null &&
                    status != 'All' &&
                    _selectedStatus == _stringToApplicationStatus(status))
                  Icon(Icons.check, size: 18, color: colorScheme.primary),
                if ((_selectedStatus == null && status == 'All') ||
                    (status == 'All' && _selectedStatus == null))
                  Icon(Icons.check, size: 18, color: colorScheme.primary),
                SizedBox(width: 8),
                Text(status),
              ],
            ),
          );
        }).toList();
      },
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: _selectedStatus != null
              ? _getStatusColor(_selectedStatus!).withOpacity(0.1)
              : colorScheme.surfaceContainer,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.arrow_drop_down,
              size: 18,
              color: _selectedStatus != null
                  ? _getStatusColor(_selectedStatus!)
                  : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              _selectedStatus != null
                  ? _selectedStatus.toString().split('.').last
                  : 'Status',
              style: theme.textTheme.labelMedium?.copyWith(
                color: _selectedStatus != null
                    ? _getStatusColor(_selectedStatus!)
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterDialog(BuildContext context) {
    // Store current values in case user cancels
    final currentStatus = _selectedStatus;
    final currentPeriod = _selectedPeriod;
    final currentSupervisor = _selectedSupervisor;

    showDialog(
      context: context,
      builder: (context) {
        // Local variables for the dialog
        ApplicationStatus? tempStatus = _selectedStatus;
        String? tempPeriod = _selectedPeriod;
        String? tempSupervisor = _selectedSupervisor;

        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              insetPadding: const EdgeInsets.all(20),
              child: Container(
                constraints: BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Filter Options',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, size: 20),
                            onPressed: () => Navigator.pop(context),
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints(),
                          ),
                        ],
                      ),
                    ),

                    // Divider
                    Divider(height: 1),

                    // Filter Content
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Status Filter
                          _buildFilterSection(
                            context,
                            title: 'Status',
                            options: _statusOptions,
                            selectedValue:
                                tempStatus?.toString().split('.').last ?? 'All',
                            onChanged: (value) {
                              setState(() {
                                tempStatus = value == 'All'
                                    ? null
                                    : _stringToApplicationStatus(value);
                              });
                            },
                          ),

                          const SizedBox(height: 16),

                          // Period Filter
                          _buildFilterSection(
                            context,
                            title: 'Period',
                            options: _periodOptions,
                            selectedValue: tempPeriod ?? 'All',
                            onChanged: (value) {
                              setState(() {
                                tempPeriod = value == 'All' ? null : value;
                              });
                            },
                          ),

                          const SizedBox(height: 24),

                          // Clear All Button
                          if ((tempStatus != null) ||
                              (tempPeriod != null && tempPeriod != 'All') ||
                              (tempSupervisor != null &&
                                  tempSupervisor != 'All'))
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      tempStatus = null;
                                      tempPeriod = null;
                                      tempSupervisor = null;
                                    });
                                  },
                                  icon: Icon(Icons.clear_all, size: 16),
                                  label: Text('Clear All'),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),

                    // Footer with Action Buttons
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: Theme.of(context).dividerColor,
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              // Cancel - restore original values
                              _selectedStatus = currentStatus;
                              _selectedPeriod = currentPeriod;
                              _selectedSupervisor = currentSupervisor;
                              _applyFilters();
                              Navigator.pop(context);
                            },
                            child: Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              // Apply the filters
                              setState(() {
                                _selectedStatus = tempStatus;
                                _selectedPeriod = tempPeriod;
                                _selectedSupervisor = tempSupervisor;
                                _applyFilters();
                              });
                              Navigator.pop(context);
                            },
                            child: Text('Apply'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterSection(
    BuildContext context, {
    required String title,
    required List<String> options,
    required String selectedValue,
    required Function(String) onChanged,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final isSelected = selectedValue == option;
            return FilterChip(
              label: Text(option),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  onChanged(option);
                }
              },
              selectedColor: colorScheme.primary.withOpacity(0.2),
              checkmarkColor: colorScheme.primary,
              labelStyle: theme.textTheme.labelMedium?.copyWith(
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  ApplicationStatus _stringToApplicationStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return ApplicationStatus.pending;
      case 'accepted':
        return ApplicationStatus.accepted;
      case 'rejected':
        return ApplicationStatus.rejected;
      default:
        return ApplicationStatus.pending;
    }
  }

  Widget _buildApplicationsList(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return Center(child: Text('Please log in'));
    }

    return StreamBuilder<List<StudentApplication>?>(
      stream: company_cloud.studentInternshipApplicationsForCompanyStream(
        currentUser.uid,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _buildErrorState(context, snapshot.error!);
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState(context);
        }

        // Store the data locally for filtering
        if (_allApplications.isEmpty || _isRefreshing) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _allApplications = snapshot.data!;
                _applyFilters();
              });
            }
          });
        }

        // Use filtered applications for display
        return _buildApplicationsListView(
          Stream.value(_filteredApplications),
          context,
        );
      },
    );
  }

  Widget _buildApplicationsListView(
    Stream<List<StudentApplication>?> applicationStream,
    BuildContext context,
  ) {
    return StreamBuilder(
      stream: applicationStream,
      builder: (context, snapshot) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        final colorScheme = theme.colorScheme;

        // Error state - must return a Widget
        if (snapshot.hasError) {
          return _buildErrorState(context, snapshot.error!);
        }

        // Loading state - check connection state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // Empty state - check if data exists and is empty
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState(context);
        }

        final dataLength = snapshot.data!.length;
        if (applicationCount != dataLength) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                applicationCount = dataLength;
              });
            }
          });
        }
        return Container(
          color: isDark
              ? colorScheme.surfaceContainerHigh
              : colorScheme.surfaceContainerLow,
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              color: isDark
                  ? colorScheme.outline.withOpacity(0.1)
                  : colorScheme.outline.withOpacity(0.08),
              indent: 16,
              endIndent: 16,
            ),
            itemBuilder: (context, index) {
              final application = snapshot.data![index];
              return _buildApplicationItem(context, application);
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.description_outlined,
            size: 64,
            color: colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No applications found',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Student applications will appear here',
            style: TextStyle(color: colorScheme.outline, fontSize: 14),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: refreshData, // Use refreshData
            icon: Icon(Icons.refresh, size: 18),
            label: Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildApplicationItem(
    BuildContext context,
    StudentApplication application,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;
    debugPrint("application status ${application.applicationStatus}");

    return Material(
      color: isDark
          ? colorScheme.surfaceContainerHighest
          : colorScheme.surfaceContainerLowest,
      child: InkWell(
        onTap: () {
          // Navigate to application details
          GeneralMethods.navigateTo(
            context,
            StudentApplicationDetailsPage(application: application),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Student Avatar
              CircleAvatar(
                radius: 24,
                backgroundImage: application.student.imageUrl.isNotEmpty
                    ? NetworkImage(application.student.imageUrl)
                    : null,
                backgroundColor: colorScheme.surfaceContainer,
                child: application.student.imageUrl.isEmpty
                    ? Text(
                        application.student.fullName[0].toUpperCase(),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),

              // Application Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Internship Title (Most Important)
                    Text(
                      application.internship?.title ?? 'Internship Application',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // Student Name and Institution
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 14,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            application.student.fullName,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),

                    // Institution and Course
                    Row(
                      children: [
                        Icon(
                          Icons.school_outlined,
                          size: 14,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${application.student.institution} • ${application.student.courseOfStudy}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),

                    // Application Date
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 14,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatApplicationDate(application.applicationDate),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant.withOpacity(
                              0.7,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Skills/Tags (if any)
                    if (application.student.skills.isNotEmpty) ...[
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: application.student.skills
                            .take(3)
                            .map(
                              (skill) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceVariant,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  skill,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 4),
                    ],
                  ],
                ),
              ),

              // Status and Actions
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(
                        application.applicationStatus.toApplicationStatus(),
                      ).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _getStatusColor(
                          application.applicationStatus.toApplicationStatus(),
                        ).withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          application.statusIcon,
                          size: 14,
                          color: _getStatusColor(
                            application.applicationStatus.toApplicationStatus(),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          application.statusDisplayName,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: _getStatusColor(
                              application.applicationStatus
                                  .toApplicationStatus(),
                            ),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // View Details Button
                  OutlinedButton.icon(
                    onPressed: () {
                      _showApplicationDetails(context, application);
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      side: BorderSide(
                        color: colorScheme.outline.withOpacity(0.3),
                      ),
                    ),
                    icon: Icon(
                      Icons.visibility_outlined,
                      size: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    label: Text(
                      'View',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ), // Delete  Button
                  OutlinedButton.icon(
                    onPressed: () {
                      _deleteApplication(context, application);
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      side: BorderSide(
                        color: colorScheme.outline.withOpacity(0.3),
                      ),
                    ),
                    icon: Icon(
                      Icons.delete_forever,
                      size: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    label: Text(
                      'Delete',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  _deleteApplication(
    BuildContext context,
    StudentApplication application,
  ) async {
    // Show confirmation dialog first
    bool confirmDelete = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: const Text(
            'Are you sure you want to delete this application? This action cannot be undone.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );

    if (confirmDelete == true) {
      // Show reason selection dialog
      String? selectedReason;
      String otherReasonText = '';

      List<Map<String, String>> reasons = [
        {'label': 'Too many applications', 'value': 'TOO_MANY_APPS'},
        {'label': 'File sent is not clear', 'value': 'FILE_NOT_CLEAR'},
        {
          'label': 'Student information is not complete',
          'value': 'INFO_INCOMPLETE',
        },
        {'label': 'Others', 'value': 'OTHER'},
      ];

      // Variables to manage state
      bool isOtherSelected = false;

      await showDialog(
        context: context,
        builder: (BuildContext context) {
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: const Text('Select Deletion Reason'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Reason dropdown
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Reason for deletion *',
                          border: OutlineInputBorder(),
                        ),
                        value: selectedReason,
                        items: reasons.map((reason) {
                          return DropdownMenuItem<String>(
                            value: reason['value'],
                            child: Text(
                              reason['label']!,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedReason = value;
                            isOtherSelected = (value == 'OTHER');
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select a reason';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Other reason text field (only shown when "Others" is selected)
                      if (isOtherSelected)
                        TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Please specify other reason *',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 3,
                          onChanged: (value) {
                            otherReasonText = value;
                          },
                          validator: (value) {
                            if (isOtherSelected &&
                                (value == null || value.trim().isEmpty)) {
                              return 'Please specify the reason';
                            }
                            return null;
                          },
                        ),
                    ],
                  ),
                ),
                actions: <Widget>[
                  TextButton(
                    child: const Text('Cancel'),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Delete Application'),
                    onPressed: () {
                      // Validation
                      if (selectedReason == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Please select a reason for deletion',
                            ),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }

                      if (isOtherSelected && otherReasonText.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Please specify the reason for deletion',
                            ),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }

                      // Build final reason
                      String finalReason = reasons.firstWhere(
                        (r) => r['value'] == selectedReason,
                      )['label']!;

                      if (isOtherSelected) {
                        finalReason = otherReasonText.trim();
                      }

                      // Close dialog and proceed with deletion
                      Navigator.of(
                        context,
                      ).pop({'proceed': true, 'reason': finalReason});
                    },
                  ),
                ],
              );
            },
          );
        },
      ).then((result) async {
        if (result != null && result['proceed'] == true) {
          // Call API to delete application
          try {
            // Show loading indicator
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) =>
                  const Center(child: CircularProgressIndicator()),
            );

            bool isApplicationDeleted;

            // Call your API service
            try {
              await company_cloud.deleteApplications(
                companyId: FirebaseAuth.instance.currentUser!.uid,
                studentId: application.student.uid,
                internship: application.internship!.id ?? "",
                reason: result['reason'],
                application: application,
              );
              isApplicationDeleted = true;
            } catch (error) {
              isApplicationDeleted = false;
            }
            if (true) {
              // Show success message
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Application deleted successfully'),
                  backgroundColor: Colors.green,
                ),
              );

              // Refresh the applications list
              if (context.mounted) {
                Navigator.of(context).pop(true);
              }
            } else {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Failed to delete application'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          } catch (error) {
            // Close loading indicator if still showing
            if (context.mounted) {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error: $error'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }
      });
    }
  }

  // Helper methods
  Color _getStatusColor(ApplicationStatus status) {
    switch (status) {
      case ApplicationStatus.accepted:
        return Colors.green;
      case ApplicationStatus.pending:
        return Colors.orange;
      case ApplicationStatus.rejected:
        return Colors.red;
    }
  }

  String _formatApplicationDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    }
    if (difference.inDays > 0) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    }
    if (difference.inHours > 0) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    }
    return 'Just now';
  }

  // Application details dialog
  void _showApplicationDetails(
    BuildContext context,
    StudentApplication application,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          application.internship?.title ?? 'Application Details',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Internship Title
              if (application.internship?.title != null) ...[
                const Text(
                  'Internship Position:',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                Text(
                  application.internship!.title,
                  style: const TextStyle(fontSize: 16, color: Colors.blue),
                ),
                const SizedBox(height: 12),
              ],

              // Student Information
              const Text(
                'Applicant Information:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              _buildDetailRow('Name', application.student.fullName),
              _buildDetailRow('Email', application.student.email),
              _buildDetailRow('Phone', application.student.phoneNumber),
              _buildDetailRow('Institution', application.student.institution),
              _buildDetailRow('Course', application.student.courseOfStudy),
              _buildDetailRow('Level', application.student.level),
              _buildDetailRow(
                'CGPA',
                '${application.student.cgpa.toStringAsFixed(2)}',
              ),

              // Application Details
              const SizedBox(height: 12),
              const Text(
                'Application Details:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              _buildDetailRow('Status', application.applicationStatus),
              _buildDetailRow(
                'Applied Date',
                _formatDate(application.applicationDate),
              ),

              // Skills
              if (application.student.skills.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Skills:',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: application.student.skills
                      .map(
                        (skill) => Chip(
                          label: Text(skill),
                          visualDensity: VisualDensity.compact,
                        ),
                      )
                      .toList(),
                ),
              ],

              // // Cover Letter
              // if (application. != null && application.coverLetter!.isNotEmpty) ...[
              //   const SizedBox(height: 12),
              //   const Text(
              //     'Cover Letter:',
              //     style: TextStyle(
              //       fontWeight: FontWeight.w600,
              //       fontSize: 14,
              //     ),
              //   ),
              //   Container(
              //     padding: const EdgeInsets.all(12),
              //     decoration: BoxDecoration(
              //       color: Colors.grey.shade100,
              //       borderRadius: BorderRadius.circular(8),
              //     ),
              //     child: Text(
              //       application.coverLetter!,
              //       style: const TextStyle(fontSize: 14),
              //     ),
              //   ),
              // ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          // Action buttons based on status
          if (application.applicationStatus.toLowerCase() == 'pending')
            Row(
              children: [
                OutlinedButton(
                  onPressed: () {
                    // Reject application
                    _handleApplicationAction(context, application, 'reject');
                  },
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Reject'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    // Accept application
                    _handleApplicationAction(context, application, 'accept');
                  },
                  child: const Text('Accept'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
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

              GeneralMethods.showLoading(context);
              await company_cloud.updateApplicationStatus(
                companyId: FirebaseAuth.instance.currentUser!.uid,
                internshipId: application.internship!.id!,
                studentId: application.student.uid,
                status: action,
                application: application,
              );
              Student student = application.student;
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

  Widget _buildErrorState(BuildContext context, Object error) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'Error Loading Posts',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w500,
                color: colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                setState(() async {
                  _cachedApplications = companyCloud
                      .studentInternshipApplicationsForCompanyStream(
                        FirebaseAuth.instance.currentUser!.uid,
                      );
                  _isDataLoaded = true;
                });
              },
              icon: Icon(Icons.refresh),
              label: Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
