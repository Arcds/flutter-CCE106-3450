import 'court_model.dart';

/// Payment methods are deliberately gateway-free for Phase 1: `online` is a
/// simulated success, `ewallet` is staff-reviewed, `cash` is paid at the desk.
enum PaymentMethod { online, ewallet, cash }

extension PaymentMethodX on PaymentMethod {
  String get label => switch (this) {
        PaymentMethod.online => 'Pay Online',
        PaymentMethod.ewallet => 'E-Wallet Transfer',
        PaymentMethod.cash => 'Pay at Desk',
      };

  String get description => switch (this) {
        PaymentMethod.online => 'Demo checkout confirms instantly.',
        PaymentMethod.ewallet => 'Send transfer, then upload your reference.',
        PaymentMethod.cash => 'Pay the front desk on arrival.',
      };
}

class Venue {
  const Venue({
    required this.id,
    required this.name,
    required this.slug,
    required this.location,
    required this.courts,
    required this.openHour,
    required this.closeHour,
    this.rules = '',
    this.announcements = '',
    this.paymentInstructions = '',
    this.acceptedPaymentMethods = const [
      PaymentMethod.online,
      PaymentMethod.ewallet,
      PaymentMethod.cash,
    ],
    this.cashHoldMinutes = 120,
    this.publicDirectoryVisible = true,
    this.subscriptionTier = 'Starter',
  });

  factory Venue.fromMap(
    String id,
    Map<String, dynamic> data, {
    List<Court> courts = const [],
  }) {
    final hours = data['operatingHours'];
    final open = hours is Map ? _parseHour(hours['open']) : 6;
    final close = hours is Map ? _parseHour(hours['close']) : 22;
    final methods = <PaymentMethod>[];
    for (final raw in (data['acceptedPaymentMethods'] as List<dynamic>? ?? const [])) {
      for (final method in PaymentMethod.values) {
        if (method.name == raw) methods.add(method);
      }
    }
    return Venue(
      id: id,
      name: data['name'] as String? ?? id,
      slug: data['slug'] as String? ?? id,
      location: data['location'] as String? ?? '',
      courts: courts,
      openHour: open,
      closeHour: close,
      rules: data['rules'] as String? ?? '',
      announcements: data['announcements'] as String? ?? '',
      paymentInstructions: data['paymentInstructions'] as String? ?? '',
      acceptedPaymentMethods: methods.isEmpty
          ? const [PaymentMethod.online, PaymentMethod.ewallet, PaymentMethod.cash]
          : methods,
      cashHoldMinutes: (data['cashHoldMinutes'] as num?)?.toInt() ?? 120,
      publicDirectoryVisible: data['publicDirectoryVisible'] as bool? ?? false,
      subscriptionTier: data['subscriptionTier'] as String? ?? 'Starter',
    );
  }

  static int _parseHour(Object? value) {
    final text = value?.toString() ?? '';
    final hour = int.tryParse(text.split(':').first);
    return (hour ?? 6).clamp(0, 23);
  }

  final String id;
  final String name;
  final String slug;
  final String location;
  final List<Court> courts;
  final int openHour;
  final int closeHour;
  final String rules;
  final String announcements;
  final String paymentInstructions;
  final List<PaymentMethod> acceptedPaymentMethods;
  final int cashHoldMinutes;
  final bool publicDirectoryVisible;
  final String subscriptionTier;

  double get lowestRate =>
      courts.isEmpty ? 0 : courts.map((c) => c.hourlyRate).reduce((a, b) => a < b ? a : b);

  double get highestRate =>
      courts.isEmpty ? 0 : courts.map((c) => c.hourlyRate).reduce((a, b) => a > b ? a : b);

  String get operatingHoursLabel => '${_hour(openHour)} – ${_hour(closeHour)}';

  Court? courtById(String id) {
    for (final court in courts) {
      if (court.id == id) return court;
    }
    return null;
  }

  Venue copyWith({
    String? name,
    String? location,
    List<Court>? courts,
    String? announcements,
    List<PaymentMethod>? acceptedPaymentMethods,
    int? cashHoldMinutes,
    bool? publicDirectoryVisible,
  }) {
    return Venue(
      id: id,
      name: name ?? this.name,
      slug: slug,
      location: location ?? this.location,
      courts: courts ?? this.courts,
      openHour: openHour,
      closeHour: closeHour,
      rules: rules,
      announcements: announcements ?? this.announcements,
      paymentInstructions: paymentInstructions,
      acceptedPaymentMethods: acceptedPaymentMethods ?? this.acceptedPaymentMethods,
      cashHoldMinutes: cashHoldMinutes ?? this.cashHoldMinutes,
      publicDirectoryVisible: publicDirectoryVisible ?? this.publicDirectoryVisible,
      subscriptionTier: subscriptionTier,
    );
  }

  static String _hour(int hour) {
    final suffix = hour < 12 ? 'AM' : 'PM';
    final display = hour % 12 == 0 ? 12 : hour % 12;
    return '$display $suffix';
  }
}
