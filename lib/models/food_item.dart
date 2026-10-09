class FoodItem {
  final String name;
  final String category;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final String? imagePath;

  FoodItem({
    required this.name,
    required this.category,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.imagePath,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'category': category,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'imagePath': imagePath,
      };

  factory FoodItem.fromJson(Map<String, dynamic> json) => FoodItem(
        name: json['name'],
        category: json['category'],
        calories: json['calories'],
        protein: json['protein'],
        carbs: json['carbs'],
        fat: json['fat'],
        imagePath: json['imagePath'],
      );
}