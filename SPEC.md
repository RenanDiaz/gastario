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
| S1 | Spike: correos de factura | Catálogo de remitentes y formatos reales, decisión go/no-go | — | — |
| 8 | Facturas por correo (v1.1) | Llega la factura por correo → queda asignada al movimiento | AC-F1…F8 (propuestos) | 4, 6, S1 |

Las fases 0 y 1 son independientes y pueden correr en paralelo (dos agentes, dos ramas).

El spike S1 no depende de código y conviene **arrancarlo ya**: es recolección de datos reales durante 2–3 semanas, el mismo tipo de espera que la Fase 7. La Fase 8 queda fuera de v1 (ver `INTENT.md`, "Fuera de alcance v1") y solo se abre si S1 sale con go.

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
- `TextNormalizer.normalize(_:)`: U+00A0 y U+202F → espacio; `\r\n` → `\n`.
- `AmountParser.parse(_:) -> Decimal?`: regex `\d[\d,]*(?:\.\d+)?`, quitar comas, `Decimal(string:locale:)` POSIX. Devuelve `nil` para vacío o no parseable; `0` para `"$0.00"`.
- `CardInputParser.parse(CardRawInputs) -> ParsedCard`: aplica `AmountParser`; monto `nil` o `0` → issue `amount` y `amount = 0`; merchant vacío o solo espacios → issue `counterparty`.
- `YappyDateParser.parse(_:) -> Date?`: regex día/mes/año/hora/minuto/`a|p`; mapa `ene…dic` + `sept`; `DateComponents` con `America/Panama`. Sin `DateFormatter`.
- `YappyEmailParser.parse(_:) -> ParsedYappy`: dirección, monto, contraparte, mensaje, confirmación, fecha, según la tabla de `INTENT.md`. Reglas de estado:
  - `failed`: no se pudo determinar dirección **o** monto.
  - `partial`: dirección y monto presentes, pero falta alguno de contraparte, confirmación o fecha. Cada faltante va a `parseIssues`.
  - `ok`: todo presente. `yappyMessage` vacío **no** es un issue.
- Tipos de salida (`ParsedCard`, `ParsedYappy`, `ParseStatus`, `ParseIssue`, `Direction`) viven aquí y `GastarioCore` los reexporta o mapea.

**Fixtures.** `Tests/GastarioParsingTests/Fixtures/Yappy/`:
- `sent-with-message.txt`, `sent-without-message.txt`, `received.txt`, `amount-with-comma.txt`.
- Variantes de fecha: `date-nbsp.txt` (U+00A0), `date-narrow-nbsp.txt` (U+202F), `date-plain.txt`.
- `unexpected-format.txt` (cuerpo que no es de Yappy).

Los cuerpos deben ser **reales**, copiados desde Mail (seleccionar todo el cuerpo → copiar). Cuando exista la vista de cuerpo crudo (Fase 4), se comparan contra lo que llega al intent y se reemplazan si difieren. Hasta recibir los reales, el agente trabaja con fixtures sintéticos marcados `// SYNTHETIC` en el nombre del test; el gate no se cierra con sintéticos.

**Pruebas automáticas.** Un test por fixture y por fila de la tabla de montos de `INTENT.md` (`$3.80`, `$1,250.00`, `B/.3.80`, `USD 3.80`, `""`, `"$0.00"`). Cubren AC-2, AC-3, AC-4, AC-16 y la mitad de parseo de AC-7 y AC-12.

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
  - Sección **Cuerpo crudo** para Yappy, con botón "Copiar" (para alimentar fixtures). Para tarjeta, `rawInputs` formateado.
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

## Spike S1 — Correos de factura electrónica

**Objetivo.** Saber con datos reales cómo llegan los correos de factura electrónica en Panamá, para decidir si se pueden atrapar con un trigger de Shortcuts y asignar a un movimiento. Es investigación, no producto: el entregable es un documento con fixtures y una decisión, no código de la app.

