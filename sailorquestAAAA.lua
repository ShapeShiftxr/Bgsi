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

local fishOn  = false
local lastArea = nil

local function getQuestArea()
    local d = LD:Get()
    if not d then return nil end
    local q = QuestUtil:FindById(d, "sailor-bounty")
    if not q or not q.Tasks then return nil end
    return q.Tasks[1] and q.Tasks[1].Area or nil
end

local function getProgress()
    local d = LD:Get()
    if not d then return "?","?" end
    local q = QuestUtil:FindById(d, "sailor-bounty")
    if not q or not q.Tasks then return "?","?" end
    return q.Progress and q.Progress[1] or 0,
           q.Tasks[1] and q.Tasks[1].Amount or "?"
end

local function equipRod()
    -- Exakt wie FishingHotbar: Remote:FireServer("EquipRod")
    Remote:FireServer("EquipRod")
    task.wait(0.8)
end

-- Findet nächste FishingArea Root für areaId
-- Gibt zurück: standPos (auf Wasserhöhe!), waterPos, lookDir
local function getFishSpot(areaId)
    local areas = FAUtil:GetActiveAreas()
    local bestRoot = nil
    local bestDist = math.huge

    local char  = LP.Character
    local hrp   = char and char:FindFirstChild("HumanoidRootPart")
    local refPos = hrp and hrp.Position or Vector3.new(0,0,0)

    for _, area in pairs(areas) do
        if area.Id == areaId then
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

    if not bestRoot then return nil end

    local waterPos = bestRoot.Position
    -- waterPos.Y ist die Wasseroberfläche (Root Y ~= 2-10)
    -- MIN_CAST_DISTANCE = 8 Studs
    -- getClosestRaycast: HRP.Pos + LookVec*8 dann -50Y raycast
    -- -> Spieler muss auf waterPos.Y stehen damit der Raycast das Wasser trifft
    -- -> Standort: 9 Studs vor dem Wasser, auf genau waterPos.Y

    local directions = {
        Vector3.new( 1, 0,  0),
        Vector3.new(-1, 0,  0),
        Vector3.new( 0, 0,  1),
        Vector3.new( 0, 0, -1),
    }

    -- Finde welche Richtung vom Wasser weg auf festem Boden liegt
    for _, dir in ipairs(directions) do
        local standXZ = Vector3.new(
            waterPos.X + dir.X * 9,
            waterPos.Y + 30,  -- von oben raycasten
            waterPos.Z + dir.Z * 9
        )
        local ray = WS:Raycast(standXZ, Vector3.new(0, -60, 0))
        if ray and ray.Position.Y >= waterPos.Y - 2 then
            -- Gültiger Boden gefunden
            -- Spieler auf waterPos.Y stellen (HRP center ~= Boden + 3)
            local standY = waterPos.Y + 3
            local standPos = Vector3.new(
                waterPos.X + dir.X * 9,
                standY,
                waterPos.Z + dir.Z * 9
            )
            -- LookVector zeigt vom Stand zum Wasser
            local lookDir = (waterPos - standPos).Unit
            return standPos, waterPos, lookDir
        end
    end

    return nil
end

local function teleport(areaId)
    local standPos, waterPos, lookDir = getFishSpot(areaId)
    if not standPos then
        warn("[Quest] Kein Spot fuer Area: " .. tostring(areaId))
        return false
    end

    local char = LP.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end

    -- CFrame: Position auf Wasserhöhe, schaut aufs Wasser
    hrp.CFrame = CFrame.new(standPos, standPos + lookDir)
    print(string.format("[Quest] TP %s | Stand: %.0f,%.0f,%.0f | Wasser: %.0f,%.0f,%.0f",
        areaId, standPos.X, standPos.Y, standPos.Z,
        waterPos.X, waterPos.Y, waterPos.Z))
    task.wait(1.5)
    return true
end

local function isAutoFishOn()
    if not AutoFishModule then return false end
    local ok, val = pcall(function() return AutoFishModule:IsEnabled() end)
    return ok and val
end

local function setAutoFish(state)
    if not AutoFishModule then return end
    pcall(function()
        if AutoFishModule:IsEnabled() ~= state then
            AutoFishModule:SetEnabled(state)
        end
    end)
end

task.spawn(function()
    while true do
        task.wait(1)
        if not fishOn then continue end

        local area = getQuestArea() or "starter"

        if area ~= lastArea then
            print("[Quest] Area: " .. area)
            setAutoFish(false)
            equipRod()
            local ok = teleport(area)
            if ok then
                task.wait(0.3)
                setAutoFish(true)
                lastArea = area
            end
        elseif not isAutoFishOn() then
            -- AutoFish hat sich deaktiviert (z.B. nach Inventar voll)
            print("[Quest] AutoFish reaktivieren...")
            equipRod()
            teleport(area)
            task.wait(0.3)
            setAutoFish(true)
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
pad.PaddingTop = UDim.new(0,8)
pad.PaddingLeft = UDim.new(0,8)
pad.PaddingRight = UDim.new(0,8)
local layout = Instance.new("UIListLayout", frame)
layout.Padding = UDim.new(0,5)

local function mkBtn(txt)
    local b = Instance.new("TextButton", frame)
    b.Size = UDim2.new(1,0,0,30)
    b.BackgroundColor3 = Color3.fromRGB(40,40,55)
    b.TextColor3 = Color3.fromRGB(220,220,230)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 13; b.Text = txt
    b.BorderSizePixel = 0; b.AutoButtonColor = false
    Instance.new("UICorner",b).CornerRadius = UDim.new(0,6)
    return b
end
local function mkLbl(txt)
    local l = Instance.new("TextLabel", frame)
    l.Size = UDim2.new(1,0,0,17)
    l.BackgroundTransparency = 1
    l.TextColor3 = Color3.fromRGB(180,180,200)
    l.Font = Enum.Font.Gotham
    l.TextSize = 11; l.Text = txt
    l.TextXAlignment = Enum.TextXAlignment.Left
    return l
end

local fishBtn  = mkBtn("Auto Fish Quest: AUS")
local tpBtn    = mkBtn("Teleport zu Area")
local questLbl = mkLbl("Quest: lade...")
local areaLbl  = mkLbl("Area: ?")

fishBtn.MouseButton1Click:Connect(function()
    fishOn = not fishOn
    fishBtn.Text = fishOn and "Auto Fish Quest: AN" or "Auto Fish Quest: AUS"
    fishBtn.BackgroundColor3 = fishOn
        and Color3.fromRGB(50,180,80)
        or  Color3.fromRGB(40,40,55)
    if fishOn then
        lastArea = nil
        equipRod()
    else
        setAutoFish(false)
    end
end)

tpBtn.MouseButton1Click:Connect(function()
    equipRod()
    teleport(getQuestArea() or "starter")
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
