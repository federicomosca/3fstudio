import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/theme/app_theme.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../core/providers/studio_provider.dart';

// ── Providers ────────────────────────────────────────────────────────────────

final _staffSelectedDayProvider = StateProvider<DateTime>((ref) => DateTime.now());

final _staffLessonsForDayProvider =
    FutureProvider.family<List<Map<String, dynamic>>, DateTime>((ref, date) async {
  final user     = ref.watch(currentUserProvider);
  final studioId = ref.watch(currentStudioIdProvider);
  if (user == null || studioId == null) return [];

  final client   = ref.watch(supabaseClientProvider);
  final roles    = ref.watch(appRolesProvider).whenOrNull(data: (r) => r);
  final start    = DateTime(date.year, date.month, date.day).toUtc().toIso8601String();
  final end      = DateTime(date.year, date.month, date.day + 1).toUtc().toIso8601String();

  // class_owner: vede lezioni di tutti i suoi corsi
  // trainer puro: vede solo le lezioni in cui è assegnato
  var query = client
      .from('lessons')
      .select('id, starts_at, ends_at, capacity, courses(name, type, class_owner_id), bookings(count)')
      .gte('starts_at', start)
      .lt('starts_at', end);

  if (roles?.isClassOwner == true) {
    // class_owner: vede solo le lezioni dei propri corsi
    query = query.eq('courses.class_owner_id', user.id);
  } else {
    // trainer: vede tutte le lezioni dello studio
    query = query.eq('courses.studio_id', studioId);
  }

  final data = await query.order('starts_at');
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
    final selectedDay = ref.watch(_staffSelectedDayProvider);
    final lessons     = ref.watch(_staffLessonsForDayProvider(selectedDay));
    final timeFmt     = DateFormat('HH:mm');
    final dayFmt      = DateFormat('EEEE d MMMM', 'it_IT');

    return Scaffold(
      appBar: AppBar(title: const Text('Calendario')),
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
                color: AppTheme.charcoal,
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
              weekendTextStyle: TextStyle(color: Color(0xFF888888)),
            ),
            onDaySelected: (selected, _) =>
                ref.read(_staffSelectedDayProvider.notifier).state = selected,
            onPageChanged: (focused) {
              ref.read(_staffSelectedDayProvider.notifier).state = focused;
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
                              size: 48, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text('Nessuna lezione',
                              style: TextStyle(color: Colors.grey.shade500)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      itemCount: list.length,
                      itemBuilder: (context, i) {
                        final l       = list[i];
                        final course  = l['courses'] as Map<String, dynamic>;
                        final bookings = l['bookings'] as List? ?? [];
                        final count   = bookings.isNotEmpty
                            ? (bookings.first['count'] as int? ?? 0)
                            : 0;
                        final cap     = l['capacity'] as int;
                        final start   = DateTime.parse(l['starts_at'] as String).toLocal();
                        final end     = DateTime.parse(l['ends_at'] as String).toLocal();

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
                            title: Text(course['name'] as String),
                            subtitle: Text('$count/$cap iscritti'),
                            trailing: TextButton(
                              onPressed: () => context.push(
                                  '/staff/roster/${l['id']}'),
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
}
