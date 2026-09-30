extends RefCounted
## Checks for version 9: the town (calendar, seasons, holidays, weather,
## events, the rival), the business (suppliers, catering, combos, upselling,
## a sister diner, late nights), the crew's working lives (careers, perks,
## time off, availability, the huddle, benefits), kids, the review wall,
## carhops, the Books, undo and blueprints, the scrapbook and the music.
## Called from autotest.gd.

const T = preload("res://tests/autotest.gd")
const Group = preload("res://people/group.gd")


static func check(ok: bool, what: String) -> void:
	T.check(ok, what)


static func run(main) -> void:
	main.new_game("Nine Diner")
	await main.get_tree().process_frame
	GameState.own_all_land()
	GameState.money = 500000.0
	T.build_sample(main.lot)
	for r in ["cook", "cook", "server", "server", "manager"]:
		main.add_staff(GameState.make_candidate(r))
	town_checks(main)
	biz_checks(main)
	career_checks(main)
	customer_checks(main)
	tool_checks(main)
	await save_checks(main)


static func town_checks(main) -> void:
	check(Town.date_text(1) == "Mon, Mar 1" and Town.season(1) == "spring", "day 1 is Monday the 1st of March, in spring (%s)" % Town.date_text(1))
	check(Town.season(1 + 31 + 30 + 31 + 30) == "summer", "July is summer")
	var d4 := 1 + (185 - 60)   # July 4th
	check(Town.holiday(d4).get("key", "") == "july4", "the Fourth of July is a holiday (%s)" % Town.date_text(d4))
	GameState.day = d4
	check(Town.dish_mult("burger") > 1.5 and Town.crowd_mult() > 1.2, "the Fourth brings a crowd that wants burgers")
	GameState.day = 1 + 306   # January
	Town.weather = "snow"
	check(Town.season() == "winter" and Town.dish_mult("soup") > 2.0 and Town.dish_mult("icedtea") < 0.8, "in a snowy winter people want soup, not iced tea")
	check(Town.price_mult("veg") > 1.1, "vegetables cost more in winter")
	check(Town.kind_mult("trucker") > 2.0, "truckers stuck in the snow pull in")
	Town.weather = "clear"
	GameState.day = 1
	Town.events = [{"key": "roadwork", "from": 1, "until": 3}]
	check(Town.event_on("roadwork") and Town.crowd_mult() < 0.9, "roadwork out front means fewer walk-ins")
	Town.events = []
	GameState.rep_level = Data.RIVAL_AT_LEVEL
	Town.rival = {"name": "Dina's Diner", "strength": 0.2, "since": 1, "good_days": 0, "closed": false}
	var pull := Town.rival_pull()
	Town.loyalty_cards = true
	Town.price_match = true
	check(pull > 0.15 and Town.rival_pull() < pull * 0.5, "loyalty cards and price matching cut what the rival takes (%.2f to %.2f)" % [pull, Town.rival_pull()])
	check(GameState.price("burger") < GameState.menu["burger"]["price"], "price matching takes a little off the prices")
	Town.rival["good_days"] = Data.RIVAL_BEAT_DAYS - 1
	GameState.rating = 4.6
	Town.rival_nightly()
	check(not Town.rival_open(), "stay excellent and the rival closes")
	Town.reset()
	GameState.rep_level = 0
	GameState.rating = 3.0


static func biz_checks(main) -> void:
	var before := Stock.unit_cost("meat")
	Biz.set_contract("butcher", true)
	check(Stock.unit_cost("meat") < before, "a supplier contract takes money off their prices")
	Biz.after_delivery(false, ["meat"])
	check(Biz.reps["butcher"]["rel"] < 50.0, "a turned-away delivery upsets the supplier")
	Biz.reps["farm"]["rel"] = 90.0
	check(Biz.never_short("veg"), "a supplier who loves you never leaves you short")
	GameState.rep_level = 1
	Biz.catering = [{"id": 1, "client": "the test wedding", "day": GameState.day, "dishes": {"burger": 10}, "pay": 150.0, "state": "offer"}]
	Biz.accept(1, true)
	check(not Biz.today_job().is_empty(), "a catering job can be accepted")
	Stock.prepped["burger"] = 10
	GameState.minute = Data.CATERING_PICKUP
	var cash := GameState.money
	Biz.tick(1.0)
	check(GameState.money > cash + 149.0 and Biz.catering[0]["state"] == "done", "the van picks up the catering and pays for it")
	# combos and upselling
	GameState.combos["classic"] = true
	check(GameState.combo_price(Data.COMBOS[0]) < GameState.price("burger") + GameState.price("fries") + GameState.price("soda"), "a combo is cheaper than its dishes")
	var server = GameState.staff.filter(func(s): return s.role == "server")[0]
	var p0: float = server.upsell_chance()
	Career.huddle = "upsell"
	server.perks.append("upseller")
	check(server.upsell_chance() > p0 + 0.1, "the upselling huddle and the Upseller perk make pies sell")
	server.perks.erase("upseller")
	Career.huddle = ""
	# late night
	check(Data.SERVICES.any(func(s): return s["key"] == "latenight"), "late-night hours can be switched on")
	GameState.set_service("latenight", true)
	check(GameState.close_min() >= 26 * 60 - 1, "late nights run to 02:00")
	GameState.set_service("latenight", false)
	# a sister diner
	GameState.rep_level = Data.SECOND_AT_LEVEL
	check(Biz.can_open_second(), "a Destination diner with money to spare can open a second diner")
	GameState.rep_level = 0


