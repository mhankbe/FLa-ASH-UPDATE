--[[
    AUTO RAID - STANDALONE (NO GUI / AUTO EXECUTE)
    Diekstrak dari 2_CONFIG_2_BREGAS.lua (PANEL AUTO RAID, Automation tab).

    PERILAKU:
    - Begitu di-execute (Auto Execute di executor), Auto Raid langsung ON.
    - Pick Mode  : FIXED MAP 11-15 (hanya masuk raid kalau salah satu dari
                   Map 11/12/13/14/15 tersedia, RANK tidak diperhitungkan -
                   List/Manual/Rune/UpDown sudah dihapus total dari logika
                   ResolveEntry).
    - Auto Boss Kill : ON (default).
    - Boss TP Delay  : 1 detik (default).
    - Tanpa guard cross-feature (Siege/Dungeon/ASC/ST2) - script ini berdiri sendiri.
    - Status pakai print() ke console saja (tanpa GUI/Label).
    - Strict Delta compatibility: no continue, no goto, no non-ASCII,
      semua remote dibungkus pcall, PG_Wait untuk ping-guarded wait.
--]]

-- ============================================================================
-- SERVICES
-- ============================================================================
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local LP                = Players.LocalPlayer
local Remotes           = ReplicatedStorage:WaitForChild("Remotes")

-- ============================================================================
-- CONFIG (default sesuai permintaan - bisa diedit manual di sini)
-- ============================================================================
local CONFIG = {
    pickMode     = "map11to15",  -- fixed, hanya Map 11-15, tidak ada opsi lain
    autoKillBoss = true,    -- Auto Boss Kill default ON
    bossDelay    = 1,       -- delay TP ke boss (detik), default 1
}

-- ============================================================================
-- GLOBAL STATE
-- ============================================================================
HERO_GUIDS = HERO_GUIDS or {}
MY_USER_ID = MY_USER_ID or LP.UserId

local function Log(msg)
    print("[AutoRaid] " .. tostring(msg))
end

-- ============================================================================
-- PG_Wait (adaptive ping-guarded wait, fallback 1x multiplier kalau berdiri sendiri)
-- ============================================================================
if not PG_Wait then
    function PG_Wait(baseTime)
        local mult = (type(PG_Multiplier) == "function") and PG_Multiplier() or 1
        local t = (baseTime or 0.05) * mult
        if t > 5 then t = 5 end
        task.wait(t)
    end
end

-- ============================================================================
-- RE: Remote Events / Functions (hanya yang dibutuhkan Auto Raid)
-- ============================================================================
RE = RE or {}
RE.CollectItem          = RE.CollectItem          or Remotes:WaitForChild("CollectItem", 10)
RE.ExtraReward          = RE.ExtraReward          or Remotes:WaitForChild("ExtraReward", 10)
RE.Click                = RE.Click                or Remotes:FindFirstChild("ClickEnemy")
RE.Atk                  = RE.Atk                  or Remotes:FindFirstChild("PlayerClickAttackSkill")
RE.HeroMove             = RE.HeroMove             or Remotes:FindFirstChild("HeroMoveToEnemyPos")
RE.HeroStand            = RE.HeroStand            or Remotes:FindFirstChild("HeroStandTo")
RE.HeroSkill            = RE.HeroSkill            or Remotes:FindFirstChild("HeroPlaySkillAnim")
RE.HeroUseSkill         = RE.HeroUseSkill         or Remotes:FindFirstChild("HeroUseSkill")
RE.StartTp              = RE.StartTp              or Remotes:FindFirstChild("StartLocalPlayerTeleport")
RE.LocalTp              = RE.LocalTp              or Remotes:FindFirstChild("LocalPlayerTeleport")
RE.CreateRaidTeam       = RE.CreateRaidTeam       or Remotes:FindFirstChild("CreateRaidTeam")
RE.StartChallengeRaidMap= RE.StartChallengeRaidMap or Remotes:FindFirstChild("StartChallengeRaidMap")
RE.UnEquipHero          = RE.UnEquipHero          or Remotes:FindFirstChild("UnequipAllHero")
RE.EquipBestHero        = RE.EquipBestHero        or Remotes:FindFirstChild("AutoEquipBestHero")
RE.EquipHeroWithData    = RE.EquipHeroWithData    or Remotes:FindFirstChild("EquipHeroWithData")

-- ============================================================================
-- DATA TABLES
-- ============================================================================
MAP_NAMES = MAP_NAMES or {
    [1]="Shadow Gate City",[2]="Level Grinding Cavern",[3]="Shadow Castle",
    [4]="Seolhan Forest",[5]="Demon Castle - Tier 1",[6]="Orc Palace",
    [7]="Demon Castle - Tier 2",[8]="Ant Island",[9]="Land of Giant",
    [10]="Plagueheart",[11]="Umbralfrost Domain",[12]="Kamish's Demise",
    [13]="Lava Hell",[14]="Illusory World",[15]="Inferno Altar",
    [16]="Shadow Throne",[17]="Angel Holy Realm",[18]="Golden Throne",
    [19]="Dragon Ball City",[20]="Dragon Ball Wasteland",
}

SPAWN_RANK = SPAWN_RANK or {
    RE1001=1, RE1002=2, RE1003=3, RE1004=4, RE1005=5, RE1006=6,
}

BOSS_NAME_BY_MAP = BOSS_NAME_BY_MAP or {
    [1]="Goblin King", [2]="Giant Arachnid Buryura", [3]="Igris",
    [4]="Leader Of The Polar Bears", [5]="Arch Lich", [6]="Kargalgan",
    [7]="Baran", [8]="Beru", [9]="Giant Monarch", [10]="Monarch Of Plague",
    [11]="Frostborne", [12]="Legia", [13]="Silas", [14]="Yogumunt",
    [15]="Antares", [16]="Ashborn", [17]="Dominion", [18]="Absolute",
    [19]="Broly", [20]="Goku[Super4]",
}

