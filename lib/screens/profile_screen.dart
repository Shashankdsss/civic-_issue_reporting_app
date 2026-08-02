import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/global_state.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/firebase_auth_service.dart';
import '../services/firestore_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _userDetails;
  int _totalReports = 0;
  int _resolvedReports = 0;
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;
  String? _profileImagePath;
  bool _isDarkMode = false;
  bool _notificationsEnabled = true;
  String _selectedLanguage = 'English';

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final details = await FirebaseAuthService.getCurrentUserDetails();
      List<Map<String, dynamic>> reports = [];
      try {
        reports = await FirestoreService.getReports();
      } catch (_) {
        // Firestore permission errors — stats will show 0
      }
      if (mounted) {
        setState(() {
          _userDetails = details;
          _totalReports = reports.length;
          _resolvedReports = reports.where((r) => r['status'] == 'Resolved').length;
          _profileImagePath = prefs.getString('profile_image_path');
          _isDarkMode = prefs.getBool('darkMode') ?? false;
          _notificationsEnabled = prefs.getBool('notifications') ?? true;
          _selectedLanguage = prefs.getString('language') ?? 'English';
          _isLoading = false;
          // Pre-fill the edit controllers
          _nameController.text = details?['name'] ?? '';
          _phoneController.text = details?['phone'] ?? '';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveChanges() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    if (name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and phone cannot be empty.')),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      final user = FirebaseAuthService.currentUser;
      if (user != null) {
        await FirebaseAuthService.updateUserDetails(user.uid, name: name, phone: phone);
        setState(() {
          _userDetails = {...?_userDetails, 'name': name, 'phone': phone};
          _isEditing = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully!'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _toggleDarkMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', value);
    GlobalState.themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
    setState(() => _isDarkMode = value);
  }

  Future<void> _toggleNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications', value);
    setState(() => _notificationsEnabled = value);
  }

  Future<void> _changeLanguage(String lang) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', lang);
    GlobalState.languageNotifier.value = lang;
    setState(() => _selectedLanguage = lang);
  }

  void _showLanguagePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(tr('Select Language'), style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              ...['English', 'Hindi', 'Marathi', 'Kannada', 'Tamil', 'Telugu'].map((lang) => 
                ListTile(
                  title: Text(lang, style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                  trailing: _selectedLanguage == lang ? const Icon(Icons.check_circle, color: const Color(0xFF10B981)) : null,
                  onTap: () {
                    _changeLanguage(lang);
                    Navigator.pop(context);
                  },
                )
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickProfilePhoto(ImageSource source) async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(source: source, imageQuality: 80);
    if (picked != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profile_image_path', picked.path);
      if (mounted) setState(() => _profileImagePath = picked.path);
    }
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text('Change Profile Photo',
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _photoOptionButton(
                    icon: Icons.camera_alt,
                    label: 'Camera',
                    color: const Color(0xFF3B82F6),
                    onTap: () {
                      Navigator.pop(context);
                      _pickProfilePhoto(ImageSource.camera);
                    },
                  ),
                  _photoOptionButton(
                    icon: Icons.photo_library,
                    label: 'Gallery',
                    color: const Color(0xFF10B981),
                    onTap: () {
                      Navigator.pop(context);
                      _pickProfilePhoto(ImageSource.gallery);
                    },
                  ),
                  if (_profileImagePath != null)
                    _photoOptionButton(
                      icon: Icons.delete_outline,
                      label: 'Remove',
                      color: Colors.red,
                      onTap: () async {
                        final nav = Navigator.of(context);
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.remove('profile_image_path');
                        if (mounted) setState(() => _profileImagePath = null);
                        nav.pop();
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  void _showFullScreenAvatar() {
    if (_profileImagePath == null) return;
    
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.file(File(_profileImagePath!), fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoOptionButton({required IconData icon, required String label, required Color color, required void Function() onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 6),
          Text(label, style: GoogleFonts.poppins(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  String _formatAadhaar(String aadhaar) {
    if (aadhaar.length == 12) {
      return '${aadhaar.substring(0, 4)} ${aadhaar.substring(4, 8)} ${aadhaar.substring(8, 12)}';
    }
    return aadhaar;
  }

  String _formatDate(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return 'N/A';
    try {
      final dt = DateTime.parse(isoDate);
      const months = [
        '', 'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ];
      return '${months[dt.month]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return 'N/A';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // ── HERO APP BAR ──
                SliverAppBar(
                  expandedHeight: 260,
                  pinned: true,
                  backgroundColor: const Color(0xFF1E293B),
                  foregroundColor: Colors.white,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF0F172A), Color(0xFF1E3A5F)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // ── TAPPABLE AVATAR ──
                          Stack(
                            children: [
                              GestureDetector(
                                onTap: _profileImagePath != null ? _showFullScreenAvatar : _showPhotoOptions,
                                child: Container(
                                  width: 95,
                                  height: 95,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFF3B82F6),
                                    border: Border.all(color: Colors.white, width: 3),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF3B82F6).withValues(alpha: 0.4),
                                        blurRadius: 20,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                    image: _profileImagePath != null
                                        ? DecorationImage(
                                            image: FileImage(File(_profileImagePath!)),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                  ),
                                  child: _profileImagePath == null
                                      ? Center(
                                          child: Text(
                                            (_userDetails?['name'] ?? 'U')[0].toUpperCase(),
                                            style: GoogleFonts.poppins(
                                              fontSize: 36,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                              // Camera badge
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: _showPhotoOptions,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF3B82F6),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 14),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _userDetails?['name'] ?? 'Citizen',
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Verified Citizen 🇮🇳',
                            style: GoogleFonts.poppins(fontSize: 13, color: Colors.white60),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── CIVIC WALLET CARD ──
                        _buildCivicWalletCard(),
                        const SizedBox(height: 24),

                        // ── STATS ROW ──
                        Row(
                          children: [
                            _buildStatCard('$_totalReports', 'Reports Filed', Icons.report_outlined, const Color(0xFF3B82F6)),
                            const SizedBox(width: 12),
                            _buildStatCard('$_resolvedReports', 'Resolved', Icons.check_circle_outline, const Color(0xFF10B981)),
                            const SizedBox(width: 12),
                            _buildStatCard(
                              _totalReports > 0 ? '${((_resolvedReports / _totalReports) * 100).round()}%' : '0%',
                              'Success Rate',
                              Icons.trending_up,
                              const Color(0xFFF59E0B),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // ── PERSONAL INFO ──
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Personal Information',
                                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1E293B))),
                            if (!_isEditing)
                              TextButton.icon(
                                onPressed: () => setState(() => _isEditing = true),
                                icon: const Icon(Icons.edit, size: 16),
                                label: Text('Edit', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                                style: TextButton.styleFrom(foregroundColor: const Color(0xFF3B82F6)),
                              )
                            else
                              Row(
                                children: [
                                  TextButton(
                                    onPressed: () {
                                      setState(() => _isEditing = false);
                                      _nameController.text = _userDetails?['name'] ?? '';
                                      _phoneController.text = _userDetails?['phone'] ?? '';
                                    },
                                    child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
                                  ),
                                  _isSaving
                                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                      : TextButton(
                                          onPressed: _saveChanges,
                                          child: Text('Save', style: GoogleFonts.poppins(color: const Color(0xFF10B981), fontWeight: FontWeight.bold)),
                                        ),
                                ],
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildInfoCard([
                          _isEditing
                              ? _buildEditRow(Icons.person_outline, 'Full Name', _nameController, TextInputType.name)
                              : _buildInfoRow(Icons.person_outline, 'Full Name', _userDetails?['name'] ?? 'N/A'),
                          const Divider(height: 1),
                          _isEditing
                              ? _buildEditRow(Icons.phone_outlined, 'Phone Number', _phoneController, TextInputType.phone)
                              : _buildInfoRow(Icons.phone_outlined, 'Phone Number', _userDetails?['phone'] ?? 'N/A'),
                          const Divider(height: 1),
                          _buildInfoRow(
                            Icons.credit_card,
                            'Aadhaar Number',
                            _formatAadhaar(_userDetails?['aadhaar'] ?? ''),
                            sensitive: true,
                          ),
                        ]),

                        const SizedBox(height: 20),

                        // ── ACCOUNT INFO ──
                        Text('Account Information',
                            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1E293B))),
                        const SizedBox(height: 12),
                        _buildInfoCard([
                          _buildInfoRow(Icons.calendar_today_outlined, 'Member Since', _formatDate(_userDetails?['createdAt'])),
                          const Divider(height: 1),
                          _buildInfoRow(Icons.verified_user_outlined, 'Account Status', 'Active & Verified', valueColor: const Color(0xFF10B981)),
                          const Divider(height: 1),
                          _buildInfoRow(Icons.location_city_outlined, 'Region', _userDetails?['region'] ?? 'Unknown'),
                        ]),

                        const SizedBox(height: 24),

                        // ── PREFERENCES ──
                        ValueListenableBuilder<String>(
                          valueListenable: GlobalState.languageNotifier,
                          builder: (_, __, ___) => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(tr('App Preferences'),
                                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1E293B))),
                              const SizedBox(height: 12),
                              _buildInfoCard([
                                _buildActionRow(Icons.inventory_2_outlined, tr('My Drafts (Offline)'), '', () => Navigator.pushNamed(context, '/drafts')),
                                const Divider(height: 1),
                                _buildSwitchRow(Icons.dark_mode_outlined, tr('Dark Mode'), _isDarkMode, _toggleDarkMode),
                                const Divider(height: 1),
                                _buildSwitchRow(Icons.notifications_active_outlined, tr('Push Notifications'), _notificationsEnabled, _toggleNotifications),
                                const Divider(height: 1),
                                _buildActionRow(Icons.language, tr('Language'), _selectedLanguage, _showLanguagePicker),
                              ]),
                              const SizedBox(height: 24),
                              Text(tr('Support & About'),
                                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1E293B))),
                              const SizedBox(height: 12),
                              _buildInfoCard([
                                _buildActionRow(Icons.headset_mic_outlined, tr('Help & Support'), '', () => Navigator.pushNamed(context, '/chat')),
                                const Divider(height: 1),
                                _buildActionRow(Icons.shield_outlined, tr('Privacy Policy'), '', () => _showPolicyDialog("Privacy Policy", "1. Data Collection: We collect location data and photos to help resolve civic issues.\n2. Usage: Your data is only used for reporting issues to local authorities.\n3. Security: Your personal data (like Aadhaar) is encrypted.\n\nWe do not sell your data.", isDark)),
                                const Divider(height: 1),
                                _buildActionRow(Icons.info_outline, tr('Terms of Service'), '', () => _showPolicyDialog("Terms of Service", "1. By using CivicConnect, you agree to submit truthful reports.\n2. Do not spam or submit inappropriate content.\n3. We reserve the right to ban accounts violating these terms.\n4. Service is provided as-is without any warranties.", isDark)),
                              ]),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // ── LOGOUT BUTTON ──
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              await FirebaseAuthService.logout();
                              if (!context.mounted) return;
                              Navigator.pushReplacementNamed(context, '/login');
                            },
                            icon: const Icon(Icons.logout, color: Colors.red),
                            label: Text('Sign Out',
                                style: GoogleFonts.poppins(color: Colors.red, fontWeight: FontWeight.w600)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(color: Colors.red, width: 1.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatCard(String value, String label, IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.12), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(value, style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1E293B))),
            Text(label, textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 10, color: isDark ? Colors.white70 : Colors.grey[500])),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildEditRow(IconData icon, String label, TextEditingController controller, TextInputType keyboardType) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: isDark ? const Color(0xFF334155) : const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: const Color(0xFF3B82F6), size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.poppins(fontSize: 11, color: isDark ? Colors.white70 : Colors.grey[500])),
                const SizedBox(height: 4),
                TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF1E293B)),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 4, horizontal: 0),
                    border: UnderlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {bool sensitive = false, Color? valueColor}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: isDark ? const Color(0xFF334155) : const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: const Color(0xFF3B82F6), size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.poppins(fontSize: 11, color: isDark ? Colors.white70 : Colors.grey[500])),
                Text(
                  sensitive ? '${value.substring(0, value.length > 8 ? value.length - 4 : 0)}****' : value,
                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: valueColor ?? (isDark ? Colors.white : const Color(0xFF1E293B))),
                ),
              ],
            ),
          ),
          if (sensitive) _SensitiveToggle(fullValue: value),
        ],
      ),
    );
  }

  Widget _buildSwitchRow(IconData icon, String label, bool value, Function(bool) onChanged) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: isDark ? Colors.white70 : const Color(0xFF475569), size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF1E293B))),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF3B82F6),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow(IconData icon, String label, String trailingText, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: isDark ? Colors.white70 : const Color(0xFF475569), size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF1E293B))),
            ),
            if (trailingText.isNotEmpty)
              Text(trailingText, style: GoogleFonts.poppins(fontSize: 11, color: isDark ? Colors.white70 : Colors.grey[600], fontWeight: FontWeight.w600)),
            if (trailingText.isNotEmpty) const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: isDark ? Colors.white54 : Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }

  void _showPolicyDialog(String title, String content, bool isDark) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1E293B))),
        content: SingleChildScrollView(
          child: Text(content, style: GoogleFonts.poppins(color: isDark ? Colors.white70 : Colors.black87, height: 1.5)),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _buildCivicWalletCard() {
    final points = _userDetails?['civicPoints'] ?? 0;
    final rupeeValue = points / 10.0;
    final bankSaved = (_userDetails?['bankAccount']?.toString().isNotEmpty ?? false);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFFCD34D)]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: const Color(0xFFF59E0B).withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 5)),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Government Civic Wallet', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              const Icon(Icons.account_balance_wallet, color: Colors.white),
            ],
          ),
          const SizedBox(height: 16),
          Text('Available Balance', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('₹${rupeeValue.toStringAsFixed(0)}', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 32)),
              const SizedBox(width: 8),
              Text('($points Points)', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFFF59E0B),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => _showWithdrawDialog(bankSaved, rupeeValue),
              child: Text('Withdraw to Bank Account', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  void _showWithdrawDialog(bool bankSaved, double balance) {
    if (balance <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Your wallet balance is empty. Resolve civic issues to earn money!')));
      return;
    }
    
    final accCtrl = TextEditingController(text: _userDetails?['bankAccount'] ?? '');
    final ifscCtrl = TextEditingController(text: _userDetails?['ifscCode'] ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Withdraw Funds', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: accCtrl,
              decoration: const InputDecoration(labelText: 'Bank Account Number', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ifscCtrl,
              decoration: const InputDecoration(labelText: 'IFSC Code', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () async {
                  if (accCtrl.text.isEmpty || ifscCtrl.text.isEmpty) {
                    return;
                  }
                  await FirebaseAuthService.updateBankDetails(accCtrl.text, ifscCtrl.text);
                  
                  // Update local UI state
                  if (mounted) {
                    setState(() {
                      if (_userDetails != null) {
                         _userDetails!['bankAccount'] = accCtrl.text;
                         _userDetails!['ifscCode'] = ifscCtrl.text;
                      }
                    });
                  }
                  
                  if (ctx.mounted) Navigator.pop(ctx);
                  
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Withdrawal initiated! ₹Funds will reflect in 3-5 business days.'), backgroundColor: Colors.green)
                    );
                  }
                },
                child: Text('Confirm Withdrawal', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _SensitiveToggle extends StatefulWidget {
  final String fullValue;
  const _SensitiveToggle({required this.fullValue});

  @override
  State<_SensitiveToggle> createState() => _SensitiveToggleState();
}

class _SensitiveToggleState extends State<_SensitiveToggle> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _revealed = !_revealed),
      child: Column(
        children: [
          Icon(_revealed ? Icons.visibility_off : Icons.visibility, size: 18, color: Colors.grey),
          if (_revealed)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(widget.fullValue,
                  style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF3B82F6), fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}
