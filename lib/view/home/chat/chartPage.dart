import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:itc_institute_admin/firebase_cloud_storage/firebase_cloud.dart';
import 'package:itc_institute_admin/generalmethods/GeneralMethods.dart';
import 'package:itc_institute_admin/itc_logic/firebase/general_cloud.dart';
import 'package:itc_institute_admin/model/authorityCompanyMapper.dart';
import 'package:itc_institute_admin/model/userProfile.dart';
import 'package:itc_institute_admin/view/home/industrailTraining/fileDetails.dart';
import 'package:itc_institute_admin/view/home/student/studentDetails.dart';

import '../../../itc_logic/firebase/message/message_service.dart';
import '../../../itc_logic/service/userService.dart';
import '../../../model/admin.dart';
import '../../../model/authority.dart';
import '../../../model/company.dart';
import '../../../model/message.dart';
import '../../../model/student.dart';
import '../../adminProfilePage.dart';
import '../../company/companyDetailPage.dart';

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
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  late ChatService _chatService = ChatService(FirebaseAuth.instance.currentUser!.uid);
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
  late Company? _company;
  ITCFirebaseLogic itcFirebaseLogic = ITCFirebaseLogic(FirebaseAuth.instance.currentUser!.uid);
  int? _previousMessageCount;
  bool _showScrollToBottomButton = false;
  Timestamp? previousDate;


  @override
  void initState() {
    super.initState();
    _receiverData = widget.receiverData;
    _initializeChat();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupKeyboardListener();
      _markMessagesAsRead();
    });
  }


  _loadUser() async {

  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }



  bool get _isAtBottom {
    if (!_scrollController.hasClients) return true;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;

    // If maxScroll is 0, we're at bottom (empty list)
    if (maxScroll == 0) return true;

    // Check if we're within 50 pixels of the bottom
    return (maxScroll - currentScroll) <= 50;
  }
  
  Widget _buildScrollToBottomButton(ThemeData theme) {
    if (!_showScrollToBottomButton) return const SizedBox.shrink();

    return Positioned(
      bottom: 80, // Position above the input bar
      right: 16,
      child: GestureDetector(
        onTap: _scrollToBottom,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            Icons.arrow_downward,
            color: theme.colorScheme.onPrimary,
            size: 20,
          ),
        ),
      ),
    );
  }

  Future<void> _markMessagesAsRead() async {
    if (_currentUserId == null) return;

    try {
      await _chatService.updateLatestMessageAsRead(
        _currentUserId!,
        widget.receiverId,
      );
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
    }
  }




  void _setupKeyboardListener() {
    // Listen for keyboard visibility changes
    KeyboardVisibilityController().onChange.listen((bool visible) {
      if (visible) {
        // Wait a bit for keyboard to fully appear, then scroll
        Future.delayed(const Duration(milliseconds: 100), () {
          _scrollToBottom();
        });
      }
    });
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

      _chatService = ChatService(FirebaseAuth.instance.currentUser!.uid);
      _messagesStream = _chatService.getFilteredMessages(
        _currentUserId!,
        widget.receiverId,
      );

      setState(() {
        _isLoading = false;
      });
      _company = await itcFirebaseLogic.getCompany(
        FirebaseAuth.instance.currentUser!.uid,
      );
      if(_company == null)
        {
          Authority? authority = await itcFirebaseLogic.getAuthority(FirebaseAuth.instance.currentUser!.uid);
          if(authority != null)
            {
              _company = AuthorityCompanyMapper.createCompanyFromAuthority(authority: authority);
            }
        }
      // Scroll to bottom after messages load
      _scrollToBottomOnMessagesLoad();
    }
  }

  void _scrollToBottomOnMessagesLoad() {
    // Listen to the stream and scroll when data is available
    _messagesStream.first.then((_) {
      if (mounted) {
        // Small delay to ensure UI is built
        Future.delayed(const Duration(milliseconds: 300), () {
          _scrollToBottom();
        });
      }
    });
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
        List<String> imageUrls = await FirebaseUploader().uploadMultipleFiles(_selectedImages,FirebaseAuth.instance.currentUser!.uid, "chatImage");

        final message = Message(
          senderId: _currentUserId!,
          receiverId: widget.receiverId,
          content: _messageController.text,
          timestamp: Timestamp.now(),
          isRead: false,
          imageUrls: imageUrls, // imageUrl after upload
        );

        await _chatService.sendImageMessage(msg: message);
        _selectedImages.clear();
      } else {
        await _chatService.sendMessage(
          widget.receiverId,
          _messageController.text.trim(),
          body: _messageController.text.trim(),
          type: "message",
          title: _company?.name ?? "Company__",
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



  // Simplified _buildMessageBubble without date header logic
  Widget _buildMessageBubble(
      Message message,
      ThemeData theme,
      {
        Message? previousMessage,
        bool isFirstMessageOfDay = false,
      }
      ) {
    final isMe = message.senderId == _currentUserId;
    final time = DateFormat('h:mm a').format(message.timestamp.toDate());

    // Get images
    final List<String> images = [];
    if (message.imageUrls != null && message.imageUrls!.isNotEmpty) {
      images.addAll(message.imageUrls!);
    } else if (message.imageUrl != null && message.imageUrl!.isNotEmpty) {
      images.add(message.imageUrl!);
    }

    final bool hasImages = images.isNotEmpty;
    final bool contentIsImageUrl = hasImages &&
        GeneralMethods.contentIsOnlyImageUrl(message.content, images);

    // Check if we should show avatar/name
    final shouldShowAvatar = !isMe && (
        previousMessage == null ||
            previousMessage.senderId != message.senderId ||
            !_isSameDay(previousMessage.timestamp, message.timestamp) ||
            _timeDifferenceInMinutes(previousMessage.timestamp, message.timestamp) > 5
    );

    final shouldShowName = !isMe && (
        previousMessage == null ||
            previousMessage.senderId != message.senderId ||
            !_isSameDay(previousMessage.timestamp, message.timestamp)
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: GestureDetector(
        onLongPress: () => _showMessageOptions(message),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (!isMe && shouldShowAvatar)
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
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!isMe && shouldShowName)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2.0, left: 8.0),
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
                    padding: hasImages
                        ? const EdgeInsets.all(8)
                        : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isMe ? theme.colorScheme.primary : theme.colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (hasImages)
                          _ImagePreviewCard(
                            images: images,
                            isMe: isMe,
                            theme: theme,
                            onViewImage: (imageUrl) {
                              GeneralMethods.navigateTo(
                                context,
                                FullScreenViewer(firebasePath: imageUrl),
                              );
                            },
                            onViewGallery: () {
                              _openImageGallery(message, images);
                            },
                          ),

                        if (!contentIsImageUrl && message.content.isNotEmpty)
                          Column(
                            children: [
                              if (hasImages) const SizedBox(height: 8),
                              Text(
                                message.content,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: isMe
                                      ? theme.colorScheme.onPrimary
                                      : theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),

                        if (message.replyTo != null)
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? theme.colorScheme.primary.withOpacity(0.3)
                                  : theme.colorScheme.surfaceVariant.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isMe
                                    ? theme.colorScheme.primary.withOpacity(0.5)
                                    : theme.colorScheme.outline.withOpacity(0.5),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Replying to',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: isMe
                                        ? theme.colorScheme.onPrimary.withOpacity(0.8)
                                        : theme.colorScheme.onSurfaceVariant.withOpacity(0.8),
                                  ),
                                ),
                                Text(
                                  message.replyTo?['content'] ?? '',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: isMe
                                        ? theme.colorScheme.onPrimary
                                        : theme.colorScheme.onSurfaceVariant,
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
                    mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                    children: [
                      Text(
                        time,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.done_all ,
                          size: 12,
                          color: message.isRead
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface.withOpacity(0.6),
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
    );
  }

// Helper methods
  Widget _buildDateHeader(DateTime date, ThemeData theme) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);

    String dateText;
    if (messageDate == today) {
      dateText = 'Today';
    } else if (messageDate == yesterday) {
      dateText = 'Yesterday';
    } else {
      dateText = DateFormat('EEEE, MMMM d').format(date);
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            dateText,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  // Update your _isSameDay method to handle both DateTime and Timestamp
  bool _isSameDay(dynamic date1, dynamic date2) {
    DateTime dateTime1, dateTime2;

    // Convert Timestamp to DateTime if needed
    if (date1 is Timestamp) {
      dateTime1 = date1.toDate();
    } else if (date1 is DateTime) {
      dateTime1 = date1;
    } else {
      return false;
    }

    if (date2 is Timestamp) {
      dateTime2 = date2.toDate();
    } else if (date2 is DateTime) {
      dateTime2 = date2;
    } else {
      return false;
    }

    return dateTime1.year == dateTime2.year &&
        dateTime1.month == dateTime2.month &&
        dateTime1.day == dateTime2.day;
  }

// Or create separate methods for clarity
  bool _isSameDayTimestamp(Timestamp timestamp1, Timestamp timestamp2) {
    final date1 = timestamp1.toDate();
    final date2 = timestamp2.toDate();
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  bool _isSameDayDateTime(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }
  Widget _buildEmptyMessage(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Simple icon
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: theme.colorScheme.onSurface.withOpacity(0.3),
            ),

            const SizedBox(height: 16),

            // Title
            Text(
              'No messages yet',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),

            const SizedBox(height: 8),

            // Description
            Text(
              'Start a conversation with ${widget.receiverName}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 24),

            // Simple send button
            ElevatedButton.icon(
              onPressed: () {
                _messageController.text = "Hello! How can I help you today?";
                FocusScope.of(context).requestFocus(_focusNode);
              },
              icon: const Icon(Icons.send, size: 18),
              label: const Text('Send first message'),
            ),
          ],
        ),
      ),
    );
  }

  int _timeDifferenceInMinutes(Timestamp timestamp1, Timestamp timestamp2) {
    final date1 = timestamp1.toDate();
    final date2 = timestamp2.toDate();
    final difference = date1.difference(date2).abs();
    return difference.inMinutes;
  }

// Helper method to open image gallery
  void _openImageGallery(Message message, List<String> images, {int initialIndex = 0}) {

    GeneralMethods.navigateTo(
      context,
      FullScreenViewer(
        firebasePaths: images,
        initialIndex: initialIndex,
      ),
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
                  debugPrint("snapshot error ${snapshot.error}");
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!;

                // Handle empty state
                if (messages.isEmpty) {
                  return const Center(child: Text('No messages yet'));

                }


                // Create a list with date headers
                final List<Widget> messageWidgets = [];

                // Add typing indicator if needed
                if (_isTyping) {
                  messageWidgets.add(_typingIndicator(theme));
                }

                // Track the last date to show headers
                DateTime? lastDate;

                for (int i = 0; i < messages.length; i++) {
                  final message = messages[i];
                  final messageDate = message.timestamp.toDate();
                  final currentDate = DateTime(
                    messageDate.year,
                    messageDate.month,
                    messageDate.day,
                  );

                  // Check if we need a date header
                  if (lastDate == null || !_isSameDay(lastDate, currentDate)) {
                    messageWidgets.add(_buildDateHeader(currentDate, theme));
                    lastDate = currentDate;
                  }

                  // Get previous message for avatar logic
                  final previousMessage = i > 0 ? messages[i - 1] : null;

                  messageWidgets.add(
                    _buildMessageBubble(
                      message,
                      theme,
                      previousMessage: previousMessage,
                      isFirstMessageOfDay: lastDate == currentDate,
                    ),
                  );
                }

                // Scroll logic...
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    final hasNewMessages = _previousMessageCount != null &&
                        messages.length > _previousMessageCount!;

                    if (hasNewMessages ||
                        _scrollController.offset >=
                            _scrollController.position.maxScrollExtent - 100) {
                      _scrollToBottom();
                    }

                    _previousMessageCount = messages.length;
                  }
                });

                return Stack(
                  children: [
                    ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: messageWidgets.length,
                      itemBuilder: (context, index) {
                        return messageWidgets[index];
                      },
                    ),
                    _buildScrollToBottomButton(theme),
                  ],
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
                onTap: () async {
                  final user =
                      await UserService().getUser(widget.receiverId);
                  if(user == null)
                  {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('User not found.')),
                    );
                  }
                  Student? student = user!.getAs<Student>();
                  Company? company = user!.getAs<Company>();
                  Admin? admin = user.getAs<Admin>();
                  if (student != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StudentProfilePage(
                          student: student,
                        ),
                      ),
                    );
                  }
                  else if(company != null &&_company != null)
                  {
                    GeneralMethods.navigateTo(context, CompanyDetailPage(company: company, user: UserConverter(_company),));
                  }
                  else if(admin != null)
                  {
                   // GeneralMethods.navigateTo(context, AdminProfilePage(admin: admin,currentStudent: widget.,));
                  }
                  else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('Profile not found or not a student.')),
                    );
                  }
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.receiverId.startsWith("admin_")?"${widget.receiverName.split(" ").first} ITC Rep":widget.receiverName,
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
                  GeneralMethods.navigateTo(
                    context,
                    StudentProfilePage(student: widget.receiverData as Student),
                  );
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
                focusNode: _focusNode,
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

