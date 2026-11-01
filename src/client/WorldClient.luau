--!strict
-- Client-side world bits: which prompts you see, prompts that open UI, the trampoline,
-- the "Unc is resting his eyes" AFK tag, and live countdowns on your own smokers.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(script.Parent.Net)
local Hud = require(script.Parent.Hud)
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local TimeUtil = require(Shared.Logic.TimeUtil)

local player = Players.LocalPlayer
local WorldClient = {}

-- Prompts that only the owner should see, and the snag prompt the owner should NOT see.
local OWNER_ONLY = { serve = true, bellyrub = true, wash = true, catch = true }

local function shouldHide(prompt: ProximityPrompt): boolean
	local kind = prompt:GetAttribute("Kind")
	local owner = prompt:GetAttribute("OwnerUserId")
	if typeof(kind) ~= "string" then
		return false
	end
	if OWNER_ONLY[kind] then
		return owner ~= player.UserId
	end
	if kind == "snag" then
		return owner == player.UserId or (Net.state and Net.state.settings.peace)
	end
	return false
end

local function watchPrompt(prompt: ProximityPrompt)
	local function apply()
		if shouldHide(prompt) and prompt.Enabled then
			prompt.Enabled = false
		end
	end
	apply()
	prompt:GetPropertyChangedSignal("Enabled"):Connect(apply)
	prompt:GetAttributeChangedSignal("OwnerUserId"):Connect(apply)
end

function WorldClient.start(Panels: any)
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("ProximityPrompt") then
			watchPrompt(d)
		end
	end
	workspace.DescendantAdded:Connect(function(d)
		if d:IsA("ProximityPrompt") then
			watchPrompt(d)
		end
	end)

	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local kind = prompt:GetAttribute("Kind")
		if kind == "ui:sauce" then
			Panels.open("sauce")
		elseif kind == "ui:pitshop" then
			Panels.open("shop")
		elseif kind == "npc:unc" then
			Net.act("HearJoke")
		end
	end)

	-- Trampoline: big bounce (that's how you reach the Sauce Shack roof).
	local lastBounce = 0
	local function hookChar(char: Model)
		local hum = char:WaitForChild("Humanoid", 10) :: Humanoid?
		local hrp = char:WaitForChild("HumanoidRootPart", 10) :: BasePart?
		if not hum or not hrp then
			return
		end
		hrp.Touched:Connect(function(hit)
			local power = hit:GetAttribute("Bounce")
			if typeof(power) == "number" and os.clock() - lastBounce > 0.4 then
				lastBounce = os.clock()
				local v = hrp.AssemblyLinearVelocity
				hrp.AssemblyLinearVelocity = Vector3.new(v.X, power, v.Z)
			end
		end)
	end
	if player.Character then
		task.spawn(hookChar, player.Character)
	end
	player.CharacterAdded:Connect(hookChar)

	-- AFK: "Unc is resting his eyes"
	local lastInput = os.clock()
	local resting = false
	UserInputService.InputBegan:Connect(function()
		lastInput = os.clock()
	end)
	UserInputService.TouchStarted:Connect(function()
		lastInput = os.clock()
	end)
	task.spawn(function()
		while true do
			task.wait(2)
			local idle = os.clock() - lastInput > Config.RESTING_IDLE_SECONDS
			if idle ~= resting then
				resting = idle
				Net.act("SetResting", resting)
			end
		end
	end)

	-- Live countdowns on your own smokers' billboards.
	task.spawn(function()
		while true do
			task.wait(0.5)
			local s = Net.state
			local map = workspace:FindFirstChild("Map")
			if s and s.plot and map then
				local plot = map.Plots:FindFirstChild("Plot" .. s.plot)
				if plot then
					for key, st in pairs(s.stations) do
						if string.sub(key, 1, 1) == "s" then
							local sm = plot.Smokers:FindFirstChild(key)
							local gui = sm and sm.Barrel:FindFirstChild("SlotGui")
							local label = gui and gui:FindFirstChild("Text") :: TextLabel?
							if label then
								local _, remaining, done = Hud.view(st, s.boost)
								local meat = Config.Meats[st.meat]
								label.Text = meat.icon .. " " .. meat.name .. (done and "\n✅ Ready!" or ("\n" .. TimeUtil.formatDuration(remaining)))
							end
						end
					end
				end
			end
		end
	end)
end

return WorldClient
