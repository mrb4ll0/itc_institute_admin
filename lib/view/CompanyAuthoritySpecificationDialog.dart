import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:itc_institute_admin/itc_logic/firebase/authority_cloud.dart';
import 'package:itc_institute_admin/itc_logic/firebase/general_cloud.dart';
import 'package:itc_institute_admin/model/authority.dart';
import 'package:itc_institute_admin/model/company.dart';

class CompanyAuthoritySpecificationDialog extends StatefulWidget {
  final Company company;
  final ITCFirebaseLogic firebaseLogic;
  final VoidCallback? onSpecificationComplete;
  final bool allowEditing;

  const CompanyAuthoritySpecificationDialog({
    Key? key,
    required this.company,
    required this.firebaseLogic,
    this.onSpecificationComplete,
    this.allowEditing = true,
  }) : super(key: key);

  @override
  State<CompanyAuthoritySpecificationDialog> createState() => _CompanyAuthoritySpecificationDialogState();
}

class _CompanyAuthoritySpecificationDialogState extends State<CompanyAuthoritySpecificationDialog> {
  final AuthorityService _authorityService = AuthorityService(FirebaseAuth.instance.currentUser!.uid);

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
        // Close dialog and call callback
        if (widget.onSpecificationComplete != null) {
          widget.onSpecificationComplete!();
        }
        Navigator.of(context).pop(true);

        Fluttertoast.showToast(
          msg: message,
          toastLength: Toast.LENGTH_LONG,
        );
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
      final companyRef = FirebaseFirestore.instance.collection('users').doc("companies").collection("companies").doc(widget.company.id);

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

  bool _shouldShowDialog() {
    if (widget.allowEditing) {
      // Always show dialog if editing is allowed
      return true;
    }

    return !widget.company.isUnderAuthority &&
        (widget.company.authorityLinkStatus == "NONE" ||
            widget.company.authorityId == null);
  }

