// lib/features/admin/views/company_onboarding_agreement.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../itc_logic/idservice/globalIdService.dart';
import '../model/company.dart';

class CompanyOnboardingAgreement extends StatefulWidget {
  final String companyId;
  final String companyName;
  final String companyEmail;
  final Company company;
  final bool notFromLogin;

  const CompanyOnboardingAgreement({
    Key? key,
    required this.companyId,
    required this.companyName,
    required this.companyEmail,
    required this.company,
    this.notFromLogin = false
  }) : super(key: key);

  @override
  State<CompanyOnboardingAgreement> createState() =>
      _CompanyOnboardingAgreementState();
}

class _CompanyOnboardingAgreementState
    extends State<CompanyOnboardingAgreement> {
  bool _isAgreed = false;
  bool _isSubmitting = false;
  final _formKey = GlobalKey<FormState>();

  // Bank details controllers
  final _accountNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _branchController = TextEditingController();
  final _swiftCodeController = TextEditingController();

  @override
  void dispose() {
    _accountNameController.dispose();
    _accountNumberController.dispose();
    _bankNameController.dispose();
    _branchController.dispose();
    _swiftCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: widget.notFromLogin,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          title: const Text('Partnership Agreement'),
          elevation: 0,
          actions: [
            if (_isAgreed)
              TextButton.icon(
                onPressed: _isSubmitting ? null : _submitAgreement,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle),
                label: const Text('Accept & Continue'),
              ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(),
              const SizedBox(height: 24),

              // Terms and Conditions
              _buildTermsAndConditions(),
              const SizedBox(height: 24),

              // Agreement Checkbox
              _buildAgreementCheckbox(),

              // Bank Details Form (only visible when agreed)
              if (_isAgreed) ...[
                const SizedBox(height: 32),
                _buildBankDetailsForm(),
              ],

              const SizedBox(height: 80), // Space for bottom button
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primaryContainer,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.business_center,
                size: 40,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'IT Connect Partnership Agreement',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Welcome ${widget.companyName}!',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please review the partnership terms carefully before proceeding.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTermsAndConditions() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📋 Partnership Terms & Conditions',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            _buildTermSection(
              '1. Revenue Share Agreement',
              Icons.percent,
              Colors.green,
              '''
• Your company is eligible to receive 40% of all application fees paid by students
• This applies to applications submitted to IT Opportunity under YOUR company
• You earn the 40% ONLY when you take action (ACCEPT or REJECT) on an application
• No action = No payment for that application
            ''',
            ),

            const SizedBox(height: 20),

            _buildTermSection(
              '2. Application Response Requirement',
              Icons.timer,
              Colors.orange,
              '''
• You have 7 calendar days to respond to each student application
• After 7 days with NO RESPONSE, the student may request a FULL REFUND
• When refund is requested, the application is CANCELLED automatically
• The student's application slot is returned to them
• You will NOT receive the 40% share for cancelled applications
            ''',
            ),

            const SizedBox(height: 20),

            _buildTermSection(
              '3. Payment Disbursement Schedule',
              Icons.payment,
              Colors.blue,
              '''
• All earnings are calculated at the END OF EACH MONTH
• Payments are disbursed ONCE per month (between 25th - 30th)
• You will receive your 40% share of ALL processed applications for that month
• Payments are sent directly to your registered Nigerian bank account
• Payment confirmation will be sent to your registered email
            ''',
            ),

            const SizedBox(height: 20),

            _buildTermSection(
              '4. Bank Account Requirements (Nigeria Only)',
              Icons.account_balance,
              Colors.purple,
              '''
• All payments are made in NAIRA (₦) to Nigerian bank accounts only
• You must provide the following valid bank details:
   ✓ Account Holder Name (must match company registration)
   ✓ Bank Name (e.g., GTBank, First Bank, Access, UBA, etc.)
   ✓ Account Number (10 digits NUBAN)
• Bank verification will be completed within 24-48 hours
• Incorrect bank details may delay or cancel payments
            ''',
            ),

            const SizedBox(height: 20),

            _buildTermSection(
              '5. Company Responsibilities',
              Icons.assignment,
              Colors.red,
              '''
• Post genuine internship/job opportunities only
• Review and respond to all applications within 7 days
• Maintain professional communication with students
• Keep company profile information up to date
• Provide accurate bank account information
• Report any platform issues promptly
            ''',
            ),

            const SizedBox(height: 20),

            _buildTermSection(
              '6. Student Refund Policy',
              Icons.refresh,
              Colors.teal,
              '''
• Students pay an application fee to submit to your company
• If you don't respond within 7 days, students can request a refund
• Approved refunds are processed within 5-7 business days
• Your company is NOT charged for refunded applications
• No earnings are generated from cancelled applications
            ''',
            ),

            const SizedBox(height: 20),

            _buildTermSection(
              '7. Termination of Agreement',
              Icons.cancel,
              Colors.grey,
              '''
• Either party may terminate with 14 days written notice
• Outstanding payments will be settled within 30 days of termination
• Violation of terms may result in immediate termination
• Upon termination, all pending applications will be automatically cancelled
• Student application fees will be refunded for cancelled applications
            ''',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTermSection(
    String title,
    IconData icon,
    Color color,
    String content,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(content, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    );
  }

  Widget _buildAgreementCheckbox() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _isAgreed
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outlineVariant,
          width: _isAgreed ? 2 : 1,
        ),
      ),
      child: CheckboxListTile(
        value: _isAgreed,
        onChanged: (value) {
          setState(() {
            _isAgreed = value ?? false;
          });
        },
        title: const Text(
          'I have read and agree to the Terms & Conditions',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'By checking this box, you agree to all the terms outlined above and authorize IT Connect to process payments to your provided bank account.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
        controlAffinity: ListTileControlAffinity.leading,
        activeColor: Theme.of(context).colorScheme.primary,
        contentPadding: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildBankDetailsForm() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).colorScheme.primary,
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.account_balance,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Bank Account Information',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'All payments are made in Naira (₦) to Nigerian bank accounts only',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),

            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _accountNameController,
                    decoration: const InputDecoration(
                      labelText: 'Account Holder Name',
                      hintText: 'Enter the name on the bank account',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                      helperText: 'Must match company registration name',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter account holder name';
                      }
                      if (value.length < 3) {
                        return 'Name must be at least 3 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _bankNameController,
                    decoration: const InputDecoration(
                      labelText: 'Bank Name',
                      hintText: 'e.g., GTBank, First Bank, Access Bank, UBA',
                      prefixIcon: Icon(Icons.account_balance),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter bank name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _accountNumberController,
                    decoration: const InputDecoration(
                      labelText: 'Account Number',
                      hintText: '10-digit NUBAN account number',
                      prefixIcon: Icon(Icons.numbers),
                      border: OutlineInputBorder(),
                      helperText: 'Enter your 10-digit NUBAN account number',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter account number';
                      }
                      if (value.length != 10) {
                        return 'Account number must be exactly 10 digits';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _branchController,
                    decoration: const InputDecoration(
                      labelText: 'Bank Branch (Optional)',
                      hintText: 'e.g., Ikeja City Mall Branch',
                      prefixIcon: Icon(Icons.location_city),
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _submitAgreement,
                      icon: _isSubmitting
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : const Icon(Icons.check_circle),
                      label: Text(
                        _isSubmitting ? 'Submitting...' : 'Complete Onboarding',
                        style: const TextStyle(fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitAgreement() async {
    // Validate form
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Prepare bank details data
      final bankDetails = {
        'accountName': _accountNameController.text.trim(),
        'accountNumber': _accountNumberController.text.trim(),
        'bankName': _bankNameController.text.trim(),
        'branch': _branchController.text.trim(),
        'country': 'Nigeria',
        'currency': 'NGN',
        'submittedAt': FieldValue.serverTimestamp(),
        'status': 'pending_verification',
        'revenueShare': 40, // 40%
        'payoutSchedule': 'monthly',
        'payoutDay': '25th-30th of each month',
      };

    // Store in Firestore with collection ID = user ID
      final docId = GlobalIdService.firestoreId;
      await FirebaseFirestore.instance
          .collection('company_partnerships')
          .doc(docId)
          .set({
            'companyId': widget.companyId,
            'companyName': widget.companyName,
            'companyEmail': widget.companyEmail,
            'bankDetails': bankDetails,
            'agreementSigned': true,
            'agreementVersion': '1.0',
            'signedAt': FieldValue.serverTimestamp(),
            'status': 'active',
            'metadata': {
              'platform': 'mobile',
              'ip': 'collected_by_firebase', // Firebase will capture this
            },
          });

      // Also update company document with partnership status
      await FirebaseFirestore.instance
          .collection('users')
          .doc("companies")
          .collection("companies")
          .doc(widget.companyId)
          .update({
            'partnershipStatus': 'active',
            'partnershipSignedAt': FieldValue.serverTimestamp(),
            'revenueShare': 40,
            'bankDetailsSubmitted': true,
          });

      // Show success message
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => PopScope(
            canPop: false,
            child: AlertDialog(
              title: const Wrap(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 12),
                  Text('Onboarding Complete!'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your partnership agreement has been submitted successfully.',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Next Steps:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text('• Wait for bank verification (24-48 hours)'),
                        const Text('• You will receive a confirmation email'),
                        const Text(
                          '• Start posting opportunities and reviewing applications',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context,
                    {
                      'agreementSigned':true,
                      'company':widget.company
                    }); // Go back to previous screen

                  },
                  child: const Text('Go to Dashboard'),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      print('Error submitting agreement: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}
