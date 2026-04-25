import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../../calendar/providers/lessons_provider.dart';
import '../logic/plan_selector.dart';
import '../repositories/booking_data_source.dart';
import '../repositories/supabase_booking_data_source.dart';

final bookingDataSourceProvider = Provider<BookingDataSource>((ref) {
  return SupabaseBookingDataSource(ref.watch(supabaseClientProvider));
});

// lessonId → bookingStatus ('confirmed' | 'attended' | 'no_show') per le lezioni
// di oggi in poi. Usato dal calendario per mostrare badge post-lezione corretti.
final userBookingsProvider = FutureProvider.autoDispose<Map<String, String>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return {};

  final client  = ref.watch(supabaseClientProvider);
  final today   = DateTime.now();
  final startOfToday = DateTime(today.year, today.month, today.day)
      .toUtc().toIso8601String();

  final response = await client
      .from('bookings')
      .select('lesson_id, status, lessons!inner(starts_at)')
      .eq('user_id', user.id)
      .inFilter('status', ['confirmed', 'attended', 'no_show'])
      .gte('lessons.starts_at', startOfToday);

  return {
    for (final b in (response as List))
      b['lesson_id'] as String: b['status'] as String,
  };
});

// Set di lesson_id in lista d'attesa — solo lezioni future/oggi
final userWaitlistProvider = FutureProvider.autoDispose<Set<String>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return {};

  final client  = ref.watch(supabaseClientProvider);
  final today   = DateTime.now();
  final startOfToday = DateTime(today.year, today.month, today.day)
      .toUtc().toIso8601String();

  final response = await client
      .from('waitlist')
      .select('lesson_id, lessons!inner(starts_at)')
      .eq('user_id', user.id)
      .gte('lessons.starts_at', startOfToday);

  return (response as List)
      .map<String>((w) => w['lesson_id'] as String)
      .toSet();
});

// Set di lesson_id con prova in attesa — solo lezioni future/oggi
final userPendingTrialLessonsProvider = FutureProvider.autoDispose<Set<String>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return {};

  final client  = ref.watch(supabaseClientProvider);
  final today   = DateTime.now();
  final startOfToday = DateTime(today.year, today.month, today.day)
      .toUtc().toIso8601String();

  final response = await client
      .from('bookings')
      .select('lesson_id, lessons!inner(starts_at)')
      .eq('user_id', user.id)
      .eq('status', 'pending')
      .eq('is_trial', true)
      .gte('lessons.starts_at', startOfToday);

  return (response as List)
      .map<String>((b) => b['lesson_id'] as String)
      .toSet();
});

/// True se l'utente ha almeno un piano credits/unlimited attivo, o trial-by-time.
final hasActivePlanProvider = FutureProvider.autoDispose<bool>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return false;

  final client = ref.watch(supabaseClientProvider);
  final now = DateTime.now().toUtc().toIso8601String();

  final plans = await client
      .from('user_plans')
      .select('credits_remaining, plans!inner(type)')
      .eq('user_id', user.id)
      .or('expires_at.is.null,expires_at.gte.$now');

  return (plans as List).cast<Map<String, dynamic>>().any((p) {
    final type = (p['plans'] as Map<String, dynamic>)['type'] as String;
    if (type == 'unlimited') return true;
    if (type == 'trial') {
      // trial-by-time (nessun credito): vale come unlimited entro la scadenza
      return p['credits_remaining'] == null;
    }
    final credits = p['credits_remaining'] as int?;
    return credits != null && credits > 0;
  });
});

/// True se l'utente ha un piano trial-by-time attivo (unlimited entro scadenza).
final hasTrialTimePlanProvider = FutureProvider.autoDispose<bool>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return false;

  final client = ref.watch(supabaseClientProvider);
  final now = DateTime.now().toUtc().toIso8601String();

  final plans = await client
      .from('user_plans')
      .select('credits_remaining, plans!inner(type)')
      .eq('user_id', user.id)
      .or('expires_at.is.null,expires_at.gte.$now');

  return (plans as List).cast<Map<String, dynamic>>().any((p) {
    final type = (p['plans'] as Map<String, dynamic>)['type'] as String;
    return type == 'trial' && p['credits_remaining'] == null;
  });
});

