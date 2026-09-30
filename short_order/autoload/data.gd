extends Node
## Every number you might want to tune lives here: dishes, ingredients,
## furniture, customers, staff and how they get along, costs and timings.
## Change a value, press play, see what happens.

const TILE := 32
const LOT_W := 40
const LOT_H := 30
const BUILD_MAX_Y := 25          # rows 0..25 can be built on
const SIDEWALK_Y := 27           # customers walk along this row
const MINUTE_SEC := 1.0          # real seconds per game minute at 1x speed
const OPEN_MIN := 10 * 60        # the diner opens at 10:00 (see GameState.open_min for today's hours)
const LAST_SEAT_MIN := 21 * 60 + 30
const CLOSE_MIN := 22 * 60       # no new customers after 22:00
const END_MIN := 24 * 60         # the day ends at midnight
const PLAN_MIN := 9 * 60         # the clock shows 09:00 while you plan
const PREP_MINUTES := 60         # staff come in this long before the doors open, to prep

const START_MONEY := 25000.0
## Suggestions for a new diner's name.
const DINER_NAMES := ["Rosie's Diner", "The Blue Plate", "Sunny Side Up", "Route 66 Grill", "The Busy Bee", "Moonlight Diner",
	"Starlite Diner", "The Short Stack", "Main Street Diner", "The Chrome Spoon", "Mel's Corner", "The Golden Griddle"]
const PLATE_COST := 6.0
const START_PLATES := 40
const PLATES_LOW := 6               # fewer clean plates than this and washing up comes first
const REFUND := 0.5              # share of the price you get back when removing
const REPAIR_COST := 30.0        # spare parts for fixing a broken station
const MAX_STAFF := 40            # a big diner with day and night crews

const WALK_TILES_PER_SEC := 5.5  # walking speed at 1x
const TABLE_PATIENCE := 20.0     # minutes a group waits for a table
const ORDER_PATIENCE := 25.0     # minutes a seated group waits to order
const FOOD_PATIENCE := 60.0      # minutes a group waits for its food
const REVIEW_WINDOW := 20        # rating = average of the last N reviews

const DIRT_SHOW := 0.05          # dirt below this is invisible
const DIRT_JOB := 0.15           # a tile this dirty gets a Sweep job during the day
## With someone on shift whose job is cleaning (a busser, a porter, or anyone
## with Clean first), every little spill gets swept right away and only a
## really dirty floor shows.
const DIRT_SHOW_CLEANER := 0.3

# staff energy, per game minute
const ENERGY_WORK := 0.11
const ENERGY_IDLE := 0.03
const BREAK_AT := 30.0           # below this, staff take a break after their current job
const BREAK_UNTIL := 90.0
const REST_SOFA := 2.2           # energy back per minute on a sofa
const REST_STANDING := 0.8       # ...and without one

# skills grow with practice: minutes of work needed for the next level
const XP_BASE := 60.0
const XP_PER_LEVEL := 20.0

# Stations wear out slowly and now and then break (then someone with Repair
# fixes them). A busy station reaches full wear in about two weeks; worn
# equipment is much likelier to break. At closing, someone on Repair services
# anything past SERVICE_AT, so a looked-after kitchen rarely breaks down.
const WEAR_PER_COOK := Vector2(0.0005, 0.0015)
const BREAK_CHANCE := 0.001      # times wear squared, rolled after every batch
const SERVICE_AT := 0.4          # closers service stations this worn...
const SERVICE_COST := 12.0       # ...for a few dollars of parts
const SERVICE_MINUTES := 3.0

const JOBS := ["cook", "serve", "host", "wash", "clean", "fix"]
const JOB_NAMES := {"cook": "Cook", "serve": "Serve", "host": "Host", "wash": "Wash", "clean": "Clean", "fix": "Repair"}
const JOB_DESC := {
	"cook": "Fetch ingredients, prep and cook orders at the stations.",
	"serve": "Take orders, bring food to tables, hand out takeout and take payment.",
	"host": "Greet customers at the host stand, keep a waitlist and ring up bills at the till.",
	"wash": "Wash dirty plates at the sink.",
	"clean": "Clear tables and sweep dirty floors.",
	"fix": "Repair broken kitchen equipment.",
}

## The parts of the day you can open for (Office page). They have to join up:
## open for breakfast and dinner and you're open for lunch too.
const SERVICES := [
	{"key": "breakfast", "name": "Breakfast", "from": 7 * 60, "to": 10 * 60},
	{"key": "lunch",     "name": "Lunch",     "from": 10 * 60, "to": 16 * 60},
	{"key": "dinner",    "name": "Dinner",    "from": 16 * 60, "to": 22 * 60},
]
## Dishes people pick more at breakfast time.
const BREAKFAST_LIKES := ["pancakes", "omelette", "coffee"]

## Busy and quiet parts of the day. mult changes how many customers arrive.
const RUSHES := [
	{"from": 8 * 60, "to": 9 * 60 + 30, "mult": 1.3, "name": "Breakfast rush"},
	{"from": 12 * 60, "to": 14 * 60, "mult": 1.5, "name": "Lunch rush"},
	{"from": 15 * 60, "to": 17 * 60, "mult": 0.6, "name": "Quiet afternoon"},
	{"from": 18 * 60, "to": 20 * 60, "mult": 1.45, "name": "Dinner rush"},
]
## A new diner isn't known yet: fewer customers on days 1, 2 and 3.
const NEW_DINER_RAMP := [0.7, 0.85, 0.95]

## kind: what part of a meal it is (main, side, drink, dessert).
## prep: can be prepped in the morning (chopped, portioned, mixed) to cook faster later.
const DISHES := {
	"burger":    {"name": "Burger",    "station": "grill",   "minutes": 5.0, "needs": {"meat": 1, "bread": 1, "veg": 1}, "price": 16.0, "plate": true,  "kind": "main", "prep": true},
	"pancakes":  {"name": "Pancakes",  "station": "griddle", "minutes": 4.0, "needs": {"dairy": 1, "bread": 1}, "price": 12.0,  "plate": true,  "kind": "main", "prep": true},
	"omelette":  {"name": "Omelette",  "station": "griddle", "minutes": 4.0, "needs": {"eggs": 1, "dairy": 1},  "price": 13.0,  "plate": true,  "kind": "main", "prep": true},
	"meatloaf":  {"name": "Meatloaf",  "station": "oven",    "minutes": 7.0, "needs": {"meat": 1, "bread": 1},  "price": 18.0, "plate": true,  "kind": "main", "prep": true},
	"fries":     {"name": "Fries",     "station": "fryer",   "minutes": 3.0, "needs": {"potatoes": 1},          "price": 6.0,  "plate": true,  "kind": "side", "prep": true},
	"pie":       {"name": "Apple pie", "station": "oven",    "minutes": 5.0, "needs": {"fruit": 1, "bread": 1}, "price": 7.0,  "plate": true,  "kind": "dessert", "prep": true},
	"milkshake": {"name": "Milkshake", "station": "drinks",  "minutes": 2.0, "needs": {"icecream": 1, "dairy": 1}, "price": 8.0, "plate": false, "kind": "drink", "prep": false},
	"coffee":    {"name": "Coffee",    "station": "drinks",  "minutes": 1.0, "needs": {},                       "price": 3.5,  "plate": false, "kind": "drink", "prep": false},
	## ice: needs an ice machine. The cook scoops the ice on the way to the drinks machine.
	"soda":      {"name": "Soda",      "station": "drinks",  "minutes": 0.8, "needs": {},                       "price": 3.5,  "plate": false, "kind": "drink", "prep": false, "ice": true},
	"icedtea":   {"name": "Iced tea",  "station": "drinks",  "minutes": 0.8, "needs": {},                       "price": 3.5,  "plate": false, "kind": "drink", "prep": false, "ice": true},
}
const DISH_ORDER := ["burger", "pancakes", "omelette", "meatloaf", "fries", "pie", "milkshake", "coffee", "soda", "icedtea"]
const SPECIAL_PICKS := 3          # customers pick today's special this many times as often
const SPECIAL_REVIEW := 0.2       # and like getting it this much

## store: where it's kept (fridge, freezer or the dry shelves). life: days it
## lasts from delivery; it's thrown out the night it goes off.
const INGREDIENTS := {
	"meat":     {"name": "Meat",         "cost": 2.8, "store": "fridge",  "life": 3},
	"veg":      {"name": "Salad veg",    "cost": 0.5, "store": "fridge",  "life": 2},
	"dairy":    {"name": "Dairy",        "cost": 1.0, "store": "fridge",  "life": 4},
	"eggs":     {"name": "Eggs",         "cost": 0.6, "store": "fridge",  "life": 10},
	"fruit":    {"name": "Fruit",        "cost": 1.0, "store": "fridge",  "life": 2},
	"bread":    {"name": "Bread",        "cost": 0.6, "store": "dry",     "life": 5},
	"potatoes": {"name": "Frozen fries", "cost": 0.5, "store": "freezer", "life": 30},
	"icecream": {"name": "Ice cream",    "cost": 0.8, "store": "freezer", "life": 30},
}
const ING_ORDER := ["meat", "veg", "dairy", "eggs", "fruit", "bread", "potatoes", "icecream"]
## About a first day's worth. The chilled part fits in one fridge, the frozen part in its freezer box.
const START_STOCK := {"meat": 45, "veg": 25, "dairy": 75, "eggs": 40, "fruit": 35, "bread": 90, "potatoes": 32, "icecream": 18}
const STORE_NAMES := {"fridge": "Fridge", "freezer": "Freezer", "dry": "Dry shelves"}
## How much each piece of storage holds: a fridge has a small freezer box too.
const STORAGE := {"fridge": {"fridge": 240, "freezer": 50}, "freezer": {"freezer": 200}}

