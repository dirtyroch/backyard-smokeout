# Publishing Backyard Smokeout (no coding needed)

This guide takes you from "I have a file" to "my game is live on Roblox". Plan on about an hour the first time.

---

## 1. Install Roblox Studio

1. Go to **https://create.roblox.com** and sign in with your Roblox account.
2. Click **Start Creating** and download **Roblox Studio**. It works on Windows and Mac.
3. Open Studio and sign in.

> If your account is under 13, some publishing and selling features are limited. Use an account that meets Roblox's age requirements for selling items.

## 2. Open the game file

1. Download **`BackyardSmokeout.rbxlx`** from the GitHub repo. Click the file, then the **Download raw file** button.
2. In Studio, choose **File > Open from File...** and pick `BackyardSmokeout.rbxlx`.
3. You'll see the hub, 8 ranches in a circle and the creek out back.
4. Press **Play** (the ▶ button at the top) to try it. Press **Stop** (■) when you're done.

**About Studio test mode:**
- Saving doesn't work in Studio until you finish step 5. A yellow note will say "progress is NOT saved". That's normal.
- Shop items show a **"Studio test (free)"** button so you can try every apron and smoker skin without spending anything.
- Want to test with a friend? Open the **Test** tab, set **Clients** to 2 and press **Start**.

## 3. Publish it

1. Choose **File > Publish to Roblox**.
2. Pick **Create new experience**.
3. Name it **Backyard Smokeout**.
4. Description idea: *"Fire up the smoker, Pitmaster! Smoke Texas brisket for real (it keeps cooking while you're offline), flip burgers in 30 seconds, serve a yard full of critter regulars, win the Saturday Cook-Off, and earn your Unc Status. 🔥🥩"*
5. Genre: **Simulation**. Devices: turn on **Computer, Phone, Tablet** (and Console if you want).
6. Click **Create**.

## 4. Make it public

1. Go to **https://create.roblox.com/dashboard/creations** and click your game.
2. Open **Configure > Basic Settings** and fill in the description.
3. The privacy setting starts out **Private**. You can't switch it to **Public** until you've answered the maturity questionnaire (step 7). Do step 7 first, then come back and choose **Public**.

## 5. Turn on saving (API services)

In Studio, with the game open:

1. Go to **Home > Game Settings > Security**.
2. Turn on **Enable Studio Access to API Services**.
3. Click **Save**.

Saving works in the live game either way. This setting only lets Studio test saving too.

## 6. Create the shop items (passes and products)

The game reads every price ID from one file: **`src/shared/Monetization.luau`**. In Studio it shows up as **ReplicatedStorage > Shared > Monetization**. Any item still set to **0** is simply hidden in the live game, so you can launch with only a few items and add the rest later.

### Game Passes (one-time buys)

1. Go to the Creator Dashboard, open your game, then **Monetization > Passes > Create a Pass**.
2. For each pass below:
   - Add a picture. Any simple 512×512 icon works. Crop a screenshot of the item in game if you like.
   - Enter the name and description, then click **Create Pass**.
3. Open the pass, go to **Sales**, turn on **Item for Sale**, set the price and click **Save**.
4. Copy the pass ID. It's the number in the web address.
5. In Studio, double-click **Monetization**, find the line with that pass's name and replace `id = 0` with `id = YOUR_NUMBER`.

| In the file | Name | Price |
|---|---|---|
| `VIPPatio` | VIP Patio | R$ 149 |
| `ExtraSmokers` | Extra Smoker Slots | R$ 249 |
| `AutoServe` | Possum Pete Waiter | R$ 299 |
| `PremiumCuts` | Premium Cuts | R$ 349 |
| `DoubleTips` | Big Tipper (+50% tips, Fair Play cap) | R$ 299 |

### Developer Products (can be bought more than once, or one-time cosmetics)

Go to **Monetization > Developer Products > Create a Developer Product**. For each product, enter the name and price, create it, copy its **Product ID** and paste it over the `0` in Monetization.