RAID_MAP_INFO = RAID_MAP_INFO or {
    [1]={instance="Map1",rootPart="4025"},[2]={instance="Map2",rootPart="4050"},
    [3]={instance="Map3",rootPart="4025"},[4]={instance="Map4",rootPart="4050"},
    [5]={instance="Map5",rootPart="4050"},[6]={instance="Map6",rootPart="4044"},
    [7]={instance="Map7",rootPart="4050"},[8]={instance="Map8",rootPart="4050"},
    [9]={instance="Map9",rootPart="4050"},[10]={instance="Map10",rootPart="4050"},
    [11]={instance="Map11",rootPart="4050"},[12]={instance="Map12",rootPart="4050"},
    [13]={instance="Map13",rootPart="4050"},[14]={instance="Map14",rootPart="4050"},
    [15]={instance="Map15",rootPart="4050"},[16]={instance="Map16",rootPart="4050"},
    [17]={instance="Map17",rootPart="4050"},[18]={instance="Map18",rootPart="4050"},
    [19]={instance="Map19",rootPart="4050"},[20]={instance="Map20",rootPart="4050"},
}

-- ============================================================================
-- RAID STATE TABLE
-- ============================================================================
RAID = RAID or {
    running=false, inMap=false, thread=nil, sukses=0, collected=0,
    raidId=0, raidMapId=50001, slotIndex=2, fromMapId=nil, serverMapId=nil,
    _raidDone=false, autoKillBoss=CONFIG.autoKillBoss, bossDelay=CONFIG.bossDelay,
    pickMode=CONFIG.pickMode,
}

RAID_LIVE    = RAID_LIVE    or {}
RAID_ID_LIST = RAID_ID_LIST or {}

_raidWakeup = nil

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================
function GetCurrentMapId()
    local ok, wm = pcall(function()
        return workspace:GetAttribute("MapId") or workspace:GetAttribute("mapId") or workspace:GetAttribute("CurrentMapId")
    end)
    return (ok and type(wm) == "number") and wm or nil
end

function GetBossRootPartCFrame(mapNum)
    local info = RAID_MAP_INFO[mapNum]
    if not info then return nil end
    local mf = workspace:FindFirstChild("Maps")
    if not mf then return nil end
    local mapFolder = mf:FindFirstChild(info.instance)
    if not mapFolder then return nil end
    local mapChild = mapFolder:FindFirstChild("Map")
    if not mapChild then return nil end
    local re = mapChild:FindFirstChild("RaidsEnemys")
    if not re then return nil end
    local rp = re:FindFirstChild(info.rootPart)
    if not rp then return nil end
    return rp.CFrame
end

function GetRaidMapNum(mapId)
    local mf = workspace:FindFirstChild("Maps")
    if mf then
        for i = 1, 20 do
            if mf:FindFirstChild("Map" .. i) then return i end
        end
    end
    if type(mapId) ~= "number" then return nil end
    if mapId >= 50101 and mapId <= 50120 then return mapId - 50100 end
    if mapId >= 50001 and mapId <= 50020 then return mapId - 50000 end
    return nil
end

function IsRaidLiveInGame()
    return RAID_ID_LIST and #RAID_ID_LIST > 0
end

-- ============================================================================
-- HERO_GUIDS AUTO-POPULATE (polling PlayerManager - tanpa GUI manual select)
-- ============================================================================
local function IsValidGUID(s)
    return type(s) == "string" and #s > 20 and s:find("-") ~= nil
end

task.spawn(function()
    while LP and LP.Parent do
        task.wait(2)
        pcall(function()
            local pm = require(ReplicatedStorage.Scripts.Client.Manager.PlayerManager)
            if not pm or not pm.localPlayerData then return end
            local heroes = pm.localPlayerData.heros or pm.localPlayerData.heroes
            if heroes then
                for guid, data in pairs(heroes) do
                    if IsValidGUID(guid) and data.isEquip then
                        local dup = false
                        for _, ex in ipairs(HERO_GUIDS) do
                            if ex == guid then dup = true; break end
                        end
                        if not dup then table.insert(HERO_GUIDS, guid) end
                    end
                end
            end
        end)
    end
end)

-- ============================================================================
-- FireAttack / FireAllDamage / FireHeroRemotes
-- ============================================================================
local _heroFireTick = {}

function FireAttack(g, pos)
    if not g then return end
    local atkPos = pos or Vector3.new(0, 0, 0)
    local char = LP and LP.Character
    local pHRP = char and char:FindFirstChild("HumanoidRootPart")
    if pHRP and pos then
        local dir = (pHRP.Position - pos)
        local dir2 = Vector3.new(dir.X, 0, dir.Z)
        if dir2.Magnitude > 0.1 then
            atkPos = pos + dir2.Unit * 5
        else
            atkPos = pos + Vector3.new(1, 0, 0) * 5
        end
    end
    if RE.Atk then pcall(function() RE.Atk:FireServer({attackEnemyGUID = g}) end) end
    if RE.HeroUseSkill and #HERO_GUIDS > 0 then
        local now = tick()
        local last = _heroFireTick[g] or 0
        if now - last >= 0.04 then
            _heroFireTick[g] = now
            for _, hGuid in ipairs(HERO_GUIDS) do
                pcall(function()
                    RE.HeroUseSkill:FireServer({heroGuid = hGuid, attackType = 1, userId = MY_USER_ID, enemyGuid = g, targetPos = atkPos})
                end)
            end
        end
    end
end

