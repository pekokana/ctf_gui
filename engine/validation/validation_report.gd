# res://engine/validation/validation_report.gd

class_name ValidationReport
extends RefCounted

var valid: bool = true
var warnd: bool = true
var errors: Array[ValidationError] = []
var warns: Array[ValidationError] = []

## エラーを追加し、valid フラグを false に設定する
func add_error(category: String, path: String, message: String):
	valid = false
	var error = ValidationError.new(category, path, message)
	errors.append(error)

## 警告を追加し、warnd フラグを false に設定する
## MainDesktop.gdのミッションロード後に参考のため表示する
func add_warn(category: String, path: String, message: String):
	warnd = false
	var warn = ValidationError.new(category, path, message)
	warns.append(warn)
