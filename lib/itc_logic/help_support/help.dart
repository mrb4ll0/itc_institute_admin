import 'package:flutter/material.dart';
import 'package:itc_institute_admin/generalmethods/GeneralMethods.dart';
import 'package:itc_institute_admin/view/home/aboutITConnect.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:itc_institute_admin/itc_logic/service/userService.dart'; // For chat functionality

class CompanyHelpPage extends StatefulWidget {
  const CompanyHelpPage({super.key});

  @override
  State<CompanyHelpPage> createState() => _CompanyHelpPageState();
}

class _CompanyHelpPageState extends State<CompanyHelpPage> {
  final UserService _userService = UserService();
  bool _isLoading = false;

  // Company-specific FAQ questions
  final List<FAQItem> _companyFaqs = [
    FAQItem(
      question: 'How do I post internship/training opportunities?',
      answer: 'Navigate to "Post Opportunities" from your dashboard, fill in the details including position, requirements, duration, and submit for approval.',
    ),
    FAQItem(
      question: 'How do I manage student applications?',
      answer: 'Go to "Applications" tab to view all received applications. You can shortlist, schedule interviews, or reject applications from there.',
    ),
    FAQItem(
      question: 'What information should I include in opportunity posts?',
      answer: 'Include position title, required skills, duration, stipend (if any), location (remote/onsite), and specific requirements. Clear descriptions attract better candidates.',
    ),
    FAQItem(
      question: 'How do I verify student credentials?',
      answer: 'Student profiles show verified academic records. You can also request additional documents through the chat feature before final selection.',
    ),
    FAQItem(
      question: 'Can I edit or remove posted opportunities?',
      answer: 'Yes, navigate to "My Posts" to edit active listings or archive completed ones. Archived posts remain in your history.',
    ),
    FAQItem(
      question: 'How are students matched with my company?',
      answer: 'Our AI matches students based on skills, academic background, and your requirements. You\'ll see suggested matches in your dashboard.',
    ),
    FAQItem(
      question: 'What support does IT Connect provide during training?',
      answer: 'We provide progress tracking, regular check-ins, and mediation if needed. You can report any issues through the support chat.',
    ),
    FAQItem(
      question: 'How do I get verified as a company?',
      answer: 'Complete your company profile with registration documents. Our team will verify within 24-48 hours. Verified companies get priority in student matching.',
    ),
  ];

  // Support contact methods
  final List<ContactMethod> _contactMethods = [
    ContactMethod(
      title: 'Email Support',
      subtitle: 'itconnect10@gmail.com',
      icon: Icons.email_outlined,
      color: Colors.blue,
      action: () async {
        final Uri emailLaunchUri = Uri(
          scheme: 'mailto',
          path: 'itconnect10@gmail.com',
          queryParameters: {'subject': 'Company Support Request'},
        );

        if (await canLaunchUrl(emailLaunchUri)) {
          await launchUrl(emailLaunchUri);
        }
      },
    ),
    ContactMethod(
      title: 'Phone Support',
      subtitle: '+234 8039382198',
      icon: Icons.phone_outlined,
      color: Colors.green,
      action: () async {
        final Uri phoneLaunchUri = Uri(
          scheme: 'tel',
          path: '+2348039382198',
        );

        if (await canLaunchUrl(phoneLaunchUri)) {
          await launchUrl(phoneLaunchUri);
        }
      },
    ),
    ContactMethod(
      title: 'Office Hours',
      subtitle: 'Mon-Fri, 9am-5pm WAT',
      icon: Icons.access_time_outlined,
      color: Colors.orange,
      action: null,
    ),
    ContactMethod(
      title: 'Emergency Contact',
      subtitle: 'Available 24/7 ',
      icon: Icons.warning_outlined,
      color: Colors.red,
      action: () async {
        final Uri phoneLaunchUri = Uri(
          scheme: 'tel',
          path: '+2348039382198',
        );

        if (await canLaunchUrl(phoneLaunchUri)) {
          await launchUrl(phoneLaunchUri);
        }
      },
    ),
  ];

  // Start chat with ITC support team
  void _startChatWithSupport() async {
    setState(() => _isLoading = true);

    try {
      // Get ITC support team user ID (you might have a dedicated support account)
      final supportUserId = 'itc_support_team'; // Replace with actual support user ID

      // Navigate to chat with support team
      // You'll need to implement this based on your chat system
      // Example: Navigator.push(context, MaterialPageRoute(builder: (_) => ChatPage(receiverId: supportUserId)));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connecting you with ITC support team...'),
        ),
      );

      // Simulate loading
      await Future.delayed(const Duration(seconds: 1));

