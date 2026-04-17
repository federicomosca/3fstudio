import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/models/course_type.dart';
import '../../../core/models/lesson.dart';

class LessonCard extends StatelessWidget {
  final Lesson lesson;
  final bool isBooked;
  /// Il client ha almeno una prenotazione confirmed/attended per questo corso.
  final bool isEnrolled;
  /// Il client ha già una prenotazione prova in attesa per questa lezione.
  final bool isPendingTrial;
  final int bookedCount;
  final VoidCallback? onBook;
  final VoidCallback? onCancel;
  /// Richiedi lezione di prova (solo per corsi a cui non si è iscritti).
  final VoidCallback? onBookTrial;

  const LessonCard({
    super.key,
    required this.lesson,
    required this.isBooked,
    required this.bookedCount,
    this.isEnrolled = true,
    this.isPendingTrial = false,
    this.onBook,
    this.onCancel,
    this.onBookTrial,
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
              height: 48,
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
                      if (lesson.trainerName != null) ...[
                        const SizedBox(width: 10),
                        Icon(Icons.person_outline,
                            size: 14,
                            color: theme.colorScheme.onSurface.withAlpha(150)),
                        const SizedBox(width: 3),
                        Text(
                          lesson.trainerName!,
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withAlpha(150)),
                        ),
                      ],
                      const SizedBox(width: 10),
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

    // Non iscritto al corso → bottone prova
    if (!isEnrolled) {
      return OutlinedButton(
        onPressed: isFull ? null : onBookTrial,
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
      onPressed: isFull ? null : onBook,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: Size.zero,
      ),
      child: Text(
        isFull ? 'Completo' : 'Prenota',
        style: const TextStyle(fontSize: 12),
      ),
    );
  }
}
