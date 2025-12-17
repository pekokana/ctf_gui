# res://ui/app_window.gd

extends PanelContainer
class_name AppWindow

@export var title: String = "Application Window"

@onready var title_bar: Control = $TitleBar
@onready var close_button: Button = $TitleBar/CloseButton

var _is_dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO

func _ready():
	# 閉じるボタンの接続
	close_button.pressed.connect(queue_free)
	
	# タイトルを設定
	_set_title(title)

## ウィンドウタイトルを更新する
func _set_title(new_title: String):
	# ラベルノードにタイトルをセットする処理 (UIシーン構築後に実装)
	pass # $TitleBar/TitleLabel.text = new_title

## ドラッグと移動の処理
func _gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			# タイトルバー領域内でのみドラッグを開始・終了
			var title_bar_rect = title_bar.get_global_rect()
			if title_bar_rect.has_point(event.global_position):
				_is_dragging = event.pressed
				if _is_dragging:
					# ドラッグ開始時のオフセットを計算
					_drag_offset = event.position 
			else:
				_is_dragging = false
	
	elif event is InputEventMouseMotion and _is_dragging:
		position += event.relative
		
		# ウィンドウの境界制限 (画面外に出ないようにする)
		# position.x = clampf(position.x, 0, get_parent().size.x - size.x)
		# position.y = clampf(position.y, 0, get_parent().size.y - size.y)
