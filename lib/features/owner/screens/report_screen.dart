import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/providers/studio_provider.dart';
import '../../../features/auth/providers/auth_provider.dart';

// ── Period state ──────────────────────────────────────────────────────────────

final _reportPeriodProvider = StateProvider<int>((ref) => 30);

// ── Data model ────────────────────────────────────────────────────────────────

class _ReportData {
  final int totalBookings;
  final int attended;
  final int cancelled;
  final List<_CourseStats> courses;
  final List<_WeekStats> weeks;

  const _ReportData({
    required this.totalBookings,
    required this.attended,
    required this.cancelled,
    required this.courses,
    required this.weeks,
  });
}

class _CourseStats {
  final String name;
  final int bookings;
  final int attended;

  const _CourseStats({
    required this.name,
    required this.bookings,
    required this.attended,
  });

  double get attendanceRate => bookings == 0 ? 0 : attended / bookings;
}

class _WeekStats {
  final String label;
  final int bookings;
  final int attended;

  const _WeekStats({
    required this.label,
    required this.bookings,
    required this.attended,
  });
}

// ── Provider ──────────────────────────────────────────────────────────────────

final _reportProvider =
    FutureProvider.autoDispose.family<_ReportData, int>((ref, days) async {
  final studioId = ref.watch(currentStudioIdProvider);
  if (studioId == null) {
    return const _ReportData(
        totalBookings: 0, attended: 0, cancelled: 0, courses: [], weeks: []);
  }

  final client = ref.watch(supabaseClientProvider);
  final now    = DateTime.now().toUtc();
  final start  = now.subtract(Duration(days: days)).toIso8601String();
  final end    = now.toIso8601String();

  // Single query: lessons + inline bookings for the period
  final lessonData = await client
      .from('lessons')
      .select('starts_at, bookings(status), courses!inner(name, studio_id)')
      .eq('courses.studio_id', studioId)
      .gte('starts_at', start)
      .lte('starts_at', end);

  final lessons = (lessonData as List).cast<Map<String, dynamic>>();
  if (lessons.isEmpty) {
    return const _ReportData(
        totalBookings: 0, attended: 0, cancelled: 0, courses: [], weeks: []);
  }

  // Aggregate overall stats
  int totalBookings = 0;
  int attended      = 0;
  int cancelled     = 0;

  final courseMap = <String, _CourseStats>{};
  final weekMap   = <String, _WeekStats>{};

  for (final lesson in lessons) {
    final course     = lesson['courses'] as Map<String, dynamic>;
    final courseName = course['name'] as String;
    final lessonDt   =
        DateTime.parse(lesson['starts_at'] as String).toLocal();
    final bookings   = (lesson['bookings'] as List? ?? [])
        .cast<Map<String, dynamic>>();

    for (final b in bookings) {
      final status      = b['status'] as String;
      final isCancelled = status == 'cancelled';
      final isAttended  = status == 'attended';

      if (!isCancelled) totalBookings++;
      if (isAttended)   attended++;
      if (isCancelled)  cancelled++;

      if (!isCancelled) {
        final prev = courseMap[courseName] ??
            _CourseStats(name: courseName, bookings: 0, attended: 0);
        courseMap[courseName] = _CourseStats(
          name:     courseName,
          bookings: prev.bookings + 1,
          attended: prev.attended + (isAttended ? 1 : 0),
        );

        final weekLabel = _weekLabel(lessonDt);
        final wPrev     = weekMap[weekLabel] ??
            _WeekStats(label: weekLabel, bookings: 0, attended: 0);
        weekMap[weekLabel] = _WeekStats(
          label:    weekLabel,
          bookings: wPrev.bookings + 1,
          attended: wPrev.attended + (isAttended ? 1 : 0),
        );
      }
    }
  }

  final courseList = courseMap.values.toList()
    ..sort((a, b) => b.bookings.compareTo(a.bookings));

  final weekList = weekMap.values.toList()
    ..sort((a, b) => a.label.compareTo(b.label));

  return _ReportData(
    totalBookings: totalBookings,
    attended:      attended,
    cancelled:     cancelled,
    courses:       courseList,
    weeks:         weekList,
  );
});

String _weekLabel(DateTime dt) {
  final monday = dt.subtract(Duration(days: dt.weekday - 1));
  return DateFormat('d MMM', 'it_IT').format(monday);
}

// ── Screen ────────────────────────────────────────────────────────────────────

