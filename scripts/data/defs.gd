class_name Defs
## Single source of truth for unit numbers (Fase 1 spec). Change numbers only here.

const HERO_ORDER: Array[String] = ["brenna", "yara", "orin", "kess"]
const GOBLIN_ORDER: Array[String] = ["rastejante", "rastejante", "bruto", "fundeiro", "fundeiro"]

# PLACEHOLDER TEMPORÁRIO — substituído pela arte final da Muse.
# `color`/`accent` are the identity colors used by the geometric placeholders and card portraits.
const HEROES := {
	"brenna": {
		"name": "Brenna", "title": "Brenna, a Guardiã", "role": "Tanque", "rarity": "Comum",
		"hp": 320.0, "damage": 9.0, "cooldown": 1.1, "speed": 90.0, "range": 0.0,
		"radius": 20.0, "brain": "muralha",
		"color": Color("b01e36"), "accent": Color("a3acb5"),
	},
	"yara": {
		"name": "Yara", "title": "Yara, a Arqueira", "role": "Atiradora", "rarity": "Comum",
		"hp": 80.0, "damage": 13.0, "cooldown": 1.3, "speed": 100.0, "range": 320.0,
		"radius": 16.0, "brain": "paciencia",
		"color": Color("5c7a36"), "accent": Color("6e4a2a"),
	},
	"orin": {
		"name": "Orin", "title": "Orin, o Oráculo", "role": "Suporte", "rarity": "Comum",
		"hp": 80.0, "damage": 8.0, "cooldown": 1.4, "speed": 85.0, "range": 280.0,
		"heal": 18.0, "heal_cooldown": 1.6,
		"radius": 16.0, "brain": "triagem",
		"color": Color("2c5cc0"), "accent": Color("dcb23c"),
	},
	"kess": {
		"name": "Kess", "title": "Kess, a Duelista", "role": "Assassina", "rarity": "Comum",
		"hp": 110.0, "damage": 18.0, "cooldown": 1.7, "speed": 130.0, "range": 0.0,
		"radius": 16.0, "brain": "oportunista",
		"color": Color("5e3a80"), "accent": Color("141016"),
	},
}

# PLACEHOLDER TEMPORÁRIO — substituído pela arte final da Muse.
const GOBLINS := {
	"rastejante": {
		"name": "Rastejante", "hp": 126.0, "damage": 7.0, "cooldown": 1.5, "speed": 95.0,
		"range": 0.0, "radius": 14.0, "brain": "rastejante",
		"color": Color("8f923a"), "accent": Color("3a3b16"),
	},
	"fundeiro": {
		"name": "Fundeiro", "hp": 109.0, "damage": 10.0, "cooldown": 1.88, "speed": 85.0,
		"range": 260.0, "radius": 13.0, "brain": "fundeiro",
		"color": Color("b9a447"), "accent": Color("4a3f17"),
	},
	"bruto": {
		"name": "Bruto", "hp": 368.0, "damage": 18.0, "cooldown": 2.87, "speed": 60.0,
		"range": 0.0, "radius": 24.0, "brain": "bruto",
		"color": Color("767c2a"), "accent": Color("2c2e10"),
	},
}

## FOCAR (the player's only direct action).
const FOCUS_DURATION := 6.0
const FOCUS_COOLDOWN := 12.0
const FOCUS_HEAL_THRESHOLD := 0.30

## Hits at or above this damage shake the screen and trigger hit-stop.
const HEAVY_HIT := 18.0
