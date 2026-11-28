import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/hold_countdown.dart';
import '../../core/widgets/status_pill.dart';
import '../../data/demo_store.dart';
import '../../models/booking_model.dart';
import '../../models/venue_model.dart';
import '../../providers/app_providers.dart';

class MyPassesScreen extends ConsumerWidget {
  const MyPassesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Passes')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.qr_code_2, size: 56, color: Colors.black26),
                const SizedBox(height: 16),
                Text(
                  'Sign in to see your passes',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Verified pre-paid bookings show a QR pass here.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => context.push('/auth'),
                  child: const Text('Sign in'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final bookings = ref.watch(
      demoStoreProvider.select(
        (state) => state.bookings.where((booking) => booking.playerId == user.uid).toList(),
      ),
    )..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final active = bookings.where((booking) => booking.status.isActive).toList();
    final past = bookings.where((booking) => !booking.status.isActive).toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'My Passes',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Active'),
              Tab(text: 'Past'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _PassList(bookings: active, emptyLabel: 'No active passes yet.'),
            _PassList(bookings: past, emptyLabel: 'No past passes yet.'),
          ],
        ),
      ),
    );
  }
}

class _PassList extends StatelessWidget {
  const _PassList({required this.bookings, required this.emptyLabel});

  final List<Booking> bookings;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) {
      return Center(
        child: Text(
          emptyLabel,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: bookings.length,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (context, index) => _PassCard(booking: bookings[index]),
    );
  }
}

class _PassCard extends ConsumerWidget {
  const _PassCard({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = booking.status;
    final accent = switch (status) {
      BookingStatus.verified => AppTheme.evergreen,
      BookingStatus.paymentReview => const Color(0xFFB26A00),
      BookingStatus.pendingPayment => const Color(0xFFB26A00),
      BookingStatus.checkedIn => const Color(0xFF2F6B9A),
      _ => Colors.black45,
    };

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
                  booking.facilityName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              StatusPill(label: status.label, color: accent),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${booking.courtName} · ${shortDate(DateTime.parse(booking.date))} · ${booking.timeLabel}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54),
          ),
          const SizedBox(height: 4),
          Text(
            '${booking.feeLabel} · ${booking.paymentMethod.label}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
          ),
          if (status == BookingStatus.verified) ...[
            const SizedBox(height: 16),
            _QrBlock(booking: booking),
          ],
          if (status == BookingStatus.pendingPayment) ...[
            const SizedBox(height: 14),
            _PendingActions(booking: booking),
          ],
          if (status == BookingStatus.paymentReview) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFB26A00).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.hourglass_top, size: 18, color: Color(0xFFB26A00)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Waiting for staff review'
                      '${booking.paymentRef == null ? '' : ' · ${booking.paymentRef}'}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFFB26A00),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (status == BookingStatus.checkedIn && booking.checkedInAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'Checked in at ${TimeOfDay.fromDateTime(booking.checkedInAt!).format(context)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF2F6B9A),
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          if (status == BookingStatus.expired)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'Hold expired — the slot was released.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54),
              ),
            ),
        ],
      ),
    );
  }
}

class _QrBlock extends StatelessWidget {
  const _QrBlock({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final token = booking.qrToken;
    if (token == null) {
      return const Text('QR pass is being issued…');
    }

    return Center(
      child: Column(
        children: [
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _showFullPass(context, booking, token),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
                ),
                child: QrImageView(
                  data: token,
                  version: QrVersions.auto,
                  size: 168,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: AppTheme.ink,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: AppTheme.ink,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap to present at the front desk',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54),
          ),
        ],
      ),
    );
  }

  void _showFullPass(BuildContext context, Booking booking, String token) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              QrImageView(
                data: token,
                version: QrVersions.auto,
                size: 260,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: AppTheme.ink,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: AppTheme.ink,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                booking.playerName,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                '${booking.facilityName} · ${booking.courtName}',
                style: const TextStyle(color: Colors.black54, fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                '${shortDate(DateTime.parse(booking.date))} · ${booking.timeLabel}',
                style: const TextStyle(color: Colors.black54, fontSize: 12),
              ),
              const SizedBox(height: 12),
              const Text(
                'Demo token · server-signed QR arrives in Phase 4',
                style: TextStyle(color: Colors.black38, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingActions extends ConsumerWidget {
  const _PendingActions({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final method = booking.paymentMethod;

    if (method == PaymentMethod.cash) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.sand,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.payments_outlined, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Present at Front Desk',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            HoldCountdown(
              expiresAt: booking.holdExpiresAt,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      );
    }

    if (method == PaymentMethod.online) {
      return Row(
        children: [
          Expanded(
            child: HoldCountdown(
              expiresAt: booking.holdExpiresAt,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          FilledButton(
            onPressed: () {
              ref.read(demoStoreProvider.notifier).completeOnlinePayment(booking.id);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Demo payment approved. QR pass issued.')),
              );
            },
            child: const Text('Pay now'),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: HoldCountdown(
            expiresAt: booking.holdExpiresAt,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        FilledButton(
          onPressed: () => _uploadProof(context, ref),
          child: const Text('Upload proof'),
        ),
      ],
    );
  }

  Future<void> _uploadProof(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: 'GCASH-');
    final reference = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Upload payment proof'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Demo mode: enter a reference number. Screenshot upload is wired up in Phase 3.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'Reference number'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reference == null || reference.isEmpty) return;
    ref.read(demoStoreProvider.notifier).submitPaymentProof(booking.id, reference);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Proof submitted for staff review.')),
      );
    }
  }
}
