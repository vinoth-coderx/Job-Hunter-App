import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'location_service.dart';

/// Country-aware city/state autocomplete source for the profile editor.
///
/// Resolves the user's country once (via [LocationService.resolve] →
/// GPS + reverse geocode, with a session cache) and then serves
/// autocomplete results from a bundled JSON asset for that country.
/// India is the only country shipped today; everything else falls back
/// to "free-text only" with no suggestions, which the chip editor
/// already handles via the manual add button.
///
/// The JSON asset at `assets/data/india_locations.json` ships ~400
/// Indian cities + all 36 states/UTs + the three remote work modes —
/// big enough to feel "all of India" in the autocomplete without
/// dragging in a multi-MB country-state-city dataset.
class LocationsDataset {
  final String country;
  final String iso;
  final List<String> workModes;
  final List<String> states;
  final List<String> cities;
  final List<String> all;
  const LocationsDataset({
    required this.country,
    required this.iso,
    required this.workModes,
    required this.states,
    required this.cities,
  }) : all = const [];

  LocationsDataset._withAll({
    required this.country,
    required this.iso,
    required this.workModes,
    required this.states,
    required this.cities,
    required this.all,
  });
}

class LocationsDataService {
  LocationsDataService._();
  static final LocationsDataService instance = LocationsDataService._();

  LocationsDataset? _india;
  String? _resolvedIso;

  /// Resolves the dataset to use for the current user, lazy-loading the
  /// underlying JSON the first time it's needed. The reverse-geocode
  /// hit is best-effort — if it fails (no GPS, denied permission), we
  /// default to India because that's where the bulk of users come from.
  Future<LocationsDataset?> datasetForCurrentUser() async {
    final iso = await _detectCountryIso();
    if (iso == 'IN') return _loadIndia();
    return null;
  }

  /// Lower-level entry point for callers that already know the country
  /// (e.g. the search bar on the home tab) — skips the GPS hop.
  Future<LocationsDataset?> datasetFor(String iso) async {
    if (iso.toUpperCase() == 'IN') return _loadIndia();
    return null;
  }

  Future<String> _detectCountryIso() async {
    if (_resolvedIso != null) return _resolvedIso!;
    // Reuse the LocationService cache if a prior screen already
    // resolved location — otherwise resolve fresh. Either way the
    // country only needs to be detected once per session.
    final cached = LocationService.instance.cached;
    final result = cached ?? await LocationService.instance.resolve();
    final country = (result.country ?? '').trim().toLowerCase();
    String iso;
    if (country == 'india' || country == 'bharat') {
      iso = 'IN';
    } else if (country.isEmpty) {
      // Couldn't detect — fall back to India.
      iso = 'IN';
    } else {
      // Real country detected, but we only ship India data right now.
      // Returning the raw country code (or a marker) lets the caller
      // decide whether to attempt a per-country dataset later.
      iso = country.toUpperCase();
    }
    _resolvedIso = iso;
    return iso;
  }

  Future<LocationsDataset> _loadIndia() async {
    final cached = _india;
    if (cached != null) return cached;
    final raw =
        await rootBundle.loadString('assets/data/india_locations.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final workModes = _toStringList(json['workModes']);
    final states = _toStringList(json['states']);
    final cities = _toStringList(json['cities']);
    final all = <String>[...workModes, ...cities, ...states];
    final dataset = LocationsDataset._withAll(
      country: (json['country'] as String?) ?? 'India',
      iso: (json['iso'] as String?) ?? 'IN',
      workModes: List.unmodifiable(workModes),
      states: List.unmodifiable(states),
      cities: List.unmodifiable(cities),
      all: List.unmodifiable(all),
    );
    _india = dataset;
    return dataset;
  }

  static List<String> _toStringList(dynamic raw) {
    if (raw is List) {
      return raw.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
    }
    return const [];
  }

  /// Substring + prefix search across the dataset's combined list.
  /// Prefix matches rank ahead of substring matches so typing "ban"
  /// puts Bangalore above Aurangabad.
  static List<String> search(
    LocationsDataset dataset,
    String query, {
    int max = 8,
  }) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final prefix = <String>[];
    final contains = <String>[];
    for (final name in dataset.all) {
      final n = name.toLowerCase();
      if (n.startsWith(q)) {
        prefix.add(name);
      } else if (n.contains(q)) {
        contains.add(name);
      }
      if (prefix.length + contains.length >= max * 3) break;
    }
    return [...prefix, ...contains].take(max).toList();
  }
}
