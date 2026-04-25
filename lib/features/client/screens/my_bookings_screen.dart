import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/booking/providers/booking_provider.dart';
import '../../../features/profile/providers/profile_provider.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

final _myBookingsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];

  final client = ref.watch(supabaseClientProvider);
  final data = await client
      .from('bookings')
      .select(
        'id, status, lesson_id, '
        'lessons(starts_at, ends_at, courses(name, type, cancel_window_hours))',
      )
      .eq('user_id', user.id)
      .limit(50);

  return (data as List)
      .where((b) => b['lessons'] != null)
      .cast<Map<String, dynamic>>()
      .toList()
    ..sort((a, b) {
      final da = DateTime.parse((a['lessons'] as Map)['starts_at'] as String);
      final db = DateTime.parse((b['lessons'] as Map)['starts_at'] as String);
      return db.compareTo(da);
    });
});

final _myWaitlistProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];

  final client = ref.watch(supabaseClientProvider);
  final data = await client
      .from('waitlist')
      .select(
        'lesson_id, created_at, '
        'lessons(starts_at, ends_at, courses(name, cancel_window_hours))',
      )
      .eq('user_id', user.id);

  final now = DateTime.now();
  return (data as List)
      .where((w) {
        final l = w['lessons'] as Map?;
        if (l == null) return false;
        return DateTime.parse(l['starts_at'] as String).isAfter(now);
      })
      .cast<Map<String, dynamic>>()
      .toList()
    ..sort((a, b) {
      final da = DateTime.parse((a['lessons'] as Map)['starts_at'] as String);
      final db = DateTime.parse((b['lessons'] as Map)['starts_at'] as String);
      return da.compareTo(db);
    });
});

// ── Screen ────────────────────────────────────────────────────────────────────

class MyBookingsScreen extends ConsumerWidget {
  const MyBookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings  = ref.watch(_myBookingsProvider);
    final waitlist  = ref.watch(_myWaitlistProvider);
    final planAsync = ref.watch(activePlanProvider);
    final isCredits =
        planAsync.whenOrNull(data: (p) => p?.planType == 'credits') ?? false;

    final waitlistList = waitlist.whenOrNull(data: (l) => l) ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('Le mie prenotazioni')),
      body: bookings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Errore: $e', style: const TextStyle(color: Colors.red)),
        ),
        data: (list) {
          final now = DateTime.now();
          final upcoming = list.where((b) {
            final start = DateTime.parse(
                (b['lessons'] as Map)['starts_at'] as String);
            final status = b['status'] as String;
            return start.isAfter(now) &&
                (status == 'confirmed' || status == 'pending');
          }).toList();
          final past = list.where((b) {
            if (upcoming.contains(b)) return false;
            final start = DateTime.parse(
                (b['lessons'] as Map)['starts_at'] as String);
            return start.isBefore(now);
          }).toList();

          final isEmpty =
              upcoming.isEmpty && past.isEmpty && waitlistList.isEmpty;

          if (isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bookmark_outline,
                      size: 56,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withAlpha(60)),
                  const SizedBox(height: 12),
                  Text('Nessuna prenotazione',
                      style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withAlpha(150))),
                  const SizedBox(height: 4),
                  Text('Vai al calendario per prenotare',
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withAlpha(150))),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (upcoming.isNotEmpty) ...[
                _SectionHeader(label: 'Prossime (${upcoming.length})'),
                const SizedBox(height: 8),
                ...upcoming.map((b) => _BookingCard(
                      booking: b,
                      showCancelDeadline: isCredits,
                      onCancelled: () => ref.invalidate(_myBookingsProvider),
                    )),
                const SizedBox(height: 20),
              ],
              if (waitlistList.isNotEmpty) ...[
                _SectionHeader(
                    label: 'Lista d\'attesa (${waitlistList.length})'),
                const SizedBox(height: 8),
                ...waitlistList.map((w) => _WaitlistCard(
                      entry: w,
                      onLeft: () {
                        ref.invalidate(_myWaitlistProvider);
                        ref.invalidate(userWaitlistProvider);
                      },
                    )),
                const SizedBox(height: 20),
              ],
              if (past.isNotEmpty) ...[
                _SectionHeader(label: 'Storico'),
                const SizedBox(height: 8),
                ...past.map((b) => _BookingCard(
                      booking: b,
                      muted: true,
                      showCancelDeadline: false,
                      onCancelled: () => ref.invalidate(_myBookingsProvider),
                    )),
              ],
            ],
          );
        },
      ),
    );
  }
}

