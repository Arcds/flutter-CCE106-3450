import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/court_model.dart';
import '../../models/slot_model.dart';
import '../../models/venue_model.dart';
import '../../providers/app_providers.dart';

class BookingConfirmationSheet extends ConsumerStatefulWidget {
  const BookingConfirmationSheet({
    super.key,
    required this.venue,
    required this.court,
    required this.slot,
    required this.maxDuration,
    this.initialDuration = 1,
    this.initialMethod,
  });

  final Venue venue;
  final Court court;
  final Slot slot;
  final int maxDuration;
  final int initialDuration;
  final PaymentMethod? initialMethod;

  @override
  ConsumerState<BookingConfirmationSheet> createState() =>
      _BookingConfirmationSheetState();
}

class _BookingConfirmationSheetState extends ConsumerState<BookingConfirmationSheet> {
  late int _duration;
  late PaymentMethod _method;

  @override
  void initState() {
    super.initState();
    _duration = widget.initialDuration.clamp(1, widget.maxDuration);
    final methods = widget.venue.acceptedPaymentMethods;
    _method = widget.initialMethod ?? methods.first;
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final total = widget.court.hourlyRate * _duration;
    final date = DateTime.parse(widget.slot.date);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppTheme.sand,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.venue.name,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          Text(
                            '${widget.court.name} · ${shortDate(date)}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.black54,
                                ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: AppTheme.cardDecoration(),
                  child: Column(
                    children: [
                      _InfoRow(
                        icon: Icons.schedule,
                        label: 'Time',
                        value: timeRangeLabel(widget.slot.startHour, _duration),
                      ),
                      const Divider(height: 20),
                      _InfoRow(
                        icon: Icons.timer_outlined,
                        label: 'Duration',
                        value: '$_duration hour${_duration == 1 ? '' : 's'}',
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          for (var hours = 1; hours <= widget.maxDuration; hours++)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text('${hours}h'),
                                selected: _duration == hours,
                                onSelected: (_) => setState(() => _duration = hours),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Payment method',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                for (final method in widget.venue.acceptedPaymentMethods)
                  _MethodTile(
                    method: method,
                    selected: _method == method,
                    onTap: () => setState(() => _method = method),
                  ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
                  ),
                  child: Column(
                    children: [
                      _FeeRow(
                        label: '${peso(widget.court.hourlyRate)} × $_duration hr',
                        value: peso(total),
                      ),
                      const Divider(height: 18),
                      _FeeRow(label: 'Total', value: peso(total), strong: true),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.lime.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_clock, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _holdNote(),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop(
                        BookingIntent(
                          facilityId: widget.venue.id,
                          courtId: widget.court.id,
                          date: widget.slot.date,
                          startHour: widget.slot.startHour,
                          durationHours: _duration,
                          paymentMethod: _method,
                        ),
                      );
                    },
                    child: Text(
                      user == null ? 'Sign in & confirm' : 'Confirm reservation',
                    ),
                  ),
                ),
                if (user == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Center(
                      child: Text(
                        'Guest checkout resumes right after sign-in.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.black54,
                            ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _holdNote() {
    if (_method == PaymentMethod.cash) {
      return 'Pay-at-desk hold: ${widget.venue.cashHoldMinutes} minutes, capped at the slot start.';
    }
    if (_method == PaymentMethod.ewallet) {
      return 'A 15-minute hold starts now. Upload your transfer reference to keep it.';
    }
    return 'A 15-minute hold starts now. Demo checkout confirms instantly.';
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.method,
    required this.selected,
    required this.onTap,
  });

  final PaymentMethod method;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = switch (method) {
      PaymentMethod.online => Icons.credit_card,
      PaymentMethod.ewallet => Icons.account_balance_wallet_outlined,
      PaymentMethod.cash => Icons.payments_outlined,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? AppTheme.evergreen.withValues(alpha: 0.06) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? AppTheme.evergreen : Colors.black.withValues(alpha: 0.08),
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: selected ? AppTheme.evergreen : Colors.black54),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        method.label,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        method.description,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.black54,
                            ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  selected ? Icons.check_circle : Icons.circle_outlined,
                  color: selected ? AppTheme.evergreen : Colors.black26,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.black54),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Colors.black54)),
        const Spacer(),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _FeeRow extends StatelessWidget {
  const _FeeRow({required this.label, required this.value, this.strong = false});

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final style = strong
        ? Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)
        : Theme.of(context).textTheme.bodyMedium;
    return Row(
      children: [
        Text(label, style: style),
        const Spacer(),
        Text(value, style: style),
      ],
    );
  }
}
