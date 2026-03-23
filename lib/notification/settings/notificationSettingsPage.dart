import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../itc_logic/localDB/sharedPreference.dart';
import '../../model/notificationSettingModel.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  // Notification settings
  NotificationSettings _settings = NotificationSettings.defaultSettings();
  bool _isLoading = true;
  String? _userEmail;

  @override
  void initState() {
    super.initState();
    _loadUserAndSettings();
  }

  Future<void> _loadUserAndSettings() async {
    try {
      // Get current user email
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.email != null) {
        _userEmail = user.email;
        final settings = await UserPreferences.getNotificationSettings(
          user.email!,
        );
        setState(() {
          _settings = settings;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.colorScheme.background,
        appBar: AppBar(
          title: const Text('Notification Settings'),
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        title: const Text('Notification Settings'),
        centerTitle: false,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _saveSettings,
            child: Text(
              'Save',
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Banner
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.colorScheme.primary.withOpacity(0.2),
                    theme.colorScheme.primary.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.primary.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.notifications_active,
                      color: theme.colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Stay Updated',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Choose how you want to receive notifications',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Notification Channels
            _buildSectionHeader(
              theme,
              title: 'Notification Channels',
              icon: Icons.notifications,
            ),

            _buildSwitchTile(
              theme,
              title: 'Push Notifications',
              subtitle: 'Receive notifications on your device',
              value: _settings.pushNotifications,
              onChanged: (value) {
                setState(() {
                  _settings = _settings.copyWith(pushNotifications: value);
                });
              },
              icon: Icons.notifications,
            ),

            _buildSwitchTile(
              theme,
              title: 'Email Notifications',
              subtitle: 'Get updates via email',
              value: _settings.emailNotifications,
              onChanged: (value) {
                setState(() {
                  _settings = _settings.copyWith(emailNotifications: value);
                });
              },
              icon: Icons.email,
            ),

            _buildSwitchTile(
              theme,
              title: 'SMS Notifications',
              subtitle: 'Receive text messages',
              value: _settings.smsNotifications,
              onChanged: (value) {
                setState(() {
                  _settings = _settings.copyWith(smsNotifications: value);
                });
              },
              icon: Icons.sms,
            ),

            _buildSwitchTile(
              theme,
              title: 'In-App Notifications',
              subtitle: 'Show notifications while using the app',
              value: _settings.inAppNotifications,
              onChanged: (value) {
                setState(() {
                  _settings = _settings.copyWith(inAppNotifications: value);
                });
              },
              icon: Icons.notifications_active,
              isLast: true,
            ),

            const SizedBox(height: 24),

            // Trainee & Application Notifications
            _buildSectionHeader(
              theme,
              title: 'Trainee & Application Alerts',
              icon: Icons.people,
            ),

            _buildSwitchTile(
              theme,
              title: 'New Trainee Applications',
              subtitle: 'When trainees apply to your company',
              value: _settings.newTraineeApplications,
              onChanged: (value) {
                setState(() {
                  _settings = _settings.copyWith(newTraineeApplications: value);
                });
              },
              icon: Icons.person_add,
              iconColor: Colors.blue,
            ),

            _buildSwitchTile(
              theme,
              title: 'Form Submissions',
              subtitle: 'When trainees submit IT forms',
              value: _settings.formSubmissions,
              onChanged: (value) {
                setState(() {
                  _settings = _settings.copyWith(formSubmissions: value);
                });
              },
              icon: Icons.description,
              iconColor: Colors.green,
            ),

            _buildSwitchTile(
              theme,
              title: 'Trainee Profile Updates',
              subtitle: 'When trainees update their profiles',
              value: _settings.traineeUpdates,
              onChanged: (value) {
                setState(() {
                  _settings = _settings.copyWith(traineeUpdates: value);
                });
              },
              icon: Icons.update,
              iconColor: Colors.orange,
            ),

            _buildSwitchTile(
              theme,
              title: 'Application Status Changes',
              subtitle: 'When trainee applications are reviewed',
              value: _settings.applicationStatus,
              onChanged: (value) {
                setState(() {
                  _settings = _settings.copyWith(applicationStatus: value);
                });
              },
              icon: Icons.swap_horiz,
              iconColor: Colors.purple,
              isLast: true,
            ),

            const SizedBox(height: 24),

            // System Notifications
            _buildSectionHeader(
              theme,
              title: 'System Notifications',
              icon: Icons.settings_suggest,
            ),

            _buildSwitchTile(
              theme,
              title: 'System Updates',
              subtitle: 'New features and improvements',
              value: _settings.systemUpdates,
              onChanged: (value) {
                setState(() {
                  _settings = _settings.copyWith(systemUpdates: value);
                });
              },
              icon: Icons.system_update,
              iconColor: Colors.teal,
            ),

            _buildSwitchTile(
              theme,
              title: 'Maintenance Alerts',
              subtitle: 'Scheduled maintenance and downtime',
              value: _settings.maintenanceAlerts,
              onChanged: (value) {
                setState(() {
                  _settings = _settings.copyWith(maintenanceAlerts: value);
                });
              },
              icon: Icons.build,
              iconColor: Colors.orange,
            ),

            _buildSwitchTile(
              theme,
              title: 'Security Alerts',
              subtitle: 'Important security notifications',
              value: _settings.securityAlerts,
              onChanged: (value) {
                setState(() {
                  _settings = _settings.copyWith(securityAlerts: value);
                });
              },
              icon: Icons.security,
              iconColor: Colors.red,
              isLast: true,
            ),

            const SizedBox(height: 24),

            // Reminders
            _buildSectionHeader(theme, title: 'Reminders', icon: Icons.alarm),

            _buildSwitchTile(
              theme,
              title: 'Daily Reminders',
              subtitle: 'Get daily tips and updates',
              value: _settings.dailyReminders,
              onChanged: (value) {
                setState(() {
                  _settings = _settings.copyWith(dailyReminders: value);
                });
              },
              icon: Icons.calendar_today,
            ),

            _buildSwitchTile(
              theme,
              title: 'Pending Forms Reminders',
              subtitle: 'Remind you about incomplete forms',
              value: _settings.pendingFormsReminders,
              onChanged: (value) {
                setState(() {
                  _settings = _settings.copyWith(pendingFormsReminders: value);
                });
              },
              icon: Icons.assignment,
              iconColor: Colors.orange,
            ),

            _buildSwitchTile(
              theme,
              title: 'Profile Completion Reminders',
              subtitle: 'Complete your company profile',
              value: _settings.profileCompletionReminders,
              onChanged: (value) {
                setState(() {
                  _settings = _settings.copyWith(
                    profileCompletionReminders: value,
                  );
                });
              },
              icon: Icons.percent,
              iconColor: Colors.green,
              isLast: true,
            ),

            const SizedBox(height: 24),

            // Quiet Hours
            _buildSectionHeader(
              theme,
              title: 'Quiet Hours',
              icon: Icons.nightlight_round,
              action: Switch(
                value: _settings.quietHoursEnabled,
                onChanged: (value) {
                  setState(() {
                    _settings = _settings.copyWith(quietHoursEnabled: value);
                  });
                },
                activeColor: theme.colorScheme.primary,
              ),
            ),

            if (_settings.quietHoursEnabled) ...[
              _buildTimePickerTile(
                theme,
                title: 'Start Time',
                time: _settings.quietStartTime,
                onTap: () => _selectTime(context, isStart: true),
                icon: Icons.nightlight,
              ),
              _buildTimePickerTile(
                theme,
                title: 'End Time',
                time: _settings.quietEndTime,
                onTap: () => _selectTime(context, isStart: false),
                icon: Icons.wb_sunny,
                isLast: true,
              ),
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No notifications will be sent during quiet hours',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Sound & Vibration
            _buildSectionHeader(
              theme,
              title: 'Sound & Vibration',
              icon: Icons.volume_up,
            ),

            _buildSwitchTile(
              theme,
              title: 'Notification Sound',
              subtitle: 'Play sound for notifications',
              value: _settings.soundEnabled,
              onChanged: (value) {
                setState(() {
                  _settings = _settings.copyWith(soundEnabled: value);
                });
              },
              icon: Icons.volume_up,
            ),

            _buildSwitchTile(
              theme,
              title: 'Vibration',
              subtitle: 'Vibrate on notifications',
              value: _settings.vibrationEnabled,
              onChanged: (value) {
                setState(() {
                  _settings = _settings.copyWith(vibrationEnabled: value);
                });
              },
              icon: Icons.vibration,
              isLast: true,
            ),

            const SizedBox(height: 32),

            // Reset Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OutlinedButton.icon(
                onPressed: _resetSettings,
                icon: Icon(
                  Icons.restore,
                  color: theme.colorScheme.error,
                  size: 18,
                ),
                label: Text(
                  'Reset to Default',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: theme.colorScheme.error.withOpacity(0.5),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    ThemeData theme, {
    required String title,
    required IconData icon,
    Widget? action,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 18, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (action != null) action,
        ],
      ),
    );
  }

  Widget _buildSwitchTile(
    ThemeData theme, {
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
    Color? iconColor,
    bool isLast = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(isLast ? 12 : 0),
          topRight: Radius.circular(isLast ? 12 : 0),
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
        border: Border(
          bottom: isLast
              ? BorderSide.none
              : BorderSide(color: theme.dividerColor),
        ),
      ),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.all(12),
        title: Text(
          title,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        value: value,
        onChanged: onChanged,
        activeColor: theme.colorScheme.primary,
        secondary: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: (iconColor ?? theme.colorScheme.primary).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 20,
            color: iconColor ?? theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildTimePickerTile(
    ThemeData theme, {
    required String title,
    required TimeOfDay time,
    required VoidCallback onTap,
    required IconData icon,
    bool isLast = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(isLast ? 12 : 0),
          topRight: Radius.circular(isLast ? 12 : 0),
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
        border: Border(
          bottom: isLast
              ? BorderSide.none
              : BorderSide(color: theme.dividerColor),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: theme.colorScheme.primary),
        ),
        title: Text(
          title,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              time.format(context),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: theme.colorScheme.onSurfaceVariant,
              size: 20,
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  Future<void> _selectTime(
    BuildContext context, {
    required bool isStart,
  }) async {
    final theme = Theme.of(context);

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _settings.quietStartTime : _settings.quietEndTime,
      builder: (context, child) {
        return Theme(
          data: theme.copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: theme.colorScheme.surface,
              hourMinuteTextColor: theme.colorScheme.onSurface,
              dayPeriodTextColor: theme.colorScheme.onSurface,
              dialBackgroundColor: theme.colorScheme.surfaceVariant,
              dialHandColor: theme.colorScheme.primary,
              dialTextColor: theme.colorScheme.onSurface,
              entryModeIconColor: theme.colorScheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _settings = _settings.copyWith(quietStartTime: picked);
        } else {
          _settings = _settings.copyWith(quietEndTime: picked);
        }
      });
    }
  }

  Future<void> _resetSettings() async {
    final theme = Theme.of(context);

    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'Reset Settings',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to reset all notification settings to default?',
          style: theme.textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (shouldReset == true) {
      setState(() {
        _settings = NotificationSettings.defaultSettings();
      });

      // Save to SharedPreferences
      if (_userEmail != null) {
        await UserPreferences.saveNotificationSettings(_userEmail!, _settings);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings reset to default'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _saveSettings() async {
    final theme = Theme.of(context);

    if (_userEmail == null) {
      // Show error if no user email
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to save: User not logged in'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Save to SharedPreferences
    await UserPreferences.saveNotificationSettings(_userEmail!, _settings);

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_circle, color: Colors.green, size: 64),
              ),
              const SizedBox(height: 16),
              Text(
                'Settings Saved!',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your notification preferences have been updated',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      );
    }
  }
}
