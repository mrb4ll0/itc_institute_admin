import 'package:flutter/material.dart';
import 'package:itc_institute_admin/view/authorityRule/views/authoriityViewModel.dart';
import 'package:itc_institute_admin/view/authorityRule/views/ruleCard.dart';
import 'package:itc_institute_admin/view/authorityRule/views/ruleFormEdit.dart';
import 'package:provider/provider.dart';

import '../../model/AuthorityRule.dart';
import '../../model/authorityRuleExtension.dart';
import 'detail/compliancePage.dart';
import 'detail/ruleDetails.dart';


class AuthorityRulesPage extends StatefulWidget {
  final String authorityId;

  const AuthorityRulesPage({Key? key, required this.authorityId}) : super(key: key);

  @override
  State<AuthorityRulesPage> createState() => _AuthorityRulesPageState();
}

class _AuthorityRulesPageState extends State<AuthorityRulesPage> {
  final _searchController = TextEditingController();
  RuleCategory? _selectedCategory;
  RuleType? _selectedType;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Authority Rules & Permissions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.dashboard),
            onPressed: _showComplianceDashboard,
            tooltip: 'Compliance Dashboard',
          ),
          IconButton(
            icon: const Icon(Icons.analytics),
            onPressed: _showAnalytics,
            tooltip: 'Rule Analytics',
          ),
        ],
      ),
      body: SafeArea(
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverToBoxAdapter(child: _buildStatsHeader()),
              SliverToBoxAdapter(child: _buildSearchFilterBar()),
            ];
          },
          body: _buildRulesList(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addNewRule,
        icon: const Icon(Icons.add_circle_outline),
        label: const Text('New Rule'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  Widget _buildStatsHeader() {
    return Consumer<AuthorityViewModel>(
      builder: (context, viewModel, child) {
        final stats = viewModel.getRuleStatistics(widget.authorityId);
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.05),
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                count: stats.totalRules,
                label: 'Total Rules',
                icon: Icons.rule,
                color: Colors.blue,
              ),
              _buildStatItem(
                count: stats.activeRules,
                label: 'Active',
                icon: Icons.check_circle,
                color: Colors.green,
              ),
              _buildStatItem(
                count: stats.pendingRequests,
                label: 'Pending',
                icon: Icons.pending_actions,
                color: Colors.orange,
              ),
              _buildStatItem(
                count: stats.violations,
                label: 'Violations',
                icon: Icons.gavel,
                color: Colors.red,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem({
    required int count,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 4),
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchFilterBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          // Search Bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search rules...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  _onSearchChanged('');
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            onChanged: _onSearchChanged,
          ),
          const SizedBox(height: 12),

          // Filter Chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // Category Filter
              FilterChip(
                label: const Text('All Categories'),
                selected: _selectedCategory == null,
                onSelected: (_) {
                  setState(() => _selectedCategory = null);
                },
              ),
              ...RuleCategory.values.map((category) {
                return FilterChip(
                  label: Text(_formatCategoryName(category.name)),
                  selected: _selectedCategory == category,
                  onSelected: (selected) {
                    setState(() => _selectedCategory = selected ? category : null);
                  },
                );
              }).toList(),

              const SizedBox(width: 16),

              // Type Filter
              FilterChip(
                label: const Text('All Types'),
                selected: _selectedType == null,
                onSelected: (_) {
                  setState(() => _selectedType = null);
                },
              ),
              ...RuleType.values.map((type) {
                return FilterChip(
                  label: Text(_formatTypeName(type.name)),
                  selected: _selectedType == type,
                  onSelected: (selected) {
                    setState(() => _selectedType = selected ? type : null);
                  },
                );
              }).toList(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRulesList() {
    return Consumer<AuthorityViewModel>(
      builder: (context, viewModel, child) {
        final rules = viewModel.getFilteredRules(
          authorityId: widget.authorityId,
          category: _selectedCategory,
          type: _selectedType,
          searchQuery: _searchController.text,
        );

        if (rules.isEmpty) {
          return _buildEmptyState();
        }

        return RefreshIndicator(
          onRefresh: () async {
            await viewModel.loadRules(widget.authorityId);
          },
          child: ListView.separated(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: kBottomNavigationBarHeight + 80,
            ),
            itemCount: rules.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final rule = rules[index];
              return RuleCard(
                rule: rule,
                onTap: () => _editRule(rule),
                onToggle: (isActive) => _toggleRule(rule, isActive),
                onDelete: () => _deleteRule(rule),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.rule_folder_outlined,
              size: 80,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 20),
            Text(
              'No Rules Found',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedCategory != null || _selectedType != null || _searchController.text.isNotEmpty
                  ? 'Try changing your filters or search'
                  : 'Create your first rule to get started',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _addNewRule,
              icon: const Icon(Icons.add),
              label: const Text('Create Rule'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return BottomAppBar(
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Quick Actions
            IconButton(
              icon: const Icon(Icons.import_export),
              onPressed: _importExportRules,
              tooltip: 'Import/Export Rules',
            ),

            // Bulk Actions
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'duplicate',
                  child: ListTile(
                    leading: Icon(Icons.copy),
                    title: Text('Duplicate Selected'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'enable_all',
                  child: ListTile(
                    leading: Icon(Icons.toggle_on),
                    title: Text('Enable All'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'disable_all',
                  child: ListTile(
                    leading: Icon(Icons.toggle_off),
                    title: Text('Disable All'),
                  ),
                ),
                 PopupMenuItem(
                  value: 'templates',
                  child: ListTile(
                    leading: Icon(Icons.ten_mp_rounded),
                    title: Text('Rule Templates'),
                  ),
                ),
              ],
              onSelected: _handleBulkAction,
            ),
          ],
        ),
      ),
    );
  }

  // Helper Methods
  String _formatCategoryName(String name) {
    return name.replaceAll('_', ' ').toLowerCase().split(' ').map(
            (word) => word[0].toUpperCase() + word.substring(1)
    ).join(' ');
  }

  String _formatTypeName(String name) {
    return name.replaceAll('_', ' ').toLowerCase().split(' ').map(
            (word) => word[0].toUpperCase() + word.substring(1)
    ).join(' ');
  }

  // Action Methods
  void _addNewRule() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return RuleForm(
          authorityId: widget.authorityId,
          onSaved: (rule) {
            final viewModel = context.read<AuthorityViewModel>();
            viewModel.addRule(rule);
            Navigator.pop(context);
            _showSuccessSnackbar('Rule created successfully');
          },
        );
      },
    );
  }

  void _editRule(AuthorityRule rule) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RuleDetailPage(rule: rule),
      ),
    );
  }

  void _toggleRule(AuthorityRule rule, bool isActive) {
    final viewModel = context.read<AuthorityViewModel>();
    viewModel.updateRule(
      rule.copyWith(isActive: isActive),
    );

    _showSuccessSnackbar(
        isActive ? 'Rule activated' : 'Rule deactivated'
    );
  }

  void _deleteRule(AuthorityRule rule) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Rule'),
        content: const Text('Are you sure you want to delete this rule? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final viewModel = context.read<AuthorityViewModel>();
              viewModel.deleteRule(rule.id);
              Navigator.pop(context);
              _showSuccessSnackbar('Rule deleted');
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _onSearchChanged(String query) {
    final viewModel = context.read<AuthorityViewModel>();
    viewModel.filterRules(query);
  }

  void _showComplianceDashboard() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ComplianceDashboardPage(
          authorityId: widget.authorityId,
        ),
      ),
    );
  }

  void _showAnalytics() {
    // Implement analytics page
  }

  void _importExportRules() {
    // Implement import/export
  }

  void _handleBulkAction(String action) {
    // Handle bulk actions
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }
}