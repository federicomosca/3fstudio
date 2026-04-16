import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/user_role.dart';
import '../../../core/providers/studio_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import 'profile_screen.dart' show UserAvatar, SpecChip, InstagramChip;

// ── Provider corsi del trainer ────────────────────────────────────────────────

final _trainerCoursesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, userId) async {
  final client = ref.watch(supabaseClientProvider);
  final data = await client
      .from('courses')
      .select('id, name, type')
      .eq('class_owner_id', userId)
      .order('name');
  return (data as List).cast<Map<String, dynamic>>();
});

// ── Screen ────────────────────────────────────────────────────────────────────

class PublicProfileScreen extends ConsumerWidget {
  final String userId;
  const PublicProfileScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(publicProfileProvider(userId));

    // Determina il prefisso route corretto per i link ai corsi
    final roles = ref.watch(appRolesProvider).whenOrNull(data: (r) => r);
    final courseRoutePrefix = switch (roles?.primaryRole) {
      UserRole.gymOwner   => '/owner',
      UserRole.classOwner => '/staff',
      UserRole.trainer    => '/staff',
      _                   => '/client',
    };

    return Scaffold(
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('Errore: $e')),
        data:    (profile) => profile == null
            ? const Center(child: Text('Profilo non trovato'))
            : _PublicProfileBody(
                profile: profile,
                courseRoutePrefix: courseRoutePrefix,
              ),
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _PublicProfileBody extends ConsumerWidget {
  final UserProfile profile;
  final String courseRoutePrefix;
  const _PublicProfileBody({
    required this.profile,
    required this.courseRoutePrefix,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coursesAsync = ref.watch(_trainerCoursesProvider(profile.id));

    return CustomScrollView(
      slivers: [
        // ── AppBar collassabile con avatar ───────────────────────────────
        SliverAppBar(
          expandedHeight: 260,
          pinned:         true,
          stretch:        true,
          backgroundColor: AppTheme.charcoal,
          foregroundColor: Colors.white,
          flexibleSpace: FlexibleSpaceBar(
            stretchModes: const [StretchMode.zoomBackground],
            background: Container(
              color: AppTheme.charcoal,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 56),
                  UserAvatar(
                    avatarUrl: profile.avatarUrl,
                    name:      profile.fullName,
                    radius:    56,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    profile.fullName,
                    style: const TextStyle(
                      color:      Colors.white,
                      fontSize:   24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (profile.instagramUrl != null)
                    InstagramChip(url: profile.instagramUrl!),
                ],
              ),
            ),
          ),
        ),

        // ── Contenuto ────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // Bio
                if (profile.bio != null && profile.bio!.isNotEmpty) ...[
                  _Section(title: 'Chi sono'),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Theme.of(context).colorScheme.outline),
                    ),
                    child: Text(
                      profile.bio!,
                      style: const TextStyle(height: 1.6, fontSize: 15),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Specializzazioni
                if (profile.specializations.isNotEmpty) ...[
                  _Section(title: 'Specializzazioni'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: profile.specializations
                        .map((s) => SpecChip(label: s))
                        .toList(),
                  ),
                  const SizedBox(height: 24),
                ],

                // Corsi
                coursesAsync.maybeWhen(
                  data: (courses) {
                    if (courses.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Section(title: 'Corsi'),
                        const SizedBox(height: 10),
                        ...courses.map((c) => _CourseTile(
                              course: c,
                              routePrefix: courseRoutePrefix,
                            )),
                        const SizedBox(height: 24),
                      ],
                    );
                  },
                  orElse: () => const SizedBox.shrink(),
                ),

                // Placeholder se profilo vuoto
                if ((profile.bio == null || profile.bio!.isEmpty) &&
                    profile.specializations.isEmpty) ...[
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Column(
                        children: [
                          Icon(Icons.person_outline,
                              size: 56,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withAlpha(60)),
                          const SizedBox(height: 12),
                          Text(
                            'Profilo ancora in costruzione',
                            style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withAlpha(150),
                                fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Course tile ───────────────────────────────────────────────────────────────

class _CourseTile extends StatelessWidget {
  final Map<String, dynamic> course;
  final String routePrefix;
  const _CourseTile({required this.course, required this.routePrefix});

  @override
  Widget build(BuildContext context) {
    final isGroup = course['type'] == 'group';
    return GestureDetector(
      onTap: () => context.push('$routePrefix/courses/${course['id']}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: isGroup
                    ? AppTheme.blue.withAlpha(30)
                    : const Color(0xFF9C27B0).withAlpha(30),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isGroup ? Icons.group_outlined : Icons.person_outline,
                color: isGroup ? AppTheme.blue : const Color(0xFFCE93D8),
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                course['name'] as String,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: Theme.of(context).colorScheme.onSurface.withAlpha(100),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  const _Section({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize:      13,
        fontWeight:    FontWeight.w800,
        color:         Theme.of(context).colorScheme.onSurface.withAlpha(180),
        letterSpacing: 0.5,
      ),
    );
  }
}
