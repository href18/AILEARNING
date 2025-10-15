# AILEARNING Compliance Training Platform

This repository contains the Supabase + Flutter implementation of the compliance & safety training MVP. It ships with:

- **Supabase backend** schema, demo seed data, and edge function for aggregated course listings, quiz scoring, and assignment dashboards (`supabase/`).
- **Flutter web/mobile client** that consumes Supabase directly, renders modules with animations, surfaces a participant "My Page" progress view, and supports quiz submission (`frontend/`).
- **Documentation** describing the product blueprint and delivery plan (`docs/`).

## Prerequisites

- [Supabase CLI](https://supabase.com/docs/guides/cli) v1.150+
- Flutter 3.16+ with the web toolchain enabled
- Node 18+ (for Supabase edge function bundling)

## Bootstrapping Supabase locally

```bash
supabase init
supabase db reset --db-url "postgresql://postgres:postgres@127.0.0.1:54322/postgres" \
  --linked
supabase db push  # applies migrations/supabase/migrations
supabase db remote commit  # optional if you want migrations generated remotely
supabase db seed --file supabase/seed/seed_demo_course.sql
supabase functions deploy api
```

> ℹ️ The seed file provisions a published **FSE-101** course with video, article, simulation, and quiz modules plus demo admin/participant accounts. The participant user has two assignments so you can explore the new progress dashboard immediately.

To run the Supabase stack locally with Docker containers:

```bash
supabase start
```

Once the stack is up you can call the edge function from curl:

```bash
supabase functions invoke api --no-verify-jwt --data '{"path":"/courses"}'

# Fetch the participant dashboard (replace user_id if you seeded different data)
supabase functions invoke api --no-verify-jwt --data '{"path":"/me/assignments","user_id":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1"}'
```

## Running the Flutter demo client

1. Update `frontend/lib/supabase_options.dart` with your Supabase project URL and anon key. For local development you can export them as environment variables when running Flutter:

   ```bash
   flutter run -d chrome \
     --dart-define=SUPABASE_URL="http://127.0.0.1:54321" \
     --dart-define=SUPABASE_ANON_KEY="your-anon-key"
   ```

2. Install dependencies and launch:

   ```bash
   cd frontend
   flutter pub get
   flutter run -d chrome
   ```

   The catalog screen will load the seeded **FSE-101** course. Open the course to experience:

   - Animated module transitions
   - A scenario simulation widget with stepper animation
   - Quiz submission with instant feedback powered by the edge function
   - A "My Page" dashboard (tap the profile icon) that shows assignment status, progress, and demo certificate links

To build a production web bundle:

```bash
flutter build web --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

## Folder structure

```
.
├── README.md
├── docs/
├── frontend/            # Flutter application source
│   ├── lib/
│   └── pubspec.yaml
└── supabase/            # SQL migrations, seeds, edge functions
    ├── functions/api
    ├── migrations
    └── seed
```

## Next steps

- Implement remaining Supabase Row Level Security policies for tenancy isolation
- Expand edge functions to handle certificate PDF generation and more advanced reporting workflows
- Add CI/CD automation for Flutter builds and Supabase migrations
