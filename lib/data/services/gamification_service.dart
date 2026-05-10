import 'api_client.dart';

class StreakInfo {
  final int streakCount;
  final int longestStreak;
  final DateTime? lastCheckinDate;
  final bool checkedInToday;

  const StreakInfo({
    required this.streakCount,
    required this.longestStreak,
    this.lastCheckinDate,
    required this.checkedInToday,
  });

  factory StreakInfo.fromJson(Map<String, dynamic> j) => StreakInfo(
        streakCount: (j['streakCount'] as num?)?.toInt() ?? 0,
        longestStreak: (j['longestStreak'] as num?)?.toInt() ?? 0,
        lastCheckinDate: j['lastCheckinDate'] == null
            ? null
            : DateTime.tryParse(j['lastCheckinDate'].toString()),
        checkedInToday: j['checkedInToday'] as bool? ?? false,
      );
}

class CheckInResult {
  final int streakCount;
  final int longestStreak;
  final bool streakChanged;
  const CheckInResult({
    required this.streakCount,
    required this.longestStreak,
    required this.streakChanged,
  });
  factory CheckInResult.fromJson(Map<String, dynamic> j) => CheckInResult(
        streakCount: (j['streakCount'] as num?)?.toInt() ?? 0,
        longestStreak: (j['longestStreak'] as num?)?.toInt() ?? 0,
        streakChanged: j['streakChanged'] as bool? ?? false,
      );
}

class ServerBadge {
  final String id;
  final String title;
  final String description;
  final String category;
  final bool unlocked;
  const ServerBadge({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.unlocked,
  });
  factory ServerBadge.fromJson(Map<String, dynamic> j) => ServerBadge(
        id: (j['id'] ?? '').toString(),
        title: (j['title'] ?? '').toString(),
        description: (j['description'] ?? '').toString(),
        category: (j['category'] ?? '').toString(),
        unlocked: j['unlocked'] as bool? ?? false,
      );
}

class BadgesSnapshot {
  final int total;
  final int unlocked;
  final List<ServerBadge> badges;
  const BadgesSnapshot({
    required this.total,
    required this.unlocked,
    required this.badges,
  });
  factory BadgesSnapshot.fromJson(Map<String, dynamic> j) => BadgesSnapshot(
        total: (j['total'] as num?)?.toInt() ?? 0,
        unlocked: (j['unlocked'] as num?)?.toInt() ?? 0,
        badges: (j['badges'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .map(ServerBadge.fromJson)
                .toList() ??
            const [],
      );
}

class GamificationService {
  GamificationService._();
  static final GamificationService instance = GamificationService._();
  final ApiClient _api = ApiClient.instance;

  Future<StreakInfo> getStreak() async {
    final raw = await _api.get('seeker/streak');
    return StreakInfo.fromJson(ApiClient.unwrapMap(raw));
  }

  Future<CheckInResult> checkIn() async {
    final raw = await _api.post('seeker/streak/checkin');
    return CheckInResult.fromJson(ApiClient.unwrapMap(raw));
  }

  Future<BadgesSnapshot> badges() async {
    final raw = await _api.get('seeker/badges');
    return BadgesSnapshot.fromJson(ApiClient.unwrapMap(raw));
  }
}
