import 'package:cloud_firestore/cloud_firestore.dart';

import 'comments_model.dart';

class TweetModel {
  final String id;
  final String userId;
  final String user;
  final String content;
  final DateTime timestamp;
  final List<Comment> comments;
  final List<dynamic> likes;
  final List<dynamic> shares;
  bool? lock = false;

  TweetModel({
    this.lock,
    required this.shares,
    required this.id,
    required this.userId,
    required this.user,
    required this.content,
    required this.timestamp,
    required this.likes,
    required this.comments,
  });

  factory TweetModel.fromMap(
    Map<String, dynamic> map,
    String id, {
    List<Comment>? comments,
  }) {
    final likesRaw = map['likes'];
    final sharesRaw = map['shares'];

    List<dynamic> likesList = likesRaw is List ? likesRaw : [];
    List<dynamic> sharesList = sharesRaw is List ? sharesRaw : [];

    return TweetModel(
      shares: sharesList,
      id: id,
      userId: map['userId'] ?? '',
      user: map['user'] ?? 'Anonymous',
      content: map['content'] ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      likes: likesList,
      comments: comments ?? [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'user': user,
      'content': content,
      'timestamp': Timestamp.fromDate(timestamp),
      'likes': likes,
      'comments': comments.map((c) => c.toMap()).toList(),
      'shares': shares,
    };
  }
}
