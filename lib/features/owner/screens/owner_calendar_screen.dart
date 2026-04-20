import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/theme/app_theme.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../core/providers/studio_provider.dart';
import '../providers/pending_lessons_count_provider.dart';
import '../../../shared/widgets/recurring_section.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

class _OwnerSelectedDayNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => DateTime.now();
  void set(DateTime day) => state = day;
}

final _ownerSelectedDayProvider =
    NotifierProvider<_OwnerSelectedDayNotifier, DateTime>(_OwnerSelectedDayNotifier.new);

final _ownerLessonsForDayProvider =
    FutureProvider.family<List<Map<String, dynamic>>, DateTime>(
        (ref, date) async {
  final studioId = ref.watch(currentStudioIdProvider);
  if (studioId == null) return [];

  final client = ref.watch(supabaseClientProvider);
  final start =
      DateTime(date.year, date.month, date.day).toUtc().toIso8601String();
  final end = DateTime(date.year, date.month, date.day + 1)
      .toUtc()
      .toIso8601String();

  final data = await client
      .from('lessons')
      .select(
          'id, starts_at, ends_at, capacity, status, '
          'courses!inner(id, name, type), '
          'users!trainer_id(full_name), '
          'bookings(count), waitlist(count)')
      .gte('starts_at', start)
      .lt('starts_at', end)
      .eq('courses.studio_id', studioId)
      .order('starts_at');

  return (data as List)
      .where((l) => l['courses'] != null)
      .cast<Map<String, dynamic>>()
      .toList();
});


// ── Rooms & Courses for creation ──────────────────────────────────────────────

final _ownerRoomsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final studioId = ref.watch(currentStudioIdProvider);
  if (studioId == null) return [];
  final client = ref.watch(supabaseClientProvider);
  final data = await client
      .from('rooms')
      .select('id, name, capacity')
      .eq('studio_id', studioId)
      .order('name');
  return (data as List).cast<Map<String, dynamic>>();
});

final _ownerCoursesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final studioId = ref.watch(currentStudioIdProvider);
  if (studioId == null) return [];
  final client = ref.watch(supabaseClientProvider);
  final data = await client
      .from('courses')
      .select('id, name, type, class_owner_id')
      .eq('studio_id', studioId)
      .order('name');
  return (data as List).cast<Map<String, dynamic>>();
});

final _ownerTrainersProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final studioId = ref.watch(currentStudioIdProvider);
  if (studioId == null) return [];
  final client = ref.watch(supabaseClientProvider);

  final data = await client
      .from('user_studio_roles')
      .select('users(id, full_name)')
      .eq('studio_id', studioId)
      .inFilter('role', ['trainer', 'owner']);

  final Map<String, Map<String, dynamic>> byUser = {};
  for (final row in (data as List)) {
    final user = row['users'] as Map<String, dynamic>?;
    if (user == null) continue;
    byUser[user['id'] as String] ??= user;
  }
  return byUser.values.toList()
    ..sort((a, b) =>
        (a['full_name'] as String).compareTo(b['full_name'] as String));
});

// ── Screen ────────────────────────────────────────────────────────────────────

