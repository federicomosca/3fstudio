import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../features/auth/providers/auth_provider.dart';
import '../../../core/providers/studio_provider.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

final _clientsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, bool>((ref, isActive) async {
  final studioId = ref.watch(currentStudioIdProvider);
  if (studioId == null) return [];
  final client = ref.watch(supabaseClientProvider);

  // Step 1: user_id dei clienti dello studio (filtro is_active)
  final roles = await client
      .from('user_studio_roles')
      .select('user_id')
      .eq('studio_id', studioId)
      .eq('role', 'client')
      .eq('is_active', isActive);

  final ids = (roles as List).map((r) => r['user_id'] as String).toList();
  if (ids.isEmpty) return [];

  // Step 2: dati utente + piano attivo
  final data = await client
      .from('users')
      .select('id, full_name, email, phone, user_plans(credits_remaining, expires_at, status, plans(name, type))')
      .inFilter('id', ids)
      .order('full_name');

  return (data as List).cast<Map<String, dynamic>>();
});

// ── Screen ────────────────────────────────────────────────────────────────────

class ClientsScreen extends ConsumerStatefulWidget {
  const ClientsScreen({super.key});

  @override
  ConsumerState<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends ConsumerState<ClientsScreen> {
  bool _showArchived = false;

  void _showAddClientDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddClientSheet(
        onCreated: () => ref.invalidate(_clientsProvider(true)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final clients = ref.watch(_clientsProvider(!_showArchived));

    return Scaffold(
      appBar: AppBar(title: const Text('Clienti')),
      floatingActionButton: _showArchived
          ? null
          : FloatingActionButton.extended(
              onPressed: _showAddClientDialog,
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
            child: clients.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                  child: Text('Errore: $e',
                      style: const TextStyle(color: Colors.red))),
              data: (list) => list.isEmpty
                  ? _showArchived
                      ? _EmptyArchive(label: 'Nessun cliente archiviato')
                      : _EmptyClients(onAdd: _showAddClientDialog)
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: list.length,
                      separatorBuilder: (context, i) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, i) => _ClientTile(
                        client: list[i],
                        isArchived: _showArchived,
                        onReactivated: () {
                          ref.invalidate(_clientsProvider(true));
                          ref.invalidate(_clientsProvider(false));
                        },
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

class _EmptyClients extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyClients({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline, size: 64,
                color: Theme.of(context).colorScheme.onSurface.withAlpha(60)),
            const SizedBox(height: 16),
            Text('Nessun cliente',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Aggiungi i tuoi clienti con il pulsante +',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withAlpha(150)),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.person_add_outlined),
              label: const Text('Aggiungi primo cliente'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Client tile ───────────────────────────────────────────────────────────────

class _ClientTile extends ConsumerWidget {
  final Map<String, dynamic> client;
  final bool isArchived;
  final VoidCallback? onReactivated;
  const _ClientTile({
    required this.client,
    this.isArchived = false,
    this.onReactivated,
  });

  Future<void> _reactivate(BuildContext context, WidgetRef ref) async {
    final name     = client['full_name'] as String? ?? '—';
    final studioId = ref.read(currentStudioIdProvider);
    if (studioId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Riattiva cliente'),
        content: Text('Riattivare $name?'),
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
          .eq('user_id', client['id'] as String)
          .eq('studio_id', studioId)
          .eq('role', 'client');
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
    final name  = client['full_name'] as String? ?? client['email'] as String? ?? '—';
    final phone = client['phone'] as String?;

    final allPlans = (client['user_plans'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .where((p) => p['status'] != 'cancelled')
        .toList();

    final activePlan = allPlans
        .where((p) => p['status'] == 'active')
        .toList()
        .firstOrNull;
    final hasSuspendedOnly =
        activePlan == null && allPlans.any((p) => p['status'] == 'suspended');

    final plan      = activePlan;
    final planData  = plan?['plans'] as Map<String, dynamic>?;
    final planName  = planData?['name'] as String?;
    final planType  = planData?['type'] as String?;
    final credits   = plan?['credits_remaining'] as int?;
    final expiresAt = plan?['expires_at'] as String?;

    String subtitle;
    Color subtitleColor = Theme.of(context).colorScheme.onSurface.withAlpha(180);

    if (hasSuspendedOnly) {
      subtitle = 'Piano sospeso';
      subtitleColor = Colors.orange.shade700;
    } else if (planName == null) {
      subtitle = 'Nessun piano';
      subtitleColor = Colors.orange.shade700;
    } else if (planType == 'credits') {
      subtitle = '$planName · $credits crediti';
      if (credits != null && credits <= 2) subtitleColor = Colors.orange.shade700;
    } else if (planType == 'unlimited') {
      subtitle = planName;
      if (expiresAt != null) {
        final exp = DateTime.tryParse(expiresAt);
        if (exp != null && exp.isBefore(DateTime.now().add(const Duration(days: 7)))) {
          subtitleColor = Colors.orange.shade700;
        }
      }
    } else {
      subtitle = planName;
    }

    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tileColor: Theme.of(context).colorScheme.surface,
      leading: CircleAvatar(
        backgroundColor: Theme.of(context)
            .colorScheme
            .primary
            .withAlpha(isArchived ? 10 : 20),
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
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subtitle, style: TextStyle(color: subtitleColor, fontSize: 12)),
          if (phone != null)
            Text(phone,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withAlpha(150),
                    fontSize: 12)),
        ],
      ),
      isThreeLine: phone != null,
      trailing: isArchived
          ? TextButton(
              onPressed: () => _reactivate(context, ref),
              child: const Text('Riattiva'),
            )
          : Icon(Icons.chevron_right,
              color: Theme.of(context).colorScheme.onSurface.withAlpha(100)),
      onTap: isArchived ? null : () => context.push('/owner/clients/${client['id']}'),
    );
  }
}

// ── Add client sheet ──────────────────────────────────────────────────────────

class _AddClientSheet extends ConsumerStatefulWidget {
  final VoidCallback onCreated;
  const _AddClientSheet({required this.onCreated});

  @override
  ConsumerState<_AddClientSheet> createState() => _AddClientSheetState();
}

class _AddClientSheetState extends ConsumerState<_AddClientSheet> {
  final _formKey   = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();

  bool    _loading = false;
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
          'role':      'client',
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
            content: Text('${_nameCtrl.text.trim()} aggiunto!'),
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
            Text('Aggiungi cliente',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Crea un profilo per il nuovo cliente.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withAlpha(150))),
            const SizedBox(height: 24),

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

            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Telefono',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _passCtrl,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                labelText: 'Password temporanea',
                prefixIcon: Icon(Icons.lock_outlined),
                helperText: 'Conservala tu — il cliente può cambiarla in seguito',
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
                  Icon(Icons.error_outline, color: theme.colorScheme.onErrorContainer, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!,
                      style: TextStyle(color: theme.colorScheme.onErrorContainer, fontSize: 13))),
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
                    : const Text('Crea cliente'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
