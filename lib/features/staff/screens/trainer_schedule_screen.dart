import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../features/auth/providers/auth_provider.dart';

final _trainerScheduleProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];

  final client = ref.watch(supabaseClientProvider);
  final now    = DateTime.now().toUtc().toIso8601String();

  final data = await client
      .from('lessons')
      .select('id, starts_at, ends_at, capacity, courses(name, type), bookings(count)')
      .eq('trainer_id', user.id)
      .gte('starts_at', now)
      .order('starts_at')
      .limit(30);

  return (data as List).cast<Map<String, dynamic>>();
});

class TrainerScheduleScreen extends ConsumerWidget {
  const TrainerScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedule = ref.watch(_trainerScheduleProvider);
    final dateFmt  = DateFormat('EEE d MMM', 'it');
    final timeFmt  = DateFormat('HH:mm');

    return Scaffold(
      appBar: AppBar(title: const Text('Il mio orario')),
      body: schedule.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text('Errore: $e', style: const TextStyle(color: Colors.red))),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.event_available,
                      size: 56,
                      color: Theme.of(context).colorScheme.onSurface.withAlpha(60)),
                  const SizedBox(height: 12),
                  Text('Nessuna lezione in programma',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withAlpha(150))),
                ],
              ),
            );
          }

          // Raggruppa per giorno
          final Map<String, List<Map<String, dynamic>>> byDay = {};
          for (final l in list) {
            final dt  = DateTime.parse(l['starts_at'] as String).toLocal();
            final key = DateFormat('yyyy-MM-dd').format(dt);
            byDay.putIfAbsent(key, () => []).add(l);
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: byDay.entries.map((entry) {
              final day = DateTime.parse(entry.key);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      dateFmt.format(day),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withAlpha(180),
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  ...entry.value.map((l) {
                    final course   = l['courses'] as Map<String, dynamic>;
                    final bookings = l['bookings'] as List? ?? [];
                    final count    = bookings.isNotEmpty
                        ? int.tryParse(
                                bookings.first['count'].toString()) ??
                            0
                        : 0;
                    final cap  = l['capacity'] as int;
                    final start = DateTime.parse(l['starts_at'] as String).toLocal();
                    final end   = DateTime.parse(l['ends_at'] as String).toLocal();

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(timeFmt.format(start),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 14)),
                            Text(timeFmt.format(end),
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Theme.of(context).colorScheme.onSurface.withAlpha(150))),
                          ],
                        ),
                        title: Text(course['name'] as String),
                        subtitle: Text('$count/$cap iscritti'),
                        trailing: TextButton(
                          onPressed: () =>
                              context.push('/staff/roster/${l['id']}'),
                          child: const Text('Presenze'),
                        ),
                      ),
                    );
                  }),
                ],
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
