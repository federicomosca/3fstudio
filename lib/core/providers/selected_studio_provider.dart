import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/studio.dart';
import '../../features/auth/providers/auth_provider.dart';

// ── Tutte le sedi accessibili dall'utente (qualunque ruolo) ──────────────────

final userSediProvider = FutureProvider<List<Studio>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];

  final client = ref.watch(supabaseClientProvider);

  // Gli admin vedono tutte le sedi; gli altri vedono solo quelle con un ruolo.
  final userRow = await client
      .from('users')
      .select('is_admin')
      .eq('id', user.id)
      .maybeSingle();

  final isAdmin = (userRow?['is_admin'] as bool?) ?? false;

  if (isAdmin) {
    final data = await client.from('studios').select('id, name, address');
    return (data as List)
        .map((r) => Studio.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  final data = await client
      .from('user_studio_roles')
      .select('studios(id, name, address)')
      .eq('user_id', user.id);

  // Deduplica (un utente può avere più ruoli nella stessa sede)
  final Map<String, Studio> byId = {};
  for (final r in (data as List)) {
    final s = r['studios'] as Map<String, dynamic>?;
    if (s == null) continue;
    final studio = Studio.fromJson(s);
    byId[studio.id] ??= studio;
  }
  return byId.values.toList();
});

/// Alias per retrocompatibilità con owner_shell.dart
final ownerStudiosProvider = userSediProvider;

// ── Studio selezionato (con memoria del default) ──────────────────────────────

class SelectedStudioNotifier extends AsyncNotifier<Studio?> {
  @override
  Future<Studio?> build() async {
    final studios = await ref.watch(userSediProvider.future);
    if (studios.isEmpty) return null;
    if (studios.length == 1) return studios.first;

    // Cerca il default salvato (colonna aggiunta con migration 005)
    final user   = ref.read(currentUserProvider);
    final client = ref.read(supabaseClientProvider);
    if (user == null) return studios.first;

    try {
      final row = await client
          .from('users')
          .select('default_studio_id')
          .eq('id', user.id)
          .maybeSingle();

      final defaultId = row?['default_studio_id'] as String?;
      if (defaultId != null) {
        try {
          return studios.firstWhere((s) => s.id == defaultId);
        } catch (_) {}
      }
    } catch (_) {
      // Colonna default_studio_id non ancora presente nel DB —
      // prima che venga eseguita la migration 005, cade qui silenziosamente.
    }
    return studios.first;
  }

  /// Cambia lo studio attivo (senza salvare come default).
  void select(Studio studio) {
    state = AsyncData(studio);
  }

  /// Imposta lo studio come default e lo seleziona.
  Future<void> setDefault(Studio studio) async {
    final user   = ref.read(currentUserProvider);
    final client = ref.read(supabaseClientProvider);
    if (user == null) return;

    try {
      await client
          .from('users')
          .update({'default_studio_id': studio.id})
          .eq('id', user.id);
    } catch (_) {
      // Colonna default_studio_id non ancora presente — ignorato silenziosamente.
    }

    state = AsyncData(studio);
  }
}

final selectedStudioProvider =
    AsyncNotifierProvider<SelectedStudioNotifier, Studio?>(
  SelectedStudioNotifier.new,
);
