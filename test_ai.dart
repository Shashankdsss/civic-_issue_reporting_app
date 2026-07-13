import 'package:google_generative_ai/google_generative_ai.dart';

void main() async {
  final apiKey = 'AIzaSyBiZwsaK3te5T2qNpCxPX94OFItUnXYTXM';
  final model = GenerativeModel(
    model: 'gemini-2.5-flash',
    apiKey: apiKey,
  );

  final prompt = TextPart("Test");
  try {
    final response = await model.generateContent([
      Content.multi([prompt])
    ]);
    print(response.text);
  } catch (e) {
    print(e.toString());
  }
}
