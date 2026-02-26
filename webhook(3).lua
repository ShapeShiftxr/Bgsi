if not game:IsLoaded() then game.Loaded:Wait() end
local RS=game:GetService("ReplicatedStorage")
local LP=game:GetService("Players").LocalPlayer
local HS=game:GetService("HttpService")
local TS=game:GetService("TeleportService")
local WEBHOOK="https://discord.com/api/webhooks/1398025843674185778/LfECpwQEY6JWm9_adX5U9h3Ow0DreA-dyWxo_S1FdRbrHAMwbMU5zFvzuK7MioJKzMa4"
local INTERVAL=300
local PID=game.PlaceId
local rejoining=false
local nextRejoin=nil
local lastRejoin=nil
local rejoinReason="Noch nicht"
local sessionStart=tick()
local cachedId=nil
local LD,SU,WU
pcall(function() LD=require(RS.Client.Framework.Services.LocalData) end)
pcall(function() SU=require(RS.Shared.Utils.Stats.StatsUtil) end)
pcall(function() WU=require(RS.Shared.Utils.WorldUtil) end)

local function ft(s)
    s=math.max(0,math.floor(s or 0))
    local d=math.floor(s/86400)
    local h=math.floor((s%86400)/3600)
    local m=math.floor((s%3600)/60)
    local sc=s%60
    if d>0 then return d.."d "..h.."h" end
    if h>0 then return h.."h "..m.."m" end
    if m>0 then return m.."m "..sc.."s" end
    return sc.."s"
end
local function fmt(n)
    if type(n)~="number" then return "?" end
    if n>=1e12 then return string.format("%.2fT",n/1e12) end
    if n>=1e9 then return string.format("%.2fB",n/1e9) end
    if n>=1e6 then return string.format("%.2fM",n/1e6) end
    if n>=1e3 then return string.format("%.1fK",n/1e3) end
    return tostring(math.floor(n))
end
local function rejoin()
    if rejoining then return end
    rejoining=true
    lastRejoin=tick()
    task.wait(3)
    local ok,r=pcall(function()
        return HS:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/"..PID.."/servers/Public?sortOrder=Asc&limit=100"))
    end)
    if ok and r and r.data then
        for _,s in ipairs(r.data) do
            if s.playing<s.maxPlayers and s.id~=game.JobId then
                TS:TeleportToPlaceInstance(PID,s.id,LP)
                task.wait(10)
                rejoining=false
                return
            end
        end
    end
    TS:Teleport(PID,LP)
    rejoining=false
end
task.spawn(function()
    while true do
        local mins=math.random(50,80)
        nextRejoin=tick()+mins*60
        rejoinReason="Geplant"
        task.wait(mins*60)
        rejoin()
    end
end)
task.spawn(function()
    local stuck=0
    while true do
        task.wait(1)
        local found=false
        pcall(function()
            for _,v in ipairs(game:GetService("CoreGui"):GetDescendants()) do
                if v:IsA("TextLabel") then
                    local t=v.Text or ""
                    if t:find("Connecting") or t:find("100%%") then found=true end
                end
            end
        end)
        if found then stuck=stuck+1 if stuck>=15 then stuck=0 rejoinReason="Stuck" rejoin() end
        else stuck=0 end
    end
end)
pcall(function()
    local p=game:GetService("CoreGui"):WaitForChild("RobloxPromptGui",10):WaitForChild("promptOverlay",10)
    p.ChildAdded:Connect(function(c)
        if c.Name=="ErrorPrompt" then rejoinReason="Disconnect" rejoin() end
    end)
end)

local function potTime(entry)
    if not entry then return "Inaktiv" end
    local active=type(entry)=="table" and (entry.Active or entry) or nil
    if not active then return "Inaktiv" end
    local exp=active.Expiry
    if not exp then return "Aktiv" end
    if exp.Type=="Timer" and exp.Duration then
        local left=math.max(0,math.floor(exp.Duration-os.time()))
        if left<=0 then return "Abgelaufen" end
        return ft(left)
    end
    return "Aktiv"
end
local function getPow(d,name)
    if not d or type(d.Powerups)~="table" then return "0" end
    local v=d.Powerups[name]
    return type(v)=="number" and fmt(v) or "0"
end
local function countTable(t)
    if type(t)~="table" then return 0 end
    local n=0
    for _,v in pairs(t) do if type(v)=="number" then n=n+v end end
    return n
end

