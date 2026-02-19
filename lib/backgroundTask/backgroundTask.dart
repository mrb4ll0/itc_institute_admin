import 'dart:async';
import 'dart:ui';


import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:workmanager/workmanager.dart';
import 'dart:isolate';

class BackgroundTaskManager {
  static final BackgroundTaskManager _instance = BackgroundTaskManager._internal();
  factory BackgroundTaskManager() => _instance;
  BackgroundTaskManager._internal();


  final Map<String, _TaskInfo> _tasks = {};
  final _statusController = StreamController<TaskUpdate>.broadcast();

  Stream<TaskUpdate> get updates => _statusController.stream;

  // Simple method to run any task in background
  String performTask({
    required Future<dynamic> Function() task,
    String? taskId,
  }) {

    debugPrint('before creating the task id');
    final id = taskId ?? _generateTaskId();
    debugPrint('🔵 [BackgroundTaskManager] Creating task with ID: $id');
    // Store task info
    _tasks[id] = _TaskInfo(
      id: id,
      status: 'queued',
      createdAt: DateTime.now(),
    );

    _statusController.add(TaskUpdate(id, 'queued'));
    debugPrint('🟡 [BackgroundTaskManager] Spawning isolate for task: $id');

    final rootIsolateToken = RootIsolateToken.instance;
    if (rootIsolateToken == null) {
      debugPrint('❌ RootIsolateToken is null in main isolate!');
      return "null";
    }
    // Run in isolate
    _spawnIsolate(id, task,rootIsolateToken);
    debugPrint('🟢 [BackgroundTaskManager] Task submitted, returning ID: $id');
    return id;
  }

  // Get task status
  // Get task status
  TaskInfo? getTaskStatus(String taskId) {
    final task = _tasks[taskId];
    if (task == null) return null;

    // Convert _TaskInfo to TaskInfo
    return TaskInfo(
      id: task.id,
      status: task.status,
      createdAt: task.createdAt,
      updatedAt: task.updatedAt,
      result: task.result,
      error: task.error,
    );
  }

  // Get task result (returns null if not completed or no result)
  dynamic getTaskResult(String taskId) {
    final task = _tasks[taskId];
    return task?.result;
  }

  // Wait for task completion and get result
  Future<T> waitForResult<T>(String taskId, {Duration? timeout}) async {
    final completer = Completer<T>();

    // Check if already completed
    final existing = _tasks[taskId];
    if (existing?.status == 'completed') {
      return existing!.result as T;
    } else if (existing?.status == 'failed') {
      throw Exception(existing?.error ?? 'Task failed');
    }

    // Listen for completion
    late StreamSubscription subscription;
    subscription = _statusController.stream.listen((update) {
      if (update.taskId == taskId) {
        if (update.status == 'completed') {
          final result = _tasks[taskId]?.result as T?;
          subscription.cancel();
          completer.complete(result);
        } else if (update.status == 'failed') {
          final error = _tasks[taskId]?.error ?? 'Unknown error';
          subscription.cancel();
          completer.completeError(error);
        }
      }
    });

    if (timeout != null) {
      return completer.future.timeout(timeout);
    }
    return completer.future;
  }

  // Cancel task
  void cancelTask(String taskId) {
    _updateTaskStatus(taskId, 'cancelled');
  }

  // Clear old tasks (optional)
  void clearCompletedTasks({Duration olderThan = const Duration(hours: 1)}) {
    final now = DateTime.now();
    _tasks.removeWhere((id, task) {
      if (task.status == 'completed' || task.status == 'failed') {
        return now.difference(task.updatedAt ?? task.createdAt) > olderThan;
      }
      return false;
    });
  }

  String _generateTaskId() {
    return 'task_${DateTime.now().millisecondsSinceEpoch}_${_tasks.length}';
  }

  void _spawnIsolate(String taskId, Future<dynamic> Function() task, RootIsolateToken rootIsolateToken) async {
    final receivePort = ReceivePort();

    receivePort.listen((message) {
      if (message is _IsolateResult) {
        if (message.success) {
          _updateTaskStatus(taskId, 'completed', result: message.data);
        } else {
          _updateTaskStatus(taskId, 'failed', error: message.error);
        }
        receivePort.close();
      }
    });

    try {
      await Isolate.spawn(
        _isolateEntry,
        _IsolateData(
          sendPort: receivePort.sendPort,
          task: task,
          rootIsolateToken: rootIsolateToken,
        ),
      );
    } catch (e) {
      _updateTaskStatus(taskId, 'failed', error: e.toString());
      receivePort.close();
    }
  }

  static void _isolateEntry(_IsolateData data) async {
    try {

      BackgroundIsolateBinaryMessenger.ensureInitialized(data.rootIsolateToken);
      debugPrint("🏁 Background messenger initialized with passed token");

      // Initialize Firebase
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
        debugPrint("🏁 Firebase initialized in isolate");
      }
      final result = await data.task();


      data.sendPort.send(_IsolateResult(success: true, data: result));
    } catch (e) {
      data.sendPort.send(_IsolateResult(success: false, error: e.toString()));
    }
  }

  void _updateTaskStatus(String taskId, String status, {dynamic result, String? error}) {
    if (_tasks.containsKey(taskId)) {
      _tasks[taskId] = _tasks[taskId]!.copyWith(
        status: status,
        result: result,
        error: error,
        updatedAt: DateTime.now(),
      );
      _statusController.add(TaskUpdate(taskId, status, result: result, error: error));
    }
  }

  void dispose() {
    _statusController.close();
  }
}

// Helper classes
class _TaskInfo {
  final String id;
  final String status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final dynamic result;
  final String? error;

  _TaskInfo({
    required this.id,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.result,
    this.error,
  });

  _TaskInfo copyWith({
    String? status,
    DateTime? updatedAt,
    dynamic result,
    String? error,
  }) {
    return _TaskInfo(
      id: id,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      result: result ?? this.result,
      error: error ?? this.error,
    );
  }
}

class TaskUpdate {
  final String taskId;
  final String status;
  final dynamic result;
  final String? error;

  TaskUpdate(this.taskId, this.status, {this.result, this.error});
}

class _IsolateData {
  final SendPort sendPort;
  final Future<dynamic> Function() task;
  final RootIsolateToken rootIsolateToken;
  _IsolateData({required this.sendPort, required this.task,required this.rootIsolateToken});
}

class _IsolateResult {
  final bool success;
  final dynamic data;
  final String? error;
  _IsolateResult({required this.success, this.data, this.error});
}

// Public interface for task info
class TaskInfo {
  final String id;
  final String status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final dynamic result;
  final String? error;

  TaskInfo({
    required this.id,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.result,
    this.error,
  });


  TaskInfo.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        status = json['status'],
        createdAt = DateTime.parse(json['createdAt']),
        updatedAt = json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
        result = json['result'],
        error = json['error'];
}