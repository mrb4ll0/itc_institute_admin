import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../itc_logic/firebase/general_cloud.dart';
import '../itc_logic/firebase/tweet/tweet_cloud.dart';
import '../model/comments_model.dart';
import '../model/reply_model.dart';
import '../model/student.dart';
import '../model/tweetModel.dart';

class TweetProvider extends ChangeNotifier {
  final TweetService _tweetService = TweetService();

  String? _replyingToTweetId;
  bool _postingReply = false;
  bool _activatedAnonymous = false;
  bool _postingComment = false;
  String? _commentingTo = "";
  List<TweetModel> _tweets = [];

  List<TweetModel> get tweets => _tweets;
  StreamSubscription<List<TweetModel>>? _tweetsSubscription;
  bool _isLoading = true;

  bool get isLoading => _isLoading;

  TweetProvider() {
    _subscribeToTweets();
  }

  String? get replyingToTweetId => _replyingToTweetId;
  bool get postingReply => _postingReply;
  bool get postingcomment => _postingComment;
  String? get commentingTo => _commentingTo;

  void postComment({required Comment comment, required Student student}) async {
    _postingComment = true;
    if (comment.content.isEmpty) return;
    await _tweetService.postComment(
      tweetId: comment.tweetId,
      student: student,
      content: comment.content,
    );
    notifyListeners();
    _postingComment = false;
  }

