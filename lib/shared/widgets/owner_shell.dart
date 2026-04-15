import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
