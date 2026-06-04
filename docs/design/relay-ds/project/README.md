# Relay Design System

A complete, **token-driven, white-label** design system for **Relay** — a multi-tenant sales CRM and call-center platform. Agencies and sales teams buy Relay and rebrand it as their own: each tenant swaps in their product name, logo, and brand color, and the entire interface reskins. Nothing in this system is visually tied to a single brand.

> **Status:** Built from scratch (no third-party UI kit, no component library). Bespoke components, custom token layer, full light + dark parity. This repo is the **design system only** — foundations + every reusable component + every state. App screens are built *on top* of this, separately.

---

## The product this serves

Relay's primary user is a **sales rep working a focused book of leads all day from one screen**:

- **Comms-heavy** — WhatsApp (the #1 channel), email, and browser-based calling with **auto call-recording + transcription**.
- **Pipeline** — a drag-and-drop kanban deal board, plus tasks and follow-ups.
- **Reporting** — KPI dashboards and metric tiles.
- **Layout convention** — a **dark slate sidebar** against a **light content console**. Data-dense tables, inbox/chat views, and status-heavy lead lists.

The system is optimized for **clarity, scanability, and speed** in dense, all-day use.

---

## The #1 structural requirement: white-label theming

Everything is painted from **semantic CSS custom properties** — never a hard-coded color. A tenant supplies **one thing**: an 11-stop brand color ramp (`--brand-50` … `--brand-950`) plus a logo. Every surface, control, badge, focus ring and chart recomputes from there.

- **Try it live:** open `index.html` and use the brand swatches (top-right) — Teal / Cobalt / Violet / Amber / Rose — and the Light/Dark toggle. The whole system reskins with zero component edits.
- **Dark mode** is planned from token one: only semantic + layer tokens flip; component CSS is untouched.
- The brand-generation logic (lightness curve × chroma multiplier per stop) lives in `ds.js` → `applyBrand()`. In production a tenant would set the 11 `--brand-*` values directly.

---

## Files in this repo

| File | What it is |
|---|---|
| **`index.html`** | Foundations gallery — color, type, spacing, elevation, motion, icons. Live white-label + dark switcher. |
| **`controls.html`** | Buttons, icon buttons, groups, segmented, switches, sliders, steppers, links + **all form fields & validation states**. |
| **`data.html`** | Cards, data tables, kanban, stat tiles, badges/pills/tags, avatars, lists, timeline + **comms** (chat, conversation list, call player, transcript). |
| **`overlays.html`** | App shell (sidebar + topbar), tabs, breadcrumbs, dropdown menus, popovers, tooltips, modals, drawer, **⌘K command palette**. |
| **`feedback.html`** | Toasts, inline alerts, loading/skeleton/progress, empty states, error pages (404/500/permission/offline), **interaction-state matrix**. |
| `colors_and_type.css` | **Source of truth** for color + type tokens (primitives → semantics, light + dark). |
| `tokens.css` | Spacing, radius, elevation, z-index, motion, breakpoints, layout primitives. |
| `components.css` | Core component styles (`rl-` prefix): buttons, fields, badges, avatars, cards, etc. |
| `components-data.css` | Tables, kanban, chat, timeline, call player, transcript. |
| `components-nav.css` | App sidebar, tabs, menus, popovers, tooltips, modals, drawer, command palette. |
| `site.css` | Documentation-site chrome only (not shipped to consumers). |
| `ds.js` | Docs theming + live white-label brand generation + Lucide icon init. |
| `fonts/fonts.css` | Webfont loader (Bricolage Grotesque, Hanken Grotesk, JetBrains Mono). |
| `assets/` | Logo, mark, and brand assets. |
| `preview/` | Small specimen cards that populate the Design System tab. |
| `SKILL.md` | Agent-Skills manifest so this system can be used as a Claude skill. |

**Sources:** This system was built to a written brief (no external Figma or codebase was provided). If you have a tenant's brand kit or a production codebase to align with, share it and the token layer can be matched exactly.

---

## CONTENT FUNDAMENTALS

How Relay writes copy — match this voice in any screen or asset.

- **Voice:** Clean, professional, trustworthy, efficient — with a crafted, confident personality. Never cute, never jargon-heavy. It respects a busy rep's time.
- **Person:** Address the user as **"you"** ("You've replied to every lead"). Refer to the rep's actions in plain active voice. The product refers to itself as **"we"** sparingly, only for system actions ("We're importing your leads").
- **Casing:** **Sentence case everywhere** — buttons, headings, menu items, table headers. Never Title Case UI. (e.g. "Add lead", "Today's follow-ups", not "Add Lead".)
- **Micro-labels / eyebrows:** UPPERCASE with letter-spacing, used sparingly for section eyebrows and stat labels ("CALLS TODAY", "LIBRARY").
- **Buttons:** Verb-first and specific — "Add lead", "Log call", "Create deal", "Send WhatsApp". Avoid vague "Submit" / "OK".
- **Numbers & data:** Always **tabular figures**. Money as `$24,000`. Times as `14:08` (24h in data contexts). IDs in mono: `LEAD-4821`.
- **Tone in empty/error states:** Calm and helpful, never blaming. "Couldn't save note — changes were not stored. Try again." "You're offline. Calls are paused and messages will send when you're back."
- **Emoji:** **Effectively none in chrome.** The one acceptable place is *inside a rep's own outbound chat message* (e.g. a 👋), because that mirrors how reps actually message leads on WhatsApp. Never in labels, headings, buttons, or empty states.
- **Length:** Terse. Helper text is one line. Alert bodies are one or two short sentences.

**Examples seen in the system:** "Close more, faster" · "Today's follow-ups" · "Inbox zero — you've replied to every lead." · "Trial ends in 3 days — add a payment method to keep your pipeline."

---

## VISUAL FOUNDATIONS

The motifs and rules that make Relay look like Relay.

### Type
- **Display & headings:** **Bricolage Grotesque** (700–800) — an editorial grotesque with real character; tight tracking (`-0.02 to -0.03em`) on large sizes. This is the system's personality.
- **UI & body:** **Hanken Grotesk** (400–600) — a clean, sturdy workhorse with excellent tabular figures for data.
- **Mono:** **JetBrains Mono** (400–600) — IDs, phone numbers, timestamps, deal values, code.
- Scale runs display 56 → caption 11px; UI default body is **15px**. Never below 11px.

### Color
- **Brand (demo):** deep **teal** — confident, trustworthy, not the default SaaS blue-purple. Fully swappable.
- **Neutrals:** **cool slate** (hue ~256–268 in oklch). Deliberately **no warm beige / cream / eggshell** anywhere.
- **Semantics:** green (success), amber (warning), red/rose (danger), blue (info) — spaced across the wheel for instant differentiation in status-dense lists.
- **Channel accents:** WhatsApp green, call blue, email (brand-near), SMS violet.
- **Categorical palette:** 8 equal-weight hues for tags and KPI charts.
- All ramps authored in **oklch** for perceptual evenness; AA contrast holds in light and dark.

### Space, radius & layout
- **4px base grid.** Dense views breathe on an 8–16px rhythm; marketing surfaces use 32–96px.
- **Radius:** controls/inputs `8px`, cards/panels `12px`, modals `16px`, pills/avatars full-round. Friendly but not bubbly.
- **Layout:** fixed dark sidebar (264px, collapsible to 64px) + sticky 60px topbar + scrolling light console. Max content width ~1320px.

### Backgrounds, surfaces & depth
- **No gradients as decoration**, no hero photography, no illustration, no texture/grain. Surfaces are **flat, layered slate** — `bg` → `surface` → `surface-2` → `surface-3` — distinguished by 1px borders and elevation, not color washes.
- **Elevation:** cool-tinted, two-layer shadows (built on the slate hue so depth reads as depth, not grime). Inputs sit flat; menus/popovers/modals rise xs → xl. Pressed/inset uses an inner shadow.
- **Borders** do a lot of the work: `1px` hairlines at `--color-border`; dividers one step lighter. This is a **border-and-elevation** system, not a shadow-heavy or a flat-borderless one.
- **Transparency & blur:** used sparingly and purposefully — the sticky topbar uses a subtle `backdrop-filter: blur` over a translucent canvas; the modal scrim is a 2px blur over a slate scrim. Subtle tints (`color-mix`) create channel/categorical soft backgrounds.

### Motion
- Short and decisive. **`ease-out` `cubic-bezier(.16,1,.3,1)`** for enters; durations 80 / 140 / 220 / 340ms.
- Hovers: background and border shift (lighter surface, stronger border) — **not** opacity fades.
- Press: a tiny `scale(.985)` + 0.5px nudge. Switch thumb uses a gentle spring overshoot.
- Decorative loops avoided; the only ambient motion is the typing-indicator bounce and skeleton shimmer. Everything respects `prefers-reduced-motion`.

### Cards & components
- Cards: `surface` background, `1px` border, `12px` radius, `shadow-sm`. No colored left-border accents (an AI cliché we explicitly avoid).
- Focus: a **3px brand ring** (`--color-focus-ring`) on every interactive element, always visible on keyboard focus.
- Hover/active/disabled/selected/loading states are defined for every interactive element (see the matrix in `feedback.html`).

### What we deliberately avoid
Blue-purple gradients · Inter/Roboto · warm cream/beige backgrounds · emoji in chrome · cards with a single colored left border · stock SaaS-on-white blandness · drawn-SVG illustrations.

---

## ICONOGRAPHY

- **Set:** [**Lucide**](https://lucide.dev) — one consistent **1.5px stroke** family across the entire product. Loaded via CDN (`unpkg.com/lucide@latest`) and rendered with `data-lucide="name"` + `lucide.createIcons()`.
- **Why Lucide:** clean, neutral, comprehensive, and brand-agnostic — exactly right for a white-label tool where icons must never feel "owned" by one tenant.
- **Sizing:** `16` (dense/inline), `18` (default UI), `20` (emphasis). Stroke inherits `currentColor`, so icons theme automatically in light/dark and under any brand.
- **Logo / mark:** Relay's placeholder mark is a **double chevron** (`»`) — a "relay/forward" motif — as inline SVG in `assets/relay-mark.svg` (currentColor) and `assets/relay-logo.svg` (filled tile). It uses `currentColor` so it tints to the active brand. **Tenants replace this** with their own logo.
- **Emoji as icons:** never in chrome. Unicode arrows (`↑ ↓ ↵`) appear only inside keyboard-hint `kbd` chips in the command palette.
- **No PNG icons, no icon font** beyond Lucide's SVG-via-JS; no hand-drawn one-off SVGs in components.

> If you adopt this system in a codebase that already standardizes on a different icon set (Phosphor, Heroicons, etc.), swap the CDN link and keep the same sizing rules — the components only assume "an inline SVG that inherits currentColor".

---

## Quick start for an agent or developer

1. Link the token layer in order: `fonts/fonts.css` → `colors_and_type.css` → `tokens.css` → `components.css` (+ `components-data.css` / `components-nav.css` as needed).
2. Add `data-theme="dark"` to `<html>` for dark mode.
3. To rebrand: override the 11 `--brand-*` stops (and swap the logo). Nothing else.
4. Build screens by composing `rl-` components. Reference **semantic tokens only** (`--color-primary`, `--color-fg-2`, `--color-surface`) — never primitives, never raw hex.
5. Match the **content voice** and **iconography** rules above.
