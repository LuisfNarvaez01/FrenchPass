# FrenchPass — Plan de Implementación

> **Estado al 2026-10-10.** Este documento es el plan original. Lo que ya está
> construido y lo que sigue pendiente está en la tabla de features del
> [README](../README.md), que es la fuente de verdad. Resumen de divergencias
> frente a lo planeado aquí:
>
> | Planeado | Realidad |
> |---|---|
> | Widget de pantalla de inicio en MVP | 🔜 pendiente — es lo único grande que falta |
> | Persistencia con Drift/SQLite | `shared_preferences`; ver ADR-009 en [technical_docs](technical_docs.md) |
> | Dataset de 500 palabras | 120 palabras curadas, cubriendo las 10 categorías y A1–C2 |
> | Multilingüe ES/EN/FR de la interfaz | los locales están declarados y el dataset trae ES+EN, pero los textos de la UI están en español; falta extraer a ARB |
> | Quiz "de pronunciación" | quiz de 4 modos (traducción ×2, audio, IPA); la pronunciación se evalúa en su propia pantalla |
> | `injectable` para DI | registro manual con `get_it` |

## Descripción del Proyecto

**FrenchPass** es una app móvil cross-platform (Flutter, Android + iOS) para el aprendizaje de vocabulario en francés. El concepto central es una *palabra del día* que el usuario puede ver, escuchar, imitar y practicar directamente desde un **widget de pantalla de inicio**. La app incorpora un sistema pedagógico completo con SRS (repetición espaciada), quiz de pronunciación, categorías temáticas, y soporte multilingüe de interfaz.

El desarrollo se realizará con **Clean Architecture**, separando claramente las capas de Dominio, Datos y Presentación, lo que garantiza escalabilidad para una eventual publicación en App Store / Play Store.

---

## Alcance de la Primera Versión (MVP)

| Módulo | Incluido en MVP |
|---|---|
| Widget pantalla de inicio | ✅ |
| Palabra del día (audio + traducción + frase) | ✅ |
| Pronunciación (reconocimiento local) | ✅ |
| Feedback de pronunciación con score | ✅ |
| SRS (repetición espaciada) | ✅ |
| Historial de palabras aprendidas | ✅ |
| Categorías temáticas | ✅ |
| Quiz / reto de pronunciación | ✅ |
| Notificaciones diarias | ✅ |
| Multilingüe (ES / EN / FR interfaz) | ✅ |
| Selector de nivel (A1 → C2) | ✅ |
| Dark mode / Light mode | ✅ |
| Publicable (App Store / Play Store) | 🔜 Fase 2 |

---

## Arquitectura: Clean Architecture + Flutter

```
lib/
├── core/                         # Utilidades globales, constantes, temas
│   ├── di/                       # Inyección de dependencias (get_it)
│   ├── error/                    # Failures, exceptions
│   ├── usecases/                 # Base UseCase abstract class
│   └── theme/                    # AppTheme, colores, tipografía
│
├── features/
│   ├── word_of_the_day/          # Feature: Palabra del Día
│   │   ├── domain/
│   │   │   ├── entities/         # Word, WordExample, AudioFile
│   │   │   ├── repositories/     # IWordRepository (interfaz)
│   │   │   └── usecases/         # GetWordOfTheDay, GetWordsByCategory
│   │   ├── data/
│   │   │   ├── models/           # WordModel (JSON ↔ Entity)
│   │   │   ├── datasources/      # LocalDataSource (SQLite/sembast)
│   │   │   └── repositories/     # WordRepositoryImpl
│   │   └── presentation/
│   │       ├── bloc/             # WordBloc, WordState, WordEvent
│   │       ├── pages/            # WordDetailPage, HomeScreen
│   │       └── widgets/          # WordCard, AudioButton, PronunciationFeedback
│   │
│   ├── pronunciation/            # Feature: Práctica de Pronunciación
│   │   ├── domain/
│   │   │   ├── entities/         # PronunciationResult, ScoreResult
│   │   │   ├── repositories/     # IPronunciationRepository
│   │   │   └── usecases/         # ValidatePronunciation, GetPronunciationScore
│   │   ├── data/
│   │   │   ├── datasources/      # SpeechRecognitionLocalDataSource
│   │   │   └── repositories/     # PronunciationRepositoryImpl
│   │   └── presentation/
│   │       ├── bloc/             # PronunciationBloc
│   │       ├── pages/            # PronunciationPracticePage
│   │       └── widgets/          # MicrophoneButton, WaveformVisualizer, ScoreBadge
│   │
│   ├── quiz/                     # Feature: Quiz de pronunciación
│   │   ├── domain/
│   │   │   ├── entities/         # QuizSession, QuizQuestion
│   │   │   └── usecases/         # StartQuizSession, SubmitAnswer
│   │   ├── data/
│   │   └── presentation/
│   │       ├── bloc/             # QuizBloc
│   │       └── pages/            # QuizPage, QuizResultPage
│   │
│   ├── progress/                 # Feature: Progreso y SRS
│   │   ├── domain/
│   │   │   ├── entities/         # LearningCard, SRSData
│   │   │   └── usecases/         # UpdateSRSCard, GetDueCards
│   │   ├── data/
│   │   │   └── datasources/      # LocalSRSDataSource (SQLite)
│   │   └── presentation/
│   │       ├── bloc/             # ProgressBloc
│   │       └── pages/            # ProgressPage, HistoryPage
│   │
│   ├── categories/               # Feature: Categorías temáticas
│   │   ├── domain/
│   │   └── presentation/
│   │       └── pages/            # CategoriesPage, CategoryDetailPage
│   │
│   └── settings/                 # Feature: Configuración
│       ├── domain/
│       │   └── usecases/         # SetLanguage, SetLevel, SetNotifications
│       └── presentation/
│           └── pages/            # SettingsPage
│
└── main.dart
```

