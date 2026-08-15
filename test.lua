-- ═══════════════════════════════════════════════════════════
-- ANIME STARS SCRIPT v1.6
-- Fixed labels + strict boss detection + debug
-- ═══════════════════════════════════════════════════════════

local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local Options = Library.Options
local Toggles = Library.Toggles

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local Remote = ReplicatedStorage.Shared.Packages.Events.RemoteEvent

-- HARDCODED SETTINGS
local ATTACK_DELAY = 0.05
local ATTACK_RANGE = 2000
local HOVER_DISTANCE = 5

-- ═══════════════════════════════════════════════════════════
-- MOB / CHAMPION DATA
-- ═══════════════════════════════════════════════════════════
local function GetEnemiesByZone()
    local dir = ReplicatedStorage.Shared.Directory.Enemies._Index
    local result = {}
    for _, zoneModule in ipairs(dir:GetChildren()) do
        local ok, data = pcall(require, zoneModule)
        if ok and type(data) == "table" then
            result[zoneModule.Name] = {}
            for _, enemyData in pairs(data) do
                if type(enemyData) == "table" and enemyData.DisplayName then
                    table.insert(result[zoneModule.Name], enemyData.DisplayName)
                end
            end
        end
    end
    return result
end

local function GetChampionsByZone()
    local dir = ReplicatedStorage.Shared.Directory.Champions._Index
    local result = {}
    for _, zoneModule in ipairs(dir:GetChildren()) do
        local ok, data = pcall(require, zoneModule)
        if ok and type(data) == "table" then
            result[zoneModule.Name] = {}
            for _, champData in pairs(data) do
                if type(champData) == "table" and champData.Name then
                    table.insert(result[zoneModule.Name], champData.Name)
                end
            end
        end
    end
    return result
end

local ZoneDisplayNames = {
    lobby = "Lobby",
    desertvillage = "Desert Village",
    skylands = "Skylands",
    alienplanet = "Alien Planet",
    kingdomoflions = "Kingdom of Lions",
    kazekageroom = "Kazekage Room",
    exclusive = "Exclusive",
    none = "Global",
}

local ZoneAliases = {
    ["shinobi world"] = "desertvillage",
    ["shinobi"] = "desertvillage",
    ["desert village"] = "desertvillage",
    ["desert"] = "desertvillage",
    ["skylands"] = "skylands",
    ["sky"] = "skylands",
    ["skypiea"] = "skylands",
    ["alien planet"] = "alienplanet",
    ["namekian world"] = "alienplanet",
    ["namekian"] = "alienplanet",
    ["alien"] = "alienplanet",
    ["kingdom of lions"] = "kingdomoflions",
    ["lions"] = "kingdomoflions",
    ["kazekage"] = "kazekageroom",
    ["lobby"] = "lobby",
}

local EnemiesByZone = GetEnemiesByZone()
local ChampionsByZone = GetChampionsByZone()

local AllByZone = {}
for zone, mobs in pairs(EnemiesByZone) do
    AllByZone[zone] = AllByZone[zone] or {}
    for _, m in ipairs(mobs) do table.insert(AllByZone[zone], m) end
end
for zone, champs in pairs(ChampionsByZone) do
    AllByZone[zone] = AllByZone[zone] or {}
    for _, c in ipairs(champs) do table.insert(AllByZone[zone], c) end
end

local ZoneList = {}
for zone, _ in pairs(AllByZone) do
    if #AllByZone[zone] > 0 then
        table.insert(ZoneList, ZoneDisplayNames[zone] or zone)
    end
end
table.sort(ZoneList)

local ZoneNameToId = {}
for id, name in pairs(ZoneDisplayNames) do
    ZoneNameToId[name] = id
end

