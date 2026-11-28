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
import '../../models/court_model.dart';
import '../../models/slot_model.dart';
import '../../models/venue_model.dart';
import '../../providers/app_providers.dart';
import 'booking_confirmation_sheet.dart';

class ClubStorefrontScreen extends ConsumerStatefulWidget {
  const ClubStorefrontScreen({super.key, required this.facilityId});

  final String facilityId;

  @override
  ConsumerState<ClubStorefrontScreen> createState() => _ClubStorefrontScreenState();
}

class _ClubStorefrontScreenState extends ConsumerState<ClubStorefrontScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  void _bootstrap() {
    if (!mounted) return;
    final pending = ref.read(pendingBookingProvider);
    if (pending != null &&
        pending.facilityId == widget.facilityId &&
        ref.read(currentUserProvider) != null) {
      ref.read(selectedDateProvider.notifier).select(DateTime.parse(pending.date));
      ref.read(selectedCourtProvider.notifier).select(pending.courtId);
      ref.read(pendingBookingProvider.notifier).clear();
      _openIntent(pending);
      return;
    }
    ref.read(selectedCourtProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(demoStoreProvider);
    final venue = firstWhereOrNull(state.venues, (v) => v.id == widget.facilityId);
    if (venue == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Club not found')),
        body: const Center(child: Text('This club is not available.')),
      );
    }

