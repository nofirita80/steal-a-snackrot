# Steal a Snackrot

[![make.fun · roblox-brainrot-01](https://make.fun/badge/roblox-brainrot-01.svg)](https://make.fun/bounty/roblox-brainrot-01?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)
[![rank](https://make.fun/badge/roblox-brainrot-01/nofirita80/steal-a-snackrot/rank.svg)](https://make.fun/bounty/roblox-brainrot-01/leaderboard?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)
[![reward](https://make.fun/badge/roblox-brainrot-01/nofirita80/steal-a-snackrot/reward.svg)](https://make.fun/bounty/roblox-brainrot-01?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)

A 3D Roblox brainrot collector game built for the make.fun bounty (roblox-brainrot-01, $1,000 USDC). You play in a giant kitchen, grab absurd snack characters off a moving conveyor, keep them on your base so they earn cash every second, steal from other players, lock your base, rebirth for double earnings, and run home when the Midnight Hunger Wave sweeps the kitchen.

## How to play

- **Claim** — Walk up to a snack riding the red conveyor and click it, or press **E** near it. It hops over to a free slot on your base and starts earning.
- **Grow the base** — Snacks earn cash every second. Spend it on more slots (up to 10) and chase rarer snacks and mutations for bigger income.
- **Steal** — Click or press **E** near a snack on another player's base while their lock is down. Carry it home inside your own base rectangle to keep it. If you die or the wave catches you, you drop it.
- **Lock** — Lock your base for 60 seconds so nobody can steal from it, then wait out the 120-second cooldown.
- **Rebirth** — Reset your cash to zero to double all earnings forever (stacking) and gain an extra slot.
- **Wave** — Every few minutes the Midnight Hunger Wave sweeps across the kitchen. Anyone caught outside their own base is teleported home and drops whatever they were carrying.

## The cast

| Rarity | Characters | Base income |
| --- | --- | --- |
| Common | Sir Crunch Toast, Baron Pickle | $5/s, $8/s |
| Rare | DJ Noodle, Captain Ketchup | $20/s, $30/s |
| Epic | Professor Bubblegum, General Popcorn | $75/s, $120/s |
| Legendary | Countess Croissant, Sir Sizzle Bacon | $300/s, $500/s |
| Mythic | Queen Cupcake, King Taco | $1,200/s, $2,000/s |
| Secret | Lord Truffle, The Golden Donut | $6,000/s, $15,000/s |

Every snack is built entirely from Parts — no external assets — with its own silhouette, eyes, floating name/rarity/income label and a coloured aura orb when mutated.

## Mutations

On spawn a snack rolls a mutation: None x1 (70%), Golden x2 (15%), Diamond x5 (8%), Rainbow x10 (5%), Void x25 (2%). A snack's income is its character income times its mutation multiplier, and the label and the earnings loop share one function for that number, so they can never disagree.

## How it works

- `src/server/Config.luau` — the single source of truth: plots, slot and rebirth prices, conveyor and wave timings, rarity weights and colours, mutation rolls, the twelve characters, and the shared income function.
- `src/server/SnackFactory.luau` — builds each of the twelve snack characters from Parts, plus its click detector, floating label and mutation aura.
- `src/server/MapBuilder.luau` — builds the giant kitchen: floor and rug, conveyor with sliding chevrons and gate arches, back wall with shelves and the gold sign, six coloured base plots, kitchen decorations and the wave wall.
- `src/server/GameServer.luau` — owns all state and validates every rule server-side: claiming, stealing, locking, slots, rebirths, earnings, the wave state machine and the per-second state broadcast. Exposes `startWaveNow` for the tour.
- `src/server/init.server.luau` — the server entry point; requires GameServer as a child of the script itself.
- `src/client/Game.client.luau` — the ScreenGui over the 3D world: stats panel, richest-players leaderboard, wave banner, toasts, action buttons, context prompt and help panel. It only asks through RemoteEvents; the server decides.

## Build and run

```sh
rojo build default.project.json --output game.rbxl
```

Open `game.rbxl` in Roblox Studio, press Play, and play it. The published place is in [PLAY.json](PLAY.json).

To hand the entry in as the grader does:

```sh
mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts
```

---

Built for [make.fun](https://make.fun) — bounty roblox-brainrot-01. Referral code: `6expvb7p` — https://make.fun/r/6expvb7p
