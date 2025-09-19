# Implementation Plan (Expanded Detailed Breakdown v0.3)

> Highly granular, implementation-focused plan. Includes: user flows, per-screen tasks, backend services, validation rules, test coverage checklist, and explicit acceptance criteria. Designed to eliminate ambiguity during development.

Legend:
✅ = Done  🔄 = In Progress  ⏳ = Planned  💤 = Deferred (after MVP)  🧪 = Test-only / instrumentation  ⚠️ = Needs decision

## Global Conventions
* Every user-visible flow gets: Controller, Policy, View (HTML + Stimulus), System Spec, Happy + 1 Failure case.
* Tenant isolation asserted in each controller spec with cross-tenant attempts.
* Background jobs: enqueue spec + idempotency spec.
* Naming: Use `tenant_id` consistently
* Flash message taxonomy: `notice`, `alert`, `error` (avoid custom keys).
* Accessibility: None

---
## Epic A: Foundations & Tenancy
### A1 Core Environment & Gems ⏳
Artifacts: Gemfile, initializers (devise, pundit, pay, solid_queue, solid_cache, meilisearch.rb). Exit: `rails s` boots, health page returns 200.
Tests: smoke request spec.

### A2 Subdomain Routing & Current Tenant ⏳
Tasks:
1. Routing constraint `SubdomainRequired` (exclude `www`, root marketing domain).
2. Middleware `SetCurrentTenant` (clears thread-local in ensure block).
3. 404 page for unknown tenant; 403 for cross-tenant resource attempts.
4. Controller concern `RequiresTenant` raising if `Current.tenant.nil?`.
Tests: request spec: valid / invalid subdomain; leakage attempt.

### A3 Tenant Model & Branding ⏳
Fields: `subdomain (uniq)`, `name`, `logo (ActiveStorage)`, `from_name`, `root_forward_address` (short uuid + inbound domain suffix), `onboarding_steps (jsonb)`.
Validations: subdomain regex `^[a-z0-9-]{3,30}$`, reserved words list (app config).
Test: rejects uppercase; generates root_forward_address.
UI: See UI-1 Logo Uploader spec.

### A4 Signup Flow & Email Confirmation (⏳ EXPANDED)
Flow (Wizard Screen 0 + 1):
1. Entry point: `/signup` (marketing/root domain only) – collects: email, password, subdomain, company name.
2. After submission create Tenant + User (admin, agent enabled) in transaction.
3. Send Devise confirmation email (enable confirmable) – ⚠️ decision: require email confirmation before entering tenant? (Assume: allow limited access until confirmed but block sending outbound replies.)
4. Post-create redirect to onboarding step 1 inside subdomain `https://{subdomain}.app/setup`.
5. Failure cases: duplicate subdomain (inline error), weak password (Devise default), invalid email.
Forms & UI:
* Single-screen (no multi-step modal) to reduce friction.
* Real-time subdomain availability check (Stimulus + debounced fetch `/subdomains/check?name=` returns JSON `{available: true/false}`).
Acceptance Criteria:
Artifacts: Gemfile, initializers (devise, pundit, pay, solid_queue, solid_cache, meilisearch.rb). Add AWS gems for ingress: `aws-sdk-rails`, `aws-actionmailbox-ses`. Exit: `rails s` boots, health page returns 200.
* Confirmation required path: Unconfirmed user sees banner “Confirm email to enable outbound replies.”
Tests:
* System: Happy signup.
* System: Duplicate subdomain error.
* Mailer spec: confirmation delivered.
1a. Exempt ActionMailbox ingress paths (`/rails/action_mailbox/**`) so SES/SNS can POST to root domain regardless of tenant.

### A5 Onboarding Checklist Persistence (⏳)
Checklist Steps (stored array or bitmask): `[inbox_created, forwarding_viewed, teammates_invited, billing_reviewed]`.
Tests: request spec: valid / invalid subdomain; leakage attempt. SES ingress endpoint reachable without subdomain while app routes remain tenant-scoped.
UI: Sidebar widget showing % complete.
Tests: toggling step persists; unauthorized user cannot update other tenant.

### A6 Seat Logic & Agent Toggle ⏳
Adds `is_agent:boolean` (default true) + guard: cannot disable last remaining agent.
Stripe seat sync job enqueued on toggle.
Notes: Inbound domain suffix must be a verified SES receiving domain with MX → SES (e.g., `{uuid}@inbound.whisperdesk.com`).
Test: attempt to disable last agent -> error message.

### A7 Email Confirmation Enforcement (⏳)
Before filter on composing/sending endpoints: redirect if `!current_user.confirmed?`.
Banner partial `_unconfirmed_banner` reused.
Ops: Ensure SES receipt rules (catch-all or explicit) accept messages for generated inbound addresses.
Spec: unconfirmed cannot send reply; confirmed can.

---
## Epic B: Schema & Domain Core
### B1 Migrations ⏳
All tables with `tenant_id` FKs, timestamps, proper indexes.
Check: `bin/rails db:reset` works.

### B2 Index Review (⏳)
Add composite: `tickets(tenant_id, inbox_id, state, last_activity_at DESC)`; `messages(ticket_id, created_at)`; uniqueness indexes.
Test: Rails migration spec verifying presence (custom matcher).

