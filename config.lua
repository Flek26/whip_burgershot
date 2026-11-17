Config = {}

-- Models and items come from BzZz's fastfood pack ([assets]/bzzz_fastfood). Its item keys are its model names, so an
-- item's prop and its picture (html/img/items/<key>.png, copied from the pack) share one name.
local P = 'bzzz_fastfood_burgershot_'
Config.Prefix = P

-- ============================================
-- The job
-- ============================================

Config.Job = 'burgershot'
Config.JobName = 'Burger Shot'

-- Made the first time; after that, roles are edited in /whip -> Economy -> Jobs (an edited role is never overwritten).
-- canManage lets a manager reprice the counter's shelf.
Config.Roles = {
    { name = 'Owner',   level = 100 },
    { name = 'Manager', level = 50, permissions = { canHire = true, canFire = true, canManage = true, bankAccess = 'view' } },
    { name = 'Cook',    level = 10 },
    { name = 'Trainee', level = 1 },
}

-- ============================================
-- Ingredients: the layers a burger is built from
-- ============================================
--
-- model   the layer's prop. false: no prop (a sauce: the tray shows its bottle, `trayModel`).
-- item    taken from the cook's pockets when the burger is wrapped (the patties). Without one, the tray never runs out.
-- height / offset   left out, they are read from the model's own size. Set them to fine-tune the stack.
Config.Ingredients = {
    bun_bottom  = { label = 'Bottom bun',  model = P .. 'bun_b' },
    bun_top     = { label = 'Top bun',     model = P .. 'bun_a' },
    patty       = { label = 'Patty',       model = P .. 'meat_a', item = P .. 'meat_a' },
    patty_burnt = { label = 'Burnt patty', model = P .. 'meat_c', item = P .. 'meat_c' },
    cheese      = { label = 'Cheese',      model = P .. 'cheese_a' },
    lettuce     = { label = 'Lettuce',     model = P .. 'salad_a' },
    ketchup     = { label = 'Ketchup',     model = false, trayModel = P .. 'ketchup',    height = 0.002 },
    mayo        = { label = 'Mayonnaise',  model = false, trayModel = P .. 'mayonnaise', height = 0.002 },
}

-- The trays along the back of the counter, left to right as the cook faces it. x: across (metres, + is right),
-- y: away from the cook.
Config.Trays = {
    { ingredient = 'bun_bottom',  x = -0.36, y = 0.28 },
    { ingredient = 'bun_top',     x = -0.24, y = 0.28 },
    { ingredient = 'patty',       x = -0.12, y = 0.28 },
    { ingredient = 'patty_burnt', x =  0.00, y = 0.28 },
    { ingredient = 'cheese',      x =  0.12, y = 0.28 },
    { ingredient = 'lettuce',     x =  0.24, y = 0.28 },
    { ingredient = 'ketchup',     x =  0.36, y = 0.24 },
    { ingredient = 'mayo',        x =  0.36, y = 0.36 },
}

-- The wrapper the burger is built on: where it lies (same frame as the trays) and its prop.
Config.Wrapper = { x = 0.0, y = 0.02, model = P .. 'tray_b' }

Config.MaxLayers = 12

-- ============================================
-- Recipes: an exact stack, bottom to top. Each makes the pack's item of that key.
-- ============================================
--
-- A stack that matches none is still a burger ('bs_burger_custom', "Burger"), as long as it has a bun at each end.
Config.Recipes = {
    [P .. 'cheeseburger_a'] = {
        name = 'Cheeseburger',
        layers = { 'bun_bottom', 'ketchup', 'patty', 'cheese', 'bun_top' },
    },
    [P .. 'bigburger_a'] = {
        name = 'Bigburger',
        layers = { 'bun_bottom', 'mayo', 'lettuce', 'patty', 'cheese', 'patty', 'cheese', 'bun_top' },
    },
}

-- A burnt patty makes the burger burnt: this much as filling.
Config.BurntFactor = 0.5

Config.WrapTime = 2500   -- ms

