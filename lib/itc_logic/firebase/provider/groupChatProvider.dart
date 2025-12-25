import 'package:flutter/material.dart';
import 'dart:io';

import '../../../model/student.dart';


class GroupChatProvider extends ChangeNotifier {
  bool isLoading = false;
  String? error;
  bool isSending = false;
  Map<String, dynamic>? group;
  List<Student> members = [];
  List<String> adminIds = [];
  File? avatarFile;
  Map<String, dynamic>? replyToMessage;

  void setLoading(bool value) {
    isLoading = value;
    notifyListeners();
  }

  void setError(String? value) {
    error = value;
    notifyListeners();
  }

  void setSending(bool value) {
    isSending = value;
    notifyListeners();
  }

  void setGroup(Map<String, dynamic> value) {
    group = value;
    notifyListeners();
  }

  void setMembers(List<Student> value) {
    members = value;
    notifyListeners();
  }

  void setAdminIds(List<String> value) {
    adminIds = value;
    notifyListeners();
  }

  void setAvatarFile(File? value) {
    avatarFile = value;
    notifyListeners();
  }

  void setReplyToMessage(Map<String, dynamic>? msg) {
    replyToMessage = msg;
    notifyListeners();
  }
}