extends RefCounted
class_name ProgressStore

# Offline progression. Never trusts a corrupted save to unlock nonexistent
# levels. File writes go to a temporary file before replacing the old save.
const SAVE_PATH: String = "user://parcel_pulse_progress.json"
const SAVE_VERSION: int = 1


static func initial_profile() -> Dictionary:
	return {"version": SAVE_VERSION, "unlocked": 1, "best": {}}


static func sanitize(candidate: Variant) -> Dictionary:
	var result: Dictionary = initial_profile()
	if not candidate is Dictionary:
		return result
	var input: Dictionary = candidate
	if int(input.get("version", -1)) != SAVE_VERSION:
		return result
	result["unlocked"] = clampi(int(input.get("unlocked", 1)), 1, LevelCatalog.count())
	var stored_best: Dictionary = input.get("best", {}) if input.get("best", {}) is Dictionary else {}
	var clean_best: Dictionary = {}
	for index in range(LevelCatalog.count()):
		var key: String = str(index)
		if not stored_best.has(key) or not stored_best[key] is Dictionary:
			continue
		var entry: Dictionary = stored_best[key]
		clean_best[key] = {
			"score": clampi(int(entry.get("score", 0)), 0, 10000000),
			"stars": clampi(int(entry.get("stars", 0)), 0, 3),
		}
	result["best"] = clean_best
	return result


static func load_profile(path: String = SAVE_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return initial_profile()
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return initial_profile()
	var payload: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(payload)
	return sanitize(parsed)


static func is_unlocked(profile: Dictionary, level_index: int) -> bool:
	return level_index >= 0 and level_index < LevelCatalog.count() and level_index < int(profile.get("unlocked", 1))


static func record_win(profile: Dictionary, level_index: int, score: int, mistakes: int) -> Dictionary:
	var result: Dictionary = sanitize(profile)
	if not is_unlocked(result, level_index):
		return result
	var key: String = str(level_index)
	var record: Dictionary = result["best"]
	var previous: Dictionary = record.get(key, {"score": 0, "stars": 0})
	record[key] = {
		"score": maxi(int(previous.get("score", 0)), maxi(0, score)),
		"stars": maxi(int(previous.get("stars", 0)), clampi(3 - mistakes, 1, 3)),
	}
	result["best"] = record
	result["unlocked"] = mini(LevelCatalog.count(), maxi(int(result["unlocked"]), level_index + 2))
	return result


static func save_profile(profile: Dictionary, path: String = SAVE_PATH) -> bool:
	var cleaned: Dictionary = sanitize(profile)
	var temp_path: String = path + ".tmp"
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(cleaned))
	file.flush()
	var write_result: Error = file.get_error()
	file.close()
	if write_result != OK:
		return false
	var move_result: Error = DirAccess.rename_absolute(
		ProjectSettings.globalize_path(temp_path),
		ProjectSettings.globalize_path(path)
	)
	return move_result == OK


static func completed_count(profile: Dictionary) -> int:
	var best: Dictionary = profile.get("best", {})
	var completed: int = 0
	for index in range(LevelCatalog.count()):
		var record: Variant = best.get(str(index), {})
		if record is Dictionary and int(record.get("stars", 0)) > 0:
			completed += 1
	return completed


static func recommended_level(profile: Dictionary) -> int:
	# Recommend the first unlocked but uncleared map. If all available maps
	# have been cleared, suggest the highest unlocked level for replay.
	var unlocked: int = clampi(int(profile.get("unlocked", 1)), 1, LevelCatalog.count())
	var best: Dictionary = profile.get("best", {})
	for index in range(unlocked):
		var record: Variant = best.get(str(index), {})
		if not record is Dictionary or int(record.get("stars", 0)) <= 0:
			return index
	return unlocked - 1
