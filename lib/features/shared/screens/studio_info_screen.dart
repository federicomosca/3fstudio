import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/providers/studio_provider.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/profile/screens/profile_screen.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _studioInfoProvider =
    FutureProvider<Map<String, dynamic>?>((ref) async {
  final studioId = ref.watch(currentStudioIdProvider);
  if (studioId == null) return null;
  final client = ref.watch(supabaseClientProvider);
  final data   = await client
      .from('studios')
      .select('id, name, address, description')
      .eq('id', studioId)
      .maybeSingle();
  return data;
});

final _studioTrainersProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final studioId = ref.watch(currentStudioIdProvider);
  if (studioId == null) return [];
  final client = ref.watch(supabaseClientProvider);

  final data = await client
      .from('user_studio_roles')
      .select('role, users(id, full_name, bio, avatar_url, specializations)')
      .eq('studio_id', studioId)
      .inFilter('role', ['trainer', 'class_owner', 'gym_owner']);

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

// ── Screen ────────────────────────────────────────────────────────────────────

class StudioInfoScreen extends ConsumerWidget {
  const StudioInfoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studioAsync   = ref.watch(_studioInfoProvider);
    final trainersAsync = ref.watch(_studioTrainersProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── AppBar ──────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 140,
            pinned: true,
            backgroundColor: AppTheme.charcoal,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding:
                  const EdgeInsets.fromLTRB(16, 0, 16, 16),
              title: studioAsync.maybeWhen(
                data: (s) => Text(
                  s?['name'] as String? ?? '3F Studio',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                orElse: () => const Text('Studio',
                    style: TextStyle(color: Colors.white)),
              ),
              background: Container(
                color: AppTheme.charcoal,
                child: const Align(
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

          // ── Content ─────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: studioAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Errore: $e',
                    style: const TextStyle(color: Colors.red)),
              ),
              data: (studio) => Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // Description
                    if (studio?['description'] != null &&
                        (studio!['description'] as String).isNotEmpty) ...[
                      _SectionTitle('Chi siamo'),
                      const SizedBox(height: 8),
                      _Card(
                        child: Text(
                          studio['description'] as String,
                          style: const TextStyle(height: 1.6),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Sedi
                    _SectionTitle('Le nostre sedi'),
                    const SizedBox(height: 8),
                    _InfoRow(
                      icon: Icons.location_on_outlined,
                      title: 'Sede principale',
                      subtitle: 'Via Aquileia, 34 – Palermo',
                    ),
                    const SizedBox(height: 8),
                    _InfoRow(
                      icon: Icons.location_on_outlined,
                      title: 'Seconda sede',
                      subtitle: 'Via Regione Siciliana, 3604 – Palermo',
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),

          // ── Team ────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: _SectionTitle('Il nostro team'),
            ),
          ),

          trainersAsync.when(
            loading: () => const SliverToBoxAdapter(
                child: Center(child: CircularProgressIndicator())),
            error: (e, _) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Errore: $e',
                      style: const TextStyle(color: Colors.red)),
                )),
            data: (trainers) => SliverPadding(
              padding:
                  const EdgeInsets.fromLTRB(16, 8, 16, 32),
              sliver: SliverList.separated(
                itemCount: trainers.length,
                separatorBuilder: (context, i) =>
                    const SizedBox(height: 8),
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

// ── Trainer tile ──────────────────────────────────────────────────────────────

class _TrainerTile extends StatelessWidget {
  final Map<String, dynamic> trainer;
  const _TrainerTile({required this.trainer});

  @override
  Widget build(BuildContext context) {
    final name  = trainer['full_name'] as String? ?? '—';
    final bio   = trainer['bio']       as String?;
    final specs = (trainer['specializations'] as List?)
            ?.cast<String>() ??
        [];

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
              name:      name,
              radius:    26,
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
                          color: Theme.of(context).colorScheme.onSurface.withAlpha(150), fontSize: 12),
                    ),
                  ],
                  if (specs.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4, runSpacing: 4,
                      children: specs
                          .take(3)
                          .map((s) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.lime.withAlpha(40),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(s,
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(context).colorScheme.onSurface)),
                              ))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: Theme.of(context).colorScheme.onSurface.withAlpha(100),
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

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
        child: child,
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
          Icon(icon, size: 18,
              color: Theme.of(context).colorScheme.onSurface.withAlpha(180)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurface.withAlpha(150),
                      fontWeight: FontWeight.w600)),
              Text(subtitle,
                  style: const TextStyle(fontWeight: FontWeight.w500)),
            ],
          ),
        ]),
      );
}