-- ═══════════════════════════════════════════════════════════
-- MOB TARGETING
-- ═══════════════════════════════════════════════════════════
local function GetMobInfo(mobModel)
    for _, gui in ipairs(LocalPlayer.PlayerGui:GetChildren()) do
        if gui.Name == "Enemy" and gui:IsA("BillboardGui") then
            if gui.Adornee and (gui.Adornee == mobModel or gui.Adornee:IsDescendantOf(mobModel)) then
                local details = gui:FindFirstChild("details")
                if details then
                    local title = details:FindFirstChild("title")
                    local diff = details:FindFirstChild("difficulty")
                    return {
                        name = title and title:IsA("TextLabel") and title.Text or nil,
                        difficulty = diff and diff:IsA("TextLabel") and diff.Text or nil,
                    }
                end
            end
        end
    end
    return {name = nil, difficulty = nil}
end

local function IsBossMob(mobModel)
    local info = GetMobInfo(mobModel)
    if info.difficulty then
        local d = info.difficulty:lower():gsub("%s+", "")
        -- STRICT: only exactly "boss" difficulty counts
        if d == "boss" then
            return true
        end
    end
    -- Any champion counts as a boss too
    if info.name then
        for _, champList in pairs(ChampionsByZone) do
            for _, c in ipairs(champList) do
                if c == info.name then return true end
            end
        end
    end
    return false
end

local function GetTargetMob(priorityName, bossOnly)
    local char = LocalPlayer.Character
    if not char then return nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    
    local enemies = Workspace:FindFirstChild("Enemies")
    if not enemies then return nil end
    
    local closest, closestDist = nil, ATTACK_RANGE
    
    for _, mob in ipairs(enemies:GetChildren()) do
        local mobHrp = mob:FindFirstChild("HumanoidRootPart")
        local hum = mob:FindFirstChildOfClass("Humanoid")
        if mobHrp and hum and hum.Health > 0 then
            local dist = (hrp.Position - mobHrp.Position).Magnitude
            if dist < closestDist then
                local valid = true
                
                if priorityName and priorityName ~= "" then
                    local info = GetMobInfo(mob)
                    valid = info.name and info.name:lower() == priorityName:lower()
                end
                
                if valid and bossOnly then
                    valid = IsBossMob(mob)
                end
                
                if valid then
                    closest = mob
                    closestDist = dist
                end
            end
        end
    end
    return closest
end

-- ═══════════════════════════════════════════════════════════
-- REMOTE ACTIONS
-- ═══════════════════════════════════════════════════════════
local Actions = {}
function Actions.M1(hero, combo)
    Remote:FireServer({{Path = "combat/m1", Params = {hero, combo}}})
end
function Actions.CastSkill()
    Remote:FireServer({{Path = "abilities/cast", Params = {"Skill"}}})
end
function Actions.CastUltimate()
    Remote:FireServer({{Path = "abilities/cast", Params = {"Ultimate"}}})
end
function Actions.Teleport(zoneId)
    Remote:FireServer({{Path = "zones/teleport", Params = {zoneId}}})
end

local function GetCurrentHero()
    local char = LocalPlayer.Character
    if char then
        local heroAttr = char:GetAttribute("AnimationPack")
        if heroAttr and heroAttr ~= "" then
            return heroAttr
        end
    end
    return "Hawk"
end

-- ═══════════════════════════════════════════════════════════
-- QUEST READER
-- ═══════════════════════════════════════════════════════════
local function GetActiveQuest()
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return nil end
    local main = pg:FindFirstChild("Main")
    if not main then return nil end
    local hud = main:FindFirstChild("Hud")
    if not hud then return nil end
    local quest = hud:FindFirstChild("Quest")
    if not quest then return nil end
    
    local info = quest:FindFirstChild("Info")
    local progress = quest:FindFirstChild("Progress")
    
    local titleLabel = info and info:FindFirstChild("Title")
    local progressLabel = progress and progress:FindFirstChild("Label")
    
    local title = titleLabel and titleLabel:IsA("TextLabel") and titleLabel.Text or ""
    local prog = progressLabel and progressLabel:IsA("TextLabel") and progressLabel.Text or ""
    
    if title == "" then return nil end
    
    return {
        title = title,
        progress = prog,
    }
end