**Por qué es un spike y no parte de la Fase 6.** La Fase 6 adjunta facturas a mano. Atraparlas por correo es una captura nueva (trigger, intent, dedup, asignación) y todo su diseño depende de formatos que hoy no conocemos. Diseñar sin ver los correos sería repetir el error del parseo frágil de Yappy.

**Procedimiento** (lo hace la persona; el agente prepara el atajo y analiza lo recolectado).
1. **Inventario retroactivo.** En Mail, buscar `factura`, `factura electrónica`, `CUFE`, `CAFE`, `comprobante` en los últimos 3 meses. Anotar por correo: remitente, dominio, asunto, si viene del comercio o de un PAC, adjuntos (PDF/XML/ninguno), y si el cuerpo trae total, CUFE, RUC del emisor, fecha y link/QR de consulta de la DGI.
2. **Atajo de diagnóstico** (sin código de la app, corre 2–3 semanas):
   ```
   When I receive an email where Subject contains "Factura"   ← un atajo por patrón candidato
   Repeat with each item in [Email]
      Get Details of Email (Sender, Subject, Date Received, Contents, y Attachments si existe)
      Append to Text File  iCloud Drive/Gastario-Spike/invoices-YYYY-MM-DD.txt
         ("=== <sender> | <subject> | <date>\n<contents>\n--- attachments: <lista o 'n/a'>")
   End Repeat
   ```
   - Objetivo doble: ver qué **recibe realmente** el atajo (puede diferir de lo que muestra Mail, como pasó con Yappy) y medir cuántos correos de factura se escapan a cada patrón de trigger.
3. **Cruce con movimientos.** Para cada factura recolectada, buscar el movimiento real (CSV viejo o Gastario si ya está en Fase 2+) y anotar: diferencia de monto, diferencia de tiempo pago→correo, y si el nombre de Wallet/Yappy se parece al emisor de la factura.

**Preguntas que el spike debe cerrar.**

| # | Pregunta | Impacto en la Fase 8 |
|---|---|---|
| S1.1 | ¿El trigger de email de Shortcuts permite filtrar por asunto, por remitente o ambos? ¿Admite varios remitentes? ¿Corre sin confirmación? | Cuántos atajos hay que configurar y si es viable mantener la lista |
| S1.2 | ¿Los remitentes son pocos y estables (PACs) o uno por comercio? | Trigger por remitente (preciso) vs. por asunto (amplio, con falsos positivos) |
| S1.3 | ¿`Contents` del `Email` trae CUFE, total, RUC, fecha y link de la DGI en texto? | Si no, el parseo depende del adjunto → ver S1.4 |
| S1.4 | ¿El `Email` del trigger expone adjuntos? ¿Se pueden pasar como `File` a un intent? | Si no, el PDF/XML solo llega por la Share Extension de v1.1 |
| S1.5 | ¿El total de la factura coincide con el monto cobrado? Casos: propina, pago dividido, factura por consumo parcial | Si el monto exacto falla seguido, la asignación automática no sirve y todo queda como sugerencia |
| S1.6 | Distribución del retraso pago → correo (mediana y máximo) | Ventana de búsqueda de candidatos |
| S1.7 | ¿El nombre del emisor se parece al `counterparty` de Wallet? | Si sí, sirve como desempate; si no, se ignora en v1.1 |
| S1.8 | ¿Algún comercio envía la misma factura dos veces, o factura + nota de crédito? | Dedup por CUFE y manejo de notas de crédito |

**Entregables.**
- `docs/spikes/invoice-emails.md`: tabla del inventario, respuestas S1.1–S1.8, patrón(es) de trigger recomendados y decisión **go / go reducido / no-go**.
- `Packages/GastarioParsing/Tests/GastarioParsingTests/Fixtures/Invoice/`: al menos 5 cuerpos reales de **emisores distintos**, tal como los recibió el atajo de diagnóstico. Si hay datos personales (cédula, dirección), se anonimizan antes de commitear.

**Criterio de go.**
- **Go:** el cuerpo trae al menos total y CUFE (o link de la DGI con CUFE) en ≥ 70 % de los correos recolectados, y el trigger los atrapa con ≤ 3 atajos.
- **Go reducido:** los datos solo vienen en el adjunto y el `Email` del atajo no lo expone → la Fase 8 se monta sobre la Share Extension de v1.1 (compartir desde Mail), no sobre un trigger automático.
- **No-go:** remitentes demasiado dispersos o datos solo en PDF escaneado. Se queda la Fase 6 manual.

