import 'package:supabase_flutter/supabase_flutter.dart';
import 'booking_data_source.dart';

class SupabaseBookingDataSource implements BookingDataSource {
  const SupabaseBookingDataSource(this._client);

  final SupabaseClient _client;

  @override
  Future<Map<String, dynamic>> getLesson(String lessonId) async {
    return await _client
        .from('lessons')
        .select('course_id')
        .eq('id', lessonId)
        .single();
  }

  @override
  Future<List<Map<String, dynamic>>> getActivePlans(String userId) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final data = await _client
        .from('user_plans')
        .select('id, credits_remaining, course_id, plans!inner(type)')
        .eq('user_id', userId)
        .or('expires_at.is.null,expires_at.gte.$now');
    return (data as List).cast<Map<String, dynamic>>();
  }

  @override
  Future<void> upsertBooking({
    required String userId,
    required String lessonId,
    required String status,
    bool isTrial = false,
  }) async {
    await _client.from('bookings').upsert(
      {
        'lesson_id': lessonId,
        'user_id': userId,
        'status': status,
        if (isTrial) 'is_trial': true,
      },
      onConflict: 'user_id,lesson_id',
    );
  }

  @override
  Future<String> bookIfAvailable({
    required String userId,
    required String lessonId,
  }) async {
    final result = await _client.rpc('book_if_available', params: {
      'p_lesson_id': lessonId,
      'p_user_id': userId,
    });
    return result as String;
  }

  @override
  Future<void> updateBookingStatus({
    required String userId,
    required String lessonId,
    required String status,
  }) async {
    await _client
        .from('bookings')
        .update({'status': status})
        .eq('lesson_id', lessonId)
        .eq('user_id', userId);
  }

  @override
  Future<void> deductCredit(String planId, int currentCredits) async {
    await _client
        .from('user_plans')
        .update({'credits_remaining': currentCredits - 1})
        .eq('id', planId);
  }

  @override
  Future<void> refundCredit(String planId, int currentCredits) async {
    await _client
        .from('user_plans')
        .update({'credits_remaining': currentCredits + 1})
        .eq('id', planId);
  }

  @override
  Future<void> promoteFromWaitlist(String lessonId) async {
    await _client.rpc('promote_from_waitlist', params: {
      'p_lesson_id': lessonId,
    });
  }
}
