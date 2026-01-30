

import '../../../model/AuthorityRule.dart';

abstract class RuleService {
  Future<List<AuthorityRule>> getRulesByAuthority(String authorityId);
  Future<AuthorityRule> getRule(String ruleId);
  Future<AuthorityRule> createRule(AuthorityRule rule);
  Future<AuthorityRule> updateRule(AuthorityRule rule);
  Future<void> deleteRule(String ruleId);
  Future<List<AuthorityRule>> searchRules(String query);
}

// Mock implementation for development
class MockRuleService implements RuleService {
  final Map<String, List<AuthorityRule>> _rulesByAuthority = {};

  @override
  Future<List<AuthorityRule>> getRulesByAuthority(String authorityId) async {
    await Future.delayed(const Duration(milliseconds: 500)); // Simulate network delay
    return _rulesByAuthority[authorityId] ?? [];
  }

  @override
  Future<AuthorityRule> getRule(String ruleId) async {
    await Future.delayed(const Duration(milliseconds: 300));

    for (final rules in _rulesByAuthority.values) {
      final rule = rules.firstWhere(
            (r) => r.id == ruleId,
        orElse: () => throw Exception('Rule not found'),
      );
      return rule;
    }

    throw Exception('Rule not found');
  }

  @override
  Future<AuthorityRule> createRule(AuthorityRule rule) async {
    await Future.delayed(const Duration(milliseconds: 800));

    if (!_rulesByAuthority.containsKey(rule.authorityId)) {
      _rulesByAuthority[rule.authorityId] = [];
    }

    final newRule = rule.copyWith(
      id: 'rule_${DateTime.now().millisecondsSinceEpoch}',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    _rulesByAuthority[rule.authorityId]!.add(newRule);
    return newRule;
  }

  @override
  Future<AuthorityRule> updateRule(AuthorityRule rule) async {
    await Future.delayed(const Duration(milliseconds: 600));

    final authorityRules = _rulesByAuthority[rule.authorityId];
    if (authorityRules == null) {
      throw Exception('Authority not found');
    }

    final index = authorityRules.indexWhere((r) => r.id == rule.id);
    if (index == -1) {
      throw Exception('Rule not found');
    }

    final updatedRule = rule.copyWith(updatedAt: DateTime.now());
    authorityRules[index] = updatedRule;
    return updatedRule;
  }

  @override
  Future<void> deleteRule(String ruleId) async {
    await Future.delayed(const Duration(milliseconds: 400));

    for (final rules in _rulesByAuthority.values) {
      rules.removeWhere((rule) => rule.id == ruleId);
    }
  }

  @override
  Future<List<AuthorityRule>> searchRules(String query) async {
    await Future.delayed(const Duration(milliseconds: 500));

    final allRules = _rulesByAuthority.values.expand((x) => x).toList();
    if (query.isEmpty) return allRules;

    final queryLower = query.toLowerCase();
    return allRules.where((rule) {
      return rule.title.toLowerCase().contains(queryLower) ||
          rule.description.toLowerCase().contains(queryLower);
    }).toList();
  }
}