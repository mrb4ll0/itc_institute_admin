import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:itc_institute_admin/model/admin.dart';
import 'package:itc_institute_admin/model/userProfile.dart';
import 'package:itc_institute_admin/view/home/chat/chartPage.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../itc_logic/admin_task.dart';
import '../../firebase_cloud_storage/firebase_cloud.dart';
import '../../itc_logic/firebase/general_cloud.dart';
import '../../itc_logic/firebase/message/message_service.dart';
import '../../itc_logic/firebase/provider/groupChatProvider.dart';
import '../../itc_logic/service/ConverterUserService.dart';
import '../../model/company.dart';
import '../../model/message.dart';
import '../../model/student.dart';
import 'chat/groupChatPage.dart';

class MessagesView extends StatefulWidget {

  MessagesView({super.key});

  @override
  State<MessagesView> createState() => _MessagesViewState();
}

class _MessagesViewState extends State<MessagesView> {
  final ChatService _chatService = ChatService();
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final ITCFirebaseLogic _itcFirebaseLogic = ITCFirebaseLogic();
  final AdminCloud _adminCloud = AdminCloud();

  late Stream<List<Message>> _messageStream;
  late Stream<List<Map<String, dynamic>>> _groupStream;
  bool _isLoading = true;  // Add this flag
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();

    _messageStream = Stream.value([]);
    _groupStream = Stream.value([]);

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });

    loadCompany();

  }
