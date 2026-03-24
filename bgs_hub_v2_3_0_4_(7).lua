-- ╔══════════════════════════════════════════════════════╗
-- ║  BGS Hub v2.3 – Delta / Mobile kompatibel           ║
-- ╚══════════════════════════════════════════════════════╝
if not game:IsLoaded() then game.Loaded:Wait() end

local RS  = game:GetService("ReplicatedStorage")
local LP  = game:GetService("Players").LocalPlayer
local VIM = game:GetService("VirtualInputManager")
local TS  = game:GetService("TweenService")
local HS  = game:GetService("HttpService")
local RUN = game:GetService("RunService")

local RemoteFn = RS.Shared.Framework.Network.Remote.RemoteFunction
local RemoteEv = RS.Shared.Framework.Network.Remote.RemoteEvent
local Remote   = require(RS.Shared.Framework.Network.Remote)
local LD       = require(RS.Client.Framework.Services.LocalData)
local Time     = require(RS.Shared.Framework.Utilities.Math.Time)
local QuestUtil= require(RS.Shared.Utils.Stats.QuestUtil)
local FuseUtil = require(RS.Shared.Utils.RebirthMachineUtil)
local GenieQuest=require(RS.Shared.Data.Quests.GenieQuest)
local RiftData = require(RS.Shared.Data.Rifts)
local RiftCosts; pcall(function() RiftCosts = require(RS.Shared.Data.RiftSummonCosts) end)
local EggsData = require(RS.Shared.Data.Eggs)
local PetsData = require(RS.Shared.Data.Pets)  -- for fuse rarity lookup
local MG_Data  = require(RS.Shared.Data.Minigames)
local Bait_Data= require(RS.Shared.Data.FishingBait)
local FishAreas= require(RS.Shared.Data.FishingAreas)
local ShrineValues=require(RS.Shared.Data.ShrineValues)
local SeasonPassData; pcall(function() SeasonPassData=require(RS.Shared.Data.Quests.SeasonPass) end)

-- Instant-Fish Patch
local FishingUtil = require(RS.Shared.Utils.FishingUtil)
FishingUtil.MIN_CAST_DISTANCE   = 10
FishingUtil.MAX_CAST_DISTANCE   = math.huge
FishingUtil.CAST_TIMEOUT        = 0
FishingUtil.MIN_FISH_BITE_DELAY = 0
FishingUtil.MAX_FISH_BITE_DELAY = 0
FishingUtil.BASE_REEL_SPEED     = math.huge
FishingUtil.BASE_FINISH_WINDOW  = 0
FishingUtil.WALL_CLICK_COOLDOWN = 0

-- Auto Pickup Patch – setzt DefaultPickupRadius auf math.huge
-- Kein Remote-Spam nötig, der Client collected automatisch
local _Constants = nil
pcall(function() _Constants = require(RS.Shared.Constants) end)
local function applyPickupPatch()
    if _Constants then
        _Constants.DefaultPickupRadius = math.huge
    end
end
-- Patch nur anwenden wenn in gespeicherter Config aktiv (wird nach loadConfig nochmal geprüft)

local AutoFishModule; pcall(function()
    AutoFishModule = require(RS.Client.Gui.Frames.Fishing.FishingWorldAutoFish)
end)

-- ═══════════════════════════════════════════════════════
--  DELTA / EXECUTOR COMPAT
-- ═══════════════════════════════════════════════════════
local function safeGetInfo(key)
    if getinfo then
        local ok,v = pcall(getinfo, key)
        return ok and v or nil
    end
    return nil
end
local function safeSetInfo(key, val)
    if setinfo then pcall(setinfo, key, val) end
end

-- ═══════════════════════════════════════════════════════
--  CONFIG PERSISTENCE
-- ═══════════════════════════════════════════════════════
local CFG_KEY = "BGS_HUB_v2_Config"

local function saveConfig(S)
    pcall(function()
        local t = {
            mgDiff=S.mgDiff, mgTicket=S.mgTicket,
            clawMax=S.clawMax, clawPrio=S.clawPrio,
            fishArea=S.fishArea, baits=S.baits,
            hatchEgg=S.hatchEgg, hatchPrio=S.hatchPrio,
            hatchPrioOn=S.hatchPrioOn, hatchRareEgg=S.hatchRareEgg,
            dreamerAmt=S.dreamerAmt, sellArea=S.sellArea,
            genieMaxReroll=S.genieMaxReroll,
            genieSkipBubbles=S.genieSkipBubbles,
            genieGoForAny=S.genieGoForAny,
            genieRerollOn=S.genieRerollOn, genieRerollMax=S.genieRerollMax,
            genieQuestPrio=S.genieQuestPrio,
            genieGreenShardOverride=S.genieGreenShardOverride,
            riftEggName=S.riftEggName, riftEggOn=S.riftEggOn,
            riftEggHatchOn=S.riftEggHatchOn, riftEggHatchName=S.riftEggHatchName,
            riftTimeIdx=S.riftTimeIdx, riftLuckIdx=S.riftLuckIdx,
            riftPermanent=S.riftPermanent,
            fuseKeepShiny=S.fuseKeepShiny, fuseKeepMythic=S.fuseKeepMythic,
            fuseOnlyUnlocked=S.fuseOnlyUnlocked,
            lockSecretChance=S.lockSecretChance, lockSecretCount=S.lockSecretCount,
            enchantOn=S.enchantOn, enchantUseCrystal=S.enchantUseCrystal,
            enchantSlot1=S.enchantSlot1, enchantSlot2=S.enchantSlot2,
            gemFarmOn=S.gemFarmOn, gemFarmThreshold=S.gemFarmThreshold,
            gemFarmBoxName=S.gemFarmBoxName,
            modulePriority=S.modulePriority, autosaveOn=S.autosaveOn,
            farmTeamBubble=S.farmTeamBubble,
            farmTeamLuck=S.farmTeamLuck,
            farmTeamSecretLuck=S.farmTeamSecretLuck,
            raceOn=S.raceOn,
            bubbleSellPriorityOn=S.bubbleSellPriorityOn,
            hideHatchAnimOn=S.hideHatchAnimOn,
            autoCollectPickupOn=S.autoCollectPickupOn,
            rainbowEggCoinQuestOn=S.rainbowEggCoinQuestOn,
            goldenOrbOn=S.goldenOrbOn,
            potionEnabled={}, runeEnabled={},
            eggEnabled={}, boxEnabled={},
            chestEnabled={}, riftChestEnabled={},
            spinOn=S.spinOn, spinSelectedIdx=S.spinSelectedIdx,
            wheelOn={}, shrineItemEnabled={},
        }
        for _,it in ipairs(S.potionItems)  do t.potionEnabled[it.Name.."_"..it.Level]=it.enabled end
        for _,it in ipairs(S.runeItems)    do t.runeEnabled[it.Name.."_"..it.Level]=it.enabled end
        for _,it in ipairs(S.eggItems)     do t.eggEnabled[it.Name]=it.enabled end
        for _,it in ipairs(S.boxItems)     do t.boxEnabled[it.Name]=it.enabled end
        for _,it in ipairs(S.chestItems)   do t.chestEnabled[it.ChestName]=it.enabled end
        for _,it in ipairs(S.riftChestItems) do t.riftChestEnabled[it.name]=it.on end
        for _,it in ipairs(S.wheels)       do t.wheelOn[it.label]=it.on end
        for _,it in ipairs(S.shrineItems)  do t.shrineItemEnabled[it.Name.."_"..it.Level]=it.enabled end
        safeSetInfo(CFG_KEY, HS:JSONEncode(t))
    end)
end

local function loadConfig()
    local raw = safeGetInfo(CFG_KEY)
    if not raw or raw == "" then return nil end
    local ok, t = pcall(HS.JSONDecode, HS, raw)
    return ok and t or nil
end

local function applyConfig(S, cfg)
    if not cfg then return end
    local function ap(k) if cfg[k] ~= nil then S[k] = cfg[k] end end
    ap("mgDiff"); ap("mgTicket"); ap("clawMax")
    ap("fishArea"); ap("baits")
    ap("hatchEgg"); ap("hatchPrio"); ap("hatchPrioOn"); ap("hatchRareEgg")
    ap("dreamerAmt"); ap("sellArea")
    ap("genieMaxReroll"); ap("genieSkipBubbles")
    ap("genieGoForAny")
    ap("genieRerollOn"); ap("genieRerollMax")
    ap("genieGreenShardOverride")
    ap("riftEggName"); ap("riftEggOn")
    ap("riftEggHatchOn"); ap("riftEggHatchName")
    ap("riftTimeIdx"); ap("riftLuckIdx"); ap("riftPermanent")
    ap("fuseKeepShiny"); ap("fuseKeepMythic"); ap("fuseOnlyUnlocked")
    ap("lockSecretChance"); ap("lockSecretCount")
    ap("autosaveOn"); ap("raceOn")
    ap("bubbleSellPriorityOn"); ap("hideHatchAnimOn"); ap("autoCollectPickupOn")
    ap("farmTeamBubble"); ap("farmTeamLuck"); ap("farmTeamSecretLuck")
    ap("enchantOn"); ap("enchantUseCrystal")
    ap("enchantSlot1"); ap("enchantSlot2")
    ap("gemFarmOn"); ap("gemFarmThreshold"); ap("gemFarmBoxName")
    ap("spinSelectedIdx"); ap("rainbowEggCoinQuestOn"); ap("goldenOrbOn")
    if cfg.clawPrio then for k,v in pairs(cfg.clawPrio) do S.clawPrio[k]=v end end
    if cfg.genieQuestPrio then for k,v in pairs(cfg.genieQuestPrio) do S.genieQuestPrio[k]=v end end
    if cfg.modulePriority then S.modulePriority = cfg.modulePriority end
    if cfg.potionEnabled then
        for _,it in ipairs(S.potionItems) do
            local k=it.Name.."_"..it.Level
            if cfg.potionEnabled[k]~=nil then it.enabled=cfg.potionEnabled[k] end
        end
    end
    if cfg.runeEnabled then
        for _,it in ipairs(S.runeItems) do
            local k=it.Name.."_"..it.Level
            if cfg.runeEnabled[k]~=nil then it.enabled=cfg.runeEnabled[k] end
        end
    end
    if cfg.eggEnabled   then for _,it in ipairs(S.eggItems)   do if cfg.eggEnabled[it.Name]~=nil   then it.enabled=cfg.eggEnabled[it.Name]   end end end
    if cfg.boxEnabled   then for _,it in ipairs(S.boxItems)   do if cfg.boxEnabled[it.Name]~=nil   then it.enabled=cfg.boxEnabled[it.Name]   end end end
    if cfg.chestEnabled then for _,it in ipairs(S.chestItems) do if cfg.chestEnabled[it.ChestName]~=nil then it.enabled=cfg.chestEnabled[it.ChestName] end end end
    if cfg.riftChestEnabled then for _,it in ipairs(S.riftChestItems) do if cfg.riftChestEnabled[it.name]~=nil then it.on=cfg.riftChestEnabled[it.name] end end end
    if cfg.spinOn~=nil      then S.spinOn=cfg.spinOn end
    if cfg.spinSelectedIdx  then S.spinSelectedIdx=cfg.spinSelectedIdx end
    if cfg.wheelOn  then for _,it in ipairs(S.wheels) do if cfg.wheelOn[it.label]~=nil then it.on=cfg.wheelOn[it.label] end end end
    if cfg.shrineItemEnabled then
        for _,it in ipairs(S.shrineItems) do
            local k=it.Name.."_"..it.Level
            if cfg.shrineItemEnabled[k]~=nil then it.enabled=cfg.shrineItemEnabled[k] end
        end
    end
end

-- ═══════════════════════════════════════════════════════
--  TRANSITION SKIP
-- ═══════════════════════════════════════════════════════
local function killGui(g)
    if g.Name == "TransitionGui" or g.Name == "WorldTransitionGui" then
        g.Enabled = false
        task.defer(function() pcall(g.Destroy, g) end)
    end
end
for _, g in ipairs(LP.PlayerGui:GetChildren()) do killGui(g) end
LP.PlayerGui.ChildAdded:Connect(killGui)

-- ═══════════════════════════════════════════════════════
--  CORE HELPERS
-- ═══════════════════════════════════════════════════════
local function getData()  return LD:Get() end
local function now()      return Time.now() end
local function isReady(k)
    local d = getData()
    return d and now() >= ((d.Cooldowns and d.Cooldowns[k]) or 0)
end
local function ownedPU(name)
    local d = getData()
    return d and d.Powerups and (d.Powerups[name] or 0) or 0
end

-- Touch-safe click helper (Delta + Mobile)
local function onClick(btn, fn)
    btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            fn()
        elseif input.UserInputType == Enum.UserInputType.Touch then
            local startPos = input.Position
            local moved = false
            local moveConn
            moveConn = input.Changed:Connect(function()
                if (input.Position - startPos).Magnitude > 10 then
                    moved = true; moveConn:Disconnect()
                end
            end)
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    moveConn:Disconnect()
                    if not moved then fn() end
                end
            end)
        end
    end)
end

local function tp(pos)
    local char = LP.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if not hrp then return false end
    if hum then hum.PlatformStand = true end
    local a = math.rad(math.random(0, 360))
    hrp.CFrame = CFrame.new(pos + Vector3.new(math.cos(a)*0.5, 1.5, math.sin(a)*0.5),
        Vector3.new(pos.X, pos.Y, pos.Z))
    task.wait(0.05)
    if hum then hum.PlatformStand = false end
    return true
end

local function pressE()
    VIM:SendKeyEvent(true,  Enum.KeyCode.E, false, game)
    task.wait(0.05)
    VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)
end

-- ═══════════════════════════════════════════════════════
--  AUTO PICKUP
--  Funktioniert über Constants.DefaultPickupRadius = math.huge
--  Der Toggle reapplied den Patch (nach Respawn etc.)
-- ═══════════════════════════════════════════════════════
local function collectAllPickups()
    applyPickupPatch()
end

