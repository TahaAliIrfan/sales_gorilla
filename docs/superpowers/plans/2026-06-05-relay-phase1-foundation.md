# Relay Phase 1 — Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port the Relay Design System into the Rails app and build the new app shell (dark sidebar + topbar + chrome) with per-tenant white-label branding, verified on a dev-only styleguide page.

**Architecture:** DS stylesheets copied verbatim into `app/assets/stylesheets/relay/`; a new `relay` layout renders the shell from ERB partials with server-rendered per-tenant `--brand-*` CSS custom properties (hex → oklch ramp ported from `ds.js`); interactivity via namespaced `relay/*` Stimulus controllers (auto-registered by `eagerLoadControllersFrom`). No page migrates to the new layout in this phase except a dev-only `/_relay` styleguide.

**Tech Stack:** Rails 7.1, Sprockets, importmap, Turbo/Stimulus, RSpec. No new gems, no build system.

> **⚠ Commit policy for this plan:** The user requires explicit approval before ANY commit. Do NOT run `git commit` at any step. Leave all changes in the working tree; a single commit happens after final user approval.

**Design references (in-repo):**
- DS source: `docs/design/relay-ds/project/` (CSS files copied verbatim)
- App prototype: `docs/design/relay-app/project/` (`app/app.css`, `app/shell.jsx` for shell markup, `Relay.html`)
- Visual truth: `docs/design/relay-app/project/screenshots/today.png` (shell chrome), DS galleries `docs/design/relay-ds/project/overlays.html`

---

### Task 1: Port the design-system stylesheets

**Files:**
- Create: `app/assets/stylesheets/relay/{fonts,colors_and_type,tokens,components,components-data,components-nav,app}.css` (copies)
- Modify: `app/assets/config/manifest.js`

- [ ] **Step 1: Copy the CSS verbatim**

```bash
mkdir -p app/assets/stylesheets/relay
cp docs/design/relay-ds/project/fonts/fonts.css        app/assets/stylesheets/relay/fonts.css
cp docs/design/relay-ds/project/colors_and_type.css    app/assets/stylesheets/relay/colors_and_type.css
cp docs/design/relay-ds/project/tokens.css             app/assets/stylesheets/relay/tokens.css
cp docs/design/relay-ds/project/components.css         app/assets/stylesheets/relay/components.css
cp docs/design/relay-ds/project/components-data.css    app/assets/stylesheets/relay/components-data.css
cp docs/design/relay-ds/project/components-nav.css     app/assets/stylesheets/relay/components-nav.css
cp docs/design/relay-app/project/app/app.css           app/assets/stylesheets/relay/app.css
```

Do NOT edit their contents — they are the source of truth. Exception: none in this phase.

- [ ] **Step 2: Register the directory with Sprockets**

In `app/assets/config/manifest.js` add after the existing `link_directory` line:

```js
//= link_tree ../stylesheets/relay .css
```

- [ ] **Step 3: Verify the assets resolve**

```bash
bin/rails runner 'puts %w[relay/fonts relay/colors_and_type relay/tokens relay/components relay/components-data relay/components-nav relay/app].map { |f| ActionController::Base.helpers.stylesheet_path(f) }'
```

Expected: seven `/assets/relay/...css` paths printed, no `Sprockets::Rails::Helper::AssetNotFound` error.

### Task 2: Brand-ramp theme helper (hex → oklch, 11 stops) — TDD

Port of `applyBrand()` from `docs/design/relay-ds/project/ds.js:16-30`: a shared lightness curve + per-stop chroma multiplier, hue/chroma seeded from the tenant color. `Organization#primary_color` is a validated hex (e.g. `#1E3A8A`, default exists — see `app/models/organization.rb`).

**Files:**
- Create: `app/helpers/relay/theme_helper.rb`
- Test: `spec/helpers/relay/theme_helper_spec.rb`

- [ ] **Step 1: Write the failing spec**

```ruby
# spec/helpers/relay/theme_helper_spec.rb
require "rails_helper"

RSpec.describe Relay::ThemeHelper, type: :helper do
  describe "#relay_hex_to_oklch" do
    it "converts pure red to the known oklch value" do
      l, c, h = helper.relay_hex_to_oklch("#ff0000")
      expect(l).to be_within(0.005).of(0.628)
      expect(c).to be_within(0.005).of(0.258)
      expect(h).to be_within(0.5).of(29.23)
    end

    it "handles 3-digit hex and near-gray without NaN" do
      l, c, h = helper.relay_hex_to_oklch("#888")
      expect(l).to be_between(0.5, 0.7)
      expect(c).to be < 0.01
      expect(h).to be_a(Float)
    end
  end

  describe "#relay_brand_style_tag" do
    let(:org) { build(:organization, primary_color: "#0F766E") }

    it "renders a style tag with all 11 brand stops sharing the seed hue" do
      html = helper.relay_brand_style_tag(org)
      expect(html).to start_with("<style>")
      stops = html.scan(/--brand-(\d+):oklch\(([\d.]+) ([\d.]+) ([\d.]+)\)/)
      expect(stops.map(&:first)).to eq(%w[50 100 200 300 400 500 600 700 800 900 950])
      hues = stops.map { |s| s[3].to_f }.uniq
      expect(hues.size).to eq(1)
      lightnesses = stops.map { |s| s[1].to_f }
      expect(lightnesses).to eq(lightnesses.sort.reverse) # 50 lightest → 950 darkest
    end

    it "falls back to the Relay teal when organization is nil" do
      expect(helper.relay_brand_style_tag(nil)).to include("--brand-500:oklch(")
    end

    it "clamps chroma so near-gray brands stay visible" do
      gray = build(:organization, primary_color: "#808080")
      html = helper.relay_brand_style_tag(gray)
      c500 = html[/--brand-500:oklch\([\d.]+ ([\d.]+)/, 1].to_f
      expect(c500).to be >= 0.03
    end
  end
end
```

Note: check `spec/factories/` for an `organization` factory first; if absent, replace `build(:organization, ...)` with `Organization.new(name: "X", subdomain: "x", primary_color: ...)`.

