import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/tweet_provider.dart';
import '../../generalmethods/GeneralMethods.dart';
import '../../itc_logic/firebase/company_cloud.dart';
import '../../itc_logic/firebase/general_cloud.dart';
import '../../itc_logic/idservice/globalIdService.dart';
import '../../itc_logic/service/followService.dart';
import '../../itc_logic/service/privacySettingsService.dart';
import '../../model/company.dart';
import '../../model/privacySettingModel.dart';
import '../../model/review.dart';
import '../../model/student.dart';
import '../../model/userProfile.dart';
import '../home/chat/chartPage.dart';
import '../home/tweet/tweet_details_page.dart';
import '../home/tweet_view.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';


class CompanyDetailPage extends StatefulWidget {
  final Company company;
  final UserConverter user;

  const CompanyDetailPage({
    Key? key,
    required this.company,
    required this.user,
  }) : super(key: key);

  @override
  State<CompanyDetailPage> createState() => _CompanyDetailPageState();
}

class _CompanyDetailPageState extends State<CompanyDetailPage>
    with TickerProviderStateMixin {

  // services
  final Company_Cloud _companyCloud = Company_Cloud(GlobalIdService.firestoreId);
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FollowService _followService = FollowService();

  // controllers & state
  late TabController _tabController;
  double _rating = 0.0;
  String _currentUserId = "";
  late PrivacySettings _privacySettings;

  // loading flags
  bool _isCheckingPermission = true;
  bool _hasAccess = false;

  // follow state
  bool _isFollowing = false;
  bool _isCheckingFollow = true;
  bool _isTogglingFollow = false;

  static const _gradientStart = Color(0xFF3563E9);
  static const _gradientEnd = Color(0xFF667eea);

  @override
  void initState() {
    super.initState();
    _checkPermissionAndInitialize();
  }

  @override
  void dispose() {
    if (_hasAccess) _tabController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------
  // Init
  // ------------------------------------------------------------------

  Future<void> _checkPermissionAndInitialize() async {
    final hasAccess = await _canViewProfile();
    if (!mounted) return;

    if (hasAccess) {
      // 4 tabs: About, Posts, Reviews, Contact
      _tabController = TabController(length: 4, vsync: this);
      await Future.wait([
        _loadCompanyRating(),
        _checkFollowStatus(),
      ]);
      setState(() {
        _hasAccess = true;
        _isCheckingPermission = false;
      });
    } else {
      setState(() {
        _hasAccess = false;
        _isCheckingPermission = false;
      });
    }
  }

  Future<bool> _canViewProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        GeneralMethods.showErrorDialog(context, "Error: kindly login again");
        Navigator.pop(context);
      }
      return false;
    }

    _currentUserId = user.uid;
    _privacySettings =
    await PrivacySettingsService.getUserPrivacySettings(user.uid);

    if (!_privacySettings.profileVisibility && mounted) {
      GeneralMethods.showErrorDialog(
          context, "You are not allowed to view this profile");
      Navigator.pop(context);
      return false;
    }

    return true;
  }

  Future<void> _loadCompanyRating() async {
    final rating =
    await _companyCloud.getAverageCompanyRating(widget.company.id);
    if (mounted) setState(() => _rating = rating);
  }

  // ------------------------------------------------------------------
  // Follow logic  (mirrors StudentProfilePage exactly)
  // ------------------------------------------------------------------

  Future<void> _checkFollowStatus() async {
    final isFollowing = await _followService.isFollowing(
      _currentUserId,
      widget.company.id,
    );
    if (mounted) {
      setState(() {
        _isFollowing = isFollowing;
        _isCheckingFollow = false;
      });
    }
  }

  Future<void> _toggleFollow() async {
    if (_isTogglingFollow) return;
    setState(() => _isTogglingFollow = true);

    try {
      if (_isFollowing) {
        await _followService.unfollowUser(_currentUserId, widget.company.id);
        if (mounted) {
          setState(() => _isFollowing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Unfollowed ${widget.company.name}'),
              backgroundColor: Colors.grey,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        await _followService.followUser(_currentUserId, widget.company.id);
        if (mounted) {
          setState(() => _isFollowing = true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Following ${widget.company.name}'),
              backgroundColor: _gradientStart,
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
      if (mounted) setState(() => _isTogglingFollow = false);
    }
  }

  // ------------------------------------------------------------------
  // Build
  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_isCheckingPermission) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_hasAccess) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
      isDark ? const Color(0xFF0D1117) : const Color(0xFFF6F8FA),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _buildSliverAppBar(theme, isDark, innerBoxIsScrolled),
        ],
        body: Column(
          children: [
            _buildStatsAndActions(theme),
            _buildTabBar(theme),
            Expanded(child: _buildTabViews(theme)),
          ],
        ),
      ),
      // bottom action bar with follow + message buttons
      bottomNavigationBar: _buildBottomBar(theme),
    );
  }

  // ------------------------------------------------------------------
  // App bar
  // ------------------------------------------------------------------

  Widget _buildSliverAppBar(
      ThemeData theme, bool isDark, bool innerBoxIsScrolled) {
    return SliverAppBar(
      expandedHeight: 200,
      floating: false,
      pinned: true,
      stretch: true,
      backgroundColor: isDark ? const Color(0xFF161B22) : Colors.white,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.25),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.arrow_back, color: Colors.white, size: 18),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [_buildActionMenu(theme)],
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground],
        titlePadding: const EdgeInsets.only(left: 16, bottom: 12),
        title: innerBoxIsScrolled
            ? Text(
          widget.company.name,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        )
            : null,
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_gradientStart, _gradientEnd],
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 16),
                // company logo
                Hero(
                  tag: 'company-logo-${widget.company.id}',
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.18),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: widget.company.logoURL.isNotEmpty
                          ? Image.network(
                        widget.company.logoURL,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _companyInitialWidget(),
                      )
                          : _companyInitialWidget(),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.company.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  widget.company.industry,
                  style: const TextStyle(fontSize: 13, color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _companyInitialWidget() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_gradientStart, _gradientEnd],
        ),
      ),
      child: Center(
        child: Text(
          widget.company.name[0].toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Stats row + Add Review button
  // ------------------------------------------------------------------

  Widget _buildStatsAndActions(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // stars + rating
          ...List.generate(
            5,
                (i) => Icon(
              i < _rating.round()
                  ? Icons.star_rounded
                  : Icons.star_border_rounded,
              color: Colors.amber,
              size: 18,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _rating.toStringAsFixed(1),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: 4),
          StreamBuilder<List<CompanyReview>>(
            stream: _companyCloud.getCompanyReviews(widget.company.id),
            builder: (context, snap) {
              final count = snap.data?.length ?? 0;
              return Text(
                '($count)',
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              );
            },
          ),
          const Spacer(),
          // add review button
          TextButton.icon(
            onPressed: () => _showAddReviewDialog(context),
            icon: const Icon(Icons.rate_review_outlined, size: 16),
            label: const Text('Review'),
            style: TextButton.styleFrom(
              foregroundColor: _gradientStart,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: _gradientStart, width: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // Tab bar
  // ------------------------------------------------------------------

  Widget _buildTabBar(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surface,
      child: TabBar(
        controller: _tabController,
        labelColor: _gradientStart,
        unselectedLabelColor: theme.colorScheme.onSurface.withOpacity(0.45),
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(fontSize: 13),
        indicatorColor: _gradientStart,
        indicatorWeight: 2.5,
        indicatorSize: TabBarIndicatorSize.tab,
        tabs: const [
          Tab(text: 'About'),
          Tab(text: 'Posts'),
          Tab(text: 'Reviews'),
          Tab(text: 'Contact'),
        ],
      ),
    );
  }

  Widget _buildTabViews(ThemeData theme) {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildAboutTab(theme),
        _buildPostsTab(),
        _buildReviewsTab(theme),
        _buildContactTab(theme),
      ],
    );
  }

  // ------------------------------------------------------------------
  // Bottom bar — Follow + Message
  // ------------------------------------------------------------------

  Widget _buildBottomBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          // follow / unfollow
          if (!_isCheckingFollow && widget.company.id != GlobalIdService.firestoreId)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isTogglingFollow ? null : _toggleFollow,
                icon: _isTogglingFollow
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : Icon(
                  _isFollowing ? Icons.check : Icons.add,
                  size: 16,
                ),
                label: Text(
                  _isTogglingFollow
                      ? '...'
                      : (_isFollowing ? 'Following' : 'Follow'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(
                    color: _isFollowing
                        ? theme.colorScheme.outline
                        : _gradientStart,
                  ),
                  foregroundColor:
                  _isFollowing ? theme.colorScheme.onSurface : _gradientStart,
                ),
              ),
            ),
          if (!_isCheckingFollow) const SizedBox(width: 12),

          // message
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _contactCompany(context),
              icon: const Icon(Icons.chat_bubble_outline, size: 16),
              label: const Text(
                'Message',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _gradientStart,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
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

  // ------------------------------------------------------------------
  // Action menu (share / report)
  // ------------------------------------------------------------------

  Widget _buildActionMenu(ThemeData theme) {
    return PopupMenuButton<String>(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'share',
          child: Row(
            children: [
              Icon(Icons.share_outlined,
                  color: theme.colorScheme.onSurface, size: 18),
              const SizedBox(width: 10),
              const Text('Share'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'report',
          child: Row(
            children: [
              Icon(Icons.flag_outlined,
                  color: theme.colorScheme.onSurface, size: 18),
              const SizedBox(width: 10),
              const Text('Report'),
            ],
          ),
        ),
      ],
      onSelected: (value) {
        if (value == 'share') _shareCompany();
        if (value == 'report') _reportCompany(context);
      },
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.25),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.more_vert, color: Colors.white, size: 18),
      ),
    );
  }

  // ------------------------------------------------------------------
  // About tab
  // ------------------------------------------------------------------

  Widget _buildAboutTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // description
          _sectionCard(
            theme,
            child: Text(
              widget.company.description.isNotEmpty
                  ? widget.company.description
                  : '${widget.company.name} is a leading company in the '
                  '${widget.company.industry} industry, offering real-world '
                  'experience for interns and professionals.',
              style: TextStyle(
                fontSize: 14,
                height: 1.65,
                color: theme.colorScheme.onSurface.withOpacity(0.75),
              ),
            ),
          ),

          const SizedBox(height: 20),
          _sectionTitle(theme, 'Details'),
          const SizedBox(height: 12),

          if (_privacySettings.shouldShowCompanyInfo(
              _currentUserId, widget.company.id))
            _infoRow(theme, Icons.location_on_outlined, 'Location',
                '${widget.company.address}, ${widget.company.localGovernment}, ${widget.company.state}'),

          _infoRow(theme, Icons.business_outlined, 'Industry',
              widget.company.industry),

          _infoRow(
            theme,
            Icons.numbers_outlined,
            'Registration',
            widget.company.registrationNumber.isNotEmpty
                ? widget.company.registrationNumber
                : 'Not provided',
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // Posts tab  (mirrors StudentProfilePage._buildPostsTab)
  // ------------------------------------------------------------------

  Widget _buildPostsTab() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tweetProvider = Provider.of<TweetProvider>(context);

    // filter posts that belong to this company
    final companyPosts = tweetProvider.tweets
        .where((t) => t.userId == widget.company.id)
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    if (tweetProvider.isLoading && companyPosts.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (companyPosts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.article_outlined,
                size: 64,
                color: theme.colorScheme.onSurface.withOpacity(0.25),
              ),
              const SizedBox(height: 16),
              Text(
                'No Posts Yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Posts from ${widget.company.name} will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // the company acts as a UserConverter poster
    final companyAsUser = widget.user;

    return RefreshIndicator(
      onRefresh: () async => tweetProvider.refreshTweets(),
      color: _gradientStart,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: companyPosts.length,
        itemBuilder: (context, index) {
          final tweet = companyPosts[index];
          return ProfessionalTweetCard(
            tweet: tweet,
            tweetPoster: companyAsUser,
            currentUser: companyAsUser,
            isDark: isDark,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TweetDetailPage(
                    tweetId: tweet.id,
                    author: companyAsUser,
                    currentUser: companyAsUser,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------------
  // Reviews tab
  // ------------------------------------------------------------------

  Widget _buildReviewsTab(ThemeData theme) {
    return StreamBuilder<List<CompanyReview>>(
      stream: _companyCloud.getCompanyReviews(widget.company.id),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final reviews = snap.data ?? [];

        if (reviews.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.reviews_outlined,
                    size: 64,
                    color: theme.colorScheme.onSurface.withOpacity(0.25),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Reviews Yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Be the first to share your experience!',
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => _showAddReviewDialog(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _gradientStart,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Write a Review'),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: reviews.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) => _buildReviewCard(reviews[i], theme),
        );
      },
    );
  }

  // ------------------------------------------------------------------
  // Contact tab
  // ------------------------------------------------------------------

  Widget _buildContactTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(theme, 'Get in touch'),
          const SizedBox(height: 12),
          if (_privacySettings.shouldShowEmail(
              _currentUserId, widget.company.id))
            _contactTile(
              theme,
              icon: Icons.email_outlined,
              label: 'Email',
              value: widget.company.email,
              onTap: () => _launchEmail(widget.company.email),
            ),
          if (_privacySettings.shouldShowPhoneNumber(
              _currentUserId, widget.company.id))
            _contactTile(
              theme,
              icon: Icons.phone_outlined,
              label: 'Phone',
              value: widget.company.phoneNumber,
              onTap: () => _launchPhone(widget.company.phoneNumber),
            ),
          _contactTile(
            theme,
            icon: Icons.location_on_outlined,
            label: 'Address',
            value:
            '${widget.company.address}, ${widget.company.localGovernment}',
            onTap: () => _launchMaps(widget.company.address),
          ),

          const SizedBox(height: 20),
          _sectionTitle(theme, 'Business Hours'),
          const SizedBox(height: 12),
          _sectionCard(
            theme,
            child: Column(
              children: [
                _hoursRow(theme, 'Mon – Fri', '9:00 AM – 6:00 PM'),
                const SizedBox(height: 8),
                _hoursRow(theme, 'Saturday', '10:00 AM – 4:00 PM'),
                const SizedBox(height: 8),
                _hoursRow(theme, 'Sunday', 'Closed'),
              ],
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // Reusable widgets
  // ------------------------------------------------------------------

  Widget _sectionTitle(ThemeData theme, String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: theme.colorScheme.onSurface,
        letterSpacing: .1,
      ),
    );
  }

  Widget _sectionCard(ThemeData theme, {required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.08),
        ),
      ),
      child: child,
    );
  }

  Widget _infoRow(
      ThemeData theme, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _gradientStart.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: _gradientStart, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                    letterSpacing: .3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactTile(
      ThemeData theme, {
        required IconData icon,
        required String label,
        required String value,
        required VoidCallback onTap,
      }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: theme.colorScheme.outline.withOpacity(0.08),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _gradientStart.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: _gradientStart, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                      letterSpacing: .3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.onSurface.withOpacity(0.25),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _hoursRow(ThemeData theme, String day, String hours) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          day,
          style: TextStyle(
            fontSize: 14,
            color: theme.colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        Text(
          hours,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildReviewCard(CompanyReview review, ThemeData theme) {
    return FutureBuilder<Student?>(
      future: ITCFirebaseLogic(GlobalIdService.firestoreId)
          .getStudent(review.studentId),
      builder: (context, snap) {
        final student = snap.data;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.08),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: _gradientStart.withOpacity(0.1),
                    child: GeneralMethods.generateUserAvatar(
                      username: student?.fullName ?? 'Anonymous',
                      imageUrl: student?.imageUrl,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          student?.fullName ?? 'Anonymous',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          review.createdAt
                              .toLocal()
                              .toString()
                              .split(' ')[0],
                          style: TextStyle(
                            fontSize: 12,
                            color:
                            theme.colorScheme.onSurface.withOpacity(0.45),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: List.generate(
                      5,
                          (i) => Icon(
                        i < review.rating
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: Colors.amber,
                        size: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                review.comment,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: theme.colorScheme.onSurface.withOpacity(0.75),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------------
  // Actions
  // ------------------------------------------------------------------

  void _showAddReviewDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddReviewSheet(
        companyId: widget.company.id,
        studentName: _auth.currentUser?.displayName ?? 'Student',
        studentId: GlobalIdService.firestoreId ?? '',
        onReviewAdded: () {
          _loadCompanyRating();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Review submitted!'),
              backgroundColor: Colors.green,
            ),
          );
        },
      ),
    );
  }

  void _contactCompany(BuildContext context) {
    GeneralMethods.navigateTo(
      context,
      ChatDetailsPage(
        receiverId: widget.company.id,
        receiverName: widget.company.name,
        receiverAvatarUrl: widget.company.logoURL,
        receiverRole: widget.company.role,
      ),
    );
  }

  void _shareCompany() async {
    await Share.share(
      'Check out ${widget.company.name} on IT Connect!\n\n'
          'Industry: ${widget.company.industry}\n'
          'Location: ${widget.company.address}, ${widget.company.state}\n\n'
          'Download IT Connect to connect with companies like this!',
    );
  }

  void _reportCompany(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Report ${widget.company.name}'),
        content: const Text(
          'Our team will review your report within 24 hours.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Report submitted')),
              );
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  Future<void> _launchEmail(String email) async {
    final uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _launchPhone(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _launchMaps(String address) async {
    final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeFull(address)}');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }
}


// ======================================================================
// Add Review bottom sheet
// ======================================================================

class _AddReviewSheet extends StatefulWidget {
  final String companyId;
  final String studentName;
  final String studentId;
  final VoidCallback onReviewAdded;

  const _AddReviewSheet({
    Key? key,
    required this.companyId,
    required this.studentName,
    required this.studentId,
    required this.onReviewAdded,
  }) : super(key: key);

  @override
  _AddReviewSheetState createState() => _AddReviewSheetState();
}

class _AddReviewSheetState extends State<_AddReviewSheet> {
  final _formKey = GlobalKey<FormState>();
  int _rating = 5;
  String _comment = '';
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 20,
        left: 20,
        right: 20,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outline.withOpacity(0.25),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 20),

          Text(
            'Rate your experience',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'How was your time with ${widget.companyId}?',
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurface.withOpacity(0.55),
            ),
          ),
          const SizedBox(height: 20),

          // star selector
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              5,
                  (i) => GestureDetector(
                onTap: () => setState(() => _rating = i + 1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    i < _rating
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    size: 38,
                    color: Colors.amber,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          Form(
            key: _formKey,
            child: TextFormField(
              decoration: InputDecoration(
                labelText: 'Share your experience',
                alignLabelWithHint: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
              maxLines: 4,
              textInputAction: TextInputAction.done,
              validator: (v) =>
              v == null || v.trim().isEmpty ? 'Please write a review' : null,
              onChanged: (v) => _comment = v,
            ),
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3563E9),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Text('Submit'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final review = CompanyReview(
      id: FirebaseFirestore.instance.collection('tmp').doc().id,
      companyId: widget.companyId,
      studentId: widget.studentId,
      studentName: widget.studentName,
      comment: _comment,
      rating: _rating,
      createdAt: DateTime.now(),
    );

    await Company_Cloud(GlobalIdService.firestoreId).addCompanyReview(review);
    widget.onReviewAdded();
    if (mounted) Navigator.pop(context);
  }
}