# Short Order

A top-down diner management game for Godot 4.7. You start with a plot of land and $25,000, build a diner, hire a crew, set their priorities and shifts, and run it the way a real restaurant runs: prep, deliveries, bills, bookings, the health inspector and all. You never control anyone directly. It's a sandbox: there are no goals, just a crew of people from all over the world who get along (or don't) in their own way.

## Open it

1. Unzip this folder somewhere **outside OneDrive**, for example `C:\Users\you\GameDev\short_order`. This is a new version, so keep it in a new folder rather than copying it over the old one.
2. In the Godot Project Manager, click **Import**, pick `project.godot` in this folder, then **Import & Edit**.
3. Press **F5** (or the play button) to run.

The first time you open it, Godot spends a few seconds importing the fonts, icons and sounds. It may print a few red "Failed loading resource" lines about the fonts while it does; they are harmless and don't come back. If the editor's 2D view shows the interface in plain grey, use **Project > Reload Current Project** once.

Saves from earlier versions still load. Wages in an old save are turned into per-shift wages, everyone starts on a Double shift, the land is all yours, and staff hired before hometowns existed get one.

## How to play

1. **Morning:** build and plan. Time stands still until you press **Start the day**.
   - **Land:** you start on the outlined lot. **Buy land** (in Structure) buys the plots marked For sale. More land means more rent.
   - **Structure:** drag Diner floor and Kitchen floor, drag Walls around them, then click a wall facing the street for a Door. Customers stay out of the kitchen and the staff room, so the dining room needs its own door. A back door near a Dumpster saves long trips with the trash.
   - **Dining:** tables with chairs beside them, a Host stand and a Till. Chairs turn to face the table; press **R** to turn anything.
   - **Kitchen:** a grill, fryer, griddle, oven or drinks machine, fridges and freezers, a prep counter, a sink, a trash can, mouse traps, and a pass counter between the kitchen and the dining room. Click a station to upgrade it to Pro.
   - **Restroom:** its own floor, a toilet and a hand sink. Customers expect one and so does the inspector. A hand sink can also go in the kitchen, which saves staff a walk.
   - **Office** (the clipboard tab): opening hours, the staff meal, bills, tips, bank loans, bookings, delivery apps and your regulars.
   - **Menu and Supplies:** star a dish for today's special, set prices, choose how much to prep each morning, pick a supplier and set how much of each ingredient to keep.
   - Hire people in the **Staff** panel, set each person's priorities (1 is done first, 4 last, – means never) and their shift.
2. **The prep hour:** the hour before opening. Openers come in, cooks prep, the delivery van arrives and the crew can eat together. Press **Open the doors** to open early, or wait for opening time.
3. **Open:** customers come in, get greeted, order, eat, pay and leave a review. Watch the ticket rail, the rushes, and events that ask you to decide something.
4. **Closing:** the doors shut, closers sweep, restock the stations and take out the trash, and you get the day's report with your food cost, staff cost and profit margin.
5. Watch your crew in the **Crew** tab: who's friends, who can't stand whom, and a log of everything that happened. Keep an eye on stress, or people quit.

The game saves itself every morning, and **Continue your diner** on the start screen loads it.

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
| **Your numbers** | The report shows food cost, staff cost and profit margin as a share of sales. About 30% each for food and staff is healthy. |
| **Tips go to the staff** | Tips no longer go in your till. Choose whether servers keep them or share with the kitchen. |
| **Bank loans** | Borrow $5,000, $10,000 or $20,000 and pay it back over 10 weeks with your bills, plus 12%. |
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
| **A stricter inspector** | Floors and the kitchen, plus the restroom, the hand sink, hand-washing, trash, mice and reported allergic reactions. |
| **Shifts and overtime** | Each person works Opening (in for prep, home 8 hours later), Closing (the second half of the day plus closing duties) or a Double. Wages are per 8-hour shift; past 8 hours it's overtime at time and a half. |
| **Lateness and no-shows** | People sometimes run late, and now and then someone doesn't show at all (and gets a warning). Coworkers who covered for them are not impressed. |
| **Sick days** | Someone calls in sick: send them home, or ask them to come in anyway. Sick people work slower, can pass it on, and take longer to get better. |
| **Training** | Pair a beginner with someone at least 2 points better (school button on their card). Working near their trainer, they learn twice as fast. |
| **Closing duties** | Closers restock the stations, mop and take out the trash. A station nobody restocked needs setting up in the morning. Closing late and opening the next morning leaves people exhausted. |

### Also in the game

| Feature | What it does |
| --- | --- |
| Events | From day 2, one or two things happen each day: tour buses, power cuts, rowdy tables, celebrities, bad batches, grease fires, shouting matches, festivals, rainy days, staff asking for raises or days off. Many pause the game and ask you to choose. |
| Stress | Work, rushes, rivals and tiredness raise it; breaks (best on a sofa), friends nearby and quiet moments lower it. Over 75% people burn food, drop plates and slow down; two days in a row over 80% and they quit. |
| Land and reputation | Buy the west ($4,000), east ($8,000) and back ($12,000) lots. Reputation grows from Roadside diner to Famous, bringing more customers and tourists. |
| Menu | Burgers, fries, milkshakes, coffee, pancakes, omelettes, meatloaf and apple pie. Star a dish as today's special. Pricier menus bring fewer customers, cheaper ones more. Suppliers: Budget, Standard or Farm fresh. |
| Customer types | Locals, students, families, truckers, tourists, takeout, app drivers, celebrities and a rare food critic whose review counts five times. |
| The crew | Every hire has a hometown and a life story (flavour only, never a number). Coworkers form opinions of each other: friends work faster side by side, rivals bicker. Managers (+$6 a shift) keep an eye on phones and break up arguments. |
| Phones | Idle staff sneak onto their phones. Click them to catch them. |
| Skills and traits | Cooking and service improve with practice. Traits: Speedy, Tireless, Chatty, Tidy, Friendly, Grumpy, Quick learner, Clumsy, Slowpoke. |
| Breakdowns and upgrades | Stations wear out and break; someone on Repair fixes them. Pro stations cook 25% faster and wear half as fast. |
| Evening and sound | The world darkens after 18:00, lamps and neon glow, and there's sizzling, the pass bell, the till and a jukebox. |

