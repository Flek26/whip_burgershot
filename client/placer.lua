-- ============================================
-- whip_burgershot — client: /bsplace, an admin puts a station down
-- ============================================
--
-- The server's /bsplace (whip.devtools, developer mode) sends the kind here; whip's own PlaceObject shows a ghost of the
-- station's prop where the admin looks. What it answers is sent back and checked there (near them, saved).
--
-- Put each one where it is used: the grill's point is the middle of its plate (patties are laid out round it, facing
-- the way you turned it), the prep counter's is the middle of the worktop, turned so its trays are behind the wrapper.

-- ============================================
-- The sign's preview: where the prompt will stand, drawn while the ghost is aimed
-- ============================================
--
-- whip's placer owns its ghost and does not hand it over, so it is found: the see-through (alpha 160), unnetworked
-- object of the ghost's model nearest the player. The sign is worked out from it as from a placed station
-- (shared/grid.lua Grid.sign): a white panel where the prompt will be, readable from the side it shows on, with the
-- station's name, and a line down to the point.

local previewing = false

local function findGhost(hash)
    local here = GetEntityCoords(PlayerPedId())
    local best, bestD
    for _, obj in ipairs(GetGamePool('CObject')) do
        if GetEntityModel(obj) == hash and GetEntityAlpha(obj) == 160 and not NetworkGetEntityIsNetworked(obj) then
            local d = #(GetEntityCoords(obj) - here)
            if d < 15.0 and (not bestD or d < bestD) then best, bestD = obj, d end
        end
    end
    return best
end

local function text3d(at, words)
    SetDrawOrigin(at.x, at.y, at.z, 0)
    SetTextScale(0.0, 0.30)
    SetTextFont(4)
    SetTextCentre(true)
    SetTextOutline()
    SetTextColour(255, 255, 255, 230)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(words)
    EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end

local function previewSign(kind, item, ghostModel, label)
    previewing = true
    local hash = GetHashKey(ghostModel)
    CreateThread(function()
        local ghost
        local W, H = 0.16, 0.05   -- half the panel's width and height
        while previewing do
            if not ghost or not DoesEntityExist(ghost) then ghost = findGhost(hash) end
            if ghost and IsEntityVisible(ghost) then
                local p = GetEntityCoords(ghost)
                local st = { kind = kind, item = item ~= 'all' and item or nil, x = p.x, y = p.y, z = p.z,
                             heading = GetEntityHeading(ghost) }
                local at, heading, tilt = Grid.sign(st)
                DrawLine(p.x, p.y, p.z, at.x, at.y, at.z, 255, 255, 255, 120)
                if heading then
                    -- The panel's corners from its right and up, as whip's sign prompt has them (flat when tilted 90).
                    local r, u, n = Grid.signAxes(heading, tilt)
                    local a = at - r * W - u * H
                    local b = at + r * W - u * H
                    local c = at + r * W + u * H
                    local d = at - r * W + u * H
                    -- Both windings: the panel shows from either side (its words only make sense from the front).
                    DrawPoly(a.x, a.y, a.z, b.x, b.y, b.z, c.x, c.y, c.z, 255, 255, 255, 70)
                    DrawPoly(a.x, a.y, a.z, c.x, c.y, c.z, d.x, d.y, d.z, 255, 255, 255, 70)
                    DrawPoly(c.x, c.y, c.z, b.x, b.y, b.z, a.x, a.y, a.z, 255, 255, 255, 70)
                    DrawPoly(d.x, d.y, d.z, c.x, c.y, c.z, a.x, a.y, a.z, 255, 255, 255, 70)
                    DrawLine(a.x, a.y, a.z, b.x, b.y, b.z, 255, 255, 255, 220)
                    DrawLine(b.x, b.y, b.z, c.x, c.y, c.z, 255, 255, 255, 220)
                    DrawLine(c.x, c.y, c.z, d.x, d.y, d.z, 255, 255, 255, 220)
                    DrawLine(d.x, d.y, d.z, a.x, a.y, a.z, 255, 255, 255, 220)
                    -- Which way it reads: a short line out of its face (up, when it lies flat), and the way its top
                    -- points (away from the cook).
                    local f = at + n * 0.12
                    DrawLine(at.x, at.y, at.z, f.x, f.y, f.z, 96, 165, 250, 255)
                    local top = at + u * (H + 0.06)
                    DrawLine(at.x, at.y, at.z, top.x, top.y, top.z, 74, 222, 128, 255)
                end
                text3d(at, label)
            end
            Wait(0)
        end
    end)
end

-- A fridge spot of one food (/bsplace fridge patty) shows that food as the ghost: where it sits is where it will be.
RegisterNetEvent('whip_burgershot:startPlacing', function(kind, item)
    local def = Config.Stations[kind]
    if not def then return end
    local food = kind == 'fridge' and Config.FridgeById[item or ''] or nil
    local ghost = food and food.model or def.ghost
    local label = food and (def.label .. ': ' .. food.label) or def.label
    previewSign(kind, food and item or nil, ghost, food and food.label or def.label)
    local spot, why = Whip.core:PlaceObject(ghost, { label = label, reach = 6.0 })
    previewing = false
    if not spot then
        if why ~= 'cancelled' then Whip.core:Notify('Not placed: ' .. tostring(why), 'error') end
        return
    end
    TriggerServerEvent('whip_burgershot:placed', kind, spot.coords.x, spot.coords.y, spot.coords.z, spot.rot.z,
        food and item or 'all')
end)
