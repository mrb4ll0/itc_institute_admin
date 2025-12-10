import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceRecord {
  String id;
  DateTime date;
  DateTime? checkInTime;
  DateTime? checkOutTime;
  String? notes;
  bool isPresent;

  AttendanceRecord({
    required this.id,
    required this.date,
    this.checkInTime,
    this.checkOutTime,
    this.notes,
    this.isPresent = false,
  });

  factory AttendanceRecord.fromMap(Map<String, dynamic> map) {
    return AttendanceRecord(
      id: map['id'] ?? '',
      date: (map['date'] as Timestamp).toDate(),
      checkInTime: map['checkInTime'] != null
          ? (map['checkInTime'] as Timestamp).toDate()
          : null,
      checkOutTime: map['checkOutTime'] != null
          ? (map['checkOutTime'] as Timestamp).toDate()
          : null,
      notes: map['notes'],
      isPresent: map['isPresent'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': Timestamp.fromDate(date),
      'checkInTime': checkInTime != null
          ? Timestamp.fromDate(checkInTime!)
          : null,
      'checkOutTime': checkOutTime != null
          ? Timestamp.fromDate(checkOutTime!)
          : null,
      'notes': notes,
      'isPresent': isPresent,
    };
  }
}
