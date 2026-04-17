import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/course_type.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/widgets/coming_soon.dart';

final _myCoursesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  final client = ref.watch(supabaseClientProvider);
  final data = await client
      .from('courses')
      .select('id, name, type, cancel_window_hours')
      .eq('class_owner_id', user.id)
      .order('name');
  return (data as List).cast<Map<String, dynamic>>();
});

class MyCoursesScreen extends ConsumerWidget {
  const MyCoursesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courses = ref.watch(_myCoursesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('I miei corsi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => context.push('/staff/profile'),
          ),
        ],
      ),
      body: courses.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text('Errore: $e', style: const TextStyle(color: Colors.red))),
        data: (list) => list.isEmpty
            ? const ComingSoon(
                title: 'Nessun corso assegnato',
                icon: Icons.fitness_center_outlined,
                subtitle: 'Il gym owner ti assegnerà i corsi di cui sei responsabile.',
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                separatorBuilder: (context, i) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final c       = list[i];
                  final courseType = c['type'] as String? ?? 'group';
                  final window  = c['cancel_window_hours'] as int? ?? 24;

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
                        color: courseType == 'personal' ? const Color(0xFFCE93D8) : AppTheme.blue,
                      ),
                    ),
                    title: Text(c['name'] as String),
                    subtitle: Text(
                        '${courseTypeLabel(courseType)} · cancella entro ${window}h'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/staff/courses/${c['id']}'),
                  );
                },
              ),
      ),
    );
  }
}
