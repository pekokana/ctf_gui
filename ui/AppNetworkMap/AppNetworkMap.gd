# res://ui/AppNetworkMap/AppNetworkMap.gd
extends Control
class_name AppNetworkMap

# MissionLoaderがオートロードされていると仮定
var devices: Array[NetworkDevice] = [] # MissionLoaderから取得するデータ
var node_radius: float = 30.0 # ノードの半径
var animated_radius_boost: float = 0.0

# 現在選択されているデバイス
var selected_device: NetworkDevice = null

@onready var action_menu = $ActionMenu

func _ready() -> void:
	# initialize() のデータロードだけを行う
	_load_data()

	# データ更新シグナルに接続
	if is_instance_valid(GameEvents):
		GameEvents.network_map_updated.connect(queue_redraw)

	# サイズ確定を待つために _perform_initial_layout を遅延実行
	call_deferred("_perform_initial_layout")

## アプリケーションの初期化（データのロードのみ）
func _load_data():
	if is_instance_valid(MissionLoader): 
		devices = MissionLoader.network_devices
	
	# データがロードされたら、描画を要求
	queue_redraw()

## 遅延実行されるレイアウト関数
func _perform_initial_layout():
	# データをロード済みで、かつノードが配置されていない場合のみ実行
	if !devices.is_empty() and devices.any(func(d): return d.position == Vector2.ZERO):
		_place_nodes_circularly()
	
	queue_redraw()

func initialize():
	# ApplicationManagerから呼ばれたときにデータを取得
	if is_instance_valid(MissionLoader): 
		devices = MissionLoader.network_devices
	
	# 初回配置 (配置済みでなければ)
	if devices.any(func(d): return d.position == Vector2.ZERO):
		_place_nodes_circularly() 
	
	# 描画要求
	queue_redraw()

# AppNetworkMap.gd の _place_nodes_circularly 関数

## ノードを楕円形に配置する (新しい配置ロジック)
func _place_nodes_circularly():
	if devices.is_empty():
		return
		
	var rect_size = get_rect().size
	if rect_size.x < 150 or rect_size.y < 150:
		return

	# --- 1. レイアウトマージンの定義 (変更なし) ---
	
	# 上部マージン: ラベルの高さを含む安全距離
	var required_min_top_margin = 75.0 
	var top_margin = max(required_min_top_margin, rect_size.y * 0.1) 

	# 下部マージン: ノード最下端が画面下端から離れる安全パディング (40.0px)
	var bottom_padding = 40.0 
	var required_bottom_clearance = node_radius + bottom_padding # 70.0

	# 左右マージン: ノード半径 + 安全パディング (35.0)
	var side_margin = node_radius + 5.0

	# 2. レイアウトが可能な領域のサイズを計算
	var total_v_margin = top_margin + required_bottom_clearance 
	var total_h_margin = side_margin * 2.0         
	
	var max_width = rect_size.x - total_h_margin
	var max_height = rect_size.y - total_v_margin
	
	if max_width <= 0 or max_height <= 0:
		return
	
	# --- 3. 配置する楕円の半径を決定 (★ 修正箇所 ★) ---
	
	# X軸の半径: レイアウト可能幅の半分
	var radius_x = max_width * 0.5
	
	# Y軸の半径: レイアウト可能高さの半分
	var radius_y = max_height * 0.5
	
	# 4. 配置する円の中心座標を決定 (非対称マージン計算)
	
	var center_x = rect_size.x / 2.0
	
	# Y軸の中心: 上端マージン位置と下端マージン位置のちょうど真ん中
	var y_top_limit = top_margin
	var y_bottom_limit = rect_size.y - required_bottom_clearance 
	
	var center_y = (y_top_limit + y_bottom_limit) / 2.0
	
	# 最終調整: ノード配置円の中心を 10px 上に強制シフト (前回修正の維持)
	center_y -= 10.0
	
	var center = Vector2(center_x, center_y)

	# ノードが1つしかない場合は、計算された中心に配置
	if devices.size() <= 1:
		devices[0].position = center
		queue_redraw()
		return
		
	var count = devices.size()
	
	# 5. ノードの配置
	for i in range(count):
		# 楕円の極座標計算
		var angle = float(i) / count * TAU + (PI / 2.0) 
		
		# ノード位置の計算に、radius_x と radius_y を使用
		var x = center.x + radius_x * cos(angle)
		var y = center.y + radius_y * sin(angle)
		devices[i].position = Vector2(x, y)
		
	queue_redraw()

