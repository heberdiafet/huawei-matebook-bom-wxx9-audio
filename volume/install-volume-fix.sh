#!/usr/bin/env bash
#
# Ajuste de volumen para HUAWEI BOM-WXX9 (acp3x-es83xx + códec ES8336).
#
# Deja la cadena analógica a 0 dB (DAC, Headphone Mixer y etapa HP) y deja que
# PipeWire haga todo el control de volumen en software.
#
#   Antes: WirePlumber movía DOS controles (DAC y Headphone Mixer); el
#          ecualizador analógico del HPMIX se saturaba al 65 % y la curva era
#          irregular.
#   Ahora: hardware siempre a 0 dB, volumen suave y monótono en software, y
#          se puede usar sobre-amplificación (150 %) para equipos difíciles.
#
# No necesita root: árbol UCM de usuario + servicio de systemd de usuario.
#
# Uso:  bash install-volume-fix.sh
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UCM_SRC="/usr/share/alsa/ucm2"
UCM_DEST="${HOME}/.local/share/alsa-ucm2-hp"
CARD_DIR="AMD/acp3x-es83xx"
CARD="acp3xes83xx"

DROP_DIR="${HOME}/.config/systemd/user/wireplumber.service.d"
DROP_FILE="${DROP_DIR}/50-ucm-hp.conf"

BIN="${HOME}/.local/bin/huawei-hpfix-gain.sh"
UNIT="${HOME}/.config/systemd/user/huawei-hpfix-gain.service"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; exit 1; }

[[ ${EUID} -ne 0 ]] || die "Ejecútalo sin sudo (es configuración de tu usuario)."
[[ -d "${UCM_SRC}/${CARD_DIR}" ]] || die "No existe ${UCM_SRC}/${CARD_DIR} (¿alsa-ucm-conf instalado?)"
command -v wpctl >/dev/null || die "wpctl no está disponible (¿PipeWire instalado?)"

# ------------------------------------------------------------------- árbol UCM
log "Creando árbol UCM de usuario en ${UCM_DEST}"
rm -rf "${UCM_DEST}"
mkdir -p "$(dirname "${UCM_DEST}")"
cp -asT "${UCM_SRC}" "${UCM_DEST}"

log "Sobrescribiendo el perfil de ${CARD_DIR}"
# OJO: los ficheros del árbol son symlinks a /usr/share; hay que borrarlos
# antes de copiar para no escribir en el original.
rm -f "${UCM_DEST}/${CARD_DIR}/acp3x-es83xx.conf" "${UCM_DEST}/${CARD_DIR}/HiFi.conf"
cp "${HERE}/ucm/${CARD_DIR}/acp3x-es83xx.conf" "${UCM_DEST}/${CARD_DIR}/acp3x-es83xx.conf"
cp "${HERE}/ucm/${CARD_DIR}/HiFi.conf" "${UCM_DEST}/${CARD_DIR}/HiFi.conf"
chmod 0644 "${UCM_DEST}/${CARD_DIR}/acp3x-es83xx.conf" "${UCM_DEST}/${CARD_DIR}/HiFi.conf"

log "Comprobando que ALSA importa el perfil propio"
if ALSA_CONFIG_UCM2="${UCM_DEST}" alsaucm -c hw:1 list _verbs >/dev/null 2>&1; then
  log "  perfil OK"
else
  warn "  alsaucm no validó (puede no ser hw:1); sigo igualmente"
fi

# ------------------------------------------------- ganancia fija (0 dB) script
log "Instalando script que fija la cadena de ganancia a 0 dB"
mkdir -p "$(dirname "${BIN}")"
cat > "${BIN}" <<'SCRIPT'
#!/usr/bin/env bash
# Fija la cadena de audio del ES8336 a 0 dB (HUAWEI BOM-WXX9).
# El BootSequence del UCM no se aplica de forma fiable con WirePlumber, así
# que la ganancia se fuerza aquí al iniciar la sesión.
CARD="acp3xes83xx"
for _ in $(seq 1 50); do
    amixer -c "$CARD" sget DAC >/dev/null 2>&1 && break
    sleep 0.2
done
set_() { amixer -c "$CARD" "$@" >/dev/null 2>&1 || true; }
# Muxes de la ruta de salida
set_ sset "Left Headphone Mixer Left DAC" on
set_ sset "Right Headphone Mixer Right DAC" on
# Cadena analógica a escala completa
set_ sset "DAC" 100%
set_ sset "Headphone Mixer" 100%
set_ sset "Headphone" 100%
# Muxes / captura
set_ cset name='DAC Source Mux' 0
set_ cset name='Digital Mic Mux' 0
set_ sset "ALC Capture Switch" off
set_ sset "ADC" 70%
SCRIPT
chmod 0755 "${BIN}"

cat > "${UNIT}" <<UNITEOF
[Unit]
Description=Huawei BOM-WXX9: cadena de audio ES8336 a 0 dB
After=wireplumber.service pipewire.service
PartOf=graphical-session.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=${BIN}

[Install]
WantedBy=graphical-session.target
UNITEOF
chmod 0644 "${UNIT}"

# ------------------------------------------------------- WirePlumber y volumen
log "Configurando WirePlumber para usar este árbol UCM"
mkdir -p "${DROP_DIR}"
cat > "${DROP_FILE}" <<EOF
[Service]
# UCM propio: cadena analógica a 0 dB y volumen gestionado en software
Environment=ALSA_CONFIG_UCM2=%h/.local/share/alsa-ucm2-hp
EOF

systemctl --user daemon-reload
systemctl --user restart wireplumber.service
sleep 2
systemctl --user is-active --quiet wireplumber.service || die "WirePlumber no arrancó"

log "Activando el servicio de ganancia"
systemctl --user enable --now huawei-hpfix-gain.service >/dev/null 2>&1 || \
  warn "No se pudo habilitar el servicio; ejecuta a mano: ${BIN}"
"${BIN}"

log "Activando sobre-amplificación en GNOME (150 %)"
gsettings set org.gnome.desktop.sound allow-volume-above-100-percent true 2>/dev/null || \
  warn "gsettings no disponible; usa 'wpctl set-volume @DEFAULT_AUDIO_SINK@ -l 1.5 1.5'"

# ------------------------------------------------------------------ resumen
rd() { amixer -c "${CARD}" sget "$1" 2>/dev/null | grep -om1 '\[[0-9]\+%\]' | tr -d '[]'; }
cat <<EOF

========================================================================
 Ajuste de volumen instalado.

 Cadena del códec (debe ser todo 100 %):
   DAC             : $(rd DAC)
   Headphone Mixer : $(rd 'Headphone Mixer')
   Headphone       : $(rd Headphone)
   ADC (captura)   : $(rd ADC)

 El volumen lo gestiona PipeWire en software; el hardware queda a 0 dB.
 Comprobar que el hardware NO se mueve al cambiar el volumen:
   wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.5
   amixer -c ${CARD} sget DAC      # debe seguir en 100 %

 Si te sigue faltando volumen (cascos de alta impedancia):
   wpctl set-volume @DEFAULT_AUDIO_SINK@ -l 1.5 1.5
   (el deslizador de GNOME llegará al 150 %)

 Revertir:
   bash ${HERE}/uninstall-volume-fix.sh
========================================================================
EOF
