# AI Learning Marketplace

Multi-tenant Flutter + Supabase marketplace for selling courses, managing enrollments, enforcing prerequisites, tracking progress, and issuing certificates with signed webhooks.

## Environment configuration

Create a `.env` (Flutter) or export variables with the following values:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY` (for Edge Functions and local tooling)
- `STRIPE_SECRET_KEY`
- `STRIPE_PUBLISHABLE_KEY`
- `STRIPE_WEBHOOK_SECRET`
- `CERTIFICATE_FUNCTION_SECRET`

## Database setup

1. Install the Supabase CLI and start local services:
   ```bash
   supabase start
   ```
2. Run migrations and seed data:
   ```bash
   supabase db reset
   supabase db push
   supabase db seed
   ```
   The migration file `supabase/migrations/001_marketplace.sql` defines all tables, views, RLS policies, triggers, and RPCs. The seed adds demo users, courses, and webhook endpoint.

## Edge Functions

Deploy or serve the Edge Functions with the Supabase CLI:

```bash
supabase functions deploy dispatch-webhooks
supabase functions deploy stripe-webhook
supabase functions deploy issue-certificate
```

- **dispatch-webhooks**: Scheduled every minute to deliver signed webhooks with HMAC-SHA256 signatures and idempotency keys.
- **stripe-webhook**: Validates Stripe signatures, persists purchases, enrolls learners via the `enroll_in_course` RPC, and handles refunds/failures.
- **issue-certificate**: Generates PDFs via `pdf-lib`, uploads to Supabase Storage (`certificates` bucket), and updates certificate URLs. Protect with `CERTIFICATE_FUNCTION_SECRET` or call internally.

### Scheduled function

Supabase automatically uses the exported `schedule` metadata; configure a cron of `* * * * *` for `dispatch-webhooks`.

## Stripe integration

1. Configure Stripe products/prices and set Checkout session metadata to include `user_id` and `course_id`.
2. Point the Stripe webhook endpoint to the deployed Supabase Function URL and set the signing secret.
3. The Flutter app starts Checkout by invoking the `create-checkout-session` Edge Function (implement to create a Stripe Checkout session that redirects back to the app).

## Flutter application

### Dependencies

Add to `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.3.6
  go_router: ^10.0.0
  supabase_flutter: ^2.0.0
  url_launcher: ^6.1.10
  common:
    path: ../packages/common

dev_dependencies:
  flutter_test:
    sdk: flutter
```

### Running locally

```bash
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
flutter run
```

The app uses `go_router` with tabs for Explore, My Learning, Certificates, and Creator Dashboard (creators/admins only). Authentication uses Supabase email/password.

Deep link callbacks (e.g., `app://success`) should be wired via `uni_links`/`firebase_dynamic_links` or platform-specific URL handlers to refresh purchases after Checkout.

### Code generation

Models under `packages/common/lib/models` are hand-written but compatible with future `freezed`/`json_serializable` migration. Running `build_runner` is optional today but recommended if you add annotations.

## Workflow summary

1. Visitors explore published courses (public RLS).
2. Checkout uses Stripe; the webhook records the purchase and server-enrolls the learner via RPC.
3. Learners progress through lessons via the `complete_lesson` RPC. Module/course completion events enqueue signed webhooks; course completion issues certificates.
4. Creators manage course content, pricing, analytics, and webhook endpoints inside the Creator Dashboard.

## Testing plan

1. **Database:** run migrations and seed; verify RLS by attempting cross-tenant queries.
2. **Edge Functions:** use `supabase functions serve stripe-webhook --env-file .env` and send Stripe CLI test events (`stripe listen --forward-to ...`). Confirm purchases and enrollments update.
3. **Flutter:** use test users from seed. Purchase a course in Stripe test mode, ensure enrollment appears in My Learning.
4. Complete lessons inside the app; verify module/course completion status, generated certificate, and that `dispatch-webhooks` delivers signed events.
5. Configure a webhook consumer (see below) to assert HMAC verification.

## Sample webhook consumer

Node.js example validating signatures:

```js
import crypto from 'crypto';
import express from 'express';

const app = express();
app.use(express.json({ verify: (req, _, buf) => { req.rawBody = buf; } }));

app.post('/webhooks', (req, res) => {
  const signature = req.header('X-Webhook-Signature');
  const secret = process.env.WEBHOOK_SECRET;
  const payload = req.rawBody;
  const digest = crypto.createHmac('sha256', secret).update(payload).digest('hex');
  if (digest !== signature) {
    return res.status(400).send('Invalid signature');
  }
  console.log('Event', req.body);
  res.sendStatus(200);
});

app.listen(3000);
```

Python example:

```python
import hmac
import hashlib
from flask import Flask, request

app = Flask(__name__)
SECRET = b"your-endpoint-secret"

@app.post('/webhooks')
def webhook():
    signature = request.headers.get('X-Webhook-Signature', '')
    computed = hmac.new(SECRET, request.get_data(), hashlib.sha256).hexdigest()
    if not hmac.compare_digest(signature, computed):
        return 'invalid signature', 400
    print(request.json)
    return '', 200

app.run(port=3000)
```

## Nice-to-haves

The migration includes schema stubs for coupons, bundles, reviews, learning paths, reminders, and organizations/seats for future expansion.
