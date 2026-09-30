extends PanelContainer
## Shows whatever you clicked with the Inspect tool: a person, a piece of
## furniture or a floor tile. Updates live while it's open.

var main
var thing = null
var _t := 0.0
var upgrade_button: Button
var buy_button: Button

@onready var portrait: Portrait = %Portrait
@onready var art: ArtIcon = %Art
@onready var title: Label = %Title
@onready var subtitle: Label = %Subtitle
@onready var body: RichTextLabel = %Body
@onready var rotate_button: Button = %Rotate
@onready var close_button: Button = %Close

const STATES := {"arriving": "Walking in", "waiting": "Waiting for a table", "to_table": "Going to a table",
	"seated": "Waiting to order", "ordered": "Waiting for food", "eating": "Eating", "leaving": "Leaving",
	"inspecting": "Inspecting the diner"}
const GRADE_TEXT := {"A": "[color=#6cc3a0]A[/color]", "B": "[color=#f2c14e]B[/color]", "C": "[color=#e75a4e]C[/color]"}


func _ready() -> void:
	close_button.pressed.connect(func():
		thing = null
		main.build.selection = null
		main.build.queue_redraw()
		refresh())
	upgrade_button = Button.new()
	upgrade_button.theme_type_variation = &"SmallButton"
	upgrade_button.icon = UiKit.icon("star")
	upgrade_button.visible = false
	rotate_button.get_parent().add_child(upgrade_button)
	upgrade_button.pressed.connect(func():
		if thing == null or not (thing is RefCounted) or thing.get("tier") == null or thing.tier > 0:
			return
		var cost := upgrade_cost(thing)
		if GameState.spend(cost):
			thing.tier = 1
			GameState.toast.emit("The %s is now Pro: 25%% faster, and it wears out half as fast." % thing.info()["name"].to_lower(), "good")
			Sfx.play("repair", -4.0)
			main.lot.queue_redraw()
			refresh())
	# clicking a plot that's for sale: buy it right here
	buy_button = Button.new()
	buy_button.theme_type_variation = &"PrimaryButton"
	buy_button.icon = UiKit.icon("money")
	buy_button.visible = false
	rotate_button.get_parent().add_child(buy_button)
	buy_button.pressed.connect(func():
		if not (thing is Vector2i):
			return
		var p := GameState.plot_at(thing)
		if not p.is_empty() and GameState.buy_plot(p["id"]):
			Sfx.play("cash")
			main.lot.queue_redraw()
			refresh())
	rotate_button.pressed.connect(func():
		if thing != null and main.lot.rotate_furniture(thing):
			Sfx.play("place", -8.0)
			refresh())


func show_thing(t) -> void:
	thing = t
	refresh()


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0 or not visible:
		return
	_t = 0.2
	refresh()


func valid() -> bool:
	if thing == null:
		return false
	if typeof(thing) == TYPE_OBJECT and not is_instance_valid(thing):
		return false
	if thing is RefCounted and thing.get("type") != null and not main.lot.furniture.has(thing):
		return false
	return true