### B3 TenantScoped Concern ⏳
Implements `.for_tenant(tenant)` scope; forbids use inside migrations seeds w/out explicit tenant.
Test: Model leak attempt returns empty.

### B4 Ticket State Machine ⏳
Service `TicketStateTransition` raising on invalid transition (table-driven hash).
Test: every allowed path; disallowed raises.

### B5 Tagging Domain ⏳
Case-insensitive uniqueness enforced with lower index.

### B6 Ticket Version History ⏳
Logidze installed; version view renders diff (priority / status / tags).
Note: If SES stores raw emails in S3, persist bucket/key pointer and restrict fetch to platform admins only.
Test: state change increments version; diff includes old/new state.

### B7 Recipient Normalization (⏳)
Note: SNS may retry deliveries; de-duplicate using `Message-ID` and/or SES `messageId` to ensure idempotent ingestion.
Normalize email to lowercase; store name (if present) parsed from header.
Test: Duplicate differing case returns same record.
Define custom exceptions: `UnsupportedAttachment`, `ThreadingAmbiguity`, `SNSVerificationFailed`, `S3ObjectMissing`.
---
## Epic C: Inboxes & Email Ingestion
### C1 Inbox CRUD ⏳
Tampered payload test. Also cover SES/SNS: invalid SNS signature and unknown topic ARN are rejected.
Validation: name required, uniqueness (tenant scope) of inbound_address.

### C2 Inbox Membership UI ⏳
Table assignment checkboxes; updates join records via Turbo Stream patch.
Test: agent sees only assigned inboxes in list filter.
Email Ingest (SES) | New ticket or appended message; ack sent once | Unknown inbox → logged; unknown SNS topic ignored; SNS signature invalid rejected | request, service, job |
### C3 Action Mailbox Routing ⏳
Configure ingress (e.g., `relay`). Inbound mail fixture test.

### C4 Email Parsing Service ⏳
Extract plain text + HTML body; choose HTML sanitized fallback; attachments enumerated.
* System flows: signup→inbox→ingest→reply→search→webhook.
* ActionMailbox SES request specs using aws-actionmailbox-ses RSpec helpers (subscription + email).

### C5 Threading Strategy ⏳
Precedence order: VERP token > In-Reply-To reference > Subject heuristic.
Test: create message attaches to correct ticket each path.

### C6 Auto Acknowledgement ⏳
Only first inbound message per ticket triggers auto-reply (config toggle).

### C7 Attachment Size Guard (⏳)
When attachment byte size > 25MB: skip save, append note to message body “Attachment removed (exceeds 25MB)”.
Test: large file fixture; ensures not stored.
* SES receiving domain verified; receipt rules deployed; SNS topic ARN configured; end-to-end inbound smoke test green.

### C8 Raw Source Access Control (⏳)
Admin-only (platform) view at `/admin/raw_emails/:id`.
Test: tenant admin gets 403.

### C9 Bounce Handling Stub (🛌 Deferred)
Record model `MessageDeliveryAttempt` placeholder.

### C10 Idempotency ⏳
Message-ID unique index; duplicate inbound logs and returns early.

---
## Epic D: Ticket Experience & Collaboration
### D1 Ticket List ⏳
Filters: state multi-select, inbox multi-select, tags (autocomplete), priority, date range (from/to), search bar forward to global overlay.
Pagination: Pagy; default 25.
Test: filter combo reduces dataset; query count <= baseline.

### D2 Ticket Detail ⏳
Sections: header (subject + state + priority), sidebar (requester, tags editable, priority select, history toggle), thread (messages), composer (Action Text) with internal/public toggle.
Test: internal note not emailed.

### D3 Presence ⏳
Broadcast join/leave events; presence list Stimulus updates.
Test: two sessions see each other within 2s.
UI: See UI-5 Presence Indicator.

### D4 Typing Indicator (🛌 Deferred)
Will add ephemeral key TTL.

### D5 Assignment ⏳
Dropdown of available agents (inbox membership). Broadcast row mutation.
Test: assignment persists + row updates.

### D6 Inline Status/Priority Updates ⏳
Turbo frame around badges; update flows through state service.
Test: history includes change entry.

### D7 Tag Quick Add UX ⏳
Stimulus combobox -> create on enter if no match.
Test: new tag appears & is associated.
UI: See UI-2 Tag Combobox.

### D8 Internal Note Visibility Guard ⏳
Ensure internal note not included in outbound email job payload.
Test: job arguments exclude internal content.

### D9 Reopen Closed Ticket ⏳
Action button when state=Closed; returns to Open.

---
## Epic E: Templates & Composition
### E1 Rich Text Composer ⏳
Uses Action Text (Lexxy). Sanitization test with script tag.
UI: See UI-6 File Attachment (Composer) for attachments behavior.

### E2 Liquid Templates ⏳
Model: `Template(name, body)`; precompile cached.
Variables test: replaces `{{ recipient.first_name }}`.

### E3 Template Picker ⏳
Stimulus list filtered on keystroke; inserts HTML into composer.
UI: See UI-3 Template Picker.

### E4 Agent Signatures ⏳
Profile setting; appended unless user unchecks “Include signature”.

