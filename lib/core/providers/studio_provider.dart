import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_role.dart';
import '../providers/selected_studio_provider.dart';
import '../../features/auth/providers/auth_provider.dart'
    show supabaseClientProvider, currentUserProvider;

/// Carica i ruoli dell'utente loggato nel DB.
final appRolesProvider = FutureProvider<AppRoles>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return AppRoles.empty();

  final client = ref.watch(supabaseClientProvider);

  final userRow = await client
      .from('users')
      .select('is_admin')
      .eq('id', user.id)
      .maybeSingle();

  // Utente non ancora nel DB (es. primo accesso non ancora propagato)
  if (userRow == null) return AppRoles.empty();

  final isAdmin = (userRow['is_admin'] as bool?) ?? false;

  final rolesRows = await client
      .from('user_studio_roles')
      .select('studio_id, role')
      .eq('user_id', user.id);

  if ((rolesRows as List).isEmpty) {
    return AppRoles(isAdmin: isAdmin, studioId: null, studioRoles: {});
  }

  final studioId = rolesRows.first['studio_id'] as String;
  final roles = rolesRows
      .map<UserRole>((r) => UserRole.fromString(r['role'] as String))
      .toSet();

  return AppRoles(isAdmin: isAdmin, studioId: studioId, studioRoles: roles);
});

/// Studio corrente:
/// - Owner: usa lo studio selezionato nel selettore (con fallback)
/// - Altri: studio di appartenenza
final currentStudioIdProvider = Provider<String?>((ref) {
  final roles = ref.watch(appRolesProvider).whenOrNull(data: (r) => r);

  if (roles?.isGymOwner == true) {
    final selected = ref.watch(selectedStudioProvider).whenOrNull(data: (s) => s);
    return selected?.id ?? roles?.studioId;
  }

  return roles?.studioId;
});
