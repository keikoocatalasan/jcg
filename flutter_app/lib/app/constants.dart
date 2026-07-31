class AppConstants {
  static const String appName = 'JCG Fitness';
  static const String version = '1.0.0';

  // Validation
  static const int minNicknameLength = 2;
  static const int maxNicknameLength = 30;
  static const int minAge = 13;
  static const int maxAge = 80;
  static const double minHeightCm = 100;
  static const double maxHeightCm = 250;
  static const double minWeightKg = 20;
  static const double maxWeightKg = 300;
  static const double minBudgetPhp = 20;
  static const int maxWaterMlPerEntry = 5000;
  static const int minWaterMlPerEntry = 1;

  // Water presets (ml)
  static const List<int> waterPresets = [250, 500, 750, 1000];

  // Macro conversion
  static const double caloriesPerGramProtein = 4;
  static const double caloriesPerGramCarbs = 4;
  static const double caloriesPerGramFat = 9;

  // Hydration formula
  static const double waterPerKgWeight = 35;

  // Food search
  static const int minSearchQueryLength = 2;
  static const int maxSearchResults = 50;

  // Sync
  static const int maxSyncRetries = 5;
  static const List<int> syncRetryDelaysMs = [0, 5000, 30000, 120000, 600000];

  // AI scanner
  static const int maxImageSizeMb = 5;
  static const int minImageDimension = 224;
  static const double highConfidenceThreshold = 0.80;
  static const double mediumConfidenceThreshold = 0.60;

  // Storage keys
  static const String onboardingCompleteKey = 'onboarding_complete';
  static const String lastSyncKey = 'last_sync_at';
  static const String userSessionKey = 'user_session';

  // Routes
  static const String loginRoute = '/login';
  static const String registerRoute = '/register';
  static const String forgotPasswordRoute = '/forgot-password';
  static const String termsRoute = '/terms';
  static const String privacyRoute = '/privacy';
  static const String onboardingRoute = '/onboarding';
  static const String dashboardRoute = '/dashboard';
  static const String foodSearchRoute = '/food-search';
  static const String mealLogRoute = '/meal-log';
  static const String hydrationRoute = '/hydration';
  static const String weightRoute = '/weight';
  static const String recommendationRoute = '/recommendations';
  static const String plannerRoute = '/planner';
  static const String aiScannerRoute = '/ai-scanner';
  static const String chatbotRoute = '/chatbot';
  static const String analyticsRoute = '/analytics';
  static const String communityRoute = '/community';
  static const String profileRoute = '/profile';
  static const String adminRoute = '/admin';
}
