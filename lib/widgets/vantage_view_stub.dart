import 'package:flutter/material.dart';

/// Non-web placeholder. VANTAGE is an HTML app embedded via an iframe, which
/// only exists on the web target; this keeps `flutter test` compiling.
class VantageView extends StatelessWidget {
  const VantageView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('The VANTAGE map is only available in the web build.'),
    );
  }
}
