# res://engine/server/app_server.gd

class_name AppServer
extends VirtualServer

# 認証情報の保持用
var admin_passwordword: String = ""
var users_db: Dictionary = {} # { "username": "passwordword" }

func _init():
	type = "app"

## 初期化処理の拡張
func initialize(server_spec: Dictionary):
	# 親クラス (VirtualServer) の初期化を呼び出す [cite: 2]
	super.initialize(server_spec)
	
	# auth 設定の読み込み
	var auth_spec = server_spec.get("auth", {})
	admin_passwordword = auth_spec.get("admin_passwordword", "admin") # デフォルト値を設定
	
	var users_list = auth_spec.get("users", [])
	for user_data in users_list:
		var uname = user_data.get("username", "")
		var upassword = user_data.get("passwordword", "")
		if uname != "":
			users_db[uname] = upassword

## リクエスト処理の拡張 (ログイン機能の追加)
func handle_request(source_ip: String, protocol: String, payload: Dictionary) -> Dictionary:
	if protocol == "API":
		var action = payload.get("action", "")
		
		match action:
			"login":
				return _handle_login(payload)
			"execute":
				return _handle_execute(payload)
				
	return super.handle_request(source_ip, protocol, payload)

## ログイン処理のシミュレーション
func _handle_login(payload: Dictionary) -> Dictionary:
	var user = payload.get("username", "")
	var password = payload.get("passwordword", "")
	
	# 管理者チェック
	if (user == "admin" or user == "root") and password == admin_passwordword:
		return {"status": 200, "message": "Login successful as ADMIN", "token": "admin-session-001"}
	
	# 一般ユーザーチェック
	if users_db.has(user) and users_db[user] == password:
		return {"status": 200, "message": "Login successful as " + user, "token": "user-session-999"}
		
	return {"status": 401, "error": "Invalid credentials"}

## 実行処理 (OSコマンドインジェクションの脆弱性はここに維持)
func _handle_execute(payload: Dictionary) -> Dictionary:
	# 以前の実装と同様の OS コマンド注入ロジック
	var cmd = payload.get("cmd", "")
	if ";" in cmd or "|" in cmd:
		return _simulate_command_injection(cmd)
	return {"status": 200, "output": execute_script(cmd)}

## コマンドインジェクションの判定ロジック
func _simulate_command_injection(input: String) -> Dictionary:
	# 簡易的なパース: 分離記号の後のコマンドを見る
	if "cat" in input and "flag" in input:
		# 仮想FSからフラグを読み取って返す
		var secret = filesystem.read_file("/root/flag.txt") 
		return {
			"status": 200, 
			"output": "[Injected Exec] Content of flag: " + secret
		}
	
	return {
		"status": 200, 
		"output": "Command executed, but no visible output (blind injection point?)"
	}
