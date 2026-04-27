import 'package:flutter_test/flutter_test.dart';
import 'package:studio/features/booking/logic/plan_selector.dart';

Map<String, dynamic> _plan({
  required String type,
  int? credits,
  String? courseId,
}) =>
    {
      'id': 'plan-$type-${courseId ?? "open"}',
      'credits_remaining': credits,
      'course_id': courseId,
      'plans': {'type': type},
    };

void main() {
  const courseA = 'course-a';
  const courseB = 'course-b';

  // ────────────────────────────────────────────────────────────────────────────
  group('hasValidPlanForCourse', () {
    test('piano unlimited → true', () {
      expect(
        hasValidPlanForCourse([_plan(type: 'unlimited')], courseA),
        isTrue,
      );
    });

    test('credits > 0 Open (null course_id) → true', () {
      expect(
        hasValidPlanForCourse([_plan(type: 'credits', credits: 5)], courseA),
        isTrue,
      );
    });

    test('credits > 0 specifico per courseA → true', () {
      expect(
        hasValidPlanForCourse(
            [_plan(type: 'credits', credits: 2, courseId: courseA)], courseA),
        isTrue,
      );
    });

    test('credits == 0 → false', () {
      expect(
        hasValidPlanForCourse([_plan(type: 'credits', credits: 0)], courseA),
        isFalse,
      );
    });

    test('piano specifico per corso diverso → false', () {
      expect(
        hasValidPlanForCourse(
            [_plan(type: 'credits', credits: 5, courseId: courseB)], courseA),
        isFalse,
      );
    });

    test('lista vuota → false', () {
      expect(hasValidPlanForCourse([], courseA), isFalse);
    });

    test('credits null → false', () {
      expect(
        hasValidPlanForCourse([_plan(type: 'credits', credits: null)], courseA),
        isFalse,
      );
    });
  });

  // ────────────────────────────────────────────────────────────────────────────
  group('selectBestCreditPlan', () {
    test('preferisce Open rispetto a corso-specifico', () {
      final open = _plan(type: 'credits', credits: 3);
      final specific = _plan(type: 'credits', credits: 5, courseId: courseA);
      final result = selectBestCreditPlan([specific, open], courseA);
      expect(result, equals(open));
    });

    test('fallback a corso-specifico se nessun Open disponibile', () {
      final specific = _plan(type: 'credits', credits: 5, courseId: courseA);
      expect(selectBestCreditPlan([specific], courseA), equals(specific));
    });

    test('scarta piano con 0 crediti', () {
      final empty = _plan(type: 'credits', credits: 0);
      final specific = _plan(type: 'credits', credits: 2, courseId: courseA);
      expect(selectBestCreditPlan([empty, specific], courseA), equals(specific));
    });

    test('restituisce null se nessun piano crediti disponibile', () {
      final unlimited = _plan(type: 'unlimited');
      expect(selectBestCreditPlan([unlimited], courseA), isNull);
    });

    test('ignora piani unlimited', () {
      expect(
          selectBestCreditPlan([_plan(type: 'unlimited')], courseA), isNull);
    });

    test('restituisce null se lista vuota', () {
      expect(selectBestCreditPlan([], courseA), isNull);
    });

    test('ignora piano corso-specifico per corso diverso', () {
      final wrongCourse =
          _plan(type: 'credits', credits: 5, courseId: courseB);
      expect(selectBestCreditPlan([wrongCourse], courseA), isNull);
    });
  });
}
