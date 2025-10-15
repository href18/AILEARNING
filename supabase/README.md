# Supabase backend

This directory holds the schema, seed data, and edge functions required to run the compliance & safety training MVP on Supabase.

## Contents

- `migrations/20240601000000_init.sql` – baseline schema matching the MVP data model.
- `seed/seed_demo_course.sql` – inserts a demo tenant, admin/participant users, assignments, and a published **FSE-101** course with localised content.
- `functions/api` – Deno edge function that exposes aggregated course listings, participant dashboards, and quiz grading logic.

## Local development quickstart

```bash
supabase init
supabase start
supabase db push
supabase db seed --file supabase/seed/seed_demo_course.sql
supabase functions serve api --env-file supabase/.env.local
```

While `supabase functions serve` runs you can exercise the endpoints with curl:

```bash
curl -X POST "http://127.0.0.1:54321/functions/v1/api" \
  -H 'Content-Type: application/json' \
  -H 'x-edge-path: /courses' \
  -d '{"path":"/courses"}'
```

For quiz scoring:

```bash
curl -X POST "http://127.0.0.1:54321/functions/v1/api" \
  -H 'Content-Type: application/json' \
  -H 'x-edge-path: /quiz' \
  -d '{"path":"/quiz","module_id":"44444444-4444-4444-4444-444444444444","answers":{"66666666-6666-6666-6666-666666666661":["77777777-7777-7777-7777-777777777771"]}}'
```

To retrieve the participant "My Page" assignment summary:

```bash
curl -X POST "http://127.0.0.1:54321/functions/v1/api" \
  -H 'Content-Type: application/json' \
  -H 'x-edge-path: /me/assignments' \
  -d '{"path":"/me/assignments","user_id":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1"}'
```
