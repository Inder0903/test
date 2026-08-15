-- ═══════════════════════════════════════════════════════════
-- ANIME STARS SCRIPT v2.8 - FULLY DYNAMIC
-- Auto-detects zones, gachas, mobs, banners from game data
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
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer
local Remote = ReplicatedStorage.Shared.Packages.Events.RemoteEvent

local ATTACK_DELAY = 0.05
local HOVER_DISTANCE = 5

LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

-- ═══════════════════════════════════════════════════════════
-- DYNAMIC DATA LOADERS
-- ═══════════════════════════════════════════════════════════

-- Load zones from game directory
local function LoadZones()
    local zones = {}
    local nameToId = {}
    local aliases = {}
    local dir = ReplicatedStorage.Shared.Directory.Zones:FindFirstChild("_Index")
    if dir then
        for _, zoneModule in ipairs(dir:GetChildren()) do
            local ok, data = pcall(require, zoneModule)
            if ok and type(data) == "table" then
                local id = data._id or zoneModule.Name
                local display = data.DisplayName or id
                local order = data.Order or 99
                table.insert(zones, {
                    id = id,
                    display = display,
                    order = order,
                    cost = data.Cost or 0,
                })
                nameToId[display] = id
                -- Auto-generate aliases from display name
                aliases[display:lower()] = id
                aliases[id:lower()] = id
                -- Split words for partial matching
                for word in display:lower():gmatch("%S+") do
                    if #word >= 4 then
                        aliases[word] = id
                    end
                end
            end
        end
    end
    -- Sort by order
    table.sort(zones, function(a, b) return a.order < b.order end)
    -- Manual aliases for common quest phrasing
    aliases["shinobi world"] = "desertvillage"
    aliases["shinobi"] = "desertvillage"
    aliases["namekian world"] = "alienplanet"
    aliases["namekian"] = "alienplanet"
    aliases["skypiea"] = "skylands"
    aliases["sky"] = "skylands"
    return zones, nameToId, aliases
end

-- Load gachas from game directory
local function LoadGachas()
    local result = {}
    local dir = ReplicatedStorage.Shared.Configs:FindFirstChild("GachaConfig")
    if dir then
        for _, gachaModule in ipairs(dir:GetChildren()) do
            local ok, data = pcall(require, gachaModule)
            if ok and type(data) == "table" then
                table.insert(result, {
                    id = gachaModule.Name,
                    display = data.DisplayName or gachaModule.Name,
                    requireZone = data.RequireZone,
                })
            end
        end
    end
    return result
end

-- Load enemies by zone
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

-- Load banner types
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

local ZoneData, ZoneNameToId, ZoneAliases = LoadZones()
local GachaData = LoadGachas()
local BannerData = LoadBanners()
local EnemiesByZone = GetEnemiesByZone()
local ChampionsByZone = GetChampionsByZone()

-- Build display list for zones
local ZoneList = {}
local ZoneDisplayNames = {}
for _, z in ipairs(ZoneData) do
    ZoneDisplayNames[z.id] = z.display
    table.insert(ZoneList, z.display)
end

-- Combined by zone (mobs + champions)
local AllByZone = {}
for zone, mobs in pairs(EnemiesByZone) do
    AllByZone[zone] = AllByZone[zone] or {}
    for _, m in ipairs(mobs) do table.insert(AllByZone[zone], m) end
end
for zone, champs in pairs(ChampionsByZone) do
    AllByZone[zone] = AllByZone[zone] or {}
    for _, c in ipairs(champs) do table.insert(AllByZone[zone], c) end
end

-- Zones with mobs only (for farming dropdown)
local FarmZoneList = {}
for _, z in ipairs(ZoneData) do
    if AllByZone[z.id] and #AllByZone[z.id] > 0 then
        table.insert(FarmZoneList, z.display)
    end
end

-- Gacha display lists
local GachaDisplayList = {}
local GachaDisplayToId = {}
for _, g in ipairs(GachaData) do
    table.insert(GachaDisplayList, g.display)
    GachaDisplayToId[g.display] = g
end

-- Champion spin zones (zones that have champions)
local ChampionSpinDisplay = {}
local ChampionSpinIdMap = {}
for _, z in ipairs(ZoneData) do
    if ChampionsByZone[z.id] and #ChampionsByZone[z.id] > 0 then
        table.insert(ChampionSpinDisplay, z.display)
        ChampionSpinIdMap[z.display] = z.id
    end
end

