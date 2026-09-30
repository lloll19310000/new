extends Node
## How the staff get along.
##
## Every person has an opinion of each coworker, from -100 to +100. It's one-way:
## Tunde can like Rosa while Rosa finds Tunde annoying. An opinion is two parts:
##   - a first impression (chemistry plus trait clashes) that never changes
##   - history, kept per reason ("Worked together", "Dropped plates"...), which
##     fades 5% every night
## Friends work faster side by side, rivals bicker, managers keep an eye on
## phones, and everything worth telling goes into the staff log.
##
## staff.gd and group.gd report what happened; this script decides what it
## means. Hometowns only ever change words here, never numbers.

signal log_added(entry: Dictionary)
signal changed                         # opinions or labels changed: the Crew page redraws
signal big_moment                      # new friends, best friends or rivals (lights the tab badge)

const LABEL_NAMES := {"best": "Best friends", "friends": "Friends", "friendly": "Friendly",
	"neutral": "Neutral", "tense": "Tense", "rivals": "Rivals"}
const LABEL_COLORS := {"best": Color("4fbf8f"), "friends": Color("6cc3a0"), "friendly": Color("4d7a66"),
	"neutral": Color("54473e"), "tense": Color("a8742e"), "rivals": Color("c9473d")}
const MOOD_NAMES := {"cheerful": "Cheerful", "okay": "Okay", "fed_up": "Fed up"}
const MOOD_ICONS := {"cheerful": "mood_good", "okay": "mood_okay", "fed_up": "mood_bad"}
const MOOD_COLORS := {"cheerful": Color("6cc3a0"), "okay": Color("b9a797"), "fed_up": Color("e75a4e")}

var main                               # set by main.gd: the lot and the customer groups
var opinions := {}                     # "id>id" -> {"base": {reason: pts}, "hist": {event: pts}, "day": {event: pts}}
var entries: Array = []                # the staff log, oldest first
var next_id := 1
var labels := {}                       # "lo|hi" -> label, to notice new friends and rivals
var bubbles: Array = []                # speech bubbles: {"who", "icon", "text", "t"}
var today := {}
var _acc := 0.0                        # game minutes not processed yet
var _overlap := {}                     # pair -> true while two people share a kitchen tile
var _bump_last := {}                   # pair -> when they last bumped
var _snap_last := {}                   # id -> when they last snapped
var _chat_min := {}                    # pair -> minutes chatted since their last exchange
var _snack_done := {}                  # pair -> true once this break together has had its snack roll
var _teamwork_day := -1                # the day a great order was last logged
var _checked := {}                     # id -> when a manager last checked on them
var _mediated := {}                    # pair -> true once a manager has sat them down today


func _ready() -> void:
	reset()


func reset() -> void:
	opinions = {}
	entries = []
	next_id = 1
	labels = {}
	bubbles = []
	_acc = 0.0
	_overlap = {}
	_bump_last = {}
	_snap_last = {}
	_chat_min = {}
	_snack_done = {}
	_teamwork_day = -1
	reset_today()


func reset_today() -> void:
	today = {"bickers": 0, "breakups": 0, "caught": 0, "reprimands": 0, "phone_seen": 0, "mediations": 0, "checkins": 0,
		"new_friends": [], "new_rivals": [], "work": {}, "quits": [], "burnout": []}
	_checked = {}
	_mediated = {}


func now() -> float:
	return GameState.day * 1440.0 + GameState.minute


func team() -> Array:
	return GameState.staff.filter(func(s): return is_instance_valid(s))


## Everyone at work today (not on a day off).
func present() -> Array:
	return GameState.staff.filter(func(s): return is_instance_valid(s) and s.is_here())


## Still on the team and in the building right now.
func valid_here(s) -> bool:
	return s != null and is_instance_valid(s) and GameState.staff.has(s) and s.is_here()


## A manager on shift who's up to settling things (not fed up themselves), or null.
func manager_on_shift(exclude: Array = []):
	for m in present():
		if m.manager and m.mood != "fed_up" and not m in exclude:
			return m
	return null


func by_id(id: int):
	for s in team():
		if s.id == id:
			return s
	return null


# ------------------------------------------------------------------ opinions

func key(a, b) -> String:
	return "%d>%d" % [a.id, b.id]


func pair_key(a, b) -> String:
	return "%d|%d" % [mini(a.id, b.id), maxi(a.id, b.id)]


## Gives a new person an id and a first impression of everyone (and everyone of them).
func register(s) -> void:
	if s.id <= 0:
		s.id = next_id
	next_id = maxi(next_id, s.id + 1)
	for o in team():
		if o != s:
			ensure(s, o)
			ensure(o, s)
	refresh_labels()


func forget(s) -> void:
	for k in opinions.keys():
		var ids: PackedStringArray = k.split(">")
		if int(ids[0]) == s.id or int(ids[1]) == s.id:
			opinions.erase(k)
	for k in labels.keys():
		var ids: PackedStringArray = k.split("|")
		if int(ids[0]) == s.id or int(ids[1]) == s.id:
			labels.erase(k)
	for b in bubbles.duplicate():
		if b["who"] == s:
			bubbles.erase(b)
	changed.emit()


func ensure(a, b) -> Dictionary:
	if not opinions.has(key(a, b)) or not opinions.has(key(b, a)):
		# chemistry is mostly mutual: one roll for the pair, nudged a little for each side
		var roll := randi_range(-Data.REL_CHEMISTRY, Data.REL_CHEMISTRY)
		for p in [[a, b], [b, a]]:
			var k := key(p[0], p[1])
			if not opinions.has(k):
				var chem := clampi(roll + randi_range(-4, 4), -Data.REL_CHEMISTRY, Data.REL_CHEMISTRY)
				opinions[k] = {"base": first_impression(p[0], p[1], chem), "hist": {}, "day": {}}
	return opinions[key(a, b)]


