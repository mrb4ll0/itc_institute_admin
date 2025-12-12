import 'package:cloud_firestore/cloud_firestore.dart';

import 'company.dart';

class IndustrialTraining {
  final String? id;
  final String title;
  final String industry;
  final Map<String, dynamic>? duration;
  final DateTime? startDate;
  final DateTime? endDate;
  final String description;
  int applicationsCount;
  String status;
  final String? stipend;
  final bool stipendAvailable;
  final String eligibilityCriteria;
  final String? postedBy;
  final DateTime? postedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  late Company company;
  final List<dynamic>? files;

  // New fields from your training data
  final String department;
  final String location;
  final String requiredSkills;
  final bool aptitudeTestRequired;
  final int intake;
  final String contactPerson;
  final List<String> attachmentUrls;
  final String companyId;
  final String companyName;
  final String? companyLogoUrl;
  final bool isTemplate;
  final bool isUniversalForm;
  final List<String> applications;
  final List<String> acceptedApplications;
  final int viewCount;
  final int applicationCount;
  final Timestamp createdAtTimestamp;
  final Timestamp updatedAtTimestamp;

  IndustrialTraining({
    this.files,
    this.id,
    required this.company,
    required this.title,
    required this.industry,
    required this.duration,
    this.startDate,
    this.endDate,
    required this.description,
    required this.applicationsCount,
    required this.status,
    this.stipend,
    required this.stipendAvailable,
    required this.eligibilityCriteria,
    this.postedBy,
    this.postedAt,
    this.createdAt,
    this.updatedAt,

    // New fields with defaults
    this.department = '',
    this.location = '',
    this.requiredSkills = '',
    this.aptitudeTestRequired = false,
    this.intake = 0,
    this.contactPerson = '',
    this.attachmentUrls = const [],
    this.companyId = '',
    this.companyName = '',
    this.companyLogoUrl,
    this.isTemplate = false,
    this.isUniversalForm = false,
    this.applications = const [],
    this.acceptedApplications = const [],
    this.viewCount = 0,
    this.applicationCount = 0,
    Timestamp? createdAtTimestamp,
    Timestamp? updatedAtTimestamp,
  }) : createdAtTimestamp = createdAtTimestamp ?? Timestamp.now(),
       updatedAtTimestamp = updatedAtTimestamp ?? Timestamp.now();

  // Enhanced factory constructor
  factory IndustrialTraining.fromMap(Map<String, dynamic> data, String docId) {
    // Handle duration field conversion
    Map<String, dynamic>? durationMap;
    if (data['duration'] is Map<String, dynamic>) {
      durationMap = Map<String, dynamic>.from(data['duration']);
    } else if (data['duration'] is String) {
      durationMap = {'value': data['duration'], 'unit': 'months'};
    }

    // Handle company data - either full Company object or just fields
    Company company;

    company = Company.fromMap(data['company']);

    // Convert lists if they exist
    List<dynamic> filesList = [];
    if (data['files'] is List) {
      filesList = List<dynamic>.from(data['files']);
    } else if (data['attachmentUrls'] is List) {
      filesList = List<dynamic>.from(data['attachmentUrls']);
    }

    List<String> applicationsList = [];
    if (data['applications'] is List) {
      applicationsList = List<String>.from(data['applications']);
    }

    List<String> acceptedApplicationsList = [];
    if (data['acceptedApplications'] is List) {
      acceptedApplicationsList = List<String>.from(
        data['acceptedApplications'],
      );
    }

    return IndustrialTraining(
      files: filesList,
      id: docId,
      company: company,
      title: data['title'] ?? '',
      industry: data['industry'] ?? data['department'] ?? '',
      duration: durationMap,
      startDate: (data['startDate'] as Timestamp?)?.toDate(),
      endDate: (data['endDate'] as Timestamp?)?.toDate(),
      description: data['description'] ?? '',
      applicationsCount:
          data['applicationsCount'] ?? data['applicationCount'] ?? 0,
      status: data['status'] ?? 'open',
      stipend: data['stipend'] ?? '',
      stipendAvailable: data['stipendAvailable'] ?? false,
      eligibilityCriteria:
          data['eligibilityCriteria'] ?? data['requiredSkills'] ?? '',
      postedBy: data['postedBy'] ?? data['contactPerson'],
      postedAt: (data['postedAt'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),

      // New fields
      department: data['department'] ?? '',
      location: data['location'] ?? '',
      requiredSkills:
          data['requiredSkills'] ?? data['eligibilityCriteria'] ?? '',
      aptitudeTestRequired: data['aptitudeTestRequired'] ?? false,
      intake: data['intake'] ?? data['intakeCapacity'] ?? 0,
      contactPerson: data['contactPerson'] ?? data['postedBy'] ?? '',
      attachmentUrls: List<String>.from(data['attachmentUrls'] ?? []),
      companyId: data['companyId'] ?? company.id,
      companyName: data['companyName'] ?? company.name,
      companyLogoUrl: data['companyLogoUrl'] ?? company.logoURL,
      isTemplate: data['isTemplate'] ?? false,
      isUniversalForm: data['isUniversalForm'] ?? false,
      applications: applicationsList,
      acceptedApplications: acceptedApplicationsList,
      viewCount: data['viewCount'] ?? 0,
      applicationCount:
          data['applicationCount'] ?? data['applicationsCount'] ?? 0,
      createdAtTimestamp: data['createdAt'] ?? Timestamp.now(),
      updatedAtTimestamp: data['updatedAt'] ?? Timestamp.now(),
    );
  }

  // Factory constructor for Firestore with options
  factory IndustrialTraining.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? options,
  ) {
    return IndustrialTraining.fromMap(snapshot.data() ?? {}, snapshot.id);
  }

