extends Control

class_name AppProcessMonitor # アプリケーションのコンテンツクラス

@onready var process_list_label: RichTextLabel = $VBoxContainer/ProcessListLabel
@onready var refresh_button: Button = $VBoxContainer/RefreshButton

# ProcessManagerへの参照を、Autoload経由で取得
# CL_ProcessManager が ProcessManager.gd の class_name であることを確認してください
var process_manager = CL_ProcessManager 

func _ready():
	# リフレッシュボタンの pressed シグナルを接続
	refresh_button.pressed.connect(_on_refresh_button_pressed)
	
	# 初回表示時にプロセス一覧を更新
	_update_process_list()

## リフレッシュボタンが押されたときに呼ばれる関数
func _on_refresh_button_pressed():
	_update_process_list()

## プロセス一覧を更新する内部関数
func _update_process_list():
	if not is_instance_valid(process_manager):
		process_list_label.text = "[color=red]Error: ProcessManager not loaded.[/color]"
		return

	# ProcessManagerから整形済みのプロセス一覧文字列を取得
	var process_info_string = process_manager.list_processes()
	process_list_label.text = process_info_string
	
	# RichTextLabelのスクロールを一番下にする (オプション)
	process_list_label.scroll_to_line(process_list_label.get_line_count() - 1)

# MDIウィンドウがアクティブになったときに呼ばれる可能性のあるメソッド（Option: MDIWindowからactivatedシグナルで接続）
# func request_focus():
# 	_update_process_list()
