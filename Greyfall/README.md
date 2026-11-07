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

### Choosing the map

The default map is set in `src/shared/Config.luau` (`Config.DefaultMap`). To override it in
Studio, select **Workspace**, add a string attribute named `Map` and set it to
`KestrelIsland` or `Ridgeline`.

## Controls

| Key | Action |
|---|---|
| WASD, Space | Move, jump |
| Left Shift | Sprint (uses stamina) |
| Left click | Attack, shoot, place a structure, plant a charge, repair |
| R | Reload |
| 1 to 5 | Equip a hotbar slot, press again to put it away |
| F | Pick up, open doors, open your storage |
| I | Inventory |
| C | Crafting |
| X | Salvage your own structure (hammer equipped) |
| V | First or third person |
| H | Show or hide the controls list in game |

## Survival

* **Food** and **water** drain over time; water drains twice as fast while sprinting. Either one
  at zero drains health.
* **Health** regenerates slowly while food and water are both above 60 and infection is low.
* **Infection** rises with every zombie hit. Above 50 it drains health. Antibiotics and medkits
  bring it down.
* **Bleeding** can start from a zombie hit and drains health until you use a bandage or medkit.
* **Carry weight** is 12 kg, plus whatever your worn backpack adds.
* Death drops everything you carried where you fell.

## Maps

* **Kestrel Island** is a small rural island with a central town, a fishing village, farmland,
  a lighthouse, a hilltop radar station and forest cabins.
* **Ridgeline** is a mainland map with a port city on the west coast, a valley town, farms, a
  fenced military base, a forest hamlet and a lodge up in the eastern mountains.

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

## Sounds

Sound ids are in `Config.Sounds`. Most are empty, so those events play nothing. Upload your
own sounds or pick ones from the Creator Store and paste their ids, for example
`"rbxassetid://123456789"`.

## Not in this first build

* Saving progress between sessions (DataStores)
* Groups or clans sharing base access
* Vehicles
* Placeholder item models (every item is a coloured block)
