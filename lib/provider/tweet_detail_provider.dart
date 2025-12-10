import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:itc_institute_admin/auth/tweet_provider.dart';

import '../itc_logic/firebase/tweet/tweet_cloud.dart';
import '../model/comments_model.dart';
import '../model/reply_model.dart';
import '../model/student.dart';
import '../model/tweetModel.dart';

class TweetDetailProvider extends ChangeNotifier {
  final TweetService _tweetService = TweetService();
  final String tweetId;

  TweetModel? _tweet;
  List<Comment> _comments = [];
  List<Reply> _replies = [];

  bool _isLoading = true;
  String? _error;

  String? _replyingToCommentId;
  String? _replyingToCommentContent;
  String? _replyingToReplyId;
  String? _replyingToReplyContent;
  String? _replyingToTweetId;
  String? _replyingToTweetContent;

  StreamSubscription<TweetModel?>? _tweetSub;
  StreamSubscription<List<Comment>>? _commentsSub;
  StreamSubscription<List<Reply>>? _repliesSub;

  TweetDetailProvider({required this.tweetId}) {
    _subscribeToTweet();
    _subscribeToComments();
    //_subscribeToReplies();
  }

  // 🔹 Getters
  TweetModel? get tweet => _tweet;
  List<Comment> get comments => _comments;
  List<Reply> get replies => _replies;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get replyingToTweetId => _replyingToTweetId;
  String? get replyingToTweetContent => _replyingToTweetContent;

  String? get replyingToCommentId => _replyingToCommentId;
  String? get replyingToCommentContent => _replyingToCommentContent;
  String? get replyingToReplyId => _replyingToReplyId;
  String? get replyingToReplyContent => _replyingToReplyContent;

  // 🔹 Subscriptions
  void _subscribeToTweet() {
    _tweetSub?.cancel();
    _isLoading = true;
    notifyListeners();
    debugPrint(tweetId);
    _tweetSub = _tweetService
        .getTweetWithCommentsAndReplies(tweetId)
        .listen(
          (tweet) {
            _tweet = tweet;
            _isLoading = false;
            notifyListeners();
          },
          onError: (e) {
            _error = e.toString();
            debugPrint(e.toString());
            _isLoading = false;
            notifyListeners();
          },
        );
  }

  void setReplyingToTweetId(tweetId, content) {
    _replyingToTweetId = tweetId;
    _replyingToTweetContent = content;
    notifyListeners();
  }

  void setReplyingToCommentId(commentId, content) {
    _replyingToCommentId = commentId;
    _replyingToCommentContent = content;
    notifyListeners();
  }

  void setReplyingToReplyId(replyId, content) {
    _replyingToReplyId = replyId;
    _replyingToReplyContent = content;
    notifyListeners();
  }

  void _subscribeToComments() {
    _commentsSub?.cancel();
    _commentsSub = _tweetService
        .fetchComments(tweetId: tweetId)
        .listen(
          (comments) {
            _comments = comments;
            notifyListeners();
          },
          onError: (e) {
            _error = e.toString();
            notifyListeners();
          },
        );
  }

  // void _subscribeToReplies() {
  //   _repliesSub?.cancel();
  //   _repliesSub = _tweetService.fetchReplies(tweetId: tweetId, co).listen(
  //       (replies)
  //           {
  //             _replies = replies;
  //             notifyListeners();
  //           }
  //   );
  // }

  // 🔹 Reply / Comment state handling
  void startReplyToComment(String commentId, String content) {
    _replyingToCommentId = commentId;
    _replyingToCommentContent = content;
    notifyListeners();
  }

  void cancelReplyToComment() {
    _replyingToCommentId = null;
    _replyingToCommentContent = null;
    notifyListeners();
  }

  void startCommentToReply(String replyId, String content) {
    _replyingToReplyId = replyId;
    _replyingToReplyContent = content;
    notifyListeners();
  }

  void cancelCommentToReply() {
    _replyingToReplyId = null;
    _replyingToReplyContent = null;
    notifyListeners();
  }

  // 🔹 Actions
  Future<void> postComment(
    String content,
    Student student,
    TweetProvider tweetProvider,
  ) async {
    if (content.isEmpty) return;
    final userId = FirebaseAuth.instance.currentUser?.uid ?? "";

    Comment comment = await _tweetService.postComment(
      tweetId: tweetId,
      student: student,
      content: content,
    );
    if (tweet == null) {
      notifyListeners();
    } else {
      tweet?.comments.insert(0, comment);
      notifyListeners();

      tweetProvider.addCommentToTweet(tweetId, comment);
    }
    notifyListeners();
  }