## ネットワーク接続とノードの描画
func _draw():
	if devices.is_empty():
		return

	var position_map: Dictionary = {}
	for device in devices:
		position_map[device.id] = device.position

	# --- 1. 接続線 (エッジ) の描画 ---
	for device in devices:
		var start_pos = device.position
		for connected_id in device.connected_to:
			if position_map.has(connected_id):
				var end_pos = position_map[connected_id]
				# スキャン済みなら線を明るく（シアン）、未スキャンならグレー
				var line_color = Color.CYAN if device.is_scanned else Color.GRAY
				var line_width = 2.0 if device.is_scanned else 1.5
				draw_line(start_pos, end_pos, line_color, line_width)
	
	# --- 2. ノード (デバイス) の描画 (中央配置ロジック) ---
	var font = ThemeDB.fallback_font
	var font_size_label = 14
	var font_size_ip = 10
	var font_size_ports = 9 # ポート用フォントサイズ
	
	# 行間（ラベルとIPアドレスの間）のパディングを定義
	var padding_between_lines = 2.0
	
	# 2行のテキスト全体の高さを計算 (正確な垂直中央揃えのため)
	var total_text_height = font_size_label + font_size_ip + padding_between_lines
	
	# ループの外でオフセットを定義
	# ノードの中心から、テキストブロック全体の高さの半分を計算
	var vertical_shift_offset = total_text_height / 2.0
	
	# 視覚的な中央揃えのための微調整オフセット
	var visual_correction_offset = 4.0 

	for device in devices:
		var center_pos = device.position

		# ノードの色を決定・初期化
		var node_color: Color
		if not device.is_scanned and device.type != "client":
			# スキャン前は正体不明（灰色）
			node_color = Color.GRAY
		else:
			# スキャン済み、または自分の場合は本来の色
			match device.type:
				"client": node_color = Color.DARK_CYAN
				"web", "database": node_color = Color.ORANGE
				_: node_color = Color.WHITE

		# 選択中のデバイスに強調枠を描画
		if selected_device == device:
			draw_circle(center_pos, node_radius + 6.0, Color.WHITE) # 白い外枠

		# スキャン済みなら外側に光輪を描画
		if device.is_scanned:
			#draw_circle(center_pos, node_radius + 3.0, node_color * 0.4) # ぼんやりした光
			# 半径を (node_radius + boost + 3.0) にする
			draw_circle(center_pos, node_radius + animated_radius_boost + 3.0, node_color * 0.4)

		# ノードの円を描画
		draw_circle(center_pos, node_radius + animated_radius_boost, node_color)
		draw_circle(center_pos, node_radius + animated_radius_boost - 2.0, Color.BLACK.lerp(node_color, 0.2))
		
		# --- 文字列の描画位置を計算 (視覚的な中央揃え) ---
		# 1. ラベル (上段) のXとY座標計算:
		# ノード中心から、オフセットと視覚補正分を減算
		#var label_y = center_pos.y - vertical_shift_offset - visual_correction_offset 
		#var label_y = center_pos.y - font_size_label - padding_between_lines
		var label_size = font.get_string_size(device.label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size_label)
		var label_x = center_pos.x - (label_size.x / 2)
		var label_y = center_pos.y - font_size_label
		
		# 2. IPアドレス (下段) のY座標計算:
		# ラベルのY座標に、ラベルのフォントサイズ、行間、および視覚補正を加える
		#var ip_y = label_y + font_size_label + padding_between_lines + visual_correction_offset
		var ip_size = font.get_string_size(device.ip_address, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size_ip)
		var ip_x = center_pos.x - (ip_size.x / 2)
		var ip_y = label_y + font_size_ip
		
		
		# --- ラベルの描画 ---
		draw_string(font, Vector2(label_x, label_y),
					device.label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size_label, Color.WHITE)
		#
		# --- IPアドレスの描画 ---
		draw_string(font, Vector2(ip_x, ip_y),
					device.ip_address, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size_ip, Color.LIGHT_GRAY)

		# ポート情報の描画 (スキャン済みの場合のみ)
		if device.is_scanned and not device.open_ports.is_empty():
			var ports_text = "Ports: " + str(device.open_ports).replace("[", "").replace("]", "")
			var p_size = font.get_string_size(ports_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size_ports)
			# ノードの円のすぐ下に配置
			var p_pos = Vector2(center_pos.x - p_size.x/2, center_pos.y + node_radius + 15.0)
			draw_string(font, p_pos, ports_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size_ports, Color.YELLOW)


