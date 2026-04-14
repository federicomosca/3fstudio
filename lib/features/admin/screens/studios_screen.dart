import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/widgets/coming_soon.dart';

final _studiosProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final data = await client.from('studios').select('id, name, address').order('name');
  return (data as List).cast<Map<String, dynamic>>();
});

class StudiosScreen extends ConsumerWidget {
  const StudiosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studios = ref.watch(_studiosProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Studios')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Creazione studio — coming soon')),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Nuovo studio'),
      ),
      body: studios.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e', style: const TextStyle(color: Colors.red))),
        data: (list) => list.isEmpty
            ? const ComingSoon(
                title: 'Nessuno studio',
                icon: Icons.store_outlined,
                subtitle: 'Crea il primo studio con il pulsante +',
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                separatorBuilder: (context, i) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final s = list[i];
                  return ListTile(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    tileColor: Theme.of(context).colorScheme.surface,
                    leading: const CircleAvatar(child: Icon(Icons.store)),
                    title: Text(s['name'] as String),
                    subtitle: Text(s['address'] as String? ?? ''),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {},
                  );
                },
              ),
      ),
    );
  }
}