local function ParseQuest(questText)
    if not questText or questText == "" then return nil end
    local lower = questText:lower()
    
    local result = {
        text = questText,
        zone = nil,
        zoneId = nil,
        bossOnly = false,
        mobName = nil,
    }
    
    if lower:find("boss") or lower:find("champion") then
        result.bossOnly = true
    end
    
    -- Sort aliases longest first
    local sortedAliases = {}
    for alias, zoneId in pairs(ZoneAliases) do
        table.insert(sortedAliases, {alias = alias, zoneId = zoneId, len = #alias})
    end
    table.sort(sortedAliases, function(a, b) return a.len > b.len end)
    
    for _, a in ipairs(sortedAliases) do
        if lower:find(a.alias, 1, true) then
            result.zoneId = a.zoneId
            result.zone = ZoneDisplayNames[a.zoneId] or a.zoneId
            break
        end
    end
    
    -- Detect specific mob name
    for _, mobList in pairs(EnemiesByZone) do
        for _, mobName in ipairs(mobList) do
            if lower:find(mobName:lower(), 1, true) then
                result.mobName = mobName
                break
            end
        end
        if result.mobName then break end
    end
    for _, champList in pairs(ChampionsByZone) do
        for _, champName in ipairs(champList) do
            if lower:find(champName:lower(), 1, true) then
                result.mobName = champName
                break
            end
        end
        if result.mobName then break end
    end
    
    return result
end

-- ═══════════════════════════════════════════════════════════
-- WINDOW
-- ═══════════════════════════════════════════════════════════
Library.ForceCheckbox = false
Library.ShowToggleFrameInKeybinds = true

local Window = Library:CreateWindow({
    Title = "Anime Stars",
    Footer = "v1.6",
    Icon = 95816097006870,
    NotifySide = "Right",
    ShowCustomCursor = true,
})

local Tabs = {
    Main = Window:AddTab("Main", "user"),
    Farm = Window:AddTab("Auto Farm", "swords"),
    Quest = Window:AddTab("Auto Quest", "scroll-text"),
    Teleport = Window:AddTab("Teleports", "map"),
    ["UI Settings"] = Window:AddTab("UI Settings", "settings"),
}

-- MAIN
local MainGroup = Tabs.Main:AddLeftGroupbox("Info", "info")
MainGroup:AddLabel("Anime Stars v1.6", true)
local HeroDisplayLabel = MainGroup:AddLabel("Current Hero: " .. GetCurrentHero(), true)

local PlayerGroup = Tabs.Main:AddRightGroupbox("Server", "server")
PlayerGroup:AddButton({
    Text = "Rejoin Server",
    Func = function()
        game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer)
    end,
})

-- AUTO FARM
local FarmGroup = Tabs.Farm:AddLeftGroupbox("Auto Farm", "swords")
FarmGroup:AddToggle("AutoAttack", { Text = "Auto Attack", Default = false })
FarmGroup:AddToggle("UseAnchor", { Text = "Anchor Mode", Default = false })
FarmGroup:AddDivider()
FarmGroup:AddToggle("AutoSkill", { Text = "Auto Skill", Default = false })
FarmGroup:AddSlider("SkillDelay", { Text = "Skill Delay", Default = 5, Min = 1, Max = 30, Rounding = 1, Suffix = "s" })
FarmGroup:AddToggle("AutoUltimate", { Text = "Auto Ultimate", Default = false })
FarmGroup:AddSlider("UltimateDelay", { Text = "Ultimate Delay", Default = 15, Min = 5, Max = 60, Rounding = 1, Suffix = "s" })

local TargetGroup = Tabs.Farm:AddRightGroupbox("Target Filter", "target")
TargetGroup:AddToggle("PriorityMob", { Text = "Prioritize Specific Mob", Default = false })

TargetGroup:AddDropdown("SelectedZone", {
    Values = ZoneList,
    Default = ZoneList[1] or "Skylands",
    Text = "Zone",
    Callback = function(zoneName)
        local zoneId = ZoneNameToId[zoneName]
        local mobList = AllByZone[zoneId] or {}
        if #mobList == 0 then mobList = {"(no mobs)"} end
        Options.SelectedMob:SetValues(mobList)
        Options.SelectedMob:SetValue(mobList[1])
    end,
})

local defaultZone = ZoneList[1]
local defaultZoneId = ZoneNameToId[defaultZone]
local defaultMobs = AllByZone[defaultZoneId] or {"Deidaro"}

TargetGroup:AddDropdown("SelectedMob", {
    Values = defaultMobs,
    Default = defaultMobs[1],
    Text = "Priority Mob",
    Searchable = true,
})

-- AUTO QUEST
local QuestGroup = Tabs.Quest:AddLeftGroupbox("Auto Quest", "scroll-text")

QuestGroup:AddToggle("AutoQuest", {
    Text = "Auto Quest",
    Default = false,
    Tooltip = "Reads active quest, teleports & farms correct mobs",
})

QuestGroup:AddToggle("AutoTeleportToZone", {
    Text = "Auto Teleport to Zone",
    Default = true,
})

local QuestTitleLabel = QuestGroup:AddLabel("Quest: (waiting...)", true)
local QuestProgressLabel = QuestGroup:AddLabel("Progress: -", true)
local QuestZoneLabel = QuestGroup:AddLabel("Zone: -", true)
local QuestTargetLabel = QuestGroup:AddLabel("Target: -", true)

QuestGroup:AddButton({
    Text = "Refresh Quest Info",
    Func = function()
        local q = GetActiveQuest()
        if q then
            local parsed = ParseQuest(q.title)
            QuestTitleLabel:SetText("Quest: " .. q.title)
            QuestProgressLabel:SetText("Progress: " .. q.progress)
            QuestZoneLabel:SetText("Zone: " .. (parsed.zone or "Unknown"))
            local target = parsed.mobName or (parsed.bossOnly and "Any Boss" or "Any Enemy")
            QuestTargetLabel:SetText("Target: " .. target)
        else
            QuestTitleLabel:SetText("Quest: (none detected)")
        end
    end,
})

local DebugGroup = Tabs.Quest:AddRightGroupbox("Debug", "bug")

DebugGroup:AddButton({
    Text = "Scan Nearby Mobs",
    Func = function()
        local enemies = Workspace:FindFirstChild("Enemies")
        if not enemies then return end
        print("\n=== NEARBY MOB SCAN ===")
        local count = 0
        for _, mob in ipairs(enemies:GetChildren()) do
            local info = GetMobInfo(mob)
            local isBoss = IsBossMob(mob)
            if info.name then
                count = count + 1
                print(string.format("[%d] %s | Difficulty: %s | IsBoss: %s", 
                    count, info.name, tostring(info.difficulty), tostring(isBoss)))
                if count >= 15 then break end
            end
        end
        Library:Notify({Title="Scan Done", Description="Check console (F9)", Time=3})
    end,
})

DebugGroup:AddButton({
    Text = "Run Remote Spy (20s)",
    Func = function()
        Library:Notify({Title="Spy Started", Description="Do actions now!", Time=5})
        local mt = getrawmetatable(game)
        setreadonly(mt, false)
        local captured = {}
        local oldNamecall
        oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
            if self == Remote and getnamecallmethod() == "FireServer" then
                local args = {...}
                if args[1] and type(args[1]) == "table" then
                    for _, entry in ipairs(args[1]) do
                        if entry.Path and not captured[entry.Path] then
                            captured[entry.Path] = true
                            print("[SPY] Path:", entry.Path)
                            if entry.Params then
                                for i, p in ipairs(entry.Params) do
                                    print("  Param", i, ":", tostring(p))
                                end
                            end
                        end
                    end
                end
            end
            return oldNamecall(self, ...)
        end)
        task.wait(20)
        hookmetamethod(game, "__namecall", oldNamecall)
        Library:Notify({Title="Spy Ended", Description="Check console (F9)", Time=3})
    end,
})

