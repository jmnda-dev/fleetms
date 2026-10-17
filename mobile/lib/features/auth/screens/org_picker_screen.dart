import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth_controller.dart';

/// Shown after sign-in when the user belongs to more than one organization.
/// Picking one sets the tenant (`x-organization`) for the rest of the session.
class OrgPickerScreen extends ConsumerWidget {
  const OrgPickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orgs = ref.watch(authControllerProvider).organizations;

    return Scaffold(
      appBar: AppBar(title: const Text('Choose an organization')),
      body: ListView.separated(
        itemCount: orgs.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final org = orgs[i];
          return ListTile(
            title: Text(org.name),
            subtitle: org.owner ? const Text('Owner') : null,
            trailing: const Icon(Icons.chevron_right),
            onTap: () => ref.read(authControllerProvider.notifier).selectOrg(org),
          );
        },
      ),
    );
  }
}
