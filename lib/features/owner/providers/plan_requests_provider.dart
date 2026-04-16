import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/studio_provider.dart';
import '../../auth/providers/auth_provider.dart';

/// Numero di richieste piano in attesa per lo studio corrente.
/// Usato dal badge sulla nav dell'owner e dalla PlansScreen.
final pendingPlanRequestsCountProvider = FutureProvider<int>((ref) async {
  final studioId = ref.watch(currentStudioIdProvider);
  if (studioId == null) return 0;
  final client = ref.watch(supabaseClientProvider);
  final data = await client
      .from('plan_requests')
      .select('id')
      .eq('studio_id', studioId)
      .eq('status', 'pending');
  return (data as List).length;
});
