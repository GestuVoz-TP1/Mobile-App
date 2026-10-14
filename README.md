# GestuVoz — Aplicación móvil

**Sistema aumentativo y alternativo de comunicación (SAAC) basado en machine
learning para apoyar la comunicación no verbal de niños con TEA en Lima
Metropolitana.**

GestuVoz permite que un niño con TEA exprese lo que necesita de dos formas:
tocando **pictogramas** o haciendo **gestos con las manos** frente a la cámara.
En ambos casos la app muestra el pictograma y **dice el mensaje en voz alta**.
El padre, madre o tutor configura los perfiles, personaliza los pictogramas y
la voz, gestiona el consentimiento y consulta el historial de uso.

Aplicación Android desarrollada con Flutter. Toda la información se guarda en
el dispositivo (SQLite) y funciona sin conexión a internet.

---

## Tabla de contenidos

- [Funcionalidades](#funcionalidades)
- [Cómo se usa](#cómo-se-usa)
- [Reconocimiento de gestos](#reconocimiento-de-gestos)
- [Arquitectura](#arquitectura)
- [Base de datos](#base-de-datos)
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
  contraseña, varios perfiles infantiles por tutor (crear, editar, cambiar y
  eliminar) y cierre de sesión.
- **Privacidad (E5):** consentimiento por perfil (otorgar, rechazar o retirar)
  e información sobre los datos tratados (Ley N.º 29733). Sin consentimiento
  vigente no se registran interacciones ni se usa la cámara; el tablero sigue
  disponible.
- **Historial (E6):** registro de cada mensaje comunicado, filtros por fecha,
  detalle de cada interacción, mensajes más usados, actividad semanal y
  exportación a CSV. Es una consulta descriptiva: no realiza evaluaciones
  clínicas.

> La recuperación de contraseña por correo (HU020) requiere un servicio de
> autenticación en línea y se incorporará con el backend.

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

### Estado del modelo

El modelo previsto es **MobileNet + LSTM** ejecutado con **TensorFlow Lite**
en el dispositivo. La integración está preparada en
`lib/infrastructure/ml/tflite_gesture_recognition_service.dart`, que incluye
los pasos para activarla cuando exista el archivo `.tflite` entrenado.

Mientras tanto, la app usa `TestModeGestureRecognitionService`:

- **En compilación de desarrollo** (`flutter run`): después de la captura
  aparece el panel **"¿Qué gesto hiciste?"**, donde quien prueba la app elige
  el gesto (o "No reconocido"). Así se puede recorrer el flujo completo.
- **En compilación de lanzamiento** (`--release`): ese panel no existe y todo
  intento termina en "No reconocido" hasta integrar el modelo.

La app nunca muestra porcentajes de coincidencia si no hay un modelo real.

### Gestos iniciales

Hola 👋 · Agua 💧 · Ayuda 🆘 · Parar ✋. Cada uno está asociado a una intención
y a un pictograma del tablero. Sus instrucciones se escriben desde
**Ajustes → Gestos disponibles**. Para cargar el repertorio definitivo se
reemplaza `lib/infrastructure/seed/gesture_seed.dart` con las clases que
devuelva el modelo; el resto de la app no cambia.

---

## Arquitectura

Arquitectura por capas (Domain-Driven Design):

```
lib/
├── domain/           Entidades, reglas y puertos (sin Flutter)
├── application/      Casos de uso: auth, profile, privacy, communication,
│                     gesture, interaction, reporting, settings
├── infrastructure/   SQLite, cámara, texto a voz, reconocimiento de gestos,
│                     datos iniciales y exportación CSV
├── presentation/     Controladores (ChangeNotifier), pantallas, widgets y tema
├── di.dart           Composición de dependencias (único punto con
│                     implementaciones concretas)
└── main.dart
```

```
Pantalla ─► Controlador ─► Servicio de aplicación ─► Repositorio ─► SQLite
```

Ninguna pantalla accede directamente a la base de datos.

| Componente | Tecnología |
|------------|------------|
| Interfaz | Flutter (Material 3), `provider` |
| Persistencia local | SQLite (`sqflite`) |
| Cámara | `camera` |
| Voz | `flutter_tts` (español) |
| Imágenes de pictogramas | `image_picker` |
| Gráficos | `fl_chart` |
| Reconocimiento de gestos | TensorFlow Lite (integración preparada) |

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
flutter pub get
flutter run
```

Generar el APK:

```bash
flutter build apk --release
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

---

## Alcance de esta versión

Incluye la aplicación móvil completa con almacenamiento local. Se integrarán
en una etapa posterior:

- Backend con Django y API REST
- Firebase Authentication, Cloud Firestore y Cloud Storage
- Sincronización de datos en la nube
- Modelo entrenado de reconocimiento de gestos (MobileNet + LSTM)

---

Proyecto de Taller de Proyecto · Ingeniería de Software · Universidad Peruana
de Ciencias Aplicadas (UPC).
