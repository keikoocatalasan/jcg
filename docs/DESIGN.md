---
name: NutriSmart Vibrant Dark
colors:
  background: '#0F172A'
  on-background: '#F8FAFC'
  surface: '#1E293B'
  on-surface: '#F8FAFC'
  surface-glass: 'rgba(30, 41, 59, 0.7)'
  primary: '#10B981' # Emerald Green
  on-primary: '#FFFFFF'
  primary-container: '#064E3B'
  on-primary-container: '#A7F3D0'
  secondary: '#F59E0B' # Ember/Orange for Budget/Cost
  on-secondary: '#FFFFFF'
  secondary-container: '#78350F'
  on-secondary-container: '#FEF3C7'
  tertiary: '#F43F5E' # Rose/Coral for Protein/Macros
  on-tertiary: '#FFFFFF'
  tertiary-container: '#4C0519'
  on-tertiary-container: '#FFE4E6'
  error: '#EF4444'
  on-error: '#FFFFFF'
  success: '#10B981'
  warning: '#F59E0B'
  text-secondary: '#94A3B8'
typography:
  display-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 40px
    fontWeight: '800'
    lineHeight: 48px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 28px
    fontWeight: '700'
    lineHeight: 36px
  body-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 18px
    fontWeight: '400'
    lineHeight: 28px
  body-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  label-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
rounded:
  sm: 4px
  DEFAULT: 8px
  md: 12px
  lg: 16px
  xl: 24px
  full: 9999px
spacing:
  base: 8px
  container-margin: 20px
  gutter: 16px
  surface-padding: 24px
---

## Brand & Style
The design system focuses on a **Vibrant Dark Mode & Glassmorphic** aesthetic tailored for a high-tech fitness and nutrition application. The core personality is "Vibrant Vitality"—a blend of athletic energy and clean, data-driven transparency.

The UI should feel premium, high-contrast, and alive. It achieves this through a dark slate interface characterized by translucent glass cards with colored glows, vibrant progress rings, and a clean, spacious layout. The target audience includes health-conscious individuals who value efficiency and high design.

## Colors
The palette is built on a foundation of **Sleek Slate Dark** and vibrant neon accents.
- **Primary (Emerald):** Represents health, nutrition, and budget target satisfaction.
- **Secondary (Ember):** Represents budget and cost parameters.
- **Tertiary (Rose/Coral):** Represents protein and macro targets.
- **Background:** Slate Black (`#0F172A`), providing high contrast for neon highlights.

## Typography
The system exclusively uses **Plus Jakarta Sans** for a modern, geometric, and friendly presence.
- **Headlines:** Feature tight letter-spacing to look bold, premium, and clean.
- **Numbers/Metrics:** Bold, high-readability layout to emphasize calorie and budget tracking.

## Elevation & Depth
Depth is created through **Stacking, Glows, and Translucency**.
- **Level 1 (Glass Cards):** Slate background at 70% opacity with `blur(20px)` and a subtle 1px border at 10% opacity.
- **Level 2 (Active Cards):** Ambient back-glow using a soft drop shadow tinted with the primary emerald or secondary ember color (opacity 10%).

## Components
- **Dashboard Rings:** Thick circular progress rings utilizing gradient fills (Emerald-to-Teal for Calories, Ember-to-Yellow for Budget).
- **Primary Buttons:** Solid Emerald Green with white text and a soft, diffused green outer glow.
- **Ghost Input Fields:** Dark gray background (30% opacity) with a thin slate border that glows emerald on focus.
