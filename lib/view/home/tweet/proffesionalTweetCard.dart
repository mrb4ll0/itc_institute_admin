import 'package:flutter/material.dart';
import 'package:itc_institute_admin/view/home/tweet/user_selection_dialog.dart';
import 'package:provider/provider.dart';

import '../../../auth/tweet_provider.dart';
import '../../../generalmethods/GeneralMethods.dart';
import '../../../itc_logic/firebase/tweet/tweet_cloud.dart';
import '../../../itc_logic/idservice/globalIdService.dart';
import '../../../itc_logic/service/followService.dart';
import '../../../model/admin.dart';
import '../../../model/comments_model.dart';
import '../../../model/company.dart';
import '../../../model/student.dart';
import '../../../model/tweetModel.dart';
import '../../../model/userProfile.dart';
import '../../adminProfilePage.dart';
import '../../company/companyDetailPage.dart';
import '../student/studentDetails.dart';
import 'expandable_text.dart';

class ProfessionalTweetCard extends StatefulWidget {
  final TweetModel tweet;
  final UserConverter tweetPoster;
  final UserConverter currentStudent;
  final bool isDark;
  final VoidCallback onTap;

  const ProfessionalTweetCard({
    Key? key,
    required this.tweet,
    required this.tweetPoster,
    required this.currentStudent,
    required this.isDark,
    required this.onTap,
  }) : super(key: key);

  @override
  State<ProfessionalTweetCard> createState() => _ProfessionalTweetCardState();
}

class _ProfessionalTweetCardState extends State<ProfessionalTweetCard> {
  bool _showOptionsMenu = false;
  bool _isLiked = false;
  bool _isShared = false;
  bool _isFollowing = false;
  bool _isCheckingFollow = true;
  bool _isTogglingFollow = false; // Add this for follow button loading state
  final TextEditingController _commentController = TextEditingController();
  final tweetService = TweetService();
  final FollowService _followService = FollowService();

  @override
  void initState() {
    super.initState();
    _isLiked = widget.tweet.isLiked;
    _isShared = widget.tweet.isShared;
    _checkFollowStatus();
  }

  Future<void> _checkFollowStatus() async {
    // Don't check follow status for own profile
    if (widget.currentStudent.uid == widget.tweetPoster.uid) {
      setState(() {
        _isFollowing = false;
        _isCheckingFollow = false;
      });
      return;
    }

    final isFollowing = await _followService.isFollowing(
      widget.currentStudent.uid,
      widget.tweetPoster.uid,
    );

    if (mounted) {
      setState(() {
        _isFollowing = isFollowing;
        _isCheckingFollow = false;
      });
    }
  }

