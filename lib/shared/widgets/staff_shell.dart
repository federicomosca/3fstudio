import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/shared/providers/notifications_provider.dart';
import 'floating_nav_item.dart';
import 'sede_selector_bar.dart';

/// Shell per trainer (e course owner — determinato da class_owner_id sul corso).
class StaffShell extends ConsumerWidget {
  final Widget child;
  const StaffShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = GoRouterState.of(context).matchedLocation;
    final sel = _index(loc);

    return Scaffold(
      body: Column(
        children: [
          const SedeSelectorBar(profileRoute: '/staff/profile'),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: FloatingNavBar(
        items: [
          FloatingNavItem(
            icon: Icon(
              sel == 0 ? Icons.calendar_month : Icons.calendar_month_outlined,
              color: sel == 0 ? Colors.white : Colors.white54,
              size: 22,
            ),
            label: 'Calendario',
            selected: sel == 0,
            onTap: () => context.go('/staff/calendar'),
          ),
          FloatingNavItem(
            icon: Icon(
              sel == 1 ? Icons.fitness_center : Icons.fitness_center_outlined,
              color: sel == 1 ? Colors.white : Colors.white54,
              size: 22,
            ),
            label: 'Corsi',
            selected: sel == 1,
            onTap: () => context.go('/staff/courses'),
          ),
          FloatingNavItem(
            icon: Icon(
              sel == 2 ? Icons.home : Icons.home_outlined,
              color: sel == 2 ? Colors.white : Colors.white54,
              size: 22,
            ),
            label: 'Studio',
            selected: sel == 2,
            onTap: () => context.go('/staff/studio'),
          ),
          FloatingNavItem(
            icon: _NotificationsBadge(selected: sel == 3),
            label: 'Notifiche',
            selected: sel == 3,
            onTap: () => context.go('/staff/notifications'),
          ),
        ],
      ),
    );
  }

  int _index(String loc) {
    if (loc.startsWith('/staff/courses') || loc.startsWith('/staff/roster')) return 1;
    if (loc.startsWith('/staff/studio'))                                      return 2;
    if (loc.startsWith('/staff/notifications'))                               return 3;
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
