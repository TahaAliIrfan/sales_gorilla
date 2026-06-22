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
- [x] Task 4: complete (commit 3060be5, 1 example 0 failures, schema clean)
- [x] Task 5: complete (commit bcd7150, 2 examples 0 failures)
- [x] Task 6: complete (commit 26ed91b, 3 examples 0 failures; live selector capture deferred — needs portal creds)
- [x] Task 7: complete (commit 4a5c23f, 1 example 0 failures)
- [x] Task 8: complete (commit 93a0628, 3 examples 0 failures; impl used find_or_create_by! idempotency; fixed plan test-3 double-stub bug)
- [x] Task 9: complete (commit 8cce8c3, 2 examples 0 failures)
- [x] Task 10: complete (commit 8d2a429, 2 examples 0 failures)
- [x] Task 11: complete (commit 95effdb, 5 examples 0 failures). FLAG for final review: subagent also made a minimal safe fix to Customer#record_activity_changes (skip activity log when no user exists; no prod behavior change) — needed for background customer updates.
- [x] Task 12: complete (commit 14e4253, 2 examples 0 failures)
- [x] Task 13: complete (commit 7b39ccb, 1 example 0 failures; backend connect/disconnect — view-card wiring into Relay features page is a follow-up)

## Environment notes (IMPORTANT for remaining tasks)
- Schema-driven repo: 7 tables (sms, google_meets, etc.) have NO migration files.
- Dev + test DBs now rebuilt complete (50 tables). `db:migrate` dumps cleanly now.
- ALWAYS verify after a migration task: `git show HEAD:db/schema.rb | grep -c create_table` must NOT drop below the prior count. If it does, restore from prior schema + re-run only the new migration against a schema:load'd DB.
