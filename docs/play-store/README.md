# Lanzamiento en Google Play

Todo lo que hay que hacer fuera del código para publicar FrenchPass, en orden.
Lo que ya está hecho en el código va al final.

## 1. Firebase (la IA sin clave en la app)

1. Entra en <https://console.firebase.google.com>, crea el proyecto
   **FrenchPass** (Google Analytics no hace falta).
2. Añade una app **Android** con el paquete `com.frenchpass.french_pass`.
   Luego añade otra con `com.frenchpass.french_pass.dev` (la versión de
   GitHub). Descarga `google-services.json` **después** de registrar las dos:
   así el archivo trae ambas.
3. Copia ese archivo a `android/app/google-services.json` en tu PC. Git lo
   ignora, no se sube.
4. En GitHub: *Settings › Secrets and variables › Actions › New repository
   secret*, nombre `GOOGLE_SERVICES_JSON`, y pega el contenido completo del
   archivo. Sin este secreto el workflow falla a propósito.
5. En Firebase: **AI Logic › Get started › Gemini Developer API**. Firebase
   crea y guarda la clave de Gemini; tú no la ves ni la necesitas.
6. **Plan:** durante las pruebas basta el plan gratuito (Spark) con el
   nivel gratuito de Gemini; no hace falta tarjeta. Tiene tres condiciones:
   - la cuota es una sola para todo el proyecto, así que con muchos usuarios
     a la vez aparecerá «Hay mucha gente usando la IA»;
   - Google puede usar lo enviado para entrenar sus modelos (ya está dicho
     en la política de privacidad);
   - las condiciones de Gemini prohíben el nivel gratuito en apps para
     usuarios del Espacio Económico Europeo, Reino Unido y Suiza: excluye
     esos países en Play Console (paso 3.5).
   Antes de abrir la app al público, pasa a **Blaze** con una alerta de
   presupuesto y con la suscripción Premium ya funcionando.
7. **App Check**:
   - App `…french_pass.dev`: proveedor *Debug*. Abre la versión de GitHub en
     tu teléfono, ve a Ajustes, copia el «Token de App Check» y pégalo en
     *App Check › Apps › Manage debug tokens*.
   - App `…french_pass`: proveedor *Play Integrity*. Pide la huella SHA-256
     de la **clave de firma de apps** de Play (Play Console › Integridad de
     la app › Firma de apps), que existe cuando subes el primer AAB.
   - Cuando las dos funcionen, activa **Enforce** para Firebase AI Logic.
     Desde el 2 de noviembre de 2026 Firebase lo exige igualmente.
8. Baja el límite por usuario: Google Cloud Console › API «Firebase AI
   Logic» › Cuotas › *Generate content requests per minute per user*. El
   valor por defecto (100) es alto; 15 sobra para esta app.

## 2. Política de privacidad (URL pública)

1. El correo de contacto ya está puesto: frenchpass07@gmail.com.
2. GitHub › *Settings › Pages › Deploy from a branch › main / docs*.
3. La URL será `https://luisfnarvaez01.github.io/FrenchPass/privacidad.html`.

## 3. Play Console

1. **Crear app**: nombre *FrenchPass*, idioma predeterminado español
   (Latinoamérica), app, gratuita.
2. **Prueba interna** primero: sube el AAB (`play-bundle`, en los artifacts
   de la ejecución del workflow en GitHub Actions) y compruébalo tú. Así
   obtienes la SHA-256 para App Check (paso 1.7) y ves el tutor funcionando
   con Play Integrity.
3. **Prueba cerrada, 14 días con 12 testers**: obligatoria para cuentas
   personales nuevas antes de producción. Los 12 tienen que seguir inscritos
   los 14 días seguidos. Empieza a reunirlos ya.
4. **Acceso a producción**: se solicita al terminar la prueba cerrada.
5. **Países**: mientras uses el nivel gratuito de Gemini, en *Alcance y
   dispositivos › Países/regiones* quita los del Espacio Económico Europeo,
   Reino Unido y Suiza.

### Contenido de la app (formularios)

