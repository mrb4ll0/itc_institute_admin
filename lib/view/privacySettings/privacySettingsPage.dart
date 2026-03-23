// pages/privacy_settings_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../itc_logic/service/privacySettingsService.dart';
import '../../model/privacySettingModel.dart';


class PrivacySettingsPage extends StatefulWidget {
  const PrivacySettingsPage({super.key});

  @override
  State<PrivacySettingsPage> createState() => _PrivacySettingsPageState();
}

class _PrivacySettingsPageState extends State<PrivacySettingsPage> {
  PrivacySettings? _settings;
  bool _isLoading = true;
  String? _userId;
  Stream<PrivacySettings>? _settingsStream;

  @override
  void initState() {
    super.initState();
    _loadUserAndSettings();
  }

  Future<void> _loadUserAndSettings() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _userId = user.uid;

        // Set up real-time stream
        _settingsStream = PrivacySettingsService.streamPrivacySettings(user.uid);

        // Initial load
        final settings = await PrivacySettingsService.getUserPrivacySettings(user.uid);
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
      debugPrint('Error loading privacy settings: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading || _settings == null) {
      return Scaffold(
        backgroundColor: theme.colorScheme.background,
        appBar: AppBar(
          title: const Text('Privacy Settings'),
          elevation: 0,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        title: const Text('Privacy Settings'),
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
      body: StreamBuilder<PrivacySettings>(
        stream: _settingsStream,
        initialData: _settings,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading settings',
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            );
          }

          final settings = snapshot.data ?? _settings!;

          return SingleChildScrollView(
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
                          Icons.privacy_tip,
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
                              'Privacy Controls',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Manage who can see your information and how your data is used',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            if (settings.lastUpdated != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  'Last updated: ${_formatDate(settings.lastUpdated!)}',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Profile Privacy
                _buildSectionHeader(
                  theme,
                  title: 'Profile Privacy',
                  icon: Icons.person,
                ),

                _buildSwitchTile(
                  theme,
                  title: 'Profile Visibility',
                  subtitle: 'Make your profile visible to others',
                  value: settings.profileVisibility,
                  onChanged: (value) {
                    _updateSetting('profileVisibility', value);
                  },
                  icon: Icons.visibility,
                ),

                _buildSwitchTile(
                  theme,
                  title: 'Show Email Address',
                  subtitle: 'Display your email on your profile',
                  value: settings.showEmail,
                  onChanged: (value) {
                    _updateSetting('showEmail', value);
                  },
                  icon: Icons.email,
                ),

                _buildSwitchTile(
                  theme,
                  title: 'Show Phone Number',
                  subtitle: 'Display your phone number on your profile',
                  value: settings.showPhoneNumber,
                  onChanged: (value) {
                    _updateSetting('showPhoneNumber', value);
                  },
                  icon: Icons.phone,
                ),

                _buildSwitchTile(
                  theme,
                  title: 'Show Location',
                  subtitle: 'Display your location on your profile',
                  value: settings.showLocation,
                  onChanged: (value) {
                    _updateSetting('showLocation', value);
                  },
                  icon: Icons.location_on,
                ),

                _buildSwitchTile(
                  theme,
                  title: 'Show Company Information',
                  subtitle: 'Display your company details',
                  value: settings.showCompanyInfo,
                  onChanged: (value) {
                    _updateSetting('showCompanyInfo', value);
                  },
                  icon: Icons.business,
                  isLast: true,
                ),

                const SizedBox(height: 24),

                // Data Sharing
                _buildSectionHeader(
                  theme,
                  title: 'Data Sharing & Analytics',
                  icon: Icons.share,
                ),

                _buildSwitchTile(
                  theme,
                  title: 'Share Analytics',
                  subtitle: 'Help improve the app by sharing usage data',
                  value: settings.shareAnalytics,
                  onChanged: (value) {
                    _updateSetting('shareAnalytics', value);
                  },
                  icon: Icons.analytics,
                ),

                _buildSwitchTile(
                  theme,
                  title: 'Share with Partners',
                  subtitle: 'Allow trusted partners to use your data',
                  value: settings.shareWithPartners,
                  onChanged: (value) {
                    _updateSetting('shareWithPartners', value);
                  },
                  icon: Icons.business_center,
                ),

                _buildSwitchTile(
                  theme,
                  title: 'Personalized Ads',
                  subtitle: 'Receive personalized advertisements',
                  value: settings.personalizedAds,
                  onChanged: (value) {
                    _updateSetting('personalizedAds', value);
                  },
                  icon: Icons.adjust,
                  isLast: true,
                ),

                const SizedBox(height: 24),

                // Account Security
                _buildSectionHeader(
                  theme,
                  title: 'Account Security',
                  icon: Icons.security,
                ),

                _buildSwitchTile(
                  theme,
                  title: 'Two-Factor Authentication',
                  subtitle: 'Add an extra layer of security to your account',
                  value: settings.twoFactorAuth,
                  onChanged: (value) {
                    _updateSetting('twoFactorAuth', value);
                  },
                  icon: Icons.security,
                  iconColor: Colors.green,
                ),

                _buildSwitchTile(
                  theme,
                  title: 'Login Alerts',
                  subtitle: 'Get notified when someone logs into your account',
                  value: settings.loginAlerts,
                  onChanged: (value) {
                    _updateSetting('loginAlerts', value);
                  },
                  icon: Icons.notifications_active,
                ),

                _buildSwitchTile(
                  theme,
                  title: 'Device Management',
                  subtitle: 'Manage devices connected to your account',
                  value: settings.deviceManagement,
                  onChanged: (value) {
                    _updateSetting('deviceManagement', value);
                  },
                  icon: Icons.devices,
                ),

                _buildSwitchTile(
                  theme,
                  title: 'Session Timeout',
                  subtitle: 'Automatically logout after inactivity',
                  value: settings.sessionTimeout,
                  onChanged: (value) {
                    _updateSetting('sessionTimeout', value);
                  },
                  icon: Icons.timer,
                ),

                if (settings.sessionTimeout)
                  _buildSliderTile(
                    theme,
                    title: 'Timeout Duration',
                    subtitle: 'Minutes of inactivity before logout',
                    value: settings.sessionTimeoutMinutes.toDouble(),
                    min: 5,
                    max: 120,
                    divisions: 23,
                    onChanged: (value) {
                      _updateSetting('sessionTimeoutMinutes', value.toInt());
                    },
                    icon: Icons.access_time,
                    isLast: true,
                  ),

                const SizedBox(height: 24),

                // Data Management
                _buildSectionHeader(
                  theme,
                  title: 'Data Management',
                  icon: Icons.storage,
                ),

                _buildSwitchTile(
                  theme,
                  title: 'Data Backup',
                  subtitle: 'Automatically backup your data to cloud',
                  value: settings.dataBackup,
                  onChanged: (value) {
                    _updateSetting('dataBackup', value);
                  },
                  icon: Icons.backup,
                ),

                _buildSwitchTile(
                  theme,
                  title: 'Auto-Delete Data',
                  subtitle: 'Automatically delete old data',
                  value: settings.autoDeleteData,
                  onChanged: (value) {
                    _updateSetting('autoDeleteData', value);
                  },
                  icon: Icons.delete_sweep,
                ),

                if (settings.autoDeleteData)
                  _buildSliderTile(
                    theme,
                    title: 'Delete After',
                    subtitle: 'Days of inactivity before data deletion',
                    value: settings.autoDeleteDays.toDouble(),
                    min: 30,
                    max: 365,
                    divisions: 33,
                    onChanged: (value) {
                      _updateSetting('autoDeleteDays', value.toInt());
                    },
                    icon: Icons.calendar_today,
                    isLast: true,
                  ),

                const SizedBox(height: 24),

                // Content Privacy
                _buildSectionHeader(
                  theme,
                  title: 'Content Privacy',
                  icon: Icons.content_copy,
                ),

                _buildSwitchTile(
                  theme,
                  title: 'Hide from Search',
                  subtitle: 'Prevent your profile from appearing in searches',
                  value: settings.hideFromSearch,
                  onChanged: (value) {
                    _updateSetting('hideFromSearch', value);
                  },
                  icon: Icons.search_off,
                ),

                _buildSwitchTile(
                  theme,
                  title: 'Block Unknown Users',
                  subtitle: 'Block messages from users you don\'t know',
                  value: settings.blockUnknownUsers,
                  onChanged: (value) {
                    _updateSetting('blockUnknownUsers', value);
                  },
                  icon: Icons.block,
                ),

                _buildSwitchTile(
                  theme,
                  title: 'Message Privacy',
                  subtitle: 'Allow only connections to message you',
                  value: settings.messagePrivacy,
                  onChanged: (value) {
                    _updateSetting('messagePrivacy', value);
                  },
                  icon: Icons.message,
                  isLast: true,
                ),

                const SizedBox(height: 24),

                // Activity Privacy
                _buildSectionHeader(
                  theme,
                  title: 'Activity Privacy',
                  icon: Icons.timeline,
                ),

                _buildSwitchTile(
                  theme,
                  title: 'Show Online Status',
                  subtitle: 'Let others see when you\'re online',
                  value: settings.showOnlineStatus,
                  onChanged: (value) {
                    _updateSetting('showOnlineStatus', value);
                  },
                  icon: Icons.circle,
                ),

                _buildSwitchTile(
                  theme,
                  title: 'Show Last Seen',
                  subtitle: 'Show when you were last active',
                  value: settings.showLastSeen,
                  onChanged: (value) {
                    _updateSetting('showLastSeen', value);
                  },
                  icon: Icons.access_time,
                ),

                _buildSwitchTile(
                  theme,
                  title: 'Show Activity Status',
                  subtitle: 'Display your recent activities',
                  value: settings.showActivityStatus,
                  onChanged: (value) {
                    _updateSetting('showActivityStatus', value);
                  },
                  icon: Icons.trending_up,
                  isLast: true,
                ),

                const SizedBox(height: 32),

                // Data Export & Delete Account
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _exportData,
                        icon: Icon(
                          Icons.download,
                          color: theme.colorScheme.primary,
                          size: 18,
                        ),
                        label: Text(
                          'Export My Data',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: theme.colorScheme.primary.withOpacity(0.5)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _deleteAccount,
                        icon: Icon(
                          Icons.delete_forever,
                          color: theme.colorScheme.error,
                          size: 18,
                        ),
                        label: Text(
                          'Delete Account',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: theme.colorScheme.error.withOpacity(0.5)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
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
                      side: BorderSide(color: theme.colorScheme.error.withOpacity(0.5)),
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
          );
        },
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
            child: Icon(
              icon,
              size: 18,
              color: theme.colorScheme.primary,
            ),
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
              : BorderSide(
            color: theme.dividerColor,
          ),
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

  Widget _buildSliderTile(
      ThemeData theme, {
        required String title,
        required String subtitle,
        required double value,
        required double min,
        required double max,
        required int divisions,
        required ValueChanged<double> onChanged,
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
              : BorderSide(
            color: theme.dividerColor,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 20,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Slider(
                    value: value,
                    min: min,
                    max: max,
                    divisions: divisions,
                    label: value.toInt().toString(),
                    onChanged: onChanged,
                    activeColor: theme.colorScheme.primary,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${min.toInt()} ${_getUnit(title)}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        '${value.toInt()} ${_getUnit(title)}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      Text(
                        '${max.toInt()} ${_getUnit(title)}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
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

  String _getUnit(String title) {
    if (title.contains('Timeout')) {
      return 'mins';
    }
    if (title.contains('Delete')) {
      return 'days';
    }
    return '';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _updateSetting(String field, dynamic value) async {
    if (_userId == null) return;

    try {
      await PrivacySettingsService.updatePrivacySetting(_userId!, field, value);

      // Show success indicator
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Setting updated'),
          duration: const Duration(seconds: 1),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating setting: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _resetSettings() async {
    if (_userId == null) return;

    final theme = Theme.of(context);

    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: Text(
          'Reset Settings',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to reset all privacy settings to default?',
          style: theme.textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
              ),
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
      try {
        await PrivacySettingsService.resetPrivacySettings(_userId!);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Settings reset to default'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error resetting settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveSettings() async {
    // Settings are saved automatically with each toggle
    // This method is kept for backward compatibility
    Navigator.pop(context);
  }

  void _exportData() {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: Text(
          'Export Data',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Your data export request has been initiated. You will receive an email with download link shortly.',
          style: theme.textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: TextStyle(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _deleteAccount() {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: Text(
          'Delete Account',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.error,
          ),
        ),
        content: Text(
          'Are you sure you want to delete your account? This action cannot be undone and all your data will be permanently lost.',
          style: theme.textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              if (_userId != null) {
                try {
                  // Delete privacy settings from Firestore
                  await PrivacySettingsService.deletePrivacySettings(_userId!);

                  // Delete user account from Firebase Auth
                  final user = FirebaseAuth.instance.currentUser;
                  if (user != null) {
                    await user.delete();
                  }

                  // Navigate to login screen
                  if (mounted) {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/login',
                          (route) => false,
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting account: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}