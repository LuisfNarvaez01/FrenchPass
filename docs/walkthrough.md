# 🗼 FrenchPass — Resumen de la Primera Entrega

> **Documento histórico (scaffold inicial).** Describe la entrega en la que la UI
> funcionaba con datos de demostración. La app ya está conectada de punta a
> punta: catálogo real, TTS, reconocimiento de voz, quiz, progreso persistido y
> notificación diaria. Para el estado actual, ver el [README](../README.md).
>
> Dos cosas que este documento da por hechas y **no** lo están: el widget de
> pantalla de inicio sigue pendiente, y la persistencia no usa Drift
> (ver ADR-009 en [technical_docs](technical_docs.md)).
>
> Los mockups de abajo siguen siendo la referencia visual válida.

FrenchPass es una aplicación móvil desarrollada en **Flutter** siguiendo los principios de **Clean Architecture**, diseñada para el aprendizaje diario de francés mediante la **palabra del día**, un **widget para la pantalla de inicio** (Android Glance/home_widget), **práctica y validación de pronunciación**, y un sistema de memoria espaciada con el **algoritmo SM-2 (SuperMemo-2)**.

---

## 📸 Mockups de Alta Fidelidad Generados

Todos los mockups visuales están guardados localmente en [`docs/mockups/`](./mockups/):

| Componente | Archivo de Imagen | Descripción |
|---|---|---|
| **Widget Android** | [`mockup_widget_home.jpg`](./mockups/mockup_widget_home.jpg) | Widget de pantalla de inicio (4x2) en estética Parisian Dark, palabra del día con IPA, audio y acceso a práctica |
| **Práctica de Pronunciación** | [`mockup_pronunciation.jpg`](./mockups/mockup_pronunciation.jpg) | Pantalla de grabación con micrófono pulsante, onda sonora de audio y tarjeta de retroalimentación en vivo |
| **Progreso & Quiz SM-2** | [`mockup_quiz_progress.jpg`](./mockups/mockup_quiz_progress.jpg) | Dashboard de progreso diario, racha de días, curva de retención SM-2 y tarjeta de quiz interactiva |

---

## 🏛️ Arquitectura del Software (Clean Architecture)

El código fuente en [`lib/`](../lib/) está organizado estrictamente por capas y features:

```
lib/
├── main.dart                                         ← Punto de entrada, orientación y MultiBlocProvider
├── core/
│   ├── di/injection.dart                             ← Inyección de dependencias con GetIt
│   ├── error/failure.dart                            ← Jerarquía de fallos (ServerFailure, CacheFailure, etc.)
│   ├── router/app_router.dart                        ← GoRouter con ShellRoute y rutas tipadas
│   ├── shell/main_shell.dart                         ← Barra de navegación inferior animada
│   ├── theme/app_theme.dart                          ← Parisian Elegance (Playfair Display + Lato, HSL Gold/Dark)
│   └── usecases/usecase.dart                         ← Abstracción base para UseCases con fpdart (Either)
├── features/
│   ├── word_of_the_day/
│   │   ├── domain/entities/word.dart                 ← Entidad de palabra con IPA, nivel CEFR y ejemplos
│   │   └── presentation/
│   │       ├── pages/home_page.dart                  ← Pantalla principal con WordCard y banner de racha
│   │       ├── pages/word_detail_page.dart           ← Vista en detalle de la palabra
│   │       └── widgets/
│   │           ├── word_card.dart                    ← Tarjeta visual con tipografía editorial y badges
│   │           └── action_buttons_row.dart           ← Botones de acción: Escuchar, Practicar, Guardar
│   ├── pronunciation/
│   │   ├── domain/entities/pronunciation_result.dart ← Entidad con feedback y puntajes (claridad, acento, ritmo)
│   │   ├── domain/usecases/pronunciation_scorer.dart ← Algoritmo Levenshtein normalizado + métrica silábica
│   │   └── presentation/pages/
│   │       ├── pronunciation_practice_page.dart      ← Micrófono interactivo con animación pulsante
│   │       └── pronunciation_result_page.dart        ← Indicador circular de score, desglose y consejos
│   ├── progress/
│   │   ├── domain/entities/srs_card.dart             ← Entidad de tarjeta de memoria espaciada
│   │   ├── domain/usecases/sm2_algorithm.dart        ← Implementación matemática pura del algoritmo SM-2
│   │   └── presentation/pages/progress_page.dart     ← Métricas de retención y revisión diaria
│   ├── quiz/presentation/pages/                      ← Quiz interactivo y pantalla de resultados
│   ├── categories/presentation/pages/                ← Exploración de palabras por tema (Comida, Viajes, etc.)
│   └── settings/                                     ← Configuración de tema (Dark/Light), nivel e idioma con BLoC
```

---

## 📚 Dataset Inicial Incluido

En [`assets/data/words_seed.json`](../assets/data/words_seed.json) se incluyeron **30 palabras curadas** organizadas por nivel del Marco Común Europeo (A1 a C2):
- Transcripción fonética internacional (IPA / AFI).
- Significado en español e inglés.
- Frases de ejemplo en francés con su traducción correspondiente.
- Categorías temáticas: *Quotidien, Nourriture, Salutations, Voyage, Nature, Philosophie, Art, Littérature*.

---

## 📄 Documentación Entregada en el Proyecto

Todos los documentos solicitados quedaron disponibles en la carpeta [`docs/`](./):

1. [`implementation_plan.md`](./implementation_plan.md): Plan de implementación completo, modelos de datos, arquitectura de integración y roadmap.
2. [`technical_docs.md`](./technical_docs.md): Documento técnico con especificaciones de APIs (TTS/STT, Azure Speech, Claude API), configuración del widget de pantalla de inicio en Android y guía de base de datos SQLite con Drift.
3. [`mockups.md`](./mockups.md): Especificaciones de diseño visual, paleta de colores, tipografía editorial y pantallas.
4. [`walkthrough.md`](./walkthrough.md): Resumen de entrega y verificación técnica.
5. [`../README.md`](../README.md): Documentación del repositorio con instrucciones de ejecución y estado del proyecto.

---

## 🧪 Pruebas y Verificación de Calidad

| Comando | Resultado |
|---|---|
| `flutter analyze` | **0 errores, 0 advertencias** (`No issues found!`) |
| `flutter test` | **6 tests unitarios ejecutados y aprobados (100% pass)**: <br>• Cálculo inicial de intervalo SM-2<br>• Crecimiento exponencial de intervalo SM-2<br>• Reset de intervalo ante fallo de memoria<br>• Evaluación de coincidencia exacta de pronunciación<br>• Evaluación de pronunciación parcial<br>• Detección de pronunciación errónea |
| `AndroidManifest.xml` | Permisos de audio (`RECORD_AUDIO`), internet (`INTERNET`) y notificaciones (`POST_NOTIFICATIONS`) configurados |