function FireAllDamage(g, ep)
    if not g then return end
    if RE.Click then
        task.spawn(function()
            pcall(function() RE.Click:InvokeServer({enemyGuid = g, enemyPos = ep}) end)
        end)
    end
    if RE.Atk then
        pcall(function() RE.Atk:FireServer({attackEnemyGUID = g}) end)
    end
    if RE.HeroUseSkill and #HERO_GUIDS > 0 then
        for _, hGuid in ipairs(HERO_GUIDS) do
            pcall(function() RE.HeroUseSkill:FireServer({heroGuid = hGuid, attackType = 1, userId = MY_USER_ID, enemyGuid = g}) end)
            pcall(function() RE.HeroUseSkill:FireServer({heroGuid = hGuid, attackType = 2, userId = MY_USER_ID, enemyGuid = g}) end)
            pcall(function() RE.HeroUseSkill:FireServer({heroGuid = hGuid, attackType = 3, userId = MY_USER_ID, enemyGuid = g}) end)
        end
    elseif RE.HeroSkill and #HERO_GUIDS > 0 then
        for _, hGuid in ipairs(HERO_GUIDS) do
            pcall(function() RE.HeroSkill:FireServer({heroGuid = hGuid, enemyGuid = g, skillType = 1, masterId = MY_USER_ID}) end)
            pcall(function() RE.HeroSkill:FireServer({heroGuid = hGuid, enemyGuid = g, skillType = 2, masterId = MY_USER_ID}) end)
            pcall(function() RE.HeroSkill:FireServer({heroGuid = hGuid, enemyGuid = g, skillType = 3, masterId = MY_USER_ID}) end)
        end
    end
end

function FireHeroRemotes(enemyGuid, enemyPos)
    local pos = enemyPos or Vector3.new(0, 0, 0)
    if #HERO_GUIDS == 0 then return end
    local posInfos = {}
    for _, hGuid in ipairs(HERO_GUIDS) do
        table.insert(posInfos, {heroGuid = hGuid, targetPos = pos})
    end
    if RE.HeroMove then
        pcall(function() RE.HeroMove:FireServer({attackTarget = enemyGuid, userId = MY_USER_ID, heroTagetPosInfos = posInfos}) end)
        pcall(function() RE.HeroMove:FireServer({attackTarget = enemyGuid, userId = MY_USER_ID, heroTagetPosInfos = posInfos}) end)
    end
end

-- ============================================================================
-- GetRaidEnemies - scan musuh aktif di workspace
-- ============================================================================
function GetRaidEnemies()
    local list = {}
    local seen = {}
    local currentMapId = GetCurrentMapId()

    local playerPos
    pcall(function()
        local char = LP and LP.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        playerPos = hrp and hrp.Position or nil
    end)

    local refPos = playerPos
    local MAX_DIST = 4000
    local useDistFilter = refPos ~= nil

    local function addEnemy(e)
        if not e:IsA("Model") then return end
        if not e:IsDescendantOf(workspace) then return end
        local g = e:GetAttribute("EnemyGuid") or e:GetAttribute("BossGuid") or e:GetAttribute("Guid") or e:GetAttribute("GUID")
        if not g or seen[g] then return end
        local hrp = e:FindFirstChild("HumanoidRootPart") or e.PrimaryPart
                 or e:FindFirstChild("Torso") or e:FindFirstChild("UpperTorso")
                 or e:FindFirstChildWhichIsA("BasePart")
        local hum = e:FindFirstChildOfClass("Humanoid")
        if not (hrp and hum) then return end
        if hum.Health <= 0 then return end
        if hum.MaxHealth <= 0 then return end
        local ep = hrp.Position
        if ep.Magnitude <= 10 then return end
        if ep.Y < -200 or ep.Y > 1500 then return end
        if not hrp:IsDescendantOf(workspace) then return end
        if useDistFilter then
            local dist = (ep - refPos).Magnitude
            if dist > MAX_DIST then return end
        end
        seen[g] = true
        table.insert(list, {guid = g, hrp = hrp, model = e})
    end

    for _, fname in ipairs({"Bosses", "Boss", "RaidBoss", "Enemys", "Enemy", "Enemies", "RaidEnemys", "Monsters", "Monster"}) do
        local folder = workspace:FindFirstChild(fname)
        if folder then
            for _, e in ipairs(folder:GetChildren()) do addEnemy(e) end
        end
    end
    return list
end

-- ============================================================================
-- RaidCollectAll - collect reward 2 ronde
-- ============================================================================
function RaidCollectAll()
    local collected_guids = {}
    local function collectFolder(folder)
        if not folder then return end
        for _, obj in ipairs(folder:GetChildren()) do
            local guid = obj:GetAttribute("GUID") or obj:GetAttribute("Guid") or obj:GetAttribute("guid") or obj:GetAttribute("ItemGuid")
            if guid and not collected_guids[guid] then
                collected_guids[guid] = true
                RAID.collected = RAID.collected + 1
                pcall(function() RE.CollectItem:InvokeServer(guid) end)
                if RE.ExtraReward then
                    pcall(function() RE.ExtraReward:FireServer({isSell = true, guid = guid}) end)
                end
                task.wait(0.05)
            end
        end
    end

    local folders = {"Golds", "Items", "Drops", "Rewards", "Loot", "Chests", "RewardItems", "DropItems"}
    for _, folderName in ipairs(folders) do
        collectFolder(workspace:FindFirstChild(folderName))
    end

    for _, obj in ipairs(workspace:GetChildren()) do
        if obj:IsA("Model") or obj:IsA("Part") or obj:IsA("BasePart") then
            local guid = obj:GetAttribute("GUID") or obj:GetAttribute("Guid") or obj:GetAttribute("guid") or obj:GetAttribute("ItemGuid")
            if guid and not collected_guids[guid] then
                collected_guids[guid] = true
                RAID.collected = RAID.collected + 1
                pcall(function() RE.CollectItem:InvokeServer(guid) end)
                if RE.ExtraReward then
                    pcall(function() RE.ExtraReward:FireServer({isSell = true, guid = guid}) end)
                end
                task.wait(0.05)
            end
        end
    end

    task.wait(1.5)
    for _, folderName in ipairs(folders) do
        collectFolder(workspace:FindFirstChild(folderName))
    end
end

