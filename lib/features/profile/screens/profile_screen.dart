import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/studio_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/profile_provider.dart';

// ── Specializzazioni preset per il mondo AL.FA.SE ─────────────────────────────
const _kSpecializations = [
  'Kettlebell Training',
  'Body Weight',
  'Animal Flow',
  'Calisthenics',
  'Weight Training',
  'Cardio',
  'Ginnastica Posturale',
  'Flow Motion',
  'Salto con la corda',
  'Personal Training',
  'Preparazione Atletica',
  'Rieducazione Motoria',
];

// ── Screen ────────────────────────────────────────────────────────────────────

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roles = ref.watch(appRolesProvider).whenOrNull(data: (r) => r);
    final isStaff = roles?.isGymOwner == true || roles?.isTrainer == true;

    return isStaff
        ? const _StaffProfileScreen()
        : const _ClientProfileScreen();
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// STAFF / OWNER — profilo pubblico modificabile
// ══════════════════════════════════════════════════════════════════════════════

class _StaffProfileScreen extends ConsumerStatefulWidget {
  const _StaffProfileScreen();

  @override
  ConsumerState<_StaffProfileScreen> createState() =>
      _StaffProfileScreenState();
}

class _StaffProfileScreenState extends ConsumerState<_StaffProfileScreen> {
  bool _editing = false;

  // Controllers per il form di modifica
  final _nameCtrl      = TextEditingController();
  final _phoneCtrl     = TextEditingController();
  final _bioCtrl       = TextEditingController();
  final _instaCtrl     = TextEditingController();
  List<String> _selectedSpecs = [];
  XFile?      _pickedXFile;
  Uint8List?  _pickedBytes;
  bool        _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _bioCtrl.dispose();
    _instaCtrl.dispose();
    super.dispose();
  }

  void _startEdit(UserProfile profile) {
    _nameCtrl.text  = profile.fullName;
    _phoneCtrl.text = profile.phone ?? '';
    _bioCtrl.text   = profile.bio ?? '';
    _instaCtrl.text = profile.instagramUrl ?? '';
    _selectedSpecs  = List.from(profile.specializations);
    _pickedXFile    = null;
    _pickedBytes    = null;
    setState(() => _editing = true);
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final xfile  = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800, maxHeight: 800,
      imageQuality: 85,
    );
    if (xfile != null) {
      final bytes = await xfile.readAsBytes();
      setState(() {
        _pickedXFile = xfile;
        _pickedBytes = bytes;
      });
    }
  }

  Future<void> _save() async {
    final current = ref.read(myProfileProvider).asData?.value;
    if (current == null) return;

    setState(() => _saving = true);
    try {
      // Upload avatar se cambiato (restituisce solo l'URL, non salva)
      String? newAvatarUrl = current.avatarUrl;
      if (_pickedXFile != null) {
        newAvatarUrl =
            await ref.read(myProfileProvider.notifier).uploadAvatar(_pickedXFile!);
      }

      // Costruisce il profilo aggiornato passando esplicitamente tutti i campi,
      // inclusi quelli che l'utente vuole svuotare (null esplicito).
      final updated = current.copyWith(
        fullName:        _nameCtrl.text.trim(),
        phone:           _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        bio:             _bioCtrl.text.trim().isEmpty   ? null : _bioCtrl.text.trim(),
        instagramUrl:    _instaCtrl.text.trim().isEmpty ? null : _instaCtrl.text.trim(),
        specializations: _selectedSpecs,
        avatarUrl:       newAvatarUrl,
      );

      await ref.read(myProfileProvider.notifier).save(updated);

      if (mounted) setState(() => _editing = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore nel salvataggio: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(myProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Modifica profilo' : 'Il mio profilo'),
        actions: [
          if (!_editing)
            profileAsync.whenOrNull(
              data: (p) => p != null
                  ? IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'Modifica',
                      onPressed: () => _startEdit(p),
                    )
                  : null,
            ) ?? const SizedBox.shrink(),
          if (_editing) ...[
            TextButton(
              onPressed: _saving ? null : () => setState(() => _editing = false),
              child: const Text('Annulla',
                  style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text('Salva',
                      style: TextStyle(
                          color: AppTheme.lime, fontWeight: FontWeight.w800)),
            ),
          ],
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('Errore: $e')),
        data:    (profile) => profile == null
            ? const Center(child: Text('Profilo non trovato'))
            : _editing
                ? _EditForm(
                    profile:       profile,
                    nameCtrl:      _nameCtrl,
                    phoneCtrl:     _phoneCtrl,
                    bioCtrl:       _bioCtrl,
                    instaCtrl:     _instaCtrl,
                    selectedSpecs: _selectedSpecs,
                    pickedBytes:   _pickedBytes,
                    onPickImage:   _pickImage,
                    onSpecToggle:  (s) => setState(() {
                      if (_selectedSpecs.contains(s)) {
                        _selectedSpecs.remove(s);
                      } else {
                        _selectedSpecs.add(s);
                      }
                    }),
                  )
                : _ProfileView(profile: profile, onEdit: () => _startEdit(profile)),
      ),
    );
  }
}

