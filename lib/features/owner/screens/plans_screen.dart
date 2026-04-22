import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../core/providers/studio_provider.dart';
import '../providers/plan_requests_provider.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _pendingRequestsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final studioId = ref.watch(currentStudioIdProvider);
  if (studioId == null) return [];
  final client = ref.watch(supabaseClientProvider);
  final data = await client
      .from('plan_requests')
      .select(
          'id, user_id, plan_id, created_at, '
          'users(full_name, email), '
          'plans(name, type, credits, duration_days), '
          'courses(name)')
      .eq('studio_id', studioId)
      .eq('status', 'pending')
      .order('created_at');
  return (data as List).cast<Map<String, dynamic>>();
});

final _plansProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final studioId = ref.watch(currentStudioIdProvider);
  if (studioId == null) return [];
  final client = ref.watch(supabaseClientProvider);
  final data = await client
      .from('plans')
      .select('id, name, type, credits, duration_days')
      .eq('studio_id', studioId)
      .order('name');
  return (data as List).cast<Map<String, dynamic>>();
});

// ── Screen ────────────────────────────────────────────────────────────────────

class PlansScreen extends ConsumerWidget {
  final bool hideAppBar;
  const PlansScreen({super.key, this.hideAppBar = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans    = ref.watch(_plansProvider);
    final requests = ref.watch(_pendingRequestsProvider);
    final cs       = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: hideAppBar ? null : AppBar(title: const Text('Piani & abbonamenti')),
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
        data: (list) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            // ── Richieste in attesa ────────────────────────────────────────
            requests.whenOrNull(
              data: (reqs) => reqs.isNotEmpty
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionLabel('Richieste in attesa'),
                        const SizedBox(height: 8),
                        ...reqs.map((r) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _RequestCard(
                                request: r,
                                onApprove: () =>
                                    _approveRequest(context, ref, r),
                                onReject: () =>
                                    _rejectRequest(context, ref, r),
                              ),
                            )),
                        const SizedBox(height: 12),
                        Divider(color: cs.outline),
                        const SizedBox(height: 12),
                      ],
                    )
                  : null,
            ) ?? const SizedBox.shrink(),

            // ── Lista piani ───────────────────────────────────────────────
            if (list.isEmpty)
              _emptyState(cs)
            else ...[
              _SectionLabel('Piani disponibili'),
              const SizedBox(height: 8),
              ...list.asMap().entries.map((e) => Padding(
                    padding: EdgeInsets.only(
                        bottom: e.key < list.length - 1 ? 10 : 0),
                    child: _PlanCard(
                      plan: e.value,
                      onEdit: () =>
                          _openSheet(context, ref, existing: e.value),
                      onDelete: () =>
                          _confirmDelete(context, ref, e.value),
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  // ── Approvazione richiesta ─────────────────────────────────────────────────

  Future<void> _approveRequest(BuildContext context, WidgetRef ref,
      Map<String, dynamic> request) async {
    final plan       = request['plans']   as Map<String, dynamic>? ?? {};
    final user       = request['users']   as Map<String, dynamic>? ?? {};
    final course     = request['courses'] as Map<String, dynamic>?;
    final planName   = plan['name']       as String? ?? '—';
    final userName   = user['full_name']  as String? ?? '—';
    final courseName = course?['name']    as String?;
    final planType   = plan['type']       as String? ?? 'credits';
    final credits    = plan['credits']    as int?;
    final duration   = plan['duration_days'] as int?;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Attiva piano'),
        content: Text(
          'Attivare "$planName"${courseName != null ? ' per il corso "$courseName"' : ''} a $userName?\n\n'
          'Assicurati di aver ricevuto il pagamento prima di procedere.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Attiva'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final db       = ref.read(supabaseClientProvider);
      final userId   = request['user_id'] as String;
      final planId   = request['plan_id'] as String;
      final now      = DateTime.now().toUtc();
      final expiresAt = duration != null
          ? now.add(Duration(days: duration)).toIso8601String()
          : null;
      final creditsRemaining = planType == 'credits' ? credits : null;

      await db.from('user_plans').insert({
        'user_id':           userId,
        'plan_id':           planId,
        'credits_remaining': creditsRemaining,
        'expires_at':        expiresAt,
      });
      await db.from('plan_requests').update({
        'status':      'approved',
        'reviewed_at': now.toIso8601String(),
      }).eq('id', request['id']);

      ref.invalidate(_pendingRequestsProvider);
      ref.invalidate(pendingPlanRequestsCountProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Piano "$planName" attivato per $userName')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Errore: $e')));
      }
    }
  }

  Future<void> _rejectRequest(BuildContext context, WidgetRef ref,
      Map<String, dynamic> request) async {
    final plan     = request['plans'] as Map<String, dynamic>? ?? {};
    final user     = request['users'] as Map<String, dynamic>? ?? {};
    final planName = plan['name'] as String? ?? '—';
    final userName = user['full_name'] as String? ?? '—';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rifiuta richiesta'),
        content: Text('Rifiutare la richiesta di "$planName" per $userName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('Rifiuta'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final db  = ref.read(supabaseClientProvider);
      final now = DateTime.now().toUtc().toIso8601String();
      await db.from('plan_requests').update({
        'status':      'rejected',
        'reviewed_at': now,
      }).eq('id', request['id']);

      ref.invalidate(_pendingRequestsProvider);
      ref.invalidate(pendingPlanRequestsCountProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Richiesta rifiutata')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Errore: $e')));
      }
    }
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

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: Theme.of(context).colorScheme.onSurface.withAlpha(180),
          letterSpacing: 0.5,
        ),
      );
}

