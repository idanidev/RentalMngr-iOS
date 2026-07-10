# RentalMngr — Guía de diseño Mac (Catalyst) / iPad

Fuente de verdad para que la app se vea **profesional y consistente** en pantallas grandes
(Mac Catalyst e iPad regular width) **sin tocar el diseño de iPhone**. Aplica estas reglas
de entrada en cada pantalla; no improvises ni esperes a que te las pidan.

Regla maestra: **gate por size class.** Las mejoras de pantalla grande van bajo
`horizontalSizeClass == .regular`. iPhone (compact) se queda como está. Lo que sea
puramente cosmético de ventana/Catalyst va bajo `#if targetEnvironment(macCatalyst)`
(no-op en iOS, no puede romper el iPhone).

---

## 1. Layout y márgenes

- **Gutter de contenido** (margen lateral de una pantalla): `regular = 20`, `compact = 16`.
  TODO lo de una pantalla comparte el MISMO gutter: hero, cabeceras de sección, listas,
  rejillas. Nunca mezclar 16 y 20 en la misma pantalla → eso es lo que produce el
  "desalineado". Define `private var gutter: CGFloat { hSize == .regular ? 20 : 16 }` y úsalo.
- **Separación entre secciones**: 24. **Entre tarjetas (grid/stack)**: 16–18.
- **Separación hero ↔ contenido**: mínimo 16 (el contenido no se pega al hero).
- El hero a sangre (full-bleed) está bien, pero su **texto interior** usa el gutter de la pantalla
  para alinear con el contenido de debajo.

## 2. Anchos de contenido

- **Rejillas de tarjetas** (propiedades, habitaciones): llenan el ancho con
  `GridItem(.adaptive(minimum:), alignment: .top)`. Sin cap → más columnas cuanto más ancho.
  - Tarjeta de propiedad: `minimum: 360`.
  - Tarjeta de habitación (foto grande): `minimum: 460`.
- **Formularios y columnas de texto largas**: sí cap (legibilidad), ~520–720, centrado.
- **Dashboards densos**: cap generoso ~1280–1600 centrado, NO columna estrecha.
- Nunca dejar contenido estirado de borde a borde en una sola columna (se ve roto),
  ni una columna estrecha con gutters enormes (desaprovecha). Multi-columna que llena.

## 3. Tipografía (escala fija, sin tamaños mágicos)

- Título de pantalla: `.largeTitle`/`.title2`.
- Nº grande (dinero del hero): `.system(.largeTitle, design: .rounded, weight: .bold)`.
- Título de tarjeta / nombre: `.title3.bold()` (Mac) — que se lea grande.
- Stat destacado: `.title3` rounded bold; su etiqueta `.caption`.
- Cuerpo: `.subheadline`. Meta/secundario: `.caption`/`.caption2`.
- Evitar `.font(.system(size: N))` salvo iconos. Preferir estilos semánticos (escalan).

## 4. Tarjetas

- Radio: `18` (contenedores), `12` (media/foto dentro de tarjeta).
- Fondo: `.background.secondary`. Borde: `RoundedRectangle.strokeBorder(.quaternary, lineWidth: 0.5)`.
- Sombras: sutiles o ninguna (plano, no “material design” pesado). El hero sí lleva sombra de color suave.
- **Tarjetas con foto y sin foto deben tener el MISMO layout** (mismo alto de media, nombre
  siempre superpuesto sobre el media con degradado inferior). Nunca un caso con texto encima
  y otro con texto debajo → descuadra.
- `.contentShape(RoundedRectangle(...))` para que toda la tarjeta sea pulsable.

## 5. Específico de macOS / Catalyst (HIG)

- **Hover / puntero**: en tarjetas y celdas pulsables, el cursor debe indicar interacción.
  Usa `.contentShape` + (cuando aporte) un efecto hover sutil (escala 1.01 / brillo de borde).
- **Hit area completa**: botones segmentados/celdas pulsables con `.frame(maxWidth:.infinity)`
  + `.contentShape(...)`. Nunca que solo el texto sea pulsable.
- **Ventana**: mínimo 920×640 (`MacWindow.swift`), titlebar unified. Tab bar arriba (no sidebar)
  para sensación iOS — sin columnas vacías.
- **Sheets**: en Mac no hay swipe-to-dismiss → TODA hoja modal lleva botón de cierre
  (`Done`/`Cerrar`) en toolbar (`.cancellationAction`/`.confirmationAction`).
- **VisionKit / cámara**: ocultar con `VNDocumentCameraViewController.isSupported`. Háptica: no-op en Mac.

## 6. Selectores / segmentos

- Para elegir entre pocas opciones (p.ej. propiedad activa en el detalle): control
  **segmentado** a todo el ancho, justo bajo el menú principal, con el segmento activo en
  color de acento y animación (`matchedGeometryEffect`). Hit area completa por segmento.
- Para muchas opciones: el mismo segmentado dentro de `ScrollView(.horizontal)`.

## 7. Estados

- **Vacío**: `EmptyStateView` centrado (icono + título + subtítulo + acción).
- **Carga**: skeleton o `ProgressView` centrado; nunca salto brusco.
- **Error**: inline, icono + mensaje + botón Reintentar.

## 8. Color (semántico, no decorativo)

- Naranja: marca / hero / ingresos.
- Índigo: propiedad. Morado: zonas comunes.
- Verde/mint: dinero cobrado / ocupado. Naranja/rojo: pendiente / vacante / alerta.
- Texto sobre foto: blanco con degradado inferior para legibilidad.

## 9. Checklist antes de dar una pantalla por buena (Mac)

1. ¿Un único gutter en toda la pantalla? (hero, headers, grids, listas alineados)
2. ¿Llena el ancho con multi-columna (no estirado, no columna estrecha)?
3. ¿Tipografía de la escala (sin tamaños mágicos)?
4. ¿Tarjetas consistentes (foto/sin-foto idénticas, radio/borde/fondo)?
5. ¿Toda celda/tarjeta pulsable en toda su área + cursor de puntero?
6. ¿Las hojas modales se pueden cerrar?
7. ¿iPhone intacto? (cambios bajo `regular` / `#if macCatalyst`)
