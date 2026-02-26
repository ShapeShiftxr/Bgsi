if not game:IsLoaded() then game.Loaded:Wait() end

local RS  = game:GetService("ReplicatedStorage")
local LP  = game:GetService("Players").LocalPlayer
local HS  = game:GetService("HttpService")
local TS  = game:GetService("TeleportService")

local WEBHOOK  = "https://discord.com/api/webhooks/1398025843674185778/LfECpwQEY6JWm9_adX5U9h3Ow0DreA-dyWxo_S1FdRbrHAMwbMU5zFvzuK7MioJKzMa4"
local INTERVAL = 300
local PLACE_ID = game.PlaceId

-- Rejoin State
local isTeleporting  = false
local nextRejoinAt   = nil  -- tick() wann naechster Rejoin
local lastRejoinTime = nil  -- tick() wann letzter Rejoin war
local rejoinReason   = "—"

local function fmtTime(s)
    s = math.floor(s or 0)
    local h = math.floor(s/3600)
    local m = math.floor((s%3600)/60)
    local sec = s%60
    if h > 0 then return h.."h "..m.."m" end
    if m > 0 then return m.."m "..sec.."s" end
    return sec.."s"
end

local function fmt(n)
    if type(n) ~= "number" then return tostring(n or "?") end
    if n >= 1e12 then return string.format("%.1fT", n/1e12)
    elseif n >= 1e9 then return string.format("%.1fB", n/1e9)
    elseif n >= 1e6 then return string.format("%.1fM", n/1e6)
    elseif n >= 1e3 then return string.format("%.1fK", n/1e3)
    end
    return tostring(math.floor(n))
end

-- ── REJOINER ────────────────────────────────────────────────
local function joinSmallServer()
    if isTeleporting then return end
    isTeleporting = true
    lastRejoinTime = tick()
    print("Verbindung wird neu aufgebaut... Suche kleinen Server.")
    task.wait(5)
    local success, result = pcall(function()
        return HS:JSONDecode(game:HttpGet(
            "https://games.roblox.com/v1/games/"..PLACE_ID.."/servers/Public?sortOrder=Asc&limit=100"
        ))
    end)
    if success and result and result.data then
        for _, server in ipairs(result.data) do
            if server.playing < server.maxPlayers and server.id ~= game.JobId then
                TS:TeleportToPlaceInstance(PLACE_ID, server.id, LP)
                task.wait(10)
                isTeleporting = false
                return
            end
        end
    end
    TS:Teleport(PLACE_ID, LP)
    isTeleporting = false
end

-- Rejoin Loop
task.spawn(function()
    while true do
        local randomMinutes = math.random(50, 80)
        local waitSeconds   = randomMinutes * 60
        nextRejoinAt = tick() + waitSeconds
        rejoinReason = "Geplant"
        print("Naechster geplanter Rejoin in "..randomMinutes.." Minuten.")
        task.wait(waitSeconds)
        joinSmallServer()
    end
end)

-- Disconnect Erkennung
task.spawn(function()
    local promptOverlay = game:GetService("CoreGui")
        :WaitForChild("RobloxPromptGui")
        :WaitForChild("promptOverlay")
    promptOverlay.ChildAdded:Connect(function(child)
        if child.Name == "ErrorPrompt" then
            rejoinReason = "Disconnect!"
            warn("Disconnect erkannt! Sofortiger Rejoin...")
            joinSmallServer()
        end
    end)
end)

-- ── STATS ────────────────────────────────────────────────────
local LD
pcall(function() LD = require(RS.Client.Framework.Services.LocalData) end)

local sessionStart = tick()