-- ═══════════════════════════════════════════════════════
--  EGG DATA
-- ═══════════════════════════════════════════════════════
local EGG_POS = {
    ["Common Egg"]      = Vector3.new(-80.9,8.2,6.0),
    ["Spotted Egg"]     = Vector3.new(-91.8,8.2,12.3),
    ["Iceshard Egg"]    = Vector3.new(-119.1,8.2,14.0),
    ["Spikey Egg"]      = Vector3.new(-6.1,421.4,162.8),
    ["Magma Egg"]       = Vector3.new(-22.8,2663.6,8.3),
    ["Crystal Egg"]     = Vector3.new(-22.8,2663.6,18.8),
    ["Lunar Egg"]       = Vector3.new(-57.0,6861.0,74.9),
    ["Void Egg"]        = Vector3.new(9.4,10146.3,190.5),
    ["Hell Egg"]        = Vector3.new(-6.8,10146.3,197.6),
    ["Nightmare Egg"]   = Vector3.new(-21.3,10146.3,187.8),
    ["Rainbow Egg"]     = Vector3.new(-36.9,15970.9,49.5),
    ["Infinity Egg"]    = Vector3.new(-105.4,10.6,-27.0),
    ["Inferno Egg"]     = Vector3.new(61.6,-38.3,-36.4),
    ["Icy Egg"]         = Vector3.new(-21427.4,5.6,-100871.0),
    ["Vine Egg"]        = Vector3.new(-19300.1,5.7,18904.8),
    ["Lava Egg"]        = Vector3.new(-17181.2,13.5,-20322.7),
    ["Atlantis Egg"]    = Vector3.new(-13945.9,11.5,-20249.3),
    ["Classic Egg"]     = Vector3.new(-41511.3,7.6,-20486.1),
    ["Showman Egg"]     = Vector3.new(9944.9,25.3,214.4),
    ["Mining Egg"]      = Vector3.new(9924.2,7680.7,244.8),
    ["Cyber Egg"]       = Vector3.new(9919.1,13408.7,242.4),
    ["Neon Egg"]        = Vector3.new(9883.4,20088.2,266.2),
    ["Dreamer Egg"]     = Vector3.new(9.4,10146.0,185.0),
}
local EGG_WORLD = {
    ["Common Egg"]="The Overworld",["Spotted Egg"]="The Overworld",
    ["Iceshard Egg"]="The Overworld",["Spikey Egg"]="The Overworld",
    ["Magma Egg"]="The Overworld",["Crystal Egg"]="The Overworld",
    ["Lunar Egg"]="The Overworld",["Void Egg"]="The Overworld",
    ["Hell Egg"]="The Overworld",["Nightmare Egg"]="The Overworld",
    ["Rainbow Egg"]="The Overworld",["Infinity Egg"]="The Overworld",
    ["Inferno Egg"]="The Overworld",["Dreamer Egg"]="The Overworld",
    ["Icy Egg"]="Seven Seas",["Vine Egg"]="Seven Seas",
    ["Lava Egg"]="Seven Seas",["Atlantis Egg"]="Seven Seas",["Classic Egg"]="Seven Seas",
    ["Showman Egg"]="Minigame Paradise",["Mining Egg"]="Minigame Paradise",
    ["Cyber Egg"]="Minigame Paradise",["Neon Egg"]="Minigame Paradise",
}
local WORLD_SPAWN = {
    ["The Overworld"]     = Vector3.new(56.1,8.2,-102.2),
    ["Seven Seas"]        = Vector3.new(-23648.5,11.0,-123.1),
    ["Minigame Paradise"] = Vector3.new(9913.1,139.3,332.2),
    ["Christmas World"]   = Vector3.new(-340.8,3.5,-409.2),
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
            hrp.CFrame = CFrame.new(spawnPos + Vector3.new(0, 5, 0))
            local t = 0
            repeat task.wait(0.1); t += 0.1; pos = findEggPos(name) until pos or t > 5
        end
        if not pos then pos = EGG_POS[name] end
    end
    if not pos then return false end
    local a = math.rad(math.random(0, 360))
    local dist = math.random(40, 50) / 10
    local safeY = pos.Y + 3
    hrp.CFrame = CFrame.new(
        Vector3.new(pos.X + math.cos(a)*dist, safeY, pos.Z + math.sin(a)*dist),
        Vector3.new(pos.X, safeY, pos.Z)
    )
    return true
end

-- E-Spam läuft als BG-Task solange _hatchSpamActive = true
local _hatchSpamActive = false
local _hatchSpamConn   = nil

local function startESpam()
    if _hatchSpamActive then return end
    _hatchSpamActive = true
    task.spawn(function()
        while _hatchSpamActive do
            pressE()
            task.wait(0.08)
        end
    end)
end

local function stopESpam()
    _hatchSpamActive = false
end

local function hatchEgg(name, tpOnly)
    -- tpOnly = nur TP, kein Spam starten (Spam läuft extern)
    if not tpToEgg(name) then return false end
    if not tpOnly then
        startESpam()
    end
    return true
end

-- Build ALL_WORLD_EGGS list
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

-- ═══════════════════════════════════════════════════════
--  RIFT DATA (dynamisch aus Spieldaten)
-- ═══════════════════════════════════════════════════════
-- Time Index: 1=10m(+1Shard), 2=15m(+2), 3=30m(+4), 4=45m(+8), 5=60m(+16)
-- Luck Index: 1=x5(+1Shard), 2=x10(+2), 3=x15(+3), 4=x20(+4), 5=x25(+5)
local RIFT_TIME_LABELS = {"10m","15m","30m","45m","60m"}
local RIFT_LUCK_LABELS = {"x5","x10","x15","x20","x25"}

-- Build dynamic rift egg+chest lists from game data
local RIFT_EGG_LIST = {}   -- { name=str, world=str }
local RIFT_CHEST_LIST = {} -- { name=str, world=str, displayName=str }

local function buildRiftLists()
    RIFT_EGG_LIST = {}
    RIFT_CHEST_LIST = {}
    -- Determine world for each island name
    local islandWorld = {}
    pcall(function()
        local worldsData = require(RS.Shared.Data.Worlds)
        for worldName, wd in pairs(worldsData) do
            if not wd.Removed then
                for _, island in ipairs(wd.Islands or {}) do
                    islandWorld[island.Name] = worldName
                end
            end
        end
    end)
    -- Scan RiftData
    for riftName, riftInfo in pairs(RiftData) do
        if riftInfo.Ignore then continue end
        if riftInfo.Type == "Egg" then
            local eggData = EggsData[riftInfo.Egg]
            if eggData then
                local world = eggData.World
                if not world and riftInfo.Areas then
                    for _, area in ipairs(riftInfo.Areas) do
                        world = islandWorld[area]; break
                    end
                end
                table.insert(RIFT_EGG_LIST, {
                    name     = riftInfo.Egg,
                    riftKey  = riftName,
                    world    = world or "The Overworld",
                })
            end
        elseif riftInfo.Type == "Chest" then
            local world = nil
            if riftInfo.Areas then
                for _, area in ipairs(riftInfo.Areas) do
                    world = islandWorld[area]; break
                end
            end
            table.insert(RIFT_CHEST_LIST, {
                name        = riftName,
                world       = world or "The Overworld",
                displayName = riftInfo.DisplayName or riftName,
                on          = false,
                lastSummon  = 0,
            })
        end
    end
    table.sort(RIFT_EGG_LIST, function(a,b) return a.name < b.name end)
    table.sort(RIFT_CHEST_LIST, function(a,b) return a.displayName < b.displayName end)
end
pcall(buildRiftLists)

-- ═══════════════════════════════════════════════════════
--  SEQUENCER
-- ═══════════════════════════════════════════════════════
local SEQ = { _tpModules={}, _bgModules={}, _running=false, _blocked=false }

function SEQ.register(name, tickFn)
    table.insert(SEQ._tpModules, {name=name, fn=tickFn, enabled=true, priority=99})
end

function SEQ.registerBG(name, tickFn)
    table.insert(SEQ._bgModules, {name=name, fn=tickFn})
    task.spawn(function()
        repeat task.wait(0.5) until getData()
        while true do
            pcall(tickFn)
            task.wait(0.2)  -- CPU-schonend: 5x/s statt 20x/s
        end
    end)
end

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
    -- Periodisch Priority neu sortieren (alle 10s)
    task.spawn(function()
        repeat task.wait(0.5) until getData()
        while true do
            task.wait(10)
            resortModules(S)
        end
    end)
    task.spawn(function()
        repeat task.wait(0.5) until getData()
        local idx = 1
        while true do
            task.wait(0.1)  -- Hauptloop: 10x/s statt 20x/s
            if SEQ._blocked then task.wait(0.5); continue end
            local mods = SEQ._tpModules
            if #mods == 0 then task.wait(1); continue end
            if idx > #mods then idx = 1 end
            local mod = mods[idx]; idx += 1
            if not mod or not mod.enabled then continue end
            -- Wenn Genie blockiert: nur Genie (Prio 1) darf laufen
            if genieBlocking then
                local prio = S.modulePriority[mod.name] or 99
                if prio > 1 then continue end
            end
            pcall(mod.fn)
        end
    end)
end

-- ═══════════════════════════════════════════════════════
--  STATE (S)
-- ═══════════════════════════════════════════════════════
local genieBlocking  = false
local _genieSpamActive = false
local _genieAtZen    = false
local _genieRerolls  = 0
local _genieReturnCF = nil
local mgActive       = false
local currentTeam    = nil

local S = {
    -- Module priorities
    modulePriority = {
        GemGenie=1, Fishing=2, Hatch=3, SeasonPass=4,
        Rifts=5, KeyChests=6, Board=7, Minigames=8,
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
    hatchOn=false, hatchEgg="Nightmare Egg",
    hatchPrio={nil,nil,nil}, hatchPrioOn=false,
    hatchRareEgg="",
    -- Wheels
    wheels={
        {label="Normal Wheel",     invoke="WheelSpin",           claim="ClaimWheelSpinQueue",           on=false},
        {label="Spring Wheel",     invoke="SpringWheelSpin",     claim="ClaimSpringWheelSpinQueue",     on=false},
        {label="Lunar Wheel",      invoke="LunarWheelSpin",      claim="ClaimLunarYearWheelSpinQueue",  on=false},
        {label="Valentines Wheel", invoke="ValentinesWheelSpin", claim="ClaimValentinesWheelSpinQueue", on=false},
    },
    -- Board
    boardOn=false,
    boardUseDice={useGolden=true,useGiant=true,useNormal=true},
    boardPrioFields={}, boardKnownTiles={},
    boardGoldenMinDist=3, boardMGBubble=false, boardMGEgg="",
    -- Shrine
    shrineOn=false, shrineItems={},
    dreamerOn=false, dreamerAmt=100,
    goldenOrbOn=false,
    -- Bubbles
    bubbleOn=false,
    -- Season Pass
    spOn=false, spStatus="Inaktiv",
    -- Consumables
    potionOn=false, potionItems={},
    runeOn=false,   runeItems={},
    eggOn=false,    eggItems={},
    boxOn=false,    boxItems={},
    -- Key Chests
    chestsOn=false, chestItems={},
    -- Rifts
    riftOn=false,
    riftEggName="Nightmare Egg", riftEggOn=false,
    riftEggHatchOn=false,
    riftEggHatchName="",
    riftTimeIdx=1, riftLuckIdx=1,
    riftPermanent=false,
    riftChestItems=RIFT_CHEST_LIST,
    -- Spin Tickets – ein Dropdown + ein Toggle
    spinTickets={
        {label="Spin Ticket",             invoke="WheelSpin",           claim="ClaimWheelSpinQueue"},
        {label="Spring Spin Ticket",      invoke="SpringWheelSpin",     claim="ClaimSpringWheelSpinQueue"},
        {label="Lunar Spin Ticket",       invoke="LunarWheelSpin",      claim="ClaimLunarYearWheelSpinQueue"},
        {label="Valentine's Spin Ticket", invoke="ValentinesWheelSpin", claim="ClaimValentinesWheelSpinQueue"},
        {label="Festival Spin Ticket",    invoke="WheelSpin",           claim="ClaimWheelSpinQueue"},
        {label="Dark Spin Ticket",        invoke="WheelSpin",           claim="ClaimWheelSpinQueue"},
        {label="OG Spin Ticket",          invoke="WheelSpin",           claim="ClaimWheelSpinQueue"},
        {label="Neon Spin Ticket",        invoke="WheelSpin",           claim="ClaimWheelSpinQueue"},
        {label="Christmas Spin Ticket",   invoke="WheelSpin",           claim="ClaimWheelSpinQueue"},
    },
    spinOn=false,
    spinSelectedIdx=1,  -- Index in spinTickets
    -- Fuse
    fuseOn=false, fuseKeepShiny=true, fuseKeepMythic=true, fuseOnlyUnlocked=true,
    fuseStatus="Inaktiv",
    -- Daily (nur ClaimSeason via SP)
    -- Sell
    sellArea="overworld",
    -- Genie
    genieOn=false, genieMaxReroll=10,
    genieSkipBubbles=false,
    genieGoForAny=false,        -- nimmt sofort besten Slot, ignoriert alle Filter
    genieStatus="Inaktiv", genieSlots={"...","...","..."},
    genieReturnPos=nil,
    genieRerollOn=false, genieRerollMax=50,
    genieQuestPrio={
        ["Green Fragment"]=10000,
        ["Rune Rock"]=0,
        ["Dream Shard"]=0,["Shadow Crystal"]=0,
    },
    genieGreenShardOverride=false,
    -- Auto Enchant (zwei Ziel-Slots, nur Team-Pets)
    enchantOn=false,
    enchantUseCrystal=true,
    enchantSlot1="",   -- Ziel-Enchant Slot 1 (Format: "enchantId/level")
    enchantSlot2="",   -- Ziel-Enchant Slot 2
    enchantStatus="Inaktiv",
    -- Gem Farm (öffnet Boxes wenn Gems unter Threshold)
    gemFarmOn=false,
    gemFarmThreshold=10000,   -- Gems unter diesem Wert → Box-Farm aktivieren
    gemFarmBoxName="Shadow Mystery Box",
    gemFarmStatus="Inaktiv",
    -- Lock Pets
    lockOn=false,
    lockSecretChance=1000000000,
    lockSecretCount=50,
    lockSecretChanceOn=true,
    lockSecretCountOn=true,
    -- Farming
    farmBubbleOn=false,
    farmPlaytimeOn=false,
    farmTeamBubble="",
    farmTeamLuck="",
    farmTeamSecretLuck="",
    farmBubbleTeamOn=false,
    farmLuckTeamOn=false,
    farmSecretLuckTeamOn=false,
    -- Automation
    autoCollectPickupOn=false,
    bubbleSellPriorityOn=false,
    hideHatchAnimOn=false,
    -- Rainbow Egg bei Coin Quest
    rainbowEggCoinQuestOn=false,
    coinQuestBubblesOn=false,
    -- Island Race
    raceOn=false,
    -- Autosave
    autosaveOn=true,
    -- Genie CD display
    _genieCDLeft=0,
    -- Warn
    autoWarnActive=false, autoWarnMsg="",
}

-- Shrine Items
for _, item in ipairs(ShrineValues) do
    if item.Type=="Potion" and (item.Level or 0)>=1 and (item.Level or 0)<=5 then
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
    "Pastel Egg","Bunny Egg","Throwback Egg",
    "Pumpkin Egg","Costume Egg","Sinister Egg","Mutant Egg","Puppet Egg",
    "Christmas Egg","Frost Egg","New Years Egg","Corn Egg",
    "July4th Egg","Candy Egg","Azure Egg","Hellish Egg",
    "Valentine's Egg","Heartbreak Egg","Lunar New Years Egg","Moon Egg",
    "Autumn Egg","Candle Egg","Winter Egg","Petal Egg","Spring Egg",
    "Sakura Egg","Blossom Egg","Royal Egg",
    "Beach Egg","Icecream Egg","Fruit Egg","Fossil Egg","Pirate Egg",
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

-- Load config
do
    local cfg = loadConfig()
    if cfg then applyConfig(S, cfg); print("[BGS Hub v2.3] Config geladen!") end
end
resortModules(S)
-- Pickup-Patch sofort anwenden wenn in Config aktiv
if S.autoCollectPickupOn then applyPickupPatch() end

-- ═══════════════════════════════════════════════════════
--  POSITIONS
-- ═══════════════════════════════════════════════════════
local ZEN_POS          = Vector3.new(-90.8,15958.8,-14.6)
local BOARD_POS        = Vector3.new(10034.2,26.9,171.7)
local RAINBOW_EGG_POS  = Vector3.new(-36.9,15970.9,49.5)
local SELL_POS = {
    overworld = Vector3.new(77.6,8.2,-113.1),
    paradise  = Vector3.new(9921.7,25.7,137.8),
    zen       = Vector3.new(-70.4,6861.5,116.5),
}
local V = Vector3.new
local FISH_POS = {
    starter   = {p=V(-23647.1,9.0,-158.8),  l=V(0.426,0,-0.905)},
    blizzard  = {p=V(-21414.8,5.5,-101008.4),l=V(-0.948,0,0.318)},
    jungle    = {p=V(-19318.9,5.5,18680.7),  l=V(-0.759,0,-0.651)},
    lava      = {p=V(-17247.5,8.6,-20493.5), l=V(-0.447,0,-0.895)},
    atlantis  = {p=V(-13983.5,3.9,-20314.4), l=V(-0.365,0,0.931)},
    dream     = {p=V(-21787.3,6.0,-20621.2), l=V(0.391,0,0.921)},
    classic   = {p=V(-41504.0,10.3,-20579.1),l=V(0.062,0,-0.998)},
}

local _fr = Random.new()
local function fishTP(area)
    local s = FISH_POS[area] or FISH_POS.starter
    local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    local ang = _fr:NextNumber(0, math.pi*2)
    local r   = _fr:NextNumber(0, 2)
    local rad = math.rad(_fr:NextNumber(-1.5, 1.5))
    local l   = V(s.l.X*math.cos(rad)-s.l.Z*math.sin(rad),0,
                   s.l.X*math.sin(rad)+s.l.Z*math.cos(rad)).Unit
    hrp.CFrame = CFrame.new(s.p + V(math.cos(ang)*r, 0, math.sin(ang)*r), s.p + l)
    task.wait(0.3)
    return true
end
local function fishRod()
    Remote:FireServer("EquipRod")
    local d = tick()+5
    while tick()<d do
        task.wait(0.3)
        local c = LP.Character
        if c then for _,v in ipairs(c:GetChildren()) do if v.Name:find("FishingRod") then return end end end
    end
end
local function afOn()
    if not AutoFishModule then return false end
    local ok,v = pcall(function() return AutoFishModule:IsEnabled() end)
    return ok and v
end
local function setAF(v)
    if AutoFishModule then pcall(function() AutoFishModule:SetEnabled(v) end) end
end
local function enableAF()
    if not AutoFishModule then return end
    task.spawn(function()
        task.wait(1)
        if not S.fishOn then return end
        pcall(function() AutoFishModule:SetEnabled(true) end)
        local conn
        conn = AutoFishModule.StateChanged:Connect(function(en)
            if not en and S.fishOn then
                conn:Disconnect()
                task.wait(0.5)
                if S.fishOn then pcall(function() AutoFishModule:SetEnabled(true) end) end
            end
        end)
        task.delay(6, function() pcall(function() conn:Disconnect() end) end)
    end)
end
local function questArea()
    local d = getData(); if not d or not d.Quests then return nil end
    for _, q in ipairs(d.Quests) do
        if (q.Id or ""):sub(1,13)=="sailor-bounty" then
            for i,t in ipairs(q.Tasks or {}) do
                local ok,req = pcall(function() return QuestUtil:GetRequirement(t) end)
                if (q.Progress or {})[i] < (ok and req or 0) and t.Area then return t.Area end
            end
        end
    end
end
local function nextBait()
    local d = getData(); if not d then return end
    for name,en in pairs(S.baits) do
        if en and d.FishingBaits and (d.FishingBaits[name] or 0)>0 then return name end
    end
end

-- ═══════════════════════════════════════════════════════
--  COIN QUEST CHECK
-- ═══════════════════════════════════════════════════════
local function hasCoinQuest()
    local d = getData(); if not d or not d.Quests then return false end
    for _, q in ipairs(d.Quests) do
        if not QuestUtil:IsComplete(q) then
            for _, t in ipairs(q.Tasks or {}) do
                if t.Type == "Collect" or t.Type == "CollectCoins"
                or t.Type == "Coins" or t.Type == "CoinCollect" then
                    return true
                end
            end
        end
    end
    return false
end

-- ═══════════════════════════════════════════════════════
--  GENIE HELPERS
-- ═══════════════════════════════════════════════════════
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
    Collect=false,Sell=true,Invite=true,Group=true,Discord=true,
    AreaUnlock=true,Purchase=true,VisitCabins=true,CollectPresents=true,
}
-- Shiny/Mythic sind standardmäßig AKZEPTIERT (nicht in BAD_TASKS)

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
    for _, t in ipairs(q.Tasks) do
        -- Hatch, Shiny und Mythic Quests gelten als hatchOnly
        if t.Type~="Hatch" and t.Type~="Shiny" and t.Type~="Mythic" then return false end
    end
    return true
end
local function genieRewardScore(rewards)
    local best = 0
    for _, item in ipairs(rewards or {}) do
        local p = S.genieQuestPrio[item.Name or ""] or 0
        if p > best then best = p end
    end
    return best
end
local function fmtItem(item)
    local s = item.Name or "?"
    if item.Level then s = s.." L"..item.Level end
    if item.Amount and item.Amount>1 then s = s.." x"..item.Amount end
    return s
end
local function fmtRewards(rewards)
    local p = {}
    for _, r in ipairs(rewards or {}) do table.insert(p, fmtItem(r)) end
    return table.concat(p, " | ")
end
local function genieQuestHasGreenShard(calc)
    for _, item in ipairs(calc.Rewards or {}) do
        if (item.Name or ""):find("Green") then return true end
    end
    return false
end

local function genieAnalyzeSlots(data)
    local seed = data.GemGenie and data.GemGenie.Seed
    if not seed then return 1, false, {"?","?","?"} end
    local previews = {}; local bestSlot, bestScore = nil, -1; local allBad = true

    for slot = 1, 3 do
        local ok, calc = pcall(GenieQuest, data, seed+(slot-1))
        if not ok or not calc then previews[slot]="?"; continue end
        local bad,badType = genieHasBadTask(calc)
        local bubbles     = genieHasBubbles(calc)
        local hatchOnly   = genieIsHatchOnly(calc)
        local score       = genieRewardScore(calc.Rewards)
        local rewards     = fmtRewards(calc.Rewards)
        local hasGS       = genieQuestHasGreenShard(calc)

        -- Go for Any: ignoriert alle Filter, nimmt einfach besten Score
        if S.genieGoForAny then
            previews[slot]="[ANY] "..(hasGS and "[GS] " or "").."Sc:"..score.." | "..rewards
            allBad = false
            if score > bestScore then bestScore=score; bestSlot=slot end
            continue
        end

        local skipBubbles = S.genieSkipBubbles and bubbles
        local isBad = bad
        -- Green Shard Override: akzeptiert Bubbles+Collect wenn GS dabei
        if hasGS and S.genieGreenShardOverride then
            skipBubbles = false
            if isBad and (badType=="Collect" or badType=="Bubbles") then isBad=false end
        end

        if isBad or skipBubbles then
            previews[slot]="[X] "..(isBad and badType or "Bubbles").." | "..rewards
        elseif hatchOnly then
            previews[slot]="[OK] "..(hasGS and "[GS] " or "").."Sc:"..score.." | "..rewards
            allBad = false
            if score > bestScore then bestScore=score; bestSlot=slot end
        else
            previews[slot]="[~] "..(hasGS and "[GS] " or "").."Mix | "..rewards
            if bestSlot==nil then allBad=false; bestSlot=slot end
        end
    end
    if bestSlot==nil then bestSlot=1 end
    return bestSlot, allBad, previews
end

local function genieQuestIsGood(data)
    local seed = data.GemGenie and data.GemGenie.Seed
    if not seed then return false end
    for slot=1,3 do
        local ok, calc = pcall(GenieQuest, data, seed+(slot-1))
        if not ok or not calc then continue end
        if genieHasBadTask(calc) then continue end
        if S.genieSkipBubbles and genieHasBubbles(calc) then continue end
        local hasPrio = false
        for _,v in pairs(S.genieQuestPrio) do if v>0 then hasPrio=true; break end end
        if not hasPrio then return true end
        for _, item in ipairs(calc.Rewards or {}) do
            if (S.genieQuestPrio[item.Name or ""] or 0) > 0 then return true end
        end
    end
    return false
end

local function genieExecuteQuest(quest)
    local data   = getData()
    local seed   = data and data.GemGenie and data.GemGenie.Seed
    local rewards= {}
    if seed then
        for slot=1,3 do
            local ok, calc = pcall(GenieQuest, data, seed+(slot-1))
            if ok and calc and QuestUtil:Compare(quest,calc) then
                rewards=calc.Rewards or {}; break
            end
        end
    end
    local rInfo = fmtRewards(rewards)
    local sortedTasks = {}
    for i, t in ipairs(quest.Tasks or {}) do
        table.insert(sortedTasks, {idx=i, task=t, isSpecific=(t.Egg and t.Egg~="")})
    end
    table.sort(sortedTasks, function(a,b)
        if a.isSpecific and not b.isSpecific then return true end; return false
    end)
    for _, entry in ipairs(sortedTasks) do
        local taskIdx = entry.idx
        local t = entry.task
        if not S.genieOn then break end
        if t.Type ~= "Hatch" and t.Type ~= "Shiny" and t.Type ~= "Mythic" then continue end
        local eggName = (t.Egg and t.Egg~="") and t.Egg
            or (t.Rarity and RARITY_EGG[t.Rarity]) or "Infinity Egg"
        local req  = QuestUtil:GetRequirement(t)
        local d0   = getData()
        local q0   = d0 and QuestUtil:FindById(d0,"gem-genie")
        if not q0 then break end
        local prog0 = (q0.Progress or {})[taskIdx] or 0
        if prog0 >= req then S.genieStatus="Task "..taskIdx.." fertig"; continue end
        S.genieStatus="Genie ["..taskIdx.."] > "..eggName.." (0/"..req..")"
        if not tpToEgg(eggName) then
            S.genieStatus="WARN: "..eggName.." nicht gefunden"
            task.wait(3)
            if not tpToEgg(eggName) then continue end
        end
        task.wait(0.3)
        _genieSpamActive = true
        task.spawn(function()
            while _genieSpamActive do pressE(); task.wait(0.08) end
        end)
        local elapsed = 0
        repeat
            task.wait(1.5); elapsed += 1.5
            if not S.genieOn then _genieSpamActive=false; return end
            local d2 = getData()
            local q2 = d2 and QuestUtil:FindById(d2,"gem-genie")
            if not q2 then _genieSpamActive=false; break end
            local p2 = (q2.Progress or {})[taskIdx] or 0
            S.genieStatus="Genie ["..taskIdx.."] "..eggName.." "..p2.."/"..req.." | "..rInfo
            if p2>=req or QuestUtil:IsComplete(q2) then _genieSpamActive=false; break end
            if elapsed%30 < 1.5 then
                local hrp    = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
                local eggPos = findEggPos(eggName)
                if hrp and eggPos and (hrp.Position-eggPos).Magnitude>25 then
                    _genieSpamActive=false
                    task.wait(0.1); tpToEgg(eggName); task.wait(0.3)
                    _genieSpamActive=true
                    task.spawn(function()
                        while _genieSpamActive do pressE(); task.wait(0.08) end
                    end)
                end
            end
        until elapsed > 240
        _genieSpamActive = false
        task.wait(0.2)
    end
end

-- Season Pass
local SP_BAD_TASKS = {Collect=true,Sell=true,Invite=true,Group=true,Discord=true,AreaUnlock=true,Purchase=true,VisitCabins=true}
local function spFindActiveQuest(data)
    if not data or not data.Quests then return nil end
    for _, q in ipairs(data.Quests) do
        local id = (q.Id or ""):lower()
        if id:find("season") or id:find("pass") or id:find("hourly") or id:find("daily") then
            if not QuestUtil:IsComplete(q) then return q end
        end
    end
    for _, q in ipairs(data.Quests) do
        if not QuestUtil:IsComplete(q) then
            local hasBad,hasGood=false,false
            for _, t in ipairs(q.Tasks or {}) do
                if SP_BAD_TASKS[t.Type] then hasBad=true end
                if t.Type=="Hatch" or t.Type=="Bubbles" then hasGood=true end
            end
            if hasGood and not hasBad then return q end
        end
    end
    return nil
end
local function spGetProgress(questRef, taskIdx)
    local d=getData(); if not d or not d.Quests then return 0 end
    for _, q in ipairs(d.Quests) do
        if q.Id==questRef.Id then return (q.Progress or {})[taskIdx] or 0 end
    end
    return 0
end
local function spIsComplete(questRef)
    local d=getData(); if not d or not d.Quests then return true end
    for _, q in ipairs(d.Quests) do
        if q.Id==questRef.Id then return QuestUtil:IsComplete(q) end
    end
    return true
end
local _spSpamActive = false
local function spExecuteQuest(quest)
    if not quest or not quest.Tasks then return end
    local tasks={}
    for i, t in ipairs(quest.Tasks) do
        local prio=99
        if t.Type=="Hatch" then prio=(t.Egg and t.Egg~="") and 1 or 2
        elseif t.Type=="Bubbles" then prio=3
        elseif t.Type=="Collect" or t.Type=="CollectCoins" or t.Type=="Coins" then prio=4
        elseif SP_BAD_TASKS[t.Type] then prio=100 end
        table.insert(tasks, {idx=i, task=t, prio=prio})
    end
    table.sort(tasks, function(a,b) return a.prio<b.prio end)
    for _, entry in ipairs(tasks) do
        if not S.spOn then break end
        if spIsComplete(quest) then break end
        local t = entry.task
        local taskIdx = entry.idx
        if entry.prio >= 100 then continue end
        local req  = QuestUtil:GetRequirement(t)
        local prog = spGetProgress(quest, taskIdx)
        if prog >= req then S.spStatus="SP Task "..taskIdx.." fertig"; continue end
        if t.Type=="Hatch" then
            local eggName=(t.Egg and t.Egg~="") and t.Egg
                or (t.Rarity and RARITY_EGG[t.Rarity]) or S.hatchEgg
            S.spStatus="SP Hatch: "..eggName.." "..prog.."/"..req
            if not tpToEgg(eggName) then
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
            -- Rainbow Egg hatchen + Pickups sammeln
            S.spStatus="SP Coins: "..prog.."/"..req
            local elapsed=0
            local spamOn=true
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
                if elapsed%30<0.6 then
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

-- ═══════════════════════════════════════════════════════
--  TP MODULE: GEM GENIE
-- ═══════════════════════════════════════════════════════
SEQ.register("GemGenie", function()
    if not S.genieOn then
        genieBlocking=false; _genieSpamActive=false; _genieAtZen=false
        return false
    end
    -- Genie aktiviert automatisch Bubble Sell Priority
    S.bubbleSellPriorityOn = true
    local data = getData()
    if not data or not data.GemGenie then task.wait(1); return false end

    local activeQuest = QuestUtil:FindById(data,"gem-genie")
    if activeQuest then
        genieBlocking = true
        stopESpam()  -- Hatch-Spam stoppen während Genie läuft
        S.genieStatus = "Quest laeuft..."
        genieExecuteQuest(activeQuest)
        local d2 = getData()
        local q2 = d2 and QuestUtil:FindById(d2,"gem-genie")
        if not q2 or QuestUtil:IsComplete(q2 or activeQuest) then
            S.genieStatus = "Quest abgeschlossen!"
            genieBlocking=false; _genieRerolls=0; _genieAtZen=false
            if _genieReturnCF then
                local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
                local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
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
    local cdLeft = (data.GemGenie.Next or 0) - now()
    S._genieCDLeft = math.max(0, cdLeft)
    if cdLeft > 0 then
        _genieRerolls=0
        local _,_,previews = genieAnalyzeSlots(data)
        S.genieSlots = previews
        S.genieStatus = "CD: "..math.ceil(cdLeft).."s"
        task.wait(math.min(cdLeft, 8))
        return false
    end

    _genieRerolls = 0
    local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if hrp and not _genieAtZen then
        _genieReturnCF = hrp.CFrame
        S.genieStatus = "TP zu Zen..."
        tp(getGenieNPCPos() + Vector3.new(3,0,3))
        task.wait(1.0); pressE(); task.wait(0.5)
        _genieAtZen = true
    end

    data = getData()
    if not data or not data.GemGenie then return false end
    S.genieStatus = "Analysiere Slots..."
    local bestSlot, allBad, previews = genieAnalyzeSlots(data)
    S.genieSlots = previews

    if S.genieRerollOn and not S.genieGoForAny then
        -- Prüfe ob Reroll Orbs vorhanden
        local rerollOrbs = ownedPU("Reroll Orb") or 0
        local isGood = genieQuestIsGood(data)
        if not isGood then
            if rerollOrbs <= 0 then
                -- Keine Orbs → nimmt besten verfügbaren Slot ohne Reroll
                S.genieStatus = "Keine Reroll Orbs → nehme besten Slot"
                -- bestSlot bleibt wie analysiert
            elseif _genieRerolls < S.genieRerollMax then
                S.genieStatus = "Reroll "..((_genieRerolls+1)).."/"..S.genieRerollMax.."..."
                if QuestUtil:FindById(getData(),"gem-genie") then return true end
                pcall(function() RemoteEv:FireServer("RerollGenie") end)
                _genieRerolls += 1
                task.wait(1.5)
                return true
            end
        else
            _genieRerolls = 0
        end
    elseif allBad and not S.genieGoForAny then
        if _genieRerolls >= S.genieMaxReroll then
            bestSlot=1; S.genieStatus="Limit > Slot 1"
        else
            S.genieStatus="Alle schlecht, Reroll ".._genieRerolls.."/"..S.genieMaxReroll
            if QuestUtil:FindById(getData(),"gem-genie") then return true end
            pcall(function() RemoteEv:FireServer("RerollGenie") end)
            _genieRerolls += 1; task.wait(1.5)
            return true
        end
    end

    if QuestUtil:FindById(getData(),"gem-genie") then _genieAtZen=false; return true end
    S.genieStatus = "Starte Slot "..bestSlot
    pcall(Remote.FireServer, Remote, "StartGenieQuest", bestSlot)
    _genieAtZen = false
    local w=0
    repeat task.wait(0.5); w+=0.5
        local d2=getData()
        if d2 and QuestUtil:FindById(d2,"gem-genie") then break end
    until w>8
    return true
end)

-- ═══════════════════════════════════════════════════════
--  TP MODULE: SEASON PASS
-- ═══════════════════════════════════════════════════════
SEQ.register("SeasonPass", function()
    if not S.spOn then S.spStatus="Inaktiv"; _spSpamActive=false; return false end
    -- SP aktiviert automatisch Bubble Sell Priority und Coin-Quest Rainbow Egg
    local prevBubbleSell = S.bubbleSellPriorityOn
    local prevRainbow    = S.rainbowEggCoinQuestOn
    S.bubbleSellPriorityOn  = true
    S.rainbowEggCoinQuestOn = true
    local data=getData(); if not data then return false end
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
    local spQuest = spFindActiveQuest(data)
    if spQuest then
        if spIsComplete(spQuest) then
            pcall(function() RemoteEv:FireServer("ClaimSeasonPassQuestReward") end)
            pcall(function() RemoteEv:FireServer("ClaimDailyQuestReward") end)
            S.spStatus="SP Quest geclaimed!"; task.wait(3); return true
        end
        S.spStatus="SP: "..(spQuest.Id or "?")
        spExecuteQuest(spQuest)
        if spIsComplete(spQuest) then
            pcall(function() RemoteEv:FireServer("ClaimSeasonPassQuestReward") end)
            pcall(function() RemoteEv:FireServer("ClaimDailyQuestReward") end)
            S.spStatus="SP Quest abgeschlossen!"
        end
        task.wait(2)
        S.bubbleSellPriorityOn  = prevBubbleSell
        S.rainbowEggCoinQuestOn = prevRainbow
        return true
    end
    S.spStatus="SP: Kein Quest / warte..."
    S.bubbleSellPriorityOn  = prevBubbleSell
    S.rainbowEggCoinQuestOn = prevRainbow
    return false
end)

-- ═══════════════════════════════════════════════════════
--  TP MODULE: HATCH
--  - Spam E läuft kontinuierlich
--  - TP nur wenn nötig (zu weit vom Egg)
--  - Sell-Priority: stoppt Spam kurz, verkauft, macht weiter
-- ═══════════════════════════════════════════════════════
local _hatchCurrentEgg = ""
local _hatchLastTp     = 0
local _rainbowCoinQuestTimer = 0

SEQ.register("Hatch", function()
    if not S.hatchOn or genieBlocking then
        stopESpam(); _hatchCurrentEgg = ""; return false
    end
    if SEQ._blocked then stopESpam(); return false end
    -- Nicht hatchen wenn SP gerade aktiv spamt
    if _spSpamActive then stopESpam(); return false end

    -- Welches Egg soll gehatcht werden?
    local targetEgg = S.hatchEgg

    -- Prio-Eggs checken
    if S.hatchPrioOn then
        for _, prioEgg in ipairs(S.hatchPrio) do
            if prioEgg and prioEgg ~= "" and findEggPos(prioEgg) then
                targetEgg = prioEgg; break
            end
        end
    end

    -- Rare Egg wenn sichtbar
    if S.hatchRareEgg and S.hatchRareEgg ~= "" and S.hatchRareEgg ~= targetEgg then
        if findEggPos(S.hatchRareEgg) then
            targetEgg = S.hatchRareEgg
        end
    end

    -- Rainbow Egg bei aktiver Coin Quest (30s Timer)
    if S.rainbowEggCoinQuestOn and hasCoinQuest() then
        local elapsed = _rainbowCoinQuestTimer or 0
        if elapsed < 30 then
            targetEgg = "Rainbow Egg"
            _rainbowCoinQuestTimer = elapsed + 0.1  -- SEQ läuft ~10x/s
        else
            _rainbowCoinQuestTimer = 0  -- Timer zurücksetzen, normales Egg weiter
        end
    else
        _rainbowCoinQuestTimer = 0
    end

    -- Bubble Sell wenn voll
    if S.bubbleSellPriorityOn then
        local d = getData()
        if d then
            local bub = d.Bubbles or 0
            local cap = d.MaxBubbles or d.BubbleCap or 0
            if cap > 0 and bub >= cap * 0.97 then
                stopESpam()
                SEQ._blocked = true
                tp(SELL_POS[S.sellArea] or SELL_POS.overworld)
                task.wait(0.3)
                pcall(function() RemoteEv:FireServer("SellPets") end)
                pcall(function() RemoteEv:FireServer("AutoSell") end)
                task.wait(2.5)
                SEQ._blocked = false
                _hatchCurrentEgg = "" -- force re-TP
            end
        end
    end

    -- TP wenn Egg gewechselt oder zu weit
    local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    local eggPos = hrp and findEggPos(targetEgg)
    local needsTp = (targetEgg ~= _hatchCurrentEgg)
        or (hrp and eggPos and (hrp.Position - eggPos).Magnitude > 30)
        or (now() - _hatchLastTp > 60) -- re-TP alle 60s als Fallback

    if needsTp then
        stopESpam()
        if tpToEgg(targetEgg) then
            _hatchCurrentEgg = targetEgg
            _hatchLastTp     = now()
            task.wait(0.3)
            startESpam()
        end
    elseif not _hatchSpamActive then
        -- Spam war gestoppt (z.B. durch Sell) - neu starten
        startESpam()
    end

    -- Pickups sammeln wenn Coin-Quest aktiv
    if S.rainbowEggCoinQuestOn and hasCoinQuest() and S.autoCollectPickupOn then
        collectAllPickups()
    end

    return true
end)

-- ═══════════════════════════════════════════════════════
--  TP MODULE: FISHING
-- ═══════════════════════════════════════════════════════
SEQ.register("Fishing", function()
    if not S.fishOn then if afOn() then setAF(false) end; S.fishAreaLast=nil; return false end
    local bait = nextBait()
    if bait then RemoteEv:FireServer("SetEquippedBait", bait) end
    local target = (S.fishQuest and questArea()) or S.fishArea or "starter"
    if target ~= S.fishAreaLast then
        setAF(false); fishRod()
        if fishTP(target) then fishRod(); enableAF(); S.fishAreaLast=target end
        task.wait(2); return true
    elseif not afOn() then
        fishRod(); fishTP(target); enableAF(); task.wait(2); return true
    else
        return false
    end
end)

-- ═══════════════════════════════════════════════════════
--  TP MODULE: RIFTS
-- ═══════════════════════════════════════════════════════
local _riftEggLastSummon = 0

local function findRiftEggInWorld(eggName)
    -- Sucht das Rift-Egg in workspace (Rendered/Rifts oder direkt)
    local function search(parent)
        for _, child in ipairs(parent:GetChildren()) do
            if child.Name == eggName or child.Name == (eggName.." Rift") then
                local r = child:FindFirstChild("Root") or child:FindFirstChildWhichIsA("BasePart")
                if r then return r.Position end
            end
            local found = search(child)
            if found then return found end
        end
    end
    local rf = workspace:FindFirstChild("Rendered")
    if rf then
        local rifts = rf:FindFirstChild("Rifts")
        if rifts then local p = search(rifts); if p then return p end end
        local p = search(rf); if p then return p end
    end
    return nil
end

SEQ.register("Rifts", function()
    local anyActive = S.riftEggOn
    if not anyActive then
        for _, r in ipairs(S.riftChestItems) do
            if r.on then anyActive=true; break end
        end
    end
    if not anyActive then return false end

    local t = now(); local did = false
    local timeIdx = math.clamp(S.riftTimeIdx or 1, 1, 5)
    local luckIdx = math.clamp(S.riftLuckIdx or 1, 1, 5)
    local COOLDOWN = S.riftPermanent and 0 or (31*60)

    -- Chest Rifts
    for _, r in ipairs(S.riftChestItems) do
        if not r.on then continue end
        local rf = workspace:FindFirstChild("Rendered")
        local riftsF = rf and rf:FindFirstChild("Rifts")
        local chestPart = nil
        if riftsF then
            local cm = riftsF:FindFirstChild(r.name)
            if cm then chestPart = cm:FindFirstChildWhichIsA("BasePart") or cm:FindFirstChild("Root") end
        end

        if chestPart then
            -- Kiste existiert bereits
            r.lastSummon = t
            if not r._tpDone then
                -- Einmaliger TP: 15 Studs über der Kiste
                local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
                local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
                if hrp then
                    local pos = chestPart.Position
                    if hum then hum.PlatformStand = true end
                    hrp.CFrame = CFrame.new(pos + Vector3.new(0, 15, 0), pos)
                    task.wait(0.15)
                    if hum then hum.PlatformStand = false end
                    r._tpDone = true
                    did = true
                end
            end
        elseif t - r.lastSummon >= COOLDOWN then
            -- Kiste spawnen
            local ok = pcall(function()
                RemoteFn:InvokeServer("SummonRift", {
                    Type="Chest", Name=r.name, World=r.world,
                    Time=math.clamp(S.riftTimeIdx or 1, 1, 5),
                })
            end)
            if ok then
                r.lastSummon = t
                r._tpDone = false
                task.wait(2)
                -- Kurz auf Kiste warten
                local searchT = 0
                repeat
                    task.wait(0.5); searchT += 0.5
                    riftsF = workspace:FindFirstChild("Rendered") and workspace.Rendered:FindFirstChild("Rifts")
                    if riftsF then
                        local cm = riftsF:FindFirstChild(r.name)
                        if cm then chestPart = cm:FindFirstChildWhichIsA("BasePart") or cm:FindFirstChild("Root") end
                    end
                until chestPart or searchT > 10
                -- Einmaliger TP nach Spawn
                if chestPart then
                    local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
                    local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
                    if hrp then
                        local pos = chestPart.Position
                        if hum then hum.PlatformStand = true end
                        hrp.CFrame = CFrame.new(pos + Vector3.new(0, 15, 0), pos)
                        task.wait(0.15)
                        if hum then hum.PlatformStand = false end
                        r._tpDone = true
                        did = true
                    end
                end
            end
        end
        task.wait(0.3)
    end

    -- Egg Rift: Spawn + TP + E-Spam
    if S.riftEggOn and S.riftEggName ~= "" then
        local riftEggPos = findRiftEggInWorld(S.riftEggName)
        if riftEggPos then
            local hrp=LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
            local hum=LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
            if hrp and (hrp.Position-riftEggPos).Magnitude>20 then
                stopESpam()
                if hum then hum.PlatformStand=true end
                local a=math.rad(math.random(0,360))
                hrp.CFrame=CFrame.new(
                    riftEggPos+Vector3.new(math.cos(a)*4,1.5,math.sin(a)*4),
                    Vector3.new(riftEggPos.X,riftEggPos.Y,riftEggPos.Z))
                task.wait(0.2)
                if hum then hum.PlatformStand=false end
                task.wait(0.3)
            end
            if not _hatchSpamActive then startESpam() end
            did=true
        elseif t-_riftEggLastSummon>=COOLDOWN then
            local ok=pcall(function()
                RemoteFn:InvokeServer("SummonRift",{
                    Type="Egg", Name=S.riftEggName,
                    World="The Overworld", Time=timeIdx, Luck=luckIdx,
                })
            end)
            if ok then
                _riftEggLastSummon=t; did=true
                task.wait(2)
                local searchT=0; local newPos=nil
                repeat
                    task.wait(0.5); searchT+=0.5
                    newPos=findRiftEggInWorld(S.riftEggName)
                until newPos or searchT>10
                if newPos then
                    local hrp=LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
                    local hum=LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
                    if hrp then
                        stopESpam()
                        if hum then hum.PlatformStand=true end
                        local a=math.rad(math.random(0,360))
                        hrp.CFrame=CFrame.new(
                            newPos+Vector3.new(math.cos(a)*4,1.5,math.sin(a)*4),
                            Vector3.new(newPos.X,newPos.Y,newPos.Z))
                        task.wait(0.2)
                        if hum then hum.PlatformStand=false end
                        task.wait(0.3)
                        startESpam()
                    end
                end
            end
        end
    end
    return did
end)

-- ═══════════════════════════════════════════════════════
--  BG MODULE: HATCH RIFT EGG (nur TP + Hatch, kein Spawn)
--  Für OG Rifts und andere Rifts die bereits existieren
-- ═══════════════════════════════════════════════════════
SEQ.registerBG("HatchRiftEgg", function()
    task.wait(2)
    if not S.riftEggHatchOn or S.riftEggHatchName=="" then return end
    local pos = findRiftEggInWorld(S.riftEggHatchName)
    if not pos then return end
    local hrp=LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    local hum=LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    if not hrp then return end
    if (hrp.Position-pos).Magnitude>20 then
        stopESpam()
        if hum then hum.PlatformStand=true end
        local a=math.rad(math.random(0,360))
        hrp.CFrame=CFrame.new(
            pos+Vector3.new(math.cos(a)*4,1.5,math.sin(a)*4),
            Vector3.new(pos.X,pos.Y,pos.Z))
        task.wait(0.2)
        if hum then hum.PlatformStand=false end
        task.wait(0.3)
    end
    if not _hatchSpamActive then startESpam() end
end)


-- ═══════════════════════════════════════════════════════
--  TP MODULE: KEY CHESTS
-- ═══════════════════════════════════════════════════════
SEQ.register("KeyChests", function()
    if not S.chestsOn then return false end
    local d=getData(); if not d then return false end
    local did=false
    for _, it in ipairs(S.chestItems) do
        if not it.enabled then continue end
        local keys=(d.Powerups or {})[it.KeyName] or 0
        if keys>0 then
            pcall(function() RemoteEv:FireServer("UnlockRiftChest", it.ChestName, it.KeyName) end)
            task.wait(1); did=true
        end
    end
    return did
end)

-- ═══════════════════════════════════════════════════════
--  TP MODULE: AUTO SELL (läuft via BubbleSellMonitor)
-- ═══════════════════════════════════════════════════════
-- AutoSell als TP-Modul entfernt - Sell läuft über BubbleSellMonitor BG

-- ═══════════════════════════════════════════════════════
--  TP MODULE: MINIGAMES
-- ═══════════════════════════════════════════════════════
local function sortedClawItems(bonusItems)
    local sorted={}
    for guid,item in pairs(bonusItems) do
        local p=S.clawPrio[item.Name or ""] or 0
        if p>0 then table.insert(sorted, {guid=guid,name=item.Name or "?",p=p}) end
    end
    table.sort(sorted, function(a,b) return a.p>b.p end)
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
        -- Server schickt BonusItems via ClientEvent zurück nach StartMinigame
        local conn=RemoteEv.OnClientEvent:Connect(function(evName, data)
            if evName=="StartMinigame" and data and data.BonusItems then
                bonusItems=data.BonusItems
            end
        end)
        RemoteEv:FireServer("StartMinigame", name, S.mgDiff)
        task.wait(1.0); conn:Disconnect()
        if bonusItems then
            for _, e in ipairs(sortedClawItems(bonusItems)) do
                if not S.mg[name] then break end
                RemoteEv:FireServer("GrabMinigameItem", e.guid); task.wait(0.15)
            end
        end
    else
        RemoteEv:FireServer("StartMinigame", name, S.mgDiff); task.wait(0.5)
    end
    RemoteEv:FireServer("FinishMinigame")
    mgActive=false; task.wait(1.5)
end

local function bestDice()
    local u=S.boardUseDice or {useGolden=true,useGiant=true,useNormal=true}
    if u.useGolden~=false and ownedPU("Golden Dice")>0 then return "Golden Dice" end
    if u.useGiant~=false  and ownedPU("Giant Dice")>0  then return "Giant Dice" end
    if u.useNormal~=false and ownedPU("Dice")>0         then return "Dice" end
    return nil
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
    local did=false
    for name,en in pairs(S.mg) do
        if en==true and isReady(name) then runMG(name); did=true; break end
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
            pcall(function() RemoteEv:FireServer("SkipMinigameCooldown", best) end)
            task.wait(1); did=true
        end
    end
    return did
end)

