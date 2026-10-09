// Archivo: lib/models/user_profile.dart

class UserProfile {
  final String name;
  final double weight;
  final double height;
  final int age;
  final String gender;
  final double activityMultiplier;
  final String goalType;
  final double calorieAdjustment;
  final double goalCalories;
  final double proteinTarget;
  final double carbTarget;
  final double fatTarget;

  UserProfile({
    required this.name, required this.weight, required this.height, required this.age,
    required this.gender, required this.activityMultiplier, required this.goalType,
    required this.calorieAdjustment, required this.goalCalories, required this.proteinTarget,
    required this.carbTarget, required this.fatTarget,
  });

  Map<String, dynamic> toJson() => {
    'name': name, 'weight': weight, 'height': height, 'age': age,
    'gender': gender, 'activityMultiplier': activityMultiplier, 'goalType': goalType,
    'calorieAdjustment': calorieAdjustment, 'goalCalories': goalCalories,
    'proteinTarget': proteinTarget, 'carbTarget': carbTarget, 'fatTarget': fatTarget,
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    name: json['name'] ?? 'Usuario', weight: json['weight'] ?? 0.0, height: json['height'] ?? 0.0,
    age: json['age'] ?? 0, gender: json['gender'] ?? 'Masculino', activityMultiplier: json['activityMultiplier'] ?? 1.2,
    goalType: json['goalType'] ?? 'Dieta Keto', calorieAdjustment: json['calorieAdjustment'] ?? -800,
    goalCalories: json['goalCalories'] ?? 2000, proteinTarget: json['proteinTarget'] ?? 120,
    carbTarget: json['carbTarget'] ?? 30, fatTarget: json['fatTarget'] ?? 100,
  );
}