---

## Stack Tecnológico

| Capa | Tecnología | Justificación |
|---|---|---|
| **Framework** | Flutter 3.x | Cross-platform, excelente soporte de widgets |
| **Lenguaje** | Dart | Nativo de Flutter |
| **State Management** | flutter_bloc | Predecible, testeable, alineado con Clean Architecture |
| **DI** | get_it + injectable | Simple y poderoso |
| **Base de datos local** | SQLite via drift | Tipado, migraciones, relaciones |
| **Audio (reproducción)** | just_audio | Reproducir pronunciación nativa |
| **Audio (grabación)** | speech_to_text + Google/Apple STT API | Reconocimiento vía API del sistema para mayor precisión en francés |
| **Widget nativo** | home_widget | Soporte de widgets iOS + Android |
| **Notificaciones** | flutter_local_notifications | Recordatorio diario |
| **Internacionalización** | flutter_localizations + l10n | ES / EN / FR |
| **Assets de audio** | Pronunciaciones `.mp3` pre-grabadas (Forvo dataset / TTS) | Offline-first |
| **SRS Algorithm** | SM-2 (implementado en Dart) | Estándar de la industria (Anki) |

---

## Diseño Visual: Estilo "Parisino Elegante"

### Paleta de Colores
```
Primario:      #2C2416  (Café oscuro parisino)
Secundario:    #C49A3C  (Dorado ocre)
Acento:        #8B4513  (Terracota)
Fondo claro:   #F5F0E8  (Crema marfil)
Fondo oscuro:  #1A1612  (Noche parisina)
Texto:         #3D3530  / #F0EBE0
```

### Tipografía
- **Títulos**: *Playfair Display* (serif elegante)
- **Cuerpo**: *Lato* o *Source Sans 3* (legible, moderno)
- **Palabras francesas**: *Crimson Pro* (tipografía literaria)

### Elementos visuales
- Texturas sutiles tipo papel envejecido en el fondo
- Iconografía lineal fina (Feather Icons)
- Animaciones suaves de entrada (slide + fade)
- Card glassmorphism en modo oscuro
- Widget en pantalla de inicio con la palabra, su traducción y un ícono de micrófono

---

## Módulos y Features — Detalle

### 1. Widget de Pantalla de Inicio
- Muestra: palabra en francés + traducción + categoría
- Toca el widget → abre la app directo en el detalle de la palabra
- Se actualiza diariamente a medianoche
- Compatible: Android (Glance / AppWidget) + iOS (WidgetKit via home_widget)

### 2. Palabra del Día
- Base de datos local con ≥ 500 palabras iniciales (JSON → SQLite al instalar)
- Cada palabra tiene: texto FR, traducción (ES/EN), IPA, categoría, nivel (A1-C2), frase de ejemplo, archivo de audio
- **Fase 1 (MVP)**: Audio via Flutter TTS (`flutter_tts`) — voz sintética francesa como fallback
- **Fase posterior**: Dataset de pronunciaciones nativas reales (Forvo / Common Voice de Mozilla) integrado como assets `.mp3`

