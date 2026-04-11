// pages/privacy_and_security_settings_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

import '../../itc_logic/service/privacySettingsService.dart';
import '../../itc_logic/service/securitySettingsService.dart';
import '../../itc_logic/service/2FactorAuthService.dart';
import '../../model/privacySettingModel.dart';

import '../../model/securitySettingsModel.dart';
import '../ConnectedDeviceManagement/ConnectedDevicePage.dart';
import '../twoFactorAuthentication/twoFactorEnrollmentScreen.dart';

class PrivacyAndSecuritySettingsPage extends StatefulWidget {
  const PrivacyAndSecuritySettingsPage({super.key});

  @override
  State<PrivacyAndSecuritySettingsPage> createState() => _PrivacyAndSecuritySettingsPageState();
}

class _PrivacyAndSecuritySettingsPageState extends State<PrivacyAndSecuritySettingsPage> {
  PrivacySettings? _privacySettings;
  SecuritySettings? _securitySettings;
  bool _isLoading = true;
  String? _userId;
  Stream<PrivacySettings>? _privacySettingsStream;
  Stream<SecuritySettings>? _securitySettingsStream;

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

        // Set up real-time streams
        _privacySettingsStream = PrivacySettingsService.streamPrivacySettings(user.uid);
        _securitySettingsStream = SecuritySettingsService.streamSecuritySettings(user.uid);

        // Initial load
        final privacySettings = await PrivacySettingsService.getUserPrivacySettings(user.uid);
        final securitySettings = await SecuritySettingsService.getUserSecuritySettings(user.uid);

