/// An issue (fault) as returned by `GET /api/v1/issues`. Mirrors the web's issue:
/// a title, description, priority and status, raised against a vehicle.
class Issue {
  const Issue({
    required this.id,
    required this.title,
    required this.description,
    required this.priority,
    required this.status,
    this.vehicleId,
    this.reportedAt,
  });

  final String id;
  final String title;
  final String description;

  /// One of `None`, `Low`, `Medium`, `High`.
  final String priority;

  /// Lifecycle status (e.g. `Open`, `Resolved`, `Closed`).
  final String status;
  final String? vehicleId;
  final DateTime? reportedAt;

  factory Issue.fromJsonApi(Map<String, dynamic> attrs) => Issue(
        id: attrs['id'] as String,
        title: (attrs['title'] ?? '') as String,
        description: (attrs['description'] ?? '') as String,
        priority: (attrs['priority'] ?? 'None') as String,
        status: (attrs['status'] ?? 'Open') as String,
        vehicleId: attrs['vehicle_id'] as String?,
        reportedAt: DateTime.tryParse(attrs['reported_at']?.toString() ?? ''),
      );
}
