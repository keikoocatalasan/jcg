# Module correction plan — September 15, 2026

Scope: review supplied screenshots and video frames, inspect source, and plan corrections. No implementation or deployment in this review.

## Evidence

- Connected Tecno device is running 1.0.7/build 4008. Recent retained device logs did not establish a matching Flutter exception; reproduction remains necessary.
- First video (15.60 seconds): recommendations list and detail render, then a blank application surface appears. Exact failing interaction needs reproduction.
- Second video (25.91 seconds): selecting a planned food produces a blank preview area; date picker remains functional.
- Community screenshot: post creation fails with SQLSTATE 42703, record NEW has no field comment_text.
- Chat screenshot: replies repeat despite changing questions and contain unsupported prices, implausible protein quantities and unnatural Tagalog.

## 1. Planner and recommendation transitions

Source defect: add_planned_meal_screen.dart, _buildPreviewPanel places Spacer inside Wrap. Spacer requires a Flex parent. Replace the header with a bounded Row and flexible title, or remove the flex child from Wrap.

Recommendation detail Add to Planner opens this same screen with a preselected food, which can trigger the defect immediately. Reproduce both Add to Planner and Log Meal separately before attributing the entire first video to this defect.

Check date and meal-slot arguments, edit existing plans, deselect/reselect food, quantity changes, cancellation and back navigation. Exercise narrow screens, large text and keyboard-visible layouts. Ensure a failed save preserves entered data and exposes retry.

Acceptance: selection and recommendation-to-planner navigation render without Flutter layout exceptions; saved food/date/meal/quantity are correct after reopening and week navigation; no duplicates on repeated taps. Test Log Meal separately and confirm dashboard totals update.

## 2. Community database trigger

The shared community_reject_blocked_content function references NEW.body_text and NEW.comment_text in one CASE expression, while posts and comments have different row structures. This is the leading cause consistent with the supplied error; inspect the deployed function and its trigger attachments to confirm.

Create a forward migration using separate table-specific trigger functions or a safe JSON record lookup, retaining moderation and ownership policies. Do not add an artificial comment_text column to posts. Validate approved post/comment inserts and updates, blocked input, public/private visibility, unauthorized edits and draft retention on failure. Replace raw PostgREST errors with useful user messages and diagnostic IDs.

Acceptance: ordinary posts and comments save; moderation still rejects prohibited content; private content stays private; no 42703 errors.

## 3. Chatbot reliability and answer quality

History is appended as JSON after the latest message. NVIDIA adapter combines instructions and all dialogue into one user message. Build provider-appropriate structured conversation turns, with latest user message last; bound history and exclude failed/moderated turns. Retain compatibility with vision calls.

Current context labels profile.dailyBudgetPhp as remaining_budget_php and omits remaining nutrition and restrictions. Calculate remaining context from current-day logs, include dietary restrictions, and distinguish daily allowance from remaining amount.

Ground numeric nutrition and prices in catalog records with serving grams and units. Retrieve a small set of relevant foods; use the language model to explain these records. If data are unavailable, say so instead of inventing exact amounts. Earlier assistant replies must not become factual sources.

Preserve processing feedback; acquire request lock before saving a new message, handle all failures, clear it in finally, and provide a bounded timeout/retry path. Test rapid sends, retries, tab switches, offline transitions and expired sessions.

Acceptance: English, Tagalog and Taglish follow-ups answer the latest question; pork/chicken comparisons address both; factual values match supplied catalog units; no repetitive template loop; processing ends on success and failure. Profanity and emergency handling must retain appropriate priority.

## 4. Recommendation correctness

Inspect ranking inputs, remaining budget/macros, meal filtering, allergies and restrictions. Verify the current recommendation engine and AI explanation path separately. Replace unconditional cached/just-now claims with actual freshness metadata. Test empty catalog, no matching foods, unavailable profile and network failure.

Acceptance: filter constraints hold, displayed numbers match food records and portion units, both action buttons open usable screens, and unavailable data show a recovery state.

## Delivery order

1. Capture device reproduction and relevant app logs without clearing user data.
2. Correct planner layout and shared community trigger first.
3. Correct chat request ordering, context and grounded numeric answers.
4. Verify recommendation calculations, transitions and error states.
5. Run focused regression/widget/database checks plus device acceptance.
6. Apply reviewed migration and deploy backend; build a new signed APK with increased version code. Install over existing app, verify retained data and repeat reported flows before publishing downloads.

Prior smoke tests and high model confidence are not evidence that these workflows or factual answers are correct. Release acceptance requires the reported actions to pass on the phone.
