-- ============================================
-- whip_burgershot — client: the prep counter, burgers built layer by layer
-- ============================================
--
-- A camera looks down at the worktop. Along the back, a tray of each ingredient (Config.Trays); in front, the wrapper.
-- Click a tray to pick one up (its prop follows the mouse over the worktop), click the wrapper to lay it on the stack.
-- Every layer is a real prop, stacked by its height (Config.Ingredients). Enter wraps: the server checks the stack and
-- the patties in the cook's pockets, runs the bar, and hands over the burger (server/stations.lua).
--
-- All the props here are this game's own (not networked): only the cook sees the burger being built.
--
-- Controls: whip's BlockControls holds every control off (mode = true: E prompts and the hotbar stand down), so the
-- mouse and keys are read with the disabled-control natives. SetScreenOpen hides the HUD, chat and prompts.

Assembly = {}

local BLOCK = 'bs_assembly'
local SCREEN = 'assembly'

local C = {   -- control ids
    cursorX = 239, cursorY = 240, click = 24, rclick = 25,
    enter = 191, space = 22, hint = 74, esc = 200, back = 177,
}

local active = nil   -- the open session: { st, cam, props, trays, wrapper, layers, stackProps, holding, ghost, have, hint }

-- ============================================
-- Geometry: the station's frame, the camera's ray
-- ============================================

--- A point on the worktop: x across (right +), y away from the cook, z up.
local function worktop(st, x, y, z)
    local h = math.rad(st.heading or 0.0)
    return vector3(
        st.x + math.cos(h) * x - math.sin(h) * y,
        st.y + math.sin(h) * x + math.cos(h) * y,
        st.z + (z or 0.0))
end

local function rotToDir(rot)
    local z, x = math.rad(rot.z), math.rad(rot.x)
    local c = math.abs(math.cos(x))
    return vector3(-math.sin(z) * c, math.cos(z) * c, math.sin(x))
end

local function cross(a, b)
    return vector3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)
end

local function norm(v)
    local l = #v
    return l > 0 and v / l or v
end

--- Where the mouse points on the worktop's plane, or nil.
local function cursorOnWorktop(cam, planeZ)
    local cx, cy = GetDisabledControlNormal(0, C.cursorX), GetDisabledControlNormal(0, C.cursorY)
    local pos, rot = GetCamCoord(cam), GetCamRot(cam, 2)
    local fwd = rotToDir(rot)
    local right = norm(cross(fwd, vector3(0.0, 0.0, 1.0)))
    local up = cross(right, fwd)
    local tanV = math.tan(math.rad(GetCamFov(cam)) / 2)
    local tanH = tanV * GetAspectRatio(false)
    local dir = norm(fwd + right * ((cx * 2 - 1) * tanH) + up * ((1 - cy * 2) * tanV))
    if dir.z >= -0.001 then return nil end
    local t = (planeZ - pos.z) / dir.z
    return pos + dir * t
end

local function flatDist(a, b)
    local dx, dy = a.x - b.x, a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end

-- ============================================
-- Props
-- ============================================

local function loadModel(model)
    local hash = type(model) == 'number' and model or GetHashKey(model)
    if not IsModelInCdimage(hash) then return nil end
    RequestModel(hash)
    local giveUp = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < giveUp do Wait(0) end
    return HasModelLoaded(hash) and hash or nil
end

local function spawnProp(model, at, heading)
    local hash = loadModel(model)
    if not hash then return nil end
    local ent = CreateObjectNoOffset(hash, at.x, at.y, at.z, false, false, false)
    SetEntityHeading(ent, heading or 0.0)
    -- Inside an MLO (the kitchen) an object made by script is in no room, and GTA culls it from inside: put it in the
    -- cook's room, where it is.
    local ped = PlayerPedId()
    local interior = GetInteriorFromEntity(ped)
    if interior ~= 0 then ForceRoomForEntity(ent, interior, GetRoomKeyFromEntity(ped)) end
    FreezeEntityPosition(ent, true)
    SetEntityCollision(ent, false, false)
    SetModelAsNoLongerNeeded(hash)
    return ent
end

local function deleteProp(ent)
    if ent and DoesEntityExist(ent) then
        SetEntityDrawOutline(ent, false)
        DeleteEntity(ent)
    end
end

