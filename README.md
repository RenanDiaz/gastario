# Gastario

App iOS que registra cada pago con Apple Pay y cada Yappy, y permite anotar en qué fue cada movimiento respondiendo desde la notificación.

> **Documentos del proyecto.** El qué y el porqué están en [`INTENT.md`](INTENT.md); el cómo y el orden, en [`SPEC.md`](SPEC.md). Este README solo explica cómo compilar y verificar. Si contradice al spec, gana el spec.

## Estado

Fase 1 (parsers) cerrada: `GastarioParsing` con fixtures reales de Yappy. Sigue la Fase 0 ([`SPEC.md` §3, mapa de fases](SPEC.md#mapa-de-fases)), bloqueada por Q1, Q4 y Q5 ([§5](SPEC.md#5-preguntas-abiertas-bloquean-la-fase-indicada)).

## Requisitos

| | Versión |
|---|---|
| Mac de build | Xcode con el SDK de iOS 27 (Swift 6) |
| App | iOS 27 (iPhone) |
| Herramientas | [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`) |

## Primeros pasos

```bash
# 1. Team ID para firmar (archivo local, fuera de git)
cp Configs/Local.xcconfig.example Configs/Local.xcconfig
#    edita DEVELOPMENT_TEAM con tu Team ID

# 2. Generar el proyecto (desde la Fase 0)
xcodegen generate
open Gastario.xcodeproj
```

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

Hasta cerrar las fases 0 y 1, `verify.sh` omite con aviso los paquetes y el proyecto que todavía no existen.

### Sesiones de Claude Code en la nube

[`.claude/hooks/session-start.sh`](.claude/hooks/session-start.sh) instala Swift para Linux al iniciar la sesión, así el agente puede correr `verify.sh` (la parte de Linux). Necesita que la política de red del environment permita `download.swift.org`; si no, avisa y la sesión sigue sin Swift.

## Estructura

```
gastario/
├── INTENT.md, SPEC.md       # qué y por qué / cómo y en qué orden
├── project.yml              # XcodeGen: fuente de verdad del proyecto (Fase 0)
├── Configs/                 # xcconfig compartido; Local.xcconfig (Team ID) fuera de git
├── Gastario/                # target iOS (Fase 0)
├── Packages/
│   ├── GastarioParsing/     # parsers puros, solo Foundation, probados también en Linux
│   └── GastarioCore/        # SwiftData y servicios, solo plataformas Apple
├── scripts/verify.sh
└── .claude/                 # hook de inicio para sesiones en la nube
```

Detalle en [`SPEC.md` §3](SPEC.md#3-arquitectura-y-convenciones-aplican-a-todas-las-fases).
