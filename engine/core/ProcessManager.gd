# ProcessManager.gd
extends Node
class_name CF_ProcessManager

# ==============================================================================
# アプリケーションの識別情報 (一元管理)
# ==============================================================================

# アプリケーションの識別定数 (App Identifier)
enum AppID {
	TERMINAL = 1,
	FILE_EXPLORER = 2,
	NETWORK_MAP = 3,
	HTTP_CLIENT = 4,
	PROCESS_MONITOR = 5,
	# 他のアプリケーションもここに追加
}


# すべてのアプリに関するメタデータを一元化
const APP_METADATA: Dictionary = {
	AppID.TERMINAL: {
			"name": "Terminal", # ユーザーフレンドリーな名前
			"icon_path": "res://assets/icons/terminal.png", # ドック用アイコン
			"scene": preload("res://ui/AppExplorer/AppFileExplorer.tscn"), # コンテンツシーン
			"title_format": "Terminal %d", # MDIタイトルフォーマット
			"type_string": "terminal", # get_pids_by_app_type用
			"min_size": Vector2(600, 450), # 最小サイズ
		},
	AppID.FILE_EXPLORER: {
			"name": "File Explorer", # ユーザーフレンドリーな名前
			"icon_path": "res://assets/icons/terminal_icon.svg", # ドック用アイコン
			"scene": preload("res://ui/AppTerminal/AppTerminal.tscn"), # コンテンツシーン
			"title_format": "File Explorer %d", # MDIタイトルフォーマット
			"type_string": "file_explorer", # get_pids_by_app_type用
			"min_size": Vector2(600, 450), # 最小サイズ
		},
	AppID.NETWORK_MAP: {
			"name": "Network Map", # ユーザーフレンドリーな名前
			"icon_path": "res://assets/icons/terminal_icon.svg", # ドック用アイコン
			"scene": preload("res://ui/AppNetworkMap/AppNetworkMap.tscn"), # コンテンツシーン
			"title_format": "Network Map %d", # MDIタイトルフォーマット
			"type_string": "net_map", # get_pids_by_app_type用
			"min_size": Vector2(600, 450), # 最小サイズ
		},
	AppID.HTTP_CLIENT: {
			"name": "Http Client", # ユーザーフレンドリーな名前
			"icon_path": "res://assets/icons/terminal_icon.svg", # ドック用アイコン
			"scene": preload("res://ui/AppTerminal/AppTerminal.tscn"), # コンテンツシーン
			"title_format": "HTTP Client %d", # MDIタイトルフォーマット
			"type_string": "http_client", # get_pids_by_app_type用
			"min_size": Vector2(600, 450), # 最小サイズ
		},
	AppID.PROCESS_MONITOR: {
			"name": "Process Monitor", # ユーザーフレンドリーな名前
			"icon_path": "res://assets/icons/processmoni.png", # ドック用アイコン
			"scene": preload("res://ui/AppProcessMonitor/AppProcessMonitor.tscn"), # コンテンツシーン
			"title_format": "Process Monitor %d", # MDIタイトルフォーマット
			"type_string": "proc_mon", # get_pids_by_app_type用
			"min_size": Vector2(400, 300), # 最小サイズ
			"is_singleton": true, # オプション: シングルトンにしたい場合はこれを追加
		},
}

# ==============================================================================
# プロセス管理コア
# ==============================================================================

# プロセス情報格納用の配列： {pid: int, app_id: AppID, window: Window}
# windowは、MDIWindowShell.gd（Windowベース）のインスタンスを指します。
var process_array: Array = [] 

# ------------------------------------------------------------------------------
# 1. プロセスID (PID) の空き番号を検索・返却する (最小値優先)
# ------------------------------------------------------------------------------
func _get_next_available_pid() -> int:
	# 登録されているPIDのSetを作成
	var existing_pids: Dictionary = {} 
	for p_info in process_array:
		existing_pids[p_info.pid] = true
	
	# 最小の空き番号 (1から探索)
	var next_pid = 1
	while existing_pids.has(next_pid):
		next_pid += 1
		
	return next_pid