### E5 Auto-Reply Template ⏳
Tenant setting: enabled flag + body (Liquid allowed subset).

### E6 Last Message Variable Extraction (⏳)
Service extracts last public message text truncated to 200 chars, strips HTML.
Test: HTML removed; length cap.

---
## Epic F: Search (Meilisearch)
### F1 Configuration ⏳
ENV: host, api key; initializer.

### F2 Index Definitions ⏳
Ticket attributes + facets; message indexing for snippet composition.

### F3 Indexing Jobs ⏳
After commit hook enqueues.

### F4 Overlay UI ⏳
Keyboard shortcut `/` opens overlay; filters displayed left.
UI: See UI-4 Search Overlay.

### F5 Reindex Task ⏳
`rake meilisearch:reindex` builds per-tenant.

### F6 Permissions Filter ⏳
Search calls include inbox ids user allowed.

### F7 Zero Result UX (⏳)
Show suggestions: “Expand date range”, “Remove a tag”.

### F8 Performance Budget (⏳)
Track latency <1s (log instrumentation). Add test stub measuring around call.

---
## Epic G: Real-Time & Notification Layer
### G1 Turbo Streams Ticket Updates ⏳
Broadcast replace partial on state/priority/assignment.

### G2 Presence Isolation ⏳
Verify channel names include tenant id.

### G3 Live Message Append ⏳
Stream appended only to viewers of ticket.

### G4 Typing (🛌 Deferred)

### G5 Broadcast Optimization (⏳)
Batch successive updates within 100ms (debounce) to reduce frames.
Test: multiple rapid status changes produce <=2 broadcasts.

---
## Epic H: Billing & Seats
### H1 Stripe Bootstrap ⏳
Create customer + subscription trial (14 days) on signup.

### H2 Seat Sync ⏳
Quantity updated on agent toggle; webhook reconciliation stub.

### H3 Suspension (⏳)
Webhook simulation sets `tenant.suspended_at`; before_action blocks non-billing pages; banner.
Test: suspended tenant redirected from tickets to billing.

### H4 Billing Portal ⏳
Stripe portal session link generated.

### H5 Seat Drift Audit (🛌 Deferred)
Nightly compares computed vs stored quantity.

---
## Epic I: Webhook Engine
### I1 Endpoint CRUD ⏳
Model validations; secret auto-generated.

### I2 Event Registry ⏳
Enum constant list; spec ensuring doc parity.

### I3 Dispatcher w/ Retries ⏳
Exponential schedule array.

### I4 Signature ⏳
HMAC header spec.

### I5 Delivery Status UI (⏳)
Paginated list: event, status, last_attempt_at, attempt_count, response_code (if any).

### I6 Manual Replay (🛌 Deferred)

### I7 Slack Formatting (🛌 Deferred)

### I8 Webhook Payload Versioning (⏳)
Include `schema_version` field (integer starting 1) for forward compatibility.

---
## Epic J: UI / Component System & Onboarding Screens
### J1 Base Layout & Navigation ⏳
Primary nav items; active state styling; dark mode root class toggle.

### J2 Component Library (BasecoatUI) Integration (⏳)
Install, wrap primitives in ViewComponents: ButtonComponent, ModalComponent, BadgeComponent, DropdownComponent.
Test: renders with accessible roles.

### J3 Shared Partials ⏳
`_flash`, `_empty_state`, `_error_messages`, `_pagination`.

### J4 Accessibility Pass (⏳)
Run axe-core rspec; remediate critical issues.

### J5 Mobile Audit (⏳)
Viewport < 400px: navigation collapses to menu; composer usable.

### J6 Onboarding Screen 1: Create First Inbox (⏳)
Route: `/setup/first-inbox`. Fields: name. After create → forwarding instructions.
Test: skipping (direct nav to later step) redirects back.

### J7 Onboarding Screen 2: Forwarding Instructions (⏳)
Show generated address + copy button; “I’ve set this up” button marks step complete.
Test: completion sets checklist flag.

### J8 Onboarding Screen 3: Invite Teammates (⏳)
Form to add multiple emails (comma split). Invalid email shows inline error.
Test: invites created; pending list visible.

### J9 Onboarding Screen 4: Billing Overview (⏳)
Shows trial days remaining + CTA to add payment method (portal link).
Completion logic optional (can skip); step auto-completes when subscription active.

### J10 Progress Widget Component (⏳)
Shows 0–100%; uses checklist flags; accessible progressbar.
UI: See UI-7 Onboarding Progress Widget.

### J11 Signup Confirmation Banner (⏳)
Displays on all pages until all steps done OR dismissed (localStorage key).

---
## Epic K: Observability & Error Handling
### K1 Structured Logging (⏳)
Lograge JSON including `tenant_id`, `user_id`, `request_id`, `duration_ms`.

### K2 Ingestion Error Classes (⏳)
Define custom exceptions: `UnsupportedAttachment`, `ThreadingAmbiguity`.
Rescue in job -> tag + re-raise / discard policy.

### K3 Sentry Context (⏳)
Before_action sets Sentry.set_user + tenant context.

### K4 Webhook Failure Threshold (🛌 Deferred)
If 5 consecutive failures for endpoint -> auto deactivate + notify.

