import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/studio.dart';
import '../../core/providers/selected_studio_provider.dart';

/// Barra superiore per selezionare la sede attiva.
/// Mostrata in tutti i shell (owner, staff, client).
/// [profileRoute]: se valorizzato, mostra l'icona profilo che naviga a quella route.
class SedeSelectorBar extends ConsumerWidget {
  final String? profileRoute;

  const SedeSelectorBar({super.key, this.profileRoute});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sediAsync     = ref.watch(userSediProvider);
    final selectedAsync = ref.watch(selectedStudioProvider);
    final theme         = Theme.of(context);

    final sedi     = sediAsync.whenOrNull(data: (s) => s) ?? [];
    final selected = selectedAsync.whenOrNull(data: (s) => s);

    return Material(
      color: theme.colorScheme.primary,
      child: SafeArea(
        bottom: false,
        child: InkWell(
          onTap: sedi.length <= 1
              ? null
              : () => _showPicker(context, ref, sedi, selected),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.store, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: selectedAsync.when(
                    loading: () => const SizedBox(
                      height: 14,
                      width: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    ),
                    error: (e, _) =>
                        const Text('—', style: TextStyle(color: Colors.white)),
                    data: (studio) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          studio?.name ?? '—',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        if (studio?.address != null)
                          Text(
                            studio!.address!,
                            style:
                                TextStyle(color: Colors.white.withAlpha(180), fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ),
                if (sedi.length > 1)
                  const Icon(Icons.expand_more, color: Colors.white, size: 20),
                if (profileRoute != null) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => context.push(profileRoute!),
                    child: const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Icon(Icons.account_circle_outlined,
                          color: Colors.white, size: 26),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPicker(
    BuildContext context,
    WidgetRef ref,
    List<Studio> sedi,
    Studio? current,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _SedePickerSheet(
        sedi: sedi,
        current: current,
        onSelect: (s) {
          ref.read(selectedStudioProvider.notifier).select(s);
          Navigator.pop(ctx);
        },
        onSetDefault: (s) async {
          await ref.read(selectedStudioProvider.notifier).setDefault(s);
          if (ctx.mounted) Navigator.pop(ctx);
        },
      ),
    );
  }
}

// ── Picker sheet ──────────────────────────────────────────────────────────────

class _SedePickerSheet extends ConsumerWidget {
  final List<Studio> sedi;
  final Studio? current;
  final void Function(Studio) onSelect;
  final Future<void> Function(Studio) onSetDefault;

  const _SedePickerSheet({
    required this.sedi,
    required this.current,
    required this.onSelect,
    required this.onSetDefault,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme     = Theme.of(context);
    final defaultId = ref
        .watch(selectedStudioProvider)
        .whenOrNull(data: (s) => s?.id);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: theme.colorScheme.outline,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Seleziona sede',
            style:
                theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 8),
        ...sedi.map((sede) {
          final isSelected = sede.id == current?.id;
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: isSelected
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.surfaceContainerHighest,
              child: Icon(
                Icons.store,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withAlpha(150),
                size: 20,
              ),
            ),
            title: Text(
              sede.name,
              style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
            ),
            subtitle: sede.address != null ? Text(sede.address!) : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSelected)
                  Icon(Icons.check_circle,
                      color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Imposta come predefinita',
                  icon: Icon(
                    sede.id == defaultId ? Icons.star : Icons.star_border,
                    color: sede.id == defaultId
                        ? Colors.amber.shade600
                        : theme.colorScheme.onSurface.withAlpha(100),
                  ),
                  onPressed: () => onSetDefault(sede),
                ),
              ],
            ),
            onTap: () => onSelect(sede),
          );
        }),
        const SizedBox(height: 16),
      ],
    );
  }
}
