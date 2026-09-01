import 'package:sqflite/sqflite.dart';

class MigrationV1 {
  static const int version = 1;

  static Future<void> run(Batch batch) async {
    batch.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS profiles (
        user_id TEXT PRIMARY KEY,
        auth_user_id TEXT NOT NULL,
        role_code TEXT NOT NULL DEFAULT 'user',
        account_status_code TEXT NOT NULL DEFAULT 'active',
        nickname TEXT NOT NULL,
        sex_code TEXT NOT NULL,
        age INTEGER NOT NULL,
        height_cm REAL NOT NULL,
        current_weight_kg REAL NOT NULL,
        target_weight_kg REAL,
        activity_level_code TEXT NOT NULL,
        fitness_goal_code TEXT NOT NULL,
        daily_budget_php REAL NOT NULL,
        onboarding_completed INTEGER NOT NULL DEFAULT 0,
        allergies TEXT,
        dietary_restrictions TEXT,
        disclaimer_accepted INTEGER NOT NULL DEFAULT 0,
        disclaimer_version TEXT,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS nutrition_targets (
        target_id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        formula_version_code TEXT NOT NULL,
        fitness_goal_code TEXT NOT NULL,
        source_weight_log_id TEXT,
        bmr REAL NOT NULL,
        tdee REAL NOT NULL,
        calorie_target INTEGER NOT NULL,
        protein_target_g REAL NOT NULL,
        carbs_target_g REAL NOT NULL,
        fat_target_g REAL NOT NULL,
        water_target_ml INTEGER NOT NULL,
        daily_budget_php REAL NOT NULL DEFAULT 0,
        effective_from TEXT NOT NULL,
        effective_to TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (user_id) REFERENCES profiles(user_id)
      )
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS daily_target_snapshots (
        snapshot_id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        nutrition_target_id TEXT NOT NULL,
        target_date TEXT NOT NULL,
        calorie_target_snapshot INTEGER NOT NULL,
        protein_target_g_snapshot REAL NOT NULL,
        carbs_target_g_snapshot REAL NOT NULL,
        fat_target_g_snapshot REAL NOT NULL,
        water_target_ml_snapshot INTEGER NOT NULL,
        daily_budget_php_snapshot REAL NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        UNIQUE(user_id, target_date),
        FOREIGN KEY (user_id) REFERENCES profiles(user_id)
      )
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS foods (
        food_id TEXT PRIMARY KEY,
        category_name TEXT NOT NULL,
        subcategory TEXT,
        owner_user_id TEXT,
        food_name TEXT NOT NULL,
        normalized_name TEXT NOT NULL,
        is_local_food INTEGER NOT NULL DEFAULT 0,
        is_official INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        serving_id TEXT,
        serving_label TEXT,
        serving_grams REAL,
        calories REAL NOT NULL,
        protein_g REAL NOT NULL,
        carbs_g REAL NOT NULL,
        fat_g REAL NOT NULL,
        estimated_price_php REAL NOT NULL,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        sync_status TEXT DEFAULT 'synced',
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    batch.execute('''
      CREATE INDEX IF NOT EXISTS idx_foods_search ON foods(normalized_name)
    ''');

    batch.execute('''
      CREATE INDEX IF NOT EXISTS idx_foods_category ON foods(category_name)
    ''');

    batch.execute('''
      CREATE INDEX IF NOT EXISTS idx_foods_user ON foods(owner_user_id)
    ''');

    batch.execute('''
      CREATE INDEX IF NOT EXISTS idx_foods_sync_status ON foods(sync_status)
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS meal_logs (
        meal_log_id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        food_id TEXT,
        meal_type_code TEXT NOT NULL,
        log_source_code TEXT NOT NULL,
        food_name_snapshot TEXT NOT NULL,
        serving_grams_snapshot REAL NOT NULL,
        quantity REAL NOT NULL,
        calories_snapshot REAL NOT NULL,
        protein_g_snapshot REAL NOT NULL,
        carbs_g_snapshot REAL NOT NULL,
        fat_g_snapshot REAL NOT NULL,
        cost_php_snapshot REAL NOT NULL,
        logged_at TEXT NOT NULL,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (user_id) REFERENCES profiles(user_id)
      )
    ''');

    batch.execute('''
      CREATE INDEX IF NOT EXISTS idx_meal_logs_user_date ON meal_logs(user_id, logged_at)
    ''');

    batch.execute('''
      CREATE INDEX IF NOT EXISTS idx_meal_logs_active ON meal_logs(user_id) WHERE is_deleted = 0
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS water_logs (
        water_log_id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        amount_ml INTEGER NOT NULL,
        logged_at TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (user_id) REFERENCES profiles(user_id)
      )
    ''');

    batch.execute('''
      CREATE INDEX IF NOT EXISTS idx_water_logs_user_date ON water_logs(user_id, logged_at)
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS weight_logs (
        weight_log_id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        weight_kg REAL NOT NULL,
        logged_at TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (user_id) REFERENCES profiles(user_id)
      )
    ''');

    batch.execute('''
      CREATE INDEX IF NOT EXISTS idx_weight_logs_user_date ON weight_logs(user_id, logged_at DESC)
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS meal_plans (
        meal_plan_id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        food_id TEXT,
        meal_type_code TEXT NOT NULL,
        status_code TEXT NOT NULL DEFAULT 'planned',
        converted_meal_log_id TEXT,
        food_name_snapshot TEXT NOT NULL,
        serving_grams_snapshot REAL NOT NULL,
        quantity REAL NOT NULL,
        calories_snapshot REAL NOT NULL,
        protein_g_snapshot REAL NOT NULL,
        carbs_g_snapshot REAL NOT NULL,
        fat_g_snapshot REAL NOT NULL,
        cost_php_snapshot REAL NOT NULL,
        planned_date TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (user_id) REFERENCES profiles(user_id)
      )
    ''');

    batch.execute('''
      CREATE INDEX IF NOT EXISTS idx_meal_plans_user_date ON meal_plans(user_id, planned_date)
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS recommendation_sessions (
        session_id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        remaining_budget_php REAL NOT NULL,
        remaining_calories INTEGER NOT NULL,
        remaining_protein_g REAL NOT NULL,
        remaining_carbs_g REAL NOT NULL,
        remaining_fat_g REAL NOT NULL,
        generated_at TEXT NOT NULL DEFAULT (datetime('now')),
        sync_status TEXT NOT NULL DEFAULT 'pending',
        FOREIGN KEY (user_id) REFERENCES profiles(user_id)
      )
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS recommendation_items (
        recommendation_item_id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        food_id TEXT NOT NULL,
        linked_meal_log_id TEXT,
        linked_meal_plan_id TEXT,
        rank_number INTEGER NOT NULL,
        final_score REAL NOT NULL,
        affordability_score REAL NOT NULL,
        protein_fit_score REAL NOT NULL,
        calorie_fit_score REAL NOT NULL,
        macro_balance_score REAL NOT NULL,
        goal_match_score REAL NOT NULL,
        meal_type_score REAL NOT NULL,
        over_budget_penalty REAL NOT NULL DEFAULT 0,
        reason_text TEXT NOT NULL,
        was_accepted INTEGER NOT NULL DEFAULT 0,
        accepted_at TEXT,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        FOREIGN KEY (session_id) REFERENCES recommendation_sessions(session_id)
      )
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS ai_scans (
        scan_id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        scan_status_code TEXT NOT NULL,
        client_scan_id TEXT NOT NULL,
        image_path TEXT,
        raw_response_json TEXT,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        completed_at TEXT,
        FOREIGN KEY (user_id) REFERENCES profiles(user_id)
      )
    ''');

    batch.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_ai_scans_client ON ai_scans(user_id, client_scan_id)
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS ai_scan_predictions (
        prediction_id TEXT PRIMARY KEY,
        scan_id TEXT NOT NULL,
        food_id TEXT,
        predicted_food_name TEXT NOT NULL,
        confidence REAL NOT NULL,
        rank_number INTEGER NOT NULL,
        calories REAL,
        protein_g REAL,
        carbs_g REAL,
        fat_g REAL,
        estimated_cost_php REAL,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        FOREIGN KEY (scan_id) REFERENCES ai_scans(scan_id)
      )
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS ai_scan_feedback (
        feedback_id TEXT PRIMARY KEY,
        scan_id TEXT NOT NULL UNIQUE,
        selected_prediction_id TEXT,
        meal_log_id TEXT,
        confirmed_food_id TEXT,
        quantity REAL NOT NULL DEFAULT 1,
        meal_type_code TEXT,
        correction_reason TEXT,
        feedback_type TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        confirmed_at TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (scan_id) REFERENCES ai_scans(scan_id)
      )
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS chat_sessions (
        chat_session_id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        started_at TEXT NOT NULL DEFAULT (datetime('now')),
        ended_at TEXT,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        FOREIGN KEY (user_id) REFERENCES profiles(user_id)
      )
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS chat_messages (
        chat_message_id TEXT PRIMARY KEY,
        chat_session_id TEXT NOT NULL,
        role_code TEXT NOT NULL,
        safety_status_code TEXT NOT NULL DEFAULT 'safe',
        delivery_status_code TEXT NOT NULL DEFAULT 'local_saved',
        message_text TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        sent_at TEXT,
        FOREIGN KEY (chat_session_id) REFERENCES chat_sessions(chat_session_id)
      )
    ''');

    batch.execute('''
      CREATE INDEX IF NOT EXISTS idx_chat_messages_session ON chat_messages(chat_session_id, created_at)
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS community_cache (
        post_id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        author_nickname TEXT NOT NULL,
        body_text TEXT NOT NULL,
        is_hidden INTEGER NOT NULL DEFAULT 0,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        like_count INTEGER NOT NULL DEFAULT 0,
        comment_count INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        cached_at TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS sync_queue (
        sync_queue_id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        operation_id TEXT NOT NULL,
        entity_type_code TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        operation_code TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        changed_fields_json TEXT,
        client_sequence INTEGER NOT NULL,
        attempt_count INTEGER NOT NULL DEFAULT 0,
        last_error TEXT,
        depends_on_entity_type TEXT,
        depends_on_entity_id TEXT,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        server_synced_at TEXT,
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (user_id) REFERENCES profiles(user_id)
      )
    ''');

    batch.execute('''
      CREATE INDEX IF NOT EXISTS idx_sync_queue_status ON sync_queue(sync_status)
    ''');

    batch.execute('''
      CREATE INDEX IF NOT EXISTS idx_sync_queue_operation ON sync_queue(operation_id)
    ''');

    batch.execute('''
      CREATE INDEX IF NOT EXISTS idx_sync_queue_entity ON sync_queue(entity_id)
    ''');
  }
}
