import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:itc_institute_admin/itc_logic/firebase/authority_cloud.dart';
import 'package:itc_institute_admin/itc_logic/firebase/general_cloud.dart';
import 'package:itc_institute_admin/model/authority.dart';
import 'package:itc_institute_admin/model/company.dart';

import '../../itc_logic/idservice/globalIdService.dart';

class CompanyAuthoritySpecificationPage extends StatefulWidget {
  final Company company;
  final ITCFirebaseLogic firebaseLogic;
  final VoidCallback? onSpecificationComplete;
  final bool allowEditing;

  const CompanyAuthoritySpecificationPage({
    Key? key,
    required this.company,
    required this.firebaseLogic,
    this.onSpecificationComplete,
    this.allowEditing = true,
  }) : super(key: key);

  @override
  State<CompanyAuthoritySpecificationPage> createState() => _CompanyAuthoritySpecificationPageState();
}

class _CompanyAuthoritySpecificationPageState extends State<CompanyAuthoritySpecificationPage> {
  final AuthorityService _authorityService = AuthorityService(GlobalIdService.firestoreId);

  String _selectedOption = 'not_selected'; // 'standalone', 'under_authority', 'not_selected'
  String? _selectedAuthorityId;
  String? _selectedAuthorityName;
  List<Authority> _availableAuthorities = [];
  bool _isLoading = false;

  bool _isLoadingAuthorities = true;
  TextEditingController _searchController = TextEditingController();
  List<Authority> _filteredAuthorities = [];

  @override
  void initState() {
    super.initState();
    _checkCurrentStatus();
    _loadAuthorities();
    _searchController.addListener(_filterAuthorities);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _checkCurrentStatus() {
    // Check if company already has authority specification
    if (widget.company.isUnderAuthority) {
      _selectedOption = 'under_authority';
      _selectedAuthorityId = widget.company.authorityId;
      _selectedAuthorityName = widget.company.authorityName;
    } else if (widget.company.authorityLinkStatus != "NONE") {
      // Company has some authority status but not set as under authority
      _selectedOption = 'under_authority';
    }
  }

  Future<void> _loadAuthorities() async {
    try {
      setState(() {
        _isLoadingAuthorities = true;
      });

      // Get all available authorities
      final authorities = await widget.firebaseLogic.getAllAuthorities();

      // Filter out the company itself if it's an authority
      _availableAuthorities = authorities.where((auth) => auth.id != widget.company.id).toList();
      _filteredAuthorities = List.from(_availableAuthorities);

      setState(() {
        _isLoadingAuthorities = false;
      });
    } catch (e) {
      print('Error loading authorities: $e');
      setState(() {
        _isLoadingAuthorities = false;
      });
    }
  }

  void _filterAuthorities() {
    final query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) {
      setState(() {
        _filteredAuthorities = List.from(_availableAuthorities);
      });
    } else {
      setState(() {
        _filteredAuthorities = _availableAuthorities
            .where((authority) =>
        authority.name.toLowerCase().contains(query) ||
            (authority.state?.toLowerCase().contains(query) ?? false) ||
            (authority.localGovernment?.toLowerCase().contains(query) ?? false))
            .toList();
      });
    }
  }