-- ============================================
-- Stations
-- ============================================
--
-- Placed in game with /bsplace <kind> (whip.devtools, developer mode on), saved in the database. ghost: the prop the
-- placer shows while you aim. reach: metres to use it.
--
-- sign: the prompt is a flat sign facing the cook (whip's sign prompt: read from the front, hidden from behind), not a
-- label that turns to face you. The cook stands at the ghost's back as you place it (the placer starts it facing
-- away from you; turn it with the wheel), and the sign stands `up` metres over the point, `out` metres toward the
-- cook. tilt: degrees it leans back, 90 lying flat face up (on the grill, over the food), read with its top away from
-- the cook. The placer shows where it will be. sign = false: a label that faces the player, as before.
Config.Stations = {
    fridge   = { label = 'Fridge',          ghost = P .. 'box_f',      reach = 1.8, sign = { up = 0.25, out = 0.0 } },
    grill    = { label = 'Grill',           ghost = P .. 'meat_b',     reach = 1.8, sign = false },
    fryer    = { label = 'Fryer',           ghost = P .. 'fries_c',    reach = 1.8, sign = false },
    drinks   = { label = 'Drinks machine',  ghost = P .. 'drink_a',    reach = 1.6, sign = { up = 0.30, out = 0.10 } },
    assembly = { label = 'Prep counter',    ghost = P .. 'tray_b',     reach = 1.6, sign = { up = 0.02, out = 0.0, tilt = 90 } },
    bagging  = { label = 'Packing',         ghost = P .. 'box_a',      reach = 1.6, sign = { up = 0.02, out = 0.0, tilt = 90 } },
    -- The register is the counter's shelf (its tray; staff open it there). Its sign stands toward the staff, off the
    -- tray's own prompt.
    register = { label = 'Counter',         ghost = P .. 'tray_a',     reach = 2.0, sign = { up = 0.25, out = 0.35 } },
    -- Where the cashier (the shop's keeper, whom customers buy from) stands: /bsplace cashier places it where YOU stand,
    -- facing the way you face. No prompt of its own (the shop puts one on the keeper).
    cashier  = { label = 'Cashier',         ghost = P .. 'tray_a',     reach = 2.0, sign = false, standHere = true },
    duty     = { label = 'Time clock',      ghost = P .. 'menu_a',     reach = 1.6, sign = { up = 0.20, out = 0.05 } },
}
-- A fridge spot of one food (/bsplace fridge patty): its sign lies flat on top of the food, `above` metres over the
-- food's own top (read from its model, so a tall box of fries and a flat patty both get it on top).
Config.FridgeItemSign = { above = 0.02, out = 0.0, tilt = 90 }

-- The animation for each thing done at a station, played through whip's bar (Progress: the server times it, and
-- walking off cancels it). time: ms. A bar with no anim still runs, without one.
Config.Anims = {
    fridge = { time = 1200, anim = { dict = 'anim@gangops@facility@servers@bodysearch@', clip = 'player_search' } },
    grill  = { time = 1500, anim = { dict = 'amb@prop_human_bbq@male@idle_a', clip = 'idle_b' } },
    fryer  = { time = 1500, anim = { dict = 'amb@prop_human_bbq@male@idle_a', clip = 'idle_b' } },
    pour   = { anim = { dict = 'mini@sprunk', clip = 'plyr_buy_drink_pt1' } },
    wrap   = { anim = { dict = 'anim@amb@business@coc@coc_unpack_cut@', clip = 'fullcut_cycle_v6_cokecutter' } },
    pack   = { anim = { dict = 'anim@amb@business@coc@coc_unpack_cut@', clip = 'fullcut_cycle_v6_cokecutter' } },
}

Config.PlaceReach = 10.0