## Chemistry is a roll of the dice; clashes come only from personality.
func first_impression(a, b, chem: int) -> Dictionary:
	var base := {"Chemistry": float(chem)}
	for c in Data.CLASHES:
		var from_ok: bool = c["from"] == "*" or a.traits.has(c["from"])
		var to_ok: bool = c["to"] == "*" or b.traits.has(c["to"])
		if from_ok and to_ok:
			base[c["reason"]] = base.get(c["reason"], 0.0) + c["points"]
	return base


func opinion(a, b) -> float:
	var rec: Dictionary = opinions.get(key(a, b), {})
	if rec.is_empty():
		return 0.0
	var v := 0.0
	for r in rec["base"]:
		v += rec["base"][r]
	for r in rec["hist"]:
		v += rec["hist"][r]
	return clampf(v, -100.0, 100.0)


## [[reason text, points], ...], biggest first.
func reasons(a, b) -> Array:
	var rec: Dictionary = opinions.get(key(a, b), {})
	var out: Array = []
	if rec.is_empty():
		return out
	for r in rec["base"]:
		if absf(rec["base"][r]) >= 0.5:
			out.append([r, rec["base"][r]])
	for e in rec["hist"]:
		if absf(rec["hist"][e]) >= 0.5:
			out.append([Data.REL_EVENTS.get(e, {}).get("reason", e), rec["hist"][e]])
	out.sort_custom(func(x, y): return absf(x[1]) > absf(y[1]))
	return out


## The pair's label. Labels stick a little: friends stay friends until an
## opinion drops a few points below the line, so they don't flicker.
func label(a, b) -> String:
	var x := opinion(a, b)
	var y := opinion(b, a)
	var was: String = labels.get(pair_key(a, b), "")
	var k := Data.LABEL_STICK
	if minf(x, y) <= Data.RIVAL_AT + (k if was == "rivals" else 0.0):
		return "rivals"
	var best_line := Data.BEST_FRIEND_AT - (k if was == "best" else 0.0)
	if x >= best_line and y >= best_line:
		return "best"
	var friend_line := Data.FRIEND_AT - (k if was == "best" or was == "friends" else 0.0)
	if x >= friend_line and y >= friend_line:
		return "friends"
	var avg := (x + y) / 2.0
	if avg >= Data.FRIENDLY_AVG:
		return "friendly"
	if avg <= Data.TENSE_AVG:
		return "tense"
	return "neutral"


## How well a gets on with b by nature: their chemistry roll, from -1 to 1.
func compat(a, b) -> float:
	var rec: Dictionary = opinions.get(key(a, b), {})
	if rec.is_empty():
		return 0.0
	return clampf(rec["base"].get("Chemistry", 0.0) / float(Data.REL_CHEMISTRY), -1.0, 1.0)


func is_friend(a, b) -> bool:
	var l := label(a, b)
	return l == "friends" or l == "best"


## Changes how a feels about b. pts defaults to the event's points; cap limits
## how much this event can add per day. Friendly people warm up faster,
## Grumpy people slower. Returns what was actually added.
func add(a, b, ev: String, pts: float = INF, cap: float = 0.0) -> float:
	if a == null or b == null or a == b or not is_instance_valid(a) or not is_instance_valid(b):
		return 0.0
	var rec := ensure(a, b)
	if is_inf(pts):
		pts = Data.REL_EVENTS[ev].get("points", 0.0)
	if pts > 0.0:
		pts *= Career.team_mult()
		for t in Data.GOOD_TRAIT_GAIN:
			if a.has_trait(t):
				pts *= Data.GOOD_TRAIT_GAIN[t]
	if cap > 0.0:
		var used: float = rec["day"].get(ev, 0.0)
		pts = minf(pts, cap - used)
		if pts <= 0.0:
			return 0.0
		rec["day"][ev] = used + pts
	rec["hist"][ev] = rec["hist"].get(ev, 0.0) + pts
	if pts < 0.0:
		a.last_bad = now()
		a.add_stress(-pts * Data.STRESS_FROM_BAD, "a clash with %s" % b.person_name.split(" ")[0])
	elif ev != "work":
		a.last_good = now()
		a.add_stress(-pts * 0.5, "good moments with coworkers")
	return pts


func both(a, b, ev: String, pts: float = INF, cap: float = 0.0) -> void:
	add(a, b, ev, pts, cap)
	add(b, a, ev, pts, cap)


## Works out every pair's label; announces new friends and rivals unless quiet.
func refresh_labels(quiet: bool = true) -> void:
	var t := team()
	for i in t.size():
		for j in range(i + 1, t.size()):
			var a = t[i]
			var b = t[j]
			var pk := pair_key(a, b)
			var l := label(a, b)
			var was: String = labels.get(pk, "")
			labels[pk] = l
			if quiet or was == "" or was == l:
				continue
			announce(a, b, was, l)
	changed.emit()


## A little written moment, from Data.STORIES, about the two of them.
func story(kind: String, a, b) -> String:
	var line: String = Data.STORIES[kind].pick_random()
	return line.replace("{a}", a.person_name).replace("{b}", b.person_name) \
		.replace("{a_home}", a.origin.get("city", "home")).replace("{a_dish}", a.origin.get("dish", "their famous dish"))


