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
	t += "You run a diner but never control anyone directly. You build, hire and set priorities; your staff decide what to do next from a shared list of jobs, and get on (or don't) in their own way. Nothing is required and the game never ends: build whatever you like and see what stories happen. The [b]Goals[/b] tab (%s) has optional milestones that unlock recipes and decor.\n\n" % ic("star")
	t += "[font_size=16][b][color=#f2c14e]Each day[/color][/b][/font_size]\n"
	t += "%s  [b]Morning:[/b] build and plan. Time stands still until you press [b]Start the day[/b].\n" % ic("sun")
	t += "%s  [b]Prep hour:[/b] the hour before opening. Cooks prep dishes (they cook 40%% faster later), the delivery van drops off supplies, and the crew can eat a staff meal. Press [b]Open the doors[/b] early if you like.\n" % ic("prep")
	t += "%s  [b]Open:[/b] 10:00 to 22:00 unless you change the hours in the [b]Office[/b] (breakfast, lunch, dinner). Customers come in, order, eat, pay and leave a review. Watch for the [color=#e2703a]rushes[/color].\n" % ic("open")
	t += "%s  [b]After closing:[/b] closers sweep, restock and service the stations and take out the trash, then you get the day's report. Each diner has its own save and saves itself every morning; Esc (or %s) opens the menu to save, load or change settings.\n\n" % [ic("moon"), ic("bars")]
	t += "[font_size=16][b][color=#f2c14e]The town[/color][/b][/font_size]\n"
	t += "%s  Day 1 is the 1st of March. [b]Seasons[/b] change what people order (iced tea in summer, soup in winter) and what produce costs; [b]holidays[/b] bring their own crowds. The top bar shows the date and the weather; the Office has tomorrow's forecast and what's on around town (the fair, roadwork, the farmers' market...).\n" % ic("calendar")
	t += "%s  Once you're a Town favourite a [b]rival[/b] opens across the street. Loyalty cards and matching their prices fight back; stay excellent for two weeks and they close.\n\n" % ic("storm", "#b58be0")
	t += "[font_size=16][b][color=#f2c14e]Building[/color][/b][/font_size]\n"
	t += "%s  [b]Structure:[/b] drag floors, drag walls around them, then click a wall facing the street for a door. A dumpster goes outside.\n" % ic("structure")
	t += "   Customers stay out of the [b]kitchen[/b] and the [b]staff room[/b], so give the dining room its own door.\n"
	t += "%s  [b]Dining:[/b] tables with chairs beside them (a single table seats one), a host stand and a till. Chairs turn to face the table; press [b]R[/b] to turn anything.\n" % ic("dining")
	t += "%s  [b]Kitchen:[/b] stations, an ice machine for cold drinks, fridges and freezers, a prep counter, a sink, trash cans and mouse traps. The [b]pass counter[/b] goes in the wall between the kitchen and the dining room. Machines face away from the wall when you place them.\n" % ic("kitchen")
	t += "%s  [b]Restroom:[/b] its own floor with a toilet and a hand sink. Customers expect one, and so does the inspector.\n" % ic("restroom")
	t += "%s  [b]Dining[/b] also has [b]booths[/b] (couples and families love them) and a [b]counter with stools[/b] (truckers and regulars on their own sit there).\n" % ic("dining")
	t += "%s  [b]Decor:[/b] plants, lamps, pictures and more cheer up tables nearby. The [b]employee of the month[/b] frame shows your best worker; a clock, a trophy shelf and a fish tank are rewards from the Goals board.\n" % ic("decor")
	t += "%s  [b]Staff & office:[/b] a sofa, a break table, staff coffee, a vending machine, a TV and lockers make breaks better; a manager's desk, a filing cabinet and a schedule board help the office run.\n" % ic("staff_room")
	t += "%s  [b]Waiting:[/b] benches and waiting chairs by the door (or outside) keep people from walking off; when they're full, people line up along the sidewalk. Big parties need a long table.\n" % ic("people")
	t += "%s  [b]Copy area[/b] and [b]Paste[/b] (Structure) copy a whole room as a blueprint. [b]Ctrl+Z[/b] undoes your last change this morning.\n" % ic("structure")
	t += "%s  [b]Land:[/b] you start on one lot. Click a plot marked For sale (or use [b]Buy land[/b] in Structure) to buy it. More land means more rent.\n" % ic("structure")
	t += "%s  [b]Upgrades:[/b] click a station and upgrade it to Pro: faster cooking, half the wear.\n\n" % ic("star")
	t += "[font_size=16][b][color=#f2c14e]Staff[/color][/b][/font_size]\n"
	t += "%s  Everyone is hired for a [b]role[/b]: line cook, server, host, busser, dishwasher, porter or manager. The role sets what they do first and their pay. New people come by every morning; hire as many as you like (up to %d), or post a job ad for more.\n" % [ic("staff"), Data.MAX_STAFF]
	t += "%s  [b]Pay[/b] is by the hour at California rates (never under $%.2f): time and a half past 8 hours in a day, double time past 12.\n" % [ic("money"), Data.MIN_WAGE]
	t += "Each person still has a priority for each job (%s cook  %s serve  %s host  %s wash  %s clean  %s repair; [color=#ff7a6b]1[/color] first, – never) that you can change on their row. Skills grow with practice, and some people have traits that help or hurt.\n" % [ic("cook"), ic("serve"), ic("host"), ic("wash"), ic("clean"), ic("fix")]
	t += "%s  [b]The schedule[/b] writes itself every night (Staff > Schedule): day, mid and night shifts so every shift has cooks and servers, and two days off a week each. Set someone's shift by hand and it stays put.\n" % ic("calendar")
	t += "%s  People are sometimes late, and now and then don't show up at all. When someone's sick you choose: send them home, or let them work slower and maybe pass it on.\n" % ic("sick", "#6cc3a0")
	t += "%s  [b]Training:[/b] pair a beginner with someone much better (school button on their card) and they learn twice as fast.\n" % ic("school")
	t += "%s  Everyone has a hometown and a story. Coworkers form opinions of each other: [color=#6cc3a0]friends[/color] work faster side by side, [color=#e75a4e]rivals[/color] bicker. The [b]Crew[/b] tab shows who feels what, and the staff log says why.\n" % ic("crew", "#e27fa8")
	t += "%s  Idle staff sneak onto their phones. Click them to catch them.\n" % ic("phone", "#6aa6d9")
	t += "%s  [b]Careers:[/b] people climb their role's ladder (trainee cook, line cook, senior line cook, sous chef) with a raise and a perk you pick. They ask for days off for their own lives, and some can't work mornings or nights. Pick a [b]morning huddle[/b] focus and offer [b]benefits[/b] in the Office.\n" % ic("school")
	t += "%s  [b]Breaks:[/b] a 30-minute meal break and 10-minute rest breaks, staggered so nobody leaves the floor empty. A missed meal break costs an hour's pay. People not on the morning shift stay home until their shift; at the end of a shift, someone stays on if nobody else in their role is there yet.\n" % ic("sun")
	t += "%s  A [b]manager[/b] runs the shift: writes a better schedule (resting the stressed, keeping rivals apart), settles arguments, checks on anyone having a rough day, handles unhappy tables and keeps phones away.\n" % ic("star")
	t += "%s  [b]Crew moments:[/b] birthdays bring cake to the staff room, the crew marks milestones, and a cook who's settled in may teach the kitchen their hometown dish. Every four weeks the hardest worker is [b]employee of the month[/b]: a photo, a small raise, and maybe a jealous coworker.\n" % ic("heart", "#e27fa8")
	t += "%s  [b]Stress[/b] builds with work, rushes and rivals, and falls on breaks (a sofa is best), days off and near friends. Stressed people burn food and drop plates. Three nights in a row burned out and they quit. People also ask for raises and days off. Each person's card lists today's reasons, like [i]+8 closed then opened[/i] or [i]-6 the manager checked in[/i].\n\n" % ic("storm", "#e75a4e")
	t += "[font_size=16][b][color=#f2c14e]Front of house[/color][/b][/font_size]\n"
	t += "%s  A [b]host stand[/b] and someone on Host keep a waitlist, so fewer people walk past. Take [b]bookings[/b] in the Office: a table is held for them, and some don't show.\n" % ic("host")
	t += "%s  With a [b]till[/b], most people pay on the way out; others (and everyone, without a till) pay at the table, and some leave the money there for a server or busser to pick up. Slow checks mean the odd dine-and-dash.\n" % ic("money")
	t += "%s  [b]Regulars[/b] have a usual order, a favourite server, a favourite seat and a birthday. Their heart meter fills as they warm to you, and their stories unfold (the Office lists them). [b]Delivery apps[/b] bring extra orders (a driver picks them up) but take 25%%.\n" % ic("heart", "#e27fa8")
	t += "%s  Unhappy tables ask for the manager. A manager on shift sorts it out; with none, you decide.\n" % ic("alert")
	t += "%s  Families with little ones want crayons soon after sitting down, or a kid cries. A kids' menu and high chairs help. Once you're a Town favourite, build a [b]drive-in stall[/b] and servers skate out to the cars.\n" % ic("heart", "#e27fa8")
	t += "%s  The [b]Reviews[/b] tab shows what people wrote: thank them, make it right with a free pie, or argue (don't).\n\n" % ic("chat")
	t += "[font_size=16][b][color=#f2c14e]The kitchen[/color][/b][/font_size]\n"
	t += "%s  The [b]ticket rail[/b] (left, while open) shows every order being made and how long it's waited.\n" % ic("ticket")
	t += "%s  Food keeps a few days (salad and fruit 2, meat 3, frozen for weeks) and needs fridge or freezer space. What goes off is thrown out and shows as waste in the report. Run out and a dish is [b]sold out[/b].\n" % ic("supplies")
	t += "%s  Mix-ups get sent back and remade, some customers have [b]allergies[/b], and plates left on the pass go cold. You can see how well a plate was cooked: a garnish on a good one, a smear on a sloppy one.\n" % ic("plate")
	t += "%s  Coffee drinkers like a [b]refill[/b]: servers go round with the pot when the floor's calm, and refilled tables tip better.\n\n" % ic("serve")
	t += "[font_size=16][b][color=#f2c14e]Menu and money[/color][/b][/font_size]\n"
	t += "%s  [b]Combos[/b] (10%% off) on the Menu, and servers who suggest a pie or a shake. [b]Catering[/b] jobs and [b]supplier[/b] contracts are in the Office, and once you're famous you can open a [b]second diner[/b]. Switch on late nights (to 02:00) for the bar crowd.\n" % ic("van")
	t += "%s  The Menu page is your printed menu: tap − and + (or drag the price) and see what each plate makes after ingredients. Star a dish to make it [b]today's special[/b]. New recipes unlock as your reputation grows, from goals, and from your cooks.\n" % ic("menu")
	t += "%s  Pick a [b]supplier[/b] on the Supplies page: Budget is cheap, Farm fresh makes better food. The van comes every morning; sometimes it's late or short.\n" % ic("van")
	t += "%s  [b]Rent and utilities[/b] are due every 7 days. The report shows food cost (aim for about 30%%), staff cost (with California wages, about 40%%) and profit margin. Short on cash? The Office has bank loans from $5,000 to $250,000.\n" % ic("office")
	t += "%s  Tips (15 to 20%% for a good visit) go to the staff, not to you. Each table's own server keeps most of theirs, or in the Office you can have everyone share them.\n" % ic("tip")
	t += "%s  High prices keep people away; low prices bring a crowd. Good reviews bring bigger tips.\n\n" % ic("money")
	t += "[font_size=16][b][color=#f2c14e]Keeping it clean[/color][/b][/font_size]\n"
	t += "%s  With a busser or porter on shift, spills are swept as soon as they happen. Trash cans fill up: someone on Clean takes the bags to the dumpster. Overflowing bins, dirty floors and food left out bring [b]mice[/b], and customers who see one leave. Traps help.\n" % ic("mouse", "#e75a4e")
	t += "%s  Equipment wears out slowly. Someone on Repair services worn stations at closing, which keeps breakdowns rare.\n" % ic("fix")
	t += "%s  Restrooms get dirty with use; staff should wash their hands after the restroom or the trash.\n\n" % ic("wash")
	t += "[font_size=16][b][color=#f2c14e]Every day is different[/color][/b][/font_size]\n"
	t += "%s  From day 2, things happen: tour buses, power cuts, rowdy tables, celebrities, grease fires, shouting matches. Some pause the game and ask what you want to do.\n" % ic("alert")
	t += "%s  Serve people well and your [b]reputation[/b] grows (top bar): more customers, and tourists once you're a Town favourite.\n\n" % ic("star")
	t += "[font_size=16][b][color=#f2c14e]Visitors to watch for[/color][/b][/font_size]\n"
	t += "%s  A [b]food critic[/b] now and then. Their review counts five times.\n" % ic("critic", "#b58be0")
	t += "%s  The [b]health inspector[/b], unannounced, soon after you open and then two to four times a year (sooner after a reported allergic reaction): floors, the kitchen, the restroom, hand-washing, trash and mice.\n\n" % ic("inspector", "#6cc3a0")
	t += "[font_size=16][b][color=#f2c14e]Controls[/color][/b][/font_size]\n"
	t += "Right-drag, middle-drag or WASD: move.  Scroll: zoom.  R: turn.  Esc: stop building, then the menu.\n"
	t += "Space: pause.  1, 2, 3: speed.  Tab: show or hide the side panel.  V: map overlays (dirt, foot traffic, table waits, station wear).\n"
	t += "Messages drop in under the top bar; the bell keeps them all. 4: 8x speed. P: a photo for the scrapbook. Ctrl+Z: undo.\n"
	t += "The [b]Books[/b] tab charts your nights; the [b]Scrapbook[/b] keeps the big moments. Click the jukebox to change the playlist, or the kitchen radio for the station."
	return t
