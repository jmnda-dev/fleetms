import '../../../core/json_api.dart';

/// A fuel entry as returned by `GET /api/v1/fuel-entries` (JSON:API type
/// `fuel-entry`). Fields mirror the backend: `quantity` (litres/kWh),
/// `refueled_at`, `odometer`, `fuel_type`, and a `cost` Money value which the API
/// serialises as `{ "amount": "...", "currency": "..." }`.
class FuelLog {
  const FuelLog({
    required this.id,
    this.vehicleId,
    required this.quantity,
    this.costAmount,
    this.costCurrency,
    required this.refueledAt,
    this.odometer,
    this.fuelType,
  });

  final String id;
  final String? vehicleId;
  final num quantity;
  final num? costAmount;
  final String? costCurrency;
  final DateTime refueledAt;
  final num? odometer;
  final String? fuelType;

  factory FuelLog.fromJsonApi(Map<String, dynamic> attrs) {
    final cost = attrs['cost'];
    num? amount;
    String? currency;
    if (cost is Map) {
      amount = JsonApi.asNum(cost['amount']);
      currency = cost['currency']?.toString();
    } else if (cost != null) {
      amount = JsonApi.asNum(cost);
    }

    return FuelLog(
      id: attrs['id'] as String,
      vehicleId: attrs['vehicle_id'] as String?,
      quantity: JsonApi.asNum(attrs['quantity']) ?? 0,
      costAmount: amount,
      costCurrency: currency,
      refueledAt: DateTime.tryParse(attrs['refueled_at']?.toString() ?? '') ??
          DateTime.now(),
      odometer: JsonApi.asNum(attrs['odometer']),
      fuelType: attrs['fuel_type']?.toString(),
    );
  }

  String get costDisplay => costAmount == null
      ? '—'
      : '${costCurrency ?? ''} ${costAmount!.toStringAsFixed(2)}'.trim();
}
