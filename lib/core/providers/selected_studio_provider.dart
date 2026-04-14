import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/studio.dart';
import '../../features/auth/providers/auth_provider.dart';

// ── Tutti gli studi di cui l'utente è owner ──────────────────────────────────

final ownerStudiosProvider = FutureProvider<List<Studio>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];

  final client = ref.watch(supabaseClientProvider);

  final data = await client
      .from('user_studio_roles')
      .select('studios(id, name, address)')
      .eq('user_id', user.id)
      .eq('role', 'owner');

  return (data as List)
      .where((r) => r['studios'] != null)
      .map((r) => Studio.fromJson(r['studios'] as Map<String, dynamic>))
      .toList();
});

// ── Studio selezionato (con memoria del default) ──────────────────────────────

class SelectedStudioNotifier extends AsyncNotifier<Studio?> {
  @override
  Future<Studio?> build() async {
    final studios = await ref.watch(ownerStudiosProvider.future);
    if (studios.isEmpty) return null;
    if (studios.length == 1) return studios.first;

    // Cerca il default salvato
    final user   = ref.read(currentUserProvider);
    final client = ref.read(supabaseClientProvider);
    if (user == null) return studios.first;

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

    await client
        .from('users')
        .update({'default_studio_id': studio.id})
        .eq('id', user.id);

    state = AsyncData(studio);
  }
}

final selectedStudioProvider =
    AsyncNotifierProvider<SelectedStudioNotifier, Studio?>(
  SelectedStudioNotifier.new,
);