| In the file | Name | Price |
|---|---|---|
| `ApronGrillMaster` | Grill Master Apron | R$ 75 |
| `HatPitmaster` | Pitmaster Cowboy Hat | R$ 99 |
| `GoldenSpatula` | Golden Spatula | R$ 149 |
| `SkinCandyRed` | Candy Apple Smoker | R$ 99 |
| `SkinGalaxy` | Galaxy Smoker | R$ 149 |
| `SkinGolden` | Solid Gold Smoker | R$ 249 |
| `SmokeBluebonnet` | Bluebonnet Smoke | R$ 49 |
| `SmokeGrape` | Grape Soda Smoke | R$ 49 |
| `SmokeSherbet` | Rainbow Sherbet Smoke | R$ 79 |
| `TrailPetals` | Bluebonnet Petal Trail | R$ 79 |
| `TrailSauce` | BBQ Sauce Drip Trail | R$ 79 |
| `TrailSparkler` | Sparkler Trail | R$ 79 |
| `BundleStarter` | Pitmaster Starter Bundle | R$ 199 |
| `BundleGoldRush` | Gold Rush Bundle | R$ 349 |
| `Boost30` | Smoke Speed x2 (30 min) | R$ 49 |
| `Boost120` | Smoke Speed x2 (2 hours) | R$ 149 |
| `FinishSmokers` | Finish All Smokers | R$ 39 |
| `WagyuPack` | Wagyu Brisket x3 | R$ 79 |
| `TomahawkPack` | Tomahawk Steak x3 | R$ 59 |
| `Rot_HatTurkey` | Gobble Hat (weekly) | R$ 59 |
| `Rot_ApronHarvest` | Harvest Plaid Apron (weekly) | R$ 75 |
| `Rot_SkinSnowy` | Snowy Smoker (weekly) | R$ 99 |
| `Rot_SmokePumpkin` | Pumpkin Patch Smoke (weekly) | R$ 49 |
| `Rot_TrailFirework` | Firework Trail (weekly) | R$ 99 |

**Tips:**
- Keep the prices in the file the same as on the dashboard. The shop shows the price from the file.
- The "weekly" items rotate in the shop by themselves every Monday. Create all of them once, and the game handles the rotation.
- Optional badges: go to **Engagement > Badges**, create them and paste their IDs into `Monetization.Badges`. Badge IDs left at `0` are skipped.

When you're done, choose **File > Publish to Roblox** again so the live game gets the new IDs.

## 7. Maturity & Compliance questionnaire (prefilled answers)

