if not game:IsLoaded() then game.Loaded:Wait() end

local RS = game:GetService("ReplicatedStorage")
local LP = game:GetService("Players").LocalPlayer
local HS = game:GetService("HttpService")
local TS = game:GetService("TeleportService")

local WEBHOOK  = "https://discord.com/api/webhooks/1398025843674185778/LfECpwQEY6JWm9_adX5U9h3Ow0DreA-dyWxo_S1FdRbrHAMwbMU5zFvzuK7MioJKzMa4"
local INTERVAL = 300
local PLACE_ID = game.PlaceId

local isTeleporting  = false
local nextRejoinAt   = nil
local lastRejoinTime = nil
local rejoinReason   = "Noch nicht"
local sessionStart   = os.time()
local cachedId       = nil

local LD, StatsUtil, WorldUtil
pcall(function() LD        = require(RS.Client.Framework.Services.LocalData) end)
pcall(function() StatsUtil = require(RS.Shared.Utils.Stats.StatsUtil) end)
pcall(function() WorldUtil = require(RS.Shared.Utils.WorldUtil) end)

local function fmtTime(s)
    s = math.max(0, math.floor(s or 0))
    local h = math.floor(s / 3600)
    local m = math.floor((s % 3600) / 60)
    local sec = s % 60
    if h > 0 then return h .. "h " .. m .. "m" end
    if m > 0 then return m .. "m " .. sec .. "s" end
    return sec .. "s"
end

local function fmt(n)
    if type(n) ~= "number" then return "?" end
    if n >= 1e12 then return string.format("%.2fT", n / 1e12) end
    if n >= 1e9  then return string.format("%.2fB", n / 1e9) end
    if n >= 1e6  then return string.format("%.2fM", n / 1e6) end
    if n >= 1e3  then return string.format("%.1fK", n / 1e3) end
    return tostring(math.floor(n))
end

local function joinSmallServer()
    if isTeleporting then return end
    isTeleporting = true
    lastRejoinTime = os.time()
    task.wait(5)
    local ok, result = pcall(function()
        return HS:JSONDecode(game:HttpGet(
            "https://games.roblox.com/v1/games/" .. PLACE_ID .. "/servers/Public?sortOrder=Asc&limit=100"
        ))
    end)
    if ok and result and result.data then
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

task.spawn(function()
    while true do
        local mins = math.random(50, 80)
        local secs = mins * 60
        nextRejoinAt = os.time() + secs
        rejoinReason = "Geplant"
        task.wait(secs)
        joinSmallServer()
    end
end)

task.spawn(function()
    local overlay = game:GetService("CoreGui"):WaitForChild("RobloxPromptGui"):WaitForChild("promptOverlay")
    overlay.ChildAdded:Connect(function(child)
        if child.Name == "ErrorPrompt" then
            rejoinReason = "Disconnect"
            joinSmallServer()
        end
    end)
end)

local function countTable(t)
    if type(t) ~= "table" then return 0 end
    local total = 0
    for _, v in pairs(t) do
        if type(v) == "number" then total = total + v end
    end
    return total
end

local function getPow(d, name)
    if not d or type(d.Powerups) ~= "table" then return "0" end
    local v = d.Powerups[name]
    return type(v) == "number" and fmt(v) or "0"
end

local function getPotion(d, name)
    if not d or type(d.ActivePotions) ~= "table" then return nil end
    return d.ActivePotions[name]
end

local function potionTime(entry)
    if not entry then return "Inaktiv" end
    if type(entry) == "table" and entry.Expiry then
        if entry.Expiry.Type == "Timer" then
            local left = math.max(0, math.floor(entry.Expiry.Duration - os.time()))
            if left <= 0 then return "Abgelaufen" end
            local d = math.floor(left / 86400)
            local h = math.floor((left % 86400) / 3600)
            local m = math.floor((left % 3600) / 60)
            local s = left % 60
            if d > 0 then return d .. "d " .. h .. "h" end
            if h > 0 then return h .. "h " .. m .. "m" end
            return m .. "m " .. s .. "s"
        end
    end
    return "Aktiv"
end

