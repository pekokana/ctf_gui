# res://engine/server/database_server.gd

class_name DatabaseServer
extends VirtualServer

func _init():
	type = "database"

## SQLリクエストのシミュレーション処理
func handle_request(source_ip: String, protocol: String, payload: Dictionary) -> Dictionary:
	if protocol != "SQL":
		return {"status": 400, "error": "Only SQL protocol is supported."}
	
	var query = payload.get("query", "").strip_edges()
	
	# 1. 非常に単純なSQLインジェクション（認証回避）のシミュレーション
	# 例: SELECT * FROM users WHERE username = 'admin' AND password = '' OR '1'='1'
	if "OR '1'='1'" in query or "' OR 1=1" in query:
		return _get_vulnerable_data_response("flag_table")

	# 2. 通常のクエリ処理（簡易実装）
	if query.to_lower().begins_with("select"):
		return _process_select_query(query)
		
	return {"status": 403, "error": "Query denied by database engine."}

## 脆弱なレスポンス（フラグなどを含むデータを返す）
func _get_vulnerable_data_response(table_name: String) -> Dictionary:
	# 仮想FSから機密情報を読み出す（ミッションJSONで定義されたファイルを想定）
	var db_content = filesystem.read_file("/var/lib/mysql/master_data.db")
	
	return {
		"status": 200,
		"rows_affected": 1,
		"results": [
			{"id": 1, "data": db_content, "note": "SQL Injection successful."}
		]
	}

## 通常のセレクトクエリの擬似処理
func _process_select_query(query: String) -> Dictionary:
	# 実際はクエリをパースせず、ダミーデータを返すか、FSから公開データを返す
	return {
		"status": 200,
		"results": [{"message": "Login failed."}]
	}
