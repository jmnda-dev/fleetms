import 'package:flutter/material.dart';

/// Shown while the app boots and restores any saved session (auth status
/// `unknown`). The router replaces it once the status resolves.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
