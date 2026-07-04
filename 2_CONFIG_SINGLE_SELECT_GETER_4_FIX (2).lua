--[[
    ============================================================================
    AUTO RAID STANDALONE - DI JUNKIE (FLa Project)
    ============================================================================
    Script tanpa UI. Saat di-execute:
      1. Delay 5 detik
      2. Auto-config:
           - Preferred Maps : 18, 19 (prioritas Map 18 dulu, baru 19)
           - Preferred Rank : E, D, C, B, A, S, SS, G, N
           - AUTO BOSS KILL : ON, Teleport Delay = 1 detik
      3. StartRaidLoop() dijalankan otomatis (auto-detect raid via workspace
         watcher + remote UpdateRaidInfo/EnterRaidsUpdateInfo, sama seperti
         mekanisme deteksi asli di 3.lua)

    Semua fungsi di bawah adalah HASIL EXTRACT LANGSUNG dari 3.lua (bagian
    AUTO RAID normal saja - Auto Ascension/Auto Siege/Single Tower TIDAK
    disertakan, cukup di-stub agar guard-guard internal StartRaidLoop tetap
    aman/nil-safe). Tidak ada logika yang diubah dari versi aslinya, KECUALI
    bagian pemilihan mode/Preferred Maps/Preferred Rank/Boss Delay yang
    di-set otomatis lewat kode di bagian paling bawah file ini.

    CATATAN (dilaporkan ke user, sengaja TIDAK diperbaiki atas permintaan):
      Ada bug asli di 3.lua pada AUTO BOSS KILL attack loop - fungsi
      EnsureHeroAtkThreadFor(guid) dipanggil sebagai global padahal aslinya
      cuma local di panel FARM (scope berbeda). Akibatnya panggilan itu
      error "attempt to call a nil value" tiap kali AUTO BOSS KILL menyerang,
      di-swallow oleh pcall pembungkusnya. Efek nyata: HERO TIDAK IKUT
      MENYERANG BOSS, hanya player yang fire RE.Atk/RE.Click ke boss.
      Script ini SENGAJA mereplikasi bug tsb agar behavior identik 3.lua.
    ============================================================================
--]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local LP                = Players.LocalPlayer
local PG                = LP:WaitForChild("PlayerGui")
local Remotes           = ReplicatedStorage:WaitForChild("Remotes")


--  GLOBALS FARM (dibutuhkan StartRA / TA) 
HERO_GUIDS       = HERO_GUIDS or {}
HERO_DATA        = HERO_DATA  or {}
_walkSpeedState  = _walkSpeedState or 16
MY_USER_ID       = MY_USER_ID or LP.UserId

function IsValidUUID(str)
    if type(str) ~= "string" then return false end
    return str:match("^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$") ~= nil
end

--  PG_Wait (Adaptive PingGuard wait) 
-- Source asli baris ~1588-1594
-- Fallback ke 1x kalau PG_Multiplier() belum ada (kerangka standalone).
-- Saat digabung ke script utama, PG_Multiplier() dari script utama yang dipakai.
if not PG_Wait then
    function PG_Wait(baseTime)
        local mult = (type(PG_Multiplier) == "function") and PG_Multiplier() or 1
        local t = (baseTime or 0.05) * mult
        if t > 5 then t = 5 end
        task.wait(t)
    end
end

--  RE: Remote Events / Functions (subset yang dibutuhkan AUTO RAID) 
RE = RE or {}
RE.CollectItem      = RE.CollectItem      or Remotes:WaitForChild("CollectItem", 10)
RE.ExtraReward      = RE.ExtraReward      or Remotes:WaitForChild("ExtraReward", 10)
RE.Click            = RE.Click            or Remotes:FindFirstChild("ClickEnemy")
RE.Atk              = RE.Atk              or Remotes:FindFirstChild("PlayerClickAttackSkill")
RE.HeroUseSkill     = RE.HeroUseSkill     or Remotes:FindFirstChild("HeroUseSkill")
RE.HeroSkill        = RE.HeroSkill        or Remotes:FindFirstChild("HeroPlaySkillAnim")
RE.StartTp          = RE.StartTp          or Remotes:FindFirstChild("StartLocalPlayerTeleport")
RE.LocalTp          = RE.LocalTp          or Remotes:FindFirstChild("LocalPlayerTeleport")
RE.CreateRaidTeam        = RE.CreateRaidTeam        or Remotes:FindFirstChild("CreateRaidTeam")
RE.StartChallengeRaidMap = RE.StartChallengeRaidMap or Remotes:FindFirstChild("StartChallengeRaidMap")
RE.LocalTpSuccess        = RE.LocalTpSuccess        or Remotes:FindFirstChild("LocalPlayerTeleportSuccess")
RE.UseRaidItem           = RE.UseRaidItem           or Remotes:FindFirstChild("UseRaidItem")
RE.GetRaidTeamInfos      = RE.GetRaidTeamInfos      or Remotes:FindFirstChild("GetRaidTeamInfos")
RE.UnEquipHero           = RE.UnEquipHero           or Remotes:FindFirstChild("UnequipAllHero")
RE.EquipBestHero         = RE.EquipBestHero         or Remotes:FindFirstChild("AutoEquipBestHero")
RE.EquipHeroWithData     = RE.EquipHeroWithData     or Remotes:FindFirstChild("EquipHeroWithData")
RE.HeroStand             = RE.HeroStand             or Remotes:FindFirstChild("HeroStandTo")

--  MODE priority system (identik 3.lua baris ~3823) 
if not MODE then
    MODE = {
        current  = "idle",
        priority = {siege=5, raid=4, asc=3, st2=2, ma=1, idle=0},
        _prev    = {},
    }
    function MODE:_p(name) return self.priority[name] or 0 end
    function MODE:IsHigherPriority(incoming) return self:_p(incoming) > self:_p(self.current) end
    function MODE:Request(name)
        if self.current == "idle" or self:IsHigherPriority(name) then
            self.current = name; return true
        end
        return false
    end
    function MODE:Release(name) if self.current == name then self.current = "idle" end end
    function MODE:ForceSet(name) self.current = name end
    function MODE:WaitAndRequest(name, timeout)
        local t = 0; local limit = timeout or 30
        while not self:Request(name) and t < limit do task.wait(0.5); t = t + 0.5 end
        return self.current == name
    end
end

--  Interrupt flags 
if _raidInterrupt  == nil then _raidInterrupt  = false end
if _ascInterrupt   == nil then _ascInterrupt   = false end
if _siegeInterrupt == nil then _siegeInterrupt = false end

--  Stub state untuk fitur lain (tidak dipakai script ini, hanya agar guard nil-safe) 
-- Script ini HANYA menjalankan AUTO RAID (normal). ASC/SIEGE/ST2 sengaja
-- dibuat "diam" (running=false) supaya semua pengecekan "if ASC and ASC.running"
-- di StartRaidLoop otomatis lolos tanpa error, TANPA benar-benar menjalankan
-- Auto Ascension / Auto Siege / Single Tower.
ASC   = ASC   or {running=false, inMap=false}
SIEGE = SIEGE or {running=false, inMap=false, teleporting=false}
ST2   = ST2   or {running=false, inMap=false}

--  Atomic map-enter lock 
if _MAP_ENTER_LOCK == nil then _MAP_ENTER_LOCK = nil end
if _MAP_ENTER_LOCK_TIME == nil then _MAP_ENTER_LOCK_TIME = 0 end
-- ============================================================================
-- [FIX] MISSING GLOBALS UNTUK AUTO RAID
-- Fungsi-fungsi ini ada di 1.lua tapi tidak di-port ke 2.lua.
-- Tanpa ini StartRaidLoop crash diam-diam karena C.ACC2/C.ACC3/GetRaidEnemies/dll nil.
-- ============================================================================

-- [FIX 1] C color table (C.ACC2, C.ACC3 dipakai di StartRaidLoop)
if not C or not C.ACC3 then
    C = C or {}
    C.BG    = Color3.fromRGB(9,11,22)
    C.ACC   = Color3.fromRGB(55,105,255)
    C.ACC2  = Color3.fromRGB(90,145,255)
    C.ACC3  = Color3.fromRGB(72,125,255)
    C.TXT   = Color3.fromRGB(195,210,255)
    C.TXT2  = Color3.fromRGB(235,242,255)
    C.TXT3  = Color3.fromRGB(90,110,170)
end

-- [FIX 2] _heroFireTick (dipakai FireAttack global)
_heroFireTick = _heroFireTick or {}

-- [FIX 3] FireAttack global (dipakai _attackBoss di STEP4 StartRaidLoop)
if not FireAttack then
    function FireAttack(g, pos)
        if not g then return end
        local _atkPos = pos or Vector3.new(0,0,0)
        local _char = LP and LP.Character
        local _pHRP = _char and _char:FindFirstChild("HumanoidRootPart")
        if _pHRP and pos then
            local _dir = (_pHRP.Position - pos)
            local _dir2 = Vector3.new(_dir.X, 0, _dir.Z)
            if _dir2.Magnitude > 0.1 then
                _atkPos = pos + _dir2.Unit * 5
            else
                _atkPos = pos + Vector3.new(1,0,0) * 5
            end
        end
        if RE.Atk then pcall(function() RE.Atk:FireServer({attackEnemyGUID=g}) end) end
        if RE.HeroUseSkill and #HERO_GUIDS > 0 then
            local now = tick()
            local last = _heroFireTick[g] or 0
            if now - last >= 0.04 then
                _heroFireTick[g] = now
                for _, hGuid in ipairs(HERO_GUIDS) do
                    pcall(function() RE.HeroUseSkill:FireServer({heroGuid=hGuid,attackType=1,userId=MY_USER_ID,enemyGuid=g,targetPos=_atkPos}) end)
                end
            end
        end
    end
end

-- [FIX 4] GetPlayerPos global (dipakai GetRaidEnemies)
if not GetPlayerPos then
    function GetPlayerPos()
        local char = LP and LP.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        return hrp and hrp.Position or nil
    end
end

-- [FIX 5] GetRaidEnemies global (dipakai STEP3+STEP4 StartRaidLoop)
if not GetRaidEnemies then
    function GetRaidEnemies()
        local list = {}
        local seen = {}
        local currentMapId = GetCurrentMapId and GetCurrentMapId() or nil
        local _inNormalRaid = currentMapId and (currentMapId >= 50101 and currentMapId <= 50120)
        local _inAscTower   = currentMapId and (currentMapId >= 50301 and currentMapId <= 50326)
        if currentMapId then
            local _inSiege   = currentMapId >= 50201 and currentMapId <= 50204
            local _inAnniv   = currentMapId == 50401
            if _inSiege or _inAnniv then return list end
        end
        local playerPos = GetPlayerPos()
        local activeMapId = _inNormalRaid and (RAID and RAID.serverMapId) or
            (not _inNormalRaid and not _inAscTower and RAID and RAID.inMap and RAID.serverMapId) or nil
        local spawnPos = activeMapId and RAID_SPAWN_POS and RAID_SPAWN_POS[activeMapId]
        local refPos = (playerPos and playerPos.Magnitude > 1) and playerPos
                    or (spawnPos and spawnPos.Magnitude > 1) and spawnPos
                    or nil
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
            local _ep = hrp.Position
            if _ep.Magnitude <= 10 then return end
            if _ep.Y < -200 or _ep.Y > 1500 then return end
            if not hrp:IsDescendantOf(workspace) then return end
            if useDistFilter then
                local dist = (_ep - refPos).Magnitude
                if dist > MAX_DIST then return end
            end
            seen[g] = true
            table.insert(list, {guid=g, hrp=hrp, model=e})
        end
        for _, fname in ipairs({"Bosses","Boss","RaidBoss","Enemys","Enemy","Enemies","RaidEnemys","Monsters","Monster"}) do
            local folder = workspace:FindFirstChild(fname)
            if folder then
                for _, e in ipairs(folder:GetChildren()) do addEnemy(e) end
            end
        end
        return list
    end
end

-- [FIX 6] _lastRescanTime + ForceRescanRaidEnter global
_lastRescanTime = _lastRescanTime or 0
if not ForceRescanRaidEnter then
    function ForceRescanRaidEnter()
        local now = tick()
        if now - _lastRescanTime < 1.5 then return end
        _lastRescanTime = now
        pcall(function()
            local RM = require(game:GetService("ReplicatedStorage").Scripts.Client.Manager.RaidsManager)
            if type(RM) ~= "table" then return end
            local newFound = false
            local currentActiveIds = {}
            for _, val in pairs(RM) do
                if type(val) == "table" then
                    for k, info in pairs(val) do
                        repeat
                        if type(info) == "table" and info.raidId and info.mapId then
                            local raidId = info.raidId
                            local mapId  = info.mapId
                            local spawnName = info.spawnName or "RE1001"
                            if raidId == 937101 then break end
                            if mapId >= 50101 and mapId <= 50120 then mapId = mapId - 100 end
                            if mapId < 50001 or mapId > 50020 then break end
                            currentActiveIds[raidId] = true
                            local mapNum = mapId - 50000
                            local grade = (RAID_CONFIG_GRADE and RAID_CONFIG_GRADE[raidId])
                                       or (_runeGradeCache and _runeGradeCache[mapNum]) or "?"
                            local tempKey = -(mapId)
                            if RAID_LIVE[tempKey] then RAID_LIVE[tempKey] = nil end
                            if not RAID_LIVE[raidId] then
                                RAID_LIVE[raidId] = {
                                    raidId=raidId, mapId=mapId, spawnName=spawnName,
                                    rank=SPAWN_RANK[spawnName] or 0, grade=grade,
                                    endTime=info.endTime,
                                    label="Map "..mapNum.." - "..(MAP_NAMES[mapNum] or "Map "..mapNum).." ["..grade.."](ID:"..raidId..")"
                                }
                                newFound = true
                            else
                                if RAID_LIVE[raidId].grade ~= grade then
                                    RAID_LIVE[raidId].grade = grade
                                    RAID_LIVE[raidId].label = "Map "..mapNum.." - "..(MAP_NAMES[mapNum] or "Map "..mapNum).." ["..grade.."](ID:"..raidId..")"
                                    newFound = true
                                end
                            end
                        end
                        until true
                    end
                end
            end
            for rid, ent in pairs(RAID_LIVE) do
                if rid > 0 and not currentActiveIds[rid] then
                    RAID_LIVE[rid] = nil; newFound = true
                end
            end
            if newFound then
                if RebuildRaidList then pcall(RebuildRaidList) end
                if TriggerEntryWakeup then TriggerEntryWakeup() end
            end
        end)
    end
end

-- [FIX v1.lua PORT] Radar global: scan otomatis tiap 1.5 detik
-- Di file 1 (baris 12186-12190) ini BERDIRI SENDIRI di luar guard apapun.
-- Di file 2 sebelumnya ada di dalam "if not ForceRescanRaidEnter" -> tidak jalan jika fungsi sudah ada!
task.spawn(function()
    while task.wait(1.5) do
        if ForceRescanRaidEnter then ForceRescanRaidEnter() end
    end
end)

-- [FIX 7] IsRaidLiveInGame (dipakai banyak di StartRaidLoop)
if not IsRaidLiveInGame then
    function IsRaidLiveInGame()
        return RAID_ID_LIST and #RAID_ID_LIST > 0
    end
end

-- [FIX 8] FireAllDamage global (dipakai _attackBoss STEP4 — versi lokal di MA block tidak accessible)
if not FireAllDamage then
    function FireAllDamage(g, ep)
        if not g then return end
        if RE.Click then
            task.spawn(function()
                pcall(function() RE.Click:InvokeServer({enemyGuid=g, enemyPos=ep}) end)
            end)
        end
        if RE.Atk then
            pcall(function() RE.Atk:FireServer({attackEnemyGUID=g}) end)
        end
        if RE.HeroUseSkill and #HERO_GUIDS > 0 then
            for _, hGuid in ipairs(HERO_GUIDS) do
                pcall(function() RE.HeroUseSkill:FireServer({heroGuid=hGuid,attackType=1,userId=MY_USER_ID,enemyGuid=g}) end)
                pcall(function() RE.HeroUseSkill:FireServer({heroGuid=hGuid,attackType=2,userId=MY_USER_ID,enemyGuid=g}) end)
                pcall(function() RE.HeroUseSkill:FireServer({heroGuid=hGuid,attackType=3,userId=MY_USER_ID,enemyGuid=g}) end)
            end
        elseif RE.HeroSkill and #HERO_GUIDS > 0 then
            for _, hGuid in ipairs(HERO_GUIDS) do
                pcall(function() RE.HeroSkill:FireServer({heroGuid=hGuid,enemyGuid=g,skillType=1,masterId=MY_USER_ID}) end)
                pcall(function() RE.HeroSkill:FireServer({heroGuid=hGuid,enemyGuid=g,skillType=2,masterId=MY_USER_ID}) end)
                pcall(function() RE.HeroSkill:FireServer({heroGuid=hGuid,enemyGuid=g,skillType=3,masterId=MY_USER_ID}) end)
            end
        end
    end
end

-- [FIX 9] FireHeroRemotes global (dipakai _attackBoss STEP4 — versi lokal di MA block tidak accessible)
-- [EDIT] HeroMoveToEnemyPos dihapus — tidak dipakai lagi.
if not FireHeroRemotes then
    function FireHeroRemotes(enemyGuid, enemyPos)
    end
end


-- [FIX 10] BOSS_NAME_BY_MAP - diperlukan AUTO BOSS KILL STEP4
BOSS_NAME_BY_MAP = BOSS_NAME_BY_MAP or {
    [1]  = "Goblin King",
    [2]  = "Giant Arachnid Buryura",
    [3]  = "Igris",
    [4]  = "Leader Of The Polar Bears",
    [5]  = "Arch Lich",
    [6]  = "Kargalgan",
    [7]  = "Baran",
    [8]  = "Beru",
    [9]  = "Giant Monarch",
    [10] = "Monarch Of Plague",
    [11] = "Frostborne",
    [12] = "Legia",
    [13] = "Silas",
    [14] = "Yogumunt",
    [15] = "Antares",
    [16] = "Ashborn",
    [17] = "Dominion",
    [18] = "Absolute",
    [19] = "Broly",
    [20] = "Goku[Super4]",
}

-- [FIX 11] ParseChatLine + TipsPanel/ExperienceChat watcher
-- INI YANG MEMBUAT RAID TERDETEKSI DARI SEMUA MAP TANPA HARUS DEKAT!
-- Port identik dari 1.lua baris 9103-9430

_runeGradeCache = _runeGradeCache or {}
_ASC_CHAT_CACHE = _ASC_CHAT_CACHE or {}
_whSilent       = _whSilent or false

if not ParseChatLine then
    function ParseChatLine(text)
        if type(text) ~= "string" or #text < 3 then return end
        text = text:gsub("<[^>]+>",""):gsub("[\r\n]+"," "):match("^%s*(.-)%s*$") or text

        if text:find("MaFissure",1,true) and text:find("appeared",1,true) then

            local function extractGradeLast(t)
                local grade = nil
                for _, pat in ipairs({"M%+%+","M%+","SS","XM","ULT","GOD","M"}) do
                    if t:find("%["..pat.."]", 1, false) then
                        local last = nil
                        for m in t:gmatch("%["..pat.."]") do last = m end
                        if last then grade = last:match("%[(.+)%]"); break end
                    end
                end
                if grade then return grade:upper() end
                local last = nil
                for bracket in t:gmatch("%[([^%]]+)%]") do
                    local up = bracket:upper()
                    if up:match("^[EDCBAGSN]$") then last = up end
                end
                return last
            end

            -- Ascension Tower
            if text:find("Ascension Tower", 1, true) then
                local towerNum = tonumber(text:match("Ascension Tower (%d+)"))
                local grade    = extractGradeLast(text)
                if towerNum and grade then
                    _runeGradeCache[-towerNum] = grade
                    _ASC_CHAT_CACHE[towerNum] = { grade = grade, time = os.time() }
                    for _rid, _ent in pairs(RAID_LIVE) do
                        if _ent.isAscension and _ent.mapId then
                            local _mn2 = (_ent.mapId >= 50301 and _ent.mapId <= 50326)
                                and (_ent.mapId - 50300) or nil
                            if _mn2 == towerNum and (_ent.grade == "?" or not _ent.grade) then
                                _ent.grade = grade
                                _ent.label = "Ascension Tower ".._mn2.." ["..grade.."]"
                            end
                        end
                    end
                    if RebuildRaidList then pcall(RebuildRaidList) end
                    if _WH and _WH.AddLine then
                        _WH.AddLine("The MaFissure appeared in Ascension Tower "..towerNum.." ["..grade.."]")
                    end
                    if TriggerEntryWakeup then TriggerEntryWakeup() end
                end
                return
            end

            -- Normal Raid: "appeared in 6,Orc Palace [B]"
            local mapStr, rest
            mapStr, rest = text:match("appeared in (%d+),(.+)")
            if not mapStr then mapStr, rest = text:match("appeared in (%d+) (.+)") end
            if mapStr then
                local mapNum = tonumber(mapStr)
                local grade  = extractGradeLast(rest or "") or extractGradeLast(text)
                if mapNum and grade then
                    local prev      = _runeGradeCache[mapNum]
                    local cleanPrev = prev and prev:match("^([^%s%(]+)") or prev
                    local upd = not prev or cleanPrev == "?"
                        or (GRADE_RANK[grade] and GRADE_RANK[cleanPrev] and GRADE_RANK[grade] > GRADE_RANK[cleanPrev])
                    if upd then _runeGradeCache[mapNum] = grade end
                    for _, entry in pairs(RAID_LIVE) do
                        if entry.mapId and (entry.mapId - 50000) == mapNum then
                            entry.isAscension = false
                        end
                    end
                    if _WH and _WH.AddLine then
                        local _mapName = MAP_NAMES and MAP_NAMES[mapNum] or ("Map "..mapNum)
                        _WH.AddLine("The MaFissure appeared in "..mapNum..",".. _mapName.." ["..grade.."]")
                    end
                    if TriggerEntryWakeup then TriggerEntryWakeup() end
                end
            end
        end
    end
end

-- Chat dedup + dispatch
local _chatSeen = {}
local function _processMsg(raw)
    if type(raw) ~= "string" or #raw < 5 then return end
    local txt = raw:gsub("<[^>]+>",""):gsub("[\r\n]+"," "):match("^%s*(.-)%s*$") or raw
    local function hasKW(s)
        return s:find("MaFissure",1,true) or s:find("appeared in",1,true) or s:find("has begun",1,true)
    end
    if not hasKW(txt) then
        local stripped = txt:match("^[^:]+:%s*(.+)$")
        if stripped and hasKW(stripped) then txt = stripped end
    end
    if not hasKW(txt) then return end
    local key = txt:sub(1,200)
    local now = tick()
    if _chatSeen[key] and (now - _chatSeen[key]) < 180 then return end
    _chatSeen[key] = now
    ParseChatLine(txt)
    local count = 0
    for _ in pairs(_chatSeen) do count = count + 1 end
    if count > 50 then
        for k, t in pairs(_chatSeen) do
            if (now - t) > 180 then _chatSeen[k] = nil end
        end
    end
end

-- PRIMER: TipsFloatingPanel detector (poll setiap 0.3s)
task.spawn(function()
    local _lastTexts = {}
    while task.wait(0.3) do
        pcall(function()
            local pg = LP.PlayerGui
            for _, panel in ipairs(pg:GetChildren()) do
                if panel.Name == "TipsFloatingPanel" then
                    for _, desc in ipairs(panel:GetDescendants()) do
                        if desc:IsA("TextLabel") then
                            local txt = (desc.Text or ""):gsub("<[^>]+>",""):gsub("[\r\n]+"," ")
                            if #txt > 5 and _lastTexts[desc] ~= txt then
                                _lastTexts[desc] = txt
                                _processMsg(txt)
                            end
                        end
                    end
                end
            end
        end)
    end
end)

-- BACKUP: TextChatService chat history
task.spawn(function()
    pcall(function()
        local TCS = game:GetService("TextChatService")
        local _w = 0
        repeat task.wait(0.5); _w = _w + 0.5
        until TCS:FindFirstChild("TextChannels") or _w >= 10
        local channels = TCS:FindFirstChild("TextChannels")
        if not channels then return end
        local function watchChannel(ch)
            if not ch:IsA("TextChannel") then return end
            ch.ChildAdded:Connect(function(obj)
                if obj:IsA("TextChatMessage") then
                    task.delay(5, function()
                        pcall(function()
                            local txt = obj.Text or ""
                            if #txt < 5 then txt = (obj.PrefixText or "").." "..(obj.Text or "") end
                            _processMsg(txt)
                        end)
                    end)
                end
            end)
        end
        for _, ch in ipairs(channels:GetChildren()) do watchChannel(ch) end
        channels.ChildAdded:Connect(function(ch) task.spawn(function() task.wait(0.1); watchChannel(ch) end) end)
        -- Scan history awal
        task.wait(5)
        _whSilent = true
        pcall(function()
            for _, ch in ipairs(channels:GetChildren()) do
                if ch:IsA("TextChannel") then
                    for _, obj in ipairs(ch:GetChildren()) do
                        if obj:IsA("TextChatMessage") then
                            local txt = obj.Text or ""
                            if #txt < 5 then txt = (obj.PrefixText or "").." "..(obj.Text or "") end
                            _processMsg(txt)
                        end
                    end
                end
            end
        end)
        _whSilent = false
    end)
end)

-- FALLBACK: ExperienceChat BodyText watcher
task.spawn(function()
    pcall(function()
        local CG = game:GetService("CoreGui")
        local ec = CG:WaitForChild("ExperienceChat", 15)
        if not ec then return end
        local function checkBodyText(lbl)
            pcall(function()
                if not lbl:IsA("TextLabel") or lbl.Name ~= "BodyText" then return end
                local function read()
                    pcall(function()
                        local txt = (lbl.Text or ""):gsub("<[^>]+>",""):gsub("[\r\n]+"," ")
                        _processMsg(txt)
                    end)
                end
                read()
                lbl:GetPropertyChangedSignal("Text"):Connect(read)
            end)
        end
        for _, obj in ipairs(ec:GetDescendants()) do checkBodyText(obj) end
        ec.ChildAdded:Connect(function(obj)
            task.spawn(function()
                task.wait(4)
                checkBodyText(obj)
            end)
        end)
    end)
end)


-- ============================================================================
-- PANEL: AUTOMATION - AUTO RAID (v30)
-- Port dari 1.lua baris 8875-14697 ke WindUI
do -- AUTO RAID: DATA & STATE GLOBAL

-- Remote tambahan untuk RAID (di luar yang sudah ada di RE)
RE = RE or {}
RE.CreateRaidTeam       = RE.CreateRaidTeam       or Remotes:FindFirstChild("CreateRaidTeam")
RE.StartChallengeRaidMap= RE.StartChallengeRaidMap or Remotes:FindFirstChild("StartChallengeRaidMap")
RE.LocalTpSuccess       = RE.LocalTpSuccess        or Remotes:FindFirstChild("LocalPlayerTeleportSuccess")
RE.UseRaidItem          = RE.UseRaidItem           or Remotes:FindFirstChild("UseRaidItem")
RE.GetRaidTeamInfos     = RE.GetRaidTeamInfos      or Remotes:FindFirstChild("GetRaidTeamInfos")
-- [FIX] Hero remotes untuk AUTO BOSS KILL (UnEquip -> EquipBest setelah TP)
RE.UnEquipHero          = RE.UnEquipHero           or Remotes:FindFirstChild("UnequipAllHero")
RE.EquipBestHero        = RE.EquipBestHero         or Remotes:FindFirstChild("AutoEquipBestHero")
RE.EquipHeroWithData    = RE.EquipHeroWithData      or Remotes:FindFirstChild("EquipHeroWithData")
RE.HeroStand            = RE.HeroStand             or Remotes:FindFirstChild("HeroStandTo")

--  SPAWN_RANK 
SPAWN_RANK = SPAWN_RANK or {
    RE1001=1, RE1002=2, RE1003=3, RE1004=4, RE1005=5, RE1006=6,
}

--  RANK_LABEL 
RANK_LABEL = RANK_LABEL or {
    [1]="E",[2]="D",[3]="C",[4]="B",[5]="A",
    [6]="S",[7]="SS",[8]="G",[9]="N",[10]="M",
    [11]="M+",[12]="M++",[15]="XM",[17]="ULT",
}

--  MAP_NAMES 
MAP_NAMES = MAP_NAMES or {
    [1]="Shadow Gate City",[2]="Level Grinding Cavern",[3]="Shadow Castle",
    [4]="Seolhan Forest",[5]="Demon Castle - Tier 1",[6]="Orc Palace",
    [7]="Demon Castle - Tier 2",[8]="Ant Island",[9]="Land of Giant",
    [10]="Plagueheart",[11]="Umbralfrost Domain",[12]="Kamish's Demise",
    [13]="Lava Hell",[14]="Illusory World",[15]="Inferno Altar",
    [16]="Shadow Throne",[17]="Angel Holy Realm",[18]="Golden Throne",
    [19]="Dragon Ball City",[20]="Dragon Ball Wasteland",
}

--  GRADE_LIST / GRADE_RANK 
GRADE_LIST = GRADE_LIST or {"E","D","C","B","A","S","SS","G","N","M","M+","M++","XM","ULT"}
GRADE_RANK = GRADE_RANK or {
    ["E"]=1,["D"]=2,["C"]=3,["B"]=4,["A"]=5,["S"]=6,["SS"]=7,
    ["G"]=8,["N"]=9,["M"]=10,["M+"]=11,["M++"]=12,["XM"]=15,["ULT"]=17,["GOD"]=18,
}

--  RAID_CONFIG_GRADE (formula dari raidId) 
if not RAID_CONFIG_GRADE then
    local _GRADE_IDX  = {"E","D","C","B","A","S","SS","G","N","M","M+","M++","XM","ULT","GOD"}
    local _GRADE_RAID = {"D","B","S","SS","G","N","M+","M++","XM","ULT"}
    RAID_CONFIG_GRADE = setmetatable({},{
        __index = function(_, raidId)
            if type(raidId) ~= "number" then return nil end
            if raidId == 937101 then return nil end
            if raidId >= 935001 then return _GRADE_IDX[raidId%100] or "?" end
            if raidId >= 930001 then return _GRADE_RAID[(raidId-930001)%10+1] or "?" end
            return nil
        end
    })
end

--  RAID_SPAWN_POS 
RAID_SPAWN_POS = RAID_SPAWN_POS or {
    [50101]=Vector3.new(2424.9,8.5,482.9),[50102]=Vector3.new(1683.1,8.6,-24.1),
    [50103]=Vector3.new(1913.1,12,-194.4),[50104]=Vector3.new(515.8,7.6,-98.0),
    [50105]=Vector3.new(-229.3,9.6,-2.3),[50106]=Vector3.new(1998.2,8.0,237.7),
    [50107]=Vector3.new(-42.0,8.4,334.0),[50108]=Vector3.new(-925.8,-396.2,-901.6),
    [50109]=Vector3.new(8.7,13.0,244.2),[50110]=Vector3.new(2003.0,8.1,344.0),
    [50111]=Vector3.new(2068.0,49.4,-155.8),[50112]=Vector3.new(16.5,9.0,269.5),
    [50113]=Vector3.new(2100.7,63.1,423.1),[50114]=Vector3.new(27.8,49.8,303.9),
    [50115]=Vector3.new(-0.9,24.0,185.3),[50116]=Vector3.new(1999.6,17.0,236.5),
    [50117]=Vector3.new(-0.4,18.5,93.5),[50118]=Vector3.new(2000.0,45.4,234.7),
    [50119]=Vector3.new(0,10.0,0),[50120]=Vector3.new(0,10.0,0),
}

--  RAID_MAP_INFO 
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

--  RAID & ASC STATE TABLES 
if not RAID then
    RAID = {
        running=false,inMap=false,thread=nil,sukses=0,collected=0,
        raidId=0,raidMapId=50001,slotIndex=2,fromMapId=nil,serverMapId=nil,
        _raidDone=false,statusLbl=nil,suksesLbl=nil,dot=nil,
        difficulty="easy",preferMaps={},runeGrades={},runeEnabled=false,
        runeMapTarget=0,updownEnabled=false,updownDir=nil,
        updownTargetGrade=nil,diffLbl=nil,snapshotMapId=nil,
        listEntries={},listEnabled=false,_listVisitedMaps={},
        autoKillBoss=false,bossDelay=3,pickMode="default",
        manualMatchMode="none",updateActiveLabel=nil,activeRaidLbl=nil,
    }
end
if not ASC then
    ASC = {
        running=false,inMap=false,thread=nil,sukses=0,pickMode="easy",
        preferMaps={},runeGrades={},runeEnabled=false,runeMapTarget=0,
        preferMapTarget=0,manualMatchMode="none",_rrIdx=0,
        autoKillBoss=false,bossDelay=3,listEnabled=false,listEntries={},
        _listVisitedMaps={},statusLbl=nil,dot=nil,suksesLbl=nil,serverMapId=nil,
    }
end

_raidOn          = _raidOn          or false
_ascOn           = _ascOn           or false
_ascWakeup       = _ascWakeup       or nil
_ascBusy         = _ascBusy         or false
_ascMatchedThisCycle  = _ascMatchedThisCycle  or false
_raidFallbackActive   = _raidFallbackActive   or false
_eventOwner           = _eventOwner           or nil
_ascInterrupt    = _ascInterrupt    or false
_MAP_ENTER_LOCK  = _MAP_ENTER_LOCK  or nil
_MAP_ENTER_LOCK_TIME = _MAP_ENTER_LOCK_TIME or 0
_raidIdRefreshCb = _raidIdRefreshCb or nil
_runeGradeCache  = _runeGradeCache  or {}
_ASC_CHAT_CACHE  = _ASC_CHAT_CACHE  or {}
_pendingTowerNum  = _pendingTowerNum  or nil
_pendingTowerTime = _pendingTowerTime or 0
_raidSessionStart = _raidSessionStart or nil
_defaultRRIdx    = _defaultRRIdx    or 0
_entryWakeupTimer = _entryWakeupTimer or nil
_ENTRY_DEBOUNCE_SEC = _ENTRY_DEBOUNCE_SEC or 3

-- Forward declare fungsi yang diperlukan UI
_setRaidToggle   = nil
_visRaidToggle   = nil
_setAscToggle    = nil
_visAscToggle    = nil
_setRaidPMIdx    = nil
_setAscPMIdx     = nil
_raidBossToggleVis   = nil
_raidBossDelaySet    = nil
_raidUpdatePrefLabel = nil
_raidUpdateRankLabel = nil
_raidRebuildListRows = nil
_setRaidListEnabledVis = nil
_raidUpdownToggleVis = nil
_raidUpdownDirVis    = nil
_setRaidUpdownGrade  = nil
_setRaidRuneMapTarget= nil
_syncRaidRuneState   = nil
_prefLocked = false; _rankLocked = false; _runeLocked = false; _updownLocked = false; _listLocked = false
_prefLockLbl=nil; _rankLockLbl=nil; _runeLockLbl=nil
_prefKeyL=nil; _rankKeyL=nil; _runeKeyL=nil

--  RAID_LIVE & RAID_ID_LIST 
RAID_LIVE    = RAID_LIVE    or {}
RAID_ID_LIST = RAID_ID_LIST or {}

--  ATOMIC MAP LOCK 
function TryClaimMapLock(featureName)
    local now = os.clock()
    if _MAP_ENTER_LOCK == nil or _MAP_ENTER_LOCK == featureName then
        _MAP_ENTER_LOCK = featureName; _MAP_ENTER_LOCK_TIME = now; return true
    end
    if (now - _MAP_ENTER_LOCK_TIME) > 30 then
        _MAP_ENTER_LOCK = featureName; _MAP_ENTER_LOCK_TIME = now; return true
    end
    return false
end

function ReleaseMapLock(featureName)
    if _MAP_ENTER_LOCK == featureName then
        _MAP_ENTER_LOCK = nil; _MAP_ENTER_LOCK_TIME = 0
    end
end

function IsAnyMapActive()
    if RAID and RAID.inMap then return true,"raid" end
    if ASC  and ASC.inMap  then return true,"asc"  end
    if SIEGE and SIEGE.inMap then return true,"siege" end
    if ST2 and ST2.inMap then return true,"st2" end
    if _MAP_ENTER_LOCK ~= nil then return true,_MAP_ENTER_LOCK end
    return false,nil
end

--  HELPER FUNCTIONS 
function GetBossRootPartCFrame(mapNum)
    local info = RAID_MAP_INFO[mapNum]; if not info then return nil end
    local mf = workspace:FindFirstChild("Maps"); if not mf then return nil end
    local mapFolder = mf:FindFirstChild(info.instance); if not mapFolder then return nil end
    local mapChild = mapFolder:FindFirstChild("Map"); if not mapChild then return nil end
    local re = mapChild:FindFirstChild("RaidsEnemys"); if not re then return nil end
    local rp = re:FindFirstChild(info.rootPart); if not rp then return nil end
    return rp.CFrame
end

function GetRaidMapNum(mapId)
    local mf = workspace:FindFirstChild("Maps")
    if mf then
        local ord = {
            {1,"Map1"},{2,"Map2"},{3,"Map3"},{4,"Map4"},{5,"Map5"},
            {6,"Map6"},{7,"Map7"},{8,"Map8"},{9,"Map9"},{10,"Map10"},
            {11,"Map11"},{12,"Map12"},{13,"Map13"},{14,"Map14"},{15,"Map15"},
            {16,"Map16"},{17,"Map17"},{18,"Map18"},{19,"Map19"},{20,"Map20"},
        }
        for _,v in ipairs(ord) do if mf:FindFirstChild(v[2]) then return v[1] end end
    end
    if type(mapId) ~= "number" then return nil end
    if mapId >= 50101 and mapId <= 50120 then return mapId - 50100 end
    if mapId >= 50001 and mapId <= 50020 then return mapId - 50000 end
    return nil
end

function GetBestGrade(mapNum, isAscension)
    local mapId = isAscension and (50300+mapNum) or (50000+mapNum)
    local cacheKey = isAscension and (-mapNum) or mapNum
    if isAscension and _ASC_CHAT_CACHE then
        local e = _ASC_CHAT_CACHE[mapNum]
        if e and e.grade and e.grade ~= "?" then return e.grade end
    end
    if isAscension and _runeGradeCache then
        local cg = _runeGradeCache[-mapNum] or _runeGradeCache[cacheKey]
        if cg and cg ~= "?" then return cg end
    end
    for _, ent in pairs(RAID_LIVE) do
        local mm = (ent.mapId == mapId)
        local am = (isAscension and ent.isAscension) or (not isAscension and not ent.isAscension)
        if mm and am and ent.raidId and ent.raidId > 0 then
            local g = RAID_CONFIG_GRADE and RAID_CONFIG_GRADE[ent.raidId]
            if g and g ~= "?" then return g end
        end
    end
    if not isAscension and _runeGradeCache then
        if _runeGradeCache[cacheKey] and _runeGradeCache[cacheKey] ~= "?" then
            return _runeGradeCache[cacheKey]
        end
    end
    for _, ent in pairs(RAID_LIVE) do
        if ent.mapId == mapId and ent.grade and ent.grade ~= "?" then
            if isAscension and ent.isAscension then return ent.grade end
            if not isAscension and not ent.isAscension then return ent.grade end
        end
    end
    return nil
end

function GetCurrentMapId()
    -- [FIX v1.lua PORT] File 1 pakai pcall + cek 3 attribute + return nil jika gagal
    -- bukan hanya workspace:GetAttribute("MapId") or 0 yang return 0 saat tidak ada
    local ok, wm = pcall(function()
        return workspace:GetAttribute("MapId") or workspace:GetAttribute("mapId") or workspace:GetAttribute("CurrentMapId")
    end)
    return (ok and type(wm) == "number") and wm or nil
end

--  REBUILD RAID LIST 
RebuildRaidList = function()
    local sorted = {}
    for _, e in pairs(RAID_LIVE) do
        local ridAbs = e.raidId and (e.raidId < 0 and math.abs(e.raidId) or e.raidId) or 0
        if ridAbs == 937101 then continue end
        if ridAbs >= 935001 and not e.isAscension then e.isAscension = true end
        local mn = e.mapId and (e.mapId - 50000) or 0
        if e.isAscension or (e.mapId and mn >= 1 and mn <= 20) then
            table.insert(sorted, e)
        end
    end
    table.sort(sorted, function(a,b)
        local aA = a.isAscension and true or false
        local bA = b.isAscension and true or false
        if aA ~= bA then return not aA end
        return (a.mapId or 0) < (b.mapId or 0)
    end)
    RAID_ID_LIST = {}
    for _, e in ipairs(sorted) do
        local mn = e.mapId and (e.mapId - 50000) or 0
        local lbl
        if e.isAscension then
            local bn = e.bossName and (e.bossName:gsub("^%l",string.upper)) or nil
            lbl = "Ascension Tower "..mn..(bn and (" - "..bn) or "").." ["..(e.grade or "?").."]"
        else
            lbl = "Map "..mn.." - "..(MAP_NAMES[mn] or "Map "..mn).." - "..(RANK_LABEL[e.rank] or (e.spawnName or "?")).." (ID:"..e.raidId..")"
        end
        table.insert(RAID_ID_LIST,{
            label=lbl,id=e.raidId,rank=e.rank,mapId=e.mapId,
            spawnName=e.spawnName,isAscension=e.isAscension,bossName=e.bossName,
        })
    end
    if _raidIdRefreshCb then pcall(_raidIdRefreshCb) end
end

--  TRIGGER ENTRY WAKEUP 
TriggerEntryWakeup = function()
    if _entryWakeupTimer then
        pcall(function() task.cancel(_entryWakeupTimer) end)
        _entryWakeupTimer = nil
    end
    _entryWakeupTimer = task.delay(_ENTRY_DEBOUNCE_SEC, function()
        _entryWakeupTimer = nil
        _ascMatchedThisCycle = false; _raidFallbackActive = false
        if RAID and RAID._listVisitedMaps then
            local _lc=0; for _ in pairs(RAID_LIVE) do _lc=_lc+1 end
            local _vc=0; for _ in pairs(RAID._listVisitedMaps) do _vc=_vc+1 end
            local _ae=true
            if _vc > 0 then
                for mapId in pairs(RAID._listVisitedMaps) do
                    for _,r in ipairs(RAID_ID_LIST) do
                        if r.mapId == mapId then _ae=false; break end
                    end
                    if not _ae then break end
                end
            end
            if _vc == 0 or _ae then
                for k in pairs(RAID._listVisitedMaps) do RAID._listVisitedMaps[k]=nil end
            end
        end
        local _hasAsc = false
        if ASC and ASC.running then
            for rid, ent in pairs(RAID_LIVE) do
                local rA = rid < 0 and math.abs(rid) or rid
                if rA == 937101 then continue end
                if ent.isAscension or rA >= 935001 or (ent.mapId and ent.mapId >= 50301 and ent.mapId <= 50326) then
                    _hasAsc = true; break
                end
            end
        end
        if _hasAsc then
            _eventOwner = "asc"; _raidFallbackActive = false
            if _ascWakeup then pcall(function() _ascWakeup:Fire() end) end
        else
            _eventOwner = "raid"; _raidFallbackActive = true
            if _raidWakeup then pcall(function() _raidWakeup:Fire() end) end
        end
    end)
end

--  WORKSPACE WATCHER (RE1001/RE1002 ChildAdded) 
local function _parseRaidEnterName(name)
    local n = name:match("^RaidEnter(%d+)$")
    return n and tonumber(n) or nil
end

local function _onRaidChildAdded(child, slotName)
    local mapNum = _parseRaidEnterName(child.Name)
    if not mapNum or mapNum < 1 or mapNum > 26 then return end
    local mapId = 50000 + mapNum
    if mapId == 50401 then return end
    for _, ent in pairs(RAID_LIVE) do
        if ent.mapId == mapId and not ent._tempEntry then return end
    end
    local tempKey = -(mapId)
    local _prevIsAsc=false; local _prevBn=nil; local _prevGr="?"
    if RAID_LIVE[tempKey] and RAID_LIVE[tempKey].isAscension then
        _prevIsAsc=true; _prevBn=RAID_LIVE[tempKey].bossName; _prevGr=RAID_LIVE[tempKey].grade or "?"
    end
    RAID_LIVE[tempKey] = {
        raidId=tempKey,mapId=mapId,spawnName=slotName or "RE1001",rank=0,grade=_prevGr,
        endTime=nil,_tempEntry=true,isAscension=_prevIsAsc,bossName=_prevBn,
        label=_prevIsAsc
            and ("Ascension Tower "..mapNum..(_prevBn and (" - "..(_prevBn:gsub("^%l",string.upper))) or "").." [".._prevGr.."]")
            or ("Map "..mapNum.." - "..(MAP_NAMES[mapNum] or "Map "..mapNum).." [?]"),
    }
    RebuildRaidList()
    if TriggerEntryWakeup then TriggerEntryWakeup() end
end

local function _onRaidChildRemoved(child)
    local mapNum = _parseRaidEnterName(child.Name); if not mapNum then return end
    local mapId = 50000 + mapNum; local changed = false
    for rid, ent in pairs(RAID_LIVE) do
        if ent.mapId == mapId then RAID_LIVE[rid]=nil; changed=true end
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
    local ok,mapsF = pcall(function() return workspace:WaitForChild("Maps",15) end)
    if not ok or not mapsF then return end
    local ok2,mapF = pcall(function() return mapsF:WaitForChild("Map",10) end)
    if not ok2 or not mapF then return end
    local ok3,reF = pcall(function() return mapF:WaitForChild("RaidEnter",10) end)
    if not ok3 or not reF then return end
    local re1 = reF:WaitForChild("RE1001",5)
    local re2 = reF:WaitForChild("RE1002",5)
    _watchRaidSlot(re1); _watchRaidSlot(re2)
end)