/// True se l'utente ha almeno un credito prova disponibile.
final hasTrialCreditsProvider = FutureProvider.autoDispose<bool>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return false;

  final client = ref.watch(supabaseClientProvider);
  final now = DateTime.now().toUtc().toIso8601String();

  final plans = await client
      .from('user_plans')
      .select('credits_remaining, plans!inner(type)')
      .eq('user_id', user.id)
      .or('expires_at.is.null,expires_at.gte.$now');

  return (plans as List).cast<Map<String, dynamic>>().any((p) {
    final type = (p['plans'] as Map<String, dynamic>)['type'] as String;
    if (type != 'trial') return false;
    final credits = p['credits_remaining'] as int?;
    return credits != null && credits > 0;
  });
});

// Set di course_id per cui l'utente ha almeno una prenotazione confirmed/attended
// → determina se l'utente è "iscritto" a quel corso
final userEnrolledCourseIdsProvider = FutureProvider.autoDispose<Set<String>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return {};

  final client = ref.watch(supabaseClientProvider);
  final response = await client
      .from('bookings')
      .select('lessons!inner(course_id)')
      .eq('user_id', user.id)
      .inFilter('status', ['confirmed', 'attended']);

  return (response as List)
      .map<String>((b) =>
          (b['lessons'] as Map<String, dynamic>)['course_id'] as String)
      .toSet();
});

class BookingNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> book(String lessonId) async {
    final user = ref.read(currentUserProvider);
    if (user == null) throw Exception('Utente non autenticato');

    final ds = ref.read(bookingDataSourceProvider);
    final lessonRow = await ds.getLesson(lessonId);
    final courseId = lessonRow['course_id'] as String;

    final plans = await ds.getActivePlans(user.id);
    if (!hasValidPlanForCourse(plans, courseId)) {
      throw Exception(
          'Nessun piano valido — usa "Prova" per richiedere una lezione di prova');
    }

    final result =
        await ds.bookIfAvailable(userId: user.id, lessonId: lessonId);
    if (result == 'full') {
      throw Exception(
          'La lezione è al completo — iscriviti alla lista d\'attesa');
    }

