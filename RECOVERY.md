# 🚨 Guía de Recuperación de Desastres

**Perfil de Estación:** Debian Testing · Particionado GPT (`EFI` 512 MB + `ext4` monolítico) · Respaldo del sistema vía **Timeshift (RSYNC)**.

> **Garantía de Integridad de Datos:** La política de snapshots configurada en `/etc/timeshift/timeshift.json` excluye explícitamente `/home/**` y `/root/**`. **Cualquier restauración con Timeshift revierte únicamente el sistema operativo base (`/`), manteniendo intactos tus proyectos, documentos, contenedores de usuario y claves SSH.**

---

## Diagnóstico Rápido: ¿En qué escenario estás?

| Síntoma al encender el equipo | Escenario a aplicar | Tiempo estimado |
| :--- | :--- | :--- |
| El sistema arranca pero la pantalla queda negra, parpadea o GNOME no inicia sesión | **Escenario 1:** Recuperación por consola TTY (`Ctrl+Alt+F3`) | 2 - 4 min |
| El sistema se congela cargando servicios pero se puede ver el menú inicial de **GRUB** | **Escenario 2:** Arranque con Kernel previo o *Recovery Mode* | 3 - 5 min |
| Error `grub rescue>`, `Kernel Panic`, `(initramfs)` o reinicio en bucle sin menú GRUB | **Escenario 3:** Rescate externo desde Pendrive **Ventoy (`chroot`)** | 5 - 10 min |

---

## Escenario 1: Falla del Entorno Gráfico (Acceso vía TTY)

Si una actualización de Mesa, Wayland o GNOME impide levantar la pantalla de login pero el sistema operativo está vivo por detrás:

1. En la pantalla bloqueada o negra, presionar **`Ctrl + Alt + F3`** (o probar con `F4` / `F5`) para abrir una terminal de texto (`TTY`).
2. Iniciar sesión con tu usuario y contraseña habituales.
3. Lanzar el asistente de rollback:
   ```bash
   devctl rollback
   ```
   *(Alternativa directa si `devctl` no está en el PATH: `sudo timeshift --restore`)*.
4. En la lista interactiva:
   * Escribir el **número de índice** del snapshot previo al fallo y presionar **`Enter`**.
   * Presionar **`Enter`** nuevamente para confirmar los discos de destino por defecto.
   * Confirmar con **`y`** para iniciar la restauración. El equipo se reiniciará automáticamente al terminar.

---

## Escenario 2: El sistema no termina de arrancar (Acceso desde GRUB)

Si una actualización de paquetes base (`systemd`, `libc6`, `udev`) o un kernel nuevo detiene el arranque antes de llegar al login:

1. Reiniciar el equipo y presionar repetidamente la tecla **`Flecha Abajo`** (o mantener `Shift` / `Esc`) apenas desaparece el logo del BIOS para frenar la cuenta regresiva de **GRUB**.
2. Seleccionar **"Opciones avanzadas para Debian GNU/Linux"** (*Advanced options for Debian GNU/Linux*).

### Opción 2A: Fallo exclusivo del último Kernel
1. Seleccionar la segunda versión de kernel de la lista (el kernel anterior al actual, **sin** la etiqueta *recovery mode*) y presionar **`Enter`**.
2. Si el sistema inicia normalmente, abrir una terminal y ejecutar `devctl rollback` para deshacer la actualización conflictiva, o regenerar el initramfs del kernel nuevo con `sudo update-initramfs -u -k all`.

### Opción 2B: Modo de Recuperación (*Recovery Mode*)
1. Dentro de "Opciones avanzadas", seleccionar la entrada que termina en **`(recovery mode)`**.
2. Una vez que el sistema detenga la carga y muestre el mensaje de mantenimiento, presionar **`Enter`** para ingresar a la consola como `root`.
   *(Nota: Si el sistema bloquea el acceso indicando `Cannot open access to console, the root account is locked`, pasar directamente al **Escenario 3**).*
3. Ejecutar el rollback:
   ```bash
   timeshift --restore
   ```
4. Elegir el número de snapshot sano, confirmar las opciones por defecto con **`Enter`** y **`y`**, y aguardar el reinicio automático.

---

## Escenario 3: Falla Catastrófica Total (Rescate con Pendrive Ventoy + `chroot`)

Cuando el cargador GRUB se corrompe, se llena o rompe el `initramfs`, o no es posible acceder al *Recovery Mode*, la estación se recupera desde afuera utilizando cualquier ISO Live de Linux cargada en el pendrive **Ventoy**.

