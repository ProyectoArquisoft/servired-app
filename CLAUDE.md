# Brief para Claude: repo `Servired-app`

> No tienes acceso al documento original del proyecto (SAD); todo lo que necesitas está aquí. Si algo falta o se contradice, **pregunta antes de inventar**.

---

## 1. Contexto del proyecto

**SERVI·RED** es una plataforma colaborativa de reporte y monitoreo de servicios públicos domiciliarios en Colombia (acueducto, energía, gas, aseo, etc.). Proyecto del curso *Arquitectura de Software* (Pontificia Universidad Javeriana, equipo de 3 personas).

Los ciudadanos reportan cortes, restablecimientos y conexiones fraudulentas; el sistema valida, calcula indicadores de continuidad y los expone. Este repo es **la app del ciudadano**.

### Arquitectura (lo que necesitas saber)

```
App Flutter ──HTTPS──▶ API Gateway (:8080) ──▶ Reportes | Moderación | Indicadores
                              │                       (microservicios, cada uno con su BD)
                              └─ valida el JWT (Supabase Auth)
Evidencia (fotos): la sube Reportes a Supabase Storage. La app NO habla con Storage.
```

- La app **solo habla con el gateway** (una única URL base) y con **Supabase Auth** (login/registro).
- Repos hermanos: `servired-infra` (contratos OpenAPI + eventos, compose, mock), `servired-gateway`, `servired-reportes`, `servired-moderacion`, `servired-indicadores`.
- **No hay panel web.** Las funciones de operador/regulador no están en esta app: se exponen solo por API.

### Fuente de verdad de la API

`servired-infra/contracts/openapi/servired-public.yaml`. **Tu código debe coincidir con ese contrato.** Si el contrato aún no existe o difiere de lo que necesitas, **detente y avísame**; no inventes endpoints. Mientras el backend no exista, desarrolla contra el **mock** (Prism) que levanta `servired-infra` con `docker compose --profile mock up` (puerto 4010).

---

## 2. Alcance

**Dentro:**
- RF1 Reportar corte no programado (foto, geolocalización, tipo de servicio).
- RF2 Reportar restablecimiento.
- RF3 Validar comunitariamente un restablecimiento.
- RF4 Reportar conexión fraudulenta **de forma anónima** (RF5, la moderación, ocurre en el backend; la app muestra el resultado).
- RF6 (solo lectura) Mapa de reportes.
- RF9 Consultar indicadores públicos.
- Registro/login/logout, "Mis reportes", cola offline.

**Fuera (no lo construyas):** panel web, vistas de operador/regulador (gestionar, cerrar, exportar), notificaciones push, reportes por voz, gamificación, soporte iOS (que no se rompa la compilación, pero no es prioridad).

---

## 3. Requisitos no funcionales (vienen del SAD y son criterio de aceptación)

| Atributo | Requisito |
|---|---|
| Usabilidad / accesibilidad | Un usuario con bajo nivel digital completa un reporte en **≤ 3 pasos**. Botones grandes, lenguaje simple |
| Rendimiento | Reportar un corte: geolocaliza y confirma recepción en **< 3 s** (con red) |
| Conectividad limitada (rural/periurbana) | **Modo offline real**: el reporte se guarda en el dispositivo y se sincroniza solo al volver la señal, con indicador visible "Pendiente por enviar" |
| Bajo consumo de datos | Comprimir fotos antes de enviar, paginar, sin *polling* agresivo |
| Privacidad | El reporte de fraude **no envía ninguna identidad** (ver §6) |
| Seguridad | Nunca incluir la `service_role key` de Supabase en la app. Solo la `anon key` (pública por diseño). No registrar tokens en logs |

---

## 4. Stack

- **Flutter** estable (Dart 3), Android como objetivo principal.
- Estado: **Riverpod**. Navegación: **go_router**. HTTP: **dio**.
- Auth: **supabase_flutter** (solo Auth; no usar su cliente de BD ni Storage).
- Mapas: **flutter_map** + **latlong2** con teselas de OpenStreetMap (configura `userAgentPackageName`; respeta la política de uso de OSM).
- Ubicación: **geolocator**. Cámara/galería: **image_picker**. Compresión: **flutter_image_compress**.
- Conectividad: **connectivity_plus**. Almacenamiento local de la cola: **sqflite** (SQLite).
- Modelos: `json_serializable` (DTOs escritos a mano alineados con el contrato).
- Textos: `flutter_localizations` + archivos ARB, idioma por defecto `es-CO` (deja todo en ARB para poder traducir luego).
- Calidad: `flutter_lints`, `flutter analyze` sin advertencias.

### Estructura sugerida (feature-first)

