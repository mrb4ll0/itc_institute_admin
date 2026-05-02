// pages/security_settings_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:itc_institute_admin/generalmethods/GeneralMethods.dart';

import '../../itc_logic/idservice/globalIdService.dart';
import '../../itc_logic/service/2FactorAuthService.dart';
import '../../itc_logic/service/securitySettingsService.dart';
import '../../model/securitySettingsModel.dart';
import '../ConnectedDeviceManagement/ConnectedDevicePage.dart';
import '../twoFactorAuthentication/twoFactorEnrollmentScreen.dart';


class SecuritySettingsPage extends StatefulWidget {
  final String email;
  const SecuritySettingsPage({super.key, required this.email});

  @override
  State<SecuritySettingsPage> createState() => _SecuritySettingsPageState();
}

class _SecuritySettingsPageState extends State<SecuritySettingsPage> {
  SecuritySettings? _settings;
  bool _isLoading = true;
  String? _userId;
  Stream<SecuritySettings>? _settingsStream;
  List<Map<String, dynamic>> _activeSessions = [];
  // Add this at the top of your state class
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
        _userId =GlobalIdService.firestoreId;

        // Set up real-time stream for settings
        _settingsStream = SecuritySettingsService.streamSecuritySettings(GlobalIdService.firestoreId);

        // Load active sessions
        SecuritySettingsService.getActiveSessions(GlobalIdService.firestoreId).listen((sessions) {
          setState(() {
            _activeSessions = sessions;
          });
        });

