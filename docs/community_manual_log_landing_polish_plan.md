# Community, Manual Log, and Public Landing Polish Plan

## Scope

This change set covers three user-visible concerns:

1. Keep unsafe Community content out of the composer, comments, and the database.
2. Make Manual Log search respect the selected meal period.
3. Bring the Community feed and the public download page into the same compact,
   premium JCG Fitness visual system.

The application remains offline-first for local logs. The Community feed and
cloud moderation remain online features, and no secret or service-role key is
added to the Flutter client.

## Implementation plan

### 1. Content safety

- Replace the small exact-match client list with a versioned deterministic
  normalizer.
- Normalize case, accents, zero-width characters, common Unicode lookalikes,
  leetspeak substitutions, repeated characters, punctuation, whitespace, and
  separator-based obfuscation.
- Match whole words and phrases first, then compact obfuscated forms only for
  sufficiently long terms to avoid blocking ordinary words accidentally.
- Cover common English and Filipino/Tagalog profanity, harassment, sexual
  content, threats, self-harm encouragement, and hate/slur categories without
  echoing the matched text back to the user.
- Run the check for post bodies, comments, and user-created topic labels.
- Keep the existing database trigger as the authoritative server boundary. The
  SQL migration will expand its dictionary and apply the same compact matching
  rules; a client check is only a fast user experience improvement.
- Keep the blocked-word table admin-only and continue recording reports for
  content that evades a local dictionary.

### 2. Meal-period-aware manual logging

- Add an optional meal-period constraint to `FoodRepository.searchByName`.
- Reuse the existing explicit food tags and category fallbacks so older local
  rows without an explicit tag still behave consistently.
- Pass the selected meal period from Manual Log and Edit Log into both the
  inline search and the Food Search sheet.
- Re-run an active search when the user changes Breakfast/Lunch/Dinner/Snack.
- Clearly label the active filter and show a useful empty state rather than
  silently returning foods from another period.
- Treat `Other` as an unclassified manual period, so it does not incorrectly
  hide every food.

### 3. Community feed polish

- Preserve the existing All/Trending/Latest tabs, live refresh, likes, reports,
  comments, and offline behavior.
- Add a compact welcome/action surface, stronger hierarchy, 48dp touch targets,
  restrained card elevation, author initials, metadata, and clear reaction
  affordances inspired by social feeds without copying another product.
- Consume `AppSemanticColors` so the UI remains correct in the current dark
  app theme and if light mode is enabled later.
- Keep typography on the existing Manrope scale and avoid text smaller than the
  app's accessibility floor.

### 4. Landing/download page

- Keep the existing real screenshots and branded APK links.
- Replace the legacy yellow/black presentation with the app's cyan/teal
  palette on a light background.
- Remove screenshot darkening so the previews represent the shipped app.
- Retain Android compatibility, install troubleshooting, update, privacy, and
  release-note links.
- Keep the page static and deployable from the existing Render service; no new
  runtime dependency or storage provider is required.

## Verification gates

- Unit tests cover exact, Tagalog/English, separated, punctuation, repeated,
  leetspeak, Unicode-lookalike, and safe near-miss moderation cases.
- Flutter formatting, analysis, and the complete test suite pass.
- Local Manual Log confirms Lunch search does not show a breakfast-only food,
  and changing the period refreshes the active result set.
- Local Community confirms feed tabs, create-post safety feedback, likes, and
  comment safety remain usable at phone width.
- Landing page loads through the local static server with all images, branded
  download links, and no browser errors.
- A local app build is launched for visual inspection. Production acceptance
  still requires the physical-device flow documented in the public Android
  release plan.

## Explicit non-goals

- No claim of perfect moderation or 100% recognition accuracy. Language evolves,
  so admin review/reporting remains necessary.
- No automatic production database migration or release publish in this polish
  pass unless explicitly requested after the local checks are green.

## Implementation status for this pass

- Client content safety, topic validation, and obfuscation tests are implemented.
- The composer now rechecks text as it is entered, disables Post for blocked
  content, and shows the safety message before any share confirmation.
- The chatbot was redesigned around one welcome panel, three compact quick
  starts, a small disclaimer, glass message bubbles, and a stable composer;
  local QA verified both the empty state and a generated reply.
- Glass `ListTile` interactions were repaired by adding transparent Material
  ancestors where needed, removing Flutter ink-visibility warnings.
- Meal-period filtering is implemented in the repository, inline Manual Log
  search, Food Search sheet, and Edit Log entry point.
- Community feed UI and the light landing page have been visually checked on
  the Android emulator/local QA build and local static landing server.
- Manual Log phone-width overflow was found during visual QA and corrected by
  stacking the detail fields below the phone breakpoint.
- `flutter test --no-pub` passes: 216 passed, 1 expected mobile-runtime skip.
- `flutter analyze --no-pub --no-fatal-infos --no-fatal-warnings` exits 0;
  remaining findings are existing info-level style/deprecation suggestions.
- The Supabase migration was applied to the remote database and verified with
  a clean public-schema lint plus an up-to-date migration dry run.
- Source was pushed to GitHub and v1.0.5 was published. The Render landing
  service still needs confirmation from the JCG Render workspace because the
  current logged-in Render workspace reports access denied for that project.
