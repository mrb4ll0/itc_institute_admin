import 'dart:io';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:open_file/open_file.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:itc_institute_admin/generalmethods/GeneralMethods.dart';
import 'package:itc_institute_admin/itc_logic/firebase/Student_cloud.dart';
import 'package:itc_institute_admin/itc_logic/firebase/company_cloud.dart';
import 'package:itc_institute_admin/itc_logic/firebase/general_cloud.dart';
import 'package:itc_institute_admin/view/home/studentApplications/studentApplicationDetail.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../itc_logic/firebase/AuthorityRulesHelper.dart';
import '../../../../itc_logic/idservice/globalIdService.dart';
import '../../../../itc_logic/notification/fireStoreNotification.dart';
import '../../../../itc_logic/notification/notificationPanel/notificationPanelService.dart';
import '../../../../itc_logic/notification/notitification_service.dart';
import '../../../../letterGenerator/GenerateAcceptanceLetter.dart';
import '../../../../model/authority.dart';
import '../../../../model/notificationModel.dart';
import '../../../../model/student.dart';
import '../../../../model/studentApplication.dart';

class SpecificStudentApplicationsPage extends StatefulWidget {
  final String companyId;
  final String studentUid;
  final String studentName;
  final int totalApplications;
  final bool isAuthority;
  final List<String> companyIds;

  const SpecificStudentApplicationsPage({
    Key? key,
    required this.companyId,
    required this.studentUid,
    this.studentName = '',
    this.totalApplications = 0,
    required this.isAuthority,
    required this.companyIds,
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



  bool canAcceptOrReject = false;
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

  Authority? authority;
  @override
  void initState() {
    super.initState();
    _applicationService = Company_Cloud(GlobalIdService.firestoreId);
    canAcceptOrReject = widget.isAuthority?true:AuthorityRulesHelper.canAcceptStudents(GlobalIdService.firestoreId);

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
        isAuthority:widget.isAuthority,
        companiesIds: widget.companyIds

      );
      authority = await ITCFirebaseLogic(GlobalIdService.firestoreId).getAuthority(GlobalIdService.firestoreId);

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
        isAuthority: widget.isAuthority,
        companyId: application.internship.company.id,
        internshipId: application.internship.id??"",
        studentId: application.student.uid,
        status: newStatus,
        application: updatedApplication,
      );

      // Send notification


      var pdfUrl =  '';
      Student student = application.student;

      if(widget.isAuthority) {

        AcceptanceLetterData acceptanceLetterData = AcceptanceLetterData(
            id: '${application.id}_${getFormattedDateTime()}',
            studentName: student.fullName,
            studentId: student.matricNumber,
            institutionName: student.institution,
            institutionAddress: "",
            institutionPhone: "",
            institutionEmail: "",
            authorityName: authority?.name ?? "",
            companyName: application.internship.company.name,
            companyAddress: application.internship.company.address,
            startDate: DateTime.parse(application.durationDetails['startDate']),
            endDate: DateTime.parse(application.durationDetails['endDate']),
            authorizedSignatoryName: authority?.name ?? "",
            acceptedAt: DateTime.now(),
            authorizedSignatoryPosition: "");
        pdfUrl =
        await runPdfGeneration(acceptanceLetterData, userId: student.uid,);

        await Company_Cloud(GlobalIdService.firestoreId).storeAcceptanceLetter(
            studentId: application.student.uid,
            acceptanceLetterData: acceptanceLetterData,
            internshipId: application.internship.id!,
            internshipTitle: application.internship.title,
            companyId: application.internship.company.id,
            applicationId: application.id,
            pdfFileUrl: pdfUrl,
            isAuthority: widget.isAuthority);
      }
      // bool notificationSent = await notificationService.sendNotificationToUser(
      //   fcmToken: student.fcmToken ?? "",
      //   title: application.internship.company.name,
      //   body: "Your application for ${application.internship.title} is ${GeneralMethods.normalizeApplicationStatus(newStatus).toUpperCase()}",
      // );


      NotificationModel notification = NotificationModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: application.internship.company.name,
        body: "Your application for ${application.internship.title} is ${GeneralMethods.normalizeApplicationStatus(newStatus).toUpperCase()}",
        timestamp: DateTime.now(),
        read: false,
        targetAudience: student.email,
        targetStudentId: student.uid,
        imageUrl: pdfUrl,
        fcmToken: student.fcmToken??"",
        type: NotificationType.announcement.name,
      );

      NotificationPanelService.sendNotificationToAllEnabledChannelsWithSummary(notification);


      debugPrint("pdf url is $pdfUrl");