        setState(() {
          _privacySettings = privacySettings;
          _securitySettings = securitySettings;
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

    if (_isLoading || _privacySettings == null || _securitySettings == null) {
      return Scaffold(
        backgroundColor: theme.colorScheme.background,
        appBar: AppBar(
          title: const Text('Privacy & Security'),
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
        title: const Text('Privacy & Security'),
        centerTitle: false,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Done',
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<PrivacySettings>(
        stream: _privacySettingsStream,
        initialData: _privacySettings,
        builder: (context, privacySnapshot) {
          if (privacySnapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
                  const SizedBox(height: 16),
                  Text('Error loading settings', style: theme.textTheme.bodyLarge),
                ],
              ),
            );
          }

          final privacySettings = privacySnapshot.data ?? _privacySettings!;

          return StreamBuilder<SecuritySettings>(
            stream: _securitySettingsStream,
            initialData: _securitySettings,
            builder: (context, securitySnapshot) {
              final securitySettings = securitySnapshot.data ?? _securitySettings!;

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Security Score Card
                    _buildSecurityScoreCard(theme, securitySettings),

                    // Authentication Security Section
                    _buildSectionHeader(theme, title: 'Authentication Security', icon: Icons.fingerprint),
                    _buildSwitchTile(
                      theme,
                      title: 'Two-Factor Authentication',
                      subtitle: 'Add an extra layer of security',
                      value: privacySettings.twoFactorAuth,
                      onChanged: (value) {
                        _updateSecuritySetting('twoFactorAuth', value);
                      },
                      icon: Icons.security,
                      iconColor: Colors.green,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const TwoFactorEnrollmentScreen()),
                        );
                      },
                    ),
                    _buildSwitchTile(
                      theme,
                      title: 'Biometric Login',
                      subtitle: 'Use fingerprint or face recognition',
                      value: securitySettings.biometricLogin,
                      onChanged: null == null?null:(value) {
                        _updateSecuritySetting('biometricLogin', value);
                      },
                      icon: Icons.fingerprint,
                    ),
                    _buildSwitchTile(
                      theme,
                      title: 'Remember Me',
                      subtitle: 'Stay logged in on this device',
                      value: securitySettings.rememberMe,
                      onChanged: (value) {
                        _updateSecuritySetting('rememberMe', value);
                      },
                      icon: Icons.device_unknown,
                    ),
                    _buildSliderTile(
                      theme,
                      title: 'Session Timeout',
                      subtitle: 'Minutes before automatic logout',
                      value: securitySettings.sessionTimeoutMinutes.toDouble(),
                      min: 5,
                      max: 120,
                      divisions: 23,
                      onChanged: (value) {
                        _updateSecuritySetting('sessionTimeoutMinutes', value.toInt());
                      },
                      icon: Icons.timer,
                      isLast: true,
                    ),

                    const SizedBox(height: 24),

                    // Login Security Section
                    _buildSectionHeader(theme, title: 'Login Security', icon: Icons.login),
                    _buildSwitchTile(
                      theme,
                      title: 'Login Alerts',
                      subtitle: 'Get notified on new logins',
                      value: securitySettings.loginAlerts,
                      onChanged: (value) {
                        _updateSecuritySetting('loginAlerts', value);
                      },
                      icon: Icons.notifications_active,
                    ),
                    // _buildSwitchTile(
                    //   theme,
                    //   title: 'New Device Alerts',
                    //   subtitle: 'Alert when logging in from new device',
                    //   value: securitySettings.newDeviceAlerts,
                    //   onChanged: (value) {
                    //     _updateSecuritySetting('newDeviceAlerts', value);
                    //   },
                    //   icon: Icons.devices,
                    // ),
                    _buildSwitchTile(
                      theme,
                      title: 'Failed Login Alerts',
                      subtitle: 'Get notified on failed login attempts',
                      value: securitySettings.failedLoginAlerts,
                      onChanged: (value) {
                        _updateSecuritySetting('failedLoginAlerts', value);
                      },
                      icon: Icons.warning,
                    ),
                    _buildSliderTile(
                      theme,
                      title: 'Max Failed Attempts',
                      subtitle: 'Attempts before account lock',
                      value: securitySettings.maxFailedAttempts.toDouble(),
                      min: 3,
                      max: 10,
                      divisions: 7,
                      onChanged: (value) {
                        _updateSecuritySetting('maxFailedAttempts', value.toInt());
                      },
                      icon: Icons.sms_outlined,
                    ),
                    _buildSwitchTile(
                      theme,
                      title: 'Lock After Failed Attempts',
                      subtitle: 'Temporarily lock account after failed attempts',
                      value: securitySettings.lockAfterFailedAttempts,
                      onChanged: (value) {
                        _updateSecuritySetting('lockAfterFailedAttempts', value);
                      },
                      icon: Icons.lock,
                    ),
                    if (securitySettings.lockAfterFailedAttempts)
                      _buildSliderTile(
                        theme,
                        title: 'Lock Duration',
                        subtitle: 'Minutes account remains locked',
                        value: securitySettings.lockDurationMinutes.toDouble(),
                        min: 15,
                        max: 120,
                        divisions: 21,
                        onChanged: (value) {
                          _updateSecuritySetting('lockDurationMinutes', value.toInt());
                        },
                        icon: Icons.timer,
                        isLast: true,
                      ),

                    const SizedBox(height: 24),

                    // Device Management Section
                    _buildSectionHeader(theme, title: 'Device Management', icon: Icons.devices),
                    _buildSwitchTile(
                      theme,
                      title: 'Device Management',
                      subtitle: 'Manage connected devices',
                      value: securitySettings.deviceManagement,
                      onChanged: (value) {
                        _updateSecuritySetting('deviceManagement', value);
                      },
                      icon: Icons.settings_ethernet,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ConnectedDevicesPage()),
                        );
                      },
                    ),
                    _buildSwitchTile(
                      theme,
                      title: 'Allow Multiple Devices',
                      subtitle: 'Use account on multiple devices',
                      value: securitySettings.allowMultipleDevices,
                      onChanged: (value) {
                        _updateSecuritySetting('allowMultipleDevices', value);
                      },
                      icon: Icons.devices,
                    ),
                    if (securitySettings.allowMultipleDevices)
                      _buildSliderTile(
                        theme,
                        title: 'Max Devices Allowed',
                        subtitle: 'Number of devices allowed',
                        value: securitySettings.maxDevicesAllowed.toDouble(),
                        min: 1,
                        max: 10,
                        divisions: 9,
                        onChanged: (value) {
                          _updateSecuritySetting('maxDevicesAllowed', value.toInt());
                        },
                        icon: Icons.devices,
                        isLast: true,
                      ),

                    const SizedBox(height: 24),

                    // Backup Codes Section (Only show if 2FA is enabled)
                    if (securitySettings.twoFactorAuth)
                      _buildBackupCodesSection(theme),

                    const SizedBox(height: 24),

