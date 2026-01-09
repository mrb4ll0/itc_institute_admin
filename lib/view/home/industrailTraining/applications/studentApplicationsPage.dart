import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:itc_institute_admin/generalmethods/GeneralMethods.dart';
import 'package:itc_institute_admin/itc_logic/firebase/Student_cloud.dart';
import 'package:itc_institute_admin/itc_logic/firebase/company_cloud.dart';
import 'package:itc_institute_admin/itc_logic/firebase/general_cloud.dart';
import 'package:itc_institute_admin/view/home/studentApplications/studentApplicationDetail.dart';
import 'package:intl/intl.dart';

import '../../../../itc_logic/notification/fireStoreNotification.dart';
import '../../../../itc_logic/notification/notitification_service.dart';
import '../../../../model/student.dart';
import '../../../../model/studentApplication.dart';

class SpecificStudentApplicationsPage extends StatefulWidget {
  final String companyId;
  final String studentUid;
  final String studentName;
  final int totalApplications;

  const SpecificStudentApplicationsPage({
    Key? key,
    required this.companyId,
    required this.studentUid,
    this.studentName = '',
    this.totalApplications = 0,
  }) : super(key: key);

  @override
  _SpecificStudentApplicationsPageState createState() => _SpecificStudentApplicationsPageState();
}

class _SpecificStudentApplicationsPageState extends State<SpecificStudentApplicationsPage> {
  late Company_Cloud _applicationService;
  List<StudentApplication> _applications = [];
  List<StudentApplication> _filteredApplications = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  final NotificationService notificationService = NotificationService();
  final FireStoreNotification fireStoreNotification = FireStoreNotification();

  // Filtering variables
  String _searchQuery = '';
  ApplicationStatus? _selectedStatus;
  String? _selectedDateRange;
  String? _selectedSortBy;
  bool _showFilters = false;

  // Date picker variables
  DateTime? _startDate;
  DateTime? _endDate;

  // Filter options
  final List<String> _statusOptions = [
    'All',
    'Pending',
    'Accepted',
    'Rejected',
  ];

  final List<String> _dateRangeOptions = [
    'All Time',
    'Last 7 Days',
    'Last 30 Days',
    'Last 90 Days',
    'Custom Range',
  ];

  final List<String> _sortOptions = [
    'Newest First',
    'Oldest First',
    'Status (A-Z)',
    'Internship Title (A-Z)',
  ];