SEQ.register("Board", function()
    if not S.boardOn or genieBlocking then return false end
    local hrp=LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if hrp and (hrp.Position-BOARD_POS).Magnitude>500 then tp(BOARD_POS) end
    if S.boardMGEgg and S.boardMGEgg~="" then
        -- tpOnly=true: nur TP, Spam läuft extern via startESpam
        hatchEgg(S.boardMGEgg, true)
        task.wait(0.3)
        startESpam()
    end
    -- Bubble Sell wenn voll
    if S.boardMGBubble then
        local d=getData()
        if d then
            local bub=d.Bubbles or 0; local cap=d.MaxBubbles or d.BubbleCap or 0
            if cap>0 and bub>=cap*0.95 then
                tp(SELL_POS.paradise); task.wait(0.3)
                pcall(function() RemoteEv:FireServer("AutoSell") end)
                task.wait(2); tp(BOARD_POS); task.wait(0.5)
            end
        end
    end
    local dice=bestDice(); if not dice then return false end
    local ok,result=pcall(function() return RemoteFn:InvokeServer("RollDice", dice) end)
    if ok and result then
        task.wait(math.max(0.8,(result.Roll or 1)*0.2))
        pcall(function() RemoteEv:FireServer("ClaimTile") end)
        return true
    end
    task.wait(2); return false
end)

