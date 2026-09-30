extends Node
## The Goals board: optional milestones for your diner, with no end to the
## game. Each one reached unlocks a reward: a recipe, a piece of decor or a
## bit of cash. Checked every night (and when you load).

signal changed

var done: Dictionary = {}      # goal key -> the day it was reached


func reset() -> void:
	done = {}


## [how far along, the target] for a goal.
func progress(key: String) -> Array:
	var t: Dictionary = GameState.totals
	match key:
		"first_week":
			return [mini(GameState.day - 1, 7), 7]
		"breakfast":
			return [int(t.get("breakfast_served", 0)), 60]
		"regular_heart":
			var best := 0.0
			for r in Front.known():
				best = maxf(best, r["loyalty"])
			return [1 if t.get("heart_full", false) else 0, 1] if t.get("heart_full", false) else [int(best), 100]
		"critic_all":
			var want: Array = Data.DISH_ORDER.filter(func(d): return not Data.DISHES[d].get("locked", false))
			var had: Array = t.get("critic_dishes", [])
			return [want.filter(func(d): return had.has(d)).size(), want.size()]
		"no_quit":
			return [mini(GameState.day - int(t.get("last_quit_day", 1)), 30), 30]
		"health_a":
			var since := int(t.get("a_since", -1))
			return [0 if since < 0 or GameState.grade != "A" else mini(GameState.day - since, Data.YEAR_DAYS), Data.YEAR_DAYS]
		"served":
			return [mini(int(t.get("served", 0)), 1000), 1000]
		"five_star":
			return [int(round(float(t.get("best_end_rating", 0.0)) * 10.0)), 48]
		"eotm":
			return [mini(int(t.get("eotm", 0)), 3), 3]
		"crew12":
			return [mini(GameState.staff.size(), 12), 12]
	return [0, 1]


func is_done(key: String) -> bool:
	return done.has(key)


## Every night: anything newly reached pays out its reward.
func check(quiet: bool = false) -> Array:
	var reached: Array = []
	for g in Data.GOALS:
		var k: String = g["key"]
		if done.has(k):
			continue
		var p := progress(k)
		if p[0] >= p[1]:
			done[k] = GameState.day
			reached.append(g)
			give(g, quiet)
	if not reached.is_empty():
		changed.emit()
	return reached


func give(g: Dictionary, quiet: bool = false) -> void:
	var r: Dictionary = g["reward"]
	var what := ""
	if r.has("dish"):
		GameState.unlock_dish(r["dish"], "goal")
		what = "the %s recipe" % Data.DISHES[r["dish"]]["name"].to_lower()
	elif r.has("decor"):
		GameState.unlock_decor(r["decor"])
		what = "a %s for the diner (in Decor)" % Data.FURNITURE[r["decor"]]["name"].to_lower()
	elif r.has("money"):
		GameState.add_money(float(r["money"]))
		what = "$%d" % int(r["money"])
	if quiet:
		return
	GameState.toast.emit("Goal reached: %s! You earned %s." % [g["name"], what], "good")
	Crew.log_line("Goal reached: %s. Reward: %s." % [g["name"], what], "star")
	Sfx.play("fanfare", -4.0)


static func reward_text(g: Dictionary) -> String:
	var r: Dictionary = g["reward"]
	if r.has("dish"):
		return "Recipe: " + Data.DISHES[r["dish"]]["name"]
	if r.has("decor"):
		return "Decor: " + Data.FURNITURE[r["decor"]]["name"]
	if r.has("money"):
		return "$%d" % int(r["money"])
	return ""


func save_data() -> Dictionary:
	return {"done": done}


func load_data(d: Dictionary) -> void:
	reset()
	for k in d.get("done", {}):
		done[str(k)] = int(d["done"][k])