  @override
  Widget build(BuildContext context) {
    if (!_shouldShowDialog() && !widget.allowEditing) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    final dialogWidth = isSmallScreen ? screenSize.width * 0.95 : 650.0;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(
          maxHeight: screenSize.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.primaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: theme.colorScheme.onPrimary,
                    child: Icon(
                      Icons.business,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Company Authority Setup',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: theme.brightness == Brightness.dark
                                ? theme.colorScheme.onSurface
                                : theme.colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Specify your company\'s authority relationship',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.brightness == Brightness.dark
                                ? theme.colorScheme.onSurface
                                : theme.colorScheme.onPrimary,
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
                    _buildIntroduction(theme),
                    const SizedBox(height: 24),

                    // Options Selection
                    _buildOptionsSelection(theme),
                    const SizedBox(height: 24),

                    // Authority Selection (only shown if under_authority is selected)
                    if (_selectedOption == 'under_authority')
                      _buildAuthoritySelection(theme),
                  ],
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: theme.dividerColor)),
                color: theme.cardColor,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.secondary,
                    ),
                    child: const Text('Skip for Now'),
                  ),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveSpecification,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.brightness == Brightness.dark
                            ? theme.colorScheme.primaryContainer  // Use primary container in dark theme
                            : theme.primaryColor,                   // Use primary color in light theme
                        foregroundColor: theme.brightness == Brightness.dark
                            ? theme.colorScheme.onPrimaryContainer  // Text color for dark theme
                            : theme.colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            theme.colorScheme.onPrimary,
                          ),
                        ),
                      )
                          : const Text('Save & Continue'),
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

  Widget _buildIntroduction(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome, ${widget.company.name}!',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'To complete your company setup, please specify your authority relationship. '
              'This helps us provide you with the right features and connections.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'This information can be changed later in your company settings.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOptionsSelection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Your Company Type',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Choose the option that best describes your company:',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 20),

        // Standalone Option
        _buildOptionCard(
          theme: theme,
          title: 'Standalone Company',
          description: 'Independent organization not linked to any government authority',
          icon: Icons.business_outlined,
          iconColor: theme.colorScheme.primary,
          value: 'standalone',
          isSelected: _selectedOption == 'standalone',
        ),
        const SizedBox(height: 12),

        // Under Authority Option
        _buildOptionCard(
          theme: theme,
          title: 'Government Facility / Under Authority',
          description: 'Company operating under a government authority or ministry',
          icon: Icons.account_balance,
          iconColor: theme.colorScheme.secondary,
          value: 'under_authority',
          isSelected: _selectedOption == 'under_authority',
        ),
      ],
    );
  }

  Widget _buildOptionCard({
    required ThemeData theme,
    required String title,
    required String description,
    required IconData icon,
    required Color iconColor,
    required String value,
    required bool isSelected,
  }) {
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
            color: isSelected ? iconColor : theme.dividerColor,
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
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isSelected ? iconColor : theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
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

  Widget _buildAuthoritySelection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Parent Authority',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Choose the government authority your company operates under:',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
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
            fillColor: theme.colorScheme.surfaceVariant,
            hintStyle: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.4),
            ),
          ),
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),

        // Authorities List
        if (_isLoadingAuthorities)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
              ),
            ),
          )
        else if (_filteredAuthorities.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.search_off,
                  size: 48,
                  color: theme.colorScheme.onSurface.withOpacity(0.4),
                ),
                const SizedBox(height: 16),
                Text(
                  'No authorities found',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  _searchController.text.isEmpty
                      ? 'No authorities available in the system'
                      : 'No authorities match your search',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      _searchController.clear();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: theme.primaryColor,
                    ),
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
              border: Border.all(color: theme.dividerColor),
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
                    backgroundColor: theme.colorScheme.secondary.withOpacity(0.1),
                    child: Icon(
                      Icons.account_balance,
                      color: theme.colorScheme.secondary,
                    ),
                  ),
                  title: Text(
                    authority.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? theme.colorScheme.secondary : theme.colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (authority.state != null)
                        Text(
                          '${authority.state}',
                          style: theme.textTheme.bodySmall,
                        ),
                      if (authority.localGovernment != null)
                        Text(
                          '${authority.localGovernment}',
                          style: theme.textTheme.bodySmall,
                        ),
                      Text(
                        '${authority.linkedCompanies.length} linked companies',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                  trailing: isSelected
                      ? Icon(Icons.check_circle, color: theme.colorScheme.secondary)
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
              color: theme.colorScheme.secondary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.secondary.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: theme.colorScheme.secondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Selected Authority:',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.secondary,
                        ),
                      ),
                      Text(
                        _selectedAuthorityName ?? '',
                        style: theme.textTheme.bodyLarge?.copyWith(
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
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.secondary,
                  ),
                  child: const Text('Change'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// Helper function to show the dialog
void showCompanyAuthoritySpecificationDialog({
  required BuildContext context,
  required Company company,
  required ITCFirebaseLogic firebaseLogic,
  VoidCallback? onSpecificationComplete,
}) {
  // Check if we should show the dialog
  if (!company.isUnderAuthority &&
      (company.authorityLinkStatus == "NONE" || company.authorityId == null)) {

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CompanyAuthoritySpecificationDialog(
        company: company,
        firebaseLogic: firebaseLogic,
        onSpecificationComplete: onSpecificationComplete,
      ),
    );
  }
}

// Usage in Company Dashboard or Home Screen
void checkAndShowAuthoritySpecificationDialog({
  required BuildContext context,
  required Company company,
  required ITCFirebaseLogic firebaseLogic,
}) {
  // Show after a delay to ensure proper context
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (context.mounted) {
      showCompanyAuthoritySpecificationDialog(
        context: context,
        company: company,
        firebaseLogic: firebaseLogic,
        onSpecificationComplete: () {
          // Refresh company data after specification
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Authority specification saved successfully!'),
              backgroundColor: Theme.of(context).primaryColor,
            ),
          );
        },
      );
    }
  });
}