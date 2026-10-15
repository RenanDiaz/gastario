#!/bin/bash
# Instala el toolchain de Swift para Linux en las sesiones de Claude Code en la nube,
# para poder correr `scripts/verify.sh` (que en Linux prueba solo GastarioParsing, SPEC §3).
# Idempotente: si la versión fijada ya está instalada, no hace nada.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ] || [ "$(uname -s)" != "Linux" ]; then
  exit 0
fi

# Mantener alineada con la imagen del job `linux` en .github/workflows/ci.yml.
SWIFT_VERSION=6.4.1
INSTALL_DIR=/opt/swift-$SWIFT_VERSION

if [ -x "$INSTALL_DIR/usr/bin/swift" ]; then
  echo "export PATH=\"$INSTALL_DIR/usr/bin:\$PATH\"" >> "$CLAUDE_ENV_FILE"
  exit 0
fi

# Dependencias del toolchain en Ubuntu 24.04 (swift.org/install/linux). tzdata es necesaria:
# los parsers usan America/Panama.
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq binutils git gnupg2 libc6-dev libcurl4-openssl-dev libedit2 \
  libgcc-13-dev libncurses-dev libpython3-dev libsqlite3-0 libstdc++-13-dev libxml2-dev \
  libz3-dev pkg-config tzdata unzip zlib1g-dev >/dev/null

arch_suffix=""
[ "$(uname -m)" = "aarch64" ] && arch_suffix="-aarch64"
platform="ubuntu24.04"
name="swift-$SWIFT_VERSION-RELEASE-$platform$arch_suffix"
url="https://download.swift.org/swift-$SWIFT_VERSION-release/${platform//./}$arch_suffix/swift-$SWIFT_VERSION-RELEASE/$name.tar.gz"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

if ! curl -fsSL -o "$tmp/swift.tar.gz" "$url" || ! curl -fsSL -o "$tmp/swift.tar.gz.sig" "$url.sig"; then
  # No bloquear la sesión: sin Swift el agente igual puede editar y CI verifica.
  echo "AVISO: no se pudo descargar Swift $SWIFT_VERSION desde download.swift.org." >&2
  echo "Revisa que la política de red del environment permita ese dominio." >&2
  exit 0
fi

# Verificar la firma con las llaves públicas del proyecto Swift.
export GNUPGHOME="$tmp/gnupg"
mkdir -m 700 "$GNUPGHOME"
curl -fsSL https://www.swift.org/keys/all-keys.asc | gpg --batch --quiet --import
gpg --batch --quiet --verify "$tmp/swift.tar.gz.sig" "$tmp/swift.tar.gz"

mkdir -p "$INSTALL_DIR"
tar -xzf "$tmp/swift.tar.gz" -C "$INSTALL_DIR" --strip-components=1
echo "export PATH=\"$INSTALL_DIR/usr/bin:\$PATH\"" >> "$CLAUDE_ENV_FILE"
"$INSTALL_DIR/usr/bin/swift" --version
