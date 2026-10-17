import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/issue.dart';

/// Read-only detail for one issue. The list already holds the full record, so
/// it's passed in directly (no extra fetch).
class IssueDetailScreen extends StatelessWidget {
  const IssueDetailScreen({super.key, required this.issue});

  final Issue issue;

  @override
  Widget build(BuildContext context) {
    final reported = issue.reportedAt == null
        ? null
        : DateFormat.yMMMd().add_jm().format(issue.reportedAt!.toLocal());

    return Scaffold(
      appBar: AppBar(title: const Text('Issue')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            issue.title.isEmpty ? '(no title)' : issue.title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              Chip(label: Text('Priority: ${issue.priority}')),
              Chip(label: Text('Status: ${issue.status}')),
            ],
          ),
          const SizedBox(height: 16),
          if (reported != null) ...[
            Text('Reported', style: Theme.of(context).textTheme.bodySmall),
            Text(reported, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 16),
          ],
          Text('Description', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(
            issue.description.isEmpty ? '—' : issue.description,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}
