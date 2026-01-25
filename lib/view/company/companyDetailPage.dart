import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:itc_institute_admin/view/home/chat/chartPage.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../../model/student.dart';
import '../../generalmethods/GeneralMethods.dart';
import '../../itc_logic/firebase/company_cloud.dart';
import '../../itc_logic/firebase/general_cloud.dart';
import '../../itc_logic/firebase/message/message_service.dart';
import '../../model/company.dart';
import '../../model/review.dart';
import '../../model/userProfile.dart';

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
  final Company_Cloud _companyCloud = Company_Cloud();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late TabController _tabController;
  double _rating = 0.0;

  final List<Map<String, dynamic>> _features = [
    {'icon': Icons.verified_user, 'label': 'Verified'},
    {'icon': Icons.featured_play_list, 'label': 'Featured'},
    {'icon': Icons.work, 'label': 'Hiring'},
    {'icon': Icons.location_city, 'label': 'Corporate'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadCompanyRating();
  }

  Future<void> _loadCompanyRating() async {
    final rating =
    await _companyCloud.getAverageCompanyRating(widget.company.id);
    setState(() {
      _rating = rating;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final gradientColors = [
      const Color(0xFF667eea),
      const Color(0xFF764ba2),
    ];

    return Scaffold(
      backgroundColor:
      isDark ? const Color(0xFF121212) : const Color(0xFFf8fafc),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 180,
              floating: false,
              pinned: true,
              snap: false,
              stretch: true,
              backgroundColor: isDark ? Colors.black : Colors.white,
              flexibleSpace: FlexibleSpaceBar(
                stretchModes: const [StretchMode.zoomBackground],
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: gradientColors,
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          // Calculate available space dynamically
                          final availableHeight = constraints.maxHeight;
                          final logoSize = availableHeight > 180 ? 80.0 : 60.0;
                          final titleFontSize =
                          availableHeight > 180 ? 22.0 : 18.0;
                          final subtitleFontSize =
                          availableHeight > 180 ? 14.0 : 12.0;

                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Dynamic spacing based on available height
                              SizedBox(height: availableHeight * 0.1),
                              // Company Logo
                              Hero(
                                tag: 'company-logo-${widget.company.id}',
                                child: Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(60),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 15,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius:
                                    BorderRadius.circular(logoSize * 0.25),
                                    child: widget.company.logoURL.isNotEmpty
                                        ? Image.network(
                                      widget.company.logoURL,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        return Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: gradientColors,
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              widget.company.name[0]
                                                  .toUpperCase(),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 32,
                                                fontWeight:
                                                FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    )
                                        : Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: gradientColors,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          widget.company.name[0]
                                              .toUpperCase(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 32,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Company Name
                              Text(
                                widget.company.name,
                                style: TextStyle(
                                  fontSize: titleFontSize,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  shadows: const [
                                    Shadow(
                                      blurRadius: 10,
                                      color: Colors.black26,
                                    ),
                                  ],
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              // Industry
                              Text(
                                widget.company.industry,
                                style: TextStyle(
                                  fontSize: subtitleFontSize,
                                  color: Colors.white70,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
              leading: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_back, color: Colors.white),
                ),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                _buildActionMenu(context),
              ],
            ),
          ];
        },
        body: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.background,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30),
            ),
          ),
          child: Column(
            children: [
              // Rating and Action Buttons
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Rating Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ...List.generate(
                          5,
                              (index) => Icon(
                            index < _rating.round()
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            color: Colors.amber,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _rating.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(width: 4),
                        StreamBuilder<List<CompanyReview>>(
                          stream: _companyCloud
                              .getCompanyReviews(widget.company.id),
                          builder: (context, snapshot) {
                            final reviewCount = snapshot.data?.length ?? 0;
                            return Text(
                              '($reviewCount reviews)',
                              style: TextStyle(
                                fontSize: 14,
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.6),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: gradientColors[0],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                            icon: const Icon(Icons.rate_review, size: 18),
                            label: const Text('Add Review'),
                            onPressed: () => _showAddReviewDialog(context),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.surface,
                              foregroundColor: gradientColors[0],
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: gradientColors[0].withOpacity(0.2),
                                ),
                              ),
                            ),
                            icon: const Icon(Icons.message_rounded, size: 18),
                            label: const Text('Message'),
                            onPressed: () => _contactCompany(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Features Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _features.map((feature) {
                          return Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: gradientColors[0].withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: gradientColors[0].withOpacity(0.2),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  feature['icon'] as IconData,
                                  color: gradientColors[0],
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  feature['label'],
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              // Tab Bar
              Container(
                color: theme.colorScheme.surface,
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    gradient: LinearGradient(
                      colors: gradientColors,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor:
                  theme.colorScheme.onSurface.withOpacity(0.5),
                  labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                  unselectedLabelStyle:
                  const TextStyle(fontWeight: FontWeight.normal),
                  indicatorSize: TabBarIndicatorSize.tab,
                  tabs: const [
                    Tab(text: 'About'),
                    Tab(text: 'Reviews'),
                    Tab(text: 'Contact'),
                  ],
                ),
              ),
              // Tab Content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // About Tab
                    _buildAboutTab(theme),
                    // Reviews Tab
                    _buildReviewsTab(theme),
                    // Contact Tab
                    _buildContactTab(theme),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionMenu(BuildContext context) {
    return PopupMenuButton<String>(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'share',
          child: Row(
            children: [
              Icon(Icons.share, color: Theme.of(context).colorScheme.onSurface),
              const SizedBox(width: 12),
              const Text('Share Company'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'report',
          child: Row(
            children: [
              Icon(Icons.flag, color: Theme.of(context).colorScheme.onSurface),
              const SizedBox(width: 12),
              const Text('Report'),
            ],
          ),
        ),
      ],
      onSelected: (value) {
        if (value == 'share') {
          _shareCompany();
        } else if (value == 'report') {
          _reportCompany(context);
        }
      },
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.more_vert, color: Colors.white),
      ),
    );
  }

  Widget _buildAboutTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Company Overview',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.outline.withOpacity(0.1),
              ),
            ),
            child: Text(
              widget.company.description.isNotEmpty
                  ? widget.company.description
                  : '${widget.company.name} is a leading company in the ${widget.company.industry} industry. They provide excellent opportunities for interns and professionals to gain real-world experience and grow their careers.',
              style: TextStyle(
                fontSize: 15,
                height: 1.6,
                color: theme.colorScheme.onSurface.withOpacity(0.8),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Company Details',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          _buildInfoCard(
            theme,
            Icons.location_on_rounded,
            'Location',
            '${widget.company.address}, ${widget.company.localGovernment}, ${widget.company.state}',
          ),
          const SizedBox(height: 12),
          _buildInfoCard(
            theme,
            Icons.business_rounded,
            'Industry',
            widget.company.industry,
          ),
          const SizedBox(height: 12),
          _buildInfoCard(
            theme,
            Icons.description_rounded,
            'Registration',
            widget.company.registrationNumber.isNotEmpty
                ? widget.company.registrationNumber
                : 'Not Provided',
          ),
          if (widget.company.description.contains('http'))
            const SizedBox(height: 12),
          if (widget.company.description.contains('http'))
            _buildInfoCard(
              theme,
              Icons.public_rounded,
              'Website',
              _extractUrl(widget.company.description) ?? 'Visit Website',
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildReviewsTab(ThemeData theme) {
    return StreamBuilder<List<CompanyReview>>(
      stream: _companyCloud.getCompanyReviews(widget.company.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.reviews_rounded,
                  size: 64,
                  color: theme.colorScheme.onSurface.withOpacity(0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  'No Reviews Yet',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Be the first to share your experience!',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.4),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => _showAddReviewDialog(context),
                  child: const Text('Add Review'),
                ),
              ],
            ),
          );
        }

        final reviews = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: reviews.length,
          itemBuilder: (context, index) {
            return _buildReviewCard(reviews[index], theme);
          },
        );
      },
    );
  }

  Widget _buildContactTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildContactOption(
            theme,
            Icons.email_rounded,
            'Email',
            widget.company.email,
                () => _launchEmail(widget.company.email),
          ),
          const SizedBox(height: 16),
          _buildContactOption(
            theme,
            Icons.phone_rounded,
            'Phone',
            widget.company.phoneNumber,
                () => _launchPhone(widget.company.phoneNumber),
          ),
          const SizedBox(height: 16),
          _buildContactOption(
            theme,
            Icons.location_on_rounded,
            'Address',
            '${widget.company.address}, ${widget.company.localGovernment}',
                () => _launchMaps(widget.company.address),
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.outline.withOpacity(0.1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Business Hours',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Monday - Friday: 9:00 AM - 6:00 PM\nSaturday: 10:00 AM - 4:00 PM\nSunday: Closed',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                    fontSize: 14,
                    height: 1.8,
                  ),
                ),
                const SizedBox(height: 16),
                Divider(
                  color: theme.colorScheme.outline.withOpacity(0.1),
                  height: 1,
                ),
                const SizedBox(height: 16),
                Text(
                  'Additional Info',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'For general inquiries, please use the email above. '
                      'For urgent matters, call during business hours.',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                    fontSize: 14,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
      ThemeData theme, IconData icon, String title, String content) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF667eea).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFF667eea), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
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

  Widget _buildReviewCard(CompanyReview review, ThemeData theme) {
    return FutureBuilder<Student?>(
      future: ITCFirebaseLogic().getStudent(review.studentId),
      builder: (context, snapshot) {
        final student = snapshot.data;
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFF667eea).withOpacity(0.1),
                    child: GeneralMethods.generateUserAvatar(
                        username: student?.fullName ?? 'Anonymous',
                        imageUrl: student?.imageUrl),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          student?.fullName ?? 'Anonymous',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${review.createdAt.toLocal().toString().split(' ')[0]}',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...List.generate(
                    5,
                        (i) => Icon(
                      i < review.rating
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: Colors.amber,
                      size: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                review.comment,
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.8),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContactOption(
      ThemeData theme,
      IconData icon,
      String title,
      String value,
      VoidCallback onTap,
      ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.outline.withOpacity(0.1),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF667eea).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF667eea)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.onSurface.withOpacity(0.3),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddReviewDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return _AddReviewDialog(
          companyId: widget.company.id,
          studentName: _auth.currentUser?.displayName ?? 'Student',
          studentId: _auth.currentUser?.uid ?? '',
          onReviewAdded: () {
            _loadCompanyRating();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Review submitted successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          },
        );
      },
    );
  }

  void _contactCompany(BuildContext context) {
    GeneralMethods.navigateTo(
         context,
         ChatDetailsPage(
           receiverId: widget.company.id, receiverName: widget.company.name, receiverAvatarUrl: widget.company.logoURL,
        ));
  }

  void _shareCompany() async {
    await Share.share(
      'Check out ${widget.company.name} on IT Connect!\n\n'
          'Industry: ${widget.company.industry}\n'
          'Location: ${widget.company.address}, ${widget.company.state}\n\n'
          'Download IT Connect app to connect with companies like this!',
    );
  }

  void _reportCompany(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Report ${widget.company.name}'),
        content: const Text(
          'Please describe the issue with this company profile. '
              'Our team will review your report within 24 hours.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Report submitted successfully')),
              );
              Navigator.pop(context);
            },
            child: const Text('Submit Report'),
          ),
        ],
      ),
    );
  }

  Future<void> _launchEmail(String email) async {
    final uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchPhone(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchMaps(String address) async {
    final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeFull(address)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  String? _extractUrl(String text) {
    final urlRegex = RegExp(r'(https?:\/\/[^\s]+)');
    final match = urlRegex.firstMatch(text);
    return match?.group(0);
  }
}

class _AddReviewDialog extends StatefulWidget {
  final String companyId;
  final String studentName;
  final String studentId;
  final VoidCallback onReviewAdded;

  const _AddReviewDialog({
    Key? key,
    required this.companyId,
    required this.studentName,
    required this.studentId,
    required this.onReviewAdded,
  }) : super(key: key);

  @override
  _AddReviewDialogState createState() => _AddReviewDialogState();
}

class _AddReviewDialogState extends State<_AddReviewDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  int _rating = 5;
  String _comment = '';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Rate Your Experience',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                5,
                    (i) => GestureDetector(
                  onTap: () => setState(() => _rating = i + 1),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      i < _rating
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      size: 40,
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
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                ),
                maxLines: 4,
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'Please write a review'
                    : null,
                onChanged: (val) => _comment = val,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF667eea),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      if (_formKey.currentState!.validate()) {
                        final review = CompanyReview(
                          id: FirebaseFirestore.instance
                              .collection('tmp')
                              .doc()
                              .id,
                          companyId: widget.companyId,
                          studentId: widget.studentId,
                          studentName: widget.studentName,
                          comment: _comment,
                          rating: _rating,
                          createdAt: DateTime.now(),
                        );
                        await Company_Cloud().addCompanyReview(review);
                        widget.onReviewAdded();
                        Navigator.pop(context);
                      }
                    },
                    child: const Text('Submit Review'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
