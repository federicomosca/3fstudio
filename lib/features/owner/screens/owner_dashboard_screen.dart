import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../features/auth/providers/auth_provider.dart';
import '../../../core/providers/studio_provider.dart';

// ── Onboarding ───────────────────────────────────────────────────────────────

class _OnboardingStatus {
  final bool hasRoom;
  final bool hasTrainer;
  final bool hasCourse;
  final bool hasPlan;

  const _OnboardingStatus({
    required this.hasRoom,
    required this.hasTrainer,
    required this.hasCourse,
    required this.hasPlan,
  });

  bool get isComplete => hasRoom && hasTrainer && hasCourse && hasPlan;
  int get completedCount =>
      [hasRoom, hasTrainer, hasCourse, hasPlan].where((b) => b).length;
}

final _onboardingProvider =
    FutureProvider<_OnboardingStatus>((ref) async {
  final studioId = ref.watch(currentStudioIdProvider);
  if (studioId == null) {
    return const _OnboardingStatus(
        hasRoom: false, hasTrainer: false, hasCourse: false, hasPlan: false);
  }

  final client = ref.watch(supabaseClientProvider);

  final results = await Future.wait([
    client.from('rooms').select('id').eq('studio_id', studioId).limit(1),
    client
        .from('user_studio_roles')
        .select('user_id')
        .eq('studio_id', studioId)
        .eq('role', 'trainer')
        .limit(1),
    client.from('courses').select('id').eq('studio_id', studioId).limit(1),
    client.from('plans').select('id').eq('studio_id', studioId).limit(1),
  ]);

  return _OnboardingStatus(
    hasRoom:    (results[0] as List).isNotEmpty,
    hasTrainer: (results[1] as List).isNotEmpty,
    hasCourse:  (results[2] as List).isNotEmpty,
    hasPlan:    (results[3] as List).isNotEmpty,
  );
});

// ── Today stats ───────────────────────────────────────────────────────────────

final _todayStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  final studioId = ref.watch(currentStudioIdProvider);
  if (studioId == null) return {};

  final client = ref.watch(supabaseClientProvider);
  final today = DateTime.now();
  final start =
      DateTime(today.year, today.month, today.day).toUtc().toIso8601String();
  final end = DateTime(today.year, today.month, today.day + 1)
      .toUtc()
      .toIso8601String();

  final lessons = await client
      .from('lessons')
      .select('id, bookings(count)')
      .gte('starts_at', start)
      .lt('starts_at', end)
      .eq('courses.studio_id', studioId);

  int totalLessons = (lessons as List).length;
  int totalBookings = 0;
  for (final l in lessons) {
    final bookings = l['bookings'] as List? ?? [];
    totalBookings +=
        bookings.isNotEmpty ? (bookings.first['count'] as int? ?? 0) : 0;
  }

  return {'lessons': totalLessons, 'bookings': totalBookings};
});

// ── Screen ───────────────────────────────────────────────────────────────────

class OwnerDashboardScreen extends ConsumerWidget {
  const OwnerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final today = DateFormat('EEEE d MMMM', 'it').format(DateTime.now());
    final stats = ref.watch(_todayStatsProvider);
    final onboarding = ref.watch(_onboardingProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(today,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurface.withAlpha(150))),
          const SizedBox(height: 4),
          Text('Buongiorno 👋',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),

          // ── Onboarding wizard ────────────────────────────────────────────
          onboarding.when(
            loading: () => const SizedBox.shrink(),
            error: (e, _) => const SizedBox.shrink(),
            data: (status) => status.isComplete
                ? const SizedBox.shrink()
                : _OnboardingCard(status: status),
          ),

