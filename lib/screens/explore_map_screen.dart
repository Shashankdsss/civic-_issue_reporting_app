import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/firestore_service.dart';
import '../services/location_service.dart';

class ExploreMapScreen extends StatefulWidget {
  const ExploreMapScreen({super.key});

  @override
  State<ExploreMapScreen> createState() => _ExploreMapScreenState();
}

class _ExploreMapScreenState extends State<ExploreMapScreen> {
  final MapController _mapController = MapController();
  LatLng _center = const LatLng(28.6139, 77.2090); // Default to New Delhi
  List<Marker> _markers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initMap();
  }

  Future<void> _initMap() async {
    // Try to get actual user location
    final posResult = await LocationService.getCurrentLocation();
    if (posResult.isSuccess && posResult.position != null) {
      if (mounted) {
        setState(() {
          _center = LatLng(posResult.position!.latitude, posResult.position!.longitude);
        });
      }
    }
    
    // Fetch issues and create markers
    final reports = await FirestoreService.getReports();
    List<Marker> newMarkers = [];
    
    // Add user location marker
    newMarkers.add(
      Marker(
        point: _center,
        width: 60,
        height: 60,
        child: const Icon(Icons.my_location, color: Colors.blue, size: 30),
      )
    );

    for (var report in reports) {
      double? lat = report['latitude'] is String ? double.tryParse(report['latitude']) : report['latitude'];
      double? lng = report['longitude'] is String ? double.tryParse(report['longitude']) : report['longitude'];
      
      // Fallback dummy location close to user for demonstration if DB lacks coordinates
      if (lat == null || lng == null) {
          final offsetLat = (reports.indexOf(report) % 5) * 0.005;
          final offsetLng = (reports.indexOf(report) % 5) * 0.004;
          lat = _center.latitude + offsetLat;
          lng = _center.longitude - offsetLng;
      }

      String category = report['category'] ?? 'Issue';
      Color pinColor = _getPinColor(category);

      newMarkers.add(
        Marker(
          point: LatLng(lat, lng),
          width: 50,
          height: 50,
          child: GestureDetector(
            onTap: () {
              showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                builder: (_) => _buildIssueDetails(report),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                color: pinColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
              ),
              child: const Icon(Icons.location_on, color: Colors.white, size: 24),
            ),
          ),
        )
      );
    }
    
    if (mounted) {
      setState(() {
        _markers = newMarkers;
        _isLoading = false;
      });
    }
  }

  Color _getPinColor(String category) {
    switch (category.toLowerCase()) {
      case 'roads': return Colors.red;
      case 'garbage': return Colors.green;
      case 'street light': return Colors.amber;
      case 'water': return Colors.blue;
      default: return Colors.orange;
    }
  }

  Widget _buildIssueDetails(Map<String, dynamic> report) {
    return Container(
      padding: const EdgeInsets.all(20),
      height: 300,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                report['category'] ?? "Unknown",
                style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: (report['status'] == 'Resolved') ? Colors.green : Colors.orange,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  report['status'] ?? "Pending",
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 12),
                ),
              )
            ],
          ),
          const SizedBox(height: 10),
          Text(report['description'] ?? "No description available", style: GoogleFonts.poppins(fontSize: 14)),
          const SizedBox(height: 20),
          report['imageUrl'] != null && report['imageUrl'].toString().startsWith('http')
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    report['imageUrl'],
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => Container(
                      height: 120,
                      width: double.infinity,
                      color: Colors.grey[200],
                      child: const Icon(Icons.broken_image, size: 40, color: Colors.grey),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("Live Urban Map", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.black87)),
        backgroundColor: Colors.white.withAlpha(200),
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 13.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.civicissue',
              ),
              MarkerLayer(
                markers: _markers,
              ),
            ],
          ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _mapController.move(_center, 15.0);
        },
        backgroundColor: Colors.white,
        child: const Icon(Icons.my_location, color: Colors.blue),
      ),
    );
  }
}
