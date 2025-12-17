# res://engine/server/server_factory.gd

class_name ServerFactory
extends Node

## ミッション定義から適切なサーバーインスタンスを生成する
static func create_server(server_spec: Dictionary) -> VirtualServer:
	var type = server_spec.get("type", "generic")
	var server: VirtualServer
	
	match type:
		"web":
			server = WebServer.new() 
		"database":
			server = DatabaseServer.new()
		"app":
			server = AppServer.new()
		_:
			# 未知のタイプは基本クラスで生成
			server = VirtualServer.new()
			
	# VirtualServer.gd の initialize を呼び出して FS とネットワーク設定を読み込む
	server.initialize(server_spec)
	return server
