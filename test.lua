-- ═══════════════════════════════════════════════════════════
-- ANIME STARS SCRIPT v5.0 - Obsidian UI + Data-Driven
-- ═══════════════════════════════════════════════════════════

local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local Options = Library.Options
local Toggles = Library.Toggles

Library.ForceCheckbox = false
Library.ShowToggleFrameInKeybinds = true

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")
local RunService        = game:GetService("RunService")
local VirtualUser       = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer
local Remote      = ReplicatedStorage.Shared.Packages.Events.RemoteEvent

local ATTACK_DELAY   = 0.05
local HOVER_DISTANCE = 5

LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

-- ═══════════════════════════════════════════════════════════
-- LOAD GAME MODULES
-- ═══════════════════════════════════════════════════════════
local ProfileManager, QuestUtils, QuestsDirectory, EnemiesManager, EnemiesDir, ZonesManager
do
    local ok, mod = pcall(require, ReplicatedStorage.Client.General.ProfileManager)
    if ok then ProfileManager = mod end

    local ok2, mod2 = pcall(require, ReplicatedStorage.Client.Utils.QuestUtils)
    if ok2 then QuestUtils = mod2 end

    local ok3, mod3 = pcall(require, ReplicatedStorage.Shared.Directory.Quests)
    if ok3 then QuestsDirectory = mod3 end

    local ok4, mod4 = pcall(require, ReplicatedStorage.Client.Zones.EnemiesManager)
    if ok4 then EnemiesManager = mod4 end

    local ok5, mod5 = pcall(require, ReplicatedStorage.Shared.Directory.Enemies)
    if ok5 then EnemiesDir = mod5 end

    local ok6, mod6 = pcall(function()
        local m = ReplicatedStorage.Client:FindFirstChild("Zones")
        if m then m = m:FindFirstChild("ZonesManager") end
        return m and require(m)
    end)
    if ok6 then ZonesManager = mod6 end
end

local DIFFICULTY_MAP = {
    ["Easy"]="easy",["Medium"]="medium",["Hard"]="hard",
    ["Ultra Hard"]="ultrahard",["Boss"]="boss",
}
local CONFIG_DIFF_MAP = {
    ["Easy"]="easy",["easy"]="easy",
    ["Medium"]="medium",["medium"]="medium",
    ["Hard"]="hard",["hard"]="hard",
    ["UltraHard"]="ultrahard",["Ultra Hard"]="ultrahard",["ultrahard"]="ultrahard",
    ["Boss"]="boss",["boss"]="boss",
    ["Champion"]="boss",["champion"]="boss",
}

-- ═══════════════════════════════════════════════════════════
-- DATA LOADERS
-- ═══════════════════════════════════════════════════════════
local function LoadZones()
    local zones, nameToId = {}, {}
    local dir = ReplicatedStorage.Shared.Directory.Zones:FindFirstChild("_Index")
    if dir then
        for _, zoneModule in ipairs(dir:GetChildren()) do
            local ok, data = pcall(require, zoneModule)
            if ok and type(data) == "table" then
                local id      = data._id or zoneModule.Name
                local display = data.DisplayName or id
                local order   = data.Order or 99
                table.insert(zones, { id=id, display=display, order=order })
                nameToId[display] = id
            end
        end
    end
    table.sort(zones, function(a,b) return a.order < b.order end)
    return zones, nameToId
end

local function LoadGachas()
    local result = {}
    local dir = ReplicatedStorage.Shared.Configs:FindFirstChild("GachaConfig")
    if dir then
        for _, gachaModule in ipairs(dir:GetChildren()) do
            local ok, data = pcall(require, gachaModule)
            if ok and type(data) == "table" then
                table.insert(result, {
                    id          = gachaModule.Name,
                    display     = data.DisplayName or gachaModule.Name,
                    requireZone = data.RequireZone,
                })
            end
        end
    end
    return result
end

local function GetEnemiesByZone()
    local dir    = ReplicatedStorage.Shared.Directory.Enemies._Index
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
    local dir    = ReplicatedStorage.Shared.Directory.Champions._Index
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

local function LoadBanners()
    local result = {}
    local dir = ReplicatedStorage.Shared.Directory.Banners:FindFirstChild("_Index")
    if dir then
        for _, b in ipairs(dir:GetChildren()) do table.insert(result, b.Name) end
    end
    return result
end

local ZoneData, ZoneNameToId = LoadZones()
local GachaData       = LoadGachas()
local BannerData      = LoadBanners()
local EnemiesByZone   = GetEnemiesByZone()
local ChampionsByZone = GetChampionsByZone()

local ZoneDisplayNames = {}
for _, z in ipairs(ZoneData) do ZoneDisplayNames[z.id] = z.display end

local AllByZone = {}
for zone, mobs in pairs(EnemiesByZone) do
    AllByZone[zone] = AllByZone[zone] or {}
    for _, m in ipairs(mobs) do table.insert(AllByZone[zone], m) end
end
for zone, champs in pairs(ChampionsByZone) do
    AllByZone[zone] = AllByZone[zone] or {}
    for _, c in ipairs(champs) do table.insert(AllByZone[zone], c) end
end

local FarmZoneList = {}
for _, z in ipairs(ZoneData) do
    if AllByZone[z.id] and #AllByZone[z.id] > 0 then
        table.insert(FarmZoneList, z.display)
    end
end

local ChampionSpinDisplay, ChampionSpinIdMap = {}, {}
for _, z in ipairs(ZoneData) do
    if ChampionsByZone[z.id] and #ChampionsByZone[z.id] > 0 then
        table.insert(ChampionSpinDisplay, z.display)
        ChampionSpinIdMap[z.display] = z.id
    end
end

