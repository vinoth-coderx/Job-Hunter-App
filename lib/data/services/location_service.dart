import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

/// Result of a location lookup. Distinguishes the "permission denied" /
/// "service off" / "no signal" cases so the UI can react appropriately:
/// e.g. fall back to profile preferredLocations only when permission was
/// granted but lookup failed, vs. show a "Turn on location" hint when
/// the user explicitly denied.
enum LocationStatus {
  ok,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  failed,
}

class LocationResult {
  final LocationStatus status;
  final String? city;
  final String? region;
  final String? country;
  final double? latitude;
  final double? longitude;

  const LocationResult({
    required this.status,
    this.city,
    this.region,
    this.country,
    this.latitude,
    this.longitude,
  });

  bool get isOk => status == LocationStatus.ok && (city ?? '').isNotEmpty;

  /// Human-readable label suitable for "Jobs in `<city>`". Prefers the most
  /// specific locality available — locality (city) > subAdministrativeArea
  /// (district) > administrativeArea (region/state).
  String? get label {
    final parts = <String>[
      if ((city ?? '').isNotEmpty) city!,
      if ((region ?? '').isNotEmpty && region != city) region!,
    ];
    return parts.isEmpty ? null : parts.first;
  }
}

class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  // Session cache. Reverse-geocoding is a relatively expensive call and
  // the user's city won't change mid-session in any normal flow, so we
  // hold onto the first successful result.
  LocationResult? _cached;

  LocationResult? get cached => _cached;

  /// Ask for permission, get coords, reverse-geocode. Returns a structured
  /// `LocationResult` rather than throwing — callers can branch on
  /// `status` to decide whether to surface an error or fall back silently.
  Future<LocationResult> resolve({bool force = false}) async {
    if (!force && _cached != null && _cached!.isOk) return _cached!;
    try {
      final serviceOn = await Geolocator.isLocationServiceEnabled();
      if (!serviceOn) {
        return _cache(const LocationResult(
          status: LocationStatus.serviceDisabled,
        ));
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return _cache(const LocationResult(
          status: LocationStatus.permissionDeniedForever,
        ));
      }
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return _cache(const LocationResult(
          status: LocationStatus.permissionDenied,
        ));
      }

      // Coarse accuracy is enough for a city-level filter and saves
      // battery / time-to-first-fix vs. high accuracy.
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 8),
        ),
      );

      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isEmpty) {
        return _cache(LocationResult(
          status: LocationStatus.failed,
          latitude: position.latitude,
          longitude: position.longitude,
        ));
      }
      final p = placemarks.first;
      final city = (p.locality?.isNotEmpty ?? false)
          ? p.locality
          : (p.subAdministrativeArea?.isNotEmpty ?? false)
              ? p.subAdministrativeArea
              : p.administrativeArea;
      return _cache(LocationResult(
        status: LocationStatus.ok,
        city: city,
        region: p.administrativeArea,
        country: p.country,
        latitude: position.latitude,
        longitude: position.longitude,
      ));
    } catch (e, st) {
      if (kDebugMode) debugPrint('LocationService.resolve failed: $e\n$st');
      return _cache(const LocationResult(status: LocationStatus.failed));
    }
  }

  LocationResult _cache(LocationResult r) {
    _cached = r;
    return r;
  }

  void clearCache() => _cached = null;
}