// ── Vista profilo (read) ──────────────────────────────────────────────────────

class _ProfileView extends ConsumerWidget {
  final UserProfile profile;
  final VoidCallback onEdit;
  const _ProfileView({required this.profile, required this.onEdit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      children: [
        // ── Header dark ────────────────────────────────────────────────────
        Container(
          color: AppTheme.charcoal,
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
          child: Column(
            children: [
              UserAvatar(avatarUrl: profile.avatarUrl, name: profile.fullName, radius: 52),
              const SizedBox(height: 16),
              Text(
                profile.fullName,
                style: const TextStyle(
                  color: Colors.white, fontSize: 22,
                  fontWeight: FontWeight.w900, letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                profile.email,
                style: TextStyle(color: Colors.white.withAlpha(140), fontSize: 13),
              ),
              if (profile.instagramUrl != null) ...[
                const SizedBox(height: 8),
                InstagramChip(url: profile.instagramUrl!),
              ],
            ],
          ),
        ),

        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // Bio
              if (profile.bio != null && profile.bio!.isNotEmpty) ...[
                _SectionTitle('Chi sono'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).colorScheme.outline),
                  ),
                  child: Text(profile.bio!, style: const TextStyle(height: 1.55)),
                ),
                const SizedBox(height: 20),
              ],

              // Specializzazioni
              if (profile.specializations.isNotEmpty) ...[
                _SectionTitle('Specializzazioni'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8, runSpacing: 6,
                  children: profile.specializations
                      .map((s) => SpecChip(label: s))
                      .toList(),
                ),
                const SizedBox(height: 20),
              ],

              // Contatti
              _SectionTitle('Contatti'),
              const SizedBox(height: 8),
              _InfoTile(icon: Icons.email_outlined, label: 'Email', value: profile.email),
              if (profile.phone != null)
                _InfoTile(icon: Icons.phone_outlined, label: 'Telefono', value: profile.phone!),
              const SizedBox(height: 24),

              // Impostazioni account
              const _AccountSettingsSection(),

              // Logout
              ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                tileColor: Theme.of(context).colorScheme.errorContainer.withAlpha(80),
                leading: Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
                title: Text('Esci',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w600)),
                onTap: () => _confirmLogout(context, ref),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Esci'),
        content: const Text('Vuoi disconnetterti?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Esci',
                  style: TextStyle(color: Theme.of(ctx).colorScheme.error))),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(authNotifierProvider.notifier).signOut();
    }
  }
}

// ── Form di modifica ──────────────────────────────────────────────────────────

class _EditForm extends StatelessWidget {
  final UserProfile        profile;
  final TextEditingController nameCtrl, phoneCtrl, bioCtrl, instaCtrl;
  final List<String>       selectedSpecs;
  final Uint8List?         pickedBytes;
  final VoidCallback       onPickImage;
  final ValueChanged<String> onSpecToggle;

