import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/widgets/coming_soon.dart';

final _globalUsersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final data = await client.from('users').select('id, email, full_name, is_admin').order('full_name');
  return (data as List).cast<Map<String, dynamic>>();
});

class GlobalUsersScreen extends ConsumerWidget {
  const GlobalUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(_globalUsersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Utenti globali')),
      body: users.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text('Errore: $e', style: const TextStyle(color: Colors.red))),
        data: (list) => list.isEmpty
            ? const ComingSoon(
                title: 'Nessun utente',
                icon: Icons.people_outline,
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                separatorBuilder: (context, i) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final u = list[i];
                  final name = u['full_name'] as String? ?? u['email'] as String;
                  final isAdmin = (u['is_admin'] as bool?) ?? false;
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?'),
                    ),
                    title: Text(name),
                    subtitle: Text(u['email'] as String? ?? ''),
                    trailing: isAdmin
                        ? Chip(
                            label: const Text('admin',
                                style: TextStyle(fontSize: 11)),
                            backgroundColor:
                                Theme.of(context).colorScheme.primaryContainer,
                            padding: EdgeInsets.zero,
                          )
                        : null,
                  );
                },
              ),
      ),
    );
  }
}
