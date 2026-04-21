import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/studio_provider.dart';
import '../../../features/auth/providers/auth_provider.dart';

// ── Realtime-backed list ──────────────────────────────────────────────────────

final notificationsProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) async* {
  final studioId = ref.watch(currentStudioIdProvider);
  if (studioId == null) {
    yield [];
    return;
  }
  final client = ref.watch(supabaseClientProvider);

  yield await _fetch(client, studioId);

  final controller = StreamController<List<Map<String, dynamic>>>();

  final channel = client
      .channel('public:notifications:$studioId')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'notifications',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'studio_id',
          value: studioId,
        ),
        callback: (_) async {
          if (!controller.isClosed) {
            controller.add(await _fetch(client, studioId));
          }
        },
      )
      .subscribe();

  ref.onDispose(() {
    controller.close();
    client.removeChannel(channel);
  });

  yield* controller.stream;
});

Future<List<Map<String, dynamic>>> _fetch(
  SupabaseClient client,
  String studioId,
) async {
  try {
    final data = await client
        .from('notifications')
        .select('id, title, body, created_at, users!created_by(full_name)')
        .eq('studio_id', studioId)
        .order('created_at', ascending: false)
        .limit(50);
    return (data as List).cast<Map<String, dynamic>>();
  } catch (_) {
    return [];
  }
}

// ── Last-seen timestamp ───────────────────────────────────────────────────────

final notificationsSeenAtProvider = FutureProvider<DateTime>((ref) async {
  final user   = ref.watch(currentUserProvider);
  final client = ref.watch(supabaseClientProvider);
  if (user == null) return DateTime.now();

  try {
    final row = await client
        .from('users')
        .select('notifications_seen_at')
        .eq('id', user.id)
        .maybeSingle();
    final raw = row?['notifications_seen_at'] as String?;
    return raw != null ? DateTime.parse(raw).toLocal() : DateTime.now();
  } catch (_) {
    return DateTime.now();
  }
});

// ── Unread count for badge ────────────────────────────────────────────────────

final unreadNotificationsCountProvider = Provider<int>((ref) {
  final notifs =
      ref.watch(notificationsProvider).whenOrNull(data: (l) => l) ?? [];
  final seenAt =
      ref.watch(notificationsSeenAtProvider).whenOrNull(data: (d) => d);
  if (seenAt == null) return 0;

  return notifs.where((n) {
    final raw = n['created_at'] as String?;
    if (raw == null) return false;
    final dt = DateTime.tryParse(raw)?.toLocal();
    return dt != null && dt.isAfter(seenAt);
  }).length;
});
