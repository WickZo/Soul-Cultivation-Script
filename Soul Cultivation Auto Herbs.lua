-- LOAD ORION LIBRARY
local OrionLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/jensonhirst/Orion/main/source"))()
local Window = OrionLib:MakeWindow({Name = "Blood Flower Collector", HidePremium = true, SaveConfig = true, ConfigFolder = "BloodFlowerCollector"})

-- SERVICES
local workspace = game:GetService("Workspace")
local userInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local currentIndex = 1
local isMoving = false
local isActive = false
local currentTween = nil
local maxFlowers = 53
local atFlower = false
local waitingForAdorneeClear = false
local harvestTimeout = nil
local timeoutDuration = 3 -- default
local isFloating = false
local bodyVelocity = nil
local bodyGyro = nil

-- Flower type to farm (nil = all, or set to specific flower)
local targetFlowerType = "Blood Flowers"

-- Movement speed (default)
local MOVE_SPEED = 450

-- Harvest remote
local harvestRemote = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("Harvest")

-- FUNCTIONS DECLARED
local getBloodFlowerByIndex
local flowerExistsAtIndex
local findNextExistingIndex
local stopMovement
local startFloating
local stopFloating
local fireHarvestRemote
local moveToFlower
local moveToNextFlower
local startCollection
local stopCollection
local setupHarvestPrompt
local startHarvestTimeout
local stopHarvestTimeout
local onCharacterAdded

-- ================== ORION UI ==================
local MainTab = Window:MakeTab({Name = "Settings", Icon = "rbxassetid://4483345998", PremiumOnly = false})

-- Speed slider
MainTab:AddSlider({
    Name = "Movement Speed",
    Min = 0,
    Max = 600,
    Default = MOVE_SPEED,
    Color = Color3.fromRGB(0,170,255),
    Increment = 10,
    ValueName = "studs/sec",
    Callback = function(value)
        MOVE_SPEED = value
    end
})

-- Timeout slider
MainTab:AddSlider({
    Name = "Harvest Timeout",
    Min = 1,
    Max = 10,
    Default = timeoutDuration,
    Color = Color3.fromRGB(255,170,0),
    Increment = 0.5,
    ValueName = "seconds",
    Callback = function(value)
        timeoutDuration = value
    end
})

-- Flower selection dropdown
local allFlowers = {
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
}

MainTab:AddDropdown({
    Name = "Target Flower",
    Default = targetFlowerType,
    Options = allFlowers,
    Callback = function(value)
        targetFlowerType = value
    end
})

-- Start/Stop button
MainTab:AddButton({
    Name = "Start / Stop Collection",
    Callback = function()
        if isActive then
            stopCollection()
        else
            startCollection()
        end
    end
})

-- ================== SCRIPT LOGIC ==================

-- Character respawn handler
onCharacterAdded = function(character)
    stopFloating()
    if isActive then
        task.wait(3)
        if isActive then
            local flower = getBloodFlowerByIndex(currentIndex)
            if flower then
                moveToFlower(flower)
            else
                moveToNextFlower()
            end
        end
    end
end
player.CharacterAdded:Connect(onCharacterAdded)

-- Get flower by index
getBloodFlowerByIndex = function(index)
    local success, flower = pcall(function()
        local herbsFolder = workspace:FindFirstChild("Herbs")
        if not herbsFolder then return nil end

        local flowerFolders
        if targetFlowerType and targetFlowerType ~= "" then
            flowerFolders = {targetFlowerType}
        else
            flowerFolders = allFlowers
        end

        for _, folderName in ipairs(flowerFolders) do
            local flowerFolder = herbsFolder:FindFirstChild(folderName)
            if flowerFolder then
                local innerFolder = flowerFolder:FindFirstChild("Folder")
                if innerFolder then
                    local children = innerFolder:GetChildren()
                    if children[index] then
                        return children[index]
                    end
                end
            end
        end
        return nil
    end)
    if success and flower then return flower end
    return nil
end

-- Check if flower exists
flowerExistsAtIndex = function(index)
    return getBloodFlowerByIndex(index) ~= nil
end

-- Find next existing flower
findNextExistingIndex = function(startFrom)
    for i = startFrom, maxFlowers do
        if flowerExistsAtIndex(i) then return i end
    end
    for i = 1, startFrom - 1 do
        if flowerExistsAtIndex(i) then return i end
    end
    return nil
end

-- Stop movement
stopMovement = function()
    if currentTween then currentTween:Cancel() currentTween = nil end
    isMoving = false
end

