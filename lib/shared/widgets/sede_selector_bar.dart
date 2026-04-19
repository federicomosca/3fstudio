import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/studio.dart';
import '../../core/providers/selected_studio_provider.dart';
import '../../core/providers/studio_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


/// Barra superiore per selezionare la sede attiva.
/// Mostrata in tutti i shell (owner, staff, client).
/// [profileRoute]: se valorizzato, mostra l'icona profilo che naviga a quella route.
class SedeSelectorBar extends ConsumerWidget {
  final String? profileRoute;

  const SedeSelectorBar({super.key, this.profileRoute});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sediAsync     = ref.watch(userSediProvider);
    final selectedAsync = ref.watch(selectedStudioProvider);
    final theme         = Theme.of(context);
    final roles         = ref.watch(appRolesProvider).whenOrNull(data: (r) => r);
    final canAddSede    = roles?.isGymOwner ?? false;

    final sedi     = sediAsync.whenOrNull(data: (s) => s) ?? [];
    final selected = selectedAsync.whenOrNull(data: (s) => s);

    final hasMultiple = sedi.length > 1;

    return Material(
      color: theme.colorScheme.primary,
      child: SafeArea(
        bottom: false,
        child: InkWell(
          onTap: sedi.isEmpty
              ? null
              : () => _showPicker(context, ref, sedi, selected, canAddSede),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.store, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: selectedAsync.when(
                    loading: () => const Text('…',
                        style: TextStyle(color: Colors.white, fontSize: 14)),
                    error: (e, _) =>
                        const Text('—', style: TextStyle(color: Colors.white)),
                    data: (studio) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (studio?.organizationName != null)
                          Text(
                            studio!.organizationName!,
                            style: TextStyle(
                              color: Colors.white.withAlpha(180),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        Text(
                          studio?.name ?? '—',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        if (studio?.address != null)
                          Text(
                            studio!.address!,
                            style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ),
                if (sedi.isNotEmpty)
                  Icon(
                    hasMultiple ? Icons.expand_more : Icons.keyboard_arrow_down,
                    color: Colors.white.withAlpha(hasMultiple ? 255 : 120),
                    size: 20,
                  ),
                if (profileRoute != null)
                  IconButton(
                    onPressed: () => context.push(profileRoute!),
                    icon: const Icon(Icons.account_circle_outlined,
                        color: Colors.white, size: 26),
                    tooltip: 'Profilo',
                    padding: EdgeInsets.zero,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPicker(
    BuildContext context,
    WidgetRef ref,
    List<Studio> sedi,
    Studio? current,
    bool canAddSede,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _SedePickerSheet(
        sedi: sedi,
        current: current,
        canAddSede: canAddSede,
        onSelect: (s) {
          ref.read(selectedStudioProvider.notifier).select(s);
          Navigator.pop(ctx);
        },
        onSetDefault: (s) async {
          await ref.read(selectedStudioProvider.notifier).setDefault(s);
          if (ctx.mounted) Navigator.pop(ctx);
        },
        onAddSede: canAddSede
            ? () {
                Navigator.pop(ctx);
                _showAddSedeDialog(context, ref);
              }
            : null,
      ),
    );
  }

  void _showAddSedeDialog(BuildContext context, WidgetRef ref) {
    final orgCtrl     = TextEditingController();
    final nameCtrl    = TextEditingController();
    final addressCtrl = TextEditingController();
    final formKey     = GlobalKey<FormState>();
    var   saving      = false;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Nuova sede'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: orgCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Organizzazione',
                    prefixIcon: Icon(Icons.business_outlined),
                    hintText: 'es. AL.FA.SE asd',
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nome sede *',
                    prefixIcon: Icon(Icons.store),
                    hintText: 'es. Via Aquileia 34',
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Campo obbligatorio' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: addressCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Indirizzo',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setState(() => saving = true);

                      try {
                        final session = Supabase.instance.client.auth.currentSession;
                        if (session == null) throw Exception('Sessione scaduta');

                        final address = addressCtrl.text.trim();
                        final org     = orgCtrl.text.trim();
                        final response = await Supabase.instance.client.functions.invoke(
                          'create-studio',
                          body: {
                            'name': nameCtrl.text.trim(),
                            if (address.isNotEmpty) 'address': address,
                            if (org.isNotEmpty) 'organization_name': org,
                          },
                          headers: {'Authorization': 'Bearer ${session.accessToken}'},
                        );

                        if (response.status != 200) {
                          final msg = (response.data as Map?)?['error'] as String?
                              ?? 'Errore sconosciuto';
                          throw Exception(msg);
                        }

                        final row = response.data as Map<String, dynamic>;

                        ref.invalidate(userSediProvider);
                        ref.invalidate(selectedStudioProvider);

                        if (ctx.mounted) Navigator.pop(ctx);

                        final newStudios = await ref.read(userSediProvider.future);
                        final newStudio = newStudios.firstWhere(
                          (s) => s.id == (row['id'] as String),
                          orElse: () => newStudios.last,
                        );
                        ref.read(selectedStudioProvider.notifier).select(newStudio);
                      } catch (e) {
                        setState(() => saving = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('Errore: $e')),
                          );
                        }
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Crea'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Picker sheet ──────────────────────────────────────────────────────────────

class _SedePickerSheet extends ConsumerWidget {
  final List<Studio> sedi;
  final Studio? current;
  final bool canAddSede;
  final void Function(Studio) onSelect;
  final Future<void> Function(Studio) onSetDefault;
  final VoidCallback? onAddSede;

  const _SedePickerSheet({
    required this.sedi,
    required this.current,
    required this.canAddSede,
    required this.onSelect,
    required this.onSetDefault,
    this.onAddSede,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme     = Theme.of(context);
    final defaultId = ref
        .watch(selectedStudioProvider)
        .whenOrNull(data: (s) => s?.id);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: theme.colorScheme.outline,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Seleziona sede',
            style:
                theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 8),
        ...sedi.map((sede) {
          final isSelected = sede.id == current?.id;
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: isSelected
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.surfaceContainerHighest,
              child: Icon(
                Icons.store,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withAlpha(150),
                size: 20,
              ),
            ),
            title: Text(
              sede.name,
              style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
            ),
            subtitle: sede.address != null ? Text(sede.address!) : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSelected)
                  Icon(Icons.check_circle,
                      color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Imposta come predefinita',
                  icon: Icon(
                    sede.id == defaultId ? Icons.star : Icons.star_border,
                    color: sede.id == defaultId
                        ? Colors.amber.shade600
                        : theme.colorScheme.onSurface.withAlpha(100),
                  ),
                  onPressed: () => onSetDefault(sede),
                ),
              ],
            ),
            onTap: () => onSelect(sede),
          );
        }),
        if (canAddSede) ...[
          const Divider(height: 1),
          ListTile(
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.secondaryContainer,
              child: Icon(Icons.add, color: theme.colorScheme.secondary, size: 20),
            ),
            title: Text(
              'Nuova sede',
              style: TextStyle(color: theme.colorScheme.secondary),
            ),
            onTap: onAddSede,
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }
}