-- ============================================================================
-- RebuildRaidList (tanpa Ascension/Anniversary - murni Normal Raid)
-- ============================================================================
RebuildRaidList = function()
    local sorted = {}
    for _, e in pairs(RAID_LIVE) do
        local mn = e.mapId and (e.mapId - 50000) or 0
        if e.mapId and mn >= 1 and mn <= 20 then
            table.insert(sorted, e)
        end
    end
    table.sort(sorted, function(a, b) return (a.mapId or 0) < (b.mapId or 0) end)

    RAID_ID_LIST = {}
    for _, e in ipairs(sorted) do
        local mn = e.mapId and (e.mapId - 50000) or 0
        local lbl = "Map " .. mn .. " - " .. (MAP_NAMES[mn] or ("Map " .. mn)) .. " (ID:" .. e.raidId .. ")"
        table.insert(RAID_ID_LIST, {label = lbl, id = e.raidId, rank = e.rank, mapId = e.mapId, spawnName = e.spawnName})
    end

    if _raidWakeup then pcall(function() _raidWakeup:Fire() end) end
end

-- ============================================================================
-- DETEKSI RAID: ForceRescanRaidEnter - direct poll RaidsManager module
-- INI YANG MEMBUAT RAID YANG SUDAH AKTIF SEBELUM SCRIPT DI-EXECUTE TETAP
-- KEDETEK, karena event UpdateRaidInfo cuma nembak SEKALI saat raid muncul
-- pertama kali - kalau raid sudah ada duluan, event itu tidak akan terulang.
-- Fungsi ini baca langsung state raid dari server module (bukan event),
-- jadi raid yang sudah berjalan dari awal tetap kebaca dengan raidId VALID.
-- ============================================================================
local _lastRescanTime = 0

function ForceRescanRaidEnter()
    local now = tick()
    if now - _lastRescanTime < 1.5 then return end
    _lastRescanTime = now
    pcall(function()
        local RM = require(ReplicatedStorage.Scripts.Client.Manager.RaidsManager)
        if type(RM) ~= "table" then return end
        local newFound = false
        local currentActiveIds = {}
        for _, val in pairs(RM) do
            if type(val) == "table" then
                for k, info in pairs(val) do
                    repeat
                        if type(info) ~= "table" or not info.raidId or not info.mapId then break end
                        local raidId = info.raidId
                        local mapId = info.mapId
                        local spawnName = info.spawnName or "RE1001"
                        if raidId == 937101 then break end       -- skip Anniversary
                        if raidId >= 935001 then break end        -- skip Ascension Tower
                        if mapId >= 50101 and mapId <= 50120 then mapId = mapId - 100 end
                        if mapId < 50001 or mapId > 50020 then break end

                        currentActiveIds[raidId] = true
                        local mapNum = mapId - 50000
                        local tempKey = -(mapId)
                        if RAID_LIVE[tempKey] then RAID_LIVE[tempKey] = nil end

                        if not RAID_LIVE[raidId] then
                            RAID_LIVE[raidId] = {
                                raidId = raidId, mapId = mapId, spawnName = spawnName,
                                rank = SPAWN_RANK[spawnName] or 0, endTime = info.endTime,
                                label = "Map " .. mapNum .. " - " .. (MAP_NAMES[mapNum] or ("Map " .. mapNum)) .. " (ID:" .. raidId .. ")",
                            }
                            newFound = true
                        end
                    until true
                end
            end
        end
        -- Bersihkan entry yang sudah tidak aktif lagi di server
        for rid, ent in pairs(RAID_LIVE) do
            if rid > 0 and not currentActiveIds[rid] then
                RAID_LIVE[rid] = nil
                newFound = true
            end
        end
        if newFound then RebuildRaidList() end
    end)
end

-- Scan langsung sekali saat script load (tangkap raid yang udah aktif duluan)
task.spawn(function()
    task.wait(1)
    ForceRescanRaidEnter()
end)

-- Radar global: scan otomatis tiap 1.5 detik, berdiri sendiri di luar guard apapun
task.spawn(function()
    while task.wait(1.5) do
        ForceRescanRaidEnter()
    end
end)

-- ============================================================================
-- DETEKSI RAID: Workspace Watcher (RE1001/RE1002 ChildAdded) - deteksi instan
-- ============================================================================
local function _parseRaidEnterName(name)
    local n = name:match("^RaidEnter(%d+)$")
    return n and tonumber(n) or nil
end

local function _onRaidChildAdded(child, slotName)
    local mapNum = _parseRaidEnterName(child.Name)
    if not mapNum or mapNum < 1 or mapNum > 20 then return end
    local mapId = 50000 + mapNum
    for _, ent in pairs(RAID_LIVE) do
        if ent.mapId == mapId and not ent._tempEntry then return end
    end
    local tempKey = -(mapId)
    RAID_LIVE[tempKey] = {
        raidId = tempKey, mapId = mapId, spawnName = slotName or "RE1001", rank = 0,
        _tempEntry = true, label = "Map " .. mapNum .. " - " .. (MAP_NAMES[mapNum] or ("Map " .. mapNum)) .. " [?]",
    }
    RebuildRaidList()
end

local function _onRaidChildRemoved(child)
    local mapNum = _parseRaidEnterName(child.Name)
    if not mapNum then return end
    local mapId = 50000 + mapNum
    local changed = false
    for rid, ent in pairs(RAID_LIVE) do
        if ent.mapId == mapId then RAID_LIVE[rid] = nil; changed = true end
    end
    if changed then RebuildRaidList() end
end

local function _watchRaidSlot(reFolder)
    if not reFolder then return end
    for _, child in ipairs(reFolder:GetChildren()) do _onRaidChildAdded(child, reFolder.Name) end
    reFolder.ChildAdded:Connect(function(child) _onRaidChildAdded(child, reFolder.Name) end)
    reFolder.ChildRemoved:Connect(function(child) _onRaidChildRemoved(child) end)
end

task.spawn(function()
    local ok, mapsF = pcall(function() return workspace:WaitForChild("Maps", 15) end)
    if not ok or not mapsF then return end
    local ok2, mapF = pcall(function() return mapsF:WaitForChild("Map", 10) end)
    if not ok2 or not mapF then return end
    local ok3, reF = pcall(function() return mapF:WaitForChild("RaidEnter", 10) end)
    if not ok3 or not reF then return end
    local re1 = reF:WaitForChild("RE1001", 5)
    local re2 = reF:WaitForChild("RE1002", 5)
    _watchRaidSlot(re1)
    _watchRaidSlot(re2)
end)

