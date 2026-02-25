-- BGS: Sailor Quest + Minigames
-- Eigenes UI, kein Rayfield

if not game:IsLoaded() then game.Loaded:Wait() end

local Players           = game:GetService("Players")
local LocalPlayer       = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local Workspace         = game:GetService("Workspace")
local UserInputService  = game:GetService("UserInputService")

-- Remote
local RE
pcall(function()
    RE = ReplicatedStorage.Shared.Framework.Network.Remote.RemoteEvent
end)
local function fire(action, ...)
    if RE then pcall(function() RE:FireServer(action, ...) end) end
end

-- LocalData fuer Quest lesen
local LocalData
pcall(function()
    LocalData = require(ReplicatedStorage.Client.Framework.Services.LocalData)
end)
local function getLD()
    if not LocalData then return nil end
    local ok, d = pcall(function() return LocalData:Get() end)
    return ok and d or nil
end
local function getQuestTask()
    local d = getLD()
    if not d then return nil end
    local QuestUtil
    pcall(function() QuestUtil = require(ReplicatedStorage.Shared.Utils.Stats.QuestUtil) end)
    if not QuestUtil then return nil end
    local ok, q = pcall(function() return QuestUtil:FindById(d, "sailor-bounty") end)
    if ok and q then return q end
    return nil
end

-- Teleport
local function tpTo(cf)
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if root then root.CFrame = cf end
end

-- ============================================================
-- ANGEL-WELTEN
-- ============================================================
local WORLDS = {
    { key="starter",   name="Fisher's Island",   area="Fisher's Island",   saved=nil, fallback=CFrame.new(-23663.1, 8, 6.9) },
    { key="blizzard",  name="Blizzard Hills",    area="Blizzard Hills",    saved=nil, fallback=CFrame.new(-21425.1, 7, -100922.3) },
    { key="jungle",    name="Poison Jungle",     area="Poison Jungle",     saved=nil, fallback=CFrame.new(-19331.6, 7, 18763.0) },
    { key="lava",      name="Infernite Volcano", area="Infernite Volcano", saved=nil, fallback=CFrame.new(-17252.8, 10, -20406.8) },
    { key="atlantis",  name="Lost Atlantis",     area="Lost Atlantis",     saved=nil, fallback=CFrame.new(-13946.1, 8, -20431.6) },
    { key="dream",     name="Dream Island",      area="Dream Island",      saved=nil, fallback=CFrame.new(-21817.9, 9, -20524.0) },
    { key="classic",   name="Classic Island",    area="Classic Island",    saved=nil, fallback=CFrame.new(-41525.7, 9, -20508.7) },
}

local function tpToWorld(world)
    local cf = world.saved
    if not cf then
        -- Versuche Server-Spawn
        pcall(function()
            local spawn = Workspace.Worlds["Seven Seas"].Areas
                :FindFirstChild(world.area)
                :FindFirstChild("IslandTeleport")
                :FindFirstChild("Spawn")
            fire("Teleport", spawn:GetFullName())
            return
        end)
        cf = world.fallback
    end
    tpTo(cf)
end

-- STATE
local fishing    = false
local miniLoop   = false
local activeWorld = WORLDS[1]

-- ============================================================
-- UI AUFBAU
-- ============================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "SailorMiniHub"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = LocalPlayer.PlayerGui

-- Farben & Stil
local C = {
    bg      = Color3.fromRGB(18, 18, 24),
    header  = Color3.fromRGB(28, 28, 38),
    accent  = Color3.fromRGB(80, 140, 255),
    green   = Color3.fromRGB(60, 200, 100),
    red     = Color3.fromRGB(220, 70, 70),
    yellow  = Color3.fromRGB(240, 200, 60),
    text    = Color3.fromRGB(220, 220, 230),
    sub     = Color3.fromRGB(140, 140, 160),
    btn     = Color3.fromRGB(40, 40, 55),
    btnH    = Color3.fromRGB(55, 55, 75),
    saved   = Color3.fromRGB(60, 180, 80),
}

local function makeCorner(r, p)
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 6); c.Parent = p; return c
end
local function makePad(t,b,l,r,p)
    local pad = Instance.new("UIPadding")
    pad.PaddingTop=UDim.new(0,t); pad.PaddingBottom=UDim.new(0,b)
    pad.PaddingLeft=UDim.new(0,l); pad.PaddingRight=UDim.new(0,r)
    pad.Parent=p; return pad
end
local function makeList(pad, p)
    local ul = Instance.new("UIListLayout")
    ul.Padding = UDim.new(0, pad or 4)
    ul.SortOrder = Enum.SortOrder.LayoutOrder
    ul.Parent = p; return ul
