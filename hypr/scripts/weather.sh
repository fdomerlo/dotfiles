#!/usr/bin/env bash
# ==============================================================================
# hypr/scripts/weather.sh - Sonda de clima ligera para Quickshell.
#
# Consulta Open-Meteo (con geocoding/geo-IP automático y fallback a wttr.in),
# cachea resultados localmente en ${XDG_CACHE_HOME:-$HOME/.cache}/quickshell/
# y soporta overrides opcionales en ~/.config/quickshell/local.json:
#   - weatherLat / weatherLon (+ weatherCity opcional)
#   - weatherLocation (nombre de ciudad)
#
# Uso:
#   weather.sh [--force]
# ==============================================================================
set -euo pipefail

FORCE=0
if [ "${1:-}" = "--force" ]; then
    FORCE=1
fi

exec python3 - "$FORCE" <<'PY'
import json
import os
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

FORCE = len(sys.argv) > 1 and sys.argv[1] == "1"
CACHE_TTL = 900       # 15 minutos
STALE_TTL = 21600     # 6 horas de fallback sin red
GEO_TTL = 21600       # 6 horas para geo-IP
TIMEOUT = 6
USER_AGENT = "dotfiles-quickshell-weather/1.0"

XDG_CONFIG = Path(os.environ.get("XDG_CONFIG_HOME") or (Path.home() / ".config"))
XDG_CACHE = Path(os.environ.get("XDG_CACHE_HOME") or (Path.home() / ".cache"))
LOCAL_CFG = XDG_CONFIG / "quickshell" / "local.json"
CACHE_DIR = XDG_CACHE / "quickshell"
WEATHER_CACHE = CACHE_DIR / "weather.json"
GEO_CACHE = CACHE_DIR / "weather-geo.json"

WMO_MAP = {
    0: ("Despejado", "󰖙", "󰖔"),
    1: ("Mayormente despejado", "󰖙", "󰖔"),
    2: ("Parcialmente nublado", "󰖕", "󰼱"),
    3: ("Nublado", "󰖐", "󰖐"),
    45: ("Niebla", "󰖑", "󰖑"),
    48: ("Niebla", "󰖑", "󰖑"),
    51: ("Llovizna", "󰖗", "󰖗"),
    53: ("Llovizna", "󰖗", "󰖗"),
    55: ("Llovizna", "󰖗", "󰖗"),
    56: ("Llovizna helada", "󰖗", "󰖗"),
    57: ("Llovizna helada", "󰖗", "󰖗"),
    61: ("Lluvia ligera", "󰖗", "󰖗"),
    63: ("Lluvia", "󰖗", "󰖗"),
    65: ("Lluvia intensa", "󰖖", "󰖖"),
    66: ("Lluvia helada", "󰖖", "󰖖"),
    67: ("Lluvia helada", "󰖖", "󰖖"),
    71: ("Nieve", "󰖘", "󰖘"),
    73: ("Nieve", "󰖘", "󰖘"),
    75: ("Nieve", "󰖘", "󰖘"),
    77: ("Nieve", "󰖘", "󰖘"),
    80: ("Chaparrones", "󰖖", "󰖖"),
    81: ("Chaparrones", "󰖖", "󰖖"),
    82: ("Chaparrones", "󰖖", "󰖖"),
    85: ("Nevadas", "󰖘", "󰖘"),
    86: ("Nevadas", "󰖘", "󰖘"),
    95: ("Tormenta", "󰖓", "󰖓"),
    96: ("Tormenta con granizo", "󰙾", "󰙾"),
    99: ("Tormenta con granizo", "󰙾", "󰙾"),
}

WTTR_WMO_MAP = {
    113: 0,
    116: 2,
    119: 3,
    122: 3,
    143: 45,
    176: 61,
    179: 71,
    182: 66,
    185: 56,
    200: 95,
    227: 73,
    230: 75,
    248: 45,
    260: 48,
    263: 51,
    266: 51,
    281: 56,
    284: 57,
    293: 61,
    296: 61,
    299: 63,
    302: 63,
    305: 65,
    308: 65,
    311: 66,
    314: 67,
    317: 66,
    320: 71,
    323: 71,
    326: 71,
    329: 73,
    332: 73,
    335: 75,
    338: 75,
    350: 77,
    353: 80,
    356: 81,
    359: 82,
    362: 66,
    365: 67,
    368: 85,
    371: 86,
    374: 96,
    377: 96,
    386: 95,
    389: 95,
    392: 95,
    395: 95,
}


