import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:itc_institute_admin/itc_logic/firebase/general_cloud.dart';
import 'package:provider/provider.dart';
import '../../itc_logic/firebase/AuthorityRulesHelper.dart';
import '../../itc_logic/firebase/StudentAcceptanceRepository.dart';
import '../../model/AuthorityRule.dart';
import '../../model/authorityRuleExtension.dart';
import '../../model/company.dart';


// Create a simple ViewModel for this specific functionality
class StudentAcceptanceViewModel extends ChangeNotifier {
  // Default rule for student acceptance
  // Default rule for student acceptance
  AuthorityRule? _studentAcceptanceRule;

  // List of companies that can accept students (if rule doesn't apply to all)
  final Map<String, bool> _companyAcceptanceStatus = {};

  bool _isLoading = false;
  String? _error;

  StudentAcceptanceViewModel() {
    _initializeDefaultRule();
  }
  final repo = StudentAcceptanceRepository();
  void _initializeDefaultRule() async {
    // Fetch the existing rule
    _studentAcceptanceRule = await repo.fetchRule(FirebaseAuth.instance.currentUser!.uid);

    // Preload all companies under the current authority
    await AuthorityRulesHelper.preloadCompanies(FirebaseAuth.instance.currentUser!.uid);

    // Get all company IDs under this authority
    final allCompanyIds = AuthorityRulesHelper.getAllCompanies().map((c) => c.id).toList();

    // Create a default rule if none exists
    _studentAcceptanceRule ??= AuthorityRule(
      id: "${FirebaseAuth.instance.currentUser!.uid}_${DateTime.now()}",
      authorityId: FirebaseAuth.instance.currentUser!.uid, // current authority ID
      title: 'Student Acceptance Permission',
      description: 'Controls which companies under this authority can accept students for training/internship',
      category: RuleCategory.COMPANY_RELATIONSHIP,
      type: RuleType.PERMISSION_BASED,
      isActive: true,
      isMandatory: true,
      effectiveDate: DateTime.now(),
      requiresExplicitPermission: true,
      permissionType: PermissionType.MANUAL_APPROVAL,
      complianceCheck: ComplianceCheck.MANUAL_REVIEW,
      enforcementAction: EnforcementAction.BLOCK_ACTION,
      gracePeriodDays: 7,
      warningMessage: 'This company is not authorized to accept students',
      successMessage: 'Company is authorized to accept students',
      applyToAllCompanies: true, // Default: All companies can accept
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: 'system',
      applicableCompanyIds: allCompanyIds, // assign all company IDs
    );

    // Initialize company acceptance status map
    _companyAcceptanceStatus.clear();
    if (_studentAcceptanceRule!.applyToAllCompanies) {
      // All companies are allowed
      for (var companyId in allCompanyIds) {
        _companyAcceptanceStatus[companyId] = true;
      }
    } else {
      // Only companies listed in applicableCompanyIds are allowed
      for (var companyId in _studentAcceptanceRule!.applicableCompanyIds) {
        _companyAcceptanceStatus[companyId] = true;
      }
    }

    notifyListeners();
  }

  final Map<String, Company> _companyCache = {};
  bool isLoadingCompanies = false;

  List<Company> get companies => _companyCache.values.toList();
 ITCFirebaseLogic itcFirebaseLogic = ITCFirebaseLogic(FirebaseAuth.instance.currentUser!.uid);
  Future<void> loadCompanies(List<String> companyIds) async {
    if (_companyCache.isNotEmpty) return;

    isLoadingCompanies = true;
    notifyListeners();

    for (final id in companyIds) {
      final company = await itcFirebaseLogic.getCompany(id);
      if (company != null) {
        _companyCache[id] = company;
      }
    }

    isLoadingCompanies = false;
    notifyListeners();
  }

  // Getters
  AuthorityRule? get rule => _studentAcceptanceRule;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get applyToAllCompanies => _studentAcceptanceRule?.applyToAllCompanies ?? true;

  // Toggle whether all companies can accept students
  void toggleApplyToAll(bool value) {
    if (_studentAcceptanceRule != null) {
      _studentAcceptanceRule = _studentAcceptanceRule!.copyWith(
        applyToAllCompanies: value,
        updatedAt: DateTime.now(),
      );
      notifyListeners();
    }
  }

  // Set which specific companies can accept
  void setCompanyAcceptanceStatus(String companyId, bool canAccept) {
    _companyAcceptanceStatus[companyId] = canAccept;
    notifyListeners();
  }

  bool canCompanyAcceptStudent(String companyId) {
    if (applyToAllCompanies) {
      return _studentAcceptanceRule?.isActive ?? true;
    }
    return _companyAcceptanceStatus[companyId] ?? false;
  }

  List<String> _getApplicableCompanies() {
    return _companyAcceptanceStatus.entries
        .where((entry) => entry.value == true)
        .map((entry) => entry.key)
        .toList();
  }

