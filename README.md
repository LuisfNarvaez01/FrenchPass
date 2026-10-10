# 🗼 FrenchPass

> Aprende francés con la **palabra del día**, práctica de pronunciación por voz y repetición espaciada. Funciona completamente sin conexión.

---

## ✨ Estado de las features

| Feature | Estado |
|---|---|
| Palabra del día (determinista por fecha) | ✅ |
| Catálogo de 196 palabras · 11 categorías (incluye conversación) · A1–C2 | ✅ |
| Audio TTS en francés (palabra y frase) | ✅ |
| Práctica de pronunciación con reconocimiento de voz | ✅ |
| Score de pronunciación (claridad · acento · ritmo) | ✅ |
| SRS — repetición espaciada SM-2 | ✅ |
| Quiz de 4 modos (traducción ×2, audio, IPA) | ✅ |
| Historial, racha y gráficas de progreso | ✅ |
| Buscador y navegación por categoría/nivel | ✅ |
| Palabras guardadas | ✅ |
| Notificación diaria configurable | ✅ |
| Actualización en la app (CI + GitHub Releases) | ✅ |
| "Otra palabra" + escucha palabra por palabra | ✅ |
| Tema claro / oscuro / sistema | ✅ |
| Widget Android (pantalla de inicio) | ✅ |
| Soporte iOS | 🔜 |

---

## 🏗️ Arquitectura

```
Clean Architecture + Feature-First
├── core/
│   ├── di/           → Inyección de dependencias (get_it)
│   ├── router/       → Navegación (go_router)
│   ├── services/     → TTS, STT, almacenamiento, notificaciones
│   ├── theme/        → Design system (AppPalette + AppTheme)
│   └── widgets/      → Componentes compartidos y gráficas
└── features/
    ├── word_of_the_day/   → Entidad Word, repositorio del catálogo, home
    ├── pronunciation/     → STT, scoring, práctica y resultado
    ├── quiz/              → Preguntas, sesión y resumen
    ├── progress/          → SM-2, repositorio de progreso, estadísticas
    ├── categories/        → Catálogo, buscador y listados
    └── settings/          → Tema, nivel, voz, recordatorio
```

### Persistencia

El catálogo es un asset de solo lectura (`assets/data/words_seed.json`), así que
el único estado persistido es el progreso del usuario: tarjetas SRS, historial
de intentos, palabras guardadas y calendario de estudio. Todo eso vive como
documentos JSON pequeños en `shared_preferences` — no hace falta una base de
datos relacional, y la app arranca sin esperar I/O.

### Decisiones de diseño

- **`AppPalette` como `ThemeExtension`** en lugar de una `extension on ColorScheme`:
  cada token se resuelve por brillo, así que el tema claro no hereda superficies
  oscuras.
- **La palabra del día es una función pura de la fecha.** Rota sobre una
  permutación fija, de modo que cualquier ventana de N días consecutivos cubre
  el catálogo entero exactamente una vez, y el mismo día da el mismo resultado
  en cualquier parte — incluido el widget de pantalla de inicio, que no
  recomputa nada: solo pinta lo último que la app le escribió.
- **Las gráficas de progreso son de una sola serie** y el título las nombra, así
  que no necesitan leyenda. La magnitud se codifica con longitud de barra más un
  paso de una rampa de un solo tono (validada: luminosidad monótona, ΔL ≥ 0.06,
  extremo claro ≥ 2:1 contra la superficie en ambos modos).
- **Los colores de estado nunca van solos.** El par bueno/crítico es
  indistinguible bajo deuteranopía (ΔE 3.5), así que siempre se acompañan de
  icono y etiqueta de texto.

---

## 🎨 Design System

**Estilo**: Parisino elegante — fondo cálido oscuro, dorado, terracota.

| Token | Oscuro | Claro |
|---|---|---|
| Fondo | `#14110D` | `#FAF6EF` |
| Superficie | `#1F1A14` | `#FFFFFF` |
| Dorado | `#C49A3C` | `#8B6520` |
| Terracota | `#C0693F` | `#9A4A22` |
| Texto | `#F2EDE3` | `#2E2720` |

**Tipografía**: Playfair Display (palabras FR y títulos) · Lato (UI) · Crimson Pro (IPA)

---

## 🚀 Setup

```bash
flutter pub get
flutter run

# APK de release firmado
flutter build apk --release
```

### Requisitos de Android

La cadena de build es sensible a las versiones. Estas cuatro restricciones son
las que hacen que compile, y cada una se descubrió con un build roto:

