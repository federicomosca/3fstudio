import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/course_type.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/selected_studio_provider.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/profile/screens/profile_screen.dart';

// ── Providers (visione globale — non filtrata per sede selezionata) ───────────

/// Tutte le sedi accessibili dall'utente corrente
final _studioSediProvider = userSediProvider;

/// Tutti i membri del team su tutte le sedi dell'utente
final _allTeamProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final sedi = await ref.watch(userSediProvider.future);
  if (sedi.isEmpty) return [];

  final client   = ref.watch(supabaseClientProvider);
  final studioIds = sedi.map((s) => s.id).toList();

  final data = await client
      .from('user_studio_roles')
      .select('role, users(id, full_name, bio, avatar_url, specializations)')
      .inFilter('studio_id', studioIds)
      .inFilter('role', ['trainer', 'owner']);

  // Deduplica per utente
  final Map<String, Map<String, dynamic>> byUser = {};
  for (final row in (data as List)) {
    final user = row['users'] as Map<String, dynamic>?;
    if (user == null) continue;
    final uid = user['id'] as String;
    byUser[uid] ??= user;
  }
  return byUser.values.toList()
    ..sort((a, b) =>
        (a['full_name'] as String).compareTo(b['full_name'] as String));
});

/// Tutte le sale su tutte le sedi dell'utente
final _allRoomsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final sedi = await ref.watch(userSediProvider.future);
  if (sedi.isEmpty) return [];

  final client    = ref.watch(supabaseClientProvider);
  final studioIds = sedi.map((s) => s.id).toList();

  final data = await client
      .from('rooms')
      .select('id, name, capacity, studio_id')
      .inFilter('studio_id', studioIds)
      .order('name');

  return (data as List).cast<Map<String, dynamic>>();
});

/// Tutti i corsi su tutte le sedi dell'utente
final _allCoursesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final sedi = await ref.watch(userSediProvider.future);
  if (sedi.isEmpty) return [];

  final client    = ref.watch(supabaseClientProvider);
  final studioIds = sedi.map((s) => s.id).toList();

  final data = await client
      .from('courses')
      .select(
          'id, name, type, '
          'users!class_owner_id(id, full_name)')
      .inFilter('studio_id', studioIds)
      .order('name');

  return (data as List).cast<Map<String, dynamic>>();
});

// ── Screen ────────────────────────────────────────────────────────────────────

class StudioInfoScreen extends ConsumerWidget {
  const StudioInfoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sediAsync    = ref.watch(_studioSediProvider);
    final roomsAsync   = ref.watch(_allRoomsProvider);
    final teamAsync    = ref.watch(_allTeamProvider);
    final coursesAsync = ref.watch(_allCoursesProvider);

