# res://ui/AppExplorer/AppFileExplorer.gd
extends Control

class_name AppFileExplorer

# VFSへの参照を保持 (MissionLoaderから取得すると想定)
var vfs_instance = null
var current_path: String = "/"

@onready var path_line_edit: LineEdit = $VBoxContainer/HBoxContainer/PathLineEdit
@onready var up_button: Button = $VBoxContainer/HBoxContainer/UpButton
@onready var file_list: ItemList = $VBoxContainer/ItemList
@onready var context_menu: PopupMenu = $ContextMenu

# 処理のために、右クリックされたアイテムのインデックスを保存する変数
var _context_menu_target_index: int = -1

func _ready():
	# 1. VFSインスタンスの取得
	if is_instance_valid(MissionLoader) and MissionLoader.user_fs:
		vfs_instance = MissionLoader.user_fs
	
	if not vfs_instance:
		print("File Explorer: VFS instance is missing.")
		return

	# 2. シグナル接続
	up_button.pressed.connect(func(): _navigate_to("..")) # フォルダを一つ上がる
	file_list.item_activated.connect(_on_file_item_activated) # ファイル/フォルダのダブルクリック
	# 右クリックシグナルの接続
	file_list.item_clicked.connect(_on_file_item_clicked)

	# PopUpMenuのitem_pressedシグナルを接続
	context_menu.id_pressed.connect(_on_context_menu_item_pressed)

	# 3. 初期ディレクトリの表示
	_display_directory(vfs_instance.get_root())

## 指定されたパスのコンテンツを表示する
func _display_directory(path: String):
	if not vfs_instance: return
	
	# パスを正規化（例: 'a/b/../c' -> 'a/c'）
	var new_path = _normalize_path(path)
	
	# フォルダが存在するかチェック (ここではVFSメソッドを仮定)
	if not vfs_instance.is_directory(new_path):
		print("File Explorer: Directory does not exist: %s" % new_path)
		return

	current_path = new_path
	path_line_edit.text = current_path
	file_list.clear()

	# ディレクトリ内のアイテムを取得 (VFSメソッドを仮定)
	var items: Array = vfs_instance.list_directory(current_path)

	for item in items:
		var is_dir = item.is_directory()

		# 1. アイテム名を取得 (VFSのパスから)
		# VirtualFileのpathプロパティからファイル名部分を取得
		var item_name = item.path.get_file()
		
		# 2. VFSが生成した仮想ディレクトリのパス末尾の '/' 処理を考慮
		if is_dir and item_name.is_empty() and item.path != "/":
			# 例: "/home/" -> "home"
			item_name = item.path.trim_suffix("/").get_file()
		
		# 3. '.' と '..' を除くフィルタリングを意図的に削除 (または ItemListに含めない)
		#if item_name == "." or item_name == "..":
			## ItemListには標準で表示しない（上へボタンを使うため）
			## ただし、現状はデバッグのため表示しても良いが、ここではスキップする
			#continue 
			
		# 4. アイテム名が空の場合もスキップ (念のため)
		if item_name.is_empty():
			continue 

		var index = file_list.add_item(item_name)
		
		# パス結合に VFS の resolve_path を使用する 
		var next_path = vfs_instance.resolve_path(current_path, item_name)
		
		if is_dir:
			file_list.set_item_icon(index, load("res://assets/icons/folder_icon.svg")) # フォルダアイコン
			file_list.set_item_metadata(index, {"type": "dir", "path": next_path})
		else:
			file_list.set_item_icon(index, load("res://assets/icons/file_icon.svg")) # ファイルアイコン
			file_list.set_item_metadata(index, {"type": "file", "path": next_path})

