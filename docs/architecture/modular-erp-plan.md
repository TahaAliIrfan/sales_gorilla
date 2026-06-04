# Modular ERP Architecture Plan

**Status:** Proposed — awaiting implementation kickoff
**Owner:** Taha
**Last updated:** 2026-06-04

## Goal

Transform the CRM into a modular ERP-style platform where each functional area (Calling, Messaging, Email, etc.) can be:

1. **Enabled/disabled per organization** via a settings UI
2. **Swapped between providers** without touching business logic (e.g., Twilio → Plivo for Calling)
3. **Developed and deployed as a self-contained module** (Rails Engine)

This document covers the **first module: Calling**. The pattern established here becomes the template for subsequent modules.

## Decisions (locked)

| Decision | Choice |
|---|---|
| Feature toggle scope | Per organization |
| First module | Calling (Twilio) |
| Engine strategy | Full Rails Engines from day one |
| Per-org Twilio credentials | Encrypted DB column (Rails 7 `encrypts`) |
| PR scope | One big PR for the full Calling extraction |

## Architecture Overview

### Three layers

```
┌─────────────────────────────────────────────────────────────┐
│  Host App (main)                                            │
│  ├─ Organization, User, Membership (tenancy)               │
│  ├─ Customer, Deal, Task (business core)                   │
│  ├─ OrganizationFeature ← NEW                              │
│  └─ Settings::FeaturesController ← NEW                     │
└──────────────────────────┬──────────────────────────────────┘
                           │ mounts at /calling
                           ▼
┌─────────────────────────────────────────────────────────────┐
│  Calling Engine (engines/calling)                          │
│  ├─ Controllers: Voice, Tokens, Recordings                 │
│  ├─ Models: Calling::Recording, Calling::DealRecording     │
│  ├─ Providers: Base → Twilio (Plivo/Vonage later)          │
│  └─ JS: Twilio Device controllers                          │
└──────────────────────────┬──────────────────────────────────┘
                           │ delegates provider-specific work
                           ▼
┌─────────────────────────────────────────────────────────────┐
│  Provider Adapter (Calling::Providers::Twilio)             │
│  Implements Calling::Providers::Base interface              │
│  Reads credentials from OrganizationFeature.settings        │
└─────────────────────────────────────────────────────────────┘
```

### Why this shape

- **Engine** gives clean code isolation, separate gemspec, separate routes namespace, easy future extraction to a separate service.
- **Provider base class** decouples controllers from Twilio specifically — adding Plivo is a new subclass, not a controller rewrite.
- **OrganizationFeature** keeps the feature-flag layer thin and in the host app, so the engine never needs to know how toggles are stored. It just asks the host for a configured provider.

## Feature Toggle Layer (host app)

### `OrganizationFeature` model

```ruby
# app/models/organization_feature.rb
class OrganizationFeature < ApplicationRecord
  belongs_to :organization
  acts_as_tenant :organization

  encrypts :settings  # Rails 7 native encryption

  validates :key, presence: true, uniqueness: { scope: :organization_id }

  KEYS = %w[calling messaging email].freeze  # extended as modules ship
  validates :key, inclusion: { in: KEYS }
end
```

Schema:
```ruby
create_table :organization_features do |t|
  t.references :organization, null: false, foreign_key: true
  t.string :key, null: false              # "calling", "messaging", etc.
  t.boolean :enabled, default: false, null: false
  t.string :provider                      # "twilio", "plivo", etc.
  t.text :settings                        # encrypted JSON: credentials + config
  t.timestamps
  t.index [:organization_id, :key], unique: true
end
```

### API on `Organization`

```ruby
class Organization < ApplicationRecord
  has_many :features, class_name: "OrganizationFeature"

  def feature_enabled?(key)
    features.find_by(key: key.to_s)&.enabled?
  end

  def calling
    @calling ||= Calling::Facade.new(self)  # provided by engine
  end
end
```

### Settings UI

- Route: `/settings/features`
- Admin-only (via Pundit policy)
- Lists all available modules with on/off toggle
- For enabled modules, shows provider dropdown + credentials form
- Credentials write to `OrganizationFeature.settings` (encrypted at rest)

## Calling Engine Structure

