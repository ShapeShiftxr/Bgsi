-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  BGS INFINITY - AIO v0.8.0                                      ║
-- ║  Tabs: MG | Fish | Eggs | Board | Wheel | Shrine | Fuse         ║
-- ║        Genie | Consum | Spins | Rifts | Farming | SeasonPass    ║
-- ║        LockPets | Priority | Milestones | Automation            ║
-- ║        PlayProfiles | Competitive                               ║
-- ╚══════════════════════════════════════════════════════════════════╝
if not game:IsLoaded() then game.Loaded:Wait() end

local RS  = game:GetService("ReplicatedStorage")
local LP  = game:GetService("Players").LocalPlayer
local VIM = game:GetService("VirtualInputManager")
local TS  = game:GetService("TweenService")
local HS  = game:GetService("HttpService")

local RemoteFn  = RS.Shared.Framework.Network.Remote.RemoteFunction
local RemoteEv  = RS.Shared.Framework.Network.Remote.RemoteEvent
local Remote    = require(RS.Shared.Framework.Network.Remote)
local LD        = require(RS.Client.Framework.Services.LocalData)
local Time      = require(RS.Shared.Framework.Utilities.Math.Time)

-- Kleine yields zwischen schweren requires damit Roblox nicht einfriert
local QuestUtil;      pcall(function() QuestUtil      = require(RS.Shared.Utils.Stats.QuestUtil)        end); task.wait(0)
local FuseUtil;       pcall(function() FuseUtil       = require(RS.Shared.Utils.RebirthMachineUtil)     end); task.wait(0)
local GenieQuest;     pcall(function() GenieQuest     = require(RS.Shared.Data.Quests.GenieQuest)       end); task.wait(0)
local MG_Data;        pcall(function() MG_Data        = require(RS.Shared.Data.Minigames)               end); task.wait(0)
local Bait_Data;      pcall(function() Bait_Data      = require(RS.Shared.Data.FishingBait)             end); task.wait(0)
local FishAreas_Data; pcall(function() FishAreas_Data = require(RS.Shared.Data.FishingAreas)            end); task.wait(0)
local ShrineValues;   pcall(function() ShrineValues   = require(RS.Shared.Data.ShrineValues)            end); task.wait(0)
local EggsData;       pcall(function() EggsData       = require(RS.Shared.Data.Eggs)                    end); task.wait(0)
local Constants;      pcall(function() Constants      = require(RS.Shared.Constants)                    end); task.wait(0)
local SeasonPassData; pcall(function() SeasonPassData = require(RS.Shared.Data.Quests.SeasonPass)       end); task.wait(0)

local FishingUtil; pcall(function()
    FishingUtil = require(RS.Shared.Utils.FishingUtil)
    FishingUtil.MIN_CAST_DISTANCE   = 10
    FishingUtil.MAX_CAST_DISTANCE   = math.huge
    FishingUtil.CAST_TIMEOUT        = 0
    FishingUtil.MIN_FISH_BITE_DELAY = 0
    FishingUtil.MAX_FISH_BITE_DELAY = 0
    FishingUtil.BASE_REEL_SPEED     = math.huge
    FishingUtil.BASE_FINISH_WINDOW  = 0
    FishingUtil.WALL_CLICK_COOLDOWN = 0
end); task.wait(0)

local AutoFishModule; pcall(function()
    AutoFishModule = require(RS.Client.Gui.Frames.Fishing.FishingWorldAutoFish)
end)

-- ═══════════════════════════════════════════════════════════════════
--  CONFIG PERSISTENCE
-- ═══════════════════════════════════════════════════════════════════
local CFG_KEY = "BGS_AIO_v08_Config"

local function saveConfig(S, profileName)
    local key = profileName and (CFG_KEY.."_profile_"..profileName) or CFG_KEY
    pcall(function()
        local t = {
            mgDiff=S.mgDiff, mgTicket=S.mgTicket,
            clawMax=S.clawMax, clawPrio=S.clawPrio,
            fishArea=S.fishArea, baits=S.baits,
            hatchEgg=S.hatchEgg, hatchPrio=S.hatchPrio, hatchPrioOn=S.hatchPrioOn,
            hatchRareEgg=S.hatchRareEgg,
            dreamerAmt=S.dreamerAmt, sellArea=S.sellArea,
            genieMaxReroll=S.genieMaxReroll,
            genieSkipBubbles=S.genieSkipBubbles, genieMinScore=S.genieMinScore,
            genieRerollOn=S.genieRerollOn, genieRerollMax=S.genieRerollMax,
            genieQuestPrio=S.genieQuestPrio,
            riftSpawnTime=S.riftSpawnTime, riftPermanent=S.riftPermanent,
            fuseKeepShiny=S.fuseKeepShiny, fuseKeepMythic=S.fuseKeepMythic,
            fuseOnlyUnlocked=S.fuseOnlyUnlocked,
            lockSecretChance=S.lockSecretChance, lockSecretCount=S.lockSecretCount,
            modulePriority=S.modulePriority,
            autosaveOn=S.autosaveOn,
            farmTeamBubble=S.farmTeamBubble, farmTeamLuck=S.farmTeamLuck,
            farmTeamSecretLuck=S.farmTeamSecretLuck,
            -- Item enabled states
            potionEnabled={}, runeEnabled={}, eggEnabled={}, boxEnabled={},
            chestEnabled={}, riftEnabled={}, spinOn={}, wheelOn={},
            shrineItemEnabled={},
        }
        for _, it in ipairs(S.potionItems) do
            t.potionEnabled[it.Name.."_"..it.Level] = it.enabled
        end
        for _, it in ipairs(S.runeItems) do
            t.runeEnabled[it.Name.."_"..it.Level] = it.enabled
        end
        for _, it in ipairs(S.eggItems) do t.eggEnabled[it.Name] = it.enabled end
        for _, it in ipairs(S.boxItems) do t.boxEnabled[it.Name] = it.enabled end
        for _, it in ipairs(S.chestItems) do t.chestEnabled[it.ChestName] = it.enabled end
        for _, it in ipairs(S.riftItems) do t.riftEnabled[it.name] = it.enabled end
        for _, it in ipairs(S.spinTickets) do t.spinOn[it.label] = it.on end
        for _, it in ipairs(S.wheels) do t.wheelOn[it.label] = it.on end
        for _, it in ipairs(S.shrineItems) do
            t.shrineItemEnabled[it.Name.."_"..it.Level] = it.enabled
        end
        setinfo(key, HS:JSONEncode(t))
    end)
end

local function loadConfig(profileName)
    local key = profileName and (CFG_KEY.."_profile_"..profileName) or CFG_KEY
    local ok, raw = pcall(getinfo, key)
    if not ok or not raw or raw == "" then return nil end
    local ok2, t = pcall(HS.JSONDecode, HS, raw)
    return ok2 and t or nil
end

local function applyConfig(S, cfg)
    if not cfg then return end
    local function ap(k) if cfg[k] ~= nil then S[k] = cfg[k] end end
    ap("mgDiff"); ap("mgTicket"); ap("clawMax")
    ap("fishArea"); ap("baits")
    ap("hatchEgg"); ap("hatchPrio"); ap("hatchPrioOn"); ap("hatchRareEgg")
    ap("dreamerAmt"); ap("sellArea")
    ap("genieMaxReroll"); ap("genieSkipBubbles"); ap("genieMinScore")
    ap("genieRerollOn"); ap("genieRerollMax")
    ap("riftSpawnTime"); ap("riftPermanent")
    ap("fuseKeepShiny"); ap("fuseKeepMythic"); ap("fuseOnlyUnlocked")
    ap("lockSecretChance"); ap("lockSecretCount")
    ap("autosaveOn")
    ap("farmTeamBubble"); ap("farmTeamLuck"); ap("farmTeamSecretLuck")
    if cfg.clawPrio then for k,v in pairs(cfg.clawPrio) do S.clawPrio[k]=v end end
    if cfg.genieQuestPrio then for k,v in pairs(cfg.genieQuestPrio) do S.genieQuestPrio[k]=v end end
    if cfg.modulePriority then S.modulePriority = cfg.modulePriority end
    if cfg.potionEnabled then
        for _, it in ipairs(S.potionItems) do
            local k = it.Name.."_"..it.Level
            if cfg.potionEnabled[k] ~= nil then it.enabled = cfg.potionEnabled[k] end
        end
    end
    if cfg.runeEnabled then
        for _, it in ipairs(S.runeItems) do
            local k = it.Name.."_"..it.Level
            if cfg.runeEnabled[k] ~= nil then it.enabled = cfg.runeEnabled[k] end
        end
    end
    if cfg.eggEnabled then
        for _, it in ipairs(S.eggItems) do
            if cfg.eggEnabled[it.Name] ~= nil then it.enabled = cfg.eggEnabled[it.Name] end
        end
    end
    if cfg.boxEnabled then
        for _, it in ipairs(S.boxItems) do
            if cfg.boxEnabled[it.Name] ~= nil then it.enabled = cfg.boxEnabled[it.Name] end
        end
    end
    if cfg.chestEnabled then
        for _, it in ipairs(S.chestItems) do
            if cfg.chestEnabled[it.ChestName] ~= nil then it.enabled = cfg.chestEnabled[it.ChestName] end
        end
    end
    if cfg.riftEnabled then
        for _, it in ipairs(S.riftItems) do
            if cfg.riftEnabled[it.name] ~= nil then it.enabled = cfg.riftEnabled[it.name] end
        end
    end
    if cfg.spinOn then
        for _, it in ipairs(S.spinTickets) do
            if cfg.spinOn[it.label] ~= nil then it.on = cfg.spinOn[it.label] end
        end
    end
    if cfg.wheelOn then
        for _, it in ipairs(S.wheels) do
            if cfg.wheelOn[it.label] ~= nil then it.on = cfg.wheelOn[it.label] end
        end
    end
    if cfg.shrineItemEnabled then
        for _, it in ipairs(S.shrineItems) do
            local k = it.Name.."_"..it.Level
            if cfg.shrineItemEnabled[k] ~= nil then it.enabled = cfg.shrineItemEnabled[k] end
        end
    end
end

-- Play Profiles storage
local PROFILES_KEY = "BGS_AIO_v07_Profiles"
local function saveProfiles(profiles)
    pcall(setinfo, PROFILES_KEY, HS:JSONEncode(profiles))
end
local function loadProfiles()
    local ok, raw = pcall(getinfo, PROFILES_KEY)
    if not ok or not raw or raw == "" then return {} end
    local ok2, t = pcall(HS.JSONDecode, HS, raw)
    return ok2 and t or {}
end

-- ═══════════════════════════════════════════════════════════════════
--  TRANSITION SKIP
-- ═══════════════════════════════════════════════════════════════════
local function killGui(g)
    if g.Name == "TransitionGui" or g.Name == "WorldTransitionGui" then
        g.Enabled = false
        task.defer(function() pcall(g.Destroy, g) end)
    end
end
for _, g in ipairs(LP.PlayerGui:GetChildren()) do killGui(g) end
LP.PlayerGui.ChildAdded:Connect(killGui)

-- ═══════════════════════════════════════════════════════════════════
--  CORE HELPERS
-- ═══════════════════════════════════════════════════════════════════
local function getData()  return LD:Get() end
local function now()      return Time.now() end
local function isReady(k)
    local d = getData()
    return d and now() >= ((d.Cooldowns and d.Cooldowns[k]) or 0)
end
local function ownedPU(name)
    local d = getData()
    return d and (d.Powerups and d.Powerups[name] or 0) or 0
end
local function tp(pos)
    local char = LP.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if not hrp then return false end
    if hum then hum.PlatformStand = true end
    local a = math.rad(math.random(0, 360))
    hrp.CFrame = CFrame.new(
        pos + Vector3.new(math.cos(a)*0.5, 1.5, math.sin(a)*0.5),
        Vector3.new(pos.X, pos.Y, pos.Z)
    )
    task.wait(0.1)
    if hum then hum.PlatformStand = false end
    return true
end
local function pressE()
    VIM:SendKeyEvent(true,  Enum.KeyCode.E, false, game)
    task.wait(0.05)
    VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)
end

-- ═══════════════════════════════════════════════════════════════════
--  EGG DATA
-- ═══════════════════════════════════════════════════════════════════
local EGG_POS = {
    ["Common Egg"]      = Vector3.new(  -80.9,    8.2,    6.0),
    ["Spotted Egg"]     = Vector3.new(  -91.8,    8.2,   12.3),
    ["Iceshard Egg"]    = Vector3.new( -119.1,    8.2,   14.0),
    ["Spikey Egg"]      = Vector3.new(   -6.1,  421.4,  162.8),
    ["Magma Egg"]       = Vector3.new(  -22.8, 2663.6,    8.3),
    ["Crystal Egg"]     = Vector3.new(  -22.8, 2663.6,   18.8),
    ["Lunar Egg"]       = Vector3.new(  -57.0, 6861.0,   74.9),
    ["Void Egg"]        = Vector3.new(    9.4,10146.3,  190.5),
    ["Hell Egg"]        = Vector3.new(   -6.8,10146.3,  197.6),
    ["Nightmare Egg"]   = Vector3.new(  -21.3,10146.3,  187.8),
    ["Rainbow Egg"]     = Vector3.new(  -36.9,15970.9,   49.5),
    ["Infinity Egg"]    = Vector3.new( -105.4,   10.6,  -27.0),
    ["Inferno Egg"]     = Vector3.new(   61.6,  -38.3,  -36.4),
    ["Icy Egg"]         = Vector3.new(-21427.4,   5.6,-100871.0),
    ["Vine Egg"]        = Vector3.new(-19300.1,   5.7, 18904.8),
    ["Lava Egg"]        = Vector3.new(-17181.2,  13.5,-20322.7),
    ["Atlantis Egg"]    = Vector3.new(-13945.9,  11.5,-20249.3),
    ["Classic Egg"]     = Vector3.new(-41511.3,   7.6,-20486.1),
    ["Showman Egg"]     = Vector3.new( 9944.9,   25.3,  214.4),
    ["Mining Egg"]      = Vector3.new( 9924.2, 7680.7,  244.8),
    ["Cyber Egg"]       = Vector3.new( 9919.1,13408.7,  242.4),
    ["Neon Egg"]        = Vector3.new( 9883.4,20088.2,  266.2),
    ["Gingerbread Egg"] = Vector3.new( -340.8,  3.5,  -409.2),
    ["Candycane Egg"]   = Vector3.new( -320.0,  3.5,  -420.0),
    ["Yuletide Egg"]    = Vector3.new( -310.0,  3.5,  -430.0),
    ["Festive Egg"]     = Vector3.new( -300.0,  3.5,  -440.0),
    ["Northpole Egg"]   = Vector3.new( -290.0,  3.5,  -450.0),
    ["Aurora Egg"]      = Vector3.new( -280.0,  3.5,  -460.0),
    ["Spring Egg"]      = Vector3.new(  120.0,   8.2,  -200.0),
    ["Petal Egg"]       = Vector3.new(  130.0,   8.2,  -210.0),
    ["Sakura Egg"]      = Vector3.new(  140.0,   8.2,  -220.0),
    ["Blossom Egg"]     = Vector3.new(  150.0,   8.2,  -230.0),
    ["Pastel Egg"]      = Vector3.new(  -80.9,   8.2,   40.0),
    ["Bunny Egg"]       = Vector3.new(  -91.8,   8.2,   50.0),
    ["Pumpkin Egg"]     = Vector3.new(  -70.0,   8.2,   20.0),
    ["Costume Egg"]     = Vector3.new(  -65.0,   8.2,   25.0),
    ["Sinister Egg"]    = Vector3.new(  -60.0,   8.2,   30.0),
    ["Mutant Egg"]      = Vector3.new(  -55.0,   8.2,   35.0),
    ["Puppet Egg"]      = Vector3.new(  -50.0,   8.2,   40.0),
    ["Valentine's Egg"] = Vector3.new(  -85.0,   8.2,   45.0),
    ["Azure Egg"]       = Vector3.new(  -90.0,   8.2,   50.0),
    ["Hellish Egg"]     = Vector3.new(  -95.0,   8.2,   55.0),
    ["Heartbreak Egg"]  = Vector3.new( -100.0,   8.2,   60.0),
    ["Lunar New Years Egg"] = Vector3.new( -45.0, 6861.0, 80.0),
    ["Moon Egg"]        = Vector3.new( -50.0, 6861.0, 85.0),
    ["Beach Egg"]       = Vector3.new(-13980.0,  11.5,-20260.0),
    ["Icecream Egg"]    = Vector3.new(-13960.0,  11.5,-20270.0),
    ["Fruit Egg"]       = Vector3.new(-13940.0,  11.5,-20280.0),
    ["Fossil Egg"]      = Vector3.new(-13920.0,  11.5,-20290.0),
    ["Pirate Egg"]      = Vector3.new(-13900.0,  11.5,-20300.0),
    ["Clown Egg"]       = Vector3.new( 9890.0, 20088.0,  260.0),
    ["Cannon Egg"]      = Vector3.new( 9895.0, 20088.0,  265.0),
    ["Magic Egg"]       = Vector3.new( 9900.0, 20088.0,  270.0),
    ["Circus Jester Egg"] = Vector3.new( 9905.0, 20088.0, 275.0),
    ["Jamboree Egg"]    = Vector3.new( 9910.0, 20088.0,  280.0),
    ["Chance Egg"]      = Vector3.new( 9915.0, 20088.0,  285.0),
    ["Autumn Egg"]      = Vector3.new( -110.0,   8.2,   65.0),
    ["Candle Egg"]      = Vector3.new( -115.0,   8.2,   70.0),
    ["Winter Egg"]      = Vector3.new( -120.0,   8.2,   75.0),
    ["July4th Egg"]     = Vector3.new( -125.0,   8.2,   80.0),
    ["Candy Egg"]       = Vector3.new( -130.0,   8.2,   85.0),
    ["Corn Egg"]        = Vector3.new( -135.0,   8.2,   90.0),
    ["Throwback Egg"]   = Vector3.new( -140.0,   8.2,   95.0),
    ["Dreamer Egg"]     = Vector3.new(    9.4, 10146.0,  185.0),
    ["Royal Egg"]       = Vector3.new( -145.0,   8.2,  100.0),
    ["Shadow Egg"]      = Vector3.new( -150.0,   8.2,  105.0),
    ["New Years Egg"]   = Vector3.new( -155.0,   8.2,  110.0),
}

local EGG_WORLD = {
    ["Common Egg"]="The Overworld",["Spotted Egg"]="The Overworld",
    ["Iceshard Egg"]="The Overworld",["Spikey Egg"]="The Overworld",
    ["Magma Egg"]="The Overworld",["Crystal Egg"]="The Overworld",
    ["Lunar Egg"]="The Overworld",["Void Egg"]="The Overworld",
    ["Hell Egg"]="The Overworld",["Nightmare Egg"]="The Overworld",
    ["Rainbow Egg"]="The Overworld",["Infinity Egg"]="The Overworld",
    ["Inferno Egg"]="The Overworld",
    ["Pastel Egg"]="The Overworld",["Bunny Egg"]="The Overworld",
    ["Pumpkin Egg"]="The Overworld",["Costume Egg"]="The Overworld",
    ["Sinister Egg"]="The Overworld",["Mutant Egg"]="The Overworld",
    ["Puppet Egg"]="The Overworld",["Valentine's Egg"]="The Overworld",
    ["Azure Egg"]="The Overworld",["Hellish Egg"]="The Overworld",
    ["Heartbreak Egg"]="The Overworld",["Autumn Egg"]="The Overworld",
    ["Candle Egg"]="The Overworld",["Winter Egg"]="The Overworld",
    ["July4th Egg"]="The Overworld",["Candy Egg"]="The Overworld",
    ["Corn Egg"]="The Overworld",["Throwback Egg"]="The Overworld",
    ["Royal Egg"]="The Overworld",["Shadow Egg"]="The Overworld",
    ["New Years Egg"]="The Overworld",["Spring Egg"]="The Overworld",
    ["Petal Egg"]="The Overworld",["Sakura Egg"]="The Overworld",
    ["Blossom Egg"]="The Overworld",["Lunar New Years Egg"]="The Overworld",
    ["Moon Egg"]="The Overworld",["Dreamer Egg"]="The Overworld",
    ["Icy Egg"]="Seven Seas",["Vine Egg"]="Seven Seas",
    ["Lava Egg"]="Seven Seas",["Atlantis Egg"]="Seven Seas",
    ["Classic Egg"]="Seven Seas",["Beach Egg"]="Seven Seas",
    ["Icecream Egg"]="Seven Seas",["Fruit Egg"]="Seven Seas",
    ["Fossil Egg"]="Seven Seas",["Pirate Egg"]="Seven Seas",
    ["Showman Egg"]="Minigame Paradise",["Mining Egg"]="Minigame Paradise",
    ["Cyber Egg"]="Minigame Paradise",["Neon Egg"]="Minigame Paradise",
    ["Clown Egg"]="Minigame Paradise",["Cannon Egg"]="Minigame Paradise",
    ["Magic Egg"]="Minigame Paradise",["Circus Jester Egg"]="Minigame Paradise",
    ["Jamboree Egg"]="Minigame Paradise",["Chance Egg"]="Minigame Paradise",
    ["Gingerbread Egg"]="Christmas World",["Candycane Egg"]="Christmas World",
    ["Yuletide Egg"]="Christmas World",["Festive Egg"]="Christmas World",
    ["Northpole Egg"]="Christmas World",["Aurora Egg"]="Christmas World",
}

local WORLD_SPAWN = {
    ["The Overworld"]     = Vector3.new(  56.1,   8.2, -102.2),
    ["Seven Seas"]        = Vector3.new(-23648.5, 11.0, -123.1),
    ["Minigame Paradise"] = Vector3.new( 9913.1, 139.3,  332.2),
    ["Christmas World"]   = Vector3.new( -340.8,   3.5, -409.2),
}