func refresh() -> void:
	if main == null or not valid():
		thing = null
		visible = false
		return
	var t = thing
	portrait.visible = false
	art.visible = false
	rotate_button.visible = false
	upgrade_button.visible = false
	buy_button.visible = false
	var sub := ""
	var text := ""
	if t is Vector2i:
		var c: Vector2i = t
		var lot = main.lot
		if not lot.in_lot(c):
			visible = false
			return
		var i: int = lot.idx(c)
		art.visible = true
		art.what = "floor:%d" % lot.floor_type[i]
		var plot := GameState.plot_at(c)
		if not plot.is_empty() and not GameState.owned.has(plot["id"]):
			# land for sale
			art.what = "land"
			title.text = plot["name"]
			var r2: Rect2i = plot["rect"]
			sub = "For sale: $%s" % UiKit.thousands(plot["cost"])
			text = "%d by %d tiles. Buy it to build on it; it adds $%d a week to the rent." % [r2.size.x, r2.size.y, plot.get("rent", 0)]
			buy_button.visible = true
			buy_button.text = "Buy this plot  ($%s)" % UiKit.thousands(plot["cost"])
			buy_button.disabled = not GameState.is_building_allowed() or not GameState.can_afford(plot["cost"])
			buy_button.tooltip_text = "You can buy land in the morning, before you start the day." if not GameState.is_building_allowed() \
				else ("You need $%s." % UiKit.thousands(plot["cost"]) if not GameState.can_afford(plot["cost"]) else "Buy the %s." % plot["name"].to_lower())
		elif c.y > Data.SIDEWALK_Y:
			title.text = "The street"
		elif c.y == Data.SIDEWALK_Y:
			title.text = "The sidewalk"
			text = "Customers arrive from both ends."
		elif lot.wall[i] == 1:
			title.text = "Wall"
			art.what = "wall"
		elif lot.wall[i] == 2:
			title.text = "Door"
			art.what = "door"
			text = "Customers come in here." if c == lot.entry_door else "Staff can use this door."
		elif lot.floor_type[i] > 0:
			title.text = Data.BUILD[["", "floor_diner", "floor_kitchen", "floor_staff", "floor_restroom"][lot.floor_type[i]]]["name"]
			var d: float = lot.dirt[i]
			sub = "Dirt %d%%" % int(d * 100)
			if d >= Data.DIRT_SHOW:
				text = "Waiting for someone with [b]Clean[/b] switched on to sweep it."
			var b: int = lot.beauty_near(c)
			text += ("\n" if text != "" else "") + "Atmosphere here: %d of %d." % [b, Data.MAX_BEAUTY]
		else:
			title.text = "Grass"
			text = "Lay a floor to build here." if c.y <= Data.BUILD_MAX_Y else "The front lawn."
	elif t is RefCounted and t.get("type") != null:
		var r: Array = describe_furniture(t)
		sub = r[0]
		text = r[1]
		art.visible = true
		art.what = "furniture:" + t.type
		art.dir = t.dir if not t.on_wall() else 0
		title.text = Data.FURNITURE[t.type]["name"]
		rotate_button.visible = GameState.is_building_allowed() and not t.on_wall()
		if t.is_station() and t.tier == 0:
			upgrade_button.visible = GameState.is_building_allowed()
			upgrade_button.text = "Upgrade to Pro  ($%d)" % upgrade_cost(t)
			upgrade_button.tooltip_text = "Pro stations cook 25% faster and wear out half as fast. Mornings only."
		if t.is_station() and t.tier > 0:
			title.text = "Pro " + title.text.to_lower()
	elif t.get("person_name") != null:
		portrait.visible = true
		portrait.show_person(t)
		title.text = "%s, %s" % [t.person_name, Data.ROLES[t.role]["name"].to_lower()]
		sub = "%s · %s" % [Data.hometown(t.origin), t.status]
		var bits: Array = []
		for tr in t.traits:
			bits.append("[color=%s]%s[/color]" % ["#6cc3a0" if Data.TRAITS[tr]["good"] else "#e75a4e", Data.TRAITS[tr]["name"]])
		var mood_col: String = "#" + Crew.MOOD_COLORS.get(t.mood, UiKit.MUTED).to_html(false)
		text = "[font_size=12][color=#b9a797]%s Signature dish: %s.[/color][/font_size]\n" % [t.bio, t.origin.get("dish", "?")]
		var stress_col := "#e75a4e" if t.stress >= Data.STRESS_FED_UP else ("#f2c14e" if t.stress > Data.STRESS_CHEERFUL else "#6cc3a0")
		text += "[color=%s][b]%s[/b][/color] · stress [color=%s][b]%d%%[/b][/color] · cook [b]%d[/b] · serve [b]%d[/b] · energy [b]%d%%[/b] · $%.2f/hr" % [
			mood_col, Crew.MOOD_NAMES.get(t.mood, "Okay"), stress_col, int(t.stress), t.cooking, t.service, int(t.energy), t.wage]
		if not bits.is_empty():
			text += "  ·  " + ", ".join(bits)
		if t.warnings > 0:
			text += "  ·  [color=#e75a4e]%d warning%s[/color]" % [t.warnings, "" if t.warnings == 1 else "s"]
		var ops: Array = []
		for o in Crew.team():
			if o != t:
				ops.append([o, Crew.opinion(t, o)])
		ops.sort_custom(func(x, y): return absf(x[1]) > absf(y[1]))
		var op_bits: Array = []
		for o in ops.slice(0, 3):
			var v := int(round(o[1]))
			var col: String = "#6cc3a0" if v >= 10 else ("#e75a4e" if v <= -10 else "#b9a797")
			op_bits.append("%s [color=%s]%s[/color]" % [o[0].person_name, col, OpinionGrid.signed(v)])
		if not op_bits.is_empty():
			text += "\nThinks of: " + ", ".join(op_bits)
		if t.on_phone:
			text += "\n[color=#6aa6d9]On the phone. Click them to catch them.[/color]"
		elif t.job != null:
			text += "\nJob: " + t.job.describe()
	elif t.get("group") != null and t.group != null and is_instance_valid(t.group):
		var g = t.group
		portrait.visible = true
		portrait.show_person(t)
		title.text = Data.CUSTOMERS[g.kind]["name"]
		sub = STATES.get(g.state, g.state)
		if g.members.size() > 1:
			text = "A group of %d." % g.members.size()
		if g.patience_left() >= 0.0:
			text += ("\n" if text != "" else "") + "Patience %d%%" % int(g.patience_left() * 100)
		var waiting: Array = g.waiting_for()
		if g.state == "ordered" and not waiting.is_empty():
			var names: Array = waiting.map(func(d): return Data.DISHES[d]["name"].to_lower())
			text += "\nWaiting for: " + ", ".join(names)
		if g.kind == "critic":
			text += "\n[color=#f2c14e]Their review counts five times.[/color]"
	else:
		visible = false
		return
	subtitle.text = sub
	subtitle.visible = sub != ""
	body.text = text
	body.visible = text != ""
	visible = true


