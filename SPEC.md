# SPEC.md — Gastario v1, plan de implementación por fases

`INTENT.md` define **qué** se construye y **por qué**. Este documento define **cómo** y **en qué orden**. Si hay conflicto, gana `INTENT.md`, salvo en los puntos marcados como **Cambio propuesto** (sección 2), que deben confirmarse antes de la fase que los usa.

## 1. Cómo usar este documento

- Cada fase es una unidad de trabajo cerrada para un agente de código: tiene objetivo, alcance, entregables, criterios y un **gate de salida**. No se abre una fase sin cerrar el gate de la anterior.
- Una fase = una rama (`phase-N-<slug>`) = un PR. El PR enlaza la sección de la fase y marca el checklist del gate.
- `AC-n` referencia el criterio de aceptación `n` de `INTENT.md`.
- Las verificaciones marcadas 📱 requieren dispositivo físico y las hace la persona, no el agente. El agente deja listo todo lo que se puede verificar con `swift test` o en simulador.
- Prioridad de orden: primero lo que **protege la captura** (principio 1), después lo que la hace útil, al final lo que es accesorio (adjuntos).

## 2. Cambios propuestos a INTENT.md

Huecos encontrados al convertir el intent en fases. Cada uno tiene una decisión por defecto; si no se objeta, se implementa así.

| # | Hueco | Decisión por defecto | Fase |
|---|---|---|---|
| C1 | La regla "si un `partial` resuelve los campos faltantes pasa a `ok`" necesita saber **qué** faltó. No se puede derivar de los datos (una fecha fallida es indistinguible de una captura sin fecha). | Agregar `parseIssues: Set<ParseIssue>` a `Movement`. `ParseIssue` = `amount`, `counterparty`, `occurredAt`, `confirmation`, `direction`. El parser la llena; editar un campo quita su issue; `parseIssues.isEmpty` → `ok`. También alimenta el texto de la notificación de tarjeta `partial` ("no pude leer el monto / el comercio"). | 0 |
| C2 | `editedFields: Set<String>` acepta cualquier string. | Tiparlo como `Set<EditableField>` con casos `amount`, `counterparty`, `occurredAt`, persistido como strings. | 0 |
| C3 | Un Yappy `failed` sin `confirmation` no se puede deduplicar. Si Shortcuts reintenta, habrá duplicados. | Aceptado para v1. Se documenta en la vista de detalle con un aviso cuando `confirmation == nil`. Se borra a mano. | 2 |
| C4 | El respaldo necesita estado (`lastExportAt`, último intento fallido) y no se dice dónde vive. | `UserDefaults(suiteName: "group.<bundle-id>")`. No va en SwiftData: el export no debe depender del store que respalda. | 5 |
| C5 | No se define nombre de archivo ni retención del CSV. | `Gastario-YYYY-MM-DD-HHmm.csv` en `<ubiquity>/Documents/`. Se conservan todos; ~52 archivos pequeños al año. | 5 |
| C6 | Formato de fechas en CSV no definido. | ISO 8601 con offset de Panamá (`2026-10-04T08:31:00-05:00`). Numbers lo reconoce. Sin BOM. | 5 |
| C7 | Un QR que no contenga URL no cabe en `kind: link`. | Se rechaza con mensaje "El QR no contiene un link". Los QR de factura electrónica de la DGI son URLs; si aparece un caso real distinto, se amplía en v1.1. | 6 |
| C8 | Imágenes sin límite inflan el almacenamiento externo. | Fotos se guardan como JPEG calidad 0.8, lado mayor máximo 2048 px. PDFs sin tocar. | 6 |
| C9 | El resumen mensual no dice qué mes ni qué zona horaria. | Mes calendario actual en `America/Panama`. Neto = entradas − salidas. Incluye todos los `parseStatus`. | 4 |
| C10 | **El `Content` del trigger de Mail es el HTML completo del correo** (~20 KB, verificado con capturas reales), no texto con etiqueta/línea vacía/valor como asume `INTENT.md`. Las reglas de la tabla de parseo siguen siendo válidas, pero sobre el texto **extraído** del HTML, no sobre el crudo. | Agregar un paso `HTMLTextExtractor` puro (Foundation, sin WebKit ni `NSAttributedString(html:)`) antes del parseo de campos. `rawContent` guarda el HTML tal cual. Detalle en Fase 1. | 1 |

## 3. Arquitectura y convenciones (aplican a todas las fases)

### Estructura del repo

