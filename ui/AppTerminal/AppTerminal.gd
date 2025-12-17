# res://ui/AppTerminal/AppTerminal.gd

extends Control
class_name AppTerminal

@onready var output_label: RichTextLabel = $TerminalLayout/Output
@onready var input_text: LineEdit = $TerminalLayout/InputLine/InputText
@onready var prompt_label: Label = $TerminalLayout/InputLine/PromptLabel

var command_interpreter: CommandInterpreter = CommandInterpreter.new()
var user_fs: VirtualFilesystem = null # GL_MissionLoaderから渡される

var title: String = ""

func _ready() -> void:
	initialize()
	input_text.call_deferred("grab_focus")

# 従来の initialize_terminal を、より汎用的な initialize に変更し、
# 必要なデータは initial_data から取得するようにします。
func initialize():
	# ターミナルが必要とする VirtualFilesystem を initial_data から取得
	var fs = MissionLoader.getUserFileSystem()
	
	if is_instance_valid(fs):
		user_fs = fs
		# コマンドインタープリタの初期化とコマンド登録
		command_interpreter.initialize() 

		# --- ここで作業ディレクトリを同期する！ ---
		# ファイルシステムのルート (例: /home/user) を初期パスとして設定
		var initial_path = user_fs.get_root()
		command_interpreter.set_current_path(initial_path)
		# -------------------------------------
		
		# 初回起動メッセージとプロンプト表示
		_update_prompt()
		
		# 入力フィールドのシグナル接続
		input_text.text_submitted.connect(_on_input_submitted)
		
		# MDIアクティブ化のシグナル接続
		var mdi_window_root = get_parent() 
		if mdi_window_root and is_instance_valid(mdi_window_root):
			if mdi_window_root.has_signal("activated"):
				mdi_window_root.activated.connect(_on_window_activated)
			
			# ★ 修正箇所: 非アクティブ化シグナルの接続を追加 (mdi_base_window.gd にこのシグナルが必要です)
			if mdi_window_root.has_signal("deactivated"):
				mdi_window_root.deactivated.connect(_on_window_deactivated)
		
	else:
		# VFSがない場合はエラーメッセージを表示して起動
		_print_output("[color=red]FATAL ERROR: VirtualFilesystem instance is missing. Terminal cannot function.[/color]")
		_update_prompt()

## プロンプト表示を更新する (user@ip:path$)
func _update_prompt():
	# GL_Env (Autoload) から現在の環境情報を取得
	var user = GlEnv.current_user
	var ip = GlEnv.user_ip_address
	var path = command_interpreter._current_path # CommandInterpreterが保持する現在のパス
	
	prompt_label.text = "%s:%s$ " % [user, path]

## ユーザーがコマンドを入力し、Enterキーを押したときに呼ばれる
func _on_input_submitted(command_line: String):
	# 1. コマンド履歴に出力
	
	# 2. 入力フィールドをクリア
	input_text.clear()
	
	if command_line.is_empty():
		_update_prompt()
		return

	# 3. CommandInterpreterを実行
	# user_fs (VirtualFilesystem) を引数として渡す
	var result = command_interpreter.interpret_and_execute(command_line, user_fs)
	
	# 4. 結果をOutputに出力
	if !result.stdout.is_empty():
		_print_output(result.stdout)
		
	if !result.stderr.is_empty():
		# エラーは赤字で表示 (RichTextLabelの機能を利用)
		_print_output("[color=red]Error: %s[/color]" % result.stderr)

	# 5. プロンプトを更新し、入力フィールドにフォーカスを戻す
	_update_prompt()
	
	#input_text.call_deferred("grab_focus")
	# スクロールを一番下へ移動 (未実装だが将来必要)
	# output_label.call_deferred("scroll_to_line", output_label.get_line_count() - 1)

## RichTextLabelに出力し、最下部までスクロールするヘルパー関数
func _print_output(text: String):
	print("_print_output text value: ", text)
	# RichTextLabelは、改行コード(\n)を自動では改行として扱わないため、
	# 'append_text' の代わりに 'text' を直接操作する。
	# ここでは簡易化のため、\nを[br]タグに置換して追記する
	# 正確には、特殊文字のエスケープ処理が必要だが、一旦簡易実装として進める。
	#var formatted_text = text.replace("\\n", "\n")
	output_label.append_text(text + "\n")
	# スクロールを強制的に最下部に移動
	output_label.scroll_to_line(output_label.get_line_count())

# MDIウィンドウがアクティブになったときの処理
func _on_window_activated():
	# MDIウィンドウがクリックされ最前面に来たら、入力フィールドにフォーカスを当てる
	# call_deferredを削除し、すぐに grab_focus を呼び出す方が確実な場合が多いです。
	input_text.grab_focus()

# MDIウィンドウが非アクティブになったときの処理
func _on_window_deactivated():
	# MDIウィンドウが非アクティブになったら、入力フィールドのフォーカスを解除する
	input_text.release_focus()

## 外部からターミナルにフォーカスを要求する（mdi_base_window.gdから呼ばれる）
func request_focus():
	# call_deferred でフォーカスを要求
	# MDIウィンドウがアクティブ化されたときに _on_window_activated が呼ばれるため、
	# ここは call_deferred で安全に処理します。
	input_text.call_deferred("grab_focus")
