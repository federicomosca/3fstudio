import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/providers/studio_provider.dart';
import '../../../features/auth/providers/auth_provider.dart';

// ── Provider ──────────────────────────────────────────────────────────────────
// Richiede la tabella: notifications(id, studio_id, title, body, created_at, created_by)
// SQL da eseguire su Supabase:
//   CREATE TABLE notifications (
//     id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
//     studio_id uuid REFERENCES studios(id),
//     title text NOT NULL,
//     body text,
//     created_at timestamptz DEFAULT now(),
//     created_by uuid REFERENCES users(id)
//   );
//   ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
//   CREATE POLICY "users see own studio notifs"
//     ON notifications FOR SELECT
//     USING (studio_id IN (
//       SELECT studio_id FROM user_studio_roles WHERE user_id = auth.uid()
//     ));
//   CREATE POLICY "owners can send notifications"
//     ON notifications FOR INSERT
//     WITH CHECK (studio_id IN (
//       SELECT studio_id FROM user_studio_roles
//       WHERE user_id = auth.uid() AND role = 'owner'
//     ));

final _notificationsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final studioId = ref.watch(currentStudioIdProvider);
  if (studioId == null) return [];
  final client = ref.watch(supabaseClientProvider);

  try {
    final data = await client
        .from('notifications')
        .select('id, title, body, created_at, users!created_by(full_name)')
        .eq('studio_id', studioId)
        .order('created_at', ascending: false)
        .limit(50);
    return (data as List).cast<Map<String, dynamic>>();
  } catch (_) {
    // Tabella non ancora creata
    return [];
  }
});

// ── Screen ────────────────────────────────────────────────────────────────────

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifsAsync = ref.watch(_notificationsProvider);
    final loc         = GoRouterState.of(context).uri.path;
    final isOwner     = loc.startsWith('/owner');

    return Scaffold(
      appBar: AppBar(title: const Text('Notifiche')),
      floatingActionButton: isOwner
          ? FloatingActionButton.extended(
              onPressed: () => _openSendSheet(context, ref),
              icon: const Icon(Icons.send_outlined),
              label: const Text('Invia comunicazione'),
            )
          : null,
      body: notifsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text('Errore: $e',
                style: const TextStyle(color: Colors.red))),
        data: (list) => list.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.notifications_none_outlined,
                        size: 64,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withAlpha(60)),
                    const SizedBox(height: 16),
                    Text('Nessuna notifica',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withAlpha(180))),
                    const SizedBox(height: 8),
                    Text(
                      isOwner
                          ? 'Usa il pulsante in basso per\ninviare una comunicazione.'
                          : 'Le comunicazioni di Vicio\nappaiono qui.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withAlpha(150),
                          fontSize: 13),
                    ),
                  ],
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: list.length,
                separatorBuilder: (context, i) => const SizedBox(height: 8),
                itemBuilder: (context, i) => _NotifCard(notif: list[i]),
              ),
      ),
    );
  }

  void _openSendSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _SendNotifSheet(
        onSent: () => ref.invalidate(_notificationsProvider),
      ),
    );
  }
}

// ── Send sheet ────────────────────────────────────────────────────────────────

class _SendNotifSheet extends ConsumerStatefulWidget {
  final VoidCallback onSent;
  const _SendNotifSheet({required this.onSent});

  @override
  ConsumerState<_SendNotifSheet> createState() => _SendNotifSheetState();
}

class _SendNotifSheetState extends ConsumerState<_SendNotifSheet> {
  final _formKey  = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _bodyCtrl  = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _sending = true);

    final studioId = ref.read(currentStudioIdProvider);
    final user     = ref.read(currentUserProvider);
    final client   = ref.read(supabaseClientProvider);

    try {
      await client.from('notifications').insert({
        'studio_id':  studioId,
        'title':      _titleCtrl.text.trim(),
        'body':       _bodyCtrl.text.trim().isEmpty
            ? null
            : _bodyCtrl.text.trim(),
        'created_by': user?.id,
      });

      widget.onSent();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Errore: $e'),
              backgroundColor: Colors.red),
        );
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 20, 16, 24 + bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            Text(
              'Nuova comunicazione',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 20),

            // Title field
            TextFormField(
              controller: _titleCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Titolo *',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Il titolo è obbligatorio' : null,
            ),
            const SizedBox(height: 14),

            // Body field
            TextFormField(
              controller: _bodyCtrl,
              minLines: 3,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Messaggio (opzionale)',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 20),

            // Send button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _sending ? null : _send,
                icon: _sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_outlined),
                label: Text(_sending ? 'Invio...' : 'Invia a tutti i membri'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Notification card ─────────────────────────────────────────────────────────

class _NotifCard extends StatelessWidget {
  final Map<String, dynamic> notif;
  const _NotifCard({required this.notif});

  @override
  Widget build(BuildContext context) {
    final title     = notif['title'] as String;
    final body      = notif['body'] as String?;
    final createdAt = notif['created_at'] as String?;
    final author    =
        (notif['users'] as Map<String, dynamic>?)?['full_name'] as String?;

    DateTime? dt;
    if (createdAt != null) dt = DateTime.tryParse(createdAt)?.toLocal();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppTheme.lime,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          if (body != null && body.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(body,
                style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withAlpha(180),
                    height: 1.5)),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              if (author != null) ...[
                Icon(Icons.person_outline,
                    size: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withAlpha(130)),
                const SizedBox(width: 4),
                Text(author,
                    style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withAlpha(130),
                        fontSize: 11)),
                const SizedBox(width: 12),
              ],
              if (dt != null) ...[
                Icon(Icons.schedule,
                    size: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withAlpha(130)),
                const SizedBox(width: 4),
                Text(
                  DateFormat('d MMM, HH:mm', 'it_IT').format(dt),
                  style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withAlpha(130),
                      fontSize: 11),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
