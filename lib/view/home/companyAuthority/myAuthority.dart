import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:itc_institute_admin/view/home/chat/chartPage.dart';
import 'dart:math' as math;
import '../../../model/authority.dart';

class AuthorityPage extends StatefulWidget {
  final Authority authority;
  final bool isCompanyLinked; // Whether the company is linked to this authority
  final String? companyId; // Current company ID
  final VoidCallback? onChatPressed;
  final VoidCallback? onRefresh;
  final VoidCallback? onApplyPressed; // For applying to authority
  final VoidCallback? onViewApplicationsPressed; // View company's applications

  const AuthorityPage({
    Key? key,
    required this.authority,
    this.isCompanyLinked = false,
    this.companyId,
    this.onChatPressed,
    this.onRefresh,
    this.onApplyPressed,
    this.onViewApplicationsPressed,
  }) : super(key: key);

  @override
  State<AuthorityPage> createState() => _AuthorityPageState();
}

class _AuthorityPageState extends State<AuthorityPage> {
  bool _isLoading = false;
  bool _isExpanded = false;
  final ScrollController _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Custom App Bar with Authority Header
          SliverAppBar(
            expandedHeight: size.height * 0.3,
            pinned: true,
            stretch: true,
            backgroundColor: theme.primaryColor,
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [
                StretchMode.zoomBackground,
                StretchMode.blurBackground,
              ],
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Background with gradient using theme colors
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          theme.primaryColor,
                          theme.primaryColor.withOpacity(0.8),
                          theme.primaryColor.withOpacity(0.6),
                        ],
                      ),
                    ),
                  ),

                  // Decorative circles
                  Positioned(
                    right: -50,
                    top: -50,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.white.withOpacity(0.1),
                      ),
                    ),
                  ),
                  Positioned(
                    left: -30,
                    bottom: -30,
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.white.withOpacity(0.1),
                      ),
                    ),
                  ),

                  // Authority Info
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Logo or Initials
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: theme.shadowColor.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: widget.authority.logoURL != null &&
                              widget.authority.logoURL!.isNotEmpty
                              ? ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                              widget.authority.logoURL!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return _buildInitialsLogo(theme);
                              },
                            ),
                          )
                              : _buildInitialsLogo(theme),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.authority.name,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (widget.authority.registrationNumber != null)
                                Text(
                                  'Reg: ${widget.authority.registrationNumber}',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                ),
                              const SizedBox(height: 8),
                              _buildStatusChips(theme),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              // Refresh button
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: widget.onRefresh,
              ),
            ],
          ),

          // Main Content
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Company Relationship Status Card (for company users)
                if (widget.companyId != null)
                  _buildCompanyRelationshipCard(theme),

                const SizedBox(height: 16),

                // Quick Stats
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatItem(
                              theme: theme,
                              icon: Icons.business_center,
                              value: '${widget.authority.linkedCompanies.length}',
                              label: 'Companies',
                              color: theme.colorScheme.primary,
                            ),
                            _buildStatItem(
                              theme: theme,
                              icon: Icons.pending_actions,
                              value: '${widget.authority.pendingApplications.length}',
                              label: 'Pending',
                              color: theme.colorScheme.secondary,
                            ),
                            _buildStatItem(
                              theme: theme,
                              icon: Icons.check_circle,
                              value: '${widget.authority.approvedApplications.length}',
                              label: 'Approved',
                              color: theme.colorScheme.tertiary ?? Colors.green,
                            ),
                          ],
                        ),
                        const Divider(height: 30),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatItem(
                              theme: theme,
                              icon: Icons.speed,
                              value: '${widget.authority.averageProcessingTimeDays.toStringAsFixed(1)}d',
                              label: 'Avg Time',
                              color: theme.colorScheme.primary,
                            ),
                            _buildStatItem(
                              theme: theme,
                              icon: Icons.percent,
                              value: '${widget.authority.approvalRate.toStringAsFixed(0)}%',
                              label: 'Approval Rate',
                              color: theme.colorScheme.secondary,
                            ),
                            _buildStatItem(
                              theme: theme,
                              icon: Icons.description,
                              value: '${widget.authority.totalApplicationsReviewed}',
                              label: 'Total Reviews',
                              color: theme.colorScheme.tertiary ?? Colors.purple,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Contact Information Card
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.contact_mail,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Contact Information',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildContactInfo(theme),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Description Card
                if (widget.authority.description != null &&
                    widget.authority.description!.isNotEmpty)
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.description,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Description',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            widget.authority.description!,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 16),

                // Additional Details
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Additional Details',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildAdditionalDetails(theme),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 80), // Space for FAB
              ]),
            ),
          ),
        ],
      ),

      // Chat FAB
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
            widget.onChatPressed!();

        },
        icon: const Icon(Icons.chat),
        label: const Text('Chat with Authority'),
        backgroundColor: theme.colorScheme.primary,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildCompanyRelationshipCard(ThemeData theme) {
    final isLinked = widget.isCompanyLinked;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isLinked
              ? theme.colorScheme.primary.withOpacity(0.3)
              : theme.colorScheme.secondary.withOpacity(0.3),
          width: 1,
        ),
      ),
      color: isLinked
          ? theme.colorScheme.primary.withOpacity(0.1)
          : theme.colorScheme.secondary.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isLinked
                    ? theme.colorScheme.primary.withOpacity(0.2)
                    : theme.colorScheme.secondary.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isLinked ? Icons.link : Icons.link_off,
                color: isLinked
                    ? theme.colorScheme.primary
                    : theme.colorScheme.secondary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isLinked ? 'Linked Authority' : 'Not Linked',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isLinked
                          ? theme.colorScheme.primary
                          : theme.colorScheme.secondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isLinked
                        ? 'Your company is linked to this authority'
                        : 'Your company is not yet linked to this authority',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (!isLinked && widget.onApplyPressed != null)
              ElevatedButton(
                onPressed: widget.onApplyPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text('Apply'),
              ),
            if (isLinked && widget.onViewApplicationsPressed != null)
              TextButton(
                onPressed: widget.onViewApplicationsPressed,
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.primary,
                ),
                child: const Text('View Applications'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInitialsLogo(ThemeData theme) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          widget.authority.name
              .split(' ')
              .map((e) => e.isNotEmpty ? e[0] : '')
              .take(2)
              .join()
              .toUpperCase(),
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChips(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    return Wrap(
      spacing: 8,
      children: [
        if (widget.authority.isVerified)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.tertiary ?? Colors.green,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.verified, size: 14, color: Colors.white),
                const SizedBox(width: 4),
                Text(
                  'Verified',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        if (widget.authority.isApproved)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.approval, size: 14, color: Colors.white),
                const SizedBox(width: 4),
                Text(
                  'Approved',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        if (widget.authority.isActive)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, size: 14, color: Colors.white),
                const SizedBox(width: 4),
                Text(
                  'Active',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildStatItem({
    required ThemeData theme,
    required IconData icon,
    required String value,
    required String label,
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
        const SizedBox(height: 8),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildContactInfo(ThemeData theme) {
    return Column(
      children: [
        if (widget.authority.contactPerson != null)
          _buildContactRow(
            theme: theme,
            icon: Icons.person,
            label: 'Contact Person',
            value: widget.authority.contactPerson!,
          ),
        if (widget.authority.email.isNotEmpty)
          _buildContactRow(
            theme: theme,
            icon: Icons.email,
            label: 'Email',
            value: widget.authority.email,
            isEmail: true,
          ),
        if (widget.authority.phoneNumber != null)
          _buildContactRow(
            theme: theme,
            icon: Icons.phone,
            label: 'Phone',
            value: widget.authority.phoneNumber!,
            isPhone: true,
          ),
        if (widget.authority.address != null)
          _buildContactRow(
            theme: theme,
            icon: Icons.location_on,
            label: 'Address',
            value: widget.authority.address!,
          ),
      ],
    );
  }

  Widget _buildContactRow({
    required ThemeData theme,
    required IconData icon,
    required String label,
    required String value,
    bool isEmail = false,
    bool isPhone = false,
  }) {
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 18,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 2),
                InkWell(
                  onTap: isEmail
                      ? () => _launchEmail(value)
                      : isPhone
                      ? () => _launchPhone(value)
                      : null,
                  child: Text(
                    value,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isEmail || isPhone
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                      decoration: isEmail || isPhone
                          ? TextDecoration.underline
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdditionalDetails(ThemeData theme) {
    return Column(
      children: [
        _buildDetailRow(theme, 'State', widget.authority.state),
        _buildDetailRow(theme, 'Local Government', widget.authority.localGovernment),
        _buildDetailRow(theme, 'Registration Number', widget.authority.registrationNumber),
        _buildDetailRow(theme, 'Max Companies', '${widget.authority.maxCompaniesAllowed}'),
        _buildDetailRow(theme, 'Auto Approve', widget.authority.autoApproveAfterAuthority ? 'Yes' : 'No'),
        _buildDetailRow(theme, 'Require Physical Letter', widget.authority.requirePhysicalLetter ? 'Yes' : 'No'),
        if (widget.authority.createdAt != null)
          _buildDetailRow(
            theme,
            'Member Since',
            _formatDate(widget.authority.createdAt!),
          ),
      ],
    );
  }

  Widget _buildDetailRow(ThemeData theme, String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _launchEmail(String email) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
    );
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    }
  }

  void _launchPhone(String phone) async {
    final Uri phoneUri = Uri(
      scheme: 'tel',
      path: phone,
    );
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    }
  }


  // Add imports for launch functionality
  Future<bool> canLaunchUrl(Uri url) async {
    // Implement actual canLaunch logic
    return true;
  }

  Future<void> launchUrl(Uri url) async {
    // Implement actual launch logic
    print('Launching: $url');
  }
}
