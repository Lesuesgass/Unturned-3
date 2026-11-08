# Greyfall

An original open-world zombie survival game for Roblox. You scavenge towns, manage food,
water and infection, fight zombies, gather resources and build bases that other players can
raid. "Greyfall" is a working title, so rename it freely.

This folder holds only original code. It contains no code, maps, models, fonts or sounds from
any other game. All the world geometry is generated from plain parts and terrain when the
server starts.

## Fastest way to try it

If someone has built `Greyfall.rbxl` for you (`rojo build -o Greyfall.rbxl`), install
**Roblox Studio**, double-click the file (or use File, Open from File in Studio) and press
**Play**. No other tools are needed. Use the Rojo setup below when you want to edit the code
and see changes live.

## Getting it running (first time with Roblox)

1. Install **Roblox Studio** from the Roblox website and sign in.
2. Install **Rojo**, the tool that syncs these files into Studio:
   * In Studio, open the **Toolbox**, search the Plugins tab for "Rojo" (published by Rojo), and install it.
   * Install the matching command-line tool. With Rust installed, run:

     ```bash
     cargo install rojo --locked
     ```

3. Start the sync server from this folder:

   ```bash
   cd Greyfall
   ```

   ```bash
   rojo serve
   ```

4. In Studio, create a new **Baseplate** place, delete the `Baseplate` part from Workspace,
   open the Rojo plugin and click **Connect**. The scripts appear in ReplicatedStorage,
   ServerScriptService and StarterPlayer.
5. Press **Play**. The server generates the map (a few seconds on Kestrel Island, longer on
   Ridgeline), then spawns you on the coast.

To build a place file without Studio running, use `rojo build -o Greyfall.rbxl`.

### Main menu (work in progress)

The first player in a server is the host and sees the main menu:

* **Mode**: Singleplayer turns away anyone else who tries to join the server. Multiplayer
  lets others join while you play. Proper private servers for singleplayer need the game
  to be published (Roblox reserved servers), which is planned for a later build.
* **Map**: Kestrel Island or Ridgeline.
* **Difficulty**: Easy, Medium or Hard (rules below).

Other players who join before the host starts see a waiting screen, then the loading screen
while the world is generated. The pre-selected choices are in `src/shared/Config.luau`.

### Difficulty

| Rule | Easy | Medium | Hard |
|---|---|---|---|
| Bleeding | Off | On | On |
| Zombie hit causes bleeding | Never | 5% | 15% |
| Weapon hit causes bleeding | Never | The weapon's own chance | 1.5 times the weapon's chance |
| Loot | Full | Half | A quarter |
| Zombie damage | 75% | 100% | 130% |
| Immunity lost per zombie hit | 60% | 100% | 140% |
| Zombies per town | 75% | 100% | 130% |
| Hunger and thirst | 80% | 100% | 120% |

Loot halves with each step, so it gets exponentially scarcer: fewer loot spots start filled,
refills are less likely, and refills take twice as long per step.

Weapon bleed chances on Medium: kitchen knife 35%, scrap knife 30%, wooden club 5%,
crowbar 10%, machete 40%, fire axe 30%, pickaxe 20%, service pistol 25%, pump shotgun 30%,
hunting rifle 45%, carbine 30%. Fists never cause bleeding.

## Controls

| Key | Action |
|---|---|
| WASD, Space | Move, jump |
| Left Shift | Sprint (uses stamina) |
| Left click | Attack, shoot, place a structure, plant a charge, repair. With empty hands it punches |
| R | Reload |
| 1 to 5 | Equip a hotbar slot, press again to put it away |
| F | Pick up, open doors, open your storage |
| Tab or I | Inventory |
| C | Crafting |
| X | Salvage your own structure (hammer equipped) |
| V | First or third person |
| H | Show or hide the controls list in game |
| K | Customize your look |

## Your survivor

