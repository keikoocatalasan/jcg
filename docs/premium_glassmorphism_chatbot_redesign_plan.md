# Premium Glassmorphism and Chatbot Redesign Plan

## Baseline observations

The local Android QA build was inspected at phone width across Dashboard,
Community, Chatbot, Planner, and Manual Log. The application already has a
cyan/teal semantic palette and a bounded `GlassContainer`, but the surfaces are
not equally composed:

- Chatbot showed a large disclaimer, five tall prompt rows, a second duplicate
  prompt row above the composer, and a large amount of vertical competition.
- Dashboard and Community have the strongest glass hierarchy and should be the
  visual reference for the remaining screens.
- Planner is intentionally wider than a phone and needs its horizontal boundary
  to remain explicit rather than appearing clipped.
- Manual Log is dense but now stacks its detail fields at phone width.

## Design direction

### Shared glass language

- Use the existing `AppSemanticColors` and `GlassContainer` tokens rather than
  introducing another palette.
- Use static glass (`liveBlur: false`) inside scrolling lists and grids.
- Reserve live blur for stationary chrome, dialogs, and modal surfaces.
- Standardize 16–22dp radii, 1px translucent borders, restrained shadows, and
  44–48dp interaction targets.
- Keep primary actions cyan with dark readable foreground text; keep body text
  on the current high-contrast teal/white pairings.
- Preserve the Manrope typography scale and avoid decorative text that competes
  with the user’s task.

### Chatbot composition

1. Compact coach header with product role, short subtitle, and a Ready/Offline
   status pill.
2. One dismissible safety pill instead of a tall Material banner.
3. Empty state with one welcome glass panel and exactly three short quick-start
   labels. Labels are concise, but their full prompts remain unchanged in code.
4. Conversation bubbles use a consistent user/coach hierarchy and glass borders.
5. Composer stays anchored above the navigation bar, uses a glass input surface,
   one send action, and no repeated prompt list once a conversation starts.
6. Failed, blocked, redirected, and sending states remain visible and retryable.

### Other application surfaces

- Dashboard: retain its metric hierarchy; migrate remaining raw cards to the
  same glass tokens without adding more panels.
- Community: keep the existing polished feed, tabs, welcome card, and touch
  targets as the reference implementation.
- Planner: preserve the horizontal weekly grid, but make its scroll boundary
  intentional and keep header/stat chips glass-backed.
- Manual Log: retain the current meal-period filter and responsive stacked
  detail layout; use the same glass card treatment for search results.
- Settings, admin, scanner, and history: migrate only the outer surfaces and
  controls first, preserving their data and navigation behavior.

## Implementation sequence

1. Capture baseline screenshots and record the active routes.
2. Refactor Chatbot presentation without changing providers, API payloads, or
   local persistence.
3. Apply shared glass tokens to the remaining high-traffic chrome and cards.
4. Audit phone-width layout for overflow, clipped text, and minimum touch sizes.
5. Run widget/unit tests, analyzer, and emulator visual QA.
6. Review screenshots at empty, populated, offline, error, and keyboard-open
   states before any production deployment.

## Acceptance gates

- Empty Chatbot fits on a phone without duplicate prompt surfaces.
- A quick start produces the same full prompt and a local/API reply.
- User and coach messages are visually distinct and readable.
- Offline and disclaimer states remain understandable without dominating the
  screen.
- No Flutter overflow or glass/ListTile ink warnings appear in the tested flows.
- Dashboard, Community, Planner, Manual Log, and Chatbot retain navigation and
  existing data behavior.
- `flutter test --no-pub` passes; analyzer exits 0 with only accepted info-level
  findings.
- Production deployment remains a separate reviewed step; local QA bypass is
  development-only and never writes to hosted Supabase data.

## Current status

The Chatbot redesign and glass/ListTile interaction repairs are implemented and
visually verified in the local emulator. Full Flutter tests pass (216 passed, 1
expected mobile-runtime skip), and analysis exits 0. The working tree remains
local and unpushed.
