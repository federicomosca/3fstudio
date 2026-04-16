import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/auth/providers/auth_provider.dart';
import '../../../core/providers/studio_provider.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

final _roomsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final studioId = ref.watch(currentStudioIdProvider);
  if (studioId == null) return [];
  final client = ref.watch(supabaseClientProvider);
  final data = await client
      .from('rooms')
      .select('id, name, capacity')
      .eq('studio_id', studioId)
      .order('name');
  return (data as List).cast<Map<String, dynamic>>();
});

// ── Screen ────────────────────────────────────────────────────────────────────

class RoomsScreen extends ConsumerWidget {
  const RoomsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rooms = ref.watch(_roomsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Spazi')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showRoomSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nuovo spazio'),
      ),
      body: rooms.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(
            child: Text('Errore: $e', style: const TextStyle(color: Colors.red))),
        data: (list) => list.isEmpty
            ? _EmptyRooms(onAdd: () => _showRoomSheet(context, ref))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                separatorBuilder: (context, i) => const SizedBox(height: 8),
                itemBuilder: (context, i) => _RoomTile(
                  room: list[i],
                  onEdit:   () => _showRoomSheet(context, ref, existing: list[i]),
                  onDelete: () => _deleteRoom(context, ref, list[i]),
                ),
              ),
      ),
    );
  }

  void _showRoomSheet(BuildContext context, WidgetRef ref,
      {Map<String, dynamic>? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _RoomSheet(
        existing: existing,
        onSaved: () => ref.invalidate(_roomsProvider),
      ),
    );
  }

  Future<void> _deleteRoom(
      BuildContext context, WidgetRef ref, Map<String, dynamic> room) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Elimina spazio'),
        content: Text('Sei sicuro di voler eliminare "${room['name']}"?'),
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

    try {
      final client = ref.read(supabaseClientProvider);
      await client.from('rooms').delete().eq('id', room['id'] as String);
      ref.invalidate(_roomsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Spazio eliminato')));
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

class _EmptyRooms extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyRooms({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.place_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.onSurface.withAlpha(60)),
            const SizedBox(height: 16),
            Text('Nessuno spazio',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Aggiungi il primo spazio con il pulsante +',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withAlpha(150))),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Aggiungi spazio'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tile ──────────────────────────────────────────────────────────────────────

class _RoomTile extends StatelessWidget {
  final Map<String, dynamic> room;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _RoomTile(
      {required this.room, required this.onEdit, required this.onDelete});

  static IconData _iconForRoom(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('outdoor') || lower.contains('esterno') ||
        lower.contains('giardino') || lower.contains('campo') ||
        lower.contains('parco')) {
      return Icons.park_outlined;
    }
    return Icons.meeting_room_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final cap  = room['capacity'] as int? ?? 0;
    final name = room['name'] as String;
    return ListTile(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tileColor: Theme.of(context).colorScheme.surface,
      leading: CircleAvatar(
        child: Icon(_iconForRoom(name)),
      ),
      title: Text(name,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text('$cap posti'),
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
              title: Text('Elimina',
                  style: TextStyle(color: Colors.red)),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bottom sheet ──────────────────────────────────────────────────────────────

class _RoomSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic>? existing;
  final VoidCallback onSaved;
  const _RoomSheet({this.existing, required this.onSaved});

  @override
  ConsumerState<_RoomSheet> createState() => _RoomSheetState();
}

class _RoomSheetState extends ConsumerState<_RoomSheet> {
  final _formKey  = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _capCtrl;
  bool    _loading = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(
        text: widget.existing?['name'] as String? ?? '');
    _capCtrl  = TextEditingController(
        text: widget.existing?['capacity']?.toString() ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _capCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error   = null;
    });

    try {
      final studioId = ref.read(currentStudioIdProvider);
      if (studioId == null) throw Exception('Studio non trovato');
      final client = ref.read(supabaseClientProvider);
      final payload = {
        'name':      _nameCtrl.text.trim(),
        'capacity':  int.parse(_capCtrl.text.trim()),
        'studio_id': studioId,
      };

      if (_isEdit) {
        await client
            .from('rooms')
            .update(payload)
            .eq('id', widget.existing!['id'] as String);
      } else {
        await client.from('rooms').insert(payload);
      }

      if (mounted) {
        Navigator.of(context).pop();
        widget.onSaved();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(_isEdit ? 'Spazio aggiornato' : 'Spazio creato'),
              backgroundColor: Colors.green.shade600),
        );
      }
    } catch (e) {
      setState(() =>
          _error = e.toString().replaceFirst('Exception: ', ''));
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
            Text(_isEdit ? 'Modifica spazio' : 'Nuovo spazio',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),

            TextFormField(
              controller: _nameCtrl,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nome spazio',
                prefixIcon: Icon(Icons.place_outlined),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Campo obbligatorio' : null,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _capCtrl,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                labelText: 'Capacità (posti)',
                prefixIcon: Icon(Icons.people_outline),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Campo obbligatorio';
                if (int.tryParse(v.trim()) == null) return 'Inserisci un numero';
                return null;
              },
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
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_isEdit ? 'Salva modifiche' : 'Crea spazio'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
