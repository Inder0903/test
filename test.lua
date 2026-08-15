-- ═══════════════════════════════════════════════════════════
-- ANIME STARS SCRIPT v3.0 - MacLib (biggaboy212) UI
-- ═══════════════════════════════════════════════════════════

local MacLib = loadstring(game:HttpGet("https://github.com/biggaboy212/Maclib/releases/latest/download/maclib.txt"))()

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
                table.insert(zones, { id = id, display = display, order = order, cost = data.Cost or 0 })
                nameToId[display] = id
                aliases[display:lower()] = id
                aliases[id:lower()] = id
                for word in display:lower():gmatch("%S+") do
                    if #word >= 4 then aliases[word] = id end
                end
            end
        end
    end
    table.sort(zones, function(a, b) return a.order < b.order end)
    aliases["shinobi world"] = "desertvillage"
    aliases["shinobi"]       = "desertvillage"
    aliases["namekian world"] = "alienplanet"
    aliases["namekian"]      = "alienplanet"
    aliases["skypiea"]       = "skylands"
    aliases["sky"]           = "skylands"
    return zones, nameToId, aliases
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
local GachaData    = LoadGachas()
local BannerData   = LoadBanners()
local EnemiesByZone   = GetEnemiesByZone()
local ChampionsByZone = GetChampionsByZone()

local ZoneDisplayNames = {}
for _, z in ipairs(ZoneData) do
    ZoneDisplayNames[z.id] = z.display
end

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

local ChampionSpinDisplay = {}
local ChampionSpinIdMap   = {}
for _, z in ipairs(ZoneData) do
    if ChampionsByZone[z.id] and #ChampionsByZone[z.id] > 0 then
        table.insert(ChampionSpinDisplay, z.display)
        ChampionSpinIdMap[z.display] = z.id
    end
end