func announce(a, b, was: String, now_label: String) -> void:
	var names := "%s and %s" % [a.person_name, b.person_name]
	if randf() < 0.5:
		var tmp = a
		a = b
		b = tmp
	if now_label == "best":
		log_line("%s are best friends now. %s" % [names, story("best", a, b)], "heart", [a, b])
		GameState.toast.emit("%s are best friends now! %s" % [names, story("best", a, b)], "crew")
		today["new_friends"].append(names)
		a.add_stress(-10.0, "a new friend")
		b.add_stress(-10.0, "a new friend")
		say(a, "", "heart")
		say(b, "", "heart")
		big_moment.emit()
	elif now_label == "friends" and was != "best":
		var line := story("friends", a, b)
		log_line("%s are friends now. %s" % [names, line], "heart", [a, b])
		GameState.toast.emit("%s are friends now. %s" % [names, line], "crew")
		today["new_friends"].append(names)
		a.add_stress(-10.0, "a new friend")
		b.add_stress(-10.0, "a new friend")
		say(a, "", "heart")
		big_moment.emit()
	elif now_label == "rivals":
		var line := story("rivals", a, b)
		log_line("%s can't stand each other. %s" % [names, line], "storm", [a, b])
		GameState.toast.emit("%s can't stand each other. %s Give them different jobs so they work apart." % [names, line], "bad")
		today["new_rivals"].append(names)
		big_moment.emit()
	elif was == "rivals":
		log_line("%s have cooled off." % names, "chat", [a, b])


# ------------------------------------------------------------------ the log and bubbles

func log_line(text: String, icon: String, who: Array = [], detail: String = "") -> void:
	var ids: Array = []
	for w in who:
		if w != null and is_instance_valid(w):
			ids.append(w.id)
	var e := {"day": GameState.day, "min": GameState.minute, "text": text, "icon": icon, "who": ids, "detail": detail}
	entries.append(e)
	while entries.size() > Data.LOG_KEEP:
		entries.pop_front()
	log_added.emit(e)


## A line from Data.LINES, with the speaker's hometown and dish filled in.
func line_for(kind: String, s) -> String:
	if not Data.LINES.has(kind):
		return ""
	var l: String = Data.LINES[kind].pick_random()
	return l.replace("{home}", s.origin.get("city", "home")).replace("{dish}", s.origin.get("dish", "lunch"))


## A speech bubble over someone's head for a moment: an icon and a short line.
func say(s, kind: String, icon: String) -> void:
	if s == null or not is_instance_valid(s):
		return
	var text := line_for(kind, s) if kind != "" else ""
	for b in bubbles.duplicate():
		if b["who"] == s:
			bubbles.erase(b)
	while bubbles.size() >= Data.MAX_BUBBLES:
		bubbles.pop_front()
	bubbles.append({"who": s, "icon": icon, "text": text, "t": Data.BUBBLE_SECONDS})


func tick_bubbles(real_dt: float) -> void:
	for b in bubbles.duplicate():
		b["t"] -= real_dt
		if b["t"] <= 0.0 or not is_instance_valid(b["who"]):
			bubbles.erase(b)


# ------------------------------------------------------------------ the day

func active() -> bool:
	return GameState.is_active()


func tile_dist(a, b) -> float:
	return a.position.distance_to(b.position) / Data.TILE


## Called every frame by main.gd with the game minutes that passed.
func tick(minutes: float) -> void:
	if not active() or main == null:
		return
	check_bumps()
	_acc += minutes
	var guard := 0
	while _acc >= 1.0 and guard < 30:
		_acc -= 1.0
		guard += 1
		minute_step()


## Two people walking through the same kitchen tile sometimes collide.
func check_bumps() -> void:
	var t := present()
	var lot = main.lot
	for i in t.size():
		for j in range(i + 1, t.size()):
			var a = t[i]
			var b = t[j]
			var pk := pair_key(a, b)
			var d := tile_dist(a, b)
			if d > 0.9:
				_overlap.erase(pk)
				continue
			if d > 0.6 or _overlap.has(pk) or not a.is_moving() or not b.is_moving():
				continue
			if lot.floor_at(a.current_cell()) != Data.FLOOR_KITCHEN:
				continue
			_overlap[pk] = true
			if now() - _bump_last.get(pk, -9999.0) >= 30.0 and randf() < Data.BUMP_CHANCE:
				_bump_last[pk] = now()
				both(a, b, "bump")
				say(a, "bump", "alert")
				log_line("%s and %s bumped into each other in the kitchen." % [a.person_name, b.person_name], "alert", [a, b])


