class InspectionForm {
  const InspectionForm({
    required this.id,
    required this.title,
    this.description,
    required this.status,
  });

  final String id;
  final String title;
  final String? description;
  final String status;

  factory InspectionForm.fromJsonApi(Map<String, dynamic> attrs, String id) {
    return InspectionForm(
      id: id,
      title: attrs['title'] as String,
      description: attrs['description'] as String?,
      status: attrs['status'] as String? ?? 'draft',
    );
  }
}

class InspectionFormVersion {
  const InspectionFormVersion({
    required this.id,
    required this.inspectionFormId,
    required this.versionNumber,
    required this.schema,
  });

  final String id;
  final String inspectionFormId;
  final int versionNumber;
  final InspectionSchema schema;

  factory InspectionFormVersion.fromJsonApi(
      Map<String, dynamic> attrs, String id) {
    final schemaData = attrs['schema'] as Map<String, dynamic>? ?? {};
    return InspectionFormVersion(
      id: id,
      inspectionFormId: (attrs['inspection_form_id'] ?? '') as String,
      versionNumber: (attrs['version_number'] ?? 1) as int,
      schema: InspectionSchema.fromJson(schemaData),
    );
  }
}

class InspectionSchema {
  const InspectionSchema({
    this.schemaVersion = 1,
    this.sections = const [],
  });

  final int schemaVersion;
  final List<InspectionSection> sections;