--  CONNECT RAID LISTENERS (UpdateRaidInfo + EnterRaidsUpdateInfo) 
_WH = _WH or {}
_WH.raidConns = _WH.raidConns or {}

DisconnectRaidConns = function()
    for _, c in ipairs(_WH.raidConns) do pcall(function() c:Disconnect() end) end
    _WH.raidConns = {}
end

ConnectRaidListeners = function()
    DisconnectRaidConns()
    local _RE_Update = Remotes:FindFirstChild("UpdateRaidInfo")
    local _RE_Enter  = Remotes:FindFirstChild("EnterRaidsUpdateInfo")
    if _RE_Update then
        local conn = _RE_Update.OnClientEvent:Connect(function(data)
            if type(data) ~= "table" then return end
            local action = data.action; local raidInfos = data.raidInfos
            if type(raidInfos) ~= "table" then return end
            if action == "RemoveRaidEnters" then
                for k, info in pairs(raidInfos) do
                    local raidId = type(k)=="number" and k or tonumber(k)
                    if raidId and raidId ~= 937101 then RAID_LIVE[raidId] = nil end
                end
                RebuildRaidList()
            else
                for k, info in pairs(raidInfos) do
                    repeat
                        if type(info) ~= "table" then break end
                        local raidId = info.raidId or (type(k)=="number" and k) or tonumber(k)
                        local mapId = info.mapId
                        if not raidId or not mapId then break end
                        if raidId == 937101 then break end
                        if mapId >= 50101 and mapId <= 50120 then mapId = mapId - 100 end
                        local _isAscMapId = (mapId >= 50301 and mapId <= 50326)
                        local _isAnniversary = (raidId == 937101)
                        local _isAscById = (raidId >= 935001) and not _isAnniversary
                        if not _isAscMapId and not _isAscById and (mapId < 50001 or mapId > 50020) then break end
                        if _isAscById and not _isAscMapId then
                            if mapId >= 50001 and mapId <= 50026 then mapId = mapId + 300 end
                            if mapId >= 50101 and mapId <= 50126 then mapId = mapId + 200 end
                            if mapId >= 50401 and mapId <= 50426 then mapId = mapId - 100 end
                            if mapId >= 50201 and mapId <= 50226 then mapId = mapId + 100 end
                            if not (mapId >= 50301 and mapId <= 50326) then
                                local _mn = math.max(1,math.min(26,math.abs(mapId-50300)))
                                mapId = 50300 + _mn
                            end
                            _isAscMapId = true
                        end
                        local mapNum = _isAscMapId and (mapId-50300) or (mapId-50000)
                        local spawnName = info.spawnName or "RE1001"
                        local rank = SPAWN_RANK[spawnName] or 0
                        local _grCacheKey = _isAscMapId and (-mapNum) or mapNum
                        local grade = (RAID_CONFIG_GRADE and RAID_CONFIG_GRADE[raidId])
                            or (_runeGradeCache and _runeGradeCache[_grCacheKey])
                            or (_ASC_CHAT_CACHE and _isAscMapId and _ASC_CHAT_CACHE[mapNum] and _ASC_CHAT_CACHE[mapNum].grade)
                            or "?"
                        local tempKey = -(mapId)
                        local _isAsc = false; local _bnAsc = nil
                        if raidId >= 935001 and not _isAnniversary then
                            _isAsc = true
                            if RAID_LIVE[tempKey] and RAID_LIVE[tempKey].bossName then _bnAsc = RAID_LIVE[tempKey].bossName
                            elseif RAID_LIVE[raidId] and RAID_LIVE[raidId].bossName then _bnAsc = RAID_LIVE[raidId].bossName end
                        elseif RAID_LIVE[tempKey] and RAID_LIVE[tempKey].isAscension then
                            _isAsc = true; _bnAsc = RAID_LIVE[tempKey].bossName
                        elseif RAID_LIVE[raidId] and RAID_LIVE[raidId].isAscension then
                            _isAsc = true; _bnAsc = RAID_LIVE[raidId].bossName
                        end
                        local _lbl = _isAsc
                            and ("Ascension Tower "..mapNum..(_bnAsc and (" - "..(_bnAsc:gsub("^%l",string.upper))) or "").." ["..grade.."]")
                            or ("Map "..mapNum.." - "..(MAP_NAMES[mapNum] or "Map "..mapNum).." ["..grade.."](ID:"..raidId..")")
                        local entryData = {raidId=raidId,mapId=mapId,spawnName=spawnName,rank=rank,grade=grade,isAscension=_isAsc,bossName=_bnAsc,endTime=info.endTime,label=_lbl}
                        if RAID_LIVE[tempKey] then
                            if grade == "?" and RAID_LIVE[tempKey].grade and RAID_LIVE[tempKey].grade ~= "?" then
                                entryData.grade = RAID_LIVE[tempKey].grade
                            end
                            RAID_LIVE[raidId] = entryData; RAID_LIVE[tempKey] = nil
                        elseif not RAID_LIVE[raidId] then
                            RAID_LIVE[raidId] = entryData
                        else
                            RAID_LIVE[raidId].grade = grade; RAID_LIVE[raidId].rank = rank; RAID_LIVE[raidId].label = _lbl
                            if _isAsc then RAID_LIVE[raidId].isAscension = true; if _bnAsc then RAID_LIVE[raidId].bossName = _bnAsc end end
                        end
                    until true
                end
                RebuildRaidList()
                if TriggerEntryWakeup then TriggerEntryWakeup() end
            end
        end)
        table.insert(_WH.raidConns, conn)
    end
    if _RE_Enter then
        local conn = _RE_Enter.OnClientEvent:Connect(function(data)
            if type(data) ~= "table" then return end
            if data.slotIndex == nil and data.fromMapId == nil and data.mapId == nil then return end
            local evMapId = data.mapId or data.fromMapId or 0
            if evMapId >= 50300 then
                if evMapId >= 50301 and evMapId <= 50326 and ASC and (ASC.running or ASC.inMap) then
                    ASC.serverMapId = evMapId
                end
                return
            end
            if ASC.inMap then return end
            if data.slotIndex then RAID.slotIndex = data.slotIndex end
            if data.fromMapId then RAID.fromMapId = data.fromMapId end
            if data.mapId then
                local mid = data.mapId
                if mid >= 50101 and mid <= 50120 then RAID.serverMapId = mid end
            end
        end)
        table.insert(_WH.raidConns, conn)
    end
