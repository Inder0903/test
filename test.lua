-- ═══════════════════════════════════════════════════════════
-- ANIME STARS SCRIPT v4.1 - EnemiesManager + Data-Driven Quests
-- ═══════════════════════════════════════════════════════════

local MacLib = loadstring(game:HttpGet("https://github.com/biggaboy212/Maclib/releases/latest/download/maclib.txt"))()

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
    if ok then ProfileManager = mod else warn("[v4.1] ProfileManager failed:", mod) end

    local ok2, mod2 = pcall(require, ReplicatedStorage.Client.Utils.QuestUtils)
    if ok2 then QuestUtils = mod2 else warn("[v4.1] QuestUtils failed:", mod2) end

    local ok3, mod3 = pcall(require, ReplicatedStorage.Shared.Directory.Quests)
    if ok3 then QuestsDirectory = mod3 else warn("[v4.1] Quests dir failed:", mod3) end

    local ok4, mod4 = pcall(require, ReplicatedStorage.Client.Zones.EnemiesManager)
    if ok4 then EnemiesManager = mod4 else warn("[v4.1] EnemiesManager failed:", mod4) end

    local ok5, mod5 = pcall(require, ReplicatedStorage.Shared.Directory.Enemies)
    if ok5 then EnemiesDir = mod5 else warn("[v4.1] Enemies dir failed:", mod5) end

    local ok6, mod6 = pcall(function()
        local m = ReplicatedStorage.Client:FindFirstChild("Zones")
        if m then m = m:FindFirstChild("ZonesManager") end
        return m and require(m)
    end)
    if ok6 then ZonesManager = mod6 end
end

local DIFFICULTY_MAP = {
    ["Easy"]       = "easy",
    ["Medium"]     = "medium",
    ["Hard"]       = "hard",
    ["Ultra Hard"] = "ultrahard",
    ["Boss"]       = "boss",
}

-- Reverse map: config difficulty tag → internal
-- The config's Difficulty field might be same strings or different
local CONFIG_DIFF_MAP = {
    ["Easy"]      = "easy",   ["easy"]      = "easy",
    ["Medium"]    = "medium", ["medium"]    = "medium",
    ["Hard"]      = "hard",   ["hard"]      = "hard",
    ["UltraHard"] = "ultrahard", ["Ultra Hard"] = "ultrahard", ["ultrahard"] = "ultrahard",
    ["Boss"]      = "boss",   ["boss"]      = "boss",
    ["Champion"]  = "boss",   ["champion"]  = "boss",
}

-- ═══════════════════════════════════════════════════════════
-- DYNAMIC DATA LOADERS
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
        for _, b in ipairs(dir:GetChildren()) do
            table.insert(result, b.Name)
        end
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