**Gate de salida.**
- [ ] Inventario con ≥ 15 correos de factura de ≥ 5 emisores.
- [ ] 📱 Atajo de diagnóstico corrió ≥ 2 semanas.
- [ ] Respuestas S1.1–S1.8 y decisión registradas en `docs/spikes/invoice-emails.md`.

---

## Fase 8 — Facturas por correo (v1.1, sujeta a S1)

> El diseño de abajo es la hipótesis previa al spike. Lo que S1 contradiga se corrige aquí antes de abrir la fase.

**Objetivo.** Un correo de factura se captura solo, se parsea y queda asignado al movimiento que corresponde, o como sugerencia si no hay certeza. Sin tocar el camino de captura de tarjeta y Yappy (principio 4).

**Alcance.**
- **Modelo `Invoice`** (entidad propia, no un `Attachment`: tiene crudo, parseo y estado de asignación, y se puede desasignar sin perder nada):

  | Campo | Tipo | Notas |
  |---|---|---|
  | `id` | UUID | |
  | `rawContent` | String | Cuerpo tal como llegó al intent |
  | `sender`, `subject` | String? | Si el atajo los pasa |
  | `capturedAt` | Date | |
  | `cufe` | String? | Clave de dedup, con fetch explícito (misma regla que `confirmation`: sin `@Attribute(.unique)`) |
  | `issuerName`, `issuerRUC` | String? | |
  | `total` | Decimal? | |
  | `issuedAt` | Date? | `America/Panama` |
  | `dgiURL` | URL? | Link de consulta, si viene en el cuerpo |
  | `parseStatus`, `parseIssues` | | Igual que `Movement` |
  | `matchStatus` | enum `unmatched` \| `suggested` \| `autoLinked` \| `confirmed` \| `dismissed` | |
  | `matchLocked` | Bool | `true` cuando yo asigno, desasigno o descarto a mano. El matcher no lo vuelve a tocar (principio 3) |
  | `movement` | `Movement?` | `deleteRule: .nullify`: borrar el movimiento devuelve la factura a la bandeja, no la borra |

  `Movement` gana la inversa `invoices: [Invoice]` (puede haber más de una, p. ej. factura + nota de crédito).
- **`GastarioParsing/InvoiceEmailParser`**: función pura sobre el cuerpo normalizado. Reglas concretas salen de los fixtures de S1. `failed` si no hay ni total ni CUFE.
- **`GastarioCore/Invoices/InvoiceMatcher`**: función pura `candidates(for: Invoice, among: [Movement]) -> [MatchCandidate]` con puntaje. Hipótesis por defecto (ajustar con S1.5–S1.7):
  - Solo `outflow`, sin factura confirmada, `occurredAt` dentro de `[issuedAt − 2h, issuedAt + 72h]` (o `capturedAt` si no hay `issuedAt`).
  - **Fuerte:** monto exacto. **Débil:** total de la factura ≤ monto ≤ total × 1.20 (propina).
  - Auto-asignar solo si hay **exactamente un** candidato fuerte y ninguna otra factura no bloqueada apunta al mismo movimiento. Todo lo demás → `suggested` con la lista ordenada.
  - El nombre del emisor no decide en v1.1, solo ordena (S1.7).
- **`LogInvoiceEmailIntent`** ("Log Invoice Email"): mismo orden obligatorio que los otros intents (crudo → parseo → guardar → asignar → guardar). Dedup por `cufe`. Nunca lanza por parseo ni por asignación. **No** notifica en v1.1: la factura es complemento, no pregunta.
- **Re-asignación** de facturas `unmatched`/`suggested` no bloqueadas al abrir la app y desde Ajustes, para el caso en que el correo llegó antes que el movimiento (o el movimiento se creó a mano después).
- **UI:**
  - Bandeja "Facturas sin asignar" (`unmatched` + `suggested`) con contador en la lista. Cada sugerencia: confirmar con un toque, elegir otro movimiento, o descartar.
  - En el detalle del movimiento: facturas asignadas, link a la DGI, botón "Desasignar".
