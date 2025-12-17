# res://engine/filesystem/virtual_filesystem.gd

class_name VirtualFilesystem
extends RefCounted

# 内部ストレージ: パスをキーとするハッシュマップで高速アクセスを実現
# { "/path/to/file.txt": VirtualFileオブジェクト }
var _file_map: Dictionary = {}
var _root: String = "/"

## JSON定義からファイルシステムを構築する
## MissionLoaderによって呼び出されることを想定
func initialize_from_spec(fs_spec: Dictionary):
	_file_map.clear()
	_root = fs_spec.get("root", "/") # デフォルトは "/"
	
	# バリデーションは MissionValidator で完了している前提
	var files_array: Array = fs_spec.get("files", [])
	for file_data in files_array:
		var file_path = file_data.path as String
		var new_file = VirtualFile.new(
			file_path, 
			file_data.type as String, 
			file_data.get("content", "") as String,
			file_data.get("generator", {}) as Dictionary
		)
		
		# ファイルの内容を初期化/生成
		_generate_content(new_file)
		
		# 内部マップに格納
		_file_map[file_path] = new_file

## 指定されたパスのファイルオブジェクトを検索する
func find_file(path: String) -> VirtualFile:
	# Unix系準拠でパスを正規化する処理が必要になる場合があるが、ここではシンプルに実装
	return _file_map.get(path, null)

## 指定されたディレクトリの内容を一覧表示する (簡易版)
## @return Array[VirtualFile] - ディレクトリ直下のファイル/ディレクトリの VirtualFile オブジェクトの配列
func list_directory(path: String) -> Array[VirtualFile]:
	var normalized_path = path if path.ends_with("/") else path + "/"
	var results: Array[VirtualFile] = []
	var seen_entries: Dictionary = {} # 重複エントリ（特にディレクトリ）を避けるため
	
	if not is_directory(normalized_path):
		return []

	print("VFS DEBUG: Listing dir: ", normalized_path)

	# "." と ".." の追加
	# Unix系では ls -a で常に "." と ".." が表示されるため、VFSのリストに加える
	# 1. "." (カレントディレクトリ)
	# pathの末尾に"."を付加することで、ls_command側で ". " として名前が抽出されることを期待する（ハック）
	# ls_command.gd側でパスの末尾の "/" を削除してから get_file() することで、空文字列を避けることがよりクリーンです
	results.append(VirtualFile.new(normalized_path + ".", "directory")) 
	seen_entries["."] = true
	
	# 2. ".." (親ディレクトリ)
	if normalized_path != "/":
		# 親ディレクトリの正規化された絶対パスを取得
		var parent_path = resolve_path(normalized_path, "..")
		if not parent_path.ends_with("/"):
			parent_path += "/"
		
		# pathの末尾に".."を付加することで、".."として名前が抽出されることを期待する（ハック）
		results.append(VirtualFile.new(parent_path + "..", "directory"))
		seen_entries[".."] = true

	for file_path in _file_map:
		if file_path.begins_with(normalized_path):
			var relative_path = file_path.trim_prefix(normalized_path)
			var parts = relative_path.split("/", false)
			
			if parts.size() > 0:
				var entry_name = parts[0]
				
				if not seen_entries.has(entry_name):
					seen_entries[entry_name] = true
					
					if parts.size() == 1:
						# 直下のファイル
						print("VFS DEBUG: Found file: ", _file_map[file_path].path)
						results.append(_file_map[file_path])
					else:
						# 直下のディレクトリ（仮想的な VirtualFile オブジェクトを生成）
						var dir_path = normalized_path + entry_name + "/"
						print("VFS DEBUG: Found directory: ", dir_path)
						var dir_entry = VirtualFile.new(dir_path, "directory") 
						#print_debug("[vfs][sita]", dir_path)
						results.append(dir_entry)
						
	print("VFS DEBUG: Total items returned for ", path, ": ", results.size())
	return results