  Future<void> postReply(
    String commentId,
    int index,
    String content,
    Student student,
    TweetProvider provider,
    String userReplyingTo,
  ) async {
    if (content.isEmpty) return;
    Reply reply = await _tweetService.postReply(
      userReplyingTo: userReplyingTo,
      tweetId: tweetId,
      commentId: commentId,
      student: student,
      content: content,
    );
    tweet?.comments[index].replies.insert(0, reply);
    notifyListeners();
  }

  Future<void> postMention({
    required String commentId,
    required int index,
    required String content,
    required Student student,
    required TweetProvider provider,
    required String mentionedId,
    required String userReplyingTo,
  }) async {
    if (content.isEmpty) return;
    Reply reply = await _tweetService.postReply(
      userReplyingTo: userReplyingTo,
      tweetId: tweetId,
      commentId: commentId,
      student: student,
      content: "@$userReplyingTo#${mentionedId}## $content",
    );
    tweet?.comments[index].replies.add(reply);
    notifyListeners();
  }

  Future<void> toggleLike(bool isCurrentlyLiked) async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? "";
    if (_tweet == null || userId.isEmpty) return;

    // optimistic update
    if (isCurrentlyLiked) {
      _tweet!.likes.remove(userId);
    } else {
      _tweet!.likes.add(userId);
    }
    notifyListeners();

    await _tweetService.toggleLikeTweet(tweetId, userId);
  }

  Future<void> toggleLikeForComment(bool isCurrentlyLiked, int index) async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? "";
    if (_tweet == null || userId.isEmpty) return;

    // optimistic update
    if (isCurrentlyLiked) {
      _tweet!.comments[index].likes.remove(userId);
    } else {
      _tweet!.comments[index].likes.add(userId);
    }
    notifyListeners();
    await _tweetService.toggleLikeComment(
      tweetId: tweetId,
      commentId: _tweet!.comments[index].id ?? "",
      userId: userId,
    );
  }

  Future<void> toggleLikeForReply(
    bool isCurrentlyLiked,
    int commentIndex,
    int replyIndex,
  ) async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? "";
    if (_tweet == null || userId.isEmpty) return;

    // optimistic update
    if (isCurrentlyLiked) {
      _tweet!.comments[commentIndex].replies[replyIndex].likes.remove(userId);
    } else {
      _tweet!.comments[commentIndex].replies[replyIndex].likes.add(userId);
    }
    notifyListeners();
    await _tweetService.toggleLikeForReply(
      tweetId: tweetId,
      commentId: _tweet!.comments[commentIndex].id ?? "",
      replyId: _tweet!.comments[commentIndex].replies[replyIndex].id ?? '',
      userId: userId,
    );
  }

  // 🔹 Clean up
  @override
  void dispose() {
    _tweetSub?.cancel();
    _commentsSub?.cancel();
    _repliesSub?.cancel();
    super.dispose();
  }

  void cancelReplyingToTweet() {
    _replyingToTweetId = null;
    _replyingToTweetContent = null;
    notifyListeners();
  }

  Future<void> deleteComment(
    tweetId,
    int index,
    TweetProvider tweetProvider,
  ) async {
    notifyListeners();
    await _tweetService.deleteComment(
      tweetId: tweetId,
      commentId: tweet?.comments[index].id ?? '',
    );
    tweet?.comments.removeAt(index);
    notifyListeners();
    tweetProvider.removeCommentFromTweet(
      tweetId,
      tweet?.comments[index].id ?? '',
    );
  }

  Future<void> deleteReply(
    String commentId,
    int commentIndex,
    int replyIndex,
    TweetProvider tweetProvider,
  ) async {
    final replyId = tweet?.comments[commentIndex].replies[replyIndex].id ?? "";

    if (replyId.isEmpty) {
      debugPrint("❌ Reply ID is empty, cannot delete");
      return;
    }

    await _tweetService.deleteReply(
      tweetId: tweetId,
      commentId: tweet?.comments[commentIndex].id ?? '',
      replyId: replyId,
    );

    // Remove locally
    tweet?.comments[commentIndex].replies.removeAt(replyIndex);
    notifyListeners();

    // Keep global state consistent
    tweetProvider.removeReplyFromComment(tweetId, commentId, replyId);

    debugPrint("✅ Reply $replyId deleted successfully");
  }
}
