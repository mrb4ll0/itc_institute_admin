import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../generalmethods/GeneralMethods.dart';
import '../../../itc_logic/firebase/message/message_service.dart';
import '../../../itc_logic/service/userService.dart';
import '../../../model/student.dart';
import '../chat/chartPage.dart';

class StudentProfilePage extends StatefulWidget {
  final Student student;
  final bool? showChatActions;
  final String? currentUserId;

  const StudentProfilePage({
    Key? key,
    required this.student,
    this.showChatActions = true,
    this.currentUserId,
  }) : super(key: key);

  @override
  State<StudentProfilePage> createState() => _StudentProfilePageState();
}

class _StudentProfilePageState extends State<StudentProfilePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ChatService _chatService = ChatService();
  final UserService _userService = UserService();
  String? _currentUserId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _getCurrentUser();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    setState(() {
      _currentUserId = user?.uid ?? widget.currentUserId;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 300,
              floating: false,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: _buildProfileHeader(context),
                titlePadding: EdgeInsets.only(bottom: 16, left: 16),
                title: innerBoxIsScrolled
                    ? Text(
                        widget.student.fullName,
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              actions: [
                if (widget.showChatActions == true && _currentUserId != null)
                  _buildChatActions(context),
              ],
            ),
            SliverPersistentHeader(
              delegate: _SliverTabBarDelegate(
                TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(icon: Icon(Icons.info), text: 'Overview'),
                    Tab(icon: Icon(Icons.school), text: 'Education'),
                    Tab(icon: Icon(Icons.work), text: 'Portfolio'),
                    Tab(icon: Icon(Icons.contact_page), text: 'Documents'),
                  ],
                  indicatorColor: colorScheme.primary,
                  labelColor: colorScheme.primary,
                  unselectedLabelColor: colorScheme.onSurfaceVariant,
                ),
              ),
              pinned: true,
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildOverviewTab(context),
            _buildEducationTab(context),
            _buildPortfolioTab(context),
            _buildDocumentsTab(context),
          ],
        ),
      ),
      bottomNavigationBar:
          widget.showChatActions == true &&
              _currentUserId != null &&
              _currentUserId != widget.student.uid
          ? _buildChatButton(context)
          : null,
    );
  }

  Widget _buildProfileHeader(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colorScheme.primary.withOpacity(0.8),
            colorScheme.primary.withOpacity(0.4),
            colorScheme.surfaceContainerLowest,
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 70,
            left: 0,
            right: 0,
            child: Column(
              children: [
                // Profile Image
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: colorScheme.surface, width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: widget.student.imageUrl.isNotEmpty
                        ? Image.network(
                            widget.student.imageUrl,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(child: CircularProgressIndicator());
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: colorScheme.surfaceContainer,
                                child: Icon(
                                  Icons.person,
                                  size: 60,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              );
                            },
                          )
                        : Container(
                            color: colorScheme.surfaceContainer,
                            child: Icon(
                              Icons.person,
                              size: 60,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                  ),
                ),
                SizedBox(height: 16),
                // Name and Title
                Column(
                  children: [
                    Text(
                      widget.student.fullName,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 4),
                    if (widget.student.courseOfStudy.isNotEmpty)
                      Text(
                        widget.student.courseOfStudy,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    SizedBox(height: 8),
                    // Institution Badge
                    if (widget.student.institution.isNotEmpty)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.surface.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: colorScheme.outline.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.school,
                              size: 16,
                              color: colorScheme.primary,
                            ),
                            SizedBox(width: 6),
                            Text(
                              widget.student.institution,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.w500,
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
    );
  }

  Widget _buildChatActions(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        _handleChatAction(value);
      },
      itemBuilder: (BuildContext context) {
        return [
          PopupMenuItem<String>(
            value: 'start_chat',
            child: Row(
              children: [
                Icon(Icons.chat, size: 20),
                SizedBox(width: 8),
                Text('Start Chat'),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'video_call',
            child: Row(
              children: [
                Icon(Icons.video_call, size: 20),
                SizedBox(width: 8),
                Text('Video Call'),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'audio_call',
            child: Row(
              children: [
                Icon(Icons.call, size: 20),
                SizedBox(width: 8),
                Text('Audio Call'),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'view_messages',
            child: Row(
              children: [
                Icon(Icons.message, size: 20),
                SizedBox(width: 8),
                Text('View Messages'),
              ],
            ),
          ),
        ];
      },
    );
  }

  void _handleChatAction(String action) async {
    switch (action) {
      case 'start_chat':
        _startChat();
        break;
      case 'video_call':
        _initiateVideoCall();
        break;
      case 'audio_call':
        _initiateAudioCall();
        break;
      case 'view_messages':
        _viewMessages();
        break;
    }
  }

  Future<void> _startChat() async {
    if (_currentUserId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Please login to start a chat')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Check if chat already exists
      final chatId = _chatService.getChatId(
        _currentUserId!,
        widget.student.uid,
      );
      final chatDoc = await FirebaseFirestore.instance
          .collection('chat_rooms')
          .doc(chatId)
          .get();

      // Navigate to chat page
      GeneralMethods.navigateTo(
        context,
        ChatDetailsPage(
          receiverId: widget.student.uid,
          receiverName: widget.student.fullName,
          receiverAvatarUrl: widget.student.imageUrl,
          receiverRole: 'student',
          receiverData: widget.student,
        ),
      );
    } catch (e) {
      print('Error starting chat: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start chat: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _initiateVideoCall() async {
    // Implement video call logic
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Video call feature coming soon')));
  }

  Future<void> _initiateAudioCall() async {
    // Implement audio call logic
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Audio call feature coming soon')));
  }

  void _viewMessages() {
    // Navigate to chat history
    _startChat();
  }

  Widget _buildChatButton(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(color: colorScheme.outline.withOpacity(0.1)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _startChat,
              icon: Icon(Icons.chat),
              label: Text(_isLoading ? 'Loading...' : 'Start Chat'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          SizedBox(width: 12),
          IconButton(
            onPressed: () {
              _showMoreOptions(context);
            },
            icon: Icon(Icons.more_vert),
            style: IconButton.styleFrom(
              backgroundColor: colorScheme.surfaceContainer,
              padding: EdgeInsets.all(12),
            ),
          ),
        ],
      ),
    );
  }

  void _showMoreOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.call),
                title: Text('Call'),
                onTap: () {
                  Navigator.pop(context);
                  _makePhoneCall();
                },
              ),
              ListTile(
                leading: Icon(Icons.email),
                title: Text('Send Email'),
                onTap: () {
                  Navigator.pop(context);
                  _sendEmail();
                },
              ),
              ListTile(
                leading: Icon(Icons.share),
                title: Text('Share Profile'),
                onTap: () {
                  Navigator.pop(context);
                  _shareProfile();
                },
              ),
              ListTile(
                leading: Icon(Icons.report),
                title: Text('Report'),
                onTap: () {
                  Navigator.pop(context);
                  _reportProfile();
                },
              ),
              ListTile(
                leading: Icon(Icons.block),
                title: Text('Block'),
                onTap: () {
                  Navigator.pop(context);
                  _blockUser();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _makePhoneCall() async {
    if (widget.student.phoneNumber.isNotEmpty) {
      final url = 'tel:${widget.student.phoneNumber}';
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not launch phone app')));
      }
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No phone number available')));
    }
  }

  Future<void> _sendEmail() async {
    if (widget.student.email.isNotEmpty) {
      final url = 'mailto:${widget.student.email}';
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not launch email app')));
      }
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No email available')));
    }
  }

  Future<void> _shareProfile() async {
    // Implement share functionality
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Share feature coming soon')));
  }

  void _reportProfile() {
    // Implement report functionality
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Report Profile'),
        content: Text('Are you sure you want to report this profile?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('Profile reported')));
            },
            child: Text('Report', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _blockUser() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Block User'),
        content: Text(
          'Are you sure you want to block ${widget.student.fullName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('User blocked')));
            },
            child: Text('Block', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bio Section
          if (widget.student.bio.isNotEmpty)
            _buildSection(
              context,
              title: 'About',
              icon: Icons.info,
              child: Text(
                widget.student.bio,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),

          // Contact Information
          _buildSection(
            context,
            title: 'Contact Information',
            icon: Icons.contact_page,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.student.email.isNotEmpty)
                  _buildInfoItem(
                    context,
                    icon: Icons.email,
                    label: 'Email',
                    value: widget.student.email,
                  ),
                if (widget.student.phoneNumber.isNotEmpty)
                  _buildInfoItem(
                    context,
                    icon: Icons.phone,
                    label: 'Phone',
                    value: widget.student.phoneNumber,
                  ),
                if (widget.student.currentAddress?.isNotEmpty ?? false)
                  _buildInfoItem(
                    context,
                    icon: Icons.location_on,
                    label: 'Address',
                    value: widget.student.currentAddress!,
                  ),
              ],
            ),
          ),

          // Social Links
          if (_hasSocialLinks())
            _buildSection(
              context,
              title: 'Social Links',
              icon: Icons.link,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _buildSocialLinks(context),
              ),
            ),

          // Skills
          if (widget.student.skills.isNotEmpty)
            _buildSection(
              context,
              title: 'Skills',
              icon: Icons.star,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.student.skills.map((skill) {
                  return Chip(
                    label: Text(skill),
                    backgroundColor: colorScheme.surfaceContainer,
                  );
                }).toList(),
              ),
            ),

          // Academic Status
          _buildSection(
            context,
            title: 'Academic Status',
            icon: Icons.school,
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: widget.student.isCurrentlyEnrolled
                        ? Colors.green.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: widget.student.isCurrentlyEnrolled
                          ? Colors.green
                          : Colors.orange,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    widget.student.academicStatus.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: widget.student.isCurrentlyEnrolled
                          ? Colors.green
                          : Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                if (widget.student.cgpa > 0)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Text('GPA: ', style: theme.textTheme.labelSmall),
                        Text(
                          widget.student.cgpa.toStringAsFixed(2),
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Industrial Training Eligibility
          if (widget.student.isEligibleForIndustrialTraining)
            _buildSection(
              context,
              title: 'Industrial Training',
              icon: Icons.work,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Eligible for IT',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  if (widget.student.graduationProgress > 0)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Graduation Progress',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: widget.student.graduationProgress / 100,
                          backgroundColor: colorScheme.surfaceContainer,
                          color: colorScheme.primary,
                          minHeight: 8,
                        ),
                        SizedBox(height: 4),
                        Text(
                          '${widget.student.graduationProgress.toStringAsFixed(1)}% complete',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
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

  Widget _buildEducationTab(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Institution Info
          _buildSection(
            context,
            title: 'Institution',
            icon: Icons.school,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.student.institution.isNotEmpty)
                  Text(
                    widget.student.institution,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                if (widget.student.department.isNotEmpty) ...[
                  SizedBox(height: 4),
                  Text(
                    widget.student.department,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Program Details
          _buildSection(
            context,
            title: 'Program Details',
            icon: Icons.book,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoItem(
                  context,
                  icon: Icons.class_,
                  label: 'Course of Study',
                  value: widget.student.courseOfStudy,
                ),
                _buildInfoItem(
                  context,
                  icon: Icons.format_list_numbered,
                  label: 'Level',
                  value: widget.student.level.isNotEmpty
                      ? '${widget.student.level} Level'
                      : 'Not specified',
                ),
                if (widget.student.matricNumber.isNotEmpty)
                  _buildInfoItem(
                    context,
                    icon: Icons.badge,
                    label: 'Matric Number',
                    value: widget.student.matricNumber,
                  ),
                if (widget.student.registrationNumber.isNotEmpty)
                  _buildInfoItem(
                    context,
                    icon: Icons.assignment_ind,
                    label: 'Registration Number',
                    value: widget.student.registrationNumber,
                  ),
              ],
            ),
          ),

          // Academic Timeline
          if (widget.student.admissionDate != null ||
              widget.student.expectedGraduationDate != null)
            _buildSection(
              context,
              title: 'Academic Timeline',
              icon: Icons.timeline,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.student.admissionDate != null)
                    _buildInfoItem(
                      context,
                      icon: Icons.calendar_today,
                      label: 'Admission Date',
                      value: DateFormat(
                        'MMM dd, yyyy',
                      ).format(widget.student.admissionDate!),
                    ),
                  if (widget.student.expectedGraduationDate != null)
                    _buildInfoItem(
                      context,
                      icon: Icons.flag,
                      label: 'Expected Graduation',
                      value: DateFormat(
                        'MMM dd, yyyy',
                      ).format(widget.student.expectedGraduationDate!),
                    ),
                  if (widget.student.yearsOfStudy != null)
                    _buildInfoItem(
                      context,
                      icon: Icons.timer,
                      label: 'Years of Study',
                      value: '${widget.student.yearsOfStudy} year(s)',
                    ),
                  if (widget.student.yearsRemaining != null)
                    _buildInfoItem(
                      context,
                      icon: Icons.timer_off,
                      label: 'Years Remaining',
                      value: '${widget.student.yearsRemaining} year(s)',
                    ),
                ],
              ),
            ),

          // Current Courses
          if (widget.student.courses.isNotEmpty)
            _buildSection(
              context,
              title: 'Current Courses',
              icon: Icons.library_books,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.student.courses.map((course) {
                      return Chip(
                        label: Text(course),
                        backgroundColor: colorScheme.surfaceContainer,
                        labelStyle: theme.textTheme.bodySmall,
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

          // GPA Classification
          if (widget.student.cgpa > 0)
            _buildSection(
              context,
              title: 'Academic Performance',
              icon: Icons.assessment,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CGPA: ${widget.student.cgpa.toStringAsFixed(2)}',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              widget.student.gpaClassification,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      RatingBarIndicator(
                        rating: widget.student.cgpa / 5.0 * 5,
                        itemBuilder: (context, index) =>
                            Icon(Icons.star, color: Colors.amber),
                        itemCount: 5,
                        itemSize: 24,
                        direction: Axis.horizontal,
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

  Widget _buildPortfolioTab(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Portfolio Description
          if (widget.student.portfolioDescription.isNotEmpty)
            _buildSection(
              context,
              title: 'Portfolio',
              icon: Icons.work_outline,
              child: Text(
                widget.student.portfolioDescription,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),

          // Certifications
          if (widget.student.certifications.isNotEmpty)
            _buildSection(
              context,
              title: 'Certifications',
              icon: Icons.verified,
              child: Column(
                children: widget.student.certifications.map((cert) {
                  return ListTile(
                    leading: Icon(Icons.verified, color: Colors.green),
                    title: Text(cert),
                    minLeadingWidth: 0,
                  );
                }).toList(),
              ),
            ),

          // Past Internships
          if (widget.student.pastInternships.isNotEmpty)
            _buildSection(
              context,
              title: 'Past Internships',
              icon: Icons.business_center,
              child: Column(
                children: widget.student.pastInternships.map((internship) {
                  return Card(
                    margin: EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      contentPadding: EdgeInsets.all(16),
                      leading: Icon(Icons.work, color: colorScheme.primary),
                      title: Text(
                        internship['company'] ?? 'Company',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (internship['position'] != null)
                            Text(internship['position']),
                          if (internship['duration'] != null)
                            Text(internship['duration']),
                          if (internship['description'] != null)
                            SizedBox(height: 8),
                          if (internship['description'] != null)
                            Text(
                              internship['description'],
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

          // Resume Download
          if (widget.student.resumeUrl.isNotEmpty)
            _buildSection(
              context,
              title: 'Resume',
              icon: Icons.description,
              child: ElevatedButton.icon(
                onPressed: () => _openUrl(widget.student.resumeUrl),
                icon: Icon(Icons.download),
                label: Text('Download Resume'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ),

          // Portfolio Website
          if (widget.student.portfolioUrl?.isNotEmpty ?? false)
            _buildSection(
              context,
              title: 'Online Portfolio',
              icon: Icons.public,
              child: ElevatedButton.icon(
                onPressed: () => _openUrl(widget.student.portfolioUrl!),
                icon: Icon(Icons.open_in_browser),
                label: Text('Visit Portfolio Website'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDocumentsTab(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Transcript
          if (widget.student.transcriptUrl.isNotEmpty)
            _buildDocumentCard(
              context,
              title: 'Academic Transcript',
              icon: Icons.description,
              url: widget.student.transcriptUrl,
            ),

          // Student ID Card
          if (widget.student.studentIdCardUrl.isNotEmpty)
            _buildDocumentCard(
              context,
              title: 'Student ID Card',
              icon: Icons.badge,
              url: widget.student.studentIdCardUrl,
            ),

          // ID Cards
          if (widget.student.idCards.isNotEmpty)
            _buildSection(
              context,
              title: 'ID Cards (${widget.student.idCards.length})',
              icon: Icons.credit_card,
              child: Column(
                children: widget.student.idCards.map((url) {
                  return _buildDocumentItem(
                    context,
                    title: 'ID Card',
                    url: url,
                  );
                }).toList(),
              ),
            ),

          // IT Letters
          if (widget.student.itLetters.isNotEmpty)
            _buildSection(
              context,
              title: 'IT Letters (${widget.student.itLetters.length})',
              icon: Icons.mail,
              child: Column(
                children: widget.student.itLetters.map((url) {
                  return _buildDocumentItem(
                    context,
                    title: 'IT Letter',
                    url: url,
                  );
                }).toList(),
              ),
            ),

          // Academic Certificates
          if (widget.student.academicCertificates.isNotEmpty)
            _buildSection(
              context,
              title:
                  'Academic Certificates (${widget.student.academicCertificates.length})',
              icon: Icons.verified,
              child: Column(
                children: widget.student.academicCertificates.map((url) {
                  return _buildDocumentItem(
                    context,
                    title: 'Certificate',
                    url: url,
                  );
                }).toList(),
              ),
            ),

          // Recommendation Letters
          if (widget.student.recommendationLetters.isNotEmpty)
            _buildSection(
              context,
              title:
                  'Recommendation Letters (${widget.student.recommendationLetters.length})',
              icon: Icons.recommend,
              child: Column(
                children: widget.student.recommendationLetters.map((url) {
                  return _buildDocumentItem(
                    context,
                    title: 'Recommendation Letter',
                    url: url,
                  );
                }).toList(),
              ),
            ),

          // Testimonials
          if (widget.student.testimonials.isNotEmpty)
            _buildSection(
              context,
              title: 'Testimonials (${widget.student.testimonials.length})',
              icon: Icons.rate_review,
              child: Column(
                children: widget.student.testimonials.map((url) {
                  return _buildDocumentItem(
                    context,
                    title: 'Testimonial',
                    url: url,
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: colorScheme.primary, size: 20),
              SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Padding(padding: EdgeInsets.only(left: 28), child: child),
        ],
      ),
    );
  }

  Widget _buildInfoItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurface,
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

  bool _hasSocialLinks() {
    return widget.student.linkedinUrl?.isNotEmpty == true ||
        widget.student.githubUrl?.isNotEmpty == true ||
        widget.student.twitterUrl?.isNotEmpty == true;
  }

  List<Widget> _buildSocialLinks(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final links = <Widget>[];

    if (widget.student.linkedinUrl?.isNotEmpty ?? false) {
      links.add(
        ElevatedButton.icon(
          onPressed: () => _openUrl(widget.student.linkedinUrl!),
          icon: Icon(Icons.linked_camera, size: 16),
          label: Text('LinkedIn'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF0077B5),
            foregroundColor: Colors.white,
          ),
        ),
      );
    }

    if (widget.student.githubUrl?.isNotEmpty ?? false) {
      links.add(
        ElevatedButton.icon(
          onPressed: () => _openUrl(widget.student.githubUrl!),
          icon: Icon(Icons.code, size: 16),
          label: Text('GitHub'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
        ),
      );
    }

    if (widget.student.twitterUrl?.isNotEmpty ?? false) {
      links.add(
        ElevatedButton.icon(
          onPressed: () => _openUrl(widget.student.twitterUrl!),
          icon: Icon(Icons.social_distance, size: 16),
          label: Text('Twitter'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF1DA1F2),
            foregroundColor: Colors.white,
          ),
        ),
      );
    }

    return links;
  }

  Widget _buildDocumentCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required String url,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: colorScheme.primary),
        title: Text(title, style: theme.textTheme.titleMedium),
        trailing: IconButton(
          icon: Icon(Icons.download),
          onPressed: () => _openUrl(url),
        ),
      ),
    );
  }

  Widget _buildDocumentItem(
    BuildContext context, {
    required String title,
    required String url,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 0),
      leading: Icon(
        Icons.insert_drive_file,
        color: colorScheme.onSurfaceVariant,
      ),
      title: Text(title, style: theme.textTheme.bodyMedium),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.visibility, size: 20),
            onPressed: () => _openUrl(url),
          ),
          IconButton(
            icon: Icon(Icons.download, size: 20),
            onPressed: () => _openUrl(url),
          ),
        ],
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not open URL')));
    }
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _SliverTabBarDelegate(this.tabBar);

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: tabBar,
    );
  }

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return false;
  }
}
