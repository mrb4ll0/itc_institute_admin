import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../itc_logic/firebase/tweet/tweet_cloud.dart';
import '../../auth/tweet_provider.dart';
import '../../generalmethods/GeneralMethods.dart';
import '../../itc_logic/idservice/globalIdService.dart';
import '../../itc_logic/service/followService.dart';
import '../../model/admin.dart';
import '../../model/comments_model.dart';
import '../../model/company.dart';
import '../../model/student.dart';
import '../../model/tweetModel.dart';
import '../../model/userProfile.dart';
import '../adminProfilePage.dart';
import '../company/companyDetailPage.dart';
import '../home/savedPost.dart';
import '../home/student/studentDetails.dart';
import '../home/tweet/expandable_text.dart';
import '../home/tweet/tweet_details_page.dart';
import '../home/tweet/user_selection_dialog.dart';


// ─────────────────────────────────────────────────────────────────────────────
// TweetView  (the feed screen)
// ─────────────────────────────────────────────────────────────────────────────

class TweetView extends StatefulWidget {
  final Company company;
  const TweetView({Key? key, required this.company}) : super(key: key);

  @override
  _TweetViewState createState() => _TweetViewState();
}

class _TweetViewState extends State<TweetView> {
  final TextEditingController _composeController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final TweetService _tweetService = TweetService();

  bool _showScrollToTop = false;
  bool _isRefreshing = false;

