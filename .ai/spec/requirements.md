<!--
	Consolidated & merged specification generated from original requirements + answered clarification questions.
	File is authoritative for current MVP scope. Future / deferred items are explicitly marked.
-->

# WhisperDesk Multi‑Tenant Help Desk – Consolidated Requirements Specification

## 0. Document Status
Version: 0.1 (living spec during early development)
Scope: MVP (Phase 1) + clearly marked Near-Term (Phase 2) + Deferred

## 1. Introduction & Vision
WhisperDesk is a multi-tenant, email‑centric help desk. Tenants ("accounts") access the application at `https://{subdomain}.whisperdesk.com`. Core MVP pillars:
1. Multi‑tenant isolation (data + billing) with subdomain branding (logo, from-name)
2. Email ingestion via forwarding, ticket threads, VERP reply handling
3. Manual ticket lifecycle (states, priorities, tagging)
4. Per‑tenant templates (Liquid) & Action Text (Lexxy) rich editor
5. Full‑text search (Meilisearch) with tenant scoping + facets
6. Real‑time collaboration (viewing / replying presence, updates)
7. Stripe billing (pay gem) per active agent seat w/ trials & proration
8. Webhook engine (Stripe‑style) + initial Slack & Zapier integration (Zapier via their own account)
9. Solid Queue + Solid Cache for background work & performance

Non‑goals MVP: analytics/reports, automations beyond webhooks, CSAT, mobile app, complex SLA engines, multi-region residency, advanced spam filtering.

## 2. High‑Level Architecture Overview
Rails 8.1 (Ruby) monolith. Gems / components: activerecord-multi-tenant (new Rails multi-tenant support), Devise (+ SAML & Google OAuth2), Pundit, Pay (Stripe), Solid Queue, Solid Cache, Action Mailbox, Action Text (Lexxy), Turbo + Stimulus, Pagy, Meilisearch, Liquid, logidze (ticket history), Sentry, Skylight. TailwindCSS for styling; dark mode fully supported. Multi-tenancy enforced at model & query layer; all cache keys prefixed by tenant id.

## 3. Multi‑Tenancy & Account Model
User Story: As an owner I want an isolated branded subdomain.
Acceptance:
1. On signup: wizard captures subdomain + company (single step if feasible; else 2 steps).
2. Subdomain uniqueness validated (lowercased, DNS-safe).
3. Tenant isolation: all queries scoped to current subdomain (middleware / constraint + multi-tenant gem).
4. System generates a short UUID-based root inbound email address per account (used for forwarding if needed before inbox creation) – MAY BE HIDDEN once first inbox created.
5. Unauthorized cross-tenant access returns 403 (never 404 for existing internal ids) and is logged (security/audit backlog).
6. Branding fields: logo (image upload), from_name (string). Fallbacks: app default.
7. Deletion: hard delete (no retention) – irreversible.

## 4. Roles & Team Management / Seats
Roles: admin, agent. (Owner is an admin.) No custom roles.
Seat definition: enabled agent accounts (admins may toggle their own agent status if ≥1 other enabled agent exists to keep coverage).
Invitations:
1. Admin can invite via email (default role: agent; adjustable to admin before sending or after acceptance).
2. Invitation token expires in 7 days; unlimited resends generate same (or rotated) token (implementation choice; log resends).
3. Accepting invitation creates user in tenant and signs them in (Devise flow) with mandatory password & (optional) MFA depending on tenant policy.
4. Per-inbox access management: admins assign which inboxes an agent can access (agents see only assigned inboxes in filters / lists; may still exist global ticket search limited to allowed inboxes).
5. Admin toggling agent_status=false removes from billable seat count immediately (stripe proration event via Pay).
6. UI: Team / Seats page lists active agents, role, agent status, invited at (pending invites), inbox access matrix.
7. Admin may leave tenant only if ≥1 other admin remains.

