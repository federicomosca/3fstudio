import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/booking/providers/booking_provider.dart';
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
      .eq('status', 'active')
      .gte('starts_at', now)
      .order('starts_at')
      .limit(20);
  return (data as List).cast<Map<String, dynamic>>();
});

/// Lesson ID delle lezioni di questo corso già prenotate dall'utente corrente.
final _myCourseLessonBookingsProvider =
    FutureProvider.family<Set<String>, String>((ref, courseId) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return {};
  final client = ref.watch(supabaseClientProvider);
  final now    = DateTime.now().toUtc().toIso8601String();
  final data   = await client
      .from('bookings')
      .select('lesson_id, lessons!inner(course_id, starts_at)')
      .eq('user_id', user.id)
      .eq('status', 'confirmed')
      .eq('lessons.course_id', courseId)
      .gte('lessons.starts_at', now);
  return (data as List).map((b) => b['lesson_id'] as String).toSet();
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
    final lessonsAsync  = ref.watch(_courseLessonsProvider(courseId));
    final isGroup       = course['type'] == 'group';
    final owner         = course['users'] as Map<String, dynamic>?;
    final desc          = course['description'] as String?;
    final cancelHours   = course['cancel_window_hours'] as int?;

    // Modalità cliente: route /client/
    final loc        = GoRouterState.of(context).matchedLocation;
    final clientMode = loc.startsWith('/client/');
    final bookedIds  = clientMode
        ? (ref.watch(_myCourseLessonBookingsProvider(courseId))
              .whenOrNull(data: (ids) => ids) ?? {})
        : const <String>{};

    void onBookingChanged() {
      ref.invalidate(_courseLessonsProvider(courseId));
      ref.invalidate(_myCourseLessonBookingsProvider(courseId));
    }

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
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withAlpha(150))),
                    ),
                  ),
                )
              : SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  sliver: SliverList.separated(
                    itemCount: lessons.length,
                    separatorBuilder: (context, i) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, i) => _LessonRow(
                      lesson: lessons[i],
                      clientMode: clientMode,
                      isBooked: bookedIds.contains(
                          lessons[i]['id'] as String),
                      onBookingChanged: onBookingChanged,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

// ── Lesson row ─────────────────────────────────────────────────────────────────

class _LessonRow extends ConsumerStatefulWidget {
  final Map<String, dynamic> lesson;
  final bool clientMode;
  final bool isBooked;
  final VoidCallback onBookingChanged;

  const _LessonRow({
    required this.lesson,
    required this.clientMode,
    required this.isBooked,
    required this.onBookingChanged,
  });

  @override
  ConsumerState<_LessonRow> createState() => _LessonRowState();
}

class _LessonRowState extends ConsumerState<_LessonRow> {
  bool _loading = false;

  Future<void> _book() async {
    setState(() => _loading = true);
    try {
      await ref
          .read(bookingNotifierProvider.notifier)
          .book(widget.lesson['id'] as String);
      widget.onBookingChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Prenotazione confermata!'),
            backgroundColor: Color(0xFF66BB6A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cancel() async {
    setState(() => _loading = true);
    try {
      await ref
          .read(bookingNotifierProvider.notifier)
          .cancel(widget.lesson['id'] as String);
      widget.onBookingChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Prenotazione annullata')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lesson   = widget.lesson;
    final start    = DateTime.parse(lesson['starts_at'] as String).toLocal();
    final end      = DateTime.parse(lesson['ends_at']   as String).toLocal();
    final cap      = lesson['capacity'] as int;
    final bookings = lesson['bookings'] as List? ?? [];
    final count    = bookings.isNotEmpty
        ? (bookings.first['count'] as int? ?? 0)
        : 0;
    final isFull   = count >= cap && !widget.isBooked;

    final dateFmt = DateFormat('EEE d MMM', 'it_IT');
    final timeFmt = DateFormat('HH:mm');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: widget.isBooked
            ? AppTheme.lime.withAlpha(15)
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.isBooked
              ? AppTheme.lime.withAlpha(120)
              : Theme.of(context).colorScheme.outline,
          width: widget.isBooked ? 1.5 : 1,
        ),
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

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dateFmt.format(start),
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  '${timeFmt.format(start)} – ${timeFmt.format(end)}',
                  style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withAlpha(180),
                      fontSize: 13),
                ),
              ],
            ),
          ),

          // Capacity badge (owner mode) / booking button (client mode)
          if (!widget.clientMode)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isFull
                    ? Theme.of(context).colorScheme.errorContainer
                    : AppTheme.lime.withAlpha(40),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$count/$cap',
                style: TextStyle(
                  color: isFull
                      ? Theme.of(context).colorScheme.onErrorContainer
                      : Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            )
          else ...[
            // Posti rimasti
            Text(
              '$count/$cap',
              style: TextStyle(
                fontSize: 12,
                color: isFull
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.onSurface.withAlpha(150),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 10),
            // Booking button
            SizedBox(
              height: 34,
              child: _loading
                  ? const SizedBox(
                      width: 34,
                      child: Center(
                          child: SizedBox(
                              width: 18,
                              height: 18,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2))))
                  : widget.isBooked
                      ? OutlinedButton(
                          onPressed: _cancel,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 0),
                            minimumSize: Size.zero,
                          ),
                          child: const Text('Annulla',
                              style: TextStyle(fontSize: 12)),
                        )
                      : ElevatedButton(
                          onPressed: isFull ? null : _book,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 0),
                            minimumSize: Size.zero,
                          ),
                          child: Text(
                            isFull ? 'Completo' : 'Prenota',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
            ),
          ],
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
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: Theme.of(context).colorScheme.onSurface.withAlpha(180),
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
          Icon(icon,
              size: 14,
              color: Theme.of(context).colorScheme.onSurface.withAlpha(180)),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
