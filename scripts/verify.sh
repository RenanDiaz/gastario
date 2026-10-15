#!/usr/bin/env bash
# Verifica pruebas y build. Es lo mismo que corre CI (SPEC §3, "Entorno y verificación").
#   macOS (Xcode + XcodeGen): ambos paquetes + build de la app en Debug y Release, sin firmar.
#   Linux (nube, job `linux` de CI): solo GastarioParsing, que no puede depender de Apple.
set -euo pipefail
cd "$(dirname "$0")/.."

DERIVED_DATA=build/DerivedData
PARSING=Packages/GastarioParsing
CORE=Packages/GastarioCore

# Hasta cerrar las fases 0 y 1, partes del repo todavía no existen: se omiten con aviso.
# La Fase 0 quita esta tolerancia (SPEC, Fase 0, entregables).
skip() { echo "    OMITIDO: $1"; }

echo "==> GastarioParsing: solo importa Foundation"
if [[ -d $PARSING/Sources ]]; then
  bad=$(grep -rhoE '^[[:space:]]*(@[a-zA-Z_]+[[:space:]]+)*import[[:space:]]+[A-Za-z_.]+' "$PARSING/Sources" \
    | awk '{print $NF}' | cut -d. -f1 | sort -u | grep -vx 'Foundation' || true)
  if [[ -n $bad ]]; then
    echo "ERROR: GastarioParsing importa módulos no permitidos: $bad" >&2
    exit 1
  fi
else
  skip "$PARSING no existe todavía"
fi

echo "==> GastarioParsing: swift test"
if [[ -f $PARSING/Package.swift ]]; then
  swift test --package-path "$PARSING"
else
  skip "$PARSING no existe todavía"
fi

if [[ $(uname -s) != Darwin ]]; then
  echo "==> Linux: GastarioCore y la app requieren macOS; los verifica el job macos de CI"
  echo "==> Todo OK (Linux)"
  exit 0
fi

echo "==> GastarioCore: swift test"
if [[ -f $CORE/Package.swift ]]; then
  swift test --package-path "$CORE"
else
  skip "$CORE no existe todavía"
fi

if [[ -f project.yml ]]; then
  echo "==> xcodegen generate"
  xcodegen generate
  for configuration in Debug Release; do
    echo "==> Build Gastario ($configuration, iOS Simulator)"
    xcodebuild -project Gastario.xcodeproj -scheme Gastario \
      -configuration "$configuration" -destination 'generic/platform=iOS Simulator' \
      -derivedDataPath "$DERIVED_DATA" \
      CODE_SIGNING_ALLOWED=NO -quiet build
  done
else
  echo "==> Build de la app"
  skip "project.yml no existe todavía"
fi

echo "==> Todo OK"
