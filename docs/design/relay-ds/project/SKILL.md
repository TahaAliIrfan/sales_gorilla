---
name: relay-design
description: Use this skill to generate well-branded interfaces and assets for Relay, a token-driven white-label sales CRM & call-center platform — either for production or throwaway prototypes/mocks/etc. Contains essential design guidelines, color & type tokens, fonts, logo assets, and a from-scratch UI component library (buttons, forms, tables, kanban, chat/comms, nav, overlays, feedback states) with full light/dark + multi-brand theming.
user-invocable: true
---

# Relay Design System — skill

Relay is a **white-label, multi-tenant sales CRM and call-center platform**. Every tenant rebrands it with their own logo and brand color, so the entire system is **token-driven**: swap the 11-stop `--brand-*` ramp (and the logo) and everything reskins. Full dark-mode parity. The signature layout is a dark slate sidebar + light content console, built for data-dense, all-day use by sales reps working leads over WhatsApp, email, and browser calling.

## Start here

1. **Read `README.md`** — it covers the product context, the white-label theming model, **content fundamentals** (voice/casing/copy), **visual foundations** (type, color, space, elevation, motion), and **iconography**. Follow those rules closely; they are what keep output on-brand and stop it looking generic/AI-default.
2. **Explore the files** — the token layer (`colors_and_type.css`, `tokens.css`), the component CSS (`components.css`, `components-data.css`, `components-nav.css`), and the five gallery pages (`index.html`, `controls.html`, `data.html`, `overlays.html`, `feedback.html`) which demonstrate every component and state in context.
3. **Reuse, don't reinvent.** Compose the existing `rl-` components and reference **semantic tokens only** (`--color-primary`, `--color-fg-2`, `--color-surface`) — never raw hex, never primitives.

## How to use it

- **Building visual artifacts** (slides, mocks, throwaway prototypes): **copy the assets you need out** of this skill (the CSS files, `fonts/fonts.css`, `assets/`, and any `preview/` specimens) into your output folder, then write static HTML that links them. Load order: `fonts/fonts.css` → `colors_and_type.css` → `tokens.css` → `components.css` (+ data/nav as needed). Add Lucide via `<script src="https://unpkg.com/lucide@latest"></script>` and call `lucide.createIcons()`.
- **Working in production code:** read the token layer and component CSS to become an expert in the system, then apply the same tokens, `rl-` patterns, content voice, and Lucide iconography in the target codebase.
- **Theming:** add `data-theme="dark"` to `<html>` for dark mode. To rebrand to a tenant, override the 11 `--brand-*` stops (see `ds.js` → `applyBrand()` for the lightness-curve generator, or set them directly).

## Non-negotiables (from the brief)

- **No warm beige / cream / eggshell** backgrounds; neutrals are **cool slate**.
- **No** blue-purple gradients, Inter/Roboto, emoji in chrome, or colored-left-border cards.
- Type is **Bricolage Grotesque** (display) + **Hanken Grotesk** (UI) + **JetBrains Mono** (data).
- **Sentence case** all UI copy; address the user as "you"; verb-first buttons; tabular figures for all numbers.
- Icons are **Lucide**, 1.5px stroke, `currentColor`.

## If invoked with no specific guidance

Ask what the user wants to build or design (a screen, a flow, a prototype, a slide, production components), ask a few focused questions (which surface? light or dark? a specific tenant brand color? data-dense or marketing?), then act as an expert Relay designer and deliver either HTML artifacts or production code as appropriate.