// ── Waitlist card ─────────────────────────────────────────────────────────────

class _WaitlistCard extends ConsumerWidget {
  final Map<String, dynamic> entry;
  final VoidCallback onLeft;
  const _WaitlistCard({required this.entry, required this.onLeft});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lesson  = entry['lessons'] as Map<String, dynamic>;
    final course  = lesson['courses'] as Map<String, dynamic>;
    final start   = DateTime.parse(lesson['starts_at'] as String).toLocal();
    final end     = DateTime.parse(lesson['ends_at'] as String).toLocal();
    final lessonId = entry['lesson_id'] as String;
    final dateFmt = DateFormat('EEE d MMM', 'it');
    final timeFmt = DateFormat('HH:mm');
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: cs.surface,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(course['name'] as String,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    '${dateFmt.format(start)}  '
                    '${timeFmt.format(start)}–${timeFmt.format(end)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withAlpha(150)),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.schedule, size: 14, color: Colors.orange),
                const SizedBox(width: 4),
                Text('In attesa',
                    style:
                        TextStyle(fontSize: 12, color: Colors.orange)),
              ],
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              color: cs.error,
              tooltip: 'Esci dalla lista',
              onPressed: () => _leave(context, ref, lessonId),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _leave(
      BuildContext context, WidgetRef ref, String lessonId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Esci dalla lista d\'attesa'),
        content: const Text(
            'Vuoi rimuoverti dalla lista d\'attesa per questa lezione?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Sì, esci',
                  style: TextStyle(
                      color: Theme.of(ctx).colorScheme.error))),
        ],
      ),
    );
    if (confirm != true) return;
    await ref
        .read(bookingNotifierProvider.notifier)
        .leaveWaitlist(lessonId);
    onLeft();
  }
}

// ── Section header ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurface.withAlpha(180),
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

// ── Booking card ──────────────────────────────────────────────────────────────

class _BookingCard extends ConsumerWidget {
  final Map<String, dynamic> booking;
  final bool muted;
  final bool showCancelDeadline;
  final VoidCallback onCancelled;