local function getStats()
    local s = {name=LP.Name, session=fmtTime(tick()-sessionStart)}

    -- Rejoin Info
    if nextRejoinAt then
        local left = nextRejoinAt - tick()
        s.rejoin = left > 0 and ("in "..fmtTime(left)) or "Bald..."
    else
        s.rejoin = "—"
    end
    s.lastRejoin = lastRejoinTime and fmtTime(tick()-lastRejoinTime).." her" or "Noch nicht"
    s.rejoinReason = rejoinReason

    pcall(function()
        local d = LD:Get(); if not d then return end
        s.gems    = fmt(d.Gems    or 0)
        s.coins   = fmt(d.Coins   or 0)
        s.tickets = fmt(d.Tickets or 0)
        s.eggs    = fmt(d.EggsOpened    or 0)
        s.secrets = fmt(d.SecretsHatched or 0)
        s.fish    = fmt(d.TotalFishCaught or 0)
        s.genie   = fmt(d.GemGenieCompletions or 0)
        local bl = {}
        if d.Potions then
            for _, p in ipairs(d.Potions) do
                if type(p)=="table" then
                    local nm  = p.Name or "?"
                    local lvl = p.Level and " Lv"..p.Level or ""
                    local t   = p.Expiry and fmtTime(math.max(0,p.Expiry-tick())) or ""
                    bl[#bl+1] = nm..lvl..(t~="" and " ("..t..")" or "")
                end
            end
        end
        s.buffs = #bl>0 and table.concat(bl,", ") or "Keine"
    end)

    pcall(function()
        local sg = LP.PlayerGui:FindFirstChild("ScreenGui")
        if not sg then return end
        local function gt(n)
            local l=sg:FindFirstChild(n,true)
            return l and l:IsA("TextLabel") and l.Text or "?"
        end
        s.bubbles = gt("BubbleRate")
        s.lucky   = gt("Lucky")
        s.mythic  = gt("Mythic")
    end)

    return s
end

local function buildContent(s)
    return table.concat({
        "**"..s.name.."**",
        "💎 `"..(s.gems    or "?").."` "..
        "🪙 `"..(s.coins   or "?").."` "..
        "🎟️ `"..(s.tickets or "?").."`",
        "🥚 `"..(s.eggs    or "?").."` "..
        "⭐ `"..(s.secrets or "?").."` "..
        "🐟 `"..(s.fish    or "?").."`",
        "🧞 `"..(s.genie   or "?").."` "..
        "🫧 `"..(s.bubbles or "?").."` "..
        "⏱️ `"..s.session.."`",
        "🍀 `"..(s.lucky  or "?").."` "..
        "✨ `"..(s.mythic or "?").."`",
        "🔄 Rejoin: `"..s.rejoin.."` | Letzter: `"..s.lastRejoin.."` | Grund: `"..s.rejoinReason.."`",
        "🧪 "..(s.buffs or "Keine"),
        "🕐 _"..os.date("%H:%M:%S").."_",
    }, "\n")
end

-- Nachricht per Account-Name finden
local function findMsgId(name)
    local ok, result = pcall(function()
        return HS:RequestAsync({
            Url     = WEBHOOK.."/messages?limit=50",
            Method  = "GET",
            Headers = {["Content-Type"]="application/json"},
        })
    end)
    if not ok or not result or not result.Body then return nil end
    local data
    pcall(function() data = HS:JSONDecode(result.Body) end)
    if type(data) ~= "table" then return nil end
    for _, msg in ipairs(data) do
        if msg.content and msg.content:find("**"..name.."**", 1, true) then
            return msg.id
        end
    end
    return nil
end

local cachedId = nil

local function update()
    local s       = getStats()
    local content = buildContent(s)

    if not cachedId then
        cachedId = findMsgId(LP.Name)
    end

    if cachedId then
        local ok = pcall(function()
            HS:RequestAsync({
                Url     = WEBHOOK.."/messages/"..cachedId,
                Method  = "PATCH",
                Headers = {["Content-Type"]="application/json"},
                Body    = HS:JSONEncode({content=content}),
            })
        end)
        if ok then print("[Webhook] Updated: "..LP.Name); return end
        cachedId = nil
    end

    -- Neue Nachricht
    local ok2, r2 = pcall(function()
        return HS:RequestAsync({
            Url     = WEBHOOK.."?wait=true",
            Method  = "POST",
            Headers = {["Content-Type"]="application/json"},
            Body    = HS:JSONEncode({content=content}),
        })
    end)
    if ok2 and r2 and r2.Body then
        local data
        pcall(function() data = HS:JSONDecode(r2.Body) end)
        if data and data.id then
            cachedId = data.id
            print("[Webhook] Neue Nachricht: "..LP.Name)
        end
    end
end

-- Start
update()
task.spawn(function()
    while true do
        task.wait(INTERVAL)
        update()
    end
end)

print("Rejoiner + Webhook aktiv fuer "..LP.Name)
