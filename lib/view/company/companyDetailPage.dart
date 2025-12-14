import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../../../model/student.dart';
import '../../itc_logic/firebase/company_cloud.dart';
import '../../itc_logic/firebase/general_cloud.dart';
import '../../model/company.dart';
import '../../model/review.dart';

class CompanyDetailPage extends StatelessWidget {
  final Company company;
  final Company_Cloud _companyCloud = Company_Cloud();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CompanyDetailPage({super.key, required this.company});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color gradientStart = const Color(0xFF667eea);
    final Color gradientEnd = const Color(0xFF764ba2);
    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF1a1a1a)
          : const Color(0xFFf8fafc),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
        title: Text(
          company.name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.transparent,
          ),
        ),
        centerTitle: true,
      ),
      extendBodyBehindAppBar: true,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Modern Hero Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 80, 24, 32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [gradientStart, gradientEnd, const Color(0xFFf093fb)],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
                boxShadow: [
                  BoxShadow(
                    color: gradientStart.withOpacity(0.18),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    backgroundImage: company.logoURL.isNotEmpty
                        ? NetworkImage(company.logoURL)
                        : const AssetImage('assets/images/default_company.png')
                              as ImageProvider,
                    radius: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    company.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    company.industry,
                    style: const TextStyle(fontSize: 16, color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  FutureBuilder<double>(
                    future: _companyCloud.getAverageCompanyRating(company.id),
                    builder: (context, snapshot) {
                      final avg = snapshot.data ?? 0.0;
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ...List.generate(
                            5,
                            (i) => Icon(
                              i < avg.round() ? Icons.star : Icons.star_border,
                              color: Colors.amber,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            avg.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: gradientStart,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    icon: const Icon(Icons.rate_review),
                    label: const Text('Add Review'),
                    onPressed: () => _showAddReviewDialog(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // About
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, color: Color(0xFF667eea)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "${company.name} is a reputable company in the ${company.industry} industry. It provides excellent opportunities for interns and professionals to grow, innovate, and build real-world experience.",
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Details List
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _buildDetailTile(
                    Icons.location_on,
                    "Address",
                    "${company.address}, ${company.localGovernment}, ${company.state}",
                  ),
                  _buildDetailTile(Icons.email, "Email", company.email),
                  _buildDetailTile(Icons.phone, "Phone", company.phoneNumber),
                  _buildDetailTile(Icons.security, "Role", company.role),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Reviews List
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Student Reviews',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: StreamBuilder<List<CompanyReview>>(
                stream: _companyCloud.getCompanyReviews(company.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final reviews = snapshot.data ?? [];
                  if (reviews.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(
                        'No reviews yet.',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: reviews.map((review) {
                      return FutureBuilder<Widget>(
                        future: _buildReviewTile(review, isDark),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return CircularProgressIndicator(); // or SizedBox.shrink()
                          } else if (snapshot.hasError) {
                            return Text('Error loading review');
                          } else {
                            return snapshot.data!;
                          }
                        },
                      );
                    }).toList(),
                  );
                },
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailTile(IconData icon, String title, String content) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF667eea)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: SelectableText(content),
      ),
    );
  }

  Future<Widget> _buildReviewTile(CompanyReview review, bool isDark) async {
    Student? student = await ITCFirebaseLogic().getStudent(review.studentId);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1,
      color: isDark ? const Color(0xFF232323) : Colors.white,
      child: ListTile(
        leading: CircleAvatar(
          child: Text(
            (student?.fullName.isNotEmpty ?? false)
                ? student!.fullName[0].toUpperCase()
                : "?",
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                (student?.fullName.isNotEmpty ?? false)
                    ? student!.fullName
                    : "",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
            ...List.generate(
              5,
              (i) => Icon(
                i < review.rating ? Icons.star : Icons.star_border,
                color: Colors.amber,
                size: 18,
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(review.comment),
            const SizedBox(height: 4),
            Text(
              '${review.createdAt.toLocal()}'.split(' ')[0],
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddReviewDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return _AddReviewDialog(
          companyId: company.id,
          studentName: _auth.currentUser?.displayName ?? 'Student',
          studentId: _auth.currentUser?.uid ?? '',
          onReviewAdded: () {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Review added!')));
          },
        );
      },
    );
  }
}

class _AddReviewDialog extends StatefulWidget {
  final String companyId;
  final String studentName;
  final String studentId;
  final VoidCallback onReviewAdded;

  const _AddReviewDialog({
    Key? key,
    required this.companyId,
    required this.studentName,
    required this.studentId,
    required this.onReviewAdded,
  }) : super(key: key);

  @override
  _AddReviewDialogState createState() => _AddReviewDialogState();
}

class _AddReviewDialogState extends State<_AddReviewDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  int _rating = 5;
  String _comment = '';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add Review'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                5,
                (i) => IconButton(
                  icon: Icon(
                    i < _rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                  ),
                  onPressed: () {
                    setState(() {
                      _rating = i + 1;
                    });
                  },
                ),
              ),
            ),
            TextFormField(
              decoration: InputDecoration(labelText: 'Comment'),
              maxLines: 3,
              validator: (val) =>
                  val == null || val.trim().isEmpty ? 'Enter a comment' : null,
              onChanged: (val) => _comment = val,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              final review = CompanyReview(
                id: FirebaseFirestore.instance.collection('tmp').doc().id,
                companyId: widget.companyId,
                studentId: widget.studentId,
                studentName: widget.studentName,
                comment: _comment,
                rating: _rating,
                createdAt: DateTime.now(),
              );
              await Company_Cloud().addCompanyReview(review);
              widget.onReviewAdded();
              Navigator.pop(context);
            }
          },
          child: Text('Submit'),
        ),
      ],
    );
  }
}
