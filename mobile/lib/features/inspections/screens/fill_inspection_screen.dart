import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'package:signature/signature.dart';
import '../../vehicles/models/vehicle.dart';
import '../models/inspection_form_models.dart';
import '../inspections_repository.dart';
import '../condition_evaluator.dart';
import '../../../core/api_client.dart';

class _UploadState {
  _UploadState(this.localPath);
  final String localPath;
  double progress = 0.0;
  bool isUploading = true;
  String? error;
  Map<String, dynamic>? keys;
}

class FillInspectionScreen extends ConsumerStatefulWidget {
  const FillInspectionScreen({
    super.key,
    required this.vehicle,
    required this.formVersion,
  });

  final Vehicle vehicle;
  final InspectionFormVersion formVersion;

  @override
  ConsumerState<FillInspectionScreen> createState() =>
      _FillInspectionScreenState();
}

class _FillInspectionScreenState extends ConsumerState<FillInspectionScreen> {
  final Map<String, dynamic> _answers = {};
  final Map<String, List<_UploadState>> _photoUploads = {};
  final Map<String, String> _statuses = {};

  bool _isSubmitting = false;
  bool _submitted = false;

  @override
  void dispose() {
    if (!_submitted) {
      // Clean up orphaned uploads if the user leaves without submitting
      for (final uploads in _photoUploads.values) {
        for (final u in uploads) {
          if (u.keys != null) {
            // Fire and forget cleanup
            ref
                .read(apiClientProvider)
                .deleteUpload(u.keys!['image_key'], u.keys!['thumbnail_key'])
                .catchError((_) {});
          }
        }
      }
    }
    super.dispose();
  }

  void _updateAnswer(InspectionItem item, dynamic value,
      [String? computedStatus]) {
    setState(() {
      if (value == null || (value is String && value.isEmpty)) {
        _answers.remove(item.id);
        _statuses.remove(item.id);
      } else {
        _answers[item.id] = value;

        // Compute basic status for conditionals if not provided
        String status = computedStatus ?? 'answered';

        final config = item.config;
        if (config is PassFailConfig) {
          if (value == 'fail') status = 'fail';
          if (value == 'pass') status = 'pass';
          if (config.allowNa && value == 'na') status = 'na';
        } else if (config is SingleSelectConfig) {
          final opt = config.options.where((o) => o.value == value).firstOrNull;
          if (opt?.fail == true) status = 'fail';
        } else if (config is MultiSelectConfig) {
          final List vals = value as List;
          final fails =
              config.options.where((o) => o.fail && vals.contains(o.value));
          if (config.failIfAnyFailOption && fails.isNotEmpty) status = 'fail';
        } else if (config is NumberConfig) {
          final numVal = double.tryParse(value.toString());
          if (numVal != null &&
              config.passMin != null &&
              config.passMax != null) {
            if (numVal < config.passMin! || numVal > config.passMax!)
              status = 'fail';
          }
        }

        _statuses[item.id] = status;
      }
    });
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);

    // Construct the answers array as the backend expects
    final List<Map<String, dynamic>> finalAnswers = [];

    for (final section in widget.formVersion.schema.sections) {
      for (final item in section.items) {
        if (!ConditionEvaluator.isVisible(
            item.visibleWhen, _answers, _statuses)) continue;

        final val = _answers[item.id];
        final config = item.config;

        // --- Required Photo Validation ---
        int requiredPhotos = 0;
        if (config is PhotoConfig) {
          requiredPhotos = config.minPhotos;
        } else {
          final photoOn = _getPhotoOn(config);
          if (photoOn != null &&
              _shouldShowSubInput(photoOn, _statuses[item.id])) {
            requiredPhotos = 1;
          }
        }

        final photoKey = '${item.id}__photos';
        final uploads = _photoUploads[photoKey];

        if (requiredPhotos > 0) {
          final photoCount = uploads?.where((u) => u.keys != null).length ?? 0;
          if (photoCount < requiredPhotos) {
            setState(() => _isSubmitting = false);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(requiredPhotos == 1
                  ? 'A photo is required for "${item.label}".'
                  : 'At least $requiredPhotos photos are required for "${item.label}".'),
            ));
            return;
          }
        }