## 5. Onboarding Flow Tracking
Steps (tracked with completion checklist):
1. Subdomain + company (Account creation)
2. First inbox creation
3. Forwarding instructions shown (email routing) – includes DMARC/SPF/DKIM reminder (DKIM optional) & Cloudflare "Configure automatically" button (Phase 2)
4. Invite teammates
5. Billing (start 14‑day trial automatically at signup; upgrade/payment later or earlier manually)
Progress: stored per tenant (simple JSON column or model). Display unobtrusive progress widget.

## 6. Email & Inbox Infrastructure
Model: Inbox (name, generated inbound address, optional custom from_name override, smtp_settings? (Phase 2)), membership join table for user access.
Inbound:
1. Each inbox gets unique system email (pattern: `{random}@{inbound-domain}`) – stable.
2. Email ingestion via forwarding only (no IMAP/Graph). Action Mailbox accepts forwarded mail.
3. Threading: VERP reply-to per conversation + In-Reply-To / References headers. Subject fallback minimal (“Re:” trimming) only if headers absent.
4. Attachments: up to 25MB (reject > limit with bounce message). Stored via Active Storage (default encryption at rest) – virus scan (Phase 2 / TBD provider) – mark accepted/unscanned state.
5. Spam filtering: Not performed application-side initially; assumed filtered at upstream mail forwarding provider. Flag for later integration (Deferred).
6. Full raw source + headers stored; raw source visible only to SaaS owner (MotorAdmin) – not tenant admins.
7. Outbound: Platform SMTP by default. Optional per-tenant SMTP + DKIM signing (Phase 2). Envelope sender supports VERP bounce classification.
8. Auto-acknowledgement: Sent only for the first email in a new ticket thread; configurable template (enable/disable + body) in tenant settings.
9. Bounce handling: (Phase 2) Track bounced deliveries and display status to agents on message attempts list.

## 7. Ticket Model & Lifecycle
States: Open, Pending, On-hold, Resolved, Closed. Closed tickets can be reopened (returns to Open). Status change optionally notifies requester (email template per action – Phase 2 for customization; default generic for MVP).
Priorities: Low, Medium, High, Urgent.
Assignment: Manual only (optional; may remain unassigned).
Data:
* Ticket (subject, state, priority, inbox_id, requester_recipient_id, assignee_user_id nullable, last_activity_at, tenant_id)
* Message (public reply or internal note flag, body (Action Text), sender (agent or recipient), attachments, conversation-specific reply-to token)
* Internal notes visible only to agents/admins (never emailed). Public replies emailed & broadcast.
Presence & Collision:
1. Viewing a ticket broadcasts presence (list of active agent names).
2. Typing indicator for reply box (optional Phase 2; MVP at least viewing presence).

## 8. Tagging
Free‑form, tenant-wide. Case-insensitive uniqueness.
Acceptance:
1. Add/remove tags inline on ticket sidebar (autocomplete existing tags).
2. No colors/descriptions/merge tools (Deferred).
3. Tags searchable & filterable.
Model: Tag(name, tenant_id); TicketTag join.

## 9. Search (Meilisearch)
Scope: tickets + messages (content, subject, tags, requester email, priority, state, inbox). Tenant isolation enforced at index level (one index per tenant or tenant_id field + filter). Facets: inbox, state, tags, priority, date range, recipient domain.
Acceptance:
1. Query returns relevance-ranked results with highlighted snippets (message excerpts).
2. Index updates asynchronously on create/update (background job) – fallback full reindex rake task `rake meilisearch:reindex`.
3. Only content from authorized tenant & (if agent) inboxes user can access.
4. Performance: < 1s typical response for standard queries (non-binding target).

## 10. Templates & Signatures
Per-tenant templates (Liquid). Variables: `recipient.first_name`, `last_message` (plain text excerpt), `agent.signature`.
Signatures: per-agent (rich text or plain). Inserted when composing replies (agent can toggle include).
No folders/snippets/versioning in MVP.

