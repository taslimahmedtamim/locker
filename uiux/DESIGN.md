---
name: Quiet Sanctuary
colors:
  surface: '#f8f9ff'
  surface-dim: '#cbdbf5'
  surface-bright: '#f8f9ff'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#eff4ff'
  surface-container: '#e5eeff'
  surface-container-high: '#dce9ff'
  surface-container-highest: '#d3e4fe'
  on-surface: '#0b1c30'
  on-surface-variant: '#444653'
  inverse-surface: '#213145'
  inverse-on-surface: '#eaf1ff'
  outline: '#757684'
  outline-variant: '#c4c5d5'
  surface-tint: '#3755c3'
  primary: '#00288e'
  on-primary: '#ffffff'
  primary-container: '#1e40af'
  on-primary-container: '#a8b8ff'
  inverse-primary: '#b8c4ff'
  secondary: '#006a61'
  on-secondary: '#ffffff'
  secondary-container: '#86f2e4'
  on-secondary-container: '#006f66'
  tertiary: '#4c2e00'
  on-tertiary: '#ffffff'
  tertiary-container: '#6b4200'
  on-tertiary-container: '#ffa929'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#dde1ff'
  primary-fixed-dim: '#b8c4ff'
  on-primary-fixed: '#001453'
  on-primary-fixed-variant: '#173bab'
  secondary-fixed: '#89f5e7'
  secondary-fixed-dim: '#6bd8cb'
  on-secondary-fixed: '#00201d'
  on-secondary-fixed-variant: '#005049'
  tertiary-fixed: '#ffddb8'
  tertiary-fixed-dim: '#ffb95f'
  on-tertiary-fixed: '#2a1700'
  on-tertiary-fixed-variant: '#653e00'
  background: '#f8f9ff'
  on-background: '#0b1c30'
  surface-variant: '#d3e4fe'
typography:
  headline-xl:
    fontFamily: Manrope
    fontSize: 36px
    fontWeight: '700'
    lineHeight: 44px
    letterSpacing: -0.02em
  headline-xl-mobile:
    fontFamily: Manrope
    fontSize: 28px
    fontWeight: '700'
    lineHeight: 36px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Manrope
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
    letterSpacing: -0.015em
  headline-sm:
    fontFamily: Manrope
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 26px
    letterSpacing: -0.01em
  body-lg:
    fontFamily: Manrope
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
    letterSpacing: -0.005em
  body-md:
    fontFamily: Manrope
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
    letterSpacing: 0em
  body-sm:
    fontFamily: Manrope
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 16px
    letterSpacing: 0.01em
  label-lg:
    fontFamily: Manrope
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
    letterSpacing: 0.02em
  label-code:
    fontFamily: JetBrains Mono
    fontSize: 14px
    fontWeight: '500'
    lineHeight: 20px
    letterSpacing: 0.04em
  label-sm:
    fontFamily: Manrope
    fontSize: 11px
    fontWeight: '600'
    lineHeight: 14px
    letterSpacing: 0.05em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 1rem
  margin: 1.25rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 1rem
  space-lg: 1.5rem
  space-xl: 2.25rem
---

## Brand & Style

This design system establishes an environment of quiet confidence, absolute privacy, and cognitive ease. Tailored for individuals seeking a zero-stress relationship with their digital credentials, the interface dispenses with cyber-security cliches—matrix rains, neon wireframes, lock badges, and aggressive alarms—in favor of warm, human-centered clarity. 

The aesthetic fuses **Warm Editorial Minimalism** with soft **Tactile Depth**. Interactions evoke the feeling of smooth archival card stock, precision stationery, and an unhurried, vault-like personal journal. Visual hierarchy is achieved through generous negative space, intentional typographic scale, and delicate, paper-thin structural borders rather than heavy decoration. The emotional resonance is calm, uncompromised safety, and effortless competence.

## Colors

The palette grounds the interface in profound stability while keeping user tension low.

