# 🗼 FrenchPass

> Aprende francés con la **palabra del día**, práctica de pronunciación por voz y repetición espaciada. Funciona completamente sin conexión.

---

## ✨ Estado de las features

| Feature | Estado |
|---|---|
| Palabra del día (determinista por fecha) | ✅ |
| Catálogo de 120 palabras · 10 categorías · A1–C2 | ✅ |
| Audio TTS en francés (palabra y frase) | ✅ |
| Práctica de pronunciación con reconocimiento de voz | ✅ |
| Score de pronunciación (claridad · acento · ritmo) | ✅ |
| SRS — repetición espaciada SM-2 | ✅ |
| Quiz de 4 modos (traducción ×2, audio, IPA) | ✅ |
| Historial, racha y gráficas de progreso | ✅ |
| Buscador y navegación por categoría/nivel | ✅ |
| Palabras guardadas | ✅ |
| Notificación diaria configurable | ✅ |
| Tema claro / oscuro / sistema | ✅ |
| Widget Android (pantalla de inicio) | 🔜 |
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
  en cualquier parte (incluido un futuro widget sin estado compartido).
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

---

## 🧪 Tests

```bash
flutter test     # 62 tests
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
| `lib/core/widgets/charts.dart` | Gráficas con `CustomPainter` |
| `lib/core/services/tts_service.dart` | Voz francesa, con degradación elegante |
| `lib/core/services/speech_service.dart` | Reconocimiento de voz y permisos |
| `lib/features/word_of_the_day/data/word_repository.dart` | Catálogo y palabra del día |
| `lib/features/progress/data/progress_repository.dart` | SRS, historial, racha |
| `lib/features/pronunciation/domain/usecases/pronunciation_scorer.dart` | Scoring de pronunciación |
| `lib/features/progress/domain/usecases/sm2_algorithm.dart` | Algoritmo SM-2 |
| `assets/data/words_seed.json` | Catálogo de 120 palabras |

---

## 📄 Documentación

Ver [`docs/`](docs/).

---

*Flutter 3.27 · Clean Architecture · BLoC/Cubit · go_router*
