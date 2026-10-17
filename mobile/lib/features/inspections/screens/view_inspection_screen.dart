import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../inspections_controller.dart';

class ViewInspectionScreen extends ConsumerWidget {
  const ViewInspectionScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(inspectionDetailProvider(id));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inspection Details'),
      ),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
        data: (inspection) {
          final dateFormat = DateFormat('MMMM d, y, h:mm a');
          final dateStr = inspection.submittedAt != null
              ? dateFormat.format(inspection.submittedAt!)
              : 'Unknown';

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        inspection.vehicleName ??
                            'Vehicle ${inspection.vehicleId}',
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text('Form: ${inspection.formTitle ?? 'Unknown'}',
                          style: theme.textTheme.bodyLarge),
                      const SizedBox(height: 8),
                      Text('Submitted: $dateStr',
                          style: theme.textTheme.bodyMedium),
                      const SizedBox(height: 8),
                      Text(
                        'Result: ${inspection.result.toUpperCase()}',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: inspection.result == 'passed'
                              ? Colors.green
                              : inspection.result == 'failed'
                                  ? Colors.red
                                  : Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (inspection.notes != null &&
                          inspection.notes!.isNotEmpty) ...[
                        const Divider(),
                        Text('Notes:', style: theme.textTheme.titleSmall),
                        Text(inspection.notes!),
                      ]
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text('Answers', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              if (inspection.answers.isEmpty)
                const Text('No answers recorded.')
              else
                ...inspection.answers.map((ans) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Item: ${ans.itemId}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              if (ans.status != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _statusColor(ans.status!),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    ans.status!.toUpperCase(),
                                    style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          if (ans.value != null && ans.value!.isNotEmpty)
                            Text('Value: ${ans.value}'),
                          if (ans.values.isNotEmpty)
                            Text('Values: ${ans.values.join(', ')}'),
                          if (ans.comment != null &&
                              ans.comment!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text('Comment: ${ans.comment}',
                                style: const TextStyle(
                                    fontStyle: FontStyle.italic)),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pass':
        return Colors.green;
      case 'fail':
        return Colors.red;
      case 'na':
        return Colors.grey;
      case 'answered':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}