```
Gastario.xcodeproj            ← app target, usa "buildable folders" (Xcode 16+) para que
                                 agregar archivos no requiera editar el pbxproj
Gastario/                     ← target iOS: UI, App Intents, Notificaciones, Adjuntos, Ajustes
Packages/
  GastarioParsing/            ← SOLO Foundation. Parsers puros. Testeable en macOS y Linux.
  GastarioCore/               ← Modelos SwiftData, CaptureService, ReparseService, CSVExporter,
                                 BackupPolicy. Depende de GastarioParsing. Testeable en macOS.
```

Por qué dos paquetes y no uno: un agente que corre en la nube (Linux) puede desarrollar y probar `GastarioParsing` completo sin Xcode. `GastarioCore` necesita SwiftData, que solo existe en plataformas Apple; se trabaja con Claude Code local en la Mac. El target de app no tiene lógica probable por unidad: todo lo que se pueda probar vive en los paquetes.

### Reglas

- Swift 6, concurrencia estricta. Swift Testing (`@Test`), no XCTest, salvo en UI tests si llegan a existir.
- Montos siempre `Decimal`. Prohibido `Double` para dinero. `Decimal(string:locale:)` con `en_US_POSIX`.
- Enums persistidos con `String` raw value.
- Toda zona horaria explícita: `TimeZone(identifier: "America/Panama")!`. Nunca `.current` en lógica de parseo o agrupación.
- Inyección por protocolo para los efectos laterales del pipeline de captura (`MovementNotifier`, `BackupTrigger`). Las fases tempranas usan implementaciones no-op; las fases posteriores las reemplazan sin tocar el pipeline.
- Ningún intent lanza error a Shortcuts por un fallo de parseo. Solo lanza si el store es inaccesible (el Append del CSV viejo ya habrá corrido).
- Definition of done por fase: compila sin warnings nuevos, `swift test` verde en ambos paquetes, checklist del gate marcado en el PR.

### Mapa de fases

| Fase | Nombre | Resultado observable | AC cubiertos | Depende de |
|---|---|---|---|---|
| 0 | Fundación | App vacía con store en App Group y lista de solo lectura | — | — |
| 1 | Parsers | `swift test` verde con fixtures reales | 2, 3, 4, 7, 16 (unitarios) | — |
| 2 | Captura | Toco la tarjeta o llega un Yappy → aparece en la lista | 1, 5, 6, 10, 12 | 0, 1 |
| 3 | Notificaciones | Llega la pregunta y respondo sin abrir la app | 1, 7, 8, 9, 12 | 2 |
| 4 | Revisión y edición | Filtros, detalle editable, re-parseo, entrada manual, borrar | 9, 13, 14, 15, 17, 18 | 3 |
| 5 | Exportar y respaldo | CSV en iCloud Drive sin abrir la app | 11, 21 | 2, 4 |
| 6 | Adjuntos | Foto, PDF, link y QR por movimiento | 15, 19, 20 | 4 |
| 7 | Transición | Shortcuts viejos retirados con evidencia | — | 3 + 2–3 semanas |

Las fases 0 y 1 son independientes y pueden correr en paralelo (dos agentes, dos ramas).

---

## Fase 0 — Fundación

**Objetivo.** Proyecto compilable en dispositivo con el store de SwiftData en el App Group desde el primer commit, modelos completos y una lista mínima para ver datos.

**Alcance.**
- Proyecto Xcode, bundle id, capability **App Groups** (`group.<bundle-id>`). iCloud Documents se habilita en Fase 5 (es solo un toggle, no una migración).
- Paquetes `GastarioParsing` (vacío, con un test placeholder) y `GastarioCore`.
- Modelos `Movement` y `Attachment` según `INTENT.md` + C1 + C2. Relación `attachments` con `deleteRule: .cascade`. **Sin** `@Attribute(.unique)` en `confirmation`.
- `GastarioStore.makeContainer(inMemory: Bool) -> ModelContainer`. En disco apunta a `FileManager.containerURL(forSecurityApplicationGroupIdentifier:)`. Falla en voz alta (`fatalError` con mensaje) si el App Group no está disponible: es un error de configuración, no de runtime.
- `MovementListView` de solo lectura con `@Query`, agrupada por día en `America/Panama`, orden `occurredAt` descendente. Muestra contraparte, monto con signo, ícono de fuente, badges "sin nota" y "requiere revisión".
- `#if DEBUG`: menú para insertar movimientos de muestra y para borrar todo.

**Fuera de alcance.** Cualquier edición, intents, notificaciones.

**Entregables.**
- `Packages/GastarioCore/Sources/GastarioCore/Models/{Movement,Attachment,Enums}.swift`
- `Packages/GastarioCore/Sources/GastarioCore/Store/GastarioStore.swift`
- `Gastario/App/GastarioApp.swift`, `Gastario/Movements/MovementListView.swift`
- README corto en cada paquete: cómo correr `swift test`.

