# Publicar este repositorio en GitHub

Nombre sugerido: **`huawei-matebook-bom-wxx9-audio`**
Descripción: `Audio fixes for HUAWEI MateBook 14/15 AMD (BOM-WXX9): active-low headphone GPIO (DKMS) + volume curve. Upstream patch included.`

Topics sugeridos: `linux`, `huawei`, `matebook`, `es8336`, `acp3x`, `dkms`, `audio`, `debian`, `alsa`

## 1. Crear el repo y hacer push

Con la interfaz web: crea un repo **vacío** (sin README, sin licencia) y luego:

```bash
cd ~/Documentos/deepseek-harness/default-workspace/huawei-audio-hpfix
git push -u origin main        # el remote 'origin' ya está configurado (HTTPS)
```

Si eliges otro nombre de repo o usuario:

```bash
git remote set-url origin https://github.com/<usuario>/<repo>.git
git push -u origin main
```

Si prefieres SSH (hace falta una clave en GitHub):

```bash
git remote set-url origin git@github.com:heberdiafet/huawei-matebook-bom-wxx9-audio.git
git push -u origin main
```

Con HTTPS te pedirá usuario + **token** (no la contraseña):

```bash
# crear token en https://github.com/settings/tokens (scope: repo)
```

Si prefieres `gh` (hay que instalarlo: `sudo apt install gh`):

```bash
gh auth login
gh repo create huawei-matebook-bom-wxx9-audio --public \
  --description "Audio fixes for HUAWEI MateBook 14/15 AMD (BOM-WXX9)" \
  --source . --remote origin --push
```

## 2. Verificar antes de publicar

```bash
cd ~/Documentos/deepseek-harness/default-workspace/huawei-audio-hpfix
git log --oneline
git status                 # debe estar limpio
git ls-files | head -30    # comprobar que no se cuela basura de compilación
du -sh .git                # ~1 MB
```

El `.gitignore` ya excluye artefactos de kbuild (`*.o`, `*.ko`, `.tmp_versions/`…)
pero deja pasar el módulo precompilado de `prebuilt/`.

## 3. Después de publicar (opcional pero recomendado)

Añadir el enlace del repo al commit que se envía al kernel, para que los
revisores vean la evidencia y el paquete DKMS. Hay que regenerar el parche
porque cambia el mensaje:

```bash
# 1) en el árbol mainline de prueba (ver upstream/SUBMITTING.md, paso 2)
cd linux
git am /ruta/huawei-audio-hpfix/upstream/0001-*.patch
git commit --amend        # añade una línea más, sin borrar la existente:
                          #   Link: https://github.com/heberdiafet/huawei-matebook-bom-wxx9-audio
git format-patch -1 -o ../out
```

O edita `upstream/commit-message.txt`, vuelve a generar el commit con
`git commit --amend -F` y `git format-patch -1`.

Luego envía con `git send-email` como explica [`SUBMITTING.md`](SUBMITTING.md).

## 4. Conectar GitHub y el kernel

* El kernel **no acepta PRs**; GitHub aquí sirve como escaparate y como
  evidencia enlazable (`Link:` en el mensaje del commit).
* Con el repo publicado puedes:
  - comentar en el issue #39 de `codepayne/linux-sound-huawei`
    (texto listo en [`community/codepayne-issue39.md`](community/codepayne-issue39.md));
  - abrir un issue/PR en `Xellanox/Huawei-Matebook-14-Audio`
    (texto listo en [`community/xellanox-repo.md`](community/xellanox-repo.md)).
    Recuerda cambiar `<tu-usuario>` por tu usuario real en esos textos.
* Cuando el parche se acepte en mainline, se puede crear una release con el
  `.ko` precompilado y cerrar con enlace al commit del kernel.
