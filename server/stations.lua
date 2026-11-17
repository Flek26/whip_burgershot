-- ============================================
-- whip_burgershot — server: the stations
-- ============================================
--
-- WHERE THEY ARE: placed in game (/bsplace <kind>, whip's PlaceObject on the admin's game), checked here, kept in a
-- table of our own, and sent to every game, which puts a prompt at each (client/stations.lua).
--
-- WHAT THEY DO: every station event is a SecureEvent whose `near` is that station's own spot, and checks duty itself
-- (the client's `require` only decides what is offered). Anything handed out at the end of a bar uses the server's
-- Progress, so a modified game can't skip it.
--
-- WHAT IS COOKING is sent to every game as it changes (whip_burgershot:cook): each game draws the food on the plate
-- from it, with the smoke, the sizzle and the countdown on the prompt (client/effects.lua).

local JOB = Config.Job

Stations = {}                  -- [id] = { id, kind, x, y, z, heading }

-- [kind][stationId] = { [slot] = { startedAt, product? } }
local cooking = { grill = {}, fryer = {} }
local bags = {}                -- [source] = { charId, items = { { item, metadata, label } } }

local PRODUCTS = {}            -- [id] = a Config.Fryer.products entry
for _, p in ipairs(Config.Fryer.products) do PRODUCTS[p.id] = p end

-- ============================================
-- Storage
-- ============================================

local TABLE = 'whip_burgershot_stations'

local function loadStations()
    local ok, rows = pcall(MySQL.query.await, ('SELECT * FROM `%s`'):format(TABLE), {})
    if not ok then
        Whip.startProblem('could not read the stations: %s', tostring(rows))
        return
    end
    Stations = {}
    for _, r in ipairs(rows or {}) do
        if Config.Stations[r.kind] then
            -- item: a fridge spot that hands out one thing (a Config.Fridge id), or nil for the whole list.
            local item = r.item and Config.FridgeById[r.item] and r.item or nil
            Stations[r.id] = { id = r.id, kind = r.kind, x = r.x, y = r.y, z = r.z, heading = r.heading, item = item }
        end
    end
end

--- Every station, as a list for the wire.
local function stationList()
    local out = {}
    for _, st in pairs(Stations) do out[#out + 1] = st end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

local function syncAll()
    TriggerClientEvent('whip_burgershot:stations', -1, stationList())
end

--- The first register (lowest id) is the counter.
local function counterStation()
    local best
    for _, st in pairs(Stations) do
        if st.kind == 'register' and (not best or st.id < best.id) then best = st end
    end
    return best
end

--- The first cashier (lowest id): where the shop's keeper stands, apart from the shelf. nil: none placed.
local function cashierStation()
    local best
    for _, st in pairs(Stations) do
        if st.kind == 'cashier' and (not best or st.id < best.id) then best = st end
    end
    return best
end

--- Set the counter up (again) from the register and the cashier: the shelf at the register, the shop and its keeper
--- at the cashier. Follows a moved or removed one (EnsureShop follows a changed declaration).
---@return boolean ok, string|nil why
local function setupCounter()
    local reg = counterStation()
    if not reg then return false, 'There is no counter yet: an admin places one with /bsplace register' end
    local ok, why = Counter.ensure(reg, cashierStation())
    if not ok then print(('[whip_burgershot] the counter could not be set up: %s'):format(tostring(why))) end
    return ok, why
end

--- Save a placed station and tell everyone. Answers its id, or nil and why.
local function saveStation(kind, x, y, z, heading, item)
    local ok, id = pcall(MySQL.insert.await,
        ('INSERT INTO `%s` (`kind`, `x`, `y`, `z`, `heading`, `item`) VALUES (?, ?, ?, ?, ?, ?)'):format(TABLE),
        { kind, x, y, z, heading % 360.0, item })
    if not ok or not id then return nil, 'Could not save it' end
    Stations[id] = { id = id, kind = kind, x = x, y = y, z = z, heading = heading % 360.0, item = item }
    syncAll()
    return id
end

local function itemLabel(key)
    return Config.Items[key] and Config.Items[key].name or key
end

-- ============================================
-- Grill and fryer
-- ============================================

local function cfgOf(kind) return kind == 'grill' and Config.Grill or Config.Fryer end

local fillOrder = Grid.fillOrder   -- shared/grid.lua: the same grid each game draws the food on

--- What a slot holds now: 'cooking', 'done' or 'burnt'.
local function doneness(cfg, startedAt)
    local t = GetGameTimer() - startedAt
    if t >= cfg.burn then return 'burnt' end
    if t >= cfg.cook then return 'done' end
    return 'cooking'
end

--- The prop for a slot: the grill's patty changes as it cooks; a fryer basket shows its product.
local function slotModel(kind, slot)
    if kind == 'fryer' then return PRODUCTS[slot.product] and PRODUCTS[slot.product].model end
    local s = doneness(Config.Grill, slot.startedAt)
    return (s == 'burnt' and Config.Grill.burntModel) or (s == 'done' and Config.Grill.doneModel) or Config.Grill.rawModel
end

--- What is on one station, for every game: { kind, free, slots = { { n, model, state, cookLeft, burnLeft, label } } }.
--- Each game draws the food from it (client/effects.lua), with the smoke, the sound and the prompt's countdown.
local function cookState(kind, stationId)
    local cfg = cfgOf(kind)
    local list = {}
    for n, slot in pairs(cooking[kind][stationId] or {}) do
        local t = GetGameTimer() - slot.startedAt
        list[#list + 1] = {
            n = n, model = slotModel(kind, slot),
            state = doneness(cfg, slot.startedAt),
            cookLeft = math.max(0, cfg.cook - t), burnLeft = math.max(0, cfg.burn - t),
            label = kind == 'fryer' and PRODUCTS[slot.product] and PRODUCTS[slot.product].label or nil,
        }
    end
    return { kind = kind, slots = list, free = cfg.slots - #list }
end

--- Tell every game what is on it now: each draws the food, the smoke and the countdown (client/effects.lua).
--- Drawn by each game rather than as a prop set, so the food's shape can be centred on its slot (a pack model's
--- origin is not always its middle) and set down on the plate by its bottom.
local function refresh(kind, stationId)
    TriggerClientEvent('whip_burgershot:cook', -1, stationId, cookState(kind, stationId))
end

--- When a slot turns done, and turns burnt, draw it again: the patty changes colour, the smoke turns dark.
local function scheduleRefresh(kind, stationId, slot)
    local cfg = cfgOf(kind)
    for _, at in ipairs({ cfg.cook, cfg.burn }) do
        SetTimeout(at + 50, function()
            local slots = cooking[kind][stationId]
            for _, s in pairs(slots or {}) do
                if s == slot then return refresh(kind, stationId) end
            end
        end)
    end
end

-- ============================================
-- Shared checks
-- ============================================

local function near(kind)
    return {
        at = function(_, _, stationId)
            local st = Stations[stationId]
            if st and st.kind == kind then return st.x, st.y, st.z end
        end,
        range = (Config.Stations[kind].reach or 2.0) + 1.0, message = 'Get closer',
    }
end

local function onDuty(source)
    if exports.whip_core:IsPlayerClockedOn(source, JOB) then return true end
    return false, 'Clock on at Burger Shot first'
end

local function stationCoords(stationId)
    local st = Stations[stationId]
    return st and vector3(st.x, st.y, st.z)
end

--- A one-off sound at a station, for every game near it (client/sounds.lua plays it, louder the nearer).
local function sound(name, stationId)
    local at = stationCoords(stationId)
    if at then TriggerClientEvent('whip_burgershot:sound', -1, name, at) end
end

--- A server-timed bar at a station: true when it ran, else false, why (nil for a cancel).
local function bar(source, player, stationId, label, duration, anim)
    local done, why = Whip.core:Progress(source, {
        label = label, duration = duration, icon = 'eat', anim = anim,
        near = { coords = stationCoords(stationId), range = 3.0 },
    })
    if not done then return false, why ~= 'cancelled' and why or nil end
    if not exports.whip_core:IsSessionCurrent(source, player.session) then return false end
    return true
end

-- ============================================
-- Declarations
-- ============================================

local KINDS = {}
for kind in pairs(Config.Stations) do KINDS[#KINDS + 1] = kind end

-- What a placed fridge spot hands out: a Config.Fridge id, or 'all' (the whole list).
local FRIDGE_IDS = { 'all' }
for _, f in ipairs(Config.Fridge) do FRIDGE_IDS[#FRIDGE_IDS + 1] = f.id end
local INGREDIENTS = {}
for key in pairs(Config.Ingredients) do INGREDIENTS[#INGREDIENTS + 1] = key end
local PRODUCT_IDS = {}
for id in pairs(PRODUCTS) do PRODUCT_IDS[#PRODUCT_IDS + 1] = id end
local BAGGABLE = {}
for key in pairs(Config.Counter.prices) do if key ~= 'bs_bag' then BAGGABLE[#BAGGABLE + 1] = key end end

Whip.register(function()
    Whip.core:EnsureTable(TABLE, ([[
        CREATE TABLE IF NOT EXISTS `%s` (
            `id`      INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `kind`    VARCHAR(20)  NOT NULL,
            `x`       FLOAT        NOT NULL,
            `y`       FLOAT        NOT NULL,
            `z`       FLOAT        NOT NULL,
            `heading` FLOAT        NOT NULL DEFAULT 0,
            `item`    VARCHAR(32)  NULL DEFAULT NULL,
            PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]):format(TABLE))
    -- A table made before fridge spots had an item: add the column.
    local okCol, hasItem = pcall(MySQL.scalar.await,
        'SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?',
        { TABLE, 'item' })
    if okCol and tonumber(hasItem) == 0 then
        local ok, err = pcall(MySQL.query.await, ('ALTER TABLE `%s` ADD COLUMN `item` VARCHAR(32) NULL DEFAULT NULL'):format(TABLE))
        if not ok then Whip.startProblem('could not add the fridge spots\' item column: %s', tostring(err)) end
    end
    loadStations()

    if counterStation() then
        local ok, why = setupCounter()
        if not ok then Whip.startProblem('the counter could not be set up: %s', tostring(why)) end
    elseif Counter.remove() then
        -- Its register was removed while the counter stayed (before /bsremove took it too): gone now.
        print('[whip_burgershot] no register is placed: removed the counter left behind')
    end
    syncAll()

    -- ---- the list, and what is cooking, for a game that has just loaded ----
    Whip.core:SecureCallback('whip_burgershot:getStations', { rateLimit = 2000, requirePlayer = false }, function()
        local cooks = {}
        for kind, byStation in pairs(cooking) do
            for stationId in pairs(byStation) do cooks[#cooks + 1] = { stationId, cookState(kind, stationId) } end
        end
        return stationList(), cooks
    end)

    -- ---- placing: the admin's game sends where PlaceObject put it ----
    Whip.core:SecureEvent('whip_burgershot:placed', {
        ace = 'whip.devtools', rateLimit = 1000,
        params = {
            { 'kind', 'enum', KINDS },
            { 'x', 'number' }, { 'y', 'number' }, { 'z', 'number' }, { 'heading', 'number', -360, 720 },
            { 'item', 'enum', FRIDGE_IDS },
        },
    }, function(source, _, kind, x, y, z, heading, item)
        if not exports.whip_core:HasDevTools(source) then return false, 'Turn developer mode on (/w)' end
        local here = GetEntityCoords(GetPlayerPed(source))
        if #(here - vector3(x, y, z)) > Config.PlaceReach then return false, 'Place it closer to you' end
        -- Only a fridge spot has an item.
        if kind ~= 'fridge' or item == 'all' then item = nil end

        local id, swhy = saveStation(kind, x, y, z, heading, item)
        if not id then return false, swhy end

        if kind == 'register' and counterStation().id == id then
            local cok, why = setupCounter()
            if not cok then exports.whip_core:NotifyPlayer(source, 'Counter: ' .. tostring(why), 'error') end
        end
        exports.whip_core:NotifyPlayer(source, ('%s placed (#%d)'):format(Config.Stations[kind].label, id), 'success')
    end)

    -- ---- the fridge ----
    local FRIDGE_ITEMS = {}
    for _, f in ipairs(Config.Fridge) do FRIDGE_ITEMS[#FRIDGE_ITEMS + 1] = f.item end
    Whip.core:SecureEvent('whip_burgershot:fridge:take', {
        rateLimit = 600, near = near('fridge'),
        params = { { 'stationId', 'id' }, { 'item', 'enum', FRIDGE_ITEMS } },
    }, function(source, player, stationId, item)
        local ok, why = onDuty(source)
        if not ok then return false, why end
        -- A spot of one food hands out only that.
        local own = Stations[stationId] and Stations[stationId].item
        if own and Config.FridgeById[own].item ~= item then return false, 'That is not kept here' end
        local a = Config.Anims.fridge
        local done, bwhy = bar(source, player, stationId, ('Taking %s...'):format(itemLabel(item)), a.time, a.anim)
        if not done then return false, bwhy end
        local given, gwhy = exports.whip_core:AddItem(source, item, 1, nil, 'Burger Shot fridge')
        if not given then return false, gwhy end
    end)

    -- ---- grill and fryer: put on ----
    local function freeSlot(kind, stationId)
        local slots = cooking[kind][stationId] or {}
        for _, n in ipairs(fillOrder(cfgOf(kind))) do if not slots[n] then return n end end
    end

    local function putOn(source, player, kind, stationId, product)
        local ok, why = onDuty(source)
        if not ok then return false, why end
        local full = ('The %s is full'):format(Config.Stations[kind].label:lower())
        if not freeSlot(kind, stationId) then return false, full end

        local raw, count = Config.Grill.raw, 1
        if kind == 'fryer' then raw, count = product.raw, product.count end
        if (exports.whip_core:GetItemCount(source, raw) or 0) < count then
            return false, ('You need %d %s'):format(count, itemLabel(raw))
        end
        local a = Config.Anims[kind]
        local done, bwhy = bar(source, player, stationId,
            kind == 'grill' and 'Putting a patty on...' or ('Frying %s...'):format(product.label:lower()), a.time, a.anim)
        if not done then return false, bwhy end
        -- Someone else may have filled it during the bar.
        local free = freeSlot(kind, stationId)
        if not free then return false, full end
        local slots = cooking[kind][stationId] or {}
        local taken, twhy = exports.whip_core:RemoveItem(source, raw, count, nil, { reason = 'Burger Shot ' .. kind })
        if not taken then return false, twhy end

        local slot = { startedAt = GetGameTimer(), product = product and product.id }
        slots[free] = slot
        cooking[kind][stationId] = slots
        refresh(kind, stationId)
        scheduleRefresh(kind, stationId, slot)
    end

    Whip.core:SecureEvent('whip_burgershot:grill:put', {
        rateLimit = 800, near = near('grill'), params = { { 'stationId', 'id' } },
    }, function(source, player, stationId)
        return putOn(source, player, 'grill', stationId)
    end)

    Whip.core:SecureEvent('whip_burgershot:fryer:put', {
        rateLimit = 800, near = near('fryer'),
        params = { { 'stationId', 'id' }, { 'product', 'enum', PRODUCT_IDS } },
    }, function(source, player, stationId, productId)
        return putOn(source, player, 'fryer', stationId, PRODUCTS[productId])
    end)

    -- ---- grill and fryer: take off (the one on longest, if it is ready) ----
    for _, kind in ipairs({ 'grill', 'fryer' }) do
        local cfg = cfgOf(kind)
        Whip.core:SecureEvent(('whip_burgershot:%s:take'):format(kind), {
            rateLimit = 800, near = near(kind), params = { { 'stationId', 'id' } },
        }, function(source, player, stationId)
            local ok, why = onDuty(source)
            if not ok then return false, why end
            -- The one on longest that is ready (looked for again after the bar: someone else may have taken it).
            local function ready()
                local pick, oldest
                for n, slot in pairs(cooking[kind][stationId] or {}) do
                    if doneness(cfg, slot.startedAt) ~= 'cooking' and (not oldest or slot.startedAt < oldest.startedAt) then
                        pick, oldest = n, slot
                    end
                end
                return pick, oldest
            end
            if not ready() then return false, 'Nothing is ready yet' end
            local a = Config.Anims[kind]
            local done, bwhy = bar(source, player, stationId,
                kind == 'grill' and 'Taking a patty off...' or 'Taking a basket out...', a.time, a.anim)
            if not done then return false, bwhy end
            local pick, oldest = ready()
            if not pick then return false, 'Nothing is ready yet' end
            local slots = cooking[kind][stationId]

            local burnt = doneness(cfg, oldest.startedAt) == 'burnt'
            slots[pick] = nil
            refresh(kind, stationId)

            local item, metadata
            if kind == 'grill' then
                item = burnt and cfg.burnt or cfg.done
            else
                item = PRODUCTS[oldest.product].done
                metadata = burnt and { burnt = true, quality = 'Burnt' } or nil
            end
            local given, gwhy = exports.whip_core:AddItem(source, item, 1, metadata, 'Burger Shot ' .. kind)
            if not given then return false, gwhy end
        end)
    end

    -- ---- the drinks machine ----
    local DRINK_ITEMS = {}
    for _, d in ipairs(Config.Drinks) do DRINK_ITEMS[#DRINK_ITEMS + 1] = d.item end
    Whip.core:SecureEvent('whip_burgershot:drinks:pour', {
        rateLimit = 1000, near = near('drinks'),
        params = { { 'stationId', 'id' }, { 'item', 'enum', DRINK_ITEMS } },
    }, function(source, player, stationId, item)
        local ok, why = onDuty(source)
        if not ok then return false, why end
        sound('pour', stationId)
        -- The drink stands under the nozzle while it pours, for everyone near (client/effects.lua).
        TriggerClientEvent('whip_burgershot:pourCup', -1, stationId, item, Config.PourTime)
        local done, bwhy = bar(source, player, stationId, ('Pouring %s...'):format(itemLabel(item)), Config.PourTime,
            Config.Anims.pour.anim)
        if not done then
            TriggerClientEvent('whip_burgershot:pourCup', -1, stationId, nil, 0)
            return false, bwhy
        end
        local given, gwhy = exports.whip_core:AddItem(source, item, 1, nil, 'Burger Shot drinks machine')
        if not given then return false, gwhy end
    end)

    -- ---- the prep counter: what the cook carries for it, and wrapping the stack ----
    Whip.core:SecureCallback('whip_burgershot:assembly:open', {
        rateLimit = 1000, near = near('assembly'), params = { { 'stationId', 'id' } },
    }, function(source)
        local ok, why = onDuty(source)
        if not ok then return false, why end
        local have = {}
        for _, ing in pairs(Config.Ingredients) do
            if ing.item then have[ing.item] = exports.whip_core:GetItemCount(source, ing.item) or 0 end
        end
        return have
    end)

    Whip.core:SecureEvent('whip_burgershot:assembly:wrap', {
        rateLimit = 1500, near = near('assembly'),
        params = { { 'stationId', 'id' }, { 'layers', 'list', { 'layer', 'enum', INGREDIENTS }, Config.MaxLayers } },
    }, function(source, player, stationId, layers)
        local ok, why = onDuty(source)
        if not ok then return false, why end
        ok, why = Recipes.check(layers)
        if not ok then return false, why end

        local used = Recipes.itemsUsed(layers)
        for item, n in pairs(used) do
            if (exports.whip_core:GetItemCount(source, item) or 0) < n then
                return false, ('You need %d %s'):format(n, itemLabel(item))
            end
        end

        sound('wrap', stationId)
        local done, bwhy = bar(source, player, stationId, 'Wrapping...', Config.WrapTime, Config.Anims.wrap.anim)
        if not done then return false, bwhy end

        -- Take the patties (all, or nothing is made), then hand over the burger.
        local taken = {}
        for item, n in pairs(used) do
            local tok, twhy = exports.whip_core:RemoveItem(source, item, n, nil, { reason = 'made a burger' })
            if not tok then
                for back, m in pairs(taken) do exports.whip_core:AddItem(source, back, m, nil, 'burger not made') end
                return false, twhy
            end
            taken[item] = n
        end
        local key, name, burnt = Recipes.match(layers)
        local given, gwhy = exports.whip_core:AddItem(source, key, 1, burnt and { burnt = true, quality = 'Burnt' } or nil,
            'Burger Shot prep counter')
        if not given then return false, gwhy end
        exports.whip_core:NotifyPlayer(source, burnt and (name .. ', with a burnt patty') or name, 'success')
    end)

    -- ---- packing: box a burger ----
    local BOX_FROM = {}
    for _, b in ipairs(Config.Boxes) do BOX_FROM[#BOX_FROM + 1] = b.from end
    Whip.core:SecureEvent('whip_burgershot:pack:box', {
        rateLimit = 800, near = near('bagging'),
        params = { { 'stationId', 'id' }, { 'item', 'enum', BOX_FROM } },
    }, function(source, player, stationId, from)
        local ok, why = onDuty(source)
        if not ok then return false, why end
        local to
        for _, b in ipairs(Config.Boxes) do if b.from == from then to = b.to end end
        local found = exports.whip_core:FindItem(source, from)
        if not found then return false, ('You have no %s'):format(itemLabel(from)) end
        local done, bwhy = bar(source, player, stationId, 'Boxing...', Config.PackTime, Config.Anims.pack.anim)
        if not done then return false, bwhy end
        local tok, twhy = exports.whip_core:RemoveItem(source, from, 1, found.metadata, { reason = 'boxed' })
        if not tok then return false, twhy end
        exports.whip_core:AddItem(source, to, 1, found.metadata, 'Burger Shot packing')
    end)

    -- ---- packing: a meal (one of each line of `needs`) ----
    local MEAL_ITEMS = {}
    for _, m in ipairs(Config.Meals) do MEAL_ITEMS[#MEAL_ITEMS + 1] = m.item end
    Whip.core:SecureEvent('whip_burgershot:pack:meal', {
        rateLimit = 800, near = near('bagging'),
        params = { { 'stationId', 'id' }, { 'item', 'enum', MEAL_ITEMS } },
    }, function(source, player, stationId, mealItem)
        local ok, why = onDuty(source)
        if not ok then return false, why end
        local meal
        for _, m in ipairs(Config.Meals) do if m.item == mealItem then meal = m end end

        -- One of each line, from what they carry.
        local picks = {}
        for _, line in ipairs(meal.needs) do
            local found
            for _, key in ipairs(line) do
                found = exports.whip_core:FindItem(source, key)
                if found then break end
            end
            if not found then return false, ('You need %s'):format(itemLabel(line[1])) end
            picks[#picks + 1] = found
        end

        local done, bwhy = bar(source, player, stationId, ('Packing %s...'):format(itemLabel(mealItem)), Config.PackTime, Config.Anims.pack.anim)
        if not done then return false, bwhy end

        local contents, names = {}, {}
        for _, f in ipairs(picks) do
            local tok, twhy = exports.whip_core:RemoveItem(source, f.item, 1, f.metadata, { reason = 'packed in a meal' })
            if not tok then
                for _, c in ipairs(contents) do exports.whip_core:AddItem(source, c.item, 1, c.metadata, 'meal not packed') end
                return false, twhy
            end
            contents[#contents + 1] = { item = f.item, metadata = f.metadata }
            names[#names + 1] = itemLabel(f.item)
        end
        exports.whip_core:AddItem(source, mealItem, 1, { contents = contents, summary = table.concat(names, ', ') },
            'Burger Shot packing')
    end)

    -- ---- packing: a takeaway box of anything ----
    Whip.core:SecureCallback('whip_burgershot:bag:state', {
        rateLimit = 250, near = near('bagging'), params = { { 'stationId', 'id' } },
    }, function(source)
        local have = {}
        for _, key in ipairs(BAGGABLE) do
            local n = exports.whip_core:GetItemCount(source, key) or 0
            if n > 0 then have[#have + 1] = { item = key, count = n, label = itemLabel(key) } end
        end
        table.sort(have, function(a, b) return a.label < b.label end)
        local inBag = {}
        for _, it in ipairs(bags[source] and bags[source].items or {}) do inBag[#inBag + 1] = it.label end
        return { have = have, inBag = inBag, max = Config.BagMax }
    end)

    Whip.core:SecureEvent('whip_burgershot:bag:add', {
        rateLimit = 300, near = near('bagging'),
        params = { { 'stationId', 'id' }, { 'item', 'enum', BAGGABLE } },
    }, function(source, player, _, item)
        local ok, why = onDuty(source)
        if not ok then return false, why end
        local bag = bags[source] or { charId = player.charId, items = {} }
        if #bag.items >= Config.BagMax then return false, 'The box is full' end
        local found = exports.whip_core:FindItem(source, item)
        if not found then return false, 'You have none' end
        local tok, twhy = exports.whip_core:StoreTake(found.addr, 1, { reason = 'packed in a takeaway box' })
        if not tok then return false, twhy end
        bag.items[#bag.items + 1] = { item = item, metadata = found.metadata, label = itemLabel(item) }
        bags[source] = bag
    end)

    Whip.core:SecureEvent('whip_burgershot:bag:back', {
        rateLimit = 300, near = near('bagging'), params = { { 'stationId', 'id' } },
    }, function(source)
        local bag = bags[source]
        local last = bag and table.remove(bag.items)
        if not last then return false, 'The box is empty' end
        exports.whip_core:AddItem(source, last.item, 1, last.metadata, 'taken out of a takeaway box')
    end)

    Whip.core:SecureEvent('whip_burgershot:bag:seal', {
        rateLimit = 1000, near = near('bagging'), params = { { 'stationId', 'id' } },
    }, function(source)
        local bag = bags[source]
        if not bag or #bag.items == 0 then return false, 'Put something in the box first' end
        local contents, counts, order = {}, {}, {}
        for _, it in ipairs(bag.items) do
            contents[#contents + 1] = { item = it.item, metadata = it.metadata }
            if not counts[it.label] then order[#order + 1] = it.label end
            counts[it.label] = (counts[it.label] or 0) + 1
        end
        local parts = {}
        for _, label in ipairs(order) do parts[#parts + 1] = counts[label] > 1 and ('%dx %s'):format(counts[label], label) or label end
        local given, gwhy = exports.whip_core:AddItem(source, 'bs_bag', 1,
            { contents = contents, summary = table.concat(parts, ', ') }, 'sealed a takeaway box')
        if not given then return false, gwhy end
        bags[source] = nil
    end)

    -- ---- the counter's shelf: from the packing station or the register ----
    for _, kind in ipairs({ 'bagging', 'register' }) do
        Whip.core:SecureEvent(('whip_burgershot:counter:stock:%s'):format(kind), {
            rateLimit = 1500, near = near(kind), params = { { 'stationId', 'id' } },
        }, function(source)
            local ok, why = onDuty(source)
            if not ok then return false, why end
            -- Not set up yet (no register when the resource started, or setting it up failed then): try now, and
            -- say what is wrong if it still cannot be.
            if not Counter.containerId then
                local cok, cwhy = setupCounter()
                if not cok then return false, 'The counter could not be set up: ' .. tostring(cwhy) end
            end
            local n, swhy = Counter.stockFrom(source)
            if n == 0 then return false, swhy end
            exports.whip_core:NotifyPlayer(source, ('Put %d on the counter'):format(n), 'success')
        end)
    end
end)

-- ============================================
-- A half-packed takeaway box is not lost: what was in it goes back, now or at their next login
-- ============================================

local function returnBag(source)
    local bag = bags[source]
    bags[source] = nil
    if not bag then return end
    for _, it in ipairs(bag.items) do
        exports.whip_core:GiveOnLogin({ charId = bag.charId }, it.item, 1, it.metadata, { reason = 'an unsealed takeaway box' })
    end
end

AddEventHandler('playerDropped', function() returnBag(source) end)
AddEventHandler('whip_core:player:logout', function(e) if type(e) == 'table' and e.source then returnBag(e.source) end end)

-- ============================================
-- Admin commands
-- ============================================

-- /bsplace <kind>: put a station down where you aim (whip's PlaceObject on your game).
Whip.command('bsplace', { dev = true }, function(source, args)
    local kind = args[1]
    if not kind or not Config.Stations[kind] then
        local names = {}
        for k in pairs(Config.Stations) do names[#names + 1] = k end
        table.sort(names)
        return exports.whip_core:NotifyPlayer(source, 'Usage: /bsplace <' .. table.concat(names, '|') .. '>', 'error')
    end
    -- A fridge spot of one food: /bsplace fridge <id>.
    local item = 'all'
    if kind == 'fridge' and args[2] then
        if not Config.FridgeById[args[2]] then
            local ids = {}
            for _, f in ipairs(Config.Fridge) do ids[#ids + 1] = f.id end
            return exports.whip_core:NotifyPlayer(source, 'Usage: /bsplace fridge [' .. table.concat(ids, '|') .. ']', 'error')
        end
        item = args[2]
    end
    -- The cashier is where the shop's keeper stands: where you stand now, facing the way you face (stand behind the
    -- counter, facing the customers).
    if kind == 'cashier' then
        local ped = GetPlayerPed(source)
        local at = GetEntityCoords(ped)
        local id, why = saveStation('cashier', at.x, at.y, at.z, GetEntityHeading(ped), nil)
        if not id then return exports.whip_core:NotifyPlayer(source, why, 'error') end
        if counterStation() then
            local ok, cwhy = setupCounter()
            if not ok then return exports.whip_core:NotifyPlayer(source, 'Counter: ' .. tostring(cwhy), 'error') end
        end
        return exports.whip_core:NotifyPlayer(source, ('Cashier placed (#%d): the keeper stands here'):format(id), 'success')
    end
    TriggerClientEvent('whip_burgershot:startPlacing', source, kind, item)
end)

-- /bssmoke <asset> <effect> [scale] [alpha] [count] [spread]: try a GTA particle over the nearest grill or fryer for
-- ten seconds (client/effects.lua), to choose what goes in Config.Smoke. Only on your own game.
Whip.command('bssmoke', { dev = true }, function(source, args)
    local asset, name = args[1], args[2]
    if not asset or not name or #asset > 64 or #name > 64 then
        return exports.whip_core:NotifyPlayer(source, 'Usage: /bssmoke <asset> <effect> [scale] [alpha] [count] [spread]', 'error')
    end
    local function num(v, def, lo, hi)
        v = tonumber(v) or def
        return math.max(lo, math.min(hi, v))
    end
    TriggerClientEvent('whip_burgershot:smokeTest', source, asset, name,
        num(args[3], 0.05, 0.001, 2.0), num(args[4], 0.3, 0.0, 1.0),
        math.floor(num(args[5], 1, 1, 8)), num(args[6], 0.04, 0.0, 0.5))
end)

-- /bsremove: take away the station nearest you (within 3 m).
Whip.command('bsremove', { dev = true }, function(source)
    local here = GetEntityCoords(GetPlayerPed(source))
    local best, bestD = nil, 3.0
    for _, st in pairs(Stations) do
        local d = #(here - vector3(st.x, st.y, st.z))
        if d < bestD then best, bestD = st, d end
    end
    if not best then
        -- The counter's shop or shelf with no register left to remove it by.
        if not counterStation() and Counter.near(here, 3.0) then
            Counter.remove()
            return exports.whip_core:NotifyPlayer(source, 'Counter removed', 'success')
        end
        return exports.whip_core:NotifyPlayer(source, 'No station within 3 m', 'error')
    end
    local ok = pcall(MySQL.query.await, ('DELETE FROM `%s` WHERE `id` = ?'):format(TABLE), { best.id })
    if not ok then return exports.whip_core:NotifyPlayer(source, 'Could not remove it', 'error') end
    Stations[best.id] = nil
    for kind in pairs(cooking) do
        if cooking[kind][best.id] then cooking[kind][best.id] = nil; refresh(kind, best.id) end
    end
    syncAll()
    -- The counter follows its register and cashier.
    -- The counter follows its register and cashier; the last register gone, it goes too (shop, keeper, shelf).
    if best.kind == 'register' or best.kind == 'cashier' then
        if counterStation() then setupCounter() else Counter.remove() end
    end
    exports.whip_core:NotifyPlayer(source, ('%s #%d removed'):format(Config.Stations[best.kind].label, best.id), 'success')
end)

-- ============================================
-- Chat suggestions for the admin commands
-- ============================================
--
-- Sent only to players who may use them (whip.devtools), when their character loads and when this resource starts,
-- so other players never see them in the chat's list.

local function commandSuggestions()
    local kinds, foods = {}, {}
    for k in pairs(Config.Stations) do kinds[#kinds + 1] = k end
    table.sort(kinds)
    for _, f in ipairs(Config.Fridge) do foods[#foods + 1] = f.id end
    return {
        { name = '/bsplace', help = 'Burger Shot: place a station where you aim (wheel turns it; the sign faces you)',
          params = {
              { name = 'kind', help = table.concat(kinds, ', ') .. ' (cashier: placed where you stand, facing the way you face)' },
              { name = 'food', help = 'fridge only, optional: a spot of one food - ' .. table.concat(foods, ', ') },
          } },
        { name = '/bsremove', help = 'Burger Shot: remove the station nearest you (within 3 m)' },
        { name = '/bssmoke', help = 'Burger Shot: try a GTA particle over the nearest grill or fryer for 10 s',
          params = {
              { name = 'asset', help = 'particle asset, e.g. core' },
              { name = 'effect', help = 'effect name, e.g. ent_amb_steam' },
              { name = 'scale', help = 'size (default 0.05)' },
              { name = 'alpha', help = '0 to 1 (default 0.3)' },
              { name = 'count', help = 'how many, 1 to 8 (default 1)' },
              { name = 'spread', help = 'metres apart (default 0.04)' },
          } },
    }
end

local function sendSuggestions(src)
    if src and IsPlayerAceAllowed(src, 'whip.devtools') then
        TriggerClientEvent('chat:addSuggestions', src, commandSuggestions())
    end
end

AddEventHandler('whip_core:player:loaded', function(e)
    if type(e) == 'table' then sendSuggestions(e.source) end
end)

CreateThread(function()
    for _, src in ipairs(GetPlayers()) do sendSuggestions(tonumber(src)) end
end)
