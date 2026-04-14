import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/theme/app_theme.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../core/providers/studio_provider.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _ownerSelectedDayProvider =
    StateProvider<DateTime>((ref) => DateTime.now());

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
          'courses!inner(id, name, type), bookings(count)')
      .gte('starts_at', start)
      .lt('starts_at', end)
      .eq('courses.studio_id', studioId)
      .order('starts_at');

  return (data as List)
      .where((l) => l['courses'] != null)
      .cast<Map<String, dynamic>>()
      .toList();
});

final _pendingLessonsCountProvider = FutureProvider<int>((ref) async {
  final studioId = ref.watch(currentStudioIdProvider);
  if (studioId == null) return 0;
  final client = ref.watch(supabaseClientProvider);

  final data = await client
      .from('lessons')
      .select('id, courses!inner(studio_id)')
      .eq('status', 'pending')
      .eq('courses.studio_id', studioId);

  return (data as List).length;
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
      .select('id, name, type')
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
      .inFilter('role', ['trainer', 'class_owner', 'owner']);

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
    final pendingCount = ref.watch(_pendingLessonsCountProvider);
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
                ref.read(_ownerSelectedDayProvider.notifier).state = selected,
            onPageChanged: (focused) {
              ref.read(_ownerSelectedDayProvider.notifier).state = focused;
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      itemCount: list.length,
                      itemBuilder: (context, i) {
                        final l = list[i];
                        final course =
                            l['courses'] as Map<String, dynamic>;
                        final bookings = l['bookings'] as List? ?? [];
                        final count = bookings.isNotEmpty
                            ? (bookings.first['count'] as int? ?? 0)
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
                              ],
                            ),
                            subtitle: Text('$count/$cap iscritti'),
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
                                : TextButton(
                                    onPressed: () => context.push(
                                        '/owner/roster/${l['id']}'),
                                    child: const Text('Presenze'),
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
    ref.invalidate(_pendingLessonsCountProvider);
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
    ref.invalidate(_pendingLessonsCountProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Lezione rifiutata'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
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
          'id, starts_at, ends_at, capacity, review_note, '
          'courses!inner(id, name, studio_id), '
          'users!proposed_by(full_name)')
      .eq('status', 'pending')
      .eq('courses.studio_id', studioId)
      .order('starts_at');

  return (data as List).cast<Map<String, dynamic>>();
});

class PendingLessonsScreen extends ConsumerWidget {
  const PendingLessonsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lessons = ref.watch(_allPendingLessonsProvider);
    final theme = Theme.of(context);
    final dateFmt = DateFormat('EEE d MMM, HH:mm', 'it');

    return Scaffold(
      appBar: AppBar(title: const Text('Richieste in attesa')),
      body: lessons.when(
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
                    Text('Nessuna richiesta in attesa',
                        style: TextStyle(
                            color:
                                theme.colorScheme.onSurface.withAlpha(150))),
                  ],
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                separatorBuilder: (context, i) =>
                    const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final l = list[i];
                  final course = l['courses'] as Map<String, dynamic>;
                  final proposer = l['users'] as Map<String, dynamic>?;
                  final start =
                      DateTime.parse(l['starts_at'] as String).toLocal();
                  final cap = l['capacity'] as int? ?? 0;

                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.orange.withAlpha(120)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
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
                              child: Text(
                                course['name'] as String,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          dateFmt.format(start),
                          style: TextStyle(
                              color: theme.colorScheme.onSurface
                                  .withAlpha(180)),
                        ),
                        Text(
                          'Capacità: $cap posti',
                          style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface
                                  .withAlpha(150)),
                        ),
                        if (proposer != null)
                          Text(
                            'Proposta da: ${proposer['full_name']}',
                            style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurface
                                    .withAlpha(150)),
                          ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.check,
                                    size: 16,
                                    color: Color(0xFF66BB6A)),
                                label: const Text('Approva',
                                    style: TextStyle(
                                        color: Color(0xFF66BB6A))),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                      color: Color(0xFF66BB6A)),
                                ),
                                onPressed: () =>
                                    _approve(context, ref, l['id'] as String),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: Icon(Icons.close,
                                    size: 16,
                                    color: theme.colorScheme.error),
                                label: Text('Rifiuta',
                                    style: TextStyle(
                                        color: theme.colorScheme.error)),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                      color: theme.colorScheme.error),
                                ),
                                onPressed: () =>
                                    _reject(context, ref, l['id'] as String),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _approve(
      BuildContext context, WidgetRef ref, String lessonId) async {
    final client = ref.read(supabaseClientProvider);
    await client
        .from('lessons')
        .update({'status': 'active'})
        .eq('id', lessonId);
    ref.invalidate(_allPendingLessonsProvider);
    ref.invalidate(_pendingLessonsCountProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lezione approvata ✓'),
          backgroundColor: Color(0xFF66BB6A),
        ),
      );
    }
  }

  Future<void> _reject(
      BuildContext context, WidgetRef ref, String lessonId) async {
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
    final client = ref.read(supabaseClientProvider);
    await client.from('lessons').update({
      'status': 'rejected',
      if (noteCtrl.text.trim().isNotEmpty)
        'review_note': noteCtrl.text.trim(),
    }).eq('id', lessonId);
    ref.invalidate(_allPendingLessonsProvider);
    ref.invalidate(_pendingLessonsCountProvider);
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
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final d = widget.initialDate;
    _startTime = DateTime(d.year, d.month, d.day, 9, 0);
    _endTime = DateTime(d.year, d.month, d.day, 10, 0);
    _capCtrl.text = '10';
  }

  @override
  void dispose() {
    _capCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(isStart ? _startTime : _endTime),
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
      setState(() => _error = 'L\'orario di fine deve essere dopo l\'inizio');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final client = ref.read(supabaseClientProvider);
      await client.from('lessons').insert({
        'course_id':  _courseId,
        'trainer_id': _trainerId,
        'starts_at':  _startTime.toUtc().toIso8601String(),
        'ends_at':    _endTime.toUtc().toIso8601String(),
        'capacity':   int.tryParse(_capCtrl.text.trim()) ?? 10,
        if (_roomId != null) 'room_id': _roomId,
        'status':     'active',   // Owner crea direttamente come attiva
      });

      if (mounted) {
        Navigator.of(context).pop();
        widget.onCreated();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lezione creata!'),
            backgroundColor: Color(0xFF66BB6A),
          ),
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
                onChanged: (v) => setState(() => _courseId = v),
              ),
            ),
            const SizedBox(height: 12),

            // Sala
            rooms.when(
              loading: () => const SizedBox.shrink(),
              error: (e, _) => const SizedBox.shrink(),
              data: (list) => list.isEmpty
                  ? const SizedBox.shrink()
                  : DropdownButtonFormField<String?>(
                      initialValue: _roomId,
                      decoration: const InputDecoration(
                        labelText: 'Sala (opzionale)',
                        prefixIcon: Icon(Icons.meeting_room_outlined),
                      ),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('— Nessuna —')),
                        ...list.map((r) => DropdownMenuItem(
                              value: r['id'] as String,
                              child: Text(r['name'] as String),
                            )),
                      ],
                      onChanged: (v) => setState(() => _roomId = v),
                    ),
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
              decoration: const InputDecoration(
                labelText: 'Posti disponibili',
                prefixIcon: Icon(Icons.people_outline),
              ),
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
                    : const Text('Crea lezione'),
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
