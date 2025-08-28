import 'package:flutter/material.dart';

class CompaniesPage extends StatefulWidget {
  const CompaniesPage({super.key});

  @override
  State<CompaniesPage> createState() => _CompaniesPageState();
}

class _CompaniesPageState extends State<CompaniesPage> {
  int _currentIndex = 2; // Companies tab selected
  String searchQuery = '';

  final List<Map<String, String>> companies = [
    {
      'status': 'Approved',
      'name': 'Tech Innovators Inc.',
      'image':
      'https://lh3.googleusercontent.com/aida-public/AB6AXuD5pSwL8EtSc_VvUukvnyfgsuATdw4iktrWDNMJu5jhGwxYkK2WrEOTAVeorI6_cclcsTyFxPWV9AOUT3tnBaIQnO1OJfOYB5Wh25iU62UAaJj9FUYx7BdFVem_GGsIkCZfDq1fl1NIpyK6vvJBdP-N5AR8qEM5-zKpI-aQ1JTViV2Des6mTooIWUhK0BQWaIXnAXxXM3Q7s8i26az_MuH6EwdVpb_ZibuIVJUTn8Ac8Bn3FRNx_gGqRkD8Aoft_-Dn8yydF16Psuo',
    },
    {
      'status': 'Approved',
      'name': 'Global Solutions Ltd.',
      'image':
      'https://lh3.googleusercontent.com/aida-public/AB6AXuCTNCVcKNqHc3ld2T2ZRitePRnznpt5GH_0z4KY3TIMBR36x106SBEasnpM8k3gMteLReara0tBoUVDgcyd3vEZmBM49Q3UNl0JRZku_tRXfh8Ohn7_P_HBhavFUgF0MYk8PkSxuF6VK7EMwDMlbdnE-U8w2T6hAE1Xq9kbqxf2SFKKvYJL1IpKtn53dbVTklr9wlESq94nfcnU6lOGnnjJ_T9vaHpBhCLIuvRiRofe3aVYbKpoPiXl2YhvlLE_DHz2ZNyUOQWuNKU',
    },
    {
      'status': 'Pending',
      'name': 'Future Dynamics Corp.',
      'image':
      'https://lh3.googleusercontent.com/aida-public/AB6AXuBVuSOsWvisANDuK6QW_uHCTZQE3Jo939IxVptHr12aSWOMulXhjz8h2bohmaMGg4OQoAB3K23e923DXBGD-ZjgCS-E3-_TV1KckU4RUBp4JERhOYS7cLzMlfVHzZ0_q0-T0ANwNF9nPBHsuz977wZzylkSVi4jCfLqJQdo7-7s8Wf3CurauAXD9qtfrtpnk3OxTxcNsyoPBzwLZX3E219_MQ-WB3RNukY_7mcg7aehBG4zsfsCDkJgD5CshtC6yJoWDTwXK6ZaZ58',
    },
    {
      'status': 'Approved',
      'name': 'Pioneer Ventures LLC',
      'image':
      'https://lh3.googleusercontent.com/aida-public/AB6AXuAVICdy0Gg52M4bBfbfhnmL_ujIFlX3wcd5YamoH8Vvvz3T7Pd_p1FjJupL82hWzcGDNauHft_eoCATTOpjUtOtdIUnQXKlIUOvlFmw7sPUYeyWHPX9Ik9Fq76ltrA3h4Xb4yhIZg7hXEOpD429Zl86TLKoallnJEbtaJs4gI-d6qfeFBQC6Io8Tp9Hz_7UOI1IaDGL6Y507NV1gGJoe3AiwcV5xgx3Fw3M67gvuUjCwu_4qeM4kFElvQoC0r41B9LW-HSmS1NcNhg',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (value) => setState(() => searchQuery = value),
              decoration: InputDecoration(
                hintText: "Search companies",
                prefixIcon: Icon(Icons.search,),
                filled: true,
                fillColor: Colors.green.shade900,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          // Tabs
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _tabButton("All", true),
              _tabButton("Approved", false),
              _tabButton("Pending", false),
            ],
          ),
          const SizedBox(height: 8),
          // Companies list
          Expanded(
            child: ListView.builder(
              itemCount: companies.length,
              itemBuilder: (context, index) {
                final company = companies[index];
                if (searchQuery.isNotEmpty &&
                    !company['name']!
                        .toLowerCase()
                        .contains(searchQuery.toLowerCase())) {
                  return const SizedBox.shrink();
                }
                return _companyItem(company);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabButton(String label, bool selected) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: selected ? Colors.white : Colors.blueGrey,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 3,
          width: 40,
          color: selected ? Colors.blue : Colors.transparent,
        ),
      ],
    );
  }

  Widget _companyItem(Map<String, String> company) {

       bool isApproved = company['status']?.toLowerCase().contains("approved")??false;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Image
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              company['image']!,
              width: 56,
              height: 56,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          // Texts
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                company['status']!,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: isApproved? Colors.green: Colors.blue,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                company['name']!,
                style: const TextStyle(color: Colors.blueGrey),
              ),
            ],
          )
        ],
      ),
    );
  }
}
