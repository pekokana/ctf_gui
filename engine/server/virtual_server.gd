# res://engine/server/virtual_server.gd

class_name VirtualServer
extends RefCounted

var id: String
var type: String # web, app, file など
var filesystem: VirtualFilesystem
var network_spec: Dictionary

## MissionLoaderから呼ばれる初期化処理
func initialize(server_spec: Dictionary):
	id = server_spec.id
	type = server_spec.type
	network_spec = server_spec.network
	
	# Filesystemのインスタンス化
	filesystem = VirtualFilesystem.new()
	filesystem.initialize_from_spec(server_spec.filesystem)

## ネットワークリクエストを処理する抽象メソッド (サブクラスで実装)
func handle_request(source_ip: String, protocol: String, payload: Dictionary) -> Dictionary:
	# Factory パターンで生成されるサブクラスでオーバーライドされる
	return {"status": 501, "error": "Service Not Implemented"}

## 仮想サーバーの内部でコマンドを実行する機能 (アプリケーションサーバーなどで利用)
func execute_script(command: String) -> String:
	# サーバータイプに応じた仮想的な実行環境ロジック
	return "Executing: " + command
