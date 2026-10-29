extends Control
class_name HUD

## HUD Manager: Handles health, steps, status messages, and Win/Defeat modals.

signal restart_requested(next_floor: bool)

@onready var label_floor: Label = $TopBar/MarginContainer/HBoxContainer/VBoxLeft/LabelFloor
@onready var label_hp: Label = $TopBar/MarginContainer/HBoxContainer/VBoxLeft/LabelHP
@onready var label_steps: Label = $TopBar/MarginContainer/HBoxContainer/VBoxRight/LabelSteps
@onready var label_message: Label = $TopBar/MarginContainer/HBoxContainer/VBoxCenter/LabelMessage

@onready var victory_panel: Control = $Modals/VictoryPanel
@onready var defeat_panel: Control = $Modals/DefeatPanel
@onready var victory_summary: Label = $Modals/VictoryPanel/VBox/LabelSummary
@onready var defeat_summary: Label = $Modals/DefeatPanel/VBox/LabelSummary

var game_manager: GameManager


func setup(manager: GameManager) -> void:
	game_manager = manager
	game_manager.player_hp_changed.connect(_on_hp_changed)
	game_manager.steps_changed.connect(_on_steps_changed)
	game_manager.message_logged.connect(_on_message_logged)
	game_manager.game_won.connect(_on_game_won)
	game_manager.game_over.connect(_on_game_over)
	
	victory_panel.visible = false
	defeat_panel.visible = false


func _on_hp_changed(current_hp: int, max_hp: int) -> void:
	var hearts: String = ""
	for i in range(max_hp):
		if i < current_hp:
			hearts += "❤️ "
		else:
			hearts += "🖤 "
	label_hp.text = "HP: " + hearts.strip_edges()


func _on_steps_changed(step_count: int) -> void:
	label_steps.text = "Steps: %d" % step_count


func _on_message_logged(text: String) -> void:
	label_message.text = text
	if game_manager:
		label_floor.text = "Floor %d" % game_manager.floor_number


func _on_game_won() -> void:
	if game_manager:
		victory_summary.text = "You cleared Floor %d in %d steps!" % [game_manager.floor_number, game_manager.steps]
	victory_panel.visible = true


func _on_game_over() -> void:
	if game_manager:
		defeat_summary.text = "Fell on Floor %d after %d steps." % [game_manager.floor_number, game_manager.steps]
	defeat_panel.visible = true


func _on_btn_restart_pressed() -> void:
	victory_panel.visible = false
	defeat_panel.visible = false
	restart_requested.emit(false)
	if game_manager:
		game_manager.start_new_game(false)


func _on_btn_next_floor_pressed() -> void:
	victory_panel.visible = false
	defeat_panel.visible = false
	restart_requested.emit(true)
	if game_manager:
		game_manager.start_new_game(true)
