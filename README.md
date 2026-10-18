# Arreglo del jack de audífonos — HUAWEI MateBook 14/15 AMD (BOM-WXX9)

Parche del controlador del kernel `snd-acp-legacy-mach` (driver de máquina
`acp3x-es83xx`) que corrige que **los audífonos se detecten pero no suene nada**
en los Huawei MateBook con códec **ES8336** y APU AMD (ACP3x).

* Equipo de referencia: `HUAWEI / BOM-WXX9 / M1010` (placa `BOM-WXX9-PCB-B2`)
* Kernel compilado y verificado: `6.12.113+deb13-amd64` (Debian 13)
* Códec: `ESSX8336` (`snd_soc_es8316`), tarjeta ALSA `acp3xes83xx`

---

## Causa del problema

1. El conector de 3.5 mm tiene un interruptor mecánico; al insertar los
   audífonos el sistema lo detecta, PipeWire conmuta el *sink* y el audio se
   reproduce… pero no se oye nada.
2. La salida de audio del ES8336 hacia el jack está habilitada por un pin GPIO
   (`headphone-enable-gpios`).
3. En estas placas Huawei ese pin está **activo en bajo (active-low)**: hay que
   llevarlo a **0 V** para *desmutear* los audífonos.
4. El driver del kernel lo configura fijo como **activo en alto**
   (`priv->enable_hp_gpio.active_low = false;`), así que al conectar los
   audífonos el kernel pone el pin en 3,3 V → el hardware **mutea** el jack.
   Por eso al insertar el conector *a medias* (sin que se detecte la inserción)
   el audio sí se oye.

## Qué hace este parche

Añade un *quirk* `ES83XX_HP_LOW` al driver de máquina y lo activa solo para el
DMI `HUAWEI / BOM-WXX9 / M1010`, de forma que:

```c
if (priv->quirk & ES83XX_HP_LOW)
        priv->enable_hp_gpio.active_low = true;   /* GPIO a 0 V = sin mute */
else
        priv->enable_hp_gpio.active_low = false;
```

Efectos esperados (reportados y coherentes con el diseño):

* suena por los audífonos al conectarlos;
* los altavoces se silencian correctamente al insertar el jack;
* desaparece el «pop» de arranque.

## Contenido

```
huawei-audio-hpfix/
├── dkms.conf                  # definición del paquete DKMS
├── Makefile                   # build out-of-tree del módulo
├── acp-legacy-mach.c          # fuente del kernel 6.12.113 (módulo completo)
├── acp-mach.h                 # cabecera privada requerida
├── acp3x-es83xx/
│   ├── acp3x-es83xx.c         # fuente original (el parche se aplica aquí)
│   └── acp3x-es83xx.h
├── patches/
│   └── 0001-hp-active-low.patch
├── prebuilt/
│   └── snd-acp-legacy-mach-6.12.113+deb13-amd64.ko   # ya compilado
├── reference/
│   └── acp3x-es83xx.c.patched                        # fuente con el parche aplicado
├── volume/                    # ajuste de volumen (opcional, sin root)
│   ├── ucm/AMD/acp3x-es83xx/{acp3x-es83xx.conf,HiFi.conf}
│   ├── install-volume-fix.sh
│   └── uninstall-volume-fix.sh
├── upstream/                  # parche listo para enviar al kernel
│   ├── 0001-ASoC-amd-acp3x-es83xx-Fix-headphone-GPIO-polarity-on.patch
│   ├── commit-message.txt
│   ├── README.md              # estado del parche y destinatarios (para quien lo envíe)
│   └── community/             # textos para issues/PRs de la comunidad
│       ├── codepayne-issue39.md
│       └── xellanox-repo.md
├── LICENSE                    # GPL-2.0 (fuentes del kernel)
├── .gitignore
├── install.sh
└── uninstall.sh
```

## Instalación

Requiere conexión a red la primera vez (instala `dkms`, `build-essential`,
`linux-headers-$(uname -r)` y `pahole`, porque el kernel usa
`CONFIG_DEBUG_INFO_BTF_MODULES`).

