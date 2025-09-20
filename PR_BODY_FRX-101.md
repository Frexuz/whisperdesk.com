# FRX-101: [A2] Subdomain routing and tenant middleware

## Summary
Implements foundational multi-tenancy: subdomain routing constraint, tenant resolution middleware, Current attributes, access guards, and isolation specs. Establishes reliable 404 for unknown subdomains and 403 for cross-tenant record access.

## Implementation Details
- Tenant model with normalized subdomain and reserved list validation (www, admin, api, billing).
- Middleware `SetCurrentTenant` sets `Current.tenant` per request and guarantees cleanup.
- Routing constraint `SubdomainRequiredConstraint` limits tenant routes to non-reserved subdomains.
- Controller concern `RequiresTenant` plus `assert_tenant!` helper for explicit record scoping.
- Error handling: rescues `Tenant::NotFound` and `Tenant::AccessDenied` returning 404 / 403 with JSON negotiation.
- Added sample `SampleItem` resource for cross-tenant isolation testing.
- Updated `ApplicationController` to hook tenancy errors and dynamic inclusion of `RequiresTenant` inside Tenanted namespace.
- Test environment host allowances for `*.lvh.me` to simulate subdomains locally.

## Changed Areas
- Backend: models (`Tenant`, `SampleItem`), middleware, routes, controller concern, application controller.
- Tests: new model and request specs.
- Migrations: `create_tenants`, `create_sample_items`.
- Docs: `AGENTS.md` strengthened PR creation steps; added `CHANGELOG_FRX-101.md` and this PR body file.

## Verification Steps
1. Run migrations: `bundle exec rails db:migrate`.
2. Specs: `bundle exec rspec spec/models/tenant_spec.rb spec/requests/tenant_routing_spec.rb spec/requests/sample_items_spec.rb` → all green locally.
3. Manual check (dev):
   - Create tenant in console: `Tenant.create!(subdomain: "acme")`.
   - Visit `http://acme.lvh.me:3000/tenant_health` → 200.
   - Visit `http://unknown.lvh.me:3000/tenant_health` → 404.
   - Create second tenant and `SampleItem` under it; access from first subdomain → 403.

## Screenshots
(No UI changes requiring visual evidence at this layer.)

## Changelog
See `CHANGELOG_FRX-101.md` for concise entry.

## Linear Issue
FRX-101 https://linear.app/frexity/issue/FRX-101/a2-subdomain-routing-and-tenant-middleware

## Follow Ups
- A3 branding fields.
- Structured logging (K1) to include tenant id.
- Shared tenant isolation RSpec examples for future resources.

## Checklist
- [x] Tests passing
- [x] Migrations added
- [x] Changelog entry present
- [x] PR body includes summary and verification
