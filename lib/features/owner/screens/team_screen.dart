import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../features/auth/providers/auth_provider.dart';
import '../../../core/providers/studio_provider.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

/// Trainers who already have an account but are NOT yet assigned to [studioId].
final _assignableTrainersProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final studioId = ref.watch(currentStudioIdProvider);
  if (studioId == null) return [];
  final client = ref.watch(supabaseClientProvider);

  // All users that have the trainer role in any studio.
  final allTrainers = await client
      .from('user_studio_roles')
      .select('user_id, users(id, full_name, email, phone)')
      .eq('role', 'trainer');

  // User IDs already present in this studio (any role).
  final inStudio = await client
      .from('user_studio_roles')
      .select('user_id')
      .eq('studio_id', studioId);

  final inStudioIds =
      (inStudio as List).map((r) => r['user_id'] as String).toSet();

  final Map<String, Map<String, dynamic>> byUser = {};
  for (final row in (allTrainers as List)) {
    final user = row['users'] as Map<String, dynamic>;
    final uid = user['id'] as String;
    if (!inStudioIds.contains(uid)) {
      byUser[uid] = user;
    }
  }
  final result = byUser.values.toList()
    ..sort((a, b) => (a['full_name'] as String? ?? '')
        .compareTo(b['full_name'] as String? ?? ''));
  return result;
});

final _allCoursesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final studioId = ref.watch(currentStudioIdProvider);
  if (studioId == null) return [];
  final client = ref.watch(supabaseClientProvider);
  final data = await client
      .from('courses')
      .select('id, name, class_owner_id, users!class_owner_id(full_name)')
      .eq('studio_id', studioId)
      .order('name');
  return (data as List).cast<Map<String, dynamic>>();
});

final _teamProvider =
    FutureProvider.family<List<Map<String, dynamic>>, bool>((ref, isActive) async {
  final studioId = ref.watch(currentStudioIdProvider);
  if (studioId == null) return [];
  final client = ref.watch(supabaseClientProvider);

  final data = await client
      .from('user_studio_roles')
      .select('role, users(id, full_name, email, phone)')
      .eq('studio_id', studioId)
      .eq('is_active', isActive)
      .inFilter('role', ['trainer']);

  // Raggruppa per utente: un utente può avere più ruoli
  final Map<String, Map<String, dynamic>> byUser = {};
  for (final row in (data as List)) {
    final user = row['users'] as Map<String, dynamic>;
    final uid  = user['id'] as String;
    if (!byUser.containsKey(uid)) {
      byUser[uid] = {...user, 'roles': <String>[]};
    }
    (byUser[uid]!['roles'] as List<String>).add(row['role'] as String);
  }
  return byUser.values.toList();
});

// ── Screen ────────────────────────────────────────────────────────────────────

class TeamScreen extends ConsumerStatefulWidget {
  final bool hideAppBar;
  const TeamScreen({super.key, this.hideAppBar = false});

