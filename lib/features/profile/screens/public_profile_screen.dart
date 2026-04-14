import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/profile_provider.dart';
import 'profile_screen.dart' show UserAvatar, SpecChip, InstagramChip;

class PublicProfileScreen extends ConsumerWidget {
  final String userId;
  const PublicProfileScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(publicProfileProvider(userId));

    return Scaffold(
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('Errore: $e')),
        data:    (profile) => profile == null
            ? const Center(child: Text('Profilo non trovato'))
            : _PublicProfileBody(profile: profile),
      ),
    );
  }
}

class _PublicProfileBody extends StatelessWidget {
  final UserProfile profile;
  const _PublicProfileBody({required this.profile});

  @override
  Widget build(BuildContext context) {
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
                  const SizedBox(height: 56), // space for status bar
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

                // Placeholder se profilo è ancora vuoto
                if ((profile.bio == null || profile.bio!.isEmpty) &&
                    profile.specializations.isEmpty) ...[
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Column(
                        children: [
                          Icon(Icons.person_outline, size: 56,
                              color: Theme.of(context).colorScheme.onSurface.withAlpha(60)),
                          const SizedBox(height: 12),
                          Text(
                            'Profilo ancora in costruzione',
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface.withAlpha(150),
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
