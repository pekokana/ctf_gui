# res://engine/terminal/commands/cat_command.gd

class_name CatCommand
extends CLICommand

func _init():
	name = "cat"
	description = "ファイルの内容を標準出力に表示する。"
	usage = "cat <file_path>"
	version = "1.0.0"

func execute(args: Array[String], current_path: String, input_data: String = "", fs: VirtualFilesystem = null) -> Dictionary:
	if args.size() == 0:
		# 引数がない場合、パイプ入力があればそれを出力する
		if !input_data.is_empty():
			return { "stdout": input_data, "stderr": "", "exit_code": 0 }
			
		return { "stdout": "", "stderr": "Usage: " + usage, "exit_code": 1 }
	
	var file_path = args[0]

	# 絶対パスへの解決 ---
	# ユーザーの Virtual Filesystem にアクセスする際は、
	# 絶対パス (例: /home/user/readme.txt) が必要。
	# MissionLoader.user_fs.initialize_from_spec で初期化されたファイルは、
	# /home/user/ がルートではなく、ファイルの絶対パスでマップに格納されているため。
	
	var absolute_path = ""
	
	if file_path.begins_with("/"):
		# 既に絶対パスの場合
		absolute_path = file_path
	else:
		# 相対パスの場合、現在のディレクトリと結合
		# Unix的なパス結合: current_path が "/home/user/" で file_path が "readme.txt" の場合
		var resolved_path = current_path
		if !resolved_path.ends_with("/"):
			resolved_path += "/"
		absolute_path = resolved_path + file_path
	# -----------------------------------

	# fs引数がnullの場合のフォールバック (安全策)
	var target_fs = fs if fs else MissionLoader.user_fs

	# CommandInterpreterから渡された fs (MissionLoader.user_fs) にアクセス
	## fs引数が渡されていることを前提とします
	#var content = MissionLoader.user_fs.read_file(absolute_path) # <-- absolute_path を使用

	# file_path ではなく absolute_path を使用する
	var content = target_fs.read_file(absolute_path)
	
	if content.begins_with("Error:"):
		# VirtualFilesystem のエラーメッセージをそのまま stderr に返す
		return { "stdout": "", "stderr": content, "exit_code": 1 }
		
	return { "stdout": content, "stderr": "", "exit_code": 0 }
