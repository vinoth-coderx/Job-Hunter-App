import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';

/// A single saved search — keyword, filters, sort, optional location.
/// Same shape covers both "recent" (auto-recorded) and "saved" (named,
/// kept until removed).
class SavedSearch {
  final String query;
  final List<String> filters;
  final String? location;
  final String sort;
  final String? label;
  final DateTime savedAt;

  const SavedSearch({
    required this.query,
    this.filters = const [],
    this.location,
    this.sort = 'mostRelevant',
    this.label,
    required this.savedAt,
  });

  String get displayLabel {
    if (label != null && label!.isNotEmpty) return label!;
    if (query.isNotEmpty) return query;
    if (filters.isNotEmpty) return filters.join(' · ');
    return 'All jobs';
  }

  String get summary {
    final parts = <String>[];
    if (location != null && location!.isNotEmpty) parts.add(location!);
    if (filters.isNotEmpty) parts.add('${filters.length} filter${filters.length == 1 ? '' : 's'}');
    return parts.join(' · ');
  }

  /// Equality on the search inputs only — `savedAt` and `label` aren't
  /// part of identity, so the same query+filters dedupes cleanly in the
  /// recent list.
  String get fingerprint {
    final f = (List<String>.from(filters)..sort()).join(',');
    return '$query|${location ?? ''}|$f|$sort';
  }

  Map<String, dynamic> toJson() => {
        'query': query,
        'filters': filters,
        'location': location,
        'sort': sort,
        'label': label,
        'savedAt': savedAt.toIso8601String(),
      };

  factory SavedSearch.fromJson(Map<String, dynamic> j) => SavedSearch(
        query: (j['query'] ?? '').toString(),
        filters:
            (j['filters'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        location: j['location'] as String?,
        sort: (j['sort'] ?? 'mostRelevant').toString(),
        label: j['label'] as String?,
        savedAt: DateTime.tryParse((j['savedAt'] ?? '').toString()) ??
            DateTime.now(),
      );
}

/// Local persistence for recent + saved searches. All data here is the
/// user's own input; nothing mocked, nothing fetched.
class SearchHistoryService {
  static const int _recentLimit = 8;

  static Future<SharedPreferences> _prefs() async =>
      SharedPreferences.getInstance();

  // ---- Recent (auto-recorded) ----

  static Future<List<SavedSearch>> getRecent() async {
    final raw = (await _prefs()).getStringList(AppConstants.keyRecentSearches) ??
        const <String>[];
    return _decodeList(raw);
  }

  /// Push a search to the front of the recent list, deduped by fingerprint
  /// and capped at `_recentLimit`. Skipped silently when there's nothing
  /// to remember (empty query AND no filters).
  static Future<void> recordRecent(SavedSearch s) async {
    if (s.query.trim().isEmpty && s.filters.isEmpty) return;
    final list = await getRecent();
    list.removeWhere((e) => e.fingerprint == s.fingerprint);
    list.insert(0, s);
    while (list.length > _recentLimit) {
      list.removeLast();
    }
    await (await _prefs())
        .setStringList(AppConstants.keyRecentSearches, _encodeList(list));
  }

  static Future<void> clearRecent() async {
    await (await _prefs()).remove(AppConstants.keyRecentSearches);
  }

  static Future<void> removeRecent(SavedSearch s) async {
    final list = await getRecent();
    list.removeWhere((e) => e.fingerprint == s.fingerprint);
    await (await _prefs())
        .setStringList(AppConstants.keyRecentSearches, _encodeList(list));
  }

  // ---- Saved (named, persistent until removed) ----

  static Future<List<SavedSearch>> getSaved() async {
    final raw = (await _prefs()).getStringList(AppConstants.keySavedSearches) ??
        const <String>[];
    return _decodeList(raw);
  }

  static Future<void> save(SavedSearch s) async {
    final list = await getSaved();
    list.removeWhere((e) => e.fingerprint == s.fingerprint);
    list.insert(0, s);
    await (await _prefs())
        .setStringList(AppConstants.keySavedSearches, _encodeList(list));
  }

  static Future<void> removeSaved(SavedSearch s) async {
    final list = await getSaved();
    list.removeWhere((e) => e.fingerprint == s.fingerprint);
    await (await _prefs())
        .setStringList(AppConstants.keySavedSearches, _encodeList(list));
  }

  static Future<bool> isSaved(SavedSearch s) async {
    final list = await getSaved();
    return list.any((e) => e.fingerprint == s.fingerprint);
  }

  // ---- helpers ----

  static List<SavedSearch> _decodeList(List<String> raw) {
    final out = <SavedSearch>[];
    for (final s in raw) {
      try {
        out.add(SavedSearch.fromJson(jsonDecode(s) as Map<String, dynamic>));
      } catch (_) {/* drop a corrupted entry, keep going */}
    }
    return out;
  }

  static List<String> _encodeList(List<SavedSearch> list) =>
      list.map((e) => jsonEncode(e.toJson())).toList();
}
