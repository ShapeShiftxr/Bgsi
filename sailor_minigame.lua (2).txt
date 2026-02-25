-- BGS: Sailor Quest + Minigames v2
-- Eigenes UI, kein Rayfield

if not game:IsLoaded() then game.Loaded:Wait() end

local Players           = game:GetService("Players")
local LocalPlayer       = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local Workspace         = game:GetService("Workspace")

-- Remote
local RE
pcall(function()
    RE = ReplicatedStorage.Shared.Framework.Network.Remote.RemoteEvent
end)
local function fire(action, ...)
    if RE then pcall(function() RE:FireServer(action, ...) end) end
end

-- LocalData
local LocalData
pcall(function()
    LocalData = require(ReplicatedStorage.Client.Framework.Services.LocalData)
end)
local function getLD()
    if not LocalData then return nil end
    local ok, d = pcall(function() return LocalData:Get() end)
    return ok and d or nil
end

-- Quest lesen
local function getActiveQuest()
    local d = getLD()
    if not d then return nil end
    local ok, QuestUtil = pcall(function()
        return require(ReplicatedStorage.Shared.Utils.Stats.QuestUtil)
    end)
    if not ok or not QuestUtil then return nil end
    local ok2, q = pcall(function() return QuestUtil:FindById(d, "sailor-bounty") end)
    return ok2 and q or nil
end

