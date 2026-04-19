import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/studio_provider.dart';
import '../../auth/providers/auth_provider.dart';

/// Conteggio richieste in attesa (proposte lezione + richieste eliminazione + prenotazioni prova).
/// Usato dal badge nella nav e nell'AppBar del calendario owner.
final pendingLessonsCountProvider = FutureProvider<int>((ref) async {
  final studioId = ref.watch(currentStudioIdProvider);
  if (studioId == null) return 0;
  final client = ref.watch(supabaseClientProvider);

  final lessonData = await client
      .from('lessons')
      .select('id, courses!inner(studio_id)')
      .inFilter('status', ['pending', 'delete_pending'])
      .eq('courses.studio_id', studioId);
  final lessonCount = (lessonData as List).length;

  final trialData = await client
      .from('bookings')
      .select('id, lessons!inner(courses!inner(studio_id))')
      .eq('status', 'pending')
      .eq('is_trial', true)
      .eq('lessons.courses.studio_id', studioId);
  final trialCount = (trialData as List).length;

  return lessonCount + trialCount;
});