**Pruebas automáticas.**
- Insertar y leer un `Movement` en container en memoria.
- Borrar un `Movement` con dos `Attachment` → cero attachments restantes (cascade).
- `editedFields` y `parseIssues` sobreviven un ciclo guardar/leer.

**Gate de salida.**
- [ ] `swift test` verde en ambos paquetes.
- [ ] 📱 La app abre en el dispositivo. El log de arranque imprime la URL del store y contiene `Group Containers`.
- [ ] 📱 Insertar muestras desde el menú DEBUG, cerrar la app desde el switcher, reabrir → siguen ahí.

**Riesgos.** Verificar contra el SDK de iOS 27 que SwiftData acepte `Set<ParseIssue>` y `Set<EditableField>` como atributos Codable sin transformer; si no, persistir como `[String]`.

---

## Fase 1 — Parsers puros

**Objetivo.** Todo el parseo como funciones puras sobre texto, con fixtures reales, sin tocar SwiftData ni UI. Es la parte que más valor da por hora de agente y la que `INTENT.md` identifica como frágil hoy.

**Alcance.** Paquete `GastarioParsing`:
- `HTMLTextExtractor.text(from html: String) -> [String]` (C10). Determinista y puro; el mismo HTML siempre da las mismas líneas:
  1. Eliminar `<style>…</style>`, `<script>…</script>` y comentarios `<!-- … -->`.
  2. Los saltos de línea del HTML fuente **no** cuentan: la etiqueta "Enviado a" llega como `Enviado\n   a` dentro de un `<span>`, y el nombre como `<strong>Isabel</strong><strong>\n Davila</strong>`.
  3. Insertar `\n` al cerrar bloques: `</p>`, `</td>`, `</tr>`, `</th>`, `</div>`, `</h1>`–`</h6>`, `</li>`, y en `<br>`.
  4. Quitar el resto de etiquetas. Decodificar entidades (`&nbsp;`, `&amp;`, `&lt;`, `&gt;`, `&quot;`, `&#NNN;`, `&#xHH;`).
  5. Normalizar U+00A0 y U+202F a espacio, colapsar espacios repetidos dentro de cada línea, recortar, descartar líneas vacías.
  Resultado esperado para un correo real: `… / Enviaste por Yappy / $600.00 / Enviado a / Isabel Davila / 60138151 / Fecha / 07 oct 2026 11:53 a. m. / Mensaje / Deposito envio de Alejandro / Confirmación / SFDLM-66689828 / …`.
- Si la entrada no contiene `<html` ni `<body` (texto plano, por si Apple cambia el trigger), el extractor aplica solo el paso 5 línea por línea.
- `AmountParser.parse(_:) -> Decimal?`: regex `\d[\d,]*(?:\.\d+)?`, quitar comas, `Decimal(string:locale:)` POSIX. Devuelve `nil` para vacío o no parseable; `0` para `"$0.00"`. Formato confirmado del trigger de Wallet: `$1.57`. Los demás formatos de la tabla son defensa, no requisito.
- `CardInputParser.parse(CardRawInputs) -> ParsedCard`: aplica `AmountParser`; monto `nil` o `0` → issue `amount` y `amount = 0`; merchant vacío o solo espacios → issue `counterparty`.
- `YappyDateParser.parse(_:) -> Date?`: regex día/mes/año/hora/minuto/`a|p`; mapa `ene…dic` + `sept`; `DateComponents` con `America/Panama`. Sin `DateFormatter`.
- `YappyEmailParser.parse(_:) -> ParsedYappy`: corre `HTMLTextExtractor` y aplica la tabla de `INTENT.md` sobre las líneas resultantes, con estos ajustes verificados en capturas reales:
  - Dirección: línea `Enviaste por Yappy` → `outflow`; `Te enviaron por Yappy` → `inflow` (texto del recibido pendiente de confirmar con la captura).
  - Monto: primera línea que empieza con `$`, p. ej. `$600.00` (en el HTML trae un espacio final antes de un `<img>`).
  - Contraparte: línea siguiente a `Enviado a` / `Enviado por`. La línea que le sigue es el teléfono (`60138151`); se ignora en v1.
  - Fecha: línea siguiente a `Fecha`. Mensaje: línea siguiente a `Mensaje`, salvo que sea `Confirmación` (verificado: sin mensaje el HTML trae `<strong></strong>` vacío, que no genera línea). Confirmación: regex `[A-Z]{5}-\d{8}` sobre todo el texto.
  - El template del correo recibido es un archivo distinto al del enviado (tabs en vez de espacios, otra numeración de líneas, el mensaje en la misma línea que el `<strong>`). Nada en el parser puede depender de la posición o el formato del HTML fuente.
  Reglas de estado:
  - `failed`: no se pudo determinar dirección **o** monto.
  - `partial`: dirección y monto presentes, pero falta alguno de contraparte, confirmación o fecha. Cada faltante va a `parseIssues`.
  - `ok`: todo presente. `yappyMessage` vacío **no** es un issue.
