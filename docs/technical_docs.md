# FrenchPass — Documentación Técnica

## 1. Decisiones de Arquitectura (ADRs)

### ADR-001: Clean Architecture con Feature-First

**Contexto**: App con múltiples features independientes (pronunciación, SRS, quiz, widget).  
**Decisión**: Organización por features con 3 capas internas cada una (domain / data / presentation).  
**Consecuencias**: Mayor escalabilidad, testabilidad por capa, sin acoplamiento entre features.

```
Feature X/
  domain/      → Entidades, interfaces de repositorio, casos de uso (Dart puro, 0 dependencias)
  data/        → Implementaciones, datasources, modelos, mappers
  presentation/ → BLoC, páginas, widgets de UI
```

### ADR-002: BLoC como State Manager

**Contexto**: Se requiere un estado predecible, testeable y compatible con streams de audio.  
**Decisión**: `flutter_bloc` con events + states tipados por feature.  
**Alternativas rechazadas**: Riverpod (menor separación de capas), GetX (menor testabilidad).

### ADR-003: Drift (SQLite) como persistencia local — ⚠️ SUPERSEDIDA por ADR-009

**Contexto**: Datos offline-first: palabras, SRS cards, progreso, historial.  
**Decisión**: `drift` por su tipado fuerte, soporte de migraciones y generación de código.  
**Alternativas rechazadas**: Hive (NoSQL, peor para relaciones), Isar (más complejo para MVP).

### ADR-004: speech_to_text + API del sistema para STT

**Contexto**: El reconocimiento local de francés tiene baja precisión en algunos dispositivos.  
**Decisión**: Usar `speech_to_text` con fallback a la API nativa del SO (Google/Apple).  
**Trade-off**: Requiere internet ocasionalmente para mayor precisión.

### ADR-005: Flutter TTS como MVP de audio + dataset futuro

**Contexto**: Pronunciaciones nativas requieren un dataset curado (Forvo, Common Voice).  
**Decisión**: `flutter_tts` con voz `fr-FR` en MVP. Dataset `.mp3` como mejora futura.  
**Criterio de migración**: Cuando el dataset supere 200 palabras, se prioriza el archivo local.

### ADR-009: `shared_preferences` en lugar de Drift (supersede ADR-003)

**Fecha**: 2026-10-10

**Contexto**: Al implementar la capa de datos quedó claro que ADR-003 asumía algo
que no se cumple: que el catálogo sería estado mutable. No lo es. Las 120
palabras son un asset de solo lectura empaquetado en el APK, y la app nunca las
escribe. El único estado que realmente persiste es el progreso del usuario:
tarjetas SRS, historial de intentos, palabras guardadas y calendario de estudio.

Eso elimina las dos razones que justificaban SQLite. No hay relaciones que
normalizar — todo se indexa por `wordId` y el catálogo se resuelve en memoria — y
no hay migraciones de esquema que gestionar, porque el esquema que cambia es el
del asset, que se reemplaza con cada release.

**Decisión**: guardar el progreso como documentos JSON pequeños en
`shared_preferences`, detrás de `StorageService`, y leer el catálogo una vez al
arrancar con `WordRepository`.

**Consecuencias**:
- Se elimina la generación de código (`build_runner`, `drift_dev`), y con ella un
  paso de build y una fuente de desincronización entre código y esquema.
- El APK no carga `sqlite3_flutter_libs` (bibliotecas nativas por ABI).
- Los repositorios quedan **síncronos** en lectura, así que la UI puede pintar
  sin estados de carga.
- **Límite aceptado**: el historial de intentos se recorta a 500 entradas y las
  sesiones de quiz a 100. Las preferencias no son un almacén ilimitado y la UI
  solo grafica las últimas semanas. Si alguna vez hace falta historial completo o
  consultas analíticas, este ADR se revisa y Drift vuelve a ser la respuesta
  correcta.

---

## 2. Dominio: Entidades