Everyone has the same blocky body and the same clothes (slate shirt, dark trousers, boots).
Roblox avatars are not used. What you choose is the head: skin tone (8), hair style (7), hair
colour (8, also used for facial hair), eyes (8, including red eyes), mouth (7, including a
grin) and facial hair (6). Set it from **Customization** in the main menu, from the waiting
screen, or with **K** during play; saving applies it straight away. Choices are saved between
sessions once the game is published (or in Studio with API access to DataStores turned on).

## Survival

* **Food** and **water** drain over time; water drains twice as fast while sprinting. Either one
  at zero drains health.
* **Health** regenerates slowly while food and water are both above 60 and infection is low.
* **Immunity** starts full and falls with every zombie hit. Below 50 it drains health, and
  health only regenerates while it is above 75. Antibiotics (+50) and medkits (+10) restore it.
* **Oxygen** appears when you need it: it drains with your head under water (about 25
  seconds of air) and, more slowly, above 240 studs over sea level. At zero you take damage.
  It refills quickly once you can breathe.
* **Bleeding** can start from a zombie or weapon hit (see Difficulty) and drains health until
  you use a bandage or medkit.
* **Fists**: with nothing equipped, left click punches (one punch every 0.4 seconds). A zombie
  goes down in 5 to 6 punches. Your own swing, hit sound and impact play the instant you click.
  In first person your fists come up into view for a moment with every punch.
* **Hotbar**: any item can go in a hotbar slot (pick a slot number in the inventory). Weapons
  and tools are held; bandages, dressings, food and drinks are used with a left click.
  Medical items fill a free slot automatically when picked up.
* **Bandage** heals 15 and stops bleeding (2 cloth). **Dressing** heals 30 and stops bleeding
  (3 cloth and a bandage).
* **Carry weight** is 12 kg, plus whatever your worn backpack adds.
* Death drops everything you carried where you fell.

## Maps

* **Kestrel Island** (2304 x 2304 studs) is a rural island with a central town, two fishing
  villages, two farms, a lighthouse, a hilltop radar station and forest cabins.
* **Ridgeline** (3584 x 3584 studs) is a mainland map with a port city on the west coast, a
  valley town, a river village, farms, a fenced military base, a forest hamlet, a mountain pass
  village and a lodge up in the eastern mountains.

Towns include **large houses**: two storeys with an inside staircase and a railed stairwell.

Regular houses are split into rooms: a living room at the front (sofa, coffee table, TV,
shelves, cabinet, lamp) and a bedroom (bed, nightstand, wardrobe), a tiled bathroom (bath,
toilet, sink and mirror) and a kitchen (counter with wall cabinets, stove, fridge, table) along
the back. Large houses have a living room and kitchen downstairs, bedrooms and a bathroom
upstairs.

Every building is furnished: beds, tables, chairs, kitchen counters, fridges, sofas, shelves,
wardrobes, store aisles, hospital beds, police lockers, bunk beds, warehouse racks, crates,
barrels and workbenches. Loot sits on the furniture as well as on the floor.

Outside, houses have fenced yards and mailboxes, town streets have lamp posts that light up at
night, parked cars, benches and bins, roads between towns are lined with power poles, farms
have hay bales and fenced crop fields, fishing villages have a pier with moored boats, the
military bases have tents and sandbag walls, and bushes (some flowering or with berries) fill
the countryside. Long roads have a gas station halfway along, every road has a name board where
it enters a town, and the forests hide abandoned campsites and hunting stands with loot.

Trees are tall with full crowns: layered pines, white birches with dark bark marks and wide
maples in autumn colours.

Each town has its own loot (residential, store, medical, police, military, industrial, farm,
vehicle wrecks) and its own zombie zone. Zones fill up when players come near and empty after
everyone leaves.

## Gathering

| Resource | Where | Best tool | Gives |
|---|---|---|---|
| Pine, birch, maple trees | Forests, fields | Fire Axe | Pine, birch or maple logs |
| Rocks | Hills, open ground | Pickaxe | Stone |
| Vehicle wrecks | Along roads | Crowbar | Scrap metal |

## Base building

Equip a building piece and a see-through preview follows your aim. Green means it fits, red
means something is in the way. Click to place. You cannot build inside towns.

