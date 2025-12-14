import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../../../model/comments_model.dart';

String anonymousWithUid(String? userId) {
  if (userId == null || userId.isEmpty) return 'Anonymous';
  final len = userId.length;
  if (len <= 6) return 'Anonymous';
  final start = (len / 2 - 3).floor();
  return 'Anonymous_' + userId.substring(start, start + 6);
}

class TweetModel {
  final String id;
  final String userId;
  final String user;
  final String content;
  final DateTime timestamp;
  final DateTime createdAt;
  final List<Comment> comments;
  final List<dynamic> likes;
  final List<dynamic> shares;
  final bool? lock;
  final bool? isPinned;
  final int? viewCount;
  final String? imageUrl;
  final List<String>? hashtags;
  final String? replyToId;
  final bool? isRetweet;
  final String? originalTweetId;
  final String? originalUserId;
  final TweetUserType? userType;

  TweetModel({
    required this.id,
    required this.userId,
    required this.user,
    required this.content,
    required this.timestamp,
    required this.likes,
    required this.comments,
    required this.shares,
    this.lock = false,
    this.isPinned = false,
    required this.createdAt,
    this.viewCount = 0,
    this.imageUrl,
    this.hashtags,
    this.replyToId,
    this.isRetweet = false,
    this.originalTweetId,
    this.originalUserId,
    this.userType,
  });

  // Getters for calculated properties
  int get commentCount => comments.length;
  int get likeCount => likes.length;
  int get shareCount => shares.length;

  bool get isLiked {
    final currentUser = FirebaseAuth.instance.currentUser;
    return currentUser != null && likes.contains(currentUser.uid);
  }