## The morning: prep, the staff meal and the delivery.
const PREP_SPEED := 0.6           # a prepped dish cooks in 60% of the time (40% faster)
const PREP_MINUTES_EACH := 0.45   # minutes of prep work per portion, for an average cook
const PREP_BATCH := 6             # portions per prep job
const START_PREP := {"burger": 6, "pancakes": 4, "omelette": 3, "meatloaf": 4, "fries": 6, "pie": 3}
const STAFF_MEAL_COST := 4.0      # food per person
const STAFF_MEAL_MINUTES := 12.0
const STAFF_MEAL_STRESS := -8.0
const DELIVERY_LATE := 0.12       # chance the delivery comes after opening
const DELIVERY_SHORT := 0.1       # chance one ingredient comes up short

## Where the ingredients come from. cost multiplies the delivery bill;
## quality changes how good the food is (and so the reviews).
const SUPPLIERS := {
	"budget":   {"name": "Budget",     "cost": 0.75, "quality": -0.08, "desc": "Cheap and a bit sad. Food comes out worse."},
	"standard": {"name": "Standard",   "cost": 1.0,  "quality": 0.0,   "desc": "Decent ingredients at a fair price."},
	"fresh":    {"name": "Farm fresh", "cost": 1.5,  "quality": 0.1,   "desc": "Costs more and tastes better. Customers notice."},
}
const SUPPLIER_ORDER := ["budget", "standard", "fresh"]

## Tips, as a share of the bill: about 15% for an okay visit, up to 20% for
## a great one, less for a bad one and nothing for a terrible one.
const TIP_BASE := 0.15            # at 3 stars
const TIP_PER_STAR := 0.025       # more per star above 3 (20% at 5 stars)
const TIP_LOW_PER_STAR := 0.075   # less per star below 3 (7.5% at 2 stars, none at 1)
## The table's own server (who took the order) gets this share of the tip; the
## rest is split between everyone who ran food to the table.
const TIP_SERVER_SHARE := 0.75
## Prices above the usual ones keep people away; cheaper ones draw a crowd.
const PRICE_DEMAND := 0.5         # each 10% above usual prices costs 5% of customers
const PRICE_DEMAND_RANGE := Vector2(0.7, 1.15)

## Floor types stored in the lot grid.
const FLOOR_NONE := 0
const FLOOR_DINER := 1
const FLOOR_KITCHEN := 2
const FLOOR_STAFF := 3
const FLOOR_RESTROOM := 4

## Things you build by dragging or clicking on the grid (not furniture).
const BUILD := {
	"floor_diner":   {"name": "Diner floor",      "cost": 8,   "floor": FLOOR_DINER,   "desc": "Checkered tiles for the dining room. Drag a box."},
	"floor_kitchen": {"name": "Kitchen floor",    "cost": 8,   "floor": FLOOR_KITCHEN, "desc": "Grey tiles for the kitchen. Customers stay out. Drag a box."},
	"floor_staff":   {"name": "Staff room floor", "cost": 8,   "floor": FLOOR_STAFF,   "desc": "Wooden floor for a break room. Customers stay out. Drag a box."},
	"floor_restroom": {"name": "Restroom floor",  "cost": 8,  "floor": FLOOR_RESTROOM, "desc": "Blue tiles for a restroom. Customers can come in here. Drag a box, then wall it in and add a door."},
	"wall":          {"name": "Walls",            "cost": 15,  "desc": "Drag a box to wall in a room."},
	"door":          {"name": "Door",             "cost": 120, "desc": "Click a wall to put a door in it."},
	"land":          {"name": "Buy land",         "cost": 0,   "desc": "Click a plot marked For sale to buy it. Then you can build there."},
}

## The land. You start with one plot and can buy the others to grow.
## rent: what that plot adds to the weekly rent and property tax.
const PLOTS := [
	{"id": "start", "name": "Your lot",  "rect": Rect2i(6, 10, 22, 16),  "cost": 0,     "rent": 350},
	{"id": "west",  "name": "West lot",  "rect": Rect2i(0, 10, 6, 16),   "cost": 4000,  "rent": 60},
	{"id": "east",  "name": "East lot",  "rect": Rect2i(28, 10, 12, 16), "cost": 8000,  "rent": 120},
	{"id": "back",  "name": "Back lot",  "rect": Rect2i(0, 0, 40, 10),   "cost": 12000, "rent": 180},
]

# ------------------------------------------------------------------ the books
## Bills come once a week, on the night of day 7, 14, 21...
const BILL_EVERY := 7
## Gas, power and water per week for each thing that uses them, plus the lights.
const UTILITIES := {"grill": 25, "fryer": 25, "griddle": 25, "oven": 25, "drinks": 15, "fridge": 20, "freezer": 20,
	"sink": 8, "ice": 15, "jukebox": 6, "neon": 5, "lamp": 2}
const UTILITIES_BASE := 40
## Bank loans: borrow now, pay back a little with every week's bills. Bigger
## loans run longer. interest: the total added on top, spread over the weeks.
const LOANS := [
	{"amount": 5000,   "weeks": 10,  "interest": 0.10},
	{"amount": 10000,  "weeks": 10,  "interest": 0.12},
	{"amount": 25000,  "weeks": 26,  "interest": 0.14},
	{"amount": 50000,  "weeks": 52,  "interest": 0.16},
	{"amount": 100000, "weeks": 104, "interest": 0.20},
	{"amount": 250000, "weeks": 156, "interest": 0.26},
]
## What owners aim for, as a share of sales.
const TARGET_FOOD_COST := 0.30
const TARGET_STAFF_COST := 0.40   # California wages: 35-45% of sales is normal for a sit-down diner
## Tips go to the staff. Good tips cheer people up; seeing others get them doesn't.
const TIP_STRESS := 25.0          # stress off for tips worth a whole day's wage
const TIP_STRESS_MAX := 12.0

## Reputation grows as you serve people well: more customers, and new kinds.
const REP_LEVELS := [
	{"name": "Roadside diner",    "served": 0,    "rating": 0.0, "mult": 1.0},
	{"name": "Local spot",        "served": 100,  "rating": 3.5, "mult": 1.1},
	{"name": "Town favourite",    "served": 300,  "rating": 3.8, "mult": 1.2},
	{"name": "Destination diner", "served": 700,  "rating": 4.1, "mult": 1.35},
	{"name": "Famous",            "served": 1500, "rating": 4.4, "mult": 1.5},
]

