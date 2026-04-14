import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AdminShell extends StatelessWidget {
  final Widget child;
  const AdminShell({super.key, required this.child});

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
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.store_outlined),
            selectedIcon: Icon(Icons.store),
            label: 'Studios',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Utenti',
          ),
        ],
      ),
    );
  }

  int _index(String loc) {
    if (loc.startsWith('/admin/studios')) return 1;
    if (loc.startsWith('/admin/users'))   return 2;
    return 0;
  }

  void _nav(BuildContext context, int i) {
    switch (i) {
      case 0: context.go('/admin/dashboard');
      case 1: context.go('/admin/studios');
      case 2: context.go('/admin/users');
    }
  }
}
