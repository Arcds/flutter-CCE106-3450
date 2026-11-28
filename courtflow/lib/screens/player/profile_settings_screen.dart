import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/status_pill.dart';
import '../../data/demo_seed.dart';
import '../../data/demo_store.dart';
import '../../models/app_user_model.dart';
import '../../providers/app_providers.dart';
import '../../providers/backend_providers.dart';

class ProfileSettingsScreen extends ConsumerWidget {
  const ProfileSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (user == null) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.evergreen, AppTheme.deepEvergreen],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.person_outline, color: Colors.white70, size: 32),
                  const SizedBox(height: 12),
                  Text(
                    'You are browsing as a guest',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sign in to book courts, join open play, and keep your passes.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white70,
                          height: 1.4,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.lime,
                          foregroundColor: AppTheme.ink,
                        ),
                        onPressed: () => context.push('/auth'),
                        child: const Text('Sign in'),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => context.push('/staff'),
                        child: const Text(
                          'Staff portal',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ] else ...[
            _UserCard(user: user),
            const SizedBox(height: 20),
            if (!AppConfig.useFirebase) ...[
              Text(
                'Demo accounts',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              _DemoSwitchRow(
                activeUid: user.uid,
                onPlayer: () => ref.read(demoStoreProvider.notifier).signInAsPlayer(),
                onStaff: () => ref.read(demoStoreProvider.notifier).signInAsStaff(),
              ),
            ] else
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_user_outlined, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Signed in with Firebase Auth. Roles and club access come '
                        'from users/${user.uid}.',
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
          const SizedBox(height: 20),
          Text(
            'Account',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          _MenuTile(
            icon: Icons.badge_outlined,
            title: 'Staff Control Center',
            subtitle: user?.isStaff == true
                ? 'Manage payments and check-ins'
                : 'Requires a staff account',
            onTap: () => context.push('/staff'),
          ),
          _MenuTile(
            icon: Icons.notifications_none,
            title: 'Notifications',
            subtitle: 'Booking, payment and roster alerts',
            onTap: () => context.push('/notifications'),
          ),
          _MenuTile(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Payment methods',
            subtitle: 'Online (demo), e-wallet transfer, pay at desk',
            onTap: () => _showPaymentInfo(context),
          ),
          if (user != null) ...[
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () async {
                try {
                  await ref.read(authControllerProvider).signOut();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Signed out.')),
                  );
                } catch (error) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$error')),
                  );
                }
              },
              icon: const Icon(Icons.logout),
              label: const Text('Sign out'),
            ),
          ],
          const SizedBox(height: 24),
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
                const Icon(Icons.construction_outlined, size: 18, color: Colors.black45),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    AppConfig.useFirebase
                        ? 'Firebase Auth is live. Venue, slot and booking screens still '
                            'read the in-memory demo store until the Phase 3 stream migration.'
                        : 'Phase 1 preview: all data is in-memory. Run with '
                            '--dart-define=USE_FIREBASE=true to exercise Firebase Auth.',
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
    );
  }

  void _showPaymentInfo(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment methods',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Pay Online — simulated success in Phase 1.\n'
              'E-Wallet Transfer — send payment, then upload a reference for staff review.\n'
              'Pay at Desk — hold the slot and pay on arrival.',
              style: TextStyle(height: 1.6, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            const Text(
              'No payment gateway or secret keys are used in this build.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final initials = user.name
        .split(' ')
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration(),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: AppTheme.evergreen,
            child: Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                Text(
                  user.email,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.black54,
                      ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    StatusPill(
                      label: user.role.name.toUpperCase(),
                      color: user.isStaff ? const Color(0xFF2F6B9A) : AppTheme.evergreen,
                    ),
                    if (user.clubRoles.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        '${user.clubRoles.length} club role(s)',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.black54,
                            ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DemoSwitchRow extends StatelessWidget {
  const _DemoSwitchRow({
    required this.activeUid,
    required this.onPlayer,
    required this.onStaff,
  });

  final String activeUid;
  final VoidCallback onPlayer;
  final VoidCallback onStaff;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              backgroundColor: activeUid == demoPlayerUser.uid ? AppTheme.sand : null,
            ),
            onPressed: onPlayer,
            child: const Text('Player demo'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              backgroundColor: activeUid == demoStaffUser.uid ? AppTheme.sand : null,
            ),
            onPressed: onStaff,
            child: const Text('Staff demo'),
          ),
        ),
      ],
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.sand,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.black54,
                            ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.black38),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
