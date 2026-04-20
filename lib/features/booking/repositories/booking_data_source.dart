abstract class BookingDataSource {
  Future<Map<String, dynamic>> getLesson(String lessonId);

  /// Piani attivi dell'utente (non scaduti). La query di filtraggio scadenza
  /// è a carico dell'implementazione concreta.
  Future<List<Map<String, dynamic>>> getActivePlans(String userId);

  Future<void> upsertBooking({
    required String userId,
    required String lessonId,
    required String status,
    bool isTrial = false,
  });

  Future<void> updateBookingStatus({
    required String userId,
    required String lessonId,
    required String status,
  });

  Future<void> deductCredit(String planId, int currentCredits);
}
