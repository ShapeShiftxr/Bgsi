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

local fishOn   = false
local lastArea = nil

-- MIN_CAST_DISTANCE = 8, MAX = 20
-- getClosestRaycast: für i=1..10:
--   testPos = HRP.Pos + LookVec * (8 + step*i)  (horizontal)
--   dann Raycast(testPos, 0,-50,0)  (senkrecht runter)
--   -> trifft wenn testPos.XZ über dem FishingArea Root-Part liegt
--
-- Lösung: Spieler steht 10 Studs vom Root entfernt auf Ufer-Höhe,
-- LookVector zeigt horizontal aufs Wasser. Dann liegt
-- HRP + LookVec*10 direkt über dem Root → Raycast trifft Root.

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
    Remote:FireServer("EquipRod")
    task.wait(0.8)
end

-- Findet nächstes FishingArea Root für areaId
-- Gibt standPos zurück: genau 10 Studs vom Root entfernt,
-- auf solidem Boden (Raycast), LookVector zeigt zum Root
local function getFishSpot(areaId)
    local areas = FAUtil:GetActiveAreas()
    local bestRoot = nil
    local bestDist = math.huge

    local char   = LP.Character
    local hrp    = char and char:FindFirstChild("HumanoidRootPart")
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

    local rootPos = bestRoot.Position
    -- rootPos.Y = Wasseroberfläche (~2-10)
    -- Ufer-Höhe typisch rootPos.Y + 1-3

    -- Teste 4 Richtungen: 10 Studs vom Root weg
    -- Suche welche Richtung festen Boden hat (nicht Wasser)
    -- und von wo aus der Raycast das Root trifft
    local dirs = {
        Vector3.new( 1,0, 0),
        Vector3.new(-1,0, 0),
        Vector3.new( 0,0, 1),
        Vector3.new( 0,0,-1),
    }

    for _, dir in ipairs(dirs) do
        local testXZ = Vector3.new(
            rootPos.X + dir.X * 10,
            rootPos.Y + 30,
            rootPos.Z + dir.Z * 10
        )

        -- Raycast nach unten: gibt es Boden?
        local groundRay = WS:Raycast(testXZ, Vector3.new(0,-60,0))
        if not groundRay then continue end

        local groundY = groundRay.Position.Y
        -- Boden muss höher sein als Wasser (sonst stehen wir im Wasser)
        if groundY < rootPos.Y then continue end

        -- Spieler HRP center = groundY + 3 (halbe Charakterhöhe)
        local hrpY   = groundY + 3
        local standPos = Vector3.new(
            rootPos.X + dir.X * 10,
            hrpY,
            rootPos.Z + dir.Z * 10
        )

        -- Verifiziere: HRP + LookVec*10 liegt über rootPos.XZ?
        -- LookVec = -dir (zeigt zum Root)
        local lookVec = -dir
        local castTestPos = Vector3.new(
            standPos.X + lookVec.X * 10,
            standPos.Y,
            standPos.Z + lookVec.Z * 10
        )
        -- XZ-Abstand zum Root muss klein sein (<5 Studs)
        local xzDist = Vector2.new(
            castTestPos.X - rootPos.X,
            castTestPos.Z - rootPos.Z
        ).Magnitude

        if xzDist < 5 then
            -- Guter Spot!
            local lookTarget = Vector3.new(rootPos.X, hrpY, rootPos.Z)
            return standPos, lookTarget
        end
    end

    return nil
end

local function teleport(areaId)
    local standPos, lookTarget = getFishSpot(areaId)
    if not standPos then
        warn("[Quest] Kein Spot fuer: " .. tostring(areaId))
        return false
    end

    local char = LP.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end

    hrp.CFrame = CFrame.new(standPos, lookTarget)
    print(string.format("[Quest] TP %s Stand:(%.0f,%.0f,%.0f)",
        areaId, standPos.X, standPos.Y, standPos.Z))
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
            print("[Quest] Neue Area: " .. area)
            setAutoFish(false)
            equipRod()
            if teleport(area) then
                setAutoFish(true)
                lastArea = area
            end
        elseif not isAutoFishOn() then
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

do
    local pad = Instance.new("UIPadding", frame)
    pad.PaddingTop = UDim.new(0,8)
    pad.PaddingLeft = UDim.new(0,8)
    pad.PaddingRight = UDim.new(0,8)
    local layout = Instance.new("UIListLayout", frame)
    layout.Padding = UDim.new(0,5)
end

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
