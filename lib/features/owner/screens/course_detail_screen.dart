import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../features/auth/providers/auth_provider.dart';
import 'courses_screen.dart';
import '../../../core/models/course_type.dart';
import '../../../features/booking/providers/booking_provider.dart';
import '../../../features/client/widgets/credits_chip.dart';
import '../../../core/providers/studio_provider.dart';
import '../../../core/theme/app_theme.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _courseDetailProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, courseId) async {
  final client = ref.watch(supabaseClientProvider);
  final data   = await client
      .from('courses')
      .select('id, name, type, cancel_window_hours, description, hourly_rate, users!class_owner_id(id, full_name)')
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
      .select('id, starts_at, ends_at, capacity, bookings(status)')
      .eq('course_id', courseId)
      .eq('status', 'active')
      .gte('starts_at', now)
      .order('starts_at')
      .limit(20);
  return (data as List).cast<Map<String, dynamic>>();
});

final _staffForCourseProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final studioId = ref.watch(currentStudioIdProvider);
  if (studioId == null) return [];
  final client = ref.watch(supabaseClientProvider);
  final data = await client
      .from('user_studio_roles')
      .select('users(id, full_name)')
      .eq('studio_id', studioId)
      .eq('role', 'trainer');
  final Map<String, Map<String, dynamic>> byUser = {};
  for (final row in (data as List)) {
    final user = row['users'] as Map<String, dynamic>;
    byUser[user['id'] as String] ??= user;
  }
  return byUser.values.toList()
    ..sort((a, b) =>
        (a['full_name'] as String).compareTo(b['full_name'] as String));
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

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String courseId,
    Map<String, dynamic> course,
  ) async {
    final name = course['name'] as String;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Elimina corso'),
        content: Text(
          'Eliminare "$name"?\n\n'
          'Verranno eliminate tutte le lezioni e prenotazioni associate.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final client = ref.read(supabaseClientProvider);

      final lessonRows = await client
          .from('lessons')
          .select('id')
          .eq('course_id', courseId);
      final lessonIds =
          (lessonRows as List).map((r) => r['id'] as String).toList();

      if (lessonIds.isNotEmpty) {
        await client.from('bookings').delete().inFilter('lesson_id', lessonIds);
        await client.from('waitlist').delete().inFilter('lesson_id', lessonIds);
        await client.from('lessons').delete().eq('course_id', courseId);
      }
      await client.from('courses').delete().eq('id', courseId);

      ref.invalidate(coursesProvider);
      if (context.mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"$name" eliminato')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lessonsAsync  = ref.watch(_courseLessonsProvider(courseId));
    final courseType    = course['type'] as String? ?? 'group';
    final owner         = course['users'] as Map<String, dynamic>?;
    final desc          = course['description'] as String?;
    final cancelHours   = course['cancel_window_hours'] as int?;
    final hourlyRate    = (course['hourly_rate'] as num?)?.toDouble();

    // Modalità cliente: route /client/
    final loc        = GoRouterState.of(context).matchedLocation;
    final clientMode = loc.startsWith('/client/');
    final bookedIds  = clientMode
        ? (ref.watch(_myCourseLessonBookingsProvider(courseId))
              .whenOrNull(data: (ids) => ids) ?? {})
        : const <String>{};
    final clientHasPlan = clientMode
        ? (ref.watch(hasActivePlanProvider).whenOrNull(data: (v) => v) ?? false)
        : false;
    final enrolledIds = clientMode
        ? (ref.watch(userEnrolledCourseIdsProvider).whenOrNull(data: (ids) => ids) ?? <String>{})
        : const <String>{};

    void onBookingChanged() {
      ref.invalidate(_courseLessonsProvider(courseId));
      ref.invalidate(_myCourseLessonBookingsProvider(courseId));
    }

    void onCourseEdited() {
      ref.invalidate(_courseDetailProvider(courseId));
    }

    return CustomScrollView(
      slivers: [
        // ── AppBar ────────────────────────────────────────────────────────
        SliverAppBar(
          expandedHeight: 160,
          pinned: true,
          backgroundColor: AppTheme.charcoal,
          foregroundColor: Colors.white,
          actions: clientMode
              ? const [CreditsChip()]
              : [
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'edit') {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          useSafeArea: true,
                          shape: const RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          builder: (_) => _EditCourseSheet(
                            courseId: courseId,
                            course: course,
                            onSaved: onCourseEdited,
                          ),
                        );
                      } else if (v == 'delete') {
                        _confirmDelete(context, ref, courseId, course);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(children: [
                          Icon(Icons.edit_outlined, size: 18),
                          SizedBox(width: 10),
                          Text('Modifica'),
                        ]),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(children: [
                          Icon(Icons.delete_outline, size: 18, color: Colors.red),
                          SizedBox(width: 10),
                          Text('Elimina', style: TextStyle(color: Colors.red)),
                        ]),
                      ),
                    ],
                  ),
                ],
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
                          courseType == 'personal' ? Colors.purple.shade400 : Colors.blue.shade400,
                      child: Icon(
                        courseTypeIcon(courseType),
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
                      icon: courseTypeIcon(courseType),
                      label: courseTypeLabel(courseType),
                    ),
                    if (owner != null)
                      GestureDetector(
                        onTap: () => context.push('/u/${owner['id']}'),
                        child: _InfoChip(
                          icon: Icons.manage_accounts_outlined,
                          label: owner['full_name'] as String,
                          tappable: true,
                        ),
                      ),
                    if (cancelHours != null)
                      _InfoChip(
                        icon: Icons.timer_outlined,
                        label: 'Disdetta entro $cancelHours h',
                      ),
                    if (!clientMode && hourlyRate != null && hourlyRate > 0)
                      _InfoChip(
                        icon: Icons.euro_outlined,
                        label: '€${hourlyRate.toStringAsFixed(2)}/lezione',
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
                      isBooked: bookedIds.contains(lessons[i]['id'] as String),
                      hasActivePlan: clientHasPlan && enrolledIds.contains(courseId),
                      onBookingChanged: onBookingChanged,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

// ── Edit course sheet ─────────────────────────────────────────────────────────

class _EditCourseSheet extends ConsumerStatefulWidget {
  final String courseId;
  final Map<String, dynamic> course;
  final VoidCallback onSaved;
  const _EditCourseSheet({
    required this.courseId,
    required this.course,
    required this.onSaved,
  });

  @override
  ConsumerState<_EditCourseSheet> createState() => _EditCourseSheetState();
}

class _EditCourseSheetState extends ConsumerState<_EditCourseSheet> {
  final _formKey   = GlobalKey<FormState>();
  late final _nameCtrl  = TextEditingController(
      text: widget.course['name'] as String? ?? '');
  late final _descCtrl  = TextEditingController(
      text: widget.course['description'] as String? ?? '');
  late final _hoursCtrl = TextEditingController(
      text: (widget.course['cancel_window_hours'] as int? ?? 2).toString());
  late final _rateCtrl  = TextEditingController(
      text: ((widget.course['hourly_rate'] as num?)?.toDouble() ?? 0) > 0
          ? (widget.course['hourly_rate'] as num).toStringAsFixed(2)
          : '');

  late String? _ownerId =
      (widget.course['users'] as Map<String, dynamic>?)?['id'] as String?;
  late String _type = widget.course['type'] as String? ?? 'group';
  bool    _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _hoursCtrl.dispose();
    _rateCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      final client = ref.read(supabaseClientProvider);
      await client.from('courses').update({
        'name':                _nameCtrl.text.trim(),
        'type':                _type,
        'description':
            _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        'cancel_window_hours': int.tryParse(_hoursCtrl.text.trim()) ?? 2,
        'class_owner_id':      _ownerId,
        'hourly_rate':         double.tryParse(_rateCtrl.text.trim()) ?? 0,
      }).eq('id', widget.courseId);

      ref.invalidate(coursesProvider);
      if (mounted) {
        Navigator.of(context).pop();
        widget.onSaved();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Corso aggiornato'),
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
    final staff = ref.watch(_staffForCourseProvider);

    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('Modifica corso',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),

              TextFormField(
                controller: _nameCtrl,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nome corso',
                  prefixIcon: Icon(Icons.fitness_center_outlined),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Campo obbligatorio' : null,
              ),
              const SizedBox(height: 16),

              // Tipo
              Text('Tipo', style: theme.textTheme.labelMedium),
              const SizedBox(height: 8),
              Row(
                children: [
                  _TypeBtn(
                    label: 'Gruppo', icon: Icons.group_outlined,
                    selected: _type == 'group',
                    onTap: () => setState(() => _type = 'group'),
                  ),
                  const SizedBox(width: 8),
                  _TypeBtn(
                    label: 'Condiviso', icon: Icons.people_outline,
                    selected: _type == 'shared',
                    onTap: () => setState(() => _type = 'shared'),
                  ),
                  const SizedBox(width: 8),
                  _TypeBtn(
                    label: 'Personal', icon: Icons.person_outline,
                    selected: _type == 'personal',
                    onTap: () => setState(() => _type = 'personal'),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Responsabile
              staff.when(
                loading: () => const LinearProgressIndicator(),
                error:   (e, _) => const SizedBox.shrink(),
                data: (members) => DropdownButtonFormField<String?>(
                  initialValue: _ownerId,
                  decoration: const InputDecoration(
                    labelText: 'Responsabile',
                    prefixIcon: Icon(Icons.manage_accounts_outlined),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Nessuno')),
                    ...members.map((m) => DropdownMenuItem(
                          value: m['id'] as String,
                          child: Text(m['full_name'] as String),
                        )),
                  ],
                  onChanged: (v) => setState(() => _ownerId = v),
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _hoursCtrl,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Ore anticipo per disdetta',
                  prefixIcon: Icon(Icons.timer_outlined),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  final n = int.tryParse(v.trim());
                  if (n == null) return 'Inserisci un numero';
                  if (n < 0) return 'Il valore deve essere ≥ 0';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _descCtrl,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Descrizione (opzionale)',
                  prefixIcon: Icon(Icons.notes_outlined),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),

              // Tariffa oraria base
              TextFormField(
                controller: _rateCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Tariffa base per lezione (€)',
                  prefixIcon: Icon(Icons.euro_outlined),
                  hintText: 'es. 10',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  final n = double.tryParse(v.trim());
                  if (n == null) return 'Inserisci un numero';
                  if (n < 0) return 'Deve essere ≥ 0';
                  return null;
                },
              ),

              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: theme.colorScheme.error.withAlpha(100)),
                  ),
                  child: Row(children: [
                    Icon(Icons.error_outline,
                        color: theme.colorScheme.onErrorContainer, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_error!,
                          style: TextStyle(
                              color: theme.colorScheme.onErrorContainer,
                              fontSize: 13)),
                    ),
                  ]),
                ),
              ],

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Salva'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Lesson row ─────────────────────────────────────────────────────────────────

class _LessonRow extends ConsumerStatefulWidget {
  final Map<String, dynamic> lesson;
  final bool clientMode;
  final bool isBooked;
  final bool hasActivePlan;
  final VoidCallback onBookingChanged;

  const _LessonRow({
    required this.lesson,
    required this.clientMode,
    required this.isBooked,
    required this.onBookingChanged,
    this.hasActivePlan = false,
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

  Future<void> _bookTrial() async {
    setState(() => _loading = true);
    try {
      await ref
          .read(bookingNotifierProvider.notifier)
          .bookTrialLesson(widget.lesson['id'] as String);
      widget.onBookingChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Richiesta prova inviata!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red),
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
    final bookings = (lesson['bookings'] as List? ?? []).cast<Map<String, dynamic>>();
    final count    = bookings.where((b) => b['status'] != 'cancelled').length;
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
                      : isFull
                          ? ElevatedButton(
                              onPressed: null,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 0),
                                minimumSize: Size.zero,
                              ),
                              child: const Text('Completo',
                                  style: TextStyle(fontSize: 12)),
                            )
                          : !widget.hasActivePlan
                              ? OutlinedButton(
                                  onPressed: _bookTrial,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFFFB74D),
                                    side: BorderSide(
                                        color: Colors.orange.withAlpha(180)),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 0),
                                    minimumSize: Size.zero,
                                  ),
                                  child: const Text('Prova',
                                      style: TextStyle(fontSize: 12)),
                                )
                              : ElevatedButton(
                                  onPressed: _book,
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 0),
                                    minimumSize: Size.zero,
                                  ),
                                  child: const Text('Prenota',
                                      style: TextStyle(fontSize: 12)),
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

class _TypeBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _TypeBtn({required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? cs.primary : cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? cs.primary : cs.outline),
          ),
          child: Column(
            children: [
              Icon(icon, size: 18,
                  color: selected ? cs.onPrimary : cs.onSurface.withAlpha(180)),
              const SizedBox(height: 4),
              Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected ? cs.onPrimary : cs.onSurface.withAlpha(180),
                    fontWeight: FontWeight.w600, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool tappable;
  const _InfoChip({required this.icon, required this.label, this.tappable = false});

  @override
  Widget build(BuildContext context) {
    final iconColor = tappable
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurface.withAlpha(180);
    final textColor = tappable
        ? Theme.of(context).colorScheme.primary
        : null;
    final borderColor = tappable
        ? Theme.of(context).colorScheme.primary.withAlpha(120)
        : Theme.of(context).colorScheme.outline;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: textColor)),
          if (tappable) ...[
            const SizedBox(width: 3),
            Icon(Icons.open_in_new, size: 11, color: iconColor),
          ],
        ],
      ),
    );
  }
}
