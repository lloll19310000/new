extends Node
## The shared job board. Things that need doing post a job here,
## and staff claim the best one for them.

const Job = preload("res://people/job.gd")

var jobs: Array = []
var version := 0              # goes up whenever a job is posted, claimed, released or finished
var _open_cache: Array = []
var _open_key := Vector2(-1, -1)


func post(type: String, kind: String, fields: Dictionary = {}):
	var j = Job.new()
	j.type = type
	j.kind = kind
	j.created = GameState.minute
	for k in fields:
		j.set(k, fields[k])
	jobs.append(j)
	version += 1
	return j


func open_jobs() -> Array:
	var now := GameState.sim_time
	# many idle staff look at the board in the same step: work it out once
	var k := Vector2(version, now)
	if k != _open_key:
		_open_key = k
		_open_cache = jobs.filter(func(j): return j.claimed_by == null and not j.done and j.retry_at <= now)
	return _open_cache


## Customer jobs (cooking, serving, washing) nobody has picked up yet: how swamped the crew is.
func waiting_count() -> int:
	var n := 0
	for j in jobs:
		if not j.done and j.claimed_by == null and j.type in ["cook", "serve", "host", "wash"]:
			n += 1
	return n


func claim(j, who) -> void:
	j.claimed_by = who
	version += 1


func release(j, cooldown: float = 0.0) -> void:
	if j != null and not j.done:
		j.claimed_by = null
		j.retry_at = GameState.sim_time + cooldown
		version += 1


func finish(j) -> void:
	if j == null:
		return
	j.done = true
	jobs.erase(j)
	version += 1


func has_open(kind: String, match_field: String, value) -> bool:
	for j in jobs:
		if j.kind == kind and not j.done and j.get(match_field) == value:
			return true
	return false


func has_unclaimed(kind: String, match_field: String, value) -> bool:
	for j in jobs:
		if j.kind == kind and not j.done and j.claimed_by == null and j.get(match_field) == value:
			return true
	return false


## Drops jobs that no longer make sense (the customers left, the table is clean...).
func prune(lot) -> void:
	for j in jobs.duplicate():
		if j.claimed_by != null:
			continue
		if still_needed(j, lot):
			continue
		finish(j)


func still_needed(j, lot) -> bool:
	var g = j.group
	var g_ok: bool = g != null and is_instance_valid(g) and g.state != "leaving" and g.state != "gone"
	match j.kind:
		"take_order":
			return g_ok and g.state == "seated"
		"cook":
			return g_ok and g.state == "ordered"
		"prep":
			return Data.DISHES.has(j.dish) and GameState.dish_on(j.dish)
		"greet":
			return g_ok and g.state == "waiting" and not g.greeted
		"till", "check":
			return g_ok and g.state == "paying"
		"complaint":
			return g_ok and g.state == "complaining"
		"mediate":
			return Crew.valid_here(j.who) and Crew.valid_here(j.who2)
		"checkin":
			return Crew.valid_here(j.who) and j.who.stress >= Data.CHECKIN_AT - 15.0
		"scrub":
			return j.furniture != null and lot.furniture.has(j.furniture) and j.furniture.grime > 0.1
		"trash":
			return j.furniture != null and lot.furniture.has(j.furniture) and j.furniture.fill > (0.03 if GameState.phase == GameState.Phase.CLEANUP else 0.2)
		"restock":
			return j.furniture != null and lot.furniture.has(j.furniture) and not j.furniture.stocked
		"deliver":
			if not g_ok:
				return false
			for f in lot.of_type("pass"):
				for it in f.items:
					if it["group"] == g:
						return true
			return false
		"bus":
			return j.furniture != null and lot.furniture.has(j.furniture) and j.furniture.dirty_plates > 0
		"collect":
			return j.furniture != null and lot.furniture.has(j.furniture) and j.furniture.cash > 0.0
		"refill":
			return g_ok and g.state == "eating" and g.wants_refill
		"crayons":
			return g_ok and not g.crayons and g.state in ["seated", "ordered", "eating"]
		"wash":
			return j.furniture != null and lot.furniture.has(j.furniture) and j.furniture.dirty > 0
		"sweep":
			return lot.in_lot(j.cell) and lot.dirt[lot.idx(j.cell)] >= Data.DIRT_SHOW
		"repair":
			return j.furniture != null and lot.furniture.has(j.furniture) and j.furniture.broken
		"service":
			return j.furniture != null and lot.furniture.has(j.furniture) and not j.furniture.broken and j.furniture.wear >= Data.SERVICE_AT * 0.5
	return true


func cancel_for_group(group) -> void:
	for j in jobs.duplicate():
		if j.group == group and j.claimed_by == null:
			finish(j)


func clear() -> void:
	jobs.clear()
	version += 1


func count_by_type() -> Dictionary:
	var out := {}
	for t in Data.JOBS:
		out[t] = 0
	for j in jobs:
		if not j.done:
			out[j.type] += 1
	return out
