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
| `DoubleTips` | Double Tips | R$ 399 |

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

## 7. Maturity & Compliance questionnaire

On the Creator Dashboard, open your game, then **Audience > Maturity & Compliance** (sometimes shown as **Experience Questionnaire**). Answer honestly. For this game, the honest answers are:

- **Violence:** none against people or avatars. The only "fighting" is swatting cartoon mosquitoes. If a question asks about unrealistic or cartoon violence, choose the mildest option.
- **Blood, gore, fear, romance, crude humor, gambling, alcohol, drugs:** none. The sauces are BBQ sauce, and the drinks are sweet tea and soda.
- **Paid random items:** **No.** Nothing sold for Robux is random.
- **Religious references:** there's a small "Jesus loves you" figure in the hub. If the questionnaire asks about religious content, say yes and describe it as a small positive message.
- **Social features:** players see each other's names and a short fixed "smoke signal" message. There's no custom player text besides Roblox's normal chat.
- **Real-money or off-platform links:** none.

You should get **Minimal** or **Mild**, which lets everyone play. Once it's done, go back to step 4 and set the game to **Public**.

## 8. Thumbnail and icon tips

- **Icon (512×512):** one big, readable thing. A glowing golden brisket on a smoker, or a cartoon pitmaster in a cowboy hat holding a spatula, against a bright orange sunset sky. Add 1–3 big words at most ("SMOKEOUT!").
- **Thumbnails (1920×1080, upload 3–5):**
  1. A rare-reveal moment: the gold beam and "SMOKE RING GOLD!" card.
  2. The busy yard: critters at the tables, smoke rising, VIP lights.
  3. The Saturday Cook-Off stage with Granny Pecan and the leaderboard.
  4. Mosquito night: the purple Queen and lots of players swatting.
- To take a clean screenshot:
  1. Press Play in Studio.
  2. Hide the game's buttons. In the Explorer, open **Players > (you) > PlayerGui > BackyardSmokeout** and untick **Enabled**.
  3. Set the time with **Lighting > ClockTime**. 18 gives a golden sunset.
  4. Take the screenshot with **View > Screenshot**.
- Use bright, warm colors (orange, gold, sky blue). Thumbnails that show a moment work better than ones that show a menu.
- Follow the Roblox thumbnail rules: no fake "FREE ROBUX" text, no real brand logos, and no images of real people.

## 9. After launch

- Check **Analytics** on the dashboard after a day. Look at **Day 1 retention** and **Average session time**.
- Every update is the same: edit in Studio, then **File > Publish to Roblox**.
- Want to change prices or add items later? Edit **Monetization** and create the matching item on the dashboard.
