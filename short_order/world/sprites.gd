class_name Sprites
extends RefCounted
## Pixel-art sprites from the Kenney packs (CC0, see art/LICENSE.txt) plus our
## own diner pieces in art/diner.png (drawn by tools/make_diner_sheet.py).
## Every sheet is 16px tiles with a 1px gap; the world draws them at 2x, so a
## tile fills one 32px grid square.

const INDOOR := preload("res://art/kenney_indoor.png")   # Roguelike Indoors
const RPG := preload("res://art/kenney_rpg.png")         # Roguelike RPG: floors
const URBAN := preload("res://art/kenney_urban.png")     # RPG Urban: street, cars, people
const DINER := preload("res://art/diner.png")            # ours

## Our own pieces in diner.png: name -> [column, row, width, height] in tiles.
## Keep in step with tools/make_diner_sheet.py (it prints this list).
const DINER_TILES := {
	"grill": [0, 0, 2, 1], "griddle": [2, 0, 2, 1], "fryer": [4, 0, 1, 1], "oven": [5, 0, 1, 1],
	"fridge": [6, 0, 1, 1], "freezer": [7, 0, 1, 1], "ice": [8, 0, 1, 1], "prep": [9, 0, 2, 1],
	"sink": [11, 0, 1, 1], "handsink": [12, 0, 1, 1], "drinks": [13, 0, 1, 1], "pass": [14, 0, 2, 1],
	"radio": [0, 1, 1, 1], "bin": [1, 1, 1, 1], "trap": [2, 1, 1, 1], "booth_down": [3, 1, 1, 1],
	"booth_up": [4, 1, 1, 1], "booth_side": [5, 1, 1, 1], "stool": [6, 1, 1, 1], "counter": [7, 1, 1, 1],
	"highchair": [8, 1, 1, 1], "host": [9, 1, 1, 1], "till": [10, 1, 1, 1], "jukebox": [11, 1, 1, 1],
	"gumball": [12, 1, 1, 1], "aquarium": [13, 1, 2, 1], "rug": [0, 2, 2, 1], "neon": [2, 2, 1, 1],
	"records": [3, 2, 1, 1], "tin_sign": [4, 2, 1, 1], "trophy": [5, 2, 1, 1], "clock": [6, 2, 1, 1],
	"eotm": [7, 2, 1, 1], "whiteboard": [8, 2, 1, 1], "takeout": [9, 2, 1, 1], "wall_art": [10, 2, 1, 1],
	"coffee_maker": [11, 2, 1, 1], "tv": [12, 2, 1, 1], "lockers": [13, 2, 2, 1], "vending": [15, 2, 1, 1],
	"desk": [0, 3, 2, 1], "filing": [2, 3, 1, 1], "sofa": [3, 3, 2, 1], "staff_table": [5, 3, 2, 1],
	"toilet": [7, 3, 1, 1], "dumpster": [8, 3, 2, 1], "lamp": [10, 3, 1, 1], "palm": [11, 3, 1, 1],
	"flowers": [12, 3, 1, 1], "plant": [13, 3, 1, 1], "stall": [14, 3, 2, 2], "floor_diner": [0, 5, 1, 1], "floor_kitchen": [1, 5, 1, 1],
	"car_red": [2, 5, 2, 1], "car_blue": [4, 5, 2, 1], "car_yellow": [6, 5, 2, 1], "car_green": [8, 5, 2, 1],
	"car_white": [10, 5, 2, 1], "bus": [12, 5, 3, 1], "van": [0, 6, 2, 1],
}

## Furniture that comes from the Kenney indoor sheet: "h" is the piece lying
## left to right (its tiles in order), "v" standing top to bottom.
const INDOOR_FURNITURE := {
	"table": {"h": [Vector2i(0, 0), Vector2i(2, 0)], "v": [Vector2i(5, 0), Vector2i(5, 1)]},
	"staff_table": {"h": [Vector2i(0, 0), Vector2i(2, 0)], "v": [Vector2i(5, 0), Vector2i(5, 1)]},
	"long_table": {"h": [Vector2i(0, 9), Vector2i(1, 9), Vector2i(2, 9)], "v": [Vector2i(5, 9), Vector2i(5, 10), Vector2i(5, 11)]},
	"table_small": {"h": [Vector2i(7, 0)]},
	"bench": {"h": [Vector2i(4, 6), Vector2i(7, 6)]},
}

## Chairs from the indoor sheet, by the way the sitter faces (0 up, 1 right, 2 down, 3 left).
const CHAIRS := [Vector2i(1, 2), Vector2i(3, 2), Vector2i(0, 2), Vector2i(2, 2)]