```dart
// features/word_of_the_day/domain/entities/word.dart
class Word {
  final String id;
  final String french;           // "flâner"
  final String ipa;              // "[flɑ.ne]"
  final String translationEs;    // "Pasear sin rumbo fijo"
  final String translationEn;    // "To stroll aimlessly"
  final String exampleFr;        // "J'aime flâner dans Paris."
  final String exampleEs;        // "Me gusta pasear por París."
  final WordCategory category;   // WordCategory.dailyLife
  final CefrLevel level;         // CefrLevel.b1
  final String? audioAssetPath;  // "assets/audio/flaner.mp3" o null (→ TTS)
  final WordType type;           // WordType.verb
}

// features/word_of_the_day/domain/entities/cefr_level.dart
enum CefrLevel { a1, a2, b1, b2, c1, c2 }

// features/word_of_the_day/domain/entities/word_category.dart
enum WordCategory {
  dailyLife,        // Vida Cotidiana
  food,             // Comida
  travel,           // Viajes
  business,         // Negocios
  emotions,         // Emociones
  technology,       // Tecnología
  nature,           // Naturaleza
  culture,          // Cultura
}

// features/pronunciation/domain/entities/pronunciation_result.dart
class PronunciationResult {
  final String recognizedText;   // Texto transcrito por STT
  final double overallScore;     // 0.0 - 1.0
  final double clarityScore;
  final double accentScore;
  final double rhythmScore;
  final PronunciationFeedback feedback;  // parfait, tresBien, biensur, reessaie
}

// features/progress/domain/entities/srs_card.dart
class SrsCard {
  final String wordId;
  final int repetitions;         // Número de revisiones
  final double easinessFactor;   // SM-2: 1.3 - 2.5 (default 2.5)
  final int intervalDays;        // Días hasta próxima revisión
  final DateTime nextReviewDate;
  final DateTime lastReviewDate;
  final double lastScore;
}
```

---

## 3. Contratos de Repositorio (Interfaces)

```dart
// features/word_of_the_day/domain/repositories/i_word_repository.dart
abstract class IWordRepository {
  Future<Either<Failure, Word>> getWordOfTheDay();
  Future<Either<Failure, List<Word>>> getWordsByCategory(WordCategory category);
  Future<Either<Failure, List<Word>>> getWordsByLevel(CefrLevel level);
  Future<Either<Failure, Word>> getWordById(String id);
  Future<Either<Failure, List<Word>>> searchWords(String query);
}

// features/pronunciation/domain/repositories/i_pronunciation_repository.dart
abstract class IPronunciationRepository {
  Future<Either<Failure, PronunciationResult>> validatePronunciation({
    required String targetWord,
    required String recognizedText,
  });
  Stream<String> startListening({required String locale});
  Future<void> stopListening();
}

// features/progress/domain/repositories/i_progress_repository.dart
abstract class IProgressRepository {
  Future<Either<Failure, SrsCard>> getSrsCard(String wordId);
  Future<Either<Failure, List<SrsCard>>> getDueCards();
  Future<Either<Failure, void>> updateSrsCard(SrsCard card, double score);
  Future<Either<Failure, UserProgress>> getUserProgress();
  Future<Either<Failure, List<WordHistoryEntry>>> getWordHistory();
}
```

---

## 4. Casos de Uso

```dart
// GetWordOfTheDay
class GetWordOfTheDay implements UseCase<Word, NoParams> {
  @override
  Future<Either<Failure, Word>> call(NoParams params) async {
    return await repository.getWordOfTheDay();
  }
}

// ValidatePronunciation
class ValidatePronunciation implements UseCase<PronunciationResult, ValidatePronunciationParams> {
  @override
  Future<Either<Failure, PronunciationResult>> call(params) async {
    return await repository.validatePronunciation(
      targetWord: params.targetWord,
      recognizedText: params.recognizedText,
    );
  }
}

// UpdateSrsCard — aplica SM-2 y guarda
class UpdateSrsCard implements UseCase<void, UpdateSrsCardParams> {
  @override
  Future<Either<Failure, void>> call(params) async {
    final card = await progressRepo.getSrsCard(params.wordId);
    final updated = SM2Algorithm.update(card, params.score);
    return await progressRepo.updateSrsCard(updated, params.score);
  }
}
```

---

## 5. Algoritmo SRS — SM-2

```dart
class SM2Algorithm {
  static const double minEasiness = 1.3;

  static SrsCard update(SrsCard card, double score) {
    // score: 0.0 (mal) → 1.0 (perfecto)
    // SM-2 trabaja con 0-5, normalizamos
    final q = (score * 5).round();

    double newEasiness = card.easinessFactor + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02));
    newEasiness = newEasiness.clamp(minEasiness, 2.5);

    int newRepetitions;
    int newInterval;

    if (q < 3) {
      // Respuesta incorrecta → reiniciar
      newRepetitions = 0;
      newInterval = 1;
    } else {
      newRepetitions = card.repetitions + 1;
      newInterval = switch (card.repetitions) {
        0 => 1,
        1 => 6,
        _ => (card.intervalDays * newEasiness).round(),
      };
    }

    return card.copyWith(
      repetitions: newRepetitions,
      easinessFactor: newEasiness,
      intervalDays: newInterval,
      nextReviewDate: DateTime.now().add(Duration(days: newInterval)),
      lastReviewDate: DateTime.now(),
      lastScore: score,
    );
  }
}
```

---

## 6. Algoritmo de Scoring de Pronunciación

