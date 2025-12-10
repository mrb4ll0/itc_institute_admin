import 'package:cloud_firestore/cloud_firestore.dart';

class MeetingRecord {
  String id;
  String title;
  String? description;
  DateTime scheduledTime;
  DateTime? actualTime;
  String location; // 'physical' or 'online' or specific place
  String? meetingLink;
  List<String> attendees; // List of user IDs
  String? agenda;
  String? minutes;
  bool isCompleted;

  MeetingRecord({
    required this.id,
    required this.title,
    this.description,
    required this.scheduledTime,
    this.actualTime,
    required this.location,
    this.meetingLink,
    this.attendees = const [],
    this.agenda,
    this.minutes,
    this.isCompleted = false,
  });

  factory MeetingRecord.fromMap(Map<String, dynamic> map) {
    return MeetingRecord(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'],
      scheduledTime: (map['scheduledTime'] as Timestamp).toDate(),
      actualTime: map['actualTime'] != null
          ? (map['actualTime'] as Timestamp).toDate()
          : null,
      location: map['location'] ?? '',
      meetingLink: map['meetingLink'],
      attendees: List<String>.from(map['attendees'] ?? []),
      agenda: map['agenda'],
      minutes: map['minutes'],
      isCompleted: map['isCompleted'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'scheduledTime': Timestamp.fromDate(scheduledTime),
      'actualTime': actualTime != null ? Timestamp.fromDate(actualTime!) : null,
      'location': location,
      'meetingLink': meetingLink,
      'attendees': attendees,
      'agenda': agenda,
      'minutes': minutes,
      'isCompleted': isCompleted,
    };
  }
}
