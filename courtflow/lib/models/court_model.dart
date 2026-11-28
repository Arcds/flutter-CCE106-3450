class Court {
  const Court({
    required this.id,
    required this.name,
    required this.hourlyRate,
    this.isActive = true,
  });

  factory Court.fromMap(String id, Map<String, dynamic> data) {
    return Court(
      id: id,
      name: data['name'] as String? ?? id,
      hourlyRate: (data['hourlyRate'] as num?)?.toDouble() ?? 0,
      isActive: data['isActive'] as bool? ?? true,
    );
  }

  final String id;
  final String name;
  final double hourlyRate;
  final bool isActive;

  Court copyWith({
    String? name,
    double? hourlyRate,
    bool? isActive,
  }) {
    return Court(
      id: id,
      name: name ?? this.name,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      isActive: isActive ?? this.isActive,
    );
  }
}
