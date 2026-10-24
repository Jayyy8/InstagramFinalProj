import "dart:convert";

import "package:geolocator/geolocator.dart";
import "package:http/http.dart" as http;

/// A place to tag on a post, story or note.
class Place {
  final String name;

  /// Town / province / country, for the second line in lists.
  final String detail;

  /// What gets saved and shown on the post, e.g. "Arayat, Pampanga".
  final String label;

  const Place({required this.name, required this.detail, required this.label});

  static Place? fromFeature(Map<String, dynamic> feature) {
    final p = (feature["properties"] as Map?)?.cast<String, dynamic>();
    if (p == null) return null;
    String? s(String key) {
      final v = p[key];
      return v is String && v.trim().isNotEmpty ? v.trim() : null;
    }

    final name = s("name") ?? s("street") ?? s("city");
    if (name == null) return null;
    // The closest bigger area that isn't the place itself.
    final area = [
      s("city"),
      s("county"),
      s("state"),
      s("country"),
    ].firstWhere((a) => a != null && a != name, orElse: () => null);
    final parts = <String>[];
    for (final part in [
      s("district"),
      s("city"),
      s("county"),
      s("state"),
      s("country"),
    ]) {
      if (part != null && part != name && !parts.contains(part)) {
        parts.add(part);
      }
    }
    return Place(
      name: name,
      detail: parts.join(", "),
      label: area == null ? name : "$name, $area",
    );
  }
}

/// Place search with Photon (OpenStreetMap data, free, no key) and the
/// phone's location for "nearby" suggestions.
class LocationService {
  static const _host = "photon.komoot.io";
  static const _userAgent = "InstagramReplica/1.0 (student project; Flutter)";

  /// Where the phone was last found (biases search results).
  static Position? _lastPosition;

  /// Nearby places already looked up during this app run.
  static List<Place>? _nearby;
  static List<Place>? get cachedNearby => _nearby;

  static Future<List<Place>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final pos = _lastPosition;
    final uri = Uri.https(_host, "/api/", {
      "q": q,
      "limit": "20",
      "lat": ?pos?.latitude.toString(),
      "lon": ?pos?.longitude.toString(),
    });
    return _places(uri);
  }

  static Future<List<Map<String, dynamic>>> _features(Uri uri) async {
    // Photon refuses the default "Dart/…" client name; its usage policy
    // asks apps to say who they are.
    final response = await http
        .get(uri, headers: const {"User-Agent": _userAgent})
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw Exception("Place search failed (${response.statusCode}).");
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return [
      for (final f in (data["features"] as List? ?? const []))
        if (f is Map) f.cast<String, dynamic>(),
    ];
  }

  static List<Place> _toPlaces(List<Map<String, dynamic>> features) {
    final seen = <String>{};
    return [
      for (final f in features)
        if (Place.fromFeature(f) case final place?)
          if (seen.add(place.label)) place,
    ];
  }

  static Future<List<Place>> _places(Uri uri) async =>
      _toPlaces(await _features(uri));

  /// Whether the app may already read the location (never asks).
  static Future<bool> allowed() async {
    try {
      final p = await Geolocator.checkPermission();
      return p == LocationPermission.always ||
          p == LocationPermission.whileInUse;
    } catch (_) {
      return false;
    }
  }

  /// Asks for location access if needed and finds the phone.
  /// Returns null with a reason when it can't.
  static Future<(Position?, String?)> locate() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return (null, "Turn on Location in your phone's settings.");
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return (
          null,
          "Location access is off for this app. Allow it in your phone's "
              "settings to see places near you.",
        );
      }
      if (permission == LocationPermission.denied) {
        return (null, "Location access wasn't allowed.");
      }
      final position =
          await Geolocator.getLastKnownPosition() ??
          await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.low,
              timeLimit: Duration(seconds: 15),
            ),
          );
      _lastPosition = position;
      return (position, null);
    } catch (_) {
      return (null, "Couldn't find your location. Try again.");
    }
  }

  static Future<void> openSettings() => Geolocator.openAppSettings();

  /// Your town and places around you, like Instagram's suggestions.
  static Future<List<Place>> nearby(Position pos) async {
    final cached = _nearby;
    if (cached != null) return cached;
    final uri = Uri.https(_host, "/reverse", {
      "lat": pos.latitude.toString(),
      "lon": pos.longitude.toString(),
      "limit": "20",
      "radius": "2",
    });
    final features = await _features(uri);
    final spots = _toPlaces(features);

    // Areas first ("Arayat, Pampanga", "Pampanga"), then spots near you.
    final areas = <Place>[];
    if (features.isNotEmpty) {
      final p = (features.first["properties"] as Map?) ?? const {};
      final city = p["city"] as String?;
      final county = p["county"] as String?;
      final state = p["state"] as String?;
      final country = p["country"] as String?;
      final region = county ?? state;
      if (city != null) {
        areas.add(
          Place(
            name: city,
            detail: [?region, ?country].join(", "),
            label: region == null || region == city ? city : "$city, $region",
          ),
        );
      }
      if (region != null) {
        areas.add(Place(name: region, detail: country ?? "", label: region));
      }
    }
    final seen = <String>{};
    final result = [
      for (final p in [...areas, ...spots])
        if (seen.add(p.label)) p,
    ];
    _nearby = result;
    return result;
  }
}
