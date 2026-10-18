# Enviar el parche upstream (ASoC / linux-sound)

Estado: **listo para enviar**.

| Verificación | Resultado |
|---|---|
| `checkpatch.pl --strict` | 0 errores, 0 warnings, 0 checks |
| Aplica sobre `mainline` (snapshot de hoy) | sí (es el commit base) |
| Aplica sobre `6.12.113` (stable, tu kernel) | sí, hunks con offset -2/-4 |
| Firmado con DCO | `Signed-off-by: heberdiafet <heberdiafet@gmail.com>` |

Ficheros:

* `0001-ASoC-amd-acp3x-es83xx-Fix-headphone-GPIO-polarity-on.patch` — el parche
  (`git format-patch`), sha256 `dc3552f0…fa875d`
* `commit-message.txt` — solo el mensaje, por si lo envías desde un webmail

## Qué cambia (3 líneas)

```c
#define ES83XX_HP_LOW          BIT(6)                              /* nuevo quirk */
priv->enable_hp_gpio.active_low = !!(priv->quirk & ES83XX_HP_LOW);  /* antes: false */
.driver_data = (void *)(ES83XX_ENABLE_DMIC | ES83XX_48_MHZ_MCLK | ES83XX_HP_LOW),
```

## 1. Preparar el envío

```bash
# cliente de correo de git
sudo apt install git-email

# identidad que aparecerá en el parche (revisa que sea la que quieres publicar)
git config --global user.name  "heberdiafet"
git config --global user.email "heberdiafet@gmail.com"
```

Envío con Gmail (necesita contraseña de aplicación, no la normal):

```bash
git config --global sendemail.smtpserver smtp.gmail.com
git config --global sendemail.smtpserverport 587
git config --global sendemail.smtpencryption tls
git config --global sendemail.smtpuser "heberdiafet@gmail.com"
```

> Si el envío directo con Gmail te da problemas (DMARC/spam), suscríbete antes a
> la lista y/o publica desde un alias; la lista acepta correo de Gmail pero el
> parche debe ser **texto plano**.

## 2. Comprobar que aplica en el mainline de verdad

```bash
git clone --depth=1 https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git
cd linux
git am /ruta/a/0001-ASoC-amd-acp3x-es83xx-Fix-headphone-GPIO-polarity-on.patch
git log -1 --stat          # debe mostrar el commit con 3 inserciones / 2 borrados
```

## 3. Enviar

```bash
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

Destinatarios según `MAINTAINERS`:

* **AMD ASoC DRIVERS** — Vijendar Mukunda (M), Venkata Prasad Potturu (R),
  lista `linux-sound@vger.kernel.org`
* **ASoC core** — Liam Girdwood y Mark Brown (M), misma lista
* Marian Postevca es el autor del driver (útil para revisión)

`alsa-devel@alsa-project.org` ya no aparece en `MAINTAINERS`; la lista vigente es
`linux-sound@vger.kernel.org` (si quieres, añádela como `--cc` extra, no molesta).

## 4. Seguimiento

* Archivo: <https://lore.kernel.org/linux-sound/>
* Patchwork: <https://patchwork.kernel.org/project/alsa-soc/>
* Mark Brown suele responder en días. Es normal que pidan cambios de estilo o
  que el quirk se llame de otra forma; se responde con una **v2**:

```bash
git commit --amend            # aplica los cambios pedidos
git format-patch -v2 -1 -o out/
git send-email ... out/0001-*.patch   # mismo comando, asunto [PATCH v2]
```

* Si pasadas ~2 semanas no hay respuesta: reenvía el mismo parche con
  `--subject-prefix="PATCH RESEND"` (no es descortés, es lo habitual).
* Si se acepta: entra en `linux-next`, luego en el *merge window* y por último
  en el kernel estable. Mientras tanto tu DKMS sigue funcionando sin tocar nada.

## 5. Opciones que puedes añadir

* `Cc: stable@vger.kernel.org` — si quieres pedir backport a 6.12.y (tu kernel).
  Muchos mantenedores lo prefieren decidir ellos; puedes añadirlo en la v1 o
  esperar a que se acepte y pedirlo después.
* `Tested-by:` con tu nombre si quieres reforzar la evidencia (ya está el
  párrafo de pruebas en el mensaje).

## Nota

El envío no lo puedo hacer yo: requiere tus credenciales de correo. Todo lo
demás (commit, mensaje, validaciones, destinatarios y comandos) queda listo en
esta carpeta.
