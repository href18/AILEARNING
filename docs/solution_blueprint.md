# Compliance & Safety Training Platform Solution Blueprint

## 1. Executive Summary
This blueprint translates the MVP scope into a shippable solution that enables tenants to manage compliance and safety training end-to-end. It maps functional journeys to Supabase-backed services and a Flutter web/mobile experience, ensuring fast delivery, high completion rates, and verifiable compliance evidence.

## 2. Product Requirements Traceability
### 2.1 Personas and Primary Objectives
| Persona | Primary Objectives | Key Success Metrics |
| --- | --- | --- |
| Participant | Complete assigned training, track progress, access certificates | ≥85% on-time completion, average feedback ≥4/5 |
| Company Admin | Assign courses, enforce deadlines, produce audit evidence | 100% of completions recorded with certificates |
| Content Author | Create & localise content, manage versions | Module update cycle ≤24h, localisation parity NO/EN |
| Super Admin | Operate multi-tenant platform, manage billing | Tenant provisioning ≤15 min, billing reconciliation daily |

### 2.2 Functional Requirements by Epic
1. **Authentication & Tenancy**
   - Email/password, magic-link, Microsoft/Google SSO.
   - Org onboarding wizard for admins; invite flow for additional members.
   - Role-based access enforcement via RLS and Flutter route guards.
2. **Course Delivery**
   - Course catalogue with Norwegian/English metadata.
   - Module player supporting video, article markdown, quiz interactions.
   - Progress autosave, resume, offline queue for intermittent connectivity.
3. **Assignments & Deadlines**
   - Bulk assignment by admin with due dates and optional reminders override.
   - Participant notification emails + in-app task list with urgency badges.
   - Automated reminder scheduler (7/3/1 days pre-due, expiry follow-up).
4. **Certificates & Compliance**
   - Certificate issuance pipeline after quiz pass + course completion.
   - PDF stored with QR verification link pointing to Supabase Edge verification endpoint.
   - Immutable audit log capturing assignment, attempt, issuance events.
5. **Reporting & Analytics**
   - Admin dashboard widgets (completion %, overdue count, median completion time).
   - Filterable reports with CSV export and scheduled email delivery.
   - PostHog instrumentation for funnel tracking (invited → started → completed → certified).
6. **Payments & Billing**
   - Stripe Checkout for seat/course purchases; billing portal for payment method updates.
   - Manual invoice workflow with approval state machine.
7. **Admin CMS**
   - Draft/publish lifecycle, version metadata, localisation diff view.
   - Quiz builder with randomisation toggle and per-question feedback.
8. **Support & Help**
   - Contextual help drawer, ticket submission stored in `support_tickets`.
   - Status page link and in-app incident banner.

## 3. Solution Architecture
### 3.1 High-Level Diagram (Narrative)
1. **Flutter Client (Web/Mobile)** authenticates with Supabase Auth and stores offline progress events locally.
2. **Supabase Postgres** hosts tenant-isolated data with RLS tied to `org_members`.
3. **Supabase Storage** stores course assets and certificates with signed URL access.
4. **Edge Functions (Deno)** provide secure orchestration: assignments, reminders, quiz grading, certificate rendering, billing webhooks.
5. **External Services** include Stripe (billing), Resend/SendGrid (emails), Vimeo or CDN (video), PostHog (analytics), Sentry (monitoring).

### 3.2 Module Interaction
- **Auth Flow:** Flutter → Supabase Auth (email/password or OAuth). Upon login, client fetches `org_members` to determine roles and configure `TenantGuard`.
- **Course Playback:** Client requests course/modules via Supabase REST/GraphQL. Progress updates sent to `progress-update` function; offline queue flushes when online.
- **Quiz Submission:** Player sends answers to `quiz-submit` Edge Function, which calculates score, logs attempt, and triggers `progress-update` for module completion.
- **Certificate Issuance:** When assignment meets completion criteria, `cert-issue` Edge Function generates PDF, stores in Storage, inserts `certificates` row, and emits notification email via Resend.
- **Reporting:** Admin dashboard queries materialized views; CSV export requests to `reports-export` which runs server-side SQL, uploads CSV, emails signed URL.
- **Billing:** Admin selects plan → Stripe Checkout → webhook `billing-webhook` updates `orgs.billing_plan` and seat counts; manual invoices inserted by admins with status workflow.

