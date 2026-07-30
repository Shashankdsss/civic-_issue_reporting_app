import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AdminService {
  static const String baseUrl = 'https://civicissue-api.onrender.com/api';

  static Future<List<dynamic>> fetchAllReports() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    final response = await http.get(
      Uri.parse('$baseUrl/admin/reports'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load reports');
    }
  }

  static Future<void> updateReport(
      String id, 
      String? status, 
      String? department, 
      String? dateString, 
      String? remarks) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    final Map<String, dynamic> body = {};
    if (status != null) body['status'] = status;
    if (department != null) body['assignedDepartment'] = department;
    if (dateString != null) body['targetCompletionDate'] = dateString;
    if (remarks != null) body['adminRemarks'] = remarks;

    final response = await http.put(
      Uri.parse('$baseUrl/admin/reports/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update report');
    }
  }
}