- [ ] **Step 2: Run it to verify failure**

Run: `bundle exec rspec spec/helpers/relay/theme_helper_spec.rb`
Expected: FAIL — `uninitialized constant Relay::ThemeHelper`

- [ ] **Step 3: Implement the helper**

```ruby
# app/helpers/relay/theme_helper.rb
#
# White-label brand engine — Ruby port of docs/design/relay-ds/project/ds.js
# (applyBrand). A tenant supplies one color (Organization#primary_color);
# we derive the 11-stop --brand-* oklch ramp the entire DS repaints from.
module Relay
  module ThemeHelper
    # Shared lightness curve + per-stop chroma multipliers (from ds.js).
    BRAND_L     = [0.984, 0.954, 0.910, 0.846, 0.762, 0.682, 0.586, 0.498, 0.420, 0.350, 0.272].freeze
    BRAND_CMUL  = [0.16, 0.34, 0.56, 0.78, 0.93, 1.0, 0.90, 0.76, 0.62, 0.48, 0.37].freeze
    BRAND_STEPS = [50, 100, 200, 300, 400, 500, 600, 700, 800, 900, 950].freeze

    DEFAULT_BRAND_HEX = "#0F766E" # Relay demo teal
    CHROMA_RANGE = (0.03..0.22)   # keep near-grays visible, loud colors calm

    def relay_brand_style_tag(organization)
      hex = organization&.primary_color.presence || DEFAULT_BRAND_HEX
      _l, c, h = relay_hex_to_oklch(hex)
      c = c.clamp(CHROMA_RANGE.min, CHROMA_RANGE.max)
      props = BRAND_STEPS.each_with_index.map do |step, i|
        "--brand-#{step}:oklch(#{BRAND_L[i]} #{(c * BRAND_CMUL[i]).round(3)} #{h.round(1)})"
      end
      tag.style(":root{#{props.join(';')}}".html_safe)
    end

    # sRGB hex -> OKLCh [lightness, chroma, hue-degrees] (Björn Ottosson's OKLab).
    def relay_hex_to_oklch(hex)
      hex = hex.to_s.delete("#")
      hex = hex.chars.map { |ch| ch * 2 }.join if hex.length == 3
      r, g, b = [hex[0, 2], hex[2, 2], hex[4, 2]].map { |p| srgb_channel_to_linear(p.to_i(16) / 255.0) }

      l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
      m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
      s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b
      l_, m_, s_ = [l, m, s].map { |v| Math.cbrt(v) }

      lab_l = 0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_
      lab_a = 1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_
      lab_b = 0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_

      chroma = Math.sqrt(lab_a**2 + lab_b**2)
      hue = Math.atan2(lab_b, lab_a) * 180.0 / Math::PI
      hue += 360 if hue.negative?
      [lab_l, chroma, hue]
    end

    private

    def srgb_channel_to_linear(c)
      c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055)**2.4
    end
  end
end
```

- [ ] **Step 4: Run the spec to verify pass**

Run: `bundle exec rspec spec/helpers/relay/theme_helper_spec.rb`
Expected: all examples PASS. If the red assertion is off by more than the tolerance, the linearization or matrix constants were mistyped — re-check against the code above; do not widen tolerances.

### Task 3: Lucide icon vendoring + icon helper — TDD

Replicates the prototype's `Icon` component (`docs/design/relay-app/project/app/ui.jsx:13-40`): Lucide SVG, default size 18, default stroke-width 1.9, wrapped in an inline-flex `span.ic`; `linkedin` is hand-vendored (removed from Lucide).

**Files:**
- Create: `bin/relay_icons` (fetch script), `app/assets/images/lucide/*.svg` (fetched), `app/helpers/relay/icon_helper.rb`
- Test: `spec/helpers/relay/icon_helper_spec.rb`

- [ ] **Step 1: Write the fetch script**

```bash
#!/usr/bin/env bash
# bin/relay_icons — vendor Lucide SVGs used by the Relay UI.
# Add names to the list and re-run; existing files are skipped.
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)/app/assets/images/lucide"
mkdir -p "$DIR"

ICONS=(
  sunrise users message-square layers megaphone bar-chart-3 receipt settings
  chevrons-left chevrons-right chevron-up chevron-down search plus user-plus
  circle-dollar-sign check-square upload phone bell shield users-2 user
  user-cog plug log-out check check-circle-2 alert-circle info x calculator
  palette inbox hammer
)

for name in "${ICONS[@]}"; do
  [ -f "$DIR/$name.svg" ] && continue
  curl -fsSL "https://unpkg.com/lucide-static@latest/icons/$name.svg" -o "$DIR/$name.svg"
  echo "fetched $name"
done

# linkedin was removed from Lucide — vendor the brand glyph the prototype uses
# (docs/design/relay-app/project/app/ui.jsx INLINE_ICONS).
cat > "$DIR/linkedin.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" stroke="none"><path d="M20.45 20.45h-3.55v-5.57c0-1.33-.02-3.04-1.85-3.04-1.85 0-2.14 1.45-2.14 2.94v5.66H9.35V9h3.41v1.56h.05c.47-.9 1.64-1.85 3.37-1.85 3.6 0 4.27 2.37 4.27 5.45v6.29zM5.34 7.43a2.06 2.06 0 1 1 0-4.12 2.06 2.06 0 0 1 0 4.12zM7.12 20.45H3.55V9h3.57v11.45zM22.22 0H1.77C.79 0 0 .77 0 1.73v20.54C0 23.22.79 24 1.77 24h20.45c.98 0 1.78-.78 1.78-1.73V1.73C24 .77 23.2 0 22.22 0z"/></svg>
SVG
echo "wrote linkedin"
```

Then: `chmod +x bin/relay_icons && bin/relay_icons`
Expected: one `fetched <name>` line per icon + `wrote linkedin`; files exist under `app/assets/images/lucide/`. (Requires network; if unpkg is unreachable, retry or use `https://cdn.jsdelivr.net/npm/lucide-static@latest/icons/$name.svg`.)

- [ ] **Step 2: Write the failing helper spec**