## アイテムがダブルクリックされたときの処理
func _on_file_item_activated(index: int):
	var metadata = file_list.get_item_metadata(index)
	var item_name = file_list.get_item_text(index)

	
	if metadata.type == "dir":
		# ★ 修正: '.' と '..' の特殊処理を追加
		if item_name == "..":
			_navigate_to("..") # '..' がダブルクリックされたら親へ移動
			return
		elif item_name == ".":
			# '.' はカレントディレクトリなので、何もしない
			return

		# ... (既存のディレクトリ移動ロジック) ...
		var target_path = vfs_instance.resolve_path("/", metadata.path)
		_display_directory(target_path) 

	elif metadata.type == "file":
		# ★ 修正: ファイルの内容を読み込み、表示する
		var file_path = metadata.path
		
		# VFSから内容を読み込む
		var content = vfs_instance.read_file(file_path)
		
		# デバッグ目的でコンソールに出力
		print("--- File Content ---")
		print("Path: ", file_path)
		print("Content:\n", content)
		print("--------------------")
		# 実際のアプリでは、ここでファイルビューアを起動する関数を呼び出します
		_view_file_content(file_path, content)

## ディレクトリナビゲーション
func _navigate_to(target: String):
	if target == "..":
		var parts = Array(current_path.split("/"))
		# ルート（/）にいる場合はそれ以上上がらない
		if parts.size() <= 1 and current_path == "/":
			return
			
		parts.pop_back()
		var parent_path = "/".join(parts)
		if parent_path.is_empty():
			parent_path = "/"
			
		_display_directory(parent_path)
	else:
		_display_directory(target)

## パスを正規化するヘルパー関数 (例: path/./other -> path/other)
func _normalize_path(path: String) -> String:
	var parts = path.split("/", false)
	var normalized: Array = []
	
	for part in parts:
		if part.is_empty() or part == ".":
			continue
		elif part == "..":
			if not normalized.is_empty():
				normalized.pop_back()
		else:
			normalized.append(part)
	
	return "/" + "/".join(normalized)

## ファイルの内容をユーザーに表示する (プレースホルダー)
func _view_file_content(path: String, content: String):
	# 将来的には、ここで AppFileManager や AppTextViewer などの別のGUIアプリを起動します。
	
	# 現状は、Godotの組み込みの通知機能を使って内容を簡易表示してみます。
	# (例: Notification/Label/PanelなどをAppFileExplorerのシーンに追加している場合)
	
	# シンプルに、通知メッセージを表示する処理（プロジェクトに実装がある場合）を想定
	# 例: get_node("/root/NotificationSystem").show_message("File: " + path, content)
	
	# ここでは、コンソール出力以外に特別な処理は行いませんが、
	# ユーザーインターフェース (UI) の実装がある場合は、そちらに統合してください。
	pass

## アイテムがクリックされたときの共通処理 (左/右ボタンをここで区別する)
## アイテムがクリックされたときの共通処理 (左/右ボタンをここで区別する)
func _on_file_item_clicked(index: int, at_position: Vector2, mouse_button_index: int):
	
	if mouse_button_index == MOUSE_BUTTON_RIGHT:
		# 右クリックの場合
		
		# 選択状態を解除し、右クリックされたアイテムを選択状態にする
		file_list.select(index, true)
		
		# ターゲットインデックスを保存
		_context_menu_target_index = index
		
		# マウスカーソルの位置にメニューを表示
		context_menu.position = file_list.get_viewport().get_mouse_position()
		context_menu.popup()

	elif mouse_button_index == MOUSE_BUTTON_LEFT:
		# ... (左クリック処理は省略) ...
		pass

## パスをクリップボードにコピーする処理を独立させる
func _copy_path_to_clipboard(index: int):
	var metadata = file_list.get_item_metadata(index)
	var item_name = file_list.get_item_text(index)
	
	if metadata.has("path"):
		var path_to_copy = metadata.path as String
		
		# . や .. のエントリはスキップ (意図しないパスのコピーを防ぐため)
		if item_name == "." or item_name == "..":
			print("Explorer: Cannot copy special entry '", item_name, "'.")
			return

		# クリップボードへのコピー
		DisplayServer.clipboard_set(path_to_copy)
		
		print("Explorer: Copied path to clipboard: ", path_to_copy)
	else:
		print("Explorer: Path metadata not found for item.")

## ContextMenuのアイテムがクリックされたときの処理
func _on_context_menu_item_pressed(id: int):
	# ID 1 は "パスをコピー"
	if id == 1:
		if _context_menu_target_index != -1:
			_copy_path_to_clipboard(_context_menu_target_index)
			
		# 処理が終わったら、ターゲットインデックスをリセット
		_context_menu_target_index = -1
