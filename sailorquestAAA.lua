if not game:IsLoaded() then game.Loaded:Wait() end
local RS  = game:GetService("ReplicatedStorage")
local LP  = game:GetService("Players").LocalPlayer
local WS  = game:GetService("Workspace")

local Remote    = require(RS.Shared.Framework.Network.Remote)
local LD        = require(RS.Client.Framework.Services.LocalData)
local QuestUtil = require(RS.Shared.Utils.Stats.QuestUtil)
local FAUtil    = require(RS.Shared.Utils.FishingAreasUtil)

local AutoFishModule = nil
pcall(function()
    AutoFishModule = require(RS.Client.Gui.Frames.Fishing.FishingWorldAutoFish)
end)

local fishOn = false
local lastArea = nil

local function getQuestArea()
    local d = LD:Get()
    if not d then return nil end
    local quest = QuestUtil:FindById(d, "sailor-bounty")
    if not quest or not quest.Tasks then return nil end
    return quest.Tasks[1] and quest.Tasks[1].Area or nil
end

local function getProgress()
    local d = LD:Get()
    if not d then return "?","?" end
    local quest = QuestUtil:FindById(d, "sailor-bounty")
    if not quest or not quest.Tasks then return "?","?" end
    return quest.Progress and quest.Progress[1] or 0,
           quest.Tasks[1] and quest.Tasks[1].Amount or "?"
end

local function equipRod()
    pcall(function() Remote:FireServer(nil, "EquipRod") end)
    task.wait(0.5)
end

-- Findet die nächste FishingArea Root für die gewünschte Area-ID
-- und gibt eine Standposition 6 Studs davor zurück
local function getStandPos(areaId)
    local areas = FAUtil:GetActiveAreas()
    local bestRoot = nil
    local bestDist = math.huge

    -- Charakter Position als Referenz (oder Welt-Mittelpunkt)
    local char = LP.Character
    local ref = char and char:FindFirstChild("HumanoidRootPart")
    local refPos = ref and ref.Position or Vector3.new(0, 0, 0)

    for _, area in pairs(areas) do
        if area.Id == areaId or areaId == nil then
            local inst = area.Instance
            if inst then
                local r = inst:FindFirstChild("Root")
                if r then
                    local d = (r.Position - refPos).Magnitude
                    if d < bestDist then
                        bestDist = d
                        bestRoot = r
                    end
                end
            end
        end
    end

    if not bestRoot then return nil, nil end

    local waterPos = bestRoot.Position
    -- 6 Studs vor dem Wasser (auf Y des Wassers + 5 damit wir auf dem Boden landen)
    -- Richtung: vom Wasser weg (nach oben auf der XZ-Ebene, willkürlich Z+)
    -- Besser: suche festen Boden via Raycast 6 Studs entfernt
    local offsets = {
        Vector3.new( 6, 0, 0),
        Vector3.new(-6, 0, 0),
        Vector3.new( 0, 0, 6),
        Vector3.new( 0, 0,-6),
    }

    local standPos = nil
    for _, off in ipairs(offsets) do
        local testXZ = waterPos + off
        local ray = WS:Raycast(
            Vector3.new(testXZ.X, waterPos.Y + 20, testXZ.Z),
            Vector3.new(0, -40, 0)
        )
        if ray then
            -- Boden gefunden, 3 Studs darüber stehen
            standPos = Vector3.new(testXZ.X, ray.Position.Y + 3, testXZ.Z)
            break
        end
    end

    -- Fallback: einfach 5 Studs hoch über dem Wasser
    if not standPos then
        standPos = waterPos + Vector3.new(6, 5, 0)
    end

    return standPos, waterPos
end

local function teleportToFishingArea(areaId)
    local standPos, waterPos = getStandPos(areaId)
    if not standPos then
        print("[Quest] Keine FishingArea gefunden fuer: " .. tostring(areaId))
        return false
    end

    local char = LP.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end

    -- CFrame so setzen dass der Spieler aufs Wasser schaut
    local lookTarget = Vector3.new(waterPos.X, standPos.Y, waterPos.Z)
    hrp.CFrame = CFrame.new(standPos, lookTarget)
    print("[Quest] TP zu " .. tostring(areaId) .. " -> " .. tostring(standPos))
    task.wait(1.5)
    return true
