if not game:IsLoaded() then game.Loaded:Wait() end

local LP  = game:GetService("Players").LocalPlayer
local RS  = game:GetService("ReplicatedStorage")
local TS  = game:GetService("TweenService")
local WS  = game:GetService("Workspace")

-- Remote
local RE
pcall(function()
    RE = RS.Shared.Framework.Network.Remote.RemoteEvent
end)
local function fire(a,...) if RE then pcall(function() RE:FireServer(a,...) end) end end

-- Worlds
local WORLDS = {
    {"Fisher's Island",  CFrame.new(-23663,8,7)},
    {"Blizzard Hills",   CFrame.new(-21425,7,-100922)},
    {"Poison Jungle",    CFrame.new(-19332,7,18763)},
    {"Infernite Volcano",CFrame.new(-17253,10,-20407)},
    {"Lost Atlantis",    CFrame.new(-13946,8,-20432)},
    {"Dream Island",     CFrame.new(-21818,9,-20524)},
    {"Classic Island",   CFrame.new(-41526,9,-20509)},
}
local savedPos = {} -- savedPos[worldName] = CFrame
local fishing = false
local miniLoops = {}

local function tpTo(cf)
    local c=LP.Character
    local r=c and c:FindFirstChild("HumanoidRootPart")
    if r and cf then r.CFrame=cf end
end

-- ── UI ──────────────────────────────────────────────────────
local gui=Instance.new("ScreenGui")
gui.Name="BGSAddon"; gui.ResetOnSpawn=false; gui.Parent=LP.PlayerGui

local C={
    bg=Color3.fromRGB(15,15,20), hdr=Color3.fromRGB(25,25,35),
    sec=Color3.fromRGB(30,30,45), acc=Color3.fromRGB(80,140,255),
    grn=Color3.fromRGB(50,190,90), txt=Color3.fromRGB(220,220,230),
    sub=Color3.fromRGB(130,130,150), btn=Color3.fromRGB(38,38,52),
    sav=Color3.fromRGB(40,150,65), yel=Color3.fromRGB(230,190,50),
}
local function crn(r,p) local c=Instance.new("UICorner");c.CornerRadius=UDim.new(0,r);c.Parent=p end
local function lst(g,p) local u=Instance.new("UIListLayout");u.Padding=UDim.new(0,g);u.SortOrder=Enum.SortOrder.LayoutOrder;u.Parent=p end
local function pdg(t,b,l,r,p) local u=Instance.new("UIPadding");u.PaddingTop=UDim.new(0,t);u.PaddingBottom=UDim.new(0,b);u.PaddingLeft=UDim.new(0,l);u.PaddingRight=UDim.new(0,r);u.Parent=p end

local Main=Instance.new("Frame")
Main.Size=UDim2.new(0,260,0,30); Main.Position=UDim2.new(0,10,0,60)
Main.BackgroundColor3=C.bg; Main.BorderSizePixel=0; crn(8,Main); Main.Parent=gui

local Hdr=Instance.new("Frame")
Hdr.Size=UDim2.new(1,0,0,30); Hdr.BackgroundColor3=C.hdr; Hdr.BorderSizePixel=0; crn(8,Hdr); Hdr.Parent=Main

local HT=Instance.new("TextLabel")
HT.Text="Sailor + Minigames"; HT.Font=Enum.Font.GothamBold; HT.TextSize=13
HT.TextColor3=C.acc; HT.BackgroundTransparency=1; HT.Size=UDim2.new(1,-34,1,0)
HT.Position=UDim2.new(0,10,0,0); HT.TextXAlignment=Enum.TextXAlignment.Left; HT.Parent=Hdr

local TB=Instance.new("TextButton")
TB.Text="▼"; TB.Font=Enum.Font.GothamBold; TB.TextSize=13; TB.TextColor3=C.sub
TB.BackgroundTransparency=1; TB.Size=UDim2.new(0,34,1,0); TB.Position=UDim2.new(1,-34,0,0); TB.Parent=Hdr

local Scr=Instance.new("ScrollingFrame")
Scr.Size=UDim2.new(1,0,1,-30); Scr.Position=UDim2.new(0,0,0,30)
Scr.BackgroundTransparency=1; Scr.BorderSizePixel=0
Scr.ScrollBarThickness=3; Scr.ScrollBarImageColor3=C.acc
Scr.AutomaticCanvasSize=Enum.AutomaticSize.Y; Scr.CanvasSize=UDim2.new(0,0,0,0)
Scr.Visible=false; Scr.Parent=Main

local Body=Instance.new("Frame")
Body.Size=UDim2.new(1,0,0,0); Body.AutomaticSize=Enum.AutomaticSize.Y
Body.BackgroundTransparency=1; Body.Parent=Scr
pdg(6,10,8,8,Body); lst(5,Body)

