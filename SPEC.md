# SPEC.md — Gastario v1, plan de implementación por fases

`INTENT.md` define **qué** se construye y **por qué**. Este documento define **cómo** y **en qué orden**. Si hay conflicto, gana `INTENT.md`, salvo en los puntos marcados como **Cambio propuesto** (sección 2), que deben confirmarse antes de la fase que los usa.

## 1. Cómo usar este documento

- Cada fase es una unidad de trabajo cerrada para un agente de código: tiene objetivo, alcance, entregables, criterios y un **gate de salida**. No se abre una fase sin cerrar el gate de la anterior.
- Una fase = una rama = un PR. La rama es `phase-N-<slug>` o, si la crea una sesión de Claude Code en la nube, `claude/<slug>`; CI corre en ambas. El PR enlaza la sección de la fase y marca el checklist del gate.
- `AC-n` referencia el criterio de aceptación `n` de `INTENT.md`.
- Las verificaciones marcadas 📱 requieren dispositivo físico y las hace la persona, no el agente. El agente deja listo todo lo que se puede verificar con `swift test` o en simulador.
- Prioridad de orden: primero lo que **protege la captura** (principio 1), después lo que la hace útil, al final lo que es accesorio (adjuntos).

## 2. Cambios propuestos a INTENT.md

Huecos encontrados al convertir el intent en fases. Cada uno tiene una decisión por defecto; si no se objeta, se implementa así. **C1–C9 confirmados** (Q4).

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
| C10 | Los correos reales muestran formatos que el intent no listaba: `Content` llega en HTML, existe "Pagaste por Yappy / Pagado a" y llegan correos de Yappy Comercial. | **Confirmado e incorporado a `INTENT.md`.** El parser convierte HTML a texto sin WebKit; "Pagaste" → `outflow`; Yappy Comercial → `inflow`. | 1 |
| C12 | **Confirmado e incorporado a `INTENT.md`.** `INTENT.md` decía iOS 27, pero los runners de GitHub (`macos-26`) solo traen Xcode 26.x con SDK de iOS 26.5; con deployment target 27 el job `macos` no puede compilar la app. Ninguna API que pide el intent es exclusiva de iOS 27. | Deployment target **iOS 26.0**, compilado con Xcode 26.x en CI. La app corre igual en iOS 27 y se puede compilar localmente con Xcode 27. Se sube a 27 cuando GitHub ofrezca Xcode 27. | 0 |
| C13 | **Confirmado e incorporado a `INTENT.md`.** `INTENT.md` no definía el texto de la notificación para una tarjeta `failed` (el parser lanzó) ni para un Yappy `partial` sin contraparte, ni los títulos. | Tarjeta `failed`: "No pude leer un pago con tarjeta, revísalo en la app." Sin contraparte: la pregunta sin el "en …" ("¿En qué gastaste $49.06?"). Títulos: "Gasto", "Ingreso", "Revisar movimiento". | 3 |
| C11 | Un pago de la cuenta personal al propio negocio llega dos veces con la misma `confirmation`; deduplicar solo por `confirmation` pierde uno. | **Confirmado e incorporado a `INTENT.md`.** Clave de deduplicación = `confirmation` + `direction`. | 2 |

## 3. Arquitectura y convenciones (aplican a todas las fases)

### Estructura del repo

```
project.yml                   ← XcodeGen: targets, capabilities y entitlements. El
                                 .xcodeproj se genera y no se versiona
Configs/                      ← Base.xcconfig; Local.xcconfig (Team ID) fuera de git
Gastario/                     ← target iOS: UI, App Intents, Notificaciones, Adjuntos, Ajustes
Packages/
  GastarioParsing/            ← SOLO Foundation. Parsers puros. Testeable en macOS y Linux.
  GastarioCore/               ← Modelos SwiftData, CaptureService, ReparseService, CSVExporter,
                                 BackupPolicy. Depende de GastarioParsing. Testeable en macOS.
scripts/verify.sh             ← lo mismo que corre CI
```

