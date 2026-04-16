import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/providers/profile_provider.dart';

/// Badge crediti rimanenti — visibile solo se il piano attivo è di tipo 'credits'.
/// Da inserire negli actions dell'AppBar delle schermate di prenotazione.
class CreditsChip extends ConsumerWidget {
  const CreditsChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planAsync = ref.watch(activePlanProvider);

    return planAsync.maybeWhen(
      data: (plan) {
        if (plan == null || plan.planType != 'credits') return const SizedBox.shrink();

        final credits = plan.creditsRemaining ?? 0;

        final Color bg;
        final Color fg;
        if (credits <= 1) {
          bg = Theme.of(context).colorScheme.errorContainer;
          fg = Theme.of(context).colorScheme.onErrorContainer;
        } else if (credits <= 3) {
          bg = Colors.orange.withAlpha(40);
          fg = Colors.orange.shade800;
        } else {
          bg = Colors.green.withAlpha(30);
          fg = Colors.green.shade700;
        }

        return Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.confirmation_number_outlined, size: 13, color: fg),
                  const SizedBox(width: 4),
                  Text(
                    '$credits',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: fg,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}
