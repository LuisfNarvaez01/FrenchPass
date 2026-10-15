# FrenchPass: sistema de diseño (v2.0)

**Dirección: editorial parisino + un personaje con vida.** La base es sobria:
tinta, papel, tipografía con carácter y mucho aire. El perrito es lo único
juguetón y animado, y aparece en momentos que significan algo. La pieza
propia de la marca es **el pase**: un billete con muescas y línea perforada.

Los valores viven en `lib/core/theme/` (`AppPalette`, `Insets`, `Radii`,
`Motion`) y los componentes en `lib/core/widgets/`. Este documento dice
**cuándo** usar cada cosa.

## Color: un rol por color

| Token | Rol | Nunca |
|---|---|---|
| `bg` / `bgAlt` | El suelo de la página y la barra inferior | Dentro de tarjetas |
| `surface` | Tarjetas, grupos de filas, el pase | Para agrupar texto suelto |
| `surfaceAlt` | Un nivel por encima: campo, control, insignia | Como fondo de página |
| `textPrimary` | Lo que se lee primero y el francés. También el filtro seleccionado (`ChoiceTag`, invertido) | |
| `textSecondary` | Explicaciones, traducciones, segundas líneas (`bodySmall`), iconos de tema | |
| `textMuted` | Metadatos: contadores, cejas (`eyebrow`), `labelSmall` | Frases que hay que leer |
| `gold` | **La** acción principal de la pantalla y lo conseguido (racha, logro, el pase destacado) | Iconos de tema, etiquetas de nivel, filtros, botones secundarios |
| `terracotta` | Lo que espera: repasos, una corrección amable | Decoración |
| `good` / `warning` / `critical` | Estado, siempre con icono o texto | Series de gráficos |

Regla práctica: **si hay más de dos cosas doradas en pantalla, sobra una.**

**Modo oscuro "noche parisina":** fondo `#0D1015`, superficie `#1C222D`,
elevada `#2A313E`. Cada capa contrasta 1.2:1 con la de debajo, así que no
hacen falta bordes. Todos los textos superan WCAG AA sobre cualquier
superficie; el más tenue (`textMuted`) llega a 5.1:1 sobre `surfaceAlt`.

**Deshabilitado ≠ secundario:** un control apagado se ve desvaído
(`textMuted` al 55 %) sobre fondo plano, o la fila entera al 45 % de
opacidad. Un texto secundario nunca usa transparencia.

## Tipografía: una función por familia

| Estilo | Uso |
|---|---|
| `headlineLarge` (Playfair 30) | Título de pestaña (`PageHeader`) |
| `headlineSmall` (Playfair 20) | Título dentro del pase o de una sección destacada |
| `AppTheme.french()` (Playfair) | **Toda palabra o frase francesa protagonista**, en tinta, nunca en dorado |
| `titleMedium` (Lato 15) | Título de fila |
| `bodySmall` (Lato 13, secundario) | Segunda línea de fila: **una línea**, con elipsis |
| `eyebrow` (Lato 11, mayúsculas) | Nombre de grupo encima de una lista |
| `AppTheme.ipa()` (Crimson cursiva) | Solo la fonética |

La serif da identidad (títulos y francés). Todo lo que se pulsa o explica va
en sans.

## Contenedores

| Componente | Cuándo |
|---|---|
| `PassCard` | La pieza especial de la pantalla: la palabra del día, lo recomendado en Practicar, tu próxima conversación. **Uno por pantalla.** |
| `RowGroup` + `ListRow` | Una lista de cosas del mismo tipo (temas, actividades, situaciones, palabras): filas en un solo bloque, con separadores finos |
| `AppCard` | Algo que destaca solo y no es una lista (un logro, el perfil del tutor) |
| Texto en la página | Títulos, cejas, explicaciones |

Nunca pongas una tarjeta dentro de otra. Nunca apiles tarjetas sueltas para
una lista: usa `RowGroup`.

## Radios y bordes

| Radio | Componentes |
|---|---|
| `Radii.xl` (20) | El pase, hojas inferiores, diálogos |
| `Radii.lg` (16) | Tarjetas y grupos de filas |
| `Radii.md` (12) | Botones y campos |
| `Radii.pill` | Filtros, buscador, etiquetas, chip de racha |
| `size × 0.3` | Insignias de icono (`TopicBadge`) |

Los bordes solo aparecen en el tema claro (blanco sobre crema) y en botones
con contorno. El pase no lleva borde (cruzaría la perforación): se separa por
tono y sombra.

## Iconos

- **Navegación:** contorno cuando no está seleccionado y relleno cuando sí.
  Cada pestaña tiene una forma distinta (sol, voz, pieza, libro, gráfico).
- **Tema o actividad:** dentro de `TopicBadge`, en `textSecondary`. Sirven
  para orientarse, no para decorar. Nada de iconos gigantes de fondo.
- **Estado:** check verde (completado), punto de color (estado de una
  palabra), siempre con texto al lado.
- **Acción:** solo dentro de botones, nunca sueltos sin etiqueta salvo
  escuchar o guardar, con `tooltip`/`Semantics`.

## Jerarquía por pantalla

Cada pestaña empieza con `PageHeader` (título + una línea). Debajo va **un
protagonista** (el pase), luego grupos con ceja y filas. Una sola acción
dorada.

## Movimiento

- Entradas: fundido con una subida de 8–10 px y `Motion.stagger` por grupo.
- Entre páginas, `FadeForwards` sobre el fondo. Entre pestañas, fundido
  cruzado corto.
- **El perrito** respira en reposo (`MascotSticker`), se balancea al pensar,
  aterriza y da dos saltitos al celebrar (`MascotCelebration`), y piensa en
  los estados vacíos (`EmptyState(mascot: true)`).
- Con "reducir movimiento" del sistema, todo queda en un fundido.

## Sonido

`SoundService` sintetiza los sonidos en el teléfono, sin archivos:
`correct` (dos notas que suben), `wrong` (una nota grave y suave, nunca un
zumbido), `complete` (arpegio) y `achievement` (acorde brillante). Los
toques normales son silenciosos. Se apagan en Ajustes › Sonidos.

## Estados

| Estado | Tratamiento |
|---|---|
| Pulsado | Escala 0.98 en tarjetas y ripple dentro del grupo |
| Seleccionado | `ChoiceTag` invertido (tinta) o icono relleno en la barra |
| Cargando | Esqueleto (`StudySkeleton`) o perrito pensando |
| Error | Mensaje con pasos, nunca el error técnico en Play |
| Vacío | Perrito pensando + una frase + una acción |
| Completado | Check verde en la fila, perrito celebrando y sonido al cerrar una ronda |

## Pendiente

- Validar con personas reales si retoman antes lo que dejaron a medias.
