import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/auth_provider.dart'
    show supabaseClientProvider, currentUserProvider;

final userPlansProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];

  final client = ref.watch(supabaseClientProvider);
  final now = DateTime.now().toUtc().toIso8601String();

  final plansRows = await client
      .from('user_plans')
      .select('credits_remaining, course_id, plans!inner(type)')
      .eq('user_id', user.id)
      .or('expires_at.is.null,expires_at.gte.$now');

  return (plansRows as List).cast<Map<String, dynamic>>();
});
