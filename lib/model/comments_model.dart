import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:itc_institute_admin/model/reply_model.dart';

class Comment {
  final String? id; // Firestore doc ID for this comment
  final String userId;
  final String user;
  final String content;
  final DateTime timestamp;
  final List<String> likes; // User IDs who liked
  final List<String> shares; // User IDs who shared
  final List<Reply> replies; // Nested replies
  final String tweetId;

  Comment({
    required this.tweetId,
    this.id,
    required this.userId,
    required this.user,
    required this.content,
    required this.timestamp,
    this.likes = const [],
    this.shares = const [],
    this.replies = const [],
  });

  factory Comment.fromMap(
    Map<String, dynamic> map,
    String id,
    List<dynamic>? replies,
    tweetId,
  ) {
    // Defensive mapping
    final likesList = (map['likes'] as List?)?.cast<String>() ?? [];
    final sharesList = (map['shares'] as List?)?.cast<String>() ?? [];

    // Map replies if embedded
    final repliesList =
        replies?.map((e) {
          if (e is Map<String, dynamic>) {
            return Reply.fromMap(e, id);
          } else if (e is Reply) {
            return e;
          } else {
            throw FormatException('Invalid reply type: ${e.runtimeType}');
          }
        }).toList() ??
        [];

    return Comment(
      tweetId: tweetId,
      id: id,
      userId: map['userId'] ?? '',
      user: map['user'] ?? 'Anonymous',
      content: map['content'] ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      likes: likesList,
      shares: sharesList,
      replies: repliesList,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'user': user,
      'content': content,
      'timestamp': Timestamp.fromDate(timestamp),
      'likes': likes,
      'shares': shares,
      'replies': replies.map((r) => r.toMap()).toList(),
      'tweetId': tweetId,
    };
  }
}