-- The fridge hands these out, one per press.
--
-- Each can have a spot of its own: /bsplace fridge <id> (/bsplace fridge patty) puts down a spot that hands out only
-- that, with its `model` sitting there for everyone to see, so each shelf of a real fridge holds its own food.
-- /bsplace fridge on its own is one spot with the whole list (and no prop).
--   lift: metres to raise the prop off the shelf.
Config.Fridge = {
    { id = 'patty',    item = P .. 'meat_b',       label = 'Raw patty',          model = P .. 'meat_b' },
    { id = 'fries',    item = 'bs_frozen_fries',   label = 'Frozen fries',       model = P .. 'fries_c' },
    { id = 'nuggets',  item = 'bs_frozen_nuggets', label = 'Frozen nuggets',     model = P .. 'nugget_a' },
    { id = 'onion',    item = 'bs_frozen_onion',   label = 'Frozen onion rings', model = P .. 'onion_a' },
    { id = 'chicken',  item = 'bs_raw_chicken',    label = 'Raw chicken',        model = P .. 'chicken_b' },
    { id = 'salad',    item = P .. 'vegesalad_a',  label = 'Vegetarian salad',   model = P .. 'vegesalad_a' },
    { id = 'noodles',  item = P .. 'noodle_a',     label = 'Chinese noodles',    model = P .. 'noodle_a' },
}
Config.FridgeById = {}
for _, f in ipairs(Config.Fridge) do Config.FridgeById[f.id] = f end

-- The grill: a raw patty goes on, turns cooked after `cook` ms and burnt after `burn`. The prop on the plate changes
-- with it (rawModel, doneModel, burntModel), drawn for everyone (ShowPropSet). slots: as many as fit on the plate (one
-- more is refused); laid out `columns` across, `spacing` metres apart, centred on the station's point.
Config.Grill = {
    slots = 1, columns = 1, spacing = 0.24, lift = 0.0, cook = 20000, burn = 45000,
    raw = P .. 'meat_b', done = P .. 'meat_a', burnt = P .. 'meat_c',
    rawModel = P .. 'meat_b', doneModel = P .. 'meat_a', burntModel = P .. 'meat_c',
}

-- The fryer: one basket per slot, each frying one product. raw: the item (and how many) it takes. done: what comes out
-- (left too long it is burnt: the same item, marked Burnt and half as filling). model: what floats in the basket.
Config.Fryer = {
    slots = 1, columns = 1, spacing = 0.30, lift = 0.0, cook = 15000, burn = 40000,
    products = {
        { id = 'fries_s', label = 'Small fries',     raw = 'bs_frozen_fries', count = 1, done = P .. 'fries_a',  model = P .. 'fries_c' },
        { id = 'fries_m', label = 'Medium fries',    raw = 'bs_frozen_fries', count = 2, done = P .. 'fries_b',  model = P .. 'fries_c' },
        { id = 'fries_l', label = 'Bucket of fries', raw = 'bs_frozen_fries', count = 3, done = P .. 'fries_d',  model = P .. 'fries_c' },
        { id = 'nuggets', label = 'Chicken nuggets', raw = 'bs_frozen_nuggets', count = 1, done = P .. 'nugget_b', model = P .. 'nugget_a' },
        { id = 'onion',   label = 'Onion rings',     raw = 'bs_frozen_onion', count = 1, done = P .. 'onion_b',  model = P .. 'onion_a' },
        { id = 'strips',  label = 'Chicken strips',  raw = 'bs_raw_chicken',  count = 1, done = P .. 'chicken_e', model = P .. 'chicken_b' },
        { id = 'legs',    label = 'Chicken legs',    raw = 'bs_raw_chicken',  count = 1, done = P .. 'chicken_d', model = P .. 'chicken_a' },
        { id = 'bites',   label = 'Chicken bites',   raw = 'bs_raw_chicken',  count = 1, done = P .. 'chicken_f', model = P .. 'chicken_c' },
    },
}

-- The drinks machine: drinks and ice cream, one per pour.
Config.Drinks = {
    { item = P .. 'drink_a',    label = 'Big drink' },
    { item = P .. 'drink_b',    label = 'Small drink' },
    { item = P .. 'icecream_a', label = 'Chocolate-vanilla ice cream' },
    { item = P .. 'icecream_b', label = 'Raspberry-moon ice cream' },
}
Config.PourTime = 3000
-- While pouring, the drink (its own prop) stands under the nozzle: the drinks machine's point, raised this much.
Config.PourCupLift = 0.0

