// notificationDropDownService.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';

class NotificationDropdownService {
  static final NotificationDropdownService _instance = NotificationDropdownService._internal();
  factory NotificationDropdownService() => _instance;
  NotificationDropdownService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final BehaviorSubject<int> _unreadCountController = BehaviorSubject.seeded(0);
  Stream<int> get unreadCountStream => _unreadCountController.stream;
  int get currentUnreadCount => _unreadCountController.value;

  // Track if user has seen the dropdown on this session
  bool _hasShownDropdown = false;
  bool get hasShownDropdown => _hasShownDropdown;
  void markDropdownAsShown() => _hasShownDropdown = true;
  void resetDropdownShown() => _hasShownDropdown = false; // Add this to reset when new notifications arrive

  // Stream to trigger dropdown show
  final BehaviorSubject<bool> _showDropdownController = BehaviorSubject.seeded(false);
  Stream<bool> get showDropdownStream => _showDropdownController.stream;

  void triggerDropdown() {
    _showDropdownController.add(true);
  }

  void initialize(String studentUid) {
    // Listen to private notifications
    _firestore
        .collection('users')
        .doc('students')
        .collection('students')
        .doc(studentUid)
        .collection('notifications')
        .snapshots()
        .listen((snapshot) {
      _updateUnreadCount(studentUid);
      // Trigger dropdown when new notification arrives
      _checkForNewNotifications(snapshot);
    });

    // Listen to general notifications
    _firestore
        .collection('notifications')
        .snapshots()
        .listen((snapshot) {
      _updateUnreadCount(studentUid);
      // Check for new general notifications
      _checkForNewGeneralNotifications(snapshot, studentUid);
    });
  }

  void _checkForNewNotifications(QuerySnapshot snapshot) {
    // Check if there are new unread notifications
    final newUnread = snapshot.docs.where((doc) {
      final isRead = doc.data() as Map?;
      return isRead?['isRead'] == false;
    }).length;

    if (newUnread > 0 && !_hasShownDropdown) {
      triggerDropdown();
    }
  }

  void _checkForNewGeneralNotifications(QuerySnapshot snapshot, String studentUid) {
    // Check for new general notifications that user hasn't read
    final newNotifications = snapshot.docs.where((doc) {
      final data = doc.data() as Map;
      final readBy = data['readBy'] as List? ?? [];
      return !readBy.contains(studentUid);
    }).length;

    if (newNotifications > 0 && !_hasShownDropdown) {
      triggerDropdown();
    }
  }

  Future<void> _updateUnreadCount(String studentUid) async {
    try {
      final privateSnapshot = await _firestore
          .collection('users')
          .doc('students')
          .collection('students')
          .doc(studentUid)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .get();

      final generalSnapshot = await _firestore
          .collection('notifications')
          .get();

      int unreadGeneralCount = 0;
      for (var doc in generalSnapshot.docs) {
        final readBy = doc.data()['readBy'] as List? ?? [];
        if (!readBy.contains(studentUid)) {
          unreadGeneralCount++;
        }
      }

      final unreadCount = privateSnapshot.docs.length + unreadGeneralCount;
      _unreadCountController.add(unreadCount);
    } catch (e) {
      print('Error updating unread count: $e');
    }
  }

  void dispose() {
    _unreadCountController.close();
    _showDropdownController.close();
  }
}