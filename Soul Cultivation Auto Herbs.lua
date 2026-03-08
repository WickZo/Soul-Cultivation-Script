--// ORION UI
local OrionLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/jensonhirst/Orion/main/source"))()

local Window = OrionLib:MakeWindow({
	Name = "Herb / Treasure / Altar Automation",
	HidePremium = true,
	SaveConfig = false
})

--// SERVICES
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

--// REMOTES
local HarvestRemote = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("Harvest")

--// VARIABLES
local herbRunning = false
local treasureRunning = false
local altarRunning = false

local herbThread = nil
local treasureThread = nil
local altarThread = nil

local moving = false

local selectedHerb = "Blood Flowers"

local treasureSelection = {
	Common = false,
	Rare = false,
	["Very Rare"] = false,
	Lost = false
}

local tweenSpeed = 300
local timeoutDuration = 3

--// FAST OPEN
local function fastOpen(chest)

	for _,prompt in ipairs(chest:GetDescendants()) do

		if prompt:IsA("ProximityPrompt") then

			pcall(function()
				prompt.HoldDuration = 0
			end)

			for i=1,3 do
				fireproximityprompt(prompt,0)
				task.wait(0.05)
			end

			return
		end
	end

end

--// CHARACTER
local function getCharacter()
	return player.Character or player.CharacterAdded:Wait()
end

--// FLY
local function enableFly()

	local char = getCharacter()
	local hrp = char:WaitForChild("HumanoidRootPart")

	local bv = Instance.new("BodyVelocity")
	bv.MaxForce = Vector3.new(999999,999999,999999)
	bv.Velocity = Vector3.new(0,0,0)
	bv.Parent = hrp

	return bv

end

--// SAFE MOVE
local function moveTo(pos)

	if moving then return end
	moving = true

	local char = getCharacter()
	local hrp = char:WaitForChild("HumanoidRootPart")

	local dist = (hrp.Position - pos).Magnitude
	local time = dist / math.max(tweenSpeed,1)

	local tween = TweenService:Create(
		hrp,
		TweenInfo.new(time,Enum.EasingStyle.Linear),
		{CFrame = CFrame.new(pos + Vector3.new(0,3,0))}
	)

	tween:Play()
	tween.Completed:Wait()

	moving = false

end

--// HERB LOOP
local function herbLoop()

	while herbRunning do

		local herbFolder = Workspace.Herbs:FindFirstChild(selectedHerb)

		if herbFolder then

			local container = herbFolder:FindFirstChild("Folder")

			if container then

				for _,herb in ipairs(container:GetChildren()) do

					if not herbRunning then break end

					local pos = herb:GetPivot().Position

					moveTo(pos)

					local prompt = player.PlayerGui:FindFirstChild("harvestPrompt")

					local start = tick()

					-- wait for adornee appear
					while tick()-start < timeoutDuration do

						if prompt and prompt.Adornee then
							break
						end

						task.wait(0.1)

					end

					local fly = enableFly()

					-- press E once
					HarvestRemote:FireServer()

					local harvestStart = tick()

					-- wait for adornee disappear
					while tick()-harvestStart < timeoutDuration do

						if not prompt or not prompt.Adornee then
							break
						end

						task.wait(0.2)

					end

					if fly then
						fly:Destroy()
					end

					task.wait(0.3)

				end

			end

		end

		task.wait(0.5)

	end

end

--// TREASURE LOOP
local function treasureLoop()

	while treasureRunning do

		for _,treasure in ipairs(Workspace.Treasures:GetChildren()) do

			if not treasureRunning then break end

			local name = treasure.Name
			local allowed = false

			if name:find("Very Rare") and treasureSelection["Very Rare"] then
				allowed = true

			elseif name:find("Rare") and treasureSelection.Rare then
				allowed = true

			elseif name:find("Common") and treasureSelection.Common then
				allowed = true

			elseif name:find("Lost") and treasureSelection.Lost then
				allowed = true
			end

			if allowed then

				moveTo(treasure:GetPivot().Position)

				fastOpen(treasure)

				task.wait(0.2)

			end

		end

		task.wait(0.5)

	end

