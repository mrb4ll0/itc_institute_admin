import 'dart:async';
import 'dart:collection';

/// Static class to manage background task IDs and their statuses
class BackgroundTaskRegistry {
  // Private constructor to prevent instantiation
  BackgroundTaskRegistry._();
  static final Map<String, String> _latestTaskIds = {};

  // Static storage for task statuses
  static final HashMap<String, TaskStatus> _tasks = HashMap();

  // Stream controller for real-time updates
  static final _statusController = StreamController<TaskStatus>.broadcast();

  /// Stream of task status updates
  static Stream<TaskStatus> get statusStream => _statusController.stream;

  /// Generate a new task ID
  static String generateTaskId({String prefix = 'task'}) {
    final id = '${prefix}_${DateTime.now().millisecondsSinceEpoch}_${_tasks.length}';
    return id;
  }

  /// Register a new task
  static String registerTask({
    String? taskId,
    required String type,
    Map<String, dynamic>? metadata,
  }) {
    final id = taskId ?? generateTaskId();

    _tasks[id] = TaskStatus(
      id: id,
      type: type,
      status: 'queued',
      createdAt: DateTime.now(),
      metadata: metadata ?? {},
    );

    // Save as latest for this type
    _latestTaskIds[type] = id;

    _statusController.add(_tasks[id]!);
    return id;
  }

  // Add method to get latest task by type
  static TaskStatus? getLatestTaskByType(String type) {
    final taskId = _latestTaskIds[type];
    if (taskId == null) return null;
    return _tasks[taskId];
  }

  // Add method to get latest migration task specifically
  static TaskStatus? getLatestMigrationTask() {
    return getLatestTaskByType('migration');
  }

  /// Update task status
  static void updateTaskStatus({
    required String taskId,
    required String status,
    dynamic result,
    String? error,
    Map<String, dynamic>? metadata,
  }) {
    if (!_tasks.containsKey(taskId)) return;

    final currentTask = _tasks[taskId]!;
    final updatedTask = currentTask.copyWith(
      status: status,
      result: result,
      error: error,
      metadata: metadata,
      updatedAt: DateTime.now(),
    );

    _tasks[taskId] = updatedTask;
    _statusController.add(updatedTask);
  }

  /// Get task status by ID
  static TaskStatus? getTask(String taskId) {
    return _tasks[taskId];
  }

  /// Get all tasks
  static List<TaskStatus> getAllTasks() {
    return _tasks.values.toList();
  }

  /// Get tasks by status
  static List<TaskStatus> getTasksByStatus(String status) {
    return _tasks.values.where((task) => task.status == status).toList();
  }

  /// Get tasks by type
  static List<TaskStatus> getTasksByType(String type) {
    return _tasks.values.where((task) => task.type == type).toList();
  }

  /// Check if task exists and is still running
  static bool isTaskRunning(String taskId) {
    final task = _tasks[taskId];
    if (task == null) return false;
    return task.status == 'queued' || task.status == 'running';
  }

  /// Check if task completed successfully
  static bool isTaskCompleted(String taskId) {
    final task = _tasks[taskId];
    return task?.status == 'completed';
  }

  /// Check if task failed
  static bool isTaskFailed(String taskId) {
    final task = _tasks[taskId];
    return task?.status == 'failed';
  }

  /// Wait for task completion
  static Future<TaskStatus> waitForTask(String taskId, {Duration? timeout}) async {
    final completer = Completer<TaskStatus>();

    // Check if already completed
    final existing = _tasks[taskId];
    if (existing != null &&
        (existing.status == 'completed' ||
            existing.status == 'failed' ||
            existing.status == 'cancelled')) {
      return existing;
    }

    // Listen for updates
    late StreamSubscription subscription;
    subscription = statusStream.listen((update) {
      if (update.id == taskId) {
        if (update.status == 'completed' ||
            update.status == 'failed' ||
            update.status == 'cancelled') {
          subscription.cancel();
          completer.complete(update);
        }
      }
    });

    if (timeout != null) {
      return completer.future.timeout(timeout);
    }
    return completer.future;
  }

  /// Mark task as started
  static void markTaskStarted(String taskId) {
    updateTaskStatus(taskId: taskId, status: 'running');
  }

  /// Mark task as completed with result
  static void markTaskCompleted(String taskId, {dynamic result}) {
    updateTaskStatus(
        taskId: taskId,
        status: 'completed',
        result: result
    );
  }

  /// Mark task as failed with error
  static void markTaskFailed(String taskId, String error) {
    updateTaskStatus(
        taskId: taskId,
        status: 'failed',
        error: error
    );
  }

  /// Mark task as cancelled
  static void markTaskCancelled(String taskId) {
    updateTaskStatus(taskId: taskId, status: 'cancelled');
  }

  /// Remove task from registry (cleanup)
  static void removeTask(String taskId) {
    _tasks.remove(taskId);
  }

  /// Clear all completed/failed tasks older than specified duration
  static void cleanOldTasks({Duration olderThan = const Duration(hours: 24)}) {
    final now = DateTime.now();
    _tasks.removeWhere((id, task) {
      if (task.status == 'completed' || task.status == 'failed' || task.status == 'cancelled') {
        return now.difference(task.updatedAt ?? task.createdAt) > olderThan;
      }
      return false;
    });
  }

  /// Clear all tasks
  static void clearAllTasks() {
    _tasks.clear();
  }

  /// Get statistics about tasks
  static Map<String, dynamic> getStatistics() {
    final allTasks = _tasks.values;

    return {
      'total': allTasks.length,
      'queued': allTasks.where((t) => t.status == 'queued').length,
      'running': allTasks.where((t) => t.status == 'running').length,
      'completed': allTasks.where((t) => t.status == 'completed').length,
      'failed': allTasks.where((t) => t.status == 'failed').length,
      'cancelled': allTasks.where((t) => t.status == 'cancelled').length,
      'byType': allTasks.fold<Map<String, int>>({}, (map, task) {
        map[task.type] = (map[task.type] ?? 0) + 1;
        return map;
      }),
    };
  }

  /// Dispose stream controller (call when app closes)
  static void dispose() {
    _statusController.close();
  }
}

/// Task status model
class TaskStatus {
  final String id;
  final String type;
  final String status; // queued, running, completed, failed, cancelled
  final DateTime createdAt;
  final DateTime? updatedAt;
  final dynamic result;
  final String? error;
  final Map<String, dynamic> metadata;

  TaskStatus({
    required this.id,
    required this.type,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.result,
    this.error,
    this.metadata = const {},
  });

  TaskStatus copyWith({
    String? status,
    DateTime? updatedAt,
    dynamic result,
    String? error,
    Map<String, dynamic>? metadata,
  }) {
    return TaskStatus(
      id: id,
      type: type,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      result: result ?? this.result,
      error: error ?? this.error,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'result': result,
      'error': error,
      'metadata': metadata,
    };
  }

  bool get isRunning => status == 'queued' || status == 'running';
  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';
  bool get isCancelled => status == 'cancelled';

  String get duration {
    final end = updatedAt ?? DateTime.now();
    final diff = end.difference(createdAt);

    if (diff.inDays > 0) return '${diff.inDays}d ${diff.inHours % 24}h';
    if (diff.inHours > 0) return '${diff.inHours}h ${diff.inMinutes % 60}m';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ${diff.inSeconds % 60}s';
    return '${diff.inSeconds}s';
  }
}