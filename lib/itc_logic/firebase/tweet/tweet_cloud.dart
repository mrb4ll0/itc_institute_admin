import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:rxdart/rxdart.dart';

import '../../../model/comments_model.dart';
import '../../../model/reply_model.dart';
import '../../../model/student.dart';
import '../../../model/tweetModel.dart';

class TweetService {
  final _tweetCollection = FirebaseFirestore.instance.collection('tweets');
  final _refreshController = StreamController<void>.broadcast();

  Stream<List<TweetModel>> getAllTweets() {
    return _tweetCollection
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map(
                (doc) => TweetModel.fromMap(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              )
              .toList();
        });
  }

  Stream<void> get refreshStream => _refreshController.stream;

  Future<void> toggleLikeTweet(String tweetId, String userId) async {
    final doc = await _tweetCollection.doc(tweetId).get();
    var likesRaw = doc['likes'];
    List<String> likes;
    if (likesRaw is List) {
      likes = List<String>.from(likesRaw);
    } else if (likesRaw is int) {
      likes = <String>[]; // migrate old int to empty list
    } else {
      likes = <String>[];
    }
    if (likes.contains(userId)) {
      likes.remove(userId);
    } else {
      likes.add(userId);
    }
    await _tweetCollection.doc(tweetId).update({'likes': likes});
  }

  Future<void> addToShareList(String tweetId, String userId) async {
    try {
      final docRef = _tweetCollection.doc(tweetId);
      final doc = await docRef.get();

      List<String> shares = [];

      if (doc.exists) {
        // Document exists - get current shares
        final shareRaw = doc.data()?['shares'];
        if (shareRaw is List) {
          shares = List<String>.from(shareRaw.whereType<String>());
        } else if (shareRaw is int) {
          shares = <String>[]; // migrate old int to empty list
        }
      }

      // Add the new user ID if not already present
      if (!shares.contains(userId)) {
        shares.add(userId);
      }

      // Update or create the document
      await docRef.set({
        'shares': shares,
        // Add any other default fields you want to initialize
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error adding to share list: $e');
      rethrow;
    }
  }

  Future<Comment> postComment({
    required String tweetId,
    required Student student,
    required String content,
  }) async {
    final commentData = {
      'userId': student.uid,
      'user': student.fullName,
      'userImage': student.imageUrl,
      'content': content,
      'timestamp': Timestamp.now(),
      'likes': [],
      'locked': false,
    };

    // Firestore will create the comments collection automatically if it doesn't exist
    var docRef = await _tweetCollection
        .doc(tweetId)
        .collection('comments')
        .add(commentData);

    triggerRefresh();
    return Comment.fromMap(commentData, docRef.id, [], tweetId);
  }

  Future<Reply> postReply({
    required String tweetId,
    required String commentId, // ID of the comment being replied to
    String? replyTo, // Optional: ID of another reply for nested replies
    required Student student,
    required String content,
    required String userReplyingTo,
  }) async {
    String finalContent = content;

    if (replyTo != null && replyTo.isNotEmpty) {
      try {
        final replyDoc = await _tweetCollection
            .doc(tweetId)
            .collection('comments')
            .doc(commentId)
            .collection('replies')
            .doc(replyTo)
            .get();

        if (replyDoc.exists) {
          final replyData = replyDoc.data();
          final repliedToUserId = replyData?['userId'] as String?;
          if (repliedToUserId != null && repliedToUserId != student.uid) {
            final repliedToUser = userReplyingTo;
            if (!content.startsWith('@$repliedToUser')) {
              finalContent = '@$repliedToUser $content';
            }
          }
        }
      } catch (e) {
        print('Error getting reply user info: $e');
      }
    }

    Reply reply = Reply(
      studentId: student.uid,
      commentId: commentId,
      tweetId: tweetId,
      content: content,
      postedAt: DateTime.timestamp(),
    );

    // Reply directly to the comment
    var docRef = await _tweetCollection
        .doc(tweetId)
        .collection('comments')
        .doc(commentId)
        .collection('replies')
        .add(reply.toMap());

    return reply.copyWith(id: docRef.id);
  }

  Future<String?> _getReplyUserIdFromComment(
    String tweetId,
    String commentId,
    String replyId,
  ) async {
    try {
      final doc = await _tweetCollection
          .doc(tweetId)
          .collection('comments')
          .doc(commentId)
          .collection('replies')
          .doc(replyId)
          .get();
      return doc.data()?['userId'] as String?;
    } catch (e) {
      return null;
    }
  }

  Future<List<Reply>> fetchReplies(String tweetId, String commentId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('tweets')
          .doc(tweetId)
          .collection('comments')
          .doc(commentId)
          .collection('replies')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => Reply.fromMap(doc.data()..['replyId'] = doc.id, doc.id))
          .toList();
    } catch (e) {
      print('❌ Error fetching replies: $e');
      return [];
    }
  }

  /// Stream replies for realtime updates
  Stream<List<Reply>> streamReplies(String tweetId, String commentId) {
    return FirebaseFirestore.instance
        .collection('tweets')
        .doc(tweetId)
        .collection('comments')
        .doc(commentId)
        .collection('replies')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) =>
                    Reply.fromMap(doc.data()..['replyId'] = doc.id, doc.id),
              )
              .toList(),
        );
  }

  Stream<List<Map<String, dynamic>>> fetchNestedReplies({
    required String tweetId,
    required String parentReplyId,
  }) {
    return _tweetCollection
        .doc(tweetId)
        .collection('replies')
        .doc(parentReplyId)
        .collection('replies')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) => {...d.data(), 'id': d.id}).toList(),
        );
  }

  Future<void> deleteComment({
    required String tweetId,
    required String commentId,
  }) async {
    if (commentId != null) {
      // Delete top-level reply and all its nested replies
      final replyRef = _tweetCollection
          .doc(tweetId)
          .collection('comments')
          .doc(commentId);

      // First, delete all nested replies
      final nestedRepliesSnapshot = await replyRef.collection('comments').get();
      for (final doc in nestedRepliesSnapshot.docs) {
        await doc.reference.delete();
      }

      // Then delete the main reply
      await replyRef.delete();
    } else {
      // Delete nested reply
      await _tweetCollection
          .doc(tweetId)
          .collection('comments')
          .doc(commentId)
          .collection('replies')
          .doc(commentId)
          .delete();
    }
  }

  Future<void> deleteReply({
    required String tweetId,
    required String commentId,
    required String replyId,
  }) async {
    final replyRef = _tweetCollection
        .doc(tweetId)
        .collection('comments')
        .doc(commentId)
        .collection("replies")
        .doc(replyId);
    await replyRef.delete();

    debugPrint("reply deleted successfully");
  }

  Future<void> deleteTweet(String tweetId) async {
    final tweetRef = _tweetCollection.doc(tweetId);

    // Delete all nested replies first
    final repliesSnapshot = await tweetRef.collection('replies').get();
    for (final replyDoc in repliesSnapshot.docs) {
      // Delete nested replies for each top-level reply
      final nestedRepliesSnapshot = await replyDoc.reference
          .collection('replies')
          .get();
      for (final nestedDoc in nestedRepliesSnapshot.docs) {
        await nestedDoc.reference.delete();
      }
      // Delete the top-level reply
      await replyDoc.reference.delete();
    }

    // Finally delete the tweet
    await tweetRef.delete();
  }

  // Add to your TweetService class
  Future<void> refreshTweets() async {
    // Force Firestore to fetch fresh data by getting the documents
    await _tweetCollection
        .orderBy('timestamp', descending: true)
        .get(const GetOptions(source: Source.server));
    // The stream will automatically update with fresh data
  }

  Stream<List<Comment>> fetchComments({required String tweetId}) {
    return _tweetCollection
        .doc(tweetId)
        .collection('comments')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .asyncMap((commentsSnapshot) async {
          // This will hold all comments with their replies
          List<Comment> commentsWithReplies = [];

          for (var commentDoc in commentsSnapshot.docs) {
            // First get the comment data
            final commentData = commentDoc.data();
            commentData['tweetId'] = tweetId;
            commentData['id'] = commentDoc.id;

            // Then fetch all replies for this comment
            final repliesSnapshot = await _tweetCollection
                .doc(tweetId)
                .collection('comments')
                .doc(commentDoc.id)
                .collection('replies')
                .orderBy('timestamp', descending: false)
                .get();

            // Convert replies to Reply objects
            final replies = repliesSnapshot.docs
                .map(
                  (replyDoc) => Reply.fromMap({
                    ...replyDoc.data(),
                    'id': replyDoc.id,
                    'commentId': commentDoc.id,
                    'tweetId': tweetId,
                  }, commentDoc.id),
                )
                .toList();

            // Create the Comment with its replies
            final commentWithReplies = Comment.fromMap(
              commentData,
              commentDoc.id,
              replies,
              tweetId,
            );
            commentsWithReplies.add(commentWithReplies);
          }

          return commentsWithReplies;
        });
  }

  Future<List<TweetModel>> _fetchTweetsWithCommentsAndReplies() async {
    final tweetSnap = await _tweetCollection
        .orderBy('timestamp', descending: true)
        .get();

    List<TweetModel> tweets = [];

    for (final tweetDoc in tweetSnap.docs) {
      // 1️⃣ Fetch comments for each tweet
      final commentsSnap = await tweetDoc.reference
          .collection('comments')
          .orderBy('timestamp', descending: false)
          .get();

      List<Comment> comments = [];
      for (final commentDoc in commentsSnap.docs) {
        // 2️⃣ Fetch replies for each comment
        final repliesSnap = await commentDoc.reference
            .collection('replies')
            .orderBy('timestamp', descending: false)
            .get();

        final replies = repliesSnap.docs
            .map((r) => Reply.fromMap(r.data(), r.id))
            .toList();

        comments.add(
          Comment.fromMap(
            commentDoc.data(),
            commentDoc.id,
            replies,
            tweetDoc.id,
          ),
        );
      }

      // 3️⃣ Add tweet with comments attached
      tweets.add(
        TweetModel.fromMap(tweetDoc.data(), tweetDoc.id, comments: comments),
      );
    }

    return tweets;
  }

  Stream<List<TweetModel>> getTweetsWithCommentsAndReplies() async* {
    yield* _refreshController.stream
        .asyncMap((_) => _fetchTweetsWithCommentsAndReplies())
        .startWith(await _fetchTweetsWithCommentsAndReplies());
  }

  Stream<TweetModel> getTweetWithCommentsAndReplies(String tweetId) async* {
    // Get the tweet document
    final tweetDoc = await _tweetCollection.doc(tweetId).get();

    if (!tweetDoc.exists) {
      debugPrint("tweet not found");
      throw Exception('Tweet not found');
    }

    // 1️⃣ Fetch comments for the tweet
    final commentsSnap = await _tweetCollection
        .doc(tweetId)
        .collection('comments')
        .orderBy('timestamp', descending: true)
        .get();

    List<Comment> comments = [];
    for (final commentDoc in commentsSnap.docs) {
      // 2️⃣ Fetch replies for each comment
      final repliesSnap = await _tweetCollection
          .doc(tweetId)
          .collection('comments')
          .doc(commentDoc.id)
          .collection('replies')
          .orderBy('postedAt', descending: true)
          .get();

      final replies = repliesSnap.docs
          .map((r) => Reply.fromMap(r.data(), r.id))
          .toList();

      comments.add(
        Comment.fromMap(
          {...commentDoc.data(), 'id': commentDoc.id, 'tweetId': tweetId},
          commentDoc.id,
          replies,
          tweetId,
        ),
      );
    }

    // 3️⃣ Create and yield the tweet with comments
    yield TweetModel.fromMap(
      {...?tweetDoc.data(), 'id': tweetDoc.id},
      tweetDoc.id,
      comments: comments,
    );
  }

  Future<TweetModel> postTweet(String userId, String content) async {
    var tweetMap = {
      'userId': userId,
      'user': userId,
      'content': content,
      'timestamp': Timestamp.now(),
      'likes': [],
      'shares': [],
      'locked': false,
    };

    var docRef = await _tweetCollection.add(tweetMap);
    return TweetModel(
      shares: [],
      id: docRef.id,
      userId: userId,
      user: userId,
      content: content,
      timestamp: DateTime.timestamp(),
      likes: [],
      comments: [],
    );
  }

  void triggerRefresh() {
    _refreshController.add(null);
  }

  Future<void> toggleLikeComment({
    required String tweetId,
    required String commentId,
    required String userId,
  }) async {
    final ref = _tweetCollection
        .doc(tweetId)
        .collection('comments')
        .doc(commentId);

    final doc = await ref.get();
    if (!doc.exists) return;

    final likes = List<String>.from(doc['likes'] ?? []);
    if (likes.contains(userId)) {
      likes.remove(userId);
    } else {
      likes.add(userId);
    }

    await ref.update({'likes': likes});
  }

  Future<void> toggleLikeForReply({
    required String tweetId,
    required String commentId,
    required String replyId,
    required String userId,
  }) async {
    final ref = _tweetCollection
        .doc(tweetId)
        .collection('comments')
        .doc(commentId)
        .collection('replies')
        .doc(replyId);
    final doc = await ref.get();
    if (!doc.exists) return;

    final likes = List<String>.from(doc['likes'] ?? []);
    if (likes.contains(userId)) {
      likes.remove(userId);
    } else {
      likes.add(userId);
    }

    await ref.update({'likes': likes});
  }

  Future<void> toggleLikeReply({
    required String tweetId,
    required String commentId,
    required String replyId,
    required String userId,
  }) async {
    final ref = _tweetCollection
        .doc(tweetId)
        .collection('comments')
        .doc(commentId)
        .collection('replies')
        .doc(replyId);

    final doc = await ref.get();
    if (!doc.exists) return;

    final likes = List<String>.from(doc['likes'] ?? []);
    if (likes.contains(userId)) {
      likes.remove(userId);
    } else {
      likes.add(userId);
    }

    await ref.update({'likes': likes});
  }
}