  Future<void> _saveSpecification() async {
    if (_selectedOption == 'not_selected') {
      Fluttertoast.showToast(msg: "Please select an option");
      return;
    }

    if (_selectedOption == 'under_authority' && _selectedAuthorityId == null) {
      Fluttertoast.showToast(msg: "Please select an authority");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      bool success = false;
      String message = '';

      if (_selectedOption == 'standalone') {
        // Update company to standalone
        success = await _updateToStandalone();
        message = success ? 'Company set as standalone' : 'Failed to update company';
      } else if (_selectedOption == 'under_authority') {
        // Request link to authority
        success = await _requestAuthorityLink();
        message = success ? 'Link request sent to authority' : 'Failed to send link request';
      }

      if (success) {
        // Call callback and navigate back
        if (widget.onSpecificationComplete != null) {
          widget.onSpecificationComplete!();
        }

        Fluttertoast.showToast(
          msg: message,
          toastLength: Toast.LENGTH_LONG,
        );

        Navigator.of(context).pop(true);
      } else {
        Fluttertoast.showToast(msg: message);
      }
    } catch (e) {
      print('Error saving specification: $e');
      Fluttertoast.showToast(msg: 'Error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<bool> _updateToStandalone() async {
    try {
      final companyRef = FirebaseFirestore.instance.collection('companies').doc(widget.company.id);

      await companyRef.update({
        'isUnderAuthority': false,
        'authorityId': null,
        'authorityName': null,
        'authorityLinkStatus': 'NONE',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error updating to standalone: $e');
      return false;
    }
  }

  Future<bool> _requestAuthorityLink() async {
    try {
      // Get the selected authority
      final selectedAuthority = _availableAuthorities.firstWhere(
            (auth) => auth.id == _selectedAuthorityId,
      );

      // Add company to authority's pending applications
      final result = await widget.firebaseLogic.addCompanyToAuthorityPendingApplications(
        authorityId: _selectedAuthorityId!,
        companyId: widget.company.id,
        companyName: widget.company.name,
        selectedAuthorityName: selectedAuthority.name,
      );

      if (result) {
        // Also update company's status
        final companyRef = FirebaseFirestore.instance.collection('users').doc("companies").collection("companies").doc(widget.company.id);

        await companyRef.update({
          'isUnderAuthority': true,
          'authorityId': _selectedAuthorityId,
          'authorityName': _selectedAuthorityName,
          'authorityLinkStatus': 'PENDING',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      return result;
    } catch (e,s) {
      debugPrintStack(stackTrace: s);
      print('Error requesting authority link: $e');
      return false;
    }
  }

  bool _shouldShowPage() {
    if (widget.allowEditing) {
      // Always show page if editing is allowed
      return true;
    }

    return !widget.company.isUnderAuthority &&
        (widget.company.authorityLinkStatus == "NONE" ||
            widget.company.authorityId == null);
  }

  @override
  Widget build(BuildContext context) {
    if (!_shouldShowPage() && !widget.allowEditing) {
      return const Scaffold(
        body: Center(
          child: Text('No authority specification needed'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Company Authority Setup'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Header Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,
                  child: Icon(
                    Icons.business,
                    size: 30,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.company.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Specify your company\'s authority relationship',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Introduction
                  _buildIntroduction(),
                  const SizedBox(height: 24),

                  // Options Selection
                  _buildOptionsSelection(),
                  const SizedBox(height: 24),

                  // Authority Selection (only shown if under_authority is selected)
                  if (_selectedOption == 'under_authority')
                    _buildAuthoritySelection(),

                  const SizedBox(height: 40),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _saveSpecification,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                              : const Text('Save & Continue'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntroduction() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome, ${widget.company.name}!',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'To complete your company setup, please specify your authority relationship. '
              'This helps us provide you with the right features and connections.',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade100),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade600),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'This information can be changed later in your company settings.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.blue.shade800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOptionsSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Your Company Type',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Choose the option that best describes your company:',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 20),

        // Standalone Option
        _buildOptionCard(
          title: 'Standalone Company',
          description: 'Independent organization not linked to any government authority',
          icon: Icons.business_outlined,
          iconColor: Colors.blue,
          value: 'standalone',
          isSelected: _selectedOption == 'standalone',
        ),
        const SizedBox(height: 12),

        // Under Authority Option
        _buildOptionCard(
          title: 'Government Facility / Under Authority',
          description: 'Company operating under a government authority or ministry',
          icon: Icons.account_balance,
          iconColor: Colors.green,
          value: 'under_authority',
          isSelected: _selectedOption == 'under_authority',
        ),
      ],
    );
  }

  Widget _buildOptionCard({
    required String title,
    required String description,
    required IconData icon,
    required Color iconColor,
    required String value,
    required bool isSelected,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedOption = value;
          if (value != 'under_authority') {
            _selectedAuthorityId = null;
            _selectedAuthorityName = null;
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? iconColor.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? iconColor : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? iconColor : isDark?Colors.white:Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: iconColor,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthoritySelection() {

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Parent Authority',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Choose the government authority your company operates under:',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 16),

        // Search Bar
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search authorities by name, state, or LGA...',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: Colors.grey.shade100,
          ),
        ),
        const SizedBox(height: 16),

        // Authorities List
        if (_isLoadingAuthorities)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_filteredAuthorities.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                const Text(
                  'No authorities found',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _searchController.text.isEmpty
                      ? 'No authorities available in the system'
                      : 'No authorities match your search',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      _searchController.clear();
                    },
                    child: const Text('Clear Search'),
                  ),
              ],
            ),
          )
        else
          Container(
            constraints: BoxConstraints(
              maxHeight: 300,
            ),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _filteredAuthorities.length,
              itemBuilder: (context, index) {
                final authority = _filteredAuthorities[index];
                final isSelected = _selectedAuthorityId == authority.id;

                return ListTile(
                  leading: authority.logoURL != null && authority.logoURL!.isNotEmpty
                      ? CircleAvatar(
                    backgroundImage: NetworkImage(authority.logoURL!),
                    radius: 20,
                  )
                      : CircleAvatar(
                    backgroundColor: Colors.green.shade100,
                    child: Icon(Icons.account_balance, color: Colors.green),
                  ),
                  title: Text(
                    authority.name,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.green : Colors.black,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (authority.state != null) Text('${authority.state}'),
                      if (authority.localGovernment != null) Text('${authority.localGovernment}'),
                      Text('${authority.linkedCompanies.length} linked companies'),
                    ],
                  ),
                  trailing: isSelected
                      ? Icon(Icons.check_circle, color: Colors.green)
                      : null,
                  onTap: () {
                    setState(() {
                      _selectedAuthorityId = authority.id;
                      _selectedAuthorityName = authority.name;
                    });
                  },
                );
              },
            ),
          ),

        const SizedBox(height: 16),

        // Selected Authority Info
        if (_selectedAuthorityId != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.brightness == Brightness.dark
                  ? theme.colorScheme.secondary.withOpacity(0.2)
                  : theme.colorScheme.secondary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade100),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Selected Authority:',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green.shade800,
                        ),
                      ),
                      Text(
                        _selectedAuthorityName ?? '',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedAuthorityId = null;
                      _selectedAuthorityName = null;
                    });
                  },
                  child: Text(
                    'Change',
                    style: TextStyle(color: Colors.green.shade800),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// Helper function to navigate to the page
Future<void> navigateToCompanyAuthoritySpecificationPage({
  required BuildContext context,
  required Company company,
  required ITCFirebaseLogic firebaseLogic,
  VoidCallback? onSpecificationComplete,
}) async {
  // Check if we should navigate to the page
  if (!company.isUnderAuthority &&
      (company.authorityLinkStatus == "NONE" || company.authorityId == null)) {

    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CompanyAuthoritySpecificationPage(
          company: company,
          firebaseLogic: firebaseLogic,
          onSpecificationComplete: onSpecificationComplete,
        ),
      ),
    );

    return result;
  }
}

// Usage in Company Dashboard or Home Screen
void checkAndNavigateToAuthoritySpecificationPage({
  required BuildContext context,
  required Company company,
  required ITCFirebaseLogic firebaseLogic,
}) {
  // Show after a delay to ensure proper context
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (context.mounted) {
      navigateToCompanyAuthoritySpecificationPage(
        context: context,
        company: company,
        firebaseLogic: firebaseLogic,
        onSpecificationComplete: () {
          // Refresh company data after specification
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Authority specification saved successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        },
      );
    }
  });
}