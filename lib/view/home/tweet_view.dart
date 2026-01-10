import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:itc_institute_admin/model/userProfile.dart';
import 'package:itc_institute_admin/view/company/companyDetailPage.dart';
import 'package:itc_institute_admin/view/home/savedPost.dart';
import 'package:itc_institute_admin/view/home/student/studentDetails.dart';
import 'package:itc_institute_admin/view/home/tweet/tweet_details_page.dart';
import 'package:itc_institute_admin/view/home/tweet/user_selection_dialog.dart';
import 'package:provider/provider.dart';

import '../../../../itc_logic/firebase/tweet/tweet_cloud.dart';
import '../../auth/tweet_provider.dart';
import '../../generalmethods/GeneralMethods.dart';
import '../../model/admin.dart';
import '../../model/comments_model.dart';
import '../../model/company.dart';
import '../../model/student.dart';
import '../../model/tweetModel.dart';
import '../adminProfilePage.dart';

class TweetView extends StatefulWidget {
  final Company company;
  const TweetView({Key? key, required this.company}) : super(key: key);
  @override
  _TweetViewState createState() => _TweetViewState();
}

class _TweetViewState extends State<TweetView> {
  final TextEditingController _tweetController = TextEditingController();
  final TweetService _tweetService = TweetService();
  final ScrollController _scrollController = ScrollController();
  bool _isComposing = false;
  bool _isRefreshing = false;
  bool _showScrollToTop = false;
  final tweetService = TweetService();

  @override
  void initState() {
    super.initState();

    // Add listener for scroll controller to show/hide scroll-to-top button
    _scrollController.addListener(() {
      if (_scrollController.offset > 400 && !_showScrollToTop) {
        setState(() => _showScrollToTop = true);
      } else if (_scrollController.offset <= 400 && _showScrollToTop) {
        setState(() => _showScrollToTop = false);
      }
    });

    // Add listener for text controller (remove debug prints)
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tweetController.dispose();
    super.dispose();
  }

