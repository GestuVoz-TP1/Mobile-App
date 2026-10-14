# GestuVoz — Matriz de trazabilidad (app móvil)

Fuentes de verdad, en orden de prioridad:
Documentos aprobados (Project Charter v1.4, OB1, OB2 v2.1) > Product Backlog V6 >
Historias de usuario > Mockups vigentes (`Mockups Gestuvoz/1..12.jpg`, idénticos a
`tp1_v2.pptx` diap. 29-31) > Modelo de datos (OB2 Fig. 6) > Código existente >
Decisiones técnicas.

Estados: IMPLEMENTADA · PARCIAL · PENDIENTE · BLOQUEADA.
"Estado inicial" = diagnóstico antes de los cambios. "Estado actual" se actualiza por fase.

## Decisiones aprobadas (D1–D11)

| ID | Decisión |
|----|----------|
| D1 | Salir del modo niño pide la contraseña del tutor (sin PIN). |
| D2 | Registro solo con correo y contraseña (modelo PADRE_TUTOR). |
| D3 | Consentimiento por perfil, al crear el perfil (HU021/HU027). |
| D4 | Sin consentimiento vigente: no se registran interacciones y no se habilita la cámara de gestos; el tablero sigue disponible. No se borran datos al retirar. |
| D5 | Eliminar perfil borra en cascada sus datos exclusivos; pictogramas personalizados solo si ningún otro perfil los usa. |
| D6 | Columna `emoji` en PICTOGRAMA para conservar los ~110 pictogramas semilla. Avatar del niño = iniciales (sin columna). |
| D7 | Gestos: preparación (gestos habilitados) → Comenzar → cámara "Buscando tus manos…" → reconocido / no reconocido (Intentar de nuevo · Usar pictogramas). DEMO con selector "DEMO — resultado simulado", sin porcentajes. |
| D8 | Se elimina la barra de acceso rápido. |
| D9 | Perfil nuevo inicia con todos los pictogramas semilla seleccionados. |
| D10 | Gestos DEMO: Hola 👋, Agua 💧, Ayuda 🆘, Parar ✋ (`demo_*`, instrucciones vacías y editables). |
| D11 | Se borra una sola vez `training_images/` (fotos del antiguo módulo de expresión facial). |

## Cambios de esquema justificados (respecto a OB2 Fig. 6)

| Tabla | Cambio | Justificación |
|-------|--------|---------------|
| PADRE_TUTOR | + `contrasena_hash`, `contrasena_sal` | Acceso local (HU018/HU019) mientras no exista Firebase Authentication. Sin PIN. |
| PICTOGRAMA | `id_intencion` admite NULL | Pictogramas del tablero sin gesto (HU007/HU008/HU012); INTENCION 1:1 GESTO no puede cubrir ~110 pictogramas. |
| PICTOGRAMA | + `emoji` (NULL) | D6. |
| PERFIL_PICTOGRAMA | + `orden` | RF-07 / mockup 10 "Orden personalizado". |
| GESTO | + `instrucciones` (NULL) | Indicaciones del gesto (RF-02, D7, D10). |
| CONFIGURACION_VOZ | + `voz_activada` | Mockup 11 / aprobado. |
| INTERACCION | `id_gesto`, `id_intencion` admiten NULL | Flujo OB2 Fig. 8: interacción por pictograma sin gesto. `id_pictograma` e `id_perfil` siguen NOT NULL. |
| PERFIL_NINO | (sin cambio) `preferencias_comunicacion` JSON: gestos activados, gestos habilitados, tamaño de pictogramas, alto contraste | HU004, RF-15, HU016, RNF-04. |

## Funcionalidades existentes retiradas (sin respaldo documental)