## Everything that happens once a game minute.
func minute_step() -> void:
	var t := present()
	var lot = main.lot
	var tm := now()
	for s in t:
		s._friend_factor = 1.0
		s._near_rival = false
	for i in t.size():
		for j in range(i + 1, t.size()):
			var a = t[i]
			var b = t[j]
			var pk := pair_key(a, b)
			var d := tile_dist(a, b)
			var l := label(a, b)
			var working: bool = a.is_working() and b.is_working()
			# working side by side, in the same room
			if working and d <= Data.REL_NEAR_TILES and lot.floor_at(a.current_cell()) == lot.floor_at(b.current_cell()):
				for p in [[a, b], [b, a]]:
					if opinion(p[0], p[1]) > Data.REL_NO_WARM_BELOW:
						var f: float = 0.5 + 0.5 * compat(p[0], p[1])
						add(p[0], p[1], "work", Data.REL_WORK_GAIN * f, Data.REL_WORK_DAY_CAP * f)
				today["work"][pk] = today["work"].get(pk, 0) + 1
				if l == "friends" or l == "best":
					var f: float = Data.BEST_FRIEND_SPEED if l == "best" else Data.FRIEND_SPEED
					a._friend_factor = maxf(a._friend_factor, f)
					b._friend_factor = maxf(b._friend_factor, f)
					if randf() < 1.0 / 30.0:
						say(a if randf() < 0.5 else b, "friends", "heart")
			# chatting: on a break together, or both idle
			var on_break: bool = a.on_break and b.on_break
			if (on_break or (a.is_idle() and b.is_idle())) and d <= Data.REL_CHAT_TILES:
				var every := Data.REL_CHAT_EVERY * (0.5 if a.has_trait("chatty") or b.has_trait("chatty") else 1.0)
				_chat_min[pk] = _chat_min.get(pk, 0.0) + 1.0
				if _chat_min[pk] >= every:
					_chat_min[pk] = 0.0
					chat(a, b)
				if on_break and not _snack_done.has(pk):
					_snack_done[pk] = true
					if randf() < Data.SNACK_CHANCE:
						snack(a, b)
			elif not on_break:
				_snack_done.erase(pk)
			# rivals near each other
			if l == "rivals" and d <= Data.RIVAL_TILES:
				a._near_rival = true
				b._near_rival = true
				if a.pause_left <= 0.0 and b.pause_left <= 0.0 and not a.on_phone and not b.on_phone \
						and not Events.calm.has(pk) and randf() < Data.BICKER_CHANCE:
					bicker(a, b)
	var rush := customers_waiting() / float(maxi(t.size(), 1))
	for s in t:
		if s._friend_factor > 1.0:
			s.crew_speed = s._friend_factor
		elif s._near_rival:
			s.crew_speed = Data.RIVAL_SPEED
		else:
			s.crew_speed = 1.0
		update_stress(s, rush)
		maybe_snap(s, t, tm)
		update_mood(s, tm)
		if s.on_phone:
			watch_phone(s, t)
		elif s.mood == "cheerful" and s.is_working() and GameState.is_open() and lot.music_near(s.current_cell()) and randf() < 1.0 / 90.0:
			say(s, "", "music")
	if int(GameState.minute) % 10 == 0:
		post_checkins(t)
	refresh_labels(false)


## One exchange between two people chatting. Each side enjoys it or not,
## depending on their chemistry (and whether they're Friendly or Grumpy).
func chat(a, b) -> void:
	var speaker = a if randf() < 0.5 else b
	say(speaker, "chat", "chat")
	for p in [[a, b], [b, a]]:
		var me = p[0]
		var them = p[1]
		var good := 0.5 + 0.4 * compat(me, them)
		if me.has_trait("friendly"):
			good += 0.15
		if me.has_trait("grumpy"):
			good -= 0.2
		if randf() < good:
			add(me, them, "chat", Data.REL_CHAT_GOOD, Data.REL_CHAT_DAY_CAP)
		else:
			var rec := ensure(me, them)
			var used: float = rec["day"].get("chat_bad", 0.0)
			if used > -Data.REL_CHAT_DAY_CAP:
				rec["day"]["chat_bad"] = used + Data.REL_CHAT_BAD
				add(me, them, "chat_bad", Data.REL_CHAT_BAD)
				if me != speaker:
					say(me, "awkward", "alert")


## Groups waiting for a table, to order or for their food: how swamped the crew is.
func customers_waiting() -> int:
	var n := 0
	if main == null:
		return 0
	for g in main.groups:
		if is_instance_valid(g) and g.state in ["waiting", "seated", "ordered"] and g.kind != "inspector":
			n += 1
	return n


## A minute of stress: work, a rush, rivals and tiredness push it up; breaks,
## friends and quiet moments bring it down.
func update_stress(s, rush: float) -> void:
	var parts: Array = []
	if s.on_break:
		parts.append([Data.STRESS_SOFA if (s.rest_sofa != null and s.sitting) else Data.STRESS_REST, "breaks"])
	else:
		if s.is_working() and GameState.phase == GameState.Phase.SERVICE:
			parts.append([Data.STRESS_WORK, "work"])
		if rush >= 2.0:
			parts.append([Data.STRESS_SWAMPED, "being swamped"])
		elif rush >= 1.0:
			parts.append([Data.STRESS_BUSY, "a busy floor"])
		if s._near_rival:
			parts.append([Data.STRESS_RIVAL, "working near a rival"])
		if s.energy < Data.SNAP_ENERGY:
			parts.append([Data.STRESS_TIRED, "being tired"])
		if s._friend_factor > 1.0:
			parts.append([Data.STRESS_FRIEND, "friends on shift"])
		if s.is_idle():
			parts.append([Data.STRESS_IDLE, "quiet moments"])
	# the kitchen radio, for whoever's working in the kitchen
	if not s.on_break and main != null and main.lot.has_type("radio") and main.lot.floor_at(s.current_cell()) == Data.FLOOR_KITCHEN:
		var st: Dictionary = Data.RADIO[GameState.radio]
		parts.append([st.get("grumpy", st["stress"]) if s.has_trait("grumpy") else st["stress"], "the kitchen radio"])
	var total := 0.0
	for p in parts:
		total += p[0]
	# grumpy people take the bad minutes harder
	var g: float = 1.25 if total > 0.0 and s.has_trait("grumpy") else 1.0
	for p in parts:
		s.add_stress(p[0] * (g if p[0] > 0.0 else 1.0), p[1])


