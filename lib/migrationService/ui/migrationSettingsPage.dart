import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../migrationSettingsStrorage.dart';

enum MigrationTrigger {
  manual,           // User triggers manually
  everyLaunch,      // Every time app launches
  firstDailyLaunch, // First launch each day
  weekly,           // Once per week
  scheduled,        // Specific time each day
}

extension MigrationTriggerExtension on MigrationTrigger {
  String get displayName {
    switch (this) {
      case MigrationTrigger.manual:
        return 'Manual Only';
      case MigrationTrigger.everyLaunch:
        return 'Every App Launch';
      case MigrationTrigger.firstDailyLaunch:
        return 'First Launch Each Day';
      case MigrationTrigger.weekly:
        return 'Weekly';
      case MigrationTrigger.scheduled:
        return 'Scheduled Time';
    }
  }

  String get description {
    switch (this) {
      case MigrationTrigger.manual:
        return 'Migration runs only when you manually trigger it';
      case MigrationTrigger.everyLaunch:
        return 'Migration runs every time you open the app';
      case MigrationTrigger.firstDailyLaunch:
        return 'Migration runs once per day on first launch';
      case MigrationTrigger.weekly:
        return 'Migration runs once per week';
      case MigrationTrigger.scheduled:
        return 'Migration runs at a specific time each day';
    }
  }

  IconData get icon {
    switch (this) {
      case MigrationTrigger.manual:
        return Icons.touch_app;
      case MigrationTrigger.everyLaunch:
        return Icons.launch;
      case MigrationTrigger.firstDailyLaunch:
        return Icons.wb_sunny;
      case MigrationTrigger.weekly:
        return Icons.calendar_view_week;
      case MigrationTrigger.scheduled:
        return Icons.schedule;
    }
  }

  Color get color {
    switch (this) {
      case MigrationTrigger.manual:
        return Colors.blue;
      case MigrationTrigger.everyLaunch:
        return Colors.green;
      case MigrationTrigger.firstDailyLaunch:
        return Colors.orange;
      case MigrationTrigger.weekly:
        return Colors.purple;
      case MigrationTrigger.scheduled:
        return Colors.indigo;
    }
  }
}

class MigrationSettingsPage extends StatefulWidget {
  const MigrationSettingsPage({Key? key}) : super(key: key);

  @override
  State<MigrationSettingsPage> createState() => _MigrationSettingsPageState();
}

class _MigrationSettingsPageState extends State<MigrationSettingsPage> with TickerProviderStateMixin {
  MigrationTrigger _selectedTrigger = MigrationTrigger.firstDailyLaunch;
  bool _migrateOnWifiOnly = true;
  bool _migrateWhileCharging = false;
  bool _showNotifications = true;
  TimeOfDay? _scheduledTime = const TimeOfDay(hour: 2, minute: 0); // 2 AM default
  int _selectedDay = DateTime.monday;

