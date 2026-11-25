# Roadmap UX/UI — Escritorio Hyprland + Quickshell (`feat/dashboard-bar`)

Documento de traspaso (*handoff*) para continuar la mejora de UX/UI del entorno de escritorio en `~/.dotfiles`.
Al retomar este trabajo, leer también [AGENTS.md](../AGENTS.md) en la raíz del repositorio.

---

## 1. Estado actual de la rama (`feat/dashboard-bar`)

### Ya implementado y verificado en vivo

- **Barra superior minimalista de 3 zonas** (`hypr/quickshell/BarWindow.qml`, `SystemState.qml`):
  - Izquierda: Lanzador / Overview + Workspaces.
  - Centro: Píldora de fecha/hora que despliega el Dashboard unificado (`Super+I`).
  - Derecha: Toggle Claro/Oscuro → Notificaciones (`Super+N`) → Energía y sesión (`Super+X`).
  - Altura `40 px` (`pillH = 30 px`) con tipografía ampliada (`14–15 px` texto, `16–17 px` iconos).
- **Dashboard central unificado** (`hypr/quickshell/DashboardPopup.qml`):
  - 4 pestañas con indicador deslizante Material 3: `Dashboard`, `Media`, `Rendimiento`, `IA`.
  - Se retiraron `CalendarPopup.qml`, `QuickSettingsPopup.qml` y `AiPopup.qml` (los endpoints IPC `calendar`, `quicksettings` y `ai` siguen activos en `shell.qml` como alias hacia `DashboardPopup`).
  - Mayor altura vertical y aire en las 4 pestañas.
- **Lanzador maestro acoplado al borde inferior** (`hypr/quickshell/LauncherWindow.qml`):
  - Expansión suave desde abajo con curvas cóncavas `bottom-right` / `bottom-left` y marco cyan continuo de `2 px`.
- **Lenguaje visual unificado en todos los overlays acoplados**:
  - Oscurecimiento suave del fondo (`Theme.dimAround = rgba(0,0,0,0.40)`) sin blur (`hypr/conf/appearance.conf`).
  - Borde cyan continuo (`2 px`) sobre la barra/borde de pantalla + `ConcaveCorner` (`z: 2`) + `ShapePath` en `U` sin picos superpuestos ni cortes.
- **Notificaciones** (`NotificationCard.qml`, `NotificationPopups.qml`, `shell.qml`):
  - Sin borde izquierdo de urgencia, sin barra de progreso inferior, duración por defecto/máxima de `5 s`.
- **Corrección de foco de teclado Wayland** (Hyprland `0.55+` con `input:follow_mouse = 2`):
  - Todos los overlays acoplados mantienen `WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive` constante hasta el desmontaje de `LazyLoader` + `HyprlandFocusGrab` + `mask: panelOpen ? null : emptyMask`.
- **Atajos nuevos** (`hypr/conf/keybinds.conf`, `hypr/scripts/dashboard-toggle.sh`):
  - `Super+I` → alterna `DashboardPopup` (`dashboard-toggle.sh`).
  - `Super+X` → alterna `PowerPopup` (`powermenu.sh`).
- **Bloque P0 completado**:
  1. IA unificada en `DashboardPopup` Tab 3 (`AiPopup.qml` eliminado; `Super+Shift+A` / `qs ipc call ai toggle` abren Tab 3).
  2. Tarjeta duplicada de Red en Dashboard Tab 0 reemplazada por resumen compacto de **Rendimiento** (`CPU %`, `RAM %`, temperatura; clic abre Tab 2).
  3. Calma cromática y gramática M3 tonal en `LauncherWindow.qml` (tabs tonales con indicador deslizante + fila seleccionada `Theme.primaryContainer` sin borde cyan redundante).
  4. Confirmación inline en dos pasos para acciones destructivas (`Cerrar sesión`, `Reiniciar`, `Apagar`) + aceleradores de una tecla (`L`, `S`, `H`, `E`, `R`, `P`) en `PowerPopup.qml` (`width: 416`).
  5. `LauncherWindow` abre en el monitor enfocado (`resolveFocusedScreen()`) igual que los demás overlays, eliminando `primaryScreenProbe`.
- **Bloque P1 completado**:
  1. Escala tipográfica nivelada en `DashboardPopup.qml`, `PowerPopup.qml`, `LauncherWindow.qml`, `NotificationCard.qml` y `NotificationCenter.qml` (piso `11–12 px` subtítulos/metadatos, `13–14 px` etiquetas y títulos principales).
  2. Cabecera de `DashboardPopup.qml` centrada (tray compacta retirada de la fila de tabs) y nombres legibles en la bandeja de Tab 2 (`tooltipTitle || title || id`).
  3. Feedback numérico (`%` / `Mudo`) en sliders verticales y chip interactivo `Hoy` en la cabecera del calendario de Tab 0.
  4. `NotificationCenter.qml` con altura adaptable (`380 px` vacío hasta `80%` de pantalla), cierre inferior limpio sin hueco de `12 px` y etiqueta `"No molestar"`.
  5. `OverviewWindow.qml` (`Super+A`) con nombres legibles e iconos reales (`DesktopEntries` / `Quickshell.iconPath`), workspaces vacíos silenciosos (`"Clic para ir al workspace N"` solo en hover/selección), buscador garantizado en el monitor enfocado y tratamiento visual alineado (`dimAround` + borde cyan).

