extends Node
## The crew's working lives:
##   careers: everyone climbs their role's ladder (a trainee cook becomes a
##     line cook, a senior line cook, a sous chef) with a raise and a perk to
##     choose at each step
##   time off: people ask for days off for their own lives (finals, a recital,
##     a second job), and some can't work mornings or nights at all
##   the huddle: pick the day's focus in the morning (speed, upselling,
##     cleanliness or teamwork); a manager makes it count for more
##   benefits: free shift meals, health insurance, paid time off and a
##     retirement match, paid weekly, each with its effect

var huddle := ""                 # "", "speed", "upsell", "clean", "team"
var benefits: Dictionary = {}    # benefit key -> on


func reset() -> void:
	huddle = ""
	benefits = {}


# ------------------------------------------------------------------ careers

## The skill that counts for this role's ladder.
func role_skill(s) -> int:
	match Data.ROLES[s.role]["skill"]:
		"cooking":
			return s.cooking
		"service":
			return s.service
	return maxi(s.cooking, s.service)


## Which step of their role's ladder they're on now (0 = the first).
func earned_rank(s) -> int:
	var r := 0
	for i in Data.CAREER_STEPS.size():
		var st: Array = Data.CAREER_STEPS[i]
		if role_skill(s) >= st[0] and s.shifts_worked >= st[1]:
			r = i
	return mini(r, Data.CAREER_TITLES.get(s.role, ["", "", "", ""]).size() - 1)


func title(s) -> String:
	var t: Array = Data.CAREER_TITLES.get(s.role, [])
	if t.is_empty():
		return Data.ROLES[s.role]["name"]
	return t[clampi(s.rank, 0, t.size() - 1)]


func has_perk(s, p: String) -> bool:
	return s != null and p in s.perks


## At night: anyone who's earned their next step gets it, a raise, and a perk to pick.
func nightly() -> void:
	for s in GameState.staff:
		var r := earned_rank(s)
		if r <= s.rank:
			continue
		s.rank = r
		s.wage += Data.PROMOTION_RAISE
		s.raises += Data.PROMOTION_RAISE
		s.add_stress(-8.0, "a promotion")
		var t := "%s is now %s, with $%.2f more an hour." % [s.person_name, title(s).to_lower(), Data.PROMOTION_RAISE]
		Crew.log_line(t, "star", [s])
		GameState.toast.emit(t, "good")
		Moments.note_scrapbook("promotion", "%s: %s" % [s.person_name, title(s)], t)
		var options: Array = Data.PERKS.keys().filter(func(k): return s.role in Data.PERKS[k]["roles"] and not k in s.perks)
		options.shuffle()
		if options.size() >= 2:
			Events.ask_player("perk", "%s's promotion" % s.person_name, "%s moved up to %s. What are they getting good at?" % [s.person_name, title(s).to_lower()],
				[{"label": Data.PERKS[options[0]]["name"], "desc": Data.PERKS[options[0]]["desc"]}, {"label": Data.PERKS[options[1]]["name"], "desc": Data.PERKS[options[1]]["desc"]}],
				{"s": s, "options": options.slice(0, 2)})
		elif options.size() == 1:
			s.perks.append(options[0])
	# time-off requests for later in the week
	for s in GameState.staff:
		if randf() < Data.TIMEOFF_CHANCE and s.requested_off.size() < 2:
			var day: int = GameState.day + randi_range(2, 5)
			if not s.requested_off.has(day):
				var why: String = Data.TIMEOFF_REASONS.pick_random()
				Events.ask_player("timeoff", "%s asks for a day off" % s.person_name,
					"%s would like %s off: %s." % [s.person_name, Town.date_text(day), why],
					[{"label": "Of course", "desc": "The schedule works around it. They're grateful."},
					{"label": "Sorry, we need you", "desc": "They'll come in, unhappily."}], {"s": s, "day": day, "why": why})
				break


# ------------------------------------------------------------------ the huddle

func set_huddle(k: String) -> void:
	huddle = k


func huddle_mult() -> float:
	return 1.5 if Crew.team().any(func(s): return s.manager and s.at_work) else 1.0


func speed_bonus() -> float:
	return 1.0 + (0.06 * huddle_mult() if huddle == "speed" else 0.0)


func upsell_bonus() -> float:
	return 0.05 * huddle_mult() if huddle == "upsell" else 0.0


func mess_mult() -> float:
	return 1.0 - (0.3 * huddle_mult() if huddle == "clean" else 0.0)


func team_mult() -> float:
	return 1.0 + (0.3 * huddle_mult() if huddle == "team" else 0.0)


# ------------------------------------------------------------------ benefits

func has_benefit(k: String) -> bool:
	return benefits.get(k, false)


func set_benefit(k: String, on: bool) -> void:
	benefits[k] = on


## What the benefits cost this week.
func benefits_week() -> float:
	var n := GameState.staff.size()
	var t := 0.0
	for k in Data.BENEFITS:
		if has_benefit(k):
			var b: Dictionary = Data.BENEFITS[k]
			t += b.get("per_person", 0.0) * n
			t += b.get("payroll", 0.0) * GameState.weekly_wages()
	return t


# ------------------------------------------------------------------ saves

func save_data() -> Dictionary:
	return {"huddle": huddle, "benefits": benefits}


func load_data(d: Dictionary) -> void:
	reset()
	huddle = str(d.get("huddle", ""))
	for k in d.get("benefits", {}):
		benefits[str(k)] = bool(d["benefits"][k])