```
lib/
├── main.dart
├── app.dart                     # MaterialApp.router, tema, l10n
├── core/
│   ├── config/                  # AppConfig leyendo --dart-define
│   ├── network/                 # dio, interceptores, mapeo de errores problem+json
│   ├── storage/                 # base sqflite
│   ├── offline/                 # cola de peticiones pendientes y sincronizador
│   ├── location/ , media/       # servicios de GPS y fotos
│   └── theme/ , router/
├── features/
│   ├── auth/
│   ├── reports/                 # crear corte, restablecimiento, mis reportes, detalle
│   ├── validation/              # validar restablecimientos cercanos
│   ├── fraud/                   # denuncia anónima
│   ├── map/
│   └── indicators/
└── shared/widgets/
```

Cada *feature* con `data/` (repositorios, DTOs), `domain/` (modelos) y `presentation/` (pantallas, controladores Riverpod). Mantén la capa liviana, sin sobreingeniería.

---

## 5. Pantallas y flujos

1. **Login / Registro** (Supabase Auth, email + contraseña). Sesión persistente. El rol por defecto es `CIUDADANO`.
2. **Inicio:** dos botones grandes ("Reportar un corte", "Ya volvió el servicio"), acceso a Mapa, Indicadores, Mis reportes y "Denunciar conexión fraudulenta" (esta última **sin requerir login**).
3. **Reportar corte, 3 pasos:**
   1. Tipo de servicio (catálogo de `GET /api/servicios`; cachéalo localmente para usarlo offline).
   2. Foto (opcional) + ubicación automática, con opción de ajustarla en el mapa. Severidad opcional (baja/media/alta).
   3. Descripción opcional + enviar. Confirmación con el **código de trazabilidad**. Si no hay red, encola y muestra "Pendiente por enviar".
4. **Restablecimiento:** elegir uno de *Mis reportes* abiertos → confirmar → `POST /api/reportes/{id}/restablecimiento`.
5. **Validar restablecimiento:** lista/mapa de restablecimientos **cercanos** (radio propuesto 500 m, configurable) que aún faltan por validar → "Confirmo que ya hay servicio" → `POST /api/reportes/{id}/validaciones`. Manejar `409` (ya validaste).
6. **Denuncia de fraude anónima** (ver §6).
7. **Mapa:** reportes activos dentro del área visible (`bbox`), marcadores por tipo de servicio, toque → detalle. Refresca al mover el mapa, con *debounce*.
8. **Indicadores:** filtros (servicio, departamento, municipio, periodo) y tarjetas con horas promedio de interrupción y frecuencia de cortes.
9. **Mis reportes:** lista con chips de estado, incluido "Pendiente por enviar" para lo que está en cola.

---

## 6. Reglas críticas

### Anonimato en fraude (no negociable)
- `POST /api/fraudes` se llama **sin header `Authorization`** y **sin ningún identificador** de usuario, dispositivo ni instalación. Si envías `Idempotency-Key`, que sea un UUID aleatorio nuevo por denuncia, nunca derivado de la cuenta ni del dispositivo.
- No guardar en local nada que vincule la denuncia con la cuenta. No registrar el contenido de esa petición en logs.
- No adjuntar fotos en fraudes (el contrato no las incluye).
- Mostrar el resultado: `APROBADO`, `RECHAZADO` o `PENDIENTE_REVISION`, con texto claro.
- Puedes encolar la denuncia offline, pero sin metadatos de cuenta.

### Cola offline e idempotencia
- Tabla `pending_requests(id, idempotency_key, type, payload_json, file_path, created_at, attempts, last_error, status)`.
- Cada petición encolada lleva un **UUID `Idempotency-Key`** generado al crearla y reutilizado en cada reintento (así el backend no duplica reportes).
- Sincroniza al recuperar conectividad, al volver la app al primer plano y con *pull-to-refresh*.
- Reintentos con *backoff* exponencial. `5xx`/timeout/sin red → reintentar. `4xx` (excepto 408 y 429) → marcar como rechazada, avisar al usuario y no reintentar.
- Comprime la foto **antes** de encolarla (lado mayor ≤ 1280 px, JPEG calidad ~70, objetivo < 500 KB; el backend admite hasta 2 MB) y quítale el EXIF.

### Red y errores
- `dio`: *timeouts* de 10 s (conexión) y 20 s (respuesta); interceptor que añade el `Bearer` (y refresca la sesión), interceptor de `Idempotency-Key`, y un mapeo de `application/problem+json` a errores de dominio con mensajes en español.
- Configuración por `--dart-define-from-file=config/dev.json` (ignorado por git; sube `config/dev.example.json`) con `API_BASE_URL`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`.
- Emulador Android: el PC es `http://10.0.2.2:<puerto>`. Celular físico: IP local del PC o la URL HTTPS del túnel. HTTP sin cifrar solo en **debug** (manifiesto `debug`/network security config), nunca en release.

