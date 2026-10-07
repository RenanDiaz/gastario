# INTENT.md — Gastario

## Intención

Registrar automáticamente cada pago con Apple Pay y cada Yappy (enviado o recibido) en una app nativa de iOS, y poder anotar **en qué fue** cada movimiento cuando yo decida, respondiendo desde la notificación sin abrir la app.

Hoy esto vive en dos automatizaciones de Shortcuts que escriben CSVs en iCloud Drive. Funcionan, pero:
- No puedo anotar el motivo de un gasto después (Ask for Input bloquea y se pierde).
- El parseo de los correos de Yappy en Shortcuts es frágil (regex + Get Group + If, difícil de depurar).
- No hay deduplicación ni forma de revisar o corregir registros.

## Principios rectores

1. **Nunca perder una captura.** Si algo falla (parseo, ubicación, fecha), el movimiento se guarda igual con lo que haya y se marca para revisión. Un registro incompleto siempre es mejor que uno perdido.
2. **Captura primero, parseo después.** Cada intent guarda los datos crudos *antes* de parsear. El parseo es una función pura y re-ejecutable sobre lo crudo. Mejorar el parser debe poder corregir el histórico sin recapturar nada.
3. **Lo que yo edito, el parser no lo pisa.** Un campo corregido a mano nunca se sobrescribe al re-parsear.
4. **Los adjuntos nunca tocan el camino de captura.** Los intents no saben que existen.

## Alcance v1

- App iOS 27, SwiftUI + SwiftData + App Intents + UserNotifications. Solo local, sin backend.
- Dos App Intents invocables desde Shortcuts, ejecutados en segundo plano.
- Notificación local con respuesta de texto por cada movimiento capturado.
- Lista, filtros "Sin nota" y "Requiere revisión", detalle editable, exportar CSV.
- Entrada manual de movimientos (efectivo, tarjeta física, taps que no dispararon la automatización).
- Edición de monto, contraparte y fecha. Borrado de movimientos.
- Re-parsear un movimiento o todos.
- Adjuntos por movimiento: foto, PDF o link (incluye escanear el QR de factura electrónica).
- Auto-export de CSV a iCloud Drive como respaldo.
- Store de SwiftData en **App Group container** desde el día uno.

## Fuera de alcance v1

- Leer Wallet o Mail directamente (FinanceKit no cubre tarjetas de Panamá). La captura sigue en Shortcuts.
- **Share Extension** para adjuntar desde Mail/Files → v1.1. El App Group de v1 la deja preparada.
- Parsear XML de factura electrónica o conciliarla automáticamente con un movimiento.
- Importar CSVs viejos → v1.1, después de validar que la captura nueva no pierde nada.
- Categorías fijas → v2, derivadas de ~2 meses de notas libres reales.
- Sincronización iCloud/CloudKit, widgets, presupuestos, multi-moneda (todo es USD).

## Modelo de datos

> La entidad se llama `Movement`, no `Transaction`, para no chocar con `SwiftUI.Transaction`.

### `Movement`

| Campo | Tipo | Notas |
|---|---|---|
| `id` | UUID | También es el identificador de la notificación |
| `source` | enum `card` \| `yappy` \| `manual` | |
| `direction` | enum `outflow` \| `inflow` | Tarjeta siempre `outflow`. Yappy: "Enviaste" → `outflow`, "Te enviaron" → `inflow` |
| `amount` | `Decimal` | Siempre positivo; el signo lo da `direction`. Nunca `Double` |
| `counterparty` | String? | Comercio (tarjeta) o persona (Yappy) |
| `cardName` | String? | Solo tarjeta |
| `yappyMessage` | String? | Mensaje del Yappy, vacío si no tiene |
| `confirmation` | String? | Solo Yappy. Único cuando existe, garantizado por **fetch explícito** en el intent. **No** usar `@Attribute(.unique)`: hace upsert y sobrescribiría el registro existente, incluida la `note` |
| `occurredAt` | Date | Fecha del Yappy si se pudo parsear; si no, la hora de captura |
| `capturedAt` | Date | Momento en que corrió el intent |
| `city` | String? | |
| `latitude` / `longitude` | Double? | |
| `rawContent` | String? | Cuerpo completo del correo de Yappy |
| `rawInputs` | String? | JSON con los parámetros tal cual llegaron al intent de tarjeta |
| `parseStatus` | enum `ok` \| `partial` \| `failed` | Aplica a `card` y `yappy`. `manual` siempre `ok` |
| `editedFields` | `Set<String>` | Campos corregidos a mano (`amount`, `counterparty`, `occurredAt`). El re-parseo los respeta |
| `note` | String? | La respuesta "en qué gastaste esto" |
| `notedAt` | Date? | |
| `attachments` | `[Attachment]` | Relación con `deleteRule: .cascade` |

