import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../features/auth/providers/auth_provider.dart';
import '../../../core/providers/studio_provider.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

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

final _teamProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final studioId = ref.watch(currentStudioIdProvider);
  if (studioId == null) return [];
  final client = ref.watch(supabaseClientProvider);

  final data = await client
      .from('user_studio_roles')
      .select('role, users(id, full_name, email, phone)')
      .eq('studio_id', studioId)
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

class TeamScreen extends ConsumerWidget {
  final bool hideAppBar;
  const TeamScreen({super.key, this.hideAppBar = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final team = ref.watch(_teamProvider);

    return Scaffold(
      appBar: hideAppBar ? null : AppBar(title: const Text('Team')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddTrainerDialog(context, ref),
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Aggiungi'),
      ),
      body: team.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text('Errore: $e', style: const TextStyle(color: Colors.red))),
        data: (list) => list.isEmpty
            ? _EmptyTeam(onAdd: () => _showAddTrainerDialog(context, ref))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                separatorBuilder: (context, i) => const SizedBox(height: 8),
                itemBuilder: (context, i) => _MemberTile(member: list[i]),
              ),
      ),
    );
  }

  void _showAddTrainerDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddTrainerSheet(
        onCreated: () => ref.invalidate(_teamProvider),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

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
  const _MemberTile({required this.member});

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
      if (phone != null) phone,
      if (ownedCount > 0) '$ownedCount cors${ownedCount > 1 ? 'i' : 'o'} responsabile',
    ].join(' · ');

    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tileColor: Theme.of(context).colorScheme.surface,
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primary.withAlpha(20),
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      trailing: Icon(Icons.chevron_right,
          color: Theme.of(context).colorScheme.onSurface.withAlpha(100)),
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: false,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => _TrainerDetailSheet(
          member: member,
          onChanged: () => ref.invalidate(_allCoursesProvider),
        ),
      ),
    );
  }
}

// ── Trainer detail sheet ──────────────────────────────────────────────────────

class _TrainerDetailSheet extends ConsumerWidget {
  final Map<String, dynamic> member;
  final VoidCallback onChanged;
  const _TrainerDetailSheet({required this.member, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme       = Theme.of(context);
    final name        = member['full_name'] as String? ?? '—';
    final trainerId   = member['id'] as String;
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
                              onChanged: onChanged,
                            ))
                        .toList(),
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

class _AddTrainerSheet extends ConsumerStatefulWidget {
  final VoidCallback onCreated;
  const _AddTrainerSheet({required this.onCreated});

  @override
  ConsumerState<_AddTrainerSheet> createState() => _AddTrainerSheetState();
}

class _AddTrainerSheetState extends ConsumerState<_AddTrainerSheet> {
  final _formKey   = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();

  String _selectedRole = 'trainer';
  bool   _loading      = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Form(
        key: _formKey,
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
            const SizedBox(height: 4),
            Text('Crea un account per il nuovo membro del team.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withAlpha(150))),
            const SizedBox(height: 24),

            // Ruolo selector
            _RoleChips(
              selected: _selectedRole,
              onChanged: (v) => setState(() => _selectedRole = v),
            ),
            const SizedBox(height: 16),

            // Nome
            TextFormField(
              controller: _nameCtrl,
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

            // Email
            TextFormField(
              controller: _emailCtrl,
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

            // Telefono (opzionale)
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Telefono (opzionale)',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 12),

            // Password temporanea
            TextFormField(
              controller: _passCtrl,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                labelText: 'Password temporanea',
                prefixIcon: Icon(Icons.lock_outlined),
                helperText: 'Comunicala al trainer per il primo accesso',
              ),
              validator: (v) =>
                  v == null || v.length < 8 ? 'Minimo 8 caratteri' : null,
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
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
                  Expanded(child: Text(_error!,
                      style: TextStyle(
                          color: theme.colorScheme.onErrorContainer,
                          fontSize: 13))),
                ]),
              ),
            ],

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Crea account'),
              ),
            ),
          ],
        ),
      ),
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
