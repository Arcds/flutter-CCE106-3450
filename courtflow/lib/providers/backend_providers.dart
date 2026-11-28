import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../data/demo_store.dart';
import '../models/app_user_model.dart';
import '../services/auth_service.dart';
import '../services/booking_repository.dart';
import '../services/functions_service.dart';
import '../services/open_play_repository.dart';
import '../services/venue_repository.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final firebaseAuthUserProvider = StreamProvider<AppUser?>(
  (ref) => ref.watch(authServiceProvider).authStateChanges(),
);

/// False only while Firebase is resolving the initial auth state.
final authReadyProvider = Provider<bool>((ref) {
  if (!AppConfig.useFirebase) return true;
  return !ref.watch(firebaseAuthUserProvider).isLoading;
});

final functionsServiceProvider =
    Provider<FunctionsService>((ref) => FunctionsService());

final venueRepositoryProvider =
    Provider<VenueRepository>((ref) => VenueRepository());

final bookingRepositoryProvider = Provider<BookingRepository>(
  (ref) => BookingRepository(functions: ref.watch(functionsServiceProvider)),
);

final openPlayRepositoryProvider =
    Provider<OpenPlayRepository>((ref) => OpenPlayRepository());

/// Switches between the Phase 1 demo accounts and Firebase Auth.
class AuthController {
  AuthController(this._ref);

  final Ref _ref;

  Future<void> signIn({
    required String email,
    required String password,
    bool createAccount = false,
  }) async {
    if (!AppConfig.useFirebase) {
      _ref.read(demoStoreProvider.notifier).signInAsPlayer();
      return;
    }
    final service = _ref.read(authServiceProvider);
    if (createAccount) {
      await service.signUp(email: email, password: password);
    } else {
      await service.signIn(email: email, password: password);
    }
  }

  Future<void> signInPlayerDemo() async {
    if (!AppConfig.useFirebase) {
      _ref.read(demoStoreProvider.notifier).signInAsPlayer();
      return;
    }
    await _ref.read(authServiceProvider).signInPlayerDemo();
  }

  Future<void> signInStaffDemo() async {
    if (!AppConfig.useFirebase) {
      _ref.read(demoStoreProvider.notifier).signInAsStaff();
      return;
    }
    await _ref.read(authServiceProvider).signInStaffDemo();
  }

  Future<void> signOut() async {
    if (!AppConfig.useFirebase) {
      _ref.read(demoStoreProvider.notifier).signOut();
      return;
    }
    await _ref.read(authServiceProvider).signOut();
  }
}

final authControllerProvider =
    Provider<AuthController>((ref) => AuthController(ref));
