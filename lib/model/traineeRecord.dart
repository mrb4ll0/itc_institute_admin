// models/trainee_record.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum TraineeStatus {
  pending,      // Application pending
  accepted,     // Application accepted but not started
  active,       // Currently in training
  completed,    // Training completed successfully
  terminated,   // Training terminated early
  withdrawn,    // Student withdrew
  rejected,
}

extension TraineeStatusExtension on TraineeStatus {
  String get name {
    switch (this) {
      case TraineeStatus.pending: return 'pending';
      case TraineeStatus.accepted: return 'accepted';
      case TraineeStatus.active: return 'active';
      case TraineeStatus.completed: return 'completed';
      case TraineeStatus.terminated: return 'terminated';
      case TraineeStatus.withdrawn: return 'withdrawn';
      case TraineeStatus.rejected: return 'rejected';
    }
  }

  String get displayName {
    switch (this) {
      case TraineeStatus.pending: return 'Pending';
      case TraineeStatus.accepted: return 'Accepted';
      case TraineeStatus.active: return 'Active';
      case TraineeStatus.completed: return 'Completed';
      case TraineeStatus.terminated: return 'Terminated';
      case TraineeStatus.withdrawn: return 'Withdrawn';
      case TraineeStatus.rejected: return 'rejected';
    }
  }

  Color get color {
    switch (this) {
      case TraineeStatus.pending: return Colors.orange;
      case TraineeStatus.accepted: return Colors.blue;
      case TraineeStatus.active: return Colors.green;
      case TraineeStatus.completed: return Colors.purple;
      case TraineeStatus.terminated: return Colors.red;
      case TraineeStatus.withdrawn: return Colors.grey;
      case TraineeStatus.rejected: return Colors.red;
    }
  }

  IconData get icon {
    switch (this) {
      case TraineeStatus.pending: return Icons.pending;
      case TraineeStatus.accepted: return Icons.check_circle;
      case TraineeStatus.active: return Icons.work;
      case TraineeStatus.completed: return Icons.verified;
      case TraineeStatus.terminated: return Icons.cancel;
      case TraineeStatus.withdrawn: return Icons.person_remove;
      case TraineeStatus.rejected: return Icons.cancel;
    }
  }
}

class TraineeRecord {
  final String id;
  final String studentId;
  final String studentName;
  final String companyId;
  final String companyName;
  final String applicationId;
  final TraineeStatus status;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? actualStartDate;
  final DateTime? actualEndDate;
  final List<String> supervisorIds;
  final String department;
  final String role;
  final String description;
  final Map<String, dynamic> requirements;
  final List<Map<String, dynamic>> milestones;
  final List<Map<String, dynamic>> evaluations;
  final double progress; // 0-100
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String imageUrl;
  final Map<String,dynamic> notes;

  TraineeRecord({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.companyId,
    required this.companyName,
    required this.applicationId,
    required this.status,
    this.startDate,
    this.endDate,
    this.actualStartDate,
    this.actualEndDate,
    this.supervisorIds = const [],
    this.department = '',
    this.role = '',
    this.description = '',
    this.requirements = const {},
    this.milestones = const [],
    this.evaluations = const [],
    this.progress = 0.0,
    this.metadata = const {},
    required this.createdAt,
    required this.updatedAt,
    required this.imageUrl,
    required this.notes
  });

  // Helper methods
  bool get isActive => status == TraineeStatus.active;
  bool get isUpcoming => status == TraineeStatus.accepted;
  bool get isCompleted => status == TraineeStatus.completed;
  bool get canStart => status == TraineeStatus.accepted;

  int? get durationInDays {
    if (startDate == null || endDate == null) return null;
    return endDate!.difference(startDate!).inDays;
  }

  int? get daysRemaining {
    if (!isActive || actualStartDate == null || endDate == null) return null;
    final now = DateTime.now();
    if (now.isAfter(endDate!)) return 0;
    return endDate!.difference(now).inDays;
  }

  int? get daysElapsed {
    if (!isActive || actualStartDate == null) return null;
    return DateTime.now().difference(actualStartDate!).inDays;
  }

