import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/studio_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../profile/providers/profile_provider.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _availablePlansProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
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

final _myPendingRequestProvider =
    FutureProvider<Map<String, dynamic>?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  final studioId = ref.watch(currentStudioIdProvider);
  if (studioId == null) return null;
  final client = ref.watch(supabaseClientProvider);
  final data = await client
      .from('plan_requests')
      .select('id, status, created_at, plans(name, type, credits, price)')
      .eq('user_id', user.id)
      .eq('studio_id', studioId)
      .eq('status', 'pending')
      .order('created_at', ascending: false)
      .limit(1)
      .maybeSingle();
  return data;
});

// ── Screen ────────────────────────────────────────────────────────────────────

class ClientPlansScreen extends ConsumerWidget {
  const ClientPlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync   = ref.watch(_availablePlansProvider);
    final requestAsync = ref.watch(_myPendingRequestProvider);
    final activePlan   = ref.watch(activePlanProvider);
    final cs           = Theme.of(context).colorScheme;

    final hasPending = requestAsync.whenOrNull(data: (r) => r != null) ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Piani disponibili')),
      body: plansAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text('Errore: $e', style: TextStyle(color: cs.error))),
        data: (plans) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            // Banner richiesta in attesa
            requestAsync.whenOrNull(
              data: (req) => req != null
                  ? _PendingBanner(
                      request: req,
                      onCancel: () => _cancelRequest(context, ref, req['id'] as String),
                    )
                  : null,
            ) ?? const SizedBox.shrink(),

            // Piano attivo
            activePlan.whenOrNull(
              data: (plan) => plan != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionLabel('Piano attivo'),
                        const SizedBox(height: 8),
                        _ActivePlanTile(plan: plan),
                        const SizedBox(height: 20),
                      ],
                    )
                  : null,
            ) ?? const SizedBox.shrink(),

            _SectionLabel('Piani disponibili'),
            const SizedBox(height: 8),

            if (plans.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    'Nessun piano disponibile',
                    style: TextStyle(color: cs.onSurface.withAlpha(120)),
                  ),
                ),
              )
            else
              ...plans.map((plan) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _PlanCard(
                      plan: plan,
                      hasPendingRequest: hasPending,
                      onRequest: () => _requestPlan(context, ref, plan),
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  // ── Azioni ──────────────────────────────────────────────────────────────────

  Future<void> _requestPlan(BuildContext context, WidgetRef ref,
      Map<String, dynamic> plan) async {
    final price = (plan['price'] as num?)?.toDouble() ?? 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Richiedi piano'),
        content: Text(
          'Stai richiedendo "${plan['name']}" (€${price.toStringAsFixed(0)}).\n\n'
          'Il piano sarà attivato dall\'istruttore dopo aver verificato il pagamento.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Invia richiesta'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final user     = ref.read(currentUserProvider);
      final studioId = ref.read(currentStudioIdProvider);
      final db       = ref.read(supabaseClientProvider);
      await db.from('plan_requests').insert({
        'user_id':   user!.id,
        'plan_id':   plan['id'],
        'studio_id': studioId,
        'status':    'pending',
      });
      ref.invalidate(_myPendingRequestProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Richiesta inviata! L\'istruttore la attiverà dopo il pagamento.'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Errore: $e')));
      }
    }
  }

  Future<void> _cancelRequest(
      BuildContext context, WidgetRef ref, String requestId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ritira richiesta'),
        content: const Text('Vuoi ritirare la richiesta del piano?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('Ritira'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final db = ref.read(supabaseClientProvider);
      await db
          .from('plan_requests')
          .update({'status': 'cancelled'})
          .eq('id', requestId);
      ref.invalidate(_myPendingRequestProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Richiesta ritirata')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Errore: $e')));
      }
    }
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────

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

class _PendingBanner extends StatelessWidget {
  final Map<String, dynamic> request;
  final VoidCallback onCancel;
  const _PendingBanner({required this.request, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final planData = request['plans'] as Map<String, dynamic>?;
    final planName = planData?['name'] as String? ?? '—';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.blue.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.blue.withAlpha(100)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.hourglass_empty, color: AppTheme.blue, size: 18),
              const SizedBox(width: 8),
              Text(
                'Richiesta in attesa',
                style: TextStyle(
                    color: AppTheme.blue, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Hai richiesto "$planName".\n'
            'L\'istruttore la attiverà dopo aver verificato il pagamento.',
            style: TextStyle(fontSize: 13, color: AppTheme.blue.withAlpha(210)),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: onCancel,
            child: Text(
              'Ritira richiesta',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivePlanTile extends StatelessWidget {
  final ActivePlan plan;
  const _ActivePlanTile({required this.plan});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.blue.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.blue.withAlpha(80)),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, color: AppTheme.blue, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(plan.planName,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                if (plan.planType == 'credits' && plan.creditsRemaining != null)
                  Text('${plan.creditsRemaining} crediti rimanenti',
                      style: TextStyle(
                          fontSize: 13, color: cs.onSurface.withAlpha(180))),
                if (plan.expiresAt != null)
                  Text(
                    'Scade il ${DateFormat('d MMM yyyy', 'it_IT').format(plan.expiresAt!)}',
                    style: TextStyle(
                        fontSize: 13, color: cs.onSurface.withAlpha(180)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final Map<String, dynamic> plan;
  final bool hasPendingRequest;
  final VoidCallback onRequest;
  const _PlanCard({
    required this.plan,
    required this.hasPendingRequest,
    required this.onRequest,
  });

  @override
  Widget build(BuildContext context) {
    final cs       = Theme.of(context).colorScheme;
    final type     = plan['type'] as String;
    final price    = (plan['price'] as num?)?.toDouble() ?? 0;
    final credits  = plan['credits'] as int?;
    final duration = plan['duration_days'] as int?;

    final (IconData icon, Color color, String typeLabel) = switch (type) {
      'unlimited' => (Icons.all_inclusive, AppTheme.cyan, 'Illimitato'),
      'trial'     => (Icons.card_giftcard_outlined, Colors.orange, 'Prova'),
      _           => (Icons.confirmation_number_outlined, AppTheme.blue, 'Crediti'),
    };

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Barra colorata sinistra
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
              // Icona
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
              ),
              // Testo
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan['name'] as String,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        children: [
                          _Chip(typeLabel, color),
                          _Chip('€${price.toStringAsFixed(0)}', cs.primary),
                          if (credits != null)
                            _Chip('$credits lezioni', cs.secondary),
                          if (duration != null)
                            _Chip('${duration}gg',
                                cs.onSurface.withAlpha(120)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: hasPendingRequest ? null : onRequest,
                child: Text(
                    hasPendingRequest ? 'Richiesta già inviata' : 'Richiedi'),
              ),
            ),
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
          color: color.withAlpha(30),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: color),
        ),
      );
}
