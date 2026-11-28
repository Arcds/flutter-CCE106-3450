enum UserRole { player, staff, owner }

enum ClubRole { owner, staff }

T _enumByName<T extends Enum>(List<T> values, Object? raw, T fallback) {
  for (final value in values) {
    if (value.name == raw) return value;
  }
  return fallback;
}

class AppUser {
  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    this.clubRoles = const {},
    this.fcmTokens = const [],
  });

  factory AppUser.fromMap(String uid, Map<String, dynamic> data) {
    final rawClubRoles = data['clubRoles'];
    final clubRoles = <String, ClubRole>{};
    if (rawClubRoles is Map) {
      rawClubRoles.forEach((key, value) {
        clubRoles['$key'] = _enumByName(ClubRole.values, value, ClubRole.staff);
      });
    }
    return AppUser(
      uid: uid,
      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      role: _enumByName(UserRole.values, data['role'], UserRole.player),
      clubRoles: clubRoles,
      fcmTokens: [
        for (final token in (data['fcmTokens'] as List<dynamic>? ?? const []))
          '$token',
      ],
    );
  }

  final String uid;
  final String name;
  final String email;
  final UserRole role;

  /// `{ facilityId: ClubRole }` — scopes staff access per club.
  final Map<String, ClubRole> clubRoles;
  final List<String> fcmTokens;

  bool get isStaff => role == UserRole.staff || role == UserRole.owner || clubRoles.isNotEmpty;

  bool manages(String facilityId) =>
      role == UserRole.owner || clubRoles.containsKey(facilityId);

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'role': role.name,
      'clubRoles': {
        for (final entry in clubRoles.entries) entry.key: entry.value.name,
      },
      'fcmTokens': fcmTokens,
    };
  }

  AppUser copyWith({
    String? name,
    String? email,
    UserRole? role,
    Map<String, ClubRole>? clubRoles,
    List<String>? fcmTokens,
  }) {
    return AppUser(
      uid: uid,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      clubRoles: clubRoles ?? this.clubRoles,
      fcmTokens: fcmTokens ?? this.fcmTokens,
    );
  }
}
