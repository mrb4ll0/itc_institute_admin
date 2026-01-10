import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:itc_institute_admin/itc_logic/firebase/general_cloud.dart';
import 'package:itc_institute_admin/itc_logic/notification/notitification_service.dart';
import 'package:itc_institute_admin/itc_logic/service/ConverterUserService.dart';
import 'package:itc_institute_admin/model/company.dart';
import 'package:itc_institute_admin/model/userProfile.dart';

import '../itc_logic/firebase/tweet/tweet_cloud.dart';
import '../model/comments_model.dart';
import '../model/reply_model.dart';
import '../model/tweetModel.dart';

class TweetProvider extends ChangeNotifier {
  final TweetService _tweetService = TweetService();
  final NotificationService notificationService = NotificationService();
  final ITCFirebaseLogic itcFirebaseLogic = ITCFirebaseLogic();

  // Main tweets list state
  List<TweetModel> _tweets = [];
  List<TweetModel> get tweets => _tweets;
  StreamSubscription<List<TweetModel>>? _tweetsSubscription;
  bool _isLoading = true;
  bool get isLoading => _isLoading;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  // Tweet detail state (for individual tweet view)
  Map<String, TweetModel?> _tweetDetails = {};
  Map<String, List<Comment>> _tweetComments = {};
  Map<String, bool> _tweetDetailLoading = {};
  Map<String, String?> _tweetDetailErrors = {};


  // Reply/Comment state
  String? _replyingToTweetId;
  String? _replyingToTweetContent;
  String? _replyingToCommentId;
  String? _replyingToCommentContent;
  String? _replyingToReplyId;
  String? _replyingToReplyContent;
  bool _postingReply = false;
  bool _postingComment = false;
  bool _activatedAnonymous = false;
  String? _commentingTo = "";

  // Subscriptions for individual tweets
  Map<String, StreamSubscription<TweetModel?>> _tweetDetailSubscriptions = {};
  Map<String, StreamSubscription<List<Comment>>> _tweetCommentsSubscriptions =
      {};

  TweetProvider() {
    _subscribeToTweets();
  }

  // Getters
  String? get replyingToTweetId => _replyingToTweetId;
  String? get replyingToTweetContent => _replyingToTweetContent;
  String? get replyingToCommentId => _replyingToCommentId;
  String? get replyingToCommentContent => _replyingToCommentContent;
  String? get replyingToReplyId => _replyingToReplyId;
  String? get replyingToReplyContent => _replyingToReplyContent;
  bool get postingReply => _postingReply;
  bool get postingComment => _postingComment;
  String? get commentingTo => _commentingTo;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;

  // Helper methods for tweet details
  TweetModel? getTweetDetail(String tweetId) => _tweetDetails[tweetId];
  List<Comment> getTweetComments(String tweetId) =>
      _tweetComments[tweetId] ?? [];
  bool isTweetDetailLoading(String tweetId) =>
      _tweetDetailLoading[tweetId] ?? true;
  String? getTweetDetailError(String tweetId) => _tweetDetailErrors[tweetId];