## Floor tiles: [sheet, column, row].
const FLOORS := {
	"grass": [1, 5, 0], "grass2": [1, 5, 1], "sidewalk": [2, 8, 1], "road": [2, 9, 17],
	"staff": [1, 8, 2], "restroom": [1, 46, 26],
}


static func region(col: int, row: int, w: int = 1, h: int = 1) -> Rect2:
	return Rect2(col * 17, row * 17, w * 17 - 1, h * 17 - 1)


## One tile (or a block of w x h tiles) from a sheet, stretched to fill dest.
static func blit(ci: CanvasItem, tex: Texture2D, col: int, row: int, dest: Rect2, w: int = 1, h: int = 1, mod: Color = Color.WHITE) -> void:
	ci.draw_texture_rect_region(tex, dest, region(col, row, w, h), mod)


## Draws a sheet block turned a quarter (clockwise) into dest, for pieces we only have lying one way.
static func blit_turned(ci: CanvasItem, tex: Texture2D, src: Rect2, dest: Rect2, turns: int, mod: Color = Color.WHITE) -> void:
	var c := dest.get_center()
	var sz := dest.size if turns % 2 == 0 else Vector2(dest.size.y, dest.size.x)
	ci.draw_set_transform(c, turns * PI * 0.5, Vector2.ONE)
	ci.draw_texture_rect_region(tex, Rect2(-sz / 2.0, sz), src, mod)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func blit_flipped(ci: CanvasItem, tex: Texture2D, src: Rect2, dest: Rect2, mod: Color = Color.WHITE) -> void:
	ci.draw_set_transform(Vector2(dest.end.x, dest.position.y), 0.0, Vector2(-1, 1))
	ci.draw_texture_rect_region(tex, Rect2(Vector2.ZERO, dest.size), src, mod)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func has_furniture(type: String) -> bool:
	return type in ["chair", "wait_chair", "booth"] or INDOOR_FURNITURE.has(type) or DINER_TILES.has(type)


## The furniture's picture filling r. dir is its rotation (0-3). Returns false
## for anything there's no sprite for.
static func furniture(ci: CanvasItem, type: String, r: Rect2, dir: int, mod: Color = Color.WHITE) -> bool:
	var along_x := r.size.x >= r.size.y - 0.5
	if type == "chair" or type == "wait_chair":
		var c: Vector2i = CHAIRS[dir % 4]
		blit(ci, INDOOR, c.x, c.y, r, 1, 1, mod)
		return true
	if type == "booth":
		match dir % 4:
			0:
				_diner(ci, "booth_up", r, mod)
			2:
				_diner(ci, "booth_down", r, mod)
			1:
				_diner(ci, "booth_side", r, mod)
			3:
				var t: Array = DINER_TILES["booth_side"]
				blit_flipped(ci, DINER, region(t[0], t[1]), r, mod)
		return true
	if INDOOR_FURNITURE.has(type):
		var spec: Dictionary = INDOOR_FURNITURE[type]
		var cells: Array = spec["h"] if along_x or not spec.has("v") else spec["v"]
		if not along_x and not spec.has("v"):
			# only drawn lying left to right: turn it
			var n := cells.size()
			var step := r.size.y / n
			for i in n:
				var cl: Vector2i = cells[i]
				blit_turned(ci, INDOOR, region(cl.x, cl.y), Rect2(r.position.x, r.position.y + step * i, r.size.x, step), 1, mod)
			return true
		var n2 := cells.size()
		for i in n2:
			var cl: Vector2i = cells[i]
			var d := Rect2(r.position.x + r.size.x / n2 * i, r.position.y, r.size.x / n2, r.size.y) if along_x \
				else Rect2(r.position.x, r.position.y + r.size.y / n2 * i, r.size.x, r.size.y / n2)
			blit(ci, INDOOR, cl.x, cl.y, d, 1, 1, mod)
		return true
	if DINER_TILES.has(type):
		var t: Array = DINER_TILES[type]
		if t[2] > t[3] and not along_x:
			blit_turned(ci, DINER, region(t[0], t[1], t[2], t[3]), r, 1, mod)
		else:
			_diner(ci, type, r, mod)
		return true
	return false


## A car, bus or van from the side, its middle at p, facing right (or left).
static func vehicle(ci: CanvasItem, name: String, p: Vector2, facing_right: bool, scale: float = 2.0) -> void:
	var t: Array = DINER_TILES[name]
	var sz := Vector2(t[2] * 16, t[3] * 16) * scale
	var dest := Rect2(p - sz / 2.0, sz)
	if facing_right:
		blit(ci, DINER, t[0], t[1], dest, t[2], t[3])
	else:
		blit_flipped(ci, DINER, region(t[0], t[1], t[2], t[3]), dest)