  Future<void> _toggleFollow() async {
    if (_isTogglingFollow) return; // Prevent multiple taps

    setState(() {
      _isTogglingFollow = true;
    });

    try {
      if (_isFollowing) {
        await _followService.unfollowUser(
          widget.currentStudent.uid,
          widget.tweetPoster.uid,
        );
        if (mounted) {
          setState(() {
            _isFollowing = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Unfollowed ${widget.tweetPoster.displayName}'),
              backgroundColor: Colors.grey,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        await _followService.followUser(
          widget.currentStudent.uid,
          widget.tweetPoster.uid,
        );
        if (mounted) {
          setState(() {
            _isFollowing = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Following ${widget.tweetPoster.displayName}'),
              backgroundColor: const Color(0xFF1877F2),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTogglingFollow = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeAgo = widget.tweet.timeAgo;
    TweetProvider provider = Provider.of<TweetProvider>(context);
    _commentController.addListener(() {
      provider.tweetControllerTextChanged();
    });

    return InkWell(
      borderRadius: BorderRadius.circular(26),
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        color: widget.isDark ? Colors.grey[900] : Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with clickable name and follow button
            _buildHeader(timeAgo),

            // Content
            _buildContent(),

            // Facebook-style stats (top)
            _buildFacebookStats(),

            // Comment Preview
            _buildCommentPreview(),

            // Facebook-style action buttons (bottom)
            _buildFacebookActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String timeAgo) {
    final isOwnProfile = widget.currentStudent.uid == widget.tweetPoster.uid;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Clickable profile picture
          GestureDetector(
            onTap: _navigateToProfile,
            child: CircleAvatar(
              radius: 20,
              backgroundImage: NetworkImage(widget.tweetPoster.imageUrl),
              backgroundColor: Colors.grey[300],
            ),
          ),
          const SizedBox(width: 12),
          // Name and role section - will take available space
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name - wraps to multiple lines, no ellipsis
                GestureDetector(
                  onTap: _navigateToProfile,
                  child: Text(
                    widget.tweetPoster.displayName,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: widget.isDark ? Colors.white : Colors.black,
                      height: 1.3,
                    ),
                    maxLines: null, // Allow unlimited lines
                    overflow: TextOverflow.visible,
                  ),
                ),
                const SizedBox(height: 4),
                // Role badge and time in a row
                Row(
                  children: [
                    _buildRoleBadge(),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        timeAgo,
                        style: TextStyle(
                          color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.tweet.isPinnedStatus) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.push_pin, size: 12, color: Colors.orange),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Follow button (only for other users) and options dropdown
          if (!isOwnProfile && !_isCheckingFollow)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Follow button
                GestureDetector(
                  onTap: _isTogglingFollow ? null : _toggleFollow,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _isTogglingFollow
                          ? (widget.isDark ? Colors.grey[700] : Colors.grey[300])
                          : (_isFollowing
                          ? (widget.isDark ? Colors.grey[800] : Colors.grey[200])
                          : const Color(0xFF1877F2)),
                      borderRadius: BorderRadius.circular(20),
                      border: _isFollowing && widget.isDark && !_isTogglingFollow
                          ? Border.all(color: Colors.grey[700]!)
                          : null,
                    ),
                    child: _isTogglingFollow
                        ? const SizedBox(
                      width: 60,
                      height: 20,
                      child: Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                    )
                        : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isFollowing)
                          Icon(
                            Icons.check,
                            size: 14,
                            color: widget.isDark ? Colors.white70 : Colors.grey[700],
                          )
                        else
                          const Icon(
                            Icons.person_add,
                            size: 14,
                            color: Colors.white,
                          ),
                        const SizedBox(width: 4),
                        Text(
                          _isFollowing ? 'Following' : 'Follow',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: _isFollowing
                                ? (widget.isDark ? Colors.white70 : Colors.grey[700])
                                : Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Options dropdown
                _buildFacebookOptionsDropdown(),
              ],
            )
          else if (isOwnProfile)
          // Just the options dropdown for own profile
            _buildFacebookOptionsDropdown(),
        ],
      ),
    );
  }

  Widget _buildRoleBadge() {
    final isCompany = widget.tweetPoster.getAs<Company>() != null;
    final isStudent = widget.tweetPoster.getAs<Student>() != null;
    final isAdmin = widget.tweetPoster.getAs<Admin>() != null;

    String role = '';
    Color badgeColor = const Color(0xFF1877F2);

    if (isCompany) {
      role = 'Company';
      badgeColor = const Color(0xFF34A853);
    } else if (isAdmin) {
      role = 'Admin';
      badgeColor = const Color(0xFFEA4335);
    } else if (isStudent) {
      role = 'Student';
      badgeColor = const Color(0xFFFBBC05);
    }

    if (role.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: badgeColor.withOpacity(0.3),
          width: 0.5,
        ),
      ),
      child: Text(
        role,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: badgeColor,
        ),
      ),
    );
  }

  Widget _buildCommentPreview() {
    if (widget.tweet.comments.isEmpty) return const SizedBox.shrink();

    final lastComment = widget.tweet.comments.last;
    final isDark = widget.isDark;
    final commentCount = widget.tweet.comments.length;

    return Column(
      children: [
        // Latest comment
        GestureDetector(
          onTap: () => _showCommentDialog(),
          child: Container(
            margin: const EdgeInsets.only(top: 4, left: 12, right: 12, bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800]!.withOpacity(0.5) : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: isDark ? Colors.grey[700] : Colors.grey[300],
                  child: Text(
                    lastComment.user.isNotEmpty
                        ? lastComment.user[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lastComment.user,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        lastComment.content,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400] : Colors.grey[700],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // View all comments link (if more than 1 comment)
        if (commentCount > 1)
          GestureDetector(
            onTap: () => widget.onTap(),
            child: Padding(
              padding: const EdgeInsets.only(left: 12, right: 12, bottom: 4),
              child: Row(
                children: [
                  const SizedBox(width: 38), // Align with avatar
                  Text(
                    'View all $commentCount comments',
                    style: TextStyle(
                      fontSize: 12,
                      color: const Color(0xFF1877F2),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExpandableText(
            text: widget.tweet.content,
            isDark: widget.isDark,
          ),

          // Show hashtags if available
          if (widget.tweet.hasHashtags)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 8,
                children: widget.tweet.hashtags!.map((hashtag) {
                  return GestureDetector(
                    onTap: () => _searchHashtag(hashtag),
                    child: Text(
                      '#$hashtag',
                      style: TextStyle(
                        fontSize: 14,
                        color: const Color(0xFF1877F2),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

          // Show image if available
          if (widget.tweet.imageUrl != null && widget.tweet.imageUrl!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  widget.tweet.imageUrl!,
                  width: double.infinity,
                  height: 300,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: double.infinity,
                    height: 300,
                    color: widget.isDark ? Colors.grey[800] : Colors.grey[200],
                    child: Center(
                      child: Icon(
                        Icons.broken_image,
                        color: Colors.grey[500],
                        size: 40,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFacebookStats() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Likes count
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1877F2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.thumb_up,
                  size: 12,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                _formatCount(widget.tweet.likes.length),
                style: TextStyle(
                  fontSize: 13,
                  color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),

          // Comments and Shares
          Row(
            children: [
              Text(
                '${_formatCount(widget.tweet.commentCount)} comments',
                style: TextStyle(
                  fontSize: 13,
                  color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${_formatCount(widget.tweet.shareCount)} shares',
                style: TextStyle(
                  fontSize: 13,
                  color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFacebookActions() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: widget.isDark ? Colors.grey[800]! : Colors.grey[300]!,
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Like Button
          _buildFacebookActionButton(
            icon: widget.tweet.likes.contains(
              GlobalIdService.firestoreId,
            )
                ? Icons.thumb_up
                : Icons.thumb_up_outlined,
            label: 'Like',
            isActive: _isLiked,
            color: widget.tweet.likes.contains(
              GlobalIdService.firestoreId,
            )
                ? const Color(0xFF1877F2)
                : null,
            onTap: () => _toggleLike(),
          ),

          // Comment Button
          _buildFacebookActionButton(
            icon: Icons.mode_comment_outlined,
            label: 'Comment',
            isActive: false,
            onTap: () => _showCommentDialog(),
          ),

          // Share Button
          _buildFacebookActionButton(
            icon: Icons.share_outlined,
            label: 'Share',
            isActive: false,
            onTap: () => _shareTweet(widget.tweet.content, context, widget.tweet.id),
          ),
        ],
      ),
    );
  }

  Widget _buildFacebookActionButton({
    required IconData icon,
    required String label,
    required bool isActive,
    Color? color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: color ??
                      (widget.isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: color ??
                        (widget.isDark ? Colors.grey[400] : Colors.grey[600]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Add FollowService class if not already present
  void _navigateToProfile() {
    bool isCompany = widget.tweetPoster.getAs<Company>() != null;
    bool isStudent = widget.tweetPoster.getAs<Student>() != null;
    bool isAdmin = widget.tweetPoster.getAs<Admin>() != null;

    if (isCompany && !isStudent) {
      GeneralMethods.navigateTo(
        context,
        CompanyDetailPage(
          user: widget.currentStudent,
          company: widget.tweetPoster.getAs<Company>()!,
        ),
      );
    } else if (isStudent && !isCompany) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => StudentProfilePage(
            student: widget.tweetPoster.getAs<Student>()!,

          ),
        ),
      );
    } else if (!isStudent && !isCompany && isAdmin) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AdminProfilePage(
            admin: widget.tweetPoster.getAs<Admin>()!,
            currentStudent: widget.currentStudent,
          ),
        ),
      );
    }
  }

  Widget _buildFacebookOptionsDropdown() {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_horiz,
        color: widget.isDark ? Colors.grey[500] : Colors.grey[600],
        size: 20,
      ),
      onSelected: (value) => _handleMenuSelection(value),
      itemBuilder: (BuildContext context) => [
        if (widget.currentStudent.uid == widget.tweet.userId)
          PopupMenuItem<String>(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete_outline, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                const Text('Delete Post'),
              ],
            ),
          ),
        PopupMenuItem<String>(
          value: 'save',
          child: Row(
            children: [
              Icon(Icons.bookmark_border, color: Colors.grey[600], size: 20),
              const SizedBox(width: 8),
              const Text('Save Post'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'report',
          child: Row(
            children: [
              Icon(Icons.flag_outlined, color: Colors.red, size: 20),
              const SizedBox(width: 8),
              const Text('Report Post'),
            ],
          ),
        ),
      ],
    );
  }

  void _handleMenuSelection(String value) {
    switch (value) {
      case 'delete':
        _deleteTweet();
        break;
      case 'edit':
        _editTweet();
        break;
      case 'save':
        _bookmarkTweet();
        break;
      case 'copy':
        _copyTweetLink();
        break;
      case 'report':
        _reportTweet();
        break;
    }
  }
  void _toggleLike() async {
    try {
      final provider = Provider.of<TweetProvider>(context, listen: false);
      bool isLike = widget.tweet.likes.contains(widget.currentStudent.uid);
      await provider.toggleLike(
        widget.tweet.id,
        widget.currentStudent.uid,
        isLike,
      );

      setState(() {
        _isLiked = !_isLiked;
      });
    } catch (e, s) {
      debugPrint("Error toggling like: $e");
      debugPrintStack(stackTrace: s);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showCommentDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: widget.isDark ? Colors.grey[900] : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Consumer<TweetProvider>(
          builder: (context, provider, child) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Write a comment',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: widget.isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.close,
                            color: widget.isDark
                                ? Colors.grey[400]
                                : Colors.grey[600],
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Current user info
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundImage: NetworkImage(
                            widget.currentStudent.imageUrl,
                          ),
                          backgroundColor: Colors.grey[300],
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.currentStudent.displayName,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color:
                                widget.isDark ? Colors.white : Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Comment input
                    TextField(
                      controller: _commentController,
                      maxLines: 4,
                      minLines: 3,
                      style: TextStyle(
                        color: widget.isDark ? Colors.white : Colors.black,
                        fontSize: 16,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Write a comment...',
                        hintStyle: TextStyle(
                          color: widget.isDark
                              ? Colors.grey[500]
                              : Colors.grey[400],
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Post button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton(
                          onPressed: _commentController.text.trim().isEmpty
                              ? null
                              : () {
                            _postComment();
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(
                              0xFF1877F2,
                            ), // Facebook blue
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                          child: const Text(
                            'Post',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
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
      },
    );
  }

  void _postComment() {
    if (_commentController.text.trim().isEmpty) return;
    Comment comment = Comment(
      tweetId: widget.tweet.id,
      userId: widget.currentStudent.uid,
      user: widget.currentStudent.displayName,
      content: _commentController.text.trim(),
      timestamp: DateTime.now(),
    );
    Provider.of<TweetProvider>(context, listen: false).postCommentToTweet(
      widget.tweet.id,
      _commentController.text.trim(),
      widget.currentStudent,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Comment posted'),
        backgroundColor: Colors.green,
      ),
    );
    _commentController.clear();
  }

  Future<void> _shareTweet(
      String content,
      BuildContext context,
      String tweetId,
      ) async {
    try {
      TweetProvider provider =
      Provider.of<TweetProvider>(context, listen: false);
      await showDialog(
        context: context,
        builder: (context) => UserSelectionDialog(
            tweetContent: GeneralMethods.formatTweetShare(content, tweetId),
            tweetId: tweetId),
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

  void _bookmarkTweet() async {
    //save implementations
    bool isTweetSaved = await tweetService.isTweetSavedByUser(
      GlobalIdService.firestoreId,
      widget.tweet.id,
    );
    if (isTweetSaved) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Feed is Saved Kindly click the Green Favorite Icon at the top to View it",
          ),
        ),
      );
      return;
    }
    debugPrint("userid ${GlobalIdService.firestoreId}");
    debugPrint("tweetId ${widget.tweet.id}");
    await tweetService.saveTweet(
      userId: GlobalIdService.firestoreId,
      tweetId: widget.tweet.id,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Post saved'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _copyTweetLink() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Link copied to clipboard'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _reportTweet() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Post'),
        content: const Text('Are you sure you want to report this post?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Post reported'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Report', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _editTweet() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Edit feature coming soon'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _deleteTweet() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Provider.of<TweetProvider>(
                context,
                listen: false,
              ).deleteTweet(widget.tweet.id, context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Post deleted'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _searchHashtag(String hashtag) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Searching for #$hashtag...'),
        backgroundColor: const Color(0xFF1877F2),
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}