### K5 Performance Instrumentation (⏳)
ActiveSupport::Notifications subscriber logs ingestion latency bucket.

---
## Epic L: Performance & Caching
### L1 Query Budget Specs (⏳)
RSpec helper wraps request; fails if > target queries (ticket list <= 10 + N tags preload).

### L2 Liquid Template Cache ⏳
Cache key: `template:{id}:{updated_at.to_i}`.

### L3 Ticket List Cache (🛌 Deferred)
Fragment w/ filter digest; invalidated on ticket mutation.

### L4 Index Review & Cleanup (⏳)
Provide doc of index usage from pg_stat_statements sample.

### L5 Meilisearch Latency Logging (⏳)
Wrap search calls; log duration; threshold warning > 800ms.

---
## Epic M: Security Hardening
### M1 Cross-Tenant Request Specs ⏳
Shared example ensures 403.

### M2 Webhook Signature Negative ⏳
Tampered payload test.

### M3 Content Sanitization ⏳
Ensures `<script>` removed from stored message output.

### M4 MFA Policy (🛌 Deferred)

### M5 SAML (🛌 Deferred)

### M6 Rate Limit Scaffold (⚠️ Decision) (🛌 Deferred)
Potential rack-attack baseline.

---
## Epic N: Imports (Deferred Scaffold)
N1 Placeholder UI (�) – upload form stores blob + row count.
N2 Mapping DSL (🛌) – configure source field → internal attr.
N3 Processor Job (🛌) – creates tickets; error CSV.

---
## Epic O: Future Enhancements (Reference Only)
Typing indicator, webhook replay, Slack deep integration, SMTP per-tenant, DKIM, fallback search, watchers, SLA, automations, analytics, mobile optimization, Redis presence, CSAT.

---
## Acceptance Criteria Matrix (Sample Excerpts)
| Feature | Success Conditions | Error Conditions | Tests |
|---------|-------------------|------------------|-------|
Signup | Tenant+User created; redirect to setup | Duplicate subdomain; invalid email | system, model |
Email Ingest | New ticket or appended message; ack sent once | Unknown inbox → logged | service, job |
Search | Results limited to permitted inboxes | None (empty safe) | request, integration |
Webhook | 2xx marks delivered; retries escalate delay | Exhausted -> failed status | job, model |

---
## Test Coverage Checklist (Must Have Before MVP Code Freeze)
* 100% models: validations + critical scopes.
* 100% services: EmailProcessor, Threading, TicketStateTransition, LiquidRenderer.
* 90% controllers: primary CRUD + security.
* System flows: signup→inbox→ingest→reply→search→webhook.
* Performance spec: ticket list query budget.
* Security spec: cross-tenant attempt battery.
* Billing spec: seat toggle adjusts quantity.
* UI interaction specs covered: UI-1 (logo upload), UI-2 (tag combobox), UI-3 (template picker), UI-4 (search overlay), UI-5 (presence), UI-6 (composer attachments), UI-7 (onboarding progress widget).

---
## Release Readiness (Updated)
Additions to previous checklist:
* Email confirmation gating verified.
* Structured logs visible in staging aggregator.
* Meilisearch latency < 1s P95 sample.
* Webhook payload schema_version documented.

---
## Immediate Next Detailed Tasks (Sprint Candidate)
1. A4 – Implement unified signup + confirmation gating.
2. A5 – Checklist persistence + widget (J10) + onboarding screens J6–J9.
3. H3 – Billing suspension with integration test.
4. I5 + I8 – Webhook delivery UI + schema_version field.
5. K1 + K3 + K5 – Structured logging, Sentry context, ingestion metrics.
6. L1 – Query budget harness + baseline numbers.
7. J2 – BasecoatUI component wrappers.
8. E6 – Last message variable extraction service.
9. F7 – Zero results UX.
10. G5 – Broadcast debounce optimization.

---
## Decisions Pending
| Topic | Question | Needed By | Notes |
|-------|----------|-----------|-------|
Email Confirmation | Block outbound until confirmed? | Before A4 merge | Default = block |
Rate Limiting | Introduce rack-attack MVP? | Post-MVP | Could mitigate abuse |
Tenant Id Column | `tenant_id` vs `account_id` unify | Pre freeze | Choose and migrate |

---
## Metrics (Expanded Instrumentation Plan)
* `ingest.latency_ms` (ActionMailbox receipt → ticket commit)
* `search.request_ms` (Meilisearch HTTP timing)
* `webhook.delivery_attempt_ms`
* `seat.sync.duration_ms`
* `ticket.list.query_count`

---
Adjust / append as implementation reveals new edge cases. Keep diffs focused & reference section IDs when updating.

## Appendix: UI Interaction Specifications (UI-1 .. UI-7)

Purpose: Eliminate ambiguity for complex interactive elements. Each spec includes: contract, behaviors, accessibility, error states, metrics, and test cases. Reference these IDs from epic tasks.