## Mood follows stress: calm people are cheerful, stressed people fed up.
func update_mood(s, _tm: float) -> void:
	if s.stress >= Data.STRESS_FED_UP:
		s.mood = "fed_up"
	elif s.stress <= Data.STRESS_CHEERFUL:
		s.mood = "cheerful"
	else:
		s.mood = "okay"


func maybe_snap(s, t: Array, tm: float) -> void:
	var limit: float = 50.0 if s.has_trait("grumpy") else Data.SNAP_ENERGY
	var frazzled: bool = s.energy < limit or s.stress >= 70.0
	if s.on_break or not frazzled or tm - _snap_last.get(s.id, -9999.0) < 60.0:
		return
	var target = null
	var best := 2.0
	for o in t:
		if o != s and not o.on_break and tile_dist(s, o) <= best:
			best = tile_dist(s, o)
			target = o
	if target == null or randf() >= Data.SNAP_CHANCE:
		return
	_snap_last[s.id] = tm
	add(target, s, "snapped")
	say(s, "snap", "storm")
	log_line("%s snapped at %s. Too tired." % [s.person_name, target.person_name], "storm", [s, target])


# ------------------------------------------------------------------ things that happen

## Customers close to a spot who would notice staff misbehaving.
func groups_near(p: Vector2, tiles: float) -> Array:
	var out: Array = []
	if main == null:
		return out
	for g in main.groups:
		if not is_instance_valid(g) or g.kind == "inspector":
			continue
		if not g.state in ["waiting", "to_table", "seated", "ordered", "eating", "complaining", "paying"]:
			continue
		for m in g.members:
			if is_instance_valid(m) and m.position.distance_to(p) <= tiles * Data.TILE:
				out.append(g)
				break
	return out


func bicker(a, b) -> void:
	for m in present():
		if m.manager and m != a and m != b and not m.on_break and m.mood != "fed_up" \
				and tile_dist(m, a) <= Data.MANAGER_BREAKUP_TILES:
			both(a, b, "bicker", -1.0)
			say(m, "breakup", "alert")
			log_line("%s broke up an argument between %s and %s." % [m.person_name, a.person_name, b.person_name], "alert", [m, a, b])
			today["breakups"] += 1
			return
	both(a, b, "bicker")
	a.add_stress(4.0, "an argument")
	b.add_stress(4.0, "an argument")
	a.pause_left = Data.BICKER_MINUTES
	b.pause_left = Data.BICKER_MINUTES
	say(a, "bicker", "storm")
	say(b, "bicker", "storm")
	var seen := groups_near(a.position, Data.REL_NEAR_TILES)
	for g in seen:
		g.note_trouble("staff arguing", Data.BICKER_REVIEW)
	today["bickers"] += 1
	log_line("%s and %s bickered%s." % [a.person_name, b.person_name, " in front of customers" if not seen.is_empty() else ""], "storm", [a, b])
	ask_mediation(a, b)


## Asks a manager on shift to sit two people down and talk it out (once a day per pair).
func ask_mediation(a, b) -> bool:
	var pk := pair_key(a, b)
	if _mediated.has(pk) or manager_on_shift([a, b]) == null:
		return false
	for j in JobBoard.jobs:
		if j.kind == "mediate" and not j.done and ((j.who == a and j.who2 == b) or (j.who == b and j.who2 == a)):
			return true
	_mediated[pk] = true
	JobBoard.post("serve", "mediate", {"who": a, "who2": b})
	return true


## The talk: how well it goes depends on the manager's people skills and mood.
func mediate(m, a, b) -> void:
	var q: float = clampf(0.5 + 0.05 * m.service, 0.5, 1.0) * (0.7 if m.mood == "okay" else 1.0) * desk_bonus() * (1.3 if "peacemaker" in m.perks else 1.0)
	both(a, b, "mediated", Data.MEDIATE_POINTS * q)
	a.add_stress(-Data.MEDIATE_STRESS * q, "the manager talked it out")
	b.add_stress(-Data.MEDIATE_STRESS * q, "the manager talked it out")
	a.pause_left = 0.0
	b.pause_left = 0.0
	Events.calm[pair_key(a, b)] = true
	say(a, "", "heart")
	today["mediations"] += 1
	log_line("%s sat %s and %s down and they talked it out." % [m.person_name, a.person_name, b.person_name], "chat", [m, a, b])
	refresh_labels(false)


## Stressed people get a manager's check-in now and then.
func post_checkins(t: Array) -> void:
	if manager_on_shift() == null:
		return
	for j in JobBoard.jobs:
		if j.kind == "checkin" and not j.done:
			return
	var worst = null
	for s in t:
		if s.manager or s.on_break or s.stress < Data.CHECKIN_AT:
			continue
		if now() - _checked.get(s.id, -9999.0) < Data.CHECKIN_EVERY:
			continue
		if worst == null or s.stress > worst.stress:
			worst = s
	if worst != null:
		_checked[worst.id] = now()
		JobBoard.post("serve", "checkin", {"who": worst})


## A manager with a desk of their own does better talks and check-ins.
func desk_bonus() -> float:
	return Data.DESK_BONUS if main != null and main.lot.has_type("desk") else 1.0


