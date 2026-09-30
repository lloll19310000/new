extends Control
## How to play. Opened with the ? button in the top bar.

@onready var text: RichTextLabel = %Text


func _ready() -> void:
	for b in [%Close, %GotIt]:
		b.pressed.connect(func(): visible = false)
	text.text = build_text()


func toggle() -> void:
	visible = not visible


func ic(n: String, col: String = "#f2c14e") -> String:
	return "[img width=16 height=16 color=%s]res://ui/icons/%s.svg[/img]" % [col, n]


func build_text() -> String:
	var t := ""
	t += "[font_size=16][b][color=#f2c14e]The idea[/color][/b][/font_size]\n"
	t += "You run a diner but never control anyone directly. You build, hire and set priorities; your staff decide what to do next from a shared list of jobs, and get on (or don't) in their own way. There are no goals: build whatever you like and see what stories happen.\n\n"
	t += "[font_size=16][b][color=#f2c14e]Each day[/color][/b][/font_size]\n"
	t += "%s  [b]Morning:[/b] build and plan. Time stands still until you press [b]Start the day[/b].\n" % ic("sun")
	t += "%s  [b]Prep hour:[/b] the hour before opening. Cooks prep dishes (they cook 40%% faster later), the delivery van drops off supplies, and the crew can eat a staff meal. Press [b]Open the doors[/b] early if you like.\n" % ic("prep")
	t += "%s  [b]Open:[/b] 10:00 to 22:00 unless you change the hours in the [b]Office[/b] (breakfast, lunch, dinner). Customers come in, order, eat, pay and leave a review. Watch for the [color=#e2703a]rushes[/color].\n" % ic("open")
	t += "%s  [b]After closing:[/b] closers sweep, restock the stations and take out the trash, then you get the day's report. The game saves every morning.\n\n" % ic("moon")
	t += "[font_size=16][b][color=#f2c14e]Building[/color][/b][/font_size]\n"
	t += "%s  [b]Structure:[/b] drag floors, drag walls around them, then click a wall facing the street for a door. A dumpster goes outside.\n" % ic("structure")
	t += "   Customers stay out of the [b]kitchen[/b] and the [b]staff room[/b], so give the dining room its own door.\n"
	t += "%s  [b]Dining:[/b] tables with chairs beside them, a host stand and a till. Chairs turn to face the table; press [b]R[/b] to turn anything.\n" % ic("dining")
	t += "%s  [b]Kitchen:[/b] stations, fridges and freezers, a prep counter, a sink, trash cans, mouse traps and a pass counter between the kitchen and the dining room.\n" % ic("kitchen")
	t += "%s  [b]Restroom:[/b] its own floor with a toilet and a hand sink. Customers expect one, and so does the inspector.\n" % ic("restroom")
	t += "%s  [b]Decor:[/b] plants, lamps, pictures and more cheer up tables nearby.\n" % ic("decor")
	t += "%s  [b]Staff room:[/b] a sofa lets tired staff rest much faster.\n" % ic("staff_room")
	t += "%s  [b]Land:[/b] you start on one lot. [b]Buy land[/b] (in Structure) to grow onto the plots marked For sale. More land means more rent.\n" % ic("structure")
	t += "%s  [b]Upgrades:[/b] click a station and upgrade it to Pro: faster cooking, half the wear.\n\n" % ic("star")
	t += "[font_size=16][b][color=#f2c14e]Staff[/color][/b][/font_size]\n"
	t += "Every person has a priority for each job: %s cook  %s serve  %s host  %s wash  %s clean  %s repair.\n" % [ic("cook"), ic("serve"), ic("host"), ic("wash"), ic("clean"), ic("fix")]
	t += "[color=#ff7a6b]1[/color] is done first, [color=#9fb6cc]4[/color] last, and – never. Skills grow with practice, and some people have traits that help or hurt.\n"
	t += "%s  [b]Shifts:[/b] each person works Opening, Closing or a Double (button on their card). Pay is by the hour, and past 8 hours it's overtime at time and a half. Closing then opening the next morning leaves people tired.\n" % ic("clock")
	t += "%s  People are sometimes late, and now and then don't show up at all. When someone's sick you choose: send them home, or let them work slower and maybe pass it on.\n" % ic("sick", "#6cc3a0")
	t += "%s  [b]Training:[/b] pair a beginner with someone much better (school button on their card) and they learn twice as fast.\n" % ic("school")
	t += "%s  Everyone has a hometown and a story. Coworkers form opinions of each other: [color=#6cc3a0]friends[/color] work faster side by side, [color=#e75a4e]rivals[/color] bicker. The [b]Crew[/b] tab shows who feels what, and the staff log says why.\n" % ic("crew", "#e27fa8")
	t += "%s  Idle staff sneak onto their phones. Click them to catch them, or make someone a [b]manager[/b] (%s on their card) to keep an eye on the floor and handle complaints.\n" % [ic("phone", "#6aa6d9"), ic("star")]
	t += "%s  [b]Stress[/b] builds with work, rushes and rivals, and falls on breaks (a sofa is best) and near friends. Stressed people burn food and drop plates. End two days in a row burned out and they quit. People also ask for raises and days off.\n\n" % ic("storm", "#e75a4e")
	t += "[font_size=16][b][color=#f2c14e]Front of house[/color][/b][/font_size]\n"
	t += "%s  A [b]host stand[/b] and someone on Host keep a waitlist, so fewer people walk past. Take [b]bookings[/b] in the Office: a table is held for them, and some don't show.\n" % ic("host")
	t += "%s  With a [b]till[/b], people pay on the way out; without one a server brings the check. Slow checks mean the odd dine-and-dash.\n" % ic("money")
	t += "%s  [b]Regulars[/b] have a usual order and a favourite server. [b]Delivery apps[/b] bring extra orders (a driver picks them up) but take 25%%.\n" % ic("heart", "#e27fa8")
	t += "%s  Unhappy tables ask for the manager. A manager on shift sorts it out; with none, you decide.\n\n" % ic("alert")
	t += "[font_size=16][b][color=#f2c14e]The kitchen[/color][/b][/font_size]\n"
	t += "%s  The [b]ticket rail[/b] (left, while open) shows every order being made and how long it's waited.\n" % ic("ticket")
	t += "%s  Food keeps a few days (salad and fruit 2, meat 3, frozen for weeks) and needs fridge or freezer space. What goes off is thrown out and shows as waste in the report. Run out and a dish is [b]sold out[/b].\n" % ic("supplies")
	t += "%s  Mix-ups get sent back and remade, some customers have [b]allergies[/b], and plates left on the pass go cold.\n\n" % ic("plate")
	t += "[font_size=16][b][color=#f2c14e]Menu and money[/color][/b][/font_size]\n"
	t += "%s  Star a dish on the Menu page to make it [b]today's special[/b]: people order it much more. Set how much of each dish to prep.\n" % ic("menu")
	t += "%s  Pick a [b]supplier[/b] on the Supplies page: Budget is cheap, Farm fresh makes better food. The van comes every morning; sometimes it's late or short.\n" % ic("van")
	t += "%s  [b]Rent and utilities[/b] are due every 7 days. The report shows food cost, staff cost and profit margin: about 30%% each is healthy. Short on cash? The Office has bank loans.\n" % ic("office")
	t += "%s  Tips go to the staff, not to you. In the Office you choose whether servers keep them or share with the kitchen.\n" % ic("tip")
	t += "%s  High prices keep people away; low prices bring a crowd. Good reviews bring bigger tips.\n\n" % ic("money")
	t += "[font_size=16][b][color=#f2c14e]Keeping it clean[/color][/b][/font_size]\n"
	t += "%s  Trash cans fill up: someone on Clean takes the bags to the dumpster. Overflowing bins, dirty floors and food left out bring [b]mice[/b], and customers who see one leave. Traps help.\n" % ic("mouse", "#e75a4e")
	t += "%s  Restrooms get dirty with use; staff should wash their hands after the restroom or the trash.\n\n" % ic("wash")
	t += "[font_size=16][b][color=#f2c14e]Every day is different[/color][/b][/font_size]\n"
	t += "%s  From day 2, things happen: tour buses, power cuts, rowdy tables, celebrities, grease fires, shouting matches. Some pause the game and ask what you want to do.\n" % ic("alert")
	t += "%s  Serve people well and your [b]reputation[/b] grows (top bar): more customers, and tourists once you're a Town favourite.\n\n" % ic("star")
	t += "[font_size=16][b][color=#f2c14e]Visitors to watch for[/color][/b][/font_size]\n"
	t += "%s  A [b]food critic[/b] now and then. Their review counts five times.\n" % ic("critic", "#b58be0")
	t += "%s  The [b]health inspector[/b] every few days, unannounced: floors, the kitchen, the restroom, hand-washing, trash and mice.\n\n" % ic("inspector", "#6cc3a0")
	t += "[font_size=16][b][color=#f2c14e]Controls[/color][/b][/font_size]\n"
	t += "Right-drag, middle-drag or WASD: move.  Scroll: zoom.  R: turn.  Esc: stop building.\n"
	t += "Space: pause.  1, 2, 3: speed.  Tab: show or hide the side panel."
	return t
