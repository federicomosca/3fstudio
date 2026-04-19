import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/theme/app_theme.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../core/providers/studio_provider.dart';

// ── Providers ────────────────────────────────────────────────────────────────

class _StaffSelectedDayNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => DateTime.now();
  void set(DateTime day) => state = day;
}

final _staffSelectedDayProvider =
    NotifierProvider<_StaffSelectedDayNotifier, DateTime>(_StaffSelectedDayNotifier.new);

final _staffLessonsForDayProvider =
    FutureProvider.family<List<Map<String, dynamic>>, DateTime>((ref, date) async {
  final studioId = ref.watch(currentStudioIdProvider);
  if (studioId == null) return [];

  final client = ref.watch(supabaseClientProvider);
  final start  = DateTime(date.year, date.month, date.day).toUtc().toIso8601String();
  final end    = DateTime(date.year, date.month, date.day + 1).toUtc().toIso8601String();

  final data = await client
      .from('lessons')
      .select('id, starts_at, ends_at, capacity, status, trainer_id, courses!inner(name, type, class_owner_id, studio_id), bookings(count), waitlist(count)')
      .gte('starts_at', start)
      .lt('starts_at', end)
      .eq('courses.studio_id', studioId)
      .order('starts_at');

  return (data as List)
      .where((l) => l['courses'] != null)
      .cast<Map<String, dynamic>>()
      .toList();
});

// ── Class-owner course/room providers for lesson proposals ────────────────────

final _myOwnedCoursesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final user     = ref.watch(currentUserProvider);
  final studioId = ref.watch(currentStudioIdProvider);
  if (user == null || studioId == null) return [];
  final client = ref.watch(supabaseClientProvider);
  final data = await client
      .from('courses')
      .select('id, name, type')
      .eq('class_owner_id', user.id)
      .eq('studio_id', studioId)
      .order('name');
  return (data as List).cast<Map<String, dynamic>>();
});

final _staffRoomsProvider =
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

// ── Screen ───────────────────────────────────────────────────────────────────

class StaffCalendarScreen extends ConsumerStatefulWidget {
  const StaffCalendarScreen({super.key});

  @override
  ConsumerState<StaffCalendarScreen> createState() => _StaffCalendarScreenState();
}