-- ═══════════════════════════════════════════════════════════
-- POSITIONING
-- ═══════════════════════════════════════════════════════════
local currentTarget = nil
local comboIndex = 1
local lastMobPos = nil

RunService.Heartbeat:Connect(function()
    if Library.Unloaded then return end
    
    local char = LocalPlayer.Character
    if not char then return end
    local myHrp = char:FindFirstChild("HumanoidRootPart")
    if not myHrp then return end
    
    if not (Toggles.AutoAttack.Value or Toggles.AutoQuest.Value) then
        if myHrp.Anchored then myHrp.Anchored = false end
        lastMobPos = nil
        return
    end
    
    if not currentTarget or not currentTarget.Parent then
        if myHrp.Anchored then myHrp.Anchored = false end
        return
    end
    
    local hum = currentTarget:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then
        if myHrp.Anchored then myHrp.Anchored = false end
        return
    end
    
    local mobHrp = currentTarget:FindFirstChild("HumanoidRootPart")
    if not mobHrp then return end
    
    local myHum = char:FindFirstChildOfClass("Humanoid")
    if not myHum then return end
    myHum.PlatformStand = false
    
    local mobPos = mobHrp.Position
    
    if lastMobPos and (mobPos - lastMobPos).Magnitude < 0.5 then
        myHrp.AssemblyLinearVelocity = Vector3.zero
        myHrp.AssemblyAngularVelocity = Vector3.zero
        if Toggles.UseAnchor.Value and not myHrp.Anchored then
            myHrp.Anchored = true
        end
        return
    end
    
    lastMobPos = mobPos
    
    local myPos = myHrp.Position
    local direction = (myPos - mobPos)
    direction = Vector3.new(direction.X, 0, direction.Z)
    
    if direction.Magnitude < 0.01 then
        direction = Vector3.new(0, 0, 1)
    else
        direction = direction.Unit
    end
    
    local targetPos = mobPos + direction * HOVER_DISTANCE
    targetPos = Vector3.new(targetPos.X, mobPos.Y, targetPos.Z)
    
    myHrp.CFrame = CFrame.lookAt(targetPos, mobPos)
    myHrp.AssemblyLinearVelocity = Vector3.zero
    myHrp.AssemblyAngularVelocity = Vector3.zero
    
    if Toggles.UseAnchor.Value then
        myHrp.Anchored = true
    else
        if myHrp.Anchored then myHrp.Anchored = false end
    end
end)