      // await fireStoreNotification.sendNotificationToStudent(
      //   studentUid: student.uid,
      //   fcmToken: student.fcmToken??"",
      //   title: application.internship.company.name,
      //   imageUrl: pdfUrl,
      //   body: "Your application for ${application.internship.title} is ${GeneralMethods.normalizeApplicationStatus(newStatus).toUpperCase()}",
      // );

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
    } catch (e,s) {
      GeneralMethods.hideLoading(context);
      debugPrintStack(stackTrace: s);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String getFormattedDateTime() {
    final now = DateTime.now();
    return '${now.year}${_twoDigits(now.month)}${_twoDigits(now.day)}${_twoDigits(now.hour)}${_twoDigits(now.minute)}${_twoDigits(now.second)}';
  }

  String _twoDigits(int n) {
    if (n >= 10) return "$n";
    return "0$n";
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
          SizedBox(height:20),
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
              // Header with Status
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

              // 🏢 COMPANY SECTION - Newly Added
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colorScheme.primary.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    // Company Logo/Avatar
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          application.internship.company.name[0] ?? 'C',
                          style: textTheme.titleLarge?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),

                    // Company Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Submitted to',
                            style: textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            application.internship.company.name ??
                                'Unknown Company',
                            style: textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          if (application.internship.company.industry != null)
                            Text(
                              application.internship.company.industry,
                              style: textTheme.labelSmall?.copyWith(
                                color: colorScheme.primary,
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Rating if available
                    // if (application.internship.company != null)
                    //   Container(
                    //     padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    //     decoration: BoxDecoration(
                    //       color: Colors.amber.withOpacity(0.1),
                    //       borderRadius: BorderRadius.circular(20),
                    //     ),
                    //     child: Row(
                    //       children: [
                    //         Icon(
                    //           Icons.star,
                    //           size: 14,
                    //           color: Colors.amber,
                    //         ),
                    //         SizedBox(width: 2),
                    //         Text(
                    //           application.internship.industryPartner!.rating!.toString(),
                    //           style: textTheme.labelSmall?.copyWith(
                    //             fontWeight: FontWeight.bold,
                    //             color: Colors.amber[800],
                    //           ),
                    //         ),
                    //       ],
                    //     ),
                    //   ),
                  ],
                ),
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

              SizedBox(height: 16),

              // Details Column with improved layout
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // First row - Date and Location (wrapped in a Container to control width)
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      _buildDetailItem(
                        Icons.calendar_today,
                        DateFormat('MMM dd, yyyy').format(application.applicationDate),
                      ),
                      if (application.internship.location != null)
                        _buildDetailItem(
                          Icons.location_on,
                          application.internship.location!,
                        ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Second row - Stipend (aligned to start)
                  if (application.internship.stipend != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade100),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.money,
                            size: 14,
                            color: Colors.green.shade700,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            application.internship.stipend!,
                            style: textTheme.labelSmall?.copyWith(
                              color: Colors.green.shade800,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
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
                          StudentApplicationDetailsPage(
                            application: application,
                            isAuthority: widget.isAuthority,
                          ),
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
                  if (application.applicationStatus.toLowerCase() == 'pending' &&
                      (widget.isAuthority ? true : canAcceptOrReject))
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
        icon: Icon(Icons.download,color: Colors.white,),
        label: Text('Export',style: TextStyle(color:Colors.white),),
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
      isScrollControlled: true,
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
              subtitle: Text('Export all ${_filteredApplications.length} applications to CSV'),
              onTap: () {
                Navigator.pop(context);
                _exportAsCSV();
              },
            ),
            ListTile(
              leading: Icon(Icons.picture_as_pdf, color: Colors.red),
              title: Text('Export as PDF'),
              subtitle: Text('Generate PDF report with summary and table'),
              onTap: () {
                Navigator.pop(context);
                _exportAsPDF();
              },
            ),
            ListTile(
              leading: Icon(Icons.print, color: Colors.green),
              title: Text('Print Report'),
              subtitle: Text('Print application summary'),
              onTap: () {
                Navigator.pop(context);
                _printReport();
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

  Future<void> _exportAsCSV() async {
    try {
      // Show loading indicator
      GeneralMethods.showLoading(context);

      // Prepare CSV data
      List<List<dynamic>> rows = [];

      // Add Student Information Header
      rows.add(['Student Information Report']);
      rows.add(['Generated:', DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())]);
      rows.add([]); // Empty row for spacing

      // Add Student Details
      rows.add(['STUDENT DETAILS']);
      rows.add(['Student Name:', widget.studentName]);
      rows.add(['Student ID:', widget.studentUid]);
      rows.add(['Total Applications:', _filteredApplications.length.toString()]);
      rows.add(['Report Filter:', _hasActiveFilters() ? 'Filtered View' : 'All Applications']);

      // Add filter information if any filters are active
      if (_hasActiveFilters()) {
        rows.add(['Active Filters:']);
        if (_selectedStatus != null) {
          rows.add(['  - Status:', _selectedStatus.toString().split('.').last]);
        }
        if (_selectedDateRange != null) {
          rows.add(['  - Date Range:', _selectedDateRange]);
        }
        if (_selectedSortBy != null) {
          rows.add(['  - Sort By:', _selectedSortBy]);
        }
      }

      rows.add([]); // Empty row for spacing
      rows.add(['APPLICATIONS DETAILS']);
      rows.add([]); // Empty row for spacing

      // Add headers for applications table
      rows.add([
        'Application ID',
        'Internship Title',
        'Company Name',
        'Company Industry',
        'Application Date',
        'Status',
        'Location',
        'Stipend',
        'Description',
      ]);

      // Add data rows
      for (var app in _filteredApplications) {
        rows.add([
          app.id,
          app.internship.title ?? 'N/A',
          app.internship.company.name ?? 'N/A',
          app.internship.company.industry ?? 'N/A',
          DateFormat('yyyy-MM-dd HH:mm').format(app.applicationDate),
          app.applicationStatus,
          app.internship.location ?? 'N/A',
          app.internship.stipend ?? 'N/A',
          app.internship.description ?? 'N/A',
        ]);
      }

      // Add summary at the bottom
      rows.add([]); // Empty row for spacing
      rows.add(['SUMMARY']);
      rows.add(['Total Applications:', _filteredApplications.length.toString()]);

      final pendingCount = _filteredApplications
          .where((app) => app.applicationStatus.toLowerCase() == 'pending')
          .length;
      final acceptedCount = _filteredApplications
          .where((app) => app.applicationStatus.toLowerCase() == 'accepted')
          .length;
      final rejectedCount = _filteredApplications
          .where((app) => app.applicationStatus.toLowerCase() == 'rejected')
          .length;

      rows.add(['Pending:', pendingCount.toString()]);
      rows.add(['Accepted:', acceptedCount.toString()]);
      rows.add(['Rejected:', rejectedCount.toString()]);

      rows.add([]); // Empty row for spacing
      rows.add(['End of Report']);

      // Convert to CSV
      String csv = _convertToCSV(rows);

      // Save to file
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'applications_${widget.studentName.replaceAll(' ', '_')}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(csv);

      GeneralMethods.hideLoading(context);

      // Create XFile for sharing
      final xFile = XFile(file.path);

      // Show options dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Export Successful'),
          content: Text('File saved as: $fileName\n\nWhat would you like to do?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Share.shareXFiles([xFile],
                  text: 'Applications for ${widget.studentName}',
                );
              },
              child: const Text('Share'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                OpenFile.open(file.path);
              },
              child: const Text('Open File'),
            ),
          ],
        ),
      );
    } catch (e, s) {
      GeneralMethods.hideLoading(context);
      debugPrintStack(stackTrace: s);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to export CSV: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _exportAsPDF() async {
    try {
      // Show loading indicator
      GeneralMethods.showLoading(context);

      final pdf = pw.Document();

      // Calculate statistics
      final pendingCount = _filteredApplications
          .where((app) => app.applicationStatus.toLowerCase() == 'pending')
          .length;
      final acceptedCount = _filteredApplications
          .where((app) => app.applicationStatus.toLowerCase() == 'accepted')
          .length;
      final rejectedCount = _filteredApplications
          .where((app) => app.applicationStatus.toLowerCase() == 'rejected')
          .length;

      // Add a page to the PDF
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Student Applications Report',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 16),

              // Student Information Box
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'STUDENT INFORMATION',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue700,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      children: [
                        pw.Expanded(
                          child: pw.Text('Name: ${widget.studentName}'),
                        ),
                        pw.Expanded(
                          child: pw.Text('Student ID: ${widget.studentUid}'),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      children: [
                        pw.Expanded(
                          child: pw.Text('Total Applications: ${_filteredApplications.length}'),
                        ),
                        pw.Expanded(
                          child: pw.Text('Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}'),
                        ),
                      ],
                    ),
                    if (_hasActiveFilters()) ...[
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'Active Filters:',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                      ),
                      pw.SizedBox(height: 4),
                      if (_selectedStatus != null)
                        pw.Text('• Status: ${_selectedStatus.toString().split('.').last}',
                            style: const pw.TextStyle(fontSize: 9)),
                      if (_selectedDateRange != null)
                        pw.Text('• Date Range: $_selectedDateRange',
                            style: const pw.TextStyle(fontSize: 9)),
                      if (_selectedSortBy != null)
                        pw.Text('• Sort By: $_selectedSortBy',
                            style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ],
                ),
              ),
              pw.SizedBox(height: 16),
              pw.Divider(),
            ],
          ),
          build: (context) => [
            // Summary Section
            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 20),
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                children: [
                  _buildPDFStatItem('Total', _filteredApplications.length.toString(), PdfColors.blue),
                  _buildPDFStatItem('Pending', pendingCount.toString(), PdfColors.orange),
                  _buildPDFStatItem('Accepted', acceptedCount.toString(), PdfColors.green),
                  _buildPDFStatItem('Rejected', rejectedCount.toString(), PdfColors.red),
                ],
              ),
            ),

            // Applications Table Title
            pw.Text(
              'APPLICATIONS DETAILS',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 12),

            // Applications Table
            pw.Table.fromTextArray(
              border: pw.TableBorder.all(),
              cellAlignment: pw.Alignment.centerLeft,
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 10,
              ),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              data: [
                // Headers
                ['#', 'Title', 'Company', 'Date', 'Status', 'Location', 'Stipend'],
                // Data rows
                ..._filteredApplications.asMap().entries.map((entry) {
                  final index = entry.key + 1;
                  final app = entry.value;
                  return [
                    index.toString(),
                    app.internship.title ?? 'N/A',
                    app.internship.company.name ?? 'N/A',
                    DateFormat('MMM dd, yyyy').format(app.applicationDate),
                    app.applicationStatus,
                    app.internship.location ?? 'N/A',
                    app.internship.stipend ?? 'N/A',
                  ];
                }).toList(),
              ],
            ),

            // Footer note
            pw.SizedBox(height: 20),
            pw.Text(
              'End of Report',
              style: pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey600,
                fontStyle: pw.FontStyle.italic,
              ),
              textAlign: pw.TextAlign.center,
            ),
          ],
          footer: (context) => pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 20),
            child: pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
          ),
        ),
      );

      GeneralMethods.hideLoading(context);

      // Save PDF
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'applications_${widget.studentName.replaceAll(' ', '_')}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(await pdf.save());

      // Create XFile for sharing
      final xFile = XFile(file.path);

      // Show options dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('PDF Generated Successfully'),
          content: Text('File saved as: $fileName\n\nWhat would you like to do?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Share.shareXFiles([xFile],
                  text: 'Applications Report for ${widget.studentName}',
                );
              },
              child: const Text('Share'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                OpenFile.open(file.path);
              },
              child: const Text('Open PDF'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await Printing.layoutPdf(
                  onLayout: (format) async => pdf.save(),
                );
              },
              child: const Text('Print'),
            ),
          ],
        ),
      );
    } catch (e, s) {
      GeneralMethods.hideLoading(context);
      debugPrintStack(stackTrace: s);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to export PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  pw.Widget _buildPDFStatItem(String label, String value, PdfColor color) {
    // Use predefined light colors instead of trying to modify the color
    PdfColor backgroundColor;

    // Choose a light background based on the main color
    if (color == PdfColors.blue) {
      backgroundColor = PdfColors.blue50;
    } else if (color == PdfColors.orange) {
      backgroundColor = PdfColors.orange50;
    } else if (color == PdfColors.green) {
      backgroundColor = PdfColors.green50;
    } else if (color == PdfColors.red) {
      backgroundColor = PdfColors.red50;
    } else {
      backgroundColor = PdfColors.grey200; // Default light gray
    }

    return pw.Column(
      children: [
        pw.Container(
          width: 40,
          height: 40,
          decoration: pw.BoxDecoration(
            color: backgroundColor, // Use predefined light color
            shape: pw.BoxShape.circle,
          ),
          child: pw.Center(
            child: pw.Text(
              value,
              style: pw.TextStyle(
                color: color,
                fontWeight: pw.FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 10),
        ),
      ],
    );
  }

  Future<void> _printReport() async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) => [
            pw.Text(
              'Applications Report for ${widget.studentName}',
              style:  pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 20),
            pw.Table.fromTextArray(
              border: pw.TableBorder.all(),
              headers: ['Title', 'Company', 'Status', 'Date'], // Added headers parameter
              data: _filteredApplications.map((app) => [
                app.internship.title ?? 'N/A',
                app.internship.company.name ?? 'N/A',
                app.applicationStatus,
                DateFormat('MMM dd, yyyy').format(app.applicationDate),
              ]).toList(),
            ),
          ],
        ),
      );

      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to print: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Alternative CSV conversion without ListToCsvConverter
  String _convertToCSV(List<List<dynamic>> rows) {
    String csv = '';
    for (var row in rows) {
      csv += row.map((cell) {
        String cellStr = cell.toString();
        // Escape quotes and wrap in quotes if contains comma or newline
        if (cellStr.contains(',') || cellStr.contains('\n') || cellStr.contains('"')) {
          cellStr = '"${cellStr.replaceAll('"', '""')}"';
        }
        return cellStr;
      }).join(',') + '\n';
    }
    return csv;
  }
}