## size is [width, height] in tiles before rotating. "solid" blocks walking.
## floor: which floor it must stand on ("any", "diner", "kitchen", "staff", "inside" = diner or
## kitchen, or "wall" = hangs on a wall tile). beauty/radius: how much it cheers up nearby tables.
const FURNITURE := {
	"table":    {"name": "Table",          "size": [2, 1], "cost": 150, "solid": true,  "cat": "dining",  "floor": "diner",   "seats": 4, "desc": "Seats up to 4. Put chairs next to it."},
	"table_small": {"name": "Single table", "size": [1, 1], "cost": 90, "solid": true, "cat": "dining",  "floor": "diner",   "seats": 1, "desc": "A small table for one, with a chair beside it. Solo diners (truckers, regulars, critics) sit here and leave the big tables for groups."},
	"chair":    {"name": "Chair",          "size": [1, 1], "cost": 45,  "solid": false, "cat": "dining",  "floor": "diner",   "desc": "Place beside a table. It turns to face the table; press R to turn it yourself."},
	"grill":    {"name": "Grill",          "size": [2, 1], "cost": 900, "solid": true,  "cat": "kitchen", "floor": "kitchen", "desc": "Cooks burgers."},
	"fryer":    {"name": "Fryer",          "size": [1, 1], "cost": 650, "solid": true,  "cat": "kitchen", "floor": "kitchen", "desc": "Cooks fries."},
	"griddle":  {"name": "Griddle",        "size": [2, 1], "cost": 600, "solid": true,  "cat": "kitchen", "floor": "kitchen", "desc": "Cooks pancakes and omelettes."},
	"drinks":   {"name": "Drinks machine", "size": [1, 1], "cost": 500, "solid": true,  "cat": "kitchen", "floor": "inside",  "desc": "Coffee, milkshakes and sodas. Servers pour the drinks and take them straight to the table, so it can go in the dining room as well as the kitchen."},
	"oven":     {"name": "Oven",           "size": [1, 1], "cost": 700, "solid": true,  "cat": "kitchen", "floor": "kitchen", "desc": "Bakes meatloaf and apple pie."},
	"pass":     {"name": "Pass counter",   "size": [2, 1], "cost": 180, "solid": true,  "cat": "kitchen", "floor": "wall",    "desc": "A hatch in the wall between the kitchen and the dining room. Cooks put finished food on it from the kitchen side and servers pick it up from the dining side. Holds 8."},
	"fridge":   {"name": "Fridge",         "size": [1, 1], "cost": 450, "solid": true,  "cat": "kitchen", "floor": "kitchen", "desc": "Cooks fetch ingredients here. Holds 240 portions of chilled food, plus a little freezer box (50)."},
	"freezer":  {"name": "Freezer",        "size": [1, 1], "cost": 500, "solid": true,  "cat": "kitchen", "floor": "kitchen", "desc": "Holds 200 portions of frozen food (fries and ice cream). Frozen food lasts a month."},
	"prep":     {"name": "Prep counter",   "size": [2, 1], "cost": 350, "solid": true,  "cat": "kitchen", "floor": "kitchen", "desc": "Before opening, cooks chop, mix and portion here. Prepped dishes cook 40% faster. Leftover prep is thrown out at night."},
	"ice":      {"name": "Ice machine",    "size": [1, 1], "cost": 1200, "solid": true, "cat": "kitchen", "floor": "kitchen", "desc": "Makes ice for sodas and iced tea. Without one, cold drinks are off the menu. Press R to turn it."},
	"sink":     {"name": "Sink",           "size": [1, 1], "cost": 300, "solid": true,  "cat": "kitchen", "floor": "kitchen", "desc": "Dirty plates are washed here."},
	"plant":    {"name": "Potted plant",   "size": [1, 1], "cost": 60,  "solid": true,  "cat": "decor",   "floor": "any",     "beauty": 1, "radius": 3, "desc": "Cheers up tables nearby."},
	"lamp":     {"name": "Floor lamp",     "size": [1, 1], "cost": 90,  "solid": true,  "cat": "decor",   "floor": "any",     "beauty": 1, "radius": 3, "glow": true, "desc": "Cheers up tables nearby and glows in the evening."},
	"wall_art": {"name": "Framed picture", "size": [1, 1], "cost": 120, "solid": true,  "cat": "decor",   "floor": "wall",    "beauty": 1, "radius": 4, "desc": "Hangs on a wall. Cheers up tables nearby."},
	"neon":     {"name": "Neon sign",      "size": [1, 1], "cost": 400, "solid": true,  "cat": "decor",   "floor": "wall",    "beauty": 2, "radius": 6, "glow": true, "desc": "Hangs on a wall and glows. Customers love it."},
	"jukebox":  {"name": "Jukebox",        "size": [1, 1], "cost": 700, "solid": true,  "cat": "decor",   "floor": "diner",   "beauty": 2, "radius": 7, "music": true, "desc": "Plays tunes while you're open. Tables nearby enjoy the music."},
	"sofa":     {"name": "Sofa",           "size": [2, 1], "cost": 250, "solid": false, "cat": "staff",   "floor": "staff",   "desc": "Tired staff rest here much faster than standing around. Goes in the staff room."},
	"toilet":   {"name": "Toilet",         "size": [1, 1], "cost": 450, "solid": false, "cat": "restroom", "floor": "restroom", "desc": "Customers use it during their visit, and staff on their breaks. It gets dirty: someone with Clean on scrubs it. The inspector checks."},
	"handsink": {"name": "Hand sink",      "size": [1, 1], "cost": 150, "solid": true,  "cat": "restroom", "floor": "wash",    "desc": "Staff wash their hands here after the restroom or the trash. Goes in a restroom or the kitchen. Skipping it costs inspection points."},
	"bin":      {"name": "Trash can",      "size": [1, 1], "cost": 60,  "solid": true,  "cat": "kitchen", "floor": "kitchen", "desc": "Kitchen scraps go in here. Someone with Clean on takes it out when it's full. Overflowing bins attract mice."},
	"trap":     {"name": "Mouse trap",     "size": [1, 1], "cost": 40,  "solid": false, "cat": "kitchen", "floor": "inside",  "desc": "Catches mice that come near, and each one (up to 3) makes mice less likely to move in."},
	"dumpster": {"name": "Dumpster",       "size": [2, 1], "cost": 400, "solid": true,  "cat": "structure", "floor": "outside", "desc": "Goes outside, ideally by a back door. Without one, trash goes out through the front door, past your customers."},
	"takeout":  {"name": "Takeout window", "size": [1, 1], "cost": 800, "solid": true,  "cat": "structure", "floor": "wall",  "desc": "Put it in an outside wall. Takeout customers and delivery drivers pick up here without needing a table."},
	"host":     {"name": "Host stand",     "size": [1, 1], "cost": 250, "solid": true,  "cat": "dining",  "floor": "diner",   "desc": "Put it by the front door. Someone with Host on greets customers, keeps a waitlist and takes bookings. Greeted customers wait longer."},
	"till":     {"name": "Till",           "size": [1, 1], "cost": 300, "solid": true,  "cat": "dining",  "floor": "diner",   "desc": "Customers pay here on the way out, and their table frees up sooner. Someone with Host or Serve on rings them up."},
}
const STATIONS := ["grill", "fryer", "griddle", "drinks", "oven"]
## Stations can be upgraded to Pro: faster cooking and half the wear.
const UPGRADE_COST := 0.6         # share of the station's price
const PRO_SPEED := 1.25
const PRO_WEAR := 0.5
const PASS_SLOTS := 8
const BATCH_EXTRA := 0.25       # each extra item cooked together adds 25% cooking time
const BATCH_MAX := 4            # a cook at a station takes other tables' orders too, up to this many items
const QUEUE_LIMIT := 2          # if this many groups already wait at the door, new ones walk past
const MAX_BEAUTY := 4           # beauty above this doesn't help any more

## The build menu, one list per category, left to right.
const BUILD_MENU := [
	{"key": "structure", "name": "Structure", "icon": "structure", "items": ["land", "floor_diner", "floor_kitchen", "wall", "door", "takeout", "dumpster"]},
	{"key": "dining",    "name": "Dining",    "icon": "dining",    "items": ["table", "table_small", "chair", "host", "till"]},
	{"key": "kitchen",   "name": "Kitchen",   "icon": "kitchen",   "items": ["grill", "fryer", "griddle", "drinks", "oven", "ice", "pass", "prep", "fridge", "freezer", "sink", "bin", "trap"]},
	{"key": "restroom",  "name": "Restroom",  "icon": "restroom",  "items": ["floor_restroom", "toilet", "handsink"]},
	{"key": "decor",     "name": "Decor",     "icon": "decor",     "items": ["plant", "lamp", "wall_art", "neon", "jukebox"]},
	{"key": "staff",     "name": "Staff room", "icon": "staff_room", "items": ["floor_staff", "sofa"]},
]

