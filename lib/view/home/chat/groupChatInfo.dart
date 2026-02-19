import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:itc_institute_admin/itc_logic/admin_task.dart';
import 'package:itc_institute_admin/itc_logic/firebase/company_cloud.dart';
import 'package:itc_institute_admin/model/userProfile.dart';
import 'package:provider/provider.dart';

import '../../../../firebase_cloud_storage/firebase_cloud.dart';
import '../../../../itc_logic/firebase/general_cloud.dart';
import '../../../../itc_logic/firebase/message/message_service.dart';
import '../../../../model/student.dart';
import '../../../itc_logic/firebase/provider/groupChatProvider.dart';
import '../../../model/company.dart';


class GroupInfoPage extends StatefulWidget {
  final UserConverter currentUser;
  const GroupInfoPage({required this.currentUser});
  @override
  State<GroupInfoPage> createState() => _GroupInfoPageState();
}

class _GroupInfoPageState extends State<GroupInfoPage> {
  final ChatService _chatService = ChatService(FirebaseAuth.instance.currentUser!.uid);
  final ITCFirebaseLogic _itcFirebaseLogic = ITCFirebaseLogic(FirebaseAuth.instance.currentUser!.uid);
  final AdminCloud adminCloud = AdminCloud(FirebaseAuth.instance.currentUser!.uid);
  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? group;
  List<Student> members = [];
  List<String> adminIds = [];
  File? _avatarFile;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    group = Provider.of<GroupChatProvider>(context).group;
    adminIds = List<String>.from(group?['admins'] ?? []);
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final memberIds = List<String>.from(group?['members'] ?? []);
      final futures = memberIds.map((id) => _itcFirebaseLogic.getStudent(id));
      final loaded = await Future.wait(futures);
      setState(() {
        members = loaded.whereType<Student>().toList();
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load members: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  bool get isAdmin => adminIds.contains(widget.currentUser.uid);
  bool get isCreator => group?['createdBy'] == widget.currentUser.uid;

  Future<void> _addMember() async {
    // Show dialog to select students to add
    Company? company = widget.currentUser.getAs<Company>();
    if(company == null )
      {
        Fluttertoast.showToast(msg: "company is null");
        return;
      }

    final allStudents = await adminCloud.getPotentialStudents(company: company);
    final currentIds = List<String>.from(group?['members'] ?? []);
    final candidates =
    allStudents.where((s) => !currentIds.contains(s.uid)).toList();
    Student? selected;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Member'),
        content: DropdownButtonFormField<Student>(
          items: candidates
              .map((s) => DropdownMenuItem(value: s, child: Text(s.fullName)))
              .toList(),
          onChanged: (s) => selected = s,
          decoration: InputDecoration(labelText: 'Select student'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (selected != null) {
                Navigator.pop(context);
                setState(() {
                  _isLoading = true;
                });
                try {
                  await _chatService.addGroupMember(
                      group?['id'], selected!.uid);
                  await _chatService.sendGroupMessage(
                    groupId: group?['id'],
                    senderId: widget.currentUser.uid,
                    content:
                    '${widget.currentUser.displayName} added ${selected!.fullName}',
                    type: 'system',
                  );
                  setState(() {
                    group?['members'].add(selected!.uid);
                  });
                  await _loadMembers();
                } catch (e) {
                  setState(() {
                    _error = 'Failed to add member: $e';
                  });
                } finally {
                  setState(() {
                    _isLoading = false;
                  });
                }
              }
            },
            child: Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _removeMember(Student member) async {
    if (member.uid == widget.currentUser.uid && !isCreator) {
      // Leave group
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Leave Group'),
          content: Text('Are you sure you want to leave this group?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel')),
            ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Leave')),
          ],
        ),
      );
      if (confirm == true) {
        setState(() {
          _isLoading = true;
        });
        try {
          await _chatService.removeGroupMember(group?['id'], member.uid);
          await _chatService.sendGroupMessage(
            groupId: group?['id'],
            senderId: widget.currentUser.uid,
            content: '${widget.currentUser.displayName} left the group',
            type: 'system',
          );
          Navigator.pop(context, null); // Close info page
        } catch (e) {
          setState(() {
            _error = 'Failed to leave group: $e';
          });
        } finally {
          setState(() {
            _isLoading = false;
          });
        }
      }
      return;
    }
    // Remove member (admin only)
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove Member'),
        content: Text('Remove ${member.fullName} from the group?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Remove')),
        ],
      ),
    );
    if (confirm == true) {
      setState(() {
        _isLoading = true;
      });
      try {
        await _chatService.removeGroupMember(group?['id'], member.uid);
        await _chatService.sendGroupMessage(
          groupId: group?['id'],
          senderId: widget.currentUser.uid,
          content: '${widget.currentUser.displayName} removed ${member.fullName}',
          type: 'system',
        );
        setState(() {
          group?['members'].remove(member.uid);
        });
        await _loadMembers();
      } catch (e) {
        setState(() {
          _error = 'Failed to remove member: $e';
        });
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _promoteDemoteAdmin(Student member, bool promote) async {
    setState(() {
      _isLoading = true;
    });
    try {
      if (promote) {
        await _chatService.promoteToAdmin(group?['id'], member.uid);
        await _chatService.sendGroupMessage(
          groupId: group?['id'],
          senderId: widget.currentUser.uid,
          content: '${member.fullName} is now an admin',
          type: 'system',
        );
        adminIds.add(member.uid);
      } else {
        await _chatService.demoteFromAdmin(group?['id'], member.uid);
        await _chatService.sendGroupMessage(
          groupId: group?['id'],
          senderId: widget.currentUser.uid,
          content: '${member.fullName} is no longer an admin',
          type: 'system',
        );
        adminIds.remove(member.uid);
      }
      setState(() {});
    } catch (e) {
      setState(() {
        _error = 'Failed to update admin: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _editGroupInfo() async {
    final nameCtrl = TextEditingController(text: group?['name']);
    final descCtrl = TextEditingController(text: group?['description']);
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Group Info'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameCtrl,
                decoration: InputDecoration(labelText: 'Group Name')),
            TextField(
                controller: descCtrl,
                decoration: InputDecoration(labelText: 'Description')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, {
              'name': nameCtrl.text.trim(),
              'description': descCtrl.text.trim(),
            }),
            child: Text('Save'),
          ),
        ],
      ),
    );
    if (result != null) {
      setState(() {
        _isLoading = true;
      });
      try {
        await _chatService.groupsCollection.doc(group?['id']).update({
          'name': result['name'],
          'description': result['description'],
        });
        setState(() {
          group?['name'] = result['name'];
          group?['description'] = result['description'];
        });
        Navigator.pop(context, group); // Return updated group
      } catch (e) {
        setState(() {
          _error = 'Failed to update group: $e';
        });
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteGroup() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Group'),
        content: Text(
            'Are you sure you want to delete this group? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Delete')),
        ],
      ),
    );
    if (confirm == true) {
      setState(() {
        _isLoading = true;
      });
      try {
        await _chatService.groupsCollection.doc(group?['id']).delete();
        Navigator.pop(context, null); // Close info page
      } catch (e) {
        setState(() {
          _error = 'Failed to delete group: $e';
        });
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final picked =
    await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      setState(() {
        _isLoading = true;
      });
      try {
        final file = File(picked.path);
        final previousUrl = group?['avatarUrl'] as String?;
        final url = await FirebaseUploader()
            .uploadFile(file, group?['id'], 'group_avatar');
        await _chatService.groupsCollection
            .doc(group?['id'])
            .update({'avatarUrl': url});
        setState(() {
          group?['avatarUrl'] = url;
        });
        // Delete the previous avatar if it exists and is not empty
        if (previousUrl != null && previousUrl.isNotEmpty) {
          await FirebaseUploader().deleteFile(previousUrl);
        }
      } catch (e) {
        setState(() {
          _error = 'Failed to upload avatar: $e';
        });
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? Colors.black : null,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme:
        IconThemeData(color: isDark ? Colors.white : Color(0xFF23243a)),
        title: Text(
          'Group Info',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.blueGrey[900],
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          if (isAdmin)
            IconButton(
              icon: Icon(Icons.edit,
                  color: isDark ? Colors.white : Colors.blueGrey[900]),
              onPressed: _editGroupInfo,
            ),
          if (isCreator)
            IconButton(
              icon: Icon(Icons.delete, color: Colors.red),
              onPressed: _deleteGroup,
            ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: isDark
            ? null
            : BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFf8fafc), Color(0xFFe0e7ff)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(
              top: kToolbarHeight + 32, left: 20, right: 20, bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Modern Group Header
              Row(
                children: [
                  GestureDetector(
                    onTap: isAdmin ? _pickAndUploadAvatar : null,
                    child: Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withOpacity(0.04)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(40),
                            boxShadow: [
                              BoxShadow(
                                color: isDark
                                    ? Colors.black.withOpacity(0.13)
                                    : Color(0xFF667eea).withOpacity(0.13),
                                blurRadius: 12,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(4),
                          child: CircleAvatar(
                            radius: 36,
                            backgroundColor:
                            isDark ? Colors.black : Colors.white,
                            backgroundImage: (group?['avatarUrl'] != null &&
                                (group?['avatarUrl'] as String).isNotEmpty)
                                ? NetworkImage(group?['avatarUrl'] as String)
                                : null,
                            child: (group?['avatarUrl'] == null ||
                                (group?['avatarUrl'] as String).isEmpty)
                                ? Icon(Icons.group,
                                size: 36,
                                color: isDark
                                    ? Colors.white54
                                    : Color(0xFF667eea))
                                : null,
                          ),
                        ),
                        if (isAdmin)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 6,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(3),
                              child: Icon(Icons.camera_alt,
                                  size: 16,
                                  color: isDark
                                      ? Colors.black
                                      : Color(0xFF667eea)),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group?['name'] ?? '',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                            color: isDark ? Colors.white : Colors.blueGrey[900],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          group?['description'] ?? '',
                          style: TextStyle(
                            color:
                            isDark ? Colors.white70 : Colors.blueGrey[700],
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.people_alt_rounded,
                          color: isDark ? Colors.white54 : Color(0xFF667eea)),
                      const SizedBox(width: 8),
                      Text('Members',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                              color: isDark
                                  ? Colors.white
                                  : Colors.blueGrey[900])),
                    ],
                  ),
                  if (isAdmin)
                    ElevatedButton.icon(
                      icon: Icon(Icons.person_add, color: Colors.white),
                      label: Text('Add',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark
                            ? Colors.white.withOpacity(0.06)
                            : const Color(0xFF667eea),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18)),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 10),
                      ),
                      onPressed: _addMember,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (_isLoading)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    children: [
                      SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator()),
                      const SizedBox(width: 12),
                      Text('Updating group...', style: TextStyle(fontSize: 16)),
                    ],
                  ),
                ),
              ...members.map((m) => Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.04)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withOpacity(0.08)
                          : Color(0xFFf093fb).withOpacity(0.08),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                  border: Border.all(
                      color: isDark
                          ? Colors.white12
                          : Color(0xFFf093fb).withOpacity(0.18)),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage: m.imageUrl.isNotEmpty
                        ? NetworkImage(m.imageUrl)
                        : null,
                    child: m.imageUrl.isEmpty ? Icon(Icons.person) : null,
                  ),
                  title: Text(
                    m.fullName,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.blueGrey[900],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: adminIds.contains(m.uid)
                      ? Text(
                      isCreator && m.uid == group?['createdBy']
                          ? 'Creator'
                          : 'Admin',
                      style: TextStyle(
                          color: isDark
                              ? Colors.tealAccent[200]
                              : Color(0xFF667eea),
                          fontWeight: FontWeight.w600))
                      : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isAdmin && m.uid != widget.currentUser.uid)
                        Tooltip(
                          message: 'Remove from group',
                          child: IconButton(
                            icon: Icon(Icons.remove_circle,
                                color: Colors.redAccent),
                            onPressed: () => _removeMember(m),
                          ),
                        ),
                      if (isAdmin &&
                          m.uid != widget.currentUser.uid &&
                          !adminIds.contains(m.uid))
                        Tooltip(
                          message: 'Promote to Admin',
                          child: IconButton(
                            icon: Icon(Icons.upgrade,
                                color: isDark
                                    ? Colors.tealAccent[200]
                                    : Color(0xFF44a08d)),
                            onPressed: () => _promoteDemoteAdmin(m, true),
                          ),
                        ),
                      if (isAdmin &&
                          m.uid != widget.currentUser.uid &&
                          adminIds.contains(m.uid) &&
                          !(isCreator && m.uid == group?['createdBy']))
                        Tooltip(
                          message: 'Demote from Admin',
                          child: IconButton(
                            icon: Icon(Icons.arrow_downward,
                                color: Colors.orange),
                            onPressed: () => _promoteDemoteAdmin(m, false),
                          ),
                        ),
                      if (m.uid == widget.currentUser.uid && !isCreator)
                        Tooltip(
                          message: 'Leave Group',
                          child: IconButton(
                            icon:
                            Icon(Icons.logout, color: Colors.redAccent),
                            onPressed: () => _removeMember(m),
                          ),
                        ),
                    ],
                  ),
                ),
              )),
              if (!isCreator)
                Padding(
                  padding: const EdgeInsets.only(top: 24.0),
                  child: Center(
                    child: ElevatedButton.icon(
                      icon: Icon(Icons.logout, color: Colors.white),
                      label: Text('Leave Group',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18)),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                      ),
                      onPressed: () => _removeMember(members
                          .firstWhere((m) => m.uid == widget.currentUser.uid)),
                    ),
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(_error!, style: TextStyle(color: Colors.red)),
                ),
            ],
          ),
        ),
      ),
    );
  }


}
