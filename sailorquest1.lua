if not game:IsLoaded() then game.Loaded:Wait() end
local RS  = game:GetService("ReplicatedStorage")
local LP  = game:GetService("Players").LocalPlayer
local WS  = game:GetService("Workspace")

local Remote    = require(RS.Shared.Framework.Network.Remote)
local LD        = require(RS.Client.Framework.Services.LocalData)
local QuestUtil = require(RS.Shared.Utils.Stats.QuestUtil)
local FAUtil    = require(RS.Shared.Utils.FishingAreasUtil)

local fishOn = false

local STAND_POS = {
    starter  = Vector3.new(-23681, 9,  -118),
    blizzard = Vector3.new(-21444, 8,  -100962),
    jungle   = Vector3.new(-19340, 8,   18723),
    lava     = Vector3.new(-17253, 11, -20446),
    atlantis = Vector3.new(-13946, 8,  -20471),
    dream    = Vector3.new(-21828, 9,  -20563),
    classic  = Vector3.new(-41534, 10, -20553),
}

local AREA_WATER = {
    starter  = Vector3.new(-23607, 3,  -35),
    blizzard = Vector3.new(-21479, 10, -100737),
    jungle   = Vector3.new(-19332, 10,  19080),
    lava     = Vector3.new(-17239, 5,  -20286),
    atlantis = Vector3.new(-13972, 0,  -20347),
    dream    = Vector3.new(-21753, 4,  -20480),
    classic  = Vector3.new(-41528, 3,  -20598),
}

local AREA_MAP = {
    starter  = "starter",
    blizzard = "blizzard",
    jungle   = "jungle",
    lava     = "lava",
    atlantis = "atlantis",
    dream    = "dream",
    classic  = "classic",
}

local function getQuestArea()
    local d = LD:Get()
    if not d then return nil end
    local quest = QuestUtil:FindById(d, "sailor-bounty")
    if not quest or not quest.Tasks then return nil end
    local task = quest.Tasks[1]
    if not task then return nil end
    return task.Area
end

local function getQuestProgress()
    local d = LD:Get()
    if not d then return nil, nil end
    local quest = QuestUtil:FindById(d, "sailor-bounty")
    if not quest or not quest.Tasks then return nil, nil end
    local t = quest.Tasks[1]
    local prog = quest.Progress and quest.Progress[1] or 0
    return prog, t and t.Amount or 0
end

local function teleport(areaId)
    local pos = STAND_POS[areaId] or STAND_POS.starter
    local char = LP.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    hrp.CFrame = CFrame.new(pos)
    task.wait(1.5)
end

local function getRealAreaRoot(areaId)
    local areas = FAUtil:GetActiveAreas()
    for _, area in pairs(areas) do
        if area.Id == areaId then
            local inst = area.Instance
            if inst then
                local r = inst:FindFirstChild("Root")
                if r then return r.Position end
            end
        end
    end
    return AREA_WATER[areaId] or AREA_WATER.starter
end

local function doFish(areaId)
    local waterPos = getRealAreaRoot(areaId)
    pcall(function() Remote:FireServer(nil, "BeginCastCharge", waterPos) end)
    task.wait(0.7)
    pcall(function() Remote:FireServer(nil, "FinishCastCharge", waterPos) end)
    task.wait(4)
    pcall(function() Remote:FireServer(nil, "Reel") end)
    task.wait(1)
    pcall(function() Remote:FireServer(nil, "SellAllFish") end)
end

local currentArea = nil
local lastTeleportArea = nil

task.spawn(function()
    while true do
        task.wait(0.5)
        if not fishOn then continue end
        local area = getQuestArea() or "starter"
        if area ~= lastTeleportArea then
            print("[Quest] Area geaendert: " .. area .. " -> teleportiere...")
            teleport(area)
            lastTeleportArea = area
        end
        currentArea = area
        doFish(area)
    end
end)

task.spawn(function()
    while true do
        task.wait(60)
        if fishOn then
            pcall(function() Remote:FireServer(nil, "ClaimAllFishingIndexRewards") end)
        end
    end
end)

local gui = Instance.new("ScreenGui")
gui.ResetOnSpawn = false
gui.Name = "SailorQuestGui"
gui.Parent = LP.PlayerGui

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 220, 0, 120)
frame.Position = UDim2.new(0, 10, 0, 160)
frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
frame.BorderSizePixel = 0
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
frame.Parent = gui

local pad = Instance.new("UIPadding")
pad.PaddingTop    = UDim.new(0, 8)
pad.PaddingLeft   = UDim.new(0, 8)
pad.PaddingRight  = UDim.new(0, 8)
pad.Parent = frame

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 5)
layout.Parent = frame

local function makeBtn(text)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, 0, 0, 32)
    b.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
    b.TextColor3 = Color3.fromRGB(220, 220, 230)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 13
    b.Text = text
    b.BorderSizePixel = 0
    b.AutoButtonColor = false
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    b.Parent = frame
    return b
end

local function makeLbl(text)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, 0, 0, 18)
    l.BackgroundTransparency = 1
    l.TextColor3 = Color3.fromRGB(180, 180, 200)
    l.Font = Enum.Font.Gotham
    l.TextSize = 11
    l.Text = text
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = frame
    return l
end

local fishBtn  = makeBtn("Auto Fish: AUS")
local questLbl = makeLbl("Quest: lade...")
local areaLbl  = makeLbl("Area: ?")
local tpBtn    = makeBtn("Teleport zu Area")

fishBtn.MouseButton1Click:Connect(function()
    fishOn = not fishOn
    fishBtn.Text = fishOn and "Auto Fish: AN" or "Auto Fish: AUS"
    fishBtn.BackgroundColor3 = fishOn
        and Color3.fromRGB(50, 180, 80)
        or  Color3.fromRGB(40, 40, 55)
    if fishOn then
        lastTeleportArea = nil
    end
end)

tpBtn.MouseButton1Click:Connect(function()
    local area = getQuestArea() or "starter"
    teleport(area)
end)

task.spawn(function()
    while true do
        task.wait(2)
        local prog, amt = getQuestProgress()
        local area = getQuestArea()
        if prog then
            questLbl.Text = "Quest: " .. tostring(prog) .. "/" .. tostring(amt)
        else
            questLbl.Text = "Quest: Keine aktiv"
        end
        areaLbl.Text = "Area: " .. (area or "beliebig")
    end
end)

print("Sailor Quest Script geladen!")
