import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/studio.dart';
import '../../../core/providers/selected_studio_provider.dart';
import '../../../features/auth/providers/auth_provider.dart';

// ── Screen ────────────────────────────────────────────────────────────────────

class StudiosScreen extends ConsumerWidget {
  final bool hideAppBar;
  const StudiosScreen({super.key, this.hideAppBar = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studiosAsync = ref.watch(userSediProvider);

    return Scaffold(
      appBar: hideAppBar ? null : AppBar(title: const Text('Sedi')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showStudioSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nuova sede'),
      ),
      body: studiosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text('Errore: $e', style: const TextStyle(color: Colors.red))),
        data: (sedi) => sedi.isEmpty
            ? _EmptyStudios(onAdd: () => _showStudioSheet(context, ref))
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: sedi.length,
                separatorBuilder: (context, i) => const SizedBox(height: 8),
                itemBuilder: (context, i) => _StudioTile(
                  studio: sedi[i],
                  onEdit: () => _showStudioSheet(context, ref, existing: sedi[i]),
                  onDelete: () => _deleteStudio(context, ref, sedi[i]),
                ),
              ),
      ),
    );
  }

  void _showStudioSheet(BuildContext context, WidgetRef ref,
      {Studio? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _StudioSheet(
        existing: existing,
        onSaved: () => ref.invalidate(userSediProvider),
      ),
    );
  }

  Future<void> _deleteStudio(
      BuildContext context, WidgetRef ref, Studio studio) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Elimina sede'),
        content: Text(
          'Sei sicuro di voler eliminare "${studio.name}"?\n\n'
          'Verranno eliminate anche tutte le sale, i corsi, le lezioni '
          'e le prenotazioni associate.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annulla')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Elimina',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;

    final client = ref.read(supabaseClientProvider);
    try {
      await client.from('studios').delete().eq('id', studio.id);
      ref.invalidate(userSediProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Sede "${studio.name}" eliminata'),
              backgroundColor: Colors.green.shade600),
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
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyStudios extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyStudios({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_city_outlined,
                size: 64,
                color:
                    Theme.of(context).colorScheme.onSurface.withAlpha(60)),
            const SizedBox(height: 16),
            Text('Nessuna sede',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Non hai ancora nessuna sede associata.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withAlpha(150))),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Aggiungi sede'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tile ──────────────────────────────────────────────────────────────────────

class _StudioTile extends StatelessWidget {
  final Studio studio;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _StudioTile(
      {required this.studio, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tileColor: Theme.of(context).colorScheme.surface,
      leading: const CircleAvatar(
        child: Icon(Icons.location_city_outlined),
      ),
      title: Text(studio.name,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(studio.address ?? '—'),
      trailing: PopupMenuButton<String>(
        onSelected: (v) {
          if (v == 'edit') {
            onEdit();
          } else {
            onDelete();
          }
        },
        itemBuilder: (_) => [
          const PopupMenuItem(
            value: 'edit',
            child: ListTile(
              leading: Icon(Icons.edit_outlined),
              title: Text('Modifica'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const PopupMenuItem(
            value: 'delete',
            child: ListTile(
              leading: Icon(Icons.delete_outline, color: Colors.red),
              title: Text('Elimina', style: TextStyle(color: Colors.red)),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bottom sheet ──────────────────────────────────────────────────────────────

class _StudioSheet extends ConsumerStatefulWidget {
  final Studio? existing;
  final VoidCallback onSaved;
  const _StudioSheet({this.existing, required this.onSaved});

  @override
  ConsumerState<_StudioSheet> createState() => _StudioSheetState();
}

class _StudioSheetState extends ConsumerState<_StudioSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _orgCtrl;
  bool _loading = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _addressCtrl =
        TextEditingController(text: widget.existing?.address ?? '');
    _orgCtrl = TextEditingController(
        text: widget.existing?.organizationName ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _orgCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final client = ref.read(supabaseClientProvider);
      final payload = <String, dynamic>{
        'name': _nameCtrl.text.trim(),
        'address': _addressCtrl.text.trim().isEmpty
            ? null
            : _addressCtrl.text.trim(),
        'organization_name': _orgCtrl.text.trim().isEmpty
            ? null
            : _orgCtrl.text.trim(),
      };

      if (_isEdit) {
        await client
            .from('studios')
            .update(payload)
            .eq('id', widget.existing!.id);
      } else {
        await client.from('studios').insert(payload);
      }

      if (mounted) {
        Navigator.of(context).pop();
        widget.onSaved();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(_isEdit ? 'Sede aggiornata' : 'Sede creata'),
              backgroundColor: Colors.green.shade600),
        );
      }
    } catch (e) {
      setState(
          () => _error = e.toString().replaceFirst('Exception: ', ''));
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
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(_isEdit ? 'Modifica sede' : 'Nuova sede',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),

            TextFormField(
              controller: _nameCtrl,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nome sede',
                prefixIcon: Icon(Icons.location_city_outlined),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Campo obbligatorio' : null,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _addressCtrl,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Indirizzo',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _orgCtrl,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nome organizzazione',
                prefixIcon: Icon(Icons.business_outlined),
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: theme.colorScheme.error.withAlpha(100)),
                ),
                child: Row(children: [
                  Icon(Icons.error_outline,
                      color: theme.colorScheme.onErrorContainer, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_error!,
                        style: TextStyle(
                            color: theme.colorScheme.onErrorContainer,
                            fontSize: 13)),
                  ),
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
                        height: 20,
                        width: 20,
                        child:
                            CircularProgressIndicator(strokeWidth: 2))
                    : Text(_isEdit ? 'Salva modifiche' : 'Crea sede'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