## Controlノードのサイズが変更されたときに再描画を要求
func _notification(what):
	if what == NOTIFICATION_RESIZED:
		# ★ 修正: サイズが変わったら、必ずノードを再配置して中央に寄せる
		if !devices.is_empty():
			_place_nodes_circularly()
		else:
			queue_redraw()
			
# MDIウィンドウがアクティブになったときに、コンテンツにフォーカスを要求させるための空関数
func request_focus():
	pass # このアプリはキー入力を必要としないため、何もしません。

func play_discovery_animation():
	var t = create_tween()
	t.tween_property(self, "animated_radius_boost", 10.0, 0.1).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(self, "animated_radius_boost", 0.0, 0.3).set_trans(Tween.TRANS_BOUNCE)
	t.set_parallel(false)
	# アニメーション中、毎フレーム再描画
	t.tween_callback(queue_redraw)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var clicked_any = false
		
		for device in devices:
			# マウス位置とノード中心の距離を計算
			var dist = event.position.distance_to(device.position)
			
			# 半径以内にクリックがあれば選択
			if dist <= node_radius:
				_on_device_clicked(device)
				clicked_any = true
				break
		
		# 何もない場所をクリックしたら選択解除
		if not clicked_any:
			selected_device = null
			queue_redraw()

func _on_device_clicked(device: NetworkDevice):
	selected_device = device
	queue_redraw() # 選択状態（枠線など）を描画するために再描画
	
	# メニューの内容をデバイスの状態に合わせて動的に変える
	action_menu.clear()
	action_menu.add_item("Ping (基本調査)", 0)
	
	if not device.is_scanned:
		action_menu.add_item("Nmap Scan (ポートスキャン)", 1)
	else:
		# スキャン済みならポートに応じた攻撃を表示
		for port in device.open_ports:
			if port == 22: action_menu.add_item("SSH Brute Force", 2)
			if port == 80: action_menu.add_item("HTTP Exploit", 3)
	
	# マウス位置にメニューを表示
	action_menu.position = get_screen_transform().origin + get_local_mouse_position()
	action_menu.popup()

# ターミナルへの参照（シングルトンや親ノードから取得）
# ここでは「現在開いているターミナル」を取得する想定です
func _on_action_menu_id_pressed(id: int):
	if not selected_device:
		return

	var command_text = ""
	var ip = selected_device.ip_address
	var execute_immediately = false # すぐ実行するか、入力だけで止めるか

	match id:
		0: # Ping
			command_text = "ping " + ip
		1: # Nmap
			command_text = "nmap " + ip
			execute_immediately = true # スキャンは頻繁に使うので自動実行
		2: # SSH
			command_text = "ssh user@" + ip
		3: # HTTP (curlやブラウザ起動など)
			command_text = "curl " + ip

	# ターミナルを探してコマンドを流し込む
	_send_to_terminal(command_text, execute_immediately)

func _send_to_terminal(cmd: String, auto_exec: bool):
	# 構成によりますが、Windowマネージャー経由などでターミナルを取得
	# ここでは例として、MDIシステム内のTerminalを想定
	var terminal = get_tree().get_first_node_in_group("active_terminal")
	if not terminal:
		# ターミナルがなければ、アプリマネージャー経由で起動
		# （ApplicationManagerは自作のウィンドウ管理クラスと仮定）
		#WindowManager.open_app("terminal")
		# 起動完了を待つために少し待機するか、起動後のコールバックでセット
		await get_tree().create_timer(0.1).timeout
		terminal = get_tree().get_first_node_in_group("active_terminal")

	if terminal:
		terminal.set_command_line(cmd, auto_exec)
