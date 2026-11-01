# 🔥 Backyard Smokeout

A Texas backyard BBQ tycoon for Roblox. Smoke brisket in real time (it keeps cooking while you're offline), flip 30-second burgers (faster with pit upgrades) while you wait, serve a yard full of original critter regulars, win the Saturday Cook-Off, swat the mosquito Queen at dusk, and climb to **OG Pitmaster** Unc Status.

- **Just want to publish it?** Read **[PUBLISHING.md](PUBLISHING.md)**. No coding needed.
- **Ready-to-open place file:** [`BackyardSmokeout.rbxlx`](BackyardSmokeout.rbxlx). Built geometry and code-built UI mean there are no uploaded assets to set up.

## What's in the game

| Loop | Details |
|---|---|
| Smokers (long) | Yardbird 8m, Roch & Roll Ribs 30m, Pork Butt 2h, Wagyu Brisket 4h (premium), Texas Brisket 6h, and a seasonal turkey leg. Cooks keep going while you're offline. |
| Grill (short) | Backyard Burger 30s, Hot Link 2m and Tomahawk 5m (premium), each with a timing flip: Perfect, Skill issue, or "Locked In" combos. |
| First cook | A one-button first brisket that finishes in 75s, is guaranteed Smoke Ring Gold, and gets a cinematic reveal. |
| Rarity | Common, Juicy, Smoke Ring Gold, Texas-Size ("CRUNCH! It broke the table!") and Meteorite. Odds are shown in game. |
| Customers | 10 original critter regulars, a Regulars Index, belly rubs, Suds Weekend pup washes, and a Rex cameo ("RAWR means I love you"). |
| Social | Crew bonus with friends, **Big Biscuit Zoomies** (3 players rub his belly within 20 s → whole server +25% tips for 5 min), **"Say Brisket!" photo spot** (Roblox share sheet + invite link), invites ("Come rub Big Biscuit's belly with me"), opt-in plate snagging (new players start in Peace Mode; lock timer, insurance, catch-back), smoke-signal flexes. |
| Daily | **Lunch Rush** every 2.5 min (serve 4 plates → +50% bonus), Sauce Shack restock every 5 min, daily streak with one free miss a week, 28-day Pitmaster Path, Unc's joke of the day ("Skip the yap"). |
| Events | Saturday Cook-Off (3×, Granny Pecan judging, weekly leaderboard), the dusk mosquito swarm with the Queen boss, Sunday potluck. |
| Prestige | Unc Status rebirth ranks (Lil Griller → Big Bro → Unc → Great Unc → OG Pitmaster), +coins forever. |
| Secrets | 11 eggs (incl. "6-7!" tips and Zoomies): the roof sign-in, the creek whisper stone, the Okayest Unc apron, the King of the Pit's hat check, Temp, the blessed potluck figure, and more. |

## Project layout

```
src/shared/          Config, Content (all jokes/lines), Monetization (ALL Robux IDs), WorldBuilder, Logic/*
src/server/          Main.server + Services (Data, Game, World, Social, Event, Egg, Cosmetic, Purchase)
src/client/          Main.client + UI, Net, Fx, Hud, Panels, WorldClient
tests/run.luau       Lune unit tests for the pure logic
scripts/bake-map.luau  Bakes the map into the .rbxlx so Studio shows the world before Play
```

## Tech notes

- **Server-authoritative.** The client only sends intents through one `Action` RemoteFunction. Every action is validated and rate-limited with a per-player token bucket.
- **DataStore** with `UpdateAsync` session locking (it takes over a lock left behind by a crashed server after 5 minutes), retries with backoff, autosave, and save on leave or `BindToClose`. If DataStores are unavailable, it runs in memory-only mode and says so.
- **Purchases.** `ProcessReceipt` is idempotent through a per-profile receipt ledger. It grants, saves, then returns `PurchaseGranted`, and returns `NotProcessedYet` on any failure. There are no paid random items, Robux never buys coins, and the shop copy is calm.
- **Offline cooking** uses `os.time()` deltas with boosts applied piecewise. Rarity is rolled when a cook starts, so a speed-up can't change it.

## Build, lint and test

The tools are pinned in `rokit.toml`: Rojo 7.7.1, selene 0.32.0, Lune 0.11.1 and luau-lsp 1.70.1.

```bash
rokit install
./scripts/build.sh                      # rojo build + bake map -> BackyardSmokeout.rbxlx
selene generate-roblox-std && selene src tests scripts
lune run tests/run
rojo sourcemap default.project.json -o sourcemap.json
luau-lsp analyze --definitions=globalTypes.d.luau --sourcemap=sourcemap.json src
```

For live sync while editing, run `rojo serve` and use the Rojo Studio plugin.

## Fair Play

Paid perks are capped so they never wall off free players: the tip pass is +50% (not x2), buying a speed boost gives everyone else a free 5-minute Smoke Shower, snagging is opt-in, and nothing paid touches the Cook-Off. See `Config.FairPlay`.

## IP and safety

Every character, joke and song reference is original. There are no real songs, brands or meme assets. The "cowboy-hat pitmaster" is an original King of the Pit, and the dog regular is an original pittie-type pup. Content is written to be all-ages.

## CI

A ready GitHub Actions workflow lives at `ci/github-actions-ci.yml`. It runs lint, tests, type check and build. To turn it on, move it to `.github/workflows/ci.yml`. It was kept out of `.github/` because the account token that pushed this repo can't write workflow files.
