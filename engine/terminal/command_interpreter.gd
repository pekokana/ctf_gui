# res://engine/terminal/command_interpreter.gd

extends RefCounted
class_name CommandInterpreter

# 登録済みコマンドのマップ { "command_name": CLICommand Class }
var _registered_commands: Dictionary = {}
var _history: Array[String] = []
var _history_index: int = -1
var _current_path: String = "/"

## 初期化: 全てのコマンドをロードし、登録する
func initialize():
	_registered_commands.clear()
	
	# GodotのDirectory/FileAccessを使用してコマンドファイルを自動で見つける (拡張ポイント)
	# 現状は手動で追加:
	_register_command(CatCommand.new())
	_register_command(LsCommand.new())
	_register_command(PingCommand.new())
	_register_command(CdCommand.new())
	_register_command(NmapCommand.new())

## 作業ディレクトリを強制的に設定する (初期化用)
func set_current_path(path: String):
	_current_path = path
	# 末尾が / で終わっていない場合は調整しておくと安全です
	if !_current_path.ends_with("/"):
		_current_path += "/"

## 現在のパスを取得する (念のため)
func get_current_path() -> String:
	return _current_path

func _register_command(command_instance: CLICommand):
	_registered_commands[command_instance.name] = command_instance
	
## コマンドラインの文字列を解析し、実行するメインメソッド
func interpret_and_execute(command_line: String, fs: VirtualFilesystem) -> Dictionary: # <--- fs引数を追加
	if command_line.is_empty():
		return { "stdout": "", "stderr": "", "exit_code": 0 }
		
	# 履歴に追加 (重複防止やフィルタリングは省略)
	_history.append(command_line)
	_history_index = _history.size()

	# パイプ '|' による分割
	var parts = command_line.split("|", false)
	var input_data = ""
	var last_result: Dictionary = { "stdout": "", "stderr": "", "exit_code": 0 }
	
	for part in parts:
		part = part.strip_edges()
		if part.is_empty():
			continue
			
		# リダイレクト '>' の処理 (今回は簡単のために最後のパイプでのみ処理を想定)
		var redirect_target = ""
		var original_command = part
		if part.find(">") != -1:
			var redirect_parts = part.split(">", false)
			original_command = redirect_parts[0].strip_edges()
			redirect_target = redirect_parts[1].strip_edges()

		# コマンドと引数の解析
		var tokens = original_command.split(" ", false)
		var cmd_name = tokens[0]
		var args = tokens.slice(1)
		
		var result = _execute_single_command(cmd_name, args, input_data, fs)

		# === パスの変更を検出 (CdCommand の副作用処理) ===
		if result.has("new_path") and typeof(result.new_path) == TYPE_STRING:
			var new_path = result.new_path
			if !new_path.is_empty():
				_current_path = new_path
				# AppTerminal のプロンプト更新のため、CommandInterpreter のパスが更新されたことを AppTerminal が知る必要がある。
				# AppTerminal はこの関数の戻り値を処理した後でプロンプトを再描画するため、ここでは _current_path の更新のみを行う。
		# ===============================================

		# パイプ処理: 次のコマンドの入力は現在のコマンドの stdout
		input_data = result.stdout
		last_result = result
		
		# エラーが発生したらパイプラインを中断
		if result.exit_code != 0:
			break

		# リダイレクト処理
		if !redirect_target.is_empty() and part == parts.back():
			return _handle_redirect(redirect_target, result, fs) # <--- fsを渡す

	# 最終結果を返す
	return last_result

## 単一コマンドを実行する
func _execute_single_command(cmd_name: String, args: Array[String], input_data: String, fs: VirtualFilesystem) -> Dictionary:
	if _registered_commands.has(cmd_name):
		var cmd_instance: CLICommand = _registered_commands[cmd_name]
		return cmd_instance.execute(args, _current_path, input_data, fs)
	else:
		return {
			"stdout": "",
			"stderr": "Error: Command '%s' not found." % cmd_name,
			"exit_code": 1
		}

## リダイレクト '>' を処理する
func _handle_redirect(target_path: String, result: Dictionary, fs: VirtualFilesystem) -> Dictionary:
	var success = fs.write_file(target_path, result.stdout)
	if success:
		return { "stdout": "", "stderr": "", "exit_code": 0 }
	else:
		return { "stdout": "", "stderr": "Error: Failed to write to file '%s'." % target_path, "exit_code": 1 }

## オートコンプリート候補の取得 (拡張ポイント)
func get_autocomplete_candidates(partial_input: String) -> Array[String]:
	var candidates: Array[String] = []
	
	# 1. コマンド名の候補
	for cmd_name in _registered_commands.keys():
		if cmd_name.begins_with(partial_input):
			candidates.append(cmd_name)
	
	# 2. ファイルパスの候補 (現在のディレクトリから)
	# ...
	
	return candidates
