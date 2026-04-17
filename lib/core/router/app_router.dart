import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/profile/screens/public_profile_screen.dart';

// Owner
import '../../features/owner/screens/owner_calendar_screen.dart';
import '../../features/owner/screens/courses_screen.dart';
import '../../features/owner/screens/course_detail_screen.dart';
import '../../features/owner/screens/rooms_screen.dart';
import '../../features/owner/screens/team_screen.dart';
import '../../features/owner/screens/clients_screen.dart';
import '../../features/owner/screens/client_detail_screen.dart';
import '../../features/owner/screens/plans_screen.dart';
import '../../features/owner/screens/owner_manage_screen.dart';

// Staff
import '../../features/staff/screens/staff_calendar_screen.dart';
import '../../features/staff/screens/my_courses_screen.dart';
import '../../features/staff/screens/roster_screen.dart';

// Client
import '../../features/client/screens/client_calendar_screen.dart';
import '../../features/client/screens/my_bookings_screen.dart';
import '../../features/client/screens/client_courses_screen.dart';
import '../../features/client/screens/client_plans_screen.dart';

// Shared
import '../../features/profile/screens/profile_screen.dart';
import '../../features/shared/screens/studio_info_screen.dart';
import '../../features/shared/screens/notifications_screen.dart';

// Shells
import '../../shared/widgets/owner_shell.dart';
import '../../shared/widgets/staff_shell.dart';
import '../../shared/widgets/client_shell.dart';

import '../models/user_role.dart';
import '../providers/studio_provider.dart';

// ─── Notifier ────────────────────────────────────────────────────────────────

class _RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  _RouterNotifier(this._ref) {
    _ref.listen(authStateProvider, (prev, next) => notifyListeners());
    _ref.listen(appRolesProvider,  (prev, next) => notifyListeners());
  }

  String? redirect(BuildContext context, GoRouterState state) {
    final authAsync  = _ref.read(authStateProvider);
    final isLoggedIn = authAsync.whenOrNull(
            data: (s) => s.session != null) ?? false;

    final loc          = state.matchedLocation;
    final isLoginRoute = loc == '/login';
    final isPublicRoute = loc.startsWith('/u/');

    if (!isLoggedIn && !isLoginRoute) return '/login';
    if (!isLoggedIn) return null;
    if (isPublicRoute) return null;

    final rolesAsync = _ref.read(appRolesProvider);
    final roles      = rolesAsync.whenOrNull(data: (r) => r);
    if (roles == null) return null;

    final home = roles.homeRoute;
    if (isLoginRoute) return home;
    if (!_isOnCorrectSection(loc, roles)) return home;

    return null;
  }

  bool _isOnCorrectSection(String loc, AppRoles roles) {
    return switch (roles.primaryRole) {
      UserRole.gymOwner => loc.startsWith('/owner'),
      UserRole.trainer  => loc.startsWith('/staff'),
      UserRole.client   => loc.startsWith('/client'),
    };
  }
}

// ─── Provider ────────────────────────────────────────────────────────────────

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);

  return GoRouter(
    initialLocation: '/client/calendar',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      // ── Auth ────────────────────────────────────────────────────────────────
      GoRoute(path: '/login', builder: (ctx, state) => const LoginScreen()),

      // ── Profilo pubblico (bypass auth) ───────────────────────────────────────
      GoRoute(
        path: '/u/:userId',
        builder: (ctx, state) =>
            PublicProfileScreen(userId: state.pathParameters['userId']!),
      ),

      // ── Gym Owner ────────────────────────────────────────────────────────────
      ShellRoute(
        builder: (ctx, state, child) => OwnerShell(child: child),
        routes: [
          GoRoute(path: '/owner/calendar',
              builder: (ctx, state) => const OwnerCalendarScreen()),
          GoRoute(path: '/owner/roster/:lessonId',
              builder: (ctx, state) => RosterScreen(
                    lessonId: state.pathParameters['lessonId']!)),
          GoRoute(path: '/owner/courses',
              builder: (ctx, state) => const CoursesScreen()),
          GoRoute(path: '/owner/courses/:courseId',
              builder: (ctx, state) => CourseDetailScreen(
                    courseId: state.pathParameters['courseId']!)),
          GoRoute(path: '/owner/manage',
              builder: (ctx, state) => const OwnerManageScreen()),
          GoRoute(path: '/owner/rooms',
              builder: (ctx, state) => const RoomsScreen()),
          GoRoute(path: '/owner/team',
              builder: (ctx, state) => const TeamScreen()),
          GoRoute(path: '/owner/clients',
              builder: (ctx, state) => const ClientsScreen()),
          GoRoute(path: '/owner/clients/:clientId',
              builder: (ctx, state) => ClientDetailScreen(
                    userId: state.pathParameters['clientId']!)),
          GoRoute(path: '/owner/plans',
              builder: (ctx, state) => const PlansScreen()),
          GoRoute(path: '/owner/studio',
              builder: (ctx, state) => const StudioInfoScreen()),
          GoRoute(path: '/owner/notifications',
              builder: (ctx, state) => const NotificationsScreen()),
          GoRoute(path: '/owner/profile',
              builder: (ctx, state) => const ProfileScreen()),
        ],
      ),

      // ── Staff (trainer) ──────────────────────────────────────────────────────
      ShellRoute(
        builder: (ctx, state, child) => StaffShell(child: child),
        routes: [
          GoRoute(path: '/staff/calendar',
              builder: (ctx, state) => const StaffCalendarScreen()),
          GoRoute(path: '/staff/courses',
              builder: (ctx, state) => const MyCoursesScreen()),
          GoRoute(path: '/staff/courses/:courseId',
              builder: (ctx, state) => CourseDetailScreen(
                    courseId: state.pathParameters['courseId']!)),
          GoRoute(path: '/staff/roster/:lessonId',
              builder: (ctx, state) => RosterScreen(
                    lessonId: state.pathParameters['lessonId']!)),
          GoRoute(path: '/staff/studio',
              builder: (ctx, state) => const StudioInfoScreen()),
          GoRoute(path: '/staff/notifications',
              builder: (ctx, state) => const NotificationsScreen()),
          GoRoute(path: '/staff/profile',
              builder: (ctx, state) => const ProfileScreen()),
        ],
      ),

      // ── Client ───────────────────────────────────────────────────────────────
      ShellRoute(
        builder: (ctx, state, child) => ClientShell(child: child),
        routes: [
          GoRoute(path: '/client/calendar',
              builder: (ctx, state) => const ClientCalendarScreen()),
          GoRoute(path: '/client/courses',
              builder: (ctx, state) => const ClientCoursesScreen()),
          GoRoute(path: '/client/courses/:courseId',
              builder: (ctx, state) => CourseDetailScreen(
                    courseId: state.pathParameters['courseId']!)),
          GoRoute(path: '/client/bookings',
              builder: (ctx, state) => const MyBookingsScreen()),
          GoRoute(path: '/client/plans',
              builder: (ctx, state) => const ClientPlansScreen()),
          GoRoute(path: '/client/studio',
              builder: (ctx, state) => const StudioInfoScreen()),
          GoRoute(path: '/client/notifications',
              builder: (ctx, state) => const NotificationsScreen()),
          GoRoute(path: '/client/profile',
              builder: (ctx, state) => const ProfileScreen()),
        ],
      ),
    ],
  );
});
