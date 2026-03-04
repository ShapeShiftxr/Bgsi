if not game:IsLoaded() then game.Loaded:Wait() end
local RS = game:GetService("ReplicatedStorage")
local LP = game:GetService("Players").LocalPlayer

local LD        = require(RS.Client.Framework.Services.LocalData)
local QuestUtil = require(RS.Shared.Utils.Stats.QuestUtil)

local AutoFishModule = nil
pcall(function()
    AutoFishModule = require(RS.Client.Gui.Frames.Fishing.FishingWorldAutoFish)
end)

-- Standposition neben Wasser + LookVector Richtung Wasser
local AREAS = {
    starter  = { stand = Vector3.new(-23590, 12, -35),  look = Vector3.new(-23607, 3,  -35)  },
    blizzard = { stand = Vector3.new(-21462, 18, -100737), look = Vector3.new(-21479, 10, -100737) },
    jungle   = { stand = Vector3.new(-19315, 18,  19080), look = Vector3.new(-19332, 9,   19080) },
    lava     = { stand = Vector3.new(-17222, 14, -20286), look = Vector3.new(-17239, 5,  -20286) },
    atlantis = { stand = Vector3.new(-13955,  9, -20347), look = Vector3.new(-13972, 0,  -20347) },
    dream    = { stand = Vector3.new(-21736, 12, -20480), look = Vector3.new(-21753, 4,  -20480) },
    classic  = { stand = Vector3.new(-41511, 11, -20598), look = Vector3.new(-41528, 3,  -20598) },
}

local function getQuestArea()
    local d = LD:Get()
    if not d then return nil end
    local quest = QuestUtil:FindById(d, "sailor-bounty")
    if not quest or not quest.Tasks then return nil end
    return quest.Tasks[1] and quest.Tasks[1].Area or nil
end

local function getProgress()
    local d = LD:Get()
    if not d then return "?", "?" end
    local quest = QuestUtil:FindById(d, "sailor-bounty")
    if not quest or not quest.Tasks then return "?", "?" end
    return quest.Progress and quest.Progress[1] or 0, quest.Tasks[1] and quest.Tasks[1].Amount or "?"
end

local function teleportAndLook(areaId)
    local a = AREAS[areaId] or AREAS.starter
    local char = LP.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    -- Charakter platzieren UND in Richtung Wasser schauen lassen
    local standPos = a.stand
    local lookPos  = a.look
    local dir = (Vector3.new(lookPos.X, standPos.Y, lookPos.Z) - standPos).Unit
    hrp.CFrame = CFrame.new(standPos, standPos + dir)
    task.wait(1.5)
end

local function enableAutoFish()
    if not AutoFishModule then return false end
    local ok = pcall(function()
        if not AutoFishModule:IsEnabled() then
            AutoFishModule:SetEnabled(true)
        end
    end)
    return ok
end

local function disableAutoFish()
    if not AutoFishModule then return end
    pcall(function()
        if AutoFishModule:IsEnabled() then
            AutoFishModule:SetEnabled(false)
        end
    end)
end

local fishOn = false
local lastArea = nil

task.spawn(function()
    while true do
        task.wait(1)
        if not fishOn then continue end
        local area = getQuestArea() or "starter"
        if area ~= lastArea then
            print("[Quest] Area: " .. area)
            disableAutoFish()
            teleportAndLook(area)
            task.wait(0.5)
            enableAutoFish()
            lastArea = area
        end
        if not AutoFishModule:IsEnabled() then
            teleportAndLook(area)
            task.wait(0.3)
            enableAutoFish()
        end
    end
end)

-- GUI
local gui = Instance.new("ScreenGui")
gui.ResetOnSpawn = false
gui.Name = "SailorQuestGui"
gui.Parent = LP.PlayerGui

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 210, 0, 120)
frame.Position = UDim2.new(0, 10, 0, 160)
frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
frame.BorderSizePixel = 0
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
frame.Parent = gui

local pad = Instance.new("UIPadding", frame)
pad.PaddingTop = UDim.new(0, 8)
pad.PaddingLeft = UDim.new(0, 8)
pad.PaddingRight = UDim.new(0, 8)
local layout = Instance.new("UIListLayout", frame)
layout.Padding = UDim.new(0, 5)

local function makeBtn(text)
    local b = Instance.new("TextButton", frame)
    b.Size = UDim2.new(1, 0, 0, 30)
    b.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
    b.TextColor3 = Color3.fromRGB(220, 220, 230)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 13
    b.Text = text
    b.BorderSizePixel = 0
    b.AutoButtonColor = false
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    return b
end
local function makeLbl(text)
    local l = Instance.new("TextLabel", frame)
    l.Size = UDim2.new(1, 0, 0, 17)
    l.BackgroundTransparency = 1
    l.TextColor3 = Color3.fromRGB(180, 180, 200)
    l.Font = Enum.Font.Gotham
    l.TextSize = 11
    l.Text = text
    l.TextXAlignment = Enum.TextXAlignment.Left
    return l
end

local fishBtn  = makeBtn("Auto Fish Quest: AUS")
local tpBtn    = makeBtn("Teleport zu Area")
local questLbl = makeLbl("Quest: lade...")
local areaLbl  = makeLbl("Area: ?")

fishBtn.MouseButton1Click:Connect(function()
    fishOn = not fishOn
    fishBtn.Text = fishOn and "Auto Fish Quest: AN" or "Auto Fish Quest: AUS"
    fishBtn.BackgroundColor3 = fishOn and Color3.fromRGB(50,180,80) or Color3.fromRGB(40,40,55)
    if fishOn then
        lastArea = nil
    else
        disableAutoFish()
    end
end)

tpBtn.MouseButton1Click:Connect(function()
    teleportAndLook(getQuestArea() or "starter")
end)

task.spawn(function()
    while true do
        task.wait(2)
        local p, a = getProgress()
        questLbl.Text = "Quest: " .. tostring(p) .. "/" .. tostring(a)
        areaLbl.Text  = "Area: " .. (getQuestArea() or "beliebig")
    end
end)

print("Sailor Quest geladen!")