### 3. Pronunciación y Validación
- El usuario graba su pronunciación con el micrófono
- `speech_to_text` usa la API del sistema operativo (Google Speech en Android / Apple Speech en iOS) para mayor precisión en francés
- Se compara la transcripción con la palabra esperada (Levenshtein distance + phonetic matching)
- Score visual (0-100%) con feedback: "¡Parfait!", "Casi", "Inténtalo de nuevo"
- Waveform animado mientras graba

### 4. SRS (Repetición Espaciada)
- Algoritmo SM-2 implementado en Dart puro (dominio, sin dependencias externas)
- Cada palabra tiene su tarjeta SRS: intervalo, easiness factor, repeticiones
- Al calificar pronunciación → actualiza la tarjeta SRS
- "Tarjetas del día" = palabras que SRS indica revisar hoy

### 5. Quiz de Pronunciación
- Sesión de 10 palabras
- Para cada palabra: escucha el audio → graba tu pronunciación → recibe score
- Resultado final con gráfico de desempeño
- Desbloquea palabras nuevas al completar quizzes

### 6. Progreso e Historial
- Racha de días (streak), palabras aprendidas, score promedio
- Gráfico de progreso semanal
- Lista de palabras marcadas como "dominadas"

### 7. Categorías Temáticas
- Comida & Restaurantes, Viajes & Transporte, Negocios & Trabajo, Emociones, Tecnología, Naturaleza, etc.
- Filtro por nivel (A1→C2) y categoría

### 8. Notificaciones Diarias
- Hora configurable
- Mensaje: "🗼 Tu palabra del día: *flâner* — ¡practica hoy!"

### 9. Configuración
- Idioma de interfaz: Español / English / Français
- Nivel de aprendizaje: A1, A2, B1, B2, C1, C2, Mixto
- Hora de notificación
- Dark Mode / Light Mode

---

## Fases de Desarrollo

### Fase 1 — Prototipo & Documentación (actual)
- [x] Entrevista de requisitos
- [x] Decisiones técnicas confirmadas
- [ ] Diseño visual (mockups — 6 pantallas principales)
- [ ] Documentación técnica completa (ADRs, diagramas, contratos de API interna)
- [ ] Configurar proyecto Flutter base con Clean Architecture

### Fase 2 — Core MVP
- [ ] Base de datos SQLite + seeder de palabras (100 palabras inicial)
- [ ] Feature: Palabra del Día (UI + audio)
- [ ] Feature: Pronunciación + validación local
- [ ] Feature: Widget de pantalla de inicio (Android primero)

### Fase 3 — Funcionalidades Avanzadas
- [ ] SRS (SM-2 algorithm)
- [ ] Quiz de pronunciación
- [ ] Historial + progreso + racha
- [ ] Categorías temáticas

### Fase 4 — Pulido y Publicación
- [ ] Widget iOS (WidgetKit)
- [ ] Multilingüe completo (ES/EN/FR)
- [ ] Notificaciones push locales
- [ ] Tests unitarios y de integración
- [ ] Preparar assets para App Store / Play Store

---

## Decisiones Técnicas Confirmadas ✅

| Decisión | Resolución |
|---|---|
| **Reconocimiento de voz** | API del sistema (Google/Apple STT) para máxima precisión en francés |
| **Audio de pronunciación** | TTS en MVP, dataset de audio nativo en fase posterior |
| **Plataforma widget** | Android primero; iOS en fase 4 |

---

## Rol de Claude como Co-desarrollador

Claude participará activamente durante todo el proyecto como par de desarrollo:

- **Decisiones de arquitectura**: consultas sobre patrones, trade-offs, y refactoring
- **Generación de código**: implementaciones de algoritmos complejos (SM-2, phonetic matching, etc.)
- **Revisión y mejora**: code reviews, sugerencias de optimización
- **Pruebas**: generación de unit tests, edge cases, mocks
- **Dataset**: generar el seed inicial de palabras francesas (JSON estructurado con IPA, ejemplos, categorías, niveles)

---

## Siguiente Paso

Una vez que apruebes este plan:
1. Generaré los **mockups de UI** para todas las pantallas principales
2. Crearé la **documentación técnica** completa (ADR, diagramas, API interna)
3. Inicializaré el **proyecto Flutter** con la estructura Clean Architecture lista para desarrollar
