import 'dart:async';

import 'package:flutter/material.dart';

import '../utils/formatters.dart';

/// Live mm:ss countdown for a hold window. A null expiry renders as a paused
/// hold (payment review).
class HoldCountdown extends StatefulWidget {
  const HoldCountdown({
    super.key,
    required this.expiresAt,
    this.prefix = '',
    this.style,
  });

  final DateTime? expiresAt;
  final String prefix;
  final TextStyle? style;

  @override
  State<HoldCountdown> createState() => _HoldCountdownState();
}

class _HoldCountdownState extends State<HoldCountdown> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final expiresAt = widget.expiresAt;
    if (expiresAt == null) {
      return Text('${widget.prefix}Paused', style: widget.style);
    }
    final remaining = expiresAt.difference(DateTime.now());
    return Text(
      '${widget.prefix}${countdownLabel(remaining)}',
      style: widget.style,
    );
  }
}
