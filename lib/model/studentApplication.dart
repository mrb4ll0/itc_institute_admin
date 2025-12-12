import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:itc_institute_admin/model/student.dart';

import 'internship_model.dart';

class StudentApplication {
  final String id;
  Student student;
  IndustrialTraining internship;
  String applicationStatus;
  DateTime applicationDate;
  // This map will hold startDate, endDate, description, selectedDuration, and durationInDays
  final Map<String, dynamic> durationDetails;
  final String idCardUrl;
  final String itLetterUrl;
  final List<String> attachedFormUrls;

  StudentApplication({
    required this.id,
    required this.applicationDate,
    required this.student,
    required this.internship,
    required this.applicationStatus,
    required this.durationDetails,
    required this.idCardUrl,
    required this.itLetterUrl,
    required this.attachedFormUrls,
  });

  // ============ ADD THESE NEW METHODS ============

  // Get the enum status
  ApplicationStatus get status => applicationStatus.toApplicationStatus();

  // Get display name for UI
  String get statusDisplayName => status.displayName;

  // Get color for UI
  Color get statusColor => status.color;

  // Get icon for UI
  IconData get statusIcon => status.icon;

  // Check status helpers
  bool get isAccepted => applicationStatus.isAccepted;
  bool get isPending => applicationStatus.isPending;
  bool get isRejected => applicationStatus.isRejected;

  // Update status (returns a new instance with updated status)
  StudentApplication withStatus(String newStatus) {
    return copyWith(applicationStatus: newStatus);
  }

  // Update status using ApplicationStatus enum
  StudentApplication withApplicationStatus(ApplicationStatus newStatus) {
    return copyWith(applicationStatus: newStatus.name);
  }

  StudentApplication copyWith({
    String? id,
    Student? student,
    IndustrialTraining? internship,
    String? applicationStatus,
    DateTime? applicationDate,
    Map<String, dynamic>? durationDetails,
    String? idCardUrl,
    String? itLetterUrl,
    List<String>? attachedFormUrls,
  }) {
    return StudentApplication(
      id: id ?? this.id,
      student: student ?? this.student,
      internship: internship ?? this.internship,
      applicationStatus: applicationStatus ?? this.applicationStatus,
      applicationDate: applicationDate ?? this.applicationDate,
      durationDetails: durationDetails ?? this.durationDetails,
      idCardUrl: idCardUrl ?? this.idCardUrl,
      itLetterUrl: itLetterUrl ?? this.itLetterUrl,
      attachedFormUrls: attachedFormUrls ?? this.attachedFormUrls,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'student': student.toMap(),
      'internship': internship.toMap(),
      'applicationStatus': applicationStatus,
      'applicationDate': applicationDate.toIso8601String(),
      'durationDetails': durationDetails,
      'idCardUrl': idCardUrl,
      'itLetterUrl': itLetterUrl,
      'attachedFormUrls': attachedFormUrls,
    };
  }

  factory StudentApplication.fromMap(
    Map<String, dynamic> map,
    String itId,
    String id,
  ) {
    return StudentApplication(
      id: id,
      student: Student.fromMap(map['student'] as Map<String, dynamic>),
      internship: IndustrialTraining.fromMap(
        map['internship'] as Map<String, dynamic>,
        itId,
      ),
      applicationStatus: map['applicationStatus'] as String,
      applicationDate:
          _parseDynamicToDateTime(map['applicationDate']) ?? DateTime.now(),
      durationDetails: map['durationDetails'] as Map<String, dynamic>? ?? {},
      idCardUrl: map['idCardUrl'] as String? ?? '',
      itLetterUrl: map['itLetterUrl'] as String? ?? '',
      attachedFormUrls: List<String>.from(
        map['attachedFormUrls'] as List<dynamic>? ?? [],
      ),
    );
  }

