import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'sede_selector_bar.dart';

class ClientShell extends ConsumerWidget {
  final Widget child;
  const ClientShell({super.key, required this.child});

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
            icon:         Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today),
            label:        'Calendario',
          ),
          NavigationDestination(
            icon:         Icon(Icons.fitness_center_outlined),
            selectedIcon: Icon(Icons.fitness_center),
            label:        'Corsi',
          ),
          NavigationDestination(
            icon:         Icon(Icons.bookmark_outline),
            selectedIcon: Icon(Icons.bookmark),
            label:        'Prenotazioni',
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
    if (loc.startsWith('/client/courses'))  return 1;
    if (loc.startsWith('/client/bookings')) return 2;
    if (loc.startsWith('/client/studio'))   return 3;
    return 0; // calendar
  }

  void _nav(BuildContext context, int i) {
    switch (i) {
      case 0: context.go('/client/calendar');
      case 1: context.go('/client/courses');
      case 2: context.go('/client/bookings');
      case 3: context.go('/client/studio');
    }
  }
}
