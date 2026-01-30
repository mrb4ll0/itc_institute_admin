class CompanyPermissionRequest {
  final String id;
  final String companyId;
  final String authorityId;
  final String ruleId;
  final PermissionRequestType requestType;

  // Request details
  final Map<String, dynamic> requestData; // What they want to do
  final String description;
  final List<String> supportingDocuments; // URLs to documents

  // Status
  final PermissionStatus status;
  final DateTime requestDate;
  final DateTime? decisionDate;
  final String? decidedBy; // Admin ID
  final String? decisionNotes;

  // If approved
  final DateTime? approvalValidFrom;
  final DateTime? approvalValidUntil;
  final List<ApprovalCondition>? conditions;

  // If rejected
  final String? rejectionReason;
  final DateTime? canReapplyAfter;

  // Tracking
  final List<PermissionRequestLog> logs;

  CompanyPermissionRequest({
    required this.id,
    required this.companyId,
    required this.authorityId,
    required this.ruleId,
    required this.requestType,
    required this.requestData,
    required this.description,
    this.supportingDocuments = const [],
    this.status = PermissionStatus.PENDING,
    required this.requestDate,
    this.decisionDate,
    this.decidedBy,
    this.decisionNotes,
    this.approvalValidFrom,
    this.approvalValidUntil,
    this.conditions,
    this.rejectionReason,
    this.canReapplyAfter,
    this.logs = const [],
  });

  bool get isExpired {
    if (status != PermissionStatus.APPROVED) return false;
    if (approvalValidUntil == null) return false;
    return DateTime.now().isAfter(approvalValidUntil!);
  }

  bool get canReapply {
    if (status != PermissionStatus.REJECTED) return false;
    if (canReapplyAfter == null) return true;
    return DateTime.now().isAfter(canReapplyAfter!);
  }
}

enum PermissionRequestType {
  NEW_PERMISSION, // Requesting new permission
  RENEWAL, // Renewing expiring permission
  MODIFICATION, // Modifying existing permission
  EXCEPTION, // Requesting exception to rule
  TRANSFER, // Transferring permission to new entity
}

enum PermissionStatus {
  DRAFT,
  PENDING,
  UNDER_REVIEW,
  ADDITIONAL_INFO_NEEDED,
  APPROVED,
  APPROVED_WITH_CONDITIONS,
  REJECTED,
  CANCELLED,
  EXPIRED,
}

class ApprovalCondition {
  final String condition;
  final DateTime? deadline;
  final bool isMet;
  final DateTime? metDate;

  ApprovalCondition({
    required this.condition,
    this.deadline,
    this.isMet = false,
    this.metDate,
  });
}

class PermissionRequestLog {
  final DateTime timestamp;
  final String action;
  final String performedBy;
  final String notes;
  final Map<String, dynamic>? metadata;

  PermissionRequestLog({
    required this.timestamp,
    required this.action,
    required this.performedBy,
    required this.notes,
    this.metadata,
  });
}