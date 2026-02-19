import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import '../../../model/message.dart';
import '../../notification/notification_sender.dart';
import '../../notification/notitification_service.dart';
import '../general_cloud.dart';

class ChatService extends ChangeNotifier {
  final FirebaseFirestore _firebaseFirestore = FirebaseFirestore.instance;
  final NotificationSender _notificationSender = NotificationSender();
  late final ITCFirebaseLogic _itcFirebaseLogic ;

  String globalUserId = "";
  ChatService(String userId)
  {
    globalUserId = userId;
    _itcFirebaseLogic = ITCFirebaseLogic(globalUserId);
  }

  // GROUP CHAT LOGIC
  final CollectionReference groupsCollection = FirebaseFirestore.instance
      .collection('groups');

  Future<String> createGroup({
    required String name,
    required String createdBy,
    required List<String> members,
    List<String>? admins,
    String? description,
    String? avatarUrl,
  }) async {
    final groupDoc = await groupsCollection.add({
      'name': name,
      'createdBy': createdBy,
      'admins': admins ?? [createdBy],
      'members': [createdBy, ...members],
      'createdAt': FieldValue.serverTimestamp(),
      'avatarUrl': avatarUrl ?? '',
      'description': description ?? '',
    });
    return groupDoc.id;
  }

  Future<void> addGroupMember(String groupId, String userId) async {
    await groupsCollection.doc(groupId).update({
      'members': FieldValue.arrayUnion([userId]),
    });
  }

  Future<void> removeGroupMember(String groupId, String userId) async {
    await groupsCollection.doc(groupId).update({
      'members': FieldValue.arrayRemove([userId]),
      'admins': FieldValue.arrayRemove([userId]),
    });
  }

  Future<void> promoteToAdmin(String groupId, String userId) async {
    await groupsCollection.doc(groupId).update({
      'admins': FieldValue.arrayUnion([userId]),
    });
  }

  Future<void> demoteFromAdmin(String groupId, String userId) async {
    await groupsCollection.doc(groupId).update({
      'admins': FieldValue.arrayRemove([userId]),
    });
  }