- Tipos de salida (`ParsedCard`, `ParsedYappy`, `ParseStatus`, `ParseIssue`, `Direction`) viven aquí y `GastarioCore` los reexporta o mapea.

**Fixtures.** `Tests/GastarioParsingTests/Fixtures/Yappy/`. Son archivos `.html` de ~20 KB, el `Content` tal cual lo entrega Shortcuts:
- `sent-with-message.html`, `sent-without-message.html`, `received.html`, `amount-with-comma.html`.
- `unexpected-format.html` (correo que no es de Yappy) y `plain-text.txt` (sintético: el mismo contenido sin HTML, para el camino de texto plano del extractor).
- Variantes de fecha con U+00A0 / U+202F: se generan **en el test** a partir de `sent-with-message.html` reemplazando los espacios de la línea de fecha, no como archivos aparte. En las capturas reales los 4 U+00A0 por correo están en párrafos vacíos del footer, no en la fecha.
- Antes de commitear, anonimizar **solo** nombre de la contraparte, teléfono y código de confirmación, conservando longitud y formato (`[A-Z]{5}-\d{8}`). Nada más se toca.

Los cuerpos deben ser **reales y capturados desde Shortcuts**, no copiados desde Mail: Shortcuts entrega el HTML crudo y Mail entrega texto renderizado; son entradas distintas. Procedimiento:

1. En la automatización de Yappy actual, dentro del `Repeat` y antes del regex, agregar `Save File` con el mismo `Content` que se pasa al parseo. Destino `iCloud Drive/Shortcuts/yappy-raw/`, nombre `yappy-{Current Date:yyyyMMdd-HHmmss}.txt`, sin preguntar dónde guardar, sin sobrescribir.
2. Esperar un correo de cada tipo (enviado con mensaje, enviado sin mensaje, recibido).
2b. **Verificar qué recibe un parámetro `String`.** `Save File` guarda `Content` como `.html` aunque el nombre diga `.txt`: Shortcuts lo tipa como HTML. Un parámetro `String` de App Intent recibe lo que resulte de la coerción de ese item a texto, que puede ser el HTML fuente o texto plano renderizado. Para saberlo sin la app: agregar una acción `Text` cuyo contenido sea la variable `Content` interpolada, y guardar ese `Text` con `Save File`. Esa interpolación aplica la misma coerción que un parámetro `String`. Si el archivo resultante empieza con `<!DOCTYPE html`, el intent recibe HTML; si trae las líneas `Enviaste por Yappy / $600.00 / …`, recibe texto plano. Los fixtures reales son **ese** archivo, no el `.html` directo. La confirmación definitiva es `rawContent` en la Fase 2.
3. En la Mac, verificar que es HTML (`head -1` empieza con `<!DOCTYPE html`) y localizar los espacios especiales: `LC_ALL=C grep -n $'\xC2\xA0' archivo.txt | cut -c1-60`.
4. Anonimizar según la regla de arriba y copiar a la carpeta de fixtures con extensión `.html`.

Cuando exista la vista de cuerpo crudo (Fase 4), se comparan contra `rawContent` y se reemplazan si difieren. Hasta recibir los reales, el agente trabaja con fixtures sintéticos marcados `// SYNTHETIC` en el nombre del test; el gate no se cierra con sintéticos.

**Pruebas automáticas.** Un test por fixture y por fila de la tabla de montos de `INTENT.md` (`$3.80`, `$1,250.00`, `B/.3.80`, `USD 3.80`, `""`, `"$0.00"`). Para `HTMLTextExtractor`, un golden test: las líneas extraídas de `sent-with-message.html` se comparan contra un `.expected.txt` versionado, para que cualquier cambio en la extracción sea visible en el diff. Cubren AC-2, AC-3, AC-4, AC-16 y la mitad de parseo de AC-7 y AC-12.

**Gate de salida.**
- [ ] `swift test` verde en `GastarioParsing` en macOS **y** en Linux (CI o contenedor).
- [ ] Al menos 3 fixtures de Yappy son reales (enviado con mensaje, sin mensaje, recibido).
- [ ] Ningún test marcado `SYNTHETIC` para los casos que ya tienen fixture real.