class _ImagePreviewCard extends StatefulWidget {
  final List<String> images;
  final bool isMe;
  final ThemeData theme;
  final Function(String) onViewImage;
  final VoidCallback onViewGallery;

  const _ImagePreviewCard({
    required this.images,
    required this.isMe,
    required this.theme,
    required this.onViewImage,
    required this.onViewGallery,
  });

  @override
  State<_ImagePreviewCard> createState() => _ImagePreviewCardState();
}

class _ImagePreviewCardState extends State<_ImagePreviewCard> {
  final Map<String, bool> _loadedImages = {};
  bool _showAllImages = false;

  @override
  Widget build(BuildContext context) {
    final bool isSingleImage = widget.images.length == 1;
    final bool showViewAll = widget.images.length > 4 && !_showAllImages;
    final displayCount = showViewAll ? 5 : widget.images.length;

    return Column(
      children: [
        // Header showing image count
        Row(
          children: [
            Icon(
              Icons.image,
              size: 16,
              color: widget.isMe
                  ? widget.theme.colorScheme.onPrimary.withOpacity(0.8)
                  : widget.theme.colorScheme.onSurfaceVariant.withOpacity(0.8),
            ),
            const SizedBox(width: 6),
            Text(
              '${widget.images.length} photo${widget.images.length > 1 ? 's' : ''}',
              style: widget.theme.textTheme.labelSmall?.copyWith(
                color: widget.isMe
                    ? widget.theme.colorScheme.onPrimary.withOpacity(0.8)
                    : widget.theme.colorScheme.onSurfaceVariant.withOpacity(0.8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Grid of image previews
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
            childAspectRatio: 1,
          ),
          itemCount: displayCount,
          itemBuilder: (context, index) {
            // "View All" button for multiple images
            if (showViewAll && index == 4) {
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _showAllImages = true;
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: widget.theme.colorScheme.surface.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: widget.isMe
                          ? widget.theme.colorScheme.primary.withOpacity(0.3)
                          : widget.theme.colorScheme.outline.withOpacity(0.3),
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '+${widget.images.length - 4}',
                          style: widget.theme.textTheme.titleLarge?.copyWith(
                            color: widget.isMe
                                ? widget.theme.colorScheme.onPrimary
                                : widget.theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'View All',
                          style: widget.theme.textTheme.labelSmall?.copyWith(
                            color: widget.isMe
                                ? widget.theme.colorScheme.onPrimary.withOpacity(0.8)
                                : widget.theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            final imageUrl = widget.images[index];
            final isLoaded = _loadedImages[imageUrl] ?? false;

            return GestureDetector(
              onTap: () {
                if (isSingleImage) {
                  widget.onViewImage(imageUrl);
                } else {
                  widget.onViewGallery();
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  color: widget.isMe
                      ? widget.theme.colorScheme.primary.withOpacity(0.2)
                      : widget.theme.colorScheme.surfaceVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: widget.isMe
                        ? widget.theme.colorScheme.primary.withOpacity(0.3)
                        : widget.theme.colorScheme.outline.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Show image if loaded
                    if (isLoaded)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                        ),
                      ),

                    // Preview overlay with icon
                    Container(
                      decoration: BoxDecoration(
                        color: isLoaded
                            ? Colors.black.withOpacity(0.2)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Show different icons based on state
                            if (!isLoaded)
                              Icon(
                                Icons.download,
                                size: 24,
                                color: widget.isMe
                                    ? widget.theme.colorScheme.onPrimary
                                    : widget.theme.colorScheme.primary,
                              ),
                            if (isLoaded)
                              Icon(
                                Icons.remove_red_eye,
                                size: 24,
                                color: widget.isMe
                                    ? widget.theme.colorScheme.onPrimary
                                    : Colors.white,
                              ),

                            const SizedBox(height: 4),

                            if (!isLoaded)
                              Text(
                                'Tap to load',
                                style: widget.theme.textTheme.labelSmall?.copyWith(
                                  color: widget.isMe
                                      ? widget.theme.colorScheme.onPrimary
                                      : widget.theme.colorScheme.primary,
                                ),
                              ),
                            if (isLoaded)
                              Text(
                                'Tap to view',
                                style: widget.theme.textTheme.labelSmall?.copyWith(
                                  color: widget.isMe
                                      ? widget.theme.colorScheme.onPrimary
                                      : Colors.white,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    // Load button in corner
                    if (!isLoaded)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _loadImage(imageUrl),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: widget.isMe
                                  ? widget.theme.colorScheme.primary
                                  : widget.theme.colorScheme.surface,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.download,
                              size: 14,
                              color: widget.isMe
                                  ? widget.theme.colorScheme.onPrimary
                                  : widget.theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),

        // Action buttons
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Download all images
                    _downloadAllImages(widget.images);
                  },
                  icon: Icon(
                    Icons.download,
                    size: 16,
                    color: widget.isMe
                        ? widget.theme.colorScheme.onPrimary
                        : widget.theme.colorScheme.primary,
                  ),
                  label: Text(
                    'Download All',
                    style: widget.theme.textTheme.labelSmall?.copyWith(
                      color: widget.isMe
                          ? widget.theme.colorScheme.onPrimary
                          : widget.theme.colorScheme.primary,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.isMe
                        ? widget.theme.colorScheme.primary.withOpacity(0.3)
                        : widget.theme.colorScheme.surfaceVariant,
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                    minimumSize: const Size(0, 30),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if(widget.images.length >1)
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: widget.onViewGallery,
                  icon: Icon(
                    Icons.remove_red_eye,
                    size: 16,
                    color: widget.isMe
                        ? widget.theme.colorScheme.onPrimary
                        : widget.theme.colorScheme.primary,
                  ),
                  label: Text(
                    'View Gallery',
                    style: widget.theme.textTheme.labelSmall?.copyWith(
                      color: widget.isMe
                          ? widget.theme.colorScheme.onPrimary
                          : widget.theme.colorScheme.primary,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.isMe
                        ? widget.theme.colorScheme.primary.withOpacity(0.3)
                        : widget.theme.colorScheme.surfaceVariant,
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                    minimumSize: const Size(0, 30),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _loadImage(String imageUrl) async {
    // Pre-cache the image
    try {
      final image = NetworkImage(imageUrl);
      await precacheImage(image, context);

      setState(() {
        _loadedImages[imageUrl] = true;
      });
    } catch (e) {
      // Show error snackbar or handle error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _downloadAllImages(List<String> images) async {
    // Implement download logic here
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Downloading ${images.length} images...'),
      ),
    );

    // Load all images
    for (final imageUrl in images) {
      if (!_loadedImages.containsKey(imageUrl) || !_loadedImages[imageUrl]!) {
        _loadImage(imageUrl);
      }
    }
  }
}