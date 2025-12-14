import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:rxdart/rxdart.dart';

import '../../../model/comments_model.dart';
import '../../../model/reply_model.dart';
import '../../../model/tweetModel.dart';
import '../../../model/userProfile.dart';

class TweetService {
  final _tweetCollection = FirebaseFirestore.instance.collection('tweets');
  final _refreshController = StreamController<void>.broadcast();
  final _savedTweetsCollection = FirebaseFirestore.instance.collection(
    'savedTweets',
  );

  // Helper method to generate document ID
  String _generateTweetDocId(String posterId) {
    final now = DateTime.now();
    // Format: posterId_yyyyMMdd_HHmmss
    final dateStr =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    return '${posterId}_${dateStr}_$timeStr';
  }

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
    try {
      final doc = await _tweetCollection.doc(tweetId).get();

      // Check if document exists
      if (!doc.exists) {
        debugPrint('Tweet $tweetId does not exist');
        return;
      }

      // Get data from document
      final data = doc.data();
      if (data == null) {
        debugPrint('Tweet $tweetId has no data');
        return;
      }

      // Safely get likes field
      var likesRaw = data['likes'];
      List<String> likes;

      if (likesRaw is List) {
        likes = List<String>.from(likesRaw);
      } else if (likesRaw is int) {
        likes = <String>[];
      } else {
        likes = <String>[];
      }

      if (likes.contains(userId)) {
        likes.remove(userId);
      } else {
        likes.add(userId);
      }

      await _tweetCollection.doc(tweetId).update({'likes': likes});
      debugPrint('Successfully toggled like for tweet $tweetId');
    } catch (e) {
      debugPrint('Error toggling like for tweet $tweetId: $e');
      rethrow;
    }
  }

  Future<void> addToShareList(String tweetId, String userId) async {
    try {
      final docRef = _tweetCollection.doc(tweetId);
      final doc = await docRef.get();

      List<String> shares = [];

      if (doc.exists) {
        final shareRaw = doc.data()?['shares'];
        if (shareRaw is List) {
          shares = List<String>.from(shareRaw.whereType<String>());
        } else if (shareRaw is int) {
          shares = <String>[];
        }
      }

      if (!shares.contains(userId)) {
        shares.add(userId);
      }

      await docRef.set({
        'shares': shares,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error adding to share list: $e');
      rethrow;
    }
  }

  Future<Comment> postComment({
    required String tweetId,
    required UserConverter student,
    required String content,
  }) async {
    final commentData = {
      'userId': student.uid,
      'user': student.displayName,
      'userImage': student.imageUrl,
      'content': content,
      'timestamp': Timestamp.now(),
      'likes': [],
      'locked': false,
    };

    var docRef = await _tweetCollection
        .doc(tweetId)
        .collection('comments')
        .add(commentData);

    triggerRefresh();
    return Comment.fromMap(commentData, docRef.id, [], tweetId);
  }

  Future<Reply> postReply({
    required String tweetId,
    required String commentId,
    String? replyTo,
    required UserConverter student,
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
        debugPrint('Error getting reply user info: $e');
      }
    }

    final reply = Reply(
      studentId: student.uid,
      commentId: commentId,
      tweetId: tweetId,
      content: finalContent,
      postedAt: DateTime.now(),
    );

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
      debugPrint('❌ Error fetching replies: $e');
      return [];
    }
  }

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
    if (commentId.isNotEmpty) {
      final replyRef = _tweetCollection
          .doc(tweetId)
          .collection('comments')
          .doc(commentId);

      final nestedRepliesSnapshot = await replyRef.collection('replies').get();
      for (final doc in nestedRepliesSnapshot.docs) {
        await doc.reference.delete();
      }

      await replyRef.delete();
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
        .collection('replies')
        .doc(replyId);
    await replyRef.delete();

    debugPrint('reply deleted successfully');
  }

  Future<void> deleteTweet(String tweetId) async {
    final tweetRef = _tweetCollection.doc(tweetId);

    // Delete all comments first
    final commentsSnapshot = await tweetRef.collection('comments').get();
    for (final commentDoc in commentsSnapshot.docs) {
      // Delete all replies for each comment
      final repliesSnapshot = await commentDoc.reference
          .collection('replies')
          .get();
      for (final replyDoc in repliesSnapshot.docs) {
        await replyDoc.reference.delete();
      }
      // Delete the comment
      await commentDoc.reference.delete();
    }

    // Finally delete the tweet
    await tweetRef.delete();
  }

  Future<void> refreshTweets() async {
    await _tweetCollection
        .orderBy('timestamp', descending: true)
        .get(const GetOptions(source: Source.server));
  }

  Stream<List<Comment>> fetchComments({required String tweetId}) {
    return _tweetCollection
        .doc(tweetId)
        .collection('comments')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .asyncMap((commentsSnapshot) async {
          List<Comment> commentsWithReplies = [];

          for (var commentDoc in commentsSnapshot.docs) {
            final commentData = commentDoc.data();
            commentData['tweetId'] = tweetId;
            commentData['id'] = commentDoc.id;

            final repliesSnapshot = await _tweetCollection
                .doc(tweetId)
                .collection('comments')
                .doc(commentDoc.id)
                .collection('replies')
                .orderBy('timestamp', descending: false)
                .get();

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
      final commentsSnap = await tweetDoc.reference
          .collection('comments')
          .orderBy('timestamp', descending: false)
          .get();

      List<Comment> comments = [];
      for (final commentDoc in commentsSnap.docs) {
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
    final tweetDoc = await _tweetCollection.doc(tweetId).get();

    if (!tweetDoc.exists) {
      debugPrint('Tweet $tweetId not found');
      throw Exception('Tweet not found');
    }

    final commentsSnap = await _tweetCollection
        .doc(tweetId)
        .collection('comments')
        .orderBy('timestamp', descending: true)
        .get();

    List<Comment> comments = [];
    for (final commentDoc in commentsSnap.docs) {
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

    yield TweetModel.fromMap(
      {...?tweetDoc.data(), 'id': tweetDoc.id},
      tweetDoc.id,
      comments: comments,
    );
  }

  // UPDATED: Use custom document ID instead of auto-generated ID
  Future<TweetModel> postTweet(String posterId, String content) async {
    // Generate custom document ID
    final docId = _generateTweetDocId(posterId);

    final tweetMap = {
      'userId': posterId,
      'user': posterId, // You might want to fetch actual username here
      'content': content,
      'timestamp': Timestamp.now(),
      'likes': [],
      'shares': [],
      'locked': false,
    };

    // Use set() with custom document ID instead of add()

    await _tweetCollection.doc(docId).set(tweetMap);

    return TweetModel(
      createdAt: DateTime.now(),
      shares: [],
      id: docId,
      userId: posterId,
      user: posterId,
      content: content,
      timestamp: DateTime.now(),
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

    final likes = List<String>.from(doc.data()?['likes'] ?? []);
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

    final likes = List<String>.from(doc.data()?['likes'] ?? []);
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

    final likes = List<String>.from(doc.data()?['likes'] ?? []);
    if (likes.contains(userId)) {
      likes.remove(userId);
    } else {
      likes.add(userId);
    }

    await ref.update({'likes': likes});
  }

  // Helper method to generate document ID for saved tweets
  String _generateSavedTweetDocId(String userId) {
    final now = DateTime.now();
    // Format: userId_yyyyMMdd_HHmmss (using current time when saved)
    final dateStr =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    return '${userId}_${dateStr}_$timeStr';
  }

  // Method to save a tweet (only stores tweetId and userId)
  Future<void> saveTweet({
    required String userId,
    required String tweetId,
  }) async {
    try {
      // Generate custom document ID
      final docId = _generateSavedTweetDocId(userId);

      final savedTweetData = {
        'userId': userId, // User who saved the tweet
        'tweetId': tweetId, // Original tweet ID
        'savedAt': Timestamp.now(), // When the tweet was saved
      };

      await _savedTweetsCollection.doc(docId).set(savedTweetData);
      debugPrint('Tweet saved successfully with ID: $docId');
    } catch (e) {
      debugPrint('Error saving tweet: $e');
      rethrow;
    }
  }

  // Method to check if a tweet is saved by a user
  Future<bool> isTweetSavedByUser(String userId, String tweetId) async {
    try {
      final query = await _savedTweetsCollection
          .where('userId', isEqualTo: userId)
          .where('tweetId', isEqualTo: tweetId)
          .limit(1)
          .get();

      return query.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking if tweet is saved: $e');
      return false;
    }
  }

  // Method to get all saved tweet IDs for a user
  Stream<List<String>> getSavedTweetIds(String userId) {
    return _savedTweetsCollection
        .where('userId', isEqualTo: userId)
        .orderBy('savedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          debugPrint("snapshot is ${snapshot.docs}");
          return snapshot.docs
              .map((doc) => doc.data()['tweetId'] as String)
              .toList();
        });
  }

  // Method to get all saved tweets with full tweet data
  Stream<List<TweetModel>> getSavedTweets(String userId) {
    return getSavedTweetIds(userId).asyncMap((tweetIds) async {
      if (tweetIds.isEmpty) return [];

      // Fetch all saved tweets in parallel
      final tweets = await Future.wait(
        tweetIds.map((tweetId) => _getTweetById(tweetId)),
      );

      // Filter out null tweets (deleted tweets)
      return tweets.whereType<TweetModel>().toList();
    });
  }

  // Helper method to get a tweet by ID
  Future<TweetModel?> _getTweetById(String tweetId) async {
    try {
      debugPrint("tweetId is $tweetId");
      final doc = await _tweetCollection.doc(tweetId).get();

      if (!doc.exists) {
        debugPrint('Tweet $tweetId not found (might have been deleted)');
        return null;
      }

      // Also fetch comments for the tweet
      final commentsSnap = await _tweetCollection
          .doc(tweetId)
          .collection('comments')
          .orderBy('timestamp', descending: false)
          .get();

      List<Comment> comments = [];
      for (final commentDoc in commentsSnap.docs) {
        final repliesSnap = await commentDoc.reference
            .collection('replies')
            .orderBy('timestamp', descending: false)
            .get();

        final replies = repliesSnap.docs
            .map((r) => Reply.fromMap(r.data(), r.id))
            .toList();

        comments.add(
          Comment.fromMap(commentDoc.data(), commentDoc.id, replies, tweetId),
        );
      }

      return TweetModel.fromMap(doc.data()!, doc.id, comments: comments);
    } catch (e) {
      debugPrint('Error fetching tweet $tweetId: $e');
      return null;
    }
  }

  // Method to get saved tweets with pagination
  Future<List<TweetModel>> getSavedTweetsPaginated({
    required String userId,
    int limit = 20,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      // Since document IDs are in format: userId_date_time
      // We can filter by document ID starting with userId
      Query query = _savedTweetsCollection
          .orderBy(FieldPath.documentId)
          .startAt([userId])
          .endAt(['${userId}\uf8ff']) // \uf8ff is a high Unicode character
          .limit(limit);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final snapshot = await query.get();

      // Extract tweet IDs from documents
      final tweetIds = snapshot.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>?;
            return data?['tweetId'] as String?;
          })
          .where((tweetId) => tweetId != null)
          .cast<String>()
          .toList();

      if (tweetIds.isEmpty) return [];

      // Fetch full tweet data for each ID
      final tweets = await Future.wait(
        tweetIds.map((tweetId) => _getTweetById(tweetId)),
      );

      // Filter out null tweets and cast to TweetModel
      return tweets.whereType<TweetModel>().toList();
    } catch (e) {
      debugPrint('Error getting saved tweets: $e');
      return [];
    }
  }

  // Method to remove a saved tweet
  Future<void> removeSavedTweet(String savedTweetDocId) async {
    try {
      await _savedTweetsCollection.doc(savedTweetDocId).delete();
      debugPrint('Saved tweet removed: $savedTweetDocId');
    } catch (e) {
      debugPrint('Error removing saved tweet: $e');
      rethrow;
    }
  }

  // Method to remove saved tweet by userId and tweetId
  Future<void> removeSavedTweetByUserAndTweetId(
    String userId,
    String tweetId,
  ) async {
    try {
      final query = await _savedTweetsCollection
          .where('userId', isEqualTo: userId)
          .where('tweetId', isEqualTo: tweetId)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        await _savedTweetsCollection.doc(query.docs.first.id).delete();
        debugPrint('Saved tweet removed for user: $userId, tweet: $tweetId');
      }
    } catch (e) {
      debugPrint('Error removing saved tweet by user and tweet ID: $e');
      rethrow;
    }
  }

  // Method to get saved tweet document ID by userId and tweetId
  Future<String?> getSavedTweetDocId(String userId, String tweetId) async {
    try {
      final query = await _savedTweetsCollection
          .where('userId', isEqualTo: userId)
          .where('tweetId', isEqualTo: tweetId)
          .limit(1)
          .get();

      return query.docs.isNotEmpty ? query.docs.first.id : null;
    } catch (e) {
      debugPrint('Error getting saved tweet document ID: $e');
      return null;
    }
  }

  // Method to toggle save/unsave a tweet (simplified)
  Future<void> toggleSaveTweet({
    required String userId,
    required String tweetId,
  }) async {
    try {
      // Check if already saved
      final isSaved = await isTweetSavedByUser(userId, tweetId);

      if (isSaved) {
        // If saved, remove it
        await removeSavedTweetByUserAndTweetId(userId, tweetId);
        debugPrint('Tweet unsaved by user: $userId');
      } else {
        // If not saved, save it
        await saveTweet(userId: userId, tweetId: tweetId);
        debugPrint('Tweet saved by user: $userId');
      }
    } catch (e) {
      debugPrint('Error toggling save tweet: $e');
      rethrow;
    }
  }

  // Method to get count of saved tweets for a user
  Future<int> getSavedTweetsCount(String userId) async {
    try {
      final query = await _savedTweetsCollection
          .where('userId', isEqualTo: userId)
          .count()
          .get();

      return query.count ?? 0;
    } catch (e) {
      debugPrint('Error getting saved tweets count: $e');
      return 0;
    }
  }

  // Method to get saved tweets with batch fetch (more efficient)
  Stream<List<TweetModel>> getSavedTweetsBatch(String userId) {
    return getSavedTweetIds(userId).switchMap((tweetIds) {
      if (tweetIds.isEmpty) {
        return Stream.value([]);
      }

      // Create a stream for each tweet and combine them
      final tweetStreams = tweetIds.map((tweetId) {
        return _tweetCollection.doc(tweetId).snapshots().map((snapshot) {
          if (!snapshot.exists) return null;

          return TweetModel.fromMap(
            snapshot.data()!,
            snapshot.id,
            comments: [], // You can add comments if needed
          );
        });
      });

      return CombineLatestStream.list<TweetModel?>(
        tweetStreams,
      ).map((tweets) => tweets.whereType<TweetModel>().toList());
    });
  }

  // Method to clear all saved tweets for a user
  Future<void> clearAllSavedTweets(String userId) async {
    try {
      final query = await _savedTweetsCollection
          .where('userId', isEqualTo: userId)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in query.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      debugPrint('All saved tweets cleared for user: $userId');
    } catch (e) {
      debugPrint('Error clearing saved tweets: $e');
      rethrow;
    }
  }

  // Method to check if multiple tweets are saved by a user
  Future<Map<String, bool>> areTweetsSavedByUser(
    String userId,
    List<String> tweetIds,
  ) async {
    try {
      if (tweetIds.isEmpty) return {};

      final query = await _savedTweetsCollection
          .where('userId', isEqualTo: userId)
          .where('tweetId', whereIn: tweetIds)
          .get();

      final savedTweetIds = query.docs
          .map((doc) => doc.data()['tweetId'] as String)
          .toSet();

      final result = <String, bool>{};
      for (final tweetId in tweetIds) {
        result[tweetId] = savedTweetIds.contains(tweetId);
      }

      return result;
    } catch (e) {
      debugPrint('Error checking multiple tweets: $e');
      return {};
    }
  }
}
