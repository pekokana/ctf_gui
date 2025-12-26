class_name NmapCommand
extends CLICommand

func _init():
	name = "nmap"
	description = "指定したIPアドレスの公開ポートをスキャンします。"
	usage = "nmap <target_ip>"
	version = "1.0.0"

func execute(args: Array[String], _current_path: String, _input_data: String = "", _fs: VirtualFilesystem = null) -> Dictionary:
	if args.size() == 0:
		return { "stdout": "", "stderr": "Usage: " + usage, "exit_code": 1 }
	
	var target_ip = args[0]
	var source_ip = GlEnv.user_ip_address # 自分のIPを取得 [cite: 11]
	
	# スキャン対象の代表的なポート（ミッションで使用するもの）
	var scan_ports = [21, 22, 80, 443, 3306, 8080]
	var found_ports: Array[int] = []
	
	var output = "Starting nmap scan on " + target_ip + "...\n"
	output += "PORT     STATE  SERVICE\n"
	
	for port in scan_ports:
		# ネットワークエンジン経由で接続を試みる 
		var response = VirtualNetworkEngine.send_request(source_ip, target_ip, port, "TCP", {"type": "probe"})
		
		# 404 (Host Unreachable) 以外なら、何らかの応答（200等）があったとみなす 
		if response.status != 404:
			var service = _get_service_name(port)
			output += "%-8d open   %s\n" % [port, service]
			found_ports.append(port)
	
	if found_ports.is_empty():
		output += "\nNo open ports found or host is down."
	else:
		output += "\nScan complete. Updating network map..."
		_update_discovery_data(target_ip, found_ports)
	
	return { "stdout": output, "stderr": "", "exit_code": 0 }

func _get_service_name(port: int) -> String:
	match port:
		21: return "ftp"
		22: return "ssh"
		80: return "http"
		443: return "https"
		3306: return "mysql"
		_: return "unknown"

func _update_discovery_data(ip: String, ports: Array):
	# MissionLoaderに登録されているデバイス情報を更新 [cite: 9]
	for device in MissionLoader.network_devices:
		if device.ip_address == ip:
			device.is_scanned = true
			device.open_ports.assign(ports)
			print("Device %s updated: is_scanned=%s, ports=%s" % [device.id, device.is_scanned, device.open_ports])
			# UIに再描画を促す（もし必要ならシグナルを飛ばす）
			# NmapCommand.gd の _update_discovery_data の最後に追加
			GameEvents.network_map_updated.emit()
