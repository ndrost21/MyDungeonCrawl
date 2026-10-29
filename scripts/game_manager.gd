extends Node
class_name GameManager

## Core Game Manager for 9x9 Dungeon Crawler
## Handles grid state, turn cycles, BFS path validation, combat, fog of war, and win conditions.

signal dungeon_generated(grid_data: Dictionary, player_pos: Vector2i, elevator_pos: Vector2i, enemies: Array[Vector2i])
signal player_moved(from_pos: Vector2i, to_pos: Vector2i)
signal player_hp_changed(current_hp: int, max_hp: int)
signal steps_changed(step_count: int)
signal fog_updated(visible_tiles: Dictionary, explored_tiles: Dictionary)
signal enemy_defeated(pos: Vector2i)
signal message_logged(text: String)
signal game_won
signal game_over

enum TileType {
	FLOOR,
	WALL,
	ELEVATOR
}

const GRID_SIZE: int = 9
const MAX_HP: int = 3
const NUM_ENEMIES: int = 3
const NUM_WALL_OBSTACLES: int = 9

var grid_data: Dictionary = {} # Vector2i -> TileType
var player_pos: Vector2i = Vector2i.ZERO
var elevator_pos: Vector2i = Vector2i.ZERO
var enemies: Array[Vector2i] = []

var explored_tiles: Dictionary = {} # Vector2i -> bool
var visible_tiles: Dictionary = {}  # Vector2i -> bool

var player_hp: int = MAX_HP
var steps: int = 0
var floor_number: int = 1
var is_game_active: bool = false


func _ready() -> void:
	pass



func start_new_game(advance_floor: bool = false) -> void:
	if advance_floor:
		floor_number += 1
		# Heal 1 HP on new floor
		player_hp = mini(player_hp + 1, MAX_HP)
	else:
		floor_number = 1
		player_hp = MAX_HP
		steps = 0
	
	is_game_active = true
	generate_dungeon()
	update_fog()
	
	player_hp_changed.emit(player_hp, MAX_HP)
	steps_changed.emit(steps)
	message_logged.emit("Floor %d: Find the elevator down!" % floor_number)


func is_in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < GRID_SIZE and pos.y >= 0 and pos.y < GRID_SIZE


func generate_dungeon() -> void:
	var success: bool = false
	var attempts: int = 0
	
	while not success and attempts < 100:
		attempts += 1
		grid_data.clear()
		explored_tiles.clear()
		visible_tiles.clear()
		enemies.clear()
		
		# 1. Fill 9x9 with floor
		for x in range(GRID_SIZE):
			for y in range(GRID_SIZE):
				grid_data[Vector2i(x, y)] = TileType.FLOOR
		
		# 2. Pick Player start position (e.g. near bottom-left corner)
		player_pos = Vector2i(randi_range(0, 2), randi_range(6, 8))
		
		# 3. Pick Elevator position far from player (e.g. near top-right corner)
		elevator_pos = Vector2i(randi_range(6, 8), randi_range(0, 2))
		grid_data[elevator_pos] = TileType.ELEVATOR
		
		# 4. Add scattered wall obstacles
		var placed_walls: int = 0
		var wall_candidates: Array[Vector2i] = []
		for x in range(GRID_SIZE):
			for y in range(GRID_SIZE):
				var p := Vector2i(x, y)
				if p != player_pos and p != elevator_pos:
					wall_candidates.append(p)
		
		wall_candidates.shuffle()
		for p in wall_candidates:
			if placed_walls >= NUM_WALL_OBSTACLES:
				break
			# Don't wall off player's direct neighbors immediately
			if (p - player_pos).length() <= 1.5:
				continue
			grid_data[p] = TileType.WALL
			placed_walls += 1
		
		# 5. Verify BFS path exists from player to elevator
		if not has_path(player_pos, elevator_pos):
			continue
		
		# 6. Place enemies on empty floor tiles not adjacent to player
		var enemy_candidates: Array[Vector2i] = []
		for x in range(GRID_SIZE):
			for y in range(GRID_SIZE):
				var p := Vector2i(x, y)
				if grid_data[p] == TileType.FLOOR and p != player_pos and p != elevator_pos:
					# At least 2 tiles distance from player at spawn
					if (p - player_pos).length() > 2.0:
						enemy_candidates.append(p)
		
		enemy_candidates.shuffle()
		for i in range(mini(NUM_ENEMIES, enemy_candidates.size())):
			enemies.append(enemy_candidates[i])
		
		success = true
	
	dungeon_generated.emit(grid_data, player_pos, elevator_pos, enemies)