---

## Fase 2 — Captura (App Intents)

**Objetivo.** Los dos App Intents guardan en el store, en segundo plano, siguiendo el orden obligatorio, con deduplicación. Al cerrar esta fase se activan los Shortcuts nuevos **en paralelo** con los CSVs viejos (empieza el reloj de la Fase 7).

**Alcance.**
- `GastarioCore/Capture/CaptureService`:
  - `captureCard(_ inputs: CardRawInputs, capturedAt: Date = .now) async -> CaptureOutcome`
  - `captureYappy(content: String, capturedAt: Date = .now) async -> CaptureOutcome`
  - `CaptureOutcome` = `.created(Movement.ID)` | `.duplicate(existing: Movement.ID)`.
  - Orden interno: (1) insertar `Movement` con crudo y `parseStatus = failed` provisional, guardar; (2) parsear; (3) actualizar campos, `parseStatus`, `parseIssues`; (4) guardar; (5) `notifier.notify(movementID)`; (6) `backup.runIfDue()`. Los pasos 5 y 6 reciben protocolos; en esta fase son no-op.
  - Dedup Yappy: si el parser devuelve `confirmation`, `FetchDescriptor` por igualdad **antes** del paso 1. Si existe → `.duplicate`, sin tocar nada, sin notificar. Si `confirmation == nil` → no hay dedup (C3).
  - `rawInputs` = JSON de `CardRawInputs` (Codable) tal como llegó.
- `Gastario/Intents/LogCardMovementIntent.swift`, `LogYappyEmailIntent.swift`:
  - Títulos "Log Card Transaction" y "Log Yappy Email".
  - Modo background con la API vigente del SDK de iOS 27 (en iOS 26 es `supportedModes = .background`; **verificar el nombre exacto antes de escribir código**).
  - Construyen el container con `GastarioStore` y llaman a `CaptureService`. Devuelven `.result()` siempre que el store responda, también en `.duplicate` y en `failed`.
- Instrucciones para configurar los dos atajos en `docs/shortcuts.md`, copiadas de `INTENT.md`, con el `Append to Text File` **antes** del intent.

**Fuera de alcance.** Notificaciones, export, UI.

**Pruebas automáticas** (container en memoria, `MovementNotifier` espía):
- Tarjeta completa → `card`/`outflow`, monto `Decimal`, `ok`, notifier llamado una vez. (AC-1 sin la notificación)
- Tarjeta con `Amount = "0"` o `Merchant = ""` → `partial`, issues correctos, se guarda. (AC-12)
- Tarjeta sin ciudad ni coordenadas → se guarda con nulos. (AC-10)
- Mismo correo dos veces, el primero con `note` → un `Movement`, `note` intacta, notifier llamado una vez. (AC-6)
- Dos correos distintos → dos movimientos. (AC-5)
- Cuerpo inesperado → `failed`, `rawContent` guardado, notifier llamado. (AC-7)
- El `Movement` existe en el store **antes** de que termine el parseo (inyectar un parser que lance; el movimiento queda `failed` con crudo). Principio 2.

**Gate de salida.**
- [ ] Tests anteriores verdes.
- [ ] 📱 Ambos atajos configurados según `docs/shortcuts.md`. Pagar con Apple Pay → el movimiento aparece en la lista sin abrir la app durante el pago.
- [ ] 📱 Recibir un Yappy → aparece. Correr el atajo de email dos veces sobre el mismo correo → un solo movimiento.
- [ ] 📱 El CSV viejo sigue recibiendo filas (el Append va antes del intent).

**Riesgos.** El trigger de Wallet puede entregar `Merchant` vacío o `Amount = 0`; los formatos reales de `Amount` deben agregarse a los fixtures de Fase 1 en cuanto se observen. Verificar que el intent corre con la app terminada desde el switcher.

---

## Fase 3 — Notificaciones

**Objetivo.** Cada captura dispara la pregunta y la respuesta se guarda sin abrir la app, incluso con la app terminada. Es el momento en que Gastario reemplaza funcionalmente a los Shortcuts viejos.