## Who comes to eat. weight = how common, hours = when they come,
## patience/price/tip are multipliers, likes = dishes they order more often,
## order = chance each person orders [a main, a side, a drink, a dessert].
## min_level: only comes once the diner's reputation reaches this level.
const CUSTOMERS := {
	"regular": {"name": "Locals",      "weight": 50.0, "size": [1, 4], "hours": [7, 22], "patience": 1.0,  "price": 1.0, "tip": 1.0, "likes": ["omelette"], "look": "", "order": [0.85, 0.4, 0.65, 0.25]},
	"student": {"name": "Students",    "weight": 18.0, "size": [2, 4], "hours": [13, 22], "patience": 1.15, "price": 2.0, "tip": 0.5, "likes": ["fries", "milkshake"], "look": "backpack", "order": [0.6, 0.7, 0.75, 0.3]},
	"family":  {"name": "A family",    "weight": 14.0, "size": [2, 4], "hours": [8, 20], "patience": 0.85, "price": 1.2, "tip": 1.1, "likes": ["pancakes", "milkshake", "pie"], "look": "family", "order": [0.8, 0.35, 0.8, 0.55]},
	"trucker": {"name": "A trucker",   "weight": 12.0, "size": [1, 1], "hours": [6, 22], "patience": 0.75, "price": 0.6, "tip": 1.6, "likes": ["burger", "meatloaf", "fries", "coffee"], "look": "cap", "order": [1.0, 0.8, 0.8, 0.45]},
	"tourist": {"name": "Tourists",    "weight": 10.0, "size": [2, 4], "hours": [9, 20], "patience": 0.9,  "price": 0.7, "tip": 1.3, "likes": ["pancakes", "meatloaf", "pie", "milkshake"], "look": "camera", "order": [0.9, 0.5, 0.8, 0.5], "min_level": 2},
	"critic":  {"name": "A food critic", "weight": 0.0, "size": [1, 1], "hours": [11, 20], "patience": 0.9, "price": 1.5, "tip": 1.0, "likes": [], "look": "beret", "order": [1.0, 0.5, 1.0, 0.8], "review_weight": 5, "picky": 2.0},
	"celebrity": {"name": "A celebrity", "weight": 0.0, "size": [1, 2], "hours": [10, 22], "patience": 0.8, "price": 0.5, "tip": 2.5, "likes": ["meatloaf", "pie"], "look": "shades", "order": [1.0, 0.5, 1.0, 0.8], "review_weight": 3, "picky": 1.3},
	"takeout": {"name": "Takeout",     "weight": 0.0,  "size": [1, 1], "hours": [7, 22], "patience": 0.8,  "price": 1.0, "tip": 0.6, "likes": [], "look": "", "order": [1.0, 0.5, 0.5, 0.2]},
	"driver":  {"name": "App delivery", "weight": 0.0, "size": [1, 1], "hours": [6, 23], "patience": 0.8,  "price": 1.0, "tip": 0.0, "likes": [], "look": "driver", "order": [1.0, 0.6, 0.6, 0.3]},
	"inspector": {"name": "The health inspector", "weight": 0.0, "size": [1, 1], "hours": [11, 20], "patience": 1.0, "price": 1.0, "tip": 0.0, "likes": [], "look": "coat", "order": [0.0, 0.0, 0.0, 0.0]},
}
# ------------------------------------------------------------------ the front of house
const GREET_PATIENCE := 1.6       # greeted customers wait this much longer for a table
const GREET_REVIEW := 0.15
const QUEUE_LIMIT_HOST := 4       # with a host keeping a waitlist, people wait instead of walking past
## Bookings: taken by the host stand, a table is held for them.
const BOOKINGS_PER_DAY := Vector2i(1, 3)
const BOOKING_HOLD := 20.0        # minutes before the time the table is held
const BOOKING_NO_SHOW := 0.12
const BOOKING_REVIEW := 0.25      # sat straight down at their table
const BOOKING_NAMES := ["Kowalski", "Nguyen", "Okafor", "Martinez", "Byrne", "Haddad", "Patel", "Svensson", "Moreau", "Tanaka",
	"Delgado", "Brennan", "Schultz", "Adeyemi", "Russo", "Lindqvist", "O'Hara", "Castillo", "Weiss", "Abernathy"]
## Paying: at the till if there is one, otherwise at the table.
const PAY_SLOW := 6.0             # minutes waiting to pay before it starts to annoy
const CASH_ON_TABLE := 0.35       # with a till, chance a table leaves the money on the table instead
const CASH_KIND := {"regular": 1.3, "trucker": 1.5, "student": 0.6, "tourist": 0.6, "family": 1.0}
const PAY_GIVE_UP := 12.0         # after this they leave the money on the table
const DASH_CHANCE := 0.012        # per minute nobody's watching a table that wants to pay
const DASH_KIND := {"student": 2.5, "regular": 1.0, "family": 0.3, "trucker": 0.6, "tourist": 0.5}
const DASH_WATCH_TILES := 6.0
## Complaints: an unhappy table asks for the manager.
const COMPLAINT_BELOW := 2.6
const COMPLAINT_CHANCE := 0.5
const COMPLAINT_WAIT := 8.0
const FOOD_COMPLAINTS := ["the food", "slow food", "cold food", "a wrong order", "missing items", "their first choice was sold out", "their usual wasn't on"]
## Delivery apps: orders come in over the app and a driver picks them up.
const APP_SHARE := 0.25           # the app keeps a quarter of the bill
const APP_PER_HOUR := 0.7
## Regulars: named locals who come back.
const REGULAR_START := 4          # regulars you have on day 1
const REGULAR_NEW_CHANCE := 0.35  # chance a night that a new regular starts coming (up to 4 + 2 per reputation level)
const REGULAR_LOYAL := 80.0       # this loyal and they tip more and bring friends
const REGULARS := [
	{"name": "Dolores", "blurb": "Retired schoolteacher. Reads the paper cover to cover.", "usual": ["pancakes", "coffee"], "hours": [7, 11], "party": 1, "every": 2},
	{"name": "Big Jim", "blurb": "Drives the gravel truck. Always hungry.", "usual": ["burger", "coffee"], "hours": [11, 14], "party": 1, "every": 1},
	{"name": "Deputy Ray", "blurb": "The sheriff's deputy. Sits facing the door.", "usual": ["omelette", "coffee"], "hours": [9, 12], "party": 1, "every": 2},
	{"name": "The Hendersons", "blurb": "Twins, and their mum who never gets a moment.", "usual": ["pancakes", "milkshake"], "hours": [12, 18], "party": 3, "every": 3},
	{"name": "Walt", "blurb": "Fixes watches down the street. Knows everyone's business.", "usual": ["meatloaf", "coffee"], "hours": [17, 20], "party": 1, "every": 2},
	{"name": "Priya and Sam", "blurb": "Newlyweds. Friday is their date night.", "usual": ["meatloaf", "pie"], "hours": [18, 21], "party": 2, "every": 3},
	{"name": "Coach Barnes", "blurb": "Runs the high school team. Loud, kind, always late.", "usual": ["burger", "fries"], "hours": [15, 19], "party": 1, "every": 2},
	{"name": "Mrs. Albright", "blurb": "Ninety-one. Has had the same pie for thirty years.", "usual": ["pie", "coffee"], "hours": [14, 17], "party": 1, "every": 2},
	{"name": "Luis", "blurb": "Night-shift nurse, just off work. Too tired to talk.", "usual": ["omelette", "coffee"], "hours": [7, 10], "party": 1, "every": 1},
	{"name": "The book club", "blurb": "Four friends who never talk about the book.", "usual": ["pie", "coffee"], "hours": [14, 17], "party": 4, "every": 4},
	{"name": "Tammy", "blurb": "Runs the salon next door. Brings the gossip.", "usual": ["omelette", "milkshake"], "hours": [12, 15], "party": 1, "every": 2},
	{"name": "Father Tom", "blurb": "The parish priest. Tips like a sinner.", "usual": ["meatloaf", "coffee"], "hours": [12, 14], "party": 1, "every": 3},
	{"name": "Hank", "blurb": "Farmer. Says the fries were better in 1987.", "usual": ["burger", "fries"], "hours": [11, 14], "party": 1, "every": 2},
	{"name": "The night crew", "blurb": "Three workers from the plant, after their shift.", "usual": ["burger", "fries"], "hours": [20, 22], "party": 3, "every": 2},
	{"name": "June", "blurb": "Writes a novel at the corner table. Very slowly.", "usual": ["coffee", "pie"], "hours": [10, 16], "party": 1, "every": 1},
	{"name": "Mayor Pruitt", "blurb": "Shakes every hand in the room. Expects the best table.", "usual": ["meatloaf", "milkshake"], "hours": [12, 14], "party": 2, "every": 4},
]
const REGULAR_LINES := {
	"great": ["{r} got their usual from {s}, just how they like it.", "{r} told {s} this place is the best in town.", "{r} left {s} a note on a napkin: \"Perfect, as always.\""],
	"bad": ["{r} left unhappy. That's not like them.", "{r} grumbled on the way out and didn't say goodbye.", "{r} pushed the plate away half-eaten."],
	"gone": ["{r} hasn't been back. Too many bad visits.", "Someone says {r} goes to the place across town now."],
	"new": ["A new face: {r} ({b}) has started coming in.", "{r} ({b}) came in once and liked it. They'll be back."],
}

# ------------------------------------------------------------------ kitchen trouble
## Wrong orders: a tired, stressed or green server writes the wrong dish down.
const WRONG_BASE := 0.015
const WRONG_PER_SKILL := 0.005    # more for each service point under 10
const WRONG_STRESSED := 0.04      # stress 60 or more
const WRONG_TIRED := 0.03         # energy under 30
const WRONG_REVIEW := 0.35
## Allergies: some customers can't eat dairy, eggs or gluten. The server has to
## flag it on the ticket; if it's missed, the kitchen can easily slip up.
const ALLERGY_CHANCE := 0.06
const ALLERGENS := {"dairy": "dairy", "eggs": "eggs", "bread": "gluten"}
const ALLERGY_MISS := 0.05        # chance a server forgets to flag it (more when green or stressed)
const ALLERGY_RISK_FLAGGED := 0.01  # plus kitchen dirt: flagged, but it still happens
const ALLERGY_RISK_MISSED := 0.25
## Food waiting on the pass gets cold.
const PASS_HOT := 4.0             # minutes it stays hot
const PASS_COLD := 10.0           # after this, customers notice
const PASS_COOL_PER_MIN := 0.04   # quality lost per minute after it's no longer hot
const SOLD_OUT_REVIEW := 0.15     # their first choice was sold out

