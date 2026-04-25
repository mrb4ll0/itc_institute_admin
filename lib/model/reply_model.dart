import 'package:cloud_firestore/cloud_firestore.dart';


class Reply {
  final String studentId; // ID of the student who posted the reply
  final String commentId; // ID of the parent comment
  final String tweetId; // The tweet this reply belongs to
  final String content; // The actual reply text
  final DateTime postedAt; // When the reply was posted
  List<String> likes; // Users who liked this reply
  final List<String> shares; // Users who shared this reply
  final String? id;
  final List<String> mentions;
  final String?
  parentReplyId; // ID of parent reply for nested replies (null if direct comment reply)
  final List<Reply> replies; // List of sub-replies (nested replies)
  final String? userReplyingTo; // Username of the person being replied to
  final String? mentionedUserId; // User ID of mentioned person

  Reply({
    this.mentions = const [],
    this.id,
    required this.studentId,
    required this.commentId,
    required this.tweetId,
    required this.content,
    required this.postedAt,
    this.likes = const [],
    this.shares = const [],
    this.parentReplyId,
    this.replies = const [],
    this.userReplyingTo,
    this.mentionedUserId,
  });

  // Check if this is a top-level reply (directly under comment)
  bool get isTopLevelReply => parentReplyId == null;

  // Check if this is a nested reply (reply to another reply)
  bool get isNestedReply => parentReplyId != null;

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
      'id': id,
      'mentions': mentions,
      'parentReplyId': parentReplyId,
      'userReplyingTo': userReplyingTo,
      'mentionedUserId': mentionedUserId,
      'hasReplies': replies.isNotEmpty, // Flag for easy filtering
    };
  }

  factory Reply.fromMap(Map<String, dynamic> map, String replyId) {
    return Reply(
      studentId: map['studentId'] ?? '',
      commentId: map['commentId'] ?? '',
      tweetId: map['tweetId'] ?? '',
      content: map['content'] ?? '',
      postedAt: (map['postedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likes: (map['likes'] as List?)?.cast<String>() ?? [],
      shares: (map['shares'] as List?)?.cast<String>() ?? [],
      id: replyId,
      mentions: (map['mentions'] as List?)?.cast<String>() ?? [],
      parentReplyId: map['parentReplyId'],
      userReplyingTo: map['userReplyingTo'],
      mentionedUserId: map['mentionedUserId'],
      // Note: Replies are fetched separately, not from the map
    );
  }

  // Factory method for creating a reply from Firestore with nested replies
  // In reply_model.dart, add this factory method
  factory Reply.fromFirestoreWithNested(
      DocumentSnapshot doc,
      List<Reply> nestedReplies,
      ) {
    final data = doc.data() as Map<String, dynamic>;
    return Reply(
      studentId: data['studentId'] ?? '',
      commentId: data['commentId'] ?? '',
      tweetId: data['tweetId'] ?? '',
      content: data['content'] ?? '',
      postedAt: (data['postedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likes: (data['likes'] as List?)?.cast<String>() ?? [],
      shares: (data['shares'] as List?)?.cast<String>() ?? [],
      id: doc.id,
      mentions: (data['mentions'] as List?)?.cast<String>() ?? [],
      parentReplyId: data['parentReplyId'],
      userReplyingTo: data['userReplyingTo'],
      mentionedUserId: data['mentionedUserId'],
      replies: nestedReplies, // This is key - attach nested replies
    );
  }
  // Factory method for creating a reply to another reply (nested)
  factory Reply.createNestedReply({
    required String studentId,
    required String commentId,
    required String tweetId,
    required String content,
    required String parentReplyId,
    String? userReplyingTo,
    String? mentionedUserId,
    List<String> mentions = const [],
  }) {
    return Reply(
      studentId: studentId,
      commentId: commentId,
      tweetId: tweetId,
      content: content,
      postedAt: DateTime.now(),
      parentReplyId: parentReplyId,
      userReplyingTo: userReplyingTo,
      mentionedUserId: mentionedUserId,
      mentions: mentions,
    );
  }

  // Factory method for creating a direct reply to a comment
  factory Reply.createDirectReply({
    required String studentId,
    required String commentId,
    required String tweetId,
    required String content,
    String? userReplyingTo,
    String? mentionedUserId,
    List<String> mentions = const [],
  }) {
    return Reply(
      studentId: studentId,
      commentId: commentId,
      tweetId: tweetId,
      content: content,
      postedAt: DateTime.now(),
      parentReplyId: null, // Direct reply to comment
      userReplyingTo: userReplyingTo,
      mentionedUserId: mentionedUserId,
      mentions: mentions,
    );
  }

  /// CopyWith method with all properties
  Reply copyWith({
    String? studentId,
    String? commentId,
    String? tweetId,
    String? content,
    DateTime? postedAt,
    List<String>? likes,
    List<String>? shares,
    String? id,
    List<String>? mentions,
    String? parentReplyId,
    List<Reply>? replies,
    String? userReplyingTo,
    String? mentionedUserId,
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
      mentions: mentions ?? List<String>.from(this.mentions),
      parentReplyId: parentReplyId ?? this.parentReplyId,
      replies: replies ?? List<Reply>.from(this.replies),
      userReplyingTo: userReplyingTo ?? this.userReplyingTo,
      mentionedUserId: mentionedUserId ?? this.mentionedUserId,
    );
  }

  /// Add a sub-reply to this reply
  Reply addSubReply(Reply subReply) {
    return copyWith(
      replies: [...replies, subReply],
    );
  }

  /// Remove a sub-reply by ID
  Reply removeSubReply(String replyId) {
    return copyWith(
      replies: replies.where((reply) => reply.id != replyId).toList(),
    );
  }

  /// Update a sub-reply
  Reply updateSubReply(String replyId, Reply updatedReply) {
    return copyWith(
      replies: replies.map((reply) {
        return reply.id == replyId ? updatedReply : reply;
      }).toList(),
    );
  }

  /// Toggle like for this reply
  Reply toggleLike(String userId) {
    if (likes.contains(userId)) {
      return copyWith(
        likes: List<String>.from(likes)..remove(userId),
      );
    } else {
      return copyWith(
        likes: List<String>.from(likes)..add(userId),
      );
    }
  }

  /// Get display content with mentions highlighted
  String get displayContent {
    if (userReplyingTo != null && mentionedUserId != null) {
      return '@$userReplyingTo $content';
    }
    return content;
  }

  /// Get mentioned user information
  Map<String, String>? get mentionedUser {
    if (userReplyingTo != null && mentionedUserId != null) {
      return {
        'userId': mentionedUserId!,
        'username': userReplyingTo!,
      };
    }
    return null;
  }

  /// Check if user has liked this reply
  bool hasUserLiked(String userId) {
    return likes.contains(userId);
  }

  /// Get formatted timestamp
  String get formattedTime {
    final now = DateTime.now();
    final difference = now.difference(postedAt);

    if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }

  /// Get all reply IDs in the hierarchy (including nested)
  List<String> getAllReplyIds() {
    final ids = <String>[];
    if (id != null) ids.add(id!);
    for (final reply in replies) {
      ids.addAll(reply.getAllReplyIds());
    }
    return ids;
  }

  /// Get depth level (0 for top-level, 1 for first nested, etc.)
  int getDepthLevel() {
    if (parentReplyId == null) return 0;
    // This would need parent information to calculate actual depth
    // For now, we can assume 1 for nested replies
    return 1;
  }

  /// Check if this reply mentions a specific user
  bool mentionsUser(String userId) {
    return mentionedUserId == userId || mentions.contains(userId);
  }

  /// Get all mentioned user IDs
  List<String> getAllMentionedUserIds() {
    final mentionedIds = <String>[];
    if (mentionedUserId != null) mentionedIds.add(mentionedUserId!);
    mentionedIds.addAll(mentions);
    return mentionedIds;
  }
}

// Helper class for managing reply hierarchies
class ReplyTree {
  final Map<String, Reply> repliesById = {};
  final Map<String, List<String>> childrenByParentId = {};

  void addReply(Reply reply) {
    repliesById[reply.id!] = reply;

    final parentId = reply.parentReplyId ?? reply.commentId;
    childrenByParentId.putIfAbsent(parentId, () => []).add(reply.id!);
  }

  List<Reply> getTopLevelReplies(String commentId) {
    final topLevelIds = childrenByParentId[commentId] ?? [];
    return topLevelIds.map((id) => repliesById[id]!).toList();
  }

  List<Reply> getNestedReplies(String parentReplyId) {
    final nestedIds = childrenByParentId[parentReplyId] ?? [];
    return nestedIds.map((id) => repliesById[id]!).toList();
  }

  Reply? getReply(String replyId) {
    return repliesById[replyId];
  }

  void removeReply(String replyId) {
    final reply = repliesById[replyId];
    if (reply == null) return;

    // Remove from parent's children list
    final parentId = reply.parentReplyId ?? reply.commentId;
    childrenByParentId[parentId]?.remove(replyId);

    // Remove all nested replies recursively
    final nestedIds = childrenByParentId[replyId] ?? [];
    for (final nestedId in nestedIds) {
      removeReply(nestedId);
    }

    // Remove the reply itself
    repliesById.remove(replyId);
    childrenByParentId.remove(replyId);
  }

  // Build a hierarchical structure
  List<Reply> buildHierarchy(String commentId) {
    final topLevelReplies = getTopLevelReplies(commentId);

    for (final reply in topLevelReplies) {
      _attachNestedReplies(reply);
    }

    return topLevelReplies;
  }

  void _attachNestedReplies(Reply parentReply) {
    final nestedReplies = getNestedReplies(parentReply.id!);
    parentReply = parentReply.copyWith(replies: nestedReplies);

    for (final reply in nestedReplies) {
      _attachNestedReplies(reply);
    }
  }
}
