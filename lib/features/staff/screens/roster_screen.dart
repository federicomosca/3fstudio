import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../features/auth/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _lessonInfoProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, lessonId) async {
  final client = ref.watch(supabaseClientProvider);
  final data   = await client
      .from('lessons')
      .select('id, starts_at, ends_at, capacity, course_id, courses(name, type)')
      .eq('id', lessonId)
      .maybeSingle();
  return data;
});

// bookings with user data
final _rosterProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, lessonId) async {
  final client = ref.watch(supabaseClientProvider);
  final data   = await client
      .from('bookings')
      .select('id, status, credits_deducted, user_id, users(id, full_name, avatar_url)')
      .eq('lesson_id', lessonId)
      .neq('status', 'cancelled')
      .order('created_at');
  return (data as List).cast<Map<String, dynamic>>();
});

// waitlist entries with user data
final _waitlistRosterProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, lessonId) async {
  final client = ref.watch(supabaseClientProvider);
  final data   = await client
      .from('waitlist')
      .select('id, user_id, position, created_at, users(id, full_name, avatar_url)')
      .eq('lesson_id', lessonId)
      .order('created_at');
  return (data as List).cast<Map<String, dynamic>>();
});

// ── Screen ────────────────────────────────────────────────────────────────────

class RosterScreen extends ConsumerWidget {
  final String lessonId;
  const RosterScreen({super.key, required this.lessonId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lessonAsync   = ref.watch(_lessonInfoProvider(lessonId));
    final rosterAsync   = ref.watch(_rosterProvider(lessonId));
    final waitlistAsync = ref.watch(_waitlistRosterProvider(lessonId));

    final timeFmt = DateFormat('HH:mm');
    final dateFmt = DateFormat('EEEE d MMMM', 'it_IT');

    return Scaffold(
      appBar: AppBar(
        title: lessonAsync.maybeWhen(
          data: (lesson) {
            if (lesson == null) return const Text('Presenze');
            final course = lesson['courses'] as Map<String, dynamic>;
            return Text(course['name'] as String);
          },
          orElse: () => const Text('Presenze'),
        ),
      ),
      body: Column(
        children: [
          // Lesson info header
          lessonAsync.when(
            loading: () => const LinearProgressIndicator(),
            error:   (e, _) => const SizedBox.shrink(),
            data: (lesson) {
              if (lesson == null) return const SizedBox.shrink();
              final start = DateTime.parse(lesson['starts_at'] as String).toLocal();
              final end   = DateTime.parse(lesson['ends_at']   as String).toLocal();
              return Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                color: AppTheme.charcoal,
                child: Row(children: [
                  const Icon(Icons.calendar_today_outlined,
                      color: AppTheme.lime, size: 18),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(dateFmt.format(start),
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700)),
                      Text(
                        '${timeFmt.format(start)} – ${timeFmt.format(end)}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Summary badge
                  rosterAsync.maybeWhen(
                    data: (roster) {
                      final attended = roster
                          .where((b) => b['status'] == 'attended')
                          .length;
                      final total = roster.length;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.lime,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$attended/$total presenti',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      );
                    },
                    orElse: () => const SizedBox.shrink(),
                  ),
                ]),
              );
            },
          ),

          // Roster list
          Expanded(
            child: rosterAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                  child: Text('Errore: $e',
                      style: const TextStyle(color: Colors.red))),
              data: (roster) {
                final waitlist = waitlistAsync.whenOrNull(data: (w) => w) ?? [];
                if (roster.isEmpty && waitlist.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_off_outlined,
                            size: 56,
                            color: Theme.of(context).colorScheme.onSurface.withAlpha(60)),
                        const SizedBox(height: 12),
                        Text('Nessun iscritto a questa lezione',
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface.withAlpha(150))),
                      ],
                    ),
                  );
                }
                final lesson = lessonAsync.asData?.value;
                final endsAt = lesson != null
                    ? DateTime.parse(lesson['ends_at'] as String).toLocal()
                    : DateTime.now();
                final canMark = DateTime.now().isAfter(endsAt);
                // Build flat item list: bookings + optional waitlist section
                final items = <_RosterItem>[
                  for (final b in roster) _RosterItem.booking(b),
                  if (waitlist.isNotEmpty) ...[
                    _RosterItem.waitlistHeader(),
                    for (final w in waitlist) _RosterItem.waitlist(w),
                  ],
                ];
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (context, i) =>
                      items[i].isHeader ? const SizedBox(height: 4) : const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final item = items[i];
                    if (item.isHeader) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 4),
                        child: Text(
                          'Lista d\'attesa (${waitlist.length})',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface.withAlpha(150),
                            letterSpacing: 0.5,
                          ),
                        ),
                      );
                    }
                    if (item.waitlistEntry != null) {
                      return _WaitlistRow(entry: item.waitlistEntry!);
                    }
                    return _AttendeeRow(
                      booking: item.booking!,
                      canMark: canMark,
                      onStatusChange: (newStatus) async {
                        await _updateStatus(context, ref, item.booking!, newStatus);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateStatus(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> booking,
    String newStatus,
  ) async {
    try {
      final client    = ref.read(supabaseClientProvider);
      final bookingId = booking['id'] as String;

      await client
          .from('bookings')
          .update({'status': newStatus})
          .eq('id', bookingId);

      // Deduct credit when marking attended (once only)
      if (newStatus == 'attended' &&
          (booking['credits_deducted'] as bool? ?? false) == false) {
        await _deductCredit(client, booking);
        await client
            .from('bookings')
            .update({'credits_deducted': true})
            .eq('id', bookingId);
      }

      ref.invalidate(_rosterProvider(lessonId));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deductCredit(
    dynamic client,
    Map<String, dynamic> booking,
  ) async {
    final userId   = booking['user_id'] as String;
    final lessonInfo = await client
        .from('lessons')
        .select('course_id')
        .eq('id', lessonId)
        .single();
    final courseId = lessonInfo['course_id'] as String;

    final now = DateTime.now().toUtc().toIso8601String();
    final plansData = await client
        .from('user_plans')
        .select('id, credits_remaining, course_id, plans!inner(type)')
        .eq('user_id', userId)
        .eq('status', 'active')
        .or('expires_at.is.null,expires_at.gte.$now');

    final plans = (plansData as List).cast<Map<String, dynamic>>();

    Map<String, dynamic>? bestPlan;
    // Open credits plan first
    for (final p in plans) {
      final type = (p['plans'] as Map<String, dynamic>)['type'] as String;
      if (type != 'credits') continue;
      if (p['course_id'] != null) continue;
      final credits = p['credits_remaining'] as int?;
      if (credits != null && credits > 0) { bestPlan = p; break; }
    }
    // Fall back to course-specific
    if (bestPlan == null) {
      for (final p in plans) {
        final type = (p['plans'] as Map<String, dynamic>)['type'] as String;
        if (type != 'credits') continue;
        if (p['course_id'] != courseId) continue;
        final credits = p['credits_remaining'] as int?;
        if (credits != null && credits > 0) { bestPlan = p; break; }
      }
    }
    // Fall back to trial credits (trial-by-credits: credito scalato alla presenza)
    if (bestPlan == null) {
      for (final p in plans) {
        final type = (p['plans'] as Map<String, dynamic>)['type'] as String;
        if (type != 'trial') continue;
        final credits = p['credits_remaining'] as int?;
        if (credits != null && credits > 0) { bestPlan = p; break; }
      }
    }

    if (bestPlan != null) {
      final credits = bestPlan['credits_remaining'] as int;
      await client
          .from('user_plans')
          .update({'credits_remaining': credits - 1})
          .eq('id', bestPlan['id'] as String);
    }
  }
}

// ── Item type helper ─────────────────────────────────────────────────────────

class _RosterItem {
  final Map<String, dynamic>? booking;
  final Map<String, dynamic>? waitlistEntry;
  final bool isHeader;

  const _RosterItem._({this.booking, this.waitlistEntry, this.isHeader = false});

  factory _RosterItem.booking(Map<String, dynamic> b) => _RosterItem._(booking: b);
  factory _RosterItem.waitlist(Map<String, dynamic> w) => _RosterItem._(waitlistEntry: w);
  factory _RosterItem.waitlistHeader() => _RosterItem._(isHeader: true);
}

// ── Waitlist row ──────────────────────────────────────────────────────────────

class _WaitlistRow extends StatelessWidget {
  final Map<String, dynamic> entry;
  const _WaitlistRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final user = entry['users'] as Map<String, dynamic>? ?? {};
    final name = user['full_name'] as String? ?? '—';

    return Container(
      decoration: BoxDecoration(
        color: Colors.orange.withAlpha(15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withAlpha(80)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: Colors.orange.withAlpha(40),
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: const TextStyle(
              color: Color(0xFFFFB74D),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.hourglass_empty_outlined,
                size: 13, color: Color(0xFFFFB74D)),
            const SizedBox(width: 4),
            const Text(
              'In lista d\'attesa',
              style: TextStyle(
                color: Color(0xFFFFB74D),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Attendee row ──────────────────────────────────────────────────────────────

class _AttendeeRow extends StatelessWidget {
  final Map<String, dynamic> booking;
  final bool canMark;
  final void Function(String newStatus) onStatusChange;
  const _AttendeeRow(
      {required this.booking, required this.canMark, required this.onStatusChange});

  @override
  Widget build(BuildContext context) {
    final user   = booking['users'] as Map<String, dynamic>? ?? {};
    final name   = user['full_name'] as String? ?? '—';
    final status = booking['status'] as String? ?? 'confirmed';

    return Container(
      decoration: BoxDecoration(
        color: _bgFor(status, context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderFor(status, context)),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: _avatarBgFor(status),
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: TextStyle(
              color: _avatarFgFor(status),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: _StatusChip(status: status),
        trailing: _AttendanceButtons(
          status: status,
          canMark: canMark,
          onPresent:  () => onStatusChange('attended'),
          onAbsent:   () => onStatusChange('no_show'),
          onReset:    () => onStatusChange('confirmed'),
        ),
      ),
    );
  }

  Color _bgFor(String s, BuildContext context) {
    return switch (s) {
      'attended' => Colors.green.withAlpha(25),
      'no_show'  => Colors.red.withAlpha(25),
      _          => Theme.of(context).colorScheme.surface,
    };
  }

  Color _borderFor(String s, BuildContext context) {
    return switch (s) {
      'attended' => Colors.green.withAlpha(100),
      'no_show'  => Colors.red.withAlpha(100),
      _          => Theme.of(context).colorScheme.outline,
    };
  }

  Color _avatarBgFor(String s) {
    return switch (s) {
      'attended' => Colors.green.withAlpha(50),
      'no_show'  => Colors.red.withAlpha(50),
      _          => AppTheme.lime.withAlpha(60),
    };
  }

  Color _avatarFgFor(String s) {
    return switch (s) {
      'attended' => const Color(0xFF66BB6A),
      'no_show'  => const Color(0xFFEF5350),
      _          => AppTheme.blue,
    };
  }
}

// ── Status chip ───────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (status) {
      'attended' => ('Presente',  const Color(0xFF66BB6A), Icons.check_circle_outline),
      'no_show'  => ('Assente',   const Color(0xFFEF5350), Icons.cancel_outlined),
      _          => ('Prenotato', AppTheme.blue,           Icons.event_available_outlined),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ── Action buttons ────────────────────────────────────────────────────────────

class _AttendanceButtons extends StatelessWidget {
  final String status;
  final bool canMark;
  final VoidCallback onPresent;
  final VoidCallback onAbsent;
  final VoidCallback onReset;
  const _AttendanceButtons(
      {required this.status,
      required this.canMark,
      required this.onPresent,
      required this.onAbsent,
      required this.onReset});

  @override
  Widget build(BuildContext context) {
    if (!canMark) {
      return Tooltip(
        message: 'Disponibile dopo la fine della lezione',
        child: Icon(
          Icons.lock_clock_outlined,
          color: Theme.of(context).colorScheme.onSurface.withAlpha(80),
        ),
      );
    }

    if (status == 'attended') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.cancel_outlined, color: Colors.red),
            tooltip: 'Segna assente',
            onPressed: onAbsent,
          ),
          IconButton(
            icon: Icon(Icons.undo,
                color: Theme.of(context).colorScheme.onSurface.withAlpha(150)),
            tooltip: 'Ripristina',
            onPressed: onReset,
          ),
        ],
      );
    }
    if (status == 'no_show') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.check_circle_outline,
                color: Colors.green),
            tooltip: 'Segna presente',
            onPressed: onPresent,
          ),
          IconButton(
            icon: Icon(Icons.undo,
                color: Theme.of(context).colorScheme.onSurface.withAlpha(150)),
            tooltip: 'Ripristina',
            onPressed: onReset,
          ),
        ],
      );
    }
    // booked → show both buttons
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.check_circle_outline,
              color: Colors.green),
          tooltip: 'Presente',
          onPressed: onPresent,
        ),
        IconButton(
          icon: const Icon(Icons.cancel_outlined, color: Colors.red),
          tooltip: 'Assente',
          onPressed: onAbsent,
        ),
      ],
    );
  }
}