  @override
  ConsumerState<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends ConsumerState<TeamScreen> {
  bool _showArchived = false;

  void _showAddTrainerDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddTrainerSheet(
        onCreated: () {
          ref.invalidate(_teamProvider(!_showArchived));
          ref.invalidate(_assignableTrainersProvider);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final team = ref.watch(_teamProvider(!_showArchived));

    return Scaffold(
      appBar: widget.hideAppBar
          ? null
          : AppBar(title: Text(_showArchived ? 'Team · Archiviati' : 'Team')),
      floatingActionButton: _showArchived
          ? null
          : FloatingActionButton.extended(
              onPressed: _showAddTrainerDialog,
              icon: const Icon(Icons.person_add_outlined),
              label: const Text('Aggiungi'),
            ),
      body: Column(
        children: [
          // ── Archive toggle ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Attivi'),
                  selected: !_showArchived,
                  onSelected: (_) => setState(() => _showArchived = false),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  avatar: const Icon(Icons.archive_outlined, size: 16),
                  label: const Text('Archiviati'),
                  selected: _showArchived,
                  onSelected: (_) => setState(() => _showArchived = true),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // ── List ───────────────────────────────────────────────────────
          Expanded(
            child: team.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                  child: Text('Errore: $e',
                      style: const TextStyle(color: Colors.red))),
              data: (list) => list.isEmpty
                  ? _showArchived
                      ? _EmptyArchive(label: 'Nessun trainer archiviato')
                      : _EmptyTeam(onAdd: _showAddTrainerDialog)
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: list.length,
                      separatorBuilder: (context, i) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, i) => _MemberTile(
                        member: list[i],
                        isArchived: _showArchived,
                        onReactivated: () => ref.invalidate(_teamProvider(false)),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty states ──────────────────────────────────────────────────────────────

class _EmptyArchive extends StatelessWidget {
  final String label;
  const _EmptyArchive({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.archive_outlined, size: 64,
              color: Theme.of(context).colorScheme.onSurface.withAlpha(60)),
          const SizedBox(height: 16),
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _EmptyTeam extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyTeam({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.group_outlined, size: 64,
                color: Theme.of(context).colorScheme.onSurface.withAlpha(60)),
            const SizedBox(height: 16),
            Text('Nessun membro nel team',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Aggiungi trainer e class owner con il pulsante +',
              textAlign: TextAlign.center,
              style:
                  theme.textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withAlpha(150)),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.person_add_outlined),
              label: const Text('Aggiungi primo membro'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Member tile ───────────────────────────────────────────────────────────────

class _MemberTile extends ConsumerWidget {
  final Map<String, dynamic> member;
  final bool isArchived;
  final VoidCallback? onReactivated;
  const _MemberTile({
    required this.member,
    this.isArchived = false,
    this.onReactivated,
  });

  Future<void> _reactivate(BuildContext context, WidgetRef ref) async {
    final name     = member['full_name'] as String? ?? '—';
    final studioId = ref.read(currentStudioIdProvider);
    if (studioId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Riattiva trainer'),
        content: Text('Riattivare $name nel team?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Riattiva'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final db = ref.read(supabaseClientProvider);
      await db
          .from('user_studio_roles')
          .update({'is_active': true})
          .eq('user_id', member['id'] as String)
          .eq('studio_id', studioId);
      onReactivated?.call();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name  = member['full_name'] as String? ?? member['email'] as String? ?? '—';
    final phone = member['phone'] as String?;

    // Count courses this trainer is responsible for
    final courses = ref.watch(_allCoursesProvider).whenOrNull(data: (c) => c) ?? [];
    final ownedCount = courses
        .where((c) => c['class_owner_id'] == member['id'])
        .length;
    final subtitle = [
      'Trainer',
      ?phone,
      if (ownedCount > 0) '$ownedCount cors${ownedCount > 1 ? 'i' : 'o'} responsabile',
    ].join(' · ');

    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tileColor: Theme.of(context).colorScheme.surface,
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primary.withAlpha(isArchived ? 10 : 20),
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withAlpha(isArchived ? 120 : 255),
              fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(name,
          style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isArchived
                  ? Theme.of(context).colorScheme.onSurface.withAlpha(150)
                  : null)),
      subtitle: Text(subtitle),
      trailing: isArchived
          ? TextButton(
              onPressed: () => _reactivate(context, ref),
              child: const Text('Riattiva'),
            )
          : Icon(Icons.chevron_right,
              color: Theme.of(context).colorScheme.onSurface.withAlpha(100)),
      onTap: isArchived
          ? null
          : () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              useSafeArea: false,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (_) => _TrainerDetailSheet(
                member: member,
                onChanged: () {
                  ref.invalidate(_allCoursesProvider);
                  ref.invalidate(_teamProvider(true));
                  ref.invalidate(_teamProvider(false));
                },
              ),
            ),
    );
  }
}

// ── Trainer detail sheet ──────────────────────────────────────────────────────

class _TrainerDetailSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> member;
  final VoidCallback onChanged;
  const _TrainerDetailSheet({required this.member, required this.onChanged});

  @override
  ConsumerState<_TrainerDetailSheet> createState() =>
      _TrainerDetailSheetState();
}

class _TrainerDetailSheetState extends ConsumerState<_TrainerDetailSheet> {
  bool _archiving = false;

  Future<void> _archive() async {
    final name      = widget.member['full_name'] as String? ?? '—';
    final trainerId = widget.member['id'] as String;
    final studioId  = ref.read(currentStudioIdProvider);
    if (studioId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archivia trainer'),
        content: Text(
          'Archiviare $name? Non comparirà più nell\'elenco del team '
          'ma il suo account rimarrà intatto.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Archivia'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _archiving = true);
    try {
      final db = ref.read(supabaseClientProvider);
      await db
          .from('user_studio_roles')
          .update({'is_active': false})
          .eq('user_id', trainerId)
          .eq('studio_id', studioId);
      if (mounted) {
        Navigator.of(context).pop();
        widget.onChanged();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red),
        );
        setState(() => _archiving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme       = Theme.of(context);
    final name        = widget.member['full_name'] as String? ?? '—';
    final trainerId   = widget.member['id'] as String;
    final coursesAsync = ref.watch(_allCoursesProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(context).viewPadding.bottom + 32),
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              CircleAvatar(
                backgroundColor: theme.colorScheme.primary.withAlpha(20),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(name,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ),
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push('/u/$trainerId');
                },
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Profilo'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Corsi responsabile',
              style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface.withAlpha(180),
                  letterSpacing: 0.5)),
          const SizedBox(height: 4),
          Text('Attiva il toggle per designare questo trainer come responsabile del corso.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurface.withAlpha(140))),
          const SizedBox(height: 8),
          coursesAsync.when(
            loading: () => const Center(child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            )),
            error: (e, _) => Text('Errore: $e',
                style: const TextStyle(color: Colors.red)),
            data: (courses) => courses.isEmpty
                ? Text('Nessun corso nello studio.',
                    style: TextStyle(
                        color: theme.colorScheme.onSurface.withAlpha(150)))
                : Column(
                    children: courses
                        .map((c) => _CourseOwnerToggle(
                              course: c,
                              trainerId: trainerId,
                              trainerName: name,
                              onChanged: widget.onChanged,
                            ))
                        .toList(),
                  ),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _archiving ? null : _archive,
              icon: _archiving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(Icons.archive_outlined,
                      color: theme.colorScheme.error),
              label: Text(
                'Archivia trainer',
                style: TextStyle(color: theme.colorScheme.error),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: theme.colorScheme.error.withAlpha(120)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseOwnerToggle extends ConsumerStatefulWidget {
  final Map<String, dynamic> course;
  final String trainerId;
  final String trainerName;
  final VoidCallback onChanged;
  const _CourseOwnerToggle({
    required this.course,
    required this.trainerId,
    required this.trainerName,
    required this.onChanged,
  });

  @override
  ConsumerState<_CourseOwnerToggle> createState() => _CourseOwnerToggleState();
}

class _CourseOwnerToggleState extends ConsumerState<_CourseOwnerToggle> {
  bool _loading = false;

  Future<void> _toggle(bool newValue) async {
    if (newValue) {
      final currentOwnerId = widget.course['class_owner_id'] as String?;
      final hasDifferentOwner =
          currentOwnerId != null && currentOwnerId != widget.trainerId;

      if (hasDifferentOwner) {
        final currentOwnerName =
            (widget.course['users'] as Map<String, dynamic>?)?['full_name']
                as String? ?? '—';
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Sostituire il responsabile?'),
            content: Text(
              'Questo corso ha già un responsabile: $currentOwnerName.\n\n'
              'Procedendo, ${widget.trainerName} diventerà il nuovo responsabile al suo posto.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Annulla'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Sostituisci'),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
      }
    }

    setState(() => _loading = true);
    try {
      final client = ref.read(supabaseClientProvider);
      await client.from('courses').update({
        'class_owner_id': newValue ? widget.trainerId : null,
      }).eq('id', widget.course['id'] as String);
      widget.onChanged();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = widget.course['class_owner_id'] == widget.trainerId;
    final currentOwnerId = widget.course['class_owner_id'] as String?;
    final hasDifferentOwner =
        currentOwnerId != null && currentOwnerId != widget.trainerId;
    final currentOwnerName =
        (widget.course['users'] as Map<String, dynamic>?)?['full_name']
            as String?;

    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(widget.course['name'] as String,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      subtitle: hasDifferentOwner && currentOwnerName != null
          ? Text('Responsabile: $currentOwnerName',
              style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.error.withAlpha(200)))
          : null,
      value: isOwner,
      onChanged: _loading ? null : _toggle,
      secondary: _loading
          ? const SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2))
          : null,
    );
  }
}

// ── Add trainer sheet ─────────────────────────────────────────────────────────

enum _AddMode { create, existing }

class _AddTrainerSheet extends ConsumerStatefulWidget {
  final VoidCallback onCreated;
  const _AddTrainerSheet({required this.onCreated});

  @override
  ConsumerState<_AddTrainerSheet> createState() => _AddTrainerSheetState();
}

class _AddTrainerSheetState extends ConsumerState<_AddTrainerSheet> {
  _AddMode _mode = _AddMode.create;

  // ── "Nuovo" state ────────────────────────────────────────────────────────
  final _formKey   = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  String _selectedRole = 'trainer';

  // ── "Esistente" state ────────────────────────────────────────────────────
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  Map<String, dynamic>? _selectedExisting;

  bool    _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(
        () => setState(() => _searchQuery = _searchCtrl.text.trim().toLowerCase()));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitNew() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    try {
      final studioId = ref.read(currentStudioIdProvider);
      if (studioId == null) throw Exception('Studio non trovato');

      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) throw Exception('Sessione scaduta, effettua nuovamente il login');

      final response = await Supabase.instance.client.functions.invoke(
        'admin-create-user',
        body: {
          'full_name': _nameCtrl.text.trim(),
          'email':     _emailCtrl.text.trim(),
          'password':  _passCtrl.text,
          'role':      _selectedRole,
          'studio_id': studioId,
          'phone':     _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        },
        headers: {'Authorization': 'Bearer ${session.accessToken}'},
      );

      if (response.status != 200) {
        final msg = (response.data as Map?)?['error'] as String? ?? 'Errore sconosciuto';
        throw Exception(msg);
      }

      if (mounted) {
        Navigator.of(context).pop();
        widget.onCreated();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_nameCtrl.text.trim()} aggiunto al team!'),
            backgroundColor: Colors.green.shade600,
          ),
        );
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitExisting() async {
    final user = _selectedExisting;
    if (user == null) return;
    setState(() { _loading = true; _error = null; });

    try {
      final studioId = ref.read(currentStudioIdProvider);
      if (studioId == null) throw Exception('Studio non trovato');

      final db = ref.read(supabaseClientProvider);
      // Upsert: handles the case where the row exists but is archived.
      await db.from('user_studio_roles').upsert(
        {
          'user_id':   user['id'] as String,
          'studio_id': studioId,
          'role':      'trainer',
          'is_active': true,
        },
        onConflict: 'user_id,studio_id,role',
      );

      if (mounted) {
        Navigator.of(context).pop();
        widget.onCreated();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${user['full_name'] ?? user['email']} aggiunto a questa sede!'),
            backgroundColor: Colors.green.shade600,
          ),
        );
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Aggiungi membro',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),

          // ── Mode selector ──────────────────────────────────────────────
          SegmentedButton<_AddMode>(
            segments: const [
              ButtonSegment(
                value: _AddMode.create,
                icon: Icon(Icons.person_add_outlined),
                label: Text('Nuovo account'),
              ),
              ButtonSegment(
                value: _AddMode.existing,
                icon: Icon(Icons.person_search_outlined),
                label: Text('Già registrato'),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (s) =>
                setState(() { _mode = s.first; _error = null; }),
          ),
          const SizedBox(height: 20),

          if (_mode == _AddMode.create)
            _NewMemberForm(
              formKey: _formKey,
              nameCtrl: _nameCtrl,
              emailCtrl: _emailCtrl,
              phoneCtrl: _phoneCtrl,
              passCtrl: _passCtrl,
              selectedRole: _selectedRole,
              onRoleChanged: (v) => setState(() => _selectedRole = v),
              loading: _loading,
              error: _error,
              onSubmit: _submitNew,
            )
          else
            _ExistingMemberPicker(
              searchCtrl: _searchCtrl,
              searchQuery: _searchQuery,
              selected: _selectedExisting,
              onSelected: (u) => setState(() => _selectedExisting = u),
              loading: _loading,
              error: _error,
              onSubmit: _submitExisting,
            ),
        ],
      ),
    );
  }
}

// ── New member form (extracted for clarity) ───────────────────────────────────

class _NewMemberForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameCtrl, emailCtrl, phoneCtrl, passCtrl;
  final String selectedRole;
  final ValueChanged<String> onRoleChanged;
  final bool loading;
  final String? error;
  final VoidCallback onSubmit;

  const _NewMemberForm({
    required this.formKey,
    required this.nameCtrl,
    required this.emailCtrl,
    required this.phoneCtrl,
    required this.passCtrl,
    required this.selectedRole,
    required this.onRoleChanged,
    required this.loading,
    required this.error,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RoleChips(selected: selectedRole, onChanged: onRoleChanged),
          const SizedBox(height: 16),
          TextFormField(
            controller: nameCtrl,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nome completo',
              prefixIcon: Icon(Icons.person_outlined),
            ),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Campo obbligatorio' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: emailCtrl,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (v) =>
                v == null || !v.contains('@') ? 'Email non valida' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: phoneCtrl,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Telefono (opzionale)',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: passCtrl,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => onSubmit(),
            decoration: const InputDecoration(
              labelText: 'Password temporanea',
              prefixIcon: Icon(Icons.lock_outlined),
              helperText: 'Comunicala al trainer per il primo accesso',
            ),
            validator: (v) =>
                v == null || v.length < 8 ? 'Minimo 8 caratteri' : null,
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            _ErrorBox(error!),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: loading ? null : onSubmit,
              child: loading
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Crea account'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Existing member picker ─────────────────────────────────────────────────────

class _ExistingMemberPicker extends ConsumerWidget {
  final TextEditingController searchCtrl;
  final String searchQuery;
  final Map<String, dynamic>? selected;
  final ValueChanged<Map<String, dynamic>?> onSelected;
  final bool loading;
  final String? error;
  final VoidCallback onSubmit;

  const _ExistingMemberPicker({
    required this.searchCtrl,
    required this.searchQuery,
    required this.selected,
    required this.onSelected,
    required this.loading,
    required this.error,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final assignableAsync = ref.watch(_assignableTrainersProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Seleziona un trainer già registrato nell\'app e aggiungilo a questa sede.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurface.withAlpha(150)),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: searchCtrl,
          decoration: const InputDecoration(
            hintText: 'Cerca per nome…',
            prefixIcon: Icon(Icons.search),
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        assignableAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: _ErrorBox(e.toString()),
          ),
          data: (all) {
            final filtered = searchQuery.isEmpty
                ? all
                : all.where((u) {
                    final name =
                        (u['full_name'] as String? ?? '').toLowerCase();
                    final email =
                        (u['email'] as String? ?? '').toLowerCase();
                    return name.contains(searchQuery) ||
                        email.contains(searchQuery);
                  }).toList();

            if (all.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Nessun trainer disponibile da altre sedi.',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(150)),
                ),
              );
            }

            if (filtered.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Nessun risultato per "$searchQuery".',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(150)),
                ),
              );
            }

            return ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: filtered.length,
                separatorBuilder: (context, i) =>
                    const SizedBox(height: 4),
                itemBuilder: (context, i) {
                  final u = filtered[i];
                  final name = u['full_name'] as String? ??
                      u['email'] as String? ?? '—';
                  final isSelected = selected?['id'] == u['id'];
                  return ListTile(
                    dense: true,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    tileColor: isSelected
                        ? theme.colorScheme.primary.withAlpha(25)
                        : theme.colorScheme.surface,
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor:
                          theme.colorScheme.primary.withAlpha(20),
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                      ),
                    ),
                    title: Text(name,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500)),
                    subtitle: Text(u['email'] as String? ?? '',
                        style: const TextStyle(fontSize: 12)),
                    trailing: isSelected
                        ? Icon(Icons.check_circle,
                            color: theme.colorScheme.primary)
                        : null,
                    onTap: () => onSelected(isSelected ? null : u),
                  );
                },
              ),
            );
          },
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          _ErrorBox(error!),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: (loading || selected == null) ? null : onSubmit,
            child: loading
                ? const SizedBox(
                    height: 20, width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Aggiungi a questa sede'),
          ),
        ),
      ],
    );
  }
}

// ── Shared error box ───────────────────────────────────────────────────────────

class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox(this.message);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.error.withAlpha(100)),
      ),
      child: Row(children: [
        Icon(Icons.error_outline,
            color: theme.colorScheme.onErrorContainer, size: 16),
        const SizedBox(width: 8),
        Expanded(
            child: Text(message,
                style: TextStyle(
                    color: theme.colorScheme.onErrorContainer,
                    fontSize: 13))),
      ]),
    );
  }
}

// ── Role chips ────────────────────────────────────────────────────────────────

class _RoleChips extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _RoleChips({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        _chip(context, 'trainer', 'Trainer'),
      ],
    );
  }

  Widget _chip(BuildContext context, String value, String label) {
    final isSelected = selected == value;
    final color = Theme.of(context).colorScheme.primary;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onChanged(value),
      selectedColor: color.withAlpha(30),
      side: BorderSide(
          color: isSelected
              ? color
              : Theme.of(context).colorScheme.outline),
      labelStyle: TextStyle(
        color: isSelected ? color : Theme.of(context).colorScheme.onSurface.withAlpha(180),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}
