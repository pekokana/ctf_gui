# res://engine/terminal/cli_command.gd

class_name CLICommand
extends RefCounted

## コマンド名 (例: "ls", "cat", "ping")
var name: String
## コマンドの簡単な説明
var description: String
## コマンドの使用方法
var usage: String
## バージョン情報 (例: "1.0.0")
var version: String

## コマンド実行ロジック (サブクラスでオーバーライド)
## @param args: Array[String] - コマンド引数の配列
## @param current_path: String - 現在の作業ディレクトリ
## @param input_data: String - パイプ '|' から渡された入力データ
## @return Dictionary: { "stdout": String, "stderr": String, "exit_code": int }
func execute(args: Array[String], current_path: String, input_data: String = "", fs: VirtualFilesystem = null) -> Dictionary:
	push_error("CLICommand.execute() must be overridden in subclass.")
	return {
		"stdout": "", 
		"stderr": "Error: Command not implemented.", 
		"exit_code": 1
	}
