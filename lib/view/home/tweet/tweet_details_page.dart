import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:itc_institute_admin/itc_logic/service/ConverterUserService.dart';
import 'package:itc_institute_admin/model/userProfile.dart';
import 'package:itc_institute_admin/view/home/tweet/user_selection_dialog.dart';
import 'package:provider/provider.dart';
import '../../../itc_logic/idservice/globalIdService.dart';
import '../../../../../model/comments_model.dart';
import '../../../../../model/reply_model.dart';
import '../../../auth/tweet_provider.dart';
import '../../../generalmethods/GeneralMethods.dart';
import '../../../model/tweetModel.dart';
import 'commentDetailPage.dart';
import 'expandable_text.dart';

class TweetDetailPage extends StatefulWidget {
  final String tweetId;
  final UserConverter author;
  final UserConverter currentUser;

  const TweetDetailPage({
    required this.tweetId,
    required this.author,
    required this.currentUser,
  });

  @override
  State<TweetDetailPage> createState() => _TweetDetailPageState();
}

class _TweetDetailPageState extends State<TweetDetailPage> {
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _commentFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TweetProvider>().subscribeToTweetDetail(widget.tweetId);
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    _commentFocusNode.dispose();
    context.read<TweetProvider>().unsubscribeFromTweetDetail(widget.tweetId);
    super.dispose();
  }

  void _focusCommentField() {
    _commentFocusNode.requestFocus();
  }

  Future<void> _submitComment() async {
    final commentText = _commentController.text.trim();
    if (commentText.isEmpty) return;

    final textToSubmit = commentText;
    _commentController.clear();

    try {
      await context.read<TweetProvider>().postCommentToTweet(
        widget.tweetId,
        textToSubmit,
        widget.currentUser,
      );

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Comment posted!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      _commentController.text = textToSubmit;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to post comment: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _navigateToCommentDetail(Comment comment, int commentIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CommentDetailPage(
          tweetId: widget.tweetId,
          comment: comment,
          commentIndex: commentIndex,
          currentUser: widget.currentUser,
          tweetAuthor: widget.author,
        ),
      ),
    );
  }

  void _navigateToReplyDetail(Comment comment, int commentIndex, Reply reply, int replyIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CommentDetailPage(
          tweetId: widget.tweetId,
          comment: comment,
          commentIndex: commentIndex,
          currentUser: widget.currentUser,
          tweetAuthor: widget.author,
          selectedReply: reply,
          selectedReplyIndex: replyIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Post',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: _TweetDetailBody(
              student: widget.author,
              tweetId: widget.tweetId,
              currentUser: widget.currentUser,
              onCommentTap: _navigateToCommentDetail,
              onReplyTap: _navigateToReplyDetail,
              onCommentIconTap: _focusCommentField,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[900] : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                ),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundImage: NetworkImage(widget.currentUser.imageUrl),
                  backgroundColor: Colors.grey[300],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[800] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: TextField(
                      controller: _commentController,
                      focusNode: _commentFocusNode,
                      decoration: InputDecoration(
                        hintText: 'Write a comment...',
                        hintStyle: TextStyle(
                          color: isDark ? Colors.grey[500] : Colors.grey[500],
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _commentController,
                  builder: (context, value, _) {
                    return GestureDetector(
                      onTap: value.text.trim().isEmpty ? null : _submitComment,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: value.text.trim().isEmpty
                              ? (isDark ? Colors.grey[800] : Colors.grey[200])
                              : const Color(0xFF1877F2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.send,
                          size: 18,
                          color: value.text.trim().isEmpty
                              ? (isDark ? Colors.grey[600] : Colors.grey[500])
                              : Colors.white,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TweetDetailBody extends StatelessWidget {
  final UserConverter student;
  final String tweetId;
  final UserConverter currentUser;
  final Function(Comment, int) onCommentTap;
  final Function(Comment, int, Reply, int) onReplyTap;
  final VoidCallback onCommentIconTap;

  const _TweetDetailBody({
    required this.student,
    required this.tweetId,
    required this.currentUser,
    required this.onCommentTap,
    required this.onReplyTap,
    required this.onCommentIconTap,
  });

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 365) {
      return DateFormat('MMM d, yyyy').format(timestamp);
    } else if (difference.inDays > 7) {
      return DateFormat('MMM d').format(timestamp);
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  void _showCommentBottomSheet({
    required BuildContext bigContext,
    required Comment comment,
    required int commentIndex,
    required String tweetId,
    required String commentUserId,
    required String commentUserName,
    required bool isOwner,
  }) {
    final isDark = Theme.of(bigContext).brightness == Brightness.dark;

    showModalBottomSheet(
      context: bigContext,
      backgroundColor: isDark ? Colors.grey[850] : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[600] : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            if (isOwner)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Delete Comment'),
                onTap: () {
                  Navigator.pop(bigContext);
                  _showDeleteConfirmation(
                    bigContext,
                    'Delete this comment?',
                        () => bigContext.read<TweetProvider>().deleteComment(tweetId, commentIndex),
                  );
                },
              ),
            ListTile(
              leading: const Icon(Icons.reply_outlined),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(bigContext);
                // This will need to be handled - you might want to pass this up
                ScaffoldMessenger.of(bigContext).showSnackBar(
                  const SnackBar(content: Text('Reply functionality coming')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.content_copy_outlined),
              title: const Text('Copy Text'),
              onTap: () {
                Navigator.pop(bigContext);
                _copyToClipboard(bigContext, comment.content);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.report_outlined, color: Colors.orange),
              title: const Text('Report'),
              onTap: () {
                Navigator.pop(bigContext);
                _showReportDialog(bigContext, comment.id ?? '');
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showReplyBottomSheet({
    required BuildContext parentContext,
    required Reply reply,
    required int replyIndex,
    required String commentId,
    required int commentIndex,
    required String tweetId,
    required String replyUserId,
    required String replyUserName,
    required bool isOwner,
    required VoidCallback onReplyTap,
  }) {
    final isDark = Theme.of(parentContext).brightness == Brightness.dark;

    showModalBottomSheet(
      context: parentContext,
      backgroundColor: isDark ? Colors.grey[850] : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[600] : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            if (isOwner)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Delete Reply'),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteConfirmation(
                    context,
                    'Delete this reply?',
                        () => parentContext.read<TweetProvider>().deleteReply(
                      tweetId,
                      commentId,
                      commentIndex,
                      replyIndex,
                    ),
                  );
                },
              ),
            ListTile(
              leading: const Icon(Icons.reply_outlined),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(context);
                onReplyTap();
              },
            ),
            ListTile(
              leading: const Icon(Icons.content_copy_outlined),
              title: const Text('Copy Text'),
              onTap: () {
                Navigator.pop(context);
                _copyToClipboard(context, reply.content);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.report_outlined, color: Colors.orange),
              title: const Text('Report'),
              onTap: () {
                Navigator.pop(context);
                _showReportDialog(context, reply.id ?? '');
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _showReportDialog(BuildContext context, String id) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? Colors.grey[850] : Colors.white,
        title: Text(
          'Report Content',
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        ),
        content: Text(
          'Are you sure you want to report this content?',
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Reported. We will review it.'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            child: const Text(
              'Report',
              style: TextStyle(color: Colors.orange),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteConfirmation(
      BuildContext context,
      String message,
      Future<void> Function() onDelete,
      ) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? Colors.grey[850] : Colors.white,
        title: Text(
          'Confirm Delete',
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        ),
        content: Text(
          message,
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Cancel',
              style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
            ),
          ),
          TextButton(
            onPressed: () async {
              // Use dialogContext to close the dialog
              Navigator.pop(dialogContext);
              try {
                await onDelete();
                // Use the original context parameter, but check if it's mounted
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Deleted successfully'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              } catch (e,s) {
                debugPrint("error deletion $e");
                debugPrintStack(stackTrace: s);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext parentContext) {
    final isDark = Theme.of(parentContext).brightness == Brightness.dark;

    return Consumer<TweetProvider>(
      builder: (context, tweetProvider, _) {
        final tweet = tweetProvider.getTweetDetail(tweetId);
        final isLoading = tweetProvider.isTweetDetailLoading(tweetId);
        final error = tweetProvider.getTweetDetailError(tweetId);

        if (isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (error != null) {
          return Center(child: Text('Error: $error'));
        }
        if (tweet == null) {
          return const Center(child: Text('Post not found'));
        }

        final currentUserId = GlobalIdService.firestoreId ?? '';

        return ListView(
          controller: ScrollController(),
          children: [
            _buildPostCard(context, tweet, currentUserId,parentContext),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Comments',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  if (tweet.comments.isNotEmpty)
                    Text(
                      '${tweet.comments.length} total',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey[500] : Colors.grey[500],
                      ),
                    ),
                ],
              ),
            ),
            if (tweet.comments.isEmpty)
              _buildEmptyComments(context)
            else
              ...tweet.comments.asMap().entries.map((entry) {
                final index = entry.key;
                final comment = entry.value;
                return _buildCommentCard(
                  bigContext: parentContext,
                  comment: comment,
                  commentIndex: index,
                  currentUserId: currentUserId,
                  tweetId: tweet.id,
                  onCommentTap: () => onCommentTap(comment, index),
                  onReplyTap: (reply, replyIndex) => onReplyTap(comment, index, reply, replyIndex),
                );
              }),
            const SizedBox(height: 80),
          ],
        );
      },
    );
  }

  Widget _buildPostCard(BuildContext context, TweetModel tweet, String currentUserId,BuildContext parentContext) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOwner = tweet.userId == currentUserId;

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage: NetworkImage(student.imageUrl),
                backgroundColor: Colors.grey[300],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.uid.startsWith('admin_')
                          ? '${student.displayName.split(' ').first} ITC Rep'
                          : student.displayName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      _formatTimestamp(tweet.timestamp),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[500] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              if (isOwner)
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert,
                    color: isDark ? Colors.white70 : Colors.black54,
                    size: 20,
                  ),
                  onSelected: (value) {
                    if (value == 'delete') {
                      _showDeleteConfirmation(
                        context,
                        'Delete this post?',
                            () => parentContext.read<TweetProvider>().deleteTweet(tweet.id, context),
                      );
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, color: Colors.red, size: 20),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          ExpandableText(
            text: tweet.content,
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                if (tweet.likes.isNotEmpty)
                  Row(
                    children: [
                      const Icon(Icons.thumb_up, size: 14, color: Color(0xFF1877F2)),
                      const SizedBox(width: 4),
                      Text(
                        '${tweet.likes.length}',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                const SizedBox(width: 16),
                if (tweet.comments.isNotEmpty)
                  Text(
                    '${tweet.comments.length} comments',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildActionButton(
                context: context,
                icon: Icons.thumb_up_outlined,
                activeIcon: Icons.thumb_up,
                isActive: tweet.likes.contains(currentUserId),
                label: 'Like',
                onTap: () => context.read<TweetProvider>().toggleLike(
                  tweet.id,
                  currentUserId,
                  tweet.likes.contains(currentUserId),
                ),
              ),
              _buildActionButton(
                context: context,
                icon: Icons.chat_bubble_outline,
                activeIcon: Icons.chat_bubble,
                isActive: false,
                label: 'Comment',
                onTap: onCommentIconTap,
              ),
              _buildActionButton(
                context: context,
                icon: Icons.share_outlined,
                activeIcon: Icons.share,
                isActive: false,
                label: 'Share',
                onTap: () => _shareTweet(tweet.content, context, tweet.id),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommentCard({
    required BuildContext bigContext,
    required Comment comment,
    required int commentIndex,
    required String currentUserId,
    required String tweetId,
    required VoidCallback onCommentTap,
    required Function(Reply, int) onReplyTap,
  }) {
    final isDark = Theme.of(bigContext).brightness == Brightness.dark;
    final isOwner = comment.userId == currentUserId;

    return FutureBuilder<UserConverter?>(
      future: UserService().getUser(comment.userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final commentUser = snapshot.data!;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[850] : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onCommentTap,
              onLongPress: () {
                _showCommentBottomSheet(
                  bigContext: bigContext,
                  comment: comment,
                  commentIndex: commentIndex,
                  tweetId: tweetId,
                  commentUserId: comment.userId,
                  commentUserName: commentUser.displayName,
                  isOwner: isOwner,
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundImage: NetworkImage(commentUser.imageUrl),
                          backgroundColor: Colors.grey[300],
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 2,
                                children: [
                                  Text(
                                    commentUser.displayName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                  Text(
                                    _formatTimestamp(comment.timestamp),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isDark ? Colors.grey[500] : Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                comment.content,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.white70 : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  GestureDetector(
                                    onTap: () => _toggleCommentLike(
                                      context,
                                      tweetId,
                                      comment.id ?? '',
                                      commentIndex,
                                      comment.likes.contains(currentUserId),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          comment.likes.contains(currentUserId)
                                              ? Icons.thumb_up
                                              : Icons.thumb_up_outlined,
                                          size: 14,
                                          color: comment.likes.contains(currentUserId)
                                              ? const Color(0xFF1877F2)
                                              : (isDark ? Colors.grey[500] : Colors.grey[600]),
                                        ),
                                        if (comment.likes.isNotEmpty) ...[
                                          const SizedBox(width: 4),
                                          Text(
                                            '${comment.likes.length}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isDark ? Colors.grey[500] : Colors.grey[500],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  GestureDetector(
                                    onTap: onCommentTap,
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.reply_outlined,
                                          size: 14,
                                          color: isDark ? Colors.grey[500] : Colors.grey[500],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Reply',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDark ? Colors.grey[500] : Colors.grey[500],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (comment.replies.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.only(left: 26),
                        child: Column(
                          children: [
                            ...comment.replies.take(3).toList().asMap().entries.map((replyEntry) {
                              final replyIndex = replyEntry.key;
                              final reply = replyEntry.value;
                              return _buildReplyPreview(
                                bigContext: context,
                                reply: reply,
                                replyIndex: replyIndex,
                                comment: comment,
                                commentIndex: commentIndex,
                                currentUserId: currentUserId,
                                tweetId: tweetId,
                                onReplyTap: () => onReplyTap(reply, replyIndex),
                              );
                            }),
                            if (comment.replies.length > 3)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: GestureDetector(
                                  onTap: onCommentTap,
                                  child: Text(
                                    'View all ${comment.replies.length} replies',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: const Color(0xFF1877F2),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildReplyPreview({
    required BuildContext bigContext,
    required Reply reply,
    required int replyIndex,
    required Comment comment,
    required int commentIndex,
    required String currentUserId,
    required String tweetId,
    required VoidCallback onReplyTap,
  }) {
    final isDark = Theme.of(bigContext).brightness == Brightness.dark;
    final isOwner = reply.studentId == currentUserId;

    return FutureBuilder<UserConverter?>(
      future: UserService().getUser(reply.studentId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final replyUser = snapshot.data!;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onReplyTap,
              onLongPress: () {
                _showReplyBottomSheet(
                  parentContext: bigContext,
                  reply: reply,
                  replyIndex: replyIndex,
                  commentId: comment.id ?? '',
                  commentIndex: commentIndex,
                  tweetId: tweetId,
                  replyUserId: reply.studentId,
                  replyUserName: replyUser.displayName,
                  isOwner: isOwner,
                  onReplyTap: onReplyTap,
                );
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundImage: NetworkImage(replyUser.imageUrl),
                      backgroundColor: Colors.grey[300],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 4,
                            runSpacing: 2,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                replyUser.displayName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              if (reply.userReplyingTo != null && reply.userReplyingTo!.isNotEmpty)
                                Text(
                                  '→ @${reply.userReplyingTo}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: const Color(0xFF1877F2),
                                  ),
                                ),
                              Text(
                                _formatTimestamp(reply.postedAt),
                                style: TextStyle(
                                  fontSize: 9,
                                  color: isDark ? Colors.grey[500] : Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            reply.content,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () => _toggleReplyLike(
                                  context,
                                  tweetId,
                                  comment.id ?? '',
                                  reply.id ?? '',
                                  commentIndex,
                                  replyIndex,
                                  reply.likes.contains(currentUserId),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      reply.likes.contains(currentUserId)
                                          ? Icons.thumb_up
                                          : Icons.thumb_up_outlined,
                                      size: 10,
                                      color: reply.likes.contains(currentUserId)
                                          ? const Color(0xFF1877F2)
                                          : (isDark ? Colors.grey[500] : Colors.grey[600]),
                                    ),
                                    if (reply.likes.isNotEmpty) ...[
                                      const SizedBox(width: 2),
                                      Text(
                                        '${reply.likes.length}',
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: isDark ? Colors.grey[500] : Colors.grey[500],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              GestureDetector(
                                onTap: onReplyTap,
                                child: Text(
                                  'Reply',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isDark ? Colors.grey[500] : Colors.grey[500],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }


  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required IconData activeIcon,
    required bool isActive,
    required String label,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isActive ? activeIcon : icon,
                size: 20,
                color: isActive
                    ? const Color(0xFF1877F2)
                    : (isDark ? Colors.grey[400] : Colors.grey[600]),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isActive
                      ? const Color(0xFF1877F2)
                      : (isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyComments(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 48,
            color: isDark ? Colors.grey[600] : Colors.grey[400],
          ),
          const SizedBox(height: 12),
          Text(
            'No comments yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Be the first to comment',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey[500] : Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  void _toggleCommentLike(
      BuildContext context,
      String tweetId,
      String commentId,
      int commentIndex,
      bool isLiked,
      ) {
    context.read<TweetProvider>().toggleLikeForComment(
      tweetId,
      commentId,
      commentIndex,
      isLiked,
    );
  }

  void _toggleReplyLike(
      BuildContext context,
      String tweetId,
      String commentId,
      String replyId,
      int commentIndex,
      int replyIndex,
      bool isLiked,
      ) {
    context.read<TweetProvider>().toggleLikeForReply(
      tweetId,
      commentId,
      replyId,
      commentIndex,
      replyIndex,
      isLiked,
    );
  }
}

Future<void> _shareTweet(
    String content,
    BuildContext context,
    String tweetId,
    ) async {
  try {
    final provider = context.read<TweetProvider>();
    await showDialog(
      context: context,
      builder: (context) =>
          UserSelectionDialog(tweetContent: content, tweetId: tweetId),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Failed to share: $e'),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}