  // Facebook blue that we use throughout
  static const _fbBlue = Color(0xFF1877F2);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _composeController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final show = _scrollController.offset > 500;
    if (show != _showScrollToTop) setState(() => _showScrollToTop = show);
  }

  Future<void> _refresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      await Provider.of<TweetProvider>(context, listen: false).refreshTweets();
    } catch (e) {
      _snack('Failed to refresh: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF18191A) : const Color(0xFFf0f2f5);

    return Scaffold(
      backgroundColor: bg,
      appBar: _buildAppBar(isDark),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: _fbBlue,
        backgroundColor: isDark ? const Color(0xFF242526) : Colors.white,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // compose box (always visible at top)
            SliverToBoxAdapter(child: _buildComposeBox(isDark)),
            // feed
            _buildFeed(isDark),
            // bottom padding so FAB doesn't cover last card
            const SliverToBoxAdapter(child: SizedBox(height: 88)),
          ],
        ),
      ),
      floatingActionButton: _showScrollToTop
          ? FloatingActionButton.small(
        onPressed: _scrollToTop,
        backgroundColor: isDark ? const Color(0xFF3A3B3C) : Colors.white,
        elevation: 4,
        child: Icon(
          Icons.arrow_upward_rounded,
          color: isDark ? Colors.white : Colors.black87,
          size: 20,
        ),
      )
          : FloatingActionButton(
        heroTag: GeneralMethods.getUniqueHeroTag(),
        onPressed: () => _showComposeSheet(context, isDark),
        backgroundColor: _fbBlue,
        elevation: 4,
        child: const Icon(Icons.edit_rounded, color: Colors.white),
      ),
    );
  }

  // ── App bar ──────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(bool isDark) {
    final surface = isDark ? const Color(0xFF242526) : Colors.white;
    return AppBar(
      elevation: 0,
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      titleSpacing: 12,
      leading: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: CircleAvatar(
          radius: 17,
          backgroundColor: Colors.grey.shade300,
          backgroundImage: widget.company.logoURL.isNotEmpty
              ? NetworkImage(widget.company.logoURL)
              : null,
          child: widget.company.logoURL.isEmpty
              ? Text(widget.company.name[0],
              style: const TextStyle(fontWeight: FontWeight.bold))
              : null,
        ),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'IT Connect',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontWeight: FontWeight.w800,
              fontSize: 19,
              letterSpacing: -0.3,
            ),
          ),
          Text(
            'Community feed',
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontSize: 11,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
      actions: [
        // saved posts
        _appBarIconBtn(
          icon: Icons.bookmark_rounded,
          color: Colors.green,
          isDark: isDark,
          onTap: () => GeneralMethods.navigateTo(
            context,
            SavedPostsPage(
              company: UserConverter(widget.company),
              tweetService: _tweetService,
            ),
          ),
        ),
        // search
        _appBarIconBtn(
          icon: Icons.search_rounded,
          isDark: isDark,
          onTap: () {},
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _appBarIconBtn({
    required IconData icon,
    required bool isDark,
    Color? color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF3A3B3C) : const Color(0xFFE4E6EB),
          shape: BoxShape.circle,
        ),
        child: Icon(icon,
            size: 19,
            color: color ?? (isDark ? Colors.white : Colors.black87)),
      ),
    );
  }

  // ── Inline compose box ───────────────────────────────────────────────────
  // A lightweight tap-to-compose row — mirrors Facebook's "What's on your mind?"

  Widget _buildComposeBox(bool isDark) {
    final surface = isDark ? const Color(0xFF242526) : Colors.white;
    final divider = isDark ? const Color(0xFF3A3B3C) : const Color(0xFFE4E6EB);

    return Container(
      color: surface,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 19,
                backgroundColor: Colors.grey.shade300,
                backgroundImage: widget.company.logoURL.isNotEmpty
                    ? NetworkImage(widget.company.logoURL)
                    : null,
                child: widget.company.logoURL.isEmpty
                    ? Text(widget.company.name[0],
                    style: const TextStyle(fontWeight: FontWeight.bold))
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => _showComposeSheet(context, isDark),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: divider),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Text(
                      "What's happening in IT?",
                      style: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey[500],
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Divider(height: 1, color: divider),
          // quick action pills below the input
          Row(
            children: [
              _composePill(
                  Icons.image_rounded, 'Photo', Colors.green, isDark, () {}),
              _composePill(Icons.videocam_rounded, 'Video', Colors.red, isDark,
                      () {}),
              _composePill(Icons.emoji_emotions_outlined, 'Feeling',
                  Colors.amber, isDark, () {}),
            ],
          ),
        ],
      ),
    );
  }

  Widget _composePill(
      IconData icon, String label, Color iconColor, bool isDark, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Feed list ────────────────────────────────────────────────────────────

  Widget _buildFeed(bool isDark) {
    return Consumer<TweetProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return SliverList(
            delegate: SliverChildBuilderDelegate(
                  (_, i) => _TweetSkeleton(isDark: isDark),
              childCount: 4,
            ),
          );
        }

        if (provider.tweets.isEmpty) {
          return SliverFillRemaining(child: _buildEmptyState(isDark));
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
                (context, index) {
              // load-more row at the end
              if (index == provider.tweets.length) {
                return _buildLoadMoreRow(provider, isDark);
              }

              final tweet = provider.tweets[index];

              return FutureBuilder<Map<String, dynamic>>(
                future: provider.fetchAllStudents([tweet]),
                builder: (context, snap) {
                  if (!snap.hasData) return _TweetSkeleton(isDark: isDark);
                  final poster = snap.data![tweet.userId];
                  if (poster == null) return const SizedBox.shrink();

                  return _FbTweetCard(
                    key: ValueKey(tweet.id),
                    tweet: tweet,
                    tweetPoster: poster,
                    currentUser: UserConverter(widget.company),
                    isDark: isDark,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TweetDetailPage(
                          tweetId: tweet.id,
                          author: poster,
                          currentUser: UserConverter(widget.company),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
            childCount: provider.tweets.length + 1,
          ),
        );
      },
    );
  }

  Widget _buildLoadMoreRow(TweetProvider provider, bool isDark) {
    if (!provider.hasMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            'You\'re all caught up',
            style: TextStyle(
              color: isDark ? Colors.grey[500] : Colors.grey[500],
              fontSize: 13,
            ),
          ),
        ),
      );
    }
    WidgetsBinding.instance
        .addPostFrameCallback((_) => provider.loadMoreTweets());
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Center(
          child: CircularProgressIndicator(
              color: Color(0xFF1877F2), strokeWidth: 2)),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF3A3B3C) : const Color(0xFFE4E6EB),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.forum_outlined,
                size: 56,
                color: isDark ? Colors.grey[500] : Colors.grey[500]),
          ),
          const SizedBox(height: 20),
          Text(
            'Nothing here yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Be the first to start a conversation.',
            style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontSize: 14),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => _showComposeSheet(context, isDark),
            style: ElevatedButton.styleFrom(
              backgroundColor: _fbBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              padding:
              const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
            ),
            child: const Text('Create a post',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ── Compose sheet ────────────────────────────────────────────────────────

  void _showComposeSheet(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ComposeSheet(
        company: widget.company,
        isDark: isDark,
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// _ComposeSheet  — the "create post" bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _ComposeSheet extends StatefulWidget {
  final Company company;
  final bool isDark;
  const _ComposeSheet({required this.company, required this.isDark});

  @override
  State<_ComposeSheet> createState() => _ComposeSheetState();
}

class _ComposeSheetState extends State<_ComposeSheet> {
  final TextEditingController _ctrl = TextEditingController();
  bool get _canPost => _ctrl.text.trim().isNotEmpty;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final surface =
    widget.isDark ? const Color(0xFF242526) : Colors.white;
    final divider =
    widget.isDark ? const Color(0xFF3A3B3C) : const Color(0xFFE4E6EB);

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      padding: MediaQuery.of(context).viewInsets,
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: divider,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),

              // header row
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
                child: Row(
                  children: [
                    Text(
                      'Create post',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: widget.isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.close,
                          color: widget.isDark
                              ? Colors.grey[400]
                              : Colors.grey[700]),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              Divider(height: 1, color: divider),

              // author row
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.grey.shade300,
                      backgroundImage: widget.company.logoURL.isNotEmpty
                          ? NetworkImage(widget.company.logoURL)
                          : null,
                      child: widget.company.logoURL.isEmpty
                          ? Text(widget.company.name[0])
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.company.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color:
                            widget.isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.only(top: 3),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: widget.isDark
                                ? const Color(0xFF3A3B3C)
                                : const Color(0xFFE4E6EB),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.public,
                                  size: 12,
                                  color: widget.isDark
                                      ? Colors.grey[300]
                                      : Colors.grey[700]),
                              const SizedBox(width: 4),
                              Text(
                                'Public',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: widget.isDark
                                      ? Colors.grey[300]
                                      : Colors.grey[700],
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

              // text input
              Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: TextField(
                  controller: _ctrl,
                  autofocus: true,
                  maxLines: 6,
                  minLines: 3,
                  style: TextStyle(
                    fontSize: 16,
                    color: widget.isDark ? Colors.white : Colors.black,
                  ),
                  decoration: InputDecoration(
                    hintText: "What's on your mind, ${widget.company.name.split(' ').first}?",
                    hintStyle: TextStyle(
                      color: widget.isDark ? Colors.grey[500] : Colors.grey[400],
                      fontSize: 16,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),

              // media action row
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Row(
                  children: [
                    _mediaBtn(Icons.image_rounded, Colors.green, 'Photo'),
                    _mediaBtn(Icons.videocam_rounded, Colors.red, 'Video'),
                    _mediaBtn(Icons.tag, const Color(0xFF1877F2), 'Tag'),
                    _mediaBtn(
                        Icons.emoji_emotions_outlined, Colors.amber, 'Feeling'),
                    const Spacer(),
                    // post button
                    Consumer<TweetProvider>(
                      builder: (_, provider, __) => ElevatedButton(
                        onPressed: _canPost
                            ? () {
                          provider.postTweet(
                            _ctrl.text.trim(),
                            widget.company.name,
                          );
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Post published'),
                              backgroundColor: Colors.green,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                  BorderRadius.circular(10)),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                          _canPost ? const Color(0xFF1877F2) : null,
                          foregroundColor: Colors.white,
                          disabledForegroundColor:
                          Colors.grey.withOpacity(0.6),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          elevation: 0,
                        ),
                        child: const Text('Post',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mediaBtn(IconData icon, Color color, String label) {
    return Tooltip(
      message: label,
      child: IconButton(
        onPressed: () {},
        icon: Icon(icon, color: color, size: 22),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        constraints: const BoxConstraints(),
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// _FbTweetCard  (the individual post card — Facebook style)
// ─────────────────────────────────────────────────────────────────────────────

class _FbTweetCard extends StatefulWidget {
  final TweetModel tweet;
  final UserConverter tweetPoster;
  final UserConverter currentUser;
  final bool isDark;
  final VoidCallback onTap;

  const _FbTweetCard({
    Key? key,
    required this.tweet,
    required this.tweetPoster,
    required this.currentUser,
    required this.isDark,
    required this.onTap,
  }) : super(key: key);

  @override
  State<_FbTweetCard> createState() => _FbTweetCardState();
}

class _FbTweetCardState extends State<_FbTweetCard> {
  static const _blue = Color(0xFF1877F2);

  final FollowService _followService = FollowService();
  final TweetService _tweetService = TweetService();
  final TextEditingController _commentCtrl = TextEditingController();

  bool _isFollowing = false;
  bool _isCheckingFollow = true;
  bool _isTogglingFollow = false;
  bool _isLiked = false;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.tweet.isLiked;
    _checkFollow();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  bool get _isOwnPost =>
      widget.currentUser.uid == widget.tweetPoster.uid;

  // ── Follow logic (identical to StudentProfilePage) ──────────────────────

  Future<void> _checkFollow() async {
    if (_isOwnPost) {
      setState(() {
        _isFollowing = false;
        _isCheckingFollow = false;
      });
      return;
    }
    final following = await _followService.isFollowing(
        widget.currentUser.uid, widget.tweetPoster.uid);
    if (mounted) {
      setState(() {
        _isFollowing = following;
        _isCheckingFollow = false;
      });
    }
  }

  Future<void> _toggleFollow() async {
    if (_isTogglingFollow) return;
    setState(() => _isTogglingFollow = true);

    try {
      if (_isFollowing) {
        await _followService.unfollowUser(
            widget.currentUser.uid, widget.tweetPoster.uid);
        if (mounted) {
          setState(() => _isFollowing = false);
          _snack('Unfollowed ${widget.tweetPoster.displayName}',
              color: Colors.grey);
        }
      } else {
        await _followService.followUser(
            widget.currentUser.uid, widget.tweetPoster.uid);
        if (mounted) {
          setState(() => _isFollowing = true);
          _snack('Following ${widget.tweetPoster.displayName}', color: _blue);
        }
      }
    } catch (e) {
      if (mounted) _snack('Error: $e', color: Colors.red);
    } finally {
      if (mounted) setState(() => _isTogglingFollow = false);
    }
  }

  void _snack(String msg, {Color color = Colors.green}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final surface =
    widget.isDark ? const Color(0xFF242526) : Colors.white;
    final divider =
    widget.isDark ? const Color(0xFF3A3B3C) : const Color(0xFFE4E6EB);

    return Container(
      color: surface,
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(divider),
          _buildBody(),
          if (widget.tweet.imageUrl?.isNotEmpty ?? false) _buildImage(),
          _buildStats(divider),
          Divider(height: 1, color: divider),
          _buildActions(divider),
          if (widget.tweet.comments.isNotEmpty) _buildLatestComment(divider),
        ],
      ),
    );
  }

  // ── Header row ───────────────────────────────────────────────────────────

  Widget _buildHeader(Color divider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // avatar
          GestureDetector(
            onTap: _navigateToProfile,
            child: CircleAvatar(
              radius: 21,
              backgroundColor: Colors.grey.shade300,
              backgroundImage: widget.tweetPoster.imageUrl.isNotEmpty
                  ? NetworkImage(widget.tweetPoster.imageUrl)
                  : null,
              child: widget.tweetPoster.imageUrl.isEmpty
                  ? Text(widget.tweetPoster.displayName[0],
                  style: const TextStyle(fontWeight: FontWeight.bold))
                  : null,
            ),
          ),
          const SizedBox(width: 10),

          // name + meta
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: _navigateToProfile,
                  child: Text(
                    widget.tweetPoster.displayName,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: widget.isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    _roleBadge(),
                    const SizedBox(width: 6),
                    Icon(Icons.public,
                        size: 12,
                        color: widget.isDark
                            ? Colors.grey[500]
                            : Colors.grey[500]),
                    const SizedBox(width: 3),
                    Text(
                      widget.tweet.timeAgo,
                      style: TextStyle(
                        fontSize: 12,
                        color: widget.isDark
                            ? Colors.grey[400]
                            : Colors.grey[600],
                      ),
                    ),
                    if (widget.tweet.isPinnedStatus) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.push_pin, size: 12, color: Colors.orange),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // follow pill (only for other users) + options
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!_isOwnPost && !_isCheckingFollow)
                GestureDetector(
                  onTap: _isTogglingFollow ? null : _toggleFollow,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _isFollowing
                          ? (widget.isDark
                          ? const Color(0xFF3A3B3C)
                          : const Color(0xFFE4E6EB))
                          : _blue,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: _isTogglingFollow
                        ? SizedBox(
                      width: 46,
                      height: 16,
                      child: Center(
                        child: SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _isFollowing
                                ? (widget.isDark
                                ? Colors.white70
                                : Colors.grey[700])
                                : Colors.white,
                          ),
                        ),
                      ),
                    )
                        : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isFollowing ? Icons.check : Icons.add,
                          size: 13,
                          color: _isFollowing
                              ? (widget.isDark
                              ? Colors.grey[300]
                              : Colors.grey[700])
                              : Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _isFollowing ? 'Following' : 'Follow',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _isFollowing
                                ? (widget.isDark
                                ? Colors.grey[300]
                                : Colors.grey[700])
                                : Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (!_isOwnPost && !_isCheckingFollow)
                const SizedBox(width: 4),
              _optionsMenu(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _roleBadge() {
    final isCompany = widget.tweetPoster.getAs<Company>() != null;
    final isAdmin = widget.tweetPoster.getAs<Admin>() != null;
    final isStudent = widget.tweetPoster.getAs<Student>() != null;

    String label;
    Color color;

    if (isCompany) {
      label = 'Company';
      color = const Color(0xFF34A853);
    } else if (isAdmin) {
      label = 'Admin';
      color = const Color(0xFFEA4335);
    } else if (isStudent) {
      label = 'Student';
      color = const Color(0xFFFBBC05);
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }

  // ── Post body ─────────────────────────────────────────────────────────────

  Widget _buildBody() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExpandableText(text: widget.tweet.content, isDark: widget.isDark),
          if (widget.tweet.hasHashtags) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: (widget.tweet.hashtags ?? []).map((tag) {
                return GestureDetector(
                  onTap: () {},
                  child: Text('#$tag',
                      style: const TextStyle(
                          color: _blue,
                          fontSize: 14,
                          fontWeight: FontWeight.w500)),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImage() {
    return GestureDetector(
      onTap: widget.onTap,
      child: Image.network(
        widget.tweet.imageUrl!,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      ),
    );
  }

  // ── Stats row (likes • comments • shares) ────────────────────────────────

  Widget _buildStats(Color divider) {
    final likeCount = widget.tweet.likes.length;
    final commentCount = widget.tweet.commentCount;
    final shareCount = widget.tweet.shareCount;

    if (likeCount == 0 && commentCount == 0 && shareCount == 0) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Row(
        children: [
          if (likeCount > 0) ...[
            Container(
              width: 18,
              height: 18,
              decoration: const BoxDecoration(
                  color: _blue, shape: BoxShape.circle),
              child: const Icon(Icons.thumb_up, size: 10, color: Colors.white),
            ),
            const SizedBox(width: 4),
            Text(
              _fmt(likeCount),
              style: TextStyle(
                  fontSize: 13,
                  color: widget.isDark ? Colors.grey[400] : Colors.grey[600]),
            ),
          ],
          const Spacer(),
          if (commentCount > 0)
            GestureDetector(
              onTap: widget.onTap,
              child: Text(
                '${_fmt(commentCount)} comments',
                style: TextStyle(
                    fontSize: 13,
                    color: widget.isDark ? Colors.grey[400] : Colors.grey[600]),
              ),
            ),
          if (commentCount > 0 && shareCount > 0)
            Text(' · ',
                style: TextStyle(
                    color: widget.isDark
                        ? Colors.grey[600]
                        : Colors.grey[400])),
          if (shareCount > 0)
            Text(
              '${_fmt(shareCount)} shares',
              style: TextStyle(
                  fontSize: 13,
                  color: widget.isDark ? Colors.grey[400] : Colors.grey[600]),
            ),
        ],
      ),
    );
  }

  // ── Action buttons row ───────────────────────────────────────────────────

  Widget _buildActions(Color divider) {
    final liked = widget.tweet.likes.contains(GlobalIdService.firestoreId);

    return Row(
      children: [
        _actionBtn(
          icon: liked ? Icons.thumb_up : Icons.thumb_up_outlined,
          label: 'Like',
          active: liked,
          activeColor: _blue,
          onTap: _toggleLike,
        ),
        _actionBtn(
          icon: Icons.mode_comment_outlined,
          label: 'Comment',
          active: false,
          onTap: () => _showCommentSheet(),
        ),
        _actionBtn(
          icon: Icons.share_outlined,
          label: 'Share',
          active: false,
          onTap: () => _share(),
        ),
      ],
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required bool active,
    Color? activeColor,
    required VoidCallback onTap,
  }) {
    final color = active
        ? (activeColor ?? _blue)
        : (widget.isDark ? Colors.grey[400]! : Colors.grey[600]!);

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 19, color: color),
                const SizedBox(width: 6),
                Text(label,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: color)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Latest comment preview ───────────────────────────────────────────────

  Widget _buildLatestComment(Color divider) {
    final last = widget.tweet.comments.last;
    final count = widget.tweet.comments.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
          child: GestureDetector(
            onTap: widget.onTap,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: widget.isDark
                      ? const Color(0xFF3A3B3C)
                      : const Color(0xFFE4E6EB),
                  child: Text(
                    last.user.isNotEmpty ? last.user[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: widget.isDark ? Colors.grey[300] : Colors.grey[700],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: widget.isDark
                          ? const Color(0xFF3A3B3C)
                          : const Color(0xFFf0f2f5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          last.user,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: widget.isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          last.content,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: widget.isDark
                                ? Colors.grey[300]
                                : Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (count > 1)
          Padding(
            padding: const EdgeInsets.only(left: 50, bottom: 8),
            child: GestureDetector(
              onTap: widget.onTap,
              child: Text(
                'View all $count comments',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _blue),
              ),
            ),
          )
        else
          const SizedBox(height: 8),
      ],
    );
  }

  // ── Options popup ────────────────────────────────────────────────────────

  Widget _optionsMenu() {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_horiz,
        size: 20,
        color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
      ),
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: _handleOption,
      itemBuilder: (_) => [
        if (_isOwnPost)
          _menuItem('delete', Icons.delete_outline, 'Delete post', Colors.red),
        _menuItem('save', Icons.bookmark_border_rounded, 'Save post',
            widget.isDark ? Colors.grey[300]! : Colors.grey[700]!),
        _menuItem('report', Icons.flag_outlined, 'Report post', Colors.red),
      ],
    );
  }

  PopupMenuItem<String> _menuItem(
      String value, IconData icon, String label, Color color) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: color)),
        ],
      ),
    );
  }

  void _handleOption(String value) {
    switch (value) {
      case 'delete':
        _deletePost();
        break;
      case 'save':
        _savePost();
        break;
      case 'report':
        _reportPost();
        break;
    }
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  void _toggleLike() {
    try {
      final provider = Provider.of<TweetProvider>(context, listen: false);
      final liked =
      widget.tweet.likes.contains(widget.currentUser.uid);
      provider.toggleLike(widget.tweet.id, widget.currentUser.uid, liked);
      setState(() => _isLiked = !liked);
    } catch (e) {
      _snack('Error: $e', color: Colors.red);
    }
  }

  void _showCommentSheet() {
    final isDark = widget.isDark;
    final surface = isDark ? const Color(0xFF242526) : Colors.white;
    final divider = isDark ? const Color(0xFF3A3B3C) : const Color(0xFFE4E6EB);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: MediaQuery.of(context).viewInsets,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Comment',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black)),
                  const Spacer(),
                  IconButton(
                      icon: Icon(Icons.close,
                          color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      onPressed: () => Navigator.pop(context)),
                ],
              ),
              Divider(height: 1, color: divider),
              const SizedBox(height: 12),
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.grey.shade300,
                    backgroundImage: widget.currentUser.imageUrl.isNotEmpty
                        ? NetworkImage(widget.currentUser.imageUrl)
                        : null,
                    child: widget.currentUser.imageUrl.isEmpty
                        ? Text(widget.currentUser.displayName[0])
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _commentCtrl,
                      autofocus: true,
                      maxLines: 4,
                      minLines: 1,
                      style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontSize: 15),
                      decoration: InputDecoration(
                        hintText: 'Write a comment...',
                        hintStyle: TextStyle(
                            color:
                            isDark ? Colors.grey[500] : Colors.grey[400]),
                        filled: true,
                        fillColor: isDark
                            ? const Color(0xFF3A3B3C)
                            : const Color(0xFFf0f2f5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatefulBuilder(builder: (ctx, setBtn) {
                    return IconButton(
                      onPressed: () {
                        if (_commentCtrl.text.trim().isEmpty) return;
                        _postComment();
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.send_rounded, color: _blue),
                    );
                  }),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _postComment() {
    if (_commentCtrl.text.trim().isEmpty) return;
    Provider.of<TweetProvider>(context, listen: false).postCommentToTweet(
      widget.tweet.id,
      _commentCtrl.text.trim(),
      widget.currentUser,
    );
    _commentCtrl.clear();
    _snack('Comment posted');
  }

  void _share() {
    showDialog(
      context: context,
      builder: (_) => UserSelectionDialog(
        tweetContent:
        GeneralMethods.formatTweetShare(widget.tweet.content, widget.tweet.id),
        tweetId: widget.tweet.id,
      ),
    );
  }

  void _savePost() async {
    final saved = await _tweetService.isTweetSavedByUser(
        GlobalIdService.firestoreId, widget.tweet.id);
    if (saved) {
      _snack('Already saved — tap the bookmark icon to view', color: Colors.orange);
      return;
    }
    await _tweetService.saveTweet(
        userId: GlobalIdService.firestoreId, tweetId: widget.tweet.id);
    _snack('Post saved');
  }

  void _reportPost() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Report post'),
        content:
        const Text('Are you sure you want to report this post?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _snack('Post reported');
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
            child: const Text('Report'),
          ),
        ],
      ),
    );
  }

  void _deletePost() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Delete post'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Provider.of<TweetProvider>(context, listen: false)
                  .deleteTweet(widget.tweet.id, context);
              _snack('Post deleted');
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _navigateToProfile() {
    final isCompany = widget.tweetPoster.getAs<Company>() != null;
    final isStudent = widget.tweetPoster.getAs<Student>() != null;
    final isAdmin = widget.tweetPoster.getAs<Admin>() != null;

    if (isCompany && !isStudent) {
      GeneralMethods.navigateTo(
          context,
          CompanyDetailPage(
              company: widget.tweetPoster.getAs<Company>()!,
              user: widget.currentUser));
    } else if (isStudent) {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => StudentProfilePage(
                  student: widget.tweetPoster.getAs<Student>()!)));
    } else if (isAdmin) {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => AdminProfilePage(
                  admin: widget.tweetPoster.getAs<Admin>()!,
                  currentStudent: widget.currentUser)));
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// _TweetSkeleton  — shown while a post's author is being fetched
// ─────────────────────────────────────────────────────────────────────────────

class _TweetSkeleton extends StatelessWidget {
  final bool isDark;
  const _TweetSkeleton({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? const Color(0xFF242526) : Colors.white;
    final shimmer = isDark ? const Color(0xFF3A3B3C) : const Color(0xFFE4E6EB);

    return Container(
      color: surface,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _box(42, 42, shimmer, radius: 21),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _box(120, 13, shimmer),
              const SizedBox(height: 6),
              _box(80, 11, shimmer),
            ]),
          ]),
          const SizedBox(height: 14),
          _box(double.infinity, 13, shimmer),
          const SizedBox(height: 7),
          _box(220, 13, shimmer),
          const SizedBox(height: 7),
          _box(160, 13, shimmer),
        ],
      ),
    );
  }

  Widget _box(double w, double h, Color color, {double radius = 6}) =>
      Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
}


// ─────────────────────────────────────────────────────────────────────────────
// Public alias so the rest of the app can still import ProfessionalTweetCard
// ─────────────────────────────────────────────────────────────────────────────

/// Alias kept for backward compatibility with CompanyDetailPage and
/// StudentProfilePage which import ProfessionalTweetCard directly.
typedef ProfessionalTweetCard = _FbTweetCard;