local function findEggPos(name)
    name = name or "Infinity Egg"
    local function searchIn(parent)
        for _, child in ipairs(parent:GetChildren()) do
            if child:IsA("Model") and child.Name == name then
                local r = child:FindFirstChild("Root")
                if r and child:FindFirstChild("Prompt") then return r.Position end
            end
            local found = searchIn(child)
            if found then return found end
        end
    end
    local rendered = workspace:FindFirstChild("Rendered")
    if rendered then local p = searchIn(rendered); if p then return p end end
    local worlds = workspace:FindFirstChild("Worlds")
    if worlds then local p = searchIn(worlds); if p then return p end end
    return EGG_POS[name]
end

local function tpToEgg(name)
    local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    if not hrp then return false end
    local pos = findEggPos(name)
    if not pos then
        local world = EGG_WORLD[name]
        local spawnPos = world and WORLD_SPAWN[world]
        if spawnPos then
            if hum then hum.PlatformStand = true end
            hrp.CFrame = CFrame.new(spawnPos + Vector3.new(0, 5, 0))
            task.wait(0.2)
            if hum then hum.PlatformStand = false end
            local t = 0
            repeat task.wait(0.3); t += 0.3; pos = findEggPos(name) until pos or t > 5
        end
        if not pos then pos = EGG_POS[name] end
    end
    if not pos then return false end
    local a = math.rad(math.random(0, 360))
    local dist = math.random(40, 50) / 10
    local safeY = pos.Y + 3
    local tgt = Vector3.new(pos.X + math.cos(a)*dist, safeY, pos.Z + math.sin(a)*dist)
    if hum then hum.PlatformStand = true end
    hrp.CFrame = CFrame.new(tgt, Vector3.new(pos.X, safeY, pos.Z))
    task.wait(0.15)
    if hum then hum.PlatformStand = false end
    return true
end

local function hatchEgg(name, duration)
    duration = duration or 3
    if not tpToEgg(name) then return end
    local t = 0
    while t < duration do pressE(); task.wait(0.15); t += 0.15 end
end

-- All World Eggs list
local ALL_WORLD_EGGS = {}
do
    local seen = {}
    for name in pairs(EGG_POS) do
        if not seen[name] then seen[name]=true; table.insert(ALL_WORLD_EGGS, name) end
    end
    for name in pairs(EGG_WORLD) do
        if not seen[name] then seen[name]=true; table.insert(ALL_WORLD_EGGS, name) end
    end
    table.sort(ALL_WORLD_EGGS, function(a,b)
        if a=="Infinity Egg" then return true end
        if b=="Infinity Egg" then return false end
        return a < b
    end)
end

-- ═══════════════════════════════════════════════════════════════════
--  SEQUENCER
-- ═══════════════════════════════════════════════════════════════════
local SEQ = { _tpModules={}, _bgModules={}, _running=false, _blocked=false }

function SEQ.register(name, tickFn)
    table.insert(SEQ._tpModules, {name=name, fn=tickFn, enabled=true, priority=99})
end

function SEQ.registerBG(name, tickFn, interval)
    -- Kein eigener Thread pro Modul -- alle laufen im gemeinsamen BG-Loop
    table.insert(SEQ._bgModules, {
        name=name, fn=tickFn,
        interval=interval or 1,  -- Standard: 1s zwischen Aufrufen
        lastRun=0
    })
end

-- Gemeinsamer BG-Loop (EIN Thread fuer alle BG-Module)
local function startBGLoop()
    task.spawn(function()
        repeat task.wait(0.5) until getData()
        while true do
            task.wait(0.1)
            local t = tick()
            for _, mod in ipairs(SEQ._bgModules) do
                if t - mod.lastRun >= mod.interval then
                    mod.lastRun = t
                    pcall(mod.fn)
                    task.wait(0) -- yield zwischen Modulen
                end
            end
        end
    end)
end

-- Re-sort TP modules by priority (lower number = higher priority = runs first)
local function resortModules(S)
    table.sort(SEQ._tpModules, function(a, b)
        local pa = S.modulePriority[a.name] or 99
        local pb = S.modulePriority[b.name] or 99
        return pa < pb
    end)
end

function SEQ.start()
    if SEQ._running then return end
    SEQ._running = true
    startBGLoop()
    task.spawn(function()
        repeat task.wait(0.5) until getData()
        local idx = 1
        while true do
            task.wait(0.1)
            if SEQ._blocked then task.wait(0.5); continue end
            local mods = SEQ._tpModules
            if #mods == 0 then task.wait(1); continue end
            if idx > #mods then idx = 1 end
            local mod = mods[idx]; idx = idx + 1
            if not mod or not mod.enabled then continue end
            pcall(mod.fn)
        end
    end)
end

-- ═══════════════════════════════════════════════════════════════════
--  STATE (S)
-- ═══════════════════════════════════════════════════════════════════
local mgActive = false
local genieBlocking = false
local _genieAtZen = false
local _genieRerolls = 0
local _genieReturnCF = nil
local _genieSpamActive = false

local S = {
    -- Module priorities (lower = higher priority)
    modulePriority = {
        GemGenie=1, SeasonPass=2, Hatch=3, Fishing=4,
        Rifts=5, KeyChests=6, Board=7, Minigames=8, AutoSell=9,
    },
    -- Minigames
    mg={}, mgDiff="Insane", mgTicket=true,
    clawPrio={
        ["Super Ticket"]=200,["Infinity Elixir"]=200,
        ["Secret Elixir"]=150,["Golden Dice"]=140,["Dice Key"]=60,
        ["Lucky"]=50,["Mythic"]=50,["Speed"]=50,["Tickets"]=50,
        ["Dragon Plushie"]=40,["Rift Charm"]=10,["Super Key"]=10,
        ["Giant Dice"]=5,["Dice"]=0,
    },
    clawMax=10,
    -- Fishing
    fishOn=false, fishQuest=false, fishArea="starter",
    baits={}, fishAreaLast=nil,
    -- Hatch
    hatchOn=false, hatchEgg="Infinity Egg",
    hatchPrio={nil,nil,nil,nil}, hatchPrioOn=false,  -- 4 Slots
    selectedEggItems={},  -- multiselect fuer Inventory Eggs
    hatchRareEgg="Infinity Egg",  -- "rare" egg definition
    -- Wheels
    wheels={
        {label="Normal Wheel",     invoke="WheelSpin",          claim="ClaimWheelSpinQueue",           on=false},
        {label="Spring Wheel",     invoke="SpringWheelSpin",    claim="ClaimSpringWheelSpinQueue",     on=false},
        {label="Lunar Wheel",      invoke="LunarWheelSpin",     claim="ClaimLunarYearWheelSpinQueue",  on=false},
        {label="Valentines Wheel", invoke="ValentinesWheelSpin",claim="ClaimValentinesWheelSpinQueue", on=false},
    },
    -- Board
    boardOn=false, boardDice={"Golden Dice","Giant Dice","Dice"},
    boardGoldenTile="",      -- Ziel-Tile fuer Golden Dice (Dropdown)
    boardGoldenMinDist=1,    -- Ab welcher Distanz (1-5) Golden Dice benutzen
    -- Smart dice: schaut Board-Items an und waehlt Wuerfel danach
    -- Shrine/Dreamer/Orb
    shrineOn=false, shrineItems={},
    dreamerOn=false, dreamerAmt=100,
    goldenOrbOn=false,
    -- Bubbles - DEFAULT OFF
    bubbleOn=false,
    -- Season Pass
    seasonPassOn=false,
    -- Consumables
    potionOn=false, potionItems={},
    runeOn=false,   runeItems={},
    eggOn=false,    eggItems={},
    boxOn=false,    boxItems={},
    -- Key Chests
    chestsOn=false, chestItems={},
    -- Rifts
    riftOn=false, riftItems={}, riftChestOn=false,
    riftPermanent=false, riftSpawnTime=5,
    -- Spin Tickets
    spinTickets={
        {label="Spin Ticket",             invoke="WheelSpin",          claim="ClaimWheelSpinQueue",           on=false},
        {label="Spring Spin Ticket",      invoke="SpringWheelSpin",    claim="ClaimSpringWheelSpinQueue",     on=false},
        {label="Lunar Spin Ticket",       invoke="LunarWheelSpin",     claim="ClaimLunarYearWheelSpinQueue",  on=false},
        {label="Valentine's Spin Ticket", invoke="ValentinesWheelSpin",claim="ClaimValentinesWheelSpinQueue", on=false},
        {label="Festival Spin Ticket",    invoke="WheelSpin",          claim="ClaimWheelSpinQueue",           on=false},
        {label="Dark Spin Ticket",        invoke="WheelSpin",          claim="ClaimWheelSpinQueue",           on=false},
        {label="OG Spin Ticket",          invoke="WheelSpin",          claim="ClaimWheelSpinQueue",           on=false},
        {label="Neon Spin Ticket",        invoke="WheelSpin",          claim="ClaimWheelSpinQueue",           on=false},
        {label="Christmas Spin Ticket",   invoke="WheelSpin",          claim="ClaimWheelSpinQueue",           on=false},
    },
    -- Fuse
    fuseOn=false, fuseKeepShiny=true, fuseKeepMythic=true, fuseOnlyUnlocked=true,
    -- Daily
    dailyReward=false, dailyPerk=false,
    -- Sell
    sellOn=false, sellArea="overworld",
    -- Genie
    genieOn=false, genieMaxReroll=10,
    genieSkipBubbles=false, genieMinScore=0,
    genieStatus="Inaktiv", genieSlots={"...","...","..."},
    genieReturnPos=nil, genieSkipShiny=true, genieSkipMythic=true,
    genieRerollOn=false, genieRerollMax=50,
    genieQuestPrio={
        ["Green Fragment"]=10000, ["Rune Rock"]=50,
        ["Dream Shard"]=20, ["Shadow Crystal"]=20,
    },
    -- Season Pass
    spOn=false, spStatus="Inaktiv",
    -- Lock Pets
    lockOn=false,
    lockSecretChance=1000,  -- lock secrets with chance 1 in X and above
    lockSecretCount=5,      -- lock secrets with exist count below X
    lockSecretChanceOn=true,
    lockSecretCountOn=true,
    -- Farming
    farmBubbleOn=false, farmCollectCoinsOn=false,
    farmPlaytimeOn=false, farmTeamBubble="",
    farmTeamLuck="", farmTeamSecretLuck="",
    farmBubbleTeamOn=false, farmLuckTeamOn=false, farmSecretLuckTeamOn=false,
    -- Automation
    autoBoxGemOn=false, autoBoxGemThreshold=1000000000,  -- 1B
    autoPotionHatchOn=false,
    autoRerollOrbOn=false, autoRerollOrbThreshold=10000,
    autoWarnActive=false, autoWarnMsg="",
    -- New automation features
    autoCollectPickupOn=false,   -- Auto collect UUID pickups (kein TP)
    bubbleSellPriorityOn=false,  -- Stoppe alles wenn Bubble-Sell aktiv
    hideHatchAnimOn=false,       -- Hatch-Animation ausblenden
    -- Genie: Green Shard Override
    genieGreenShardOverride=false, -- bei green shard Quest: Bubbles+Coins auch akzeptieren
    -- Competitive
    competitiveOn=false,
    -- Autosave
    autosaveOn=true,
    -- Misc
    collectPlaytimeReward=false,
    -- Play Profiles
    profiles={}, -- loaded separately
}

-- Shrine Items
for _, item in ipairs(ShrineValues or {}) do
    if item.Type=="Potion" and (item.Level or 0) >= 1 and (item.Level or 0) <= 5 then
        local n = item.Name
        if n=="Lucky" or n=="Speed" or n=="Mythic" or n=="Coins" or n=="Tickets" then
            table.insert(S.shrineItems, {Type="Potion",Name=n,Level=item.Level,XP=item.XP,enabled=true})
        end
    end
end

-- Potions
for _, name in ipairs({"Lucky","Mythic","Speed","Coins","Tickets"}) do
    for lvl=1,7 do table.insert(S.potionItems, {Name=name,Level=lvl,enabled=false}) end
end
for _, name in ipairs({
    "Infinity Elixir","Secret Elixir","Egg Elixir",
    "Ultra Infinity Elixir","Festive Infinity Elixir",
    "Halloween Infinity Elixir","Circus Infinity Elixir",
}) do table.insert(S.potionItems, {Name=name,Level=1,enabled=false}) end
for _, name in ipairs({
    "Halloween Elixir","Festive Elixir","Valentine's Elixir",
    "Duality Elixir","Heartbreak Elixir","Circus Elixir",
    "Heaven Elixir","Hell Elixir","Lunar New Years Lantern",
    "2026 Elixir","Flowers","Spring Elixir","Sakura Elixir",
}) do for lvl=1,4 do table.insert(S.potionItems, {Name=name,Level=lvl,enabled=false}) end end

-- Runes
for _, name in ipairs({"Lucky","Mythic","Speed","Coins"}) do
    for lvl=1,7 do table.insert(S.runeItems, {Name=name,Level=lvl,enabled=false}) end
end

-- Powerup Eggs
for _, name in ipairs({
    "OG Rift Egg","Aura Egg","Silly Egg","Bee Egg","Underworld Egg",
    "Brainrot Egg","Developer Egg","Light Egg","Dark Egg","Voidcrystal Egg",
    "Season 1 Egg","Season 2 Egg","Season 3 Egg","Season 4 Egg","Season 5 Egg",
    "Season 6 Egg","Season 7 Egg","Season 8 Egg","Season 9 Egg",
    "Season OG Egg","Season XMAS Egg","Season 12 Egg","Season 13 Egg","Season Sakura Egg",
    "Series 1 Egg","Series 2 Egg","Duality Egg","Spooky Egg","Stellaris Egg",
    "Secret Egg","Prismatic Egg",
    "100M Egg","200M Egg","500M Egg",
    "OG Egg","Super OG Egg","OGRobux Egg","Inferno Egg","Jester Egg",
    "67 Egg","Federation Egg","Rumblecon Egg","Game Egg","Instrumental Egg",
    "Retro Egg","Nostalgia Egg","Food Egg","Super Silly Egg","Super Aura Egg",
    "Super Egg","Giftbox Egg","Cartoon Egg","Bruh Egg",
    "Pastel Egg","Bunny Egg","Throwback Egg",
    "Pumpkin Egg","Costume Egg","Sinister Egg","Mutant Egg","Puppet Egg",
    "Christmas Egg","Frost Egg","New Years Egg","Corn Egg",
    "July4th Egg","Candy Egg","Azure Egg","Hellish Egg",
    "Valentine's Egg","Heartbreak Egg","Lunar New Years Egg","Moon Egg",
    "Autumn Egg","Candle Egg","Winter Egg","Petal Egg","Spring Egg","Sakura Egg","Blossom Egg",
    "Royal Egg","Beach Egg","Icecream Egg","Fruit Egg","Fossil Egg","Pirate Egg",
    "Clown Egg","Cannon Egg","Magic Egg","Circus Jester Egg","Jamboree Egg","Chance Egg",
    "Dreamer Egg","Shadow Egg",
}) do table.insert(S.eggItems, {Name=name,enabled=false}) end

-- Mystery Boxes
for _, name in ipairs({
    "Mystery Box","Golden Box","Light Box","Festival Mystery Box",
    "Shadow Mystery Box","Fall Mystery Box","Spooky Mystery Box",
    "OG Mystery Box","Thanksgiving Mystery Box","Circus Mystery Box",
    "Infinity Mystery Box","Spring Mystery Box","Sakura Mystery Box",
}) do table.insert(S.boxItems, {Name=name,enabled=false}) end

-- Key Chests
for _, pair in ipairs({
    {"Golden Chest","Golden Key"},{"Royal Chest","Royal Key"},
    {"Dice Chest","Dice Key"},{"Super Chest","Super Key"},{"Moon Chest","Moon Key"},
}) do table.insert(S.chestItems, {ChestName=pair[1],KeyName=pair[2],enabled=false}) end

-- Rift Items — nur tatsaechlich spawnbare Rifts
-- Overworld: Golden Chest, Royal Chest, Super Chest, OG Egg Rift
-- Minigame Paradise: Dice Chest
-- Egg Rifts: alle bekannten Egg-Rifts als freie Auswahl
S.riftEggName = "OG Rift Egg"   -- ausgewaehltes Egg Rift
S.riftEggOn   = false
S.riftChestItems = {
    {name="golden-chest", world="The Overworld",    displayName="Golden Chest",  on=false, lastSummon=0, interval=31*60},
    {name="royal-chest",  world="The Overworld",    displayName="Royal Chest",   on=false, lastSummon=0, interval=31*60},
    {name="super-chest",  world="The Overworld",    displayName="Super Chest",   on=false, lastSummon=0, interval=31*60},
    {name="dice-chest",   world="Minigame Paradise", displayName="Dice Chest",    on=false, lastSummon=0, interval=31*60},
}
-- Alle bekannten Egg-Rift Namen (fuer Dropdown)
S.riftEggOptions = {
    "OG Rift Egg","Lunar New Years Egg","Spring Egg","Sakura Egg",
    "Pastel Egg","Bunny Egg","Pumpkin Egg","Sinister Egg",
    "Valentine's Egg","Heartbreak Egg","Christmas Egg","Frost Egg",
}

-- ═══════════════════════════════════════════════════════════════════
--  LOAD CONFIG
-- ═══════════════════════════════════════════════════════════════════
do
    local cfg = loadConfig()
    if cfg then applyConfig(S, cfg); print("[BGS AIO v0.8.1] Config geladen!") end
end
-- Load profiles list
do
    local raw = loadProfiles()
    if raw and type(raw)=="table" then S.profiles = raw end
end

-- Auto-sort modules based on saved priority
resortModules(S)

-- ═══════════════════════════════════════════════════════════════════
--  POSITIONS
-- ═══════════════════════════════════════════════════════════════════
local ZEN_POS        = Vector3.new(-90.8,15958.8,-14.6)
local BOARD_POS      = Vector3.new(10034.2,26.9,171.7)
local RAINBOW_EGG_POS = Vector3.new(-36.9,15970.9,49.5)
local SELL_POS = {
    overworld=Vector3.new(77.6,8.2,-113.1),
    paradise=Vector3.new(9921.7,25.7,137.8),
    zen=Vector3.new(-70.4,6861.5,116.5),
}
local FISH_POS = {
    starter=Vector3.new(-23647.1,9.0,-158.8),
    blizzard=Vector3.new(-21414.8,5.5,-101008.4),
    jungle=Vector3.new(-19318.9,5.5,18680.7),
    lava=Vector3.new(-17247.5,8.6,-20493.5),
    atlantis=Vector3.new(-13983.5,3.9,-20314.4),
    dream=Vector3.new(-21787.3,6.0,-20621.2),
    classic=Vector3.new(-41504.0,10.3,-20579.1),
}

-- CollectPickup Remote (separate path)
local PickupRemote = nil
pcall(function()
    local rem = RS:FindFirstChild("Remotes")
    if rem then
        local pick = rem:FindFirstChild("Pickups")
        if pick then PickupRemote = pick:FindFirstChild("CollectPickup") end
    end
end)
if not PickupRemote then
    -- Try WaitForChild with timeout
    task.spawn(function()
        local ok, r = pcall(function()
            return RS:WaitForChild("Remotes",5)
                :WaitForChild("Pickups",5)
                :WaitForChild("CollectPickup",5)
        end)
        if ok and r then PickupRemote = r
            print("[BGS AIO] PickupRemote gefunden: "..r:GetFullName())
        end
    end)
end

-- Rebirth Machine Remote — bestaetigt:
-- RS.Shared.Framework.Network.Remote.RemoteFunction:InvokeServer("UseRebirthMachine", {id1,id2,...})
-- Das ist identisch mit RemoteFn — kein auto-detect noetig

-- GetExisting Remote (zum Pruefen ob Pet-ID noch existiert):
local function getExistingPet(name)
    local ok, result = pcall(function()
        return RemoteFn:InvokeServer("GetExisting", name)
    end)
    return ok and result or nil
end

-- Collect all pickups in workspace via CollectPickup UUID remote
local function collectAllPickups()
    if not PickupRemote then return 0 end
    local collected = 0
    local UUID_PAT = "^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$"
    local function scanForPickups(parent, depth)
        if depth > 6 then return end
        for _, obj in ipairs(parent:GetChildren()) do
            -- UUID-named parts = pickups
            if obj.Name:match(UUID_PAT) then
                pcall(function() PickupRemote:FireServer(obj.Name) end)
                collected += 1
                task.wait(0)
            end
            scanForPickups(obj, depth+1)
        end
    end
    local rendered = workspace:FindFirstChild("Rendered")
    if rendered then
        -- Check common pickup folder names
        for _, folderName in ipairs({"Pickups","Coins","Collectables","Items","Generic"}) do
            local folder = rendered:FindFirstChild(folderName)
            if folder then scanForPickups(folder, 0) end
        end
        -- Also scan Generic for UUID-named parts (from the remote log)
        local generic = rendered:FindFirstChild("Generic")
        if generic then scanForPickups(generic, 0) end
    end
    return collected
end

-- ═══════════════════════════════════════════════════════════════════
--  GENIE HELPERS
-- ═══════════════════════════════════════════════════════════════════
local function getGenieNPCPos()
    local ok, pos = pcall(function()
        return workspace.Worlds["The Overworld"].Islands.Zen.Island.GemGenie.Root.Position
    end)
    return (ok and pos) or ZEN_POS
end

local RARITY_EGG = {
    ["Common"]="Spikey Egg",["Unique"]="Spikey Egg",["Rare"]="Spikey Egg",
    ["Epic"]="Crystal Egg",["Legendary"]="Infinity Egg",
}
local GENIE_BAD_TASKS = {
    Collect=true,Sell=true,Invite=true,Group=true,Discord=true,
    AreaUnlock=true,Purchase=true,VisitCabins=true,CollectPresents=true,
}

local function genieHasBadTask(q)
    for _, t in ipairs(q.Tasks or {}) do
        if GENIE_BAD_TASKS[t.Type] then return true, t.Type end
    end
    return false
