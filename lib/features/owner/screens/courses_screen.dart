import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../core/providers/studio_provider.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _coursesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final studioId = ref.watch(currentStudioIdProvider);
  if (studioId == null) return [];
  final client = ref.watch(supabaseClientProvider);
  final data = await client
      .from('courses')
      .select('id, name, type, cancel_window_hours, description, users!class_owner_id(id, full_name)')
      .eq('studio_id', studioId)
      .order('name');
  return (data as List).cast<Map<String, dynamic>>();
});

final _staffForStudioProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final studioId = ref.watch(currentStudioIdProvider);
  if (studioId == null) return [];
  final client = ref.watch(supabaseClientProvider);

  final data = await client
      .from('user_studio_roles')
      .select('user_id, role, users(id, full_name)')
      .eq('studio_id', studioId)
      .inFilter('role', ['trainer', 'class_owner']);

  // deduplicate by user_id
  final Map<String, Map<String, dynamic>> byUser = {};
  for (final row in (data as List)) {
    final user = row['users'] as Map<String, dynamic>;
    final uid  = user['id'] as String;
    byUser[uid] ??= user;
  }
  return byUser.values.toList()
    ..sort((a, b) => (a['full_name'] as String)
        .compareTo(b['full_name'] as String));
});

// ── Screen ────────────────────────────────────────────────────────────────────

class CoursesScreen extends ConsumerWidget {
  const CoursesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courses = ref.watch(_coursesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Corsi')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nuovo corso'),
      ),
      body: courses.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(
            child: Text('Errore: $e',
                style: const TextStyle(color: Colors.red))),
        data: (list) => list.isEmpty
            ? _EmptyCourses(onAdd: () => _showAddSheet(context, ref))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                separatorBuilder: (context, i) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final c       = list[i];
                  final isGroup = c['type'] == 'group';
                  final owner   = c['users'] as Map<String, dynamic>?;
                  return ListTile(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    tileColor: Theme.of(context).colorScheme.surface,
                    leading: CircleAvatar(
                      backgroundColor: isGroup
                          ? AppTheme.blue.withAlpha(30)
                          : const Color(0xFF9C27B0).withAlpha(30),
                      child: Icon(
                        isGroup
                            ? Icons.group_outlined
                            : Icons.person_outline,
                        color: isGroup ? AppTheme.blue : const Color(0xFFCE93D8),
                      ),
                    ),
                    title: Text(c['name'] as String,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(owner != null
                        ? 'Responsabile: ${owner['full_name']}'
                        : isGroup ? 'Collettivo' : 'Personal'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () =>
                        context.push('/owner/courses/${c['id']}'),
                  );
                },
              ),
      ),
    );
  }

  void _showAddSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddCourseSheet(
        onCreated: () => ref.invalidate(_coursesProvider),
      ),
    );
  }
}

// ── Empty ─────────────────────────────────────────────────────────────────────

class _EmptyCourses extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyCourses({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.fitness_center_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.onSurface.withAlpha(60)),
            const SizedBox(height: 16),
            Text('Nessun corso',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Crea il primo corso con il pulsante +',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withAlpha(150))),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Aggiungi corso'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Add-course sheet ──────────────────────────────────────────────────────────

class _AddCourseSheet extends ConsumerStatefulWidget {
  final VoidCallback onCreated;
  const _AddCourseSheet({required this.onCreated});

  @override
  ConsumerState<_AddCourseSheet> createState() => _AddCourseSheetState();
}

class _AddCourseSheetState extends ConsumerState<_AddCourseSheet> {
  final _formKey   = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController();
  final _descCtrl  = TextEditingController();
  final _hoursCtrl = TextEditingController(text: '2');

  String  _type     = 'group';
  String? _ownerId;
  bool    _loading  = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _hoursCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    try {
      final studioId = ref.read(currentStudioIdProvider);
      if (studioId == null) throw Exception('Studio non trovato');
      final client = ref.read(supabaseClientProvider);

      await client.from('courses').insert({
        'name':                _nameCtrl.text.trim(),
        'type':                _type,
        'studio_id':           studioId,
        'class_owner_id':      _ownerId,
        'cancel_window_hours': int.tryParse(_hoursCtrl.text.trim()) ?? 2,
        'description':
            _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      });

      if (mounted) {
        Navigator.of(context).pop();
        widget.onCreated();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_nameCtrl.text.trim()} creato!'),
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
    final staff = ref.watch(_staffForStudioProvider);

    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
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
              Text('Nuovo corso',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),

              // Nome
              TextFormField(
                controller: _nameCtrl,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nome corso',
                  prefixIcon: Icon(Icons.fitness_center_outlined),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Campo obbligatorio' : null,
              ),
              const SizedBox(height: 16),

              // Tipo
              Text('Tipo', style: theme.textTheme.labelMedium),
              const SizedBox(height: 8),
              Row(
                children: [
                  _TypeChip(
                    label: 'Collettivo',
                    icon: Icons.group_outlined,
                    selected: _type == 'group',
                    onTap: () => setState(() => _type = 'group'),
                  ),
                  const SizedBox(width: 8),
                  _TypeChip(
                    label: 'Personal',
                    icon: Icons.person_outline,
                    selected: _type == 'personal',
                    onTap: () => setState(() => _type = 'personal'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Responsabile
              staff.when(
                loading: () => const LinearProgressIndicator(),
                error:   (e, _) => const SizedBox.shrink(),
                data: (members) => DropdownButtonFormField<String?>(
                  initialValue: _ownerId,
                  decoration: const InputDecoration(
                    labelText: 'Responsabile (class owner)',
                    prefixIcon: Icon(Icons.manage_accounts_outlined),
                  ),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('Nessuno')),
                    ...members.map((m) => DropdownMenuItem(
                          value: m['id'] as String,
                          child: Text(m['full_name'] as String),
                        )),
                  ],
                  onChanged: (v) => setState(() => _ownerId = v),
                ),
              ),
              const SizedBox(height: 12),

              // Finestra cancellazione
              TextFormField(
                controller: _hoursCtrl,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Ore anticipo per disdetta',
                  prefixIcon: Icon(Icons.timer_outlined),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  if (int.tryParse(v.trim()) == null) return 'Inserisci un numero';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Descrizione
              TextFormField(
                controller: _descCtrl,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Descrizione (opzionale)',
                  prefixIcon: Icon(Icons.notes_outlined),
                  alignLabelWithHint: true,
                ),
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
                      : const Text('Crea corso'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _TypeChip(
      {required this.label,
      required this.icon,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? cs.primary : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? cs.primary : cs.outline,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 18,
                color: selected ? cs.onPrimary : cs.onSurface.withAlpha(180)),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                  color:
                      selected ? cs.onPrimary : cs.onSurface.withAlpha(180),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                )),
          ],
        ),
      ),
    );
  }
}