On the Creator Dashboard, open your game, then **Publish settings > Content rating** (older dashboards call it **Audience > Maturity & Compliance**). Click **Start**, and answer every page (not just the first question), so the game can reach younger players. Base each answer on the most intense thing a player can see. These are the honest answers for this build (checked against Roblox's guide, Nov 2026):

| Category | Question | Answer for Backyard Smokeout | Why |
|---|---|---|---|
| Violence | Depicts violence? | **Yes** | Players swat cartoon mosquitoes at dusk. |
| Violence | How intense? | **Mild** | Unrealistic: swatted mosquitoes just pop and vanish. No violence against players or NPC people. |
| Violence | How frequent? | **Repeated** | During the swarm, many swats happen quickly. (Picking "Repeated" is the safe choice. It still gives a Mild label.) |
| Blood | Any blood? | **No** | None anywhere. |
| Fear | Scary elements? | **Yes** | Temp the thermometer says slightly creepy jokes at night ("I see your brisket..."). |
| Fear | Level | **Mild** | A silly, creepy-ish NPC with no jump scares, gore or scary sounds. |
| Fear | Frequency | **Occasional** | Only at night, and only if you poke Temp. |
| Crude humor | Crude humor? | **No** | No burping, farting, poop or pee jokes. Unc's dad jokes are clean. |
| Gambling | Unplayable gambling content? | **No** | No casino and no cards. Rarity rolls are free and not bought with Robux. |
| Strong language | Strong language? | **No** | None. The slang ("Mid", "Cooked", "Taxed", "6-7") is clean. |
| Romantic themes | Romance, private spaces or adult settings? | **No** | It's a public backyard BBQ. There are no bars, and the drinks are sweet tea and soda. |
| Alcohol | Alcohol? | **No** | None. The sauces are BBQ sauces. |
| Social hangout | Primary theme is a social hangout? | **No** | It's a tycoon or simulator, and chat is not the point of the game. |
| Free-form creation | Free-form user creation? | **No** | No drawing, painting or free text on surfaces. Smoke signals are fixed phrases. |
| Sensitive issues | Primary theme a sensitive issue? | **No** | The small "Jesus loves you" potluck figure is a minor detail, not the theme. Roblox says not to disclose minor details like this. |
| Paid random items | Paid random items? | **No** | Every Robux item shows exactly what you get. Rarities, restocks and bandanas are free to play. |
| Paid item trading | Trade paid items? | **No** | There's no trading. Snagged plates are earned food, can't be bought, and snagging is opt-in. |
| Media | Share media from gameplay that others can see? | **Yes** | The "Say Brisket!" photo spot opens Roblox's own Captures share sheet (CaptureService). The game never shows other players' images in game. |
| Media | Content feeds or autoplay video? | **No** | |
| Media | View captures from other games? | **No** | |
| AI interaction | Users interact with generative AI? | **No** | All NPC lines are pre-written. |

**Expected result:** a **Mild** label (mild cartoon violence, mild fear), which is eligible for Roblox Kids (5–8) and Select (9–15). Before you click **Submit**, check that the preview shows Mild. If it shows anything higher, retake the questionnaire. If you add content later (a new event, voice or sounds), retake it in the same update. When you're done, go back to step 4 and set the game to **Public**.

Already wired in code: `PolicyService` gates (`PurchaseService.policy`), with no paid random items and no paid trading. The photo spot is wrapped in `pcall`, so devices that can't share fall back to a friendly message.

## 8. Icon, thumbnails and trailer (ready-made files in `marketing/`)

Draft files are rendered from the actual map:

| File | Use | Notes |
|---|---|---|
| `marketing/icon-512.png` | Game icon (512×512) | Big Biscuit belly-up, grinning, with the gold collar. One big readable character and no text, as Roblox recommends. |
| `marketing/thumb-1-zoomies.png` | Thumbnail 1 (1920×1080) | "RUB THE BELLY = ZOOMIES!" Big Biscuit and the photo spot. |
| `marketing/thumb-2-temp.png` | Thumbnail 2 | "TEMP IS ALWAYS WATCHING... YOUR BRISKET" |
| `marketing/thumb-3-ranches.png` | Thumbnail 3 | "8 RANCHES. 1 KING OF THE PIT." Shows the whole map. |
| `marketing/thumb-4-sleep.png` | Thumbnail 4 | "SMOKE IT WHILE YOU SLEEP" Shows the smoker row and grill. |
| `marketing/TRAILER.md` | 30-second trailer plan | A shot list you can record in Studio. |

How to upload: on the dashboard, open your game, then **Places > (start place) > Thumbnails** (or **Configure > Thumbnails**). Upload 3–5 thumbnails, and set the icon under **Basic Info > Icon**.

- **Swap in real gameplay shots once you can.** The drafts come from a preview renderer, so they have no smoke particles, UI or night lighting. Studio screenshots will look better. Keep the same text and layout.
- Keep words big and at the top. Nothing important should sit in the bottom 15%, because Roblox overlays UI there. Use 1–6 words per thumbnail.
- **A/B test the thumbnails** (Creator Hub **Thumbnail Personalization** or rotating order). Keep the one with the best click-through after about 1,000 impressions each.
- Follow the rules: no fake "FREE ROBUX" text, no real brands or real people, and no misleading art. Every scene shown is really in the game.

To take a clean Studio screenshot:
  1. Press Play.
  2. Hide the UI: **Players > (you) > PlayerGui > BackyardSmokeout > Enabled = off**.
  3. Set **Lighting > ClockTime** (18 gives golden hour, 21 gives night with smoke glow).
  4. Use **View > Screenshot**.

## 9. After launch

- Check **Analytics** on the dashboard after a day. Look at **Day 1 retention** and **Average session time**.
- Every update is the same: edit in Studio, then **File > Publish to Roblox**.
- Want to change prices or add items later? Edit **Monetization** and create the matching item on the dashboard.
