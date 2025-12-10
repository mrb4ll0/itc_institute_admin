// lib/model/report.dart

import 'package:cloud_firestore/cloud_firestore.dart';

enum ReportType { scam, fakeListing, inappropriateContent, feedback, other }

class Report {
  final String id;
  final ReportType type;
  final String description;
  final DateTime reportedAt;
  final String reporterId;      // who filed it
  final String targetListingId; // or userId, companyId, etc.
  final Map<String, dynamic> rawData;

  Report({
    required this.id,
    required this.type,
    required this.description,
    required this.reportedAt,
    required this.reporterId,
    required this.targetListingId,
    required this.rawData,
  });

  factory Report.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final typeString = data['type'] as String? ?? 'other';
    late ReportType type;
    switch (typeString) {
      case 'scam':
        type = ReportType.scam;
        break;
      case 'fakeListing':
        type = ReportType.fakeListing;
        break;
      case 'inappropriateContent':
        type = ReportType.inappropriateContent;
        break;
      case 'feedback':
        type = ReportType.feedback;
        break;
      default:
        type = ReportType.other;
    }

    return Report(
      id: doc.id,
      type: type,
      description: data['description'] ?? data['message'] ?? '',
      reportedAt: (data['reportedAt'] ?? data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reporterId: data['reporterId'] as String? ?? '',
      targetListingId: data['targetListingId'] ?? data['reportedUserId'] ?? '',
      rawData: data,
    );
  }


  Map<String, dynamic> toMap() => {
    'type': type.toString().split('.').last,
    'description': description,
    'reportedAt': Timestamp.fromDate(reportedAt),
    'reporterId': reporterId,
    'targetListingId': targetListingId,
    ...rawData,
  };
}
