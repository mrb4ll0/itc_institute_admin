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
  List<String>? imageUrls;

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
    this.imageUrls
  });

  factory Message.fromMap(Map<String, dynamic> map, String documentId) {
    // Handle both single image and multiple images
    List<String>? imageUrls;

    if (map['imageUrls'] != null) {
      imageUrls = List<String>.from(map['imageUrls']);
    } else if (map['imageUrl'] != null) {
      // Convert single imageUrl to list for backward compatibility
      imageUrls = [map['imageUrl'] as String];
    }

    return Message(
      id: documentId,
      senderId: map['sender_id'] ?? map['senderId'] ?? '',
      receiverId: map['receiver_id'] ?? map['receiverId'] ?? '',
      content: map['content'] ?? '',
      timestamp: map['timestamp'] ?? Timestamp.now(),
      isRead: map['is_read'] ?? false,
      imageUrl: map['imageUrl'], // Keep for backward compatibility
      replyTo: map['replyTo'],
      deletedFor: map['deletedFor'] != null ? List<String>.from(map['deletedFor']) : null,
      imageUrls: imageUrls, // Use the processed list
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
      'imageUrls': imageUrls
    };
  }
}