# ------------------------------------------------------------------ health and cleanliness
## Restrooms: some customers use one during their visit.
const RESTROOM_CHANCE := 0.35     # chance a group sends someone
const TOILET_MINUTES := 2.0
const TOILET_GRIME := Vector2(0.05, 0.1)   # how much dirtier each visit makes it
const TOILET_SCRUB_AT := 0.35     # a scrub job is posted at this much grime
const RESTROOM_DIRTY := 0.5       # customers notice above this
const NO_RESTROOM := 0.2          # stars off when someone needs one and there isn't one
## Trash: every order and prep job makes some. Bins are taken out at this full.
const TRASH_PER_ITEM := 0.02
const TRASH_PER_PREP := 0.012
const TRASH_PER_PLATE := 0.01
const BIN_EMPTY_AT := 0.7
const TRASH_PAST_TABLES := 0.2    # stars off for a table that sees trash carried past
## Mice: dirt, overflowing bins and food left out bring them in; traps help.
const MOUSE_MINUTES := Vector2(8.0, 16.0)
const MOUSE_SEEN_TILES := 4.0
const MOUSE_LEAVE := 0.6          # chance a table that sees one walks out (if they haven't eaten yet)
const MOUSE_REVIEW := 1.0
## Hand-washing: after the restroom or the trash, staff should wash their hands.
const HANDWASH_SKIP := 0.12       # chance they don't bother (more when fed up or in a rush; Tidy people never skip)
const HANDWASH_MINUTES := 0.3

# ------------------------------------------------------------------ roles and pay
## Everyone is hired for a role. The role sets their hourly pay and what they
## do first (their job priorities, which you can still change by hand), and the
## schedule puts the right mix of roles on every shift.
## pay: the hourly range in California, from a beginner to someone with 10 in
## the role's skill ("cooking", "service" or "both"). tipped: gets tips from tables.
const ROLES := {
	"cook":       {"name": "Line cook",  "plural": "Line cooks",  "icon": "cook",  "pay": [19.00, 26.00], "skill": "cooking",
		"priorities": {"cook": 1, "fix": 2, "wash": 3, "clean": 4, "serve": 0, "host": 0},
		"desc": "Cooks the orders, preps in the morning and restocks the stations at night."},
	"server":     {"name": "Server",     "plural": "Servers",     "icon": "serve", "pay": [16.90, 18.50], "skill": "service", "tipped": true,
		"priorities": {"serve": 1, "host": 2, "clean": 3, "cook": 0, "wash": 0, "fix": 0},
		"desc": "Takes orders, runs food, brings checks and keeps their tables' tips."},
	"host":       {"name": "Host",       "plural": "Hosts",       "icon": "host",  "pay": [17.00, 19.50], "skill": "service", "tipped": true,
		"priorities": {"host": 1, "serve": 2, "clean": 3, "cook": 0, "wash": 0, "fix": 0},
		"desc": "Greets people at the host stand, keeps the waitlist and bookings, and rings up the till."},
	"busser":     {"name": "Busser",     "plural": "Bussers",     "icon": "clean", "pay": [16.90, 18.00], "skill": "service",
		"priorities": {"clean": 1, "wash": 2, "serve": 3, "cook": 0, "host": 0, "fix": 0},
		"desc": "Clears and wipes tables, sweeps the dining room and picks up money left on tables."},
	"dishwasher": {"name": "Dishwasher", "plural": "Dishwashers", "icon": "wash",  "pay": [16.90, 18.50], "skill": "both",
		"priorities": {"wash": 1, "clean": 2, "fix": 3, "cook": 0, "serve": 0, "host": 0},
		"desc": "Keeps the plates coming: washes up, and takes out the trash."},
	"porter":     {"name": "Porter",     "plural": "Porters",     "icon": "fix",   "pay": [17.50, 21.00], "skill": "both",
		"priorities": {"fix": 1, "clean": 1, "wash": 3, "cook": 0, "serve": 0, "host": 0},
		"desc": "Keeps the place clean and running: floors, restrooms, trash, repairs and servicing the equipment."},
	"manager":    {"name": "Manager",    "plural": "Managers",    "icon": "star",  "pay": [26.00, 36.00], "skill": "both",
		"priorities": {"serve": 2, "host": 2, "fix": 2, "cook": 3, "clean": 4, "wash": 4},
		"desc": "Runs the shift: writes the schedule, handles unhappy tables, settles arguments, checks on stressed staff and pitches in."},
}
const ROLE_ORDER := ["manager", "cook", "server", "host", "busser", "dishwasher", "porter"]
## California's minimum wage. Nobody is paid less, tips or not.
const MIN_WAGE := 16.90
## Traits change pay a little: dollars an hour per trait (see TRAITS "wage").
const TRAIT_PAY := 0.04
## New people looking for work every morning, and what an extra job ad costs.
const CANDIDATES_PER_DAY := 8
const JOB_AD_COST := 60
const JOB_AD_PEOPLE := 3

## Pay is by the hour. California: past 8 hours in a day it's time and a half,
## past 12 it's double time. Anyone who comes in is paid for at least 4 hours.
const SHIFT_HOURS := 8.0
const OVERTIME := 1.5
const DOUBLE_TIME := 2.0
const DOUBLE_TIME_AFTER := 12.0
const MIN_PAID_HOURS := 4.0
## "open": the day shift, in for prep and home 8 hours later. "mid": 8 hours
## across the middle of the day, for both rushes. "close": the night shift, in
## 8 hours before the last closing jobs are done. "double": all day (overtime!).
const SHIFTS := {
	"open":   {"name": "Day",    "desc": "In before the doors open for prep, home 8 hours later."},
	"mid":    {"name": "Mid",    "desc": "Eight hours across the middle of the day, for both the lunch and dinner rushes."},
	"close":  {"name": "Night",  "desc": "The second half of the day, and stays to close up: mop, restock, trash."},
	"double": {"name": "Double", "desc": "The whole day. Past 8 hours it's time and a half and past 12 double time, and long days wear people out."},
}
const SHIFT_ORDER := ["open", "mid", "close", "double"]
## How many customers a diner draws grows with its seats (DEMAND_SEATS is
## "normal"), a little less than one for one.
const DEMAND_SEATS := 20.0
const DEMAND_SEAT_POWER := 0.8
const DEMAND_SEAT_RANGE := Vector2(0.6, 4.0)
const CLOSE_EXTRA := 45           # minutes of closing duties planned after the doors shut
const LONG_DAY_STRESS := 0.04     # extra stress per minute after 10 hours on a double
## Tomorrow: whoever closed late starts tired; closing then opening ("clopening") is worse.
const CLOSED_LATE_ENERGY := 85.0
const CLOPEN_ENERGY := 70.0
const CLOPEN_STRESS := 8.0
## Lateness and no-shows, rolled each morning for everyone who's due in.
const LATE_CHANCE := 0.025
const LATE_MINUTES := Vector2i(10, 40)
const NO_SHOW_CHANCE := 0.004
## Sick days: people catch colds, more when stressed, run down, or near someone sick.
const SICK_CHANCE := 0.012
const SICK_DAYS := Vector2i(1, 3)
const SICK_SPEED := 0.8
const SICK_SPREAD := 0.04         # chance per hour spent near a sick coworker
const SICK_SPREAD_MAX := 0.15     # at most this much extra chance in one day
## Training: a new hire paired with someone better learns faster.
const TRAIN_XP := 2.0             # practice counts this many times as much
const TRAIN_TILES := 4.0
const TRAIN_DAYS := 7
const TRAIN_TRAINER_SPEED := 0.95 # the trainer slows down a little
## Closing duties: stations are restocked at night, or the first cook in the morning sets up.
const SETUP_MINUTES := 3.0

const CRITIC_CHANCE := 0.25       # chance per day (from day 2) that a critic visits
const TAKEOUT_SHARE := 0.2        # share of arrivals that want takeout, if you have a window
## Health inspections: a first visit soon after you open, then two to four a
## year (every three to six months), plus a follow-up when someone reports a
## reaction to the food.
const FIRST_INSPECTION := Vector2i(3, 10)     # days after opening
const INSPECTION_DAYS := Vector2i(91, 182)    # days between routine visits
const FOLLOW_UP_INSPECTION := Vector2i(3, 10) # days after a reported allergic reaction
const GRADE_EFFECT := {"A": 1.15, "B": 1.0, "C": 0.8}

## Personality traits a new hire might have. wage is added to their pay
## (per day at full rate; it's scaled down to a shift when they're hired).
## bio is the line their life story uses for it.
const TRAITS := {
	"speedy":   {"name": "Speedy",        "good": true,  "wage": 8,   "desc": "Walks 20% faster.", "bio": "Always in a hurry, even on days off."},
	"tireless": {"name": "Tireless",      "good": true,  "wage": 6,   "desc": "Gets tired half as fast.", "bio": "Never seems to need a break."},
	"chatty":   {"name": "Chatty",        "good": true,  "wage": 4,   "desc": "Customers they serve leave happier, but taking orders takes longer. Chats with coworkers twice as much.", "bio": "Knows every regular's name by the second visit."},
	"tidy":     {"name": "Tidy",          "good": true,  "wage": 4,   "desc": "Sweeps a wider area and makes less mess. Can't stand clumsy coworkers.", "bio": "Can't stand a messy station."},
	"learner":  {"name": "Quick learner", "good": true,  "wage": 5,   "desc": "Skills improve twice as fast.", "bio": "Picks up new tricks fast."},
	"friendly": {"name": "Friendly",      "good": true,  "wage": 4,   "desc": "Makes friends 1.5× faster, and coworkers like them from the start.", "bio": "Gets along with just about everyone."},
	"clumsy":   {"name": "Clumsy",        "good": false, "wage": -10, "desc": "Sometimes breaks a plate, and makes more mess.", "bio": "Has broken more plates than anyone can count."},
	"slow":     {"name": "Slowpoke",      "good": false, "wage": -10, "desc": "Works and walks 15% slower.", "bio": "Takes things one careful step at a time."},
	"grumpy":   {"name": "Grumpy",        "good": false, "wage": -8,  "desc": "Warms up to people slowly, starts off cool with everyone and snaps when tired.", "bio": "Not a morning person. Or an afternoon person."},
}