## 4. Data Model Extensions
### 4.1 Core Tables (from MVP)
Adopt schema outlined in MVP spec for `orgs`, `org_members`, `courses`, `course_i18n`, `modules`, `module_i18n`, `quizzes`, `quiz_questions`, `quiz_options`, `assignments`, `progress`, `certificates`, `audit_logs`.

### 4.2 Additional Tables
```sql
create table support_tickets (
  id uuid primary key default gen_random_uuid(),
  org_id uuid references orgs(id) on delete cascade,
  created_by uuid references auth.users(id),
  subject text not null,
  body text not null,
  status text check (status in ('open','in_progress','resolved')) default 'open',
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table invoices (
  id uuid primary key default gen_random_uuid(),
  org_id uuid references orgs(id) on delete cascade,
  type text check (type in ('stripe','manual')),
  amount_cents int not null,
  currency text default 'NOK',
  status text check (status in ('draft','sent','paid','void')) default 'draft',
  stripe_session_id text,
  due_at timestamptz,
  created_at timestamptz default now(),
  paid_at timestamptz
);

create table course_versions (
  id uuid primary key default gen_random_uuid(),
  course_id uuid references courses(id) on delete cascade,
  version int not null,
  change_log text,
  published_by uuid references auth.users(id),
  published_at timestamptz default now()
);

create table reminder_queue (
  id bigserial primary key,
  assignment_id uuid references assignments(id) on delete cascade,
  reminder_type text check (reminder_type in ('due_7','due_3','due_1','expiry','overdue')),
  scheduled_at timestamptz not null,
  sent_at timestamptz,
  error text
);
```

### 4.3 RLS Principles
- Policies ensure users access rows where `org_id` matches membership and role-specific predicates (e.g., participants can only read their assignments, admins can update assignments within their org).
- Audit tables (`audit_logs`) set to `insert` only with Supabase service role.

## 5. API & Edge Function Contracts
| Function | Method | Request | Response | Notes |
| --- | --- | --- | --- | --- |
| `assignments-create` | POST | `{ org_id, course_id, assigned_to: uuid[], due_at }` | `{ assignment_ids[] }` | Validates seat availability, enqueues reminders, sends emails. |
| `progress-update` | POST | `{ assignment_id, module_id, last_pos, completed, score? }` | `{ status: 'ok', completion_pct }` | Updates progress row, emits audit log event. |
| `quiz-submit` | POST | `{ assignment_id, module_id, answers: [] }` | `{ score, passed, feedback[] }` | Handles shuffle order, increments attempts, triggers certificate check. |
| `cert-issue` | POST | `{ assignment_id }` | `{ certificate_id, pdf_url, expires_at }` | Verifies completion, renders PDF via HTML template. |
| `reports-export` | POST | `{ org_id, filters }` | `{ export_id }` | Background job; status polled via `GET /reports-export/:id`. |
| `billing-webhook` | POST (Stripe) | Stripe event payload | `200 OK` | Updates `invoices`, `orgs`, seat counts. |

## 6. Frontend Architecture
### 6.1 State Management & Routing
- Use Riverpod for dependency injection and state observers (auth state, assignments, player state).
- Routing with `go_router`, integrating `AuthGate` and `TenantGuard` to redirect unauthorised users.

### 6.2 UI Modules
- **Participant Area:** `MyCoursesScreen`, `CoursePlayer`, `CertificateWallet`, `ProfileSettings`.
- **Admin Area:** `DashboardScreen`, `AssignmentsScreen`, `PeopleScreen`, `ReportsScreen`, `BillingScreen`.
- **Authoring:** `CourseList`, `CourseEditor`, `ModuleEditor`, `QuizBuilder`.
- **Shared Components:** `LanguageToggle`, `ReminderBadge`, `ProgressStepper`, `AuditTimeline`.

### 6.3 Offline & Accessibility
- Implement `ProgressQueueService` using `hive` to store offline events.
- Provide accessible controls: keyboard navigation for quizzes, captions for videos, contrast-checked palette.
- Localisation files maintained via `arb` format with translation pipeline.