local function getStats()
    local s={
        name=LP.Name,session=ft(tick()-sessionStart),
        rejoin=nextRejoin and ft(nextRejoin-tick()) or "?",
        lastRejoin=lastRejoin and (ft(tick()-lastRejoin).." her") or "Noch nicht",
        reason=rejoinReason,
        eggsMin="?",luck="?",ultraLuck="?",secretLuck="?",hatchSpeed="?",
        stars="?",totalEggs="?",totalBubbles="?",coins="?",tickets="?",pearls="?",points="?",
        pInf="Inaktiv",pSec="Inaktiv",pLucky="Inaktiv",pMythic="Inaktiv",pSpeed="Inaktiv",
        superTicket="0",giantDice="0",dice="0",goldenDice="0",
        rerollOrb="0",dreamShard="0",shadowCrystal="0",
    }
    pcall(function()
        local d=LD:Get()
        if not d then return end
        s.totalEggs=fmt(countTable(d.EggsOpened))
        s.coins=fmt(d.Coins or 0)
        s.tickets=fmt(d.Tickets or 0)
        s.pearls=fmt(d.Pearls or 0)
        if type(d.Stats)=="table" then
            s.totalBubbles=fmt(d.Stats.TotalBubbles or d.Stats.Bubbles or 0)
        end
        if type(d.ChallengePass)=="table" then
            s.points=fmt(d.ChallengePass.Points or 0)
        end
        if type(d.DailyRewards)=="table" then
            s.stars=tostring(d.DailyRewards.Stars or "?")
        end
        s.pInf   =potTime(d.ActivePotions and d.ActivePotions["Infinity Elixir"])
        s.pSec   =potTime(d.ActivePotions and d.ActivePotions["Secret Elixir"])
        s.pLucky =potTime(d.ActivePotions and d.ActivePotions["Lucky"])
        s.pMythic=potTime(d.ActivePotions and d.ActivePotions["Mythic"])
        s.pSpeed =potTime(d.ActivePotions and d.ActivePotions["Speed"])
        s.superTicket  =getPow(d,"Super Ticket")
        s.giantDice    =getPow(d,"Giant Dice")
        s.dice         =getPow(d,"Dice")
        s.goldenDice   =getPow(d,"Golden Dice")
        s.rerollOrb    =getPow(d,"Reroll Orb")
        s.dreamShard   =getPow(d,"Dream Shard")
        s.shadowCrystal=getPow(d,"Shadow Crystal")
        if SU and WU then
            local world=WU:GetPlayerWorld(LP)
            pcall(function()
                local spd=SU:GetHatchSpeed(d,true)
                s.hatchSpeed=math.round(spd*100).."%"
                local dur=SU:GetHatchDuration(d,true)
                local maxH=1
                pcall(function() maxH=SU:GetMaxEggHatches(d) end)
                s.eggsMin=tostring(math.round(60/dur*maxH))
            end)
            pcall(function()
                local luck=SU:GetLuckMultiplier(LP,d,world,true)
                s.luck="+"..string.format("%.0f",(luck-1)*100).."%"
            end)
            pcall(function()
                s.ultraLuck=string.format("%.2fx",SU:GetInfinityLuck(d,world))
            end)
            pcall(function()
                s.secretLuck=string.format("%.1fx",SU:GetSecretLuck(LP,d,world))
            end)
        end
    end)
    return s
end

local function pad(str,len)
    str=tostring(str)
    while #str<len do str=str.." " end
    return str
end

local function build(s)
    local L={
        "**"..s.name.."**",
        "```",
        "STATS",
        pad("Eggs/min",14)..s.eggsMin,
        pad("Luck",14)..s.luck,
        pad("Ultra Inf",14)..s.ultraLuck,
        pad("Secret Luck",14)..s.secretLuck,
        pad("Hatch Speed",14)..s.hatchSpeed,
        pad("Season Stars",14)..s.stars,
        pad("Total Eggs",14)..s.totalEggs,
        pad("Bubbles",14)..s.totalBubbles,
        pad("Coins",14)..s.coins,
        pad("Tickets",14)..s.tickets,
        pad("Pearls",14)..s.pearls,
        pad("CP Points",14)..s.points,
        "",
        "POTIONS",
        pad("Infinity",14)..s.pInf,
        pad("Secret",14)..s.pSec,
        pad("Lucky Inf",14)..s.pLucky,
        pad("Mythic Inf",14)..s.pMythic,
        pad("Speed Inf",14)..s.pSpeed,
        "",
        "ITEMS",
        pad("Super Ticket",14)..s.superTicket,
        pad("Giant Dice",14)..s.giantDice,
        pad("Dice",14)..s.dice,
        pad("Golden Dice",14)..s.goldenDice,
        pad("Reroll Orb",14)..s.rerollOrb,
        pad("Dream Shard",14)..s.dreamShard,
        pad("Shadow Cryst",14)..s.shadowCrystal,
        "",
        "REJOIN",
        pad("Naechster",14).."in "..s.rejoin.." ("..s.reason..")",
        pad("Letzter",14)..s.lastRejoin,
        pad("Session",14)..s.session,
        "```",
        "_"..os.date("%d.%m.%Y %H:%M:%S").."_",
    }
    return table.concat(L,"\n")
end

local function findId(name)
    local ok,r=pcall(function()
        return HS:RequestAsync({Url=WEBHOOK.."?limit=50",Method="GET",Headers={["Content-Type"]="application/json"}})
    end)
    if not ok or not r or not r.Body then return nil end
    local data
    pcall(function() data=HS:JSONDecode(r.Body) end)
    if type(data)~="table" then return nil end
    for _,msg in ipairs(data) do
        if msg.content and msg.content:find("**"..name.."**",1,true) then return msg.id end
    end
    return nil
end

local function update()
    local content=build(getStats())
    if not cachedId then cachedId=findId(LP.Name) end
    if cachedId then
        local ok=pcall(function()
            HS:RequestAsync({Url=WEBHOOK.."/messages/"..cachedId,Method="PATCH",
                Headers={["Content-Type"]="application/json"},Body=HS:JSONEncode({content=content})})
        end)
        if ok then print("[WH] Updated") return end
        cachedId=nil
    end
    local ok2,r2=pcall(function()
        return HS:RequestAsync({Url=WEBHOOK.."?wait=true",Method="POST",
            Headers={["Content-Type"]="application/json"},Body=HS:JSONEncode({content=content})})
    end)
    if ok2 and r2 and r2.Body then
        local data
        pcall(function() data=HS:JSONDecode(r2.Body) end)
        if data and data.id then cachedId=data.id print("[WH] Neu: "..LP.Name) end
    end
end

update()
task.spawn(function()
    while true do task.wait(INTERVAL) update() end
end)
print("Webhook+Rejoin aktiv: "..LP.Name)