# ------------------------------------------------------------------ where people are from
## Flavour only: hometowns, names and dishes never change a number in the game.
## weight = how often someone comes from there (the US is where the diner is).
## places = where they might have worked before, for their life story.
const ORIGINS := [
	{"country": "USA", "weight": 8.0,
		"cities": ["Tulsa", "Savannah", "Duluth", "Albuquerque", "Milwaukee", "Memphis"],
		"names": ["Dolly", "Earl", "Mabel", "Hank", "Jolene", "Wes", "Tess", "Marcus", "Darnell", "Kayla", "Bo", "Flo", "Cody", "Rhonda", "Shawn", "Lorraine"],
		"dishes": ["chicken-fried steak", "shrimp and grits", "green chile stew", "cherry pie", "biscuits and gravy", "meatloaf"],
		"places": ["a truck stop", "an all-night diner", "a barbecue joint", "a ballpark snack stand"]},
	{"country": "Mexico", "weight": 1.0, "cities": ["Oaxaca", "Puebla", "Guadalajara", "Mérida"],
		"names": ["Rosa", "Mateo", "Ximena", "Diego", "Lupita", "Joaquín"],
		"dishes": ["mole negro", "chiles en nogada", "birria", "cochinita pibil"],
		"places": ["a taquería", "a market food stall"]},
	{"country": "Nigeria", "weight": 1.0, "cities": ["Lagos", "Enugu", "Ibadan"],
		"names": ["Tunde", "Ngozi", "Chidi", "Funmi", "Emeka", "Amara"],
		"dishes": ["jollof rice", "egusi soup", "suya", "puff-puff"],
		"places": ["a buka", "a busy suya stand"]},
	{"country": "Ethiopia", "weight": 1.0, "cities": ["Addis Ababa", "Gondar", "Hawassa"],
		"names": ["Selam", "Dawit", "Hana", "Yonas", "Meron"],
		"dishes": ["doro wat", "shiro", "kitfo", "misir wat"],
		"places": ["a coffee house", "a family restaurant"]},
	{"country": "Ireland", "weight": 1.0, "cities": ["Cork", "Galway", "Dublin"],
		"names": ["Declan", "Aoife", "Cian", "Siobhán", "Niamh", "Ciarán"],
		"dishes": ["Irish stew", "boxty", "soda bread", "colcannon"],
		"places": ["a pub kitchen", "a seaside chipper"]},
	{"country": "Italy", "weight": 1.0, "cities": ["Naples", "Bologna", "Palermo"],
		"names": ["Giulia", "Marco", "Luca", "Chiara", "Francesca", "Matteo"],
		"dishes": ["pizza margherita", "tagliatelle al ragù", "arancini"],
		"places": ["a trattoria", "a pizzeria"]},
	{"country": "India", "weight": 1.0, "cities": ["Chennai", "Delhi", "Kolkata", "Kochi"],
		"names": ["Priya", "Arjun", "Ananya", "Rohan", "Kavya", "Vikram"],
		"dishes": ["masala dosa", "butter chicken", "kosha mangsho", "appam and stew"],
		"places": ["a roadside dhaba", "a hotel kitchen"]},
	{"country": "Vietnam", "weight": 1.0, "cities": ["Hanoi", "Huế", "Hội An"],
		"names": ["Linh", "Minh", "Thảo", "Huy", "Trang"],
		"dishes": ["phở", "bún bò Huế", "cao lầu", "bánh xèo"],
		"places": ["a phở shop", "a street food stall"]},
	{"country": "Philippines", "weight": 1.0, "cities": ["Cebu", "Iloilo", "Manila"],
		"names": ["Maricel", "Paolo", "Joy", "Rafael", "Jasmine"],
		"dishes": ["lechon", "batchoy", "chicken adobo", "sinigang"],
		"places": ["a carinderia", "a bakeshop"]},
	{"country": "South Korea", "weight": 1.0, "cities": ["Jeonju", "Busan", "Seoul"],
		"names": ["Ji-woo", "Min-jun", "Seo-yeon", "Hyun-woo", "Da-eun"],
		"dishes": ["bibimbap", "dwaeji gukbap", "tteokbokki", "kimchi jjigae"],
		"places": ["a street food tent", "a barbecue restaurant"]},
	{"country": "Peru", "weight": 1.0, "cities": ["Lima", "Arequipa", "Cusco"],
		"names": ["Lucía", "Renzo", "Valeria", "Álvaro", "Camila"],
		"dishes": ["ceviche", "rocoto relleno", "lomo saltado"],
		"places": ["a cevichería", "a picantería"]},
	{"country": "Japan", "weight": 1.0, "cities": ["Osaka", "Sapporo", "Fukuoka"],
		"names": ["Yuki", "Haruto", "Aiko", "Ren", "Sakura"],
		"dishes": ["okonomiyaki", "miso ramen", "tonkotsu ramen"],
		"places": ["a ramen shop", "an izakaya"]},
	{"country": "Jamaica", "weight": 1.0, "cities": ["Kingston", "Montego Bay"],
		"names": ["Keisha", "Andre", "Shanice", "Delroy", "Tanisha"],
		"dishes": ["jerk chicken", "ackee and saltfish", "curry goat"],
		"places": ["a jerk stand", "a beach bar"]},
	{"country": "Lebanon", "weight": 1.0, "cities": ["Beirut", "Tripoli", "Byblos"],
		"names": ["Rami", "Nour", "Layla", "Karim", "Maya"],
		"dishes": ["kibbeh", "fattoush", "knafeh", "manakish"],
		"places": ["a bakery", "a mezze restaurant"]},
	{"country": "Poland", "weight": 1.0, "cities": ["Kraków", "Gdańsk", "Wrocław"],
		"names": ["Kasia", "Tomasz", "Zofia", "Piotr", "Agnieszka"],
		"dishes": ["pierogi", "żurek", "bigos"],
		"places": ["a milk bar", "a hotel kitchen"]},
	{"country": "Brazil", "weight": 1.0, "cities": ["Salvador", "Belo Horizonte", "Porto Alegre"],
		"names": ["Thiago", "Larissa", "João", "Bianca", "Rafaela"],
		"dishes": ["moqueca", "pão de queijo", "churrasco"],
		"places": ["a churrascaria", "a juice bar"]},
	{"country": "Morocco", "weight": 1.0, "cities": ["Fez", "Marrakesh", "Tangier"],
		"names": ["Youssef", "Salma", "Hamza", "Leila", "Imane"],
		"dishes": ["lamb tagine", "pastilla", "harira"],
		"places": ["a café in the old medina", "a tagine stall"]},
	{"country": "Greece", "weight": 1.0, "cities": ["Thessaloniki", "Chania", "Athens"],
		"names": ["Eleni", "Nikos", "Sofia", "Yiannis", "Katerina"],
		"dishes": ["moussaka", "spanakopita", "souvlaki"],
		"places": ["a taverna", "a bakery"]},
	{"country": "Canada", "weight": 1.0, "cities": ["Montréal", "Halifax", "Winnipeg"],
		"names": ["Élodie", "Liam", "Chloé", "Owen", "Mathieu"],
		"dishes": ["poutine", "tourtière", "butter tarts"],
		"places": ["a sugar shack", "a hockey rink canteen"]},
	{"country": "China", "weight": 1.0, "cities": ["Chengdu", "Guangzhou", "Xi'an"],
		"names": ["Mei", "Wei", "Lin", "Jun", "Xiu"],
		"dishes": ["mapo tofu", "dim sum", "biangbiang noodles"],
		"places": ["a noodle shop", "a dim sum house"]},
]

## One of these ends each life story.
const HOBBIES := [
	"Plays bass in a garage band.", "Collects old postcards.", "Is training for a marathon.",
	"Knits between shifts.", "Grows chillies on a tiny balcony.", "Is saving up for a motorbike.",
	"Watches old kung fu movies.", "Sings karaoke every Friday.", "Paints tiny landscapes on the bus.",
	"Keeps three cats and a very loud parrot.", "Is learning the accordion, badly.", "Plays chess in the park on Sundays.",
	"Fixes up old bicycles.", "Takes night classes in accounting.", "Coaches a kids' soccer team.",
	"Reads a mystery novel a week.", "Dances salsa on weekends.", "Is learning to juggle.",
	"Bakes bread at 5 a.m. for fun.", "Knows every word of every musical.", "Builds model trains.",
	"Goes fishing on days off.", "Writes poems on napkins.", "Plays pickup basketball after work.",
]

