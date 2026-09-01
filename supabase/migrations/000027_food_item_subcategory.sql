-- 000027: Add subcategory to FOOD_ITEM
-- Supports the admin food form's subcategory field

ALTER TABLE FOOD_ITEM ADD COLUMN IF NOT EXISTS subcategory TEXT;
