import 'package:flutter/material.dart';

import 'rooms_screen.dart';
import 'studios_screen.dart';
import 'team_screen.dart';
import 'plans_screen.dart';
import 'report_screen.dart';

class OwnerManageScreen extends StatelessWidget {
  const OwnerManageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Gestione'),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Color(0x99FFFFFF),
            indicatorColor: Colors.white,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(icon: Icon(Icons.meeting_room_outlined), text: 'Spazi'),
              Tab(icon: Icon(Icons.group_outlined), text: 'Team'),
              Tab(icon: Icon(Icons.card_membership_outlined), text: 'Piani'),
              Tab(icon: Icon(Icons.location_city_outlined), text: 'Sedi'),
              Tab(icon: Icon(Icons.bar_chart_outlined), text: 'Report'),
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
          ],
        ),
      ),
    );
  }
}