-- Packing: put a burger in its box, make a meal, or pack a takeaway box of anything.
Config.Boxes = {
    { from = P .. 'cheeseburger_a', to = P .. 'cheeseburger_b' },
    { from = P .. 'bigburger_a',    to = P .. 'bigburger_b' },
}
-- A meal: one of each `needs` line (any item of the line), packed into the pack's menu item. Opened, it gives them back.
Config.Meals = {
    { item = P .. 'menu_a', needs = { { P .. 'cheeseburger_a', P .. 'bigburger_a', 'bs_burger_custom' }, { P .. 'fries_a', P .. 'fries_b' } } },
    { item = P .. 'menu_b', needs = { { P .. 'nugget_b' },  { P .. 'fries_a', P .. 'fries_b' } } },
    { item = P .. 'menu_c', needs = { { P .. 'chicken_d' }, { P .. 'fries_a', P .. 'fries_b' } } },
    { item = P .. 'menu_d', needs = { { P .. 'chicken_e' }, { P .. 'fries_a', P .. 'fries_b' } } },
}
Config.PackTime = 2000
Config.BagMax = 6   -- a takeaway box holds this many

-- The counter: a stocked whip shop whose shelf is a container. Staff put food on it from the packing station or the
-- register; a customer buys from the cashier, and the money goes to the job's business account (once it has an
-- owner). prices: what each sells for the first time it goes on the shelf (a manager can change it there after).
Config.Counter = {
    shopName = 'Burger Shot',
    npcModel = 'csb_burgerdrug',
    -- The shelf's prop at the register (staff open it there). whip sets a stash's prop on the surface under it and puts
    -- its prompt on the prop's box, so a tall prop keeps the prompt up off the counter: a flat tray had it lying in the
    -- tray. Any model works (the pack's tray: P .. 'tray_a').
    shelfProp = P .. 'box_a',
    slots = 40, maxWeight = 100.0,
    blipSprite = 106, blipColor = 1,
    prices = {
        [P .. 'cheeseburger_a'] = 15, [P .. 'cheeseburger_b'] = 16, [P .. 'bigburger_a'] = 22, [P .. 'bigburger_b'] = 23,
        bs_burger_custom = 12,
        [P .. 'fries_a'] = 4, [P .. 'fries_b'] = 6, [P .. 'fries_d'] = 10,
        [P .. 'nugget_b'] = 9, [P .. 'onion_b'] = 7, [P .. 'chicken_d'] = 12, [P .. 'chicken_e'] = 11, [P .. 'chicken_f'] = 10,
        [P .. 'drink_a'] = 5, [P .. 'drink_b'] = 3, [P .. 'icecream_a'] = 5, [P .. 'icecream_b'] = 5,
        [P .. 'noodle_a'] = 12, [P .. 'vegesalad_a'] = 10,
        [P .. 'menu_a'] = 20, [P .. 'menu_b'] = 14, [P .. 'menu_c'] = 16, [P .. 'menu_d'] = 15,
        bs_bag = 40,
    },
}

-- ============================================
-- Smoke and sound
-- ============================================

-- Particles over each piece of food on a grill or fryer (GTA's own effects). Each state is a list of layers, all
-- drawn at once over every piece: a few thin wisps spread across it, and a slow haze. One GTA effect alone is a
-- single fast column, so the look comes from mixing them.
--   asset/name  the effect           scale  size            alpha  0 (invisible) to 1
--   lift        metres above the food  count  how many of it per piece, spread `spread` metres apart
--   colour      { r, g, b } 0..1: forces a tint (white steam from an effect that is grey or yellow)
-- Try others live with /bssmoke (admins): /bssmoke core ent_amb_steam 0.05 0.3
-- Per station kind (grill, fryer), then per state (cooking, burnt).
local BURNT = {
    { asset = 'core', name = 'ent_amb_smoke_foundry', scale = 0.05, alpha = 0.55, lift = 0.02, count = 2, spread = 0.04 },
    { asset = 'core', name = 'exp_grd_bzgas_smoke',   scale = 0.15, alpha = 0.25, lift = 0.02, colour = { 0.25, 0.25, 0.25 } },
}
Config.Smoke = {
    grill = {
        cooking = {
            -- The soft cloud off the meat.
            { asset = 'core', name = 'exp_grd_bzgas_smoke', scale = 0.15, alpha = 0.12, lift = 0.02 },
            -- A tiny vent steam in the middle, hardly seen: it brings GTA's steam hiss with it.
            { asset = 'core', name = 'ent_amb_steam',       scale = 0.01, alpha = 0.08, lift = 0.02 },
        },
        burnt = BURNT,
    },
    fryer = {
        cooking = {
            -- Steam off the whole basket.
            { asset = 'core', name = 'ent_amb_steam', scale = 0.03, alpha = 0.2, lift = 0.02, count = 8, spread = 0.09 },
        },
        burnt = BURNT,
    },
    range = 25.0,   -- metres: drawn only for players this near
}

-- Sounds, played by each nearby game's own page (html/index.html), louder the nearer. Put the files in html/sounds/:
-- the pack has none, and GTA has no sizzle. A missing file is silent. loop: plays while the station is busy.
Config.Sounds = {
    grill = { file = 'sizzle.ogg', volume = 0.35, range = 12.0, loop = true },
    fryer = { file = 'fryer.ogg',  volume = 0.30, range = 12.0, loop = true },
    pour  = { file = 'pour.ogg',   volume = 0.60, range = 8.0 },
    wrap  = { file = 'wrap.ogg',   volume = 0.50, range = 6.0 },
}

-- ============================================
-- Items
-- ============================================
--
-- Every model of the pack's Burger Shot set is an item, with the pack's picture. Below: what each does.
-- hunger / thirst: what eating or drinking one gives (0-100). use: the animation and props while eating (the pack's own
-- two-handed animations for boxes, from its ox_inventory code). opens: using it hands these back instead (a box, a meal).

local ONE_HAND_EAT = { dict = 'mp_player_inteat@burger', clip = 'mp_player_int_eat_burger' }
local DRINK = { dict = 'mp_player_intdrink', clip = 'loop_bottle' }
local TWO_HAND = { dict = 'bzzz_burgershot_anim2', clip = 'anim2' }
local FRIES = { dict = 'bzzz_burgershot_anim1', clip = 'anim1' }

local function one(model, pos, rot, bone)
    return { { model = model, bone = bone or 18905, offset = pos, rot = rot } }
end
local function two(a, apos, arot, b, bpos, brot)
    return { { model = a, bone = 60309, offset = apos, rot = arot }, { model = b, bone = 28422, offset = bpos, rot = brot } }
end

Config.Items = {
    -- ---- what is cooked and built with ----
    [P .. 'meat_b']   = { name = 'Raw patty',     desc = 'Needs the grill.',          weight = 0.15 },
    [P .. 'meat_a']   = { name = 'Cooked patty',  desc = 'Ready for a bun.',          weight = 0.15 },
    [P .. 'meat_c']   = { name = 'Burnt patty',   desc = 'Left on the grill too long.', weight = 0.15 },
    [P .. 'bun_a']    = { name = 'Top bun',       desc = 'Burger top bun.',           weight = 0.05 },
    [P .. 'bun_b']    = { name = 'Bottom bun',    desc = 'Burger bun bottom.',        weight = 0.05 },
    [P .. 'bun_c']    = { name = 'Bun',           desc = 'A burger bun.',             weight = 0.08 },
    [P .. 'cheese_a'] = { name = 'Cheese',        desc = 'A slice of cheese.',        weight = 0.02 },
    [P .. 'salad_a']  = { name = 'Salad leaf',    desc = 'Crisp lettuce.',            weight = 0.02 },
    [P .. 'ketchup']  = { name = 'Ketchup',       desc = 'A squeeze bottle.',         weight = 0.3 },
    [P .. 'mayonnaise'] = { name = 'Mayonnaise',  desc = 'A squeeze bottle.',         weight = 0.3 },
    bs_frozen_fries   = { name = 'Frozen fries',  desc = 'Needs the fryer.',          weight = 0.2,  image = P .. 'fries_c' },
    bs_frozen_nuggets = { name = 'Frozen nuggets', desc = 'Needs the fryer.',         weight = 0.2,  image = P .. 'nugget_a' },
    bs_frozen_onion   = { name = 'Frozen onion rings', desc = 'Needs the fryer.',     weight = 0.2,  image = P .. 'onion_a' },
    bs_raw_chicken    = { name = 'Raw chicken',   desc = 'Needs the fryer.',          weight = 0.25, image = P .. 'chicken_b' },

    -- ---- burgers ----
    [P .. 'cheeseburger_a'] = { name = 'Cheeseburger', desc = 'A Burger Shot classic.', weight = 0.3, hunger = 35,
        use = { anim = ONE_HAND_EAT, props = one(P .. 'cheeseburger_a', { -0.01, 0.0, -0.02 }, { 31.0, 15.0, 0.0 }) } },
    [P .. 'bigburger_a'] = { name = 'Bigburger', desc = 'Two patties. Two slices.', weight = 0.4, hunger = 55,
        use = { anim = ONE_HAND_EAT, props = one(P .. 'bigburger_a', { -0.01, 0.0, -0.02 }, { 31.0, 15.0, 0.0 }) } },
    bs_burger_custom = { name = 'Burger', desc = 'Built your way.', weight = 0.3, hunger = 30, image = P .. 'cheeseburger_a',
        use = { anim = ONE_HAND_EAT, props = one(P .. 'cheeseburger_a', { -0.01, 0.0, -0.02 }, { 31.0, 15.0, 0.0 }) } },
    [P .. 'cheeseburger_b'] = { name = 'Cheeseburger in box', desc = 'Open it to eat.', weight = 0.35, opens = { P .. 'cheeseburger_a' } },
    [P .. 'bigburger_b']    = { name = 'Bigburger in box',    desc = 'Open it to eat.', weight = 0.45, opens = { P .. 'bigburger_a' } },

    -- ---- fried ----
    [P .. 'fries_a'] = { name = 'Small fries',  desc = 'Hot and salty.', weight = 0.15, hunger = 15,
        use = { anim = FRIES, props = two(P .. 'fries_a', { 0.09, 0.04, 0.05 }, { -80.0, 50.0, 0.0 }, P .. 'fries_c', { 0.07, 0.04, -0.03 }, { -100.0, -40.0, -30.0 }) } },
    [P .. 'fries_b'] = { name = 'Medium fries', desc = 'Hot and salty.', weight = 0.2, hunger = 22,
        use = { anim = FRIES, props = two(P .. 'fries_b', { 0.09, 0.04, 0.05 }, { -80.0, 50.0, 0.0 }, P .. 'fries_c', { 0.07, 0.04, -0.03 }, { -100.0, -40.0, -30.0 }) } },
    [P .. 'fries_d'] = { name = 'Bucket of fries', desc = 'For sharing. Or not.', weight = 0.35, hunger = 35,
        use = { anim = TWO_HAND, props = two(P .. 'fries_d', { 0.12, 0.06, 0.08 }, { 30.0, 35.0, 134.0 }, P .. 'fries_c', { 0.06, 0.05, -0.04 }, { 13.0, 50.0, 124.0 }) } },
    [P .. 'fries_c'] = { name = 'Fry', desc = 'Just the one.', weight = 0.01, hunger = 1,
        use = { anim = ONE_HAND_EAT, props = one(P .. 'fries_c', { -0.02, 0.0, -0.01 }, { 41.0, 35.0, -70.0 }) } },
    [P .. 'nugget_b'] = { name = 'Chicken nuggets', desc = 'A box of nuggets.', weight = 0.2, hunger = 25,
        use = { anim = TWO_HAND, props = two(P .. 'nugget_b', { 0.15, 0.02, 0.02 }, { 30.0, 35.0, 134.0 }, P .. 'nugget_a', { 0.08, 0.05, -0.04 }, { 13.0, 50.0, 124.0 }) } },
    [P .. 'nugget_a'] = { name = 'Chicken nugget', desc = 'Just the one.', weight = 0.02, hunger = 4,
        use = { anim = ONE_HAND_EAT, props = one(P .. 'nugget_a', { -0.04, 0.01, -0.01 }, { 1.0, 45.0, -85.0 }) } },
    [P .. 'onion_b'] = { name = 'Onion rings', desc = 'A box of onion rings.', weight = 0.2, hunger = 20,
        use = { anim = TWO_HAND, props = two(P .. 'onion_b', { 0.16, 0.02, 0.02 }, { 30.0, 35.0, 134.0 }, P .. 'onion_a', { 0.08, 0.06, -0.05 }, { 13.0, 50.0, 124.0 }) } },
    [P .. 'onion_a'] = { name = 'Onion ring', desc = 'Just the one.', weight = 0.02, hunger = 3,
        use = { anim = ONE_HAND_EAT, props = one(P .. 'onion_a', { -0.04, 0.01, -0.01 }, { 1.0, 45.0, -85.0 }) } },
    [P .. 'chicken_d'] = { name = 'Chicken legs', desc = 'A box of chicken legs.', weight = 0.3, hunger = 35,
        use = { anim = TWO_HAND, props = two(P .. 'chicken_d', { 0.09, 0.02, 0.04 }, { 30.0, 35.0, 134.0 }, P .. 'chicken_a', { 0.08, 0.04, -0.03 }, { 13.0, 37.0, 124.0 }) } },
    [P .. 'chicken_e'] = { name = 'Chicken strips', desc = 'A box of chicken strips.', weight = 0.25, hunger = 30,
        use = { anim = TWO_HAND, props = two(P .. 'chicken_e', { 0.09, 0.02, 0.04 }, { 30.0, 35.0, 134.0 }, P .. 'chicken_b', { 0.09, 0.05, -0.04 }, { 13.0, 37.0, 124.0 }) } },
    [P .. 'chicken_f'] = { name = 'Chicken bites', desc = 'A box of chicken bites.', weight = 0.25, hunger = 28,
        use = { anim = TWO_HAND, props = two(P .. 'chicken_f', { 0.09, 0.02, 0.04 }, { 30.0, 35.0, 134.0 }, P .. 'chicken_c', { 0.09, 0.05, -0.04 }, { 13.0, 37.0, 124.0 }) } },
    [P .. 'chicken_a'] = { name = 'Chicken leg', desc = 'Just the one.', weight = 0.08, hunger = 10,
        use = { anim = ONE_HAND_EAT, props = one(P .. 'chicken_a', { -0.02, 0.0, -0.01 }, { 41.0, 35.0, -70.0 }) } },
    [P .. 'chicken_b'] = { name = 'Chicken strip', desc = 'Just the one.', weight = 0.06, hunger = 8,
        use = { anim = ONE_HAND_EAT, props = one(P .. 'chicken_b', { -0.02, 0.0, -0.01 }, { 41.0, 35.0, -70.0 }) } },
    [P .. 'chicken_c'] = { name = 'Chicken bit', desc = 'Just the one.', weight = 0.03, hunger = 5,
        use = { anim = ONE_HAND_EAT, props = one(P .. 'chicken_c', { -0.02, 0.0, -0.01 }, { 41.0, 35.0, -70.0 }) } },

    -- ---- cold ----
    [P .. 'noodle_a'] = { name = 'Chinese noodles', desc = 'With chopsticks.', weight = 0.3, hunger = 40,
        use = { anim = TWO_HAND, props = two(P .. 'noodle_a', { 0.08, 0.05, 0.08 }, { -40.0, -10.0, -30.0 }, P .. 'noodle_b', { 0.06, 0.05, 0.0 }, { -94.0, -10.0, -30.0 }) } },
    [P .. 'vegesalad_a'] = { name = 'Vegetarian salad', desc = 'Fresh and green.', weight = 0.25, hunger = 25,
        use = { anim = TWO_HAND, props = two(P .. 'vegesalad_a', { 0.11, -0.01, 0.05 }, { -30.0, 10.0, 0.0 }, P .. 'vegesalad_b', { 0.07, 0.04, -0.03 }, { -100.0, -40.0, -30.0 }) } },

    -- ---- drinks and dessert ----
    [P .. 'drink_a'] = { name = 'Big drink',   desc = 'Ice cold.', weight = 0.5, thirst = 40,
        use = { anim = DRINK, props = one(P .. 'drink_a', { 0.02, 0.0, -0.01 }, { 0.0, 0.0, 0.0 }) } },
    [P .. 'drink_b'] = { name = 'Small drink', desc = 'Ice cold.', weight = 0.3, thirst = 25,
        use = { anim = DRINK, props = one(P .. 'drink_b', { 0.02, 0.0, 0.01 }, { 0.0, 0.0, 0.0 }) } },
    [P .. 'icecream_a'] = { name = 'Chocolate-vanilla ice cream', desc = 'Two flavours.', weight = 0.2, hunger = 10, thirst = 10,
        use = { anim = ONE_HAND_EAT, props = one(P .. 'icecream_a', { -0.02, 0.0, -0.01 }, { 1.0, -85.0, 10.0 }) } },
    [P .. 'icecream_b'] = { name = 'Raspberry-moon ice cream', desc = 'Out of this world.', weight = 0.2, hunger = 10, thirst = 10,
        use = { anim = ONE_HAND_EAT, props = one(P .. 'icecream_b', { -0.02, 0.0, -0.01 }, { 1.0, -85.0, 10.0 }) } },

    -- ---- meals (opened, they give back what was packed) ----
    [P .. 'menu_a'] = { name = 'Burger and fries',        desc = 'Open it to eat.', weight = 0.6, meal = true },
    [P .. 'menu_b'] = { name = 'Nuggets and fries',       desc = 'Open it to eat.', weight = 0.5, meal = true },
    [P .. 'menu_c'] = { name = 'Chicken legs and fries',  desc = 'Open it to eat.', weight = 0.6, meal = true },
    [P .. 'menu_d'] = { name = 'Strips and fries',        desc = 'Open it to eat.', weight = 0.5, meal = true },
    bs_bag = { name = 'Takeaway box', desc = 'A takeaway order. Open it.', weight = 0.1, stack = false, meal = true, image = P .. 'box_f' },

    -- ---- packaging and the rest of the set ----
    [P .. 'box_a'] = { name = 'Closed burger box',    desc = 'Packaging.', weight = 0.05 },
    [P .. 'box_b'] = { name = 'Open burger box',      desc = 'Packaging.', weight = 0.05 },
    [P .. 'box_c'] = { name = 'Small box for fries',  desc = 'Packaging.', weight = 0.03 },
    [P .. 'box_d'] = { name = 'Medium box for fries', desc = 'Packaging.', weight = 0.04 },
    [P .. 'box_e'] = { name = 'Bucket for fries',     desc = 'Packaging.', weight = 0.05 },
    [P .. 'box_f'] = { name = 'Closed big box',       desc = 'Packaging.', weight = 0.06 },
    [P .. 'box_g'] = { name = 'Chinese noodle box',   desc = 'Packaging.', weight = 0.04 },
    [P .. 'noodle_b'] = { name = 'Chopsticks',        desc = 'For noodles.', weight = 0.01 },
    [P .. 'vegesalad_b'] = { name = 'Fork with cucumber', desc = 'For the salad.', weight = 0.02 },
    [P .. 'tray_a'] = { name = 'Clean tray',          desc = 'A Burger Shot tray.', weight = 0.3 },
    [P .. 'tray_b'] = { name = 'Empty tray',          desc = 'A Burger Shot tray.', weight = 0.3 },
    [P .. 'tray_c'] = { name = 'Tray with food',      desc = 'A Burger Shot tray.', weight = 0.8 },
}

Config.EatTime = 5000
Config.DrinkTime = 4000