### Android
- Permisos: `INTERNET`, `ACCESS_NETWORK_STATE`, `ACCESS_FINE_LOCATION`, `CAMERA`. Pide ubicación y cámara **en contexto**, con una explicación breve antes del diálogo del sistema, y maneja la negación de forma amable (permitir elegir la ubicación a mano).
- `applicationId`: `com.servired.mobile`.

### Accesibilidad
- Áreas táctiles ≥ 48 dp, buen contraste, etiquetas `Semantics`, soporte de texto agrandado (hasta ×1.5–2 sin romper el diseño). El dictado por voz del teclado ya sirve para el campo de descripción (no hace falta un módulo de voz propio).

---

## 7. Pruebas y CI

- **Obligatorias:** pruebas unitarias de la cola offline (encolar, reintento, *backoff*, descarte por 4xx), del mapeo de errores y de los repositorios (con `dio` simulado); pruebas de *widget* del flujo de 3 pasos.
- CI: `.github/workflows/ci.yml` → formato, `flutter analyze`, `flutter test`, `flutter build apk --release` y subida del APK como artefacto. Los valores de `--dart-define` van como *secrets* de GitHub.

---

## 8. Hitos y criterios de aceptación

| Hito | Entrega | Aceptación |
|---|---|---|
| **M0** | Proyecto base: `flutter create` (org `com.servired`), estructura, lints, tema, router, l10n `es-CO`, README, CI | `flutter analyze` y `flutter test` pasan; CI verde |
| **M1** | Config por `dart-define`, cliente `dio`, Auth (registro/login/logout, sesión persistente) | Login contra Supabase; el token se envía al mock/gateway |
| **M2** | Reportar corte (3 pasos) online contra el **mock** | Reporte creado, muestra código de trazabilidad, < 3 s |
| **M3** | Cola offline + chip "Pendiente por enviar" + sincronización | En modo avión se encola; al reconectar se envía **una sola vez** (idempotencia) |
| **M4** | Mapa + detalle + Mis reportes | Marcadores por `bbox`, detalle con evidencia |
| **M5** | Restablecimiento + validación comunitaria cercana | Maneja `409`; respeta el radio |
| **M6** | Denuncia de fraude anónima | Verificado con el inspector de red: **sin** `Authorization` ni identificadores |
| **M7** | Indicadores con filtros | Datos del mock y luego del backend real |
| **M8** | Pulido: accesibilidad, rendimiento, APK *release*, guion de demo y video de respaldo | Cumple la tabla de §3 |

---

## 9. Reglas de trabajo

- **Los commits, pushes y PR los hace el usuario.** Claude solo modifica el árbol de trabajo y, al terminar cada hito, resume los cambios y propone un mensaje de commit convencional.
- No modifiques otros repos ni el contrato. Si necesitas un cambio de API, descríbelo (endpoint, campos, motivo) y se gestiona en `servired-infra`.
- Ningún secreto en git (`config/dev.json`, keystores, `.env`). Si ves uno, detente y avisa.
- Documentación en español; commits convencionales; ramas + PR (`main` protegida).
- No agregues paquetes fuera de este brief sin preguntar.

---

## 10. Decisiones tomadas a partir del contrato (v0.1.0)

1. **Severidad:** opcional (`BAJA|MEDIA|ALTA`), en el paso 2. `magnitudAreaAfectada` y `tiempoInicioEstimado` existen en el contrato pero no se piden, para respetar los 3 pasos.
2. **Validación cercana:** no hay endpoint de "cercanos". Se usa `GET /api/reportes?estado=RESTABLECIMIENTO_REPORTADO&bbox=…` con un bbox calculado del radio (500 m, configurable) y se filtra por distancia en el cliente. El número requerido sale de `validacionesRequeridas` (no se fija en código). Se manejan `409` (ya validó o es el autor) y `422` (fuera de radio).
3. **Íconos/colores por servicio:** el catálogo no los trae; la app los define por `TipoServicio`.
4. **Mis reportes abiertos:** `GET /api/reportes?mios=true` y filtro de `ACTIVO`/`EN_ATENCION` en el cliente (el parámetro `estado` admite un solo valor).
5. **Rol `CIUDADANO`:** viaja en `app_metadata.rol`, que el cliente no puede escribir; lo asigna Supabase/infra.
6. **Localizaciones:** `lib/l10n/app_es.arb` es la plantilla; `app_localizations*.dart` se generan y no se versionan.