---

## 2. Invariantes técnicos obligatorios (NO romper)

1. **Propiedades de color en `Theme.qml` (`Singleton`):** usar siempre prefijo `Theme.fg*`, **nunca** `Theme.on*` (colisiona con signal handlers de Qt6).
2. **Sin `Behavior on ...` dentro de `Theme.qml` (`Singleton`):** provoca `SIGSEGV` en Quickshell.
3. **Foco de teclado Wayland con `follow_mouse = 2`:**
   - **Nunca** usar `WlrKeyboardFocus.OnDemand`.
   - **Nunca** cambiar `WlrLayershell.keyboardFocus` de `Exclusive` a `None` mientras la ventana sigue montada durante el timer de animación de cierre (rompe la devolución de foco a Zed/ventanas activas). Mantener `Exclusive` constante + `mask: panelOpen ? null : emptyMask` + `HyprlandFocusGrab`.
4. **Geometría de esquinas cóncavas:**
   - `ConcaveCorner.qml` debe mantener `z: 2` para que el arco de `2 px` quede por encima de la superficie y empalme sin corte con el `ShapePath` del panel en `y = Theme.concaveRadius` (`16 px`).
5. **Hardware agnóstico:** no asumir CPU, RAM, GPU ni batería fija (cualquier elemento de batería o brillo debe quedar condicionado a `hasBattery` / `hasBacklight`).
6. **Flujo de aplicación y verificación obligatorio tras cambios:**
   - Validación sintáctica estática QML (llaves/paréntesis balanceados, cero `Theme.on*`, cero `OnDemand`) y `bash -n` en scripts modificados.
   - `make refresh && sleep 4`
   - Verificar `hyprctl configerrors` (vacío) y último `/run/user/$(id -u)/quickshell/by-id/*/log.qslog` (cero errores QML).
   - Verificación visual con `grim` (borrar capturas temporales después) y `make verify`.

---

## 3. Pasos pendientes para el próximo agente

### Bloque P1 — Jerarquía tipográfica, estética y claridad

- [x] **1. Nivelar la escala tipográfica interna de los popups**
  - *Problema:* la barra superior usa `14–15 px`, mientras los popups aún tienen numerosos textos en `10–11 px` (escala invertida).
  - *Archivos:* `hypr/quickshell/DashboardPopup.qml`, `hypr/quickshell/PowerPopup.qml`, `hypr/quickshell/NotificationCard.qml`, `hypr/quickshell/NotificationCenter.qml`, `hypr/quickshell/LauncherWindow.qml`.
  - *Objetivo:* subir el piso mínimo a `11–12 px` para subtítulos/metadatos y `13–14 px` para etiquetas/títulos principales, ajustando alturas de tarjetas si hiciera falta para evitar truncamiento (`elide`).

- [x] **2. Limpiar cabecera del Dashboard y nombre legible en la bandeja del sistema**
  - *Problema:* en `DashboardPopup.qml`, la píldora compacta de `SystemTray` en la cabecera de tabs desalinea las 4 pestañas respecto del reloj central y duplica la bandeja de Tab 2 (`Rendimiento`). Además, en Tab 2 (`line ~2703`) se muestra el ID técnico D-Bus (`Antigravity_status_icon_1`) en lugar del nombre humano.
  - *Archivo:* `hypr/quickshell/DashboardPopup.qml`.
  - *Objetivo:*
    - Retirar (o reubicar fuera de la fila de tabs) la píldora de tray de la cabecera para que las 4 pestañas queden 100% centradas.
    - En la bandeja de Tab 2, resolver el texto como `String(modelData.tooltipTitle || modelData.title || modelData.id || "App")` (verificando las propiedades disponibles en `SystemTrayItem` en `log.qslog` si alguna difiere).

- [x] **3. Feedback numérico en sliders verticales y botón "Hoy" en el calendario**
  - *Archivo:* `hypr/quickshell/DashboardPopup.qml` (Tab 0).
  - *Objetivo:*
    - Mostrar el porcentaje (`%`) en los sliders verticales de Volumen, Micrófono y Brillo (visible de forma sutil arriba/abajo o al hacer hover/arrastre).
    - En la cabecera del calendario, mostrar un pequeño chip interactivo `Hoy` únicamente cuando `displayYear !== currentDate.getFullYear() || displayMonth !== currentDate.getMonth()` para volver al mes actual con claridad.

- [x] **4. Proporción, cierre inferior e idioma del Centro de Notificaciones**
  - *Archivo:* `hypr/quickshell/NotificationCenter.qml`.
  - *Objetivo:*
    - Eliminar el hueco inferior de `12 px` (`bottomMargin: 12`) pegando el drawer limpiamente al borde inferior (con su borde cyan coherente) o bien hacerlo de altura adaptable (`min ~360 px`, `max ~80%` de pantalla) con esquina inferior izquierda y borde inferior cerrados con sentido. Confirmar visualmente con `grim` en estado vacío y con varias notificaciones.
    - Cambiar la etiqueta `"DND"` por `"No molestar"` (o `"Silenciar"`).

