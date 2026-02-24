-- BGS Infinity -- Sailor Quest + Gem Genie v2
-- Genie: liest echte Slot-Rewards, waehlt besten Slot
-- Sailor: Position pro Insel selbst bestimmbar

if not game:IsLoaded() then game.Loaded:Wait() end

local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Players           = game:GetService("Players")
local LocalPlayer       = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")

-- Remote
local RE
pcall(function()
    RE = ReplicatedStorage.Shared.Framework.Network.Remote.RemoteEvent
end)
local function fire(action, ...)
    if RE then pcall(function() RE:FireServer(action, ...) end) end
end

-- LocalData (fuer Genie Seed/Quests lesen)
local LocalData
pcall(function()
    LocalData = require(ReplicatedStorage.Client.Framework.Services.LocalData)
end)

local function getLD()
    if not LocalData then return nil end
    local ok, d = pcall(function() return LocalData:Get() end)
    return ok and d or nil
end

-- ============================================================
-- GENIE REWARD PRIORITAET
-- Beste Rewards zuerst (Shadow Crystal > Elixiere > Lv6 Potions > Rest)
-- ============================================================
local REWARD_PRIORITY = {
    ["Shadow Crystal"]        = 100,
    ["Secret Elixir"]         = 90,
    ["Egg Elixir"]            = 88,
    ["Infinity Elixir"]       = 85,
    ["Lunar New Years Lantern"] = 80,
    ["Green Fragment"]        = 78,
    ["Lunar Spin Ticket"]     = 70,
    ["Lucky Lv6"]             = 65,
    ["Speed Lv6"]             = 64,
    ["Coins Lv6"]             = 63,
    ["Mythic Lv6"]            = 62,
    ["Royal Key"]             = 55,
    ["Moon Key"]              = 54,
    ["Lucky Lv5"]             = 45,
    ["Speed Lv5"]             = 44,
    ["Coins Lv5"]             = 43,
    ["Mythic Lv5"]            = 42,
    ["Power Orb"]             = 30,
    ["Reroll Orb"]            = 25,
    ["Dream Shard"]           = 20,
    ["Spin Ticket"]           = 15,
    ["Lucky Lv4"]             = 10,
    ["Speed Lv4"]             = 9,
    ["Coins Lv4"]             = 8,
    ["Mythic Lv4"]            = 7,
}

