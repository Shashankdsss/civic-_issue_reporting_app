import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class DraftReport {
  final String id;
  final String category;
  final String description;
  final String mediaPath;
  final String mediaType;
  final double latitude;
  final double longitude;
  final String timestamp;

  DraftReport({
    required this.id,
    required this.category,
    required this.description,
    required this.mediaPath,
    required this.mediaType,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category': category,
      'description': description,
      'mediaPath': mediaPath,
      'mediaType': mediaType,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp,
    };
  }

  factory DraftReport.fromJson(Map<String, dynamic> json) {
    return DraftReport(
      id: json['id'],
      category: json['category'],
      description: json['description'] ?? '',
      mediaPath: json['mediaPath'] ?? json['imagePath'] ?? '',
      mediaType: json['mediaType'] ?? 'image',
      latitude: json['latitude'],
      longitude: json['longitude'],
      timestamp: json['timestamp'],
    );
  }
}

class DraftService {
  static const String _fileName = 'drafts.json';

  static Future<File> _getFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_fileName');
  }

  static Future<List<DraftReport>> getDrafts() async {
    try {
      final file = await _getFile();
      if (!await file.exists()) {
        return [];
      }
      final contents = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(contents);
      return jsonList.map((json) => DraftReport.fromJson(json)).toList();
    } catch (e) {
      print("Error reading drafts: $e");
      return [];
    }
  }

  static Future<void> saveDraft(DraftReport draft) async {
    try {
      final drafts = await getDrafts();
      final index = drafts.indexWhere((d) => d.id == draft.id);
      if (index >= 0) {
        drafts[index] = draft;
      } else {
        drafts.add(draft);
      }
      final file = await _getFile();
      final jsonList = drafts.map((d) => d.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));
    } catch (e) {
      print("Error saving draft: $e");
    }
  }

  static Future<void> deleteDraft(String id) async {
    try {
      final drafts = await getDrafts();
      final draftIndex = drafts.indexWhere((d) => d.id == id);
      
      if (draftIndex >= 0) {
        final draft = drafts[draftIndex];
        // Try to delete the local media file as well
        try {
          final file = File(draft.mediaPath);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          print("Error deleting draft media file: $e");
        }

        drafts.removeAt(draftIndex);
        final file = await _getFile();
        final jsonList = drafts.map((d) => d.toJson()).toList();
        await file.writeAsString(jsonEncode(jsonList));
      }
    } catch (e) {
      print("Error deleting draft: $e");
    }
  }
}
