import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/owner/providers/plan_requests_provider.dart';
import 'sede_selector_bar.dart';

class OwnerShell extends ConsumerWidget {
  final Widget child;
  const OwnerShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = GoRouterState.of(context).matchedLocation;

    return Scaffold(
      body: Column(
        children: [
          SedeSelectorBar(profileRoute: '/owner/profile'),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index(loc),
        onDestinationSelected: (i) => _nav(context, i),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Calendario',
          ),
          const NavigationDestination(
            icon: Icon(Icons.fitness_center_outlined),
            selectedIcon: Icon(Icons.fitness_center),
            label: 'Corsi',
          ),
          const NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Clienti',
          ),
          NavigationDestination(
            icon: _GestioneBadge(selected: false),
            selectedIcon: _GestioneBadge(selected: true),
            label: 'Gestione',
          ),
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Studio',
          ),
          const NavigationDestination(
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
    if (loc.startsWith('/owner/courses'))                                        return 1;
    if (loc.startsWith('/owner/clients'))                                        return 2;
    if (loc.startsWith('/owner/manage') || loc.startsWith('/owner/rooms') ||
        loc.startsWith('/owner/team')   || loc.startsWith('/owner/plans'))      { return 3; }
    if (loc.startsWith('/owner/studio'))                                         return 4;
    if (loc.startsWith('/owner/notifications') || loc.startsWith('/owner/profile')) return 5;
    return 0;
  }

  void _nav(BuildContext context, int i) {
    switch (i) {
      case 0: context.go('/owner/calendar');
      case 1: context.go('/owner/courses');
      case 2: context.go('/owner/clients');
      case 3: context.go('/owner/manage');
      case 4: context.go('/owner/studio');
      case 5: context.go('/owner/notifications');
    }
  }
}

// Badge sulla voce "Gestione" che mostra il numero di richieste piani in attesa.
class _GestioneBadge extends ConsumerWidget {
  final bool selected;
  const _GestioneBadge({required this.selected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(pendingPlanRequestsCountProvider).whenOrNull(
              data: (n) => n,
            ) ??
        0;

    final icon = Icon(
      selected ? Icons.tune : Icons.tune_outlined,
    );

    if (count == 0) return icon;

    return Badge(
      label: Text('$count'),
      child: icon,
    );
  }
}