def map_wmo(code, is_day):
    entry = WMO_MAP.get(code)
    if entry is None:
        return "Variable", "󰖐"
    cond, day_glyph, night_glyph = entry
    return cond, (day_glyph if is_day else night_glyph)


def read_json(path):
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
        return data if isinstance(data, dict) else None
    except Exception:
        return None


def write_json_atomic(path, payload):
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        tmp = path.with_name(path.name + ".tmp")
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(payload, f, ensure_ascii=False)
            f.write("\n")
        os.replace(tmp, path)
    except Exception:
        pass


def fetch_json(url):
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
        return json.loads(resp.read().decode("utf-8"))


def load_config():
    cfg = read_json(LOCAL_CFG) or {}
    lat = cfg.get("weatherLat")
    lon = cfg.get("weatherLon")
    city = str(cfg.get("weatherCity") or "").strip()
    loc = str(cfg.get("weatherLocation") or "").strip()

    if isinstance(lat, (int, float)) and isinstance(lon, (int, float)):
        key = f"coords:{float(lat):.4f},{float(lon):.4f}:{city}"
        return {"mode": "coords", "lat": float(lat), "lon": float(lon), "city": city or "Local", "key": key}
    if loc:
        return {"mode": "location", "location": loc, "key": f"loc:{loc}"}
    return {"mode": "auto", "key": "auto"}


def resolve_geo(cfg, now):
    if cfg["mode"] == "coords":
        return cfg["lat"], cfg["lon"], cfg["city"]

    cached = read_json(GEO_CACHE)
    if (
        not FORCE
        and cached
        and cached.get("configKey") == cfg["key"]
        and (now - float(cached.get("updatedAt") or 0)) < GEO_TTL
        and isinstance(cached.get("lat"), (int, float))
        and isinstance(cached.get("lon"), (int, float))
    ):
        return float(cached["lat"]), float(cached["lon"]), str(cached.get("city") or "Local")

    lat = lon = None
    city = ""

    if cfg["mode"] == "location":
        q = urllib.parse.quote(cfg["location"])
        data = fetch_json(
            f"https://geocoding-api.open-meteo.com/v1/search?name={q}&count=1&language=es&format=json"
        )
        results = data.get("results") if isinstance(data, dict) else None
        if results and isinstance(results, list):
            first = results[0]
            lat = float(first["latitude"])
            lon = float(first["longitude"])
            city = str(first.get("name") or cfg["location"]).strip()
    else:
        try:
            data = fetch_json("https://ipwho.is/?fields=success,city,latitude,longitude")
            if isinstance(data, dict) and data.get("success") is not False:
                lat = float(data["latitude"])
                lon = float(data["longitude"])
                city = str(data.get("city") or "").strip()
        except Exception:
            lat = lon = None

        if lat is None or lon is None:
            data = fetch_json("https://get.geojs.io/v1/ip/geo.json")
            if isinstance(data, dict):
                lat = float(data["latitude"])
                lon = float(data["longitude"])
                city = str(data.get("city") or "").strip()

    if lat is None or lon is None:
        raise RuntimeError("No se pudo resolver la ubicación")

    city = city or "Local"
    write_json_atomic(
        GEO_CACHE,
        {"configKey": cfg["key"], "lat": lat, "lon": lon, "city": city, "updatedAt": now},
    )
    return lat, lon, city