-- ═══════════════════════════════════════════════════════
--  BG MODULES
-- ═══════════════════════════════════════════════════════
SEQ.registerBG("Shrines", function()
    task.wait(2)
    if S.shrineOn then
        local d=getData()
        if d then
            local endTime=d.BubbleShrine and d.BubbleShrine.ShrineBlessingEndTime or 0
            -- Nur spenden wenn Shrine leer (endTime abgelaufen) UND Cooldown bereit
            if endTime <= now() and isReady("Shrine") then
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
            pcall(function() RemoteFn:InvokeServer("DonateToDreamerShrine", math.min(15,shards)) end)
            task.wait(0.3)
        end
    end
end)

-- Golden Orb – eigenes schnelles BG-Modul (0.1s)
SEQ.registerBG("GoldenOrb", function()
    task.wait(0.1)
    if not S.goldenOrbOn then return end
    local d=getData()
    local orbs=d and d.Powerups and (d.Powerups["Golden Orb"] or 0) or 0
    if orbs>0 then
        pcall(function() RemoteEv:FireServer("UseGoldenOrb") end)
    end
end)

SEQ.registerBG("Bubbles", function()
    task.wait(0.13)  -- ~7x/s reicht für BlowBubble
    local coinBubble = S.coinQuestBubblesOn and hasCoinQuest()
    if not S.bubbleOn and not S.farmBubbleOn and not coinBubble then return end
    pcall(function() RemoteEv:FireServer("BlowBubble") end)
end)

-- Bubble Sell Priority – blockiert SEQ wenn Sell stattfindet
SEQ.registerBG("BubbleSellMonitor", function()
    task.wait(1)
    if not S.bubbleSellPriorityOn then return end
    local d=getData(); if not d then return end
    local bub = d.Bubbles or 0
    local cap = d.MaxBubbles or d.BubbleCap or 0
    if cap>0 and bub>=cap*0.97 then
        SEQ._blocked = true
        tp(SELL_POS[S.sellArea] or SELL_POS.overworld); task.wait(0.3)
        pcall(function() RemoteEv:FireServer("SellPets") end)
        pcall(function() RemoteEv:FireServer("AutoSell") end)
        task.wait(2.5)
        SEQ._blocked = false
    end
end)

SEQ.registerBG("Consumables", function()
    task.wait(2)
    if S.potionOn and not genieBlocking then
        local d=getData(); if d then
            for _, it in ipairs(S.potionItems) do
                if not it.enabled then continue end
                for _, p in ipairs(d.Potions or {}) do
                    if p.Name==it.Name and p.Level==it.Level and p.Amount>0 then
                        pcall(function() RemoteEv:FireServer("UsePotion", it.Name, it.Level, 10) end)
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
                        pcall(function() RemoteEv:FireServer("UseRune", it.Name, it.Level, 1) end)
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
                    pcall(function() RemoteEv:FireServer("HatchPowerupEgg", it.Name, math.min(12,count)) end)
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
                        pcall(function() RemoteEv:FireServer("UseGift", it.Name, batch) end)
                        task.wait(0.1); d=getData(); if not d then break end
                        count=(d.Powerups or {})[it.Name] or 0
                    end
                end
                PI.Gift=oldGift
            end
        end
    end
end)

