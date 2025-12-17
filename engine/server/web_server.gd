# res://engine/server/web_server.gd

class_name WebServer
extends VirtualServer

func _init():
	type = "web"

## HTTP GET/POSTリクエストの処理を仮想化
func handle_request(source_ip: String, protocol: String, payload: Dictionary) -> Dictionary:
	if protocol == "HTTP" and payload.get("method") == "GET":
		var path = payload.get("path", "/index.html")
		
		# 仮想ファイルシステムからファイルを読み込む
		var file_content = filesystem.read_file(path)
		
		if file_content.begins_with("Error:"):
			return {"status": 404, "body": "404 Not Found"}
		
		return {
			"status": 200,
			"headers": {"Content-Type": "text/html"},
			"body": file_content
		}
		
	return {"status": 400, "error": "Unsupported Method"}
