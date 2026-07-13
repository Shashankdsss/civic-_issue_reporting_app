import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../screens/chatbot_screen.dart'; // Import to use geminiApiKey

class ImageValidationService {
  /// Detects the category of the civic issue from the image automatically using Gemini vision API.
  static Future<String?> detectCategory(String imagePath) async {
    try {
      if (geminiApiKey == 'REPLACE_WITH_YOUR_GEMINI_API_KEY' || geminiApiKey.isEmpty) {
        return null;
      }
      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: geminiApiKey,
      );
      final imageBytes = await File(imagePath).readAsBytes();
      final prompt = TextPart(
          "Analyze this image and classify it into EXACTLY ONE of the following precise categories of civic issues: "
          "'Roads (Pothole)', 'Water Leakage', 'Garbage', 'Drainage', or 'Street Light'. "
          "If the image does not clearly depict any of these, respond EXACTLY with 'Uncategorized'. "
          "You must output ONLY the exact category string and nothing else. Do not use quotes."
      );
      final imageParts = [DataPart('image/jpeg', imageBytes)];
      final response = await model.generateContent([
        Content.multi([prompt, ...imageParts])
      ]);
      final resultText = response.text?.trim() ?? "Uncategorized";
      List<String> validCategories = ['Roads (Pothole)', 'Water Leakage', 'Garbage', 'Drainage', 'Street Light'];
      
      for (var cat in validCategories) {
        if (resultText.toLowerCase().contains(cat.toLowerCase())) {
          return cat;
        }
      }
      return 'Uncategorized';
    } catch (e) {
      return 'Uncategorized';
    }
  }

  /// Validates that the image matches the selected complaint category using Gemini Vision API.
  static Future<ValidationResult> validateImage(String imagePath, String category) async {
    try {
      if (geminiApiKey == 'REPLACE_WITH_YOUR_GEMINI_API_KEY' || geminiApiKey.isEmpty) {
        return ValidationResult(
          isValid: true, // Don't block user if API key isn't setup
          message: "Gemini API key not configured. Validation skipped.",
          detectedLabels: [],
        );
      }

      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: geminiApiKey,
      );

      final imageBytes = await File(imagePath).readAsBytes();
      
      final prompt = TextPart(
          "You are a strict AI validating a civic issue report. Does this image explicitly and clearly show the civic issue: '$category'? "
          "If it is an unrelated object (like an indoor setting, laptop, person, etc.), you MUST reject it. "
          "Respond with exactly 'YES' ONLY if it likely does show a '$category'. "
          "Otherwise, respond with 'NO' and what you see instead."
      );
          
      final imageParts = [
        DataPart('image/jpeg', imageBytes),
      ];

      final response = await model.generateContent([
        Content.multi([prompt, ...imageParts])
      ]);
      
      final resultText = response.text?.trim() ?? "NO";
      
      if (resultText.toUpperCase().startsWith("YES")) {
        return ValidationResult(
          isValid: true,
          message: "Photo verified using Gemini AI for $category",
          detectedLabels: [resultText],
        );
      } else {
        return ValidationResult(
          isValid: false,
          message: "AI Validation failed for '$category'. Reason: ${resultText.replaceAll('NO', '').trim()}",
          detectedLabels: [resultText],
        );
      }
    } catch (e) {
      String errorMessage = "Failed to connect to the Image Validation service.\nPlease check your internet connection and try again.";
      final errorString = e.toString();
      
      if (errorString.contains("503") || errorString.contains("high demand") || errorString.contains("UNAVAILABLE")) {
        errorMessage = "The AI Validation Service is currently experiencing high demand.\n\nPlease try submitting again in a few moments.";
      } else if (errorString.contains("quota") || errorString.contains("429")) {
        errorMessage = "The AI Validation Service quota has been reached. Please try again later.";
      } else {
        errorMessage = "An unexpected error occurred with the AI service.\n\nPlease try again later.";
      }

      return ValidationResult(
        isValid: false,
        message: errorMessage,
        detectedLabels: [],
      );
    }
  }
}

class ValidationResult {
  final bool isValid;
  final String message;
  final List<String> detectedLabels;
  final List<String>? matchedLabels;

  ValidationResult({
    required this.isValid,
    required this.message,
    required this.detectedLabels,
    this.matchedLabels,
  });
}
