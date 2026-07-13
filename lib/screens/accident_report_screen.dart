import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/location_service.dart';
import '../services/firestore_service.dart';

class AccidentReportScreen extends StatefulWidget {
  const AccidentReportScreen({super.key});

  @override
  State<AccidentReportScreen> createState() => _AccidentReportScreenState();
}

class _AccidentReportScreenState extends State<AccidentReportScreen>
    with SingleTickerProviderStateMixin {
  File? _image;
  bool _isLocating = false;
  bool _isSubmitting = false;
  double? _latitude;
  double? _longitude;
  String _locationLabel = 'Tap to detect location';
  final TextEditingController _descController = TextEditingController();

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    // Auto-fetch location on open
    _fetchLocation();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _fetchLocation() async {
    setState(() {
      _isLocating = true;
      _locationLabel = 'Detecting location...';
    });
    final result = await LocationService.getCurrentLocation();
    setState(() {
      _isLocating = false;
      if (result.isSuccess) {
        _latitude = result.position!.latitude;
        _longitude = result.position!.longitude;
        _locationLabel =
            'Lat: ${result.position!.latitude.toStringAsFixed(5)},  '
            'Lng: ${result.position!.longitude.toStringAsFixed(5)}';
      } else {
        _locationLabel = result.error ?? 'Location unavailable — tap to retry';
        // If GPS off or permission denied forever, offer Settings
        if (result.error != null &&
            (result.error!.contains('Settings') ||
                result.error!.contains('turned off') ||
                result.error!.contains('permanently'))) {
          _showLocationSettingsDialog(result.error!);
        }
      }
    });
  }

  void _showLocationSettingsDialog(String reason) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.location_off, color: Color(0xFFEF4444)),
            const SizedBox(width: 8),
            Text(
              'Location Issue',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(reason, style: GoogleFonts.poppins(fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              Navigator.pop(context);
              if (reason.contains('turned off') || reason.contains('GPS')) {
                await LocationService.openLocationSettings();
              } else {
                await LocationService.openAppSettings();
              }
            },
            child: Text(
              'Open Settings',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1280,
    );
    if (picked != null) {
      setState(() => _image = File(picked.path));
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
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
              const SizedBox(height: 20),
              Text(
                'Add Accident Photo',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _imageSourceButton(
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    color: const Color(0xFFEF4444),
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.camera);
                    },
                  ),
                  _imageSourceButton(
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    color: const Color(0xFF3B82F6),
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.gallery);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imageSourceButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitSOS() async {
    if (_image == null) {
      _showError('Please add a photo of the accident');
      return;
    }
    if (_latitude == null || _longitude == null) {
      _showError('Location not detected. Please retry location.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await FirestoreService.insertAccident({
        'imagePath': _image!.path,
        'latitude': _latitude,
        'longitude': _longitude,
        'description': _descController.text.trim(),
        'timestamp': DateTime.now().toIso8601String(),
        'status': 'SOS Sent',
      });

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      // Show success dialog, then call 112
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(
                  color: Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF16A34A),
                  size: 48,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'SOS Sent!',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your accident report has been saved with GPS location.\n\nNow calling emergency services (112)...',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.call),
                  label: Text(
                    'Call 112 Now',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () async {
                    Navigator.pop(context);
                    await _call112();
                  },
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: Text(
                  'Done',
                  style: GoogleFonts.poppins(color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        _showError('Failed to submit report. Please try again.');
      }
    }
  }

  Future<void> _call112() async {
    final uri = Uri.parse('tel:112');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) _showError('Cannot open dialer. Please call 112 manually.');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.poppins(fontSize: 13)),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: CustomScrollView(
        slivers: [
          // ── Emergency App Bar ──────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: const Color(0xFFDC2626),
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF7F1D1D), Color(0xFFDC2626)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 30),
                      ScaleTransition(
                        scale: _pulseAnimation,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.emergency_rounded,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'ACCIDENT REPORT',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                      Text(
                        'Emergency SOS System',
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Body ──────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Photo Section ─────────────────────────────────────────
                  _sectionLabel('📸 Accident Photo', required: true),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: _showImageSourceSheet,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: _image != null
                              ? const Color(0xFF22C55E)
                              : const Color(0xFFEF4444).withValues(alpha: 0.6),
                          width: 2,
                        ),
                        color: const Color(0xFF1E293B),
                      ),
                      child: _image != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.file(_image!, fit: BoxFit.cover),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_a_photo_rounded,
                                  size: 48,
                                  color: const Color(
                                    0xFFEF4444,
                                  ).withValues(alpha: 0.7),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Tap to add accident photo',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white54,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  if (_image != null) ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _showImageSourceSheet,
                      child: Row(
                        children: [
                          const Icon(
                            Icons.refresh,
                            color: Color(0xFF94A3B8),
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Change photo',
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF94A3B8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // ── Location Section ──────────────────────────────────────
                  _sectionLabel('📍 Accident Location', required: true),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: _isLocating ? null : _fetchLocation,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _latitude != null
                              ? const Color(0xFF22C55E).withValues(alpha: 0.5)
                              : const Color(0xFF475569),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _latitude != null
                                  ? const Color(
                                      0xFF22C55E,
                                    ).withValues(alpha: 0.15)
                                  : const Color(
                                      0xFF475569,
                                    ).withValues(alpha: 0.3),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _latitude != null
                                  ? Icons.location_on
                                  : Icons.location_searching,
                              color: _latitude != null
                                  ? const Color(0xFF22C55E)
                                  : Colors.grey,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _isLocating
                                ? Row(
                                    children: [
                                      const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Color(0xFF3B82F6),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        'Detecting GPS location...',
                                        style: GoogleFonts.poppins(
                                          color: Colors.white54,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  )
                                : Text(
                                    _locationLabel,
                                    style: GoogleFonts.poppins(
                                      color: _latitude != null
                                          ? Colors.white
                                          : Colors.white54,
                                      fontSize: 12.5,
                                    ),
                                  ),
                          ),
                          if (!_isLocating)
                            Icon(
                              _latitude != null
                                  ? Icons.check_circle
                                  : Icons.refresh,
                              color: _latitude != null
                                  ? const Color(0xFF22C55E)
                                  : Colors.grey,
                              size: 18,
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Description Section ───────────────────────────────────
                  _sectionLabel('📝 Brief Description (optional)'),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _descController,
                    maxLines: 3,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      hintText:
                          'e.g. Car collision, 2 people injured, near signal...',
                      hintStyle: GoogleFonts.poppins(
                        color: Colors.white38,
                        fontSize: 12.5,
                      ),
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFF334155)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFF334155)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: Color(0xFFEF4444),
                          width: 2,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ── Emergency Info Box ────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7F1D1D).withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Color(0xFFFCA5A5),
                          size: 16,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'After submitting, your GPS location and photo will be saved. '
                            'The app will open the dialer with emergency number 112 so you can call for an ambulance immediately.',
                            style: GoogleFonts.poppins(
                              color: const Color(0xFFFCA5A5),
                              fontSize: 11.5,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── SOS Submit Button ─────────────────────────────────────
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : _submitSOS,
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.emergency_rounded, size: 24),
                        label: Text(
                          _isSubmitting
                              ? 'Sending SOS...'
                              : 'SEND SOS & CALL 112',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(
                            0xFFDC2626,
                          ).withValues(alpha: 0.5),
                          elevation: 8,
                          shadowColor: const Color(
                            0xFFEF4444,
                          ).withValues(alpha: 0.5),
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Direct call 112 button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(
                        Icons.call,
                        color: Color(0xFFFCA5A5),
                        size: 18,
                      ),
                      label: Text(
                        'Call 112 Directly',
                        style: GoogleFonts.poppins(
                          color: const Color(0xFFFCA5A5),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFEF4444)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: _call112,
                    ),
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text, {bool required = false}) {
    return Row(
      children: [
        Text(
          text,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (required) ...[
          const SizedBox(width: 4),
          const Text(
            '*',
            style: TextStyle(
              color: Color(0xFFEF4444),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ],
    );
  }
}