  // Subscribe to main tweets list
  void _subscribeToTweets() {
    _tweetsSubscription?.cancel();
    _isLoading = true;
    notifyListeners();

    _tweetService.resetPagination();
    _tweetsSubscription = _tweetService
        .getTweetsWithCommentsAndReplies()
        .listen(
          (tweets) {
        _tweets = tweets;
        _isLoading = false;
        _hasMore = tweets.length >= _tweetService.tweetsPerPage;
        notifyListeners();
      },
      onError: (error) {
        debugPrint('Error fetching tweets: $error');
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  // Load more tweets
  Future<void> loadMoreTweets() async {
    if (_isLoadingMore || !_hasMore) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final moreTweets = await _tweetService.loadMoreTweets();

      if (moreTweets.isEmpty) {
        _hasMore = false;
      } else {
        _tweets.addAll(moreTweets);
        _hasMore = moreTweets.length >= _tweetService.tweetsPerPage;
      }
    } catch (error) {
      debugPrint('Error loading more tweets: $error');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  // Check if there are more tweets
  Future<void> checkHasMore() async {
    _hasMore = await _tweetService.hasMoreTweets();
    notifyListeners();
  }

  // Refresh tweets
  Future<void> refreshTweets() async {
    _tweetService.resetPagination();
    _subscribeToTweets();
  }

  // Subscribe to individual tweet details
  void subscribeToTweetDetail(String tweetId) {
    if (_tweetDetailSubscriptions.containsKey(tweetId)) return;

    _tweetDetailLoading[tweetId] = true;
    _tweetDetailErrors[tweetId] = null;
    notifyListeners();

    _tweetDetailSubscriptions[tweetId] = _tweetService
        .getTweetWithCommentsAndReplies(tweetId)
        .listen(
          (tweet) {
            _tweetDetails[tweetId] = tweet as TweetModel?;
            _tweetDetailLoading[tweetId] = false;
            notifyListeners();
          },
          onError: (error) {
            debugPrint('Error fetching tweet $tweetId: $error');
            _tweetDetailErrors[tweetId] = error.toString();
            _tweetDetailLoading[tweetId] = false;
            notifyListeners();
          },
        );

    // Also subscribe to comments separately if needed
    _subscribeToTweetComments(tweetId);
  }

  void _subscribeToTweetComments(String tweetId) {
    _tweetCommentsSubscriptions[tweetId]?.cancel();

    _tweetCommentsSubscriptions[tweetId] = _tweetService
        .fetchComments(tweetId: tweetId)
        .listen(
          (comments) {
            _tweetComments[tweetId] = comments;
            notifyListeners();
          },
          onError: (error) {
            debugPrint('Error fetching comments for tweet $tweetId: $error');
          },
        );
  }

  // Unsubscribe from tweet details when not needed
  void unsubscribeFromTweetDetail(String tweetId) {
    _tweetDetailSubscriptions[tweetId]?.cancel();
    _tweetDetailSubscriptions.remove(tweetId);

    _tweetCommentsSubscriptions[tweetId]?.cancel();
    _tweetCommentsSubscriptions.remove(tweetId);

    _tweetDetails.remove(tweetId);
    _tweetComments.remove(tweetId);
    _tweetDetailLoading.remove(tweetId);
    _tweetDetailErrors.remove(tweetId);
  }

  // Reply state management
  void setReplyingToTweet(String tweetId, String content) {
    _replyingToTweetId = tweetId;
    _replyingToTweetContent = content;
    notifyListeners();
  }

  void setReplyingToComment(String commentId, String content) {
    _replyingToCommentId = commentId;
    _replyingToCommentContent = content;
    notifyListeners();
  }

  void setReplyingToReply(String replyId, String content) {
    _replyingToReplyId = replyId;
    _replyingToReplyContent = content;
    notifyListeners();
  }

  void cancelReplyingToTweet() {
    _replyingToTweetId = null;
    _replyingToTweetContent = null;
    notifyListeners();
  }

  void cancelReplyToComment() {
    _replyingToCommentId = null;
    _replyingToCommentContent = null;
    notifyListeners();
  }

  void cancelCommentToReply() {
    _replyingToReplyId = null;
    _replyingToReplyContent = null;
    notifyListeners();
  }

  // // Original methods
  // void postComment({required Comment comment, required Student student}) async {
  //   _postingComment = true;
  //   if (comment.content.isEmpty) return;
  //
  //   await _tweetService.postComment(
  //     tweetId: comment.tweetId,
  //     student: student,
  //     content: comment.content,
  //   );
  //
  //   notifyListeners();
  //   _postingComment = false;
  // }

  // Enhanced postComment with tweet detail update
  Future<void> postCommentToTweet(
    String tweetId,
    String content,
    UserConverter student,
  ) async {
    if (content.isEmpty) return;
    debugPrint("tweetPoster is ${student.displayName}");
    final comment = await _tweetService.postComment(
      tweetId: tweetId,
      student: student,
      content: content,
    );




      await notificationService.sendNotificationToUser(
          fcmToken: student.fcmToken, title: "New Comment from ${student.displayName}", body: content.trim());


    // Update main tweets list
    final tweetIndex = _tweets.indexWhere((t) => t.id == tweetId);
    if (tweetIndex != -1) {
      _tweets[tweetIndex].comments.insert(0, comment);
    }

    // Update tweet detail
    final detailTweet = _tweetDetails[tweetId];
    if (detailTweet != null) {
      detailTweet.comments.insert(0, comment);
    }

    // Update comments list
    final comments = _tweetComments[tweetId] ?? [];
    comments.insert(0, comment);
    _tweetComments[tweetId] = comments;

    notifyListeners();
  }

  Future<void> postReply(
    String tweetId,
    String commentId,
    int commentIndex,
    String content,
    UserConverter company,
    String userReplyingTo,
  ) async {
    if (content.isEmpty) return;

    final reply = await _tweetService.postReply(
      userReplyingTo: userReplyingTo,
      tweetId: tweetId,
      commentId: commentId,
      student: company,
      content: content,
    );

    //final fcmTokens = await itcFirebaseLogic.getAllFCMTokens();


       notificationService.sendNotificationToUser(
          fcmToken: company.fcmToken, title: "New reply from ${company.displayName}", body: content.trim());


    // Update main tweets list
    final tweetIndex = _tweets.indexWhere((t) => t.id == tweetId);
    if (tweetIndex != -1 &&
        commentIndex < _tweets[tweetIndex].comments.length) {
      _tweets[tweetIndex].comments[commentIndex].replies.insert(0, reply);
    }

    // Update tweet detail
    final detailTweet = _tweetDetails[tweetId];
    if (detailTweet != null && commentIndex < detailTweet.comments.length) {
      detailTweet.comments[commentIndex].replies.insert(0, reply);
    }

    notifyListeners();
  }

  Future<void> postMention({
    required String tweetId,
    required String commentId,
    required int commentIndex,
    required String content,
    required Company student,
    required String mentionedId,
    required String userReplyingTo,
  }) async {
    if (content.isEmpty) return;

    final reply = await _tweetService.postReply(
      userReplyingTo: userReplyingTo,
      tweetId: tweetId,
      commentId: commentId,
      student: UserConverter(student),
      content: "@$userReplyingTo#$mentionedId## $content",
    );

    // Update tweet detail
    final detailTweet = _tweetDetails[tweetId];
    if (detailTweet != null && commentIndex < detailTweet.comments.length) {
      detailTweet.comments[commentIndex].replies.add(reply);
    }

    notifyListeners();
  }

  Future<void> postTweet(String text, String userName) async {
    if (text.isEmpty) return;
    _postingReply = true;
    notifyListeners();

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid ?? "";

      // First post the tweet to get the actual Firestore document ID
      final postedTweet = await _tweetService.postTweet(
        FirebaseAuth.instance.currentUser!.uid,
        text.trim(),
      );
       final fcmTokens = await itcFirebaseLogic.getAllFCMTokens();

       for(final fcmToken in fcmTokens) {
         await notificationService.sendNotificationToUser(
             fcmToken: fcmToken, title: "New Feeds", body: text.trim());
       }
      // Now use the actual tweet returned from Firestore
      final newTweet = TweetModel(
        createdAt: DateTime.now(),
        user: userName,
        shares: [],
        id: postedTweet.id, // Use the actual Firestore ID
        userId: userId,
        content: text.trim(),
        timestamp: DateTime.now(),
        likes: [],
        comments: [],
      );

      _tweets.insert(0, newTweet);
      notifyListeners();
    } catch (e) {
      debugPrint('Error posting tweet: $e');
      // Handle error - maybe remove the temporary tweet from the list
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
    // Update main tweets list
    final tweetIndex = _tweets.indexWhere((t) => t.id == tweetId);
    if (tweetIndex != -1) {
      final updatedTweet = _tweets[tweetIndex];
      if (isCurrentlyLiked) {
        updatedTweet.likes.remove(userId);
      } else {
        updatedTweet.likes.add(userId);
      }
      _tweets[tweetIndex] = updatedTweet;
    }

    // Update tweet detail
    final detailTweet = _tweetDetails[tweetId];
    if (detailTweet != null) {
      if (isCurrentlyLiked) {
        detailTweet.likes.remove(userId);
      } else {
        detailTweet.likes.add(userId);
      }
    }

    notifyListeners();
    await _tweetService.toggleLikeTweet(tweetId, userId);
  }

  Future<void> toggleLikeForComment(
    String tweetId,
    String commentId,
    int commentIndex,
    bool isCurrentlyLiked,
  ) async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? "";
    if (userId.isEmpty) return;

    // Update tweet detail
    final detailTweet = _tweetDetails[tweetId];
    if (detailTweet != null && commentIndex < detailTweet.comments.length) {
      if (isCurrentlyLiked) {
        detailTweet.comments[commentIndex].likes.remove(userId);
      } else {
        detailTweet.comments[commentIndex].likes.add(userId);
      }
    }

    // Update main tweets list
    final tweetIndex = _tweets.indexWhere((t) => t.id == tweetId);
    if (tweetIndex != -1 &&
        commentIndex < _tweets[tweetIndex].comments.length) {
      if (isCurrentlyLiked) {
        _tweets[tweetIndex].comments[commentIndex].likes.remove(userId);
      } else {
        _tweets[tweetIndex].comments[commentIndex].likes.add(userId);
      }
    }

    notifyListeners();
    await _tweetService.toggleLikeComment(
      tweetId: tweetId,
      commentId: commentId,
      userId: userId,
    );
  }

  Future<void> toggleLikeForReply(
    String tweetId,
    String commentId,
    String replyId,
    int commentIndex,
    int replyIndex,
    bool isCurrentlyLiked,
  ) async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? "";
    if (userId.isEmpty) return;

    // Update tweet detail
    final detailTweet = _tweetDetails[tweetId];
    if (detailTweet != null &&
        commentIndex < detailTweet.comments.length &&
        replyIndex < detailTweet.comments[commentIndex].replies.length) {
      if (isCurrentlyLiked) {
        detailTweet.comments[commentIndex].replies[replyIndex].likes.remove(
          userId,
        );
      } else {
        detailTweet.comments[commentIndex].replies[replyIndex].likes.add(
          userId,
        );
      }
    }

    // Update main tweets list
    final tweetIndex = _tweets.indexWhere((t) => t.id == tweetId);
    if (tweetIndex != -1 &&
        commentIndex < _tweets[tweetIndex].comments.length &&
        replyIndex <
            _tweets[tweetIndex].comments[commentIndex].replies.length) {
      if (isCurrentlyLiked) {
        _tweets[tweetIndex].comments[commentIndex].replies[replyIndex].likes
            .remove(userId);
      } else {
        _tweets[tweetIndex].comments[commentIndex].replies[replyIndex].likes
            .add(userId);
      }
    }

    notifyListeners();
    await _tweetService.toggleLikeForReply(
      tweetId: tweetId,
      commentId: commentId,
      replyId: replyId,
      userId: userId,
    );
  }

  Future<void> shareTweet() async {
    notifyListeners();
  }

  // Future<void> refreshTweets() async {
  //   try {
  //     _isLoading = true;
  //     notifyListeners();
  //
  //     _tweetsSubscription?.cancel();
  //     _tweetsSubscription = null;
  //
  //     final freshTweets = await _tweetService
  //         .getTweetsWithCommentsAndReplies()
  //         .first;
  //     _tweets = freshTweets;
  //
  //     _subscribeToTweets();
  //     notifyListeners();
  //   } catch (e) {
  //     debugPrint('Error refreshing tweets: $e');
  //     _isLoading = false;
  //     notifyListeners();
  //     _subscribeToTweets();
  //   }
  // }

  Future<Map<String, UserConverter>> fetchAllStudents(List<TweetModel> tweets) async {
    try {
      //final users = await UserService().getAllUsers();
      final studentIds = tweets
          .map((t) => t.userId)
          .where((id) => id.isNotEmpty)
          .toSet();
      final studentFutures = studentIds.map(
            (id) => UserService().getUser(id),
      );
      final studentResults = await Future.wait(
        studentFutures,
        eagerError: false,
      );

      final studentMap = <String, UserConverter>{};
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

    final removed = _tweets.removeAt(idx);
    notifyListeners();

    // Also remove from tweet details
    unsubscribeFromTweetDetail(tweetId);

    try {
      await _tweetService.deleteTweet(tweetId);
    } catch (e) {
      _tweets.insert(idx, removed);
      notifyListeners();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete. Please retry.')),
      );
    }
  }

  Future<void> deleteComment(String tweetId, int commentIndex) async {
    final detailTweet = _tweetDetails[tweetId];
    if (detailTweet == null || commentIndex >= detailTweet.comments.length)
      return;

    final commentId = detailTweet.comments[commentIndex].id ?? '';

    // Remove from tweet detail
    detailTweet.comments.removeAt(commentIndex);

    // Remove from main tweets list
    final tweetIndex = _tweets.indexWhere((t) => t.id == tweetId);
    if (tweetIndex != -1 &&
        commentIndex < _tweets[tweetIndex].comments.length) {
      _tweets[tweetIndex].comments.removeAt(commentIndex);
    }

    // Remove from comments list
    final comments = _tweetComments[tweetId];
    if (comments != null) {
      comments.removeWhere((c) => c.id == commentId);
    }

    notifyListeners();

    await _tweetService.deleteComment(tweetId: tweetId, commentId: commentId);
  }

  Future<void> deleteReply(
    String tweetId,
    String commentId,
    int commentIndex,
    int replyIndex,
  ) async {
    final detailTweet = _tweetDetails[tweetId];
    if (detailTweet == null ||
        commentIndex >= detailTweet.comments.length ||
        replyIndex >= detailTweet.comments[commentIndex].replies.length)
      return;

    final replyId =
        detailTweet.comments[commentIndex].replies[replyIndex].id ?? '';

    // Remove from tweet detail
    detailTweet.comments[commentIndex].replies.removeAt(replyIndex);

    // Remove from main tweets list
    final tweetIndex = _tweets.indexWhere((t) => t.id == tweetId);
    if (tweetIndex != -1 &&
        commentIndex < _tweets[tweetIndex].comments.length &&
        replyIndex <
            _tweets[tweetIndex].comments[commentIndex].replies.length) {
      _tweets[tweetIndex].comments[commentIndex].replies.removeAt(replyIndex);
    }

    notifyListeners();

    await _tweetService.deleteReply(
      tweetId: tweetId,
      commentId: commentId,
      replyId: replyId,
    );
  }

  void addCommentToTweet(String tweetId, Comment comment) {
    final tweetIndex = _tweets.indexWhere((tweet) => tweet.id == tweetId);
    if (tweetIndex != -1) {
      _tweets[tweetIndex].comments.add(comment);
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

  @override
  void dispose() {
    _tweetsSubscription?.cancel();

    // Cancel all tweet detail subscriptions
    _tweetDetailSubscriptions.values.forEach((sub) => sub.cancel());
    _tweetCommentsSubscriptions.values.forEach((sub) => sub.cancel());

    super.dispose();
  }

  tweetControllerTextChanged() {
    notifyListeners();
    //debugPrint("tweetControllerTextChanged changed");
  }

  mainCommentTextChange() {
    notifyListeners();
  }

  replyTextChange() {
    notifyListeners();
  }
}

class StudentCache {
  static final Map<String, UserConverter> _cache = {};

  static Future<UserConverter?> getStudent(String id) async {
    if (_cache.containsKey(id)) return _cache[id];
    final student = await UserService().getUser(id);
    if (student != null) {
      _cache[id] = student;
    }
    return student;
  }
}
