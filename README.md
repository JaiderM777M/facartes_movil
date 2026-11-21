# FACARTES Móvil
App Flutter (Material 3) con Supabase (Auth, Postgres, Storage). La IA se conecta en la Fase 2.

## Configuración
1. Crea un proyecto en supabase.com y ejecuta `supabase/schema.sql` en **SQL Editor**.
2. En **Authentication → Providers → Email**, desactiva *Confirm email* (para desarrollo).
3. Copia `env.example.json` a `env.json` y pon tu URL y anon key (Project Settings → API). `env.json` NO se sube a Git.
4. `flutter pub get`
5. `flutter run -d <dispositivo> --dart-define-from-file=env.json`

## Estructura
- `lib/core.dart`: tema, modelo `Artwork`, widgets comunes
- `lib/services/repo.dart`: acceso a datos (Supabase)
- `lib/services/ai_service.dart`: IA (simulada; Fase 2 = Gemini)
- `lib/screens/`: pantallas