Company? company;
  loadCompany()async
  {
    company = await _itcFirebaseLogic.getCompany(FirebaseAuth.instance.currentUser!.uid);
     if(company == null)
       {
         debugPrint("company is null");
         setState(() {
           _isLoading = false;
         });
         return;
       }
    _messageStream = _chatService.getAllMessagesForCurrentUser();
    _groupStream = _chatService.getUserGroups(company!.id);
    setState(() {
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }
    return Scaffold(
      appBar: AppBar(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        elevation: 0,
        title: Text(
          'Messages',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.blueGrey[900],
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: Container(
        decoration:
        BoxDecoration(color: isDark ? Colors.grey[900] : Colors.white),
        child: Column(
          children: [
            // Modern Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [Color(0xFF232526), Color(0xFF414345)]
                        : [
                      Colors.white.withOpacity(0.7),
                      Colors.blue[50]!.withOpacity(0.9)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withOpacity(0.08)
                          : Colors.blue[100]!.withOpacity(0.13),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by name...',
                    hintStyle: TextStyle(
                        color: isDark ? Colors.white54 : Colors.blueGrey[400]),
                    prefixIcon: Icon(Icons.search,
                        color: isDark ? Colors.white54 : Colors.blueGrey[400]),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                  style: TextStyle(
                      color: isDark ? Colors.white : Colors.blueGrey[900]),
                ),
              ),
            ),
            // GROUPS SECTION
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: _groupStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final groups = snapshot.data ?? [];
                if (groups.isEmpty) return SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Text(
                        'Groups',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Color(0xFF23243a),
                          fontSize: 15,
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 110,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: groups.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 16),
                        itemBuilder: (context, index) {
                          final group = groups[index];
                          return FutureBuilder<QuerySnapshot>(
                            future: ChatService()
                                .groupsCollection
                                .doc(group['id'])
                                .collection('messages')
                                .orderBy('timestamp', descending: true)
                                .limit(1)
                                .get(),
                            builder: (context, lastMsgSnap) {
                              String lastMsg = '';
                              String lastType = 'text';
                              DateTime? lastTime;
                              if (lastMsgSnap.hasData &&
                                  lastMsgSnap.data!.docs.isNotEmpty) {
                                final msg = lastMsgSnap.data!.docs.first.data()
                                as Map<String, dynamic>;
                                lastMsg = msg['content'] ?? '';
                                lastType = msg['type'] ?? 'text';
                                if (msg['timestamp'] is Timestamp)
                                  lastTime =
                                      (msg['timestamp'] as Timestamp).toDate();
                              }
                              return GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ChangeNotifierProvider(
                                        create: (_) => GroupChatProvider()
                                          ..setGroup(group),
                                        child: GroupChatPage(
                                            currentUser: UserConverter(company)),
                                      ),
                                    ),
                                  );
                                },
                                child: Container(
                                  width: 220,
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF23243a)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: isDark
                                            ? Colors.black.withOpacity(0.10)
                                            : const Color(0xFF667eea)
                                            .withOpacity(0.08),
                                        blurRadius: 14,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                    border: Border.all(
                                      color: isDark
                                          ? Colors.white12
                                          : const Color(0xFF667eea)
                                          .withOpacity(0.18),
                                      width: 1.2,
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 14),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 26,
                                        backgroundColor: Colors.white,
                                        child: Icon(Icons.group,
                                            color: Color(0xFF667eea), size: 28),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              group['name'] ?? '',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                                color: isDark
                                                    ? Colors.white
                                                    : Colors.blueGrey[900],
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              lastType == 'image'
                                                  ? '[Image]'
                                                  : lastMsg,
                                              style: TextStyle(
                                                color: isDark
                                                    ? Colors.white70
                                                    : Colors.blueGrey[700],
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (lastTime != null)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 4.0),
                                                child: Text(
                                                  TimeOfDay.fromDateTime(
                                                      lastTime)
                                                      .format(context),
                                                  style: TextStyle(
                                                    color: isDark
                                                        ? Colors.white54
                                                        : Colors.blueGrey[400],
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
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
                      ),
                    ),
                  ],
                );
              },
            ),
            // Horizontally scrollable list of students
            FutureBuilder<List<Student>>(
              future: _adminCloud.getPotentialStudents(company: company),
              builder: (context, studentSnap) {
                if (!studentSnap.hasData) {
                  return const SizedBox(
                    height: 110,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final students = studentSnap.data!
                    .where((s) => s.uid != company?.id)
                    .where((s) =>
                _searchQuery.isEmpty ||
                    s.fullName.toLowerCase().contains(_searchQuery))
                    .toList();
                if (students.isEmpty) {
                  return const SizedBox(height: 110);
                }
                return SizedBox(
                  height: 110,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    itemCount: students.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 16),
                    itemBuilder: (context, index) {
                      final s = students[index];
                      return SizedBox(
                        width: 80,
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatDetailsPage(
                                  receiverName: s.fullName,
                                  receiverAvatarUrl: s.imageUrl,
                                  receiverId: s.uid,
                                ),
                              ),
                            );
                          },
                          child: SingleChildScrollView(
                            physics: NeverScrollableScrollPhysics(),
                            scrollDirection: Axis.vertical,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                ClipOval(
                                  child: SizedBox(
                                    width: 56,
                                    height: 56,
                                    child: s.imageUrl.isNotEmpty
                                        ? Image.network(
                                      s.imageUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                          Container(
                                            color: Colors.blueGrey.shade200,
                                            child: const Icon(Icons.person,
                                                color: Colors.white,
                                                size: 28),
                                          ),
                                    )
                                        : Container(
                                      color: Colors.blueGrey.shade200,
                                      child: const Icon(Icons.person,
                                          color: Colors.white, size: 28),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: 72,
                                  child: Text(
                                    s.fullName.split(' ').first,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
            // Expanded chat list or student list
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  setState(() {});
                },
                child: StreamBuilder<List<Message>>(
                  stream: _messageStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      debugPrint("${snapshot.error}");
                      return const Center(
                          child: Text("Error loading messages."));
                    }

                    final userId = _firebaseAuth.currentUser?.uid;
                    final messages = (snapshot.data ?? [])
                        .where((msg) =>
                    msg.deletedFor == null ||
                        !(msg.deletedFor?.contains(userId) ?? false))
                        .toList();

                    if (messages.isEmpty) {
                      // Show all students (except current user) in Messenger style (vertical list)
                      return FutureBuilder<List<Student>>(
                        future: _adminCloud.getAllStudents(),
                        builder: (context, studentSnap) {
                          if (!studentSnap.hasData) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }
                          final students = studentSnap.data!
                              .where((s) => s.uid != company?.id)
                              .where((s) =>
                          _searchQuery.isEmpty ||
                              s.fullName
                                  .toLowerCase()
                                  .contains(_searchQuery))
                              .toList();
                          if (students.isEmpty) {
                            return const Center(
                                child:
                                Text("No other students registered yet."));
                          }
                          return ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: students.length,
                            itemBuilder: (context, index) {
                              final s = students[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                elevation: 4,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                                child: ListTile(
                                  leading: ClipOval(
                                    child: SizedBox(
                                      width: 48,
                                      height: 48,
                                      child: s.imageUrl != null &&
                                          s.imageUrl.isNotEmpty
                                          ? Image.network(
                                        s.imageUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error,
                                            stackTrace) =>
                                            Container(
                                              color: Colors.blueGrey.shade200,
                                              child: const Icon(Icons.person,
                                                  color: Colors.white,
                                                  size: 24),
                                            ),
                                      )
                                          : Container(
                                        color: Colors.blueGrey.shade200,
                                        child: const Icon(Icons.person,
                                            color: Colors.white,
                                            size: 24),
                                      ),
                                    ),
                                  ),
                                  title: Text(s.fullName,
                                      style: theme.textTheme.titleMedium),
                                  subtitle: Text(s.email),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ChatDetailsPage(
                                          receiverName: s.fullName,
                                          receiverAvatarUrl: s.imageUrl,
                                          receiverId: s.uid,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          );
                        },
                      );
                    }
                    // Filter messages by search query (name)
                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        final otherUserId =
                        message.senderId == _firebaseAuth.currentUser!.uid
                            ? message.receiverId
                            : message.senderId;
                        debugPrint(
                            'Fetching message: currentUser=${_firebaseAuth.currentUser!.uid}, otherUserId=$otherUserId, messageId=${message.id}');

                        return FutureBuilder<UserConverter?>(
                          future: UserService().getUser(otherUserId),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const SizedBox();
                            }
                            final user = snapshot.data!;
                            debugPrint("user is ${user.toString()}");

                            bool isAdmin = false;
                            if (_searchQuery.isNotEmpty &&
                                !user.displayName.toLowerCase().contains(_searchQuery)) {
                              return const SizedBox.shrink();
                            }
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              child: ListTile(
                                leading: ClipOval(
                                  child: SizedBox(
                                    width: 48,
                                    height: 48,
                                    child: isAdmin
                                        ? Container(
                                      color: Colors.blueGrey.shade200,
                                      child: const Icon(Icons.person,
                                          color: Colors.white, size: 24),
                                    )
                                        : (user.imageUrl.isNotEmpty
                                        ? Image.network(
                                      user.imageUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error,
                                          stackTrace) =>
                                          Container(
                                            color:
                                            Colors.blueGrey.shade200,
                                            child: const Icon(
                                                Icons.person,
                                                color: Colors.white,
                                                size: 24),
                                          ),
                                    )
                                        : Container(
                                      color: Colors.blueGrey.shade200,
                                      child: const Icon(Icons.person,
                                          color: Colors.white,
                                          size: 24),
                                    )),
                                  ),
                                ),
                                title: Text(user.uid.startsWith("admin_")?"${user.displayName.split(" ").first} ITC Rep":user.displayName,
                                    style: theme.textTheme.titleMedium),
                                subtitle: Text(
                                  message.senderId == FirebaseAuth.instance.currentUser!.uid?
                                  "You: ${message.content
                                      .replaceAll(RegExp(r'\([^)]*\)$'), '')}":message.content
                                      .replaceAll(RegExp(r'\([^)]*\)$'), ''),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: Column(
                                  mainAxisAlignment:
                                  MainAxisAlignment.spaceAround,
                                  children: [
                                    Text(
                                      "${TimeOfDay.fromDateTime(message.timestamp.toDate()).hour}:${TimeOfDay.fromDateTime(message.timestamp.toDate()).minute.toString().padLeft(2, '0')}",
                                    ),
                                    if (!message.isRead &&
                                        message.receiverId ==
                                            _firebaseAuth.currentUser!.uid)
                                      Container(
                                        height: 24,
                                        width: 24,
                                        decoration: BoxDecoration(
                                          borderRadius:BorderRadius.circular(20),
                                        ),
                                        child: const Center(
                                          child: Text("1+",
                                              style: TextStyle(
                                                  color: Colors.blue,
                                                  fontSize: 12)),
                                        ),
                                      )
                                  ],
                                ),
                                onTap: () {
                                  final isAdminChat = user.uid.startsWith('admin_');
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ChatDetailsPage(
                                        receiverName: user.displayName,
                                        receiverAvatarUrl:user.imageUrl,
                                        receiverId: user.uid,
                                      ),
                                    ),
                                  );
                                },
                                onLongPress: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Delete Chat'),
                                      content: const Text(
                                          'Are you sure you want to delete this chat? This cannot be undone.'),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(false),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(true),
                                          child: const Text('Delete',
                                              style:
                                              TextStyle(color: Colors.red)),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    // Show progress dialog
                                    showDialog(
                                      context: context,
                                      barrierDismissible: false,
                                      builder: (context) => const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    );
                                    await _deleteChatWithUser(user.uid);
                                    Navigator.of(context, rootNavigator: true)
                                        .pop(); // Dismiss progress dialog
                                    setState(() {}); // Refresh the list
                                  }
                                },
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Color(0xFF667eea).withOpacity(0.18),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton(
          backgroundColor: Colors.transparent,
          elevation: 0,
          onPressed: () async {
            final result = await showModalBottomSheet<String>(
              context: context,
              shape: RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.vertical(top: Radius.circular(18))),
              builder: (context) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: Icon(Icons.group_add),
                    title: Text('Create Group'),
                    onTap: () => Navigator.pop(context, 'group'),
                  ),
                  ListTile(
                    leading: Icon(Icons.person_add),
                    title: Text('Start New Chat'),
                    onTap: () => Navigator.pop(context, 'chat'),
                  ),
                ],
              ),
            );
            if (result == 'group') {
              if(company == null)
                {
                  Fluttertoast.showToast(msg: "company is null");
                  return;
                }
              await showDialog(
                context: context,
                builder: (context) =>
                    CreateGroupDialog(currentUser: UserConverter(company)),
              );
            } else if (result == 'chat') {
              await showDialog(
                context: context,
                builder: (context) => _StartNewChatDialog(
                  student: UserConverter(company),
                  adminCloud: _adminCloud,
                  chatService: _chatService,
                  itcFirebaseLogic: _itcFirebaseLogic,
                  firebaseAuth: _firebaseAuth,
                ),
              );
            }
          },
          child: Icon(Icons.add, color: Colors.white, size: 28),
        ),
      ),
    );
  }

  Future<void> _deleteChatWithUser(String otherUserId) async {
    final userId = _firebaseAuth.currentUser?.uid;
    if (userId == null) return;
    try {
      // Compute chatRoomID
      List<String> ids = [userId, otherUserId];
      ids.sort();
      String chatRoomID = ids.join('_');
      final chatRoomRef =
      FirebaseFirestore.instance.collection('chat_rooms').doc(chatRoomID);
      final messagesRef = chatRoomRef.collection('messages');
      final messages = await messagesRef.get();
      for (var doc in messages.docs) {
        await doc.reference.update({
          'deletedFor': FieldValue.arrayUnion([userId]),
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat deleted for you.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete chat: $e')),
        );
      }
    }
  }
}

