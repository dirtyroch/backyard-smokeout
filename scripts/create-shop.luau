--!nocheck
--[[
	create-shop.luau — creates every Game Pass and Developer Product in
	src/shared/Monetization.luau on Roblox in one run (Open Cloud), then writes the new IDs
	over the `id = 0` placeholders. Replaces ~45 rounds of copy and paste on the Creator Dashboard.

	  ROBLOX_API_KEY=... lune run scripts/create-shop <universeId>           # dry run: shows the plan
	  ROBLOX_API_KEY=... lune run scripts/create-shop <universeId> --apply   # creates, then saves IDs

	The API key needs (Creator Dashboard > Open Cloud > API Keys, limited to this game):
	  game-pass:read, game-pass:write, developer-product:read, developer-product:write
	The universe ID is on the game's Creator Dashboard page (Overview, "Universe ID"); it is not the
	place ID in the game's web address.

	Safe to run again: anything already on Roblox under the exact same name is reused, and IDs that
	are already filled in are never changed. Icons from marketing/shop-icons/<Key>.png are uploaded
	when present. Prices stay exactly as written in Monetization (regional pricing off).
]]
local fs = require("@lune/fs")
local net = require("@lune/net")
local process = require("@lune/process")
local serde = require("@lune/serde")
local task = require("@lune/task")

local ShopSync = require("./lib/ShopSync")
local Monetization = require("../src/shared/Monetization")

local MONETIZATION_PATH = "src/shared/Monetization.luau"
local ICON_DIR = "marketing/shop-icons"
local BASE = process.env.ROBLOX_API_BASE or "https://apis.roblox.com" -- override only for a local mock

local universeId = process.args[1]
local apply = table.find(process.args, "--apply") ~= nil
local key = process.env.ROBLOX_API_KEY

local function die(msg: string)
	print("✗ " .. msg)
	process.exit(1)
end

if not universeId or not string.match(universeId, "^%d+$") then
	die("Usage: ROBLOX_API_KEY=... lune run scripts/create-shop <universeId> [--apply]")
end
if not key or key == "" then
	die("Set ROBLOX_API_KEY to an Open Cloud key with game-pass and developer-product read + write.")
end

local function call(method: string, path: string, body: string?, contentType: string?): any
	local headers = { ["x-api-key"] = key }
	if contentType then
		headers["content-type"] = contentType
	end
	for attempt = 1, 5 do
		local res = net.request({ url = BASE .. path, method = method, headers = headers, body = body })
		if res.ok then
			return if res.body ~= "" then serde.decode("json", res.body) else {}
		end
		if res.statusCode == 429 or res.statusCode >= 500 then
			task.wait(attempt * 2) -- rate limit (3 to 5 a second) or a hiccup: back off and retry
		else
			die(string.format("%s %s -> %d %s", method, path, res.statusCode, res.body))
		end
	end
	return die(method .. " " .. path .. " kept failing; try again in a minute")
end

local function listAll(path: string, field: string, idField: string): { ShopSync.Existing }
	local out, token = {}, nil
	repeat
		local q = "?pageSize=50" .. (token and ("&pageToken=" .. token) or "")
		local page = call("GET", path .. q)
		for _, e in ipairs(page[field] or {}) do
			table.insert(out, { id = tonumber(e[idField]), name = e.name })
		end
		token = page.nextPageToken
	until token == nil or token == ""
	return out
end

local passPath = "/game-passes/v1/universes/" .. universeId .. "/game-passes"
local productPath = "/developer-products/v2/universes/" .. universeId .. "/developer-products"

print("Reading what's already on Roblox for universe " .. universeId .. "...")
local existing = {
	pass = listAll(passPath .. "/creator", "gamePasses", "gamePassId"),
	product = listAll(productPath .. "/creator", "developerProducts", "productId"),
}
local plan = ShopSync.plan(ShopSync.items(Monetization), existing)

for _, p in ipairs(plan.problems) do
	print("✗ " .. p)
end
if #plan.problems > 0 then
	die("Fix the items above in Monetization.luau first.")
end

print(string.format("Already filled in: %d. Found on Roblox by name: %d. To create: %d.", #plan.done, #plan.link, #plan.create))
for _, it in ipairs(plan.create) do
	local icon = fs.isFile(ICON_DIR .. "/" .. it.key .. ".png") and "icon" or "no icon"
	print(string.format("  + %-8s %-18s R$ %-4d %s (%s)", it.kind, it.key, it.price, it.name, icon))
end

if not apply then
	print("\nDry run only. Add --apply to create these and save the IDs into " .. MONETIZATION_PATH .. ".")
	return
end

local ids: { [string]: number } = {}
for _, l in ipairs(plan.link) do
	ids[l.key] = l.id
end
-- Save after every item so an interrupted run never loses IDs (the next run links by name anyway).
local function save()
	local src = fs.readFile(MONETIZATION_PATH)
	local newSrc = ShopSync.applyIds(src, ids)
	if newSrc ~= src then
		fs.writeFile(MONETIZATION_PATH, newSrc)
	end
end
save()

for i, it in ipairs(plan.create) do
	local iconPath = ICON_DIR .. "/" .. it.key .. ".png"
	local iconBytes = if fs.isFile(iconPath) then fs.readFile(iconPath) else nil
	local boundary = "----BackyardSmokeout" .. tostring(os.time()) .. tostring(i)
	local body = ShopSync.multipart(ShopSync.formFields(it, iconBytes), boundary)
	local path = if it.kind == "pass" then passPath else productPath
	local res = call("POST", path, body, "multipart/form-data; boundary=" .. boundary)
	local id = tonumber(if it.kind == "pass" then res.gamePassId else res.productId)
	if not id then
		die("Roblox didn't return an ID for " .. it.key)
	end
	ids[it.key] = id
	save()
	print(string.format("  ✓ %s -> %d", it.key, id))
	task.wait(0.4) -- stay under 3 requests a second
end

print("\nDone. Every shop item now has an ID in " .. MONETIZATION_PATH .. ".")
print("Next: ./scripts/build.sh, open BackyardSmokeout.rbxlx in Studio and File > Publish to Roblox.")