-- ============================================================================
-- DETEKSI RAID: UpdateRaidInfo + EnterRaidsUpdateInfo (murni Normal Raid)
-- ============================================================================
local _raidConns = {}

local function DisconnectRaidConns()
    for _, c in ipairs(_raidConns) do pcall(function() c:Disconnect() end) end
    _raidConns = {}
end

local function ConnectRaidListeners()
    DisconnectRaidConns()
    local reUpdate = Remotes:FindFirstChild("UpdateRaidInfo")
    local reEnter  = Remotes:FindFirstChild("EnterRaidsUpdateInfo")

    if reUpdate then
        local conn = reUpdate.OnClientEvent:Connect(function(data)
            if type(data) ~= "table" then return end
            local action = data.action
            local raidInfos = data.raidInfos
            if type(raidInfos) ~= "table" then return end

            if action == "RemoveRaidEnters" then
                for k, info in pairs(raidInfos) do
                    local raidId = type(k) == "number" and k or tonumber(k)
                    if raidId then RAID_LIVE[raidId] = nil end
                end
                RebuildRaidList()
            else
                for k, info in pairs(raidInfos) do
                    repeat
                        if type(info) ~= "table" then break end
                        local raidId = info.raidId or (type(k) == "number" and k) or tonumber(k)
                        local mapId = info.mapId
                        if not raidId or not mapId then break end
                        if raidId == 937101 then break end          -- skip Anniversary
                        if raidId >= 935001 then break end           -- skip Ascension Tower
                        if mapId >= 50101 and mapId <= 50120 then mapId = mapId - 100 end
                        if mapId < 50001 or mapId > 50020 then break end

                        local spawnName = info.spawnName or "RE1001"
                        local rank = SPAWN_RANK[spawnName] or 0
                        local mapNum = mapId - 50000
                        local tempKey = -(mapId)
                        local lbl = "Map " .. mapNum .. " - " .. (MAP_NAMES[mapNum] or ("Map " .. mapNum)) .. " (ID:" .. raidId .. ")"
                        local entryData = {raidId = raidId, mapId = mapId, spawnName = spawnName, rank = rank, endTime = info.endTime, label = lbl}

                        if RAID_LIVE[tempKey] then
                            RAID_LIVE[raidId] = entryData
                            RAID_LIVE[tempKey] = nil
                        else
                            RAID_LIVE[raidId] = entryData
                        end
                    until true
                end
                RebuildRaidList()
            end
        end)
        table.insert(_raidConns, conn)
    end

    if reEnter then
        local conn = reEnter.OnClientEvent:Connect(function(data)
            if type(data) ~= "table" then return end
            if data.slotIndex == nil and data.fromMapId == nil and data.mapId == nil then return end
            local evMapId = data.mapId or data.fromMapId or 0
            if evMapId >= 50300 then return end  -- bukan urusan kita (Ascension dsb)
            if data.slotIndex then RAID.slotIndex = data.slotIndex end
            if data.fromMapId then RAID.fromMapId = data.fromMapId end
            if data.mapId then
                local mid = data.mapId
                if mid >= 50101 and mid <= 50120 then RAID.serverMapId = mid end
            end
        end)
        table.insert(_raidConns, conn)
    end
end

task.spawn(function() ConnectRaidListeners() end)

-- Auto-reconnect kalau Remotes refresh (misal setelah rejoin)
local _raidReconnectAlive = true
task.spawn(function()
    local lastRef = Remotes:FindFirstChild("UpdateRaidInfo")
    while _raidReconnectAlive do
        task.wait(3)
        local cur = Remotes:FindFirstChild("UpdateRaidInfo")
        if cur ~= lastRef then
            lastRef = cur
            if cur then ConnectRaidListeners() end
        end
    end
end)

-- ============================================================================
-- ResolveEntry - HANYA MAP 11-15 (tanpa peduli RANK, asal salah satu tersedia)
-- ============================================================================
local ALLOWED_MAPS = {[11] = true, [12] = true, [13] = true, [14] = true, [15] = true}

local function ResolveEntry()
    if #RAID_ID_LIST == 0 then return nil end

    local now = os.time()
    local pruned = false
    for rid, ent in pairs(RAID_LIVE) do
        if ent.endTime and ent.endTime < (now - 10) then
            RAID_LIVE[rid] = nil
            pruned = true
        end
    end
    if pruned then RebuildRaidList() end
    if #RAID_ID_LIST == 0 then return nil end

    local pickList = {}
    for _, r in ipairs(RAID_ID_LIST) do
        local mn = r.mapId - 50000
        if ALLOWED_MAPS[mn] then
            table.insert(pickList, r)
        end
    end
    if #pickList == 0 then return nil end

    table.sort(pickList, function(a, b) return a.mapId < b.mapId end)
    return pickList[1]
end

-- ============================================================================
-- StopRaid
-- ============================================================================
function StopRaid()
    RAID.running = false
    RAID.inMap = false
    if RAID.thread then pcall(function() task.cancel(RAID.thread) end); RAID.thread = nil end
    if _raidWakeup then pcall(function() _raidWakeup:Destroy() end); _raidWakeup = nil end
    RAID.raidId = nil
    RAID.raidMapId = nil
    RAID.serverMapId = nil
    RAID.fromMapId = nil
    RAID.slotIndex = 2
    RAID._raidDone = false
    RAID_LIVE = {}
    RAID_ID_LIST = {}
end