class _StartNewChatDialog extends StatefulWidget {
  final UserConverter student;
  final AdminCloud adminCloud;
  final ChatService chatService;
  final ITCFirebaseLogic itcFirebaseLogic;
  final FirebaseAuth firebaseAuth;
  const _StartNewChatDialog({
    required this.student,
    required this.adminCloud,
    required this.chatService,
    required this.itcFirebaseLogic,
    required this.firebaseAuth,
  });

  @override
  State<_StartNewChatDialog> createState() => _StartNewChatDialogState();
}

class _StartNewChatDialogState extends State<_StartNewChatDialog> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Start New Chat'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              labelText: 'Enter student name',
              prefixIcon: Icon(Icons.search),
            ),
            keyboardType: TextInputType.text,
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: CircularProgressIndicator(),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text("Student not found",
                  style: const TextStyle(color: Colors.red)),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _startChat,
          child: const Text('Start Chat'),
        ),
      ],
    );
  }

  Future<void> _startChat() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final input = _searchController.text.trim();
    if (input.isEmpty) {
      setState(() {
        _isLoading = false;
        _error = 'Please enter a name.';
      });
      return;
    }
    try {
      dynamic user;
      // Search all students and match by name (case-insensitive)
      final allStudents = await widget.adminCloud.getAllStudents();
      user = allStudents.firstWhere(
            (s) => s.fullName.toLowerCase() == input.toLowerCase(),
        orElse: () => null as dynamic,
      );
      if (user == null || (user is Student && user.uid == widget.student.uid)) {
        // Not found or self
        setState(() {
          _isLoading = false;
        });
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Student Not Found'),
            content: const Text(
                'This student is not on ITConnect. Would you like to share the app link with them?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Share.share(
                    'Check out my app: https://play.google.com/store/apps/details?id=com.mrb4ll0.it_connect',
                    subject: 'IT Connect , Find your IT Placement fast!',
                  );
                  Navigator.pop(context);
                },
                child: const Text('Share App Link'),
              ),
            ],
          ),
        );
        return;
      }
      // If found, open chat page
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatDetailsPage(
            receiverName: user.fullName,
            receiverAvatarUrl: user.imageUrl,
            receiverId: user.uid,
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _error = 'Error: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

// GROUP CREATION DIALOG
class CreateGroupDialog extends StatefulWidget {
  final UserConverter currentUser;
  const CreateGroupDialog({required this.currentUser});
  @override
  State<CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<CreateGroupDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  File? _avatarFile;
  String? _avatarUrl;
  List<Student> _allStudents = [];
  List<Student> _selectedMembers = [];
  List<Student> _selectedAdmins = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    Company? company = widget.currentUser.getAs<Company>();
     if(company == null)
       {
         Fluttertoast.showToast(msg: "Error showing dialog, the company model is null");
         return;
       }

    final students = await AdminCloud().getPotentialStudents(company: company);
    setState(() {
      _allStudents =
          students.where((s) => s.uid != widget.currentUser.uid).toList();
    });
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked =
    await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      setState(() {
        _avatarFile = File(picked.path);
      });
    }
  }

  Future<void> _createGroup() async {
    if (!_formKey.currentState!.validate() || _selectedMembers.isEmpty) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      String? avatarUrl;
      if (_avatarFile != null) {
        avatarUrl = await FirebaseUploader()
            .uploadFile(_avatarFile!, widget.currentUser.uid, 'group_avatar');
      }
      final groupId = await ChatService().createGroup(
        name: _nameController.text.trim(),
        createdBy: widget.currentUser.uid,
        members: _selectedMembers.map((s) => s.uid).toList(),
        admins: [widget.currentUser.uid, ..._selectedAdmins.map((s) => s.uid)],
        description: _descController.text.trim(),
        avatarUrl: avatarUrl,
      );
      Navigator.pop(context);
      // Optionally: show success or open group chat
    } catch (e) {
      setState(() {
        _error = 'Failed to create group: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Create Group'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: _pickAvatar,
                child: CircleAvatar(
                  radius: 32,
                  backgroundColor: Colors.blue[200],
                  backgroundImage:
                  _avatarFile != null ? FileImage(_avatarFile!) : null,
                  child: _avatarFile == null
                      ? Icon(Icons.camera_alt, size: 32)
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'Group Name'),
                validator: (v) =>
                v == null || v.trim().isEmpty ? 'Enter group name' : null,
              ),
              TextFormField(
                controller: _descController,
                decoration:
                InputDecoration(labelText: 'Description (optional)'),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Add Members',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              Wrap(
                spacing: 6,
                children: _allStudents
                    .map((s) => FilterChip(
                  label: Text(s.fullName),
                  selected: _selectedMembers.contains(s),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedMembers.add(s);
                      } else {
                        _selectedMembers.remove(s);
                        _selectedAdmins.remove(s);
                      }
                    });
                  },
                ))
                    .toList(),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Add Admins',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              Wrap(
                spacing: 6,
                children: _selectedMembers
                    .map((s) => FilterChip(
                  label: Text(s.fullName),
                  selected: _selectedAdmins.contains(s),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedAdmins.add(s);
                      } else {
                        _selectedAdmins.remove(s);
                      }
                    });
                  },
                ))
                    .toList(),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_error!, style: TextStyle(color: Colors.red)),
                ),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: CircularProgressIndicator(),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: Text('Cancel')),
        ElevatedButton(
          onPressed: _isLoading ? null : _createGroup,
          child: Text('Create'),
        ),
      ],
    );
  }
}