SEQ.registerBG("SpinTickets", function()
    task.wait(0.5)
    if not S.spinOn then return end
    local st = S.spinTickets[S.spinSelectedIdx]
    if not st then S.spinOn=false; return end
    local d = getData(); if not d then return end
    local count = (d.Powerups or {})[st.label] or 0
    if count <= 0 then
        S.spinOn = false  -- automatisch aus wenn leer
        return
    end
    pcall(function() RemoteFn:InvokeServer(st.invoke) end)
    task.wait(0.05)
    pcall(function() RemoteEv:FireServer(st.claim) end)
    task.wait(0.05)
end)

-- Alle Wheels in einem einzigen BG-Modul (spart 3 Threads)
SEQ.registerBG("Wheels", function()
    task.wait(1)
    for _, wheel in ipairs(S.wheels) do
        if not wheel.on then continue end
        pcall(function() RemoteFn:InvokeServer(wheel.invoke) end)
        pcall(function() RemoteEv:FireServer(wheel.claim) end)
        task.wait(0.3)
    end
end)

SEQ.registerBG("Fuse", function()
    task.wait(3)
    if not S.fuseOn then S.fuseStatus="Inaktiv"; return end
    local d=getData(); if not d then return end
    local cd=(d.NextRebirthMachineUse or 0)-now()
    if cd>0 then
        S.fuseStatus="CD: "..math.ceil(cd).."s"
        task.wait(math.min(cd,10)); return
    end
    local NUM_REQ = FuseUtil.NUM_SECRETS_REQUIRED or 5
    local cands={}
    if d.Pets then
        for _, pet in ipairs(d.Pets) do
            -- Rarity kommt aus PetsData[pet.Name], nicht aus pet direkt
            local petInfo = PetsData[pet.Name]
            local isSecret = petInfo and petInfo.Rarity == "Secret"
            if not isSecret then continue end
            -- Kein XL
            if pet.XL == true then continue end
            -- Kein Infinity/Celestial
            if petInfo.Infinity or petInfo.Celestial then continue end
            -- Locked überspringen
            if pet.Locked then continue end
            -- Shiny behalten?
            if S.fuseKeepShiny and pet.Shiny == true then continue end
            -- Mythic behalten?
            if S.fuseKeepMythic and pet.Mythic == true then continue end
            -- Nur Unlocked (bereits im Codex)?
            if S.fuseOnlyUnlocked and not pet.Unlocked then continue end
            table.insert(cands, pet)
        end
    end
    -- Sort by XP ascending (weakest first)
    table.sort(cands, function(a,b) return (a.XP or 0)<(b.XP or 0) end)
    if #cands < NUM_REQ then
        S.fuseStatus="Secrets: "..#cands.."/"..NUM_REQ.." (zu wenig)"
        return
    end
    -- Build ID array
    local ids = table.create(NUM_REQ)
    for i=1,NUM_REQ do
        ids[i] = cands[i].Id or cands[i].UUID or cands[i].GUID
    end
    -- Prüfen ob alle IDs gültig
    for _, id in ipairs(ids) do
        if not id then S.fuseStatus="Fehler: Pet-ID nicht gefunden"; return end
    end
    S.fuseStatus="Fuse: "..NUM_REQ.." Secrets..."
    local ok, err = pcall(function()
        RemoteFn:InvokeServer("UseRebirthMachine", ids)
    end)
    if ok then
        S.fuseStatus="Fuse erfolgreich! ("..#cands-NUM_REQ.." uebrig)"
    else
        S.fuseStatus="Fuse Fehler: "..tostring(err):sub(1,50)
    end
    task.wait(3)
end)

SEQ.registerBG("LockPets", function()
    task.wait(5)
    if not S.lockOn then return end
    local d=getData(); if not d or not d.Pets then return end
    for _, pet in ipairs(d.Pets) do
        -- Rarity aus PetsData, nicht aus pet direkt
        local petInfo = PetsData[pet.Name]
        local isSecret = (petInfo and petInfo.Rarity=="Secret")
            or pet.Rarity=="Secret" or pet.Type=="Secret"
        if not isSecret then continue end
        if pet.Locked then continue end
        local petId = pet.Id or pet.UUID or pet.GUID
        if not petId then continue end
        local shouldLock = false
        if S.lockSecretChanceOn and pet.Chance then
            if pet.Chance >= S.lockSecretChance then shouldLock=true end
        end
        if S.lockSecretCountOn and pet.ExistCount then
            if pet.ExistCount <= S.lockSecretCount then shouldLock=true end
        end
        if shouldLock then
            pcall(function() RemoteEv:FireServer("LockPet", petId, true) end)
            task.wait(0.3)
        end
    end
end)

-- Team switching
local function switchTeam(teamName)
    if not teamName or teamName=="" or teamName==currentTeam then return end
    pcall(function() RemoteEv:FireServer("JoinTeam", teamName) end)
    currentTeam=teamName; task.wait(0.5)
end

SEQ.registerBG("TeamManager", function()
    task.wait(1)
    if S.farmBubbleTeamOn and S.farmTeamBubble~="" then
        switchTeam(S.farmTeamBubble)
    elseif S.farmLuckTeamOn and S.farmTeamLuck~="" then
        switchTeam(S.farmTeamLuck)
    elseif S.farmSecretLuckTeamOn and S.farmTeamSecretLuck~="" then
        switchTeam(S.farmTeamSecretLuck)
    end
end)

SEQ.registerBG("PlaytimeReward", function()
    task.wait(1)
    if not S.farmPlaytimeOn then return end
    -- ClaimAllPlaytime = claiment alle verfügbaren Playtime Rewards auf einmal
    pcall(function() RemoteEv:FireServer("ClaimAllPlaytime") end)
    task.wait(5) -- nicht zu oft feuern
end)

SEQ.registerBG("AutoCollectPickup", function()
    task.wait(5)
    if not S.autoCollectPickupOn then return end
    -- Radius-Patch reapplyen (nach Respawn/Reload könnte er zurückgesetzt sein)
    applyPickupPatch()
end)

-- Hide Hatch Animation – Event-basiert statt Polling (kein CPU-Overhead)
do
    local function hideHatchGui(child)
        if not S.hideHatchAnimOn then return end
        if not child:IsA("ScreenGui") then return end
        local n = child.Name:lower()
        if n:find("hatch") or n:find("afkreveal") or n:find("petreveal") then
            child.Enabled = false
        end
    end
    LP.PlayerGui.ChildAdded:Connect(hideHatchGui)
    -- Einmalig vorhandene GUIs prüfen
    task.spawn(function()
        repeat task.wait(0.5) until getData()
        local sg = LP.PlayerGui:FindFirstChild("ScreenGui")
        if sg then
            sg.ChildAdded:Connect(function(child)
                if not S.hideHatchAnimOn then return end
                if child.Name:lower():find("afkreveal") then child.Visible=false end
            end)
        end
    end)
    -- Schlankes BG-Modul nur für AFKReveal-Check (seltener)
    SEQ.registerBG("HideHatchAnim", function()
        task.wait(0.3)
        if not S.hideHatchAnimOn then return end
        local sg = LP.PlayerGui:FindFirstChild("ScreenGui")
        if not sg then return end
        local afkReveal = sg:FindFirstChild("AFKReveal")
        if afkReveal and afkReveal.Visible then afkReveal.Visible = false end
    end)
end

SEQ.registerBG("Daily", function()
    task.wait(30)  -- nicht zu oft
    local d=getData(); if not d then return end
    if S.spOn then
        pcall(function() RemoteEv:FireServer("ClaimSeason") end)
        pcall(function() RemoteEv:FireServer("BeginSeasonInfinite") end)
    end
end)

-- ═══════════════════════════════════════════════════════
--  BG MODULE: AUTO ENCHANT
--  Nur Team-Pets, zwei Ziel-Slots
--  Remote: RemoteFn:InvokeServer("RerollEnchants", petId36, slotId, lockedSlotId)
--  SlotId Format: "enchantId/level" z.B. "ultra-infinity-luck/1"
-- ═══════════════════════════════════════════════════════
local function getTeamPetIds()
    -- Gibt alle Pet-IDs (36 Zeichen) zurück die im Team sind
    local d = getData(); if not d then return {} end
    local ids = {}
    -- Versuch 1: d.EquippedPets
    if d.EquippedPets then
        if type(d.EquippedPets) == "table" then
            for _, v in pairs(d.EquippedPets) do
                if type(v)=="string" and #v>=36 then
                    table.insert(ids, string.sub(v,1,36))
                end
            end
        end
    end
    -- Versuch 2: pet.Equipped flag
    if #ids==0 and d.Pets then
        for _, pet in ipairs(d.Pets) do
            if pet.Equipped==true then
                local id = pet.Id or pet.UUID or pet.GUID or ""
                if #id>0 then table.insert(ids, string.sub(id,1,36)) end
            end
        end
    end
    return ids
end

local function getPetById(petId36)
    local d = getData(); if not d or not d.Pets then return nil end
    for _, pet in ipairs(d.Pets) do
        local id = string.sub(pet.Id or pet.UUID or pet.GUID or "", 1, 36)
        if id == petId36 then return pet end
    end
    return nil
end

local function enchantSlotId(ench)
    -- Format: "enchantId/level"
    if type(ench)=="table" then
        return (ench.Id or ench.Name or "?") .. "/" .. (ench.Level or 1)
    end
    return tostring(ench)
end

local function petHasEnchant(pet, targetSlotStr)
    if not targetSlotStr or targetSlotStr=="" then return false end
    for _, ench in ipairs(pet.Enchants or {}) do
        if enchantSlotId(ench) == targetSlotStr then return true end
    end
    return false
end

local function petHasBothEnchants(pet)
    local has1 = S.enchantSlot1=="" or petHasEnchant(pet, S.enchantSlot1)
    local has2 = S.enchantSlot2=="" or petHasEnchant(pet, S.enchantSlot2)
    return has1 and has2
end

local function getLockedSlot(pet)
    -- Gibt den SlotId zurück der bereits das Ziel hat (zum Locken)
    if S.enchantSlot1~="" and petHasEnchant(pet, S.enchantSlot1) then
        return S.enchantSlot1
    end
    if S.enchantSlot2~="" and petHasEnchant(pet, S.enchantSlot2) then
        return S.enchantSlot2
    end
    return nil
end

local function getRerollTarget(pet)
    -- Gibt einen Slot zurück der noch nicht das Ziel hat
    for _, ench in ipairs(pet.Enchants or {}) do
        local sid = enchantSlotId(ench)
        if sid ~= S.enchantSlot1 and sid ~= S.enchantSlot2 then
            return sid
        end
    end
    -- Fallback: erster Slot
    local e = (pet.Enchants or {})[1]
    return e and enchantSlotId(e) or nil
end

SEQ.registerBG("AutoEnchant", function()
    task.wait(1.5)
    if not S.enchantOn then S.enchantStatus="Inaktiv"; return end
    local d = getData(); if not d then return end

    local teamIds = getTeamPetIds()
    if #teamIds==0 then S.enchantStatus="Kein Team-Pet gefunden"; return end

    -- Bearbeite jedes Team-Pet
    for _, petId36 in ipairs(teamIds) do
        local pet = getPetById(petId36)
        if not pet then continue end

        -- Fertig wenn beide Ziele erreicht
        if petHasBothEnchants(pet) then
            S.enchantStatus="Alle Ziele erreicht!"
            continue
        end

        local crystals = (d.Powerups or {})["Shadow Crystal"] or 0
        local lockedSlot = getLockedSlot(pet)
        local rerollTarget = getRerollTarget(pet)

        -- Shadow Crystal benutzen (gibt neue Enchants)
        if S.enchantUseCrystal and crystals > 0 then
            S.enchantStatus="ShadowCrystal auf "..petId36:sub(1,8).."..."
            pcall(function() RemoteEv:FireServer("UseShadowCrystal", petId36) end)
            task.wait(1.5)
            -- Pet neu laden
            pet = getPetById(petId36)
            if not pet then continue end
            if petHasBothEnchants(pet) then
                S.enchantStatus="Ziel erreicht nach Crystal!"
                continue
            end
            lockedSlot = getLockedSlot(pet)
            rerollTarget = getRerollTarget(pet)
        end

        -- Reroll: schlechten Slot neu rollen, guten locken
        if rerollTarget then
            S.enchantStatus="RerollEnchants | Lock: "..(lockedSlot or "keiner")
            local ok, result = pcall(function()
                return RemoteFn:InvokeServer("RerollEnchants", petId36, rerollTarget, lockedSlot)
            end)
            if ok and result == "toofast" then
                task.wait(0.5)
            elseif ok then
                task.wait(0.5)
            end
        end

        -- Status update
        pet = getPetById(petId36)
        if pet then
            local enchNames = {}
            for _, e in ipairs(pet.Enchants or {}) do
                table.insert(enchNames, enchantSlotId(e))
            end
            S.enchantStatus = petId36:sub(1,8).."... | "..table.concat(enchNames," + ")
        end
        task.wait(0.5)
    end
end)

-- ═══════════════════════════════════════════════════════
--  BG MODULE: GEM FARM
--  Wenn Gems unter Threshold → Bubble Team → Boxes öffnen
-- ═══════════════════════════════════════════════════════
local _gemFarmActive = false

SEQ.registerBG("GemFarm", function()
    task.wait(5)
    if not S.gemFarmOn then
        _gemFarmActive = false
        S.gemFarmStatus = "Inaktiv"
        return
    end
    local d = getData(); if not d then return end
    local gems = (d.Currency or {}).Gems or d.Gems or 0

    if gems >= S.gemFarmThreshold and not _gemFarmActive then
        S.gemFarmStatus = "Gems OK: "..gems
        return
    end

    -- Gems leer → Farm-Modus
    _gemFarmActive = true
    S.gemFarmStatus = "Farm aktiv | Gems: "..gems

    -- Bubble Team aktivieren wenn gesetzt
    if S.farmTeamBubble ~= "" then
        switchTeam(S.farmTeamBubble)
    end

    -- Boxes öffnen
    local d2 = getData(); if not d2 then return end
    local boxCount = (d2.Powerups or {})[S.gemFarmBoxName] or 0
    if boxCount <= 0 then
        S.gemFarmStatus = "Keine Boxes mehr – deaktiviert"
        S.gemFarmOn = false
        _gemFarmActive = false
        return
    end

    -- PhysicalItem patch für ClaimGift
    local ok2, PI = pcall(function() return require(RS.Client.Effects.PhysicalItem) end)
    if ok2 and PI then
        local oldGift = PI.Gift
        PI.Gift = function(giftId)
            task.spawn(function() pcall(function() Remote:FireServer("ClaimGift", giftId) end) end)
            return nil
        end
        pcall(function() RemoteEv:FireServer("SetSetting","Item Notifications",false) end)
        local batch = math.min(boxCount, 50)
        pcall(function() RemoteEv:FireServer("UseGift", S.gemFarmBoxName, batch) end)
        task.wait(0.5)
        PI.Gift = oldGift
    else
        -- Fallback ohne PI patch
        pcall(function() RemoteEv:FireServer("UseGift", S.gemFarmBoxName, math.min(boxCount,50)) end)
        task.wait(0.5)
    end

    -- Gems nochmal prüfen
    local d3 = getData()
    local gems3 = d3 and ((d3.Currency or {}).Gems or d3.Gems or 0) or 0
    if gems3 >= S.gemFarmThreshold then
        _gemFarmActive = false
        S.gemFarmStatus = "Aufgefüllt: "..gems3.." Gems"
    end
end)

-- ═══════════════════════════════════════════════════════
--  ISLAND RACE
--  Tween von 100 unter Zen bis 100 über Zen
-- ═══════════════════════════════════════════════════════
local ZEN_Y       = 15958.8
local ZEN_X       = -90.8
local ZEN_Z       = -14.6
local RACE_BELOW  = Vector3.new(ZEN_X, ZEN_Y - 100, ZEN_Z)
local RACE_ABOVE  = Vector3.new(ZEN_X, ZEN_Y + 100, ZEN_Z)

task.spawn(function()
    repeat task.wait(0.5) until getData()
    RemoteEv.OnClientEvent:Connect(function(evName, raceData)
        if evName ~= "IslandRaceStart" then return end
        if not S.raceOn then return end
        task.spawn(function()
            local char = LP.Character
            local hrp  = char and char:FindFirstChild("HumanoidRootPart")
            local hum  = char and char:FindFirstChildOfClass("Humanoid")
            if not hrp then return end

            -- TP zum Startpunkt (100 unter Zen)
            if hum then hum.PlatformStand = true end
            hrp.CFrame = CFrame.new(RACE_BELOW)
            task.wait(0.3)

            -- Tween durch die Finish-Linie
            local tweenTime = math.random(60, 90) / 10  -- 6-9 Sekunden
            local tween = TS:Create(hrp,
                TweenInfo.new(tweenTime, Enum.EasingStyle.Linear),
                {CFrame = CFrame.new(RACE_ABOVE)}
            )
            tween:Play()
            tween.Completed:Wait()
            if hum then hum.PlatformStand = false end
        end)
    end)
end)

-- Auto-save
task.spawn(function()
    while true do task.wait(30)
        if S.autosaveOn then saveConfig(S) end
    end
end)

resortModules(S)

-- ═══════════════════════════════════════════════════════
--  UI
-- ═══════════════════════════════════════════════════════
local function tw(o, p, t)
    TS:Create(o, TweenInfo.new(t or 0.14, Enum.EasingStyle.Quint), p):Play()
end

