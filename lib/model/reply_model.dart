import 'package:cloud_firestore/cloud_firestore.dart';

class Reply {
  final String studentId; // ID of the student who posted the reply
  final String commentId; // Unique ID for the reply
  final String tweetId;   // The tweet this reply belongs to
  final String content;   // The actual reply text
  final DateTime postedAt; // When the reply was posted
  final List<String> likes;        // Number of likes for this reply
  final List<String> shares;       // Number of shares for this reply
  final String? id;
  final List<String> mentions;

  Reply({
    this.mentions = const[],
    this.id,
    required this.studentId,
    required this.commentId,
    required this.tweetId,
    required this.content,
    required this.postedAt,
    this.likes = const[],
    this.shares = const[],
  });

  // Convert a Reply object into a Map (for Firestore)
  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'commentId': commentId,
      'tweetId': tweetId,
      'content': content,
      'postedAt': postedAt.toUtc(),
      'likes': likes,
      'shares': shares,
      'id':id,
      'mentions': mentions
    };
  }

  factory Reply.fromMap(Map<String, dynamic> map, String replyId) {
    return Reply(
      studentId: map['studentId'] ?? '',
      commentId: map['commentId'],
      tweetId: map['tweetId'] ?? '',
      content: map['content'] ?? '',
      postedAt: (map['postedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likes: (map['likes'] as List?)?.cast<String>()??[] ,
      shares: (map['shares'] as List?)?.cast<String>()??[],
      id: replyId,
      mentions: (map['mentions'] as List?)?.cast<String>()??[]
    );
  }

  /// CopyWith method
  Reply copyWith({
    String? studentId,
    String? commentId,
    String? tweetId,
    String? content,
    DateTime? postedAt,
    List<String>? likes,
    List<String>? shares,
    String? id,
    List<String> mentions = const[]
  }) {
    return Reply(
      studentId: studentId ?? this.studentId,
      commentId: commentId ?? this.commentId,
      tweetId: tweetId ?? this.tweetId,
      content: content ?? this.content,
      postedAt: postedAt ?? this.postedAt,
      likes: likes ?? List<String>.from(this.likes),
      shares: shares ?? List<String>.from(this.shares),
      id: id ?? this.id,
      mentions: mentions
    );
  }
}
