import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class FirestoreService {
  static const String baseUrl = 'http://192.168.32.117:5000/api';

  // ── CIVIC ISSUE REPORTS ────────────────────────────────────────────────────

  static Future<void> insertReport(Map<String, dynamic> data) async {
    await insertReportAndGetId(data);
  }

  static Future<String> insertReportAndGetId(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    final response = await http.post(
      Uri.parse('$baseUrl/reports'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      final body = jsonDecode(response.body);
      // Mongo usually returns _id instead of id
      return body['_id'] ?? (body['id'] ?? '');
    } else {
      throw Exception(
        'Failed to insert report: ${response.statusCode} - ${response.body}',
      );
    }
  }

  static Future<List<Map<String, dynamic>>> getReports() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/reports'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((e) {
          final map = Map<String, dynamic>.from(e);
          map['id'] = map['_id'] ?? (map['id'] ?? '');
          final created = (map['createdAt'] ?? map['timestamp'] ?? '').toString();
          map['timestamp'] = created.length >= 16 ? created : DateTime.now().toIso8601String();
          return map;
        }).toList();
      }
    } catch (e) {
      print('Network error fetching reports: \$e');
    }
    return [];
  }

  static Stream<List<Map<String, dynamic>>>? _cachedReportsStream;

  static Stream<List<Map<String, dynamic>>> getReportsStream() {
    _cachedReportsStream ??= _createReportsStream().asBroadcastStream();
    return _cachedReportsStream!;
  }

  static Stream<List<Map<String, dynamic>>> _createReportsStream() async* {
    // Basic polling mechanism to simulate Stream snapshot
    while (true) {
      yield await getReports();
      await Future.delayed(const Duration(seconds: 5));
    }
  }

  static Future<void> deleteReport(String id) async {
    await http.delete(Uri.parse('$baseUrl/reports/$id'));
  }

  static Future<void> updateReportStatus(String id, String newStatus) async {
    await http.patch(
      Uri.parse('$baseUrl/reports/$id/status'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'status': newStatus}),
    );
  }

  static Future<void> updateReportStatusWithTimestamp(
    String id,
    String newStatus,
  ) async {
    await updateReportStatus(id, newStatus);
  }

  static Future<void> toggleUpvote(
    String id,
    bool currentStatus,
    int currentUpvotes,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    await http.post(
      Uri.parse('$baseUrl/reports/$id/upvote'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'upvotes': currentUpvotes}),
    );
  }

  // STUBS FOR NON-MIGRATED FEATURES FOR BACKWARDS COMPATIBILITY
  // Depending on how much of the app uses these, we might need actual Node routes or just local mock DB

  static Future<List<Map<String, dynamic>>> getReportsByCategory(
    String category,
  ) async {
    final all = await getReports();
    return all.where((element) => element['category'] == category).toList();
  }

  static Future<void> updateReportFeedback(
    String id,
    int rating,
    String message,
  ) async {}

  static Map<String, dynamic> computeSlaFields(
    String priority, [
    DateTime? now,
  ]) {
    final base = now ?? DateTime.now();
    const int days = 10;
    return {
      'submittedAt': base.toIso8601String(),
      'slaDays': days,
      'expectedResolutionDate': base
          .add(const Duration(days: days))
          .toIso8601String(),
      'expectedStages': {
        'Verified': base.add(const Duration(days: 1)).toIso8601String(),
        'In Progress': base.add(const Duration(days: 5)).toIso8601String(),
        'Resolved': base.add(const Duration(days: days)).toIso8601String(),
      },
    };
  }

  static Future<void> addComment(
    String reportId,
    String userId,
    String userName,
    String message,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    await http.post(
      Uri.parse('$baseUrl/community/comments'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'reportId': reportId,
        'userName': userName,
        'message': message,
      }),
    );
  }

  static Stream<List<Map<String, dynamic>>> getCommentsStream(String reportId) async* {
    while (true) {
      try {
        final response = await http.get(Uri.parse('$baseUrl/community/comments/$reportId'));
        if (response.statusCode == 200) {
          final List<dynamic> data = jsonDecode(response.body);
          yield data.cast<Map<String, dynamic>>();
        } else {
          yield [];
        }
      } catch (e) {
        yield [];
      }
      await Future.delayed(const Duration(seconds: 3));
    }
  }

  static Future<void> followUser(String myUid, String targetUid) async {}
  static Future<void> unfollowUser(String myUid, String targetUid) async {}
  static Future<List<String>> getFollowingUids(String myUid) async {
    return [];
  }

  static Future<bool> isFollowing(String myUid, String targetUid) async {
    return false;
  }

  static Future<List<Map<String, dynamic>>> getAllUsers() async {
    return [];
  }

  static Future<void> insertNotification(String title, String message) async {}
  static Future<List<Map<String, dynamic>>> getNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/notifications'),
        headers: {if (token != null) 'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((e) {
          final map = Map<String, dynamic>.from(e);
          map['id'] = map['_id'] ?? map['id'];
          return map;
        }).toList();
      }
    } catch (e) {
      print('Error fetching notifications: $e');
    }
    return [];
  }

  static Future<void> markNotificationRead(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    try {
      await http.patch(
        Uri.parse('$baseUrl/notifications/$id/read'),
        headers: {if (token != null) 'Authorization': 'Bearer $token'},
      );
    } catch (e) {
      print('Error marking notification read: $e');
    }
  }
  static Future<void> deleteNotification(String id) async {}
  static Future<int> getUnreadNotificationCount() async {
    final notifs = await getNotifications();
    return notifs.where((n) => n['isRead'] == false).length;
  }

  static Future<void> clearAllNotifications() async {}

  static Future<void> insertAccident(Map<String, dynamic> data) async {}
  static Future<List<Map<String, dynamic>>> getAccidents() async {
    return [];
  }

  static Future<void> deleteAccident(String id) async {}
  static Future<void> clearAllAccidents() async {}
  static Future<void> clearAllReports() async {}
}
