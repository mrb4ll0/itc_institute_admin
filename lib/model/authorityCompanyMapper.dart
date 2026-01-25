import 'dart:math';
import 'authority.dart';
import 'company.dart';

class AuthorityCompanyMapper {
  /// Creates a Company from an Authority with the FULL Authority embedded
  static Company createCompanyWithEmbeddedAuthority({
    required Authority authority,
    String? customCompanyName,
    String? customIndustry,
    String? customRole = 'company',
    bool embedFullAuthority = true, // Set to true to embed full authority
  }) {
    return Company(
      // Core identifying properties
      id: authority.id,
      name: customCompanyName ?? authority.name,
      industry: customIndustry ?? (authority.description ?? 'Government Services'),

      // Contact information
      email: authority.email,
      phoneNumber: authority.phoneNumber ?? '',

      // Location information
      logoURL: authority.logoURL ?? '',
      localGovernment: authority.localGovernment ?? '',
      state: authority.state ?? '',
      address: authority.address ?? '',

      // Business information
      role: customRole ?? 'company',
      registrationNumber: authority.registrationNumber ??
          _generateConversionRegistrationNumber(authority.name),
      description: authority.description ??
          'Converted from ${authority.name} government authority',

      // Conversion tracking WITH FULL AUTHORITY
      wasAuthority: true,
      originalAuthorityId: authority.id,
      convertedAt: DateTime.now(),
      originalAuthority: embedFullAuthority ? authority : null, // EMBED HERE

      // Status flags
      isfeatured: false,
      isActive: true,
      isVerified: authority.isVerified,
      isApproved: true,
      isPending: false,
      isBlocked: false,
      isDeleted: false,
      isRejected: false,
      isSuspended: false,
      isBanned: false,
      isMuted: false,

      // Authority relationship
      isUnderAuthority: false,
      authorityId: null,
      authorityName: null,
      authorityLinkStatus: 'NONE',

      // Communication
      fcmToken: authority.fcmToken,

      // Transfer relationships
      supervisors: [...authority.supervisors, ...authority.admins],
      potentialtrainee: authority.linkedCompanies,

      // Initialize empty lists
      pendingApplications: [],
      acceptedTrainees: [],
      currentTrainees: [],
      completedTrainees: [],
      rejectedApplications: [],

      // Other fields
      forms: null,
      updatedAt: DateTime.now(),
      isMutedUntil: null,
      isMutedBy: null,
      isMutedFor: null,
      isMutedOn: null,
    );
  }

  /// Creates a Company from an Authority (without embedding full authority)
  static Company createCompanyFromAuthority({
    required Authority authority,
    String? customCompanyName,
    String? customIndustry,
    String? customRole,
    bool markAsConverted = true,
  }) {
    return Company(
      // Core identifying properties
      id: authority.id,
      name: customCompanyName ?? authority.name,
      industry: customIndustry ?? (authority.description ?? 'Government Services'),

      // Contact information (common with Authority)
      email: authority.email,
      phoneNumber: authority.phoneNumber ?? '',

      // Location information (common with Authority)
      logoURL: authority.logoURL ?? '',
      localGovernment: authority.localGovernment ?? '',
      state: authority.state ?? '',
      address: authority.address ?? '',

      // Business information
      role: customRole ?? 'company',
      registrationNumber: authority.registrationNumber ??
          _generateConversionRegistrationNumber(authority.name),
      description: authority.description ??
          'Converted from ${authority.name} government authority',

      // Conversion tracking
      wasAuthority: markAsConverted,
      originalAuthorityId: markAsConverted ? authority.id : null,
      convertedAt: markAsConverted ? DateTime.now() : null,
      originalAuthority: authority, // Not embedding full authority in this method

      // Status flags (with appropriate defaults)
      isfeatured: false,
      isActive: true,
      isVerified: authority.isVerified,
      isApproved: true, // Auto-approve converted authorities
      isPending: false,
      isBlocked: false,
      isDeleted: false,
      isRejected: false,
      isSuspended: false,
      isBanned: false,
      isMuted: false,

      // Authority relationship (none for converted authorities)
      isUnderAuthority: false,
      authorityId: null,
      authorityName: null,
      authorityLinkStatus: 'NONE',

      // Communication
      fcmToken: authority.fcmToken,

      // Transfer personnel relationships
      supervisors: [...authority.supervisors, ...authority.admins],

      // Transfer linked companies as potential trainees
      potentialtrainee: authority.linkedCompanies,

      // Initialize empty lists for company-specific data
      pendingApplications: [],
      acceptedTrainees: [],
      currentTrainees: [],
      completedTrainees: [],
      rejectedApplications: [],

      // Forms and documents (initialize as empty)
      forms: null,

      // Timestamps
      updatedAt: DateTime.now(),

      // Nullable fields
      isMutedUntil: null,
      isMutedBy: null,
      isMutedFor: null,
      isMutedOn: null,
    );
  }