    final selectedDate = ref.watch(selectedDateProvider);
    final courtFilter = ref.watch(selectedCourtProvider);
    final now = DateTime.now();
    final dates = List.generate(7, (index) => DateUtils.dateOnly(now.add(Duration(days: index))));
    final courts = courtFilter == null
        ? venue.courts.where((court) => court.isActive).toList()
        : venue.courts.where((court) => court.id == courtFilter).toList();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildHeader(context, venue),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 88,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                itemCount: dates.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final date = dates[index];
                  final selected = DateUtils.isSameDay(date, selectedDate);
                  return _DateChip(
                    date: date,
                    selected: selected,
                    onTap: () => ref.read(selectedDateProvider.notifier).select(date),
                  );
                },
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('All courts'),
                    selected: courtFilter == null,
                    onSelected: (_) => ref.read(selectedCourtProvider.notifier).clear(),
                  ),
                  for (final court in venue.courts.where((court) => court.isActive)) ...[
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text(court.name),
                      selected: courtFilter == court.id,
                      onSelected: (_) =>
                          ref.read(selectedCourtProvider.notifier).select(court.id),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (venue.announcements.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.lime.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.campaign_outlined, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          venue.announcements,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          for (final court in courts) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Row(
                  children: [
                    Text(
                      court.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${peso(court.hourlyRate)}/hr',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.evergreen,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const Spacer(),
                    Text(
                      shortDate(selectedDate),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.black54,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            _buildSlotList(context, venue, court, selectedDate, now),
          ],
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: AppTheme.cardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Good to know',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    _InfoLine(icon: Icons.info_outline, text: venue.rules),
                    const SizedBox(height: 8),
                    _InfoLine(
                      icon: Icons.account_balance_wallet_outlined,
                      text: venue.paymentInstructions,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  SliverAppBar _buildHeader(BuildContext context, Venue venue) {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 168,
      foregroundColor: Colors.white,
      backgroundColor: AppTheme.deepEvergreen,
      title: Text(
        venue.name,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
      ),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.evergreen, AppTheme.deepEvergreen],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -20,
                bottom: -30,
                child: Icon(
                  Icons.sports_tennis,
                  size: 180,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 52,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      venue.location,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _HeaderChip(
                          icon: Icons.schedule,
                          label: venue.operatingHoursLabel,
                        ),
                        const SizedBox(width: 8),
                        _HeaderChip(
                          icon: Icons.sports_tennis,
                          label: '${venue.courts.length} courts',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlotList(
    BuildContext context,
    Venue venue,
    Court court,
    DateTime selectedDate,
    DateTime now,
  ) {
    final dateKeyValue = dateKey(selectedDate);
    final slots = ref
        .watch(demoStoreProvider)
        .slots
        .where((slot) =>
            slot.facilityId == venue.id &&
            slot.courtId == court.id &&
            slot.date == dateKeyValue)
        .toList()
      ..sort((a, b) => a.startHour.compareTo(b.startHour));

    if (slots.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No slots published for this day.'),
        ),
      );
    }

    return SliverList.builder(
      itemCount: slots.length,
      itemBuilder: (context, index) {
        final slot = slots[index];
        final past = !slotStart(slot.date, slot.startHour).isAfter(now);
        final status = past ? SlotStatus.reserved : slot.effectiveStatus(now);
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: _SlotCard(
            slot: slot,
            court: court,
            status: status,
            past: past,
            onTap: status == SlotStatus.available
                ? () => _openSheet(venue, court, slot)
                : null,
          ),
        );
      },
    );
  }

  Future<void> _openSheet(
    Venue venue,
    Court court,
    Slot slot, {
    BookingIntent? initial,
  }) async {
    final maxDuration = _maxDuration(venue, court, slot);
    final intent = await showModalBottomSheet<BookingIntent>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BookingConfirmationSheet(
        venue: venue,
        court: court,
        slot: slot,
        maxDuration: maxDuration,
        initialDuration: initial?.durationHours ?? 1,
        initialMethod: initial?.paymentMethod,
      ),
    );
    if (intent == null || !mounted) return;
    await _handleIntent(venue, court, intent);
  }

  int _maxDuration(Venue venue, Court court, Slot slot) {
    final now = DateTime.now();
    final state = ref.read(demoStoreProvider);
    var duration = 1;
    for (var hour = slot.startHour + 1;
        hour < venue.closeHour && duration < 3;
        hour++) {
      final next = firstWhereOrNull(
        state.slots,
        (candidate) =>
            candidate.facilityId == venue.id &&
            candidate.courtId == court.id &&
            candidate.date == slot.date &&
            candidate.startHour == hour,
      );
      if (next == null || !next.isAvailableAt(now)) break;
      duration++;
    }
    return duration;
  }

  void _openIntent(BookingIntent intent) {
    final state = ref.read(demoStoreProvider);
    final venue = firstWhereOrNull(state.venues, (v) => v.id == intent.facilityId);
    final court = venue?.courtById(intent.courtId);
    final slot = firstWhereOrNull(
      state.slots,
      (candidate) =>
          candidate.facilityId == intent.facilityId &&
          candidate.courtId == intent.courtId &&
          candidate.date == intent.date &&
          candidate.startHour == intent.startHour,
    );
    if (venue == null || court == null || slot == null) return;
    _openSheet(venue, court, slot, initial: intent);
  }

  Future<void> _handleIntent(Venue venue, Court court, BookingIntent intent) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      ref.read(pendingBookingProvider.notifier).set(intent);
      final next = Uri.encodeComponent('/club/${venue.id}');
      context.push('/auth?next=$next');
      return;
    }

    try {
      final booking = ref.read(demoStoreProvider.notifier).reserveSlot(
            venue: venue,
            court: court,
            date: intent.date,
            startHour: intent.startHour,
            durationHours: intent.durationHours,
            paymentMethod: intent.paymentMethod,
          );

      if (intent.paymentMethod == PaymentMethod.online) {
        ref.read(demoStoreProvider.notifier).completeOnlinePayment(booking.id);
      }

      if (!mounted) return;
      final viewPass = await _showSuccessDialog(booking, intent.paymentMethod);
      if (!mounted) return;
      if (viewPass == true) context.go('/passes');
    } on SlotConflictException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  Future<bool?> _showSuccessDialog(Booking booking, PaymentMethod method) {
    final (title, message) = switch (method) {
      PaymentMethod.online => (
          'Payment successful (demo)',
          'Your QR pass is ready in My Passes.',
        ),
      PaymentMethod.ewallet => (
          'Hold confirmed',
          'Upload your transfer reference before the 15-minute hold ends.',
        ),
      PaymentMethod.cash => (
          'Hold confirmed',
          'Pay at the front desk when you arrive. No QR pass is needed.',
        ),
    };

    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: AppTheme.evergreen, size: 40),
        title: Text(title),
        content: Text(
          '${booking.facilityName} · ${booking.courtName}\n'
          '${shortDate(DateTime.parse(booking.date))} · ${booking.timeLabel}\n\n'
          '$message',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('View pass'),
          ),
        ],
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({
    required this.date,
    required this.selected,
    required this.onTap,
  });

  final DateTime date;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppTheme.evergreen : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: 58,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppTheme.evergreen : Colors.black.withValues(alpha: 0.06),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                weekdayShort(date),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                dayNumber(date),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : AppTheme.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SlotCard extends StatelessWidget {
  const _SlotCard({
    required this.slot,
    required this.court,
    required this.status,
    required this.past,
    this.onTap,
  });

  final Slot slot;
  final Court court;
  final SlotStatus status;
  final bool past;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final available = status == SlotStatus.available;
    final held = status == SlotStatus.held;
    final accent = past
        ? Colors.black26
        : available
            ? AppTheme.evergreen
            : held
                ? const Color(0xFFB26A00)
                : const Color(0xFFB3261E);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: AppTheme.cardDecoration(
        color: available ? Colors.white : Colors.black.withValues(alpha: 0.03),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hourLabel(slot.startHour),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 2),
                      if (held)
                        HoldCountdown(
                          expiresAt: slot.holdExpiresAt,
                          prefix: slot.holdExpiresAt == null
                              ? 'Payment review · '
                              : 'Pending payment · ',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: accent,
                                fontWeight: FontWeight.w600,
                              ),
                        )
                      else
                        Text(
                          past
                              ? 'Past'
                              : available
                                  ? 'Available'
                                  : 'Reserved',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.black54,
                              ),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      peso(court.hourlyRate),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 6),
                    if (available)
                      FilledButton(
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                        ),
                        onPressed: onTap,
                        child: const Text('Reserve'),
                      )
                    else
                      StatusPill(
                        label: held
                            ? (slot.holdExpiresAt == null ? 'In review' : 'On hold')
                            : past
                                ? 'Past'
                                : 'Booked',
                        color: accent,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.black45),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.black54,
                  height: 1.4,
                ),
          ),
        ),
      ],
    );
  }
}
