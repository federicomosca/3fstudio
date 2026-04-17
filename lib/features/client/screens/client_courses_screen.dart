import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/course_type.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../core/providers/studio_provider.dart';
import '../widgets/credits_chip.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

/// Tutti i corsi dello studio
final _allCoursesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final studioId = ref.watch(currentStudioIdProvider);
  if (studioId == null) return [];
  final client = ref.watch(supabaseClientProvider);
  final data = await client
      .from('courses')
      .select(
          'id, name, type, description, '
          'users!class_owner_id(id, full_name, avatar_url)')
      .eq('studio_id', studioId)
      .order('name');
  return (data as List).cast<Map<String, dynamic>>();
});

/// ID dei corsi a cui il cliente è iscritto (ha almeno una prenotazione futura)
final _enrolledCourseIdsProvider =
    FutureProvider<Set<String>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return {};
  final client = ref.watch(supabaseClientProvider);
  final now    = DateTime.now().toUtc().toIso8601String();

  final data = await client
      .from('bookings')
      .select('lessons(course_id, starts_at)')
      .eq('user_id', user.id)
      .eq('status', 'confirmed');

  final ids = <String>{};
  for (final b in (data as List)) {
    final lesson = b['lessons'] as Map<String, dynamic>?;
    if (lesson == null) continue;
    final startsAt = lesson['starts_at'] as String?;
    if (startsAt != null && startsAt.compareTo(now) > 0) {
      final cid = lesson['course_id'] as String?;
      if (cid != null) ids.add(cid);
    }
  }
  return ids;
});

// ── Screen ────────────────────────────────────────────────────────────────────

class ClientCoursesScreen extends ConsumerWidget {
  const ClientCoursesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coursesAsync  = ref.watch(_allCoursesProvider);
    final enrolledAsync = ref.watch(_enrolledCourseIdsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Corsi'),
        actions: [
          const CreditsChip(),
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => context.push('/client/profile'),
          ),
        ],
      ),
      body: coursesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(
            child: Text('Errore: $e',
                style: const TextStyle(color: Colors.red))),
        data: (courses) {
          if (courses.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.fitness_center_outlined,
                      size: 56,
                      color: Theme.of(context).colorScheme.onSurface.withAlpha(60)),
                  const SizedBox(height: 12),
                  Text('Nessun corso disponibile',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withAlpha(150))),
                ],
              ),
            );
          }

          final enrolled = enrolledAsync.whenOrNull(data: (ids) => ids) ?? {};

          final myCourses   = courses.where((c) => enrolled.contains(c['id'])).toList();
          final otherCourses = courses.where((c) => !enrolled.contains(c['id'])).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── I miei corsi ──────────────────────────────────────────
              if (myCourses.isNotEmpty) ...[
                _SectionTitle('I miei corsi'),
                const SizedBox(height: 8),
                ...myCourses.map((c) => _CourseCard(
                      course: c, enrolled: true)),
                const SizedBox(height: 20),
              ],

              // ── Altri corsi ───────────────────────────────────────────
              _SectionTitle(
                myCourses.isEmpty ? 'Tutti i corsi' : 'Esplora altri corsi',
              ),
              const SizedBox(height: 8),
              if (otherCourses.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text('Sei già iscritto a tutti i corsi disponibili!',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withAlpha(150))),
                )
              else
                ...otherCourses.map((c) => _CourseCard(
                      course: c, enrolled: false)),
            ],
          );
        },
      ),
    );
  }
}

// ── Course card ───────────────────────────────────────────────────────────────

class _CourseCard extends StatelessWidget {
  final Map<String, dynamic> course;
  final bool enrolled;
  const _CourseCard({required this.course, required this.enrolled});

  @override
  Widget build(BuildContext context) {
    final courseType = course['type'] as String? ?? 'group';
    final owner   = course['users'] as Map<String, dynamic>?;
    final desc    = course['description'] as String?;

    return GestureDetector(
      onTap: () => context.push('/client/courses/${course['id']}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: enrolled ? AppTheme.lime.withAlpha(20) : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: enrolled
                ? AppTheme.lime.withAlpha(120)
                : Theme.of(context).colorScheme.outline,
            width: enrolled ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: enrolled
                    ? AppTheme.navy
                    : (courseType == 'personal'
                        ? const Color(0xFF9C27B0).withAlpha(30)
                        : AppTheme.blue.withAlpha(30)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                courseTypeIcon(courseType),
                color: enrolled
                    ? AppTheme.blue
                    : (courseType == 'personal' ? const Color(0xFFCE93D8) : AppTheme.blue),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          course['name'] as String,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      if (enrolled)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.blue,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text('Iscritto',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700)),
                        ),
                    ],
                  ),
                  if (owner != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      owner['full_name'] as String,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withAlpha(180), fontSize: 12),
                    ),
                  ],
                  if (desc != null && desc.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      desc,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withAlpha(150), fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: Theme.of(context).colorScheme.onSurface.withAlpha(100),
                size: 20),
          ],
        ),
      ),
    );
  }
}

// ── Helper ────────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: Theme.of(context).colorScheme.onSurface.withAlpha(180),
        letterSpacing: 0.4,
      ),
    );
  }
}