## The sprite nearest a paint colour.
static func car_for(col: Color) -> String:
	var best := "car_white"
	var d := INF
	var paints := {"car_red": Color("d24b3e"), "car_blue": Color("4a8fd0"), "car_yellow": Color("f2c14e"), "car_green": Color("4f9a6a"), "car_white": Color("e9e6df")}
	for k in paints:
		var c: Color = paints[k]
		var dd := Vector3(col.r - c.r, col.g - c.g, col.b - c.b).length()
		if dd < d:
			d = dd
			best = k
	return best


static func _diner(ci: CanvasItem, name: String, r: Rect2, mod: Color = Color.WHITE) -> void:
	var t: Array = DINER_TILES[name]
	blit(ci, DINER, t[0], t[1], r, t[2], t[3], mod)


# ------------------------------------------------------------------ floors

static var _tileset: TileSet
static var _floor_ids := {}          # floor name -> [source id, atlas coords]


## The tile set for the floor layer, built once from the sheets.
static func floor_tileset() -> TileSet:
	if _tileset != null:
		return _tileset
	_tileset = TileSet.new()
	_tileset.tile_size = Vector2i(16, 16)
	var sheets := [DINER, RPG, URBAN]
	var sources: Array = []
	for i in sheets.size():
		var src := TileSetAtlasSource.new()
		src.texture = sheets[i]
		src.texture_region_size = Vector2i(16, 16)
		src.separation = Vector2i(1, 1)
		_tileset.add_source(src, i)
		sources.append(src)
	var all := FLOORS.duplicate()
	for k in ["diner", "kitchen"]:
		var fd: Array = DINER_TILES["floor_" + k]
		all[k] = [0, fd[0], fd[1]]
	for k in all:
		var spec: Array = all[k]
		var at := Vector2i(spec[1], spec[2])
		var src: TileSetAtlasSource = sources[spec[0]]
		if not src.has_tile(at):
			src.create_tile(at)
		_floor_ids[k] = [spec[0], at]
	return _tileset


## [source id, atlas coords] for a floor name.
static func floor_id(name: String) -> Array:
	floor_tileset()
	return _floor_ids[name]


# ------------------------------------------------------------------ people

## The six walkers in the Urban sheet, three rows each (standing, two steps),
## four columns: facing left, down, up, right.
const PEOPLE_COL := 23
const DIR_COLS := {"left": 0, "down": 1, "up": 2, "right": 3}

## Which colours in each walker are skin, hair, shirt and trousers, so they can
## be swapped for someone's own. [hex, part, from row, to row].
const SKIN_RULES := [["ffc999", "skin", 0, 15], ["ffc8a1", "skin", 0, 15], ["f1b089", "skin_lo", 0, 15]]
const RECOLOR := {
	0: [["dc8652", "hair", 0, 12], ["c57652", "hair_lo", 0, 12], ["42a379", "shirt", 0, 15], ["369069", "shirt_lo", 0, 15],
		["d6d4aa", "pants", 0, 15], ["c5b993", "pants_lo", 0, 15]],
	1: [["dc8652", "hair", 0, 12], ["c57652", "hair_lo", 0, 12], ["c2504d", "shirt", 0, 15], ["a54240", "shirt_lo", 0, 15],
		["a09cca", "pants", 0, 15], ["7a77a4", "pants_lo", 0, 15]],
	2: [["dc8652", "shirt", 10, 13], ["c57652", "shirt_lo", 10, 13], ["42a379", "pants", 0, 15], ["369069", "pants_lo", 0, 15]],
	3: [],
	4: [["dc8652", "hair", 0, 9], ["dc8652", "shirt", 10, 12], ["c57652", "shirt_lo", 10, 13], ["60605a", "pants", 0, 15],
		["54544e", "pants_lo", 0, 15]],
	5: [["373733", "hair", 0, 11], ["50504a", "hair_lo", 0, 11], ["60605a", "hair_lo", 0, 9], ["ff7143", "accent", 0, 15],
		["c77b47", "shirt", 0, 15], ["a9673b", "shirt_lo", 0, 15], ["aaa8bd", "pants", 12, 15]],
}
const PANTS := [Color("3b4a66"), Color("5a4a3a"), Color("2e2e34"), Color("6b6f78"), Color("7a5a3a")]

static var _urban_img: Image
static var _people := {}


## Which walker someone is, from their hairstyle (see Art.style_for).
static func base_for(hair_style: int, hair: Color, staff: bool, look: String) -> int:
	if look == "driver":
		return 3
	if not staff and hair.is_equal_approx(Color("8c8c8c")):
		return 2
	match hair_style:
		1, 3:
			return 1
		2, 7:
			return 0
		5, 6:
			return 4
	return 5