```ruby
# spec/helpers/relay/icon_helper_spec.rb
require "rails_helper"

RSpec.describe Relay::IconHelper, type: :helper do
  it "renders a vendored lucide icon at the requested size and stroke" do
    html = helper.relay_icon("check", size: 20)
    expect(html).to include('class="ic"')
    expect(html).to include('width="20"')
    expect(html).to include('stroke-width="1.9"')
    expect(html).to include("<svg")
  end

  it "renders the hand-vendored linkedin icon" do
    expect(helper.relay_icon("linkedin")).to include("<svg")
  end

  it "renders a visible placeholder for unknown icons instead of raising" do
    html = helper.relay_icon("no-such-icon")
    expect(html).to include("ic--missing")
  end
end
```

- [ ] **Step 3: Run it to verify failure**

Run: `bundle exec rspec spec/helpers/relay/icon_helper_spec.rb`
Expected: FAIL — `uninitialized constant Relay::IconHelper`

- [ ] **Step 4: Implement the helper**

```ruby
# app/helpers/relay/icon_helper.rb
#
# Inline-SVG Lucide icons (vendored under app/assets/images/lucide via
# bin/relay_icons). Mirrors the prototype's Icon component: span.ic wrapper,
# default 18px, 1.9 stroke. Icons inherit currentColor.
module Relay
  module IconHelper
    LUCIDE_DIR = Rails.root.join("app/assets/images/lucide")

    def relay_icon(name, size: 18, stroke: 1.9, css: nil)
      raw = relay_icon_source(name.to_s)
      style = "display:inline-flex;width:#{size.to_i}px;height:#{size.to_i}px;flex:none"
      unless raw
        Rails.logger.warn("relay_icon: missing icon #{name} — run bin/relay_icons") if Rails.env.development?
        return tag.span(class: "ic ic--missing", style: style, title: "missing icon: #{name}")
      end
      svg = raw.sub("<svg", %(<svg width="#{size.to_i}" height="#{size.to_i}" stroke-width="#{stroke}"))
      tag.span(svg.html_safe, class: ["ic", css].compact.join(" "), style: style)
    end

    private

    # Strip the source width/height/stroke-width so per-call values apply.
    # Cached per-process in production; re-read each call in development.
    def relay_icon_source(name)
      return read_icon(name) if Rails.env.development?
      (@@relay_icon_cache ||= {})[name] ||= read_icon(name)
    end

    def read_icon(name)
      path = LUCIDE_DIR.join("#{name}.svg")
      return nil unless name.match?(/\A[a-z0-9-]+\z/) && path.exist?
      path.read.gsub(/\s(width|height|stroke-width)="[^"]*"/, "")
    end
  end
end
```

- [ ] **Step 5: Run the spec to verify pass**

Run: `bundle exec rspec spec/helpers/relay/icon_helper_spec.rb`
Expected: all examples PASS.

### Task 4: Relay layout + nav helper

**Files:**
- Create: `app/views/layouts/relay.html.erb`, `app/helpers/relay/nav_helper.rb`
- Reference: shell markup in `docs/design/relay-app/project/Relay.html:35-46` and `app/shell.jsx`

- [ ] **Step 1: Write the nav helper**

Nav items point at **existing** routes (Inbox arrives in Phase 6). Active state by controller name.

```ruby
# app/helpers/relay/nav_helper.rb
module Relay
  module NavHelper
    # Sidebar nav: [group label, items]. Each item: label/icon/path/controllers
    # that mark it active. Keep icons in sync with bin/relay_icons.
    def relay_nav_groups
      [
        ["Workspace", [
          { label: "Today",    icon: "sunrise",     path: dashboard_path,  controllers: %w[user_dashboard my_tasks_dashboard manager] },
          { label: "Leads",    icon: "users",       path: customers_path,  controllers: %w[customers csv_imports customer_followups] },
          { label: "Pipeline", icon: "layers",      path: deals_path,      controllers: %w[deals pipelines deal_stages] },
          { label: "Outreach", icon: "megaphone",   path: campaigns_path,  controllers: %w[campaigns customer_groups whatsapp_templates] },
          { label: "Insights", icon: "bar-chart-3", path: reports_path,    controllers: %w[reports] },
        ]],
        ["Money", [
          { label: "Quotes & invoices", icon: "receipt", path: invoices_path,
            controllers: %w[all_invoices invoices cost_estimates odoo_proposals milestones] },
        ]],
      ]
    end

    def relay_nav_active?(item)
      item[:controllers].include?(controller_name)
    end
  end
end
```

- [ ] **Step 2: Write the layout**

```erb
<%# app/views/layouts/relay.html.erb — Relay console shell %>
<!DOCTYPE html>
<html lang="en">
  <head>
    <title><%= content_for(:title) || current_organization&.name || "Relay" %></title>
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>
    <%= stylesheet_link_tag "relay/fonts", "relay/colors_and_type", "relay/tokens",
                            "relay/components", "relay/components-data", "relay/components-nav",
                            "relay/app", "data-turbo-track": "reload" %>
    <%= relay_brand_style_tag(current_organization) %>
    <%= javascript_importmap_tags %>
    <%= yield :head %>
  </head>

  <body data-controller="relay--command-palette"
        data-action="keydown@window->relay--command-palette#keydown">
    <div class="app" data-controller="relay--sidebar">
      <%= render "relay/shared/sidebar" %>
      <div class="app__main">
        <%= render "relay/shared/topbar" %>
        <main class="app__body" id="relay_body"><%= yield %></main>
      </div>
    </div>

    <%= render "relay/shared/command_palette" %>
    <%= render "relay/shared/toasts" %>
  </body>
</html>
```

- [ ] **Step 3: Boot check**

Run: `bin/rails runner 'ApplicationController.render(template: "layouts/relay", assigns: {}) rescue puts $!.message'`
Expected: a missing-partial error mentioning `relay/shared/sidebar` (partials come next) — NOT a syntax/helper error. Helpers in `app/helpers` are auto-included.

### Task 5: Sidebar partial + collapse controller

