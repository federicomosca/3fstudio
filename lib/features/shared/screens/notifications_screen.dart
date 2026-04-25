import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/providers/studio_provider.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../providers/notifications_provider.dart';

// ── Screen ────────────────────────────────────────────────────────────────────

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _markSeen());
  }

  Future<void> _markSeen() async {
    final user   = ref.read(currentUserProvider);
    final client = ref.read(supabaseClientProvider);
    if (user == null) return;
    try {
      await client.from('users').update({
        'notifications_seen_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', user.id);
      ref.invalidate(notificationsSeenAtProvider);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final notifsAsync = ref.watch(notificationsProvider);
    final loc         = GoRouterState.of(context).uri.path;
    final isOwner     = loc.startsWith('/owner');

    return Scaffold(
      appBar: AppBar(title: const Text('Notifiche')),
      floatingActionButton: isOwner
          ? FloatingActionButton.extended(
              onPressed: () => _openSendSheet(context),
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

  void _openSendSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => const _SendNotifSheet(),
    );
  }
}

// ── Send sheet ────────────────────────────────────────────────────────────────

class _SendNotifSheet extends ConsumerStatefulWidget {
  const _SendNotifSheet();

  @override
  ConsumerState<_SendNotifSheet> createState() => _SendNotifSheetState();
}

class _SendNotifSheetState extends ConsumerState<_SendNotifSheet> {
  final _formKey   = GlobalKey<FormState>();
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

class _NotifCard extends ConsumerWidget {
  final Map<String, dynamic> notif;
  const _NotifCard({required this.notif});

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final id     = notif['id'] as String;
    final client = ref.read(supabaseClientProvider);
    try {
      await client.from('notifications').delete().eq('id', id);
      ref.invalidate(notificationsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                iconSize: 18,
                icon: Icon(
                  Icons.delete_outline,
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(100),
                ),
                onPressed: () => _delete(context, ref),
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