class OwnerCalendarScreen extends ConsumerWidget {
  const OwnerCalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDay = ref.watch(_ownerSelectedDayProvider);
    final lessons = ref.watch(_ownerLessonsForDayProvider(selectedDay));
    final pendingCount = ref.watch(pendingLessonsCountProvider);
    final timeFmt = DateFormat('HH:mm');
    final dayFmt = DateFormat('EEEE d MMMM', 'it_IT');
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendario'),
        actions: [
          // Badge richieste pending
          pendingCount.when(
            loading: () => const SizedBox.shrink(),
            error: (e, _) => const SizedBox.shrink(),
            data: (count) => count == 0
                ? const SizedBox.shrink()
                : Stack(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.pending_actions_outlined),
                        tooltip: 'Richieste in attesa',
                        onPressed: () => context.push('/owner/requests'),
                      ),
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.error,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '$count',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateLessonSheet(context, ref, selectedDay),
        icon: const Icon(Icons.add),
        label: const Text('Nuova lezione'),
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2024, 1, 1),
            lastDay: DateTime.utc(2027, 12, 31),
            focusedDay: selectedDay,
            selectedDayPredicate: (d) => isSameDay(d, selectedDay),
            calendarFormat: CalendarFormat.month,
            availableCalendarFormats: const {CalendarFormat.month: 'Mese'},
            locale: 'it_IT',
            startingDayOfWeek: StartingDayOfWeek.monday,
            headerStyle: const HeaderStyle(
                formatButtonVisible: false, titleCentered: true),
            calendarStyle: const CalendarStyle(
              todayDecoration: BoxDecoration(
                color: AppTheme.lime,
                shape: BoxShape.circle,
              ),
              todayTextStyle: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
              selectedDecoration: BoxDecoration(
                color: AppTheme.charcoal,
                shape: BoxShape.circle,
              ),
              selectedTextStyle: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
              weekendTextStyle: TextStyle(color: Color(0xFFAAAAAA)),
            ),
            onDaySelected: (selected, _) =>
                ref.read(_ownerSelectedDayProvider.notifier).set(selected),
            onPageChanged: (focused) {
              ref.read(_ownerSelectedDayProvider.notifier).set(focused);
            },
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                dayFmt.format(selectedDay),
                style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(180)),
              ),
            ),
          ),
          Expanded(
            child: lessons.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                  child: Text('Errore: $e',
                      style: const TextStyle(color: Colors.red))),
              data: (list) => list.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.event_busy,
                              size: 48,
                              color: theme.colorScheme.onSurface
                                  .withAlpha(60)),
                          const SizedBox(height: 12),
                          Text(
                            'Nessuna lezione',
                            style: TextStyle(
                                color: theme.colorScheme.onSurface
                                    .withAlpha(150)),
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            icon: const Icon(Icons.add),
                            label: const Text('Aggiungi lezione'),
                            onPressed: () => _showCreateLessonSheet(
                                context, ref, selectedDay),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      itemCount: list.length,
                      itemBuilder: (context, i) {
                        final l = list[i];
                        final course =
                            l['courses'] as Map<String, dynamic>;
                        final trainer =
                            (l['users'] as Map<String, dynamic>?)?['full_name'] as String?;
                        final bookings = l['bookings'] as List? ?? [];
                        final count = bookings.isNotEmpty
                            ? (bookings.first['count'] as int? ?? 0)
                            : 0;
                        final waitlist = l['waitlist'] as List? ?? [];
                        final wCount = waitlist.isNotEmpty
                            ? (waitlist.first['count'] as int? ?? 0)
                            : 0;
                        final cap = l['capacity'] as int? ?? 0;
                        final start = DateTime.parse(
                                l['starts_at'] as String)
                            .toLocal();
                        final end =
                            DateTime.parse(l['ends_at'] as String)
                                .toLocal();
                        final status = l['status'] as String? ?? 'active';
                        final isPending = status == 'pending';
                        final isDeletePending = status == 'delete_pending';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(timeFmt.format(start),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                Text(timeFmt.format(end),
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: theme.colorScheme.onSurface
                                            .withAlpha(150))),
                              ],
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                    child: Text(course['name'] as String)),
                                if (isPending)
                                  Container(
                                    margin: const EdgeInsets.only(left: 6),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withAlpha(40),
                                      borderRadius:
                                          BorderRadius.circular(4),
                                      border: Border.all(
                                          color:
                                              Colors.orange.withAlpha(120)),
                                    ),
                                    child: const Text(
                                      'In attesa',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: Color(0xFFFFB74D),
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                if (isDeletePending)
                                  Container(
                                    margin: const EdgeInsets.only(left: 6),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withAlpha(40),
                                      borderRadius:
                                          BorderRadius.circular(4),
                                      border: Border.all(
                                          color: Colors.red.withAlpha(120)),
                                    ),
                                    child: const Text(
                                      'Elim. richiesta',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.red,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: Text([
                              ?trainer,
                              wCount > 0
                                  ? '$count/$cap iscritti · $wCount in lista'
                                  : '$count/$cap iscritti',
                            ].join(' · ')),
                            trailing: isPending
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.check_circle_outline,
                                            color: Color(0xFF66BB6A)),
                                        tooltip: 'Approva',
                                        onPressed: () => _approveLesson(
                                            context, ref, l['id'] as String),
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.cancel_outlined,
                                            color:
                                                theme.colorScheme.error),
                                        tooltip: 'Rifiuta',
                                        onPressed: () => _rejectLesson(
                                            context, ref, l['id'] as String),
                                      ),
                                    ],
                                  )
                                : isDeletePending
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: Icon(Icons.delete_forever,
                                                color: theme.colorScheme.error),
                                            tooltip: 'Approva eliminazione',
                                            onPressed: () => _approveDeleteLesson(
                                                context, ref, l),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.restore,
                                                color: Color(0xFF66BB6A)),
                                            tooltip: 'Rifiuta eliminazione',
                                            onPressed: () => _rejectDeleteLesson(
                                                context, ref, l['id'] as String),
                                          ),
                                        ],
                                      )
                                    : PopupMenuButton<String>(
                                    onSelected: (v) {
                                      if (v == 'presenze') {
                                        context.push('/owner/roster/${l['id']}');
                                      } else if (v == 'delete') {
                                        _deleteLesson(context, ref, l);
                                      }
                                    },
                                    itemBuilder: (_) => [
                                      const PopupMenuItem(
                                        value: 'presenze',
                                        child: ListTile(
                                          leading: Icon(Icons.how_to_reg_outlined),
                                          title: Text('Presenze'),
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: ListTile(
                                          leading: Icon(Icons.delete_outline,
                                              color: Colors.red),
                                          title: Text('Elimina',
                                              style: TextStyle(color: Colors.red)),
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _approveLesson(
      BuildContext context, WidgetRef ref, String lessonId) async {
    final client = ref.read(supabaseClientProvider);
    await client
        .from('lessons')
        .update({'status': 'active'})
        .eq('id', lessonId);
    ref.invalidate(_ownerLessonsForDayProvider);
    ref.invalidate(pendingLessonsCountProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lezione approvata'),
          backgroundColor: Color(0xFF66BB6A),
        ),
      );
    }
  }

  Future<void> _rejectLesson(
      BuildContext context, WidgetRef ref, String lessonId) async {
    final noteCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rifiuta lezione'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Aggiungi una nota opzionale per il class owner:'),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Motivo (opzionale)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annulla')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Rifiuta',
                  style: TextStyle(
                      color: Theme.of(ctx).colorScheme.error))),
        ],
      ),
    );
    if (confirm != true) return;
    final client = ref.read(supabaseClientProvider);
    await client.from('lessons').update({
      'status': 'rejected',
      if (noteCtrl.text.trim().isNotEmpty)
        'review_note': noteCtrl.text.trim(),
    }).eq('id', lessonId);
    ref.invalidate(_ownerLessonsForDayProvider);
    ref.invalidate(pendingLessonsCountProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Lezione rifiutata'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _approveDeleteLesson(
      BuildContext context, WidgetRef ref, Map<String, dynamic> lesson) async {
    final client = ref.read(supabaseClientProvider);
    final lessonId = lesson['id'] as String;

    final result = await client
        .from('bookings')
        .select('id')
        .eq('lesson_id', lessonId)
        .count();
    final count = result.count;

    if (!context.mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approva eliminazione'),
        content: Text(
          count > 0
              ? 'Ci sono $count prenotazioni per questa lezione. '
                  'Eliminandola verranno cancellate anche le prenotazioni. Continuare?'
              : 'Confermi l\'eliminazione di questa lezione?',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annulla')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Elimina',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      if (count > 0) {
        await client.from('bookings').delete().eq('lesson_id', lessonId);
      }
      await client.from('lessons').delete().eq('id', lessonId);
      ref.invalidate(_ownerLessonsForDayProvider);
      ref.invalidate(pendingLessonsCountProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Lezione eliminata'),
              backgroundColor: Color(0xFF66BB6A)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Errore: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _rejectDeleteLesson(
      BuildContext context, WidgetRef ref, String lessonId) async {
    final client = ref.read(supabaseClientProvider);
    await client
        .from('lessons')
        .update({'status': 'active'})
        .eq('id', lessonId);
    ref.invalidate(_ownerLessonsForDayProvider);
    ref.invalidate(pendingLessonsCountProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Eliminazione rifiutata — lezione ripristinata'),
          backgroundColor: Color(0xFF66BB6A),
        ),
      );
    }
  }

  Future<void> _deleteLesson(
      BuildContext context, WidgetRef ref, Map<String, dynamic> lesson) async {
    final client   = ref.read(supabaseClientProvider);
    final lessonId = lesson['id'] as String;

    final bookingCount = await client
        .from('bookings')
        .select('id')
        .eq('lesson_id', lessonId)
        .count();
    final count = bookingCount.count;

    if (!context.mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Elimina lezione'),
        content: Text(
          count > 0
              ? 'Ci sono $count prenotazioni per questa lezione. '
                'Eliminando la lezione verranno cancellate anche le prenotazioni. Continuare?'
              : 'Sei sicuro di voler eliminare questa lezione?',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annulla')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Elimina',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      if (count > 0) {
        await client.from('bookings').delete().eq('lesson_id', lessonId);
      }
      await client.from('lessons').delete().eq('id', lessonId);
      ref.invalidate(_ownerLessonsForDayProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Lezione eliminata')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Errore: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _showCreateLessonSheet(
      BuildContext context, WidgetRef ref, DateTime date) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CreateLessonSheet(
        initialDate: date,
        onCreated: () {
          ref.invalidate(_ownerLessonsForDayProvider);
        },
      ),
    );
  }
}

// ── Pending lessons screen (standalone route) ─────────────────────────────────

final _allPendingLessonsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final studioId = ref.watch(currentStudioIdProvider);
  if (studioId == null) return [];
  final client = ref.watch(supabaseClientProvider);

  final data = await client
      .from('lessons')
      .select(
          'id, starts_at, ends_at, capacity, review_note, status, '
          'courses!inner(id, name, studio_id), '
          'users!proposed_by(full_name)')
      .inFilter('status', ['pending', 'delete_pending'])
      .eq('courses.studio_id', studioId)
      .order('starts_at');

  return (data as List).cast<Map<String, dynamic>>();
});

