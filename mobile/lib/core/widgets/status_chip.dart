import 'package:flutter/material.dart';

import '../theme.dart';

/// A small status pill using the same semantic colors as the web badges: a soft
/// tinted background with a stronger text color. The vehicle-status → color
/// mapping mirrors `FleetmsWeb.VehicleLive.StatusPresenter`.
///
///   Active → success · Maintenance → warning · Out-of-Service → danger ·
///   Inactive / Sold → neutral
class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});

  final String status;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tone = _toneFor(status);
    final (bg, fg) = tone.colors(dark);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        _label(status),
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  static _Tone _toneFor(String status) => switch (status) {
        'Active' => _Tone.success,
        'Maintenance' => _Tone.warning,
        'Out-of-Service' => _Tone.danger,
        _ => _Tone.neutral,
      };

  // "In Shop" is the friendlier label the web uses for the Maintenance status.
  static String _label(String status) =>
      status == 'Maintenance' ? 'In Shop' : status;
}

enum _Tone {
  success,
  warning,
  danger,
  neutral;

  /// (background, foreground) for the given brightness — soft tint + strong text,
  /// like the web's `bg-*-soft` / `text-fg-*` badge tokens.
  (Color, Color) colors(bool dark) => switch (this) {
        _Tone.success => dark
            ? (FleetmsColors.emerald600, FleetmsColors.emerald50)
            : (FleetmsColors.emerald50, FleetmsColors.emerald600),
        _Tone.warning => dark
            ? (FleetmsColors.amber600, FleetmsColors.amber50)
            : (FleetmsColors.amber50, FleetmsColors.amber600),
        _Tone.danger => dark
            ? (FleetmsColors.red700, FleetmsColors.red50)
            : (FleetmsColors.red50, FleetmsColors.red600),
        _Tone.neutral => dark
            ? (FleetmsColors.gray700, FleetmsColors.gray300)
            : (FleetmsColors.gray100, FleetmsColors.gray600),
      };
}