local open=false
local function setOpen(v)
    open=v; TB.Text=v and "▲" or "▼"; Scr.Visible=v
    TS:Create(Main,TweenInfo.new(0.15),{Size=UDim2.new(0,260,0,v and 480 or 30)}):Play()
end
TB.MouseButton1Click:Connect(function() setOpen(not open) end)

local function sec(t)
    local f=Instance.new("Frame");f.Size=UDim2.new(1,0,0,20);f.BackgroundColor3=C.sec;f.BorderSizePixel=0;crn(4,f);f.Parent=Body
    local l=Instance.new("TextLabel");l.Text=t;l.Font=Enum.Font.GothamBold;l.TextSize=11;l.TextColor3=C.acc
    l.BackgroundTransparency=1;l.Size=UDim2.new(1,0,1,0);l.TextXAlignment=Enum.TextXAlignment.Center;l.Parent=f
end
local function mkL(t,c,p)
    local l=Instance.new("TextLabel");l.Text=tostring(t);l.Font=Enum.Font.GothamMedium;l.TextSize=11
    l.TextColor3=c or C.txt;l.BackgroundTransparency=1;l.TextXAlignment=Enum.TextXAlignment.Left
    l.Size=UDim2.new(1,0,0,16);l.TextWrapped=true;l.Parent=p;return l
end
local function mkB(t,bg,p,cb)
    local b=Instance.new("TextButton");b.Text=tostring(t);b.TextSize=12;b.TextColor3=C.txt
    b.BackgroundColor3=bg;b.Font=Enum.Font.GothamMedium;b.AutoButtonColor=false
    b.Size=UDim2.new(1,0,0,26);b.BorderSizePixel=0;crn(5,b);b.Parent=p
    if cb then b.MouseButton1Click:Connect(cb) end;return b
end

-- ── SAILOR QUEST ────────────────────────────────────────────
sec("SAILOR QUEST")
local qLbl=mkL("Quest: lade...",C.yel,Body)
qLbl.Size=UDim2.new(1,0,0,30)

