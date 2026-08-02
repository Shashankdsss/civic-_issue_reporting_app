import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../services/location_service.dart';
import '../services/firestore_service.dart';
import '../services/image_validation_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:native_exif/native_exif.dart';
import '../services/draft_service.dart';
import '../services/firebase_auth_service.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});
  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  String? selectedCategory;
  String? selectedSeverity;
  final List<String> severities = ['Low', 'Medium', 'High'];
  final List<String> categories = [
    'Roads (Pothole)',
    'Water Leakage',
    'Garbage',
    'Drainage',
    'Street Light',
  ];

  // ── Department Routing Map ──────────────────────────────────────────────────
  static const Map<String, Map<String, String>> _departmentMap = {
    'Roads (Pothole)': {
      'name': 'Public Works Department (PWD)',
      'abbr': 'PWD',
      'contact': '1800-123-4567',
      'priority': 'High',
    },
    'Water Leakage': {
      'name': 'Jal Board / Water Supply Dept.',
      'abbr': 'Jal Board',
      'contact': '1916',
      'priority': 'Medium',
    },
    'Garbage': {
      'name': 'Municipal Corporation (Solid Waste)',
      'abbr': 'Municipal Corp.',
      'contact': '1800-419-0001',
      'priority': 'Low',
    },
    'Drainage': {
      'name': 'Drainage & Sewerage Department',
      'abbr': 'Drainage Dept.',
      'contact': '1800-419-0002',
      'priority': 'High',
    },
    'Street Light': {
      'name': 'Electricity Board / MSEDCL',
      'abbr': 'MSEDCL',
      'contact': '1912',
      'priority': 'Medium',
    },
  };
  bool isLocating = false;
  XFile? _image;
  XFile? _video;
  bool _isVideo = false;
  bool _isFromGallery = false;
  DraftReport? _draftReport;
  double? _draftLat;
  double? _draftLng;
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _descriptionController = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (selectedCategory == null) {
      final arg = ModalRoute.of(context)?.settings.arguments;
      if (arg is String && categories.contains(arg)) {
        selectedCategory = arg;
      } else if (arg is DraftReport) {
        _draftReport = arg;
        selectedCategory = categories.contains(arg.category) ? arg.category : null;
        _descriptionController.text = arg.description;
        if (arg.mediaType == 'video') {
           _video = XFile(arg.mediaPath);
           _isVideo = true;
        } else {
           _image = XFile(arg.mediaPath);
           _isVideo = false;
        }
        _isFromGallery = false;
        _draftLat = arg.latitude;
        _draftLng = arg.longitude;
      } else if (arg is Map && arg['isQuickCapture'] == true) {
        selectedCategory = categories.contains(arg['category']) ? arg['category'] : null;
        if (arg['imagePath'] != null) {
          _image = XFile(arg['imagePath']);
        }
        if (arg['description'] != null) {
          _descriptionController.text = arg['description'];
        }
        _isVideo = false;
        _isFromGallery = false;
      }
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo != null) {
      setState(() {
        _image = photo;
        _video = null;
        _isVideo = false;
        _isFromGallery = false;
      });
    }
  }

  Future<void> _uploadPhoto() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.gallery);
    if (photo != null) {
      setState(() {
        _image = photo;
        _video = null;
        _isVideo = false;
        _isFromGallery = true;
      });
    }
  }

  Future<void> _recordVideo() async {
    final XFile? video = await _picker.pickVideo(
      source: ImageSource.camera,
      maxDuration: const Duration(seconds: 60),
    );
    if (video != null) {
      setState(() {
        _video = video;
        _image = null;
        _isVideo = true;
        _isFromGallery = false;
      });
    }
  }

  Future<void> _uploadVideo() async {
    final XFile? video = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(seconds: 60),
    );
    if (video != null) {
      setState(() {
        _video = video;
        _image = null;
        _isVideo = true;
        _isFromGallery = true;
      });
    }
  }

  Future<void> _saveToDrafts() async {
    final bool hasMedia = _isVideo ? _video != null : _image != null;
    if (!hasMedia) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Attach a photo or video to save as draft!")));
      return;
    }
    setState(() => isLocating = true);
    try {
      double? finalLat = _draftLat;
      double? finalLng = _draftLng;
      if (finalLat == null || finalLng == null) {
         final locationResult = await LocationService.getCurrentLocation();
         if (locationResult.isSuccess) {
           finalLat = locationResult.position!.latitude;
           finalLng = locationResult.position!.longitude;
         } else {
           if (!mounted) return;
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to save draft location.")));
           setState(() => isLocating = false);
           return;
         }
      }

      // --- DUPLICATE CHECK FOR DRAFTS ---
      final existingReports = await FirestoreService.getReportsByCategory(selectedCategory ?? '');
      int duplicateCount = 0;
      for (var report in existingReports) {
        if (report['latitude'] != null && report['longitude'] != null) {
          double distance = Geolocator.distanceBetween(
            finalLat,
            finalLng,
            (report['latitude'] as num).toDouble(),
            (report['longitude'] as num).toDouble(),
          );
          if (distance <= 50) duplicateCount++;
        }
      }
      
      if (duplicateCount > 0) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Duplicate location! Someone already reported this specific type of issue within 50m.")));
        setState(() => isLocating = false);
        return;
      }

      final directory = await getApplicationDocumentsDirectory();
      String localMediaPath;
      if (_isVideo) {
        final File localVideo = await File(_video!.path).copy('${directory.path}/draft_${DateTime.now().millisecondsSinceEpoch}.mp4');
        localMediaPath = localVideo.path;
      } else {
        final File localImage = await File(_image!.path).copy('${directory.path}/draft_${DateTime.now().millisecondsSinceEpoch}.jpg');
        localMediaPath = localImage.path;
      }
      final draft = DraftReport(
        id: _draftReport?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        category: selectedCategory ?? '',
        description: _descriptionController.text.trim(),
        mediaPath: localMediaPath,
        mediaType: _isVideo ? 'video' : 'image',
        latitude: finalLat,
        longitude: finalLng,
        timestamp: DateTime.now().toString(),
      );
      await DraftService.saveDraft(draft);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Saved to Drafts (Location locked)")));
      Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error saving draft: $e")));
    } finally {
      if (mounted) setState(() => isLocating = false);
    }
  }

  void handleReport() async {
    // 1. Validation: Make sure category and image/video selected, description filled
    final bool hasMedia = _isVideo ? _video != null : _image != null;
    if (selectedCategory == null || selectedSeverity == null || !hasMedia || _descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select a category and severity, add a description, and attach a photo or video!"),
        ),
      );
      return;
    }

    setState(() => isLocating = true);

    try {
      // 1.5. Validate Image using ML Kit (skip for video)
      if (!_isVideo) {
        final validation = await ImageValidationService.validateImage(
            _image!.path, selectedCategory!);

        if (!validation.isValid) {
          if (!mounted) return;
          setState(() => isLocating = false);
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text("Image Validation Failed"),
              content: Text(validation.message),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("CLOSE"),
                ),
              ],
            ),
          );
          return;
        }
      }

      // 2. Get Location
      double? finalLat;
      double? finalLng;

      // Extract GPS from EXIF if from gallery
      if (_isFromGallery && !_isVideo && _image != null) {
        try {
          final exif = await Exif.fromPath(_image!.path);
          final latLong = await exif.getLatLong();
          if (latLong != null) {
            finalLat = latLong.latitude;
            finalLng = latLong.longitude;
          }
          await exif.close();
        } catch (e) {
          debugPrint("Failed to parse EXIF: $e");
        }
      }

      // Fallback to current location if EXIF GPS is missing or it's a live capture
      if (finalLat == null || finalLng == null) {
        if (_draftLat != null && _draftLng != null) {
          finalLat = _draftLat;
          finalLng = _draftLng;
        } else {
          final locationResult = await LocationService.getCurrentLocation();
          if (locationResult.isSuccess) {
            finalLat = locationResult.position!.latitude;
            finalLng = locationResult.position!.longitude;
          } else {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(locationResult.error ?? 'Could not get location'),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }
        }
      }

      if (finalLat != null && finalLng != null) {
        // --- DUPLICATE CHECK ---
        setState(() => isLocating = true); // Ensure UI loading is visible if async ops happen
        final existingReports = await FirestoreService.getReportsByCategory(selectedCategory!);
        int duplicateCount = 0;
        for (var report in existingReports) {
          if (report['latitude'] != null && report['longitude'] != null) {
            double distance = Geolocator.distanceBetween(
              finalLat,
              finalLng,
              (report['latitude'] as num).toDouble(),
              (report['longitude'] as num).toDouble(),
            );
            if (distance <= 50) { // 50 meters radius
              duplicateCount++;
            }
          }
        }

        if (duplicateCount > 0) {
          if (!mounted) return;
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text("Duplicate Issue Detected!"),
                  ),
                ],
              ),
              content: Text(
                "Another '$selectedCategory' issue has already been reported within 50 meters of this exact location.\n\nNavigating back so you can Upvote the existing report on the Community Feed to boost its priority instead!",
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                  child: const Text("GOT IT"),
                ),
              ],
            ),
          );
          if (mounted) Navigator.pop(context); // Exit the report screen
          return;
        }
        // --- END DUPLICATE CHECK ---

        // 3. Permanent Media Storage
        final directory = await getApplicationDocumentsDirectory();
        String localMediaPath;

        if (_isVideo) {
          final String fileName = p.basename(_video!.path);
          final File localVideo = await File(_video!.path)
              .copy('${directory.path}/$fileName');
          localMediaPath = localVideo.path;
        } else {
          final String fileName = p.basename(_image!.path);
          final File localImage = await File(_image!.path)
              .copy('${directory.path}/$fileName');
          localMediaPath = localImage.path;
        }

        // 4. Resolve department for this category
        final deptInfo = _departmentMap[selectedCategory] ?? {
          'name': 'Municipal Authority',
          'abbr': 'Civic Dept.',
          'contact': '1800-000-0000',
          'priority': 'Low',
        };

        // 6. Save to Database (with department, user identity - without SLA)
        final currentUser = FirebaseAuthService.currentUser;
        final userDetails = await FirebaseAuthService.getCurrentUserDetails();
        final now = DateTime.now();
        final reportId = await FirestoreService.insertReportAndGetId({
          'category': selectedCategory,
          'description': _descriptionController.text.trim(),
          'latitude': finalLat,
          'longitude': finalLng,
          'imagePath': localMediaPath,
          'mediaType': _isVideo ? 'video' : 'image',
          'timestamp': now.toString(),
          'department': deptInfo['name'],
          'priority': selectedSeverity,
          'status': 'Reported',
          'statusHistory': {
            'Reported': now.toIso8601String(),
          },
          'upvotes': 0,
          'hasUpvoted': 0,
          'feedbackRating': 0,
          'feedbackMessage': '',
          'userId': currentUser?.uid ?? 'anonymous',
          'userName': userDetails?['name'] ?? 'A Citizen',
        });

        await FirestoreService.insertNotification("New Report Submitted", "Your report regarding $selectedCategory has been submitted and forwarded to ${deptInfo['abbr']}.");

        if (_draftReport != null) {
          await DraftService.deleteDraft(_draftReport!.id);
        }

        if (!mounted) return;
        _showSuccessSheet(
          dept: deptInfo,
          priority: selectedSeverity!,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => isLocating = false);
    }
  }


  void _showSuccessSheet({
    required Map<String, String> dept,
    required String priority,
  }) {
    final Color priorityColor = priority == 'High'
        ? const Color(0xFFE11D48)
        : (priority == 'Medium' ? const Color(0xFFD97706) : const Color(0xFF059669));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Handle Bar ──
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // ── Success Icon ──
            Container(
              width: 70, height: 70,
              decoration: const BoxDecoration(
                color: Color(0xFFDCFCE7),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded,
                  color: Color(0xFF059669), size: 40),
            ),
            const SizedBox(height: 12),
            Text('Complaint submitted successfully',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B))),
            Text('Awaiting Admin Review',
                style: GoogleFonts.poppins(
                    fontSize: 13, color: const Color(0xFF64748B))),
            const SizedBox(height: 20),

            // ── Resolution ETA Banner ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E293B), Color(0xFF334155)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          color: Color(0xFF38BDF8), size: 18),
                      const SizedBox(width: 8),
                      Text('Pending Admin Allocation',
                          style: GoogleFonts.poppins(
                              color: const Color(0xFF94A3B8),
                              fontSize: 12,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('Timeline will be updated shortly',
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: priorityColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: priorityColor.withValues(alpha: 0.5)),
                    ),
                    child: Text('$priority Priority',
                        style: GoogleFonts.poppins(
                            color: priorityColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── What Happens Next ──
            Align(
              alignment: Alignment.centerLeft,
              child: Text('What happens next',
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF64748B))),
            ),
            const SizedBox(height: 10),
            _nextStep(Icons.admin_panel_settings_rounded, const Color(0xFF8B5CF6),
                'Admin reviews your report and allocates timeline'),
            _nextStep(Icons.verified_rounded, const Color(0xFF3B82F6),
                'Officials visit and verify your report'),
            _nextStep(Icons.engineering_rounded, const Color(0xFFD97706),
                'Repair / maintenance work begins'),
            _nextStep(Icons.check_circle_rounded, const Color(0xFF059669),
                'Issue resolved & you are notified'),
            const SizedBox(height: 22),

            // ── Actions ──
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.home_rounded),
                label: Text('Back to Home',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600, fontSize: 15)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _nextStep(IconData icon, Color color, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: GoogleFonts.poppins(
                    fontSize: 13, color: const Color(0xFF334155))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("New Report"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButton<String>(
              isExpanded: true,
              value: selectedCategory,
              hint: const Text("Select Civic Issue"),
              items: categories
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (val) => setState(() => selectedCategory = val),
            ),
            const SizedBox(height: 15),
            DropdownButton<String>(
              isExpanded: true,
              value: selectedSeverity,
              hint: const Text("Select Severity Level"),
              items: severities
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (val) => setState(() => selectedSeverity = val),
            ),
            const SizedBox(height: 15),
            TextFormField(
              controller: _descriptionController,
              style: const TextStyle(color: Colors.black87),
              decoration: InputDecoration(
                hintText: "Describe the issue...",
                hintStyle: TextStyle(color: Colors.grey[600]),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: Colors.grey[200],
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 20),

            // ── MEDIA PREVIEW ──
            Container(
              height: 220,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: _isVideo && _video != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            color: const Color(0xFF1E293B),
                            child: Center(
                              child: Icon(Icons.videocam, color: Colors.white.withValues(alpha: 0.3), size: 80),
                            ),
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle, color: Colors.green, size: 40),
                              const SizedBox(height: 8),
                              Text(
                                'Video attached!',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                p.basename(_video!.path),
                                style: GoogleFonts.poppins(
                                  color: Colors.white60,
                                  fontSize: 11,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ],
                      ),
                    )
                  : !_isVideo && _image != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(File(_image!.path), fit: BoxFit.cover, width: double.infinity),
                        )
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate_outlined, size: 48, color: Colors.grey[600]),
                              const SizedBox(height: 8),
                              Text(
                                'Add a photo or video',
                                style: GoogleFonts.poppins(color: Colors.grey[700], fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
            ),
            const SizedBox(height: 12),

            // ── PHOTO BUTTONS ──
            Text('📷  Photo', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _takePhoto,
                    icon: const Icon(Icons.camera_alt, size: 18),
                    label: const Text("Camera"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _uploadPhoto,
                    icon: const Icon(Icons.photo_library, size: 18),
                    label: const Text("Gallery"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── VIDEO BUTTONS ──
            Text('🎥  Video (max 60s)', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _recordVideo,
                    icon: const Icon(Icons.videocam, size: 18),
                    label: const Text("Record"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _uploadVideo,
                    icon: const Icon(Icons.video_library, size: 18),
                    label: const Text("Gallery"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
            Row(
              children: [
                if (_draftReport == null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isLocating ? null : _saveToDrafts,
                      icon: const Icon(Icons.inventory_2_outlined),
                      label: const Text("Save Draft", style: TextStyle(fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                    ),
                  ),
                if (_draftReport == null) const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: isLocating ? null : handleReport,
                    icon: isLocating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.send),
                    label: Text(
                      isLocating ? "Processing..." : "Submit Report",
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
