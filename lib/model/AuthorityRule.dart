import 'dart:convert';

import 'authorityRuleExtension.dart';

class AuthorityRule {
  final String id;
   String authorityId;
  final String title;
  final String description;
  final RuleCategory category;
  final RuleType type;
  final bool isActive;
  final bool isMandatory; // Must be complied with
  final DateTime effectiveDate;
  final DateTime? expiryDate;

  // PERMISSION CONTROL
  final bool requiresExplicitPermission; // Needs authority approval
  final PermissionType permissionType; // How permission is granted
  final List<PermissionCondition> conditions; // Conditions for auto-permission

  // COMPLIANCE CHECKING
  final ComplianceCheck complianceCheck; // How compliance is verified
  final String? validationLogic; // Custom validation logic
  final List<String> requiredProofs; // Documents/proofs needed

  // ENFORCEMENT
  final EnforcementAction enforcementAction;
  final int gracePeriodDays; // Time to comply after violation
  final Penalty? penalty;
  final String? warningMessage;
  final String? successMessage;

  // APPLICABILITY
  final List<String> applicableCompanyTypes; // e.g., ["LLC", "CORPORATION"]
  final List<String> applicableIndustries; // e.g., ["MANUFACTURING", "CONSTRUCTION"]
  final List<String> applicableCompanySizes; // e.g., ["SMALL", "MEDIUM", "LARGE"]
  final bool applyToAllCompanies; // Overrides above filters if true
  final List<String> applicableCompanyIds; // Specific company IDs

  // TRACKING
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy; // Admin ID
  final int version;
  final List<RuleAmendment> amendments; // History of changes

  AuthorityRule({
    required this.id,
    required this.authorityId,
    required this.title,
    required this.description,
    required this.category,
    required this.type,
    this.isActive = true,
    this.isMandatory = false,
    required this.effectiveDate,
    this.expiryDate,
    required this.applicableCompanyIds,
    // Permission defaults
    this.requiresExplicitPermission = true,
    this.permissionType = PermissionType.MANUAL_APPROVAL,
    this.conditions = const [],

    // Compliance defaults
    this.complianceCheck = ComplianceCheck.MANUAL_REVIEW,
    this.validationLogic,
    this.requiredProofs = const [],

    // Enforcement defaults
    this.enforcementAction = EnforcementAction.BLOCK_ACTION,
    this.gracePeriodDays = 30,
    this.penalty,
    this.warningMessage,
    this.successMessage,

    // Applicability defaults
    this.applicableCompanyTypes = const [],
    this.applicableIndustries = const [],
    this.applicableCompanySizes = const [],
    this.applyToAllCompanies = false,

    // Tracking defaults
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    this.version = 1,
    this.amendments = const [],
  });

  // Check if rule applies to a specific company
  bool appliesToCompany({
    required String companyId,
    required String companyType,
    required String industry,
    required String companySize,
  }) {
    if (applicableCompanyIds.isNotEmpty) {
      return applicableCompanyIds.contains(companyId);
    }
    if (applyToAllCompanies) return true;

    if (applicableCompanyTypes.isNotEmpty &&
        !applicableCompanyTypes.contains(companyType)) {
      return false;
    }

    if (applicableIndustries.isNotEmpty &&
        !applicableIndustries.contains(industry)) {
      return false;
    }

    if (applicableCompanySizes.isNotEmpty &&
        !applicableCompanySizes.contains(companySize)) {
      return false;
    }

    return true;
  }

  // Check if current date is within rule's validity period
  bool get isValidPeriod {
    final now = DateTime.now();
    if (now.isBefore(effectiveDate)) return false;
    if (expiryDate != null && now.isAfter(expiryDate!)) return false;
    return true;
  }

  // Check if rule is currently active and applicable
  bool get isCurrentlyActive {
    return isActive && isValidPeriod;
  }

