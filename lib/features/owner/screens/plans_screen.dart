import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../core/providers/studio_provider.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

final _plansProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final studioId = ref.watch(currentStudioIdProvider);
  if (studioId == null) return [];
  final client = ref.watch(supabaseClientProvider);
  final data = await client
      .from('plans')
      .select('id, name, type, credits, price, duration_days')
      .eq('studio_id', studioId)
      .order('price');
  return (data as List).cast<Map<String, dynamic>>();
});

// ── Screen ────────────────────────────────────────────────────────────────────

class PlansScreen extends ConsumerWidget {
  const PlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(_plansProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Piani & abbonamenti')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nuovo piano'),
      ),
      body: plans.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Errore: $e', style: TextStyle(color: cs.error)),
        ),
        data: (list) => list.isEmpty
            ? _emptyState(cs)
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: list.length,
                separatorBuilder: (context, i) => const SizedBox(height: 10),
                itemBuilder: (context, i) => _PlanCard(
                  plan: list[i],
                  onEdit:   () => _openSheet(context, ref, existing: list[i]),
                  onDelete: () => _confirmDelete(context, ref, list[i]),
                ),
              ),
      ),
    );
  }

  Widget _emptyState(ColorScheme cs) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.card_membership_outlined,
                size: 56, color: cs.onSurface.withAlpha(60)),
            const SizedBox(height: 12),
            Text('Nessun piano',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface.withAlpha(180))),
            const SizedBox(height: 4),
            Text('Crea il primo piano con il pulsante +',
                style: TextStyle(
                    fontSize: 13, color: cs.onSurface.withAlpha(120))),
          ],
        ),
      );

  void _openSheet(BuildContext context, WidgetRef ref,
      {Map<String, dynamic>? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _PlanSheet(
        existing: existing,
        onSaved: () => ref.invalidate(_plansProvider),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Map<String, dynamic> plan) async {
    final cs = Theme.of(context).colorScheme;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cs.surface,
        title: const Text('Elimina piano'),
        content: Text('Eliminare "${plan['name']}"? L\'operazione è irreversibile.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annulla')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: cs.error),
              child: const Text('Elimina')),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;

    try {
      final client = ref.read(supabaseClientProvider);
      await client.from('plans').delete().eq('id', plan['id']);
      ref.invalidate(_plansProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Piano eliminato')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e')),
        );
      }
    }
  }
}

// ── Plan card ─────────────────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  final Map<String, dynamic> plan;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _PlanCard(
      {required this.plan, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final cs   = Theme.of(context).colorScheme;
    final type = plan['type'] as String;
    final price    = (plan['price'] as num?)?.toDouble() ?? 0;
    final credits  = plan['credits']      as int?;
    final duration = plan['duration_days'] as int?;

    final (IconData icon, Color color, String typeLabel) = switch (type) {
      'unlimited' => (Icons.all_inclusive,            AppTheme.cyan, 'Illimitato'),
      'trial'     => (Icons.card_giftcard_outlined,   Colors.orange, 'Prova'),
      _           => (Icons.confirmation_number_outlined, AppTheme.blue, 'Crediti'),
    };

    return Container(
      decoration: BoxDecoration(
        color:  cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline),
      ),
      child: Row(
        children: [
          // Colored left bar
          Container(
            width: 5,
            height: 80,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.only(
                topLeft:    Radius.circular(14),
                bottomLeft: Radius.circular(14),
              ),
            ),
          ),

          // Icon
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color:        color.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
          ),

          // Text
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(plan['name'] as String,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    children: [
                      _Chip(typeLabel, color),
                      _Chip('€${price.toStringAsFixed(0)}', cs.primary),
                      if (credits != null) _Chip('$credits lezioni', cs.secondary),
                      if (duration != null) _Chip('${duration}gg', cs.onSurface.withAlpha(120)),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Actions
          PopupMenuButton<String>(
            color: cs.surface,
            onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                  value: 'edit',
                  child: Row(children: [
                    Icon(Icons.edit_outlined, size: 18),
                    SizedBox(width: 10),
                    Text('Modifica'),
                  ])),
              PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    Icon(Icons.delete_outline, size: 18, color: cs.error),
                    const SizedBox(width: 10),
                    Text('Elimina', style: TextStyle(color: cs.error)),
                  ])),
            ],
            icon: Icon(Icons.more_vert, color: cs.onSurface.withAlpha(150)),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color:        color.withAlpha(30),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      );
}

