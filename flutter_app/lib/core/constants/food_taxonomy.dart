class FoodTaxonomy {
  FoodTaxonomy._();

  static const categories = <String>[
    'Rice and Grains',
    'Meat and Poultry',
    'Seafood',
    'Vegetables',
    'Fruits',
    'Dairy and Eggs',
    'Bread and Pastry',
    'Soups and Porridge',
    'Beverages',
    'Snacks and Desserts',
    'Legumes and Tofu',
    'Condiments and Spreads',
  ];

  static const mealTypeCodes = <String>[
    'breakfast',
    'lunch',
    'dinner',
    'snack',
  ];

  static const fallbackMealTypesByCategory = <String, Set<String>>{
    'Rice and Grains': {'breakfast', 'lunch', 'dinner'},
    'Meat and Poultry': {'lunch', 'dinner'},
    'Seafood': {'lunch', 'dinner'},
    'Vegetables': {'lunch', 'dinner'},
    'Fruits': {'breakfast', 'snack'},
    'Dairy and Eggs': {'breakfast', 'snack'},
    'Bread and Pastry': {'breakfast', 'snack'},
    'Soups and Porridge': {'breakfast', 'lunch', 'dinner'},
    'Beverages': {'breakfast', 'snack'},
    'Snacks and Desserts': {'snack'},
    'Legumes and Tofu': {'lunch', 'dinner'},
    'Condiments and Spreads': {'breakfast', 'lunch', 'dinner', 'snack'},
  };

  static List<String> parseMealTypeCodes(Object? raw) {
    final values = raw is Iterable
        ? raw.map((value) => value.toString())
        : (raw?.toString() ?? '').split(',');
    return values
        .map((value) => value.trim().toLowerCase())
        .where(mealTypeCodes.contains)
        .toSet()
        .toList()
      ..sort();
  }

  static Set<String> suitableMealTypes({
    required String categoryName,
    required List<String> explicitCodes,
  }) {
    if (explicitCodes.isNotEmpty) return explicitCodes.toSet();
    return fallbackMealTypesByCategory[categoryName] ?? const <String>{};
  }

  static String normalizeAllergyCode(String value) {
    final normalized = _normalize(value);
    return const {
          'dairy': 'milk',
          'peanuts': 'peanut',
          'tree nut': 'tree_nut',
          'tree nuts': 'tree_nut',
          'shell fish': 'shellfish',
        }[normalized] ??
        normalized.replaceAll(' ', '_');
  }

  static String normalizeRestrictionCode(String value) {
    final normalized = _normalize(value);
    return const {
          'gluten-free': 'gluten_free',
          'low carb': 'low_carb',
          'low fat': 'low_fat',
          'low sodium': 'low_sodium',
          'lactose intolerant': 'lactose_intolerant',
          'diabetic-friendly': 'diabetic',
          'no pork': 'no_pork',
          'no beef': 'no_beef',
        }[normalized] ??
        normalized.replaceAll(RegExp(r'[-\s]+'), '_');
  }

  static String _normalize(String value) => value.trim().toLowerCase();
}