Por qué XcodeGen y no un `.xcodeproj` versionado: un agente en la nube no tiene Xcode. Con `project.yml` puede agregar el App Group (Fase 0), iCloud Documents (Fase 5) o el target de la Share Extension (v1.1) editando YAML legible; con un `pbxproj` versionado tendría que editarlo a mano. El costo es instalar XcodeGen y correr `xcodegen generate` después de agregar archivos.

Por qué dos paquetes y no uno: un agente que corre en la nube (Linux) puede desarrollar y probar `GastarioParsing` completo sin Xcode. `GastarioCore` necesita SwiftData, que solo existe en plataformas Apple; se trabaja con Claude Code local en la Mac. El target de app no tiene lógica probable por unidad: todo lo que se pueda probar vive en los paquetes.

### Entorno y verificación

- `scripts/verify.sh` es la única definición de "verde". En macOS corre ambos paquetes y compila la app en Debug y Release sin firmar; en Linux corre solo `GastarioParsing`.
- CI tiene dos jobs: `linux` (imagen `swift`) y `macos` (Xcode 26.x, SDK de iOS 26). Un PR no se mergea con ninguno en rojo.
- `GastarioParsing` solo importa `Foundation`; `verify.sh` falla si importa otra cosa.
- Las sesiones de Claude Code en la nube instalan Swift para Linux con `.claude/hooks/session-start.sh`. Ahí se desarrolla y prueba `GastarioParsing`; lo que depende de SwiftData o UIKit se escribe en la nube pero lo verifica el job `macos`.

### Reglas

- Swift 6, concurrencia estricta. Swift Testing (`@Test`), no XCTest, salvo en UI tests si llegan a existir.
- Las suites de prueba que crean containers o modelos de SwiftData son `@MainActor`. Swift Testing corre las suites en paralelo, y SwiftData usado desde varios hilos a la vez tumbó el proceso de pruebas en CI (señal 11, de forma intermitente).
- Montos siempre `Decimal`. Prohibido `Double` para dinero. `Decimal(string:locale:)` con `en_US_POSIX`.
- Enums persistidos con `String` raw value.
- Toda zona horaria explícita: `TimeZone(identifier: "America/Panama")!`. Nunca `.current` en lógica de parseo o agrupación.
- Inyección por protocolo para los efectos laterales del pipeline de captura (`MovementNotifier`, `BackupTrigger`). Las fases tempranas usan implementaciones no-op; las fases posteriores las reemplazan sin tocar el pipeline.
- Ningún intent lanza error a Shortcuts por un fallo de parseo. Solo lanza si el store es inaccesible (el Append del CSV viejo ya habrá corrido).
- Definition of done por fase: compila sin warnings nuevos, `swift test` verde en ambos paquetes, `README.md` al día (ver `CLAUDE.md`, "Antes de abrir un PR"), checklist del gate marcado en el PR.

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

Las fases 0 y 1 pueden correr en paralelo (dos agentes, dos ramas). La Fase 1 es dueña de `Packages/GastarioParsing`; la Fase 0 no lo crea.

---

## Fase 0 — Fundación

**Objetivo.** Proyecto compilable en dispositivo con el store de SwiftData en el App Group desde el primer commit, modelos completos y una lista mínima para ver datos.

**Alcance.**
- `project.yml` (XcodeGen) con bundle id y capability **App Groups** (`group.<bundle-id>`). iCloud Documents se habilita en Fase 5 (es solo un toggle, no una migración).
- Paquete `GastarioCore`, que depende de `GastarioParsing` (lo crea la Fase 1; si la Fase 0 empieza antes de mergearla, se basa en su rama).
- Modelos `Movement` y `Attachment` según `INTENT.md` + C1 + C2. Relación `attachments` con `deleteRule: .cascade`. **Sin** `@Attribute(.unique)` en `confirmation`.
- `GastarioStore.makeContainer(inMemory: Bool) -> ModelContainer`. En disco apunta a `FileManager.containerURL(forSecurityApplicationGroupIdentifier:)`. Falla en voz alta (`fatalError` con mensaje) si el App Group no está disponible: es un error de configuración, no de runtime.
- `MovementListView` de solo lectura con `@Query`, agrupada por día en `America/Panama`, orden `occurredAt` descendente. Muestra contraparte, monto con signo, ícono de fuente, badges "sin nota" y "requiere revisión".
- `#if DEBUG`: menú para insertar movimientos de muestra y para borrar todo.