-- ============================================================================
-- StartRaidLoop - LOOP UTAMA AUTO RAID
-- ============================================================================
function StartRaidLoop()
    StopRaid()
    RAID.running = true
    RAID.sukses = 0
    RAID.collected = 0
    RAID.fromMapId = nil
    RAID.autoKillBoss = CONFIG.autoKillBoss
    RAID.bossDelay = CONFIG.bossDelay

    _raidWakeup = Instance.new("BindableEvent")

    Log("Siap. Menunggu raid... (Pick Mode: MAP 11-15, Auto Boss Kill: ON, Delay: " .. CONFIG.bossDelay .. "s)")

    RAID.thread = task.spawn(function()
        pcall(function()
            while RAID.running do
                repeat
                    if not IsRaidLiveInGame() then
                        RAID.raidId = nil
                        RAID.raidMapId = nil
                        RAID_LIVE = {}
                        RAID_ID_LIST = {}
                        RebuildRaidList()
                    end

                    local raidEntry = ResolveEntry()
                    if not raidEntry then
                        -- STANDBY: tunggu wakeup event atau timeout pendek, lalu cek lagi
                        local woken = false
                        local wConn
                        if _raidWakeup then
                            wConn = _raidWakeup.Event:Connect(function() woken = true end)
                        end
                        local we = 0
                        while not woken and we < 1 and RAID.running do
                            task.wait(0.1); we = we + 0.1
                        end
                        if wConn then pcall(function() wConn:Disconnect() end) end
                        break -- next loop iteration
                    end

                    -- ============================================================
                    -- STEP 2: Create Team + Enter Map
                    -- ============================================================
                    RAID.raidId = raidEntry.id
                    RAID.raidMapId = raidEntry.mapId
                    RAID.inMap = true
                    RAID.slotIndex = 2

                    local mn = raidEntry.mapId - 50000
                    Log("Masuk Raid Map " .. mn .. " - " .. (MAP_NAMES[mn] or ("Map " .. mn)) .. " (ID:" .. raidEntry.id .. ")")

                    local liveEntry = RAID_LIVE[RAID.raidId]
                    if not liveEntry then
                        RAID.inMap = false
                        task.wait(1)
                        break
                    end
                    RAID.serverMapId = nil

                    local targetMapId = raidEntry.mapId + 100
                    if not RAID.fromMapId then RAID.fromMapId = RAID.raidMapId end
                    if RE.CreateRaidTeam then pcall(function() RE.CreateRaidTeam:InvokeServer(RAID.raidId) end) end
                    task.wait(0.2)
                    if not RAID.running then break end

                    local cfail = false
                    local cfConn
                    local cfRe = Remotes:FindFirstChild("ChallengeRaidsFail")
                    if cfRe then cfConn = cfRe.OnClientEvent:Connect(function() cfail = true end) end

                    if RE.StartChallengeRaidMap then
                        pcall(function() RE.StartChallengeRaidMap:FireServer({mapId = targetMapId}) end)
                    end

                    local w2 = 0
                    while RAID.serverMapId == nil and w2 < 5 and RAID.running and not cfail do
                        task.wait(0.05); w2 = w2 + 0.05
                    end
                    if cfConn then pcall(function() cfConn:Disconnect() end) end

                    if cfail then
                        RAID_LIVE[RAID.raidId] = nil
                        RebuildRaidList()
                        RAID.inMap = false
                        task.wait(1)
                        break
                    end

                    -- ============================================================
                    -- STEP 3: Tunggu masuk map (max 2s)
                    -- ============================================================
                    Log("[~] Waiting masuk map...")
                    local tpOk = false
                    local tpWait = 0
                    while not tpOk and tpWait < 2 and RAID.running do
                        task.wait(0.3); tpWait = tpWait + 0.3
                        pcall(function()
                            local wMapId = workspace:GetAttribute("MapId") or workspace:GetAttribute("mapId") or workspace:GetAttribute("CurrentMapId")
                            if wMapId then
                                if RAID.serverMapId and wMapId == RAID.serverMapId then
                                    tpOk = true
                                elseif wMapId >= 50101 and wMapId <= 50120 then
                                    tpOk = true
                                end
                            end
                        end)
                        if not tpOk and #GetRaidEnemies() > 0 then tpOk = true end
                    end

                    if not tpOk and RAID.running then
                        RAID_LIVE[RAID.raidId] = nil
                        RebuildRaidList()
                        RAID.inMap = false
                        RAID.fromMapId = nil
                        task.wait(1)
                        break
                    end

                    -- Equip hero ke map ini
                    if #HERO_GUIDS > 0 then
                        task.spawn(function()
                            task.wait(0.5)
                            if RE.EquipHeroWithData then
                                for _, hGuid in ipairs(HERO_GUIDS) do
                                    pcall(function()
                                        RE.EquipHeroWithData:FireServer({heroGuid = hGuid, userId = MY_USER_ID})
                                    end)
                                    PG_Wait(0.1)
                                end
                            end
                            if RE.HeroStand then
                                local char = LP.Character
                                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                                local spawnPos = (hrp and hrp.Position) or Vector3.new(0, 0, 0)
                                pcall(function()
                                    RE.HeroStand:FireServer({userId = MY_USER_ID, standPos = spawnPos})
                                end)
                                for _, hGuid in ipairs(HERO_GUIDS) do
                                    pcall(function()
                                        RE.HeroStand:FireServer({heroGuid = hGuid, userId = MY_USER_ID, standPos = spawnPos})
                                    end)
                                end
                            end
                        end)
                    end

                    -- ============================================================
                    -- STEP 4: Cari boss, TP, serang
                    -- ============================================================
                    RAID._raidDone = false
                    local raidSuccess = false

                    local connS, connF
                    local raidServerDone = false
                    local reS = Remotes:FindFirstChild("ChallengeRaidsSuccess")
                    local reF = Remotes:FindFirstChild("ChallengeRaidsFail")
                    if reS then
                        connS = reS.OnClientEvent:Connect(function()
                            raidServerDone = true
                            raidSuccess = true
                        end)
                    end
                    if reF then
                        connF = reF.OnClientEvent:Connect(function() RAID._raidDone = true end)
                    end

                    local freezeConn = nil
                    local frozenCFrame = nil
                    local freezeFrame = 0
                    local function step4Cleanup()
                        pcall(function()
                            local char = LP.Character
                            local hrp = char and char:FindFirstChild("HumanoidRootPart")
                            if hrp then hrp.Anchored = false end
                        end)
                        if freezeConn then
                            pcall(function() freezeConn:Disconnect() end)
                            freezeConn = nil
                            frozenCFrame = nil
                        end
                        if connS then pcall(function() connS:Disconnect() end); connS = nil end
                        if connF then pcall(function() connF:Disconnect() end); connF = nil end
                    end

                    Log("[..] Enter Map - loading...")
                    task.wait(0.3)

                    local preMapNum = GetRaidMapNum(raidEntry.mapId)
                    local renderDelay = (preMapNum == 1) and 4 or 2
                    Log("[..] Render delay " .. renderDelay .. "s...")
                    task.wait(renderDelay)

                    if RAID.running and not RAID._raidDone and RAID.autoKillBoss then
                        local mapNumNow = GetRaidMapNum(raidEntry.mapId)
                        local tpTargetCF = mapNumNow and GetBossRootPartCFrame(mapNumNow) or nil
                        local tpTargetPos = tpTargetCF and tpTargetCF.Position or nil

                        if not tpTargetPos and (mapNumNow == 1 or mapNumNow == 3) then
                            local bossName = BOSS_NAME_BY_MAP[mapNumNow]
                            local enemysFolder = workspace:FindFirstChild("Enemys")
                            if enemysFolder and bossName then
                                for _, e in ipairs(enemysFolder:GetChildren()) do
                                    if e:IsA("Model") and e.Name:find(bossName, 1, true) then
                                        local bHrp = e:FindFirstChild("HumanoidRootPart") or e.PrimaryPart
                                        local bHum = e:FindFirstChildOfClass("Humanoid")
                                        if bHrp and bHum and bHum.Health > 0 then
                                            tpTargetPos = bHrp.Position
                                            tpTargetCF = bHrp.CFrame
                                            break
                                        end
                                    end
                                end
                            end
                        end

                        if not tpTargetPos then
                            Log("[!] RootPart boss tidak ditemukan (mapNum=" .. tostring(mapNumNow) .. ") - skip")
                            step4Cleanup()
                            task.wait(2)
                        else
                            local bd = math.max(1, math.min(10, RAID.bossDelay or 1))
                            for ci = bd, 1, -1 do
                                if not RAID.running or RAID._raidDone then break end
                                Log("[K] TP ke Boss Map " .. tostring(mapNumNow) .. " - " .. ci .. "s...")
                                task.wait(1)
                            end

                            if RAID.running and not RAID._raidDone then
                                tpTargetCF = GetBossRootPartCFrame(mapNumNow) or tpTargetCF
                                tpTargetPos = tpTargetCF.Position

                                pcall(function()
                                    local char = LP.Character
                                    local hrp = char and char:FindFirstChild("HumanoidRootPart")
                                    if hrp then hrp.CFrame = tpTargetCF end
                                end)

                                pcall(function()
                                    local heroFolder = workspace:FindFirstChild("Heros")
                                    if heroFolder then
                                        for _, hModel in ipairs(heroFolder:GetChildren()) do
                                            local hHrp = hModel:FindFirstChild("HumanoidRootPart")
                                            if hHrp then hHrp.CFrame = tpTargetCF end
                                        end
                                    end
                                end)

                                task.wait(0.3)
                                if RE.UnEquipHero then pcall(function() RE.UnEquipHero:FireServer() end) end
                                task.wait(0.3)
                                if RE.EquipBestHero then pcall(function() RE.EquipBestHero:FireServer() end) end
                                task.wait(0.3)

                                pcall(function()
                                    local heroFolder = workspace:FindFirstChild("Heros")
                                    if heroFolder then
                                        for _, hModel in ipairs(heroFolder:GetChildren()) do
                                            local hHrp = hModel:FindFirstChild("HumanoidRootPart")
                                            if hHrp then hHrp.CFrame = tpTargetCF end
                                        end
                                    end
                                end)

                                pcall(function()
                                    local char = LP.Character
                                    local hrp = char and char:FindFirstChild("HumanoidRootPart")
                                    if hrp then
                                        frozenCFrame = tpTargetCF
                                        hrp.Anchored = true
                                        hrp.CFrame = frozenCFrame
                                        freezeConn = RunService.Heartbeat:Connect(function()
                                            freezeFrame = freezeFrame + 1
                                            if freezeFrame % 2 ~= 0 then return end
                                            if not RAID.running or RAID._raidDone then
                                                pcall(function() if hrp and hrp.Parent then hrp.Anchored = false end end)
                                                if freezeConn then freezeConn:Disconnect(); freezeConn = nil end
                                                frozenCFrame = nil
                                                return
                                            end
                                            if hrp and hrp.Parent and frozenCFrame then
                                                hrp.CFrame = frozenCFrame
                                            end
                                        end)
                                    end
                                end)

                                local TP_SCAN_RADIUS = 50
                                local function scanNearbyEnemy()
                                    local best, bestDist = nil, nil
                                    for _, e in ipairs(GetRaidEnemies()) do
                                        local hum = e.model:FindFirstChildOfClass("Humanoid")
                                        if hum and hum.Health > 0 and e.hrp and e.hrp.Parent then
                                            local d = (e.hrp.Position - tpTargetPos).Magnitude
                                            if d <= TP_SCAN_RADIUS and (not bestDist or d < bestDist) then
                                                best = e; bestDist = d
                                            end
                                        end
                                    end
                                    return best
                                end

                                local target = scanNearbyEnemy()
                                local scanWait = 0
                                while not target and scanWait < 3 and RAID.running and not RAID._raidDone do
                                    task.wait(0.5); scanWait = scanWait + 0.5
                                    target = scanNearbyEnemy()
                                end

                                if not target then
                                    Log("[!] Tidak ada musuh dalam radius " .. TP_SCAN_RADIUS .. " studs - Go Out...")
                                    step4Cleanup()
                                    task.wait(2)
                                else
                                    local targetGuid = target.guid
                                    Log("[FLa] Attack: " .. target.model.Name)

                                    local function getBossAtkPos(enemyHRP)
                                        local char = LP and LP.Character
                                        local pHRP = char and char:FindFirstChild("HumanoidRootPart")
                                        if not pHRP or not enemyHRP then return enemyHRP and enemyHRP.Position or tpTargetPos end
                                        local ePos = enemyHRP.Position
                                        local dir = pHRP.Position - ePos
                                        local dir2 = Vector3.new(dir.X, 0, dir.Z)
                                        if dir2.Magnitude < 0.1 then return ePos + Vector3.new(10, 0, 0) end
                                        return ePos + dir2.Unit * 10
                                    end

                                    local function attackBoss(guid, enemyHRP)
                                        local atkPos = getBossAtkPos(enemyHRP)
                                        FireAttack(guid, atkPos)
                                        FireAllDamage(guid, atkPos)
                                        FireHeroRemotes(guid, atkPos)
                                        FireAttack(guid, atkPos)
                                        FireAllDamage(guid, atkPos)
                                        FireHeroRemotes(guid, atkPos)
                                    end

                                    local outOfMapCount = 0
                                    local bossTimeout = false
                                    local atkStart = tick()
                                    local BOSS_TIMEOUT = 240

                                    while RAID.running do
                                        if tick() - atkStart >= BOSS_TIMEOUT then
                                            bossTimeout = true
                                            Log("[T] Boss timeout 4min - Dianggap Sukses, keluar...")
                                            break
                                        end
                                        if raidServerDone then break end
                                        local curMap = GetCurrentMapId()
                                        if curMap and (curMap < 50101 or curMap > 50120) then
                                            outOfMapCount = outOfMapCount + 1
                                            if outOfMapCount >= 3 then
                                                Log("[!] Player keluar raid map - stop attack")
                                                break
                                            end
                                        else
                                            outOfMapCount = 0
                                        end
                                        if not target.model or not target.model.Parent then break end
                                        local hum = target.model:FindFirstChildOfClass("Humanoid")
                                        if not hum or hum.Health <= 0 then break end
                                        if not target.hrp or not target.hrp.Parent then
                                            PG_Wait(0.1)
                                        else
                                            local nearNow = scanNearbyEnemy()
                                            if nearNow and nearNow.guid ~= targetGuid then
                                                target = nearNow
                                                targetGuid = target.guid
                                                Log("[FLa] Target baru: " .. target.model.Name)
                                            end
                                            pcall(function() attackBoss(targetGuid, target.hrp) end)
                                            PG_Wait(0.1)
                                        end
                                    end

                                    step4Cleanup()
                                    raidSuccess = true
                                    RAID._raidDone = true
                                    if bossTimeout then
                                        Log("[T] Timeout 4min - Raid Sukses (forced)")
                                    else
                                        Log("[FLa] Target Dead!")
                                    end
                                end
                            end
                        end
                    elseif RAID.running and not RAID._raidDone then
                        local wt = 0
                        while RAID.running and not RAID._raidDone and wt < 300 do
                            task.wait(1); wt = wt + 1
                        end
                    end

                    step4Cleanup()

                    if raidSuccess then
                        RAID.sukses = RAID.sukses + 1
                        Log("[OK] Succes-" .. RAID.sukses .. " Map " .. mn)
                    end
                    if not RAID.running then break end

                    if raidSuccess then
                        Log("[..] Wait 1s (Get reward)...")
                        task.wait(1)
                    end
                    if not RAID.running then break end

                    -- ============================================================
                    -- STEP 5: Collect + Exit raid
                    -- ============================================================
                    task.spawn(function() pcall(RaidCollectAll) end)
                    Log("[FLa] Go Out raid...")

                    RAID_LIVE[RAID.raidId] = nil
                    RebuildRaidList()

                    -- ============================================================
                    -- STEP 6: TP ke Map 1 + cooldown
                    -- ============================================================
                    local toMapId = 50001
                    Log("[FLa] Go Out -> Map 1...")

                    local function fireTpRaid(mapId)
                        local m = mapId - 50000
                        if m >= 1 and m <= 4 then
                            pcall(function() RE.StartTp:FireServer({mapId = mapId}) end)
                        else
                            pcall(function() RE.LocalTp:FireServer({mapId = mapId}) end)
                        end
                    end

                    local function inRaidArea()
                        local ok = false
                        pcall(function()
                            local wm = workspace:GetAttribute("MapId") or workspace:GetAttribute("mapId") or workspace:GetAttribute("CurrentMapId")
                            if wm then ok = (wm >= 50101 and wm <= 50120) end
                        end)
                        return ok
                    end

                    local quitRe = Remotes:FindFirstChild("QuitRaidsMap")
                    if quitRe then
                        pcall(function() quitRe:FireServer({currentSlotIndex = RAID.slotIndex or 2, toMapId = toMapId}) end)
                    end
                    task.wait(0.3)
                    fireTpRaid(toMapId)

                    local exitTry = 0
                    while inRaidArea() and exitTry < 5 and RAID.running do
                        exitTry = exitTry + 1
                        task.wait(1)
                        if quitRe then
                            pcall(function() quitRe:FireServer({currentSlotIndex = RAID.slotIndex or 2, toMapId = toMapId}) end)
                        end
                        task.wait(0.2)
                        fireTpRaid(toMapId)
                    end

                    RAID.fromMapId = nil
                    RAID.inMap = false

                    for cd = 14, 1, -1 do
                        if not RAID.running then break end
                        Log("[..] Cooldown " .. cd .. "s...")
                        task.wait(1)
                    end

                until true
            end
        end)
    end)
end

-- ============================================================================
-- AUTO START (Auto Execute - langsung ON begitu script jalan)
-- ============================================================================
Log("Script loaded. Pick Mode = MAP 11-15, Auto Boss Kill = ON, Boss TP Delay = " .. CONFIG.bossDelay .. "s")
Log("[FLa] Delay start 5 detik...")
task.wait(5)
StartRaidLoop()
