import 'package:flutter/foundation.dart';

import '../../../model/AuthorityRule.dart';
import '../../../model/authorityRuleExtension.dart';
import '../service/ruleService.dart';


class AuthorityViewModel extends ChangeNotifier {
  final RuleService _ruleService;

  List<AuthorityRule> _rules = [];
  List<AuthorityRule> _filteredRules = [];
  String? _searchQuery;
  RuleCategory? _filterCategory;
  RuleType? _filterType;

  bool _isLoading = false;
  String? _error;

  AuthorityViewModel({required RuleService ruleService})
      : _ruleService = ruleService;

  // Getters
  List<AuthorityRule> get rules => _filteredRules;
  List<AuthorityRule> get allRules => _rules;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Rule Statistics
  RuleStatistics getRuleStatistics(String authorityId) {
    final authorityRules = _rules.where((r) => r.authorityId == authorityId);

    return RuleStatistics(
      totalRules: authorityRules.length,
      activeRules: authorityRules.where((r) => r.isActive).length,
      pendingRequests: 0, // You'll need to get this from permission requests
      violations: 0, // You'll need to get this from violations data
    );
  }

  // Load rules for an authority
  Future<void> loadRules(String authorityId) async {
    try {
      _isLoading = true;
      notifyListeners();

      _rules = await _ruleService.getRulesByAuthority(authorityId);
      _applyFilters();

      _error = null;
    } catch (e) {
      _error = 'Failed to load rules: ${e.toString()}';
      debugPrint('Error loading rules: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get filtered rules
  List<AuthorityRule> getFilteredRules({
    required String authorityId,
    RuleCategory? category,
    RuleType? type,
    String searchQuery = '',
  }) {
    return _rules.where((rule) {
      // Filter by authority
      if (rule.authorityId != authorityId) return false;

      // Filter by category
      if (category != null && rule.category != category) return false;

      // Filter by type
      if (type != null && rule.type != type) return false;

      // Filter by search query
      if (searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        if (!rule.title.toLowerCase().contains(query) &&
            !rule.description.toLowerCase().contains(query)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  // Filter rules
  void filterRules(String query) {
    _searchQuery = query;
    _applyFilters();
  }

  void setCategoryFilter(RuleCategory? category) {
    _filterCategory = category;
    _applyFilters();
  }

  void setTypeFilter(RuleType? type) {
    _filterType = type;
    _applyFilters();
  }

  void _applyFilters() {
    _filteredRules = _rules.where((rule) {
      if (_filterCategory != null && rule.category != _filterCategory) {
        return false;
      }
      if (_filterType != null && rule.type != _filterType) {
        return false;
      }
      if (_searchQuery?.isNotEmpty == true) {
        final query = _searchQuery!.toLowerCase();
        if (!rule.title.toLowerCase().contains(query) &&
            !rule.description.toLowerCase().contains(query)) {
          return false;
        }
      }
      return true;
    }).toList();

    notifyListeners();
  }

  // CRUD Operations
  Future<void> addRule(AuthorityRule rule) async {
    try {
      _isLoading = true;
      notifyListeners();

      final newRule = await _ruleService.createRule(rule);
      _rules.add(newRule);
      _applyFilters();

      _error = null;
    } catch (e) {
      _error = 'Failed to add rule: ${e.toString()}';
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateRule(AuthorityRule rule) async {
    try {
      _isLoading = true;
      notifyListeners();

      final updatedRule = await _ruleService.updateRule(rule);
      final index = _rules.indexWhere((r) => r.id == rule.id);
      if (index != -1) {
        _rules[index] = updatedRule;
      }
      _applyFilters();

      _error = null;
    } catch (e) {
      _error = 'Failed to update rule: ${e.toString()}';
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteRule(String ruleId) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _ruleService.deleteRule(ruleId);
      _rules.removeWhere((rule) => rule.id == ruleId);
      _applyFilters();

      _error = null;
    } catch (e) {
      _error = 'Failed to delete rule: ${e.toString()}';
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleRule(String ruleId, bool isActive) async {
    try {
      final rule = _rules.firstWhere((r) => r.id == ruleId);
      final updatedRule = rule.copyWith(isActive: isActive);
      await updateRule(updatedRule);
    } catch (e) {
      _error = 'Failed to toggle rule: ${e.toString()}';
      rethrow;
    }
  }

  // Bulk operations
  Future<void> enableAllRules(String authorityId) async {
    try {
      _isLoading = true;
      notifyListeners();

      final authorityRules = _rules.where((r) => r.authorityId == authorityId);
      for (final rule in authorityRules) {
        if (!rule.isActive) {
          final updatedRule = rule.copyWith(isActive: true);
          await _ruleService.updateRule(updatedRule);
        }
      }

      await loadRules(authorityId);
      _error = null;
    } catch (e) {
      _error = 'Failed to enable all rules: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> disableAllRules(String authorityId) async {
    try {
      _isLoading = true;
      notifyListeners();

      final authorityRules = _rules.where((r) => r.authorityId == authorityId);
      for (final rule in authorityRules) {
        if (rule.isActive) {
          final updatedRule = rule.copyWith(isActive: false);
          await _ruleService.updateRule(updatedRule);
        }
      }

      await loadRules(authorityId);
      _error = null;
    } catch (e) {
      _error = 'Failed to disable all rules: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Clear filters
  void clearFilters() {
    _searchQuery = null;
    _filterCategory = null;
    _filterType = null;
    _filteredRules = List.from(_rules);
    notifyListeners();
  }
}

// Rule Statistics Model
class RuleStatistics {
  final int totalRules;
  final int activeRules;
  final int pendingRequests;
  final int violations;

  RuleStatistics({
    required this.totalRules,
    required this.activeRules,
    required this.pendingRequests,
    required this.violations,
  });
}