### `Attachment`

| Campo | Tipo | Notas |
|---|---|---|
| `id` | UUID | |
| `kind` | enum `image` \| `pdf` \| `link` | |
| `data` | `Data?` | `@Attribute(.externalStorage)`: se guarda como archivo, no infla la base |
| `url` | URL? | Solo `link` |
| `filename` | String? | |
| `addedAt` | Date | |
| `movement` | `Movement?` | Inversa de la relación |

### Persistencia

- `ModelConfiguration` apunta al container del App Group (`group.<bundle-id>`) desde v1. Moverlo después es una migración de datos, justo el riesgo que el principio 1 prohíbe.

## App Intents

### Ambos intents

- Ejecución en segundo plano con la API vigente (`supportedModes = .background` desde iOS 26). **Verificar contra el SDK de iOS 27 antes de implementar.**
- Orden obligatorio:
  1. Guardar crudo.
  2. Parsear.
  3. Actualizar campos y `parseStatus`.
  4. Guardar.
  5. Programar notificación.
  6. Ejecutar el auto-export si corresponde (ver Respaldo).
- Nunca lanzan error hacia Shortcuts por un fallo de parseo: guardan con el `parseStatus` correspondiente.

### `LogCardMovementIntent`

Título visible en Shortcuts: "Log Card Transaction".

Parámetros: `merchant: String`, `amount: String`, `cardName: String`, `city: String?`, `latitude: Double?`, `longitude: Double?`.

- Guardar todos los parámetros recibidos en `rawInputs`.
- **Parseo de monto:**
  - Extraer el primer número con la regex `\d[\d,]*(?:\.\d+)?`, quitar las comas y convertir con `Decimal(string:locale: Locale(identifier: "en_US_POSIX"))`.
  - No basta con "quitar todo lo que no sea dígito o punto": `B/.3.80` quedaría `.3.80`.
  - Formatos a confirmar con capturas reales: `$3.80`, `$1,250.00`, `B/.3.80`, `USD 3.80`.
- **Datos vacíos de Wallet** (la automatización a veces entrega `Merchant` vacío o `Amount = 0`):
  - Monto vacío, no parseable o `0` → `parseStatus = partial`, `amount = 0`.
  - Merchant vacío → `parseStatus = partial`, `counterparty = nil`.
  - Se guarda igual. Nunca se descarta.
- Sin deduplicación: no hay ID de transacción y dos compras iguales seguidas pueden ser reales.

### `LogYappyEmailIntent`

Título visible en Shortcuts: "Log Yappy Email".

Parámetro: `content: String` (cuerpo completo del correo).

**Deduplicación.** Antes de insertar, `FetchDescriptor<Movement>` filtrando por `confirmation`. Si existe → no crear, no modificar el existente, no notificar, devolver éxito.

**Todo el parseo vive en Swift.** Antes de cualquier regex, normalizar U+00A0 y U+202F a espacio normal y `\r\n` a `\n`. El cuerpo trae saltos de línea y líneas vacías entre etiqueta y valor.

| Campo | Regla |
|---|---|
| Dirección | `Enviaste` / `Te enviaron` |
| Monto | Número después de `$` |
| Contraparte | Primera línea no vacía después de `Enviado a` / `Enviado por` |
| Mensaje | Primera línea no vacía después de `Mensaje`, salvo que sea `Confirmación` (entonces vacío) |
| Confirmación | `[A-Z]{5}-\d{8}` |
| Fecha | Ver abajo |

**Fecha** (ej. `04 oct 2026 08:31 a. m.`):
- **No** usar `DateFormatter` con locale `es`: espera `a. m.` con espacios no separables y falla en silencio si el correo trae espacios normales (o al revés).
- Parsear con regex: día, mes contra un mapa `ene…dic` (aceptar también `sept`), año, hora, minuto, `a`/`p`.
- Construir con `DateComponents` y `TimeZone(identifier: "America/Panama")` explícito.
- Si falla → `occurredAt = capturedAt` y `parseStatus = partial`.

## Re-parseo

- Se aplica sobre `rawInputs` / `rawContent`. Movimientos `manual` no se re-parsean.
- Nunca toca `note`, `notedAt`, `attachments` ni los campos listados en `editedFields`.
- "Re-parsear todo" solo procesa movimientos con `parseStatus != ok`.
- El botón "Re-parsear" del detalle funciona en cualquier estado, con la misma regla de `editedFields`.

