import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/course_type.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/widgets/coming_soon.dart';

class _CourseEntry {
  final Map<String, dynamic> course;
  final bool isOwner;
  const _CourseEntry({required this.course, required this.isOwner});
}

final _myCoursesProvider = FutureProvider<List<_CourseEntry>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  final client = ref.watch(supabaseClientProvider);

  // Corsi di cui sono responsabile (class_owner)
  final ownerData = await client
      .from('courses')
      .select('id, name, type, cancel_window_hours')
      .eq('class_owner_id', user.id)
      .order('name');
  final ownerCourses = (ownerData as List).cast<Map<String, dynamic>>();
  final ownerIds = ownerCourses.map((c) => c['id'] as String).toSet();

  // Course IDs assegnati via lezioni
  final lessonData = await client
      .from('lessons')
      .select('course_id')
      .eq('trainer_id', user.id);
  final assignedIds = (lessonData as List)
      .map((l) => l['course_id'] as String)
      .toSet()
      .difference(ownerIds);

  List<Map<String, dynamic>> assignedCourses = [];
  if (assignedIds.isNotEmpty) {
    final extraData = await client
        .from('courses')
        .select('id, name, type, cancel_window_hours')
        .inFilter('id', assignedIds.toList())
        .order('name');
    assignedCourses = (extraData as List).cast<Map<String, dynamic>>();
  }

  return [
    ...ownerCourses.map((c) => _CourseEntry(course: c, isOwner: true)),
    ...assignedCourses.map((c) => _CourseEntry(course: c, isOwner: false)),
  ]..sort((a, b) =>
      (a.course['name'] as String).compareTo(b.course['name'] as String));
});

class MyCoursesScreen extends ConsumerWidget {
  const MyCoursesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courses = ref.watch(_myCoursesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('I miei corsi'),
      ),
      body: courses.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text('Errore: $e', style: const TextStyle(color: Colors.red))),
        data: (list) => list.isEmpty
            ? const ComingSoon(
                title: 'Nessun corso assegnato',
                icon: Icons.fitness_center_outlined,
                subtitle: 'Il gym owner ti assegnerà i corsi.',
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                separatorBuilder: (context, i) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final entry      = list[i];
                  final c          = entry.course;
                  final courseType = c['type'] as String? ?? 'group';
                  final window     = c['cancel_window_hours'] as int? ?? 24;

                  return ListTile(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    tileColor: Theme.of(context).colorScheme.surface,
                    leading: CircleAvatar(
                      backgroundColor: courseType == 'personal'
                          ? const Color(0xFF9C27B0).withAlpha(30)
                          : AppTheme.blue.withAlpha(30),
                      child: Icon(
                        courseTypeIcon(courseType),
                        color: courseType == 'personal'
                            ? const Color(0xFFCE93D8)
                            : AppTheme.blue,
                      ),
                    ),
                    title: Text(c['name'] as String),
                    subtitle: Text(
                      '${courseTypeLabel(courseType)} · cancella entro ${window}h'
                      '${entry.isOwner ? '' : ' · assegnato'}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/staff/courses/${c['id']}'),
                  );
                },
              ),
      ),
    );
  }
}