**Fuera de alcance.** Cualquier edición, intents, notificaciones.

**Entregables.**
- `Packages/GastarioCore/Sources/GastarioCore/Models/{Movement,Attachment,Enums}.swift`
- `Packages/GastarioCore/Sources/GastarioCore/Store/GastarioStore.swift`
- `Gastario/App/GastarioApp.swift`, `Gastario/Movements/MovementListView.swift`
- `project.yml` con la capability App Groups. Desde la Fase 5 las capabilities viven en `Configs/Gastario.entitlements` (versionado) y `Configs/Base.xcconfig` elige el archivo.
- README corto en cada paquete: cómo correr `swift test`.
- `scripts/verify.sh` sin la tolerancia a partes faltantes: si un paquete o `project.yml` no existe, falla.

**Pruebas automáticas.**
- Insertar y leer un `Movement` en container en memoria.
- Borrar un `Movement` con dos `Attachment` → cero attachments restantes (cascade).
- `editedFields` y `parseIssues` sobreviven un ciclo guardar/leer.

**Gate de salida.**
- [ ] `swift test` verde en ambos paquetes.
- [ ] 📱 La app abre en el dispositivo. El log de arranque (categoría `app`) imprime la URL del store y contiene `Shared/AppGroup`, la ruta de los App Groups en iOS. (`Group Containers` es la ruta en macOS.)
- [ ] 📱 Insertar muestras desde el menú DEBUG, cerrar la app desde el switcher, reabrir → siguen ahí.

**Riesgos.** ~~Verificar contra el SDK de iOS 27 que SwiftData acepte `Set<ParseIssue>` y `Set<EditableField>` como atributos Codable sin transformer; si no, persistir como `[String]`.~~ **Resuelto:** enums y conjuntos se persisten como `String` / `[String]` con accesores tipados. Evita el riesgo y permite predicados sobre `parseStatusRaw` en la Fase 4.

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
- HTML tal como lo entrega `Content`: `sent-with-message.html`, `sent-without-message.html`, `received.html`.
- `paid-merchant-content.txt`: "Pagaste" real tal como llegó al intent (texto plano), desde la vista de cuerpo crudo. Coincide línea por línea con `paid-merchant-with-message.txt`.
- Texto plano copiado de Mail (todavía sin HTML de estos tipos): `sent-as-text.txt`, `paid-merchant.txt`, `paid-merchant-with-message.txt`, `commercial-received.txt`, `commercial-online-purchase.txt`.
- Sintéticos derivados de un real: `amount-with-comma.html`, variantes de fecha `date-narrow-nbsp.html` (U+202F) y `date-plain.html`. La variante U+00A0 es la de los fixtures reales.
- `unexpected-format.txt` (cuerpo que no es de Yappy).
- Los datos personales (nombres, teléfonos, confirmaciones, números de pedido, negocio) se reemplazan conservando el formato.

Los cuerpos deben ser **reales**, copiados desde Mail (seleccionar todo el cuerpo → copiar). Cuando exista la vista de cuerpo crudo (Fase 4), se comparan contra lo que llega al intent y se reemplazan si difieren. Hasta recibir los reales, el agente trabaja con fixtures sintéticos marcados `// SYNTHETIC` en el nombre del test; el gate no se cierra con sintéticos.

**Pruebas automáticas.** Un test por fixture y por fila de la tabla de montos de `INTENT.md` (`$3.80`, `$1,250.00`, `B/.3.80`, `USD 3.80`, `""`, `"$0.00"`). Cubren AC-2, AC-3, AC-4, AC-16 y la mitad de parseo de AC-7 y AC-12.

**Gate de salida.**
- [ ] `swift test` verde en `GastarioParsing` en macOS **y** en Linux (jobs `macos` y `linux` de CI).
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
  - Dedup Yappy por `confirmation` + `direction` (C11), **después** de los pasos 1–3: la confirmación sale del parser, y parsear antes de guardar el crudo perdería la captura si el parser falla (principio 2). Si existe otro movimiento con la misma clave → se borra el recién insertado y se devuelve `.duplicate`, sin tocar el existente y sin notificar. Sin `confirmation` o sin `direction` no hay dedup (C3).
  - El parser se inyecta (`CaptureParser`) para poder probar con uno que lanza.
  - `@MainActor`: las capturas del proceso se serializan, así dos correos iguales simultáneos no pasan ambos la dedup.
  - `rawInputs` = JSON de `CardRawInputs` (Codable) tal como llegó.