- **minSdk 24** — lo imponen los plugins de audio.
- **AGP 8.6.0 / Gradle 8.7 / Kotlin 2.0.21.** AGP 8.1.x revienta en el
  transform de `jdkImage` al compilar con JDK 21
  ([issue 294137077](https://issuetracker.google.com/issues/294137077)).
- **`flutter_tts` fijado a 4.1.0, sin `^`.** La 4.2.x declara Kotlin 2.2.20 y
  AGP 8.13, por encima de lo que soporta Flutter 3.27, y su fuente hace caer el
  frontend K2 de Kotlin 2.0.x con `IllegalArgumentException: source must not be
  null`. Al subir Flutter se puede quitar el pin.
- **Desugaring de `coreLibraryDesugaring` activado** — lo necesita
  `flutter_local_notifications` para el backport de `java.time` por debajo de
  API 26.

Además:

- La firma de release se lee de `android/key.properties`; si el archivo no
  existe, el build cae a las claves de debug.
- El TTS y el reconocimiento de voz necesitan las `<queries>` del manifest
  (Android 11+) o quedan invisibles para la app.

### Lo que necesita el dispositivo

- Una **voz francesa** instalada (Ajustes de Android › Idiomas › Texto a voz).
  La app lo detecta y lo avisa en lugar de fallar en silencio.
- **Reconocimiento de voz** con permiso de micrófono para la práctica de
  pronunciación.

### Widget de pantalla de inicio

Mantén presionada la pantalla de inicio → *Widgets* → **FrenchPass** →
arrastra el widget "Palabra del día". Muestra la palabra, su IPA y la
traducción, y tocarlo abre la app. Se actualiza cada vez que la app calcula
la palabra del día (al abrir la pestaña "Hoy" o al iniciar la app) — es un
`RemoteViews` clásico (`WordOfTheDayWidgetProvider.kt`) que solo pinta lo que
Flutter le escribió vía `home_widget`; no recalcula nada por su cuenta, así
que el valor puede quedarse un día atrasado si la app no se abre, igual que
cualquier widget de clima.

---

## 🔄 Actualizaciones automáticas

Cada push a `main` dispara `.github/workflows/release.yml`, que compila,
corre `analyze`/`test`, y publica una GitHub Release etiquetada con la
versión de `pubspec.yaml` (`vX.Y.Z`). La app, al abrir cualquier pantalla con
la barra de navegación, revisa en segundo plano si esa release es más nueva
que la instalada; si lo es, ofrece un diálogo para **descargar e instalar
sola** — el único paso manual que queda es la confirmación del instalador de
Android, que el sistema no deja automatizar para una app fuera de la Play
Store.

**Configuración única (ya no se repite):** la release debe firmarse con la
*misma* clave que ya está instalada en los teléfonos de prueba, o Android
rechazará la actualización por firma distinta y pedirá desinstalar primero.
Hay que cargar esa clave como secretos del repo:

1. En GitHub → *Settings → Secrets and variables → Actions → New repository
   secret*, crea estos cuatro:
   - `KEYSTORE_BASE64` — contenido de `keystore_base64_for_github_secret.txt`
     (generado junto al keystore local, ignorado por git; bórralo del disco
     una vez cargado el secreto).
   - `KEYSTORE_PASSWORD`, `KEY_PASSWORD`, `KEY_ALIAS` — los mismos valores de
     `android/key.properties`.
2. Pushea a `main`. La Action compila, firma y publica la release.
3. Abre la app en el teléfono que ya tiene la versión anterior instalada: en
   un momento debería aparecer el aviso de actualización.

Si alguna vez se pierde o rota la clave de firma, hay que desinstalar la app
de cada dispositivo de prueba antes de poder instalar una build firmada con
una clave nueva — no hay forma de evitarlo, es una restricción de Android.

---

## 🧪 Tests

```bash
flutter test     # 69 tests
flutter analyze  # sin issues
```

Cubren el algoritmo SM-2, el scorer de pronunciación (incluido el orden de los
dígrafos franceses y las consonantes finales mudas), el parseo y la integridad
del catálogo, la rotación de la palabra del día, y el repositorio de progreso
(racha, agregados y recuperación ante datos corruptos).

---

## 📁 Archivos clave

| Archivo | Propósito |
|---|---|
| `lib/core/theme/app_palette.dart` | Tokens de color, espaciado y radios |
| `lib/core/theme/app_theme.dart` | Temas claro y oscuro, escala tipográfica |
| `lib/core/services/widget_service.dart` | Publica la palabra del día al widget |
| `android/.../WordOfTheDayWidgetProvider.kt` | Widget nativo (RemoteViews) |
| `lib/core/services/update_service.dart` | Chequeo de actualizaciones (GitHub Releases) |
| `lib/core/widgets/charts.dart` | Gráficas con `CustomPainter` |
| `lib/core/services/tts_service.dart` | Voz francesa, con degradación elegante |
| `lib/core/services/speech_service.dart` | Reconocimiento de voz y permisos |
| `lib/features/word_of_the_day/data/word_repository.dart` | Catálogo y palabra del día |
| `lib/features/progress/data/progress_repository.dart` | SRS, historial, racha |
| `lib/features/pronunciation/domain/usecases/pronunciation_scorer.dart` | Scoring de pronunciación |
| `lib/features/progress/domain/usecases/sm2_algorithm.dart` | Algoritmo SM-2 |
| `assets/data/words_seed.json` | Catálogo de 196 palabras |

---

## 📄 Documentación

Ver [`docs/`](docs/).

---

*Flutter 3.27 · Clean Architecture · BLoC/Cubit · go_router*
