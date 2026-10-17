import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../inspections_controller.dart';
import '../../auth/auth_controller.dart';
import '../models/inspection.dart';

class InspectionsListScreen extends ConsumerWidget {
  const InspectionsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(inspectionsControllerProvider);
    final isArchivedView = ref.watch(archivedViewProvider);

    final orgs = ref.watch(authControllerProvider).organizations;
    // Assuming single active org in scope for this app context. Alternatively, find current active.
    final canDelete =
        orgs.isNotEmpty && orgs.first.hasPermission('delete_inspection');

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Inspections'),
            Text(
              'Inspections drivers and technicians have completed.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        bottom: canDelete
            ? PreferredSize(
                preferredSize: const Size.fromHeight(48.0),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment<bool>(value: false, label: Text('Active')),
                      ButtonSegment<bool>(value: true, label: Text('Archived')),
                    ],
                    selected: {isArchivedView},
                    onSelectionChanged: (Set<bool> newSelection) {
                      ref.read(archivedViewProvider.notifier).state =
                          newSelection.first;
                    },
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              )
            : null,
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(inspectionsControllerProvider.notifier).refresh(),
        child: state.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error: $err')),
          data: (list) {
            if (list.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.assignment_outlined,
                        size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(
                      isArchivedView
                          ? 'No archived inspections.'
                          : 'No inspections yet.',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 84),
              itemCount: list.length,
              itemBuilder: (context, i) {
                return _InspectionCard(
                  inspection: list[i],
                  canDelete: canDelete,
                  isArchivedView: isArchivedView,
                );
              },
            );
          },
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            onPressed: () {
              context.push('/inspections/new');
            },
            icon: const Icon(Icons.add),
            label:
                const Text('Start Inspection', style: TextStyle(fontSize: 16)),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(16),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _InspectionCard extends ConsumerWidget {
  const _InspectionCard({
    required this.inspection,
    required this.canDelete,
    required this.isArchivedView,
  });

  final Inspection inspection;
  final bool canDelete;
  final bool isArchivedView;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM d, y, h:mm a');
    final dateStr = inspection.submittedAt != null
        ? dateFormat.format(inspection.submittedAt!)
        : 'Unknown Date';

    // Badge styling based on result
    Color badgeColor;
    String badgeText;
    switch (inspection.result) {
      case 'passed':
        badgeColor = Colors.green;
        badgeText = 'Passed';
        break;
      case 'failed':
        badgeColor = Colors.red;
        badgeText = 'Failed (${inspection.failureCount})';
        break;
      default:
        badgeColor = Colors.grey;
        badgeText = 'Pending';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    inspection.vehicleName ?? 'Vehicle ${inspection.vehicleId}',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: badgeColor),
                  ),
                  child: Text(
                    badgeText,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: badgeColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              inspection.formTitle ?? 'Unknown Form',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.access_time, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  dateStr,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: Colors.grey[700]),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!isArchivedView) ...[
                  if (canDelete)
                    ActionChip(
                      label: const Text('Archive'),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (c) => AlertDialog(
                            title: const Text('Archive Inspection?'),
                            content: const Text(
                                'This will move the inspection to the archived list.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(c, false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(c, true),
                                child: const Text('Archive'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          ref
                              .read(inspectionsControllerProvider.notifier)
                              .archive(inspection.id);
                        }
                      },
                    ),
                  const SizedBox(width: 8),
                  ActionChip(
                    label: const Text('View'),
                    backgroundColor: theme.colorScheme.primaryContainer,
                    onPressed: () {
                      context.push('/inspections/${inspection.id}');
                    },
                  ),
                ] else ...[
                  if (canDelete)
                    ActionChip(
                      label: const Text('Restore'),
                      onPressed: () {
                        ref
                            .read(inspectionsControllerProvider.notifier)
                            .restore(inspection.id);
                      },
                    ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