// ── Bottom sheet ──────────────────────────────────────────────────────────────

class _PlanSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic>? existing;
  final VoidCallback onSaved;
  const _PlanSheet({this.existing, required this.onSaved});

  @override
  ConsumerState<_PlanSheet> createState() => _PlanSheetState();
}

class _PlanSheetState extends ConsumerState<_PlanSheet> {
  final _formKey  = GlobalKey<FormState>();
  final _nameCt   = TextEditingController();
  final _priceCt  = TextEditingController();
  final _creditCt = TextEditingController();
  final _daysCt   = TextEditingController();

  String _type    = 'credits';
  bool   _saving  = false;

  static const _types = [
    ('credits',   'Crediti',    Icons.confirmation_number_outlined),
    ('unlimited', 'Illimitato', Icons.all_inclusive),
    ('trial',     'Prova',      Icons.card_giftcard_outlined),
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameCt.text  = e['name']          as String? ?? '';
      _priceCt.text = (e['price'] as num?)?.toStringAsFixed(0) ?? '';
      _creditCt.text = (e['credits'] as int?)?.toString() ?? '';
      _daysCt.text  = (e['duration_days'] as int?)?.toString() ?? '';
      _type         = e['type']           as String? ?? 'credits';
    }
  }

  @override
  void dispose() {
    _nameCt.dispose(); _priceCt.dispose();
    _creditCt.dispose(); _daysCt.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final studioId = ref.read(currentStudioIdProvider);
      final client   = ref.read(supabaseClientProvider);
      final payload  = {
        'name':          _nameCt.text.trim(),
        'type':          _type,
        'price':         double.tryParse(_priceCt.text) ?? 0,
        'credits':       _type == 'credits'
            ? int.tryParse(_creditCt.text)
            : null,
        'duration_days': _daysCt.text.isNotEmpty
            ? int.tryParse(_daysCt.text)
            : null,
        'studio_id':     studioId,
      };

      if (widget.existing != null) {
        await client
            .from('plans')
            .update(payload)
            .eq('id', widget.existing!['id']);
      } else {
        await client.from('plans').insert(payload);
      }

      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs  = Theme.of(context).colorScheme;
    final isEdit = widget.existing != null;

    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: cs.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Text(
              isEdit ? 'Modifica piano' : 'Nuovo piano',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 20),

            // Nome
            TextFormField(
              controller: _nameCt,
              decoration: const InputDecoration(labelText: 'Nome piano'),
              textCapitalization: TextCapitalization.sentences,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Campo obbligatorio' : null,
            ),
            const SizedBox(height: 14),

            // Tipo
            Text('Tipo',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface.withAlpha(150))),
            const SizedBox(height: 8),
            Row(
              children: _types.map((t) {
                final (value, label, icon) = t;
                final selected = _type == value;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _type = value),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppTheme.blue.withAlpha(40)
                            : cs.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected ? AppTheme.blue : cs.outline,
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(icon,
                              size: 20,
                              color: selected
                                  ? AppTheme.blue
                                  : cs.onSurface.withAlpha(120)),
                          const SizedBox(height: 4),
                          Text(label,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: selected
                                      ? AppTheme.blue
                                      : cs.onSurface.withAlpha(150))),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // Prezzo + Crediti
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _priceCt,
                    decoration: const InputDecoration(
                      labelText: 'Prezzo (€)',
                      prefixText: '€ ',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                    ],
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Obbligatorio' : null,
                  ),
                ),
                if (_type == 'credits') ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _creditCt,
                      decoration: const InputDecoration(labelText: 'N. lezioni'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),

            // Durata giorni
            TextFormField(
              controller: _daysCt,
              decoration: const InputDecoration(
                labelText: 'Durata (giorni)',
                hintText: 'es. 30, 90, 365 — lascia vuoto per illimitata',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 24),

            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(isEdit ? 'Salva modifiche' : 'Crea piano'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