## Controls

| Action | Control |
| --- | --- |
| Move the camera | Right-drag, middle-drag or WASD |
| Zoom | Mouse wheel |
| Turn what you're placing, or the selected piece | R |
| Stop building, or clear the selection | Esc |
| Pause / speed | Space, then 1, 2, 3 |
| Show or hide the side panel | Tab |

## Where things are

| File | What it does |
| --- | --- |
| `autoload/data.gd` | **Every number to tune:** dishes, furniture, customer types, traits, hometowns, how fast people warm up, phones, managers, rush hours, costs and timings |
| `autoload/game_state.gd` | Money, clock, rating, menu and today's special, stock and supplier, prices, land, reputation, the health grade, hiring |
| `autoload/job_board.gd` | The shared job board staff pick work from |
| `autoload/sfx.gd` | Plays sounds. Anywhere in the code: `Sfx.play("cash")` |
| `autoload/crew.gd` | **How staff get along:** opinions and their reasons, friends and rivals, chats, arguments, phones, managers, stress, mood, burnout and quitting, story moments, speech bubbles and the staff log |
| `autoload/events.gd` | **Daily events:** each one's can/start/choose functions, rain, power cuts, customers on their way |
| `autoload/stock.gd` | Ingredients by delivery date, shelf life, fridge and freezer space, waste, the morning van, prep and sold-out dishes |
| `autoload/books.gd` | Weekly rent and utilities, bank loans, tips for the staff, and the owner's numbers |
| `autoload/front.gd` | Front of house: bookings, regulars and delivery apps |
| `autoload/health.gd` | Restrooms, trash, mice, hand-washing and what the inspector looks for |
| `autoload/shifts.gd` | Opening hours and shifts, overtime, lateness, no-shows, sick days, training and closing duties |
| `world/lot.gd` | The grid, building rules, pathfinding (one grid for staff, one for customers), dirt, decor, the inspection |
| `world/build_tool.gd` | Mouse input for building and inspecting |
| `world/art.gd` | All the world drawing, done in code with simple shapes |
| `world/overlay.gd` | Order bubbles, table numbers and RSVD cards, repair wrenches, sleepy staff and the evening light |
| `world/mouse.gd` | A mouse running around the diner |
| `people/staff.gd` | How staff choose jobs, work through them, take breaks and learn |
| `people/group.gd` | A customer group's visit, from arriving to paying and reviewing, plus takeout, app orders, complaints, allergies and the inspector |
| `main.gd` | Time, the day cycle, spawning customers, saving and loading |
| `ui/` | The interface, one scene per piece (see below) |
| `sounds/` | The sound effects (WAV files) |
| `tests/autotest.gd` | Automatic tests |

## The interface

The interface is built from scenes you can open and edit in Godot, like any other scene:

| Scene | What it is |
| --- | --- |
| `ui/hud.tscn` | The whole interface. Open this first to see how the pieces fit together. |
| `ui/top_bar.tscn` | Cash, day, clock, rating, health grade, Start/Open button, speed |
| `ui/build_menu.tscn` + `build_card.tscn` | The build menu in the bottom left and its item cards |
| `ui/side_panel.tscn` | The sliding panel on the right with its icon rail |
| `ui/staff_page.tscn`, `staff_card.tscn`, `candidate_card.tscn` | Hiring and your crew, with each person's shift and training |
| `ui/menu_page.tscn` + `dish_row.tscn` | Dishes and prices |
| `ui/supplies_page.tscn` + `supply_row.tscn` | Ingredients and plates |
| `ui/crew_page.tscn` + `widgets/opinion_grid.gd` | The Crew tab: the opinion grid and the staff log |
| `ui/office_page.tscn` | The Office tab: opening hours, staff meal, bills, tips, loans, bookings, apps and regulars |
| `ui/tickets_card.gd` | The ticket rail on the left while you're open |
| `ui/checklist.tscn`, `today_card.tscn`, `inspect_card.tscn` | The cards on the left |
| `ui/report.tscn`, `start_screen.tscn`, `help.tscn`, `event_card.tscn` | Pop-ups (the event card asks you to choose) |

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

The third plays two weeks and prints how it went, which is handy after changing the numbers in `data.gd`: cash, customers served and walked out, the rating, what's costing stars, where staff time goes, and the food cost, staff cost and margin. Extra options: `--staff=6` for a bigger crew, `--shifts=odocc` to give each person a shift (o = opening, c = closing, d = double), `--apps` to switch on delivery apps, and `--starter` for a small first diner with two people and the starting money.

## Ideas for what to add next

- Your own sprites: replace a function in `world/art.gd` with `draw_texture`
- Booths, counters with stools, and bigger tables
- A weekly schedule, so you can plan days off and shifts ahead
- Seasonal menus and ingredient prices that change with the seasons
- Cheaper potatoes from your Spudstead farm
