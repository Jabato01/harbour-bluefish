# Celeste: cliente de Bluesky para Sailfish OS

Cliente **no oficial** de [Bluesky](https://bsky.app) (AT Protocol) para teléfonos con
[Sailfish OS](https://sailfishos.org). Nombre provisional.

> [!IMPORTANT]
> Proyecto personal sin ninguna vinculación con Bluesky Social PBC. Sin ánimo de lucro, sin
> publicidad y sin recogida de datos. Desarrollado mediante [Claude Code](https://claude.com/claude-code).
> Se ofrece sin garantía de ningún tipo.

**Estado: versión 0.1, en desarrollo.** Aún no se ha probado en un teléfono.

## Funciones de la 0.1

- Inicio de sesión con **contraseña de aplicación**, en bsky.social o en un servidor (PDS) propio.
  La sesión se renueva sola y se guarda solo en el teléfono; la contraseña no se guarda.
- **Timeline** «Siguiendo», con carga continua al desplazarse.
- **Hilos** completos: posts anteriores y respuestas anidadas.
- **Perfiles**: cabecera, biografía, contadores, seguir y dejar de seguir, y posts del usuario.
- **Búsqueda** de personas y de posts; los hashtags abren su búsqueda.
- **Publicar, responder y citar**, con detección de enlaces, menciones y hashtags.
- **Me gusta y republicar**.
- Imágenes con texto alternativo y visor a pantalla completa, tarjetas de enlace, posts citados y
  vista previa de vídeos (por ahora se abren en el navegador).
- Moderación básica: oculta lo marcado como `!hide` y difumina las imágenes con etiquetas para
  adultos o violentas hasta que las toques.

## Compilar

Se necesita Docker. El script usa la imagen `coderus/sailfishos-platform-sdk:5.1.0.11` y compila
cada arquitectura en su propia carpeta:

```bash
./build.sh aarch64 armv7hl
```

Los paquetes quedan en `RPMS/`. Los tests (funciones de C++ y compilación de todos los QML) se
ejecutan con:

```bash
tests/run.sh
```

## Estructura

```
src/bsky.cpp              Sesión, peticiones XRPC, facets (offsets UTF-8) y texto enriquecido
qml/js/feed.js            Conversión de las respuestas de la API a lo que muestran las listas
qml/pages/                Pantallas
qml/components/PostItem   Un post en una lista
tests/                    Tests de C++ y comprobación de los QML
```

## Seguridad y privacidad

- La sesión (tokens, no la contraseña) se guarda en `~/.local/share/org.jabato/celeste`, que
  Sailjail oculta al resto de apps, con permisos solo para el propietario.
- El texto de los posts se escapa antes de mostrarse. Solo se crean enlaces `http`/`https`.
- La app solo se conecta a tu servidor de Bluesky (PDS), a `public.api.bsky.app` y
  `plc.directory` para localizar tu cuenta al iniciar sesión, y a `cdn.bsky.app` para las imágenes.

## Licencia

[GNU GPL v3](LICENSE). El icono es un diseño propio de este proyecto, bajo la misma licencia.
