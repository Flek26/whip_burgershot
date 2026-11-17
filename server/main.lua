-- ============================================
-- whip_burgershot — server: the job, the items, eating and drinking, the counter
-- ============================================
--
-- Everything is declared in Whip.register, so a whip_core restart declares it again. The stations themselves (where
-- they are, what is on the grill) are server/stations.lua.

local JOB = Config.Job
local IMG = 'html/img/items/%s.png'

-- ============================================
-- Eating and drinking
-- ============================================
--
-- Not a declared timed use: whip's bar holds one prop, and the pack's boxed food is held in two hands (the box, and a
-- piece of it). So: the props go in the hands (HoldProps), the server's Progress runs the pack's animation, and only
-- then is the item taken (it must still be there) and the stat given.

local eating = {}   -- [source] = true while a bar runs

local function eat(source, slotData, addr)
    local def = Config.Items[slotData.item]
    if eating[source] then return end
    eating[source] = true

    local drink = def.thirst and not def.hunger
    if def.use and def.use.props then Whip.core:HoldProps(source, def.use.props, 'eat') end
    local done = Whip.core:Progress(source, {
        label = ('%s %s...'):format(drink and 'Drinking' or 'Eating', def.name),
        duration = drink and Config.DrinkTime or Config.EatTime,
        anim = def.use and def.use.anim, icon = 'eat', canCancel = true,
        disable = { move = false },
    })
    Whip.core:DropHeldProps(source, 'eat')
    eating[source] = nil
    if not done then return end

    -- Still there, still the same item: then take it and feed them.
    local now = Whip.core:GetItemAt(addr)
    if not now or now.item ~= slotData.item then return end
    local taken = Whip.core:StoreTake(addr, 1, { reason = 'eaten' })
    if not taken then return end
    local factor = (now.metadata and now.metadata.burnt) and Config.BurntFactor or 1.0
    if def.hunger then Whip.core:AddStat(source, 'hunger', math.floor(def.hunger * factor), 'item:' .. slotData.item) end
    if def.thirst then Whip.core:AddStat(source, 'thirst', math.floor(def.thirst * factor), 'item:' .. slotData.item) end
end

