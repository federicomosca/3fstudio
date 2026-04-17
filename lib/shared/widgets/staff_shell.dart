import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'sede_selector_bar.dart';

/// Shell per trainer (e course owner — determinato da class_owner_id sul corso).
class StaffShell extends ConsumerWidget {
  final Widget child;
  const StaffShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = GoRouterState.of(context).matchedLocation;

    return Scaffold(
      body: Column(
        children: [
          const SedeSelectorBar(),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index(loc),
        onDestinationSelected: (i) => _nav(context, i),
        destinations: const [
          NavigationDestination(
            icon:         Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label:        'Calendario',
          ),
          NavigationDestination(
            icon:         Icon(Icons.fitness_center_outlined),
            selectedIcon: Icon(Icons.fitness_center),
            label:        'Corsi',
          ),
          NavigationDestination(
            icon:         Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label:        'Studio',
          ),
          NavigationDestination(
            icon:         Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications),
            label:        'Notifiche',
          ),
        ],
      ),
    );
  }

  int _index(String loc) {
    if (loc.startsWith('/staff/courses') ||
        loc.startsWith('/staff/roster'))        { return 1; }
    if (loc.startsWith('/staff/studio'))        { return 2; }
    if (loc.startsWith('/staff/notifications')) { return 3; }
    return 0;
  }

  void _nav(BuildContext context, int i) {
    switch (i) {
      case 0: context.go('/staff/calendar');
      case 1: context.go('/staff/courses');
      case 2: context.go('/staff/studio');
      case 3: context.go('/staff/notifications');
    }
  }
}
