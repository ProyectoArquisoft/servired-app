# SERVI·RED — app del ciudadano

App Flutter (Android) de **SERVI·RED**, plataforma colaborativa de reporte y monitoreo de servicios
públicos domiciliarios en Colombia. El ciudadano reporta cortes, restablecimientos y conexiones
fraudulentas (de forma anónima), valida restablecimientos cercanos y consulta indicadores.

La app solo habla con el **API Gateway** (una URL base) y con **Supabase Auth**. El contrato de la
API es [`servired-infra/contracts/openapi/servired-public.yaml`](https://github.com/ProyectoArquisoft/servired-infra).

## Requisitos

- Flutter 3.44 (Dart 3.12) estable
- Android SDK (emulador o celular con depuración USB)
- Docker, para levantar el mock de la API desde `servired-infra`

## Puesta en marcha

```bash
# 1. Configuración local (no se sube a git)
cp config/dev.example.json config/dev.json   # y completa los valores

# 2. Mock de la API (desde servired-infra/compose)
docker compose --profile mock up              # http://localhost:4010

# 3. Dependencias y ejecución
flutter pub get
flutter run --dart-define-from-file=config/dev.json
```

### URL base según el dispositivo

| Dónde corre la app | `API_BASE_URL` |
|---|---|
| Emulador Android | `http://10.0.2.2:4010` (mock) o `http://10.0.2.2:8080` (gateway) |
| Celular físico, misma red | `http://<IP-local-del-PC>:4010` |
| Celular físico, fuera de la red | URL HTTPS del túnel |

El HTTP sin cifrar solo está permitido en compilaciones **debug**
(`android/app/src/debug/AndroidManifest.xml`); en release se exige HTTPS.

## Calidad

```bash
dart format lib test
flutter analyze
flutter test
```

La CI (`.github/workflows/ci.yml`) ejecuta formato, análisis, pruebas y `flutter build apk --release`,
y publica el APK como artefacto. Necesita los *secrets* `API_BASE_URL`, `SUPABASE_URL` y
`SUPABASE_ANON_KEY`.

> **Seguridad:** solo la `anon key` de Supabase va en la app. Nunca la `service_role key`.

## Estructura

```
lib/
├── main.dart, app.dart     # arranque, MaterialApp.router, tema, l10n
├── core/                   # config, red, almacenamiento, cola offline, router, tema
├── features/<feature>/     # data/ · domain/ · presentation/
├── shared/widgets/
└── l10n/                   # textos en ARB (es-CO por defecto)
```

Los textos visibles van en `lib/l10n/app_es.arb`; las clases `AppLocalizations` se generan con
`flutter gen-l10n` (o automáticamente con `flutter pub get`) y no se versionan.

## Avance

| Hito | Contenido | Estado |
|---|---|---|
| M0 | Proyecto base, lints, tema, router, l10n, CI | ✅ |
| M1 | Config, cliente HTTP, autenticación | ⏳ |
| M2 | Reportar corte (3 pasos) | ⏳ |
| M3 | Cola offline y sincronización | ⏳ |
| M4 | Mapa, detalle, mis reportes | ⏳ |
| M5 | Restablecimiento y validación comunitaria | ⏳ |
| M6 | Denuncia de fraude anónima | ⏳ |
| M7 | Indicadores | ⏳ |
| M8 | Pulido, accesibilidad, APK release | ⏳ |
