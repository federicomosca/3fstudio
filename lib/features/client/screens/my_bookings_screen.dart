import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/booking/providers/booking_provider.dart';
import '../../../features/profile/providers/profile_provider.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

final _myBookingsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];

  final client = ref.watch(supabaseClientProvider);
  final data   = await client
      .from('bookings')
      .select(
          'id, status, lesson_id, '
          'lessons(starts_at, ends_at, courses(name, type, cancel_window_hours))')
      .eq('user_id', user.id)
      .limit(50);

  return (data as List)
      .where((b) => b['lessons'] != null)
      .cast<Map<String, dynamic>>()
      .toList()
    ..sort((a, b) {
      final da = DateTime.parse(
          (a['lessons'] as Map)['starts_at'] as String);
      final db = DateTime.parse(
          (b['lessons'] as Map)['starts_at'] as String);
      return db.compareTo(da);
    });
});

// ── Screen ────────────────────────────────────────────────────────────────────

class MyBookingsScreen extends ConsumerWidget {
  const MyBookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings   = ref.watch(_myBookingsProvider);
    final planAsync  = ref.watch(activePlanProvider);
    final isCredits  = planAsync.whenOrNull(
          data: (p) => p?.planType == 'credits') ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Le mie prenotazioni')),
      body: bookings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(
            child: Text('Errore: $e',
                style: const TextStyle(color: Colors.red))),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bookmark_outline,
                      size: 56, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text('Nessuna prenotazione',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withAlpha(150))),
                  const SizedBox(height: 4),
                  Text('Vai al calendario per prenotare',
                      style: TextStyle(
                          fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withAlpha(150))),
                ],
              ),
            );
          }

          final now      = DateTime.now();
          final upcoming = list
              .where((b) =>
                  DateTime.parse((b['lessons'] as Map)['starts_at'] as String)
                      .isAfter(now) &&
                  b['status'] == 'booked')
              .toList();
          final past = list
              .where((b) => !upcoming.contains(b))
              .toList();

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
    final lesson  = booking['lessons'] as Map<String, dynamic>;
    final course  = lesson['courses']  as Map<String, dynamic>;
    final status  = booking['status']  as String;
    final lessonId = booking['lesson_id'] as String;
    final start   = DateTime.parse(lesson['starts_at'] as String).toLocal();
    final end     = DateTime.parse(lesson['ends_at']   as String).toLocal();
    final cancelHours = course['cancel_window_hours'] as int? ?? 24;
    final dateFmt = DateFormat('EEE d MMM', 'it');
    final timeFmt = DateFormat('HH:mm');
    final now     = DateTime.now();

    final deadline   = start.subtract(Duration(hours: cancelHours));
    final canCancel  = status == 'booked' && start.isAfter(now);
    final withinWindow = now.isAfter(deadline);

    final (Color statusColor, String statusLabel, IconData statusIcon) =
        switch (status) {
      'booked'    => (Colors.blue.shade600,  'Prenotata',  Icons.event_available_outlined),
      'cancelled' => (Colors.grey.shade400,  'Annullata',  Icons.cancel_outlined),
      'attended'  => (Colors.green.shade600, 'Presente',   Icons.done_all),
      'no_show'   => (Colors.red.shade400,   'Assente',    Icons.person_off_outlined),
      _           => (Colors.grey.shade400,  status,       Icons.help_outline),
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
                  width: 4, height: 48,
                  decoration: BoxDecoration(
                    color: muted ? Colors.grey.shade300 : statusColor,
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
                              color: muted ? Theme.of(context).colorScheme.onSurface.withAlpha(150) : null,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${dateFmt.format(start)}  '
                        '${timeFmt.format(start)}–${timeFmt.format(end)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withAlpha(150)),
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
                    Text(statusLabel,
                        style: TextStyle(fontSize: 12, color: statusColor)),
                  ],
                ),
                // Bottone cancella
                if (canCancel) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    color: Colors.red.shade300,
                    tooltip: 'Cancella',
                    onPressed: () => _cancel(context, ref, lessonId),
                  ),
                ],
              ],
            ),

            // Cancellation deadline (only for credit plans + upcoming booked)
            if (showCancelDeadline && canCancel) ...[
              const SizedBox(height: 8),
              _CancelDeadlineBadge(
                deadline: deadline,
                withinWindow: withinWindow,
                cancelHours: cancelHours,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _cancel(
      BuildContext context, WidgetRef ref, String lessonId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annulla prenotazione'),
        content: const Text('Sei sicuro?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Sì, annulla',
                  style: TextStyle(color: Colors.red.shade700))),
        ],
      ),
    );
    if (confirm != true) return;
    await ref.read(bookingNotifierProvider.notifier).cancel(lessonId);
    onCancelled();
  }
}

// ── Cancellation deadline badge ───────────────────────────────────────────────

class _CancelDeadlineBadge extends StatelessWidget {
  final DateTime deadline;
  final bool withinWindow;
  final int cancelHours;

  const _CancelDeadlineBadge({
    required this.deadline,
    required this.withinWindow,
    required this.cancelHours,
  });

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('EEE d MMM, HH:mm', 'it');

    if (withinWindow) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(children: [
          Icon(Icons.warning_amber_outlined,
              size: 14, color: Colors.red.shade700),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Finestra di cancellazione chiusa — '
              'cancellare ora fa perdere il credito',
              style: TextStyle(
                  color: Colors.red.shade700,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ]),
      );
    }

    final remaining = deadline.difference(DateTime.now());
    final hours     = remaining.inHours;
    final minutes   = remaining.inMinutes % 60;

    String timeLabel;
    Color  color;
    Color  bg;
    Color  border;

    if (hours < 2) {
      timeLabel = '${hours}h ${minutes}min';
      color  = Colors.orange.shade800;
      bg     = Colors.orange.shade50;
      border = Colors.orange.shade200;
    } else {
      timeLabel = 'entro ${dateFmt.format(deadline)}';
      color  = AppTheme.charcoal;
      bg     = AppTheme.lime.withAlpha(30);
      border = AppTheme.lime.withAlpha(80);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Row(children: [
        Icon(Icons.timer_outlined, size: 14, color: color),
        const SizedBox(width: 6),
        Text(
          'Puoi cancellare senza perdere crediti: $timeLabel',
          style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600),
        ),
      ]),
    );
  }
}
