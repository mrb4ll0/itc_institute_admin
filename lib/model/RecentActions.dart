import 'package:cloud_firestore/cloud_firestore.dart';

class RecentAction {
  String id;
  String userId;
  String userName;
  String userEmail;
  String userRole; // 'admin', 'company', 'student'
  String
  actionType; // 'created', 'updated', 'deleted', 'approved', 'rejected', 'viewed'
  String
  entityType; // 'student', 'company', 'application', 'training', 'document'
  String entityId;
  String entityName;
  String description;
  Map<String, dynamic>? changes; // Track what was changed
  Map<String, dynamic>? metadata;
  DateTime timestamp;
  String ipAddress;
  String userAgent;

  RecentAction({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.userRole,
    required this.actionType,
    required this.entityType,
    required this.entityId,
    required this.entityName,
    required this.description,
    this.changes,
    this.metadata,
    required this.timestamp,
    this.ipAddress = '',
    this.userAgent = '',
  });

  factory RecentAction.fromFirestore(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>? ?? {};
    return RecentAction(
      id: snapshot.id,
      userId: data['userId']?.toString() ?? '',
      userName: data['userName']?.toString() ?? '',
      userEmail: data['userEmail']?.toString() ?? '',
      userRole: data['userRole']?.toString() ?? '',
      actionType: data['actionType']?.toString() ?? '',
      entityType: data['entityType']?.toString() ?? '',
      entityId: data['entityId']?.toString() ?? '',
      entityName: data['entityName']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      changes: data['changes'] is Map
          ? Map<String, dynamic>.from(data['changes'] as Map)
          : null,
      metadata: data['metadata'] is Map
          ? Map<String, dynamic>.from(data['metadata'] as Map)
          : null,
      timestamp: data['timestamp'] is Timestamp
          ? (data['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      ipAddress: data['ipAddress']?.toString() ?? '',
      userAgent: data['userAgent']?.toString() ?? '',
    );
  }
  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'userRole': userRole,
      'actionType': actionType,
      'entityType': entityType,
      'entityId': entityId,
      'entityName': entityName,
      'description': description,
      'changes': changes,
      'metadata': metadata,
      'timestamp': Timestamp.fromDate(timestamp),
      'ipAddress': ipAddress,
      'userAgent': userAgent,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  // Helper method to create action from map
  factory RecentAction.fromMap(Map<String, dynamic> map) {
    return RecentAction(
      id: map['id']?.toString() ?? '',
      userId: map['userId']?.toString() ?? '',
      userName: map['userName']?.toString() ?? '',
      userEmail: map['userEmail']?.toString() ?? '',
      userRole: map['userRole']?.toString() ?? '',
      actionType: map['actionType']?.toString() ?? '',
      entityType: map['entityType']?.toString() ?? '',
      entityId: map['entityId']?.toString() ?? '',
      entityName: map['entityName']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      changes: map['changes'] is Map
          ? Map<String, dynamic>.from(map['changes'] as Map)
          : null,
      metadata: map['metadata'] is Map
          ? Map<String, dynamic>.from(map['metadata'] as Map)
          : null,
      timestamp: map['timestamp'] is Timestamp
          ? (map['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      ipAddress: map['ipAddress']?.toString() ?? '',
      userAgent: map['userAgent']?.toString() ?? '',
    );
  }

  // Copy with method
  RecentAction copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userEmail,
    String? userRole,
    String? actionType,
    String? entityType,
    String? entityId,
    String? entityName,
    String? description,
    Map<String, dynamic>? changes,
    Map<String, dynamic>? metadata,
    DateTime? timestamp,
    String? ipAddress,
    String? userAgent,
  }) {
    return RecentAction(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      userRole: userRole ?? this.userRole,
      actionType: actionType ?? this.actionType,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      entityName: entityName ?? this.entityName,
      description: description ?? this.description,
      changes: changes ?? this.changes,
      metadata: metadata ?? this.metadata,
      timestamp: timestamp ?? this.timestamp,
      ipAddress: ipAddress ?? this.ipAddress,
      userAgent: userAgent ?? this.userAgent,
    );
  }

  // Helper methods
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return '$years year${years > 1 ? 's' : ''} ago';
    }
    if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '$months month${months > 1 ? 's' : ''} ago';
    }
    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    }
    if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    }
    if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    }
    return 'Just now';
  }

  String get formattedDate {
    return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
  }

  String get formattedTime {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }

  bool get hasChanges => changes != null && changes!.isNotEmpty;

  String get actionIcon {
    switch (actionType) {
      case 'created':
        return '📝';
      case 'updated':
        return '✏️';
      case 'deleted':
        return '🗑️';
      case 'approved':
        return '✅';
      case 'rejected':
        return '❌';
      case 'viewed':
        return '👁️';
      case 'downloaded':
        return '📥';
      case 'uploaded':
        return '📤';
      default:
        return '📋';
    }
  }

  String get entityIcon {
    switch (entityType) {
      case 'student':
        return '🎓';
      case 'company':
        return '🏢';
      case 'application':
        return '📄';
      case 'training':
        return '📚';
      case 'document':
        return '📑';
      case 'user':
        return '👤';
      case 'settings':
        return '⚙️';
      default:
        return '📋';
    }
  }

  // Get color based on action type
  String get actionColor {
    switch (actionType) {
      case 'created':
        return '#4CAF50'; // Green
      case 'updated':
        return '#2196F3'; // Blue
      case 'deleted':
        return '#F44336'; // Red
      case 'approved':
        return '#4CAF50'; // Green
      case 'rejected':
        return '#FF9800'; // Orange
      case 'viewed':
        return '#9C27B0'; // Purple
      default:
        return '#607D8B'; // Blue Grey
    }
  }

  // Predefined action creators
  factory RecentAction.studentCreated({
    required String userId,
    required String userName,
    required String userEmail,
    required String userRole,
    required String studentId,
    required String studentName,
    String ipAddress = '',
    String userAgent = '',
  }) {
    return RecentAction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: userId,
      userName: userName,
      userEmail: userEmail,
      userRole: userRole,
      actionType: 'created',
      entityType: 'student',
      entityId: studentId,
      entityName: studentName,
      description: 'Created new student account',
      timestamp: DateTime.now(),
      ipAddress: ipAddress,
      userAgent: userAgent,
    );
  }

  factory RecentAction.applicationApproved({
    required String userId,
    required String userName,
    required String userEmail,
    required String userRole,
    required String applicationId,
    required String studentName,
    required String companyName,
    String ipAddress = '',
    String userAgent = '',
  }) {
    return RecentAction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: userId,
      userName: userName,
      userEmail: userEmail,
      userRole: userRole,
      actionType: 'approved',
      entityType: 'application',
      entityId: applicationId,
      entityName: '$studentName → $companyName',
      description: 'Approved internship application',
      timestamp: DateTime.now(),
      ipAddress: ipAddress,
      userAgent: userAgent,
    );
  }

  factory RecentAction.companyUpdated({
    required String userId,
    required String userName,
    required String userEmail,
    required String userRole,
    required String companyId,
    required String companyName,
    Map<String, dynamic>? changes,
    String ipAddress = '',
    String userAgent = '',
  }) {
    return RecentAction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: userId,
      userName: userName,
      userEmail: userEmail,
      userRole: userRole,
      actionType: 'updated',
      entityType: 'company',
      entityId: companyId,
      entityName: companyName,
      description: 'Updated company information',
      changes: changes,
      timestamp: DateTime.now(),
      ipAddress: ipAddress,
      userAgent: userAgent,
    );
  }

  factory RecentAction.documentUploaded({
    required String userId,
    required String userName,
    required String userEmail,
    required String userRole,
    required String documentId,
    required String documentName,
    String ipAddress = '',
    String userAgent = '',
  }) {
    return RecentAction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: userId,
      userName: userName,
      userEmail: userEmail,
      userRole: userRole,
      actionType: 'uploaded',
      entityType: 'document',
      entityId: documentId,
      entityName: documentName,
      description: 'Uploaded new document',
      timestamp: DateTime.now(),
      ipAddress: ipAddress,
      userAgent: userAgent,
    );
  }

  factory RecentAction.login({
    required String userId,
    required String userName,
    required String userEmail,
    required String userRole,
    String ipAddress = '',
    String userAgent = '',
  }) {
    return RecentAction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: userId,
      userName: userName,
      userEmail: userEmail,
      userRole: userRole,
      actionType: 'login',
      entityType: 'user',
      entityId: userId,
      entityName: userName,
      description: 'User logged in',
      timestamp: DateTime.now(),
      ipAddress: ipAddress,
      userAgent: userAgent,
    );
  }

  factory RecentAction.logout({
    required String userId,
    required String userName,
    required String userEmail,
    required String userRole,
    String ipAddress = '',
    String userAgent = '',
  }) {
    return RecentAction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: userId,
      userName: userName,
      userEmail: userEmail,
      userRole: userRole,
      actionType: 'logout',
      entityType: 'user',
      entityId: userId,
      entityName: userName,
      description: 'User logged out',
      timestamp: DateTime.now(),
      ipAddress: ipAddress,
      userAgent: userAgent,
    );
  }
}
