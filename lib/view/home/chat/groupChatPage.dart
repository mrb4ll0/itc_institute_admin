// Placeholder for group chat page
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:itc_institute_admin/model/userProfile.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../../../itc_logic/firebase/general_cloud.dart';
import '../../../../itc_logic/firebase/message/message_service.dart';
import '../../../../model/student.dart';
import '../../../../firebase_cloud_storage/firebase_cloud.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../../itc_logic/firebase/provider/groupChatProvider.dart';
import 'groupChatInfo.dart';

class GroupChatPage extends StatefulWidget {
  final UserConverter currentUser;
  const GroupChatPage({required this.currentUser});
  @override
  State<GroupChatPage> createState() => _GroupChatPageState();
}

class _GroupChatPageState extends State<GroupChatPage> with WidgetsBindingObserver {
  final ChatService _chatService = ChatService(FirebaseAuth.instance.currentUser!.uid);
  final ITCFirebaseLogic _itcFirebaseLogic = ITCFirebaseLogic(FirebaseAuth.instance.currentUser!.uid);
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  double _lastViewInset = 0;
  bool _isScrollingToBottom = false;
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _inputFocusNode.addListener(_onFocusChange);
    _scrollController.addListener(_onScroll);
  }

  void _onFocusChange() {
    if (_inputFocusNode.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isScrollingToBottom) {
          _scrollToBottom();
        }
      });
    }
  }

  void _onScroll() {
    // Prevent auto-scroll when user is manually scrolling
    if (_scrollController.position.userScrollDirection != ScrollDirection.idle) {
      _isScrollingToBottom = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    _messageController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    final viewInset = MediaQuery.of(context).viewInsets.bottom;
    if (viewInset > _lastViewInset && !_isScrollingToBottom) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToBottom();
      });
    }
    _lastViewInset = viewInset;
  }

  void _scrollToBottom() {
    if (!mounted || !_scrollController.hasClients) return;

    _isScrollingToBottom = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        ).then((_) {
          _isScrollingToBottom = false;
        });
      }
    });
  }

  bool _shouldAutoScroll() {
    if (!_scrollController.hasClients) return false;
    return _scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 100;
  }

  Future<Widget> _buildSenderInfo(String senderId) async {
    final user = await _itcFirebaseLogic.getUserById(senderId);
    if (user is Student) {
      return Row(
        children: [
          CircleAvatar(radius: 12, backgroundImage: user.imageUrl.isNotEmpty ? NetworkImage(user.imageUrl) : null, child: user.imageUrl.isEmpty ? Icon(Icons.person, size: 14) : null),
          const SizedBox(width: 6),
          Text(user.fullName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      );
    }
    return Text('Unknown', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600));
  }

  void _openGroupInfo(GroupChatProvider groupChatProvider) async {
    final updated = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChangeNotifierProvider.value(
          value: groupChatProvider,
          child: GroupInfoPage(currentUser: widget.currentUser),
        ),
      ),
    );
    if (updated != null && updated is Map<String, dynamic>) {
      setState(() {
        // Update group state
      });
    }
  }

  void _showGroupMessageActions(BuildContext context, Map<String, dynamic> msg, String groupId, GroupChatProvider groupChatProvider) {
    final currentUserId = widget.currentUser.uid;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.share, color: Theme.of(context).colorScheme.primary),
                title: Text('Share'),
                onTap: () async {
                  Navigator.pop(context);
                  await Share.share(msg['content'] ?? '');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Message shared!')),
                    );
                  }
                },
              ),
              ListTile(
                leading: Icon(Icons.copy, color: Theme.of(context).colorScheme.primary),
                title: Text('Copy'),
                onTap: () async {
                  Navigator.pop(context);
                  await Clipboard.setData(ClipboardData(text: msg['content'] ?? ''));
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied to clipboard')),
                    );
                  }
                },
              ),
              ListTile(
                leading: Icon(Icons.reply, color: Theme.of(context).colorScheme.primary),
                title: Text('Reply'),
                onTap: () {
                  Navigator.pop(context);
                  groupChatProvider.setReplyToMessage(msg);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _scrollToBottom();
                  });
                },
              ),
              if (msg['senderId'] == currentUserId)
                ListTile(
                  leading: Icon(Icons.delete, color: Colors.red),
                  title: Text('Delete'),
                  onTap: () async {
                    Navigator.pop(context);
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Message'),
                        content: const Text('Are you sure you want to delete this message for yourself?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('Delete', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await _chatService.groupsCollection.doc(groupId).collection('messages').doc(msg['id']).update({
                        'deletedFor': FieldValue.arrayUnion([currentUserId]),
                      });
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Message deleted for you.')),
                        );
                      }
                    }
                  },
                )
              else
                ListTile(
                  leading: Icon(Icons.delete, color: Colors.grey),
                  title: Text('Delete'),
                  onTap: () {
                    Navigator.pop(context);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('You can only delete your own messages.')),
                      );
                    }
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGroupMessageBubble(Map<String, dynamic> msg, String groupId, bool isMe, bool isSystem, DateTime time) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final groupChatProvider = Provider.of<GroupChatProvider>(context, listen: false);

    if (isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.grey[100],
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? Colors.grey[600]! : Colors.grey[300]!,
                width: 1,
              ),
            ),
            child: Text(
              msg['content'] ?? '',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: isDark ? Colors.grey[300] : Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Container(
      margin: EdgeInsets.only(
        left: isMe ? 60 : 16,
        right: isMe ? 16 : 60,
        top: 8,
        bottom: 8,
      ),
      child: GestureDetector(
        onLongPress: () => _showGroupMessageActions(context, msg, groupId, groupChatProvider),
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity != null && details.primaryVelocity! > 0) {
            groupChatProvider.setReplyToMessage(msg);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _scrollToBottom();
            });
          }
        },
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 4),
                child: FutureBuilder<Widget>(
                  future: _buildSenderInfo(msg['senderId']),
                  builder: (context, snap) => snap.data ?? SizedBox.shrink(),
                ),
              ),
            Container(
              decoration: BoxDecoration(
                gradient: isMe
                    ? const LinearGradient(
                  colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
                    : null,
                color: isMe ? null : (isDark ? Colors.grey[800] : Colors.white),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isMe ? 20 : 8),
                  bottomRight: Radius.circular(isMe ? 8 : 20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: isMe ? null : Border.all(
                  color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
                  width: 1,
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (msg['replyTo'] != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isMe
                              ? Colors.white.withOpacity(0.2)
                              : (isDark ? Colors.grey[700] : Colors.grey[50]),
                          borderRadius: BorderRadius.circular(12),
                          border: Border(
                            left: BorderSide(
                              color: isMe ? Colors.white : const Color(0xFF667eea),
                              width: 3,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.reply,
                              size: 16,
                              color: isMe ? Colors.white70 : const Color(0xFF667eea),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                msg['replyTo']['content']?.toString() ?? '',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isMe ? Colors.white70 : (isDark ? Colors.grey[300] : Colors.grey[700]),
                                  fontStyle: FontStyle.italic,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Text(
                      msg['content'] ?? '',
                      style: TextStyle(
                        color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black87),
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Text(
                        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          fontSize: 11,
                          color: isMe ? Colors.white70 : Colors.grey[500],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupChatProvider = Provider.of<GroupChatProvider>(context, listen: false);
    final groupId = groupChatProvider.group?['id'] as String? ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF1a1a1a) : const Color(0xFFf8fafc);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF2d2d2d) : Colors.white,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Color(0xFF23243a)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white,
                backgroundImage: (groupChatProvider.group?['avatarUrl'] != null && (groupChatProvider.group?['avatarUrl'] as String).isNotEmpty)
                    ? NetworkImage(groupChatProvider.group?['avatarUrl'] as String)
                    : null,
                child: (groupChatProvider.group?['avatarUrl'] == null || (groupChatProvider.group?['avatarUrl'] as String).isEmpty)
                    ? Icon(Icons.group, color: const Color(0xFF667eea), size: 20)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    groupChatProvider.group?['name'] ?? 'Group',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '${groupChatProvider.group?['members']?.length ?? 0} members',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                icon: Icon(Icons.info_outline, color: const Color(0xFF667eea)),
                onPressed: () => _openGroupInfo(groupChatProvider),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: backgroundColor,
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _chatService.getGroupMessages(groupId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && _isLoading) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Loading messages...',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Error loading messages',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final currentUserId = widget.currentUser.uid;
                  final newMessages = (snapshot.data ?? [])
                      .where((msg) => msg['deletedFor'] == null || !(msg['deletedFor'] is List && (msg['deletedFor'] as List).contains(currentUserId)))
                      .toList();

                  if (_messages.length != newMessages.length ||
                      (_messages.isNotEmpty && newMessages.isNotEmpty &&
                          _messages.last['id'] != newMessages.last['id'])) {
                    _messages = newMessages;
                    _isLoading = false;
                    if (_messages.isNotEmpty) {
                      final lastMessage = _messages.last;
                      final shouldAutoScroll = _shouldAutoScroll() ||
                          lastMessage['senderId'] == currentUserId;
                      if (shouldAutoScroll && !_isScrollingToBottom) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted && _scrollController.hasClients) {
                            _scrollToBottom();
                          }
                        });
                      }
                    }
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isMe = msg['senderId'] == widget.currentUser.uid;
                      final isSystem = msg['type'] == 'system';
                      final time = msg['timestamp'] != null && msg['timestamp'] is Timestamp
                          ? (msg['timestamp'] as Timestamp).toDate()
                          : DateTime.now();
                      return _buildGroupMessageBubble(msg, groupId, isMe, isSystem, time);
                    },
                  );
                },
              ),
            ),
          ),
          SafeArea(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2d2d2d) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Consumer<GroupChatProvider>(
                    builder: (context, groupChatProvider, child) {
                      if (groupChatProvider.replyToMessage == null) return SizedBox.shrink();
                      return Container(
                        width: double.infinity,
                        margin: const EdgeInsets.all(12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[800] : const Color(0xFFf0f4ff),
                          borderRadius: BorderRadius.circular(12),
                          border: Border(
                            left: BorderSide(
                              color: const Color(0xFF667eea),
                              width: 3,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.reply, color: const Color(0xFF667eea), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                groupChatProvider.replyToMessage!['content'] != null && (groupChatProvider.replyToMessage!['content'] as String).isNotEmpty
                                    ? groupChatProvider.replyToMessage!['content']
                                    : (groupChatProvider.replyToMessage!['imageUrl'] != null ? '[Image]' : '[File]'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontStyle: FontStyle.italic,
                                  color: isDark ? Colors.white70 : Colors.grey[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close, size: 18, color: Colors.red[400]),
                              onPressed: () {
                                groupChatProvider.setReplyToMessage(null);
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            focusNode: _inputFocusNode,
                            controller: _messageController,
                            minLines: 1,
                            maxLines: 4,
                            decoration: InputDecoration(
                              hintText: 'Type your message...',
                              hintStyle: TextStyle(
                                color: Colors.grey[500],
                                fontWeight: FontWeight.w400,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF667eea).withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.send, color: Colors.white, size: 20),
                            onPressed: () async {
                              final text = _messageController.text.trim();
                              if (text.isEmpty) return;
                              final replyToMessage = Provider.of<GroupChatProvider>(context, listen: false).replyToMessage;
                              _messageController.clear();
                              Provider.of<GroupChatProvider>(context, listen: false).setReplyToMessage(null);
                              try {
                                await _chatService.sendGroupMessage(
                                  groupId: groupId,
                                  senderId: widget.currentUser.uid,
                                  content: text,
                                  extra: replyToMessage != null ? {'replyTo': replyToMessage} : null,
                                );
                              } catch (e) {
                                _messageController.text = text;
                                if (replyToMessage != null) {
                                  Provider.of<GroupChatProvider>(context, listen: false).setReplyToMessage(replyToMessage);
                                }
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send: $e')));
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
