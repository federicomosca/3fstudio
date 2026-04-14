import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/models/lesson.dart';

class LessonCard extends StatelessWidget {
  final Lesson lesson;
  final bool isBooked;
  final int bookedCount;
  final VoidCallback? onBook;
  final VoidCallback? onCancel;

  const LessonCard({
    super.key,
    required this.lesson,
    required this.isBooked,
    required this.bookedCount,
    this.onBook,
    this.onCancel,
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
                        lesson.courseType == 'group'
                            ? Icons.group_outlined
                            : Icons.person_outline,
                        size: 14,
                        color: theme.colorScheme.onSurface.withAlpha(150),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        lesson.courseType == 'group' ? 'Collettivo' : 'Personal',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: Colors.grey.shade500),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.people_outline,
                          size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text(
                        '$bookedCount/${lesson.capacity}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isFull ? Colors.red : Colors.grey.shade500,
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