  StudentAcceptanceRepository studentAcceptanceRepository = StudentAcceptanceRepository();
  // Save the rule
  Future<void> saveRule() async {
    try {
      _isLoading = true;
      notifyListeners();

      if (_studentAcceptanceRule == null) return;

      final updatedRule = _studentAcceptanceRule!.copyWith(
        applicableCompanyIds: applyToAllCompanies
            ? [] // not needed when global
            : _getApplicableCompanies(),
        updatedAt: DateTime.now(),
      );

      _studentAcceptanceRule = updatedRule;

      debugPrint('Saving rule: ${updatedRule.toString()}');

      // TODO: Save to backend / Firebase
      await studentAcceptanceRepository.saveRule(_studentAcceptanceRule!);

      _error = null;
    } catch (e) {
      _error = 'Failed to save: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

}

// Main Page
class StudentAcceptanceControlPage extends StatefulWidget {
  final String authorityId;
  final List<String> companies; // List of company IDs under this authority

  const StudentAcceptanceControlPage({
    Key? key,
    required this.authorityId,
    required this.companies,
  }) : super(key: key);

  @override
  State<StudentAcceptanceControlPage> createState() => _StudentAcceptanceControlPageState();
}

class _StudentAcceptanceControlPageState extends State<StudentAcceptanceControlPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  ITCFirebaseLogic itcFirebaseLogic = ITCFirebaseLogic(FirebaseAuth.instance.currentUser!.uid);
  List<String> applicableCompanies = [];

  @override
  void initState() {
    super.initState();
    // Initialize with authority ID
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final viewModel = context.read<StudentAcceptanceViewModel>();
      if (viewModel.rule != null) {
        viewModel.rule!.authorityId = widget.authorityId;
      }
      viewModel.loadCompanies(widget.companies);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Acceptance Control'),
      ),
      body: Consumer<StudentAcceptanceViewModel>(
        builder: (context, viewModel, child) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and description
                _buildHeader(),

                const SizedBox(height: 20),

                // Main control: All companies or specific ones
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Who can accept students?',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                                    
                        // Option 1: All companies
                        RadioListTile<bool>(
                          title: const Text('All companies can accept students'),
                          subtitle: const Text('Every company under this authority can accept students'),
                          value: true,
                          groupValue: viewModel.applyToAllCompanies,
                          onChanged: (value) {
                            if (value != null) {
                              viewModel.toggleApplyToAll(value);
                            }
                          },
                        ),
                                    
                        // Option 2: Specific companies
                        RadioListTile<bool>(
                          title: const Text('Only selected companies can accept students'),
                          subtitle: const Text('Choose which specific companies are authorized'),
                          value: false,
                          groupValue: viewModel.applyToAllCompanies,
                          onChanged: (value) {
                            if (value != null) {
                              viewModel.toggleApplyToAll(value);
                            }
                          },
                        ),
                        // Show company list if "specific companies" is selected
                        if (!viewModel.applyToAllCompanies) ...[
                          const SizedBox(height: 20),
                          _buildCompanyListControl(viewModel),
                        ],

                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Save button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: viewModel.isLoading ? null : () => _saveSettings(viewModel),
                    icon: viewModel.isLoading
                        ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Icon(Icons.save),
                    label: Text(viewModel.isLoading ? 'Saving...' : 'Save Settings'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Student Acceptance Control',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Configure which companies under your authority can accept students for training, internship, or other programs.',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  List<Company> catchCompany = [];
  List<String> catchCompanyIds = [];



  Widget _buildCompanyListControl(StudentAcceptanceViewModel viewModel) {
    if (viewModel.isLoadingCompanies) {
      return const Center(child: CircularProgressIndicator());
    }

    final filteredCompanies = viewModel.companies.where((company) {
      if (_searchQuery.isEmpty) return true;
      return company.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: const InputDecoration(
                hintText: 'Search companies...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 12),

            filteredCompanies.isEmpty
                ? const Center(child: Text('No companies found'))
                : ListView.builder(
              shrinkWrap: true,
              physics: const BouncingScrollPhysics(),
              itemCount: filteredCompanies.length,
              itemBuilder: (_, index) {
                final company = filteredCompanies[index];

                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: NetworkImage(company.logoURL),
                  ),
                  title: Text(company.name),
                  subtitle: Text(
                    viewModel.canCompanyAcceptStudent(company.id)
                        ? 'Can accept students'
                        : 'Cannot accept students',
                    style: TextStyle(
                      color: viewModel.canCompanyAcceptStudent(company.id)
                          ? Colors.green
                          : Colors.red,
                    ),
                  ),
                  trailing: Switch(
                    value: viewModel.canCompanyAcceptStudent(company.id),
                    onChanged: (v) {
                      viewModel.setCompanyAcceptanceStatus(company.id, v);
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }



  Future<void> _saveSettings(StudentAcceptanceViewModel viewModel) async {
    await viewModel.saveRule();

    if (viewModel.error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved successfully'),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate back after a short delay
      Future.delayed(const Duration(seconds: 1), () {
        Navigator.pop(context);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${viewModel.error}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

// Usage example (in your drawer or navigation):
Widget _buildNavigationToStudentControl(BuildContext context) {
  return ListTile(
    leading: const Icon(Icons.school),
    title: const Text('Student Acceptance Control'),
    subtitle: const Text('Control which companies can accept students'),
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChangeNotifierProvider(
            create: (_) => StudentAcceptanceViewModel(),
            child: StudentAcceptanceControlPage(
              authorityId: 'your_authority_id', // Pass actual authority ID
              companies: [
                'Company A',
                'Company B',
                'Company C',
                'Company D',
                'Company E',
              ], // Pass actual company list
            ),
          ),
        ),
      );
    },
  );
}