end
local function genieHasBubbles(q)
    for _, t in ipairs(q.Tasks or {}) do
        if t.Type=="Bubbles" then return true end
    end
    return false
end
local function genieIsHatchOnly(q)
    if not q or not q.Tasks or #q.Tasks==0 then return false end
    for _, t in ipairs(q.Tasks) do if t.Type~="Hatch" then return false end end
    return true
end
local function genieRewardScore(rewards)
    local best=0
    for _, item in ipairs(rewards or {}) do
        local p = S.genieQuestPrio[item.Name or ""] or 0
        if p > best then best=p end
    end
    return best
end
local function fmtItem(item)
    local s=item.Name or "?"
    if item.Level then s=s.." L"..item.Level end
    if item.Amount and item.Amount>1 then s=s.." x"..item.Amount end
    return s
end
local function fmtRewards(rewards)
    local p={}
    for _, r in ipairs(rewards or {}) do table.insert(p,fmtItem(r)) end
    return table.concat(p," | ")
end

local function genieQuestHasGreenShard(calc)
    for _, item in ipairs(calc.Rewards or {}) do
        if (item.Name or ""):find("Green") then return true end
    end
    return false
end

local function genieAnalyzeSlots(data)
    local seed = data.GemGenie and data.GemGenie.Seed
    if not seed then return 1,false,{"?","?","?"} end
    local previews={}; local bestSlot,bestScore=nil,-1; local allBad=true
    for slot=1,3 do
        local ok, calc = pcall(GenieQuest, data, seed+(slot-1))
        if not ok or not calc then previews[slot]="?"; continue end
        local bad,badType = genieHasBadTask(calc)
        local bubbles = genieHasBubbles(calc)
        local hatchOnly = genieIsHatchOnly(calc)
        local score = genieRewardScore(calc.Rewards)
        local rewards = fmtRewards(calc.Rewards)
        local hasGS = genieQuestHasGreenShard(calc)

        -- Green Shard Override: quest mit Green Shard wird immer akzeptiert,
        -- auch wenn Bubbles oder Collect dabei sind
        local skipBubbles = S.genieSkipBubbles and bubbles
        local isBad = bad
        if hasGS and S.genieGreenShardOverride then
            skipBubbles = false
            if isBad and (badType=="Collect" or badType=="Bubbles") then
                isBad=false
            end
        end

        local skip = isBad or skipBubbles
        if skip then
            previews[slot]="[X] "..(isBad and badType or "Bubbles").." | "..rewards
        elseif hatchOnly then
            previews[slot]="[OK] "..(hasGS and "[GS] " or "").."Sc:"..score.." | "..rewards
            allBad=false
            if score>bestScore then bestScore=score; bestSlot=slot end
        else
            previews[slot]="[~] "..(hasGS and "[GS] " or "").."Mix | "..rewards
            if bestSlot==nil then allBad=false; bestSlot=slot end
        end
    end
    if bestSlot==nil then bestSlot=1 end
    return bestSlot,allBad,previews
end

local function genieQuestIsGood(data)
    local seed = data.GemGenie and data.GemGenie.Seed
    if not seed then return false end
    for slot=1,3 do
        local ok, calc = pcall(GenieQuest, data, seed+(slot-1))
        if not ok or not calc then continue end
        -- Bad tasks = sofort skip
        if genieHasBadTask(calc) then continue end
        -- Bubbles skip (wenn aktiviert)
        if S.genieSkipBubbles and genieHasBubbles(calc) then continue end
        -- Green Shard Override: wenn GS dabei, immer gut
        if genieQuestHasGreenShard and genieQuestHasGreenShard(calc) and S.genieGreenShardOverride then
            return true
        end
        -- Wenn genieQuestPrio alle 0 sind: jede nicht-bad Quest ist gut
        local hasPrio = false
        for _, v in pairs(S.genieQuestPrio) do
            if v > 0 then hasPrio = true; break end
        end
        if not hasPrio then return true end -- keine Prios gesetzt = alles akzeptieren
        -- Sonst: pruefe ob ein Prio-Item in den Rewards ist
        for _, item in ipairs(calc.Rewards or {}) do
            if (S.genieQuestPrio[item.Name or ""] or 0) > 0 then return true end
        end
    end
    return false
end

local function genieExecuteQuest(quest)
    local data = getData()
    local seed = data and data.GemGenie and data.GemGenie.Seed
    local rewards={}
    if seed then
        for slot=1,3 do
            local ok, calc = pcall(GenieQuest, data, seed+(slot-1))
            if ok and calc and QuestUtil:Compare(quest,calc) then
                rewards=calc.Rewards or {}; break
            end
        end
    end
    local rInfo = fmtRewards(rewards)

    -- Sort tasks: specific egg first, then rarity
    local sortedTasks = {}
    for i, t in ipairs(quest.Tasks or {}) do
        table.insert(sortedTasks, {idx=i, task=t, isSpecific=(t.Egg and t.Egg~="")})
    end
    table.sort(sortedTasks, function(a,b)
        if a.isSpecific and not b.isSpecific then return true end
        return false
    end)

    for _, entry in ipairs(sortedTasks) do
        local taskIdx = entry.idx
        local t = entry.task
        if not S.genieOn then break end
        if t.Type~="Hatch" then continue end

        local eggName = (t.Egg and t.Egg~="") and t.Egg
            or (t.Rarity and RARITY_EGG[t.Rarity]) or "Infinity Egg"
        local req = QuestUtil:GetRequirement(t)
        local d0 = getData()
        local q0 = d0 and QuestUtil:FindById(d0,"gem-genie")
        if not q0 then break end
        local prog0 = (q0.Progress or {})[taskIdx] or 0
        if prog0>=req then S.genieStatus=("Task "..taskIdx.." fertig"); continue end

        S.genieStatus=("Egg ["..taskIdx.."] TP > "..eggName.." (0/"..req..")")
        if not tpToEgg(eggName) then
            S.genieStatus=("WARN: "..eggName.." nicht gefunden")
            task.wait(3)
            if not tpToEgg(eggName) then continue end
        end
        task.wait(0.3)
        _genieSpamActive=true
        task.spawn(function()
            while _genieSpamActive do pressE(); task.wait(0.08) end
        end)
        local elapsed=0
        repeat
            task.wait(1.5); elapsed+=1.5
            if not S.genieOn then _genieSpamActive=false; return end
            local d2=getData()
            local q2=d2 and QuestUtil:FindById(d2,"gem-genie")
            if not q2 then _genieSpamActive=false; break end
            local p2=(q2.Progress or {})[taskIdx] or 0
            S.genieStatus=("Egg ["..taskIdx.."] "..eggName.." "..p2.."/"..req.." | "..rInfo)
            if p2>=req or QuestUtil:IsComplete(q2) then _genieSpamActive=false; break end
            if elapsed%30<1.5 then
                local hrp=LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
                local eggPos=findEggPos(eggName)
                if hrp and eggPos and (hrp.Position-eggPos).Magnitude>25 then
                    _genieSpamActive=false
                    task.wait(0.1); tpToEgg(eggName); task.wait(0.3)
                    _genieSpamActive=true
                    task.spawn(function()
                        while _genieSpamActive do pressE(); task.wait(0.08) end
                    end)
                end
            end
        until elapsed>240
        _genieSpamActive=false
        task.wait(0.2)
    end
end

-- Season Pass: robuster Quest-Scan (sucht alle aktiven Quests nach SP-Typ)
local SP_BAD_TASKS = {
    Collect=true, Sell=true, Invite=true, Group=true, Discord=true,
    AreaUnlock=true, Purchase=true, VisitCabins=true,
}
local function spFindActiveQuest(data)
    if not data or not data.Quests then return nil end
    -- Durchsuche alle Quests nach Season Pass Kandidaten
    for _, q in ipairs(data.Quests) do
        local id = (q.Id or ""):lower()
        if id:find("season") or id:find("pass") or id:find("hourly") or id:find("daily") then
            if not QuestUtil:IsComplete(q) then return q end
        end
    end
    -- Fallback: irgendeine nicht-abgeschlossene Quest mit Hatch/Bubbles
    for _, q in ipairs(data.Quests) do
        if not QuestUtil:IsComplete(q) then
            local hasBad=false
            local hasGood=false
            for _, t in ipairs(q.Tasks or {}) do
                if SP_BAD_TASKS[t.Type] then hasBad=true end
                if t.Type=="Hatch" or t.Type=="Bubbles" then hasGood=true end
            end
            if hasGood and not hasBad then return q end
        end
    end
    return nil
end

-- Holt aktuellen Progress fuer eine Quest (sucht nach questRef in allen Quests)
local function spGetProgress(questRef, taskIdx)
    local d=getData(); if not d or not d.Quests then return 0 end
    for _, q in ipairs(d.Quests) do
        if q.Id == questRef.Id then
            return (q.Progress or {})[taskIdx] or 0
        end
    end
    return 0
end
local function spIsComplete(questRef)
    local d=getData(); if not d or not d.Quests then return true end
    for _, q in ipairs(d.Quests) do
        if q.Id == questRef.Id then return QuestUtil:IsComplete(q) end
    end
    return true -- nicht mehr da = als complete behandeln
end

-- Season Pass Quest Executor
local _spSpamActive = false
local function spExecuteQuest(quest)
    if not quest or not quest.Tasks then return end
    -- Sort tasks: 1. specific egg (Egg field gesetzt), 2. rarity hatch, 3. bubbles, 4. rest
    local tasks = {}
    for i, t in ipairs(quest.Tasks) do
        local prio = 99
        if t.Type=="Hatch" then
            prio = (t.Egg and t.Egg~="") and 1 or 2
        elseif t.Type=="Bubbles" then
            prio = 3
        elseif SP_BAD_TASKS[t.Type] then
            prio = 100 -- skip
        end
        table.insert(tasks, {idx=i, task=t, prio=prio})
    end
    table.sort(tasks, function(a,b) return a.prio < b.prio end)

    for _, entry in ipairs(tasks) do
        if not S.spOn then break end
        if spIsComplete(quest) then break end
        local t = entry.task
        local taskIdx = entry.idx
        if entry.prio >= 100 then continue end -- Skip bad tasks

        local req = QuestUtil:GetRequirement(t)
        local prog = spGetProgress(quest, taskIdx)
        if prog >= req then S.spStatus="SP Task "..taskIdx.." fertig"; continue end

        if t.Type=="Hatch" then
            local eggName = (t.Egg and t.Egg~="") and t.Egg
                or (t.Rarity and RARITY_EGG[t.Rarity]) or S.hatchEgg
            S.spStatus="SP Hatch: "..eggName.." "..prog.."/"..req
            if not tpToEgg(eggName) then
                -- Fallback to standard egg
                if not tpToEgg(S.hatchEgg) then continue end
                eggName = S.hatchEgg
            end
            task.wait(0.3)
            _spSpamActive=true
            task.spawn(function() while _spSpamActive do pressE(); task.wait(0.08) end end)
            local elapsed=0
            repeat
                task.wait(1.5); elapsed+=1.5
                if not S.spOn then _spSpamActive=false; return end
                local p2=spGetProgress(quest, taskIdx)
                S.spStatus="SP Hatch: "..eggName.." "..p2.."/"..req
                if p2>=req or spIsComplete(quest) then _spSpamActive=false; break end
                -- Re-TP alle 30s
                if elapsed%30<1.5 then
                    local hrp=LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
                    local eggPos=findEggPos(eggName)
                    if hrp and eggPos and (hrp.Position-eggPos).Magnitude>25 then
                        _spSpamActive=false; task.wait(0.1)
                        tpToEgg(eggName); task.wait(0.3)
                        _spSpamActive=true
                        task.spawn(function() while _spSpamActive do pressE(); task.wait(0.08) end end)
                    end
                end
            until elapsed>300
            _spSpamActive=false

        elseif t.Type=="Bubbles" then
            S.spStatus="SP Bubbles: "..prog.."/"..req
            local elapsed=0
            repeat
                task.wait(0.08); elapsed+=0.08
                if not S.spOn then break end
                pcall(function() RemoteEv:FireServer("BlowBubble") end)
                if elapsed%2<0.1 then
                    local p2=spGetProgress(quest, taskIdx)
                    S.spStatus="SP Bubbles: "..p2.."/"..req
                    if p2>=req or spIsComplete(quest) then break end
                end
            until elapsed>180

        elseif t.Type=="Collect" or t.Type=="CollectCoins" or t.Type=="Coins" then
            -- Nur Rainbow Egg wenn aktive Coin-Quest - sonst nur Pickups sammeln
            S.spStatus="SP Coins: "..prog.."/"..req
            local elapsed=0
            local spamOn=true
            -- TP zu Rainbow Egg und hatchen (hoechste Coin-Dichte im Overworld)
            tpToEgg("Rainbow Egg"); task.wait(0.3)
            task.spawn(function()
                while spamOn and S.spOn do pressE(); task.wait(0.08) end
            end)
            repeat
                task.wait(0.5); elapsed+=0.5
                if not S.spOn then spamOn=false; break end
                collectAllPickups()
                local p2=spGetProgress(quest, taskIdx)
                S.spStatus="SP Coins: "..p2.."/"..req
                if p2>=req or spIsComplete(quest) then break end
                if elapsed%15<0.6 then
                    spamOn=false; task.wait(0.1)
                    tpToEgg("Rainbow Egg"); task.wait(0.3)
                    spamOn=true
                    task.spawn(function()
                        while spamOn and S.spOn do pressE(); task.wait(0.08) end
                    end)
                end
            until elapsed>300
            spamOn=false
        end
        task.wait(0.3)
    end
    _spSpamActive=false
end

-- ═══════════════════════════════════════════════════════════════════
--  TP MODULE: GEM GENIE
-- ═══════════════════════════════════════════════════════════════════
SEQ.register("GemGenie", function()
    if not QuestUtil or not GenieQuest then return false end
    if not S.genieOn then
        genieBlocking=false; _genieSpamActive=false; _genieAtZen=false
        return false
    end
    local data=getData()
    if not data or not data.GemGenie then task.wait(1); return false end

    local activeQuest=QuestUtil:FindById(data,"gem-genie")
    if activeQuest then
        genieBlocking=true
        S.genieStatus="Quest laeuft..."
        genieExecuteQuest(activeQuest)
        local d2=getData()
        local q2=d2 and QuestUtil:FindById(d2,"gem-genie")
        if not q2 or QuestUtil:IsComplete(q2 or activeQuest) then
            S.genieStatus="Quest abgeschlossen!"
            genieBlocking=false; _genieRerolls=0; _genieAtZen=false
            if _genieReturnCF then
                local hrp=LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
                local hum=LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
                if hrp then
                    if hum then hum.PlatformStand=true end
                    hrp.CFrame=_genieReturnCF; task.wait(0.12)
                    if hum then hum.PlatformStand=false end
                end
            end
            local w=0
            repeat task.wait(0.5); w+=0.5
                local d3=getData()
                if not d3 or not QuestUtil:FindById(d3,"gem-genie") then break end
            until w>15
        end
        return true
    end

    genieBlocking=false
    local cdLeft=(data.GemGenie.Next or 0)-now()
    if cdLeft>0 then
        _genieRerolls=0
        local _,_,previews=genieAnalyzeSlots(data)
        S.genieSlots=previews
        S.genieStatus=("CD: "..math.ceil(cdLeft).."s")
        task.wait(math.min(cdLeft,8))
        return false
    end

    _genieRerolls=0
    local hrp=LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if hrp and not _genieAtZen then
        _genieReturnCF=hrp.CFrame
        S.genieStatus="TP zu Zen..."
        tp(getGenieNPCPos()+Vector3.new(3,0,3))
        task.wait(1.0); pressE(); task.wait(0.5)
        _genieAtZen=true
    end

    data=getData()
    if not data or not data.GemGenie then return false end
    S.genieStatus="Analysiere Slots..."
    local bestSlot,allBad,previews=genieAnalyzeSlots(data)
    S.genieSlots=previews

    -- Quest-Reroll-System
    if S.genieRerollOn then
        local isGood = genieQuestIsGood(data)
        if not isGood then
            -- Grenze: wenn unter genieRerollMax, reroll
            -- Wenn ueber Grenze: trotzdem weiter rerolln bis gute Quest gefunden
            -- (Grenze darf ueberschritten werden laut Anforderung)
            S.genieStatus = ("Reroll "..(_genieRerolls+1).."/"..S.genieRerollMax
                ..(_genieRerolls >= S.genieRerollMax and " (Limit - suche weiter)" or "").."...")
            if QuestUtil:FindById(getData(),"gem-genie") then return true end
            pcall(Remote.FireServer, Remote, "ChangeGenieQuest")
            _genieRerolls += 1
            task.wait(1.5)
            return true
        else
            -- Gute Quest gefunden - zaehler zuruecksetzen
            _genieRerolls = 0
        end
    elseif allBad then
        if _genieRerolls>=S.genieMaxReroll then
            bestSlot=1; S.genieStatus="Limit erreicht > Slot 1"
        else
            S.genieStatus=("Alle schlecht, Reroll ".._genieRerolls.."/"..S.genieMaxReroll)
            if QuestUtil:FindById(getData(),"gem-genie") then return true end
            pcall(Remote.FireServer,Remote,"ChangeGenieQuest")
            _genieRerolls+=1; task.wait(1.5)
            return true
        end
    end

    if QuestUtil:FindById(getData(),"gem-genie") then _genieAtZen=false; return true end
    S.genieStatus=("Starte Slot "..bestSlot)
    pcall(Remote.FireServer,Remote,"StartGenieQuest",bestSlot)
    _genieAtZen=false
    local w=0
    repeat task.wait(0.5); w+=0.5
        local d2=getData()
        if d2 and QuestUtil:FindById(d2,"gem-genie") then break end
    until w>8
    return true
end)

-- ═══════════════════════════════════════════════════════════════════
--  TP MODULE: SEASON PASS
-- ═══════════════════════════════════════════════════════════════════
SEQ.register("SeasonPass", function()
    if not S.spOn then S.spStatus="Inaktiv"; _spSpamActive=false; return false end
    local data=getData(); if not data then return false end

    -- 1) Erst: Season Pass Tier-Rewards claimen (passive)
    if data.SeasonPass then
        local claimed=0
        for i, reward in ipairs(data.SeasonPass.Rewards or {}) do
            if not reward.Claimed then
                pcall(function() RemoteEv:FireServer("ClaimSeasonPassReward",i) end)
                claimed+=1; task.wait(0.2)
            end
        end
        if claimed>0 then S.spStatus="SP: "..claimed.." Rewards geclaimed"; task.wait(1) end
    end

    -- 2) Aktive SP-Quest suchen und ausführen
    local spQuest = spFindActiveQuest(data)
    if spQuest then
        if spIsComplete(spQuest) then
            -- Claim reward
            pcall(function() RemoteEv:FireServer("ClaimSeasonPassQuestReward") end)
            pcall(function() RemoteEv:FireServer("ClaimDailyQuestReward") end)
            S.spStatus="SP Quest abgeschlossen + geclaimed!"
            task.wait(3)
            return true
        end
        S.spStatus="SP Quest gefunden: "..(spQuest.Id or "?")
        spExecuteQuest(spQuest)
        -- Nach Ausführung: claim versuchen
        if spIsComplete(spQuest) then
            pcall(function() RemoteEv:FireServer("ClaimSeasonPassQuestReward") end)
            pcall(function() RemoteEv:FireServer("ClaimDailyQuestReward") end)
            S.spStatus="SP Quest abgeschlossen!"
        end
        task.wait(2)
        return true
    end

    S.spStatus="SP: Kein Quest aktiv / warte..."
    return false
end)

-- ═══════════════════════════════════════════════════════════════════
--  TP MODULE: HATCH
-- ═══════════════════════════════════════════════════════════════════
SEQ.register("Hatch", function()
    if not S.hatchOn or genieBlocking then return false end
    if S.hatchPrioOn then
        for _, prioEgg in ipairs(S.hatchPrio) do
            if prioEgg and prioEgg~="" and findEggPos(prioEgg) then
                hatchEgg(prioEgg,4); return true
            end
        end
    end
    -- Check if rare egg is available in workspace first
    if S.hatchRareEgg and S.hatchRareEgg~="" and S.hatchRareEgg~=S.hatchEgg then
        if findEggPos(S.hatchRareEgg) then
            hatchEgg(S.hatchRareEgg,4); return true
        end
    end
    hatchEgg(S.hatchEgg,4)
    return true
end)

-- ═══════════════════════════════════════════════════════════════════
--  TP MODULE: FISHING
-- ═══════════════════════════════════════════════════════════════════
local function afOn()
    if not AutoFishModule then return false end
    local ok,v=pcall(function() return AutoFishModule:IsEnabled() end)
    return ok and v
end
local function setAF(v)
    if AutoFishModule then pcall(function() AutoFishModule:SetEnabled(v) end) end
end
local function questArea()
    local d=getData(); if not d or not d.Quests then return nil end
    for _, q in ipairs(d.Quests) do
        if (q.Id or ""):sub(1,13)=="sailor-bounty" then
            for i,t in ipairs(q.Tasks or {}) do
                local ok,req=pcall(function() return QuestUtil:GetRequirement(t) end)
                if (q.Progress or {})[i]<(ok and req or 0) and t.Area then return t.Area end
            end
        end
    end
end
local function nextBait()
    local d=getData(); if not d then return end
    for name,en in pairs(S.baits) do
        if en and d.FishingBaits and (d.FishingBaits[name] or 0)>0 then return name end
    end
end

SEQ.register("Fishing", function()
    if not S.fishOn then
        if afOn() then setAF(false) end
        return false
    end
    local bait=nextBait()
    if bait then RemoteEv:FireServer("SetEquippedBait",bait) end
    local target=(S.fishQuest and questArea()) or S.fishArea or "starter"
    if target~=S.fishAreaLast or not afOn() then
        setAF(false); RemoteEv:FireServer("EquipRod")
        tp(FISH_POS[target] or FISH_POS.starter)
        task.wait(0.25); RemoteEv:FireServer("EquipRod"); task.wait(0.25)
        if S.fishOn then setAF(true) end
        S.fishAreaLast=target
    end
    task.wait(2)
    return true
end)

