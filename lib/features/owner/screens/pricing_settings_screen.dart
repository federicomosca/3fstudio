import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/studio.dart';
import '../../../core/providers/studio_provider.dart';
import '../../../core/providers/selected_studio_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart' show supabaseClientProvider;
import '../providers/pricing_provider.dart';

class PricingSettingsScreen extends ConsumerStatefulWidget {
  final bool hideAppBar;
  const PricingSettingsScreen({super.key, this.hideAppBar = false});

  @override
  ConsumerState<PricingSettingsScreen> createState() =>
      _PricingSettingsScreenState();
}

class _PricingSettingsScreenState extends ConsumerState<PricingSettingsScreen> {
  final _formKey      = GlobalKey<FormState>();
  final _groupCtrl    = TextEditingController();
  final _sharedCtrl   = TextEditingController();
  final _personalCtrl = TextEditingController();
  final _discountCtrl = TextEditingController();

  bool _initialized = false;
  bool _saving      = false;
  String? _error;

  @override
  void dispose() {
    _groupCtrl.dispose();
    _sharedCtrl.dispose();
    _personalCtrl.dispose();
    _discountCtrl.dispose();
    super.dispose();
  }

  void _initControllers(Map<String, dynamic> pricing) {
    if (_initialized) return;
    _groupCtrl.text    = (pricing['group_surcharge_pct']           as num).toStringAsFixed(0);
    _sharedCtrl.text   = (pricing['shared_surcharge_pct']          as num).toStringAsFixed(0);
    _personalCtrl.text = (pricing['personal_surcharge_pct']        as num).toStringAsFixed(0);
    _discountCtrl.text = (pricing['second_course_discount_pct']    as num).toStringAsFixed(0);
    _initialized = true;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final studioId = ref.read(currentStudioIdProvider);
    if (studioId == null) return;

    setState(() { _saving = true; _error = null; });
    try {
      await ref.read(supabaseClientProvider).from('studios').update({
        'group_surcharge_pct':         double.parse(_groupCtrl.text.trim()),
        'shared_surcharge_pct':        double.parse(_sharedCtrl.text.trim()),
        'personal_surcharge_pct':      double.parse(_personalCtrl.text.trim()),
        'second_course_discount_pct':  double.parse(_discountCtrl.text.trim()),
      }).eq('id', studioId);

      ref.invalidate(studioPricingProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tariffe aggiornate'),
            backgroundColor: Color(0xFF66BB6A),
          ),
        );
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showCopyFromStudioDialog(
    BuildContext context,
    List<Studio> otherStudios,
    String? currentStudioId,
  ) {
    Studio? selected = otherStudios.length == 1 ? otherStudios.first : null;
    bool loading = false;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Copia tariffe da sede'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'I valori verranno caricati nel form. '
                'Premi "Salva tariffe" per confermare.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<Studio>(
                initialValue: selected,
                decoration: const InputDecoration(
                  labelText: 'Sede sorgente',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: otherStudios
                    .map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(s.name),
                        ))
                    .toList(),
                onChanged: loading
                    ? null
                    : (v) => setDlgState(() => selected = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: loading ? null : () => Navigator.pop(ctx),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: (selected == null || loading || currentStudioId == null)
                  ? null
                  : () async {
                      setDlgState(() => loading = true);
                      await _loadPricingFromStudio(context, selected!.id);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
              child: loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Copia'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadPricingFromStudio(
      BuildContext context, String sourceStudioId) async {
    try {
      final client = ref.read(supabaseClientProvider);
      final row = await client
          .from('studios')
          .select(
              'group_surcharge_pct, shared_surcharge_pct, '
              'personal_surcharge_pct, second_course_discount_pct')
          .eq('id', sourceStudioId)
          .single();

      if (!mounted) return;
      setState(() {
        _groupCtrl.text =
            (row['group_surcharge_pct'] as num).toStringAsFixed(0);
        _sharedCtrl.text =
            (row['shared_surcharge_pct'] as num).toStringAsFixed(0);
        _personalCtrl.text =
            (row['personal_surcharge_pct'] as num).toStringAsFixed(0);
        _discountCtrl.text =
            (row['second_course_discount_pct'] as num).toStringAsFixed(0);
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Tariffe caricate — premi Salva per confermare')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Errore: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pricingAsync = ref.watch(studioPricingProvider);
    final currentStudioId = ref.watch(currentStudioIdProvider);
    final allStudios = ref.watch(userSediProvider).whenOrNull(data: (s) => s) ?? [];
    final otherStudios = allStudios.where((s) => s.id != currentStudioId).toList();

    return Scaffold(
      appBar: widget.hideAppBar
          ? null
          : AppBar(title: const Text('Tariffe')),
      body: pricingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text('Errore: $e', style: const TextStyle(color: Colors.red))),
        data: (pricing) {
          if (pricing != null) _initControllers(pricing);
          if (!_initialized) return const Center(child: CircularProgressIndicator());
          return _buildForm(context, otherStudios, currentStudioId);
        },
      ),
    );
  }

  Widget _buildForm(BuildContext context, List<Studio> otherStudios, String? currentStudioId) {
    final theme = Theme.of(context);
    final cs    = theme.colorScheme;

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (widget.hideAppBar) ...[
            Text('Tariffe',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
          ],
          Text(
            'Definisci i moltiplicatori applicati alla tariffa oraria base di '
            'ciascun corso. Il prezzo di un piano viene calcolato automaticamente '
            'in fase di assegnazione.',
            style: TextStyle(color: cs.onSurface.withAlpha(170), fontSize: 13),
          ),
          const SizedBox(height: 16),

          if (otherStudios.isNotEmpty)
            OutlinedButton.icon(
              onPressed: () =>
                  _showCopyFromStudioDialog(context, otherStudios, currentStudioId),
              icon: const Icon(Icons.copy_all, size: 16),
              label: const Text('Copia da altra sede'),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
            ),

          const SizedBox(height: 24),

          _SurchargeField(
            controller: _groupCtrl,
            label: 'Rincaro Gruppo',
            icon: Icons.group_outlined,
            description: 'Applicato ai corsi di tipo Gruppo',
          ),
          const SizedBox(height: 16),
          _SurchargeField(
            controller: _sharedCtrl,
            label: 'Rincaro Condiviso',
            icon: Icons.people_outline,
            description: 'Applicato ai corsi di tipo Condiviso',
          ),
          const SizedBox(height: 16),
          _SurchargeField(
            controller: _personalCtrl,
            label: 'Rincaro Personal',
            icon: Icons.person_outline,
            description: 'Applicato ai corsi di tipo Personal',
          ),
          const SizedBox(height: 16),
          _SurchargeField(
            controller: _discountCtrl,
            label: 'Sconto 2° corso',
            icon: Icons.discount_outlined,
            description: 'Sconto applicato automaticamente quando il cliente '
                'si iscrive a un secondo corso. Impostare 0 per disabilitarlo.',
            accentColor: AppTheme.cyan,
            isSurcharge: false,
          ),

          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.errorContainer,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: cs.error.withAlpha(100)),
              ),
              child: Row(children: [
                Icon(Icons.error_outline,
                    color: cs.onErrorContainer, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_error!,
                      style: TextStyle(
                          color: cs.onErrorContainer, fontSize: 13)),
                ),
              ]),
            ),
          ],

          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Salva tariffe'),
            ),
          ),

          const SizedBox(height: 28),
          _ExampleCard(),
        ],
      ),
    );
  }
}

