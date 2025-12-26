# res://engine/mission/mission_loader.gd

extends Node
class_name GL_MissionLoader # Autoload シングルトンとして設定

# 仮想環境の状態
var current_mission_json: Dictionary = {}
var user_fs: VirtualFilesystem = null
var servers: Array[VirtualServer] = []
var goals: Dictionary = {}
var network_devices: Array[NetworkDevice] = []


# サーバータイプとクラスのマッピング (Factoryパターン)
# 新しいサーバータイプを追加する場合はここに登録するだけで良い
const SERVER_FACTORY: Dictionary = {
	"web": preload("res://engine/server/web_server.gd"),
	"database": preload("res://engine/server/database_server.gd"),
	"app": preload("res://engine/server/app_server.gd"),
	# "file": preload("res://engine/server/file_server.gd"),
}

## Mission JSON ファイルをロードし、環境を構築する
## @param json_path: String - 読み込むJSONファイルのパス (例: "user://missions/mission01.json")
## @return ValidationReport - バリデーション結果とロード結果を含む
func load_mission(json_path: String) -> ValidationReport:
	# 既存環境のクリア
	_cleanup_environment()

	# 1. JSON ファイルの読み込み
	var report = ValidationReport.new()
	
	var file = FileAccess.open(json_path, FileAccess.READ)
	if !file:
		report.add_error("LOAD_ERROR", json_path, "JSONファイルが見つからないか、読み込みに失敗しました。")
		return report

	var json_text = file.get_as_text()
	
	# 2. JSON パース
	var json_parse_result = JSON.parse_string(json_text)
	if typeof(json_parse_result) != TYPE_DICTIONARY:
		report.add_error("LOAD_ERROR", json_path, "JSONのパースに失敗しました。無効な形式です。")
		return report
		
	current_mission_json = json_parse_result

	# 3. バリデーションの実行
	# GL_MissionValidator は Autoload であり、Mission JSON Validation 設計に基づき実装済み
	var validation_report: ValidationReport = GL_MissionValidator.validate(current_mission_json)
	if !validation_report.valid:
		return validation_report # バリデーションエラーがあれば構築を中断

	# 4. 環境構築 (バリデーション成功時のみ)

	# <--- ユーザーIPを環境設定に追加 ---
	# Mission JSONにユーザーIPの定義がない場合、暫定でハードコード
	var user_client_ip = current_mission_json.get("client_ip", "0.0.0.0")
	
	# GL_Env にグローバル環境を初期化
	GlEnv.set_environment(user_client_ip, current_mission_json.mission_id)
	# ターミナルの初期パスも設定
	GlEnv.current_working_directory = current_mission_json.user_filesystem.get("root", "/")

	# 4.1. ユーザーFSの生成
	user_fs = VirtualFilesystem.new()
	user_fs.initialize_from_spec(current_mission_json.user_filesystem)

	# 4.2. サーバー群の生成
	for server_spec in current_mission_json.servers:
		var server_type = server_spec.type as String
		if SERVER_FACTORY.has(server_type):
			var ServerClass = SERVER_FACTORY[server_type]
			# ServerClass は VirtualServer を継承している
			var server_instance: VirtualServer = ServerClass.new()
			server_instance.initialize(server_spec)
			servers.append(server_instance)
		else:
			# バリデーターがキャッチしているはずだが、念のため二重チェック
			push_error("MissionLoader: Unknown server type: %s" % server_type)
			# ここでエラーがあれば、環境が不完全なため中断が必要
			report.add_error("FACTORY_ERROR", "servers", "不明なサーバー種別: " + server_type)
			return report
			
	# 4.3. ネットワークエンジンの初期化
	# 4.3. ネットワークトポロジーの構築 (リソースの生成)
	# 先に JSON データを NetworkDevice リソースの配列に変換する
	_load_network_topology(current_mission_json)

	# 4.4. ネットワークエンジンの初期化
	# クラス変数 self.network_devices (Array[NetworkDevice]) を渡す
	VirtualNetworkEngine.initialize_network(servers, network_devices)
	
	# 5. ゴール設定
	goals = current_mission_json.goals	

	# 成功レポート
	return report

## 環境をリセットする
func _cleanup_environment():
	user_fs = null
	servers.clear()
	goals.clear()
	current_mission_json = {}
	VirtualNetworkEngine._device_map.clear() # ネットワークもリセット

## ファイルシステムを戻す
func getUserFileSystem() -> VirtualFilesystem:
	return self.user_fs


## ミッションJSONから NetworkDevice のリストを生成する
func _load_network_topology(data: Dictionary):
	network_devices.clear()
	var all_target_ids: Array[String] = [] # クライアントの接続先候補リスト

	# --- 1. サーバーデバイスの生成 ---
	for server_spec in data.servers:
		var server_device = NetworkDevice.new()
		server_device.id = server_spec.id
		server_device.type = server_spec.type
		server_device.label = server_spec.id.capitalize()
		
		# IPアドレスの抽出: servers[].network.interfaces[0].ip を利用
		var interfaces = server_spec.network.get("interfaces", [])
		if interfaces.size() > 0:
			# 最初のIPアドレスを使用
			server_device.ip_address = interfaces[0].ip
		
		# ★ 修正: 新しい JSON 仕様 'connected_to' を優先的に利用
		var connections = server_spec.get("connected_to", []) 
		server_device.connected_to.append_array(connections)

		# connected_to に "client" が含まれていない場合、互換性のため追加
		if not server_device.connected_to.has("client"):
			server_device.connected_to.append("client")
		
		network_devices.append(server_device)
		all_target_ids.append(server_spec.id) # クライアントの接続先候補に追加

	# --- 2. 追加ネットワークデバイスの生成 ---
	for net_device_spec in data.get("network_devices", []):
		var net_device = NetworkDevice.new()
		net_device.id = net_device_spec.id
		net_device.type = net_device_spec.type
		net_device.label = net_device_spec.id.capitalize()
		
		# ★ 修正: 新しい JSON 仕様 'connected_to' を優先的に利用
		var connections = net_device_spec.get("connected_to", [])
		net_device.connected_to.append_array(connections)
		
		# connected_to に "client" が含まれていない場合、互換性のため追加
		if not net_device.connected_to.has("client"):
			net_device.connected_to.append("client")
		
		network_devices.append(net_device)
		all_target_ids.append(net_device_spec.id) # クライアントの接続先候補に追加

	# --- 3. クライアントデバイス (ユーザー自身) の生成 ---
	var client_device = NetworkDevice.new()
	client_device.id = "client"
	client_device.type = "client"
	client_device.label = "You (Client)"
	client_device.ip_address = GlEnv.user_ip_address if is_instance_valid(GlEnv) else "0.0.0.0"
	print(GlEnv.user_ip_address)
	
	# クライアント接続先の確定
	# クライアント側は、すべてのターゲットに接続していると仮定 (JSONでクライアント側の接続を定義するのは非効率なため)
	client_device.connected_to.append_array(all_target_ids)
	
	network_devices.append(client_device)
	
	#デバッグチェック
	if network_devices.is_empty():
		push_error("MissionLoader: network_devices is EMPTY!")
	else:
		print("MissionLoader: network_devices loaded successfully with %d devices." % network_devices.size())
		for device in network_devices:
			print("  - Device ID: %s, IP: %s, Connections: %s" % [device.id, device.ip_address, device.connected_to])
