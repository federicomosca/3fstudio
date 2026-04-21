import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/studio_provider.dart';
import '../../auth/providers/auth_provider.dart' show supabaseClientProvider;

final studioPricingProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final studioId = ref.watch(currentStudioIdProvider);
  if (studioId == null) return null;
  final client = ref.watch(supabaseClientProvider);
  return await client
      .from('studios')
      .select(
          'group_surcharge_pct, shared_surcharge_pct, personal_surcharge_pct, second_course_discount_pct')
      .eq('id', studioId)
      .maybeSingle();
});

double calcCourseRate(
  Map<String, dynamic> course,
  Map<String, dynamic> pricing, {
  String? formulaOverride,
}) {
  final base = (course['hourly_rate'] as num?)?.toDouble() ?? 0;
  final type = formulaOverride ?? course['type'] as String? ?? 'group';
  final pct = switch (type) {
    'personal' => (pricing['personal_surcharge_pct'] as num?)?.toDouble() ?? 100,
    'shared'   => (pricing['shared_surcharge_pct']   as num?)?.toDouble() ?? 50,
    _          => (pricing['group_surcharge_pct']     as num?)?.toDouble() ?? 20,
  };
  return base * (1 + pct / 100);
}