  // Add this helper method to your StudentApplication class
  static DateTime? _parseDynamicToDateTime(dynamic value) {
    if (value == null) return null;

    try {
      // Handle Timestamp
      if (value is Timestamp) {
        return value.toDate();
      }

      // Handle String (ISO format)
      if (value is String) {
        return DateTime.parse(value);
      }

      // Handle DateTime (already a DateTime)
      if (value is DateTime) {
        return value;
      }

      // Handle integer (milliseconds since epoch)
      if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }

      // Try to convert to string and parse
      final stringValue = value.toString();
      return DateTime.parse(stringValue);
    } catch (e) {
      print(
        'Error parsing date: $e, value: $value (type: ${value.runtimeType})',
      );
      return null;
    }
  }

  String toJson() => json.encode(toMap());

  factory StudentApplication.fromJson(String source, String id, String itId) =>
      StudentApplication.fromMap(json.decode(source), id, itId);

  @override
  String toString() {
    return 'StudentApplication(id: $id, student: $student, internship: $internship, applicationStatus: $applicationStatus, applicationDate: $applicationDate, durationDetails: $durationDetails, idCardUrl: $idCardUrl, itLetterUrl: $itLetterUrl, attachedFormUrls: $attachedFormUrls)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is StudentApplication &&
        other.id == id &&
        other.student == student &&
        other.internship == internship &&
        other.applicationStatus == applicationStatus &&
        other.applicationDate == applicationDate &&
        mapEquals(other.durationDetails, durationDetails) &&
        other.idCardUrl == idCardUrl &&
        other.itLetterUrl == itLetterUrl &&
        listEquals(other.attachedFormUrls, attachedFormUrls);
  }

  @override
  int get hashCode {
    return id.hashCode ^
        student.hashCode ^
        internship.hashCode ^
        applicationStatus.hashCode ^
        applicationDate.hashCode ^
        durationDetails.hashCode ^
        idCardUrl.hashCode ^
        itLetterUrl.hashCode ^
        attachedFormUrls.hashCode;
  }
}

enum ApplicationStatus { accepted, pending, rejected }

extension ApplicationStatusExtension on ApplicationStatus {
  String get name {
    switch (this) {
      case ApplicationStatus.accepted:
        return 'accepted';
      case ApplicationStatus.pending:
        return 'pending';
      case ApplicationStatus.rejected:
        return 'rejected';
    }
  }

  String get displayName {
    switch (this) {
      case ApplicationStatus.accepted:
        return 'Accepted';
      case ApplicationStatus.pending:
        return 'Pending';
      case ApplicationStatus.rejected:
        return 'Rejected';
    }
  }

  Color get color {
    switch (this) {
      case ApplicationStatus.accepted:
        return Colors.green;
      case ApplicationStatus.pending:
        return Colors.orange;
      case ApplicationStatus.rejected:
        return Colors.red;
    }
  }

  IconData get icon {
    switch (this) {
      case ApplicationStatus.accepted:
        return Icons.check_circle;
      case ApplicationStatus.pending:
        return Icons.pending;
      case ApplicationStatus.rejected:
        return Icons.cancel;
    }
  }
}

// Enhanced String to Enum conversion
extension StringToApplicationStatus on String {
  ApplicationStatus toApplicationStatus() {
    final normalized = toLowerCase().trim();

    // Handle various input formats
    switch (normalized) {
      case 'accepted':
      case 'accept':
      case 'approved':
        return ApplicationStatus.accepted;

      case 'pending':
      case 'pend':
      case 'waiting':
      case 'in_progress':
        return ApplicationStatus.pending;

      case 'rejected':
      case 'reject':
      case 'declined':
      case 'denied':
        return ApplicationStatus.rejected;

      default:
        return ApplicationStatus.pending; // Default value
    }
  }

  // Helper methods for checking status
  bool get isAccepted => toApplicationStatus() == ApplicationStatus.accepted;
  bool get isPending => toApplicationStatus() == ApplicationStatus.pending;
  bool get isRejected => toApplicationStatus() == ApplicationStatus.rejected;
}