-- ═══════════════════════════════════════════════════════════════════
--  TP MODULE: RIFTS
-- ═══════════════════════════════════════════════════════════════════
SEQ.register("Rifts", function()
    if not S.riftOn then return false end
    local t=now(); local didSomething=false
    local riftTime=S.riftSpawnTime*60

    -- Chest Rifts
    for _, r in ipairs(S.riftChestItems) do
        if not r.on then continue end
        local interval=S.riftPermanent and 0 or r.interval
        if t-r.lastSummon < interval then continue end
        local ok=pcall(function()
            RemoteFn:InvokeServer("SummonRift",{Type="Chest",Name=r.name,World=r.world,Time=riftTime})
        end)
        if ok then
            r.lastSummon=t; didSomething=true
            if S.riftChestOn then
                task.wait(3)
                local chestPart=nil; local searchT=0
                repeat
                    task.wait(0.5); searchT+=0.5
                    local riftsFolder=workspace:FindFirstChild("Rendered")
                        and workspace.Rendered:FindFirstChild("Rifts")
                    if riftsFolder then
                        local cm=riftsFolder:FindFirstChild(r.name)
                        if cm then
                            chestPart=cm:FindFirstChildWhichIsA("BasePart") or cm:FindFirstChild("Root")
                        end
                    end
                until chestPart or searchT>8
                if chestPart then
                    local hrp=LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
                    local hum=LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
                    if hrp then
                        if hum then hum.PlatformStand=true end
                        local pos=chestPart.Position
                        hrp.CFrame=CFrame.new(pos+Vector3.new(2,0.5,0),Vector3.new(pos.X,pos.Y+0.5,pos.Z))
                        task.wait(0.2)
                        if hum then hum.PlatformStand=false end
                        task.wait(0.3)
                        for _=1,5 do
                            pcall(function() RemoteEv:FireServer("UnlockRiftChest",r.name,LP) end)
                            task.wait(0.3)
                        end
                    end
                end
            end
        end
        task.wait(1)
    end

    -- Egg Rift
    if S.riftEggOn and S.riftEggName~="" then
        local riftEggLastKey="_riftEggLast"
        S[riftEggLastKey]=S[riftEggLastKey] or 0
        local interval=S.riftPermanent and 0 or 31*60
        if t-S[riftEggLastKey] >= interval then
            local ok=pcall(function()
                RemoteFn:InvokeServer("SummonRift",{
                    Type="Egg", Name=S.riftEggName,
                    World="The Overworld", Time=riftTime, Luck=1
                })
            end)
            if ok then
                S[riftEggLastKey]=t; didSomething=true
                -- TP to hatched egg if toggle on
                if S.riftChestOn then
                    task.wait(2)
                    tpToEgg(S.riftEggName)
                    task.wait(0.3)
                    for _=1,15 do pressE(); task.wait(0.1) end
                end
            end
        end
    end

    return didSomething
end)

-- ═══════════════════════════════════════════════════════════════════
--  TP MODULE: KEY CHESTS
-- ═══════════════════════════════════════════════════════════════════
SEQ.register("KeyChests", function()
    if not S.chestsOn then return false end
    local d=getData(); if not d then return false end
    local didSomething=false
    for _, it in ipairs(S.chestItems) do
        if not it.enabled then continue end
        local keys=(d.Powerups or {})[it.KeyName] or 0
        if keys>0 then
            pcall(function() RemoteEv:FireServer("UnlockRiftChest",it.ChestName,it.KeyName) end)
            task.wait(1); didSomething=true
        end
    end
    return didSomething
end)

-- ═══════════════════════════════════════════════════════════════════
--  TP MODULE: AUTO SELL
-- ═══════════════════════════════════════════════════════════════════
SEQ.register("AutoSell", function()
    if not S.sellOn then return false end
    tp(SELL_POS[S.sellArea] or SELL_POS.overworld); task.wait(0.3)
    pcall(function() RemoteEv:FireServer("SellPets") end)
    pcall(function() RemoteEv:FireServer("AutoSell") end)
    task.wait(1.5)
    return true
end)

-- ═══════════════════════════════════════════════════════════════════
--  TP MODULE: MINIGAMES
-- ═══════════════════════════════════════════════════════════════════
local function sortedItems(bonusItems)
    local sorted={}
    for guid,item in pairs(bonusItems) do
        local p=S.clawPrio[item.Name or ""] or 0
        if p>0 then table.insert(sorted,{guid=guid,name=item.Name or "?",p=p}) end
    end
    table.sort(sorted,function(a,b) return a.p>b.p end)
    if S.clawMax<#sorted then
        local c={}; for i=1,S.clawMax do c[i]=sorted[i] end; return c
    end
    return sorted
end
local MG_POS={["Robot Claw"]=Vector3.new(9887.8,13406.6,262.7),["Hyper Darts"]=Vector3.new(9859.1,20086.4,255.5)}

local function runMG(name)
    if not S.mg[name] then return end
    mgActive=true
    local mgPos=MG_POS[name]
    if mgPos then
        local hrp=LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        if hrp and (hrp.Position-mgPos).Magnitude>50 then tp(mgPos) end
    end
    if not S.mg[name] then mgActive=false; RemoteEv:FireServer("FinishMinigame"); return end
    if name=="Robot Claw" or name=="Hyper Darts" then
        local bonusItems=nil
        local conn=Remote.Event("StartMinigame"):Connect(function(data)
            if data and data.BonusItems then bonusItems=data.BonusItems end
        end)
        RemoteEv:FireServer("StartMinigame",name,S.mgDiff)
        task.wait(0.8); conn:Disconnect()
        if bonusItems then
            local items=sortedItems(bonusItems)
            for _, e in ipairs(items) do
                if not S.mg[name] then break end
                RemoteEv:FireServer("GrabMinigameItem",e.guid); task.wait(0.15)
            end
        end
    else
        RemoteEv:FireServer("StartMinigame",name,S.mgDiff); task.wait(0.5)
    end
    RemoteEv:FireServer("FinishMinigame")
    mgActive=false; task.wait(1.5)
end

local function bestDice()
    local d=getData(); if not d then return nil end
    for _, name in ipairs(S.boardDice) do
        if (d.Powerups and (d.Powerups[name] or 0)>0) then return name end
    end
end

SEQ.register("Minigames", function()
    if genieBlocking then return false end
    local any=false
    for _, en in pairs(S.mg) do if en==true then any=true; break end end
    if not any then
        if mgActive then RemoteEv:FireServer("FinishMinigame"); mgActive=false end
        return false
    end
    local d=getData(); if not d then return false end
    local didSomething=false
    for name,en in pairs(S.mg) do
        if en==true and isReady(name) then runMG(name); didSomething=true; break end
    end
    if S.mgTicket and ownedPU("Super Ticket")>0 then
        local best,bestT=nil,math.huge
        for name,en in pairs(S.mg) do
            if en then
                local t=((d.Cooldowns and d.Cooldowns[name]) or 0)-now()
                if t>0 and t<bestT then bestT=t; best=name end
            end
        end
        if best and bestT<30 then
            RemoteEv:FireServer("SkipMinigameCooldown",best); task.wait(1); didSomething=true
        end
    end
    return didSomething
end)

SEQ.register("Board", function()
    if not S.boardOn or genieBlocking then return false end

    -- Smart Dice Logik:
    -- 1) Schau welche Items auf dem Board sind und wie weit sie weg sind
    -- 2) Wenn ein Item <= 6 Felder: normaler Dice
    -- 3) Wenn ein Item <= 10 Felder: Giant Dice
    -- 4) Golden Dice: nur wenn Ziel-Tile innerhalb boardGoldenMinDist Felder
    local d = getData(); if not d then return false end

    local function getBoardItems()
        -- Versuche Board-Items aus LocalData zu lesen
        local items = d.Board and d.Board.Items or {}
        return items
    end

    local function getDistToNearestItem()
        local items = getBoardItems()
        local minDist = math.huge
        for _, item in pairs(items) do
            local pos = item.Position or item.Tile or 0
            local current = d.Board and (d.Board.Position or d.Board.Tile or 0) or 0
            local dist = pos - current
            if dist < 0 then dist = dist + (d.Board and d.Board.Size or 72) end
            if dist < minDist then minDist = dist end
        end
        return minDist
    end

    local function getDistToTargetTile()
        if not S.boardGoldenTile or S.boardGoldenTile == "" then return math.huge end
        local items = getBoardItems()
        local current = d.Board and (d.Board.Position or d.Board.Tile or 0) or 0
        local boardSize = d.Board and d.Board.Size or 72
        for _, item in pairs(items) do
            local name = item.Name or item.Type or ""
            if name == S.boardGoldenTile then
                local dist = (item.Position or item.Tile or 0) - current
                if dist < 0 then dist = dist + boardSize end
                return dist
            end
        end
        return math.huge
    end

    -- Wuerfel auswaehlen
    local function pickDice()
        local distToTarget = getDistToTargetTile()
        local distToItem   = getDistToNearestItem()

        -- Golden Dice: wenn Ziel-Tile exakt in S.boardGoldenMinDist Felder
        if S.boardGoldenTile ~= "" and distToTarget <= S.boardGoldenMinDist then
            if ownedPU("Golden Dice") > 0 then return "Golden Dice" end
        end
        -- Giant Dice: Item ist 7-10 Felder weg
        if distToItem <= 10 and distToItem > 6 then
            if ownedPU("Giant Dice") > 0 then return "Giant Dice" end
        end
        -- Normal Dice: Item ist <= 6 Felder weg
        if distToItem <= 6 then
            if ownedPU("Dice") > 0 then return "Dice" end
        end
        -- Fallback: bester verfuegbarer Wuerfel
        for _, name in ipairs(S.boardDice) do
            if ownedPU(name) > 0 then return name end
        end
        return nil
    end

    local dice = pickDice()
    if not dice then return false end

    local ok, result = pcall(function() return RemoteFn:InvokeServer("RollDice", dice) end)
    if ok and result then
        task.wait(math.max(0.8, (result.Roll or 1) * 0.2))
        pcall(function() RemoteEv:FireServer("ClaimTile") end)
        return true
    end
    task.wait(2)
    return false
end)