end
local function label(text, size, color, parent)
    local l = Instance.new("TextLabel")
    l.Text = text; l.TextSize = size or 13
    l.TextColor3 = color or C.text
    l.BackgroundTransparency = 1
    l.Font = Enum.Font.GothamMedium
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Size = UDim2.new(1,0,0,size and size+4 or 17)
    l.Parent = parent; return l
end

local function btn(text, bgColor, parent, callback)
    local b = Instance.new("TextButton")
    b.Text = text; b.TextSize = 12
    b.TextColor3 = C.text
    b.BackgroundColor3 = bgColor or C.btn
    b.Font = Enum.Font.GothamMedium
    b.AutoButtonColor = false
    b.Size = UDim2.new(1,0,0,26)
    makeCorner(5, b)
    b.Parent = parent
    b.MouseEnter:Connect(function() b.BackgroundColor3 = C.btnH end)
    b.MouseLeave:Connect(function() b.BackgroundColor3 = bgColor or C.btn end)
    if callback then b.MouseButton1Click:Connect(callback) end
    return b
end

-- Haupt-Frame (draggbar)
local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0, 260, 0, 30)
Main.Position = UDim2.new(0, 20, 0.5, -200)
Main.BackgroundColor3 = C.bg
Main.BorderSizePixel = 0
makeCorner(8, Main)
Main.Parent = ScreenGui

-- Drag
local dragging, dragStart, startPos
Main.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true; dragStart = i.Position; startPos = Main.Position
    end
end)
UserInputService.InputChanged:Connect(function(i)
    if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
        local d = i.Position - dragStart
        Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset+d.X, startPos.Y.Scale, startPos.Y.Offset+d.Y)
    end
end)
UserInputService.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
end)

-- Header (Titelleiste + Toggle)
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1,0,0,30)
Header.BackgroundColor3 = C.header
Header.BorderSizePixel = 0
makeCorner(8, Header)
Header.Parent = Main

local Title = Instance.new("TextLabel")
Title.Text = "BGS: Sailor + Minigames"
Title.Font = Enum.Font.GothamBold
Title.TextSize = 13
Title.TextColor3 = C.accent
Title.BackgroundTransparency = 1
Title.Size = UDim2.new(1,-40,1,0)
Title.Position = UDim2.new(0,10,0,0)
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Text = "▼"
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.TextSize = 12
ToggleBtn.TextColor3 = C.sub
ToggleBtn.BackgroundTransparency = 1
ToggleBtn.Size = UDim2.new(0,30,1,0)
ToggleBtn.Position = UDim2.new(1,-34,0,0)
ToggleBtn.Parent = Header

-- Scroll-Container fuer Inhalt
local Scroll = Instance.new("ScrollingFrame")
Scroll.Size = UDim2.new(1,0,1,-30)
Scroll.Position = UDim2.new(0,0,0,30)
Scroll.BackgroundTransparency = 1
Scroll.BorderSizePixel = 0
Scroll.ScrollBarThickness = 3
Scroll.ScrollBarImageColor3 = C.accent
Scroll.CanvasSize = UDim2.new(0,0,0,0)
Scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
Scroll.Parent = Main

local Content = Instance.new("Frame")
Content.Size = UDim2.new(1,0,0,0)
Content.AutomaticSize = Enum.AutomaticSize.Y
Content.BackgroundTransparency = 1
Content.Parent = Scroll
makePad(6,8,8,8,Content)
makeList(6, Content)

local expanded = false
local function setExpanded(v)
    expanded = v
    ToggleBtn.Text = v and "▲" or "▼"
    local targetH = v and 480 or 30
    TweenService:Create(Main, TweenInfo.new(0.2), {Size=UDim2.new(0,260,0,targetH)}):Play()
    Scroll.Visible = v
end
ToggleBtn.MouseButton1Click:Connect(function() setExpanded(not expanded) end)
Header.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then setExpanded(not expanded) end
end)
Scroll.Visible = false

-- ============================================================
-- ABSCHNITT: HELPER
-- ============================================================
local function section(text)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1,0,0,20)
    f.BackgroundColor3 = C.header
    f.BorderSizePixel = 0
    makeCorner(4, f)
    f.Parent = Content
    local l = Instance.new("TextLabel")
    l.Text = text; l.Font = Enum.Font.GothamBold
    l.TextSize = 11; l.TextColor3 = C.accent
    l.BackgroundTransparency = 1
    l.Size = UDim2.new(1,0,1,0)
    l.TextXAlignment = Enum.TextXAlignment.Center
    l.Parent = f
    return f
