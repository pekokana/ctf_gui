# res://engine/validation/mission_validator.gd

extends Node
class_name MissionValidator # Autoload シングルトン名

const IPV4_REGEX: String = "^(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])(\\.(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])){3}$"
const ALLOWED_FILE_TYPES: Array[String] = ["text", "log", "pcap", "binary"] # 登録済みファイルタイプ

## Mission JSON全体を検証し、レポートを返す
func validate(mission_json: Dictionary) -> ValidationReport:
	var report = ValidationReport.new()

	# 1. 構造と基本型の検証
	_validate_top_level(mission_json, report)
	if !report.valid:
		return report # 必須キーがない場合は続行しない

	# 2. 詳細コンポーネントの検証
	_validate_filesystem_component("user_filesystem", mission_json.user_filesystem, report)
	_validate_servers(mission_json.servers, report)
	_validate_goals(mission_json.goals, report)
	# Network Devicesも必要であればここで呼び出し

	# 3. クロスチェック (重複/競合)
	_validate_cross_checks(mission_json, report)

	return report


## 3.1 Mission JSON のトップレベル項目を検証
func _validate_top_level(json: Dictionary, report: ValidationReport):
	# difficulty のチェックをカスタムで行うため、一旦除外
	var required_fields_general: Dictionary = {
		"mission_id": TYPE_STRING,
		"title": TYPE_STRING,
		"description": TYPE_STRING,
		"user_filesystem": TYPE_DICTIONARY,
		"servers": TYPE_ARRAY,
		"goals": TYPE_DICTIONARY,
	}

	# 1. 一般的な必須フィールドと型のチェック
	for key in required_fields_general.keys():
		var expected_type = required_fields_general[key]
		
		# 必須キーの有無チェック
		if !json.has(key):
			report.add_error("STRUCTURE_ERROR", key, "必須キー '%s' が欠落しています。" % key)
			continue 
			
		var actual_type = typeof(json[key])
		
		# 型チェック
		if actual_type != expected_type:
			report.add_error("TYPE_ERROR", key, "型が正しくありません。期待: %d, 実際: %d" % [expected_type, actual_type])
			continue
			
		# 追加のロジックチェック
		match key:
			"mission_id", "title":
				if (json[key] as String).is_empty():
					report.add_error("TYPE_ERROR", key, "空文字列は許可されません。")
			"servers":
				if (json[key] as Array).size() < 1:
					report.add_error("STRUCTURE_ERROR", key, "サーバー配列の長さは1以上でなければなりません。")


	# 2. difficulty フィールドの特別チェック (int/float混在対応 & 欠落チェックを統合)
	if !json.has("difficulty"):
		# 欠落チェック
		report.add_error("STRUCTURE_ERROR", "difficulty", "必須キー 'difficulty' が欠落しています。")
	else:
		var difficulty_val = json.difficulty
		var val_type = typeof(difficulty_val)
		
		# 型チェック: float (3) または int (2) でなければエラー
		if val_type != TYPE_INT and val_type != TYPE_FLOAT:
			report.add_error("TYPE_ERROR", "difficulty", "難易度は数値 (int/float) である必要があります。")
			
		# 値域チェック (1〜5の整数であること)
		elif floor(difficulty_val) != difficulty_val or difficulty_val < 1 or difficulty_val > 5:
			report.add_error("FORMAT_ERROR", "difficulty", "難易度は1から5の整数値である必要があります。")
		
		# NOTE: このロジックはエラーがない場合、何も報告しません。これが正しい挙動です。

