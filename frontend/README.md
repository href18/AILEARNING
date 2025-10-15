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