Building works on an 8 x 8 stud grid:

* **Foundation**: rests on the ground. Aim at the side of a foundation to extend it.
* **Wall** and **Doorway**: aim at a foundation or floor, on the side where you want the wall.
* **Door**: aim at a doorway. Only you can open your doors.
* **Floor**: aim at the top of a wall, at another floor, or at a foundation (places a ceiling
  above it).
* **Stairs**: aim at a foundation or floor. They rise away from you.
* **Wooden Crate** and **Metal Locker**: storage you can put on any flat surface. Only you can
  open them.

Every piece comes in five tiers, from weakest to strongest:

| Tier | Material | How the material is made | Wall health |
|---|---|---|---|
| Pine | Pine Planks | 1 pine log into 3 planks | 250 |
| Birch | Birch Planks | 1 birch log into 3 planks | 340 |
| Maple | Maple Planks | 1 maple log into 2 planks | 440 |
| Brick | Bricks | 3 stone and 1 charcoal into 2 bricks | 900 |
| Metal | Metal Plate | 3 scrap metal into 1 plate, needs a **blowtorch** | 1600 |

Charcoal comes from burning a pine log (needs a matchbox, which is not used up).
Piece costs, in units of the tier material (metal in brackets): foundation 6 (4), wall 4 (3),
doorway 3 (2), door 4 (3), floor 4 (3), stairs 5 (4). Every structure needs a **hammer**
in your inventory to craft. Foundations get 1.5 times the wall health, doorways 0.9,
floors and stairs 0.8, doors 0.7.

## Raiding

Structures have health. What damages them depends on the tier:

| Damage type | Pine | Birch | Maple | Brick | Metal |
|---|---|---|---|---|---|
| Melee | 100% | 80% | 65% | 12% | none |
| Bullets | 100% | 80% | 60% | 8% | none |
| Explosives | 100% | 100% | 100% | 75% | 50% |

* **Pipe Charge**: 1 scrap metal, 3 gunpowder, 1 cloth. 240 structure damage, 8 stud radius,
  6 second fuse.
* **Demolition Charge**: 2 metal plates, 10 gunpowder. 760 structure damage, 11 stud radius,
  8 second fuse.
* **Gunpowder**: 2 fertilizer (farms) and 1 charcoal into 2 gunpowder.
* Plant a charge by equipping it and clicking a surface within reach. Damage is full at the
  centre and half at the edge of the radius. Players and zombies nearby get hurt too, and the
  blast draws zombies from far away.
* Breaking a doorway also removes its door. Breaking storage spills everything inside.
* **Repair**: equip a hammer (wood and brick) or blowtorch (metal) and click your piece. Each
  repair restores 12% of its health for 1 unit of its material.
* **Salvage**: with a hammer, press X on your own piece to remove it and get half the
  material back.

All these numbers live in `src/shared/BuildingDefs.luau` and `src/shared/Items.luau`.

## Project layout

```
src/shared     Config, items, recipes, building rules, grid snapping, UI theme, remotes
src/server     Server entry point and services
  Services/World   Terrain generator, building generator, map definitions
src/client     HUD, inventory and crafting panel, controls, build preview, effects
src/character  Replaces the default health regeneration
```

The server owns every decision: the client only sends requests (use this item, fire in
this direction, place this piece here) and the server checks distance, cooldowns, ammo,
weight and ownership before anything happens.

## Weapons

| Kind | Weapons |
|---|---|
| Melee | Kitchen knife, scrap knife, wooden club, frying pan, golf club, baseball bat, crowbar, pipe wrench, shovel, hatchet, machete, fire axe, pickaxe, sledgehammer |
| Civilian guns (houses, farms, police) | Compact pistol, revolver, double-barrel shotgun, varmint rifle |
| Service and military guns | Service pistol, pump shotgun, hunting rifle, carbine |

Ammunition: pistol rounds, revolver rounds, small calibre rounds, shotgun shells, rifle rounds.
The sledgehammer is the strongest melee tool against wooden walls; the hatchet and fire axe
chop trees fastest; the pipe wrench and crowbar pull scrap off wrecks.