local function getStats()
    local s = {
        name         = LP.Name,
        session      = fmtTime(os.time() - sessionStart),
        rejoin       = nextRejoinAt and fmtTime(nextRejoinAt - os.time()) or "?",
        lastRejoin   = lastRejoinTime and (fmtTime(os.time() - lastRejoinTime) .. " her") or "Noch nicht",
        rejoinReason = rejoinReason,
        eggsPerMin   = "?",
        luck         = "?",
        ultraLuck    = "?",
        secretLuck   = "?",
        hatchSpeed   = "?",
        seasonStars  = "?",
        totalEggs    = "?",
        totalBubbles = "?",
        coins        = "?",
        tickets      = "?",
        pearls       = "?",
        points       = "?",
        pInfinity    = "Inaktiv",
        pSecret      = "Inaktiv",
        pLuckyInf    = "Inaktiv",
        pMythicInf   = "Inaktiv",
        pSpeedInf    = "Inaktiv",
        superTicket  = "0",
        giantDice    = "0",
        dice         = "0",
        goldenDice   = "0",
        rerollOrb    = "0",
        dreamShard   = "0",
        shadowCrystal = "0",
    }

    pcall(function()
        local d = LD:Get()
        if not d then return end

        s.totalEggs    = fmt(countTable(d.EggsOpened))
        s.coins        = fmt(d.Coins   or 0)
        s.tickets      = fmt(d.Tickets or 0)
        s.pearls       = fmt(d.Pearls  or 0)
        s.points       = fmt(d.Points  or 0)

        if type(d.Stats) == "table" then
            s.totalBubbles = fmt(d.Stats.TotalBubbles or d.Stats.Bubbles or 0)
            s.seasonStars  = tostring(d.Stats.SeasonStars or d.Stats.ChallengeStars or "?")
        end

        s.pInfinity   = potionTime(getPotion(d, "Infinity Elixir"))
        s.pSecret     = potionTime(getPotion(d, "Secret Elixir"))
        s.pLuckyInf   = potionTime(getPotion(d, "Lucky"))
        s.pMythicInf  = potionTime(getPotion(d, "Mythic"))
        s.pSpeedInf   = potionTime(getPotion(d, "Speed"))

        s.superTicket  = getPow(d, "Super Ticket")
        s.giantDice    = getPow(d, "Giant Dice")
        s.dice         = getPow(d, "Dice")
        s.goldenDice   = getPow(d, "Golden Dice")
        s.rerollOrb    = getPow(d, "Reroll Orb")
        s.dreamShard   = getPow(d, "Dream Shard")
        s.shadowCrystal = getPow(d, "Shadow Crystal")

        if StatsUtil and WorldUtil then
            local world = WorldUtil:GetPlayerWorld(LP)
            pcall(function()
                local spd = StatsUtil:GetHatchSpeed(d, true)
                s.hatchSpeed  = math.round(spd * 100) .. "%"
                local eggsMin = math.round(60 / StatsUtil:GetHatchDuration(d, true))
                s.eggsPerMin  = tostring(eggsMin)
            end)
            pcall(function()
                local luck = StatsUtil:GetLuckMultiplier(LP, d, world, true)
                s.luck = "+" .. string.format("%.0f", (luck - 1) * 100) .. "%"
            end)
            pcall(function()
                local ul = StatsUtil:GetInfinityLuck(d, world)
                s.ultraLuck = string.format("%.2fx", ul)
            end)
            pcall(function()
                local sl = StatsUtil:GetSecretLuck(LP, d, world)
                s.secretLuck = string.format("%.1fx", sl)
            end)
        end
    end)

    return s
end

local function buildContent(s)
    local lines = {
        "**" .. s.name .. "**",
        "```",
        "STATS",
        "Eggs/min      " .. s.eggsPerMin,
        "Luck          " .. s.luck,
        "Ultra Inf     " .. s.ultraLuck,
        "Secret Luck   " .. s.secretLuck,
        "Hatch Speed   " .. s.hatchSpeed,
        "Season Stars  " .. s.seasonStars,
        "Total Eggs    " .. s.totalEggs,
        "Total Bubbles " .. s.totalBubbles,
        "Coins         " .. s.coins,
        "Tickets       " .. s.tickets,
        "Pearls        " .. s.pearls,
        "Points        " .. s.points,
        "",
        "POTIONS",
        "Infinity      " .. s.pInfinity,
        "Secret        " .. s.pSecret,
        "Lucky Inf     " .. s.pLuckyInf,
        "Mythic Inf    " .. s.pMythicInf,
        "Speed Inf     " .. s.pSpeedInf,
        "",
        "ITEMS",
        "Super Ticket  " .. s.superTicket,
        "Giant Dice    " .. s.giantDice,
        "Dice          " .. s.dice,
        "Golden Dice   " .. s.goldenDice,
        "Reroll Orb    " .. s.rerollOrb,
        "Dream Shard   " .. s.dreamShard,
        "Shadow Cryst  " .. s.shadowCrystal,
        "",
        "REJOIN",
        "Naechster     " .. s.rejoin .. " (" .. s.rejoinReason .. ")",
        "Letzter       " .. s.lastRejoin,
        "Session       " .. s.session,
        "```",
        "_" .. os.date("%d.%m.%Y %H:%M:%S") .. "_",
    }
    return table.concat(lines, "\n")
end

local function findMsgId(name)
    local ok, result = pcall(function()
        return HS:RequestAsync({
            Url     = WEBHOOK .. "?limit=50",
            Method  = "GET",
            Headers = {["Content-Type"] = "application/json"},
        })
    end)
    if not ok or not result or not result.Body then return nil end
    local data
    pcall(function() data = HS:JSONDecode(result.Body) end)
    if type(data) ~= "table" then return nil end
    for _, msg in ipairs(data) do
        if msg.content and msg.content:find("**" .. name .. "**", 1, true) then
            return msg.id
        end
    end
    return nil
end

local function update()
    local s       = getStats()
    local content = buildContent(s)

    if not cachedId then
        cachedId = findMsgId(LP.Name)
    end

    if cachedId then
        local ok = pcall(function()
            HS:RequestAsync({
                Url     = WEBHOOK .. "/messages/" .. cachedId,
                Method  = "PATCH",
                Headers = {["Content-Type"] = "application/json"},
                Body    = HS:JSONEncode({content = content}),
            })
        end)
        if ok then
            print("[Webhook] Updated: " .. LP.Name)
            return
        end
        cachedId = nil
    end

    local ok2, r2 = pcall(function()
        return HS:RequestAsync({
            Url     = WEBHOOK .. "?wait=true",
            Method  = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body    = HS:JSONEncode({content = content}),
        })
    end)
    if ok2 and r2 and r2.Body then
        local data
        pcall(function() data = HS:JSONDecode(r2.Body) end)
        if data and data.id then
            cachedId = data.id
            print("[Webhook] Neue Nachricht: " .. LP.Name)
        end
    end
end

update()
task.spawn(function()
    while true do
        task.wait(INTERVAL)
        update()
    end
end)

print("Webhook + Rejoiner aktiv: " .. LP.Name)
