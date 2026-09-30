extends PanelContainer
## Someone looking for work: portrait, hometown, traits, skills, wage, a Hire
## button, their life story, and whether they'd clash with your crew.

signal hire_requested(index: int)

var data: Dictionary = {}
var index := 0

@onready var portrait: Portrait = %Portrait
@onready var name_label: Label = %Name
@onready var traits_box: HFlowContainer = %Traits
@onready var cook_bar: ProgressBar = %CookBar
@onready var cook_value: Label = %CookValue
@onready var serve_bar: ProgressBar = %ServeBar
@onready var serve_value: Label = %ServeValue
@onready var wage_label: Label = %Wage
@onready var hire_button: Button = %Hire
@onready var origin_label: Label = %Origin
@onready var bio_label: Label = %Bio
@onready var hints_label: Label = %Hints


func setup(d: Dictionary, i: int) -> void:
	data = d
	index = i


func _ready() -> void:
	portrait.show_person(data)
	name_label.text = data["name"]
	UiKit.fill_traits(traits_box, data.get("traits", []))
	cook_bar.value = data["cooking"]
	cook_value.text = str(data["cooking"])
	serve_bar.value = data["service"]
	serve_value.text = str(data["service"])
	cook_bar.tooltip_text = "Cooking %d of 10" % data["cooking"]
	serve_bar.tooltip_text = "Service %d of 10" % data["service"]
	wage_label.text = "$%d/shift" % data["wage"]
	hire_button.tooltip_text = "Hire %s for $%d an 8-hour shift, paid every night (time and a half after 8 hours)." % [data["name"], data["wage"]]
	hire_button.pressed.connect(func(): hire_requested.emit(index))
	var origin: Dictionary = data.get("origin", {})
	origin_label.text = "From " + Data.hometown(origin) if not origin.is_empty() else ""
	origin_label.visible = not origin.is_empty()
	bio_label.text = data.get("bio", "")
	if not origin.is_empty():
		bio_label.text += " Signature dish: %s." % origin.get("dish", "")
	bio_label.visible = bio_label.text != ""
	var hints: Array = Crew.clash_hints(data.get("traits", []))
	hints_label.text = "\n".join(hints)
	hints_label.visible = not hints.is_empty()