### Palette Architecture
- **Primary (`#1E40AF` - Royal Indigo)**: Commands focus for primary authentication actions, secure keys, and key focal anchors. It signals institutional-grade security without feeling militaristic or cold.
- **Secondary (`#0D9488` - Deep Sea Pine)**: Denotes healthy states, secure passwords, synced states, and biometrics. It offers a soothing, organic validation signal.
- **Tertiary (`#F59E0B` - Warm Amber)**: Used strictly for actionable attention—expiring credentials, weak entropy warnings, or account recovery alerts. Never panic-inducing; always informational.
- **Neutral (`#64748B` - Slate)**: Modulates structural boundaries, non-critical labels, and icon states.

### Light Mode Foundations
- **Canvas Base**: `#F8FAFC` (Soft Slate) creates an eye-resting, glare-free background.
- **Card Surface**: `#FFFFFF` (Pure Crisp White) floats subtly over the base.
- **Primary Text**: `#0F172A` (Deep Slate) delivers sharp, fatigue-free contrast.
- **Secondary Text**: `#64748B` (Muted Slate) recedes metadata gracefully.
- **Border / Hairline**: `#E2E8F0` defines cards and inputs with whisper-quiet boundaries.

### Dark Mode Foundations
- **Canvas Base**: `#0F172A` (Abyssal Slate) minimizes retinal glare in low light.
- **Card Surface**: `#1E293B` (Midnight Slate) raises interactive objects forward.
- **Primary Text**: `#F8FAFC` preserves crisp legibility.
- **Secondary Text**: `#94A3B8` balances secondary information cleanly.
- **Border / Hairline**: `#334155` outlines elements without glowing harshly.

## Typography

The typographic system pairs the humanist geometric precision of **Manrope** for structural and conversational copy with the clinical fidelity of **JetBrains Mono** for masked keys, entropy scores, two-factor seeds, and passphrases.

### Rules of Application
- **Manrope** conveys warmth, non-technical hospitality, and rock-solid architectural rhythm across headings and running body text.
- **JetBrains Mono** is reserved exclusively for `label-code`: obfuscated dots, master key recovery tokens, raw passwords, and numerical 2FA codes. This avoids glyph confusion between `0` and `O`, `1` and `l`.
- Never set body copy or primary navigational labels in monospace.
- Restrict `headline-xl` solely to high-level onboarding views or screen-level security balance overviews; standard page headers rely on `headline-lg` or `headline-sm`.

## Layout & Spacing

A mobile-centric fluid column system governs all viewport transitions, centering on finger-driven usability and calm visual padding.

### Layout Mechanics
- **Mobile Handheld (320px – 480px)**: A 4-column fluid grid governed by a 20px (`1.25rem`) edge margin to preserve side thumb buffers. Internal gutters are locked at 16px (`1rem`).
- **Tablet / Expanded Handheld (481px – 840px)**: Reflows to an 8-column layout with a 32px outer canvas margin. Content containers (e.g., credential sheets, password generators) clamp to a max-width of 540px to retain single-column scannability.
- **Desktop Companion (841px+)**: A 12-column architecture featuring a pinned, quiet navigation rail (280px) and a primary utility workspace centered at 680px maximum content width.

### Spacing Discipline
- Maintain internal component padding strictly at `space-md` (16px) or `space-lg` (24px) to preserve substantial breathing room.
- Vertical item separation inside grouped lists uses zero-gap contiguous layouts with internal hairlines, while distinct security categories are separated by `space-xl` (36px).

## Elevation & Depth

Visual depth is conveyed through a **layered paper and tonal resting** philosophy. Avoid dramatic drops, high-blur shadows, or glass-like chromatic distortions, which induce visual clutter.

### Surface Hierarchy
- **Level 0 (App Canvas)**: Ground zero. In light mode, `#F8FAFC`; in dark mode, `#0F172A`. Never holds actionable touch targets directly without a containing boundary or typographic distinction.
- **Level 1 (Card & Content Blocks)**: Surface rest layer. Pure White `#FFFFFF` in light mode, `#1E293B` in dark mode. Outlined with a hairline border (`#E2E8F0` / `#334155`). Employs an ultra-subtle, ambient grounding shadow:
  - `box-shadow: 0 1px 3px 0 rgba(15, 23, 42, 0.04), 0 1px 2px -1px rgba(15, 23, 42, 0.02)`
