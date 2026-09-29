extends RefCounted
static func load_rules() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/residence_interiors.json"))
