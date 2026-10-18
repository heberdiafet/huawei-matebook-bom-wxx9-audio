# Comentario para el issue #39 de `codepayne/linux-sound-huawei`

Issue: <https://github.com/codepayne/linux-sound-huawei/issues/39>
Título: *No sound on headphones BOM-WXX9-PCB-B2*

**Publicado:** <https://github.com/codepayne/linux-sound-huawei/issues/39#issuecomment-6246424466>

## Comentario

```markdown
Confirmo el diagnóstico de @Xellanox y aporto una prueba más, sobre
**BOM-WXX9-PCB-B2** con el kernel **6.12.113 de Debian 13**:

La causa es la polaridad del GPIO de habilitación de auriculares en
`sound/soc/amd/acp/acp3x-es83xx/acp3x-es83xx.c`:

```c
priv->enable_hp_gpio.active_low = false;   /* mainline / 6.12.y */
```

En estas placas la línea es **active-low**: cuando el usuario conecta los cascos,
`acp3x_es83xx_headphone_power_event()` marca `headphone_on = true` y el driver
pone la línea en **nivel alto**, que el hardware interpreta como *mute*. Resultado:
jack detectado, PipeWire reproduce, pero no se oye nada. Insertando el conector a
medias (sin que se cierre el interruptor de presencia) sí suena, justo porque el
GPIO aún no se ha conmutado.

Lo he resuelto con un paquete DKMS que añade un quirk (`ES83XX_HP_LOW`) y lo
activa solo para el DMI `HUAWEI/BOM-WXX9/M1010`:

- repo: https://github.com/heberdiafet/huawei-matebook-bom-wxx9-audio
- parche de kernel incluido y listo para upstream

Evidencia tras el fix:

```
$ sudo dmesg | grep -i "headphone gpio"
[    6.636606] es8316 i2c-ESSX8336:00: speaker gpio 0 active high, headphone gpio 1 active low
```

Y efecto: suena por el jack y los altavoces se silencian al conectar los cascos
(antes sonaban los dos a la vez si se forzaba el altavoz en el mezclador).

Un aviso para quien pruebe el parche de @Xellanox
(https://github.com/Xellanox/Huawei-Matebook-14-Audio): añade una **segunda**
entrada DMI para `BOM-WXX9/M1010`, pero esa entrada ya existe antes en
`acp3x_es83xx_dmi_table()`. Como el driver usa `dmi_first_match()`, la entrada
duplicada nunca se usa y el quirk no surte efecto; hay que modificar el
`driver_data` de la entrada existente (lo tengo hecho en el parche del repo).

El parche corregido queda en el repo por si alguien quiere enviarlo a
`linux-sound@vger.kernel.org` (asunto sugerido:
`ASoC: amd: acp3x-es83xx: Fix headphone GPIO polarity on BOM-WXX9`); ya está
validado con checkpatch y aplica limpio en mainline y en 6.12.y.
Mientras tanto, el DKMS cubre 6.12.y.
```

## Notas

* La URL ya apunta a `heberdiafet/huawei-matebook-bom-wxx9-audio`: publícalo antes de comentar, o ajústala si cambias el nombre.
* Texto = el comentario publicado (editado el 18/10 para quitar la promesa de
  envío a la lista: el parche queda disponible para quien quiera enviarlo).
* Este mismo texto sirve para el issue #28 («No sound on 6.7rc5…») y para
  cualquier otro reporte de `BOM-WXX9` con auriculares mudos.