**Files:**
- Create: `app/views/relay/shared/_sidebar.html.erb`, `app/javascript/controllers/relay/sidebar_controller.js`
- Reference: `docs/design/relay-app/project/app/shell.jsx:16-67` (Sidebar), DS classes in `relay/components-nav.css` (`rl-sidebar`, `rl-navlink`, `rl-navgroup-label`, `rl-userchip`)

- [ ] **Step 1: Write the sidebar partial**

```erb
<%# app/views/relay/shared/_sidebar.html.erb %>
<aside class="rl-sidebar" data-relay--sidebar-target="aside">
  <div class="rl-sidebar__brand">
    <span class="rl-logo">
      <% if current_organization&.logo&.attached? %>
        <%= image_tag current_organization.logo, alt: current_organization.name,
              style: "width:26px;height:26px;border-radius:7px;object-fit:cover" %>
      <% else %>
        <svg viewBox="0 0 32 32" fill="none"><path d="M6 7.5 L14.5 16 L6 24.5" stroke="currentColor" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/><path d="M15.5 7.5 L24 16 L15.5 24.5" stroke="currentColor" stroke-width="4" stroke-linecap="round" stroke-linejoin="round" opacity="0.55"/></svg>
      <% end %>
    </span>
    <b><%= current_organization&.name || "Relay" %></b>
  </div>

  <nav class="rl-sidebar__nav">
    <% relay_nav_groups.each do |group_label, items| %>
      <div class="rl-navgroup-label"><%= group_label %></div>
      <% items.each do |item| %>
        <%= link_to item[:path], class: class_names("rl-navlink", "is-active" => relay_nav_active?(item)), title: item[:label] do %>
          <%= relay_icon(item[:icon], size: 18) %>
          <span><%= item[:label] %></span>
        <% end %>
      <% end %>
    <% end %>

    <div style="flex:1"></div>
    <div class="rl-navgroup-label">System</div>
    <%= link_to settings_path, class: class_names("rl-navlink", "is-active" => %w[settings users branding roles role_assignments].include?(controller_name)), title: "Settings" do %>
      <%= relay_icon("settings", size: 18) %><span>Settings</span>
    <% end %>
    <a class="rl-navlink" data-action="click->relay--sidebar#toggle" title="Collapse" role="button">
      <span data-relay--sidebar-target="collapseIcon"><%= relay_icon("chevrons-left", size: 18) %></span>
      <span data-relay--sidebar-target="expandIcon" hidden><%= relay_icon("chevrons-right", size: 18) %></span>
      <span>Collapse</span>
    </a>
  </nav>

  <div class="rl-sidebar__foot">
    <%= link_to settings_path, class: "rl-userchip" do %>
      <span class="rl-avatar rl-avatar--sm rl-avatar--c1"><%= current_user&.name.to_s.split.map(&:first).join[0, 2].upcase %></span>
      <span class="rl-userchip__main">
        <span class="rl-userchip__name"><%= current_user&.name %></span>
        <span class="rl-userchip__role" style="text-transform:capitalize"><%= current_user&.role %> · <%= current_organization&.name %></span>
      </span>
      <%= relay_icon("chevron-up", size: 15) %>
    <% end %>
  </div>
</aside>
```

Note: verify avatar/userchip class names against `relay/components-nav.css` and `relay/components.css` while implementing — use the classes defined there (`grep -n "rl-avatar\|rl-userchip" app/assets/stylesheets/relay/*.css`); never invent class names.

- [ ] **Step 2: Write the collapse controller**

```javascript
// app/javascript/controllers/relay/sidebar_controller.js
// Collapses the sidebar to icon rail (DS class `is-collapsed`), persisted.
import { Controller } from "@hotwired/stimulus"

const KEY = "relay:sidebar-collapsed"

export default class extends Controller {
  static targets = ["aside", "collapseIcon", "expandIcon"]

  connect() {
    this.apply(localStorage.getItem(KEY) === "1")
  }

  toggle() {
    this.apply(!this.asideTarget.classList.contains("is-collapsed"))
  }

  apply(collapsed) {
    this.asideTarget.classList.toggle("is-collapsed", collapsed)
    if (this.hasCollapseIconTarget) this.collapseIconTarget.hidden = collapsed
    if (this.hasExpandIconTarget) this.expandIconTarget.hidden = !collapsed
    localStorage.setItem(KEY, collapsed ? "1" : "0")
  }
}
```

(`eagerLoadControllersFrom("controllers", application)` in `app/javascript/controllers/index.js` auto-registers it as `relay--sidebar` — no manual registration.)

### Task 6: Topbar partial + dropdown controller + notifications panel

**Files:**
- Create: `app/views/relay/shared/_topbar.html.erb`, `app/views/relay/shared/_notifications.html.erb`, `app/javascript/controllers/relay/dropdown_controller.js`
- Modify: `app/controllers/notifications_controller.rb` (`mark_as_read`, `mark_all_as_read` — add turbo_stream)
- Reference: `docs/design/relay-app/project/app/shell.jsx:70-176` (Topbar + NotifPanel)

- [ ] **Step 1: Write the generic dropdown controller**

```javascript
// app/javascript/controllers/relay/dropdown_controller.js
// Generic disclosure: toggles [data-relay--dropdown-target="menu"],
// closes on outside click and Escape.
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]

  connect() {
    this.close = this.close.bind(this)
    this.onKeydown = (e) => { if (e.key === "Escape") this.close() }
  }

  toggle(event) {
    event.stopPropagation()
    this.menuTarget.hidden ? this.open() : this.close()
  }

  open() {
    this.menuTarget.hidden = false
    document.addEventListener("click", this.close)
    document.addEventListener("keydown", this.onKeydown)
  }

  close() {
    this.menuTarget.hidden = true
    document.removeEventListener("click", this.close)
    document.removeEventListener("keydown", this.onKeydown)
  }

  disconnect() { this.close() }
}
```

- [ ] **Step 2: Write the topbar partial**