// Prenotazioni prova in attesa per lo studio corrente
final _allPendingTrialBookingsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final studioId = ref.watch(currentStudioIdProvider);
  if (studioId == null) return [];
  final client = ref.watch(supabaseClientProvider);

  final data = await client
      .from('bookings')
      .select(
          'id, lesson_id, '
          'users(id, full_name), '
          'lessons!inner(starts_at, ends_at, courses!inner(name, studio_id))')
      .eq('status', 'pending')
      .eq('is_trial', true)
      .eq('lessons.courses.studio_id', studioId)
      .order('created_at');

  return (data as List).cast<Map<String, dynamic>>();
});

class PendingLessonsScreen extends ConsumerWidget {
  const PendingLessonsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trialBookings = ref.watch(_allPendingTrialBookingsProvider);
    final trialCount = trialBookings.whenOrNull(data: (l) => l.length) ?? 0;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Richieste in attesa'),
          bottom: TabBar(
            tabs: [
              const Tab(text: 'Proposte lezioni'),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Lezioni di prova'),
                    if (trialCount > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('$trialCount',
                            style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _LessonProposalsTab(
              onApprove: (ctx, r, id, isDelete) => _approveLesson(ctx, r, id, isDelete: isDelete),
              onReject: (ctx, r, id, isDelete) => _rejectLesson(ctx, r, id, isDelete: isDelete),
            ),
            _TrialBookingsTab(
              onApprove: (ctx, r, id) => _approveTrial(ctx, r, id),
              onReject: (ctx, r, id) => _rejectTrial(ctx, r, id),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _approveLesson(
      BuildContext context, WidgetRef ref, String lessonId,
      {required bool isDelete}) async {
    final client = ref.read(supabaseClientProvider);
    if (isDelete) {
      final result = await client
          .from('bookings')
          .select('id')
          .eq('lesson_id', lessonId)
          .count();
      final count = result.count;
      if (!context.mounted) return;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Approva eliminazione'),
          content: Text(
            count > 0
                ? 'Ci sono $count prenotazioni per questa lezione. '
                    'Eliminandola verranno cancellate anche le prenotazioni. Continuare?'
                : "Confermi l'eliminazione di questa lezione?",
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annulla')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Elimina',
                    style: TextStyle(color: Colors.red))),
          ],
        ),
      );
      if (confirm != true) return;
      if (count > 0) {
        await client.from('bookings').delete().eq('lesson_id', lessonId);
      }
      await client.from('lessons').delete().eq('id', lessonId);
    } else {
      await client
          .from('lessons')
          .update({'status': 'active'})
          .eq('id', lessonId);
    }
    ref.invalidate(_allPendingLessonsProvider);
    ref.invalidate(pendingLessonsCountProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isDelete ? 'Lezione eliminata ✓' : 'Lezione approvata ✓'),
          backgroundColor: const Color(0xFF66BB6A),
        ),
      );
    }
  }

  Future<void> _rejectLesson(
      BuildContext context, WidgetRef ref, String lessonId,
      {required bool isDelete}) async {
    final client = ref.read(supabaseClientProvider);
    if (isDelete) {
      // Reject deletion request → restore to active
      await client
          .from('lessons')
          .update({'status': 'active'})
          .eq('id', lessonId);
      ref.invalidate(_allPendingLessonsProvider);
      ref.invalidate(pendingLessonsCountProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Eliminazione rifiutata — lezione ripristinata'),
            backgroundColor: Color(0xFF66BB6A),
          ),
        );
      }
      return;
    }
    final noteCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rifiuta lezione'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Nota per il class owner (opzionale):'),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Motivo',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annulla')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Rifiuta',
                  style: TextStyle(
                      color: Theme.of(ctx).colorScheme.error))),
        ],
      ),
    );
    if (confirm != true) return;
    await client.from('lessons').update({
      'status': 'rejected',
      if (noteCtrl.text.trim().isNotEmpty)
        'review_note': noteCtrl.text.trim(),
    }).eq('id', lessonId);
    ref.invalidate(_allPendingLessonsProvider);
    ref.invalidate(pendingLessonsCountProvider);
  }

  Future<void> _approveTrial(
      BuildContext context, WidgetRef ref, String bookingId) async {
    final client = ref.read(supabaseClientProvider);
    await client
        .from('bookings')
        .update({'status': 'confirmed'})
        .eq('id', bookingId);
    ref.invalidate(_allPendingTrialBookingsProvider);
    ref.invalidate(pendingLessonsCountProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Prenotazione approvata ✓'),
          backgroundColor: Color(0xFF66BB6A),
        ),
      );
    }
  }

  Future<void> _rejectTrial(
      BuildContext context, WidgetRef ref, String bookingId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rifiuta prenotazione prova'),
        content: const Text(
            'La richiesta verrà rifiutata. Il cliente non sarà iscritto alla lezione.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annulla')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Rifiuta',
                  style: TextStyle(
                      color: Theme.of(ctx).colorScheme.error))),
        ],
      ),
    );
    if (confirm != true) return;
    final client = ref.read(supabaseClientProvider);
    await client
        .from('bookings')
        .update({'status': 'cancelled'})
        .eq('id', bookingId);
    ref.invalidate(_allPendingTrialBookingsProvider);
    ref.invalidate(pendingLessonsCountProvider);
  }
}