print(string.format("[Anime Stars v4.1] Zones: %d | Gachas: %d | Banners: %d",
    #ZoneData, #GachaData, #BannerData))
print("  ProfileManager: ", ProfileManager and "OK" or "MISSING")
print("  QuestUtils:     ", QuestUtils     and "OK" or "MISSING")
print("  QuestsDirectory:", QuestsDirectory and "OK" or "MISSING")
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
-- ENEMY DATA — via EnemiesManager (much more reliable)
-- ═══════════════════════════════════════════════════════════

-- Try to reach into the enemy's data via EnemiesManager, otherwise fall back to GUI
local function GetEnemyDataForModel(mobModel)
    if not EnemiesManager then return nil end
    -- EnemiesManager stores enemies keyed by their unique ID (a string)
    -- The mob model's Name usually IS this ID
    local ok, allEnemies = pcall(function() return EnemiesManager:GetAllEnemies() end)
    if not ok or type(allEnemies) ~= "table" then return nil end

    -- Try direct lookup by model name (usually matches)
    local direct = allEnemies[mobModel.Name]
    if direct then return direct end

    -- Try matching by model reference (some enemies expose .Model)
    for id, enemy in pairs(allEnemies) do
        if type(enemy) == "table" then
            local m = enemy.Model or enemy.model or enemy._model
            if m == mobModel then return enemy end
        end
    end
    return nil
end

-- Gets enemy config (Index, DisplayName, Difficulty, etc.) from mob model
local function GetEnemyConfig(mobModel)
    if not mobModel then return nil end

    -- Approach 1: check model attributes
    local index = mobModel:GetAttribute("Index")
        or mobModel:GetAttribute("EnemyIndex")
        or mobModel:GetAttribute("ConfigId")

    if index and EnemiesDir and EnemiesDir.GetConfig then
        local ok, cfg = pcall(EnemiesDir.GetConfig, EnemiesDir, index)
        if ok and cfg then return cfg end
    end

    -- Approach 2: via EnemiesManager
    local enemyData = GetEnemyDataForModel(mobModel)
    if enemyData then
        -- Try various common field names
        local cfg = enemyData.Config or enemyData.config or enemyData._config
        if cfg then return cfg end

        local idx = enemyData.Index or (enemyData.Data and enemyData.Data.Index)
        if idx and EnemiesDir and EnemiesDir.GetConfig then
            local ok, cfg2 = pcall(EnemiesDir.GetConfig, EnemiesDir, idx)
            if ok and cfg2 then return cfg2 end
        end
    end

    -- Approach 3: search EnemiesDir by DisplayName (from GUI or model name)
    local displayName = mobModel:GetAttribute("DisplayName")
    if not displayName then
        -- Fallback to GUI reading
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

    if displayName and EnemiesDir then
        -- Search all enemy configs for matching DisplayName
        local dir = ReplicatedStorage.Shared.Directory.Enemies:FindFirstChild("_Index")
        if dir then
            for _, zoneModule in ipairs(dir:GetChildren()) do
                local ok, data = pcall(require, zoneModule)
                if ok and type(data) == "table" then
                    for enemyId, enemyData in pairs(data) do
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

-- Returns {name, difficulty, zone, isChampion} for a mob model
local function GetMobInfo(mobModel)
    if not mobModel then return { name=nil, difficulty=nil } end

    local cfg = GetEnemyConfig(mobModel)
    if cfg then
        local diff = cfg.Difficulty or cfg.difficulty
        local normDiff = diff and CONFIG_DIFF_MAP[diff] or nil
        return {
            name       = cfg.DisplayName or cfg.Name,
            difficulty = normDiff or (diff and diff:lower():gsub("%s+","")) or nil,
            configDifficulty = diff,
            zone       = cfg.Zone or cfg.zone,
            isBoss     = cfg.IsBoss or cfg.Boss or (normDiff == "boss"),
        }
    end

    -- Ultimate fallback: GUI parsing (old behavior)
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
                        configDifficulty = diffText,
                    }
                end
            end
        end
    end

    return { name=nil, difficulty=nil }
end

local function NormDiff(str)
    if not str then return nil end
    return str:lower():gsub("%s+","")
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

-- filter: { mobNames = {["name"]=true}, difficulty = "ultrahard", zoneId = "..." }
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
    elseif filter.mobName then
        if not info.name then return false end
        if not NameMatches(info.name, filter.mobName) then return false end
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

-- Enumerate live enemies via EnemiesManager (or fall back to Workspace scan)
local function IterateLiveEnemies()
    local results = {}

    if EnemiesManager then
        local ok, allEnemies = pcall(function() return EnemiesManager:GetAllEnemies() end)
        if ok and type(allEnemies) == "table" then
            for id, enemy in pairs(allEnemies) do
                if type(enemy) == "table" then
                    local model = enemy.Model or enemy.model or enemy._model
                    if not model then
                        -- Try finding by name
                        local enemies = Workspace:FindFirstChild("Enemies")
                        if enemies then model = enemies:FindFirstChild(id) end
                    end
                    if model and model.Parent then
                        local hum = model:FindFirstChildOfClass("Humanoid")
                        local hrp = model:FindFirstChild("HumanoidRootPart")
                        if hum and hum.Health > 0 and hrp then
                            table.insert(results, { model=model, hrp=hrp, hum=hum, enemyData=enemy, id=id })
                        end
                    end
                end
            end
            if #results > 0 then return results end
        end
    end

    -- Fallback: Workspace.Enemies scan
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
function Actions.PinMission(missionId)
    Remote:FireServer({{Path="missions/pin", Params={missionId}}})
end
function Actions.HiddenSpin(name)        HideSpinPopups(); Actions.GachaSpin(name);    task.wait(0.1); HideSpinPopups() end
function Actions.HiddenChampionSpin(z)   HideSpinPopups(); Actions.ChampionSpin(z);    task.wait(0.1); HideSpinPopups() end
function Actions.HiddenBannerRoll(b,c,t) HideSpinPopups(); Actions.BannerRoll(b,c,t);  task.wait(0.1); HideSpinPopups() end

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
        stage       = stage,
        lineConfig  = lineConfig,
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
    -- Try ZonesManager first
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
-- STATE
-- ═══════════════════════════════════════════════════════════
local State = {
    AutoAttack     = false,
    AutoQuest      = false,
    AutoSkill      = false,
    AutoUltimate   = false,
    AutoRankup     = false,
    AutoChampSpin  = false,
    AutoBanner     = false,
    SmartGroup     = true,
    UseAnchor      = false,
    PriorityMob    = false,
    FallbackAny    = false,
    AutoTeleport   = true,
    AutoClaim      = true,

    SkillDelay     = 5,
    UltDelay       = 15,
    RankupDelay    = 2,
    GroupRadius    = 25,
    BannerDelay    = 5,

    SelectedZone   = FarmZoneList[1] or "",
    SelectedMob    = {},
    ChampZone      = ChampionSpinDisplay[1] or "",
    BannerName     = BannerData[1] or "",
    BannerCount    = 10,
    BannerRollType = "Normal",

    GachaEnabled   = {},
}
for _, g in ipairs(GachaData) do State.GachaEnabled[g.id] = false end

local ActiveQuest       = nil
local ActiveQuestFilter = nil
local lastZoneTeleport  = 0

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
-- WINDOW
-- ═══════════════════════════════════════════════════════════
local Window = MacLib:Window({
    Title    = "Anime Stars",
    Subtitle = "v4.1",
    Size     = UDim2.fromOffset(868, 650),
    DragStyle = 1,
    DisabledWindowControls = {},
    ShowUserInfo  = true,
    Keybind       = Enum.KeyCode.RightShift,
    AcrylicBlur   = true,
})

Window:GlobalSetting({ Name="UI Blur",        Default=Window:GetAcrylicBlurState(),   Callback=function(v) Window:SetAcrylicBlurState(v)   end })
Window:GlobalSetting({ Name="Notifications",  Default=Window:GetNotificationsState(), Callback=function(v) Window:SetNotificationsState(v) end })
Window:GlobalSetting({ Name="Show User Info", Default=Window:GetUserInfoState(),      Callback=function(v) Window:SetUserInfoState(v)      end })

local TabGroup = Window:TabGroup()
local Tabs = {
    Main     = TabGroup:Tab({ Name="Main",     Image="rbxassetid://18821914323" }),
    Farm     = TabGroup:Tab({ Name="Farm",     Image="rbxassetid://18821914323" }),
    Quest    = TabGroup:Tab({ Name="Quest",    Image="rbxassetid://18821914323" }),
    Extras   = TabGroup:Tab({ Name="Extras",   Image="rbxassetid://18821914323" }),
    Summon   = TabGroup:Tab({ Name="Summon",   Image="rbxassetid://18821914323" }),
    Teleport = TabGroup:Tab({ Name="Teleport", Image="rbxassetid://18821914323" }),
    Settings = TabGroup:Tab({ Name="Settings", Image="rbxassetid://10734950309" }),
}

-- ── MAIN TAB ────────────────────────────────────────────────
local MainLeft  = Tabs.Main:Section({ Side="Left"  })
local MainRight = Tabs.Main:Section({ Side="Right" })

MainLeft:Header({ Name = "Status" })
local HeroLabel   = MainLeft:Label({ Text = "Hero: " .. GetCurrentHero() })
local GroupLabel  = MainLeft:Label({ Text = "Group Farm: -" })
local TargetLabel = MainLeft:Label({ Text = "Target: -" })
local FilterLabel = MainLeft:Label({ Text = "Filter: -" })
local ZoneLabel   = MainLeft:Label({ Text = "Current Zone: -" })

MainRight:Header({ Name = "Server" })
MainRight:Button({ Name="Rejoin Server", Callback=function()
    game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer)
end })
MainRight:Button({ Name="Restore Popups", Callback=function()
    ShowSpinPopups()
    Window:Notify({ Title="Popups", Description="Restored", Lifetime=3 })
end })