- `Gastario/Intents/LogCardMovementIntent.swift`, `LogYappyEmailIntent.swift`:
  - Títulos "Log Card Transaction" y "Log Yappy Email".
  - Modo background con `supportedModes = .background` (iOS 26+; verificado: compila con Xcode 26.6).
  - Usan un único container por proceso (compartido con la app) y llaman a `CaptureService`. Devuelven `.result()` siempre que el store responda, también en `.duplicate` y en `failed`.
  - Todos los parámetros son opcionales: uno requerido que llega vacío hace que Atajos pregunte, y en segundo plano eso detiene la captura (principio 1). `nil` se guarda como `""`.
- Instrucciones para configurar los dos atajos en `docs/shortcuts.md`, copiadas de `INTENT.md`, con el `Append to Text File` **antes** del intent.

**Fuera de alcance.** Notificaciones, export, UI.

**Pruebas automáticas** (container en memoria, `MovementNotifier` espía):
- Tarjeta completa → `card`/`outflow`, monto `Decimal`, `ok`, notifier llamado una vez. (AC-1 sin la notificación)
- Tarjeta con `Amount = "0"` o `Merchant = ""` → `partial`, issues correctos, se guarda. (AC-12)
- Tarjeta sin ciudad ni coordenadas → se guarda con nulos. (AC-10)
- Mismo correo dos veces, el primero con `note` → un `Movement`, `note` intacta, notifier llamado una vez. (AC-6)
- Dos correos distintos → dos movimientos. (AC-5)
- Misma `confirmation` con dirección opuesta (pago al propio negocio por Yappy Comercial) → dos movimientos. (C11)
- Cuerpo inesperado → `failed`, `rawContent` guardado, notifier llamado. (AC-7)
- El `Movement` existe en el store **antes** de que termine el parseo (inyectar un parser que lance; el movimiento queda `failed` con crudo). Principio 2.

**Gate de salida.**
- [ ] Tests anteriores verdes.
- [ ] 📱 Ambos atajos configurados según `docs/shortcuts.md`. Pagar con Apple Pay → el movimiento aparece en la lista sin abrir la app durante el pago.
- [ ] 📱 Recibir un Yappy → aparece. Correr el atajo de email dos veces sobre el mismo correo → un solo movimiento.
- [ ] 📱 El CSV viejo sigue recibiendo filas (el Append va antes del intent).
- [ ] 📱 Un correo de otro remitente que llega junto con un Yappy no crea movimiento (`If` del remitente dentro del `Repeat`).
- [ ] 📱 Un Yappy que llega **después** de otro correo en el mismo lote sí entra (el trigger no filtra por remitente).

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
- Swift 6: los métodos del delegate son `nonisolated` y solo pasan valores `Sendable` al `MainActor`; permiso y programación usan las APIs `async` desde funciones `nonisolated` (un completion handler creado en el `MainActor` y llamado desde otro hilo falla la verificación de aislamiento).
- El detalle de solo lectura muestra `note` y `notedAt`, para verificar AC-8 en el dispositivo.

**Pruebas automáticas.**
- `NotificationText` para los 6 casos: salida, entrada, tarjeta sin monto, sin comercio, sin ambos, Yappy `failed`. Más los de C13 y un monto con coma.
- `NotificationText` recibe valores simples (con una sobrecarga para `Movement`), así se prueba también fuera de SwiftData.
- `NoteReplyHandler` con container en memoria: guarda `note` y `notedAt`; con un ID inexistente no lanza.

**Gate de salida.**
- [ ] 📱 AC-1 completo: pago → notificación con el texto correcto.
- [x] 📱 AC-8: dejar la notificación varias horas, matar la app desde el switcher, responder desde el Centro de Notificaciones → abrir la app → `note` y `notedAt` guardados.
- [ ] 📱 AC-7 y AC-12: llegan las notificaciones de revisión / completar.
- [ ] 📱 Dedup: un correo repetido no genera segunda notificación (AC-6).

