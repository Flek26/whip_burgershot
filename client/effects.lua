-- ============================================
-- whip_burgershot — client: smoke over the grill and fryer, and the kitchen's sounds
-- ============================================
--
-- SMOKE: GTA's own particles (Config.Smoke), at every grill or fryer with food on it within range: steam while it
-- cooks, dark smoke once something on it is burnt. From what the server says is cooking (Cooks, client/stations.lua),
-- so every player near sees the same.
--
-- SOUND: this resource's page (html/index.html) plays the files in html/sounds/, louder the nearer the player is: a
-- loop while a grill or fryer is busy, and one-offs the server asks for (pouring, wrapping). A missing file is silent.

local fx = {}        -- [stationId] = { handle, kind } : the looped particle at each station
local loops = {}     -- [stationId] = true while its sound loop plays

-- ============================================
-- Particles
-- ============================================

local function loadAsset(asset)
    if HasNamedPtfxAssetLoaded(asset) then return true end
    RequestNamedPtfxAsset(asset)
    local giveUp = GetGameTimer() + 3000
    while not HasNamedPtfxAssetLoaded(asset) and GetGameTimer() < giveUp do Wait(0) end
    return HasNamedPtfxAssetLoaded(asset)
end

local function stopFx(stationId)
    local f = fx[stationId]
    if f then
        for _, h in ipairs(f.handles) do StopParticleFxLooped(h, false) end
    end
    fx[stationId] = nil
end

