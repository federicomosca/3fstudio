import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../features/auth/providers/auth_provider.dart';
import '../../../core/providers/studio_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/pricing_provider.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _studioPlansProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
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

final _studioCoursesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final studioId = ref.watch(currentStudioIdProvider);
  if (studioId == null) return [];
  final client = ref.watch(supabaseClientProvider);
  final data = await client
      .from('courses')
      .select('id, name, type, hourly_rate, allows_group, allows_shared, allows_personal')
      .eq('studio_id', studioId)
      .order('name');
  return (data as List).cast<Map<String, dynamic>>();
});

final _clientDetailProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, userId) async {
  final client = ref.watch(supabaseClientProvider);
  final data   = await client
      .from('users')
      .select('id, full_name, email, phone, user_plans(id, credits_remaining, expires_at, course_id, status, courses(name), plans(name, type))')
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

  Future<void> _managePlan(
    BuildContext context,
    WidgetRef ref,
    String uid,
    Map<String, dynamic> plan,
    String action,
  ) async {
    final db         = ref.read(supabaseClientProvider);
    final planId     = plan['id'] as String;
    final planName   = (plan['plans'] as Map<String, dynamic>?)?['name'] as String? ?? '—';
    final isSuspended = plan['status'] == 'suspended';

    if (action == 'cancel') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Cancella piano'),
          content: Text(
              'Cancellare "$planName"? Il piano non sarà più visibile.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annulla')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error),
                child: const Text('Cancella')),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
      await db.from('user_plans').update({'status': 'cancelled'}).eq('id', planId);
    } else if (action == 'toggle_suspend') {
      final newStatus = isSuspended ? 'active' : 'suspended';
      await db.from('user_plans').update({'status': newStatus}).eq('id', planId);
    }

    ref.invalidate(_clientDetailProvider(uid));
  }

  void _openAssignPlan(BuildContext context, String uid) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _AssignPlanSheet(userId: uid),
    );
  }

  Future<void> _archiveClient(BuildContext context, WidgetRef ref) async {
    final name     = client['full_name'] as String? ?? '—';
    final studioId = ref.read(currentStudioIdProvider);
    if (studioId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archivia cliente'),
        content: Text(
          'Archiviare $name? Non comparirà più nell\'elenco clienti '
          'ma il suo account rimarrà intatto.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Archivia'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final db = ref.read(supabaseClientProvider);
      await db
          .from('user_studio_roles')
          .update({'is_active': false})
          .eq('user_id', userId)
          .eq('studio_id', studioId);
      if (context.mounted) context.pop();
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
    final bookingsAsync = ref.watch(_clientBookingsProvider(userId));
    final name  = client['full_name'] as String? ?? '—';
    final email = client['email']     as String? ?? '—';
    final phone = client['phone']     as String?;

    final userPlans = (client['user_plans'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .where((p) => p['status'] != 'cancelled')
        .toList();

    return CustomScrollView(
      slivers: [
        // ── SliverAppBar ──────────────────────────────────────────────────
        SliverAppBar(
          expandedHeight: 200,
          pinned: true,
          backgroundColor: AppTheme.charcoal,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.archive_outlined),
              tooltip: 'Archivia cliente',
              onPressed: () => _archiveClient(context, ref),
            ),
          ],
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
                        color: Colors.white,
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

                // Piani
                Row(
                  children: [
                    Expanded(child: _SectionTitle('Piani attivi')),
                    TextButton.icon(
                      onPressed: () => _openAssignPlan(context, userId),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Assegna'),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: AppTheme.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (userPlans.isEmpty)
                  _PlanCard(plan: null, onManage: null)
                else
                  ...userPlans.asMap().entries.map((e) => Padding(
                        padding: EdgeInsets.only(
                            bottom: e.key < userPlans.length - 1 ? 8 : 0),
                        child: _PlanCard(
                          plan: e.value,
                          onManage: (action) =>
                              _managePlan(context, ref, userId, e.value, action),
                        ),
                      )),
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
  final void Function(String action)? onManage;
  const _PlanCard({this.plan, required this.onManage});

  @override
  Widget build(BuildContext context) {
    if (plan == null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.orange.withAlpha(30),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withAlpha(100)),
        ),
        child: Row(children: [
          const Icon(Icons.warning_amber_outlined,
              color: Color(0xFFFFB74D), size: 20),
          const SizedBox(width: 10),
          Text('Nessun piano attivo',
              style: const TextStyle(
                  color: Color(0xFFFFB74D),
                  fontWeight: FontWeight.w600)),
        ]),
      );
    }

    final planData    = plan!['plans'] as Map<String, dynamic>?;
    final planName    = planData?['name'] as String? ?? '—';
    final planType    = planData?['type'] as String? ?? '';
    final credits     = plan!['credits_remaining'] as int?;
    final expiresAt   = plan!['expires_at'] as String?;
    final courseData  = plan!['courses'] as Map<String, dynamic>?;
    final courseName  = courseData?['name'] as String?;
    final planStatus  = plan!['status'] as String? ?? 'active';
    final isSuspended = planStatus == 'suspended';

    DateTime? expDate;
    if (expiresAt != null) expDate = DateTime.tryParse(expiresAt);

    final isExpiringSoon = !isSuspended &&
        expDate != null &&
        expDate.isBefore(DateTime.now().add(const Duration(days: 7)));
    final isLowCredits = !isSuspended &&
        planType == 'credits' &&
        credits != null &&
        credits <= 2;
    final isWarning = isExpiringSoon || isLowCredits;

    final borderColor = isSuspended
        ? Theme.of(context).colorScheme.outline
        : isWarning
            ? Colors.orange.withAlpha(100)
            : Theme.of(context).colorScheme.outline;
    final bgColor = isSuspended
        ? Theme.of(context).colorScheme.surface
        : isWarning
            ? Colors.orange.withAlpha(30)
            : Theme.of(context).colorScheme.surface;

    return Opacity(
      opacity: isSuspended ? 0.5 : 1.0,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Row(children: [
          Icon(Icons.card_membership_outlined,
              color: isSuspended
                  ? Theme.of(context).colorScheme.onSurface.withAlpha(100)
                  : isWarning
                      ? const Color(0xFFFFB74D)
                      : Theme.of(context).colorScheme.onSurface.withAlpha(180),
              size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(planName,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  if (isSuspended)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.withAlpha(30),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('Sospeso',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFFFB74D))),
                    ),
                ]),
                const SizedBox(height: 2),
                _ScopeChip(courseName: courseName),
                if (planType == 'credits' && credits != null)
                  Text('$credits crediti rimanenti',
                      style: TextStyle(
                          color: isLowCredits
                              ? const Color(0xFFFFB74D)
                              : Theme.of(context).colorScheme.onSurface.withAlpha(180),
                          fontSize: 13)),
                if (expDate != null)
                  Text(
                    'Scade il ${DateFormat('d MMM yyyy', 'it_IT').format(expDate)}',
                    style: TextStyle(
                        color: isExpiringSoon
                            ? const Color(0xFFFFB74D)
                            : Theme.of(context).colorScheme.onSurface.withAlpha(180),
                        fontSize: 13),
                  ),
              ],
            ),
          ),
          if (onManage != null)
            PopupMenuButton<String>(
              color: Theme.of(context).colorScheme.surface,
              onSelected: onManage!,
              icon: Icon(Icons.more_vert,
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(150),
                  size: 20),
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  value: 'toggle_suspend',
                  child: Row(children: [
                    Icon(
                      isSuspended
                          ? Icons.play_circle_outline
                          : Icons.pause_circle_outline,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Text(isSuspended ? 'Riattiva' : 'Sospendi'),
                  ]),
                ),
                PopupMenuItem(
                  value: 'cancel',
                  child: Row(children: [
                    Icon(Icons.cancel_outlined,
                        size: 18,
                        color: Theme.of(context).colorScheme.error),
                    const SizedBox(width: 10),
                    Text('Cancella',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  ]),
                ),
              ],
            ),
        ]),
      ),
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
    final status   = booking['status'] as String? ?? 'confirmed';

    DateTime? dt;
    if (startsAt != null) dt = DateTime.tryParse(startsAt)?.toLocal();

    final isPast = dt != null && dt.isBefore(DateTime.now());

    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    final cs = Theme.of(context).colorScheme;
    switch (status) {
      case 'attended':
        statusColor = const Color(0xFF66BB6A);
        statusLabel = 'Presente';
        statusIcon  = Icons.check_circle_outline;
        break;
      case 'no_show':
        statusColor = const Color(0xFFEF5350);
        statusLabel = 'Assente';
        statusIcon  = Icons.cancel_outlined;
        break;
      default:
        statusColor = isPast ? cs.onSurface.withAlpha(150) : AppTheme.blue;
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

// ── Scope chip ────────────────────────────────────────────────────────────────

class _ScopeChip extends StatelessWidget {
  final String? courseName;
  const _ScopeChip({this.courseName});

  @override
  Widget build(BuildContext context) {
    final label = courseName ?? 'Aperto';
    final color = courseName != null ? AppTheme.cyan : AppTheme.blue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            courseName != null ? Icons.lock_outline : Icons.all_inclusive,
            size: 11,
            color: color,
          ),
          const SizedBox(width: 3),
          Text(label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

// ── Assign plan sheet ─────────────────────────────────────────────────────────

class _AssignPlanSheet extends ConsumerStatefulWidget {
  final String userId;
  const _AssignPlanSheet({required this.userId});

  @override
  ConsumerState<_AssignPlanSheet> createState() => _AssignPlanSheetState();
}

class _AssignPlanSheetState extends ConsumerState<_AssignPlanSheet> {
  String? _selectedPlanId;
  String? _courseId;
  String  _formula              = 'group';
  bool    _saving               = false;
  bool    _infiniteSessions     = false;
  final   _sessionsCtrl         = TextEditingController(text: '3');
  final   _discountCtrl         = TextEditingController(text: '0');

  @override
  void dispose() {
    _sessionsCtrl.dispose();
    _discountCtrl.dispose();
    super.dispose();
  }

  int get _effectiveSessions =>
      _infiniteSessions ? 6 : (int.tryParse(_sessionsCtrl.text) ?? 3).clamp(1, 99);

  void _onCourseChanged(
    String? v,
    List<Map<String, dynamic>> courses,
    List<Map<String, dynamic>> activePlans,
    Map<String, dynamic>? pricing,
  ) {
    final course = v != null
        ? courses.where((c) => c['id'] == v).firstOrNull
        : null;

    // Reset formula to first allowed by new course
    String newFormula = _formula;
    if (course != null) {
      final ag = course['allows_group']    as bool? ?? true;
      final as_ = course['allows_shared']  as bool? ?? false;
      final ap = course['allows_personal'] as bool? ?? false;
      final currentOk = (_formula == 'group' && ag) ||
          (_formula == 'shared' && as_) ||
          (_formula == 'personal' && ap);
      if (!currentOk) {
        newFormula = ag ? 'group' : (as_ ? 'shared' : 'personal');
      }
    }

    // Auto-fill discount on each course change
    final hasOther = activePlans.any((p) =>
        p['course_id'] != null && p['course_id'] != v);
    final studioDiscount = pricing != null
        ? (pricing['second_course_discount_pct'] as num?)?.toDouble() ?? 0.0
        : 0.0;

    setState(() {
      _courseId          = v;
      _formula           = newFormula;
      _discountCtrl.text =
          (hasOther ? studioDiscount : 0.0).toStringAsFixed(0);
    });
  }

  Future<void> _save(
    List<Map<String, dynamic>> plans,
    List<Map<String, dynamic>> courses,
    Map<String, dynamic>? pricing,
  ) async {
    if (_selectedPlanId == null || _courseId == null) return;

    final plan = plans.firstWhere((p) => p['id'] == _selectedPlanId,
        orElse: () => {});
    if (plan.isEmpty) return;

    final selectedCourse =
        courses.where((c) => c['id'] == _courseId).firstOrNull;
    if (selectedCourse == null) return;

    final rate = pricing != null
        ? calcCourseRate(selectedCourse, pricing, formulaOverride: _formula)
        : null;

    final discountPct  = double.tryParse(_discountCtrl.text.trim()) ?? 0.0;
    final discountMult = 1 - discountPct / 100;

    final planType = plan['type'] as String? ?? 'credits';
    final credits  = plan['credits'] as int?;
    final duration = plan['duration_days'] as int?;

    double? basePrice;
    if (rate != null) {
      if (planType == 'unlimited' && duration != null) {
        basePrice = rate * _effectiveSessions * (duration / 7);
      } else if (credits != null) {
        basePrice = rate * credits;
      }
    }
    final pricePaid = basePrice != null ? basePrice * discountMult : null;

    setState(() => _saving = true);
    try {
      final db  = ref.read(supabaseClientProvider);
      final now = DateTime.now().toUtc();

      await db.from('user_plans').insert({
        'user_id':           widget.userId,
        'plan_id':           _selectedPlanId,
        'course_id':         _courseId,
        'credits_remaining': planType == 'credits' ? credits : null,
        'expires_at':        duration != null
            ? now.add(Duration(days: duration)).toIso8601String()
            : null,
        'formula':           _formula,
        'rate_snapshot':     rate,
        'price_paid':        pricePaid,
      });

      ref.invalidate(_clientDetailProvider(widget.userId));
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
    final cs           = Theme.of(context).colorScheme;
    final plansAsync   = ref.watch(_studioPlansProvider);
    final coursesAsync = ref.watch(_studioCoursesProvider);
    final pricingAsync = ref.watch(studioPricingProvider);
    final clientAsync  = ref.watch(_clientDetailProvider(widget.userId));

    final pricing = pricingAsync.whenOrNull(data: (p) => p);
    final activePlans = clientAsync.whenOrNull(data: (d) =>
        (d?['user_plans'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .where((p) => p['status'] != 'cancelled')
        .toList()) ?? [];

    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: cs.outline, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Assegna piano',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 20),

          plansAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Errore: $e', style: TextStyle(color: cs.error)),
            data: (plans) => coursesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Errore: $e', style: TextStyle(color: cs.error)),
              data: (courses) {
                final selectedCourse = _courseId != null
                    ? courses.where((c) => c['id'] == _courseId).firstOrNull
                    : null;

                final rate = selectedCourse != null && pricing != null
                    ? calcCourseRate(selectedCourse, pricing,
                        formulaOverride: _formula)
                    : null;

                final selectedPlan = _selectedPlanId != null
                    ? plans.where((p) => p['id'] == _selectedPlanId).firstOrNull
                    : null;
                final credits  = selectedPlan?['credits'] as int?;
                final planType = selectedPlan?['type'] as String? ?? '';

                final ag  = selectedCourse?['allows_group']    as bool? ?? true;
                final as_ = selectedCourse?['allows_shared']   as bool? ?? false;
                final ap  = selectedCourse?['allows_personal'] as bool? ?? false;

                final hasHourlyRate = selectedCourse != null &&
                    ((selectedCourse['hourly_rate'] as num?)?.toDouble() ?? 0) > 0;

                final discountPct =
                    double.tryParse(_discountCtrl.text.trim()) ?? 0.0;

                final canSave =
                    _selectedPlanId != null && _courseId != null && !_saving;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Course picker ─────────────────────────────────
                    DropdownButtonFormField<String>(
                      initialValue: _courseId,
                      decoration: const InputDecoration(labelText: 'Corso'),
                      items: courses.map((c) => DropdownMenuItem(
                        value: c['id'] as String,
                        child: Text(c['name'] as String),
                      )).toList(),
                      onChanged: (v) =>
                          _onCourseChanged(v, courses, activePlans, pricing),
                    ),

                    // ── Formula ───────────────────────────────────────
                    if (selectedCourse != null) ...[
                      const SizedBox(height: 14),
                      Text('Modalità',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface.withAlpha(150))),
                      const SizedBox(height: 8),
                      Row(children: [
                        if (ag) ...[
                          _ScopeToggle(
                            label: 'Group',
                            icon: Icons.group_outlined,
                            selected: _formula == 'group',
                            color: AppTheme.blue,
                            onTap: () => setState(() => _formula = 'group'),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (as_) ...[
                          _ScopeToggle(
                            label: 'Shared',
                            icon: Icons.people_outline,
                            selected: _formula == 'shared',
                            color: AppTheme.cyan,
                            onTap: () => setState(() => _formula = 'shared'),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (ap)
                          _ScopeToggle(
                            label: 'Personal',
                            icon: Icons.person_outline,
                            selected: _formula == 'personal',
                            color: Colors.deepPurple.shade300,
                            onTap: () =>
                                setState(() => _formula = 'personal'),
                          ),
                      ]),
                    ],

                    const SizedBox(height: 14),

                    // ── Plan picker ───────────────────────────────────
                    DropdownButtonFormField<String>(
                      initialValue: _selectedPlanId,
                      decoration: const InputDecoration(labelText: 'Piano'),
                      items: plans.map((p) {
                        final type  = p['type'] as String? ?? '';
                        final creds = p['credits'] as int?;
                        final days  = p['duration_days'] as int?;
                        final typeLabel = switch (type) {
                          'unlimited' => 'Illimitato',
                          'trial'     => 'Prova',
                          _ => creds != null ? '$creds lezioni' : 'Crediti',
                        };
                        final daysLabel = days != null ? ' · $days gg' : '';
                        return DropdownMenuItem(
                          value: p['id'] as String,
                          child: Text('${p['name']}  ·  $typeLabel$daysLabel'),
                        );
                      }).toList(),
                      onChanged: (v) =>
                          setState(() => _selectedPlanId = v),
                    ),

                    // ── Frequency (unlimited with duration) ───────────
                    if (planType == 'unlimited' && selectedPlan != null &&
                        (selectedPlan['duration_days'] as int?) != null) ...[
                      const SizedBox(height: 14),
                      Text('Frequenza stimata',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface.withAlpha(150))),
                      const SizedBox(height: 8),
                      Row(children: [
                        SizedBox(
                          width: 80,
                          child: TextField(
                            controller: _sessionsCtrl,
                            enabled: !_infiniteSessions,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: '×/sett.',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 10),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () => setState(
                              () => _infiniteSessions = !_infiniteSessions),
                          child: Row(children: [
                            Checkbox(
                              value: _infiniteSessions,
                              onChanged: (v) => setState(
                                  () => _infiniteSessions = v ?? false),
                            ),
                            const Text('∞  (6×/sett.)'),
                          ]),
                        ),
                      ]),
                    ],

                    // ── Discount ──────────────────────────────────────
                    const SizedBox(height: 14),
                    TextField(
                      controller: _discountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Sconto applicato (%)',
                        prefixIcon: const Icon(Icons.discount_outlined),
                        suffixText: '-%',
                        helperText: activePlans.any((p) =>
                                p['course_id'] != null &&
                                p['course_id'] != _courseId) &&
                            pricing != null
                            ? 'Sconto studio 2° corso: '
                              '${(pricing['second_course_discount_pct'] as num?)?.toStringAsFixed(0) ?? '0'}%'
                            : null,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),

                    // ── Price preview ─────────────────────────────────
                    if (selectedPlan != null && _courseId != null) ...[
                      const SizedBox(height: 14),
                      _PricePreview(
                        rate: rate,
                        credits: planType == 'credits' ? credits : null,
                        courseName: selectedCourse?['name'] as String?,
                        formula: _formula,
                        hasHourlyRate: hasHourlyRate,
                        sessionsPerWeek: planType == 'unlimited'
                            ? _effectiveSessions
                            : null,
                        durationDays: planType == 'unlimited'
                            ? (selectedPlan['duration_days'] as int?)
                            : null,
                        discountPct: discountPct,
                      ),
                    ],

                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: canSave
                            ? () => _save(plans, courses, pricing)
                            : null,
                        child: _saving
                            ? const SizedBox(
                                height: 20, width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Text('Attiva piano'),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Price preview ─────────────────────────────────────────────────────────────

class _PricePreview extends StatelessWidget {
  final double? rate;
  final int? credits;
  final String? courseName;
  final String formula;
  final bool hasHourlyRate;
  final int? sessionsPerWeek;
  final int? durationDays;
  final double discountPct;

  const _PricePreview({
    this.rate,
    this.credits,
    this.courseName,
    required this.formula,
    required this.hasHourlyRate,
    this.sessionsPerWeek,
    this.durationDays,
    this.discountPct = 0,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (!hasHourlyRate) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.withAlpha(30),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.orange.withAlpha(100)),
        ),
        child: Row(children: [
          const Icon(Icons.info_outline, color: Color(0xFFFFB74D), size: 16),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Imposta la tariffa base del corso per il calcolo automatico del prezzo.',
              style: TextStyle(fontSize: 12, color: Color(0xFFFFB74D)),
            ),
          ),
        ]),
      );
    }

    if (rate == null) return const SizedBox.shrink();

    final isUnlimited = sessionsPerWeek != null && durationDays != null;
    final baseTotal = isUnlimited
        ? rate! * sessionsPerWeek! * (durationDays! / 7)
        : (credits != null ? rate! * credits! : null);

    final hasDiscount = discountPct > 0 && baseTotal != null;
    final finalTotal =
        hasDiscount ? baseTotal * (1 - discountPct / 100) : baseTotal;

    final formulaLabel = switch (formula) {
      'personal' => 'Personal',
      'shared'   => 'Shared',
      _          => 'Group',
    };
    final scope = '${courseName ?? 'Corso'} · $formulaLabel';

    final detailLine = isUnlimited
        ? '€${rate!.toStringAsFixed(2)}/lezione  ×  '
          '$sessionsPerWeek×/sett.  ×  '
          '${(durationDays! / 7).toStringAsFixed(1)} sett.'
        : '€${rate!.toStringAsFixed(2)}/lezione'
          '${credits != null ? ' × $credits lezioni' : ''}';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.blue.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.blue.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.euro_outlined, size: 14, color: AppTheme.blue),
            const SizedBox(width: 6),
            Text('Prezzo stimato · $scope',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.blue)),
          ]),
          const SizedBox(height: 6),
          Text(detailLine,
              style: TextStyle(fontSize: 13, color: cs.onSurface.withAlpha(200))),
          if (baseTotal != null) ...[
            const SizedBox(height: 2),
            if (hasDiscount) ...[
              Text(
                'Subtotale: €${baseTotal.toStringAsFixed(2)}',
                style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurface.withAlpha(150),
                    decoration: TextDecoration.lineThrough),
              ),
              Text(
                'Sconto ${discountPct.toStringAsFixed(0)}%: '
                '−€${(baseTotal - finalTotal!).toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 13, color: AppTheme.cyan),
              ),
            ],
            Text(
              'Totale: €${(finalTotal ?? baseTotal).toStringAsFixed(2)}',
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.blue),
            ),
          ],
        ],
      ),
    );
  }
}

class _ScopeToggle extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _ScopeToggle({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? color.withAlpha(40) : cs.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? color : cs.outline,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  size: 20,
                  color: selected ? color : cs.onSurface.withAlpha(120)),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: selected ? color : cs.onSurface.withAlpha(150))),
            ],
          ),
        ),
      ),
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
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: Theme.of(context).colorScheme.onSurface.withAlpha(180),
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
