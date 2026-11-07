# Updating a place that already has shop IDs

Mike's purchases worked in his Studio copy. The Robux IDs may live only in that copy, in `ReplicatedStorage > Shared > Monetization`. This repo still has those IDs at `0`. Publishing this update on top of the live place **without putting the IDs back** hides the shop (live games hide anything whose id is `0`).

Do not publish to Roblox, and do not change the Creator Dashboard, until the checks at the bottom pass.

## What this update changes

- Warmer, larger UI for the shop, Rookie List, settings, and the game HUD. Phone layouts reflow instead of shrinking the type.
- A music mute and volume, saved separately from sound effects. The default volume is quiet (`0.22`).
- A few original yard jokes and a small "Today's Board" sign by Unc's grill.
- Original cute faces on the Backyard Burger and the Tomahawk Steak. They sit on top of the food. The meat itself still changes color as it cooks, and a burnt one still turns black (the face frowns and loses its sparkle).
- Saves gain `settings.music` and `settings.musicVolume` automatically. Old fields stay. Gameplay, the skippable Rookie List and its finish reward, seasons, gifting, and purchases are the same.

## What this update does not change

- `src/shared/Monetization.luau` is unchanged. Prices, product keys, and the `0` placeholders are the same as before.
- No new game passes, developer products, or subscriptions.
- Nothing is published from here.

## Safe way to bring it into the Studio place where purchases already work

1. Open the Studio place where purchases already work. Do not open `BackyardSmokeout.rbxlx` over it yet.
2. In Explorer, open **ReplicatedStorage > Shared > Monetization**. Select all of the source and paste it into a text file named `monetization-backup.luau` somewhere outside the place. This is the copy with the real IDs.
3. Also write down any other Studio-only edits (badge IDs in that same module, Workspace attributes such as `ForceTurkeyDay`, Game Settings).
4. Pick one install path.

### Path A — Rojo into the existing place

Use this if the Rojo plugin is already connected to this repo.

1. Stop Rojo.
2. Confirm `monetization-backup.luau` exists (step 2).
3. Sync this branch. Rojo will replace **Shared > Monetization** with the repo file, which has `id = 0`.
4. Open Monetization again and put each real id back. Only the `id = ` numbers (and the Pit Crew Club `id = "EXP-..."` string, if you set one) should change. Leave every name, price, and description as they are in the new file. They match the backup.
5. Do not paste the entire old module over the new one if you only needed the IDs. Pasting the old file is safe **only** because this update did not edit Monetization. If you do paste it, you are restoring your IDs and also discarding nothing else from this update, because this update did not touch that module.

### Path B — open the new place file

`BackyardSmokeout.rbxlx` on this branch is a full place with the new scripts and the porch board baked in. It still has shop IDs at `0`.

1. Keep the purchase place open, or keep `monetization-backup.luau`.
2. Open `BackyardSmokeout.rbxlx` in a **second** Studio window (File > Open from File). Do not choose the existing experience when Studio asks where to publish.
3. Copy the source from `monetization-backup.luau` into the new place's **ReplicatedStorage > Shared > Monetization**, or copy each id by hand.
4. Play once. Shop buttons that you already created on the dashboard should say **Buy for R$ …**, not **Studio test (free)**.
5. Only then use File > Publish to Roblox and choose the **existing** Backyard Smokeout experience.

## Music (not playing yet)

`audio/porch-light.ogg` is an original 40-second instrumental loop. See `audio/ATTRIBUTION.md`. Roblox will not play a file that sits in the git repo, and this update does **not** invent an asset id.

Until you upload it:

- `src/shared/Music.luau` has `id = 0`.
- The client does not call Play.
- Settings > Game still shows the music switch and Quiet / Easy / Full. Those values save. The ranch stays quiet.

To turn the tune on later:

1. In Creator Dashboard, open the experience, then **Development Items > Audio** (or Asset Manager in Studio) and upload `audio/porch-light.ogg`.
2. Copy the numeric asset id.
3. In Studio, open **ReplicatedStorage > Shared > Music** and set `id = 0` to `id =` that number. Leave Monetization alone.
4. Publish the place. Mute and volume the player already saved will apply. The loop is one sound, so it does not stack on itself. Sound effects stay on their own switch.

If the upload is rejected, leave `id` at `0`. Do not paste in a song you do not own.

## After the scripts are in, before you publish

- Pit Shop shows your real prices, not "Studio test (free)", for items you already created.
- A test purchase still prompts Roblox's purchase window.
- Settings > Game still has Peace Mode, sound effects, and **Bring it back** for a skipped Rookie List.
- Gifting a look still opens the gift picker.
- Turkey Day and Holiday dates are unchanged.

## The porch board on an already-baked map

If the place already has `Workspace.Map`, the server adds `Hub.YardBoard` when it is missing. You do not have to rebake the map to see the sign. A brand-new open of `BackyardSmokeout.rbxlx` already has the board baked in.