**Alcance.**
- `Gastario/Notifications/NotificationService`: pedir permiso en el primer arranque; registrar categoría `MOVEMENT_QUESTION` con `UNTextInputNotificationAction(identifier: "REPLY", title: "Responder")`, **sin** `.foreground`. Implementa `MovementNotifier`.
- `GastarioCore/Notifications/NotificationText.build(for: Movement) -> (title, body)`: textos de `INTENT.md`. Para tarjeta `partial` usa `parseIssues` para elegir "el monto", "el comercio" o "el monto ni el comercio". Montos con `.currency(code: "USD")` y locale `en_US` → `$3.80`.
- Identificador de la notificación = `movement.id.uuidString`.
- `Gastario/App/AppDelegate` vía `@UIApplicationDelegateAdaptor`. En `didFinishLaunchingWithOptions`: crear el `ModelContainer` compartido (propiedad del AppDelegate, no de la escena SwiftUI) y asignar `UNUserNotificationCenter.current().delegate`. Motivo: al responder con la app terminada, iOS lanza el proceso y llama a `didReceive` sin que ninguna vista exista.
- `GastarioCore/Notifications/NoteReplyHandler.handle(movementID:text:)`: busca, asigna `note` y `notedAt`, guarda. El `completionHandler` del delegate se llama **después** del `await` de este método.
- Movimientos `manual` no notifican (el `CaptureService` no participa en la entrada manual; se cubre en Fase 4).
- Reemplazar el no-op de Fase 2 por `NotificationService`.

**Pruebas automáticas.**
- `NotificationText` para los 6 casos: salida, entrada, tarjeta sin monto, sin comercio, sin ambos, Yappy `failed`.
- `NoteReplyHandler` con container en memoria: guarda `note` y `notedAt`; con un ID inexistente no lanza.

**Gate de salida.**
- [ ] 📱 AC-1 completo: pago → notificación con el texto correcto.
- [ ] 📱 AC-8: dejar la notificación varias horas, matar la app desde el switcher, responder desde el Centro de Notificaciones → abrir la app → `note` y `notedAt` guardados.
- [ ] 📱 AC-7 y AC-12: llegan las notificaciones de revisión / completar.
- [ ] 📱 Dedup: un correo repetido no genera segunda notificación (AC-6).

**Riesgos.** Si `didReceive` llega antes de que el container esté listo, la respuesta se pierde: por eso el container se crea síncronamente en `didFinishLaunching`. Medir que no exceda el tiempo de arranque en frío.

---

## Fase 4 — Revisión y edición

**Objetivo.** Todo lo que permite confiar en los datos: ver qué falló, corregirlo, re-parsear, agregar lo que la automatización no capturó y borrar lo que sobra.

**Alcance.**
- **Filtros** en la lista: "Todos", "Sin nota" (`note == nil`), "Requiere revisión" (`parseStatus != ok`). Cuenta en cada filtro.
- **Detalle** (`MovementDetailView`):
  - Todos los campos. Link a Maps si hay coordenadas. Aviso si es Yappy sin `confirmation` (C3).
  - Sección **Cuerpo crudo** para Yappy: muestra las líneas extraídas por `HTMLTextExtractor` (legibles) con un toggle a HTML crudo, y botón "Copiar" del HTML (para alimentar fixtures). Para tarjeta, `rawInputs` formateado.
  - Edición de `amount`, `counterparty`, `occurredAt`. Cada edición agrega el campo a `editedFields` y quita su `ParseIssue`. Si `parseIssues` queda vacío y el estado era `partial` → `ok`. Un `failed` **no** cambia por edición: solo por re-parseo (su crudo no se entendió; editar a mano no lo valida).
  - `note` editable; al guardar asigna `notedAt` si estaba vacío.
  - Botón "Re-parsear" en `card`/`yappy`.
- `GastarioCore/Reparse/ReparseService`:
  - `reparse(_ movement:)`: vuelve a correr el parser sobre `rawInputs`/`rawContent`, escribe solo los campos **no** incluidos en `editedFields`, recalcula `parseStatus` y `parseIssues` (un campo editado nunca cuenta como issue). No toca `note`, `notedAt`, `attachments`. Ignora `manual`.
  - `reparseAll()`: solo `parseStatus != ok`. Devuelve conteo de cambiados.
- **Entrada manual** (`+`): monto, dirección, contraparte, fecha (default ahora), nota opcional. Crea `source = manual`, `parseStatus = ok`, sin pasar por `CaptureService` → sin notificación.
- **Borrar**: swipe con `confirmationDialog`. Cascade borra adjuntos.
- **Resumen del mes** como cabecera de la lista (C9).
- **Ajustes** (esqueleto): "Re-parsear todo" con resultado "N movimientos actualizados". Fase 5 agrega las filas de export.

**Pruebas automáticas.**
- `ReparseService`: crudo bueno + campos corruptos → restaura, conserva `note`, `attachments` y `editedFields`. (AC-17, AC-18)
- `reparseAll` ignora `ok` y `manual`.
- Resolución `partial → ok` al editar el último campo faltante; `failed` no cambia por edición. (AC-13)
- Resumen mensual con movimientos en el límite de mes en `America/Panama` (23:30 del día 30 en UTC cae en el mes siguiente; en Panamá no).

