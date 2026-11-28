import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/iterables.dart';
import '../../core/widgets/hold_countdown.dart';
import '../../core/widgets/status_pill.dart';
import '../../data/demo_store.dart';
import '../../models/booking_model.dart';
import '../../models/venue_model.dart';
import '../../providers/app_providers.dart';

enum _StaffFilter { all, unpaid, forReview, verified, checkedIn }

extension on _StaffFilter {
  String get label => switch (this) {
        _StaffFilter.all => 'All',
        _StaffFilter.unpaid => 'Unpaid',
        _StaffFilter.forReview => 'For Review',
        _StaffFilter.verified => 'Verified',
        _StaffFilter.checkedIn => 'Checked In',
      };

  bool matches(Booking booking) => switch (this) {
        _StaffFilter.all => true,
        _StaffFilter.unpaid => booking.status == BookingStatus.pendingPayment,
        _StaffFilter.forReview => booking.status == BookingStatus.paymentReview,
        _StaffFilter.verified => booking.status == BookingStatus.verified,
        _StaffFilter.checkedIn => booking.status == BookingStatus.checkedIn,
      };
}

class StaffControlCenterScreen extends ConsumerStatefulWidget {
  const StaffControlCenterScreen({super.key});

  @override
  ConsumerState<StaffControlCenterScreen> createState() =>
      _StaffControlCenterScreenState();
}

class _StaffControlCenterScreenState extends ConsumerState<StaffControlCenterScreen> {
  _StaffFilter _filter = _StaffFilter.all;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final state = ref.watch(demoStoreProvider);
    final venue = firstWhereOrNull(
          state.venues,
          (candidate) => user != null && user.manages(candidate.id),
        ) ??
        state.venues.first;

    if (user == null || !user.isStaff) {
      return Scaffold(
        appBar: AppBar(title: const Text('Staff Control Center')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 48, color: Colors.black26),
                const SizedBox(height: 12),
                const Text('Staff access required'),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context.push('/auth'),
                  child: const Text('Staff sign in'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final today = dateKey(DateTime.now());
    final venueBookings = state.bookings
        .where((booking) => booking.facilityId == venue.id)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final todays = venueBookings.where((booking) => booking.date == today).toList();
    final checkedInToday =
        todays.where((booking) => booking.status == BookingStatus.checkedIn).length;
    final revenue = venueBookings
        .where((booking) =>
            booking.status == BookingStatus.verified ||
            booking.status == BookingStatus.checkedIn)
        .fold<double>(0, (sum, booking) => sum + booking.totalFee);
    final filtered = venueBookings.where(_filter.matches).toList();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Staff Control Center',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            Text(
              venue.name,
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Scan QR pass',
            onPressed: () => context.push('/staff/scan'),
            icon: const Icon(Icons.qr_code_scanner),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Row(
            children: [
              Expanded(
                child: _SummaryTile(
                  label: 'Today',
                  value: '${todays.length}',
                  caption: 'bookings',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryTile(
                  label: 'Checked in',
                  value: '$checkedInToday',
                  caption: 'players',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryTile(
                  label: 'Collected',
                  value: peso(revenue),
                  caption: 'verified + paid',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<_StaffFilter>(
              segments: [
                for (final filter in _StaffFilter.values)
                  ButtonSegment(value: filter, label: Text(filter.label)),
              ],
              selected: {_filter},
              onSelectionChanged: (selection) =>
                  setState(() => _filter = selection.first),
              showSelectedIcon: false,
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                textStyle: WidgetStateProperty.all(
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: AppTheme.cardDecoration(),
              child: Center(
                child: Text(
                  'No bookings in this queue.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.black54,
                      ),
                ),
              ),
            ),
          for (final booking in filtered) ...[
            _StaffBookingCard(booking: booking),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    required this.caption,
  });

  final String label;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          Text(
            caption,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.black38,
                  fontSize: 10,
                ),
          ),
        ],
      ),
    );
  }
}

class _StaffBookingCard extends ConsumerWidget {
  const _StaffBookingCard({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = switch (booking.status) {
      BookingStatus.verified => AppTheme.evergreen,
      BookingStatus.paymentReview => const Color(0xFFB26A00),
      BookingStatus.pendingPayment => const Color(0xFFB26A00),
      BookingStatus.checkedIn => const Color(0xFF2F6B9A),
      _ => Colors.black45,
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  booking.playerName,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
              StatusPill(label: booking.status.label, color: accent),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${booking.courtName} · ${shortDate(DateTime.parse(booking.date))} · ${booking.timeLabel}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54),
          ),
          const SizedBox(height: 2),
          Text(
            '${booking.paymentMethod.label} · ${booking.feeLabel}'
            '${booking.paymentRef == null ? '' : ' · ${booking.paymentRef}'}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 10),
          if (booking.status == BookingStatus.paymentReview)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      ref.read(demoStoreProvider.notifier).rejectPayment(booking.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Rejected ${booking.playerName}\'s proof.')),
                      );
                    },
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      ref.read(demoStoreProvider.notifier).approvePayment(booking.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Approved ${booking.playerName}. QR pass issued.')),
                      );
                    },
                    child: const Text('Approve'),
                  ),
                ),
              ],
            )
          else if (booking.status == BookingStatus.pendingPayment &&
              booking.paymentMethod == PaymentMethod.cash)
            Row(
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
                FilledButton.icon(
                  onPressed: () {
                    ref.read(demoStoreProvider.notifier).verifyAndCheckIn(booking.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${booking.playerName} checked in.')),
                    );
                  },
                  icon: const Icon(Icons.how_to_reg, size: 18),
                  label: const Text('Verify & Check In'),
                ),
              ],
            )
          else if (booking.status == BookingStatus.pendingPayment)
            Row(
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
                const Text(
                  'Awaiting player payment',
                  style: TextStyle(fontSize: 12, color: Colors.black45),
                ),
              ],
            )
          else if (booking.status == BookingStatus.verified)
            Row(
              children: [
                const Icon(Icons.qr_code_2, size: 18, color: AppTheme.evergreen),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ready for QR check-in',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.evergreen,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/staff/scan'),
                  child: const Text('Scan'),
                ),
              ],
            )
          else if (booking.status == BookingStatus.checkedIn &&
              booking.checkedInAt != null)
            Text(
              'Checked in at ${TimeOfDay.fromDateTime(booking.checkedInAt!).format(context)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF2F6B9A),
                    fontWeight: FontWeight.w600,
                  ),
            ),
        ],
      ),
    );
  }
}