### Paso 1: Iniciar desde el Pendrive Ventoy
1. Conectar el pendrive Ventoy con el equipo apagado.
2. Encender y presionar la tecla de menú de booteo del BIOS/UEFI (`F12` en Lenovo/Dell, `F11` o `F8` en Gigabyte/ASUS, `F9` en HP).
3. Seleccionar el pendrive en modo **UEFI** e iniciar una imagen **Debian Live** (o cualquier distro Live disponible en el USB).
4. Abrir una terminal y pasar a superusuario:
   ```bash
   sudo -i
   ```

### Paso 2: Identificar las particiones del disco local
Nuestras estaciones utilizan siempre una tabla GPT con 2 particiones:
* **Partición 1 (`p1` o `1`):** 512 MB `vfat` (Partición EFI).
* **Partición 2 (`p2` o `2`):** Resto del disco en `ext4` (Sistema raíz `/`).

Ejecutar:
```bash
lsblk -f
```
* **En equipos con disco NVMe:** La raíz es `/dev/nvme0n1p2` y el EFI es `/dev/nvme0n1p1`.
* **En equipos con disco SSD SATA:** La raíz es `/dev/sda2` y el EFI es `/dev/sda1`.

### Paso 3: Montar el sistema dañado y entrar en `chroot`
*(Ajustar `/dev/nvme0n1p2` y `/dev/nvme0n1p1` a `/dev/sda2` y `/dev/sda1` si el disco es SATA)*:

```bash
# 1. Crear punto de montaje y montar raíz (ext4) + EFI (fat32)
mkdir -p /mnt/rescue
mount /dev/nvme0n1p2 /mnt/rescue
mount /dev/nvme0n1p1 /mnt/rescue/boot/efi

# 2. Enlazar directorios virtuales del kernel y variables UEFI
for dir in /dev /dev/pts /proc /sys /run; do
    mount --bind "$dir" "/mnt/rescue$dir"
done
[ -d /sys/firmware/efi/efivars ] && mount --bind /sys/firmware/efi/efivars /mnt/rescue/sys/firmware/efi/efivars

# 3. Habilitar resolución DNS por si se requiere descargar paquetes con APT
cp -L /etc/resolv.conf /mnt/rescue/etc/resolv.conf

# 4. Ingresar al sistema instalado
chroot /mnt/rescue /bin/bash
```

### Paso 4: Restaurar con Timeshift o Reparar Manualmente

#### Caso A: Restaurar un Snapshot de Timeshift (Recomendado)
Dentro del `chroot`, listar los snapshots y restaurar:
```bash
timeshift --list
timeshift --restore
```
1. Ingresar el **número de índice** del snapshot deseado.
2. Presionar **`Enter`** en las preguntas de ruta de montaje (`/` y `/boot/efi`).
3. Confirmar la reinstalación de **GRUB2** y presionar **`y`** para ejecutar la restauración.

#### Caso B: Reparación sin Snapshot (Si una actualización se cortó por falta de energía)
Si el fallo ocurrió antes de haber creado el primer snapshot o por un corte eléctrico en pleno `apt upgrade`:
```bash
# 1. Completar configuración de paquetes interrumpidos y reparar dependencias
dpkg --configure -a
apt-get update
apt-get install -f -y

# 2. Regenerar las imágenes initramfs de todos los kernels
update-initramfs -u -k all

# 3. Reinstalar el cargador de arranque GRUB2 en la partición UEFI
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=debian --recheck
update-grub
```

### Paso 5: Salir de forma segura y reiniciar
Una vez completado el Paso 4:
```bash
# 1. Salir del entorno chroot
exit

# 2. Desmontar todas las particiones y volcar el caché de escritura a disco
umount -R /mnt/rescue
sync

# 3. Reiniciar el equipo y retirar el pendrive Ventoy
reboot
```

---

## Anexo: Comandos de Emergencia con APT Pinning (Sin restaurar todo el sistema)

Cuando solo un paquete puntual de **Debian Testing** presenta un bug recién introducido pero el sistema funciona normalmente:

* **Instalar la versión con el fix adelantado desde `unstable` (Sid):**
  ```bash
  sudo apt-get update
  sudo apt-get install -t unstable <nombre-del-paquete>
  ```
* **Retener (congelar) un paquete para que `devctl update` no lo actualice hasta que se corrija upstream:**
  ```bash
  sudo apt-mark hold <nombre-del-paquete>
  ```
* **Liberar un paquete retenido:**
  ```bash
  sudo apt-mark unhold <nombre-del-paquete>
  ```
