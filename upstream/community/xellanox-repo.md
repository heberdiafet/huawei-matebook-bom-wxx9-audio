# PR para `Xellanox/Huawei-Matebook-14-Audio`

Repo: <https://github.com/Xellanox/Huawei-Matebook-14-Audio>
Fichero a adjuntar: `upstream/0001-ASoC-amd-acp3x-es83xx-Fix-headphone-GPIO-polarity-on.patch`

## Título sugerido

```
Fix: apply ES83XX_HP_LOW to the existing BOM-WXX9 DMI entry (duplicate entry never matches)
```

## Cuerpo

```markdown
Hola, y gracias por el parche: la idea (`ES83XX_HP_LOW` → `active_low = true`) es
correcta y es la que hacía falta en estas placas.

Revisándolo contra mainline me encontré con un problema: el parche **añade una
segunda entrada DMI** para `BOM-WXX9` / `M1010`, pero esa entrada ya existe más
arriba en `acp3x_es83xx_dmi_table()` (la que trae `ES83XX_48_MHZ_MCLK`, añadida
en 54fcd9dd44b2 "ASoC: amd: acp: Add machine driver that enables sound for
systems with a ES8336 codec").

Como el driver usa `dmi_first_match()`, gana la **primera** coincidencia: la
entrada original (sin `ES83XX_HP_LOW`). Es decir, el bit del quirk nunca llega a
`priv->quirk` y la polaridad no cambia.

La corrección es modificar el `driver_data` de la entrada existente en lugar de
añadir otra. Adjunto el parche corregido (`0001-ASoC-amd-acp3x-es83xx-Fix-
headphone-GPIO-polarity-on.patch`):

- añade `#define ES83XX_HP_LOW BIT(6)`;
- en `acp3x_es83xx_configure_gpios()`:
  `priv->enable_hp_gpio.active_low = !!(priv->quirk & ES83XX_HP_LOW);`
- en la entrada DMI existente de `BOM-WXX9`/`M1010`:
  `ES83XX_ENABLE_DMIC | ES83XX_48_MHZ_MCLK | ES83XX_HP_LOW`.

Probado en un MateBook 14 2021 (`BOM-WXX9-PCB-B2`, kernel 6.12.113 de Debian 13):
`dmesg` muestra `speaker gpio 0 active high, headphone gpio 1 active low` y el
jack suena; además los altavoces se silencian al conectar los cascos.

También tengo preparado el envío a la lista del kernel
(`linux-sound@vger.kernel.org`, asunto
`ASoC: amd: acp3x-es83xx: Fix headphone GPIO polarity on BOM-WXX9`)
para que deje de hacer falta el parche fuera del árbol.

Si te parece bien, puedo mandarlo como PR con el fichero del parche actualizado
(y ajustar el README). ¿Lo prefieres así?
```

## Notas

* Si prefieres no tocar su repo, este texto vale igual como **issue**.
* Adjunta el `.patch`; no hace falta pegar el diff en el cuerpo.
* Repo con la corrección y el módulo DKMS: https://github.com/heberdiafet/huawei-matebook-bom-wxx9-audio
* Nuestro parche aplica también sobre 6.19/6.20 (está hecho contra mainline),
  así que le sirve igual.
