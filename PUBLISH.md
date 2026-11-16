# Publish Backyard Smokeout (first time)

You only need the place file to get the game onto Roblox. Real Robux purchases stay off until the passes and developer products exist. The long version, including the maturity answers, is [PUBLISHING.md](PUBLISHING.md).

## 1. Open the file

1. Install Roblox Studio from [create.roblox.com](https://create.roblox.com) and sign in.
2. **File > Open from File...** and choose `BackyardSmokeout.rbxlx`.
3. Press **Play** to look around, then **Stop**.

Saving in Studio says progress is not saved until step 4. Shop buttons say **Studio test (free)** until step 6. That is expected.

## 2. Publish a new experience

1. **File > Publish to Roblox**.
2. Choose **Create new experience** (older Studio builds label this **Publish to Roblox As**).
3. Name it **Backyard Smokeout**. Genre: **Simulation**. Turn on Computer, Phone, and Tablet.
4. Click **Create**.

## 3. Creator Dashboard

Open [create.roblox.com/dashboard/creations](https://create.roblox.com/dashboard/creations) and click the game.

1. **Publish settings > Content rating** (older pages say **Audience > Maturity & Compliance**). Answer every page. The filled-in answers are in PUBLISHING.md section 7. Expect **Mild**. Submit before you try to go public.
2. Come back and set the experience to **Public**. It stays private until the questionnaire is done.
3. **Configure > Basic Settings**: paste a description. One that matches the game: *Fire up the smoker, Pitmaster! Smoke Texas brisket for real (it keeps cooking while you're offline), flip burgers in 30 seconds, serve a yard full of critter regulars, win the Saturday Cook-Off, and earn your Unc Status.*
4. Icon: `marketing/icon-512.png` under **Basic Info > Icon**.
5. Thumbnails: **Places > (the start place) > Thumbnails** (some dashboards say **Configure > Thumbnails**). Upload `marketing/thumb-1-dinnerbell.png`, `thumb-2-temp.png`, `thumb-3-ranches.png`, and `thumb-4-sleep.png`.

## 4. Studio API access (only for testing saves in Studio)

Live servers save without this. Turn it on only if you want Studio playtests to write to DataStores.

In Studio: **Home > Game Settings > Security > Enable Studio Access to API Services > Save**.

## 5. Music

The porch-light loop is in the download as `audio/porch-light.ogg`. It does not play until Roblox has the file.

1. In Studio, open **View > Asset Manager** and upload `audio/porch-light.ogg`.
2. Copy the numeric asset id Roblox assigns.
3. In Explorer, open **ReplicatedStorage > Shared > Music** and change `id = 0` to `id =` that number.
4. **File > Publish to Roblox** again.

Leave `id = 0` if the upload is rejected. The game stays quiet on purpose. Do not paste in a song you do not own.

## 6. Passes and developer products (required before real purchases)

Anything still set to `id = 0` is hidden in the live game. Studio's **Studio test (free)** button is not a real purchase.

**If you have this project folder** (not just the rbxlx):

1. Creator Dashboard: **Open Cloud > API Keys > Create API Key**.
2. Add **game-passes** and **developer-products**, pick this experience, and allow **read** and **write** for both.
3. Copy the key and the **Universe ID** from the experience's Overview. The universe id is not the place id in the game's web address.
4. Dry run, then apply:

```bash
ROBLOX_API_KEY=your-key lune run scripts/create-shop YOUR_UNIVERSE_ID
ROBLOX_API_KEY=your-key lune run scripts/create-shop YOUR_UNIVERSE_ID --apply
```

The script creates all 44 passes and products, reuses any that already have the same name, never overwrites an id that is already filled in, and writes the new ids into `src/shared/Monetization.luau`. Icons come from `marketing/shop-icons/`. Then rebuild or paste those ids into the Studio **Monetization** module and publish again. Delete the API key when you are done.

**If you only have the rbxlx:** on the experience, use **Monetization > Passes** and **Monetization > Developer Products**. Create each item from the tables in PUBLISHING.md section 6, turn on sale, set the same price as the file, and paste each id over the matching `id = 0` in **ReplicatedStorage > Shared > Monetization**. Publish again. Play once and confirm the shop says **Buy for R$ …** instead of **Studio test (free)**.