```
engines/calling/
├── calling.gemspec
├── Gemfile                                # twilio-ruby moves here
├── lib/
│   ├── calling.rb
│   └── calling/
│       ├── engine.rb                      # isolate_namespace Calling
│       └── version.rb
├── app/
│   ├── controllers/calling/
│   │   ├── application_controller.rb      # feature_enabled? gate
│   │   ├── voice_controller.rb            # TwiML responses
│   │   ├── tokens_controller.rb           # access token generation
│   │   └── recordings_controller.rb       # index/show
│   ├── models/calling/
│   │   ├── recording.rb                   # was app/models/recording.rb
│   │   └── deal_recording.rb
│   ├── services/calling/
│   │   ├── facade.rb                      # entry point for host app
│   │   └── providers/
│   │       ├── base.rb                    # abstract interface
│   │       └── twilio.rb                  # was app/services/twilio_service.rb
│   ├── workers/calling/
│   │   ├── recording_storage_worker.rb
│   │   └── recording_rename_worker.rb
│   ├── views/calling/                     # any calling-specific views
│   └── javascript/calling/                # Twilio Device JS controllers
└── config/
    └── routes.rb                          # mounted at /calling
```

### Engine boot

```ruby
# engines/calling/lib/calling/engine.rb
module Calling
  class Engine < ::Rails::Engine
    isolate_namespace Calling

    config.generators do |g|
      g.test_framework nil
    end
  end
end
```

### Host Gemfile entry

```ruby
gem "calling", path: "engines/calling"
```

### Host routes

```ruby
# config/routes.rb
mount Calling::Engine => "/calling"
```

## Provider Adapter Pattern

### Abstract base

```ruby
# engines/calling/app/services/calling/providers/base.rb
module Calling
  module Providers
    class Base
      attr_reader :organization, :config

      def initialize(organization, config)
        @organization = organization
        @config = config  # decrypted settings hash from OrganizationFeature
      end

      # Required interface — subclasses must implement
      def generate_access_token(user)
        raise NotImplementedError
      end

      def voice_response(params)
        raise NotImplementedError
      end

      def verify_webhook(request)
        raise NotImplementedError
      end

      def place_call(from:, to:, **opts)
        raise NotImplementedError
      end

      def fetch_recording(sid)
        raise NotImplementedError
      end
    end
  end
end
```

### Twilio implementation

```ruby
# engines/calling/app/services/calling/providers/twilio.rb
module Calling
  module Providers
    class Twilio < Base
      def generate_access_token(user)
        # existing TwilioService#generate_token logic
        # reads SID/token/app_sid from @config instead of Rails credentials
      end
      # ... rest of interface
    end
  end
end
```

### Facade (host-facing entry point)

```ruby
# engines/calling/app/services/calling/facade.rb
module Calling
  class Facade
    def initialize(organization)
      @organization = organization
    end

    def enabled?
      @organization.feature_enabled?(:calling)
    end

    def provider
      return nil unless enabled?
      @provider ||= build_provider
    end

    private

    def feature
      @feature ||= @organization.features.find_by(key: "calling")
    end

    def build_provider
      klass = PROVIDER_REGISTRY.fetch(feature.provider)
      klass.new(@organization, feature.settings)
    end

    PROVIDER_REGISTRY = {
      "twilio" => Calling::Providers::Twilio
      # "plivo" => Calling::Providers::Plivo, etc.
    }.freeze
  end
end
```

### Engine controller gate

```ruby
# engines/calling/app/controllers/calling/application_controller.rb
module Calling
  class ApplicationController < ::ApplicationController
    before_action :require_calling_enabled

    private

    def require_calling_enabled
      return if current_tenant&.feature_enabled?(:calling)
      head :forbidden
    end
  end
end
```

## What Moves vs. Stays

### Stays in host app

| File | Reason |
|---|---|
| `app/models/organization.rb` | Tenancy core; gains `feature_enabled?` + `calling` facade accessor |
| `app/models/user.rb`, `membership.rb` | Tenancy core |
| `app/models/customer.rb`, `deal.rb`, `task.rb` | Business core |
| `app/controllers/concerns/sets_current_tenant.rb` | Tenancy infra |
| `app/models/organization_feature.rb` | **NEW** — feature toggle storage |
| `app/controllers/settings/features_controller.rb` | **NEW** — toggle UI |
| `app/views/settings/features/*` | **NEW** — toggle UI |
| `app/policies/organization_feature_policy.rb` | **NEW** — admin-only |

### Moves to `Calling` engine

| Current path | New path |
|---|---|
| `app/controllers/calling_controller.rb` | Split: `engines/calling/app/controllers/calling/{voice,tokens,recordings}_controller.rb` |
| `app/services/twilio_service.rb` | `engines/calling/app/services/calling/providers/twilio.rb` |
| `app/models/recording.rb` | `engines/calling/app/models/calling/recording.rb` (table name stays `recordings`) |
| `app/models/deal_recording.rb` | `engines/calling/app/models/calling/deal_recording.rb` |
| `app/workers/recording_storage_worker.rb` | `engines/calling/app/workers/calling/recording_storage_worker.rb` |
| `app/workers/recording_rename_worker.rb` | `engines/calling/app/workers/calling/recording_rename_worker.rb` |
| `app/services/recording_storage_service.rb` | `engines/calling/app/services/calling/recording_storage_service.rb` |
| `app/services/deep_seek_recording_service.rb` | `engines/calling/app/services/calling/deep_seek_recording_service.rb` |
| `app/javascript/controllers/*calling*` | `engines/calling/app/javascript/calling/` |
| `config/routes.rb` calling routes | `engines/calling/config/routes.rb` |
| `gem "twilio-ruby"` in main Gemfile | `engines/calling/calling.gemspec` |