  // Animation controllers
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final List<String> _weekDays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];

  @override
  void initState() {
    super.initState();
    _loadSavedSettings();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();
  }



  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedSettings() async {
    final settings = await MigrationSettingsStorage.loadSettings();

    setState(() {
      _selectedTrigger = settings['trigger'];
      _migrateOnWifiOnly = settings['wifiOnly'];
      _migrateWhileCharging = settings['whileCharging'];
      _showNotifications = settings['showNotifications'];
      _scheduledTime = settings['scheduledTime'];
      _selectedDay = settings['weeklyDay'];
    });

    debugPrint('Loaded migration settings: ${_selectedTrigger.displayName}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.05),
              Theme.of(context).colorScheme.background,
            ],
          ),
        ),
        child: CustomScrollView(
          slivers: [
            // App Bar
            SliverAppBar(
              expandedHeight: 120,
              floating: false,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                title: const Text(
                  'Migration Settings',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.secondary,
                      ],
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.cloud_upload,
                      size: 50,
                      color: Colors.white.withOpacity(0.2),
                    ),
                  ),
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.info_outline),
                  onPressed: _showInfoDialog,
                ),
                IconButton(
                  icon: const Icon(Icons.save),
                  onPressed: ()=>_saveSettings(context),
                ),
              ],
            ),

            // Main Content
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header
                          const SizedBox(height: 8),
                          Text(
                            'Choose how migration should run',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Select when data migration occurs automatically',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Migration Trigger Cards
                          ...MigrationTrigger.values.map((trigger) =>
                              _buildTriggerCard(trigger)
                          ),

                          const SizedBox(height: 24),

                          // Additional Settings
                          _buildAdditionalSettings(),

                          const SizedBox(height: 24),

                          // Summary Card
                          _buildSummaryCard(),

                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildTriggerCard(MigrationTrigger trigger) {
    final isSelected = _selectedTrigger == trigger;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: isSelected ? trigger.color.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedTrigger = trigger;
            });

            if(trigger == MigrationTrigger.scheduled){
              _selectTime();
            }

            // Haptic feedback
            HapticFeedback.selectionClick();
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? trigger.color : Colors.grey[300]!,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Icon with animated scale
                  AnimatedScale(
                    duration: const Duration(milliseconds: 300),
                    scale: isSelected ? 1.2 : 1.0,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isSelected ? trigger.color : trigger.color.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        trigger.icon,
                        color: isSelected ? Colors.white : trigger.color,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              trigger.displayName,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? trigger.color : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (isSelected)
                              Icon(Icons.check_circle, color: trigger.color, size: 16),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          trigger.description,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Additional config for specific triggers
                  if (trigger == MigrationTrigger.weekly && isSelected)
                    _buildWeeklySelector(),

                  if (trigger == MigrationTrigger.scheduled && isSelected)
                    _buildTimeSelector(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWeeklySelector() {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      child: DropdownButton<int>(
        value: _selectedDay,
        icon: const Icon(Icons.arrow_drop_down),
        elevation: 16,
        underline: Container(),
        onChanged: (int? newValue) {
          if (newValue != null) {
            setState(() {
              _selectedDay = newValue;
            });
          }
        },
        items: _weekDays.asMap().entries.map((entry) {
          return DropdownMenuItem<int>(
            value: entry.key,
            child: Text(entry.value),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTimeSelector() {
    return IconButton(
      icon: Icon(Icons.access_time, color: _selectedTrigger.color),
      onPressed: _selectTime,
    );
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _scheduledTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: _selectedTrigger.color,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _scheduledTime) {
      setState(() {
        _scheduledTime = picked;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Migration scheduled for ${picked.format(context)}'),
          backgroundColor: _selectedTrigger.color,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildAdditionalSettings() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings, color: Colors.grey[700], size: 20),
                const SizedBox(width: 8),
                Text(
                  'Additional Conditions',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // WiFi only
            SwitchListTile(
              title: const Text('WiFi Only'),
              subtitle: const Text('Only migrate when connected to WiFi'),
              value: _migrateOnWifiOnly,
              secondary: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.wifi, color: Colors.blue),
              ),
              onChanged: (value) {
                setState(() {
                  _migrateOnWifiOnly = value;
                });
              },
            ),

            // While charging
            SwitchListTile(
              title: const Text('While Charging'),
              subtitle: const Text('Only migrate when device is charging'),
              value: _migrateWhileCharging,
              secondary: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.battery_charging_full, color: Colors.green),
              ),
              onChanged: (value) {
                setState(() {
                  _migrateWhileCharging = value;
                });
              },
            ),

            // Show notifications
            SwitchListTile(
              title: const Text('Show Notifications'),
              subtitle: const Text('Get notified when migration runs'),
              value: _showNotifications,
              secondary: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.notifications, color: Colors.orange),
              ),
              onChanged: (value) {
                setState(() {
                  _showNotifications = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: _selectedTrigger.color.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: _selectedTrigger.color,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Migration Summary',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _selectedTrigger.color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Summary details
            _buildSummaryRow(
              'Trigger:',
              _selectedTrigger.displayName,
              _selectedTrigger.icon,
            ),
            _buildSummaryRow(
              'Network:',
              _migrateOnWifiOnly ? 'WiFi only' : 'Any network',
              Icons.network_check,
            ),
            _buildSummaryRow(
              'Charging:',
              _migrateWhileCharging ? 'Required' : 'Not required',
              Icons.battery_std,
            ),
            _buildSummaryRow(
              'Notifications:',
              _showNotifications ? 'Enabled' : 'Disabled',
              Icons.notifications,
            ),

            if (_selectedTrigger == MigrationTrigger.weekly)
              _buildSummaryRow(
                'Weekly on:',
                _weekDays[_selectedDay],
                Icons.calendar_today,
              ),

            if (_selectedTrigger == MigrationTrigger.scheduled && _scheduledTime != null)
              _buildSummaryRow(
                'Scheduled:',
                _scheduledTime!.format(context),
                Icons.schedule,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.grey[700]),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    _resetToDefaults();
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('RESET TO DEFAULTS'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: ()=>_saveSettings(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedTrigger.color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('SAVE SETTINGS'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue),
            SizedBox(width: 8),
            Text('About Migration'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Migration triggers determine when your data will be automatically synchronized.',
              style: TextStyle(color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            const Text(
              '• Manual: You control when migration happens\n'
                  '• Every launch: Always up-to-date but may use more battery\n'
                  '• First daily: Good balance of freshness and battery life\n'
                  '• Weekly: Best for battery saving\n'
                  '• Scheduled: Runs at a specific time each day',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('GOT IT'),
          ),
        ],
      ),
    );
  }

  void _resetToDefaults() async {
    setState(() {
      _selectedTrigger = MigrationTrigger.firstDailyLaunch;
      _migrateOnWifiOnly = true;
      _migrateWhileCharging = false;
      _showNotifications = true;
      _scheduledTime = const TimeOfDay(hour: 2, minute: 0);
      _selectedDay = DateTime.monday;
    });

    // Clear saved settings
    await MigrationSettingsStorage.clearSettings();

    // Save defaults
    await MigrationSettingsStorage.saveSettings(
      trigger: _selectedTrigger,
      wifiOnly: _migrateOnWifiOnly,
      whileCharging: _migrateWhileCharging,
      showNotifications: _showNotifications,
      scheduledTime: _scheduledTime,
      weeklyDay: _selectedDay,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Settings reset to defaults'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  void _saveSettings(mainContext) async {
    // Save to SharedPreferences
    await MigrationSettingsStorage.saveSettings(
      trigger: _selectedTrigger,
      wifiOnly: _migrateOnWifiOnly,
      whileCharging: _migrateWhileCharging,
      showNotifications: _showNotifications,
      scheduledTime: _scheduledTime,
      weeklyDay: _selectedDay,
    );

    // Show success message
    ScaffoldMessenger.of(mainContext).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Migration settings saved (${_selectedTrigger.displayName})',
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green[700],
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );

    // Haptic feedback
    HapticFeedback.heavyImpact();


  }


}