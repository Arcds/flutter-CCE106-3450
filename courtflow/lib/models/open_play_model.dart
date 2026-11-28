class OpenPlaySession {
  const OpenPlaySession({
    required this.id,
    required this.facilityId,
    required this.facilityName,
    required this.title,
    required this.skillTier,
    required this.date,
    required this.timeWindow,
    required this.entryFee,
    required this.maxCapacity,
    required this.participantIds,
  });

  factory OpenPlaySession.fromMap(String id, Map<String, dynamic> data) {
    return OpenPlaySession(
      id: id,
      facilityId: data['facilityId'] as String? ?? '',
      facilityName: data['facilityName'] as String? ??
          data['facilityId'] as String? ??
          '',
      title: data['title'] as String? ?? 'Open Play',
      skillTier: data['skillTier'] as String? ?? 'All Levels',
      date: data['date'] as String? ?? '',
      timeWindow: data['timeWindow'] as String? ?? '',
      entryFee: (data['entryFee'] as num?)?.toDouble() ?? 0,
      maxCapacity: (data['maxCapacity'] as num?)?.toInt() ?? 0,
      participantIds: [
        for (final participant in (data['participantIds'] as List<dynamic>? ?? const []))
          '$participant',
      ],
    );
  }

  final String id;
  final String facilityId;
  final String facilityName;
  final String title;
  final String skillTier;
  final String date;
  final String timeWindow;
  final double entryFee;
  final int maxCapacity;
  final List<String> participantIds;

  int get currentCount => participantIds.length;

  bool get isFull => currentCount >= maxCapacity;

  int get spotsLeft => (maxCapacity - currentCount).clamp(0, maxCapacity);

  double get fillRatio =>
      maxCapacity == 0 ? 0 : (currentCount / maxCapacity).clamp(0, 1).toDouble();

  bool hasParticipant(String uid) => participantIds.contains(uid);

  OpenPlaySession copyWith({List<String>? participantIds}) {
    return OpenPlaySession(
      id: id,
      facilityId: facilityId,
      facilityName: facilityName,
      title: title,
      skillTier: skillTier,
      date: date,
      timeWindow: timeWindow,
      entryFee: entryFee,
      maxCapacity: maxCapacity,
      participantIds: participantIds ?? this.participantIds,
    );
  }
}