end

--// ALTARS
local altarPrompts = {}

for _,obj in ipairs(Workspace.Altars:GetDescendants()) do
	if obj:IsA("ProximityPrompt") then
		table.insert(altarPrompts,obj)
	end
end

local function altarLoop()

	while altarRunning do

		for _,prompt in ipairs(altarPrompts) do

			if not altarRunning then break end

			local part = prompt.Parent

			if part then

				moveTo(part:GetPivot().Position)

				pcall(function()
					prompt.HoldDuration = 0
				end)

				fireproximityprompt(prompt,0)

			end

		end

		task.wait(1)

	end

end

--// RESUME AFTER DEATH
player.CharacterAdded:Connect(function()

	task.wait(2)

	if herbRunning and not herbThread then
		herbThread = task.spawn(function()
			herbLoop()
			herbThread = nil
		end)
	end

	if treasureRunning and not treasureThread then
		treasureThread = task.spawn(function()
			treasureLoop()
			treasureThread = nil
		end)
	end

	if altarRunning and not altarThread then
		altarThread = task.spawn(function()
			altarLoop()
			altarThread = nil
		end)
	end

end)

--// UI TABS
local HerbTab = Window:MakeTab({Name="Herbs"})
local TreasureTab = Window:MakeTab({Name="Treasures"})
local AltarTab = Window:MakeTab({Name="Altars"})
local SettingsTab = Window:MakeTab({Name="Settings"})

--// HERB DROPDOWN
HerbTab:AddDropdown({
	Name="Select Herb",
	Default="Blood Flowers",
	Options={
		"Blood Flowers",
		"Ginseng",
		"Lingzhi",
		"Moonlight Flowers",
		"Qilin Berries",
		"Spirit Grass",
		"Taixian",
		"Twilight Bloom",
		"Yang Flower",
		"Yin Bush"
	},
	Callback=function(v)
		selectedHerb=v
	end
})

--// HERB TOGGLE
HerbTab:AddToggle({
	Name="Start Herb Collection",
	Default=false,
	Callback=function(v)

		herbRunning=v

		if v and not herbThread then
			herbThread = task.spawn(function()
				herbLoop()
				herbThread = nil
			end)
		end

	end
})

--// TREASURE MULTI SELECT
TreasureTab:AddToggle({
	Name="Common",
	Default=false,
	Callback=function(v)
		treasureSelection.Common=v
	end
})

TreasureTab:AddToggle({
	Name="Rare",
	Default=false,
	Callback=function(v)
		treasureSelection.Rare=v
	end
})

TreasureTab:AddToggle({
	Name="Very Rare",
	Default=false,
	Callback=function(v)
		treasureSelection["Very Rare"]=v
	end
})

TreasureTab:AddToggle({
	Name="Lost",
	Default=false,
	Callback=function(v)
		treasureSelection.Lost=v
	end
})

TreasureTab:AddToggle({
	Name="Start Treasure Collection",
	Default=false,
	Callback=function(v)

		treasureRunning=v

		if v and not treasureThread then
			treasureThread = task.spawn(function()
				treasureLoop()
				treasureThread = nil
			end)
		end

	end
})

--// ALTARS
AltarTab:AddToggle({
	Name="Auto Altars",
	Default=false,
	Callback=function(v)

		altarRunning=v

		if v and not altarThread then
			altarThread = task.spawn(function()
				altarLoop()
				altarThread = nil
			end)
		end

	end
})

--// SETTINGS
SettingsTab:AddSlider({
	Name="Tween Speed",
	Min=0,
	Max=800,
	Default=300,
	Callback=function(v)
		tweenSpeed=v
	end
})

SettingsTab:AddSlider({
	Name="Harvest Timeout",
	Min=1,
	Max=10,
	Default=3,
	Callback=function(v)
		timeoutDuration=v
	end
})

OrionLib:Init()
