import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/lesson.dart';
import '../../../core/providers/studio_provider.dart';
import '../../auth/providers/auth_provider.dart';

class _SelectedDayNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => DateTime.now();
  void set(DateTime day) => state = day;
}

final selectedDayProvider =
    NotifierProvider<_SelectedDayNotifier, DateTime>(_SelectedDayNotifier.new);

final lessonsForDayProvider =
    FutureProvider.family<List<Lesson>, DateTime>((ref, date) async {
  final studioId = ref.watch(currentStudioIdProvider);
  if (studioId == null) return [];

  final client = ref.watch(supabaseClientProvider);
  final startOfDay = DateTime(date.year, date.month, date.day).toUtc();
  final endOfDay = startOfDay.add(const Duration(days: 1));

  final response = await client
      .from('lessons')
      .select('*, courses!inner(name, type, studio_id, users!class_owner_id(id, full_name))')
      .gte('starts_at', startOfDay.toIso8601String())
      .lt('starts_at', endOfDay.toIso8601String())
      .eq('courses.studio_id', studioId)
      .eq('status', 'active')
      .order('starts_at');

  return (response as List)
      .where((json) => json['courses'] != null)
      .map((json) => Lesson.fromJson(json as Map<String, dynamic>))
      .toList();
});

// Giorni del mese corrente che hanno almeno una lezione
final lessonDaysProvider =
    FutureProvider.family<Set<DateTime>, DateTime>((ref, month) async {
  final studioId = ref.watch(currentStudioIdProvider);
  if (studioId == null) return {};

  final client = ref.watch(supabaseClientProvider);
  final startOfMonth = DateTime(month.year, month.month, 1).toUtc();
  final endOfMonth = DateTime(month.year, month.month + 1, 1).toUtc();

  final response = await client
      .from('lessons')
      .select('starts_at, courses!inner(studio_id)')
      .gte('starts_at', startOfMonth.toIso8601String())
      .lt('starts_at', endOfMonth.toIso8601String())
      .eq('courses.studio_id', studioId)
      .eq('status', 'active');

  return (response as List)
      .where((json) => json['courses'] != null)
      .map((json) {
    final dt = DateTime.parse(json['starts_at'] as String).toLocal();
    return DateTime(dt.year, dt.month, dt.day);
  }).toSet();
});