end

task.spawn(function() ConnectRaidListeners() end)

-- [FIX v1.lua PORT] Auto-reconnect kalau Remotes refresh (mis. setelah rejoin)
-- File 1 baris 10423-10434 punya ini, file 2 hilang -> listener mati setelah rejoin
-- [FIXED zombie] pakai flag _raidReconnectAlive agar loop mati kalau nil-kan flag
_raidReconnectAlive = true
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
-- [FIX v1.lua PORT] RaidCollectAll - dipakai di STEP 5 StartRaidLoop tapi tidak pernah didefinisikan di file 2!
-- Port dari file 1 baris 11918-11969 (v73 FIX: scan agresif + retry)
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
                    pcall(function() RE.ExtraReward:FireServer({isSell=true, guid=guid}) end)
                end
                task.wait(0.05)
            end
        end
    end
    -- Round 1: scan semua folder reward standar
    local folders = {"Golds","Items","Drops","Rewards","Loot","Chests","RewardItems","DropItems"}
    for _, folderName in ipairs(folders) do
        collectFolder(workspace:FindFirstChild(folderName))
    end
    -- Scan workspace root untuk item loose (tidak dalam folder)
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj:IsA("Model") or obj:IsA("Part") or obj:IsA("BasePart") then
            local guid = obj:GetAttribute("GUID") or obj:GetAttribute("Guid") or obj:GetAttribute("guid") or obj:GetAttribute("ItemGuid")
            if guid and not collected_guids[guid] then
                collected_guids[guid] = true
                RAID.collected = RAID.collected + 1
                pcall(function() RE.CollectItem:InvokeServer(guid) end)
                if RE.ExtraReward then
                    pcall(function() RE.ExtraReward:FireServer({isSell=true, guid=guid}) end)
                end
                task.wait(0.05)
            end
        end
    end
    -- Round 2: tunggu 1.5 detik lalu scan ulang (item spawn delayed)
    task.wait(1.5)
    for _, folderName in ipairs(folders) do
        collectFolder(workspace:FindFirstChild(folderName))
    end