// ── Request card ──────────────────────────────────────────────────────────────

class _RequestCard extends StatelessWidget {
  final Map<String, dynamic> request;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  const _RequestCard({
    required this.request,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final cs         = Theme.of(context).colorScheme;
    final plan       = request['plans']   as Map<String, dynamic>? ?? {};
    final user       = request['users']   as Map<String, dynamic>? ?? {};
    final course     = request['courses'] as Map<String, dynamic>?;
    final planName   = plan['name']   as String? ?? '—';
    final userName   = user['full_name'] as String? ?? '—';
    final courseName = course?['name'] as String?;
    final createdAt  = request['created_at'] as String?;
    DateTime? created;
    if (createdAt != null) created = DateTime.tryParse(createdAt)?.toLocal();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.blue.withAlpha(15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.blue.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.hourglass_empty, color: AppTheme.blue, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  userName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              if (created != null)
                Text(
                  DateFormat('d MMM', 'it_IT').format(created),
                  style: TextStyle(
                      fontSize: 12, color: cs.onSurface.withAlpha(150)),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            planName,
            style: TextStyle(fontSize: 13, color: cs.onSurface.withAlpha(180)),
          ),
          if (courseName != null) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.fitness_center_outlined,
                    size: 12, color: cs.onSurface.withAlpha(130)),
                const SizedBox(width: 4),
                Text(
                  courseName,
                  style: TextStyle(
                      fontSize: 12, color: cs.onSurface.withAlpha(150)),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: cs.error,
                    side: BorderSide(color: cs.error.withAlpha(120)),
                  ),
                  child: const Text('Rifiuta'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: onApprove,
                  child: const Text('Attiva'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
    final type     = plan['type'] as String;
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
  final _creditCt = TextEditingController();
  final _daysCt   = TextEditingController();

  String _type        = 'credits';
  // Solo per tipo trial: 'credits' | 'duration'
  String _trialMode   = 'credits';
  // Solo per tipo trial + trialMode duration: 'days' | 'weeks'
  String _durationUnit = 'days';
  bool   _saving      = false;

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
      _nameCt.text = e['name'] as String? ?? '';
      _type        = e['type'] as String? ?? 'credits';
      final credits  = e['credits']      as int?;
      final days     = e['duration_days'] as int?;
      if (_type == 'trial') {
        if (credits != null) {
          _trialMode   = 'credits';
          _creditCt.text = credits.toString();
        } else if (days != null) {
          _trialMode = 'duration';
          if (days % 7 == 0) {
            _durationUnit  = 'weeks';
            _daysCt.text   = (days ~/ 7).toString();
          } else {
            _durationUnit  = 'days';
            _daysCt.text   = days.toString();
          }
        }
      } else {
        _creditCt.text = credits?.toString() ?? '';
        _daysCt.text   = days?.toString()    ?? '';
      }
    }
  }

  @override
  void dispose() {
    _nameCt.dispose();
    _creditCt.dispose();
    _daysCt.dispose();
    super.dispose();
  }

  int? get _computedDurationDays {
    final n = int.tryParse(_daysCt.text.trim());
    if (n == null) return null;
    return _durationUnit == 'weeks' ? n * 7 : n;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final studioId = ref.read(currentStudioIdProvider);
      final client   = ref.read(supabaseClientProvider);

      int?  credits;
      int?  durationDays;

      if (_type == 'credits') {
        credits     = int.tryParse(_creditCt.text);
        durationDays = _daysCt.text.isNotEmpty ? int.tryParse(_daysCt.text) : null;
      } else if (_type == 'unlimited') {
        durationDays = _daysCt.text.isNotEmpty ? int.tryParse(_daysCt.text) : null;
      } else { // trial
        if (_trialMode == 'credits') {
          credits = int.tryParse(_creditCt.text);
        } else {
          durationDays = _computedDurationDays;
        }
      }

      final payload = {
        'name':          _nameCt.text.trim(),
        'type':          _type,
        'credits':       credits,
        'duration_days': durationDays,
        'studio_id':     studioId,
      };

      if (widget.existing != null) {
        await client.from('plans').update(payload).eq('id', widget.existing!['id']);
      } else {
        await client.from('plans').insert(payload);
      }

      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Errore: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
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
                  color: cs.outline, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),

            Text(
              isEdit ? 'Modifica piano' : 'Nuovo piano',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 20),

            // ── Nome ──────────────────────────────────────────────────────────
            TextFormField(
              controller: _nameCt,
              decoration: const InputDecoration(labelText: 'Nome piano'),
              textCapitalization: TextCapitalization.sentences,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Campo obbligatorio' : null,
            ),
            const SizedBox(height: 14),

            // ── Tipo ──────────────────────────────────────────────────────────
            Text('Tipo',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700,
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
                        color: selected ? AppTheme.blue.withAlpha(40) : cs.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected ? AppTheme.blue : cs.outline,
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(icon, size: 20,
                              color: selected
                                  ? AppTheme.blue
                                  : cs.onSurface.withAlpha(120)),
                          const SizedBox(height: 4),
                          Text(label,
                              style: TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w700,
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

            // ── Campi per tipo Crediti ─────────────────────────────────────
            if (_type == 'credits') ...[
              TextFormField(
                controller: _creditCt,
                decoration: const InputDecoration(labelText: 'N. lezioni'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _daysCt,
                decoration: const InputDecoration(
                  labelText: 'Durata (giorni)',
                  hintText: 'es. 30, 90, 365 — lascia vuoto per illimitata',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ],

            // ── Campi per tipo Illimitato ──────────────────────────────────
            if (_type == 'unlimited')
              TextFormField(
                controller: _daysCt,
                decoration: const InputDecoration(
                  labelText: 'Durata (giorni)',
                  hintText: 'es. 30, 90, 365 — lascia vuoto per illimitata',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),

            // ── Campi per tipo Prova ───────────────────────────────────────
            if (_type == 'trial') ...[
              // Sub-toggle Crediti / Durata
              Text('Modalità prova',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700,
                      color: cs.onSurface.withAlpha(150))),
              const SizedBox(height: 8),
              Row(children: [
                _ModeToggle(
                  label: 'Crediti',
                  icon: Icons.confirmation_number_outlined,
                  selected: _trialMode == 'credits',
                  onTap: () => setState(() => _trialMode = 'credits'),
                ),
                const SizedBox(width: 8),
                _ModeToggle(
                  label: 'Durata',
                  icon: Icons.calendar_today_outlined,
                  selected: _trialMode == 'duration',
                  onTap: () => setState(() => _trialMode = 'duration'),
                ),
              ]),
              const SizedBox(height: 14),

              if (_trialMode == 'credits')
                TextFormField(
                  controller: _creditCt,
                  decoration: const InputDecoration(labelText: 'N. crediti prova'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Campo obbligatorio' : null,
                ),

              if (_trialMode == 'duration')
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(
                    width: 90,
                    child: TextFormField(
                      controller: _daysCt,
                      decoration: const InputDecoration(labelText: 'Quantità'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Obbligatorio' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Unità',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700,
                                color: cs.onSurface.withAlpha(150))),
                        const SizedBox(height: 6),
                        Row(children: [
                          _ModeToggle(
                            label: 'Giorni',
                            selected: _durationUnit == 'days',
                            onTap: () => setState(() => _durationUnit = 'days'),
                          ),
                          const SizedBox(width: 8),
                          _ModeToggle(
                            label: 'Settimane',
                            selected: _durationUnit == 'weeks',
                            onTap: () => setState(() => _durationUnit = 'weeks'),
                          ),
                        ]),
                      ],
                    ),
                  ),
                ]),
            ],

            const SizedBox(height: 24),

            // ── Save ──────────────────────────────────────────────────────────
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

class _ModeToggle extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;
  const _ModeToggle({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.blue.withAlpha(40) : cs.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppTheme.blue : cs.outline,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16,
                  color: selected ? AppTheme.blue : cs.onSurface.withAlpha(120)),
              const SizedBox(width: 6),
            ],
            Text(label,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700,
                    color: selected ? AppTheme.blue : cs.onSurface.withAlpha(150))),
          ],
        ),
      ),
    );
  }
}
