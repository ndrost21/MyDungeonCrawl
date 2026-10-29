extends Control
class_name GridView

## GridView renders the 9x9 dungeon board, entities, fog of war, and animations.
## Also supports direct tap-to-move by tapping adjacent tiles.

signal tile_clicked(direction: Vector2i)

const GRID_SIZE: int = 9

@export var cell_size: float = 72.0
@export var grid_padding: float = 4.0

var game_manager: GameManager

# Cached game state
var grid_data: Dictionary = {}
var player_pos: Vector2i = Vector2i.ZERO
var visual_player_pos: Vector2 = Vector2.ZERO
var elevator_pos: Vector2i = Vector2i.ZERO
var enemies: Array[Vector2i] = []
var explored_tiles: Dictionary = {}
var visible_tiles: Dictionary = {}

var player_tween: Tween
var pulse_time: float = 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(cell_size * GRID_SIZE, cell_size * GRID_SIZE)


func _process(delta: float) -> void:
	pulse_time += delta
	queue_redraw()


func setup(manager: GameManager) -> void:
	game_manager = manager
	game_manager.dungeon_generated.connect(_on_dungeon_generated)
	game_manager.player_moved.connect(_on_player_moved)
	game_manager.fog_updated.connect(_on_fog_updated)
	game_manager.enemy_defeated.connect(_on_enemy_defeated)
	
	if game_manager.grid_data.size() > 0:
		_on_dungeon_generated(game_manager.grid_data, game_manager.player_pos, game_manager.elevator_pos, game_manager.enemies)
		_on_fog_updated(game_manager.visible_tiles, game_manager.explored_tiles)



func _on_dungeon_generated(new_grid: Dictionary, p_pos: Vector2i, e_pos: Vector2i, new_enemies: Array[Vector2i]) -> void:
	grid_data = new_grid
	player_pos = p_pos
	visual_player_pos = Vector2(p_pos.x * cell_size, p_pos.y * cell_size)
	elevator_pos = e_pos
	enemies = new_enemies.duplicate()
	explored_tiles.clear()
	visible_tiles.clear()
	queue_redraw()


