import 'package:flutter/material.dart';



class SupervisionPage extends StatelessWidget {
  const SupervisionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Tabs
          Container(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TabItem(label: 'Assign', selected: true),
                TabItem(label: 'Check-in', selected: false),
                TabItem(label: 'Reports', selected: false),
                TabItem(label: 'Logbooks', selected: false),
              ],
            ),
          ),

          // Section title
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Assign Supervisors',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // List of supervisors
          Expanded(
            child: ListView(
              children: const [
                SupervisorCard(
                  name: 'Ethan Harper',
                  studentId: '20210001',
                  imageUrl:
                  'https://lh3.googleusercontent.com/aida-public/AB6AXuDIdbEwtGhClVqbf2n3ZcOKhYqURYSRD3zphVd2KgsX8lLiioMBz-b_W_W5lZgmQ002mJ17wytnFiHtpZUjTKMReHqcTlR12xNWQaRYZ3WmpiKMXP1FxjrQHXw2QzTX625ZA9b21Cz0TJZPwAEBKyUwJv7tsOUv2qza9b3qolr1PqndGZ-99TEdQ8OSSfC0veHH6QFX5rL08FEPNJEC57ipj5as00TqwNCtRbDxYuPOORmxHNeM1CEMXoC5D_4xsnwxCMXSp9Zem6k',
                ),
                SupervisorCard(
                  name: 'Olivia Bennett',
                  studentId: '20210002',
                  imageUrl:
                  'https://lh3.googleusercontent.com/aida-public/AB6AXuCQ7oaYWHz66yUwQdqnnt8c9BuPhitVq-gpcwatvaPyoT7FkjVrcgFVmN-wfCK4sJ3MHDTo7haJYz2poz2azj3m7WlLZnW2hTQvtccPjxTM2kh82YpHT1WLr8rIlTgZRtJPjbeGTLYLYi2opGXdsiw88etAVng89ad3xkWEjgL14kXzGjYDK_oL9qbTXAf2B6VdxNJypZVqfsPhbnwHuAnd73WWJzDXYbaw0M2LNNwHrsM0gcXQZyDqfwfllknaaDfAhrmJrRgYJMQ',
                ),
                SupervisorCard(
                  name: 'Noah Carter',
                  studentId: '20210003',
                  imageUrl:
                  'https://lh3.googleusercontent.com/aida-public/AB6AXuAxmNF3nYKbuLQ4i3C6stTXtXOsjey_lCrmKhW0Krp7QP8YhW_paM5P8I764zb2JYWhe6qz4-aZsWPQARTJ32XBUE7OP5Tno3DsM1UAkknSHhg-v53AvnqSw2gMcURnnkgA4AXC1l8yZnIZZZBaI8pPp54rLAMpsYN5JMcAVsaZqSH0PxY9S98TC0wfhjckf-k1grvqC3Nl01begF3frES7I78FG9BNDsuXkwJxK6F290XAUbWWYTIGLDMREstAUi6BNq6oD-5r3D4',
                ),
                SupervisorCard(
                  name: 'Ava Mitchell',
                  studentId: '20210004',
                  imageUrl:
                  'https://lh3.googleusercontent.com/aida-public/AB6AXuASAnRW9K1cMeZ8cTZwUK9qDh1SOL7zgxd1mGag5c5NZI0eAO92ejse9f_Ly8dbORf-7YdrEy75Is4ama0fiQ0N8pHxbq0vZlW-382oPQpKGgJt_4E3aZqJzCzW5Rj13oHCcskI_rlEBRBug20WHDXQILxl3u_2ZB-5soYiH1f5chUfxB5kxM87CsnKx6l-AQKLChGNjkTNtAEtNwpibazouoLuc0MnEHIKCsBLWR7gn6Xuy81Dy7jtXRqacNiTpQFOoLXXxsxXF7s',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TabItem extends StatelessWidget {
  final String label;
  final bool selected;

  const TabItem({super.key, required this.label, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF96C5A9),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 40,
          height: 3,
          color: selected ? const Color(0xFF38E07B) : Colors.transparent,
        ),
      ],
    );
  }
}

class SupervisorCard extends StatelessWidget {
  final String name;
  final String studentId;
  final String imageUrl;

  const SupervisorCard({
    super.key,
    required this.name,
    required this.studentId,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundImage: NetworkImage(imageUrl),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                'Student ID: $studentId',
                style: const TextStyle(
                  color: Color(0xFF96C5A9),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