```erb
<%# app/views/relay/shared/_topbar.html.erb %>
<header class="app__top">
  <div class="app__search" role="button" data-action="click->relay--command-palette#open">
    <%= relay_icon("search", size: 16) %>
    <input readonly placeholder="Search leads, deals, actions…">
    <span class="rl-kbd">⌘K</span>
  </div>
  <div class="grow"></div>

  <%# Quick add %>
  <span data-controller="relay--dropdown" style="position:relative;display:inline-flex">
    <button class="rl-btn rl-btn--primary rl-btn--sm" data-action="click->relay--dropdown#toggle">
      <%= relay_icon("plus", size: 15) %>New<%= relay_icon("chevron-down", size: 14) %>
    </button>
    <div class="menu-float pop" hidden data-relay--dropdown-target="menu" style="top:calc(100% + 8px);right:0">
      <div class="rl-menu" style="width:210px">
        <%= link_to new_customer_path, class: "rl-menuitem" do %><%= relay_icon("user-plus") %>Add lead<% end %>
        <%= link_to new_deal_path, class: "rl-menuitem" do %><%= relay_icon("circle-dollar-sign") %>Create deal<% end %>
        <%= link_to new_task_path, class: "rl-menuitem" do %><%= relay_icon("check-square") %>Add task<% end %>
        <div class="rl-menu__sep"></div>
        <%= link_to new_campaign_path, class: "rl-menuitem" do %><%= relay_icon("megaphone") %>New campaign<% end %>
        <%= link_to new_csv_import_path, class: "rl-menuitem" do %><%= relay_icon("upload") %>Import CSV<% end %>
      </div>
    </div>
  </span>

  <%= link_to "/calling", class: "rl-iconbtn rl-iconbtn--bordered", title: "Dialer" do %>
    <%= relay_icon("phone", size: 17) %>
  <% end %>

  <%# Notifications %>
  <span data-controller="relay--dropdown" style="position:relative;display:inline-flex">
    <button class="rl-iconbtn rl-iconbtn--bordered" style="position:relative" title="Notifications"
            data-action="click->relay--dropdown#toggle">
      <%= relay_icon("bell", size: 17) %>
      <% unread = current_user ? current_user.notifications.unread.count : 0 %>
      <% if unread > 0 %><span class="dotcount"><%= unread > 99 ? "99+" : unread %></span><% end %>
    </button>
    <div class="menu-float pop" hidden data-relay--dropdown-target="menu"
         style="top:calc(100% + 8px);right:0" data-action="click->relay--dropdown#noop:stop">
      <%= render "relay/shared/notifications" %>
    </div>
  </span>

  <%# Profile %>
  <span data-controller="relay--dropdown" style="position:relative;display:inline-flex">
    <button style="border:none;background:none;padding:0;display:inline-flex;cursor:pointer"
            data-action="click->relay--dropdown#toggle">
      <span class="rl-avatar rl-avatar--sm rl-avatar--c1"><%= current_user&.name.to_s.split.map(&:first).join[0, 2].upcase %></span>
    </button>
    <div class="menu-float pop" hidden data-relay--dropdown-target="menu" style="top:calc(100% + 8px);right:0">
      <div class="rl-menu" style="width:230px">
        <div style="padding:8px 10px 10px;display:flex;gap:10px;align-items:center">
          <span class="rl-avatar rl-avatar--c1"><%= current_user&.name.to_s.split.map(&:first).join[0, 2].upcase %></span>
          <div style="min-width:0">
            <div style="font-weight:700;font-size:var(--text-sm)"><%= current_user&.name %></div>
            <div class="muted" style="font-size:12px"><%= current_user&.email %></div>
          </div>
        </div>
        <div class="rl-menu__sep"></div>
        <%= link_to settings_path, class: "rl-menuitem" do %><%= relay_icon("user-cog") %>Profile &amp; preferences<% end %>
        <%= link_to settings_path, class: "rl-menuitem" do %><%= relay_icon("plug") %>Connections<% end %>
        <div class="rl-menu__sep"></div>
        <%= link_to signout_url(subdomain: false), class: "rl-menuitem is-danger", data: { turbo: false } do %><%= relay_icon("log-out") %>Sign out<% end %>
      </div>
    </div>
  </span>
</header>
```

Implementation notes: a) `noop:stop` — add `noop() {}` to the dropdown controller so panel clicks don't bubble to the document-level close; b) verify `signout` works cross-subdomain (it's defined on the root domain — check `signout_url(subdomain: false)` resolves; adjust to the pattern used by the old layout, see `grep -rn signout app/views/layouts/`); c) verify `rl-menu`/`rl-menuitem`/`rl-iconbtn` class names against `relay/components-nav.css` and `relay/components.css`.

- [ ] **Step 3: Write the notifications panel partial**

```erb
<%# app/views/relay/shared/_notifications.html.erb %>
<turbo-frame id="relay_notifications">
  <div class="rl-popover" style="width:360px">
    <div class="rl-popover__head">
      <b style="font-size:var(--text-sm);font-weight:700">Notifications</b>
      <%= button_to "Mark all read", mark_all_as_read_notifications_path,
            class: "rl-btn rl-btn--ghost rl-btn--sm", form: { data: { turbo_frame: "relay_notifications" } } %>
    </div>
    <div style="max-height:380px;overflow-y:auto">
      <% notifications = current_user ? current_user.notifications.recent.limit(15) : [] %>
      <% if notifications.none? %>
        <div class="empty" style="padding:var(--space-8)">
          <span class="empty__ic"><%= relay_icon("bell", size: 26) %></span>
          <div style="font-weight:700">You're all caught up</div>
        </div>
      <% end %>
      <% notifications.each do |n| %>
        <%= link_to notification_path(n), class: "rl-listitem clickable", data: { turbo_frame: "_top" },
              style: ("background:var(--color-primary-subtle)" unless n.read) do %>
          <span class="iccircle" style="background:var(--color-surface-3);color:var(--color-fg-2)">
            <%= relay_icon({ "message" => "message-square", "task" => "check-square", "deal" => "circle-dollar-sign" }.fetch(n.notification_type, "info"), size: 17) %>
          </span>
          <span class="rl-listitem__main">
            <span class="rl-listitem__title"><%= n.notification_type&.titleize || "System" %></span>
            <span class="rl-listitem__sub"><%= n.content %></span>
          </span>
          <span style="text-align:right;flex:none">
            <span class="muted" style="font-size:11px"><%= time_ago_in_words(n.created_at) %> ago</span>
            <% unless n.read %><span style="display:inline-block;width:8px;height:8px;border-radius:999px;background:var(--color-primary);margin-top:6px"></span><% end %>
          </span>
        <% end %>
      <% end %>
    </div>
  </div>
</turbo-frame>
```