## Zombies

There are four kinds, all with cube heads, pixel faces and glowing eyes:

| Type | Look | What it does |
|---|---|---|
| Walker | Grey-green rot, torn clothes, blood stains, yellow eyes | The common shambler (about three in four zombies). Bites for 5 to 7 damage, like the Smoulderer and Livewire |
| Smoulderer | Charred black skin split by glowing embers, always on fire | Hits set you alight for 4 seconds (3 damage per second). Diving into water puts the fire out |
| Livewire | Pale skin with glowing blue veins, crackling with sparks | Hits slow you and drain 30 stamina. Zaps you with an electric arc from up to 14 studs away |
| Behemoth | A giant in scraps of riot armour with red eyes | The boss of military bases: 1500 health, heavy hits, a ground slam that throws players back and cracks player bases, and short charges at anyone keeping their distance. Drops three rolls of military loot and returns 10 minutes after it dies |

A health bar appears at the top of the screen while a Behemoth is close.

Zombies shamble: hunched over, arms reaching forward, head tilted, one stiff leg dragging
behind with the body dipping on each step. They walk at 3 studs per second and chase at about
10, so a player walking at 14 can get away. The walk is drawn by each player's own game
instead of the server, and only for zombies within 160 studs of the camera.

They groan now and then (every 10 to 25 seconds, only within 60 studs, at most two voices at
once, at low volume) and make a sound when they attack.

## Sounds

The `sounds` folder holds original sound effects made for this game (zombie groans and attacks, punch swing and hit, the Behemoth roar and slam, the Livewire zap and a looping fire crackle for Smoulderers). The script that generates them, `make_sfx.py`, is next to them. To use them, upload each `.ogg` file from the Roblox Creator Dashboard
(Creations, Audio) or from Studio's Asset Manager, then paste the ids into `Config.Sounds`
(`ZombieGroan`, `ZombieAttack`, `PunchSwing`, `PunchHit`, `BossRoar`, `BossSlam`, `Zap`,
`FireCrackle`). Sounds uploaded by your own account
always play in your own game.

Sound ids are in `Config.Sounds`. Any entry can be a list; one is picked at random each time.
Empty entries play nothing. Upload your own sounds or pick ones from the Creator Store and
paste their ids, for example `"rbxassetid://123456789"`.

The zombie sounds are community uploads from the Creator Store. Listen to them and swap any
you do not like:

* Groans: [zombie_groan0](https://create.roblox.com/store/asset/99659350948942),
  [zombie_groan1](https://create.roblox.com/store/asset/96529107293726),
  [Zombie Groan 05](https://create.roblox.com/store/asset/134766104012323),
  [zombie growl](https://create.roblox.com/store/asset/74103327872448)
* Attacks: [Zombie Attack 1](https://create.roblox.com/store/asset/18942682166),
  [Zombie Attack 2](https://create.roblox.com/store/asset/18942691946),
  [Zombie Attack 3](https://create.roblox.com/store/asset/18942711304)

## Performance

* Terrain is generated as a thin shell under the surface instead of solid rock down to the
  sea floor, and roads and towns are skipped early when far from a point.
* Workspace streaming is on, so each player only loads the area around them.
* Zombies near the camera are animated every frame, farther ones 20 or 8 times a second.
* At most 50 zombies exist at once; only every other street lamp casts light.
* Players load the world within about 640 studs of themselves.
* Zombie zones only fill when a player is near, zombies far from every player think once a
  second instead of four times, and zombie animation and voices run on clients.
* World parts have touch events turned off, since nothing uses them.
* Leaves, bushes and small props cast no shadows and are ignored by raycasts, so aiming and
  bullets pass through foliage and the renderer does less work. Furniture casts no shadows.
* Buildings and trees are set to draw as simplified meshes when far away.

## Not in this first build

* Saving progress between sessions (DataStores)
* Groups or clans sharing base access
* Vehicles
* Placeholder item models (every item is a coloured block)
