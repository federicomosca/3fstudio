import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_role.dart';
import '../providers/selected_studio_provider.dart';
import '../../features/auth/providers/auth_provider.dart'
    show supabaseClientProvider, currentUserProvider;

final appRolesProvider = FutureProvider<AppRoles>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return AppRoles.empty();

  final client = ref.watch(supabaseClientProvider);

  final rolesRows = await client
      .from('user_studio_roles')
      .select('studio_id, role')
      .eq('user_id', user.id);

  if ((rolesRows as List).isEmpty) {
    return AppRoles(studioId: null, studioRoles: {});
  }

  final studioId = rolesRows.first['studio_id'] as String;
  final roles = rolesRows
      .map<UserRole>((r) => UserRole.fromString(r['role'] as String))
      .toSet();

  return AppRoles(studioId: studioId, studioRoles: roles);
});

final currentStudioIdProvider = Provider<String?>((ref) {
  final roles    = ref.watch(appRolesProvider).whenOrNull(data: (r) => r);
  final selected = ref.watch(selectedStudioProvider).whenOrNull(data: (s) => s);
  return selected?.id ?? roles?.studioId;
});
