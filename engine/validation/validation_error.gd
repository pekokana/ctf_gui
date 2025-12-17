# res://engine/validation/validation_error.gd

class_name ValidationError
extends RefCounted # メモリ管理のために継承

## エラーカテゴリ: STRUCTURE_ERROR, TYPE_ERROR, FORMAT_ERROR, DUPLICATE_ERROR, CONFLICT_ERROR, UNSUPPORTED_ERROR, GENERATOR_ERROR
var category: String
## JSON内のパス: servers[1].id
var path: String
## 人間が読むためのメッセージ
var message: String

func _init(p_category: String, p_path: String, p_message: String):
	category = p_category
	path = p_path
	message = p_message

func to_debug_string() -> String:
	return "[%s] Path: %s | Message: %s" % [category, path, message]
