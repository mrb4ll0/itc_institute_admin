import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../extensions/extensions.dart';
import '../../../model/AuthorityRule.dart';
import '../../../model/authorityRuleExtension.dart';

class RuleCard extends StatelessWidget {
  final AuthorityRule rule;
  final VoidCallback onTap;
  final Function(bool) onToggle;
  final VoidCallback onDelete;

  const RuleCard({
    Key? key,
    required this.rule,
    required this.onTap,
    required this.onToggle,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: rule.isActive ? Colors.green.shade100 : Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Title & Status
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _getCategoryIcon(rule.category),
                              size: 16,
                              color: _getCategoryColor(rule.category),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              rule.title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          rule.description,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Toggle Switch
                  Switch(
                    value: rule.isActive,
                    onChanged: onToggle,
                    activeColor: Colors.green,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Rule Details
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  // Category Badge
                  Chip(
                    label: Text(
                      rule.category.name.replaceAll('_', ' ').toTitleCase(),
                    ),
                    backgroundColor: _getCategoryColor(rule.category).withOpacity(0.1),
                    labelStyle: TextStyle(
                      color: _getCategoryColor(rule.category),
                      fontSize: 12,
                    ),
                  ),

                  // Type Badge
                  Chip(
                    label: Text(
                      rule.type.name.replaceAll('_', ' ').toTitleCase(),
                    ),
                    backgroundColor: Colors.blue.shade50,
                    labelStyle: const TextStyle(
                      color: Colors.blue,
                      fontSize: 12,
                    ),
                  ),

                  // Permission Badge
                  if (rule.requiresExplicitPermission)
                    Chip(
                      label: const Text('Permission Required'),
                      backgroundColor: Colors.orange.shade50,
                      labelStyle: const TextStyle(
                        color: Colors.orange,
                        fontSize: 12,
                      ),
                    ),

                  // Mandatory Badge
                  if (rule.isMandatory)
                    Chip(
                      label: const Text('Mandatory'),
                      backgroundColor: Colors.red.shade50,
                      labelStyle: const TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),

              // Footer with dates and actions
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Dates
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Effective: ${DateFormat.yMMMd().format(rule.effectiveDate)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      if (rule.expiryDate != null)
                        Text(
                          'Expires: ${DateFormat.yMMMd().format(rule.expiryDate!)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),

                  // Actions
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 18),
                        onPressed: onTap,
                        tooltip: 'Edit Rule',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        onPressed: onDelete,
                        tooltip: 'Delete Rule',
                        color: Colors.red.shade300,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(RuleCategory category) {
    switch (category) {
      case RuleCategory.STUDENT_MANAGEMENT:
        return Icons.school; // students & placements

      case RuleCategory.APPROVAL_FLOW:
        return Icons.approval; // approvals & decisions

      case RuleCategory.OPERATIONAL:
        return Icons.settings; // day-to-day operations

      case RuleCategory.COMPLIANCE:
        return Icons.verified; // rules & compliance

      case RuleCategory.REPORTING:
        return Icons.description; // reports

      default:
        return Icons.rule;
    }
  }

  Color _getCategoryColor(RuleCategory category) {
    switch (category) {
      case RuleCategory.STUDENT_MANAGEMENT:
        return Colors.blue; // education-focused

      case RuleCategory.APPROVAL_FLOW:
        return Colors.deepPurple; // authority & control

      case RuleCategory.OPERATIONAL:
        return Colors.orange; // processes

      case RuleCategory.COMPLIANCE:
        return Colors.green; // valid / approved

      case RuleCategory.REPORTING:
        return Colors.teal; // insights & analytics

      default:
        return Colors.grey;
    }
  }


}