class _StaffCalendarScreenState extends ConsumerState<StaffCalendarScreen> {
  @override
  Widget build(BuildContext context) {
    final selectedDay  = ref.watch(_staffSelectedDayProvider);
    final lessons      = ref.watch(_staffLessonsForDayProvider(selectedDay));
    final ownedCourses = ref.watch(_myOwnedCoursesProvider).whenOrNull(data: (c) => c) ?? [];
    final isCourseOwner = ownedCourses.isNotEmpty;
    final user         = ref.watch(currentUserProvider);
    final timeFmt      = DateFormat('HH:mm');
    final dayFmt      = DateFormat('EEEE d MMMM', 'it_IT');
    final theme       = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendario'),
        actions: const [],
      ),
      floatingActionButton: isCourseOwner
          ? FloatingActionButton.extended(
              onPressed: () => _showProposeSheet(context, selectedDay),
              icon: const Icon(Icons.add),
              label: const Text('Proponi lezione'),
            )
          : null,
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
              markerDecoration: BoxDecoration(
                color: AppTheme.lime,
                shape: BoxShape.circle,
              ),
              markerSize: 5,
              weekendTextStyle: TextStyle(color: Color(0xFFAAAAAA)),
            ),
            onDaySelected: (selected, _) =>
                ref.read(_staffSelectedDayProvider.notifier).set(selected),
            onPageChanged: (focused) {
              ref.read(_staffSelectedDayProvider.notifier).set(focused);
            },
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(dayFmt.format(selectedDay),
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withAlpha(180))),
            ),
          ),
          Expanded(
            child: lessons.when(
              loading: () => const Center(child: CircularProgressIndicator()),
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
                              color: theme.colorScheme.onSurface.withAlpha(60)),
                          const SizedBox(height: 12),
                          Text('Nessuna lezione',
                              style: TextStyle(
                                  color: theme.colorScheme.onSurface.withAlpha(150))),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.fromLTRB(
                          16, 8, 16, isCourseOwner ? 96 : 8),
                      itemCount: list.length,
                      itemBuilder: (context, i) {
                        final l       = list[i];
                        final course  = l['courses'] as Map<String, dynamic>;
                        final bookings = l['bookings'] as List? ?? [];
                        final count   = bookings.isNotEmpty
                            ? int.tryParse(
                                    bookings.first['count'].toString()) ??
                                0
                            : 0;
                        final waitlist = l['waitlist'] as List? ?? [];
                        final wCount  = waitlist.isNotEmpty
                            ? (waitlist.first['count'] as int? ?? 0)
                            : 0;
                        final cap       = l['capacity'] as int;
                        final start     = DateTime.parse(l['starts_at'] as String).toLocal();
                        final end       = DateTime.parse(l['ends_at'] as String).toLocal();
                        final status = (l['status'] as String?) ?? 'active';
                        final isPending = status == 'pending';
                        final isDeletePending = status == 'delete_pending';
                        final isCourseOwnerForThis =
                            course['class_owner_id'] == user?.id;
                        final isMyLesson = l['trainer_id'] == user?.id || isCourseOwnerForThis;

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
                                        color: Theme.of(context).colorScheme.onSurface.withAlpha(150))),
                              ],
                            ),
                            title: Row(
                              children: [
                                Expanded(child: Text(course['name'] as String)),
                                if (isPending)
                                  Container(
                                    margin: const EdgeInsets.only(left: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withAlpha(40),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Text(
                                      'In attesa',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFFFFB74D),
                                      ),
                                    ),
                                  ),
                                if (isDeletePending)
                                  Container(
                                    margin: const EdgeInsets.only(left: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withAlpha(40),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Text(
                                      'Elim. richiesta',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: Text(wCount > 0
                                ? '$count/$cap iscritti · $wCount in lista'
                                : '$count/$cap iscritti'),
                            trailing: isPending || isDeletePending || !isMyLesson
                                ? null
                                : PopupMenuButton<String>(
                                    onSelected: (v) {
                                      if (v == 'presenze') {
                                        context.push('/staff/roster/${l['id']}');
                                      } else if (v == 'delete') {
                                        _deleteDirectLesson(context, ref, l);
                                      } else if (v == 'propose_delete') {
                                        _proposeDeleteLesson(context, ref, l['id'] as String);
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
                                      if (isCourseOwnerForThis)
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: ListTile(
                                            leading: Icon(Icons.delete_outline,
                                                color: Colors.red),
                                            title: Text('Elimina',
                                                style: TextStyle(color: Colors.red)),
                                            contentPadding: EdgeInsets.zero,
                                          ),
                                        )
                                      else
                                        const PopupMenuItem(
                                          value: 'propose_delete',
                                          child: ListTile(
                                            leading: Icon(Icons.delete_sweep_outlined),
                                            title: Text('Proponi eliminazione'),
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

  Future<void> _proposeDeleteLesson(
      BuildContext context, WidgetRef ref, String lessonId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Proponi eliminazione'),
        content: const Text(
            "Vuoi richiedere l'eliminazione di questa lezione? L'owner dovrà approvare."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annulla')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Richiedi',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    final client = ref.read(supabaseClientProvider);
    await client
        .from('lessons')
        .update({'status': 'delete_pending'})
        .eq('id', lessonId);
    ref.invalidate(_staffLessonsForDayProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Richiesta di eliminazione inviata all'owner"),
          backgroundColor: Color(0xFFFFB74D),
        ),
      );
    }
  }

  Future<void> _deleteDirectLesson(
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
        title: const Text('Elimina lezione'),
        content: Text(
          count > 0
              ? 'Ci sono $count prenotazioni per questa lezione. '
                  'Eliminandola verranno cancellate anche le prenotazioni. Continuare?'
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
      ref.invalidate(_staffLessonsForDayProvider);
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

  void _showProposeSheet(BuildContext context, DateTime date) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ProposeLessonSheet(
        initialDate: date,
        onProposed: () => ref.invalidate(_staffLessonsForDayProvider),
      ),
    );
  }
}

// ── Propose lesson sheet (class_owner) ────────────────────────────────────────

class _ProposeLessonSheet extends ConsumerStatefulWidget {
  final DateTime initialDate;
  final VoidCallback onProposed;
  const _ProposeLessonSheet(
      {required this.initialDate, required this.onProposed});

  @override
  ConsumerState<_ProposeLessonSheet> createState() =>
      _ProposeLessonSheetState();
}

class _ProposeLessonSheetState extends ConsumerState<_ProposeLessonSheet> {
  String? _courseId;
  String? _roomId;
  late DateTime _startTime;
  late DateTime _endTime;
  final _capCtrl = TextEditingController();
  int? _maxCapacity; // capienza massima dello spazio selezionato
  bool _loading = false;
  String? _error;
  Set<String> _occupiedRoomIds = {};

  @override
  void initState() {
    super.initState();
    final d = widget.initialDate;
    _startTime = DateTime(d.year, d.month, d.day, 9, 0);
    _endTime = DateTime(d.year, d.month, d.day, 10, 0);
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
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startTime = DateTime(_startTime.year, _startTime.month,
            _startTime.day, picked.hour, picked.minute);
        if (!_endTime.isAfter(_startTime)) {
          _endTime = _startTime.add(const Duration(hours: 1));
        }
      } else {
        _endTime = DateTime(_endTime.year, _endTime.month, _endTime.day,
            picked.hour, picked.minute);
      }
    });
    _loadOccupiedRooms();
  }

  Future<void> _submit() async {
    if (_courseId == null) {
      setState(() => _error = 'Seleziona un corso');
      return;
    }
    if (!_endTime.isAfter(_startTime)) {
      setState(() => _error = 'L\'orario di fine deve essere dopo l\'inizio');
      return;
    }
    final capacity = int.tryParse(_capCtrl.text.trim()) ?? 0;
    if (_maxCapacity != null && capacity > _maxCapacity!) {
      setState(() => _error = 'I posti non possono superare la capienza dello spazio ($_maxCapacity)');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user      = ref.read(currentUserProvider);
      final client    = ref.read(supabaseClientProvider);
      final startsUtc = _startTime.toUtc().toIso8601String();
      final endsUtc   = _endTime.toUtc().toIso8601String();

      if (_roomId != null) {
        final conflicts = await client
            .from('lessons')
            .select('id')
            .eq('room_id', _roomId!)
            .neq('status', 'rejected')
            .lt('starts_at', endsUtc)
            .gt('ends_at', startsUtc);
        if ((conflicts as List).isNotEmpty) {
          throw Exception('Lo spazio è già occupato in questo orario');
        }
      }

      await client.from('lessons').insert({
        'course_id':   _courseId,
        'trainer_id':  user?.id,
        'starts_at':   startsUtc,
        'ends_at':     endsUtc,
        'capacity':    int.tryParse(_capCtrl.text.trim()) ?? 10,
        if (_roomId != null) 'room_id': _roomId,
        'status':      'pending',
        'proposed_by': user?.id,
      });

      if (mounted) {
        Navigator.of(context).pop();
        widget.onProposed();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Proposta inviata all\'owner per approvazione'),
            backgroundColor: Color(0xFFFFB74D),
          ),
        );
      }
    } catch (e) {
      setState(
          () => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final courses = ref.watch(_myOwnedCoursesProvider);
    final rooms = ref.watch(_staffRoomsProvider);
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
            Text('Proponi lezione',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            Text(
              '${dateFmt.format(widget.initialDate)} · in attesa di approvazione',
              style: TextStyle(
                  fontSize: 13,
                  color: const Color(0xFFFFB74D)),
            ),
            const SizedBox(height: 24),

            // Corso
            courses.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => const SizedBox.shrink(),
              data: (list) => list.isEmpty
                  ? Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Nessun corso assegnato. Contatta l\'owner.',
                        style: TextStyle(
                            color: theme.colorScheme.onErrorContainer),
                      ),
                    )
                  : DropdownButtonFormField<String?>(
                      initialValue: _courseId,
                      decoration: const InputDecoration(
                        labelText: 'Corso',
                        prefixIcon: Icon(Icons.fitness_center_outlined),
                      ),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('— Seleziona —')),
                        ...list.map((c) => DropdownMenuItem(
                              value: c['id'] as String,
                              child: Text(c['name'] as String),
                            )),
                      ],
                      onChanged: (v) => setState(() => _courseId = v),
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

            // Orari
            Row(
              children: [
                Expanded(
                  child: _TimePickerTile(
                    label: 'Inizio',
                    time: timeFmt.format(_startTime),
                    onTap: () => _pickTime(isStart: true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TimePickerTile(
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
                        child:
                            CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Invia proposta'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimePickerTile extends StatelessWidget {
  final String label;
  final String time;
  final VoidCallback onTap;

  const _TimePickerTile(
      {required this.label, required this.time, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                    style:
                        const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