end

local function statusLabel(parent)
    local l = label("", 11, C.sub, parent)
    l.Size = UDim2.new(1,0,0,15)
    return l
end

-- ============================================================
-- ABSCHNITT: SAILOR QUEST
-- ============================================================
section("SAILOR QUEST")

local questStatusLbl = label("Quest: ...", 11, C.yellow, Content)
questStatusLbl.Size = UDim2.new(1,0,0,15)

-- Quest-Typ lesen und Text formatieren
local function formatQuestTask(q)
    if not q or not q.Tasks then return "Keine Quest aktiv" end
    local parts = {}
    for _, task in ipairs(q.Tasks) do
        local t = task.Task or task
        if t.Type == "Catch" then
            local area = t.Area or "?"
            local amount = t.Amount or 1
            parts[#parts+1] = "Fang "..amount.."x in "..area
        elseif t.Type == "CatchFish" then
            parts[#parts+1] = "Fang "..(t.Amount or 1).."x "..(t.Fish or "Fisch")
        elseif t.Type == "CatchRarity" then
            parts[#parts+1] = "Fang "..(t.Amount or 1).."x "..(t.Rarity or "?").."-Fisch"
        elseif t.Type == "CatchArea" then
            parts[#parts+1] = "Fang "..(t.Amount or 1).."x in "..(t.Area or "?")
        else
            parts[#parts+1] = t.Type..": "..(t.Amount or "?")
        end
    end
    if #parts == 0 then return "Quest aktiv (kein Task-Text)" end
    return table.concat(parts, " | ")
end

-- Quest-Bereich-Erkennung (welche Welt brauchst du?)
local AREA_WORLD_MAP = {
    ["Fisher's Island"]   = WORLDS[1],
    ["Blizzard Hills"]    = WORLDS[2],
    ["Poison Jungle"]     = WORLDS[3],
    ["Infernite Volcano"] = WORLDS[4],
    ["Lost Atlantis"]     = WORLDS[5],
    ["Dream Island"]      = WORLDS[6],
    ["Classic Island"]    = WORLDS[7],
    ["starter"]           = WORLDS[1],
    ["blizzard"]          = WORLDS[2],
    ["jungle"]            = WORLDS[3],
    ["lava"]              = WORLDS[4],
    ["atlantis"]          = WORLDS[5],
    ["dream"]             = WORLDS[6],
    ["classic"]           = WORLDS[7],
}

local detectedWorld = nil

local function refreshQuest()
    local q = getQuestTask()
    if not q then
        questStatusLbl.Text = "Keine Sailor-Bounty aktiv"
        questStatusLbl.TextColor3 = C.sub
        detectedWorld = nil
        return
    end
    local txt = formatQuestTask(q)
    questStatusLbl.Text = txt
    questStatusLbl.TextColor3 = C.yellow

    -- Versuche Welt aus Quest-Area zu bestimmen
    detectedWorld = nil
    if q.Tasks then
        for _, task in ipairs(q.Tasks) do
            local t = task.Task or task
            local area = t.Area or t.FishingArea or t.World
            if area then
                detectedWorld = AREA_WORLD_MAP[area]
                if detectedWorld then break end
            end
        end
    end
end

-- Refresh Button
btn("Quest aktualisieren", C.btn, Content, function()
    refreshQuest()
end)

-- Auto Fish Toggle
local autoFishBtn = btn("Auto Fish: AUS", C.btn, Content, nil)
autoFishBtn.MouseButton1Click:Connect(function()
    fishing = not fishing
    autoFishBtn.Text = fishing and "Auto Fish: AN" or "Auto Fish: AUS"
    autoFishBtn.BackgroundColor3 = fishing and C.green or C.btn
    if fishing then
        task.spawn(function()
            -- TP zur erkannten oder ausgewaehlten Welt
            local world = detectedWorld or activeWorld
            tpToWorld(world)
            task.wait(2)
            while fishing do
                fire("BeginCastCharge")
                task.wait(0.5)
                fire("FinishCastCharge")
                task.wait(3)
                fire("Reel")
                task.wait(1)
            end
        end)
    end
end)

btn("Sell All Fish", C.btn, Content, function()
    fire("SellAllFish")
end)
btn("Claim Fish Rewards", C.btn, Content, function()
    fire("ClaimAllFishingIndexRewards")
end)

-- ============================================================
-- ABSCHNITT: ANGEL-POSITIONEN (ausklappbar pro Insel)
-- ============================================================
section("ANGEL-POSITIONEN")
label("Geh ans Wasser -> Klick Inselname = Position speichern", 10, C.sub, Content).Size = UDim2.new(1,0,0,14)

for _, world in ipairs(WORLDS) do
    local w = world

    -- Container
    local worldFrame = Instance.new("Frame")
    worldFrame.Size = UDim2.new(1,0,0,26)
    worldFrame.BackgroundTransparency = 1
    worldFrame.Parent = Content

    local worldList = Instance.new("UIListLayout")
    worldList.Padding = UDim.new(0, 2)
    worldList.Parent = worldFrame

    -- Haupt-Button = Position speichern
    local saveBtn = Instance.new("TextButton")
    saveBtn.Size = UDim2.new(1,0,0,26)
    saveBtn.Font = Enum.Font.GothamMedium
    saveBtn.TextSize = 12
    saveBtn.TextColor3 = C.text
    saveBtn.BackgroundColor3 = C.btn
    saveBtn.AutoButtonColor = false
    makeCorner(5, saveBtn)
    saveBtn.Parent = worldFrame

    local function updateSaveBtn()
        if w.saved then
            local p = w.saved.Position
            saveBtn.Text = "[SAVED] "..w.name
            saveBtn.BackgroundColor3 = C.saved
        else
            saveBtn.Text = w.name
            saveBtn.BackgroundColor3 = C.btn
        end
    end
    updateSaveBtn()

    saveBtn.MouseEnter:Connect(function()
        saveBtn.BackgroundColor3 = w.saved and Color3.fromRGB(50,160,70) or C.btnH
    end)
    saveBtn.MouseLeave:Connect(function() updateSaveBtn() end)

    -- Klick = Position speichern + sofort TP test
    saveBtn.MouseButton1Click:Connect(function()
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if root then
            w.saved = root.CFrame
            updateSaveBtn()
            -- Kurze visuelle Bestaetigung
            local orig = saveBtn.BackgroundColor3
            saveBtn.BackgroundColor3 = C.green
            task.wait(0.3)
            updateSaveBtn()
        end
    end)

    -- Rechtsklick = Position loeschen
    saveBtn.MouseButton2Click:Connect(function()
        w.saved = nil
        updateSaveBtn()
    end)

    -- AutomaticSize anpassen
    worldFrame.AutomaticSize = Enum.AutomaticSize.Y
end

-- ============================================================
-- ABSCHNITT: MINIGAMES
-- ============================================================
section("MINIGAMES")
label("Super Ticket + Finish Insane fuer jedes Spiel", 10, C.sub, Content).Size = UDim2.new(1,0,0,14)

local MINIGAMES = {"Pet Match", "Cart Escape", "Robot Claw", "Hyper Darts"}

local miniLoopBtn = btn("Auto All Minigames: AUS", C.btn, Content, nil)
miniLoopBtn.MouseButton1Click:Connect(function()
    miniLoop = not miniLoop
    miniLoopBtn.Text = miniLoop and "Auto All Minigames: AN" or "Auto All Minigames: AUS"
    miniLoopBtn.BackgroundColor3 = miniLoop and C.green or C.btn
    if miniLoop then
        task.spawn(function()
            while miniLoop do
                for _, mgName in ipairs(MINIGAMES) do
                    if not miniLoop then break end
                    fire("UseItem", "Super Ticket")
                    task.wait(0.5)
                    fire("FinishMinigame")
                    task.wait(1)
                end
                task.wait(2)
            end
        end)
    end
end)

-- Einzelne Buttons pro Minigame
for _, mgName in ipairs(MINIGAMES) do
    local name = mgName
    btn(name, C.btn, Content, function()
        fire("UseItem", "Super Ticket")
        task.wait(0.5)
        fire("FinishMinigame")
    end)
end

-- Spam x10 alle
btn("x10 Spam (alle)", C.btn, Content, function()
    task.spawn(function()
        for i = 1, 10 do
            for _, mgName in ipairs(MINIGAMES) do
                fire("UseItem", "Super Ticket")
                task.wait(0.4)
                fire("FinishMinigame")
                task.wait(0.6)
            end
        end
    end)
end)

-- ============================================================
-- AUTO-REFRESH QUEST STATUS
-- ============================================================
task.spawn(function()
    while true do
        task.wait(5)
        if expanded then
            pcall(refreshQuest)
        end
    end
end)

-- Initiales Quest lesen
task.delay(1, function()
    pcall(refreshQuest)
    setExpanded(true)
end)

print("[Sailor+Mini] geladen! Klick Header zum Ein/Ausklappen. Rechtsklick = Position loeschen.")