## 11. Authentication, Authorization & Security
Auth: Devise (email/password), Google OAuth2, SAML (tenant-configurable; Phase 2—MVP implements Google + email/password; SAML optional if time allows). MFA: optional per-tenant policy (Phase 2 toggle adds TOTP).
Authorization: Pundit policies – enforce tenant + role + inbox membership.
Admin interface: MotorAdmin exposed to SaaS operator only (protected via HTTP Basic Auth) – shows raw emails, tenants, billing records.
Log history: logidze on tickets (state, priority, tags changes). No full audit log yet (Deferred).

## 12. Background Jobs & Reliability
Worker: Solid Queue (Postgres). Retry: default strategy; capture failures in Sentry.
Critical jobs: email ingestion, outbound send, search indexing, webhook delivery, billing seat sync.
Idempotency: Email ingestion + webhook deliveries use idempotency keys (e.g., message-id or delivery attempt UUID).
Monitoring: Sentry (errors), Skylight (performance); minimal admin status page (Phase 2).

## 13. Real‑Time Updates
Transport: Turbo + ActionCable (SolidCable). Events:
1. Ticket list updates (new ticket, state change, priority change, assignment change).
2. New public replies while viewing ticket.
3. Presence: agents viewing ticket (and Phase 2: typing indicator).
Caching: Solid Cache for frequent list queries (key prefix: `tenant:{id}:tickets:index:{filters_hash}`). Invalidate on ticket mutation.

## 14. Payments & Billing (Stripe via Pay gem)
Model: Subscription per tenant (Stripe customer + subscription). Pricing: per active agent seat / month. Trial: 14 days (no card required). Proration: rely on Stripe defaults (seats adjust immediately). Billing anchor: first successful payment date (Stripe default acceptable).
Seat counting: On agent status toggle or role change to/from billable agent, update subscription quantity (webhook fallback reconciliation nightly job Phase 2).
Suspension: After 3 failed payments (Stripe dunning), mark tenant suspended (read-only except billing) until resolved.
Active subscription check: helper verifying subscription status & not suspended.
Events handled: via Pay gem defaults (payment succeeded/failed, subscription updated, customer updated). Provide internal mapping -> tenant billing flags.

## 15. Caching & Performance
Guidelines:
1. Cache keys include tenant id.
2. Paginate ticket lists with Pagy.
3. Add DB indexes: foreign keys, tickets(state, priority, inbox_id), tickets(last_activity_at), messages(ticket_id, created_at), ticket_tags(tag_id, ticket_id), tags(tenant_id, name unique composite).
4. Avoid N+1 on ticket list (eager load inbox, assignee, tags).
CDN: Static assets through BunnyCDN (Rails asset host config). Email inline images optional (Phase 2).

## 16. Webhooks & Integrations
Webhook Engine MVP:
* Tenant defines endpoints (url, secret, active flag, description).
* Events (MVP set): ticket.created, ticket.updated (state/priority/assignee/tag change consolidated), message.created (public), subscription.updated (billing status changes).
* Delivery: background job with exponential backoff (default attempts e.g. 6). HMAC signature header using tenant secret.
* Replay: (Phase 2) manual re-delivery from UI.
Slack (Phase 2 initial): outbound webhook to Slack channel (simple message) using existing webhook mechanism (wrapping Slack formatting). Zapier: tenants configure Zapier webhook endpoint manually (no OAuth app initially).

## 17. Imports & Data Migration
Supported: Zendesk, Freshdesk, Help Scout exports (Phase 2). MVP may scaffold model & UI placeholders (upload + basic field mapping not executed yet if time constraints). Field mapping UI: map external fields to ticket subject, body, requester email, state, priority, created_at.
Validation: show errors per row; successful rows proceed; failed rows skipped (report downloadable CSV). No bulk post-import tag or state actions (out of scope).

