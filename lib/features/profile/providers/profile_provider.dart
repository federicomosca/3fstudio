import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../features/auth/providers/auth_provider.dart';
import '../models/user_profile.dart';

export '../models/user_profile.dart';

// ─── Kept for client profile screen ──────────────────────────────────────────

class ActivePlan {
  final String planName;
  final String planType;
  final int? creditsRemaining;
  final DateTime? expiresAt;

  const ActivePlan({
    required this.planName,
    required this.planType,
    this.creditsRemaining,
    this.expiresAt,
  });
}

class UpcomingBooking {
  final String lessonId;
  final String courseName;
  final DateTime startsAt;
  final DateTime endsAt;

  const UpcomingBooking({
    required this.lessonId,
    required this.courseName,
    required this.startsAt,
    required this.endsAt,
  });
}

final activePlanProvider = FutureProvider<ActivePlan?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;

  final client = ref.watch(supabaseClientProvider);
  final now = DateTime.now().toUtc().toIso8601String();

  final response = await client
      .from('user_plans')
      .select('credits_remaining, expires_at, plans(name, type)')
      .eq('user_id', user.id)
      .or('expires_at.is.null,expires_at.gte.$now')
      .order('expires_at', ascending: false)
      .limit(1)
      .maybeSingle();

  if (response == null) return null;
  final plan = response['plans'] as Map<String, dynamic>;
  return ActivePlan(
    planName:        plan['name'] as String,
    planType:        plan['type'] as String,
    creditsRemaining: response['credits_remaining'] as int?,
    expiresAt: response['expires_at'] != null
        ? DateTime.parse(response['expires_at'] as String).toLocal()
        : null,
  );
});

final upcomingBookingsProvider =
    FutureProvider<List<UpcomingBooking>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];

  final client = ref.watch(supabaseClientProvider);
  final now = DateTime.now().toUtc().toIso8601String();

  final response = await client
      .from('bookings')
      .select('lesson_id, lessons(starts_at, ends_at, courses(name))')
      .eq('user_id', user.id)
      .eq('status', 'confirmed')
      .gte('lessons.starts_at', now)
      .order('lessons(starts_at)')
      .limit(5);

  final list = (response as List)
      .where((b) => b['lessons'] != null)
      .map((b) {
        final lesson = b['lessons'] as Map<String, dynamic>;
        final course = lesson['courses'] as Map<String, dynamic>;
        return UpcomingBooking(
          lessonId:   b['lesson_id'] as String,
          courseName: course['name'] as String,
          startsAt:   DateTime.parse(lesson['starts_at'] as String).toLocal(),
          endsAt:     DateTime.parse(lesson['ends_at'] as String).toLocal(),
        );
      })
      .toList()
    ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

  return list;
});

// ─── My profile (editable) ────────────────────────────────────────────────────

class MyProfileNotifier extends AsyncNotifier<UserProfile?> {
  @override
  Future<UserProfile?> build() async {
    final user = ref.watch(currentUserProvider);
    if (user == null) return null;

    final client = ref.watch(supabaseClientProvider);
    final row = await client
        .from('users')
        .select('id, full_name, email, phone, bio, avatar_url, instagram_url, specializations')
        .eq('id', user.id)
        .maybeSingle();

    return row != null ? UserProfile.fromMap(row) : null;
  }

  /// Salva le modifiche al profilo nel DB.
  Future<void> save(UserProfile updated) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final client = Supabase.instance.client;
      await client
          .from('users')
          .update(updated.toUpdateMap())
          .eq('id', user.id);
      return updated;
    });
  }

  /// Carica un'immagine su Supabase Storage e restituisce il public URL.
  /// Non chiama save() — è compito del chiamante salvare il profilo completo.
  Future<String?> uploadAvatar(XFile imageFile) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return null;

    final client = Supabase.instance.client;

    // Estrae l'estensione in modo robusto; fallback a 'jpg'
    final rawExt = imageFile.name.split('.').last.toLowerCase();
    final ext    = _safeImageExt(rawExt);
    final mime   = 'image/$ext';
    final path   = '${user.id}/avatar.$ext';
    final bytes  = await imageFile.readAsBytes();

    // upsert: true usa la policy UPDATE (già presente in migration 005),
    // evitando il pattern fragile remove + insert.
    await client.storage.from('avatars').uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: mime, upsert: true),
    );

    final url = client.storage.from('avatars').getPublicUrl(path);
    // Cache-busting: forza il reload su CachedNetworkImage
    return '$url?t=${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Normalizza l'estensione a un formato MIME valido.
  static String _safeImageExt(String raw) {
    const known = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'heic', 'heif'};
    if (known.contains(raw)) return raw == 'jpeg' ? 'jpg' : raw;
    return 'jpg'; // fallback sicuro
  }
}

final myProfileProvider =
    AsyncNotifierProvider<MyProfileNotifier, UserProfile?>(
        MyProfileNotifier.new);

// ─── Public profile (read-only, by userId) ───────────────────────────────────

final publicProfileProvider =
    FutureProvider.family<UserProfile?, String>((ref, userId) async {
  final client = ref.watch(supabaseClientProvider);
  final row = await client
      .from('users')
      .select('id, full_name, email, phone, bio, avatar_url, instagram_url, specializations')
      .eq('id', userId)
      .maybeSingle();

  return row != null ? UserProfile.fromMap(row) : null;
});