- [x] **5. Pulido del Overview (`Super+A`)**
  - *Archivo:* `hypr/quickshell/OverviewWindow.qml`.
  - *Objetivo:*
    - Reemplazar la clase técnica cruda (`dev.zed.Zed`) en el pie de cada ventana por nombre legible + icono (usando `DesktopEntries` / `Quickshell.iconPath` con fallback limpio).
    - Reducir ruido visual en workspaces vacíos: mostrar el texto `"Clic para ir al workspace N"` (en español, sin `"Click"`) solo en *hover* o usar un indicador mínimo.
    - Alinear el tratamiento visual del backdrop/borde con el resto de overlays y revisar por qué la barra de búsqueda se oculta cuando el monitor aún no figura como `isFocusedMonitor`.

---

### Bloque P2 — Ergonomía de uso diario y cohesión entre capas

- [ ] **6. Alertas contextuales discretas en la barra superior**
  - *Archivo:* `hypr/quickshell/BarWindow.qml` (y `shell.qml` / `SystemState.qml` si falta pasar `sinkMuted` o batería baja).
  - *Objetivo:* mantener la barra minimalista en estado normal, pero mostrar un ícono discreto **solo ante estados anómalos**: audio silenciado (`sinkMuted`), sin conexión de red (`netKind === "disconnected"`), o batería baja (`<= 20%` sin cargar en laptops), igual que ya ocurre con grabación activa, IA y reposo inhibido.

- [ ] **7. Señal de scroll y contador de resultados en el Lanzador**
  - *Archivo:* `hypr/quickshell/LauncherWindow.qml`.
  - *Objetivo:*
    - Agregar un indicador de desplazamiento delgado (`ScrollBar` o barra sutil) y/o desvanecimiento inferior suave en `resultList` para evitar cortes bruscos de la última fila visible.
    - Mostrar un contador sutil con la cantidad de resultados (`filteredItems.length`) dentro del buscador.

- [ ] **8. Alinear Fuzzel y OSD con el lenguaje visual del entorno**
  - *Archivos:* `hypr/fuzzel/fuzzel.ini`, `hypr/themes/dark/` y `hypr/themes/light/` (si `theme-switch.sh` genera/copia configs de fuzzel — verificar `hypr/scripts/theme-switch.sh`), y `hypr/quickshell/OsdWindow.qml`.
  - *Objetivo:*
    - Subir tipografía de Fuzzel (`Inter:size=11.5`), `border` de `2 px` en color primario (`22d3eeff` en dark / `#006d80` en light) y `radius=20`.
    - Revisar el borde de `OsdWindow.qml` para integrarlo visualmente con el acento primario (`Theme.primary` / `Theme.error` en alerta).

- [ ] **9. Consistencia de microcopy en español**
  - *Archivos:* `DashboardPopup.qml`, `NotificationCenter.qml`, `OverviewWindow.qml`.
  - *Objetivo:* reemplazar restos en inglés (`"DND"`, `"Click"`, `"Off"`, `"Player"`, `"load"`) por equivalentes claros en español (`"No molestar"`, `"Clic"`, `"Sin red"`, `"Reproductor"`, `"carga"`).

- [ ] **10. Navegación por teclado ampliada**
  - *Archivos:* `hypr/quickshell/DashboardPopup.qml`, `hypr/quickshell/NotificationCenter.qml`.
  - *Objetivo:*
    - En `DashboardPopup`: añadir `←`/`→` para cambiar entre pestañas y un micro-hint discreto de atajos si suma claridad.
    - En `NotificationCenter`: añadir navegación con `↑`/`↓`, `Delete`/`Backspace` para descartar y `Enter` para acción principal.

---

### Bloque P3 — Pulido final y cierre de rama

- [ ] **11. Recorte circular real en la portada de Media (Dashboard Tab 0)**
  - *Nota detectada en captura en vivo:* en `DashboardPopup.qml` Tab 0 (`line ~1656`), la portada muestra esquinas cuadradas dentro del círculo porque `Rectangle { clip: true; radius: 39 }` no recorta un `Image` hijo a círculo en Qt6 sin `MultiEffect` / `OpacityMask` o contenedor cuadrado redondeado coherente (`radius: Theme.radiusMedium`).
- [ ] **12. Auditoría visual en Modo Claro (`light`)**
  - Ejecutar `~/.config/hypr/scripts/theme-switch.sh light` y verificar contraste de `Theme.activeBorder` (`#006d80`), `Theme.dimAround`, textos `fgOnPrimaryContainer`, `DashboardPopup`, `LauncherWindow`, `PowerPopup`, `NotificationCenter` y `Fuzzel` con `grim`; luego volver a `dark` si era el modo activo.
- [ ] **13. Revisión final e integración a `main`**
  - Confirmar con el usuario antes de hacer merge de `feat/dashboard-bar` en `main` y limpiar la rama.
