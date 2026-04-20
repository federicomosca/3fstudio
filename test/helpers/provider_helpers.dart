import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_dynamic_calls
ProviderContainer createContainer({List<dynamic> overrides = const []}) {
  // The ProviderContainer constructor accepts List<Override>, but Override is
  // not exported by flutter_riverpod 3.x — cast is safe here.
  final container = ProviderContainer(
    overrides: overrides.cast(),
  );
  addTearDown(container.dispose);
  return container;
}