## 3.2 Filesystem (User/Server 共通) の検証
func _validate_filesystem_component(path_prefix: String, fs: Dictionary, report: ValidationReport):
	if !fs.has_all(["root", "files"]):
		report.add_error("STRUCTURE_ERROR", path_prefix, "FSは 'root' と 'files' を含む必要があります。")
		return

	if typeof(fs.root) != TYPE_STRING or typeof(fs.files) != TYPE_ARRAY:
		report.add_error("TYPE_ERROR", path_prefix, "FS構造内の型が不正です。")
		return

	var existing_paths: Array[String] = []

	for i in range(fs.files.size()):
		var file_path = "%s.files[%d]" % [path_prefix, i]
		var file_obj = fs.files[i]

		# 必須フィールドチェック
		if !file_obj.has_all(["path", "type"]):
			report.add_error("STRUCTURE_ERROR", file_path, "ファイルオブジェクトには 'path' と 'type' が必要です。")
			continue
		
		# path/typeの型チェック
		if typeof(file_obj.path) != TYPE_STRING or typeof(file_obj.type) != TYPE_STRING:
			report.add_error("TYPE_ERROR", file_path, "'path' と 'type' は文字列である必要があります。")
			continue

		# pathルールチェック
		if !(file_obj.path as String).begins_with("/"):
			report.add_error("FORMAT_ERROR", file_path + ".path", "パスは '/' から始まる必要があります。")
		
		# path 重複チェック
		if existing_paths.has(file_obj.path):
			report.add_error("DUPLICATE_ERROR", file_path + ".path", "同じパスがファイルシステム内で重複しています。")
		existing_paths.append(file_obj.path)

		# type 登録チェック
		if !ALLOWED_FILE_TYPES.has(file_obj.type):
			report.add_error("UNSUPPORTED_ERROR", file_path + ".type", "未登録のファイルタイプです。許可: " + str(ALLOWED_FILE_TYPES))

		# generator, content の型チェック (省略 - 現状はoptionalのため)


## 3.3 Servers 配列の検証
func _validate_servers(servers: Array, report: ValidationReport):
	var existing_server_ids: Array[String] = []
	
	for i in range(servers.size()):
		var server_spec = servers[i]
		var path = "servers[%d]" % i
		
		# 構造チェック (ID, type, filesystem, network)
		if typeof(server_spec) != TYPE_DICTIONARY:
			report.add_error("TYPE_ERROR", path, "サーバー定義は辞書型である必要があります。")
			continue
			
		# 必須キーチェック
		for key in ["id", "type", "filesystem", "network"]:
			if !server_spec.has(key):
				report.add_error("STRUCTURE_ERROR", "%s.%s" % [path, key], "必須キー '%s' が欠落しています。" % key)
				
		# ID重複チェック
		var server_id = server_spec.get("id", "") as String
		if server_id.is_empty():
			report.add_error("FORMAT_ERROR", "%s.id" % path, "サーバーIDは空文字列にできません。")
		elif existing_server_ids.has(server_id):
			report.add_error("DUPLICATE_ERROR", "%s.id" % path, "サーバーID '%s' が重複しています。" % server_id)
		else:
			existing_server_ids.append(server_id)

		# サーバータイプチェック (現状は web のみ許容)
		var server_type = server_spec.get("type", "") as String
		if server_type != "web" and \
		   server_type != "database":
			report.add_error("UNSUPPORTED_ERROR", "%s.type" % path, "未サポートのサーバー種別 '%s' です。" % server_type)
		
		# Filesystemの再帰的検証 (既存の _validate_filesystem_component を呼び出す)
		_validate_filesystem_component("%s.filesystem" % path, server_spec.get("filesystem", {}), report)

		# ネットワークインターフェースの検証
		var network = server_spec.get("network", {})
		if network.has("interfaces") and typeof(network.interfaces) == TYPE_ARRAY:
			for j in range(network.interfaces.size()):
				var interface = network.interfaces[j]
				# ここで上記で定義したヘルパー関数を呼び出す
				_validate_network_interface(interface, "%s.network.interfaces[%d]" % [path, j], report)
		else:
			report.add_error("STRUCTURE_ERROR", "%s.network.interfaces" % path, "必須キー 'interfaces' (配列) が欠落しています。")
			

## 3.5 Goals の検証
func _validate_goals(goals: Dictionary, report: ValidationReport):
	if goals.has("flag") and typeof(goals.flag) != TYPE_STRING:
		report.add_error("TYPE_ERROR", "goals.flag", "'flag' は文字列である必要があります。")


