import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;
import 'package:three_f_studio/features/auth/providers/auth_provider.dart';
import 'package:three_f_studio/features/booking/providers/booking_provider.dart';
import 'package:three_f_studio/features/booking/repositories/booking_data_source.dart';

import '../../../helpers/provider_helpers.dart';

// ─── Fake user ────────────────────────────────────────────────────────────────

User _fakeUser(String id) => User(
      id: id,
      appMetadata: {},
      userMetadata: {},
      aud: 'authenticated',
      createdAt: DateTime.now().toIso8601String(),
    );

// ─── Fake BookingDataSource ───────────────────────────────────────────────────

class _FakeBookingDataSource implements BookingDataSource {
  String? lastUpsertStatus;
  bool isTrial = false;
  String? lastUpdatedStatus;
  String? deductedPlanId;
  int? deductedFromCredits;
  String bookIfAvailableResult = 'booked';
  String? lastBookIfAvailableUserId;

  Map<String, dynamic> lessonToReturn = {'course_id': 'course-a'};
  List<Map<String, dynamic>> plansToReturn = [];

  @override
  Future<Map<String, dynamic>> getLesson(String lessonId) async =>
      lessonToReturn;

  @override
  Future<List<Map<String, dynamic>>> getActivePlans(String userId) async =>
      plansToReturn;

  @override
  Future<void> upsertBooking({
    required String userId,
    required String lessonId,
    required String status,
    bool isTrial = false,
  }) async {
    lastUpsertStatus = status;
    this.isTrial = isTrial;
  }

  @override
  Future<String> bookIfAvailable({
    required String userId,
    required String lessonId,
  }) async {
    lastBookIfAvailableUserId = userId;
    return bookIfAvailableResult;
  }

  @override
  Future<void> updateBookingStatus({
    required String userId,
    required String lessonId,
    required String status,
  }) async {
    lastUpdatedStatus = status;
  }

  @override
  Future<void> deductCredit(String planId, int currentCredits) async {
    deductedPlanId = planId;
    deductedFromCredits = currentCredits;
  }

  @override
  Future<void> refundCredit(String planId, int currentCredits) async {}

  @override
  Future<void> promoteFromWaitlist(String lessonId) async {}
}

Map<String, dynamic> _plan({
  required String id,
  required String type,
  int? credits,
  String? courseId,
}) =>
    {
      'id': id,
      'credits_remaining': credits,
      'course_id': courseId,
      'plans': {'type': type},
    };

// ─── Helpers ──────────────────────────────────────────────────────────────────

ProviderContainer _makeContainer({
  User? user,
  required _FakeBookingDataSource ds,
}) {
  return createContainer(overrides: [
    currentUserProvider.overrideWithValue(user),
    bookingDataSourceProvider.overrideWithValue(ds),
  ]);
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  const lessonId = 'lesson-1';
  const userId = 'user-1';

  group('BookingNotifier.book()', () {
    test('prenota via bookIfAvailable quando piano valido', () async {
      final ds = _FakeBookingDataSource()
        ..plansToReturn = [
          _plan(id: 'p1', type: 'credits', credits: 3)
        ];
      final container = _makeContainer(user: _fakeUser(userId), ds: ds);

      await container
          .read(bookingNotifierProvider.notifier)
          .book(lessonId);

      expect(ds.lastBookIfAvailableUserId, userId);
    });

    test('lancia eccezione quando lezione al completo', () async {
      final ds = _FakeBookingDataSource()
        ..bookIfAvailableResult = 'full'
        ..plansToReturn = [
          _plan(id: 'p1', type: 'credits', credits: 3)
        ];
      final container = _makeContainer(user: _fakeUser(userId), ds: ds);

      await expectLater(
        container.read(bookingNotifierProvider.notifier).book(lessonId),
        throwsA(isA<Exception>().having(
            (e) => e.toString(), 'message', contains('al completo'))),
      );
    });

    test('lancia eccezione quando nessun piano valido', () async {
      final ds = _FakeBookingDataSource()..plansToReturn = [];
      final container = _makeContainer(user: _fakeUser(userId), ds: ds);

      await expectLater(
        container.read(bookingNotifierProvider.notifier).book(lessonId),
        throwsA(isA<Exception>().having(
            (e) => e.toString(), 'message', contains('Nessun piano valido'))),
      );
    });

    test('lancia eccezione quando utente non autenticato', () async {
      final ds = _FakeBookingDataSource();
      final container = _makeContainer(user: null, ds: ds);

      await expectLater(
        container.read(bookingNotifierProvider.notifier).book(lessonId),
        throwsA(isA<Exception>().having(
            (e) => e.toString(), 'message', contains('non autenticato'))),
      );
    });
  });

  group('BookingNotifier.cancelWithCreditDeduction()', () {
    test('cancella e detrae credito dal piano Open', () async {
      final ds = _FakeBookingDataSource()
        ..plansToReturn = [
          _plan(id: 'open-plan', type: 'credits', credits: 5),
        ];
      final container = _makeContainer(user: _fakeUser(userId), ds: ds);

      await container
          .read(bookingNotifierProvider.notifier)
          .cancelWithCreditDeduction(lessonId);

      expect(ds.lastUpdatedStatus, 'cancelled');
      expect(ds.deductedPlanId, 'open-plan');
      expect(ds.deductedFromCredits, 5);
    });

    test('usa piano corso-specifico come fallback', () async {
      final ds = _FakeBookingDataSource()
        ..plansToReturn = [
          _plan(id: 'specific-plan', type: 'credits', credits: 2,
              courseId: 'course-a'),
        ];
      final container = _makeContainer(user: _fakeUser(userId), ds: ds);

      await container
          .read(bookingNotifierProvider.notifier)
          .cancelWithCreditDeduction(lessonId);

      expect(ds.deductedPlanId, 'specific-plan');
    });

    test('cancella senza detrarre se nessun piano crediti trovato', () async {
      final ds = _FakeBookingDataSource()
        ..plansToReturn = [
          _plan(id: 'unlimited', type: 'unlimited'),
        ];
      final container = _makeContainer(user: _fakeUser(userId), ds: ds);

      await container
          .read(bookingNotifierProvider.notifier)
          .cancelWithCreditDeduction(lessonId);

      expect(ds.lastUpdatedStatus, 'cancelled');
      expect(ds.deductedPlanId, isNull);
    });
  });
}