## A 64x48 sheet (4 directions x 3 frames) of this person in their own colours,
## made once and kept.
static func person(skin: Color, hair: Color, shirt: Color, st: Dictionary, staff: bool, look: String) -> ImageTexture:
	var role := look.substr(5) if look.begins_with("role:") else ""
	var base := base_for(int(st.get("hair", 0)), hair, staff, look)
	var pants: Color = Color("2e2e34") if staff else PANTS[int(st.get("pattern", 0)) % PANTS.size()]
	var accent: Color = st.get("accent", Color("d23b30"))
	var key := "%d|%s|%s|%s|%s|%s|%s" % [base, skin.to_html(false), hair.to_html(false), shirt.to_html(false), pants.to_html(false), accent.to_html(false), role]
	if _people.has(key):
		return _people[key]
	if _urban_img == null:
		_urban_img = URBAN.get_image()
		if _urban_img.is_compressed():
			_urban_img.decompress()
		_urban_img.convert(Image.FORMAT_RGBA8)
	var to := {"skin": skin, "skin_lo": skin.darkened(0.14), "hair": hair, "hair_lo": hair.darkened(0.22),
		"shirt": shirt, "shirt_lo": shirt.darkened(0.2), "pants": pants, "pants_lo": pants.darkened(0.2), "accent": accent}
	var rules: Array = (SKIN_RULES if base != 3 else []) + RECOLOR[base]
	var img := Image.create(64, 48, false, Image.FORMAT_RGBA8)
	for d in 4:
		for fr in 3:
			var sx := (PEOPLE_COL + d) * 17
			var sy := (base * 3 + fr) * 17
			for y in 16:
				for x in 16:
					var c := _urban_img.get_pixel(sx + x, sy + y)
					if c.a <= 0.0:
						continue
					var hex := c.to_html(false)
					for rl in rules:
						if rl[0] == hex and y >= rl[2] and y <= rl[3]:
							c = to[rl[1]]
							break
					img.set_pixel(d * 16 + x, fr * 16 + y, c)
	_dress(img, role)
	var tex := ImageTexture.create_from_image(img)
	_people[key] = tex
	return tex


static var _portraits := {}


## Head and shoulders from the standing, facing-down frame, blown up 8x with
## hard edges so it stays crisp in the interface.
static func portrait(skin: Color, hair: Color, shirt: Color, st: Dictionary, staff: bool, look: String) -> ImageTexture:
	var tex := person(skin, hair, shirt, st, staff, look)
	if _portraits.has(tex):
		return _portraits[tex]
	var img := tex.get_image().get_region(Rect2i(16 + 1, 0, 14, 13))
	img.resize(14 * 8, 13 * 8, Image.INTERPOLATE_NEAREST)
	var out := ImageTexture.create_from_image(img)
	_portraits[tex] = out
	return out


## Work clothes on top: the cook's toque, a cap, the manager's tie, an apron.
static func _dress(img: Image, role: String) -> void:
	var white := Color("f6f2ea")
	var line := Color("8d5243")
	for d in 4:
		for fr in 3:
			var ox := d * 16
			var oy := fr * 16
			var top := _top_row(img, ox, oy)
			match role:
				"cook":
					for y in range(maxi(0, top - 3), top + 1):
						for x in range(5, 11):
							var edge := x == 5 or x == 10 or y == maxi(0, top - 3)
							img.set_pixel(ox + x, oy + y, line if edge else white)
				"busser", "porter":
					var cap := Color("2e2e34") if role == "busser" else Color("2f6db0")
					for y in range(top + 1, top + 3):
						for x in range(4, 12):
							if img.get_pixel(ox + x, oy + y).a > 0.0:
								img.set_pixel(ox + x, oy + y, cap)
				"manager":
					if d == 1:
						for y in range(10, 13):
							img.set_pixel(ox + 7, oy + y, Color("c8403a"))
							img.set_pixel(ox + 8, oy + y, Color("9a3129"))
				"server", "busser":
					if d == 1:
						for x in range(5, 11):
							if img.get_pixel(ox + x, oy + 12).a > 0.0:
								img.set_pixel(ox + x, oy + 12, white)


## The first row with anything in it: the top of their head.
static func _top_row(img: Image, ox: int, oy: int) -> int:
	for y in 16:
		for x in 16:
			if img.get_pixel(ox + x, oy + y).a > 0.0:
				return y
	return 0


## The column for someone facing this way.
static func dir_col(facing: Vector2) -> int:
	if absf(facing.x) > absf(facing.y):
		return DIR_COLS["right"] if facing.x > 0.0 else DIR_COLS["left"]
	return DIR_COLS["down"] if facing.y >= 0.0 else DIR_COLS["up"]