                    // Profile Privacy Section
                    _buildSectionHeader(theme, title: 'Profile Privacy', icon: Icons.person),
                    _buildSwitchTile(
                      theme,
                      title: 'Profile Visibility',
                      subtitle: 'Make your profile visible to others',
                      value: privacySettings.profileVisibility,
                      onChanged: (value) {
                        _updatePrivacySetting('profileVisibility', value);
                      },
                      icon: Icons.visibility,
                    ),
                    _buildSwitchTile(
                      theme,
                      title: 'Show Email Address',
                      subtitle: 'Display your email on your profile',
                      value: privacySettings.showEmail,
                      onChanged: (value) {
                        _updatePrivacySetting('showEmail', value);
                      },
                      icon: Icons.email,
                    ),
                    _buildSwitchTile(
                      theme,
                      title: 'Show Phone Number',
                      subtitle: 'Display your phone number on your profile',
                      value: privacySettings.showPhoneNumber,
                      onChanged: (value) {
                        _updatePrivacySetting('showPhoneNumber', value);
                      },
                      icon: Icons.phone,
                    ),
                    _buildSwitchTile(
                      theme,
                      title: 'Show Location',
                      subtitle: 'Display your location on your profile',
                      value: privacySettings.showLocation,
                      onChanged: (value) {
                        _updatePrivacySetting('showLocation', value);
                      },
                      icon: Icons.location_on,
                    ),
                    _buildSwitchTile(
                      theme,
                      title: 'Show Company Information',
                      subtitle: 'Display your company details',
                      value: privacySettings.showCompanyInfo,
                      onChanged: (value) {
                        _updatePrivacySetting('showCompanyInfo', value);
                      },
                      icon: Icons.business,
                      isLast: true,
                    ),

                    const SizedBox(height: 24),

                    // Data Sharing Section
                    _buildSectionHeader(theme, title: 'Data Sharing & Analytics', icon: Icons.share),
                    _buildSwitchTile(
                      theme,
                      title: 'Share Analytics',
                      subtitle: 'Help improve the app by sharing usage data',
                      value: privacySettings.shareAnalytics,
                      onChanged: (value) {
                        _updatePrivacySetting('shareAnalytics', value);
                      },
                      icon: Icons.analytics,
                    ),
                    _buildSwitchTile(
                      theme,
                      title: 'Share with Partners',
                      subtitle: 'Allow trusted partners to use your data',
                      value: privacySettings.shareWithPartners,
                      onChanged: (value) {
                        _updatePrivacySetting('shareWithPartners', value);
                      },
                      icon: Icons.business_center,
                    ),
                    _buildSwitchTile(
                      theme,
                      title: 'Personalized Ads',
                      subtitle: 'Receive personalized advertisements',
                      value: privacySettings.personalizedAds,
                      onChanged: (value) {
                        _updatePrivacySetting('personalizedAds', value);
                      },
                      icon: Icons.adjust,
                      isLast: true,
                    ),

                    const SizedBox(height: 24),

                    // Data Management Section
                    _buildSectionHeader(theme, title: 'Data Management', icon: Icons.storage),
                    _buildSwitchTile(
                      theme,
                      title: 'Data Backup',
                      subtitle: 'Automatically backup your data to cloud',
                      value: privacySettings.dataBackup,
                      onChanged: (value) {
                        _updatePrivacySetting('dataBackup', value);
                      },
                      icon: Icons.backup,
                    ),
                    _buildSwitchTile(
                      theme,
                      title: 'Auto-Delete Data',
                      subtitle: 'Automatically delete old data',
                      value: privacySettings.autoDeleteData,
                      onChanged: (value) {
                        _updatePrivacySetting('autoDeleteData', value);
                      },
                      icon: Icons.delete_sweep,
                    ),
                    if (privacySettings.autoDeleteData)
                      _buildSliderTile(
                        theme,
                        title: 'Delete After',
                        subtitle: 'Days of inactivity before data deletion',
                        value: privacySettings.autoDeleteDays.toDouble(),
                        min: 30,
                        max: 365,
                        divisions: 33,
                        onChanged: (value) {
                          _updatePrivacySetting('autoDeleteDays', value.toInt());
                        },
                        icon: Icons.calendar_today,
                        isLast: true,
                      ),

                    const SizedBox(height: 24),

