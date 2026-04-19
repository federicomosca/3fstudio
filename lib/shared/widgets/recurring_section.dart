import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';

class RecurringSection extends StatelessWidget {
  final bool isRecurring;
  final Set<int> recurDays;
  final DateTime recurUntil;
  final ValueChanged<bool> onToggle;
  final ValueChanged<int> onDayToggled;
  final VoidCallback onPickUntil;
  final int? occurrenceCount;

  const RecurringSection({
    super.key,
    required this.isRecurring,
    required this.recurDays,
    required this.recurUntil,
    required this.onToggle,
    required this.onDayToggled,
    required this.onPickUntil,
    this.occurrenceCount,
  });

  static const _dayLabels = ['L', 'M', 'M', 'G', 'V', 'S', 'D'];

  @override
  Widget build(BuildContext context) {
    final theme   = Theme.of(context);
    final dateFmt = DateFormat('d MMM yyyy', 'it_IT');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Lezione ricorrente',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          subtitle: Text(
            'Crea più lezioni automaticamente',
            style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withAlpha(150)),
          ),
          value: isRecurring,
          onChanged: onToggle,
        ),
        if (isRecurring) ...[
          const SizedBox(height: 8),
          Text('Giorni della settimana',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withAlpha(180))),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (i) {
              final day      = i + 1;
              final selected = recurDays.contains(day);
              return GestureDetector(
                onTap: () => onDayToggled(day),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? AppTheme.lime : Colors.transparent,
                    border: Border.all(
                      color: selected
                          ? AppTheme.lime
                          : theme.colorScheme.outline,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      _dayLabels[i],
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? AppTheme.charcoal
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: onPickUntil,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.outline),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.event_outlined,
                      size: 18,
                      color: theme.colorScheme.onSurface.withAlpha(150)),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ripeti fino al',
                          style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurface
                                  .withAlpha(150))),
                      Text(dateFmt.format(recurUntil),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const Spacer(),
                  if (occurrenceCount != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.lime.withAlpha(40),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$occurrenceCount lezioni',
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
