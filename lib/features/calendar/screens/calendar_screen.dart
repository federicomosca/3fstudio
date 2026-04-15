import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/theme/app_theme.dart';
import '../../../features/booking/providers/booking_provider.dart';
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
    final selectedDay = ref.watch(selectedDayProvider);
    final lessonDays = ref.watch(lessonDaysProvider(_focusedMonth));
    final lessons = ref.watch(lessonsForDayProvider(selectedDay));
    final userBookings = ref.watch(userBookingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendario'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => context.push('/client/profile'),
          ),
        ],
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
              ref.read(selectedDayProvider.notifier).state = selected;
            },
            onPageChanged: (focused) {
              setState(() => _focusedMonth = focused);
              ref.read(selectedDayProvider.notifier).state = focused;
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

                final bookedIds =
                    userBookings.whenOrNull(data: (ids) => ids) ?? {};

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: lessonList.length,
                  itemBuilder: (context, index) {
                    final lesson = lessonList[index];
                    final isBooked = bookedIds.contains(lesson.id);

                    return LessonCard(
                      lesson: lesson,
                      isBooked: isBooked,
                      bookedCount: 0, // TODO: fetch count per lesson
                      onBook: () => _book(lesson.id),
                      onCancel: () => _cancel(lesson.id),
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
