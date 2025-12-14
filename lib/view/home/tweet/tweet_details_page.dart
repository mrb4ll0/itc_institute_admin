import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:itc_institute_admin/itc_logic/service/ConverterUserService.dart';
import 'package:itc_institute_admin/model/userProfile.dart';
import 'package:itc_institute_admin/view/home/tweet/user_selection_dialog.dart';
import 'package:provider/provider.dart';

import '../../../../../model/comments_model.dart';
import '../../../../../model/reply_model.dart';
import '../../../auth/tweet_provider.dart';
import '../../../model/tweetModel.dart';
import 'expandable_text.dart';

class TweetDetailPage extends StatefulWidget {
  final String tweetId;
  final UserConverter company;
  final UserConverter user;

  const TweetDetailPage({
    required this.tweetId,
    required this.company,
    required this.user,
  });

  @override
  State<TweetDetailPage> createState() => _TweetDetailPageState();
}

class _TweetDetailPageState extends State<TweetDetailPage> {
  final TextEditingController _mainCommentController = TextEditingController();
  bool _isSubmittingMainComment = false;
  final _scrollController = ScrollController();
  final ValueNotifier<String> _mainCommentText = ValueNotifier('');
  final ValueNotifier<String> _replyText = ValueNotifier('');
  Timer? _debounceTimer;
  final FocusNode _commentFocusNode = FocusNode(); // Add this
  void _focusCommentField() {
    _commentFocusNode.requestFocus();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TweetProvider>().subscribeToTweetDetail(widget.tweetId);
    });
    // Add debouncing to text listeners
    _mainCommentController.addListener(() {
      if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 50), () {
        if (mounted) {
          _mainCommentText.value = _mainCommentController.text;
        }
      });
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _mainCommentController.dispose();
    _scrollController.dispose();
    context.read<TweetProvider>().unsubscribeFromTweetDetail(widget.tweetId);
    _mainCommentText.dispose();
    _replyText.dispose();
    super.dispose();
  }

  void _showReplyDialog({
    String? commentId,
    String? commentContent,
    int? commentIndex,
    bool isSubReply = false,
  }) {
    final replyController = TextEditingController();
    bool isSubmitting = false;

    replyController.addListener(() {
      _replyText.value = replyController.text;
    });

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final colorScheme = Theme.of(context).colorScheme;
            final textTheme = Theme.of(context).textTheme;

            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 16),
              contentPadding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              content: Container(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: colorScheme.outline.withOpacity(0.1),
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            commentId == null ? 'Add Comment' : 'Reply',
                            style: textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(
                              Icons.close,
                              color: colorScheme.onSurfaceVariant,
                              size: 24,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),

                    // Context preview for replies
                    if (commentContent != null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceVariant.withOpacity(0.1),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.reply,
                              size: 16,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                commentContent.length > 100
                                    ? '${commentContent.substring(0, 100)}...'
                                    : commentContent,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Input section
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // User avatar
                          CircleAvatar(
                            radius: 20,
                            backgroundImage: NetworkImage(
                              widget.company.imageUrl,
                            ),
                            backgroundColor: colorScheme.surfaceVariant,
                          ),
                          const SizedBox(width: 12),

                          // Text input
                          Expanded(
                            child: TextField(
                              controller: replyController,
                              maxLines: 4,
                              minLines: 1,
                              autofocus: true,
                              decoration: InputDecoration(
                                hintText:
                                    'Write your ${isSubReply ? 'reply' : 'comment'}...',
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Action buttons
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 12),
                          ValueListenableBuilder<String>(
                            valueListenable: _replyText,
                            builder: (context, text, _) {
                              return ElevatedButton(
                                onPressed: isSubmitting || text.trim().isEmpty
                                    ? null
                                    : () async {
                                        setState(() => isSubmitting = true);
                                        await _submitReply(
                                          replyController,
                                          commentId: commentId,
                                          commentIndex: commentIndex,
                                        );
                                        setState(() => isSubmitting = false);
                                        if (mounted) Navigator.pop(context);
                                      },
                                child: isSubmitting
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(isSubReply ? 'Reply' : 'Comment'),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _submitMainComment() async {
    final commentText = _mainCommentController.text.trim();
    if (commentText.isEmpty) return;

    setState(() => _isSubmittingMainComment = true);

    try {
      await context.read<TweetProvider>().postCommentToTweet(
        widget.tweetId,
        commentText,
        widget.user,
      );

      _mainCommentController.clear();

      // Scroll to show new comment
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Comment added!'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (e, s) {
      debugPrint("error posting comment: $e");
      debugPrintStack(stackTrace: s);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to post: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } finally {
      setState(() => _isSubmittingMainComment = false);
    }
  }

  Future<void> _submitReply(
    TextEditingController controller, {
    String? commentId,
    int? commentIndex,
  }) async {
    final replyText = controller.text.trim();
    if (replyText.isEmpty) return;

    final tweetProvider = context.read<TweetProvider>();

    try {
      if (commentId != null && commentIndex != null) {
        await tweetProvider.postReply(
          widget.tweetId,
          commentId,
          commentIndex,
          replyText,
          widget.user,
          '',
        );
        _replyText.value = '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reply added!'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e, s) {
      debugPrint("error posting reply: $e");
      debugPrintStack(stackTrace: s);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to post: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLocked =
        context.select<TweetProvider, bool?>(
          (provider) => provider.getTweetDetail(widget.tweetId)?.lock,
        ) ??
        false;
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: NestedScrollView(
              controller: _scrollController,
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverAppBar(
                    floating: true,
                    pinned: true,
                    backgroundColor: colorScheme.surface,
                    surfaceTintColor: colorScheme.surfaceTint,
                    elevation: 0,
                    leading: IconButton(
                      icon: Icon(
                        Icons.arrow_back,
                        color: colorScheme.onSurface,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    title: Text(
                      'Post',
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    centerTitle: true,
                  ),
                ];
              },
              body: _TweetDetailBody(
                focusNodeTap: _focusCommentField,
                student: widget.company,
                tweetId: widget.tweetId,
                onReplyToComment: (commentId, commentContent, commentIndex) =>
                    _showReplyDialog(
                      commentId: commentId,
                      commentContent: commentContent,
                      commentIndex: commentIndex,
                      isSubReply: true,
                    ),
              ),
            ),
          ),

          // Fixed comment input field (Facebook style)
          if (!isLocked)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                border: Border(
                  top: BorderSide(color: colorScheme.outline.withOpacity(0.1)),
                ),
              ),
              child: Row(
                children: [
                  // User avatar
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: NetworkImage(widget.user.imageUrl),
                    backgroundColor: colorScheme.surfaceVariant,
                  ),
                  const SizedBox(width: 12),

                  // Text input
                  Expanded(
                    child: TextField(
                      controller: _mainCommentController,
                      maxLines: 4,
                      minLines: 1,
                      focusNode: _commentFocusNode,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Write a comment...',
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        filled: true,
                        fillColor: colorScheme.surfaceVariant.withOpacity(0.4),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(
                            color: colorScheme.primary,
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Send button
                  ValueListenableBuilder<String>(
                    valueListenable: _mainCommentText,
                    builder: (context, text, _) {
                      return IconButton(
                        onPressed:
                            _isSubmittingMainComment || text.trim().isEmpty
                            ? null
                            : _submitMainComment,
                        icon: _isSubmittingMainComment
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                Icons.send,
                                color: text.trim().isNotEmpty
                                    ? colorScheme.primary
                                    : colorScheme.onSurfaceVariant,
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
  final Function(String, String, int) onReplyToComment;
  final VoidCallback? focusNodeTap;

  const _TweetDetailBody({
    this.focusNodeTap,
    required this.student,
    required this.tweetId,
    required this.onReplyToComment,
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

  Widget _buildReplyItem(
    Reply reply,
    String tweetId,
    String commentId,
    int commentIndex,
    int replyIndex,
    BuildContext context,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return FutureBuilder<UserConverter?>(
      future: UserService().getUser(reply.studentId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 100, // Give it a height while loading
            margin: const EdgeInsets.only(bottom: 12, left: 36),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        // FIX: Return an error placeholder instead of shrink
        if (!snapshot.hasData || snapshot.hasError) {
          return Container(
            height: 100, // Give it a height even on error
            margin: const EdgeInsets.only(bottom: 12, left: 36),
            child: const Center(child: Icon(Icons.error_outline)),
          );
        }

        final replyStudent = snapshot.data!;
        final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

        return Padding(
          padding: const EdgeInsets.only(bottom: 12, left: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Connection line
              // FIXED Connection line - Remove Expanded and alignment issues
              SizedBox(
                width: 24,
                child: Column(
                  mainAxisSize: MainAxisSize.min, // Important: Don't expand
                  children: [
                    Container(
                      width: 2,
                      height: 24,
                      color: colorScheme.outline.withOpacity(0.2),
                    ),
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: colorScheme.outline.withOpacity(0.4),
                        shape: BoxShape.circle,
                      ),
                    ),
                    // FIX: Remove Expanded, use a Container with flex
                    Container(
                      width: 2,
                      constraints: BoxConstraints(
                        minHeight: 0,
                        maxHeight: double.infinity,
                      ),
                      color: colorScheme.outline.withOpacity(0.2),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Reply content
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceVariant.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Reply header
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceVariant.withOpacity(0.1),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundImage: NetworkImage(
                                replyStudent.imageUrl,
                              ),
                              backgroundColor: colorScheme.surfaceVariant,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    replyStudent.displayName,
                                    style: textTheme.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _formatTimestamp(reply.postedAt),
                                    style: textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (reply.studentId == currentUserId)
                              IconButton(
                                onPressed: () {
                                  _showDeleteReplyDialog(
                                    context,
                                    tweetId,
                                    commentId,
                                    commentIndex,
                                    reply.id ?? "",
                                    replyIndex,
                                  );
                                },
                                icon: Icon(
                                  Icons.more_vert,
                                  size: 20,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),

                      // Reply content
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          reply.content,
                          style: textTheme.bodyLarge?.copyWith(height: 1.5),
                        ),
                      ),

                      // Actions
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(16),
                          ),
                        ),
                        child: Row(
                          children: [
                            Consumer<TweetProvider>(
                              builder: (context, tweetProvider, _) {
                                final isLiked = reply.likes.contains(
                                  currentUserId,
                                );
                                return FilledButton.tonalIcon(
                                  onPressed: () {
                                    tweetProvider.toggleLikeForReply(
                                      tweetId,
                                      commentId,
                                      reply.id ?? "",
                                      commentIndex,
                                      replyIndex,
                                      isLiked,
                                    );
                                  },
                                  icon: Icon(
                                    isLiked
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    size: 18,
                                  ),
                                  label: Text('${reply.likes.length}'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: isLiked
                                        ? colorScheme.errorContainer
                                        : null,
                                    foregroundColor: isLiked
                                        ? colorScheme.onErrorContainer
                                        : null,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton.icon(
                              onPressed: () {
                                onReplyToComment(
                                  commentId,
                                  reply.content,
                                  commentIndex,
                                );
                              },
                              icon: const Icon(Icons.reply, size: 18),
                              label: const Text('Reply'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDeleteReplyDialog(
    BuildContext context,
    String tweetId,
    String commentId,
    int commentIndex,
    String replyId,
    int replyIndex,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        final textTheme = Theme.of(context).textTheme;

        return AlertDialog(
          title: Text(
            'Delete Reply',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          content: Text(
            'Are you sure you want to delete this reply? This action cannot be undone.',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(context);
                await _deleteReply(
                  context,
                  tweetId,
                  commentId,
                  commentIndex,
                  replyId,
                  replyIndex,
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
              ),
              child: const Text('Delete'),
            ),
          ],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        );
      },
    );
  }

  Future<void> _deleteReply(
    BuildContext context,
    String tweetId,
    String commentId,
    int commentIndex,
    String replyId,
    int replyIndex,
  ) async {
    try {
      final tweetProvider = context.read<TweetProvider>();
      await tweetProvider.deleteReply(
        tweetId,
        commentId,
        commentIndex,
        replyIndex,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reply deleted'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TweetProvider>(
      builder: (context, tweetProvider, _) {
        final tweet = tweetProvider.getTweetDetail(tweetId);
        final isLoading = tweetProvider.isTweetDetailLoading(tweetId);
        final error = tweetProvider.getTweetDetailError(tweetId);

        if (isLoading) return _buildLoadingState(context);
        if (error != null) return _buildErrorState(error, context);
        if (tweet == null) return _buildEmptyState(context);

        return _buildTweetDetail(tweet, tweetProvider, context);
      },
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: colorScheme.primary),
          const SizedBox(height: 20),
          Text(
            'Loading post...',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error, BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'Unable to load post',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 48,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Post not found',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'The post you\'re looking for doesn\'t exist or has been deleted.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTweetDetail(
    TweetModel tweet,
    TweetProvider tweetProvider,
    BuildContext context,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isLocked = tweet.lock ?? false;

    return CustomScrollView(
      slivers: [
        // Tweet content
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withOpacity(0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      // Avatar
                      CircleAvatar(
                        radius: 28,
                        backgroundImage: NetworkImage(student.imageUrl),
                        backgroundColor: colorScheme.surfaceVariant,
                      ),
                      const SizedBox(width: 16),

                      // User info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              student.displayName,
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatTimestamp(tweet.timestamp),
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Student badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Student',
                          style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Content
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    tweet.content,
                    style: textTheme.bodyLarge?.copyWith(height: 1.6),
                  ),
                ),

                const SizedBox(height: 24),

                // Stats and actions
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceVariant.withOpacity(0.1),
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildActionButton(
                            context: context,
                            icon: Icons.favorite_border,
                            activeIcon: Icons.favorite,
                            count: tweet.likes.length,
                            label: 'Likes',
                            isActive: tweet.likes.contains(currentUserId),
                            onTap: () {
                              tweetProvider.toggleLike(
                                tweet.id,
                                currentUserId,
                                tweet.likes.contains(currentUserId),
                              );
                            },
                          ),
                          _buildActionButton(
                            context: context,
                            icon: Icons.chat_bubble_outline,
                            activeIcon: Icons.chat_bubble,
                            count: tweet.comments.length,
                            label: 'Comments',
                            isActive: false,
                            onTap: focusNodeTap ?? () {},
                          ),
                          _buildActionButton(
                            context: context,
                            icon: Icons.share_outlined,
                            activeIcon: Icons.share,
                            count: tweet.shares.length,
                            label: 'Shares',
                            isActive: false,
                            onTap: () =>
                                _shareTweet(tweet.content, context, tweet.id),
                          ),
                        ],
                      ),
                      if (isLocked) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colorScheme.errorContainer.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: colorScheme.errorContainer.withOpacity(
                                0.3,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.lock_outline,
                                size: 18,
                                color: colorScheme.error,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Comments locked by author',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.error,
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
              ],
            ),
          ),
        ),

        // Comments section
        SliverPadding(
          padding: const EdgeInsets.only(top: 8),
          sliver: SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Text(
                'Comments',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),

        if (tweet.comments.isEmpty)
          SliverToBoxAdapter(child: _buildEmptyCommentsState(context))
        else
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final comment = tweet.comments[index];
              debugPrint("comment index ${index}");
              return _buildCommentItem(
                comment,
                tweet.id,
                index,
                context,
                tweetProvider,
              );
            }, childCount: tweet.comments.length),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  Widget _buildCommentItem(
    Comment comment,
    String tweetId,
    int index,
    BuildContext context,
    TweetProvider tweetProvider,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    // Add a local state to track if replies are shown
    bool showReplies = false;

    return FutureBuilder<UserConverter?>(
      future: UserService().getUser(comment.userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final commentStudent = snapshot.data!;

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Comment header
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundImage: NetworkImage(
                            commentStudent.imageUrl,
                          ),
                          backgroundColor: colorScheme.surfaceVariant,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      commentStudent.displayName,
                                      style: textTheme.bodyLarge?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Student',
                                      style: textTheme.labelSmall?.copyWith(
                                        color: colorScheme.onPrimaryContainer,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _formatTimestamp(comment.timestamp),
                                style: textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (comment.userId == currentUserId)
                          IconButton(
                            onPressed: () {
                              _showDeleteCommentDialog(
                                context,
                                tweetId,
                                index,
                                tweetProvider,
                              );
                            },
                            icon: Icon(
                              Icons.more_vert,
                              size: 20,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Comment content
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: ExpandableText(
                      isDark: Theme.of(context).brightness == Brightness.dark,
                      text: comment.content,
                    ),
                  ),

                  // Actions
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceVariant.withOpacity(0.1),
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      children: [
                        Consumer<TweetProvider>(
                          builder: (context, tweetProvider, _) {
                            final isLiked = comment.likes.contains(
                              currentUserId,
                            );
                            return FilledButton.tonalIcon(
                              onPressed: () {
                                tweetProvider.toggleLikeForComment(
                                  tweetId,
                                  comment.id ?? '',
                                  index,
                                  comment.likes.contains(currentUserId),
                                );
                              },
                              icon: Icon(
                                isLiked
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                size: 18,
                              ),
                              label: Text('${comment.likes.length}'),
                              style: FilledButton.styleFrom(
                                backgroundColor: isLiked
                                    ? colorScheme.errorContainer
                                    : null,
                                foregroundColor: isLiked
                                    ? colorScheme.onErrorContainer
                                    : null,
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              onReplyToComment(
                                comment.id ?? '',
                                comment.content,
                                index,
                              );
                            },
                            icon: const Icon(Icons.reply, size: 18),
                            label: Text(
                              comment.replies.isNotEmpty
                                  ? 'Reply (${comment.replies.length})'
                                  : 'Reply',
                            ),
                          ),
                        ),

                        // Add "Show Replies" button if there are replies
                        if (comment.replies.isNotEmpty) ...[
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                showReplies = !showReplies;
                              });
                            },
                            icon: Icon(
                              showReplies
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              size: 18,
                            ),
                            label: Text(showReplies ? 'Hide' : 'See'),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Replies - Only show when expanded
                  if (comment.replies.isNotEmpty && showReplies)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Replies header
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.subdirectory_arrow_right,
                                  size: 18,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Replies (${comment.replies.length})',
                                  style: textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Replies list
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (
                                int i = comment.replies.length - 1;
                                i >= 0;
                                i--
                              )
                                _buildReplyItem(
                                  comment.replies[i],
                                  tweetId,
                                  comment.id ?? '',
                                  index,
                                  i,
                                  context,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void _showDeleteCommentDialog(
    BuildContext context,
    String tweetId,
    int index,
    TweetProvider tweetProvider,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        final textTheme = Theme.of(context).textTheme;

        return AlertDialog(
          title: Text(
            'Delete Comment',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          content: Text(
            'Are you sure you want to delete this comment? This action cannot be undone.',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await tweetProvider.deleteComment(tweetId, index);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Comment deleted'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete: $e'),
                      backgroundColor: colorScheme.error,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
              ),
              child: const Text('Delete'),
            ),
          ],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        );
      },
    );
  }

  Widget _buildEmptyCommentsState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outline.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.forum_outlined,
            size: 48,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 20),
          Text(
            'No comments yet',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Be the first to share your thoughts on this post!',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required IconData activeIcon,
    required int count,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        IconButton.filledTonal(
          onPressed: onTap,
          icon: Icon(isActive ? activeIcon : icon),
          isSelected: isActive,
          style: IconButton.styleFrom(
            backgroundColor: isActive
                ? colorScheme.primaryContainer
                : colorScheme.surfaceVariant,
            foregroundColor: isActive
                ? colorScheme.onPrimaryContainer
                : colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          count.toString(),
          style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

Future<void> _shareTweet(
  String content,
  BuildContext context,
  String tweetId,
) async {
  try {
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