```dart
class PronunciationScorer {
  static PronunciationResult score({
    required String target,     // "flâner"
    required String recognized, // texto de STT
  }) {
    final normalizedTarget = _normalize(target);
    final normalizedRecognized = _normalize(recognized);

    // 1. Claridad: Levenshtein distance normalizada
    final editDistance = _levenshtein(normalizedTarget, normalizedRecognized);
    final clarityScore = 1.0 - (editDistance / normalizedTarget.length).clamp(0.0, 1.0);

    // 2. Acento: comparación fonética con soundex/metaphone adaptado al francés
    final phoneticTarget = FrenchPhonetic.encode(normalizedTarget);
    final phoneticRecognized = FrenchPhonetic.encode(normalizedRecognized);
    final accentScore = phoneticTarget == phoneticRecognized ? 1.0 : clarityScore * 0.8;

    // 3. Ritmo: basado en la longitud de sílabas reconocidas vs esperadas
    final rhythmScore = _syllableRhythmScore(normalizedTarget, normalizedRecognized);

    final overall = (clarityScore * 0.5 + accentScore * 0.3 + rhythmScore * 0.2);

    return PronunciationResult(
      recognizedText: recognized,
      overallScore: overall,
      clarityScore: clarityScore,
      accentScore: accentScore,
      rhythmScore: rhythmScore,
      feedback: _feedbackFor(overall),
    );
  }

  static PronunciationFeedback _feedbackFor(double score) => switch (score) {
    >= 0.90 => PronunciationFeedback.parfait,
    >= 0.75 => PronunciationFeedback.tresBien,
    >= 0.55 => PronunciationFeedback.biensur,
    _       => PronunciationFeedback.reessaie,
  };
}
```

---

## 7. Esquema de Base de Datos (Drift) — ⚠️ NO IMPLEMENTADO