print("[Anime Stars v3.0] Zones:", #ZoneData, "| Gachas:", #GachaData, "| Banners:", #BannerData)

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
-- MOB INFO + MATCHING
-- ═══════════════════════════════════════════════════════════
local function GetMobInfo(mobModel)
    for _, gui in ipairs(LocalPlayer.PlayerGui:GetChildren()) do
        if gui.Name == "Enemy" and gui:IsA("BillboardGui") then
            if gui.Adornee and (gui.Adornee == mobModel or gui.Adornee:IsDescendantOf(mobModel)) then
                local details = gui:FindFirstChild("details")
                if details then
                    local title = details:FindFirstChild("title")
                    local diff  = details:FindFirstChild("difficulty")
                    return {
                        name       = title and title:IsA("TextLabel") and title.Text or nil,
                        difficulty = diff  and diff:IsA("TextLabel")  and diff.Text  or nil,
                    }
                end
            end
        end
    end
    return { name = nil, difficulty = nil }
end

local function NormDiff(str)
    if not str then return nil end
    return str:lower():gsub("%s+","")
end

local function IsChampion(mobName)
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
    if math.abs(#a-#w) <= 1 and #a >= 3 then
        local minLen = math.min(#a,#w)
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
        local hum    = mob:FindFirstChildOfClass("Humanoid")
        if mobHrp and hum and hum.Health > 0 then
            local dist = (hrp.Position - mobHrp.Position).Magnitude
            if dist < maxDist and MatchesFilter(mob, filter) then
                table.insert(mobs, { mob = mob, hrp = mobHrp, dist = dist })
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
function Actions.BannerRoll(bannerName, count, rollType)
    Remote:FireServer({{Path="banner/requestRoll", Params={bannerName, count, rollType or "Normal"}}})
end
function Actions.HiddenSpin(gachaName)
    HideSpinPopups(); Actions.GachaSpin(gachaName); task.wait(0.1); HideSpinPopups()
end
function Actions.HiddenChampionSpin(zoneId)
    HideSpinPopups(); Actions.ChampionSpin(zoneId); task.wait(0.1); HideSpinPopups()
end
function Actions.HiddenBannerRoll(banner, count, rollType)
    HideSpinPopups(); Actions.BannerRoll(banner, count, rollType); task.wait(0.1); HideSpinPopups()
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
-- QUEST HELPERS
-- ═══════════════════════════════════════════════════════════
local function GetActiveQuest()
    local pg = LocalPlayer:FindFirstChild("PlayerGui"); if not pg then return nil end
    local main = pg:FindFirstChild("Main");            if not main then return nil end
    local hud  = main:FindFirstChild("Hud");           if not hud  then return nil end
    local quest = hud:FindFirstChild("Quest");         if not quest then return nil end
    local info     = quest:FindFirstChild("Info")
    local progress = quest:FindFirstChild("Progress")
    local claim    = quest:FindFirstChild("Claim")
    local titleLabel    = info     and info:FindFirstChild("Title")
    local progressLabel = progress and progress:FindFirstChild("Label")
    local claimBtn      = claim    and claim:FindFirstChild("Button")
    local title = titleLabel    and titleLabel:IsA("TextLabel")    and titleLabel.Text    or ""
    local prog  = progressLabel and progressLabel:IsA("TextLabel") and progressLabel.Text or ""
    local canClaim = claim and claim.Visible or false
    if title == "" then return nil end
    return { title=title, progress=prog, canClaim=canClaim, claimButton=claimBtn }
end

local DIFFICULTY_KEYWORDS = {
    ["ultra hard"]="ultrahard", ["ultra"]="ultrahard",
    ["hard"]="hard", ["medium"]="medium", ["easy"]="easy",
    ["boss"]="boss", ["champion"]="boss",
}

local function ParseQuest(questText)
    if not questText or questText == "" then return nil end
    local lower = questText:lower()
    local result = { text=questText, zone=nil, zoneId=nil, difficulty=nil, mobName=nil }
    local diffOrder = {"ultra hard","ultra","hard","medium","easy","boss","champion"}
    for _, keyword in ipairs(diffOrder) do
        if lower:find(keyword,1,true) then result.difficulty = DIFFICULTY_KEYWORDS[keyword]; break end
    end
    local sortedAliases = {}
    for alias, zoneId in pairs(ZoneAliases) do
        table.insert(sortedAliases, {alias=alias, zoneId=zoneId, len=#alias})
    end
    table.sort(sortedAliases, function(a,b) return a.len > b.len end)
    for _, a in ipairs(sortedAliases) do
        if lower:find(a.alias,1,true) then
            result.zoneId = a.zoneId
            result.zone   = ZoneDisplayNames[a.zoneId] or a.zoneId
            break
        end
    end
    for _, mobList in pairs(EnemiesByZone) do
        for _, mobName in ipairs(mobList) do
            if lower:find(mobName:lower(),1,true) then result.mobName = mobName; break end
        end
        if result.mobName then break end
    end
    for _, champList in pairs(ChampionsByZone) do
        for _, champName in ipairs(champList) do
            if lower:find(champName:lower(),1,true) then result.mobName = champName; break end
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
            local pos = btn.AbsolutePosition + btn.AbsoluteSize / 2
            VirtualUser:Button1Down(pos)
            task.wait(0.05)
            VirtualUser:Button1Up(pos)
        end)
        return true
    end
    return false
end

-- ═══════════════════════════════════════════════════════════
-- STATE
-- ═══════════════════════════════════════════════════════════
local State = {
    AutoAttack    = false,
    AutoQuest     = false,
    AutoSkill     = false,
    AutoUltimate  = false,
    AutoRankup    = false,
    AutoChampSpin = false,
    AutoBanner    = false,
    SmartGroup    = true,
    UseAnchor     = false,
    PriorityMob   = false,
    FallbackAny   = true,
    AutoTeleport  = true,
    AutoClaim     = true,

    SkillDelay    = 5,
    UltDelay      = 15,
    RankupDelay   = 2,
    GroupRadius   = 25,
    BannerDelay   = 5,

    SelectedZone  = FarmZoneList[1] or "",
    SelectedMob   = {},
    ChampZone     = ChampionSpinDisplay[1] or "",
    BannerName    = BannerData[1] or "",
    BannerCount   = 10,
    BannerRollType= "Normal",

    GachaEnabled  = {},
}
for _, g in ipairs(GachaData) do State.GachaEnabled[g.id] = false end

local activeQuestData   = nil
local lastZoneTeleport  = 0
local currentTarget     = nil
local currentGroup      = nil
local currentGroupSize  = 0
local comboIndex        = 1
local needNewTarget     = true
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
    Subtitle = "v3.0",
    Size     = UDim2.fromOffset(868, 650),
    DragStyle = 1,
    DisabledWindowControls = {},
    ShowUserInfo  = true,
    Keybind       = Enum.KeyCode.RightShift,
    AcrylicBlur   = true,
})

-- ── GLOBAL SETTINGS ─────────────────────────────────────────
Window:GlobalSetting({
    Name    = "UI Blur",
    Default = Window:GetAcrylicBlurState(),
    Callback = function(bool)
        Window:SetAcrylicBlurState(bool)
    end,
})
Window:GlobalSetting({
    Name    = "Notifications",
    Default = Window:GetNotificationsState(),
    Callback = function(bool)
        Window:SetNotificationsState(bool)
    end,
})
Window:GlobalSetting({
    Name    = "Show User Info",
    Default = Window:GetUserInfoState(),
    Callback = function(bool)
        Window:SetUserInfoState(bool)
    end,
})

-- ── TAB GROUPS + TABS ────────────────────────────────────────
local TabGroup = Window:TabGroup()

local Tabs = {
    Main     = TabGroup:Tab({ Name = "Main",    Image = "rbxassetid://18821914323" }),
    Farm     = TabGroup:Tab({ Name = "Farm",    Image = "rbxassetid://18821914323" }),
    Quest    = TabGroup:Tab({ Name = "Quest",   Image = "rbxassetid://18821914323" }),
    Extras   = TabGroup:Tab({ Name = "Extras",  Image = "rbxassetid://18821914323" }),
    Summon   = TabGroup:Tab({ Name = "Summon",  Image = "rbxassetid://18821914323" }),
    Teleport = TabGroup:Tab({ Name = "Teleport",Image = "rbxassetid://18821914323" }),
    Settings = TabGroup:Tab({ Name = "Settings",Image = "rbxassetid://10734950309" }),
}

-- ═══════════════════════════════════════════════════════════
-- TAB: MAIN
-- ═══════════════════════════════════════════════════════════
local MainLeft  = Tabs.Main:Section({ Side = "Left"  })
local MainRight = Tabs.Main:Section({ Side = "Right" })

MainLeft:Header({ Name = "Info" })

local HeroLabel    = MainLeft:Label({ Text = "Hero: " .. GetCurrentHero() })
local GroupLabel   = MainLeft:Label({ Text = "Group Farm: -" })
local TargetLabel  = MainLeft:Label({ Text = "Target: -" })

MainLeft:Label({
    Text = string.format("Zones: %d  |  Gachas: %d  |  Banners: %d", #ZoneData, #GachaData, #BannerData)
})

MainRight:Header({ Name = "Server" })

MainRight:Button({
    Name = "Rejoin Server",
    Callback = function()
        game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer)
    end,
})

MainRight:Button({
    Name = "Restore Popups",
    Callback = function()
        ShowSpinPopups()
        Window:Notify({ Title = "Popups", Description = "Popups restored", Lifetime = 3 })
    end,
})

-- ═══════════════════════════════════════════════════════════
-- TAB: FARM
-- ═══════════════════════════════════════════════════════════
local FarmLeft  = Tabs.Farm:Section({ Side = "Left"  })
local FarmRight = Tabs.Farm:Section({ Side = "Right" })

FarmLeft:Header({ Name = "Auto Farm" })

FarmLeft:Toggle({
    Name     = "Auto Attack",
    Default  = false,
    Callback = function(v) State.AutoAttack = v end,
}, "AutoAttack")

FarmLeft:Toggle({
    Name     = "Smart Group Farm",
    Default  = true,
    Callback = function(v) State.SmartGroup = v; invalidateTarget() end,
}, "SmartGroup")

FarmLeft:Slider({
    Name     = "Group Radius",
    Default  = 25,
    Minimum  = 10,
    Maximum  = 60,
    Precision = 0,
    Callback = function(v) State.GroupRadius = v end,
}, "GroupRadius")

FarmLeft:Toggle({
    Name     = "Anchor Mode",
    Default  = false,
    Callback = function(v) State.UseAnchor = v end,
}, "UseAnchor")

FarmLeft:Divider()
FarmLeft:Header({ Name = "Abilities" })

FarmLeft:Toggle({
    Name     = "Auto Skill",
    Default  = false,
    Callback = function(v) State.AutoSkill = v end,
}, "AutoSkill")

FarmLeft:Slider({
    Name      = "Skill Delay",
    Default   = 5,
    Minimum   = 1,
    Maximum   = 30,
    Precision = 1,
    Callback  = function(v) State.SkillDelay = v end,
}, "SkillDelay")

FarmLeft:Toggle({
    Name     = "Auto Ultimate",
    Default  = false,
    Callback = function(v) State.AutoUltimate = v end,
}, "AutoUltimate")

FarmLeft:Slider({
    Name      = "Ultimate Delay",
    Default   = 15,
    Minimum   = 5,
    Maximum   = 60,
    Precision = 1,
    Callback  = function(v) State.UltDelay = v end,
}, "UltDelay")

-- TARGET FILTER (right side)
FarmRight:Header({ Name = "Target Filter" })

FarmRight:Toggle({
    Name     = "Prioritize Selected Mobs",
    Default  = false,
    Callback = function(v) State.PriorityMob = v; invalidateTarget() end,
}, "PriorityMob")

FarmRight:Toggle({
    Name     = "Fallback: Any Mob if None Found",
    Default  = true,
    Callback = function(v) State.FallbackAny = v; invalidateTarget() end,
}, "FallbackAny")

-- Zone dropdown
local defaultFarmZone = FarmZoneList[1] or ""
local defaultZoneId   = ZoneNameToId[defaultFarmZone]
local defaultMobList  = AllByZone[defaultZoneId] or {}

local MobDropdown -- forward declare so zone callback can update it

local ZoneDropdown = FarmRight:Dropdown({
    Name     = "Zone",
    Multi    = false,
    Required = true,
    Options  = FarmZoneList,
    Default  = 1,
    Callback = function(v)
        State.SelectedZone = v
        State.SelectedMob  = {}
        invalidateTarget()
        -- refresh mob dropdown options
        local zId   = ZoneNameToId[v]
        local mList = AllByZone[zId] or {}
        if MobDropdown then
            MobDropdown:Refresh(#mList > 0 and mList or {"(none)"}, true)
        end
    end,
}, "SelectedZone")

MobDropdown = FarmRight:Dropdown({
    Name     = "Priority Mob",
    Multi    = false,
    Required = false,
    Options  = #defaultMobList > 0 and defaultMobList or {"(none)"},
    Default  = 1,
    Callback = function(v)
        State.SelectedMob = { [v] = true }
        invalidateTarget()
    end,
}, "SelectedMob")

-- ═══════════════════════════════════════════════════════════
-- TAB: QUEST
-- ═══════════════════════════════════════════════════════════
local QuestLeft  = Tabs.Quest:Section({ Side = "Left"  })
local QuestRight = Tabs.Quest:Section({ Side = "Right" })

QuestLeft:Header({ Name = "Auto Quest" })

QuestLeft:Toggle({
    Name     = "Auto Quest",
    Default  = false,
    Callback = function(v) State.AutoQuest = v end,
}, "AutoQuest")

QuestLeft:Toggle({
    Name     = "Auto Teleport to Zone",
    Default  = true,
    Callback = function(v) State.AutoTeleport = v end,
}, "AutoTeleport")

QuestLeft:Toggle({
    Name     = "Auto Claim",
    Default  = true,
    Callback = function(v) State.AutoClaim = v end,
}, "AutoClaim")

QuestLeft:Button({
    Name = "Manual Claim",
    Callback = function()
        local ok = ClickClaimButton()
        Window:Notify({
            Title       = "Claim",
            Description = ok and "Quest claimed!" or "Nothing to claim",
            Lifetime    = 3,
        })
    end,
})

QuestLeft:Divider()
QuestLeft:Header({ Name = "Quest Info" })

local QTitleLabel    = QuestLeft:Label({ Text = "Quest: (none)"   })
local QProgressLabel = QuestLeft:Label({ Text = "Progress: -"     })
local QZoneLabel     = QuestLeft:Label({ Text = "Zone: -"         })
local QDiffLabel     = QuestLeft:Label({ Text = "Difficulty: -"   })
local QTargetLabel   = QuestLeft:Label({ Text = "Target: -"       })
local QClaimLabel    = QuestLeft:Label({ Text = "Claim Ready: No" })

QuestLeft:Button({
    Name = "Refresh Quest Info",
    Callback = function()
        local q = GetActiveQuest()
        if q then
            local p = ParseQuest(q.title)
            QTitleLabel:SetText("Quest: " .. q.title)
            QProgressLabel:SetText("Progress: " .. q.progress)
            QZoneLabel:SetText("Zone: " .. (p and p.zone or "Unknown"))
            QDiffLabel:SetText("Difficulty: " .. (p and p.difficulty or "Any"))
            QTargetLabel:SetText("Target: " .. (p and p.mobName or "Any"))
            QClaimLabel:SetText("Claim Ready: " .. (q.canClaim and "YES ✓" or "No"))
        else
            QTitleLabel:SetText("Quest: (none)")
        end
    end,
})

-- DEBUG (right side)
QuestRight:Header({ Name = "Debug" })

QuestRight:Button({
    Name = "Scan Mobs (Console)",
    Callback = function()
        local enemies = Workspace:FindFirstChild("Enemies")
        if not enemies then return end
        local char  = LocalPlayer.Character
        local myHrp = char and char:FindFirstChild("HumanoidRootPart")
        print("\n=== MOB SCAN ===")
        local count = 0
        for _, mob in ipairs(enemies:GetChildren()) do
            local info   = GetMobInfo(mob)
            local mobHrp = mob:FindFirstChild("HumanoidRootPart")
            if info.name and mobHrp then
                count = count + 1
                local dist = myHrp and math.floor((myHrp.Position - mobHrp.Position).Magnitude) or "?"
                print(string.format("[%d] %s | %s | %sm", count, info.name, tostring(info.difficulty), tostring(dist)))
                if count >= 30 then break end
            end
        end
        Window:Notify({ Title="Debug", Description="Scanned "..count.." mobs (see console)", Lifetime=3 })
    end,
})

QuestRight:Button({
    Name = "Test Priority Filter",
    Callback = function()
        local wantedList = {}
        for name, enabled in pairs(State.SelectedMob) do
            if enabled then table.insert(wantedList, name) end
        end
        print("\n=== PRIORITY TEST ===")
        print("Wanted:", table.concat(wantedList, ", "))
        local enemies = Workspace:FindFirstChild("Enemies")
        if not enemies then return end
        local char  = LocalPlayer.Character
        local myHrp = char and char:FindFirstChild("HumanoidRootPart")
        local matches = 0
        for _, mob in ipairs(enemies:GetChildren()) do
            local info   = GetMobInfo(mob)
            local mobHrp = mob:FindFirstChild("HumanoidRootPart")
            if info.name and mobHrp then
                for _, w in ipairs(wantedList) do
                    if NameMatches(info.name, w) then
                        matches = matches + 1
                        local dist = myHrp and math.floor((myHrp.Position - mobHrp.Position).Magnitude) or "?"
                        print(string.format("★ %s | %sm", info.name, tostring(dist)))
                        break
                    end
                end
            end
        end
        Window:Notify({ Title="Priority Test", Description=matches.." matches (see console)", Lifetime=3 })
    end,
})

-- ═══════════════════════════════════════════════════════════
-- TAB: EXTRAS
-- ═══════════════════════════════════════════════════════════
local ExtrasLeft  = Tabs.Extras:Section({ Side = "Left"  })
local ExtrasRight = Tabs.Extras:Section({ Side = "Right" })

-- CHAMPIONS
ExtrasLeft:Header({ Name = "Auto Champions" })

ExtrasLeft:Toggle({
    Name     = "Auto Champion Spin",
    Default  = false,
    Callback = function(v)
        State.AutoChampSpin = v
        if v then
            local zoneId = ChampionSpinIdMap[State.ChampZone]
            if zoneId then Actions.HiddenChampionSpin(zoneId) end
        else
            Actions.GachaStop("Champions")
            task.wait(0.5)
            local anyActive = State.AutoBanner
            for _, g in ipairs(GachaData) do
                if State.GachaEnabled[g.id] then anyActive = true; break end
            end
            if not anyActive then ShowSpinPopups() end
        end
    end,
}, "AutoChampSpin")

ExtrasLeft:Dropdown({
    Name     = "Champion Zone",
    Multi    = false,
    Required = true,
    Options  = ChampionSpinDisplay,
    Default  = 1,
    Callback = function(v)
        State.ChampZone = v
        if State.AutoChampSpin then
            Actions.GachaStop("Champions")
            task.wait(0.3)
            local zoneId = ChampionSpinIdMap[v]
            if zoneId then Actions.HiddenChampionSpin(zoneId) end
        end
    end,
}, "ChampZone")

ExtrasLeft:Button({
    Name = "Manual Champion Spin",
    Callback = function()
        local zoneId = ChampionSpinIdMap[State.ChampZone]
        if zoneId then Actions.HiddenChampionSpin(zoneId) end
    end,
})

ExtrasLeft:Button({
    Name = "Force Stop Champions",
    Callback = function()
        Actions.GachaStop("Champions")
        Window:Notify({ Title="Champions", Description="Stopped", Lifetime=2 })
    end,
})

-- RANKUP
ExtrasLeft:Divider()
ExtrasLeft:Header({ Name = "Auto Rankup" })

ExtrasLeft:Toggle({
    Name     = "Auto Rankup Power",
    Default  = false,
    Callback = function(v) State.AutoRankup = v end,
}, "AutoRankup")

ExtrasLeft:Slider({
    Name      = "Rankup Delay",
    Default   = 2,
    Minimum   = 0.5,
    Maximum   = 30,
    Precision = 1,
    Callback  = function(v) State.RankupDelay = v end,
}, "RankupDelay")

-- GACHAS (right side)
ExtrasRight:Header({ Name = "Auto Gacha (" .. #GachaData .. ")" })

for _, gacha in ipairs(GachaData) do
    local zoneText = gacha.requireZone
        and (" [" .. (ZoneDisplayNames[gacha.requireZone] or gacha.requireZone) .. "]")
        or ""

    ExtrasRight:Toggle({
        Name     = "Auto " .. gacha.display .. zoneText,
        Default  = false,
        Callback = function(v)
            State.GachaEnabled[gacha.id] = v
            if v then
                Actions.HiddenSpin(gacha.id)
                Window:Notify({ Title=gacha.display, Description="Auto spin started", Lifetime=2 })
            else
                Actions.GachaStop(gacha.id)
                task.wait(0.5)
                local anyActive = State.AutoChampSpin or State.AutoBanner
                for _, g in ipairs(GachaData) do
                    if State.GachaEnabled[g.id] then anyActive = true; break end
                end
                if not anyActive then ShowSpinPopups() end
            end
        end,
    }, "Gacha_" .. gacha.id)
end

ExtrasRight:Divider()

ExtrasRight:Button({
    Name = "Stop All Gacha",
    Callback = function()
        for _, g in ipairs(GachaData) do Actions.GachaStop(g.id) end
        Actions.GachaStop("Champions")
        Window:Notify({ Title="Gacha", Description="All stopped", Lifetime=2 })
    end,
})

-- ═══════════════════════════════════════════════════════════
-- TAB: SUMMON (BANNER)
-- ═══════════════════════════════════════════════════════════
local SummonLeft  = Tabs.Summon:Section({ Side = "Left"  })
local SummonRight = Tabs.Summon:Section({ Side = "Right" })

SummonLeft:Header({ Name = "Auto Banner Summon" })

SummonLeft:Toggle({
    Name     = "Auto Banner Summon",
    Default  = false,
    Callback = function(v)
        State.AutoBanner = v
        if v then
            Window:Notify({ Title="Banner", Description="Auto summon started", Lifetime=2 })
        else
            task.wait(0.5)
            local anyActive = State.AutoChampSpin
            for _, g in ipairs(GachaData) do
                if State.GachaEnabled[g.id] then anyActive = true; break end
            end
            if not anyActive then ShowSpinPopups() end
            Window:Notify({ Title="Banner", Description="Auto summon stopped", Lifetime=2 })
        end
    end,
}, "AutoBanner")

SummonLeft:Dropdown({
    Name     = "Banner",
    Multi    = false,
    Required = true,
    Options  = #BannerData > 0 and BannerData or {"(none)"},
    Default  = 1,
    Callback = function(v) State.BannerName = v end,
}, "BannerName")

SummonLeft:Dropdown({
    Name     = "Rolls per Summon",
    Multi    = false,
    Required = true,
    Options  = {"1", "10"},
    Default  = 2,
    Callback = function(v) State.BannerCount = tonumber(v) or 10 end,
}, "BannerCount")

SummonLeft:Dropdown({
    Name     = "Ticket Type",
    Multi    = false,
    Required = true,
    Options  = {"Normal", "Premium"},
    Default  = 1,
    Callback = function(v) State.BannerRollType = v end,
}, "BannerRollType")

SummonLeft:Slider({
    Name      = "Summon Delay",
    Default   = 5,
    Minimum   = 1,
    Maximum   = 60,
    Precision = 1,
    Callback  = function(v) State.BannerDelay = v end,
}, "BannerDelay")

SummonLeft:Button({
    Name = "Manual Summon",
    Callback = function()
        Actions.HiddenBannerRoll(State.BannerName, State.BannerCount, State.BannerRollType)
        Window:Notify({
            Title       = "Banner",
            Description = State.BannerName .. " x" .. State.BannerCount,
            Lifetime    = 2,
        })
    end,
})

-- Banner list info (right side)
SummonRight:Header({ Name = "Available Banners" })
for _, b in ipairs(BannerData) do
    SummonRight:Label({ Text = "• " .. b })
end
SummonRight:Divider()
SummonRight:Label({ Text = "Normal  = standard tickets"  })
SummonRight:Label({ Text = "Premium = premium tickets"   })

-- ═══════════════════════════════════════════════════════════
-- TAB: TELEPORT
-- ═══════════════════════════════════════════════════════════
local TeleLeft  = Tabs.Teleport:Section({ Side = "Left"  })
local TeleRight = Tabs.Teleport:Section({ Side = "Right" })

TeleLeft:Header({ Name = "Zones" })

-- Split zones evenly across left/right
local half = math.ceil(#ZoneData / 2)
for i, zone in ipairs(ZoneData) do
    local sec = (i <= half) and TeleLeft or TeleRight
    sec:Button({
        Name = zone.display,
        Callback = function()
            Actions.Teleport(zone.id)
            invalidateTarget()
            Window:Notify({ Title="Teleport", Description="→ "..zone.display, Lifetime=2 })
        end,
    })
end
if #ZoneData > half then
    TeleRight:Header({ Name = "Zones (cont.)" })
end

-- ═══════════════════════════════════════════════════════════
-- TAB: SETTINGS
-- ═══════════════════════════════════════════════════════════
MacLib:SetFolder("AnimeStars")
Tabs.Settings:InsertConfigSection("Left")

-- ═══════════════════════════════════════════════════════════
-- HEARTBEAT: POSITIONING
-- ═══════════════════════════════════════════════════════════
RunService.Heartbeat:Connect(function()
    local char = LocalPlayer.Character
    if not char then return end
    local myHrp = char:FindFirstChild("HumanoidRootPart")
    if not myHrp then return end

    if not (State.AutoAttack or State.AutoQuest) then
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
    if myHum then myHum.PlatformStand = false end

    local targetPos, lookAt

    if State.SmartGroup and currentGroup and #currentGroup > 1 then
        local livePos = {}
        for _, m in ipairs(currentGroup) do
            if m.mob and m.mob.Parent then
                local h   = m.mob:FindFirstChildOfClass("Humanoid")
                local hrp = m.mob:FindFirstChild("HumanoidRootPart")
                if h and h.Health > 0 and hrp then
                    table.insert(livePos, hrp.Position)
                end
            end
        end
        if #livePos > 1 then
            local sum = Vector3.zero
            for _, p in ipairs(livePos) do sum = sum + p end
            local center = sum / #livePos
            targetPos = Vector3.new(center.X, mobHrp.Position.Y, center.Z)
            lookAt    = mobHrp.Position
            currentGroupSize = #livePos
        else
            local dir = (myHrp.Position - mobHrp.Position)
            dir = Vector3.new(dir.X, 0, dir.Z)
            dir = dir.Magnitude < 0.01 and Vector3.new(0,0,1) or dir.Unit
            local mp = mobHrp.Position + dir * HOVER_DISTANCE
            targetPos = Vector3.new(mp.X, mobHrp.Position.Y, mp.Z)
            lookAt    = mobHrp.Position
            currentGroupSize = 1
        end
    else
        local dir = (myHrp.Position - mobHrp.Position)
        dir = Vector3.new(dir.X, 0, dir.Z)
        dir = dir.Magnitude < 0.01 and Vector3.new(0,0,1) or dir.Unit
        local mp = mobHrp.Position + dir * HOVER_DISTANCE
        targetPos = Vector3.new(mp.X, mobHrp.Position.Y, mp.Z)
        lookAt    = mobHrp.Position
    end

    myHrp.CFrame = CFrame.lookAt(targetPos, lookAt)
    myHrp.AssemblyLinearVelocity  = Vector3.zero
    myHrp.AssemblyAngularVelocity = Vector3.zero

    if State.UseAnchor then
        myHrp.Anchored = true
    elseif myHrp.Anchored then
        myHrp.Anchored = false
    end
end)

-- ═══════════════════════════════════════════════════════════
-- ATTACK LOOP
-- ═══════════════════════════════════════════════════════════
task.spawn(function()
    while true do
        local shouldFarm = State.AutoAttack or State.AutoQuest
        if not shouldFarm then
            currentTarget     = nil
            currentGroup      = nil
            currentGroupSize  = 0
            task.wait(0.1)
            continue
        end

        local hero = GetCurrentHero()

        if needNewTarget or not currentTarget or not currentTarget.Parent then
            needNewTarget = false

            local filter, ignoreRange = nil, false

            if State.PriorityMob and next(State.SelectedMob) then
                filter      = { mobNames = State.SelectedMob }
                ignoreRange = true
            end

            if not filter and State.AutoQuest and activeQuestData then
                filter      = { mobName = activeQuestData.mobName, difficulty = activeQuestData.difficulty }
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
-- SKILL / ULTIMATE / RANKUP LOOPS
-- ═══════════════════════════════════════════════════════════
task.spawn(function()
    while true do
        if State.AutoSkill then
            Actions.CastSkill()
            task.wait(State.SkillDelay)
        else
            task.wait(0.5)
        end
    end
end)

task.spawn(function()
    while true do
        if State.AutoUltimate then
            Actions.CastUltimate()
            task.wait(State.UltDelay)
        else
            task.wait(0.5)
        end
    end
end)

task.spawn(function()
    while true do
        if State.AutoRankup then
            Actions.RankupPower()
            task.wait(State.RankupDelay)
        else
            task.wait(0.5)
        end
    end
end)

-- ═══════════════════════════════════════════════════════════
-- BANNER LOOP
-- ═══════════════════════════════════════════════════════════
task.spawn(function()
    while true do
        if State.AutoBanner then
            Actions.HiddenBannerRoll(State.BannerName, State.BannerCount, State.BannerRollType)
            task.wait(State.BannerDelay)
        else
            task.wait(1)
        end
    end
end)

-- ═══════════════════════════════════════════════════════════
-- GACHA / CHAMPION WATCHDOG (re-fires every 15s)
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
                if State.GachaEnabled[g.id] then anyActive = true; break end
            end
        end
        if anyActive then HideSpinPopups() end
    end
end)

-- ═══════════════════════════════════════════════════════════
-- QUEST + UI UPDATE LOOP
-- ═══════════════════════════════════════════════════════════
task.spawn(function()
    while task.wait(1.5) do
        pcall(function()
            HeroLabel:SetText("Hero: " .. GetCurrentHero())
            if State.SmartGroup and currentGroupSize > 1 then
                GroupLabel:SetText("Group Farm: " .. currentGroupSize .. " mobs")
            else
                GroupLabel:SetText("Group Farm: single target")
            end
            if currentTarget and currentTarget.Parent then
                local info = GetMobInfo(currentTarget)
                TargetLabel:SetText("Target: " .. (info.name or "?") .. " (" .. (info.difficulty or "?") .. ")")
            else
                TargetLabel:SetText("Target: (searching...)")
            end
        end)

        local q = GetActiveQuest()
        if q then
            local parsed = ParseQuest(q.title)
            activeQuestData = parsed
            pcall(function()
                QTitleLabel:SetText("Quest: "    .. q.title)
                QProgressLabel:SetText("Progress: " .. q.progress)
                QZoneLabel:SetText("Zone: "      .. (parsed and parsed.zone       or "Unknown"))
                QDiffLabel:SetText("Difficulty: " .. (parsed and parsed.difficulty or "Any"))
                QTargetLabel:SetText("Target: "   .. (parsed and parsed.mobName   or "Any"))
                QClaimLabel:SetText("Claim Ready: " .. (q.canClaim and "YES ✓" or "No"))
            end)

            if State.AutoQuest and State.AutoClaim and q.canClaim then
                task.wait(0.5)
                ClickClaimButton()
                Window:Notify({ Title="Auto Claim", Description="Quest claimed!", Lifetime=2 })
                task.wait(2)
            end

            if State.AutoQuest and State.AutoTeleport and parsed and parsed.zoneId and not State.PriorityMob then
                if tick() - lastZoneTeleport > 10 then
                    local hasMatchingMobs = false
                    local enemies = Workspace:FindFirstChild("Enemies")
                    if enemies then
                        local filter = { mobName=parsed.mobName, difficulty=parsed.difficulty }
                        for _, mob in ipairs(enemies:GetChildren()) do
                            local mobHum = mob:FindFirstChildOfClass("Humanoid")
                            if mobHum and mobHum.Health > 0 and MatchesFilter(mob, filter) then
                                hasMatchingMobs = true; break
                            end
                        end
                    end
                    if not hasMatchingMobs then
                        Actions.Teleport(parsed.zoneId)
                        lastZoneTeleport = tick()
                        invalidateTarget()
                        Window:Notify({ Title="Auto Quest", Description="TP → "..parsed.zone, Lifetime=3 })
                        task.wait(5)
                    end
                end
            end
        else
            activeQuestData = nil
            pcall(function() QTitleLabel:SetText("Quest: (none)") end)
        end
    end
end)

-- ═══════════════════════════════════════════════════════════
-- CHARACTER RESET
-- ═══════════════════════════════════════════════════════════
LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(0.5)
    local hrp = char:WaitForChild("HumanoidRootPart", 5)
    if hrp then hrp.Anchored = false end
    invalidateTarget()
end)

-- ═══════════════════════════════════════════════════════════
-- UNLOAD
-- ═══════════════════════════════════════════════════════════
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
    Title       = "Anime Stars v3.0",
    Description = string.format("Loaded: %d zones, %d gachas, %d banners", #ZoneData, #GachaData, #BannerData),
    Lifetime    = 5,
})