end

-- [FIX v1.lua PORT] GetRaidEnemies - override/define ulang sebagai global tanpa guard
-- Port dari file 1 baris 11975-12048. Di file 2 sebelumnya hanya ada di "if not GetRaidEnemies" guard
-- yang bisa dilewati jika fungsi sudah ada dari script master (versi berbeda/salah)
-- Dengan mendefinisikan ulang di sini, kita pastikan versi yang BENAR selalu dipakai
function GetRaidEnemies()
    local list = {}
    local seen = {}
    local currentMapId = GetCurrentMapId()
    local _inNormalRaid = currentMapId and (currentMapId >= 50101 and currentMapId <= 50120)
    local _inAscTower   = currentMapId and (currentMapId >= 50301 and currentMapId <= 50326)
    -- [BUG FIX] Jangan scan saat di Siege, Dungeon, atau Anniversary
    if currentMapId then
        local _inSiege   = currentMapId >= 50201 and currentMapId <= 50204
        local _inAnniv   = currentMapId == 50401
        if _inSiege or _inAnniv then return list end
    end
    local playerPos
    pcall(function()
        local char = LP and LP.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        playerPos = hrp and hrp.Position or nil
    end)
    local activeMapId = _inNormalRaid and (RAID and RAID.serverMapId) or
        (not _inNormalRaid and not _inAscTower and RAID and RAID.inMap and RAID.serverMapId) or nil
    local spawnPos = activeMapId and RAID_SPAWN_POS and RAID_SPAWN_POS[activeMapId]
    local refPos = (playerPos and playerPos.Magnitude > 1) and playerPos
                or (spawnPos and spawnPos.Magnitude > 1) and spawnPos
                or nil
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
        local _ep = hrp.Position
        if _ep.Magnitude <= 10 then return end
        if _ep.Y < -200 or _ep.Y > 1500 then return end
        if not hrp:IsDescendantOf(workspace) then return end
        if useDistFilter then
            local dist = (_ep - refPos).Magnitude
            if dist > MAX_DIST then return end
        end
        seen[g] = true
        table.insert(list, {guid=g, hrp=hrp, model=e})
    end
    -- [FIX V51] Scan semua folder enemy standar
    for _, fname in ipairs({"Bosses","Boss","RaidBoss","Enemys","Enemy","Enemies","RaidEnemys","Monsters","Monster"}) do
        local folder = workspace:FindFirstChild(fname)
        if folder then
            for _, e in ipairs(folder:GetChildren()) do addEnemy(e) end
        end
    end
    return list
end

_raidSessionStart = nil

function StopRaid()
    _raidInterrupt = false
    if MODE then MODE:Release("raid") end
    RAID.running = false; RAID.inMap = false
    ReleaseMapLock("raid")
    if RAID.thread then pcall(function() task.cancel(RAID.thread) end); RAID.thread = nil end
    if _raidWakeup then pcall(function() _raidWakeup:Destroy() end); _raidWakeup = nil end
    RAID.raidId=nil; RAID.raidMapId=nil; RAID.serverMapId=nil; RAID.fromMapId=nil
    RAID.slotIndex=2; RAID._raidDone=false; RAID._cooldownActive=false
    RAID_LIVE={}; _defaultRRIdx=0; RAID_ID_LIST={}
    if RAID._listVisitedMaps then for k in pairs(RAID._listVisitedMaps) do RAID._listVisitedMaps[k]=nil end end
    if _runeGradeCache then for k in pairs(_runeGradeCache) do _runeGradeCache[k]=nil end end
    if RebuildRaidList then pcall(RebuildRaidList) end
end

function RaidStatusUpdate(msg, color)
    if RAID.statusLbl then
        local ts = ""
        if _raidSessionStart then
            local dur = os.time() - _raidSessionStart
            ts = string.format("[%02d:%02d:%02d] ", math.floor(dur/3600), math.floor(dur/60)%60, dur%60)
        end
        RAID.statusLbl.Text = ts..msg
        RAID.statusLbl.TextColor3 = color or Color3.fromRGB(255,210,160)
    end
    if RAID.dot then RAID.dot.BackgroundColor3 = color or Color3.fromRGB(100,100,100) end
end

function RaidCounterUpdate()
    if RAID.suksesLbl then RAID.suksesLbl.Text = tostring(RAID.sukses) end
end

function AscStatusUpdate(msg, color)
    if ASC.statusLbl then
        ASC.statusLbl.Text = msg
        ASC.statusLbl.TextColor3 = color or Color3.fromRGB(255,200,100)
    end
    if ASC.dot then ASC.dot.BackgroundColor3 = color or Color3.fromRGB(100,100,100) end
end

end -- end do: AUTO RAID DATA & STATE