  @override
  void initState() {
    super.initState();
    _applicationService = Company_Cloud();
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

      for (var application in applications) {
        debugPrint("application id ${application.id}");
      }


      setState(() {
        _applications = applications;
        _applyFilters();
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

  void _applyFilters() {
    List<StudentApplication> filtered = List.from(_applications);

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((app) {
        final internshipTitle = app.internship?.title?.toLowerCase() ?? '';
        final description = app.internship?.description?.toLowerCase() ?? '';
        final query = _searchQuery.toLowerCase();

        return internshipTitle.contains(query) || description.contains(query);
      }).toList();
    }

    // Apply status filter
    if (_selectedStatus != null) {
      filtered = filtered.where((app) {
        return app.applicationStatus.toLowerCase() ==
            _selectedStatus.toString().split('.').last.toLowerCase();
      }).toList();
    }

    // Apply date range filter
    if (_selectedDateRange != null && _selectedDateRange != 'All Time') {
      DateTime now = DateTime.now();
      DateTime? cutoffDate;

      switch (_selectedDateRange) {
        case 'Last 7 Days':
          cutoffDate = now.subtract(Duration(days: 7));
          break;
        case 'Last 30 Days':
          cutoffDate = now.subtract(Duration(days: 30));
          break;
        case 'Last 90 Days':
          cutoffDate = now.subtract(Duration(days: 90));
          break;
        case 'Custom Range':
          if (_startDate != null && _endDate != null) {
            filtered = filtered.where((app) {
              return app.applicationDate.isAfter(_startDate!) &&
                  app.applicationDate.isBefore(_endDate!);
            }).toList();
          }
          break;
      }

      if (cutoffDate != null && _selectedDateRange != 'Custom Range') {
        filtered = filtered.where((app) {
          return app.applicationDate.isAfter(cutoffDate!);
        }).toList();
      }
    }

    // Apply sorting
    if (_selectedSortBy != null) {
      switch (_selectedSortBy) {
        case 'Newest First':
          filtered.sort((a, b) => b.applicationDate.compareTo(a.applicationDate));
          break;
        case 'Oldest First':
          filtered.sort((a, b) => a.applicationDate.compareTo(b.applicationDate));
          break;
        case 'Status (A-Z)':
          filtered.sort((a, b) => a.applicationStatus.compareTo(b.applicationStatus));
          break;
        case 'Internship Title (A-Z)':
          filtered.sort((a, b) => (a.internship?.title ?? '')
              .compareTo(b.internship?.title ?? ''));
          break;
      }
    } else {
      // Default sort: newest first
      filtered.sort((a, b) => b.applicationDate.compareTo(a.applicationDate));
    }

    setState(() {
      _filteredApplications = filtered;
    });
  }

  Future<void> _updateApplicationStatus(
      StudentApplication application,
      String newStatus,
      ) async {
    try {
      // Create updated application
      final updatedApplication = application.copyWith(
        applicationStatus: newStatus,
        applicationDate: DateTime.now(),
      );

      GeneralMethods.showLoading(context);

      await _applicationService.updateApplicationStatus(
        companyId: widget.companyId,
        internshipId: application.internship.id??"",
        studentId: application.student.uid,
        status: newStatus,
        application: updatedApplication,
      );

      // Send notification
      Student student = application.student;
      bool notificationSent = await notificationService.sendNotificationToUser(
        fcmToken: student.fcmToken ?? "",
        title: application.internship.company.name,
        body: "Your application for ${application.internship.title} is ${GeneralMethods.normalizeApplicationStatus(newStatus).toUpperCase()}",
      );

      await fireStoreNotification.sendNotificationToStudent(
        studentUid: student.uid,
        title: application.internship.company.name,
        body: "Your application for ${application.internship.title} is ${GeneralMethods.normalizeApplicationStatus(newStatus).toUpperCase()}",
      );

      GeneralMethods.hideLoading(context);

      // Update local list
      setState(() {
        final index = _applications.indexWhere((app) => app.id == application.id);
        if (index != -1) {
          _applications[index] = updatedApplication;
        }
        _applyFilters();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Application ${newStatus.toLowerCase()}d successfully'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      GeneralMethods.hideLoading(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildHeader() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary,
            colorScheme.secondary,
          ],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(width: 50,),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.studentName,
                      style: textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${_applications.length} applications • ${_filteredApplications.length} filtered',
                      style: textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          // Quick stats
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatItem('Pending', Icons.pending, Colors.amber),
              _buildStatItem('Accepted', Icons.check_circle, Colors.green),
              _buildStatItem('Rejected', Icons.cancel, Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, IconData icon, Color color) {
    final count = _applications
        .where((app) => app.applicationStatus.toLowerCase() == label.toLowerCase())
        .length;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        SizedBox(height: 6),
        Text(
          count.toString(),
          style: textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(
            color: Colors.white.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilters() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Search Bar
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: theme.shadowColor.withOpacity(0.1),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Icon(
                    Icons.search,
                    color: theme.hintColor,
                  ),
                ),
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search applications...',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      hintStyle: textTheme.bodyMedium?.copyWith(color: theme.hintColor),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                        _applyFilters();
                      });
                    },
                    style: textTheme.bodyMedium,
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  IconButton(
                    icon: Icon(Icons.clear, size: 20, color: colorScheme.onSurface),
                    onPressed: () {
                      setState(() {
                        _searchQuery = '';
                        _applyFilters();
                      });
                    },
                  ),
                IconButton(
                  icon: Icon(
                    Icons.filter_list,
                    color: _hasActiveFilters() ? colorScheme.primary : theme.hintColor,
                  ),
                  onPressed: () {
                    setState(() => _showFilters = !_showFilters);
                  },
                ),
              ],
            ),
          ),

          // Filters Panel
          if (_showFilters)
            Container(
              margin: EdgeInsets.only(top: 16),
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: theme.shadowColor.withOpacity(0.1),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Filters',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_hasActiveFilters())
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _selectedStatus = null;
                              _selectedDateRange = null;
                              _selectedSortBy = null;
                              _startDate = null;
                              _endDate = null;
                              _applyFilters();
                            });
                          },
                          icon: Icon(Icons.clear_all, size: 16),
                          label: Text('Clear All'),
                        ),
                    ],
                  ),
                  SizedBox(height: 16),

                  // Status Filter
                  _buildFilterSection(
                    title: 'Status',
                    currentValue: _selectedStatus?.toString().split('.').last ?? 'All',
                    options: _statusOptions,
                    onChanged: (value) {
                      setState(() {
                        _selectedStatus = value == 'All' ? null : _stringToApplicationStatus(value);
                        _applyFilters();
                      });
                    },
                  ),

                  SizedBox(height: 12),

                  // Date Range Filter
                  _buildFilterSection(
                    title: 'Date Range',
                    currentValue: _selectedDateRange ?? 'All Time',
                    options: _dateRangeOptions,
                    onChanged: (value) {
                      setState(() {
                        _selectedDateRange = value == 'All Time' ? null : value;
                        if (value == 'Custom Range') {
                          _showDateRangePicker();
                        } else {
                          _applyFilters();
                        }
                      });
                    },
                  ),

                  SizedBox(height: 12),

                  // Sort By Filter
                  _buildFilterSection(
                    title: 'Sort By',
                    currentValue: _selectedSortBy ?? 'Newest First',
                    options: _sortOptions,
                    onChanged: (value) {
                      setState(() {
                        _selectedSortBy = value;
                        _applyFilters();
                      });
                    },
                  ),
                ],
              ),
            ),

          // Active Filter Chips
          if (_hasActiveFilters() && !_showFilters)
            Container(
              margin: EdgeInsets.only(top: 12),
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  if (_selectedStatus != null)
                    _buildActiveFilterChip(
                      'Status: ${_selectedStatus.toString().split('.').last}',
                      onRemove: () {
                        setState(() {
                          _selectedStatus = null;
                          _applyFilters();
                        });
                      },
                    ),
                  if (_selectedDateRange != null)
                    _buildActiveFilterChip(
                      'Date: $_selectedDateRange',
                      onRemove: () {
                        setState(() {
                          _selectedDateRange = null;
                          _startDate = null;
                          _endDate = null;
                          _applyFilters();
                        });
                      },
                    ),
                  if (_selectedSortBy != null)
                    _buildActiveFilterChip(
                      'Sort: $_selectedSortBy',
                      onRemove: () {
                        setState(() {
                          _selectedSortBy = null;
                          _applyFilters();
                        });
                      },
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterSection({
    required String title,
    required String currentValue,
    required List<String> options,
    required Function(String) onChanged,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: theme.hintColor,
          ),
        ),
        SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final isSelected = currentValue == option;
            return ChoiceChip(
              label: Text(option),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  onChanged(option);
                }
              },
              selectedColor: colorScheme.primary.withOpacity(0.2),
              backgroundColor: theme.cardColor,
              labelStyle: textTheme.bodyMedium?.copyWith(
                color: isSelected ? colorScheme.primary : colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildActiveFilterChip(String label, {required VoidCallback onRemove}) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.primary.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: colorScheme.primary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(width: 6),
            GestureDetector(
              onTap: onRemove,
              child: Icon(
                Icons.close,
                size: 14,
                color: colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDateRangePicker() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : DateTimeRange(
        start: DateTime.now().subtract(Duration(days: 30)),
        end: DateTime.now(),
      ),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _applyFilters();
      });
    }
  }

  bool _hasActiveFilters() {
    return _selectedStatus != null ||
        _selectedDateRange != null ||
        _selectedSortBy != null;
  }

  Widget _buildApplicationCard(StudentApplication application) {
    debugPrint("in _buildApplicationCard appid is${application.id} ");
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final statusColor = _getStatusColor(application.applicationStatus);

    return Card(
      elevation: 2,
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: statusColor.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      application.internship.title ?? 'Unknown Internship',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getStatusIcon(application.applicationStatus),
                          size: 14,
                          color: statusColor,
                        ),
                        SizedBox(width: 4),
                        Text(
                          application.applicationStatus.toUpperCase(),
                          style: textTheme.labelSmall?.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              SizedBox(height: 12),

              // Description
              if (application.internship.description != null &&
                  application.internship.description!.isNotEmpty)
                Text(
                  application.internship.description!,
                  style: textTheme.bodyMedium?.copyWith(
                    color: theme.hintColor,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),

              SizedBox(height: 16),

              // Details Row
              Row(
                children: [
                  _buildDetailItem(
                    Icons.calendar_today,
                    DateFormat('MMM dd, yyyy').format(application.applicationDate),
                  ),
                  SizedBox(width: 16),
                  if (application.internship.location != null)
                    _buildDetailItem(
                      Icons.location_on,
                      application.internship.location!,
                    ),
                  Spacer(),
                  if (application.internship.stipend != null)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade100),
                      ),
                      child: Text(
                        application.internship.stipend!,
                        style: textTheme.labelSmall?.copyWith(
                          color: Colors.green.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),

              SizedBox(height: 16),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        GeneralMethods.navigateTo(
                            context,
                            StudentApplicationDetailsPage(application: application)
                        );
                      },
                      icon: Icon(Icons.visibility_outlined, size: 16),
                      label: Text('View Details'),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  if (application.applicationStatus.toLowerCase() == 'pending')
                    _buildActionButtons(application),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String text) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, size: 16, color: theme.hintColor),
        SizedBox(width: 4),
        Text(
          text,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.hintColor,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(StudentApplication application) {
    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(10),
          ),
          child: IconButton(
            onPressed: () => _showAcceptConfirmation(application),
            icon: Icon(Icons.check, color: Colors.green.shade800),
            tooltip: 'Accept',
          ),
        ),
        SizedBox(width: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(10),
          ),
          child: IconButton(
            onPressed: () => _showRejectConfirmation(application),
            icon: Icon(Icons.close, color: Colors.red.shade800),
            tooltip: 'Reject',
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Theme.of(context).colorScheme.onSurface;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'pending':
        return Icons.pending;
      default:
        return Icons.help;
    }
  }

  void _showAcceptConfirmation(StudentApplication application) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Accept Application'),
          ],
        ),
        content: Text(
          'Are you sure you want to accept this application for '
              '${application.internship.title}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateApplicationStatus(application, 'accepted');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: Text('Accept'),
          ),
        ],
      ),
    );
  }

  void _showRejectConfirmation(StudentApplication application) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.cancel, color: Colors.red),
            SizedBox(width: 8),
            Text('Reject Application'),
          ],
        ),
        content: Text(
          'Are you sure you want to reject this application for '
              '${application.internship.title}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateApplicationStatus(application, 'rejected');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text('Reject'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.description_outlined,
            size: 100,
            color: theme.hintColor,
          ),
          SizedBox(height: 20),
          Text(
            _hasActiveFilters() ? 'No matching applications' : 'No applications yet',
            style: textTheme.titleLarge?.copyWith(
              color: theme.hintColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            _hasActiveFilters()
                ? 'Try adjusting your filters'
                : 'This student has not applied to any internships',
            style: textTheme.bodyMedium?.copyWith(
              color: theme.hintColor,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 20),
          if (_hasActiveFilters())
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _selectedStatus = null;
                  _selectedDateRange = null;
                  _selectedSortBy = null;
                  _startDate = null;
                  _endDate = null;
                  _applyFilters();
                });
              },
              child: Text('Clear All Filters'),
            ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 20),
          Text(
            'Loading applications...',
            style: textTheme.bodyMedium?.copyWith(
              color: theme.hintColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 80,
            color: colorScheme.error,
          ),
          SizedBox(height: 20),
          Text(
            'Unable to load applications',
            style: textTheme.titleLarge?.copyWith(
              color: colorScheme.error,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              _errorMessage,
              style: textTheme.bodyMedium?.copyWith(color: theme.hintColor),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _loadApplications,
            icon: Icon(Icons.refresh),
            label: Text('Try Again'),
          ),
        ],
      ),
    );
  }

  void _showStats() {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    final pendingCount = _applications
        .where((app) => app.applicationStatus.toLowerCase() == 'pending')
        .length;
    final acceptedCount = _applications
        .where((app) => app.applicationStatus.toLowerCase() == 'accepted')
        .length;
    final rejectedCount = _applications
        .where((app) => app.applicationStatus.toLowerCase() == 'rejected')
        .length;
    final totalCount = _applications.length;

    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Application Statistics',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),
            _buildStatRow('Total Applications', totalCount, Icons.list, Colors.blue),
            _buildStatRow('Pending', pendingCount, Icons.pending, Colors.orange),
            _buildStatRow('Accepted', acceptedCount, Icons.check_circle, Colors.green),
            _buildStatRow('Rejected', rejectedCount, Icons.cancel, Colors.red),
            SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, int count, IconData icon, Color color) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: textTheme.bodyLarge,
            ),
          ),
          Text(
            count.toString(),
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surfaceVariant,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            floating: true,
            pinned: true,
            snap: true,
            flexibleSpace: FlexibleSpaceBar(
              background: _buildHeader(),
            ),
            actions: [
              IconButton(
                onPressed: _loadApplications,
                icon: Icon(Icons.refresh, color: Colors.white),
                tooltip: 'Refresh',
              ),
              IconButton(
                onPressed: _showStats,
                icon: Icon(Icons.analytics, color: Colors.white),
                tooltip: 'Statistics',
              ),
            ],
          ),

          SliverToBoxAdapter(
            child: _buildSearchAndFilters(),
          ),

          if (_isLoading)
            SliverFillRemaining(
              child: _buildLoadingState(),
            )
          else if (_hasError)
            SliverFillRemaining(
              child: _buildErrorState(),
            )
          else if (_filteredApplications.isEmpty)
              SliverFillRemaining(
                child: _buildEmptyState(),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildApplicationCard(_filteredApplications[index]),
                  childCount: _filteredApplications.length,
                ),
              ),
        ],
      ),

      floatingActionButton: _filteredApplications.isNotEmpty
          ? FloatingActionButton.extended(
        onPressed: () {
          // Export or additional actions
          _showExportOptions();
        },
        icon: Icon(Icons.download),
        label: Text('Export'),
        backgroundColor: colorScheme.primary,
      )
          : null,
    );
  }

  void _showExportOptions() {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Export Options',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),
            ListTile(
              leading: Icon(Icons.file_download, color: colorScheme.primary),
              title: Text('Export as CSV'),
              subtitle: Text('Export all filtered applications'),
              onTap: () {
                Navigator.pop(context);
                // Implement CSV export
                Fluttertoast.showToast(msg: "Feature is not available");
              },
            ),
            ListTile(
              leading: Icon(Icons.picture_as_pdf, color: Colors.red),
              title: Text('Export as PDF'),
              subtitle: Text('Generate PDF report'),
              onTap: () {
                Navigator.pop(context);
                // Implement PDF export
                Fluttertoast.showToast(msg: "Feature is not available");
              },
            ),
            ListTile(
              leading: Icon(Icons.print, color: Colors.green),
              title: Text('Print Report'),
              subtitle: Text('Print application details'),
              onTap: () {
                Navigator.pop(context);
                // Implement print
                Fluttertoast.showToast(msg: "Feature is not available");
              },
            ),
            SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}