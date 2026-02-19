import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../generalmethods/GeneralMethods.dart';
import '../../../itc_logic/admin_task.dart';
import '../../../itc_logic/firebase/message/message_service.dart';
import '../../../itc_logic/firebase/tweet/tweet_cloud.dart';
import '../../../model/company.dart';
import '../../../model/student.dart';

class UserSelectionDialog extends StatefulWidget {
  final String tweetContent;
  final String tweetId;
  final ChatService chatService = ChatService(FirebaseAuth.instance.currentUser!.uid);

  UserSelectionDialog({
    Key? key,
    required this.tweetContent,
    required this.tweetId,
  }) : super(key: key);

  @override
  _UserSelectionDialogState createState() => _UserSelectionDialogState();
}

class _UserSelectionDialogState extends State<UserSelectionDialog> {
  List<dynamic> _users = [];
  List<dynamic> _filteredUsers = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    _searchController.addListener(_filterUsers);
  }

  Future<void> _fetchUsers() async {
    try {
      final adminCloud = AdminCloud(FirebaseAuth.instance.currentUser!.uid);
      final students = await adminCloud.getAllStudents();
      final companies = await adminCloud.getAllCompanies();
      setState(() {
        _users = [...students, ...companies];
        _filteredUsers = _users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      // Handle error appropriately
    }
  }

  void _filterUsers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredUsers = _users.where((user) {
        final name = user is Student
            ? user.fullName.toLowerCase()
            : (user is Company ? user.name.toLowerCase() : '');
        return name.contains(query);
      }).toList();
    });
  }

  Future<void> _shareTweet(String recipientId) async {
    try {
      await TweetService().addToShareList(widget.tweetId, recipientId);
      await widget.chatService.sendMessage(
        recipientId,
        widget.tweetContent,
        body: "${widget.tweetContent}",
        type: "message",
        title: "User_${recipientId}",
      );
      Navigator.of(context).pop(); // Close the dialog
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tweet shared successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to share tweet: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Share Tweet'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(labelText: 'Search users...'),
            ),
            const SizedBox(height: 10),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Expanded(
                    child: ListView.builder(
                      itemCount: _filteredUsers.length,
                      itemBuilder: (context, index) {
                        final user = _filteredUsers[index];
                        final name = user is Student
                            ? user.fullName
                            : user.name;
                        final imageUrl = user is Student
                            ? user.imageUrl
                            : user.logoURL;

                        return ListTile(
                          leading: GeneralMethods.generateUserAvatar(
                            username: name,
                            imageUrl: imageUrl,
                            radius: 20,
                          ),
                          title: Text(name),
                          onTap: () => _shareTweet(user.uid),
                        );
                      },
                    ),
                  ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