-- ============================================
-- The stack
-- ============================================

--- How many of a pocket item the stack uses so far.
local function usedOf(item)
    local n = 0
    for _, key in ipairs(active.layers) do
        if Config.Ingredients[key].item == item then n = n + 1 end
    end
    return n
end

--- Can one more of this ingredient go on? Patties come from the cook's pockets.
local function available(key)
    local item = Config.Ingredients[key].item
    if not item then return true end
    return (active.have[item] or 0) - usedOf(item) > 0
end

--- A layer's height and how far its model's origin sits above its bottom: from config, else the model's own size.
local sizes = {}
local function layerSize(key)
    local ing = Config.Ingredients[key]
    if sizes[key] then return sizes[key].height, sizes[key].offset end
    local height, offset = ing.height or 0.0, ing.offset or 0.0
    if ing.model and (ing.height == nil or ing.offset == nil) then
        local hash = GetHashKey(ing.model)
        if IsModelInCdimage(hash) then
            local min, max = GetModelDimensions(hash)
            if ing.height == nil then height = max.z - min.z end
            if ing.offset == nil then offset = -min.z end
        end
    end
    sizes[key] = { height = height, offset = offset }
    return height, offset
end

local function stackHeight()
    local h = 0.0
    for _, key in ipairs(active.layers) do h = h + (layerSize(key)) end
    return h
end

