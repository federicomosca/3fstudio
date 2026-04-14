class UserProfile {
  final String  id;
  final String  fullName;
  final String  email;
  final String? phone;
  final String? bio;
  final String? avatarUrl;
  final String? instagramUrl;
  final List<String> specializations;

  const UserProfile({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone,
    this.bio,
    this.avatarUrl,
    this.instagramUrl,
    this.specializations = const [],
  });

  factory UserProfile.fromMap(Map<String, dynamic> m) => UserProfile(
        id:              m['id'] as String,
        fullName:        m['full_name'] as String? ?? '',
        email:           m['email'] as String? ?? '',
        phone:           m['phone'] as String?,
        bio:             m['bio'] as String?,
        avatarUrl:       m['avatar_url'] as String?,
        instagramUrl:    m['instagram_url'] as String?,
        specializations: (m['specializations'] as List?)
                ?.cast<String>() ??
            [],
      );

  UserProfile copyWith({
    String?       fullName,
    String?       phone,
    String?       bio,
    String?       avatarUrl,
    String?       instagramUrl,
    List<String>? specializations,
  }) =>
      UserProfile(
        id:              id,
        fullName:        fullName      ?? this.fullName,
        email:           email,
        phone:           phone         ?? this.phone,
        bio:             bio           ?? this.bio,
        avatarUrl:       avatarUrl     ?? this.avatarUrl,
        instagramUrl:    instagramUrl  ?? this.instagramUrl,
        specializations: specializations ?? this.specializations,
      );

  Map<String, dynamic> toUpdateMap() => {
        'full_name':      fullName,
        'phone':          phone,
        'bio':            bio,
        'avatar_url':     avatarUrl,
        'instagram_url':  instagramUrl,
        'specializations': specializations.isEmpty ? null : specializations,
      };
}
