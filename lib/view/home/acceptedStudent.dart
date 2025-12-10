import 'package:flutter/material.dart';

class AcceptedStudentsPage extends StatefulWidget {
  const AcceptedStudentsPage({super.key});

  @override
  State<AcceptedStudentsPage> createState() => _AcceptedStudentsPageState();
}

class _AcceptedStudentsPageState extends State<AcceptedStudentsPage> {
  final TextEditingController _searchController = TextEditingController();

  // Sample accepted students data
  final List<AcceptedStudent> _students = [
    AcceptedStudent(
      name: 'Aisha Khan',
      studentId: 'STU-84321',
      program: 'UX/UI Design',
      supervisor: 'Dr. Evans',
      status: StudentStatus.onboarding,
      avatarUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuA18b3qfKxIarA4DiBBXokINmjVm0jXf-0KlulkhGDcBeLZAMj6TZYTte6V-zdQ_hJAuokvF5Eb4CpNlJUFpUcw6lC2aqkj7F-l3CdlRYP4fv4Uz04jhAikrq8O5D6-nq9Zh3izKjs08lCN__rmp5j9X8wvNdj7VU9MqCXFg3Vzwjo6gZ5ZL_u8tRE9mCzJVWpnQc_ByQnVShb4pVhJvPie-bVIlxgn4RbSEYUtXWFilHFVfOFHCogYHNAbHE9HfC0cEO4XrBUwhoAI',
    ),
    AcceptedStudent(
      name: 'Ben Carter',
      studentId: 'STU-91234',
      program: 'Data Science',
      supervisor: 'Dr. Patel',
      status: StudentStatus.active,
      avatarUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuBZBKg8xmYjKu1uVdDUnSllqAYp2F4FEkZH_2uGG54SQmS2rgad8oB_YUPx_3Q49MhyqUNUT12nZkeno7rPG_TJJ79eIqbvtCvgLyxHnjPTB7TB1NRHYW73jnvMMwMWQ2rB98v19MbMGizlYCrzpTRphIoXg0584V1XK3JSIyx2BAn0xuL7JzSjV64FR-4lT-19Q9h8HE7_u50QDE-vloGcKz8GvgQiRyaHLrZpe5jlQEQ7VUELg0q3fHmznMAENbg0LCQUS7hmBoz1',
    ),
    AcceptedStudent(
      name: 'Chloe Davis',
      studentId: 'STU-76543',
      program: 'Software Engineering',
      supervisor: 'Dr. Lee',
      status: StudentStatus.active,
      avatarUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuDz2D9_W5_NmVbKd_IbCY8sbZsZ2Gp9m4Vw2ZnyAAL2jeG0EE5H3ivWfAEpS4KjAoTq6zPJDLgFPHsURs0AYl34gGRJOmkM5IfU2l7D-4J6v9NhOyo6WAWm7iwILQqB-TFLwxusufMQlJx-FGdXIM9wqeIb_jirQ_UbgXsSA67jJG8VfSSoGXH2gUXm0k2Wxb3UWueuTRfq2NA_eOTjUHZmWb6VeE0cM-H8lLiwrUkoftPwCHwtA4Bp307TpJ0nVR08a8XdtMu5Mz8n',
    ),
    AcceptedStudent(
      name: 'David Miller',
      studentId: 'STU-54321',
      program: 'Cybersecurity',
      supervisor: 'Dr. Evans',
      status: StudentStatus.completed,
      avatarUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuCgPaYbjK3IbI5E_H_Vtepkbh2EcT8UPrle0EVBL_Q4R-pj4VV7CcN68t0mKQTY8zY0KlGdSM0X3itaa5rhHlztqyRT45kouOOkQ8WV2q2_iSfiuSBWDIsoFULEYr-qhBGMcL65SY-irIP0_ogHOiW-QsowfQMo4wwQt1ZJ6VcV0_wzQ2u-HhJFN3r8XKhMxyrjOiCBcy_cXgghEYUYTlh8QflpZs1GqpsZbPSVWWg94QOEy3OQ4rJaQJcOdZu7KCESik1A2-ykPtAs',
    ),
    AcceptedStudent(
      name: 'Emily White',
      studentId: 'STU-11223',
      program: 'UX/UI Design',
      supervisor: 'Dr. Lee',
      status: StudentStatus.active,
      avatarUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuCMexurQTqLlnSFM9Btn9jimslXI6Q9XuEzm_MMEYwlrmUReAPXeHodU7nT-x3NxIUjQeCbqOBTpN7z8AnK_76c9hgoB5qrdypJYWnFFPVsILaMaGLoE7LeAsq3-wivzuLFUbRUcVdAeJoEshwSWFaUpSwypNE9TMoPtZ8mIriEDy-1WMJWRJ5aZMFQt0d9GmK_WHyQCeUeu9uU8ATxOahcSOAvvRHk4VItMcYiHfXDu2WWWcwV5UT6sOszuOGEBftPzr_cGN2p7vN2',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar
            _buildTopAppBar(context),

            // Search Bar
            _buildSearchBar(context),

            // Filter Chips
            _buildFilterChips(context),

            // Students List
            Expanded(child: _buildStudentsList(context)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Add new accepted student
        },
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTopAppBar(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      height: 56,
      color: colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new,
                color: colorScheme.onSurface,
                size: 28,
              ),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
            Expanded(
              child: Center(
                child: Text(
                  'Accepted Students',
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
                // Navigate to add student
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
              child: Icon(Icons.search, color: colorScheme.onSurfaceVariant),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by name, program, or ID',
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

  Widget _buildFilterChips(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip(
              context,
              label: 'All Programs',
              isPrimary: true,
              icon: Icons.keyboard_arrow_down,
            ),
            const SizedBox(width: 12),
            _buildFilterChip(
              context,
              label: 'Start Date',
              icon: Icons.keyboard_arrow_down,
            ),
            const SizedBox(width: 12),
            _buildFilterChip(
              context,
              label: 'Supervisor',
              icon: Icons.keyboard_arrow_down,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(
    BuildContext context, {
    required String label,
    required IconData icon,
    bool isPrimary = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    return Container(
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: isPrimary
            ? colorScheme.primary.withOpacity(0.2)
            : isDark
            ? colorScheme.surfaceContainerHigh
            : colorScheme.surfaceContainer,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: isPrimary
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              icon,
              size: 20,
              color: isPrimary
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentsList(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      color: colorScheme.surfaceContainerLowest,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        separatorBuilder: (context, index) => const SizedBox(height: 4),
        itemCount: _students.length,
        itemBuilder: (context, index) {
          final student = _students[index];
          return _buildStudentCard(context, student);
        },
      ),
    );
  }

  Widget _buildStudentCard(BuildContext context, AcceptedStudent student) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () {
          // Navigate to student details
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 28,
                backgroundImage: NetworkImage(student.avatarUrl),
                backgroundColor: colorScheme.surfaceContainer,
              ),
              const SizedBox(width: 16),

              // Student Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            student.name,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _getStatusColor(student.status),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _getStatusText(student.status),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: _getStatusColor(student.status),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'ID: ${student.studentId}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${student.program} | ${student.supervisor}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Chevron
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(StudentStatus status) {
    switch (status) {
      case StudentStatus.onboarding:
        return const Color(0xFF007AFF); // Blue
      case StudentStatus.active:
        return const Color(0xFF34C759); // Green
      case StudentStatus.completed:
        return const Color(0xFF8E8E93); // Gray
    }
  }

  String _getStatusText(StudentStatus status) {
    switch (status) {
      case StudentStatus.onboarding:
        return 'Onboarding';
      case StudentStatus.active:
        return 'Active';
      case StudentStatus.completed:
        return 'Completed';
    }
  }
}

// Helper classes
enum StudentStatus { onboarding, active, completed }

class AcceptedStudent {
  final String name;
  final String studentId;
  final String program;
  final String supervisor;
  final StudentStatus status;
  final String avatarUrl;

  AcceptedStudent({
    required this.name,
    required this.studentId,
    required this.program,
    required this.supervisor,
    required this.status,
    required this.avatarUrl,
  });
}
