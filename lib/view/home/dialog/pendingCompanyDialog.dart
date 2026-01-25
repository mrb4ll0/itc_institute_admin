import 'package:flutter/material.dart';
import '../../../itc_logic/firebase/authority_cloud.dart';
import '../../../model/authority.dart';
import '../../../model/company.dart';
import '../LinkedCompaniesScreen.dart';


class PendingCompaniesDialog extends StatefulWidget {
  final Authority authority;
  final AuthorityService authorityService;

  const PendingCompaniesDialog({
    Key? key,
    required this.authority,
    required this.authorityService,
  }) : super(key: key);

  @override
  State<PendingCompaniesDialog> createState() => _PendingCompaniesDialogState();
}

class _PendingCompaniesDialogState extends State<PendingCompaniesDialog> {
  late Future<List<Company>> _pendingCompaniesFuture;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPendingCompanies();
  }

  void _loadPendingCompanies() {
    setState(() {
      _pendingCompaniesFuture = widget.authorityService
          .getPendingCompaniesForAuthority(widget.authority.id);
    });
  }

  void _refreshData() {
    _loadPendingCompanies();
  }

  Future<void> _approveCompany(Company company, [String? remarks]) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await widget.authorityService.approvePendingCompany(
        authorityId: widget.authority.id,
        companyId: company.id,
        remarks: remarks,
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
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _rejectCompany(Company company, [String? remarks]) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await widget.authorityService.rejectPendingCompany(
        authorityId: widget.authority.id,
        companyId: company.id,
        remarks: remarks,
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
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

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
            Text('Approve ${company.name} to be linked to ${widget.authority.name}?'),
            const SizedBox(height: 16),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Remarks (optional)',
                border: OutlineInputBorder(),
                hintText: 'Add any notes about this approval',
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
            onPressed: () {
              Navigator.pop(context);
              _approveCompany(company, remarksController.text);
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
            Text('Reject ${company.name} from linking to ${widget.authority.name}?'),
            const SizedBox(height: 16),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Reason for rejection',
                border: OutlineInputBorder(),
                hintText: 'Explain why this company is being rejected',
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
            onPressed: () {
              Navigator.pop(context);
              _rejectCompany(company, remarksController.text);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showQuickActionDialog(Company company) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${company.name} - Quick Actions'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.check, color: Colors.green),
              title: const Text('Approve'),
              subtitle: const Text('Approve this company request'),
              onTap: () {
                Navigator.pop(context);
                _showApproveDialog(company);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.close, color: Colors.red),
              title: const Text('Reject'),
              subtitle: const Text('Reject this company request'),
              onTap: () {
                Navigator.pop(context);
                _showRejectDialog(company);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.visibility),
              title: const Text('View Details'),
              subtitle: const Text('View company information'),
              onTap: () {
                Navigator.pop(context);
                _showCompanyDetails(company);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showCompanyDetails(Company company) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(company.name),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (company.logoURL.isNotEmpty)
                Center(
                  child: CircleAvatar(
                    backgroundImage: NetworkImage(company.logoURL),
                    radius: 40,
                    onBackgroundImageError: (exception, stackTrace) {
                      // Handle error
                    },
                  ),
                ),
              const SizedBox(height: 16),
              _buildDetailRow('Industry:', company.industry),
              _buildDetailRow('Email:', company.email),
              _buildDetailRow('Phone:', company.phoneNumber),
              _buildDetailRow('Location:', '${company.localGovernment}, ${company.state}'),
              _buildDetailRow('Address:', company.address),
              if (company.description.isNotEmpty)
                _buildDetailRow('Description:', company.description),
              const SizedBox(height: 16),
              const Text(
                'Statistics:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildStatChip('Pending Apps', company.pendingApplications.length),
                  _buildStatChip('Current Trainees', company.currentTrainees.length),
                  _buildStatChip('Completed', company.completedTrainees.length),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showApproveDialog(company);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, int count) {
    return Chip(
      label: Text('$label: $count'),
      backgroundColor: Colors.blue[50],
      side: BorderSide(color: Colors.blue[100]!),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Text(
                      widget.authority.name.substring(0, 1).toUpperCase(),
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.authority.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Pending Company Approvals',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: FutureBuilder<List<Company>>(
                future: _pendingCompaniesFuture,
                builder: (context, snapshot) {
                  if (_isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error, size: 48, color: Colors.red),
                          const SizedBox(height: 16),
                          const Text(
                            'Error loading companies',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            snapshot.error.toString(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 16),
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
                          const Icon(Icons.check_circle, size: 64, color: Colors.green),
                          const SizedBox(height: 16),
                          const Text(
                            'All Caught Up!',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No companies waiting for approval',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    );
                  }

                  return Column(
                    children: [
                      // Summary
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          border: Border(
                            bottom: BorderSide(color: Colors.orange[100]!),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${pendingCompanies.length} company${pendingCompanies.length == 1 ? '' : 's'} waiting',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  onPressed: _refreshData,
                                  icon: const Icon(Icons.refresh, size: 20),
                                  tooltip: 'Refresh',
                                ),
                                IconButton(
                                  onPressed: () {
                                    // Show bulk actions
                                    _showBulkActionsDialog(pendingCompanies);
                                  },
                                  icon: const Icon(Icons.playlist_add_check, size: 20),
                                  tooltip: 'Bulk Actions',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // List
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(0),
                          itemCount: pendingCompanies.length,
                          itemBuilder: (context, index) {
                            final company = pendingCompanies[index];
                            return _buildCompanyItem(company);
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      // Navigate to full screen view
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AuthorityCompaniesScreen(
                            authorityId: widget.authority.id,
                            authorityName: widget.authority.name,
                          ),
                        ),
                      );
                    },
                    child: const Text('View All'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompanyItem(Company company) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: company.logoURL.isNotEmpty
            ? CircleAvatar(
          backgroundImage: NetworkImage(company.logoURL),
          radius: 20,
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
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              company.industry,
              style: const TextStyle(fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              '${company.localGovernment}, ${company.state}',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () => _showApproveDialog(company),
              icon: const Icon(Icons.check, color: Colors.green, size: 20),
              tooltip: 'Approve',
            ),
            IconButton(
              onPressed: () => _showRejectDialog(company),
              icon: const Icon(Icons.close, color: Colors.red, size: 20),
              tooltip: 'Reject',
            ),
          ],
        ),
        onTap: () => _showQuickActionDialog(company),
        onLongPress: () => _showCompanyDetails(company),
      ),
    );
  }

  void _showBulkActionsDialog(List<Company> companies) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bulk Actions'),
        content: Text('Select action for ${companies.length} companies'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _bulkApproveCompanies(companies);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Approve All'),
          ),
          OutlinedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _bulkRejectCompanies(companies);
            },
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reject All'),
          ),
        ],
      ),
    );
  }

  Future<void> _bulkApproveCompanies(List<Company> companies) async {
    setState(() {
      _isLoading = true;
    });

    int successCount = 0;
    int failCount = 0;

    for (final company in companies) {
      try {
        final result = await widget.authorityService.approvePendingCompany(
          authorityId: widget.authority.id,
          companyId: company.id,
          approvedByUserId: 'current_user_id',
        );

        if (result['success'] == true) {
          successCount++;
        } else {
          failCount++;
        }
      } catch (e) {
        failCount++;
      }
    }

    setState(() {
      _isLoading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Approved $successCount companies. Failed: $failCount'),
        backgroundColor: successCount > 0 ? Colors.green : Colors.red,
      ),
    );

    _refreshData();
  }

  Future<void> _bulkRejectCompanies(List<Company> companies) async {
    setState(() {
      _isLoading = true;
    });

    int successCount = 0;
    int failCount = 0;

    for (final company in companies) {
      try {
        final result = await widget.authorityService.rejectPendingCompany(
          authorityId: widget.authority.id,
          companyId: company.id,
          rejectedByUserId: 'current_user_id',
        );

        if (result['success'] == true) {
          successCount++;
        } else {
          failCount++;
        }
      } catch (e) {
        failCount++;
      }
    }

    setState(() {
      _isLoading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Rejected $successCount companies. Failed: $failCount'),
        backgroundColor: successCount > 0 ? Colors.orange : Colors.red,
      ),
    );

    _refreshData();
  }
}

// How to use the dialog:
void showPendingCompaniesDialog(BuildContext context, Authority authority) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => PendingCompaniesDialog(
      authority: authority,
      authorityService: AuthorityService(),
    ),
  );
}

