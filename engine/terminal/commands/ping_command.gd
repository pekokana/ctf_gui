# res://engine/terminal/commands/ping_command.gd

class_name PingCommand
extends CLICommand

func _init():
	name = "ping"
	description = "指定されたIPアドレスに仮想ICMPリクエストを送信する。"
	usage = "ping <ip_address>"
	version = "1.0.1"

func execute(args: Array[String], current_path: String, input_data: String = "", fs: VirtualFilesystem = null) -> Dictionary:
	if args.size() == 0:
		return { "stdout": "", "stderr": "Usage: " + usage, "exit_code": 1 }

	var dest_ip = args[0]
	var source_ip: String = "127.0.0.1" # デフォルト値
	
	# GL_Env (Autoload) から送信元IPを取得
	# Autoload名はプロジェクト設定に依存しますが、以前の設計に従い GL_Env とします
	if (get_tree() and get_tree().root.has_node("GL_Env")):
		source_ip = GlEnv.user_ip_address
	else:
		# エラーにはせず、デバッグ用にデフォルトIPで続行する場合
		# return { "stdout": "", "stderr": "Error: GL_Env not loaded.", "exit_code": 1 }
		pass

	# 結果を蓄積する変数
	var output = ""
	var exit_code = 0
	
	# Linuxのping風ヘッダー
	output += "PING %s (%s) 56(84) bytes of data.\n" % [dest_ip, dest_ip]
	
	# 4回パケット送信をシミュレート
	var received_count = 0
	for i in range(1, 5):
		# GL_VirtualNetworkEngine (Autoload) にリクエスト送信
		# dest_port=0 は ICMP 扱い (VirtualNetworkEngineのロジックに依存)
		var response = VirtualNetworkEngine.send_request(source_ip, dest_ip, 0, "ICMP", {})

		if response.status == 200:
			# 成功 (200 OK)
			output += "64 bytes from %s: icmp_seq=%d ttl=64 time=1 ms\n" % [dest_ip, i]
			received_count += 1
		else:
			# 失敗 (Destination Host Unreachable など)
			output += "From %s icmp_seq=%d Destination Host Unreachable\n" % [source_ip, i]
			exit_code = 1
	
	# 統計情報の表示
	output += "\n--- %s ping statistics ---\n" % dest_ip
	var loss_percent = 0
	if received_count < 4:
		loss_percent = 100
		if received_count > 0:
			loss_percent = (4 - received_count) * 25
			
	output += "4 packets transmitted, %d received, %d%% packet loss, time 0ms\n" % [received_count, loss_percent]
	
	return { "stdout": output, "stderr": "", "exit_code": exit_code }

# ヘルパー: ツリーへのアクセス用 (CLICommandはRefCountedなのでget_tree()を持っていないため工夫が必要)
# ただし、Autoloadはグローバル変数としてアクセスできるため、
# GL_Env や GL_VirtualNetworkEngine と直接書いてもOKです。
# 上記コードでは安全のため has_node チェックを入れていますが、
# 単に GL_Env.user_ip_address と書いても動作します。
func get_tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree
