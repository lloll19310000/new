# Short Order

A top-down diner management game for Godot 4.7. You start with a plot of land and $25,000, build a diner, hire a crew for every role from line cook to manager, and run it the way a real California restaurant runs: hourly pay, schedules, prep, deliveries, bills, bookings, the health inspector and all. You never control anyone directly. It's a sandbox: there are no goals, just a crew of people from all over the world who get along (or don't) in their own way.

## Open it

1. Unzip this folder somewhere **outside OneDrive**, for example `C:\Users\you\GameDev\short_order`. This is a new version, so keep it in a new folder rather than copying it over the old one.
2. In the Godot Project Manager, click **Import**, pick `project.godot` in this folder, then **Import & Edit**.
3. Press **F5** (or the play button) to run.

The first time you open it, Godot spends a few seconds importing the fonts, icons and sounds. It may print a few red "Failed loading resource" lines about the fonts while it does; they are harmless and don't come back. If the editor's 2D view shows the interface in plain grey, use **Project > Reload Current Project** once.

Saves from earlier versions still load: your old save becomes the first diner in **Load a diner**. Everyone in it gets the role that fits their job priorities best and California's going rate for it, the schedule takes over their shifts, the land is all yours, and staff hired before hometowns existed get one.

## How to play

1. **Morning:** build and plan. Time stands still until you press **Start the day**.
   - **Land:** you start on the outlined lot. Click a plot marked For sale to buy it from its card, or use **Buy land** in Structure. More land means more rent.
   - **Structure:** drag Diner floor and Kitchen floor, drag Walls around them, then click a wall facing the street for a Door. Customers stay out of the kitchen and the staff room, so the dining room needs its own door. A back door near a Dumpster saves long trips with the trash.
   - **Dining:** tables with chairs beside them (a single table seats one), a Host stand and a Till. Chairs turn to face the table; press **R** to turn anything.
   - **Kitchen:** a grill, fryer, griddle, oven or drinks machine, an ice machine for sodas and iced tea, fridges and freezers, a prep counter, a sink, a trash can and mouse traps. The pass counter goes in the wall between the kitchen and the dining room, so give the kitchen its own wall with a door in it for the staff. Machines turn their backs to the wall when you place them. Click a station to upgrade it to Pro.
   - **Restroom:** its own floor, a toilet and a hand sink. Customers expect one and so does the inspector. A hand sink can also go in the kitchen, which saves staff a walk.
   - **Office** (the clipboard tab): opening hours, the staff meal, bills, tips, bank loans, bookings, delivery apps and your regulars.
   - **Menu and Supplies:** star a dish for today's special, set prices, choose how much to prep each morning, pick a supplier and set how much of each ingredient to keep.
   - Hire people in the **Staff** panel's Hire tab: each one is hired for a role, which sets their pay and what they do first. The schedule gives everyone their shifts and days off.
2. **The prep hour:** the hour before opening. Openers come in, cooks prep, the delivery van arrives and the crew can eat together. Press **Open the doors** to open early, or wait for opening time.
3. **Open:** customers come in, get greeted, order, eat, pay and leave a review. Watch the ticket rail, the rushes, and events that ask you to decide something.
4. **Closing:** the doors shut, closers sweep, restock the stations and take out the trash, and you get the day's report with your food cost, staff cost and profit margin.
5. Watch your crew in the **Crew** tab: who's friends, who can't stand whom, who's stressed, and a log of everything that happened. Keep an eye on stress, or people quit.

Each diner has its own save and saves itself every morning. The main menu can continue your latest diner, start a new one or load any of them; in the game, **Esc** (or the menu button on the top bar) pauses and opens the menu to save, load, change the settings or go back to the main menu.

### New in version 6: a real crew