-- ═══════════════════════════════════════════════════════════
-- QUEST LOOP
-- ═══════════════════════════════════════════════════════════
local activeQuestData = nil
local lastZoneTeleport = 0

task.spawn(function()
    while task.wait(2) do
        if Library.Unloaded then break end
        
        pcall(function()
            HeroDisplayLabel:SetText("Current Hero: " .. GetCurrentHero())
        end)
        
        local q = GetActiveQuest()
        if q then
            local parsed = ParseQuest(q.title)
            activeQuestData = parsed
            
            pcall(function()
                QuestTitleLabel:SetText("Quest: " .. q.title)
                QuestProgressLabel:SetText("Progress: " .. q.progress)
                QuestZoneLabel:SetText("Zone: " .. (parsed.zone or "Unknown"))
                local target = parsed.mobName or (parsed.bossOnly and "Any Boss" or "Any Enemy")
                QuestTargetLabel:SetText("Target: " .. target)
            end)
            
            if Toggles.AutoQuest.Value and Toggles.AutoTeleportToZone.Value and parsed.zoneId then
                if tick() - lastZoneTeleport > 15 then
                    local enemies = Workspace:FindFirstChild("Enemies")
                    local hasEnemies = enemies and #enemies:GetChildren() > 0
                    if not hasEnemies then
                        Actions.Teleport(parsed.zoneId)
                        lastZoneTeleport = tick()
                        Library:Notify({Title="Auto Quest", Description="TP → "..parsed.zone, Time=3})
                    end
                end
            end
        else
            activeQuestData = nil
            pcall(function()
                QuestTitleLabel:SetText("Quest: (none detected)")
            end)
        end
    end
end)

