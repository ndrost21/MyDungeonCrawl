extends Control
class_name TouchControls

## Touch D-Pad and Keyboard Input Controller for Dungeon Crawler
## Handles Up, Down, Left, Right, and Wait actions.

signal move_requested(direction: Vector2i)
signal wait_requested

var game_manager: GameManager


func setup(manager: GameManager) -> void:
	game_manager = manager


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	
	if event is InputEventKey:
		match event.keycode:
			KEY_UP, KEY_W:
				_on_dir_pressed(Vector2i.UP)
			KEY_DOWN, KEY_S:
				_on_dir_pressed(Vector2i.DOWN)
			KEY_LEFT, KEY_A:
				_on_dir_pressed(Vector2i.LEFT)
			KEY_RIGHT, KEY_D:
				_on_dir_pressed(Vector2i.RIGHT)
			KEY_SPACE, KEY_ENTER, KEY_PERIOD:
				_on_wait_pressed()


func _on_dir_pressed(dir: Vector2i) -> void:
	move_requested.emit(dir)
	if game_manager:
		game_manager.try_move_player(dir)


func _on_wait_pressed() -> void:
	wait_requested.emit()
	if game_manager:
		game_manager.wait_turn()


func _on_btn_up_pressed() -> void:
	_on_dir_pressed(Vector2i.UP)


func _on_btn_down_pressed() -> void:
	_on_dir_pressed(Vector2i.DOWN)


func _on_btn_left_pressed() -> void:
	_on_dir_pressed(Vector2i.LEFT)


func _on_btn_right_pressed() -> void:
	_on_dir_pressed(Vector2i.RIGHT)


func _on_btn_wait_pressed() -> void:
	_on_wait_pressed()
