import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/app_providers.dart';
import '../../providers/backend_providers.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _email = TextEditingController(
    text: AppConfig.useFirebase ? 'player@courtflow.demo' : 'alex@courtflow.demo',
  );
  final _password = TextEditingController(
    text: AppConfig.useFirebase ? 'courtflow123' : 'demo1234',
  );
  bool _signUp = false;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(pendingBookingProvider);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: () => context.canPop() ? context.pop() : context.go('/'),
                icon: const Icon(Icons.arrow_back),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppTheme.evergreen,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.sports_tennis, color: Colors.white),
            ),
            const SizedBox(height: 20),
            Text(
              _signUp ? 'Quick sign-up' : 'Welcome back',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              pending == null
                  ? 'Sign in to reserve courts and keep your passes in one wallet.'
                  : 'Sign in to finish your booking at ${pending.facilityId.replaceAll('-', ' ')}.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.black54,
                    height: 1.4,
                  ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Password',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _busy ? null : _signInPlayer,
                child: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_signUp ? 'Create player account' : 'Sign in as player'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _busy ? null : _signInStaff,
                icon: const Icon(Icons.badge_outlined),
                label: const Text('Continue as staff (demo)'),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: _busy ? null : () => setState(() => _signUp = !_signUp),
                child: Text(
                  _signUp
                      ? 'Already have an account? Sign in'
                      : 'New here? Quick sign-up',
                ),
              ),
            ),
            Center(
              child: TextButton(
                onPressed: _busy ? null : () => context.go('/'),
                child: const Text('Continue as guest'),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 18, color: Colors.black45),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      AppConfig.useFirebase
                          ? 'Firebase Auth is active. Emulator accounts: '
                              'player@courtflow.demo / staff@courtflow.demo, '
                              'password courtflow123.'
                          : 'Phase 1 uses demo auth — any credentials work and no data '
                              'leaves the device.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.black54,
                            height: 1.4,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _signInPlayer() async {
    setState(() => _busy = true);
    try {
      await ref.read(authControllerProvider).signIn(
            email: _email.text.trim(),
            password: _password.text,
            createAccount: _signUp,
          );
      if (!mounted) return;
      await _finish(staff: false);
    } on FirebaseAuthException catch (error) {
      _showError(error.message ?? error.code);
    } catch (error) {
      _showError('$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signInStaff() async {
    setState(() => _busy = true);
    try {
      await ref.read(authControllerProvider).signInStaffDemo();
      if (!mounted) return;
      await _finish(staff: true);
    } on FirebaseAuthException catch (error) {
      _showError(error.message ?? error.code);
    } catch (error) {
      _showError('$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _finish({required bool staff}) async {
    if (AppConfig.useFirebase) {
      // Wait for the auth stream to deliver the Firestore profile before the
      // storefront reads the current user for a pending booking.
      for (var attempt = 0; attempt < 30; attempt++) {
        if (ref.read(currentUserProvider) != null) break;
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      if (!mounted) return;
    }
    final pending = ref.read(pendingBookingProvider);
    if (pending != null) {
      context.go('/club/${pending.facilityId}');
      return;
    }
    final next = GoRouterState.of(context).uri.queryParameters['next'];
    if (next != null && next.isNotEmpty) {
      context.go(next);
      return;
    }
    context.go(staff ? '/staff' : '/');
  }
}
