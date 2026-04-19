import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/models/lesson.dart';

import '../../../core/theme/app_theme.dart';
import '../../../features/booking/providers/booking_provider.dart';

import '../../../features/client/widgets/credits_chip.dart';
import '../providers/lessons_provider.dart';
import '../widgets/lesson_card.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focusedMonth = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final selectedDay    = ref.watch(selectedDayProvider);
    final lessonDays     = ref.watch(lessonDaysProvider(_focusedMonth));
    final lessons        = ref.watch(lessonsForDayProvider(selectedDay));
    final userBookings  = ref.watch(userBookingsProvider);
    final hasActivePlan = ref.watch(hasActivePlanProvider);
    final pendingTrials = ref.watch(userPendingTrialLessonsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendario'),
        actions: const [CreditsChip()],
      ),
      body: Column(
        children: [
          // Calendario
          TableCalendar(
            firstDay: DateTime.utc(2024, 1, 1),
            lastDay: DateTime.utc(2027, 12, 31),
            focusedDay: selectedDay,
            selectedDayPredicate: (day) => isSameDay(day, selectedDay),
            calendarFormat: CalendarFormat.month,
            availableCalendarFormats: const {CalendarFormat.month: 'Mese'},
            locale: 'it_IT',
            startingDayOfWeek: StartingDayOfWeek.monday,
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
            ),
            calendarStyle: const CalendarStyle(
              // Oggi: cerchio lime con testo scuro
              todayDecoration: BoxDecoration(
                color: AppTheme.lime,
                shape: BoxShape.circle,
              ),
              todayTextStyle: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
              // Selezionato: cerchio charcoal con testo bianco
              selectedDecoration: BoxDecoration(
                color: AppTheme.charcoal,
                shape: BoxShape.circle,
              ),
              selectedTextStyle: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
              // Marker lezioni: puntino lime
              markerDecoration: BoxDecoration(
                color: AppTheme.lime,
                shape: BoxShape.circle,
              ),
              markerSize: 5,
              weekendTextStyle: TextStyle(color: Color(0xFFAAAAAA)),
            ),
            eventLoader: (day) {
              final days = lessonDays.whenOrNull(data: (d) => d) ?? {};
              final normalized = DateTime(day.year, day.month, day.day);
              return days.contains(normalized) ? [true] : [];
            },
            onDaySelected: (selected, focused) {
              ref.read(selectedDayProvider.notifier).set(selected);
            },
            onPageChanged: (focused) {
              setState(() => _focusedMonth = focused);
              ref.read(selectedDayProvider.notifier).set(focused);
            },
          ),
          const Divider(height: 1),
          // Header giorno selezionato
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                DateFormat('EEEE d MMMM', 'it_IT').format(selectedDay),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withAlpha(180),
                    ),
              ),
            ),
          ),
          // Lista lezioni
          Expanded(
            child: lessons.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text('Errore: $e',
                    style: const TextStyle(color: Colors.red)),
              ),
              data: (lessonList) {
                if (lessonList.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.event_busy,
                            size: 48,
                            color: Theme.of(context).colorScheme.onSurface.withAlpha(60)),
                        const SizedBox(height: 12),
                        Text(
                          'Nessuna lezione programmata',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withAlpha(150)),
                        ),
                      ],
                    ),
                  );
                }

                final bookedIds    = userBookings.whenOrNull(data: (ids) => ids) ?? {};
                final clientHasPlan = hasActivePlan.whenOrNull(data: (v) => v) ?? false;
                final pendingIds  = pendingTrials.whenOrNull(data: (ids) => ids) ?? {};

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: lessonList.length,
                  itemBuilder: (context, index) {
                    final lesson         = lessonList[index];
                    final isBooked       = bookedIds.contains(lesson.id);
                    final isPendingTrial = pendingIds.contains(lesson.id);

                    return LessonCard(
                      lesson: lesson,
                      isBooked: isBooked,
                      hasActivePlan: clientHasPlan,
                      isPendingTrial: isPendingTrial,
                      bookedCount: lesson.bookedCount,
                      onBook: () => _book(lesson.id),
                      onCancel: () => _cancel(lesson.id),
                      onBookTrial: () => _bookTrial(lesson),
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

  Future<void> _bookTrial(Lesson lesson) async {
    final timeFormat = DateFormat('HH:mm');
    final dateFormat = DateFormat('EEEE d MMMM', 'it_IT');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Richiedi lezione di prova'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lesson.courseName,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              '${dateFormat.format(lesson.startTime)} · '
              '${timeFormat.format(lesson.startTime)}–${timeFormat.format(lesson.endTime)}',
              style: TextStyle(
                  color: Theme.of(ctx).colorScheme.onSurface.withAlpha(180),
                  fontSize: 13),
            ),
            const SizedBox(height: 12),
            const Text(
              'La richiesta sarà inviata all\'istruttore, '
              'che ti confermerà la disponibilità.',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Richiedi prova'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await ref.read(bookingNotifierProvider.notifier).bookTrialLesson(lesson.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Richiesta inviata per ${lesson.courseName}!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _book(String lessonId) async {
    try {
      await ref.read(bookingNotifierProvider.notifier).book(lessonId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Prenotazione confermata!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Errore: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _cancel(String lessonId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annulla prenotazione'),
        content: const Text('Sei sicuro di voler annullare questa prenotazione?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sì, annulla',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ref.read(bookingNotifierProvider.notifier).cancel(lessonId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Prenotazione annullata')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Errore: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