// ── Tab: proposte di lezione ──────────────────────────────────────────────────

class _LessonProposalsTab extends ConsumerWidget {
  final Future<void> Function(BuildContext, WidgetRef, String, bool) onApprove;
  final Future<void> Function(BuildContext, WidgetRef, String, bool) onReject;

  const _LessonProposalsTab(
      {required this.onApprove, required this.onReject});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lessons = ref.watch(_allPendingLessonsProvider);
    final theme = Theme.of(context);
    final dateFmt = DateFormat('EEE d MMM, HH:mm', 'it');

    return lessons.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
          child: Text('Errore: $e',
              style: const TextStyle(color: Colors.red))),
      data: (list) => list.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.pending_actions_outlined,
                      size: 56,
                      color: theme.colorScheme.onSurface.withAlpha(60)),
                  const SizedBox(height: 12),
                  Text('Nessuna proposta in attesa',
                      style: TextStyle(
                          color: theme.colorScheme.onSurface.withAlpha(150))),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (context, i) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final l = list[i];
                final course = l['courses'] as Map<String, dynamic>;
                final proposer = l['users'] as Map<String, dynamic>?;
                final start =
                    DateTime.parse(l['starts_at'] as String).toLocal();
                final cap = l['capacity'] as int? ?? 0;
                final isDelete = l['status'] == 'delete_pending';
                final proposerLabel = proposer != null
                    ? ' · Da: ${proposer['full_name']}'
                    : '';
                return _PendingCard(
                  title: course['name'] as String,
                  subtitle: dateFmt.format(start),
                  detail: isDelete
                      ? 'Richiesta eliminazione$proposerLabel'
                      : 'Capacità: $cap posti$proposerLabel',
                  approveLabel: isDelete ? 'Elimina' : 'Approva',
                  rejectLabel: isDelete ? 'Mantieni' : 'Rifiuta',
                  approveDestructive: isDelete,
                  onApprove: () => onApprove(context, ref, l['id'] as String, isDelete),
                  onReject: () => onReject(context, ref, l['id'] as String, isDelete),
                );
              },
            ),
    );
  }
}

