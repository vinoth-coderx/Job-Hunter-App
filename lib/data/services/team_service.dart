import 'api_client.dart';

class TeamMember {
  final String? userId;
  final String? email;
  final String? fullName;
  final String? avatar;
  final String role;
  final DateTime? addedAt;

  const TeamMember({
    this.userId,
    this.email,
    this.fullName,
    this.avatar,
    required this.role,
    this.addedAt,
  });

  factory TeamMember.fromJson(Map<String, dynamic> j) => TeamMember(
        userId: j['userId'] as String?,
        email: j['email'] as String?,
        fullName: j['fullName'] as String?,
        avatar: j['avatar'] as String?,
        role: (j['role'] ?? 'recruiter').toString(),
        addedAt: j['addedAt'] == null
            ? null
            : DateTime.tryParse(j['addedAt'].toString()),
      );
}

class PendingInvite {
  final String email;
  final String role;
  final DateTime? expiresAt;
  final DateTime? invitedAt;
  const PendingInvite({
    required this.email,
    required this.role,
    this.expiresAt,
    this.invitedAt,
  });
  factory PendingInvite.fromJson(Map<String, dynamic> j) => PendingInvite(
        email: (j['email'] ?? '').toString(),
        role: (j['role'] ?? 'recruiter').toString(),
        expiresAt: j['expiresAt'] == null
            ? null
            : DateTime.tryParse(j['expiresAt'].toString()),
        invitedAt: j['invitedAt'] == null
            ? null
            : DateTime.tryParse(j['invitedAt'].toString()),
      );
}

class TeamSnapshot {
  final String ownerUserId;
  final List<TeamMember> members;
  final List<PendingInvite> pendingInvites;
  const TeamSnapshot({
    required this.ownerUserId,
    required this.members,
    required this.pendingInvites,
  });
  factory TeamSnapshot.fromJson(Map<String, dynamic> j) => TeamSnapshot(
        ownerUserId: (j['ownerUserId'] ?? '').toString(),
        members: (j['members'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .map(TeamMember.fromJson)
                .toList() ??
            const [],
        pendingInvites: (j['pendingInvites'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .map(PendingInvite.fromJson)
                .toList() ??
            const [],
      );
}

class TeamInvitePayload {
  final String id;
  final String email;
  final String role;
  final String token;
  final DateTime? expiresAt;
  const TeamInvitePayload({
    required this.id,
    required this.email,
    required this.role,
    required this.token,
    this.expiresAt,
  });
  factory TeamInvitePayload.fromJson(Map<String, dynamic> j) =>
      TeamInvitePayload(
        id: (j['id'] ?? '').toString(),
        email: (j['email'] ?? '').toString(),
        role: (j['role'] ?? 'recruiter').toString(),
        token: (j['token'] ?? '').toString(),
        expiresAt: j['expiresAt'] == null
            ? null
            : DateTime.tryParse(j['expiresAt'].toString()),
      );
}

class TeamService {
  TeamService._();
  static final TeamService instance = TeamService._();
  final ApiClient _api = ApiClient.instance;

  Future<TeamSnapshot> snapshot() async {
    final raw = await _api.get('hirer/team');
    return TeamSnapshot.fromJson(ApiClient.unwrapMap(raw));
  }

  Future<TeamInvitePayload> invite({
    required String email,
    required String role,
  }) async {
    final raw = await _api.post('hirer/team/invite', body: {
      'email': email,
      'role': role,
    });
    return TeamInvitePayload.fromJson(ApiClient.unwrapMap(raw));
  }

  Future<({String hirerProfileId, String companyName, String role})> accept(
      String token) async {
    final raw = await _api.post('hirer/team/accept', body: {'token': token});
    final m = ApiClient.unwrapMap(raw);
    return (
      hirerProfileId: (m['hirerProfileId'] ?? '').toString(),
      companyName: (m['companyName'] ?? '').toString(),
      role: (m['role'] ?? '').toString(),
    );
  }

  Future<void> remove(String userId) =>
      _api.delete('hirer/team/members/$userId');

  Future<void> changeRole({required String userId, required String role}) =>
      _api.put('hirer/team/members/$userId/role', body: {'role': role});
}