local function addLayer(key)
    if #active.layers >= Config.MaxLayers then
        return Whip.core:Notify(('At most %d layers'):format(Config.MaxLayers), 'error')
    end
    local ing = Config.Ingredients[key]
    local w = active.wrapper
    local _, offset = layerSize(key)
    local at = vector3(w.x, w.y, active.st.z + active.wrapperTop + stackHeight() + offset)
    active.layers[#active.layers + 1] = key
    -- A sauce has no prop of its own: the layer is there, and shows in the stack's name.
    active.stackProps[#active.stackProps + 1] = ing.model and spawnProp(ing.model, at, active.st.heading) or false
end

local function removeTop()
    local n = #active.layers
    if n == 0 then return end
    deleteProp(active.stackProps[n])
    active.stackProps[n] = nil
    active.layers[n] = nil
end

-- ============================================
-- On screen
-- ============================================

local function drawText(x, y, text, scale, r, g, b)
    SetTextFont(4)
    SetTextScale(scale, scale)
    SetTextColour(r or 255, g or 255, b or 255, 235)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(x, y)
end

local function ingredientNames(layers)
    local out = {}
    for _, key in ipairs(layers) do out[#out + 1] = Config.Ingredients[key].label end
    return table.concat(out, ', ')
end

local function drawHint()
    local y = 0.08
    drawText(0.02, y, 'Recipes (bottom to top)', 0.45, 255, 200, 80)
    for _, r in pairs(Config.Recipes) do
        y = y + 0.035
        drawText(0.02, y, ('%s: %s'):format(r.name, ingredientNames(r.layers)), 0.33)
    end
end

local function drawStack()
    local title
    if #active.layers == 0 then
        title = 'Empty wrapper'
    else
        local ok = Recipes.check(active.layers)
        local _, name = Recipes.match(active.layers)
        title = ok and ('Ready to wrap: %s'):format(name) or ('%d layers'):format(#active.layers)
    end
    drawText(0.5 - 0.1, 0.06, title, 0.5)
    if active.hover then
        local ing = Config.Ingredients[active.hover]
        local label = ing.label
        if ing.item then
            label = ('%s (%d left)'):format(label, math.max(0, (active.have[ing.item] or 0) - usedOf(ing.item)))
        end
        drawText(0.5 - 0.05, 0.10, label, 0.4, 180, 220, 255)
    end
end

-- ============================================
-- Open and close
-- ============================================

local function close()
    if not active then return end
    local s = active
    active = nil
    for _, ent in pairs(s.props) do deleteProp(ent) end
    for _, ent in pairs(s.stackProps) do deleteProp(ent) end
    deleteProp(s.ghost)
    RenderScriptCams(false, true, 350, true, false)
    DestroyCam(s.cam, false)
    Whip.core:UnblockControls(BLOCK)
    Whip.core:HideText()
    Whip.core:SetScreenOpen(false, SCREEN)
end

local function wrap()
    local ok, why = Recipes.check(active.layers)
    if not ok then return Whip.core:Notify(why, 'error') end
    local layers, id = {}, active.st.id
    for i, key in ipairs(active.layers) do layers[i] = key end
    close()
    -- The server checks the stack and the patties, runs the bar and gives the burger.
    TriggerServerEvent('whip_burgershot:assembly:wrap', id, layers)
end

local function tick()
    local s = active
    SetMouseCursorActiveThisFrame()

    local point = cursorOnWorktop(s.cam, s.st.z)

    -- Which tray is under the mouse.
    local hover, hoverEnt
    if point then
        for _, t in ipairs(s.trays) do
            if flatDist(point, t.at) < 0.06 then hover, hoverEnt = t.ingredient, t.ent end
        end
    end
    if s.hoverEnt ~= hoverEnt then
        if s.hoverEnt then SetEntityDrawOutline(s.hoverEnt, false) end
        if hoverEnt then SetEntityDrawOutline(hoverEnt, true) end
        s.hoverEnt = hoverEnt
    end
    s.hover = hover

    -- What is in hand follows the mouse, a little above the worktop.
    if s.ghost and point then
        SetEntityCoordsNoOffset(s.ghost, point.x, point.y, s.st.z + 0.06, false, false, false)
    end
    local overWrapper = point and flatDist(point, s.wrapper) < 0.13

    if IsDisabledControlJustPressed(0, C.click) then
        if s.holding then
            if overWrapper then addLayer(s.holding) end
            deleteProp(s.ghost); s.ghost, s.holding = nil, nil
        elseif hover then
            if available(hover) then
                s.holding = hover
                local ing = Config.Ingredients[hover]
                s.ghost = spawnProp(ing.model or ing.trayModel, point or s.wrapper, s.st.heading)
                if s.ghost then SetEntityAlpha(s.ghost, 200, false) end
            else
                Whip.core:Notify('None left: cook more patties', 'error')
            end
        end
    elseif IsDisabledControlJustPressed(0, C.rclick) then
        if s.holding then
            deleteProp(s.ghost); s.ghost, s.holding = nil, nil
        else
            removeTop()
        end
    elseif IsDisabledControlJustPressed(0, C.hint) then
        s.hint = not s.hint
    elseif IsDisabledControlJustPressed(0, C.enter) or IsDisabledControlJustPressed(0, C.space) then
        return wrap()
    elseif IsDisabledControlJustPressed(0, C.esc) or IsDisabledControlJustPressed(0, C.back) then
        return close()
    end

    drawStack()
    if s.hint then drawHint() end
end

--- The worktop's real height under the station: a ray straight down from above it, against the map and objects (the
--- placed point can sit a little in or under a counter's top). The saved height when nothing is hit.
local function surfaceZ(st)
    local ped = PlayerPedId()
    local best
    -- A few points round the middle, in case the middle is a seam or a hole; the highest surface wins.
    for _, o in ipairs({ { 0, 0 }, { -0.2, 0.15 }, { 0.2, 0.15 }, { 0, 0.25 } }) do
        local p = worktop(st, o[1], o[2])
        -- From just above the saved point (not higher: a shelf or heat lamp over the counter must not be taken for it).
        local ray = StartExpensiveSynchronousShapeTestLosProbe(p.x, p.y, st.z + 0.25, p.x, p.y, st.z - 0.5, 1 + 16, ped, 7)
        local _, hit, at = GetShapeTestResult(ray)
        -- Only a surface right at the saved point: a ray that starts inside a thick counter top misses that top and
        -- finds something far below (a shelf, the floor), which put the whole view under the counter.
        if (hit == true or hit == 1) and math.abs(at.z - st.z) <= 0.15 and (not best or at.z > best) then best = at.z end
    end
    return best or st.z
end

--- Open the prep counter at a station.
---@param st table an assembly station { id, x, y, z, heading }
function Assembly.open(st)
    if active then return end
    -- Everything here sits on the worktop as it really is, not where the point was saved.
    st = { id = st.id, x = st.x, y = st.y, z = surfaceZ(st), heading = st.heading }
    local have, why = exports.whip_core:Callback('whip_burgershot:assembly:open', st.id)
    if type(have) ~= 'table' then
        return Whip.core:Notify(why or 'You cannot use this now', 'error')
    end

    active = { st = st, props = {}, trays = {}, layers = {}, stackProps = {}, have = have, hint = false }

    -- Face the counter.
    SetEntityHeading(PlayerPedId(), st.heading or 0.0)

    -- The trays and the wrapper.
    for _, t in ipairs(Config.Trays) do
        local ing = Config.Ingredients[t.ingredient]
        if ing then
            local model = ing.trayModel or ing.model
            -- Standing on the worktop, whichever way the model's origin was set.
            local lift = 0.0
            if IsModelInCdimage(GetHashKey(model)) then
                local min = GetModelDimensions(GetHashKey(model))
                lift = -min.z
            end
            local at = worktop(st, t.x, t.y, lift)
            local ent = spawnProp(model, at, st.heading)
            if ent then
                active.props[#active.props + 1] = ent
                -- A pocket ingredient they have none of shows faded.
                if ing.item and (have[ing.item] or 0) == 0 then SetEntityAlpha(ent, 90, false) end
                active.trays[#active.trays + 1] = { ingredient = t.ingredient, at = at, ent = ent }
            end
        end
    end
    active.wrapper = worktop(st, Config.Wrapper.x, Config.Wrapper.y)
    local paper = spawnProp(Config.Wrapper.model, active.wrapper, st.heading)
    if paper then active.props[#active.props + 1] = paper end
    -- The burger is built on top of the wrapper (a tray: it has a thickness).
    active.wrapperTop = 0.0
    local wrapHash = GetHashKey(Config.Wrapper.model)
    if IsModelInCdimage(wrapHash) then
        local min, max = GetModelDimensions(wrapHash)
        active.wrapperTop = math.max(0.0, max.z - min.z) * 0.5
    end

    -- Looking down over the wrapper from the cook's side. A kitchen often has a shelf or heat lamp over the counter: the
    -- camera must be under it, or all it shows is the shelf's top. So look from the worktop up to where the camera
    -- would be, and come down to just under anything in the way.
    local lookAt = worktop(st, 0.0, 0.16, 0.0)
    local camAt = worktop(st, 0.0, -0.32, 0.62)
    local from = lookAt + vector3(0.0, 0.0, 0.03)
    local ray = StartExpensiveSynchronousShapeTestLosProbe(from.x, from.y, from.z, camAt.x, camAt.y, camAt.z, 1 + 16,
        PlayerPedId(), 7)
    local _, blocked, hitAt = GetShapeTestResult(ray)
    if blocked == true or blocked == 1 then
        local dir = camAt - from
        local len = #dir
        local keep = math.max(0.15, #(hitAt - from) - 0.06)
        camAt = from + dir / len * keep
    end
    print(('[whip_burgershot] prep counter #%d: saved z %.2f, worktop z %.2f, camera %s%s, you at %s'):format(
        st.id, (Stations[st.id] or st).z, st.z, tostring(camAt), (blocked == true or blocked == 1) and ' (moved under something)' or '',
        tostring(GetEntityCoords(PlayerPedId()))))
    local cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', camAt.x, camAt.y, camAt.z, 0.0, 0.0, 0.0, 55.0, false, 2)
    PointCamAtCoord(cam, lookAt.x, lookAt.y, lookAt.z)
    SetCamActive(cam, true)
    RenderScriptCams(true, true, 350, true, false)
    active.cam = cam

    SetEntityDrawOutlineColor(80, 200, 255, 255)
    Whip.core:SetScreenOpen(true, SCREEN)
    Whip.core:BlockControls(BLOCK, { all = true, mode = true })
    Whip.core:ShowText('Prep counter | [LMB] Grab / place | [RMB] Undo | [ENTER] Wrap | [H] Recipes | [ESC] Close',
        { icon = 'place' })

    CreateThread(function()
        while active do
            -- Walked off, died or ragdolled: the counter closes.
            local ped = PlayerPedId()
            if IsEntityDead(ped) or IsPedRagdoll(ped) or #(GetEntityCoords(ped) - vector3(st.x, st.y, st.z)) > 3.0 then
                close()
                break
            end
            tick()
            Wait(0)
        end
    end)
end

AddEventHandler('whip_core:player:died', close)
AddEventHandler('whip_core:player:logout', close)
AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then close() end
end)