      // TODO: Implement actual chat navigation
      // Navigator.push(context, MaterialPageRoute(
      //   builder: (_) => ChatDetailsPage(
      //     receiverId: supportUserId,
      //     receiverName: 'ITC Support Team',
      //     receiverAvatarUrl: '',
      //   ),
      // ));

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to start chat: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Show quick help options
  void _showQuickHelpOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Quick Help Options',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.chat, color: Colors.blue),
              title: const Text('Live Chat with Support'),
              subtitle: const Text('Get instant answers'),
              onTap: () {
                Navigator.pop(context);
                _startChatWithSupport();
              },
            ),
            ListTile(
              leading: const Icon(Icons.video_call, color: Colors.green),
              title: const Text('Schedule Video Call'),
              subtitle: const Text('Book a 15-min consultation'),
              onTap: () {
                Navigator.pop(context);
                _scheduleVideoCall();
              },
            ),
            ListTile(
              leading: const Icon(Icons.document_scanner, color: Colors.orange),
              title: const Text('Download Company Guide'),
              subtitle: const Text('PDF manual for companies'),
              onTap: () {
                Navigator.pop(context);
                _downloadCompanyGuide();
              },
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  void _scheduleVideoCall() {
    // Implement video call scheduling
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Schedule Video Call'),
        content: const Text('This feature will be available soon. For now, please use the chat or email support.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _downloadCompanyGuide() {
    // Implement PDF download
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Downloading company guide...'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Company Help Center'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // Implement search functionality
              showSearch(
                context: context,
                delegate: FAQSearchDelegate(faqs: _companyFaqs),
              );
            },
            tooltip: 'Search FAQs',
          ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Welcome Card
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.business,
                            color: theme.colorScheme.primary,
                            size: 32,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Company Support Center',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Get help with posting opportunities, managing applications, and using platform features.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Quick Contact Section
              Row(
                children: [
                  Text(
                    'Quick Contact',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _showQuickHelpOptions,
                    icon: const Icon(Icons.help_outline),
                    label: const Text('More Options'),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Contact Methods Grid
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                childAspectRatio: 1.2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: _contactMethods.map((method) {
                  return Card(
                    child: InkWell(
                      onTap: method.action,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              method.icon,
                              color: method.color,
                              size: 32,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              method.title,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Expanded(
                              child: Text(
                                method.subtitle,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                maxLines: 5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 32),

              // FAQ Section
              Row(
                children: [
                  Text(
                    'Frequently Asked Questions',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Chip(
                    label: Text('${_companyFaqs.length} FAQs'),
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // FAQ List
              ..._companyFaqs.map((faq) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ExpansionTile(
                    leading: const Icon(Icons.help_outline, size: 20),
                    title: Text(
                      faq.question,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          faq.answer,
                          style: const TextStyle(height: 1.5),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),

              const SizedBox(height: 32),

              // About Section
              Card(
                child: ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('About IT Connect for Companies'),
                  onTap: () {

                    GeneralMethods.navigateTo(context, AboutITConnectPage());
                  },
                ),
              ),

              const SizedBox(height: 80), // Extra space for FAB
            ],
          ),

          // Chat FAB
          Positioned(
            bottom: 20,
            right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Tooltip that appears on long press
                Tooltip(
                  message: 'Chat with ITC Support Team',
                  child: FloatingActionButton.extended(
                    onPressed: _isLoading ? null : _startChatWithSupport,
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    icon: _isLoading
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Icon(Icons.chat),
                    label: const Text('Support Chat'),
                    heroTag: 'support_chat_fab',
                  ),
                ),
                const SizedBox(height: 8),
                // Smaller FAB for quick options
                FloatingActionButton.small(
                  onPressed: _showQuickHelpOptions,
                  backgroundColor: theme.colorScheme.secondary,
                  child: const Icon(Icons.more_horiz),
                  heroTag: 'quick_help_fab',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Data Models
class FAQItem {
  final String question;
  final String answer;

  FAQItem({required this.question, required this.answer});
}

class ContactMethod {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? action;

  ContactMethod({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.action,
  });
}

// Search Delegate for FAQs
class FAQSearchDelegate extends SearchDelegate {
  final List<FAQItem> faqs;

  FAQSearchDelegate({required this.faqs});

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    final results = faqs.where((faq) {
      return faq.question.toLowerCase().contains(query.toLowerCase()) ||
          faq.answer.toLowerCase().contains(query.toLowerCase());
    }).toList();

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final faq = results[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ExpansionTile(
            title: Text(faq.question),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(faq.answer),
              ),
            ],
          ),
        );
      },
    );
  }
}