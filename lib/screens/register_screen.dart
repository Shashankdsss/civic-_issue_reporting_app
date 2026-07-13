import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../services/firebase_auth_service.dart';
import '../services/aadhaar_validator.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _aadhaarController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  final TextEditingController _confirmPassController = TextEditingController();
  final TextEditingController _otherDetailsController = TextEditingController();
  String _selectedGender = 'Male';
  bool _isLoading = false;

  // Aadhaar validation state
  AadhaarValidationResult? _aadhaarResult;
  bool _showAadhaarFeedback = false;

  @override
  void initState() {
    super.initState();
    _aadhaarController.addListener(_onAadhaarChanged);
  }

  @override
  void dispose() {
    _aadhaarController.removeListener(_onAadhaarChanged);
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _aadhaarController.dispose();
    _passController.dispose();
    _confirmPassController.dispose();
    _otherDetailsController.dispose();
    super.dispose();
  }

  void _onAadhaarChanged() {
    final text = _aadhaarController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _showAadhaarFeedback = false;
        _aadhaarResult = null;
      });
      return;
    }
    if (text.length >= 4) {
      setState(() {
        _showAadhaarFeedback = true;
        _aadhaarResult = AadhaarValidator.validate(text);
      });
    }
  }

  void _handleRegister() async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final aadhaar = _aadhaarController.text.trim();
    final pass = _passController.text.trim();
    final confirmPass = _confirmPassController.text.trim();
    final otherDetails = _otherDetailsController.text.trim();

    // Basic field check
    if (firstName.isEmpty || lastName.isEmpty || email.isEmpty || phone.isEmpty || aadhaar.isEmpty || pass.isEmpty || confirmPass.isEmpty) {
      _showSnackbar("Please fill all required fields", isError: true);
      return;
    }

    if (pass != confirmPass) {
      _showSnackbar("Passwords do not match", isError: true);
      return;
    }

    // Phone number check
    if (!RegExp(r'^\d{10}$').hasMatch(phone)) {
      _showSnackbar("Phone number must be exactly 10 digits", isError: true);
      return;
    }

    // Aadhaar validation
    final validation = AadhaarValidator.validate(aadhaar);
    setState(() {
      _showAadhaarFeedback = true;
      _aadhaarResult = validation;
    });

    if (!validation.isValid) {
      _showSnackbar(validation.message, isError: true);
      return;
    }

    // Password length check
    if (pass.length < 6) {
      _showSnackbar("Password must be at least 6 characters", isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Get location for region
      String region = 'Unknown';
      try {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.low,
            timeLimit: const Duration(seconds: 10),
          );
          final placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
          if (placemarks.isNotEmpty) {
            final place = placemarks.first;
            region = '${place.administrativeArea ?? place.locality ?? 'Unknown'}, ${place.country ?? 'India'}';
          }
        }
      } catch (e) {
        debugPrint('Location error during registration: $e');
      }

      await FirebaseAuthService.registerUser(
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        email: email,
        gender: _selectedGender,
        aadhaar: aadhaar,
        password: pass,
        otherDetails: otherDetails,
        region: region,
      );
      if (!mounted) return;
      _showSnackbar("Account created! Please login.", isError: false);
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      _showSnackbar(e.toString().replaceAll('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackbar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins(fontSize: 13)),
        backgroundColor:
            isError ? const Color(0xFFEF4444) : const Color(0xFF22C55E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Aadhaar field border color
    Color aadhaarBorderColor = Colors.transparent;
    if (_showAadhaarFeedback && _aadhaarResult != null) {
      aadhaarBorderColor = _aadhaarResult!.isValid
          ? const Color(0xFF22C55E)
          : const Color(0xFFEF4444);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF1E293B),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Create Account",
              style: GoogleFonts.poppins(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E293B),
              ),
            ),
            Text(
              "Register to report civic issues reliably.",
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 30),

            Container(
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                children: [
                  // ── First Name and Last Name ──────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _firstNameController,
                          hint: "First Name",
                          icon: Icons.person,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildTextField(
                          controller: _lastNameController,
                          hint: "Last Name",
                          icon: Icons.person_outline,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),

                  // ── Phone Number ─────────────────────────────────────────
                  _buildTextField(
                    controller: _phoneController,
                    hint: "10-Digit Phone Number",
                    icon: Icons.phone,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                  ),
                  const SizedBox(height: 15),
                  
                  // ── Gender Dropdown ──────────────────────────────────────
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _selectedGender,
                        icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF3B82F6)),
                        items: ['Male', 'Female', 'Other'].map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Row(
                              children: [
                                const Icon(Icons.people, color: Color(0xFF3B82F6), size: 20),
                                const SizedBox(width: 12),
                                Text(value, style: GoogleFonts.poppins(color: Colors.black87)),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _selectedGender = newValue;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),

                  // ── Email ────────────────────────────────────────────────
                  _buildTextField(
                    controller: _emailController,
                    hint: "Email Address",
                    icon: Icons.email,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 15),

                  // ── Password ─────────────────────────────────────────────
                  _buildTextField(
                    controller: _passController,
                    hint: "Create Password (min. 6 chars)",
                    icon: Icons.lock,
                    obscureText: true,
                  ),
                  const SizedBox(height: 15),

                  // ── Confirm Password ──────────────────────────────────────
                  _buildTextField(
                    controller: _confirmPassController,
                    hint: "Confirm Password",
                    icon: Icons.lock_outline,
                    obscureText: true,
                  ),
                  const SizedBox(height: 15),

                  // ── Aadhaar Field with real-time validation ──────────────
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: aadhaarBorderColor,
                            width: 2,
                          ),
                        ),
                        child: TextField(
                          controller: _aadhaarController,
                          keyboardType: TextInputType.number,
                          maxLength: 12,
                          decoration: InputDecoration(
                            counterText: "",
                            hintText: "12-Digit Aadhaar Number",
                            prefixIcon: const Icon(
                              Icons.fingerprint,
                              color: Color(0xFF3B82F6),
                            ),
                            suffixIcon: _showAadhaarFeedback &&
                                    _aadhaarResult != null
                                ? Icon(
                                    _aadhaarResult!.isValid
                                        ? Icons.check_circle
                                        : Icons.cancel,
                                    color: _aadhaarResult!.isValid
                                        ? const Color(0xFF22C55E)
                                        : const Color(0xFFEF4444),
                                  )
                                : null,
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),

                      // Inline validation message
                      if (_showAadhaarFeedback && _aadhaarResult != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6, left: 4),
                          child: Row(
                            children: [
                              Icon(
                                _aadhaarResult!.isValid
                                    ? Icons.verified_user
                                    : Icons.info_outline,
                                size: 13,
                                color: _aadhaarResult!.isValid
                                    ? const Color(0xFF22C55E)
                                    : const Color(0xFFEF4444),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  _aadhaarResult!.message,
                                  style: GoogleFonts.poppins(
                                    fontSize: 11.5,
                                    color: _aadhaarResult!.isValid
                                        ? const Color(0xFF22C55E)
                                        : const Color(0xFFEF4444),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 15),

                  // ── Other Details ────────────────────────────────────────
                  _buildTextField(
                    controller: _otherDetailsController,
                    hint: "Other Details (Optional)",
                    icon: Icons.notes,
                  ),

                  const SizedBox(height: 25),

                  // ── Register Button ────────────────────────────────────
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleRegister,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            "REGISTER",
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    int? maxLength,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      maxLength: maxLength,
      decoration: InputDecoration(
        counterText: "",
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF3B82F6)),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
