import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../core/providers/studio_provider.dart';
import '../../../core/providers/selected_studio_provider.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final coursesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final sedi = await ref.watch(userSediProvider.future);
  if (sedi.isEmpty) return [];
  final allStudioIds = sedi.map((s) => s.id).toList();
  final client = ref.watch(supabaseClientProvider);
  final data = await client
      .from('courses')
      .select('id, name, type, studio_id, cancel_window_hours, description, '
              'allows_group, allows_shared, allows_personal, '
              'users!class_owner_id(id, full_name)')
      .inFilter('studio_id', allStudioIds)
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
      .inFilter('role', ['trainer']);

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
    final courses = ref.watch(coursesProvider);
    final sedi    = ref.watch(userSediProvider).whenOrNull(data: (s) => s) ?? [];
    final hasMulipleSedi = sedi.length > 1;

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
        data: (list) {
          if (list.isEmpty) return _EmptyCourses(onAdd: () => _showAddSheet(context, ref));

          // Raggruppa per sede nell'ordine di userSediProvider
          final items = <Widget>[];
          final sedeOrder = sedi.map((s) => s.id).toList();
          // Courses not matched by any known sede (edge case)
          final otherIds = list.map((c) => c['studio_id'] as String?).whereType<String>().toSet()
              ..removeAll(sedeOrder);

          for (var si = 0; si < sedeOrder.length; si++) {
            final sedeId      = sedeOrder[si];
            final sedeCourses = list.where((c) => c['studio_id'] == sedeId).toList();
            if (sedeCourses.isEmpty) continue;

            if (hasMulipleSedi) {
              final sedeName = sedi[si].name;
              final color    = AppTheme.sedeColor(si);
              items.add(_SedeSectionHeader(name: sedeName, color: color));
            }
            for (final c in sedeCourses) {
              items.add(_CourseTile(c: c, onTap: () => context.push('/owner/courses/${c['id']}')));
            }
            if (hasMulipleSedi) items.add(const SizedBox(height: 8));
          }

          // Edge case: corsi di sedi non nel provider (es. accesso admin)
          final orphans = list.where((c) => otherIds.contains(c['studio_id'])).toList();
          if (orphans.isNotEmpty) {
            for (final c in orphans) {
              items.add(_CourseTile(c: c, onTap: () => context.push('/owner/courses/${c['id']}')));
            }
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: items,
          );
        },
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
        onCreated: () => ref.invalidate(coursesProvider),
      ),
    );
  }
}

// ── Sede section header ───────────────────────────────────────────────────────

class _SedeSectionHeader extends StatelessWidget {
  final String name;
  final Color color;
  const _SedeSectionHeader({required this.name, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Container(
          width: 12, height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          name,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: 0.4,
          ),
        ),
      ]),
    );
  }
}

// ── Course tile ───────────────────────────────────────────────────────────────

class _CourseTile extends StatelessWidget {
  final Map<String, dynamic> c;
  final VoidCallback onTap;
  const _CourseTile({required this.c, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final owner = c['users'] as Map<String, dynamic>?;
    final ag    = c['allows_group']    as bool? ?? true;
    final as_   = c['allows_shared']   as bool? ?? false;
    final ap    = c['allows_personal'] as bool? ?? false;
    final modes = [
      if (ag)  'Gruppo',
      if (as_) 'Condiviso',
      if (ap)  'Personal',
    ].join(' · ');
    final subtitle = owner != null
        ? '${owner['full_name']}  ·  $modes'
        : modes;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: Theme.of(context).colorScheme.surface,
        leading: CircleAvatar(
          backgroundColor: AppTheme.blue.withAlpha(30),
          child: Icon(Icons.fitness_center_outlined, color: AppTheme.blue),
        ),
        title: Text(c['name'] as String,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
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
  final _formKey    = GlobalKey<FormState>();
  final _nameCtrl   = TextEditingController();
  final _descCtrl   = TextEditingController();
  final _hoursCtrl  = TextEditingController(text: '2');
  final _rateCtrl   = TextEditingController();

  bool    _allowsGroup    = true;
  bool    _allowsShared   = false;
  bool    _allowsPersonal = false;
  String? _ownerId;
  bool    _loading  = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _hoursCtrl.dispose();
    _rateCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    try {
      final studioId = ref.read(currentStudioIdProvider);
      if (studioId == null) throw Exception('Studio non trovato');
      final client = ref.read(supabaseClientProvider);

      final derivedType = _allowsPersonal && !_allowsGroup && !_allowsShared
          ? 'personal'
          : _allowsShared && !_allowsGroup && !_allowsPersonal
              ? 'shared'
              : 'group';

      await client.from('courses').insert({
        'name':                _nameCtrl.text.trim(),
        'type':                derivedType,
        'studio_id':           studioId,
        'class_owner_id':      _ownerId,
        'cancel_window_hours': int.tryParse(_hoursCtrl.text.trim()) ?? 2,
        'description':
            _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        'hourly_rate':         double.tryParse(_rateCtrl.text.trim()) ?? 0,
        'allows_group':        _allowsGroup,
        'allows_shared':       _allowsShared,
        'allows_personal':     _allowsPersonal,
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

              // Modalità di lezione
              Text('Modalità di lezione abilitate', style: theme.textTheme.labelMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  FilterChip(
                    label: const Text('Gruppo'),
                    avatar: const Icon(Icons.group_outlined, size: 16),
                    selected: _allowsGroup,
                    onSelected: (v) => setState(() => _allowsGroup = v),
                  ),
                  FilterChip(
                    label: const Text('Condiviso'),
                    avatar: const Icon(Icons.people_outline, size: 16),
                    selected: _allowsShared,
                    onSelected: (v) => setState(() => _allowsShared = v),
                  ),
                  FilterChip(
                    label: const Text('Personal'),
                    avatar: const Icon(Icons.person_outline, size: 16),
                    selected: _allowsPersonal,
                    onSelected: (v) => setState(() => _allowsPersonal = v),
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
                  final n = int.tryParse(v.trim());
                  if (n == null) return 'Inserisci un numero';
                  if (n < 0) return 'Il valore deve essere ≥ 0';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Tariffa oraria base
              TextFormField(
                controller: _rateCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Tariffa base per lezione (€)',
                  prefixIcon: Icon(Icons.euro_outlined),
                  hintText: 'es. 10',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  final n = double.tryParse(v.trim());
                  if (n == null) return 'Inserisci un numero';
                  if (n < 0) return 'Deve essere ≥ 0';
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