## Shortcuts resultantes

```
Tarjeta:
When Any Card is tapped
Current Location
Log Card Transaction (Merchant, Amount, Card or Pass, City, Latitude, Longitude)

Yappy:
When I receive an email where Sender is notificaciones@yappy.com.pa
Repeat with each item in [Email]
   Log Yappy Email (Repeat Item → Content)
End Repeat
```

## Notificaciones

- Pedir permiso en el primer arranque.
- Por cada movimiento capturado, notificación local inmediata:
  - Salida: "¿En qué gastaste $3.80 en M/S Betty?"
  - Entrada: "¿Por qué te enviaron $123.20? (Miguel E.)"
  - Tarjeta `partial`: "Pagaste con {cardName}, pero no pude leer {el monto | el comercio}. Complétalo en la app."
  - Yappy `failed`: "No pude leer un Yappy, revísalo en la app."
- Los movimientos `manual` no generan notificación.
- Categoría con `UNTextInputNotificationAction` ("Responder"), **sin** la opción `.foreground`. La respuesta se guarda en `note` sin abrir la app.
- El delegate se registra en un `UIApplicationDelegateAdaptor`, en `application(_:didFinishLaunchingWithOptions:)`. **No** en `.onAppear` ni en el `init` de una vista.
- El `completionHandler` se llama **después** de que el save de `note` termine.

## UI

- **Lista** agrupada por día: contraparte, monto con signo, ícono de fuente, indicadores de "sin nota" y "requiere revisión".
  - Botón "+" para entrada manual.
  - Swipe para borrar, con confirmación.
- **Filtros:** "Sin nota" y "Requiere revisión" (`parseStatus != ok`).
- **Detalle:**
  - Todos los campos. Link a Maps si hay coordenadas. Cuerpo crudo (Yappy).
  - Monto, contraparte y fecha editables. Editar un campo lo agrega a `editedFields`. Si el movimiento era `partial` y quedan resueltos los campos faltantes, pasa a `ok`.
  - Nota editable.
  - Botón "Re-parsear" en movimientos `card`/`yappy`.
  - Sección de adjuntos:
    - Foto con `PhotosPicker` o cámara.
    - PDF con `.fileImporter` (`UTType.pdf`).
    - Link con campo de texto validado.
    - Escanear QR con `DataScannerViewController` → se guarda como `link`.
    - Ver con `QuickLookPreview`, abrir links con `Link`.
- **Resumen** del mes: total salidas, total entradas, neto.
- **Ajustes:** "Re-parsear todo", fecha del último auto-export, "Exportar ahora".

## Respaldo

- **Auto-export:** si pasaron 7+ días desde el último, escribir el CSV completo a la carpeta de la app en iCloud Drive.
  - Se evalúa **al final de cada intent y al abrir la app**. Solo al abrir no basta: el flujo normal es responder desde la notificación, y la app puede pasar semanas sin abrirse.
  - Un fallo del export nunca afecta la captura: se registra la fecha del último intento fallido y se reintenta en la siguiente ejecución.
  - Requiere la capability de iCloud Documents (ubiquity container). No es CloudKit.
- **Transición:** durante las primeras 2–3 semanas, los Shortcuts viejos siguen escribiendo sus CSVs **en paralelo**, dentro del mismo atajo:
  - El `Append to Text File` va **antes** de la llamada al intent. Si el intent falla, el atajo se detiene y el CSV tiene que haberse escrito ya.
  - Al final del período, comparar conteos por día entre ambos. Solo entonces se retiran los Append.

## Exportar CSV

- Una fila por movimiento, montos con signo.
- Columnas: `occurredAt`, `capturedAt`, `source`, `direction`, `amount`, `counterparty`, `cardName`, `yappyMessage`, `confirmation`, `city`, `latitude`, `longitude`, `note`, `parseStatus`, `attachmentCount`.
- Los archivos adjuntos **no** se exportan.

## Criterios de aceptación

