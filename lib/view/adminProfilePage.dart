import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:itc_institute_admin/view/home/chat/chartPage.dart';
import 'package:itc_institute_admin/view/home/tweet/expandable_text.dart';
import 'package:provider/provider.dart';
import '../../../../../itc_logic/firebase/message/message_service.dart';
import '../../../../../itc_logic/service/followService.dart';
import '../../../../../model/admin.dart';
import '../auth/tweet_provider.dart';
import '../itc_logic/firebase/general_cloud.dart';
import '../itc_logic/firebase/tweet/tweet_cloud.dart';
import '../itc_logic/idservice/globalIdService.dart';
import '../model/tweetModel.dart';
import '../model/userProfile.dart';

import '../view/home/tweet/tweet_details_page.dart';
import 'home/tweet_view.dart';

class AdminProfilePage extends StatefulWidget {
  final Admin admin;
  final UserConverter currentStudent;

  const AdminProfilePage({
    Key? key,
    required this.admin,
    required this.currentStudent,
  }) : super(key: key);

  @override
  State<AdminProfilePage> createState() => _AdminProfilePageState();
}

class _AdminProfilePageState extends State<AdminProfilePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Follow functionality variables
  final FollowService _followService = FollowService();
  String? _currentUserId;
  bool _isFollowing = false;
  bool _isCheckingFollow = true;
  bool _isTogglingFollow = false;

  // Admin tweets
  List<TweetModel> _adminTweets = [];
  bool _isLoadingTweets = true;
  bool _hasMoreTweets = true;
  bool _isLoadingMoreTweets = false;

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
    _tabController = TabController(length: 2, vsync: this);
    _loadAdminTweets();
  }

  Future<void> _getCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    _currentUserId = GlobalIdService.firestoreId;

    if (_currentUserId != null && _currentUserId != widget.admin.uid) {
      await _checkFollowStatus();
    } else {
      setState(() {
        _isCheckingFollow = false;
      });
    }
  }

  Future<void> _loadAdminTweets() async {
    setState(() {
      _isLoadingTweets = true;
    });

    try {
      final tweetProvider = Provider.of<TweetProvider>(context, listen: false);

      // Get all tweets and filter by admin ID
      final allTweets = tweetProvider.tweets;

      // Filter tweets where userId matches admin's UID
      final filteredTweets = allTweets
          .where((tweet) => tweet.userId == widget.admin.uid)
          .toList();

      // Sort by timestamp (newest first)
      filteredTweets.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      setState(() {
        _adminTweets = filteredTweets;
        _isLoadingTweets = false;
      });
    } catch (e) {
      debugPrint('Error loading admin tweets: $e');
      setState(() {
        _isLoadingTweets = false;
      });
    }
  }

  Future<void> _refreshAdminTweets() async {
    await _loadAdminTweets();
  }

  Future<void> _checkFollowStatus() async {
    if (_currentUserId == null || _currentUserId == widget.admin.uid) {
      setState(() {
        _isCheckingFollow = false;
      });
      return;
    }

    final isFollowing = await _followService.isFollowing(
      _currentUserId!,
      widget.admin.uid,
    );

    if (mounted) {
      setState(() {
        _isFollowing = isFollowing;
        _isCheckingFollow = false;
      });
    }
  }

  Future<void> _toggleFollow() async {
    if (_isTogglingFollow || _currentUserId == null) return;

    setState(() {
      _isTogglingFollow = true;
    });

    try {
      if (_isFollowing) {
        await _followService.unfollowUser(
          _currentUserId!,
          widget.admin.uid,
        );
        if (mounted) {
          setState(() {
            _isFollowing = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Unfollowed ${widget.admin.fullName}'),
              backgroundColor: Colors.grey,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        await _followService.followUser(
          _currentUserId!,
          widget.admin.uid,
        );
        if (mounted) {
          setState(() {
            _isFollowing = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Following ${widget.admin.fullName}'),
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
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _startChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatDetailsPage(
          receiverId: widget.admin.uid,
          receiverAvatarUrl: widget.admin.photoUrl ?? "",
          receiverName: widget.admin.fullName,
          receiverRole: widget.admin.role,
        ),
      ),
    );
  }

  void _showContactOptions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Contact Options',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onBackground,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildContactOption(
                icon: Icons.message,
                title: 'Send Message',
                subtitle: 'Start a private conversation',
                onTap: () {
                  Navigator.pop(context);
                  _startChat();
                },
              ),
              const SizedBox(height: 16),
              _buildContactOption(
                icon: Icons.email,
                title: 'Send Email',
                subtitle: widget.admin.email,
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 16),
              _buildContactOption(
                icon: Icons.call,
                title: 'Request Callback',
                subtitle: 'Schedule a phone consultation',
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 16),
              _buildContactOption(
                icon: Icons.video_call,
                title: 'Request Video Meeting',
                subtitle: 'Schedule a virtual meeting',
                onTap: () {
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContactOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;
    final isOwnProfile = _currentUserId == widget.admin.uid;

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 420,
              floating: false,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: _buildProfileHeader(isDark, colors),
                collapseMode: CollapseMode.pin,
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Container(
                  color: isDark ? Colors.grey[900] : Colors.white,
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: colors.primary,
                    labelColor: colors.primary,
                    unselectedLabelColor: colors.onSurface.withOpacity(0.6),
                    indicatorSize: TabBarIndicatorSize.label,
                    tabs: const [
                      Tab(text: 'About'),
                      Tab(text: 'Posts'),
                    ],
                  ),
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: _showContactOptions,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ],
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildAboutTab(isDark, colors),
            _buildPostsTab(isDark, colors),
            //_buildActivityTab(isDark, colors),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomActionBar(isDark, colors, isOwnProfile),
    );
  }

  Widget _buildBottomActionBar(bool isDark, ColorScheme colors, bool isOwnProfile) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        border: Border(
          top: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
        ),
      ),
      child: Row(
        children: [
          if (!isOwnProfile && !_isCheckingFollow)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isTogglingFollow ? null : _toggleFollow,
                icon: _isTogglingFollow
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : Icon(
                  _isFollowing ? Icons.check : Icons.person_add,
                  size: 18,
                ),
                label: Text(
                  _isTogglingFollow
                      ? '...'
                      : (_isFollowing ? 'Following' : 'Follow'),
                ),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(
                    color: _isFollowing ? colors.outline : colors.primary,
                  ),
                  foregroundColor: _isFollowing ? colors.onSurface : colors.primary,
                ),
              ),
            ),
          if (!isOwnProfile && !_isCheckingFollow) const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _startChat,
              icon: const Icon(Icons.message),
              label: const Text('Message'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(bool isDark, ColorScheme colors) {
    final isOwnProfile = _currentUserId == widget.admin.uid;

    return Container(
      color: isDark ? Colors.grey[900] : Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[800] : Colors.grey[200],
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? Colors.grey[900]! : Colors.white,
                      width: 4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: widget.admin.photoUrl != null
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(60),
                    child: Image.network(
                      widget.admin.photoUrl!,
                      fit: BoxFit.cover,
                    ),
                  )
                      : Icon(
                    Icons.person,
                    size: 60,
                    color: colors.onSurface.withOpacity(0.5),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.verified,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  widget.admin.fullName,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: const Text(
                    'ITC Administrator',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (!isOwnProfile && !_isCheckingFollow)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: GestureDetector(
                      onTap: _isTogglingFollow ? null : _toggleFollow,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _isFollowing
                              ? Colors.grey.withOpacity(0.2)
                              : Colors.blue,
                          borderRadius: BorderRadius.circular(20),
                          border: _isFollowing
                              ? Border.all(color: colors.outline.withOpacity(0.3))
                              : null,
                        ),
                        child: _isTogglingFollow
                            ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                            : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isFollowing ? Icons.check : Icons.person_add,
                              size: 14,
                              color: _isFollowing
                                  ? colors.onSurface
                                  : Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _isFollowing ? 'Following' : 'Follow',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _isFollowing
                                    ? colors.onSurface
                                    : Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                Text(
                  widget.admin.email,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Member since ${_formatDate(widget.admin.createdAt)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostsTab(bool isDark, ColorScheme colors) {
    if (_isLoadingTweets) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_adminTweets.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.announcement,
                size: 80,
                color: colors.onSurface.withOpacity(0.3),
              ),
              const SizedBox(height: 20),
              Text(
                'No Posts Yet',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: colors.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Official announcements will appear here',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshAdminTweets,
      color: const Color(0xFF1DA1F2),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _adminTweets.length,
        itemBuilder: (context, index) {
          final tweet = _adminTweets[index];

          // Create UserConverter for the tweet poster (admin)
          final tweetPoster = UserConverter(widget.admin);

          return ProfessionalTweetCard(
            tweet: tweet,
            tweetPoster: tweetPoster,
            currentUser: widget.currentStudent,
            isDark: isDark,
            onTap: () {
              // Navigate to tweet detail page for full interaction
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TweetDetailPage(
                    tweetId: tweet.id,
                    author: tweetPoster,
                    currentUser: widget.currentStudent,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
  Widget _buildTweetCard(TweetModel tweet, bool isDark, ColorScheme colors) {
    final timeAgo = _getTimeAgo(tweet.timestamp);
    final isLiked = tweet.likes.contains(_currentUserId);
    final currentUser = UserConverter(widget.admin);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundImage: widget.admin.photoUrl != null
                      ? NetworkImage(widget.admin.photoUrl!)
                      : null,
                  backgroundColor: Colors.grey[300],
                  child: widget.admin.photoUrl == null
                      ? Text(
                    widget.admin.fullName[0].toUpperCase(),
                    style: const TextStyle(fontSize: 18),
                  )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            widget.admin.fullName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Icon(
                              Icons.verified,
                              color: Colors.blue,
                              size: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            'ITC Administrator',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            timeAgo,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.more_horiz,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    size: 20,
                  ),
                  onPressed: () => _showTweetOptions(tweet),
                ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ExpandableText(
              text: tweet.content,
              isDark: isDark,
            ),
          ),

          // Hashtags
          if (tweet.hasHashtags)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 16, right: 16),
              child: Wrap(
                spacing: 8,
                children: tweet.hashtags!.map((tag) {
                  return GestureDetector(
                    onTap: () => _searchHashtag(tag),
                    child: Text(
                      '#$tag',
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

          // Image
          if (tweet.imageUrl != null && tweet.imageUrl!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12, left: 16, right: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  tweet.imageUrl!,
                  width: double.infinity,
                  height: 250,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 200,
                    color: isDark ? Colors.grey[800] : Colors.grey[200],
                    child: const Center(child: Icon(Icons.broken_image, size: 48)),
                  ),
                ),
              ),
            ),

          // Stats
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Color(0xFF1877F2),
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
                      _formatCount(tweet.likes.length),
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      '${_formatCount(tweet.comments.length)} comments',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${_formatCount(tweet.shareCount)} shares',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Action Buttons
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                ),
                bottom: BorderSide(
                  color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  icon: isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                  label: 'Like',
                  isActive: isLiked,
                  isDark: isDark,
                  onTap: () => _toggleLike(tweet),
                ),
                _buildActionButton(
                  icon: Icons.mode_comment_outlined,
                  label: 'Comment',
                  isActive: false,
                  isDark: isDark,
                  onTap: () => _showCommentDialog(tweet),
                ),
                _buildActionButton(
                  icon: Icons.share_outlined,
                  label: 'Share',
                  isActive: false,
                  isDark: isDark,
                  onTap: () => _shareTweet(tweet),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final color = isActive
        ? const Color(0xFF1877F2)
        : (isDark ? Colors.grey[400] : Colors.grey[600]);

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
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _toggleLike(TweetModel tweet) async {
    final tweetProvider = Provider.of<TweetProvider>(context, listen: false);
    final isCurrentlyLiked = tweet.likes.contains(_currentUserId);

    await tweetProvider.toggleLike(
      tweet.id,
      _currentUserId!,
      isCurrentlyLiked,
    );

    // Refresh the tweets list
    await _loadAdminTweets();
  }

  void _showCommentDialog(TweetModel tweet) {
    // Implement comment dialog similar to TweetView
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Comment feature coming soon')),
    );
  }

  void _shareTweet(TweetModel tweet) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share feature coming soon')),
    );
  }

  void _showTweetOptions(TweetModel tweet) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete Post'),
              onTap: () {
                Navigator.pop(context);
                _deleteTweet(tweet);
              },
            ),
            ListTile(
              leading: const Icon(Icons.bookmark_border),
              title: const Text('Save Post'),
              onTap: () {
                Navigator.pop(context);
                _bookmarkTweet(tweet);
              },
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined, color: Colors.red),
              title: const Text('Report Post'),
              onTap: () {
                Navigator.pop(context);
                _reportTweet(tweet);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteTweet(TweetModel tweet) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('Are you sure you want to delete this post?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final tweetProvider = Provider.of<TweetProvider>(context, listen: false);
      await tweetProvider.deleteTweet(tweet.id, context);
      await _loadAdminTweets();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post deleted'), backgroundColor: Colors.green),
      );
    }
  }

  void _bookmarkTweet(TweetModel tweet) async {
    final tweetService = TweetService();
    final isSaved = await tweetService.isTweetSavedByUser(
      _currentUserId!,
      tweet.id,
    );

    if (isSaved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post already saved')),
      );
      return;
    }

    await tweetService.saveTweet(
      userId: _currentUserId!,
      tweetId: tweet.id,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Post saved'), backgroundColor: Colors.green),
    );
  }

  void _reportTweet(TweetModel tweet) {
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
                const SnackBar(content: Text('Post reported'), backgroundColor: Colors.green),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Report', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _searchHashtag(String hashtag) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Searching for #$hashtag...')),
    );
  }

  Widget _buildAboutTab(bool isDark, ColorScheme colors) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSection(
            title: 'About Administrator',
            icon: Icons.info_outline,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Official IT Connect platform administrator. Responsible for maintaining community guidelines, assisting users, and ensuring smooth platform operation.',
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.6,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      Icons.verified_user,
                      color: colors.primary,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Verified Platform Staff',
                      style: TextStyle(
                        color: colors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildSection(
            title: 'Contact Information',
            icon: Icons.contact_mail,
            child: Column(
              children: [
                _buildInfoRow(
                  icon: Icons.email,
                  title: 'Email',
                  value: widget.admin.email,
                ),
                const SizedBox(height: 12),
                _buildInfoRow(
                  icon: Icons.person,
                  title: 'Role',
                  value: 'Platform Administrator',
                ),
                const SizedBox(height: 12),
                _buildInfoRow(
                  icon: Icons.calendar_today,
                  title: 'Joined',
                  value: _formatDate(widget.admin.createdAt),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildSection(
            title: 'How I Can Help',
            icon: Icons.help_outline,
            child: Column(
              children: [
                _buildHelpItem(
                  icon: Icons.support_agent,
                  title: 'Technical Support',
                  description: 'Resolve platform issues and bugs',
                ),
                const SizedBox(height: 12),
                _buildHelpItem(
                  icon: Icons.gavel,
                  title: 'Community Guidelines',
                  description: 'Enforce rules and handle reports',
                ),
                const SizedBox(height: 12),
                _buildHelpItem(
                  icon: Icons.lightbulb_outline,
                  title: 'Feature Requests',
                  description: 'Collect and review user suggestions',
                ),
                const SizedBox(height: 12),
                _buildHelpItem(
                  icon: Icons.security,
                  title: 'Account Security',
                  description: 'Assist with login and security issues',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildSection(
            title: 'Quick Actions',
            icon: Icons.bolt,
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildQuickActionButton(
                  icon: Icons.report_problem,
                  label: 'Report Issue',
                  onTap: () => _startChat(),
                ),
                _buildQuickActionButton(
                  icon: Icons.question_answer,
                  label: 'Ask Question',
                  onTap: () => _startChat(),
                ),
                _buildQuickActionButton(
                  icon: Icons.feedback,
                  label: 'Give Feedback',
                  onTap: () => _startChat(),
                ),
                _buildQuickActionButton(
                  icon: Icons.help,
                  label: 'Get Help',
                  onTap: () => _startChat(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: isDark ? Colors.grey[400] : Colors.grey[600],
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHelpItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
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
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isDark ? Colors.grey[800] : Colors.grey[100],
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivityTab(bool isDark, ColorScheme colors) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[900] : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.update,
                  color: colors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'System Update',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Platform maintenance completed successfully',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '2 days ago',
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
        );
      },
    );
  }

  String _getTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 30) {
      return '${difference.inDays ~/ 30}mo ago';
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

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  String _formatDate(DateTime date) {
    const monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${monthNames[date.month - 1]} ${date.year}';
  }
}