import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:itc_institute_admin/itc_logic/service/ConverterUserService.dart';
import 'package:itc_institute_admin/view/home/tweet/tweet_details_page.dart';
import 'package:provider/provider.dart';

import '../../../../itc_logic/firebase/tweet/tweet_cloud.dart';
import '../../itc_logic/firebase/general_cloud.dart';
import '../../model/tweetModel.dart';
import '../../model/userProfile.dart';

class SavedPostsPage extends StatefulWidget {
  final UserConverter company;
  final TweetService tweetService;
  const SavedPostsPage({
    Key? key,
    required this.company,
    required this.tweetService,
  }) : super(key: key);
  @override
  State<SavedPostsPage> createState() => _SavedPostsPageState();
}

class _SavedPostsPageState extends State<SavedPostsPage> {
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = true;
  bool _isLoadingMore = false;
  List<TweetModel> _savedTweets = [];
  String? _currentUserId;
  SortType _currentSortType = SortType.newestFirst;
  String _searchQuery = '';
  final ITCFirebaseLogic itcFirebaseLogic = ITCFirebaseLogic();
  final UserService userService = UserService();

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Load tweets here instead of initState
    if (_currentUserId != null && _isLoading) {
      _loadSavedTweets();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _getCurrentUser() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _currentUserId = user.uid;
      // Don't call _loadSavedTweets() here - wait for didChangeDependencies
    } else {
      // Handle user not logged in
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadSavedTweets() async {
    if (_currentUserId == null || !mounted) return;

    try {
      final tweets = await widget.tweetService.getSavedTweetsPaginated(
        userId: _currentUserId!,
        limit: 20,
      );

      if (mounted) {
        setState(() {
          _savedTweets = tweets;
          _sortTweets();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading saved tweets: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackbar('Failed to load saved posts');
      }
    }
  }

  Future<void> _loadMoreTweets() async {
    if (_isLoadingMore || _currentUserId == null || !mounted) return;

    setState(() => _isLoadingMore = true);

    try {
      final tweetService = Provider.of<TweetService>(context, listen: false);
      final newTweets = await tweetService.getSavedTweetsPaginated(
        userId: _currentUserId!,
        limit: 20,
      );

      if (mounted) {
        setState(() {
          _savedTweets.addAll(newTweets);
          _sortTweets();
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
        print('Error loading more tweets: $e');
      }
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      _loadMoreTweets();
    }
  }

  void _sortTweets() {
    switch (_currentSortType) {
      case SortType.newestFirst:
        _savedTweets.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        break;
      case SortType.oldestFirst:
        _savedTweets.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        break;
      case SortType.mostLikes:
        _savedTweets.sort((a, b) => b.likes.length.compareTo(a.likes.length));
        break;
      case SortType.mostComments:
        _savedTweets.sort(
          (a, b) => b.comments.length.compareTo(a.comments.length),
        );
        break;
    }
  }

  List<TweetModel> _getFilteredTweets() {
    if (_searchQuery.isEmpty) return _savedTweets;

    return _savedTweets
        .where(
          (tweet) =>
              tweet.content.toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ) ||
              tweet.user.toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .toList();
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  Future<void> _onUnsavePost(String tweetId, int index) async {
    if (_currentUserId == null || !mounted) return;

    try {
      final tweetService = Provider.of<TweetService>(context, listen: false);
      await tweetService.removeSavedTweetByUserAndTweetId(
        _currentUserId!,
        tweetId,
      );

      if (mounted) {
        setState(() {
          _savedTweets.removeAt(index);
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Post removed from saved'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () async {
                await tweetService.saveTweet(
                  userId: _currentUserId!,
                  tweetId: tweetId,
                );
                _loadSavedTweets();
              },
            ),
          ),
        );
      }
    } catch (e) {
      _showErrorSnackbar('Failed to unsave post');
    }
  }

  void _onPostTap(TweetModel tweet) async {
    UserConverter? user = await userService.getUser(tweet.user);
    if (user == null) {
      _showErrorSnackbar('Failed to load user');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TweetDetailPage(
          tweetId: tweet.id,
          user: widget.company,
          company: user,
        ),
      ),
    );
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sort by',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ...SortType.values.map((sortType) {
                return ListTile(
                  leading: Icon(
                    _getSortIcon(sortType),
                    color: _currentSortType == sortType
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  title: Text(
                    _getSortLabel(sortType),
                    style: TextStyle(
                      fontWeight: _currentSortType == sortType
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: _currentSortType == sortType
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  trailing: _currentSortType == sortType
                      ? Icon(
                          Icons.check,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                  onTap: () {
                    setState(() {
                      _currentSortType = sortType;
                      _sortTweets();
                    });
                    Navigator.pop(context);
                  },
                );
              }).toList(),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  IconData _getSortIcon(SortType sortType) {
    switch (sortType) {
      case SortType.newestFirst:
        return Icons.new_releases;
      case SortType.oldestFirst:
        return Icons.history;
      case SortType.mostLikes:
        return Icons.favorite;
      case SortType.mostComments:
        return Icons.chat_bubble;
    }
  }

  String _getSortLabel(SortType sortType) {
    switch (sortType) {
      case SortType.newestFirst:
        return 'Newest First';
      case SortType.oldestFirst:
        return 'Oldest First';
      case SortType.mostLikes:
        return 'Most Likes';
      case SortType.mostComments:
        return 'Most Comments';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final filteredTweets = _getFilteredTweets();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Posts'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.sort), onPressed: _showSortOptions),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _currentUserId == null
          ? _buildLoginRequiredState()
          : _savedTweets.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _loadSavedTweets,
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  /// 🔍 Search bar
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search saved posts...',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (value) {
                          setState(() => _searchQuery = value);
                        },
                      ),
                    ),
                  ),

                  /// 📊 Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        '${filteredTweets.length} posts',
                        style: textTheme.bodyMedium,
                      ),
                    ),
                  ),

                  /// 🧱 Grid
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.8,
                          ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final tweet = filteredTweets[index];
                        return _SavedPostGridCard(
                          tweet: tweet,
                          index: index,
                          onTap: () => _onPostTap(tweet),
                          onUnsave: () => _onUnsavePost(tweet.id, index),
                        );
                      }, childCount: filteredTweets.length),
                    ),
                  ),

                  if (_isLoadingMore)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
              ),
            ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Loading saved posts...',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }

  Widget _buildLoginRequiredState() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.login,
              size: 80,
              color: colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'Login Required',
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Please login to view saved posts',
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bookmark_outline_rounded,
              size: 80,
              color: colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'No saved posts yet',
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Tap the bookmark icon on any post to save it here',
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: const Icon(Icons.explore),
              label: const Text('Explore Posts'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedPostGridCard extends StatelessWidget {
  final TweetModel tweet;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onUnsave;

  const _SavedPostGridCard({
    required this.tweet,
    required this.index,
    required this.onTap,
    required this.onUnsave,
  });

  String _truncateText(String text, {int maxLength = 80}) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 365) {
      return '${date.year}';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()}mo';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else {
      return '${difference.inMinutes}m';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      colorScheme.primary.withOpacity(0.1),
                      colorScheme.surface.withOpacity(0.5),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User info and timestamp
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: colorScheme.surfaceVariant,
                        child: Text(
                          tweet.user.substring(0, 1).toUpperCase(),
                          style: textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          tweet.user,
                          style: textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _formatDate(tweet.timestamp),
                        style: textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Content preview
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.surface.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _truncateText(tweet.content),
                        style: textTheme.bodyMedium?.copyWith(height: 1.4),
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Stats
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.favorite_outline,
                            size: 14,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${tweet.likes.length}',
                            style: textTheme.labelSmall,
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 14,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${tweet.comments.length}',
                            style: textTheme.labelSmall,
                          ),
                        ],
                      ),
                      Icon(
                        Icons.bookmark,
                        size: 14,
                        color: colorScheme.primary,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Unsave button (floating)
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: onUnsave,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: colorScheme.surface.withOpacity(0.9),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.shadow.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(Icons.close, size: 14, color: colorScheme.error),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum SortType { newestFirst, oldestFirst, mostLikes, mostComments }
