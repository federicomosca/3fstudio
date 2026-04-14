import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/lesson.dart';
import '../../auth/providers/auth_provider.dart';

final selectedDayProvider = StateProvider<DateTime>((ref) => DateTime.now());

final lessonsForDayProvider =
    FutureProvider.family<List<Lesson>, DateTime>((ref, date) async {
  final client = ref.watch(supabaseClientProvider);
  final startOfDay = DateTime(date.year, date.month, date.day).toUtc();
  final endOfDay = startOfDay.add(const Duration(days: 1));

  final response = await client
      .from('lessons')
      .select('*, courses(name, type)')
      .gte('starts_at', startOfDay.toIso8601String())
      .lt('starts_at', endOfDay.toIso8601String())
      .order('starts_at');

  return (response as List)
      .map((json) => Lesson.fromJson(json as Map<String, dynamic>))
      .toList();
});

// Giorni del mese corrente che hanno almeno una lezione
final lessonDaysProvider =
    FutureProvider.family<Set<DateTime>, DateTime>((ref, month) async {
  final client = ref.watch(supabaseClientProvider);
  final startOfMonth = DateTime(month.year, month.month, 1).toUtc();
  final endOfMonth = DateTime(month.year, month.month + 1, 1).toUtc();

  final response = await client
      .from('lessons')
      .select('starts_at')
      .gte('starts_at', startOfMonth.toIso8601String())
      .lt('starts_at', endOfMonth.toIso8601String());

  return (response as List).map((json) {
    final dt = DateTime.parse(json['starts_at'] as String).toLocal();
    return DateTime(dt.year, dt.month, dt.day);
  }).toSet();
});