        final sigKey = '${item.id}__signature';
        final sigUploads = _photoUploads[sigKey];

        if (val != null ||
            (uploads != null && uploads.isNotEmpty) ||
            (sigUploads != null && sigUploads.isNotEmpty)) {
          final answerPayload = <String, dynamic>{
            'item_id': item.id,
            'type': item.config.type,
          };

          if (val != null) {
            if (item.config.type == 'multi_select') {
              answerPayload['values'] = val;
            } else {
              answerPayload['value'] = val.toString();
            }
          }

          // Attach comment if present
          final comment = _answers['${item.id}__comment'];
          if (comment != null && (comment as String).isNotEmpty) {
            answerPayload['comment'] = comment;
          }

          // Attach photos if present
          final photoKey = '${item.id}__photos';
          final uploads = _photoUploads[photoKey];
          if (uploads != null && uploads.isNotEmpty) {
            if (uploads.any((u) => u.isUploading)) {
              setState(() => _isSubmitting = false);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content:
                      Text('Please wait for photos to finish uploading.')));
              return;
            }
            if (uploads.any((u) => u.error != null)) {
              setState(() => _isSubmitting = false);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text(
                      'Some photos failed to upload. Please remove them or try again.')));
              return;
            }
            final keys = uploads
                .map((u) => u.keys)
                .whereType<Map<String, dynamic>>()
                .toList();
            if (keys.isNotEmpty) {
              answerPayload['photos'] = keys;
            }
          }

          // Attach signature if present
          final sigKey = '${item.id}__signature';
          final sigUploads = _photoUploads[sigKey];
          if (sigUploads != null && sigUploads.isNotEmpty) {
            final sig = sigUploads.last;
            if (sig.isUploading) {
              setState(() => _isSubmitting = false);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content:
                      Text('Please wait for signature to finish uploading.')));
              return;
            }
            if (sig.error != null) {
              setState(() => _isSubmitting = false);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content:
                      Text('Signature failed to upload. Please try again.')));
              return;
            }
            if (sig.keys != null) {
              answerPayload['signature'] = sig.keys;
            }
          }

          finalAnswers.add(answerPayload);
        }
      }
    }

    try {
      final repo = ref.read(inspectionsRepositoryProvider);
      await repo.create({
        'vehicle_id': widget.vehicle.id,
        'inspection_form_version_id': widget.formVersion.id,
        'answers': finalAnswers,
      });

      if (mounted) {
        setState(() => _submitted = true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Inspection submitted successfully!')));
        context.go('/inspections');
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to submit: $e')));
      }
    }
  }

  String? _getPhotoOn(ItemConfig config) {
    if (config is PassFailConfig) return config.photoOn;
    if (config is NumberConfig) return config.photoOn;
    if (config is SingleSelectConfig) return config.photoOn;
    return null;
  }

  String? _getCommentOn(ItemConfig config) {
    if (config is PassFailConfig) return config.commentOn;
    if (config is NumberConfig) return config.commentOn;
    if (config is MeterConfig) return config.commentOn;
    if (config is SingleSelectConfig) return config.commentOn;
    if (config is MultiSelectConfig) return config.commentOn;
    return null;
  }

  /// Determines whether a sub-input (comment or photo) should be shown based
  /// on the `comment_on` / `photo_on` config value and the current answer.
  bool _shouldShowSubInput(String trigger, String? currentVal) {
    if (currentVal == null) return false;
    switch (trigger) {
      case 'always':
        return true;
      case 'fail':
        return currentVal == 'fail';
      case 'pass':
        return currentVal == 'pass';
      case 'never':
      default:
        return false;
    }
  }

  /// Builds a compact inline photo upload strip for a given item.
  Future<void> _uploadPhoto(String itemId, String path) async {
    final photoKey = '${itemId}__photos';
    final uploadState = _UploadState(path);

    setState(() {
      _photoUploads.putIfAbsent(photoKey, () => []).add(uploadState);
    });

    try {
      final client = ref.read(apiClientProvider);
      final response =
          await client.uploadPhoto(path, onSendProgress: (sent, total) {
        setState(() {
          uploadState.progress = sent / total;
        });
      });

      setState(() {
        uploadState.isUploading = false;
        uploadState.progress = 1.0;
        uploadState.keys = response;
      });
    } catch (e) {
      setState(() {
        uploadState.isUploading = false;
        uploadState.error = e.toString();
      });
    }
  }

  Future<void> _removePhoto(String itemId, _UploadState uploadState) async {
    final photoKey = '${itemId}__photos';
    setState(() {
      _photoUploads[photoKey]?.remove(uploadState);
    });

    if (uploadState.keys != null) {
      try {
        final client = ref.read(apiClientProvider);
        await client.deleteUpload(
          uploadState.keys!['image_key'],
          uploadState.keys!['thumbnail_key'],
        );
      } catch (e) {
        debugPrint('Failed to delete upload: $e');
      }
    }
  }

  Future<void> _pickAndUploadPhoto(String itemId) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a photo'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source != null) {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: source);
      if (image != null) {
        _uploadPhoto(itemId, image.path);
      }
    }
  }

  Widget _buildInlinePhotoUpload(String itemId) {
    final String photoKey = '${itemId}__photos';
    final List<_UploadState> uploads = _photoUploads[photoKey] ?? [];

    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ...uploads.map((u) {
          final index = uploads.indexOf(u) + 1;
          return Chip(
            avatar: u.isUploading
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        value: u.progress, strokeWidth: 2))
                : u.error != null
                    ? const Icon(Icons.error, size: 16, color: Colors.red)
                    : const Icon(Icons.check_circle,
                        size: 16, color: Colors.green),
            label: Text('Photo $index'),
            onDeleted: () => _removePhoto(itemId, u),
          );
        }),
        ActionChip(
          avatar: const Icon(Icons.add_a_photo, size: 16),
          label: const Text('Add Photo'),
          onPressed: () => _pickAndUploadPhoto(itemId),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.vehicle.name.isEmpty
            ? widget.vehicle.id
            : widget.vehicle.name),
      ),
      body: _isSubmitting
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 84),
              children: [
                for (final section in widget.formVersion.schema.sections)
                  _buildSection(section),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            onPressed: _isSubmitting ? null : _submit,
            icon: const Icon(Icons.check),
            label: const Text('Submit', style: TextStyle(fontSize: 16)),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(InspectionSection section) {
    // Only build section if at least one item is visible
    final visibleItems = section.items
        .where((i) =>
            ConditionEvaluator.isVisible(i.visibleWhen, _answers, _statuses))
        .toList();
    if (visibleItems.isEmpty) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(section.title,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            if (section.description != null) ...[
              const SizedBox(height: 8),
              Text(section.description!),
            ],
            const Divider(),
            ...visibleItems.map((item) => _buildItem(item)),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(InspectionItem item) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                  child: Text(item.label ?? 'Item',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w500))),
              if (item.required)
                const Text('*',
                    style: TextStyle(color: Colors.red, fontSize: 16)),
            ],
          ),
          if (item.helpText != null) ...[
            const SizedBox(height: 4),
            Text(item.helpText!,
                style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          ],
          const SizedBox(height: 8),
          _buildItemInput(item),
        ],
      ),
    );
  }

  Widget _buildItemInput(InspectionItem item) {
    final config = item.config;
    final val = _answers[item.id];
    final String? currentVal = _statuses[item.id];

    final String? commentOn = _getCommentOn(config);
    final String? photoOn = _getPhotoOn(config);
    final bool showComment =
        commentOn != null && _shouldShowSubInput(commentOn, currentVal);
    final bool showPhoto =
        photoOn != null && _shouldShowSubInput(photoOn, currentVal);

    Widget inputWidget;

    if (config is PassFailConfig) {
      inputWidget = SegmentedButton<String>(
        segments: [
          ButtonSegment(
              value: 'pass',
              label: Text(config.passLabel),
              icon: const Icon(Icons.check_circle, color: Colors.green)),
          ButtonSegment(
              value: 'fail',
              label: Text(config.failLabel),
              icon: const Icon(Icons.cancel, color: Colors.red)),
          if (config.allowNa)
            const ButtonSegment(value: 'na', label: Text('N/A')),
        ],
        selected: val != null ? {val as String} : {},
        emptySelectionAllowed: true,
        onSelectionChanged: (set) {
          if (set.isNotEmpty) _updateAnswer(item, set.first);
        },
      );
    } else if (config is TextConfig) {
      inputWidget = TextFormField(
        initialValue: val as String?,
        maxLines: config.multiline ? 3 : 1,
        maxLength: config.maxLength,
        decoration: const InputDecoration(border: OutlineInputBorder()),
        onChanged: (v) => _updateAnswer(item, v),
      );
    } else if (config is NumberConfig || config is MeterConfig) {
      inputWidget = TextFormField(
        initialValue: val?.toString(),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          suffixText: config is NumberConfig
              ? config.unit
              : (config as MeterConfig).unit,
        ),
        onChanged: (v) => _updateAnswer(item, v),
      );
    } else if (config is SingleSelectConfig) {
      if (config.display == 'radio') {
        inputWidget = RadioGroup<String>(
          groupValue: val as String?,
          onChanged: (v) => _updateAnswer(item, v),
          child: Column(
            children: config.options
                .map((o) => RadioListTile<String>(
                      title: Text(o.label),
                      value: o.value,
                    ))
                .toList(),
          ),
        );
      } else {
        inputWidget = DropdownButtonFormField<String>(
          initialValue: val as String?,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: config.options
              .map(
                  (o) => DropdownMenuItem(value: o.value, child: Text(o.label)))
              .toList(),
          onChanged: (v) => _updateAnswer(item, v),
        );
      }
    } else if (config is MultiSelectConfig) {
      final List<String> current =
          (val as List<dynamic>?)?.cast<String>() ?? [];
      inputWidget = Column(
        children: config.options
            .map((o) => CheckboxListTile(
                  title: Text(o.label),
                  value: current.contains(o.value),
                  onChanged: (checked) {
                    if (checked == true) {
                      _updateAnswer(item, [...current, o.value]);
                    } else {
                      _updateAnswer(
                          item, current.where((v) => v != o.value).toList());
                    }
                  },
                ))
            .toList(),
      );
    } else if (config is DateConfig) {
      inputWidget = ElevatedButton.icon(
        icon: const Icon(Icons.calendar_today, size: 20),
        label: Text(val as String? ?? 'Select ${config.mode}',
            style: const TextStyle(fontSize: 16)),
        style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
        onPressed: () async {
          final d = await showDatePicker(
            context: context,
            initialDate: DateTime.now(),
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
          );
          if (d != null) {
            _updateAnswer(item, d.toIso8601String().split('T').first);
          }
        },
      );
    } else if (config is PhotoConfig) {
      inputWidget = _buildInlinePhotoUpload(item.id);
    } else if (config is SignatureConfig) {
      final String sigKey = '${item.id}__signature';
      final sigUploads = _photoUploads[sigKey];
      final sig = (sigUploads != null && sigUploads.isNotEmpty)
          ? sigUploads.last
          : null;

      inputWidget = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (sig != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (sig.isUploading)
                    SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            value: sig.progress, strokeWidth: 2))
                  else if (sig.error != null)
                    const Icon(Icons.error, color: Colors.red, size: 20)
                  else
                    const Icon(Icons.check_circle,
                        color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    sig.isUploading
                        ? 'Uploading signature...'
                        : sig.error != null
                            ? 'Upload failed'
                            : 'Signature captured',
                    style: TextStyle(
                        color: sig.error != null ? Colors.red : Colors.green),
                  ),
                  if (sig.error != null || !sig.isUploading)
                    IconButton(
                      icon: const Icon(Icons.delete, size: 20),
                      onPressed: () {
                        setState(() {
                          _photoUploads.remove(sigKey);
                        });
                        if (sig.keys != null) {
                          ref
                              .read(apiClientProvider)
                              .deleteUpload(sig.keys!['image_key'],
                                  sig.keys!['thumbnail_key'])
                              .catchError((_) {});
                        }
                      },
                    ),
                ],
              ),
            ),
          ElevatedButton.icon(
            icon: const Icon(Icons.draw, size: 20),
            label: Text(sig != null ? 'Re-sign' : 'Sign Here',
                style: const TextStyle(fontSize: 16)),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
            onPressed: () async {
              final result = await showDialog<String>(
                context: context,
                builder: (context) => const _SignatureDialog(),
              );
              if (result != null) {
                // If there's an existing one, remove it
                if (sig != null && sig.keys != null) {
                  ref
                      .read(apiClientProvider)
                      .deleteUpload(
                          sig.keys!['image_key'], sig.keys!['thumbnail_key'])
                      .catchError((_) {});
                }

                final uploadState = _UploadState(result);
                setState(() {
                  _photoUploads[sigKey] = [uploadState];
                });

                try {
                  final client = ref.read(apiClientProvider);
                  final response = await client.uploadPhoto(result,
                      onSendProgress: (sent, total) {
                    setState(() {
                      uploadState.progress = sent / total;
                    });
                  });

                  setState(() {
                    uploadState.isUploading = false;
                    uploadState.progress = 1.0;
                    uploadState.keys = response;
                  });
                } catch (e) {
                  setState(() {
                    uploadState.isUploading = false;
                    uploadState.error = e.toString();
                  });
                }
              }
            },
          ),
        ],
      );
    } else if (config is InstructionConfig) {
      inputWidget = Container(
        padding: const EdgeInsets.all(12),
        color: Colors.blue.withValues(alpha: 0.1),
        child: Text(config.body,
            style: const TextStyle(fontStyle: FontStyle.italic)),
      );
    } else {
      inputWidget = const Text('Unsupported item type');
    }

    if (!showComment && !showPhoto) {
      return inputWidget;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        inputWidget,
        if (showComment) ...[
          const SizedBox(height: 8),
          TextFormField(
            key: ValueKey('comment_${item.id}'),
            initialValue: _answers['${item.id}__comment'] as String?,
            maxLines: 2,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Add a comment...',
              prefixIcon: Icon(Icons.comment_outlined),
            ),
            onChanged: (v) {
              setState(() {
                if (v.isEmpty) {
                  _answers.remove('${item.id}__comment');
                } else {
                  _answers['${item.id}__comment'] = v;
                }
              });
            },
          ),
        ],
        if (showPhoto) ...[
          const SizedBox(height: 8),
          _buildInlinePhotoUpload(item.id),
        ],
      ],
    );
  }
}

class _SignatureDialog extends StatefulWidget {
  const _SignatureDialog();

  @override
  State<_SignatureDialog> createState() => _SignatureDialogState();
}

class _SignatureDialogState extends State<_SignatureDialog> {
  final SignatureController _controller = SignatureController(
    penStrokeWidth: 4,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Capture Signature'),
      content: SizedBox(
        width: 300,
        height: 200,
        child: Signature(
          controller: _controller,
          backgroundColor: Colors.grey[200]!,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => _controller.clear(),
          child: const Text('Clear'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (_controller.isNotEmpty) {
              final exportBytes = await _controller.toPngBytes();
              if (exportBytes != null) {
                final tempDir = await getTemporaryDirectory();
                final file = File(
                    '${tempDir.path}/signature_${DateTime.now().millisecondsSinceEpoch}.png');
                await file.writeAsBytes(exportBytes);
                if (context.mounted) {
                  Navigator.of(context).pop(file.path);
                }
              }
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