| Formulario | Respuesta |
|---|---|
| Política de privacidad | La URL del paso 2 |
| Anuncios | No contiene anuncios |
| Acceso a la app | Todas las funciones sin restricciones (no hay login) |
| Clasificación de contenido | Categoría «Referencia, noticias o educativa». Hay interacción con IA generativa: márcalo cuando lo pregunte |
| Público objetivo | 13 años o más. No la marques para niños: entrarías en el programa de familias, con reglas más duras sobre IA y datos |
| Apps gubernamentales, financieras, de salud, de noticias | No |
| Servicios en primer plano | No aplica (el permiso genérico lo añade WorkManager para el widget) |

### Seguridad de los datos

Datos que salen del teléfono (todos cifrados en tránsito; no se comparten con
terceros con fines propios: Google actúa como proveedor del servicio):

| Tipo de dato | ¿Recopilado? | Uso | ¿Opcional? |
|---|---|---|---|
| Audio › Grabaciones de voz | Sí | Funcionalidad de la app (tutor) | Sí, solo si usas el tutor |
| Actividad › Otro contenido generado por el usuario (texto del traductor, transcripciones) | Sí | Funcionalidad de la app | Sí |
| Identificadores del dispositivo | Revisa lo que declara Firebase para App Check en <https://firebase.google.com/docs/android/play-data-disclosure> | Prevención de fraude y seguridad | No |

- ¿Se pueden eliminar los datos? Sí: «Borrar mis datos» en Ajustes, o
  desinstalar. No hay servidor propio con copias.
- No hay cuenta de usuario, ni ubicación, ni contactos, ni datos de pago.

### Ficha de Play Store

**Nombre** (máx. 30): `FrenchPass: francés con IA`

**Descripción breve** (máx. 80):
`Habla francés con un tutor de voz que te corrige sin cortar la charla.`

**Descripción completa** (máx. 4000):

```
FrenchPass es para hispanohablantes que quieren hablar francés, no solo
leerlo.

El tutor conversa contigo por voz en situaciones reales: pedir en un café,
presentarte, preguntar por una calle. Habla en francés, a tu nivel, y cuando
te equivocas no te interrumpe: la corrección aparece escrita debajo de tu
frase, con la explicación en español. Si te bloqueas, pulsas «No sé cómo
decirlo» y te da una frase para seguir.

Al terminar puedes repasar la conversación frase por frase: escucharla otra
vez, ver cada palabra con su pronunciación y su significado, y aprender
cómo podrías haber respondido, de lo más sencillo a lo más natural.

También incluye:
- Un traductor que no se queda en traducir: te desarma la frase palabra por
  palabra y te enseña otras formas de decirla según con quién hables.
- La palabra del día, con audio y un widget para tu pantalla de inicio.
- Práctica de pronunciación con puntuación.
- Quiz con repaso espaciado, para que vuelvas a cada palabra justo cuando
  la estás olvidando.
- Tu racha y tu progreso, guardados en tu teléfono.

No necesitas cuenta. La app no tiene anuncios.

El tutor, el traductor y el repaso usan Gemini, la IA de Google, así que
necesitan conexión a internet.
```

**Gráficos** (en esta carpeta, se regeneran con
`python scripts/make_store_assets.py`):

- `icon-512.png`: ícono de 512×512.
- `feature-graphic.png`: gráfico destacado de 1024×500.
- Capturas: entre 2 y 8, tomadas en tu teléfono (inicio, tutor en plena
  conversación con una corrección visible, repaso palabra por palabra,
  traductor, progreso).

## 4. Decisiones pendientes

- **Derechos de la imagen del perrito.** Es una foto que circula como meme.
  Si no es tuya ni tienes permiso, Play puede rechazar la app por propiedad
  intelectual. La salida segura es una ilustración propia del mismo
  personaje.
- **Tope de uso diario.** Cada minuto de voz con el tutor cuesta. Como App
  Check garantiza que las peticiones vienen de tu app, un límite dentro de
  la app (por ejemplo, 20 minutos de tutor y 50 traducciones al día) sí
  protege tu factura. Falta decidir las cifras.

## Ya hecho en el código

- La app no lleva ni pide clave de Gemini: usa Firebase AI Logic con App
  Check.
- Dos versiones: `play` (sin autoactualización ni permiso para instalar
  paquetes, que Play prohíbe) y `github` (paquete `.dev`, con actualizador
  y token de depuración de App Check).
- `targetSdk` 36, como exige Play desde el 31 de agosto de 2026.
- El workflow genera el AAB de Play ofuscado, con los símbolos para leer
  los errores.
- `google-services.json` fuera del repositorio público.
