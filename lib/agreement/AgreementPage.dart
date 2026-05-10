// lib/features/admin/views/company_agreement_details.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../itc_logic/idservice/globalIdService.dart';
import '../model/company.dart';

class CompanyAgreementDetails extends StatefulWidget {
  final Company company;

  const CompanyAgreementDetails({
    Key? key,
    required this.company,
  }) : super(key: key);

  @override
  State<CompanyAgreementDetails> createState() => _CompanyAgreementDetailsState();
}

class _CompanyAgreementDetailsState extends State<CompanyAgreementDetails> {
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;
  Map<String, dynamic>? _agreementData;
  Map<String, dynamic>? _bankDetails;

  // Bank details controllers
  final _accountNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _branchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAgreementData();
  }

  @override
  void dispose() {
    _accountNameController.dispose();
    _accountNumberController.dispose();
    _bankNameController.dispose();
    _branchController.dispose();
    super.dispose();
  }

  Future<void> _loadAgreementData() async {
    setState(() => _isLoading = true);

    try {
      final docId = GlobalIdService.firestoreId;
      final doc = await FirebaseFirestore.instance
          .collection('company_partnerships')
          .doc(docId)
          .get();

      if (doc.exists) {
        _agreementData = doc.data();
        _bankDetails = _agreementData?['bankDetails'] as Map<String, dynamic>?;

        // Populate controllers
        if (_bankDetails != null) {
          _accountNameController.text = _bankDetails?['accountName'] ?? '';
          _accountNumberController.text = _bankDetails?['accountNumber'] ?? '';
          _bankNameController.text = _bankDetails?['bankName'] ?? '';
          _branchController.text = _bankDetails?['branch'] ?? '';
        }
      }
    } catch (e) {
      print('Error loading agreement: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading agreement: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateBankDetails() async {
    if (_accountNameController.text.trim().isEmpty ||
        _accountNumberController.text.trim().isEmpty ||
        _bankNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_accountNumberController.text.trim().length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account number must be exactly 10 digits'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final docId = GlobalIdService.firestoreId;
      final updatedBankDetails = {
        'accountName': _accountNameController.text.trim(),
        'accountNumber': _accountNumberController.text.trim(),
        'bankName': _bankNameController.text.trim(),
        'branch': _branchController.text.trim(),
        'country': 'Nigeria',
        'currency': 'NGN',
        'updatedAt': FieldValue.serverTimestamp(),
        'status': 'pending_verification', // Re-verify after update
      };

      await FirebaseFirestore.instance
          .collection('company_partnerships')
          .doc(docId)
          .update({
        'bankDetails': updatedBankDetails,
        'bankDetailsUpdatedAt': FieldValue.serverTimestamp(),
        'bankDetailsStatus': 'pending_verification',
      });

      setState(() {
        _isEditing = false;
        _bankDetails = updatedBankDetails;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bank details updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error updating bank details: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating bank details: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          title: const Text('Partnership Agreement'),
          elevation: 0,
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.description), text: 'Agreement'),
              Tab(icon: Icon(Icons.account_balance), text: 'Bank Details'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
          children: [
            // Tab 1: Agreement View
            _buildAgreementTab(),
            // Tab 2: Bank Details
            _buildBankDetailsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildAgreementTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Banner
          _buildStatusBanner(

          ),
          const SizedBox(height: 20),

          // Terms and Conditions
          Card(
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
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner() {
    String status = _agreementData?['status'] ?? 'unknown';
    String statusText = '';
    Color statusColor;

    switch (status) {
      case 'active':
        statusText = '✓ Agreement Active';
        statusColor = Colors.green;
        break;
      case 'pending_verification':
        statusText = '⏳ Pending Bank Verification';
        statusColor = Colors.orange;
        break;
      case 'suspended':
        statusText = '⚠️ Agreement Suspended';
        statusColor = Colors.red;
        break;
      default:
        statusText = '⚠️ Agreement Status Unknown';
        statusColor = Colors.grey;
    }

    final signedAt = (_agreementData?['signedAt'] as Timestamp?)?.toDate();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: statusColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (signedAt != null)
                  Text(
                    'Signed on: ${signedAt.day}/${signedAt.month}/${signedAt.year}',
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTermSection(String title, IconData icon, Color color, String content) {
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
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
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

  Widget _buildBankDetailsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Current Bank Details Card
          Card(
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
                  Row(
                    children: [
                      Icon(
                        Icons.account_balance,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _isEditing ? 'Edit Bank Details' : 'Current Bank Details',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      if (!_isEditing)
                        IconButton(
                          onPressed: () => setState(() => _isEditing = true),
                          icon: const Icon(Icons.edit, size: 20),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  if (_isEditing)
                    _buildEditForm()
                  else
                    _buildCurrentDetails(),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Warning Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.orange.withOpacity(0.3)),
            ),
            color: Colors.orange.withOpacity(0.1),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Important Note:',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Bank details will be re-verified after update. '
                              'Payments may be delayed until verification is complete.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentDetails() {
    if (_bankDetails == null) {
      return const Center(
        child: Text('No bank details found. Please contact support.'),
      );
    }

    return Column(
      children: [
        _buildDetailRow('Account Holder Name', _bankDetails?['accountName'] ?? 'Not provided'),
        const Divider(),
        _buildDetailRow('Bank Name', _bankDetails?['bankName'] ?? 'Not provided'),
        const Divider(),
        _buildDetailRow('Account Number', _bankDetails?['accountNumber'] ?? 'Not provided'),
        const Divider(),
        _buildDetailRow('Branch', _bankDetails?['branch'] ?? 'Not provided'),
        const Divider(),
        _buildDetailRow('Country', _bankDetails?['country'] ?? 'Nigeria'),
        const Divider(),
        _buildDetailRow('Currency', _bankDetails?['currency'] ?? 'NGN'),
        const Divider(),
        _buildDetailRow(
          'Verification Status',
          _bankDetails?['status'] ?? 'pending',
          isStatus: true,
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isStatus = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: isStatus
                ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: value == 'verified'
                    ? Colors.green.withOpacity(0.1)
                    : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                value.toUpperCase(),
                style: TextStyle(
                  color: value == 'verified' ? Colors.green : Colors.orange,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            )
                : Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildEditForm() {
    return Column(
      children: [
        TextFormField(
          controller: _accountNameController,
          decoration: const InputDecoration(
            labelText: 'Account Holder Name *',
            hintText: 'Enter the name on the bank account',
            prefixIcon: Icon(Icons.person),
            border: OutlineInputBorder(),
            helperText: 'Must match company registration name',
          ),
        ),
        const SizedBox(height: 16),

        TextFormField(
          controller: _bankNameController,
          decoration: const InputDecoration(
            labelText: 'Bank Name *',
            hintText: 'e.g., GTBank, First Bank, Access Bank, UBA',
            prefixIcon: Icon(Icons.account_balance),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),

        TextFormField(
          controller: _accountNumberController,
          decoration: const InputDecoration(
            labelText: 'Account Number *',
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
        ),
        const SizedBox(height: 16),

        TextFormField(
          controller: _branchController,
          decoration: const InputDecoration(
            labelText: 'Bank Branch',
            hintText: 'e.g., Ikeja City Mall Branch',
            prefixIcon: Icon(Icons.location_city),
            border: OutlineInputBorder(),
          ),
        ),

        const SizedBox(height: 24),

        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isSaving ? null : () => setState(() => _isEditing = false),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _isSaving ? null : _updateBankDetails,
                child: _isSaving
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Text('Save Changes'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}