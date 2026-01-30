// What type of rule is this?
enum RuleCategory {
  // RELATIONSHIP RULES
  COMPANY_RELATIONSHIP, // Can company accept authority? Can they leave?
  HIERARCHY, // Sub-authorities, parent-child relationships

  // OPERATIONAL RULES
  OPERATIONAL, // Day-to-day operations
  FINANCIAL, // Financial transactions, fees, payments
  REPORTING, // Reports, disclosures
  COMPLIANCE, // Regulatory compliance

  // SPECIFIC PERMISSIONS
  EXPANSION, // Opening new branches, expanding operations
  PERSONNEL, // Hiring key personnel, CEO changes
  ASSETS, // Buying/selling major assets
  CONTRACTS, // Entering major contracts
  INVESTMENT, // Major investments, loans
  TECHNOLOGY, // Adopting new technologies
  MARKETING, // Advertising, promotions

  // SAFETY & QUALITY
  SAFETY, // Safety standards, certifications
  QUALITY, // Quality control, standards
  ENVIRONMENTAL, // Environmental compliance

  // DATA & PRIVACY
  DATA_PRIVACY, // Data handling, GDPR
  CYBER_SECURITY, // Security measures

  // EMERGENCY
  EMERGENCY, // Emergency procedures
  CONTINGENCY, // Contingency plans
}

// How is the rule enforced?
enum RuleType {
  PERMISSION_BASED, // Requires explicit permission
  NOTIFICATION_BASED, // Just notify authority
  AUTO_APPROVED, // Automatically allowed if conditions met
  PROHIBITED, // Completely forbidden
  CONDITIONAL, // Allowed with conditions
  QUOTA_BASED, MANDATORY, // Limited number allowed
}

// How permission is granted
enum PermissionType {
  MANUAL_APPROVAL, // Authority must manually approve
  AUTO_APPROVAL_IF_CONDITIONS_MET, // Auto-approved if conditions met
  DELEGATED_TO_SUPERVISOR, // Supervisor can approve
  TIME_BASED_AUTO_APPROVAL, // Auto-approved after X days if no objection
  TIERED_APPROVAL, // Multiple levels of approval needed
}

// How compliance is checked
enum ComplianceCheck {
  MANUAL_REVIEW, // Authority reviews manually
  DOCUMENT_SUBMISSION, // Company submits documents
  AUTOMATED_VALIDATION, // System validates automatically
  THIRD_PARTY_VERIFICATION, // Third party verifies
  SITE_INSPECTION, // Physical inspection required
  SELF_CERTIFICATION, // Company self-certifies
}

// What happens if violated
enum EnforcementAction {
  BLOCK_ACTION, // Prevent the action
  REQUIRE_REMEDIATION, // Allow but require fix
  ISSUE_WARNING, // Just issue warning
  IMPOSE_PENALTY, // Apply penalty
  SUSPEND_OPERATIONS, // Suspend operations
  TERMINATE_RELATIONSHIP, // Remove from authority
  ESCALATE_TO_HIGHER_AUTHORITY, // Escalate to parent authority
}

// Conditions for auto-permission
class PermissionCondition {
  final String field; // e.g., "employeeCount", "revenue"
  final dynamic value; // Expected value
  final ConditionOperator operator; // e.g., ">=", "==", "contains"
  final String description;

  PermissionCondition({
    required this.field,
    required this.value,
    required this.operator,
    required this.description,
  });

  Map<String, dynamic> toMap() {
    return {
      'field': field,
      'value': value,
      'operator': operator.name,
      'description': description,
    };
  }

  factory PermissionCondition.fromMap(Map<String, dynamic> map) {
    return PermissionCondition(
      field: map['field'] as String,
      value: map['value'],
      operator: ConditionOperator.values.firstWhere(
            (e) => e.name == map['operator'],
        orElse: () => ConditionOperator.EQUALS,
      ),
      description: map['description'] as String,
    );
  }
}

enum ConditionOperator {
  EQUALS,
  NOT_EQUALS,
  GREATER_THAN,
  GREATER_THAN_OR_EQUAL,
  LESS_THAN,
  LESS_THAN_OR_EQUAL,
  CONTAINS,
  NOT_CONTAINS,
  STARTS_WITH,
  ENDS_WITH,
  IN_LIST,
  NOT_IN_LIST,
}

// Penalty for violation
class Penalty {
  final PenaltyType type;
  final double? amount;
  final int? suspensionDays;
  final String description;
  final bool isRecurring; // Does penalty recur if not fixed?
  final int? recurrenceDays;

  Penalty({
    required this.type,
    this.amount,
    this.suspensionDays,
    required this.description,
    this.isRecurring = false,
    this.recurrenceDays,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'amount': amount,
      'suspensionDays': suspensionDays,
      'description': description,
      'isRecurring': isRecurring,
      'recurrenceDays': recurrenceDays,
    };
  }

  factory Penalty.fromMap(Map<String, dynamic> map) {
    return Penalty(
      type: PenaltyType.values.firstWhere(
            (e) => e.name == map['type'],
        orElse: () => PenaltyType.WARNING,
      ),
      amount: (map['amount'] as num?)?.toDouble(),
      suspensionDays: (map['suspensionDays'] as num?)?.toInt(),
      description: map['description'] as String,
      isRecurring: map['isRecurring'] as bool? ?? false,
      recurrenceDays: (map['recurrenceDays'] as num?)?.toInt(),
    );
  }
}

enum PenaltyType {
  WARNING,
  FINE,
  SUSPENSION,
  DEMOTION, // Lower authority level
  BLACKLIST, // Cannot apply again for X time
  LEGAL_ACTION,
}

// Track rule amendments
class RuleAmendment {
  final DateTime amendmentDate;
  final String amendedBy;
  final String changeDescription;
  final Map<String, dynamic> previousVersion;
  final Map<String, dynamic> newVersion;

  RuleAmendment({
    required this.amendmentDate,
    required this.amendedBy,
    required this.changeDescription,
    required this.previousVersion,
    required this.newVersion,
  });

  Map<String, dynamic> toMap() {
    return {
      'amendmentDate': amendmentDate.toIso8601String(),
      'amendedBy': amendedBy,
      'changeDescription': changeDescription,
      'previousVersion': previousVersion,
      'newVersion': newVersion,
    };
  }

  factory RuleAmendment.fromMap(Map<String, dynamic> map) {
    return RuleAmendment(
      amendmentDate: DateTime.parse(map['amendmentDate'] as String),
      amendedBy: map['amendedBy'] as String,
      changeDescription: map['changeDescription'] as String,
      previousVersion: Map<String, dynamic>.from(map['previousVersion']),
      newVersion: Map<String, dynamic>.from(map['newVersion']),
    );
  }
}