// ── Tab: prenotazioni prova ───────────────────────────────────────────────────

class _TrialBookingsTab extends ConsumerWidget {
  final Future<void> Function(BuildContext, WidgetRef, String) onApprove;
  final Future<void> Function(BuildContext, WidgetRef, String) onReject;

  const _TrialBookingsTab(
      {required this.onApprove, required this.onReject});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(_allPendingTrialBookingsProvider);
    final theme = Theme.of(context);
    final dateFmt = DateFormat('EEE d MMM, HH:mm', 'it');

    return bookings.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
          child: Text('Errore: $e',
              style: const TextStyle(color: Colors.red))),
      data: (list) => list.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.fitness_center_outlined,
                      size: 56,
                      color: theme.colorScheme.onSurface.withAlpha(60)),
                  const SizedBox(height: 12),
                  Text('Nessuna richiesta di prova in attesa',
                      style: TextStyle(
                          color: theme.colorScheme.onSurface.withAlpha(150))),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (context, i) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final b = list[i];
                final user = b['users'] as Map<String, dynamic>?;
                final lesson =
                    b['lessons'] as Map<String, dynamic>;
                final course =
                    lesson['courses'] as Map<String, dynamic>;
                final start =
                    DateTime.parse(lesson['starts_at'] as String).toLocal();
                return _PendingCard(
                  title: user?['full_name'] as String? ?? 'Cliente',
                  subtitle: '${course['name']} · ${dateFmt.format(start)}',
                  detail: 'Lezione di prova',
                  onApprove: () =>
                      onApprove(context, ref, b['id'] as String),
                  onReject: () =>
                      onReject(context, ref, b['id'] as String),
                );
              },
            ),
    );
  }
}

