import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/plan_requests_provider.dart';
import 'rooms_screen.dart';
import 'studios_screen.dart';
import 'team_screen.dart';
import 'plans_screen.dart';
import 'report_screen.dart';
import 'pricing_settings_screen.dart';

class OwnerManageScreen extends ConsumerWidget {
  const OwnerManageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingCount = ref.watch(pendingPlanRequestsCountProvider)
        .whenOrNull(data: (n) => n) ?? 0;

    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Gestione'),
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: const Color(0x99FFFFFF),
            indicatorColor: Colors.white,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              const Tab(icon: Icon(Icons.meeting_room_outlined), text: 'Spazi'),
              const Tab(icon: Icon(Icons.group_outlined), text: 'Team'),
              Tab(
                text: 'Piani',
                icon: Badge(
                  isLabelVisible: pendingCount > 0,
                  label: Text('$pendingCount'),
                  child: const Icon(Icons.card_membership_outlined),
                ),
              ),
              const Tab(icon: Icon(Icons.location_city_outlined), text: 'Sedi'),
              const Tab(icon: Icon(Icons.bar_chart_outlined), text: 'Report'),
              const Tab(icon: Icon(Icons.percent_outlined), text: 'Tariffe'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            RoomsScreen(hideAppBar: true),
            TeamScreen(hideAppBar: true),
            PlansScreen(hideAppBar: true),
            StudiosScreen(hideAppBar: true),
            ReportScreen(hideAppBar: true),
            PricingSettingsScreen(hideAppBar: true),
          ],
        ),
      ),
    );
  }
}