  Future<void> _refreshTweets() async {
    setState(() => _isRefreshing = true);

    try {
      final provider = Provider.of<TweetProvider>(context, listen: false);
      await provider.refreshTweets();

      // Show success feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Feed updated'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error refreshing: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isRefreshing = false);
    }
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;
    _tweetController.addListener(() {
      // print('Text field content: "${_tweetController.text}"');
      // print('Trimmed content: "${_tweetController.text.trim()}"');
      // print('Is empty: ${_tweetController.text.trim().isEmpty}');
      TweetProvider provider = Provider.of<TweetProvider>(
        context,
        listen: false,
      );
      provider.tweetControllerTextChanged();
    });
    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFf0f2f5),
      appBar: _buildAppBar(isDark, colors),
      floatingActionButton: _buildFloatingActionButtons(isDark),
      body: Stack(
        children: [
          // Main Content with RefreshIndicator
          RefreshIndicator(
            onRefresh: _refreshTweets,
            color: const Color(0xFF1DA1F2),
            backgroundColor: isDark ? Colors.grey[900] : Colors.white,
            displacement: 40,
            strokeWidth: 3,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildWelcomeHeader(context, isDark)),
                SliverToBoxAdapter(child: _buildQuickActionBar(isDark)),
                SliverToBoxAdapter(child: _buildRefreshHeader(isDark)),
                _buildTweetList(isDark),
                const SliverToBoxAdapter(
                  child: SizedBox(height: 80), // Extra padding at bottom
                ),
              ],
            ),
          ),

          // Compose Modal Overlay
          if (_isComposing)
            Positioned.fill(child: _buildComposeModal(context, isDark, colors)),

          // Scroll to top button
          if (_showScrollToTop)
            Positioned(
              bottom: 100,
              right: 20,
              child: _buildScrollToTopButton(isDark),
            ),
        ],
      ),
    );
  }

  AppBar _buildAppBar(bool isDark, ColorScheme colors) {
    return AppBar(
      elevation: 0,
      backgroundColor: isDark ? Colors.black : Colors.white,
      surfaceTintColor: Colors.transparent,
      leading: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: CircleAvatar(
          radius: 18,
          backgroundImage: NetworkImage(widget.company.logoURL),
          backgroundColor: Colors.grey[300],
        ),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'IT Connect Feed',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 20,
              letterSpacing: -0.5,
            ),
          ),
          Text(
            'Latest from the community',
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],
      ),
      actions: [
        // Refresh button
        IconButton(
          icon: Icon(Icons.favorite, color: Colors.green, size: 24),
          onPressed: () {
            GeneralMethods.navigateTo(
              context,
              SavedPostsPage(
                company: UserConverter(widget.company),
                tweetService: tweetService,
              ),
            );
          },
        ),
        IconButton(
          icon: Icon(
            Icons.search,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
            size: 24,
          ),
          onPressed: () {},
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildFloatingActionButtons(bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Scroll to top button
        if (_showScrollToTop)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: FloatingActionButton.small(
              onPressed: _scrollToTop,
              backgroundColor: isDark ? Colors.grey[800] : Colors.white,
              child: Icon(
                Icons.arrow_upward,
                color: isDark ? Colors.white : Colors.black,
                size: 20,
              ),
            ),
          ),

        // Compose button
        if (!_isComposing)
          FloatingActionButton(
            heroTag: GeneralMethods.getUniqueHeroTag(),
            onPressed: () => setState(() => _isComposing = true),
            backgroundColor: const Color(0xFF1DA1F2),
            child: const Icon(Icons.edit, color: Colors.white),
          ),
      ],
    );
  }

  Widget _buildRefreshHeader(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Latest Posts',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          GestureDetector(
            onTap: _refreshTweets,
            child: Row(
              children: [
                Icon(Icons.refresh, size: 16, color: const Color(0xFF1DA1F2)),
                const SizedBox(width: 6),
                Text(
                  'Refresh',
                  style: TextStyle(
                    color: const Color(0xFF1DA1F2),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScrollToTopButton(bool isDark) {
    return FloatingActionButton.small(
      onPressed: _scrollToTop,
      backgroundColor: isDark ? Colors.grey[800] : Colors.white,
      elevation: 4,
      child: Icon(
        Icons.arrow_upward,
        color: isDark ? Colors.white : Colors.black,
        size: 20,
      ),
    );
  }

  Widget _buildWelcomeHeader(BuildContext context, bool isDark) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1a237e), const Color(0xFF283593)]
              : [const Color(0xFF667eea), const Color(0xFF764ba2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667eea).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back, ${widget.company.name.split(' ').first}!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Share your thoughts, ask questions, or discuss industry trends.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${Provider.of<TweetProvider>(context).tweets.length} posts',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Live updates',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.rocket_launch,
              color: Colors.white,
              size: 32,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionBar(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1a1a1a) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildQuickAction(
            icon: Icons.trending_up,
            label: 'Trending',
            isDark: isDark,
            onTap: () {},
          ),
          _buildQuickAction(
            icon: Icons.question_answer,
            label: 'Questions',
            isDark: isDark,
            onTap: () {},
          ),
          _buildQuickAction(
            icon: Icons.work,
            label: 'IT',
            isDark: isDark,
            onTap: () {},
          ),
          _buildQuickAction(
            icon: Icons.lightbulb,
            label: 'Tips',
            isDark: isDark,
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[900] : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF667eea), size: 20),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  // Keep your existing _buildComposeModal method (it's already good)
  // Keep your existing _buildComposeAction method
  // Keep your existing _buildTweetList method
  // Keep your existing _buildTweetSkeleton method

  Widget _buildComposeModal(
    BuildContext context,
    bool isDark,
    ColorScheme colors,
  ) {
    return Stack(
      children: [
        // Backdrop
        Positioned.fill(
          child: Container(
            color: Colors.black.withOpacity(0.5),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _isComposing = false;
                  _tweetController.clear();
                });
              },
              child: Container(color: Colors.transparent),
            ),
          ),
        ),

        // Compose Modal
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[900] : Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Create Post',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.close,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                          onPressed: () {
                            setState(() {
                              _isComposing = false;
                              _tweetController.clear();
                            });
                          },
                        ),
                      ],
                    ),

                    // User Info
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundImage: NetworkImage(
                              widget.company.logoURL,
                            ),
                            backgroundColor: Colors.grey[300],
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.company.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                              Text(
                                '@${widget.company.email.split('@').first}',
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Text Input
                    TextField(
                      controller: _tweetController,
                      maxLines: 5,
                      minLines: 3,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontSize: 16,
                      ),
                      decoration: InputDecoration(
                        hintText: "What's happening in the IT world?",
                        hintStyle: TextStyle(
                          color: isDark ? Colors.grey[500] : Colors.grey[400],
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),

                    // Action Bar
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Row(
                        children: [
                          _buildComposeAction(
                            icon: Icons.image,
                            label: 'Photo',
                            isDark: isDark,
                          ),
                          _buildComposeAction(
                            icon: Icons.gif,
                            label: 'GIF',
                            isDark: isDark,
                          ),
                          _buildComposeAction(
                            icon: Icons.poll,
                            label: 'Poll',
                            isDark: isDark,
                          ),
                          const Spacer(),
                          Consumer<TweetProvider>(
                            builder: (context, provider, child) {
                              final isButtonDisabled = _tweetController.text
                                  .trim()
                                  .isEmpty;

                              return ElevatedButton(
                                onPressed: () {
                                  provider.postTweet(
                                    _tweetController.text.trim(),
                                    widget.company.name,
                                  );
                                  _tweetController.clear();
                                  setState(() {
                                    _isComposing = false;
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text(
                                        'Post published successfully',
                                      ),
                                      backgroundColor: Colors.green,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isButtonDisabled
                                      ? Colors.grey[400]
                                      : const Color(0xFF1DA1F2),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                ),
                                child: Text(
                                  'Post',
                                  style: TextStyle(
                                    color: isButtonDisabled
                                        ? Colors.grey[600]
                                        : Colors.white,
                                    fontWeight: FontWeight.w600,
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
              ),
            ),
          ),
        ),
      ],
    );
  }

  // @override
  // void initState() {
  //   // TODO: implement initState
  //   super.initState();
  //   _tweetController.addListener(() {
  //     print('Text field content: "${_tweetController.text}"');
  //     print('Trimmed content: "${_tweetController.text.trim()}"');
  //     print('Is empty: ${_tweetController.text.trim().isEmpty}');
  //   });
  // }

  Widget _buildComposeAction({
    required IconData icon,
    required String label,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.grey[100],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: const Color(0xFF1DA1F2)),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTweetList(bool isDark) {
    return Consumer<TweetProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    color: Color(0xFF1DA1F2),
                    strokeWidth: 2,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading community posts...',
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (provider.tweets.isEmpty) {
          return SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[900] : Colors.grey[100],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.forum_outlined,
                      size: 64,
                      color: isDark ? Colors.grey[700] : Colors.grey[400],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'No posts yet',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Be the first to start a conversation!',
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _isComposing = true;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1DA1F2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                    ),
                    child: const Text(
                      'Create First Post',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {

            if (index == provider.tweets.length) {
              // If there are more tweets to load
              if (provider.hasMore) {
                // Trigger load more
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  provider.loadMoreTweets();
                });

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Center(
                    child: provider.isLoadingMore
                        ? CircularProgressIndicator(
                      color: Color(0xFF1DA1F2),
                    )
                        : TextButton(
                      onPressed: provider.loadMoreTweets,
                      child: Text(
                        'Load More',
                        style: TextStyle(
                          color: Color(0xFF1DA1F2),
                        ),
                      ),
                    ),
                  ),
                );
              } else {
                // No more tweets to load
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Center(
                    child: Text(
                      'No more posts',
                      style: TextStyle(
                        color: isDark ? Colors.grey[500] : Colors.grey[600],
                      ),
                    ),
                  ),
                );
              }
            }
            final tweet = provider.tweets[index];
            return FutureBuilder<Map<String, dynamic>>(
              future: provider.fetchAllStudents([tweet]),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return _buildTweetSkeleton(isDark);
                }

                final studentMap = snapshot.data!;
                final tweetPoster = studentMap[tweet.userId];

                if (tweetPoster == null) {
                  return Container();
                }

                return Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1a1a1a) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ProfessionalTweetCard(
                    tweet: tweet,
                    tweetPoster: tweetPoster,
                    currentStudent: widget.company,
                    isDark: isDark,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TweetDetailPage(
                            tweetId: tweet.id,
                            company: tweetPoster,
                            user: UserConverter(widget.company),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          }, childCount: provider.tweets.length + 1,),
        );
      },
    );
  }

  Widget _buildTweetSkeleton(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1a1a1a) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 120,
                      height: 16,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.grey[200],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 80,
                      height: 12,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.grey[200],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                height: 14,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 200,
                height: 14,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ProfessionalTweetCard extends StatefulWidget {
  final TweetModel tweet;
  final UserConverter tweetPoster;
  final Company currentStudent;
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
  final TextEditingController _commentController = TextEditingController();
  final tweetService = TweetService();

  @override
  void initState() {
    super.initState();
    _isLiked = widget.tweet.isLiked;
    _isShared = widget.tweet.isShared;
  }

  @override
  Widget build(BuildContext context) {
    final timeAgo = widget.tweet.timeAgo;
    TweetProvider provider = Provider.of<TweetProvider>(context);
    _commentController.addListener(() {
      provider.tweetControllerTextChanged();
    });
    return InkWell(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        color: widget.isDark ? Colors.grey[900] : Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with clickable name
            _buildHeader(timeAgo),

            // Content
            _buildContent(),

            // Facebook-style stats (top)
            _buildFacebookStats(),

            // Facebook-style action buttons (bottom)
            _buildFacebookActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String timeAgo) {
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Clickable name
                GestureDetector(
                  onTap: _navigateToProfile,
                  child: Text(
                    widget.tweetPoster.uid.startsWith('admin_')?'${widget.tweetPoster.displayName.split(' ').first} ITC Rep' : widget.tweetPoster.displayName,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: widget.isDark ? Colors.white : Colors.black,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      timeAgo,
                      style: TextStyle(
                        color: widget.isDark
                            ? Colors.grey[400]
                            : Colors.grey[600],
                        fontSize: 12,
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
          // Facebook-style options dropdown
          _buildFacebookOptionsDropdown(),
        ],
      ),
    );
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
        if (widget.currentStudent.id == widget.tweet.userId)
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
        // if (widget.currentStudent.uid == widget.tweet.userId)
        //   PopupMenuItem<String>(
        //     value: 'edit',
        //     child: Row(
        //       children: [
        //         Icon(Icons.edit, color: Colors.grey[600], size: 20),
        //         const SizedBox(width: 8),
        //         const Text('Edit Post'),
        //       ],
        //     ),
        //   ),
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
        // PopupMenuItem<String>(
        //   value: 'copy',
        //   child: Row(
        //     children: [
        //       Icon(Icons.link, color: Colors.grey[600], size: 20),
        //       const SizedBox(width: 8),
        //       const Text('Copy Link'),
        //     ],
        //   ),
        // ),
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

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.tweet.content,
            style: TextStyle(
              fontSize: 15,
              height: 1.4,
              color: widget.isDark ? Colors.white : Colors.black,
            ),
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
                        color: const Color(0xFF1877F2), // Facebook blue
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

          // Show image if available
          if (widget.tweet.imageUrl != null &&
              widget.tweet.imageUrl!.isNotEmpty)
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
                  color: const Color(0xFF1877F2), // Facebook blue
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
            icon:
                widget.tweet.likes.contains(
                  FirebaseAuth.instance.currentUser!.uid,
                )
                ? Icons.thumb_up
                : Icons.thumb_up_outlined,
            label: 'Like',
            isActive: _isLiked,
            color:
                widget.tweet.likes.contains(
                  FirebaseAuth.instance.currentUser!.uid,
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
            onTap: () =>
                _shareTweet(widget.tweet.content, context, widget.tweet.id),
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
          borderRadius: BorderRadius.circular(4),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color:
                      color ??
                      (widget.isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color:
                        color ??
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

  // Action Methods
  void _navigateToProfile() {
    bool isCompany = widget.tweetPoster.getAs<Company>() != null;
    bool isStudent = widget.tweetPoster.getAs<Student>() != null;
    bool isAdmin = widget.tweetPoster.getAs<Admin>() !=null;
    if (isCompany && !isStudent) {
      GeneralMethods.navigateTo(
        context,
        CompanyDetailPage(
            company: widget.tweetPoster.getAs<Company>()!),
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
    }else if (!isStudent && !isCompany && isAdmin) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AdminProfilePage(
            admin: widget.tweetPoster.getAs<Admin>()!,
            currentStudent: UserConverter(widget.currentStudent),
          ),
        ),
      );
    }
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
      bool isLike = widget.tweet.likes.contains(widget.currentStudent.id);
      await provider.toggleLike(
        widget.tweet.id,
        widget.currentStudent.id,
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
                            widget.currentStudent.logoURL,
                          ),
                          backgroundColor: Colors.grey[300],
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.currentStudent.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: widget.isDark
                                    ? Colors.white
                                    : Colors.black,
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
      userId: widget.currentStudent.id,
      user: widget.currentStudent.name,
      content: _commentController.text.trim(),
      timestamp: DateTime.now(),
    );
    Provider.of<TweetProvider>(context, listen: false).postCommentToTweet(
      widget.tweet.id,
      _commentController.text.trim(),
      UserConverter(widget.currentStudent),
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

  void _bookmarkTweet() async {
    //save implementations
    bool isTweetSaved = await tweetService.isTweetSavedByUser(
      FirebaseAuth.instance.currentUser!.uid,
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
    debugPrint("userid ${FirebaseAuth.instance.currentUser!.uid}");
    debugPrint("tweetId ${widget.tweet.id}");
    await tweetService.saveTweet(
      userId: FirebaseAuth.instance.currentUser!.uid,
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
