# res://engine/terminal/commands/ls_command.gd

class_name LsCommand
extends CLICommand

func _init():
	name = "ls"
	description = "指定されたディレクトリ、または現在のディレクトリの内容を一覧表示する。(-l: 詳細表示)"
	usage = "lsls [-l] [path]"
	version = "1.1.0"

## コマンド実行ロジック
func execute(args: Array[String], current_path: String, input_data: String = "", fs: VirtualFilesystem = null) -> Dictionary:
	if fs == null:
		return { "stdout": "", "stderr": "Internal Error: Filesystem not available.", "exit_code": 1 }

	# 1. オプションとパスの解析
	var target_paths: Array[String] = []
	var is_long_format = false
	var show_all = false

	for arg in args:
		match arg:
			"-l":
				is_long_format = true
			"-la":
				is_long_format = true
				show_all = true 
			"-al":
				is_long_format = true
				show_all = true 
			"-a":
				show_all = true
			_:
				target_paths.append(arg)

	# 表示対象パスの決定
	var target_path: String
	if target_paths.is_empty():
		target_path = current_path
	else:
		target_path = target_paths[0]
	
	# 2. ファイルシステムからディレクトリの内容を取得
	var file_list: Array

	# パスが存在し、ディレクトリであることをチェック
	if !fs.is_directory(target_path):
		if fs.read_file(target_path).begins_with("Error: No such file or directory."):
			return {
				"stdout": "",
				"stderr": "Error: Cannot access '%s': No such file or directory." % target_path,
				"exit_code": 1
			}
		else:
			# ファイルの場合 (単一ファイルの詳細表示)
			if is_long_format:
				# 🛠️ 修正 3: 単一ファイルの-l出力も標準形式に修正
				var file_obj = fs.find_file(target_path)
				var size = file_obj.content.length() if file_obj.content else 0
				return {
					"stdout": "-rwxr-xr--  1 user user %6d %s" % [size, target_path.get_file()],
					"stderr": "",
					"exit_code": 0
				}
			# 簡易表示
			return { "stdout": target_path.get_file(), "stderr": "", "exit_code": 0 }


	# パスの正規化
	if !target_path.ends_with("/"):
		target_path += "/"
		
	# ファイルリストの取得
	if is_long_format:
		file_list = fs.list_directory_detailed(target_path)
	else:
		file_list = fs.list_directory(target_path)

	# 3. 結果のフィルタリングと整形
	var output: String = ""
	var processed_list: Array = []

	for file in file_list:
		var entry_name: String
		
		# エントリ名の取得
		if is_long_format:
			entry_name = file.get("name", "")
		else:
			# 簡易リストの場合、pathプロパティからファイル名を取得
			entry_name = file.path.trim_suffix("/").get_file()
		
		## 空のファイル名は無視
		#if entry_name.is_empty():
			#continue

		# 3.2. 隠しファイル (.ssh など) のフィルタリング
		# 🛠️ 修正 2: -a オプションがなく、かつエントリ名が '.' で始まる場合 (. や .. を含む) はスキップ
		if !show_all and entry_name.begins_with("."):
		#if !show_all:
			continue
			
		processed_list.append(file)

	print_debug("[file_list]", file_list)


	# 4. 最終出力
	if is_long_format:
		# 詳細リスト表示 (-l / -la)
		print_debug("[is_long]:",processed_list)
		for file_info in processed_list:
			if typeof(file_info) != TYPE_DICTIONARY:
				continue

			var entry_name = file_info.get("name", "")
			var type_char = "d" if file_info.get("type", "") == "directory" else "-"
			
			if entry_name.is_empty() and file_info.has("path"):
				entry_name = file_info.path.trim_suffix("/").get_file()
			
			if !show_all and entry_name.is_empty() and entry_name != "." and entry_name != "..":
				continue
				
			# 🛠️ 修正 3: パイプとタブを削除し、標準形式に修正
			output += "%s%s\t%6d\t| %s\n" % [
				type_char,
				file_info.get("permissions", "---------"),
				file_info.get("size", 0),
				entry_name
			]
		output = output.strip_edges(true, false)

	else:
		# 簡易リスト表示 (ls / ls -a)
		var file_names: Array[String] = []
		for file in processed_list:
			var entry_name: String
			
			# Dictionaryの場合
			if typeof(file) == TYPE_DICTIONARY and file.has("name"):
				entry_name = file.name
			
			# VirtualFileの場合 (has("path")を "path" in file に変更)
			elif file is RefCounted: 
				if "path" in file and !file.path.is_empty():
					entry_name = file.path.trim_suffix("/").get_file()
			
			# Stringの場合
			elif typeof(file) == TYPE_STRING:
				entry_name = file.trim_suffix("/").get_file()

			if !entry_name.is_empty():
				file_names.append(entry_name)

		output = " / ".join(file_names)
		
	return { "stdout": output, "stderr": "", "exit_code": 0 }