1. **Captura de tarjeta.** Dado que pago con Apple Pay, cuando corre la automatización, entonces se crea un movimiento `card`/`outflow` con monto `Decimal` correcto y llega la notificación de pregunta.
2. **Montos con formato.** `"$1,250.00"` se guarda como `1250.00` y `"B/.3.80"` como `3.80`.
3. **Yappy enviado.** Dado un correo "Enviaste" con mensaje, se guardan dirección, monto, contraparte **sin** "Enviado a", mensaje **sin** la palabra "Mensaje", confirmación y fecha del Yappy.
4. **Yappy sin mensaje.** `yappyMessage` queda vacío, nunca "Confirmación".
5. **Dos correos a la vez.** Llegan dos correos juntos → se crean dos movimientos separados.
6. **Duplicado.** Mismo `confirmation` procesado dos veces → un solo movimiento, una sola notificación, y si el primero ya tenía `note`, la `note` no se modifica.
7. **Parseo fallido.** Correo con formato inesperado → se guarda con `rawContent` y `parseStatus = failed`, y llega la notificación de revisión.
8. **Responder después.** Dejo la notificación sin tocar varias horas, respondo desde el Centro de Notificaciones → `note` y `notedAt` quedan guardados sin abrir la app, **incluso si la app fue cerrada desde el app switcher**.
9. **Respaldo de notas.** Si borro la notificación sin responder, el movimiento aparece en el filtro "Sin nota".
10. **Sin ubicación.** Si no hay ubicación, el movimiento se guarda igual con esos campos vacíos.
11. **Exportar.** El CSV exportado abre en Numbers con una fila por movimiento y montos con signo.
12. **Tarjeta con datos vacíos.** Si la automatización entrega `Amount = 0` o `Merchant` vacío → se guarda con `parseStatus = partial` y llega la notificación de completar.
13. **Resolver parcial.** Edito el monto de un movimiento `partial` en el detalle → queda guardado y el movimiento sale de "Requiere revisión".
14. **Entrada manual.** Creo un movimiento desde "+" → aparece en la lista con `source = manual` y no genera notificación.
15. **Borrar.** Borro un movimiento con adjuntos → desaparecen el movimiento y sus adjuntos.
16. **Fecha con espacio no separable.** Un correo con `08:31 a. m.` usando U+00A0 o U+202F → `occurredAt` correcto, `parseStatus = ok`.
17. **Re-parsear.** Corrijo el parser, ejecuto "Re-parsear todo" → los movimientos `partial`/`failed` que ahora parsean bien pasan a `ok`, sin perder la `note` ni los adjuntos.
18. **Edición protegida.** Corrijo a mano el monto de un movimiento y luego lo re-parseo → el monto editado se conserva.
19. **Adjunto persistente.** Adjunto un PDF de 5 MB, cierro y abro la app → el PDF sigue ahí y abre en Quick Look.
20. **QR de factura.** Escaneo el QR de una factura electrónica → se guarda como adjunto `link` y abre en Safari.
21. **Auto-export sin abrir la app.** Pasan 7+ días sin abrir la app y llega una captura → aparece un CSV nuevo en iCloud Drive.

## Pruebas

- **Parser de Yappy** con fixtures de **cuerpos reales** (copiados vía la vista de cuerpo crudo): enviado con mensaje, enviado sin mensaje, recibido, monto con coma.
- **Fixtures de fecha:** con espacio normal, con U+00A0 y con U+202F.
- **Parser de montos de tarjeta:** `$3.80`, `$1,250.00`, `B/.3.80`, `USD 3.80`, `""`, `"$0.00"`. Agregar los formatos reales que se observen en dispositivo.
- **Deduplicación:** con un `ModelContainer` en memoria, procesar el mismo correo dos veces → un solo `Movement`, `note` intacta.
- **Re-parseo:** un `Movement` con datos crudos y campos corruptos → re-parsear restaura los campos y conserva `note`, `attachments` y los campos en `editedFields`.
- **Prueba manual en dispositivo:** 1, 5, 8 (con la app cerrada desde el switcher), 12, 19 y 21.

## Restricciones

- Requiere cuenta de Apple Developer pagada para uso diario (con cuenta gratis la app expira a los 7 días).
- Requiere capabilities: App Groups e iCloud Documents.
- Los triggers de Shortcuts en iOS 27 son bloques dentro del atajo. La salida del trigger de email es `Email`, **no** `Shortcut Input`.
- El trigger de Wallet se dispara con el **tap**, no con la aprobación. Un pago rechazado igual genera un movimiento → se borra a mano.
- El trigger puede no disparar o llegar con datos vacíos. La entrada manual y el estado `partial` cubren ambos casos.

## Decisiones

| Pregunta | Decisión |
|---|---|
| ¿Importar CSVs existentes en v1? | No. v1.1, después del período en paralelo. Se implementa como un parser más que asigna `parseStatus` |
| ¿Categorías fijas? | No en v1. Derivarlas de ~2 meses de notas reales. En v2, evaluar sugerencia on-device con Foundation Models |
| ¿Sincronización iCloud en v2? | Solo si el auto-export no basta |
| Nombre de la app | **Gastario** |