### UI-1 Logo Uploader (Referenced by A3 Tenant Branding)
Contract:
* Input: User provides image via drag & drop OR file picker click.
* Accepted types: `image/svg+xml`, `image/png`, `image/jpeg`.
* Max file size: 2MB. SVG sanitized (remove scripts, external hrefs).
* Output: Active Storage attachment (original) + 128px square variant (background job) + stored metadata (content_type, byte_size, width, height if raster).
Behaviors:
1. Drag-over highlights drop zone (add `is-dragging` class).
2. Drop triggers optimistic preview (object URL) immediately.
3. Upload errors revert to prior state (if any) and surface inline error.
4. Replace action: selecting a new file overwrites previous after confirmation dialog if one exists.
5. Remove: explicit “Remove logo” button resets to generated initials avatar.
Error States:
* `file_type_unsupported` – show: “Use SVG, PNG, or JPG.”
* `file_too_large` (> 2MB) – show size & limit.
* `processing_error` – variant generation failure (retry button appears, logs error code).
Accessibility:
* Drop zone is a button element (or role="button") with `aria-label="Upload logo"`.
* Focus ring visible; Enter/Space open file dialog.
* Remove button has `aria-label="Remove uploaded logo"`.
Metrics (optional): `logo.upload.success`, `logo.upload.error` tagged by error_type, variant processing duration.
Tests:
* System: happy path upload PNG -> preview shown -> saved.
* System: reject >2MB file.
* Controller/Service: sanitizes SVG (strip script tag).
* Background job: creates variant; failure surfaces processing_error.

### UI-2 Tag Combobox (Referenced by D7 Tag Quick Add)
Contract:
* Input: Free text search; returns existing tags (case-insensitive) OR creates new on Enter if none.
* Limit: Max 20 tags per ticket.
Behaviors:
1. Debounced (150ms) fetch as user types; spinner while loading.
2. Arrow keys navigate list; Enter selects; Escape closes without changes.
3. Creating new tag slugifies input (spaces -> dash, lowercase), trims length 40 chars.
4. Duplicate (case-insensitive) selection prevented (visual shake or subtle highlight).
5. Selected tags render as removable pills; Backspace in empty input focuses last pill.
Error States:
* `tag_limit_reached` (attempt to add 21st) – toast + blocked.
* `creation_failed` (server 422) – show inline error under input.
Accessibility:
* ARIA combobox pattern: input `role="combobox"` with `aria-expanded`, `aria-controls`.
* Listbox items `role="option"` with `aria-selected`.
Metrics: `tags.add`, `tags.create`, `tags.limit_hit`.
Tests:
* System: create new tag via Enter when none exists.
* System: reach limit and verify blocked.
* Model: uniqueness case-insensitive enforced.

### UI-3 Template Picker (Referenced by E3 Template Picker)
Contract:
* Invoked via keyboard shortcut (Cmd/Ctrl+Shift+T) or button in composer.
* Displays searchable list of templates; selecting inserts Liquid-rendered (preview mode) HTML into Action Text at cursor.
Behaviors:
1. Opens modal overlay; focus traps inside until closed.
2. Typing filters client-side (fetch all once on open) with fuzzy match (simple subsequence algorithm).
3. Up/Down arrows navigate; Enter inserts & closes; Escape closes (restores focus to composer).
4. Insertion wraps in undo group (single undo removes entire inserted content) via editor API.
5. Shows variables legend link opening small popover (non-blocking).
Error States:
* `load_failed` – display retry button.
Accessibility:
* Modal has `role="dialog"` + `aria-labelledby` (template picker heading).
* List has `role="listbox"`; items `role="option"`.
Metrics: `template_picker.open`, `template_picker.insert`.
Tests:
* System: open via shortcut, insert template, verify content present.
* Stimulus: fuzzy filtering hides non-matching items.

### UI-4 Search Overlay (Referenced by F4 Global Search Overlay UI)
Contract:
* Global quick search triggered by pressing `/` (when not inside input/textarea) OR clicking search icon.
* Presents input + facet filters (state, inbox, tag) + results list with highlight.
Behaviors:
1. Overlay uses portal root, adds body class `overlay-open` (prevent scroll).
2. Input auto-focused; pressing `/` again while open focuses input (does not close).
3. Debounced (200ms) remote search; stale responses discarded via request timestamp.
4. Recent queries (last 5) persisted in `localStorage` (tenant-scoped key) – show when input empty & focused.
5. Selecting result (Enter or click) navigates (Turbo visit) and closes overlay.
Error States:
* Network error -> inline retry link.
* Empty results -> suggestions (“Expand date range”, “Remove a tag”) referencing F7.
Accessibility:
* `role="dialog"`; results list `role="listbox"`.
* Keyboard: Tab cycles facets → results → close button.
Metrics: `search.overlay.open`, `search.query` (latency ms), `search.zero_result`.
Tests:
* System: open with `/`, perform search, navigate to ticket.
* System: empty result displays suggestions.
* Unit: discards stale response.

### UI-5 Presence Indicator (Referenced by D3 Presence)
Contract:
* Shows avatars of users currently viewing ticket; collapses to +N after 5.
Behaviors:
1. Subscribe on ticket show; heartbeat every 5s; absence of heartbeat >10s prunes user.
2. Tooltips show agent name (title attribute or accessible name).
3. Avatars update order: newest rightmost.
Error States:
* Connection drop -> show subtle offline badge (optional, non-blocking).
Accessibility:
* Container `aria-label="Currently viewing agents"`.
* Each avatar has `aria-label` with agent name.
Metrics: `presence.viewers.count` gauge (periodic sample client->server optional).
Tests:
* System: two sessions appear to each other within 2s.
* Unit: pruning removes stale viewer after >10s simulated.

