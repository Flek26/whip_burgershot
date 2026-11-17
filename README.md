# whip_burgershot

A Burger Shot job for whip: a grill, a fryer, a drinks machine, a prep counter where burgers are built layer by layer
from props, packing (boxes, meals, takeaway), and a counter that sells what the staff made.

Models, item pictures and the two eating animations come from **BzZz's fastfood pack** (https://bzzz.tebex.io/package/5811456). The pack's item keys are its model names, so every item here has the pack's prop and picture.

Built on whip_core's own systems: the job and duty (`EnsureJob`, `ClockOn`), whip's prop placer (`PlaceObject`),
server-timed bars (`Progress`), `ShowPropSet` for food on the grill, `HoldProps` for food in the hands, and a stocked
shop whose takings go to the job's business account.

## Setup

1. Add `ensure whip_burgershot` to `server.cfg`, below the whip resources and `[assets]`.
2. Restart the server. The job **Burger Shot** is created.
3. Hire yourself: `/whip` → Economy → Jobs → Burger Shot. Give the job an owner there too, or the counter's takings
   have no business account to go to.
4. With developer mode on (`/w`), place each station with `/bsplace <kind>` (`/bsremove` takes away the nearest):

   | kind | what it is | where to aim |
   |---|---|---|
   | `duty` | time clock | anywhere staff pass |
   | `fridge` | raw patties, frozen fries / nuggets / onion rings, raw chicken, salads, noodles | the fridge |
   | `grill` | patties: raw → cooked → burnt, the prop changes as it cooks | the middle of the hotplate |
   | `fryer` | fries (3 sizes), nuggets, onion rings, chicken strips / legs / bites | the middle of the fryer |
   | `drinks` | big and small drinks, two ice creams | the drinks machine |
   | `assembly` | the prep counter (top-down view) | the middle of the worktop, **turned so you face it** |
   | `bagging` | box a burger, make a meal, takeaway box, stock the counter | the packing area |
   | `register` | the counter: a cashier sells what staff stocked | where the cashier stands |

5. Item pictures (not in this repo; they are the pack's). Copy every `.png` from
   `[assets]/bzzz_fastfood/data/burgershot/images_for_inventory/` into `whip_burgershot/html/img/items/`
   (create the folder). That is 50 files named `bzzz_fastfood_burgershot_<name>.png`, and these are the ones used:

   `bigburger_a` `bigburger_b` `box_a`–`box_g` `bun_a` `bun_b` `bun_c` `cheese_a` `cheeseburger_a` `cheeseburger_b`
   `chicken_a`–`chicken_f` `drink_a` `drink_b` `fries_a`–`fries_d` `icecream_a` `icecream_b` `ketchup` `mayonnaise`
   `meat_a` `meat_b` `meat_c` `menu_a`–`menu_d` `noodle_a` `noodle_b` `nugget_a` `nugget_b` `onion_a` `onion_b`
   `salad_a` `tray_a` `tray_b` `tray_c` `vegesalad_a` `vegesalad_b`

   On Windows, from the `resources` folder:

   ```bat
   mkdir whip_burgershot\html\img\items
   copy "[assets]\bzzz_fastfood\data\burgershot\images_for_inventory\*.png" whip_burgershot\html\img\items\
   ```

   The items that are not pack models (frozen fries, frozen nuggets, frozen onion rings, raw chicken, the custom
   burger, the takeaway box) reuse those pictures, so nothing else is needed. Without the folder, items show with no
   picture; everything else works.
6. Sounds: put `sizzle.ogg`, `fryer.ogg`, `pour.ogg` and `wrap.ogg` in `html/sounds/` (see the note there). Without
   them the kitchen is silent; everything else works.

## The work

1. **Fridge** → raw patties and frozen food.
2. **Grill / fryer**: put it on. The prompt counts down to ready; steam rises while it cooks, dark smoke once something
   burns. Take it off in time: a burnt patty makes a burnt burger, burnt fries are half as filling.
3. **Prep counter**: Build a burger. Click a tray, click the tray in front to lay it on; right-click undoes, **H** shows
   the recipes, **Enter** wraps, **Esc** leaves. Patties come from your pockets.
   - **Cheeseburger**: bottom bun, ketchup, patty, cheese, top bun
   - **Bigburger**: bottom bun, mayonnaise, lettuce, patty, cheese, patty, cheese, top bun
   - anything else with a bun at each end: a plain **Burger**
4. **Drinks**: pour a drink or an ice cream.
5. **Packing**: box a burger, make a meal (burger / nuggets / chicken legs / strips with fries), or fill a takeaway box
   with anything. Boxes and meals open back into their food when used. **Put food on the counter** stocks the shelf,
   priced from `Config.Counter.prices` the first time (a manager with `canManage` can reprice it).
6. **Customers** buy from the cashier; the money goes to the job's business account.

Eating uses the pack's own animations and props: two-handed for boxed food (the box in one hand, a piece in the other).
