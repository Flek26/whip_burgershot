fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'whip_burgershot'
description 'Burger Shot for whip: a grill, a fryer, a drinks machine, a prep counter where burgers are built layer by layer, packing, and a counter that sells what the staff made. Models and pictures: BzZz fastfood (bzzz_fastfood).'
version '0.2.0'
author 'Flek'

-- Everything goes through whip_core: the job and duty (EnsureJob, ClockOn), the stations' places (PlaceObject, saved in
-- a table of our own), the bars (Progress), the food on the grill (ShowPropSet), food in the hands (HoldProps), and the
-- counter (a stocked shop whose takings go to the job's business account).
shared_script '@whip_core/lib/satellite.lua'
shared_script 'config.lua'
shared_script 'shared/recipes.lua'   -- what a stack of layers is
shared_script 'shared/grid.lua'      -- where the food sits on a grill or fryer

client_scripts {
    'client/stations.lua',   -- the prompts at each station, and what is cooking
    'client/effects.lua',    -- smoke over the grill and fryer, the kitchen's sounds
    'client/assembly.lua',   -- the counter's top-down view: grab, place, wrap
    'client/placer.lua',     -- /bsplace: an admin puts a station down
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',            -- the stations' places, in a table of our own (EnsureTable)
    '@whip_core/server/db_guard.lua',    -- whip's guard on it: a database that does not answer errors after a limit
    'server/main.lua',       -- the job, the items, eating and drinking, the counter shop
    'server/stations.lua',   -- where the stations are, and what each one does
}

-- The sound page (client/effects.lua), the sounds you add, and the items' pictures (copied from bzzz_fastfood).
ui_page 'html/index.html'
files {
    'html/index.html',
    'html/sounds/*.ogg',
    'html/sounds/*.mp3',
    'html/img/items/*.png',
}

-- The models and the two eating animations are streamed by the pack.
dependencies { 'whip_core', 'oxmysql', 'bzzz_fastfood' }
whip_requires '1.0'