### UI-6 File Attachment (Composer) (Referenced by E1 Rich Text Composer)
Contract:
* Multiple file attachments added to outbound message (stored via Active Storage).
* Per-file max 25MB; aggregate max 50MB per message.
Behaviors:
1. Drag & drop zone integrated with composer; inline list of attachments with progress bars.
2. Parallel direct uploads (if using Active Storage direct upload) limited to 3 concurrent; queue remainder.
3. Cancel button aborts upload (removes from list, cancels request).
4. Attachment removal updates aggregate size tally.
Error States:
* `file_too_large` – per-file; `aggregate_too_large` – when new file would exceed 50MB.
* `upload_failed` – show retry icon per attachment.
Accessibility:
* Each attachment row: file name as button to focus; remove has `aria-label="Remove attachment {filename}"`.
Metrics: `attachments.upload.success`, `attachments.upload.error`.
Tests:
* System: add multiple files; cancel one; ensure aggregate adjusts.
* Unit: guard rejects >50MB aggregate.

### UI-7 Onboarding Progress Widget (Referenced by J10 Progress Widget Component & A5 Checklist)
Contract:
* Visual progress bar + list of steps; steps gated sequentially except billing screen accessible anytime.
Behaviors:
1. Fetch checklist JSON on layout load (cached in memory per session until mutation).
2. Clicking incomplete future step attempts navigation -> redirect back with flash hint.
3. Completion of a step triggers Turbo Stream update of widget (partial replacement) + announces via ARIA live region.
4. Dismiss banner state stored in localStorage (does not hide side widget itself).
Error States:
* Network failure fetching checklist -> fallback skeleton (no blocker) + retry button.
Accessibility:
* Progressbar: `role="progressbar"` with `aria-valuenow`, `aria-valuemax`.
* Live region polite announcement: “Onboarding step ‘Create Inbox’ completed (2 of 4).”
Metrics: `onboarding.step.complete`, `onboarding.banner.dismiss`.
Tests:
* System: complete steps in order; attempt skip blocked.
* System: dismiss banner persists across page reload.

---
Cross-reference Summary:
* A3 -> UI-1
* D7 -> UI-2
* E3 -> UI-3
* F4 -> UI-4
* D3 -> UI-5
* E1 -> UI-6
* J10 & A5 -> UI-7

Update process: Changes to UI interactions must update this appendix and link commit in related epic task.

## Epic A: Foundations & Tenancy
| ID | Task | Status | Exit Criteria | Depends |
|----|------|--------|---------------|---------|
A1 | Rails app + core gems (Devise, Pundit, Tailwind, Turbo, Stimulus, Action Text, Pay, Solid * stack) | ⏳ | App boots; gems loaded; base layout w/ dark mode scaffold | — |
A2 | Subdomain routing + tenant middleware (`Current`) | ⏳ | Requests under subdomain load tenant or 404; tests for isolation | A1 |
A3 | Tenant model + branding fields + forwarding root address | ⏳ | Migration + model + UUID email generated; validation specs | A1 |
A4 | Account signup + onboarding checklist storage | ⏳ | Wizard persists step completions; system spec passes | A2 |
A5 | Role & seat model (admin/agent + agent toggle) | ⏳ | Toggling updates billable scope; policy specs | A2 |

## Epic B: Data & Core Domain
| ID | Task | Status | Exit Criteria | Depends |
|----|------|--------|---------------|---------|
B1 | Schema (accounts, users, inboxes, recipients, tickets, messages, tags, joins) | ⏳ | Migrations + schema consistency test | A1 |
B2 | Index strategy (initial) | ⏳ | Indexes present for hot queries; no missing FK index warnings | B1 |
B3 | Model scoping concern (`TenantScoped`) | ⏳ | All tenant models include; leakage spec passes | B1 |
B4 | Ticket lifecycle enums + transitions | ⏳ | State change service + tests; allowed transitions enforced | B1 |
B5 | Tagging domain + uniqueness + autocomplete scope | ⏳ | Tag create & assign spec + case-insensitive uniqueness | B1 |
B6 | Logidze versioning on tickets (status/priority/tags) | ⏳ | Version history visible in UI; spec ensures diff capture | B4 |

## Epic C: Inboxes & Email Ingestion
| ID | Task | Status | Exit Criteria | Depends |
|----|------|--------|---------------|---------|
C1 | Inbox CRUD + address generation | ⏳ | System test creates inbox; unique address assertion | A3 |
C2 | Inbox membership (user_inbox_assignments) | ⏳ | Filtering tickets per agent inbox membership passes | C1 |
C3 | Action Mailbox routing integration | ⏳ | Incoming fixture email persisted | B1 |
C4 | Email parsing + Recipient creation | ⏳ | Service spec covers plain + HTML + attachments stub | C3 |
C5 | Threading (VERP + headers + fallback) | ⏳ | Specs for each precedence path | C4 |
C6 | Auto-acknowledgement (first message only) | ⏳ | Test ensures only 1 ack per ticket | C5 |
C7 | Attachments support (<=25MB guard) | ⏳ | Oversized rejected with log; standard saved via Active Storage | C4 |
C8 | Raw source restricted visibility | ⏳ | Admin (platform) only view path; tenant admin denied | C4 |
C9 | Bounce handling stub (Phase 2) | 💤 | Placeholder service + ADR note | C6 |

