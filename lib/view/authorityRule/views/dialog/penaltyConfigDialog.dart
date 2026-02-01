import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../extensions/extensions.dart';
import '../../../../model/authorityRuleExtension.dart';

class PenaltyConfigDialog extends StatefulWidget {
  final Penalty? initialPenalty;
  final Function(Penalty) onSaved;

  const PenaltyConfigDialog({
    Key? key,
    this.initialPenalty,
    required this.onSaved,
  }) : super(key: key);

  @override
  State<PenaltyConfigDialog> createState() => _PenaltyConfigDialogState();
}

class _PenaltyConfigDialogState extends State<PenaltyConfigDialog> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();

  late PenaltyType _type;
  double? _amount;
  int? _suspensionDays;
  bool _isRecurring = false;
  int? _recurrenceDays;

  @override
  void initState() {
    super.initState();
    if (widget.initialPenalty != null) {
      _type = widget.initialPenalty!.type;
      _amount = widget.initialPenalty!.amount;
      _suspensionDays = widget.initialPenalty!.suspensionDays;
      _isRecurring = widget.initialPenalty!.isRecurring;
      _recurrenceDays = widget.initialPenalty!.recurrenceDays;
      _descriptionController.text = widget.initialPenalty!.description;
    } else {
      _type = PenaltyType.WARNING;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Configure Penalty',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),

                // Penalty Type
                DropdownButtonFormField<PenaltyType>(
                  value: _type,
                  decoration: const InputDecoration(
                    labelText: 'Penalty Type *',
                    border: OutlineInputBorder(),
                  ),
                  items: PenaltyType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(formatPenaltyType(type)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _type = value!);
                  },
                  validator: (value) {
                    if (value == null) {
                      return 'Please select a penalty type';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Description
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description *',
                    hintText: 'e.g., Fine for late submission',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a description';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),


                // Suspension Days (for SUSPENSION type)
                if (_type == PenaltyType.SUSPENSION)
                  TextFormField(
                    initialValue: _suspensionDays?.toString() ?? '',
                    decoration: const InputDecoration(
                      labelText: 'Suspension Days *',
                      hintText: 'e.g., 30',
                      border: OutlineInputBorder(),
                      suffixText: 'days',
                    ),
                    keyboardType: TextInputType.number,
                    validator: _type == PenaltyType.SUSPENSION ? (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter suspension days';
                      }
                      final days = int.tryParse(value);
                      if (days == null || days <= 0) {
                        return 'Please enter valid days';
                      }
                      return null;
                    } : null,
                    onChanged: (value) {
                      _suspensionDays = int.tryParse(value) ?? 0;
                    },
                  ),

                // Blacklist Days (for BLACKLIST type)
                if (_type == PenaltyType.BLACKLIST)
                  TextFormField(
                    initialValue: _suspensionDays?.toString() ?? '',
                    decoration: const InputDecoration(
                      labelText: 'Blacklist Period *',
                      hintText: 'e.g., 365',
                      border: OutlineInputBorder(),
                      suffixText: 'days',
                    ),
                    keyboardType: TextInputType.number,
                    validator: _type == PenaltyType.BLACKLIST ? (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter blacklist period';
                      }
                      final days = int.tryParse(value);
                      if (days == null || days <= 0) {
                        return 'Please enter valid days';
                      }
                      return null;
                    } : null,
                    onChanged: (value) {
                      _suspensionDays = int.tryParse(value) ?? 0;
                    },
                  ),

                const SizedBox(height: 16),

                // Recurring Penalty
                SwitchListTile(
                  title: const Text('Recurring Penalty'),
                  subtitle: const Text('Penalty repeats if issue is not fixed'),
                  value: _isRecurring,
                  onChanged: (value) {
                    setState(() => _isRecurring = value);
                  },
                ),

                // Recurrence Interval
                if (_isRecurring)
                  TextFormField(
                    initialValue: _recurrenceDays?.toString() ?? '30',
                    decoration: const InputDecoration(
                      labelText: 'Repeat Every',
                      hintText: 'e.g., 30',
                      border: OutlineInputBorder(),
                      suffixText: 'days',
                    ),
                    keyboardType: TextInputType.number,
                    validator: _isRecurring ? (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter recurrence interval';
                      }
                      final days = int.tryParse(value);
                      if (days == null || days <= 0) {
                        return 'Please enter valid days';
                      }
                      return null;
                    } : null,
                    onChanged: (value) {
                      _recurrenceDays = int.tryParse(value) ?? 30;
                    },
                  ),

                const SizedBox(height: 24),

                // Preview
                if (_isValidPenalty())
                  Card(
                    color: Colors.red.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Penalty Preview:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(_generatePenaltyDescription()),
                        ],
                      ),
                    ),
                  ),

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
                      onPressed: _savePenalty,
                      child: const Text('Save Penalty'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String formatPenaltyType(PenaltyType type) {
    switch (type) {
      case PenaltyType.WARNING:
        return 'Warning (Notification Only)';
      case PenaltyType.SUSPENSION:
        return 'Suspension (Temporary Ban)';
      case PenaltyType.BLACKLIST:
        return 'Blacklist (Cannot Reapply)';
    }
  }





  bool _isValidPenalty() {
    return _descriptionController.text.isNotEmpty &&
        (_type != PenaltyType.SUSPENSION || (_suspensionDays != null && _suspensionDays! > 0)) &&
        (_type != PenaltyType.BLACKLIST || (_suspensionDays != null && _suspensionDays! > 0)) &&
        (!_isRecurring || (_recurrenceDays != null && _recurrenceDays! > 0));
  }

  String _generatePenaltyDescription() {
    final List<String> parts = [_descriptionController.text];



    if (_type == PenaltyType.SUSPENSION && _suspensionDays != null) {
      parts.add('Suspension: $_suspensionDays days');
    }

    if (_type == PenaltyType.BLACKLIST && _suspensionDays != null) {
      parts.add('Blacklist period: $_suspensionDays days');
    }

    if (_isRecurring && _recurrenceDays != null) {
      parts.add('Recurs every $_recurrenceDays days until resolved');
    }

    return parts.join('\n');
  }

  void _savePenalty() {
    if (_formKey.currentState!.validate()) {
      final penalty = Penalty(
        type: _type,
        suspensionDays: (_type == PenaltyType.SUSPENSION || _type == PenaltyType.BLACKLIST)
            ? _suspensionDays
            : null,
        description: _descriptionController.text,
        isRecurring: _isRecurring,
        recurrenceDays: _isRecurring ? _recurrenceDays : null,
      );

      widget.onSaved(penalty);
      Navigator.pop(context);
    }
  }
}