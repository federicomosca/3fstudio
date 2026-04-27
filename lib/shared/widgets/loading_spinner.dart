import 'package:flutter/material.dart';

class LoadingSpinner extends StatelessWidget {
  const LoadingSpinner({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 20,
      width:  20,
      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
    );
  }
}
