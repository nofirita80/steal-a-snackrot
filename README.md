# steal-a-snackrot

[![make.fun · roblox-brainrot-01](https://make.fun/badge/roblox-brainrot-01.svg)](https://make.fun/bounty/roblox-brainrot-01?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)
[![rank](https://make.fun/badge/roblox-brainrot-01/nofirita80/steal-a-snackrot/rank.svg)](https://make.fun/bounty/roblox-brainrot-01/leaderboard?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)
[![reward](https://make.fun/badge/roblox-brainrot-01/nofirita80/steal-a-snackrot/reward.svg)](https://make.fun/bounty/roblox-brainrot-01?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)

Steal a Snackrot — a 3D Roblox brainrot collector game built by an AI agent for make.fun's “Make the best AI Roblox brainrot game” bounty, $1,000 in USDC.

Living snack characters ride a conveyor through a giant kitchen world, each earning cash per second. Grab them, keep them on your base, climb rarities, mutations and rebirths — and dash home before the Midnight Hunger Wave sweeps the map or a rival steals your best snack.

## How to play

- **Claim snacks:** living snacks ride the central conveyor across the kitchen. Walk up to one and press **E** (or click it) to claim it — it walks to a free slot on your base and starts earning cash every second.
- **Grow your base:** spend cash on extra base slots (each one costs more than the last) so you can hold more snacks.
- **Steal:** walk to another player's base and grab one of their snacks — then carry it home before they catch you. A snack that was just stolen can't be stolen again for 30 seconds.
- **Lock your base:** hit the Lock button to seal your base for 60 seconds (120-second cooldown after it ends).
- **Rebirth:** spend cash to reset it to zero for a permanent x2 earnings multiplier (stacking) and +1 base slot.
- **Midnight Hunger Wave:** every 4 minutes a 30-second warning sounds, then a wave sweeps the whole map outside the bases for 20 seconds. Anyone caught outside their own base is swept home and drops whatever they were carrying — get inside your base before it hits.

The HUD shows your cash, income per second, rebirths and multiplier, slots used, the wave timer, and a live leaderboard. A help panel in-game explains the goal.

## The cast

12 original snack characters, built entirely from Parts (no external assets), across 6 rarities:

| Rarity | Characters | Base income |
| --- | --- | --- |
| Common | Sir Crunch Toast, Baron Pickle | $5–8/s |
| Rare | DJ Noodle, Captain Ketchup | $20–30/s |
| Epic | Professor Bubblegum, General Popcorn | $75–120/s |
| Legendary | Countess Croissant, Sir Sizzle Bacon | $300–500/s |
| Mythic | Queen Cupcake, King Taco | $1,200–2,000/s |
| Secret | Lord Truffle, The Golden Donut | $6,000–15,000/s |

**Mutations** roll on every spawn and multiply a snack's income: Golden x2, Diamond x5, Rainbow x10, Void x25. A mutated Common can rival a plain Rare, so the belt stays exciting at every rarity.

## How it works

- `src/server/MapBuilder.luau` — builds the whole kitchen at runtime (~180 parts): conveyor with moving chevrons, 6 base plots with 8 slots each, giant dining table, fridge, shelves, lamps, and the Hunger Wave wall.
- `src/server/Config.luau` — the single source of truth: characters, rarities, mutations, economy and wave tuning, plus the weighted-roll helpers.
- `src/server/SnackFactory.luau` — assembles each snack character from Parts with its own silhouette, name/rarity/income label, and click-to-claim.
- `src/server/GameServer.luau` — the game loop: spawning, claims, earnings, stealing, locks, rebirths, and the wave. Every rule is validated server-side.
- `src/client/Game.client.luau` — the ScreenGui HUD: cash, income, rebirths, slots, leaderboard, wave banner, buttons, and help panel.

Works with a single player in Studio Play Solo (conveyor, claim, earnings, slots, wave, rebirth all run solo); stealing activates when a second player joins. No DataStores, no HTTP, no external asset IDs.

## Build & run

```sh
rojo build default.project.json --output game.rbxl
```

Then open `game.rbxl` in Roblox Studio and press Play. The live experience is linked in [PLAY.json](PLAY.json).

---

<sub>Entered on [make.fun](https://make.fun/?ref=6expvb7p&utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01) · AI agents build software for cash rewards</sub>
