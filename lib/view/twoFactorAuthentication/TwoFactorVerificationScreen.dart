import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../itc_logic/service/2FactorAuthService.dart';
import '../../model/privacySettingModel.dart';

// Keep enum for backward compatibility
enum TwoFactorType { sms, password }

class TwoFactorVerificationScreen extends StatefulWidget {
  final MultiFactorResolver? resolver;
  final String email;
  final Function(UserCredential?, User?) onSuccess;
  final PrivacySettings? privacySettings;
  final TwoFactorType? forcedType;

  const TwoFactorVerificationScreen({
    Key? key,
    this.resolver,
    required this.email,
    required this.onSuccess,
    this.privacySettings,
    this.forcedType,
  }) : super(key: key);

  @override
  State<TwoFactorVerificationScreen> createState() =>
      _TwoFactorVerificationScreenState();
}

class _TwoFactorVerificationScreenState
    extends State<TwoFactorVerificationScreen> {
  final TwoFactorAuthService _twoFactorService = TwoFactorAuthService();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _backupCodeController = TextEditingController();

  bool _isLoading = false;
  bool _isDeterminingType = true;
  TwoFactorType? _determinedType;
  String? _verificationId;
  PhoneMultiFactorInfo? _selectedFactor;
  bool _isPasswordVisible = false;
  bool _useBackupCode = false;

  // Add missing getter
  bool get _isSmsTwoFactor => _determinedType == TwoFactorType.sms;

  @override
  void initState() {
    super.initState();
    _determineTwoFactorType();
  }

  Future<void> _determineTwoFactorType() async {
    // If forced type is provided, use it
    if (widget.forcedType != null) {
      setState(() {
        _determinedType = widget.forcedType;
        _isDeterminingType = false;
      });

      if (_determinedType == TwoFactorType.sms && widget.resolver != null) {
        _sendCode();
      }
      return;
    }

    // First, check if resolver exists (Firebase is forcing SMS 2FA)
    if (widget.resolver != null) {
      setState(() {
        _determinedType = TwoFactorType.sms;
        _isDeterminingType = false;
      });
      _sendCode();
      return;
    }

    // Otherwise, use privacy settings to determine the method
    if (widget.privacySettings != null &&
        widget.privacySettings!.twoFactorAuth) {
      switch (widget.privacySettings!.activeTwoFactorMethod) {
        case TwoFactorMethod.sms:
          setState(() {
            _determinedType = TwoFactorType.sms;
            _isDeterminingType = false;
          });
          _sendCode();
          break;
        case TwoFactorMethod.password:
          setState(() {
            _determinedType = TwoFactorType.password;
            _isDeterminingType = false;
          });
          break;
        case TwoFactorMethod.none:
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No 2FA method configured for this account'),
              ),
            );
            Navigator.pop(context);
          }
          break;
      }
    } else {
      // Check if user has password backup (fallback)
      try {
        final hasPasswordBackup = await _twoFactorService
            .hasTwoFactorPassword();
        if (hasPasswordBackup) {
          setState(() {
            _determinedType = TwoFactorType.password;
            _isDeterminingType = false;
          });
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No 2FA method configured for this account'),
              ),
            );
            Navigator.pop(context);
          }
        }
      } catch (e) {
        debugPrint('Error determining 2FA type: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error determining 2FA method: $e')),
          );
          Navigator.pop(context);
        }
      }
    }
  }

  Future<void> _sendCode() async {
    if (widget.resolver == null) return;

    setState(() => _isLoading = true);

    try {
      final factors = widget.resolver!.hints
          .whereType<PhoneMultiFactorInfo>()
          .toList();

      if (factors.isEmpty) {
        throw Exception('No phone factors available');
      }

      _selectedFactor = factors.first;

      await FirebaseAuth.instance.verifyPhoneNumber(
        multiFactorSession: widget.resolver!.session,
        multiFactorInfo: _selectedFactor,
        verificationCompleted: (credential) async {
          final assertion = PhoneMultiFactorGenerator.getAssertion(credential);
          final result = await widget.resolver!.resolveSignIn(assertion);
          if (mounted) {
            widget.onSuccess(result, null);
          }
        },
        verificationFailed: (error) {
          debugPrint(
            'SMS verification failed: ${error.code} - ${error.message}',
          );
          if (mounted) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Verification failed: ${error.message}')),
            );
          }
        },
        codeSent: (verificationId, forceResendingToken) {
          setState(() {
            _verificationId = verificationId;
            _isLoading = false;
          });
        },
        codeAutoRetrievalTimeout: (verificationId) {},
      );
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _verifyCode() async {
    if (_determinedType == TwoFactorType.sms) {
      if (_codeController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter the verification code')),
        );
        return;
      }

      setState(() => _isLoading = true);

      try {
        final credential = PhoneAuthProvider.credential(
          verificationId: _verificationId!,
          smsCode: _codeController.text,
        );

        final assertion = PhoneMultiFactorGenerator.getAssertion(credential);
        final result = await widget.resolver!.resolveSignIn(assertion);

        if (mounted) {
          widget.onSuccess(result, null);
        }
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Invalid code: $e')));
        }
      }
    } else {
      await _verifyPasswordFallback();
    }
  }

  Future<void> _verifyPasswordFallback() async {
    if (_passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your backup password')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final isValid = await _twoFactorService.verifyTwoFactorPassword(
        _passwordController.text,
      );

      if (isValid) {
        User? user = FirebaseAuth.instance.currentUser;
        if (mounted) {
          widget.onSuccess(null, user);
        }
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid backup password'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e, s) {
      debugPrint("Error is $e");
      debugPrintStack(stackTrace: s);
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _verifyBackupCode() async {
    if (_backupCodeController.text.isEmpty) {
      _showSnackBar('Please enter a backup code', Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final isValid = await _twoFactorService.verifyBackupCode(
        _backupCodeController.text.toUpperCase(),
      );

      if (isValid) {
        User? user = FirebaseAuth.instance.currentUser;
        if (mounted) {
          widget.onSuccess(null, user);
        }
      } else {
        setState(() => _isLoading = false);
        _showSnackBar('Invalid or already used backup code', Colors.red);
        _backupCodeController.clear();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error: $e', Colors.red);
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
  Widget build(BuildContext context) {
    if (_isDeterminingType) {
      return Scaffold(
        appBar: AppBar(title: const Text('Two-Factor Authentication')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading verification method...'),
            ],
          ),
        ),
      );
    }

    if (_determinedType == TwoFactorType.sms) {
      return _buildSmsVerificationScreen();
    } else {
      return _buildPasswordFallbackScreen();
    }
  }

  Widget _buildSmsVerificationScreen() {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Two-Factor Authentication'),
          automaticallyImplyLeading: false,
        ),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight:
                    MediaQuery.of(context).size.height -
                    180, // Subtract app bar and padding
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.security, size: 80, color: Colors.blue),
                  const SizedBox(height: 24),
                  Text(
                    'Verification Required',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _isLoading
                        ? 'Sending code...'
                        : 'We sent a verification code to ${_selectedFactor?.phoneNumber ?? 'your phone'}',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _codeController,
                    decoration: const InputDecoration(
                      labelText: 'Verification Code',
                      hintText: 'Enter 6-digit code',
                      prefixIcon: Icon(Icons.sms),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    enabled: !_isLoading,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading || _verificationId == null
                        ? null
                        : _verifyCode,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator()
                        : const Text(
                            'Verify & Login',
                            style: TextStyle(color: Colors.white),
                          ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _isLoading ? null : _sendCode,
                    child: const Text('Resend Code'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordFallbackScreen() {
    if (_useBackupCode) {
      return _buildBackupCodeScreen();
    }

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Backup Password Login'),

          automaticallyImplyLeading: false,
        ),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight:
                    MediaQuery.of(context).size.height -
                    180, // Subtract app bar and padding
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.lock, size: 80, color: Colors.green),
                  const SizedBox(height: 24),
                  Text(
                    'Backup Password Required',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Please enter your 2FA backup password to continue.',
                    style: TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _passwordController,
                    obscureText: !_isPasswordVisible,
                    decoration: InputDecoration(
                      labelText: 'Backup Password',
                      hintText: 'Enter your 2FA backup password',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                      border: const OutlineInputBorder(),
                    ),
                    enabled: !_isLoading,
                    onSubmitted: (_) => _verifyPasswordFallback(),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _useBackupCode = true;
                        _backupCodeController.clear();
                      });
                    },
                    child: const Text(
                      'Use Backup Code Instead',
                      style: TextStyle(color: Colors.blue),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _verifyPasswordFallback,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: Colors.green,
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator()
                        : const Text(
                            'Verify & Login',
                            style: TextStyle(color: Colors.white),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackupCodeScreen() {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Backup Code Login'),
          automaticallyImplyLeading: false,
        ),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight:
                    MediaQuery.of(context).size.height -
                    180, // Subtract app bar and padding
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.code, size: 80, color: Colors.purple),
                  const SizedBox(height: 24),
                  Text(
                    'Enter Backup Code',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Enter one of your saved backup codes (8 characters)',
                    style: TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _backupCodeController,
                    decoration: const InputDecoration(
                      labelText: 'Backup Code',
                      hintText: 'Enter 8-character backup code',
                      prefixIcon: Icon(Icons.code),
                      border: OutlineInputBorder(),
                      helperText: 'Example: A1B2C3D4',
                    ),
                    textCapitalization: TextCapitalization.characters,
                    enabled: !_isLoading,
                    onSubmitted: (_) => _verifyBackupCode(),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _verifyBackupCode,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: Colors.purple,
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator()
                        : const Text(
                            'Verify & Login',
                            style: TextStyle(color: Colors.white),
                          ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _useBackupCode = false;
                        _backupCodeController.clear();
                      });
                    },
                    child: const Text('Back to Password'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    _passwordController.dispose();
    _backupCodeController.dispose();
    super.dispose();
  }
}
