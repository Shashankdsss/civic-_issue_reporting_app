class AadhaarValidator {
  // Verhoeff multiplication table
  static const List<List<int>> _d = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
    [1, 2, 3, 4, 0, 6, 7, 8, 9, 5],
    [2, 3, 4, 0, 1, 7, 8, 9, 5, 6],
    [3, 4, 0, 1, 2, 8, 9, 5, 6, 7],
    [4, 0, 1, 2, 3, 9, 5, 6, 7, 8],
    [5, 9, 8, 7, 6, 0, 4, 3, 2, 1],
    [6, 5, 9, 8, 7, 1, 0, 4, 3, 2],
    [7, 6, 5, 9, 8, 2, 1, 0, 4, 3],
    [8, 7, 6, 5, 9, 3, 2, 1, 0, 4],
    [9, 8, 7, 6, 5, 4, 3, 2, 1, 0],
  ];

  // Verhoeff permutation table
  static const List<List<int>> _p = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
    [1, 5, 7, 6, 2, 8, 3, 0, 9, 4],
    [5, 8, 0, 3, 7, 9, 6, 1, 4, 2],
    [8, 9, 1, 6, 0, 4, 3, 5, 2, 7],
    [9, 4, 5, 3, 1, 2, 6, 8, 7, 0],
    [4, 2, 8, 6, 5, 7, 3, 9, 0, 1],
    [2, 7, 9, 3, 8, 0, 6, 4, 1, 5],
    [7, 0, 4, 6, 9, 1, 3, 2, 5, 8],
  ];

  /// Validates Aadhaar number using format rules + Verhoeff checksum.
  /// Returns a [AadhaarValidationResult] with status and message.
  static AadhaarValidationResult validate(String input) {
    // Remove spaces or dashes (user-friendly input like "2345 6789 0123")
    final cleaned = input.replaceAll(RegExp(r'[\s\-]'), '');

    // Rule 1: Must be exactly 12 digits
    if (cleaned.isEmpty) {
      return AadhaarValidationResult(
        isValid: false,
        message: 'Please enter your Aadhaar number',
        cleanedNumber: cleaned,
      );
    }

    if (!RegExp(r'^\d+$').hasMatch(cleaned)) {
      return AadhaarValidationResult(
        isValid: false,
        message: 'Aadhaar number must contain digits only',
        cleanedNumber: cleaned,
      );
    }

    if (cleaned.length != 12) {
      return AadhaarValidationResult(
        isValid: false,
        message: 'Aadhaar number must be exactly 12 digits (entered: ${cleaned.length})',
        cleanedNumber: cleaned,
      );
    }

    // Rule 2: Cannot start with 0 or 1 (UIDAI rule)
    if (cleaned[0] == '0' || cleaned[0] == '1') {
      return AadhaarValidationResult(
        isValid: false,
        message: 'Invalid Aadhaar number — cannot start with 0 or 1',
        cleanedNumber: cleaned,
      );
    }

    // Rule 3: Cannot be all same digits (e.g., 111111111111)
    if (RegExp(r'^(\d)\1{11}$').hasMatch(cleaned)) {
      return AadhaarValidationResult(
        isValid: false,
        message: 'Invalid Aadhaar number — all digits are same',
        cleanedNumber: cleaned,
      );
    }

    // Rule 4: Verhoeff checksum (mathematical validity check)
    if (!_verhoeffCheck(cleaned)) {
      return AadhaarValidationResult(
        isValid: false,
        message: 'Invalid Aadhaar number — checksum failed',
        cleanedNumber: cleaned,
      );
    }

    return AadhaarValidationResult(
      isValid: true,
      message: 'Valid Aadhaar number ✓',
      cleanedNumber: cleaned,
    );
  }

  /// Runs the Verhoeff checksum algorithm.
  /// A valid Aadhaar number always produces checksum = 0.
  static bool _verhoeffCheck(String number) {
    int c = 0;
    final digits = number.split('').reversed.map(int.parse).toList();
    for (int i = 0; i < digits.length; i++) {
      c = _d[c][_p[i % 8][digits[i]]];
    }
    return c == 0;
  }
}

class AadhaarValidationResult {
  final bool isValid;
  final String message;
  final String cleanedNumber;

  AadhaarValidationResult({
    required this.isValid,
    required this.message,
    required this.cleanedNumber,
  });
}