  // Enhanced toMap method
  Map<String, dynamic> toMap() {
    return {
      'files': files,
      'company': company.toMap(),
      'title': title,
      'industry': industry,
      'duration': duration,
      'startDate': startDate,
      'endDate': endDate,
      'description': description,
      'applicationsCount': applicationsCount,
      'status': status,
      'stipend': stipend,
      'stipendAvailable': stipendAvailable,
      'eligibilityCriteria': eligibilityCriteria,
      'postedBy': postedBy,
      'postedAt': postedAt,
      'createdAt': createdAt,
      'updatedAt': updatedAt,

      // New fields
      'department': department,
      'location': location,
      'requiredSkills': requiredSkills,
      'aptitudeTestRequired': aptitudeTestRequired,
      'intake': intake,
      'contactPerson': contactPerson,
      'attachmentUrls': attachmentUrls,
      'companyId': companyId,
      'companyName': companyName,
      if (companyLogoUrl != null) 'companyLogoUrl': companyLogoUrl,
      'isTemplate': isTemplate,
      'isUniversalForm': isUniversalForm,
      'applications': applications,
      'acceptedApplications': acceptedApplications,
      'viewCount': viewCount,
      'applicationCount': applicationCount,
      'createdAt': createdAtTimestamp,
      'updatedAt': updatedAtTimestamp,
    };
  }

  // Convert to Firestore format
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'industry': industry,
      'duration': duration,
      'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'description': description,
      'applicationsCount': applicationsCount,
      'status': status,
      'stipend': stipend,
      'stipendAvailable': stipendAvailable,
      'eligibilityCriteria': eligibilityCriteria,
      'postedBy': postedBy,
      'postedAt': postedAt != null ? Timestamp.fromDate(postedAt!) : null,
      'createdAt': createdAtTimestamp,
      'updatedAt': updatedAtTimestamp,