print(string.format("[Anime Stars v5.0] Zones:%d Gachas:%d Banners:%d",
    #ZoneData, #GachaData, #BannerData))
print("  ProfileManager: ", ProfileManager and "OK" or "MISSING")
print("  QuestUtils:     ", QuestUtils     and "OK" or "MISSING")
print("  EnemiesManager: ", EnemiesManager and "OK" or "MISSING")
print("  EnemiesDir:     ", EnemiesDir     and "OK" or "MISSING")

-- ═══════════════════════════════════════════════════════════
-- POPUP HIDING
-- ═══════════════════════════════════════════════════════════
local POPUPS_TO_HIDE = {
    "ChampionPopup","GachaDropPopup","RewardPopup","ItemPopup",
    "BlessingPopup","SkillPopup","WeaponPopup","IndexPopup",
    "TitlePopup","SkillTreePopup","BannerPopup",
}
local function HideSpinPopups()
    pcall(function()
        local summon = LocalPlayer.PlayerGui:FindFirstChild("Summon")
        if summon and summon.Enabled then summon.Enabled = false end
        local popups = LocalPlayer.PlayerGui:FindFirstChild("Popups")
        if popups then
            for _, name in ipairs(POPUPS_TO_HIDE) do
                local p = popups:FindFirstChild(name)
                if p and p.Visible then p.Visible = false end
            end
        end
    end)
end
local function ShowSpinPopups()
    pcall(function()
        local summon = LocalPlayer.PlayerGui:FindFirstChild("Summon")
        if summon then summon.Enabled = true end
    end)
end

-- ═══════════════════════════════════════════════════════════
-- ENEMY DATA — via EnemiesManager
-- ═══════════════════════════════════════════════════════════
local function GetEnemyDataForModel(mobModel)
    if not EnemiesManager then return nil end
    local ok, allEnemies = pcall(function() return EnemiesManager:GetAllEnemies() end)
    if not ok or type(allEnemies) ~= "table" then return nil end
    local direct = allEnemies[mobModel.Name]
    if direct then return direct end
    for _, enemy in pairs(allEnemies) do
        if type(enemy) == "table" then
            local m = enemy.Model or enemy.model or enemy._model
            if m == mobModel then return enemy end
        end
    end
    return nil
end

local function GetEnemyConfig(mobModel)
    if not mobModel then return nil end
    local index = mobModel:GetAttribute("Index")
        or mobModel:GetAttribute("EnemyIndex") or mobModel:GetAttribute("ConfigId")
    if index and EnemiesDir and EnemiesDir.GetConfig then
        local ok, cfg = pcall(EnemiesDir.GetConfig, EnemiesDir, index)
        if ok and cfg then return cfg end
    end
    local enemyData = GetEnemyDataForModel(mobModel)
    if enemyData then
        local cfg = enemyData.Config or enemyData.config or enemyData._config
        if cfg then return cfg end
        local idx = enemyData.Index or (enemyData.Data and enemyData.Data.Index)
        if idx and EnemiesDir and EnemiesDir.GetConfig then
            local ok, cfg2 = pcall(EnemiesDir.GetConfig, EnemiesDir, idx)
            if ok and cfg2 then return cfg2 end
        end
    end
    local displayName = mobModel:GetAttribute("DisplayName")
    if not displayName then
        for _, gui in ipairs(LocalPlayer.PlayerGui:GetChildren()) do
            if gui.Name == "Enemy" and gui:IsA("BillboardGui") then
                if gui.Adornee and (gui.Adornee == mobModel or gui.Adornee:IsDescendantOf(mobModel)) then
                    local details = gui:FindFirstChild("details")
                    local title = details and details:FindFirstChild("title")
                    if title and title:IsA("TextLabel") then displayName = title.Text end
                    break
                end
            end
        end
    end
    if displayName then
        local dir = ReplicatedStorage.Shared.Directory.Enemies:FindFirstChild("_Index")
        if dir then
            for _, zoneModule in ipairs(dir:GetChildren()) do
                local ok, data = pcall(require, zoneModule)
                if ok and type(data) == "table" then
                    for _, enemyData in pairs(data) do
                        if type(enemyData) == "table" and enemyData.DisplayName == displayName then
                            return enemyData
                        end
                    end
                end
            end
        end
    end
    return nil
end

local function GetMobInfo(mobModel)
    if not mobModel then return { name=nil, difficulty=nil } end
    local cfg = GetEnemyConfig(mobModel)
    if cfg then
        local diff = cfg.Difficulty or cfg.difficulty
        local normDiff = diff and CONFIG_DIFF_MAP[diff] or nil
        return {
            name       = cfg.DisplayName or cfg.Name,
            difficulty = normDiff or (diff and diff:lower():gsub("%s+","")) or nil,
            zone       = cfg.Zone or cfg.zone,
            isBoss     = cfg.IsBoss or cfg.Boss or (normDiff == "boss"),
        }
    end
    for _, gui in ipairs(LocalPlayer.PlayerGui:GetChildren()) do
        if gui.Name == "Enemy" and gui:IsA("BillboardGui") then
            if gui.Adornee and (gui.Adornee == mobModel or gui.Adornee:IsDescendantOf(mobModel)) then
                local details = gui:FindFirstChild("details")
                if details then
                    local title = details:FindFirstChild("title")
                    local diff  = details:FindFirstChild("difficulty")
                    local diffText = diff and diff:IsA("TextLabel") and diff.Text or nil
                    return {
                        name       = title and title:IsA("TextLabel") and title.Text or nil,
                        difficulty = diffText and diffText:lower():gsub("%s+","") or nil,
                    }
                end
            end
        end
    end
    return { name=nil, difficulty=nil }
end

local function IsChampion(mobName)
    if not mobName then return false end
    for _, champList in pairs(ChampionsByZone) do
        for _, c in ipairs(champList) do
            if c == mobName then return true end
        end
    end
    return false
end

local function NameMatches(actualName, wantedName)
    if not actualName or not wantedName then return false end
    local a = actualName:lower():gsub("%s+","")
    local w = wantedName:lower():gsub("%s+","")
    if a == w then return true end
    if a:find(w,1,true) or w:find(a,1,true) then return true end
    return false
end

local function MatchesFilter(mobModel, filter)
    if not filter then return true end
    local info = GetMobInfo(mobModel)

    if filter.mobNames and next(filter.mobNames) then
        if not info.name then return false end
        local nameMatched = false
        for name, enabled in pairs(filter.mobNames) do
            if enabled and NameMatches(info.name, name) then
                nameMatched = true
                break
            end
        end
        if not nameMatched then return false end
    end

    if filter.difficulty then
        local wanted = filter.difficulty
        local actual = info.difficulty
        if wanted == "boss" then
            if actual == "boss" then return true end
            if info.isBoss then return true end
            if info.name and IsChampion(info.name) then return true end
            return false
        end
        if not actual then return false end
        return actual == wanted
    end

    return true
end

local function IterateLiveEnemies()
    local results = {}
    if EnemiesManager then
        local ok, allEnemies = pcall(function() return EnemiesManager:GetAllEnemies() end)
        if ok and type(allEnemies) == "table" then
            for id, enemy in pairs(allEnemies) do
                if type(enemy) == "table" then
                    local model = enemy.Model or enemy.model or enemy._model
                    if not model then
                        local enemies = Workspace:FindFirstChild("Enemies")
                        if enemies then model = enemies:FindFirstChild(id) end
                    end
                    if model and model.Parent then
                        local hum = model:FindFirstChildOfClass("Humanoid")
                        local hrp = model:FindFirstChild("HumanoidRootPart")
                        if hum and hum.Health > 0 and hrp then
                            table.insert(results, { model=model, hrp=hrp, hum=hum })
                        end
                    end
                end
            end
            if #results > 0 then return results end
        end
    end
    local enemies = Workspace:FindFirstChild("Enemies")
    if enemies then
        for _, mob in ipairs(enemies:GetChildren()) do
            local hum = mob:FindFirstChildOfClass("Humanoid")
            local hrp = mob:FindFirstChild("HumanoidRootPart")
            if hum and hum.Health > 0 and hrp then
                table.insert(results, { model=mob, hrp=hrp, hum=hum })
            end
        end
    end
    return results
end

local function GetAllMatchingMobs(filter, ignoreRange)
    local char = LocalPlayer.Character
    if not char then return {} end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return {} end
    local maxDist = ignoreRange and math.huge or 2000
    local mobs = {}
    for _, e in ipairs(IterateLiveEnemies()) do
        local dist = (hrp.Position - e.hrp.Position).Magnitude
        if dist < maxDist and MatchesFilter(e.model, filter) then
            table.insert(mobs, { mob=e.model, hrp=e.hrp, dist=dist })
        end
    end
    table.sort(mobs, function(a,b) return a.dist < b.dist end)
    return mobs
end

local function GetSingleTarget(filter, ignoreRange)
    local mobs = GetAllMatchingMobs(filter, ignoreRange)
    return mobs[1] and mobs[1].mob or nil
end

local function GetMobGroup(filter, groupRadius, ignoreRange)
    groupRadius = groupRadius or 25
    local allMobs = GetAllMatchingMobs(filter, ignoreRange)
    if #allMobs == 0 then return nil, nil end
    local bestGroup, bestScore = nil, 0
    for _, anchor in ipairs(allMobs) do
        local group = { anchor }
        for _, other in ipairs(allMobs) do
            if other.mob ~= anchor.mob then
                if (anchor.hrp.Position - other.hrp.Position).Magnitude <= groupRadius then
                    table.insert(group, other)
                end
            end
        end
        local score = #group * 1000 - anchor.dist
        if score > bestScore then bestScore = score; bestGroup = group end
    end
    if not bestGroup or #bestGroup == 0 then return nil, nil end
    return bestGroup[1].mob, bestGroup
end

-- ═══════════════════════════════════════════════════════════
-- REMOTES
-- ═══════════════════════════════════════════════════════════
local Actions = {}
function Actions.M1(hero, combo)       Remote:FireServer({{Path="combat/m1", Params={hero, combo}}}) end
function Actions.CastSkill()           Remote:FireServer({{Path="abilities/cast", Params={"Skill"}}}) end
function Actions.CastUltimate()        Remote:FireServer({{Path="abilities/cast", Params={"Ultimate"}}}) end
function Actions.Teleport(zoneId)      Remote:FireServer({{Path="zones/teleport", Params={zoneId}}}) end
function Actions.ChampionSpin(zoneId)  Remote:FireServer({{Path="champions/spin", Params={"auto", zoneId}}}) end
function Actions.GachaSpin(name)       Remote:FireServer({{Path="gacha/spin", Params={name, "auto"}}}) end
function Actions.GachaStop(name)       Remote:FireServer({{Path="gacha/stopAuto", Params={name}}}) end
function Actions.RankupPower()         Remote:FireServer({{Path="rankup/power", Params={}}}) end
function Actions.BannerRoll(b,c,t)     Remote:FireServer({{Path="banner/requestRoll", Params={b,c,t or "Normal"}}}) end
function Actions.ClaimMission(line, index)
    Remote:FireServer({{Path="missions/claim", Params={line, index}}})
end
function Actions.HiddenSpin(name)        HideSpinPopups(); Actions.GachaSpin(name);   task.wait(0.1); HideSpinPopups() end
function Actions.HiddenChampionSpin(z)   HideSpinPopups(); Actions.ChampionSpin(z);   task.wait(0.1); HideSpinPopups() end
function Actions.HiddenBannerRoll(b,c,t) HideSpinPopups(); Actions.BannerRoll(b,c,t); task.wait(0.1); HideSpinPopups() end

local function GetCurrentHero()
    local char = LocalPlayer.Character
    if char then
        local h = char:GetAttribute("AnimationPack")
        if h and h ~= "" then return h end
    end
    return "Hawk"
end

-- ═══════════════════════════════════════════════════════════
-- QUEST ENGINE
-- ═══════════════════════════════════════════════════════════
local function ParseMissionId(missionId)
    if not missionId then return nil, nil end
    local line, idx = missionId:match("^(.-)_(%d+)$")
    return line, tonumber(idx)
end

local function GetStageConfig(missionId)
    if not QuestsDirectory or not missionId then return nil, nil end
    if QuestUtils and QuestUtils.getStage then
        local ok, stage, line, lineName, idx = pcall(QuestUtils.getStage, missionId)
        if ok and stage then return stage, line, lineName, idx end
    end
    local lineName, idx = ParseMissionId(missionId)
    if not lineName then return nil, nil end
    local lineConfig = (QuestsDirectory.Get and QuestsDirectory.Get(lineName))
        or (QuestsDirectory.Directory and QuestsDirectory.Directory[lineName])
    if not lineConfig or not lineConfig.Quests then return nil, nil end
    return lineConfig.Quests[idx], lineConfig, lineName, idx
end

local function GetMissionsData()
    if not ProfileManager then return nil end
    local ok, data = pcall(function() return ProfileManager:get("Missions", false) end)
    if ok and type(data) == "table" then return data end
    return nil
end

local function BuildQuestInfo(missionId, ongoingData)
    if not missionId or not ongoingData then return nil end
    local stage, lineConfig, lineName, idx = GetStageConfig(missionId)
    if not stage then return nil end
    local objective = stage.Objective or {}
    return {
        missionId   = missionId,
        lineName    = lineName,
        index       = idx,
        name        = stage.Name,
        description = stage.Description,
        objective   = objective,
        progress    = ongoingData.Progress or 0,
        goal        = ongoingData.Goal or objective.Goal or 1,
        completed   = ongoingData.Completed == true,
        zoneId      = (lineConfig and lineConfig.ZoneRestriction) or objective.TargetZone,
        difficulty  = objective.Target and DIFFICULTY_MAP[objective.Target] or nil,
    }
end

local function GetActiveQuest()
    local missions = GetMissionsData()
    if not missions then return nil end
    local pinnedId = missions.Pinned and next(missions.Pinned) or nil
    if pinnedId and missions.OnGoing and missions.OnGoing[pinnedId] then
        return BuildQuestInfo(pinnedId, missions.OnGoing[pinnedId])
    end
    if QuestUtils and QuestUtils.mostRelevant then
        local ok, relevantId = pcall(QuestUtils.mostRelevant, missions, nil)
        if ok and relevantId and missions.OnGoing[relevantId] then
            return BuildQuestInfo(relevantId, missions.OnGoing[relevantId])
        end
    end
    if missions.OnGoing then
        for id, data in pairs(missions.OnGoing) do
            if not data.Completed and not (missions.Finished and missions.Finished[id]) then
                return BuildQuestInfo(id, data)
            end
        end
        for id, data in pairs(missions.OnGoing) do
            if data.Completed then return BuildQuestInfo(id, data) end
        end
    end
    return nil
end

local function BuildFilterFromQuest(quest)
    if not quest then return nil end
    if not quest.difficulty and not quest.zoneId then return nil end
    return { difficulty=quest.difficulty, zoneId=quest.zoneId }
end

local function ClaimQuest(quest)
    if not quest then return false end
    Actions.ClaimMission(quest.lineName, quest.index)
    return true
end

local function GetPlayerCurrentZone()
    if ZonesManager and ZonesManager.GetCurrentZone then
        local ok, z = pcall(function() return ZonesManager:GetCurrentZone() end)
        if ok and z then return z end
    end
    local char = LocalPlayer.Character
    if char then
        local z = char:GetAttribute("Zone") or char:GetAttribute("CurrentZone")
        if z then return z end
    end
    return LocalPlayer:GetAttribute("Zone") or LocalPlayer:GetAttribute("CurrentZone")
end

-- ═══════════════════════════════════════════════════════════
-- TARGET STATE
-- ═══════════════════════════════════════════════════════════
local ActiveQuest, ActiveQuestFilter = nil, nil
local lastZoneTeleport      = 0
local currentTarget         = nil
local currentGroup          = nil
local currentGroupSize      = 0
local comboIndex            = 1
local needNewTarget         = true
local currentTargetDiedConn = nil

local function invalidateTarget()
    needNewTarget = true
    currentTarget = nil
end

local function setCurrentTarget(mob)
    if currentTargetDiedConn then currentTargetDiedConn:Disconnect(); currentTargetDiedConn = nil end
    currentTarget = mob
    if mob then
        local hum = mob:FindFirstChildOfClass("Humanoid")
        if hum then currentTargetDiedConn = hum.Died:Connect(invalidateTarget) end
        local capturedMob = mob
        mob.AncestryChanged:Once(function(_, parent)
            if not parent and currentTarget == capturedMob then invalidateTarget() end
        end)
    end
end

-- ═══════════════════════════════════════════════════════════
-- WINDOW (Obsidian)
-- ═══════════════════════════════════════════════════════════
local Window = Library:CreateWindow({
    Title = "Anime Stars",
    Footer = "v5.0",
    Icon = 95816097006870,
    NotifySide = "Right",
    ShowCustomCursor = true,
})

local Tabs = {
    Main     = Window:AddTab("Main", "user"),
    Farm     = Window:AddTab("Auto Farm", "swords"),
    Quest    = Window:AddTab("Auto Quest", "scroll-text"),
    Extras   = Window:AddTab("Auto Extras", "sparkles"),
    Summon   = Window:AddTab("Auto Summon", "gift"),
    Teleport = Window:AddTab("Teleports", "map"),
    ["UI Settings"] = Window:AddTab("UI Settings", "settings"),
}

-- ── MAIN TAB ────────────────────────────────────────────────
local InfoGroup = Tabs.Main:AddLeftGroupbox("Status", "info")
InfoGroup:AddLabel("Anime Stars v5.0", true)
InfoGroup:AddLabel(string.format("Zones: %d | Gachas: %d | Banners: %d",
    #ZoneData, #GachaData, #BannerData), true)
local HeroLabel    = InfoGroup:AddLabel("Hero: " .. GetCurrentHero(), true)
local GroupLabel   = InfoGroup:AddLabel("Group Farm: -", true)
local TargetLabel  = InfoGroup:AddLabel("Target: -", true)
local FilterLabel  = InfoGroup:AddLabel("Filter: -", true)
local ZoneLabel    = InfoGroup:AddLabel("Current Zone: -", true)

local ServerGroup = Tabs.Main:AddRightGroupbox("Server", "server")
ServerGroup:AddButton({
    Text = "Rejoin Server",
    Func = function()
        game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer)
    end,
})
ServerGroup:AddButton({
    Text = "Restore Popups",
    Func = function()
        ShowSpinPopups()
        Library:Notify({ Title="Popups", Description="Restored", Time=3 })
    end,
})

-- ── FARM TAB ────────────────────────────────────────────────
local FarmGroup = Tabs.Farm:AddLeftGroupbox("Auto Farm", "swords")
FarmGroup:AddToggle("AutoAttack",   { Text="Auto Attack",       Default=false })
FarmGroup:AddToggle("SmartGroup",   { Text="Smart Group Farm ★", Default=true })
FarmGroup:AddSlider("GroupRadius",  {
    Text="Group Detection Radius", Default=25, Min=10, Max=60, Rounding=0, Suffix=" studs",
})
FarmGroup:AddToggle("UseAnchor",    { Text="Anchor Mode", Default=false })
FarmGroup:AddDivider()
FarmGroup:AddToggle("AutoSkill",    { Text="Auto Skill", Default=false })
FarmGroup:AddSlider("SkillDelay",   { Text="Skill Delay", Default=5, Min=1, Max=30, Rounding=1, Suffix="s" })
FarmGroup:AddToggle("AutoUltimate", { Text="Auto Ultimate", Default=false })
FarmGroup:AddSlider("UltDelay",     { Text="Ultimate Delay", Default=15, Min=5, Max=60, Rounding=1, Suffix="s" })

local TargetGroup = Tabs.Farm:AddRightGroupbox("Target Filter", "target")
TargetGroup:AddToggle("PriorityMob", {
    Text = "Prioritize Selected Mobs (overrides quest)",
    Default = false,
})
TargetGroup:AddToggle("FallbackAny", {
    Text = "Fallback: Any Mob if None Found",
    Default = false,
})

local defaultFarmZone = FarmZoneList[1] or "Skylands"
local defaultZoneId   = ZoneNameToId[defaultFarmZone] or ""
local defaultMobList  = AllByZone[defaultZoneId] or {"(no mobs)"}

TargetGroup:AddDropdown("SelectedZone", {
    Values  = FarmZoneList,
    Default = defaultFarmZone,
    Text    = "Zone",
    Callback = function(zoneName)
        local zoneId = ZoneNameToId[zoneName]
        local mobList = AllByZone[zoneId] or {}
        if #mobList == 0 then mobList = {"(no mobs)"} end
        -- Obsidian's clean way to refresh dropdown values:
        Options.SelectedMob:SetValues(mobList)
        Options.SelectedMob:SetValue({})
        invalidateTarget()
    end,
})

TargetGroup:AddDropdown("SelectedMob", {
    Values     = defaultMobList,
    Default    = defaultMobList[1],
    Text       = "Priority Mobs (multi-select)",
    Multi      = true,
    Searchable = true,
    Callback   = function()
        invalidateTarget()
    end,
})

-- ── QUEST TAB ───────────────────────────────────────────────
local QuestGroup = Tabs.Quest:AddLeftGroupbox("Auto Quest", "scroll-text")
QuestGroup:AddToggle("AutoQuest",     { Text="Auto Quest",            Default=false })
QuestGroup:AddToggle("AutoTeleport",  { Text="Auto Teleport to Zone", Default=true })
QuestGroup:AddToggle("AutoClaim",     { Text="Auto Claim",            Default=true })
QuestGroup:AddButton({
    Text = "Manual Claim Active",
    Func = function()
        if ActiveQuest and ActiveQuest.completed then
            ClaimQuest(ActiveQuest)
            Library:Notify({ Title="Claim", Description="Claimed "..ActiveQuest.name, Time=2 })
        else
            Library:Notify({ Title="Claim", Description="No completed quest", Time=2 })
        end
    end,
})

local ActiveQuestGroup = Tabs.Quest:AddLeftGroupbox("Active Quest Info", "book-open")
local QLabelName     = ActiveQuestGroup:AddLabel("Name: -", true)
local QLabelId       = ActiveQuestGroup:AddLabel("ID: -", true)
local QLabelZone     = ActiveQuestGroup:AddLabel("Zone: -", true)
local QLabelDiff     = ActiveQuestGroup:AddLabel("Difficulty: -", true)
local QLabelProgress = ActiveQuestGroup:AddLabel("Progress: -", true)
local QLabelStatus   = ActiveQuestGroup:AddLabel("Status: -", true)

local DebugGroup = Tabs.Quest:AddRightGroupbox("Debug", "bug")
DebugGroup:AddButton({
    Text = "Debug Missions (Console)",
    Func = function()
        print("\n=== MISSIONS DATA ===")
        local missions = GetMissionsData()
        if not missions then print("No data"); return end
        print("[Pinned]")
        for k, v in pairs(missions.Pinned or {}) do print("  "..tostring(k).." = "..tostring(v)) end
        print("[OnGoing]")
        for k, v in pairs(missions.OnGoing or {}) do
            print(string.format("  %s → %s/%s Completed=%s",
                k, tostring(v.Progress or 0), tostring(v.Goal),
                tostring(v.Completed)))
        end
        local q = GetActiveQuest()
        print("\n[Active]")
        if q then
            print("  " .. q.missionId .. " | " .. q.name)
            print("  Zone: " .. tostring(q.zoneId) .. " | Diff: " .. tostring(q.difficulty))
            print("  Progress: " .. q.progress .. "/" .. q.goal)
        else
            print("  (none)")
        end
    end,
})
DebugGroup:AddButton({
    Text = "Debug Enemies (Console)",
    Func = function()
        print("\n=== ENEMIES ===")
        print("EnemiesManager:", EnemiesManager and "OK" or "MISSING")
        local enemies = IterateLiveEnemies()
        print("Live count:", #enemies)
        local char = LocalPlayer.Character
        local myHrp = char and char:FindFirstChild("HumanoidRootPart")
        for i, e in ipairs(enemies) do
            if i > 25 then print("  ..."); break end
            local info = GetMobInfo(e.model)
            local dist = myHrp and math.floor((myHrp.Position - e.hrp.Position).Magnitude) or "?"
            print(string.format("  [%d] %s | diff=%s | %sm",
                i, tostring(info.name), tostring(info.difficulty), tostring(dist)))
        end
    end,
})

local BrowserGroup = Tabs.Quest:AddRightGroupbox("All OnGoing Missions", "list")
local OnGoingSummaryLabel = BrowserGroup:AddLabel("Loading...", true)

-- ── EXTRAS TAB ──────────────────────────────────────────────
local ChampGroup = Tabs.Extras:AddLeftGroupbox("Auto Champions ★", "star")
ChampGroup:AddToggle("AutoChampSpin", { Text="Auto Champion Spin", Default=false })
ChampGroup:AddDropdown("ChampZone", {
    Values  = ChampionSpinDisplay,
    Default = ChampionSpinDisplay[1] or "Skylands",
    Text    = "Zone",
})
ChampGroup:AddButton({
    Text = "Manual Spin",
    Func = function()
        local zoneId = ChampionSpinIdMap[Options.ChampZone.Value]
        if zoneId then Actions.HiddenChampionSpin(zoneId) end
    end,
})
ChampGroup:AddButton({ Text="Force Stop", Func=function() Actions.GachaStop("Champions") end })

local RankupGroup = Tabs.Extras:AddLeftGroupbox("Auto Rankup", "arrow-up")
RankupGroup:AddToggle("AutoRankup", { Text="Auto Rankup Power", Default=false })
RankupGroup:AddSlider("RankupDelay", { Text="Rankup Delay", Default=2, Min=0.5, Max=30, Rounding=1, Suffix="s" })

local GachaGroup = Tabs.Extras:AddRightGroupbox("Auto Gacha (" .. #GachaData .. ")", "gift")
local gachaTogglesList = {}
for _, gacha in ipairs(GachaData) do
    local toggleName = "AutoGacha_" .. gacha.id
    table.insert(gachaTogglesList, { toggleName=toggleName, gacha=gacha })
    local zoneText = gacha.requireZone
        and (" [" .. (ZoneDisplayNames[gacha.requireZone] or gacha.requireZone) .. "]") or ""
    GachaGroup:AddToggle(toggleName, {
        Text = "Auto " .. gacha.display .. zoneText,
        Default = false,
    })
end
GachaGroup:AddDivider()
GachaGroup:AddButton({
    Text = "Stop All Gacha",
    Func = function()
        for _, g in ipairs(GachaData) do Actions.GachaStop(g.id) end
        Actions.GachaStop("Champions")
    end,
})

-- ── SUMMON TAB ──────────────────────────────────────────────
local BannerGroup = Tabs.Summon:AddLeftGroupbox("Auto Banner Summon", "gift")
BannerGroup:AddToggle("AutoBanner", { Text="Auto Banner Summon", Default=false })
BannerGroup:AddDropdown("BannerName", {
    Values  = BannerData,
    Default = BannerData[1] or "",
    Text    = "Banner",
})
BannerGroup:AddDropdown("BannerCount", {
    Values  = {"1", "10"},
    Default = "10",
    Text    = "Rolls per Summon",
})
BannerGroup:AddDropdown("BannerRollType", {
    Values  = {"Normal", "Premium"},
    Default = "Normal",
    Text    = "Ticket Type",
})
BannerGroup:AddSlider("BannerDelay", { Text="Summon Delay", Default=5, Min=1, Max=60, Rounding=1, Suffix="s" })
BannerGroup:AddButton({
    Text = "Manual Summon",
    Func = function()
        local count = tonumber(Options.BannerCount.Value) or 1
        Actions.HiddenBannerRoll(Options.BannerName.Value, count, Options.BannerRollType.Value)
    end,
})

local BannerInfoGroup = Tabs.Summon:AddRightGroupbox("Info", "info")
BannerInfoGroup:AddLabel("Available Banners:", true)
for _, b in ipairs(BannerData) do BannerInfoGroup:AddLabel("• " .. b, true) end

-- ── TELEPORT TAB ────────────────────────────────────────────
local TeleportGroup = Tabs.Teleport:AddLeftGroupbox("Zones", "map-pin")
for _, zone in ipairs(ZoneData) do
    TeleportGroup:AddButton({
        Text = "TP: " .. zone.display,
        Func = function()
            Actions.Teleport(zone.id)
            invalidateTarget()
        end,
    })
end

-- ── UI SETTINGS ─────────────────────────────────────────────
local MenuGroup = Tabs["UI Settings"]:AddLeftGroupbox("Menu", "wrench")
MenuGroup:AddToggle("KeybindMenuOpen", {
    Default = Library.KeybindFrame.Visible,
    Text = "Open Keybind Menu",
    Callback = function(v) Library.KeybindFrame.Visible = v end,
})
MenuGroup:AddToggle("ShowCustomCursor", {
    Text = "Custom Cursor",
    Default = Library.ShowCustomCursor,
    Callback = function(v) Library.ShowCustomCursor = v end,
})
MenuGroup:AddDropdown("NotificationSide", {
    Values = {"Left", "Right"},
    Default = "Right",
    Text = "Notification Side",
    Callback = function(v) Library:SetNotifySide(v) end,
})
MenuGroup:AddDivider()
MenuGroup:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", {
    Default = "RightShift",
    NoUI = true,
    Text = "Menu keybind",
})
MenuGroup:AddButton("Unload Script", function()
    Library:Unload()
end)

Library.ToggleKeybind = Options.MenuKeybind

-- ═══════════════════════════════════════════════════════════
-- HEARTBEAT: POSITIONING
-- ═══════════════════════════════════════════════════════════
RunService.Heartbeat:Connect(function()
    if Library.Unloaded then return end
    local char = LocalPlayer.Character; if not char then return end
    local myHrp = char:FindFirstChild("HumanoidRootPart"); if not myHrp then return end

    if not (Toggles.AutoAttack.Value or Toggles.AutoQuest.Value) then
        if myHrp.Anchored then myHrp.Anchored = false end; return
    end
    if not currentTarget or not currentTarget.Parent then
        if myHrp.Anchored then myHrp.Anchored = false end; return
    end

    local hum = currentTarget:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then
        if myHrp.Anchored then myHrp.Anchored = false end
        invalidateTarget(); return
    end

    local mobHrp = currentTarget:FindFirstChild("HumanoidRootPart"); if not mobHrp then return end
    local myHum  = char:FindFirstChildOfClass("Humanoid")
    if myHum then myHum.PlatformStand = false end

    local targetPos, lookAt
    if Toggles.SmartGroup.Value and currentGroup and #currentGroup > 1 then
        local livePos = {}
        for _, m in ipairs(currentGroup) do
            if m.mob and m.mob.Parent then
                local h   = m.mob:FindFirstChildOfClass("Humanoid")
                local hrp = m.mob:FindFirstChild("HumanoidRootPart")
                if h and h.Health > 0 and hrp then table.insert(livePos, hrp.Position) end
            end
        end
        if #livePos > 1 then
            local sum = Vector3.zero
            for _, p in ipairs(livePos) do sum = sum + p end
            local center = sum / #livePos
            targetPos = Vector3.new(center.X, mobHrp.Position.Y, center.Z)
            lookAt = mobHrp.Position
            currentGroupSize = #livePos
        else
            local dir = (myHrp.Position - mobHrp.Position)
            dir = Vector3.new(dir.X,0,dir.Z)
            dir = dir.Magnitude < 0.01 and Vector3.new(0,0,1) or dir.Unit
            local mp = mobHrp.Position + dir * HOVER_DISTANCE
            targetPos = Vector3.new(mp.X, mobHrp.Position.Y, mp.Z)
            lookAt = mobHrp.Position; currentGroupSize = 1
        end
    else
        local dir = (myHrp.Position - mobHrp.Position)
        dir = Vector3.new(dir.X,0,dir.Z)
        dir = dir.Magnitude < 0.01 and Vector3.new(0,0,1) or dir.Unit
        local mp = mobHrp.Position + dir * HOVER_DISTANCE
        targetPos = Vector3.new(mp.X, mobHrp.Position.Y, mp.Z)
        lookAt = mobHrp.Position
    end

    myHrp.CFrame = CFrame.lookAt(targetPos, lookAt)
    myHrp.AssemblyLinearVelocity  = Vector3.zero
    myHrp.AssemblyAngularVelocity = Vector3.zero

    if Toggles.UseAnchor.Value then myHrp.Anchored = true
    elseif myHrp.Anchored then myHrp.Anchored = false end
end)

-- Invalidate target when filter/priority toggles change
Toggles.PriorityMob:OnChanged(function() invalidateTarget() end)
Toggles.FallbackAny:OnChanged(function() invalidateTarget() end)
Toggles.SmartGroup:OnChanged(function() invalidateTarget() end)

-- ═══════════════════════════════════════════════════════════
-- ATTACK LOOP
-- ═══════════════════════════════════════════════════════════
task.spawn(function()
    while task.wait() do
        if Library.Unloaded then break end
        local shouldFarm = Toggles.AutoAttack.Value or Toggles.AutoQuest.Value
        if not shouldFarm then
            currentTarget=nil; currentGroup=nil; currentGroupSize=0
            task.wait(0.1)
        else
            local hero = GetCurrentHero()

            if needNewTarget or not currentTarget or not currentTarget.Parent then
                needNewTarget = false
                local filter, ignoreRange = nil, false

                if Toggles.PriorityMob.Value then
                    local val = Options.SelectedMob.Value
                    if type(val) == "table" then
                        local hasAny = false
                        for _, v in pairs(val) do if v then hasAny=true; break end end
                        if hasAny then
                            filter = { mobNames = val }
                            ignoreRange = true
                        end
                    end
                end

                if not filter and Toggles.AutoQuest.Value and ActiveQuestFilter then
                    filter = ActiveQuestFilter
                    ignoreRange = true
                end

                local mob, group
                if Toggles.SmartGroup.Value then
                    mob, group = GetMobGroup(filter, Options.GroupRadius.Value, ignoreRange)
                else
                    mob = GetSingleTarget(filter, ignoreRange)
                end

                if not mob and Toggles.FallbackAny.Value and filter then
                    if Toggles.SmartGroup.Value then
                        mob, group = GetMobGroup(nil, Options.GroupRadius.Value, false)
                    else
                        mob = GetSingleTarget(nil, false)
                    end
                end

                setCurrentTarget(mob)
                currentGroup     = group
                currentGroupSize = group and #group or 0
                comboIndex       = 1
            end

            if currentTarget and hero ~= "" then
                local hum = currentTarget:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 then
                    Actions.M1(hero, comboIndex)
                    comboIndex = comboIndex % 4 + 1
                else
                    invalidateTarget()
                end
            end

            task.wait(ATTACK_DELAY)
        end
    end
end)

-- ═══════════════════════════════════════════════════════════
-- SKILL / ULT / RANKUP / BANNER LOOPS
-- ═══════════════════════════════════════════════════════════
task.spawn(function() while task.wait() do
    if Library.Unloaded then break end
    if Toggles.AutoSkill.Value then Actions.CastSkill(); task.wait(Options.SkillDelay.Value)
    else task.wait(0.5) end
end end)
task.spawn(function() while task.wait() do
    if Library.Unloaded then break end
    if Toggles.AutoUltimate.Value then Actions.CastUltimate(); task.wait(Options.UltDelay.Value)
    else task.wait(0.5) end
end end)
task.spawn(function() while task.wait() do
    if Library.Unloaded then break end
    if Toggles.AutoRankup.Value then Actions.RankupPower(); task.wait(Options.RankupDelay.Value)
    else task.wait(0.5) end
end end)
task.spawn(function() while task.wait() do
    if Library.Unloaded then break end
    if Toggles.AutoBanner.Value then
        local count = tonumber(Options.BannerCount.Value) or 10
        Actions.HiddenBannerRoll(Options.BannerName.Value, count, Options.BannerRollType.Value)
        task.wait(Options.BannerDelay.Value)
    else task.wait(1) end
end end)

-- ═══════════════════════════════════════════════════════════
-- CHAMPION + GACHA HANDLERS
-- ═══════════════════════════════════════════════════════════
Toggles.AutoChampSpin:OnChanged(function()
    if Toggles.AutoChampSpin.Value then
        local zoneId = ChampionSpinIdMap[Options.ChampZone.Value]
        if zoneId then Actions.HiddenChampionSpin(zoneId) end
    else
        Actions.GachaStop("Champions")
        task.wait(0.5)
        local anyActive = Toggles.AutoBanner.Value
        for _, g in ipairs(gachaTogglesList) do
            if Toggles[g.toggleName].Value then anyActive=true; break end
        end
        if not anyActive then ShowSpinPopups() end
    end
end)

Options.ChampZone:OnChanged(function()
    if Toggles.AutoChampSpin.Value then
        Actions.GachaStop("Champions"); task.wait(0.3)
        local zoneId = ChampionSpinIdMap[Options.ChampZone.Value]
        if zoneId then Actions.HiddenChampionSpin(zoneId) end
    end
end)

for _, g in ipairs(gachaTogglesList) do
    Toggles[g.toggleName]:OnChanged(function()
        if Toggles[g.toggleName].Value then
            Actions.HiddenSpin(g.gacha.id)
        else
            Actions.GachaStop(g.gacha.id); task.wait(0.5)
            local anyActive = Toggles.AutoChampSpin.Value or Toggles.AutoBanner.Value
            for _, g2 in ipairs(gachaTogglesList) do
                if g2.toggleName ~= g.toggleName and Toggles[g2.toggleName].Value then
                    anyActive = true; break
                end
            end
            if not anyActive then ShowSpinPopups() end
        end
    end)
end

-- Watchdog (re-fire every 15s)
task.spawn(function()
    while task.wait(15) do
        if Library.Unloaded then break end
        if Toggles.AutoChampSpin.Value then
            local zoneId = ChampionSpinIdMap[Options.ChampZone.Value]
            if zoneId then Actions.ChampionSpin(zoneId) end
        end
        for _, g in ipairs(gachaTogglesList) do
            if Toggles[g.toggleName].Value then Actions.GachaSpin(g.gacha.id) end
        end
    end
end)

-- Popup hider
task.spawn(function()
    while task.wait(0.25) do
        if Library.Unloaded then break end
        local anyActive = Toggles.AutoChampSpin.Value or Toggles.AutoBanner.Value
        if not anyActive then
            for _, g in ipairs(gachaTogglesList) do
                if Toggles[g.toggleName].Value then anyActive=true; break end
            end
        end
        if anyActive then HideSpinPopups() end
    end
end)

-- ═══════════════════════════════════════════════════════════
-- QUEST + UI UPDATE LOOP
-- ═══════════════════════════════════════════════════════════
task.spawn(function()
    while task.wait(1.0) do
        if Library.Unloaded then break end

        local newQuest = GetActiveQuest()
        ActiveQuest       = newQuest
        ActiveQuestFilter = BuildFilterFromQuest(newQuest)

        pcall(function()
            HeroLabel:SetText("Hero: " .. GetCurrentHero())
            GroupLabel:SetText(Toggles.SmartGroup.Value and currentGroupSize > 1
                and ("Group Farm: " .. currentGroupSize .. " mobs")
                or  "Group Farm: single target")
            if currentTarget and currentTarget.Parent then
                local info = GetMobInfo(currentTarget)
                TargetLabel:SetText("Target: " .. (info.name or "?") .. " (" .. (info.difficulty or "?") .. ")")
            else
                TargetLabel:SetText("Target: (searching...)")
            end
            if ActiveQuestFilter then
                FilterLabel:SetText(string.format("Filter: %s @ %s",
                    ActiveQuestFilter.difficulty or "?",
                    ActiveQuestFilter.zoneId and (ZoneDisplayNames[ActiveQuestFilter.zoneId] or ActiveQuestFilter.zoneId) or "any"))
            else
                FilterLabel:SetText("Filter: -")
            end
            local cz = GetPlayerCurrentZone()
            ZoneLabel:SetText("Current Zone: " .. (cz and (ZoneDisplayNames[cz] or cz) or "unknown"))

            if ActiveQuest then
                QLabelName:SetText("Name: " .. (ActiveQuest.name or "?"))
                QLabelId:SetText("ID: " .. ActiveQuest.missionId)
                QLabelZone:SetText("Zone: " .. (ZoneDisplayNames[ActiveQuest.zoneId] or ActiveQuest.zoneId or "?"))
                QLabelDiff:SetText("Difficulty: " .. (ActiveQuest.objective.Target or "?"))
                QLabelProgress:SetText("Progress: " .. ActiveQuest.progress .. "/" .. ActiveQuest.goal)
                QLabelStatus:SetText("Status: " .. (ActiveQuest.completed and "READY TO CLAIM ✓" or "In Progress"))
            else
                QLabelName:SetText("Name: (no active quest)")
                QLabelId:SetText("ID: -")
                QLabelZone:SetText("Zone: -")
                QLabelDiff:SetText("Difficulty: -")
                QLabelProgress:SetText("Progress: -")
                QLabelStatus:SetText("Status: -")
            end

            local missions = GetMissionsData()
            if missions and missions.OnGoing then
                local lines = {}
                for id, d in pairs(missions.OnGoing) do
                    local marker = d.Completed and "✓" or " "
                    table.insert(lines, string.format("[%s] %s: %s/%s",
                        marker, id, tostring(d.Progress or 0), tostring(d.Goal)))
                end
                table.sort(lines)
                OnGoingSummaryLabel:SetText(#lines > 0 and table.concat(lines, "\n") or "(none)")
            end
        end)

        if Toggles.AutoQuest.Value and Toggles.AutoClaim.Value and ActiveQuest and ActiveQuest.completed then
            ClaimQuest(ActiveQuest)
            Library:Notify({ Title="Auto Claim", Description="Claimed: "..ActiveQuest.name, Time=3 })
            invalidateTarget()
            task.wait(2)
        elseif Toggles.AutoQuest.Value and Toggles.AutoTeleport.Value
            and ActiveQuestFilter and ActiveQuestFilter.zoneId
            and not Toggles.PriorityMob.Value
        then
            if tick() - lastZoneTeleport > 8 then
                local currentZone = GetPlayerCurrentZone()
                local alreadyInZone = (currentZone == ActiveQuestFilter.zoneId)
                local exactMatches = 0
                for _, e in ipairs(IterateLiveEnemies()) do
                    if MatchesFilter(e.model, ActiveQuestFilter) then
                        exactMatches = exactMatches + 1
                    end
                end
                if exactMatches == 0 and not alreadyInZone then
                    local zoneName = ZoneDisplayNames[ActiveQuestFilter.zoneId] or ActiveQuestFilter.zoneId
                    Actions.Teleport(ActiveQuestFilter.zoneId)
                    lastZoneTeleport = tick()
                    invalidateTarget()
                    Library:Notify({ Title="Auto Quest", Description="TP → "..zoneName, Time=3 })
                    task.wait(5)
                end
            end
        end

        -- Wrong-difficulty swap
        if Toggles.AutoQuest.Value and ActiveQuestFilter and currentTarget and currentTarget.Parent then
            local info = GetMobInfo(currentTarget)
            if info.difficulty then
                local actual = info.difficulty
                local wanted = ActiveQuestFilter.difficulty
                local matches = (actual == wanted)
                if wanted == "boss" and (actual == "boss" or (info.name and IsChampion(info.name))) then
                    matches = true
                end
                if not matches then
                    local hasBetter = false
                    for _, e in ipairs(IterateLiveEnemies()) do
                        if MatchesFilter(e.model, ActiveQuestFilter) then
                            hasBetter = true; break
                        end
                    end
                    if hasBetter then invalidateTarget() end
                end
            end
        end
    end
end)

-- ═══════════════════════════════════════════════════════════
-- CHARACTER + UNLOAD
-- ═══════════════════════════════════════════════════════════
LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(0.5)
    local hrp = char:WaitForChild("HumanoidRootPart", 5)
    if hrp then hrp.Anchored = false end
    invalidateTarget()
end)

Library:OnUnload(function()
    pcall(function()
        local char = LocalPlayer.Character
        if char then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then hrp.Anchored = false end
        end
        for _, g in ipairs(GachaData) do Actions.GachaStop(g.id) end
        Actions.GachaStop("Champions")
        ShowSpinPopups()
    end)
end)

-- ═══════════════════════════════════════════════════════════
-- THEME + SAVE
-- ═══════════════════════════════════════════════════════════
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
ThemeManager:SetFolder("AnimeStarsScript")
SaveManager:SetFolder("AnimeStarsScript/configs")
SaveManager:BuildConfigSection(Tabs["UI Settings"])
ThemeManager:ApplyToTab(Tabs["UI Settings"])
SaveManager:LoadAutoloadConfig()

Library:Notify({
    Title = "Anime Stars v5.0",
    Description = string.format("%d zones | %d gachas | %d banners", #ZoneData, #GachaData, #BannerData),
    Time = 5,
})