local function questToText(q)
    if not q then return "Keine Sailor-Bounty aktiv" end
    if not q.Tasks then return "Quest aktiv (Tasks unlesbar)" end
    local parts = {}
    for _, entry in ipairs(q.Tasks) do
        local t = entry.Task or entry
        if type(t) == "table" then
            local typ = tostring(t.Type or "?")
            local amt = tostring(t.Amount or "?")
            local extra = t.Area or t.FishingArea or t.Rarity or t.Fish or ""
            if extra ~= "" then
                parts[#parts+1] = typ..": "..amt.."x "..tostring(extra)
            else
                parts[#parts+1] = typ..": "..amt
            end
        end
    end
    return #parts > 0 and table.concat(parts, "  |  ") or "Quest aktiv"
end

-- TP
local function tpTo(cf)
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if root and cf then root.CFrame = cf end
end

-- Worlds
local WORLDS = {
    { name="Fisher's Island",   area="Fisher's Island",   saved=nil, fallback=CFrame.new(-23663, 8, 7) },
    { name="Blizzard Hills",    area="Blizzard Hills",    saved=nil, fallback=CFrame.new(-21425, 7, -100922) },
    { name="Poison Jungle",     area="Poison Jungle",     saved=nil, fallback=CFrame.new(-19332, 7, 18763) },
    { name="Infernite Volcano", area="Infernite Volcano", saved=nil, fallback=CFrame.new(-17253, 10, -20407) },
    { name="Lost Atlantis",     area="Lost Atlantis",     saved=nil, fallback=CFrame.new(-13946, 8, -20432) },
    { name="Dream Island",      area="Dream Island",      saved=nil, fallback=CFrame.new(-21818, 9, -20524) },
    { name="Classic Island",    area="Classic Island",    saved=nil, fallback=CFrame.new(-41526, 9, -20509) },
}

local function tpToWorld(world)
    if world.saved then tpTo(world.saved); return end
    local ok = pcall(function()
        local spawn = Workspace.Worlds["Seven Seas"].Areas
            :FindFirstChild(world.area)
            :FindFirstChild("IslandTeleport")
            :FindFirstChild("Spawn")
        fire("Teleport", spawn:GetFullName())
    end)
    if not ok then tpTo(world.fallback) end
end

-- STATE
local fishing   = false
local activeWorld = WORLDS[1]
local DIFFICULTIES = {"Easy", "Normal", "Hard", "Insane"}
local miniDiff = { ["Pet Match"]="Insane", ["Cart Escape"]="Insane", ["Robot Claw"]="Insane", ["Hyper Darts"]="Insane" }
local miniLoop = { ["Pet Match"]=false, ["Cart Escape"]=false, ["Robot Claw"]=false, ["Hyper Darts"]=false }

-- ============================================================
-- UI FARBEN
-- ============================================================
local C = {
    bg     = Color3.fromRGB(15, 15, 20),
    header = Color3.fromRGB(25, 25, 35),
    sec    = Color3.fromRGB(30, 30, 45),
    accent = Color3.fromRGB(80, 140, 255),
    green  = Color3.fromRGB(50, 190, 90),
    red    = Color3.fromRGB(210, 60, 60),
    yellow = Color3.fromRGB(230, 190, 50),
    text   = Color3.fromRGB(220, 220, 230),
    sub    = Color3.fromRGB(130, 130, 150),
    btn    = Color3.fromRGB(38, 38, 52),
    btnH   = Color3.fromRGB(52, 52, 70),
    saved  = Color3.fromRGB(40, 150, 65),
}

local function corner(r, p)
    local c = Instance.new("UICorner"); c.CornerRadius=UDim.new(0,r or 6); c.Parent=p
end
local function pad(t,b,l,r,p)
    local u=Instance.new("UIPadding")
    u.PaddingTop=UDim.new(0,t); u.PaddingBottom=UDim.new(0,b)
    u.PaddingLeft=UDim.new(0,l); u.PaddingRight=UDim.new(0,r)
    u.Parent=p
end
local function list(gap, p)
    local u=Instance.new("UIListLayout"); u.Padding=UDim.new(0,gap or 4)
    u.SortOrder=Enum.SortOrder.LayoutOrder; u.Parent=p
end
local function lbl(txt, sz, col, parent)
    local l=Instance.new("TextLabel")
    l.Text=tostring(txt or ""); l.TextSize=sz or 12
    l.TextColor3=col or C.text; l.BackgroundTransparency=1
    l.Font=Enum.Font.GothamMedium; l.TextXAlignment=Enum.TextXAlignment.Left
    l.Size=UDim2.new(1,0,0,(sz or 12)+5); l.TextWrapped=true
    l.Parent=parent; return l
end
local function mkBtn(txt, bg, parent, cb)
    local b=Instance.new("TextButton")
    b.Text=tostring(txt or ""); b.TextSize=12; b.TextColor3=C.text
    b.BackgroundColor3=bg or C.btn; b.Font=Enum.Font.GothamMedium
    b.AutoButtonColor=false; b.Size=UDim2.new(1,0,0,26)
    corner(5,b); b.Parent=parent
    b.MouseEnter:Connect(function() b.BackgroundColor3=C.btnH end)
    b.MouseLeave:Connect(function() b.BackgroundColor3=bg or C.btn end)
    if cb then b.MouseButton1Click:Connect(cb) end
    return b
end

-- ============================================================
-- HAUPT-GUI
-- ============================================================
local gui = Instance.new("ScreenGui")
gui.Name="BGSAddon"; gui.ResetOnSpawn=false
gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
gui.Parent=LocalPlayer.PlayerGui

-- Drag-Frame
local Main=Instance.new("Frame")
Main.Size=UDim2.new(0,260,0,30); Main.Position=UDim2.new(0,20,0,80)
Main.BackgroundColor3=C.bg; Main.BorderSizePixel=0
corner(8,Main); Main.Parent=gui

-- Kein Drag (Mobile)

-- Header
local Hdr=Instance.new("Frame")
Hdr.Size=UDim2.new(1,0,0,30); Hdr.BackgroundColor3=C.header
Hdr.BorderSizePixel=0; corner(8,Hdr); Hdr.Parent=Main

local HdrTitle=Instance.new("TextLabel")
HdrTitle.Text="Sailor + Minigames"; HdrTitle.Font=Enum.Font.GothamBold
HdrTitle.TextSize=13; HdrTitle.TextColor3=C.accent
HdrTitle.BackgroundTransparency=1; HdrTitle.Size=UDim2.new(1,-34,1,0)
HdrTitle.Position=UDim2.new(0,10,0,0); HdrTitle.TextXAlignment=Enum.TextXAlignment.Left
HdrTitle.Parent=Hdr

local TglBtn=Instance.new("TextButton")
TglBtn.Text="▼"; TglBtn.Font=Enum.Font.GothamBold; TglBtn.TextSize=12
TglBtn.TextColor3=C.sub; TglBtn.BackgroundTransparency=1
TglBtn.Size=UDim2.new(0,30,1,0); TglBtn.Position=UDim2.new(1,-34,0,0)
TglBtn.Parent=Hdr

-- Scroll
local Scroll=Instance.new("ScrollingFrame")
Scroll.Size=UDim2.new(1,0,1,-30); Scroll.Position=UDim2.new(0,0,0,30)
Scroll.BackgroundTransparency=1; Scroll.BorderSizePixel=0
Scroll.ScrollBarThickness=3; Scroll.ScrollBarImageColor3=C.accent
Scroll.CanvasSize=UDim2.new(0,0,0,0); Scroll.AutomaticCanvasSize=Enum.AutomaticSize.Y
Scroll.Visible=false; Scroll.Parent=Main

local Body=Instance.new("Frame")
Body.Size=UDim2.new(1,0,0,0); Body.AutomaticSize=Enum.AutomaticSize.Y
Body.BackgroundTransparency=1; Body.Parent=Scroll
pad(6,10,8,8,Body); list(5,Body)

-- Toggle expand
local expanded=false
local function setOpen(v)
    expanded=v; TglBtn.Text=v and "▲" or "▼"
    TweenService:Create(Main,TweenInfo.new(0.18),{Size=UDim2.new(0,260,0,v and 500 or 30)}):Play()
    Scroll.Visible=v
end
TglBtn.MouseButton1Click:Connect(function() setOpen(not expanded) end)
Hdr.InputBegan:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 then setOpen(not expanded) end
end)

-- Section header
local function sec(txt)
    local f=Instance.new("Frame"); f.Size=UDim2.new(1,0,0,20)
    f.BackgroundColor3=C.sec; f.BorderSizePixel=0; corner(4,f); f.Parent=Body
    local l=Instance.new("TextLabel"); l.Text=tostring(txt); l.Font=Enum.Font.GothamBold
    l.TextSize=11; l.TextColor3=C.accent; l.BackgroundTransparency=1
    l.Size=UDim2.new(1,0,1,0); l.TextXAlignment=Enum.TextXAlignment.Center; l.Parent=f
end

-- ============================================================
-- SAILOR QUEST SECTION
-- ============================================================
sec("SAILOR QUEST")

local questLbl=lbl("Quest: lade...", 11, C.yellow, Body)
questLbl.Size=UDim2.new(1,0,0,28)
questLbl.TextWrapped=true

local function refreshQuest()
    local q=getActiveQuest()
    local txt=questToText(q)
    questLbl.Text="Quest: "..txt
    questLbl.TextColor3=q and C.yellow or C.sub
end

mkBtn("Quest aktualisieren", C.btn, Body, function() pcall(refreshQuest) end)

local fishBtn=mkBtn("Auto Fish: AUS", C.btn, Body)
fishBtn.MouseButton1Click:Connect(function()
    fishing=not fishing
    fishBtn.Text=fishing and "Auto Fish: AN" or "Auto Fish: AUS"
    fishBtn.BackgroundColor3=fishing and C.green or C.btn
    if fishing then
        task.spawn(function()
            tpToWorld(activeWorld)
            task.wait(2)
            while fishing do
                fire("BeginCastCharge"); task.wait(0.5)
                fire("FinishCastCharge"); task.wait(3)
                fire("Reel"); task.wait(1)
            end
        end)
    end
end)

mkBtn("Sell All Fish", C.btn, Body, function() fire("SellAllFish") end)
mkBtn("Claim Fish Rewards", C.btn, Body, function() fire("ClaimAllFishingIndexRewards") end)

-- ============================================================
-- ANGEL-POSITIONEN
-- ============================================================
sec("ANGEL-POSITIONEN")
lbl("Linksklick = Position speichern  |  Rechtsklick = reset", 10, C.sub, Body).Size=UDim2.new(1,0,0,14)

for _, world in ipairs(WORLDS) do
    local w=world
    local b=Instance.new("TextButton")
    b.TextSize=12; b.TextColor3=C.text; b.Font=Enum.Font.GothamMedium
    b.AutoButtonColor=false; b.Size=UDim2.new(1,0,0,26); b.BorderSizePixel=0
    corner(5,b); b.Parent=Body

    local function refresh()
        if w.saved then
            local p=w.saved.Position
            b.Text="[SAVED] "..w.name
            b.BackgroundColor3=C.saved
        else
            b.Text=w.name
            b.BackgroundColor3=C.btn
        end
    end
    refresh()

    b.MouseEnter:Connect(function() b.BackgroundColor3=w.saved and Color3.fromRGB(50,160,70) or C.btnH end)
    b.MouseLeave:Connect(function() refresh() end)

    -- Linksklick = speichern
    b.MouseButton1Click:Connect(function()
        local char=LocalPlayer.Character
        local root=char and char:FindFirstChild("HumanoidRootPart")
        if root then
            w.saved=root.CFrame
            activeWorld=w
            refresh()
            b.BackgroundColor3=C.green
            task.delay(0.3, function() refresh() end)
        end
    end)
    -- Rechtsklick = loeschen
    b.MouseButton2Click:Connect(function()
        w.saved=nil; refresh()
    end)
end

-- ============================================================
-- MINIGAMES - EINZELN MIT DIFFICULTY
-- ============================================================
sec("MINIGAMES")
lbl("Difficulty per Spiel einstellbar", 10, C.sub, Body).Size=UDim2.new(1,0,0,14)

local MINIGAMES = {"Pet Match", "Cart Escape", "Robot Claw", "Hyper Darts"}

for _, mgName in ipairs(MINIGAMES) do
    local name=mgName

    -- Container pro Minigame
    local mgFrame=Instance.new("Frame")
    mgFrame.Size=UDim2.new(1,0,0,0); mgFrame.AutomaticSize=Enum.AutomaticSize.Y
    mgFrame.BackgroundColor3=Color3.fromRGB(22,22,32); mgFrame.BorderSizePixel=0
    corner(6,mgFrame); mgFrame.Parent=Body
    pad(5,5,6,6,mgFrame); list(4,mgFrame)

    -- Titel
    lbl(name, 12, C.accent, mgFrame).Size=UDim2.new(1,0,0,16)

    -- Difficulty Buttons (4 kleine nebeneinander)
    local diffRow=Instance.new("Frame")
    diffRow.Size=UDim2.new(1,0,0,24); diffRow.BackgroundTransparency=1; diffRow.Parent=mgFrame
    local diffList=Instance.new("UIListLayout")
    diffList.FillDirection=Enum.FillDirection.Horizontal
    diffList.Padding=UDim.new(0,3); diffList.Parent=diffRow

    for _, diff in ipairs(DIFFICULTIES) do
        local d=diff
        local db=Instance.new("TextButton")
        db.Size=UDim2.new(0.24,-2,1,0); db.TextSize=10; db.Font=Enum.Font.GothamMedium
        db.TextColor3=C.text; db.AutoButtonColor=false; db.BorderSizePixel=0
        db.Text=d
        db.BackgroundColor3=(miniDiff[name]==d) and C.accent or C.btn
        corner(4,db); db.Parent=diffRow

        db.MouseButton1Click:Connect(function()
            miniDiff[name]=d
            -- Alle Diff-Buttons dieser Reihe updaten
            for _, child in ipairs(diffRow:GetChildren()) do
                if child:IsA("TextButton") then
                    child.BackgroundColor3=(child.Text==d) and C.accent or C.btn
                end
            end
        end)
    end

    -- Einmalig + Loop nebeneinander
    local btnRow=Instance.new("Frame")
    btnRow.Size=UDim2.new(1,0,0,26); btnRow.BackgroundTransparency=1; btnRow.Parent=mgFrame
    local btnList=Instance.new("UIListLayout")
    btnList.FillDirection=Enum.FillDirection.Horizontal
    btnList.Padding=UDim.new(0,4); btnList.Parent=btnRow

    -- Einmalig
    local once=Instance.new("TextButton")
    once.Size=UDim2.new(0.48,0,1,0); once.TextSize=11; once.Font=Enum.Font.GothamMedium
    once.TextColor3=C.text; once.BackgroundColor3=C.btn; once.AutoButtonColor=false
    once.Text="Einmalig"; once.BorderSizePixel=0; corner(5,once); once.Parent=btnRow
    once.MouseButton1Click:Connect(function()
        fire("UseItem","Super Ticket")
        task.wait(0.4)
        fire("FinishMinigame")
    end)

    -- Loop
    local loopBtn=Instance.new("TextButton")
    loopBtn.Size=UDim2.new(0.48,0,1,0); loopBtn.TextSize=11; loopBtn.Font=Enum.Font.GothamMedium
    loopBtn.TextColor3=C.text; loopBtn.BackgroundColor3=C.btn; loopBtn.AutoButtonColor=false
    loopBtn.Text="Loop: AUS"; loopBtn.BorderSizePixel=0; corner(5,loopBtn); loopBtn.Parent=btnRow
    loopBtn.MouseButton1Click:Connect(function()
        miniLoop[name]=not miniLoop[name]
        local on=miniLoop[name]
        loopBtn.Text=on and "Loop: AN" or "Loop: AUS"
        loopBtn.BackgroundColor3=on and C.green or C.btn
        if on then
            task.spawn(function()
                while miniLoop[name] do
                    fire("UseItem","Super Ticket")
                    task.wait(0.4)
                    fire("FinishMinigame")
                    task.wait(1.5)
                end
            end)
        end
    end)
end

-- ============================================================
-- AUTO-REFRESH + INIT
-- ============================================================
task.spawn(function()
    while true do
        task.wait(6)
        if expanded then pcall(refreshQuest) end
    end
end)

task.delay(1.5, function()
    pcall(refreshQuest)
    setOpen(true)
end)

print("[BGS Addon] Geladen! Rechtsklick auf Insel-Button = Position loeschen")
