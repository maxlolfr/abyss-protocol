class_name AbyssSession
## Passage de relais entre la campagne (géoscape) et le combat tactique (main.tscn), dans le même lancement.

const CAMPAIGN_SAVE := "user://abyss_campaign.json"
const STRATEGY_SCENE := "res://view/strategy/strategy.tscn"
const BATTLE_SCENE := "res://view/main.tscn"

static var mission := {} # configuration du combat lancé depuis la campagne (AbyssCampaign.mission_config)
static var result := {} # bilan du combat à appliquer au retour (AbyssBattle.result)
static var skirmish := false # mission Némésis seule, hors campagne

static func save_campaign(c: AbyssCampaign) -> void:
	var f := FileAccess.open(CAMPAIGN_SAVE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(c.to_dict()))

static func load_campaign() -> AbyssCampaign:
	if not FileAccess.file_exists(CAMPAIGN_SAVE):
		return null
	var d = JSON.parse_string(FileAccess.get_file_as_string(CAMPAIGN_SAVE))
	return AbyssCampaign.from_dict(d) if d is Dictionary else null

static func clear_campaign() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CAMPAIGN_SAVE))
