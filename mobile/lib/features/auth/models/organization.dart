/// An organization the signed-in user belongs to. `publicId` is what goes in the
/// `x-organization` tenant header. Returned by `POST /sign-in`.
class Organization {
  const Organization({
    required this.id,
    required this.publicId,
    required this.name,
    required this.owner,
    this.permissions = const [],
  });

  final String id;
  final String publicId;
  final String name;
  final bool owner;
  final List<String> permissions;

  bool hasPermission(String permission) => owner || permissions.contains(permission);

  /// From the plain JSON object in the sign-in response's `organizations` array
  /// (NOT a JSON:API resource — sign-in is a plain controller).
  factory Organization.fromJson(Map<String, dynamic> json) => Organization(
        id: json['id'] as String,
        publicId: json['public_id'] as String,
        name: (json['name'] ?? '') as String,
        owner: (json['owner'] ?? false) as bool,
        permissions: (json['permissions'] as List<dynamic>?)?.cast<String>() ?? [],
      );
}