  factory TraineeRecord.fromFirestore(Map<String, dynamic> data, String id) {
    return TraineeRecord(
      id: id,
      studentId: data['studentId'] ?? '',
      studentName: data['studentName'] ?? '',
      companyId: data['companyId'] ?? '',
      companyName: data['companyName'] ?? '',
      applicationId: data['applicationId'] ?? '',
      status: _parseTraineeStatus(data['status']),
      startDate: _parseDateTime(data['startDate']),
      endDate: _parseDateTime(data['endDate']),
      actualStartDate: _parseDateTime(data['actualStartDate']),
      actualEndDate: _parseDateTime(data['actualEndDate']),
      supervisorIds: List<String>.from(data['supervisorIds'] ?? []),
      department: data['department'] ?? '',
      role: data['role'] ?? '',
      description: data['description'] ?? '',
      requirements: Map<String, dynamic>.from(data['requirements'] ?? {}),
      milestones: List<Map<String, dynamic>>.from(data['milestones'] ?? []),
      evaluations: List<Map<String, dynamic>>.from(data['evaluations'] ?? []),
      progress: (data['progress'] ?? 0.0).toDouble(),
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
      createdAt: _parseDateTime(data['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDateTime(data['updatedAt']) ?? DateTime.now(),
      imageUrl: data["imageUrl"]??"",
      notes: data["notes"] is Map<String, dynamic>
          ? Map<String, dynamic>.from(data["notes"])
          : {},
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'studentName': studentName,
      'companyId': companyId,
      'companyName': companyName,
      'applicationId': applicationId,
      'status': status.name,
      'startDate': startDate,
      'endDate': endDate,
      'actualStartDate': actualStartDate,
      'actualEndDate': actualEndDate,
      'supervisorIds': supervisorIds,
      'department': department,
      'role': role,
      'description': description,
      'requirements': requirements,
      'milestones': milestones,
      'evaluations': evaluations,
      'progress': progress,
      'metadata': metadata,
      'createdAt': createdAt,
      'updatedAt': FieldValue.serverTimestamp(),
      'imageUrl': imageUrl,
      'notes': notes
    };
  }

  static TraineeStatus _parseTraineeStatus(dynamic value) {
    if (value == null) return TraineeStatus.pending;
    final str = value.toString().toLowerCase();
    switch (str) {
      case 'active': return TraineeStatus.active;
      case 'accepted': return TraineeStatus.accepted;
      case 'completed': return TraineeStatus.completed;
      case 'terminated': return TraineeStatus.terminated;
      case 'withdrawn': return TraineeStatus.withdrawn;
      case 'rejected': return TraineeStatus.rejected;
      default: return TraineeStatus.pending;
    }
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  TraineeRecord copyWith({
    String? studentId,
    String? studentName,
    String? companyId,
    String? companyName,
    String? applicationId,
    TraineeStatus? status,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? actualStartDate,
    DateTime? actualEndDate,
    List<String>? supervisorIds,
    String? department,
    String? role,
    String? description,
    Map<String, dynamic>? requirements,
    List<Map<String, dynamic>>? milestones,
    List<Map<String, dynamic>>? evaluations,
    double? progress,
    Map<String, dynamic>? metadata,
    imageUrl,
    notes
  }) {
    return TraineeRecord(
      id: id,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      companyId: companyId ?? this.companyId,
      companyName: companyName ?? this.companyName,
      applicationId: applicationId ?? this.applicationId,
      status: status ?? this.status,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      actualStartDate: actualStartDate ?? this.actualStartDate,
      actualEndDate: actualEndDate ?? this.actualEndDate,
      supervisorIds: supervisorIds ?? this.supervisorIds,
      department: department ?? this.department,
      role: role ?? this.role,
      description: description ?? this.description,
      requirements: requirements ?? this.requirements,
      milestones: milestones ?? this.milestones,
      evaluations: evaluations ?? this.evaluations,
      progress: progress ?? this.progress,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      imageUrl: imageUrl??this.imageUrl,
      notes:notes
    );
  }

  // Status update methods
  TraineeRecord markAsAccepted({DateTime? newStartDate, DateTime? newEndDate}) {
    return copyWith(
      status: TraineeStatus.accepted,
      startDate: newStartDate ?? startDate,
      endDate: newEndDate ?? endDate,
    );
  }

  TraineeRecord markAsActive({DateTime? actualStart}) {
    return copyWith(
      status: TraineeStatus.active,
      actualStartDate: actualStart ?? DateTime.now(),
    );
  }

  TraineeRecord markAsCompleted({DateTime? actualEnd}) {
    return copyWith(
      status: TraineeStatus.completed,
      actualEndDate: actualEnd ?? DateTime.now(),
      progress: 100.0,
    );
  }

  TraineeRecord updateProgress(double newProgress) {
    return copyWith(
      progress: newProgress.clamp(0.0, 100.0),
    );
  }

  TraineeRecord addSupervisor(String supervisorId) {
    final newSupervisors = List<String>.from(supervisorIds)..add(supervisorId);
    return copyWith(supervisorIds: newSupervisors);
  }

  TraineeRecord removeSupervisor(String supervisorId) {
    final newSupervisors = List<String>.from(supervisorIds)
      ..remove(supervisorId);
    return copyWith(supervisorIds: newSupervisors);
  }

  TraineeRecord addMilestone(Map<String, dynamic> milestone) {
    final newMilestones = List<Map<String, dynamic>>.from(milestones)
      ..add(milestone);
    return copyWith(milestones: newMilestones);
  }

  TraineeRecord addEvaluation(Map<String, dynamic> evaluation) {
    final newEvaluations = List<Map<String, dynamic>>.from(evaluations)
      ..add(evaluation);
    return copyWith(evaluations: newEvaluations);
  }


}

extension TraineeDateStatus on TraineeRecord {
  /// Calculate what the status should be based on dates
  TraineeStatus get calculatedStatusFromDates {
    final now = DateTime.now();
    // If already in final state, don't recalculate
    if (status == TraineeStatus.completed ||
        status == TraineeStatus.terminated ||
        status == TraineeStatus.withdrawn ||
        status == TraineeStatus.rejected) {
      return status;
    }

    // If actual end date exists, it's done
    if (actualEndDate != null) {
      return TraineeStatus.completed;
    }

    // If actively training
    if (actualStartDate != null) {
      // Check if past planned end date - capture in local variable first
      final plannedEndDate = endDate;
      if (plannedEndDate != null && now.isAfter(plannedEndDate)) {
        return TraineeStatus.completed;
      }
      return TraineeStatus.active;
    }

    // Not started yet - check planned dates - capture in local variable first
    final plannedStartDate = startDate;
    if (plannedStartDate != null) {
      if (now.isBefore(plannedStartDate)) {
        return TraineeStatus.accepted;
      } else {
        // Start date passed but not started
        return TraineeStatus.accepted;
      }
    }

    return status;
  }

  /// Check if status is out of sync with dates
  bool get needsStatusUpdate {
    return calculatedStatusFromDates != status;
  }

  /// Get a human-readable description of the status based on dates
  String get statusDescription {
    final calculated = calculatedStatusFromDates;

    if (calculated != status) {
      return 'Should be ${calculated.displayName} (currently ${status.displayName})';
    }

    switch (calculated) {
      case TraineeStatus.accepted:
        if (startDate != null) {
          final daysUntil = startDate!.difference(DateTime.now()).inDays;
          if (daysUntil > 0) {
            return 'Starts in $daysUntil days';
          } else if (daysUntil == 0) {
            return 'Starts today';
          }
        }
        return 'Accepted, waiting to start';

      case TraineeStatus.active:
        if (actualStartDate != null) {
          final daysActive = DateTime.now().difference(actualStartDate!).inDays;
          return 'Active for $daysActive days';
        }
        return 'Currently active';

      case TraineeStatus.completed:
        if (actualEndDate != null) {
          return 'Completed on ${_formatDate(actualEndDate)}';
        }
        return 'Training completed';

      case TraineeStatus.terminated:
        return 'Terminated';
      case TraineeStatus.withdrawn:
        return 'Withdrawn';
      case TraineeStatus.pending:
        return 'Pending';
      case TraineeStatus.rejected:
        return 'Rejected';
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'unknown date';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}