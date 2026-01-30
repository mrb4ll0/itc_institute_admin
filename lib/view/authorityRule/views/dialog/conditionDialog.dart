import 'package:flutter/material.dart';

import '../../../../model/authorityRuleExtension.dart';

class ConditionFormDialog extends StatefulWidget {
  final PermissionCondition? initialCondition;
  final Function(PermissionCondition) onSaved;

  const ConditionFormDialog({
    Key? key,
    this.initialCondition,
    required this.onSaved,
  }) : super(key: key);

  @override
  State<ConditionFormDialog> createState() => _ConditionFormDialogState();
}

class _ConditionFormDialogState extends State<ConditionFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();

  String _field = 'annualRevenue';
  String _operator = 'GREATER_THAN';
  dynamic _value = '1000000';

  @override
  void initState() {
    super.initState();
    if (widget.initialCondition != null) {
      _field = widget.initialCondition!.field;
      _operator = widget.initialCondition!.operator.name;
      _value = widget.initialCondition!.value;
      _descriptionController.text = widget.initialCondition!.description;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.initialCondition == null
                    ? 'Add Condition'
                    : 'Edit Condition',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description *',
                  hintText: 'e.g., Annual revenue must exceed \$ 1,000,000',
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Field Selection
              DropdownButtonFormField<String>(
                value: _field,
                decoration: const InputDecoration(
                  labelText: 'Field to Check',
                  border: OutlineInputBorder(),
                ),
                items: [
                  'annualRevenue',
                  'employeeCount',
                  'companyType',
                  'industry',
                  'yearsInOperation',
                  'capital',
                  'hasLicense',
                  'complianceScore',
                ].map((field) {
                  return DropdownMenuItem(
                    value: field,
                    child: Text(_formatFieldName(field)),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _field = value!);
                },
              ),
              const SizedBox(height: 16),

              // Operator Selection
              DropdownButtonFormField<String>(
                value: _operator,
                decoration: const InputDecoration(
                  labelText: 'Operator',
                  border: OutlineInputBorder(),
                ),
                items: ConditionOperator.values.map((op) {
                  return DropdownMenuItem(
                    value: op.name,
                    child: Text(_formatOperatorName(op.name)),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _operator = value!);
                },
              ),
              const SizedBox(height: 16),

              // Value Input
              _buildValueInput(),

              const SizedBox(height: 24),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _saveCondition,
                    child: const Text('Save Condition'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildValueInput() {
    // Show different input based on field type
    if (_field == 'hasLicense' || _field == 'isActive') {
      return DropdownButtonFormField<dynamic>(
        value: _value is bool ? _value : _value == 'true',
        decoration: const InputDecoration(
          labelText: 'Value',
          border: OutlineInputBorder(),
        ),
        items: const [
          DropdownMenuItem(value: true, child: Text('True')),
          DropdownMenuItem(value: false, child: Text('False')),
        ],
        onChanged: (value) {
          setState(() => _value = value!);
        },
      );
    } else if (_field == 'companyType' || _field == 'industry') {
      final List<String> options = _field == 'companyType'
          ? ['LLC', 'CORPORATION', 'PARTNERSHIP', 'SOLE_PROPRIETORSHIP']
          : ['MANUFACTURING', 'CONSTRUCTION', 'RETAIL', 'SERVICES', 'TECHNOLOGY'];

      return DropdownButtonFormField<dynamic>(
        value: _value,
        decoration: const InputDecoration(
          labelText: 'Value',
          border: OutlineInputBorder(),
        ),
        items: options.map((option) {
          return DropdownMenuItem(
            value: option,
            child: Text(option),
          );
        }).toList(),
        onChanged: (value) {
          setState(() => _value = value!);
        },
      );
    } else {
      // Numeric or text field
      return TextFormField(
        initialValue: _value.toString(),
        decoration: const InputDecoration(
          labelText: 'Value *',
          hintText: 'Enter the comparison value',
          border: OutlineInputBorder(),
        ),
        keyboardType: _field.contains('Count') || _field.contains('Revenue')
            ? TextInputType.number
            : TextInputType.text,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter a value';
          }
          return null;
        },
        onChanged: (value) {
          _value = _field.contains('Count') || _field.contains('Revenue')
              ? (int.tryParse(value) ?? 0)
              : value;
        },
      );
    }
  }

  String _formatFieldName(String field) {
    return field.replaceAllMapped(
      RegExp(r'([A-Z])'),
          (match) => ' ${match.group(1)}',
    ).replaceAllMapped(
      RegExp(r'^[a-z]'),
          (match) => match.group(0)!.toUpperCase(),
    ).replaceAll('annual Revenue', 'Annual Revenue')
        .replaceAll('employee Count', 'Employee Count')
        .replaceAll('company Type', 'Company Type')
        .replaceAll('years In Operation', 'Years in Operation')
        .replaceAll('has License', 'Has License')
        .replaceAll('compliance Score', 'Compliance Score');
  }

  String _formatOperatorName(String operator) {
    final Map<String, String> operatorNames = {
      'EQUALS': 'Equals (==)',
      'NOT_EQUALS': 'Not Equals (!=)',
      'GREATER_THAN': 'Greater Than (>)',
      'GREATER_THAN_OR_EQUAL': 'Greater Than or Equal (>=)',
      'LESS_THAN': 'Less Than (<)',
      'LESS_THAN_OR_EQUAL': 'Less Than or Equal (<=)',
      'CONTAINS': 'Contains',
      'NOT_CONTAINS': 'Does Not Contain',
      'STARTS_WITH': 'Starts With',
      'ENDS_WITH': 'Ends With',
      'IN_LIST': 'In List',
      'NOT_IN_LIST': 'Not In List',
    };

    return operatorNames[operator] ?? operator.replaceAll('_', ' ');
  }

  void _saveCondition() {
    if (_formKey.currentState!.validate()) {
      final condition = PermissionCondition(
        field: _field,
        value: _value,
        operator: ConditionOperator.values.firstWhere(
              (op) => op.name == _operator,
        ),
        description: _descriptionController.text,
      );

      widget.onSaved(condition);
      Navigator.pop(context);
    }
  }
}