enum UserRole {
  admin,
  gymOwner,
  classOwner,
  trainer,
  client;

  static UserRole fromString(String value) => switch (value) {
        'admin'       => UserRole.admin,
        'owner'       => UserRole.gymOwner,
        'class_owner' => UserRole.classOwner,
        'trainer'     => UserRole.trainer,
        _             => UserRole.client,
      };

  String get dbValue => switch (this) {
        UserRole.admin      => 'admin',
        UserRole.gymOwner   => 'owner',
        UserRole.classOwner => 'class_owner',
        UserRole.trainer    => 'trainer',
        UserRole.client     => 'client',
      };

  int get priority => switch (this) {
        UserRole.admin      => 5,
        UserRole.gymOwner   => 4,
        UserRole.classOwner => 3,
        UserRole.trainer    => 2,
        UserRole.client     => 1,
      };
}

/// Ruoli dell'utente corrente in uno studio.
class AppRoles {
  final bool isAdmin;
  final String? studioId;
  final Set<UserRole> studioRoles;

  const AppRoles({
    required this.isAdmin,
    required this.studioId,
    required this.studioRoles,
  });

  factory AppRoles.empty() => const AppRoles(
        isAdmin: false,
        studioId: null,
        studioRoles: {},
      );

  bool get isGymOwner   => studioRoles.contains(UserRole.gymOwner);
  bool get isClassOwner => studioRoles.contains(UserRole.classOwner);
  bool get isTrainer    => studioRoles.contains(UserRole.trainer);
  bool get isClient     => studioRoles.contains(UserRole.client);

  /// Ruolo primario (più alto privilegio).
  UserRole get primaryRole {
    if (isAdmin) return UserRole.admin;
    if (studioRoles.isEmpty) return UserRole.client;
    return studioRoles.reduce(
      (a, b) => a.priority >= b.priority ? a : b,
    );
  }

  String get homeRoute => switch (primaryRole) {
        UserRole.admin      => '/admin/dashboard',
        UserRole.gymOwner   => '/owner/calendar',
        UserRole.classOwner => '/staff/calendar',
        UserRole.trainer    => '/staff/calendar',
        UserRole.client     => '/client/calendar',
      };

  @override
  String toString() =>
      'AppRoles(admin=$isAdmin, studio=$studioId, roles=$studioRoles)';
}