-- Liest die Rewards eines Genie-Slots aus dem GUI
-- Die GUI baut die Karten aus LocalData.GemGenie.Seed + (slot-1)
-- Rewards sind in den Card-Frames sichtbar
local function getSlotRewards(slotIndex)
    local rewards = {}
    pcall(function()
        local cards = LocalPlayer.PlayerGui.ScreenGui.GemGenie.Cards
        local slot = nil
        local count = 0
        for _, child in ipairs(cards:GetChildren()) do
            if child:IsA("Frame") and child.Name ~= "Template" then
                count = count + 1
                if count == slotIndex then slot = child; break end
            end
        end
        if not slot then return end
        local rewardContainer = slot:FindFirstChild("Inner", true)
            and slot.Inner:FindFirstChild("Content", true)
            and slot.Inner.Content:FindFirstChild("Rewards", true)
        if not rewardContainer then return end
        for _, item in ipairs(rewardContainer:GetChildren()) do
            if item:IsA("Frame") then
                -- Name des Rewards aus Attribut oder Label
                local name = item:GetAttribute("ItemName")
                    or (item:FindFirstChild("Label") and item.Label.Text)
                    or item.Name
                if name and name ~= "Template" then
                    rewards[#rewards+1] = name
                end
            end
        end
    end)
    return rewards
end

-- Berechnet Score fuer einen Slot basierend auf Rewards
local function scoreSlot(slotIndex)
    local rewards = getSlotRewards(slotIndex)
    local best = 0
    local bestName = "?"
    for _, r in ipairs(rewards) do
        local score = REWARD_PRIORITY[r] or 1
        if score > best then best = score; bestName = r end
    end
    return best, bestName, rewards
end

-- Findet den besten Slot
local function findBestSlot()
    local bestSlot = 1
    local bestScore = -1
    local bestReward = "?"
    for i = 1, 3 do
        local score, name = scoreSlot(i)
        if score > bestScore then
            bestScore = score
            bestSlot = i
            bestReward = name
        end
    end
    return bestSlot, bestReward, bestScore
end

-- Quest-Typ lesen (fuer Auto-Farm Hinweis)
local function getQuestTask(slotIndex)
    local task_info = ""
    pcall(function()
        local cards = LocalPlayer.PlayerGui.ScreenGui.GemGenie.Cards
        local count = 0
        for _, child in ipairs(cards:GetChildren()) do
            if child:IsA("Frame") and child.Name ~= "Template" then
                count = count + 1
                if count == slotIndex then
                    local tasks = child:FindFirstChild("Inner", true)
                        and child.Inner:FindFirstChild("Content", true)
                        and child.Inner.Content:FindFirstChild("Tasks", true)
                    if tasks then
                        for _, t in ipairs(tasks:GetChildren()) do
                            if t:IsA("Frame") then
                                local lbl = t:FindFirstChild("Label")
                                if lbl then task_info = lbl.Text; break end
                            end
                        end
                    end
                    break
                end
            end
        end
    end)
    return task_info
end

-- ============================================================
-- FISHING POSITIONEN (speicherbar pro Insel)
-- ============================================================
local FISH_WORLDS = {
    { name = "Fisher's Island",   area = "Fisher's Island",   fallback = Vector3.new(-23663.1, 5.8,  6.9),    pos = nil, cf = nil },
    { name = "Blizzard Hills",    area = "Blizzard Hills",    fallback = Vector3.new(-21425.1, 4.1,  -100922.3), pos = nil, cf = nil },
    { name = "Poison Jungle",     area = "Poison Jungle",     fallback = Vector3.new(-19331.6, 4.6,  18763.0), pos = nil, cf = nil },
    { name = "Infernite Volcano", area = "Infernite Volcano", fallback = Vector3.new(-17252.8, 7.2,  -20406.8), pos = nil, cf = nil },
    { name = "Lost Atlantis",     area = "Lost Atlantis",     fallback = Vector3.new(-13946.1, 5.7,  -20431.6), pos = nil, cf = nil },
    { name = "Dream Island",      area = "Dream Island",      fallback = Vector3.new(-21817.9, 6.3,  -20524.0), pos = nil, cf = nil },
    { name = "Classic Island",    area = "Classic Island",    fallback = Vector3.new(-41525.7, 6.4,  -20508.7), pos = nil, cf = nil },
}

local function tpToWorld(world)
    -- Eigene gespeicherte Position hat Prioritaet (inkl. Blickrichtung)
    if world.cf then
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if root then root.CFrame = world.cf; return end
    end
    -- Server-Teleport via IslandTeleport Spawn
    local ok = pcall(function()
        local spawn = Workspace.Worlds["Seven Seas"].Areas
            :FindFirstChild(world.area)
            :FindFirstChild("IslandTeleport")
            :FindFirstChild("Spawn")
        fire("Teleport", spawn:GetFullName())
    end)
    -- Fallback: direkte Position
    if not ok then
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if root then root.CFrame = CFrame.new(world.fallback + Vector3.new(0,3,0)) end
    end
end

-- STATE
local fishing       = false
local genieRunning  = false
local autoAccept    = false
local genieInterval = 4
local selectedWorld = FISH_WORLDS[1]
local minPriority   = 0  -- Mindest-Score um Quest zu nehmen

-- Paragraph Refs fuer Live-Status
local genieStatusP = nil
local fishStatusP  = nil

-- ============================================================
-- WINDOW
-- ============================================================
local Window = Rayfield:CreateWindow({
    Name            = "Sailor + Genie v2",
    LoadingTitle    = "BGS Addon",
    LoadingSubtitle = "Sailor Quest & Gem Genie",
    ConfigurationSaving = { Enabled = false },
    KeySystem = false,
})

-- ============================================================
-- TAB 1: SAILOR QUEST
-- ============================================================
local T1 = Window:CreateTab("Sailor Quest", "fish")

T1:CreateSection("Angel-Welt")
T1:CreateLabel("Waehle Welt -> TP -> gute Position suchen -> 'Position speichern'")

local worldNames = {}
for _, w in ipairs(FISH_WORLDS) do worldNames[#worldNames+1] = w.name end

T1:CreateDropdown({
    Name = "Welt auswaehlen",
    Options = worldNames,
    CurrentOption = {worldNames[1]},
    Flag = "FishWorld",
    Callback = function(v)
        local sel = type(v) == "table" and v[1] or v
        for _, w in ipairs(FISH_WORLDS) do
            if w.name == sel then selectedWorld = w; break end
        end
    end,
})

T1:CreateButton({ Name = "TP zur Welt (Standard-Spawn)", Callback = function()
    -- TP ohne gespeicherte Position (immer Standard)
    local ok = pcall(function()
        local spawn = Workspace.Worlds["Seven Seas"].Areas
            :FindFirstChild(selectedWorld.area)
            :FindFirstChild("IslandTeleport")
            :FindFirstChild("Spawn")
        fire("Teleport", spawn:GetFullName())
    end)
    if not ok then
        local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if root then root.CFrame = CFrame.new(selectedWorld.fallback + Vector3.new(0,3,0)) end
    end
    Rayfield:Notify({ Title="TP", Content=selectedWorld.name.." (Standard)", Duration=2 })
end })

T1:CreateSection("Angel-Position bestimmen")
T1:CreateLabel("1. TP zur Welt  2. Stell dich ans Wasser  3. Richte Kamera aus  4. Speichern")

T1:CreateButton({ Name = "Position JETZT speichern", Callback = function()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if root then
        selectedWorld.cf  = root.CFrame
        selectedWorld.pos = root.Position
        local p = root.Position
        Rayfield:Notify({
            Title   = "Position gespeichert!",
            Content = selectedWorld.name.."\n"
                .."X:"..math.round(p.X).." Y:"..math.round(p.Y).." Z:"..math.round(p.Z),
            Duration = 4,
        })
    end
end })

T1:CreateButton({ Name = "Position loeschen", Callback = function()
    selectedWorld.cf  = nil
    selectedWorld.pos = nil
    Rayfield:Notify({ Title="Reset", Content=selectedWorld.name.." -> Standard-Spawn", Duration=2 })
end })

-- Status
fishStatusP = T1:CreateParagraph({ Title="Status", Content="Inaktiv" })

T1:CreateSection("Auto Fish")
T1:CreateToggle({
    Name = "Auto Fish",
    CurrentValue = false,
    Flag = "AutoFish",
    Callback = function(v)
        fishing = v
        if v then
            task.spawn(function()
                tpToWorld(selectedWorld)
                task.wait(2)
                pcall(function() fishStatusP:Set({Title="Status", Content="Fischt in: "..selectedWorld.name}) end)
                while fishing do
                    fire("BeginCastCharge")
                    task.wait(0.5)
                    fire("FinishCastCharge")
                    task.wait(3)
                    fire("Reel")
                    task.wait(1)
                end
                pcall(function() fishStatusP:Set({Title="Status", Content="Inaktiv"}) end)
            end)
        else
            pcall(function() fishStatusP:Set({Title="Status", Content="Inaktiv"}) end)
        end
    end,
})

T1:CreateSection("Manuell")
T1:CreateButton({ Name = "Cast",              Callback = function() fire("BeginCastCharge"); task.wait(0.5); fire("FinishCastCharge") end })
T1:CreateButton({ Name = "Reel",              Callback = function() fire("Reel") end })
T1:CreateButton({ Name = "Sell All Fish",      Callback = function() fire("SellAllFish"); Rayfield:Notify({Title="Fish",Content="Sold!",Duration=2}) end })
T1:CreateButton({ Name = "Claim Fish Rewards", Callback = function() fire("ClaimAllFishingIndexRewards"); Rayfield:Notify({Title="Fish",Content="Claimed!",Duration=2}) end })

T1:CreateSection("Alle Welten (TP)")
for _, w in ipairs(FISH_WORLDS) do
    local world = w
    T1:CreateButton({ Name = (world.pos and "[CUSTOM] " or "").."TP: "..w.name,
        Callback = function()
            tpToWorld(world)
            Rayfield:Notify({ Title="TP", Content=world.name, Duration=2 })
        end })
end

-- ============================================================
-- TAB 2: GEM GENIE
-- ============================================================
local T2 = Window:CreateTab("Gem Genie", "gem")

T2:CreateSection("Reward-basierte Slot-Auswahl")
T2:CreateLabel("Scannt alle 3 Slots -> waehlt den mit bestem Reward")
T2:CreateLabel("Prioritaet: Shadow Crystal > Elixiere > Lv6 Pots > Keys > ...")

-- Min-Prioritaet Slider
T2:CreateSlider({
    Name = "Mindest-Prioritaet (0=alles nehmen)",
    Range = {0, 100},
    Increment = 5,
    CurrentValue = 0,
    Flag = "MinPrio",
    Callback = function(v) minPriority = v end,
})

T2:CreateSlider({
    Name = "Reroll Intervall (Sek.)",
    Range = {2, 15},
    Increment = 1,
    CurrentValue = 4,
    Flag = "GenieInterval",
    Callback = function(v) genieInterval = v end,
})

-- Status
genieStatusP = T2:CreateParagraph({ Title="Status", Content="Inaktiv" })

local function updateGenieStatus()
    pcall(function()
        local slot, reward, score = findBestSlot()
        local task_txt = getQuestTask(slot)
        genieStatusP:Set({
            Title   = "Bester Slot: "..slot.." ("..reward..")",
            Content = "Score: "..score.."\nAufgabe: "..(task_txt ~= "" and task_txt or "?"),
        })
    end)
end

T2:CreateButton({ Name = "Slots jetzt scannen", Callback = function()
    updateGenieStatus()
end })

T2:CreateToggle({
    Name = "Auto Reroll + Best Slot nehmen",
    CurrentValue = false,
    Flag = "AutoGenie",
    Callback = function(v)
        genieRunning = v
        if v then
            task.spawn(function()
                while genieRunning do
                    -- Pruefe ob Quest aktiv
                    local d = getLD()
                    local hasActiveQuest = false
                    if d then
                        pcall(function()
                            local QuestUtil = require(ReplicatedStorage.Shared.Utils.Stats.QuestUtil)
                            hasActiveQuest = QuestUtil:FindById(d, "gem-genie") ~= nil
                        end)
                    end

                    if hasActiveQuest then
                        -- Quest laeuft noch, warte
                        pcall(function() genieStatusP:Set({Title="Status", Content="Quest aktiv - warte..."}) end)
                        task.wait(10)
                    else
                        -- Reroll und besten Slot waehlen
                        fire("RerollGenie")
                        task.wait(genieInterval)

                        -- Scan
                        local bestSlot, bestReward, bestScore = findBestSlot()

                        if bestScore >= minPriority then
                            fire("StartGenieQuest", bestSlot)
                            local task_txt = getQuestTask(bestSlot)
                            pcall(function()
                                genieStatusP:Set({
                                    Title   = "Quest gestartet! Slot "..bestSlot,
                                    Content = "Reward: "..bestReward.."\nAufgabe: "..(task_txt ~= "" and task_txt or "?"),
                                })
                            end)
                            Rayfield:Notify({
                                Title   = "Genie: Slot "..bestSlot,
                                Content = bestReward.."\n"..(task_txt ~= "" and task_txt or ""),
                                Duration = 5,
                            })
                            -- Warte bis Quest abgelaufen (1h Cooldown) oder fertig
                            task.wait(30)
                        else
                            pcall(function()
                                genieStatusP:Set({
                                    Title   = "Kein guter Slot (Score "..bestScore.."<"..minPriority..")",
                                    Content = "Rerolle weiter...",
                                })
                            end)
                            task.wait(2)
                        end
                    end
                end
                pcall(function() genieStatusP:Set({Title="Status", Content="Inaktiv"}) end)
            end)
        else
            pcall(function() genieStatusP:Set({Title="Status", Content="Inaktiv"}) end)
        end
    end,
})

T2:CreateSection("Manuell")
T2:CreateButton({ Name = "Reroll",          Callback = function()
    fire("RerollGenie")
    task.wait(1)
    updateGenieStatus()
    Rayfield:Notify({Title="Genie",Content="Rerolled!",Duration=2})
end })

T2:CreateButton({ Name = "Besten Slot nehmen", Callback = function()
    local slot, reward, score = findBestSlot()
    fire("StartGenieQuest", slot)
    local task_txt = getQuestTask(slot)
    Rayfield:Notify({
        Title   = "Slot "..slot.." gestartet",
        Content = reward.." (Score "..score..")\n"..(task_txt ~= "" and task_txt or ""),
        Duration = 4,
    })
    updateGenieStatus()
end })

T2:CreateButton({ Name = "Quest 1 nehmen",  Callback = function() fire("StartGenieQuest", 1); updateGenieStatus() end })
T2:CreateButton({ Name = "Quest 2 nehmen",  Callback = function() fire("StartGenieQuest", 2); updateGenieStatus() end })
T2:CreateButton({ Name = "Quest 3 nehmen",  Callback = function() fire("StartGenieQuest", 3); updateGenieStatus() end })
T2:CreateButton({ Name = "Quest wechseln",  Callback = function() fire("ChangeGenieQuest") end })

T2:CreateSection("Reroll-Spam")
T2:CreateButton({ Name = "10x Reroll", Callback = function()
    task.spawn(function()
        for i = 1, 10 do fire("RerollGenie"); task.wait(0.5) end
        updateGenieStatus()
        Rayfield:Notify({Title="Genie",Content="10x Rerolled!",Duration=2})
    end)
end })

T2:CreateSection("Reward Prioritaeten (Info)")
T2:CreateLabel("100: Shadow Crystal")
T2:CreateLabel("90-85: Secret/Egg/Infinity Elixir")
T2:CreateLabel("78-70: Green Fragment, Lunar Spin")
T2:CreateLabel("65-62: Lv6 Potions (Lucky/Speed/Coins/Mythic)")
T2:CreateLabel("55-54: Royal Key / Moon Key")
T2:CreateLabel("45-42: Lv5 Potions")
T2:CreateLabel("30-15: Power Orb / Reroll Orb / Spin Ticket")
T2:CreateLabel("10-7:  Lv4 Potions")
T2:CreateLabel("Mindest-Prio 0 = jeden Slot nehmen")
T2:CreateLabel("Mindest-Prio 60 = nur ab Lv6 Pots+")

-- INIT
Rayfield:Notify({
    Title   = "Sailor + Genie v2!",
    Content = "Custom Fish-Pos | Reward-Scan | Best Slot",
    Duration = 4,
})