static func career_checks(main) -> void:
	var cook = GameState.staff.filter(func(s): return s.role == "cook")[0]
	cook.cooking = 7
	cook.shifts_worked = 35
	cook.rank = 0
	var wage: float = cook.wage
	Events.auto_choice = 0
	Career.nightly()
	check(cook.rank == 2 and cook.wage > wage and cook.perks.size() == 1, "a cook with the skill and the shifts moves up, with a raise and a perk (%s, %s)" % [Career.title(cook), cook.perks])
	check(Career.title(cook) == "Senior line cook", "their title")
	cook.perks = ["flip_master"]
	var j := preload("res://people/job.gd").new()
	j.kind = "cook"
	cook.job = j
	var fast: float = cook.work_speed(true)
	cook.perks = []
	check(fast > cook.work_speed(true) * 1.15, "Flip master cooks faster")
	cook.job = null
	cook.requested_off = [GameState.day + 2]
	check(Shifts.works_off(cook, GameState.day + 2), "a day off they asked for is off the schedule")
	cook.requested_off = []
	# benefits
	Career.set_benefit("health", true)
	check(Career.benefits_week() >= Data.BENEFITS["health"]["per_person"] * GameState.staff.size(), "health insurance costs a set amount a person each week")
	Career.set_benefit("health", false)
	Career.huddle = "speed"
	check(Career.speed_bonus() > 1.05, "a speed huddle makes everyone a bit quicker")
	Career.huddle = ""


static func customer_checks(main) -> void:
	var g := Group.new()
	g.lot = main.lot
	g.kind = "family"
	g.kids = 2
	g.table = main.lot.tables()[0]
	g.kid_tick(Data.CRAYON_WAIT + 1.0)
	check(g.crying and g.extra_hits.has("a bored, crying kid"), "a family without crayons ends up with a crying kid")
	g.got_crayons()
	check(not g.crying and g.crayons, "the crayons calm it down")
	g.table = null
	g.free()
	check(Data.FURNITURE.has("highchair") and Data.FURNITURE.has("stall"), "high chairs and drive-in stalls")
	check(not GameState.item_unlocked("stall"), "the drive-in stall unlocks later")
	var n := GameState.review_feed.size()
	GameState.write_review("Big Jim", 1.5, "slow food", "burger")
	GameState.write_review("June", 5.0, "", "pie")
	check(GameState.review_feed.size() == n + 2 and GameState.review_feed[-2]["text"].to_lower().contains("slow food"), "people write reviews (%s)" % GameState.review_feed[-2]["text"])
	var bad_id: int = GameState.review_feed[-2]["id"]
	var mood := GameState.reply_mood
	GameState.reply_review(bad_id, "sorry")
	check(GameState.reply_mood > mood and GameState.review_feed[-2]["reply"] != "", "an apology and a free pie go down well")
	var good_id: int = GameState.review_feed[-1]["id"]
	GameState.reply_review(good_id, "argue")
	check(GameState.reply_mood < mood + 1.0, "arguing with reviewers doesn't")


static func tool_checks(main) -> void:
	var lot = main.lot
	GameState.phase = GameState.Phase.PLANNING
	var n: int = lot.furniture.size()
	var cash := GameState.money
	main.build.remember()
	lot.place_furniture("plant", Vector2i(16, 13), 0)
	check(lot.furniture.size() == n + 1, "placed a plant")
	main.build.undo()
	check(lot.furniture.size() == n and absf(GameState.money - cash) < 0.01, "Ctrl+Z takes it back, money and all")
	var bp: Dictionary = lot.copy_area(Rect2i(5, 5, 4, 4))
	check(not bp["furn"].is_empty() and lot.blueprint_cost(bp) > 0, "an area can be copied as a blueprint ($%d)" % lot.blueprint_cost(bp))
	check(lot.paste_area(bp, Vector2i(5, 5)) != "", "it won't paste over what's there")
	check(lot.paste_area(bp, Vector2i(33, 18)) == "", "it pastes onto empty land")
	GameState.playlist = "country"
	check(Data.PLAYLISTS[GameState.playlist]["likes"]["trucker"] > 0.2, "truckers love the country playlist")
	check(Data.RADIO.has("hits") and Data.FURNITURE.has("radio"), "a kitchen radio")
	GameState.history = [{"day": 1, "net": 100.0, "wages": 500.0}, {"day": 2, "net": 300.0, "wages": 500.0}]
	check(is_equal_approx(GameState.weekly_profit(), 1400.0), "the Books know a week's profit ($%d)" % int(GameState.weekly_profit()))


static func save_checks(main) -> void:
	GameState.scrapbook.append({"day": 1, "kind": "photo", "title": "Test", "text": "A snapshot.", "img": ""})
	Town.weather = "rain"
	Career.set_benefit("pto", true)
	main.save_game()
	check(main.load_game(main.slot), "a v9 diner loads")
	check(Town.weather == "rain" and Career.has_benefit("pto") and GameState.scrapbook.size() >= 1 and GameState.playlist == "country"
		and GameState.review_feed.size() >= 2 and GameState.history.size() >= 2 and Biz.reps["butcher"]["contract"], "the town, benefits, scrapbook, music, reviews, books and suppliers are saved")
	await main.get_tree().process_frame
