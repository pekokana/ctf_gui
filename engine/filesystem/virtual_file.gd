# res://engine/filesystem/virtual_file.gd

class_name VirtualFile
extends RefCounted # インスタンス管理を容易にするため

## ファイルの絶対パス (例: /home/user/readme.txt)
var path: String
## ファイルタイプ (text, log, pcap, binary)
var type: String
## 実際のコンテンツ (読み書き対象)
var content: String
## JSONに定義された自動生成ルール (ノイズなど)
var generator: Dictionary 
## Unix風のパーミッション (例: "rwxr-xr--")
var permissions: String
## サイズ (バイト単位。ディレクトリは 4096 など)
var size: int
## JSONから読み込んだオリジナルのコンテンツ (ノイズ生成前の状態を保持する目的で利用可)
var raw_content: String

## コンストラクタ
func _init(p_path: String, p_type: String, p_content: String = "", p_generator: Dictionary = {}):
	path = p_path
	type = p_type
	content = p_content
	raw_content = p_content # 初期コンテンツを保持
	generator = p_generator
	# ファイルタイプに応じた初期設定
	if type == "directory":
		permissions = "drwxr-xr-x"
		size = 4096 # ディレクトリのサイズは慣例で4096
	else:
		# ファイルのサイズは content の長さ
		size = content.length()
		permissions = "-rwxr-xr--" # ファイルのパーミッション

## 指定されたパスがディレクトリであるかを返す
func is_directory() -> bool:
	return type == "directory"

## ls -l 用の詳細情報を Dictionary で返す
func get_ls_info() -> Dictionary:
	# ls_command.gd の -l 出力形式に合わせる
	var type_char = permissions.left(1)
	return {
		"type": type_char,
		"permissions": permissions.right(9), # type_char を除いた9文字
		"size": size,
		"name": path.get_file()
	}
