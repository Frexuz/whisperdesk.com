# FRX-100 Core Environment & Gems

## Summary
Initial application bootstrapped with core platform foundations: authentication, authorization, billing scaffolding, health instrumentation, and test framework standardization.

## Added
- Devise authentication with confirmable.
- Pundit authorization base policy and integration.
- Pay gem setup with basic subscription/customer tables (SQLite json compatibility).
- Solid stack already present (solid_cache, solid_queue, solid_cable) leveraged.
- Health endpoint `/health` returning JSON status + timestamp.
- RSpec testing framework (rspec-rails) configured.

## Changed
- Root route points temporarily to health for smoke validation.
- `AGENTS.md` updated to explicitly mandate RSpec and forbid Minitest usage.

## Removed
- Legacy Minitest `test/` directory and all prior test files.

## Tests
- Request spec for health endpoint.
- User model spec (basic validity).
- Application policy scope spec.

## Follow-ups / Next Epics
- Subdomain tenancy (A2).
- Tenant model & branding (A3).
- Signup + onboarding (A4/A5) including Stripe customer bootstrap.

## Migration Notes
- Uses `json` instead of `jsonb` columns for Pay tables due to SQLite in dev/test.
- Future switch to Postgres can migrate columns to `jsonb`.

## Verification
- `bundle exec rspec` passes (3 examples, 0 failures).
- `bin/rails db:migrate` succeeded creating users + pay tables.
