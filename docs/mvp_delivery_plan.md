# Compliance & Safety Training Platform MVP Delivery Plan

## 1. Product Vision
Deliver a fast, audit-ready digital training platform that helps Norwegian enterprises keep workers compliant with critical HSE requirements. The MVP must make it effortless for company admins to assign safety courses, for participants to complete them quickly on any device, and for compliance teams to export verifiable documentation.

## 2. Success Criteria
- **Time-to-launch:** Production-ready MVP shipped within 8–10 weeks.
- **Participant experience:** ≥85% of invited participants complete courses within due dates during pilot.
- **Compliance evidence:** 100% of completions accompanied by downloadable, audit-grade certificates and logged attempts.
- **Operational readiness:** Admins can self-serve assignments, run reports, and handle billing through Stripe or manual invoices.

## 3. Core Personas & Jobs-to-be-Done
| Persona | Primary Jobs | Key Needs |
| --- | --- | --- |
| Participant | Complete assigned courses, download certificates | Mobile-friendly player, multilingual content, reminders |
| Company Admin | Assign courses, monitor compliance, pass audits | Bulk assignment, dashboards, CSV exports, certificate retrieval |
| Content Author | Maintain catalog, localise content | Version control, preview, localisation workflow |
| Super Admin | Manage tenants, billing, integrations | Org provisioning, plan management, analytics |

## 4. Feature Scope Breakdown
### 4.1 Authentication & Tenancy
- Email/password sign-up with Supabase Auth.
- Optional magic-link + Microsoft/Google SSO (time-boxed integration using Supabase OAuth providers).
- Organisation entity with member roles (participant, admin, author, super_admin).
- RLS policies to ensure data isolation per `org_id`.

### 4.2 Course Delivery Experience
- Course catalogue with metadata, modules (video/article/quiz/simulation placeholder), and localisation (Norwegian Bokmål + English).
- Course player with resumable progress, per-module completion, and quiz engine with pass/fail logic.
- Offline caching for mobile (limited to course assets & progress queue).

### 4.3 Assignments & Notifications
- Admin assignment flow with due dates and seat tracking.
- Email notifications for assignment creation and reminders at 7/3/1 days before due, plus expiry reminders.
- Dashboard to display to-do/in-progress/completed courses for participants.

### 4.4 Certificates & Audit Trail
- Automated certificate generation (PDF) via Edge Function after passing quiz requirements.
- Certificate metadata: participant details, course code, issuer, issue/expiry dates, QR verification link.
- Immutable audit logs for assignments, completions, score attempts, certificate issuance.

### 4.5 Reporting & Analytics
- Admin dashboard metrics: completion %, overdue count, time-to-complete, first-attempt pass rate.
- CSV export of completion report with filters (date range, course, status).
- PostHog event tracking for funnel analytics.

### 4.6 Billing & Plans
- Stripe integration for per-seat and per-course plans (checkout + webhooks for seat allocation).
- Manual invoicing workflow (generate invoice summary & mark as paid).

### 4.7 Admin CMS
- CRUD interfaces for courses, modules, quizzes with draft/publish lifecycle.
- Version history (store revision metadata per publish action).

### 4.8 Support & Help
- Contextual help sidebar, knowledge base links, contact form storing tickets in Supabase table.
- Status page placeholder linking to externally hosted status tool.

### 4.9 Nice-to-Haves (Time-boxed)
- Gamification (streaks, badges) toggled by feature flag.
- Practical training checklist module for blended learning sign-off.
- SCORM/xAPI import (read-only subset).
- Hybrid push notification wrapper for mobile (if time allows).

## 5. Technical Architecture
### 5.1 Frontend (Flutter Web + Mobile)
- Single Flutter project targeting web, iOS, Android.
- State management via Riverpod or Bloc; localisation using `intl` package.
- Offline caching with `hive` or `sqflite` for progress queue.
- Component structure:
  - `AuthGate` handles Supabase session.
  - `TenantGuard` enforces role-based routes.
  - `CoursePlayer` renders modules (video via player plugin, article markdown renderer, quiz widget).
  - `CertificateWallet` lists issued certificates and downloads PDFs.
  - Admin area components: `DashboardScreen`, `AssignmentsScreen`, `ReportTable`, `CourseEditor`.

### 5.2 Backend (Supabase)
- Postgres schema per provided model with additional tables:
  - `support_tickets`, `invoices`, `course_versions`, `reminder_queue`.
- Row-Level Security policies ensuring `org_members` scope.
- Supabase Storage buckets: `course-assets`, `certificates`.
- Edge Functions:
  1. `assignments-create`: validates seats, inserts assignments, triggers emails.
  2. `progress-update`: updates progress, calculates quiz attempts.
  3. `quiz-submit`: grades responses, logs attempts.
  4. `cert-issue`: renders HTML template to PDF using Deno/Chromium (Puppeteer-compatible library), stores file, returns URL.
  5. `billing-webhook`: processes Stripe events (checkout completed, subscription updates).
  6. `reports-export`: generates CSV asynchronously, stores in Storage, emails link.

