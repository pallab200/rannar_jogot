import 'dart:ui';

class CategoryModel {
  final String id;
  final String nameEn;
  final String icon;
  final List<Color> gradientColors;
  final List<String> keywords;
  int videoCount;

  CategoryModel({
    required this.id,
    required this.nameEn,
    required this.icon,
    required this.gradientColors,
    required this.keywords,
    this.videoCount = 0,
  });

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    final gradientHexList = map['gradient'] as List<dynamic>;
    return CategoryModel(
      id: map['id'] as String,
      nameEn: map['nameEn'] as String,
      icon: map['icon'] as String,
      gradientColors: gradientHexList
          .map((hex) => Color(int.parse(hex as String)))
          .toList(),
      keywords: List<String>.from(map['keywords'] as List<dynamic>),
    );
  }
}