local C = {
    bg  = Color3.fromRGB(11,11,17),
    sur = Color3.fromRGB(19,19,28),
    elv = Color3.fromRGB(27,27,40),
    brd = Color3.fromRGB(44,44,66),
    acc = Color3.fromRGB(99,102,241),
    grn = Color3.fromRGB(72,194,108),
    red = Color3.fromRGB(220,80,80),
    tp  = Color3.fromRGB(228,228,240),
    ts  = Color3.fromRGB(108,108,142),
    off = Color3.fromRGB(38,38,56),
    warn= Color3.fromRGB(255,180,0),
    rar = {
        Common=Color3.fromRGB(255,255,255), Unique=Color3.fromRGB(255,196,148),
        Rare=Color3.fromRGB(255,94,94), Epic=Color3.fromRGB(207,98,255),
        Legendary=Color3.fromRGB(255,213,0), Secret=Color3.fromRGB(255,22,211),
    },
}
local W = 340

-- Destroy old GUI if reloading
local oldGui = LP.PlayerGui:FindFirstChild("BGS_AIO")
if oldGui then oldGui:Destroy() end

local SG = Instance.new("ScreenGui", LP.PlayerGui)
SG.Name="BGS_AIO"; SG.ResetOnSpawn=false; SG.IgnoreGuiInset=true
SG.ZIndexBehavior=Enum.ZIndexBehavior.Sibling

local win = Instance.new("Frame", SG)
win.Size=UDim2.new(0,W,0,44); win.Position=UDim2.new(0,14,0.5,-256)
win.BackgroundColor3=C.bg; win.BorderSizePixel=0; win.Active=true; win.Draggable=false
Instance.new("UICorner",win).CornerRadius=UDim.new(0,13)
local ws=Instance.new("UIStroke",win); ws.Color=C.brd; ws.Thickness=1

local tb=Instance.new("Frame",win); tb.Size=UDim2.new(1,0,0,44)
tb.BackgroundColor3=C.sur; tb.BorderSizePixel=0
Instance.new("UICorner",tb).CornerRadius=UDim.new(0,13)
local tbFix=Instance.new("Frame",tb); tbFix.Size=UDim2.new(1,0,0,13)
tbFix.Position=UDim2.new(0,0,1,-13); tbFix.BackgroundColor3=C.sur; tbFix.BorderSizePixel=0

local ttl=Instance.new("TextLabel",tb)
ttl.Size=UDim2.new(1,-76,1,0); ttl.Position=UDim2.new(0,13,0,0)
ttl.BackgroundTransparency=1; ttl.Text="BGS Hub v2.3"
ttl.TextColor3=C.tp; ttl.Font=Enum.Font.GothamBold; ttl.TextSize=12
ttl.TextXAlignment=Enum.TextXAlignment.Left

local mBtn=Instance.new("TextButton",tb)
mBtn.Size=UDim2.new(0,24,0,24); mBtn.Position=UDim2.new(1,-62,0.5,-12)
mBtn.BackgroundColor3=C.elv; mBtn.BorderSizePixel=0
mBtn.Text="-"; mBtn.TextColor3=C.ts; mBtn.Font=Enum.Font.GothamBold; mBtn.TextSize=14
Instance.new("UICorner",mBtn).CornerRadius=UDim.new(0,6)

local xBtn=Instance.new("TextButton",tb)
xBtn.Size=UDim2.new(0,24,0,24); xBtn.Position=UDim2.new(1,-34,0.5,-12)
xBtn.BackgroundColor3=C.elv; xBtn.BorderSizePixel=0
xBtn.Text="✕"; xBtn.TextColor3=C.red; xBtn.Font=Enum.Font.GothamBold; xBtn.TextSize=11
Instance.new("UICorner",xBtn).CornerRadius=UDim.new(0,6)

-- Show-Button: oben mittig, halbtransparent, erscheint wenn UI versteckt
local showBtn=Instance.new("TextButton",SG)
showBtn.Size=UDim2.new(0,120,0,22)
showBtn.Position=UDim2.new(0.5,-60,0,6)
showBtn.BackgroundColor3=Color3.fromRGB(99,102,241)
showBtn.BackgroundTransparency=0.45
showBtn.BorderSizePixel=0
showBtn.Text="BGS Hub v2.3"
showBtn.TextColor3=Color3.fromRGB(228,228,240)
showBtn.Font=Enum.Font.GothamBold
showBtn.TextSize=11
showBtn.Visible=false
showBtn.ZIndex=50
Instance.new("UICorner",showBtn).CornerRadius=UDim.new(0,11)

-- Manuelles Drag nur über Titelleiste + unteren Handle (verhindert Fenster-Mitziehen beim Swipen)
local UIS = game:GetService("UserInputService")
local _dragActive = false
local _dragStart  = nil
local _dragOrigin = nil

local function attachDrag(target)
    target.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            _dragActive = true
            _dragStart  = input.Position
            _dragOrigin = win.Position
        end
    end)
    target.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            _dragActive = false
        end
    end)
end

UIS.InputChanged:Connect(function(input)
    if not _dragActive then return end
    if input.UserInputType ~= Enum.UserInputType.MouseMovement
    and input.UserInputType ~= Enum.UserInputType.Touch then return end
    local delta   = input.Position - _dragStart
    local vp      = game:GetService("GuiService"):GetGuiInset()
    local screenX = game.Workspace.CurrentCamera.ViewportSize.X
    local screenY = game.Workspace.CurrentCamera.ViewportSize.Y
    local newX = math.clamp(_dragOrigin.X.Offset + delta.X, 0, screenX - win.AbsoluteSize.X)
    local newY = math.clamp(_dragOrigin.Y.Offset + delta.Y, -vp.Y, screenY - 20)
    win.Position = UDim2.new(0, newX, 0, newY)
end)

attachDrag(tb)

-- Warning banner
local warnBanner=Instance.new("Frame",SG)
warnBanner.Size=UDim2.new(0,400,0,40); warnBanner.Position=UDim2.new(0.5,-200,0,10)
warnBanner.BackgroundColor3=C.warn; warnBanner.BorderSizePixel=0; warnBanner.Visible=false; warnBanner.ZIndex=200
Instance.new("UICorner",warnBanner).CornerRadius=UDim.new(0,8)
local warnLbl=Instance.new("TextLabel",warnBanner)
warnLbl.Size=UDim2.new(1,-10,1,0); warnLbl.Position=UDim2.new(0,5,0,0)
warnLbl.BackgroundTransparency=1; warnLbl.TextColor3=Color3.fromRGB(0,0,0)
warnLbl.Font=Enum.Font.GothamBold; warnLbl.TextSize=11; warnLbl.TextWrapped=true
warnLbl.Text=""; warnLbl.ZIndex=201
task.spawn(function()
    while true do task.wait(0.5)
        warnBanner.Visible=S.autoWarnActive; warnLbl.Text=S.autoWarnMsg
    end
end)

-- Tab bar
local TH=33
local tabBar=Instance.new("Frame",win); tabBar.Size=UDim2.new(1,0,0,TH)
tabBar.Position=UDim2.new(0,0,0,44); tabBar.BackgroundColor3=Color3.fromRGB(14,14,21)
tabBar.BorderSizePixel=0; tabBar.ClipsDescendants=true
local tabLine=Instance.new("Frame",tabBar); tabLine.Size=UDim2.new(0,2,0,2)
tabLine.Position=UDim2.new(0,0,1,-2); tabLine.BackgroundColor3=C.acc; tabLine.BorderSizePixel=0

local tabScroll=Instance.new("ScrollingFrame",tabBar)
tabScroll.Size=UDim2.new(1,0,1,0); tabScroll.BackgroundTransparency=1
tabScroll.BorderSizePixel=0; tabScroll.ScrollBarThickness=2
tabScroll.ScrollBarImageColor3=C.brd; tabScroll.CanvasSize=UDim2.new(0,0,0,0)
tabScroll.AutomaticCanvasSize=Enum.AutomaticSize.X
tabScroll.ScrollingDirection=Enum.ScrollingDirection.X

local cnt=Instance.new("Frame",win); cnt.Size=UDim2.new(1,0,1,-77)
cnt.Position=UDim2.new(0,0,0,77); cnt.BackgroundTransparency=1; cnt.ClipsDescendants=true

-- Unterer Drag-Handle
local dragHandle = Instance.new("Frame", win)
dragHandle.Name = "DragHandle"
dragHandle.Size = UDim2.new(0, 80, 0, 5)
dragHandle.Position = UDim2.new(0.5, -40, 1, 4)  -- leicht unterhalb der UI
dragHandle.BackgroundColor3 = Color3.fromRGB(255,255,255)
dragHandle.BackgroundTransparency = 0.55
dragHandle.BorderSizePixel = 0
dragHandle.ZIndex = 1  -- unter anderen UIs
Instance.new("UICorner", dragHandle).CornerRadius = UDim.new(1, 0)
attachDrag(dragHandle)

local tabs,activeTab,minimized={},nil,false

local function recalcHeight()
    if minimized or not activeTab then return end
    local lay=activeTab.s:FindFirstChildOfClass("UIListLayout")
    if lay then
        tw(win,{Size=UDim2.new(0,W,0,math.min(lay.AbsoluteContentSize.Y+77+13+12,572))},0.16)
    end
end

local TAB_DEF={
    "Priority","Eggs","Genie","Shrine","Farming","SP","MG","Fish","Rifts","Enchant","Board","Fuse","Spins","LockPets",
}
local TAB_W=42
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
local _hidden = false
local function setHidden(v)
    _hidden = v
    win.Visible = not v
    showBtn.Visible = v
end
onClick(mBtn, function() setMinimized(not minimized) end)
onClick(xBtn, function() setHidden(true) end)
onClick(showBtn, function() setHidden(false) end)

-- ── UI HELPERS ──────────────────────────────────────────
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
    onClick(clickBtn, function() setOn(not on) end)
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
        bg.Size=UDim2.new(1,0,1,0); bg.BackgroundTransparency=1; bg.Text=""; bg.ZIndex=100
        onClick(bg, function() closeActiveOverlay() end)
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
    local lbl2=Instance.new("TextLabel",row); lbl2.Size=UDim2.new(1,-80,1,0)
    lbl2.Position=UDim2.new(0,10,0,0); lbl2.BackgroundTransparency=1; lbl2.Text=label
    lbl2.TextColor3=C.tp; lbl2.Font=Enum.Font.Gotham; lbl2.TextSize=11
    lbl2.TextXAlignment=Enum.TextXAlignment.Left; lbl2.TextTruncate=Enum.TextTruncate.AtEnd
    lbl2.Active=false; lbl2.Interactable=false
    local minus=Instance.new("TextButton",row)
    minus.Size=UDim2.new(0,24,0,24); minus.Position=UDim2.new(1,-78,0.5,-12)
    minus.BackgroundColor3=C.off; minus.BorderSizePixel=0
    minus.Text="-"; minus.TextColor3=C.ts; minus.Font=Enum.Font.GothamBold; minus.TextSize=14
    Instance.new("UICorner",minus).CornerRadius=UDim.new(0,6)
    local box=Instance.new("TextBox",row)
    box.Size=UDim2.new(0,36,0,24); box.Position=UDim2.new(1,-50,0.5,-12)
    box.BackgroundColor3=C.off; box.BorderSizePixel=0
    box.Text=tostring(initVal); box.TextColor3=C.acc
    box.Font=Enum.Font.GothamBold; box.TextSize=12; box.TextXAlignment=Enum.TextXAlignment.Center
    Instance.new("UICorner",box).CornerRadius=UDim.new(0,6)
    local plus=Instance.new("TextButton",row)
    plus.Size=UDim2.new(0,24,0,24); plus.Position=UDim2.new(1,-22,0.5,-12)
    plus.BackgroundColor3=C.off; plus.BorderSizePixel=0
    plus.Text="+"; plus.TextColor3=C.ts; plus.Font=Enum.Font.GothamBold; plus.TextSize=14
    Instance.new("UICorner",plus).CornerRadius=UDim.new(0,6)
    local value=initVal
    local function setValue(v)
        value=math.clamp(math.floor(tonumber(v) or 0), minV, maxV)
        box.Text=tostring(value); if onChange then onChange(value) end
    end
    onClick(minus, function() setValue(value-1) end)
    onClick(plus,  function() setValue(value+1) end)
    box.FocusLost:Connect(function() setValue(tonumber(box.Text) or value) end)
    box.Focused:Connect(function()    tw(rs,{Color=C.acc,Transparency=0}) end)
    box.FocusLost:Connect(function()  tw(rs,{Color=C.brd,Transparency=0.5}) end)
    return row,setValue
end

local function mkTextInput(parent,label,init,onChange)
    local row=Instance.new("Frame",parent); row.Size=UDim2.new(1,0,0,46)
    row.BackgroundColor3=C.elv; row.BorderSizePixel=0
    Instance.new("UICorner",row).CornerRadius=UDim.new(0,7)
    local lbl2=Instance.new("TextLabel",row); lbl2.Size=UDim2.new(1,0,0,18)
    lbl2.Position=UDim2.new(0,10,0,3); lbl2.BackgroundTransparency=1; lbl2.Text=label
    lbl2.TextColor3=C.ts; lbl2.Font=Enum.Font.Gotham; lbl2.TextSize=9
    lbl2.TextXAlignment=Enum.TextXAlignment.Left; lbl2.Active=false; lbl2.Interactable=false
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

local function mkButton(parent,label,color,fn)
    local b=Instance.new("TextButton",parent); b.Size=UDim2.new(1,0,0,30)
    b.BackgroundColor3=color or C.acc; b.BorderSizePixel=0
    b.Text=label; b.TextColor3=C.tp; b.Font=Enum.Font.GothamBold; b.TextSize=10
    Instance.new("UICorner",b).CornerRadius=UDim.new(0,7)
    onClick(b, fn); return b
end

-- SEQ badge
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

-- ═══════════════════════════════════════════════════════
--  TAB: PRIORITY
-- ═══════════════════════════════════════════════════════
local pPrio=pages["Priority"]
mkSec(pPrio,"Modul-Prioritaet (Slot 1 = hoechste Prioritaet)")
do
    local moduleNames={"GemGenie","SeasonPass","Hatch","Fishing","Rifts","KeyChests","Board","Minigames"}
    local numSlots=#moduleNames
    local slotAssign={}
    do
        local sorted={}
        for _,mn in ipairs(moduleNames) do
            table.insert(sorted,{name=mn,prio=S.modulePriority[mn] or 99})
        end
        table.sort(sorted,function(a,b) return a.prio<b.prio end)
        for i,entry in ipairs(sorted) do slotAssign[i]=entry.name end
    end
    local dropLabels={}
    local function applySlots()
        for i,mn in ipairs(slotAssign) do if mn then S.modulePriority[mn]=i end end
        resortModules(S)
    end
    local function getAvailableOpts(mySlot)
        local used={}
        for i,mn in ipairs(slotAssign) do if i~=mySlot and mn then used[mn]=true end end
        local opts={"(leer)"}
        for _,mn in ipairs(moduleNames) do if not used[mn] then table.insert(opts,mn) end end
        return opts
    end
    for slot=1,numSlots do
        local s=slot
        local cur=slotAssign[s] or "(leer)"
        local _,dLbl=mkDrop(pPrio,"prio_slot"..s,getAvailableOpts(s),cur,
            function(sel)
                if sel~="(leer)" then
                    for i=1,numSlots do
                        if i~=s and slotAssign[i]==sel then
                            slotAssign[i]=nil
                            if dropLabels[i] then dropLabels[i].Text="v  Slot "..i..": (leer)" end
                        end
                    end
                end
                slotAssign[s]=(sel=="(leer)") and nil or sel
                applySlots()
            end,
            function() return getAvailableOpts(s) end,"Slot "..s)
        dropLabels[s]=dLbl
        if dLbl then dLbl.Text="v  Slot "..s..": "..cur end
    end
end
mkSec(pPrio,"Aktuelle Reihenfolge")
local sPrio=mkStat(pPrio,"...")
task.spawn(function() while true do task.wait(2)
    local ln={}
    for i,m in ipairs(SEQ._tpModules) do table.insert(ln,i..". "..m.name) end
    sPrio.Text=#ln>0 and table.concat(ln,"\n") or "Keine Module"
end end)

mkSec(pPrio,"Config speichern (lokal auf Gerät)")
mkStat(pPrio,"Einstellungen werden lokal gespeichert.\nJeder Account mit dieser Datei hat dieselben Settings.")
mkToggle(pPrio,"Auto Save","Alle 30s speichern",S.autosaveOn,nil,function(v) S.autosaveOn=v end)
mkButton(pPrio,"Jetzt speichern",C.acc,function()
    saveConfig(S); print("[BGS Hub] Config gespeichert!")
end)
mkButton(pPrio,"Config loeschen",C.red,function()
    safeSetInfo(CFG_KEY, ""); print("[BGS Hub] Config geloescht!")
end)

-- ═══════════════════════════════════════════════════════
--  TAB: MINIGAMES
-- ═══════════════════════════════════════════════════════
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
        iLbl.BackgroundTransparency=1; iLbl.Text=opt
        iLbl.TextColor3=opt==cur and (DIFF_C[opt] or C.acc) or C.ts
        iLbl.Font=opt==cur and Enum.Font.GothamBold or Enum.Font.Gotham
        iLbl.TextSize=11; iLbl.TextXAlignment=Enum.TextXAlignment.Left
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
for name,data in pairs(MG_Data) do
    mkToggle(pMG,name,math.floor((data.Cooldown or 300)/60).."m CD",false,nil,function(v) S.mg[name]=v end)