func _on_player_moved(from_pos: Vector2i, to_pos: Vector2i) -> void:
	player_pos = to_pos
	
	if player_tween and player_tween.is_valid():
		player_tween.kill()
	
	player_tween = create_tween()
	var target_pixel := Vector2(to_pos.x * cell_size, to_pos.y * cell_size)
	player_tween.tween_property(self, "visual_player_pos", target_pixel, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _on_fog_updated(p_visible: Dictionary, p_explored: Dictionary) -> void:
	visible_tiles = p_visible
	explored_tiles = p_explored
	# Sync enemies state from game manager
	if game_manager:
		enemies = game_manager.enemies.duplicate()
	queue_redraw()


func _on_enemy_defeated(_pos: Vector2i) -> void:
	if game_manager:
		enemies = game_manager.enemies.duplicate()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var local_pos: Vector2 = event.position
		var clicked_x: int = int(local_pos.x / cell_size)
		var clicked_y: int = int(local_pos.y / cell_size)
		var clicked_tile := Vector2i(clicked_x, clicked_y)
		
		# Check if in bounds
		if clicked_x >= 0 and clicked_x < GRID_SIZE and clicked_y >= 0 and clicked_y < GRID_SIZE:
			var diff := clicked_tile - player_pos
			# Cardinal adjacent tile tapped
			if abs(diff.x) + abs(diff.y) == 1:
				tile_clicked.emit(diff)
				if game_manager:
					game_manager.try_move_player(diff)


func _draw() -> void:
	var total_w := cell_size * GRID_SIZE
	var total_h := cell_size * GRID_SIZE
	
	# Background frame
	draw_rect(Rect2(0, 0, total_w, total_h), Color("#12161f"))
	draw_rect(Rect2(-3, -3, total_w + 6, total_h + 6), Color("#2d3748"), false, 3.0)
	
	# Draw tiles
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			var tile := Vector2i(x, y)
			var tile_rect := Rect2(x * cell_size + 1, y * cell_size + 1, cell_size - 2, cell_size - 2)
			var is_visible: bool = visible_tiles.has(tile)
			var is_explored: bool = explored_tiles.has(tile)
			
			if not is_explored:
				# Pitch black unexplored
				draw_rect(tile_rect, Color("#090b0e"))
				continue
			
			var tile_type = grid_data.get(tile, GameManager.TileType.FLOOR)
			
			match tile_type:
				GameManager.TileType.FLOOR:
					draw_rect(tile_rect, Color("#1f242e"))
					# Subtle floor grid stone border
					draw_rect(tile_rect, Color("#2b3240"), false, 1.0)
				
				GameManager.TileType.WALL:
					draw_rect(tile_rect, Color("#333b4a"))
					draw_rect(tile_rect, Color("#4c586e"), false, 1.5)
					# Wall brick detail
					var center := tile_rect.get_center()
					draw_line(Vector2(tile_rect.position.x + 8, center.y), Vector2(tile_rect.end.x - 8, center.y), Color("#262c38"), 2.0)
					draw_line(Vector2(center.x, tile_rect.position.y + 4), Vector2(center.x, center.y), Color("#262c38"), 2.0)
				
				GameManager.TileType.ELEVATOR:
					# Elevator floor base
					draw_rect(tile_rect, Color("#1f242e"))
					draw_rect(tile_rect, Color("#2b3240"), false, 1.0)
					
					# Elevator hatch
					var center := tile_rect.get_center()
					var hatch_radius := cell_size * 0.35
					var glow_pulse: float = (sin(pulse_time * 4.0) + 1.0) * 0.5
					var gold_color: Color = Color("#f39c12").lerp(Color("#f1c40f"), glow_pulse)
					
					draw_circle(center, hatch_radius, gold_color)
					draw_circle(center, hatch_radius * 0.8, Color("#2c1d07"))
					
					# Down arrow symbol (▼)
					var pts := PackedVector2Array([
						center + Vector2(-hatch_radius * 0.5, -hatch_radius * 0.25),
						center + Vector2(hatch_radius * 0.5, -hatch_radius * 0.25),
						center + Vector2(0, hatch_radius * 0.45)
					])
					draw_colored_polygon(pts, gold_color)
			
			# Draw Enemies (ONLY if tile is currently visible)
			if is_visible and enemies.has(tile):
				_draw_enemy(tile_rect)
			
			# Draw Fog of War Shroud if explored but NOT currently directly adjacent
			if not is_visible:
				# Dark shroud over explored memory
				draw_rect(tile_rect, Color(0.04, 0.05, 0.07, 0.78))
	
	# Draw Adventurer (Player)
	_draw_adventurer()


func _draw_enemy(rect: Rect2) -> void:
	var center := rect.get_center()
	var r := cell_size * 0.32
	
	# Red beast body
	draw_circle(center, r, Color("#c0392b"))
	draw_circle(center, r * 0.85, Color("#e74c3c"))
	
	# Horns
	var left_horn := PackedVector2Array([
		center + Vector2(-r * 0.7, -r * 0.2),
		center + Vector2(-r * 0.9, -r * 0.9),
		center + Vector2(-r * 0.2, -r * 0.6)
	])
	var right_horn := PackedVector2Array([
		center + Vector2(r * 0.7, -r * 0.2),
		center + Vector2(r * 0.9, -r * 0.9),
		center + Vector2(r * 0.2, -r * 0.6)
	])
	draw_colored_polygon(left_horn, Color("#7f1d1d"))
	draw_colored_polygon(right_horn, Color("#7f1d1d"))
	
	# Menacing yellow eyes
	draw_circle(center + Vector2(-r * 0.35, -r * 0.1), r * 0.18, Color("#f1c40f"))
	draw_circle(center + Vector2(r * 0.35, -r * 0.1), r * 0.18, Color("#f1c40f"))
	draw_circle(center + Vector2(-r * 0.35, -r * 0.1), r * 0.08, Color("#000000"))
	draw_circle(center + Vector2(r * 0.35, -r * 0.1), r * 0.08, Color("#000000"))


func _draw_adventurer() -> void:
	var center := visual_player_pos + Vector2(cell_size * 0.5, cell_size * 0.5)
	var r := cell_size * 0.36
	
	# Hero aura
	var aura_color := Color("#00adb5", 0.3)
	draw_circle(center, r * 1.25, aura_color)
	
	# Adventurer base (Armor cyan / teal)
	draw_circle(center, r, Color("#0f4c81"))
	draw_circle(center, r * 0.85, Color("#00adb5"))
	
	# Adventurer helmet / visor (gold)
	var visor_rect := Rect2(center.x - r * 0.5, center.y - r * 0.3, r, r * 0.35)
	draw_rect(visor_rect, Color("#ffd369"), true)
	
	# Hero shield / sword crest in white
	draw_circle(center + Vector2(0, r * 0.3), r * 0.2, Color("#ffffff"))
