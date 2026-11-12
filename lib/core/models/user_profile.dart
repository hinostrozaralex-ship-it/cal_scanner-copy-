import 'dart:convert';

class UserProfile {
  final String name;
  final int age;
  final double weight;
  final double height;
  final String unitSystem; // 'metric' o 'imperial'
  final String gender; // 'Male' o 'Female'
  final String goal; // 'Weight Loss', 'Maintenance', 'Muscle Gain'
  final double targetWeight;
  final int goalWeeks;
  final String? apiKey;
  final bool isOnboarded;

  const UserProfile({
    required this.name,
    required this.age,
    required this.weight,
    required this.height,
    this.unitSystem = 'metric',
    this.gender = 'Male',
    this.goal = 'Maintenance',
    double? targetWeight,
    this.goalWeeks = 8,
    this.apiKey,
    this.isOnboarded = false,
  }) : targetWeight = targetWeight ?? weight;

  UserProfile copyWith({
    String? name,
    int? age,
    double? weight,
    double? height,
    String? unitSystem,
    String? gender,
    String? goal,
    double? targetWeight,
    int? goalWeeks,
    String? apiKey,
    bool? isOnboarded,
  }) {
    return UserProfile(
      name: name ?? this.name,
      age: age ?? this.age,
      weight: weight ?? this.weight,
      height: height ?? this.height,
      unitSystem: unitSystem ?? this.unitSystem,
      gender: gender ?? this.gender,
      goal: goal ?? this.goal,
      targetWeight: targetWeight ?? this.targetWeight,
      goalWeeks: goalWeeks ?? this.goalWeeks,
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
      'gender': gender,
      'goal': goal,
      'targetWeight': targetWeight,
      'goalWeeks': goalWeeks,
      'apiKey': apiKey,
      'isOnboarded': isOnboarded,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    final parsedWeight = (map['weight'] as num?)?.toDouble() ?? 70.0;
    return UserProfile(
      name: (map['name'] as String?) ?? '',
      age: (map['age'] as num?)?.toInt() ?? 25,
      weight: parsedWeight,
      height: (map['height'] as num?)?.toDouble() ?? 170.0,
      unitSystem: (map['unitSystem'] as String?) ?? 'metric',
      gender: (map['gender'] as String?) ?? 'Male',
      goal: (map['goal'] as String?) ?? 'Maintenance',
      targetWeight: (map['targetWeight'] as num?)?.toDouble() ?? parsedWeight,
      goalWeeks: (map['goalWeeks'] as num?)?.toInt() ?? 8,
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
