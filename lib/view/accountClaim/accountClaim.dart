import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:itc_institute_admin/generalmethods/GeneralMethods.dart';
import 'package:itc_institute_admin/itc_logic/idservice/globalIdService.dart';
import 'package:itc_institute_admin/model/authority.dart';
import 'package:itc_institute_admin/model/company.dart';
import 'package:itc_institute_admin/view/home/companyDashBoard.dart';

class AccountClaimPage extends StatefulWidget {
  const AccountClaimPage({super.key});

  @override
  State<AccountClaimPage> createState() => _AccountClaimPageState();
}

class _AccountClaimPageState extends State<AccountClaimPage> {
  final TextEditingController _registrationNumberController = TextEditingController();

  String _selectedAccountType = 'company'; // 'company' or 'authority'
  bool _isLoading = false;
  bool _isChecking = false;
  String? _error;
  bool _isSuccess = false;

  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _checkIfAlreadyClaimed();
  }

  @override
  void dispose() {
    _registrationNumberController.dispose();
    super.dispose();
  }

  Future<void> _checkIfAlreadyClaimed() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    setState(() => _isLoading = true);

    try {
      // Check if user already has a claimed account
      final mappingDoc = await _firestore
          .collection('auth_mappings')
          .doc(currentUser.uid)
          .get();

      if (mappingDoc.exists) {
        final firestoreId = mappingDoc['firestoreId'] as String?;
        final userType = mappingDoc['userType'] as String?;

        if (firestoreId != null && userType != null) {
          setState(() {
            _isSuccess = true;
            _isLoading = false;
            _error = 'You have already claimed an account.';
          });
        }
      }
    } catch (e) {
      debugPrint('Error checking claim status: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _claimAccount() async {
    // Validate inputs
    if (_registrationNumberController.text.trim().isEmpty) {
      setState(() => _error = 'Please enter your registration number');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        setState(() {
          _error = 'You must be logged in to claim an account.';
          _isLoading = false;
        });
        return;
      }

      final authUid = currentUser.uid;

      // Step 1: Verify the registration number exists
      dynamic accountData;
      String accountId;
      String accountType = _selectedAccountType;

      if (_selectedAccountType == 'company') {
        // Search for company with matching registration number
        final companyQuery = await _firestore
            .collection('users')
            .doc('companies')
            .collection('companies')
            .where('registrationNumber', isEqualTo: _registrationNumberController.text.trim())
            .limit(1)
            .get();

        if (companyQuery.docs.isEmpty) {
          setState(() {
            _error = 'No company account found with this registration number.';
            _isLoading = false;
          });
          return;
        }

        final doc = companyQuery.docs.first;
        accountId = doc.id;
        accountData = Company.fromMap(doc.data() as Map<String, dynamic>);

      } else {
        // Search for authority with matching registration number
        final authorityQuery = await _firestore
            .collection('users')
            .doc('authorities')
            .collection('authorities')
            .where('registrationNumber', isEqualTo: _registrationNumberController.text.trim())
            .limit(1)
            .get();

        if (authorityQuery.docs.isEmpty) {
          setState(() {
            _error = 'No authority account found with this registration number.';
            _isLoading = false;
          });
          return;
        }

        final doc = authorityQuery.docs.first;
        accountId = doc.id;
        accountData = Authority.fromMap(doc.data() as Map<String, dynamic>);
      }

      // Step 2: Check if account is already claimed
      final isClaimed = await _checkIfAccountClaimed(accountId, accountType);
      if (isClaimed) {
        setState(() {
          _error = 'This account has already been claimed by another user.';
          _isLoading = false;
        });
        return;
      }

      // Step 3: Link Auth ID to Firestore ID using GlobalIdService
      await GlobalIdService.linkToFirestoreId(
        firestoreId: accountId,
        userType: accountType,
      );

      // Step 4: Update the original document with authUid and claim info
      final updateData = {
        'authUid': authUid,
        'claimedAt': FieldValue.serverTimestamp(),
        'claimed': true,
        'claimedBy': authUid,
        'claimStatus': 'completed',
        'email': currentUser.email, // Update email to match auth
      };

      if (accountType == 'company') {
        await _firestore
            .collection('users')
            .doc('companies')
            .collection('companies')
            .doc(accountId)
            .update(updateData);

        // Also update the company object's authUid field if exists
        if (accountData is Company) {
          // You may want to update any other fields
        }
      } else {
        await _firestore
            .collection('users')
            .doc('authorities')
            .collection('authorities')
            .doc(accountId)
            .update(updateData);
      }

      // Step 5: Refresh GlobalIdService
      await GlobalIdService.refresh();

      setState(() {
        _isSuccess = true;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account claimed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = _getAuthErrorMessage(e.code);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'An error occurred: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<bool> _checkIfAccountClaimed(String accountId, String accountType) async {
    try {
      if (accountType == 'company') {
        final doc = await _firestore
            .collection('users')
            .doc('companies')
            .collection('companies')
            .doc(accountId)
            .get();

        if (doc.exists) {
          final data = doc.data();
          return data?['claimed'] == true || data?['authUid'] != null;
        }
      } else {
        final doc = await _firestore
            .collection('users')
            .doc('authorities')
            .collection('authorities')
            .doc(accountId)
            .get();

        if (doc.exists) {
          final data = doc.data();
          return data?['claimed'] == true || data?['authUid'] != null;
        }
      }
      return false;
    } catch (e) {
      debugPrint('Error checking if account claimed: $e');
      return false;
    }
  }

  void _checkRegistrationNumber() async {
    final regNumber = _registrationNumberController.text.trim();
    if (regNumber.isEmpty) return;

    setState(() {
      _isChecking = true;
      _error = null;
    });

    try {
      bool exists = false;

      if (_selectedAccountType == 'company') {
        final query = await _firestore
            .collection('users')
            .doc('companies')
            .collection('companies')
            .where('registrationNumber', isEqualTo: regNumber)
            .limit(1)
            .get();
        exists = query.docs.isNotEmpty;
      } else {
        final query = await _firestore
            .collection('users')
            .doc('authorities')
            .collection('authorities')
            .where('registrationNumber', isEqualTo: regNumber)
            .limit(1)
            .get();
        exists = query.docs.isNotEmpty;
      }

      if (mounted) {
        setState(() {
          if (!exists) {
            _error = 'No account found with this registration number';
          }
          _isChecking = false;
        });
      }
    } catch (e) {
      setState(() {
        _isChecking = false;
      });
    }
  }

  String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password should be at least 6 characters.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUser = _auth.currentUser;

    // Show loading while checking claim status
    if (_isLoading && !_isSuccess) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Claim Your Account'),
          centerTitle: true,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Show success/error message if already claimed
    if (_isSuccess) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Claim Your Account'),
          centerTitle: true,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 80,
                  color: Colors.green,
                ),
                const SizedBox(height: 16),
                Text(
                  'Account Already Claimed',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You have already claimed your account.\nYou will be redirected to your dashboard.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                      Navigator.pop(context);
                  },
                  child: const Text('Go to Dashboard'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Claim Your Account'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // User Info Card
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            child: Text(
                              currentUser?.email?.substring(0, 1).toUpperCase() ?? 'U',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Logged in as',
                                  style: theme.textTheme.labelSmall,
                                ),
                                Text(
                                  currentUser?.email ?? 'Unknown',
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Header
              Icon(
                Icons.verified_user_outlined,
                size: 80,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Claim Your Account',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Enter your registration number to link this account to your organization',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Account Type Selection
              Text(
                'Account Type',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'company', label: Text('Company')),
                  ButtonSegment(value: 'authority', label: Text('Authority')),
                ],
                selected: {_selectedAccountType},
                onSelectionChanged: (Set<String> selection) {
                  setState(() {
                    _selectedAccountType = selection.first;
                    _registrationNumberController.clear();
                    _error = null;
                  });
                },
              ),
              const SizedBox(height: 24),

              // Registration Number Field
              TextField(
                controller: _registrationNumberController,
                decoration: InputDecoration(
                  labelText: 'Registration Number',
                  hintText: 'Enter your registration number',
                  prefixIcon: const Icon(Icons.numbers),
                  suffixIcon: _isChecking
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : null,
                  errorText: _error != null && _error!.contains('registration number') ? _error : null,
                  helperText: 'The registration number provided by ITC',
                ),
                onChanged: (_) => _checkRegistrationNumber(),
              ),

              if (_error != null && !_error!.contains('registration number'))
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),

              const SizedBox(height: 32),

              // Info Box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Once claimed, this account will be permanently linked to your email. You cannot unclaim it.',
                        style: TextStyle(color: Colors.blue[700], fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Claim Button
              ElevatedButton(
                onPressed: _isLoading || _isChecking ? null : _claimAccount,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Text('Claim Account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

