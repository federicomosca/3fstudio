import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../features/auth/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _courseDetailProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, courseId) async {
  final client = ref.watch(supabaseClientProvider);
  final data   = await client
      .from('courses')
      .select('id, name, type, cancel_window_hours, description, users!class_owner_id(id, full_name)')
      .eq('id', courseId)
      .maybeSingle();
  return data;
});

final _courseLessonsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, courseId) async {
  final client = ref.watch(supabaseClientProvider);
  final now    = DateTime.now().toUtc().toIso8601String();
  final data   = await client
      .from('lessons')
      .select('id, starts_at, ends_at, capacity, bookings(count)')
      .eq('course_id', courseId)
      .gte('starts_at', now)
      .order('starts_at')
      .limit(20);
  return (data as List).cast<Map<String, dynamic>>();
});

// ── Screen ────────────────────────────────────────────────────────────────────

class CourseDetailScreen extends ConsumerWidget {
  final String courseId;
  const CourseDetailScreen({super.key, required this.courseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courseAsync = ref.watch(_courseDetailProvider(courseId));

    return Scaffold(
      body: courseAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(
            child: Text('Errore: $e',
                style: const TextStyle(color: Colors.red))),
        data: (course) => course == null
            ? const Center(child: Text('Corso non trovato'))
            : _CourseBody(courseId: courseId, course: course),
      ),
    );
  }
}

class _CourseBody extends ConsumerWidget {
  final String courseId;
  final Map<String, dynamic> course;
  const _CourseBody({required this.courseId, required this.course});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lessonsAsync = ref.watch(_courseLessonsProvider(courseId));
    final isGroup      = course['type'] == 'group';
    final owner        = course['users'] as Map<String, dynamic>?;
    final desc         = course['description'] as String?;
    final cancelHours  = course['cancel_window_hours'] as int?;

    return CustomScrollView(
      slivers: [
        // ── AppBar ────────────────────────────────────────────────────────
        SliverAppBar(
          expandedHeight: 160,
          pinned: true,
          backgroundColor: AppTheme.charcoal,
          foregroundColor: Colors.white,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              color: AppTheme.charcoal,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 60),
                    CircleAvatar(
                      radius: 30,
                      backgroundColor:
                          isGroup ? Colors.blue.shade400 : Colors.purple.shade400,
                      child: Icon(
                        isGroup ? Icons.group_outlined : Icons.person_outline,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      course['name'] as String,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // ── Info cards ────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // Chips info
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: [
                    _InfoChip(
                      icon: isGroup ? Icons.group_outlined : Icons.person_outline,
                      label: isGroup ? 'Collettivo' : 'Personal',
                    ),
                    if (owner != null)
                      _InfoChip(
                        icon: Icons.manage_accounts_outlined,
                        label: owner['full_name'] as String,
                      ),
                    if (cancelHours != null)
                      _InfoChip(
                        icon: Icons.timer_outlined,
                        label: 'Disdetta entro $cancelHours h',
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Descrizione
                if (desc != null && desc.isNotEmpty) ...[
                  _SectionTitle('Descrizione'),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Theme.of(context).colorScheme.outline),
                    ),
                    child: Text(desc,
                        style: const TextStyle(height: 1.6, fontSize: 15)),
                  ),
                  const SizedBox(height: 20),
                ],

                // Prossime lezioni
                _SectionTitle('Prossime lezioni'),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),

        // ── Lessons list ──────────────────────────────────────────────────
        lessonsAsync.when(
          loading: () => const SliverToBoxAdapter(
              child: Center(child: CircularProgressIndicator())),
          error: (e, _) => SliverToBoxAdapter(
              child: Text('Errore lezioni: $e',
                  style: const TextStyle(color: Colors.red))),
          data: (lessons) => lessons.isEmpty
              ? SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text('Nessuna lezione in programma',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withAlpha(150))),
                    ),
                  ),
                )
              : SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  sliver: SliverList.separated(
                    itemCount: lessons.length,
                    separatorBuilder: (context, i) => const SizedBox(height: 8),
                    itemBuilder: (context, i) =>
                        _LessonRow(lesson: lessons[i]),
                  ),
                ),
        ),
      ],
    );
  }
}

// ── Lesson row ─────────────────────────────────────────────────────────────────

class _LessonRow extends StatelessWidget {
  final Map<String, dynamic> lesson;
  const _LessonRow({required this.lesson});

  @override
  Widget build(BuildContext context) {
    final start    = DateTime.parse(lesson['starts_at'] as String).toLocal();
    final end      = DateTime.parse(lesson['ends_at']   as String).toLocal();
    final cap      = lesson['capacity'] as int;
    final bookings = lesson['bookings'] as List? ?? [];
    final count    = bookings.isNotEmpty
        ? (bookings.first['count'] as int? ?? 0)
        : 0;
    final isFull   = count >= cap;

    final dateFmt  = DateFormat('EEE d MMM', 'it_IT');
    final timeFmt  = DateFormat('HH:mm');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Row(
        children: [
          // Date block
          Container(
            width: 44,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.charcoal,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  start.day.toString(),
                  style: const TextStyle(
                    color: AppTheme.lime,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  DateFormat('MMM', 'it_IT').format(start).toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dateFmt.format(start),
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  '${timeFmt.format(start)} – ${timeFmt.format(end)}',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withAlpha(180), fontSize: 13),
                ),
              ],
            ),
          ),
          // Capacity badge
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isFull
                  ? Colors.red.shade50
                  : AppTheme.lime.withAlpha(40),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count/$cap',
              style: TextStyle(
                color: isFull ? Colors.red.shade700 : AppTheme.charcoal,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: AppTheme.charcoal,
          letterSpacing: 0.5,
        ));
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.charcoal),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
