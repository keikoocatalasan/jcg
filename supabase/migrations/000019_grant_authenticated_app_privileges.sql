-- RLS decides which rows authenticated users may access; grants allow PostgREST
-- to issue the corresponding statements.
GRANT SELECT ON public.role, public.account_status, public.sex,
  public.activity_level, public.fitness_goal, public.meal_type,
  public.log_source, public.meal_plan_status, public.allergy,
  public.dietary_restriction, public.food_category, public.data_source,
  public.nutrition_formula_version, public.ai_scan_status,
  public.chat_role, public.chat_safety_status, public.chat_delivery_status,
  public.report_reason, public.report_status, public.moderation_action_type,
  public.sync_entity_type, public.sync_operation_type, public.sync_status
TO authenticated;

GRANT SELECT, INSERT, UPDATE, DELETE ON
  public.user_profile,
  public.medical_disclaimer_acceptance,
  public.user_allergy,
  public.user_dietary_restriction,
  public.nutrition_target,
  public.daily_target_snapshot,
  public.meal_log,
  public.water_log,
  public.weight_log,
  public.meal_plan,
  public.recommendation_session,
  public.recommendation_item,
  public.ai_scan,
  public.ai_scan_prediction,
  public.ai_scan_confirmation,
  public.chat_session,
  public.chat_message,
  public.chat_message_context,
  public.device,
  public.sync_queue
TO authenticated;

GRANT SELECT ON public.food_item, public.food_nutrition_profile,
  public.food_serving, public.food_price
TO authenticated;
