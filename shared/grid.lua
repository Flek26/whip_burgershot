-- Where the food sits on a grill or fryer: a grid of slots centred on the station's point, turned to its heading. One
-- rule for the server (which slot is free, filled from the middle) and each game (which draws the food there).

Grid = {}

--- Slot n's place in a grid centred on (0, 0): `columns` across, as many rows as it takes.
local function rawOffset(cfg, n)
    local rows = math.ceil(cfg.slots / cfg.columns)
    local col = (n - 1) % cfg.columns
    local row = (n - 1) // cfg.columns
    return (col - (cfg.columns - 1) / 2) * cfg.spacing, (row - (rows - 1) / 2) * cfg.spacing
end

--- Slot n's place, in metres from the station's point. The slot filled first sits ON the point (where the prompt
--- and the smoke are, where the admin placed it); the others are laid out from there.
---@return number across, number back
function Grid.offset(cfg, n)
    local first = Grid.fillOrder(cfg)[1]
    local fx, fy = rawOffset(cfg, first)
    local x, y = rawOffset(cfg, n)
    return x - fx, y - fy
end

--- A point in the station's frame (x across, y back, z up) in the world.
function Grid.world(st, x, y, z)
    local h = math.rad(st.heading or 0.0)
    return vector3(
        st.x + math.cos(h) * x - math.sin(h) * y,
        st.y + math.sin(h) * x + math.cos(h) * y,
        st.z + (z or 0.0))
end

--- Where a station's sign stands, and the way it faces: `up` over the point, `out` toward the cook (who stands at the
--- station's back), turned to face them. nil heading: no sign (a label that faces the player).
---@param st table  { kind, x, y, z, heading, item? }
---@return vector3 at, number|nil heading, number|nil tilt  degrees it leans back (90: flat, face up)
function Grid.sign(st)
    local def = Config.Stations[st.kind] or {}
    local s = def.sign
    local up = s and s.up or 0.25
    local food = st.kind == 'fridge' and st.item and Config.FridgeById[st.item]
    if food then
        s = Config.FridgeItemSign
        -- On top of the food: its model's top (the point is its origin, as placed), then `above`.
        local top = 0.05
        local hash = GetHashKey(food.model)
        if not IsDuplicityVersion() and IsModelInCdimage(hash) then
            if not HasModelLoaded(hash) then RequestModel(hash) end
            local _, max = GetModelDimensions(hash)
            if max and max.z > 0.0 then top = max.z end
        end
        up = top + (s.above or 0.02)
    end
    if not s then return vector3(st.x, st.y, st.z + 0.25), nil, nil end
    local h = math.rad(st.heading or 0.0)
    local out = s.out or 0.0
    -- The station faces (-sin h, cos h); the cook is the other way.
    return vector3(st.x + math.sin(h) * out, st.y - math.cos(h) * out, st.z + up),
        ((st.heading or 0.0) + 180.0) % 360.0, s.tilt
end

--- A sign's corners and the way its face points, as whip's sign prompt draws it (client/interact_world.lua
--- signOrientation): right (-cos h, -sin h, 0), up (sin t sin h, -sin t cos h, cos t). For the placer's preview.
---@return vector3 right, vector3 up, vector3 normal
function Grid.signAxes(heading, tilt)
    local h, t = math.rad(heading), math.rad(tilt or 0.0)
    local sinH, cosH, sinT, cosT = math.sin(h), math.cos(h), math.sin(t), math.cos(t)
    return vector3(-cosH, -sinH, 0.0),
        vector3(sinT * sinH, -sinT * cosH, cosT),
        vector3(-sinH * cosT, cosH * cosT, sinT)
end

--- The order slots are filled in: nearest the station's point first.
function Grid.fillOrder(cfg)
    if cfg._order then return cfg._order end
    local order = {}
    for n = 1, cfg.slots do order[n] = n end
    table.sort(order, function(a, b)
        local ax, ay = rawOffset(cfg, a)
        local bx, by = rawOffset(cfg, b)
        local da, db = ax * ax + ay * ay, bx * bx + by * by
        if math.abs(da - db) > 1e-6 then return da < db end
        return a < b
    end)
    cfg._order = order
    return order
end