# ------------------------------------------------------------------ how staff get along
## Every person has an opinion of each coworker, from -100 to +100. It's their
## first impression (never changes) plus what has happened since (fades each night).
const REL_NEAR_TILES := 4.0       # "side by side": both working in the same room, this close
const REL_WORK_GAIN := 0.04       # opinion per minute of working side by side
const REL_WORK_DAY_CAP := 5.0     # most a pair gains from working together in one day (less with poor chemistry)
const REL_NO_WARM_BELOW := -10.0  # below this, working together stops helping
const REL_CHAT_TILES := 3.0       # chatting: both on a break, or both idle, this close
const REL_CHAT_EVERY := 10.0      # minutes of chatting per exchange (Chatty: twice as often)
const REL_CHAT_GOOD := 2.0        # a nice chat...
const REL_CHAT_BAD := -2.0        # ...or an annoying one. Good chemistry makes nice ones likelier
const REL_CHAT_DAY_CAP := 4.0     # most a pair gains, or loses, from chats in one day
const REL_FADE := 0.05            # share of history that fades every night
const REL_CHEMISTRY := 15         # chemistry: one roll of -15 to +15 for the pair, then up to 4 either way for each side
const FRIEND_AT := 35.0           # friends: both opinions at least this
const BEST_FRIEND_AT := 70.0
const RIVAL_AT := -35.0           # rivals: either opinion at most this
const FRIENDLY_AVG := 10.0
const TENSE_AVG := -10.0
const LABEL_STICK := 5.0          # a label sticks until opinions move this far back past the line
const FRIEND_SPEED := 1.08        # working near a friend
const BEST_FRIEND_SPEED := 1.12
const RIVAL_SPEED := 0.95         # working near a rival
const RIVAL_TILES := 3.0
const BICKER_CHANCE := 0.015      # per minute, rivals this close
const BICKER_MINUTES := 1.0
const BICKER_REVIEW := 0.3        # stars a table loses when it sees an argument
const SNAP_CHANCE := 0.01         # per minute, tired and near someone
const SNAP_ENERGY := 30.0         # Grumpy people snap below 50
const BUMP_CHANCE := 0.06         # two walking staff on one kitchen tile
const SNACK_CHANCE := 0.2         # a break chat where someone shares food
const GOOD_TRAIT_GAIN := {"friendly": 1.5, "grumpy": 0.5}

## Points and the reason shown for each thing that can happen between two people.
const REL_EVENTS := {
	"work":     {"reason": "Worked together"},
	"chat":     {"reason": "Good chats"},
	"chat_bad": {"reason": "Annoying chats"},
	"snack":    {"points": 3.0,  "reason": "Shared food"},
	"teamwork": {"points": 1.0,  "reason": "Great orders together"},
	"fixed":    {"points": 4.0,  "reason": "Fixed my station"},
	"plates":   {"points": -4.0, "reason": "Dropped plates"},
	"bump":     {"points": -2.0, "reason": "Got in my way"},
	"snapped":  {"points": -5.0, "reason": "Snapped at me"},
	"sofa":     {"points": -3.0, "reason": "Hogged the sofa"},
	"bicker":   {"points": -2.0, "reason": "Arguments"},
	"phone":    {"points": -3.0, "reason": "Slacking off"},
	"told_off": {"points": -4.0, "reason": "Told me off"},
	"remake":   {"points": -2.0, "reason": "Got orders wrong"},
	"hands":    {"points": -3.0, "reason": "Doesn't wash their hands"},
	"noshow":   {"points": -4.0, "reason": "Left us short-handed"},
	"late":     {"points": -1.5, "reason": "Late again"},
	"trained":  {"reason": "Showed me the ropes"},
	"blowup":   {"points": -6.0, "reason": "The big argument"},
	"mediated": {"reason": "Talked it out"},
	"meal":     {"points": 1.5,  "reason": "Staff meals together"},
	"tips_keep":  {"points": -2.0, "reason": "Keeps all the tips"},
	"tips_share": {"points": 1.0,  "reason": "Shares the tips"},
}

## First impressions from traits (from = the one who has the opinion, "*" = anyone).
const CLASHES := [
	{"from": "tidy",   "to": "clumsy",   "points": -12.0, "reason": "Keeps making a mess"},
	{"from": "speedy", "to": "slow",     "points": -10.0, "reason": "So slow"},
	{"from": "grumpy", "to": "chatty",   "points": -8.0,  "reason": "Never stops talking"},
	{"from": "grumpy", "to": "*",        "points": -6.0,  "reason": "Grumpy"},
	{"from": "chatty", "to": "chatty",   "points": 8.0,   "reason": "Great to talk to"},
	{"from": "*",      "to": "friendly", "points": 6.0,   "reason": "So warm"},
]

## Phones: idle staff sometimes sneak a look. On a break it's fine.
const PHONE_CHANCE := 0.005       # per idle minute (twice as likely when fed up)
const PHONE_CHANCE_WORKING := 0.002  # per working minute, only when fed up
const PHONE_MINUTES := Vector2(3.0, 8.0)
const PHONE_COWORKER_TILES := 4.0
const PHONE_CUSTOMER_TILES := 5.0
const PHONE_MANAGER_TILES := 6.0
const PHONE_REVIEW := 0.2         # stars a table loses when it sees it
const PHONE_WARN_AFTER := 3       # times you catch someone in a week before a warning

## Managers still do their jobs, and also keep an eye on the floor.
const MANAGER_STRICT := 0.7       # chance to reprimand someone on their phone
const MANAGER_STRICT_FRIEND := 0.2
const MANAGER_STRICT_RIVAL := 0.95
const MANAGER_MOOD := 0.2         # fed up: this much stricter; cheerful: this much softer
const MANAGER_BREAKUP_TILES := 5.0
## A manager on shift also settles arguments (they sit the two down and talk
## it out), checks on anyone who's stressed and sends the worn-out on a break.
## Having a manager at all takes a little more stress off everyone overnight.
const MEDIATE_POINTS := 10.0      # opinion each way after a good talk (less from a so-so manager)
const MEDIATE_STRESS := 10.0
const CHECKIN_AT := 55.0          # stress that gets a manager's check-in
const CHECKIN_STRESS := 12.0
const CHECKIN_EVERY := 30.0       # minutes between one person's check-ins
const MANAGER_NIGHT_CALM := 6.0

## Stress, from 0 to 100. It rises in a rush, near rivals, when tired and when
## bad things happen, and falls on breaks (fast on a sofa), near friends, when
## idle and overnight. It sets the mood; too much for too long and people quit.
const STRESS_WORK := 0.025        # per minute of work while open
const STRESS_BUSY := 0.02         # ...more when there are more customers waiting than staff
const STRESS_SWAMPED := 0.05      # ...and more again when there are twice as many
const STRESS_RIVAL := 0.05        # a rival nearby
const STRESS_TIRED := 0.05        # energy under 30
const STRESS_FRIEND := -0.015     # a friend working nearby
const STRESS_IDLE := -0.04
const STRESS_REST := -0.12        # on a break with no sofa
const STRESS_SOFA := -0.35        # on a sofa
const STRESS_FROM_BAD := 0.5      # stress per opinion point lost in a bad moment
const STRESS_NIGHT := -30.0       # a night's sleep
const STRESS_CHEERFUL := 25.0     # mood: at or under this, cheerful
const STRESS_FED_UP := 60.0       # at or over this, fed up
const STRESS_MISTAKES := 75.0     # over this: burnt food, dropped plates, 10% slower
const STRESS_BURNOUT := 80.0      # ending three days in a row over this, they quit
const BURNOUT_QUIT_NIGHTS := 3
const RAISE_REFUSALS_QUIT := 3    # say no to a raise this many times and they find another job
const STRESS_FRIEND_QUIT := 15.0  # stress for a friend when someone quits

## Written story moments when two people become friends, best friends or rivals.
## {a} and {b} are names; {a_home} and {a_dish} are a's hometown and dish.
const STORIES := {
	"friends": ["{a} and {b} have started taking their breaks together.", "{a} showed {b} photos from {a_home}.", "{b} tried {a}'s {a_dish} and can't stop talking about it.", "{a} and {b} have a running joke nobody else gets."],
	"best": ["{a} taught {b} how to make {a_dish} after closing.", "{a} and {b} have started walking home together.", "{a} saves {b} a seat on the bus every morning.", "{a} and {b} are planning a trip to {a_home} together."],
	"rivals": ["{a} and {b} had words in the walk-in fridge. Nobody knows what about.", "{a} rearranged {b}'s station. Again.", "{a} and {b} have stopped saying good morning.", "{a} says {b} steals the good spatula."],
}

