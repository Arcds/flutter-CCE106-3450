import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/iterables.dart';
import '../../data/demo_store.dart';
import '../../models/booking_model.dart';
import '../../providers/app_providers.dart';

class QrScannerScreen extends ConsumerStatefulWidget {
  const QrScannerScreen({super.key});

  @override
  ConsumerState<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends ConsumerState<QrScannerScreen> {
  final _tokenController = TextEditingController();
  bool _torchOn = false;
  ScanResult? _result;

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final state = ref.watch(demoStoreProvider);
    final venue = firstWhereOrNull(
          state.venues,
          (candidate) => user != null && user.manages(candidate.id),
        ) ??
        state.venues.first;

    return Scaffold(
      backgroundColor: const Color(0xFF0B1512),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1512),
        foregroundColor: Colors.white,
        title: const Text(
          'Scan Pass',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        actions: [
          IconButton(
            tooltip: 'Toggle torch',
            onPressed: () => setState(() => _torchOn = !_torchOn),
            icon: Icon(_torchOn ? Icons.flashlight_on : Icons.flashlight_off),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(220, 220),
                    painter: _ReticlePainter(
                      color: _torchOn ? AppTheme.lime : Colors.white70,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.qr_code_scanner,
                        size: 48,
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Camera preview arrives in Phase 4',
                        style: TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              '${venue.name} · offline roster ready',
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Pass token',
            style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _tokenController,
            maxLines: 3,
            minLines: 1,
            style: const TextStyle(color: Colors.white, fontSize: 12),
            decoration: InputDecoration(
              hintText: 'Paste a CFDEMO token or use the demo pass button',
              hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () => _validate(venue.id),
                  child: const Text('Validate token'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.24)),
                  ),
                  onPressed: () => _useDemoToken(state.bookings, venue.id),
                  child: const Text('Use demo pass'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_result != null) _ResultBanner(result: _result!),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'Demo checks: token format, club match, payment status, validity window '
              'and duplicate check-in. Real Ed25519 signature verification replaces the '
              'CFDEMO format in Phase 4.',
              style: TextStyle(color: Colors.white38, fontSize: 11, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  void _useDemoToken(List<Booking> bookings, String facilityId) {
    final booking = firstWhereOrNull(
      bookings,
      (candidate) =>
          candidate.facilityId == facilityId &&
          candidate.status == BookingStatus.verified &&
          candidate.qrToken != null,
    );
    if (booking == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No verified pass for this club yet.')),
      );
      return;
    }
    setState(() {
      _tokenController.text = booking.qrToken!;
      _result = null;
    });
  }

  void _validate(String facilityId) {
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paste a token first.')),
      );
      return;
    }
    final result = ref.read(demoStoreProvider.notifier).scanToken(
          token: token,
          facilityId: facilityId,
        );
    setState(() => _result = result);
  }
}

class _ResultBanner extends StatelessWidget {
  const _ResultBanner({required this.result});

  final ScanResult result;

  @override
  Widget build(BuildContext context) {
    final color = switch (result.outcome) {
      ScanOutcome.valid => AppTheme.lime,
      ScanOutcome.alreadyCheckedIn => const Color(0xFF8AB4F8),
      ScanOutcome.unverified => const Color(0xFFFFC46B),
      _ => const Color(0xFFFF8A80),
    };
    final icon = result.isSuccess ? Icons.check_circle : Icons.error_outline;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.isSuccess ? 'Valid pass' : 'Scan rejected',
                  style: TextStyle(color: color, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  result.message,
                  style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReticlePainter extends CustomPainter {
  const _ReticlePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const corner = 34.0;
    final left = 0.0;
    final top = 0.0;
    final right = size.width;
    final bottom = size.height;

    canvas.drawPath(
      Path()
        ..moveTo(left, top + corner)
        ..lineTo(left, top)
        ..lineTo(left + corner, top),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(right - corner, top)
        ..lineTo(right, top)
        ..lineTo(right, top + corner),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(left, bottom - corner)
        ..lineTo(left, bottom)
        ..lineTo(left + corner, bottom),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(right - corner, bottom)
        ..lineTo(right, bottom)
        ..lineTo(right, bottom - corner),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _ReticlePainter oldDelegate) =>
      oldDelegate.color != color;
}