-- ── FARM TAB ────────────────────────────────────────────────
local FarmLeft  = Tabs.Farm:Section({ Side="Left"  })
local FarmRight = Tabs.Farm:Section({ Side="Right" })

FarmLeft:Header({ Name = "Auto Farm" })
FarmLeft:Toggle({ Name="Auto Attack",      Default=false, Callback=function(v) State.AutoAttack = v end }, "AutoAttack")
FarmLeft:Toggle({ Name="Smart Group Farm", Default=true,  Callback=function(v) State.SmartGroup = v; invalidateTarget() end }, "SmartGroup")
FarmLeft:Slider({ Name="Group Radius", Default=25, Minimum=10, Maximum=60, Precision=0, Callback=function(v) State.GroupRadius = v end }, "GroupRadius")
FarmLeft:Toggle({ Name="Anchor Mode", Default=false, Callback=function(v) State.UseAnchor = v end }, "UseAnchor")

FarmLeft:Divider()
FarmLeft:Header({ Name = "Abilities" })
FarmLeft:Toggle({ Name="Auto Skill",     Default=false, Callback=function(v) State.AutoSkill = v end }, "AutoSkill")
FarmLeft:Slider({ Name="Skill Delay",    Default=5,  Minimum=1, Maximum=30, Precision=1, Callback=function(v) State.SkillDelay = v end }, "SkillDelay")
FarmLeft:Toggle({ Name="Auto Ultimate",  Default=false, Callback=function(v) State.AutoUltimate = v end }, "AutoUltimate")
FarmLeft:Slider({ Name="Ultimate Delay", Default=15, Minimum=5, Maximum=60, Precision=1, Callback=function(v) State.UltDelay = v end }, "UltDelay")

