import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/auth_controller.dart';
import '../models/user_profile.dart';
import '../profile_controller.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _postalCode = TextEditingController();

  bool _initialized = false;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    _address.dispose();
    _city.dispose();
    _state.dispose();
    _postalCode.dispose();
    super.dispose();
  }

  void _populate(UserProfile? profile) {
    if (_initialized) return;
    if (profile != null) {
      _firstName.text = profile.firstName;
      _lastName.text = profile.lastName;
      _phone.text = profile.phoneNumber ?? '';
      _address.text = profile.address ?? '';
      _city.text = profile.city ?? '';
      _state.text = profile.state ?? '';
      _postalCode.text = profile.postalCode ?? '';
    }
    _initialized = true;
  }

  void _save(UserProfile? currentProfile) {
    if (_formKey.currentState?.validate() ?? false) {
      final userId = ref.read(authControllerProvider).userId;
      if (userId == null) return;

      final updated = UserProfile(
        id: currentProfile?.id ?? '',
        userId: userId,
        firstName: _firstName.text,
        lastName: _lastName.text,
        phoneNumber: _phone.text.isEmpty ? null : _phone.text,
        address: _address.text.isEmpty ? null : _address.text,
        city: _city.text.isEmpty ? null : _city.text,
        state: _state.text.isEmpty ? null : _state.text,
        postalCode: _postalCode.text.isEmpty ? null : _postalCode.text,
      );

      ref.read(profileControllerProvider.notifier).saveProfile(updated).then((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile saved successfully.')));
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              ref.read(authControllerProvider.notifier).signOut();
              context.go('/login');
            },
          ),
        ],
      ),
      body: profileState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (profile) {
          _populate(profile);
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Icon(Icons.person, size: 50, color: theme.colorScheme.onPrimaryContainer),
                  ),
                  const SizedBox(height: 24),
                  Text('Personal Details', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _firstName,
                    decoration: const InputDecoration(labelText: 'First Name'),
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _lastName,
                    decoration: const InputDecoration(labelText: 'Last Name'),
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phone,
                    decoration: const InputDecoration(labelText: 'Phone Number'),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 24),
                  Text('Address', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _address,
                    decoration: const InputDecoration(labelText: 'Address'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _city,
                    decoration: const InputDecoration(labelText: 'City'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _state,
                    decoration: const InputDecoration(labelText: 'State / Province'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _postalCode,
                    decoration: const InputDecoration(labelText: 'Postal Code'),
                  ),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: () => _save(profile),
                    icon: const Icon(Icons.save),
                    label: const Text('Save Profile'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