end
mkSec(pMG,"Optionen")
mkToggle(pMG,"Super Ticket","Cooldown skippen",S.mgTicket,nil,function(v) S.mgTicket=v end)
mkSec(pMG,"Claw Prioritaet")
mkNumberInput(pMG,"Grab Count",S.clawMax,1,9999,function(v) S.clawMax=v end)
for _,iName in ipairs({"Dragon Plushie","Secret Elixir","Infinity Elixir","Rift Charm",
    "Super Key","Super Ticket","Lucky","Mythic","Speed","Tickets","Golden Dice","Dice Key","Giant Dice","Dice"}) do
    local n=iName
    mkNumberInput(pMG,n,S.clawPrio[n] or 0,0,9999,function(v) S.clawPrio[n]=v end)
end
mkSec(pMG,"Status")
local sMG=mkStat(pMG,"Inaktiv")
task.spawn(function() while true do task.wait(2)
    local d=getData(); if not d then continue end; local ln={}
    for n,en in pairs(S.mg) do if en then
        local cd=((d.Cooldowns and d.Cooldowns[n]) or 0)-now()
        table.insert(ln, cd>0 and ("CD "..n..": "..math.ceil(cd).."s") or ("OK "..n))
    end end
    sMG.Text=#ln>0 and table.concat(ln,"\n") or "Kein MG aktiv"
end end)

-- ═══════════════════════════════════════════════════════
--  TAB: FISHING
-- ═══════════════════════════════════════════════════════
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
    for k,d in pairs(FishAreas) do
        local lb=d.DisplayName or k; table.insert(aN,lb); aBL[lb]=k
    end
    table.sort(aN,function(a,b)
        return ((FishAreas[aBL[a]] or {}).DisplayOrder or 99)
             < ((FishAreas[aBL[b]] or {}).DisplayOrder or 99)
    end)
    mkDrop(pFish,"Area",aN,aN[1] or "Starter",function(v)
        S.fishArea=aBL[v] or "starter"; S.fishAreaLast=nil
    end,nil,"Area")
end
mkSec(pFish,"Bait Queue")
for key,bd in pairs(Bait_Data) do
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

-- ═══════════════════════════════════════════════════════
--  TAB: EGGS
-- ═══════════════════════════════════════════════════════
local pEgg=pages["Eggs"]
mkSec(pEgg,"Base Egg")
mkToggle(pEgg,"Auto Hatch","TP + E-Spam",S.hatchOn,nil,function(v) S.hatchOn=v end)
mkDrop(pEgg,"worldEgg",ALL_WORLD_EGGS,S.hatchEgg,function(sel) S.hatchEgg=sel end,
    function() return ALL_WORLD_EGGS end,"Base Egg")
mkSec(pEgg,"Rare Egg (wenn sichtbar)")
do
    local rareEggList={"(keins)"}
    for _,n in ipairs(ALL_WORLD_EGGS) do table.insert(rareEggList,n) end
    mkDrop(pEgg,"rareEgg",rareEggList,S.hatchRareEgg,function(sel)
        S.hatchRareEgg=(sel=="(keins)") and "" or sel
    end,nil,"Rare Egg")
end
mkSec(pEgg,"Prioritaets-Eggs")
mkToggle(pEgg,"Prioritaet aktiv","Unterbricht normales Hatchen",S.hatchPrioOn,nil,function(v) S.hatchPrioOn=v end)
do
    local slotOpts={"(leer)"}
    for _,n in ipairs(ALL_WORLD_EGGS) do table.insert(slotOpts,n) end
    for i=1,3 do
        local si=i
        local _,dLbl=mkDrop(pEgg,"prio"..si,slotOpts,S.hatchPrio[si] or "(leer)",function(sel)
            S.hatchPrio[si]=(sel=="(leer)") and nil or sel
        end,nil,"Slot "..i)
        if dLbl then dLbl.Text="v  Slot "..i..": "..(S.hatchPrio[i] or "leer") end
    end
end
mkSec(pEgg,"Optionen")
mkToggle(pEgg,"Hide Hatch Animation","Versteckt AFKReveal / PetReveal GUI",S.hideHatchAnimOn,nil,function(v)
    S.hideHatchAnimOn=v
end)
mkSec(pEgg,"Status")
local sEgg=mkStat(pEgg,"Inaktiv")
task.spawn(function() while true do task.wait(2)
    if not S.hatchOn then sEgg.Text="Inaktiv"; continue end
    local pos=findEggPos(S.hatchEgg)
    sEgg.Text=pos
        and ("Hatcht: "..S.hatchEgg.."\nPos: "..math.floor(pos.X)..","..math.floor(pos.Y)..","..math.floor(pos.Z))
        or ("WARN: "..S.hatchEgg.." nicht gefunden")
end end)

-- ═══════════════════════════════════════════════════════
--  TAB: BOARD
-- ═══════════════════════════════════════════════════════
local pBoard=pages["Board"]
mkSec(pBoard,"Auto Board")
mkToggle(pBoard,"Auto Roll","Smart Dice (MG Paradise)",S.boardOn,nil,function(v) S.boardOn=v end)
mkSec(pBoard,"Wuerfel")
mkToggle(pBoard,"Golden Dice","",S.boardUseDice.useGolden,nil,function(v) S.boardUseDice.useGolden=v end)
mkToggle(pBoard,"Giant Dice","",S.boardUseDice.useGiant,nil,function(v) S.boardUseDice.useGiant=v end)
mkToggle(pBoard,"Dice (Normal)","",S.boardUseDice.useNormal,nil,function(v) S.boardUseDice.useNormal=v end)
mkDrop(pBoard,"boardGoldenDist",{"1","2","3","4","5"},tostring(S.boardGoldenMinDist),function(v)
    S.boardGoldenMinDist=tonumber(v) or 3
end,nil,"Golden wenn <= Felder")
mkSec(pBoard,"Egg hatchen (MG Paradise)")
mkToggle(pBoard,"Auto Hatch beim Board","Hatcht Egg neben dem Board",S.boardMGEgg~="",nil,function(v)
    if not v then S.boardMGEgg="" end
end)
do
    local mgEggs={"(keins)","Mining Egg","Cyber Egg","Neon Egg","Showman Egg"}
    local _,boardEggLbl=mkDrop(pBoard,"boardEgg",mgEggs,S.boardMGEgg~="" and S.boardMGEgg or "(keins)",
        function(sel)
            S.boardMGEgg=(sel=="(keins)") and "" or sel
        end,nil,"Egg")
    if boardEggLbl then boardEggLbl.Text="v  Egg: "..(S.boardMGEgg~="" and S.boardMGEgg or "(keins)") end
end
mkSec(pBoard,"Auto Bubble (MG Paradise)")
mkToggle(pBoard,"Auto Bubble","Verkauft wenn Bubbles voll",S.boardMGBubble,nil,function(v)
    S.boardMGBubble=v; S.bubbleOn=v
end)
mkButton(pBoard,"TP > Sell (MG Paradise)",C.acc,function() tp(SELL_POS.paradise) end)
mkSec(pBoard,"Status")
mkButton(pBoard,"TP > Board (MG Paradise)",C.off,function() tp(BOARD_POS) end)
local sBoardI=mkStat(pBoard,"Wuerfel: ?")
task.spawn(function() while true do task.wait(3)
    local d=getData(); if not d then continue end
    local dl={}
    for _,n in ipairs({"Golden Dice","Giant Dice","Dice"}) do
        local c=ownedPU(n); if c>0 then table.insert(dl,n..": x"..c) end
    end
    sBoardI.Text=#dl>0 and table.concat(dl," | ") or "Kein Wuerfel"
end end)

-- ═══════════════════════════════════════════════════════
--  TAB: SHRINE
-- ═══════════════════════════════════════════════════════
local pShrine=pages["Shrine"]
mkSec(pShrine,"Bubble Shrine")
mkToggle(pShrine,"Auto Shrine","Potions spenden",S.shrineOn,nil,function(v) S.shrineOn=v end)
mkSec(pShrine,"Potion-Typ")
do
    -- Grouped by name, dropdown for level
    local shrineNames={}
    local seen={}
    for _,it in ipairs(S.shrineItems) do
        if not seen[it.Name] then seen[it.Name]=true; table.insert(shrineNames,it.Name) end
    end
    for _,name in ipairs(shrineNames) do
        local n=name
        -- toggle enable/disable for this name
        local anyOn=false
        for _,it in ipairs(S.shrineItems) do if it.Name==n and it.enabled then anyOn=true end end
        -- Collect levels for this name
        local levels={}
        for _,it in ipairs(S.shrineItems) do
            if it.Name==n then table.insert(levels,"L"..it.Level.." (XP:"..it.XP..")") end
        end
        -- Toggle row
        mkToggle(pShrine,n,"Spende diese Potion",anyOn,nil,function(v)
            for _,it in ipairs(S.shrineItems) do if it.Name==n then it.enabled=v end end
        end)
    end
end
mkSec(pShrine,"Dreamer Shrine")
mkToggle(pShrine,"Auto Dreamer","15 Dream Shards spenden",S.dreamerOn,nil,function(v) S.dreamerOn=v end)
mkSec(pShrine,"Status")
local sShrine=mkStat(pShrine,"Inaktiv")
task.spawn(function() while true do task.wait(3); local ln={}
    if S.shrineOn then table.insert(ln,"Shrine: "..(isReady("Shrine") and "Bereit" or "warte...")) end
    if S.dreamerOn then table.insert(ln,"Dreamer: "..ownedPU("Dream Shard").." Shards") end
    sShrine.Text=#ln>0 and table.concat(ln,"\n") or "Inaktiv"
end end)

-- ═══════════════════════════════════════════════════════
--  TAB: GENIE
-- ═══════════════════════════════════════════════════════
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
do
    local _greenFragActive = false
    local _savedPrio = {}
    local _savedRerollOn, _savedRerollMax = false, 50
    mkToggle(pGenie,"Reroll til Green Fragment","Rerollt bis Green Fragment Quest (ignoriert alles andere)",false,nil,function(v)
        _greenFragActive = v
        if v then
            for k,val in pairs(S.genieQuestPrio) do _savedPrio[k]=val end
            _savedRerollOn  = S.genieRerollOn
            _savedRerollMax = S.genieRerollMax
            for k in pairs(S.genieQuestPrio) do
                if k ~= "Green Fragment" then S.genieQuestPrio[k]=0 end
            end
            S.genieQuestPrio["Green Fragment"]=10000
            S.genieRerollOn=true
            S.genieRerollMax=9999
            S.genieOn=true
            S.genieStatus="Reroll til Green Fragment..."
            print("[BGS Hub] Reroll til Green Fragment: AN")
        else
            for k,val in pairs(_savedPrio) do S.genieQuestPrio[k]=val end
            S.genieRerollOn  = _savedRerollOn
            S.genieRerollMax = _savedRerollMax
            S.genieStatus="Inaktiv"
            print("[BGS Hub] Reroll til Green Fragment: AUS")
        end
    end)
