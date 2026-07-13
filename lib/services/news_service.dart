import 'dart:convert';
import 'package:http/http.dart' as http;

class NewsArticle {
  final String title;
  final String? description;
  final String? imageUrl;
  final String? sourceUrl;
  final String? sourceName;

  NewsArticle({
    required this.title,
    this.description,
    this.imageUrl,
    this.sourceUrl,
    this.sourceName,
  });

  factory NewsArticle.fromJson(Map<String, dynamic> json) {
    return NewsArticle(
      title: json['title'] ?? 'No title',
      description: json['description'],
      imageUrl: json['image_url'],
      sourceUrl: json['link'],
      sourceName: json['source_name'],
    );
  }
}

class NewsService {
  static const String _baseUrl = 'https://newsdata.io/api/1/news';
  static const String _apiKey = 'pub_71954f9a0c6a51d020e980302b13fa2ce01d8';
  static Future<List<NewsArticle>> fetchCivicNews() async {
    try {
      final uri = Uri.parse(
        '$_baseUrl?apikey=$_apiKey&q=pothole OR garbage OR civic OR infrastructure OR municipality&country=in&language=en&size=10',
      );

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];

        if (results.isEmpty) return _fallbackNews();

        return results.map((article) => NewsArticle.fromJson(article)).toList();
      } else {
        return _fallbackNews();
      }
    } catch (e) {
      return _fallbackNews();
    }
  }

  static List<NewsArticle> _fallbackNews() {
    return [
      NewsArticle(
        title: "Pune: Over 500 potholes reported on major roads this monsoon",
        description:
            "Citizens demand urgent action from corporation authorities.",
        sourceName: "Civic Connect",
      ),
      NewsArticle(
        title: "Garbage collection drives launched across 12 wards",
        description:
            "Municipal corporation ramps up daily waste management operations.",
        sourceName: "Civic Connect",
      ),
      NewsArticle(
        title: "Smart streetlight project to cover 10,000 poles by 2027",
        description: "LED upgrade initiative aims to cut energy usage by 40%.",
        sourceName: "Civic Connect",
      ),
      NewsArticle(
        title: "Water pipeline repairs to affect supply in 3 localities",
        description:
            "Residents advised to store water as maintenance work begins.",
        sourceName: "Civic Connect",
      ),
    ];
  }
}
