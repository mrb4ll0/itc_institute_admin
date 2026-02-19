import 'package:flutter/material.dart';

import '../../migrationService/migrationService.dart';
import '../backgroundTask.dart';
import '../backgroundTaskRegistry.dart';
import 'migrationStatusPopUp.dart';


class MigrationStatusIcon extends StatelessWidget {
  final VoidCallback? onRefresh;

  const MigrationStatusIcon({Key? key, this.onRefresh}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<TaskStatus>(
      stream: BackgroundTaskRegistry.statusStream
          .where((task) => task.type == 'migration'),
      builder: (context, snapshot) {
        final task = snapshot.data ??
            BackgroundTaskRegistry.getLatestMigrationTask();

        return MigrationPopupMenu(
          onRefresh: onRefresh,
          child: _buildIcon(context, task),
        );
      },
    );
  }

  Widget _buildIcon(BuildContext context, TaskStatus? task) {
    final theme = Theme.of(context);

    if (task == null) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        child: Icon(
          Icons.sync,
          color: theme.iconTheme.color,
        ),
      );
    }

    switch (task.status) {
      case 'queued':
      case 'running':
        return Stack(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              child: Icon(
                Icons.sync,
                color: Colors.orange,
              ),
            ),
            Positioned(
              top: 0,
              right: 4,
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
                child: const SizedBox(),
              ),
            ),
          ],
        );

      case 'completed':
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          child: const Icon(
            Icons.check_circle,
            color: Colors.green,
          ),
        );

      case 'failed':
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          child: const Icon(
            Icons.error,
            color: Colors.red,
          ),
        );

      default:
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          child: Icon(
            Icons.sync,
            color: theme.iconTheme.color,
          ),
        );
    }
  }
}