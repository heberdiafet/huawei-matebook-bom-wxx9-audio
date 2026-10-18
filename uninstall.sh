#!/usr/bin/env bash
#
# Desinstala el parche de audio DKMS para HUAWEI BOM-WXX9.
#
# Uso:  sudo bash uninstall.sh
#
set -euo pipefail

PKG="huawei-hpfix"
VER="1.0.0"
SRC_DIR="/usr/src/${PKG}-${VER}"
KVER="$(uname -r)"

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; exit 1; }

[[ ${EUID} -eq 0 ]] || die "Ejecuta este script con sudo:  sudo bash uninstall.sh"

log "Eliminando módulo de DKMS"
for k in $(dkms status -m "${PKG}" -v "${VER}" 2>/dev/null | awk -F'[,/: ]+' '{print $3}'); do
  dkms remove -m "${PKG}" -v "${VER}" -k "${k}" >/dev/null 2>&1 || true
done
dkms remove --all -m "${PKG}" -v "${VER}" >/dev/null 2>&1 || true

log "Borrando fuentes ${SRC_DIR}"
rm -rf "${SRC_DIR}"

depmod -a "${KVER}" || true

cat <<EOF

Listo. El módulo original del kernel vuelve a usarse tras reiniciar:
   sudo reboot

Verificación: no debe aparecer nada al ejecutar
   dkms status -m ${PKG}
EOF
