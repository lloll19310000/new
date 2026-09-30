extends "res://people/pawn.gd"
## A single customer. Their group decides where they go; they just walk and sit.
## Now and then one of them pops off to the restroom (an errand) and comes back.

var group = null
var seat = null
var errand := ""                # "", "to_toilet", "waiting", "using", "back"
var errand_left := 0.0
var toilet = null


func setup(lot_ref, g, index: int = 0) -> void:
	lot = lot_ref
	group = g
	customer_nav = g.kind != "inspector"
	skin = Data.SKIN.pick_random()
	hair = Data.HAIR.pick_random()
	shirt = Data.CLOTHES.pick_random()
	var info: Dictionary = Data.CUSTOMERS[g.kind]
	look = info["look"]
	if look == "family":
		look = ""
		if index >= 2:
			body_scale = 0.78   # the kids
	if g.kind == "critic":
		shirt = Color("3b3340")
	offset = Vector2(randf_range(-6, 6), randf_range(-5, 5))


## Off to the restroom. Returns false if there's no way there.
func start_restroom(t) -> bool:
	if t == null or not go_to(t.cell):
		return false
	toilet = t
	errand = "to_toilet"
	errand_left = 4.0     # how long they'll wait if it's busy
	sitting = false
	offset = Vector2.ZERO
	return true


func errand_tick(minutes: float) -> void:
	match errand:
		"to_toilet":
			if is_moving():
				return
			if toilet == null or not lot.furniture.has(toilet):
				come_back()
				return
			if toilet.occupant != null and toilet.occupant != self and is_instance_valid(toilet.occupant):
				errand_left -= minutes
				if errand_left <= 0.0:
					come_back()
				return
			toilet.occupant = self
			sitting = true
			place_at(toilet.cell)
			errand = "using"
			errand_left = Data.TOILET_MINUTES
		"using":
			errand_left -= minutes
			if errand_left <= 0.0:
				toilet.occupant = null
				Health.used_toilet(toilet, group)
				come_back()
		"back":
			if is_moving():
				return
			errand = ""
			if seat != null and group != null and is_instance_valid(group) and group.state in ["seated", "ordered", "eating"]:
				sitting = true
				place_at(seat.cell)
				if group.table != null:
					face_toward(group.table.center_px())


func come_back() -> void:
	if toilet != null and toilet.occupant == self:
		toilet.occupant = null
	toilet = null
	sitting = false
	errand = "back"
	if seat == null or not go_to(seat.cell):
		errand = ""


## The group is leaving: drop whatever they were doing.
func cancel_errand() -> void:
	if toilet != null and toilet.occupant == self:
		toilet.occupant = null
	toilet = null
	errand = ""


func _draw() -> void:
	super._draw()
	if group == null or not is_instance_valid(group):
		return
	var p: float = group.patience_left()
	if p >= 0.0 and p < 0.999 and errand == "":
		var w := 18.0
		var r := Rect2(Vector2(-w / 2, -19), Vector2(w, 3))
		draw_rect(r, Color(0, 0, 0, 0.55))
		draw_rect(Rect2(r.position, Vector2(w * p, 3)), Color(0.9, 0.3, 0.25).lerp(Color(0.35, 0.8, 0.4), p))