  Stream<List<Map<String, dynamic>>> getUserGroups(String userId) {
    return groupsCollection
        .where('members', arrayContains: userId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => {...doc.data() as Map<String, dynamic>, 'id': doc.id},
              )
              .toList(),
        );
  }

  Stream<List<Map<String, dynamic>>> getGroupMessages(String groupId) {
    return groupsCollection
        .doc(groupId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            return data;
          }).toList(),
        );
  }

  Future<void> sendGroupMessage({
    required String groupId,
    required String senderId,
    required String content,
    String type = 'text',
    Map<String, dynamic>? extra,
  }) async {
    await groupsCollection.doc(groupId).collection('messages').add({
      'senderId': senderId,
      'content': content,
      'timestamp': FieldValue.serverTimestamp(),
      'type': type,
      ...?extra,
    });

    // Send push notification to all group members except sender
    final groupDoc = await groupsCollection.doc(groupId).get();
    final groupData = groupDoc.data() as Map<String, dynamic>?;
    if (groupData == null) return;
    final List members = groupData['members'] ?? [];
    final groupName = groupData['name'] ?? 'Group';

    // Fetch sender name
    String senderName = 'Someone';
    try {
      final user = await _itcFirebaseLogic.getUserById(senderId);
      if (user != null && user is dynamic && user.fullName != null) {
        senderName = user.fullName;
      }
    } catch (_) {}

    // Fetch device tokens for all members except sender
    final tokens = <String>[];
    for (final memberId in members) {
      if (memberId == senderId) continue;
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc('students')
          .collection('students')
          .doc(memberId)
          .get();
      final data = userDoc.data();
      if (data != null && data['deviceToken'] != null) {
        tokens.add(data['deviceToken']);
      }
    }
    if (tokens.isNotEmpty) {
      for (final token in tokens) {
        await NotificationService().sendNotificationToUser(
          fcmToken: token,
          title: groupName,
          body: '$senderName: $content',
          data: {'groupId': groupId},
        );
      }
    }
  }

  //SEND MESSAGE
  Future<void> sendMessage(
    String receiverID,
    String content, {
    Map<String, dynamic>? replyTo,
    required String body,
    required String type,
    required String title,
  }) async {
    final String currentUserId = globalUserId;

    List<String> chatID = [currentUserId, receiverID];
    chatID.sort();
    String chatRoomID = chatID.join('_');

    Message message = Message(
      senderId: currentUserId,
      receiverId: receiverID,
      content: content,
      timestamp: Timestamp.now(),
      isRead: false,
      replyTo: replyTo,
    );

    final messageMap = message.toMap();

    // Save the message
    await _firebaseFirestore
        .collection('chat_rooms')
        .doc(chatRoomID)
        .collection('messages')
        .add(messageMap);

    // Save/update the latest message and participants
    await _firebaseFirestore.collection('chat_rooms').doc(chatRoomID).set({
      'participants': [currentUserId, receiverID],
      'latest_message': messageMap,
       'receiver_id': receiverID,
      'lastUpdated': Timestamp.now(),
    }, SetOptions(merge: true));

    _notificationSender.sendNotification(receiverID, body, type, title);
  }

  Stream<QuerySnapshot> getMessages(String userId, String otherUserId) {
    List<String> ids = [userId, otherUserId];
    ids.sort();
    String chatRoomID = ids.join("_");

    return _firebaseFirestore
        .collection("chat_rooms")
        .doc(chatRoomID)
        .collection("messages")
        .orderBy("timestamp", descending: false)
        .snapshots();
  }

  Stream<List<Message>> getFilteredMessages(String userId, String otherUserId) {
    List<String> ids = [userId, otherUserId];
    ids.sort();
    String chatRoomID = ids.join("_");

    return _firebaseFirestore
        .collection("chat_rooms")
        .doc(chatRoomID)
        .collection("messages")
        .orderBy("timestamp", descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Message.fromMap(doc.data(), doc.id))
              .where(
                (msg) =>
                    msg.senderId.isNotEmpty &&
                    msg.receiverId.isNotEmpty &&
                    msg.content != null &&
                    msg.timestamp != null &&
                    (msg.replyTo == null ||
                        msg.replyTo is Map<String, dynamic>) &&
                    (!(msg.toMap()['deletedFor'] is List) ||
                        !(msg.toMap()['deletedFor'] as List).contains(userId)),
              )
              .toList(),
        );
  }

  Stream<List<Message>> getAllMessagesForCurrentUser() {
    debugPrint("getAllMessagesForCurrentUser called");
    final String? currentUserId = globalUserId;
    if (currentUserId == null) {
      throw Exception("User not logged in.");
    }

    var message =  _firebaseFirestore
        .collection('chat_rooms')
        .where('participants', arrayContains: currentUserId)
        .orderBy('lastUpdated', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) {
                final data = doc.data();
                final latestMessage = data['latest_message'];
                if (latestMessage == null) return null;
                final deletedFor = latestMessage['deletedFor'] as List?;
                if (deletedFor != null && deletedFor.contains(currentUserId)) {
                  return null;
                }
                return Message.fromMap(latestMessage, doc.id);
              })
              .whereType<Message>()
              .toList();
        });
    debugPrint("message size ${message.length}");
    return message;
  }

  // Inside ChatService
  Future<void> deleteMessage(
    String contactId,
    String currentUserId,
    String messageId,
  ) async {
    final chatId = getChatId(currentUserId, contactId);
    debugPrint("Chat ID: $chatId");

    final messageRef = _firebaseFirestore
        .collection('chat_rooms')
        .doc(chatId)
        .collection('messages')
        .doc(messageId);

    final messageDoc = await messageRef.get();

    if (!messageDoc.exists) {
      debugPrint("Message not found");
      return;
    }

    final messageData = messageDoc.data();
    final messageTimestamp = messageData?['timestamp'];

    // Delete the message
    await messageRef.delete();
    debugPrint("Message deleted");

    // Check if it's the latest message
    final chatRoomRef = _firebaseFirestore.collection('chat_rooms').doc(chatId);
    final chatRoomDoc = await chatRoomRef.get();

    if (chatRoomDoc.exists) {
      final latestMessage = chatRoomDoc.data()?['latest_message'];
      final latestTimestamp = latestMessage?['timestamp'];
      debugPrint(
        "latestMessage is $latestMessage and latestTimestamp is $latestTimestamp",
      );

      if (latestTimestamp != null && latestTimestamp == messageTimestamp) {
        debugPrint("Deleted message was the latest");

        // Fetch new latest message (next most recent)
        final newLatest = await _firebaseFirestore
            .collection('chat_rooms')
            .doc(chatId)
            .collection('messages')
            .orderBy('timestamp', descending: true)
            .limit(1)
            .get();

        if (newLatest.docs.isNotEmpty) {
          final newLatestData = newLatest.docs.first.data();
          await chatRoomRef.update({
            'latest_message': newLatestData,
            'lastUpdated': newLatestData['timestamp'],
          });
        } else {
          // No messages left
          await chatRoomRef.update({
            'latest_message': FieldValue.delete(),
            'lastUpdated': FieldValue.delete(),
          });
        }
      }
    }
  }

  // Helper to get chat ID (if you already have a chat ID generator, reuse it)
  String getChatId(String userId, String contactId) {
    final sorted = [userId, contactId]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  Future<void> sendImageMessage({required Message msg}) async {
    if (msg.imageUrl == null && msg.imageUrls == null) {
      print('sendImageMessage was called with null imageFile');
      return;
    }


    String receiverID = msg.receiverId;

    String imageUrl = msg.imageUrl??"", optionalText = msg.content;
    final String currentUserId = globalUserId;

    List<String> chatID = [currentUserId, receiverID];
    chatID.sort();
    String chatRoomID = chatID.join('_');

    Message message = Message(
      senderId: currentUserId,
      receiverId: receiverID,
      content: optionalText,
      imageUrl: imageUrl,
      timestamp: Timestamp.now(),
      isRead: false,
      imageUrls: msg.imageUrls
    );
    debugPrint("message name is ${message.content}");

    final messageMap = message.toMap();

    // Save the message
    await _firebaseFirestore
        .collection('chat_rooms')
        .doc(chatRoomID)
        .collection('messages')
        .add(messageMap);

    // Save/update the latest message and participants
    await _firebaseFirestore.collection('chat_rooms').doc(chatRoomID).set({
      'participants': [currentUserId, receiverID],
      'latest_message': messageMap,
      'receiver_id': receiverID,
      'lastUpdated': Timestamp.now(),
    }, SetOptions(merge: true));
  }

  // Method to get latest message data with both content and receiver_id
  Future<Map<String, dynamic>?> getLatestMessageData(
    String userId,
    String contactId,
  ) async {
    try {
      final chatId = getChatId(userId, contactId);

      final chatDoc = await _firebaseFirestore
          .collection('chat_rooms')
          .doc(chatId)
          .get();

      if (!chatDoc.exists) {
        return null;
      }

      final data = chatDoc.data();
      if (data == null || data['latest_message'] == null) {
        return null;
      }

      final latestMessage = data['latest_message'] as Map<String, dynamic>;

      // Extract both content and receiver_id
       String? content = latestMessage['content'] as String?;
      final String? senderId = latestMessage['sender_id'] as String?;
      final String receiverId = data['receiver_id'];

      if (content == null && receiverId == null) {
        return null;
      }

     content = determineContent(latestMessage);
      debugPrint("content now is ${content}");

      return {
        'content': content,
        'receiver_id': receiverId,
        'sender_id': latestMessage['sender_id'] as String?,
        'timestamp': latestMessage['timestamp'],
        'is_read': latestMessage['isRead'] as bool? ?? false,

      };
    } catch (e) {
      print('Error getting latest message data: $e');
      return null;
    }
  }
  String determineContent(Map<String, dynamic> lastMessage) {
    // Check if it has multiple images
    if (lastMessage['imageUrls'] is List &&
        (lastMessage['imageUrls'] as List).isNotEmpty) {
      final imageCount = (lastMessage['imageUrls'] as List).length;
      if (imageCount == 1) {
        return '📷 Photo';
      } else {
        return '📷 $imageCount Photos';
      }
    }

    // Check if it has single image
    if (lastMessage['imageUrl'] is String &&
        (lastMessage['imageUrl'] as String).isNotEmpty) {
      return '📷 Photo';
    }

    // Check if it has reply
    if (lastMessage['replyTo'] is Map &&
        (lastMessage['replyTo'] as Map).isNotEmpty) {
      final repliedContent = lastMessage['replyTo']['content'] ?? '';
      if (repliedContent.isNotEmpty) {
        return '↪️ ${repliedContent.length > 30 ? '${repliedContent.substring(0, 30)}...' : repliedContent}';
      }
      return '↪️ Replied to a message';
    }

    // Check if it has regular text content
    final content = lastMessage['content'] as String? ?? '';
    if (content.isNotEmpty) {
      return content.length > 40 ? '${content.substring(0, 40)}...' : content;
    }

    // Fallback for empty messages
    return 'No message yet';
  }  // Stream version for real-time updates
  // In ChatService class, modify this method:
  Stream<Map<String, dynamic>?> getLatestMessageDataStream(
    String userId,
    String contactId,
  ) {
    final chatId = getChatId(userId, contactId);

    return _firebaseFirestore
        .collection('chat_rooms')
        .doc(chatId)
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists) return null;

          final data = snapshot.data();
          if (data == null || data['latest_message'] == null) {
            return null;
          }

          final latestMessage = data['latest_message'] as Map<String, dynamic>;

          return {
            'contactId': contactId, // Add this to identify which chat
            'content': determineContent(latestMessage),
            'receiver_id': data['receiver_id'] as String?,
            'sender_id': latestMessage['sender_id'] as String?,
            'timestamp': latestMessage['timestamp'],
            'is_read': latestMessage['isRead'] as bool? ?? false,
          };
        });
  }

  // Method to get latest message content with receiver info
  Future<Map<String, String>> getLatestMessageWithReceiver(
    String userId,
    String contactId,
  ) async {
    try {
      final data = await getLatestMessageData(userId, contactId);

      if (data == null) {
        return {
          'content': 'Tap to start conversation',
          'receiver_id': contactId,
          'type': 'default',
        };
      }

      return {
        'content': data['content'] as String? ?? 'Tap to start conversation',
        'receiver_id': data['receiver_id'] as String? ?? contactId,
        'sender_id': data['sender_id'] as String? ?? '',
        'type': data['content'] != null ? 'actual' : 'default',
      };
    } catch (e) {
      print('Error getting message with receiver: $e');
      return {
        'content': 'Start a conversation',
        'receiver_id': contactId,
        'type': 'error',
      };
    }
  }

  // Add this to your ChatService for checking message direction
  Future<bool> wasMessageSentToMe(String userId, String contactId) async {
    try {
      final data = await getLatestMessageData(userId, contactId);

      if (data == null) return false;

      final String? receiverId = data['receiver_id'] as String?;
      return receiverId == userId; // True if I was the receiver
    } catch (e) {
      print('Error checking message direction: $e');
      return false;
    }
  }

  // Get formatted last message with indication of direction
  Future<String> getFormattedLastMessageWithDirection(
    String userId,
    String contactId,
  ) async {
    try {
      final data = await getLatestMessageData(userId, contactId);

      if (data == null) {
        return 'Tap to start conversation';
      }

      final String? content = data['content'] as String?;
      if (content == null) {
        return 'Tap to start conversation';
      }

      final String? senderId = data['sender_id'] as String?;
      final String? receiverId = data['receiver_id'] as String?;

      // Check if I sent this message
      if (senderId == userId) {
        return 'You: ${_truncateMessage(content)}';
      }
      // Check if message was sent to me
      else if (receiverId == userId) {
        return _truncateMessage(content);
      }
      // Message between other users (in group chats maybe)
      else {
        return _truncateMessage(content);
      }
    } catch (e) {
      return 'Start a conversation';
    }
  }

  String _truncateMessage(String message) {
    if (message.length <= 30) return message;
    return '${message.substring(0, 30)}...';
  }

  // Mark all unread messages from a specific sender as read
  // Add this to your ChatService class
  Future<void> updateLatestMessageAsRead(
    String currentUserId,
    String contactId,
  ) async {
    try {
      final chatId = getChatId(currentUserId, contactId);

      final chatDoc = await _firebaseFirestore
          .collection('chat_rooms')
          .doc(chatId)
          .get();

      if (!chatDoc.exists) return;

      final data = chatDoc.data();
      if (data == null || data['latest_message'] == null) return;

      final latestMessage = data['latest_message'] as Map<String, dynamic>;

      // Check if the latest message is from the other person and unread
      debugPrint(
        "senderId ${contactId} lms sender_id is ${latestMessage['sender_id']}",
      );
      if (latestMessage['sender_id'] == contactId &&
          (latestMessage['is_read'] as bool? ?? false) == false) {
        // Update the is_read field in latest_message
        await _firebaseFirestore.collection('chat_rooms').doc(chatId).update({
          'latest_message.is_read': true,
          'latest_message.read_at':
              FieldValue.serverTimestamp(), // Add read_at timestamp
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }
      debugPrint("Message marked as read");
    } catch (e, s) {
      debugPrint('Error updating latest message as read: $e');
      debugPrintStack(stackTrace: s);
    }
  }
}