  bool get isShared {
    final currentUser = FirebaseAuth.instance.currentUser;
    return currentUser != null && shares.contains(currentUser.uid);
  }

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return '$years year${years > 1 ? 's' : ''} ago';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '$months month${months > 1 ? 's' : ''} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    }
    return 'Just now';
  }

  String get formattedDate {
    return DateFormat('MMM dd, yyyy • hh:mm a').format(timestamp);
  }

  String get shortDate {
    return DateFormat('MMM dd').format(timestamp);
  }

  factory TweetModel.fromMap(
    Map<String, dynamic> map,
    String id, {
    List<Comment>? comments,
  }) {
    final likesRaw = map['likes'] ?? [];
    final sharesRaw = map['shares'] ?? [];
    final hashtagsRaw = map['hashtags'] ?? [];

    // Parse timestamps
    DateTime timestamp;
    if (map['timestamp'] is Timestamp) {
      timestamp = (map['timestamp'] as Timestamp).toDate();
    } else if (map['timestamp'] is String) {
      timestamp = DateTime.parse(map['timestamp']);
    } else if (map['timestamp'] is DateTime) {
      timestamp = map['timestamp'];
    } else {
      timestamp = DateTime.now();
    }

    DateTime createdAt = DateTime.now();
    if (map['createdAt'] != null) {
      if (map['createdAt'] is Timestamp) {
        createdAt = (map['createdAt'] as Timestamp).toDate();
      } else if (map['createdAt'] is String) {
        createdAt = DateTime.parse(map['createdAt']);
      } else if (map['createdAt'] is DateTime) {
        createdAt = map['createdAt'];
      }
    }

    return TweetModel(
      id: id,
      userId: map['userId']?.toString() ?? '',
      user:
          map['user']?.toString() ??
          anonymousWithUid(map['userId']?.toString()),
      content: map['content']?.toString() ?? '',
      timestamp: timestamp,
      createdAt: createdAt,
      likes: likesRaw is List ? likesRaw : [],
      shares: sharesRaw is List ? sharesRaw : [],
      comments: comments ?? [],
      lock: map['lock'] as bool? ?? false,
      isPinned: map['isPinned'] as bool? ?? false,
      viewCount: (map['viewCount'] as num?)?.toInt() ?? 0,
      imageUrl: map['imageUrl']?.toString(),
      hashtags: hashtagsRaw is List
          ? hashtagsRaw.map((e) => e.toString()).toList()
          : null,
      replyToId: map['replyToId']?.toString(),
      isRetweet: map['isRetweet'] as bool? ?? false,
      originalTweetId: map['originalTweetId']?.toString(),
      originalUserId: map['originalUserId']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'user': user,
      'content': content,
      'timestamp': Timestamp.fromDate(timestamp),
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      'likes': likes,
      'shares': shares,
      'comments': comments.map((c) => c.toMap()).toList(),
      'lock': lock,
      'isPinned': isPinned,
      'viewCount': viewCount,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (hashtags != null && hashtags!.isNotEmpty) 'hashtags': hashtags,
      if (replyToId != null) 'replyToId': replyToId,
      'isRetweet': isRetweet,
      if (originalTweetId != null) 'originalTweetId': originalTweetId,
      if (originalUserId != null) 'originalUserId': originalUserId,
    };
  }

  // Copy with method for updates
  TweetModel copyWith({
    String? id,
    String? userId,
    String? user,
    String? content,
    DateTime? timestamp,
    DateTime? createdAt,
    List<Comment>? comments,
    List<dynamic>? likes,
    List<dynamic>? shares,
    bool? lock,
    bool? isPinned,
    int? viewCount,
    String? imageUrl,
    List<String>? hashtags,
    String? replyToId,
    bool? isRetweet,
    String? originalTweetId,
    String? originalUserId,
  }) {
    return TweetModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      user: user ?? this.user,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      createdAt: createdAt ?? this.createdAt,
      likes: likes ?? this.likes,
      shares: shares ?? this.shares,
      comments: comments ?? this.comments,
      lock: lock ?? this.lock,
      isPinned: isPinned ?? this.isPinned,
      viewCount: viewCount ?? this.viewCount,
      imageUrl: imageUrl ?? this.imageUrl,
      hashtags: hashtags ?? this.hashtags,
      replyToId: replyToId ?? this.replyToId,
      isRetweet: isRetweet ?? this.isRetweet,
      originalTweetId: originalTweetId ?? this.originalTweetId,
      originalUserId: originalUserId ?? this.originalUserId,
    );
  }

  // Toggle like for current user
  TweetModel toggleLike(String userId) {
    final newLikes = List<dynamic>.from(likes);
    if (newLikes.contains(userId)) {
      newLikes.remove(userId);
    } else {
      newLikes.add(userId);
    }
    return copyWith(likes: newLikes);
  }

  // Toggle share for current user
  TweetModel toggleShare(String userId) {
    final newShares = List<dynamic>.from(shares);
    if (newShares.contains(userId)) {
      newShares.remove(userId);
    } else {
      newShares.add(userId);
    }
    return copyWith(shares: newShares);
  }

  // Add comment
  TweetModel addComment(Comment comment) {
    final newComments = List<Comment>.from(comments)..add(comment);
    return copyWith(comments: newComments);
  }

  // Remove comment
  TweetModel removeComment(String commentId) {
    final newComments = comments.where((c) => c.id != commentId).toList();
    return copyWith(comments: newComments);
  }

  // Increment view count
  TweetModel incrementViewCount() {
    return copyWith(viewCount: (viewCount ?? 0) + 1);
  }

  // Toggle pin status
  TweetModel togglePin() {
    return copyWith(isPinned: !(isPinned ?? false));
  }

  // Toggle lock status
  TweetModel toggleLock() {
    return copyWith(lock: !(lock ?? false));
  }

  // Check if tweet is locked
  bool get isLocked => lock ?? false;

  // Check if tweet is pinned
  bool get isPinnedStatus => isPinned ?? false;

  // Check if tweet is a reply
  bool get isReply => replyToId != null && replyToId!.isNotEmpty;

  // Check if tweet contains hashtags
  bool get hasHashtags => hashtags != null && hashtags!.isNotEmpty;

  // Get formatted hashtags string
  String get formattedHashtags {
    if (!hasHashtags) return '';
    return hashtags!.map((h) => '#$h').join(' ');
  }

  @override
  String toString() {
    return 'TweetModel(id: $id, user: $user, content: ${content.length > 50 ? '${content.substring(0, 50)}...' : content}, likes: $likeCount, comments: $commentCount, shares: $shareCount, timeAgo: $timeAgo)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is TweetModel &&
        other.id == id &&
        other.userId == userId &&
        other.user == user &&
        other.content == content &&
        other.timestamp == timestamp &&
        listEquals(other.likes, likes) &&
        listEquals(other.shares, shares) &&
        listEquals(other.comments, comments);
  }

  @override
  int get hashCode {
    return id.hashCode ^
        userId.hashCode ^
        user.hashCode ^
        content.hashCode ^
        timestamp.hashCode ^
        likes.hashCode ^
        shares.hashCode ^
        comments.hashCode;
  }
}

// Extension for list operations
extension TweetListExtensions on List<TweetModel> {
  List<TweetModel> get pinnedTweets =>
      where((tweet) => tweet.isPinnedStatus).toList();

  List<TweetModel> get regularTweets =>
      where((tweet) => !tweet.isPinnedStatus).toList();

  List<TweetModel> get sortedByDate =>
      [...this]..sort((a, b) => b.timestamp.compareTo(a.timestamp));

  List<TweetModel> get sortedByPopularity => [...this]
    ..sort((a, b) {
      final aScore = a.likeCount + a.commentCount * 2 + a.shareCount * 3;
      final bScore = b.likeCount + b.commentCount * 2 + b.shareCount * 3;
      return bScore.compareTo(aScore);
    });

  List<TweetModel> getUserTweets(String userId) =>
      where((tweet) => tweet.userId == userId).toList();

  List<TweetModel> getLikedTweets(String userId) =>
      where((tweet) => tweet.likes.contains(userId)).toList();
}

enum TweetUserType { student, company }