// ── Shared pending card ───────────────────────────────────────────────────────

class _PendingCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? detail;
  final String approveLabel;
  final String rejectLabel;
  final bool approveDestructive;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _PendingCard({
    required this.title,
    required this.subtitle,
    this.detail,
    this.approveLabel = 'Approva',
    this.rejectLabel = 'Rifiuta',
    this.approveDestructive = false,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withAlpha(120)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.orange.withAlpha(30),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'In attesa',
                  style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFFFFB74D),
                      fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style:
                        const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(subtitle,
              style: TextStyle(
                  color: theme.colorScheme.onSurface.withAlpha(180))),
          if (detail != null)
            Text(detail!,
                style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withAlpha(150))),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: Icon(approveDestructive ? Icons.delete_forever : Icons.check,
                      size: 16,
                      color: approveDestructive
                          ? theme.colorScheme.error
                          : const Color(0xFF66BB6A)),
                  label: Text(approveLabel,
                      style: TextStyle(
                          color: approveDestructive
                              ? theme.colorScheme.error
                              : const Color(0xFF66BB6A))),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                        color: approveDestructive
                            ? theme.colorScheme.error
                            : const Color(0xFF66BB6A)),
                  ),
                  onPressed: onApprove,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  icon: Icon(approveDestructive ? Icons.restore : Icons.close,
                      size: 16,
                      color: approveDestructive
                          ? const Color(0xFF66BB6A)
                          : theme.colorScheme.error),
                  label: Text(rejectLabel,
                      style: TextStyle(
                          color: approveDestructive
                              ? const Color(0xFF66BB6A)
                              : theme.colorScheme.error)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                        color: approveDestructive
                            ? const Color(0xFF66BB6A)
                            : theme.colorScheme.error),
                  ),
                  onPressed: onReject,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Create lesson sheet ───────────────────────────────────────────────────────

class _CreateLessonSheet extends ConsumerStatefulWidget {
  final DateTime initialDate;
  final VoidCallback onCreated;

  const _CreateLessonSheet({
    required this.initialDate,
    required this.onCreated,
  });

  @override
  ConsumerState<_CreateLessonSheet> createState() =>
      _CreateLessonSheetState();
}

class _CreateLessonSheetState extends ConsumerState<_CreateLessonSheet> {
  String? _courseId;
  String? _roomId;
  String? _trainerId;
  late DateTime _startTime;
  late DateTime _endTime;
  final _capCtrl = TextEditingController();
  int? _maxCapacity;
  bool _loading = false;
  String? _error;
  Set<String> _occupiedRoomIds = {};

  // Recurring
  bool _isRecurring = false;
  final Set<int> _recurDays = {}; // 1=Mon … 7=Sun (ISO weekday)
  late DateTime _recurUntil;

