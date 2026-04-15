import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';

// Set di lesson_id prenotati dall'utente corrente
final userBookingsProvider = FutureProvider<Set<String>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return {};

  final client = ref.watch(supabaseClientProvider);
  final response = await client
      .from('bookings')
      .select('lesson_id')
      .eq('user_id', user.id)
      .eq('status', 'confirmed');

  return (response as List)
      .map<String>((b) => b['lesson_id'] as String)
      .toSet();
});

class BookingNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> book(String lessonId) async {
    final user = ref.read(currentUserProvider);
    if (user == null) throw Exception('Utente non autenticato');

    final client = ref.read(supabaseClientProvider);
    await client.from('bookings').upsert(
      {
        'lesson_id': lessonId,
        'user_id': user.id,
        'status': 'confirmed',
      },
      onConflict: 'user_id,lesson_id',
    );

    ref.invalidate(userBookingsProvider);
  }

  Future<void> cancel(String lessonId) async {
    final user = ref.read(currentUserProvider);
    if (user == null) throw Exception('Utente non autenticato');

    final client = ref.read(supabaseClientProvider);
    await client
        .from('bookings')
        .update({'status': 'cancelled'})
        .eq('lesson_id', lessonId)
        .eq('user_id', user.id);

    ref.invalidate(userBookingsProvider);
  }

  /// Cancella la prenotazione E scala un credito dal piano attivo.
  /// Da usare quando la finestra di cancellazione gratuita è già scaduta.
  Future<void> cancelWithCreditDeduction(String lessonId) async {
    final user = ref.read(currentUserProvider);
    if (user == null) throw Exception('Utente non autenticato');

    final client = ref.read(supabaseClientProvider);

    // 1. Trova il piano attivo per scalare il credito
    final now = DateTime.now().toUtc().toIso8601String();
    final planRow = await client
        .from('user_plans')
        .select('id, credits_remaining')
        .eq('user_id', user.id)
        .or('expires_at.is.null,expires_at.gte.$now')
        .order('expires_at', ascending: false)
        .limit(1)
        .maybeSingle();

    // 2. Segna la prenotazione come cancellata
    await client
        .from('bookings')
        .update({'status': 'cancelled'})
        .eq('lesson_id', lessonId)
        .eq('user_id', user.id);

    // 3. Scala un credito (se il piano esiste e ha crediti disponibili)
    if (planRow != null) {
      final credits = planRow['credits_remaining'] as int?;
      if (credits != null && credits > 0) {
        await client
            .from('user_plans')
            .update({'credits_remaining': credits - 1})
            .eq('id', planRow['id'] as String);
      }
    }

    ref.invalidate(userBookingsProvider);
  }
}

final bookingNotifierProvider =
    AsyncNotifierProvider<BookingNotifier, void>(BookingNotifier.new);