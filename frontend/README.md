# Flutter demo client

This Flutter app demonstrates the course catalog and player experience for the compliance & safety training MVP. It connects directly to Supabase for data retrieval and uses the edge function for quiz grading.

## Running locally

```bash
flutter pub get
flutter run -d chrome \
  --dart-define=SUPABASE_URL="https://your-project.supabase.co" \
  --dart-define=SUPABASE_ANON_KEY="your-anon-key"
```

The default locale is Norwegian Bokmål (`nb`). Update the device/browser locale to switch between Norwegian and English seeded content.

`lib/supabase_options.dart` ships with the demo project's public configuration baked in, so you can run the app without supplying any extra flags. Provide your own Supabase project credentials via the `--dart-define` overrides shown above when targeting another backend.

## Authentication

The catalog now requires a Supabase email/password account. Create users from the Supabase Dashboard (Authentication → Users) or via the Admin API. The login screen also supports self-service registration using Supabase Auth; depending on your project policy, users may need to confirm their email before signing in. After authentication the catalog and course player become available. Use the "Sign out" action in the catalog app bar to switch accounts.

### Features

- Responsive catalog grid with subtle entry animations
- Module player that supports video placeholders, markdown articles, interactive simulation steps, and quizzes
- Quiz grading with real-time feedback and retry support

### Production build

```bash
flutter build web \
  --dart-define=SUPABASE_URL="https://your-project.supabase.co" \
  --dart-define=SUPABASE_ANON_KEY="your-anon-key"
```
