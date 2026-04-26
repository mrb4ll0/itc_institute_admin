import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../../model/comments_model.dart';
import '../../../../../model/reply_model.dart';
import '../../../../../model/userProfile.dart';
import '../../../auth/tweet_provider.dart';
import '../../../itc_logic/idservice/globalIdService.dart';
import '../../../itc_logic/service/userService.dart';


class CommentDetailPage extends StatefulWidget {
  final String tweetId;
  final Comment comment;
  final int commentIndex;
  final UserConverter currentUser;
  final UserConverter tweetAuthor;
  final Reply? selectedReply;
  final int? selectedReplyIndex;

  const CommentDetailPage({
    super.key,
    required this.tweetId,
    required this.comment,
    required this.commentIndex,
    required this.currentUser,
    required this.tweetAuthor,
    this.selectedReply,
    this.selectedReplyIndex,
  });

  @override
  State<CommentDetailPage> createState() => _CommentDetailPageState();
}

class _CommentDetailPageState extends State<CommentDetailPage> {
  final TextEditingController _replyController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _replyFocusNode = FocusNode();
  String? _replyingToUserId;
  String? _replyingToUserName;
  String? _parentReplyId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TweetProvider>().subscribeToTweetDetail(widget.tweetId);
    });

    if (widget.selectedReply != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToReply();
      });
    }
  }

  void _scrollToReply() {
    final replyIndex = widget.selectedReplyIndex ?? 0;
    _scrollController.animateTo(
      replyIndex * 100.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _replyController.dispose();
    _scrollController.dispose();
    _replyFocusNode.dispose();
    super.dispose();
  }

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

  Future<void> _showDeleteConfirmation(
      String message,
      Future<void> Function() onDelete,
      ) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await onDelete();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Deleted successfully'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              } catch (e) {
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
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                _setReplyTo(replyUserId, replyUserName, parentReplyId: reply.id);
              },
            ),
            ListTile(
              leading: const Icon(Icons.content_copy_outlined),
              title: const Text('Copy Text'),
              onTap: () {
                Navigator.pop(context);
                _copyToClipboard(reply.content,parentContext);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.report_outlined, color: Colors.orange),
              title: const Text('Report'),
              onTap: () {
                Navigator.pop(context);
                _showReportDialog(reply.id ?? '');
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _copyToClipboard(String text,BuildContext parentContext) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _showReportDialog(String replyId) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? Colors.grey[850] : Colors.white,
        title: Text(
          'Report Reply',
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        ),
        content: Text(
          'Are you sure you want to report this reply?',
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
                  content: Text('Reply reported. We will review it.'),
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

  void _setReplyTo(String userId, String userName, {String? parentReplyId}) {
    setState(() {
      _replyingToUserId = userId;
      _replyingToUserName = userName;
      _parentReplyId = parentReplyId;
      _replyController.text = '@$userName ';
      _replyController.selection = TextSelection.fromPosition(
        TextPosition(offset: _replyController.text.length),
      );
      _replyFocusNode.requestFocus();
    });
  }

  void _clearReplyTo() {
    setState(() {
      _replyingToUserId = null;
      _replyingToUserName = null;
      _parentReplyId = null;
    });
  }

  Future<void> _submitReply() async {
    final replyText = _replyController.text.trim();
    if (replyText.isEmpty) return;

    try {
      if (_parentReplyId != null) {
        await context.read<TweetProvider>().postReplyToReply(
          widget.tweetId,
          widget.comment.id ?? '',
          widget.commentIndex,
          0,
          replyText,
          widget.currentUser,
          _replyingToUserName ?? '',
          _replyingToUserId,
          _parentReplyId!,
        );
      } else {
        await context.read<TweetProvider>().postReplyDirect(
          widget.tweetId,
          widget.comment.id ?? '',
          widget.commentIndex,
          replyText,
          widget.currentUser,
          _replyingToUserName ?? '',
        );
      }
      _replyController.clear();
      _clearReplyTo();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reply posted!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to post reply: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext parentContext) {
    final isDark = Theme.of(parentContext).brightness == Brightness.dark;
    final currentUserId = GlobalIdService.firestoreId ?? '';

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
          'Comment',
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
            child: Consumer<TweetProvider>(
              builder: (context, tweetProvider, _) {
                final tweet = tweetProvider.getTweetDetail(widget.tweetId);

                if (tweet == null) {
                  return const Center(child: CircularProgressIndicator());
                }

                final updatedComment = tweet.comments.length > widget.commentIndex
                    ? tweet.comments[widget.commentIndex]
                    : widget.comment;

                return ListView(
                  controller: _scrollController,
                  children: [
                    _buildMainCommentCard(context, updatedComment, currentUserId),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text(
                        'Replies',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                    if (updatedComment.replies.isEmpty)
                      _buildEmptyReplies(context)
                    else
                      ...updatedComment.replies.asMap().entries.map((entry) {
                        final index = entry.key;
                        final reply = entry.value;
                        return _buildReplyItem(
                          parentContext: parentContext,
                          reply: reply,
                          replyIndex: index,
                          tweetId: widget.tweetId,
                          commentId: widget.comment.id ?? '',
                          commentIndex: widget.commentIndex,
                          currentUserId: currentUserId,
                          isHighlighted: widget.selectedReply?.id == reply.id,
                          onReplyToReply: (replyId, userId, userName) {
                            _setReplyTo(userId, userName, parentReplyId: replyId);
                          },
                        );
                      }).toList(),
                    const SizedBox(height: 100),
                  ],
                );
              },
            ),
          ),
          // Reply input
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_replyingToUserName != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1877F2).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.reply, size: 14, color: Color(0xFF1877F2)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Replying to @$_replyingToUserName',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF1877F2),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: _clearReplyTo,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                Row(
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
                          controller: _replyController,
                          focusNode: _replyFocusNode,
                          decoration: InputDecoration(
                            hintText: _replyingToUserName != null
                                ? 'Write your reply...'
                                : 'Write a reply...',
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
                      valueListenable: _replyController,
                      builder: (context, value, _) {
                        return GestureDetector(
                          onTap: value.text.trim().isEmpty ? null : _submitReply,
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainCommentCard(BuildContext context, Comment comment, String currentUserId) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOwner = comment.userId == currentUserId;

    return FutureBuilder<UserConverter?>(
      future: UserService().getUser(comment.userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final commentUser = snapshot.data!;

        return Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[850] : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF1877F2).withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundImage: NetworkImage(commentUser.imageUrl),
                    backgroundColor: Colors.grey[300],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    commentUser.displayName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                  Text(
                                    _formatTimestamp(comment.timestamp),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.grey[500] : Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isOwner)
                              GestureDetector(
                                onTap: () => _showDeleteConfirmation(
                                  'Delete this comment?',
                                      () => context.read<TweetProvider>().deleteComment(
                                    widget.tweetId,
                                    widget.commentIndex,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: Icon(
                                    Icons.delete_outline,
                                    size: 20,
                                    color: Colors.red.withOpacity(0.7),
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
              const SizedBox(height: 16),
              Text(
                comment.content,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  GestureDetector(
                    onTap: () => _toggleCommentLike(
                      context,
                      widget.tweetId,
                      comment.id ?? '',
                      widget.commentIndex,
                      comment.likes.contains(currentUserId),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          comment.likes.contains(currentUserId)
                              ? Icons.thumb_up
                              : Icons.thumb_up_outlined,
                          size: 18,
                          color: comment.likes.contains(currentUserId)
                              ? const Color(0xFF1877F2)
                              : (isDark ? Colors.grey[500] : Colors.grey[600]),
                        ),
                        if (comment.likes.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Text(
                            '${comment.likes.length}',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  GestureDetector(
                    onTap: () => _setReplyTo(comment.userId, commentUser.displayName),
                    child: Row(
                      children: [
                        Icon(
                          Icons.reply_outlined,
                          size: 18,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Reply',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReplyItem({
    required BuildContext parentContext,
    required Reply reply,
    required String tweetId,
    required String commentId,
    required int commentIndex,
    required int replyIndex,
    required String currentUserId,
    required bool isHighlighted,
    required Function(String, String, String) onReplyToReply,
  }) {
    final isDark = Theme.of(parentContext).brightness == Brightness.dark;
    final isOwner = reply.studentId == currentUserId;

    return FutureBuilder<UserConverter?>(
      future: UserService().getUser(reply.studentId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final replyUser = snapshot.data!;

        return GestureDetector(
          onLongPress: () {
            _showReplyBottomSheet(
              parentContext: parentContext,
              reply: reply,
              replyIndex: replyIndex,
              commentId: commentId,
              commentIndex: commentIndex,
              tweetId: tweetId,
              replyUserId: reply.studentId,
              replyUserName: replyUser.displayName,
              isOwner: isOwner,
            );
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[850] : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isHighlighted
                    ? const Color(0xFF1877F2).withOpacity(0.5)
                    : (isDark ? Colors.grey[800]! : Colors.grey[200]!),
                width: isHighlighted ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundImage: NetworkImage(replyUser.imageUrl),
                      backgroundColor: Colors.grey[300],
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // User info with proper wrapping
                          Wrap(
                            spacing: 4,
                            runSpacing: 2,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                replyUser.displayName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              if (reply.userReplyingTo != null && reply.userReplyingTo!.isNotEmpty)
                                Text(
                                  '→ @${reply.userReplyingTo}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: const Color(0xFF1877F2),
                                  ),
                                ),
                              Text(
                                _formatTimestamp(reply.postedAt),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.grey[500] : Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  reply.content,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                const SizedBox(height: 12), // Increased from 8
                // Action Buttons Row - Larger and more tappable
                Row(
                  children: [
                    // Like Button - Larger
                    GestureDetector(
                      onTap: () => _toggleReplyLike(
                        context,
                        tweetId,
                        commentId,
                        reply.id ?? '',
                        commentIndex,
                        replyIndex,
                        reply.likes.contains(currentUserId),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Row(
                          children: [
                            Icon(
                              reply.likes.contains(currentUserId)
                                  ? Icons.thumb_up
                                  : Icons.thumb_up_outlined,
                              size: 20, // Increased from 14
                              color: reply.likes.contains(currentUserId)
                                  ? const Color(0xFF1877F2)
                                  : (isDark ? Colors.grey[400] : Colors.grey[600]),
                            ),
                            const SizedBox(width: 6), // Increased from 4
                            if (reply.likes.isNotEmpty) ...[
                              Text(
                                '${reply.likes.length}',
                                style: TextStyle(
                                  fontSize: 14, // Increased from 12
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8), // Increased from 16 to give more space
                    // Reply Button - Larger
                    GestureDetector(
                      onTap: () => onReplyToReply(reply.id ?? '', reply.studentId, replyUser.displayName),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Row(
                          children: [
                            Icon(
                              Icons.reply_outlined,
                              size: 20, // Increased from 14
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                            const SizedBox(width: 6), // Increased from 4
                            Text(
                              'Reply',
                              style: TextStyle(
                                fontSize: 14, // Increased from 12
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.grey[300] : Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyReplies(BuildContext context) {
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
            'No replies yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Be the first to reply',
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
    HapticFeedback.lightImpact();
  }
}