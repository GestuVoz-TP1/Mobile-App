# GestuVoz — Aplicación móvil

**Sistema aumentativo y alternativo de comunicación (SAAC) basado en machine
learning para apoyar la comunicación no verbal de niños con TEA en Lima
Metropolitana.**

GestuVoz permite que un niño con TEA exprese lo que necesita de dos formas:
tocando **pictogramas** o haciendo **gestos con las manos** frente a la cámara.
En ambos casos la app muestra el pictograma y **dice el mensaje en voz alta**.
El padre, madre o tutor configura los perfiles, personaliza los pictogramas y
la voz, gestiona el consentimiento y consulta el historial de uso.

Aplicación Android desarrollada con Flutter. Esta rama (`deploy`) está
conectada al backend Django y a Firebase; la rama `develop` contiene el
prototipo sin conexión.

La comunicación del niño funciona sin internet: todo se guarda primero en el
dispositivo (SQLite) y se sincroniza con el backend cuando hay conexión.

---

## Tabla de contenidos

- [Funcionalidades](#funcionalidades)
- [Cómo se usa](#cómo-se-usa)
- [Reconocimiento de gestos](#reconocimiento-de-gestos)
- [Arquitectura](#arquitectura)
- [Base de datos](#base-de-datos)
- [Conexión con el backend](#conexión-con-el-backend)
- [Requisitos](#requisitos)
- [Instalación y ejecución](#instalación-y-ejecución)
- [Pruebas](#pruebas)
- [Alcance de esta versión](#alcance-de-esta-versión)

---

## Funcionalidades

Organizadas según las épicas del Product Backlog.

### E1 · Comunicación mediante gestos

| HU | Funcionalidad |
|----|---------------|
| HU001 | Reconocer los gestos del niño con la cámara; si no se reconoce, no se comunica un mensaje incorrecto |
| HU002 | Preparar la modalidad: activar gestos y otorgar el permiso de cámara (indica qué corregir si falla) |
| HU003 | Consultar los gestos disponibles con su referencia visual |
| HU004 | Activar o desactivar la comunicación por gestos para cada perfil |
| HU005 | Pasar al tablero de pictogramas cuando un gesto no se reconoce |
| HU011 | Volver a intentar un gesto conservando la configuración del perfil |

### E2 · Comunicación mediante pictogramas y voz

| HU | Funcionalidad |
|----|---------------|
| HU006 | Mostrar el pictograma del gesto reconocido y decir el mensaje automáticamente |
| HU007 | Tablero con los pictogramas del perfil (aviso si aún no hay ninguno) |
| HU008 | Seleccionar un pictograma y verlo en "Mi mensaje" |
| HU009 | Escuchar el mensaje en español (aviso si la voz no está disponible) |
| HU010 | Explorar pictogramas por categorías |

### E3 · Personalización de la comunicación

| HU | Funcionalidad |
|----|---------------|
| HU012 | Crear pictogramas propios con imagen (galería o cámara) y mensaje |
| HU013 | Editar la imagen o el mensaje de un pictograma propio |
| HU014 | Cambiar la categoría de un pictograma |
| HU015 | Elegir qué pictogramas aparecen en el tablero y en qué orden |
| HU016 | Ajustar el tamaño de los pictogramas |
| HU017 | Configurar la voz: tipo, velocidad, volumen y prueba de voz |

### E4 a E6 · Perfiles, privacidad e historial

- **Cuenta y perfiles (E4):** registro e inicio de sesión con correo y
  contraseña (Firebase Authentication), recuperación de contraseña por
  correo, varios perfiles infantiles por tutor (crear, editar, cambiar y
  eliminar) y cierre de sesión.
- **Privacidad (E5):** consentimiento por perfil (otorgar, rechazar o retirar)
  e información sobre los datos tratados (Ley N.º 29733). Sin consentimiento
  vigente no se registran interacciones ni se usa la cámara; el tablero sigue
  disponible.
- **Historial (E6):** registro de cada mensaje comunicado, filtros por fecha,
  detalle de cada interacción, mensajes más usados, actividad semanal y
  exportación a CSV. El historial y los reportes los genera el backend, por
  lo que su consulta requiere conexión. Es una consulta descriptiva: no
  realiza evaluaciones clínicas.

---

## Cómo se usa

```
Bienvenida ──► Crear cuenta / Iniciar sesión
                   │
                   ▼
            Crear perfil del niño ──► Consentimiento
                   │
                   ▼
          ¿Quién usará la app ahora?
           │                     │
           ▼                     ▼
   Panel del niño          Panel del tutor
   · Inicio                · Inicio (perfil activo, actividad de hoy)
   · Hablar (tablero)      · Reportes (historial)
   · Gestos (cámara)       · Ajustes (perfiles, voz, pictogramas,
                             gestos, privacidad, cerrar sesión)
```

- **Panel del niño:** interfaz simple, con botones y pictogramas grandes,
  colores por categoría y poco texto. Para salir se pide la contraseña del
  tutor.
- **Panel del tutor:** interfaz administrativa para configurar y consultar.

---

## Reconocimiento de gestos

```
Cámara ─► secuencia de imágenes (solo en memoria)
       ─► GestureRecognitionService ─► GESTO ─► INTENCIÓN COMUNICATIVA
       ─► PICTOGRAMA ─► voz ─► registro en el historial
```

1. **Preparación:** el niño ve los gestos habilitados para su perfil, con su
   imagen e instrucciones, y pulsa **Comenzar**.
2. **Cámara:** un recuadro guía indica dónde colocar las manos ("Buscando tus
   manos…").
3. **Resultado:** se muestra el pictograma y se dice el mensaje; si no se
   reconoce, se ofrece **Intentar de nuevo** o **Usar pictogramas**.

Las imágenes de la cámara **nunca se guardan** ni salen del dispositivo.

### Modelo de reconocimiento

La app usa el modelo **MobileNet + LSTM** con **TensorFlow Lite**, en el
dispositivo (`lib/infrastructure/ml/`). Por cada fotograma de la secuencia:

1. El detector de palmas de MediaPipe (`palm_detection_lite.tflite`) ubica
   las manos.
2. Se recorta la mano (o las dos manos) y MobileNetV3
   (`gestos_fotograma.tflite`) extrae sus características.
3. Con los 16 fotogramas, el LSTM (`gestos_secuencia.tflite`) decide el
   gesto o "ninguno".

El resultado solo se acepta con una confianza de al menos 85 % y si el gesto
está habilitado en el perfil; si no, se muestra "No reconocido".

Los modelos están en `assets/models/` y se entrenan en el repositorio
[ML](https://github.com/GestuVoz-TP1/ML) con
[HaGRIDv2](https://github.com/hukenovs/hagrid) (CC BY-SA 4.0). Se
probaron con imágenes de HaGRIDv2 que no se usaron para entrenar; **falta
validarlos con videos propios y medir la latencia en el teléfono**.

`TestModeGestureRecognitionService` (el reconocedor de prueba, sin modelo)
sigue disponible para pruebas: se activa en `lib/di.dart`.

### Gestos

| Gesto | Mensaje | Lo reconoce el modelo |
|-------|---------|:---------------------:|
| Hola 👋 | Hola | Sí |
| Agua 💧 | Quiero agua | No (sin datos de entrenamiento) |
| Ayuda 🆘 | Necesito ayuda | Sí |
| Parar ✋ | Para, por favor | Sí |
| Sí 👍 | Sí | Sí |
| No 👎 | No | Sí |
| Por favor 🙏 | Por favor | Sí |
| Terminé 🙅 | Ya terminé | Sí |
| Silencio 🤫 | Quiero silencio | Sí |
| Descanso ⏸️ | Necesito un descanso | Sí |
| Abrazo 🫶 | Quiero un abrazo | Sí |

Cada gesto está asociado a una intención y a un pictograma del tablero. Sus
instrucciones se escriben desde **Ajustes → Gestos disponibles**. El
repertorio está pendiente de validación por el especialista.

---

## Arquitectura

Arquitectura por capas (Domain-Driven Design):

```
lib/
├── domain/           Entidades, reglas y puertos (sin Flutter)
├── application/      Casos de uso: auth, profile, privacy, communication,
│                     gesture, interaction, reporting, settings
├── infrastructure/   SQLite, cámara, texto a voz, reconocimiento de gestos,
│                     datos iniciales, exportación CSV, cliente del backend
│                     (remote/) y sincronización (sync/)
├── presentation/     Controladores (ChangeNotifier), pantallas, widgets y tema
├── di.dart           Composición de dependencias (único punto con
│                     implementaciones concretas)
└── main.dart
```

```
Pantalla ─► Controlador ─► Servicio de aplicación ─► Repositorio ─► SQLite
```

Ninguna pantalla accede directamente a la base de datos. La app usa Firebase
solo para iniciar sesión; los datos llegan a Cloud Firestore únicamente a
través del backend Django.

| Componente | Tecnología |
|------------|------------|
| Interfaz | Flutter (Material 3), `provider` |
| Persistencia local | SQLite (`sqflite`) |
| Cámara | `camera` |
| Voz | `flutter_tts` (español) |
| Imágenes de pictogramas | `image_picker` |
| Gráficos | `fl_chart` |
| Reconocimiento de gestos | TensorFlow Lite (integración preparada) |
| Autenticación | Firebase Authentication (`firebase_auth`) |
| Backend | API REST Django (`http`), estado de red (`connectivity_plus`) |

---

## Base de datos

SQLite, según el diagrama físico del proyecto:

| Tabla | Contenido |
|-------|-----------|
| `padre_tutor` | Cuenta del tutor (correo y contraseña con hash y sal) |
| `nino` · `perfil_nino` | Datos del niño y su perfil comunicativo |
| `categoria` · `pictograma` | Catálogo de pictogramas |
| `perfil_pictograma` | Pictogramas visibles de cada perfil y su orden |
| `gesto` · `intencion_comunicativa` | Gestos, instrucciones y su significado |
| `configuracion_voz` | Voz, velocidad y volumen de cada perfil |
| `consentimiento` | Decisión del tutor y fechas de registro o retiro |
| `interaccion` | Historial de mensajes comunicados |

Datos iniciales: 10 categorías, 127 pictogramas y 4 gestos. Un perfil nuevo
empieza con todos los pictogramas iniciales visibles.

Para la sincronización, cada registro tiene un identificador remoto (`uuid`) y
una fecha de última modificación (`actualizado_en`). Los cambios pendientes
de envío se guardan en `sync_pendiente`, y las interacciones se marcan con
`sincronizada`. En los pictogramas propios, `imagen_ref` guarda la ruta de la imagen
en Cloud Storage; si está vacía, la imagen aún no se ha subido.

---

## Conexión con el backend

- **Inicio de sesión:** Firebase Authentication. La contraseña del tutor
  también se guarda con hash en el dispositivo para poder salir del modo niño
  sin conexión.
- **Sincronización:** al iniciar sesión se descargan los perfiles y ajustes
  del tutor. Luego los cambios se envían automáticamente al recuperar la
  conexión, al registrar algo nuevo y cada dos minutos. Si dos cambios
  coinciden, se conserva el más reciente.
- **Privacidad:** sin consentimiento vigente no se envía ningún dato del
  perfil; solo la decisión de consentimiento.
- **Sin conexión:** el panel del tutor muestra cuántos cambios están
  pendientes y permite reintentar.
- **Imágenes propias:** se suben a Cloud Storage (a través del backend) al
  sincronizar, solo si el perfil tiene el consentimiento otorgado, y se
  descargan al iniciar sesión en otro teléfono. El backend acepta JPG, PNG o
  WebP de hasta 500 KB; la app ya reduce la imagen a 768 px al elegirla.

### Ejecutar con el backend local

1. Iniciar el backend ([GestuVoz-TP1/Backend](https://github.com/GestuVoz-TP1/Backend))
   escuchando en la red local:

   ```bash
   python manage.py runserver 0.0.0.0:8000
   ```

2. En el emulador de Android la app usa `http://10.0.2.2:8000/api/v1/` por
   defecto:

   ```bash
   flutter run
   ```

3. En un teléfono físico (misma red Wi-Fi), indicar la IP de la computadora y
   agregarla a `DJANGO_ALLOWED_HOSTS` en el `.env` del backend:

   ```bash
   flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000/api/v1/
   ```

Las conexiones HTTP sin cifrar solo se permiten en la compilación de
desarrollo. Para la versión de lanzamiento se usa la URL HTTPS del backend
desplegado:

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://<dominio>/api/v1/
```

La configuración de Firebase está en `android/app/google-services.json`
(paquete `pe.edu.upc.gestuvoz`).

---

## Requisitos

- Flutter 3.44 o superior (Dart 3.12)
- Android SDK; dispositivo o emulador con Android 10 o superior
- Cámara frontal para la comunicación por gestos

---

## Instalación y ejecución

```bash
git clone https://github.com/GestuVoz-TP1/Mobile-App.git
cd Mobile-App
git checkout deploy
flutter pub get
flutter run
```

Generar el APK (ver [Conexión con el backend](#conexión-con-el-backend) para
indicar la URL del servidor):

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://<dominio>/api/v1/
```

El archivo queda en `build/app/outputs/flutter-apk/app-release.apk`.

---

## Pruebas

```bash
flutter analyze
flutter test
```

- `test/persistence_test.dart`: persistencia sobre SQLite real (crear, cerrar
  y reabrir la base), validaciones de pictogramas y voz, consentimiento,
  eliminación de perfiles y migración de versiones de la base.
- `test/widget_test.dart`: reglas de dominio, reconocimiento de gestos,
  resúmenes del historial y componentes de la interfaz.
- `test/hand_detection_test.dart`: lectura de los fotogramas de la cámara
  (giro y color) y decodificación del detector de palmas.
- `test/sync_test.dart`: sincronización con un backend simulado (sin
  conexión, consentimiento, orden y formato de envío, eliminación, descarga
  en un teléfono nuevo) y consulta del historial y los reportes.

---

## Alcance de esta versión

Incluye la aplicación móvil conectada al backend Django desplegado en Render
(Cloud Firestore y Cloud Storage), Firebase Authentication y el modelo de
reconocimiento de gestos en el dispositivo. Queda pendiente:

- Validar el modelo con videos propios y medir la latencia en el teléfono.
- Gestos con movimiento (Agua, Me duele, Comer, Beber).

---

Proyecto de Taller de Proyecto · Ingeniería de Software · Universidad Peruana
de Ciencias Aplicadas (UPC).
