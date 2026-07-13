import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'home_screen.dart';
import 'history_screen.dart';
import 'community_screen.dart';
import 'profile_screen.dart';
import '../utils/global_state.dart';
import 'package:image_picker/image_picker.dart';
import '../services/image_validation_service.dart';
import '../services/location_service.dart';
import '../services/draft_service.dart';

class MainScreen extends StatefulWidget {
  final int initialPage;
  const MainScreen({super.key, this.initialPage = 0});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _currentIndex;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialPage;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      if (index == 0) _currentIndex = 0;
      else if (index == 1) _currentIndex = 1; // Community
      else if (index == 2) _currentIndex = 3; // History
      else if (index == 3) _currentIndex = 4; // Profile
    });
  }

  Future<void> _onItemTapped(int index) async {
    if (index == 2) { // Center Capture button
      final picker = ImagePicker();
      final photo = await picker.pickImage(source: ImageSource.camera);
      if (photo != null) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => const Center(child: CircularProgressIndicator()),
        );
        try {
          String? category = await ImageValidationService.detectCategory(photo.path);
          final locationResult = await LocationService.getCurrentLocation();
          
          if (!locationResult.isSuccess || locationResult.position == null) {
             if (mounted) {
               Navigator.pop(context);
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to save draft location. Enable GPS.")));
             }
             return;
          }

          final directory = await getApplicationDocumentsDirectory();
          final File localImage = await File(photo.path).copy('${directory.path}/draft_${DateTime.now().millisecondsSinceEpoch}.jpg');

          final draft = DraftReport(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            category: category ?? 'Unknown',
            description: '',
            mediaPath: localImage.path,
            mediaType: 'image',
            latitude: locationResult.position!.latitude,
            longitude: locationResult.position!.longitude,
            timestamp: DateTime.now().toString(),
          );
          
          await DraftService.saveDraft(draft);

          if (mounted) {
            Navigator.pop(context); // Close dialog
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Photo locked to location and saved to Drafts!")));
            // Refresh home screen if we are on it, or just let user pull to refresh.
          }
        } catch (e) {
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to save draft: $e")));
          }
        }
      }
      return; 
    }
    
    int pageIndex = index;
    if (index > 2) {
      pageIndex = index - 1; 
    }

    _pageController.animateToPage(
      pageIndex,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, Color color) {
    bool isSelected = _currentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => _onItemTapped(index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCirc,
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: isSelected ? color.withAlpha(35) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? color : Colors.grey[400],
                size: 24,
              ),
              if (isSelected) 
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      tr(label),
                      style: GoogleFonts.poppins(
                        color: color,
                        fontWeight: FontWeight.w600,
                        fontSize: 10, // slightly smaller font
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCenterCaptureButton() {
    return Transform.translate(
      offset: const Offset(0, -12),
      child: GestureDetector(
        onTap: () => _onItemTapped(2),
        child: Container(
          height: 58,
          width: 58,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFEF4444), Color(0xFFB91C1C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFEF4444).withValues(alpha: 0.45),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(color: Colors.white, width: 3),
          ),
          child: const Icon(
            Icons.camera_alt_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: () async {
        if (_currentIndex != 0) {
          _onItemTapped(0); // Go back to Home Tab instead of closing app
          return false; // Prevent exit
        }
        return true; // Exits app if currently on Home tab
      },
      child: Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        physics: const NeverScrollableScrollPhysics(), // Recommended when using BottomNavigationBar to prevent swiping breaking UI
        children: const [
          HomeScreen(),
          CommunityScreen(),
          HistoryScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(20),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ],
            border: Border.all(color: Colors.grey.withAlpha(25), width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildNavItem(0, Icons.home_rounded, "Home", const Color(0xFF3B82F6)),
                    _buildNavItem(1, Icons.groups_rounded, "Community", const Color(0xFFF59E0B)),
                  ],
                ),
              ),
              _buildCenterCaptureButton(),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildNavItem(3, Icons.history_rounded, "History", const Color(0xFF8B5CF6)),
                    _buildNavItem(4, Icons.person_rounded, "Profile", const Color(0xFFEC4899)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/chat'),
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.amber,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.auto_awesome),
      ),
    ),
    );
  }
}
