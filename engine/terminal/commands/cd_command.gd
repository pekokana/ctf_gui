# res://engine/terminal/commands/cd_command.gd

class_name CdCommand
extends CLICommand

func _init():
	name = "cd"
	description = "現在の作業ディレクトリを変更する。"
	usage = "cd [directory_path]"
	version = "1.0.0"

## コマンド実行ロジック
func execute(args: Array[String], current_path: String, input_data: String = "", fs: VirtualFilesystem = null) -> Dictionary:
	# MissionLoaderはAutoload（シングルトン）なのでどこからでもアクセス可能
	#var fs: VirtualFilesystem = MissionLoader.user_fs

	var target_path: String
	if args.size() == 0:
		# 引数なしの場合、ホームディレクトリ（暫定的にルート "/"）に移動
		target_path = "/"
	else:
		target_path = args[0]
	
	# 1. パスの解決と正規化
	var new_path = fs.resolve_path(current_path, target_path)
	
	# 2. ディレクトリの存在と有効性を確認
	if !fs.is_directory(new_path):
		var error_message: String
		
		# 移動先がファイルだった場合のエラーメッセージ
		if fs.find_file(new_path):
			error_message = "Error: cd: '%s': Not a directory." % target_path
		else:
			# パス自体が存在しない場合のエラーメッセージ
			error_message = "Error: cd: '%s': No such file or directory." % target_path
			
		return {
			"stdout": "", 
			"stderr": error_message, 
			"exit_code": 1,
			"new_path": "" # パス変更なし
		}
		
	# 3. 成功: 新しいパスを CommandInterpreter に伝えるために "new_path" キーを含める
	return { 
		"stdout": "", 
		"stderr": "", 
		"exit_code": 0, 
		"new_path": new_path # CommandInterpreterがこのキーを見てパスを更新する
	}