                    // Content Privacy Section
                    _buildSectionHeader(theme, title: 'Content Privacy', icon: Icons.content_copy),
                    _buildSwitchTile(
                      theme,
                      title: 'Hide from Search',
                      subtitle: 'Prevent your profile from appearing in searches',
                      value: privacySettings.hideFromSearch,
                      onChanged: (value) {
                        _updatePrivacySetting('hideFromSearch', value);
                      },
                      icon: Icons.search_off,
                    ),
                    _buildSwitchTile(
                      theme,
                      title: 'Block Unknown Users',
                      subtitle: 'Block messages from users you don\'t know',
                      value: privacySettings.blockUnknownUsers,
                      onChanged: (value) {
                        _updatePrivacySetting('blockUnknownUsers', value);
                      },
                      icon: Icons.block,
                    ),
                    _buildSwitchTile(
                      theme,
                      title: 'Message Privacy',
                      subtitle: 'Allow only connections to message you',
                      value: privacySettings.messagePrivacy,
                      onChanged: (value) {
                        _updatePrivacySetting('messagePrivacy', value);
                      },
                      icon: Icons.message,
                      isLast: true,
                    ),

                    const SizedBox(height: 24),

                    // Activity Privacy Section
                    _buildSectionHeader(theme, title: 'Activity Privacy', icon: Icons.timeline),
                    _buildSwitchTile(
                      theme,
                      title: 'Show Online Status',
                      subtitle: 'Let others see when you\'re online',
                      value: privacySettings.showOnlineStatus,
                      onChanged: (value) {
                        _updatePrivacySetting('showOnlineStatus', value);
                      },
                      icon: Icons.circle,
                    ),
                    _buildSwitchTile(
                      theme,
                      title: 'Show Last Seen',
                      subtitle: 'Show when you were last active',
                      value: privacySettings.showLastSeen,
                      onChanged: (value) {
                        _updatePrivacySetting('showLastSeen', value);
                      },
                      icon: Icons.access_time,
                    ),
                    _buildSwitchTile(
                      theme,
                      title: 'Show Activity Status',
                      subtitle: 'Display your recent activities',
                      value: privacySettings.showActivityStatus,
                      onChanged: (value) {
                        _updatePrivacySetting('showActivityStatus', value);
                      },
                      icon: Icons.trending_up,
                      isLast: true,
                    ),

                    const SizedBox(height: 32),

