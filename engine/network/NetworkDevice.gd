extends Resource
class_name NetworkDevice

## ネットワークマップ表示に必要なデータ構造

# デバイスの一意識別子 (サーバーID, クライアントIDなど)
@export var id: String = ""
@export var type: String = "client" # client, server, router, etc.
@export var label: String = "" # マップに表示する名前 (例: "Web Server 01")
@export var ip_address: String = "" # プライマリIPアドレス

# 接続情報: 接続先のデバイスのIDリスト
# (例: [ "web01", "router_a" ])
@export var connected_to: Array[String] = []

# マップ上の位置 (AppNetworkMap.gd が管理する)
@export var position: Vector2 = Vector2.ZERO

@export var is_scanned: bool = false	# スキャンされたか
@export var open_ports: Array[int] = []	# 見つかったポートのリスト
