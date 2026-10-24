class_name VisualQuality
extends RefCounted
## Qualité visuelle : détection automatique (RAM + GPU) et résolution du
## réglage joueur. Réglage sauvegardé : AUTO (-1), ou JuiceConfig.Quality.

const AUTO := -1
## Seuils RAM (Go) : < LOW_RAM → Bas, < MEDIUM_RAM → Moyen, sinon Haut.
const LOW_RAM_GB := 2.6
const MEDIUM_RAM_GB := 4.5
## GPU d'entrée de gamme connus (sous-chaînes, minuscules) → Bas.
## Galaxy A23 (Adreno 610, 1080x2408) mesuré, panier plein : Haut 38-40 FPS,
## Moyen 45-60 FPS (instable, chauffe), Bas 62-64 FPS → Bas.
const WEAK_GPUS := ["mali-4", "mali-t6", "mali-t7", "mali-g31", "mali-g51", "mali-g52",
	"mali-g57 mc1", "adreno (tm) 3", "adreno (tm) 4", "adreno (tm) 50", "adreno (tm) 51",
	"adreno (tm) 605", "adreno (tm) 608", "adreno (tm) 610", "adreno (tm) 612",
	"adreno (tm) 613", "powervr", "sgx"]
## GPU milieu de gamme → Moyen au plus (non mesurés : par prudence).
const MID_GPUS := ["mali-g57", "mali-g68", "adreno (tm) 616", "adreno (tm) 618",
	"adreno (tm) 619"]

static var _detected: int = -2


## Niveau détecté pour cet appareil (calculé une fois).
static func detect() -> int:
	if _detected == -2:
		var gb := float(OS.get_memory_info().get("physical", 0)) / 1073741824.0
		var gpu := RenderingServer.get_video_adapter_name().to_lower()
		_detected = level_for(gb, gpu)
	return _detected


## Règle pure (testable) : RAM en Go + nom du GPU → niveau.
static func level_for(ram_gb: float, gpu_name: String) -> int:
	var gpu := gpu_name.to_lower()
	for weak in WEAK_GPUS:
		if gpu.contains(weak):
			return JuiceConfig.Quality.LOW
	if ram_gb > 0.0 and ram_gb < LOW_RAM_GB:
		return JuiceConfig.Quality.LOW
	for mid in MID_GPUS:
		if gpu.contains(mid):
			return JuiceConfig.Quality.MEDIUM
	if ram_gb > 0.0 and ram_gb < MEDIUM_RAM_GB:
		return JuiceConfig.Quality.MEDIUM
	return JuiceConfig.Quality.HIGH


## Réglage joueur (AUTO ou niveau) → niveau effectif. AUTO = détection
## (Haut sur les appareils capables, Bas/Moyen sur l'entrée de gamme).
static func resolve(setting: int) -> int:
	return detect() if setting == AUTO else clampi(setting, JuiceConfig.Quality.LOW, JuiceConfig.Quality.HIGH)


## Résolution 3D et MSAA du viewport pour un niveau (data/visual.tres).
static func apply_viewport(vp: Viewport, level: int, cfg: VisualConfig) -> void:
	if vp == null or cfg == null:
		return
	var i := clampi(level, 0, 2)
	if i < cfg.render_scale_by_quality.size():
		vp.scaling_3d_scale = cfg.render_scale_by_quality[i]
	if i < cfg.msaa_by_quality.size():
		vp.msaa_3d = cfg.msaa_by_quality[i] as Viewport.MSAA


static func label(setting: int) -> String:
	return "Auto" if setting == AUTO else ["Bas", "Moyen", "Haut"][clampi(setting, 0, 2)]
