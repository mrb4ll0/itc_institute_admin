import 'package:flutter/foundation.dart';

import '../../../model/tweetModel.dart';
import '../../admin_task.dart';
import '../tweet/tweet_cloud.dart';

class FeedProvider with ChangeNotifier {
  final TweetService _tweetService = TweetService();
  final AdminCloud _adminCloud = AdminCloud();

  bool _isLoading = true;
  List<TweetModel> _tweets = [];
  final Map<String, dynamic> _users =
      {}; // Cache for user data (Student or Company)

  bool get isLoading => _isLoading;
  List<TweetModel> get tweets => _tweets;

  FeedProvider() {
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Fetch all users (students and companies) and cache them.
      // This is the most important optimization.
      final students = await _adminCloud.getAllStudents();
      for (var student in students) {
        _users[student.uid] = student;
      }
      final companies = await _adminCloud.getAllCompanies();
      for (var company in companies) {
        _users[company.id] = company;
      }

      // Fetch all tweets
      _tweetService.getAllTweets().listen((tweets) {
        _tweets = tweets;
        _isLoading = false;
        notifyListeners();
      });
    } catch (e) {
      debugPrint("Error fetching initial feed data: $e");
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Gets a user (Student or Company) from the cache by their ID.
  /// This is much faster than fetching from Firestore every time.
  dynamic getUserById(String userId) {
    return _users[userId];
  }

  Future<void> refreshFeed() async {
    // This can be called to refresh the feed data, for example, using a
    // pull-to-refresh indicator.
    await _fetchInitialData();
  }
}
