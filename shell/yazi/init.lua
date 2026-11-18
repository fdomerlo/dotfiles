-- Yazi - comportamiento extra tipo gestor gráfico.
--
-- Yazi no cuenta "doble click": el click izquierdo solo revela (selecciona)
-- y el derecho abre. Para acercarlo a Nautilus/Dolphin se mide el tiempo
-- entre dos clicks izquierdos sobre el mismo archivo de la lista actual:
--   * carpeta  -> enter (navegar dentro)
--   * archivo  -> open  (con las reglas de [open]; los comprimidos se extraen)
--
-- El doble click solo aplica al panel actual (in_current), no al padre ni al
-- preview, para no mezclar la navegación normal de esos paneles.

local DOUBLE_CLICK_MS = 400
local last_url, last_at = nil, 0

local base_click = Entity.click

function Entity:click(event, up)
	base_click(self, event, up)

	if up or event.is_right or event.is_middle or not self._file.in_current then
		return
	end

	local now = ya.time()
	local url = tostring(self._file.url)

	if last_url == url and (now - last_at) * 1000 <= DOUBLE_CLICK_MS then
		last_url, last_at = nil, 0

		if self._file.cha.is_dir then
			ya.emit("enter", {})
		else
			ya.emit("open", { hovered = true })
		end
	else
		last_url, last_at = url, now
	end
end