  @override
  void initState() {
    super.initState();
    final d = widget.initialDate;
    _startTime = DateTime(d.year, d.month, d.day, 9, 0);
    _endTime = DateTime(d.year, d.month, d.day, 10, 0);
    _recurUntil = d.add(const Duration(days: 28));
    _capCtrl.text = '10';
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadOccupiedRooms());
  }

  @override
  void dispose() {
    _capCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadOccupiedRooms() async {
    if (!_endTime.isAfter(_startTime)) return;
    final client = ref.read(supabaseClientProvider);
    final result = await client
        .from('lessons')
        .select('room_id')
        .not('room_id', 'is', null)
        .neq('status', 'rejected')
        .lt('starts_at', _endTime.toUtc().toIso8601String())
        .gt('ends_at', _startTime.toUtc().toIso8601String());
    if (!mounted) return;
    final ids = (result as List).map((r) => r['room_id'] as String).toSet();
    setState(() {
      _occupiedRoomIds = ids;
      if (_roomId != null && ids.contains(_roomId)) _roomId = null;
    });
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(isStart ? _startTime : _endTime),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startTime = DateTime(
          _startTime.year, _startTime.month, _startTime.day,
          picked.hour, picked.minute,
        );
        // Auto-advance end time by 1h
        if (!_endTime.isAfter(_startTime)) {
          _endTime = _startTime.add(const Duration(hours: 1));
        }
      } else {
        _endTime = DateTime(
          _endTime.year, _endTime.month, _endTime.day,
          picked.hour, picked.minute,
        );
      }
    });
    _loadOccupiedRooms();
  }

  List<DateTime> _occurrences() {
    final dates = <DateTime>[];
    if (!_isRecurring || _recurDays.isEmpty) {
      dates.add(_startTime);
    } else {
      var cursor = DateTime(
          widget.initialDate.year, widget.initialDate.month, widget.initialDate.day);
      final until = DateTime(_recurUntil.year, _recurUntil.month, _recurUntil.day, 23, 59);
      while (!cursor.isAfter(until)) {
        if (_recurDays.contains(cursor.weekday)) {
          dates.add(DateTime(
            cursor.year, cursor.month, cursor.day,
            _startTime.hour, _startTime.minute,
          ));
        }
        cursor = cursor.add(const Duration(days: 1));
      }
    }
    return dates;
  }

  Future<void> _submit() async {
    if (_courseId == null) {
      setState(() => _error = 'Seleziona un corso');
      return;
    }
    if (_trainerId == null) {
      setState(() => _error = 'Seleziona un trainer');
      return;
    }
    if (!_endTime.isAfter(_startTime)) {
      setState(() => _error = "L'orario di fine deve essere dopo l'inizio");
      return;
    }
    if (_isRecurring && _recurDays.isEmpty) {
      setState(() => _error = 'Seleziona almeno un giorno della settimana');
      return;
    }
    final capacity = int.tryParse(_capCtrl.text.trim()) ?? 0;
    if (_maxCapacity != null && capacity > _maxCapacity!) {
      setState(() => _error = 'I posti non possono superare la capienza dello spazio ($_maxCapacity)');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final client = ref.read(supabaseClientProvider);
      final duration = _endTime.difference(_startTime);
      final occurrences = _occurrences();

      if (_roomId != null) {
        for (final start in occurrences) {
          final end = start.add(duration);
          final conflicts = await client
              .from('lessons')
              .select('id')
              .eq('room_id', _roomId!)
              .neq('status', 'rejected')
              .lt('starts_at', end.toUtc().toIso8601String())
              .gt('ends_at', start.toUtc().toIso8601String());
          if ((conflicts as List).isNotEmpty) {
            final dateFmt = DateFormat('d MMM', 'it_IT');
            throw Exception('Conflitto sala il ${dateFmt.format(start)}');
          }
        }
      }

      final rows = occurrences.map((start) {
        final end = start.add(duration);
        return {
          'course_id':  _courseId,
          'trainer_id': _trainerId,
          'starts_at':  start.toUtc().toIso8601String(),
          'ends_at':    end.toUtc().toIso8601String(),
          'capacity':   capacity == 0 ? 10 : capacity,
          if (_roomId != null) 'room_id': _roomId,
          'status':     'active',
        };
      }).toList();

      await client.from('lessons').insert(rows);

      if (mounted) {
        Navigator.of(context).pop();
        widget.onCreated();
        final msg = occurrences.length == 1
            ? 'Lezione creata!'
            : '${occurrences.length} lezioni create!';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: const Color(0xFF66BB6A)),
        );
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final courses = ref.watch(_ownerCoursesProvider);
    final rooms = ref.watch(_ownerRoomsProvider);
    final trainers = ref.watch(_ownerTrainersProvider);
    final timeFmt = DateFormat('HH:mm');
    final dateFmt = DateFormat('EEE d MMM', 'it');

    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Nuova lezione',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            Text(dateFmt.format(widget.initialDate),
                style: TextStyle(
                    color: theme.colorScheme.onSurface.withAlpha(150))),
            const SizedBox(height: 24),

            // Corso
            courses.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => const SizedBox.shrink(),
              data: (list) => DropdownButtonFormField<String?>(
                initialValue: _courseId,
                decoration: const InputDecoration(
                  labelText: 'Corso',
                  prefixIcon: Icon(Icons.fitness_center_outlined),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('— Seleziona —')),
                  ...list.map((c) => DropdownMenuItem(
                        value: c['id'] as String,
                        child: Text(c['name'] as String),
                      )),
                ],
                onChanged: (v) {
                  final classOwnerId = v == null
                      ? null
                      : list.firstWhere((c) => c['id'] == v,
                              orElse: () => {})['class_owner_id'] as String?;
                  setState(() {
                    _courseId = v;
                    if (classOwnerId != null) _trainerId = classOwnerId;
                  });
                },
              ),
            ),
            const SizedBox(height: 12),

            // Spazio
            rooms.when(
              loading: () => const SizedBox.shrink(),
              error: (e, _) => const SizedBox.shrink(),
              data: (list) {
                if (list.isEmpty) return const SizedBox.shrink();
                final available = list
                    .where((r) => !_occupiedRoomIds.contains(r['id'] as String))
                    .toList();
                final allOccupied = available.isEmpty;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String?>(
                      initialValue: _roomId,
                      decoration: const InputDecoration(
                        labelText: 'Spazio (opzionale)',
                        prefixIcon: Icon(Icons.place_outlined),
                      ),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('— Nessuna —')),
                        ...available.map((r) => DropdownMenuItem(
                              value: r['id'] as String,
                              child: Text('${r['name']} (max ${r['capacity']})'),
                            )),
                      ],
                      onChanged: (v) {
                        setState(() {
                          _roomId = v;
                          if (v != null) {
                            final room = list.firstWhere((r) => r['id'] == v);
                            final cap = room['capacity'] as int? ?? 10;
                            _maxCapacity = cap;
                            _capCtrl.text = cap.toString();
                          } else {
                            _maxCapacity = null;
                          }
                        });
                      },
                    ),
                    if (allOccupied) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const SizedBox(width: 12),
                          Icon(Icons.warning_amber_rounded,
                              size: 14,
                              color: Theme.of(context).colorScheme.error),
                          const SizedBox(width: 4),
                          Text(
                            'Tutte le sale sono occupate in questo orario',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 12),

            // Trainer
            trainers.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => const SizedBox.shrink(),
              data: (list) => DropdownButtonFormField<String?>(
                initialValue: _trainerId,
                decoration: const InputDecoration(
                  labelText: 'Trainer',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('— Seleziona —')),
                  ...list.map((t) => DropdownMenuItem(
                        value: t['id'] as String,
                        child: Text(t['full_name'] as String),
                      )),
                ],
                onChanged: (v) => setState(() => _trainerId = v),
              ),
            ),
            const SizedBox(height: 12),

            // Orari
            Row(
              children: [
                Expanded(
                  child: _TimeButton(
                    label: 'Inizio',
                    time: timeFmt.format(_startTime),
                    onTap: () => _pickTime(isStart: true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TimeButton(
                    label: 'Fine',
                    time: timeFmt.format(_endTime),
                    onTap: () => _pickTime(isStart: false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Capacità
            TextFormField(
              controller: _capCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Posti disponibili',
                prefixIcon: const Icon(Icons.people_outline),
                helperText: _maxCapacity != null
                    ? 'Massimo $_maxCapacity (capienza spazio)'
                    : null,
                helperStyle: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Ricorrenza
            RecurringSection(
              isRecurring: _isRecurring,
              recurDays: _recurDays,
              recurUntil: _recurUntil,
              onToggle: (v) => setState(() {
                _isRecurring = v;
                if (v && _recurDays.isEmpty) {
                  _recurDays.add(widget.initialDate.weekday);
                }
              }),
              onDayToggled: (day) => setState(() {
                if (_recurDays.contains(day)) {
                  _recurDays.remove(day);
                } else {
                  _recurDays.add(day);
                }
              }),
              onPickUntil: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _recurUntil,
                  firstDate: widget.initialDate,
                  lastDate: widget.initialDate.add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => _recurUntil = picked);
              },
              occurrenceCount: _isRecurring ? _occurrences().length : null,
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_error!,
                    style: TextStyle(
                        color: theme.colorScheme.onErrorContainer,
                        fontSize: 13)),
              ),
            ],

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_isRecurring && _recurDays.isNotEmpty
                        ? 'Crea ${_occurrences().length} lezioni'
                        : 'Crea lezione'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeButton extends StatelessWidget {
  final String label;
  final String time;
  final VoidCallback onTap;

  const _TimeButton({
    required this.label,
    required this.time,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(Icons.access_time_outlined,
                size: 18,
                color: theme.colorScheme.onSurface.withAlpha(150)),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurface.withAlpha(150))),
                Text(time,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
