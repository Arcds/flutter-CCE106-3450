import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  static const _items = [
    (
      icon: Icons.qr_code_2,
      color: AppTheme.evergreen,
      title: 'Pass ready',
      body: 'Your payment was verified. The QR pass for Court 1 is now active.',
      time: '2 min ago',
    ),
    (
      icon: Icons.groups_outlined,
      color: Color(0xFF2F6B9A),
      title: 'Open play roster updated',
      body: 'Sunset Open Play is down to 3 open slots.',
      time: '18 min ago',
    ),
    (
      icon: Icons.lock_clock,
      color: Color(0xFFB26A00),
      title: 'Hold expiring soon',
      body: 'Upload your e-wallet reference to keep Court A at 6:00 PM.',
      time: '32 min ago',
    ),
    (
      icon: Icons.verified_outlined,
      color: AppTheme.evergreen,
      title: 'Booking verified',
      body: 'Davao Pickleball Club approved your transfer for Center Court.',
      time: 'Yesterday',
    ),
    (
      icon: Icons.event_busy_outlined,
      color: Color(0xFFB3261E),
      title: 'Schedule change',
      body: 'Court 2 closes at 6 PM this Saturday for league finals.',
      time: '2 days ago',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        itemCount: _items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final item = _items[index];
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: AppTheme.cardDecoration(),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(item.icon, size: 20, color: item.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          Text(
                            item.time,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.black45,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.body,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.black54,
                              height: 1.4,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
