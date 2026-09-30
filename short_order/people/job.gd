extends RefCounted
## One task on the job board, like "cook a burger for table 3".

var type: String = ""        # which job column it belongs to: cook, serve, host, wash, clean, fix
var kind: String = ""        # what exactly: take_order, cook, prep, deliver, greet, till, check, complaint, bus, wash, sweep, repair
var group = null             # the customer group it is for, if any
var furniture = null         # the table, sink or station it is about, if any
var dish: String = ""        # for cook and prep jobs
var count: int = 1           # how many items are cooked together
var items: Array = []        # the dishes in this cook job (all made at one station)
var station: String = ""     # which kind of station they need
var cell: Vector2i = Vector2i.ZERO
var claimed_by = null        # the staff member doing it
var pref = null              # a staff member who gets first go (a regular's favourite server)
var who = null               # manager jobs: the person to talk to...
var who2 = null              # ...and the other one, when settling an argument
var remake := false          # a dish being made again after the wrong one went out
var done: bool = false
var created: float = 0.0     # game minute it was posted, older jobs win ties
var retry_at: float = 0.0    # after a failed try, nobody retries before this sim time


func describe() -> String:
	match kind:
		"take_order": return "Take an order"
		"cook": return "Cook %d item%s at the %s" % [count, "" if count == 1 else "s", Data.FURNITURE[station]["name"].to_lower()]
		"prep": return "Prep %d %s" % [count, Data.DISHES[dish]["name"].to_lower()]
		"deliver": return "Bring food to a table"
		"greet": return "Greet customers at the door"
		"till": return "Ring up a bill at the till"
		"check": return "Take payment at a table"
		"complaint": return "Talk to an unhappy table"
		"mediate": return "Settle an argument"
		"checkin": return "Check on a stressed coworker"
		"scrub": return "Clean the restroom"
		"trash": return "Take out the trash"
		"restroom": return "A trip to the restroom"
		"restock": return "Restock the %s" % Data.FURNITURE[furniture.type]["name"].to_lower()
		"bus": return "Clear a table"
		"collect": return "Pick up the money left on a table"
		"wash": return "Wash dishes"
		"sweep": return "Sweep the floor"
		"repair": return "Repair the %s" % Data.FURNITURE[furniture.type]["name"].to_lower()
		"service": return "Service the %s" % Data.FURNITURE[furniture.type]["name"].to_lower()
	return kind