-- Floating
startFloating = function()
    stopFloating()
    local character = player.Character
    if not character then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.MaxForce = Vector3.new(4000,4000,4000)
    bodyVelocity.Velocity = Vector3.new(0,0,0)
    bodyVelocity.Parent = hrp
    bodyGyro = Instance.new("BodyGyro")
    bodyGyro.MaxTorque = Vector3.new(4000,4000,4000)
    bodyGyro.CFrame = CFrame.new(hrp.Position)
    bodyGyro.Parent = hrp
    isFloating = true
end

stopFloating = function()
    if bodyVelocity then bodyVelocity:Destroy() bodyVelocity=nil end
    if bodyGyro then bodyGyro:Destroy() bodyGyro=nil end
    isFloating = false
end

fireHarvestRemote = function()
    startFloating()
    local success, err = pcall(function()
        harvestRemote:FireServer()
    end)
    startHarvestTimeout()
end

startHarvestTimeout = function()
    stopHarvestTimeout()
    harvestTimeout = tick() + timeoutDuration
    task.spawn(function()
        while waitingForAdorneeClear and isActive do
            if tick() >= harvestTimeout then
                stopFloating()
                waitingForAdorneeClear = false
                atFlower = false
                if isActive then
                    moveToNextFlower()
                end
                break
            end
            task.wait(0.5)
        end
    end)
end

stopHarvestTimeout = function()
    harvestTimeout = nil
end

setupHarvestPrompt = function()
    local harvestPrompt = playerGui:FindFirstChild("harvestPrompt")
    if harvestPrompt then
        harvestPrompt:GetPropertyChangedSignal("Adornee"):Connect(function()
            local adornee = harvestPrompt.Adornee
            if adornee then
                local flowerFolder
                if targetFlowerType and targetFlowerType~="" then
                    local folder = workspace:FindFirstChild("Herbs") and workspace.Herbs:FindFirstChild(targetFlowerType)
                    flowerFolder = folder and folder:FindFirstChild("Folder")
                else
                    local bloodFolder = workspace:FindFirstChild("Herbs") and workspace.Herbs:FindFirstChild("Blood Flowers")
                    flowerFolder = bloodFolder and bloodFolder:FindFirstChild("Folder")
                end
                if flowerFolder and adornee:IsDescendantOf(flowerFolder) then
                    if not waitingForAdorneeClear then
                        atFlower = true
                        waitingForAdorneeClear = true
                        fireHarvestRemote()
                    end
                end
            else
                if waitingForAdorneeClear then
                    stopFloating()
                    stopHarvestTimeout()
                    waitingForAdorneeClear = false
                    atFlower = false
                    if isActive then moveToNextFlower() end
                end
            end
        end)
    else
        playerGui.ChildAdded:Connect(function(child)
            if child.Name=="harvestPrompt" then
                setupHarvestPrompt()
            end
        end)
    end
end

-- Move to flower
moveToFlower = function(flower)
    if not flower or not flower.Parent then
        if isActive then moveToNextFlower() end
        return
    end
    if isMoving then return end
    isMoving = true
    local character = player.Character or player.CharacterAdded:Wait()
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then isMoving=false; if isActive then moveToNextFlower() end return end
    local targetPos = flower.Position + Vector3.new(0,3,0)
    local distance = (hrp.Position - targetPos).Magnitude
    local duration = math.max(0.2, distance / MOVE_SPEED)
    local tween = TweenService:Create(hrp, TweenInfo.new(duration, Enum.EasingStyle.Linear), {CFrame = CFrame.new(targetPos)})
    currentTween = tween
    tween:Play()
    tween.Completed:Connect(function()
        isMoving=false
        currentTween=nil
    end)
end

-- Move to next flower (wrap around)
moveToNextFlower = function()
    if not isActive then return end
    local nextIndex = findNextExistingIndex(currentIndex + 1)
    if nextIndex then
        currentIndex = nextIndex
        local nextFlower = getBloodFlowerByIndex(currentIndex)
        if nextFlower then moveToFlower(nextFlower) else moveToNextFlower() end
    else
        currentIndex=1
        local firstFlower = getBloodFlowerByIndex(1)
        if firstFlower then moveToFlower(firstFlower) else isActive=false end
    end
end

-- Start collection
startCollection = function()
    if isActive then return end
    local firstIndex = findNextExistingIndex(1)
    if not firstIndex then return end
    isActive=true
    currentIndex=firstIndex
    waitingForAdorneeClear=false
    atFlower=false
    setupHarvestPrompt()
    local firstFlower = getBloodFlowerByIndex(firstIndex)
    if firstFlower then moveToFlower(firstFlower) else isActive=false end
end

-- Stop collection
stopCollection = function()
    isActive=false
    atFlower=false
    waitingForAdorneeClear=false
    stopFloating()
    stopHarvestTimeout()
    stopMovement()
end

-- Keybind (P)
userInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode==Enum.KeyCode.P then
        if isActive then stopCollection() else startCollection() end
    end
end)

OrionLib:Init()