## Epic D: Ticket Experience & Collaboration
| ID | Task | Status | Exit Criteria | Depends |
|----|------|--------|---------------|---------|
D1 | Ticket list (filters, pagination Pagy) | ⏳ | Filtering by state/tag/inbox works; query count budget met | B4 |
D2 | Ticket detail thread (messages + internal notes) | ⏳ | UI toggles public/internal; note excluded from recipient email | C5 |
D3 | Presence (viewing) broadcast | ⏳ | Two sessions show each other; cable test | D2 |
D4 | Typing indicator (Phase 2) | 💤 | Channel events + idle timeout | D3 |
D5 | Assignment update + real-time row refresh | ⏳ | Broadcast on assignment; row replaced in list | D1 |
D6 | Priority & status inline updates | ⏳ | Turbo stream updates; history recorded | D2 |

## Epic E: Templates & Editor
| ID | Task | Status | Exit Criteria | Depends |
|----|------|--------|---------------|---------|
E1 | Action Text (Lexxy) integration | ⏳ | Composer renders & persists rich content | A1 |
E2 | Liquid template model + variables context | ⏳ | Spec rendering variables + sanitization | E1 |
E3 | Template picker Stimulus controller | ⏳ | Keyboard accessible; inserts content | E2 |
E4 | Agent signatures (toggle include) | ⏳ | Stored per agent; inserted into outgoing | E2 |
E5 | Auto-reply template configurable | ⏳ | Enable/disable & body edit test | C6 |

## Epic F: Search (Meilisearch)
| ID | Task | Status | Exit Criteria | Depends |
|----|------|--------|---------------|---------|
F1 | Meilisearch client config + ENV wiring | ⏳ | Rake connectivity test passes | A1 |
F2 | Ticket + Message index definitions | ⏳ | Fields + facets per spec | B4 |
F3 | Async indexing job + callbacks | ⏳ | Create/update triggers enqueue | F2 |
F4 | Global search overlay UI | ⏳ | Highlighting + filters functional | F3 |
F5 | Reindex rake task | ⏳ | Full rebuild populates index | F2 |
F6 | Inbox membership filter enforcement | ⏳ | Agent w/o inbox can't see restricted results | F4 |
F7 | Fallback (Phase 2) | 💤 | Postgres ILIKE fallback adapter | F2 |

## Epic G: Real-Time & Notification Layer
| ID | Task | Status | Exit Criteria | Depends |
|----|------|--------|---------------|---------|
G1 | Turbo streams wiring (ticket updates) | ⏳ | State/prio/assignment propagate instantly | D6 |
G2 | Presence channel isolation | ⏳ | Tenant mix-up test proves isolation | D3 |
G3 | New message broadcast (viewer context) | ⏳ | Only viewers get appended stream | C5 |
G4 | Typing events (Phase 2) | 💤 | See D4 | D4 |

## Epic H: Billing & Seats (Stripe via Pay)
| ID | Task | Status | Exit Criteria | Depends |
|----|------|--------|---------------|---------|
H1 | Stripe customer + subscription bootstrap | ⏳ | Trial start on signup; test mode spec | A4 |
H2 | Seat quantity sync (agent toggle) | ⏳ | Toggle changes Stripe quantity; spec w/ webhook stub | H1 |
H3 | Suspension gating (3 failed payments) | ⏳ | Simulated webhook sets suspended flag & blocks app | H2 |
H4 | Billing portal link + UI | ⏳ | Link present; access allowed when suspended | H1 |
H5 | Nightly reconciliation job (Phase 2) | 💤 | Compares counted seats vs Stripe quantity | H2 |

## Epic I: Webhook Engine
| ID | Task | Status | Exit Criteria | Depends |
|----|------|--------|---------------|---------|
I1 | Endpoint model (url, secret, active) | ⏳ | CRUD + validation specs | B1 |
I2 | Event registry + filter | ⏳ | Whitelist events enumerated | D6 |
I3 | Dispatcher job w/ retries (exp backoff) | ⏳ | Failure path logs + retry schedule test | I2 |
I4 | HMAC signature header | ⏳ | Spec verifying deterministic signature | I3 |
I5 | Delivery status UI (success/failure list) | ⏳ | Paginated table + retry counts | I3 |
I6 | Manual replay (Phase 2) | 💤 | Replay button enqueues delivery | I5 |
I7 | Slack formatting adapter (Phase 2) | 💤 | Basic markdown to Slack text | I2 |

## Epic J: UI / Component System
| ID | Task | Status | Exit Criteria | Depends |
|----|------|--------|---------------|---------|
J1 | Base layout (dark mode ready) | ⏳ | Toggles theme class; no FOUC | A1 |
J2 | Component library adoption (BasecoatUI) | ⏳ | Core primitives (buttons, inputs, modal) wrapped | J1 |
J3 | Shared partials (`_flash`, `_pagination`, `_avatar`) | ⏳ | Reused ≥2 places; no duplication | J1 |
J4 | Stimulus controllers (presence, tags, search overlay, template picker) | ⏳ | All controllers namespaced & tested | Various |
J5 | Accessibility pass (labels, focus states) | ⏳ | Axe linter clean (critical issues) | J2 |
J6 | Mobile responsive audit (critical pages) | ⏳ | Ticket list & detail usable < 400px | J1 |

