import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/firebase_auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  final TextEditingController _passkeyController = TextEditingController();
  final FocusNode _emailFocusNode = FocusNode();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String _selectedRole = 'Citizen'; // Default role
  String? _savedEmail;
  String? _savedPass;
  bool _showSavedSuggestion = false;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
    _emailFocusNode.addListener(() {
      setState(() {
        _showSavedSuggestion = _emailFocusNode.hasFocus && _savedEmail != null && _emailController.text.isEmpty;
      });
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passController.dispose();
    _passkeyController.dispose();
    _emailFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedEmail = prefs.getString('saved_email');
      _savedPass = prefs.getString('saved_pass');
    });
  }

  Future<void> _saveCredentials(String email, String pass) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_email', email);
    await prefs.setString('saved_pass', pass);
    await prefs.setBool('is_logged_in', true);
  }

  void _handleLogin() async {
    final email = _emailController.text.trim();
    final pass = _passController.text.trim();
    final passkey = _passkeyController.text.trim();

    if (email.isEmpty || pass.isEmpty || (_selectedRole == 'Admin' && passkey.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Please fill all required fields",
                  style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          elevation: 6,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = await FirebaseAuthService.loginUser(
        email, 
        pass, 
        _selectedRole.toLowerCase(),
        passkey: _selectedRole == 'Admin' ? passkey : null,
      );
      if (!mounted) return;

      if (user != null) {
        bool shouldSave = false;

        if (_selectedRole == 'Admin') {
          shouldSave = false;
        } else if (_savedEmail == email) {
          shouldSave = true;
        } else {
          // Ask if they want to save credentials before continuing
          shouldSave = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              title: Text(
                "Save Login?",
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
              ),
              content: Text(
                "Would you like to securely save your login details on this device for next time?",
                style: GoogleFonts.poppins(color: Colors.grey[700]),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(
                    "Not Now",
                    style: GoogleFonts.poppins(color: Colors.grey[600], fontWeight: FontWeight.w600),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text("Save", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ) ?? false;
        }

        if (shouldSave) {
          await _saveCredentials(email, pass);
        } else {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('saved_email');
          await prefs.remove('saved_pass');
        }

        if (!mounted) return;
        if (user.role == 'admin') {
          Navigator.pushReplacementNamed(context, '/admin');
        } else {
          Navigator.pushReplacementNamed(context, '/');
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  e.toString().replaceAll('Exception: ', ''),
                  style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          elevation: 6,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF1E40AF); // Deep premium blue for the top bg
    const buttonBlue = Color(0xFF2563EB);  // Slightly brighter blue for buttons
    
    final bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: primaryBlue,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Top Header Section ───────────────────────────────────────────
            if (!isKeyboardOpen)
              Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                color: primaryBlue,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Squircle Logo inside container
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.location_city_rounded,
                        size: 45,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Text(
                      "CivicConnect",
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Official Public Reporting Tool",
                      style: GoogleFonts.poppins(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            if (isKeyboardOpen)
              const SizedBox(height: 20),

            // ── Bottom Sheet Section ─────────────────────────────────────────
            Expanded(
              flex: isKeyboardOpen ? 1 : 7,
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(35),
                    topRight: Radius.circular(35),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 35),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Welcome Back 👋",
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Sign in to continue to your dashboard",
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 35),

                      // ── Email Field ──
                      Text(
                        "Email",
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _emailController,
                        focusNode: _emailFocusNode,
                        keyboardType: TextInputType.emailAddress,
                        onChanged: (val) {
                          setState(() {
                            _showSavedSuggestion = val.isEmpty && _savedEmail != null;
                          });
                        },
                        decoration: InputDecoration(
                          hintText: "citizen@example.com",
                          hintStyle: TextStyle(color: Colors.grey[400]),
                          prefixIcon: Icon(Icons.email_outlined, color: Colors.grey[500]),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(vertical: 16),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: buttonBlue, width: 2),
                          ),
                        ),
                      ),
                      if (_showSavedSuggestion && _savedEmail != null && _selectedRole != 'Admin')
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _emailController.text = _savedEmail!;
                              _passController.text = _savedPass ?? '';
                              _showSavedSuggestion = false;
                              _emailFocusNode.unfocus();
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.only(top: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.account_circle, color: Colors.blue.shade700, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _savedEmail!,
                                    style: GoogleFonts.poppins(
                                      color: Colors.blue.shade900,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                Text(
                                  "Tap to autofill",
                                  style: GoogleFonts.poppins(
                                    color: Colors.blue.shade600,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),

                      // ── Password Field ──
                      Text(
                        "Password",
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _passController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          hintText: "••••••••",
                          hintStyle: TextStyle(color: Colors.grey[400]),
                          prefixIcon: Icon(Icons.lock_outline, color: Colors.grey[500]),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: Colors.grey[500],
                            ),
                            onPressed: () {
                              setState(() => _obscurePassword = !_obscurePassword);
                            },
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(vertical: 16),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: buttonBlue, width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      if (_selectedRole == 'Admin') ...[
                        Text(
                          "Admin Passkey",
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _passkeyController,
                          obscureText: true,
                          decoration: InputDecoration(
                            hintText: "Enter the admin passkey",
                            hintStyle: TextStyle(color: Colors.grey[400]),
                            prefixIcon: Icon(Icons.security, color: Colors.grey[500]),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(vertical: 16),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // ── Role Selection ──
                      Text(
                        "Login As",
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _selectedRole,
                        decoration: InputDecoration(
                          prefixIcon: Icon(Icons.admin_panel_settings_outlined, color: Colors.grey[500]),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(vertical: 16),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
                          ),
                        ),
                        items: ['Citizen', 'Admin']
                            .map((role) => DropdownMenuItem(value: role, child: Text(role)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedRole = val);
                        },
                      ),

                      // ── Forgot Password ──
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                title: Text(
                                  "Reset Password", 
                                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
                                ),
                                content: Text(
                                  "Password resets are currently handled by system administrators. Please contact support or your local municipality office to reset your password.",
                                  style: GoogleFonts.poppins(color: Colors.grey[700]),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: Text(
                                      "OK", 
                                      style: GoogleFonts.poppins(color: buttonBlue, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                          child: Text(
                            "Forgot Password?",
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),

                      // ── Sign In Button ──
                      ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: buttonBlue,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          minimumSize: const Size(double.infinity, 55),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                              )
                            : Text(
                                "Sign In",
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                      const SizedBox(height: 25),

                      // ── OR Divider ──
                      Row(
                        children: [
                          Expanded(child: Divider(color: Colors.grey.shade300)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 15),
                            child: Text(
                              "or",
                              style: GoogleFonts.poppins(color: Colors.grey.shade400, fontSize: 13),
                            ),
                          ),
                          Expanded(child: Divider(color: Colors.grey.shade300)),
                        ],
                      ),
                      const SizedBox(height: 25),

                      // ── Continue as Guest Button ──
                      OutlinedButton.icon(
                        icon: const Icon(Icons.explore_outlined, color: Color(0xFF334155)),
                        onPressed: () {
                          // Bypass auth and go to main dashboard as guest
                          Navigator.pushReplacementNamed(context, '/');
                        },
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 55),
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        label: Text(
                          "Continue as Guest",
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF334155),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 25),

                      // ── Register Link ──
                      Center(
                        child: TextButton(
                          onPressed: () => Navigator.pushNamed(context, '/register'),
                          child: RichText(
                            text: TextSpan(
                              text: "Don't have an account? ",
                              style: GoogleFonts.poppins(color: const Color(0xFF64748B), fontSize: 14),
                              children: [
                                TextSpan(
                                  text: "Sign Up",
                                  style: GoogleFonts.poppins(
                                    color: buttonBlue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