**Gate de salida.**
- [ ] Tests verdes.
- [ ] 📱 AC-9: borrar una notificación sin responder → el movimiento está en "Sin nota".
- [ ] 📱 AC-13, AC-14, AC-18 en dispositivo.
- [ ] 📱 AC-15 parcial: borrar un movimiento desaparece de la lista (adjuntos reales se verifican en Fase 6).
- [ ] Fixtures de Fase 1 comparados con el cuerpo crudo real capturado; reemplazados si difieren.

---

## Fase 5 — Exportar y respaldo

**Objetivo.** Nunca depender del dispositivo como única copia. El CSV completo se escribe a iCloud Drive cada 7+ días, aunque la app no se abra.

**Alcance.**
- Capability **iCloud Documents** (ubiquity container, no CloudKit). `NSUbiquitousContainers` en Info.plist con `NSUbiquitousContainerIsDocumentScopePublic = true` para que la carpeta aparezca en Files.
- `GastarioCore/Export/CSVExporter.export(_ movements:) -> Data`: columnas exactas de `INTENT.md`, montos con signo (`outflow` negativo), fechas según C6, escape RFC 4180 (comillas dobles, saltos de línea dentro de `note`), `attachmentCount` = `attachments.count`. Sin BOM.
- `GastarioCore/Export/BackupPolicy`: `isDue(lastExportAt:now:)` → 7 días. Estado en `UserDefaults` del App Group (C4): `lastExportAt`, `lastExportAttemptAt`, `lastExportError`.
- `Gastario/Export/BackupService`: implementa `BackupTrigger`. Obtiene `FileManager.url(forUbiquityContainerIdentifier: nil)` **fuera del main actor** (puede bloquear), escribe en `Documents/` con el nombre de C5. Cualquier error se registra en `lastExportError` y **nunca** se propaga al intent.
- Puntos de evaluación: paso 6 del `CaptureService` (reemplaza el no-op) y `scenePhase == .active` al abrir la app.
- Ajustes: fecha del último export, último error si lo hay, "Exportar ahora" (fuerza el export a iCloud **y** ofrece `ShareLink` del mismo archivo).
- `#if DEBUG`: botón "Simular 8 días sin export" que retrocede `lastExportAt`.

**Pruebas automáticas.**
- Golden test de `CSVExporter` con 3 movimientos (uno con coma y comillas en `note`, uno `inflow`, uno sin ubicación).
- `BackupPolicy.isDue` en los bordes: 6d23h → no; 7d → sí; nunca exportado → sí.
- `CaptureService` con un `BackupTrigger` que lanza → la captura igual termina `.created`.

**Gate de salida.**
- [ ] Tests verdes.
- [ ] 📱 AC-11: "Exportar ahora" → el archivo abre en Numbers, una fila por movimiento, montos con signo, fechas legibles.
- [ ] 📱 AC-21: "Simular 8 días", matar la app, hacer un pago → aparece el CSV nuevo en Files → iCloud Drive → Gastario, sin abrir la app.
- [ ] 📱 Un export fallido (modo avión + iCloud deshabilitado) no impide la captura ni la notificación.

**Riesgos.** El ubiquity container puede tardar en estar disponible tras la primera activación de iCloud Documents; el primer export puede fallar y reintentarse en la siguiente captura. Eso es comportamiento esperado, no bug.

---

## Fase 6 — Adjuntos

**Objetivo.** Documentar cada movimiento con foto, PDF o link, sin tocar el camino de captura (principio 4).

**Alcance.**
- `Gastario/Attachments/AttachmentService` (app target, necesita UIKit/PhotosUI):
  - Foto: `PhotosPicker` y cámara (`UIImagePickerController` envuelto). Guardar según C8.
  - PDF: `.fileImporter(allowedContentTypes: [.pdf])`, leer dentro de `startAccessingSecurityScopedResource`, copiar `Data`.
  - Link: `TextField` validado (`URL` con esquema `http`/`https`).
  - QR: `DataScannerViewController` con `.barcode(symbologies: [.qr])`; si el payload es URL → `kind = link`; si no → error (C7).
  - Ver: `QLPreviewController` sobre un archivo temporal escrito desde `data`; links con `Link`.
- Sección de adjuntos en el detalle: lista, agregar, borrar individual.
- `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription` en Info.plist.

**Pruebas automáticas.** Validación de links (acepta `https://dgi-fep.mef.gob.pa/...`, rechaza `javascript:`, texto plano, `ftp://`). Redimensionado de imagen respeta el máximo. El resto es UI y se verifica en dispositivo.

