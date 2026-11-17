-- What a stack of layers is. One rule for the counter's view (client/assembly.lua: the hint, the Wrap check) and for the
-- server (server/stations.lua), which decides.

Recipes = {}

--- Can this stack be wrapped? A bun at each end, known layers, not too many.
---@param layers string[]
---@return boolean ok
---@return string|nil why
function Recipes.check(layers)
    if type(layers) ~= 'table' or #layers < 3 then return false, 'A burger needs a bun, a filling and a bun' end
    if #layers > Config.MaxLayers then return false, ('At most %d layers'):format(Config.MaxLayers) end
    for _, key in ipairs(layers) do
        if not Config.Ingredients[key] then return false, 'Unknown ingredient' end
    end
    if layers[1] ~= 'bun_bottom' then return false, 'Start with a bottom bun' end
    if layers[#layers] ~= 'bun_top' then return false, 'Finish with a top bun' end
    for i = 2, #layers - 1 do
        if layers[i] == 'bun_bottom' or layers[i] == 'bun_top' then return false, 'Buns go at the ends' end
    end
    return true
end

--- How many of each pocket item the stack uses (the patties).
---@param layers string[]
---@return table<string, integer>
function Recipes.itemsUsed(layers)
    local used = {}
    for _, key in ipairs(layers) do
        local item = Config.Ingredients[key] and Config.Ingredients[key].item
        if item then used[item] = (used[item] or 0) + 1 end
    end
    return used
end

--- The burger a stack makes. A burnt patty counts as a patty for the recipe, and makes it worse.
---@param layers string[]
---@return string itemKey
---@return string name
---@return boolean burnt
function Recipes.match(layers)
    local burnt = false
    local plain = {}
    for i, key in ipairs(layers) do
        if key == 'patty_burnt' then burnt = true; key = 'patty' end
        plain[i] = key
    end
    for itemKey, r in pairs(Config.Recipes) do
        if #r.layers == #plain then
            local same = true
            for i = 1, #plain do
                if r.layers[i] ~= plain[i] then same = false; break end
            end
            if same then return itemKey, r.name, burnt end
        end
    end
    return 'bs_burger_custom', 'Burger', burnt
end
