if not game:IsLoaded() then game.Loaded:Wait() end
local RS  = game:GetService("ReplicatedStorage")
local LP  = game:GetService("Players").LocalPlayer
local WS  = game:GetService("Workspace")

local Remote   = require(RS.Shared.Framework.Network.Remote)
local LD       = require(RS.Client.Framework.Services.LocalData)
local QuestUtil = require(RS.Shared.Utils.Stats.QuestUtil)
local FAUtil   = require(RS.Shared.Utils.FishingAreasUtil)

local fishOn = false

local AREA_POSITIONS = {
    starter  = Vector3.new(-1160, 102, 1244),
    blizzard = Vector3.new(-1445, 102, 777),
    jungle   = Vector3.new(-1050, 102, 480),
    lava     = Vector3.new(-745,  102, 777),
    moon     = Vector3.new(-745,  102, 1244),
    deep     = Vector3.new(-1050, 102, 1244),
    ancient  = Vector3.new(-1445, 102, 1244),
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

local function teleportToArea(areaId)
    local target = AREA_POSITIONS[areaId] or AREA_POSITIONS.starter
    local char = LP.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    hrp.CFrame = CFrame.new(target)
    task.wait(1)
end

local function findAreaRoot(areaId)
    local areas = FAUtil:GetActiveAreas()
    for _, area in pairs(areas) do
        if area.Id == areaId then
            return area.Instance and area.Instance:FindFirstChild("Root")
        end
    end
    return nil
end

local function doFish(areaId)
    local root = findAreaRoot(areaId or "starter")
    local castPos
    if root then
        castPos = root.Position
    else
        castPos = AREA_POSITIONS[areaId or "starter"]
    end

    Remote:FireServer(nil, "BeginCastCharge", castPos)
    task.wait(0.6)
    Remote:FireServer(nil, "FinishCastCharge", castPos)
    task.wait(3.5)
    Remote:FireServer(nil, "Reel")
    task.wait(1)
    Remote:FireServer(nil, "SellAllFish")
end

local currentArea = nil

task.spawn(function()
    while true do
        task.wait(0.5)
        if not fishOn then continue end

        local area = getQuestArea()
        if area and area ~= currentArea then
            print("[Quest] Neue Area erkannt: " .. area)
            currentArea = area
            teleportToArea(area)
        elseif not area then
            currentArea = currentArea or "starter"
        end

        doFish(currentArea or "starter")
    end
end)

local LD2 = require(RS.Client.Framework.Services.LocalData)
task.spawn(function()
    while true do
        task.wait(30)
        if fishOn then
            Remote:FireServer(nil, "ClaimAllFishingIndexRewards")
        end
    end
end)

local gui = Instance.new("ScreenGui")
gui.ResetOnSpawn = false
gui.Name = "SailorQuestGui"
gui.Parent = LP.PlayerGui

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 220, 0, 110)
frame.Position = UDim2.new(0, 10, 0, 160)
frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
frame.BorderSizePixel = 0
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
frame.Parent = gui

local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0, 8)
pad.PaddingLeft = UDim.new(0, 8)
pad.PaddingRight = UDim.new(0, 8)
pad.Parent = frame

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.Parent = frame

local function makeBtn(text, parent)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, 0, 0, 30)
    b.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
    b.TextColor3 = Color3.fromRGB(220, 220, 230)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 13
    b.Text = text
    b.BorderSizePixel = 0
    b.AutoButtonColor = false
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    b.Parent = parent
    return b
end

local makeLabel
makeLabel = function(text, parent)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, 0, 0, 20)
    l.BackgroundTransparency = 1
    l.TextColor3 = Color3.fromRGB(180, 180, 200)
    l.Font = Enum.Font.Gotham
    l.TextSize = 11
    l.Text = text
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = parent
    return l
end

local fishBtn  = makeBtn("Auto Fish Quest: AUS", frame)
local questLbl = makeLabel("Quest: wird geladen...", frame)
local areaLbl  = makeLabel("Area: ?", frame)

fishBtn.MouseButton1Click:Connect(function()
    fishOn = not fishOn
    fishBtn.Text = fishOn and "Auto Fish Quest: AN" or "Auto Fish Quest: AUS"
    fishBtn.BackgroundColor3 = fishOn and Color3.fromRGB(50,180,80) or Color3.fromRGB(40,40,55)
    if fishOn then
        local area = getQuestArea()
        currentArea = area
        if area then teleportToArea(area) end
    end
end)

task.spawn(function()
    while true do
        task.wait(2)
        local d = LD:Get()
        if d then
            local quest = QuestUtil:FindById(d, "sailor-bounty")
            if quest and quest.Tasks and quest.Tasks[1] then
                local t = quest.Tasks[1]
                local prog = quest.Progress and quest.Progress[1] or 0
                local amt  = t.Amount or "?"
                local area = t.Area or "Beliebig"
                questLbl.Text = "Aufgabe: " .. tostring(prog) .. "/" .. tostring(amt)
                areaLbl.Text  = "Area: " .. tostring(area)
            else
                questLbl.Text = "Quest: Keine aktiv"
                areaLbl.Text  = "Area: -"
            end
        end
    end
end)

print("Sailor Quest Script geladen!")
