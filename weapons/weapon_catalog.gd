extends RefCounted
## Slot order is part of the network protocol. Keep it identical on every peer.

const DEFINITIONS = [
	preload("res://weapons/definitions/ak74u.tres"),
	preload("res://weapons/definitions/beretta.tres"),
]


static func is_valid_slot(slot: int) -> bool:
	return slot >= 0 and slot < DEFINITIONS.size()
