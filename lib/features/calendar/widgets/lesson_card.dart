import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/models/course_type.dart';
import '../../../core/models/lesson.dart';

class LessonCard extends StatelessWidget {
  final Lesson lesson;
  final bool isBooked;
  final bool hasActivePlan;
  final bool isPendingTrial;
  final bool isOnWaitlist;
  final int bookedCount;
  final VoidCallback? onBook;
  final VoidCallback? onCancel;
  final VoidCallback? onBookTrial;
  final VoidCallback? onJoinWaitlist;
  final VoidCallback? onLeaveWaitlist;

  const LessonCard({
    super.key,
    required this.lesson,
    required this.isBooked,
    required this.bookedCount,
    this.hasActivePlan = false,
    this.isPendingTrial = false,
    this.isOnWaitlist = false,
    this.onBook,
    this.onCancel,
    this.onBookTrial,
    this.onJoinWaitlist,
    this.onLeaveWaitlist,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeFormat = DateFormat('HH:mm');
    final spotsLeft = lesson.capacity - bookedCount;
    final isFull = spotsLeft <= 0 && !isBooked;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Orario
            Column(
              children: [
                Text(
                  timeFormat.format(lesson.startTime),
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  timeFormat.format(lesson.endTime),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurface.withAlpha(150)),
                ),
              ],
            ),
            const SizedBox(width: 16),
            // Linea verticale
            Container(
              width: 2,
              height: 64,
              decoration: BoxDecoration(
                color: isBooked
                    ? theme.colorScheme.primary
                    : isPendingTrial
                        ? Colors.orange
                        : theme.colorScheme.outline,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            const SizedBox(width: 16),
            // Info corso
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lesson.courseName,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        courseTypeIcon(lesson.courseType),
                        size: 14,
                        color: theme.colorScheme.onSurface.withAlpha(150),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        courseTypeLabel(lesson.courseType),
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withAlpha(150)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (lesson.trainerName != null) ...[
                        Icon(Icons.person_outline,
                            size: 14,
                            color: theme.colorScheme.onSurface.withAlpha(150)),
                        const SizedBox(width: 3),
                        Text(
                          lesson.trainerName!,
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withAlpha(150)),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Icon(Icons.people_outline,
                          size: 14,
                          color: theme.colorScheme.onSurface.withAlpha(150)),
                      const SizedBox(width: 4),
                      Text(
                        '$bookedCount/${lesson.capacity}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isFull
                              ? theme.colorScheme.error
                              : theme.colorScheme.onSurface.withAlpha(150),
                        ),
                      ),
                      if (isFull && lesson.waitlistCount > 0) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.schedule,
                            size: 14,
                            color: theme.colorScheme.onSurface.withAlpha(120)),
                        const SizedBox(width: 3),
                        Text(
                          '${lesson.waitlistCount} in lista',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color:
                                  theme.colorScheme.onSurface.withAlpha(120)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Bottone
            _buildButton(context, isFull),
          ],
        ),
      ),
    );
  }

  Widget _buildButton(BuildContext context, bool isFull) {
    // Prenotazione confermata → mostra annulla
    if (isBooked) {
      return OutlinedButton(
        onPressed: onCancel,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red,
          side: const BorderSide(color: Colors.red),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        child: const Text('Annulla', style: TextStyle(fontSize: 12)),
      );
    }

    // Richiesta prova già inviata → chip arancione
    if (isPendingTrial) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.orange.withAlpha(25),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.withAlpha(120)),
        ),
        child: const Text(
          'In attesa',
          style: TextStyle(fontSize: 11, color: Color(0xFFFFB74D)),
        ),
      );
    }

    // Lezione piena → gestione lista d'attesa
    if (isFull) {
      if (isOnWaitlist) {
        return OutlinedButton(
          onPressed: onLeaveWaitlist,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.orange,
            side: BorderSide(color: Colors.orange.withAlpha(180)),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
          child: const Text('In lista', style: TextStyle(fontSize: 12)),
        );
      }
      return OutlinedButton(
        onPressed: onJoinWaitlist,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.orange,
          side: BorderSide(color: Colors.orange.withAlpha(180)),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),
        child: const Text('Lista d\'attesa', style: TextStyle(fontSize: 12)),
      );
    }

    // Nessun piano attivo → bottone prova
    if (!hasActivePlan) {
      return OutlinedButton(
        onPressed: onBookTrial,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFFFB74D),
          side: BorderSide(color: Colors.orange.withAlpha(180)),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),
        child: const Text('Prova', style: TextStyle(fontSize: 12)),
      );
    }

    // Iscritto → prenotazione normale
    return ElevatedButton(
      onPressed: onBook,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: Size.zero,
      ),
      child: const Text('Prenota', style: TextStyle(fontSize: 12)),
    );
  }
}
