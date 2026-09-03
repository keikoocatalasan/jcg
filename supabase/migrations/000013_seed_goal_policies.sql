-- 000013: Seed goal calorie and macro policies

-- GOAL_CALORIE_POLICY
-- One policy per fitness goal
INSERT INTO GOAL_CALORIE_POLICY (fitness_goal_id, calorie_adjustment, is_active)
SELECT fitness_goal_id, -400, TRUE FROM FITNESS_GOAL WHERE goal_code = 'cutting'
ON CONFLICT (fitness_goal_id) DO NOTHING;

INSERT INTO GOAL_CALORIE_POLICY (fitness_goal_id, calorie_adjustment, is_active)
SELECT fitness_goal_id, 0, TRUE FROM FITNESS_GOAL WHERE goal_code = 'maintenance'
ON CONFLICT (fitness_goal_id) DO NOTHING;

INSERT INTO GOAL_CALORIE_POLICY (fitness_goal_id, calorie_adjustment, is_active)
SELECT fitness_goal_id, 400, TRUE FROM FITNESS_GOAL WHERE goal_code = 'bulking'
ON CONFLICT (fitness_goal_id) DO NOTHING;

INSERT INTO GOAL_CALORIE_POLICY (fitness_goal_id, calorie_adjustment, is_active)
SELECT fitness_goal_id, 200, TRUE FROM FITNESS_GOAL WHERE goal_code = 'lean'
ON CONFLICT (fitness_goal_id) DO NOTHING;

INSERT INTO GOAL_CALORIE_POLICY (fitness_goal_id, calorie_adjustment, is_active)
SELECT fitness_goal_id, 500, TRUE FROM FITNESS_GOAL WHERE goal_code = 'gain_weight'
ON CONFLICT (fitness_goal_id) DO NOTHING;

-- GOAL_MACRO_POLICY
-- Each goal has protein/carbs/fat percentages totaling 100
-- cutting: 30% protein, 45% carbs, 25% fat
INSERT INTO GOAL_MACRO_POLICY (fitness_goal_id, protein_pct, carbs_pct, fat_pct, is_active)
SELECT fitness_goal_id, 30, 45, 25, TRUE FROM FITNESS_GOAL WHERE goal_code = 'cutting'
ON CONFLICT (fitness_goal_id) DO NOTHING;

-- maintenance: 25% protein, 50% carbs, 25% fat
INSERT INTO GOAL_MACRO_POLICY (fitness_goal_id, protein_pct, carbs_pct, fat_pct, is_active)
SELECT fitness_goal_id, 25, 50, 25, TRUE FROM FITNESS_GOAL WHERE goal_code = 'maintenance'
ON CONFLICT (fitness_goal_id) DO NOTHING;

-- bulking: 30% protein, 50% carbs, 20% fat
INSERT INTO GOAL_MACRO_POLICY (fitness_goal_id, protein_pct, carbs_pct, fat_pct, is_active)
SELECT fitness_goal_id, 30, 50, 20, TRUE FROM FITNESS_GOAL WHERE goal_code = 'bulking'
ON CONFLICT (fitness_goal_id) DO NOTHING;

-- lean: 30% protein, 45% carbs, 25% fat
INSERT INTO GOAL_MACRO_POLICY (fitness_goal_id, protein_pct, carbs_pct, fat_pct, is_active)
SELECT fitness_goal_id, 30, 45, 25, TRUE FROM FITNESS_GOAL WHERE goal_code = 'lean'
ON CONFLICT (fitness_goal_id) DO NOTHING;

-- gain_weight: 25% protein, 55% carbs, 20% fat
INSERT INTO GOAL_MACRO_POLICY (fitness_goal_id, protein_pct, carbs_pct, fat_pct, is_active)
SELECT fitness_goal_id, 25, 55, 20, TRUE FROM FITNESS_GOAL WHERE goal_code = 'gain_weight'
ON CONFLICT (fitness_goal_id) DO NOTHING;
