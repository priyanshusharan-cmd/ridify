import 'dart:convert';
import 'package:http/http.dart' as http;

class PlaceSearchException implements Exception {}

// Free, OSM-based place search. Photon (built for search-as-you-type, typo
// tolerant) is tried first; Nominatim is the fallback.
class PlaceSearchService {
  // Rough bounding box of India: minLon, minLat, maxLon, maxLat
  static const String _indiaBbox = '68.1,6.5,97.4,35.7';

  // Last location we know the user is near, used to rank nearby places first.
  static double? biasLat;
  static double? biasLon;

  static void setBias(double lat, double lon) {
    biasLat = lat;
    biasLon = lon;
  }

  // Each result: title, subtitle, display_name, lat, lon.
  // Throws PlaceSearchException when both providers fail.
  static Future<List<Map<String, dynamic>>> searchAddress(String query) async {
    query = query.trim();
    if (query.length < 3) return [];

    try {
      final results = await _searchPhoton(query);
      if (results.isNotEmpty) return results;
    } catch (_) {
      // Fall through to Nominatim
    }

    try {
      return await _searchNominatim(query);
    } catch (_) {
      throw PlaceSearchException();
    }
  }

  static Future<List<Map<String, dynamic>>> _searchPhoton(String query) async {
    final params = {
      'q': query,
      'limit': '8',
      'lang': 'en',
      'bbox': _indiaBbox,
      if (biasLat != null && biasLon != null) ...{
        'lat': '$biasLat',
        'lon': '$biasLon',
      },
    };
    final response = await http
        // Photon rejects Dart's default User-Agent
        .get(Uri.https('photon.komoot.io', '/api/', params), headers: {'User-Agent': 'Ridify-App/1.0'})
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) throw PlaceSearchException();

    final features = json.decode(response.body)['features'] as List;
    final seen = <String>{};
    final results = <Map<String, dynamic>>[];
    for (final f in features) {
      final p = f['properties'] as Map<String, dynamic>;
      final coords = f['geometry']['coordinates'] as List;

      final street = [p['housenumber'], p['street']].whereType<String>().join(' ');
      final title = (p['name'] ?? (street.isNotEmpty ? street : p['city'])) as String?;
      if (title == null) continue;

      final subtitle = <String?>[
        if (p['name'] != null && street.isNotEmpty) street,
        p['district'] ?? p['locality'],
        p['city'],
        p['state'],
      ].whereType<String>().where((s) => s != title).toSet().join(', ');

      // Photon often returns the same place several times (e.g. suburb + post office)
      if (!seen.add('$title|$subtitle')) continue;

      results.add({
        'title': title,
        'subtitle': subtitle,
        'display_name': subtitle.isEmpty ? title : '$title, $subtitle',
        'lat': (coords[1] as num).toDouble(),
        'lon': (coords[0] as num).toDouble(),
      });
    }
    return results;
  }

  static Future<List<Map<String, dynamic>>> _searchNominatim(String query) async {
    final params = {
      'q': query,
      'format': 'json',
      'addressdetails': '1',
      'limit': '8',
      'countrycodes': 'in',
      'accept-language': 'en',
      if (biasLat != null && biasLon != null)
        // ~50 km box around the user; preferred but not exclusive
        'viewbox': '${biasLon! - 0.5},${biasLat! + 0.5},${biasLon! + 0.5},${biasLat! - 0.5}',
    };
    final response = await http.get(
      Uri.https('nominatim.openstreetmap.org', '/search', params),
      headers: {'User-Agent': 'Ridify-App/1.0'},
    ).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) throw PlaceSearchException();

    final data = json.decode(response.body) as List;
    return data.map((e) {
      final displayName = e['display_name'] as String;
      final parts = displayName.split(', ');
      return {
        'title': parts.first,
        // Drop the trailing postcode/country noise
        'subtitle': parts.skip(1).where((s) => s != 'India' && int.tryParse(s) == null).take(3).join(', '),
        'display_name': displayName,
        'lat': double.parse(e['lat'].toString()),
        'lon': double.parse(e['lon'].toString()),
      };
    }).toList();
  }
}
