import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../features/auth/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _clientDetailProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, userId) async {
  final client = ref.watch(supabaseClientProvider);
  final data   = await client
      .from('users')
      .select('id, full_name, email, phone, user_plans(id, credits_remaining, expires_at, plans(name, type))')
      .eq('id', userId)
      .maybeSingle();
  return data;
});

final _clientBookingsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, userId) async {
  final client = ref.watch(supabaseClientProvider);
  final data   = await client
      .from('bookings')
      .select('id, status, created_at, lessons(starts_at, ends_at, courses(name))')
      .eq('user_id', userId)
      .neq('status', 'cancelled')
      .order('created_at', ascending: false)
      .limit(30);
  return (data as List).cast<Map<String, dynamic>>();
});

// ── Screen ────────────────────────────────────────────────────────────────────

class ClientDetailScreen extends ConsumerWidget {
  final String userId;
  const ClientDetailScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientAsync = ref.watch(_clientDetailProvider(userId));

    return Scaffold(
      body: clientAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(
            child: Text('Errore: $e',
                style: const TextStyle(color: Colors.red))),
        data: (client) => client == null
            ? const Center(child: Text('Cliente non trovato'))
            : _ClientBody(userId: userId, client: client),
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _ClientBody extends ConsumerWidget {
  final String userId;
  final Map<String, dynamic> client;
  const _ClientBody({required this.userId, required this.client});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(_clientBookingsProvider(userId));
    final name  = client['full_name'] as String? ?? '—';
    final email = client['email']     as String? ?? '—';
    final phone = client['phone']     as String?;

    final userPlans = client['user_plans'] as List?;
    final plan      = userPlans?.isNotEmpty == true
        ? userPlans!.first as Map<String, dynamic>
        : null;

    return CustomScrollView(
      slivers: [
        // ── SliverAppBar ──────────────────────────────────────────────────
        SliverAppBar(
          expandedHeight: 200,
          pinned: true,
          backgroundColor: AppTheme.charcoal,
          foregroundColor: Colors.white,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              color: AppTheme.charcoal,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 60),
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: AppTheme.lime,
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: AppTheme.charcoal,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      )),
                ],
              ),
            ),
          ),
        ),

        // ── Content ───────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // Contatti
                _SectionTitle('Contatti'),
                const SizedBox(height: 8),
                _InfoCard(children: [
                  _InfoRow(icon: Icons.email_outlined, text: email),
                  if (phone != null)
                    _InfoRow(icon: Icons.phone_outlined, text: phone),
                ]),
                const SizedBox(height: 20),

                // Piano
                _SectionTitle('Piano attivo'),
                const SizedBox(height: 8),
                _PlanCard(plan: plan),
                const SizedBox(height: 20),

                // Prenotazioni
                _SectionTitle('Prenotazioni recenti'),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),

        // ── Bookings ──────────────────────────────────────────────────────
        bookingsAsync.when(
          loading: () => const SliverToBoxAdapter(
              child: Center(child: CircularProgressIndicator())),
          error: (e, _) => SliverToBoxAdapter(
              child: Text('Errore: $e',
                  style: const TextStyle(color: Colors.red))),
          data: (bookings) => bookings.isEmpty
              ? SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text('Nessuna prenotazione',
                          style:
                              TextStyle(color: Theme.of(context).colorScheme.onSurface.withAlpha(150))),
                    ),
                  ),
                )
              : SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  sliver: SliverList.separated(
                    itemCount: bookings.length,
                    separatorBuilder: (context, i) => const SizedBox(height: 8),
                    itemBuilder: (context, i) =>
                        _BookingRow(booking: bookings[i]),
                  ),
                ),
        ),
      ],
    );
  }
}