| Feature | What it does |
| --- | --- |
| **Roles** | Everyone is hired as a line cook, server, host, busser, dishwasher, porter or manager. The role sets what they do first (their job priorities, which you can still change) and their pay. Change someone's role from their row on the Staff page. |
| **Hourly pay, California style** | Pay is by the hour at California rates: from the $16.90 minimum for dishwashers, bussers and servers to about $26 for an experienced cook and $36 for a manager. Time and a half past 8 hours in a day, double time past 12, and at least 4 hours for anyone who comes in. |
| **Hiring** | Eight people come by every morning, covering every role; filter them by role and hire as many as you like, up to 40 staff. Post a job ad ($60) for three more people for a role. |
| **The schedule** | It writes itself every night: day, mid and night shifts so every shift has cooks and servers, and about two days off a week each (nobody works more than six in a row if someone can cover). Set a shift by hand (it's then locked) and the schedule leaves it alone. See it all in Staff > Schedule. |
| **Managers** | A manager writes a better schedule (days off for the stressed and burned out, rivals on different shifts, trainees with their trainers), sits arguing coworkers down to talk it out, checks on anyone having a rough shift and sends them on a break, handles shouting matches and unhappy tables, and makes nights calmer for everyone. |
| **Less quitting** | Stress builds more slowly, and it takes three burned-out nights in a row (not two) or three refused raises before someone quits. Days off wipe stress away. |
| **Tips** | 15% for an okay visit, up to 20% for a great one. The table's own server keeps most of it and whoever ran food shares the rest; the report lists every server's take. |
| **Money left on the table** | Some customers leave the money on the table instead of going to the till. A server or busser picks it up, and the table can't be reseated until they do. |
| **Servers pour drinks** | Coffee, milkshakes and sodas are made by servers, who take them straight to the table, so the drinks machine can go in the dining room. |
| **The ice machine** | Sodas and iced tea need one. |
| **Single tables** | A small round table for one, for truckers, regulars and critics, which keeps the big tables for groups. |
| **The pass in the wall** | The pass counter is now a hatch in the wall between the kitchen and the dining room: cooks use it from one side, servers from the other. |
| **Everything turns** | The sink, jukebox, drinks machine, oven, fridge, freezer, hand sink, ice machine, host stand and till now show which way they face, and turn with R. |
| **Fixed art** | The host stand and till are drawn (they were invisible), and the framed picture, neon EAT sign and takeout window sit properly on their walls. Food stays on the tabletop. |
| **Cleaner floors** | With a busser or porter on shift, spills are swept as soon as they happen, so you only see a really dirty floor. |
| **Fewer breakdowns** | Equipment wears out over a couple of weeks of busy use, and someone on Repair services worn stations at closing, so a looked-after kitchen rarely breaks down. |
| **Inspections** | The inspector comes soon after you open, then two to four times a year, and a few days after a customer reports an allergic reaction. |
| **Bigger loans** | From $5,000 over 10 weeks up to $250,000 over three years. |
| **Buying land** | Click a plot marked For sale and buy it from its card. |
| **Menus and saves** | A main menu (continue, new diner, load, settings, quit), a save slot for every diner, and a pause menu to save a copy or load another. |
| **A tidier interface** | The Staff page has Crew, Hire and Schedule tabs with compact rows (click one for details), the Crew tab draws who gets along as a web of lines with the trouble spelled out underneath, and the Supplies page has simple − and + buttons that don't fight you while you type. |
| **California prices** | Menu prices and ingredients cost what they would at a California diner, and bigger dining rooms draw more customers. |

### New in version 5: running a real restaurant

| Feature | What it does |
| --- | --- |
| **Opening hours** | In the Office, open for breakfast (07:00–10:00), lunch (10:00–16:00) and dinner (16:00–22:00) in any run of them. Breakfast brings egg and pancake lovers. |
| **The prep hour** | The hour before the doors open. Cooks prep dishes at the prep counter; a prepped dish cooks 40% faster later. Whatever's left at night is thrown out. Set how much to prep on the Menu page. |
| **Staff meal** | Switch it on in the Office: the crew eats together before opening ($4 a person). They start calmer and like each other a little more. |
| **Morning deliveries** | Your order comes by van each morning. Sometimes it's late, and sometimes it's short on something. |
| **Shelf life and storage** | Salad and fruit keep 2 days, meat 3, dairy 4, bread 5, eggs 10, frozen food a month. A fridge holds 240 (plus a 50-portion freezer box); a freezer holds 200. What goes off is thrown out and counted as waste. Supplies shows what goes off tonight and what you used yesterday. |
| **Sold out** | When an ingredient runs out, the dishes that need it are sold out. Customers pick something else, or leave. |
| **Weekly bills** | Rent ($350 a week for the first lot, more with more land) and utilities (more with more equipment) go out every 7 days. The top bar's cash tooltip says when. |
| **Your numbers** | The report shows food cost, staff cost and profit margin as a share of sales. About 30% for food and 40% for staff is healthy with California wages. |
| **Tips go to the staff** | Tips no longer go in your till. Choose whether servers keep them or share with the kitchen. |
| **Bank loans** | Borrow from $5,000 to $250,000 and pay it back with your weekly bills over 10 weeks to three years. |
| **Host stand and waitlist** | Someone on the new **Host** job greets people at the door and keeps a waitlist, so fewer walk past and they wait longer. |
| **Bookings** | Take bookings in the Office: a table is held for them (RSVD) and some never show. |
| **Paying** | With a till, people pay on the way out; without one a server brings the check. Slow checks annoy people, and now and then someone dines and dashes. |
| **Complaints** | Unhappy tables ask for the manager. A manager on shift goes over and sorts it out (an apology, or a free meal if it was the food). With no manager on shift, you decide. |
| **Regulars** | Named locals who come back, have a usual order and a favourite server. |
| **Delivery apps** | Switch them on for extra orders. A driver picks up at the takeout window; the app keeps 25%. |
| **Ticket rail** | While you're open, every order being made, oldest first, with how long it's waited. |
| **Kitchen trouble** | Mix-ups go back and get remade, some customers have allergies (a server who writes it down saves the day), and plates left on the pass go cold. |
| **Plates** | 40 to start. If the kitchen runs out of clean plates, washing up comes first and the game tells you. Buy more in Supplies. |
| **Restrooms** | Customers and staff use them and they get dirty; someone on Clean scrubs them. |
| **Trash and mice** | Cooking and clearing plates fill the trash cans; someone on Clean takes the bags out. Overflowing bins, dirty floors and dirty tables bring mice, and customers who see one walk out. Traps help. |
| **Hand-washing** | After the restroom or the trash, staff should wash their hands. Now and then someone skips it, and the inspector notices. |
| **A stricter inspector** | Floors and the kitchen, plus the restroom, the hand sink, hand-washing, trash, mice and reported allergic reactions. Visits two to four times a year. |
| **Shifts and overtime** | Each person works a Day shift (in for prep, home 8 hours later), a Mid shift across both rushes, a Night shift (the second half of the day plus closing duties) or a Double. Pay is by the hour, with overtime past 8 hours. |
| **Lateness and no-shows** | People sometimes run late, and now and then someone doesn't show at all (and gets a warning). Coworkers who covered for them are not impressed. |
| **Sick days** | Someone calls in sick: send them home, or ask them to come in anyway. Sick people work slower, can pass it on, and take longer to get better. |
| **Training** | Pair a beginner with someone at least 2 points better (school button on their card). Working near their trainer, they learn twice as fast. |
| **Closing duties** | Closers restock the stations, mop and take out the trash. A station nobody restocked needs setting up in the morning. Closing late and opening the next morning leaves people exhausted. |

### Also in the game

| Feature | What it does |
| --- | --- |
| Events | From day 2, one or two things happen each day: tour buses, power cuts, rowdy tables, celebrities, bad batches, grease fires, shouting matches, festivals, rainy days, staff asking for raises or days off. Many pause the game and ask you to choose. |
| Stress | Work, rushes, rivals and tiredness raise it; breaks (best on a sofa), days off, friends nearby, managers and quiet moments lower it. Over 75% people burn food, drop plates and slow down; three days in a row over 80% and they quit. |
| Land and reputation | Buy the west ($4,000), east ($8,000) and back ($12,000) lots. Reputation grows from Roadside diner to Famous, bringing more customers and tourists. |
| Menu | Burgers, fries, milkshakes, coffee, sodas, iced tea, pancakes, omelettes, meatloaf and apple pie. Star a dish as today's special. Pricier menus bring fewer customers, cheaper ones more. Suppliers: Budget, Standard or Farm fresh. |
| Customer types | Locals, students, families, truckers, tourists, takeout, app drivers, celebrities and a rare food critic whose review counts five times. |
| The crew | Every hire has a hometown and a life story (flavour only, never a number). Coworkers form opinions of each other: friends work faster side by side, rivals bicker. Managers keep an eye on phones and settle arguments. |
| Phones | Idle staff sneak onto their phones. Click them to catch them. |
| Skills and traits | Cooking and service improve with practice. Traits: Speedy, Tireless, Chatty, Tidy, Friendly, Grumpy, Quick learner, Clumsy, Slowpoke. |
| Breakdowns and upgrades | Stations wear out and can break; someone on Repair fixes them, and services worn ones at closing. Pro stations cook 25% faster and wear half as fast. |
| Evening and sound | The world darkens after 18:00, lamps and neon glow, and there's sizzling, the pass bell, the till and a jukebox. |

## Controls

| Action | Control |
| --- | --- |
| Move the camera | Right-drag, middle-drag or WASD |
| Zoom | Mouse wheel |
| Turn what you're placing, or the selected piece | R |
| Stop building, or clear the selection | Esc |
| Pause / speed | Space, then 1, 2, 3 |
| The menu: save, load, settings | Esc (after stopping building and letting go of the selection), or the menu button on the top bar |
| Show or hide the side panel | Tab |

## Where things are

| File | What it does |
| --- | --- |
| `autoload/data.gd` | **Every number to tune:** dishes, furniture, roles and pay, customer types, traits, hometowns, how fast people warm up, phones, managers, rush hours, loans, costs and timings |
| `autoload/game_state.gd` | Money, clock, rating, menu and today's special, stock and supplier, prices, land, reputation, the health grade, hiring |
| `autoload/job_board.gd` | The shared job board staff pick work from |
| `autoload/sfx.gd` | Plays sounds. Anywhere in the code: `Sfx.play("cash")` |
| `autoload/crew.gd` | **How staff get along:** opinions and their reasons, friends and rivals, chats, arguments, phones, managers, stress, mood, burnout and quitting, story moments, speech bubbles and the staff log |
| `autoload/events.gd` | **Daily events:** each one's can/start/choose functions, rain, power cuts, customers on their way |
| `autoload/stock.gd` | Ingredients by delivery date, shelf life, fridge and freezer space, waste, the morning van, prep and sold-out dishes |
| `autoload/books.gd` | Weekly rent and utilities, bank loans, tips for the staff, and the owner's numbers |
| `autoload/front.gd` | Front of house: bookings, regulars and delivery apps |
| `autoload/health.gd` | Restrooms, trash, mice, hand-washing and what the inspector looks for |
| `autoload/shifts.gd` | Opening hours, **the schedule** (shifts and days off), California overtime, lateness, no-shows, sick days, training and closing duties |
| `world/lot.gd` | The grid, building rules, pathfinding (one grid for staff, one for customers), dirt, decor, the inspection |
| `world/build_tool.gd` | Mouse input for building and inspecting |
| `world/art.gd` | All the world drawing, done in code with simple shapes |
| `world/overlay.gd` | Order bubbles, table numbers and RSVD cards, repair wrenches, sleepy staff and the evening light |
| `world/mouse.gd` | A mouse running around the diner |
| `people/staff.gd` | How staff choose jobs, work through them, take breaks and learn |
| `people/group.gd` | A customer group's visit, from arriving to paying and reviewing, plus takeout, app orders, complaints, allergies and the inspector |
| `main.gd` | Time, the day cycle, spawning customers, save slots, saving and loading |
| `ui/` | The interface, one scene per piece (see below) |
| `sounds/` | The sound effects (WAV files) |
| `tests/autotest.gd`, `tests/v6_checks.gd` | Automatic tests |
| `tests/art_preview.gd` | Draws every piece of furniture in every direction, for checking the art |

## The interface

The interface is built from scenes you can open and edit in Godot, like any other scene:

| Scene | What it is |
| --- | --- |
| `ui/hud.tscn` | The whole interface. Open this first to see how the pieces fit together. |
| `ui/top_bar.tscn` | Cash, day, clock, rating, health grade, Start/Open button, speed |
| `ui/build_menu.tscn` + `build_card.tscn` | The build menu in the bottom left and its item cards |
| `ui/side_panel.tscn` | The sliding panel on the right with its icon rail |
| `ui/staff_page.tscn` + `staff_row.gd`, `candidate_row.gd`, `widgets/schedule_board.gd` | The Staff page: your crew by role (click a row for details), hiring, and the schedule |
| `ui/menu_page.tscn` + `dish_row.tscn` | Dishes and prices |
| `ui/supplies_page.tscn` + `supply_row.tscn` | Ingredients and plates |
| `ui/crew_page.tscn` + `widgets/relation_web.gd` | The Crew tab: who gets along (the web of lines), the trouble spelled out, who's stressed, and the staff log |
| `ui/office_page.tscn` | The Office tab: opening hours, staff meal, bills, tips, loans, bookings, apps and regulars |
| `ui/tickets_card.gd` | The ticket rail on the left while you're open |
| `ui/checklist.tscn`, `today_card.tscn`, `inspect_card.tscn` | The cards on the left |
| `ui/start_screen.tscn`, `game_menu.gd`, `widgets/save_list.gd`, `widgets/settings_box.gd` | The main menu, the pause menu, the list of saves and the settings |
| `ui/report.tscn`, `help.tscn`, `event_card.tscn` | Pop-ups (the event card asks you to choose) |

Some things to try:

- **Change the look everywhere:** double-click `ui/theme.tres` to open the Theme editor. Colours, fonts, corners and spacing all live there. Named styles like `PrimaryButton`, `Card` or `HeaderLabel` are *type variations*; a node uses one through its **Theme Type Variation** property.
- **Change an icon:** the icons are SVG files in `ui/icons/`, all white so the game can tint them. Replace one with your own SVG of the same name, or point a node's Texture or Icon property at your own image.
- **Find a node from code:** nodes marked with `%` in the Scene dock have a unique name, so scripts can reach them with `%Money` no matter where they sit in the scene.
- **Signals up, calls down:** pieces like the top bar emit signals (`open_pressed`, `speed_chosen`) and `ui/hud.gd` connects them to the game. That keeps each piece independent.

The font is Poppins (SIL Open Font License, see `ui/fonts/OFL.txt`). Poppins has no Vietnamese letters like ả or ế, so a tiny cut of DejaVu Sans fills those in (see `ui/fonts/DejaVu-LICENSE.txt`).

## Running the tests

From a terminal in this folder (replace `godot` with the path to your Godot program):

```
godot --headless --path . -- --autotest
godot --path . -- --uitest
godot --headless --path . -- --balance --days=14
```

The first builds a sample diner and plays two days as fast as possible, checking that everything works: customers of every kind, takeout and delivery apps, the prep hour, deliveries, shelf life and waste, bills and loans, the host, bookings, the till, complaints and regulars, the ticket rail, sold-out dishes, mix-ups and allergies, restrooms, trash, mice and hand-washing, shifts, overtime, lateness, sick days and training, how the crew gets along, every event, and saving and loading, including old saves. The second clicks through the interface the way a player would; try it with `--resolution 1920x1080` or `--resolution 1024x768` after `--path .` to check other window sizes. Each line starting `TEST ok` passed.

The third plays two weeks and prints how it went, which is handy after changing the numbers in `data.gd`: cash, customers served and walked out, the rating, what's costing stars, where staff time goes, and the food cost, staff cost and margin (each day ends with a one-line `SUMMARY`). Extra options: `--staff=8` for a bigger crew (hired by role: cooks, servers, a busser, a dishwasher, a manager...), `--roles=cook,server,host` to pick the roles yourself, `--shifts=odocc` to give each person a shift by hand instead of the schedule (o = day, c = night, d = double), `--apps` to switch on delivery apps, and `--starter` for a small first diner with two people and the starting money.

To look at the furniture art in every direction: `godot --path . -- --art` saves `art_kitchen.png` and `art_diner.png` in the user data folder.

## Ideas for what to add next

- Your own sprites: replace a function in `world/art.gd` with `draw_texture`
- Booths, counters with stools, and bigger tables
- A week-ahead view of the schedule
- Seasonal menus and ingredient prices that change with the seasons
- Cheaper potatoes from your Spudstead farm
