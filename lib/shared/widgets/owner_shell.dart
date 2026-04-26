import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/owner/providers/plan_requests_provider.dart';
import '../../features/owner/providers/pending_lessons_count_provider.dart';
import '../../features/shared/providers/notifications_provider.dart';
import 'floating_nav_item.dart';
import 'sede_selector_bar.dart';

class OwnerShell extends ConsumerWidget {
  final Widget child;
  const OwnerShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = GoRouterState.of(context).matchedLocation;
    final sel = _index(loc);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          const SedeSelectorBar(profileRoute: '/owner/profile'),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: FloatingNavBar(
        items: [
          FloatingNavItem(
            icon: _CalendarioBadge(selected: sel == 0),
            label: 'Calendario',
            selected: sel == 0,
            onTap: () => context.go('/owner/calendar'),
          ),
          FloatingNavItem(
            icon: Icon(
              sel == 1 ? Icons.fitness_center : Icons.fitness_center_outlined,
              color: sel == 1 ? Colors.white : Colors.white54,
              size: 22,
            ),
            label: 'Corsi',
            selected: sel == 1,
            onTap: () => context.go('/owner/courses'),
          ),
          FloatingNavItem(
            icon: Icon(
              sel == 2 ? Icons.people : Icons.people_outline,
              color: sel == 2 ? Colors.white : Colors.white54,
              size: 22,
            ),
            label: 'Clienti',
            selected: sel == 2,
            onTap: () => context.go('/owner/clients'),
          ),
          FloatingNavItem(
            icon: _GestioneBadge(selected: sel == 3),
            label: 'Gestione',
            selected: sel == 3,
            onTap: () => context.go('/owner/manage'),
          ),
          FloatingNavItem(
            icon: Icon(
              sel == 4 ? Icons.home : Icons.home_outlined,
              color: sel == 4 ? Colors.white : Colors.white54,
              size: 22,
            ),
            label: 'Studio',
            selected: sel == 4,
            onTap: () => context.go('/owner/studio'),
          ),
          FloatingNavItem(
            icon: _NotificationsBadge(selected: sel == 5),
            label: 'Notifiche',
            selected: sel == 5,
            onTap: () => context.go('/owner/notifications'),
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
        loc.startsWith('/owner/team')   || loc.startsWith('/owner/plans') ||
        loc.startsWith('/owner/report') || loc.startsWith('/owner/pricing')) { return 3; }
    if (loc.startsWith('/owner/studio'))                                         return 4;
    if (loc.startsWith('/owner/notifications') || loc.startsWith('/owner/profile')) return 5;
    return 0;
  }
}

class _CalendarioBadge extends ConsumerWidget {
  final bool selected;
  const _CalendarioBadge({required this.selected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(pendingLessonsCountProvider).whenOrNull(data: (n) => n) ?? 0;
    final color = selected ? Colors.white : Colors.white54;
    final icon = Icon(
      selected ? Icons.calendar_month : Icons.calendar_month_outlined,
      color: color,
      size: 22,
    );
    if (count == 0) return icon;
    return Badge(label: Text('$count'), child: icon);
  }
}

class _GestioneBadge extends ConsumerWidget {
  final bool selected;
  const _GestioneBadge({required this.selected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(pendingPlanRequestsCountProvider).whenOrNull(data: (n) => n) ?? 0;
    final color = selected ? Colors.white : Colors.white54;
    final icon = Icon(
      selected ? Icons.tune : Icons.tune_outlined,
      color: color,
      size: 22,
    );
    if (count == 0) return icon;
    return Badge(label: Text('$count'), child: icon);
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
