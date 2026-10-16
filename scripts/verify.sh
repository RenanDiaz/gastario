#!/usr/bin/env bash
# Verifica pruebas y build. Es lo mismo que corre CI (SPEC §3, "Entorno y verificación").
#   macOS (Xcode + XcodeGen): paquetes, herramienta de la Fase 7 y build de la app en Debug y
#   Release, sin firmar.
#   Linux (nube, job `linux` de CI): GastarioParsing y la herramienta de la Fase 7, que no
#   dependen de Apple.
set -euo pipefail
cd "$(dirname "$0")/.."

DERIVED_DATA=build/DerivedData
PARSING=Packages/GastarioParsing
CORE=Packages/GastarioCore
TRANSITION=Tools/TransitionReport

# Todo lo que se verifica tiene que existir: si falta, es un error, no algo que se omite.
for required in "$PARSING/Package.swift" "$CORE/Package.swift" "$TRANSITION/Package.swift" project.yml; do
  if [[ ! -f $required ]]; then
    echo "ERROR: falta $required" >&2
    exit 1
  fi
done

echo "==> GastarioParsing: solo importa Foundation"
bad=$(grep -rhoE '^[[:space:]]*(@[a-zA-Z_]+[[:space:]]+)*import[[:space:]]+[A-Za-z_.]+' "$PARSING/Sources" \
  | awk '{print $NF}' | cut -d. -f1 | sort -u | grep -vx 'Foundation' || true)
if [[ -n $bad ]]; then
  echo "ERROR: GastarioParsing importa módulos no permitidos: $bad" >&2
  exit 1
fi

echo "==> GastarioParsing: swift test"
swift test --package-path "$PARSING"

echo "==> TransitionReport: swift test"
swift test --package-path "$TRANSITION"

if [[ $(uname -s) != Darwin ]]; then
  echo "==> Linux: GastarioCore y la app requieren macOS; los verifica el job macos de CI"
  echo "==> Todo OK (Linux)"
  exit 0
fi

echo "==> GastarioCore: swift test"
swift test --package-path "$CORE"

echo "==> xcodegen generate"
xcodegen generate

for configuration in Debug Release; do
  echo "==> Build Gastario ($configuration, iOS Simulator)"
  xcodebuild -project Gastario.xcodeproj -scheme Gastario \
    -configuration "$configuration" -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath "$DERIVED_DATA" \
    CODE_SIGNING_ALLOWED=NO -quiet build
done

echo "==> Todo OK"
