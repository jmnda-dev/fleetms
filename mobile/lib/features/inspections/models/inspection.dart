class InspectionAnswer {
  const InspectionAnswer({
    required this.itemId,
    required this.type,
    this.value,
    this.values = const [],
    this.comment,
    this.status,
  });

  final String itemId;
  final String type;
  final String? value;
  final List<String> values;
  final String? comment;
  final String? status;

  factory InspectionAnswer.fromJsonApi(Map<String, dynamic> attrs) {
    return InspectionAnswer(
      itemId: (attrs['item-id'] ?? attrs['item_id']) as String? ?? '',
      type: attrs['type'] as String? ?? 'unknown',
      value: attrs['value'] as String?,
      values: (attrs['values'] as List<dynamic>?)?.cast<String>() ?? [],
      comment: attrs['comment'] as String?,
      status: attrs['status'] as String?,
    );
  }
}

class Inspection {
  const Inspection({
    required this.id,
    required this.vehicleId,
    required this.status,
    required this.result,
    this.submittedAt,
    this.failureCount = 0,
    this.vehicleName,
    this.formTitle,
    this.notes,
    this.answers = const [],
  });

  final String id;
  final String vehicleId;
  final String status;
  final String result;
  final DateTime? submittedAt;
  final int failureCount;
  final String? vehicleName;
  final String? formTitle;
  final String? notes;
  final List<InspectionAnswer> answers;

  factory Inspection.fromJsonApi(Map<String, dynamic> attrs) {
    final vehicleAttr = (attrs['vehicle'] ?? attrs['vehicle-id']) as Map<String, dynamic>?;
    final formAttr = (attrs['inspection-form'] ?? attrs['inspection_form']) as Map<String, dynamic>?;
    
    final answersData = attrs['answers'] as List<dynamic>? ?? [];
    final parsedAnswers = answersData
        .map((a) => InspectionAnswer.fromJsonApi(a as Map<String, dynamic>))
        .toList();

    final submittedAtStr = attrs['submitted-at'] ?? attrs['submitted_at'];

    return Inspection(
      id: attrs['id'] as String,
      vehicleId: (attrs['vehicle-id'] ?? attrs['vehicle_id'] ?? '') as String,
      status: (attrs['status'] ?? 'pending') as String,
      result: (attrs['result'] ?? 'pending') as String,
      submittedAt: submittedAtStr != null ? DateTime.tryParse(submittedAtStr as String) : null,
      failureCount: (attrs['failure-count'] ?? attrs['failure_count'] as num?)?.toInt() ?? 0,
      vehicleName: vehicleAttr?['name'] as String?,
      formTitle: formAttr?['title'] as String?,
      notes: attrs['notes'] as String?,
      answers: parsedAnswers,
    );
  }
}
