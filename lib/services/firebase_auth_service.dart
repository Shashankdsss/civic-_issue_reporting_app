import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class CustomUser {
  final String uid;
  CustomUser(this.uid);
}

class FirebaseAuthService {
  static const String baseUrl = 'http://10.0.2.2:5000/api';
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
      final body = jsonDecode(response.body);
      throw Exception(body['error'] ?? 'Registration failed.');
    }
  }

  static Future<CustomUser?> loginUser(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final token = data['token'];
      final userId = data['userId'];

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jwt_token', token);
      await prefs.setString('user_id', userId);
      await prefs.setBool('is_logged_in', true);

      _currentUser = CustomUser(userId);
      return _currentUser;
    } else {
       final body = jsonDecode(response.body);
       throw Exception(body['error'] ?? 'Login failed.');
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
     // NOTE: Stub for backward compatibility
  }
}
