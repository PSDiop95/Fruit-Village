class_name VisualQuality
extends RefCounted
## Qualité visuelle : détection automatique (RAM + GPU) et résolution du
## réglage joueur. Réglage sauvegardé : AUTO (-1), ou JuiceConfig.Quality.

const AUTO := -1
## Seuils RAM (Go) : < LOW_RAM → Bas, < MEDIUM_RAM → Moyen, sinon Haut.
const LOW_RAM_GB := 2.6
const MEDIUM_RAM_GB := 4.5
## GPU d'entrée de gamme connus (sous-chaînes, minuscules) → Bas.
const WEAK_GPUS := ["mali-4", "mali-t6", "mali-t7", "mali-g31", "mali-g51", "mali-g52",
	"adreno (tm) 3", "adreno (tm) 4", "adreno (tm) 50", "adreno (tm) 51", "powervr", "sgx"]


## Niveau détecté pour cet appareil.
static func detect() -> int:
	var gb := float(OS.get_memory_info().get("physical", 0)) / 1073741824.0
	var gpu := RenderingServer.get_video_adapter_name().to_lower()
	return level_for(gb, gpu)


## Règle pure (testable) : RAM en Go + nom du GPU → niveau.
static func level_for(ram_gb: float, gpu_name: String) -> int:
	var gpu := gpu_name.to_lower()
	for weak in WEAK_GPUS:
		if gpu.contains(weak):
			return JuiceConfig.Quality.LOW
	if ram_gb > 0.0 and ram_gb < LOW_RAM_GB:
		return JuiceConfig.Quality.LOW
	if ram_gb > 0.0 and ram_gb < MEDIUM_RAM_GB:
		return JuiceConfig.Quality.MEDIUM
	return JuiceConfig.Quality.HIGH


## Réglage joueur (AUTO ou niveau) → niveau effectif.
static func resolve(setting: int) -> int:
	return detect() if setting == AUTO else clampi(setting, JuiceConfig.Quality.LOW, JuiceConfig.Quality.HIGH)


static func label(setting: int) -> String:
	return "Auto" if setting == AUTO else ["Bas", "Moyen", "Haut"][clampi(setting, 0, 2)]
