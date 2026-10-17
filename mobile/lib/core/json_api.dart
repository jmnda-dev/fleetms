/// Helpers for reading and building JSON:API payloads, so features never poke at
/// the raw `{data: {type, id, attributes}}` envelope by hand.
///
/// A JSON:API resource object looks like:
///   {"type": "vehicle", "id": "…", "attributes": {…}, "relationships": {…}}
/// A response is either `{"data": {…}}` (one) or `{"data": [ … ]}` (many).
class JsonApi {
  /// The list of resource objects from a collection response.
  static List<Map<String, dynamic>> many(Map<String, dynamic> body) {
    final data = body['data'];
    if (data is List) return data.cast<Map<String, dynamic>>();
    return const [];
  }

  /// The single resource object from an item response.
  static Map<String, dynamic> one(Map<String, dynamic> body) {
    final data = body['data'];
    if (data is Map<String, dynamic>) return data;
    return const {};
  }

  /// A resource object's attributes, with its `id` merged in under `"id"` so a
  /// model's `fromJsonApi` can read everything from one flat map.
  static Map<String, dynamic> attributes(Map<String, dynamic> resource, {Map<String, dynamic>? body}) {
    final attrs = <String, dynamic>{};
    final a = resource['attributes'];
    if (a is Map<String, dynamic>) attrs.addAll(a);
    attrs['id'] = resource['id'];
    
    if (body != null && resource['relationships'] is Map) {
      final relationships = resource['relationships'] as Map<String, dynamic>;
      final included = (body['included'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      
      for (final entry in relationships.entries) {
        final relName = entry.key;
        final relData = entry.value['data'];
        
        if (relData is Map<String, dynamic>) {
          // single relationship
          final matched = included.where((i) => i['type'] == relData['type'] && i['id'] == relData['id']);
          if (matched.isNotEmpty) {
            attrs[relName] = attributes(matched.first); // no recursive body passing to avoid cycles
          }
        }
      }
    }
    
    return attrs;
  }

  /// Coerces a JSON value to `num?`. JSON:API serializes Ash `decimal` fields
  /// (mileage, money, quantities, …) as **strings** to preserve precision, so a
  /// plain `as num?` cast throws on them — read numeric attributes through this.
  static num? asNum(dynamic value) {
    if (value == null) return null;
    if (value is num) return value;
    if (value is String) return num.tryParse(value);
    return null;
  }

  /// Wraps attributes into a write body: `{data: {type, id?, attributes}}`.
  static Map<String, dynamic> body(
    String type,
    Map<String, dynamic> attributes, {
    String? id,
  }) {
    final data = <String, dynamic>{'type': type, 'attributes': attributes};
    if (id != null) data['id'] = id;
    return {'data': data};
  }
}