--- A meal with nothing recorded in it (stocked by hand, given by an admin): the first choice of each of its lines.
local function mealDefault(itemKey)
    for _, m in ipairs(Config.Meals) do
        if m.item == itemKey then
            local list = {}
            for _, line in ipairs(m.needs) do list[#list + 1] = { item = line[1] } end
            return list
        end
    end
    return {}
end

--- A box or a meal: opened, it hands back what is in it (its metadata.contents, or the item's `opens`, or a meal's
--- usual contents). whip calls a use handler with (source, player, slotData, addr).
local function open(source, _, slotData)
    local def = Config.Items[slotData.item]
    if not def then return false end
    local contents = slotData.metadata and slotData.metadata.contents
    if type(contents) ~= 'table' or #contents == 0 then
        contents = {}
        for _, key in ipairs(def.opens or {}) do contents[#contents + 1] = { item = key } end
        if #contents == 0 then contents = mealDefault(slotData.item) end
    end
    -- Nothing to give (an empty takeaway box): keep it rather than eat it for nothing.
    if #contents == 0 then return false end
    for _, c in ipairs(contents) do
        if type(c) == 'table' and type(c.item) == 'string' then
            -- AddItem drops at their feet what does not fit: nothing in the box is lost.
            exports.whip_core:AddItem(source, c.item, 1, c.metadata, 'opened ' .. def.name)
        end
    end
    return true   -- the box or meal is used up
end

-- ============================================
-- Declarations
-- ============================================

Whip.register(function()
    Whip.core:EnsureJob(JOB, { name = Config.JobName, icon = 'eat', roles = Config.Roles })

    for key, it in pairs(Config.Items) do
        local edible = (it.hunger or it.thirst) ~= nil
        local opens = it.meal or it.opens ~= nil
        Whip.core:RegisterItem(key, {
            name = it.name, desc = it.desc, weight = it.weight,
            type = (edible or opens) and 'consumable' or 'ingredient',
            stack = it.stack ~= false, maxStack = it.stack == false and 1 or 20,
            usable = edible or opens,
            prop = key:find(Config.Prefix, 1, true) == 1 and key or (it.image or nil),
            image = IMG:format(it.image or key),
            metaFields = it.meal and { { key = 'summary', label = 'Inside' } } or { { key = 'quality', label = 'Quality' } },
        })
        if opens then
            Whip.core:RegisterUseHandler(key, open)
        elseif edible then
            -- false keeps the item: eat() takes it when the bar has run.
            Whip.core:RegisterUseHandler(key, function(source, _, slotData, addr)
                CreateThread(function() eat(source, slotData, addr) end)
                return false
            end)
        end
    end
end)

AddEventHandler('playerDropped', function() eating[source] = nil end)

-- ============================================
-- The counter: a stocked shop, its shelf a container, at the register station
-- ============================================

Counter = {}

local SHOP_KEY, STOCK_KEY = 'burgershot', 'burgershot:counter'

--- Put the counter at a register station: its shelf there, and the keeper selling from it at the cashier station
--- (/bsplace cashier, where an admin stood). No cashier yet: the keeper stands at the register, as before.
---@param st table a register station { x, y, z, heading }
---@param cashier table|nil a cashier station { x, y, z, heading }
---@return boolean ok
---@return string|nil why
function Counter.ensure(st, cashier)
    local keeper = cashier or st
    local stock, why = Whip.core:EnsureContainer(STOCK_KEY, {
        name = 'Burger Shot counter', slots = Config.Counter.slots, maxWeight = Config.Counter.maxWeight,
        -- A declared container must have a prop (EnsureContainer refuses false): Config.Counter.shelfProp.
        x = st.x, y = st.y, z = st.z, heading = st.heading, prop = Config.Counter.shelfProp or Config.Stations.register.ghost,
        requirements = { jobs = JOB, onDuty = true },   -- staff only: customers buy through the shop
    })
    if not stock then return false, why end

    local shop
    shop, why = Whip.core:EnsureShop(SHOP_KEY, {
        name = Config.Counter.shopName, mode = 'stocked', jobId = JOB, containerId = stock.containerId,
        npcModel = Config.Counter.npcModel,
        x = keeper.x, y = keeper.y, z = keeper.z, heading = keeper.heading,
        blipSprite = Config.Counter.blipSprite, blipColor = Config.Counter.blipColor,
    })
    if not shop then return false, why end
    Counter.containerId = stock.containerId
    return true
end

--- Take the counter away: the shop (its keeper and prompt go with it), then its shelf and whatever is on it. When the
--- last register is removed, and at start when there is none.
---@return boolean removedAny
function Counter.remove()
    local any = false
    local shop = Whip.core:GetShop({ key = SHOP_KEY })
    if shop and shop.shopId then
        local ok, why = Whip.core:DeleteShop(shop.shopId)
        if ok then any = true else print(('[whip_burgershot] could not remove the counter\'s shop: %s'):format(tostring(why))) end
    end
    local stock = Whip.core:GetContainer({ key = STOCK_KEY })
    local stockId = stock and (stock.containerId or stock.id)
    if stockId then
        local ok, why = Whip.core:DeleteContainer(stockId)
        if ok then any = true else print(('[whip_burgershot] could not remove the counter\'s shelf: %s'):format(tostring(why))) end
    end
    Counter.containerId = nil
    return any
end

--- Is the counter's shop here? (Its keeper, or the register it stood at.) For /bsremove.
function Counter.near(at, range)
    local shop = Whip.core:GetShop({ key = SHOP_KEY })
    if shop and shop.x and #(at - vector3(shop.x, shop.y, shop.z)) <= range then return true end
    local stock = Whip.core:GetContainer({ key = STOCK_KEY })
    if stock and stock.x and #(at - vector3(stock.x, stock.y, stock.z)) <= range then return true end
    return false
end

--- Put food from a cook's pockets on the shelf, priced from Config.Counter.prices where it has no price yet.
---@param source number
---@return integer moved  how many stacks went on
---@return string|nil why
function Counter.stockFrom(source)
    if not Counter.containerId then return 0, 'The counter has not been placed yet' end
    local prices = Whip.core:GetShopPrices({ shopId = (Whip.core:GetShop({ key = SHOP_KEY }) or {}).shopId }) or {}
    local moved = 0
    for itemKey, price in pairs(Config.Counter.prices) do
        for _, found in ipairs(Whip.core:FindAllItems(source, itemKey) or {}) do
            local ok = Whip.core:StoreMove(found.addr, { kind = 'container', id = Counter.containerId },
                { reason = 'stocked the Burger Shot counter' })
            if ok then
                moved = moved + 1
                if not prices[itemKey] then
                    Whip.core:SetShopItemPrice(Counter.containerId, itemKey, price, true)
                    prices[itemKey] = { price = price, forSale = true }
                end
            end
        end
    end
    if moved == 0 then return 0, 'You have nothing the counter sells' end
    return moved
end

Whip.sayStarted()