(`notifications#show` already marks-as-read and redirects to the resource — reuse it; `data-turbo-frame="_top"` breaks out of the frame for that navigation. Verify `rl-listitem`/`rl-popover` class names against the DS CSS.)

- [ ] **Step 4: Make mark_all_as_read answer turbo_stream**

In `app/controllers/notifications_controller.rb`, inside `mark_all_as_read`'s `respond_to` block, add:

```ruby
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace("relay_notifications",
          partial: "relay/shared/notifications")
      end
```

- [ ] **Step 5: Run the existing notification specs**

Run: `bundle exec rspec spec/requests 2>/dev/null | tail -5` (scope to notification specs if present: `ls spec/requests`)
Expected: no new failures (pre-existing failures, if any, noted but untouched).

### Task 7: Flash → toasts

**Files:**
- Create: `app/views/relay/shared/_toasts.html.erb`, `app/javascript/controllers/relay/toast_controller.js`
- Reference: toast CSS in `relay/app.css:177-184`, prototype timing 2600ms (`main.jsx:50`)

- [ ] **Step 1: Write the toasts partial**

```erb
<%# app/views/relay/shared/_toasts.html.erb %>
<div class="toasts" id="relay_toasts" data-controller="relay--toast">
  <% flash.each do |type, message| %>
    <% kind = { "notice" => "success", "success" => "success", "alert" => "danger", "error" => "danger" }.fetch(type.to_s, "info") %>
    <div class="toast toast--<%= kind %>" data-relay--toast-target="item">
      <%= relay_icon(kind == "success" ? "check-circle-2" : kind == "danger" ? "alert-circle" : "info", size: 17) %>
      <%= message %>
    </div>
  <% end %>
</div>
```

- [ ] **Step 2: Write the toast controller**

```javascript
// app/javascript/controllers/relay/toast_controller.js
// Auto-dismisses server-rendered toasts after 2.6s (matches prototype).
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["item"]

  itemTargetConnected(el) {
    setTimeout(() => {
      el.style.transition = "opacity .3s var(--ease-out)"
      el.style.opacity = "0"
      setTimeout(() => el.remove(), 300)
    }, 2600)
  }
}
```

(`itemTargetConnected` also fires for toasts appended later via Turbo Streams — future phases broadcast into `#relay_toasts`.)

### Task 8: Command palette

**Files:**
- Create: `app/views/relay/shared/_command_palette.html.erb`, `app/javascript/controllers/relay/command_palette_controller.js`
- Reference: `docs/design/relay-app/project/app/shell.jsx:179-248`; DS classes `rl-cmd*` in `relay/components-nav.css`

Scope: navigation + actions, client-side filtering, full keyboard support. Lead search joins in Phase 3.

- [ ] **Step 1: Write the palette partial**

```erb
<%# app/views/relay/shared/_command_palette.html.erb %>
<div class="scrim" hidden data-relay--command-palette-target="scrim"
     style="align-items:flex-start;padding-top:12vh;z-index:var(--z-command)"
     data-action="mousedown->relay--command-palette#backdrop">
  <div class="rl-cmd pop">
    <div class="rl-cmd__input">
      <%= relay_icon("search", size: 20) %>
      <input data-relay--command-palette-target="input" placeholder="Type a command or search…"
             data-action="input->relay--command-palette#filter keydown->relay--command-palette#navigate">
      <span class="rl-kbd">esc</span>
    </div>
    <div class="rl-cmd__list" data-relay--command-palette-target="list">
      <% {
        "Go to" => [
          ["sunrise", "Today", dashboard_path], ["users", "Leads", customers_path],
          ["layers", "Pipeline", deals_path], ["megaphone", "Outreach", campaigns_path],
          ["bar-chart-3", "Insights", reports_path], ["receipt", "Quotes & invoices", invoices_path],
          ["settings", "Settings", settings_path],
        ],
        "Actions" => [
          ["user-plus", "Add lead", new_customer_path], ["circle-dollar-sign", "Create deal", new_deal_path],
          ["check-square", "Add task", new_task_path], ["upload", "Import leads from CSV", new_csv_import_path],
          ["megaphone", "New campaign", new_campaign_path],
        ],
      }.each do |group, items| %>
        <div data-relay--command-palette-target="group">
          <div class="rl-cmd__group"><%= group %></div>
          <% items.each do |icon, label, path| %>
            <%= link_to path, class: "rl-cmd__item", data: { "relay--command-palette-target": "item", label: label.downcase } do %>
              <%= relay_icon(icon, size: 17) %><span><%= label %></span>
            <% end %>
          <% end %>
        </div>
      <% end %>
      <div hidden class="muted" data-relay--command-palette-target="blank"
           style="padding:20px;text-align:center;font-size:var(--text-sm)">No results.</div>
    </div>
    <div class="rl-cmd__foot">
      <span class="rl-cmd-hint"><span class="rl-kbd">↑</span><span class="rl-kbd">↓</span> navigate</span>
      <span class="rl-cmd-hint"><span class="rl-kbd">↵</span> select</span>
      <span class="rl-cmd-hint"><span class="rl-kbd">esc</span> close</span>
    </div>
  </div>
</div>
```

- [ ] **Step 2: Write the palette controller**

