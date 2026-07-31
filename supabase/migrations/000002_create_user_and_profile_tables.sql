-- 000002: User, profile, medical disclaimer, allergies, restrictions

CREATE TABLE IF NOT EXISTS APP_USER (
  user_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  auth_user_id UUID NOT NULL UNIQUE,
  role_id SMALLINT NOT NULL REFERENCES ROLE(role_id) DEFAULT 1,
  account_status_id SMALLINT NOT NULL REFERENCES ACCOUNT_STATUS(account_status_id) DEFAULT 1,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_app_user_auth_id ON APP_USER(auth_user_id);
CREATE INDEX idx_app_user_status ON APP_USER(account_status_id);

CREATE TABLE IF NOT EXISTS USER_PROFILE (
  profile_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE REFERENCES APP_USER(user_id) ON DELETE CASCADE,
  sex_id SMALLINT NOT NULL REFERENCES SEX(sex_id),
  activity_level_id SMALLINT NOT NULL REFERENCES ACTIVITY_LEVEL(activity_level_id),
  fitness_goal_id SMALLINT NOT NULL REFERENCES FITNESS_GOAL(fitness_goal_id),
  nickname TEXT NOT NULL CHECK (char_length(nickname) >= 2 AND char_length(nickname) <= 30),
  age SMALLINT NOT NULL CHECK (age >= 13 AND age <= 80),
  height_cm NUMERIC(5,1) NOT NULL CHECK (height_cm >= 100 AND height_cm <= 250),
  current_weight_kg NUMERIC(5,1) NOT NULL CHECK (current_weight_kg >= 20 AND current_weight_kg <= 300),
  target_weight_kg NUMERIC(5,1) CHECK (target_weight_kg >= 20 AND target_weight_kg <= 300),
  daily_budget_php NUMERIC(8,2) NOT NULL CHECK (daily_budget_php >= 20),
  onboarding_completed BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_user_profile_user ON USER_PROFILE(user_id);

CREATE TABLE IF NOT EXISTS MEDICAL_DISCLAIMER_ACCEPTANCE (
  acceptance_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES APP_USER(user_id) ON DELETE CASCADE,
  accepted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  disclaimer_version TEXT NOT NULL
);

CREATE INDEX idx_medical_disclaimer_user ON MEDICAL_DISCLAIMER_ACCEPTANCE(user_id);

CREATE TABLE IF NOT EXISTS USER_ALLERGY (
  user_allergy_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES APP_USER(user_id) ON DELETE CASCADE,
  allergy_id SMALLINT NOT NULL REFERENCES ALLERGY(allergy_id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_user_allergy UNIQUE (user_id, allergy_id)
);

CREATE INDEX idx_user_allergy_user ON USER_ALLERGY(user_id);

CREATE TABLE IF NOT EXISTS USER_DIETARY_RESTRICTION (
  user_restriction_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES APP_USER(user_id) ON DELETE CASCADE,
  restriction_id SMALLINT NOT NULL REFERENCES DIETARY_RESTRICTION(restriction_id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_user_restriction UNIQUE (user_id, restriction_id)
);

CREATE INDEX idx_user_restriction_user ON USER_DIETARY_RESTRICTION(user_id);

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_app_user_updated_at
  BEFORE UPDATE ON APP_USER
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trg_user_profile_updated_at
  BEFORE UPDATE ON USER_PROFILE
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
