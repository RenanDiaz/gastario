# Gastario

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/marca/lockup-gastario-oscuro.svg">
  <img src="docs/marca/lockup-gastario.svg" alt="Gastario" height="64">
</picture>

App iOS que registra cada pago con Apple Pay y cada Yappy, y permite anotar en qué fue cada movimiento respondiendo desde la notificación.

> **Documentos del proyecto.** El qué y el porqué están en [`INTENT.md`](INTENT.md); el cómo y el orden, en [`SPEC.md`](SPEC.md). Este README solo explica cómo compilar y verificar. Si contradice al spec, gana el spec.

## Estado

| Fase | Estado |
|---|---|
| 0. Fundación | Cerrada |
| 1. Parsers | Cerrada |
| 2. Captura ([`docs/shortcuts.md`](docs/shortcuts.md)) | Implementada; faltan las verificaciones 📱 del gate |
| 3. Notificaciones | Implementada; faltan las verificaciones 📱 del gate |
| 4. Revisión y edición | Implementada; faltan las verificaciones 📱 y comparar los fixtures de la Fase 1 con el cuerpo crudo real |
| 5. Exportar y respaldo (iCloud Drive) | Implementada; faltan las verificaciones 📱 del gate |
| 6. Adjuntos (foto, PDF, link, QR de factura) | Implementada; faltan las verificaciones 📱 del gate |
| 7. Transición | Sigue (operativa, sin código) |

Pendiente de decisión: [Q3](SPEC.md#5-preguntas-abiertas-bloquean-la-fase-indicada) (formato del `Amount` de Wallet) y confirmar [C13](SPEC.md#2-cambios-propuestos-a-intentmd) (textos de notificación). Detalle de cada fase en el [mapa de fases](SPEC.md#mapa-de-fases).

## Requisitos

| | Versión |
|---|---|
| Mac de build | Xcode 26 o posterior (Swift 6) |
| App | iOS 26+ (iPhone); deployment target en [`SPEC.md` §2, C12](SPEC.md#2-cambios-propuestos-a-intentmd) |
| Cuenta de Apple | Developer pagada: iCloud Documents no está disponible con una cuenta gratis, y la firma gratis vence a los 7 días |
| Herramientas | [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`) |

## Primeros pasos

```bash
# 1. Team ID para firmar (archivo local, fuera de git)
cp Configs/Local.xcconfig.example Configs/Local.xcconfig
#    edita DEVELOPMENT_TEAM con tu Team ID

# 2. Generar el proyecto
xcodegen generate
open Gastario.xcodeproj
```

Con el Team ID puesto y firma automática, Xcode registra el App Group `group.com.renandiaz.Gastario` la primera vez que compilas en el iPhone. En la consola de Xcode, el arranque imprime la ruta del store: debe contener `Shared/AppGroup`.

Lo mismo pasa con el contenedor de iCloud `iCloud.com.renandiaz.Gastario`, que usa el respaldo. **Con un equipo personal (cuenta gratis)** Xcode no puede firmar: "Personal development teams … do not support the iCloud capability". Mientras tanto, descomenta `GASTARIO_ENTITLEMENTS` en tu `Configs/Local.xcconfig` (ver `Local.xcconfig.example`): la app firma sin iCloud, el respaldo automático queda deshabilitado y "Exportar ahora" sigue ofreciendo el CSV para compartir. Si la carpeta "Gastario" no aparece en Archivos → iCloud Drive después del primer export, sube `CURRENT_PROJECT_VERSION` en `Configs/Base.xcconfig` y reinstala: iOS solo vuelve a leer `NSUbiquitousContainers` cuando cambia el número de build.

Vuelve a correr `xcodegen generate` cada vez que agregues o quites archivos o cambies `project.yml`.

## Verificación

```bash
scripts/verify.sh
```

Es lo mismo que corre CI (GitHub Actions, en cada push a `main`, `claude/**` y `phase-*`, y en cada PR):

| Job | Runner | Qué verifica |
|---|---|---|
| `linux` | `swift:6.4.1-noble` | `GastarioParsing` solo importa `Foundation`; `swift test` de `GastarioParsing` |
| `macos` | `macos-26` | Lo anterior + `swift test` de `GastarioCore` + build de la app en Debug y Release, sin firmar |

Si falta `project.yml` o alguno de los dos paquetes, `verify.sh` falla: no omite nada.

### Sesiones de Claude Code en la nube

[`.claude/hooks/session-start.sh`](.claude/hooks/session-start.sh) instala Swift para Linux al iniciar la sesión, así el agente puede correr `verify.sh` (la parte de Linux). Necesita que la política de red del environment permita `download.swift.org`; si no, avisa y la sesión sigue sin Swift.

## Estructura

```
gastario/
├── INTENT.md, SPEC.md       # qué y por qué / cómo y en qué orden
├── project.yml              # XcodeGen: fuente de verdad del proyecto
├── Configs/                 # xcconfig y entitlements (con y sin iCloud); Local.xcconfig fuera de git
├── Gastario/                # target iOS
│   ├── Assets.xcassets/     # ícono de la app (clara, oscura, tintada)
│   ├── App/                 # arranque, AppDelegate, contenedor SwiftData en el App Group
│   ├── Intents/             # App Intents de captura (tarjeta y Yappy)
│   ├── Notifications/       # notificaciones con respuesta
│   ├── Movements/           # lista, detalle, edición y entrada manual
│   ├── Export/              # respaldo semanal del CSV en iCloud Drive
│   ├── Attachments/         # adjuntos: foto, PDF, link y QR
│   ├── Settings/
│   └── Debug/
├── Packages/
│   ├── GastarioParsing/     # parsers puros, solo Foundation, probados también en Linux
│   └── GastarioCore/        # SwiftData y servicios, solo plataformas Apple
├── docs/
│   ├── shortcuts.md         # cómo configurar los atajos de captura
│   └── marca/               # ícono y lockup en SVG, capas para Icon Composer
├── scripts/verify.sh
├── .github/workflows/ci.yml # jobs linux y macos
└── .claude/                 # hook de inicio para sesiones en la nube
```

Detalle en [`SPEC.md` §3](SPEC.md#3-arquitectura-y-convenciones-aplican-a-todas-las-fases).