// ── Plan card ─────────────────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  final Map<String, dynamic>? plan;
  const _PlanCard({this.plan});

  @override
  Widget build(BuildContext context) {
    if (plan == null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Row(children: [
          Icon(Icons.warning_amber_outlined,
              color: Colors.orange.shade700, size: 20),
          const SizedBox(width: 10),
          Text('Nessun piano attivo',
              style: TextStyle(
                  color: Colors.orange.shade700,
                  fontWeight: FontWeight.w600)),
        ]),
      );
    }

    final planData   = plan!['plans'] as Map<String, dynamic>?;
    final planName   = planData?['name'] as String? ?? '—';
    final planType   = planData?['type'] as String? ?? '';
    final credits    = plan!['credits_remaining'] as int?;
    final expiresAt  = plan!['expires_at'] as String?;

    DateTime? expDate;
    if (expiresAt != null) expDate = DateTime.tryParse(expiresAt);

    final isExpiringSoon = expDate != null &&
        expDate.isBefore(DateTime.now().add(const Duration(days: 7)));
    final isLowCredits =
        planType == 'credits' && credits != null && credits <= 2;
    final isWarning = isExpiringSoon || isLowCredits;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isWarning ? Colors.orange.shade50 : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isWarning
                ? Colors.orange.shade200
                : Theme.of(context).colorScheme.outline),
      ),
      child: Row(children: [
        Icon(Icons.card_membership_outlined,
            color:
                isWarning ? Colors.orange.shade700 : AppTheme.charcoal,
            size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(planName,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              if (planType == 'credits' && credits != null)
                Text('$credits crediti rimanenti',
                    style: TextStyle(
                        color: isLowCredits
                            ? Colors.orange.shade700
                            : Theme.of(context).colorScheme.onSurface.withAlpha(180),
                        fontSize: 13)),
              if (expDate != null)
                Text(
                  'Scade il ${DateFormat('d MMM yyyy', 'it_IT').format(expDate)}',
                  style: TextStyle(
                      color: isExpiringSoon
                          ? Colors.orange.shade700
                          : Theme.of(context).colorScheme.onSurface.withAlpha(180),
                      fontSize: 13),
                ),
            ],
          ),
        ),
      ]),
    );
  }
}

// ── Booking row ───────────────────────────────────────────────────────────────

class _BookingRow extends StatelessWidget {
  final Map<String, dynamic> booking;
  const _BookingRow({required this.booking});

  @override
  Widget build(BuildContext context) {
    final lesson   = booking['lessons'] as Map<String, dynamic>?;
    final course   = lesson?['courses'] as Map<String, dynamic>?;
    final name     = course?['name'] as String? ?? '—';
    final startsAt = lesson?['starts_at'] as String?;
    final status   = booking['status'] as String? ?? 'booked';

    DateTime? dt;
    if (startsAt != null) dt = DateTime.tryParse(startsAt)?.toLocal();

    final isPast = dt != null && dt.isBefore(DateTime.now());

    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    switch (status) {
      case 'attended':
        statusColor = Colors.green.shade600;
        statusLabel = 'Presente';
        statusIcon  = Icons.check_circle_outline;
        break;
      case 'no_show':
        statusColor = Colors.red.shade600;
        statusLabel = 'Assente';
        statusIcon  = Icons.cancel_outlined;
        break;
      default:
        statusColor = isPast ? Colors.grey.shade500 : Colors.blue.shade600;
        statusLabel = isPast ? 'Completata' : 'Prenotata';
        statusIcon  = isPast ? Icons.history : Icons.event_available_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              if (dt != null)
                Text(
                  DateFormat('EEE d MMM, HH:mm', 'it_IT').format(dt),
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withAlpha(180), fontSize: 13),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(statusIcon, size: 14, color: statusColor),
            const SizedBox(width: 4),
            Text(statusLabel,
                style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ]),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: AppTheme.charcoal,
          letterSpacing: 0.5,
        ));
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.onSurface.withAlpha(150)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: const TextStyle(fontSize: 14)),
        ),
      ]),
    );
  }
}