    ref.invalidate(userBookingsProvider);
    ref.invalidate(lessonsForDayProvider);
  }

  /// Richiede una lezione di prova (piano trial-by-credits).
  /// Il credito viene scalato alla presenza o alla disdetta tardiva, non qui.
  Future<void> bookTrialLesson(String lessonId) async {
    final user = ref.read(currentUserProvider);
    if (user == null) throw Exception('Utente non autenticato');

    final ds = ref.read(bookingDataSourceProvider);
    final plans = await ds.getActivePlans(user.id);

    final trialPlan = plans.cast<Map<String, dynamic>?>().firstWhere(
      (p) {
        final type =
            (p!['plans'] as Map<String, dynamic>)['type'] as String;
        final credits = p['credits_remaining'] as int?;
        return type == 'trial' && credits != null && credits > 0;
      },
      orElse: () => null,
    );

    if (trialPlan == null) {
      throw Exception(
          'Nessun credito prova disponibile — contatta l\'istruttore');
    }

    await ds.upsertBooking(
        userId: user.id, lessonId: lessonId, status: 'pending', isTrial: true);

    ref.invalidate(userPendingTrialLessonsProvider);
  }

  Future<void> cancel(String lessonId) async {
    final user = ref.read(currentUserProvider);
    if (user == null) throw Exception('Utente non autenticato');

    final ds = ref.read(bookingDataSourceProvider);
    await ds.updateBookingStatus(
        userId: user.id, lessonId: lessonId, status: 'cancelled');
    await ds.promoteFromWaitlist(lessonId);

    ref.invalidate(userBookingsProvider);
    ref.invalidate(userPendingTrialLessonsProvider);
    ref.invalidate(lessonsForDayProvider);
    ref.invalidate(userWaitlistProvider);
  }

  /// Cancella una richiesta di prova entro la finestra gratuita (nessun addebito).
  Future<void> cancelTrialRequest(String lessonId) async {
    final user = ref.read(currentUserProvider);
    if (user == null) throw Exception('Utente non autenticato');

    final ds = ref.read(bookingDataSourceProvider);
    await ds.updateBookingStatus(
        userId: user.id, lessonId: lessonId, status: 'cancelled');

    ref.invalidate(userPendingTrialLessonsProvider);
    ref.invalidate(lessonsForDayProvider);
  }

  /// Cancella una richiesta di prova dopo la finestra gratuita: scala 1 credito prova.
  Future<void> cancelTrialWithDeduction(String lessonId) async {
    final user = ref.read(currentUserProvider);
    if (user == null) throw Exception('Utente non autenticato');

    final ds = ref.read(bookingDataSourceProvider);
    final plans = await ds.getActivePlans(user.id);

    final trialPlan = plans.cast<Map<String, dynamic>?>().firstWhere(
      (p) {
        final type =
            (p!['plans'] as Map<String, dynamic>)['type'] as String;
        final credits = p['credits_remaining'] as int?;
        return type == 'trial' && credits != null && credits > 0;
      },
      orElse: () => null,
    );

    await ds.updateBookingStatus(
        userId: user.id, lessonId: lessonId, status: 'cancelled');

    if (trialPlan != null) {
      await ds.deductCredit(
          trialPlan['id'] as String, trialPlan['credits_remaining'] as int);
    }

    ref.invalidate(userPendingTrialLessonsProvider);
    ref.invalidate(hasTrialCreditsProvider);
    ref.invalidate(lessonsForDayProvider);
  }

  Future<void> joinWaitlist(String lessonId) async {
    final user = ref.read(currentUserProvider);
    if (user == null) throw Exception('Utente non autenticato');
    final client = ref.read(supabaseClientProvider);
    await client.from('waitlist').upsert(
      {'lesson_id': lessonId, 'user_id': user.id},
      onConflict: 'user_id,lesson_id',
    );
    ref.invalidate(userWaitlistProvider);
    ref.invalidate(lessonsForDayProvider);
  }

  Future<void> leaveWaitlist(String lessonId) async {
    final user = ref.read(currentUserProvider);
    if (user == null) throw Exception('Utente non autenticato');
    final client = ref.read(supabaseClientProvider);
    await client
        .from('waitlist')
        .delete()
        .eq('lesson_id', lessonId)
        .eq('user_id', user.id);
    ref.invalidate(userWaitlistProvider);
    ref.invalidate(lessonsForDayProvider);
  }

  /// Cancella la prenotazione E scala un credito dal piano attivo.
  /// Da usare quando la finestra di cancellazione gratuita è già scaduta.
  Future<void> cancelWithCreditDeduction(String lessonId) async {
    final user = ref.read(currentUserProvider);
    if (user == null) throw Exception('Utente non autenticato');

    final ds = ref.read(bookingDataSourceProvider);
    final lessonRow = await ds.getLesson(lessonId);
    final courseId = lessonRow['course_id'] as String;

    final plans = await ds.getActivePlans(user.id);
    final bestPlan = selectBestCreditPlan(plans, courseId);

    await ds.updateBookingStatus(
        userId: user.id, lessonId: lessonId, status: 'cancelled');

    if (bestPlan != null) {
      await ds.deductCredit(
          bestPlan['id'] as String, bestPlan['credits_remaining'] as int);
    }

    await ds.promoteFromWaitlist(lessonId);

    ref.invalidate(userBookingsProvider);
    ref.invalidate(lessonsForDayProvider);
    ref.invalidate(userWaitlistProvider);
  }
}

final bookingNotifierProvider =
    AsyncNotifierProvider<BookingNotifier, void>(BookingNotifier.new);