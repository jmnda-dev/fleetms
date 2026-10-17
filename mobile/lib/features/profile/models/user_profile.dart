import '../../../core/json_api.dart';

class UserProfile {
  UserProfile({
    required this.id,
    required this.userId,
    required this.firstName,
    required this.lastName,
    this.otherName,
    this.phoneNumber,
    this.secondaryPhoneNumber,
    this.dateOfBirth,
    this.address,
    this.city,
    this.state,
    this.postalCode,
    this.profilePhoto,
  });

  final String id;
  final String userId;
  final String firstName;
  final String lastName;
  final String? otherName;
  final String? phoneNumber;
  final String? secondaryPhoneNumber;
  final String? dateOfBirth;
  final String? address;
  final String? city;
  final String? state;
  final String? postalCode;
  final String? profilePhoto;

  factory UserProfile.fromJsonApi(Map<String, dynamic> resource) {
    final attrs = JsonApi.attributes(resource);
    return UserProfile(
      id: attrs['id'] as String,
      userId: attrs['user_id'] as String,
      firstName: attrs['first_name'] as String,
      lastName: (attrs['last_name'] ?? '') as String, // It could be nil if validation was loose before? wait, backend says allow_nil?: false for last_name in backend, except it allows nil in the original but recently changed?
      otherName: attrs['other_name'] as String?,
      phoneNumber: attrs['phone_number'] as String?,
      secondaryPhoneNumber: attrs['secondary_phone_number'] as String?,
      dateOfBirth: attrs['date_of_birth'] as String?,
      address: attrs['address'] as String?,
      city: attrs['city'] as String?,
      state: attrs['state'] as String?,
      postalCode: attrs['postal_code'] as String?,
      profilePhoto: attrs['profile_photo'] as String?,
    );
  }

  Map<String, dynamic> toJsonApiAttributes() {
    return {
      'user_id': userId,
      'first_name': firstName,
      'last_name': lastName,
      'other_name': otherName,
      'phone_number': phoneNumber,
      'secondary_phone_number': secondaryPhoneNumber,
      'date_of_birth': dateOfBirth,
      'address': address,
      'city': city,
      'state': state,
      'postal_code': postalCode,
      'profile_photo': profilePhoto,
    }..removeWhere((k, v) => v == null);
  }
}
