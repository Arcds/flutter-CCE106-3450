import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/status_pill.dart';
import '../../data/demo_store.dart';
import '../../models/open_play_model.dart';
import '../../providers/app_providers.dart';

class OpenPlayScreen extends ConsumerWidget {
  const OpenPlayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final sessions = ref.watch(
      demoStoreProvider.select((state) => [...state.sessions]),
    )..sort((a, b) => a.date.compareTo(b.date));

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Open Play',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(
            'Live capacity',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Join a session and your spot is counted instantly.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
          ),
          const SizedBox(height: 16),
          for (final session in sessions) ...[
            _SessionCard(
              session: session,
              signedIn: user != null,
              joined: user != null && session.hasParticipant(user.uid),
              onJoin: () {
                if (user == null) {
                  context.push('/auth?next=${Uri.encodeComponent('/open-play')}');
                  return;
                }
                try {
                  ref.read(demoStoreProvider.notifier).joinOpenPlay(session.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Joined ${session.title}.')),
                  );
                } on SlotConflictException catch (error) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(error.message)),
                  );
                }
              },
              onLeave: () {
                ref.read(demoStoreProvider.notifier).leaveOpenPlay(session.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Left ${session.title}.')),
                );
              },
            ),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.signedIn,
    required this.joined,
    required this.onJoin,
    required this.onLeave,
  });

  final OpenPlaySession session;
  final bool signedIn;
  final bool joined;
  final VoidCallback onJoin;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final full = session.isFull;
    final date = DateTime.tryParse(session.date);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  session.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              StatusPill(
                label: full ? 'Full' : '${session.spotsLeft} slots left',
                color: full ? const Color(0xFFB3261E) : AppTheme.evergreen,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${session.facilityName} · ${session.skillTier}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.event_outlined, size: 16, color: Colors.black45),
              const SizedBox(width: 6),
              Text(
                date == null ? session.date : shortDate(date),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(width: 12),
              const Icon(Icons.schedule, size: 16, color: Colors.black45),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  session.timeWindow,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              Text(
                peso(session.entryFee),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.evergreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: session.fillRatio,
              minHeight: 8,
              backgroundColor: Colors.black.withValues(alpha: 0.06),
              color: full ? const Color(0xFFB3261E) : AppTheme.evergreen,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                '${session.currentCount} / ${session.maxCapacity} players',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.black54,
                    ),
              ),
              const Spacer(),
              if (joined)
                OutlinedButton(
                  onPressed: onLeave,
                  child: const Text('Leave'),
                )
              else
                FilledButton(
                  onPressed: full ? null : onJoin,
                  child: Text(full ? 'Full' : (signedIn ? 'Join' : 'Sign in to join')),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
