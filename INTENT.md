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

- App iOS (deployment target 26.0, se usa en iOS 27), SwiftUI + SwiftData + App Intents + UserNotifications. Solo local, sin backend.
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
- Parsear XML de factura electrónica o conciliarla automáticamente con un movimiento → candidato v1.1, ver [v1.1 — Facturas por correo](#v11--facturas-por-correo-candidato).
- Importar CSVs viejos → v1.1, después de validar que la captura nueva no pierde nada.
- Categorías fijas → v2, ver [v2 — Clasificación](#v2--clasificación).
- Sincronización iCloud/CloudKit, widgets, presupuestos, multi-moneda (todo es USD).

## Modelo de datos

> La entidad se llama `Movement`, no `Transaction`, para no chocar con `SwiftUI.Transaction`.

### `Movement`

| Campo | Tipo | Notas |
|---|---|---|
| `id` | UUID | También es el identificador de la notificación |
| `source` | enum `card` \| `yappy` \| `manual` | |
| `direction` | enum `outflow` \| `inflow` | Tarjeta siempre `outflow`. Yappy: "Enviaste" y "Pagaste" → `outflow`; "Te enviaron" y Yappy Comercial → `inflow` |
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

- Ejecución en segundo plano con la API vigente (`supportedModes = .background` desde iOS 26). **Verificar contra el SDK con que se compila (Xcode 26.x) antes de implementar.**
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

Parámetro: `content: String` (cuerpo completo del correo). `Content` en Shortcuts entrega el cuerpo **en HTML o en texto plano** según el correo (visto en dispositivo: "Enviaste" llegó en HTML y "Pagaste" en texto). Se guarda tal cual en `rawContent`; el parser acepta ambos y convierte el HTML a texto.

**Deduplicación.** Antes de insertar, `FetchDescriptor<Movement>` filtrando por `confirmation` **y** `direction`. Si existe → no crear, no modificar el existente, no notificar, devolver éxito. La dirección entra en la clave porque un pago de la cuenta personal a Yappy Comercial llega dos veces con la misma confirmación: como `outflow` ("Pagaste") y como `inflow` ("Recibiste una compra en línea"). Son dos movimientos.

**Todo el parseo vive en Swift.** Antes de cualquier regex, normalizar U+00A0 y U+202F a espacio normal y `\r\n` a `\n`. El cuerpo trae saltos de línea y líneas vacías entre etiqueta y valor.

| Campo | Regla |
|---|---|
| Dirección | `Enviaste` / `Pagaste` → `outflow`; `Te enviaron` / Yappy Comercial (`ha recibido un pago por Yappy`, `Recibiste una compra en línea por Yappy`) → `inflow` |
| Monto | Número después de `$` |
| Contraparte | Primera línea no vacía después de `Enviado a` / `Enviado por` / `Pagado a`. Yappy Comercial: valor de `Cliente:` |
| Mensaje | Primera línea no vacía después de `Mensaje`, salvo que sea `Confirmación` (entonces vacío). Yappy Comercial: valor de `Comentario:`; si no hay, `Pedido <Número de pedido>` |
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
When I receive an email (cualquier remitente)
Repeat with each item in [Email]
   If Repeat Item → Sender is notificaciones@yappy.com.pa
      Log Yappy Email (Repeat Item → Content)
   End If
End Repeat
```

## Notificaciones

- Pedir permiso en el primer arranque.
- Por cada movimiento capturado, notificación local inmediata:
  - Salida: "¿En qué gastaste $3.80 en M/S Betty?"
  - Entrada: "¿Por qué te enviaron $123.20? (Miguel E.)"
  - Tarjeta `partial`: "Pagaste con {cardName}, pero no pude leer {el monto | el comercio}. Complétalo en la app."
  - Yappy `failed`: "No pude leer un Yappy, revísalo en la app."
  - Tarjeta `failed`: "No pude leer un pago con tarjeta, revísalo en la app."
  - Sin contraparte, la pregunta va sin el "en …": "¿En qué gastaste $49.06?"
  - Títulos: "Gasto", "Ingreso" y, para completar o revisar, "Revisar movimiento".
- Los movimientos `manual` no generan notificación.
- Categoría con `UNTextInputNotificationAction` ("Responder"), **sin** la opción `.foreground`. La respuesta se guarda en `note` sin abrir la app.
- Tocar la notificación abre la app en el detalle del movimiento, con el editor abierto y el cursor en la nota.
- El delegate se registra en un `UIApplicationDelegateAdaptor`, en `application(_:didFinishLaunchingWithOptions:)`. **No** en `.onAppear` ni en el `init` de una vista.
- El `completionHandler` se llama **después** de que el save de `note` termine, y **en el hilo principal**: al tocar la notificación, UIKit lo exige y de lo contrario la app muere al abrirse.

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
    - Ver con `QuickLookPreview`; los links abren dentro de la app con `SFSafariViewController`, sin dejar pestañas en Safari.
- **Resumen** del mes: total salidas, total entradas, neto.
- **Ajustes:** "Re-parsear todo", fecha del último auto-export, "Exportar ahora" y la bitácora de captura (ver Respaldo).

## Respaldo

- **Auto-export:** si pasaron 7+ días desde el último, escribir el CSV completo a la carpeta de la app en iCloud Drive.
  - Se evalúa **al final de cada intent y al abrir la app**. Solo al abrir no basta: el flujo normal es responder desde la notificación, y la app puede pasar semanas sin abrirse.
  - Un fallo del export nunca afecta la captura: se registra la fecha del último intento fallido y se reintenta en la siguiente ejecución.
  - Requiere la capability de iCloud Documents (ubiquity container). No es CloudKit.
- **Transición:** durante las primeras 2–3 semanas, los Shortcuts viejos siguen escribiendo sus CSVs **en paralelo**, dentro del mismo atajo:
  - El `Append to Text File` va **antes** de la llamada al intent. Si el intent falla, el atajo se detiene y el CSV tiene que haberse escrito ya.
  - Al final del período, comparar conteos por día entre ambos. Solo entonces se retiran los Append.
- **Bitácora de captura:** cada invocación de los intents deja una línea por paso (recibido, crudo guardado, guardado, error, terminado) en un archivo del App Group, **fuera de SwiftData**, y cada borrado hecho desde la app también. Si una captura se pierde, dice en qué paso murió o si se borró a mano. Nunca hace fallar una captura. Se ve y se comparte desde Ajustes; se conservan 3 meses.

## Exportar CSV

- Una fila por movimiento, montos con signo.
- Columnas: `occurredAt`, `capturedAt`, `source`, `direction`, `amount`, `counterparty`, `cardName`, `yappyMessage`, `confirmation`, `city`, `latitude`, `longitude`, `note`, `parseStatus`, `attachmentCount`.
- Los archivos adjuntos **no** se exportan.

## v1.1 — Facturas por correo (candidato)

Con la factura electrónica, muchos comercios de Panamá envían la factura por correo después de la compra. Gastario debería **atrapar esos correos y asignar la factura al movimiento** sin que yo la busque y la adjunte a mano. Hoy el adjunto de factura es manual (escanear el QR o importar el PDF) y casi nunca lo voy a hacer en el momento.

Ya está la mitad del camino:
- El atajo de Yappy corre con **cada** correo que llega, sin filtro de remitente (ver [Restricciones](#restricciones)). Atrapar facturas es agregar una rama a ese `If`, no un trigger nuevo.
- Ya se vio en el dispositivo un recibo de comercio llegando junto con un Yappy: hoy el `If` lo descarta.
- El adjunto `link` con la URL de consulta de la DGI ya existe (AC-20), igual que la conversión de HTML a texto del parser de Yappy.

### Principios

- **La factura es su propia captura**, con su propio intent. Los intents de tarjeta y Yappy no cambian (principio 4): la asignación corre del lado de la factura.
- **Nunca perder una factura (1).** Una factura que no parsea o no calza con ningún movimiento queda en una bandeja "Facturas sin asignar"; nunca se descarta.
- **Captura primero (2).** Se guarda el cuerpo crudo antes de parsear. Parseo y asignación son re-ejecutables.
- **Lo que asigno a mano no lo pisa el matcher (3).** Confirmar, desasignar o descartar una factura la bloquea.
- **Un correo que no es factura no se guarda.** El atajo le pasa a Gastario cada correo que no es de Yappy; Gastario decide en Swift si es factura (no en Atajos, por la misma razón que el parseo de Yappy vive en Swift). Si no lo es, se descarta sin guardar el cuerpo. Mis correos personales no terminan en el store.

### Resultado esperado

1. Llega un correo de factura → se guarda como factura con su cuerpo crudo.
2. Si hay **un solo** movimiento de salida (tarjeta, Yappy o manual) que calza por monto exacto y ventana de tiempo → se asigna solo.
3. Si hay varios candidatos o ninguno exacto (propina, pago dividido) → queda como sugerencia y la confirmo con un toque.
4. En el detalle del movimiento veo la factura y abro el link de la DGI dentro de la app, como cualquier link adjunto.

### Lo que no sabemos (spike S1 en `SPEC.md`)

- Qué remitentes envían facturas (comercio, PAC o ambos) y si el asunto o el remitente bastan para reconocerlas.
- Si `Content` trae CUFE, total, RUC, fecha y link de la DGI, o si eso vive solo en el PDF (CAFE) o el XML adjunto, y si Atajos expone los adjuntos del `Email`.
- Si el total de la factura coincide con lo cobrado (propina, pago dividido) y cuánto tarda el correo en llegar.
- Si el nombre del emisor se parece al `counterparty` de Wallet. Probablemente no: la asignación va por monto y hora.
- Cuánto cuesta (batería, tiempo) que el intent corra con cada correo que no es de Yappy.

## v2 — Clasificación

Saber de qué tipo es cada movimiento y en qué categoría cae, para cruzarlo con los topes del presupuesto. La captura no cambia: clasificar nunca bloquea ni retrasa guardar un movimiento (principio 1).

### Tipo (`kind`)

| `kind` | Qué es | `direction` permitida | ¿Suma en el resumen? |
|---|---|---|---|
| `expense` | Gasto variable propio | `outflow` | Sí, como salida |
| `fixed_expense` | Gasto fijo | `outflow` | Sí, como salida |
| `debt_payment` | Cuota de un préstamo o de una tarjeta | `outflow` | Sí, como salida |
| `reimbursable` | Pagué algo por otro y me lo devuelven; la devolución lleva el mismo `kind` | ambas | No |
| `loan` | Presté o me prestaron | ambas | No |
| `passthrough` | Pasamanos: me llega y lo paso tal cual | ambas | No |
| `transfer` | Entre mis propias cuentas | ambas | No |
| `income` | Ingreso real | `inflow` | Sí, como entrada |

- `kind` es opcional en el modelo. Sin `kind`, el movimiento está **por clasificar** y suma en el resumen según su `direction`, como en v1.
- Quién reembolsa, a quién se prestó, etc. va en la contraparte o en la nota, no en el `kind`.

### Categoría

Solo para `expense` y `fixed_expense`; en esos dos es obligatoria al clasificar. La subcategoría es opcional y solo existe en Transporte.

- **`expense`:** Supermercado, Comida fuera, Ocio, Salud, Ropa/compras, Mascotas, Transporte {Gasolina, Parking, Placa y trámites, Mantenimiento}, Aporte al hogar, Otros.
  - **Fuera del presupuesto:** Proyectos, Música. Suman en el resumen como cualquier gasto, pero no se cruzan con los topes.
- **`fixed_expense`:** Servicios, Suscripciones, Seguros, Cargos bancarios.

La lista es fija en el código (enums con `String` raw value). Cambiarla es un cambio de spec.

### Modelo

- `Movement` agrega `kind`, `category` y `subcategory`, opcionales.
- `Allocation` (nuevo): parte de un movimiento dividido. `id`, `amount: Decimal`, `kind`, `category`, `subcategory`, `movement` (inversa, `deleteRule: .cascade` desde `Movement`).
- `ClassificationRule` (nuevo): `counterpartyKey` (normalizado, único por fetch explícito), `kind`, `category`, `subcategory`, `updatedAt`.
- El re-parseo nunca toca `kind`, `category`, `subcategory` ni las partes (principio 3 extendido).

### Dividir un movimiento

- El movimiento sigue siendo uno: un monto, un crudo, una nota, sus adjuntos. Se divide en N partes, cada una con su `kind` y categoría.
- No se puede guardar una división cuyas partes no sumen exactamente el monto.
- Con partes, la clasificación del movimiento son sus partes: `kind`/`category` del movimiento quedan vacíos.
- Los totales suman por parte.
- Si un re-parseo cambia el monto y las partes dejan de sumar, no se borra nada: el movimiento pasa a "Requiere revisión" hasta que se corrija la división.

### Reglas y sugerencias

- `counterparty` se normaliza para comparar: mayúsculas, sin prefijos numéricos, sin sufijos de sucursal. Las reglas exactas salen de contrapartes reales.
- **Tarjeta:** al clasificar un movimiento, se guarda o actualiza la regla `counterpartyKey → (kind, category, subcategory)`. Si se clasifica distinto, gana la última.
- **Yappy:** no se guardan reglas por persona. Se sugiere solo si las últimas 3 clasificaciones de esa contraparte en Yappy fueron iguales.
- **Siempre es una sugerencia.** Nunca se aplica sola.
- **Dónde aparece:**
  - En el detalle, con un botón "Aplicar".
  - En la notificación, como botón "✓ <categoría o tipo>" junto a "Responder", **sin** `.foreground`: clasifica sin abrir la app, incluso con la app terminada, igual que la respuesta (AC-8). Como iOS fija los botones por categoría de notificación, se registra una categoría por cada combinación de `kind` y categoría.
- Buscar la regla al programar la notificación nunca afecta la captura: si falla, la notificación sale sin sugerencia.

### UI

- Filtro **"Por clasificar"**: movimientos sin `kind` y sin partes, o con alguna parte sin `kind`.
- Editor: `kind` (solo los permitidos para la `direction`), categoría y subcategoría. No guarda un `expense`/`fixed_expense` sin categoría.
- Detalle: clasificación, sugerencia con "Aplicar" y "Dividir".

### Exportar CSV (v2)

- Columnas nuevas: `id` (primera), `kind`, `category`, `subcategory`, `splitGroupId`.
- `id` es único por fila y estable entre exports: el del movimiento o, si está dividido, el de cada parte.
- Un movimiento dividido sale como una fila por parte: `amount` con signo de la parte, su clasificación, y `splitGroupId` = `id` del movimiento. Los demás campos se repiten. Sin división, `splitGroupId` va vacío.

## Criterios de aceptación

1. **Captura de tarjeta.** Dado que pago con Apple Pay, cuando corre la automatización, entonces se crea un movimiento `card`/`outflow` con monto `Decimal` correcto y llega la notificación de pregunta.
2. **Montos con formato.** `"$1,250.00"` se guarda como `1250.00` y `"B/.3.80"` como `3.80`.
3. **Yappy enviado.** Dado un correo "Enviaste" con mensaje, se guardan dirección, monto, contraparte **sin** "Enviado a", mensaje **sin** la palabra "Mensaje", confirmación y fecha del Yappy.
4. **Yappy sin mensaje.** `yappyMessage` queda vacío, nunca "Confirmación".
5. **Dos correos a la vez.** Llegan dos correos juntos → se crean dos movimientos separados.
6. **Duplicado.** Mismo `confirmation` y `direction` procesados dos veces → un solo movimiento, una sola notificación, y si el primero ya tenía `note`, la `note` no se modifica.
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
20. **QR de factura.** Escaneo el QR de una factura electrónica → se guarda como adjunto `link` y abre dentro de la app (`SFSafariViewController`).
21. **Auto-export sin abrir la app.** Pasan 7+ días sin abrir la app y llega una captura → aparece un CSV nuevo en iCloud Drive.

### v2

22. **Por clasificar.** Los movimientos existentes y toda captura nueva quedan sin `kind` y aparecen en "Por clasificar". Ninguna captura se bloquea ni se retrasa por no estar clasificada.
23. **Gasto sin categoría.** En el editor, un `expense` o `fixed_expense` sin categoría no se puede guardar.
24. **Tipo y dirección.** El editor solo ofrece los `kind` permitidos para la `direction` del movimiento (o de la parte).
25. **Totales.** Un `passthrough`, `loan`, `transfer` o `reimbursable` no suma ni a entradas ni a salidas en ningún total. Un movimiento dividido suma por parte.
26. **Sugerencia, nunca silenciosa.** Clasifico una compra en un comercio; la siguiente captura del mismo comercio (normalizado) llega con el botón de sugerencia y la muestra en el detalle, pero sigue sin `kind` hasta que la acepto.
27. **Clasificar desde la notificación.** Toco "✓ Supermercado" con la app cerrada desde el switcher → el movimiento queda `expense`/Supermercado sin abrir la app.
28. **Yappy sin regla.** Una persona clasificada igual menos de 3 veces seguidas no genera sugerencia.
29. **División que no suma.** Al guardar, se rechaza una división cuyas partes no suman el monto.
30. **Re-parseo con división.** Si un re-parseo cambia el monto de un movimiento dividido, las partes se conservan y el movimiento aparece en "Requiere revisión".
31. **Export v2.** El CSV trae `id`, `kind`, `category`, `subcategory` y `splitGroupId`; un movimiento dividido en 2 sale como 2 filas con el mismo `splitGroupId` y montos que suman el original.

## Pruebas

- **Parser de Yappy** con fixtures de **cuerpos reales**: enviado con mensaje, enviado sin mensaje, recibido, pago a comercio (con y sin mensaje), Yappy Comercial (recibido y compra en línea), monto con coma.
- **Fixtures de fecha:** con espacio normal, con U+00A0 y con U+202F.
- **Parser de montos de tarjeta:** `$3.80`, `$1,250.00`, `B/.3.80`, `USD 3.80`, `""`, `"$0.00"`. Agregar los formatos reales que se observen en dispositivo.
- **Deduplicación:** con un `ModelContainer` en memoria, procesar el mismo correo dos veces → un solo `Movement`, `note` intacta.
- **Re-parseo:** un `Movement` con datos crudos y campos corruptos → re-parsear restaura los campos y conserva `note`, `attachments` y los campos en `editedFields`.
- **Prueba manual en dispositivo:** 1, 5, 8 (con la app cerrada desde el switcher), 12, 19 y 21.

## Restricciones

- Requiere cuenta de Apple Developer pagada para uso diario (con cuenta gratis la app expira a los 7 días).
- Requiere capabilities: App Groups e iCloud Documents.
- Los triggers de Shortcuts en iOS 27 son bloques dentro del atajo. La salida del trigger de email es `Email`, **no** `Shortcut Input`.
- El trigger de email no filtra por remitente: `Email` trae todos los correos del lote y el remitente se valida dentro del `Repeat`. Visto en dispositivo:
  - con filtro en el trigger, un Yappy que llegó **después** de otro correo en el mismo lote no disparó el atajo y se perdió;
  - sin el `If`, el recibo de un comercio que llegó junto con el Yappy entró como movimiento `failed`.
- El trigger de Wallet se dispara con el **tap**, no con la aprobación. Un pago rechazado igual genera un movimiento → se borra a mano.
- El trigger puede no disparar o llegar con datos vacíos. La entrada manual y el estado `partial` cubren ambos casos.

## Decisiones

| Pregunta | Decisión |
|---|---|
| ¿Importar CSVs existentes en v1? | No. v1.1, después del período en paralelo. Se implementa como un parser más que asigna `parseStatus` |
| ¿Categorías fijas? | No en v1. En v2, lista fija tomada de los topes del presupuesto, con `kind` aparte; ver [v2 — Clasificación](#v2--clasificación). Sugerencia por reglas de comercio, no con Foundation Models |
| ¿Sincronización iCloud en v2? | Solo si el auto-export no basta |
| Nombre de la app | **Gastario** |
| ¿Yappy Comercial (cuenta del negocio)? | Se registra como `inflow`. La deduplicación usa `confirmation` + `direction` para no perder el lado personal de un pago al propio negocio |