```javascript
// app/javascript/controllers/relay/command_palette_controller.js
// ⌘K palette: open/close, filter, arrow-key selection, enter to follow.
// Lives on <body>; the topbar search box and keydown@window route here.
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["scrim", "input", "list", "item", "group", "blank"]

  keydown(e) {
    if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === "k") { e.preventDefault(); this.toggle() }
    else if (e.key === "Escape" && !this.scrimTarget.hidden) this.close()
  }

  open() {
    this.scrimTarget.hidden = false
    this.inputTarget.value = ""
    this.filter()
    setTimeout(() => this.inputTarget.focus(), 30)
  }

  close() { this.scrimTarget.hidden = true }
  toggle() { this.scrimTarget.hidden ? this.open() : this.close() }
  backdrop(e) { if (e.target === this.scrimTarget) this.close() }

  filter() {
    const q = this.inputTarget.value.trim().toLowerCase()
    let any = false
    this.itemTargets.forEach((el) => {
      const hit = !q || el.dataset.label.includes(q)
      el.hidden = !hit
      if (hit) any = true
    })
    this.groupTargets.forEach((g) => {
      g.hidden = !g.querySelector("[data-relay--command-palette-target='item']:not([hidden])")
    })
    this.blankTarget.hidden = any
    this.select(0)
  }

  navigate(e) {
    const visible = this.itemTargets.filter((el) => !el.hidden)
    if (e.key === "ArrowDown") { e.preventDefault(); this.select(Math.min(this.index + 1, visible.length - 1)) }
    else if (e.key === "ArrowUp") { e.preventDefault(); this.select(Math.max(this.index - 1, 0)) }
    else if (e.key === "Enter") { e.preventDefault(); visible[this.index]?.click(); this.close() }
  }

  select(i) {
    this.index = i
    this.itemTargets.filter((el) => !el.hidden).forEach((el, j) => {
      el.classList.toggle("is-active", j === i)
      if (j === i) el.scrollIntoView({ block: "nearest" })
    })
  }
}
```

### Task 9: Modal, drawer, and tabs primitives

Generic open/close primitives later phases compose. DS markup: `.scrim > .rl-modal` and `.drawer` (`relay/app.css:163-172`, `relay/components-nav.css`).

**Files:**
- Create: `app/javascript/controllers/relay/overlay_controller.js`, `app/javascript/controllers/relay/tabs_controller.js`

- [ ] **Step 1: Write the overlay controller (covers modal + drawer)**

```javascript
// app/javascript/controllers/relay/overlay_controller.js
// Generic modal/drawer: any element with target="panel" (a .scrim wrapper
// for modals, or a .drawer) is shown/hidden. One controller instance wraps
// trigger + panel.
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel"]

  connect() { this.onKeydown = (e) => { if (e.key === "Escape") this.close() } }

  open() {
    this.panelTarget.hidden = false
    document.addEventListener("keydown", this.onKeydown)
  }

  close() {
    this.panelTarget.hidden = true
    document.removeEventListener("keydown", this.onKeydown)
  }

  backdrop(e) { if (e.target === this.panelTarget) this.close() }

  disconnect() { document.removeEventListener("keydown", this.onKeydown) }
}
```

- [ ] **Step 2: Write the tabs controller**

```javascript
// app/javascript/controllers/relay/tabs_controller.js
// DS tabs (.rl-tabs / .rl-tab with is-active) switching same-page panels.
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel"]
  static values = { index: { type: Number, default: 0 } }

  connect() { this.show(this.indexValue) }

  switch(e) { this.show(this.tabTargets.indexOf(e.currentTarget)) }

  show(i) {
    this.tabTargets.forEach((t, j) => t.classList.toggle("is-active", j === i))
    this.panelTargets.forEach((p, j) => (p.hidden = j !== i))
  }
}
```

(Existing `tabs_controller.js` serves the old UI and is untouched; the relay one registers separately as `relay--tabs`. Verify `.rl-tab` class names against `relay/components-nav.css` when building the styleguide demo.)

### Task 10: Dev-only styleguide page

The verification surface for this phase: renders the full shell + DS component samples with the relay layout, on real tenant chrome.

**Files:**
- Create: `app/controllers/relay_styleguide_controller.rb`, `app/views/relay_styleguide/index.html.erb`
- Modify: `config/routes.rb` (inside the `TenantSubdomain` constraint block)

- [ ] **Step 1: Add the route**

In `config/routes.rb`, inside `constraints(TenantSubdomain) do`, add near the top:

```ruby
    # Relay redesign styleguide (development only).
    get "_relay", to: "relay_styleguide#index" if Rails.env.development?
```

- [ ] **Step 2: Write the controller**

```ruby
# app/controllers/relay_styleguide_controller.rb
#
# Development-only gallery proving the Relay foundation: layout, shell,
# tokens, and Stimulus primitives. Not routed outside development.
class RelayStyleguideController < TenantController
  layout "relay"

  def index
    flash.now[:notice] = "Foundation loaded — this is a toast." if params[:toast]
  end
end
```

(Check `TenantController` for the auth before_actions the old pages use; inherit the same way `BrandingController` does.)

- [ ] **Step 3: Write the styleguide view**