## Breadth-first search to ensure path exists from start to target
func has_path(start: Vector2i, target: Vector2i) -> bool:
	var queue: Array[Vector2i] = [start]
	var visited: Dictionary = {start: true}
	var dirs: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	
	while queue.size() > 0:
		var current: Vector2i = queue.pop_front()
		if current == target:
			return true
		
		for d in dirs:
			var neighbor: Vector2i = current + d
			if is_in_bounds(neighbor) and not visited.has(neighbor):
				if grid_data[neighbor] != TileType.WALL:
					visited[neighbor] = true
					queue.append(neighbor)
	
	return false


## Try moving the player in the given direction
func try_move_player(direction: Vector2i) -> bool:
	if not is_game_active:
		return false
	
	var target_pos: Vector2i = player_pos + direction
	if not is_in_bounds(target_pos):
		message_logged.emit("You bump into the dungeon edge.")
		return false
	
	# Check for wall
	if grid_data.get(target_pos, TileType.FLOOR) == TileType.WALL:
		message_logged.emit("A stone wall blocks your path.")
		return false
	
	# Check for enemy on target tile (Player attacks!)
	var enemy_idx: int = enemies.find(target_pos)
	if enemy_idx != -1:
		# Combat resolution: Defeat enemy, but take 1 damage
		enemies.remove_at(enemy_idx)
		enemy_defeated.emit(target_pos)
		player_hp -= 1
		player_hp_changed.emit(player_hp, MAX_HP)
		message_logged.emit("You strike down the beast, but take 1 damage!")
		
		steps += 1
		steps_changed.emit(steps)
		
		if player_hp <= 0:
			trigger_game_over()
			return true
		
		# After defeating enemy, process remaining enemies turn
		process_enemy_turns()
		return true
	
	# Regular move
	var old_pos: Vector2i = player_pos
	player_pos = target_pos
	steps += 1
	steps_changed.emit(steps)
	player_moved.emit(old_pos, player_pos)
	
	# Check win condition (Elevator reached)
	if player_pos == elevator_pos:
		update_fog()
		trigger_game_won()
		return true
	
	update_fog()
	process_enemy_turns()
	return true


## Wait a turn in place (enemies move/react)
func wait_turn() -> void:
	if not is_game_active:
		return
	steps += 1
	steps_changed.emit(steps)
	message_logged.emit("You pause and catch your breath...")
	process_enemy_turns()


## Update Fog of War (Tiles directly next to adventurer are visible)
func update_fog() -> void:
	visible_tiles.clear()
	
	# Radius 1: 3x3 surrounding player
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var tile: Vector2i = player_pos + Vector2i(dx, dy)
			if is_in_bounds(tile):
				visible_tiles[tile] = true
				explored_tiles[tile] = true
	
	fog_updated.emit(visible_tiles, explored_tiles)


## Enemy AI turn: If adjacent to player, attack; otherwise wander or stand guard
func process_enemy_turns() -> void:
	if not is_game_active:
		return
	
	var cardinal_dirs: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	
	for i in range(enemies.size()):
		var enemy_pos: Vector2i = enemies[i]
		
		# If enemy is directly adjacent to player (Manhattan distance == 1)
		var diff: Vector2i = player_pos - enemy_pos
		if abs(diff.x) + abs(diff.y) == 1:
			# Enemy attacks player!
			player_hp -= 1
			player_hp_changed.emit(player_hp, MAX_HP)
			message_logged.emit("A monster strikes you for 1 damage!")
			
			if player_hp <= 0:
				trigger_game_over()
				return
			continue
		
		# Wander chance (40% chance to move to an adjacent free floor tile)
		if randf() < 0.4:
			cardinal_dirs.shuffle()
			for d in cardinal_dirs:
				var candidate: Vector2i = enemy_pos + d
				if is_in_bounds(candidate) and candidate != player_pos and candidate != elevator_pos:
					if grid_data.get(candidate, TileType.WALL) == TileType.FLOOR and not enemies.has(candidate):
						enemies[i] = candidate
						break


func trigger_game_won() -> void:
	is_game_active = false
	message_logged.emit("You reached the elevator down! VICTORY!")
	game_won.emit()


func trigger_game_over() -> void:
	is_game_active = false
	message_logged.emit("You have fallen in the dungeon...")
	game_over.emit()