          // ── Stat cards oggi ───────────────────────────────────────────────
          Text('Oggi',
              style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(180), fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          stats.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => const SizedBox.shrink(),
            data: (s) => Row(
              children: [
                _StatCard(
                  icon: Icons.event_note_outlined,
                  label: 'Lezioni',
                  value: '${s['lessons'] ?? 0}',
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                _StatCard(
                  icon: Icons.people_outline,
                  label: 'Prenotazioni',
                  value: '${s['bookings'] ?? 0}',
                  color: const Color(0xFF66BB6A),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Menu gestione ─────────────────────────────────────────────────
          Text('Gestione',
              style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(180), fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _MenuGrid(items: const [
            _MenuItem(
                icon: Icons.fitness_center_outlined,
                label: 'Corsi',
                route: '/owner/courses'),
            _MenuItem(
                icon: Icons.place_outlined,
                label: 'Spazi',
                route: '/owner/rooms'),
            _MenuItem(
                icon: Icons.group_outlined,
                label: 'Team',
                route: '/owner/team'),
            _MenuItem(
                icon: Icons.people_outline,
                label: 'Clienti',
                route: '/owner/clients'),
            _MenuItem(
                icon: Icons.card_membership_outlined,
                label: 'Piani',
                route: '/owner/plans'),
          ]),
        ],
      ),
    );
  }
}

// ── Onboarding card ───────────────────────────────────────────────────────────

class _OnboardingCard extends StatelessWidget {
  final _OnboardingStatus status;
  const _OnboardingCard({required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = status.completedCount / 4;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withAlpha(18),
            theme.colorScheme.primaryContainer.withAlpha(30),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.primary.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.rocket_launch_outlined,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Configura il tuo studio',
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      Text(
                        '${status.completedCount} di 4 completati',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.onSurface.withAlpha(180)),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${(progress * 100).round()}%',
                  style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary),
                ),
              ],
            ),
          ),

          // Progress bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: theme.colorScheme.outline.withAlpha(80),
                valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
              ),
            ),
          ),

          // Steps
          _OnboardingStep(
            done: status.hasRoom,
            icon: Icons.place_outlined,
            title: 'Aggiungi uno spazio',
            subtitle: 'Le lezioni hanno bisogno di uno spazio',
            route: '/owner/rooms',
            isLast: false,
          ),
          _OnboardingStep(
            done: status.hasTrainer,
            icon: Icons.sports_outlined,
            title: 'Invita un trainer',
            subtitle: 'Chi guiderà i tuoi clienti?',
            route: '/owner/team',
            isLast: false,
          ),
          _OnboardingStep(
            done: status.hasCourse,
            icon: Icons.fitness_center_outlined,
            title: 'Crea un corso',
            subtitle: 'Yoga, HIIT, Pilates... inizia dal primo',
            route: '/owner/courses',
            isLast: false,
          ),
          _OnboardingStep(
            done: status.hasPlan,
            icon: Icons.card_membership_outlined,
            title: 'Crea un piano abbonamento',
            subtitle: 'Credit, illimitato o prova gratuita',
            route: '/owner/plans',
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _OnboardingStep extends StatelessWidget {
  final bool done;
  final IconData icon;
  final String title;
  final String subtitle;
  final String route;
  final bool isLast;

  const _OnboardingStep({
    required this.done,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = done
        ? const Color(0xFF66BB6A)
        : theme.colorScheme.primary;

    return InkWell(
      onTap: done ? null : () => context.go(route),
      borderRadius: isLast
          ? const BorderRadius.only(
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16))
          : BorderRadius.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            // Indicator circle
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done
                    ? Colors.green.withAlpha(40)
                    : theme.colorScheme.primary.withAlpha(15),
                border: Border.all(
                  color: done
                      ? Colors.green.withAlpha(120)
                      : theme.colorScheme.primary.withAlpha(80),
                ),
              ),
              child: done
                  ? const Icon(Icons.check, size: 18, color: Color(0xFF66BB6A))
                  : Icon(icon, size: 18, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: done ? theme.colorScheme.onSurface.withAlpha(150) : null,
                      decoration: done ? TextDecoration.lineThrough : null,
                      decorationColor: theme.colorScheme.onSurface.withAlpha(100),
                    ),
                  ),
                  if (!done)
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurface.withAlpha(150)),
                    ),
                ],
              ),
            ),
            if (!done)
              Icon(Icons.arrow_forward_ios,
                  size: 14, color: color.withAlpha(180)),
          ],
        ),
      ),
    );
  }
}

// ── Stat card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: color.withAlpha(25),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
                Text(label,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withAlpha(180))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Menu grid ─────────────────────────────────────────────────────────────────

class _MenuItem {
  final IconData icon;
  final String label;
  final String route;
  const _MenuItem(
      {required this.icon, required this.label, required this.route});
}

class _MenuGrid extends StatelessWidget {
  final List<_MenuItem> items;
  const _MenuGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1,
      children: items.map((item) => _MenuCell(item: item)).toList(),
    );
  }
}

class _MenuCell extends StatelessWidget {
  final _MenuItem item;
  const _MenuCell({required this.item});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => context.go(item.route),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item.icon,
                color: Theme.of(context).colorScheme.primary, size: 28),
            const SizedBox(height: 8),
            Text(item.label,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
