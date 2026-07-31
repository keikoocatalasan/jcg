# NutriSmart AI — Thesis Defense Demo Script

> Presenter walks through each step in order. Read the **bold** text aloud.  
> Perform each action on the device as you describe it.

---

### 1. Register New User
**"First, I'll register a fresh account. Tap 'Register' and enter email, password, and confirm."**

- Demo email: `defense@nutrismart.ph`
- Password: `Demo123!`

### 2. Complete Onboarding (7 screens)
**"The app walks you through setup — nickname, goal, disclaimer, allergies, stats, budget, and a review screen."**

- Tap through each screen:
  1. Nickname → "Defense User"
  2. Goal → "Maintain Weight"
  3. Disclaimer → check acknowledgment
  4. Allergies → select "Peanuts", "Shellfish"
  5. Stats → Age 22, Height 165 cm, Weight 58 kg, Activity "Moderate"
  6. Budget → ₱150.00
  7. Review → tap "Confirm"

### 3. Show Calculated Nutrition Targets
**"After onboarding, the app calculates my personalized nutrition targets based on my stats."**

- Point to: calorie goal, protein, carbs, fat targets on dashboard

### 4. Search Filipino Food Offline
**"The food database is bundled locally, so I can search even without internet."**

- Enable airplane mode
- Type "adobo" in search bar
- Show results loading from local SQLite

### 5. Log Meal Manually
**"I tap a food item, adjust the serving, and see the nutrition snapshot update in real time."**

- Select "Chicken Adobo"
- Serving: 1 cup (shown: ~480 kcal, 35g protein, etc.)
- Tap "Log Meal"
- Show snack bar confirmation

### 6. Dashboard Updates in Real-Time
**"Back on the dashboard, the calorie ring and macro bars update instantly."**

- Swipe or navigate back to Dashboard
- Point to: calorie progress, protein/carbs/fat bars, updated values

### 7. Log Water (Preset + Custom)
**"Hydration tracking supports both preset amounts and custom entries."**

- Open Hydration screen
- Tap "250ml" preset
- Tap "Custom" → enter "150ml" → save
- Show total for the day

### 8. Log Weight (Show Recalculation)
**"Logging a new weight recalculates my BMI and adjusts nutrition targets."**

- Open Weight screen
- Enter: 57.5 kg
- Show BMI change
- Navigate back to Dashboard — show updated calorie target

### 9. Generate Budget Recommendations
**"With a ₱150 budget, the app finds affordable, nutritious meals."**

- Open Recommendations tab
- Show budget amount displayed at top
- List of meal suggestions with prices

### 10. Add Recommendation to Planner
**"I can add any recommendation to my weekly meal plan with one tap."**

- Tap "Add to Planner" on one item
- Open Planner screen — show item on Monday

### 11. Convert Planner Item to Log
**"From the planner, I can convert a planned meal directly into a food log entry."**

- Tap planned item → "Log Now"
- Show confirmation and dashboard update

### 12. Turn On Internet → Sync
**"Now I'll re-enable the internet. All offline logs sync to Supabase automatically."**

- Disable airplane mode
- Show sync indicator or toast: "Synced 3 items"

### 13. AI Scan Food (Camera)
**"The AI scanner uses Gemini to identify food from a photo and estimate nutrition."**

- Open AI Scanner
- Point camera at a real food item (or hold up printed photo)
- Tap capture
- Wait for result → show identified food + nutrition estimate
- Tap "Confirm" to log

### 14. Ask Chatbot Budget Question
**"The chatbot can answer nutrition and budget questions in natural language."**

- Open Chatbot
- Type: "What can I eat for ₱50?"
- Show AI response with suggestions

### 15. Show Analytics (7-Day View)
**"The analytics screen visualizes my week — calories, macros, weight trend."**

- Open Analytics
- Tap through: Calorie chart, Macro breakdown, Weight trend line
- Point out day-by-day comparison

### 16. Admin Updates Food Price
**"An admin can update food prices, which affects budget recommendations."**

- Log in to admin account (show login switch if needed)
- Open Food Management
- Select "Rice" → change price from ₱15 to ₱18
- Save

### 17. Show Old Meal Log Unchanged
**"Existing meal logs with snapshot values are preserved — they don't change retroactively."**

- Open past meal log entry (the one from step 5)
- Show that the logged nutrition values are unchanged

---

**End of demo.**

Expected duration: ~8–10 minutes.
