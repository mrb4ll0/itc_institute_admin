import 'package:flutter/material.dart';

import '../../generalmethods/GeneralMethods.dart';

class SupervisorsListPage extends StatefulWidget {
  const SupervisorsListPage({super.key});

  @override
  State<SupervisorsListPage> createState() => _SupervisorsListPageState();
}

class _SupervisorsListPageState extends State<SupervisorsListPage> {
  final TextEditingController _searchController = TextEditingController();

  // Sample supervisors data
  final List<Supervisor> _supervisors = [
    Supervisor(
      name: 'Dr. Jane Doe',
      position: 'Senior R&D Engineer',
      assignedStudents: 3,
      avatarUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuBvJVek9mNfPJWwdGLY3vFxr9Nmzfa_xZx-NrRLTo9Wf9a82YUB8j6nF0rlXTmpJzIkOsG6Qw0VDA84zEMgmomiAaMVzvCvLggU_TeOXs7zsEaBMuP6xn-qLxXccV2moT1ubdeSAGU3zzs097gPDy7M7WCOpeev1Q1vfC0mPaXtcGvj5ShsRaIho0IQzoKvFof1a96a9ayuVan44KM16tdpgk1EhPXOnFQfh1z3uQbN5qmnVULwj_xuP5EtQboassoI5RDPi0T8wahg',
    ),
    Supervisor(
      name: 'John Smith',
      position: 'Lead Software Engineer',
      assignedStudents: 5,
      avatarUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuAPo2jpyslyV1fySkgY5UnLgGR1Hfiegg4osKNpGGeGLlgxWhxaF_E9bKnnb9z6uwQ_3zxzA5Jbn2vf7PWnJ9h9u8a8wFXX0OjAQ4Nft12emx5INd9WAy2DHVPCRdwbK85Nn2Hy6dk0ChHff-qY_HCpAeVufk-DV4c9CZkFO-juqmDj8inG_lUfKKeRlc7qcco6oSBONYdmeHfv7_BxFb53FzOKX_rc2D-rTrIuON2LC4TroojFhVMahEW5qHRAmw3zHkrmUPXe04Fe',
    ),
    Supervisor(
      name: 'Emily White',
      position: 'Product Manager',
      assignedStudents: 2,
      avatarUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuAhj05g2N1cb9f0ClUbnpf4-Dbq5STVBhvJRvTSYxT_nNOFa47eIPzX6tvM46j0QyMpbgcZMtAgnHlyyc9_jWqk21Z4umLQasRRaEC_JBke1r8Wm0Hapn9n8k9Mb8kKEGV_lhZKRO80-n2q8KoqgQLeK3rv3yg0wRnjH1wUcgRlHNjguuaZ3sp9YlalxxAsIGPjA4YY5JlweCesasUT5DflyjmzsfYMqyGOTzz_bQcXhRVubSpilUalnIhxTt5iTUDTeyl10Y2Iw_Cr',
    ),
    Supervisor(
      name: 'Michael Brown',
      position: 'Data Science Lead',
      assignedStudents: 4,
      avatarUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuCSWM7hxKE85wV4gBiKYPUlWdlpufGScQtC6IgrJlgwcwdWo1SfPeLtIUQgikh35bC4Uja1CB12XO-S2dPwZ5K_Dl2ui4Qo9DkGin5FpbnKx7c4QarASt2yAUxpt-fAmvBVXYBs-runlUSEWM9itPTUM0ZVZ-ILadYQE63TAIcJfugCDY3-Rs35s-ovy-IhG_zlG4hlPQuAkAqcxHj4DVPZg5EZkB9raQdAB8f3h8_jiH--3pFnb3U0AtTi-SXx4xawJPG2V9lyDzn6',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: isDark
          ? colorScheme.surfaceContainerHighest
          : colorScheme.surfaceContainerLowest,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar
            _buildTopAppBar(context),

            // Search Bar
            _buildSearchBar(context),

            // Supervisors List
            Expanded(
              child: _supervisors.isEmpty
                  ? _buildEmptyState(context)
                  : _buildSupervisorsList(context),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: GeneralMethods.getUniqueHeroTag(),
        onPressed: () {
          // Add new supervisor
        },
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTopAppBar(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.surfaceContainerHighest.withOpacity(0.8)
            : colorScheme.surfaceContainerLowest.withOpacity(0.8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new,
                color: colorScheme.onSurface,
                size: 24,
              ),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
            Expanded(
              child: Center(
                child: Text(
                  'Supervisors',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.add, color: colorScheme.primary, size: 28),
              onPressed: () {
                // Navigate to add supervisor
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isDark
              ? colorScheme.surfaceContainerHigh
              : colorScheme.surfaceContainer,
        ),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Icon(
                Icons.search,
                color: colorScheme.onSurfaceVariant,
                size: 24,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by name or department...',
                    hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: TextStyle(color: colorScheme.onSurface),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupervisorsList(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.separated(
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemCount: _supervisors.length,
        itemBuilder: (context, index) {
          final supervisor = _supervisors[index];
          return _buildSupervisorCard(context, supervisor);
        },
      ),
    );
  }

  Widget _buildSupervisorCard(BuildContext context, Supervisor supervisor) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () {
          // Navigate to supervisor details
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 28,
                backgroundImage: NetworkImage(supervisor.avatarUrl),
                backgroundColor: colorScheme.surfaceContainer,
              ),
              const SizedBox(width: 16),

              // Supervisor Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      supervisor.name,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      supervisor.position,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Assigned Students: ${supervisor.assignedStudents}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // Chevron
              Icon(
                Icons.chevron_right,
                color: colorScheme.onSurfaceVariant,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.person_add, size: 48, color: colorScheme.primary),
          ),
          const SizedBox(height: 24),
          Text(
            'No Supervisors Found',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the + button to add a new supervisor.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// Helper class
class Supervisor {
  final String name;
  final String position;
  final int assignedStudents;
  final String avatarUrl;

  Supervisor({
    required this.name,
    required this.position,
    required this.assignedStudents,
    required this.avatarUrl,
  });
}
