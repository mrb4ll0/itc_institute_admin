// Action Logger Service
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';

import '../../model/RecentActions.dart';

class ActionLogger {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get company-specific actions collection reference
  CollectionReference _getCompanyActionsRef(String companyId,{bool isAuthority = false}) {
    return !isAuthority?_firestore
        .collection('users')
        .doc('companies')
        .collection('companies')
        .doc(companyId)
        .collection('recentActions'):
    _firestore
        .collection('users')
        .doc('authorities')
        .collection('authorities')
        .doc(companyId)
        .collection('recentActions')
    ;
  }

  // Generate a unique document ID for actions
  String _generateActionId(RecentAction action) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = DateTime.now().microsecondsSinceEpoch % 10000;
    return '${action.userId}_${timestamp}_$random';
  }

  // Log an action to company-specific collection
  Future<void> logAction(
    RecentAction action, {
    required String companyId,
     required bool isAuthority ,
  }) async {
    try {
      final actionsRef = _getCompanyActionsRef(companyId,isAuthority: isAuthority);
      final actionId = _generateActionId(action);

      // Add companyId to the action metadata
      final actionData = action.toFirestore();
      actionData['companyId'] = companyId;

      await actionsRef.doc(actionId).set(actionData);

      print(
        '✅ Action logged for company $companyId: ${action.actionType} - ${action.entityType}',
      );
    } catch (e) {
      print('❌ Error logging action for company $companyId: $e');
      rethrow;
    }
  }

  // Log multiple actions to company collection
  Future<void> logActions(
    List<RecentAction> actions, {
    required String companyId,
        required bool isAuthority ,
  }) async {
    try {
      final actionsRef = _getCompanyActionsRef(companyId,isAuthority: isAuthority);
      final batch = _firestore.batch();

      for (final action in actions) {
        final actionId = _generateActionId(action);
        final actionData = action.toFirestore();
        actionData['companyId'] = companyId;

        final docRef = actionsRef.doc(actionId);
        batch.set(docRef, actionData);
      }

      await batch.commit();
      print('✅ Batch logged ${actions.length} actions for company $companyId');
    } catch (e) {
      print('❌ Error logging batch actions for company $companyId: $e');
      rethrow;
    }
  }

  // Stream company-specific recent actions
  Stream<List<RecentAction>> streamCompanyActions(
    String companyId, {
    int limit = 5,
        required bool isAuthority ,
  }) {
    final actionsRef = _getCompanyActionsRef(companyId,isAuthority: isAuthority);

    return actionsRef
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => RecentAction.fromFirestore(doc))
              .toList(),
        );
  }

  Stream<List<RecentAction>> streamCompanyActionsPaginated(
      String companyId, {
        int pageSize = 20,
        DocumentSnapshot? lastDocument,
        required bool isAuthority,
      }) {
    try {
      final actionsRef = _getCompanyActionsRef(companyId,isAuthority: isAuthority);

      Query query = actionsRef
          .orderBy('timestamp', descending: true)
          .limit(pageSize);

      // Apply pagination if we have a last document
      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      return query.snapshots().map(
            (snapshot) => snapshot.docs
            .map((doc) => RecentAction.fromFirestore(doc))
            .toList(),
      );
    } catch (e) {
      debugPrint('Error streaming company actions: $e');
      return Stream.value([]);
    }
  }

  // Stream actions for a specific user within a company
  Stream<List<RecentAction>> streamCompanyUserActions(
    String companyId,
    String userId, {
    int limit = 50,
        required bool isAuthority ,
  }) {
    final actionsRef = _getCompanyActionsRef(companyId,isAuthority:isAuthority);

    return actionsRef
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => RecentAction.fromFirestore(doc))
              .toList(),
        );
  }

  // Stream actions by entity type within a company
  Stream<List<RecentAction>> streamCompanyActionsByEntity(
    String companyId,
    String entityType, {
    int limit = 50,
        required bool isAuthority
  }) {
    final actionsRef = _getCompanyActionsRef(companyId,isAuthority:isAuthority);

    return actionsRef
        .where('entityType', isEqualTo: entityType)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => RecentAction.fromFirestore(doc))
              .toList(),
        );
  }

  // Stream actions by action type within a company
  Stream<List<RecentAction>> streamCompanyActionsByActionType(
    String companyId,
    String actionType, {
    int limit = 50,
        required bool isAuthority
  }) {
    final actionsRef = _getCompanyActionsRef(companyId,isAuthority:isAuthority);

    return actionsRef
        .where('actionType', isEqualTo: actionType)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => RecentAction.fromFirestore(doc))
              .toList(),
        );
  }

  // Get today's actions for a company
  Stream<List<RecentAction>> streamTodayCompanyActions(String companyId,{required isAuthority}) {
    final actionsRef = _getCompanyActionsRef(companyId,isAuthority: isAuthority);
    final startOfDay = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    return actionsRef
        .where(
          'timestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
        )
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => RecentAction.fromFirestore(doc))
              .toList(),
        );
  }

  // Get action count for a company
  Future<int> getCompanyActionCount(
    String companyId, {
    DateTime? startDate,
    DateTime? endDate,
        required bool isAuthority
  }) async {
    try {
      final actionsRef = _getCompanyActionsRef(companyId,isAuthority: isAuthority);
      Query query = actionsRef;

      if (startDate != null) {
        query = query.where(
          'timestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
        );
      }

      if (endDate != null) {
        query = query.where(
          'timestamp',
          isLessThanOrEqualTo: Timestamp.fromDate(endDate),
        );
      }

      final snapshot = await query.get();
      return snapshot.docs.length;
    } catch (e) {
      print('Error getting action count for company $companyId: $e');
      return 0;
    }
  }

  // Clear old actions for a specific company (older than 30 days)
  Future<void> cleanupCompanyOldActions(String companyId,{required bool isAuthority}) async {
    try {
      final actionsRef = _getCompanyActionsRef(companyId,isAuthority:isAuthority);
      final monthAgo = DateTime.now().subtract(const Duration(days: 30));
      final timestamp = Timestamp.fromDate(monthAgo);

      final snapshot = await actionsRef
          .where('timestamp', isLessThan: timestamp)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
        }

        await batch.commit();
        print(
          '🧹 Cleaned up ${snapshot.docs.length} old actions for company $companyId',
        );
      }
    } catch (e) {
      print('❌ Error cleaning up old actions for company $companyId: $e');
    }
  }

  // Get statistics for a specific company
  Future<Map<String, dynamic>> getCompanyActionStatistics(
    String companyId, {
    DateTime? startDate,
    DateTime? endDate,
        required bool isAuthority
  }) async {
    try {
      final actionsRef = _getCompanyActionsRef(companyId);
      Query query = actionsRef;

      if (startDate != null) {
        query = query.where(
          'timestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
        );
      }

      if (endDate != null) {
        query = query.where(
          'timestamp',
          isLessThanOrEqualTo: Timestamp.fromDate(endDate),
        );
      }

      final snapshot = await query.get();
      final actions = snapshot.docs
          .map((doc) => RecentAction.fromFirestore(doc))
          .toList();

      // Count by action type
      final actionTypeCounts = <String, int>{};
      // Count by entity type
      final entityTypeCounts = <String, int>{};
      // Count by user role
      final userRoleCounts = <String, int>{};
      // Count by user
      final userActionCounts = <String, int>{};
      // Daily counts
      final dailyCounts = <String, int>{};

      for (final action in actions) {
        // Action type counts
        actionTypeCounts[action.actionType] =
            (actionTypeCounts[action.actionType] ?? 0) + 1;

        // Entity type counts
        entityTypeCounts[action.entityType] =
            (entityTypeCounts[action.entityType] ?? 0) + 1;

        // User role counts
        userRoleCounts[action.userRole] =
            (userRoleCounts[action.userRole] ?? 0) + 1;

        // User action counts
        userActionCounts[action.userName] =
            (userActionCounts[action.userName] ?? 0) + 1;

        // Daily counts
        final dateKey = action.timestamp.toLocal().toString().split(' ')[0];
        dailyCounts[dateKey] = (dailyCounts[dateKey] ?? 0) + 1;
      }

      return {
        'companyId': companyId,
        'totalActions': actions.length,
        'actionTypeCounts': actionTypeCounts,
        'entityTypeCounts': entityTypeCounts,
        'userRoleCounts': userRoleCounts,
        'userActionCounts': userActionCounts,
        'dailyCounts': dailyCounts,
        'mostActiveUser': _getMostActiveUser(actions,isAuthority:isAuthority),
        'mostCommonAction': _getMostCommonAction(actionTypeCounts),
        'mostCommonEntity': _getMostCommonEntity(entityTypeCounts),
        'period': {
          'start': startDate?.toIso8601String(),
          'end': endDate?.toIso8601String(),
        },
      };
    } catch (e) {
      print('❌ Error getting action statistics for company $companyId: $e');
      return {'error': e.toString()};
    }
  }

  // Get activity summary for dashboard
  Future<Map<String, dynamic>> getCompanyActivitySummary(
    String companyId,
  {required bool isAuthority}
  ) async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final weekAgo = today.subtract(const Duration(days: 7));
      final monthAgo = today.subtract(const Duration(days: 30));

      final totalCount = await getCompanyActionCount(companyId,isAuthority: isAuthority);
      final todayCount = await getCompanyActionCount(
        isAuthority: isAuthority,
        companyId,
        startDate: today,
      );
      final weekCount = await getCompanyActionCount( isAuthority: isAuthority,
        companyId,
        startDate: weekAgo,
      );
      final monthCount = await getCompanyActionCount( isAuthority: isAuthority,
        companyId,
        startDate: monthAgo,
      );

    final stats = await getCompanyActionStatistics( isAuthority: isAuthority,
        companyId,
        startDate: monthAgo,
      );

      return {
        'companyId': companyId,
        'summary': {
          'total': totalCount,
          'today': todayCount,
          'thisWeek': weekCount,
          'thisMonth': monthCount,
        },
        'trends': {
          'dailyAverage': monthCount > 0 ? monthCount / 30 : 0,
          'weeklyAverage': monthCount > 0 ? monthCount / 4.3 : 0,
        },
        'topActions': _getTopItems(
          stats['actionTypeCounts'] as Map<String, int>? ?? {},
          3,
        ),
        'topEntities': _getTopItems(
          stats['entityTypeCounts'] as Map<String, int>? ?? {},
          3,
        ),
        'topUsers': _getTopItems(
          stats['userActionCounts'] as Map<String, int>? ?? {},
          5,
        ),
      };
    } catch (e) {
      print('❌ Error getting activity summary for company $companyId: $e');
      return {'error': e.toString()};
    }
  }

  // Helper method to get top items
  List<Map<String, dynamic>> _getTopItems(Map<String, int> items, int count) {
    final sorted = items.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted
        .take(count)
        .map((entry) => {'name': entry.key, 'count': entry.value})
        .toList();
  }

  // Delete all actions for a company (use with caution!)
  Future<void> deleteAllCompanyActions(String companyId,{required bool isAuthority}) async {
    try {
      final actionsRef = _getCompanyActionsRef(companyId,isAuthority: isAuthority);
      final snapshot = await actionsRef.get();

      if (snapshot.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        print(
          '🗑️ Deleted all ${snapshot.docs.length} actions for company $companyId',
        );
      }
    } catch (e) {
      print('❌ Error deleting all actions for company $companyId: $e');
      rethrow;
    }
  }

  // Update an existing action
  Future<void> updateAction(
    String companyId,
    String actionId,
    Map<String, dynamic> updates,
      {required bool isAuthority}
  ) async {
    try {
      final actionsRef = _getCompanyActionsRef(companyId,isAuthority: isAuthority);
      await actionsRef.doc(actionId).update(updates);
      print('📝 Updated action $actionId for company $companyId');
    } catch (e) {
      print('❌ Error updating action for company $companyId: $e');
      rethrow;
    }
  }

  // Helper methods (keep from original)
  String _getMostActiveUser(List<RecentAction> actions,{required bool isAuthority}) {
    final userCounts = <String, int>{};
    for (final action in actions) {
      userCounts[action.userName] = (userCounts[action.userName] ?? 0) + 1;
    }

    if (userCounts.isEmpty) return 'N/A';

    final sorted = userCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.first.key;
  }

  String _getMostCommonAction(Map<String, int> counts) {
    if (counts.isEmpty) return 'N/A';

    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.first.key;
  }

  String _getMostCommonEntity(Map<String, int> counts) {
    if (counts.isEmpty) return 'N/A';

    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.first.key;
  }
}