    final loc = GoRouterState.of(context).uri.path;
    final courseBasePath = loc.startsWith('/owner')
        ? '/owner/courses'
        : loc.startsWith('/staff')
            ? '/staff/courses'
            : '/client/courses';

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── AppBar ──────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 140,
            pinned: true,
            backgroundColor: AppTheme.charcoal,
            foregroundColor: Colors.white,
            flexibleSpace: const FlexibleSpaceBar(
              titlePadding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              title: Text(
                '3F Training',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              background: ColoredBox(
                color: AppTheme.charcoal,
                child: Align(
                  alignment: Alignment(0, 0.3),
                  child: Text(
                    '3F',
                    style: TextStyle(
                      color: AppTheme.lime,
                      fontSize: 60,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -2,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Sedi ────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: _SectionTitle('Le nostre sedi'),
            ),
          ),

          sediAsync.when(
            loading: () => const SliverToBoxAdapter(
                child: Center(child: CircularProgressIndicator())),
            error: (e, _) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Errore: $e',
                      style: const TextStyle(color: Colors.red)),
                )),
            data: (sedi) => SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList.separated(
                itemCount: sedi.length,
                separatorBuilder: (context, i) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final sede = sedi[i];
                  return _InfoRow(
                    icon: Icons.location_on_outlined,
                    title: sede.name,
                    subtitle: sede.address ?? '—',
                  );
                },
              ),
            ),
          ),

          // ── Sale ────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: _SectionTitle('Le nostre sale'),
            ),
          ),

          roomsAsync.when(
            loading: () => const SliverToBoxAdapter(
                child: Center(child: CircularProgressIndicator())),
            error: (e, _) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Errore: $e',
                      style: const TextStyle(color: Colors.red)),
                )),
            data: (rooms) => rooms.isEmpty
                ? SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Text(
                        'Nessuna sala disponibile',
                        style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withAlpha(150)),
                      ),
                    ),
                  )
                : SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList.separated(
                      itemCount: rooms.length,
                      separatorBuilder: (context, i) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, i) => _RoomTile(room: rooms[i]),
                    ),
                  ),
          ),

          // ── Corsi ───────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: _SectionTitle('I nostri corsi'),
            ),
          ),

          coursesAsync.when(
            loading: () => const SliverToBoxAdapter(
                child: Center(child: CircularProgressIndicator())),
            error: (e, _) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Errore: $e',
                      style: const TextStyle(color: Colors.red)),
                )),
            data: (courses) => courses.isEmpty
                ? SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Text(
                        'Nessun corso disponibile',
                        style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withAlpha(150)),
                      ),
                    ),
                  )
                : SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList.separated(
                      itemCount: courses.length,
                      separatorBuilder: (context, i) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, i) =>
                          _CourseTile(course: courses[i], courseBasePath: courseBasePath),
                    ),
                  ),
          ),

          // ── Team ────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: _SectionTitle('Il nostro team'),
            ),
          ),

          teamAsync.when(
            loading: () => const SliverToBoxAdapter(
                child: Center(child: CircularProgressIndicator())),
            error: (e, _) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Errore: $e',
                      style: const TextStyle(color: Colors.red)),
                )),
            data: (trainers) => SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
              sliver: SliverList.separated(
                itemCount: trainers.length,
                separatorBuilder: (context, i) => const SizedBox(height: 8),
                itemBuilder: (context, i) =>
                    _TrainerTile(trainer: trainers[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Room tile ─────────────────────────────────────────────────────────────────

class _RoomTile extends StatelessWidget {
  final Map<String, dynamic> room;
  const _RoomTile({required this.room});

  @override
  Widget build(BuildContext context) {
    final capacity = room['capacity'] as int?;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.cyan.withAlpha(30),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.meeting_room_outlined,
              color: AppTheme.cyan,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              room['name'] as String,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          if (capacity != null)
            Row(
              children: [
                Icon(Icons.people_outline,
                    size: 14,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withAlpha(150)),
                const SizedBox(width: 4),
                Text(
                  '$capacity',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withAlpha(150),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ── Course tile ───────────────────────────────────────────────────────────────

class _CourseTile extends StatelessWidget {
  final Map<String, dynamic> course;
  final String courseBasePath;
  const _CourseTile({required this.course, required this.courseBasePath});

  @override
  Widget build(BuildContext context) {
    final courseType = course['type'] as String? ?? 'group';
    final owner   = course['users'] as Map<String, dynamic>?;

    return GestureDetector(
      onTap: () => context.push('$courseBasePath/${course['id']}'),
      child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: courseType == 'personal'
                  ? const Color(0xFF9C27B0).withAlpha(30)
                  : AppTheme.blue.withAlpha(30),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              courseTypeIcon(courseType),
              color: courseType == 'personal' ? const Color(0xFFCE93D8) : AppTheme.blue,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course['name'] as String,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (owner != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    owner['full_name'] as String,
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withAlpha(150)),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: courseType == 'personal'
                  ? const Color(0xFF9C27B0).withAlpha(20)
                  : AppTheme.blue.withAlpha(20),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              courseTypeLabel(courseType),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: courseType == 'personal' ? const Color(0xFFCE93D8) : AppTheme.blue,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right,
              size: 18,
              color: Theme.of(context).colorScheme.onSurface.withAlpha(100)),
        ],
      ),
    ),
    );
  }
}

// ── Trainer tile ──────────────────────────────────────────────────────────────

class _TrainerTile extends StatelessWidget {
  final Map<String, dynamic> trainer;
  const _TrainerTile({required this.trainer});

  @override
  Widget build(BuildContext context) {
    final name  = trainer['full_name'] as String? ?? '—';
    final bio   = trainer['bio'] as String?;
    final specs = (trainer['specializations'] as List?)?.cast<String>() ?? [];

    return GestureDetector(
      onTap: () => context.push('/u/${trainer['id']}'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
        child: Row(
          children: [
            UserAvatar(
              avatarUrl: trainer['avatar_url'] as String?,
              name: name,
              radius: 26,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  if (bio != null && bio.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      bio,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withAlpha(150),
                          fontSize: 12),
                    ),
                  ],
                  if (specs.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: specs
                          .take(3)
                          .map((s) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.lime.withAlpha(40),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  s,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface,
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color:
                    Theme.of(context).colorScheme.onSurface.withAlpha(100),
                size: 18),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: Theme.of(context).colorScheme.onSurface.withAlpha(180),
          letterSpacing: 0.4,
        ),
      );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _InfoRow(
      {required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
        child: Row(children: [
          Icon(icon,
              size: 18,
              color:
                  Theme.of(context).colorScheme.onSurface.withAlpha(180)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withAlpha(150)),
                ),
              ],
            ),
          ),
        ]),
      );
}
