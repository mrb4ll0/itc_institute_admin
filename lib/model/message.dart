import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String? id; // 🔥 Add this
  final String senderId;
  final String receiverId;
   String content;
  final Timestamp timestamp;
  final bool isRead;
  String? imageUrl;
  Map<String, dynamic>? replyTo;
  List<String>? deletedFor;

  Message({
     this.id, // 🔥 Include in constructor
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.timestamp,
    required this.isRead,
    this.imageUrl,
    this.replyTo,
    this.deletedFor,
  });

  factory Message.fromMap(Map<String, dynamic> map, String documentId) {
    return Message(
      id: documentId, // 🔥 Assign document ID here
      senderId: map['sender_id'] ?? map['senderId'] ?? '',
      receiverId: map['receiver_id'] ?? map['receiverId'] ?? '',
      content: map['content'] ?? '',
      timestamp: map['timestamp'] ?? Timestamp.now(),
      isRead: map['is_read'] ?? false,
      imageUrl: map['imageUrl'],
      replyTo: map['replyTo'],
      deletedFor: map['deletedFor'] != null ? List<String>.from(map['deletedFor']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sender_id': senderId,
      'receiver_id': receiverId,
      'content': content,
      'timestamp': timestamp,
      'is_read': isRead,
      'imageUrl' : imageUrl,
      'replyTo': replyTo,
      if (deletedFor != null) 'deletedFor': deletedFor,
    };
  }
}
