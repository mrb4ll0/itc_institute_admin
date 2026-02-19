import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:itc_institute_admin/itc_logic/firebase/general_cloud.dart';
import 'package:itc_institute_admin/model/authorityCompanyMapper.dart';
import 'package:itc_institute_admin/model/userProfile.dart';
import 'package:itc_institute_admin/view/company/companyDetailPage.dart';
import 'package:provider/provider.dart';

import '../../itc_logic/firebase/authority_cloud.dart';
import '../../model/authority.dart';
import '../../model/company.dart';

class AuthorityCompaniesScreen extends StatefulWidget {
  final String authorityId;
  final String authorityName;

  const AuthorityCompaniesScreen({
    Key? key,
    required this.authorityId,
    required this.authorityName,
  }) : super(key: key);

  @override
  State<AuthorityCompaniesScreen> createState() => _AuthorityCompaniesScreenState();
}

class _AuthorityCompaniesScreenState extends State<AuthorityCompaniesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AuthorityService _authorityService = AuthorityService(FirebaseAuth.instance.currentUser!.uid);

  late Future<List<Company>> _linkedCompaniesFuture;
  late Future<List<Company>> _pendingCompaniesFuture;
  late Authority? authority;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    debugPrint("authorityId is ${widget.authorityId}");
    _loadData();
    _loadAuthority();
  }
  _loadAuthority() async
  {
    authority = await ITCFirebaseLogic(FirebaseAuth.instance.currentUser!.uid).getAuthority(widget.authorityId);
  }

  void _loadData() {
    setState(() {
      _linkedCompaniesFuture = _authorityService
          .getLinkedCompaniesForAuthority(widget.authorityId);
      _pendingCompaniesFuture = _authorityService
          .getPendingCompaniesForAuthority(widget.authorityId);
    });
  }

  void _refreshData() {
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.authorityName} - Companies'),
        actions: [
          IconButton(
            onPressed: _refreshData,
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.pending_actions),
              text: 'Pending',
            ),
            Tab(
              icon: Icon(Icons.link),
              text: 'Linked',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Pending Companies Tab
          _buildPendingTab(),

          // Linked Companies Tab
          _buildLinkedTab(),
        ],
      ),
    );
  }

  Widget _buildPendingTab() {
    return FutureBuilder<List<Company>>(
      future: _pendingCompaniesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          debugPrint("Error in pending tab: ${snapshot.error}");
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Error loading pending companies',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                ElevatedButton(
                  onPressed: _refreshData,
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final pendingCompanies = snapshot.data ?? [];

        if (pendingCompanies.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.pending_actions, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  'No Pending Companies',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  'No companies are waiting for approval',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            _refreshData();
            return;
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: pendingCompanies.length,
            itemBuilder: (context, index) {
              final company = pendingCompanies[index];
              return _buildPendingCompanyCard(company);
            },
          ),
        );
      },
    );
  }

  Widget _buildPendingCompanyCard(Company company) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: company.logoURL.isNotEmpty
            ? CircleAvatar(
          backgroundImage: NetworkImage(company.logoURL),
          radius: 24,
          onBackgroundImageError: (exception, stackTrace) {
            // Handle image error
          },
        )
            : CircleAvatar(
          backgroundColor: Colors.blue[100],
          child: Text(
            company.name.substring(0, 1).toUpperCase(),
            style: const TextStyle(
              color: Colors.blue,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          company.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(company.industry),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.location_on, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${company.localGovernment}, ${company.state}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Chip(
              label: const Text(
                'PENDING',
                style: TextStyle(fontSize: 10, color: Colors.white),
              ),
              backgroundColor: Colors.orange,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'approve',
              child: Row(
                children: [
                  Icon(Icons.check, color: Colors.green),
                  SizedBox(width: 8),
                  Text('Approve'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'reject',
              child: Row(
                children: [
                  Icon(Icons.close, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Reject'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'view',
              child: Row(
                children: [
                  Icon(Icons.visibility),
                  SizedBox(width: 8),
                  Text('View Details'),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            if (value == 'approve') {
              _showApproveDialog(company);
            } else if (value == 'reject') {
              _showRejectDialog(company);
            } else if (value == 'view') {
              _navigateToCompanyDetails(company);
            }
          },
        ),
        onTap: () => _navigateToCompanyDetails(company),
      ),
    );
  }

  Widget _buildLinkedTab() {
    return FutureBuilder<List<Company>>(
      future: _linkedCompaniesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          debugPrint("Error in linked tab: ${snapshot.error}");
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Error loading linked companies',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                ElevatedButton(
                  onPressed: _refreshData,
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final companies = snapshot.data ?? [];

        if (companies.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.business, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  'No Linked Companies',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  'This authority has no companies linked yet',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            _refreshData();
            return;
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: companies.length,
            itemBuilder: (context, index) {
              final company = companies[index];
              return _buildLinkedCompanyCard(company);
            },
          ),
        );
      },
    );
  }

  Widget _buildLinkedCompanyCard(Company company) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: company.logoURL.isNotEmpty
            ? CircleAvatar(
          backgroundImage: NetworkImage(company.logoURL),
          radius: 24,
          onBackgroundImageError: (exception, stackTrace) {
            // Handle image error
          },
        )
            : CircleAvatar(
          backgroundColor: Colors.green[100],
          child: Text(
            company.name.substring(0, 1).toUpperCase(),
            style: TextStyle(
              color: Colors.green[800],
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          company.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(company.industry),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.location_on, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${company.localGovernment}, ${company.state}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            _buildStatusChip(company),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'unlink',
              child: Row(
                children: [
                  Icon(Icons.link_off, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Unlink'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'view',
              child: Row(
                children: [
                  Icon(Icons.visibility),
                  SizedBox(width: 8),
                  Text('View Details'),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            if (value == 'unlink') {
              _showUnlinkDialog(company);
            } else if (value == 'view') {
              _navigateToCompanyDetails(company);
            }
          },
        ),
        onTap: () => _navigateToCompanyDetails(company),
      ),
    );
  }

  Widget _buildStatusChip(Company company) {
    Color chipColor;
    String statusText;

    if (company.isBlocked || company.isBanned) {
      chipColor = Colors.red;
      statusText = 'Blocked';
    } else if (company.isSuspended) {
      chipColor = Colors.orange;
      statusText = 'Suspended';
    } else if (company.isApproved) {
      chipColor = Colors.green;
      statusText = 'Approved';
    } else if (company.isPending) {
      chipColor = Colors.blue;
      statusText = 'Pending';
    } else if (company.isRejected) {
      chipColor = Colors.red;
      statusText = 'Rejected';
    } else {
      chipColor = Colors.grey;
      statusText = 'Inactive';
    }

    return Chip(
      label: Text(
        statusText,
        style: const TextStyle(fontSize: 10, color: Colors.white),
      ),
      backgroundColor: chipColor,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      visualDensity: VisualDensity.compact,
    );
  }

  // Dialog Methods
  void _showApproveDialog(Company company) {
    final remarksController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Company'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Approve ${company.name} to be linked to this authority?'),
            const SizedBox(height: 16),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Remarks (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              controller: remarksController,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _approveCompany(company, remarksController.text);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Approve', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(Company company) {
    final remarksController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Company'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reject ${company.name} from linking to this authority?'),
            const SizedBox(height: 16),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Reason for rejection',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              controller: remarksController,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _rejectCompany(company, remarksController.text);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showUnlinkDialog(Company company) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unlink Company'),
        content: Text('Unlink ${company.name} from this authority?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _unlinkCompany(company);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Unlink', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Action Methods
  Future<void> _approveCompany(Company company, String remarks) async {
    try {
      final result = await _authorityService.approvePendingCompany(
        authorityId: widget.authorityId,
        companyId: company.id,
        remarks: remarks.isNotEmpty ? remarks : null,
        approvedByUserId: 'current_user_id', // Replace with actual user ID
      );

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${company.name} approved successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _refreshData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to approve: ${result['error']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _rejectCompany(Company company, String remarks) async {
    try {
      final result = await _authorityService.rejectPendingCompany(
        authorityId: widget.authorityId,
        companyId: company.id,
        remarks: remarks.isNotEmpty ? remarks : null,
        rejectedByUserId: 'current_user_id', // Replace with actual user ID
      );

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${company.name} rejected'),
            backgroundColor: Colors.orange,
          ),
        );
        _refreshData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reject: ${result['error']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _unlinkCompany(Company company) async {
    try {
      final result = await _authorityService.removeCompanyFromAuthority(
        authorityId: widget.authorityId,
        companyId: company.id,

      );

      if (result == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${company.name} unlinked successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _refreshData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to unlink: }'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _navigateToCompanyDetails(Company company) {
    if(authority == null)
      {
        Fluttertoast.showToast(msg: "Internal Error: Authority is null");
        return;
      }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CompanyDetailPage(company: company, user: UserConverter(AuthorityCompanyMapper.createCompanyFromAuthority(authority: authority!)),),
      ),
    );
  }
}

