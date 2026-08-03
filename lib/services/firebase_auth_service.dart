import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class CustomUser {
  final String uid;
  final String role;
  CustomUser(this.uid, {this.role = 'citizen'});
}

class FirebaseAuthService {
  static const String baseUrl = 'https://civicissue-api.onrender.com/api';
  static CustomUser? _currentUser;
  
  static CustomUser? get currentUser => _currentUser;

  static Future<void> registerUser({
    required String firstName,
    required String lastName,
    required String phone,
    required String aadhaar,
    required String email,
    required String gender,
    required String password,
    String? otherDetails,
    String? region,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'firstName': firstName,
        'lastName': lastName,
        'phone': phone,
        'aadhaar': aadhaar,
        'email': email,
        'gender': gender,
        'password': password,
        'otherDetails': otherDetails,
        'region': region,
      }),
    );
    if (response.statusCode != 201) {
      try {
        final body = jsonDecode(response.body);
        throw Exception(body['error'] ?? 'Registration failed.');
      } catch (_) {
        throw Exception('Registration failed: ${response.statusCode} - ${response.body}');
      }
    }
  }

  static Future<CustomUser?> loginUser(String email, String password, String requestedRole) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'role': requestedRole,
      }),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final token = data['token'];
      final userId = data['userId'];
      final role = data['role'] ?? 'citizen';

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jwt_token', token);
      await prefs.setString('user_id', userId);
      await prefs.setString('user_role', role);
      await prefs.setBool('is_logged_in', true);

      _currentUser = CustomUser(userId, role: role);
      return _currentUser;
    } else {
       try {
         final body = jsonDecode(response.body);
         throw Exception(body['error'] ?? 'Login failed.');
       } catch (_) {
         throw Exception('Login failed: ${response.statusCode} - ${response.body}');
       }
    }
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('user_id');
    await prefs.setBool('is_logged_in', false);
    _currentUser = null;
  }

  static Future<Map<String, dynamic>?> getCurrentUserDetails() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null) return null;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/auth/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        data['uid'] = data['_id'];
        data['name'] = '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim();
        
        if (_currentUser == null) {
          final uid = prefs.getString('user_id');
          if (uid != null) _currentUser = CustomUser(uid);
        }
        return data;
      }
    } catch(e) {
      return null;
    }
    return null;
  }

  static Future<void> updateUserDetails(String uid, {required String name, required String phone}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null) return;
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/auth/profile'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({'name': name, 'phone': phone}),
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to update profile');
      }
    } catch (_) {
      rethrow;
    }
  }

  static Future<void> updateBankDetails(String account, String ifsc) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) return;
    try {
      await http.put(
        Uri.parse('https://civicissue-api.onrender.com/api/auth/bank'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({'bankAccount': account, 'ifscCode': ifsc}),
      );
    } catch (_) {}
  }
}
