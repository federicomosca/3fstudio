enum UserRole {
  gymOwner,
  trainer,
  client;

  static UserRole fromString(String value) => switch (value) {
        'owner'   => UserRole.gymOwner,
        'trainer' => UserRole.trainer,
        _         => UserRole.client,
      };

  String get dbValue => switch (this) {
        UserRole.gymOwner => 'owner',
        UserRole.trainer  => 'trainer',
        UserRole.client   => 'client',
      };

  int get priority => switch (this) {
        UserRole.gymOwner => 4,
        UserRole.trainer  => 2,
        UserRole.client   => 1,
      };
}

class AppRoles {
  final String? studioId;
  final Set<UserRole> studioRoles;

  const AppRoles({
    required this.studioId,
    required this.studioRoles,
  });

  factory AppRoles.empty() => const AppRoles(studioId: null, studioRoles: {});

  bool get isGymOwner => studioRoles.contains(UserRole.gymOwner);
  bool get isTrainer  => studioRoles.contains(UserRole.trainer);
  bool get isClient   => studioRoles.contains(UserRole.client);

  UserRole get primaryRole {
    if (studioRoles.isEmpty) return UserRole.client;
    return studioRoles.reduce((a, b) => a.priority >= b.priority ? a : b);
  }

  String get homeRoute => switch (primaryRole) {
        UserRole.gymOwner => '/owner/calendar',
        UserRole.trainer  => '/staff/calendar',
        UserRole.client   => '/client/calendar',
      };

  @override
  String toString() => 'AppRoles(studio=$studioId, roles=$studioRoles)';
}
