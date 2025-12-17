# ApplicationManager.gd
extends Node
class_name ApplicationManager

# MDI画面のベースとなるWindowクラスのシーンをプリロードします。
# ユーザーのファイルから、mdi_window.tscn（Windowノードがルート）を指していると仮定します。
#const MDI_WINDOW_SCENE = preload("res://ui/mdi/mdi_window.tscn")
const MDI_WINDOW_PATH = "res://ui/mdi/mdi_window.tscn"

# AutoLoadされたProcessManagerへの参照 (名前を合わせてください)
var process_manager = CL_ProcessManager 

# --- 内部状態 ---
# 開いているMDIウィンドウのリスト (ProcessManagerの配列とは別に、Controlノード自体を管理する目的で持つこともできます)
var open_windows: Array[Control] = [] 

# ==============================================================================
# 1. アプリケーション起動機能 (ApplicationManagerの主要な責務)
# ==============================================================================

## MainDesktopなどから呼ばれる、アプリケーション起動指示
## @param app_id: ProcessManager.AppID enumの識別定数
## @param initial_data: アプリケーションに渡す初期データ（例: Terminalの場合はVFSなど）
func launch_application(app_id: int) -> int:

	if not process_manager:
		push_error("ProcessManager AutoLoad is not available.")
		return -1

	# シーンのロードを遅延させる(Godot起動ときのリソース競合を避ける）

	var mdi_window_scene = load(MDI_WINDOW_PATH)
	if not mdi_window_scene:
		push_error("ApplicationManager: Failed to load MDI window scene: %s" % MDI_WINDOW_PATH)
		return -1
	# 1. PIDの取得とプロセス登録
	# ProcessManagerにMDIウィンドウのインスタンス（Node）を渡す必要があるため、
	# ここでは先にMDIウィンドウをインスタンス化します。
	#var new_mdi_window: Window = MDI_WINDOW_SCENE.instantiate()
	#return -1
	var new_mdi_window: Control = mdi_window_scene.instantiate()

	# 登録。ProcessManagerがPIDを附番し、管理配列に追加します。
	var pid = process_manager.register_process(app_id, new_mdi_window)
	
	if pid == -1:
		new_mdi_window.queue_free()
		return -1

	# 2. MDI画面の初期化と注入（ProcessManagerから情報取得）
	var content_scene = process_manager.get_app_scene(app_id)
	var mdi_minimal_size = process_manager.get_app_minimal_size(app_id)
	var title_format = process_manager.get_app_title_format(app_id)
	var window_title = title_format % pid
	
	if not is_instance_valid(content_scene):
		push_error("ApplicationManager: Content scene not found for AppID %d" % app_id)
		# 登録解除とウィンドウ削除
		process_manager.unregister_process_by_pid(pid)
		new_mdi_window.queue_free()
		return -1

	# MDI画面のベースとなるWindowクラス（mdi_window.gd）が持つ初期化関数を呼び出す
	if new_mdi_window.has_method("initialize"):
		# MDI画面（mdi_window.gd）に、タイトル、コンテンツ、PIDを渡します。
		# MDIウィンドウ側は、このPIDを終了時に使用します。
		new_mdi_window.initialize(window_title, content_scene, mdi_minimal_size, pid)
	else:
		push_error("MDI_WINDOW_SCENE does not have an 'initialize' method.")

	# 3. MDI画面の配置とシーンツリーへの追加
	var main_desktop_node = get_tree().get_first_node_in_group("main_desktop")
	#GlEnv.print_node_struct("mdi-add after", get_tree().get_root())

	#GlEnv.print_node_struct("mae", get_tree().get_root())
	if is_instance_valid(main_desktop_node):
		# MainDesktopの子ノード $Desktop にMDIウィンドウを追加
		main_desktop_node.get_node("Desktop").add_child(new_mdi_window)
	else:
		# デスクトップノードが見つからない場合はルートに追加する
		get_tree().get_root().add_child(new_mdi_window)	
	#GlEnv.print_node_struct("ato", get_tree().get_root())
	
	
	# MDI画面（Windowクラス）のpositionやsizeの初期設定は、
	# MDIウィンドウ側、またはMDIマネージャー側で行うべきですが、ここでは簡易的に。
	# new_mdi_window.set_initial_position_and_size() 
	
	open_windows.append(new_mdi_window)
	print("ApplicationManager: Launched App ID %d with PID %d." % [app_id, pid])
	
	return pid

# ==============================================================================
# 2. MDI画面終了時のプロセス登録解除
# ==============================================================================

## MDI画面からシグナルで呼ばれる、ウィンドウ終了処理
## @param pid: 終了するMDIウィンドウが保持していたプロセスID
func close_application_by_pid(pid: int):
	# 1. ProcessManagerから登録を解除
	var success = process_manager.unregister_process_by_pid(pid)
	
	if success:
		# 2. open_windowsリストからControlノードを削除し、queue_free()で消去
		var target_window = null
		var target_index = -1
		
		# ProcessManagerから取得したウィンドウインスタンスをリストから探す
		# ★ 修正: open_windowsリストを走査し、ノードの有効性もチェック
		for i in range(open_windows.size()):
			var window = open_windows[i]
			
			# is_instance_validでインスタンスが有効かチェック
			# 💡 window.process_pid (mdi_base_windowの変数) を直接参照する方が、
			# get_meta() よりコードが明確になります。（get_meta()はエラーの原因になりやすいため）
			if is_instance_valid(window) and window.process_pid == pid: 
				target_window = window
				target_index = i
				break
				
		if target_window:
			open_windows.remove_at(target_index)
			# ★ 修正: リストからの削除が成功した後、ここでノードを解放します。
			target_window.queue_free() 
			print("ApplicationManager: Closed PID %d." % pid)
		else:
			# この警告が出た場合、論理エラーの可能性あり
			print("ApplicationManager: Warning - Window node for PID %d not found in open_windows list." % pid)
	else:
		push_error("ApplicationManager: Failed to unregister PID %d from ProcessManager." % pid)