  const _EditForm({
    required this.profile,
    required this.nameCtrl,
    required this.phoneCtrl,
    required this.bioCtrl,
    required this.instaCtrl,
    required this.selectedSpecs,
    required this.pickedBytes,
    required this.onPickImage,
    required this.onSpecToggle,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Avatar
        Center(
          child: Stack(
            children: [
              pickedBytes != null
                  ? CircleAvatar(
                      radius: 52,
                      backgroundImage: MemoryImage(pickedBytes!),
                    )
                  : UserAvatar(
                      avatarUrl: profile.avatarUrl,
                      name:      profile.fullName,
                      radius:    52,
                    ),
              Positioned(
                bottom: 0, right: 0,
                child: GestureDetector(
                  onTap: onPickImage,
                  child: Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      color: AppTheme.lime,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        _FieldLabel('Nome completo'),
        const SizedBox(height: 6),
        TextField(
          controller: nameCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(prefixIcon: Icon(Icons.person_outlined)),
        ),
        const SizedBox(height: 16),

        _FieldLabel('Telefono'),
        const SizedBox(height: 6),
        TextField(
          controller: phoneCtrl,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(prefixIcon: Icon(Icons.phone_outlined)),
        ),
        const SizedBox(height: 16),

        _FieldLabel('Bio'),
        const SizedBox(height: 6),
        TextField(
          controller: bioCtrl,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'Raccontati: formazione, stile di allenamento, filosofia...',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 16),

        _FieldLabel('Instagram'),
        const SizedBox(height: 6),
        TextField(
          controller: instaCtrl,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.link),
            hintText: 'https://instagram.com/tuo_profilo',
          ),
        ),
        const SizedBox(height: 24),

        _FieldLabel('Specializzazioni'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: _kSpecializations.map((s) {
            final selected = selectedSpecs.contains(s);
            return FilterChip(
              label: Text(s),
              selected: selected,
              onSelected: (_) => onSpecToggle(s),
              selectedColor: AppTheme.lime.withAlpha(60),
              checkmarkColor: AppTheme.charcoal,
              side: BorderSide(
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline,
              ),
              labelStyle: TextStyle(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                fontSize: 13,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// CLIENT — piano + prossime prenotazioni + profilo modificabile
// ══════════════════════════════════════════════════════════════════════════════

class _ClientProfileScreen extends ConsumerStatefulWidget {
  const _ClientProfileScreen();

  @override
  ConsumerState<_ClientProfileScreen> createState() =>
      _ClientProfileScreenState();
}

class _ClientProfileScreenState extends ConsumerState<_ClientProfileScreen> {
  bool _editing = false;

  final _nameCtrl  = TextEditingController();
  final _phoneCtrl = TextEditingController();
  XFile?     _pickedXFile;
  Uint8List? _pickedBytes;
  bool       _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _startEdit(UserProfile profile) {
    _nameCtrl.text  = profile.fullName;
    _phoneCtrl.text = profile.phone ?? '';
    _pickedXFile    = null;
    _pickedBytes    = null;
    setState(() => _editing = true);
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final xfile  = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800, maxHeight: 800,
      imageQuality: 85,
    );
    if (xfile != null) {
      final bytes = await xfile.readAsBytes();
      setState(() {
        _pickedXFile = xfile;
        _pickedBytes = bytes;
      });
    }
  }

  Future<void> _save() async {
    final current = ref.read(myProfileProvider).asData?.value;
    if (current == null) return;

    setState(() => _saving = true);
    try {
      String? newAvatarUrl = current.avatarUrl;
      if (_pickedXFile != null) {
        newAvatarUrl =
            await ref.read(myProfileProvider.notifier).uploadAvatar(_pickedXFile!);
      }

      final updated = current.copyWith(
        fullName:  _nameCtrl.text.trim(),
        phone:     _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        avatarUrl: newAvatarUrl,
      );

      await ref.read(myProfileProvider.notifier).save(updated);

      if (mounted) setState(() => _editing = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore nel salvataggio: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(myProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Modifica profilo' : 'Profilo'),
        actions: [
          if (!_editing)
            profileAsync.whenOrNull(
              data: (p) => p != null
                  ? IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'Modifica',
                      onPressed: () => _startEdit(p),
                    )
                  : null,
            ) ?? const SizedBox.shrink(),
          if (_editing) ...[
            TextButton(
              onPressed: _saving ? null : () => setState(() => _editing = false),
              child: const Text('Annulla',
                  style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text('Salva',
                      style: TextStyle(
                          color: AppTheme.lime, fontWeight: FontWeight.w800)),
            ),
          ],
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('Errore: $e')),
        data:    (profile) => profile == null
            ? const Center(child: Text('Profilo non trovato'))
            : _editing
                ? _ClientEditForm(
                    profile:     profile,
                    nameCtrl:    _nameCtrl,
                    phoneCtrl:   _phoneCtrl,
                    pickedBytes: _pickedBytes,
                    onPickImage: _pickImage,
                  )
                : _ClientView(
                    profile: profile,
                    onEdit:  () => _startEdit(profile),
                  ),
      ),
    );
  }
}

// ── Vista client (read) ───────────────────────────────────────────────────────

class _ClientView extends ConsumerWidget {
  final UserProfile profile;
  final VoidCallback onEdit;
  const _ClientView({required this.profile, required this.onEdit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Avatar + nome
        Center(
          child: UserAvatar(
            avatarUrl: profile.avatarUrl,
            name:      profile.fullName,
            radius:    40,
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(profile.fullName,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        ),
        Center(
          child: Text(profile.email,
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(180))),
        ),
        if (profile.phone != null) ...[
          const SizedBox(height: 4),
          Center(
            child: Text(profile.phone!,
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(180))),
          ),
        ],
        const SizedBox(height: 28),

        _SectionTitle('Piano attivo'),
        const SizedBox(height: 8),
        ref.watch(activePlanProvider).when(
              data: (plan) => plan == null
                  ? _EmptyCard(text: 'Nessun piano attivo')
                  : _PlanCard(plan: plan),
              loading: () => const _LoadingCard(),
              error:   (e, _) => _EmptyCard(text: 'Errore nel caricamento'),
            ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => context.go('/client/plans'),
            icon: const Icon(Icons.card_membership_outlined, size: 18),
            label: const Text('Vedi piani disponibili'),
          ),
        ),
        const SizedBox(height: 24),

        const _AccountSettingsSection(),

        ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          tileColor: theme.colorScheme.errorContainer.withAlpha(80),
          leading: Icon(Icons.logout, color: theme.colorScheme.error),
          title: Text('Esci',
              style: TextStyle(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w600)),
          onTap: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Esci'),
                content: const Text('Vuoi disconnetterti?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Annulla')),
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text('Esci',
                          style: TextStyle(color: Theme.of(ctx).colorScheme.error))),
                ],
              ),
            );
            if (confirm == true) {
              await ref.read(authNotifierProvider.notifier).signOut();
            }
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ── Form di modifica client (nome, telefono, avatar) ──────────────────────────

class _ClientEditForm extends StatelessWidget {
  final UserProfile             profile;
  final TextEditingController   nameCtrl;
  final TextEditingController   phoneCtrl;
  final Uint8List?              pickedBytes;
  final VoidCallback            onPickImage;

  const _ClientEditForm({
    required this.profile,
    required this.nameCtrl,
    required this.phoneCtrl,
    required this.pickedBytes,
    required this.onPickImage,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: Stack(
            children: [
              pickedBytes != null
                  ? CircleAvatar(
                      radius: 52,
                      backgroundImage: MemoryImage(pickedBytes!),
                    )
                  : UserAvatar(
                      avatarUrl: profile.avatarUrl,
                      name:      profile.fullName,
                      radius:    52,
                    ),
              Positioned(
                bottom: 0, right: 0,
                child: GestureDetector(
                  onTap: onPickImage,
                  child: Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      color: AppTheme.lime,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        _FieldLabel('Nome completo'),
        const SizedBox(height: 6),
        TextField(
          controller: nameCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(prefixIcon: Icon(Icons.person_outlined)),
        ),
        const SizedBox(height: 16),

        _FieldLabel('Telefono'),
        const SizedBox(height: 6),
        TextField(
          controller: phoneCtrl,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(prefixIcon: Icon(Icons.phone_outlined)),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SHARED WIDGETS (riusati anche da PublicProfileScreen)
// ══════════════════════════════════════════════════════════════════════════════

/// Avatar circolare con fallback su iniziali.
class UserAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String  name;
  final double  radius;

  const UserAvatar({
    super.key,
    required this.avatarUrl,
    required this.name,
    this.radius = 28,
  });

  @override
  Widget build(BuildContext context) {
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: CachedNetworkImageProvider(avatarUrl!),
        backgroundColor: AppTheme.charcoal,
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppTheme.charcoal,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
          color:      Colors.white,
          fontSize:   radius * 0.7,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class InstagramChip extends StatelessWidget {
  final String url;
  const InstagramChip({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    final handle = url.replaceAll(RegExp(r'https?://(www\.)?instagram\.com/'), '@').replaceAll('/', '');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white30),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.link, color: Colors.white70, size: 14),
          const SizedBox(width: 6),
          Text(handle,
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      ),
    );
  }
}

class SpecChip extends StatelessWidget {
  final String label;
  const SpecChip({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.blue.withAlpha(40),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface)),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _InfoTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.onSurface.withAlpha(150)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withAlpha(150), fontWeight: FontWeight.w600)),
                Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class _SectionTitle extends StatelessWidget {
  final String label;
  const _SectionTitle(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface.withAlpha(180),
            letterSpacing: 0.4));
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(label,
        style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurface.withAlpha(180)));
  }
}

class _EmptyCard extends StatelessWidget {
  final String text;
  const _EmptyCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withAlpha(150), fontSize: 14)),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(12)),
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final ActivePlan plan;
  const _PlanCard({required this.plan});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final expiry  = plan.expiresAt;
    final dateStr = expiry != null
        ? DateFormat('d MMM yyyy', 'it').format(expiry)
        : null;

    final (subtitle, icon, iconColor) = switch (plan.planType) {
      'credits' => (
          '${plan.creditsRemaining ?? 0} crediti rimasti',
          Icons.confirmation_number_outlined,
          theme.colorScheme.primary,
        ),
      'unlimited' => (
          'Accesso illimitato',
          Icons.all_inclusive,
          Colors.green.shade600,
        ),
      _ => (
          plan.creditsRemaining != null
              ? '${plan.creditsRemaining} ingressi rimasti'
              : 'Periodo di prova',
          Icons.card_giftcard_outlined,
          Colors.orange.shade700,
        ),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(plan.planName,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withAlpha(180))),
              ],
            ),
          ),
          if (dateStr != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('scade',
                    style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurface.withAlpha(150))),
                Text(dateStr,
                    style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
        ],
      ),
    );
  }
}

// ── Account settings section (condiviso tra staff e client) ───────────────────

/// Sezione "Impostazioni account" con cambio email, password e cancellazione.
/// Va inserita prima del pulsante Logout in entrambi i profili.
class _AccountSettingsSection extends ConsumerWidget {
  const _AccountSettingsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle('Impostazioni account'),
        const SizedBox(height: 8),
        _SettingsTile(
          icon: Icons.email_outlined,
          label: 'Cambia email',
          onTap: () => _showChangeEmailDialog(context, ref),
        ),
        const SizedBox(height: 6),
        _SettingsTile(
          icon: Icons.lock_outline,
          label: 'Cambia password',
          onTap: () => _showChangePasswordDialog(context, ref),
        ),
        const SizedBox(height: 6),
        _SettingsTile(
          icon: Icons.delete_forever_outlined,
          label: 'Elimina account',
          color: Theme.of(context).colorScheme.error,
          onTap: () => _showDeleteAccountDialog(context, ref),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // ── Cambio email ────────────────────────────────────────────────────────────

  Future<void> _showChangeEmailDialog(
      BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuova email'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'nuova@email.com',
            prefixIcon: Icon(Icons.email_outlined),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annulla')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Continua')),
        ],
      ),
    );
    if (confirmed != true || ctrl.text.trim().isEmpty) return;
    if (!context.mounted) return;

    try {
      final client = ref.read(supabaseClientProvider);
      await client.auth.updateUser(
        UserAttributes(email: ctrl.text.trim()),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Controlla la tua casella email: ti abbiamo inviato un link di conferma'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Errore: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── Cambio password ─────────────────────────────────────────────────────────

  Future<void> _showChangePasswordDialog(
      BuildContext context, WidgetRef ref) async {
    final newCtrl     = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool  obscureNew     = true;
    bool  obscureConfirm = true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Nuova password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: newCtrl,
                obscureText: obscureNew,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Nuova password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(obscureNew
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () => setSt(() => obscureNew = !obscureNew),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmCtrl,
                obscureText: obscureConfirm,
                decoration: InputDecoration(
                  labelText: 'Conferma password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(obscureConfirm
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () =>
                        setSt(() => obscureConfirm = !obscureConfirm),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annulla')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Salva')),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;

    final newPass = newCtrl.text;
    if (newPass.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('La password deve essere di almeno 8 caratteri'),
            backgroundColor: Colors.red),
      );
      return;
    }
    if (newPass != confirmCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Le password non coincidono'),
            backgroundColor: Colors.red),
      );
      return;
    }

    try {
      final client = ref.read(supabaseClientProvider);
      await client.auth.updateUser(UserAttributes(password: newPass));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Password aggiornata ✓'),
              backgroundColor: Color(0xFF66BB6A)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Errore: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── Cancellazione account ────────────────────────────────────────────────────

  Future<void> _showDeleteAccountDialog(
      BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Elimina account'),
        content: const Text(
          'Sei sicuro? Questa azione è irreversibile.\n\n'
          'Tutti i tuoi dati (prenotazioni, piano) saranno eliminati '
          'definitivamente.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annulla')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Elimina',
                  style: TextStyle(
                      color: Theme.of(ctx).colorScheme.error,
                      fontWeight: FontWeight.bold))),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final client = ref.read(supabaseClientProvider);
      await client.functions.invoke('delete-account');
      // L'utente è già stato cancellato dal server: usiamo solo il signOut locale
      // per evitare che il client tenti di invalidare un token già inesistente.
      await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Errore: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color?   color;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.onSurface;
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tileColor: Theme.of(context).colorScheme.surface,
      leading: Icon(icon, color: c),
      title: Text(label,
          style: TextStyle(color: c, fontWeight: FontWeight.w500)),
      trailing: Icon(Icons.chevron_right, color: c.withAlpha(120)),
      onTap: onTap,
    );
  }
}

