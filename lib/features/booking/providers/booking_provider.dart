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
      .eq('status', 'booked');

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
    await client.from('bookings').insert({
      'lesson_id': lessonId,
      'user_id': user.id,
      'status': 'booked',
    });

    ref.invalidate(userBookingsProvider);
  }

  Future<void> cancel(String lessonId) async {
    final user = ref.read(currentUserProvider);
    if (user == null) throw Exception('Utente non autenticato');

    final client = ref.read(supabaseClientProvider);
    await client
        .from('bookings')
        .delete()
        .eq('lesson_id', lessonId)
        .eq('user_id', user.id);

    ref.invalidate(userBookingsProvider);
  }
}

final bookingNotifierProvider =
    AsyncNotifierProvider<BookingNotifier, void>(BookingNotifier.new);