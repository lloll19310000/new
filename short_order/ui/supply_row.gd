extends PanelContainer
## One ingredient on the Supplies page: how much is left, how much goes off
## tonight, and how much to keep. − and + change the amount by 5 (Shift: 25);
## you can also type it in.

const MAX_KEEP := 500

var ing := ""

@onready var icon: ArtIcon = %Icon
@onready var name_label: Label = %Name
@onready var have: Label = %Have
@onready var bar: ProgressBar = %Bar
@onready var keep_box: HBoxContainer = %Keep
@onready var less: Button = %Less
@onready var more: Button = %More
@onready var amount: LineEdit = %Amount


func setup(i: String) -> void:
	ing = i


func _ready() -> void:
	icon.what = "ingredient:" + ing
	name_label.text = Data.INGREDIENTS[ing]["name"]
	less.pressed.connect(func(): step(-1))
	more.pressed.connect(func(): step(1))
	amount.text_submitted.connect(func(_t): _typed())
	amount.focus_exited.connect(_typed)
	var used: Array = []
	for d in Data.DISH_ORDER:
		if Data.DISHES[d]["needs"].has(ing) and GameState.dish_known(d):
			used.append(Data.DISHES[d]["name"].to_lower())
	var info: Dictionary = Data.INGREDIENTS[ing]
	tooltip_text = "%s: $%.2f each. Used for %s.\nKept on the %s. Lasts %d day%s from delivery, then it's thrown out." % [info["name"], info["cost"], ", ".join(used),
		Data.STORE_NAMES[info["store"]].to_lower(), info["life"], "" if info["life"] == 1 else "s"]
	keep_box.tooltip_text = "Every night you order enough to top this up to this many (as far as the space allows). It arrives in the morning and you pay then.\n− and + change it by 5, or 25 with Shift held. You can type a number too."
	refresh()


func set_keep(v: int) -> void:
	GameState.target[ing] = clampi(v, 0, MAX_KEEP)
	amount.text = str(GameState.target[ing])
	GameState.stock_changed.emit()


func step(dir: int) -> void:
	var by := 25 if Input.is_key_pressed(KEY_SHIFT) else 5
	set_keep(GameState.target[ing] + dir * by)


func _typed() -> void:
	var t := amount.text.strip_edges()
	if t.is_valid_int():
		set_keep(int(t))
	else:
		amount.text = str(GameState.target[ing])


func refresh() -> void:
	var n: int = GameState.stock[ing]
	var t: int = GameState.target[ing]
	var off := Stock.expiring(ing)
	var bits: Array = ["%d left" % n]
	if off > 0:
		bits.append("%d go off tonight" % off)
	elif Stock.used_yesterday.has(ing):
		bits.append("used %d yesterday" % Stock.used_yesterday[ing])
	have.text = "  ·  ".join(bits)
	have.add_theme_color_override("font_color", UiKit.CHERRY if n < 8 or off > 0 else UiKit.MUTED)
	bar.max_value = maxf(1.0, maxf(t, n))
	bar.value = n
	bar.theme_type_variation = &"WarnBar" if n < 8 else &"ProgressBar"
	# never overwrite the box while someone's typing in it
	if not amount.has_focus():
		amount.text = str(t)