  // Copy with method
  AuthorityRule copyWith({
    String? id,
    String? authorityId,
    String? title,
    String? description,
    RuleCategory? category,
    RuleType? type,
    bool? isActive,
    bool? isMandatory,
    DateTime? effectiveDate,
    DateTime? expiryDate,
    bool? requiresExplicitPermission,
    PermissionType? permissionType,
    List<PermissionCondition>? conditions,
    ComplianceCheck? complianceCheck,
    String? validationLogic,
    List<String>? requiredProofs,
    EnforcementAction? enforcementAction,
    int? gracePeriodDays,
    Penalty? penalty,
    String? warningMessage,
    String? successMessage,
    List<String>? applicableCompanyTypes,
    List<String>? applicableIndustries,
    List<String>? applicableCompanySizes,
    bool? applyToAllCompanies,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    int? version,
    List<RuleAmendment>? amendments,
    List<String>? applicableCompanyIds
  }) {
    return AuthorityRule(
      id: id ?? this.id,
      authorityId: authorityId ?? this.authorityId,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      type: type ?? this.type,
      isActive: isActive ?? this.isActive,
      isMandatory: isMandatory ?? this.isMandatory,
      effectiveDate: effectiveDate ?? this.effectiveDate,
      expiryDate: expiryDate ?? this.expiryDate,
      requiresExplicitPermission: requiresExplicitPermission ?? this.requiresExplicitPermission,
      permissionType: permissionType ?? this.permissionType,
      conditions: conditions ?? this.conditions,
      complianceCheck: complianceCheck ?? this.complianceCheck,
      validationLogic: validationLogic ?? this.validationLogic,
      requiredProofs: requiredProofs ?? this.requiredProofs,
      enforcementAction: enforcementAction ?? this.enforcementAction,
      gracePeriodDays: gracePeriodDays ?? this.gracePeriodDays,
      penalty: penalty ?? this.penalty,
      warningMessage: warningMessage ?? this.warningMessage,
      successMessage: successMessage ?? this.successMessage,
      applicableCompanyTypes: applicableCompanyTypes ?? this.applicableCompanyTypes,
      applicableIndustries: applicableIndustries ?? this.applicableIndustries,
      applicableCompanySizes: applicableCompanySizes ?? this.applicableCompanySizes,
      applyToAllCompanies: applyToAllCompanies ?? this.applyToAllCompanies,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      version: version != null ? this.version + 1 : this.version,
      amendments: amendments ?? this.amendments,
      applicableCompanyIds: applicableCompanyIds ?? this.applicableCompanyIds,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'authorityId': authorityId,
      'title': title,
      'description': description,
      'category': category.name,
      'type': type.name,
      'isActive': isActive,
      'isMandatory': isMandatory,
      'effectiveDate': effectiveDate.toIso8601String(),
      'expiryDate': expiryDate?.toIso8601String(),
      'requiresExplicitPermission': requiresExplicitPermission,
      'permissionType': permissionType.name,
      'conditions': conditions.map((c) => c.toMap()).toList(),
      'complianceCheck': complianceCheck.name,
      'validationLogic': validationLogic,
      'requiredProofs': requiredProofs,
      'enforcementAction': enforcementAction.name,
      'gracePeriodDays': gracePeriodDays,
      'penalty': penalty?.toMap(),
      'warningMessage': warningMessage,
      'successMessage': successMessage,
      'applicableCompanyTypes': applicableCompanyTypes,
      'applicableIndustries': applicableIndustries,
      'applicableCompanySizes': applicableCompanySizes,
      'applyToAllCompanies': applyToAllCompanies,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'createdBy': createdBy,
      'version': version,
      'amendments': amendments.map((a) => a.toMap()).toList(),
      'applicableCompanyIds': applicableCompanyIds,
    };
  }

  factory AuthorityRule.fromMap(Map<String, dynamic> map) {
    return AuthorityRule(
      id: map['id'] as String,
      authorityId: map['authorityId'] as String,
      title: map['title'] as String,
      description: map['description'] as String,
      category: RuleCategory.values.firstWhere(
            (e) => e.name == map['category'],
        orElse: () => RuleCategory.OPERATIONAL,
      ),
      type: RuleType.values.firstWhere(
            (e) => e.name == map['type'],
        orElse: () => RuleType.PERMISSION_BASED,
      ),
      isActive: map['isActive'] as bool? ?? true,
      isMandatory: map['isMandatory'] as bool? ?? false,
      effectiveDate: DateTime.parse(map['effectiveDate'] as String),
      expiryDate: map['expiryDate'] != null
          ? DateTime.parse(map['expiryDate'] as String)
          : null,
      requiresExplicitPermission: map['requiresExplicitPermission'] as bool? ?? true,
      permissionType: PermissionType.values.firstWhere(
            (e) => e.name == map['permissionType'],
        orElse: () => PermissionType.MANUAL_APPROVAL,
      ),
      conditions: (map['conditions'] as List? ?? [])
          .map((c) => PermissionCondition.fromMap(c))
          .toList(),
      complianceCheck: ComplianceCheck.values.firstWhere(
            (e) => e.name == map['complianceCheck'],
        orElse: () => ComplianceCheck.MANUAL_REVIEW,
      ),
      validationLogic: map['validationLogic'] as String?,
      requiredProofs: List<String>.from(map['requiredProofs'] ?? []),
      enforcementAction: EnforcementAction.values.firstWhere(
            (e) => e.name == map['enforcementAction'],
        orElse: () => EnforcementAction.BLOCK_ACTION,
      ),
      gracePeriodDays: (map['gracePeriodDays'] as num?)?.toInt() ?? 30,
      penalty: map['penalty'] != null
          ? Penalty.fromMap(map['penalty'])
          : null,
      warningMessage: map['warningMessage'] as String?,
      successMessage: map['successMessage'] as String?,
      applicableCompanyTypes: List<String>.from(map['applicableCompanyTypes'] ?? []),
      applicableIndustries: List<String>.from(map['applicableIndustries'] ?? []),
      applicableCompanySizes: List<String>.from(map['applicableCompanySizes'] ?? []),
      applyToAllCompanies: map['applyToAllCompanies'] as bool? ?? false,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      createdBy: map['createdBy'] as String,
      version: (map['version'] as num?)?.toInt() ?? 1,
      amendments: (map['amendments'] as List? ?? [])
          .map((a) => RuleAmendment.fromMap(a))
          .toList(),
      applicableCompanyIds: List<String>.from(map['applicableCompanyIds'] ?? []),
    );
  }

  String toJson() => json.encode(toMap());
  factory AuthorityRule.fromJson(String source) =>
      AuthorityRule.fromMap(json.decode(source));
}