extends PanelContainer
## One ingredient on the Supplies page: how much is left, how much goes off
## tonight, and how much to keep.

var ing := ""

@onready var icon: ArtIcon = %Icon
@onready var name_label: Label = %Name
@onready var have: Label = %Have
@onready var bar: ProgressBar = %Bar
@onready var keep: SpinBox = %Keep


func setup(i: String) -> void:
	ing = i


func _ready() -> void:
	icon.what = "ingredient:" + ing
	name_label.text = Data.INGREDIENTS[ing]["name"]
	keep.value_changed.connect(func(v: float):
		GameState.target[ing] = int(v)
		GameState.stock_changed.emit())
	var used: Array = []
	for d in Data.DISH_ORDER:
		if Data.DISHES[d]["needs"].has(ing):
			used.append(Data.DISHES[d]["name"].to_lower())
	var info: Dictionary = Data.INGREDIENTS[ing]
	tooltip_text = "%s: $%.2f each. Used for %s.\nKept on the %s. Lasts %d day%s from delivery, then it's thrown out." % [info["name"], info["cost"], ", ".join(used),
		Data.STORE_NAMES[info["store"]].to_lower(), info["life"], "" if info["life"] == 1 else "s"]
	keep.tooltip_text = "Every night you order enough to top this up to this many (as far as the space allows). It arrives in the morning and you pay then."
	refresh()


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
	have.add_theme_color_override("font_color", UiKit.CHERRY if n < 8 else UiKit.MUTED)
	bar.max_value = maxf(1.0, maxf(t, n))
	bar.value = n
	bar.theme_type_variation = &"WarnBar" if n < 8 else &"ProgressBar"
	keep.set_value_no_signal(t)