local function refreshQ()
    pcall(function()
        local LD=require(RS.Client.Framework.Services.LocalData)
        local d=LD:Get(); if not d then qLbl.Text="LocalData nil"; return end
        local QU=require(RS.Shared.Utils.Stats.QuestUtil)
        local q=QU:FindById(d,"sailor-bounty")
        if not q then qLbl.Text="Keine Sailor-Bounty aktiv"; qLbl.TextColor3=C.sub; return end
        local parts={}
        if q.Tasks then
            for _,e in ipairs(q.Tasks) do
                local t=e.Task or e
                if type(t)=="table" then
                    local s=tostring(t.Type or "?")..": "..tostring(t.Amount or "?")
                    local x=t.Area or t.Rarity or t.Fish or ""
                    if x~="" then s=s.." ("..x..")" end
                    parts[#parts+1]=s
                end
            end
        end
        qLbl.Text=#parts>0 and table.concat(parts," | ") or "Quest aktiv"
        qLbl.TextColor3=C.yel
    end)
end

mkB("Quest aktualisieren",C.btn,Body,function() refreshQ() end)

local fBtn=mkB("Auto Fish: AUS",C.btn,Body)
fBtn.MouseButton1Click:Connect(function()
    fishing=not fishing
    fBtn.Text=fishing and "Auto Fish: AN" or "Auto Fish: AUS"
    fBtn.BackgroundColor3=fishing and C.grn or C.btn
    if fishing then task.spawn(function()
        task.wait(2)
        while fishing do
            fire("BeginCastCharge"); task.wait(0.5)
            fire("FinishCastCharge"); task.wait(3)
            fire("Reel"); task.wait(1)
        end
    end) end
end)
mkB("Sell Fish",C.btn,Body,function() fire("SellAllFish") end)
mkB("Claim Fish Rewards",C.btn,Body,function() fire("ClaimAllFishingIndexRewards") end)

-- ── ANGEL-POSITIONEN ────────────────────────────────────────
sec("ANGEL-POSITIONEN")
mkL("Klick = aktuelle Pos speichern + TP",C.sub,Body)

for _,w in ipairs(WORLDS) do
    local wname=w[1]; local wfb=w[2]
    local b=Instance.new("TextButton")
    b.TextSize=11; b.TextColor3=C.txt; b.Font=Enum.Font.GothamMedium
    b.AutoButtonColor=false; b.Size=UDim2.new(1,0,0,26); b.BorderSizePixel=0
    b.Text=wname; b.BackgroundColor3=C.btn; crn(5,b); b.Parent=Body

    local function upd()
        if savedPos[wname] then
            b.Text="[POS] "..wname; b.BackgroundColor3=C.sav
        else
            b.Text=wname; b.BackgroundColor3=C.btn
        end
    end

    b.MouseButton1Click:Connect(function()
        -- Pos speichern
        local c=LP.Character; local r=c and c:FindFirstChild("HumanoidRootPart")
        if r then savedPos[wname]=r.CFrame end
        upd()
        -- TP zur Insel
        local cf=savedPos[wname]
        if cf then tpTo(cf) return end
        local ok=pcall(function()
            local sp=WS.Worlds["Seven Seas"].Areas:FindFirstChild(wname):FindFirstChild("IslandTeleport"):FindFirstChild("Spawn")
            fire("Teleport",sp:GetFullName())
        end)
        if not ok then tpTo(wfb) end
    end)
end

-- ── MINIGAMES ───────────────────────────────────────────────
sec("MINIGAMES")
local DIFFS={"Easy","Normal","Hard","Insane"}
local MG={"Pet Match","Cart Escape","Robot Claw","Hyper Darts"}
local mgDiff={}; for _,n in ipairs(MG) do mgDiff[n]="Insane" end

for _,mgName in ipairs(MG) do
    local name=mgName
    miniLoops[name]=false

    local box=Instance.new("Frame");box.Size=UDim2.new(1,0,0,0);box.AutomaticSize=Enum.AutomaticSize.Y
    box.BackgroundColor3=Color3.fromRGB(22,22,32);box.BorderSizePixel=0;crn(6,box);box.Parent=Body
    pdg(4,4,6,6,box);lst(3,box)

    mkL(name,C.acc,box)

    -- Diff row
    local dr=Instance.new("Frame");dr.Size=UDim2.new(1,0,0,24);dr.BackgroundTransparency=1;dr.Parent=box
    local dl=Instance.new("UIListLayout");dl.FillDirection=Enum.FillDirection.Horizontal;dl.Padding=UDim.new(0,2);dl.Parent=dr

    local dBtns={}
    for _,d in ipairs(DIFFS) do
        local db=Instance.new("TextButton")
        db.Size=UDim2.new(0.24,-2,1,0);db.TextSize=10;db.Font=Enum.Font.GothamMedium
        db.TextColor3=C.txt;db.AutoButtonColor=false;db.BorderSizePixel=0;db.Text=d
        db.BackgroundColor3=(mgDiff[name]==d) and C.acc or C.btn
        crn(4,db);db.Parent=dr;dBtns[d]=db
        db.MouseButton1Click:Connect(function()
            mgDiff[name]=d
            for _,b2 in pairs(dBtns) do b2.BackgroundColor3=C.btn end
            db.BackgroundColor3=C.acc
        end)
    end

    -- Once + Loop row
    local br=Instance.new("Frame");br.Size=UDim2.new(1,0,0,26);br.BackgroundTransparency=1;br.Parent=box
    local bl=Instance.new("UIListLayout");bl.FillDirection=Enum.FillDirection.Horizontal;bl.Padding=UDim.new(0,4);bl.Parent=br

    local once=Instance.new("TextButton")
    once.Size=UDim2.new(0.5,-2,1,0);once.TextSize=11;once.Font=Enum.Font.GothamMedium
    once.TextColor3=C.txt;once.BackgroundColor3=C.btn;once.AutoButtonColor=false
    once.Text="1x";once.BorderSizePixel=0;crn(5,once);once.Parent=br
    once.MouseButton1Click:Connect(function()
        fire("UseItem","Super Ticket"); task.wait(0.4); fire("FinishMinigame")
    end)

    local lBtn=Instance.new("TextButton")
    lBtn.Size=UDim2.new(0.5,-2,1,0);lBtn.TextSize=11;lBtn.Font=Enum.Font.GothamMedium
    lBtn.TextColor3=C.txt;lBtn.BackgroundColor3=C.btn;lBtn.AutoButtonColor=false
    lBtn.Text="Loop: AUS";lBtn.BorderSizePixel=0;crn(5,lBtn);lBtn.Parent=br
    lBtn.MouseButton1Click:Connect(function()
        miniLoops[name]=not miniLoops[name]; local on=miniLoops[name]
        lBtn.Text=on and "Loop: AN" or "Loop: AUS"; lBtn.BackgroundColor3=on and C.grn or C.btn
        if on then task.spawn(function()
            while miniLoops[name] do
                fire("UseItem","Super Ticket"); task.wait(0.4)
                fire("FinishMinigame"); task.wait(1.5)
            end
        end) end
    end)
end

-- Init
task.delay(2, function() pcall(refreshQ); setOpen(true) end)
print("[BGS] Geladen!")