**Gate de salida.**
- [ ] 📱 AC-19: PDF de 5 MB, cerrar y abrir → sigue ahí y abre en Quick Look. Verificar que el store `.sqlite` no creció 5 MB (externalStorage).
- [ ] 📱 AC-20: QR de una factura electrónica real → `link` que abre en Safari.
- [ ] 📱 AC-15 completo: borrar un movimiento con 3 adjuntos → desaparecen los archivos externos.
- [ ] 📱 Una captura durante el flujo de adjuntar no se pierde ni se afecta.

---

## Fase 7 — Transición (operativa, sin código)

**Objetivo.** Retirar los Shortcuts viejos con evidencia de que Gastario no pierde capturas.

**Procedimiento.**
1. Empieza al cerrar la Fase 3 (desde ahí Gastario es funcional). Duración: 2–3 semanas de uso normal.
2. Al final: "Exportar ahora" en Gastario; abrir los dos CSVs viejos; comparar **conteos por día** y **sumas por día** en Numbers.
3. Cada discrepancia se clasifica: (a) duplicado en Gastario sin `confirmation` (C3), (b) pago rechazado capturado por el tap, (c) captura perdida en Gastario, (d) captura perdida en el CSV viejo.
4. Cualquier (c) bloquea el retiro: se investiga, se corrige, y se extiende el período una semana.
5. Con cero (c): quitar el `Append to Text File` de ambos atajos. Archivar los CSVs viejos como insumo para la importación de v1.1.

**Gate de salida.**
- [ ] Tabla de comparación en `docs/transition-report.md` con los conteos y la clasificación de cada discrepancia.
- [ ] Appends retirados.
- [ ] Decisión registrada sobre v1.1: importar CSVs, Share Extension, y qué formatos reales de `Amount` aparecieron.

---

## 4. Trazabilidad AC → Fase

| AC | Descripción corta | Prueba automática | Verificación 📱 |
|---|---|---|---|
| 1 | Captura de tarjeta + notificación | F2 | F3 |
| 2 | Montos con formato | F1 | — |
| 3 | Yappy enviado completo | F1 | F2 |
| 4 | Yappy sin mensaje | F1 | — |
| 5 | Dos correos a la vez | F2 | F2 |
| 6 | Duplicado, nota intacta | F2 | F3 |
| 7 | Parseo fallido | F1, F2 | F3 |
| 8 | Responder después, app terminada | F3 (handler) | F3 |
| 9 | Sin nota tras descartar | — | F4 |
| 10 | Sin ubicación | F2 | — |
| 11 | Exportar abre en Numbers | F5 (golden) | F5 |
| 12 | Tarjeta con datos vacíos | F1, F2 | F3 |
| 13 | Resolver parcial | F4 | F4 |
| 14 | Entrada manual | — | F4 |
| 15 | Borrar con adjuntos | F0 (cascade) | F4, F6 |
| 16 | Fecha con NBSP | F1 | — |
| 17 | Re-parsear todo | F4 | — |
| 18 | Edición protegida | F4 | F4 |
| 19 | Adjunto persistente | — | F6 |
| 20 | QR de factura | F6 (validación) | F6 |
| 21 | Auto-export sin abrir la app | F5 (policy) | F5 |

## 5. Preguntas abiertas (bloquean la fase indicada)

| # | Pregunta | Bloquea |
|---|---|---|
| Q1 | Bundle id y Team ID para el App Group y el ubiquity container. | F0 |
| Q2 | ~~Tres cuerpos reales de correo Yappy.~~ **Resuelto** (2 enviados, 1 recibido, 7 oct 2026). Confirmado: `Te enviaron por Yappy`, `Enviado por`, mensaje vacío = `<strong></strong>`, montos `$600.00 ` / `$0.01 ` con espacio final. Falta un caso real con coma (`$1,250.00`); hasta entonces `amount-with-comma` es sintético. | — |
| Q6 | ¿El parámetro `String` de `LogYappyEmailIntent` recibe el HTML fuente o texto plano? Ver paso 2b del procedimiento de fixtures. El extractor soporta ambos caminos, pero el gate de la Fase 1 exige fixtures del camino real. | Gate F1 |
| Q3 | ~~Formato exacto del `Amount` que entrega el trigger de Wallet.~~ **Resuelto:** `$1.57`. | — |
| Q4 | Confirmar C1–C9 o indicar cuáles cambian. | F0 (C1, C2), F5, F6 |
| Q5 | ¿La lista muestra montos de `partial` con `amount = 0` como `$0.00` o como "—"? Default: "—" con el badge de revisión. | F0 |