        // Initial load
        final settings = await SecuritySettingsService.getUserSecuritySettings(GlobalIdService.firestoreId);
        debugPrint("two factor settings is ${settings.twoFactorAuth}");
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
      debugPrint('Error loading security settings: $e');
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
          title: const Text('Security Settings'),
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
        title: const Text('Security Settings'),
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
      body: StreamBuilder<SecuritySettings>(
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
                // Security Score Card
                _buildSecurityScoreCard(theme, settings),

                // Authentication Security
                _buildSectionHeader(
                  theme,
                  title: 'Authentication Security',
                  icon: Icons.fingerprint,
                ),

                _buildSwitchTile(
                  theme,
                  title: 'Two-Factor Authentication',
                  subtitle: 'Add an extra layer of security',
                  value: settings.twoFactorAuth,
                  onChanged: (value) {
                    _updateSetting('twoFactorAuth', value);
                  },
                  icon: Icons.security,
                  iconColor: Colors.green,
                  onTap: ()
                    {
                      GeneralMethods.navigateTo(context, TwoFactorEnrollmentScreen());
                    }
                ),

                _buildSwitchTile(
                  theme,
                  title: 'Biometric Login',
                  subtitle: 'Use fingerprint or face recognition',
                  value: settings.biometricLogin,
                  onChanged: (value) {
                    _updateSetting('biometricLogin', value);
                  },
                  icon: Icons.fingerprint,
                ),

                _buildSwitchTile(
                  theme,
                  title: 'Remember Me',
                  subtitle: 'Stay logged in on this device',
                  value: settings.rememberMe,
                  onChanged: (value) {
                    _updateSetting('rememberMe', value);
                  },
                  icon: Icons.device_unknown,
                ),

                _buildSliderTile(
                  theme,
                  title: 'Session Timeout',
                  subtitle: 'Minutes before automatic logout',
                  value: settings.sessionTimeoutMinutes.toDouble(),
                  min: 5,
                  max: 120,
                  divisions: 23,
                  onChanged: (value) {
                    _updateSetting('sessionTimeoutMinutes', value.toInt());
                  },
                  icon: Icons.timer,
                  isLast: true,
                ),

                const SizedBox(height: 24),

                // Password Security
                _buildSectionHeader(
                  theme,
                  title: 'Password Security',
                  icon: Icons.lock,
                ),

                _buildSwitchTile(
                  theme,
                  title: 'Require Strong Password',
                  subtitle: 'Must include uppercase, lowercase, numbers, and symbols',
                  value: settings.requireStrongPassword,
                  onChanged: (value) {
                    _updateSetting('requireStrongPassword', value);
                  },
                  icon: Icons.password,
                ),

                _buildSwitchTile(
                  theme,
                  title: 'Password Expiry',
                  subtitle: 'Force password change after period',
                  value: settings.passwordExpiry,
                  onChanged: (value) {
                    _updateSetting('passwordExpiry', value);
                  },
                  icon: Icons.update,
                ),

                if (settings.passwordExpiry)
                  _buildSliderTile(
                    theme,
                    title: 'Expiry Period',
                    subtitle: 'Days until password expires',
                    value: settings.passwordExpiryDays.toDouble(),
                    min: 30,
                    max: 365,
                    divisions: 33,
                    onChanged: (value) {
                      _updateSetting('passwordExpiryDays', value.toInt());
                    },
                    icon: Icons.calendar_today,
                  ),

                _buildSwitchTile(
                  theme,
                  title: 'Prevent Password Reuse',
                  subtitle: 'Cannot use recently used passwords',
                  value: settings.preventPasswordReuse,
                  onChanged: (value) {
                    _updateSetting('preventPasswordReuse', value);
                  },
                  icon: Icons.history,
                ),

                if (settings.preventPasswordReuse)
                  _buildSliderTile(
                    theme,
                    title: 'Password History',
                    subtitle: 'Number of passwords to remember',
                    value: settings.passwordHistoryCount.toDouble(),
                    min: 3,
                    max: 10,
                    divisions: 7,
                    onChanged: (value) {
                      _updateSetting('passwordHistoryCount', value.toInt());
                    },
                    icon: Icons.list,
                    isLast: true,
                  ),

                const SizedBox(height: 24),

                // Login Security
                _buildSectionHeader(
                  theme,
                  title: 'Login Security',
                  icon: Icons.login,
                ),

                _buildSwitchTile(
                  theme,
                  title: 'Login Alerts',
                  subtitle: 'Get notified on new logins',
                  value: settings.loginAlerts,
                  onChanged: (value) {
                    _updateSetting('loginAlerts', value);
                  },
                  icon: Icons.notifications_active,
                ),

                _buildSwitchTile(
                  theme,
                  title: 'New Device Alerts',
                  subtitle: 'Alert when logging in from new device',
                  value: settings.newDeviceAlerts,
                  onChanged: (value) {
                    _updateSetting('newDeviceAlerts', value);
                  },
                  icon: Icons.devices,
                ),

                _buildSwitchTile(
                  theme,
                  title: 'Failed Login Alerts',
                  subtitle: 'Get notified on failed login attempts',
                  value: settings.failedLoginAlerts,
                  onChanged: (value) {
                    _updateSetting('failedLoginAlerts', value);
                  },
                  icon: Icons.warning,
                ),

                _buildSliderTile(
                  theme,
                  title: 'Max Failed Attempts',
                  subtitle: 'Attempts before account lock',
                  value: settings.maxFailedAttempts.toDouble(),
                  min: 3,
                  max: 10,
                  divisions: 7,
                  onChanged: (value) {
                    _updateSetting('maxFailedAttempts', value.toInt());
                  },
                  icon: Icons.sms_outlined,
                ),

                _buildSwitchTile(
                  theme,
                  title: 'Lock After Failed Attempts',
                  subtitle: 'Temporarily lock account after failed attempts',
                  value: settings.lockAfterFailedAttempts,
                  onChanged: (value) {
                    _updateSetting('lockAfterFailedAttempts', value);
                  },
                  icon: Icons.lock,
                ),

                if (settings.lockAfterFailedAttempts)
                  _buildSliderTile(
                    theme,
                    title: 'Lock Duration',
                    subtitle: 'Minutes account remains locked',
                    value: settings.lockDurationMinutes.toDouble(),
                    min: 15,
                    max: 120,
                    divisions: 21,
                    onChanged: (value) {
                      _updateSetting('lockDurationMinutes', value.toInt());
                    },
                    icon: Icons.timer,
                    isLast: true,
                  ),

                const SizedBox(height: 24),

                // Session Management
                _buildSectionHeader(
                  theme,
                  title: 'Session Management',
                  icon: Icons.web,
                ),

                _buildSwitchTile(
                  theme,
                  title: 'Single Session Only',
                  subtitle: 'Only one active session at a time',
                  value: settings.singleSessionOnly,
                  onChanged: (value) {
                    _updateSetting('singleSessionOnly', value);
                  },
                  icon: Icons.devices_other,
                ),

                _buildSwitchTile(
                  theme,
                  title: 'Auto Logout on Inactivity',
                  subtitle: 'Logout when inactive',
                  value: settings.autoLogoutOnInactivity,
                  onChanged: (value) {
                    _updateSetting('autoLogoutOnInactivity', value);
                  },
                  icon: Icons.logout,
                ),

                if (settings.autoLogoutOnInactivity)
                  _buildSliderTile(
                    theme,
                    title: 'Inactivity Timeout',
                    subtitle: 'Minutes of inactivity before logout',
                    value: settings.inactivityTimeoutMinutes.toDouble(),
                    min: 5,
                    max: 60,
                    divisions: 11,
                    onChanged: (value) {
                      _updateSetting('inactivityTimeoutMinutes', value.toInt());
                    },
                    icon: Icons.timer_off,
                  ),

                // Active Sessions Section
                const SizedBox(height: 24),
                _buildSectionHeader(
                  theme,
                  title: 'Active Sessions',
                  icon: Icons.devices,
                ),

                if (_activeSessions.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: Text(
                        'No active sessions',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                else
                  ..._activeSessions.map((session) => _buildSessionTile(theme, session)),

                if (_activeSessions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: OutlinedButton.icon(
                      onPressed: _terminateAllOtherSessions,
                      icon: Icon(
                        Icons.logout,
                        size: 18,
                        color: theme.colorScheme.error,
                      ),
                      label: Text(
                        'Terminate All Other Sessions',
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

                const SizedBox(height: 24),

                // Device Management
                _buildSectionHeader(
                  theme,
                  title: 'Device Management',
                  icon: Icons.smartphone,
                ),

                _buildSwitchTile(
                  theme,
                  title: 'Device Management',
                  subtitle: 'Manage connected devices',
                  value: settings.deviceManagement,
                  onChanged: (value) {
                    _updateSetting('deviceManagement', value);
                  },
                  icon: Icons.settings_ethernet,
                ),

                _buildSwitchTile(
                  theme,
                  title: 'Allow Multiple Devices',
                  subtitle: 'Use account on multiple devices',
                  value: settings.allowMultipleDevices,
                  onChanged: (value) {
                    _updateSetting('allowMultipleDevices', value);
                  },
                  icon: Icons.devices,
                ),

                if (settings.allowMultipleDevices)
                  _buildSliderTile(
                    theme,
                    title: 'Max Devices Allowed',
                    subtitle: 'Number of devices allowed',
                    value: settings.maxDevicesAllowed.toDouble(),
                    min: 1,
                    max: 10,
                    divisions: 9,
                    onChanged: (value) {
                      _updateSetting('maxDevicesAllowed', value.toInt());
                    },
                    icon: Icons.devices,
                    isLast: true,
                  ),

                const SizedBox(height: 24),

                // IP & Location Security
                _buildSectionHeader(
                  theme,
                  title: 'IP & Location Security',
                  icon: Icons.location_on,
                ),

                _buildSwitchTile(
                  theme,
                  title: 'IP Whitelist',
                  subtitle: 'Only allow specific IP addresses',
                  value: settings.ipWhitelist,
                  onChanged: (value) {
                    _updateSetting('ipWhitelist', value);
                  },
                  icon: Icons.dns,
                ),

                _buildSwitchTile(
                  theme,
                  title: 'Location Restriction',
                  subtitle: 'Only allow access from specific countries',
                  value: settings.locationRestriction,
                  onChanged: (value) {
                    _updateSetting('locationRestriction', value);
                  },
                  icon: Icons.public,
                  isLast: true,
                ),

                const SizedBox(height: 24),

                // Data Security
                _buildSectionHeader(
                  theme,
                  title: 'Data Security',
                  icon: Icons.data_usage,
                ),

                _buildSwitchTile(
                  theme,
                  title: 'Encrypt Data',
                  subtitle: 'Encrypt sensitive data',
                  value: settings.encryptData,
                  onChanged: (value) {
                    _updateSetting('encryptData', value);
                  },
                  icon: Icons.enhanced_encryption,
                ),

                _buildSwitchTile(
                  theme,
                  title: 'Backup Data',
                  subtitle: 'Automatically backup your data',
                  value: settings.backupData,
                  onChanged: (value) {
                    _updateSetting('backupData', value);
                  },
                  icon: Icons.backup,
                ),

                if (settings.backupData)
                  _buildSliderTile(
                    theme,
                    title: 'Backup Frequency',
                    subtitle: 'Days between automatic backups',
                    value: settings.backupFrequencyDays.toDouble(),
                    min: 1,
                    max: 30,
                    divisions: 29,
                    onChanged: (value) {
                      _updateSetting('backupFrequencyDays', value.toInt());
                    },
                    icon: Icons.calendar_today,
                    isLast: true,
                  ),

                const SizedBox(height: 32),

                // Security Actions
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _changePassword,
                        icon: Icon(
                          Icons.lock_reset,
                          color: theme.colorScheme.primary,
                          size: 18,
                        ),
                        label: Text(
                          'Change Password',
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
                        onPressed: _setupRecovery,
                        icon: Icon(
                          Icons.restore,
                          color: theme.colorScheme.primary,
                          size: 18,
                        ),
                        label: Text(
                          'Setup Recovery Options',
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
                        onPressed: _viewSecurityLog,
                        icon: Icon(
                          Icons.history,
                          color: theme.colorScheme.primary,
                          size: 18,
                        ),
                        label: Text(
                          'View Security Log',
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

  Widget _buildSecurityScoreCard(ThemeData theme, SecuritySettings settings) {
    // Calculate security score
    int score = 0;
    int total = 0;

    // Authentication Security (max 20 points)
    if (settings.twoFactorAuth) score += 10;
    if (settings.biometricLogin) score += 5;
    if (!settings.rememberMe) score += 5;
    total += 20;

    // Password Security (max 20 points)
    if (settings.requireStrongPassword) score += 10;
    if (settings.passwordExpiry) score += 5;
    if (settings.preventPasswordReuse) score += 5;
    total += 20;

    // Login Security (max 20 points)
    if (settings.loginAlerts) score += 5;
    if (settings.newDeviceAlerts) score += 5;
    if (settings.failedLoginAlerts) score += 5;
    if (settings.lockAfterFailedAttempts) score += 5;
    total += 20;

    // Session Management (max 20 points)
    if (settings.singleSessionOnly) score += 10;
    if (settings.autoLogoutOnInactivity) score += 10;
    total += 20;

    // Data Security (max 20 points)
    if (settings.encryptData) score += 10;
    if (settings.backupData) score += 10;
    total += 20;

    final percentage = (score / total * 100).toInt();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _getScoreColor(percentage).withOpacity(0.2),
            _getScoreColor(percentage).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getScoreColor(percentage).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getScoreColor(percentage).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.shield,
                  color: _getScoreColor(percentage),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Security Score',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$percentage% - ${_getScoreMessage(percentage)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: _getScoreColor(percentage),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$score/$total',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: _getScoreColor(percentage),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: theme.colorScheme.surfaceVariant,
            color: _getScoreColor(percentage),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 12),
          Text(
            _getScoreRecommendation(percentage),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
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
        bool value = false,
        ValueChanged<bool>? onChanged,
        required IconData icon,
        Color? iconColor,
        bool isLast = false,
        VoidCallback? onTap,           // New: for navigation
        Widget? trailing,               // New: custom trailing widget
        bool showSwitch = true,        // New: whether to show switch or not
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap ?? (showSwitch && onChanged != null ? null : null),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Icon
                Container(
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
                const SizedBox(width: 12),

                // Title and Subtitle
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
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

                // Trailing Widget
                if (trailing != null)
                  trailing
                else if (showSwitch && onChanged != null)
                  Switch(
                    value: value,
                    onChanged: onChanged,
                    activeColor: theme.colorScheme.primary,
                  )
                else if (onTap != null)
                    Icon(
                      Icons.chevron_right,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
              ],
            ),
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

  Widget _buildSessionTile(ThemeData theme, Map<String, dynamic> session) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.dividerColor,
        ),
      ),
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
              _getDeviceIcon(session['deviceType']),
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
                  session['deviceName'] ?? 'Unknown Device',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Last active: ${_formatDate(session['lastActivity'])}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  'IP: ${session['ipAddress']}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _terminateSession(session['sessionId']),
            icon: Icon(
              Icons.logout,
              size: 20,
              color: theme.colorScheme.error,
            ),
            tooltip: 'Terminate Session',
          ),
        ],
      ),
    );
  }

  IconData _getDeviceIcon(String deviceType) {
    switch (deviceType.toLowerCase()) {
      case 'mobile':
        return Icons.smartphone;
      case 'tablet':
        return Icons.tablet;
      case 'web':
        return Icons.computer;
      default:
        return Icons.devices;
    }
  }

  String _getUnit(String title) {
    if (title.contains('Timeout') || title.contains('Duration')) {
      return 'mins';
    }
    if (title.contains('Days') || title.contains('Period')) {
      return 'days';
    }
    if (title.contains('Devices')) {
      return 'devices';
    }
    if (title.contains('Attempts')) {
      return 'attempts';
    }
    return '';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
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
          // Get enrolled factors and unenroll them (for SMS 2FA)
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            await user.reload();
            final factors = await user.multiFactor.getEnrolledFactors();

            for (final factor in factors) {
              await user.multiFactor.unenroll(factorUid: factor.uid);
            }
          }

          // Also remove password-based 2FA if exists
          // try {
          //   await _twoFactorService.removeTwoFactorPassword();
          // } catch (e) {
          //   // Ignore if no password 2FA exists
          //   debugPrint('No password 2FA to remove: $e');
          // }

          // Update Firestore
          await SecuritySettingsService.updateSecuritySetting(_userId!, field, value);

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

    // Special handling for Login Alerts (no special action needed, just update)
    if (field == 'loginAlerts') {
      try {
        await SecuritySettingsService.updateSecuritySetting(_userId!, field, value);
        _showSnackBar('Login alerts ${value ? "enabled" : "disabled"}', Colors.green);
      } catch (e) {
        _showSnackBar('Error updating setting: $e', Colors.red);
        // Revert the toggle
        setState(() {
          if (field == 'loginAlerts') _settings?.loginAlerts = !value;
        });
      }
      return;
    }

    // Special handling for Device Management (navigate to connected devices)
    if (field == 'deviceManagement') {
      if (value == true) {
        // Navigate to Connected Devices page when enabled
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>  DeviceManagementPage(userId: GlobalIdService.firestoreId, email: widget.email),
          ),
        );
        // No need to update the setting, just navigate
        setState(() {
          _settings?.deviceManagement = false; // Revert since it's just a navigation trigger
        });
      }
      return;
    }

    // Special handling for Session Timeout
    if (field == 'sessionTimeout') {
      if (value == true) {
        // Show dialog to select timeout duration
        final selectedMinutes = await _showTimeoutDialog();
        if (selectedMinutes != null) {
          await SecuritySettingsService.updateSecuritySetting(_userId!, 'sessionTimeoutMinutes', selectedMinutes);
          await SecuritySettingsService.updateSecuritySetting(_userId!, field, value);
          _showSnackBar('Session timeout set to $selectedMinutes minutes', Colors.green);
        } else {
          // User cancelled, revert the toggle
          setState(() {
            _settings?.sessionTimeout = false;
          });
          return;
        }
      } else {
        // Disabling session timeout
        await SecuritySettingsService.updateSecuritySetting(_userId!, field, value);
        _showSnackBar('Session timeout disabled', Colors.green);
      }

      setState(() {
        _settings?.sessionTimeout = value;
      });
      return;
    }

    // Normal update for other fields
    try {
      await SecuritySettingsService.updateSecuritySetting(_userId!, field, value);

      // Update local state

      _showSnackBar('Setting updated', Colors.green);
    } catch (e) {
      _showSnackBar('Error updating setting: $e', Colors.red);
    }
  }

// Helper method for timeout dialog
  Future<int?> _showTimeoutDialog() async {
    int selectedMinutes = 30;

    return showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Session Timeout'),
        content: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Select how long before automatic logout:'),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: selectedMinutes,
                  items: [5, 15, 30, 60, 120].map((minutes) {
                    return DropdownMenuItem(
                      value: minutes,
                      child: Text('$minutes minutes'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedMinutes = value!;
                    });
                  },
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, selectedMinutes),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
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
          'Are you sure you want to reset all security settings to default?',
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
        await SecuritySettingsService.resetSecuritySettings(_userId!);

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

  Future<void> _terminateSession(String sessionId) async {
    try {
      await SecuritySettingsService.terminateSession(sessionId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session terminated'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error terminating session: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _terminateAllOtherSessions() async {
    if (_userId == null) return;

    final theme = Theme.of(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: Text(
          'Terminate Sessions',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to terminate all other active sessions? You will be logged out from all other devices.',
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
            child: const Text('Terminate'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await SecuritySettingsService.terminateAllOtherSessions(
          _userId!,
          '', // You need to pass current session ID
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All other sessions terminated'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error terminating sessions: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _changePassword() {
    // Implement change password functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Change password feature coming soon'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _setupRecovery() {
    // Implement recovery options setup
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Recovery options feature coming soon'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _viewSecurityLog() {
    // Implement security log view
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Security log feature coming soon'),
        backgroundColor: Colors.orange,
      ),
    );
  }
}