FarmRight:Header({ Name = "Target Filter" })
FarmRight:Toggle({ Name="Prioritize Selected Mobs",  Default=false, Callback=function(v) State.PriorityMob = v; invalidateTarget() end }, "PriorityMob")
FarmRight:Toggle({ Name="Fallback: Any Mob if None", Default=false, Callback=function(v) State.FallbackAny = v; invalidateTarget() end }, "FallbackAny")

local defaultFarmZone = FarmZoneList[1] or ""
local defaultZoneId   = ZoneNameToId[defaultFarmZone]
local defaultMobList  = AllByZone[defaultZoneId] or {}
local MobDropdown

-- Forward-declare mob dropdown so zone callback can refresh it
local MobDropdown

FarmRight:Dropdown({
    Name = "Zone",
    Multi = false,
    Required = true,
    Options = FarmZoneList,
    Default = 1,
    Callback = function(v)
        State.SelectedZone = v
        State.SelectedMob = {}
        invalidateTarget()
        
        local zId = ZoneNameToId[v]
        local mList = AllByZone[zId] or {}
        if #mList == 0 then mList = {"(no mobs)"} end
        
        if MobDropdown then
            -- Try multiple MacLib refresh methods (varies by version)
            local ok = pcall(function() MobDropdown:SetOptions(mList) end)
            if not ok then
                pcall(function() MobDropdown:Refresh(mList, true) end)
            end
            if not ok then
                pcall(function() MobDropdown:UpdateOptions(mList) end)
            end
            -- Clear the current selection
            pcall(function() MobDropdown:UpdateSelection(mList[1]) end)
        end
    end,
}, "SelectedZone")

MobDropdown = FarmRight:Dropdown({
    Name = "Priority Mob",
    Multi = false,
    Required = false,
    Options = #defaultMobList > 0 and defaultMobList or {"(none)"},
    Default = 1,
    Callback = function(v)
        if v and v ~= "(no mobs)" and v ~= "(none)" then
            State.SelectedMob = { [v] = true }
        else
            State.SelectedMob = {}
        end
        invalidateTarget()
    end,
}, "SelectedMob")