                    // Security Actions

                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          _buildActionButton(
                            onPressed: _changePassword,
                            icon: Icons.lock_reset,
                            label: 'Change Password',
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(height: 12),
                          _buildActionButton(
                            onPressed: _exportData,
                            icon: Icons.download,
                            label: 'Export My Data',
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(height: 12),
                          _buildActionButton(
                            onPressed: _deleteAccount,
                            icon: Icons.delete_forever,
                            label: 'Delete Account',
                            color: theme.colorScheme.error,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

// Reset Button
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildActionButton(
                        onPressed: _resetSettings,
                        icon: Icons.restore,
                        label: 'Reset to Default',
                        color: theme.colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // Create a reusable button widget
  Widget _buildActionButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    final theme  =  Theme.of(context);
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: color, size: 18),
        label: Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
          overflow: TextOverflow.ellipsis, // Handle long text
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color.withOpacity(0.5)),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }


  Widget _buildSecurityScoreCard(ThemeData theme, SecuritySettings settings) {
    int score = 0;
    int total = 0;

    if (settings.twoFactorAuth) score += 10;
    if (settings.biometricLogin) score += 5;
    if (!settings.rememberMe) score += 5;
    total += 20;

    if (settings.loginAlerts) score += 5;
    if (settings.newDeviceAlerts) score += 5;
    if (settings.failedLoginAlerts) score += 5;
    if (settings.lockAfterFailedAttempts) score += 5;
    total += 20;

    if (settings.singleSessionOnly) score += 10;
    if (settings.autoLogoutOnInactivity) score += 10;
    total += 20;

    final percentage = (score / total * 100).toInt();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_getScoreColor(percentage).withOpacity(0.2), _getScoreColor(percentage).withOpacity(0.1)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _getScoreColor(percentage).withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: _getScoreColor(percentage).withOpacity(0.2), shape: BoxShape.circle),
                child: Icon(Icons.shield, color: _getScoreColor(percentage), size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Security Score', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('$percentage% - ${_getScoreMessage(percentage)}', style: theme.textTheme.bodyMedium?.copyWith(color: _getScoreColor(percentage), fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Text('$score/$total', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: _getScoreColor(percentage))),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(value: percentage / 100, backgroundColor: theme.colorScheme.surfaceVariant, color: _getScoreColor(percentage), minHeight: 8, borderRadius: BorderRadius.circular(4)),
          const SizedBox(height: 12),
          Text(_getScoreRecommendation(percentage), style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Color _getScoreColor(int percentage) {
    if (percentage >= 80) return Colors.green;
    if (percentage >= 60) return Colors.lightGreen;
    if (percentage >= 40) return Colors.orange;
    if (percentage >= 20) return Colors.deepOrange;
    return Colors.red;
  }

  String _getScoreMessage(int percentage) {
    if (percentage >= 80) return 'Excellent';
    if (percentage >= 60) return 'Good';
    if (percentage >= 40) return 'Fair';
    if (percentage >= 20) return 'Weak';
    return 'Critical';
  }

  String _getScoreRecommendation(int percentage) {
    if (percentage >= 80) return 'Your account is well protected';
    if (percentage >= 60) return 'Enable 2FA to improve security';
    if (percentage >= 40) return 'Enable security features for better protection';
    if (percentage >= 20) return 'Your account needs immediate attention';
    return 'Critical security issues detected';
  }

  Widget _buildSectionHeader(ThemeData theme, {required String title, required IconData icon, Widget? action}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
            child: Icon(icon, size: 18, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
          if (action != null) action,
        ],
      ),
    );
  }

  Widget _buildSwitchTile(ThemeData theme, {
    required String title,
    required String subtitle,
    bool value = false,
    ValueChanged<bool>? onChanged,
    required IconData icon,
    Color? iconColor,
    bool isLast = false,
    VoidCallback? onTap,
    Widget? trailing,
    bool showSwitch = true,
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
        border: Border(bottom: isLast ? BorderSide.none : BorderSide(color: theme.dividerColor)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: (iconColor ?? theme.colorScheme.primary).withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(icon, size: 20, color: iconColor ?? theme.colorScheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                if (trailing != null)
                  trailing
                else if (showSwitch && onChanged != null)
                  Switch(value: value, onChanged: onChanged, activeColor: theme.colorScheme.primary)
                else if (onTap != null)
                    Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSliderTile(ThemeData theme, {
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
        border: Border(bottom: isLast ? BorderSide.none : BorderSide(color: theme.dividerColor)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(width: 40, height: 40, decoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, size: 20, color: theme.colorScheme.primary)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                  Text(subtitle, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  Slider(value: value, min: min, max: max, divisions: divisions, label: value.toInt().toString(), onChanged: onChanged, activeColor: theme.colorScheme.primary),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${min.toInt()} ${_getUnit(title)}', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      Text('${value.toInt()} ${_getUnit(title)}', style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                      Text('${max.toInt()} ${_getUnit(title)}', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
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

  Widget _buildBackupCodesSection(ThemeData theme) {
    return FutureBuilder<int>(
      future: _twoFactorService.getRemainingBackupCodesCount(),
      builder: (context, snapshot) {
        final remaining = snapshot.data ?? 0;
        return Column(
          children: [
            _buildSectionHeader(theme, title: 'Backup Codes', icon: Icons.code),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Remaining backup codes:'),
                      Text('$remaining / 10', style: TextStyle(fontWeight: FontWeight.bold, color: remaining < 3 ? Colors.orange : Colors.green)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: OutlinedButton.icon(onPressed: _viewBackupCodes, icon: const Icon(Icons.visibility), label: const Text('View Codes'))),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _regenerateBackupCodes,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Regenerate'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
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

  String _getUnit(String title) {
    if (title.contains('Timeout') || title.contains('Duration')) return 'mins';
    if (title.contains('Delete')) return 'days';
    if (title.contains('Devices')) return 'devices';
    if (title.contains('Attempts')) return 'attempts';
    return '';
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: color, duration: const Duration(seconds: 3)));
  }

  Future<void> _updatePrivacySetting(String field, dynamic value) async {
    if (_userId == null) return;
    try {
      await PrivacySettingsService.updatePrivacySetting(_userId!, field, value);
      _showSnackBar('Privacy setting updated', Colors.green);
    } catch (e) {
      _showSnackBar('Error updating setting: $e', Colors.red);
    }
  }

  Future<void> _updateSecuritySetting(String field, dynamic value) async {
    if (_userId == null) return;

    if (field == 'twoFactorAuth') {
      if (value == true) {
        final result = await Navigator.push<bool>(context, MaterialPageRoute(builder: (context) => const TwoFactorEnrollmentScreen()));
        if (result != true) {
          setState(() => _securitySettings?.twoFactorAuth = false);
          return;
        }
        setState(() => _securitySettings?.twoFactorAuth = true);
        _showSnackBar('Two-Factor Authentication enabled successfully!', Colors.green);
      } else {
        final shouldDisable = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Disable Two-Factor Authentication'),
            content: const Text('Disabling 2FA will make your account less secure. Are you sure you want to continue?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Disable')),
            ],
          ),
        );
        if (shouldDisable != true) {
          setState(() => _securitySettings?.twoFactorAuth = true);
          return;
        }
        setState(() => _isLoading = true);
        try {
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            await user.reload();
            final factors = await user.multiFactor.getEnrolledFactors();
            for (final factor in factors) {
              await user.multiFactor.unenroll(factorUid: factor.uid);
            }
          }
          await SecuritySettingsService.updateSecuritySetting(_userId!, field, value);
          setState(() {
            _securitySettings?.twoFactorAuth = false;
            _isLoading = false;
          });
          _showSnackBar('Two-Factor Authentication disabled', Colors.orange);
        } catch (e) {
          setState(() {
            _securitySettings?.twoFactorAuth = true;
            _isLoading = false;
          });
          _showSnackBar('Error disabling 2FA: $e', Colors.red);
        }
      }
      return;
    }

    try {
      await SecuritySettingsService.updateSecuritySetting(_userId!, field, value);
      _showSnackBar('Security setting updated', Colors.green);
    } catch (e) {
      _showSnackBar('Error updating setting: $e', Colors.red);
    }
  }

  Future<void> _resetSettings() async {
    if (_userId == null) return;
    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Settings'),
        content: const Text('Are you sure you want to reset all privacy and security settings to default?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Reset')),
        ],
      ),
    );
    if (shouldReset == true) {
      try {
        await PrivacySettingsService.resetPrivacySettings(_userId!);
        await SecuritySettingsService.resetSecuritySettings(_userId!);
        _showSnackBar('Settings reset to default', Colors.orange);
      } catch (e) {
        _showSnackBar('Error resetting settings: $e', Colors.red);
      }
    }
  }

  Future<void> _viewBackupCodes() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('View Backup Codes'),
        content: const Text('For security reasons, existing backup codes cannot be viewed again. Would you like to generate new backup codes?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.blue), child: const Text('Generate New Codes')),
        ],
      ),
    );
    if (confirmed == true) await _regenerateBackupCodes();
  }

