import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

    return Scaffold(
      appBar: AppBar(title: const Text('Notifiche')),
      body: notifsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(
            child: Text('Errore: $e',
                style: const TextStyle(color: Colors.red))),
        data: (list) => list.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.notifications_none_outlined,
                        size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text('Nessuna notifica',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface.withAlpha(180))),
                    const SizedBox(height: 8),
                    Text(
                      'Le comunicazioni di Vicio\nappaiono qui.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.grey.shade400, fontSize: 13),
                    ),
                  ],
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                separatorBuilder: (context, i) =>
                    const SizedBox(height: 8),
                itemBuilder: (context, i) =>
                    _NotifCard(notif: list[i]),
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
    final title    = notif['title'] as String;
    final body     = notif['body']  as String?;
    final createdAt = notif['created_at'] as String?;
    final author   = (notif['users'] as Map<String, dynamic>?)?['full_name']
        as String?;

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
                width: 8, height: 8,
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
                    color: Theme.of(context).colorScheme.onSurface.withAlpha(180), height: 1.5)),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              if (author != null) ...[
                Icon(Icons.person_outline,
                    size: 12, color: Colors.grey.shade400),
                const SizedBox(width: 4),
                Text(author,
                    style: TextStyle(
                        color: Colors.grey.shade400, fontSize: 11)),
                const SizedBox(width: 12),
              ],
              if (dt != null) ...[
                Icon(Icons.schedule, size: 12, color: Colors.grey.shade400),
                const SizedBox(width: 4),
                Text(
                  DateFormat('d MMM, HH:mm', 'it_IT').format(dt),
                  style: TextStyle(
                      color: Colors.grey.shade400, fontSize: 11),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