      // New fields
      'department': department,
      'location': location,
      'requiredSkills': requiredSkills,
      'aptitudeTestRequired': aptitudeTestRequired,
      'intake': intake,
      'contactPerson': contactPerson,
      'attachmentUrls': attachmentUrls,
      'companyId': companyId,
      'companyName': companyName,
      if (companyLogoUrl != null) 'companyLogoUrl': companyLogoUrl,
      'isTemplate': isTemplate,
      'isUniversalForm': isUniversalForm,
      'applications': applications,
      'acceptedApplications': acceptedApplications,
      'viewCount': viewCount,
      'applicationCount': applicationCount,
      'company': company.toMap(),
    };
  }

  // Copy with method for updates
  IndustrialTraining copyWith({
    List<dynamic>? files,
    String? id,
    Company? company,
    String? title,
    String? industry,
    Map<String, dynamic>? duration,
    DateTime? startDate,
    DateTime? endDate,
    String? description,
    int? applicationsCount,
    String? status,
    String? stipend,
    String? stipendAvailable,
    String? eligibilityCriteria,
    String? postedBy,
    DateTime? postedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? department,
    String? location,
    String? requiredSkills,
    bool? aptitudeTestRequired,
    int? intake,
    String? contactPerson,
    List<String>? attachmentUrls,
    String? companyId,
    String? companyName,
    String? companyLogoUrl,
    bool? isTemplate,
    bool? isUniversalForm,
    List<String>? applications,
    List<String>? acceptedApplications,
    int? viewCount,
    int? applicationCount,
    Timestamp? createdAtTimestamp,
    Timestamp? updatedAtTimestamp,
  }) {
    return IndustrialTraining(
      files: files ?? this.files,
      id: id ?? this.id,
      company: company ?? this.company,
      title: title ?? this.title,
      industry: industry ?? this.industry,
      duration: duration ?? this.duration,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      description: description ?? this.description,
      applicationsCount: applicationsCount ?? this.applicationsCount,
      status: status ?? this.status,
      stipend: stipend ?? this.stipend,
      stipendAvailable: stipendAvailable != null && stipendAvailable == true,
      eligibilityCriteria: eligibilityCriteria ?? this.eligibilityCriteria,
      postedBy: postedBy ?? this.postedBy,
      postedAt: postedAt ?? this.postedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      department: department ?? this.department,
      location: location ?? this.location,
      requiredSkills: requiredSkills ?? this.requiredSkills,
      aptitudeTestRequired: aptitudeTestRequired ?? this.aptitudeTestRequired,
      intake: intake ?? this.intake,
      contactPerson: contactPerson ?? this.contactPerson,
      attachmentUrls: attachmentUrls ?? this.attachmentUrls,
      companyId: companyId ?? this.companyId,
      companyName: companyName ?? this.companyName,
      companyLogoUrl: companyLogoUrl ?? this.companyLogoUrl,
      isTemplate: isTemplate ?? this.isTemplate,
      isUniversalForm: isUniversalForm ?? this.isUniversalForm,
      applications: applications ?? this.applications,
      acceptedApplications: acceptedApplications ?? this.acceptedApplications,
      viewCount: viewCount ?? this.viewCount,
      applicationCount: applicationCount ?? this.applicationCount,
      createdAtTimestamp: createdAtTimestamp ?? this.createdAtTimestamp,
      updatedAtTimestamp: updatedAtTimestamp ?? this.updatedAtTimestamp,
    );
  }

  // Factory method to create from form data
  factory IndustrialTraining.fromFormData({
    required String title,
    required String department,
    required String location,
    required String description,
    required String requiredSkills,
    required bool aptitudeTestRequired,
    required int intake,
    required String stipend,
    required String status,
    required String contactPerson,
    required List<String> attachmentUrls,
    required String companyId,
    required String companyName,
    required Company company,
    String? companyLogoUrl,
    bool isTemplate = false,
    bool isUniversalForm = false,
    String? industry,
    Map<String, dynamic>? duration,
    String? eligibilityCriteria,
  }) {
    return IndustrialTraining(
      title: title,
      department: department,
      location: location,
      description: description,
      requiredSkills: requiredSkills,
      aptitudeTestRequired: aptitudeTestRequired,
      intake: intake,
      stipend: stipend,
      status: status,
      contactPerson: contactPerson,
      attachmentUrls: attachmentUrls,
      companyId: companyId,
      companyName: companyName,
      companyLogoUrl: companyLogoUrl,
      isTemplate: isTemplate,
      isUniversalForm: isUniversalForm,
      company: company,
      industry: industry ?? department,
      eligibilityCriteria: eligibilityCriteria ?? requiredSkills,
      stipendAvailable: stipend != null && stipend.isNotEmpty ? true : false,
      applicationsCount: 0,
      createdAtTimestamp: Timestamp.now(),
      updatedAtTimestamp: Timestamp.now(),
      duration: {},
    );
  }

  // Helper methods
  bool get isOpen => status.toLowerCase() == 'open';
  bool get isClosed => status.toLowerCase() == 'closed';

  String get formattedStartDate => startDate != null
      ? '${startDate!.day}/${startDate!.month}/${startDate!.year}'
      : 'Not specified';

  String get formattedEndDate => endDate != null
      ? '${endDate!.day}/${endDate!.month}/${endDate!.year}'
      : 'Not specified';

  String get durationText {
    if (duration != null && duration!.isNotEmpty) {
      return '${duration!['value']} ${duration!['unit']}';
    }
    return 'Not specified';
  }
}