## 指定されたパスがディレクトリとして認識されるかチェックする (簡易版)
func is_directory(path: String) -> bool:
	# resolve_pathを使用してパスを正規化
	var normalized_path = resolve_path("/", path) # is_directoryはパスの絶対的な存在を確認するため、ルートをベースにする
	
	# 1. ルートディレクトリは常に存在する
	if normalized_path == "/":
		return true
	
	# 2. パス自体がファイルとして存在する場合、それはディレクトリではない
	if _file_map.has(normalized_path):
		return false
		
	# 3. ファイルマップ内に、このディレクトリ以下のファイルが存在するか確認
	# VirtualFilesystemはファイルのみを格納するため、ディレクトリの存在は子ファイルの有無で判断
	var dir_prefix = normalized_path + "/"
	for file_path in _file_map.keys():
		if file_path.begins_with(dir_prefix):
			return true
			
	return false

## カレントパス (current_path) に基づいて相対パス (target_path) を解決し、正規化する
## ., .. の解決、二重スラッシュの削除を行う
func resolve_path(current_path: String, target_path: String) -> String:
	# ターゲットパスが絶対パスであれば、current_pathを無視する
	var path_to_normalize: String
	if target_path.begins_with("/"):
		path_to_normalize = target_path
	else:
		# 相対パスの場合: current_pathをベースにする
		path_to_normalize = current_path
		# current_pathがルートでない限り末尾の'/'を削除し、target_pathを結合
		if path_to_normalize != "/":
			path_to_normalize += "/"
		path_to_normalize += target_path
	
	# 正規化処理
	#var parts: Array[String] = path_to_normalize.split("/", false)
	# String.split() は PackedStringArray を返すため、Array[String] に変換する
	#print_debug("[debug]path_to_normalize:", path_to_normalize)
	#print_debug("[debug]path_to_normalize2:", Array(path_to_normalize.split("/", false)))
	
	var parts: Array = Array(path_to_normalize.split("/", false))

	var resolved_parts: Array[String] = []

	for part in parts:
		if part.is_empty() or part == ".":
			continue
		elif part == "..":
			if resolved_parts.size() > 0:
				resolved_parts.pop_back()
			# else: ルートディレクトリの上の .. は無視
		else:
			resolved_parts.append(part)

	# 常にルート "/" から始まるようにし、パスが空の場合（元のパスが "" や "/" の場合）はルートとする
	var normalized = "/" + "/".join(resolved_parts)
	
	# 結果が空の場合はルートを返す
	if normalized.is_empty():
		return "/"
		
	return normalized

## 指定されたディレクトリの内容を詳細情報付きで一覧表示する
func list_directory_detailed(path: String) -> Array[Dictionary]:
	var file_list: Array[VirtualFile] = list_directory(path)
	var detailed_list: Array[Dictionary] = []
	
	for file in file_list:
		detailed_list.append(file.get_ls_info())
		
	return detailed_list


## ファイルシステムのルートパスを取得する
func get_root() -> String:
	return _root

## ファイルの内容を読み込む
func read_file(path: String) -> String:
	var file = find_file(path)
	if file:
		return file.content
	return "Error: File not found or permission denied." # ターミナルコマンドに合わせる

## ファイルの内容を書き込む
## (主にユーザーFSで利用、サーバーFSでは権限チェックが必要になる可能性あり)
func write_file(path: String, new_content: String) -> bool:
	var file = find_file(path)
	if file:
		file.content = new_content
		return true
	return false

## ファイルを検索する (簡易版)
func search_files(keyword: String) -> Array[VirtualFile]:
	var results: Array[VirtualFile] = []
	for path in _file_map:
		if path.find(keyword) != -1 or _file_map[path].content.find(keyword) != -1:
			results.append(_file_map[path])
	return results

## ノイズ付きフラグ生成ロジック (拡張ポイント)
func _generate_content(file: VirtualFile):
	# 将来の拡張性のため、file.generatorの定義に基づき内容を生成する
	if file.generator.has("flag_id"):
		# 例: フラグをノイズで包む、Base64デコードが必要なバイナリとして格納するなど
		file.content = "..." # Complex generation logic here
		pass
	# 現時点ではJSONのcontentをそのまま利用
	# file.content = file.raw_content
	pass