  /// Creates an updated Authority with conversion metadata
  static Authority markAuthorityAsConverted({
    required Authority authority,
    required String userId,
    String? companyId,
    bool archive = true,
  }) {
    // Since your copyWith method doesn't include the conversion fields,
    // we need to create a new Authority with updated conversion fields

    return Authority(
      id: authority.id,
      name: authority.name,
      email: authority.email,
      contactPerson: authority.contactPerson,
      phoneNumber: authority.phoneNumber,
      logoURL: authority.logoURL,
      address: authority.address,
      state: authority.state,
      localGovernment: authority.localGovernment,
      registrationNumber: authority.registrationNumber,
      description: authority.description,
      isActive: !archive, // Deactivate if archived
      isVerified: authority.isVerified,
      isApproved: authority.isApproved,
      isBlocked: authority.isBlocked,
      createdAt: authority.createdAt,
      updatedAt: DateTime.now(),
      linkedCompanies: authority.linkedCompanies,
      pendingApplications: authority.pendingApplications,
      approvedApplications: authority.approvedApplications,
      rejectedApplications: authority.rejectedApplications,
      admins: authority.admins,
      supervisors: authority.supervisors,
      fcmToken: authority.fcmToken,
      notificationTokens: authority.notificationTokens,
      autoApproveAfterAuthority: authority.autoApproveAfterAuthority,
      maxCompaniesAllowed: authority.maxCompaniesAllowed,
      maxApplicationsPerBatch: authority.maxApplicationsPerBatch,
      requirePhysicalLetter: authority.requirePhysicalLetter,
      letterTemplateUrl: authority.letterTemplateUrl,
      totalApplicationsReviewed: authority.totalApplicationsReviewed,
      currentPendingCount: authority.currentPendingCount,
      averageProcessingTimeDays: authority.averageProcessingTimeDays,
      // Conversion fields
      isConvertedToCompany: true,
      convertedToCompanyId: companyId ?? authority.id,
      convertedBy: userId,
      convertedAt: DateTime.now(),
      isArchived: archive,
    );
  }

  /// Generates a unique registration number for converted authorities
  static String _generateConversionRegistrationNumber(String authorityName) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final cleanedName = authorityName.replaceAll(RegExp(r'[^a-zA-Z]'), '');
    final nameCode = cleanedName.isNotEmpty
        ? cleanedName.substring(0, min(3, cleanedName.length)).toUpperCase()
        : 'AUTH';

