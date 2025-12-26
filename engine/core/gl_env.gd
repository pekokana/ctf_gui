# res://engine/gl_env.gd

extends Node
class_name GL_Env

## ユーザー端末の仮想IPアドレス (MissionLoaderによって設定される)
var user_ip_address: String = "0.0.0.0" 

## 現在のミッションID
var current_mission_id: String = ""

## 現在のユーザーセッション情報 (今回は簡易的なユーザー名)
var current_user: String = "user" 

## 現在の作業ディレクトリ (ターミナルと連携)
var current_working_directory: String = "/"

# MissionLoaderから呼ばれる設定関数 (MissionLoader.gd の修正提案を参照)
func set_environment(user_ip: String, mission_id: String):
	self.user_ip_address = user_ip
	self.current_mission_id = mission_id

# ----------
# ヘルパーメソッド
# ----------

# 実行中のノードツリー全体を出力するヘルパー関数
# 使い方：GlEnv.print_node_struct("ほげ", get_tree().get_root())
func print_node_struct(title: String, node: Node, indent: int = 0) -> void:
	print("====================================")
	print(title)
	print("====================================")
	print_node_tree(node, indent)
	
func print_node_tree(node: Node, indent: int = 0) -> void:
	# インデントを作成
	var prefix = ""
	for i in range(indent):
		prefix += "  "
	
	var type_name = node.get_class()
	var line = prefix + "|-- " + node.name + " (" + type_name + ")"
	
	# スクリプトがアタッチされている場合はそのパスも表示
	var script = node.get_script()
	if script != null:
		line += " [Script]" # 詳細なパスは長くなるため[Script]のみ
		
	print(line)

	# スクリプトに定義されているメソッド一覧を出力
	if script != null and script is Script:
		var method_list = script.get_script_method_list()
		if not method_list.is_empty():
			var methods_str = []
			for method in method_list:
				# 辞書の'name'キーから関数名を取得
				methods_str.append(method.name)
			
			# メソッドリストを整形して出力
			# 組み込み関数（_readyなど）は除外されないため、全て出力されます。
			print(prefix + "  |-> Methods: [" + ", ".join(methods_str) + "]")

	# 子ノードを再帰的に処理
	for child in node.get_children():
		print_node_tree(child, indent + 1)