# ------------------------------------------------------------------ events
## Things that happen during the day. From day 2, one or two a day at random
## times; some ask you to choose. weight = how likely, min_day = earliest day.
const EVENTS := {
	"tour_bus":       {"weight": 1.0, "min_day": 2},
	"power_cut":      {"weight": 0.6, "min_day": 3},
	"rowdy":          {"weight": 0.8, "min_day": 2},
	"celebrity":      {"weight": 0.4, "min_day": 3},
	"short_delivery": {"weight": 0.0, "min_day": 2},   # happens with the morning delivery now
	"grease_fire":    {"weight": 0.5, "min_day": 2},
	"staff_blowup":   {"weight": 1.5, "min_day": 2},
	"raise":          {"weight": 1.2, "min_day": 4},
	"day_off":        {"weight": 0.6, "min_day": 3},
	"festival":       {"weight": 0.5, "min_day": 2},
}
const EVENTS_PER_DAY := Vector2i(1, 2)
const RAIN_CHANCE := 0.2          # chance a day is rainy (fewer walk-ins, more takeout)
const RAIN_CROWD := 0.8
const TOUR_BUS_GROUPS := Vector2i(5, 6)
const ELECTRICIAN_COST := 150.0
const FESTIVAL_CROWD := 1.35
const BUZZ_DAYS := 3              # a great celebrity review brings more people for this many days
const BUZZ_CROWD := 1.2
const RAISE_AMOUNT := Vector2(0.50, 2.00)   # dollars an hour

## Speech bubbles and the staff log.
const BUBBLE_SECONDS := 2.5
const MAX_BUBBLES := 3
const LOG_KEEP := 100

## What people say. {home} and {dish} are the speaker's hometown and signature dish.
const LINES := {
	"awkward": ["Ugh.", "If you say so.", "Not this again.", "Mm-hm."],
	"chat": ["Ha! No way.", "Did you see that?", "Busy one, huh?", "Miss {home}…", "{dish} later?", "Tell me more!", "So then I said…", "Long day…"],
	"friends": ["Nice one!", "Got your back.", "Teamwork!", "On it!", "You're quick!"],
	"bicker": ["Watch it!", "Not again!", "Your turn!", "Ugh. Fine.", "Seriously?"],
	"bump": ["Oops, sorry!", "Behind you!", "Coming through!"],
	"snap": ["Not now!", "Leave it!", "I'm tired, okay?", "Ugh."],
	"plate": ["Again?!", "Careful!"],
	"sofa": ["No room?", "Scoot over!"],
	"snack": ["Try this!", "{dish}, anyone?"],
	"fixed": ["Good as new!"],
	"thanks": ["Thanks!", "My hero."],
	"teamwork": ["Nailed it!", "5 stars!"],
	"phone": ["Just a sec…", "One message…"],
	"sorry": ["Sorry!", "Putting it away!"],
	"reprimand": ["Phone away.", "Not on shift!"],
	"slide": ["I saw nothing."],
	"greet": ["Welcome in!", "Hi there!", "Right this way!", "Won't be long!"],
	"remake": ["Remake?!", "Not again…", "Who wrote this?"],
	"mouse": ["A mouse!", "Eek!", "Get it!", "Shoo!"],
	"hands": ["Wash your hands!", "Hands!"],
	"sorry_table": ["So sorry!", "It's on us."],
	"argue": ["That's not fair!", "Now listen here…"],
	"slacking": ["Really?", "Slacking?"],
	"cover": ["I got this."],
	"breakup": ["Break it up!", "Enough, you two."],
	"mediate": ["Let's talk.", "Both of you, a minute?", "What's going on?"],
	"checkin": ["You okay?", "Take five.", "Rough one, huh?"],
}

const SKIN := [Color("f1c7a5"), Color("e0ac86"), Color("c68863"), Color("a5694a"), Color("7d4a33"), Color("f6d8bf")]
const HAIR := [Color("2b1d14"), Color("5a3a22"), Color("a0662f"), Color("d8b25a"), Color("1c1c1c"), Color("8c8c8c"), Color("b8452e")]
const CLOTHES := [Color("3f7fc0"), Color("2f9a78"), Color("7b59b8"), Color("e2a13a"), Color("5c7088"), Color("c64e87"), Color("8f6a3f"), Color("4b8f3a"), Color("d8623f"), Color("3b4b5a")]
const UNIFORM := Color("c8403a")

## Directions used for rotation: 0 up, 1 right, 2 down, 3 left.
const DIRS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]


func item_name(key: String) -> String:
	if FURNITURE.has(key):
		return FURNITURE[key]["name"]
	if BUILD.has(key):
		return BUILD[key]["name"]
	if DISHES.has(key):
		return DISHES[key]["name"]
	return key.capitalize()


func item_cost(key: String) -> int:
	if FURNITURE.has(key):
		return FURNITURE[key]["cost"]
	if BUILD.has(key):
		return BUILD[key]["cost"]
	return 0


func item_desc(key: String) -> String:
	if FURNITURE.has(key):
		return FURNITURE[key]["desc"]
	if BUILD.has(key):
		return BUILD[key]["desc"]
	return ""


## The hourly pay someone would ask for in this role, with these skills and traits.
func role_pay(role: String, cooking: int, service: int, traits: Array = []) -> float:
	var r: Dictionary = ROLES.get(role, ROLES["server"])
	var skill: float = cooking if r["skill"] == "cooking" else (service if r["skill"] == "service" else (cooking + service) / 2.0)
	var lo: float = r["pay"][0]
	var hi: float = r["pay"][1]
	var pay: float = lo + (hi - lo) * clampf((skill - 1.0) / 9.0, 0.0, 1.0)
	for t in traits:
		if TRAITS.has(t):
			pay += TRAITS[t]["wage"] * TRAIT_PAY
	return maxf(MIN_WAGE, snappedf(pay, 0.25))


## "$18.50/hr"
func hourly(v: float) -> String:
	return "$%.2f/hr" % v


func loan_terms(amount: int) -> Dictionary:
	for l in LOANS:
		if l["amount"] == amount:
			return l
	return {}


## Who makes a dish: servers pour drinks, cooks make everything else.
func job_type_for(station: String) -> String:
	return "serve" if station == "drinks" else "cook"


func rush_at(minute: float) -> Dictionary:
	for r in RUSHES:
		if minute >= r["from"] and minute < r["to"]:
			return r
	return {}


func xp_needed(level: int) -> float:
	return XP_BASE + XP_PER_LEVEL * level


func _ready() -> void:
	# Poppins has no Vietnamese letters like ả or ế (Thảo, Huế), so borrow them
	# from a tiny cut of DejaVu Sans. Everything else still uses Poppins.
	var extra: FontFile = load("res://ui/fonts/DejaVuSans-Extra.ttf")
	var extra_bold: FontFile = load("res://ui/fonts/DejaVuSans-Bold-Extra.ttf")
	for n in ["Regular", "Medium", "Bold", "BoldItalic"]:
		var f: FontFile = load("res://ui/fonts/Poppins-%s.ttf" % n)
		if f != null:
			f.fallbacks = [extra_bold if n.begins_with("Bold") else extra]


## Picks a hometown for a new hire: {country, city, dish, place, name}.
func random_origin(used_names: Dictionary = {}) -> Dictionary:
	var total := 0.0
	for o in ORIGINS:
		total += o["weight"]
	var roll := randf() * total
	var pick: Dictionary = ORIGINS[0]
	for o in ORIGINS:
		roll -= o["weight"]
		if roll <= 0.0:
			pick = o
			break
	var names: Array = pick["names"].filter(func(n): return not used_names.has(n))
	if names.is_empty():
		names = pick["names"]
	return {"country": pick["country"], "city": pick["cities"].pick_random(), "dish": pick["dishes"].pick_random(),
		"place": pick["places"].pick_random(), "name": names.pick_random()}


## "Oaxaca, Mexico"
func hometown(origin: Dictionary) -> String:
	if origin.is_empty():
		return ""
	return "%s, %s" % [origin.get("city", ""), origin.get("country", "")]


## A short life story, written from who the person already is (skills, traits,
## hometown), so it never changes their numbers.
func write_bio(origin: Dictionary, cooking: int, service: int, traits: Array) -> String:
	var bits: Array = []
	var home := hometown(origin)
	if origin.get("country", "") == "USA":
		bits.append(["Grew up in %s.", "Born and raised in %s.", "Came here from %s."].pick_random() % home)
	else:
		bits.append(["Grew up in %s.", "Born and raised in %s.", "Moved here from %s."].pick_random() % home)
	var place: String = origin.get("place", "a busy restaurant")
	var years := randi_range(2, 9)
	if cooking >= 7 and cooking >= service:
		bits.append("Spent %d years on the line at %s." % [years, place])
	elif service >= 7:
		bits.append("Waited tables at %s for %d years." % [place, years])
	elif cooking >= 5 and cooking >= service:
		bits.append("Cooked at %s for a couple of years." % place)
	elif service >= 5:
		bits.append("Worked the counter at %s for a while." % place)
	else:
		bits.append("First restaurant job, and keen to learn.")
	if not traits.is_empty() and TRAITS.has(traits[0]):
		bits.append(TRAITS[traits[0]]["bio"])
	bits.append(HOBBIES.pick_random())
	return " ".join(bits)
