CREATE OR REPLACE VIEW public.food_catalog
WITH (security_invoker = true)
AS
SELECT f.food_id, c.category_name, f.owner_user_id, f.food_name,
  f.normalized_name, f.is_local_food, f.is_official, f.is_active,
  s.serving_id, s.serving_label, s.serving_grams,
  n.calories, n.protein_g, n.carbs_g, n.fat_g,
  COALESCE(p.estimated_price_php, 0) AS estimated_price_php,
  f.created_at, f.updated_at
FROM public.food_item f
JOIN public.food_category c ON c.category_id = f.category_id
JOIN public.food_serving s ON s.food_id = f.food_id AND s.is_default AND s.is_active
JOIN public.food_nutrition_profile n
  ON n.food_id = f.food_id AND n.serving_id = s.serving_id AND n.is_active
LEFT JOIN public.food_price p
  ON p.food_id = f.food_id AND p.serving_id = s.serving_id AND p.is_active
WHERE f.is_active;

GRANT SELECT ON public.food_catalog TO authenticated;