func check_in(m, s) -> void:
	var q: float = clampf(0.5 + 0.05 * m.service, 0.5, 1.0) * desk_bonus() * (1.3 if "peacemaker" in m.perks else 1.0)
	s.add_stress(-Data.CHECKIN_STRESS * q, "the manager checked in")
	if s.energy < 60.0 or s.stress >= Data.STRESS_FED_UP:
		s.break_asked = true
	say(m, "checkin", "heart")
	today["checkins"] += 1
	add(s, m, "chat", 1.0, Data.REL_CHAT_DAY_CAP)
	log_line("%s checked on %s%s." % [m.person_name, s.person_name, " and sent them on a break" if s.break_asked else ""], "heart", [m, s])


func snack(a, b) -> void:
	var giver = a if randf() < 0.5 else b
	var taker = b if giver == a else a
	both(a, b, "snack")
	say(giver, "snack", "heart")
	log_line("%s shared some %s with %s." % [giver.person_name, giver.origin.get("dish", "leftovers"), taker.person_name], "heart", [giver, taker])


func plate_dropped(s) -> void:
	var seen: Array = []
	for w in present():
		if w != s and not w.on_break and tile_dist(w, s) <= 5.0:
			add(w, s, "plates", -8.0 if w.has_trait("tidy") else Data.REL_EVENTS["plates"]["points"])
			seen.append(w)
	if seen.is_empty():
		return
	say(seen[0], "plate", "alert")
	var names: Array = seen.map(func(w): return w.person_name)
	log_line("%s dropped a plate. %s %s impressed." % [s.person_name, and_list(names), "wasn't" if seen.size() == 1 else "weren't"], "alert", [s] + seen)


func sofa_full(s, resters: Array) -> void:
	var others: Array = resters.filter(func(r): return r != null and is_instance_valid(r) and r != s)
	if others.is_empty():
		return
	for r in others:
		add(s, r, "sofa")
	say(s, "sofa", "alert")
	var names: Array = others.map(func(r): return r.person_name)
	log_line("%s wanted to rest, but %s had the sofa." % [s.person_name, and_list(names)], "energy", [s] + others)


func fixed(fixer, cook, what: String) -> void:
	if cook == null or not is_instance_valid(cook) or cook == fixer or not GameState.staff.has(cook):
		return
	add(cook, fixer, "fixed")
	say(cook, "thanks", "heart")
	log_line("%s fixed the %s for %s." % [fixer.person_name, what, cook.person_name], "fix", [fixer, cook])


## A 5-star review: the cooks and the servers of that order like each other a little more.
func teamwork(cooks: Array, servers: Array) -> void:
	for c in cooks:
		for s in servers:
			if c == null or s == null or c == s or not is_instance_valid(c) or not is_instance_valid(s):
				continue
			if not GameState.staff.has(c) or not GameState.staff.has(s):
				continue
			both(c, s, "teamwork", Data.REL_EVENTS["teamwork"]["points"], 2.0)
			if _teamwork_day != GameState.day:
				_teamwork_day = GameState.day
				say(c, "teamwork", "sparkle")
				log_line("%s and %s nailed an order: 5 stars." % [c.person_name, s.person_name], "star", [c, s])


# ------------------------------------------------------------------ phones and managers

## Someone is on their phone: managers, coworkers and customers may notice.
func watch_phone(s, t: Array) -> void:
	for m in t:
		if m == s or not m.manager or m.on_break or s.phone_seen.has(m.id):
			continue
		if tile_dist(m, s) > Data.PHONE_MANAGER_TILES:
			continue
		s.phone_seen[m.id] = true
		var p := Data.MANAGER_STRICT
		var op := opinion(m, s)
		if op >= Data.FRIEND_AT:
			p = Data.MANAGER_STRICT_FRIEND
		elif op <= Data.RIVAL_AT:
			p = Data.MANAGER_STRICT_RIVAL
		if m.mood == "fed_up":
			p += Data.MANAGER_MOOD
		elif m.mood == "cheerful":
			p -= Data.MANAGER_MOOD
		if randf() < clampf(p, 0.0, 1.0):
			reprimand(m, s)
			return
		say(m, "slide", "chat")
		log_line("%s saw %s on the phone and let it slide." % [m.person_name, s.person_name], "phone", [m, s])
	for c in t:
		if c == s or c.manager or s.phone_seen.has(c.id) or not c.is_working():
			continue
		if tile_dist(c, s) > Data.PHONE_COWORKER_TILES:
			continue
		s.phone_seen[c.id] = true
		if is_friend(c, s):
			if not s.phone_seen.has("covered"):
				s.phone_seen["covered"] = true
				say(c, "cover", "heart")
				log_line("%s covered for %s, who was on the phone." % [c.person_name, s.person_name], "phone", [c, s])
		else:
			add(c, s, "phone")
			say(c, "slacking", "alert")
	if not s.phone_seen.has("customers"):
		var seen := groups_near(s.position, Data.PHONE_CUSTOMER_TILES)
		if not seen.is_empty():
			s.phone_seen["customers"] = true
			for g in seen:
				g.note_trouble("staff on their phone", Data.PHONE_REVIEW)
			today["phone_seen"] += 1
			log_line("Customers saw %s on the phone." % s.person_name, "phone", [s])


func reprimand(m, s) -> void:
	s.end_phone()
	add(s, m, "told_off", -6.0 if s.has_trait("grumpy") else Data.REL_EVENTS["told_off"]["points"])
	s.add_stress(4.0, "told off")
	say(m, "reprimand", "alert")
	say(s, "sorry", "phone")
	today["reprimands"] += 1
	log_line("%s told %s to put the phone away." % [m.person_name, s.person_name], "phone", [m, s])