-- ============================================================================
-- AUTO RAID: StartRaidLoop (port dari 1.lua baris 12218-13571)
-- ============================================================================
function StartRaidLoop()
 StopRaid()
 RAID.running = true
 RAID.sukses = 0
 RAID.collected = 0
 RAID.fromMapId = nil
 RaidCounterUpdate()
 _raidSessionStart = os.time()
 -- [FIX] Buat _raidWakeup BindableEvent agar chat/UpdateRaidInfo bisa bangunkan waiting loop
 if _raidWakeup then pcall(function() _raidWakeup:Destroy() end) end
 _raidWakeup = Instance.new("BindableEvent")

 -- [FIX] Bersihkan sisa runeMapTarget kalau runeEnabled OFF
 if not RAID.runeEnabled and RAID.runeMapTarget ~= 0 then
 RAID.runeMapTarget = 0
 end

 -- Workspace watcher sudah menjaga RAID_LIVE real-time
 -- Tidak perlu fetch manual - langsung mulai loop
 RaidStatusUpdate("Siap. Menunggu raid...", Color3.fromRGB(180,180,60))

 RAID.thread = task.spawn(function()
 pcall(function()
 while RAID.running do
 repeat

 -- [v252] Cek semua interrupt via MODE dispatcher

 -- [FIX] Cek ST2 (Single/Ascension Tower) - pause Auto Raid selama Tower berjalan
 if ST2 and (ST2.running or ST2.inMap) then
 RAID.inMap = false
 RaidStatusUpdate("[||] Tower aktif - Auto Raid pause...", Color3.fromRGB(255,140,0))
 while ST2 and (ST2.running or ST2.inMap) and RAID.running do
 task.wait(0.5)
 end
 if not RAID.running then break end
 RaidStatusUpdate("> Tower selesai - lanjut raid...", C.ACC3)
 task.wait(0.1)
 end

 -- [v56 FIX] Guard RAID: tunggu fitur lain selesai
 -- ASC: RAID boleh lolos guard HANYA jika ResolveAscEntry() = nil (tidak ada Tower match)
 -- Jika ASC.inMap = true (di Tower) -> tetap tunggu ASC keluar dulu sebelum cek ResolveAscEntry
 do
  -- RAID pause selama _ascBusy=true (ASC sedang inMap atau cooldown)
  -- _ascBusy diset false oleh ASC hanya saat benar-benar tidak ada Tower lagi
  local _rGuard = 0
  while RAID.running and _rGuard < 90 do
   -- Cek ASC busy dulu (prioritas)
   if ASC and ASC.running and _ascBusy then
    RaidStatusUpdate("[||] ASC aktif - RAID standby...", Color3.fromRGB(180,100,255))
    task.wait(0.5); _rGuard = _rGuard + 0.5
    continue
   end
   -- Cek fitur lain (Siege, Dungeon)
   local _busy, _who = IsAnyMapActive()
   local _selfBusy = (_who == "raid")
   if not _busy or _selfBusy then break end
   RaidStatusUpdate("[||] Tunggu "..(_who or "?").." selesai dulu...", Color3.fromRGB(255,140,0))
   task.wait(0.5); _rGuard = _rGuard + 0.5
  end
  if not RAID.running then break end
 end

        -- Prioritas: Rune Map + Pick Rank > Rune Map saja > Pick Rank > Difficulty
 -- Selalu baca RAID.runeEnabled / runeGrades / runeMapTarget live
 -- sehingga kalau user ganti setting di tengah, iterasi berikutnya langsung ikut

-- [RAID LIST ENTRY] ResolveEntryFromList
-- Resolver independen: bypass manual mode, scan entry dari bawah ke atas.
-- Return: raidEntry yang match, atau nil jika tidak ada yg match (caller fallback ke Easy)
local function ResolveEntryFromList()
    if not RAID.listEnabled then return nil end
    if #RAID.listEntries == 0 then return nil end
    if #RAID_ID_LIST == 0 then return nil end

    -- Filter Ascension keluar (sama seperti ResolveEntry)
    local normalList = {}
    for _, r in ipairs(RAID_ID_LIST) do
        local isAsc = r.isAscension == true or (r.id and r.id >= 935001)
        if not isAsc then
            local live = r.id and RAID_LIVE[r.id]
            if not (live and live.isAscension == true) then
                table.insert(normalList, r)
            end
        end
    end
    if #normalList == 0 then return nil end

    -- Helper ambil grade terbaik
    local function _getGrade(r)
        return GetBestGrade(r.mapId - 50000, false)
    end

    -- Kumpulkan semua lobby yang match dari semua entry sekaligus
    local function collectAllMatched(skipVisited)
        local allMatched = {}
        local seen = {}
        for i = 1, #RAID.listEntries do
            local ent = RAID.listEntries[i]
            local hasMaps  = next(ent.maps)  ~= nil
            local hasRanks = next(ent.ranks) ~= nil
            for _, r in ipairs(normalList) do
                if seen[r.mapId] then continue end
                -- Skip map yang sudah dikunjungi di siklus ini (kecuali sedang reset)
                if skipVisited and RAID._listVisitedMaps[r.mapId] then continue end
                local mn = r.mapId - 50000
                local mapsOk = (not hasMaps) or ent.maps[mn]
                if not mapsOk then continue end
                if hasRanks then
                    local grade = _getGrade(r)
                    if grade and ent.ranks[grade] then
                        table.insert(allMatched, r)
                        seen[r.mapId] = true
                    end
                else
                    table.insert(allMatched, r)
                    seen[r.mapId] = true
                end
            end
        end
        return allMatched
    end

    -- Tahap 1: cari match yang belum dikunjungi
    local allMatched = collectAllMatched(true)

    -- Tahap 2: kalau semua sudah dikunjungi -> reset visited dan loop ulang dari awal
    if #allMatched == 0 then
        for k in pairs(RAID._listVisitedMaps) do RAID._listVisitedMaps[k] = nil end
        allMatched = collectAllMatched(true)
    end

    if #allMatched == 0 then return nil end

    -- Pilih mapId terkecil dari semua yang match
    table.sort(allMatched, function(a, b) return a.mapId < b.mapId end)
    return allMatched[1]
end

local function ResolveEntry()
                if #RAID_ID_LIST == 0 then return nil end

                -- [LIST FALLBACK v3] Exclude {1,3,8} berlaku di SEMUA tahap — didefinisikan di GLOBAL_EXCLUDE bawah
                -- [RAID LIST ENTRY] Cek List Entry dulu sebelum logika normal
                -- [LIST FALLBACK v3] Kalau List Entry gagal match:
                --   Stage 2 → jalankan Pick Mode aktif (bukan langsung Easy)
                --   Stage 3 → Easy fallback terakhir, exclude {1,3,8}
                --   Kalau Stage 3 juga nil → return nil (Waiting loop)
                local _listFailed = false
                if RAID.listEnabled and #RAID.listEntries > 0 then
                    local listResult = ResolveEntryFromList()
                    if listResult then
                        return listResult
                    end
                    -- List Entry tidak match -> tandai, lanjut ke Pick Mode aktif (fall-through)
                    _listFailed = true
                end

                -- [v46] Auto Raid selalu filter Normal saja (Ascension ditangani Auto Ascension)
                local function _ascFilter(entry)
                    if not entry then return false end
                    -- Cek flag isAscension dari entry RAID_ID_LIST itu sendiri
                    if entry.isAscension == true then return false end
                    -- Cek raidId range Ascension Tower (confirmed SimpleSPY: 936501+)
                    -- Server pakai raidId >= 935001 untuk semua Ascension Tower event
                    if entry.id and entry.id >= 935001 then return false end
                    -- Cek dari RAID_LIVE via id entry
                    local live = entry.id and RAID_LIVE[entry.id]
                    if live and live.isAscension == true then return false end
                    -- Safety net: cek RAID_LIVE[-(mapId)] - entry chat Ascension yang belum di-resolve
                    if entry.mapId then
                        local chatKey = -(entry.mapId)
                        local chatEnt = RAID_LIVE[chatKey]
                        if chatEnt and chatEnt.isAscension == true then return false end
                    end
                    -- Lolos semua cek = RAID Normal
                    return true
                end
                local _now0 = os.time()
                local _pruned0 = false
                for rid, ent in pairs(RAID_LIVE) do
                    if ent.endTime and ent.endTime < (_now0 - 10) then
                        RAID_LIVE[rid] = nil; _pruned0 = true
                    end
                end
                if _pruned0 then
                    if RebuildRaidList then pcall(RebuildRaidList) end
                end
                if #RAID_ID_LIST == 0 then return nil end

                -- [FIX] Helper grade yang sadar Ascension (pakai key cache negatif untuk AT)
                -- (dibutuhkan custom resolver di bawah - dipertahankan dari versi asli)
                local function _getGrade(r)
                    return GetBestGrade(r.mapId - 50000, r.isAscension == true)
                end

                -- [Ascension Mode] Filter RAID_ID_LIST sesuai mode (buang Ascension,
                -- Auto Raid Normal cuma pakai raid Normal) - dipertahankan dari versi asli
                local _filteredList = {}
                for _, r in ipairs(RAID_ID_LIST) do
                    if _ascFilter(r) then
                        table.insert(_filteredList, r)
                    end
                end
                local RAID_ID_LIST = _filteredList

                -- ============================================================================
                -- [CUSTOM] Resolver 2-tahap khusus AUTO RAID STANDALONE:
                --   Tahap 1 (STRICT): Map 18 diutamakan, lalu Map 19 - HANYA jika
                --                     rank raid tsb termasuk salah satu Preferred
                --                     Rank (E/D/C/B/A/S/SS/G/N). Kalau tidak match,
                --                     TIDAK masuk (bukan fallback ke map lain dulu).
                --   Tahap 2 (FALLBACK): Kalau tidak ada Map 18/19 yang rank-nya
                --                     cocok sama sekali, baru cari Map 11-16
                --                     (urut terkecil dulu) dengan RANK APAPUN.
                --   Kalau keduanya tidak ada -> return nil (Waiting loop, tidak
                --   masuk raid manapun; StartRaidLoop otomatis retry terus).
                -- ============================================================================
                local STRICT_MAPS    = {18, 19}
                local FALLBACK_MAPS  = {11, 12, 13, 14, 15, 16}

                -- Tahap 1: STRICT (map + rank), Map 18 dicek duluan baru 19
                for _, wantMap in ipairs(STRICT_MAPS) do
                    local bestForThisMap = nil
                    for _, r in ipairs(RAID_ID_LIST) do
                        local mn = r.mapId - 50000
                        if mn == wantMap then
                            local grade = _getGrade(r)
                            if grade and RAID.runeGrades[grade] then
                                bestForThisMap = r
                                break
                            end
                        end
                    end
                    if bestForThisMap then
                        return bestForThisMap
                    end
                end

                -- Tahap 2: FALLBACK (Map 11-16, rank apapun), urut terkecil dulu
                local fallbackCandidates = {}
                for _, r in ipairs(RAID_ID_LIST) do
                    local mn = r.mapId - 50000
                    for _, wantMap in ipairs(FALLBACK_MAPS) do
                        if mn == wantMap then
                            table.insert(fallbackCandidates, r)
                            break
                        end
                    end
                end
                if #fallbackCandidates > 0 then
                    table.sort(fallbackCandidates, function(a, b) return a.mapId < b.mapId end)
                    return fallbackCandidates[1]
                end

                -- Tidak ada kandidat sama sekali di Tahap 1 maupun Tahap 2 -> Waiting
                return nil
            end
 -- [v238 FIX] Cek apakah ada raid yang benar-benar aktif di game sekarang
 -- Jika tidak, langsung masuk waiting loop tanpa coba masuk
 -- Ini mencegah "tindakan palsu" (TP ke enemy random, loop tak berguna)
 -- ketika Rune Map/Pick Rank di-OFF lalu di-ON lagi saat raid sudah habis
 if not IsRaidLiveInGame() then
 RAID.raidId = nil
 RAID.raidMapId = nil
 raidEntry = nil
 -- Paksa reset RAID_LIVE agar ResolveEntry tidak pakai data stale
 RAID_LIVE = {}
 RAID_ID_LIST = {}
 _defaultRRIdx = 0 -- reset RR saat RAID habis
 if RebuildRaidList then pcall(RebuildRaidList) end
 end

 local raidEntry = ResolveEntry()
 -- [v62 RINO/RINI FIX] Keputusan siapa yang "dipanggil" sudah dibuat di TriggerEntryWakeup.
 -- Jika _eventOwner == "asc" berarti siklus ini giliran ASC (Rino), RAID (Rini) tetap duduk.
 -- Fallback: kalau _eventOwner belum diset (nil), pakai cek ResolveAscEntry lama.
 if raidEntry and ASC and ASC.running then
  if _eventOwner == "asc" then
   raidEntry = nil -- giliran ASC, RAID standby
  elseif _eventOwner == nil and ResolveAscEntry and ResolveAscEntry() then
   raidEntry = nil -- belum ada keputusan, cek manual
  end
 end

 while RAID.running and not raidEntry do
 ForceRescanRaidEnter()
 raidEntry = ResolveEntry()
 -- [v62 RINO/RINI FIX] Cek ulang _eventOwner di setiap iterasi waiting loop
 if raidEntry and ASC and ASC.running then
  if _eventOwner == "asc" then
   raidEntry = nil
  elseif _eventOwner == nil and ResolveAscEntry and ResolveAscEntry() then
   raidEntry = nil
  end
 end
 if not raidEntry then
 -- Prune expired entries
 local _now2 = os.time()
 local _pruned2 = 0
 for rid, ent in pairs(RAID_LIVE) do
 if ent.endTime and ent.endTime < (_now2 - 10) then
 RAID_LIVE[rid] = nil; _pruned2 = _pruned2 + 1
 end
 end
 if _pruned2 > 0 then
 if RebuildRaidList then pcall(RebuildRaidList) end
 end
 -- [v262 FIX] Status label sesuai mode aktif (pickMode aware)
 local _pm = RAID.pickMode
 if not IsRaidLiveInGame() then
 RaidStatusUpdate("Empty RAID - Waiting new RAID", Color3.fromRGB(160,100,60))
 elseif ASC and ASC.running and (_eventOwner == "asc" or (ResolveAscEntry and ResolveAscEntry())) then
 -- [v62 RINO/RINI FIX] ASC ON dan siklus ini giliran ASC -> RAID standby
 RaidStatusUpdate("[||] ASC Ascension aktif & ada Tower match - Normal Raid standby...", Color3.fromRGB(180,100,255))
 elseif _pm == "byrank" and next(RAID.runeGrades) ~= nil then
 local _gr = {}
 for _,g in ipairs(GRADE_LIST) do if RAID.runeGrades[g] then table.insert(_gr,g) end end
 RaidStatusUpdate("Waiting Rank: ["..table.concat(_gr,"] [").."]...", Color3.fromRGB(200,120,255))
 elseif _pm == "bymap" and next(RAID.preferMaps) ~= nil then
 local _ms = {}
 for mn in pairs(RAID.preferMaps) do table.insert(_ms,"Map "..mn) end
 table.sort(_ms)
 RaidStatusUpdate("Waiting Map: "..table.concat(_ms,", ").."...", Color3.fromRGB(100,200,100))
 elseif RAID.runeEnabled and RAID.runeMapTarget >= 1 and RAID.runeMapTarget <= 20 and next(RAID.runeGrades) ~= nil then
 RaidStatusUpdate("Waiting grade cocok -> override Map " .. RAID.runeMapTarget .. "...", Color3.fromRGB(200,140,255))
 elseif RAID.runeEnabled and RAID.runeMapTarget >= 1 and RAID.runeMapTarget <= 20 then
 RaidStatusUpdate("Waiting raid apapun -> override Map " .. RAID.runeMapTarget .. "...", Color3.fromRGB(147,197,253))
 elseif next(RAID.runeGrades) ~= nil then
 RaidStatusUpdate("Waiting grade cocok [" .. RAID.difficulty .. "]...", Color3.fromRGB(200,255,150))
 else
 RaidStatusUpdate("Waiting raid [" .. (_pm ~= "default" and _pm or RAID.difficulty) .. "]...", Color3.fromRGB(255,200,60))
 end
 -- [FIX v256] Wakeup CEPAT: poll 0.05s, max 0.5s (bukan 1s)
 if _raidInterrupt and not RAID.running then _raidInterrupt = false end
 local _woken = false
 local _wConn
 if _raidWakeup then
 _wConn = _raidWakeup.Event:Connect(function() _woken = true end)
 end
 local _we = 0
 while not _woken and _we < 1 and RAID.running do
 task.wait(0.1); _we = _we + 0.1
 end
 if _wConn then pcall(function() _wConn:Disconnect() end) end
 end
 end
 if not RAID.running then break end


 -- [v238 FIX] Double-check sebelum masuk: apakah raid di raidEntry
 -- masih valid di server saat ini?
 -- [v245 FIX] Longgarkan: kalau raidEntry ada di RAID_LIVE dan tidak ada endTime
 -- (server tidak kirim endTime), anggap masih valid - jangan blokir masuk
 local _preCheck_ok = true
 if not raidEntry then
 _preCheck_ok = false
 elseif not RAID_LIVE[raidEntry.id] then
 _preCheck_ok = false
 elseif not IsRaidLiveInGame() then
 -- Satu kesempatan lagi: kalau entry ada tapi tidak ada endTime, izinkan
 local _ent = RAID_LIVE[raidEntry.id]
 if _ent and not _ent.endTime then
 _preCheck_ok = true -- server tidak kirim endTime = anggap valid
 else
 _preCheck_ok = false
 end
 end

 if not _preCheck_ok then
 _raidInterrupt = false; RAID.inMap = false; ReleaseMapLock("raid"); MODE:Release("raid")
 RaidStatusUpdate("Raid expired sebelum masuk - tunggu raid baru...", Color3.fromRGB(255,100,60))
 task.wait(2)
 break
 end

 -- [v252] Pause Mass Attack via MODE dispatcher
 
 -- [HUKUM PRIORITAS TERTINGGI - ANTI CULIK]
 -- Jika Siege / Dungeon sedang jalan, RAID WAJIB PAUSE!
 if (SIEGE and (SIEGE.inMap or SIEGE.teleporting)) then
     RaidStatusUpdate("[!] PAUSE: Menunggu Siege Selesai...", Color3.fromRGB(255, 100, 100))
     task.wait(2)
     break
 end
 
 -- [v54] HUKUM PRIORITAS ASC > RAID NORMAL (diperkuat dari v53)
 -- Kasus 1: ASC ON + ada Tower match sekarang -> RAID Normal standby
 -- Kasus 2: ASC ON + sudah pernah dominasi event ini (dominatedThisEvent) -> RAID Normal
 --          tetap diblokir meskipun Tower saat ini tidak match, sampai event benar-benar habis
 -- Kasus 3: ASC ON + tidak pernah dominasi event ini + tidak ada Tower match -> RAID boleh (fallback)
 -- Kasus 4: ASC OFF -> RAID jalan penuh tanpa batasan
 -- [v56 FIX] RAID standby selama ASC.running=true DAN masih ada Tower match di event saat ini
 -- Tidak diblokir oleh ASC.inMap atau _ascDominatedThisEvent
 -- RAID hanya boleh jalan kalau ResolveAscEntry() = nil (tidak ada Tower match sama sekali)
 if ASC and ASC.running then
     local _ascEntry = ResolveAscEntry and ResolveAscEntry()
     if _ascEntry then
         RaidStatusUpdate("[||] AUTO RAID ASCENSION aktif & ada Tower match - Normal Raid standby...", Color3.fromRGB(180,100,255))
         task.wait(1)
         break
     end
     -- ResolveAscEntry() = nil -> tidak ada Tower match -> RAID boleh jalan sebagai fallback
     -- [v61 CYCLEFIX] Tandai bahwa RAID jalan sebagai fallback di siklus ini
     -- ASC harus standby dan tidak boleh mencuri sampai siklus baru datang
     _raidFallbackActive = true
 end

 local currentWm = workspace:GetAttribute("MapId") or 0
 -- [FIX] Blokir Auto Raid saat di dalam Map Siege atau Dungeon
 if (currentWm >= 50201 and currentWm <= 50204) then
     task.wait(2)
     break
 end
 -- [v56 FIX] Jika player masih secara fisik di dalam Tower (seharusnya tidak terjadi karena ASC.inMap sudah cover)
 -- Tapi sebagai safety net: tunggu sampai keluar, jangan langsung break
 if currentWm >= 50301 and currentWm <= 50326 then
     RaidStatusUpdate("[||] Masih di dalam Ascension Tower - tunggu keluar...", Color3.fromRGB(180,100,255))
     while (workspace:GetAttribute("MapId") or 0) >= 50301 and RAID.running do
         task.wait(0.5)
     end
     if not RAID.running then break end
 end
 -- [FIX] Pause Auto Raid jika ST2 (Single Tower) sedang aktif di dalam map
 if ST2 and ST2.inMap then
     RaidStatusUpdate("[||] Tower aktif - Auto Raid pause...", Color3.fromRGB(255,140,0))
     while ST2 and ST2.inMap and RAID.running do
         task.wait(0.5)
     end
     if not RAID.running then break end
     RaidStatusUpdate("> Tower selesai - lanjut raid...", C.ACC3)
     task.wait(0.1)
 end

 -- Siege cek tetap pakai flag lama (siege sudah pakai MODE juga via alias)
 -- Tunggu SIEGE selesai dulu jika sedang inMap
 if SIEGE and (SIEGE.inMap or SIEGE.teleporting) then
     RaidStatusUpdate("[||] Tunggu SIEGE selesai...", Color3.fromRGB(255,180,50))
     local _ws = 0
     while (SIEGE.inMap or SIEGE.teleporting) and RAID.running and _ws < 120 do
         task.wait(0.5); _ws = _ws + 0.5
     end
     if not RAID.running then break end
 end

 -- Tunggu ASC selesai dulu jika sedang inMap
 if ASC and ASC.inMap then
     RaidStatusUpdate("[||] Tunggu ASC selesai...", Color3.fromRGB(255,180,50))
     local _wa = 0
     while ASC.inMap and RAID.running and _wa < 120 do
         task.wait(0.5); _wa = _wa + 0.5
     end
     if not RAID.running then break end
 end

 _raidInterrupt = true -- signal MA untuk pause (MA cek di guard tiap iterasi)

 -- [v52 FIX] Atomic lock: cegah ASC masuk bersamaan saat RAID baru lolos guard
 do
  local _rLockWait = 0
  while RAID.running and _rLockWait < 15 do
   if TryClaimMapLock("raid") then break end
   RaidStatusUpdate("[||] Tunggu slot masuk map bebas...", Color3.fromRGB(200,200,100))
   task.wait(0.2); _rLockWait = _rLockWait + 0.2
  end
  if not RAID.running then ReleaseMapLock("raid"); break end
 end
 
-- [v262 FIX] JANGAN set inMap=true dulu sebelum raidMapId di-assign
                    -- [FIX Ascension] raidEntry.id negatif = Ascension entry (chat-only id)
                    -- CreateRaidTeam butuh raidId positif dari server -> ambil dari RAID_LIVE jika tersedia
                    local _resolvedRaidId = raidEntry.id
                    if raidEntry.isAscension and _resolvedRaidId < 0 then
                        -- Cari raidId positif dari RAID_LIVE entry yang sama mapId & isAscension
                        for _rid, _ent in pairs(RAID_LIVE) do
                            if _ent.isAscension and _ent.mapId == raidEntry.mapId and _rid > 0 then
                                _resolvedRaidId = _rid; break
                            end
                        end
                        -- Jika masih negatif: pakai abs (fallback darurat, mungkin tidak work tapi tidak crash)
                        if _resolvedRaidId < 0 then _resolvedRaidId = math.abs(_resolvedRaidId) end
                    end
                    RAID.raidId = _resolvedRaidId
                    RAID.raidMapId = raidEntry.mapId
                    RAID.inMap = true
                    ReleaseMapLock("raid") -- [v52 FIX] inMap=true sudah di-set, IsAnyMapActive sudah cover
                    if RAID.updateActiveLabel then pcall(RAID.updateActiveLabel) end


                    
                    RAID.slotIndex = 2
                    if _raidIdRefreshCb then pcall(_raidIdRefreshCb) end
                    
                    local mn = raidEntry.mapId - 50000
                    if RAID.runeEnabled and RAID.runeMapTarget >= 1 and RAID.runeMapTarget <= 20 then mn = RAID.runeMapTarget end
                    local mapLabel = MAP_NAMES[mn] or ("Map " .. mn)

                    local _liveEntry = RAID_LIVE[RAID.raidId]
                    if not _liveEntry then
                        _raidInterrupt = false; RAID.inMap = false; MODE:Release("raid")
                        task.wait(1); break
                    end
                    RAID.serverMapId = nil
                    if not RAID.running then break end

                    -- [FUNGSI DEWA: Eksekusi UP/DOWN Rank]
                    local function DoUpDownOverride()
                        if not RAID.updownEnabled or not RE.UseRaidItem then return end
                        local dir = RAID.updownDir or "up"  -- [FIX v1.lua] default "up" jika nil (file 1 baris 12863)
                        local udId = (dir == "up") and 10270 or 10271
                        RaidStatusUpdate("[~] Override: "..dir:upper(), Color3.fromRGB(200,140,255))
                        pcall(function() RE.UseRaidItem:FireServer(udId) end)
                        task.wait(0.3)
                    end

                    -- [LOGIKA KEPUTUSAN 4 HUKUM]
                    local pm = RAID.pickMode or "default"
                    local useRune = false
                    local useUpDown = false
                    
                    if pm == "manual" then
                        if RAID.manualMatchMode == "primary" then
                            -- TAHAP 1: MATCH PREFERRED RANK -> HANYA RUNE YANG BOLEH JALAN!
                            if RAID.runeEnabled and RAID.runeMapTarget >= 1 and RAID.runeMapTarget <= 20 then 
                                -- [SISTEM ANTI-MUBAZIR]
                                if (raidEntry.mapId - 50000) == RAID.runeMapTarget then
                                    useRune = false -- Map sudah sama, simpan Rune-nya!
                                else
                                    useRune = true 
                                end
                            else
                                useRune = false
                            end
                            useUpDown = false -- << MUTLAK MATI DI TAHAP 1 (Gak boleh ikut campur!)
                            
                        elseif RAID.manualMatchMode == "updown" then
                            -- TAHAP 2: MATCH UP/DOWN TARGET -> Rune Mati, UpDown Jalan!
                            useRune = false
                            useUpDown = true
                            
                        elseif RAID.manualMatchMode == "fallback" then
                            -- TAHAP 3: JANGAN MAKSA! Keduanya mati.
                            useRune = false
                            useUpDown = false
                        end
                    else
                        -- Mode selain Manual (ByRank, dll)
                        if RAID.runeEnabled and RAID.runeMapTarget >= 1 and RAID.runeMapTarget <= 20 then 
                            if (raidEntry.mapId - 50000) == RAID.runeMapTarget then
                                useRune = false
                            else
                                useRune = true 
                            end
                        end
                        if RAID.updownEnabled then useUpDown = true end
                    end

                    -- [EKSEKUSI]
                    if useRune then
                        -- >>> MODE RUNE MAP OVERRIDE <<<
                        local targetMap = RAID.runeMapTarget
                        RaidStatusUpdate("Create Team...", C.ACC2)
                        if not RAID.fromMapId then RAID.fromMapId = RAID.raidMapId end
                        if RE.CreateRaidTeam then pcall(function() RE.CreateRaidTeam:InvokeServer(RAID.raidId) end) end
                        task.wait(0.2)
                        
                        -- Prioritas: Rune digunakan dulu, setelah itu langsung UpDown!
                        if useUpDown then DoUpDownOverride() end
                        
                        RaidStatusUpdate("Use Item (Map "..targetMap..")...", Color3.fromRGB(255,200,60))
                        local RUNE_IDS = {
                            [1]=10265,[2]=10266,[3]=10267,[4]=10268,[5]=10269, [6]=10314,[7]=10315,[8]=10316,
                            [9]=10357,[10]=10358,[11]=10359,[12]=10360,[13]=10361, [14]=10362,[15]=10363,[16]=10364,[17]=10365,[18]=10366,
                            [19]=10367,[20]=10368,
                        }
                        local itemId = RUNE_IDS[targetMap]
                        if itemId and RE.UseRaidItem then
                            pcall(function() RE.UseRaidItem:FireServer(itemId) end)
                        end
                        task.wait(0.3)
                        
                        if RE.StartChallengeRaidMap then
                            local _runeMapId = 50100 + targetMap
                            pcall(function() RE.StartChallengeRaidMap:FireServer({mapId = _runeMapId}) end)
                        end
                        
                        local _wR = 0
                        while RAID.serverMapId == nil and _wR < 10 and RAID.running do
                            task.wait(0.1); _wR = _wR + 0.1
                        end
                        
                        -- Fallback jika tiket Rune Map ternyata habis di inventory
                        if RAID.serverMapId == nil and RAID.running then
                            RaidStatusUpdate("[!] Material Kosong - Fallback...", Color3.fromRGB(255,140,0))
                            local _fbTargetMapId = raidEntry.mapId + 100
                            if RE.CreateRaidTeam then pcall(function() RE.CreateRaidTeam:InvokeServer(RAID.raidId) end) end
                            task.wait(0.2)
                            if RE.StartChallengeRaidMap then pcall(function() RE.StartChallengeRaidMap:FireServer({mapId = _fbTargetMapId}) end) end
                            local _wFb = 0; while RAID.serverMapId == nil and _wFb < 5 and RAID.running do task.wait(0.05); _wFb = _wFb + 0.05 end
                        end
                        
                    else
                        -- >>> MODE NORMAL / FALLBACK <<<
                        local targetMapId = raidEntry.mapId + 100
                        RaidStatusUpdate("Enter Map " .. (targetMapId-50100) .. "...", C.ACC3)

                        if not RAID.fromMapId then RAID.fromMapId = RAID.raidMapId end
                        if RE.CreateRaidTeam then pcall(function() RE.CreateRaidTeam:InvokeServer(RAID.raidId) end) end
                        task.wait(0.2)
                        if not RAID.running then break end

                        if useUpDown then DoUpDownOverride() end

                        local _cfail = false
                        local _cfConn
                        local _cfRe = Remotes:FindFirstChild("ChallengeRaidsFail")
                        if _cfRe then _cfConn = _cfRe.OnClientEvent:Connect(function() _cfail = true end) end

                        if RE.StartChallengeRaidMap then
                            pcall(function() RE.StartChallengeRaidMap:FireServer({mapId = targetMapId}) end)
                        end

                        local _w2 = 0
                        while RAID.serverMapId == nil and _w2 < 5 and RAID.running and not _cfail do task.wait(0.05); _w2 = _w2 + 0.05 end

                        if _cfConn then pcall(function() _cfConn:Disconnect() end) end
                        if _cfail then
                            RAID_LIVE[RAID.raidId] = nil; RebuildRaidList()
                            _raidInterrupt = false; RAID.inMap = false; MODE:Release("raid")
                            task.wait(1); break
                        end
                    end
 -- STEP 3: Tunggu masuk map (max 10s) - flow sama persis v41
 RaidStatusUpdate("[~] Waiting...", Color3.fromRGB(180,100,255))
 local _tpOk = false
 local _tpWait = 0
 while not _tpOk and _tpWait < 2 and RAID.running do
  task.wait(0.3); _tpWait = _tpWait + 0.3
  pcall(function()
   local wMapId = workspace:GetAttribute("MapId") or workspace:GetAttribute("mapId") or workspace:GetAttribute("CurrentMapId")
   if wMapId then
    if RAID.serverMapId and wMapId == RAID.serverMapId then
     _tpOk = true
    elseif RAID.runeEnabled then
     local ok = (wMapId >= 50101 and wMapId <= 50120)
     if ok then RAID.serverMapId = wMapId; _tpOk = true end
    elseif (wMapId >= 50101 and wMapId <= 50120) then
     _tpOk = true
    end
   end
  end)
  -- Fallback: kalau enemy sudah ada, berarti sudah di dalam map
  if not _tpOk and #GetRaidEnemies() > 0 then _tpOk = true end
 end

 if not _tpOk and RAID.running then
  -- Gagal masuk map: hapus entry dan retry
  RAID_LIVE[RAID.raidId] = nil; RebuildRaidList()
  _raidInterrupt = false; RAID.inMap = false; ReleaseMapLock("raid"); MODE:Release("raid"); RAID.fromMapId = nil
  task.wait(1); break
 end

 -- [FIX] Equip hero ke map ini agar hero spawn di sebelah player
 -- Tanpa ini hero tidak muncul di map raid meski GUID sudah ada
 if #HERO_GUIDS > 0 then
 task.spawn(function()
 task.wait(0.5)
 -- EquipHeroWithData: daftarkan hero ke map saat ini
 if RE.EquipHeroWithData then
 for _, hGuid in ipairs(HERO_GUIDS) do
 pcall(function()
 RE.EquipHeroWithData:FireServer({
 heroGuid = hGuid,
 userId = MY_USER_ID,
 })
 end)
 PG_Wait(0.1) -- [PingGuard] equip hero loop
 end
 end
 -- HeroStandTo ke posisi player sekarang
 if RE.HeroStand then
 local char = LP.Character
 local hrp = char and char:FindFirstChild("HumanoidRootPart")
 local spawnPos = (hrp and hrp.Position) or Vector3.new(0, 0, 0)
 pcall(function()
 RE.HeroStand:FireServer({
 userId = MY_USER_ID,
 standPos = spawnPos,
 })
 end)
 for _, hGuid in ipairs(HERO_GUIDS) do
 pcall(function()
 RE.HeroStand:FireServer({
 heroGuid = hGuid,
 userId = MY_USER_ID,
 standPos = spawnPos,
 })
 end)
 end
 end
 end)
 end

 -- STEP 4: Di dalam raid - cari boss, TP, serang
 -- [FIX v260] Jika sebelumnya Siege baru saja selesai, tunggu workspace bersih dulu.
 -- Cek aktif sampai 5 detik: jika masih ada enemy Siege di workspace, tunggu terus.
 -- Tanpa ini scan boss bisa menemukan sisa enemy Siege dan salah TP ke sana.
 if SIEGE and SIEGE._lastExitTime and (os.time() - SIEGE._lastExitTime) < 5 then
  RaidStatusUpdate("[~] Clearing Siege remnants...", Color3.fromRGB(160,148,135))
  local _siegeWait = 0
  while _siegeWait < 5 and RAID.running do
   local _curMId = GetCurrentMapId()
   -- Selama mapId masih di range Siege, tunggu
   if _curMId and (_curMId >= 50201 and _curMId <= 50204) then
    task.wait(0.5); _siegeWait = _siegeWait + 0.5
   else
    break -- mapId sudah bersih, lanjut
   end
  end
 end

 RAID._raidDone = false
 local _raidSuccess = false

 local connS, connF
 -- _raidServerDone = flag bahwa server sudah bilang sukses
 -- (attack loop tetap jalan sampai boss model hilang dari workspace)
 local _raidServerDone = false
 local _reS = Remotes:FindFirstChild("ChallengeRaidsSuccess")
 local _reF = Remotes:FindFirstChild("ChallengeRaidsFail")
 if _reS then connS = _reS.OnClientEvent:Connect(function()
  _raidServerDone = true; _raidSuccess = true
 end) end
 if _reF then connF = _reF.OnClientEvent:Connect(function()
  RAID._raidDone = true
 end) end

 --  HELPER: Cleanup semua koneksi + unfreeze player 
 -- Dipanggil di SETIAP jalur keluar dari STEP 4 (boss mati, boss tidak ketemu,
 local _freezeConn  = nil  -- RunService.Heartbeat conn untuk lock posisi player
 local _frozenCFrame = nil -- CFrame terkunci saat attack
 local function _step4Cleanup()
  -- 1) Lepas freeze player - pastikan Anchored = false
  pcall(function()
   local char = LP.Character
   local hrp  = char and char:FindFirstChild("HumanoidRootPart")
   if hrp then hrp.Anchored = false end
  end)
  -- 2) Disconnect Heartbeat freeze (idempoten - aman dipanggil berkali-kali)
  if _freezeConn then
   pcall(function() _freezeConn:Disconnect() end)
   _freezeConn  = nil
   _frozenCFrame = nil
  end
  -- 3) Disconnect server event listeners
  if connS then pcall(function() connS:Disconnect() end); connS = nil end
  if connF then pcall(function() connF:Disconnect() end); connF = nil end
 end

 --  LOADING WAIT: tunggu enemies muncul via ChildAdded 
 -- ChildAdded murni untuk deteksi instan + polling ringan sebagai safety net.
 RaidStatusUpdate("[..] Enter Map - loading...", Color3.fromRGB(160,148,135))

 -- [FIX v261] Snapshot mapId diambil SETELAH jeda singkat agar workspace.MapId
 -- sempat update dari server sebelum dipakai untuk validasi.
 task.wait(0.3) -- beri server 1 tick untuk update workspace.MapId

 local function _isValidRaidMap(mId)
  if not mId then return false end
  return (mId >= 50101 and mId <= 50120) or (mId >= 50301 and mId <= 50326)
 end

 local function _isValidRaidMapByInstance()
  local mf = workspace:FindFirstChild("Maps")
  if not mf then return false end
  -- Map1 dan Map3 instance-nya Map101/Map103 (beda sendiri)
  if mf:FindFirstChild("Map101") or mf:FindFirstChild("Map103") then return true end
  for i = 2, 20 do
   if i ~= 3 and mf:FindFirstChild("Map"..i) then return true end
  end
  return false
 end

 -- Tunggu mapId valid (max 3s) - cek via workspace.Maps instance ATAU numerik
 local _raidMapIdSnapshot = GetCurrentMapId()
 local _snapWait = 0
 while not (_isValidRaidMapByInstance() or _isValidRaidMap(_raidMapIdSnapshot)) and _snapWait < 3 and RAID.running do
  task.wait(0.3); _snapWait = _snapWait + 0.3
  _raidMapIdSnapshot = GetCurrentMapId()
 end

 -- [CUSTOM v54.1] Render delay sederhana - TANPA scan nama boss sama sekali.
 -- Mode TP DIRECT tidak butuh tahu siapa boss-nya; target diambil murni dari
 -- scan radius di titik TP (lihat blok AUTO BOSS KILL di bawah). Loading wait
 -- ini hanya untuk memberi waktu render server sebelum TP+scan dilakukan.
 RaidStatusUpdate("[..] Render delay...", Color3.fromRGB(160,148,135))
 local _preMapNum = GetRaidMapNum(raidEntry and raidEntry.mapId)
 local _renderDelay = (_preMapNum == 1) and 4 or 2
 task.wait(_renderDelay) -- Map1: 4s, lainnya: 2s

 if RAID.running and not RAID._raidDone and RAID.autoKillBoss then
  -- [v56] AUTO BOSS KILL - TP KE ROOTPART BOSS (REALTIME)
  -- Teleport player+hero langsung ke CFrame RootPart boss di workspace.Maps.
  -- Path: workspace.Maps.[instanceName].Map.RaidsEnemys.[rootPartName]
  -- Mapping instance+rootPart per mapNum ada di RAID_MAP_INFO.
  -- Setelah TP, scan musuh radius 50 studs dari posisi RootPart tersebut.

  -- Resolve mapNum via workspace.Maps instance (primary) lalu fallback numerik.
  local _mapNumNow = GetRaidMapNum(raidEntry and raidEntry.mapId)

  -- Ambil CFrame realtime dari RootPart boss
  local _tpTargetCF  = _mapNumNow and GetBossRootPartCFrame(_mapNumNow) or nil
  local _tpTargetPos = _tpTargetCF and _tpTargetCF.Position or nil

  -- [v56] FALLBACK BOSS NAME khusus Map 1 dan Map 3:
  -- RootPart di kedua map ini tidak bisa dideteksi via workspace.Maps,
  -- scan workspace.Enemys berdasarkan nama boss (Goblin King / Igris).
  if not _tpTargetPos and (_mapNumNow == 1 or _mapNumNow == 3) then
   local _bossName = BOSS_NAME_BY_MAP[_mapNumNow]
   local _enemysFolder = workspace:FindFirstChild("Enemys")
   if _enemysFolder and _bossName then
    for _, e in ipairs(_enemysFolder:GetChildren()) do
     if e:IsA("Model") and e.Name:find(_bossName, 1, true) then
      local _bHrp = e:FindFirstChild("HumanoidRootPart") or e.PrimaryPart
      local _bHum = e:FindFirstChildOfClass("Humanoid")
      if _bHrp and _bHum and _bHum.Health > 0 then
       _tpTargetPos = _bHrp.Position
       _tpTargetCF  = _bHrp.CFrame
       break
      end
     end
    end
   end
  end

  if not _tpTargetPos then
   local _info = _mapNumNow and RAID_MAP_INFO[_mapNumNow]
   local _detail = _info and ("Maps."..(_info.instance)..".Map.RaidsEnemys.".._info.rootPart) or ("mapNum="..tostring(_mapNumNow))
   RaidStatusUpdate("[!] RootPart boss tidak ditemukan - " .. _detail .. " - skip", Color3.fromRGB(255,80,80))
   _step4Cleanup()
   task.wait(2)
  else
   -- Countdown delay sebelum TP (1-10s, user-controlled, sama seperti sebelumnya)
   local _bd = math.max(1, math.min(10, RAID.bossDelay or 3))
   for _ci = _bd, 1, -1 do
    if not RAID.running or RAID._raidDone then break end
    RaidStatusUpdate("[K] TP ke Boss Map " .. tostring(_mapNumNow) .. " - " .. _ci .. "s...", Color3.fromRGB(255,160,60))
    task.wait(1)
   end

   if RAID.running and not RAID._raidDone then
    -- Refresh CFrame boss tepat sebelum TP (posisi bisa saja bergerak)
    _tpTargetCF  = GetBossRootPartCFrame(_mapNumNow) or _tpTargetCF
    _tpTargetPos = _tpTargetCF.Position

    -- 1) TP Player ke posisi RootPart boss
    pcall(function()
     local char = LP.Character
     local hrp  = char and char:FindFirstChild("HumanoidRootPart")
     if hrp then hrp.CFrame = _tpTargetCF end
    end)

    -- 2) UnEquip -> EquipBest (timing: UnEquip, wait 1s, EquipBest, wait 2s)
    if RE.UnEquipHero  then pcall(function() RE.UnEquipHero:FireServer()  end) end
    task.wait(1)
    if RE.EquipBestHero then pcall(function() RE.EquipBestHero:FireServer() end) end
    task.wait(2)

    -- [FIX BOSS-KILL] Pastikan HERO_GUIDS terisi independen (jangan bergantung RA/TA/fitur lain).
    -- RE.HeroUseSkill butuh heroGuid eksplisit; tanpa ini hero diam walau EquipBestHero sukses.
    if #HERO_GUIDS == 0 then
     pcall(function()
      for _, obj in ipairs(LP.PlayerGui:GetChildren()) do
       local g = obj:GetAttribute("heroGuid") or obj:GetAttribute("guid")
       if type(g) == "string" and IsValidUUID(g) then
        local dup = false
        for _, ex in ipairs(HERO_GUIDS) do if ex == g then dup = true; break end end
        if not dup then table.insert(HERO_GUIDS, g) end
       end
      end
     end)
     if #HERO_GUIDS > 0 then
      RaidStatusUpdate("[HERO] "..#HERO_GUIDS.." hero guid ter-scan dari PlayerGui", Color3.fromRGB(120,220,255))
     else
      RaidStatusUpdate("[!] HERO_GUIDS masih kosong - hero mungkin tidak menyerang", Color3.fromRGB(255,140,0))
     end
    end

    -- 5) Kunci posisi player selama scan+attack (Heartbeat freeze)
    -- [TA-STYLE] Reposisi mengikuti target real-time (bukan statis di titik TP awal),
    -- identik pola ReassertFreeze/TpToF milik TARGET ATTACK: tiap frame CFrame
    -- direfresh ke 3 stud di depan HRP musuh terkini (_bossFollowTarget, diisi
    -- setelah target hasil scan radius ditemukan di bawah).
    local _bossFollowTarget = nil -- diisi = {hrp=...} setelah target ditemukan (lihat blok scan di bawah)
    pcall(function()
     local char = LP.Character
     local hrp  = char and char:FindFirstChild("HumanoidRootPart")
     if hrp then
      _frozenCFrame = _tpTargetCF
      hrp.Anchored  = true
      hrp.CFrame    = _frozenCFrame
      _freezeConn = RunService.Heartbeat:Connect(function()
       -- [FLa CPU] skip frame ganjil  efektif ~30fps
       if not _freezeFrame then _freezeFrame = 0 end
       _freezeFrame = _freezeFrame + 1
       if _freezeFrame % 2 ~= 0 then return end
       if not RAID.running or RAID._raidDone then
        pcall(function() if hrp and hrp.Parent then hrp.Anchored = false end end)
        if _freezeConn then _freezeConn:Disconnect(); _freezeConn = nil end
        _frozenCFrame = nil
        return
       end
       if hrp and hrp.Parent then
        -- [TA-STYLE] Kalau target sudah ada & hidup, ikuti posisinya (3 stud di depan).
        -- Kalau belum ada target (masih fase scan awal), tetap pakai _frozenCFrame lama.
        local _bt = _bossFollowTarget
        if _bt and _bt.hrp and _bt.hrp.Parent then
         local ok = pcall(function()
          _frozenCFrame = _bt.hrp.CFrame * CFrame.new(0, 0, -3)
          hrp.CFrame     = _frozenCFrame
         end)
         if not ok and _frozenCFrame then hrp.CFrame = _frozenCFrame end
        elseif _frozenCFrame then
         hrp.CFrame = _frozenCFrame
        end
       end
      end)
     end
    end)

    --  SCAN RADIUS 10 STUDS - cari 1 musuh terdekat dari posisi RootPart boss 
    -- Timeout 3 detik (sesuai keputusan): scan tiap 0.5s, total 6x percobaan.
    local TP_SCAN_RADIUS = 50
    local function _scanNearbyEnemy()
     local best, bestDist = nil, nil
     for _, e in ipairs(GetRaidEnemies()) do
      local hum = e.model:FindFirstChildOfClass("Humanoid")
      if hum and hum.Health > 0 and e.hrp and e.hrp.Parent then
       local d = (e.hrp.Position - _tpTargetPos).Magnitude
       if d <= TP_SCAN_RADIUS and (not bestDist or d < bestDist) then
        best = e; bestDist = d
       end
      end
     end
     return best
    end

    local target = _scanNearbyEnemy()
    local _scanWait = 0
    while not target and _scanWait < 3 and RAID.running and not RAID._raidDone do
     task.wait(0.5); _scanWait = _scanWait + 0.5
     target = _scanNearbyEnemy()
    end

    if not target then
     -- Tidak ada musuh dalam radius setelah timeout - anggap gagal, skip map ini
     RaidStatusUpdate("[!] Tidak ada musuh dalam radius " .. TP_SCAN_RADIUS .. " studs - Go Out...", Color3.fromRGB(255,150,50))
     _step4Cleanup()
     task.wait(2)
    else
     -- Musuh ketemu - attack loop pakai cara RA+TA (FCharF style)
     local targetGuid = target.guid
     RaidStatusUpdate("[FLa] Attack: " .. target.model.Name, Color3.fromRGB(255,80,60))

     -- [TA-STYLE] Aktifkan follow-target untuk Heartbeat freeze di atas: mulai
     -- sekarang player akan direposisi 3 stud di depan HRP boss setiap frame,
     -- mengikuti gerak boss (bukan lagi diam di titik TP awal).
     _bossFollowTarget = target

     -- Helper: hitung posisi 10 stud dari musuh ke arah player (sama seperti GetAtkPosF di Farm)
     local function _getBossAtkPos(enemyHRP)
      local char = LP and LP.Character
      local pHRP = char and char:FindFirstChild("HumanoidRootPart")
      if not pHRP or not enemyHRP then return enemyHRP and enemyHRP.Position or _tpTargetPos end
      local ePos = enemyHRP.Position
      local dir = pHRP.Position - ePos
      local dir2 = Vector3.new(dir.X, 0, dir.Z)
      if dir2.Magnitude < 0.1 then return ePos + Vector3.new(10,0,0) end
      return ePos + dir2.Unit * 10
     end

     -- [RA+TA HYBRID] Attack loop STEP4 diganti pakai mekanisme asli RA & TA
     -- (RE.Atk + RE.Click + EnsureHeroAtkThreadFor), BUKAN FireAttack/FireAllDamage/FireHeroRemotes.
     -- Tahap 1 (RA-style): begitu masuk radius 50 studs, fire ke GUID musuh RANDOM dari hasil scan
     --   (memicu combat state, identik cara kerja RA saat memilih musuh acak).
     -- Tahap 2 (TA-style): fire ke GUID boss hasil scan 50 studs, DIKUNCI terus tiap loop
     --   sampai target itu mati (identik cara kerja TA saat lock 1 target by GUID).
     local function _fireOnce(guid)
      if not guid then return end
      if RE.Atk then
       pcall(function() RE.Atk:FireServer({attackEnemyGUID=guid}) end)
      end
      if RE.Click then
       task.spawn(function()
        pcall(function() RE.Click:InvokeServer({enemyGuid=guid}) end)
       end)
      end
      EnsureHeroAtkThreadFor(guid)
     end

     -- Ambil GUID musuh random lain (selain target boss) dari radius 50 studs untuk tahap RA.
     -- Kalau tidak ada musuh lain, fallback pakai GUID boss itu sendiri sebagai RA (tidak masalah).
     local function _pickRandomGuidNearby(excludeGuid)
      local pool = {}
      for _, e in ipairs(GetRaidEnemies()) do
       local hum = e.model:FindFirstChildOfClass("Humanoid")
       if hum and hum.Health > 0 and e.hrp and e.hrp.Parent then
        local d = (e.hrp.Position - _tpTargetPos).Magnitude
        if d <= TP_SCAN_RADIUS then table.insert(pool, e) end
       end
      end
      if #pool == 0 then return excludeGuid end
      local pick = pool[math.random(1, #pool)]
      return pick.guid
     end

     -- Helper: attack 1 cycle = RA (random guid) lalu TA (locked target guid)
     local function _attackBoss(guid, enemyHRP)
      -- Tahap 1: RA-style ke guid random dalam radius
      local _raGuid = _pickRandomGuidNearby(guid)
      _fireOnce(_raGuid)
      -- Tahap 2: TA-style ke guid target boss (locked)
      _fireOnce(guid)
     end

     local _outOfMapCount = 0
     local _bossTimeout   = false          -- [v5] flag timeout 4 menit
     local _atkStart      = tick()         -- [v5] waktu mulai attack
     local BOSS_TIMEOUT   = 240            -- [v5] 4 menit (detik)
     while RAID.running do
      -- [v5] TIMEOUT: 4 menit tanpa boss mati → anggap sukses, keluar seperti kill normal
      if tick() - _atkStart >= BOSS_TIMEOUT then
       _bossTimeout = true
       RaidStatusUpdate("[T] Boss timeout 4min - Dianggap Sukses, keluar...", Color3.fromRGB(255,200,60))
       break
      end
      if _raidServerDone then break end
      local _curMap = GetCurrentMapId()
      if _curMap and (_curMap < 50101 or _curMap > 50120) then
       _outOfMapCount = _outOfMapCount + 1
       if _outOfMapCount >= 3 then
        RaidStatusUpdate("[!] Player keluar raid map - stop attack", Color3.fromRGB(255,140,0))
        break
       end
      else
       _outOfMapCount = 0
      end
      if not target.model or not target.model.Parent then break end
      local hum = target.model:FindFirstChildOfClass("Humanoid")
      if not hum or hum.Health <= 0 then break end
      if not target.hrp or not target.hrp.Parent then
       task.wait() -- [TA-STYLE] no-delay, sama seperti TA
       if not target.model or not target.model.Parent then break end
       local hum2 = target.model:FindFirstChildOfClass("Humanoid")
       if not hum2 or hum2.Health <= 0 then break end
       continue
      end
      -- Scan ulang musuh terdekat dalam radius (jaga-jaga boss ganti/spawn baru)
      local _nearNow = _scanNearbyEnemy()
      if _nearNow and _nearNow.guid ~= targetGuid then
       target = _nearNow
       targetGuid = target.guid
       _bossFollowTarget = target -- [TA-STYLE] update follow-target juga saat target berganti
       RaidStatusUpdate("[FLa] Target baru: " .. target.model.Name, Color3.fromRGB(255,80,60))
      end
      pcall(function() _attackBoss(targetGuid, target.hrp) end)
      task.wait() -- [TA-STYLE] no-delay, sama seperti TA (bukan PG_Wait(0.1))
     end

     _step4Cleanup()
     _raidSuccess = true
     RAID._raidDone = true
     if _bossTimeout then
      RaidStatusUpdate("[T] Timeout 4min - Raid Sukses (forced)", Color3.fromRGB(255,200,60))
     else
      RaidStatusUpdate("[FLa] Target Dead!", Color3.fromRGB(100,255,150))
     end
    end -- if target
   end -- if RAID.running (setelah countdown)
  end -- if _tpTargetPos valid
 elseif RAID.running and not RAID._raidDone then
 -- Auto Kill Boss OFF - tunggu event ChallengeRaidsSuccess max 5 menit
 local _wt = 0
 while RAID.running and not RAID._raidDone and _wt < 300 do
  task.wait(1); _wt = _wt + 1
 end
 end

 -- [FIX v260] Cleanup terpusat (idempoten - aman meski sudah dipanggil dari dalam autoKillBoss path)
 _step4Cleanup()

 if _raidSuccess then
 RAID.sukses = RAID.sukses + 1
 RaidCounterUpdate()
 RaidStatusUpdate("[OK] Succes-" .. RAID.sukses .. " Map " .. mn, Color3.fromRGB(100,255,150))
 -- [RAID LIST ENTRY] Catat map ini sudah dikunjungi setelah sukses keluar
 if RAID.listEnabled and RAID.raidMapId then
  RAID._listVisitedMaps[RAID.raidMapId] = true
 end
 end
 if not RAID.running then break end

 if _raidSuccess then
  RaidStatusUpdate("[..] Wait 1s (Get reward)...", Color3.fromRGB(100,255,150))
  task.wait(1)
 end
 if not RAID.running then break end

 -- STEP 5: Collect + Exit raid
 task.spawn(function() pcall(RaidCollectAll) end)
 RaidStatusUpdate("[FLa] Go Out raid...", Color3.fromRGB(100,200,255))

 RAID_LIVE[RAID.raidId] = nil
 RebuildRaidList()

 -- [v247] STEP 6: Selalu TP ke MapId 50001 (Map 1) setelah raid selesai
 -- Reward sudah di-collect bersamaan saat boss mati (RaidCollectAll di atas)
 local _toMapId = 50001
 RaidStatusUpdate("[FLa] Go Out -> Map 1...", Color3.fromRGB(200,100,100))

 -- Helper TP sesuai range map
 local function _fireTpRaid(mapId)
 local m = mapId - 50000
 if m >= 1 and m <= 4 then
 pcall(function() RE.StartTp:FireServer({ mapId = mapId }) end)
 else
 pcall(function() RE.LocalTp:FireServer({ mapId = mapId }) end)
 end
 end

 -- Cek masih di area raid
 local function _inRaidArea()
 local ok = false
 pcall(function()
 local wm = workspace:GetAttribute("MapId") or workspace:GetAttribute("mapId") or workspace:GetAttribute("CurrentMapId")
 if wm then
 ok = (wm >= 50101 and wm <= 50120) -- [FIX v17] cover Map 19 & 20
 end
 end)
 return ok
 end

 if true then -- [INDEPENDEN] tidak cek siege
 -- Kirim QuitRaidsMap + TpRemote berlapis
 local _quitRe = Remotes:FindFirstChild("QuitRaidsMap")
 if _quitRe then
 pcall(function() _quitRe:FireServer({ currentSlotIndex = RAID.slotIndex or 2, toMapId = _toMapId }) end)
 end
 task.wait(0.3)
 _fireTpRaid(_toMapId)

 -- Retry max 5x kalau masih di raid area
 local _exitTry = 0
 while _inRaidArea() and _exitTry < 5 and RAID.running do
 _exitTry = _exitTry + 1
 task.wait(1)
 if _quitRe then
 pcall(function() _quitRe:FireServer({ currentSlotIndex = RAID.slotIndex or 2, toMapId = _toMapId }) end)
 end
 task.wait(0.2)
 _fireTpRaid(_toMapId)
 end
 end

 RAID.fromMapId = nil
 RAID.inMap = false

 -- STEP 6: Resume MA -> cooldown
 _raidInterrupt = false
 MODE:Release("raid") -- [FIX v257] MA HARUS resume saat player di luar raid
 -- [FIX v256] Cooldown 12s: server butuh ~12s sebelum bisa masuk Raid lagi
 -- TAPI: selama cooldown, tetap scan workspace agar RAID_LIVE siap
 -- Saat cooldown habis, langsung masuk tanpa delay tambahan
 -- [BUG FIX 3] Tandai cooldown aktif agar standby loop tidak terburu-buru masuk
 RAID._cooldownActive = true
 for cd = 14, 1, -1 do
 if not RAID.running then break end
 -- [INDEPENDEN] tidak tunggu siege setelah exit raid
 -- Scan workspace selama cooldown agar data siap
 if cd % 3 == 0 then ForceRescanRaidEnter() end
 RaidStatusUpdate("[..] Cooldown " .. cd .. "s...", Color3.fromRGB(160,148,135))
 if RAID.dot then RAID.dot.BackgroundColor3 = Color3.fromRGB(255,200,60) end
 task.wait(1)
 end
 RAID._cooldownActive = false -- [BUG FIX 3] Cooldown selesai, standby loop boleh masuk

 -- [FIX BUG 2 LIST ENTRY] Buffer 2s tambahan setelah cooldown 14s
 -- Mencegah "terlalu cepat masuk raid lagi" notif dari server
 if RAID.listEnabled and #RAID.listEntries > 0 then
  RaidStatusUpdate("[..] List Entry buffer 2s...", Color3.fromRGB(160,148,135))
  for _bf = 2, 1, -1 do
   if not RAID.running then break end
   task.wait(1)
  end
 end

 -- [v247] STEP 7: Setelah cooldown selesai:
 -- 1. Jika SIEGE aktif/running -> tunggu SIEGE selesai total dulu (PRIORITAS atas MA)
 -- 2. Setelah SIEGE selesai -> baru MA bisa resume (via _raidInterrupt=false)
 -- 3. Jika tidak ada SIEGE -> MA langsung resume
 if RAID.running then
 RaidStatusUpdate("[>>] Waiting & Cooldown...", Color3.fromRGB(100,255,150))
 if RAID.dot then RAID.dot.BackgroundColor3 = Color3.fromRGB(100,100,100) end
 local _fw = 0
 while RAID.running do
 -- [FIX v256] Agresif: manual scan workspace tiap cycle
            ForceRescanRaidEnter()

            -- [HUKUM PRIORITAS TERTINGGI DI FASE STANDBY]
            local isBusy = false
            if (SIEGE and (SIEGE.inMap or SIEGE.teleporting)) then
                isBusy = true
            end
            local mapId = workspace:GetAttribute("MapId") or 0
            if (mapId >= 50201 and mapId <= 50204) then
                isBusy = true
            end
            -- RAID standby selama _ascBusy=true (ASC inMap atau cooldown dengan Tower tersedia)
            local _ascBlocking = ASC and ASC.running and _ascBusy

            if isBusy or _ascBlocking then
                if _ascBlocking then
                    RaidStatusUpdate("[||] ASC aktif & ada Tower match - Normal Raid standby...", Color3.fromRGB(180, 100, 255))
                else
                    RaidStatusUpdate("[!] PAUSE: Menunggu Siege/Dungeon Selesai...", Color3.fromRGB(255, 100, 100))
                end
            else
                -- Jika aman, baru boleh cari Raid
                -- Cek IsRaidLiveInGame DULU sebelum ResolveEntry
                -- [BUG FIX 3] Jangan break jika cooldown masih aktif
                if not RAID._cooldownActive and IsRaidLiveInGame() then
                    local _newEntry = ResolveEntry and ResolveEntry()
                    if _newEntry then raidEntry = _newEntry; break end
                    RaidStatusUpdate("[FLa] Waiting grade filter... (" .. _fw .. "s)", Color3.fromRGB(200,255,150))
                else
                    RaidStatusUpdate("[FLa] Empty RAID - Waiting event baru... (" .. _fw .. "s)", Color3.fromRGB(160,120,60))
                end
            end
 -- [FIX v256] Wakeup CEPAT: poll 0.05s, max 0.5s
 local _woken2 = false
 local _wConn2
 if _raidWakeup then
 _wConn2 = _raidWakeup.Event:Connect(function() _woken2 = true end)
 end
 local _we2 = 0
 while not _woken2 and _we2 < 1 and RAID.running do
 task.wait(0.1); _we2 = _we2 + 0.1
 end
 if _wConn2 then pcall(function() _wConn2:Disconnect() end) end
 _fw = _fw + 1
 end
 end

 until true
 end -- while RAID.running
 end) -- pcall

 -- [v63 FIX] Cleanup dijamin jalan meskipun ada Lua error di dalam loop
 _raidInterrupt = false
 RAID.running = false
 RAID.inMap = false
 _raidOn = false
 _raidFallbackActive = false  -- [v61 CYCLEFIX] reset saat RAID stop
 MODE:Release("raid") -- [v257] pastikan MA bisa resume
 RaidStatusUpdate("[FLa] Auto Raid STOP", Color3.fromRGB(160,148,135))
 if RAID.dot then RAID.dot.BackgroundColor3 = Color3.fromRGB(100,100,100) end
 end)
