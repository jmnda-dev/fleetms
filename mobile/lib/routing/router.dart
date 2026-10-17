import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_controller.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/org_picker_screen.dart';
import '../features/auth/screens/splash_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/auth/screens/forgot_password_screen.dart';
import '../features/auth/screens/reset_password_screen.dart';
import '../features/vehicles/screens/vehicles_screen.dart';
import '../features/vehicles/screens/vehicle_detail_screen.dart';
import '../features/issues/screens/issue_detail_screen.dart';
import '../features/issues/models/issue.dart';
import '../features/inspections/screens/inspections_list_screen.dart';
import '../features/inspections/screens/new_inspection_screen.dart';
import '../features/inspections/screens/fill_inspection_screen.dart';
import '../features/inspections/screens/view_inspection_screen.dart';
import '../features/vehicles/models/vehicle.dart';
import '../features/inspections/models/inspection_form_models.dart';
import '../features/fuel/screens/fuel_list_screen.dart';
import '../features/fuel/screens/log_fuel_screen.dart';
import '../features/issues/screens/issues_list_screen.dart';
import '../features/issues/screens/report_issue_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import 'home_shell.dart';

/// The app router. A single `redirect` keyed off [AuthState] decides where the
/// user can be; a `ValueNotifier` bridged from the auth provider drives
/// `refreshListenable` so navigation re-evaluates when auth changes.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh =
      ValueNotifier<AuthStatus>(ref.read(authControllerProvider).status);
  ref.onDispose(refresh.dispose);
  ref.listen(authControllerProvider, (_, next) => refresh.value = next.status);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final status = ref.read(authControllerProvider).status;
      final loc = state.matchedLocation;

      return switch (status) {
        AuthStatus.unknown => loc == '/' ? null : '/',
        AuthStatus.unauthenticated => const [
            '/login',
            '/register',
            '/forgot-password',
            '/reset-password'
          ].contains(loc)
              ? null
              : '/login',
        AuthStatus.needsOrg => loc == '/select-org' ? null : '/select-org',
        AuthStatus.authenticated =>
          const ['/', '/login', '/select-org'].contains(loc)
              ? '/vehicles'
              : null,
      };
    },
    routes: [
      GoRoute(path: '/', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(
          path: '/forgot-password',
          builder: (_, __) => const ForgotPasswordScreen()),
      GoRoute(
          path: '/reset-password',
          builder: (_, __) => const ResetPasswordScreen()),
      GoRoute(path: '/select-org', builder: (_, __) => const OrgPickerScreen()),
      GoRoute(
        path: '/inspections/new',
        builder: (_, __) => const NewInspectionScreen(),
      ),
      GoRoute(
        path: '/issues/new',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return ReportIssueScreen(
            initialVehicleId: extra?['vehicle_id'] as String?,
          );
        },
      ),
      GoRoute(
        path: '/issues/:id',
        builder: (_, state) => IssueDetailScreen(issue: state.extra as Issue),
      ),
      GoRoute(
        path: '/fuel/new',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return LogFuelScreen(
            initialVehicleId: extra?['vehicle_id'] as String?,
          );
        },
      ),
      GoRoute(
        path: '/vehicles/:id',
        builder: (_, state) =>
            VehicleDetailScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/inspections/fill',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>;
          return FillInspectionScreen(
            vehicle: extra['vehicle'] as Vehicle,
            formVersion: extra['formVersion'] as InspectionFormVersion,
          );
        },
      ),
      GoRoute(
        path: '/inspections/:id',
        builder: (_, state) {
          return ViewInspectionScreen(id: state.pathParameters['id']!);
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return HomeShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                  path: '/vehicles',
                  builder: (_, __) => const VehiclesScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                  path: '/inspections',
                  builder: (_, __) => const InspectionsListScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                  path: '/fuel', builder: (_, __) => const FuelListScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                  path: '/issues',
                  builder: (_, __) => const IssuesListScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                  path: '/profile', builder: (_, __) => const ProfileScreen()),
            ],
          ),
        ],
      ),
    ],
  );
});
