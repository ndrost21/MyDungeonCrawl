extends Control
class_name Main

## Main Scene Controller: Glues together GameManager, GridView, TouchControls, and HUD.

@onready var game_manager: GameManager = $GameManager
@onready var grid_view: GridView = $GridCenterContainer/GridView
@onready var touch_controls: TouchControls = $TouchControls
@onready var hud: HUD = $HUD


func _ready() -> void:
	grid_view.setup(game_manager)
	touch_controls.setup(game_manager)
	hud.setup(game_manager)
	game_manager.start_new_game()