end

-- ============================================================================
-- AUTO-CONFIG: Preferred Maps 18,19 | Preferred Rank E-N | Auto Boss Kill 1s
-- ============================================================================
task.wait(5) -- delay 5 detik sebelum apapun dijalankan

-- [PENTING] Pemilihan raid TIDAK lagi memakai Pick Mode bawaan (default/byrank/
-- bymap/manual/dst) - fungsi ResolveEntry() di StartRaidLoop sudah DIGANTI
-- dengan resolver custom 2-tahap khusus (lihat komentar [CUSTOM] di dalamnya):
--   Tahap 1 (STRICT) : Map 18 diutamakan, baru Map 19 - HANYA jika rank raid
--                       tsb match salah satu Preferred Rank di bawah.
--   Tahap 2 (FALLBACK): Map 11-16 (urut terkecil dulu) dengan RANK APAPUN,
--                       hanya dipakai kalau Tahap 1 sama sekali tidak ada
--                       yang match.
--   Kalau keduanya kosong -> Waiting (tidak masuk raid manapun).
-- RAID.pickMode di bawah HANYA dipakai internal untuk cabang useRune/useUpDown
-- (keduanya OFF di config ini) - tidak lagi memengaruhi map/rank yang dipilih.
RAID.pickMode   = "default"
RAID.difficulty = "easy"

