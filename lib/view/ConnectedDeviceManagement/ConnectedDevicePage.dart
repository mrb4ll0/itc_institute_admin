// pages/connected_devices_page.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../itc_logic/service/ConnectedDeviceService.dart';
import '../../model/ConnectedDevice.dart';


class ConnectedDevicesPage extends StatefulWidget {
  const ConnectedDevicesPage({Key? key}) : super(key: key);

  @override
  State<ConnectedDevicesPage> createState() => _ConnectedDevicesPageState();
}

class _ConnectedDevicesPageState extends State<ConnectedDevicesPage> {
  final ConnectedDeviceService _deviceService = ConnectedDeviceService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<ConnectedDevice> _devices = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final devices = await _deviceService.getConnectedDevicesFuture();
      setState(() {
        _devices = devices;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load devices: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _revokeDevice(ConnectedDevice device) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revoke Device Access'),
        content: Text(
          'Are you sure you want to revoke access for ${device.deviceName}? '
              'This will log out the device and require re-authentication.',
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
            ),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _deviceService.revokeDevice(device.id);

      // If revoking current device, sign out
      if (device.isCurrentDevice) {
        await _auth.signOut();
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
        }
        return;
      }

      await _loadDevices();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Device access revoked successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to revoke device: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _revokeAllOtherDevices() async {
    final currentDevice = _devices.firstWhere(
          (d) => d.isCurrentDevice,
      orElse: () => _devices.first,
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revoke All Other Devices'),
        content: const Text(
          'Are you sure you want to revoke access for all other devices? '
              'This will log out all devices except this one.',
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
            ),
            child: const Text('Revoke All'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _deviceService.revokeAllOtherDevices(currentDevice.id);
      await _loadDevices();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All other devices have been revoked'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to revoke devices: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connected Devices'),
        centerTitle: false,
        actions: [
          if (_devices.length > 1)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: _revokeAllOtherDevices,
              tooltip: 'Revoke all other devices',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDevices,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading connected devices...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadDevices,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_devices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.phonelink_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('No connected devices found'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadDevices,
              child: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDevices,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _devices.length,
        itemBuilder: (context, index) {
          final device = _devices[index];
          return _buildDeviceCard(device);
        },
      ),
    );
  }

  Widget _buildDeviceCard(ConnectedDevice device) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isCurrent = device.isCurrentDevice;
    final isMobile = device.deviceType.contains('Phone') || device.deviceType.contains('iOS') || device.deviceType.contains('Android');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isCurrent
            ? colorScheme.primary.withOpacity(0.05)
            : colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrent
              ? colorScheme.primary
              : colorScheme.outline.withOpacity(0.2),
          width: isCurrent ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? colorScheme.primary.withOpacity(0.1)
                        : colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isMobile ? Icons.phone_android : Icons.computer,
                    color: isCurrent ? colorScheme.primary : colorScheme.secondary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              device.deviceName,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isCurrent) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Current',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        device.deviceType,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (device.osVersion != 'Unknown')
                        Text(
                          device.osVersion,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.location_on_outlined, size: 16, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    device.location,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.public_outlined, size: 16, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    device.ipAddress,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Last active: ${DateFormat('MMM dd, yyyy - hh:mm a').format(device.lastActive)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (!isCurrent)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _revokeDevice(device),
                      icon: const Icon(Icons.block, size: 18),
                      label: const Text('Revoke Access'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                  ),
                if (!isCurrent) const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showDeviceDetails(device),
                    icon: const Icon(Icons.info_outline, size: 18),
                    label: const Text('Details'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDeviceDetails(ConnectedDevice device) {
    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.devices),
              title: const Text('Device Name'),
              subtitle: Text(device.deviceName),
            ),
            ListTile(
              leading: const Icon(Icons.computer),
              title: const Text('Device Type'),
              subtitle: Text(device.deviceType),
            ),
            if (device.manufacturer != null)
              ListTile(
                leading: const Icon(Icons.business),
                title: const Text('Manufacturer'),
                subtitle: Text(device.manufacturer!),
              ),
            if (device.deviceModel != null)
              ListTile(
                leading: const Icon(Icons.smartphone),
                title: const Text('Model'),
                subtitle: Text(device.deviceModel!),
              ),
            if (device.osVersion != 'Unknown')
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('OS Version'),
                subtitle: Text(device.osVersion),
              ),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('First Seen'),
              subtitle: Text(DateFormat('MMM dd, yyyy - hh:mm a').format(device.firstSeen)),
            ),
            ListTile(
              leading: const Icon(Icons.access_time),
              title: const Text('Last Active'),
              subtitle: Text(DateFormat('MMM dd, yyyy - hh:mm a').format(device.lastActive)),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}