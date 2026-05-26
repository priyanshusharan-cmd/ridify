import 'dart:convert';
import 'package:http/http.dart' as http;

class NominatimService {
  static Future<List<Map<String, dynamic>>> searchAddress(String query) async {
    if (query.isEmpty) return [];
    
    try {
      final url = "https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&addressdetails=1&limit=5";
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'Ridify-App/1.0'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        return data.map((e) => {
          'display_name': e['display_name'],
          'lat': double.parse(e['lat'].toString()),
          'lon': double.parse(e['lon'].toString()),
        }).toList();
      }
    } catch (e) {
      // Ignore errors
    }
    return [];
  }
}
