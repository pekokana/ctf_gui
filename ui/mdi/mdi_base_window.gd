# res://scripts/windows/mdi_window.gd
extends Control
var tilte: String = "Untitled Window"
#class_name MDIWindow

# AutoLoadされたApplicationManagerへの参照 (ApplicationManager AutoLoadが必要です)
var app_manager = CL_ApplicationManager 

# --- 内部状態 ---
var process_pid: int = -1 
var initial_app_data: Dictionary = {}
var ui_scene: PackedScene
#@onready var close_button: Button = $VBoxRoot/TitleBar/CloseButton

# --- MDI ドラッグ用変数 ---
var is_dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO

# Windowが最前面に来たことをコンテンツに通知するためのカスタムシグナル
signal activated
signal deactivated

# 現在、最前面のウィンドウであるか
var is_top_window: bool = false
# --- Godot組み込み関数 ---

func _ready():
	pass
	# タイトルバーの閉じるボタンの接続をここで行います
	# ノード構成は以前提案した [$VBoxRoot/TitleBar/CloseButton] を想定
	#
	#if is_instance_valid(close_button):
		#close_button.pressed.connect(_on_close_requested)
	#else:
		#push_error("MDIWindow: CloseButton node not found for signal connection.")

# --- パブリック API (ApplicationManagerから呼ばれる) ---
## ウィンドウの初期化 (ApplicationManagerから呼ばれる)
func initialize(title_text: String, content_scene: PackedScene, mdi_minimal_size: Vector2, pid: int):
	#GlEnv.print_node_struct("★mdi-b-w call initialize first:", get_tree().get_root())

	# 1. 基本設定
	self.process_pid = pid
	self.ui_scene = content_scene
	self.tilte = title_text


	# タイトルを設定
	var title_label = $VBoxRoot/TitleBar/TitleLabel
	if is_instance_valid(title_label) and title_label is Label:
		title_label.text = "  " + title_text

	# 2. 最小サイズと初期サイズを設定
	#self.min_size = Vector2(225, 250)
	self.custom_minimum_size = mdi_minimal_size
	#self.size = Vector2(600, 450) # ターミナルとして適切な初期サイズを設定
	
	# 3. ウィンドウの内容をインスタンス化して配置
	var content_instance = self.ui_scene.instantiate()
	var content_container = $VBoxRoot/ContentContainer # MDIWindow.tscnの子ノード名に依存
	
	if is_instance_valid(content_container):
		content_container.add_child(content_instance)
		content_instance.set_anchors_preset(Control.PRESET_FULL_RECT)
		
		# 4. アプリケーション固有の初期化関数を呼び出す
		#if content_instance.has_method("initialize_terminal"):
		#if content_instance.has_method("initialize"):
			#content_instance.initialize(initial_data)
		
		# MDIウィンドウがアクティブになったときに、コンテンツにフォーカスを要求させる
		if content_instance.has_method("request_focus"):
			self.activated.connect(content_instance.request_focus)
		
		
	# 5. 閉じる要求シグナル接続
	
	#close_requested.connect(_on_close_requested)

# --- 内部処理 ---

## 閉じる要求シグナルハンドラ
func _on_close_requested():
	# 要件2: ApplicationManagerへどの画面が終了したのかをシグナルとして発砲
	if is_instance_valid(app_manager) and process_pid != -1:
		app_manager.close_application_by_pid(process_pid)
	
	# ウィンドウノードをノードツリーから削除
	#queue_free()

## Windowがフォーカスされたり、クリックされたりしたときのイベント
#func _gui_input(event: InputEvent):
	## マウスボタンが押されたとき (Window自体がクリックされたとき)
	#if event is InputEventMouseButton and event.pressed:
		## 最前面に移動
		#if get_parent():
			#get_parent().move_child(self, get_parent().get_child_count() - 1)
		## Activatedシグナルをエミットして、コンテンツ（TerminalContent）に通知
		#emit_signal("activated")

# --- MDI ドラッグ処理 ---

## タイトルバーの入力イベントを受け取る
func _input(event: InputEvent):
	# 常に最前面化処理を行う
	if event is InputEventMouseButton and event.pressed:
		
		var parent = get_parent()
		if not parent: return
		
		var children = parent.get_children()
		
		# --- 1. 非アクティブ化の処理 ---
		
		# 既存のウィンドウが既に最前面にあるかチェック
		if children.size() > 0 and children.back() != self:
			# 現在最前面のウィンドウを取得 (つまり、これから非アクティブになるウィンドウ)
			var old_top_window = children.back()
			
			if is_instance_valid(old_top_window) and old_top_window.has_signal("deactivated"):
				# 以前のウィンドウのフラグを更新
				old_top_window.is_top_window = false 
				# 非アクティブ化を通知
				old_top_window.emit_signal("deactivated")
		
		# --- 2. 最前面化とアクティブ化の処理 ---
		
		# ウィンドウを最前面に移動
		parent.move_child(self, parent.get_child_count() - 1)
		
		# アクティブ化を通知
		if not is_top_window:
			is_top_window = true
			emit_signal("activated")

	# --- 3. ドラッグ処理 (既存のコードをそのまま利用) ---
	
	# 1. マウス左ボタンのクリックイベントを処理
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		# タイトルバー領域のチェック
		var title_bar = $VBoxRoot/TitleBar
		if not is_instance_valid(title_bar): return
		
		var global_mouse_pos = get_global_mouse_position()
		
		var close_button = $VBoxRoot/TitleBar/CloseButton
		if is_instance_valid(close_button) and close_button.get_global_rect().has_point(global_mouse_pos):
			# イベントを消費せず、ボタン（子ノード）に伝播させる
			return # ここで処理を中断し、ボタンにイベントを渡す
		
		# タイトルバーのグローバルな矩形領域内にあるかチェックします。
		if title_bar.get_global_rect().has_point(global_mouse_pos):
			if event.pressed:
				is_dragging = true
				# グローバル位置からオフセットを計算
				drag_offset = global_mouse_pos - global_position
			elif not event.pressed:
				is_dragging = false
		else:
			# タイトルバー外でマウスが離された場合、ドラッグを終了
			if not event.pressed:
				is_dragging = false
				
		# イベントが処理済みとしてマークされている場合、他のノードへの伝播を防ぎます
		if is_dragging or (event.pressed == false and is_dragging):
			get_viewport().set_input_as_handled()
			
	# 2. マウスの移動イベントを処理
	if event is InputEventMouseMotion and is_dragging:
		# ドラッグ中は常にマウスの位置に合わせてノードの位置を更新
		global_position = get_global_mouse_position() - drag_offset
		get_viewport().set_input_as_handled()

### 実行ループで位置を更新
#func _process(delta):
	#pass
