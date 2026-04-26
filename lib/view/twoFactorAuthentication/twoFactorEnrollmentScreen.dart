import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

import '../../itc_logic/idservice/globalIdService.dart';
import '../../itc_logic/service/2FactorAuthService.dart';
import '../../model/privacySettingModel.dart';

class TwoFactorEnrollmentScreen extends StatefulWidget {
  const TwoFactorEnrollmentScreen({Key? key}) : super(key: key);

  @override
  State<TwoFactorEnrollmentScreen> createState() => _TwoFactorEnrollmentScreenState();
}

class _TwoFactorEnrollmentScreenState extends State<TwoFactorEnrollmentScreen> {
  final TwoFactorAuthService _twoFactorService = TwoFactorAuthService();

  // SMS 2FA Controllers
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _displayNameController = TextEditingController();

  // Password 2FA Controllers
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _existingPasswordController = TextEditingController(); // For confirmation

  String? _verificationId;
  bool _isLoading = false;
  bool _codeSent = false;
  bool _hasExistingPassword = false;
  bool _isVerifyingExistingPassword = false; // Track verification state
  TwoFactorMethod _selectedMethod = TwoFactorMethod.sms;

  @override
  void initState() {
    super.initState();
    _checkExistingPassword();
  }

  Future<void> _checkExistingPassword() async {
    final hasPassword = await _twoFactorService.hasTwoFactorPassword();
    debugPrint("has password $hasPassword}");
    setState(() {
      _hasExistingPassword = hasPassword;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enable Two-Factor Authentication')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose a verification method to secure your account',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),

            // Method selection
            _buildMethodSelection(),

            const SizedBox(height: 24),

            // Method-specific UI
            if (_selectedMethod == TwoFactorMethod.sms)
              _buildSmsMethod(),
            if (_selectedMethod == TwoFactorMethod.password)
              _buildPasswordMethod(),
          ],
        ),
      ),
    );
  }

  Widget _buildMethodSelection() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          RadioListTile<TwoFactorMethod>(
            title: const Text('SMS Verification'),
            subtitle: const Text('Receive codes via text message'),
            value: TwoFactorMethod.sms,
            groupValue: _selectedMethod,
            onChanged: (value) {
              setState(() {
                _selectedMethod = value!;
                _codeSent = false;
                _isVerifyingExistingPassword = false;
              });
            },
            secondary: const Icon(Icons.sms, color: Colors.blue),
          ),
          const Divider(height: 1),
          RadioListTile<TwoFactorMethod>(
            title: const Text('Password Backup'),
            subtitle: const Text('Use a secure password as backup (encrypted)'),
            value: TwoFactorMethod.password,
            groupValue: _selectedMethod,
            onChanged: (value) {
              setState(() {
                _selectedMethod = value!;
                _codeSent = false;
                _isVerifyingExistingPassword = false;
              });
            },
            secondary: const Icon(Icons.lock, color: Colors.green),
          ),
        ],
      ),
    );
  }

  Widget _buildSmsMethod() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!_codeSent) ...[
          TextField(
            controller: _phoneController,
            decoration: const InputDecoration(
              labelText: 'Phone Number',
              hintText: '+1234567890',
              prefixIcon: Icon(Icons.phone),
              helperText: 'Enter phone number with country code',
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _displayNameController,
            decoration: const InputDecoration(
              labelText: 'Device Name (Optional)',
              hintText: 'My Personal Phone',
              prefixIcon: Icon(Icons.devices),
            ),
          ),
          const SizedBox(height: 24),

          ElevatedButton(
            onPressed: _isLoading ? null : _sendVerificationCode,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
            child: _isLoading
                ? const CircularProgressIndicator()
                : const Text('Send Verification Code'),
          ),
        ],

        if (_codeSent) ...[
          TextField(
            controller: _codeController,
            decoration: const InputDecoration(
              labelText: 'Verification Code',
              hintText: 'Enter 6-digit code from SMS',
              prefixIcon: Icon(Icons.sms),
            ),
            keyboardType: TextInputType.number,
            maxLength: 6,
          ),
          const SizedBox(height: 16),

          ElevatedButton(
            onPressed: _isLoading ? null : _verifyAndEnrollSms,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
            child: _isLoading
                ? const CircularProgressIndicator()
                : const Text('Verify & Enable SMS 2FA'),
          ),

          TextButton(
            onPressed: _isLoading ? null : _sendVerificationCode,
            child: const Text('Resend Code'),
          ),
        ],
      ],
    );
  }

  Widget _buildPasswordMethod() {
    // Show password verification screen if verifying existing password
    if (_isVerifyingExistingPassword) {
      return _buildVerifyExistingPasswordScreen();
    }
debugPrint("existing password ${_hasExistingPassword}");
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              Icon(Icons.info, color: Colors.blue),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Your password will be encrypted and stored securely. Use this as a backup if SMS verification fails.',
                  style: TextStyle(fontSize: 12,color: Colors.black),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // If user already has a password, show option to use it
        if (_hasExistingPassword) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Column(
              children: [
                const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'You already have a backup password set!',
                        style: TextStyle(fontWeight: FontWeight.bold,
                        color:Colors.black),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : () {
                      setState(() {
                        _isVerifyingExistingPassword = true;
                        _existingPasswordController.clear();
                      });
                    },
                    icon: const Icon(Icons.verified),
                    label: const Text('Use Existing Backup Password'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'OR set a new password',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // New password setup
        TextField(
          controller: _passwordController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: '2FA Backup Password',
            hintText: 'Enter a strong password',
            prefixIcon: Icon(Icons.lock),
            helperText: 'Minimum 6 characters',
          ),
        ),
        const SizedBox(height: 16),

        TextField(
          controller: _confirmPasswordController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Confirm Password',
            hintText: 'Re-enter your password',
            prefixIcon: Icon(Icons.lock_outline),
          ),
        ),
        const SizedBox(height: 24),

        if (_hasExistingPassword)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning, color: Colors.orange),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Setting a new password will replace your existing backup password.',
                    style: TextStyle(fontSize: 12,
                    color: Colors.black),
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 16),

        ElevatedButton(
          onPressed: _isLoading ? null : _setPasswordAndEnroll,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
          ),
          child: _isLoading
              ? const CircularProgressIndicator()
              : Text(_hasExistingPassword ? 'Replace with New Password' : 'Enable Password 2FA'),
        ),
      ],
    );
  }

  // New screen for verifying existing password
  Widget _buildVerifyExistingPasswordScreen() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.shade200),
          ),
          child: const Row(
            children: [
              Icon(Icons.security, color: Colors.amber),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Please enter your existing backup password to confirm you still remember it.',
                  style: TextStyle(fontSize: 14,
                  color: Colors.black),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        TextField(
          controller: _existingPasswordController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Existing Backup Password',
            hintText: 'Enter your current backup password',
            prefixIcon: Icon(Icons.lock),
            helperText: 'Enter the password you previously set for 2FA',
          ),
        ),
        const SizedBox(height: 24),

        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isLoading ? null : () {
                  setState(() {
                    _isVerifyingExistingPassword = false;
                    _existingPasswordController.clear();
                  });
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Back'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: _isLoading ? null : _verifyAndEnableExistingPassword,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.green,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Verify & Enable',style: TextStyle(color: Colors.black),),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _verifyAndEnableExistingPassword() async {
    final existingPassword = _existingPasswordController.text;

    if (existingPassword.isEmpty) {
      _showSnackBar('Please enter your existing backup password', Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Verify the existing password
      final isValid = await _twoFactorService.verifyTwoFactorPassword(existingPassword);

      if (isValid) {
        // Password is correct - enable 2FA
        await _updatePrivacySettings(TwoFactorMethod.password);

        if (mounted) {
          _showSnackBar('2FA Backup Password enabled successfully!', Colors.green);
          Navigator.pop(context, true);
        }
      } else {
        setState(() => _isLoading = false);
        _showSnackBar('Invalid password. Please try again.', Colors.red);
        _existingPasswordController.clear();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error: $e', Colors.red);
    }
  }

  Future<void> _enableExistingPassword() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Use Existing Backup Password'),
        content: const Text(
          'Your existing backup password will be used for 2FA. '
              'You will need to enter it during login when 2FA is required.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => {
        _isVerifyingExistingPassword = true,
        _existingPasswordController.clear(),
      });
    }
  }

  Future<void> _sendVerificationCode() async {
    if (_phoneController.text.isEmpty) {
      _showSnackBar('Please enter a phone number', Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final session = await _twoFactorService.getMultiFactorSession();

      final verificationId = await _twoFactorService.sendEnrollmentCode(
        phoneNumber: _phoneController.text,
        session: session,
      );

      setState(() {
        _verificationId = verificationId;
        _codeSent = true;
        _isLoading = false;
      });

      _showSnackBar('Verification code sent!', Colors.green);
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error: $e', Colors.red);
    }
  }

  Future<void> _verifyAndEnrollSms() async {
    if (_codeController.text.isEmpty) {
      _showSnackBar('Please enter the verification code', Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _twoFactorService.completeEnrollment(
        verificationId: _verificationId!,
        smsCode: _codeController.text,
        displayName: _displayNameController.text.isNotEmpty
            ? _displayNameController.text
            : _phoneController.text,
      );

      await _updatePrivacySettings(TwoFactorMethod.sms);

      if (mounted) {
        _showSnackBar('SMS 2FA successfully enabled!', Colors.green);
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Enrollment failed: $e', Colors.red);
    }
  }

  Future<void> _setPasswordAndEnroll() async {
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (password.isEmpty) {
      _showSnackBar('Please enter a password', Colors.red);
      return;
    }

    if (password.length < 6) {
      _showSnackBar('Password must be at least 6 characters', Colors.red);
      return;
    }

    if (password != confirmPassword) {
      _showSnackBar('Passwords do not match', Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Set password - this already generates backup codes internally
      final backupCodes = await _twoFactorService.setTwoFactorPassword(password);

      // Update privacy settings
      await _updatePrivacySettings(TwoFactorMethod.password);

      if (mounted) {
        // Show backup codes if any were generated
        if (backupCodes.isNotEmpty) {
          await _showBackupCodesDialog(backupCodes);
        }

        _showSnackBar('2FA Backup Password enabled successfully!', Colors.green);
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error: $e', Colors.red);
    }
  }

  Future<void> _showBackupCodesDialog(List<String> codes) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        title: Text(
          'Save Your Backup Codes',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'These backup codes can be used to access your account if you forget your 2FA password. '
                    'Each code can only be used once.',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey[300] : Colors.black87,
                ),
              ),
              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                  ),
                ),
                child: Column(
                  children: codes.asMap().entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 30,
                            child: Text(
                              '${entry.key + 1}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              entry.value,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.greenAccent : Colors.black,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.copy,
                              size: 18,
                              color: isDark ? Colors.grey[300] : Colors.black,
                            ),
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(text: entry.value),
                              );
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

              Text(
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
            child: Text(
              'I Have Saved Them',
              style: TextStyle(
                color: isDark ? Colors.blue[300] : Colors.blue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updatePrivacySettings(TwoFactorMethod method) async {
    final userId = GlobalIdService.firestoreId;
    if (userId != null) {
      await FirebaseFirestore.instance
          .collection('privacy_settings')
          .doc(userId)
          .update({
        'twoFactorAuth': true,
        'twoFactorMethod': method.name,
        'twoFactorEnabledAt': FieldValue.serverTimestamp(),
      });
    }
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

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _displayNameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _existingPasswordController.dispose();
    super.dispose();
  }
}