# ProcessManager.gd
extends Node
class_name ProcessManager

# ==============================================================================
# アプリケーションの識別情報 (一元管理)
# ==============================================================================

# アプリケーションの識別定数 (App Identifier)
enum AppID {
	TERMINAL = 1,
	FILE_EXPLORER = 2,
	NETWORK_MAP = 3,
	HTTP_CLIENT = 4,
	# 他のアプリケーションもここに追加
}

# AppIDに対応するコンテンツシーンのパス (PackedSceneとしてプリロード)
# MDIWindowShellのContentContainerにロードされるアプリの中身です。
const APP_SCENES: Dictionary = {
	AppID.TERMINAL: preload("res://ui/AppTerminal/AppTerminal.tscn")
	#AppID.FILE_EXPLORER: preload("res://scenes/windows/file_explorer_ui.tscn"), # 存在すると仮定
	# AppID.NETWORK_MAP: preload("res://ui/NetworkMapUI/NetworkMapUI.tscn"),
	# AppID.HTTP_CLIENT: preload("res://ui/HttpClient/HttpClientUI.tscn"),
}

# AppIDに対応する初期タイトルフォーマット
# %d は MDI Managerから渡されるプロセスID (PID) でフォーマットされます
const APP_TITLES: Dictionary = {
	AppID.TERMINAL: "Terminal %d", 
	AppID.FILE_EXPLORER: "File Explorer %d",
	AppID.NETWORK_MAP: "Network Map %d",
	AppID.HTTP_CLIENT: "HTTP Client %d",
}

# AppIDに対応するアプリのタイプ名 (get_pids_by_app_typeやlist_processes用)
const APP_TYPES: Dictionary = {
	AppID.TERMINAL: "terminal", 
	AppID.FILE_EXPLORER: "file_explorer",
	AppID.NETWORK_MAP: "net_map",
	AppID.HTTP_CLIENT: "http_client",
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
func register_process(app_id: int, window_instance: Window) -> int:
	if not APP_SCENES.has(app_id):
		push_error("ProcessManager: Invalid AppID %d. Registration failed." % app_id)
		return -1

	var new_pid = _get_next_available_pid()
	
	var process_info = {
		"pid": new_pid,
		"app_id": app_id, # AppID (int)を格納
		"window": window_instance # MDIウィンドウのルートノード
	}
	
	process_array.append(process_info)
	
	var app_type_string = APP_TYPES.get(app_id, "unknown")
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
			CL_ProcessManager.print_List_process()
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
		# 文字列からAppIDを逆引き
		for key in APP_TYPES.keys():
			if APP_TYPES[key] == app_type_or_id:
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
## AppIDに対応するPackedSceneを返します
func get_app_scene(app_id: int) -> PackedScene:
	return APP_SCENES.get(app_id)

## AppIDに対応するタイトルフォーマットを返します
func get_app_title_format(app_id: int) -> String:
	return APP_TITLES.get(app_id, "Application %d")

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
		var type = APP_TYPES.get(app_id, "unknown") # AppIDからタイプ名を取得
		var title = ""
		
		if is_instance_valid(p_info.window):
			title = p_info.window.title 
		else:
			title = "<Window Closed>"
			
		output += "%d\t%s\t%s\n" % [pid, type, title]
		
	return output
