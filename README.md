# Bluefish: cliente no oficial para Bluesky en Sailfish OS

Cliente **no oficial** de [Bluesky](https://bsky.app) (AT Protocol) para teléfonos con
[Sailfish OS](https://sailfishos.org).

> [!IMPORTANT]
> Proyecto personal sin ninguna vinculación con Bluesky Social PBC. Sin ánimo de lucro, sin
> publicidad y sin recogida de datos. Desarrollado mediante [Claude Code](https://claude.com/claude-code).
> Se ofrece sin garantía de ningún tipo.
> «Bluesky» es una marca de Bluesky Social PBC; aquí solo se usa para indicar con qué servicio
> funciona la app.

**Estado: versión 0.1, en desarrollo.** Probada en un Xperia con Sailfish OS 5.2.

## Funciones

- Inicio de sesión con **contraseña de aplicación**, en bsky.social o en un servidor (PDS) propio.
  La sesión se renueva sola y se guarda solo en el teléfono; la contraseña no se guarda.
- **Timeline** «Siguiendo», con carga continua al desplazarse.
- **Feeds y listas**: Discover, los feeds guardados en tu cuenta y tus listas.
- **Hilos** completos: posts anteriores y respuestas anidadas.
- **Perfiles**: cabecera, biografía, contadores, seguir y dejar de seguir, bloquear, silenciar y
  posts del usuario.
- **Búsqueda** de personas, posts y hashtags, y tendencias del momento. Las menciones y los
  hashtags de los posts se pueden pulsar.
- **Mensajes privados**: conversaciones, solicitudes, enviar y borrar mensajes. La contraseña de
  aplicación necesita tener activado el acceso a mensajes directos.
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

- La sesión (tokens, no la contraseña) se guarda en `~/.local/share/org.jabato/bluefish`, que
  Sailjail oculta al resto de apps, con permisos solo para el propietario.
- Todo va cifrado: los servidores propios tienen que usar `https://`, y las peticiones con tu
  sesión no siguen redirecciones, para que el token no pueda acabar en otro servidor.
- El texto de los posts se escapa antes de mostrarse y solo se crean enlaces `http`/`https`. Los
  nombres, títulos y mensajes de error que vienen de fuera se muestran como texto plano, sin HTML.
- Las notificaciones del sistema llevan el texto sin marcado. La de un mensaje privado no muestra
  su contenido en el aviso emergente, que puede salir con el teléfono bloqueado; solo en Eventos.
- El servicio D-Bus de la app solo acepta abrir un post, un perfil, una conversación o las
  notificaciones, y descarta cualquier otra cosa.
- Permisos de Sailjail: solo `Internet`. La app no accede a tus fotos, vídeos ni otros archivos.
- La app solo se conecta a tu servidor de Bluesky (PDS), a `public.api.bsky.app` y
  `plc.directory` para localizar tu cuenta al iniciar sesión, y a `cdn.bsky.app` para las imágenes.

## Licencia

[GNU GPL v3](LICENSE). El icono es un diseño propio de este proyecto, bajo la misma licencia.