## 3.6 クロスチェック (IP/ポートの競合など) の検証
func _validate_cross_checks(json: Dictionary, report: ValidationReport):
	var used_ip_port_combos: Dictionary = {} # { "10.0.0.10:80": [\"web01\"] }

	# WARNING_SERVER_COUNT の修正 (行番号 230付近)
	if json.servers.size() < 1:
		# サーバーが0台の場合
		report.add_error("WARNING_SERVER_COUNT", "servers", "ミッション実行に必要なサーバーが定義されていません (0台)。")
	elif json.servers.size() == 1: 
		# サーバーが1台の場合 (Warningとして残す)
		report.add_warn("WARNING_SERVER_COUNT", "servers", "サーバーが1台のみ定義されています。複雑なミッションには2台以上を推奨します。")
	# <--- ここから後のコードは、for server in json.servers: で始まるはずです。

	for server in json.servers:
		if server.network.has("interfaces"):
			for interface in server.network.interfaces:
				var ips: Array = []
				if interface.has("ip"):
					ips = interface.ip if typeof(interface.ip) == TYPE_ARRAY else [interface.ip]

				if interface.has("ports") and typeof(interface.ports) == TYPE_ARRAY:
					for ip in ips:
						for port in interface.ports:
							var key = "%s:%d" % [ip, port]
							
							# ポート競合チェック
							if used_ip_port_combos.has(key):
								# ポート競合エラー：同一IPアドレスでポートが重複している
								report.add_error("CONFLICT_ERROR", "servers[...].network", "IP/ポートの競合: %s はサーバー %s と %s で使用されています。" % [key, used_ip_port_combos[key][0], server.id])
							else:
								used_ip_port_combos[key] = [server.id]

	# FSのクロスチェック: user FS と server FS のパス衝突は許容 (名前空間が別のため)
	pass # 現時点では実装不要

# ネットワークインターフェース（IPとポート）の検証を行うヘルパー関数
func _validate_network_interface(interface: Dictionary, path: String, report: ValidationReport):
	# 1. IP Address Validation (FORMAT_ERROR の修正)
	if interface.has("ip"):
		var ips: Array = []
		if typeof(interface.ip) == TYPE_ARRAY:
			ips = interface.ip
		elif typeof(interface.ip) == TYPE_STRING:
			ips.append(interface.ip)
		else:
			report.add_error("TYPE_ERROR", "%s.ip" % path, "IPアドレスは文字列または文字列の配列である必要があります。")
			
		const IPV4_REGEX: String = "^(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])(\\.(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])){3}$"

		var IPRegex = RegEx.new()
		#IPRegex.compile(IPV4_REGEX)
		if IPRegex.compile(IPV4_REGEX) != OK:
			print_debug("RegEx compile Error!")
			return false
		for i in range(ips.size()):
			var ip_val = ips[i]
			if typeof(ip_val) != TYPE_STRING:
				report.add_error("TYPE_ERROR", "%s.ip[%d]" % [path, i], "IPアドレスは文字列である必要があります。")
				continue
				
			# JSON読み込み時に混入する可能性のある空白を削除し、正規表現で検証
			var stripped_ip = ip_val.strip_edges()
			if stripped_ip.is_empty() or !IPRegex.search(stripped_ip):
				report.add_error("FORMAT_ERROR", "%s.ip[%d]" % [path, i], "IPアドレスが不正なIPv4形式です。")

	# 2. Ports Validation (FORMAT_ERROR の修正: float許容と範囲チェックの強化)
	if interface.has("ports"):
		var ports_array = interface.ports
		if typeof(ports_array) != TYPE_ARRAY:
			report.add_error("TYPE_ERROR", "%s.ports" % path, "ポートは配列である必要があります。")
			return
			
		var existing_ports: Array[int] = []
		for i in range(ports_array.size()):
			var port_val = ports_array[i]
			var val_type = typeof(port_val)

			# ポートは数値 (int または float) であることを確認
			if val_type != TYPE_INT and val_type != TYPE_FLOAT:
				report.add_error("TYPE_ERROR", "%s.ports[%d]" % [path, i], "ポート番号は数値である必要があります。")
				continue
			
			# ポートは小数点以下のない整数値であることを確認
			if floor(port_val) != port_val:
				report.add_error("FORMAT_ERROR", "%s.ports[%d]" % [path, i], "ポート番号は整数値である必要があります。")
				continue
			
			# 範囲チェック (1〜65535)
			if port_val < 1 or port_val > 65535:
				report.add_error("FORMAT_ERROR", "%s.ports[%d]" % [path, i], "ポート番号は 1 から 65535 の範囲内である必要があります。")
				continue
			
			# ポート重複チェック（同一NIC内）
			if existing_ports.has(int(port_val)):
				report.add_error("DUPLICATE_ERROR", "%s.ports[%d]" % [path, i], "ポート番号 '%d' が同一NIC内で重複しています。" % port_val)
			existing_ports.append(int(port_val))