-- Preferred Maps: 18, 19 (dipakai custom resolver Tahap 1 di atas)
RAID.preferMaps = {}
RAID.preferMaps[18] = true
RAID.preferMaps[19] = true

-- Preferred Rank: E, D, C, B, A, S, SS, G, N (dipakai custom resolver Tahap 1)
RAID.runeGrades = {}
for _, g in ipairs({"E","D","C","B","A","S","SS","G","N"}) do
    RAID.runeGrades[g] = true
end

-- Auto Item / Rune Map: tidak dipakai
RAID.runeMapTarget = 0
RAID.runeEnabled   = false

-- UP/DOWN Rank: tidak dipakai
RAID.updownEnabled     = false
RAID.updownDir         = nil
RAID.updownTargetGrade = nil

-- Raid List Entry: tidak dipakai (pakai Preferred Maps + Preferred Rank biasa)
RAID.listEnabled = false
RAID.listEntries = {}

-- AUTO KILL BOSS: ON, Teleport Delay = 1 detik
RAID.autoKillBoss = true
RAID.bossDelay    = 1

-- ============================================================================
-- START
-- ============================================================================
StartRaidLoop()
print("[AUTO RAID STANDALONE] Started. Preferred Maps: 18,19 | Rank: E/D/C/B/A/S/SS/G/N | Boss Kill: ON (1s)")
