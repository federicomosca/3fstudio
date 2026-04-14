import 'package:flutter/material.dart';
import '../../../shared/widgets/coming_soon.dart';

class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report')),
      body: const ComingSoon(
        title: 'Report & analytics',
        icon: Icons.bar_chart_outlined,
        subtitle: 'Presenze, revenue e no-show per corso e periodo.\nIn arrivo presto.',
      ),
    );
  }
}