```bash
cd huawei-audio-hpfix
sudo bash install.sh
sudo reboot
```

## Verificación

```bash
# 1) El driver debe reportar el GPIO como activo en bajo
sudo dmesg | grep -i "headphone gpio"
#    esperado:  ... speaker gpio 0 active high, headphone gpio 1 active low

# 2) El módulo cargado debe ser el de DKMS
modinfo -n snd_acp_legacy_mach
#    esperado: /lib/modules/$(uname -r)/updates/dkms/snd-acp-legacy-mach.ko.xz
dkms status -m huawei-hpfix
#    esperado: huawei-hpfix/1.0.0, <kernel>: installed

# 3) Prueba de sonido directa a la tarjeta
aplay -D plughw:1,0 /usr/share/sounds/alsa/Front_Center.wav
```

> `dmesg` necesita `sudo` (el kernel restringe el buffer a root, por eso
> `dmesg: fallo al leer el «buffer» del núcleo: Operación no permitida`).

## Ajuste de volumen (opcional, sin root)

El jack ya suena, pero el control de volumen de esta tarjeta tiene dos defectos
medidos en el equipo:

1. **WirePlumber movía dos controles a la vez** (`DAC` como *master* y
   `Headphone Mixer` como volumen del camino), con lo que la curva no era
   monótona y el atenuador analógico del HPMIX se **saturaba al ~65 %**
   (de 0 % a 65 % de volumen el sonido ya no bajaba más).
2. A 100 % sí se alcanza la **escala completa** del códec (DAC 0 dB,
   HPMIX 0 dB, etapa HP 0 dB) — es decir, el máximo volumen por hardware ya
   estaba disponible; no hay ganancia extra que activar.

El ajuste deja el hardware **siempre a 0 dB** y el volumen lo gestiona PipeWire
en software: curva suave de 0 a 100 %, más la posibilidad de **sobre-amplificar
hasta el 150 %** (≈ +3,5 dB) para cascos de alta impedancia.

```bash
cd huawei-audio-hpfix/volume
bash install-volume-fix.sh          # sin sudo
# y para revertir:
bash uninstall-volume-fix.sh
```

Qué instala (todo en tu `$HOME`):

| Elemento | Ruta |
|---|---|
| Árbol UCM propio (symlinks + perfil de la tarjeta) | `~/.local/share/alsa-ucm2-hp` |
| `ALSA_CONFIG_UCM2` para WirePlumber | `~/.config/systemd/user/wireplumber.service.d/50-ucm-hp.conf` |
| Fuerza la ganancia a 0 dB al iniciar sesión | `~/.config/systemd/user/huawei-hpfix-gain.service` |
| Script de ganancia | `~/.local/bin/huawei-hpfix-gain.sh` |
| Sobre-amplificación GNOME | `gsettings … allow-volume-above-100-percent true` |

Verificación:

```bash
# el hardware debe quedarse a 100 % aunque bajes el volumen
wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.3
amixer -c acp3xes83xx sget DAC | grep -m1 '\['
# y el volumen controla el sonido de forma suave de 0 a 100 %:
wpctl set-volume @DEFAULT_AUDIO_SINK@ 1.0
```

> Por qué se fuerza la ganancia con un servicio: el `BootSequence` del UCM **no
> se aplica** de forma fiable cuando WirePlumber abre la tarjeta (comprobado
> reiniciando con estado limpio), así que los valores iniciales podían quedar
> atenuados (-12 dB o menos) sin que nada los corrigiera.

> Compromiso: al usar volumen en software, a volúmenes muy bajos se atenúa en
> digital (más resolución perdida que con atenuador analógico). A cambio la
> curva es correcta, no se satura y siempre se llega al máximo real.

## Desinstalación

```bash
sudo bash uninstall.sh
sudo reboot
```

## Instalación manual (sin DKMS, sin red)

Si no quieres instalar `dkms` se puede colocar el módulo ya compilado. Solo vale
para **exactamente** el mismo kernel (verifica antes con `uname -r`):

