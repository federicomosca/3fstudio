import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/shared/providers/notifications_provider.dart';
import 'floating_nav_item.dart';
import 'sede_selector_bar.dart';

class ClientShell extends ConsumerWidget {
  final Widget child;
  const ClientShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = GoRouterState.of(context).matchedLocation;
    final sel = _index(loc);

    return Scaffold(
      body: Column(
        children: [
          const SedeSelectorBar(profileRoute: '/client/profile'),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: FloatingNavBar(
        items: [
          FloatingNavItem(
            icon: Icon(
              sel == 0 ? Icons.calendar_today : Icons.calendar_today_outlined,
              color: sel == 0 ? Colors.white : Colors.white54,
              size: 22,
            ),
            label: 'Calendario',
            selected: sel == 0,
            onTap: () => context.go('/client/calendar'),
          ),
          FloatingNavItem(
            icon: Icon(
              sel == 1 ? Icons.fitness_center : Icons.fitness_center_outlined,
              color: sel == 1 ? Colors.white : Colors.white54,
              size: 22,
            ),
            label: 'Corsi',
            selected: sel == 1,
            onTap: () => context.go('/client/courses'),
          ),
          FloatingNavItem(
            icon: Icon(
              sel == 2 ? Icons.bookmark : Icons.bookmark_outline,
              color: sel == 2 ? Colors.white : Colors.white54,
              size: 22,
            ),
            label: 'Prenotazioni',
            selected: sel == 2,
            onTap: () => context.go('/client/bookings'),
          ),
          FloatingNavItem(
            icon: Icon(
              sel == 3 ? Icons.home : Icons.home_outlined,
              color: sel == 3 ? Colors.white : Colors.white54,
              size: 22,
            ),
            label: 'Studio',
            selected: sel == 3,
            onTap: () => context.go('/client/studio'),
          ),
          FloatingNavItem(
            icon: _NotificationsBadge(selected: sel == 4),
            label: 'Notifiche',
            selected: sel == 4,
            onTap: () => context.go('/client/notifications'),
          ),
        ],
      ),
    );
  }

  int _index(String loc) {
    if (loc.startsWith('/client/courses'))       return 1;
    if (loc.startsWith('/client/bookings'))      return 2;
    if (loc.startsWith('/client/studio'))        return 3;
    if (loc.startsWith('/client/notifications')) return 4;
    return 0;
  }
}

class _NotificationsBadge extends ConsumerWidget {
  final bool selected;
  const _NotificationsBadge({required this.selected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(unreadNotificationsCountProvider);
    final color = selected ? Colors.white : Colors.white54;
    final icon = Icon(
      selected ? Icons.notifications : Icons.notifications_outlined,
      color: color,
      size: 22,
    );
    if (count == 0) return icon;
    return Badge(label: Text('$count'), child: icon);
  }
}
