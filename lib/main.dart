import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/config/supabase_config.dart';
import 'core/providers/theme_provider.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/providers/auth_provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Future.wait([
    initializeDateFormatting('it_IT'),
    Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    ),
  ]);

  await SentryFlutter.init(
    (options) {
      options.dsn =
          'https://a2c2696c35f25ff0f7e8b0197712a92f@o4511285544026112.ingest.de.sentry.io/4511285546975312';
      options.sendDefaultPii = true;
      options.tracesSampleRate = 0.2;
      options.profilesSampleRate = 0.1;
    },
    appRunner: () =>
        runApp(SentryWidget(child: const ProviderScope(child: StudioApp()))),
  );
}

class StudioApp extends ConsumerWidget {
  const StudioApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    ref.listen(currentUserProvider, (_, user) {
      if (user != null) {
        Sentry.configureScope(
          (scope) => scope.setUser(SentryUser(id: user.id, email: user.email)),
        );
      } else {
        Sentry.configureScope((scope) => scope.setUser(null));
      }
    });

    return MaterialApp.router(
      title: 'Studio',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeModeProvider),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
