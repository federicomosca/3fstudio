import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../features/auth/providers/auth_provider.dart';
import '../../../core/providers/studio_provider.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

final _teamProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final studioId = ref.watch(currentStudioIdProvider);
  if (studioId == null) return [];
  final client = ref.watch(supabaseClientProvider);

  final data = await client
      .from('user_studio_roles')
      .select('role, users(id, full_name, email, phone)')
      .eq('studio_id', studioId)
      .inFilter('role', ['trainer', 'class_owner']);

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
  const TeamScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final team = ref.watch(_teamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Team')),
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

class _MemberTile extends StatelessWidget {
  final Map<String, dynamic> member;
  const _MemberTile({required this.member});

  @override
  Widget build(BuildContext context) {
    final name  = member['full_name'] as String? ?? member['email'] as String? ?? '—';
    final phone = member['phone'] as String?;
    final roles = (member['roles'] as List<String>)
        .map((r) => r == 'class_owner' ? 'Class Owner' : 'Trainer')
        .toSet()
        .join(' · ');

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
      subtitle: Text(phone != null ? '$roles · $phone' : roles),
      trailing: Icon(Icons.chevron_right,
          color: Theme.of(context).colorScheme.onSurface.withAlpha(100)),
      onTap: () => context.push('/u/${member['id']}'),
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
        _chip(context, 'trainer',     'Trainer'),
        _chip(context, 'class_owner', 'Class Owner'),
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
