import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:itc_institute_admin/view/home/message_view.dart';
import 'package:itc_institute_admin/view/home/notification_page.dart';
import 'package:itc_institute_admin/view/home/pending_approval.dart';
import 'package:itc_institute_admin/view/home/placements_approved.dart';
import 'package:itc_institute_admin/view/home/student_page.dart';
import 'package:itc_institute_admin/view/home/supervision_home.dart';

import 'company_page.dart';

class InstitutionDashboardPage extends StatefulWidget {
  const InstitutionDashboardPage({super.key});

  @override
  State<InstitutionDashboardPage> createState() => _InstitutionDashboardPageState();
}

class _InstitutionDashboardPageState extends State<InstitutionDashboardPage> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const _DashboardBody(),
    const StudentsPage(),
    const CompaniesPage(),
    const SupervisionPage(),
     MessagesPage(),
  ];
  final List<String> _titles = [
    'Dashboard',
    'Students',
    'Companies',
    'Supervision',
    'Messages',
  ];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const SizedBox(width: 48), // left spacer
                Expanded(
                  child: Text(
                    _titles[_currentIndex],
                    textAlign: TextAlign.center,
                    style: GoogleFonts.splineSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: Colors.white,
                    ),
                  ),
                ),
                SizedBox(
                  width: 48,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context)
                        {
                          return NotificationPage();
                        }));
                      },
                      icon: const Icon(Icons.notifications_none, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: _BottomNav(
        currentIndex: _currentIndex,
        onTap: (i) {
          setState(() => _currentIndex = i);
          },
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        // Stat cards
        Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = constraints.maxWidth < 320
                  ? constraints.maxWidth // small phones
                  : (constraints.maxWidth / 2) - 20; // 2 per row
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _StatCard(title: 'Students on IT', value: '120', width: cardWidth,callback: (){
                    Navigator.push(context, MaterialPageRoute(builder: (context)
                    {
                      return StudentsPage();
                    }));
                  }),
                  _StatCard(title: 'Approved Placements', value: '85', width: cardWidth,
                  callback: ()
                    {
                      Navigator.push(context, MaterialPageRoute(builder: (context)
                      {
                        return ApprovedPlacementsPage();
                      }));
                    },),
                  _StatCard(title: 'Pending Approvals', value: '35', width: cardWidth,
                  callback: ()
                    {
                      Navigator.push(context, MaterialPageRoute(builder: (context)
                      {
                        return PendingPlacementsPage();
                      }));
                    },),
                ],
              );
            },
          ),
        ),

        // Notifications header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Text(
            'Notifications',
            style: GoogleFonts.splineSans(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
        ),

        // Notification items
         _NotificationItem(
          label: 'Deadline',
          title: 'Report Submission',
          message: 'Submit your final report by next Friday.',
          imageUrl: 'https://picsum.photos/300/200?random=1',
          notificationCallback: ()
          {
            NotificationDetailsDialog.show(context,
                title: 'Report Submission',
                message: 'Submit your final report by next Friday.',
                time: "2m ago");
          },
        ),
         _NotificationItem(
          label: 'Pending',
          title: 'Supervisor Approval',
          message: 'Your supervisor needs to approve your placement.',
          imageUrl: 'https://picsum.photos/300/200?random=2',
          notificationCallback: ()
          {
            NotificationDetailsDialog.show(
                context,
                title: 'Supervisor Approval',
                message: 'Your supervisor needs to approve your placement.',
                time: "4m ago");
          },
        ),
         _NotificationItem(
          label: 'Task',
          title: 'Supervisor Meeting',
          message: 'Schedule a meeting with your supervisor this week.',
          imageUrl: 'https://picsum.photos/300/200?random=3',
           notificationCallback: ()
           {
             NotificationDetailsDialog.show(
                 context,
                 title: 'Supervisor Meeting',
                 message: 'Schedule a meeting with your supervisor this week.',
                 time: "3min ago");
           },
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.title, required this.value, required this.width, this.callback});

  final String title;
  final String value;
  final double width;
  final VoidCallback? callback;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: GestureDetector(
        onTap: callback,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF264532),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.splineSans(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: GoogleFonts.splineSans(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationItem extends StatelessWidget {
  const _NotificationItem({
    required this.label,
    required this.title,
    required this.message,
    required this.imageUrl,
    required this.notificationCallback
  });

  final VoidCallback notificationCallback;
  final String label;
  final String title;
  final String message;
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    const muted = Color(0xFF96C5A9);
    return GestureDetector(
      onTap: notificationCallback,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Texts
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: GoogleFonts.splineSans(color: muted, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: GoogleFonts.splineSans(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: GoogleFonts.splineSans(color: muted, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Image
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 90,
                height: 60,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const ColoredBox(color: Color(0xFF264532));
                  },
                  errorBuilder: (context, error, stack) =>
                  const ColoredBox(color: Color(0xFF264532)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    const unselected = Color(0xFF96C5A9);
    const bg = Color(0xFF1B3124);

    return Container(
      decoration: const BoxDecoration(
        color: bg,
        border: Border(
          top: BorderSide(color: Color(0xFF264532), width: 1),
        ),
      ),
      child: NavigationBar(
        height: 64,
        backgroundColor: bg,
        indicatorColor: Colors.transparent,
        selectedIndex: currentIndex,
        onDestinationSelected: onTap,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations:  [
          NavigationDestination(
            icon: Icon(Icons.home_rounded, color: currentIndex ==0? Colors.white: unselected),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.group_outlined, color: currentIndex ==1? Colors.white: unselected),
            label: 'Students',
          ),
          NavigationDestination(
            icon: Icon(Icons.apartment_outlined, color: currentIndex ==2? Colors.white: unselected),
            label: 'Companies',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_circle_outlined, color: currentIndex ==3? Colors.white: unselected),
            label: 'Supervision',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined, color: currentIndex ==4? Colors.white: unselected),
            label: 'More',
          ),
        ],
      ),
    );
  }
}

navigate(BuildContext context, Widget page)
{
  Navigator.push(context,
  MaterialPageRoute(builder: (context)
  {
    return page;
  }));
}


