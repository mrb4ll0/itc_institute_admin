import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:itc_institute_admin/itc_logic/firebase/general_cloud.dart';
import 'package:itc_institute_admin/view/home/chat/chartPage.dart';

import '../../generalmethods/GeneralMethods.dart';
import '../../itc_logic/firebase/company_cloud.dart'; // Import company cloud
import '../../itc_logic/firebase/message/message_service.dart';
import '../../model/company.dart';
import '../../model/message.dart';
import '../../model/student.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  final TextEditingController _searchController = TextEditingController();
  int _selectedFilter = 0; // 0: All, 1: Unread, 2: Accepted, 3: Archived

  // Variables for real data
  List<UserChat> _filteredChats = [];
  List<UserChat> _allChats = [];
  bool _isLoading = true;
  String? _currentUserId;
  String? _currentUserRole; // 'student' or 'company'

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      _currentUserId = user.uid;

      // Determine if current user is a student or company
      final userService = UserService();
      final userData = await userService.getCurrentUserData();
      _currentUserRole = userData?['role'] ?? 'student';

      if (_currentUserRole == 'company') {
        // Company user: Load students who applied to this company
        await _loadStudentsForCompany();
      } else {
        // Student user: Load all chats normally
        await _loadAllChats();
      }
    } catch (e) {
      print('Error loading user: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadStudentsForCompany() async {
    try {
      if (_currentUserId == null) return;

      final companyCloud = Company_Cloud(); // Create instance

      // Get students who applied to this company
      final List<Student> students = await companyCloud
          .getStudentsThatAppliedForCompany(_currentUserId!);

      // Convert students to UserChat format
      final List<UserChat> chats = [];

      for (final student in students) {
        final chat = UserChat(
          id: student.uid,
          name: student.fullName,
          lastMessage: 'Tap to start conversation',
          timestamp: '',
          isUnread: false,
          avatarUrl: student.imageUrl,
          unreadCount: 0,
          lastMessageTimestamp: Timestamp.now(),
          userRole: 'student',
          userData: student,
        );

        chats.add(chat);
      }

      // Sort by name
      chats.sort((a, b) => a.name.compareTo(b.name));

      setState(() {
        _allChats = chats;
        _filteredChats = _applyFilter(chats, _selectedFilter);
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading students for company: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAllChats() async {
    try {
      final chatService = ChatService();

      // Listen to messages stream
      chatService.getAllMessagesForCurrentUser().listen((messages) {
        if (mounted) {
          _processMessages(messages);
        }
      });
    } catch (e) {
      print('Error loading chats: $e');
      setState(() => _isLoading = false);
    }
  }

  void _processMessages(List<Message> messages) async {
    final userService = UserService();
    final List<UserChat> chats = [];

    // Group messages by chat partner
    final Map<String, List<Message>> messagesByPartner = {};

    for (final message in messages) {
      final partnerId = message.senderId == _currentUserId
          ? message.receiverId
          : message.senderId;

      if (!messagesByPartner.containsKey(partnerId)) {
        messagesByPartner[partnerId] = [];
      }
      messagesByPartner[partnerId]!.add(message);
    }

    // Convert to UserChat objects
    for (final entry in messagesByPartner.entries) {
      final partnerId = entry.key;
      final partnerMessages = entry.value;

      // Sort messages by timestamp (newest first)
      partnerMessages.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      final latestMessage = partnerMessages.first;

      // Get user details
      final userDetails = await userService.getUserDetails(partnerId);

      // Determine user role
      bool isStudent = false;
      dynamic userData;

      if (userDetails is Student) {
        isStudent = true;
        userData = userDetails;
      } else if (userDetails is Company) {
        userData = userDetails;
      }

      final chat = UserChat(
        id: partnerId,
        name: isStudent
            ? (userDetails as Student).fullName
            : (userDetails as Company).name ?? 'Unknown User',
        lastMessage: latestMessage.content,
        timestamp: _formatTimestamp(latestMessage.timestamp),
        isUnread:
            !latestMessage.isRead && latestMessage.senderId != _currentUserId,
        avatarUrl: isStudent
            ? (userDetails as Student).imageUrl
            : (userDetails as Company).logoURL ?? '',
        unreadCount: partnerMessages
            .where((msg) => !msg.isRead && msg.senderId != _currentUserId)
            .length,
        lastMessageTimestamp: latestMessage.timestamp,
        userRole: isStudent ? 'student' : 'company',
        userData: userData,
      );

      chats.add(chat);
    }

    // Sort chats by last message timestamp (newest first)
    chats.sort(
      (a, b) => b.lastMessageTimestamp.compareTo(a.lastMessageTimestamp),
    );

    setState(() {
      _allChats = chats;
      _filteredChats = _applyFilter(chats, _selectedFilter);
      _isLoading = false;
    });
  }

  String _formatTimestamp(Timestamp timestamp) {
    final now = DateTime.now();
    final messageDate = timestamp.toDate();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final messageDay = DateTime(
      messageDate.year,
      messageDate.month,
      messageDate.day,
    );

    if (messageDay == today) {
      return DateFormat('h:mm a').format(messageDate);
    } else if (messageDay == yesterday) {
      return 'Yesterday';
    } else if (now.difference(messageDate).inDays < 7) {
      return DateFormat('EEEE').format(messageDate);
    } else {
      return DateFormat('MM/dd/yy').format(messageDate);
    }
  }

  List<UserChat> _applyFilter(List<UserChat> chats, int filterIndex) {
    switch (filterIndex) {
      case 1: // Unread
        return chats.where((chat) => chat.isUnread).toList();
      case 2: // Students only (if company user)
        if (_currentUserRole == 'company') {
          return chats.where((chat) => chat.userRole == 'student').toList();
        }
        return chats;
      case 3: // Companies only (if student user)
        if (_currentUserRole == 'student') {
          return chats.where((chat) => chat.userRole == 'company').toList();
        }
        return chats;
      default: // All
        return chats;
    }
  }

  void _onSearchChanged(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredChats = _applyFilter(_allChats, _selectedFilter);
      });
    } else {
      setState(() {
        _filteredChats = _applyFilter(_allChats, _selectedFilter)
            .where(
              (chat) =>
                  chat.name.toLowerCase().contains(query.toLowerCase()) ||
                  chat.lastMessage.toLowerCase().contains(query.toLowerCase()),
            )
            .toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar
            _buildTopAppBar(context),

            // Search Bar
            _buildSearchBar(context),

            // Filter Chips
            if (_currentUserRole !=
                null) // Only show filters if we know user role
              _buildFilterChips(context),

            // Loading or Chat List
            Expanded(
              child: _isLoading
                  ? _buildLoadingIndicator(context)
                  : _filteredChats.isEmpty
                  ? _buildEmptyState(context)
                  : _buildChatList(context),
            ),
          ],
        ),
      ),
      floatingActionButton: _currentUserRole == 'company'
          ? FloatingActionButton(
              onPressed: () {
                // Show dialog to select from existing students
                _showStudentSelectionDialog(context);
              },
              child: Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildTopAppBar(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      height: 56,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: colorScheme.outline.withOpacity(0.1)),
        ),
        color: colorScheme.surface.withOpacity(0.85),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  _currentUserRole == 'company' ? 'Students Chat' : 'Chats',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ),
            if (_currentUserRole != 'company')
              IconButton(
                icon: Icon(
                  Icons.group_add,
                  color: colorScheme.onSurface,
                  size: 28,
                ),
                onPressed: () {
                  // Navigate to create group chat
                  // GeneralMethods.navigateTo(context, CreateGroupPage());
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    // Different filters based on user role
    List<String> filters;

    if (_currentUserRole == 'company') {
      filters = ['All', 'Unread', 'Students', 'Companies'];
    } else {
      filters = ['All', 'Unread', 'Accepted', 'Archived'];
    }

    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.asMap().entries.map((entry) {
            final index = entry.key;
            final filter = entry.value;
            final isSelected = _selectedFilter == index;

            return Padding(
              padding: EdgeInsets.only(
                right: index < filters.length - 1 ? 12 : 0,
              ),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedFilter = index;
                    _filteredChats = _applyFilter(_allChats, index);
                  });
                },
                child: Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: isSelected
                        ? colorScheme.primary
                        : isDark
                        ? Colors.white.withOpacity(0.1)
                        : colorScheme.surfaceContainer,
                  ),
                  child: Center(
                    child: Text(
                      filter,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: isSelected
                            ? colorScheme.onPrimary
                            : colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            _currentUserRole == 'company'
                ? 'Loading students...'
                : 'Loading chats...',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: colorScheme.onSurfaceVariant,
          ),
          SizedBox(height: 16),
          Text(
            _selectedFilter == 3
                ? 'No archived chats'
                : _searchController.text.isNotEmpty
                ? 'No matching chats found'
                : _currentUserRole == 'company'
                ? 'No students have applied yet'
                : 'No messages yet',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: 8),
          if (_currentUserRole == 'company')
            Text(
              'Students who apply will appear here',
              style: theme.textTheme.bodySmall,
            ),
        ],
      ),
    );
  }

  Widget _buildChatList(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      color: colorScheme.surfaceContainerLowest,
      child: ListView.separated(
        separatorBuilder: (context, index) =>
            Divider(height: 1, color: colorScheme.outline.withOpacity(0.1)),
        itemCount: _filteredChats.length,
        itemBuilder: (context, index) {
          final chat = _filteredChats[index];
          return _buildChatItem(context, chat);
        },
      ),
    );
  }

  Widget _buildChatItem(BuildContext context, UserChat chat) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: chat.isUnread
          ? colorScheme.primary.withOpacity(0.05)
          : colorScheme.surface,
      child: InkWell(
        onTap: () {
          // Check if there's an existing conversation
          if (_currentUserRole == 'company' &&
              chat.lastMessageTimestamp == null) {
            // Start a new conversation with this student
            _startNewConversation(context, chat);
          } else {
            // Open existing chat
            GeneralMethods.navigateTo(
              context,
              ChatDetailsPage(
                receiverId: chat.id,
                receiverName: chat.name,
                receiverAvatarUrl: chat.avatarUrl,
                receiverRole: chat.userRole,
                receiverData: chat.userData,
              ),
            );
          }
        },
        onLongPress: () {
          _showChatOptions(context, chat);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          height: 72,
          child: Row(
            children: [
              // Avatar with unread indicator
              Stack(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundImage: chat.avatarUrl.isNotEmpty
                        ? NetworkImage(chat.avatarUrl)
                        : null,
                    backgroundColor: chat.avatarUrl.isEmpty
                        ? colorScheme.primary.withOpacity(0.2)
                        : colorScheme.surfaceContainer,
                    child: chat.avatarUrl.isEmpty
                        ? Text(
                            chat.name.substring(0, 1).toUpperCase(),
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: colorScheme.primary,
                            ),
                          )
                        : null,
                  ),
                  if (chat.unreadCount > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: colorScheme.error,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: colorScheme.surface,
                            width: 2,
                          ),
                        ),
                        constraints: BoxConstraints(
                          minWidth: 24,
                          minHeight: 24,
                        ),
                        child: Text(
                          chat.unreadCount > 9 ? '9+' : '${chat.unreadCount}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onError,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  if (_currentUserRole == 'company' &&
                      chat.userRole == 'student')
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: colorScheme.surface,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.school,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),

              // Chat Info
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            chat.name,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: chat.isUnread
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          chat.timestamp,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: chat.isUnread
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      chat.lastMessage.isNotEmpty
                          ? chat.lastMessage
                          : 'Tap to start conversation',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: chat.isUnread
                            ? colorScheme.onSurface
                            : colorScheme.onSurfaceVariant,
                        fontWeight: chat.isUnread
                            ? FontWeight.w500
                            : FontWeight.normal,
                        fontStyle: chat.lastMessage.isEmpty
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

  void _showStudentSelectionDialog(BuildContext context) async {
    try {
      final companyCloud = Company_Cloud();
      final students = await companyCloud.getStudentsThatAppliedForCompany(
        _currentUserId!,
      );

      if (students.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No students have applied yet')));
        return;
      }

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Select Student to Chat With'),
          content: Container(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: students.length,
              itemBuilder: (context, index) {
                final student = students[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: student.imageUrl.isNotEmpty
                        ? NetworkImage(student.imageUrl)
                        : null,
                    child: student.imageUrl.isEmpty
                        ? Text(student.fullName.substring(0, 1))
                        : null,
                  ),
                  title: Text(student.fullName),
                  subtitle: Text(student.courseOfStudy ?? 'Student'),
                  onTap: () {
                    Navigator.pop(context);
                    _startNewConversation(
                      context,
                      UserChat(
                        id: student.uid,
                        name: student.fullName,
                        lastMessage: '',
                        timestamp: '',
                        isUnread: false,
                        avatarUrl: student.imageUrl,
                        unreadCount: 0,
                        lastMessageTimestamp: Timestamp.now(),
                        userRole: 'student',
                        userData: student,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      );
    } catch (e) {
      print('Error showing student selection: $e');
    }
  }

  void _startNewConversation(BuildContext context, UserChat chat) {
    GeneralMethods.navigateTo(
      context,
      ChatDetailsPage(
        receiverId: chat.id,
        receiverName: chat.name,
        receiverAvatarUrl: chat.avatarUrl,
        receiverRole: chat.userRole,
        receiverData: chat.userData,
      ),
    );
  }

  String _getEmptyStateTitle() {
    if (_searchController.text.isNotEmpty) {
      return _currentUserRole == 'company'
          ? 'No students found'
          : 'No chats found';
    }

    if (_selectedFilter == 3 && _currentUserRole != 'company') {
      return 'No archived chats';
    }

    return _currentUserRole == 'company'
        ? 'No students have applied yet'
        : 'No messages yet';
  }

  String _getEmptyStateSubtitle() {
    if (_searchController.text.isNotEmpty) {
      return _currentUserRole == 'company'
          ? 'Try searching with different keywords'
          : 'Try a different search term';
    }

    return _currentUserRole == 'company'
        ? 'Students who apply to your company will appear here'
        : 'Start a conversation with your connections';
  }

  bool _shouldShowActionButton() {
    return _searchController.text.isEmpty &&
        _selectedFilter == 0 &&
        _currentUserRole != 'company';
  }

  void _getEmptyStateAction() {
    // Navigate to start new chat
    // GeneralMethods.navigateTo(context, NewChatPage());
  }

  String _getEmptyStateActionText() {
    return 'Start a conversation';
  }

  Widget _buildSearchBar(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isDark
              ? Colors.black.withOpacity(0.3)
              : colorScheme.surfaceContainer,
        ),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Icon(
                Icons.search,
                color: colorScheme.onSurfaceVariant,
                size: 24,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: _getSearchHintText(),
                    hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: TextStyle(color: colorScheme.onSurface),
                ),
              ),
            ),
            if (_searchController.text.isNotEmpty)
              IconButton(
                icon: Icon(
                  Icons.clear,
                  color: colorScheme.onSurfaceVariant,
                  size: 20,
                ),
                onPressed: () {
                  _searchController.clear();
                  _onSearchChanged('');
                },
              ),
          ],
        ),
      ),
    );
  }

  String _getSearchHintText() {
    if (_currentUserRole == 'company') {
      return 'Search students by name...';
    } else {
      return 'Search by name or message...';
    }
  }

  void _showChatOptions(BuildContext context, UserChat chat) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_currentUserRole == 'company' && chat.userRole == 'student')
                ListTile(
                  leading: Icon(Icons.person),
                  title: Text('View Student Profile'),
                  onTap: () {
                    Navigator.pop(context);
                    _viewStudentProfile(context, chat.userData as Student);
                  },
                ),
              ListTile(
                leading: Icon(Icons.archive),
                title: Text('Archive chat'),
                onTap: () {
                  Navigator.pop(context);
                  _archiveChat(chat);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete),
                title: Text('Delete chat'),
                onTap: () {
                  Navigator.pop(context);
                  _deleteChat(chat);
                },
              ),
              ListTile(
                leading: Icon(Icons.cancel),
                title: Text('Cancel'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  void _viewStudentProfile(BuildContext context, Student student) {
    // Navigate to student profile page
    // GeneralMethods.navigateTo(context, StudentProfilePage(student: student));
    print('View profile for student: ${student.fullName}');
  }

  void _archiveChat(UserChat chat) {
    print('Archive chat with ${chat.name}');
  }

  void _deleteChat(UserChat chat) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete chat?'),
        content: Text(
          'Are you sure you want to delete chat with ${chat.name}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              print('Delete chat with ${chat.name}');
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class UserChat {
  final String id;
  final String name;
  final String lastMessage;
  final String timestamp;
  final bool isUnread;
  final String avatarUrl;
  final int unreadCount;
  final Timestamp lastMessageTimestamp;
  final String userRole; // 'student' or 'company'
  final dynamic userData; // Student or Company object

  UserChat({
    required this.id,
    required this.name,
    required this.lastMessage,
    required this.timestamp,
    required this.isUnread,
    required this.avatarUrl,
    required this.unreadCount,
    required this.lastMessageTimestamp,
    this.userRole = 'student',
    this.userData,
  });
}

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ITCFirebaseLogic itcFirebaseLogic = ITCFirebaseLogic();

  Future<dynamic> getUserDetails(String userId) async {
    try {
      // Try to get student first
      Student? student = await itcFirebaseLogic.getStudent(userId);
      if (student != null) {
        return student;
      }

      // Try to get company
      Company? company = await itcFirebaseLogic.getCompany(userId);
      if (company != null) return company;

      return null;
    } catch (e) {
      print('Error getting user details: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getCurrentUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      // Check in students collection
      final studentDoc = await _firestore
          .collection('users')
          .doc('students')
          .collection('students')
          .doc(user.uid)
          .get();

      if (studentDoc.exists) {
        return studentDoc.data();
      }

      // Check in companies collection
      final companyDoc = await _firestore
          .collection('users')
          .doc('companies')
          .collection('companies')
          .doc(user.uid)
          .get();

      if (companyDoc.exists) {
        return companyDoc.data();
      }

      return null;
    } catch (e) {
      print('Error getting current user data: $e');
      return null;
    }
  }
}
