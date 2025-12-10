import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';

import '../../../model/message.dart';
import '../../notification/notification_sender.dart';
import '../../notification/notitification_service.dart';
import '../general_cloud.dart';

class ChatService extends ChangeNotifier {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firebaseFirestore = FirebaseFirestore.instance;
  final NotificationSender _notificationSender = NotificationSender();
  final ITCFirebaseLogic _itcFirebaseLogic = ITCFirebaseLogic();

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
  }) async {
    final String currentUserId = _firebaseAuth.currentUser!.uid;

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
      'lastUpdated': Timestamp.now(),
    }, SetOptions(merge: true));

    _notificationSender.sendNotification(
      receiverID,
      "Message",
      "message",
      "New Notification",
    );
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
    final String? currentUserId = _firebaseAuth.currentUser?.uid;
    if (currentUserId == null) {
      throw Exception("User not logged in.");
    }

    return _firebaseFirestore
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
  }

  // Inside ChatService
  Future<void> deleteMessage(
    String contactId,
    String currentUserId,
    String messageId,
  ) async {
    final chatId = _getChatId(currentUserId, contactId);
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
  String _getChatId(String userId, String contactId) {
    final sorted = [userId, contactId]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  Future<void> sendImageMessage({required Message msg}) async {
    if (msg.imageUrl == null) {
      print('sendImageMessage was called with null imageFile');
      return;
    }
    String receiverID = msg.receiverId;
    String imageUrl = msg.imageUrl!, optionalText = msg.content;
    final String currentUserId = _firebaseAuth.currentUser!.uid;

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
      'lastUpdated': Timestamp.now(),
    }, SetOptions(merge: true));
  }
}