  const _BookingCard({
    required this.booking,
    required this.showCancelDeadline,
    required this.onCancelled,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lesson = booking['lessons'] as Map<String, dynamic>;
    final course = lesson['courses'] as Map<String, dynamic>;
    final status = booking['status'] as String;
    final lessonId = booking['lesson_id'] as String;
    final start = DateTime.parse(lesson['starts_at'] as String).toLocal();
    final end = DateTime.parse(lesson['ends_at'] as String).toLocal();
    final cancelHours = course['cancel_window_hours'] as int? ?? 24;
    final dateFmt = DateFormat('EEE d MMM', 'it');
    final timeFmt = DateFormat('HH:mm');
    final now = DateTime.now();

    final deadline = start.subtract(Duration(hours: cancelHours));
    final canCancel = status == 'confirmed' && start.isAfter(now);

    final cs = Theme.of(context).colorScheme;
    final (
      Color statusColor,
      String statusLabel,
      IconData statusIcon,
    ) = switch (status) {
      'confirmed' => muted
          ? (cs.onSurface.withAlpha(120), 'Non registrata', Icons.help_outline)
          : (AppTheme.blue, 'Prenotata', Icons.event_available_outlined),
      'cancelled' => (
        cs.onSurface.withAlpha(150),
        'Annullata',
        Icons.cancel_outlined,
      ),
      'attended' => (const Color(0xFF66BB6A), 'Presente', Icons.done_all),
      'no_show' => (
        const Color(0xFFEF5350),
        'Assente',
        Icons.person_off_outlined,
      ),
      _ => (cs.onSurface.withAlpha(150), status, Icons.help_outline),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Barra colorata
                Container(
                  width: 4,
                  height: 48,
                  decoration: BoxDecoration(
                    color: muted
                        ? Theme.of(context).colorScheme.outlineVariant
                        : statusColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course['name'] as String,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: muted
                              ? Theme.of(
                                  context,
                                ).colorScheme.onSurface.withAlpha(150)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${dateFmt.format(start)}  '
                        '${timeFmt.format(start)}–${timeFmt.format(end)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withAlpha(150),
                        ),
                      ),
                    ],
                  ),
                ),
                // Status badge
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 14, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      statusLabel,
                      style: TextStyle(fontSize: 12, color: statusColor),
                    ),
                  ],
                ),
                // Bottone cancella
                if (canCancel) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    color: Theme.of(context).colorScheme.error,
                    tooltip: 'Cancella',
                    onPressed: () => _cancel(
                      context,
                      ref,
                      lessonId,
                      deadline: deadline,
                      isCredits: showCancelDeadline,
                    ),
                  ),
                ],
              ],
            ),

            // Cancellation deadline (only for credit plans + upcoming booked)
            if (showCancelDeadline && canCancel) ...[
              const SizedBox(height: 8),
              _CancelDeadlineBadge(
                deadline: deadline,
                cancelHours: cancelHours,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _cancel(
    BuildContext context,
    WidgetRef ref,
    String lessonId, {
    required DateTime deadline,
    required bool isCredits,
  }) async {
    // Ricalcola al momento del tap per non fare affidamento su stato statico
    final lateCancel = isCredits && DateTime.now().isAfter(deadline);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: const Text('Annulla prenotazione'),
          content: lateCancel
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cs.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber_outlined,
                            size: 16,
                            color: cs.onErrorContainer,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'La finestra gratuita è scaduta.',
                              style: TextStyle(
                                color: cs.onErrorContainer,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Cancellando ora perderai 1 credito dal tuo piano.\nVuoi procedere?',
                    ),
                  ],
                )
              : const Text('Vuoi annullare questa prenotazione?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                lateCancel ? 'Sì, perdo il credito' : 'Sì, annulla',
                style: TextStyle(color: cs.error),
              ),
            ),
          ],
        );
      },
    );
    if (confirm != true) return;

    if (lateCancel) {
      await ref
          .read(bookingNotifierProvider.notifier)
          .cancelWithCreditDeduction(lessonId);
    } else {
      await ref.read(bookingNotifierProvider.notifier).cancel(lessonId);
    }
    onCancelled();
  }
}

// ── Cancellation deadline badge ───────────────────────────────────────────────

class _CancelDeadlineBadge extends StatefulWidget {
  final DateTime deadline;
  final int cancelHours;

  const _CancelDeadlineBadge({
    required this.deadline,
    required this.cancelHours,
  });

  @override
  State<_CancelDeadlineBadge> createState() => _CancelDeadlineBadgeState();
}

class _CancelDeadlineBadgeState extends State<_CancelDeadlineBadge> {
  late Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('EEE d MMM, HH:mm', 'it');
    final withinWindow = _now.isAfter(widget.deadline);

    if (withinWindow) {
      final cs = Theme.of(context).colorScheme;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: cs.errorContainer,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: cs.error.withAlpha(100)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.warning_amber_outlined,
              size: 14,
              color: cs.onErrorContainer,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Finestra di cancellazione chiusa — '
                'cancellare ora non farà recuperare il credito',
                style: TextStyle(
                  color: cs.onErrorContainer,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final remaining = widget.deadline.difference(_now);
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;

    String timeLabel;
    Color color;
    Color bg;
    Color border;

    if (hours < 2) {
      timeLabel = '${hours}h ${minutes}min';
      color = const Color(0xFFFFB74D);
      bg = Colors.orange.withAlpha(30);
      border = Colors.orange.withAlpha(100);
    } else {
      timeLabel = 'entro ${dateFmt.format(widget.deadline)}';
      color = Theme.of(context).colorScheme.onSurface;
      bg = AppTheme.lime.withAlpha(30);
      border = AppTheme.lime.withAlpha(80);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(Icons.timer_outlined, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Puoi cancellare senza perdere crediti: $timeLabel',
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