### Stays put (out of scope for this PR)

- WhatsApp/Twilio messaging code (`twilio_whatsapp_*`) — becomes `Messaging` engine later
- Gmail/Email integration — becomes `Email` engine later
- LinkedIn integration — TBD module

## Migration Order (within the single PR)

1. **Add `OrganizationFeature` model + migration**
   - Schema + model + Rails 7 `encrypts` setup
   - `Organization#feature_enabled?` method
   - Seed: existing orgs get `calling` enabled with shared Twilio creds (migration backfill)

2. **Build Settings UI**
   - `Settings::FeaturesController` (index/update)
   - Admin-only policy
   - View with toggles + provider dropdown + credentials form

3. **Scaffold `engines/calling`**
   - Empty mountable engine
   - Wire into host Gemfile + routes (mount at `/calling`)
   - Smoke-test with a hello route

4. **Define provider interface**
   - `Calling::Providers::Base`
   - `Calling::Facade` with provider registry

5. **Port `TwilioService` → `Calling::Providers::Twilio`**
   - Move logic, switch credential source from Rails credentials to `@config`
   - Keep the old `TwilioService` as a thin shim during transition, then delete

6. **Move calling controllers + JS into engine**
   - Update `calling_controller.rb` → split into `Calling::VoiceController`, etc.
   - Update routes (now in engine)
   - Update JS imports

7. **Move `Recording` + workers + recording services into engine**
   - Class rename: `Recording` → `Calling::Recording` (table stays `recordings`)
   - Update all references in `Deal`, `DealRecording`, views, controllers
   - Workers move with their class names namespaced

8. **Switch credential source to per-org**
   - All provider calls now read from `OrganizationFeature.settings`
   - Remove Twilio credentials from Rails credentials (after backfill validates)

9. **Verification**
   - All existing calling flows work end-to-end with one test org
   - Disable calling for a test org → routes return 403, UI hides calling buttons
   - New provider stub (Plivo `NotImplementedError`) proves the registry works

## Risks & Mitigations

| Risk | Mitigation |
|---|---|
| **Class rename `Recording` → `Calling::Recording` breaks polymorphic refs** | Audit all `recordable_type` strings; backfill with a data migration. Keep `self.table_name = "recordings"` to avoid table rename. |
| **Encrypted credentials lost on rotation** | Pin `config.active_record.encryption.primary_key` in credentials; document key rotation process. |
| **acts_as_tenant scoping across engine boundary** | Engine controllers inherit from host `ApplicationController`, which already sets the tenant. Verify in step 3 smoke test. |
| **JS bundling for engine assets** | Use Propshaft / importmap to expose engine JS to host. May require explicit `Rails.application.config.assets.paths` additions. |
| **One-big-PR makes review hard** | Mitigate by keeping each step a separate commit within the PR; reviewer can walk commit-by-commit. |
| **Existing Twilio credentials shared across orgs today** | Backfill migration: copy Rails credentials → every org's `calling` feature. Zero downtime. Remove Rails credentials only after every org has its own. |

## Open Questions (for future modules, not blocking)

- Does `DeepSeekRecordingService` belong in the Calling engine or a separate `AI` engine? **Current decision:** stays with Calling for now, extract later only if a second module needs DeepSeek.
- Will `Customer` itself eventually move into a `Contacts` engine? **Current decision:** no — Customer is business core, not a swappable module.
- Sidekiq queues per engine? **Current decision:** keep existing queue names; engines push to host's Sidekiq.

## Definition of Done

- [ ] `OrganizationFeature` model + migration + seed
- [ ] Settings UI lets an admin toggle Calling on/off and configure Twilio creds
- [ ] `engines/calling` is a working mountable engine in the host Gemfile
- [ ] `Calling::Providers::Base` + `Calling::Providers::Twilio` implemented
- [ ] All calling controllers, models, workers, services, JS moved into engine
- [ ] All Twilio calls read credentials from per-org `OrganizationFeature.settings`
- [ ] Disabling `calling` for an org returns 403 on engine routes and hides UI
- [ ] Adding a new provider requires only: new subclass + registry entry (no controller changes)
- [ ] Existing call/recording flows pass manual smoke test for one test org
- [ ] Rails credentials Twilio entries removed
