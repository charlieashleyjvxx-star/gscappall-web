class UserProfile {
  const UserProfile({
    required this.id,
    required this.nickname,
    required this.tagline,
    required this.createdAt,
    this.lastActiveAt,
    this.avatarSeed,
  });

  factory UserProfile.fromRow(Map<String, Object?>? row) {
    if (row == null) {
      return UserProfile(
        id: 1,
        nickname: '小诗童',
        tagline: '今天也和古诗做朋友',
        createdAt: DateTime.now(),
        lastActiveAt: DateTime.now(),
        avatarSeed: 'amber',
      );
    }

    return UserProfile(
      id: (row['id'] as int?) ?? 1,
      nickname: row['nickname'] as String? ?? '小诗童',
      tagline: row['tagline'] as String? ?? '今天也和古诗做朋友',
      createdAt:
          DateTime.tryParse(row['created_at'] as String? ?? '') ??
          DateTime.now(),
      lastActiveAt: DateTime.tryParse(row['last_active_at'] as String? ?? ''),
      avatarSeed: row['avatar_seed'] as String?,
    );
  }

  final int id;
  final String nickname;
  final String tagline;
  final DateTime createdAt;
  final DateTime? lastActiveAt;
  final String? avatarSeed;

  String get initial => nickname.trim().isEmpty ? '诗' : nickname.trim()[0];

  UserProfile copyWith({
    int? id,
    String? nickname,
    String? tagline,
    DateTime? createdAt,
    DateTime? lastActiveAt,
    String? avatarSeed,
  }) {
    return UserProfile(
      id: id ?? this.id,
      nickname: nickname ?? this.nickname,
      tagline: tagline ?? this.tagline,
      createdAt: createdAt ?? this.createdAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      avatarSeed: avatarSeed ?? this.avatarSeed,
    );
  }
}
