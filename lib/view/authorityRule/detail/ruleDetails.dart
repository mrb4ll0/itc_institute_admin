import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../extensions/extensions.dart';
import '../../../model/AuthorityRule.dart' show AuthorityRule;
import '../../../model/authorityRuleExtension.dart';
import '../views/authoriityViewModel.dart';
import '../views/ruleFormEdit.dart';


class RuleDetailPage extends StatefulWidget {
  final AuthorityRule rule;

  const RuleDetailPage({
    Key? key,
    required this.rule,
  }) : super(key: key);

  @override
  State<RuleDetailPage> createState() => _RuleDetailPageState();
}

class _RuleDetailPageState extends State<RuleDetailPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _activityLog = [
    'Rule created by Admin User on ${DateFormat.yMMMd().format(DateTime.now().subtract(const Duration(days: 30)))}',
    'Updated description on ${DateFormat.yMMMd().format(DateTime.now().subtract(const Duration(days: 15)))}',
    'Grace period extended to 45 days on ${DateFormat.yMMMd().format(DateTime.now().subtract(const Duration(days: 7)))}',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rule = widget.rule;

    return Scaffold(
      appBar: AppBar(
        title: Text(rule.title),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.info), text: 'Details'),
            Tab(icon: Icon(Icons.gavel), text: 'Enforcement'),
            Tab(icon: Icon(Icons.people), text: 'Companies'),
            Tab(icon: Icon(Icons.history), text: 'Activity'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _editRule(rule),
            tooltip: 'Edit Rule',
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () => _duplicateRule(rule),
            tooltip: 'Duplicate Rule',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export',
                child: ListTile(
                  leading: Icon(Icons.download),
                  title: Text('Export Rule'),
                ),
              ),
              const PopupMenuItem(
                value: 'archive',
                child: ListTile(
                  leading: Icon(Icons.archive),
                  title: Text('Archive Rule'),
                ),
              ),
              PopupMenuItem(
                value: 'deactivate',
                child: ListTile(
                  leading: Icon(
                    rule.isActive ? Icons.toggle_off : Icons.toggle_on,
                    color: rule.isActive ? Colors.orange : Colors.green,
                  ),
                  title: Text(rule.isActive ? 'Deactivate Rule' : 'Activate Rule'),
                ),
              ),
            ],
            onSelected: (value) => _handlePopupAction(value, rule),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDetailsTab(rule),
          _buildEnforcementTab(rule),
          _buildCompaniesTab(rule),
          _buildActivityTab(rule),
        ],
      ),
    );
  }

  Widget _buildDetailsTab(AuthorityRule rule) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Badges
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(
                label: Text(
                  rule.isActive ? 'ACTIVE' : 'INACTIVE',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                backgroundColor: rule.isActive
                    ? Colors.green.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.1),
                labelStyle: TextStyle(
                  color: rule.isActive ? Colors.green : Colors.grey,
                ),
              ),
              Chip(
                label: Text(
                  StringExtension(rule.category.name.replaceAll('_', ' ')).toTitleCase(),
                ),
                backgroundColor: Colors.blue.withOpacity(0.1),
                labelStyle: const TextStyle(color: Colors.blue),
              ),
              Chip(
                label: Text(
                  StringExtension(rule.type.name.replaceAll('_', ' ')).toTitleCase(),
                ),
                backgroundColor: Colors.purple.withOpacity(0.1),
                labelStyle: const TextStyle(color: Colors.purple),
              ),
              if (rule.isMandatory)
                Chip(
                  label: const Text('MANDATORY'),
                  backgroundColor: Colors.red.withOpacity(0.1),
                  labelStyle: const TextStyle(color: Colors.red),
                ),
            ],
          ),

          const SizedBox(height: 24),

          // Description
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Description',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(rule.description),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Effective Dates
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Validity Period',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildDateInfo(
                        icon: Icons.calendar_today,
                        label: 'Effective From',
                        date: rule.effectiveDate,
                      ),
                      const SizedBox(width: 24),
                      if (rule.expiryDate != null)
                        _buildDateInfo(
                          icon: Icons.calendar_today,
                          label: 'Expires On',
                          date: rule.expiryDate!,
                        ),
                    ],
                  ),
                  if (rule.expiryDate != null) ...[
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: _calculateTimeRemainingPercentage(rule.effectiveDate, rule.expiryDate!),
                      backgroundColor: Colors.grey.shade200,
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_calculateDaysRemaining(rule.expiryDate!)} days remaining',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Permission Settings
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Permission Settings',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    label: 'Requires Permission',
                    value: rule.requiresExplicitPermission ? 'Yes' : 'No',
                  ),
                  _buildInfoRow(
                    label: 'Permission Type',
                    value: StringExtension(rule.permissionType.name.replaceAll('_', ' ')).toTitleCase(),
                  ),
                  _buildInfoRow(
                    label: 'Compliance Check',
                    value: StringExtension(rule.complianceCheck.name.replaceAll('_', ' ')).toTitleCase(),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Conditions
          if (rule.conditions.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Auto-Approval Conditions',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ...rule.conditions.map((condition) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green.shade600, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                condition.description,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 16),

          // Required Proofs
          if (rule.requiredProofs.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Required Documents',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ...rule.requiredProofs.map((proof) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Icon(Icons.description, color: Colors.blue.shade600, size: 16),
                            const SizedBox(width: 8),
                            Text(proof),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEnforcementTab(AuthorityRule rule) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Enforcement Action
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Enforcement',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    label: 'Enforcement Action',
                    value: StringExtension(rule.enforcementAction.name.replaceAll('_', ' ')).toTitleCase(),
                  ),
                  _buildInfoRow(
                    label: 'Grace Period',
                    value: '${rule.gracePeriodDays} days',
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Penalty
          if (rule.penalty != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Penalty',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    _buildPenaltyDetails(rule.penalty!),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 16),

          // Messages
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Messages',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (rule.warningMessage != null && rule.warningMessage!.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Warning Message:',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          rule.warningMessage!,
                          style: TextStyle(color: Colors.red.shade600),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  if (rule.successMessage != null && rule.successMessage!.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Success Message:',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          rule.successMessage!,
                          style: TextStyle(color: Colors.green.shade600),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Applicability
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Applicability',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildApplicabilityInfo(rule),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompaniesTab(AuthorityRule rule) {
    // Mock companies data - replace with real data
    final companies = [
      {'name': 'ABC Manufacturing', 'status': 'COMPLIANT', 'lastChecked': '2024-01-15'},
      {'name': 'XYZ Construction', 'status': 'PENDING', 'lastChecked': '2024-01-10'},
      {'name': 'Tech Solutions Ltd', 'status': 'NON_COMPLIANT', 'lastChecked': '2024-01-05'},
      {'name': 'Global Retail', 'status': 'EXEMPTED', 'lastChecked': '2024-01-02'},
      {'name': 'Eco Industries', 'status': 'COMPLIANT', 'lastChecked': '2023-12-28'},
    ];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search companies...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilterChip(
                label: const Text('All'),
                selected: true,
                onSelected: (_) {},
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: companies.length,
            itemBuilder: (context, index) {
              final company = companies[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getStatusColor(company['status'] as String).withOpacity(0.1),
                    child: Icon(
                      _getStatusIcon(company['status'] as String),
                      color: _getStatusColor(company['status'] as String),
                      size: 20,
                    ),
                  ),
                  title: Text(company['name'] as String),
                  subtitle: Text('Last checked: ${company['lastChecked']}'),
                  trailing: Chip(
                    label: Text(
                      StringExtension((company['status'] as String).replaceAll('_', ' ')).toTitleCase(),
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor: _getStatusColor(company['status'] as String).withOpacity(0.1),
                    labelStyle: TextStyle(
                      color: _getStatusColor(company['status'] as String),
                    ),
                  ),
                  onTap: () => _viewCompanyDetails(company['name'] as String),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActivityTab(AuthorityRule rule) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _activityLog.length,
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue.shade50,
              child: const Icon(Icons.history, size: 20, color: Colors.blue),
            ),
            title: Text(_activityLog[index]),
            subtitle: Text('Version ${index + 1}'),
            trailing: const Icon(Icons.chevron_right),
          ),
        );
      },
    );
  }

  // Helper Widgets
  Widget _buildDateInfo({
    required IconData icon,
    required String label,
    required DateTime date,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          DateFormat.yMMMd().format(date),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow({required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPenaltyDetails(Penalty penalty) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow(
          label: 'Penalty Type',
          value: StringExtension(penalty.type.name.replaceAll('_', ' ')).toTitleCase(),
        ),
        if (penalty.description.isNotEmpty)
          _buildInfoRow(
            label: 'Description',
            value: penalty.description,
          ),
        if (penalty.amount != null)
          _buildInfoRow(
            label: 'Amount',
            value: '\$${penalty.amount!.toStringAsFixed(2)}',
          ),
        if (penalty.suspensionDays != null)
          _buildInfoRow(
            label: 'Suspension Days',
            value: '${penalty.suspensionDays} days',
          ),
        if (penalty.isRecurring && penalty.recurrenceDays != null)
          _buildInfoRow(
            label: 'Recurs Every',
            value: '${penalty.recurrenceDays} days',
          ),
      ],
    );
  }

  Widget _buildApplicabilityInfo(AuthorityRule rule) {
    if (rule.applyToAllCompanies) {
      return const Text(
        'This rule applies to ALL companies under this authority.',
        style: TextStyle(color: Colors.green, fontWeight: FontWeight.w500),
      );
    }

    final applicableTo = <String>[];

    if (rule.applicableCompanyTypes.isNotEmpty) {
      applicableTo.add('Company Types: ${rule.applicableCompanyTypes.join(', ')}');
    }
    if (rule.applicableIndustries.isNotEmpty) {
      applicableTo.add('Industries: ${rule.applicableIndustries.join(', ')}');
    }
    if (rule.applicableCompanySizes.isNotEmpty) {
      applicableTo.add('Company Sizes: ${rule.applicableCompanySizes.join(', ')}');
    }

    if (applicableTo.isEmpty) {
      return const Text('No specific applicability defined.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: applicableTo.map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text('• $item'),
        );
      }).toList(),
    );
  }

  // Helper Methods
  double _calculateTimeRemainingPercentage(DateTime start, DateTime end) {
    final total = end.difference(start).inDays;
    final remaining = end.difference(DateTime.now()).inDays;
    if (total <= 0 || remaining <= 0) return 0.0;
    return remaining / total;
  }

  int _calculateDaysRemaining(DateTime expiryDate) {
    final remaining = expiryDate.difference(DateTime.now()).inDays;
    return remaining > 0 ? remaining : 0;
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'COMPLIANT':
        return Colors.green;
      case 'PENDING':
        return Colors.orange;
      case 'NON_COMPLIANT':
        return Colors.red;
      case 'EXEMPTED':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'COMPLIANT':
        return Icons.check_circle;
      case 'PENDING':
        return Icons.pending;
      case 'NON_COMPLIANT':
        return Icons.error;
      case 'EXEMPTED':
        return Icons.verified;
      default:
        return Icons.help;
    }
  }

  // Action Methods
  void _editRule(AuthorityRule rule) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RuleForm(
          authorityId: rule.authorityId,
          initialRule: rule,
          onSaved: (updatedRule) {
            final viewModel = context.read<AuthorityViewModel>();
            viewModel.updateRule(updatedRule);
            Navigator.pop(context); // Pop back to detail page
          },
        ),
      ),
    );
  }

  void _duplicateRule(AuthorityRule rule) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Duplicate Rule'),
        content: const Text('Create a copy of this rule?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newRule = rule.copyWith(
                id: 'rule_${DateTime.now().millisecondsSinceEpoch}',
                title: '${rule.title} (Copy)',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              );

              final viewModel = context.read<AuthorityViewModel>();
              viewModel.addRule(newRule);

              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Rule duplicated successfully')),
              );
            },
            child: const Text('Duplicate'),
          ),
        ],
      ),
    );
  }

  void _handlePopupAction(String value, AuthorityRule rule) {
    final viewModel = context.read<AuthorityViewModel>();

    switch (value) {
      case 'export':
        _exportRule(rule);
        break;
      case 'archive':
        _archiveRule(rule, viewModel);
        break;
      case 'deactivate':
        _toggleRuleActive(rule, viewModel);
        break;
    }
  }

  void _exportRule(AuthorityRule rule) {
    // Implement export functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Rule exported successfully')),
    );
  }

  void _archiveRule(AuthorityRule rule, AuthorityViewModel viewModel) {
    // Implement archive functionality
  }

  void _toggleRuleActive(AuthorityRule rule, AuthorityViewModel viewModel) {
    viewModel.toggleRule(rule.id, !rule.isActive);
  }

  void _viewCompanyDetails(String companyName) {
    // Navigate to company details page
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Viewing $companyName details')),
    );
  }
}