extends Node
## Crew moments, the small things that make a crew feel like people:
##   birthdays: cake in the staff room, a little less stress all round
##   milestones: 10, 50, 100 and 250 shifts, and a year with you
##   a hometown dish: a cook who's settled in teaches the kitchen their
##     signature dish after close, and it goes on the menu
##   employee of the month: whoever did the most over four weeks gets their
##     photo on the wall (the frame is in Decor), a small raise and a morale
##     boost, and a rival or a close runner-up gets a little jealous
## Everything is logged in the staff log and the day report.

var eotm: Dictionary = {}     # {"id", "name", "role", "skin", "hair", "shirt", "look", "day", "jobs"}
var cake_for := ""            # whose birthday it is today, or ""
var today_lines: Array = []   # [icon, colour, text] for tonight's report


func reset() -> void:
	eotm = {}
	cake_for = ""
	today_lines = []


func day_of_year(day: int) -> int:
	return posmod(day - 1, Data.YEAR_DAYS) + 1


## A new hire: their first day, and a birthday (now and then a soon one).
func welcome(s) -> void:
	s.hired_day = GameState.day
	if s.birthday <= 0:
		var ahead := randi_range(3, 30) if randf() < 0.3 else randi_range(1, Data.YEAR_DAYS)
		s.birthday = day_of_year(GameState.day + ahead)


func days_until_birthday(s) -> int:
	return posmod(s.birthday - day_of_year(GameState.day), Data.YEAR_DAYS)


## The morning: is it anyone's birthday?
func morning() -> void:
	cake_for = ""
	for s in GameState.staff:
		if s.birthday != day_of_year(GameState.day) or s.away:
			continue
		cake_for = s.person_name
		GameState.toast.emit("It's %s's birthday! There's cake in the staff room." % s.person_name, "crew")
		Crew.log_line("%s's birthday. Someone brought a cake to the staff room." % s.person_name, "heart", [s])
		s.add_stress(-Data.BIRTHDAY_STRESS, "birthday cake")
		for o in GameState.staff:
			if o != s:
				Crew.add(o, s, "cake")
				o.add_stress(-Data.BIRTHDAY_STRESS * 0.4, "birthday cake")
		break


## The night: milestones, maybe a hometown dish, and the employee of the month.
func nightly() -> void:
	today_lines = []
	for s in GameState.staff:
		s.jobs_month += s.jobs_today
		if not s.worked_today:
			continue
		s.shifts_worked += 1
		if s.shifts_worked in Data.SHIFT_MILESTONES:
			var t := "%s worked their %s shift here tonight." % [s.person_name, ordinal(s.shifts_worked)]
			Crew.log_line(t, "star", [s])
			GameState.toast.emit(t + " The crew signed a card.", "crew")
			s.add_stress(-Data.MILESTONE_STRESS, "a milestone")
			today_lines.append(["star", "#f2c14e", t])
		if GameState.day - s.hired_day == Data.YEAR_DAYS:
			var y := "%s has been with you a whole year." % s.person_name
			Crew.log_line(y, "star", [s])
			GameState.toast.emit(y, "crew")
			s.add_stress(-Data.MILESTONE_STRESS, "a year here")
			today_lines.append(["star", "#f2c14e", y])
	teach_dish()
	if GameState.day % Data.EOTM_EVERY == 0:
		pick_eotm()


static func ordinal(n: int) -> String:
	var suf := "th"
	if n % 100 < 11 or n % 100 > 13:
		suf = {1: "st", 2: "nd", 3: "rd"}.get(n % 10, "th")
	return "%d%s" % [n, suf]


## After close, a cook who's settled in may show the kitchen their hometown dish.
func teach_dish(force = null) -> bool:
	if GameState.unlocked.has("hometown"):
		return false
	var who = force
	if who == null:
		var cands: Array = GameState.staff.filter(func(s): return s.role == "cook" and s.worked_today \
			and GameState.day - s.hired_day >= Data.TEACH_AFTER_DAYS and str(s.origin.get("dish", "")) != "")
		if cands.is_empty() or randf() > Data.TEACH_CHANCE:
			return false
		who = cands.pick_random()
	var dish: String = str(who.origin.get("dish", "house special"))
	GameState.set_hometown(who.person_name, dish)
	GameState.unlock_dish("hometown", "teach")
	var t := "After close, %s showed the kitchen how they make %s back in %s. %s is on the menu now." % [who.person_name, dish,
		str(who.origin.get("city", "their hometown")), GameState.hometown_name()]
	Crew.log_line(t, "cook", [who])
	GameState.toast.emit(t, "crew")
	who.add_stress(-Data.MILESTONE_STRESS, "taught their hometown dish")
	for o in GameState.staff:
		if o != who and o.worked_today and o.role in ["cook", "manager"]:
			Crew.add(o, who, "taught_dish")
	today_lines.append(["cook", "#ef8a3a", t])
	return true


## Every four weeks: whoever finished the most jobs.
func pick_eotm() -> void:
	var best = null
	var best_v := 0
	for s in GameState.staff:
		if s.jobs_month > best_v:
			best_v = s.jobs_month
			best = s
	if best == null:
		return
	eotm = {"id": best.id, "name": best.person_name, "role": best.role, "skin": best.skin.to_html(), "hair": best.hair.to_html(),
		"shirt": best.shirt.to_html(), "look": best.look, "day": GameState.day, "jobs": best_v}
	best.eotm_count += 1
	GameState.totals["eotm"] = int(GameState.totals.get("eotm", 0)) + 1
	best.wage += Data.EOTM_RAISE
	best.raises += Data.EOTM_RAISE
	best.add_stress(-Data.EOTM_STRESS, "employee of the month")
	var t := "%s is employee of the month (%d jobs in four weeks): their photo goes on the wall, and $%.2f more an hour." % [best.person_name, best_v, Data.EOTM_RAISE]
	GameState.toast.emit(t, "good")
	Crew.log_line(t, "star", [best])
	today_lines.append(["star", "#f2c14e", t])
	var jealous: Array = []
	for o in GameState.staff:
		if o == best:
			continue
		var l := Crew.label(o, best)
		if l in ["tense", "rivals"] or (o.jobs_month >= best_v * 0.8 and not l in ["friends", "best"]):
			Crew.add(o, best, "jealous")
			o.add_stress(Data.JEALOUS_STRESS, "jealous of %s" % best.person_name.split(" ")[0])
			jealous.append(o.person_name.split(" ")[0])
		elif l in ["friends", "best"]:
			Crew.add(o, best, "proud")
	if not jealous.is_empty():
		var jt := "%s grumbled that they'd earned it more." % Crew.and_list(jealous)
		Crew.log_line(jt, "storm")
		today_lines.append(["storm", "#e0923a", jt])
	for s in GameState.staff:
		s.jobs_month = 0
	if Crew.main != null:
		Crew.main.lot.queue_redraw()


func eotm_look() -> Dictionary:
	if eotm.is_empty():
		return {}
	return {"skin": Color(eotm["skin"]), "hair": Color(eotm["hair"]), "shirt": Color(eotm["shirt"]), "look": str(eotm.get("look", ""))}


func save_data() -> Dictionary:
	return {"eotm": eotm, "cake": cake_for}


func load_data(d: Dictionary) -> void:
	reset()
	eotm = d.get("eotm", {})
	cake_for = str(d.get("cake", ""))