// ── Surcharge field ────────────────────────────────────────────────────────────

class _SurchargeField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String description;
  final Color? accentColor;
  final bool isSurcharge;
  const _SurchargeField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.description,
    this.accentColor,
    this.isSurcharge = true,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = accentColor ?? cs.onSurface.withAlpha(180);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 13, color: color)),
        ]),
        const SizedBox(height: 4),
        Text(description,
            style: TextStyle(fontSize: 12, color: cs.onSurface.withAlpha(130))),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            suffixText: isSurcharge ? '+%' : '-%',
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Campo obbligatorio';
            final n = double.tryParse(v.trim());
            if (n == null) return 'Inserisci un numero';
            if (n < 0) return 'Deve essere ≥ 0';
            return null;
          },
        ),
      ],
    );
  }
}

// ── Example card ───────────────────────────────────────────────────────────────

class _ExampleCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.lightbulb_outline, size: 16, color: AppTheme.blue),
            const SizedBox(width: 6),
            Text('Esempio di calcolo',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppTheme.blue)),
          ]),
          const SizedBox(height: 10),
          Text(
            'Corso Body Building · tariffa base €10/lezione\n'
            '  · Gruppo (+20%): €12/lezione\n'
            '  · Condiviso (+50%): €15/lezione\n'
            '  · Personal (+100%): €20/lezione\n\n'
            'Sconto 2° corso (-15%): applicato automaticamente\n'
            '  es. piano crediti da €120 → €102',
            style: TextStyle(
                fontSize: 13,
                color: cs.onSurface.withAlpha(180),
                height: 1.6),
          ),
        ],
      ),
    );
  }
}
