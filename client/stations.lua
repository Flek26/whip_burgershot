-- ============================================
-- whip_burgershot — client: a prompt at every station
-- ============================================
--
-- The server sends where the stations are (server/stations.lua); each gets one AddAction with its options. `require`
-- only decides what is offered: every press is a SecureEvent the server checks again (duty, distance).
--
-- What is cooking arrives as it changes (whip_burgershot:cook) and is kept in Cooks, which the grill and fryer labels,
-- the smoke and the sizzle (client/effects.lua) read.

local JOB = Config.Job
local STAFF = { job = JOB, onDuty = true }

Stations = {}                -- [id] = station
Cooks = {}                   -- [stationId] = { kind, slots = { { state, cookLeft, burnLeft, label } }, free, at }

local function actionId(st) return ('station:%d'):format(st.id) end

local function send(name, ...)
    TriggerServerEvent('whip_burgershot:' .. name, ...)
end

local function itemName(key)
    return Config.Items[key] and Config.Items[key].name or key
end

-- ============================================
-- What is cooking
-- ============================================

RegisterNetEvent('whip_burgershot:cook', function(stationId, state)
    if type(state) ~= 'table' then return end
    state.at = GetGameTimer()
    Cooks[stationId] = (#state.slots > 0) and state or nil
end)

--- The grill or fryer's label: what is on it, with a countdown to the next one ready.
local function cookLabel(st)
    local name = Config.Stations[st.kind].label
    local c = Cooks[st.id]
    if not c then return name .. ' - empty' end
    local since = GetGameTimer() - c.at
    local cookingN, ready, burnt, nextLeft = 0, 0, 0, nil
    for _, s in ipairs(c.slots) do
        local cookLeft, burnLeft = s.cookLeft - since, s.burnLeft - since
        if burnLeft <= 0 then burnt = burnt + 1
        elseif cookLeft <= 0 then ready = ready + 1
        else
            cookingN = cookingN + 1
            if not nextLeft or cookLeft < nextLeft then nextLeft = cookLeft end
        end
    end
    local parts = {}
    if ready > 0 then parts[#parts + 1] = ('%d ready'):format(ready) end
    if burnt > 0 then parts[#parts + 1] = ('%d burnt'):format(burnt) end
    if cookingN > 0 then parts[#parts + 1] = ('%d cooking (%ds)'):format(cookingN, math.ceil(nextLeft / 1000)) end
    return name .. ' - ' .. table.concat(parts, ', ')
end

--- Room for one more? (The server refuses it anyway; this only hides the option.)
local function hasRoom(st)
    local c = Cooks[st.id]
    return not c or c.free > 0
end

--- Anything on it? (Hides "take" on an empty grill or fryer.)
local function hasFood(st)
    local c = Cooks[st.id]
    return c ~= nil and #c.slots > 0
end

-- ============================================
-- One prompt per station
-- ============================================

local OPTIONS = {}

OPTIONS.duty = function()
    return {
        { id = 'on', label = 'Clock on', icon = 'success', require = { job = JOB },
          canInteract = function() return not exports.whip_core:IsPlayerClockedOn(JOB) end,
          onSelect = function(ctx)
              local ok, why = exports.whip_core:ClockOn(JOB)
              if not ok then ctx.refuse(why) end
          end },
        { id = 'off', label = 'Clock off', icon = 'back', require = STAFF,
          onSelect = function() exports.whip_core:ClockOff(JOB) end },
    }
end

OPTIONS.fridge = function(st)
    local list = {}
    -- A spot of one food offers only that.
    local only = st.item and Config.FridgeById[st.item]
    for _, f in ipairs(only and { only } or Config.Fridge) do
        -- A spot of one food sits on that food: no picture on the sign. The whole list keeps them, to tell them apart.
        list[#list + 1] = { id = f.item, label = 'Take ' .. f.label, require = STAFF, stay = true,
            image = not only and ('https://cfx-nui-%s/html/img/items/%s.png'):format(GetCurrentResourceName(),
                Config.Items[f.item] and Config.Items[f.item].image or f.item) or nil,
            onSelect = function() send('fridge:take', st.id, f.item) end }
    end
    return list
end

OPTIONS.grill = function(st)
    return {
        { id = 'put', label = 'Put a patty on', require = STAFF, stay = true,
          canInteract = function() return hasRoom(st) end,
          onSelect = function() send('grill:put', st.id) end },
        { id = 'take', label = 'Take a patty off', require = STAFF, stay = true,
          canInteract = function() return hasFood(st) end,
          onSelect = function() send('grill:take', st.id) end },
    }
end

OPTIONS.fryer = function(st)
    local fry = {}
    for _, p in ipairs(Config.Fryer.products) do
        fry[#fry + 1] = { id = p.id, label = ('%s (%dx %s)'):format(p.label, p.count, itemName(p.raw)),
            onSelect = function() send('fryer:put', st.id, p.id) end }
    end
    return {
        { id = 'put', label = 'Fry...', require = STAFF, options = fry,
          canInteract = function() return hasRoom(st) end },
        { id = 'take', label = 'Take a basket out', require = STAFF, stay = true,
          canInteract = function() return hasFood(st) end,
          onSelect = function() send('fryer:take', st.id) end },
    }
end

OPTIONS.drinks = function(st)
    local list = {}
    for _, d in ipairs(Config.Drinks) do
        list[#list + 1] = { id = d.item, label = 'Pour ' .. d.label, require = STAFF,
            onSelect = function() send('drinks:pour', st.id, d.item) end }
    end
    return list
end

OPTIONS.assembly = function(st)
    return {
        { id = 'build', label = 'Build a burger', require = STAFF,
          onSelect = function() Assembly.open(st) end },
    }
end

OPTIONS.bagging = function(st)
    local boxes = {}
    for _, b in ipairs(Config.Boxes) do
        boxes[#boxes + 1] = { id = b.from, label = ('%s -> %s'):format(itemName(b.from), itemName(b.to)),
            onSelect = function() send('pack:box', st.id, b.from) end }
    end
    local meals = {}
    for _, m in ipairs(Config.Meals) do
        meals[#meals + 1] = { id = m.item, label = itemName(m.item),
            onSelect = function() send('pack:meal', st.id, m.item) end }
    end
    return {
        { id = 'box', label = 'Box a burger', require = STAFF, options = boxes },
        { id = 'meal', label = 'Make a meal', require = STAFF, options = meals },
        { id = 'pack', label = 'Takeaway box', require = STAFF,
          -- Filled as it opens: what they carry, and what is in the box so far.
          options = function()
              local s = exports.whip_core:Callback('whip_burgershot:bag:state', st.id)
              if type(s) ~= 'table' then return {} end
              local list = {}
              for _, h in ipairs(s.have) do
                  list[#list + 1] = { id = 'add:' .. h.item, label = ('Add %s (%d)'):format(h.label, h.count), stay = true,
                      onSelect = function() send('bag:add', st.id, h.item); Wait(250) end }
              end
              if #s.inBag > 0 then
                  list[#list + 1] = { id = 'back', label = 'Take the last one out', stay = true,
                      onSelect = function() send('bag:back', st.id); Wait(250) end }
                  list[#list + 1] = { id = 'seal', label = ('Close the box (%d/%d): %s'):format(#s.inBag, s.max, table.concat(s.inBag, ', ')),
                      onSelect = function() send('bag:seal', st.id) end }
              end
              return list
          end },
        { id = 'stock', label = 'Put food on the counter', require = STAFF,
          onSelect = function() send('counter:stock:bagging', st.id) end },
    }
end

-- The register has no prompt of its own: the counter's stash stands there with its own (open the shelf), and the
-- packing station puts food on it ("Put food on the counter"). Two prompts on one spot was one too many.


local function addStation(st)
    local def = Config.Stations[st.kind]
    local isCook = st.kind == 'grill' or st.kind == 'fryer'
    local food = st.kind == 'fridge' and st.item and Config.FridgeById[st.item]
    -- A sign facing the cook (Config.Stations' sign; shared/grid.lua).
    local signAt, signHeading, signTilt = Grid.sign(st)
    local at = { coords = signAt, heading = signHeading }
    if signHeading and signTilt then
        -- Leaning back (flat on the grill, on top of a fridge spot's food): only a follow can say a tilt. Worked out
        -- each time, so a food's height is right once its model has loaded. Centred on its point.
        at.follow = function()
            local p, h, t = Grid.sign(st)
            return p.x, p.y, p.z, h, 0.0, nil, true, t
        end
    end
    Whip.core:AddAction({
        id = actionId(st), group = 'stations',
        at = at,
        label = isCook and function() return cookLabel(st) end or (food and food.label) or def.label,
        -- No icon: the badge is whip's plain key (E).
        reach = def.reach, focusMode = 'aim',
        options = OPTIONS[st.kind](st),
    })
end

local function rebuild(list)
    Whip.core:RemoveActionGroup('stations')
    Stations = {}
    for _, st in ipairs(list or {}) do
        if Config.Stations[st.kind] and OPTIONS[st.kind] then
            Stations[st.id] = st
            addStation(st)
        end
    end
end

RegisterNetEvent('whip_burgershot:stations', rebuild)

-- On load, and after a whip_core restart (its actions are forgotten): the stations, and what is cooking on them.
Whip.register(function()
    local list, cooks = exports.whip_core:Callback('whip_burgershot:getStations')
    if type(list) ~= 'table' then return end
    rebuild(list)
    for _, c in ipairs(type(cooks) == 'table' and cooks or {}) do
        local state = c[2]
        state.at = GetGameTimer()
        Cooks[c[1]] = state
    end
end)