end
mkToggle(pGenie,"Reroll Quests","Rerollt bis gute Quest",S.genieRerollOn,nil,function(v) S.genieRerollOn=v end)
mkNumberInput(pGenie,"Max Rerolls",S.genieRerollMax,0,9999,function(v) S.genieRerollMax=v end)
mkStat(pGenie,"Wenn Reroll Orbs leer: nimmt beste verfuegbare Quest")
mkSec(pGenie,"Modus")
mkToggle(pGenie,"Go for Any","Nimmt sofort besten Slot – ignoriert ALLE Filter",S.genieGoForAny,nil,function(v)
    S.genieGoForAny=v
    -- Go for Any hat höhere Priorität als Green Shard Override
    if v then S.genieGreenShardOverride=false end
end)
mkSec(pGenie,"Task-Filter (inaktiv wenn Go for Any an)")
mkToggle(pGenie,"Skip Bubbles","AN = Bubble-Quests überspringen",S.genieSkipBubbles,nil,function(v) S.genieSkipBubbles=v end)
mkToggle(pGenie,"Skip Coins/Collect","AN = Coin/Collect-Quests überspringen",false,nil,function(v) GENIE_BAD_TASKS.Collect=v end)
-- Shiny/Mythic sind standardmäßig akzeptiert (kein Skip)
mkSec(pGenie,"Green Shard Override")
mkToggle(pGenie,"Override fuer Green Shard","Bubbles+Coins trotzdem akzeptieren",S.genieGreenShardOverride,nil,function(v) S.genieGreenShardOverride=v end)
mkSec(pGenie,"Reward Prioritaet")
do
    local pItems={
        {"Green Fragment",10000},{"Rune Rock",0},
        {"Dream Shard",0},{"Shadow Crystal",0},
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
mkSec(pGenie,"Slot-Vorschau (live)")
local sSlot1=mkStat(pGenie,"Slot 1: ...")
local sSlot2=mkStat(pGenie,"Slot 2: ...")
local sSlot3=mkStat(pGenie,"Slot 3: ...")
mkButton(pGenie,"Refresh Slots",C.off,function()
    local data=getData()
    if not data or not data.GemGenie then return end
    local _,_,previews=genieAnalyzeSlots(data)
    S.genieSlots=previews
end)
mkSec(pGenie,"Status")
local sGenie=mkStat(pGenie,"Inaktiv")
task.spawn(function() while true do task.wait(1)
    sSlot1.Text="Slot 1: "..(S.genieSlots[1] or "..."):sub(1,45)
    sSlot2.Text="Slot 2: "..(S.genieSlots[2] or "..."):sub(1,45)
    sSlot3.Text="Slot 3: "..(S.genieSlots[3] or "..."):sub(1,45)
    local st=S.genieStatus
    if S._genieCDLeft and S._genieCDLeft>0 then
        st=st.." | CD: "..math.ceil(S._genieCDLeft).."s"
    end
    if _genieRerolls>0 then st=st.."\nRerolls: ".._genieRerolls end
    if genieBlocking then st=st.."\nPrioritaet aktiv" end
    sGenie.Text=st
end end)

-- ═══════════════════════════════════════════════════════
--  TAB: RIFTS
-- ═══════════════════════════════════════════════════════
local pRifts=pages["Rifts"]

-- ── Egg Rift (Spawn + TP + Hatch) ──
mkSec(pRifts,"Egg Rift (Spawn)")
mkToggle(pRifts,"Egg Rift aktiv","Spawnt + TP + E-Spam",S.riftEggOn,nil,function(v) S.riftEggOn=v end)
do
    local eggNames={"(keins)"}
    for _,e in ipairs(RIFT_EGG_LIST) do table.insert(eggNames, e.name) end
    if #eggNames==1 then
        for _,n in ipairs({"Nightmare Egg","Void Egg","Hell Egg","Rainbow Egg",
            "Lunar Egg","Infinity Egg","Mining Egg","Cyber Egg","Neon Egg","Showman Egg"}) do
            table.insert(eggNames,n)
        end
    end
    local _,dLblEgg=mkDrop(pRifts,"riftEgg",eggNames,S.riftEggName,function(sel)
        if sel~="(keins)" then S.riftEggName=sel end
    end,function() return eggNames end,"Egg")
    if dLblEgg then dLblEgg.Text="v  Egg: "..S.riftEggName end
end
mkDrop(pRifts,"riftLuck",RIFT_LUCK_LABELS,RIFT_LUCK_LABELS[S.riftLuckIdx],function(sel)
    for i,v in ipairs(RIFT_LUCK_LABELS) do if v==sel then S.riftLuckIdx=i; break end end
end,nil,"Luck")
mkToggle(pRifts,"Permanent (kein Cooldown)","",S.riftPermanent,nil,function(v) S.riftPermanent=v end)

-- ── Hatch Rift Egg (nur TP + Hatch, kein Spawn) ──
mkSec(pRifts,"Hatch Rift Egg (kein Spawn)")
mkToggle(pRifts,"Hatch Rift Egg","TP + E-Spam wenn Rift gefunden",S.riftEggHatchOn,nil,function(v) S.riftEggHatchOn=v end)
do
    -- Alle bekannten Rift-Eggs + freie Eingabe
    local hatchEggNames={"(keins)"}
    for _,e in ipairs(RIFT_EGG_LIST) do table.insert(hatchEggNames, e.name) end
    -- Zusätzlich OG Rift Eggs die nicht in RIFT_EGG_LIST sein könnten
    local extras={"OG Rift Egg","Aura Rift Egg","Shadow Rift Egg","Classic Rift Egg","Stellaris Rift Egg"}
    for _,n in ipairs(extras) do
        local found=false
        for _,e in ipairs(RIFT_EGG_LIST) do if e.name==n then found=true; break end end
        if not found then table.insert(hatchEggNames,n) end
    end
    local _,dLblHatch=mkDrop(pRifts,"riftHatchEgg",hatchEggNames,
        S.riftEggHatchName~="" and S.riftEggHatchName or "(keins)",
        function(sel)
            S.riftEggHatchName=(sel=="(keins)") and "" or sel
        end,function() return hatchEggNames end,"Egg")
    if dLblHatch then
        dLblHatch.Text="v  Egg: "..(S.riftEggHatchName~="" and S.riftEggHatchName or "(keins)")
    end
end

-- ── Chest Rifts ──
mkSec(pRifts,"Chest Rifts (Spawn + einmaliger TP)")
mkDrop(pRifts,"riftChestTime",RIFT_TIME_LABELS,RIFT_TIME_LABELS[S.riftTimeIdx],function(sel)
    for i,v in ipairs(RIFT_TIME_LABELS) do if v==sel then S.riftTimeIdx=i; break end end
end,nil,"Zeit (alle Kisten)")
local _riftChestsBuilt = false

local function buildChestUI()
    if _riftChestsBuilt then return end
    if #RIFT_CHEST_LIST == 0 then pcall(buildRiftLists) end
    if #RIFT_CHEST_LIST == 0 then
        local fallbackChests={
            {name="golden-chest", world="The Overworld",    displayName="Golden Chest", on=false, lastSummon=0},
            {name="royal-chest",  world="The Overworld",    displayName="Royal Chest",  on=false, lastSummon=0},
            {name="super-chest",  world="The Overworld",    displayName="Super Chest",  on=false, lastSummon=0},
            {name="dice-chest",   world="Minigame Paradise", displayName="Dice Chest",  on=false, lastSummon=0},
        }
        for _,fc in ipairs(fallbackChests) do table.insert(RIFT_CHEST_LIST, fc) end
        S.riftChestItems = RIFT_CHEST_LIST
    end
    _riftChestsBuilt = true
    for _, chest in ipairs(RIFT_CHEST_LIST) do
        local ch = chest
        mkToggle(pRifts, ch.displayName, ch.world, ch.on, nil, function(v)
            ch.on = v
            ch._tpDone = false
        end)
    end
    recalcHeight()
end

task.spawn(function()
    repeat task.wait(0.5) until getData()
    task.wait(1)
    buildChestUI()
end)

mkSec(pRifts,"Status")
local sRifts=mkStat(pRifts,"Inaktiv")
task.spawn(function() while true do task.wait(3)
    local anyOn = S.riftEggOn or S.riftEggHatchOn
    if not anyOn then for _,r in ipairs(S.riftChestItems) do if r.on then anyOn=true; break end end end
    if not anyOn then sRifts.Text="Inaktiv"; continue end
    local d=getData(); if not d then continue end
    local shards=(d.Powerups or {})["Rift Shard"] or 0
    local charms=(d.Powerups or {})["Rift Charm"] or 0
    local ln={"Shards: "..shards.." | Charms: "..charms}
    if S.riftEggOn then
        local cd = _riftEggLastSummon + 31*60 - now()
        table.insert(ln, not S.riftPermanent and cd>0
            and "Egg Spawn CD: "..math.ceil(cd).."s"
            or "Egg Spawn: bereit")
    end
    if S.riftEggHatchOn and S.riftEggHatchName~="" then
        local pos = findRiftEggInWorld(S.riftEggHatchName)
        table.insert(ln, pos and ("Hatch Rift: gefunden!") or ("Hatch Rift: suche "..S.riftEggHatchName))
    end
    sRifts.Text=table.concat(ln,"\n")
end end)

-- TAB CONSUM entfernt (BG-Modul läuft weiterhin für gespeicherte Configs)

-- ═══════════════════════════════════════════════════════
--  TAB: SPINS
-- ═══════════════════════════════════════════════════════
local pSpins=pages["Spins"]
mkSec(pSpins,"Spin Ticket auswählen")

-- Dropdown: welcher Ticket-Typ
do
    local spinLabels={}
    for _,st in ipairs(S.spinTickets) do table.insert(spinLabels,st.label) end
    local _,spinDropLbl=mkDrop(pSpins,"spinSelect",spinLabels,
        S.spinTickets[S.spinSelectedIdx].label,
        function(sel)
            for i,st in ipairs(S.spinTickets) do
                if st.label==sel then S.spinSelectedIdx=i; break end
            end
        end,nil,"Ticket")
    -- Dropdown-Label aktuell halten
    task.spawn(function() while true do task.wait(1)
        if spinDropLbl then
            local st=S.spinTickets[S.spinSelectedIdx]
            if st then spinDropLbl.Text="v  Ticket: "..st.label end
        end
    end end)
end

mkSec(pSpins,"Auto Spin")
local _,spinToggleSetter=mkToggle(pSpins,"Auto Spin","0.05s Spam bis Tickets leer",S.spinOn,nil,function(v)
    S.spinOn=v
end)

-- Toggle automatisch ausschalten wenn Tickets leer → UI updaten
task.spawn(function()
    local wasOn=false
    while true do task.wait(0.5)
        if wasOn and not S.spinOn then
            if spinToggleSetter then spinToggleSetter(false) end
        end
        wasOn=S.spinOn
    end
end)

mkSec(pSpins,"Status")
local sSpins=mkStat(pSpins,"Inaktiv")
task.spawn(function() while true do task.wait(1)
    local d=getData(); if not d then continue end
    local st=S.spinTickets[S.spinSelectedIdx]
    if not st then sSpins.Text="Kein Ticket gewählt"; continue end
    local count=(d.Powerups or {})[st.label] or 0
    if not S.spinOn then
        sSpins.Text="Inaktiv | "..st.label..": "..count.."x"
    else
        sSpins.Text="Spinning: "..st.label.."\nTickets übrig: "..count
    end
end end)

-- ═══════════════════════════════════════════════════════
--  TAB: FARMING
-- ═══════════════════════════════════════════════════════
local pFarm=pages["Farming"]
mkSec(pFarm,"Bubbles")
mkToggle(pFarm,"Auto Bubble","Bubbles spammen (BG)",S.farmBubbleOn,nil,function(v)
    S.farmBubbleOn=v; S.bubbleOn=v
end)
mkToggle(pFarm,"Bubble Sell Priority","Stoppt SEQ wenn Bubbles voll",S.bubbleSellPriorityOn,nil,function(v)
    S.bubbleSellPriorityOn=v
end)
mkDrop(pFarm,"sellArea",{"overworld","paradise","zen"},S.sellArea,function(v) S.sellArea=v end,nil,"Sell Area")

mkSec(pFarm,"Pickups & Coins")
mkToggle(pFarm,"Auto Collect Pickup","Radius = math.huge (sofort aktiv)",S.autoCollectPickupOn,nil,function(v)
    S.autoCollectPickupOn=v
    if v then applyPickupPatch() end
end)
mkToggle(pFarm,"Coin Quest: Bubbles","Bläst Bubbles wenn Coin-Quest aktiv",S.coinQuestBubblesOn,nil,function(v)
    S.coinQuestBubblesOn=v
end)
mkToggle(pFarm,"Coin Quest: Rainbow Egg","Hatcht Rainbow Egg 30s wenn Coin-Quest aktiv",S.rainbowEggCoinQuestOn,nil,function(v)
    S.rainbowEggCoinQuestOn=v
end)
mkToggle(pFarm,"Playtime Reward","Alle 10s (BG)",S.farmPlaytimeOn,nil,function(v) S.farmPlaytimeOn=v end)
mkToggle(pFarm,"Auto Golden Orb","Golden Orb benutzen (BG)",S.goldenOrbOn,nil,function(v) S.goldenOrbOn=v end)

mkSec(pFarm,"Teams (nur 1 aktiv gleichzeitig)")
mkStat(pFarm,"Gehe ins Inventar > Team ausrüsten > dann Button klicken.")
do
    local teamSetters = {}
    local function makeTeamRow(label, sub, stateKeyOn, stateKeyName)
        local _, setter = mkToggle(pFarm, label, sub, S[stateKeyOn], nil, function(v)
            S[stateKeyOn] = v
            if v then
                for k,s in pairs(teamSetters) do
                    if k ~= stateKeyOn then S[k]=false; s(false) end
                end
            end
        end)
        teamSetters[stateKeyOn] = setter
        mkButton(pFarm,"Speichern ("..label..")",C.off,function()
            local d=getData()
            if d and d.TeamEquipped then
                S[stateKeyName]=tostring(d.TeamEquipped)
            end
        end)
        local sStat=mkStat(pFarm,"Gespeichert: "..tostring(S[stateKeyName]))
        task.spawn(function() while true do task.wait(2)
            sStat.Text="Gespeichert: "..tostring(S[stateKeyName])
        end end)
    end
    makeTeamRow("Bubble Team","Fuer Bubbling","farmBubbleTeamOn","farmTeamBubble")
    makeTeamRow("Luck Team","Fuer Luck Farming","farmLuckTeamOn","farmTeamLuck")
    makeTeamRow("Secret Luck Team","Fuer Secret Luck","farmSecretLuckTeamOn","farmTeamSecretLuck")
end

mkSec(pFarm,"Island Race")
mkToggle(pFarm,"Auto Island Race","TP Start → Zen nach 8-15s",S.raceOn,nil,function(v) S.raceOn=v end)

mkSec(pFarm,"Status")
local sFarm=mkStat(pFarm,"Inaktiv")
task.spawn(function() while true do task.wait(2); local ln={}
    if S.farmBubbleOn then table.insert(ln,"Bubbles: aktiv") end
    if S.autoCollectPickupOn then table.insert(ln,"Pickups: aktiv") end
    if S.rainbowEggCoinQuestOn and hasCoinQuest() then table.insert(ln,"Coin Quest: aktiv") end
    if S.raceOn then table.insert(ln,"Race: aktiv") end
    table.insert(ln,"Team: "..(currentTeam or "keins"))
    sFarm.Text=#ln>0 and table.concat(ln,"\n") or "Inaktiv"
end end)

-- ═══════════════════════════════════════════════════════
--  TAB: SEASON PASS
-- ═══════════════════════════════════════════════════════
local pSP=pages["SP"]
mkSec(pSP,"Auto Season Pass")
mkToggle(pSP,"Auto SP","Daily+Hourly + Rewards (TP-SEQ)",S.spOn,nil,function(v) S.spOn=v end)
mkSec(pSP,"Info")
mkStat(pSP,"Verarbeitet Daily & Hourly Quests automatisch.\nHatch-Quests zuerst. Rewards werden geclaimed.\nCoin-Quests: Rainbow Egg + Pickups sammeln.")
mkSec(pSP,"Status")
local sSP=mkStat(pSP,"Inaktiv")
task.spawn(function() while true do task.wait(2); sSP.Text=S.spStatus end end)

-- ═══════════════════════════════════════════════════════
--  TAB: FUSE
-- ═══════════════════════════════════════════════════════
local pFuse=pages["Fuse"]
mkSec(pFuse,"Rebirth Machine")
mkToggle(pFuse,"Auto Fuse","Secrets fused automatisch",S.fuseOn,nil,function(v) S.fuseOn=v end)
mkToggle(pFuse,"Behalte Shinys","",S.fuseKeepShiny,nil,function(v) S.fuseKeepShiny=v end)
mkToggle(pFuse,"Behalte Mythics","",S.fuseKeepMythic,nil,function(v) S.fuseKeepMythic=v end)
mkToggle(pFuse,"Nur Unlocked","Nur Pets die bereits im Codex sind",S.fuseOnlyUnlocked,nil,function(v) S.fuseOnlyUnlocked=v end)
mkSec(pFuse,"Status")
local sFuse=mkStat(pFuse,"Inaktiv")
task.spawn(function() while true do task.wait(2)
    if not S.fuseOn then sFuse.Text="Inaktiv"; continue end
    local d=getData(); if not d then continue end
    local count=0
    if d.Pets then
        for _, pet in ipairs(d.Pets) do
            local petInfo = PetsData[pet.Name]
            local isSecret = petInfo and petInfo.Rarity=="Secret"
            if not isSecret then continue end
            if pet.XL==true then continue end
            if petInfo.Infinity or petInfo.Celestial then continue end
            if pet.Locked then continue end
            if S.fuseKeepShiny  and pet.Shiny==true  then continue end
            if S.fuseKeepMythic and pet.Mythic==true then continue end
            if S.fuseOnlyUnlocked and not pet.Unlocked then continue end
            count+=1
        end
    end
    local req=FuseUtil.NUM_SECRETS_REQUIRED or 5
    sFuse.Text=S.fuseStatus.."\nFuseable: "..count.."/"..req
end end)

-- ═══════════════════════════════════════════════════════
--  TAB: LOCK PETS
-- ═══════════════════════════════════════════════════════
local pLock=pages["LockPets"]
mkSec(pLock,"Auto Lock Secrets")
mkToggle(pLock,"Lock Pets aktiv","",S.lockOn,nil,function(v) S.lockOn=v end)
mkToggle(pLock,"Nach Chance","Lock wenn Chance >= Threshold",S.lockSecretChanceOn,nil,function(v) S.lockSecretChanceOn=v end)
mkNumberInput(pLock,"Chance Threshold (1/X)",S.lockSecretChance,1,200000000000000,function(v) S.lockSecretChance=v end)
mkToggle(pLock,"Nach Anzahl","Lock wenn ExistCount <=",S.lockSecretCountOn,nil,function(v) S.lockSecretCountOn=v end)
mkNumberInput(pLock,"Count Threshold",S.lockSecretCount,1,100000000,function(v) S.lockSecretCount=v end)
mkSec(pLock,"Status")
local sLock=mkStat(pLock,"Inaktiv")
task.spawn(function() while true do task.wait(5)
    if not S.lockOn then sLock.Text="Inaktiv"; continue end
    local d=getData(); if not d or not d.Pets then continue end
    local total,locked=0,0
    for _, pet in ipairs(d.Pets) do
        local petInfo = PetsData[pet.Name]
        if (petInfo and petInfo.Rarity=="Secret") or pet.Rarity=="Secret" then
            total+=1; if pet.Locked then locked+=1 end
        end
    end
    sLock.Text="Secrets: "..total.." | Gelockt: "..locked
end end)

-- ═══════════════════════════════════════════════════════
--  TAB: ENCHANT
-- ═══════════════════════════════════════════════════════
local pEnchant=pages["Enchant"]
mkSec(pEnchant,"Auto Enchant (nur Team-Pets)")
mkToggle(pEnchant,"Auto Enchant","Shadow Crystal + Reroll",S.enchantOn,nil,function(v)
    S.enchantOn=v
end)
mkToggle(pEnchant,"Shadow Crystal","Standard: an",S.enchantUseCrystal,nil,function(v)
    S.enchantUseCrystal=v
end)
mkSec(pEnchant,"Ziel Enchants")
mkStat(pEnchant,"Format: enchantId/level z.B. ultra-infinity-luck/1\nLeer = kein Ziel, stoppt nicht automatisch.")
mkTextInput(pEnchant,"Enchant 1",S.enchantSlot1,function(v) S.enchantSlot1=v end)
mkTextInput(pEnchant,"Enchant 2",S.enchantSlot2,function(v) S.enchantSlot2=v end)
mkSec(pEnchant,"Gem Farm")
mkToggle(pEnchant,"Gem Farm aktiv","Pausiert alles, farmt Boxes wenn Gems leer",S.gemFarmOn,nil,function(v)
    S.gemFarmOn=v
end)
mkStat(pEnchant,"Beste Box: Shadow Mystery Box (Shadow Egg farmen)")
do
    local boxNames={
        "Shadow Mystery Box","Infinity Mystery Box","OG Mystery Box",
        "Golden Box","Mystery Box","Spring Mystery Box","Sakura Mystery Box",
    }
    local _,gemBoxLbl=mkDrop(pEnchant,"gemBox",boxNames,S.gemFarmBoxName,function(v)
        S.gemFarmBoxName=v
    end,nil,"Box")
    if gemBoxLbl then gemBoxLbl.Text="v  Box: "..S.gemFarmBoxName end
end
mkNumberInput(pEnchant,"Gems Threshold",S.gemFarmThreshold,100,10000000,function(v) S.gemFarmThreshold=v end)
mkSec(pEnchant,"Status")
local sEnchant=mkStat(pEnchant,"Inaktiv")
task.spawn(function() while true do task.wait(2)
    local d=getData(); if not d then continue end
    local crystals=(d.Powerups or {})["Shadow Crystal"] or 0
    local gems=(d.Currency or {}).Gems or d.Gems or 0
    local ln={}
    if S.enchantOn then
        table.insert(ln,S.enchantStatus)
        table.insert(ln,"Crystals: "..crystals)
    else
        table.insert(ln,"Enchant: Inaktiv | Crystals: "..crystals)
    end
    if S.gemFarmOn then
        table.insert(ln,S.gemFarmStatus.."\nGems: "..gems)
    end
    sEnchant.Text=table.concat(ln,"\n")
end end)

mkSec(pEnchant,"Config")
mkToggle(pEnchant,"Auto Save","Alle 30s speichern",S.autosaveOn,nil,function(v) S.autosaveOn=v end)
mkButton(pEnchant,"Jetzt speichern",C.acc,function()
    saveConfig(S); print("[BGS Hub] Config gespeichert!")
end)
mkButton(pEnchant,"Config loeschen",C.red,function()
    safeSetInfo(CFG_KEY,""); print("[BGS Hub] Config geloescht!")
end)

-- ═══════════════════════════════════════════════════════
--  ACTIVATE FIRST TAB + START
-- ═══════════════════════════════════════════════════════
do
    local tab=tabs[1]
    activeTab=tab; tab.s.Visible=true
    tw(tab.lb,{TextColor3=C.acc})
    tw(tabLine,{Size=UDim2.new(0,TAB_W,0,2),Position=UDim2.new(0,0,1,-2)})
    recalcHeight()
end

SEQ.start()
print("[BGS Hub v2.3] Geladen! Delta/Mobile ready.")