-- ═══════════════════════════════════════════════════════════════════
--  BG MODULES
-- ═══════════════════════════════════════════════════════════════════
SEQ.registerBG("Shrines", function()
    if S.shrineOn then
        local d=getData()
        if d then
            local endTime=d.BubbleShrine and d.BubbleShrine.ShrineBlessingEndTime or 0
            if (endTime-now())<1800 and isReady("Shrine") then
                for _, item in ipairs(S.shrineItems) do
                    if not item.enabled then continue end
                    local cnt=0
                    for _, p in ipairs(d.Potions or {}) do
                        if p.Name==item.Name and p.Level==item.Level then cnt=p.Amount or 0 end
                    end
                    if cnt<=0 then continue end
                    pcall(function() RemoteFn:InvokeServer("DonateToShrine",
                        {Type="Potion",Name=item.Name,Level=item.Level,Amount=500}) end)
                    task.wait(0.2)
                end
            end
        end
    end
    if S.dreamerOn then
        local shards=ownedPU("Dream Shard")
        if shards>0 then
            pcall(function() RemoteFn:InvokeServer("DonateToDreamerShrine",math.min(S.dreamerAmt,shards)) end)
            task.wait(0.3)
        end
    end
    if S.goldenOrbOn then
        local d=getData()
        local orbs=d and d.Powerups and (d.Powerups["Golden Orb"] or 0) or 0
        if orbs>0 then pcall(function() Remote:FireServer("UseGoldenOrb") end); task.wait(0.5) end
    end
end)
SEQ._bgModules[#SEQ._bgModules].interval = 5

SEQ.registerBG("Bubbles", function()
    task.wait(0.1)
    if not S.bubbleOn and not (genieBlocking and (function()
        local d=getData()
        local q=d and QuestUtil:FindById(d,"gem-genie")
        if not q then return false end
        for _, t in ipairs(q.Tasks or {}) do if t.Type=="Bubbles" then return true end end
        return false
    end)()) then return end
    pcall(function() RemoteEv:FireServer("BlowBubble") end)
end)
SEQ._bgModules[#SEQ._bgModules].interval = 0.15

SEQ.registerBG("Consumables", function()
    if S.potionOn and not genieBlocking then
        local d=getData(); if d then
            for _, it in ipairs(S.potionItems) do
                if not it.enabled then continue end
                for _, p in ipairs(d.Potions or {}) do
                    if p.Name==it.Name and p.Level==it.Level and p.Amount>0 then
                        pcall(function() RemoteEv:FireServer("UsePotion",it.Name,it.Level) end)
                        task.wait(0.3); break
                    end
                end
            end
        end
    end
    if S.runeOn then
        local d=getData(); if d then
            for _, it in ipairs(S.runeItems) do
                if not it.enabled then continue end
                for _, p in ipairs(d.Potions or {}) do
                    if p.Name==it.Name and p.Level==it.Level and p.Amount>0 then
                        pcall(function() RemoteEv:FireServer("UseRune",it.Name,it.Level,1) end)
                        task.wait(0.3); break
                    end
                end
            end
        end
    end
    if S.eggOn and not genieBlocking then
        local d=getData(); if d then
            for _, it in ipairs(S.eggItems) do
                if not it.enabled then continue end
                local count=(d.Powerups or {})[it.Name] or 0
                if count>0 then
                    pcall(function() RemoteEv:FireServer("HatchPowerupEgg",it.Name,math.min(12,count)) end)
                    task.wait(1)
                end
            end
        end
    end
    if S.boxOn and not genieBlocking then
        local d=getData(); if d then
            local ok2,PI=pcall(function() return require(RS.Client.Effects.PhysicalItem) end)
            if ok2 and PI then
                local oldGift=PI.Gift
                PI.Gift=function(giftId)
                    task.spawn(function() pcall(function() Remote:FireServer("ClaimGift",giftId) end) end)
                    return nil
                end
                pcall(function() RemoteEv:FireServer("SetSetting","Item Notifications",false) end)
                for _, it in ipairs(S.boxItems) do
                    if not it.enabled then continue end
                    local count=(d.Powerups or {})[it.Name] or 0
                    while count>0 do
                        local batch=math.min(count,50)
                        pcall(function() RemoteEv:FireServer("UseGift",it.Name,batch) end)
                        task.wait(0.1); d=getData(); if not d then break end
                        count=(d.Powerups or {})[it.Name] or 0
                    end
                end
                PI.Gift=oldGift
            end
        end
    end
end)
SEQ._bgModules[#SEQ._bgModules].interval = 5

SEQ.registerBG("SpinTickets", function()
    for _, st in ipairs(S.spinTickets) do
        if not st.on then continue end
        local d=getData(); if not d then continue end
        local count=(d.Powerups or {})[st.label] or 0
        if count>0 then
            pcall(function() RemoteFn:InvokeServer(st.invoke) end)
            task.wait(0.5)
            pcall(function() RemoteEv:FireServer(st.claim) end)
            task.wait(1)
        end
    end
end)
SEQ._bgModules[#SEQ._bgModules].interval = 3

for _, wheel in ipairs(S.wheels) do
    local w=wheel
    SEQ.registerBG("Wheel_"..w.label, function()
        if not w.on then return end
        pcall(function() RemoteFn:InvokeServer(w.invoke) end)
        pcall(function() RemoteEv:FireServer(w.claim) end)
    end)
    SEQ._bgModules[#SEQ._bgModules].interval = 2
end

SEQ.registerBG("Fuse", function()
    if not S.fuseOn then return end
    local d=getData(); if not d then return end

    -- Cooldown check
    local cd=(d.NextRebirthMachineUse or 0)-now()
    if cd>0 then task.wait(math.min(cd,10)); return end

    if not FuseUtil then return end
    local NUM_REQ2=FuseUtil.NUM_SECRETS_REQUIRED or 5
    local cands={}
    if d.Pets then
        for _, pet in ipairs(d.Pets) do
            if (pet.Rarity=="Secret" or pet.Type=="Secret") then
                if S.fuseOnlyUnlocked and pet.Locked then continue end
                if S.fuseKeepShiny and pet.Shiny then continue end
                if S.fuseKeepMythic and pet.Mythic then continue end
                table.insert(cands, pet)
            end
        end
    end
    -- Sort by XP ascending (fuse weakest first)
    table.sort(cands, function(a,b) return (a.XP or 0) < (b.XP or 0) end)
    if #cands < NUM_REQ2 then return end

    local ids = {}
    for i=1,NUM_REQ2 do ids[i] = cands[i].Id end

    -- Confirmed remote path:
    -- RemoteFunction:InvokeServer("UseRebirthMachine", {id1, id2, id3, id4, id5})
    local ok, err = pcall(function()
        RemoteFn:InvokeServer("UseRebirthMachine", ids)
    end)
    if not ok then
        warn("[BGS AIO Fuse] Fehler: "..tostring(err))
    end
    task.wait(2)
end)
SEQ._bgModules[#SEQ._bgModules].interval = 8

-- Lock Pets BG Module
SEQ.registerBG("LockPets", function()
    if not S.lockOn then return end
    local d=getData(); if not d or not d.Pets then return end
    for _, pet in ipairs(d.Pets) do
        if not (pet.Rarity=="Secret" or pet.Type=="Secret") then continue end
        if pet.Locked then continue end
        local shouldLock=false
        -- Lock by chance threshold
        if S.lockSecretChanceOn and pet.Chance then
            -- chance is typically stored as 1/X, higher X = rarer
            local chanceVal=pet.Chance or 0
            if chanceVal>=S.lockSecretChance then shouldLock=true end
        end
        -- Lock by exist count threshold
        if S.lockSecretCountOn and pet.ExistCount then
            if pet.ExistCount<=S.lockSecretCount then shouldLock=true end
        end
        if shouldLock then
            pcall(function() RemoteEv:FireServer("LockPet",pet.Id,true) end)
            task.wait(0.2)
        end
    end
end)
SEQ._bgModules[#SEQ._bgModules].interval = 10

-- Farming BG Module
-- Team switching (only one active at a time)
local currentTeam = nil
local _teamToggleSetters = {}  -- {bubble=fn, luck=fn, secretLuck=fn}
local function switchTeam(teamName)
    if not teamName or teamName=="" or teamName==currentTeam then return end
    pcall(function() RemoteEv:FireServer("JoinTeam",teamName) end)
    currentTeam=teamName; task.wait(0.5)
end

-- (team mutual exclusion handled inline in UI)

SEQ.registerBG("TeamManager", function()
    -- Exactly one team toggle active at a time
    if S.farmBubbleTeamOn and S.farmTeamBubble~="" then
        switchTeam(S.farmTeamBubble)
    elseif S.farmLuckTeamOn and S.farmTeamLuck~="" then
        switchTeam(S.farmTeamLuck)
    elseif S.farmSecretLuckTeamOn and S.farmTeamSecretLuck~="" then
        switchTeam(S.farmTeamSecretLuck)
    end
end)
SEQ._bgModules[#SEQ._bgModules].interval = 10

-- Farming Bubble: unified with bubbleOn
SEQ.registerBG("FarmBubbles", function()
    task.wait(0.08)
    if not S.farmBubbleOn then return end
    pcall(function() RemoteEv:FireServer("BlowBubble") end)
end)
SEQ._bgModules[#SEQ._bgModules].interval = 0.15

-- Playtime reward
local _lastPlaytimeClaim = 0
SEQ.registerBG("PlaytimeReward", function()
    if not S.farmPlaytimeOn then return end
    if now()-_lastPlaytimeClaim >= 10 then
        pcall(function() RemoteEv:FireServer("ClaimPlaytimeReward") end)
        _lastPlaytimeClaim = now()
    end
end)
SEQ._bgModules[#SEQ._bgModules].interval = 8

-- Coin collect: TP to Rainbow Egg area, hatch it, collect pickups via UUID remote
SEQ.registerBG("CollectCoins", function()
    if not S.farmCollectCoinsOn then return end
    -- Collect all visible pickups via UUID remote (instant, no TP needed)
    local n = collectAllPickups()
    if n > 0 then task.wait(0.5) end
    -- Also: TP to Rainbow Egg area and hatch (coins spawn from eggs too)
    -- Only do TP hatch every 30s to not spam
    if not S._lastRainbowHatch or (now() - S._lastRainbowHatch) > 30 then
        if S.farmCollectCoinsOn then
            -- Spawn hatch in background so we don't block the BG loop
            task.spawn(function()
                tpToEgg("Rainbow Egg"); task.wait(0.2)
                for _=1,10 do pressE(); task.wait(0.1) end
                -- After hatching, collect spawned pickups
                task.wait(0.5)
                collectAllPickups()
            end)
            S._lastRainbowHatch = now()
        end
    end
end)
SEQ._bgModules[#SEQ._bgModules].interval = 5

-- Automation BG Module
local _autoLockActive = false
SEQ.registerBG("Automation", function()
    local d=getData(); if not d then return end

    -- Auto Box when gems < threshold
    if S.autoBoxGemOn and not _autoLockActive then
        local gems=d.Gems or d.Bubbles or 0
        if gems<S.autoBoxGemThreshold then
            -- Switch to bubble team
            local prevTeam=currentTeam
            if S.farmTeamBubble~="" then switchTeam(S.farmTeamBubble) end
            local ok2,PI=pcall(function() return require(RS.Client.Effects.PhysicalItem) end)
            if ok2 and PI then
                local oldGift=PI.Gift
                PI.Gift=function(giftId)
                    task.spawn(function() pcall(function() Remote:FireServer("ClaimGift",giftId) end) end)
                    return nil
                end
                local opened=0; local maxOpen=200
                repeat
                    d=getData(); if not d then break end
                    gems=d.Gems or d.Bubbles or 0
                    if gems>=S.autoBoxGemThreshold then break end
                    local found=false
                    for _, it in ipairs(S.boxItems) do
                        local count=(d.Powerups or {})[it.Name] or 0
                        if count>0 then
                            local batch=math.min(count,50)
                            pcall(function() RemoteEv:FireServer("UseGift",it.Name,batch) end)
                            opened+=batch; task.wait(0.3); found=true; break
                        end
                    end
                    if not found then break end
                until gems>=S.autoBoxGemThreshold or opened>=maxOpen
                PI.Gift=oldGift
            end
            -- Switch back
            if prevTeam and prevTeam~="" then switchTeam(prevTeam) end
        end
    end

    -- Auto Potion when hatching without potions
    if S.autoPotionHatchOn and S.hatchOn then
        d=getData(); if d then
            local hasPotion=false
            for _, p in ipairs(d.Potions or {}) do
                if p.Name=="Infinity Elixir" or p.Name=="Ultra Infinity Elixir"
                or p.Name=="Secret Elixir" then
                    hasPotion=true
                end
            end
            if not hasPotion then
                local bestOrder={
                    {n="Infinity Elixir",l=1},{n="Ultra Infinity Elixir",l=1},
                    {n="Secret Elixir",l=1},{n="Lucky",l=7},{n="Speed",l=7},{n="Mythic",l=7},
                }
                local function tryUsePotion()
                    for _, combo in ipairs(bestOrder) do
                        for _, p in ipairs(d.Potions or {}) do
                            if p.Name==combo.n and (p.Level or 1)==combo.l and (p.Amount or 0)>=10 then
                                for _=1,10 do
                                    pcall(function() RemoteEv:FireServer("UsePotion",combo.n,combo.l) end)
                                    task.wait(0.1)
                                end
                                return -- break out of both loops
                            end
                        end
                    end
                end
                tryUsePotion()
            end
        end
    end

    -- Auto Reroll Orb fill
    if S.autoRerollOrbOn and not _autoLockActive then
        d=getData(); if d then
            local orbs=(d.Powerups or {})["Reroll Orb"] or 0
            if orbs<S.autoRerollOrbThreshold then
                _autoLockActive=true
                S.autoWarnActive=true
                S.autoWarnMsg="ACHTUNG: Reroll Orbs leer! Oeffne Boxen bis "..S.autoRerollOrbThreshold.."+"
                local ok2,PI=pcall(function() return require(RS.Client.Effects.PhysicalItem) end)
                if ok2 and PI then
                    local oldGift=PI.Gift
                    PI.Gift=function(giftId)
                        task.spawn(function() pcall(function() Remote:FireServer("ClaimGift",giftId) end) end)
                        return nil
                    end
                    repeat
                        d=getData(); if not d then break end
                        orbs=(d.Powerups or {})["Reroll Orb"] or 0
                        if orbs>=S.autoRerollOrbThreshold then break end
                        local found=false
                        for _, it in ipairs(S.boxItems) do
                            local count=(d.Powerups or {})[it.Name] or 0
                            if count>0 then
                                pcall(function() RemoteEv:FireServer("UseGift",it.Name,math.min(50,count)) end)
                                task.wait(0.3); found=true; break
                            end
                        end
                        if not found then break end
                        task.wait(0.2)
                    until orbs>=S.autoRerollOrbThreshold
                    PI.Gift=oldGift
                end
                _autoLockActive=false
                S.autoWarnActive=false; S.autoWarnMsg=""
            end
        end
    end
end)
SEQ._bgModules[#SEQ._bgModules].interval = 8

SEQ.registerBG("Daily", function()
    local d=getData(); if not d then return end
    if S.dailyReward and now()-(d.DailyReward and d.DailyReward.LastClaim or 0)>=86400 then
        pcall(function() RemoteEv:FireServer("ClaimDailyReward") end); task.wait(2)
    end
    if S.dailyPerk and d.DailyPerks and not d.DailyPerks.Claimed then
        pcall(function() RemoteEv:FireServer("SelectDailyPerk",1) end); task.wait(2)
    end
    -- ClaimSeason (season pass passive claim)
    if S.spOn then
        pcall(function() RemoteEv:FireServer("ClaimSeason") end)
    end
end)
SEQ._bgModules[#SEQ._bgModules].interval = 60

-- Hide hatch animation: destroy HatchGui/animation frames as they appear
SEQ.registerBG("HideHatchAnim", function()
    task.wait(0.05)
    if not S.hideHatchAnimOn then return end
    local pg = LP.PlayerGui
    for _, g in ipairs(pg:GetChildren()) do
        local n = g.Name:lower()
        if n:find("hatch") or n:find("egg") or n:find("hatchanim") or n:find("petegg") then
            if g:IsA("ScreenGui") or g:IsA("Frame") then
                g.Enabled = false
            end
        end
    end
end)
SEQ._bgModules[#SEQ._bgModules].interval = 10

-- Auto Collect Pickups (UUID remote, no TP)
SEQ.registerBG("AutoCollectPickup", function()
    task.wait(0.5)
    if not S.autoCollectPickupOn then return end
    collectAllPickups()
end)
SEQ._bgModules[#SEQ._bgModules].interval = 3

-- Bubble Sell Priority: detect when sell is happening, block sequencer briefly
local _bubbleSellBlocking = false
SEQ.registerBG("BubbleSellPriority", function()
    if not S.bubbleSellPriorityOn then return end
    local d=getData(); if not d then return end
    -- Check if player has full bubbles / sell is imminent
    -- BGSI fires "SellBubbles" or uses AutoSell when bubbles cap
    -- We detect via a RemoteEvent hook
    -- For now: block sequencer for 3s if we detect sell just happened
    -- (The actual detection is via monkey-patching the sell remote response)
end)
SEQ._bgModules[#SEQ._bgModules].interval = 2

-- Monkey-patch sell remote to detect bubble sells and block sequencer
task.spawn(function()
    task.wait(3)
    if not Remote then return end
    local origEvent = Remote.Event
    if not origEvent then return end
    pcall(function()
        Remote.Event("SellBubbles"):Connect(function()
            if S.bubbleSellPriorityOn then
                SEQ._blocked = true
                task.wait(3)
                SEQ._blocked = false
            end
        end)
        Remote.Event("AutoSell"):Connect(function()
            if S.bubbleSellPriorityOn then
                SEQ._blocked = true
                task.wait(2)
                SEQ._blocked = false
            end
        end)
    end)
end)

-- Auto-sort after registration
resortModules(S)

-- ═══════════════════════════════════════════════════════════════════
--  START SEQUENCER
-- ═══════════════════════════════════════════════════════════════════
SEQ.start()

-- Auto-save
task.spawn(function()
    while true do task.wait(30)
        if S.autosaveOn then saveConfig(S) end
    end
end)

-- ═══════════════════════════════════════════════════════════════════
--  UI
-- ═══════════════════════════════════════════════════════════════════
local function tw(o,p,t)
    TS:Create(o,TweenInfo.new(t or 0.14,Enum.EasingStyle.Quint),p):Play()
end
local function onClick(btn,fn)
    btn.InputBegan:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 then fn()
        elseif input.UserInputType==Enum.UserInputType.Touch then
            local startPos=input.Position; local moved=false; local moveConn
            moveConn=input.Changed:Connect(function()
                if (input.Position-startPos).Magnitude>10 then moved=true; moveConn:Disconnect() end
            end)
            input.Changed:Connect(function()
                if input.UserInputState==Enum.UserInputState.End then
                    moveConn:Disconnect(); if not moved then fn() end
                end
            end)
        end
    end)
end

local C = {
    bg=Color3.fromRGB(11,11,17), sur=Color3.fromRGB(19,19,28),
    elv=Color3.fromRGB(27,27,40), brd=Color3.fromRGB(44,44,66),
    acc=Color3.fromRGB(99,102,241), grn=Color3.fromRGB(72,194,108),
    red=Color3.fromRGB(220,80,80), tp=Color3.fromRGB(228,228,240),
    ts=Color3.fromRGB(108,108,142), off=Color3.fromRGB(38,38,56),
    warn=Color3.fromRGB(255,180,0),
    rar={
        Common=Color3.fromRGB(255,255,255), Unique=Color3.fromRGB(255,196,148),
        Rare=Color3.fromRGB(255,94,94), Epic=Color3.fromRGB(207,98,255),
        Legendary=Color3.fromRGB(255,213,0), Secret=Color3.fromRGB(255,22,211),
    },
}
local W=340

local SG=Instance.new("ScreenGui",LP.PlayerGui)
SG.Name="BGS_AIO"; SG.ResetOnSpawn=false; SG.IgnoreGuiInset=true
SG.ZIndexBehavior=Enum.ZIndexBehavior.Sibling

local win=Instance.new("Frame",SG)
win.Size=UDim2.new(0,W,0,44); win.Position=UDim2.new(0,14,0.5,-256)
win.BackgroundColor3=C.bg; win.BorderSizePixel=0; win.Active=true; win.Draggable=true
Instance.new("UICorner",win).CornerRadius=UDim.new(0,13)
local ws=Instance.new("UIStroke",win); ws.Color=C.brd; ws.Thickness=1

local tb=Instance.new("Frame",win); tb.Size=UDim2.new(1,0,0,44)
tb.BackgroundColor3=C.sur; tb.BorderSizePixel=0
Instance.new("UICorner",tb).CornerRadius=UDim.new(0,13)
local tbFix=Instance.new("Frame",tb); tbFix.Size=UDim2.new(1,0,0,13)
tbFix.Position=UDim2.new(0,0,1,-13); tbFix.BackgroundColor3=C.sur; tbFix.BorderSizePixel=0

local ttl=Instance.new("TextLabel",tb)
ttl.Size=UDim2.new(1,-76,1,0); ttl.Position=UDim2.new(0,13,0,0)
ttl.BackgroundTransparency=1; ttl.Text="BGS Infinity AIO v0.7.3"
ttl.TextColor3=C.tp; ttl.Font=Enum.Font.GothamBold; ttl.TextSize=12
ttl.TextXAlignment=Enum.TextXAlignment.Left

local mBtn=Instance.new("TextButton",tb)
mBtn.Size=UDim2.new(0,24,0,24); mBtn.Position=UDim2.new(1,-34,0.5,-12)
mBtn.BackgroundColor3=C.elv; mBtn.BorderSizePixel=0
mBtn.Text="-"; mBtn.TextColor3=C.ts; mBtn.Font=Enum.Font.GothamBold; mBtn.TextSize=14
Instance.new("UICorner",mBtn).CornerRadius=UDim.new(0,6)

-- Warning banner
local warnBanner=Instance.new("Frame",SG)
warnBanner.Size=UDim2.new(0,400,0,40); warnBanner.Position=UDim2.new(0.5,-200,0,10)
warnBanner.BackgroundColor3=C.warn; warnBanner.BorderSizePixel=0; warnBanner.Visible=false
warnBanner.ZIndex=200
Instance.new("UICorner",warnBanner).CornerRadius=UDim.new(0,8)
local warnLbl=Instance.new("TextLabel",warnBanner)
warnLbl.Size=UDim2.new(1,-10,1,0); warnLbl.Position=UDim2.new(0,5,0,0)
warnLbl.BackgroundTransparency=1; warnLbl.TextColor3=Color3.fromRGB(0,0,0)
warnLbl.Font=Enum.Font.GothamBold; warnLbl.TextSize=11; warnLbl.TextWrapped=true
warnLbl.Text=""; warnLbl.ZIndex=201
task.spawn(function()
    while true do task.wait(0.5)
        warnBanner.Visible=S.autoWarnActive
        warnLbl.Text=S.autoWarnMsg
    end
end)

-- Tab bar (scrollable, 2 rows for many tabs)
local TH=33
local tabBar=Instance.new("Frame",win); tabBar.Size=UDim2.new(1,0,0,TH)
tabBar.Position=UDim2.new(0,0,0,44); tabBar.BackgroundColor3=Color3.fromRGB(14,14,21)
tabBar.BorderSizePixel=0; tabBar.ClipsDescendants=true
local tabLine=Instance.new("Frame",tabBar); tabLine.Size=UDim2.new(0,2,0,2)
tabLine.Position=UDim2.new(0,0,1,-2); tabLine.BackgroundColor3=C.acc; tabLine.BorderSizePixel=0

-- Scrollable tab bar
local tabScroll=Instance.new("ScrollingFrame",tabBar)
tabScroll.Size=UDim2.new(1,0,1,0); tabScroll.BackgroundTransparency=1
tabScroll.BorderSizePixel=0; tabScroll.ScrollBarThickness=2
tabScroll.ScrollBarImageColor3=C.brd; tabScroll.CanvasSize=UDim2.new(0,0,0,0)
tabScroll.AutomaticCanvasSize=Enum.AutomaticSize.X
tabScroll.ScrollingDirection=Enum.ScrollingDirection.X

local cnt=Instance.new("Frame",win); cnt.Size=UDim2.new(1,0,1,-77)
cnt.Position=UDim2.new(0,0,0,77); cnt.BackgroundTransparency=1; cnt.ClipsDescendants=true

local tabs,activeTab,minimized={},nil,false

local function recalcHeight()
    if minimized or not activeTab then return end
    local lay=activeTab.s:FindFirstChildOfClass("UIListLayout")
    if lay then tw(win,{Size=UDim2.new(0,W,0,math.min(lay.AbsoluteContentSize.Y+77+13,560))},0.16) end
end

-- Tab definitions
local TAB_DEF={
    "MG","Fish","Eggs","Board","Wheel","Shrine","Fuse","Genie",
    "Consum","Spins","Rifts","Farming","SP","LockPets",
    "Priority","Milestones","Auto","Profiles","Comp",
}
local TAB_W=42  -- fixed width per tab
local pages={}

local function mkScroll()
    local s=Instance.new("ScrollingFrame",cnt)
    s.Size=UDim2.new(1,0,1,0); s.BackgroundTransparency=1
    s.BorderSizePixel=0; s.ScrollBarThickness=3
    s.ScrollBarImageColor3=C.brd; s.CanvasSize=UDim2.new(0,0,0,0)
    s.AutomaticCanvasSize=Enum.AutomaticSize.Y; s.Visible=false
    local l=Instance.new("UIListLayout",s); l.Padding=UDim.new(0,5)
    local p=Instance.new("UIPadding",s)
    p.PaddingLeft=UDim.new(0,10); p.PaddingRight=UDim.new(0,10)
    p.PaddingTop=UDim.new(0,8); p.PaddingBottom=UDim.new(0,10)
    return s
end

for i,lbl in ipairs(TAB_DEF) do
    local btn=Instance.new("TextButton",tabScroll)
    btn.Size=UDim2.new(0,TAB_W,1,0); btn.Position=UDim2.new(0,(i-1)*TAB_W,0,0)
    btn.BackgroundTransparency=1; btn.Text=lbl; btn.TextSize=8
    btn.Font=Enum.Font.GothamBold; btn.TextColor3=C.ts
    local scroll=mkScroll()
    local tab={btn=btn,s=scroll,lb=btn,i=i}
    tabs[i]=tab; pages[lbl]=scroll
    scroll:FindFirstChildOfClass("UIListLayout"):GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        if activeTab==tab then recalcHeight() end
    end)
    onClick(btn,function()
        if activeTab==tab then return end
        if activeTab then activeTab.s.Visible=false; tw(activeTab.lb,{TextColor3=C.ts}) end
        activeTab=tab; scroll.Visible=true
        tw(btn,{TextColor3=C.acc})
        tw(tabLine,{Size=UDim2.new(0,TAB_W,0,2),Position=UDim2.new(0,(i-1)*TAB_W,1,-2)})
        recalcHeight()
    end)
end

local function setMinimized(v)
    minimized=v; mBtn.Text=v and "+" or "-"
    cnt.Visible=not v; tabBar.Visible=not v
    tw(win,{Size=UDim2.new(0,W,0,44)},0.15)
    if not v and activeTab then recalcHeight() end
end
onClick(mBtn,function() setMinimized(not minimized) end)

-- ── UI Helpers ──────────────────────────────────────────────────────
local function mkSec(parent,txt)
    local f=Instance.new("Frame",parent); f.Size=UDim2.new(1,0,0,22)
    f.BackgroundColor3=Color3.fromRGB(14,14,21); f.BorderSizePixel=0
    Instance.new("UICorner",f).CornerRadius=UDim.new(0,5)
    local l=Instance.new("TextLabel",f); l.Size=UDim2.new(1,-10,1,0)
    l.Position=UDim2.new(0,8,0,0); l.BackgroundTransparency=1; l.Text=txt
    l.TextColor3=C.ts; l.Font=Enum.Font.GothamBold; l.TextSize=9
    l.TextXAlignment=Enum.TextXAlignment.Left
    return f
end

local function mkToggle(parent,label,sub,init,dot,onChange)
    local row=Instance.new("Frame",parent); row.Size=UDim2.new(1,0,0,36)
    row.BackgroundColor3=C.elv; row.BorderSizePixel=0
    Instance.new("UICorner",row).CornerRadius=UDim.new(0,7)
    if dot then
        local d=Instance.new("Frame",row); d.Size=UDim2.new(0,4,1,0)
        d.BackgroundColor3=dot; d.BorderSizePixel=0
        Instance.new("UICorner",d).CornerRadius=UDim.new(0,4)
    end
    local lbl=Instance.new("TextLabel",row); lbl.Size=UDim2.new(1,-54,0,18)
    lbl.Position=UDim2.new(0,10,0,5); lbl.BackgroundTransparency=1; lbl.Text=label
    lbl.TextColor3=C.tp; lbl.Font=Enum.Font.GothamBold; lbl.TextSize=11
    lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.TextTruncate=Enum.TextTruncate.AtEnd
    lbl.Active=false; lbl.Interactable=false
    local sub2=Instance.new("TextLabel",row); sub2.Size=UDim2.new(1,-54,0,11)
    sub2.Position=UDim2.new(0,10,0,21); sub2.BackgroundTransparency=1; sub2.Text=sub or ""
    sub2.TextColor3=C.ts; sub2.Font=Enum.Font.Gotham; sub2.TextSize=9
    sub2.TextXAlignment=Enum.TextXAlignment.Left; sub2.TextTruncate=Enum.TextTruncate.AtEnd
    sub2.Active=false; sub2.Interactable=false
    local on=init or false
    local sw=Instance.new("Frame",row); sw.Size=UDim2.new(0,34,0,18)
    sw.Position=UDim2.new(1,-42,0.5,-9); sw.BorderSizePixel=0
    sw.BackgroundColor3=on and C.grn or C.off
    Instance.new("UICorner",sw).CornerRadius=UDim.new(0,9)
    local knob=Instance.new("Frame",sw); knob.Size=UDim2.new(0,14,0,14)
    knob.Position=on and UDim2.new(1,-16,0.5,-7) or UDim2.new(0,2,0.5,-7)
    knob.BackgroundColor3=Color3.new(1,1,1); knob.BorderSizePixel=0
    Instance.new("UICorner",knob).CornerRadius=UDim.new(0,7)
    local function setOn(v)
        on=v; tw(sw,{BackgroundColor3=v and C.grn or C.off})
        tw(knob,{Position=v and UDim2.new(1,-16,0.5,-7) or UDim2.new(0,2,0.5,-7)})
        if onChange then onChange(v) end
    end
    local clickBtn=Instance.new("TextButton",row)
    clickBtn.Size=UDim2.new(1,0,1,0); clickBtn.BackgroundTransparency=1
    clickBtn.Text=""; clickBtn.ZIndex=2
    onClick(clickBtn,function() setOn(not on) end)
    return row,setOn
end

local function mkStat(parent,txt)
    local f=Instance.new("Frame",parent); f.Size=UDim2.new(1,0,0,32)
    f.BackgroundColor3=Color3.fromRGB(14,14,21); f.BorderSizePixel=0
    Instance.new("UICorner",f).CornerRadius=UDim.new(0,6)
    local l=Instance.new("TextLabel",f); l.Size=UDim2.new(1,-10,1,0)
    l.Position=UDim2.new(0,8,0,0); l.BackgroundTransparency=1; l.Text=txt
    l.TextColor3=C.ts; l.Font=Enum.Font.Gotham; l.TextSize=9
    l.TextXAlignment=Enum.TextXAlignment.Left; l.TextWrapped=true
    l.AutomaticSize=Enum.AutomaticSize.Y; f.AutomaticSize=Enum.AutomaticSize.Y
    return l
end

local activeDropOverlay=nil
local function closeActiveOverlay()
    if activeDropOverlay then activeDropOverlay:Destroy(); activeDropOverlay=nil end
end

-- FIXED mkDrop: label is always shown as "Name: selection"
local function mkDrop(parent,id,values,default,onChange,getValuesFn,labelPrefix)
    local row=Instance.new("Frame",parent); row.Size=UDim2.new(1,0,0,32)
    row.BackgroundColor3=C.elv; row.BorderSizePixel=0; row.Name="Drop_"..id
    Instance.new("UICorner",row).CornerRadius=UDim.new(0,7)
    local prefix=(labelPrefix and (labelPrefix..": ")) or ""
    local lbl=Instance.new("TextButton",row); lbl.Size=UDim2.new(1,-8,1,0)
    lbl.Position=UDim2.new(0,8,0,0); lbl.BackgroundTransparency=1
    lbl.Text="v  "..prefix..tostring(default); lbl.TextColor3=C.tp
    lbl.Font=Enum.Font.Gotham; lbl.TextSize=10; lbl.TextXAlignment=Enum.TextXAlignment.Left
    onClick(lbl,function()
        if activeDropOverlay then closeActiveOverlay(); return end
        local vals=getValuesFn and getValuesFn() or values
        local overlay=Instance.new("Frame",SG)
        overlay.Size=UDim2.new(1,0,1,0); overlay.BackgroundTransparency=1
        overlay.ZIndex=100; activeDropOverlay=overlay
        local bg=Instance.new("TextButton",overlay)
        bg.Size=UDim2.new(1,0,1,0); bg.BackgroundTransparency=1
        bg.Text=""; bg.ZIndex=100
        onClick(bg,function() closeActiveOverlay() end)
        local absPos=lbl.AbsolutePosition; local absSize=lbl.AbsoluteSize
        local dropH=math.min(#vals,8)*26+4
        local dropFrame=Instance.new("Frame",overlay)
        dropFrame.Size=UDim2.new(0,absSize.X+8,0,dropH)
        dropFrame.Position=UDim2.new(0,absPos.X-8,0,absPos.Y+absSize.Y+2)
        dropFrame.BackgroundColor3=C.sur; dropFrame.BorderSizePixel=0; dropFrame.ZIndex=101
        Instance.new("UICorner",dropFrame).CornerRadius=UDim.new(0,7)
        Instance.new("UIStroke",dropFrame).Color=C.brd
        local dScroll=Instance.new("ScrollingFrame",dropFrame)
        dScroll.Size=UDim2.new(1,0,1,0); dScroll.BackgroundTransparency=1
        dScroll.BorderSizePixel=0; dScroll.ScrollBarThickness=3
        dScroll.ScrollBarImageColor3=C.brd; dScroll.CanvasSize=UDim2.new(0,0,0,0)
        dScroll.AutomaticCanvasSize=Enum.AutomaticSize.Y; dScroll.ZIndex=101
        local layout=Instance.new("UIListLayout",dScroll); layout.Padding=UDim.new(0,2)
        local pad=Instance.new("UIPadding",dScroll)
        pad.PaddingLeft=UDim.new(0,4); pad.PaddingRight=UDim.new(0,4)
        pad.PaddingTop=UDim.new(0,2); pad.PaddingBottom=UDim.new(0,2)
        for _, v in ipairs(vals) do
            local btn=Instance.new("TextButton",dScroll)
            btn.Size=UDim2.new(1,0,0,24); btn.BackgroundColor3=C.elv
            btn.BorderSizePixel=0; btn.Text="  "..tostring(v); btn.TextColor3=C.tp
            btn.Font=Enum.Font.Gotham; btn.TextSize=10
            btn.TextXAlignment=Enum.TextXAlignment.Left; btn.ZIndex=102
            Instance.new("UICorner",btn).CornerRadius=UDim.new(0,5)
            onClick(btn,function()
                lbl.Text="v  "..prefix..tostring(v)
                closeActiveOverlay()
                if onChange then onChange(v) end
            end)
        end
        activeDropOverlay=overlay
    end)
    return row,lbl
end

local function mkNumberInput(parent,label,initVal,minV,maxV,onChange)
    local row=Instance.new("Frame",parent); row.Size=UDim2.new(1,0,0,46)
    row.BackgroundColor3=C.elv; row.BorderSizePixel=0
    Instance.new("UICorner",row).CornerRadius=UDim.new(0,7)
    local rs=Instance.new("UIStroke",row); rs.Color=C.brd; rs.Thickness=1; rs.Transparency=0.5
    local lbl=Instance.new("TextLabel",row); lbl.Size=UDim2.new(1,-80,1,0)
    lbl.Position=UDim2.new(0,10,0,0); lbl.BackgroundTransparency=1; lbl.Text=label
    lbl.TextColor3=C.tp; lbl.Font=Enum.Font.Gotham; lbl.TextSize=11
    lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.TextTruncate=Enum.TextTruncate.AtEnd
    lbl.Active=false; lbl.Interactable=false
    local minus=Instance.new("TextButton",row)
    minus.Size=UDim2.new(0,24,0,24); minus.Position=UDim2.new(1,-78,0.5,-12)
    minus.BackgroundColor3=C.off; minus.BorderSizePixel=0
    minus.Text="-"; minus.TextColor3=C.ts; minus.Font=Enum.Font.GothamBold; minus.TextSize=14
    Instance.new("UICorner",minus).CornerRadius=UDim.new(0,6)
    local box=Instance.new("TextBox",row)
    box.Size=UDim2.new(0,36,0,24); box.Position=UDim2.new(1,-50,0.5,-12)
    box.BackgroundColor3=C.off; box.BorderSizePixel=0
    box.Text=tostring(initVal); box.TextColor3=C.acc
    box.Font=Enum.Font.GothamBold; box.TextSize=12
    box.TextXAlignment=Enum.TextXAlignment.Center
    Instance.new("UICorner",box).CornerRadius=UDim.new(0,6)
    local plus=Instance.new("TextButton",row)
    plus.Size=UDim2.new(0,24,0,24); plus.Position=UDim2.new(1,-22,0.5,-12)
    plus.BackgroundColor3=C.off; plus.BorderSizePixel=0
    plus.Text="+"; plus.TextColor3=C.ts; plus.Font=Enum.Font.GothamBold; plus.TextSize=14
    Instance.new("UICorner",plus).CornerRadius=UDim.new(0,6)
    local value=initVal
    local function setValue(v)
        value=math.clamp(math.floor(tonumber(v) or 0),minV,maxV)
        box.Text=tostring(value); if onChange then onChange(value) end
    end
    minus.MouseButton1Click:Connect(function() setValue(value-1) end)
    plus.MouseButton1Click:Connect(function() setValue(value+1) end)
    box.FocusLost:Connect(function() setValue(tonumber(box.Text) or value) end)
    box.Focused:Connect(function() tw(rs,{Color=C.acc,Transparency=0}) end)
    box.FocusLost:Connect(function() tw(rs,{Color=C.brd,Transparency=0.5}) end)
    return row,setValue
end

-- TextInput helper
local function mkTextInput(parent,label,init,onChange)
    local row=Instance.new("Frame",parent); row.Size=UDim2.new(1,0,0,46)
    row.BackgroundColor3=C.elv; row.BorderSizePixel=0
    Instance.new("UICorner",row).CornerRadius=UDim.new(0,7)
    local lbl=Instance.new("TextLabel",row); lbl.Size=UDim2.new(1,0,0,18)
    lbl.Position=UDim2.new(0,10,0,3); lbl.BackgroundTransparency=1; lbl.Text=label
    lbl.TextColor3=C.ts; lbl.Font=Enum.Font.Gotham; lbl.TextSize=9
    lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.Active=false; lbl.Interactable=false
    local box=Instance.new("TextBox",row)
    box.Size=UDim2.new(1,-20,0,22); box.Position=UDim2.new(0,10,0,20)
    box.BackgroundColor3=C.off; box.BorderSizePixel=0
    box.Text=init or ""; box.TextColor3=C.tp
    box.Font=Enum.Font.Gotham; box.TextSize=11
    box.TextXAlignment=Enum.TextXAlignment.Left; box.PlaceholderText="..."
    Instance.new("UICorner",box).CornerRadius=UDim.new(0,5)
    box.FocusLost:Connect(function() if onChange then onChange(box.Text) end end)
    return row,box
end

-- SEQ status badge
local seqLabel=Instance.new("TextLabel",tb)
seqLabel.Size=UDim2.new(0,55,1,0); seqLabel.Position=UDim2.new(1,-95,0,0)
seqLabel.BackgroundTransparency=1; seqLabel.TextColor3=C.ts
seqLabel.Font=Enum.Font.Gotham; seqLabel.TextSize=8
seqLabel.TextXAlignment=Enum.TextXAlignment.Right; seqLabel.Text=""
task.spawn(function()
    while true do task.wait(1)
        seqLabel.Text="SEQ:"..#SEQ._tpModules.."m"
    end
end)

-- ═══════════════════════════════════════════════════════════════════
--  TAB CONTENTS
-- ═══════════════════════════════════════════════════════════════════

-- ── MINIGAMES ──────────────────────────────────────────────────────
local pMG=pages["MG"]
mkSec(pMG,"Schwierigkeit")
do
    local DIFF_C={Easy=C.grn,Normal=Color3.fromRGB(255,213,0),Hard=Color3.fromRGB(255,140,0),Insane=Color3.fromRGB(190,65,230)}
    local opts={"Easy","Normal","Hard","Insane"}; local cur=S.mgDiff; local open=false; local IH=32
    local wrap=Instance.new("Frame",pMG); wrap.Size=UDim2.new(1,0,0,44)
    wrap.BackgroundColor3=C.elv; wrap.BorderSizePixel=0; wrap.ClipsDescendants=true
    Instance.new("UICorner",wrap).CornerRadius=UDim.new(0,8)
    local wss=Instance.new("UIStroke",wrap); wss.Color=C.brd; wss.Thickness=1
    local vLbl=Instance.new("TextLabel",wrap); vLbl.Size=UDim2.new(1,-50,0,18)
    vLbl.Position=UDim2.new(0,12,0,6); vLbl.BackgroundTransparency=1; vLbl.Text=cur
    vLbl.TextColor3=DIFF_C[cur] or C.acc; vLbl.Font=Enum.Font.GothamBold; vLbl.TextSize=12
    vLbl.TextXAlignment=Enum.TextXAlignment.Left
    local sub2=Instance.new("TextLabel",wrap); sub2.Size=UDim2.new(1,-50,0,12)
    sub2.Position=UDim2.new(0,12,0,25); sub2.BackgroundTransparency=1; sub2.Text="Schwierigkeit"
    sub2.TextColor3=C.ts; sub2.Font=Enum.Font.Gotham; sub2.TextSize=9; sub2.TextXAlignment=Enum.TextXAlignment.Left
    local chev=Instance.new("TextLabel",wrap); chev.Size=UDim2.new(0,18,0,18); chev.Position=UDim2.new(1,-26,0,13)
    chev.BackgroundTransparency=1; chev.Text="v"; chev.TextColor3=C.ts; chev.Font=Enum.Font.GothamBold; chev.TextSize=13
    for i,opt in ipairs(opts) do
        local item=Instance.new("TextButton",wrap); item.Size=UDim2.new(1,0,0,IH)
        item.Position=UDim2.new(0,0,0,45+(i-1)*IH); item.BackgroundTransparency=1; item.Text=""
        local iLbl=Instance.new("TextLabel",item); iLbl.Size=UDim2.new(1,-12,1,0); iLbl.Position=UDim2.new(0,12,0,0)
        iLbl.BackgroundTransparency=1; iLbl.Text=opt; iLbl.TextColor3=opt==cur and (DIFF_C[opt] or C.acc) or C.ts
        iLbl.Font=opt==cur and Enum.Font.GothamBold or Enum.Font.Gotham; iLbl.TextSize=11; iLbl.TextXAlignment=Enum.TextXAlignment.Left
        onClick(item,function()
            cur=opt; S.mgDiff=opt; vLbl.Text=opt; vLbl.TextColor3=DIFF_C[opt] or C.acc
            for _,ch in ipairs(wrap:GetChildren()) do
                if ch:IsA("TextButton") then
                    local cl=ch:FindFirstChildOfClass("TextLabel")
                    if cl then cl.TextColor3=cl.Text==opt and (DIFF_C[opt] or C.acc) or C.ts
                    cl.Font=cl.Text==opt and Enum.Font.GothamBold or Enum.Font.Gotham end
                end
            end
            open=false; tw(wrap,{Size=UDim2.new(1,0,0,44)}); tw(chev,{Rotation=0}); tw(wss,{Color=C.brd})
        end)
    end
    local hbtn=Instance.new("TextButton",wrap); hbtn.Size=UDim2.new(1,0,0,44)
    hbtn.BackgroundTransparency=1; hbtn.Text=""; hbtn.ZIndex=3
    onClick(hbtn,function()
        open=not open
        tw(wrap,{Size=UDim2.new(1,0,0,open and 45+#opts*IH or 44)})
        tw(chev,{Rotation=open and 180 or 0}); tw(wss,{Color=open and C.acc or C.brd})
    end)
end
mkSec(pMG,"Minigames")
for name,data in pairs(MG_Data or {}) do
    mkToggle(pMG,name,math.floor((data.Cooldown or 300)/60).."m CD",false,nil,function(v) S.mg[name]=v end)
end
mkSec(pMG,"Optionen")
mkToggle(pMG,"Super Ticket","Cooldown skippen",S.mgTicket,nil,function(v) S.mgTicket=v end)
mkSec(pMG,"Claw Prioritaet")
do
    mkNumberInput(pMG,"Grab Count",S.clawMax,1,9999,function(v) S.clawMax=v end)
    for _,iName in ipairs({"Dragon Plushie","Secret Elixir","Infinity Elixir","Rift Charm",
        "Super Key","Super Ticket","Lucky","Mythic","Speed","Tickets","Golden Dice","Dice Key","Giant Dice","Dice"}) do
        local n=iName
        mkNumberInput(pMG,n,S.clawPrio[n] or 0,0,9999,function(v) S.clawPrio[n]=v end)
    end
end
mkSec(pMG,"Status")
local sMG=mkStat(pMG,"Inaktiv")
task.spawn(function() while true do task.wait(2)
    local d=getData(); if not d then continue end; local ln={}
    for n,en in pairs(S.mg) do if en then
        local cd=((d.Cooldowns and d.Cooldowns[n]) or 0)-now()
        table.insert(ln,cd>0 and ("CD "..n..": "..math.ceil(cd).."s") or ("OK "..n))
    end end
    sMG.Text=#ln>0 and table.concat(ln,"\n") or "Kein MG aktiv"
end end)

-- ── FISHING ────────────────────────────────────────────────────────
local pFish=pages["Fish"]
mkSec(pFish,"Modus")
mkToggle(pFish,"Auto Fish","TP + AutoFish",false,nil,function(v)
    S.fishOn=v; if not v then setAF(false); S.fishAreaLast=nil end
end)
mkToggle(pFish,"Sailor Quest","Wechselt zur Quest-Area",false,nil,function(v)
    S.fishQuest=v; S.fishAreaLast=nil
end)
mkSec(pFish,"Area")
do
    local aN,aBL={},{}
    for k,d in pairs(FishAreas_Data or {}) do
        local lb=d.DisplayName or k; table.insert(aN,lb); aBL[lb]=k
    end
    table.sort(aN,function(a,b)
        return ((FishAreas_Data[aBL[a]] or {}).DisplayOrder or 99)
             < ((FishAreas_Data[aBL[b]] or {}).DisplayOrder or 99)
    end)
    mkDrop(pFish,"Area",aN,aN[1] or "Starter",function(v)
        S.fishArea=aBL[v] or "starter"; S.fishAreaLast=nil
    end,nil,"Area")
end
mkSec(pFish,"Bait Queue")
for key,bd in pairs(Bait_Data or {}) do
    local col=C.rar[bd.Rarity] or C.rar.Common
    mkToggle(pFish,bd.DisplayName or key,bd.Rarity or "Common",false,col,function(v)
        S.baits[bd.DisplayName or key]=v
    end)
end
mkSec(pFish,"Status")
local sFish=mkStat(pFish,"Inaktiv")
task.spawn(function() while true do task.wait(2)
    if not S.fishOn then sFish.Text="Inaktiv"
    elseif S.fishQuest then sFish.Text="Quest > "..(questArea() or "suche...")
    else sFish.Text="Fischt: "..S.fishArea end
end end)

-- ── EGGS ───────────────────────────────────────────────────────────
-- ── EGGS ───────────────────────────────────────────────────────────
local pEgg=pages["Eggs"]

-- ── Sektion 1: Priority Slots ──
mkSec(pEgg,"Prioritaets-Eggs")
do
    local noneOpt = "(none)"
    local slotOpts = {noneOpt}
    for _,n in ipairs(ALL_WORLD_EGGS) do table.insert(slotOpts, n) end

    -- ensure 4 slots
    while #S.hatchPrio < 4 do table.insert(S.hatchPrio, nil) end

    local dropRefs = {}
    for i=1,4 do
        local si = i
        local cur = S.hatchPrio[si] or noneOpt
        local _, dLbl = mkDrop(pEgg, "hprio"..si, slotOpts, cur, function(sel)
            S.hatchPrio[si] = (sel==noneOpt) and nil or sel
            if dropRefs[si] then dropRefs[si].Text = "v  Slot "..si..": "..(S.hatchPrio[si] or "none") end
        end, function() return slotOpts end, "Slot "..i)
        dropRefs[i] = dLbl
        if dLbl then dLbl.Text = "v  Slot "..i..": "..cur end
    end
end

-- ── Trennlinie ──
mkSec(pEgg,"---")

-- ── Sektion 2: Base Egg ──
mkSec(pEgg,"Base Egg")
do
    mkDrop(pEgg, "baseEgg", ALL_WORLD_EGGS, S.hatchEgg, function(sel)
        S.hatchEgg = sel
    end, function() return ALL_WORLD_EGGS end, "Egg")
end
mkToggle(pEgg, "Auto Hatch", "TP + E-Spam", S.hatchOn, nil, function(v) S.hatchOn=v end)
mkToggle(pEgg, "Prioritaet aktiv", "Slot 1-4 vor Base Egg", S.hatchPrioOn, nil, function(v) S.hatchPrioOn=v end)

-- ── Trennlinie ──
mkSec(pEgg,"---")

-- ── Sektion 3: Inventory Eggs (Multiselect Dropdown) ──
mkSec(pEgg,"Inventory Eggs")
mkToggle(pEgg, "Auto Hatch Inventory", "Ausgewaehlte Eggs aus Inventory", S.eggOn, nil, function(v) S.eggOn=v end)
do
    -- Multiselect: eine Dropdown die beim Waehlen togglet ob das Egg aktiv ist
    -- Zeigt aktive Eggs als Label an
    local selectedNames = {}
    -- Aus S.eggItems laden
    for _, it in ipairs(S.eggItems) do
        if it.enabled then selectedNames[it.Name] = true end
    end

    -- Anzeige-Label fuer aktuell selektierte
    local selDisplay = Instance.new("TextLabel", pEgg)
    selDisplay.Size = UDim2.new(1,0,0,0)
    selDisplay.AutomaticSize = Enum.AutomaticSize.Y
    selDisplay.BackgroundColor3 = C.elv; selDisplay.BorderSizePixel = 0
    selDisplay.TextColor3 = C.ts; selDisplay.Font = Enum.Font.Gotham; selDisplay.TextSize = 9
    selDisplay.TextWrapped = true; selDisplay.TextXAlignment = Enum.TextXAlignment.Left
    selDisplay.Text = "Keine ausgewaehlt"
    local lpad = Instance.new("UIPadding", selDisplay)
    lpad.PaddingLeft = UDim.new(0,8); lpad.PaddingRight = UDim.new(0,8)
    lpad.PaddingTop = UDim.new(0,4); lpad.PaddingBottom = UDim.new(0,4)
    Instance.new("UICorner", selDisplay).CornerRadius = UDim.new(0,6)

    local function updateSelDisplay()
        local names = {}
        for n, v in pairs(selectedNames) do if v then table.insert(names, n) end end
        table.sort(names)
        selDisplay.Text = #names > 0 and table.concat(names, ", ") or "Keine ausgewaehlt"
    end

    -- Dropdown Button
    local dropBtn = Instance.new("TextButton", pEgg)
    dropBtn.Size = UDim2.new(1,0,0,32)
    dropBtn.BackgroundColor3 = C.acc; dropBtn.BorderSizePixel = 0
    dropBtn.Text = "Eggs auswaehlen..."; dropBtn.TextColor3 = C.tp
    dropBtn.Font = Enum.Font.GothamBold; dropBtn.TextSize = 11
    Instance.new("UICorner", dropBtn).CornerRadius = UDim.new(0,7)

    onClick(dropBtn, function()
        if activeDropOverlay then closeActiveOverlay(); return end

        local overlay = Instance.new("Frame", SG)
        overlay.Size = UDim2.new(1,0,1,0); overlay.BackgroundTransparency = 0.3
        overlay.BackgroundColor3 = Color3.fromRGB(0,0,0); overlay.ZIndex = 100
        activeDropOverlay = overlay

        local bg = Instance.new("TextButton", overlay)
        bg.Size = UDim2.new(1,0,1,0); bg.BackgroundTransparency = 1; bg.Text = ""; bg.ZIndex = 100
        onClick(bg, function() closeActiveOverlay(); updateSelDisplay() end)

        local panel = Instance.new("Frame", overlay)
        panel.Size = UDim2.new(0, W-20, 0, 400)
        panel.Position = UDim2.new(0.5, -(W-20)/2, 0.5, -200)
        panel.BackgroundColor3 = C.sur; panel.BorderSizePixel = 0; panel.ZIndex = 101
        Instance.new("UICorner", panel).CornerRadius = UDim.new(0,10)
        Instance.new("UIStroke", panel).Color = C.brd

        local ptitle = Instance.new("TextLabel", panel)
        ptitle.Size = UDim2.new(1,0,0,30); ptitle.BackgroundTransparency = 1
        ptitle.Text = "Inventory Eggs auswaehlen"; ptitle.TextColor3 = C.tp
        ptitle.Font = Enum.Font.GothamBold; ptitle.TextSize = 12; ptitle.ZIndex = 102

        local closeBtn = Instance.new("TextButton", panel)
        closeBtn.Size = UDim2.new(0,28,0,28); closeBtn.Position = UDim2.new(1,-32,0,1)
        closeBtn.BackgroundColor3 = C.red; closeBtn.BorderSizePixel = 0
        closeBtn.Text = "X"; closeBtn.TextColor3 = Color3.new(1,1,1)
        closeBtn.Font = Enum.Font.GothamBold; closeBtn.TextSize = 12; closeBtn.ZIndex = 103
        Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0,6)
        onClick(closeBtn, function() closeActiveOverlay(); updateSelDisplay() end)

        local pscroll = Instance.new("ScrollingFrame", panel)
        pscroll.Size = UDim2.new(1,-8,1,-36); pscroll.Position = UDim2.new(0,4,0,32)
        pscroll.BackgroundTransparency = 1; pscroll.BorderSizePixel = 0
        pscroll.ScrollBarThickness = 3; pscroll.CanvasSize = UDim2.new(0,0,0,0)
        pscroll.AutomaticCanvasSize = Enum.AutomaticSize.Y; pscroll.ZIndex = 102
        local pll = Instance.new("UIListLayout", pscroll); pll.Padding = UDim.new(0,3)
        local ppd = Instance.new("UIPadding", pscroll)
        ppd.PaddingLeft=UDim.new(0,4); ppd.PaddingRight=UDim.new(0,4)
        ppd.PaddingTop=UDim.new(0,4); ppd.PaddingBottom=UDim.new(0,4)

        for _, item in ipairs(S.eggItems) do
            local it = item
            local row = Instance.new("Frame", pscroll)
            row.Size = UDim2.new(1,0,0,28); row.BackgroundColor3 = C.elv
            row.BorderSizePixel = 0; row.ZIndex = 102
            Instance.new("UICorner", row).CornerRadius = UDim.new(0,5)

            local check = Instance.new("Frame", row)
            check.Size = UDim2.new(0,16,0,16); check.Position = UDim2.new(0,6,0.5,-8)
            check.BackgroundColor3 = selectedNames[it.Name] and C.grn or C.off
            check.BorderSizePixel = 0; check.ZIndex = 103
            Instance.new("UICorner", check).CornerRadius = UDim.new(0,4)

            local lbl = Instance.new("TextLabel", row)
            lbl.Size = UDim2.new(1,-30,1,0); lbl.Position = UDim2.new(0,28,0,0)
            lbl.BackgroundTransparency = 1; lbl.Text = it.Name
            lbl.TextColor3 = selectedNames[it.Name] and C.tp or C.ts
            lbl.Font = Enum.Font.Gotham; lbl.TextSize = 10
            lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.ZIndex = 103

            local rowBtn = Instance.new("TextButton", row)
            rowBtn.Size = UDim2.new(1,0,1,0); rowBtn.BackgroundTransparency = 1
            rowBtn.Text = ""; rowBtn.ZIndex = 104
            onClick(rowBtn, function()
                selectedNames[it.Name] = not selectedNames[it.Name]
                it.enabled = selectedNames[it.Name]
                check.BackgroundColor3 = it.enabled and C.grn or C.off
                lbl.TextColor3 = it.enabled and C.tp or C.ts
            end)
        end
        activeDropOverlay = overlay
    end)
    updateSelDisplay()
end

mkSec(pEgg,"Status")
local sEgg=mkStat(pEgg,"Inaktiv")
task.spawn(function() while true do task.wait(5)
    local lines = {}
    if S.hatchOn then
        local pos = findEggPos(S.hatchEgg)
        table.insert(lines, "Hatcht: "..S.hatchEgg..(pos and "" or " (WARN: nicht gefunden)"))
    else
        table.insert(lines, "Auto Hatch: aus")
    end
    if S.hatchPrioOn then
        for i,p in ipairs(S.hatchPrio) do
            if p then table.insert(lines, "Prio "..i..": "..p) end
        end
    end
    if S.eggOn then
        local cnt=0; for _,it in ipairs(S.eggItems) do if it.enabled then cnt+=1 end end
        table.insert(lines, "Inventory: "..cnt.." Egg(s) aktiv")
    end
    sEgg.Text = #lines>0 and table.concat(lines,"\n") or "Inaktiv"
end end)

-- ── BOARD ──────────────────────────────────────────────────────────
local pBoard=pages["Board"]
mkSec(pBoard,"Auto Board")
mkToggle(pBoard,"Auto Roll","Smart Dice Logik",S.boardOn,nil,function(v) S.boardOn=v end)
do
    local b=Instance.new("TextButton",pBoard); b.Size=UDim2.new(1,0,0,32)
    b.BackgroundColor3=C.acc; b.BorderSizePixel=0
    b.Text="TP > Minigame Paradise"; b.TextColor3=C.tp; b.Font=Enum.Font.GothamBold; b.TextSize=11
    Instance.new("UICorner",b).CornerRadius=UDim.new(0,7)
    onClick(b,function() tp(BOARD_POS) end)
end
mkSec(pBoard,"Smart Dice Regeln")
do
    -- Info text
    local info = mkStat(pBoard,
        "Normal Dice: Item <= 6 Felder\n"..
        "Giant Dice:  Item 7-10 Felder\n"..
        "Golden Dice: Ziel-Tile in X Felder")
    info.TextColor3 = C.ts
end
mkSec(pBoard,"Golden Dice Ziel")
do
    -- Board tile types as dropdown
    local tileTypes = {
        "(keins)","Bonus","Coins","Chest","Mystery","Reroll","Event",
        "Lucky","Super Lucky","Green Shard","Diamond","Jackpot",
        "Mini Game","Shortcut","Start",
    }
    mkDrop(pBoard,"boardGoldenTile",tileTypes,
        S.boardGoldenTile~="" and S.boardGoldenTile or "(keins)",
        function(sel)
            S.boardGoldenTile = (sel=="(keins)") and "" or sel
        end, nil, "Ziel-Tile")

    -- Golden distance: 1-5
    local distOpts={"1","2","3","4","5"}
    mkDrop(pBoard,"boardGoldenDist",distOpts,tostring(S.boardGoldenMinDist),function(v)
        S.boardGoldenMinDist = tonumber(v) or 1
    end,nil,"Golden wenn <= Felder")
end
mkSec(pBoard,"Status")
local sBoard=mkStat(pBoard,"Inaktiv")
task.spawn(function() while true do task.wait(3)
    if not S.boardOn then sBoard.Text="Inaktiv"; continue end
    local d=getData()
    local pos = d and d.Board and (d.Board.Position or d.Board.Tile or 0) or 0
    local ln = {}
    table.insert(ln,"Position: Feld "..pos)
    for _, name in ipairs({"Golden Dice","Giant Dice","Dice"}) do
        local n = ownedPU(name)
        if n > 0 then table.insert(ln, name..": x"..n) end
    end
    if S.boardGoldenTile ~= "" then
        table.insert(ln,"Ziel: "..S.boardGoldenTile.." (ab "..S.boardGoldenMinDist.." Felder)")
    end
    sBoard.Text = table.concat(ln,"\n")
end end)

-- ── WHEEL ──────────────────────────────────────────────────────────
local pWheel=pages["Wheel"]
mkSec(pWheel,"Auto Wheels")
for _,w in ipairs(S.wheels) do
    local ww=w
    mkToggle(pWheel,ww.label,"Hintergrund",ww.on,nil,function(v) ww.on=v end)
end
mkSec(pWheel,"Status")
local sWheel=mkStat(pWheel,"Inaktiv")
task.spawn(function() while true do task.wait(1)
    local act={}
    for _,w in ipairs(S.wheels) do if w.on then table.insert(act,w.label) end end
    sWheel.Text=#act>0 and table.concat(act,"\n") or "Inaktiv"
end end)

-- ── SHRINE ─────────────────────────────────────────────────────────
local pShrine=pages["Shrine"]
mkSec(pShrine,"Bubble Shrine")
mkToggle(pShrine,"Auto Shrine","Potions spenden",S.shrineOn,nil,function(v) S.shrineOn=v end)
mkSec(pShrine,"Items (L1-L5)")
for _,item in ipairs(S.shrineItems) do
    local it=item
    mkToggle(pShrine,it.Name.." L"..it.Level,"XP: "..it.XP,it.enabled,nil,function(v) it.enabled=v end)
end
mkSec(pShrine,"Dreamer Shrine")
mkToggle(pShrine,"Auto Dreamer","Dream Shards spenden",S.dreamerOn,nil,function(v) S.dreamerOn=v end)
mkNumberInput(pShrine,"Shards pro Use",S.dreamerAmt,1,1000,function(v) S.dreamerAmt=v end)
mkSec(pShrine,"Bubbles")
mkToggle(pShrine,"Auto Bubbles","Standard: AUS",false,nil,function(v) S.bubbleOn=v end)
mkSec(pShrine,"Status")
local sShrine=mkStat(pShrine,"Inaktiv")
task.spawn(function() while true do task.wait(3); local ln={}
    if S.shrineOn then table.insert(ln,"Shrine: "..(isReady("Shrine") and "Bereit" or "warte...")) end
    if S.dreamerOn then table.insert(ln,"Dreamer: "..ownedPU("Dream Shard").." Shards") end
    if S.bubbleOn then table.insert(ln,"Bubbles: aktiv") end
    sShrine.Text=#ln>0 and table.concat(ln,"\n") or "Inaktiv"
end end)

-- ── FUSE ───────────────────────────────────────────────────────────
local NUM_REQ=FuseUtil.NUM_SECRETS_REQUIRED or 5
local pFuse=pages["Fuse"]
mkSec(pFuse,"Pet Rebirth ("..NUM_REQ.." Secrets)")
mkToggle(pFuse,"Auto Fuse","Schlechteste Secrets",S.fuseOn,nil,function(v) S.fuseOn=v end)
mkToggle(pFuse,"Shiny behalten","",S.fuseKeepShiny,nil,function(v) S.fuseKeepShiny=v end)
mkToggle(pFuse,"Mythic behalten","",S.fuseKeepMythic,nil,function(v) S.fuseKeepMythic=v end)
mkToggle(pFuse,"Nur Unlocked","Locked Pets nie fusen",S.fuseOnlyUnlocked,nil,function(v) S.fuseOnlyUnlocked=v end)
-- Lock Pets section also in Fuse tab
mkSec(pFuse,"Lock Pets (auch im LockPets Tab)")
mkToggle(pFuse,"Auto Lock",  "Secrets nach Kriterien locken",S.lockOn,nil,function(v) S.lockOn=v end)
mkToggle(pFuse,"Lock by Chance","1 in X und besser",S.lockSecretChanceOn,nil,function(v) S.lockSecretChanceOn=v end)
mkNumberInput(pFuse,"Chance 1 in ...",S.lockSecretChance,1,999999,function(v) S.lockSecretChance=v end)
mkToggle(pFuse,"Lock by Count","ExistCount unter X",S.lockSecretCountOn,nil,function(v) S.lockSecretCountOn=v end)
mkNumberInput(pFuse,"Exist Count unter",S.lockSecretCount,1,99999,function(v) S.lockSecretCount=v end)
mkSec(pFuse,"Status")
local sFuse=mkStat(pFuse,"Inaktiv")
task.spawn(function() while true do task.wait(3)
    if not S.fuseOn then sFuse.Text="Inaktiv"; continue end
    local d=getData(); if not d then continue end; local cnt2=0
    if d.Pets then for _,p in ipairs(d.Pets) do
        if (p.Rarity=="Secret" or p.Type=="Secret") then
            if S.fuseOnlyUnlocked and p.Locked then continue end
            if not (S.fuseKeepShiny and p.Shiny) and not (S.fuseKeepMythic and p.Mythic) then cnt2+=1 end
        end
    end end
    local cd=(d.NextRebirthMachineUse or 0)-now()
    sFuse.Text="Fuseable: "..cnt2.."/"..NUM_REQ.."\n"
        ..(cd>0 and "CD: "..math.ceil(cd).."s" or (cnt2>=NUM_REQ and "Bereit!" or "warte..."))
end end)

-- ── GEM GENIE ──────────────────────────────────────────────────────
local pGenie=pages["Genie"]
mkSec(pGenie,"Auto Gem Genie")
mkToggle(pGenie,"Auto Genie","Hoechste SEQ-Prioritaet",false,nil,function(v)
    S.genieOn=v
    if v then
        S.genieStatus="Genie laeuft..."
        local hrp=LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        S.genieReturnPos=hrp and hrp.CFrame or nil
    else
        S.genieStatus="Inaktiv"; genieBlocking=false; _genieSpamActive=false
        if S.genieReturnPos then
            local hrp=LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
            local hum=LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
            if hrp then
                if hum then hum.PlatformStand=true end
                hrp.CFrame=S.genieReturnPos; task.wait(0.1)
                if hum then hum.PlatformStand=false end
            end
        end
    end
end)
mkSec(pGenie,"Task-Filter")
mkToggle(pGenie,"Skip Bubbles","",S.genieSkipBubbles,nil,function(v) S.genieSkipBubbles=v end)
mkToggle(pGenie,"Skip Coins","Collect skippen",true,nil,function(v) GENIE_BAD_TASKS.Collect=v end)
mkToggle(pGenie,"Skip Shiny","",true,nil,function(v) S.genieSkipShiny=v end)
mkToggle(pGenie,"Skip Mythic","",true,nil,function(v) S.genieSkipMythic=v end)
mkSec(pGenie,"Green Shard Override")
mkToggle(pGenie,"Override fuer Green Shard","Quest mit Green Shard: Bubbles+Coins trotzdem akzeptieren",S.genieGreenShardOverride,nil,function(v) S.genieGreenShardOverride=v end)
mkSec(pGenie,"Reward Prioritaet")
do
    local pItems={
        {"Green Fragment",10000},{"Rune Rock",50},
        {"Dream Shard",20},{"Shadow Crystal",20},
        {"Secret Elixir",0},{"Infinity Elixir",0},
        {"Royal Key",0},{"Moon Key",0},{"Reroll Orb",0},
    }
    for _,pair in ipairs(pItems) do
        local pName=pair[1]
        S.genieQuestPrio[pName]=S.genieQuestPrio[pName] or pair[2]
        mkNumberInput(pGenie,pName,S.genieQuestPrio[pName] or pair[2],0,99999,function(v)
            S.genieQuestPrio[pName]=v
        end)
    end
end
mkSec(pGenie,"Reroll System")
mkToggle(pGenie,"Reroll Quests","Rerollt bis gute Quest (AUS)",S.genieRerollOn,nil,function(v) S.genieRerollOn=v end)
mkNumberInput(pGenie,"Reroll Grenze",S.genieRerollMax,0,9999,function(v) S.genieRerollMax=v end)
mkNumberInput(pGenie,"Max Rerolls (alt)",S.genieMaxReroll,0,100,function(v) S.genieMaxReroll=v end)
mkSec(pGenie,"Slot-Vorschau")
local sSlots=mkStat(pGenie,"Slot 1: ...\nSlot 2: ...\nSlot 3: ...")
mkSec(pGenie,"Status")
local sGenie=mkStat(pGenie,"Inaktiv")
task.spawn(function() while true do task.wait(1)
    sSlots.Text="1: "..(S.genieSlots[1] or "..."):sub(1,40)
        .."\n2: "..(S.genieSlots[2] or "..."):sub(1,40)
        .."\n3: "..(S.genieSlots[3] or "..."):sub(1,40)
    sGenie.Text=S.genieStatus
    if S.genieOn and _genieRerolls>0 then
        sGenie.Text=sGenie.Text.."\nRerolls: ".._genieRerolls
    end
    if genieBlocking then sGenie.Text=sGenie.Text.."\nPrio aktiv" end
end end)

-- ── CONSUMABLES ────────────────────────────────────────────────────
local pConsum=pages["Consum"]
mkSec(pConsum,"Potions")
mkToggle(pConsum,"Auto Potion","Alle aktiven Potions (BG)",false,nil,function(v) S.potionOn=v end)
do
    local groups,order={},{}
    for _,it in ipairs(S.potionItems) do
        if not groups[it.Name] then groups[it.Name]={}; table.insert(order,it.Name) end
        table.insert(groups[it.Name],it)
    end
    for _,pName in ipairs(order) do
        local grp=groups[pName]
        local masterOn=false; local selLvl="Alle"
        -- FIXED: toggle label includes the potion name
        mkToggle(pConsum,pName,"Toggle > dann Level waehlen",false,nil,function(v)
            masterOn=v
            for _,it in ipairs(grp) do
                if selLvl=="Alle" then it.enabled=v
                else local n=tonumber(selLvl:match("%d+")); it.enabled=v and (it.Level==n) end
            end
        end)
        if #grp>1 then
            local opts={}
            for _,it in ipairs(grp) do table.insert(opts,"L"..it.Level) end
            table.insert(opts,"Alle")
            -- FIXED: labelPrefix shows the potion name before the dropdown value
            mkDrop(pConsum,"p_"..pName:gsub("[%s%'%\"%-%.%(%)%[%]]","_"),opts,"Alle",function(sel)
                selLvl=sel; if not masterOn then return end
                for _,it in ipairs(grp) do
                    if sel=="Alle" then it.enabled=true
                    else local n=tonumber(sel:match("%d+")); it.enabled=(it.Level==n) end
                end
            end,nil,pName.." Level")
        end
    end
end
mkSec(pConsum,"Runes")
mkToggle(pConsum,"Auto Rune","Alle aktiven Runes (BG)",false,nil,function(v) S.runeOn=v end)
do
    local runeG,runeO={},{}
    for _,it in ipairs(S.runeItems) do
        if not runeG[it.Name] then runeG[it.Name]={}; table.insert(runeO,it.Name) end
        table.insert(runeG[it.Name],it)
    end
    for _,rName in ipairs(runeO) do
        local grp=runeG[rName]; local masterOn=false; local selLvl="Alle"
        mkToggle(pConsum,rName,"Rune",false,nil,function(v)
            masterOn=v
            for _,it in ipairs(grp) do
                if selLvl=="Alle" then it.enabled=v
                else local n=tonumber(selLvl:match("%d+")); it.enabled=v and (it.Level==n) end
            end
        end)
        local opts={}
        for _,it in ipairs(grp) do table.insert(opts,"L"..it.Level) end
        table.insert(opts,"Alle")
        mkDrop(pConsum,"r_"..rName:gsub("[%s%'%\"%-%.%(%)%[%]]","_"),opts,"Alle",function(sel)
            selLvl=sel; if not masterOn then return end
            for _,it in ipairs(grp) do
                if sel=="Alle" then it.enabled=true
                else local n=tonumber(sel:match("%d+")); it.enabled=(it.Level==n) end
            end
        end,nil,rName.." Level")
    end
end
mkSec(pConsum,"Boxes & Crates")
mkToggle(pConsum,"Auto Box","Mystery Boxes",false,nil,function(v) S.boxOn=v end)
for _,item in ipairs(S.boxItems) do
    local it=item
    mkToggle(pConsum,it.Name,"",it.enabled,nil,function(v) it.enabled=v end)
end
mkSec(pConsum,"Sonstiges")
mkToggle(pConsum,"Auto Golden Orb","",false,nil,function(v) S.goldenOrbOn=v end)
mkToggle(pConsum,"Daily Reward","",false,nil,function(v) S.dailyReward=v end)
mkToggle(pConsum,"Daily Perk","Slot 1",false,nil,function(v) S.dailyPerk=v end)
mkSec(pConsum,"Status")
local sConsum=mkStat(pConsum,"Inaktiv")
task.spawn(function() while true do task.wait(3); local ln={}
    if S.potionOn then table.insert(ln,"Potion: an") end
    if S.runeOn then table.insert(ln,"Rune: an") end
    if S.eggOn then table.insert(ln,"Eggs: an") end
    if S.boxOn then table.insert(ln,"Boxes: an") end
    sConsum.Text=#ln>0 and table.concat(ln,"\n") or "Inaktiv"
end end)

-- ── SPINS ──────────────────────────────────────────────────────────
local pSpins=pages["Spins"]
mkSec(pSpins,"Wheel Spins (BG)")
for _,st in ipairs(S.spinTickets) do
    local e=st
    mkToggle(pSpins,e.label,"Ticket+Claim",e.on,nil,function(v) e.on=v end)
end
mkSec(pSpins,"Key Chests (TP)")
mkToggle(pSpins,"Auto Chests","",S.chestsOn,nil,function(v) S.chestsOn=v end)
for _,it in ipairs(S.chestItems) do
    local item=it
    mkToggle(pSpins,item.ChestName,"Key: "..item.KeyName,item.enabled,nil,function(v) item.enabled=v end)
end
mkSec(pSpins,"Status")
local sSpins=mkStat(pSpins,"Inaktiv")
task.spawn(function() while true do task.wait(3); local ln={}; local d=getData()
    for _,st in ipairs(S.spinTickets) do
        if st.on then local c=d and d.Powerups and (d.Powerups[st.label] or 0) or 0
            table.insert(ln,st.label..": "..c) end
    end
    sSpins.Text=#ln>0 and table.concat(ln,"\n") or "Inaktiv"
end end)

-- ── RIFTS ──────────────────────────────────────────────────────────
local pRifts=pages["Rifts"]
mkSec(pRifts,"Global")
mkToggle(pRifts,"Auto Rift Spawn","Alle aktivierten Rifts",S.riftOn,nil,function(v) S.riftOn=v end)
mkToggle(pRifts,"Permanent","Sofort respawnen wenn weg",S.riftPermanent,nil,function(v) S.riftPermanent=v end)
do
    local dOpts={"1","2","3","5","10","15","20","30"}
    mkDrop(pRifts,"riftDur",dOpts,tostring(S.riftSpawnTime),function(v)
        S.riftSpawnTime=tonumber(v) or 5
    end,nil,"Dauer (Min)")
end
mkSec(pRifts,"Egg Rift")
mkToggle(pRifts,"Spawn Egg Rift",   "31min Cooldown",S.riftEggOn,nil,function(v) S.riftEggOn=v end)
mkToggle(pRifts,"TP + Hatch Egg", "Nach Spawn zum Egg TP",S.riftChestOn,nil,function(v) S.riftChestOn=v end)
do
    mkDrop(pRifts,"riftEggSel",S.riftEggOptions,S.riftEggName,function(sel)
        S.riftEggName=sel
    end,nil,"Egg")
end
mkSec(pRifts,"Chest Rifts")
for _,r in ipairs(S.riftChestItems) do
    local item=r
    mkToggle(pRifts,item.displayName,item.world,item.on,nil,function(v)
        item.on=v
    end)
    mkToggle(pRifts,"  TP zum Chest","Nach Spawn",item.on and S.riftChestOn,nil,function(v)
        -- Per-chest TP toggle stored on item
        item.tpOn=v
    end)
end
mkSec(pRifts,"Status")
local sRifts=mkStat(pRifts,"Inaktiv")
task.spawn(function() while true do task.wait(3); local ln={}
    local t=now()
    if S.riftEggOn then
        local last=S._riftEggLast or 0
        local cd=(31*60)-(t-last)
        ln[#ln+1]="Egg Rift "..S.riftEggName..": "..(S.riftPermanent and "Permanent" or
            (cd>0 and math.floor(cd/60).."m" or "Bereit!"))
    end
    for _,r in ipairs(S.riftChestItems) do
        if r.on then
            local cd=r.interval-(t-r.lastSummon)
            ln[#ln+1]=r.displayName..": "..(S.riftPermanent and "Permanent" or
                (cd>0 and math.floor(cd/60).."m" or "Bereit!"))
        end
    end
    sRifts.Text=#ln>0 and table.concat(ln,"\n") or "Inaktiv"
end end)

-- ── FARMING ────────────────────────────────────────────────────────
local pFarm=pages["Farming"]
mkSec(pFarm,"Bubbles & Farming")
mkToggle(pFarm,"Auto Bubble","Bubbles spammen (BG)",S.farmBubbleOn,nil,function(v)
    S.farmBubbleOn=v; S.bubbleOn=v
end)
mkToggle(pFarm,"Auto Collect Pickup","UUID-Pickups sammeln (BG, kein TP)",S.autoCollectPickupOn,nil,function(v)
    S.autoCollectPickupOn=v  -- shared with Automation tab
end)
mkToggle(pFarm,"Playtime Reward","Alle 10s (BG)",S.farmPlaytimeOn,nil,function(v) S.farmPlaytimeOn=v end)
mkSec(pFarm,"Teams (nur 1 aktiv gleichzeitig)")
do
    -- 3 team toggles, only one at a time - with setter refs for mutual exclusion
    local setters = {}
    local function mkExclusiveTeamToggle(label, sub, stateKey)
        local _, setter = mkToggle(pFarm, label, sub, S[stateKey], nil, function(v)
            S[stateKey] = v
            if v then
                -- Deactivate the other two
                for k, s in pairs(setters) do
                    if k ~= stateKey then S[k]=false; s(false) end
                end
            end
        end)
        setters[stateKey] = setter
    end
    mkExclusiveTeamToggle("Bubble Team aktiv","Fuer Bubbling","farmBubbleTeamOn")
    mkTextInput(pFarm,"Team Name Bubble (1-15):",S.farmTeamBubble,function(v) S.farmTeamBubble=v end)
    mkExclusiveTeamToggle("Luck Team aktiv","Fuer Luck Farming","farmLuckTeamOn")
    mkTextInput(pFarm,"Team Name Luck (1-15):",S.farmTeamLuck,function(v) S.farmTeamLuck=v end)
    mkExclusiveTeamToggle("Secret Luck Team","Fuer Secret Luck","farmSecretLuckTeamOn")
    mkTextInput(pFarm,"Team Name Secret Luck (1-15):",S.farmTeamSecretLuck,function(v) S.farmTeamSecretLuck=v end)
end
mkSec(pFarm,"Status")
local sFarm=mkStat(pFarm,"Inaktiv")
task.spawn(function() while true do task.wait(2); local ln={}
    if S.farmBubbleOn then table.insert(ln,"Bubbles: aktiv") end
    if S.farmCollectCoinsOn then table.insert(ln,"Coins: sammeln") end
    if S.farmPlaytimeOn then table.insert(ln,"Playtime: aktiv") end
    local t=currentTeam or "kein Team"
    table.insert(ln,"Team: "..t)
    sFarm.Text=#ln>0 and table.concat(ln,"\n") or "Inaktiv"
end end)

-- ── SEASON PASS ────────────────────────────────────────────────────
local pSP=pages["SP"]
mkSec(pSP,"Auto Season Pass")
mkToggle(pSP,"Auto SP","Daily+Hourly Quests + Rewards (TP-SEQ)",S.spOn,nil,function(v) S.spOn=v end)
mkSec(pSP,"Info")
do
    local info=mkStat(pSP,"Season Pass verarbeitet Daily und Hourly Quests automatisch.\n"
        .."Hatch-Specific-Egg Quests werden zuerst gemacht.\n"
        .."Rewards werden automatisch geclaimed.")
    info.TextWrapped=true
end
mkSec(pSP,"Status")
local sSP=mkStat(pSP,"Inaktiv")
task.spawn(function() while true do task.wait(2)
    sSP.Text=S.spStatus
end end)

-- ── LOCK PETS ──────────────────────────────────────────────────────
local pLock=pages["LockPets"]
mkSec(pLock,"Auto Lock Pets")
mkToggle(pLock,"Auto Lock","Secrets nach Kriterien locken",S.lockOn,nil,function(v) S.lockOn=v end)
mkSec(pLock,"Lock by Chance (1 in X)")
mkToggle(pLock,"Aktiv","Seltene Secrets locken",S.lockSecretChanceOn,nil,function(v) S.lockSecretChanceOn=v end)
mkNumberInput(pLock,"Chance: 1 in ...",S.lockSecretChance,1,999999,function(v) S.lockSecretChance=v end)
mkSec(pLock,"Lock by Exist Count")
mkToggle(pLock,"Aktiv","Rare Secrets locken",S.lockSecretCountOn,nil,function(v) S.lockSecretCountOn=v end)
mkNumberInput(pLock,"ExistCount unter",S.lockSecretCount,1,99999,function(v) S.lockSecretCount=v end)
mkSec(pLock,"Info")
mkStat(pLock,"Dieser Tab ist auch im Fuse Tab verfuegbar.\nLocked Pets werden NIEMALS gefused.")

-- ── PRIORITY ───────────────────────────────────────────────────────
local pPrio=pages["Priority"]
mkSec(pPrio,"Modul-Prioritaet (Slot 1 = hoechste Prioritaet)")
do
    local moduleNames={
        "GemGenie","SeasonPass","Hatch","Fishing",
        "Rifts","KeyChests","Board","Minigames","AutoSell"
    }
    local numSlots=#moduleNames

    -- Current assignment: slot -> moduleName
    -- Build from S.modulePriority (priority number = slot position)
    local slotAssign = {}  -- slotAssign[i] = moduleName or nil
    do
        -- Sort modules by current priority to fill slots
        local sorted={}
        for _,mn in ipairs(moduleNames) do
            table.insert(sorted,{name=mn, prio=S.modulePriority[mn] or 99})
        end
        table.sort(sorted,function(a,b) return a.prio<b.prio end)
        for i,entry in ipairs(sorted) do
            slotAssign[i]=entry.name
        end
    end

    local dropLabels={}  -- dropLabels[i] = the TextButton label ref

    -- Rebuild modulePriority from slotAssign
    local function applySlots()
        for i,mn in ipairs(slotAssign) do
            if mn then S.modulePriority[mn]=i end
        end
        resortModules(S)
    end

    -- Options for a slot = all modules not yet assigned to another slot
    local function getAvailableOpts(mySlot)
        local used={}
        for i,mn in ipairs(slotAssign) do
            if i~=mySlot and mn then used[mn]=true end
        end
        local opts={"(leer)"}
        for _,mn in ipairs(moduleNames) do
            if not used[mn] then table.insert(opts,mn) end
        end
        return opts
    end

    for slot=1,numSlots do
        local s=slot
        local cur=slotAssign[s] or "(leer)"
        local _, dLbl = mkDrop(pPrio,"prio_slot"..s,
            getAvailableOpts(s), cur,
            function(sel)
                -- Remove this module from any other slot
                if sel~="(leer)" then
                    for i=1,numSlots do
                        if i~=s and slotAssign[i]==sel then
                            slotAssign[i]=nil
                            -- Update that slot's label
                            if dropLabels[i] then
                                dropLabels[i].Text="v  Slot "..i..": (leer)"
                            end
                        end
                    end
                end
                slotAssign[s]=(sel=="(leer)") and nil or sel
                applySlots()
            end,
            function() return getAvailableOpts(s) end,
            "Slot "..s)
        dropLabels[s]=dLbl
        if dLbl then dLbl.Text="v  Slot "..s..": "..cur end
    end
end
mkSec(pPrio,"Aktuelle Reihenfolge")
local sPrio=mkStat(pPrio,"...")
task.spawn(function() while true do task.wait(2)
    local ln={}
    for i,m in ipairs(SEQ._tpModules) do
        table.insert(ln,i..". "..m.name)
    end
    sPrio.Text=#ln>0 and table.concat(ln,"\n") or "Keine Module"
end end)

-- ── MILESTONES ─────────────────────────────────────────────────────
local pMile=pages["Milestones"]
mkSec(pMile,"Milestones (Live-Fortschritt)")
do
    local mileItems={
        {label="Bubbles",      dataKey="Bubbles",       questType="Bubbles"},
        {label="Eggs Hatched", dataKey="EggsHatched",   questType="Hatch"},
        {label="Coins",        dataKey="Coins",          questType="Collect"},
        {label="Fish Caught",  dataKey="FishCaught",    questType="Fish"},
        {label="Board Tiles",  dataKey="BoardTiles",    questType="Board"},
        {label="Minigames",    dataKey="MinigamesPlayed",questType="MG"},
    }
    for _,mi in ipairs(mileItems) do
        local m=mi
        local f=Instance.new("Frame",pMile); f.Size=UDim2.new(1,0,0,60)
        f.BackgroundColor3=C.elv; f.BorderSizePixel=0
        Instance.new("UICorner",f).CornerRadius=UDim.new(0,7)
        -- Label
        local nameLbl=Instance.new("TextLabel",f); nameLbl.Size=UDim2.new(1,-42,0,18)
        nameLbl.Position=UDim2.new(0,10,0,4); nameLbl.BackgroundTransparency=1
        nameLbl.Text=m.label; nameLbl.TextColor3=C.tp
        nameLbl.Font=Enum.Font.GothamBold; nameLbl.TextSize=11; nameLbl.TextXAlignment=Enum.TextXAlignment.Left
        -- Progress label
        local progLbl=Instance.new("TextLabel",f); progLbl.Size=UDim2.new(1,-20,0,14)
        progLbl.Position=UDim2.new(0,10,0,24); progLbl.BackgroundTransparency=1
        progLbl.Text="Lade..."; progLbl.TextColor3=C.ts
        progLbl.Font=Enum.Font.Gotham; progLbl.TextSize=9; progLbl.TextXAlignment=Enum.TextXAlignment.Left
        -- Progress bar
        local barBg=Instance.new("Frame",f); barBg.Size=UDim2.new(1,-20,0,6)
        barBg.Position=UDim2.new(0,10,0,42); barBg.BackgroundColor3=C.off; barBg.BorderSizePixel=0
        Instance.new("UICorner",barBg).CornerRadius=UDim.new(0,3)
        local barFill=Instance.new("Frame",barBg); barFill.Size=UDim2.new(0,0,1,0)
        barFill.BackgroundColor3=C.acc; barFill.BorderSizePixel=0
        Instance.new("UICorner",barFill).CornerRadius=UDim.new(0,3)
        -- Toggle
        local tog=Instance.new("TextButton",f); tog.Size=UDim2.new(0,34,0,18)
        tog.Position=UDim2.new(1,-42,0.5,-9); tog.BackgroundColor3=C.off; tog.BorderSizePixel=0
        tog.Text="OFF"; tog.TextColor3=C.ts; tog.Font=Enum.Font.GothamBold; tog.TextSize=9
        Instance.new("UICorner",tog).CornerRadius=UDim.new(0,9)
        local togOn=false
        onClick(tog,function()
            togOn=not togOn
            tog.BackgroundColor3=togOn and C.grn or C.off
            tog.Text=togOn and "ON" or "OFF"
            -- Activate corresponding module via S flags
            if m.label=="Bubbles" then S.farmBubbleOn=togOn; S.bubbleOn=togOn
            elseif m.label=="Eggs Hatched" then S.hatchOn=togOn
            elseif m.label=="Fish Caught" then S.fishOn=togOn
            elseif m.label=="Board Tiles" then S.boardOn=togOn
            end
        end)
        -- Live update
        task.spawn(function()
            while true do task.wait(3)
                local d=getData(); if not d then continue end
                local val=0; local req=0; local stagePct=0
                if m.dataKey=="Bubbles" then
                    val=(d.Stats and d.Stats.BubblesPopped) or (d.Bubbles or 0)
                elseif m.dataKey=="EggsHatched" then
                    val=(d.Stats and d.Stats.EggsHatched) or 0
                elseif m.dataKey=="Coins" then
                    val=(d.Stats and d.Stats.CoinsCollected) or (d.Coins or 0)
                elseif m.dataKey=="FishCaught" then
                    val=(d.Stats and d.Stats.FishCaught) or 0
                elseif m.dataKey=="BoardTiles" then
                    val=(d.Stats and d.Stats.BoardTiles) or 0
                elseif m.dataKey=="MinigamesPlayed" then
                    val=(d.Stats and d.Stats.MinigamesPlayed) or 0
                end
                -- Find current milestone from Milestones data if available
                local milestoneData=d.Milestones and d.Milestones[m.questType]
                if milestoneData then
                    req=milestoneData.Required or req
                    stagePct=req>0 and math.min(100,math.floor(val/req*100)) or 0
                end
                local valStr=val>=1e9 and (math.floor(val/1e9*10)/10).."B"
                    or val>=1e6 and (math.floor(val/1e6*10)/10).."M"
                    or val>=1e3 and (math.floor(val/1e3*10)/10).."K"
                    or tostring(math.floor(val))
                local reqStr=req>=1e9 and (math.floor(req/1e9*10)/10).."B"
                    or req>=1e6 and (math.floor(req/1e6*10)/10).."M"
                    or req>=1e3 and (math.floor(req/1e3*10)/10).."K"
                    or tostring(math.floor(req))
                progLbl.Text=valStr.."/"..reqStr.." ("..stagePct.."% dieser Stage)"
                tw(barFill,{Size=UDim2.new(stagePct/100,0,1,0)})
            end
        end)
    end
end

-- ── AUTOMATION ─────────────────────────────────────────────────────
local pAuto=pages["Auto"]
mkSec(pAuto,"Pickup & Collect")
mkToggle(pAuto,"Auto Collect Pickup","UUID-Pickups sammeln (BG, kein TP)",S.autoCollectPickupOn,nil,function(v) S.autoCollectPickupOn=v end)
mkToggle(pAuto,"Bubble Sell Prioritaet","Stoppt Sequencer wenn Sell aktiv",S.bubbleSellPriorityOn,nil,function(v) S.bubbleSellPriorityOn=v end)
mkSec(pAuto,"Hatch")
mkToggle(pAuto,"Hide Hatch Animation","Hatch-Anim ausblenden",S.hideHatchAnimOn,nil,function(v) S.hideHatchAnimOn=v end)
mkToggle(pAuto,"Auto Potion beim Hatchen","Infinity Elixir + L7 Lucky/Speed/Mythic",S.autoPotionHatchOn,nil,function(v) S.autoPotionHatchOn=v end)
mkSec(pAuto,"Auto Box (Gems unter Schwellwert)")
mkToggle(pAuto,"Auto Box wenn Gems leer","Boxen oeffnen bis Gems voll",S.autoBoxGemOn,nil,function(v) S.autoBoxGemOn=v end)
do
    mkNumberInput(pAuto,"Gem Schwellwert (Milliarden)",
        math.floor(S.autoBoxGemThreshold/1e9), 0, 9999, function(v)
            S.autoBoxGemThreshold = v * 1e9
        end)
end
mkSec(pAuto,"Auto Reroll Orb Refill")
mkToggle(pAuto,"Auto Orb Refill","STOPPT alles! Warnt den User",S.autoRerollOrbOn,nil,function(v) S.autoRerollOrbOn=v end)
mkNumberInput(pAuto,"Orb Schwellwert",S.autoRerollOrbThreshold,0,999999,function(v) S.autoRerollOrbThreshold=v end)
mkSec(pAuto,"Status")
local sAuto=mkStat(pAuto,"Inaktiv")
task.spawn(function() while true do task.wait(2); local ln={}
    if S.autoCollectPickupOn then table.insert(ln,"Pickup: aktiv"..(PickupRemote and "" or " (kein Remote!)")) end
    if S.bubbleSellPriorityOn then table.insert(ln,"Sell-Prio: aktiv") end
    if S.hideHatchAnimOn then table.insert(ln,"HideAnim: aktiv") end
    if S.autoBoxGemOn then
        table.insert(ln,"AutoBox: an (Schwelle: "..(S.autoBoxGemThreshold/1e9).."B)")
    end
    if S.autoPotionHatchOn then table.insert(ln,"AutoPotion: an") end
    if S.autoRerollOrbOn then
        local d=getData()
        local orbs=d and d.Powerups and (d.Powerups["Reroll Orb"] or 0) or 0
        table.insert(ln,"Orbs: "..orbs.."/"..S.autoRerollOrbThreshold)
    end
    if S.autoWarnActive then table.insert(ln,"!!! "..S.autoWarnMsg.." !!!") end
    sAuto.Text=#ln>0 and table.concat(ln,"\n") or "Inaktiv"
end end)

-- ── PLAY PROFILES ──────────────────────────────────────────────────
local pProf=pages["Profiles"]
mkSec(pProf,"Play Profiles")
do
    -- Profile slots: up to 12
    local profileSlots={}; for i=1,12 do profileSlots[i]="(leer "..i..")" end
    -- Load existing profile names
    for i,prof in ipairs(S.profiles) do
        if i<=12 then profileSlots[i]=prof.name or ("Profil "..i) end
    end

    local selectedSlot=1
    local _,slotDropLbl=mkDrop(pProf,"profileSlot",profileSlots,profileSlots[1],function(sel)
        for i,n in ipairs(profileSlots) do if n==sel then selectedSlot=i; break end end
    end,function() return profileSlots end,"Profil")

    -- Profile name input
    local _,nameBox=mkTextInput(pProf,"Profil-Name:",profileSlots[1],nil)

    -- Player name input
    local _,playerBox=mkTextInput(pProf,"Spieler-Name (auto-load):",LP.Name,nil)

    -- Autosave toggle
    mkToggle(pProf,"Auto-Save (30s)","Konfiguration automatisch speichern",S.autosaveOn,nil,function(v)
        S.autosaveOn=v
    end)

    -- Save button
    local saveBtn=Instance.new("TextButton",pProf)
    saveBtn.Size=UDim2.new(1,0,0,32); saveBtn.BackgroundColor3=C.acc; saveBtn.BorderSizePixel=0
    saveBtn.Text="Speichern"; saveBtn.TextColor3=C.tp; saveBtn.Font=Enum.Font.GothamBold; saveBtn.TextSize=11
    Instance.new("UICorner",saveBtn).CornerRadius=UDim.new(0,7)
    onClick(saveBtn,function()
        local pname=nameBox.Text~="" and nameBox.Text or ("Profil "..selectedSlot)
        local player=playerBox.Text
        profileSlots[selectedSlot]=pname
        S.profiles[selectedSlot]={name=pname, player=player}
        saveProfiles(S.profiles)
        saveConfig(S,pname)
        if slotDropLbl then slotDropLbl.Text="v  Profil: "..pname end
    end)

    -- Load button
    local loadBtn=Instance.new("TextButton",pProf)
    loadBtn.Size=UDim2.new(1,0,0,32); loadBtn.BackgroundColor3=C.elv; loadBtn.BorderSizePixel=0
    loadBtn.Text="Laden"; loadBtn.TextColor3=C.tp; loadBtn.Font=Enum.Font.GothamBold; loadBtn.TextSize=11
    Instance.new("UIStroke",loadBtn).Color=C.acc
    Instance.new("UICorner",loadBtn).CornerRadius=UDim.new(0,7)
    onClick(loadBtn,function()
        local prof=S.profiles[selectedSlot]
        if prof and prof.name then
            local cfg=loadConfig(prof.name)
            if cfg then
                applyConfig(S,cfg)
                resortModules(S)
            end
        end
    end)

    -- Auto-load for current player
    task.spawn(function()
        local pname=LP.Name
        for _,prof in ipairs(S.profiles) do
            if prof.player==pname and prof.name then
                local cfg=loadConfig(prof.name)
                if cfg then applyConfig(S,cfg); resortModules(S)
                    print("[BGS AIO] Auto-load Profil '"..prof.name.."' fuer "..pname) end
                break
            end
        end
    end)
end
mkSec(pProf,"Status")
local sProf=mkStat(pProf,"Bereit")
task.spawn(function() while true do task.wait(5)
    sProf.Text="Spieler: "..LP.Name.."\nAutosave: "..(S.autosaveOn and "an" or "aus")
end end)

-- ── COMPETITIVE ────────────────────────────────────────────────────
local pComp=pages["Comp"]
mkSec(pComp,"Competitive Mode")
mkToggle(pComp,"Competitive aktiv","Hatch + Bubbles + Rarity",S.competitiveOn,nil,function(v)
    S.competitiveOn=v
    -- Activate key modules
    S.hatchOn=v; S.farmBubbleOn=v; S.bubbleOn=v
end)
mkSec(pComp,"Hatch Egg")
mkDrop(pComp,"compEgg",ALL_WORLD_EGGS,S.hatchEgg,function(sel) S.hatchEgg=sel end,
    function() return ALL_WORLD_EGGS end,"Egg")
mkSec(pComp,"Status")
local sComp=mkStat(pComp,"Inaktiv (Competitive nicht getestet)")
task.spawn(function() while true do task.wait(2)
    sComp.Text=S.competitiveOn and ("Aktiv\nHatch: "..S.hatchEgg.."\nBubbles: an") or "Inaktiv"
end end)

-- ── Activate first tab ─────────────────────────────────────────────
do
    local tab=tabs[1]
    activeTab=tab; tab.s.Visible=true
    tw(tab.lb,{TextColor3=C.acc})
    tw(tabLine,{Size=UDim2.new(0,TAB_W,0,2),Position=UDim2.new(0,0,1,-2)})
    recalcHeight()
end

print("[BGS AIO v0.8.3] OK | "..#SEQ._tpModules.." TP | "..#SEQ._bgModules.." BG")
print("Modul-Reihenfolge:")
for i,m in ipairs(SEQ._tpModules) do
    print("  "..i..". "..m.name.." (Prio "..(S.modulePriority[m.name] or 99)..")")
end
