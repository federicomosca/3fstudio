import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/studio.dart';
import '../../core/providers/selected_studio_provider.dart';

class OwnerShell extends ConsumerWidget {
  final Widget child;
  const OwnerShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = GoRouterState.of(context).matchedLocation;

    return Scaffold(
      body: Column(
        children: [
          _StudioSelectorBar(),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index(loc),
        onDestinationSelected: (i) => _nav(context, i),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Calendario',
          ),
          NavigationDestination(
            icon: Icon(Icons.fitness_center_outlined),
            selectedIcon: Icon(Icons.fitness_center),
            label: 'Corsi',
          ),
          NavigationDestination(
            icon: Icon(Icons.group_outlined),
            selectedIcon: Icon(Icons.group),
            label: 'Team',
          ),
          NavigationDestination(
            icon: Icon(Icons.card_membership_outlined),
            selectedIcon: Icon(Icons.card_membership),
            label: 'Piani',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Clienti',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Report',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications),
            label: 'Notifiche',
          ),
        ],
      ),
    );
  }

  int _index(String loc) {
    if (loc.startsWith('/owner/calendar') || loc.startsWith('/owner/requests')) return 0;
    if (loc.startsWith('/owner/courses') || loc.startsWith('/owner/rooms'))     return 1;
    if (loc.startsWith('/owner/team'))                                           return 2;
    if (loc.startsWith('/owner/plans'))                                          return 3;
    if (loc.startsWith('/owner/clients'))                                        return 4;
    if (loc.startsWith('/owner/report'))                                         return 5;
    if (loc.startsWith('/owner/notifications') || loc.startsWith('/owner/profile')) return 6;
    return 0;
  }

  void _nav(BuildContext context, int i) {
    switch (i) {
      case 0: context.go('/owner/calendar');
      case 1: context.go('/owner/courses');
      case 2: context.go('/owner/team');
      case 3: context.go('/owner/plans');
      case 4: context.go('/owner/clients');
      case 5: context.go('/owner/report');
      case 6: context.go('/owner/notifications');
    }
  }
}

// ── Studio selector bar ───────────────────────────────────────────────────────

class _StudioSelectorBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studiosAsync = ref.watch(ownerStudiosProvider);
    final selectedAsync = ref.watch(selectedStudioProvider);
    final theme = Theme.of(context);

    final studios  = studiosAsync.whenOrNull(data: (s) => s) ?? [];
    final selected = selectedAsync.whenOrNull(data: (s) => s);

    // Se c'è un solo studio non serve il selettore (ma lo mostriamo comunque)
    return Material(
      color: theme.colorScheme.primary,
      child: SafeArea(
        bottom: false,
        child: InkWell(
          onTap: studios.length <= 1
              ? null
              : () => _showPicker(context, ref, studios, selected),
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
                    error: (e, _) => const Text('—',
                        style: TextStyle(color: Colors.white)),
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
                            style: TextStyle(
                              color: Colors.white.withAlpha(180),
                              fontSize: 11,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ),
                if (studios.length > 1)
                  const Icon(Icons.expand_more, color: Colors.white, size: 20),
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
    List<Studio> studios,
    Studio? current,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _StudioPickerSheet(
        studios: studios,
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

// ── Picker sheet ─────────────────────────────────────────────────────────────

class _StudioPickerSheet extends ConsumerWidget {
  final List<Studio> studios;
  final Studio? current;
  final void Function(Studio) onSelect;
  final Future<void> Function(Studio) onSetDefault;

  const _StudioPickerSheet({
    required this.studios,
    required this.current,
    required this.onSelect,
    required this.onSetDefault,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    // Legge il default_studio_id dall'utente per mostrare la stella piena
    // Usiamo selectedStudioProvider come proxy (è già quello impostato come default)
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
            color: Theme.of(context).colorScheme.outline,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Seleziona studio',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 8),
        ...studios.map((studio) {
          final isSelected = studio.id == current?.id;
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
              studio.name,
              style: TextStyle(
                fontWeight:
                    isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            subtitle: studio.address != null ? Text(studio.address!) : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSelected)
                  Icon(Icons.check_circle,
                      color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                // Stella per impostare come default
                IconButton(
                  tooltip: 'Imposta come predefinito',
                  icon: Icon(
                    studio.id == defaultId
                        ? Icons.star
                        : Icons.star_border,
                    color: studio.id == defaultId
                        ? Colors.amber.shade600
                        : theme.colorScheme.onSurface.withAlpha(100),
                  ),
                  onPressed: () => onSetDefault(studio),
                ),
              ],
            ),
            onTap: () => onSelect(studio),
          );
        }),
        const SizedBox(height: 16),
      ],
    );
  }
}
