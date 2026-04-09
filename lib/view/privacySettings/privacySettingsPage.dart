// pages/privacy_settings_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

import '../../itc_logic/service/privacySettingsService.dart';
import '../../itc_logic/service/2FactorAuthService.dart';
import '../../model/privacySettingModel.dart';
import '../twoFactorAuthentication/twoFactorEnrollmentScreen.dart';

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

  // Add TwoFactorAuthService
  final TwoFactorAuthService _twoFactorService = TwoFactorAuthService();

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
                _buildHeaderBanner(theme, settings),

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

                // Backup Codes Section (Only show if 2FA is enabled)
                if (settings.twoFactorAuth && settings.activeTwoFactorMethod == TwoFactorMethod.password)
                  _buildBackupCodesSection(theme),

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

  Widget _buildHeaderBanner(ThemeData theme, PrivacySettings settings) {
    return Container(
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
    );
  }

  // Add Backup Codes Section
  Widget _buildBackupCodesSection(ThemeData theme) {
    return FutureBuilder<int>(
      future: _twoFactorService.getRemainingBackupCodesCount(),
      builder: (context, snapshot) {
        final remaining = snapshot.data ?? 0;

        return Column(
          children: [
            _buildSectionHeader(
              theme,
              title: 'Backup Codes',
              icon: Icons.code,
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Remaining backup codes:'),
                      Text(
                        '$remaining / 10',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: remaining < 3 ? Colors.orange : Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _viewBackupCodes,
                          icon: const Icon(Icons.visibility),
                          label: const Text('View Codes'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _regenerateBackupCodes,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Regenerate'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _viewBackupCodes() async {
    // First, regenerate to show new codes (since we can't retrieve old ones)
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('View Backup Codes'),
        content: const Text(
            'For security reasons, existing backup codes cannot be viewed again. '
                'Would you like to generate new backup codes?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
            ),
            child: const Text('Generate New Codes'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _regenerateBackupCodes();
    }
  }

  Future<void> _regenerateBackupCodes() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Regenerate Backup Codes'),
        content: const Text(
            'Regenerating backup codes will invalidate your old codes. '
                'Make sure to save the new codes. Continue?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('Regenerate'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        final newCodes = await _twoFactorService.regenerateBackupCodes();
        await _showBackupCodesDialog(newCodes);
        // Refresh the count
        setState(() {});
      } catch (e) {
        _showSnackBar('Error: $e', Colors.red);
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showBackupCodesDialog(List<String> codes) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Save Your Backup Codes'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'These backup codes can be used to access your account if you forget your 2FA password. '
                    'Each code can only be used once.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: codes.asMap().entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 30,
                            child: Text(
                              '${entry.key + 1}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              entry.value,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy, size: 18),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: entry.value));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Code copied!')),
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '⚠️ Make sure to save these codes in a secure place. '
                    'You will not be able to see them again!',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('I Have Saved Them'),
          ),
        ],
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

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _updateSetting(String field, dynamic value) async {
    if (_userId == null) return;

    // Special handling for Two-Factor Authentication
    if (field == 'twoFactorAuth') {
      if (value == true) {
        // Enabling 2FA - navigate to enrollment screen
        final result = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (context) => const TwoFactorEnrollmentScreen(),
          ),
        );

        if (result != true) {
          // User cancelled or failed to enroll, revert the toggle
          setState(() {
            _settings?.twoFactorAuth = false;
          });
          return;
        }

        // 2FA successfully enabled, update local state
        setState(() {
          _settings?.twoFactorAuth = true;
        });

        _showSnackBar('Two-Factor Authentication enabled successfully!', Colors.green);
      } else {
        // Disabling 2FA - show confirmation dialog first
        final shouldDisable = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Disable Two-Factor Authentication'),
            content: const Text(
                'Disabling 2FA will make your account less secure. '
                    'Are you sure you want to continue?'
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Disable'),
              ),
            ],
          ),
        );

        if (shouldDisable != true) {
          // User cancelled, revert the toggle
          setState(() {
            _settings?.twoFactorAuth = true;
          });
          return;
        }

        // Show loading
        setState(() => _isLoading = true);

        try {
          // Get enrolled factors and unenroll them
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            await user.reload();
            final factors = await user.multiFactor.getEnrolledFactors();

            for (final factor in factors) {
              await user.multiFactor.unenroll(factorUid: factor.uid);
            }
          }

          // Also remove password-based 2FA if exists
          try {
            await _twoFactorService.removeTwoFactorPassword();
          } catch (e) {
            // Ignore if no password 2FA exists
          }

          // Update Firestore
          await PrivacySettingsService.updatePrivacySetting(_userId!, field, value);

          setState(() {
            _settings?.twoFactorAuth = false;
            _isLoading = false;
          });

          _showSnackBar('Two-Factor Authentication disabled', Colors.orange);
        } catch (e) {
          setState(() {
            _settings?.twoFactorAuth = true; // Revert
            _isLoading = false;
          });

          _showSnackBar('Error disabling 2FA: $e', Colors.red);
        }
      }
      return;
    }

    // Normal update for other fields
    try {
      await PrivacySettingsService.updatePrivacySetting(_userId!, field, value);
      _showSnackBar('Setting updated', Colors.green);
    } catch (e) {
      _showSnackBar('Error updating setting: $e', Colors.red);
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
          _showSnackBar('Settings reset to default', Colors.orange);
        }
      } catch (e) {
        _showSnackBar('Error resetting settings: $e', Colors.red);
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

                  // Delete backup codes
                  try {
                    await _twoFactorService.removeTwoFactorPassword();
                  } catch (e) {
                    // Ignore
                  }

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
                  _showSnackBar('Error deleting account: $e', Colors.red);
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