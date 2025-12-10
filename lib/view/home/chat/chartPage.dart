import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../itc_logic/firebase/message/message_service.dart';
import '../../../model/message.dart';
import '../../../model/student.dart';
import '../chatListPage.dart';
//import '../../home/chat/components/student_profile_card.dart'; // Optional: Create this for showing student info

class ChatDetailsPage extends StatefulWidget {
  final String receiverId;
  final String receiverName;
  final String receiverAvatarUrl;
  final String receiverRole; // 'student' or 'company'
  final dynamic receiverData; // Student or Company object

  const ChatDetailsPage({
    super.key,
    required this.receiverId,
    required this.receiverName,
    required this.receiverAvatarUrl,
    this.receiverRole = 'student',
    this.receiverData,
  });

  @override
  State<ChatDetailsPage> createState() => _ChatDetailsPageState();
}

class _ChatDetailsPageState extends State<ChatDetailsPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late ChatService _chatService;
  late Stream<List<Message>> _messagesStream;
  String? _currentUserId;
  String? _currentUserRole;
  bool _isLoading = true;
  bool _isSending = false;
  bool _isTyping = false;
  List<File> _selectedImages = [];
  final ImagePicker _imagePicker = ImagePicker();
  bool _showStudentInfo = false; // For showing student profile card
  late dynamic _receiverData; // Store the receiver data

  @override
  void initState() {
    super.initState();
    _receiverData = widget.receiverData;
    _initializeChat();
  }

  void _initializeChat() async {
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (_currentUserId != null) {
      // Get current user role
      final userService = UserService();
      final currentUserData = await userService.getCurrentUserData();
      _currentUserRole = currentUserData?['role'] ?? 'student';

      // Store receiver data
      _receiverData = widget.receiverData;

      _chatService = ChatService();
      _messagesStream = _chatService.getFilteredMessages(
        _currentUserId!,
        widget.receiverId,
      );
      setState(() {
        _isLoading = false;
      });

      // Scroll to bottom when new messages arrive
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty && _selectedImages.isEmpty) {
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      if (_selectedImages.isNotEmpty) {
        // Handle image upload and send
        final firstImage = _selectedImages.first;
        // Upload image to storage and get URL
        // String imageUrl = await _uploadImage(firstImage);

        final message = Message(
          senderId: _currentUserId!,
          receiverId: widget.receiverId,
          content: _messageController.text,
          timestamp: Timestamp.now(),
          isRead: false,
          imageUrl: null, // imageUrl after upload
        );

        await _chatService.sendImageMessage(msg: message);
        _selectedImages.clear();
      } else {
        await _chatService.sendMessage(
          widget.receiverId,
          _messageController.text.trim(),
        );
      }

      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send message: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      final List<XFile>? images = await _imagePicker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (images != null && images.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(images.map((xFile) => File(xFile.path)));
        });
      }
    } catch (e) {
      print('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pick image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (photo != null) {
        setState(() {
          _selectedImages.add(File(photo.path));
        });
      }
    } catch (e) {
      print('Error taking photo: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to take photo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(context);
                _takePhoto();
              },
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showMessageOptions(Message message) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.senderId == _currentUserId)
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Delete message'),
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessage(message);
                },
              ),
            ListTile(
              leading: const Icon(Icons.reply),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(context);
                _messageController.text = 'Replying to: ${message.content}';
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy text'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteMessage(Message message) async {
    if (message.id == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete message?'),
        content: const Text('This message will be deleted for everyone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _chatService.deleteMessage(
                  widget.receiverId,
                  _currentUserId!,
                  message.id!,
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to delete message: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Message message, ThemeData theme) {
    final isMe = message.senderId == _currentUserId;
    final time = DateFormat('h:mm a').format(message.timestamp.toDate());
    final showDateHeader = _shouldShowDateHeader(message);
    final previousMessage = _getPreviousMessage(message);

    return Column(
      children: [
        if (showDateHeader) _dateSeparator(message.timestamp, theme),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: GestureDetector(
            onLongPress: () => _showMessageOptions(message),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: isMe
                  ? MainAxisAlignment.end
                  : MainAxisAlignment.start,
              children: [
                if (!isMe &&
                    (_shouldShowAvatar(message, previousMessage) ||
                        message.imageUrl != null))
                  CircleAvatar(
                    backgroundImage: widget.receiverAvatarUrl.isNotEmpty
                        ? NetworkImage(widget.receiverAvatarUrl)
                        : null,
                    radius: 16,
                    backgroundColor: widget.receiverAvatarUrl.isEmpty
                        ? theme.colorScheme.primary.withOpacity(0.2)
                        : null,
                    child: widget.receiverAvatarUrl.isEmpty
                        ? Text(
                            widget.receiverName.substring(0, 1).toUpperCase(),
                            style: const TextStyle(fontSize: 12),
                          )
                        : null,
                  )
                else if (!isMe)
                  const SizedBox(width: 40),

                if (!isMe) const SizedBox(width: 8),

                Flexible(
                  child: Column(
                    crossAxisAlignment: isMe
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      if (!isMe && _shouldShowName(message, previousMessage))
                        Padding(
                          padding: const EdgeInsets.only(
                            bottom: 2.0,
                            left: 8.0,
                          ),
                          child: Text(
                            widget.receiverName,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                      Container(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.7,
                        ),
                        padding: message.imageUrl != null
                            ? const EdgeInsets.all(8)
                            : const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                        decoration: BoxDecoration(
                          color: isMe
                              ? theme.colorScheme.primary
                              : theme.colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (message.imageUrl != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  message.imageUrl!,
                                  width: 250,
                                  height: 150,
                                  fit: BoxFit.cover,
                                  loadingBuilder:
                                      (context, child, loadingProgress) {
                                        if (loadingProgress == null)
                                          return child;
                                        return Container(
                                          width: 250,
                                          height: 150,
                                          color: theme.colorScheme.surface,
                                          child: Center(
                                            child: CircularProgressIndicator(
                                              value:
                                                  loadingProgress
                                                          .expectedTotalBytes !=
                                                      null
                                                  ? loadingProgress
                                                            .cumulativeBytesLoaded /
                                                        loadingProgress
                                                            .expectedTotalBytes!
                                                  : null,
                                            ),
                                          ),
                                        );
                                      },
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      width: 250,
                                      height: 150,
                                      color: theme.colorScheme.errorContainer,
                                      child: Center(
                                        child: Icon(
                                          Icons.broken_image,
                                          color: theme.colorScheme.error,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),

                            if (message.imageUrl != null &&
                                message.content.isNotEmpty)
                              const SizedBox(height: 8),

                            if (message.content.isNotEmpty)
                              Text(
                                message.content,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: isMe
                                      ? theme.colorScheme.onPrimary
                                      : theme.colorScheme.onSurfaceVariant,
                                ),
                              ),

                            if (message.replyTo != null)
                              Container(
                                margin: const EdgeInsets.only(top: 8),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isMe
                                      ? theme.colorScheme.primary.withOpacity(
                                          0.3,
                                        )
                                      : theme.colorScheme.surfaceVariant
                                            .withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isMe
                                        ? theme.colorScheme.primary.withOpacity(
                                            0.5,
                                          )
                                        : theme.colorScheme.outline.withOpacity(
                                            0.5,
                                          ),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Replying to',
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: isMe
                                                ? theme.colorScheme.onPrimary
                                                      .withOpacity(0.8)
                                                : theme
                                                      .colorScheme
                                                      .onSurfaceVariant
                                                      .withOpacity(0.8),
                                          ),
                                    ),
                                    Text(
                                      message.replyTo?['content'] ?? '',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: isMe
                                                ? theme.colorScheme.onPrimary
                                                : theme
                                                      .colorScheme
                                                      .onSurfaceVariant,
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

                      const SizedBox(height: 4),

                      Row(
                        mainAxisAlignment: isMe
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.start,
                        children: [
                          Text(
                            time,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.6,
                              ),
                            ),
                          ),
                          if (isMe) ...[
                            const SizedBox(width: 4),
                            Icon(
                              message.isRead ? Icons.done_all : Icons.done,
                              size: 12,
                              color: message.isRead
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurface.withOpacity(
                                      0.6,
                                    ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  bool _shouldShowDateHeader(Message message) {
    return true;
  }

  bool _shouldShowAvatar(Message message, Message? previousMessage) {
    if (previousMessage == null) return true;

    final timeDiff =
        message.timestamp.seconds - previousMessage.timestamp.seconds;
    final isSameSender = message.senderId == previousMessage.senderId;

    return !isSameSender || timeDiff > 300;
  }

  bool _shouldShowName(Message message, Message? previousMessage) {
    if (message.senderId == _currentUserId) return false;
    if (previousMessage == null) return true;

    final isSameSender = message.senderId == previousMessage.senderId;
    return !isSameSender;
  }

  Message? _getPreviousMessage(Message message) {
    return null;
  }

  Widget _dateSeparator(Timestamp timestamp, ThemeData theme) {
    final messageDate = timestamp.toDate();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final messageDay = DateTime(
      messageDate.year,
      messageDate.month,
      messageDate.day,
    );

    String dateText;
    if (messageDay == today) {
      dateText = 'Today';
    } else if (messageDay == yesterday) {
      dateText = 'Yesterday';
    } else {
      dateText = DateFormat('MMMM d, yyyy').format(messageDate);
    }

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 16),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(dateText, style: theme.textTheme.bodySmall),
      ),
    );
  }

  Widget _buildSelectedImagesPreview() {
    if (_selectedImages.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Selected images:'),
              const Spacer(),
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedImages.clear();
                  });
                },
                child: const Text('Clear all'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedImages.length,
              itemBuilder: (context, index) {
                return Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: FileImage(_selectedImages[index]),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 12,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedImages.removeAt(index);
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 20,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentProfileCard() {
    if (_receiverData is! Student || !_showStudentInfo) {
      return const SizedBox.shrink();
    }

    final student = _receiverData as Student;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Student Information',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _showStudentInfo = false;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundImage: student.imageUrl.isNotEmpty
                    ? NetworkImage(student.imageUrl)
                    : null,
                backgroundColor: student.imageUrl.isEmpty
                    ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                    : null,
                child: student.imageUrl.isEmpty
                    ? Text(
                        student.fullName.substring(0, 1).toUpperCase(),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.fullName,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (student.courseOfStudy != null)
                      Text(
                        student.courseOfStudy!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    if (student.institution != null)
                      Text(
                        student.institution!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (student.skills.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Skills',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: student.skills
                      .map(
                        (skill) => Chip(
                          label: Text(skill),
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primaryContainer,
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (student.email.isNotEmpty)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Email',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      Text(
                        student.email,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              if (student.phoneNumber.isNotEmpty)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Phone',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      Text(
                        student.phoneNumber,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: Column(
        children: [
          _buildAppBar(context, theme),

          if (_showStudentInfo && _receiverData is Student)
            _buildStudentProfileCard(),

          if (_selectedImages.isNotEmpty) _buildSelectedImagesPreview(),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : StreamBuilder<List<Message>>(
                    stream: _messagesStream,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }

                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final messages = snapshot.data!;

                      if (messages.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline,
                                size: 64,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No messages yet',
                                style: theme.textTheme.bodyLarge,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Start a conversation with ${widget.receiverName}',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              if (_currentUserRole == 'company' &&
                                  _receiverData is Student)
                                const SizedBox(height: 16),
                              if (_currentUserRole == 'company' &&
                                  _receiverData is Student)
                                ElevatedButton(
                                  onPressed: () {
                                    setState(() {
                                      _showStudentInfo = true;
                                    });
                                  },
                                  child: const Text('View Student Profile'),
                                ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: messages.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return _isTyping
                                ? _typingIndicator(theme)
                                : const SizedBox.shrink();
                          }

                          final messageIndex = index - 1;
                          final message = messages[messageIndex];
                          return _buildMessageBubble(message, theme);
                        },
                      );
                    },
                  ),
          ),

          _inputBar(theme),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, ThemeData theme) {
    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            bottom: BorderSide(color: theme.dividerColor, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundImage: widget.receiverAvatarUrl.isNotEmpty
                  ? NetworkImage(widget.receiverAvatarUrl)
                  : null,
              radius: 20,
              backgroundColor: widget.receiverAvatarUrl.isEmpty
                  ? theme.colorScheme.primary.withOpacity(0.2)
                  : null,
              child: widget.receiverAvatarUrl.isEmpty
                  ? Text(
                      widget.receiverName.substring(0, 1).toUpperCase(),
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  if (_currentUserRole == 'company' &&
                      _receiverData is Student) {
                    setState(() {
                      _showStudentInfo = !_showStudentInfo;
                    });
                  }
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.receiverName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_currentUserRole == 'company' &&
                            widget.receiverRole == 'student')
                          Icon(
                            Icons.info_outline,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                      ],
                    ),
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(widget.receiverId)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasData && snapshot.data!.exists) {
                          final status =
                              snapshot.data!.data() as Map<String, dynamic>;
                          final isOnline = status['isOnline'] ?? false;
                          final lastSeen = status['lastSeen'];

                          if (isOnline) {
                            return Text(
                              'Online',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                            );
                          } else if (lastSeen != null) {
                            return Text(
                              'Last seen ${_formatLastSeen(lastSeen)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            );
                          }
                        }

                        // Show role instead
                        if (widget.receiverRole == 'student') {
                          if (_receiverData is Student) {
                            final student = _receiverData as Student;
                            return Text(
                              student.courseOfStudy ?? 'Student',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            );
                          }
                          return Text(
                            'Student',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          );
                        } else {
                          return Text(
                            'Company',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.more_horiz),
              onPressed: () => _showMoreOptions(context),
            ),
          ],
        ),
      ),
    );
  }

  String _formatLastSeen(dynamic lastSeen) {
    if (lastSeen is Timestamp) {
      final lastSeenTime = lastSeen.toDate();
      final now = DateTime.now();
      final difference = now.difference(lastSeenTime);

      if (difference.inMinutes < 1) return 'just now';
      if (difference.inMinutes < 60) return '${difference.inMinutes} min ago';
      if (difference.inHours < 24) return '${difference.inHours} hours ago';
      return DateFormat('MMM d').format(lastSeenTime);
    }
    return '';
  }

  void _showMoreOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_currentUserRole == 'company' &&
                widget.receiverRole == 'student')
              ListTile(
                leading: const Icon(Icons.person),
                title: const Text('View student profile'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _showStudentInfo = true;
                  });
                },
              ),
            ListTile(
              leading: const Icon(Icons.notifications),
              title: const Text('Mute notifications'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.block),
              title: const Text('Block user'),
              onTap: () {
                Navigator.pop(context);
                _showBlockConfirmation();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Delete conversation'),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation();
              },
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showBlockConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block user?'),
        content: Text(
          'You will no longer receive messages from ${widget.receiverName}.',
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
                SnackBar(
                  content: Text('${widget.receiverName} has been blocked'),
                ),
              );
            },
            child: const Text('Block', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete conversation?'),
        content: const Text(
          'This will delete the entire conversation history.',
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
                const SnackBar(content: Text('Conversation deleted')),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _typingIndicator(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundImage: widget.receiverAvatarUrl.isNotEmpty
                ? NetworkImage(widget.receiverAvatarUrl)
                : null,
            backgroundColor: widget.receiverAvatarUrl.isEmpty
                ? theme.colorScheme.surfaceVariant
                : null,
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: const [
                _Dot(delay: 0),
                _Dot(delay: 200),
                _Dot(delay: 400),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.dividerColor, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            PopupMenuButton<String>(
              icon: Icon(
                Icons.add,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'image',
                  child: Row(
                    children: [
                      Icon(Icons.photo_library),
                      SizedBox(width: 8),
                      Text('Photo & Video'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'camera',
                  child: Row(
                    children: [
                      Icon(Icons.camera_alt),
                      SizedBox(width: 8),
                      Text('Camera'),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'image') {
                  _pickImage();
                } else if (value == 'camera') {
                  _takePhoto();
                }
              },
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                minLines: 1,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: "Type a message...",
                  border: InputBorder.none,
                  filled: true,
                  fillColor: theme.inputDecorationTheme.fillColor,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  isDense: true,
                ),
                onChanged: (text) {
                  // Typing indicators could be implemented here
                },
              ),
            ),
            IconButton(
              icon: Icon(
                _isSending ? Icons.hourglass_bottom : Icons.send,
                color: _isSending
                    ? theme.colorScheme.onSurface.withOpacity(0.3)
                    : theme.colorScheme.primary,
              ),
              onPressed: _isSending ? null : _sendMessage,
            ),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  final int delay;

  const _Dot({required this.delay});

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 900),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            _controller.reverse();
          } else if (status == AnimationStatus.dismissed) {
            _controller.forward();
          }
        });

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
