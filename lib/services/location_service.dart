import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationService {
  /// Returns the current GPS position, or null with a reason string if it fails.
  static Future<LocationResult> getCurrentLocation() async {
    try {
      // 1. Check if GPS hardware is on
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return LocationResult(
          position: null,
          error: 'GPS is turned off. Please enable Location in phone Settings.',
        );
      }

      // 2. Check / request permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return LocationResult(
            position: null,
            error: 'Location permission denied. Please allow it and try again.',
          );
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return LocationResult(
          position: null,
          error:
              'Location permission permanently denied. Go to App Settings → Permissions → Location and allow it.',
        );
      }

      // 3. Try to get the last known position first as a fallback
      Position? position;
      try {
        position = await Geolocator.getLastKnownPosition();
      } catch (_) {}

      // 4. Try to fetch the current fresh position
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 8),
        );
      } catch (e) {
        if (position == null) {
          rethrow; // Throw to the outer catch if we have NO fallback
        }
      }

      return LocationResult(position: position, error: null);
    } on LocationServiceDisabledException {
      return LocationResult(
        position: null,
        error: 'GPS is disabled. Please turn on Location from Settings.',
      );
    } catch (e) {
      print("Location fetch error: $e"); // Log the exact error for debugging
      return LocationResult(
        position: null,
        error: 'Could not detect location. Make sure GPS is actively on, or tap to retry.',
      );
    }
  }

  /// Opens the device Location Settings page so the user can enable GPS.
  static Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }

  /// Opens the app's permission settings page.
  static Future<void> openAppSettings() async {
    await Geolocator.openAppSettings();
  }

  /// Converts coordinates into a human readable address (City, State).
  static Future<String?> getAddressFromLocation(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        String city = place.locality ?? place.subAdministrativeArea ?? 'Unknown City';
        String state = place.administrativeArea ?? 'Unknown State';
        
        // Handle short state names if needed or just return standard
        if (state.length > 2) {
          // Keep it brief for UI if we have a known state string
          if (state.toLowerCase().contains("maharashtra")) state = "MH";
          else if (state.toLowerCase().contains("karnataka")) state = "KA";
          else if (state.toLowerCase().contains("delhi")) state = "DL";
          else if (state.toLowerCase().contains("gujarat")) state = "GJ";
          // We can fallback to the full state name otherwise
        }
        
        return "$city, $state";
      }
    } catch (e) {
      // Ignored
    }
    return null;
  }
}

class LocationResult {
  final Position? position;
  final String? error;

  LocationResult({required this.position, required this.error});

  bool get isSuccess => position != null;
}