## You clicked someone who was on their phone.
func owner_caught(s) -> void:
	if not s.on_phone:
		return
	s.end_phone()
	say(s, "sorry", "phone")
	s.add_stress(4.0, "caught on the phone")
	today["caught"] += 1
	s.caught_days = s.caught_days.filter(func(d): return d > GameState.day - 7)
	s.caught_days.append(GameState.day)
	Sfx.play("pop", -6.0)
	if s.caught_days.size() >= Data.PHONE_WARN_AFTER:
		s.warnings += 1
		s.caught_days.clear()
		log_line("%s got a warning for being on the phone too often." % s.person_name, "alert", [s])
		GameState.toast.emit("%s got a warning: that's %d times on the phone this week." % [s.person_name, Data.PHONE_WARN_AFTER], "bad")
	else:
		log_line("You caught %s on the phone." % s.person_name, "phone", [s])
		GameState.toast.emit("You caught %s on the phone. They put it away." % s.person_name, "")
	GameState.staff_changed.emit()


## Gives someone a new role: new job priorities, and the going rate for it
## (plus any raises you've given them).
func set_role(s, role: String) -> void:
	if s.role == role or not Data.ROLES.has(role):
		return
	var was: String = s.role
	s.role = role
	s.priorities = GameState.default_priorities(role)
	s.wage = maxf(Data.MIN_WAGE, Data.role_pay(role, s.cooking, s.service, s.traits) + s.raises)
	s.dress()
	Shifts.replan()
	var name_: String = Data.ROLES[role]["name"].to_lower()
	if role == "manager":
		log_line("%s is now a manager." % s.person_name, "star", [s])
		GameState.toast.emit("%s is now a manager ($%.2f an hour)." % [s.person_name, s.wage], "good")
	else:
		log_line("%s is now a %s%s." % [s.person_name, name_, " (was a manager)" if was == "manager" else ""], "staff", [s])
		GameState.toast.emit("%s is now a %s ($%.2f an hour)." % [s.person_name, name_, s.wage], "")
	GameState.staff_changed.emit()


## Older code: makes someone a manager, or back to what fits them best.
func set_manager(s, on: bool) -> void:
	if on:
		set_role(s, "manager")
	elif s.manager:
		set_role(s, "cook" if s.cooking > s.service else "server")


# ------------------------------------------------------------------ nights, reports, saves

## After closing: people who have had enough quit, stress eases overnight,
## history fades a little, and daily limits reset.
func nightly() -> void:
	for s in team():
		var extra := 1 if Career.has_benefit("retire") else 0
		if s.raise_refused >= Data.RAISE_REFUSALS_QUIT + extra:
			quit(s, "%s left for a better-paying job across town." % s.person_name)
		elif s.stress >= Data.STRESS_BURNOUT:
			s.burnout_nights += 1
			if s.burnout_nights >= Data.BURNOUT_QUIT_NIGHTS + (1 if Career.has_benefit("health") else 0) + extra:
				quit(s, "%s burned out and quit." % s.person_name)
				continue
			s.burnout_warned = true
			today["burnout"].append(s.person_name)
			log_line("%s is burning out. A day off, a sofa or friends nearby would help." % s.person_name, "alert", [s])
			GameState.toast.emit("%s is burning out (%d of %d bad nights). A day off would help." % [s.person_name, s.burnout_nights, Data.BURNOUT_QUIT_NIGHTS], "bad")
		elif s.stress < Data.STRESS_FED_UP:
			s.burnout_warned = false
			s.burnout_nights = 0
	var calm: float = Data.MANAGER_NIGHT_CALM if team().any(func(s): return s.manager) else 0.0
	if calm > 0.0 and main != null and main.lot.has_type("desk"):
		calm *= Data.DESK_NIGHT_CALM
	if Career.has_benefit("pto"):
		calm += 2.0
	for s in team():
		s.add_stress(Data.STRESS_NIGHT - calm, "a night's rest")
	var worked: Array = []
	for pk in today["work"]:
		if today["work"][pk] >= 180:
			worked.append([pk, today["work"][pk]])
	worked.sort_custom(func(x, y): return x[1] > y[1])
	for w in worked.slice(0, 2):
		var ids: PackedStringArray = w[0].split("|")
		var a = by_id(int(ids[0]))
		var b = by_id(int(ids[1]))
		if a != null and b != null:
			log_line("%s and %s worked side by side for %d hours." % [a.person_name, b.person_name, int(w[1] / 60)], "people", [a, b])
	for k in opinions:
		var rec: Dictionary = opinions[k]
		for e in rec["hist"].keys():
			rec["hist"][e] *= 1.0 - Data.REL_FADE
			if absf(rec["hist"][e]) < 0.05:
				rec["hist"].erase(e)
		rec["day"] = {}
	_snack_done = {}
	_chat_min = {}
	_overlap = {}
	bubbles = []
	for s in team():
		s.crew_speed = 1.0
		update_mood(s, 0.0)
	refresh_labels(false)


## Someone has had enough and leaves. Their friends take it hard.
## Someone else is already standing or sitting on this cell.
func cell_taken(c: Vector2i, me) -> bool:
	for o in GameState.staff:
		if o != me and o.is_inside_tree() and o.at_work and o.current_cell() == c:
			return true
	return false


func quit(s, text: String) -> void:
	today["quits"].append(s.person_name)
	GameState.totals["last_quit_day"] = GameState.day
	log_line(text, "walkout", [s])
	GameState.toast.emit(text, "bad")
	for o in team():
		if o != s and is_friend(o, s):
			o.add_stress(Data.STRESS_FRIEND_QUIT, "a friend quit")
	if main != null:
		main.lose_staff(s)