> **Esta sección describe el diseño descartado en [ADR-009](#adr-009-shared_preferences-en-lugar-de-drift-supersede-adr-003).**
> Se conserva porque documenta el modelo de datos lógico, que sigue siendo
> válido; lo que cambió es el motor. La implementación real guarda estas mismas
> entidades como documentos JSON en `shared_preferences`:
>
> | Tabla del diseño | Clave real en `StorageKeys` |
> |---|---|
> | `words` | ninguna — el catálogo es un asset de solo lectura |
> | `srs_cards` | `fp.progress.srsCards` (mapa `wordId` → tarjeta) |
> | `daily_words` | ninguna — la palabra del día es función pura de la fecha |
> | `user_progress` | se deriva de `fp.progress.attempts` y `fp.progress.studiedDays` |

```dart
// words table
class Words extends Table {
  TextColumn get id => text()();
  TextColumn get french => text()();
  TextColumn get ipa => text()();
  TextColumn get translationEs => text()();
  TextColumn get translationEn => text()();
  TextColumn get exampleFr => text()();
  TextColumn get exampleEs => text()();
  TextColumn get category => textEnum<WordCategory>()();
  TextColumn get level => textEnum<CefrLevel>()();
  TextColumn get audioAssetPath => text().nullable()();
  TextColumn get wordType => textEnum<WordType>()();
  DateTimeColumn get addedAt => dateTime()();
}

// srs_cards table
class SrsCards extends Table {
  TextColumn get wordId => text().references(Words, #id)();
  IntColumn get repetitions => integer().withDefault(const Constant(0))();
  RealColumn get easinessFactor => real().withDefault(const Constant(2.5))();
  IntColumn get intervalDays => integer().withDefault(const Constant(1))();
  DateTimeColumn get nextReviewDate => dateTime()();
  DateTimeColumn get lastReviewDate => dateTime().nullable()();
  RealColumn get lastScore => real().nullable()();
}

// daily_words table (palabras asignadas por día)
class DailyWords extends Table {
  TextColumn get wordId => text().references(Words, #id)();
  DateTimeColumn get assignedDate => dateTime()();
  BoolColumn get practiced => boolean().withDefault(const Constant(false))();
}

// user_progress table
class UserProgress extends Table {
  IntColumn get totalWordsPracticed => integer().withDefault(const Constant(0))();
  IntColumn get currentStreak => integer().withDefault(const Constant(0))();
  IntColumn get longestStreak => integer().withDefault(const Constant(0))();
  RealColumn get averageScore => real().withDefault(const Constant(0.0))();
  DateTimeColumn get lastActiveDate => dateTime().nullable()();
}
```

---

## 8. Protocolo de Comunicación Widget ↔ App — 🔜 PENDIENTE

> El widget no está implementado y `home_widget` **no** está en `pubspec.yaml`:
> se quitó junto con las demás dependencias sin usar. Hay que volver a añadirlo
> al retomar esta fase.
>
> Una nota a favor del diseño de abajo: `WordRepository.wordOfTheDay` es una
> función pura de la fecha y del filtro de nivel, así que el widget puede
> calcular la misma palabra que la app sin compartir estado — el paso de
> "escribir los datos del día" es una optimización, no un requisito de
> correctitud.

```
Android Widget (Glance/AppWidget)
        ↓
  home_widget package
        ↓
  SharedPreferences (datos serializados JSON)
  → "fp_word_today": { "french": "flâner", "translation": "...", "level": "B1" }
        ↓
  Widget actualiza su UI con los datos

App (Flutter)
  → Al inicio del día: escribe datos en SharedPreferences via home_widget
  → Al tap en widget: app se abre en la ruta /word-detail/{wordId}
  → Widget recibe click callback → HomeWidget.widgetClicked stream
```

---

## 9. Estructura de Inyección de Dependencias

El registro se escribe a mano con `get_it`. Se descartó `injectable` por la misma
razón que Drift ([ADR-009](#adr-009-shared_preferences-en-lugar-de-drift-supersede-adr-003)):
el grafo tiene ocho nodos y un paso de `build_runner` para generarlo cuesta más
de lo que ahorra.

```dart
// core/di/injection.dart
Future<void> configureDependencies() async {
  // Servicios
  final storage = await StorageService.create();
  getIt.registerSingleton<StorageService>(storage);
  getIt.registerSingleton<TtsService>(TtsService());
  getIt.registerSingleton<SpeechService>(SpeechService());
  getIt.registerSingleton<NotificationService>(NotificationService());

  // Repositorios — el catálogo se carga una vez al arrancar, así que las
  // lecturas posteriores son síncronas y la UI no necesita estados de carga.
  final words = WordRepository();
  await words.load();
  getIt.registerSingleton<WordRepository>(words);
  getIt.registerSingleton<ProgressRepository>(ProgressRepository(storage));

  // BLoCs
  getIt.registerFactory<SettingsBloc>(() => SettingsBloc(
        getIt<StorageService>(),
        getIt<NotificationService>(),
        getIt<TtsService>(),
      ));
}
```

Los cubits con estado por pantalla (`HomeCubit`, `QuizCubit`) no se registran en
`get_it`: los construye el `BlocProvider` de su página, que es también quien debe
destruirlos.

---

## 10. Estructura de Navegación (GoRouter)

Rutas implementadas. Las cinco primeras viven dentro de un `ShellRoute` con la
barra de pestañas; las de pantalla completa quedan fuera para que la práctica y
el detalle no compitan con la navegación inferior.

```
ShellRoute (MainShell · barra de pestañas, transición de fundido)
├── /home                     → HomePage        · palabra del día
├── /quiz                     → QuizPage        · intro → ronda → resumen
├── /categories               → CategoriesPage  · catálogo + buscador
├── /progress                 → ProgressPage    · estadísticas y gráficas
└── /settings                 → SettingsPage

Pantalla completa (fuera del shell)
├── /category/:key            → CategoryWordsPage
└── /word/:id                 → WordDetailPage
    └── /word/:id/practice    → PronunciationPracticePage
```

Dos decisiones que vale la pena registrar:

- **El resultado del quiz no es una ruta.** Es un estado de `QuizCubit`
  (`QuizStatus.finished`), porque una ruta de resultado se puede alcanzar con el
  botón atrás sin una sesión detrás.
- **El resultado de pronunciación se empuja con `Navigator`**, no con GoRouter,
  porque lleva un objeto `PronunciationResult` que no se puede serializar en una
  URL. La ruta de práctica sí acepta un arranque en frío: si `extra` no sobrevive,
  resuelve la palabra desde el `:id` del path.

---

## 11. Dataset de Palabras — Estructura JSON

Claude generará el seed inicial de 500 palabras en este formato:

```json
{
  "words": [
    {
      "id": "uuid-v4",
      "french": "flâner",
      "ipa": "[flɑ.ne]",
      "translation_es": "Pasear sin rumbo fijo",
      "translation_en": "To stroll aimlessly",
      "example_fr": "J'aime flâner dans les rues de Paris le dimanche.",
      "example_es": "Me encanta pasear sin rumbo por las calles de París los domingos.",
      "category": "daily_life",
      "level": "b1",
      "word_type": "verb",
      "audio_asset": null
    }
  ]
}
```

---

## 12. Rol de Claude en el Desarrollo

| Tarea | Cuándo usar Claude |
|---|---|
| Generar dataset de 500 palabras (JSON) | Fase 2 inicio |
| Revisar implementación SM-2 | Fase 2 |
| Optimizar PronunciationScorer | Fase 2 |
| Generar tests unitarios por feature | Por cada feature completada |
| Code review de BLoCs y repositorios | Por cada PR/feature |
| Sugerir mejoras de UX | En cada iteración de UI |
| Debuggear edge cases de STT en francés | Fase 2 - pronunciación |
| Documentar APIs internas | Ongoing |
