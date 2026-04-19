import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';

// Set di lesson_id prenotati dall'utente corrente (status confirmed)
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

// Set di lesson_id con prenotazione prova in attesa di approvazione
final userPendingTrialLessonsProvider = FutureProvider<Set<String>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return {};

  final client = ref.watch(supabaseClientProvider);
  final response = await client
      .from('bookings')
      .select('lesson_id')
      .eq('user_id', user.id)
      .eq('status', 'pending')
      .eq('is_trial', true);

  return (response as List)
      .map<String>((b) => b['lesson_id'] as String)
      .toSet();
});

// Set di course_id per cui l'utente ha almeno una prenotazione confirmed/attended
// → determina se l'utente è "iscritto" a quel corso
final userEnrolledCourseIdsProvider = FutureProvider<Set<String>>((ref) async {
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

    final client = ref.read(supabaseClientProvider);

    final lessonRow = await client
        .from('lessons')
        .select('course_id')
        .eq('id', lessonId)
        .single();
    final courseId = lessonRow['course_id'] as String;

    // Verifica piano valido (Open o specifico per questo corso)
    final now = DateTime.now().toUtc().toIso8601String();
    final plansData = await client
        .from('user_plans')
        .select('credits_remaining, course_id, plans!inner(type)')
        .eq('user_id', user.id)
        .eq('status', 'active')
        .or('expires_at.is.null,expires_at.gte.$now');

    final plans = (plansData as List).cast<Map<String, dynamic>>();
    final hasValidPlan = plans.any((p) {
      final planCourseId = p['course_id'] as String?;
      // Exclude plans scoped to a different course
      if (planCourseId != null && planCourseId != courseId) return false;
      final type =
          (p['plans'] as Map<String, dynamic>)['type'] as String;
      if (type == 'unlimited') return true;
      final credits = p['credits_remaining'] as int?;
      return credits != null && credits > 0;
    });

    if (!hasValidPlan) {
      throw Exception(
          'Nessun piano valido — usa "Prova" per richiedere una lezione di prova');
    }

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

  /// Richiede una lezione di prova per un corso a cui non si è iscritti.
  /// La prenotazione parte con status [pending] e [is_trial] = true.
  /// L'owner dovrà approvarla o rifiutarla.
  Future<void> bookTrialLesson(String lessonId) async {
    final user = ref.read(currentUserProvider);
    if (user == null) throw Exception('Utente non autenticato');

    final client = ref.read(supabaseClientProvider);
    await client.from('bookings').upsert(
      {
        'lesson_id': lessonId,
        'user_id': user.id,
        'status': 'pending',
        'is_trial': true,
      },
      onConflict: 'user_id,lesson_id',
    );

    ref.invalidate(userPendingTrialLessonsProvider);
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
    ref.invalidate(userPendingTrialLessonsProvider);
  }

  /// Cancella la prenotazione E scala un credito dal piano attivo.
  /// Da usare quando la finestra di cancellazione gratuita è già scaduta.
  Future<void> cancelWithCreditDeduction(String lessonId) async {
    final user = ref.read(currentUserProvider);
    if (user == null) throw Exception('Utente non autenticato');

    final client = ref.read(supabaseClientProvider);

    // 1. Recupera il course_id della lezione
    final lessonRow = await client
        .from('lessons')
        .select('course_id')
        .eq('id', lessonId)
        .single();
    final courseId = lessonRow['course_id'] as String;

    // 2. Trova il piano crediti migliore (Open prima, poi specifico per corso)
    final now = DateTime.now().toUtc().toIso8601String();
    final plansData = await client
        .from('user_plans')
        .select('id, credits_remaining, course_id, plans!inner(type)')
        .eq('user_id', user.id)
        .eq('status', 'active')
        .or('expires_at.is.null,expires_at.gte.$now');

    final plans = (plansData as List).cast<Map<String, dynamic>>();

    Map<String, dynamic>? bestPlan;
    // Open credits plan first
    for (final p in plans) {
      final type = (p['plans'] as Map<String, dynamic>)['type'] as String;
      if (type != 'credits') continue;
      if (p['course_id'] != null) continue; // skip course-specific
      final credits = p['credits_remaining'] as int?;
      if (credits != null && credits > 0) { bestPlan = p; break; }
    }
    // Fall back to course-specific
    if (bestPlan == null) {
      for (final p in plans) {
        final type = (p['plans'] as Map<String, dynamic>)['type'] as String;
        if (type != 'credits') continue;
        if (p['course_id'] != courseId) continue;
        final credits = p['credits_remaining'] as int?;
        if (credits != null && credits > 0) { bestPlan = p; break; }
      }
    }

    // 3. Segna la prenotazione come cancellata
    await client
        .from('bookings')
        .update({'status': 'cancelled'})
        .eq('lesson_id', lessonId)
        .eq('user_id', user.id);

    // 4. Scala un credito
    if (bestPlan != null) {
      final credits = bestPlan['credits_remaining'] as int;
      await client
          .from('user_plans')
          .update({'credits_remaining': credits - 1})
          .eq('id', bestPlan['id'] as String);
    }

    ref.invalidate(userBookingsProvider);
  }
}

final bookingNotifierProvider =
    AsyncNotifierProvider<BookingNotifier, void>(BookingNotifier.new);