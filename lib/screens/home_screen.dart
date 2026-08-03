import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/firestore_service.dart';
import '../services/firebase_auth_service.dart';
import '../services/location_service.dart';
import '../services/draft_service.dart';
import 'drafts_screen.dart';
import 'notification_screen.dart';
import 'profile_screen.dart';
import '../utils/global_state.dart';
import '../services/notification_service.dart';
import '../services/status_simulation_service.dart';
import 'package:shimmer/shimmer.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _userName = "Citizen";
  String _userLocation = "Locating...";
  String? _profileImagePath;
  int _unreadNotifications = 0;
  int _pendingDraftsCount = 0;
  
  bool _isLoading = true;

  Future<void> _initializeData() async {
    // Request notification permissions now that the UI is built
    NotificationService.requestPermission();
    // Catch up any missed background progressions
    StatusSimulationService.catchUpMissedUpdates();
    
    await Future.wait([
      _fetchUserDetails(),
      _fetchUserLocation(),
      _fetchUnreadCount(),
      _fetchProfileImage(),
      _fetchDraftsCount(),
      Future.delayed(const Duration(milliseconds: 800)), // Assures shimmer lasts enough to feel premium
    ]);
    
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _fetchUserLocation({bool showToast = false}) async {
    if (showToast && mounted) setState(() => _userLocation = "Locating...");
    final locationResult = await LocationService.getCurrentLocation();
    if (locationResult.isSuccess && mounted) {
      final pos = locationResult.position!;
      final address = await LocationService.getAddressFromLocation(pos.latitude, pos.longitude);
      if (mounted) setState(() => _userLocation = address ?? "Location Unknown");
      if (showToast && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location tracked successfully!'), duration: Duration(seconds: 2)),
        );
      }
    } else if (mounted) {
      setState(() => _userLocation = "Location Unavailable");
      if (showToast) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(locationResult.error ?? "Could not fetch location"),
            backgroundColor: Colors.redAccent,
            action: SnackBarAction(
              label: 'Settings',
              textColor: Colors.white,
              onPressed: () => LocationService.openAppSettings(),
            ),
          ),
        );
      }
    }
  }

  Future<void> _fetchUserDetails() async {
    try {
      final details = await FirebaseAuthService.getCurrentUserDetails();
      if (details != null && mounted) {
        setState(() => _userName = details['name'] ?? "Citizen");
      }
    } catch (_) {}
  }

  Future<void> _fetchProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString('profile_image_path');
    if (mounted) setState(() => _profileImagePath = path);
  }

  Future<void> _fetchDraftsCount() async {
    final drafts = await DraftService.getDrafts();
    if (mounted) setState(() => _pendingDraftsCount = drafts.length);
  }

  Future<void> _fetchUnreadCount() async {
    final count = await FirestoreService.getUnreadNotificationCount();
    if (mounted) setState(() => _unreadNotifications = count);
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 0,
        title: Row(
          children: [
            GestureDetector(
              onTap: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
                _fetchProfileImage();
              },
              child: CircleAvatar(
                backgroundColor: const Color(0xFF3B82F6),
                radius: 20,
                backgroundImage: _profileImagePath != null ? FileImage(File(_profileImagePath!)) as ImageProvider : null,
                child: _profileImagePath == null ? const Icon(Icons.person, color: Colors.white, size: 20) : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Hello, $_userName!", style: GoogleFonts.poppins(fontSize: 14, color: Colors.white70), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  GestureDetector(
                    onTap: () => _fetchUserLocation(showToast: true),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on, color: Color(0xFF3B82F6), size: 14),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(_userLocation, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none, color: Colors.white),
                onPressed: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationScreen()));
                  _fetchUnreadCount();
                },
              ),
              if (_unreadNotifications > 0)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    child: Text('$_unreadNotifications', style: GoogleFonts.poppins(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await FirebaseAuthService.logout();
              if (!context.mounted) return;
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildMainScrollContent(),
      ),
    );
  }

  Widget _buildMainScrollContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 25.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── DRAFTS BANNER ──
          if (_pendingDraftsCount > 0) ...[
            _buildDraftsBanner(),
            const SizedBox(height: 25),
          ],

          // ── LOCALITY OVERVIEW ──
          Text(tr("Locality Overview"), style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
          const SizedBox(height: 15),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: FirestoreService.getReports(),
            builder: (context, snapshot) {
              int reported = snapshot.hasData ? snapshot.data!.length : 0;
              int inProgress = snapshot.hasData ? snapshot.data!.where((r) => r['status'] == 'In Progress' || r['status'] == 'Pending').length : 0;
              int resolved = snapshot.hasData ? snapshot.data!.where((r) => r['status'] == 'Resolved').length : 0;
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatBox("$reported", tr("Total reported"), const Color(0xFFFFE4E6), const Color(0xFFE11D48), Icons.report),
                  _buildStatBox("$inProgress", tr("In progress"), const Color(0xFFFEF3C7), const Color(0xFFD97706), Icons.engineering),
                  _buildStatBox("$resolved", tr("Resolved"), const Color(0xFFD1FAE5), const Color(0xFF059669), Icons.check_circle),
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // ── ANALYTICS CARD ──
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/analytics'),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E293B), Color(0xFF334155)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF3B82F6).withAlpha(40), blurRadius: 18, offset: const Offset(0, 8)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFF3B82F6).withAlpha(40), shape: BoxShape.circle),
                    child: const Icon(Icons.bar_chart_rounded, color: Color(0xFF3B82F6), size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Ward Analytics', style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                        Text('Charts · Status · Category breakdown', style: GoogleFonts.poppins(color: Colors.white54, fontSize: 11)),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white38, size: 16),
                ],
              ),
            ),
          ),
          const SizedBox(height: 25),

          // ── REPORT AN ISSUE ──
          Text(tr("Report an Issue"), style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
          const SizedBox(height: 15),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            mainAxisSpacing: 15,
            crossAxisSpacing: 15,
            childAspectRatio: 0.70,
            children: [
              _buildCategoryItem(Icons.construction, "Roads (Pothole)", const Color(0xFFF1F5F9), const Color(0xFF475569)),
              _buildCategoryItem(Icons.water_damage, "Water Leakage", const Color(0xFFEFF6FF), const Color(0xFF2563EB)),
              _buildCategoryItem(Icons.delete_sweep, "Garbage", const Color(0xFFECFCCB), const Color(0xFF65A30D)),
              _buildCategoryItem(Icons.waves, "Drainage", const Color(0xFFFFEDD5), const Color(0xFFEA580C)),
              _buildCategoryItem(Icons.tungsten, "Street Light", const Color(0xFFFEF08A), const Color(0xFFCA8A04)),
            ],
          ),
        ],
      ),
    );
  }



  Widget _buildStatBox(String count, String label, Color bgColor, Color iconColor, IconData icon) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.28,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: iconColor.withAlpha(25), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(
        children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: bgColor.withAlpha(150), shape: BoxShape.circle), child: Icon(icon, color: iconColor, size: 24)),
          const SizedBox(height: 12),
          Text(count, style: GoogleFonts.poppins(color: const Color(0xFF1E293B), fontSize: 24, fontWeight: FontWeight.w700, height: 1.1)),
          const SizedBox(height: 4),
          Text(label, textAlign: TextAlign.center, style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 10, fontWeight: FontWeight.w600, height: 1.2)),
        ],
      ),
    );
  }

  Widget _buildCategoryItem(IconData icon, String label, Color bgColor, Color iconColor) {
    return InkWell(
      onTap: () => Navigator.pushNamed(context, '/report', arguments: label),
      borderRadius: BorderRadius.circular(20),
      splashColor: iconColor.withAlpha(30),
      highlightColor: iconColor.withAlpha(10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.withAlpha(20), width: 1.5),
          boxShadow: [BoxShadow(color: iconColor.withAlpha(15), blurRadius: 15, offset: const Offset(0, 6))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle), child: Icon(icon, color: iconColor, size: 28)),
            const SizedBox(height: 12),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Text(label, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, maxLines: 2, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF334155), height: 1.2)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDraftsBanner() {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => const DraftsScreen()));
        _fetchDraftsCount(); // Refresh count after returning from DraftsScreen
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)], // Elegant Purple
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: const Color(0xFF8B5CF6).withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: const Icon(Icons.cloud_sync_rounded, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'You have $_pendingDraftsCount Offline Draft${_pendingDraftsCount == 1 ? '' : 's'}!',
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                  ),
                  Text(
                    'Tap here to sync pending reports.',
                    style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
              child: Text('SYNC', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)),
            ),
          ],
        ),
      ),
    );
  }
}