def fetch_open_meteo(lat, lon, city, now):
    url = (
        f"https://api.open-meteo.com/v1/forecast?latitude={lat:.4f}&longitude={lon:.4f}"
        "&current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day,weather_code,wind_speed_10m"
        "&daily=temperature_2m_max,temperature_2m_min&timezone=auto&forecast_days=1"
    )
    data = fetch_json(url)
    cur = data["current"]
    daily = data.get("daily") or {}
    tmax = daily.get("temperature_2m_max") or [cur["temperature_2m"]]
    tmin = daily.get("temperature_2m_min") or [cur["temperature_2m"]]
    is_day = bool(int(cur.get("is_day", 1)))
    code = int(cur.get("weather_code", -1))
    cond, glyph = map_wmo(code, is_day)
    return {
        "ok": True,
        "stale": False,
        "tempC": round(float(cur["temperature_2m"])),
        "feelsLikeC": round(float(cur.get("apparent_temperature", cur["temperature_2m"]))),
        "minC": round(float(tmin[0])),
        "maxC": round(float(tmax[0])),
        "humidity": round(float(cur.get("relative_humidity_2m", 0))),
        "windKmh": round(float(cur.get("wind_speed_10m", 0))),
        "condition": cond,
        "glyph": glyph,
        "isDay": is_day,
        "city": city,
        "updatedAt": int(now),
    }


def fetch_wttr(cfg, now):
    loc = ""
    fallback_city = "Local"
    if cfg["mode"] == "location":
        loc = urllib.parse.quote(cfg["location"])
        fallback_city = cfg["location"]
    elif cfg["mode"] == "coords":
        loc = f"{cfg['lat']:.4f},{cfg['lon']:.4f}"
        fallback_city = cfg["city"]

    data = fetch_json(f"https://wttr.in/{loc}?format=j1&lang=es")
    cur = data["current_condition"][0]
    day = (data.get("weather") or [{}])[0]
    area = (data.get("nearest_area") or [{}])[0]
    area_names = area.get("areaName") or [{}]
    city = str(area_names[0].get("value") or fallback_city).strip()
    if cfg["mode"] == "coords" and cfg["city"] != "Local":
        city = cfg["city"]

    wttr_code = int(cur.get("weatherCode", -1))
    wmo_code = WTTR_WMO_MAP.get(wttr_code, -1)
    cond, glyph = map_wmo(wmo_code, True)
    lang_es = cur.get("lang_es") or []
    if lang_es and isinstance(lang_es, list) and lang_es[0].get("value"):
        cond = str(lang_es[0]["value"]).strip()

    temp_c = round(float(cur["temp_C"]))
    return {
        "ok": True,
        "stale": False,
        "tempC": temp_c,
        "feelsLikeC": round(float(cur.get("FeelsLikeC", temp_c))),
        "minC": round(float(day.get("mintempC", temp_c))),
        "maxC": round(float(day.get("maxtempC", temp_c))),
        "humidity": round(float(cur.get("humidity", 0))),
        "windKmh": round(float(cur.get("windspeedKmph", 0))),
        "condition": cond,
        "glyph": glyph,
        "isDay": True,
        "city": city,
        "updatedAt": int(now),
    }


def main():
    now = time.time()
    cfg = load_config()
    cached = read_json(WEATHER_CACHE)

    if (
        not FORCE
        and cached
        and cached.get("ok") is True
        and cached.get("configKey") == cfg["key"]
        and (now - float(cached.get("updatedAt") or 0)) < CACHE_TTL
    ):
        out = dict(cached)
        out.pop("configKey", None)
        out["stale"] = False
        print(json.dumps(out, ensure_ascii=False))
        return

    payload = None
    try:
        lat, lon, city = resolve_geo(cfg, now)
        payload = fetch_open_meteo(lat, lon, city, now)
    except Exception:
        try:
            payload = fetch_wttr(cfg, now)
        except Exception:
            payload = None

    if payload is not None:
        to_cache = dict(payload)
        to_cache["configKey"] = cfg["key"]
        write_json_atomic(WEATHER_CACHE, to_cache)
        print(json.dumps(payload, ensure_ascii=False))
        return

    if (
        cached
        and cached.get("ok") is True
        and cached.get("configKey") == cfg["key"]
        and (now - float(cached.get("updatedAt") or 0)) < STALE_TTL
    ):
        out = dict(cached)
        out.pop("configKey", None)
        out["stale"] = True
        print(json.dumps(out, ensure_ascii=False))
        return

    print(json.dumps({"ok": False, "error": "Sin conexión"}, ensure_ascii=False))


if __name__ == "__main__":
    main()
PY
