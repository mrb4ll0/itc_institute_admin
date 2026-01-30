import 'package:flutter/material.dart';

import '../../../model/AuthorityRule.dart';
import '../../../model/authorityRuleExtension.dart';
import 'dialog/conditionDialog.dart';
import 'dialog/penaltyConfigDialog.dart';

class RuleForm extends StatefulWidget {
  final String authorityId;
  final AuthorityRule? initialRule;
  final Function(AuthorityRule) onSaved;

  const RuleForm({
    Key? key,
    required this.authorityId,
    this.initialRule,
    required this.onSaved,
  }) : super(key: key);

  @override
  State<RuleForm> createState() => _RuleFormState();
}

class _RuleFormState extends State<RuleForm> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TabController _tabController;
  String? _warningMessage;
  String? _successMessage;
  // Form fields
  late String _title;
  late String _description;
  late RuleCategory _category;
  late RuleType _type;
  late bool _isMandatory;
  late bool _requiresPermission;
  late PermissionType _permissionType;
  late ComplianceCheck _complianceCheck;
  late EnforcementAction _enforcementAction;

  DateTime? _effectiveDate;
  DateTime? _expiryDate;
  int _gracePeriodDays = 30;

  List<PermissionCondition> _conditions = [];
  List<String> _requiredProofs = [];
   List<String> _applicableCompanyTypes = [];
  List<String> _applicableIndustries = [];
  List<String> _applicableCompanySizes = [];

  Penalty? _penalty;
  String? _validationLogic;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    _warningMessage = widget.initialRule?.warningMessage;
    _successMessage = widget.initialRule?.successMessage;
    // Initialize with existing rule or defaults
    if (widget.initialRule != null) {
      _initializeFromRule(widget.initialRule!);
    } else {
      _initializeDefaults();
    }
  }

  void _initializeFromRule(AuthorityRule rule) {
    _title = rule.title;
    _description = rule.description;
    _category = rule.category;
    _type = rule.type;
    _isMandatory = rule.isMandatory;
    _requiresPermission = rule.requiresExplicitPermission;
    _permissionType = rule.permissionType;
    _complianceCheck = rule.complianceCheck;
    _enforcementAction = rule.enforcementAction;
    _effectiveDate = rule.effectiveDate;
    _expiryDate = rule.expiryDate;
    _gracePeriodDays = rule.gracePeriodDays;
    _conditions.addAll(rule.conditions);
    _requiredProofs.addAll(rule.requiredProofs);
    _applicableCompanyTypes.addAll(rule.applicableCompanyTypes);
    _applicableIndustries.addAll(rule.applicableIndustries);
    _applicableCompanySizes.addAll(rule.applicableCompanySizes);
    _penalty = rule.penalty;
    _validationLogic = rule.validationLogic;
  }

  void _initializeDefaults() {
    _title = '';
    _description = '';
    _category = RuleCategory.OPERATIONAL;
    _type = RuleType.PERMISSION_BASED;
    _isMandatory = false;
    _requiresPermission = true;
    _permissionType = PermissionType.MANUAL_APPROVAL;
    _complianceCheck = ComplianceCheck.MANUAL_REVIEW;
    _enforcementAction = EnforcementAction.BLOCK_ACTION;
    _effectiveDate = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initialRule == null ? 'Create Rule' : 'Edit Rule'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.info), text: 'Basic'),
            Tab(icon: Icon(Icons.settings), text: 'Settings'),
            Tab(icon: Icon(Icons.filter_alt), text: 'Applicability'),
            Tab(icon: Icon(Icons.gavel), text: 'Enforcement'),
          ],
        ),
      ),
      body: Form(
        key: _formKey,
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildBasicInfoTab(),
            _buildSettingsTab(),
            _buildApplicabilityTab(),
            _buildEnforcementTab(),
          ],
        ),
      ),
      persistentFooterButtons: [
        ElevatedButton.icon(
          onPressed: _saveAsDraft,
          icon: const Icon(Icons.save),
          label: const Text('Save Draft'),
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.grey.shade800, backgroundColor: Colors.grey.shade300,
          ),
        ),
        ElevatedButton.icon(
          onPressed: _saveAndPublish,
          icon: const Icon(Icons.publish),
          label: const Text('Publish Rule'),
        ),
      ],
    );
  }

  Widget _buildBasicInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          TextFormField(
            initialValue: _title,
            decoration: const InputDecoration(
              labelText: 'Rule Title *',
              hintText: 'e.g., Annual Revenue Reporting',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a rule title';
              }
              return null;
            },
            onSaved: (value) => _title = value!,
          ),
          const SizedBox(height: 16),

          // Description
          TextFormField(
            initialValue: _description,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Description *',
              hintText: 'Describe what this rule is about...',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a description';
              }
              return null;
            },
            onSaved: (value) => _description = value!,
          ),
          const SizedBox(height: 16),

          // Category & Type
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<RuleCategory>(
                  value: _category,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  items: RuleCategory.values.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(
                        category.name.replaceAll('_', ' ').toTitleCase(),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _category = value!);
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<RuleType>(
                  value: _type,
                  decoration: const InputDecoration(
                    labelText: 'Rule Type',
                    border: OutlineInputBorder(),
                  ),
                  items: RuleType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(
                        type.name.replaceAll('_', ' ').toTitleCase(),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _type = value!);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Effective & Expiry Dates
          Row(
            children: [
              Expanded(
                child: InputDatePickerFormField(
                  initialDate: _effectiveDate ?? DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime(2100),
                  fieldLabelText: 'Effective From',
                  onDateSaved: (date) => _effectiveDate = date,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: InputDatePickerFormField(
                  initialDate: _expiryDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime(2100),
                  fieldLabelText: 'Expires On (Optional)',
                  onDateSaved: (date) => _expiryDate = date,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          const Divider(),

          // Quick Templates Section
          _buildQuickTemplates(),
        ],
      ),
    );
  }

  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                  const SizedBox(height: 8),
                  const Text(
                    'How companies obtain permission for this rule',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),

                  // Requires Explicit Permission
                  SwitchListTile(
                    title: const Text('Requires Explicit Permission'),
                    subtitle: const Text('Companies must request approval'),
                    value: _requiresPermission,
                    onChanged: (value) {
                      setState(() => _requiresPermission = value);
                    },
                  ),

                  if (_requiresPermission) ...[
                    const SizedBox(height: 8),
                    DropdownButtonFormField<PermissionType>(
                      value: _permissionType,
                      decoration: const InputDecoration(
                        labelText: 'Permission Type',
                        border: OutlineInputBorder(),
                      ),
                      items: PermissionType.values.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(
                            type.name.replaceAll('_', ' ').toTitleCase(),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _permissionType = value!);
                      },
                    ),
                  ],

                  // Compliance Check
                  const SizedBox(height: 16),
                  DropdownButtonFormField<ComplianceCheck>(
                    value: _complianceCheck,
                    decoration: const InputDecoration(
                      labelText: 'Compliance Verification',
                      border: OutlineInputBorder(),
                    ),
                    items: ComplianceCheck.values.map((check) {
                      return DropdownMenuItem(
                        value: check,
                        child: Text(
                          check.name.replaceAll('_', ' ').toTitleCase(),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _complianceCheck = value!);
                    },
                  ),

                  // Conditions Section
                  const SizedBox(height: 24),
                  _buildConditionsSection(),
                ],
              ),
            ),
          ),

          // Required Proofs
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Required Proofs/Documents',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: _addRequiredProof,
                      ),
                    ],
                  ),
                  ..._requiredProofs.map((proof) {
                    return ListTile(
                      title: Text(proof),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle, color: Colors.red),
                        onPressed: () => _removeRequiredProof(proof),
                      ),
                    );
                  }).toList(),
                  if (_requiredProofs.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text(
                        'No proofs required',
                        style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Validation Logic (Advanced)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Custom Validation Logic (Advanced)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Define custom validation rules using JSON logic',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: _validationLogic,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      hintText: '{\n  "and": [\n    { ">": [{ "var": "revenue" }, 1000000] },\n    { "==": [{ "var": "companyType" }, "LLC"] }\n  ]\n}',
                      border: OutlineInputBorder(),
                    ),
                    onSaved: (value) => _validationLogic = value,
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _showValidationHelp,
                    icon: const Icon(Icons.help),
                    label: const Text('View Validation Examples'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConditionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Auto-Approval Conditions',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle),
              color: Theme.of(context).primaryColor,
              onPressed: _addCondition,
            ),
          ],
        ),
        ..._conditions.map((condition) {
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              title: Text(condition.description),
              subtitle: Text('${condition.field} ${condition.operator.name} ${condition.value}'),
              trailing: IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _editCondition(condition),
              ),
            ),
          );
        }).toList(),
        if (_conditions.isEmpty)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text(
              'No conditions set. Permission will always require manual approval.',
              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          ),
      ],
    );
  }

  Widget _buildApplicabilityTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Apply to All Toggle
          SwitchListTile(
            title: const Text('Apply to All Companies'),
            subtitle: const Text('Override filters and apply to all companies under this authority'),
            value: _applicableCompanyTypes.isEmpty &&
                _applicableIndustries.isEmpty &&
                _applicableCompanySizes.isEmpty,
            onChanged: (value) {
              setState(() {
                if (value) {
                  _applicableCompanyTypes.clear();
                  _applicableIndustries.clear();
                  _applicableCompanySizes.clear();
                }
              });
            },
          ),

          if (!(_applicableCompanyTypes.isEmpty &&
              _applicableIndustries.isEmpty &&
              _applicableCompanySizes.isEmpty)) ...[
            const SizedBox(height: 24),
            const Text(
              'Apply Rule To:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Company Types
            _buildMultiSelector(
              title: 'Company Types',
              items: const ['LLC', 'CORPORATION', 'PARTNERSHIP', 'SOLE_PROPRIETORSHIP'],
              selectedItems: _applicableCompanyTypes,
              onChanged: (items) => _applicableCompanyTypes = items,
            ),

            // Industries
            _buildMultiSelector(
              title: 'Industries',
              items: const ['MANUFACTURING', 'CONSTRUCTION', 'RETAIL', 'SERVICES', 'TECHNOLOGY'],
              selectedItems: _applicableIndustries,
              onChanged: (items) => _applicableIndustries = items,
            ),

            // Company Sizes
            _buildMultiSelector(
              title: 'Company Sizes',
              items: const ['MICRO', 'SMALL', 'MEDIUM', 'LARGE', 'ENTERPRISE'],
              selectedItems: _applicableCompanySizes,
              onChanged: (items) => _applicableCompanySizes = items,
            ),

            // Preview Section
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Preview Applicability',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getApplicabilityPreview(),
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMultiSelector({
    required String title,
    required List<String> items,
    required List<String> selectedItems,
    required Function(List<String>) onChanged,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: items.map((item) {
                final isSelected = selectedItems.contains(item);
                return FilterChip(
                  label: Text(item.replaceAll('_', ' ').toTitleCase()),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        selectedItems.add(item);
                      } else {
                        selectedItems.remove(item);
                      }
                      onChanged(List.from(selectedItems));
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnforcementTab() {
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
                    'Enforcement Action',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'What happens when this rule is violated',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<EnforcementAction>(
                    value: _enforcementAction,
                    decoration: const InputDecoration(
                      labelText: 'Action',
                      border: OutlineInputBorder(),
                    ),
                    items: EnforcementAction.values.map((action) {
                      return DropdownMenuItem(
                        value: action,
                        child: Text(
                          action.name.replaceAll('_', ' ').toTitleCase(),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _enforcementAction = value!);
                    },
                  ),
                ],
              ),
            ),
          ),

          // Grace Period
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Grace Period',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Time given to companies to comply after violation',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  Slider(
                    value: _gracePeriodDays.toDouble(),
                    min: 0,
                    max: 90,
                    divisions: 18,
                    label: '$_gracePeriodDays days',
                    onChanged: (value) {
                      setState(() => _gracePeriodDays = value.toInt());
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Immediate', style: TextStyle(color: Colors.grey.shade600)),
                      Text('$_gracePeriodDays days', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('90 days', style: TextStyle(color: Colors.grey.shade600)),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Penalty Configuration
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Penalty Configuration',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: Icon(
                          _penalty == null ? Icons.add_circle : Icons.edit,
                          color: Theme.of(context).primaryColor,
                        ),
                        onPressed: _configurePenalty,
                      ),
                    ],
                  ),
                  if (_penalty != null) ...[
                    const SizedBox(height: 8),
                    _buildPenaltyPreview(),
                  ] else ...[
                    const SizedBox(height: 8),
                    const Text(
                      'No penalty configured',
                      style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                    ),
                  ],
                ],
              ),
            ),
          ),

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
                  const SizedBox(height: 16),
                  TextFormField(
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Warning Message',
                      hintText: 'Message shown to companies when they violate this rule',
                      border: OutlineInputBorder(),
                    ),
                    onSaved: (value) => _warningMessage = value,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Success Message',
                      hintText: 'Message shown when companies successfully comply',
                      border: OutlineInputBorder(),
                    ),
                    onSaved: (value) => _successMessage = value,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPenaltyPreview() {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.gavel, color: Colors.red.shade700),
                const SizedBox(width: 8),
                Text(
                  _penalty!.type.name.replaceAll('_', ' ').toTitleCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(_penalty!.description),
            if (_penalty!.amount != null) ...[
              const SizedBox(height: 4),
              Text('Amount: \$${_penalty!.amount!.toStringAsFixed(2)}'),
            ],
            if (_penalty!.suspensionDays != null) ...[
              const SizedBox(height: 4),
              Text('Suspension: ${_penalty!.suspensionDays} days'),
            ],
            if (_penalty!.isRecurring && _penalty!.recurrenceDays != null) ...[
              const SizedBox(height: 4),
              Text('Recurs every ${_penalty!.recurrenceDays} days until fixed'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuickTemplates() {
    final templates = [
      {
        'title': 'Annual Reporting',
        'category': RuleCategory.REPORTING,
        'icon': Icons.description,
      },
      {
        'title': 'Safety Compliance',
        'category': RuleCategory.SAFETY,
        'icon': Icons.security,
      },
      {
        'title': 'Financial Audit',
        'category': RuleCategory.FINANCIAL,
        'icon': Icons.account_balance,
      },
      {
        'title': 'Expansion Permission',
        'category': RuleCategory.EXPANSION,
        'icon': Icons.business,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Templates',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Start with a pre-defined template',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: templates.map((template) {
            return ActionChip(
              avatar: Icon(template['icon'] as IconData),
              label: Text(template['title'] as String),
              onPressed: () => _applyTemplate(template['category'] as RuleCategory),
            );
          }).toList(),
        ),
      ],
    );
  }

  String _getApplicabilityPreview() {
    if (_applicableCompanyTypes.isEmpty &&
        _applicableIndustries.isEmpty &&
        _applicableCompanySizes.isEmpty) {
      return 'This rule will apply to ALL companies under this authority.';
    }

    final parts = <String>[];

    if (_applicableCompanyTypes.isNotEmpty) {
      parts.add('Company types: ${_applicableCompanyTypes.join(', ')}');
    }
    if (_applicableIndustries.isNotEmpty) {
      parts.add('Industries: ${_applicableIndustries.join(', ')}');
    }
    if (_applicableCompanySizes.isNotEmpty) {
      parts.add('Company sizes: ${_applicableCompanySizes.join(', ')}');
    }

    return 'This rule will apply to companies matching:\n${parts.join('\n')}';
  }

  // Action Methods
  void _addCondition() {
    showDialog(
      context: context,
      builder: (context) => ConditionFormDialog(
        onSaved: (condition) {
          setState(() => _conditions.add(condition));
        },
      ),
    );
  }

  void _editCondition(PermissionCondition condition) {
    showDialog(
      context: context,
      builder: (context) => ConditionFormDialog(
        initialCondition: condition,
        onSaved: (updatedCondition) {
          setState(() {
            final index = _conditions.indexOf(condition);
            _conditions[index] = updatedCondition;
          });
        },
      ),
    );
  }

  void _addRequiredProof() {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Add Required Proof'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'e.g., audited_financial_statements.pdf',
              labelText: 'Document/Proof Name',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  setState(() => _requiredProofs.add(controller.text));
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _removeRequiredProof(String proof) {
    setState(() => _requiredProofs.remove(proof));
  }

  void _configurePenalty() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => PenaltyConfigDialog(
        initialPenalty: _penalty,
        onSaved: (penalty) {
          setState(() => _penalty = penalty);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _applyTemplate(RuleCategory category) {
    setState(() {
      _category = category;

      // Pre-fill based on category
      switch (category) {
        case RuleCategory.REPORTING:
          _type = RuleType.PERMISSION_BASED;
          _complianceCheck = ComplianceCheck.DOCUMENT_SUBMISSION;
          _requiredProofs.addAll(['annual_report.pdf', 'financial_statements.pdf']);
          break;
        case RuleCategory.SAFETY:
          _type = RuleType.MANDATORY;
          _isMandatory = true;
          _complianceCheck = ComplianceCheck.SITE_INSPECTION;
          break;
        case RuleCategory.FINANCIAL:
          _type = RuleType.CONDITIONAL;
          _requiresPermission = true;
          _conditions.add(PermissionCondition(
            field: 'annualRevenue',
            value: 1000000,
            operator: ConditionOperator.GREATER_THAN,
            description: 'Annual revenue must exceed \$1,000,000',
          ));
          break;
        case RuleCategory.EXPANSION:
          _type = RuleType.PERMISSION_BASED;
          _permissionType = PermissionType.MANUAL_APPROVAL;
          _requiredProofs.addAll(['business_plan.pdf', 'market_analysis.pdf']);
          break;
        default:
          break;
      }

      _tabController.animateTo(1); // Jump to settings tab
    });
  }

  void _showValidationHelp() {
    // Show validation examples
  }

  void _saveAsDraft() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final rule = AuthorityRule(
        id: widget.initialRule?.id ?? 'rule_${DateTime.now().millisecondsSinceEpoch}',
        authorityId: widget.authorityId,
        title: _title,
        description: _description,
        category: _category,
        type: _type,
        isActive: false, // Draft rules are inactive
        isMandatory: _isMandatory,
        effectiveDate: _effectiveDate!,
        expiryDate: _expiryDate,
        requiresExplicitPermission: _requiresPermission,
        permissionType: _permissionType,
        conditions: _conditions,
        complianceCheck: _complianceCheck,
        validationLogic: _validationLogic,
        requiredProofs: _requiredProofs,
        enforcementAction: _enforcementAction,
        gracePeriodDays: _gracePeriodDays,
        penalty: _penalty,
        warningMessage: _warningMessage,
        successMessage: _successMessage,
        applicableCompanyTypes: _applicableCompanyTypes,
        applicableIndustries: _applicableIndustries,
        applicableCompanySizes: _applicableCompanySizes,
        applyToAllCompanies: _applicableCompanyTypes.isEmpty &&
            _applicableIndustries.isEmpty &&
            _applicableCompanySizes.isEmpty,
        createdAt: widget.initialRule?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: widget.initialRule?.createdBy ?? 'current_user_id',
        version: widget.initialRule?.version ?? 1,
        amendments: widget.initialRule?.amendments ?? [],
      );

      widget.onSaved(rule);
    }
  }

  void _saveAndPublish() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final rule = AuthorityRule(
        id: widget.initialRule?.id ?? 'rule_${DateTime.now().millisecondsSinceEpoch}',
        authorityId: widget.authorityId,
        title: _title,
        description: _description,
        category: _category,
        type: _type,
        isActive: true, // Published rules are active
        isMandatory: _isMandatory,
        effectiveDate: _effectiveDate!,
        expiryDate: _expiryDate,
        requiresExplicitPermission: _requiresPermission,
        permissionType: _permissionType,
        conditions: _conditions,
        complianceCheck: _complianceCheck,
        validationLogic: _validationLogic,
        requiredProofs: _requiredProofs,
        enforcementAction: _enforcementAction,
        gracePeriodDays: _gracePeriodDays,
        penalty: _penalty,
        warningMessage: _warningMessage,
        successMessage: _successMessage,
        applicableCompanyTypes: _applicableCompanyTypes,
        applicableIndustries: _applicableIndustries,
        applicableCompanySizes: _applicableCompanySizes,
        applyToAllCompanies: _applicableCompanyTypes.isEmpty &&
            _applicableIndustries.isEmpty &&
            _applicableCompanySizes.isEmpty,
        createdAt: widget.initialRule?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: widget.initialRule?.createdBy ?? 'current_user_id',
        version: widget.initialRule?.version ?? 1,
        amendments: widget.initialRule?.amendments ?? [],
      );

      widget.onSaved(rule);
    }
  }
}

// Helper extension for string formatting
extension StringExtension on String {
  String toTitleCase() {
    return split(' ').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }
}