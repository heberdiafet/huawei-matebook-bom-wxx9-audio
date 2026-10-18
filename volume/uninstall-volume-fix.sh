#!/usr/bin/env bash
#
# Revierte el ajuste de volumen (vuelve al perfil UCM de la distribución).
#
# Uso:  bash uninstall-volume-fix.sh
#
set -euo pipefail

UCM_DEST="${HOME}/.local/share/alsa-ucm2-hp"
DROP_FILE="${HOME}/.config/systemd/user/wireplumber.service.d/50-ucm-hp.conf"
BIN="${HOME}/.local/bin/huawei-hpfix-gain.sh"
UNIT="${HOME}/.config/systemd/user/huawei-hpfix-gain.service"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; exit 1; }

[[ ${EUID} -ne 0 ]] || die "Ejecútalo sin sudo."

log "Parando y eliminando el servicio de ganancia"
systemctl --user disable --now huawei-hpfix-gain.service >/dev/null 2>&1 || true
rm -f "${UNIT}" "${BIN}"

log "Eliminando drop-in de systemd y árbol UCM propio"
rm -f "${DROP_FILE}"
rmdir "$(dirname "${DROP_FILE}")" 2>/dev/null || true
rm -rf "${UCM_DEST}"

log "Reiniciando WirePlumber"
systemctl --user daemon-reload
systemctl --user restart wireplumber.service
sleep 2

gsettings set org.gnome.desktop.sound allow-volume-above-100-percent false 2>/dev/null || true

log "Hecho. Vuelve el perfil UCM de /usr/share/alsa/ucm2"