# ------------------------------------------------------------------------------
# 2. MDI起動時にデータを追加し、PIDを附番する機能
# ------------------------------------------------------------------------------
## 新しいプロセスを登録し、PIDを割り当てて返します
func register_process(app_id: int, window_instance: Control) -> int:
	if not APP_METADATA.has(app_id):
		push_error("ProcessManager: Invalid AppID %d. Registration failed." % app_id)
		return -1

	var new_pid = _get_next_available_pid()
	
	var process_info = {
		"pid": new_pid,
		"app_id": app_id, # AppID (int)を格納
		"window": window_instance # MDIウィンドウのルートノード
	}
	
	process_array.append(process_info)
	
	var app_type_string = get_app_type_string(app_id)
	print("ProcessManager: Process registered. PID: %d, Type: %s" % [new_pid, app_type_string])
	
	return new_pid

# ------------------------------------------------------------------------------
# 3. MDI終了時にデータを消去する機能
# ------------------------------------------------------------------------------
## 指定されたPIDを持つプロセスをリストから削除します
func unregister_process_by_pid(pid: int) -> bool:
	for i in range(process_array.size()):
		if process_array[i].pid == pid:
			process_array.remove_at(i)
			print("ProcessManager: Process unregistered. PID: %d" % pid)
			return true
	print("ProcessManager: Error unregistering process. PID %d not found." % pid)
	return false

# ------------------------------------------------------------------------------
# 4. プロセス番号での値取得
# ------------------------------------------------------------------------------
## 指定されたPIDを持つプロセス情報（辞書）を返します
func get_process_info_by_pid(pid: int) -> Dictionary:
	for p_info in process_array:
		if p_info.pid == pid:
			return p_info
	return {}

# ------------------------------------------------------------------------------
# 5. 起動しているアプリ種類（AppIDまたは文字列）に該当するPIDの一覧を返却
# ------------------------------------------------------------------------------
## 指定されたアプリ種類に一致する全てのPIDの配列を返します
func get_pids_by_app_type(app_type_or_id: Variant) -> Array[int]:
	var pids: Array[int] = []
	var target_app_id = -1
	
	if typeof(app_type_or_id) == TYPE_INT: # AppID (int) で検索する場合
		target_app_id = int(app_type_or_id)
	elif typeof(app_type_or_id) == TYPE_STRING: # アプリ種類名 (String) で検索する場合
		for key in APP_METADATA.keys():
			if APP_METADATA[key].type_string == app_type_or_id:
				target_app_id = key
				break
	
	if target_app_id != -1:
		for p_info in process_array:
			if p_info.app_id == target_app_id:
				pids.append(p_info.pid)
	
	return pids

# ------------------------------------------------------------------------------
# 6. アプリケーション情報取得ユーティリティ
# ------------------------------------------------------------------------------
# 新規追加: アプリケーションメタデータ全体を取得
func get_app_metadata(app_id: int) -> Dictionary:
	return APP_METADATA.get(app_id, {})

## AppIDに対応するPackedSceneを返します
func get_app_scene(app_id: int) -> PackedScene:
	# APP_METADATAを参照
	return APP_METADATA.get(app_id, {}).get("scene")

## AppIDに対応するタイトルフォーマットを返します
func get_app_title_format(app_id: int) -> String:
	# APP_METADATAを参照
	return APP_METADATA.get(app_id, {}).get("title_format", "Application %d")

## AppIDに対応するMDI最小サイズを返します。
func get_app_minimal_size(app_id: int) -> Vector2:
	# APP_METADATAを参照
	return APP_METADATA.get(app_id, {}).get("min_size", Vector2(600,450))

## 新規追加: AppIDに対応するアプリのタイプ名 (get_pids_by_app_typeやlist_processes用)を返します
func get_app_type_string(app_id: int) -> String:
	return APP_METADATA.get(app_id, {}).get("type_string", "unknown")

## 実行中のプロセス一覧を整形して文字列で返却します
func list_processes() -> String:
	var output = "PID\tTYPE\tWINDOW_TITLE\n"
	output += "---------------------------------------\n"
	
	if process_array.is_empty():
		output += "No running processes found.\n"
		return output
		
	for p_info in process_array:
		var pid = p_info.pid
		var app_id = p_info.app_id
		# APP_TYPESではなく、get_app_type_stringを使用
		var type = get_app_type_string(app_id)
		var title = ""
		
		if is_instance_valid(p_info.window):
			# windowインスタンスはMDIWindow.gdであり、titleプロパティを持っていることを想定
			title = p_info.window.get("title")
		else:
			title = "<Window Closed>"
			
		output += "%d\t%s\t%s\n" % [pid, type, title]
		
	return output

# Debug用 list_process出力
func print_List_process():
	print("###############")
	print(list_processes())
	print("###############")