- **Level 2 (Active Sheets, Bottom Trays, Floating Action Prompts)**: Used for credential generators and biometric challenge sheets. Slightly elevated to signal dismissibility:
  - `box-shadow: 0 10px 25px -5px rgba(15, 23, 42, 0.08), 0 8px 10px -6px rgba(15, 23, 42, 0.04)`
- **Level 3 (Modal Alerts & Master Seed Overlays)**: Maximum focus. Supported by a 40% opacity dimming backdrop (`#0F172A` at 0.40 alpha with 4px backdrop blur) to strip away all background distraction.

## Shapes

The shape vocabulary communicates approachability, safety, and modern precision through a **16px base radius** (`rounded-lg` under Level 2 setting).

### Geometry Guidelines
- **Cards & Vault Items**: Fixed at `16px` border-radius (`rounded-lg`). This softens the silhouette and strips out cold, institutional edges while feeling more disciplined than pill containers.
- **Form Inputs & Search Trays**: Locked at `16px` (`rounded-lg`) to mirror card boundaries, producing uninterrupted, calm horizontal bands.
- **Buttons (Primary & Secondary)**: Standardized at `16px` (`rounded-lg`) for primary block actions, matching input heights (52px minimum) to ensure seamless stacked parity.
- **Pill Exceptions (`9999px`)**: Reserved exclusively for small status tags, security strength chips, and 2FA copy indicators.
- **Icon Enclosures**: Squircle-like containers with `12px` rounding for identity icons (e.g., website favicons, service symbols).

## Components

### Buttons
- **Primary**: Full-width or inline block, height 52px. Light mode: `#1E40AF` fill with `#FFFFFF` text. Dark mode: `#2563EB` fill with `#FFFFFF` text. Radius: 16px. No shadow; tactile micro-scale transform (0.98) on active tap.
- **Secondary / Ghost**: Height 52px. Transparent background with an internal `#E2E8F0` (light) or `#334155` (dark) border. Text color: `#0F172A` (light) / `#F8FAFC` (dark).
- **Destructive**: Height 52px. Soft tinted fill (`#FEF2F2`), text in crimson (`#DC2626`). In dark mode: `#450A0A` base with `#FCA5A5` text.

### Form Inputs & Search Fields
- **Height**: 52px with 16px horizontal internal padding.
- **Surface**: `#FFFFFF` (light) / `#1E293B` (dark) wrapped in a 1px border (`#E2E8F0` / `#334155`).
- **Focus State**: Border transitions to primary `#1E40AF` accompanied by a soft 3px outer ring tinted at 15% opacity (`rgba(30, 64, 175, 0.15)`).
- **Reveal Controls**: Integrated inline toggle buttons (eye icon / copy button) spaced with 44px x 44px hit-targets.

### Password Strength Meter & Chips
- **Meter**: Segmented 4-bar horizontal track. Inactive track: `#E2E8F0` (light) / `#334155` (dark). Active fill dynamically paints from amber (`#F59E0B`) to sea pine (`#0D9488`).
- **Security Chips**: Pill-shaped badges (`rounded-full`), height 24px, horizontal padding 8px. Typography set to `label-sm`. Positive state: `#F0FDF4` background with `#15803D` text.

### Vault Item Cards & Lists
- **Structure**: Grouped list items share a single white surface container with 16px outer rounding and internal 1px hair-dividers inset by 56px (matching icon width + margin).
- **Item Row**: 64px min-height to ensure touch ergonomics. Left: 40px rounded icon container. Center: Title (`label-lg`) stacked above muted account handle (`body-sm`). Right: Chevron or rapid-copy action icon.

### Checkboxes & Biometric Switches
- **Switches**: Track size 48px x 28px, rounded pill, with a 24px circular white knob. On state switches track to `#1E40AF`; Off state rests at `#CBD5E1` (light) / `#475569` (dark).
- **Checkboxes**: 22px x 22px squircle (6px radius). Checked state displays a solid `#1E40AF` fill with a crisp white 1.5px checkmark.

### Additional Specialty Component: Quick-Copy Drawer
- Bottom sheet drawer revealing OTP codes and sensitive keys.
- Anchored to the mobile base with `24px` top-corner radii.
- Prominently showcases JetBrains Mono characters at `headline-lg` with single-tap copy triggers confirming via a subtle haptic pulse and secondary sea-pine badge state.