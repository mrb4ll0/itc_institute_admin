// What type of rule is this?
enum RuleCategory {
  STUDENT_MANAGEMENT, // Accept / reject students
  APPROVAL_FLOW,      // Who approves what
  OPERATIONAL,        // Day-to-day placement operations
  COMPLIANCE,         // School / IT policy compliance
  REPORTING, COMPANY_RELATIONSHIP,          // Reporting to authority
}

// How is the rule enforced?
enum RuleType {
  PERMISSION_BASED,        // Company must request approval
  AUTO_APPROVED,           // Allowed automatically
  PROHIBITED,              // Not allowed at all
  CONDITIONAL,             // Allowed if conditions are met
  QUOTA_BASED,             // Limited number of students
  MANDATORY,               // Must follow (e.g. must respond in 7 days)
}

// How permission is granted
enum PermissionType {
  MANUAL_APPROVAL,                  // Authority approves acceptance
  AUTO_APPROVAL_IF_CONDITIONS_MET,  // GPA, department match, etc.
  TIME_BASED_AUTO_APPROVAL,         // Auto-approve after X days
  TIERED_APPROVAL,                  // Authority + School approval
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
  BLOCK_ACTION,           // Block acceptance/rejection
  ISSUE_WARNING,          // Warn company
  SUSPEND_OPERATIONS,     // Temporarily stop placements
  TERMINATE_RELATIONSHIP, // Remove company from authority
}

enum StudentDecisionPolicy {
  COMPANY_DECIDES,
  AUTHORITY_DECIDES,
  JOINT_DECISION,
  AUTO_MATCH_SYSTEM,
}

class ResponseTimeRule {
  final int maxDays;
  final bool autoApproveIfNoResponse;
  final bool autoRejectIfNoResponse;

  ResponseTimeRule({required this.maxDays,required this.autoApproveIfNoResponse,required this.autoRejectIfNoResponse});
}

class PlacementLimitRule {
  final int maxStudentsPerCompany;
  final int maxStudentsPerCycle;
  final bool allowExceedWithApproval;

  PlacementLimitRule({required this.maxStudentsPerCompany, required this.maxStudentsPerCycle,required this.allowExceedWithApproval});
}

class AuthorityOverrideRule {
  final bool authorityCanOverrideCompanyDecision;
  final String reasonRequired;

  AuthorityOverrideRule({required this.authorityCanOverrideCompanyDecision, required this.reasonRequired});
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
  SUSPENSION,
  BLACKLIST, // Cannot apply again for X time
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