end

local function disableAutoFish()
    pcall(function()
        if AutoFishModule and AutoFishModule:IsEnabled() then
            AutoFishModule:SetEnabled(false)
        end
    end)
end

local function enableAutoFish()
    if not AutoFishModule then return false end
    local ok, err = pcall(function()
        if not AutoFishModule:IsEnabled() then
            AutoFishModule:SetEnabled(true)
        end
    end)
    if not ok then print("[AutoFish] Fehler: " .. tostring(err)) end
    return ok
end

task.spawn(function()
    while true do
        task.wait(1)
        if not fishOn then continue end
        local area = getQuestArea() or "starter"

        if area ~= lastArea then
            print("[Quest] Neue Area: " .. area)
            disableAutoFish()
            equipRod()
            local ok = teleportToFishingArea(area)
            if ok then
                enableAutoFish()
                lastArea = area
            end
        else
            -- Prüfe ob AutoFish noch aktiv
            local isOn = false
            pcall(function() isOn = AutoFishModule and AutoFishModule:IsEnabled() end)
            if not isOn then
                print("[Quest] AutoFish inaktiv - reaktiviere...")
                equipRod()
                teleportToFishingArea(area)
                enableAutoFish()
            end
        end
    end
end)

-- GUI
local gui = Instance.new("ScreenGui")
gui.ResetOnSpawn = false
gui.Name = "SailorQuestGui"
gui.Parent = LP.PlayerGui

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 215, 0, 125)
frame.Position = UDim2.new(0, 10, 0, 160)
frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
frame.BorderSizePixel = 0
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
frame.Parent = gui

local pad = Instance.new("UIPadding", frame)
pad.PaddingTop = UDim.new(0,8); pad.PaddingLeft = UDim.new(0,8); pad.PaddingRight = UDim.new(0,8)
local layout = Instance.new("UIListLayout", frame)
layout.Padding = UDim.new(0,5)

local function mkBtn(txt)
    local b = Instance.new("TextButton", frame)
    b.Size = UDim2.new(1,0,0,30); b.BackgroundColor3 = Color3.fromRGB(40,40,55)
    b.TextColor3 = Color3.fromRGB(220,220,230); b.Font = Enum.Font.GothamBold
    b.TextSize = 13; b.Text = txt; b.BorderSizePixel = 0; b.AutoButtonColor = false
    Instance.new("UICorner",b).CornerRadius = UDim.new(0,6)
    return b
end
local function mkLbl(txt)
    local l = Instance.new("TextLabel", frame)
    l.Size = UDim2.new(1,0,0,17); l.BackgroundTransparency = 1
    l.TextColor3 = Color3.fromRGB(180,180,200); l.Font = Enum.Font.Gotham
    l.TextSize = 11; l.Text = txt; l.TextXAlignment = Enum.TextXAlignment.Left
    return l
end

local fishBtn  = mkBtn("Auto Fish Quest: AUS")
local tpBtn    = mkBtn("Teleport zu Area")
local questLbl = mkLbl("Quest: lade...")
local areaLbl  = mkLbl("Area: ?")

fishBtn.MouseButton1Click:Connect(function()
    fishOn = not fishOn
    fishBtn.Text = fishOn and "Auto Fish Quest: AN" or "Auto Fish Quest: AUS"
    fishBtn.BackgroundColor3 = fishOn and Color3.fromRGB(50,180,80) or Color3.fromRGB(40,40,55)
    if fishOn then lastArea = nil equipRod() else disableAutoFish() end
end)

tpBtn.MouseButton1Click:Connect(function()
    equipRod()
    teleportToFishingArea(getQuestArea() or "starter")
end)

task.spawn(function()
    while true do
        task.wait(2)
        local p,a = getProgress()
        questLbl.Text = "Quest: "..tostring(p).."/"..tostring(a)
        areaLbl.Text  = "Area: "..(getQuestArea() or "beliebig")
    end
end)

print("Sailor Quest geladen!")