## 7. DevOps & Environment Strategy
- **Repositories:** Monorepo containing Flutter app, Supabase migrations (`supabase/migrations`), Edge Functions (`supabase/functions`).
- **Environments:** `dev` (local Supabase + emulator), `staging` (Supabase project), `production`.
- **CI/CD:** GitHub Actions workflows
  - `lint-test`: Flutter analyzer, unit tests, Supabase migration checks.
  - `build-web`: Deploy to Firebase Hosting/Netlify on main.
  - `build-mobile`: Produce TestFlight/Android internal builds weekly.
  - `functions-deploy`: Deploy Edge Functions via Supabase CLI.
- **Secrets Management:** Use GitHub OIDC + Supabase access tokens. Stripe keys stored as GitHub secrets & Supabase config vars.
- **Observability:** Sentry DSNs for Flutter and Edge, Supabase log drains, PostHog dashboards.

## 8. Quality Assurance Plan
- **Automated Testing:**
  - Flutter unit tests (business logic), widget tests (CoursePlayer, QuizWidget).
  - Integration tests using `flutter_test` for key flows (login → complete course → certificate download).
  - Supabase SQL unit tests for RLS using `pgTAP` or Supabase test harness.
  - Edge Function tests via Deno test runner.
- **Manual Testing:**
  - Weekly exploratory sessions covering multilingual UI and accessibility.
  - Pilot tenant UAT scenario scripts for admin and participant journeys.
- **Performance Targets:**
  - Player initial load <2s on broadband, <4s on 3G.
  - PDF generation <5s average, with progress indicators.

## 9. Security, Privacy, and Compliance Controls
- Enforce mandatory TLS and HTTP security headers in Flutter web hosting.
- Apply `row-level` policies for every table referencing `org_id`.
- Encrypt PII at rest using Supabase default encryption; avoid storing unnecessary personal data (birth date optional, hashed if stored).
- GDPR tooling: self-service data export (participant downloads own data), admin-level delete requests executed via support workflow.
- Maintain audit log retention for ≥5 years to satisfy regulatory audits.
- Implement incident response plan with severity matrix and notification procedure.

## 10. Implementation Timeline (Aligned to MVP Plan)
| Week | Focus | Key Deliverables |
| --- | --- | --- |
| 1 | Foundations | Supabase project, auth flows, org onboarding, CI skeleton |
| 2 | Tenancy & Shell | Role management, navigation, localisation scaffolding |
| 3 | Course CMS | Course & module CRUD, storage integration |
| 4 | Player & Quiz | CoursePlayer, quiz grading, progress tracking |
| 5 | Assignments | Admin assignment UI, reminder scheduler, email templates |
| 6 | Certificates | PDF generator, QR verification endpoint, audit logging |
| 7 | Reporting & Billing | Dashboard metrics, CSV export, Stripe integration |
| 8 | Support & Polish | Support tickets, status banner, accessibility pass |
| 9 | QA & Pilot | Automated tests, UAT scripts, pilot tenant onboarding |
| 10 | Launch | Runbooks, monitoring, production cut-over |

## 11. Post-Launch Operations
- **Runbooks:** incident handling, on-call rotation, billing reconciliation, content update SOPs.
- **Metrics Review:** weekly review of completion rates, overdue counts, reminder effectiveness.
- **Customer Success:** proactive outreach for expiring certificates, quarterly business reviews.
- **Continuous Improvement:** backlog grooming for gamification, practical training checklists, SCORM ingestion.

## 12. Appendices
### 12.1 Email Template Inventory
- Assignment notification (admin & participant variants).
- Reminder emails (7/3/1 days, expiry, overdue).
- Certificate issued notification with PDF link.
- Manual invoice sent / payment received.

### 12.2 Edge Function Deployment Checklist
1. Run automated tests (`deno test`).
2. Validate environment variables (Stripe keys, Resend API key).
3. Deploy via `supabase functions deploy <name>` to staging → production.
4. Update monitoring dashboards and alert thresholds post-deploy.

### 12.3 Compliance Artifacts
- Template for audit export: assignments, progress, certificates, audit logs zipped per org.
- Data Processing Agreement checklist for tenant onboarding.
- Accessibility VPAT summary for web application.