-- ── QUEST TAB ───────────────────────────────────────────────
local QuestLeft  = Tabs.Quest:Section({ Side="Left"  })
local QuestRight = Tabs.Quest:Section({ Side="Right" })

QuestLeft:Header({ Name = "Auto Quest" })
QuestLeft:Toggle({ Name="Auto Quest",            Default=false, Callback=function(v) State.AutoQuest    = v end }, "AutoQuest")
QuestLeft:Toggle({ Name="Auto Teleport to Zone", Default=true,  Callback=function(v) State.AutoTeleport = v end }, "AutoTeleport")
QuestLeft:Toggle({ Name="Auto Claim",            Default=true,  Callback=function(v) State.AutoClaim    = v end }, "AutoClaim")

QuestLeft:Button({
    Name = "Manual Claim Active",
    Callback = function()
        if ActiveQuest and ActiveQuest.completed then
            ClaimQuest(ActiveQuest)
            Window:Notify({ Title="Claim", Description="Claimed "..ActiveQuest.name, Lifetime=2 })
        else
            Window:Notify({ Title="Claim", Description="No completed quest", Lifetime=2 })
        end
    end,
})

QuestLeft:Divider()
QuestLeft:Header({ Name = "Active Quest" })
local QLabelName     = QuestLeft:Label({ Text = "Name: -" })
local QLabelId       = QuestLeft:Label({ Text = "ID: -" })
local QLabelZone     = QuestLeft:Label({ Text = "Zone: -" })
local QLabelDiff     = QuestLeft:Label({ Text = "Difficulty: -" })
local QLabelProgress = QuestLeft:Label({ Text = "Progress: -" })
local QLabelStatus   = QuestLeft:Label({ Text = "Status: -" })

QuestLeft:Divider()
QuestLeft:Header({ Name = "Debug" })

QuestLeft:Button({
    Name = "Debug Missions (Console)",
    Callback = function()
        print("\n=== MISSIONS DATA ===")
        local missions = GetMissionsData()
        if not missions then print("No missions data"); return end
        print("[Pinned]")
        for k, v in pairs(missions.Pinned or {}) do print("  "..tostring(k).." = "..tostring(v)) end
        print("[OnGoing]")
        for k, v in pairs(missions.OnGoing or {}) do
            print(string.format("  %s → %s/%s Completed=%s",
                k, tostring(v.Progress or 0), tostring(v.Goal),
                tostring(v.Completed)))
        end
        print("\n[Active Selection]")
        local q = GetActiveQuest()
        if q then
            print("  ID:", q.missionId, "| Name:", q.name)
            print("  Zone:", q.zoneId, "| Diff:", q.difficulty)
            print("  Progress:", q.progress .. "/" .. q.goal, "| Complete:", q.completed)
        else
            print("  (none)")
        end
    end,
})

