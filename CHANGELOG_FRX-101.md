# FRX-101 Subdomain Routing & Tenant Middleware

## Summary
Introduced multi-tenant subdomain routing foundation: tenant extraction via subdomain constraint, thread-local Current.tenant, access control guards, and error handling (404 unknown tenant, 403 cross-tenant access). Provides groundwork for subsequent tenancy-dependent features.

## Added
- `Tenant` model (subdomain, name) with normalization & reserved list validation.
- Routing constraint `SubdomainRequiredConstraint` wrapping tenant-scoped routes.
- `Current` attributes (`tenant`, `user`, `request_id`).
- Middleware `SetCurrentTenant` resolving tenant and ensuring thread-local cleanup.
- Controller concern `RequiresTenant` + `assert_tenant!` helper.
- Error handling: custom 403 page; JSON negotiation for 404/403.
- Sample resource (`SampleItem`) and controller for cross-tenant access tests.
- RSpec specs: tenant model validations, routing behaviors, JSON negotiation, cross-tenant 403, thread-local reset hygiene.

## Changed
- `ApplicationController` updated to rescue tenant errors and include tenant requirement for Tenanted namespace.
- `routes.rb` updated to wrap tenant routes in constraint scope.
- Test environment allows `lvh.me` subdomains.

## Tests
- All new specs passing (`tenant_spec`, `tenant_routing_spec`, `sample_items_spec`).

## Follow-ups / Next Epics
- A3: Extend Tenant model with branding + forwarding root address.
- M1: Reuse shared isolation tests for additional resources.
- K1: Integrate structured logging (will add tenant_id tag using Current.tenant).

## Verification
- Manual curl against `acme.lvh.me:3000/tenant_health` returns 200 after creating tenant.
- Unknown subdomain returns 404 with `{error:"Not Found"}` for JSON Accept header.
- Cross-tenant record access returns 403 without leaking existence.
