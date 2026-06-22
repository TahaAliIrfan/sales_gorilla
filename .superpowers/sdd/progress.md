# Odoo Partner Portal Connector — SDD Progress

Branch: feat/odoo-portal-connector
Base commit (docs): 6d4d4cf
Env: ruby 3.3.0 via `export PATH="$HOME/.rbenv/shims:$PATH"`
Note: spec/models/membership_spec.rb has 2 PRE-EXISTING failures on revamp (not ours).

## Tasks
- [x] Task 0: branch + node agent scaffold (commit a node-agent)
- [x] Task 1: complete (commit d8559ad, review clean: 2 examples 0 failures)
- [x] Task 2: complete (commit 73e60e0, review clean: 3 examples 0 failures; FIXED schema.rb regression that dropped 7 tables + rebuilt dev/test DBs from full schema)
- [x] Task 3: complete (commit ef87d2a, 2 examples 0 failures, schema clean)
- [ ] Task 4: Customer portal columns
- [ ] Task 5: LeadParser
- [ ] Task 6: BrowserRunner + selectors
- [ ] Task 7: Scraper
- [ ] Task 8: OdooPortalSyncWorker
- [ ] Task 9: EmailTrigger
- [ ] Task 10: scheduled poll + manual sync
- [ ] Task 11: write-back event map + callback
- [ ] Task 12: Writer + push worker
- [ ] Task 13: settings UI

## Environment notes (IMPORTANT for remaining tasks)
- Schema-driven repo: 7 tables (sms, google_meets, etc.) have NO migration files.
- Dev + test DBs now rebuilt complete (50 tables). `db:migrate` dumps cleanly now.
- ALWAYS verify after a migration task: `git show HEAD:db/schema.rb | grep -c create_table` must NOT drop below the prior count. If it does, restore from prior schema + re-run only the new migration against a schema:load'd DB.
