import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Shell unificata per class_owner e trainer.
/// 4 tab per tutti: Calendario | Corsi | Studio | Profilo
class StaffShell extends StatelessWidget {
  final Widget child;
  const StaffShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;

    return Scaffold(
      body: child,
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
        ],
      ),
    );
  }

  int _index(String loc) {
    if (loc.startsWith('/staff/courses') ||
        loc.startsWith('/staff/roster'))  { return 1; }
    if (loc.startsWith('/staff/studio'))  { return 2; }
    return 0;
  }

  void _nav(BuildContext context, int i) {
    switch (i) {
      case 0: context.go('/staff/calendar');
      case 1: context.go('/staff/courses');
      case 2: context.go('/staff/studio');
    }
  }
}