## Epic K: Observability & Error Handling
| ID | Task | Status | Exit Criteria | Depends |
|----|------|--------|---------------|---------|
K1 | Structured logging (JSON in production) | ⏳ | Key fields: tenant_id, request_id, user_id | A1 |
K2 | Ingestion error taxonomy & retry caps | ⏳ | Distinct log tags; spec verifying max retries | C4 |
K3 | Webhook failure alert hook (Phase 2) | 💤 | Threshold triggers email/slack alert | I3 |
K4 | Sentry context enrichment middleware | ⏳ | Tenant/user tags present in captured errors | A2 |

## Epic L: Performance & Caching
| ID | Task | Status | Exit Criteria | Depends |
|----|------|--------|---------------|---------|
L1 | Query budget tests (ticket list & search) | ⏳ | RSpec expectation < N queries per request | D1 |
L2 | Cache compiled Liquid templates | ⏳ | Cache hit spec (no reparse on second render) | E2 |
L3 | Optional ticket list caching (TTL) | 💤 | Cache invalidation hooks on mutation | D1 |
L4 | Index analysis & cleanup (unused indexes) | ⏳ | Report with removals & rationale | B2 |

## Epic M: Security Hardening
| ID | Task | Status | Exit Criteria | Depends |
|----|------|--------|---------------|---------|
M1 | Cross-tenant request spec battery | ⏳ | Forged IDs return 403 | A2 |
M2 | Webhook signature negative tests | ⏳ | Invalid signature 401 path | I4 |
M3 | Content sanitization (templates + messages) | ⏳ | XSS payload neutralized spec | E2 |
M4 | MFA policy toggles (Phase 2) | 💤 | TOTP enrollment flow + backup codes | A5 |
M5 | SAML integration (Phase 2) | 💤 | IdP metadata ingest + assertion validation | M4 |

## Epic N: Imports (Phase 2 Seed)
| ID | Task | Status | Exit Criteria | Depends |
|----|------|--------|---------------|---------|
N1 | Import placeholder UI + model | 💤 | Upload saved; status pending | B1 |
N2 | Field mapping config DSL | 💤 | Map external columns → internal attributes | N1 |
N3 | Async import processor | 💤 | Rows create tickets; error CSV generated | N2 |

## Epic O: Future Enhancements (Deferred)
Macro actions, SLA engine, advanced analytics, watchers/followers, Slack deep integration, typing indicator, per-tenant SMTP + DKIM, spam filtering pipeline, Postgres ILIKE search fallback, webhook replay & alerting, bulk ticket actions, presence via Redis, org-level customer grouping, advanced audit log (beyond Logidze), CSAT, mobile optimization.

## 1. Cross-Cutting Definition of Done
* Tests: unit + policy + system where user flow involved.
* Security: tenant scoping verified.
* Performance: no new N+1 (rspec query counter where relevant).
* Docs: update `design.md` if architecture materially changes.
* Observability: meaningful logs for failures.

## 2. Release Readiness Checklist (Pre-MVP)
1. All Epics A–I critical tasks ⏳ or explicitly postponed.
2. Billing suspension path (H3) implemented or feature-flagged off.
3. Seat updates reliable under concurrency (stress test script run).
4. Search reindex completed successfully on staging dataset.
5. Webhooks deliver & retry under simulated 500/timeout conditions.
6. Security sweep: manual attempt to access cross-tenant ids.
7. Rollback plan documented (db snapshot + environment variable flag to disable ingestion).

## 3. Suggested Immediate Next Tasks (In Priority Order)
1. H3 – Suspension gating ⏳
2. I5 – Webhook delivery status UI ⏳
3. J2 – Component library adoption (BasecoatUI) ⏳
4. K1/K4 – Structured logging + Sentry enrichment ⏳
5. L1 – Query budget test harness ⏳
6. J5/J6 – Accessibility & mobile passes ⏳

## 4. Metrics to Track Post-MVP
* Ingestion latency (email received → ticket visible) P50/P95
* Ticket list render time server-side P95
* Webhook success rate (%) & average delivery attempts
* Seat sync drift (Stripe quantity vs computed seats)
* Search query latency & zero-result ratio

## 5. Mapping to Requirements Summary
* Multi-tenancy: Epics A, B
* Inboxes & Email: Epic C
* Tickets & States: Epics B, D
* Tagging: B5, D1
* Search: Epic F
* Templates & Signatures: Epic E
* AuthZ/AuthN: A5, M series (future MFA/SAML)
* Background jobs: C, F3, I3, H2, search & webhook queues
* Real-time: G series
* Billing: H series
* Webhooks: I series
* Caching & Performance: L series
* Security: M series
* Imports: N series (Phase 2)
* UI Architecture: J series
* Observability: K series

---
Adjust, split, or mark tasks with effort tags next iteration. Can auto-generate GitHub issues from this structure on request.