-- ═══════════════════════════════════════════════════════════
-- ATTACK LOOP
-- ═══════════════════════════════════════════════════════════
task.spawn(function()
    while task.wait() do
        if Library.Unloaded then break end
        
        local shouldFarm = Toggles.AutoAttack.Value or Toggles.AutoQuest.Value
        
        if shouldFarm then
            local hero = GetCurrentHero()
            
            local needNewTarget = true
            if currentTarget and currentTarget.Parent then
                local h = currentTarget:FindFirstChildOfClass("Humanoid")
                if h and h.Health > 0 then
                    needNewTarget = false
                end
            end
            
            if needNewTarget then
                local priority = nil
                local bossOnly = false
                
                if Toggles.AutoQuest.Value and activeQuestData then
                    priority = activeQuestData.mobName
                    bossOnly = activeQuestData.bossOnly
                elseif Toggles.PriorityMob.Value then
                    priority = Options.SelectedMob.Value
                end
                
                currentTarget = GetTargetMob(priority, bossOnly)
                comboIndex = 1
            end
            
            if currentTarget and hero and hero ~= "" then
                Actions.M1(hero, comboIndex)
                comboIndex = comboIndex + 1
                if comboIndex > 4 then comboIndex = 1 end
            end
            
            task.wait(ATTACK_DELAY)
        else
            currentTarget = nil
            task.wait(0.1)
        end
    end
end)

task.spawn(function()
    while task.wait(0.5) do
        if Library.Unloaded then break end
        if Toggles.AutoSkill.Value then
            Actions.CastSkill()
            task.wait(Options.SkillDelay.Value)
        end
    end
end)

task.spawn(function()
    while task.wait(0.5) do
        if Library.Unloaded then break end
        if Toggles.AutoUltimate.Value then
            Actions.CastUltimate()
            task.wait(Options.UltimateDelay.Value)
        end
    end
end)

LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(0.5)
    local hrp = char:WaitForChild("HumanoidRootPart", 5)
    if hrp then hrp.Anchored = false end
end)

-- TELEPORT
local TeleportGroup = Tabs.Teleport:AddLeftGroupbox("Zones", "map-pin")
local zones = {
    {name = "Lobby", id = "lobby"},
    {name = "Desert Village", id = "desertvillage"},
    {name = "Skylands", id = "skylands"},
    {name = "Alien Planet", id = "alienplanet"},
    {name = "Kingdom of Lions", id = "kingdomoflions"},
    {name = "Kazekage Room", id = "kazekageroom"},
}

for _, zone in ipairs(zones) do
    TeleportGroup:AddButton({
        Text = "TP: " .. zone.name,
        Func = function()
            Actions.Teleport(zone.id)
            Library:Notify({Title="Teleport", Description="→ "..zone.name, Time=2})
        end,
    })
end

-- UI SETTINGS
local MenuGroup = Tabs["UI Settings"]:AddLeftGroupbox("Menu", "wrench")
MenuGroup:AddToggle("KeybindMenuOpen", {
    Default = Library.KeybindFrame.Visible, Text = "Open Keybind Menu",
    Callback = function(v) Library.KeybindFrame.Visible = v end,
})
MenuGroup:AddToggle("ShowCustomCursor", {
    Text = "Custom Cursor", Default = Library.ShowCustomCursor,
    Callback = function(v) Library.ShowCustomCursor = v end,
})
MenuGroup:AddDropdown("NotificationSide", {
    Values = {"Left","Right"}, Default = "Right", Text = "Notification Side",
    Callback = function(v) Library:SetNotifySide(v) end,
})
MenuGroup:AddDivider()
MenuGroup:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", {Default="RightShift", NoUI=true, Text="Menu keybind"})
MenuGroup:AddButton("Unload", function() Library:Unload() end)
Library.ToggleKeybind = Options.MenuKeybind

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({"MenuKeybind"})
ThemeManager:SetFolder("AnimeStarsScript")
SaveManager:SetFolder("AnimeStarsScript/configs")
SaveManager:BuildConfigSection(Tabs["UI Settings"])
ThemeManager:ApplyToTab(Tabs["UI Settings"])
SaveManager:LoadAutoloadConfig()

Library:Notify({Title="Anime Stars v1.6", Description="Fixed labels + strict boss", Time=5})