```erb
<%# app/views/relay_styleguide/index.html.erb %>
<div class="page">
  <div class="pagehead">
    <div>
      <div class="pagehead__title">Relay foundation</div>
      <div class="pagehead__sub">Design-system port, shell, and primitives — development only.</div>
    </div>
    <div class="pagehead__actions">
      <%= link_to "Trigger toast", "?toast=1", class: "rl-btn rl-btn--secondary rl-btn--sm" %>
    </div>
  </div>

  <div class="grid grid-2">
    <div class="sect">
      <div class="sect__head"><div class="sect__title"><%= relay_icon("palette", size: 17) %>Buttons &amp; badges</div></div>
      <div class="sect__body">
        <div class="row row--wrap" style="margin-bottom:var(--space-4)">
          <button class="rl-btn rl-btn--primary">Add lead</button>
          <button class="rl-btn rl-btn--secondary">Log call</button>
          <button class="rl-btn rl-btn--ghost">Cancel</button>
          <button class="rl-btn rl-btn--danger">Delete</button>
        </div>
        <div class="row row--wrap">
          <span class="rl-badge rl-badge--success">Won</span>
          <span class="rl-badge rl-badge--warning">Follow up</span>
          <span class="rl-badge rl-badge--danger">Overdue</span>
          <span class="rl-badge rl-badge--info">New</span>
        </div>
      </div>
    </div>

    <div class="sect" data-controller="relay--tabs">
      <div class="sect__head">
        <div class="sect__title"><%= relay_icon("layers", size: 17) %>Tabs</div>
        <div class="rl-tabs">
          <button class="rl-tab" data-relay--tabs-target="tab" data-action="click->relay--tabs#switch">First</button>
          <button class="rl-tab" data-relay--tabs-target="tab" data-action="click->relay--tabs#switch">Second</button>
        </div>
      </div>
      <div class="sect__body" data-relay--tabs-target="panel">Panel one — tokens drive everything you see.</div>
      <div class="sect__body" data-relay--tabs-target="panel" hidden>Panel two — switched client-side.</div>
    </div>

    <div class="sect" data-controller="relay--overlay">
      <div class="sect__head"><div class="sect__title"><%= relay_icon("info", size: 17) %>Modal</div></div>
      <div class="sect__body">
        <button class="rl-btn rl-btn--secondary" data-action="click->relay--overlay#open">Open modal</button>
        <div class="scrim" hidden data-relay--overlay-target="panel" data-action="mousedown->relay--overlay#backdrop">
          <div class="rl-modal pop" style="width:440px">
            <div class="rl-modal__head"><b>Sample modal</b></div>
            <div class="rl-modal__body">Composed from DS classes; closes on Escape and backdrop.</div>
            <div class="rl-modal__foot">
              <button class="rl-btn rl-btn--ghost" data-action="click->relay--overlay#close">Close</button>
              <button class="rl-btn rl-btn--primary" data-action="click->relay--overlay#close">Confirm</button>
            </div>
          </div>
        </div>
      </div>
    </div>

    <div class="sect" data-controller="relay--overlay">
      <div class="sect__head"><div class="sect__title"><%= relay_icon("chevrons-left", size: 17) %>Drawer</div></div>
      <div class="sect__body">
        <button class="rl-btn rl-btn--secondary" data-action="click->relay--overlay#open">Open drawer</button>
        <div class="drawer" hidden data-relay--overlay-target="panel">
          <div class="drawer__head"><b class="grow">Sample drawer</b>
            <button class="rl-iconbtn" data-action="click->relay--overlay#close"><%= relay_icon("x", size: 16) %></button>
          </div>
          <div class="drawer__body">Right-hand drawer used by deal details and money actions in later phases.</div>
          <div class="drawer__foot"><button class="rl-btn rl-btn--primary" data-action="click->relay--overlay#close">Done</button></div>
        </div>
      </div>
    </div>
  </div>

  <div class="sect" style="margin-top:var(--space-4)">
    <div class="sect__head"><div class="sect__title"><%= relay_icon("users", size: 17) %>Empty state</div></div>
    <div class="empty">
      <span class="empty__ic"><%= relay_icon("inbox", size: 26) %></span>
      <div style="font-weight:700;font-family:var(--font-display)">Inbox zero</div>
      <div class="muted" style="font-size:var(--text-sm)">You've replied to every lead.</div>
    </div>
  </div>
</div>
```

(While building: cross-check every `rl-*` class used here against the DS CSS files; fix any that don't exist — e.g. modal class names — by reading `relay/components-nav.css`. The DS galleries `docs/design/relay-ds/project/*.html` show canonical markup.)

### Task 11: Full verification pass

- [ ] **Step 1: Run the whole spec suite**

Run: `bundle exec rspec`
Expected: new helper specs pass; zero NEW failures vs. a baseline run from before this work (`git stash` first if a baseline is needed).

- [ ] **Step 2: Boot and visually verify**

```bash
bin/dev
```

Visit `http://<existing-org-subdomain>.lvh.me:3000/_relay` (sign in via `/dev_login` on the root domain first; check `Organization.first.subdomain` in `bin/rails console` for a valid subdomain).

Checklist against `docs/design/relay-app/project/screenshots/today.png` (chrome only) and `docs/design/relay-ds/project/overlays.html`:
- Dark slate sidebar 264px, org name + logo/mark, grouped nav (Workspace/Money/System), active state on hover/current
- Collapse toggles to 64px rail and persists across reloads
- Topbar: search field (⌘K hint), New dropdown with 5 items, dialer icon, bell with unread count, avatar menu
- ⌘K opens palette; typing filters; ↑/↓/↵ navigate; esc closes
- "Trigger toast" shows a dark toast bottom-center that auto-dismisses ~2.6s
- Modal + drawer open/close (button, Escape, backdrop)
- Brand check: change `Organization#primary_color` in console (e.g. `#7C3AED`), reload — sidebar active states, buttons, focus rings all reskin
- Browser console: zero errors
- Old app unaffected: visit `/customers` — old layout still renders

- [ ] **Step 3: STOP — user review**

Present the styleguide to the user. **Do not commit.** Per user instruction, all Phase 1 changes stay uncommitted until the user reviews and approves.

---

## Self-review notes

- **Spec coverage (Phase 1 scope):** DS CSS port (T1), relay layout (T4), shell sidebar/topbar/notifications (T5–6), brand-ramp helper + tenant theming (T2), icon helper (T3), Stimulus primitives dropdown/modal/drawer/toast/tabs/command-palette (T6–9), flash-as-toast (T7). ✔
- **Type consistency:** controller identifiers are `relay--sidebar`, `relay--dropdown`, `relay--toast`, `relay--command-palette`, `relay--overlay`, `relay--tabs` throughout; helper names `relay_brand_style_tag`, `relay_hex_to_oklch`, `relay_icon`, `relay_nav_groups`, `relay_nav_active?` consistent across tasks. ✔
- **Known unknowns called out inline** (verify during implementation, all with exact grep commands): DS class names for avatar/userchip/menu/popover/listitem/modal/tab, signout URL pattern, organization factory existence, TenantController auth hooks.
- **No placeholders:** every step has complete code or an exact command. ✔