print("[Anime Stars] Loaded:")
print("  Zones:", #ZoneData)
print("  Gachas:", #GachaData)
print("  Banners:", #BannerData)
print("  Champion spin zones:", #ChampionSpinDisplay)

-- ═══════════════════════════════════════════════════════════
-- POPUP HIDING
-- ═══════════════════════════════════════════════════════════
local POPUPS_TO_HIDE = {
    "ChampionPopup", "GachaDropPopup", "RewardPopup", "ItemPopup",
    "BlessingPopup", "SkillPopup", "WeaponPopup", "IndexPopup",
    "TitlePopup", "SkillTreePopup", "BannerPopup",
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
-- MOB INFO + MATCHING
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
    return {name=nil, difficulty=nil}
end

local function NormDiff(str) if not str then return nil end return str:lower():gsub("%s+","") end

local function IsChampion(mobName)
    for _, champList in pairs(ChampionsByZone) do
        for _, c in ipairs(champList) do if c == mobName then return true end end
    end
    return false
end

local function NameMatches(actualName, wantedName)
    if not actualName or not wantedName then return false end
    local a = actualName:lower():gsub("%s+", "")
    local w = wantedName:lower():gsub("%s+", "")
    if a == w then return true end
    if a:find(w, 1, true) or w:find(a, 1, true) then return true end
    if math.abs(#a - #w) <= 1 and #a >= 3 then
        local minLen = math.min(#a, #w)
        local matches = 0
        for i = 1, minLen do
            if a:sub(i,i) == w:sub(i,i) then matches = matches + 1 end
        end
        if matches >= minLen - 1 then return true end
    end
    return false
end

local function MatchesFilter(mobModel, filter)
    if not filter then return true end
    local info = GetMobInfo(mobModel)
    if filter.mobNames and next(filter.mobNames) then
        if not info.name then return false end
        local matched = false
        for name, enabled in pairs(filter.mobNames) do
            if enabled and NameMatches(info.name, name) then matched = true; break end
        end
        if not matched then return false end
    elseif filter.mobName then
        if not info.name then return false end
        if not NameMatches(info.name, filter.mobName) then return false end
    end
    if filter.difficulty then
        local wanted = NormDiff(filter.difficulty)
        local actual = NormDiff(info.difficulty)
        if wanted == "boss" then
            if actual == "boss" then return true end
            if info.name and IsChampion(info.name) then return true end
            return false
        end
        if not actual then return false end
        return actual == wanted
    end
    return true
end

local function GetAllMatchingMobs(filter, ignoreRange)
    local char = LocalPlayer.Character
    if not char then return {} end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return {} end
    local enemies = Workspace:FindFirstChild("Enemies")
    if not enemies then return {} end
    local maxDist = ignoreRange and math.huge or 2000
    local mobs = {}
    for _, mob in ipairs(enemies:GetChildren()) do
        local mobHrp = mob:FindFirstChild("HumanoidRootPart")
        local hum = mob:FindFirstChildOfClass("Humanoid")
        if mobHrp and hum and hum.Health > 0 then
            local dist = (hrp.Position - mobHrp.Position).Magnitude
            if dist < maxDist and MatchesFilter(mob, filter) then
                table.insert(mobs, {mob=mob, hrp=mobHrp, dist=dist})
            end
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
    if #allMobs == 0 then return nil, nil, nil end
    local bestGroup = nil
    local bestScore = 0
    for _, anchor in ipairs(allMobs) do
        local group = {anchor}
        for _, other in ipairs(allMobs) do
            if other.mob ~= anchor.mob then
                local d = (anchor.hrp.Position - other.hrp.Position).Magnitude
                if d <= groupRadius then table.insert(group, other) end
            end
        end
        local score = #group * 1000 - anchor.dist
        if score > bestScore then bestScore = score; bestGroup = group end
    end
    if not bestGroup or #bestGroup == 0 then return nil, nil, nil end
    local sum = Vector3.zero
    for _, m in ipairs(bestGroup) do sum = sum + m.hrp.Position end
    local center = sum / #bestGroup
    return bestGroup[1].mob, bestGroup, center
end

-- ═══════════════════════════════════════════════════════════
-- REMOTES
-- ═══════════════════════════════════════════════════════════
local Actions = {}
function Actions.M1(hero, combo)
    Remote:FireServer({{Path="combat/m1", Params={hero, combo}}})
end
function Actions.CastSkill()
    Remote:FireServer({{Path="abilities/cast", Params={"Skill"}}})
end
function Actions.CastUltimate()
    Remote:FireServer({{Path="abilities/cast", Params={"Ultimate"}}})
end
function Actions.Teleport(zoneId)
    Remote:FireServer({{Path="zones/teleport", Params={zoneId}}})
end
function Actions.ChampionSpin(zoneId)
    Remote:FireServer({{Path="champions/spin", Params={"auto", zoneId}}})
end
function Actions.GachaSpin(gachaName)
    Remote:FireServer({{Path="gacha/spin", Params={gachaName, "auto"}}})
end
function Actions.GachaStop(gachaName)
    Remote:FireServer({{Path="gacha/stopAuto", Params={gachaName}}})
end
function Actions.RankupPower()
    Remote:FireServer({{Path="rankup/power", Params={}}})
end
function Actions.HiddenSpin(gachaName)
    HideSpinPopups(); Actions.GachaSpin(gachaName); task.wait(0.1); HideSpinPopups()
end
function Actions.HiddenChampionSpin(zoneId)
    HideSpinPopups(); Actions.ChampionSpin(zoneId); task.wait(0.1); HideSpinPopups()
end

local function GetCurrentHero()
    local char = LocalPlayer.Character
    if char then
        local heroAttr = char:GetAttribute("AnimationPack")
        if heroAttr and heroAttr ~= "" then return heroAttr end
    end
    return "Hawk"
end

-- ═══════════════════════════════════════════════════════════
-- QUEST
-- ═══════════════════════════════════════════════════════════
local function GetActiveQuest()
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return nil end
    local main = pg:FindFirstChild("Main"); if not main then return nil end
    local hud = main:FindFirstChild("Hud"); if not hud then return nil end
    local quest = hud:FindFirstChild("Quest"); if not quest then return nil end
    local info = quest:FindFirstChild("Info")
    local progress = quest:FindFirstChild("Progress")
    local claim = quest:FindFirstChild("Claim")
    local titleLabel = info and info:FindFirstChild("Title")
    local progressLabel = progress and progress:FindFirstChild("Label")
    local claimBtn = claim and claim:FindFirstChild("Button")
    local title = titleLabel and titleLabel:IsA("TextLabel") and titleLabel.Text or ""
    local prog = progressLabel and progressLabel:IsA("TextLabel") and progressLabel.Text or ""
    local canClaim = claim and claim.Visible or false
    if title == "" then return nil end
    return {title=title, progress=prog, canClaim=canClaim, claimButton=claimBtn}
end

local DIFFICULTY_KEYWORDS = {
    ["ultra hard"]="ultrahard",["ultra"]="ultrahard",
    ["hard"]="hard",["medium"]="medium",["easy"]="easy",
    ["boss"]="boss",["champion"]="boss",
}

local function ParseQuest(questText)
    if not questText or questText == "" then return nil end
    local lower = questText:lower()
    local result = {text=questText, zone=nil, zoneId=nil, difficulty=nil, mobName=nil}
    local diffOrder = {"ultra hard","ultra","hard","medium","easy","boss","champion"}
    for _, keyword in ipairs(diffOrder) do
        if lower:find(keyword, 1, true) then result.difficulty = DIFFICULTY_KEYWORDS[keyword]; break end
    end
    local sortedAliases = {}
    for alias, zoneId in pairs(ZoneAliases) do
        table.insert(sortedAliases, {alias=alias, zoneId=zoneId, len=#alias})
    end
    table.sort(sortedAliases, function(a,b) return a.len > b.len end)
    for _, a in ipairs(sortedAliases) do
        if lower:find(a.alias, 1, true) then
            result.zoneId = a.zoneId
            result.zone = ZoneDisplayNames[a.zoneId] or a.zoneId
            break
        end
    end
    for _, mobList in pairs(EnemiesByZone) do
        for _, mobName in ipairs(mobList) do
            if lower:find(mobName:lower(), 1, true) then result.mobName = mobName; break end
        end
        if result.mobName then break end
    end
    for _, champList in pairs(ChampionsByZone) do
        for _, champName in ipairs(champList) do
            if lower:find(champName:lower(), 1, true) then result.mobName = champName; break end
        end
        if result.mobName then break end
    end
    return result
end

local function ClickClaimButton()
    local q = GetActiveQuest()
    if q and q.canClaim and q.claimButton then
        local btn = q.claimButton
        pcall(function()
            if firesignal then
                firesignal(btn.MouseButton1Click)
                firesignal(btn.Activated)
            end
        end)
        pcall(function()
            local pos = btn.AbsolutePosition + btn.AbsoluteSize/2
            VirtualUser:Button1Down(pos)
            task.wait(0.05)
            VirtualUser:Button1Up(pos)
        end)
        return true
    end
    return false
end

-- ═══════════════════════════════════════════════════════════
-- WINDOW
-- ═══════════════════════════════════════════════════════════
Library.ForceCheckbox = false
Library.ShowToggleFrameInKeybinds = true

local Window = Library:CreateWindow({
    Title = "Anime Stars", Footer = "v2.8 Dynamic",
    Icon = 95816097006870, NotifySide = "Right",
    ShowCustomCursor = true,
})

local Tabs = {
    Main = Window:AddTab("Main", "user"),
    Farm = Window:AddTab("Auto Farm", "swords"),
    Quest = Window:AddTab("Auto Quest", "scroll-text"),
    Extras = Window:AddTab("Auto Extras", "sparkles"),
    Teleport = Window:AddTab("Teleports", "map"),
    ["UI Settings"] = Window:AddTab("UI Settings", "settings"),
}

local MainGroup = Tabs.Main:AddLeftGroupbox("Info", "info")
MainGroup:AddLabel("Anime Stars v2.8 (Dynamic)", true)
MainGroup:AddLabel("Anti-AFK: Enabled", true)
MainGroup:AddLabel("Zones: " .. #ZoneData .. " | Gachas: " .. #GachaData, true)
local HeroDisplayLabel = MainGroup:AddLabel("Current Hero: " .. GetCurrentHero(), true)
local GroupInfoLabel = MainGroup:AddLabel("Group Farm: -", true)
local TargetInfoLabel = MainGroup:AddLabel("Target: -", true)

local PlayerGroup = Tabs.Main:AddRightGroupbox("Server", "server")
PlayerGroup:AddButton({
    Text = "Rejoin Server",
    Func = function()
        game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer)
    end,
})
PlayerGroup:AddButton({
    Text = "Restore Popups",
    Func = function() ShowSpinPopups() end,
})

local invalidateTarget

-- AUTO FARM
local FarmGroup = Tabs.Farm:AddLeftGroupbox("Auto Farm", "swords")
FarmGroup:AddToggle("AutoAttack", { Text = "Auto Attack", Default = false })
FarmGroup:AddToggle("SmartGroupFarm", { Text = "Smart Group Farm ★", Default = true })
FarmGroup:AddSlider("GroupRadius", {
    Text = "Group Detection Radius",
    Default = 25, Min = 10, Max = 60, Rounding = 0, Suffix = " studs",
})
FarmGroup:AddToggle("UseAnchor", { Text = "Anchor Mode", Default = false })
FarmGroup:AddDivider()
FarmGroup:AddToggle("AutoSkill", { Text = "Auto Skill", Default = false })
FarmGroup:AddSlider("SkillDelay", { Text = "Skill Delay", Default = 5, Min = 1, Max = 30, Rounding = 1, Suffix = "s" })
FarmGroup:AddToggle("AutoUltimate", { Text = "Auto Ultimate", Default = false })
FarmGroup:AddSlider("UltimateDelay", { Text = "Ultimate Delay", Default = 15, Min = 5, Max = 60, Rounding = 1, Suffix = "s" })

local TargetGroup = Tabs.Farm:AddRightGroupbox("Target Filter", "target")
TargetGroup:AddToggle("PriorityMob", { 
    Text = "Prioritize Selected Mobs (overrides quest)", 
    Default = false,
})
TargetGroup:AddToggle("FallbackToAny", { 
    Text = "Fallback: Any Mob if None Found",
    Default = true,
})
TargetGroup:AddDropdown("SelectedZone", {
    Values = FarmZoneList, Default = FarmZoneList[1] or "Skylands", Text = "Zone",
    Callback = function(zoneName)
        local zoneId = ZoneNameToId[zoneName]
        local mobList = AllByZone[zoneId] or {}
        if #mobList == 0 then mobList = {"(no mobs)"} end
        Options.SelectedMob:SetValues(mobList)
        Options.SelectedMob:SetValue({})
        if invalidateTarget then invalidateTarget() end
    end,
})

local defaultZone = FarmZoneList[1] or "Skylands"
local defaultZoneId = ZoneNameToId[defaultZone]
local defaultMobs = AllByZone[defaultZoneId] or {"Sand"}

TargetGroup:AddDropdown("SelectedMob", {
    Values = defaultMobs,
    Default = defaultMobs[1],
    Text = "Priority Mobs (multi)",
    Searchable = true,
    Multi = true,
    Callback = function()
        if invalidateTarget then invalidateTarget() end
    end,
})

-- AUTO QUEST
local QuestGroup = Tabs.Quest:AddLeftGroupbox("Auto Quest", "scroll-text")
QuestGroup:AddToggle("AutoQuest", { Text = "Auto Quest", Default = false })
QuestGroup:AddToggle("AutoTeleportToZone", { Text = "Auto TP to Zone", Default = true })
QuestGroup:AddToggle("AutoClaim", { Text = "Auto Claim", Default = true })

local QuestTitleLabel = QuestGroup:AddLabel("Quest: (waiting...)", true)
local QuestProgressLabel = QuestGroup:AddLabel("Progress: -", true)
local QuestZoneLabel = QuestGroup:AddLabel("Zone: -", true)
local QuestDiffLabel = QuestGroup:AddLabel("Difficulty: -", true)
local QuestTargetLabel = QuestGroup:AddLabel("Target: -", true)
local QuestClaimLabel = QuestGroup:AddLabel("Claim Ready: No", true)

QuestGroup:AddButton({
    Text = "Refresh", Func = function()
        local q = GetActiveQuest()
        if q then
            local p = ParseQuest(q.title)
            QuestTitleLabel:SetText("Quest: " .. q.title)
            QuestProgressLabel:SetText("Progress: " .. q.progress)
            QuestZoneLabel:SetText("Zone: " .. (p.zone or "Unknown"))
            QuestDiffLabel:SetText("Difficulty: " .. (p.difficulty or "Any"))
            QuestTargetLabel:SetText("Target: " .. (p.mobName or "Any"))
            QuestClaimLabel:SetText("Claim Ready: " .. (q.canClaim and "YES" or "No"))
        end
    end,
})
QuestGroup:AddButton({
    Text = "Manual Claim", Func = function()
        local ok = ClickClaimButton()
        Library:Notify({Title="Claim", Description=ok and "Clicked!" or "Nothing", Time=3})
    end,
})

-- EXTRAS - CHAMPIONS
local ChampionGroup = Tabs.Extras:AddLeftGroupbox("Auto Champions ★", "star")
ChampionGroup:AddToggle("AutoChampionSpin", { Text = "Auto Champion Spin", Default = false })
ChampionGroup:AddDropdown("ChampionSpinZone", {
    Values = ChampionSpinDisplay, 
    Default = ChampionSpinDisplay[1] or "Skylands", 
    Text = "Zone",
})
ChampionGroup:AddButton({
    Text = "Manual Spin",
    Func = function()
        local zoneName = Options.ChampionSpinZone.Value
        local zoneId = ChampionSpinIdMap[zoneName]
        if zoneId then Actions.HiddenChampionSpin(zoneId) end
    end,
})
ChampionGroup:AddButton({ Text = "Force Stop", Func = function() Actions.GachaStop("Champions") end })

-- EXTRAS - GACHAS (fully dynamic!)
local GachaGroup = Tabs.Extras:AddRightGroupbox("Auto Gacha (" .. #GachaData .. " available)", "gift")

local gachaTogglesList = {} -- track for stop button

for _, gacha in ipairs(GachaData) do
    local toggleName = "AutoGacha_" .. gacha.id
    table.insert(gachaTogglesList, {toggleName = toggleName, gacha = gacha})
    
    local zoneText = gacha.requireZone and (" [" .. (ZoneDisplayNames[gacha.requireZone] or gacha.requireZone) .. "]") or ""
    
    GachaGroup:AddToggle(toggleName, { 
        Text = "Auto " .. gacha.display .. zoneText,
        Default = false,
    })
end

GachaGroup:AddDivider()

for _, gacha in ipairs(GachaData) do
    GachaGroup:AddButton({ 
        Text = "Manual " .. gacha.display, 
        Func = function() Actions.HiddenSpin(gacha.id) end,
    })
end

GachaGroup:AddButton({ 
    Text = "Stop All Gacha", 
    Func = function()
        for _, g in ipairs(GachaData) do
            Actions.GachaStop(g.id)
        end
        Actions.GachaStop("Champions")
    end,
})

-- EXTRAS - RANKUP
local RankupGroup = Tabs.Extras:AddLeftGroupbox("Auto Rankup", "arrow-up")
RankupGroup:AddToggle("AutoRankup", { Text = "Auto Rankup Power", Default = false })
RankupGroup:AddSlider("RankupDelay", {
    Text = "Delay", Default = 2, Min = 0.5, Max = 30, Rounding = 1, Suffix = "s",
})

-- DEBUG
local DebugGroup = Tabs.Quest:AddRightGroupbox("Debug", "bug")
DebugGroup:AddButton({
    Text = "Scan Mobs", Func = function()
        local enemies = Workspace:FindFirstChild("Enemies")
        if not enemies then return end
        local char = LocalPlayer.Character
        local myHrp = char and char:FindFirstChild("HumanoidRootPart")
        print("\n=== MOBS ===")
        local count = 0
        for _, mob in ipairs(enemies:GetChildren()) do
            local info = GetMobInfo(mob)
            local mobHrp = mob:FindFirstChild("HumanoidRootPart")
            if info.name and mobHrp then
                count = count + 1
                local dist = myHrp and math.floor((myHrp.Position - mobHrp.Position).Magnitude) or "?"
                print(string.format("[%d] %s | %s | %sm", count, info.name, tostring(info.difficulty), tostring(dist)))
                if count >= 30 then break end
            end
        end
    end,
})
DebugGroup:AddButton({
    Text = "Test Priority", Func = function()
        local val = Options.SelectedMob.Value
        local wantedList = {}
        if type(val) == "table" then
            for name, enabled in pairs(val) do
                if enabled then table.insert(wantedList, name) end
            end
        end
        print("\n=== PRIORITY TEST ===")
        print("Wanted:", table.concat(wantedList, ", "))
        local enemies = Workspace:FindFirstChild("Enemies")
        if not enemies then return end
        local char = LocalPlayer.Character
        local myHrp = char and char:FindFirstChild("HumanoidRootPart")
        local matches = 0
        for _, mob in ipairs(enemies:GetChildren()) do
            local info = GetMobInfo(mob)
            local mobHrp = mob:FindFirstChild("HumanoidRootPart")
            if info.name and mobHrp then
                local matched = false
                for _, w in ipairs(wantedList) do
                    if NameMatches(info.name, w) then matched = true; break end
                end
                if matched then
                    matches = matches + 1
                    local dist = myHrp and math.floor((myHrp.Position - mobHrp.Position).Magnitude) or "?"
                    print(string.format("★ %s | %sm", info.name, tostring(dist)))
                end
            end
        end
        print("Total matches:", matches)
    end,
})

-- ═══════════════════════════════════════════════════════════
-- TARGET / POSITIONING
-- ═══════════════════════════════════════════════════════════
local currentTarget = nil
local currentGroup = nil
local currentGroupSize = 0
local comboIndex = 1
local needNewTarget = true

invalidateTarget = function()
    needNewTarget = true
    currentTarget = nil
end

Toggles.PriorityMob:OnChanged(function() invalidateTarget() end)
Toggles.FallbackToAny:OnChanged(function() invalidateTarget() end)
Toggles.SmartGroupFarm:OnChanged(function() invalidateTarget() end)

local currentTargetDiedConn = nil
local function setCurrentTarget(mob)
    if currentTargetDiedConn then currentTargetDiedConn:Disconnect(); currentTargetDiedConn = nil end
    currentTarget = mob
    if mob then
        local hum = mob:FindFirstChildOfClass("Humanoid")
        if hum then
            currentTargetDiedConn = hum.Died:Connect(invalidateTarget)
        end
        mob.AncestryChanged:Once(function(_, parent)
            if not parent then invalidateTarget() end
        end)
    end
end

RunService.Heartbeat:Connect(function()
    if Library.Unloaded then return end
    local char = LocalPlayer.Character
    if not char then return end
    local myHrp = char:FindFirstChild("HumanoidRootPart")
    if not myHrp then return end
    
    if not (Toggles.AutoAttack.Value or Toggles.AutoQuest.Value) then
        if myHrp.Anchored then myHrp.Anchored = false end
        return
    end
    
    if not currentTarget or not currentTarget.Parent then
        if myHrp.Anchored then myHrp.Anchored = false end
        return
    end
    
    local hum = currentTarget:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then
        if myHrp.Anchored then myHrp.Anchored = false end
        invalidateTarget()
        return
    end
    
    local mobHrp = currentTarget:FindFirstChild("HumanoidRootPart")
    if not mobHrp then return end
    
    local myHum = char:FindFirstChildOfClass("Humanoid")
    if not myHum then return end
    myHum.PlatformStand = false
    
    local targetPos, lookAt
    
    if Toggles.SmartGroupFarm.Value and currentGroup and #currentGroup > 1 then
        local liveMembers = {}
        for _, m in ipairs(currentGroup) do
            if m.mob and m.mob.Parent then
                local h = m.mob:FindFirstChildOfClass("Humanoid")
                local hrp = m.mob:FindFirstChild("HumanoidRootPart")
                if h and h.Health > 0 and hrp then
                    table.insert(liveMembers, hrp.Position)
                end
            end
        end
        if #liveMembers > 1 then
            local sum = Vector3.zero
            for _, p in ipairs(liveMembers) do sum = sum + p end
            local center = sum / #liveMembers
            targetPos = Vector3.new(center.X, mobHrp.Position.Y, center.Z)
            lookAt = mobHrp.Position
            currentGroupSize = #liveMembers
        else
            local mobPos = mobHrp.Position
            local myPos = myHrp.Position
            local direction = (myPos - mobPos)
            direction = Vector3.new(direction.X, 0, direction.Z)
            if direction.Magnitude < 0.01 then direction = Vector3.new(0, 0, 1) else direction = direction.Unit end
            targetPos = mobPos + direction * HOVER_DISTANCE
            targetPos = Vector3.new(targetPos.X, mobPos.Y, targetPos.Z)
            lookAt = mobPos
            currentGroupSize = 1
        end
    else
        local mobPos = mobHrp.Position
        local myPos = myHrp.Position
        local direction = (myPos - mobPos)
        direction = Vector3.new(direction.X, 0, direction.Z)
        if direction.Magnitude < 0.01 then direction = Vector3.new(0, 0, 1) else direction = direction.Unit end
        targetPos = mobPos + direction * HOVER_DISTANCE
        targetPos = Vector3.new(targetPos.X, mobPos.Y, targetPos.Z)
        lookAt = mobPos
    end
    
    myHrp.CFrame = CFrame.lookAt(targetPos, lookAt)
    myHrp.AssemblyLinearVelocity = Vector3.zero
    myHrp.AssemblyAngularVelocity = Vector3.zero
    
    if Toggles.UseAnchor.Value then
        myHrp.Anchored = true
    else
        if myHrp.Anchored then myHrp.Anchored = false end
    end
end)

-- Popup hide watchdog
task.spawn(function()
    while task.wait(0.05) do
        if Library.Unloaded then break end
        local anyActive = Toggles.AutoChampionSpin.Value
        for _, g in ipairs(gachaTogglesList) do
            if Toggles[g.toggleName] and Toggles[g.toggleName].Value then anyActive = true; break end
        end
        if anyActive then HideSpinPopups() end
    end
end)

RunService.Heartbeat:Connect(function()
    if Library.Unloaded then return end
    if currentTarget and currentTarget.Parent then
        local hum = currentTarget:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then invalidateTarget() end
    end
end)

-- QUEST LOOP
local activeQuestData = nil
local lastZoneTeleport = 0

task.spawn(function()
    while task.wait(1.5) do
        if Library.Unloaded then break end
        pcall(function()
            HeroDisplayLabel:SetText("Current Hero: " .. GetCurrentHero())
            if Toggles.SmartGroupFarm.Value and currentGroupSize > 1 then
                GroupInfoLabel:SetText("Group Farm: " .. currentGroupSize .. " mobs")
            else
                GroupInfoLabel:SetText("Group Farm: single target")
            end
            if currentTarget then
                local info = GetMobInfo(currentTarget)
                TargetInfoLabel:SetText("Target: " .. (info.name or "?") .. " (" .. (info.difficulty or "?") .. ")")
            else
                TargetInfoLabel:SetText("Target: (searching...)")
            end
        end)
        local q = GetActiveQuest()
        if q then
            local parsed = ParseQuest(q.title)
            activeQuestData = parsed
            pcall(function()
                QuestTitleLabel:SetText("Quest: " .. q.title)
                QuestProgressLabel:SetText("Progress: " .. q.progress)
                QuestZoneLabel:SetText("Zone: " .. (parsed.zone or "Unknown"))
                QuestDiffLabel:SetText("Difficulty: " .. (parsed.difficulty or "Any"))
                QuestTargetLabel:SetText("Target: " .. (parsed.mobName or "Any"))
                QuestClaimLabel:SetText("Claim Ready: " .. (q.canClaim and "YES ✓" or "No"))
            end)
            if Toggles.AutoQuest.Value and Toggles.AutoClaim.Value and q.canClaim then
                task.wait(0.5)
                ClickClaimButton()
                Library:Notify({Title="Auto Claim", Description="Claimed!", Time=2})
                task.wait(2)
            end
            if Toggles.AutoQuest.Value and Toggles.AutoTeleportToZone.Value and parsed.zoneId and not Toggles.PriorityMob.Value then
                if tick() - lastZoneTeleport > 10 then
                    local hasMatchingMobs = false
                    local enemies = Workspace:FindFirstChild("Enemies")
                    if enemies then
                        local filter = {mobName = parsed.mobName, difficulty = parsed.difficulty}
                        for _, mob in ipairs(enemies:GetChildren()) do
                            local hum = mob:FindFirstChildOfClass("Humanoid")
                            if hum and hum.Health > 0 and MatchesFilter(mob, filter) then
                                hasMatchingMobs = true; break
                            end
                        end
                    end
                    if not hasMatchingMobs then
                        Actions.Teleport(parsed.zoneId)
                        lastZoneTeleport = tick()
                        invalidateTarget()
                        Library:Notify({Title="Auto Quest", Description="TP → "..parsed.zone, Time=3})
                    end
                end
            end
        else
            activeQuestData = nil
            pcall(function() QuestTitleLabel:SetText("Quest: (none)") end)
        end
    end
end)

-- ATTACK LOOP
task.spawn(function()
    while task.wait() do
        if Library.Unloaded then break end
        local shouldFarm = Toggles.AutoAttack.Value or Toggles.AutoQuest.Value
        if shouldFarm then
            local hero = GetCurrentHero()
            
            if needNewTarget or not currentTarget or not currentTarget.Parent then
                needNewTarget = false
                local filter = nil
                local ignoreRange = false
                
                if Toggles.PriorityMob.Value then
                    local val = Options.SelectedMob.Value
                    if type(val) == "table" then
                        local hasAny = false
                        for _, v in pairs(val) do if v then hasAny = true; break end end
                        if hasAny then
                            filter = {mobNames = val}
                            ignoreRange = true
                        end
                    elseif type(val) == "string" and val ~= "" then
                        filter = {mobName = val}
                        ignoreRange = true
                    end
                end
                
                if not filter and Toggles.AutoQuest.Value and activeQuestData then
                    filter = {mobName = activeQuestData.mobName, difficulty = activeQuestData.difficulty}
                    ignoreRange = true
                end
                
                local mob, group, center
                if Toggles.SmartGroupFarm.Value then
                    mob, group, center = GetMobGroup(filter, Options.GroupRadius.Value, ignoreRange)
                else
                    mob = GetSingleTarget(filter, ignoreRange)
                end
                
                if not mob and Toggles.FallbackToAny.Value and filter then
                    if Toggles.SmartGroupFarm.Value then
                        mob, group, center = GetMobGroup(nil, Options.GroupRadius.Value, false)
                    else
                        mob = GetSingleTarget(nil, false)
                    end
                end
                
                setCurrentTarget(mob)
                currentGroup = group
                currentGroupSize = group and #group or 0
                comboIndex = 1
            end
            
            if currentTarget and hero and hero ~= "" then
                local hum = currentTarget:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 then
                    Actions.M1(hero, comboIndex)
                    comboIndex = comboIndex + 1
                    if comboIndex > 4 then comboIndex = 1 end
                else
                    invalidateTarget()
                end
            end
            
            task.wait(ATTACK_DELAY)
        else
            currentTarget = nil
            currentGroup = nil
            currentGroupSize = 0
            task.wait(0.1)
        end
    end
end)

task.spawn(function()
    while task.wait(0.5) do
        if Library.Unloaded then break end
        if Toggles.AutoSkill.Value then Actions.CastSkill(); task.wait(Options.SkillDelay.Value) end
    end
end)

task.spawn(function()
    while task.wait(0.5) do
        if Library.Unloaded then break end
        if Toggles.AutoUltimate.Value then Actions.CastUltimate(); task.wait(Options.UltimateDelay.Value) end
    end
end)

Toggles.AutoChampionSpin:OnChanged(function()
    if Toggles.AutoChampionSpin.Value then
        local zoneName = Options.ChampionSpinZone.Value
        local zoneId = ChampionSpinIdMap[zoneName]
        if zoneId then Actions.HiddenChampionSpin(zoneId) end
    else
        Actions.GachaStop("Champions")
        task.wait(0.5)
        ShowSpinPopups()
    end
end)

Options.ChampionSpinZone:OnChanged(function()
    if Toggles.AutoChampionSpin.Value then
        Actions.GachaStop("Champions")
        task.wait(0.3)
        local zoneName = Options.ChampionSpinZone.Value
        local zoneId = ChampionSpinIdMap[zoneName]
        if zoneId then Actions.HiddenChampionSpin(zoneId) end
    end
end)

-- Set up OnChanged for every dynamic gacha toggle
for _, g in ipairs(gachaTogglesList) do
    Toggles[g.toggleName]:OnChanged(function()
        if Toggles[g.toggleName].Value then
            Actions.HiddenSpin(g.gacha.id)
            Library:Notify({Title=g.gacha.display, Description="Started", Time=2})
        else
            Actions.GachaStop(g.gacha.id)
            task.wait(0.5)
            -- Only show popups if nothing else is running
            local anyActive = Toggles.AutoChampionSpin.Value
            for _, g2 in ipairs(gachaTogglesList) do
                if g2.toggleName ~= g.toggleName and Toggles[g2.toggleName].Value then anyActive = true; break end
            end
            if not anyActive then ShowSpinPopups() end
        end
    end)
end

-- Watchdog: restart if game stopped
task.spawn(function()
    while task.wait(15) do
        if Library.Unloaded then break end
        if Toggles.AutoChampionSpin.Value then
            local zoneName = Options.ChampionSpinZone.Value
            local zoneId = ChampionSpinIdMap[zoneName]
            if zoneId then Actions.ChampionSpin(zoneId) end
        end
        for _, g in ipairs(gachaTogglesList) do
            if Toggles[g.toggleName].Value then
                Actions.GachaSpin(g.gacha.id)
            end
        end
    end
end)

task.spawn(function()
    while task.wait(0.5) do
        if Library.Unloaded then break end
        if Toggles.AutoRankup.Value then Actions.RankupPower(); task.wait(Options.RankupDelay.Value) end
    end
end)

LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(0.5)
    local hrp = char:WaitForChild("HumanoidRootPart", 5)
    if hrp then hrp.Anchored = false end
    invalidateTarget()
end)

Library:OnUnload(function()
    pcall(function()
        for _, g in ipairs(GachaData) do
            Actions.GachaStop(g.id)
        end
        Actions.GachaStop("Champions")
        local summon = LocalPlayer.PlayerGui:FindFirstChild("Summon")
        if summon then summon.Enabled = true end
    end)
end)

-- TELEPORT (dynamic from ZoneData)
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

Library:Notify({
    Title="Anime Stars v2.8", 
    Description=string.format("Loaded %d zones, %d gachas", #ZoneData, #GachaData), 
    Time=5
})