  Future<void> postTweet(String text, String userName) async {
    if (text.isEmpty) return;
    _postingReply = true;
    notifyListeners();

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid ?? "";
      final newTweet = TweetModel(
        user: userName,
        shares: [],
        id: DateTime.now().millisecondsSinceEpoch.toString(), // temp id
        userId: userId,
        content: text.trim(),
        timestamp: DateTime.now(),
        likes: [],
        comments: [],
      );

      _tweets.insert(0, newTweet);
      notifyListeners();
      var postedTweet = await _tweetService.postTweet(
        FirebaseAuth.instance.currentUser!.uid,
        text.trim(),
      );

      // 3️⃣ Replace temp tweet with real one (optional)
      final idx = _tweets.indexWhere(
        (t) => t.id == DateTime.now().millisecondsSinceEpoch.toString(),
      );
      if (idx != -1) {
        _tweets[idx] = postedTweet;
        notifyListeners();
      }
    } finally {
      _postingReply = false;
      notifyListeners();
    }
  }

  void activateAnonymous() {
    _activatedAnonymous = !_activatedAnonymous;
    notifyListeners();
  }

  void startReply(String tweetId) {
    _replyingToTweetId = tweetId;
    notifyListeners();
  }

  void cancelReply() {
    _replyingToTweetId = null;

    notifyListeners();
  }

  void startComment(String tweetId) {
    _commentingTo = tweetId;
    notifyListeners();
  }

  void cancelComment() {
    _commentingTo = null;

    notifyListeners();
  }

  Future<void> toggleLike(
    String tweetId,
    String userId,
    bool isCurrentlyLiked,
  ) async {
    final tweetIndex = _tweets.indexWhere((t) => t.id == tweetId);

    if (tweetIndex != -1) {
      final updatedTweet = _tweets[tweetIndex];

      if (isCurrentlyLiked) {
        updatedTweet.likes.remove(userId);
      } else {
        updatedTweet.likes.add(userId);
      }

      _tweets[tweetIndex] = updatedTweet;
      notifyListeners(); // UI updates instantly
    }

    _tweetService.toggleLikeTweet(tweetId, userId);
  }

  Future<void> shareTweet() async {
    notifyListeners();
  }

  void _subscribeToTweets() {
    _tweetsSubscription?.cancel(); // Cancel any existing subscription
    _isLoading = true;
    notifyListeners();
    _tweetsSubscription = _tweetService
        .getTweetsWithCommentsAndReplies()
        .listen((tweets) {
          _tweets = tweets;
          _isLoading = false;
          notifyListeners();
        });
  }

  Future<Map<String, Student>> fetchAllStudents(List<TweetModel> tweets) async {
    try {
      final studentIds = tweets
          .map((t) => t.userId)
          .where((id) => id.isNotEmpty)
          .toSet();

      final studentFutures = studentIds.map(
        (id) => StudentCache.getStudent(id),
      );
      final studentResults = await Future.wait(
        studentFutures,
        eagerError: false,
      );

      final studentMap = <String, Student>{};
      for (var i = 0; i < studentIds.length; i++) {
        final student = studentResults[i];
        final studentId = studentIds.elementAt(i);
        if (student != null) {
          studentMap[studentId] = student;
        } else {
          debugPrint('Student not found for ID: $studentId');
        }
      }

      return studentMap;
    } catch (e) {
      debugPrint('Error fetching students: $e');
      return {};
    }
  }

  Future<void> deleteTweet(String tweetId, BuildContext context) async {
    final idx = _tweets.indexWhere((t) => t.id == tweetId);
    if (idx == -1) return;

    final removed = _tweets.removeAt(idx); // optimistic removal
    notifyListeners();

    try {
      await _tweetService.deleteTweet(tweetId);
    } catch (e) {
      // rollback on failure
      _tweets.insert(idx, removed);
      notifyListeners();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete. Please retry.')),
      );
    }
  }

  void addCommentToTweet(String tweetId, Comment comments) {
    final tweetIndex = _tweets.indexWhere((tweet) => tweet.id == tweetId);

    if (tweetIndex != -1) {
      _tweets[tweetIndex].comments.add(comments);
      debugPrint("comment added successfully");
      notifyListeners();
    }
  }

  void removeCommentFromTweet(String tweetId, String commentId) {
    final tweetIndex = _tweets.indexWhere((tweet) => tweet.id == tweetId);
    debugPrint("tweetIndex is $tweetIndex");

    if (tweetIndex != -1) {
      final before = _tweets[tweetIndex].comments.length;
      _tweets[tweetIndex].comments.removeWhere((c) {
        debugPrint("Checking comment with id: ${c.id}");
        return c.id == commentId;
      });
      final after = _tweets[tweetIndex].comments.length;

      debugPrint("Removed? ${before != after}");
      notifyListeners();
    }
  }

  /// Add a reply to a specific comment inside a tweet
  void addReplyToComment(String tweetId, String commentId, Reply reply) {
    final tweetIndex = _tweets.indexWhere((tweet) => tweet.id == tweetId);

    if (tweetIndex != -1) {
      final commentIndex = _tweets[tweetIndex].comments.indexWhere(
        (c) => c.id == commentId,
      );

      if (commentIndex != -1) {
        _tweets[tweetIndex].comments[commentIndex].replies.add(reply);
        debugPrint("Reply added successfully");
        notifyListeners();
      } else {
        debugPrint("Comment not found for id $commentId");
      }
    } else {
      debugPrint("Tweet not found for id $tweetId");
    }
  }

  /// Remove a reply from a specific comment inside a tweet
  void removeReplyFromComment(
    String tweetId,
    String commentId,
    String replyId,
  ) {
    final tweetIndex = _tweets.indexWhere((tweet) => tweet.id == tweetId);

    if (tweetIndex != -1) {
      final commentIndex = _tweets[tweetIndex].comments.indexWhere(
        (c) => c.id == commentId,
      );

      if (commentIndex != -1) {
        final before =
            _tweets[tweetIndex].comments[commentIndex].replies.length;
        _tweets[tweetIndex].comments[commentIndex].replies.removeWhere(
          (r) => r.id == replyId,
        );
        final after = _tweets[tweetIndex].comments[commentIndex].replies.length;

        debugPrint("Reply removed? ${before != after}");
        notifyListeners();
      } else {
        debugPrint("Comment not found for id $commentId");
      }
    } else {
      debugPrint("Tweet not found for id $tweetId");
    }
  }
}

class StudentCache {
  static final Map<String, Student> _cache = {};

  static Future<Student?> getStudent(String id) async {
    if (_cache.containsKey(id)) return _cache[id];
    final student = await ITCFirebaseLogic().getStudent(id);
    if (student != null) {
      _cache[id] = student;
    }
    return student;
  }
}