class ReportScreen extends ConsumerWidget {
  final bool hideAppBar;
  const ReportScreen({super.key, this.hideAppBar = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days     = ref.watch(_reportPeriodProvider);
    final dataAsync = ref.watch(_reportProvider(days));

    return Scaffold(
      appBar: hideAppBar ? null : AppBar(title: const Text('Report')),
      body: Column(
        children: [
          // ── Period picker ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                _PeriodChip(label: 'Ultimi 30 giorni', value: 30, selected: days),
                const SizedBox(width: 8),
                _PeriodChip(label: 'Ultimi 90 giorni', value: 90, selected: days),
              ],
            ),
          ),

          // ── Content ────────────────────────────────────────────────────────
          Expanded(
            child: dataAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text('Errore: $e',
                    style: const TextStyle(color: Colors.red)),
              ),
              data: (data) => data.totalBookings == 0
                  ? _EmptyState(days: days)
                  : _ReportBody(data: data),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Period chip ───────────────────────────────────────────────────────────────

class _PeriodChip extends ConsumerWidget {
  final String label;
  final int value;
  final int selected;
  const _PeriodChip(
      {required this.label, required this.value, required this.selected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSelected = value == selected;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) =>
          ref.read(_reportPeriodProvider.notifier).state = value,
      selectedColor: AppTheme.blue.withAlpha(40),
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.blue : null,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
        fontSize: 12,
      ),
      side: BorderSide(
        color: isSelected
            ? AppTheme.blue
            : Theme.of(context).colorScheme.outline,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }
}

// ── Report body ───────────────────────────────────────────────────────────────

class _ReportBody extends StatelessWidget {
  final _ReportData data;
  const _ReportBody({required this.data});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        // ── Summary cards ────────────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon:  Icons.event_available,
                color: AppTheme.blue,
                label: 'Prenotazioni',
                value: '${data.totalBookings}',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                icon:  Icons.check_circle_outline,
                color: Colors.green,
                label: 'Presenze',
                value: data.totalBookings > 0
                    ? '${data.attended} · ${(data.attended / data.totalBookings * 100).round()}%'
                    : '0',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                icon:  Icons.cancel_outlined,
                color: Colors.orange,
                label: 'Cancellate',
                value: data.cancelled > 0
                    ? '${data.cancelled} · ${(data.cancelled / (data.totalBookings + data.cancelled) * 100).round()}%'
                    : '0',
              ),
            ),
          ],
        ),

        // ── Per-course breakdown ─────────────────────────────────────────────
        if (data.courses.isNotEmpty) ...[
          const SizedBox(height: 24),
          _SectionTitle('Presenze per corso'),
          const SizedBox(height: 10),
          ...data.courses.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _CourseBar(stats: c),
              )),
        ],

        // ── Week trend ───────────────────────────────────────────────────────
        if (data.weeks.length > 1) ...[
          const SizedBox(height: 24),
          _SectionTitle('Andamento settimanale'),
          const SizedBox(height: 10),
          _WeekTrend(weeks: data.weeks),
        ],
      ],
    );
  }
}

// ── Stat card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  const _StatCard(
      {required this.icon,
      required this.color,
      required this.label,
      required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurface.withAlpha(160),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Course bar ────────────────────────────────────────────────────────────────

class _CourseBar extends StatelessWidget {
  final _CourseStats stats;
  const _CourseBar({required this.stats});

  @override
  Widget build(BuildContext context) {
    final pct = stats.attendanceRate;
    final barColor = pct >= 0.75
        ? Colors.green
        : pct >= 0.5
            ? AppTheme.blue
            : Colors.orange;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  stats.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '${stats.attended}/${stats.bookings} presenti',
                style: TextStyle(
                  fontSize: 12,
                  color:
                      Theme.of(context).colorScheme.onSurface.withAlpha(160),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor:
                  Theme.of(context).colorScheme.outline.withAlpha(80),
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${(pct * 100).round()}% tasso di presenza',
            style: TextStyle(
              fontSize: 11,
              color: barColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Week trend ────────────────────────────────────────────────────────────────

class _WeekTrend extends StatelessWidget {
  final List<_WeekStats> weeks;
  const _WeekTrend({required this.weeks});

  @override
  Widget build(BuildContext context) {
    final maxBookings = weeks.fold(0, (m, w) => w.bookings > m ? w.bookings : m);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Column(
        children: weeks.map((w) {
          final barFraction = maxBookings == 0 ? 0.0 : w.bookings / maxBookings;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                SizedBox(
                  width: 56,
                  child: Text(
                    w.label,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withAlpha(160),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: barFraction,
                      minHeight: 8,
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .outline
                          .withAlpha(60),
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(AppTheme.blue),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 28,
                  child: Text(
                    '${w.bookings}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Section title ─────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: Theme.of(context).colorScheme.onSurface.withAlpha(180),
          letterSpacing: 0.3,
        ),
      );
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final int days;
  const _EmptyState({required this.days});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bar_chart,
                size: 64,
                color:
                    Theme.of(context).colorScheme.onSurface.withAlpha(60)),
            const SizedBox(height: 16),
            Text(
              'Nessun dato',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withAlpha(180),
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Nessuna prenotazione negli ultimi $days giorni.',
              style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withAlpha(150),
                  fontSize: 13),
            ),
          ],
        ),
      );
}
