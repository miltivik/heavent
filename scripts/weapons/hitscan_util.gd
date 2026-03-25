extends RefCounted
class_name HitscanUtil

## =============================================================================
## HITSCAN UTILITY — HEAVENT
## Reusable raycast-based hitscan for weapons.
## Uses PhysicsDirectSpaceState3D for immediate raycast queries.
## =============================================================================

## Result of a hitscan query.
## {
##   hit: bool,
##   collider: Node3D or null,
##   point: Vector3,
##   normal: Vector3,
##   distance: float,
##   rid: RID
## }


## Perform a single hitscan ray from origin along direction.
## Returns a Dictionary with hit data.
static func cast(
	world: World3D,
	origin: Vector3,
	direction: Vector3,
	max_distance: float = 200.0,
	collision_mask: int = 0xFFFFFFFF,
	exclude: Array[RID] = []
) -> Dictionary:
	var space_state := world.direct_space_state
	if not space_state:
		return _empty_result(origin, direction, max_distance)

	var end := origin + direction.normalized() * max_distance

	var query := PhysicsRayQueryParameters3D.new()
	query.from = origin
	query.to = end
	query.collision_mask = collision_mask
	query.exclude = exclude
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var result := space_state.intersect_ray(query)

	if result.is_empty():
		return _empty_result(origin, direction, max_distance)

	return {
		"hit": true,
		"collider": result["collider"],
		"point": result["position"],
		"normal": result["normal"],
		"distance": origin.distance_to(result["position"]),
		"rid": result["rid"]
	}


## Perform a hitscan that bounces off surfaces (for ricochet).
## Returns an Array of hit Dictionaries (one per bounce + initial).
static func cast_ricochet(
	world: World3D,
	origin: Vector3,
	direction: Vector3,
	max_distance: float = 200.0,
	max_bounces: int = 2,
	collision_mask: int = 0xFFFFFFFF,
	exclude: Array[RID] = [],
	damage_falloff_per_bounce: float = 0.8
) -> Array[Dictionary]:
	var hits: Array[Dictionary] = []
	var current_origin := origin
	var current_direction := direction.normalized()
	var remaining_distance := max_distance
	var current_damage_mult := 1.0

	for i in range(max_bounces + 1):
		var hit := cast(world, current_origin, current_direction, remaining_distance, collision_mask, exclude)
		hit["damage_multiplier"] = current_damage_mult
		hit["bounce_index"] = i
		hits.append(hit)

		if not hit["hit"]:
			break

		# Prepare next bounce
		remaining_distance -= hit["distance"]
		if remaining_distance <= 0.0:
			break

		current_origin = hit["point"] + hit["normal"] * 0.01  # offset to avoid self-hit
		current_direction = current_direction.bounce(hit["normal"])
		current_damage_mult *= damage_falloff_per_bounce

	return hits


## Build an empty (miss) result.
static func _empty_result(origin: Vector3, direction: Vector3, max_distance: float) -> Dictionary:
	return {
		"hit": false,
		"collider": null,
		"point": origin + direction.normalized() * max_distance,
		"normal": Vector3.ZERO,
		"distance": max_distance,
		"rid": RID()
	}