QuestLeft:Button({
    Name = "Debug Enemies (Console)",
    Callback = function()
        print("\n=== ENEMIES SCAN ===")
        print("EnemiesManager:", EnemiesManager and "OK" or "MISSING")
        local enemies = IterateLiveEnemies()
        print("Total live:", #enemies)
        local char = LocalPlayer.Character
        local myHrp = char and char:FindFirstChild("HumanoidRootPart")
        for i, e in ipairs(enemies) do
            if i > 25 then print("  ...(more)"); break end
            local info = GetMobInfo(e.model)
            local dist = myHrp and math.floor((myHrp.Position - e.hrp.Position).Magnitude) or "?"
            print(string.format("  [%d] %s | diff=%s | %sm",
                i, tostring(info.name), tostring(info.difficulty), tostring(dist)))
        end
    end,
})

-- Right side: quest browser
QuestRight:Header({ Name = "All OnGoing Missions" })
local OnGoingSummaryLabel = QuestRight:Label({ Text = "Loading..." })

-- ── EXTRAS TAB ──────────────────────────────────────────────
local ExtrasLeft  = Tabs.Extras:Section({ Side="Left"  })
local ExtrasRight = Tabs.Extras:Section({ Side="Right" })

ExtrasLeft:Header({ Name = "Auto Champions" })
ExtrasLeft:Toggle({
    Name="Auto Champion Spin", Default=false,
    Callback=function(v)
        State.AutoChampSpin = v
        if v then
            local zoneId = ChampionSpinIdMap[State.ChampZone]
            if zoneId then Actions.HiddenChampionSpin(zoneId) end
        else
            Actions.GachaStop("Champions"); task.wait(0.5)
            local anyActive = State.AutoBanner
            for _, g in ipairs(GachaData) do
                if State.GachaEnabled[g.id] then anyActive=true; break end
            end
            if not anyActive then ShowSpinPopups() end
        end
    end,
}, "AutoChampSpin")

ExtrasLeft:Dropdown({
    Name="Champion Zone", Multi=false, Required=true,
    Options=ChampionSpinDisplay, Default=1,
    Callback=function(v)
        State.ChampZone = v
        if State.AutoChampSpin then
            Actions.GachaStop("Champions"); task.wait(0.3)
            local zoneId = ChampionSpinIdMap[v]
            if zoneId then Actions.HiddenChampionSpin(zoneId) end
        end
    end,
}, "ChampZone")

ExtrasLeft:Button({ Name="Manual Champion Spin", Callback=function()
    local zoneId = ChampionSpinIdMap[State.ChampZone]
    if zoneId then Actions.HiddenChampionSpin(zoneId) end
end })
ExtrasLeft:Button({ Name="Force Stop Champions", Callback=function()
    Actions.GachaStop("Champions")
end })

ExtrasLeft:Divider()
ExtrasLeft:Header({ Name = "Auto Rankup" })
ExtrasLeft:Toggle({ Name="Auto Rankup Power", Default=false, Callback=function(v) State.AutoRankup = v end }, "AutoRankup")
ExtrasLeft:Slider({ Name="Rankup Delay", Default=2, Minimum=0.5, Maximum=30, Precision=1, Callback=function(v) State.RankupDelay = v end }, "RankupDelay")

ExtrasRight:Header({ Name = "Auto Gacha (" .. #GachaData .. ")" })
for _, gacha in ipairs(GachaData) do
    local zoneText = gacha.requireZone
        and (" [" .. (ZoneDisplayNames[gacha.requireZone] or gacha.requireZone) .. "]") or ""
    ExtrasRight:Toggle({
        Name = "Auto " .. gacha.display .. zoneText,
        Default = false,
        Callback = function(v)
            State.GachaEnabled[gacha.id] = v
            if v then
                Actions.HiddenSpin(gacha.id)
            else
                Actions.GachaStop(gacha.id); task.wait(0.5)
                local anyActive = State.AutoChampSpin or State.AutoBanner
                for _, g in ipairs(GachaData) do
                    if State.GachaEnabled[g.id] then anyActive=true; break end
                end
                if not anyActive then ShowSpinPopups() end
            end
        end,
    }, "Gacha_" .. gacha.id)
end
ExtrasRight:Divider()
ExtrasRight:Button({ Name="Stop All Gacha", Callback=function()
    for _, g in ipairs(GachaData) do Actions.GachaStop(g.id) end
    Actions.GachaStop("Champions")
end })

-- ── SUMMON TAB ──────────────────────────────────────────────
local SummonLeft  = Tabs.Summon:Section({ Side="Left"  })
local SummonRight = Tabs.Summon:Section({ Side="Right" })

SummonLeft:Header({ Name = "Auto Banner Summon" })
SummonLeft:Toggle({
    Name="Auto Banner Summon", Default=false,
    Callback=function(v)
        State.AutoBanner = v
        if not v then
            task.wait(0.5)
            local anyActive = State.AutoChampSpin
            for _, g in ipairs(GachaData) do
                if State.GachaEnabled[g.id] then anyActive=true; break end
            end
            if not anyActive then ShowSpinPopups() end
        end
    end,
}, "AutoBanner")

SummonLeft:Dropdown({ Name="Banner",          Multi=false, Required=true, Options=#BannerData>0 and BannerData or {"(none)"}, Default=1, Callback=function(v) State.BannerName    = v end }, "BannerName")
SummonLeft:Dropdown({ Name="Rolls per Summon",Multi=false, Required=true, Options={"1","10"},   Default=2,                     Callback=function(v) State.BannerCount   = tonumber(v) or 10 end }, "BannerCount")
SummonLeft:Dropdown({ Name="Ticket Type",     Multi=false, Required=true, Options={"Normal","Premium"}, Default=1,             Callback=function(v) State.BannerRollType = v end }, "BannerRollType")
SummonLeft:Slider({ Name="Summon Delay", Default=5, Minimum=1, Maximum=60, Precision=1, Callback=function(v) State.BannerDelay = v end }, "BannerDelay")
SummonLeft:Button({ Name="Manual Summon", Callback=function()
    Actions.HiddenBannerRoll(State.BannerName, State.BannerCount, State.BannerRollType)
end })

SummonRight:Header({ Name = "Available Banners" })
for _, b in ipairs(BannerData) do SummonRight:Label({ Text="• "..b }) end

-- ── TELEPORT TAB ────────────────────────────────────────────
local TeleLeft  = Tabs.Teleport:Section({ Side="Left"  })
local TeleRight = Tabs.Teleport:Section({ Side="Right" })
TeleLeft:Header({ Name="Zones" })
local half = math.ceil(#ZoneData / 2)
for i, zone in ipairs(ZoneData) do
    local sec = (i <= half) and TeleLeft or TeleRight
    if i == half + 1 then TeleRight:Header({ Name="Zones (cont.)" }) end
    sec:Button({
        Name = zone.display,
        Callback = function()
            Actions.Teleport(zone.id)
            invalidateTarget()
        end,
    })
end

-- ── SETTINGS TAB ────────────────────────────────────────────
MacLib:SetFolder("AnimeStars")
Tabs.Settings:InsertConfigSection("Left")

local SettingsRight = Tabs.Settings:Section({ Side="Right" })
SettingsRight:Header({ Name = "Script" })
SettingsRight:Label({ Text = "Anime Stars v4.1" })
SettingsRight:SubLabel({ Text = "Toggle UI: Right Shift" })
SettingsRight:Divider()
SettingsRight:Button({
    Name = "Unload Script",
    Callback = function()
        Window:Dialog({
            Title = "Unload Script",
            Description = "Are you sure? All auto-features will stop.",
            Buttons = {
                { Name="Unload", Callback = function() task.wait(0.2); Window:Unload() end },
                { Name="Cancel" },
            },
        })
    end,
})
SettingsRight:Button({
    Name = "Rejoin Server",
    Callback = function()
        game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer)
    end,
})

-- ═══════════════════════════════════════════════════════════
-- HEARTBEAT: POSITIONING
-- ═══════════════════════════════════════════════════════════
RunService.Heartbeat:Connect(function()
    local char = LocalPlayer.Character; if not char then return end
    local myHrp = char:FindFirstChild("HumanoidRootPart"); if not myHrp then return end

    if not (State.AutoAttack or State.AutoQuest) then
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

    if State.SmartGroup and currentGroup and #currentGroup > 1 then
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

    if State.UseAnchor then myHrp.Anchored = true
    elseif myHrp.Anchored then myHrp.Anchored = false end
end)

-- ═══════════════════════════════════════════════════════════
-- ATTACK LOOP
-- ═══════════════════════════════════════════════════════════
task.spawn(function()
    while true do
        local shouldFarm = State.AutoAttack or State.AutoQuest
        if not shouldFarm then
            currentTarget=nil; currentGroup=nil; currentGroupSize=0
            task.wait(0.1); continue
        end

        local hero = GetCurrentHero()

        if needNewTarget or not currentTarget or not currentTarget.Parent then
            needNewTarget = false
            local filter, ignoreRange = nil, false

            if State.PriorityMob and next(State.SelectedMob) then
                filter      = { mobNames = State.SelectedMob }
                ignoreRange = true
            elseif State.AutoQuest and ActiveQuestFilter then
                filter      = ActiveQuestFilter
                ignoreRange = true
            end

            local mob, group
            if State.SmartGroup then
                mob, group = GetMobGroup(filter, State.GroupRadius, ignoreRange)
            else
                mob = GetSingleTarget(filter, ignoreRange)
            end

            if not mob and State.FallbackAny and filter then
                if State.SmartGroup then
                    mob, group = GetMobGroup(nil, State.GroupRadius, false)
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
end)

-- ═══════════════════════════════════════════════════════════
-- SKILL / ULTIMATE / RANKUP / BANNER LOOPS
-- ═══════════════════════════════════════════════════════════
task.spawn(function() while true do
    if State.AutoSkill    then Actions.CastSkill();    task.wait(State.SkillDelay)  else task.wait(0.5) end
end end)
task.spawn(function() while true do
    if State.AutoUltimate then Actions.CastUltimate(); task.wait(State.UltDelay)    else task.wait(0.5) end
end end)
task.spawn(function() while true do
    if State.AutoRankup   then Actions.RankupPower();  task.wait(State.RankupDelay) else task.wait(0.5) end
end end)
task.spawn(function() while true do
    if State.AutoBanner   then
        Actions.HiddenBannerRoll(State.BannerName, State.BannerCount, State.BannerRollType)
        task.wait(State.BannerDelay)
    else task.wait(1) end
end end)

-- ═══════════════════════════════════════════════════════════
-- GACHA / CHAMPION WATCHDOG
-- ═══════════════════════════════════════════════════════════
task.spawn(function()
    while task.wait(15) do
        if State.AutoChampSpin then
            local zoneId = ChampionSpinIdMap[State.ChampZone]
            if zoneId then Actions.ChampionSpin(zoneId) end
        end
        for _, g in ipairs(GachaData) do
            if State.GachaEnabled[g.id] then Actions.GachaSpin(g.id) end
        end
    end
end)

-- ═══════════════════════════════════════════════════════════
-- POPUP WATCHDOG
-- ═══════════════════════════════════════════════════════════
task.spawn(function()
    while task.wait(0.25) do
        local anyActive = State.AutoChampSpin or State.AutoBanner
        if not anyActive then
            for _, g in ipairs(GachaData) do
                if State.GachaEnabled[g.id] then anyActive=true; break end
            end
        end
        if anyActive then HideSpinPopups() end
    end
end)

-- ═══════════════════════════════════════════════════════════
-- MAIN QUEST + UI UPDATE LOOP
-- ═══════════════════════════════════════════════════════════
task.spawn(function()
    while task.wait(1.0) do
        local newQuest = GetActiveQuest()
        ActiveQuest       = newQuest
        ActiveQuestFilter = BuildFilterFromQuest(newQuest)

        pcall(function()
            HeroLabel:SetText("Hero: " .. GetCurrentHero())
            GroupLabel:SetText(State.SmartGroup and currentGroupSize > 1
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

        if State.AutoQuest and State.AutoClaim and ActiveQuest and ActiveQuest.completed then
            ClaimQuest(ActiveQuest)
            Window:Notify({ Title="Auto Claim", Description="Claimed: "..ActiveQuest.name, Lifetime=3 })
            invalidateTarget()
            task.wait(2)
            continue
        end

        if State.AutoQuest and State.AutoTeleport
            and ActiveQuestFilter and ActiveQuestFilter.zoneId
            and not State.PriorityMob
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
                    Window:Notify({ Title="Auto Quest", Description="TP → "..zoneName, Lifetime=3 })
                    task.wait(5)
                    continue
                end
            end
        end

        -- Wrong difficulty auto-swap
        if State.AutoQuest and ActiveQuestFilter and currentTarget and currentTarget.Parent then
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

Window.onUnloaded(function()
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
-- STARTUP
-- ═══════════════════════════════════════════════════════════
Tabs.Main:Select()
MacLib:LoadAutoLoadConfig()

Window:Notify({
    Title       = "Anime Stars v4.1",
    Description = "Loaded with EnemiesManager integration",
    Lifetime    = 5,
})
