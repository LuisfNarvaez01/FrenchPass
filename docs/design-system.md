# FrenchPass: sistema de diseño

**Dirección: editorial parisino + un personaje con vida.** La base es sobria:
tinta, papel, tipografía con carácter y mucho aire. El perrito es lo único
juguetón y animado, y aparece solo en momentos que significan algo.

Los valores viven en `lib/core/theme/` (`AppPalette`, `Insets`, `Radii`,
`Motion`) y en `lib/core/widgets/app_widgets.dart`. Este documento dice
**cuándo** usar cada cosa.

## Color: un rol por color

| Token | Rol | Nunca |
|---|---|---|
| `bg` / `bgAlt` | El suelo de la página y la barra inferior | Dentro de tarjetas |
| `surface` | Una tarjeta: algo que se toca o que se separa del resto | Para agrupar texto suelto |
| `surfaceAlt` | Un nivel por encima: campo de texto, control, chip | Como fondo de página |
| `textPrimary` | Lo que se lee primero, y el francés | |
| `textSecondary` | Explicaciones, traducciones | |
| `textMuted` | Metadatos: contadores, fechas, etiquetas pequeñas | Para frases que hay que leer |
| `gold` | **La** acción principal de la pantalla y lo conseguido (racha, logro, acierto destacado) | Iconos decorativos, etiquetas de nivel, botones secundarios |
| `terracotta` | Una corrección amable, lo que falta | Decoración |
| `good` / `warning` / `critical` | Estado, siempre con icono y texto | Series de gráficos |

Regla práctica: **si hay más de dos cosas doradas en pantalla, sobra una.**

Modo oscuro "noche parisina": fondo tinta azul-noche `#0F1218`, superficies
`#1A1F29` y `#252B37`, texto crema. Todos los textos superan WCAG AA
(4.5:1) sobre fondo y superficies.

## Tipografía: una función por familia

- **Playfair Display**: titulares y **el francés**. Usa
  `AppTheme.french(context)` para la palabra o frase protagonista. Va en
  color de tinta, no en dorado: es contenido, no adorno.
- **Lato**: toda la interfaz (botones, explicaciones, etiquetas).
- **Crimson Pro en cursiva**: solo la fonética (`AppTheme.ipa`).
- Las descripciones caben en **una línea**. Si necesitan dos, sobra texto.

## Contenedores: cuándo usar tarjeta

1. **Tarjeta** (`AppCard`): una cosa que se toca o que destaca por sí
   misma, como la palabra del día, una lección o un resultado.
2. **Fila** (`ListTile` o `Row` con separador): elementos de una lista del
   mismo tipo, como ajustes, verbos o situaciones del tutor.
3. **Texto en la página**: explicaciones, títulos de sección, metadatos.

Nunca pongas una tarjeta dentro de otra. Si dentro de una tarjeta hace falta
separar algo, usa espacio o un tono `surfaceAlt` sin borde.

En oscuro, las tarjetas se distinguen por ser más claras que el fondo. El
borde es un brillo casi invisible. En claro llevan un borde fino.

## Jerarquía por pantalla

Cada pantalla tiene **un protagonista y una acción principal** (dorada). Lo
demás es secundario: botones con contorno o de texto, o un menú.

## Movimiento y sonido (fase 5)

- Las entradas en cascada usan `Motion.stagger`. Las duraciones salen de
  `Motion.fast/base/slow`, nunca de milisegundos sueltos.
- El perrito respira en reposo, salta al celebrar y se balancea mientras
  piensa. Es el único elemento que "juega".
- Los sonidos son cortos y suaves: acierto, error, sesión completada, racha
  y logro. Los toques normales van en silencio. Se apagan en Ajustes.

## Fases del rediseño

1. Sistema de diseño: color, tipografía, reglas de contenedores y
   navegación. *(v1.8.0)*
2. Inicio: la palabra del día como protagonista, una acción principal y
   "continuar donde lo dejaste".
3. Catálogo y Práctica: sin iconos de marca de agua, progreso por
   categoría, actividades agrupadas y una recomendada.
4. Tutor: guiado frente a libre, situaciones compactas con nivel y
   duración.
5. Mascota animada, sonidos y transiciones.