    return 'AUTH-CONV-$nameCode-$timestamp';
  }

  /// Creates a comprehensive conversion record (in-memory)
  static Map<String, dynamic> createConversionRecord({
    required Authority originalAuthority,
    required Company newCompany,
    required String userId,
    required Authority updatedAuthority,
    String reason = 'Authority converted to Company',
  }) {
    return {
      'id': 'conv_${DateTime.now().millisecondsSinceEpoch}',
      'timestamp': DateTime.now().toIso8601String(),
      'userId': userId,

      // Original data
      'originalAuthority': originalAuthority.toMap(),

      // Updated data
      'updatedAuthority': updatedAuthority.toMap(),
      'newCompany': newCompany.toMap(),

      // Metadata
      'reason': reason,
      'linkedCompaniesTransferred': originalAuthority.linkedCompanies.length,
      'adminsTransferred': originalAuthority.admins.length,
      'supervisorsTransferred': originalAuthority.supervisors.length,

      // Common properties that were mapped
      'mappedProperties': _getCommonProperties(originalAuthority, newCompany),
    };
  }

  /// Gets list of common properties between Authority and Company
  static List<String> _getCommonProperties(Authority authority, Company company) {
    final commonProps = <String>[];

    // Check which properties were directly mapped
    if (authority.name == company.name) commonProps.add('name');
    if (authority.email == company.email) commonProps.add('email');
    if (authority.phoneNumber == company.phoneNumber) commonProps.add('phoneNumber');
    if (authority.logoURL == company.logoURL) commonProps.add('logoURL');
    if (authority.address == company.address) commonProps.add('address');
    if (authority.state == company.state) commonProps.add('state');
    if (authority.localGovernment == company.localGovernment) commonProps.add('localGovernment');
    if (authority.registrationNumber == company.registrationNumber) commonProps.add('registrationNumber');
    if (authority.description == company.description) commonProps.add('description');

    return commonProps;
  }

  /// Extracts only the common/shared properties between Authority and Company models
  static Map<String, dynamic> extractCommonProperties(Authority authority) {
    return {
      // Personal/Contact Info
      'id': authority.id,
      'name': authority.name,
      'email': authority.email,
      'phoneNumber': authority.phoneNumber,
      'contactPerson': authority.contactPerson,

      // Location/Business Info
      'logoURL': authority.logoURL,
      'address': authority.address,
      'state': authority.state,
      'localGovernment': authority.localGovernment,
      'registrationNumber': authority.registrationNumber,
      'description': authority.description,

      // Status
      'isVerified': authority.isVerified,

      // Communication
      'fcmToken': authority.fcmToken,

      // Personnel
      'admins': authority.admins,
      'supervisors': authority.supervisors,

      // Relationships
      'linkedCompanies': authority.linkedCompanies,
    };
  }

  /// Creates a summary of what will be transferred during conversion
  static ConversionSummary analyzeConversion(Authority authority) {
    return ConversionSummary(
      authorityName: authority.name,
      authorityId: authority.id,
      totalProperties: _countTotalProperties(authority),
      commonProperties: _countCommonProperties(authority),
      linkedCompaniesCount: authority.linkedCompanies.length,
      adminsCount: authority.admins.length,
      supervisorsCount: authority.supervisors.length,
      pendingApplicationsCount: authority.pendingApplications.length,
      willBePreserved: true,
      estimatedCompanyData: _estimateCompanyData(authority),
    );
  }

  /// Estimates what the Company data will look like
  static Map<String, dynamic> _estimateCompanyData(Authority authority) {
    final company = createCompanyFromAuthority(authority: authority);
    return {
      'name': company.name,
      'industry': company.industry,
      'email': company.email,
      'role': company.role,
      'willHaveTrainees': company.potentialtrainee.isNotEmpty,
      'willHaveSupervisors': company.supervisors.isNotEmpty,
      'registrationNumber': company.registrationNumber,
    };
  }

  static int _countTotalProperties(Authority authority) {
    // Count non-null properties
    final map = authority.toMap();
    return map.values.where((value) => value != null && value.toString().isNotEmpty).length;
  }

  static int _countCommonProperties(Authority authority) {
    // Properties that exist in both models
    const commonPropertyNames = [
      'id', 'name', 'email', 'phoneNumber', 'logoURL', 'address',
      'state', 'localGovernment', 'registrationNumber', 'description',
      'isVerified', 'fcmToken'
    ];

    final map = authority.toMap();
    return commonPropertyNames
        .where((prop) =>
    map[prop] != null &&
        map[prop].toString().isNotEmpty &&
        map[prop] != false) // Exclude false boolean values
        .length;
  }
}

/// Summary of what will happen during conversion
class ConversionSummary {
  final String authorityName;
  final String authorityId;
  final int totalProperties;
  final int commonProperties;
  final int linkedCompaniesCount;
  final int adminsCount;
  final int supervisorsCount;
  final int pendingApplicationsCount;
  final bool willBePreserved;
  final Map<String, dynamic> estimatedCompanyData;

  ConversionSummary({
    required this.authorityName,
    required this.authorityId,
    required this.totalProperties,
    required this.commonProperties,
    required this.linkedCompaniesCount,
    required this.adminsCount,
    required this.supervisorsCount,
    required this.pendingApplicationsCount,
    required this.willBePreserved,
    required this.estimatedCompanyData,
  });

  double get transferPercentage => totalProperties > 0
      ? (commonProperties / totalProperties) * 100
      : 0.0;

  String get summaryText {
    return '''
Conversion Analysis for "$authorityName":
----------------------------------------
• Total Properties: $totalProperties
• Common Properties to Transfer: $commonProperties (${transferPercentage.toStringAsFixed(1)}%)
• Linked Companies: $linkedCompaniesCount
• Admins: $adminsCount
• Supervisors: $supervisorsCount
• Pending Applications: $pendingApplicationsCount

New Company Will Have:
• Name: ${estimatedCompanyData['name']}
• Industry: ${estimatedCompanyData['industry']}
• Role: ${estimatedCompanyData['role']}
• Trainees: ${estimatedCompanyData['willHaveTrainees'] ? 'Yes' : 'No'}
• Supervisors: ${estimatedCompanyData['willHaveSupervisors'] ? 'Yes' : 'No'}
''';
  }
}