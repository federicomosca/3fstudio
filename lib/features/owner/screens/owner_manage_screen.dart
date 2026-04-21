import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/floating_nav_item.dart';
import '../providers/plan_requests_provider.dart';
import 'rooms_screen.dart';
import 'studios_screen.dart';
import 'team_screen.dart';
import 'plans_screen.dart';
import 'report_screen.dart';
import 'pricing_settings_screen.dart';

class OwnerManageScreen extends ConsumerStatefulWidget {
  const OwnerManageScreen({super.key});

  @override
  ConsumerState<OwnerManageScreen> createState() => _OwnerManageScreenState();
}

class _OwnerManageScreenState extends ConsumerState<OwnerManageScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 6, vsync: this);
    _tab.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = ref.watch(pendingPlanRequestsCountProvider)
            .whenOrNull(data: (n) => n) ??
        0;
    final sel = _tab.index;

    return Scaffold(
      appBar: AppBar(title: const Text('Gestione')),
      body: Column(
        children: [
          // Pill nav scrollabile
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.navy,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(130),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    FloatingNavItem(
                      icon: Icon(
                        sel == 0 ? Icons.meeting_room : Icons.meeting_room_outlined,
                        color: sel == 0 ? Colors.white : Colors.white54,
                        size: 20,
                      ),
                      label: 'Spazi',
                      selected: sel == 0,
                      onTap: () => _tab.animateTo(0),
                    ),
                    FloatingNavItem(
                      icon: Icon(
                        sel == 1 ? Icons.group : Icons.group_outlined,
                        color: sel == 1 ? Colors.white : Colors.white54,
                        size: 20,
                      ),
                      label: 'Team',
                      selected: sel == 1,
                      onTap: () => _tab.animateTo(1),
                    ),
                    FloatingNavItem(
                      icon: Badge(
                        isLabelVisible: pendingCount > 0,
                        label: Text('$pendingCount'),
                        child: Icon(
                          sel == 2
                              ? Icons.card_membership
                              : Icons.card_membership_outlined,
                          color: sel == 2 ? Colors.white : Colors.white54,
                          size: 20,
                        ),
                      ),
                      label: 'Piani',
                      selected: sel == 2,
                      onTap: () => _tab.animateTo(2),
                    ),
                    FloatingNavItem(
                      icon: Icon(
                        sel == 3 ? Icons.location_city : Icons.location_city_outlined,
                        color: sel == 3 ? Colors.white : Colors.white54,
                        size: 20,
                      ),
                      label: 'Sedi',
                      selected: sel == 3,
                      onTap: () => _tab.animateTo(3),
                    ),
                    FloatingNavItem(
                      icon: Icon(
                        sel == 4 ? Icons.bar_chart : Icons.bar_chart_outlined,
                        color: sel == 4 ? Colors.white : Colors.white54,
                        size: 20,
                      ),
                      label: 'Report',
                      selected: sel == 4,
                      onTap: () => _tab.animateTo(4),
                    ),
                    FloatingNavItem(
                      icon: Icon(
                        sel == 5 ? Icons.percent : Icons.percent_outlined,
                        color: sel == 5 ? Colors.white : Colors.white54,
                        size: 20,
                      ),
                      label: 'Tariffe',
                      selected: sel == 5,
                      onTap: () => _tab.animateTo(5),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tab,
              children: const [
                RoomsScreen(hideAppBar: true),
                TeamScreen(hideAppBar: true),
                PlansScreen(hideAppBar: true),
                StudiosScreen(hideAppBar: true),
                ReportScreen(hideAppBar: true),
                PricingSettingsScreen(hideAppBar: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
