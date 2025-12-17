extends Control

@onready var main_buttons: VBoxContainer = $MainButtons
@onready var options: Panel = $Options
@onready var chkbnt_screen_size: CheckButton = $Options/Label/chkbntScreenSize

func _ready():
	main_buttons.visible = true
	options.visible = false
	#chkbnt_screen_size.button_pressed = true

	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		chkbnt_screen_size.button_pressed = true
	else:
		chkbnt_screen_size.button_pressed = false

func _on_btn_exit_pressed() -> void:
	self.get_tree().quit()

func _on_btn_options_pressed() -> void:
	print("pressed btnOptions")
	main_buttons.visible = false
	options.visible = true

func _on_btn_start_pressed() -> void:
	var root_scene = get_node("/root/RootScene")

	if is_instance_valid(root_scene):
		if root_scene.has_method("navigate_to_maindesktop_select"):
			# 
			root_scene.navigate_to_maindesktop_select()
		else:
			print("ERROR: RootScene found, but method 'navigate_to_maindesktop_select' is missing in root_scene.gd.")
	else:
		# エラーメッセージを分かりやすく
		print("ERROR: Could not find RootScene node in the tree.")
		print("Is RootScene the main scene?")

func _on_btn_options_back_pressed() -> void:
	#_ready()
	print("pressed btnOptionsBack")
	main_buttons.visible = true
	options.visible = false
	
func _on_chkbnt_screen_size_toggled(button_pressed: bool) -> void:
	var display_server = DisplayServer
	
	if button_pressed:
		print("Setting screen to Fullscreen mode.")
		# チェックが入っている場合: フルスクリーンにする
		display_server.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		print("Setting screen to Windowed mode.")
		# チェックが外れている場合: ウィンドウモードにする
		display_server.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
