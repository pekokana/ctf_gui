# res://engine/network/virtual_network_engine.gd (修正版)

extends Node
class_name GL_VirtualNetworkEngine # Autoload シングルトン

# ネットワーク内の全デバイス (サーバー, ルーターなど)
var _device_map: Dictionary = {} # { "10.0.0.10:80": VirtualServer }
var _server_lookup: Dictionary = {} # { "server_id": VirtualServer }

## MissionLoaderから呼ばれ、ネットワークトポロジーを構築する
# <--- 修正箇所: serversが JSON Array から VirtualServer Array に変更
func initialize_network(servers: Array[VirtualServer], network_devices: Array): 
	_device_map.clear()
	_server_lookup.clear()

	# サーバーをネットワークに追加
	for server_instance in servers: # <--- 修正箇所: インスタンスをループ
		# _server_lookup にインスタンスを格納
		_server_lookup[server_instance.id] = server_instance
		_register_server_interfaces(server_instance) # <--- 修正箇所: インスタンスを登録

	# ネットワークデバイス (ルーター/スイッチ) を追加 (後続ステップで詳細化)
	# for device_spec in network_devices: ...

## 仮想的なパケット/リクエストの送信処理
func send_request(source_ip: String, dest_ip: String, dest_port: int, protocol: String, payload: Dictionary) -> Dictionary:
	
	# <--- 修正箇所: 3.2 ICMP (Ping) 特殊処理の追加
	if protocol == "ICMP":
		# ICMPはポートを使用しない。IPアドレスのみでサーバーの存在を確認
		if _is_ip_assigned_to_server(dest_ip): 
			# サーバーが存在し、応答可能と仮定
			return {"status": 200, "body": "Pong"}
		else:
			return {"status": 404, "error": "Destination Host Unreachable"}

	# TCP/UDPの場合、IP:Port の組み合わせで検索
	var key = "%s:%d" % [dest_ip, dest_port]
	
	# 宛先のIPとポートでデバイスを検索
	if _device_map.has(key):
		var target_device: VirtualServer = _device_map[key]
		
		# <--- 修正箇所: サーバーインスタンスの handle_request を呼び出す
		return target_device.handle_request(source_ip, protocol, payload)
	
	return {"status": 404, "error": "Destination Host Unreachable"}

## サーバーのネットワーク定義を解析し、デバイスマップに登録する
# <--- 修正箇所: 1.1 VirtualServer のインスタンスを受け取る
func _register_server_interfaces(server_instance: VirtualServer):
	var server_id = server_instance.id 
	# <--- 修正箇所: JSONではなくインスタンスのプロパティを利用
	var network = server_instance.network_spec 
	
	for interface in network.get("interfaces", []):
		var ips: Array = []
		if typeof(interface.ip) == TYPE_ARRAY:
			ips = interface.ip
		elif typeof(interface.ip) == TYPE_STRING:
			ips = [interface.ip]
		
		var ports: Array = interface.get("ports", [])
		
		for ip in ips:
			# IPのみの登録 (ping用)
			_device_map[ip] = server_instance # <--- 修正箇所: インスタンスを登録
			
			for port in ports:
				var key = "%s:%d" % [ip, port]
				# IP:Port の組み合わせを登録
				_device_map[key] = server_instance # <--- 修正箇所: インスタンスを登録

## 補助関数: IPアドレスがサーバーに割り当てられているか確認
func _is_ip_assigned_to_server(ip: String) -> bool:
	return _device_map.has(ip)
