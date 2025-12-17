extends Node2D

# 修正: シーンのpreloadは全て 'const' で大文字表記に統一します
const MAIN_MENU_SCENE = preload("res://ui/MainMenu.tscn")
const MAIN_DESKTOP_SCENE = preload("res://ui/MainDesktop.tscn")

# 開いているウィンドウを管理する辞書（重複防止用）
var open_windows: Dictionary = {}

# アニメーションを制御するノード (SidebarContainerの子として追加するのがベスト)
@onready var ui_layer: CanvasLayer = $UI_Layer
@onready var ui_holder: Control = $UI_Layer/UI_Holder

var current_ui_instance: Control = null
var current_ui_scene: Control = null


func _ready():
	start_main_menu_mode()

# ----------
# ヘルパーメソッド（UI切り替えの核とするロジック）
# ----------
func get_root_scene():
	# 確実にRootSceneを取得するためのヘルパー
	return get_node("/root/RootScene")

# 追加: 既存のUIとウィンドウを全てクリーンアップする関数
func _clear_ui_and_windows():

	# 1. 古い全画面UIを削除
	if is_instance_valid(current_ui_instance):
		#print("DEBUG: [Cleanup] Clearing current_ui_instance:", current_ui_instance.name)
		current_ui_instance.queue_free()
		current_ui_instance = null
		
	# 2. 開いているMDIウィンドウを全て削除 (オープンウィンドウ辞書に基づく)
	for id in open_windows.keys():
		if is_instance_valid(open_windows[id]):
			#print("DEBUG: [Cleanup] Clearing open_windows dict entry:", id)
			open_windows[id].queue_free()
	open_windows.clear()
	
	# 3. 【強制クリーンアップ強化】UI_Layer直下の動的な子ノードをすべて解放
	if is_instance_valid(ui_layer):
		# 永続的に残すべきノードのリストを作成
		# (ui_holder, sidebar_toggle, btn_back_mission_selectはシーンツリーで定義されている)
		var persistent_nodes = [ui_holder]
		
		# get_children()の配列をコピーし、逆順に反復処理することで、
		#    ノード解放によるツリー構造の変化を安全に扱う
		var children_to_check = ui_layer.get_children().duplicate()
		
		for child in children_to_check:
			# ノードがまだ有効で、解放待ちでないことを確認
			if is_instance_valid(child) and not child.is_queued_for_deletion():
				
				# 永続ノードリストに含まれているかチェック
				if not persistent_nodes.has(child):
					# 強制解放対象のノード名を出力
					print("FATAL DEBUG: [Cleanup] FORCIBLY FREEING UNWANTED NODE:", child.name, " (Type:", child.get_class(), ")")
					child.queue_free()

	# 4. RootSceneノード(self)直下のMDIウィンドウを強制解放
	# MDIウィンドウが RootScene (self) の直下に追加された場合の対策
	var root_node = get_tree().get_root()
	var root_children = root_node.get_children().duplicate()
	
	# ルートの子ノードをすべてチェック
	for child in root_children:
		if is_instance_valid(child) and not child.is_queued_for_deletion():
			pass	
			## 永続ノード（Global, MissionManager, RootScene）ではないノードを解放
			#if child.get_name() != "Global" \
				#and child.get_name() != "MissionManager" \
				#and child.get_name() != "VFSCore" \
				#and child.get_name() != "RootScene" \
				#and child.get_name() != "MissionState"\
				#and child.get_name() != "CF_NetworkService":
				#
				## Windowノード（MDIウィンドウ）か、その他の不要なグローバルノードを解放
				#print("FATAL DEBUG: [Cleanup] FORCIBLY FREEING ROOT NODE CHILD (MDI Window):", child.name, " (Type:", child.get_class(), ")")
				#child.queue_free()

func _set_current_ui(new_ui: Control):
	# 1.古いUIを削除
	if is_instance_valid(current_ui_instance):
		current_ui_instance.queue_free()
		
	# 2.新しいUIをUI_Holderに追加
	if is_instance_valid(ui_holder):
		ui_holder.add_child(new_ui)
	else:
		print("FATAL ERROR: UI_Holder is null! Cannot add UI_Holder.")
	current_ui_instance = new_ui
	# Full Rectプリセットで親(UI_Holder)全体に広げる
	new_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	
# メインメニュー画面へ移行 (アプリ起動時や、MissionSelectUIの「戻る」ボタンから呼び出される)
func start_main_menu_mode():
	# UIとMDIウィンドウを全てクリア
	_clear_ui_and_windows()
	
	# UI_HolderにMainMenuUIをロード
	var main_menu_instance = MAIN_MENU_SCENE.instantiate()
	_set_current_ui(main_menu_instance)

# メインデスクトップ画面へ移行(MainMenuUIから呼び出される）
func navigate_to_maindesktop_select():
	# _clear_ui_and_windowsを呼び出し、クリーンアップを任せる
	_clear_ui_and_windows()
	
	# UI_HolderにMissionSelectUIをロード
	var mission_select_instance = MAIN_DESKTOP_SCENE.instantiate() 
	_set_current_ui(mission_select_instance) 
	


func open_window(window_type: String, window_title: String, mission_id: String) -> void:
	# 1. 既に開いているかチェック
	if open_windows.has(window_title):
		# 既に開いている場合は前面に移動
		var existing_window = open_windows[window_title]
		if is_instance_valid(existing_window):
			existing_window.top_level = false # MDIWindowがWindowクラスの場合、CanvasLayerの子にするときはtop_level=falseが必要
			existing_window.z_index = 100 
			existing_window.top_level = true # 再度top_level=trueにして最前面に移動
		return
	
	var content_scene: PackedScene