**Riesgos.** Si `didReceive` llega antes de que el container esté listo, la respuesta se pierde: por eso el container se crea síncronamente en `didFinishLaunching`. Medir que no exceda el tiempo de arranque en frío.

---

## Fase 4 — Revisión y edición

**Objetivo.** Todo lo que permite confiar en los datos: ver qué falló, corregirlo, re-parsear, agregar lo que la automatización no capturó y borrar lo que sobra.

**Alcance.**
- **Filtros** en la lista: "Todos", "Sin nota" (`note == nil`), "Requiere revisión" (`parseStatus != ok`; en el control segmentado dice "Revisar"). Cuenta en cada filtro. Se filtra en memoria sobre el `@Query`: el volumen personal no justifica predicados dinámicos.
- **Detalle** (`MovementDetailView`):
  - Todos los campos. Link a Maps si hay coordenadas. Aviso si es Yappy sin `confirmation` (C3).
  - Sección **Cuerpo crudo** para Yappy, con botón "Copiar" (para alimentar fixtures). Para tarjeta, `rawInputs` formateado. **Adelantado:** una versión de solo lectura (campos, hora de captura con segundos y cuerpo crudo) entró después de la Fase 2 para diagnosticar capturas reales; la Fase 4 la vuelve editable.
  - Edición en una hoja ("Editar") que solo aplica los campos que cambiaron, vía `GastarioCore/Editing/MovementEditor`. Montos con el mismo `AmountParser` de la captura.
  - Edición de `amount`, `counterparty`, `occurredAt`. Cada edición agrega el campo a `editedFields` y quita su `ParseIssue`. Si `parseIssues` queda vacío y el estado era `partial` → `ok`. Un `failed` **no** cambia por edición: solo por re-parseo (su crudo no se entendió; editar a mano no lo valida).
  - `note` editable; al guardar asigna `notedAt` si estaba vacío.
  - Botón "Re-parsear" en `card`/`yappy`.
- `GastarioCore/Reparse/ReparseService`:
  - `reparse(_ movement:)`: vuelve a correr el parser sobre `rawInputs`/`rawContent`, escribe solo los campos **no** incluidos en `editedFields`, recalcula `parseStatus` y `parseIssues` (un campo editado nunca cuenta como issue). No toca `note`, `notedAt`, `attachments`. Ignora `manual`.
  - `reparseAll()`: solo `parseStatus != ok`. Devuelve conteo de cambiados.
- **Entrada manual** (`+`): monto, dirección, contraparte, fecha (default ahora), nota opcional. Crea `source = manual`, `parseStatus = ok`, sin pasar por `CaptureService` → sin notificación.
- **Borrar**: swipe con `confirmationDialog`. Cascade borra adjuntos. También retira la notificación entregada del movimiento, para que no quede una pregunta sobre algo que ya no existe.
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
- [x] Fixtures de Fase 1 comparados con el cuerpo crudo real capturado; reemplazados si difieren. ("Pagaste" real coincide con el fixture de Mail; agregado como `paid-merchant-content.txt`.)

---

## Fase 5 — Exportar y respaldo

**Objetivo.** Nunca depender del dispositivo como única copia. El CSV completo se escribe a iCloud Drive cada 7+ días, aunque la app no se abra.