### 5.3 Integrations
- **Email:** Supabase + Resend/SendGrid for transactional templates (assignment, reminders, certificate, passwordless magic link).
- **Payments:** Stripe Checkout + Billing Portal; manual invoice recorded in `invoices` table.
- **Analytics:** PostHog JS/Flutter SDK for frontend; server events via HTTP API.

### 5.4 Infrastructure & DevOps
- Supabase project (production + staging). Use Database migrations via Supabase CLI.
- Flutter CI/CD (GitHub Actions) building web (Firebase Hosting/Netlify) and mobile betas (TestFlight/Internal testing).
- Environment configuration using Supabase secrets + Flutter flavors (`dev`, `staging`, `prod`).
- Monitoring: Supabase logs, PostHog, Stripe dashboard. Set up error tracking (Sentry for Flutter & Edge Functions).

## 6. Security & Compliance
- Enforce TLS everywhere; Supabase-managed certificates.
- Apply RLS policies referencing authenticated user IDs.
- Audit logs immutable via `insert only` policy.
- Data retention policy aligning with Norwegian HSE requirements.
- GDPR considerations: consent for storing personal data (birth date optional), data export/delete tooling.
- Access logging and MFA for super admins (Supabase supports TOTP via Auth settings).

## 7. Implementation Roadmap (10 Weeks)
### Week 1–2: Foundation
- Set up Supabase project, schema migration, and auth flows.
- Implement `AuthGate`, onboarding, tenant creation, role management.
- Establish PostHog analytics baseline and Sentry integration.
- Deliver initial Flutter shell with navigation & localisation scaffolding.

### Week 3–4: Course Delivery
- Build course/catalog CRUD for authors, including localisation forms.
- Implement module player for video/article, quiz engine with scoring.
- Store progress, support resume, integrate offline caching for progress events.
- QA on multilingual toggle and responsive layouts.

### Week 5: Assignments & Notifications
- Admin assignment UI (select users, set due dates, seat validation).
- Edge function for assignment creation + email templates.
- Reminder scheduler using Supabase cron jobs (Edge Functions + pg_cron).
- Participant dashboard list with due status and reminders.

### Week 6: Certificates & Audit
- Implement quiz pass validation -> certificate issuance pipeline.
- Design PDF template and QR verification endpoint.
- Create audit log table, instrument all key actions.
- Participant certificate wallet download.

### Week 7: Reporting & Billing
- Admin dashboard metrics (Supabase materialized views or SQL queries).
- CSV export functionality with background job + email link.
- Integrate Stripe Checkout for seat purchases, store invoices, handle webhooks.
- Manual invoice workflow for offline billing.

### Week 8: CMS Polish & Support
- Enhance Course Editor with versioning, preview, and localisation diffing.
- Implement support contact form and route to `support_tickets`.
- Publish status page placeholder.
- Accessibility pass (WCAG AA), performance optimisations.

### Week 9: QA & Pilot Prep
- End-to-end testing (Cypress for web, Flutter integration tests for mobile).
- Seed pilot tenant, import initial content, run UAT with stakeholders.
- Penetration testing checklist, review RLS policies, backup procedures.

### Week 10: Launch & Handover
- Final bug bash, freeze critical paths.
- Prepare runbooks (incident response, support escalation).
- Deliver documentation for admin onboarding and content authoring.
- Launch marketing site updates & app store submissions (if mobile wrapper ready).

## 8. Resourcing
- **Product/Project Lead:** orchestrates backlog, stakeholder alignment.
- **Flutter Engineer (x2):** frontend feature delivery (participant + admin areas).
- **Backend/Full-stack Engineer:** Supabase schema, Edge Functions, integrations.
- **Content/Instructional Designer:** adapt courses, QA localisation.
- **QA Engineer (part-time from Week 6):** test automation, regression suites.
- **Design/UX (part-time):** UI system, accessibility review.

## 9. Risks & Mitigations
| Risk | Impact | Mitigation |
| --- | --- | --- |
| Video hosting costs spike | Budget overrun | Use Vimeo private links initially; monitor consumption, switch to CDN when scale justifies |
| RLS misconfiguration exposes data | Compliance breach | Automated tests for RLS policies, peer review of SQL, Supabase row-level tests |
| Certificate PDF generation latency | Poor UX | Queue certificates, show "Processing" state, optimise template rendering |
| Stripe webhook failures | Billing inaccuracies | Implement retry logic, alerting via Supabase Functions logs |
| Content localisation delays | Launch slip | Parallel content prep starting Week 3, translation memory tools |

## 10. Launch Checklist
- [ ] Production Supabase + Storage secured, backups enabled.
- [ ] Stripe live keys configured, test transactions verified.
- [ ] Email deliverability tested (SPF/DKIM, domain warm-up).
- [ ] All critical user journeys tested (assignment → completion → certificate → report → billing).
- [ ] Monitoring dashboards and alerts configured (PostHog, Sentry, Supabase logs).
- [ ] Support playbooks published (FAQ, escalation contacts).

## 11. Post-MVP Iteration Backlog
- Gamification layer with streak tracking and badge notifications.
- Practical training checklist module with supervisor sign-off.
- SCORM/xAPI import pipeline to ingest legacy content.
- Native wrapper for push notifications & offline certificate wallet.
- Advanced analytics (cohort retention, reminder effectiveness dashboards).

