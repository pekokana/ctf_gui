# res://tests/test_mission_validator.gd
extends GutTest

func _ready():
	test_all_json_files()

func test_all_json_files():
	var test_dir := "res://tests/testmission"
	var dir := DirAccess.open(test_dir)
	assert(dir != null, "テスト用ディレクトリが存在しません: %s" % test_dir)

	dir.list_dir_begin()
	var filename := dir.get_next()
	while filename != "":
		if not dir.current_is_dir() and filename.ends_with(".json"):
			var path := test_dir + "/" + filename
			var file := FileAccess.open(path, FileAccess.READ)
			assert(file != null, "JSON を開けません: %s" % path)
			var text := file.get_as_text()
			file.close()
			var json_string = JSON.stringify(text)
			var json = JSON.new()
			var parsed = json.parse(json_string)
			assert(parsed == OK, "JSON パース失敗: %s" % filename)
			var valid := GL_MissionValidator.validate(Dictionary(json_string))
			assert(valid, "Validation failed for %s:\n%s" % [filename, GL_MissionValidator.errors])
		filename = dir.get_next()
	dir.list_dir_end()