## Lines for the day's report: [icon, colour, text].
func report_lines() -> Array:
	var out: Array = []
	for n in today["quits"]:
		out.append(["walkout", "#e75a4e", "[b]%s[/b] quit." % n])
	for n in today["burnout"]:
		out.append(["alert", "#e75a4e", "[b]%s[/b] is burning out. Give them a day off, a sofa to rest on, or lighter jobs." % n])
	for n in today["new_friends"]:
		out.append(["heart", "#e27fa8", "[b]%s[/b] became friends." % n])
	for n in today["new_rivals"]:
		out.append(["storm", "#e75a4e", "[b]%s[/b] can't stand each other. Give them different jobs." % n])
	if today["mediations"] > 0 or today["checkins"] > 0:
		var bits2: Array = []
		if today["mediations"] > 0:
			bits2.append("settled %d argument%s" % [today["mediations"], "" if today["mediations"] == 1 else "s"])
		if today["checkins"] > 0:
			bits2.append("checked on stressed staff %d time%s" % [today["checkins"], "" if today["checkins"] == 1 else "s"])
		out.append(["star", "#f2c14e", "Your managers " + " and ".join(bits2) + "."])
	if today["bickers"] > 0:
		out.append(["storm", "#f2c14e", "%d argument%s between staff%s." % [today["bickers"], "" if today["bickers"] == 1 else "s",
			(", and %d broken up by a manager" % today["breakups"]) if today["breakups"] > 0 else ""]])
	var phones: int = today["caught"] + today["reprimands"]
	if phones > 0 or today["phone_seen"] > 0:
		var bits: Array = []
		if today["caught"] > 0:
			bits.append("you caught %d" % today["caught"])
		if today["reprimands"] > 0:
			bits.append("managers caught %d" % today["reprimands"])
		if today["phone_seen"] > 0:
			bits.append("customers noticed %d" % today["phone_seen"])
		out.append(["phone", "#6aa6d9", "Phones on shift: " + ", ".join(bits) + "."])
	var best_pk := ""
	var best_m := 0
	for pk in today["work"]:
		if today["work"][pk] > best_m:
			best_m = today["work"][pk]
			best_pk = pk
	if best_pk != "" and best_m >= 120:
		var ids: PackedStringArray = best_pk.split("|")
		var a = by_id(int(ids[0]))
		var b = by_id(int(ids[1]))
		if a != null and b != null:
			out.append(["people", "#6cc3a0", "Best pair today: [b]%s and %s[/b], %d hours side by side." % [a.person_name, b.person_name, int(best_m / 60)]])
	return out


func save_data() -> Dictionary:
	return {"opinions": opinions, "log": entries, "next_id": next_id}


func load_data(d: Dictionary) -> void:
	reset()
	next_id = int(d.get("next_id", 1))
	var ops: Dictionary = d.get("opinions", {})
	for k in ops:
		var rec: Dictionary = ops[k]
		var base := {}
		var hist := {}
		var day := {}
		for r in rec.get("base", {}):
			base[r] = float(rec["base"][r])
		for r in rec.get("hist", {}):
			hist[r] = float(rec["hist"][r])
		for r in rec.get("day", {}):
			day[r] = float(rec["day"][r])
		opinions[k] = {"base": base, "hist": hist, "day": day}
	for e in d.get("log", []):
		var ids: Array = []
		for i in e.get("who", []):
			ids.append(int(i))
		entries.append({"day": int(e.get("day", 1)), "min": float(e.get("min", 0.0)), "text": str(e.get("text", "")),
			"icon": str(e.get("icon", "info")), "who": ids, "detail": str(e.get("detail", ""))})


# ------------------------------------------------------------------ words

## "Rosa", "Rosa and Linh", "Rosa, Linh and Tunde"
static func and_list(names: Array) -> String:
	if names.size() <= 1:
		return "".join(names)
	return ", ".join(names.slice(0, names.size() - 1)) + " and " + names[-1]


## "Friends: Linh · Rival: Tunde" for someone's card.
func summary(s) -> String:
	var friends: Array = []
	var rivals: Array = []
	for o in team():
		if o == s:
			continue
		var l := label(s, o)
		if l == "best":
			friends.append(o.person_name + " ♥")
		elif l == "friends":
			friends.append(o.person_name)
		elif l == "rivals":
			rivals.append(o.person_name)
	var bits: Array = []
	if not friends.is_empty():
		bits.append(("Friend: " if friends.size() == 1 else "Friends: ") + ", ".join(friends))
	if not rivals.is_empty():
		bits.append(("Rival: " if rivals.size() == 1 else "Rivals: ") + ", ".join(rivals))
	return "  ·  ".join(bits)


## For the hiring cards: how someone with these traits would get on with the
## crew you have, from trait clashes alone (chemistry is a surprise).
func clash_hints(traits: Array) -> Array:
	var out: Array = []
	for s in team():
		for c in Data.CLASHES:
			if c["from"] == "*" or c["to"] == "*":
				continue
			var theirs: bool = s.traits.has(c["from"]) and traits.has(c["to"])
			var mine: bool = traits.has(c["from"]) and s.traits.has(c["to"])
			if c["points"] > 0.0 and (theirs or mine):
				out.append("Will hit it off with %s: %s." % [s.person_name, c["reason"].to_lower()])
			elif theirs:
				out.append("%s won't like them: %s." % [s.person_name, c["reason"].to_lower()])
			elif mine:
				out.append("They won't like %s: %s." % [s.person_name, c["reason"].to_lower()])
			if out.size() >= 3:
				return out
	return out
