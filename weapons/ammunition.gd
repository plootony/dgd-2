extends RefCounted
## Inventory belongs to the local player, independently of the viewmodel and selected slot.
const Catalog = preload("res://weapons/weapon_catalog.gd")
var magazines: Array[int] = []
var reserves: Array[int] = []
var reload_slot: int = -1


func _init() -> void:
	reset()


func reset() -> void:
	magazines.clear()
	reserves.clear()
	for definition in Catalog.DEFINITIONS:
		magazines.append(definition.magazine_size)
		reserves.append(definition.starting_reserve)
	reload_slot = -1


func consume(slot: int) -> bool:
	if reload_slot >= 0 or magazines[slot] <= 0:
		return false
	magazines[slot] -= 1
	return true


func begin_reload(slot: int) -> bool:
	if (
		reload_slot >= 0
		or reserves[slot] <= 0
		or magazines[slot] >= Catalog.DEFINITIONS[slot].magazine_size
	):
		return false
	reload_slot = slot
	return true


func finish_reload() -> void:
	if reload_slot < 0:
		return
	var amount = mini(
		Catalog.DEFINITIONS[reload_slot].magazine_size - magazines[reload_slot],
		reserves[reload_slot]
	)
	magazines[reload_slot] += amount
	reserves[reload_slot] -= amount
	reload_slot = -1


func cancel_reload() -> void:
	reload_slot = -1
