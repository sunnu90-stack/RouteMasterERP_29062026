@echo off
echo Starting NavGati ERP with configured keys...
if not defined GEMINI_API_KEY if not defined GROQ_API_KEY if not defined SARVAM_API_KEY if not defined OPENROUTER_API_KEY echo No AI keys found; live providers may be unavailable. Configure an API key in the environment.
flutter run --dart-define=ADMIN_PIN=%ADMIN_PIN% --dart-define=MAPS_KEY=%MAPS_KEY% --dart-define=GEMINI_API_KEY=%GEMINI_API_KEY% --dart-define=GROQ_API_KEY=%GROQ_API_KEY% --dart-define=SARVAM_API_KEY=%SARVAM_API_KEY% --dart-define=OPENROUTER_API_KEY=%OPENROUTER_API_KEY%
pause
