import 'package:flutter/material.dart';

class RpmDisplay extends StatelessWidget {
  final ValueNotifier<double> rpmNotifier;

  const RpmDisplay({super.key, required this.rpmNotifier});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: rpmNotifier,
      builder: (_, rpm, __) => Text(
        '${rpm.toStringAsFixed(0)} RPM',
        style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
      ),
    );
  }
}
