# res://engine/network/virtual_network_engine.gd
extends Node
class_name GL_VirtualNetworkEngine

# ネットワーク内の全デバイスを保持するマップ
# キー: "IPアドレス" (Ping用) または "IPアドレス:ポート" (通信用)
# 値: VirtualServer インスタンス または NetworkDevice リソース
var _device_map: Dictionary = {}

# IDからデバイスを逆引きするためのマップ
var _id_lookup: Dictionary = {}

## ミッション開始時に呼ばれる初期化処理
func initialize_network(servers: Array[VirtualServer], network_devices: Array[NetworkDevice]):
	_device_map.clear()
	_id_lookup.clear()

	# 1. サーバー（VirtualServer）の登録
	for server in servers:
		_id_lookup[server.id] = server
		_register_server_interfaces(server)

	# 2. ネットワークデバイス（NetworkDevice リソース）の登録
	for device in network_devices:
		_id_lookup[device.id] = device
		_register_network_device(device)

## サーバー用：インターフェースとポートを登録
func _register_server_interfaces(server: VirtualServer):
	var network = server.network_spec
	for interface in network.get("interfaces", []):
		var ip = interface.get("ip", "")
		if ip == "": continue
		
		# IP単体を登録 (Ping用)
		_device_map[ip] = server
		
		# ポートを登録 (通信用)
		for port in interface.get("ports", []):
			var key = "%s:%d" % [ip, port]
			_device_map[key] = server

## 一般デバイス用：IPアドレスを登録（ルーター・スイッチなど）
func _register_network_device(device: NetworkDevice):
	if device.ip_address != "":
		# NetworkDeviceリソースの ip_address を登録
		_device_map[device.ip_address] = device

## 【復活】IPアドレスがネットワーク上に存在するか確認
func _is_ip_assigned_to_server(ip: String) -> bool:
	# 名前は server ですが、ルーター等のデバイスも含めて存在チェックを行います
	return _device_map.has(ip)

## 通信リクエストの送信処理
func send_request(source_ip: String, dest_ip: String, dest_port: int, protocol: String, payload: Dictionary) -> Dictionary:
	
	# 1. ICMP (Ping) の処理
	if protocol == "ICMP":
		if _is_ip_assigned_to_server(dest_ip):
			var target = _device_map[dest_ip]
			# ターゲットが Resource(NetworkDevice) か Instance(VirtualServer) かで ID取得を分ける
			var target_id = target.id if "id" in target else "unknown"
			return {"status": 200, "body": "Pong from %s" % target_id}
		else:
			return {"status": 404, "error": "Destination Host Unreachable"}

	# 2. TCP/UDP の処理
	var key = "%s:%d" % [dest_ip, dest_port]
	
	if _device_map.has(key):
		var target = _device_map[key]
		# サーバーインスタンスであれば handle_request を実行
		if target.has_method("handle_request"):
			return target.handle_request(source_ip, protocol, payload)
		else:
			# ポートが開いていない、またはサーバーではないデバイス
			return {"status": 111, "error": "Connection Refused"}
	
	return {"status": 404, "error": "Destination Host Unreachable"}
