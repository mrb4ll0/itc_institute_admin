// pages/device_management_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:itc_institute_admin/itc_logic/service/ConnectedDeviceService.dart';

import '../../itc_logic/localDB/sharedPreference.dart';
import '../../model/ConnectedDevice.dart';

class DeviceManagementPage extends StatefulWidget {
  final String userId;
  final String email;

  const DeviceManagementPage({
    Key? key,
    required this.userId,
    required this.email,
  }) : super(key: key);

  @override
  State<DeviceManagementPage> createState() => _DeviceManagementPageState();
}

class _DeviceManagementPageState extends State<DeviceManagementPage> {
  List<ConnectedDevice> _devices = [];
  bool _isLoading = true;
  String? _currentDeviceId;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    setState(() => _isLoading = true);

    try {
      // Load from Firestore
      final devices = await ConnectedDeviceService.getUserDevicesFromFirestore(widget.userId);
      _currentDeviceId = await UserPreferences.getCurrentDeviceId();

      setState(() {
        _devices = devices;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading devices: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _blockDevice(String deviceId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block Device'),
        content: const Text('Are you sure you want to block this device?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Block'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ConnectedDeviceService.blockDevice(widget.userId, deviceId, widget.email);
      await _loadDevices();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Device blocked successfully')),
      );
    }
  }

  Future<void> _removeDevice(String deviceId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Device'),
        content: const Text('Are you sure you want to remove this device?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ConnectedDeviceService.removeDevice(widget.userId, deviceId, widget.email);
      await _loadDevices();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Device removed successfully')),
      );
    }
  }

  Future<void> _setAdminDevice(String deviceId) async {
    await ConnectedDeviceService.setAdminDevice(widget.userId, deviceId, widget.email);
    await _loadDevices();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Admin device updated successfully')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Management'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _devices.isEmpty
          ? const Center(child: Text('No devices found'))
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _devices.length,
        itemBuilder: (context, index) {
          final device = _devices[index];
          final isCurrentDevice = device.deviceId == _currentDeviceId;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Column(
              children: [
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: device.getStatusColor().withOpacity(0.1),
                    child: Text(
                      device.getStatusIcon(),
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          device.deviceName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (device.isAdminDevice)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'ADMIN',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      if (isCurrentDevice)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'CURRENT',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text('📍 ${device.location}'),
                      Text('🌐 ${device.ipAddress}'),
                      Text('📱 ${device.deviceType.toUpperCase()}'),
                      Text(
                        'Last active: ${DateFormat('MMM dd, yyyy hh:mm a').format(device.lastActiveAt)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      if (device.status == DeviceStatus.blocked)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'BLOCKED',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  isThreeLine: true,
                ),
                if (device.status != DeviceStatus.blocked && !isCurrentDevice)
                  ButtonBar(
                    children: [
                      if (!device.isAdminDevice)
                        TextButton.icon(
                          onPressed: () => _setAdminDevice(device.deviceId),
                          icon: const Icon(Icons.admin_panel_settings, size: 18),
                          label: const Text('Set as Admin'),
                        ),
                      TextButton.icon(
                        onPressed: () => _blockDevice(device.deviceId),
                        icon: const Icon(Icons.block, size: 18),
                        label: const Text('Block'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.orange,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _removeDevice(device.deviceId),
                        icon: const Icon(Icons.delete, size: 18),
                        label: const Text('Remove'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}