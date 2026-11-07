# 🔥 Backyard Smokeout

A Texas backyard BBQ tycoon for Roblox. Smoke brisket in real time (it keeps cooking while you're offline), flip 30-second burgers (faster with pit upgrades) while you wait, serve a yard full of original critter regulars, win the Saturday Cook-Off, swat the mosquito Queen at dusk, and climb to **OG Pitmaster** Unc Status.

- **Just want to publish it?** Read **[PUBLISHING.md](PUBLISHING.md)**. No coding needed.
- **Already published, and the shop IDs are only in your Studio place?** Read **[STUDIO-UPDATE.md](STUDIO-UPDATE.md)** before you open a new file or sync Rojo. This repo still has those IDs at `0`.
- **Ready-to-open place file:** [`BackyardSmokeout.rbxlx`](BackyardSmokeout.rbxlx). Built geometry and code-built UI mean there are no uploaded images to set up. Sound effects are public Roblox-library cues. The porch-light music loop is an original file in `audio/` and stays silent until you upload it (see STUDIO-UPDATE.md).

## What's in the game

| Loop | Details |
|---|---|
| Smokers (long) | Yardbird 8m, Roch & Roll Ribs 30m, Pork Butt 2h, Wagyu Brisket 4h (premium), Texas Brisket 6h, a seasonal turkey leg (Nov) and a Holiday Glazed Ham (Dec–Jan). Cooks keep going while you're offline. |
| Grill (short) | Backyard Burger 30s, Hot Link 2m and Tomahawk 5m (premium), each with a timing flip: Perfect, Skill issue, or "Locked In" combos. |
| First cook | A one-button first brisket that finishes in 75s, is guaranteed Smoke Ring Gold, and gets a cinematic reveal. |
| Rookie List | Right after the first brisket, Unc Hank hands you five quick goals (flip a burger, serve 3 critters, start a Hot Link, grab a sauce, ring Big Bertha's bell). A card in the top right shows the goal, progress and reward, and a bobbing gold arrow with a trail on the ground leads you there. Each goal pays a few free coins. The card always shows the finish reward: complete all five for **+250 coins, the Rookie of the Ranch Bandana and the Rookie of the Ranch title**. A **Skip** button asks once ("You'll miss the finish reward for now..."). Skipped lists come back from **Settings > Game > Bring it back**, goals done in the meantime count right away, and the reward can still be earned. The skip state is saved. Players from before the list skip it quietly but can bring it back too. Nothing in it is paid. |
| Sound | Grill sizzle (it sits on your grill, so it fades as you walk away), spatula clank and sear on flips (the sear climbs in pitch with your combo), cash register on serves, Big Bertha's bell, a kazoo fanfare for rare reveals and the Dinner Bell, the Texas-Size crunch, mosquito swats and soft UI clicks. All are public Roblox-library sounds (`src/shared/SfxIds.luau`). Settings → Game has a saved on/off toggle. Music is a separate saved mute and volume (quiet by default). The loop is the original Porch Light file in `audio/porch-light.ogg`. It does not play until that file is uploaded and `src/shared/Music.luau` gets the real asset id. `id = 0` is silence, not a stand-in. |
| Rarity | Common, Juicy, Smoke Ring Gold, Texas-Size ("CRUNCH! It broke the table!") and Meteorite. Odds are shown in game. |
| Customers | 10 original critter regulars, a Regulars Index, belly rubs, Suds Weekend pup washes, and a Rex cameo ("RAWR means I love you"). |
| Social | Crew bonus with friends, **Big Bertha's Dinner Bell** (3 players ring the bell on the King of the Pit's 1,000-gallon hub smoker within 20 s → "DINNER'S ON!", whole server +25% tips for 5 min), **"Say Brisket!" photo spot** in front of Big Bertha (Roblox share sheet + invite link), invites ("Help me ring Big Bertha's dinner bell!"), opt-in plate snagging (new players start in Peace Mode; lock timer, insurance, catch-back), smoke-signal flexes. |
| Daily | **Lunch Rush** every 2.5 min (serve 4 plates → +50% bonus), Sauce Shack restock every 5 min, daily streak with one free miss a week, 28-day Pitmaster Path, Unc's joke of the day ("Skip the yap"). A small board by his grill has a few original yard lines (November 2026 food slang, written for this porch, not copied clips). |
| Events | Saturday Cook-Off (3×, Granny Pecan judging, weekly leaderboard), the dusk mosquito swarm with the Queen boss, Sunday potluck, and the **Turkey Day Smokeout** (Thanksgiving week, Mon–Sun around the 4th Thursday of November, Texas time): the potluck table dresses up with a smoked turkey, pecan pie, pumpkins and a banner; share a Harvest Turkey Leg once a day for coins, your first share earns the free **Thankful & Full Apron**, and when 3 pitmasters share within 10 minutes the whole server gets +25% tips for 5 minutes. Nothing in it is paid. Then the **Holiday Smokeout** (Christmas, Dec 19 – Jan 1, Texas time): the same table dresses up with a glazed ham, tamales, a little Christmas tree, presents and garland; smoke a **Holiday Glazed Ham** (a Dec–Jan cut, 20 min) and share it once a day for coins and the free **Merry & Smoky Apron**, with the same 3-share server tip bonus. The event itself is free; a separate Holiday look set is sold only during those dates. |
| Prestige | Unc Status rebirth ranks (Lil Griller → Big Bro → Unc → Great Unc → OG Pitmaster), +coins forever. |
| Secrets | 11 eggs (incl. "6-7!" tips and the Dinner Bell): the roof sign-in, the creek whisper stone, the Okayest Unc apron, the King of the Pit's hat check, Temp, the blessed potluck figure, and more. |

## Project layout

```
src/shared/          Config, Content (all jokes/lines), Monetization (ALL Robux IDs), WorldBuilder, Logic/*
src/server/          Main.server + Services (Data, Game, World, Social, Event, Egg, Cosmetic, Purchase)
src/client/          Main.client + UI, Net, Fx, Sfx, Hud, Panels, RookieGuide, WorldClient
tests/run.luau       Lune unit tests for the pure logic
scripts/bake-map.luau  Bakes the map into the .rbxlx so Studio shows the world before Play
```

## Tech notes

- **Server-authoritative.** The client only sends intents through one `Action` RemoteFunction. Every action is validated and rate-limited with a per-player token bucket.
- **DataStore** with `UpdateAsync` session locking (it takes over a lock left behind by a crashed server after 5 minutes), retries with backoff, autosave, and save on leave or `BindToClose`. If DataStores are unavailable, it runs in memory-only mode and says so.
- **Purchases.** `ProcessReceipt` is idempotent through a per-profile receipt ledger. It grants, saves, then returns `PurchaseGranted`, and returns `NotProcessedYet` on any failure. There are no paid random items, Robux never buys coins, and the shop copy is calm.
- **Profit ladder (all looks, titles or speed perks, never coins).** Entry: First-Time Pit Pack, R$49 once. Middle: looks and bundles. Top: Whole Hog Collection, R$499. Repeat: the Smokehouse Pass (R$399 a season through Season 5 Firefly Smoke; Logic/SeasonPass, free and paid tracks, tier skips) the Turkey Day look set (Nov 23–29) and the Holiday look set (Dec 19 – Jan 1: Twinkle Lights Cowboy Hat, Evergreen Smoke, Tinsel Trail, Ornament Smoker, or all four for R$ 229). Monthly: the Pit Crew Club subscription (MembershipService, PolicyService gated). Social: the private server host perk. Premium: a Premium look that earns Premium Payouts. AnalyticsService funnels (Onboarding, PitShop) and economy events go through InsightsService.
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