--- One layer (Config.Smoke) at a point: `count` of it in a little ring `spread` across.
local function startLayer(def, at, handles)
    if not loadAsset(def.asset) then return end
    local count = def.count or 1
    for i = 1, count do
        local x, y = at.x, at.y
        if count > 1 then
            local a = (i - 1) / count * math.pi * 2
            x = x + math.cos(a) * (def.spread or 0.0)
            y = y + math.sin(a) * (def.spread or 0.0)
        end
        UseParticleFxAssetNextCall(def.asset)
        local h = StartParticleFxLoopedAtCoord(def.name, x, y, at.z + (def.lift or 0.0), 0.0, 0.0, 0.0,
            (def.scale or 1.0) + 0.0, false, false, false, false)
        if h and h ~= 0 then
            if def.alpha then SetParticleFxLoopedAlpha(h, def.alpha + 0.0) end
            if def.colour then SetParticleFxLoopedColour(h, def.colour[1] + 0.0, def.colour[2] + 0.0, def.colour[3] + 0.0, false) end
            handles[#handles + 1] = h
        end
    end
end

--- Where each piece of food is, and whether it is burnt by now (the state the server sent, moved on by the time
--- since). Also a key that changes when either does, so the particles are only remade then.
local function pieces(st, c)
    local cfg = st.kind == 'grill' and Config.Grill or Config.Fryer
    local since = GetGameTimer() - c.at
    local list, key = {}, {}
    for _, s in ipairs(c.slots) do
        if s.n then
            local burnt = s.burnLeft - since <= 0
            local across, back = Grid.offset(cfg, s.n)
            list[#list + 1] = { at = Grid.world(st, across, back, cfg.lift or 0.0), burnt = burnt }
            key[#key + 1] = s.n .. (burnt and 'b' or 'c')
        end
    end
    table.sort(key)
    return list, table.concat(key, ',')
end

local function startFx(st, c)
    local list, key = pieces(st, c)
    if fx[st.id] and fx[st.id].key == key then return end
    stopFx(st.id)
    local handles = {}
    local looks = Config.Smoke[st.kind] or {}
    for _, p in ipairs(list) do
        for _, def in ipairs(looks[p.burnt and 'burnt' or 'cooking'] or {}) do
            startLayer(def, p.at, handles)
        end
    end
    fx[st.id] = { handles = handles, key = key }
end

-- /bssmoke asset name scale alpha [count] [spread]: try a GTA effect over the nearest grill or fryer for ten
-- seconds, to pick what goes in Config.Smoke. Admins (whip dev tools) only: the server checks.
RegisterNetEvent('whip_burgershot:smokeTest', function(asset, name, scale, alpha, count, spread)
    local here = GetEntityCoords(PlayerPedId())
    local best, bestD
    for _, st in pairs(Stations) do
        if st.kind == 'grill' or st.kind == 'fryer' then
            local d = #(here - vector3(st.x, st.y, st.z))
            if not bestD or d < bestD then best, bestD = st, d end
        end
    end
    if not best or bestD > 10.0 then
        print('[whip_burgershot] /bssmoke: no grill or fryer within 10 m')
        return
    end
    local handles = {}
    startLayer({ asset = asset, name = name, scale = scale, alpha = alpha, count = count, spread = spread, lift = 0.02 },
        vector3(best.x, best.y, best.z), handles)
    print(('[whip_burgershot] /bssmoke %s %s scale %.3f alpha %.2f: %s'):format(asset, name, scale, alpha,
        #handles > 0 and 'playing for 10 s' or 'GTA has no such effect (or its asset would not load)'))
    SetTimeout(10000, function()
        for _, h in ipairs(handles) do StopParticleFxLooped(h, false) end
    end)
end)

-- ============================================
-- The food on the plate
-- ============================================
--
-- Each game makes its own (not networked), from what the server says is on each slot. A pack model's origin is not
-- always the middle of its shape, so the shape's own middle (GetModelDimensions) goes on the slot, and its bottom on
-- the plate.

local food = {}      -- [stationId] = { [n] = { ent, model } }

local function deleteFood(stationId, n)
    local f = food[stationId] and food[stationId][n]
    if f and DoesEntityExist(f.ent) then DeleteEntity(f.ent) end
    if food[stationId] then food[stationId][n] = nil end
end

local function clearFood(stationId)
    for n in pairs(food[stationId] or {}) do deleteFood(stationId, n) end
    food[stationId] = nil
end

local function makeFood(st, cfg, n, model)
    local hash = GetHashKey(model)
    if not IsModelInCdimage(hash) then return nil end
    RequestModel(hash)
    local giveUp = GetGameTimer() + 3000
    while not HasModelLoaded(hash) and GetGameTimer() < giveUp do Wait(0) end
    if not HasModelLoaded(hash) then return nil end

    local min, max = GetModelDimensions(hash)
    local across, back = Grid.offset(cfg, n)
    -- The shape's middle on the slot: take its offset from the origin (turned with the station) off the slot.
    local at = Grid.world(st, across - (min.x + max.x) / 2, back - (min.y + max.y) / 2, (cfg.lift or 0.0) - min.z)
    local ent = CreateObjectNoOffset(hash, at.x, at.y, at.z, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    SetEntityHeading(ent, st.heading or 0.0)
    FreezeEntityPosition(ent, true)
    SetEntityCollision(ent, false, false)
    -- In the kitchen's room (an MLO culls a script's object that is in none).
    local interior = GetInteriorAtCoords(st.x, st.y, st.z + 0.5)
    if interior ~= 0 then
        local ped = PlayerPedId()
        if GetInteriorFromEntity(ped) == interior then ForceRoomForEntity(ent, interior, GetRoomKeyFromEntity(ped)) end
    end
    return ent
end

--- Make what is missing, change what changed (raw to cooked to burnt), take away what was taken off.
local function syncFood(st, c)
    local cfg = st.kind == 'grill' and Config.Grill or Config.Fryer
    local want = {}
    for _, s in ipairs(c and c.slots or {}) do
        if s.n and s.model then want[s.n] = s.model end
    end
    for n in pairs(food[st.id] or {}) do
        if want[n] ~= food[st.id][n].model then deleteFood(st.id, n) end
    end
    for n, model in pairs(want) do
        if not (food[st.id] and food[st.id][n]) then
            local ent = makeFood(st, cfg, n, model)
            if ent then
                food[st.id] = food[st.id] or {}
                food[st.id][n] = { ent = ent, model = model }
            end
        end
    end
end

-- ============================================
-- The food on a fridge spot of one food (/bsplace fridge patty)
-- ============================================
--
-- Just where the placer's ghost was (the station's point and heading are the ghost's), so it is drawn as placed:
-- no centring. Each game makes its own.

local shelf = {}     -- [stationId] = { ent, model }

local function clearShelf(stationId)
    local s = shelf[stationId]
    if s and DoesEntityExist(s.ent) then DeleteEntity(s.ent) end
    shelf[stationId] = nil
end

local function syncShelf(st)
    local food = Config.FridgeById[st.item]
    if not food or not food.model then return end
    if shelf[st.id] and shelf[st.id].model == food.model and DoesEntityExist(shelf[st.id].ent) then return end
    clearShelf(st.id)
    local hash = GetHashKey(food.model)
    if not IsModelInCdimage(hash) then return end
    RequestModel(hash)
    local giveUp = GetGameTimer() + 3000
    while not HasModelLoaded(hash) and GetGameTimer() < giveUp do Wait(0) end
    if not HasModelLoaded(hash) then return end
    local ent = CreateObjectNoOffset(hash, st.x, st.y, st.z + (food.lift or 0.0), false, false, false)
    SetModelAsNoLongerNeeded(hash)
    SetEntityHeading(ent, st.heading or 0.0)
    FreezeEntityPosition(ent, true)
    SetEntityCollision(ent, false, false)
    local interior = GetInteriorAtCoords(st.x, st.y, st.z + 0.5)
    if interior ~= 0 then
        local ped = PlayerPedId()
        if GetInteriorFromEntity(ped) == interior then ForceRoomForEntity(ent, interior, GetRoomKeyFromEntity(ped)) end
    end
    shelf[st.id] = { ent = ent, model = food.model }
end

-- ============================================
-- The cup under the drinks machine's nozzle while it pours
-- ============================================
--
-- The drink's own prop (the pack's item keys are its models), its bottom on the machine's point, for the pour's
-- length. The server sends it to every game; one near enough draws it. nil item: the pour stopped early.

local cups = {}      -- [stationId] = { ent, token }

local function clearCup(stationId)
    local c = cups[stationId]
    if c and DoesEntityExist(c.ent) then DeleteEntity(c.ent) end
    cups[stationId] = nil
end

RegisterNetEvent('whip_burgershot:pourCup', function(stationId, item, duration)
    clearCup(stationId)
    local st = Stations[stationId]
    if not st or type(item) ~= 'string' then return end
    if #(GetEntityCoords(PlayerPedId()) - vector3(st.x, st.y, st.z)) > Config.Smoke.range then return end
    local hash = GetHashKey(item)
    if not IsModelInCdimage(hash) then return end
    RequestModel(hash)
    local giveUp = GetGameTimer() + 2000
    while not HasModelLoaded(hash) and GetGameTimer() < giveUp do Wait(0) end
    if not HasModelLoaded(hash) then return end
    -- The point is where the placer's ghost (Config.Stations.drinks.ghost) stood, its bottom on the drip tray: find the
    -- tray from it, then stand this drink's bottom there.
    local ghost = GetHashKey(Config.Stations.drinks.ghost)
    local trayZ = st.z
    if IsModelInCdimage(ghost) then trayZ = st.z + GetModelDimensions(ghost).z end
    local min = GetModelDimensions(hash)
    local ent = CreateObjectNoOffset(hash, st.x, st.y, trayZ + (Config.PourCupLift or 0.0) - min.z, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    SetEntityHeading(ent, st.heading or 0.0)
    FreezeEntityPosition(ent, true)
    SetEntityCollision(ent, false, false)
    local interior = GetInteriorAtCoords(st.x, st.y, st.z + 0.5)
    if interior ~= 0 then
        local ped = PlayerPedId()
        if GetInteriorFromEntity(ped) == interior then ForceRoomForEntity(ent, interior, GetRoomKeyFromEntity(ped)) end
    end
    local token = {}
    cups[stationId] = { ent = ent, token = token }
    SetTimeout(math.max(500, tonumber(duration) or 3000), function()
        if cups[stationId] and cups[stationId].token == token then clearCup(stationId) end
    end)
end)

-- ============================================
-- Sound
-- ============================================

local function volumeAt(def, at)
    local d = #(GetEntityCoords(PlayerPedId()) - at)
    if d >= def.range then return 0.0 end
    return def.volume * (1.0 - d / def.range)
end

local function stopLoop(stationId)
    if not loops[stationId] then return end
    loops[stationId] = nil
    SendNUIMessage({ type = 'stop', id = 'st' .. stationId })
end

-- A one-off at a point (server/stations.lua: pouring, wrapping).
RegisterNetEvent('whip_burgershot:sound', function(name, at)
    local def = Config.Sounds[name]
    if not def or type(at) ~= 'vector3' then return end
    local volume = volumeAt(def, at)
    if volume <= 0.01 then return end
    SendNUIMessage({ type = 'play', file = def.file, volume = volume })
end)

-- ============================================
-- The loop: four times a second, every grill and fryer near enough
-- ============================================

CreateThread(function()
    while true do
        local here = GetEntityCoords(PlayerPedId())
        for id, st in pairs(Stations) do
            -- A fridge spot's food.
            if st.kind == 'fridge' and st.item then
                if #(here - vector3(st.x, st.y, st.z)) < Config.Smoke.range then syncShelf(st)
                elseif shelf[id] then clearShelf(id) end
            end

            local c = Cooks[id]
            local near = c and #(here - vector3(st.x, st.y, st.z)) < Config.Smoke.range

            -- The food itself.
            if near then syncFood(st, c) elseif food[id] then clearFood(id) end

            -- Smoke over each piece: steam while it cooks, dark smoke once it is burnt.
            if near then
                startFx(st, c)
            elseif fx[id] then
                stopFx(id)
            end

            -- The sizzle (grill) or the bubbling (fryer), louder the nearer.
            local def = c and Config.Sounds[st.kind]
            if near and def then
                local volume = volumeAt(def, vector3(st.x, st.y, st.z))
                SendNUIMessage({ type = loops[id] and 'volume' or 'loop', id = 'st' .. id, file = def.file, volume = volume })
                loops[id] = true
            else
                stopLoop(id)
            end
        end
        -- A station removed while it smoked.
        for id in pairs(fx) do if not Stations[id] then stopFx(id) end end
        for id in pairs(food) do if not Stations[id] then clearFood(id) end end
        for id in pairs(shelf) do if not Stations[id] then clearShelf(id) end end
        for id in pairs(loops) do if not Stations[id] then stopLoop(id) end end
        Wait(250)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id in pairs(fx) do stopFx(id) end
    for id in pairs(food) do clearFood(id) end
    for id in pairs(shelf) do clearShelf(id) end
    for id in pairs(cups) do clearCup(id) end
end)
