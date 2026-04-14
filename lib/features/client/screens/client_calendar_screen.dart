import 'package:flutter/material.dart';
import '../../calendar/screens/calendar_screen.dart';

/// Wrapper del calendario client. Usa la CalendarScreen esistente.
class ClientCalendarScreen extends StatelessWidget {
  const ClientCalendarScreen({super.key});

  @override
  Widget build(BuildContext context) => const CalendarScreen();
}