```bash
uname -r        # debe ser 6.12.113+deb13-amd64
sudo install -Dm644 prebuilt/snd-acp-legacy-mach-6.12.113+deb13-amd64.ko \
     /lib/modules/$(uname -r)/updates/snd-acp-legacy-mach.ko
sudo depmod -a
sudo reboot
```

Para revertirlo: `sudo rm /lib/modules/$(uname -r)/updates/snd-acp-legacy-mach.ko && sudo depmod -a`

## Solución de problemas

**«dmesg: fallo al leer el buffer del núcleo: Operación no permitida»**
→ usa `sudo dmesg`.

**`dkms status` dice solo `added` y el módulo sigue saliendo de
`kernel/sound/soc/amd/acp/...`**
→ El build de DKMS falló. `dkms.conf` debe declarar el parche **sin** el prefijo
`patches/` (DKMS 3.x ya lo añade):

```ini
PATCH[0]="0001-hp-active-low.patch"      # correcto
# PATCH[0]="patches/0001-hp-active-low.patch"   # incorrecto -> dkms aborta
```

Vuelve a ejecutar `sudo bash install.sh` (el script limpia el registro anterior
antes de recompilar). Logs útiles:

```bash
sudo cat /var/lib/dkms/huawei-hpfix/1.0.0/<kernel>/*/log/make.log
sudo dkms status
ls -l /lib/modules/$(uname -r)/updates/dkms/
```

## Parche upstream (para quien quiera usarlo)

En [`upstream/`](upstream/) queda el parche del arreglo, validado y listo, pero
**no lo enviamos a la lista del kernel**: se publica para que la comunidad lo
revise, lo pruebe o lo envíe si le interesa. Este repo no hace seguimiento de
ese envío.

* commit contra `mainline`, con mensaje, `Fixes:` y `Signed-off-by`;
* `checkpatch.pl --strict`: **0 errores, 0 warnings, 0 checks**;
* aplica tanto en `mainline` como en `6.12.113` (offset −2/−4).

Si alguien quiere enviarlo, los destinatarios según `MAINTAINERS` (*AMD ASoC
DRIVERS* + *ASoC core*) y el comando `git send-email` están en
[`upstream/README.md`](upstream/README.md). Respetando el DCO: se mantiene el
`From:` original y se añade el `Signed-off-by` de quien envía.

## Publicado en GitHub

Repo público: **<https://github.com/heberdiafet/huawei-matebook-bom-wxx9-audio>**

* Comentario en el issue original del bug:
  [codepayne/linux-sound-huawei#39](https://github.com/codepayne/linux-sound-huawei/issues/39#issuecomment-6246424466)
* Comentario en el issue «upstreaming» de la comunidad:
  [Xellanox/Huawei-Matebook-14-Audio#1](https://github.com/Xellanox/Huawei-Matebook-14-Audio/issues/1#issuecomment-6246425857)

El kernel **no acepta PRs** en GitHub: el repo sirve como escaparate y como
evidencia enlazable (`Link:` en el parche), no como vía de integración.

## Notas técnicas

* El módulo se compila contra las cabeceras del kernel en ejecución con
  `vermagic` idéntico al original:
  `6.12.113+deb13-amd64 SMP preempt mod_unload modversions`.
* Solo se sustituye `snd-acp-legacy-mach`; el resto de drivers de audio siguen
  siendo los de la distribución.
* Con `AUTOINSTALL="yes"`, DKMS recompila el módulo automáticamente en cada
  actualización de kernel.
* Secure Boot está desactivado en este equipo, por lo que un módulo sin firmar
  se carga sin problema. Si algún día activas Secure Boot tendrás que firmar el
  módulo (MOK) o desinstalar el parche.
* El parche afecta únicamente al DMI `BOM-WXX9/M1010`; otros modelos Huawei con
  ES8336 no cambian de comportamiento.
* Situación en upstream: el quirk **no** está en el kernel principal. En
  [`upstream/`](upstream/) queda el parche validado para quien quiera usarlo o
  enviarlo; el problema original está descrito en
  <https://github.com/codepayne/linux-sound-huawei/issues/39>.