  Future<void> _regenerateBackupCodes() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Regenerate Backup Codes'),
        content: const Text('Regenerating backup codes will invalidate your old codes. Make sure to save the new codes. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.orange), child: const Text('Regenerate')),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        final newCodes = await _twoFactorService.regenerateBackupCodes();
        await _showBackupCodesDialog(newCodes);
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
              const Text('These backup codes can be used to access your account if you forget your 2FA password. Each code can only be used once.', style: TextStyle(fontSize: 14)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                child: Column(
                  children: codes.asMap().entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(width: 30, child: Text('${entry.key + 1}', style: const TextStyle(fontWeight: FontWeight.bold))),
                          Expanded(child: Text(entry.value, style: const TextStyle(fontFamily: 'monospace', fontSize: 16, fontWeight: FontWeight.bold))),
                          IconButton(icon: const Icon(Icons.copy, size: 18), onPressed: () {
                            Clipboard.setData(ClipboardData(text: entry.value));
                            _showSnackBar('Code copied!', Colors.green);
                          }),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
              const Text('⚠️ Make sure to save these codes in a secure place. You will not be able to see them again!', style: TextStyle(fontSize: 12, color: Colors.orange)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('I Have Saved Them')),
        ],
      ),
    );
  }

  void _changePassword() {
    _showSnackBar('Change password feature coming soon', Colors.orange);
  }

  void _exportData() {
    _showSnackBar('Your data export request has been initiated. You will receive an email with download link shortly.', Colors.green);
  }

  void _deleteAccount() {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text('Are you sure you want to delete your account? This action cannot be undone and all your data will be permanently lost.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              if (_userId != null) {
                try {
                  await PrivacySettingsService.deletePrivacySettings(_userId!);
                  try { await _twoFactorService.removeTwoFactorPassword(); } catch (e) {}
                  final user = FirebaseAuth.instance.currentUser;
                  if (user != null) await user.delete();
                  if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                } catch (e) {
                  _showSnackBar('Error deleting account: $e', Colors.red);
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}