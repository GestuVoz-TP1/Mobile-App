# GestuVoz — Aplicación móvil (Flutter · Android)

Sistema aumentativo y alternativo de comunicación (SAAC) basado en machine
learning para apoyar la comunicación no verbal de niños con TEA en Lima
Metropolitana.

Fuentes de verdad: Project Charter v1.4, OB1, OB2 v2.1, Product Backlog V6 y
mockups vigentes. La trazabilidad HU → funcionalidad → archivos → estado está en
[`docs/TRAZABILIDAD.md`](docs/TRAZABILIDAD.md).

## Alcance de esta etapa

Solo la aplicación móvil: Flutter + Dart + Android + SQLite + cámara + voz +
pictogramas + reconocimiento de gestos (DEMO) + UX/UI infantil.

**No incluye todavía** backend Django, API REST, Firebase Authentication,
Cloud Firestore, Cloud Storage ni sincronización. El acceso del tutor es local
(contraseña con hash y sal en SQLite).

## Flujo

1. **Bienvenida → Crear cuenta / Iniciar sesión** (correo y contraseña).
2. **Perfiles**: crear el perfil del niño (nombre, fecha de nacimiento, género,
   nivel de apoyo) → **consentimiento** de tratamiento de datos del perfil.
3. **¿Quién usará la app?**
   - **Panel del niño**: Inicio · Hablar (tablero por categorías + "Mi
     mensaje") · Gestos (preparación → cámara → reconocido / no reconocido).
     Para salir se pide la contraseña del tutor.
   - **Panel del tutor**: Inicio · Reportes (historial) · Ajustes (perfiles,
     perfil del niño, voz, pictogramas, gestos, privacidad, cerrar sesión).

Sin consentimiento vigente no se registran interacciones ni se usa la cámara;
el tablero de pictogramas sigue disponible.

## Reconocimiento de gestos

```
Cámara (secuencia en memoria) → GestureRecognitionService → GESTO
  → INTENCION_COMUNICATIVA → PICTOGRAMA → voz → INTERACCION
```

- `MockGestureRecognitionService` (activo): **no es un modelo de ML**. El
  resultado se elige en el selector **"DEMO — resultado simulado"** y nunca se
  muestran porcentajes.
- `TensorFlowLiteGestureRecognitionService`: estructura preparada para el
  modelo MobileNet + LSTM (OB2). No está activa porque aún no existe el
  `.tflite` entrenado. Pasos para activarla en el propio archivo.
- Los 4 gestos actuales (Hola, Agua, Ayuda, Parar) son **DEMO**, no el
  repertorio oficial. Sus instrucciones son editables desde
  Ajustes → Gestos disponibles.
- Las imágenes de la cámara nunca se guardan en disco.

## Arquitectura

```
lib/
  domain/          Entidades y puertos (sin Flutter): auth, child, communication,
                   gesture, ml, interaction, consent, settings (voz), reporting
  application/     Casos de uso: auth, profile, privacy, communication,
                   gesture, interaction, reporting, settings
  infrastructure/  SQLite (database.dart + repositories.dart), cámara, TTS,
                   ML (mock + TFLite preparado), seed, CSV
  presentation/    Controladores (ChangeNotifier) + pantallas + widgets + tema
  di.dart          Composition root
```

UI → Controller → Service → Repository → SQLite. Ningún widget consulta SQLite.

### SQLite

Esquema de OB2 (Fig. 6): `padre_tutor`, `nino`, `perfil_nino`, `categoria`,
`pictograma`, `perfil_pictograma`, `gesto`, `intencion_comunicativa`,
`configuracion_voz`, `consentimiento`, `interaccion`. Los cambios justificados
están en `docs/TRAZABILIDAD.md`.

Datos iniciales (SEED): las 10 categorías y los 127 pictogramas que ya tenía el
prototipo (emojis) y los 4 gestos DEMO.

## Ejecutar y probar

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

APK: `flutter build apk --debug` → `build/app/outputs/flutter-apk/app-debug.apk`

Las pruebas de `test/persistence_test.dart` usan SQLite real
(`sqflite_common_ffi`) e incluyen el ciclo crear → cerrar → reabrir.
