# res://ui/main_desktop.gd
extends Control
class_name MainDesktop

# ApplicationManagerに処理を委譲するため、MDIウィンドウ関連のプリロードは不要になります
@onready var desktop_container: Control = $Desktop 
@onready var task_bar_container: HBoxContainer = $TaskBar
@onready var dock_container: HBoxContainer = $TaskBar/DockContainer

## 画面ロード時 (Godotの組み込み関数)
func _ready():
	add_to_group("main_desktop")
	# ApplicationManager Autoloadの確認
	if not is_instance_valid(CL_ApplicationManager) or not is_instance_valid(CL_ProcessManager):
		push_error("ApplicationManager or ProcessManager Autoload is missing. Cannot proceed.")
		return
		
	# 1. デバッグ用の初期ミッションをロード
	var report = MissionLoader.load_mission("res://missions/sample_mission.json")
	
	if report.valid:
		if report.warnd:
			for warn in report.warns:
				print("Validation Warning: ", warn.to_debug_string())
		print("Mission loaded successfully.")
		
		# ドックセットアップ呼び出し
		_setup_dock()
		
		# 2. 初期アプリケーション (ターミナル) を起動
		# アプリIDを直接渡し、ApplicationManagerに委譲します
		#_launch_app(ProcessManager.AppID.TERMINAL)
	else:
		# エラーウィンドウを表示 (未実装)
		print("Mission loading failed: ", report.errors)
		for error in report.errors:
			print("Validation Error: ", error.to_debug_string())
		push_error("Mission environment could not be set up.")
		if report.warnd:
			for warn in report.warns:
				print("Validation Warning: ", warn.to_debug_string())

# --- ドック/タスクバー関連の関数 ---

func _setup_dock():
	# ProcessManagerから全てのアプリ定義を取得 (APP_METADATAを参照)
	var all_applications = CL_ProcessManager.APP_METADATA
	
	# 1. MissionLoaderから許可されたアプリのリストを取得
	var mission_apps = MissionLoader.current_mission_json.get("allowed_apps", [])
	
	var apps_to_display = {}
	
	if mission_apps.is_empty():
		# 指定がない場合、ProcessManagerで定義された全てのアプリを表示
		apps_to_display = all_applications
		# print("DEBUG DOCK: Displaying all available applications.")
	else:
		# 指定されたアプリのみを表示
		for app_id_str in mission_apps:
			var id = int(app_id_str)
			if all_applications.has(id):
				apps_to_display[id] = all_applications[id]
		# print("DEBUG DOCK: Displaying mission-specific applications: %s" % apps_to_display.keys())
		
	# 2. 決定したリストに基づいてボタンを生成
	for app_id in apps_to_display:
		var app_data = apps_to_display[app_id]
		# キーである AppID を明示的に渡す
		_create_dock_button(app_id, app_data)


## ドックボタンの生成
func _create_dock_button(app_id: int, app_data: Dictionary):
	var button = Button.new()
	button.name = app_data.name + "Launcher"
	
	# ProcessManagerから取得した "name", "icon_path" を使用
	button.text = app_data.name
	button.custom_minimum_size = Vector2(50, 50) 
	
	# アイコンを設定
	if FileAccess.file_exists(app_data.icon_path):
		var texture = load(app_data.icon_path)
		if texture is Texture2D:
			button.icon = texture
			button.text = "" 
			
	# 起動用シグナルの接続: AppIDを引数としてバインド
	button.pressed.connect(_on_dock_button_pressed.bind(app_id))
	
	task_bar_container.add_child(button)

## ドックボタンが押されたときに呼ばれる (app_idを引数として受け取る)
func _on_dock_button_pressed(app_id: int):
	var app_meta = CL_ProcessManager.get_app_metadata(app_id)
	var app_name = app_meta.get("name", "Unknown App")
	print("DEBUG DOCK: Launching App ID %d: %s" % [app_id, app_name])
	_launch_app(app_id)

## アプリケーションを起動し、ApplicationManagerに処理を委譲する
## MainDesktopの唯一の責務は、初期データ（IPやユーザー名など）を集めて渡すことになります。
## @param app_id: ProcessManager.AppID enumの識別定数
func _launch_app(app_id: int) -> int:
	
	# 2. ApplicationManagerに起動処理を委譲
	# 起動、タイトル設定、ProcessManagerへの登録、シーンツリーへの追加は全てApplicationManagerが行います。
	var pid = CL_ApplicationManager.launch_application(app_id)
	
	if pid == -1:
		push_error("Failed to launch application with AppID %d." % app_id)
		return -1
	
	return pid

## タスクバーやアイコンからの起動を処理する (後で実装)
func _on_launcher_pressed(app_name: String):
	var app_id = -1 # 仮のAppID
	
	# 文字列からAppIDへのマッピング
	match app_name:
		"terminal":
			app_id = ProcessManager.AppID.TERMINAL
		"file_explorer":
			# NOTE: ProcessManager.AppID.FILE_EXPLORER の定義を仮定
			# app_id = ProcessManager.AppID.FILE_EXPLORER 
			push_error("File Explorer launch not fully implemented.")
			return
		_:
			push_error("Unknown application name: %s" % app_name)
			return

	if app_id != -1:
		_launch_app(app_id)