- **CSV:** columna nueva `invoiceCUFE` (vacía si no hay). Cambia el golden test de Fase 5.
- `docs/shortcuts.md`: atajo(s) de factura con el patrón recomendado por S1.

**Fuera de alcance.** Parsear el XML o el PDF (depende de S1.4; si es go reducido, entra con la Share Extension). Notificar facturas. Aprender alias comercio ↔ RUC (candidato v2, con las asignaciones confirmadas como datos de entrenamiento).

**Criterios de aceptación propuestos** (se mueven a `INTENT.md` cuando S1 dé go):

| # | Criterio |
|---|---|
| AC-F1 | Llega un correo de factura con total igual a un único pago de las últimas 72 h → queda `autoLinked` a ese movimiento. |
| AC-F2 | Dos pagos del mismo monto en la ventana → la factura queda `suggested` con ambos candidatos; no se asigna sola. |
| AC-F3 | Factura sin movimiento que calce → `unmatched` en la bandeja. Al crear después el movimiento a mano y abrir la app → pasa a `suggested` o `autoLinked`. |
| AC-F4 | Mismo CUFE dos veces → una sola factura. |
| AC-F5 | Correo de factura que no parsea → se guarda con `rawContent` y `parseStatus = failed`, visible en la bandeja. |
| AC-F6 | Desasigno una factura auto-asignada → no se vuelve a asignar sola al re-ejecutar el matcher. |
| AC-F7 | Borro un movimiento con factura → la factura vuelve a la bandeja. |
| AC-F8 | Un pago con propina (monto > total, ≤ 20 %) → aparece como sugerencia, no como auto-asignación. |

**Pruebas automáticas.** `InvoiceEmailParser` con los fixtures reales de S1. `InvoiceMatcher` con tabla de casos: exacto único, exacto duplicado, propina, fuera de ventana, `inflow` ignorado, movimiento con factura confirmada ignorado, factura bloqueada ignorada. `CaptureService`/intent de factura con container en memoria: dedup por CUFE, crudo guardado antes de parsear, el fallo del matcher no impide la captura.

**Gate de salida.**
- [ ] Tests verdes, incluido el golden de CSV actualizado.
- [ ] 📱 Una compra real con factura por correo → queda asignada sin abrir la app durante el flujo.
- [ ] 📱 AC-F2, AC-F6 y AC-F7 en dispositivo.
- [ ] Los intents de tarjeta y Yappy no cambiaron (diff vacío en esos archivos).

**Riesgos.** Falsos positivos del trigger por asunto (promociones con "factura" en el asunto) → terminan como `failed` en la bandeja; si son muchos, se agrega un filtro por remitente. El total con ITBMS vs. el monto cobrado debería coincidir, pero redondeos o cargos por servicio pueden romper el "monto exacto"; S1.5 lo mide.

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
| Q2 | Tres cuerpos reales de correo Yappy (enviado con mensaje, sin mensaje, recibido), copiados desde Mail. | Gate F1 |
| Q3 | Formato exacto del `Amount` que entrega el trigger de Wallet hoy (revisar el CSV viejo: ¿`3.80`, `$3.80`, `B/.3.80`?). | F1 (fixtures), F2 |
| Q4 | Confirmar C1–C9 o indicar cuáles cambian. | F0 (C1, C2), F5, F6 |
| Q5 | ¿La lista muestra montos de `partial` con `amount = 0` como `$0.00` o como "—"? Default: "—" con el badge de revisión. | F0 |
| Q6 | Para S1: ¿qué cuenta(s) de correo reciben las facturas? El trigger de Shortcuts solo ve cuentas configuradas en Mail del iPhone. | S1 |
| Q7 | ¿Es aceptable que una factura se asigne sola sin avisar (AC-F1), o toda asignación debe confirmarse a mano al principio? Default: auto-asignar solo con candidato único exacto. | F8 |