## 18. UI / UX Overview
Primary nav: Inboxes, Tickets, Templates, Customers, Settings, Billing, My Profile.
Dark mode: Tailwind `dark:` classes.
Ticket List columns: status, priority, inbox, assignee, last updated (sortable by last updated). Bulk actions: (Phase 2) none in MVP except maybe reopen/close multiple (defer if complexity high).
Ticket Detail: thread (messages + internal notes), sidebar (requester, tags edit, priority edit, activity log – sourced from logidze deltas simplified). Composer: bottom of thread using Action Text (rich). Internal note toggle.
Global Search: header search box opens overlay with filters (facets). Results show snippet + highlights.
Team Page: list + invitation form + inbox access matrix + agent status toggle + role selector.
Templates Page: list, create, edit, preview (render sample variables). Variables cheat-sheet panel.
Settings: branding (logo, from name), email (auto-reply template + enable flag, DKIM instructions placeholder), security (MFA policy toggle – hidden until implemented), webhooks management. Billing: show plan, seat count, trial days left, link to Stripe billing portal.

## 19. Non‑Functional Requirements
Availability: Best effort (no formal SLA). Performance responsive < 300ms server render for standard ticket list (target). Security: tenant isolation mandatory; no cross-tenant IDOR. Data deletion immediate on tenant delete.
Internationalization: English only (i18n framework ready). Time zones: tenant default; per user override for display (ticket timestamps localized client-side or via Rails).
Accessibility: Basic semantic HTML; deep WCAG compliance deferred.

## 20. Roadmap Priorities (Phased)
Phase 1 (MVP): Multi-tenancy, inboxes & email ingestion, ticket states & priorities, tagging, templates, search, real-time updates (list + presence), Stripe billing (seats + trial), basic webhooks, dark mode.
Phase 2 (Near-Term): SAML, MFA policy, DKIM + per-tenant SMTP, typing indicators, Slack + Zapier usage, bounce handling UI, importers, webhook replay UI, presence typing, attachment virus scanning, Cloudflare auto DNS config button, basic ticket bulk actions.
Deferred: Advanced analytics, SLA engine, automation rules beyond webhooks, CSAT surveys, mobile optimization, spam filtering engine, org-level customer grouping, advanced audit logging, full reports, multi-region, watchers, macros, snippets, per-inbox signatures, tag management enhancements.

## 21. Open Questions / Assumptions
1. Bounce handling specifics (provider integration) – TBD.
2. Virus scanning engine provider (ClamAV vs external SaaS) – TBD.
3. SAML IdP metadata per tenant storage format – Decide pre Phase 2.
4. Import export formats (exact CSV columns per source) – gather sample exports.

## 22. Development Practices & Conventions
* Modify existing migration files (allowed until first production release); always reset DB & re-migrate after migration edits.
* TDD-first: write RSpec tests (with FactoryBot, Faker) before implementation for each feature.
* Stimulus controllers for interactive components (presence indicators, tag input autocomplete, search overlay).
* TailwindCSS utility-first; extract components only when reused ≥3 times.
* Background job tests: verify enqueue + idempotency.
* Security tests: ensure tenant scoping (Pundit + model scope tests).
* Linting / quality: (Add Rubocop config if not present – future). Performance: add query count expectations for hot paths.

## 23. Acceptance Criteria Summary (Condensed)
Below is a condensed mapping – details reside in sections above.
* Tenant isolation: enforced at every persistence + query path.
* Signup wizard: subdomain + company; onboarding checklist persists progress.
* Inboxes: unique address generation; per-inbox access control.
* Email ingestion: create ticket (or append message) w/ VERP + headers.
* Auto-reply: first message only configurable enable/disable + body.
* Tickets: states, priorities, internal notes, reopening closed tickets.
* Tags: add/remove, autocomplete, unique per tenant.
* Search: Meilisearch facets + highlights, tenant/inbox scoping.
* Templates: Liquid variables; per-agent signatures.
* Auth: Devise + Google; Pundit; (SAML / MFA Phase 2).
* Real-time: ticket list updates + presence.
* Billing: Stripe per active agent; trial; proration; suspension after failures.
* Webhooks: core events w/ signed HMAC, retries.
* Caching: tenant-prefixed keys; Pagy lists.
* Logging: ticket change history via logidze.
* Imports: placeholder Phase 2.
