import 'dart:convert';

class UserProfile {
  final String name;
  final int age;
  final double weight;
  final double height;
  final String unitSystem; // 'metric' o 'imperial'
  final String? apiKey;
  final bool isOnboarded;

  const UserProfile({
    required this.name,
    required this.age,
    required this.weight,
    required this.height,
    this.unitSystem = 'metric',
    this.apiKey,
    this.isOnboarded = false,
  });

  UserProfile copyWith({
    String? name,
    int? age,
    double? weight,
    double? height,
    String? unitSystem,
    String? apiKey,
    bool? isOnboarded,
  }) {
    return UserProfile(
      name: name ?? this.name,
      age: age ?? this.age,
      weight: weight ?? this.weight,
      height: height ?? this.height,
      unitSystem: unitSystem ?? this.unitSystem,
      apiKey: apiKey ?? this.apiKey,
      isOnboarded: isOnboarded ?? this.isOnboarded,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'age': age,
      'weight': weight,
      'height': height,
      'unitSystem': unitSystem,
      'apiKey': apiKey,
      'isOnboarded': isOnboarded,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      name: (map['name'] as String?) ?? '',
      age: (map['age'] as num?)?.toInt() ?? 25,
      weight: (map['weight'] as num?)?.toDouble() ?? 70.0,
      height: (map['height'] as num?)?.toDouble() ?? 170.0,
      unitSystem: (map['unitSystem'] as String?) ?? 'metric',
      apiKey: map['apiKey'] as String?,
      isOnboarded: (map['isOnboarded'] as bool?) ?? false,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory UserProfile.fromJson(dynamic source) {
    if (source is String) {
      return UserProfile.fromMap(
        Map<String, dynamic>.from(jsonDecode(source) as Map),
      );
    }
    if (source is Map) {
      return UserProfile.fromMap(Map<String, dynamic>.from(source));
    }
    throw ArgumentError('Invalid source for UserProfile.fromJson: $source');
  }
}