  factory InspectionSchema.fromJson(Map<String, dynamic> json) {
    final sectionsList = json['sections'] as List<dynamic>? ?? [];
    return InspectionSchema(
      schemaVersion: json['schema_version'] as int? ?? 1,
      sections: sectionsList
          .map((e) => InspectionSection.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class InspectionSection {
  const InspectionSection({
    required this.title,
    this.description,
    this.items = const [],
  });

  final String title;
  final String? description;
  final List<InspectionItem> items;

  factory InspectionSection.fromJson(Map<String, dynamic> json) {
    final itemsList = json['items'] as List<dynamic>? ?? [];
    return InspectionSection(
      title: (json['title'] ?? '') as String,
      description: json['description'] as String?,
      items: itemsList
          .map((e) => InspectionItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class InspectionItem {
  const InspectionItem({
    required this.id,
    this.label,
    this.helpText,
    this.required = false,
    this.visibleWhen,
    required this.config,
  });

  final String id;
  final String? label;
  final String? helpText;
  final bool required;
  final Map<String, dynamic>? visibleWhen;
  final ItemConfig config;

  factory InspectionItem.fromJson(Map<String, dynamic> json) {
    return InspectionItem(
      id: (json['id'] ?? '') as String,
      label: json['label'] as String?,
      helpText: json['help_text'] as String?,
      required: json['required'] as bool? ?? false,
      visibleWhen: json['visible_when'] as Map<String, dynamic>?,
      config:
          ItemConfig.fromJson(json['config'] as Map<String, dynamic>? ?? {}),
    );
  }
}

abstract class ItemConfig {
  const ItemConfig({required this.type});
  final String type;

  factory ItemConfig.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String? ?? 'unknown';
    switch (type) {
      case 'pass_fail':
        return PassFailConfig.fromJson(json);
      case 'number':
        return NumberConfig.fromJson(json);
      case 'meter':
        return MeterConfig.fromJson(json);
      case 'single_select':
        return SingleSelectConfig.fromJson(json);
      case 'multi_select':
        return MultiSelectConfig.fromJson(json);
      case 'text':
        return TextConfig.fromJson(json);
      case 'date':
        return DateConfig.fromJson(json);
      case 'photo':
        return PhotoConfig.fromJson(json);
      case 'signature':
        return SignatureConfig.fromJson(json);
      case 'instruction':
        return InstructionConfig.fromJson(json);
      default:
        return UnknownConfig(type: type);
    }
  }
}

class PassFailConfig extends ItemConfig {
  const PassFailConfig({
    this.passLabel = 'Pass',
    this.failLabel = 'Fail',
    this.allowNa = true,
    this.commentOn = 'never',
    this.photoOn = 'never',
  }) : super(type: 'pass_fail');

  final String passLabel;
  final String failLabel;
  final bool allowNa;

  /// When to show a comment box: 'never', 'always', 'fail', 'pass'
  final String commentOn;

  /// When to show a photo upload: 'never', 'always', 'fail', 'pass'
  final String photoOn;

  factory PassFailConfig.fromJson(Map<String, dynamic> json) {
    return PassFailConfig(
      passLabel: json['pass_label'] as String? ?? 'Pass',
      failLabel: json['fail_label'] as String? ?? 'Fail',
      allowNa: json['allow_na'] as bool? ?? true,
      commentOn: json['comment_on'] as String? ?? 'never',
      photoOn: json['photo_on'] as String? ?? 'never',
    );
  }
}

class NumberConfig extends ItemConfig {
  const NumberConfig({
    this.unit,
    this.decimals = 0,
    this.min,
    this.max,
    this.passMin,
    this.passMax,
    this.commentOn = 'never',
    this.photoOn = 'never',
  }) : super(type: 'number');

  final String? unit;
  final int decimals;
  final double? min;
  final double? max;
  final double? passMin;
  final double? passMax;
  final String commentOn;
  final String photoOn;

  factory NumberConfig.fromJson(Map<String, dynamic> json) {
    double? parseDouble(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val);
      return null;
    }

    return NumberConfig(
      unit: json['unit'] as String?,
      decimals: json['decimals'] as int? ?? 0,
      min: parseDouble(json['min']),
      max: parseDouble(json['max']),
      passMin: parseDouble(json['pass_min']),
      passMax: parseDouble(json['pass_max']),
      commentOn: json['comment_on'] as String? ?? 'never',
      photoOn: json['photo_on'] as String? ?? 'never',
    );
  }
}

class MeterConfig extends ItemConfig {
  const MeterConfig({
    this.unit,
    this.mustIncrease = true,
    this.commentOn = 'never',
  }) : super(type: 'meter');

  final String? unit;
  final bool mustIncrease;
  final String commentOn;

  factory MeterConfig.fromJson(Map<String, dynamic> json) {
    return MeterConfig(
      unit: json['unit'] as String?,
      mustIncrease: json['must_increase'] as bool? ?? true,
      commentOn: json['comment_on'] as String? ?? 'never',
    );
  }
}

class SingleSelectConfig extends ItemConfig {
  const SingleSelectConfig({
    this.display = 'dropdown',
    this.options = const [],
    this.commentOn = 'never',
    this.photoOn = 'never',
  }) : super(type: 'single_select');

  final String display;
  final List<SelectOption> options;
  final String commentOn;
  final String photoOn;

  factory SingleSelectConfig.fromJson(Map<String, dynamic> json) {
    final opts = json['options'] as List<dynamic>? ?? [];
    return SingleSelectConfig(
      display: json['display'] as String? ?? 'dropdown',
      options: opts
          .map((e) => SelectOption.fromJson(e as Map<String, dynamic>))
          .toList(),
      commentOn: json['comment_on'] as String? ?? 'never',
      photoOn: json['photo_on'] as String? ?? 'never',
    );
  }
}

class MultiSelectConfig extends ItemConfig {
  const MultiSelectConfig({
    this.options = const [],
    this.minSelected = 0,
    this.maxSelected,
    this.failIfAnyFailOption = true,
    this.commentOn = 'never',
  }) : super(type: 'multi_select');

  final List<SelectOption> options;
  final int minSelected;
  final int? maxSelected;
  final bool failIfAnyFailOption;
  final String commentOn;

  factory MultiSelectConfig.fromJson(Map<String, dynamic> json) {
    final opts = json['options'] as List<dynamic>? ?? [];
    return MultiSelectConfig(
      options: opts
          .map((e) => SelectOption.fromJson(e as Map<String, dynamic>))
          .toList(),
      minSelected: json['min_selected'] as int? ?? 0,
      maxSelected: json['max_selected'] as int?,
      failIfAnyFailOption: json['fail_if_any_fail_option'] as bool? ?? true,
      commentOn: json['comment_on'] as String? ?? 'never',
    );
  }
}

class TextConfig extends ItemConfig {
  const TextConfig({
    this.multiline = true,
    this.maxLength,
  }) : super(type: 'text');

  final bool multiline;
  final int? maxLength;

  factory TextConfig.fromJson(Map<String, dynamic> json) {
    return TextConfig(
      multiline: json['multiline'] as bool? ?? true,
      maxLength: json['max_length'] as int?,
    );
  }
}

class DateConfig extends ItemConfig {
  const DateConfig({
    this.mode = 'date',
    this.failIfPast = false,
    this.failIfFuture = false,
  }) : super(type: 'date');

  final String mode; // 'date' or 'datetime'
  final bool failIfPast;
  final bool failIfFuture;

  factory DateConfig.fromJson(Map<String, dynamic> json) {
    return DateConfig(
      mode: json['mode'] as String? ?? 'date',
      failIfPast: json['fail_if_past'] as bool? ?? false,
      failIfFuture: json['fail_if_future'] as bool? ?? false,
    );
  }
}

class PhotoConfig extends ItemConfig {
  const PhotoConfig({
    this.minPhotos = 1,
    this.maxPhotos,
  }) : super(type: 'photo');

  final int minPhotos;
  final int? maxPhotos;

  factory PhotoConfig.fromJson(Map<String, dynamic> json) {
    return PhotoConfig(
      minPhotos: json['min_photos'] as int? ?? 1,
      maxPhotos: json['max_photos'] as int?,
    );
  }
}

class SignatureConfig extends ItemConfig {
  const SignatureConfig({
    this.prompt,
    this.who = 'inspector',
  }) : super(type: 'signature');

  final String? prompt;
  final String who;

  factory SignatureConfig.fromJson(Map<String, dynamic> json) {
    return SignatureConfig(
      prompt: json['prompt'] as String?,
      who: json['who'] as String? ?? 'inspector',
    );
  }
}

class InstructionConfig extends ItemConfig {
  const InstructionConfig({
    required this.body,
  }) : super(type: 'instruction');

  final String body;

  factory InstructionConfig.fromJson(Map<String, dynamic> json) {
    return InstructionConfig(
      body: (json['body'] ?? '') as String,
    );
  }
}

class UnknownConfig extends ItemConfig {
  const UnknownConfig({required super.type});
}

class SelectOption {
  const SelectOption({
    required this.value,
    required this.label,
    this.fail = false,
  });

  final String value;
  final String label;
  final bool fail;

  factory SelectOption.fromJson(Map<String, dynamic> json) {
    return SelectOption(
      value: (json['value'] ?? '') as String,
      label: (json['label'] ?? '') as String,
      fail: json['fail?'] as bool? ?? false,
    );
  }
}
