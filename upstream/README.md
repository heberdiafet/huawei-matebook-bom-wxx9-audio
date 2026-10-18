# Parche upstream (disponible para la comunidad)

Este directorio contiene el arreglo del jack de auriculares como parche de
kernel, listo para que lo use quien quiera.

**No lo estamos enviando a la lista del kernel.** Queda publicado aquí para que
la comunidad lo revise, lo pruebe o lo envíe si le interesa; este repo no hace
seguimiento de ese envío.

## Contenido

| Fichero | Qué es |
|---|---|
| `0001-ASoC-amd-acp3x-es83xx-Fix-headphone-GPIO-polarity-on.patch` | commit contra `mainline` (`git format-patch`), con `Fixes:`, dos `Link:` y `Signed-off-by` |
| `commit-message.txt` | el mismo mensaje en texto plano, por si se envía desde un webmail |
| `community/` | comentarios publicados en los repos de la comunidad sobre este bug |

## Qué cambia (3 líneas)

```c
#define ES83XX_HP_LOW          BIT(6)                              /* nuevo quirk */
priv->enable_hp_gpio.active_low = !!(priv->quirk & ES83XX_HP_LOW);  /* antes: false */
.driver_data = (void *)(ES83XX_ENABLE_DMIC | ES83XX_48_MHZ_MCLK | ES83XX_HP_LOW),
```

## Estado / validación

| Verificación | Resultado |
|---|---|
| `checkpatch.pl --strict` (con `spelling.txt` y `const_structs`) | 0 errores, 0 warnings, 0 checks |
| `git am` sobre `mainline` (snapshot al prepararlo) | OK |
| `patch -p1` sobre `6.12.113` (stable) | OK (hunks con offset −2/−4) |
| Probado en hardware | MateBook 14 2021 (`BOM-WXX9-PCB-B2`), Debian 13, 6.12.113: `dmesg` → `headphone gpio 1 active low`, suenan los cascos y se silencian los altavoces |

## Si alguien quiere enviarlo

Destinatarios según `MAINTAINERS` (secciones *AMD ASoC DRIVERS* y *ASoC core*):

* **To:** Mark Brown `<broonie@kernel.org>`
* **Cc:** Liam Girdwood `<lgirdwood@gmail.com>`, Vijendar Mukunda
  `<Vijendar.Mukunda@amd.com>`, Venkata Prasad Potturu
  `<venkataprasad.potturu@amd.com>`, Marian Postevca `<posteuca@mutex.one>`
  (autor del driver), `linux-sound@vger.kernel.org`,
  `linux-kernel@vger.kernel.org`

```bash
sudo apt install git-email
git send-email \
  --to="Mark Brown <broonie@kernel.org>" \
  --cc="Liam Girdwood <lgirdwood@gmail.com>" \
  --cc="Vijendar Mukunda <Vijendar.Mukunda@amd.com>" \
  --cc="Venkata Prasad Potturu <venkataprasad.potturu@amd.com>" \
  --cc="Marian Postevca <posteuca@mutex.one>" \
  --cc="linux-sound@vger.kernel.org" \
  --cc="linux-kernel@vger.kernel.org" \
  0001-ASoC-amd-acp3x-es83xx-Fix-headphone-GPIO-polarity-on.patch
```

Notas para quien lo envíe:

* El parche ya lleva `From:` y `Signed-off-by` del autor original. Si lo envía
  otra persona, debe **mantener** ese `From:` y **añadir su propio**
  `Signed-off-by` (Developer's Certificate of Origin); no se debe borrar.
* Seguimiento: <https://lore.kernel.org/linux-sound/> y
  <https://patchwork.kernel.org/project/alsa-soc/>.
* Si piden cambios, se responde con una v2 (`git format-patch -v2`).

## Enlaces

* Bug reportado originalmente: <https://github.com/codepayne/linux-sound-huawei/issues/39>
* Discusión «upstreaming»: <https://github.com/Xellanox/Huawei-Matebook-14-Audio/issues/1>