func upgrade_cost(f) -> int:
	return int(Data.FURNITURE[f.type]["cost"] * Data.UPGRADE_COST)


func describe_furniture(f) -> Array:
	var info: Dictionary = Data.FURNITURE[f.type]
	var sub := ""
	var text: String = info["desc"]
	match f.type:
		"table", "table_small":
			sub = "%d chair%s" % [f.chairs.size(), "" if f.chairs.size() == 1 else "s"]
			if f.chairs.is_empty():
				text = "Put chairs next to it so customers can sit here."
			if f.group != null:
				sub += ", customers sitting"
			if f.dirty_plates > 0:
				text += "\n[color=#f2c14e]%d dirty plate%s waiting to be cleared.[/color]" % [f.dirty_plates, "" if f.dirty_plates == 1 else "s"]
			text += "\nAtmosphere: %d of %d." % [main.lot.beauty_near(f.cell), Data.MAX_BEAUTY]
		"chair":
			sub = "At a table" if f.table != null else "Not next to a table"
		"pass":
			sub = "%d of %d spots used" % [f.items.size(), Data.PASS_SLOTS]
		"sink":
			sub = "%d dirty plate%s" % [f.dirty, "" if f.dirty == 1 else "s"]
		"sofa":
			var n := 0
			for c in f.resters:
				if f.resters[c] != null and is_instance_valid(f.resters[c]):
					n += 1
			sub = "%d resting" % n
		"takeout":
			sub = "A customer is waiting" if f.group != null else "Nobody waiting"
		"prep":
			var bits: Array = []
			for d in Data.DISH_ORDER:
				if Stock.ready_portions(d) > 0:
					bits.append("%d %s" % [Stock.ready_portions(d), Data.DISHES[d]["name"].to_lower()])
			sub = ("In use by %s" % f.user.person_name) if f.user != null and is_instance_valid(f.user) else "Free"
			if not bits.is_empty():
				text += "\nReady: " + ", ".join(bits) + "."
		"fridge", "freezer":
			var bits2: Array = []
			for space in ["fridge", "freezer"]:
				if Data.STORAGE[f.type].has(space):
					bits2.append("%s %d of %d" % [Data.STORE_NAMES[space], Stock.used(space), Stock.capacity(space)])
			sub = "  ·  ".join(bits2)
		"grill", "fryer", "griddle", "drinks":
			if f.broken:
				sub = "Broken"
				text = "[color=#e75a4e]Broken.[/color] Someone with [b]Repair[/b] switched on will fix it for $%d in parts." % int(Data.REPAIR_COST)
			elif f.user != null and is_instance_valid(f.user):
				sub = "In use by %s" % f.user.person_name
			else:
				sub = "Free"
			text += "\nWear: %d%%. Worn stations break down more often." % int(f.wear * 100)
	if info.get("beauty", 0) > 0:
		text += "\nCheers up tables within %d tiles (+%d atmosphere)." % [info.get("radius", 3), info["beauty"]]
	return [sub, text]