**Alcance.**
- Capability **iCloud Documents** (ubiquity container `iCloud.com.renandiaz.Gastario`, no CloudKit), en `Configs/Gastario.entitlements`. Los equipos personales (cuenta gratis) no admiten iCloud: `Configs/Local.xcconfig` puede elegir `Configs/Gastario-SinICloud.entitlements` (sin respaldo automático; el error queda en Ajustes y la captura no se ve afectada). `NSUbiquitousContainers` en Info.plist con `NSUbiquitousContainerIsDocumentScopePublic = true` para que la carpeta aparezca en Files. Como es un diccionario, XcodeGen genera `Gastario/Info.plist` desde `project.yml` (no se versiona), con las versiones enlazadas a `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`.
- `GastarioCore/Export/CSVExporter.export(_ rows: [CSVRow]) -> Data` (filas con valores simples, más `CSVRow(movement)`; se prueba también fuera de SwiftData). Fin de línea CRLF (RFC 4180). Montos con dos decimales y punto: columnas exactas de `INTENT.md`, montos con signo (`outflow` negativo), fechas según C6, escape RFC 4180 (comillas dobles, saltos de línea dentro de `note`), `attachmentCount` = `attachments.count`. Sin BOM.
- `GastarioCore/Export/BackupPolicy`: `isDue(lastExportAt:now:)` → 7 días. Estado en `UserDefaults` del App Group (C4): `lastExportAt`, `lastExportAttemptAt`, `lastExportError`.
- `Gastario/Export/BackupService`: implementa `BackupTrigger`. Obtiene `FileManager.url(forUbiquityContainerIdentifier: nil)` **fuera del main actor** (puede bloquear), escribe en `Documents/` con el nombre de C5. Cualquier error se registra en `lastExportError` y **nunca** se propaga al intent.
- Puntos de evaluación: paso 6 del `CaptureService` (reemplaza el no-op) y `scenePhase == .active` al abrir la app.
- Ajustes: fecha del último export, último error si lo hay, "Exportar ahora" (fuerza el export a iCloud **y** ofrece `ShareLink` del mismo archivo, que se escribe también en el directorio temporal: se puede compartir aunque iCloud falle).
- `#if DEBUG`: botón "Simular 8 días sin export" que retrocede `lastExportAt`.

**Pruebas automáticas.**
- Golden test de `CSVExporter` con 3 movimientos (uno con coma y comillas en `note`, uno `inflow`, uno sin ubicación).
- `BackupPolicy.isDue` en los bordes: 6d23h → no; 7d → sí; nunca exportado → sí.
- ~~`CaptureService` con un `BackupTrigger` que lanza → la captura igual termina `.created`.~~ Garantizado por tipo: `BackupTrigger.runIfDue()` no es `throws`, así que no puede propagar un error a la captura.
- `BackupState` en un `UserDefaults` de prueba: un fallo no mueve `lastExportAt`; un éxito limpia el error.
- Nombre de archivo de C5 en hora de Panamá.

**Gate de salida.**
- [ ] Tests verdes.
- [x] 📱 AC-11: "Exportar ahora" → el archivo abre en Numbers, una fila por movimiento, montos con signo, fechas legibles.
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

**Notas de implementación.**
- La lógica probable vive en `GastarioCore/Attachments`: `AttachmentRules` (links; el QR es estricto, un link escrito a mano sin esquema se completa con `https://`) e `ImageCompressor` (ImageIO, aplica la orientación EXIF y nunca agranda una imagen chica).
- La compresión corre fuera del main actor.
- La vista previa usa `.quickLookPreview` de SwiftUI sobre un archivo temporal.

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
| Q1 | ~~Bundle id y Team ID para el App Group y el ubiquity container.~~ **Resuelta:** `com.renandiaz.Gastario`, App Group `group.com.renandiaz.Gastario`. El Team ID va en `Configs/Local.xcconfig`, fuera de git. | F0 |
| Q2 | ~~Tres cuerpos reales de correo Yappy (enviado con mensaje, sin mensaje, recibido), copiados desde Mail.~~ **Resuelta:** recibidos en HTML (lo que entrega `Content`), más pago a comercio y Yappy Comercial en texto. Ver C10. | Gate F1 |
| Q3 | ~~Formato exacto del `Amount` que entrega el trigger de Wallet hoy (revisar el CSV viejo: ¿`3.80`, `$3.80`, `B/.3.80`?).~~ **Resuelta:** `$46.55` (con `$` y punto decimal), visto en "Datos recibidos" de una compra real con Apple Pay. `AmountParser` ya lo cubría; queda una prueba con ese formato. | F1 (fixtures), F2 |
| Q4 | ~~Confirmar C1–C9 o indicar cuáles cambian.~~ **Resuelta:** confirmados. | F0 (C1, C2), F5, F6 |
| Q5 | ~~¿La lista muestra montos de `partial` con `amount = 0` como `$0.00` o como "—"?~~ **Resuelta:** "—" con el badge de revisión. | F0 |
