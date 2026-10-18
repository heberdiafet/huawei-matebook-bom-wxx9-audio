#!/usr/bin/env bash
#
# Instalación del parche de audio (jack de audífonos) para
# HUAWEI BOM-WXX9 / MateBook 14-15 AMD mediante DKMS.
#
# Uso:  sudo bash install.sh
#
set -euo pipefail

PKG="huawei-hpfix"
VER="1.0.0"
SRC_DIR="/usr/src/${PKG}-${VER}"
KVER="$(uname -r)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; exit 1; }

[[ ${EUID} -eq 0 ]] || die "Ejecuta este script con sudo:  sudo bash install.sh"

# ---------------------------------------------------------------- comprobación
log "Comprobando modelo de equipo"
BOARD_VENDOR="$(cat /sys/class/dmi/id/board_vendor 2>/dev/null || true)"
PRODUCT_NAME="$(cat /sys/class/dmi/id/product_name 2>/dev/null || true)"
PRODUCT_VER="$(cat /sys/class/dmi/id/product_version 2>/dev/null || true)"
log "  board_vendor=${BOARD_VENDOR}  product_name=${PRODUCT_NAME}  version=${PRODUCT_VER}"

if [[ "${BOARD_VENDOR}" != "HUAWEI" || "${PRODUCT_NAME}" != "BOM-WXX9" || "${PRODUCT_VER}" != "M1010" ]]; then
  warn "Este parche está pensado para HUAWEI / BOM-WXX9 / M1010."
  warn "En otro modelo puede silenciar el audio en vez de arreglarlo."
  read -r -p "¿Continuar de todas formas? [s/N] " ans
  [[ "${ans,,}" == "s" || "${ans,,}" == "si" || "${ans,,}" == "y" ]] || die "Cancelado."
fi

log "Kernel en ejecución: ${KVER}"

# ------------------------------------------------------------- dependencias
log "Instalando dependencias de compilación (dkms, cabeceras, gcc, pahole)"
apt-get update -qq || true
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  dkms build-essential "linux-headers-${KVER}" pahole kmod || \
  die "No se pudieron instalar las dependencias (¿repositorios y red OK?)."

[[ -d "/lib/modules/${KVER}/build" ]] || die "Faltan las cabeceras: /lib/modules/${KVER}/build"
command -v dkms >/dev/null || die "dkms no está disponible tras la instalación"

# --------------------------------------------------------- limpiar el pasado
log "Eliminando registros previos del parche (si los hubiera)"
dkms remove --all -m "${PKG}" -v "${VER}" >/dev/null 2>&1 || true

# --------------------------------------------------------------- árbol fuente
log "Instalando fuentes en ${SRC_DIR}"
rm -rf "${SRC_DIR}"
install -d -m 0755 "${SRC_DIR}"
( cd "${HERE}" && tar --exclude=./prebuilt --exclude=./reference -cf - . ) \
  | tar -xf - -C "${SRC_DIR}"
chmod 0644 "${SRC_DIR}/dkms.conf" "${SRC_DIR}/Makefile"

# ------------------------------------------------------------- DKMS build
log "Registrando el módulo en DKMS"
dkms add -m "${PKG}" -v "${VER}" >/dev/null || die "dkms add falló"

log "Compilando (dkms build)"
if ! dkms build -m "${PKG}" -v "${VER}" -k "${KVER}"; then
  echo
  warn "La compilación falló. Volcado del log de DKMS:"
  for f in "/var/lib/dkms/${PKG}/${VER}/build/make.log" \
           "/var/lib/dkms/${PKG}/${VER}/${KVER}"/*/log/make.log; do
    [[ -f "${f}" ]] && { echo "----- ${f} -----"; tail -40 "${f}"; }
  done
  die "dkms build falló para ${KVER}. Revisa el log anterior."
fi

log "Instalando en el árbol de módulos"
dkms install --force -m "${PKG}" -v "${VER}" -k "${KVER}" || die "dkms install falló"

depmod -a "${KVER}"

MODPATH="$(find "/lib/modules/${KVER}/updates/dkms" -name 'snd-acp-legacy-mach.ko*' 2>/dev/null | head -1)"
[[ -n "${MODPATH}" ]] || die "No se encontró el módulo instalado en /lib/modules/${KVER}/updates/dkms/"
log "Módulo instalado: ${MODPATH}"

dkms status -m "${PKG}" -v "${VER}"

# ------------------------------------------------------- recarga del módulo
log "Intentando recargar el controlador de audio"
if modprobe -r snd_acp_legacy_mach 2>/dev/null; then
  modprobe snd_acp_legacy_mach || warn "No se pudo recargar el módulo ahora."
else
  warn "El módulo está en uso por el servidor de sonido."
  warn "Reinicia el equipo para activar el cambio:  sudo reboot"
fi

cat <<EOF

========================================================================
 Instalación completada.

 Verificación (tras reiniciar):
   sudo dmesg | grep -i "headphone gpio"
   -> debe decir:  ... speaker gpio 0 active high, headphone gpio 1 active low

   modinfo -n snd_acp_legacy_mach
   -> debe apuntar a /lib/modules/${KVER}/updates/dkms/...

   dkms status -m ${PKG}
   -> debe decir:  ${PKG}/${VER}, ${KVER}: installed

   Prueba de sonido:
   aplay -D plughw:1,0 /usr/share/sounds/alsa/Front_Center.wav

 Desinstalar:
   sudo bash ${HERE}/uninstall.sh

 NOTA: tras cada actualización de kernel, DKMS recompilará el módulo
 automáticamente (AUTOINSTALL="yes").
========================================================================
EOF