| Funcionalidad | Motivo |
|---------------|--------|
| Expresión facial / análisis de afecto | OB2 define gestos manuales (MobileNet+LSTM, HaGRID); ninguna HU lo pide. |
| Datos de entrenamiento (fotos del niño) | RNF-02; fuera de alcance. |
| PIN del modo niño | No está en documentos ni HU (provenía de un informe previo "TP1-1"). |
| Recompensa con confeti | Sin respaldo; contradice "evitar animaciones excesivas". |
| Reordenamiento automático por uso | Contradice HU015 / orden personalizado. |
| Racha y "% vía expresión" | Sin respaldo. |
| Interruptor "Modo offline" | No tenía efecto. |
| Barra de acceso rápido | D8. |

## Matriz HU → funcionalidad → archivos → estado

| HU | Épica | Funcionalidad | Estado inicial | Estado actual | Archivos |
|----|-------|---------------|----------------|---------------|----------|
| HU001 | E1 | Reconocer gestos | PENDIENTE | PENDIENTE | — |
| HU002 | E1 | Preparar gestos (activar + permiso cámara) | PENDIENTE | PENDIENTE | — |
| HU003 | E1 | Consultar gestos disponibles | PENDIENTE | PENDIENTE | — |
| HU004 | E1 | Activar/desactivar gestos | PENDIENTE | PENDIENTE | — |
| HU005 | E1 | Usar pictogramas si el gesto falla | PENDIENTE | PENDIENTE | — |
| HU006 | E2 | Comunicar lo que expresa el gesto | PENDIENTE | PENDIENTE | — |
| HU007 | E2 | Tablero de pictogramas | PARCIAL | PARCIAL | — |
| HU008 | E2 | Seleccionar pictograma | PARCIAL | PARCIAL | — |
| HU009 | E2 | Escuchar mensaje | PARCIAL | PARCIAL | — |
| HU010 | E2 | Categorías | IMPLEMENTADA (global) | IMPLEMENTADA (global) | — |
| HU011 | E1 | Reintentar gesto | PENDIENTE | PENDIENTE | — |
| HU012 | E3 | Crear pictograma personalizado | PARCIAL | PARCIAL | — |
| HU013 | E3 | Editar pictograma personalizado | PENDIENTE | PENDIENTE | — |
| HU014 | E3 | Organizar por categorías | PARCIAL | PARCIAL | — |
| HU015 | E3 | Seleccionar pictogramas del tablero | PARCIAL | PARCIAL | — |
| HU016 | E3 | Tamaño de pictogramas | PARCIAL | PARCIAL | — |
| HU017 | E3 | Configurar voz | PARCIAL | PARCIAL | — |
| HU018 | E4 | Registrar cuenta | PARCIAL | PARCIAL | — |
| HU019 | E4 | Iniciar sesión | IMPLEMENTADA (usuario) | IMPLEMENTADA (usuario) | — |
| HU020 | E4 | Recuperar contraseña | PENDIENTE | BLOQUEADA (requiere backend) | — |
| HU021 | E4 | Crear perfiles infantiles | PARCIAL | PARCIAL | — |
| HU022 | E4 | Actualizar perfil | PARCIAL | PARCIAL | — |
| HU023 | E4 | Seleccionar perfil | PENDIENTE | PENDIENTE | — |
| HU024 | E4 | Cambiar de perfil | PENDIENTE | PENDIENTE | — |
| HU025 | E4 | Eliminar perfil | PENDIENTE | PENDIENTE | — |
| HU026 | E4 | Cerrar sesión | IMPLEMENTADA | IMPLEMENTADA | — |
| HU027 | E5 | Otorgar consentimiento | PENDIENTE | PENDIENTE | — |
| HU028 | E5 | Retirar consentimiento | PENDIENTE | PENDIENTE | — |
| HU029 | E5 | Consultar uso de datos | PENDIENTE | PENDIENTE | — |
| HU030 | E6 | Historial | PARCIAL | PARCIAL | — |
| HU031 | E6 | Mensajes frecuentes | PARCIAL | PARCIAL | — |
| HU032 | E6 | Filtrar por fechas | PENDIENTE | PENDIENTE | — |
| HU033 | E6 | Detalle de interacción | PENDIENTE | PENDIENTE | — |

## Registro de avance por fase

- Fase 4 (SQLite): en curso.
