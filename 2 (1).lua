--[[
    KERANGKA MENU TAB -> WindUI (VERSI FINAL)
    Urutan sesuai permintaan terbaru - 11 tab, TIDAK di-flatten lagi.
    Automation & Reroll masing-masing CUMA 1 tab (sub-fitur di dalamnya diatur
    pakai Section/Group nanti waktu pengisian fungsi, bukan dipecah jadi tab sidebar).

    Tambahan: profil user (avatar + username Roblox asli) di pojok kiri-bawah sidebar,
    di bawah tab Theme - pakai config native `User` WindUI (pengganti CreateUserProfile()
    di baris 1132-1172 source asli).

    Pemetaan tab -> baris source asli (referensi buat pengisian fungsi nanti):
      1. Main        -> PANEL: MAIN (3812)
      2. Hide         -> PANEL: HIDE (5171)
      3. Farm         -> PANEL: FARM (5571)
      4. Mass Attack  -> PANEL: ATTACK (6785)
      5. Automation   -> Auto Raid (13577), Auto Ascension (14700), Auto Siege (16029),
                         Single Tower Map2 (17293), Join To Tower (17486), Join To Raid (17800)
      6. Reroll       -> Hero Fastroll (7241), Weapon Fastroll (7633), Pet Gear (8002),
                         Halo (8217), Ornament (8311)
      7. Player       -> PANEL: PLAYER (7022)
      8. Setting      -> PANEL: SETTINGS (19002)
      9. Webhook      -> PANEL: WEBHOOK (19113)
      10. Config      -> PANEL: CONFIG (20199)
      11. Theme       -> PANEL: THEME (21364)

      [belum dipetakan ke tab mana - tunggu instruksi]: Claim Reward (18167),
        Anniversary Celebration (18475) -- kemungkinan masuk ke dalam tab Main atau
        tab tersendiri, BELUM ditentukan di list barumu. Tanya saya nanti kalau sudah sampai sana.

    [v3] PENAMBAHAN ke tab Main:
      - COUNTER AUTO SELL HERO EQUIP  (Paragraph: R/Y/B/Supreme + Button RESET COUNTER)
      - AUTO SELL HERO EQUIP          (Toggle + seluruh logika sell)
        Logika: StartAutoSell, scanGuidNames, getType, getGrade, shouldSell, doSell,
                _sellToggleCb, global expose _setSellHeroToggle/_visSellHero/_autoSellOnState
      - Status info via Paragraph yang diupdate realtime

    [v4] PENAMBAHAN ke tab Main:
      - AUTO COLLECT GOLD & ITEM      (Toggle + seluruh logika collect)
        Dependency chain:
          _collectObj           (baris ~486)  - TP obj ke player + fire CollectItem/ExtraReward
          _instantCollectConns  (baris ~483)  - tabel koneksi instant collector
          _instantCollected     (baris ~484)  - dedup cache instant collector
          StartInstantGoldCollector (baris ~511) - listen ChildAdded per folder
          _goldMagnetRunning    (baris ~2420) - flag magnet loop
          StartGoldMagnet       (baris ~2421) - loop TP semua item ke player tiap 0.05s
          StopGoldMagnet        (baris ~2468) - stop magnet loop
          DoAutoCollect         (baris ~2720) - polling loop collect via StartLoop
          DoAutoCollectGoldItem (baris ~2472) - master toggle: panggil semua di atas
        Global expose: _setAutoCollectToggle, _visAutoCollect, _autoCollectState
        Dependency global: STATE, LOOPS, COLLECTED, RE, LP, PG_Wait, StartLoop, StopLoop
--]]

--  SERVICES 
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

--  GLOBALS BERSAMA (dibutuhkan AUTO COLLECT dan fitur lain) 
-- Source asli baris ~1504
STATE = {
    autoCollect         = false,
    autoCollectGoldItem = false,
    autoDestroyer       = false,
    autoArise           = false,
    noClip              = false,
    antiAfk             = false,
    autoConfirm         = false,
    autoClose           = false,
}
LOOPS     = {}  -- { [key] = thread } - dikelola StopLoop/StartLoop
COLLECTED = {}  -- dedup cache collect loop

--  StopLoop / StartLoop 
-- Source asli baris ~1507-1516
function StopLoop(key)
    if LOOPS[key] then
        pcall(function() task.cancel(LOOPS[key]) end)
        LOOPS[key] = nil
    end
end

function StartLoop(key, fn)
    StopLoop(key)
    LOOPS[key] = task.spawn(fn)
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

--  RE: Remote Events / Functions 
-- Source asli baris ~443-477
-- Hanya remote yang dibutuhkan fitur di kerangka ini.
-- Remote lain (HeroUseSkill, Atk, dll) ditambahkan saat panel lain masuk.
RE = RE or {}
RE.CollectItem      = RE.CollectItem      or Remotes:WaitForChild("CollectItem", 10)
RE.ExtraReward      = RE.ExtraReward      or Remotes:WaitForChild("ExtraReward", 10)
RE.Click            = RE.Click            or Remotes:FindFirstChild("ClickEnemy")
RE.Atk              = RE.Atk              or Remotes:FindFirstChild("PlayerClickAttackSkill")
RE.Death            = RE.Death            or Remotes:FindFirstChild("EnemyDeath")
RE.HeroMove         = RE.HeroMove         or Remotes:FindFirstChild("HeroMoveToEnemyPos")
RE.HeroStand        = RE.HeroStand        or Remotes:FindFirstChild("HeroStandTo")
RE.HeroSkill        = RE.HeroSkill        or Remotes:FindFirstChild("HeroPlaySkillAnim")
RE.HeroUseSkill     = RE.HeroUseSkill     or Remotes:FindFirstChild("HeroUseSkill")
RE.StartTp          = RE.StartTp          or Remotes:FindFirstChild("StartLocalPlayerTeleport")
RE.LocalTp          = RE.LocalTp          or Remotes:FindFirstChild("LocalPlayerTeleport")
-- Hero Fastroll remotes
RE.RandomHeroQuirk  = RE.RandomHeroQuirk  or Remotes:WaitForChild("RandomHeroQuirk", 10)
RE.AutoHeroQuirk    = RE.AutoHeroQuirk    or Remotes:WaitForChild("AutoRandomHeroQuirk", 10)
-- Weapon Fastroll remotes
RE.RandomWeaponQuirk = RE.RandomWeaponQuirk or Remotes:WaitForChild("RandomWeaponQuirk", 10)
RE.AutoWeaponQuirk   = RE.AutoWeaponQuirk   or Remotes:WaitForChild("AutoRandomWeaponQuirk", 15)
-- Pet Gear Fastroll remotes (remote literal-nya bernama "RandomHeroEquipGrade" / "AutoRandomHeroEquipGrade"
-- meski dipakai untuk Pet Gear, bukan Hero - confirmed sniff 1.lua baris 460 & 3428)
RE.RandomPetGearGrade = RE.RandomPetGearGrade or Remotes:WaitForChild("RandomHeroEquipGrade", 10)
RE.AutoPetGearGrade    = RE.AutoPetGearGrade    or Remotes:WaitForChild("AutoRandomHeroEquipGrade", 15)
-- Halo Gacha remote (RemoteFunction)
RE.RerollHalo          = RE.RerollHalo          or Remotes:FindFirstChild("RerollHalo")
-- Ornament Roll remote (RemoteFunction)
RE.RerollOrnament      = RE.RerollOrnament      or Remotes:WaitForChild("RerollOrnament", 15)

--  LOAD WINDUI 
local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()

--  WINDOW (+ floating minimize bubble, sudah teruji OK) 
local Window = WindUI:CreateWindow({
    Title  = "Auto Farming ASH",
    Icon   = "sword",
    Theme  = "Dark",
    Folder = "premium_rejoin",

    OpenButton = {
        Title           = "FLa",
        CornerRadius    = UDim.new(0, 12),
        StrokeThickness = 2,
        Enabled         = true,
        Draggable       = true,
        OnlyMobile      = false,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0,    Color3.fromRGB(25, 45, 115)),
            ColorSequenceKeypoint.new(0.55, Color3.fromRGB(55, 105, 255)),
            ColorSequenceKeypoint.new(1,    Color3.fromRGB(90, 145, 255)),
        }),
    },

    --  Pengganti CreateUserProfile() (baris 1132-1172 source asli) 
    User = {
        Enabled   = true,
        Anonymous = false,
        Callback  = function() end,
    },
})

Window:SetToggleKey(Enum.KeyCode.LeftAlt)

-- ============================================================================
-- 11 TAB SESUAI URUTAN TERBARU
-- ============================================================================

local MainTab = Window:Tab({
    Title = "Main",
    Icon  = "home",
})

local HideTab = Window:Tab({
    Title = "Hide",
    Icon  = "eye-off",
})

local FarmTab = Window:Tab({
    Title = "Farm",
    Icon  = "sword",
})

local MassAttackTab = Window:Tab({
    Title = "Mass Attack",
    Icon  = "swords",
})

local AutomationTab = Window:Tab({
    Title = "Automation",
    Icon  = "bot",
})

local RerollTab = Window:Tab({
    Title = "Reroll",
    Icon  = "dices",
})

local PlayerTab = Window:Tab({
    Title = "Player",
    Icon  = "user",
})

local SettingTab = Window:Tab({
    Title = "Setting",
    Icon  = "settings",
})

local WebhookTab = Window:Tab({
    Title = "Webhook",
    Icon  = "send",
})

local ConfigTab = Window:Tab({
    Title = "Config",
    Icon  = "save",
})

local ThemeTab = Window:Tab({
    Title = "Theme",
    Icon  = "palette",
})

-- ============================================================================
-- PANEL: MAIN
-- COUNTER AUTO SELL HERO EQUIP + AUTO SELL HERO EQUIP
-- Dipindah dari PANEL: MAIN baris 3812 source premium
-- Ditulis ulang pakai WindUI native API (tidak ada helper C/Frame/Label/Btn premium)
-- ============================================================================
do
    --  Global expose (dibaca oleh Config panel saat save/load) 
    -- Sama persis dengan deklarasi source asli baris ~1715-1718
    _setSellHeroToggle = nil   -- setter logic toggle (fn(bool))
    _visSellHero       = nil   -- setter visual-only toggle (fn(bool))
    _autoSellOnState   = false -- tracking state untuk CollectConfig

    --  State lokal (scope do-block, tidak bocor keluar) 
    local _autoSellOn   = false
    local _sellConn     = nil
    local _lockedGuids  = {}
    local _cnt          = {R=0, Y=0, B=0, other=0, skipped=0}
    local _sellToggleCb = nil

    --  Helper update label counter 
    local _cntParagraph = nil  -- diisi setelah Paragraph dibuat di bawah
    local function RefreshCounters()
        if not _cntParagraph then return end
        pcall(function()
            _cntParagraph:SetDesc(
                "R: " .. _cnt.R ..
                "  |  Y: " .. _cnt.Y ..
                "  |  B: " .. _cnt.B ..
                "  |  Supreme skip: " .. _cnt.skipped
            )
        end)
    end

    --  Helper update status line 
    local _statusParagraph = nil  -- diisi setelah Paragraph dibuat di bawah
    local function SetSellStatus(msg)
        if not _statusParagraph then return end
        pcall(function()
            _statusParagraph:SetDesc(msg)
        end)
    end

    -- 
    --  SECTION: COUNTER AUTO SELL HERO EQUIP
    --  Source asli baris ~3931-3969
    -- 
    MainTab:Section({ Title = "Counter Auto Sell Hero Equip", Icon = "bar-chart-2" })

    -- Paragraph yang menampilkan angka R/Y/B/Supreme (diupdate via RefreshCounters)
    _cntParagraph = MainTab:Paragraph({
        Title = "Sold Count",
        Desc  = "R: 0  |  Y: 0  |  B: 0  |  Supreme skip: 0",
    })

    -- Tombol RESET COUNTER
    MainTab:Button({
        Title    = "RESET COUNTER",
        Desc     = "Reset semua angka counter ke 0",
        Callback = function()
            _cnt = {R=0, Y=0, B=0, other=0, skipped=0}
            RefreshCounters()
            SetSellStatus("[OK] DONE RESET")
        end,
    })

    -- 
    --  SECTION: AUTO SELL HERO EQUIP
    --  Source asli baris ~3971-4145
    -- 
    MainTab:Section({ Title = "Auto Sell Hero Equip", Icon = "package-minus" })

    -- Paragraph status (diupdate via SetSellStatus)
    _statusParagraph = MainTab:Paragraph({
        Title = "Status",
        Desc  = "Idle",
    })

    -- Toggle utama AUTO SELL HERO EQUIP
    -- Source asli baris ~3971-3978
    local _sellToggleElement = MainTab:Toggle({
        Flag     = "mainSellHero",
        Title    = "AUTO SELL HERO EQUIP",
        Desc     = "Auto sell all items (except Locked & Supreme)",
        Value    = false,
        Callback = function(on)
            _autoSellOn      = on
            _autoSellOnState = on
            if _sellToggleCb then _sellToggleCb(on) end
        end,
    })

    -- Expose ke global (dibaca Config panel saat restore)
    _setSellHeroToggle = function(v)
        if _sellToggleElement then
            _sellToggleElement:Set(v)   -- trigger Callback + update visual
        end
    end
    _visSellHero = function(v)
        if _sellToggleElement then
            _sellToggleElement:Set(v, false)  -- update visual only (false = silent)
        end
    end

    --  GUID name cache 
    -- Source asli baris ~3988-4012
    local _guidNames = {}
    local function scanGuidNames()
        pcall(function()
            local panel = PG:FindFirstChild("HeroEquipPanel")
            if not panel then return end
            for _, obj in ipairs(panel:GetDescendants()) do
                pcall(function()
                    if obj.Name == "NameText" and obj:IsA("TextLabel") and #obj.Text > 0 then
                        local itemName = obj.Text
                        local p2 = obj.Parent
                        for _ = 1, 8 do
                            if not p2 then break end
                            if p2:IsA("ImageButton") then
                                local n = p2.Name
                                if n:match("^%x+%-%x+%-%x+%-%x+%-%x+$") then
                                    _guidNames[n] = itemName; break
                                end
                            end
                            p2 = p2.Parent
                        end
                    end
                end)
            end
        end)
    end

    --  getType: R / Y / B / other dari karakter pertama nama item 
    -- Source asli baris ~4014-4022
    local function getType(name)
        if not name or #name == 0 then return "other" end
        local f = name:sub(1,1):upper()
        if f == "R" then return "R"
        elseif f == "Y" then return "Y"
        elseif f == "B" then return "B"
        else return "other" end
    end

    --  getGrade: parse grade dari data / nama item 
    -- Source asli baris ~4024-4038
    local function getGrade(item)
        local d = (item.data and type(item.data) == "table") and item.data or item
        local g = d.grade or d.Grade or d.gradeId or d.gradeType
        if g then return tostring(g):upper() end
        local name = item.name or item.Name or item.itemName or d.name or ""
        local found = name:match("%[M%+%+%]") and "M++"
                   or name:match("%[M%+%]")   and "M+"
                   or name:match("%[SS%]")     and "SS"
                   or name:match("%[([EDCBAGSNMedcbagsn])%]")
        if found then return found:upper() end
        return nil
    end

    --  shouldSell: filter lock / Supreme / tipe / grade 
    -- Source asli baris ~4040-4054 (dead code di source asli, tetap dibawa)
    local function shouldSell(item, name, isLock)
        if isLock then return false, "locked" end
        if name and name:lower():find("supreme", 1, true) then return false, "Supreme" end
        local typ = getType(name)
        if typ ~= "other" and not _sellTypes[typ] then return false, "tipe " .. typ .. " dimatikan" end
        local grade = getGrade(item)
        if grade then
            local itemRank = _SELL_GRADE_RANK[grade] or 0
            local minRank  = _SELL_GRADE_RANK[_minGrade] or 1
            if itemRank >= minRank then return false, "grade " .. grade .. " >= min " .. _minGrade end
        end
        return true, ""
    end

    --  doSell: fire remote + update counter 
    -- Source asli baris ~4058-4068 (dead code di source asli, tetap dibawa)
    local function doSell(guid, name)
        local remote = Remotes:FindFirstChild("DelectHeroEquips")
        if not remote then return end
        pcall(function()
            remote:FireServer({guid})
            local prefix = getType(name)
            _cnt[prefix] = (_cnt[prefix] or 0) + 1
            RefreshCounters()
            SetSellStatus(
                "Sold [" .. (_cnt.R + _cnt.Y + _cnt.B + _cnt.other) .. "] " .. name:sub(1,24)
            )
        end)
    end

    --  StartAutoSell: attach listener ke UpdateHeroEquip 
    -- Source asli baris ~4071-4136
    local function StartAutoSell()
        if _sellConn then pcall(function() _sellConn:Disconnect() end) end

        local updateRemote = Remotes:FindFirstChild("UpdateHeroEquip")
        if not updateRemote then
            SetSellStatus("[!] Remote UpdateHeroEquip NOT FOUND!")
            return
        end

        scanGuidNames()

        -- Pantau Lock / Unlock agar item locked tidak ikut terjual
        pcall(function()
            local lockR   = Remotes:FindFirstChild("LockHeroEquip")
            local unlockR = Remotes:FindFirstChild("UnlockHeroEquip")
            if lockR then
                lockR.OnClientEvent:Connect(function(d)
                    local g = type(d) == "string" and d
                          or (type(d) == "table" and (d.guid or d[1]))
                          or nil
                    if g then _lockedGuids[g] = true end
                end)
            end
            if unlockR then
                unlockR.OnClientEvent:Connect(function(d)
                    local g = type(d) == "string" and d
                          or (type(d) == "table" and (d.guid or d[1]))
                          or nil
                    if g then _lockedGuids[g] = nil end
                end)
            end
        end)

        _sellConn = updateRemote.OnClientEvent:Connect(function(data)
            if not _autoSellOn then return end
            if type(data) ~= "table" then return end
            task.spawn(function()
                task.wait(0.3)
                -- [v186] Struktur confirmed dari sniff:
                -- item = { guid="...", data = { id=970002, isLock=bool, grade=990001, guid="..." } }
                local items = {}
                if data.heroEquips and type(data.heroEquips) == "table" then
                    items = data.heroEquips
                elseif data[1] and type(data[1]) == "table" then
                    items = data
                elseif data.guid then
                    items = {data}
                end

                for _, item in ipairs(items) do
                    if not _autoSellOn then break end

                    local guid = item.guid
                    if guid and #tostring(guid) > 0 then
                        local d      = (item.data and type(item.data) == "table") and item.data or item
                        local isLock = d.isLock or d.locked or d.isLocked or false
                        if _lockedGuids[tostring(guid)] then isLock = true end

                        if not isLock then
                            scanGuidNames()
                            local name   = _guidNames[tostring(guid)] or ""
                            local prefix = getType(name)

                            task.wait(0.15)
                            local remote = Remotes:FindFirstChild("DelectHeroEquips")
                            if remote then
                                local ok = pcall(function() remote:FireServer({tostring(guid)}) end)
                                if ok then
                                    _cnt[prefix] = (_cnt[prefix] or 0) + 1
                                    RefreshCounters()
                                    local total = _cnt.R + _cnt.Y + _cnt.B + _cnt.other
                                    local label = #name > 0 and name:sub(1,20)
                                              or ("ID:" .. tostring(d.id or "?"))
                                    SetSellStatus(
                                        "Sold [" .. total .. "] " .. prefix .. ": " .. label
                                    )
                                end
                            end
                        end
                    end
                end
                task.delay(0.5, scanGuidNames)
            end)
        end)

        SetSellStatus("[OK] Monitoring Active - Sell All except Locked")
    end

    --  Callback toggle ON/OFF 
    -- Source asli baris ~4138-4145
    _sellToggleCb = function(on)
        if on then
            StartAutoSell()
        else
            if _sellConn then
                pcall(function() _sellConn:Disconnect() end)
                _sellConn = nil
            end
            local total = _cnt.R + _cnt.Y + _cnt.B + _cnt.other
            SetSellStatus("Idle - " .. total .. " item terjual")
        end
    end

end -- end do PANEL: MAIN (Counter + Auto Sell Hero Equip)

-- ============================================================================
-- TAB LAINNYA - placeholder (belum diisi fungsi)
-- FarmTab, MassAttackTab, AutomationTab, RerollTab,
-- PlayerTab, SettingTab, WebhookTab, ConfigTab, ThemeTab
-- -> diisi sesuai urutan pengisian selanjutnya
-- ============================================================================

-- ============================================================================
-- PANEL: HIDE
-- Dipindah dari baris ~5171 source premium
-- Ditulis ulang pakai WindUI native API
-- Perbedaan API vs source asli:
--   Source asli: NewPanel("hide") + ToggleRow custom
--   WindUI:      HideTab:Section() + HideTab:Toggle() + HideTab:Paragraph()
-- Global expose:
--   _hideRerollChatState, _setHideRerollChat, _visHideRerollChat
--   _hideAllUIState,      _setHideAllUI,      _visHideAllUI
--   _hideAllAnimState,    _setHideAllAnim,     _visHideAllAnim
--   _hideRewardState,     _setHideReward,      _visHideRewardPanel
-- ============================================================================
do
    -- Global expose state tracking (dibaca Config panel saat save/load)
    -- Sama persis dengan deklarasi source asli baris ~1787-1789
    _hideRerollChatState = false
    _hideAllUIState      = false
    _hideAllAnimState    = false
    _hideRewardState     = false

    -- Global expose setters/vis (diisi setelah Toggle dibuat)
    -- Sama persis dengan deklarasi source asli baris ~1767-1772, ~1743-1744
    _setHideRerollChat  = nil
    _visHideRerollChat  = nil
    _setHideAllUI       = nil
    _visHideAllUI       = nil
    _setHideAllAnim     = nil
    _visHideAllAnim     = nil
    _setHideReward      = nil
    _visHideRewardPanel = nil

    -- State internal
    local _hideRerollOn = false
    local _hideUIOn     = false
    local _hideAnimOn   = false
    local _hideRewardOn = false

    local _rerollConn  = nil
    local _animLoop    = nil
    local _animWsConn  = nil
    local _uiAddConn   = nil

    -- Cache untuk restore
    local _rerollHidden = {}  -- [Frame baris] = true
    local _uiCache      = {}  -- [obj] = state sebelum hide
    local _animBbCache  = {}
    local _animPcCache  = {}

    -- Nama GUI kita sendiri - dikecualikan dari HIDE ALL UI (source asli ~5189)
    local _OUR_GUI = "ASH_NightFrost"

    -- ============================================================
    -- 1. HIDE REROLL CHAT  (source asli baris ~5199-5292)
    -- Struktur ExperienceChat:
    --   ScrollingFrame[scrollView]
    --     Frame[0-{uuid}]    <-- satu baris chat (INI yang di-hide)
    --       Frame[TextMessage]
    --         TextLabel[BodyText]  <-- teks "... just reroll a ..."
    -- ============================================================

    local function isRerollText(t)
        t = (t or ""):gsub("<[^>]+>", ""):lower()
        return t:find("reroll a", 1, true) ~= nil
    end

    -- Naik 2 level: BodyText -> Frame[TextMessage] -> Frame[0-{uuid}] = baris chat
    local function getRowFrame(lbl)
        local p1 = lbl.Parent
        if not p1 then return lbl end
        local p2 = p1.Parent
        if not p2 then return p1 end
        if p2:IsA("ScrollingFrame") then return p1 end
        return p2
    end

    local function hideRow(row)
        if row and row.Parent and not _rerollHidden[row] then
            row.Visible = false
            _rerollHidden[row] = true
        end
    end

    local function scanAndHideReroll()
        pcall(function()
            local ec = game:GetService("CoreGui"):FindFirstChild("ExperienceChat")
            if not ec then return end
            for _, obj in ipairs(ec:GetDescendants()) do
                if obj.Name == "BodyText" and (obj:IsA("TextLabel") or obj:IsA("TextButton")) then
                    if isRerollText(obj.Text) then hideRow(getRowFrame(obj)) end
                end
            end
        end)
    end

    local function ApplyHideReroll(on)
        _hideRerollChatState = on
        _hideRerollOn        = on
        if _rerollConn then _rerollConn:Disconnect(); _rerollConn = nil end

        if on then
            scanAndHideReroll()
            pcall(function()
                local CG2 = game:GetService("CoreGui")
                local ec   = CG2:FindFirstChild("ExperienceChat")
                if not ec then ec = CG2:WaitForChild("ExperienceChat", 10) end
                if not ec then return end
                _rerollConn = ec.DescendantAdded:Connect(function(obj)
                    task.delay(0.2, function()
                        pcall(function()
                            if not _hideRerollOn then return end
                            if obj.Name == "BodyText" and (obj:IsA("TextLabel") or obj:IsA("TextButton")) then
                                if isRerollText(obj.Text) then hideRow(getRowFrame(obj)) end
                            end
                        end)
                    end)
                end)
            end)
        else
            for row in pairs(_rerollHidden) do
                pcall(function() if row and row.Parent then row.Visible = true end end)
            end
            _rerollHidden = {}
        end
    end

    -- ============================================================
    -- 2. HIDE ALL UI  (source asli baris ~5294-5373)
    -- ============================================================

    local function ApplyHideUI(on)
        _hideAllUIState = on
        _hideUIOn       = on
        if _uiAddConn then _uiAddConn:Disconnect(); _uiAddConn = nil end

        if on then
            _uiCache = {}
            pcall(function()
                for _, gui in ipairs(PG:GetChildren()) do
                    pcall(function()
                        if gui.Name == _OUR_GUI then return end
                        if gui:IsA("ScreenGui") or gui:IsA("GuiBase2d") then
                            _uiCache[gui] = gui.Enabled
                            gui.Enabled   = false
                        elseif gui:IsA("GuiObject") then
                            _uiCache[gui] = gui.Visible
                            gui.Visible   = false
                        end
                    end)
                end
            end)

            -- [FIX SIEGE] Panel Siege wajib dikecualikan dari hide
            local _SIEGE_PANEL_KW = {
                "cityraid","city_raid","garrisoncityraid","garrisonboss",
                "siege","cityraidpanel","cityraidenterpanel",
                "raidcityresult","garrisonraidresult","citycount","citytimer",
            }
            local function _isSiegePanelGui(gui)
                if not (SIEGE and SIEGE.inMap) then return false end
                local n = gui.Name:lower()
                for _, kw in ipairs(_SIEGE_PANEL_KW) do
                    if n:find(kw, 1, true) then return true end
                end
                return false
            end

            _uiAddConn = PG.ChildAdded:Connect(function(gui)
                task.defer(function()
                    pcall(function()
                        if not _hideUIOn then return end
                        if gui.Name == _OUR_GUI then return end
                        if _isSiegePanelGui(gui) then return end
                        if gui:IsA("ScreenGui") or gui:IsA("GuiBase2d") then
                            _uiCache[gui] = gui.Enabled
                            gui.Enabled   = false
                        elseif gui:IsA("GuiObject") then
                            _uiCache[gui] = gui.Visible
                            gui.Visible   = false
                        end
                    end)
                end)
            end)
        else
            if _uiAddConn then _uiAddConn:Disconnect(); _uiAddConn = nil end
            for obj, prev in pairs(_uiCache) do
                pcall(function()
                    if obj and obj.Parent then
                        if obj:IsA("ScreenGui") or obj:IsA("GuiBase2d") then
                            obj.Enabled = prev
                        elseif obj:IsA("GuiObject") then
                            obj.Visible = prev
                        end
                    end
                end)
            end
            _uiCache = {}
        end
    end

    -- ============================================================
    -- 3. HIDE ALL ANIMATION (versi penuh, restore sempurna)
    -- Source asli baris ~5375-5496
    -- ============================================================

    local function ApplyHideAnim(on)
        _hideAllAnimState = on
        _hideAnimOn       = on

        if on then
            _animBbCache = {}
            _animPcCache = {}
            if _animLoop then _animLoop:Disconnect(); _animLoop = nil end

            -- Stop animation tracks via RenderStepped (throttle 0.5s - FLa CPU)
            local _animLoop2LastT = 0
            _animLoop = game:GetService("RunService").RenderStepped:Connect(function()
                local _now2 = tick()
                if (_now2 - _animLoop2LastT) < 0.5 then return end
                _animLoop2LastT = _now2
                pcall(function()
                    for _, fname in ipairs({"Heros","Pets","Characters"}) do
                        local folder = workspace:FindFirstChild(fname)
                        if folder then
                            for _, char in ipairs(folder:GetChildren()) do
                                local hum = char:FindFirstChildOfClass("Humanoid")
                                         or char:FindFirstChildOfClass("AnimationController")
                                if hum then
                                    local anim = hum:FindFirstChildOfClass("Animator")
                                    if anim then
                                        for _, track in ipairs(anim:GetPlayingAnimationTracks()) do
                                            track:AdjustSpeed(0)
                                        end
                                    end
                                end
                            end
                        end
                    end
                end)
            end)

            -- Matikan efek di workspace + cache state awal
            pcall(function()
                for _, obj in ipairs(workspace:GetDescendants()) do
                    pcall(function()
                        if obj:IsA("BillboardGui") then
                            local n = obj.Name:lower()
                            if not n:find("name") and not n:find("health") and not n:find("tag") then
                                _animBbCache[obj] = obj.Enabled
                                obj.Enabled = false
                            end
                        elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam")
                            or obj:IsA("PointLight") or obj:IsA("Fire") or obj:IsA("Sparkles") then
                            _animPcCache[obj] = obj.Enabled
                            obj.Enabled = false
                        end
                    end)
                end
            end)

            -- Watch objek efek baru yang spawn
            if _animWsConn then _animWsConn:Disconnect(); _animWsConn = nil end
            _animWsConn = workspace.DescendantAdded:Connect(function(obj)
                task.defer(function()
                    pcall(function()
                        if not _hideAnimOn then return end
                        if obj:IsA("BillboardGui") then
                            local n = obj.Name:lower()
                            if not n:find("name") and not n:find("health") and not n:find("tag") then
                                _animBbCache[obj] = obj.Enabled; obj.Enabled = false
                            end
                        elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam")
                            or obj:IsA("PointLight") or obj:IsA("Fire") or obj:IsA("Sparkles") then
                            _animPcCache[obj] = obj.Enabled; obj.Enabled = false
                        end
                    end)
                end)
            end)

        else
            -- RESTORE PENUH
            if _animLoop   then _animLoop:Disconnect();   _animLoop   = nil end
            if _animWsConn then _animWsConn:Disconnect(); _animWsConn = nil end

            -- Resume semua animation track
            pcall(function()
                for _, fname in ipairs({"Heros","Pets","Characters"}) do
                    local folder = workspace:FindFirstChild(fname)
                    if folder then
                        for _, char in ipairs(folder:GetChildren()) do
                            local hum = char:FindFirstChildOfClass("Humanoid")
                                     or char:FindFirstChildOfClass("AnimationController")
                            if hum then
                                local anim = hum:FindFirstChildOfClass("Animator")
                                if anim then
                                    for _, track in ipairs(anim:GetPlayingAnimationTracks()) do
                                        pcall(function() track:AdjustSpeed(1) end)
                                    end
                                end
                            end
                        end
                    end
                end
            end)

            for obj, prev in pairs(_animBbCache) do
                pcall(function() if obj and obj.Parent then obj.Enabled = prev end end)
            end
            _animBbCache = {}

            for obj, prev in pairs(_animPcCache) do
                pcall(function() if obj and obj.Parent then obj.Enabled = prev end end)
            end
            _animPcCache = {}
        end
    end

    -- ============================================================
    -- 4. AUTO HIDE REWARD  (source asli baris ~5498-5567)
    -- ============================================================

    local function ApplyHideReward(on)
        _hideRewardState = on
        _hideRewardOn    = on

        if on then
            local HIDE_PANELS = {"RewardsFrame","ResultFrame","RewardPanel","ChallengeGarrisonBossSuccess"}

            local function forceHide(obj)
                if not obj or not obj.Parent then return end
                pcall(function()
                    if obj:IsA("GuiObject") then
                        obj.Visible  = false
                        obj.Position = UDim2.new(2, 0, 2, 0)
                    elseif obj:IsA("ScreenGui") then
                        obj.Enabled = false
                    end
                end)
            end

            local function checkAndHide(obj)
                if not _hideRewardOn then return end
                if not (obj:IsA("GuiObject") or obj:IsA("ScreenGui")) then return end
                for _, name in ipairs(HIDE_PANELS) do
                    if obj.Name == name or obj.Name:find("GarrisonBoss") then
                        if _hideRewardOn then forceHide(obj) end
                        pcall(function()
                            if obj:IsA("GuiObject") then
                                obj:GetPropertyChangedSignal("Visible"):Connect(function()
                                    if _hideRewardOn and obj.Visible then forceHide(obj) end
                                end)
                            elseif obj:IsA("ScreenGui") then
                                obj:GetPropertyChangedSignal("Enabled"):Connect(function()
                                    if _hideRewardOn and obj.Enabled then forceHide(obj) end
                                end)
                            end
                        end)
                        break
                    end
                end
            end

            for _, obj in ipairs(LP.PlayerGui:GetDescendants()) do checkAndHide(obj) end

            -- Ghost polling loop
            task.spawn(function()
                while _hideRewardOn do
                    task.wait(0.5)
                    pcall(function()
                        for _, obj in ipairs(LP.PlayerGui:GetChildren()) do
                            for _, name in ipairs(HIDE_PANELS) do
                                if obj.Name == name or obj.Name:find("GarrisonBoss") then
                                    forceHide(obj)
                                end
                            end
                        end
                    end)
                end
            end)
        end
    end

    -- ============================================================
    -- WINDUI UI ELEMENTS
    -- ============================================================

    HideTab:Section({ Title = "Hide Manager", Icon = "eye-off" })

    HideTab:Paragraph({
        Title = "Hide Manager",
        Desc  = "Sembunyikan elemen game. Toggle OFF untuk restore penuh.",
    })

    -- 1. HIDE REROLL CHAT
    HideTab:Section({ Title = "Hide Reroll Chat", Icon = "message-square-off" })

    local _hrcrToggle = HideTab:Toggle({
        Flag     = "hideRerollChat",
        Title    = "HIDE REROLL CHAT",
        Desc     = "Sembunyikan baris chat 'just reroll a...' tanpa menghilangkan chat box",
        Value    = false,
        Callback = function(on) ApplyHideReroll(on) end,
    })
    _setHideRerollChat = function(v)
        ApplyHideReroll(v)
        if _hrcrToggle then pcall(function() _hrcrToggle:Set(v) end) end
    end
    _visHideRerollChat = function(v)
        if _hrcrToggle then pcall(function() _hrcrToggle:Set(v, false) end) end
    end

    -- 2. HIDE ALL UI
    HideTab:Section({ Title = "Hide All UI", Icon = "layout-dashboard" })

    local _hauiToggle = HideTab:Toggle({
        Flag     = "hideAllUI",
        Title    = "HIDE ALL UI",
        Desc     = "Sembunyikan semua panel game. Toggle OFF restore penuh.",
        Value    = false,
        Callback = function(on) ApplyHideUI(on) end,
    })
    _setHideAllUI = function(v)
        ApplyHideUI(v)
        if _hauiToggle then pcall(function() _hauiToggle:Set(v) end) end
    end
    _visHideAllUI = function(v)
        if _hauiToggle then pcall(function() _hauiToggle:Set(v, false) end) end
    end

    -- 3. HIDE ALL ANIMATION
    HideTab:Section({ Title = "Hide All Animation", Icon = "zap-off" })

    local _hanimToggle = HideTab:Toggle({
        Flag     = "hideAllAnim",
        Title    = "HIDE ALL ANIMATION",
        Desc     = "Matikan animasi, efek, partikel. Restore penuh saat OFF.",
        Value    = false,
        Callback = function(on) ApplyHideAnim(on) end,
    })
    _setHideAllAnim = function(v)
        ApplyHideAnim(v)
        if _hanimToggle then pcall(function() _hanimToggle:Set(v) end) end
    end
    _visHideAllAnim = function(v)
        if _hanimToggle then pcall(function() _hanimToggle:Set(v, false) end) end
    end

    -- 4. AUTO HIDE REWARD
    HideTab:Section({ Title = "Auto Hide Reward", Icon = "gift" })

    local _hrewToggle = HideTab:Toggle({
        Flag     = "hideReward",
        Title    = "AUTO HIDE REWARD",
        Desc     = "Sembunyikan popup reward otomatis.",
        Value    = false,
        Callback = function(on) ApplyHideReward(on) end,
    })
    _setHideReward = function(v)
        ApplyHideReward(v)
        if _hrewToggle then pcall(function() _hrewToggle:Set(v) end) end
    end
    _visHideRewardPanel = function(v)
        if _hrewToggle then pcall(function() _hrewToggle:Set(v, false) end) end
    end

end -- end do PANEL: HIDE


-- ============================================================================
-- PANEL: MAIN (lanjutan)
-- AUTO COLLECT GOLD & ITEM
-- Dipindah dari baris ~5150 source premium
-- Ditulis ulang pakai WindUI native API
-- Dependency chain (semua dari source 1.lua):
--   _collectObj, _instantCollectConns, _instantCollected  (~baris 483-509)
--   StartInstantGoldCollector                              (~baris 511-573)
--   _goldMagnetRunning, StartGoldMagnet, StopGoldMagnet   (~baris 2420-2469)
--   DoAutoCollect                                          (~baris 2720-2748)
--   DoAutoCollectGoldItem                                  (~baris 2473-2485)
-- Global expose: _setAutoCollectToggle, _visAutoCollect, _autoCollectState
-- ============================================================================
do
    --  Global expose (dibaca Config panel saat save/load) 
    -- Sama persis dengan deklarasi source asli baris ~1713, ~1745, ~1794
    _setAutoCollectToggle = nil   -- setter logic toggle (fn(bool))
    _visAutoCollect       = nil   -- setter visual-only toggle (fn(bool))
    _autoCollectState     = false -- tracking state untuk CollectConfig

    -- 
    --  INSTANT COLLECTOR - STATE VARS
    --  Source asli baris ~483-484
    -- 
    local _instantCollectConns = {}
    local _instantCollected    = {}

    -- 
    --  _collectObj: TP obj ke player lalu fire CollectItem + ExtraReward
    --  Source asli baris ~486-509
    -- 
    local function _collectObj(obj)
        local guid = obj:GetAttribute("GUID") or obj:GetAttribute("Guid") or obj:GetAttribute("guid")
        if not guid or _instantCollected[guid] then return end
        _instantCollected[guid] = true
        -- Teleport langsung ke player sebelum collect
        pcall(function()
            local char = LP.Character
            local hrp  = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local pos = hrp.Position
                if obj:IsA("BasePart") then
                    obj.CFrame = CFrame.new(pos)
                elseif obj:IsA("Model") then
                    local part = obj:FindFirstChildWhichIsA("BasePart") or obj.PrimaryPart
                    if part then part.CFrame = CFrame.new(pos) end
                end
            end
        end)
        -- Fire collect remote (RemoteFunction -> InvokeServer)
        pcall(function() RE.CollectItem:InvokeServer(guid) end)
        if RE.ExtraReward then
            pcall(function() RE.ExtraReward:FireServer({isSell=true, guid=guid}) end)
        end
    end

    -- 
    --  StartInstantGoldCollector: listen ChildAdded per folder drop
    --  Source asli baris ~511-573
    -- 
    local function StartInstantGoldCollector(on)
        -- Putuskan semua koneksi lama
        for _, c in ipairs(_instantCollectConns) do pcall(function() c:Disconnect() end) end
        _instantCollectConns = {}
        _instantCollected    = {}

        if not on then return end

        local DROP_FOLDERS = {"Golds","Items","Drops","Rewards","Loot","DropItems","RewardItems"}

        for _, folderName in ipairs(DROP_FOLDERS) do
            -- Tunggu folder muncul atau sudah ada
            task.spawn(function()
                local folder = workspace:FindFirstChild(folderName)
                            or workspace:WaitForChild(folderName, 5)
                if not folder then return end

                -- Collect semua yang sudah ada di folder (batch, tanpa delay)
                for _, obj in ipairs(folder:GetChildren()) do
                    _collectObj(obj)
                end

                -- Listen ChildAdded di folder (BUKAN di workspace)
                local conn = folder.ChildAdded:Connect(function(obj)
                    -- Tidak ada task.wait / task.delay - langsung collect
                    _collectObj(obj)
                end)
                table.insert(_instantCollectConns, conn)
            end)
        end

        -- Juga pantau folder baru yang mungkin muncul nanti di workspace
        local wsConn = workspace.ChildAdded:Connect(function(obj)
            for _, fn in ipairs(DROP_FOLDERS) do
                if obj.Name == fn then
                    task.spawn(function()
                        task.wait(0.05)
                        -- Batch collect isi folder baru
                        for _, child in ipairs(obj:GetChildren()) do
                            _collectObj(child)
                        end
                        -- Connect ChildAdded ke folder baru
                        local c2 = obj.ChildAdded:Connect(function(item)
                            _collectObj(item)
                        end)
                        table.insert(_instantCollectConns, c2)
                    end)
                    break
                end
            end
        end)
        table.insert(_instantCollectConns, wsConn)
    end

    -- 
    --  GOLD MAGNET - loop TP semua item di folder ke posisi player tiap 0.05s
    --  Source asli baris ~2420-2469
    -- 
    local _goldMagnetRunning = false

    local function StartGoldMagnet(checkFn)
        if _goldMagnetRunning then return end
        _goldMagnetRunning = true
        task.spawn(function()
            local GOLD_FOLDERS = {"Golds","Items","Drops","Rewards","Loot","DropItems","RewardItems"}
            while _goldMagnetRunning do
                local shouldRun = (checkFn == nil) or checkFn()
                if not shouldRun then
                    _goldMagnetRunning = false
                    break
                end
                pcall(function()
                    local char = LP.Character
                    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
                    if not hrp then return end
                    local playerPos = hrp.Position
                    for _, folderName in ipairs(GOLD_FOLDERS) do
                        local folder = workspace:FindFirstChild(folderName)
                        if folder then
                            for _, obj in ipairs(folder:GetChildren()) do
                                pcall(function()
                                    -- TP langsung ke player (no random offset agar pasti ke-collect)
                                    if obj:IsA("BasePart") then
                                        obj.CFrame = CFrame.new(playerPos)
                                    elseif obj:IsA("Model") then
                                        local part = obj:FindFirstChildWhichIsA("BasePart") or obj.PrimaryPart
                                        if part then part.CFrame = CFrame.new(playerPos) end
                                    end
                                    -- Fire collect
                                    local guid = obj:GetAttribute("GUID") or obj:GetAttribute("Guid") or obj:GetAttribute("guid")
                                    if guid then
                                        pcall(function() RE.CollectItem:InvokeServer(guid) end)
                                        if RE.ExtraReward then
                                            pcall(function() RE.ExtraReward:FireServer({isSell=true, guid=guid}) end)
                                        end
                                    end
                                end)
                            end
                        end
                    end
                end)
                PG_Wait(0.05) -- [PingGuard] adaptive throttle (base 0.05s)
            end
            _goldMagnetRunning = false
        end)
    end

    local function StopGoldMagnet()
        _goldMagnetRunning = false
    end

    -- 
    --  DoAutoCollect: polling loop collect via StartLoop/StopLoop
    --  Source asli baris ~2720-2748
    -- 
    local function DoAutoCollect(on)
        StopLoop("collect"); COLLECTED = {}
        if not on then return end
        local _COL_FOLDERS = {"Golds","Items","Drops","Rewards","Loot","DropItems","RewardItems"}
        StartLoop("collect", function()
            while STATE.autoCollect do
                for _, folderName in ipairs(_COL_FOLDERS) do
                    if not STATE.autoCollect then break end
                    local folder = workspace:FindFirstChild(folderName)
                    if folder then
                        for _, obj in ipairs(folder:GetChildren()) do
                            if not STATE.autoCollect then break end
                            local guid = obj:GetAttribute("GUID")
                            if guid and not COLLECTED[guid] then
                                COLLECTED[guid] = true
                                pcall(function() RE.CollectItem:InvokeServer(guid) end)
                                -- [v112-FIX] Nil guard ExtraReward
                                if RE.ExtraReward then
                                    pcall(function() RE.ExtraReward:FireServer({isSell=true, guid=guid}) end)
                                end
                                PG_Wait(0.03) -- [PingGuard] collect item
                            end
                        end
                    end
                end
                PG_Wait(0.2) -- [PingGuard] collect poll outer
            end
        end)
    end

    -- 
    --  DoAutoCollectGoldItem: master toggle - panggil semua collector
    --  Source asli baris ~2473-2485
    -- 
    local function DoAutoCollectGoldItem(on)
        STATE.autoCollectGoldItem = on
        if on then
            StartInstantGoldCollector(true)
            StartGoldMagnet(function() return STATE.autoCollectGoldItem end)
            STATE.autoCollect = true
            DoAutoCollect(true)
        else
            StartInstantGoldCollector(false)
            StopGoldMagnet()
            STATE.autoCollect = false
            StopLoop("collect")
        end
    end

    -- 
    --  SECTION: AUTO COLLECT GOLD & ITEM (WindUI)
    --  Source asli baris ~5150-5163
    -- 
    MainTab:Section({ Title = "Auto Collect Gold & Item", Icon = "coins" })

    local _collectToggleElement = MainTab:Toggle({
        Flag     = "mainCollect",
        Title    = "AUTO COLLECT GOLD & ITEM",
        Desc     = "TP & collect semua gold/item ke player",
        Value    = false,
        Callback = function(on)
            _autoCollectState = on
            DoAutoCollectGoldItem(on)
        end,
    })

    -- Expose ke global (dibaca Config panel saat restore)
    _setAutoCollectToggle = function(v)
        if _collectToggleElement then
            _collectToggleElement:Set(v)  -- trigger Callback + update visual
        end
    end
    _visAutoCollect = function(v)
        if _collectToggleElement then
            _collectToggleElement:Set(v, false)  -- update visual only (false = silent)
        end
    end

end -- end do PANEL: MAIN (Auto Collect Gold & Item)

-- ============================================================================
-- PANEL: MAIN (lanjutan)
-- AUTO DECOMPOSE GEMS
-- Dipindah dari baris ~4762 source premium
-- Ditulis ulang pakai WindUI native API
-- Perbedaan API vs source asli:
--   Source asli: Frame/Btn/Label/Pill + TextBox input custom
--   WindUI:      Toggle + Input (min) + Input (max) + Paragraph status
-- Global expose: _autoDecompGemSet, _visDecompGem, _autoDecompGemState,
--                _setGemLevelRange, _gemMinLevelState, _gemMaxLevelState
-- ============================================================================
do
    --  Global expose (dibaca Config panel saat save/load) 
    -- Sama persis dengan deklarasi source asli baris ~1720-1763
    _autoDecompGemSet  = nil   -- setter logic toggle (fn(bool))
    _visDecompGem      = nil   -- setter visual-only toggle (fn(bool))
    _autoDecompGemState = false -- tracking state untuk Config
    _setGemLevelRange  = nil   -- setter level range (fn(min,max))
    _gemMinLevelState  = 1     -- tracking min level untuk Config
    _gemMaxLevelState  = 1     -- tracking max level untuk Config

    --  State internal
    local _autoDecompGemOn     = false
    local _autoDecompGemThread = nil
    local GEM_ITEM_TYPE        = 7
    local _gemMinLevel         = 1
    local _gemMaxLevel         = 1

    --  GEM_ID_RANGES: tabel itemId gem berdasarkan nama dan level
    -- Source asli baris ~4772-4808
    -- Format: {startId, endId, minLevel, maxLevel, displayName}
    local GEM_ID_RANGES = {
        {88001, 88009,  1,  9, "Ruby"},
        {88011, 88019,  1,  9, "Emerald"},
        {88021, 88029,  1,  9, "Sapphire"},
        {88031, 88039,  1,  9, "Deadly Gem"},
        {88141, 88149,  1,  9, "Purple Gem"},
        -- Lv10
        {88010, 88010, 10, 10, "Ruby"},
        {88061, 88070, 11, 20, "Ruby"},
        {88020, 88020, 10, 10, "Emerald"},
        {88071, 88080, 11, 20, "Emerald"},
        {88030, 88030, 10, 10, "Sapphire"},
        {88081, 88090, 11, 20, "Sapphire"},
        {88040, 88040, 10, 10, "Deadly Gem"},
        {88091, 88100, 11, 20, "Deadly Gem"},
        {88150, 88150, 10, 10, "Purple Gem"},
        {88151, 88160, 11, 20, "Purple Gem"},
        -- Lv21-30
        {88171, 88180, 21, 30, "Ruby"},
        {88181, 88190, 21, 30, "Emerald"},
        {88191, 88200, 21, 30, "Sapphire"},
        -- Colorful Gem: game Level 101-109 = user level 1-9
        {88041, 88049,  1,  9, "Colorful Gem"},
        {88050, 88050, 10, 10, "Colorful Gem"},
        {88101, 88110, 11, 20, "Colorful Gem"},
        -- Rainbow Gem: game Level 101-109 = user level 1-9
        {88051, 88059,  1,  9, "Rainbow Gem"},
        {88060, 88060, 10, 10, "Rainbow Gem"},
        {88111, 88120, 11, 20, "Rainbow Gem"},
    }

    -- Build lookup: itemId -> userLevel
    -- Source asli baris ~4810-4816
    local GEM_ID_TO_LEVEL = {}
    for _, r in ipairs(GEM_ID_RANGES) do
        local startId, endId, minLv = r[1], r[2], r[3]
        for id = startId, endId do
            GEM_ID_TO_LEVEL[id] = minLv + (id - startId)
        end
    end

    -- IsGemIdToDecomp: cek apakah itemId masuk range min-max level
    -- Source asli baris ~4820-4823
    local function IsGemIdToDecomp(itemId, minLv, maxLv)
        local lv = GEM_ID_TO_LEVEL[itemId]
        if not lv then return false end
        return lv >= minLv and lv <= maxLv
    end

    --  SetDGStatus: update paragraph status
    local _dgStatusParagraph = nil
    local function SetDGStatus(msg)
        if not _dgStatusParagraph then return end
        pcall(function() _dgStatusParagraph:SetDesc(msg) end)
    end

    --  SetDGLevelRange: update state + visual Input WindUI
    -- Source asli baris ~4878-4892
    local _dgMinInputElement = nil
    local _dgMaxInputElement = nil
    local function SetDGLevelRange(minLv, maxLv)
        _gemMinLevel      = minLv or 1
        _gemMaxLevel      = maxLv or 1
        _gemMinLevelState = _gemMinLevel
        _gemMaxLevelState = _gemMaxLevel
        -- Update visual WindUI Input
        if _dgMinInputElement then
            pcall(function() _dgMinInputElement:Set(tostring(_gemMinLevel)) end)
        end
        if _dgMaxInputElement then
            pcall(function() _dgMaxInputElement:Set(tostring(_gemMaxLevel)) end)
        end
    end

    --  GetGemGuidsFromPanel: scan GemsPanel, filter berdasarkan itemId / Lv text
    -- Source asli baris ~4929-4994
    local function GetGemGuidsFromPanel(minLv, maxLv)
        local result = {}
        pcall(function()
            local pg = LP.PlayerGui
            local gp = pg:FindFirstChild("GemsPanel")
            if not gp then return end

            -- Cari ScrollingFrame container gem
            local sf = nil
            pcall(function()
                sf = gp:FindFirstChild("Frame")
                    :FindFirstChild("BgImage")
                    :FindFirstChild("List")
                    :FindFirstChild("ScrollingFrame")
            end)
            if not sf then
                for _, obj in ipairs(gp:GetDescendants()) do
                    if obj:IsA("ScrollingFrame") then sf = obj; break end
                end
            end
            if not sf then return end

            for _, child in ipairs(sf:GetChildren()) do
                repeat
                    local guidStr = child.Name
                    -- Hanya proses child dengan nama UUID
                    if #guidStr ~= 36 or not guidStr:find("^%x+%-%x+%-%x+%-%x+%-%x+$") then break end

                    -- Sumber 1: attribute langsung di child
                    local itemId = child:GetAttribute("itemId") or child:GetAttribute("ItemId")
                                or child:GetAttribute("id")     or child:GetAttribute("Id")
                                or child:GetAttribute("item_id")

                    -- Sumber 2: scan descendants
                    if not itemId then
                        for _, c in ipairs(child:GetDescendants()) do
                            local aid = c:GetAttribute("itemId") or c:GetAttribute("ItemId")
                                     or c:GetAttribute("id")     or c:GetAttribute("Id")
                                     or c:GetAttribute("item_id")
                            if aid and tonumber(aid) then itemId = tonumber(aid); break end
                        end
                    end

                    -- Jika dapat itemId, filter dengan GEM_ID_TO_LEVEL
                    if itemId and tonumber(itemId) then
                        local id = tonumber(itemId)
                        if IsGemIdToDecomp(id, minLv, maxLv) then
                            table.insert(result, guidStr)
                        end
                    else
                        -- Fallback: parse "Lv.X" dari NumText / TextLabel
                        local lvFound = nil
                        for _, c in ipairs(child:GetDescendants()) do
                            if c:IsA("TextLabel") and (
                                c.Name == "NumText" or
                                c.Name:lower():find("lv") or
                                c.Name:lower():find("level")
                            ) then
                                local n = c.Text:match("[Ll][Vv]%.?%s*(%d+)")
                                if n then lvFound = tonumber(n); break end
                            end
                        end
                        if lvFound and lvFound >= minLv and lvFound <= maxLv then
                            table.insert(result, guidStr)
                        end
                    end
                until true
            end
        end)
        return result
    end

    --  SetDGPillOff: matikan toggle secara paksa (WindUI)
    -- Source asli baris ~5001-5007
    local _dgToggleElement = nil
    local function SetDGPillOff()
        _autoDecompGemOn = false
        if _dgToggleElement then
            pcall(function() _dgToggleElement:Set(false, false) end)
        end
    end

    --  RunAutoDecompGem: validasi input, scan panel, fire DecomposeItems
    -- Source asli baris ~5008-5104
    local function RunAutoDecompGem()
        -- Validasi min level
        if _gemMinLevel < 1 then
            SetDGStatus("[ERROR] Min Level wajib diisi!")
            task.wait(2); SetDGPillOff()
            SetDGStatus("Idle - Input Error")
            return
        end

        -- Validasi max level
        if _gemMaxLevel < 1 then
            SetDGStatus("[ERROR] Max Level wajib diisi!")
            task.wait(2); SetDGPillOff()
            SetDGStatus("Idle - Input Error")
            return
        end

        -- Validasi: min tidak boleh > max
        if _gemMinLevel > _gemMaxLevel then
            SetDGStatus("[ERROR] Min Level > Max Level!")
            task.wait(2); SetDGPillOff()
            SetDGStatus("Idle - Input Error")
            return
        end

        -- Validasi: range 1-150
        if _gemMinLevel < 1 or _gemMinLevel > 150 or _gemMaxLevel < 1 or _gemMaxLevel > 150 then
            SetDGStatus("[ERROR] Level harus antara 1-150!")
            task.wait(2); SetDGPillOff()
            SetDGStatus("Idle - Input Error")
            return
        end

        -- Update state tracking
        _gemMinLevelState = _gemMinLevel
        _gemMaxLevelState = _gemMaxLevel

        SetDGStatus("SCAN Inventory...")
        task.wait(0.5)

        local guids = GetGemGuidsFromPanel(_gemMinLevel, _gemMaxLevel)

        if #guids == 0 then
            SetDGStatus("[!] OPEN GemsPanel First! (Lv" .. _gemMinLevel .. "-" .. _gemMaxLevel .. ")")
            task.wait(2); SetDGPillOff()
            SetDGStatus("Idle - OPEN GemsPanel First")
            return
        end

        SetDGStatus("GOT " .. #guids .. " gem (Lv" .. _gemMinLevel .. "-" .. _gemMaxLevel .. ")...")
        task.wait(0.3)

        local decomposed = 0
        local BATCH = 20
        local re = Remotes:FindFirstChild("DecomposeItems")
        if not re then
            SetDGStatus("[!] DecomposeItems remote NOT FOUND!")
            task.wait(2); SetDGPillOff()
            return
        end

        for i = 1, #guids, BATCH do
            if not _autoDecompGemOn then break end
            local batch = {}
            for j = i, math.min(i + BATCH - 1, #guids) do
                table.insert(batch, guids[j])
            end
            SetDGStatus("Decompose " .. decomposed .. "/" .. #guids .. "...")
            -- [v54 FIX] Format confirmed SimpleSpy: {itemType=7, data={guid1,...}}
            pcall(function() re:FireServer({itemType = GEM_ITEM_TYPE, data = batch}) end)
            decomposed = decomposed + #batch
            task.wait(0.5)
        end

        SetDGStatus("[OK] " .. decomposed .. " gem DECOMPOSED! (Lv" .. _gemMinLevel .. "-" .. _gemMaxLevel .. ")")
        task.wait(2); SetDGPillOff()
        SetDGStatus("Idle")
    end

    -- 
    --  SECTION: AUTO DECOMPOSE GEMS (WindUI)
    --  Source asli baris ~4826-5148
    -- 
    MainTab:Section({ Title = "Auto Decompose Gems", Icon = "gem" })

    -- Paragraph status
    _dgStatusParagraph = MainTab:Paragraph({
        Title = "Status",
        Desc  = "Idle",
    })

    -- Input Min Level
    -- Pengganti dgMinInput TextBox dari source asli baris ~4858-4868
    _dgMinInputElement = MainTab:Input({
        Flag        = "mainGemMin",
        Title       = "Min Level",
        Desc        = "Level minimum gem yang akan di-decompose (1-150)",
        Placeholder = "Contoh: 1",
        Value       = "1",
        Callback    = function(val)
            local n = tonumber(val)
            if n and n >= 1 and n <= 150 then
                _gemMinLevel      = n
                _gemMinLevelState = n
            end
        end,
    })

    -- Input Max Level
    -- Pengganti dgMaxInput TextBox dari source asli baris ~4870-4880
    _dgMaxInputElement = MainTab:Input({
        Flag        = "mainGemMax",
        Title       = "Max Level",
        Desc        = "Level maksimum gem yang akan di-decompose (1-150)",
        Placeholder = "Contoh: 5",
        Value       = "1",
        Callback    = function(val)
            local n = tonumber(val)
            if n and n >= 1 and n <= 150 then
                _gemMaxLevel      = n
                _gemMaxLevelState = n
            end
        end,
    })

    -- Set default via SetDGLevelRange (expose ke global setelah elemen dibuat)
    SetDGLevelRange(1, 1)
    _setGemLevelRange = SetDGLevelRange

    -- Toggle utama AUTO DECOMPOSE GEMS
    -- Source asli baris ~4826-4830 (dgPill.MouseButton1Click)
    _dgToggleElement = MainTab:Toggle({
        Flag     = "mainDecompGem",
        Title    = "AUTO DECOMPOSE GEMS",
        Desc     = "Scan GemsPanel & decompose gem sesuai range level",
        Value    = false,
        Callback = function(on)
            _autoDecompGemOn    = on
            _autoDecompGemState = on
            if on then
                _autoDecompGemThread = task.spawn(RunAutoDecompGem)
            else
                if _autoDecompGemThread then
                    pcall(function() task.cancel(_autoDecompGemThread) end)
                    _autoDecompGemThread = nil
                end
                SetDGStatus("Idle - STOPPED")
            end
        end,
    })

    --  Expose ke global (dibaca Config panel saat restore)
    -- Source asli baris ~5122-5148
    _autoDecompGemSet = function(v)
        if v == _autoDecompGemOn then return end
        _autoDecompGemOn    = v
        _autoDecompGemState = v
        if _dgToggleElement then _dgToggleElement:Set(v) end
    end

    _visDecompGem = function(v)
        _autoDecompGemState = v
        if _dgToggleElement then _dgToggleElement:Set(v, false) end
    end

end -- end do PANEL: MAIN (Auto Decompose Gems)

-- ============================================================================
-- PANEL: MAIN (lanjutan)
-- AUTO MERGE POTION
-- Dipindah dari baris ~8627 source premium (v243)
-- Ditulis ulang pakai WindUI native API
-- Perbedaan API vs source asli:
--   Source asli: Frame/Btn/Label custom + MakeDropdown + MakeSlider + ToggleRow
--   WindUI:      Section + Paragraph + Dropdown(Multi=false) + Input + Toggle
-- Remote: PotionMerge:InvokeServer({id=id, count=cnt})
-- Global expose: _mergeRunningState, _setMergeToggle, _visMerge
-- ============================================================================
do
    --  Global expose (dibaca Config panel saat save/load) 
    -- Sama persis dengan deklarasi source asli baris ~1721, ~1736, ~1752
    _mergeRunningState = false  -- tracking state untuk Config
    _setMergeToggle    = nil    -- setter logic toggle (fn(bool))
    _visMerge          = nil    -- setter visual-only toggle (fn(bool))

    --  POTION DATA (source asli baris ~8447-8455) 
    local MERGE_POTIONS = {
        {name = "Small Attack Potion", id = 10048},
        {name = "Small Gold Potion",   id = 10049},
        {name = "Small Luck Potion",   id = 10047},
        {name = "Big Potion DMG",      id = 10051},
        {name = "Big Potion Gold",     id = 10052},
        {name = "Big Potion Luck",     id = 10050},
    }

    --  Build tabel dropdown values (nama) dan lookup nama -> id
    -- WindUI Dropdown bekerja dengan string value
    local _mDropValues = {}   -- list nama untuk WindUI Dropdown Values
    local _mNameToId   = {}   -- {["Small Attack Potion"] = 10048, ...}
    for _, pt in ipairs(MERGE_POTIONS) do
        table.insert(_mDropValues, pt.name)
        _mNameToId[pt.name] = pt.id
    end

    --  State internal (source asli baris ~8654-8658) 
    local _mergeSelectedId = nil  -- nil = belum dipilih user
    local _mergeCount      = 1    -- default count = 1
    local _mergeRunning    = false
    local _mergeThread     = nil

    --  SetMergeStatus: update paragraph status 
    local _mergeStatusParagraph = nil
    local function SetMergeStatus(msg)
        if not _mergeStatusParagraph then return end
        pcall(function() _mergeStatusParagraph:SetDesc(msg) end)
    end

    -- 
    --  SECTION: AUTO MERGE POTION (WindUI)
    --  Source asli baris ~8627-8748
    -- 
    MainTab:Section({ Title = "Auto Merge Potion", Icon = "flask-conical" })

    -- Paragraph status (pengganti mStatusCard dari source asli baris ~8661-8665)
    _mergeStatusParagraph = MainTab:Paragraph({
        Title = "Status",
        Desc  = "Idle - SELECT ITEM & ENABLE",
    })

    -- Dropdown SELECT ITEM (pengganti MakeDropdown dari source asli baris ~8668-8690)
    -- Single-select (Multi=false):
    --   - Value = nil  -> placeholder "--" (WindUI default untuk kosong)
    --   - Callback menerima ap.Value langsung = string nama item (bukan table)
    local _mDropElement = MainTab:Dropdown({
        Flag     = "mainMergeItem",
        Title    = "Select Item",
        Desc     = "Pilih potion yang akan di-merge",
        Values   = _mDropValues,
        Value    = nil,   -- nil = kosong / belum pilih (bukan {} - itu untuk Multi=true)
        Multi    = false,
        Callback = function(val)
            -- Single-select: WindUI kirim ap.Value = string nama item
            local selectedName = type(val) == "string" and val or nil
            if selectedName and _mNameToId[selectedName] then
                _mergeSelectedId = _mNameToId[selectedName]
                SetMergeStatus("ITEM SELECTED: " .. selectedName)
            else
                _mergeSelectedId = nil
                SetMergeStatus("Idle - SELECT ITEM & ENABLE")
            end
        end,
    })

    -- Input COUNT 1-5 (pengganti MakeSlider(1,5) dari source asli baris ~8691-8707)
    -- WindUI tidak memiliki Slider -> pakai Input number
    local _mCountInput = MainTab:Input({
        Flag        = "mainMergeCount",
        Title       = "Count (1-5)",
        Desc        = "Jumlah merge per siklus (1-5)",
        Placeholder = "Contoh: 1",
        Value       = "1",
        Callback    = function(val)
            local n = tonumber(val)
            if n and n >= 1 and n <= 5 then
                _mergeCount = math.floor(n)
            end
        end,
    })

    -- Toggle ON/OFF (pengganti ToggleRow dari source asli baris ~8708-8741)
    local _mergeToggleElement = MainTab:Toggle({
        Flag     = "mainMergeToggle",
        Title    = "AUTO MERGE POTION",
        Desc     = "ON = START merge potion",
        Value    = false,
        Callback = function(on)
            if on then
                -- Validasi: item harus sudah dipilih
                if not _mergeSelectedId then
                    SetMergeStatus("[!] SELECT ITEM PLEASE!")
                    -- Matikan toggle kembali (silent)
                    task.defer(function()
                        if _mergeToggleElement then
                            pcall(function() _mergeToggleElement:Set(false, false) end)
                        end
                    end)
                    return
                end
                _mergeRunning      = true
                _mergeRunningState = true
                -- Cancel thread lama jika ada
                if _mergeThread then pcall(function() task.cancel(_mergeThread) end) end
                -- Spawn loop merge
                _mergeThread = task.spawn(function()
                    while _mergeRunning do
                        local id  = _mergeSelectedId
                        local cnt = _mergeCount
                        SetMergeStatus("[M] Merging id=" .. id .. " x" .. cnt)
                        pcall(function()
                            local re = Remotes:FindFirstChild("PotionMerge")
                            if re then re:InvokeServer({id = id, count = cnt}) end
                        end)
                        SetMergeStatus("[OK] Merge DONE x" .. cnt)
                        task.wait(0.5)
                    end
                    SetMergeStatus("Idle - toggle OFF")
                end)
            else
                _mergeRunning      = false
                _mergeRunningState = false
                if _mergeThread then
                    pcall(function() task.cancel(_mergeThread) end)
                    _mergeThread = nil
                end
                SetMergeStatus("Idle - SELECT ITEM & ENABLE")
            end
        end,
    })

    --  Expose ke global (dibaca Config panel saat restore)
    -- Source asli baris ~8740-8741
    _setMergeToggle = function(v)
        if _mergeToggleElement then
            _mergeToggleElement:Set(v)           -- trigger Callback + update visual
        end
    end
    _visMerge = function(v)
        if _mergeToggleElement then
            _mergeToggleElement:Set(v, false)    -- update visual only (silent)
        end
    end

end -- end do PANEL: MAIN (Auto Merge Potion)

-- ============================================================================
-- PANEL: MAIN (lanjutan)
-- AUTO USE POTION
-- Dipindah dari baris ~8750 source premium (v243)
-- Ditulis ulang pakai WindUI native API
-- Perbedaan API vs source asli:
--   Source asli: Frame/Btn/Label custom + MakeDropdown + MakeSlider + ToggleRow
--   WindUI:      Section + Paragraph + Dropdown(Multi=false) + Input + Toggle
-- Remote: UseItem:InvokeServer({useCount=cnt, itemId=id})
-- Global expose: _useRunningState, _setUseToggle, _visUse
-- ============================================================================
do
    --  Global expose (dibaca Config panel saat save/load) 
    -- Sama persis dengan deklarasi source asli baris ~1722, ~1737, ~1753
    _useRunningState = false  -- tracking state untuk Config
    _setUseToggle    = nil    -- setter logic toggle (fn(bool))
    _visUse          = nil    -- setter visual-only toggle (fn(bool))

    --  POTION DATA (source asli baris ~8456-8468) 
    -- USE_POTIONS memiliki 9 item (termasuk Super Potion) vs MERGE_POTIONS 6 item
    local USE_POTIONS = {
        {name = "Small Potion DMG",  id = 10048},
        {name = "Small Potion Gold", id = 10049},
        {name = "Small Potion Luck", id = 10047},
        {name = "Big Potion DMG",    id = 10051},
        {name = "Big Potion Gold",   id = 10052},
        {name = "Big Potion Luck",   id = 10050},
        {name = "Super Potion DMG",  id = 10060},
        {name = "Super Potion Gold", id = 10061},
        {name = "Super Potion Luck", id = 10059},
    }

    --  Build tabel dropdown values dan lookup nama -> id
    local _uDropValues = {}
    local _uNameToId   = {}
    for _, pt in ipairs(USE_POTIONS) do
        table.insert(_uDropValues, pt.name)
        _uNameToId[pt.name] = pt.id
    end

    --  State internal (source asli baris ~8783-8787) 
    local _useSelectedId = nil  -- nil = belum dipilih user
    local _useCount      = 1    -- default count = 1
    local _useRunning    = false
    local _useThread     = nil

    --  SetUseStatus: update paragraph status 
    local _useStatusParagraph = nil
    local function SetUseStatus(msg)
        if not _useStatusParagraph then return end
        pcall(function() _useStatusParagraph:SetDesc(msg) end)
    end

    -- 
    --  SECTION: AUTO USE POTION (WindUI)
    --  Source asli baris ~8750-8872
    -- 
    MainTab:Section({ Title = "Auto Use Potion", Icon = "zap" })

    -- Paragraph status (pengganti uStatusCard dari source asli baris ~8789-8793)
    _useStatusParagraph = MainTab:Paragraph({
        Title = "Status",
        Desc  = "Idle - SELECT ITEM & ENABLE",
    })

    -- Dropdown SELECT ITEM (pengganti MakeDropdown dari source asli baris ~8795-8816)
    -- Single-select (Multi=false):
    --   - Value = nil  -> placeholder "--" (WindUI default untuk kosong)
    --   - Callback menerima ap.Value langsung = string nama item (bukan table)
    local _uDropElement = MainTab:Dropdown({
        Flag     = "mainUseItem",
        Title    = "Select Item",
        Desc     = "Pilih potion yang akan digunakan",
        Values   = _uDropValues,
        Value    = nil,   -- nil = kosong / belum pilih (bukan {} - itu untuk Multi=true)
        Multi    = false,
        Callback = function(val)
            -- Single-select: WindUI kirim ap.Value = string nama item
            local selectedName = type(val) == "string" and val or nil
            if selectedName and _uNameToId[selectedName] then
                _useSelectedId = _uNameToId[selectedName]
                SetUseStatus("Item SELECTED: " .. selectedName)
            else
                _useSelectedId = nil
                SetUseStatus("Idle - SELECT ITEM & ENABLE")
            end
        end,
    })

    -- Input COUNT 1-100 (pengganti MakeSlider(1,100) dari source asli baris ~8817-8830)
    -- WindUI tidak memiliki Slider -> pakai Input number
    local _uCountInput = MainTab:Input({
        Flag        = "mainUseCount",
        Title       = "Use Count (1-100)",
        Desc        = "Jumlah potion yang digunakan per siklus (1-100)",
        Placeholder = "Contoh: 1",
        Value       = "1",
        Callback    = function(val)
            local n = tonumber(val)
            if n and n >= 1 and n <= 100 then
                _useCount = math.floor(n)
            end
        end,
    })

    -- Toggle ON/OFF (pengganti ToggleRow dari source asli baris ~8831-8863)
    local _useToggleElement = MainTab:Toggle({
        Flag     = "mainUseToggle",
        Title    = "AUTO USE POTION",
        Desc     = "ON = start use potion",
        Value    = false,
        Callback = function(on)
            if on then
                -- Validasi: item harus sudah dipilih
                if not _useSelectedId then
                    SetUseStatus("[!] SELECT ITEM PLEASE!")
                    -- Matikan toggle kembali (silent)
                    task.defer(function()
                        if _useToggleElement then
                            pcall(function() _useToggleElement:Set(false, false) end)
                        end
                    end)
                    return
                end
                _useRunning      = true
                _useRunningState = true
                -- Cancel thread lama jika ada
                if _useThread then pcall(function() task.cancel(_useThread) end) end
                -- Spawn loop use
                _useThread = task.spawn(function()
                    while _useRunning do
                        local id  = _useSelectedId
                        local cnt = _useCount
                        SetUseStatus("[U] Using id=" .. id .. " x" .. cnt)
                        pcall(function()
                            local re = Remotes:FindFirstChild("UseItem")
                            if re then re:InvokeServer({useCount = cnt, itemId = id}) end
                        end)
                        SetUseStatus("[OK] Use DONE x" .. cnt)
                        task.wait(0.5)
                    end
                    SetUseStatus("Idle - toggle OFF")
                end)
            else
                _useRunning      = false
                _useRunningState = false
                if _useThread then
                    pcall(function() task.cancel(_useThread) end)
                    _useThread = nil
                end
                SetUseStatus("Idle - SELECT ITEM & ENABLE")
            end
        end,
    })

    --  Expose ke global (dibaca Config panel saat restore)
    -- Source asli baris ~8862-8863
    _setUseToggle = function(v)
        if _useToggleElement then
            _useToggleElement:Set(v)           -- trigger Callback + update visual
        end
    end
    _visUse = function(v)
        if _useToggleElement then
            _useToggleElement:Set(v, false)    -- update visual only (silent)
        end
    end

end -- end do PANEL: MAIN (Auto Use Potion)


-- ============================================================================
-- PANEL: FARM
-- Dipindah dari baris ~5571 source premium (1.lua)
-- Ditulis ulang pakai WindUI native API
--
-- Perbedaan API vs source asli:
--   Source asli : ToggleRow(), custom Frame/Btn dropdown, custom ScrollingFrame rows
--   WindUI      : Tab:Toggle(), Tab:Dropdown(Multi=false), Tab:Paragraph(), Tab:Button()
--                 Enemy list rows dibuat manual (WindUI tidak punya dynamic list),
--                 disimulasikan via Paragraph + Button per enemy (lihat catatan TA di bawah)
--
-- Fitur:
--   1. ENEMY HP MONITOR   HP bar + stopwatch (Paragraph + Button START/STOP/RESET)
--   2. RANDOM ATTACK (RA)  Toggle, kill counter Paragraph, BlockSkillEffects
--   3. SELECT ENEMY / TARGET ATTACK (TA)  Mode dropdown + Refresh + enemy list rows
--
-- Remote:
--   RE.Atk   (RemoteEvent)  : FireServer({attackEnemyGUID=guid})
--   RE.Click (RemoteFunction): InvokeServer({enemyGuid=guid})
--   RE.Death (RemoteEvent)  : OnClientEvent  data.enemyGuid / data.guid
--   ShowEnemyTakeDamageInfo (RemoteEvent RS.Remotes): OnClientEvent  {enemyId, hp, maxHp}
--
-- Global expose:
--   _setRAToggle       set + trigger toggle RA
--   _visRandomAtk      set visual only RA
--   _raRunningState    bool state RA
-- ============================================================================
do
    --  Global expose (dibaca Config panel saat save/load) 
    _raRunningState = false
    _setRAToggle    = nil
    _visRandomAtk   = nil

    --  State RA & TA 
    local RA = { running=false, threads={}, killed=0, cur=nil, next=nil, _lockConn=nil }
    local TA = { running=false, threads={}, killed=0, cur=nil, targetName=nil }

    local _byNameLiveToken = nil
    local _raDiedConns     = {}
    local _deadG_F         = {}
    local HERO_GUIDS_F     = HERO_GUIDS  -- alias ke global, bukan copy

    --  Death listener global 
    -- Source asli baris 5587-5597
    if RE and RE.Death then
        RE.Death.OnClientEvent:Connect(function(d)
            if not d then return end
            local g = d.enemyGuid or d.guid
            if g then
                _deadG_F[g] = false
                if RA.running then RA.killed = RA.killed + 1 end
                if TA.running then TA.killed = TA.killed + 1 end
            end
        end)
    end

    --  Helper: validasi posisi HRP 
    -- Source asli baris 5600-5606
    local function IsPosValidF(hrp)
        if not hrp then return false end
        local pos = hrp.Position
        if pos.X~=pos.X or pos.Y~=pos.Y or pos.Z~=pos.Z then return false end
        if math.abs(pos.X)>1e10 or math.abs(pos.Y)>1e10 or math.abs(pos.Z)>1e10 then return false end
        return true
    end

    --  Helper: scan semua folder enemy standar 
    -- Source asli baris 5611-5635
    local function GetEnemiesF()
        local list = {}
        local seen = {}
        for _, fname in ipairs({"Bosses","Boss","RaidBoss","Enemys","Enemy","Enemies","RaidEnemys","Monsters","Monster"}) do
            local f = workspace:FindFirstChild(fname)
            if f then
                for _,e in ipairs(f:GetChildren()) do
                    if e:IsA("Model") then
                        local g = e:GetAttribute("EnemyGuid") or e:GetAttribute("BossGuid")
                                or e:GetAttribute("Guid")     or e:GetAttribute("GUID")
                        local h = e:FindFirstChild("HumanoidRootPart")
                                or e.PrimaryPart
                                or e:FindFirstChild("Torso")
                                or e:FindFirstChild("UpperTorso")
                                or e:FindFirstChildWhichIsA("BasePart")
                        local hum = e:FindFirstChildOfClass("Humanoid")
                        if g and h and hum and hum.Health>0 and not seen[g] and IsPosValidF(h) then
                            seen[g] = true
                            table.insert(list, {model=e, guid=g, hrp=h, name=e.Name})
                        end
                    end
                end
            end
        end
        return list
    end

    local function IsDeadF(e)
        if not e then return true end
        if _deadG_F[e.guid] then return true end
        if not e.model or not e.model.Parent then return true end
        local hum = e.model:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then return true end
        return false
    end

    local function FindByGuidF(guid)
        for _,e in ipairs(GetEnemiesF()) do
            if e.guid == guid and not IsDeadF(e) then return e end
        end
        return nil
    end

    local function FindAllByNameF(nm)
        local result = {}
        for _,e in ipairs(GetEnemiesF()) do
            if e.name == nm and not IsDeadF(e) then
                table.insert(result, e)
            end
        end
        return result
    end

    --  Freeze / Unfreeze player 
    -- Source asli baris 5665-5710
    local _frozenWS     = nil
    local _frozenAnchor = false

    local function FreezePlayer()
        local char = LP and LP.Character; if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid"); if not hum then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        _frozenWS = true
        if hrp then
            pcall(function() hrp.AssemblyLinearVelocity  = Vector3.new(0,0,0) end)
            pcall(function() hrp.AssemblyAngularVelocity = Vector3.new(0,0,0) end)
            hum.PlatformStand = false
            hrp.Anchored      = true
            _frozenAnchor     = true
        end
    end

    local function UnfreezePlayer()
        if _frozenWS == nil then return end
        local char = LP and LP.Character; if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp and _frozenAnchor then
            hrp.Anchored  = false
            _frozenAnchor = false
        end
        _frozenWS = nil
    end

    local function ReassertFreeze()
        if _frozenWS == nil then return end
        local char = LP and LP.Character; if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp and not hrp.Anchored then
            pcall(function() hrp.AssemblyLinearVelocity  = Vector3.new(0,0,0) end)
            pcall(function() hrp.AssemblyAngularVelocity = Vector3.new(0,0,0) end)
            hrp.Anchored = true
        end
    end

    --  TpToF  teleport 3 stud di depan musuh + FreezePlayer (anchor + velocity reset)
    local function TpToF(tgt)
        if not tgt or not tgt.hrp then return end
        local char = LP.Character; if not char then return end
        local hrp  = char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
        pcall(function()
            hrp.CFrame = tgt.hrp.CFrame * CFrame.new(0, 0, -3)
        end)
        FreezePlayer()
    end

    --  IsEnemyGuidValid  validasi enemy masih ada & hidup 
    -- Source asli baris 2180-2214
    local function IsEnemyGuidValid(g)
        if not g then return false end
        local ENEMY_FOLDERS = {"Enemys","EnemyCityRaid","CityRaidEnemys","Enemies","Enemy"}
        for _, folderName in ipairs(ENEMY_FOLDERS) do
            local f = workspace:FindFirstChild(folderName)
            if f then
                for _, e in ipairs(f:GetChildren()) do
                    if e:IsA("Model") and e:GetAttribute("EnemyGuid") == g then
                        local hrp = e:FindFirstChild("HumanoidRootPart")
                        local hum = e:FindFirstChildOfClass("Humanoid")
                        if hrp and hum and hum.Health > 0 then return true end
                        return false
                    end
                end
            end
        end
        -- Fallback: nested di workspace.Map.CityRaidEnter (Siege)
        pcall(function()
            local mapF = workspace:FindFirstChild("Map")
            local cre  = mapF and mapF:FindFirstChild("CityRaidEnter")
            if cre then
                for _, e in ipairs(cre:GetDescendants()) do
                    if e:IsA("Model") and e:GetAttribute("EnemyGuid") == g then
                        local hrp = e:FindFirstChild("HumanoidRootPart")
                        local hum = e:FindFirstChildOfClass("Humanoid")
                        if hrp and hum and hum.Health > 0 then return true end
                    end
                end
            end
        end)
        return false
    end

    --  Hero-attack thread per-GUID (EnsureHeroAtkThreadFor / StopHeroAtkThreadFor) 
    -- Source asli baris 2217-2260
    local _heroAtkThreads = {}


    local function EnsureHeroAtkThreadFor(g)
        if not g then return end
        if _heroAtkThreads[g] and _heroAtkThreads[g].running then return end
        local handle = {running = true, tick = 0}
        _heroAtkThreads[g] = handle
        task.spawn(function()
            local _lastFire = {}
            while handle.running do
                if #HERO_GUIDS > 0 and (tick() - handle.tick) >= 0.5 and IsEnemyGuidValid(g) then
                    handle.tick = tick()
                    -- Ambil posisi player sekarang untuk dipasang ke semua hero
                    local _char = LP and LP.Character
                    local _pHRP = _char and _char:FindFirstChild("HumanoidRootPart")
                    local _pPos = _pHRP and _pHRP.Position or Vector3.new(0,0,0)
                    for _, hGuid in ipairs(HERO_GUIDS) do
                        local last = _lastFire[hGuid] or 0
                        if (tick() - last) >= 0.05 then
                            _lastFire[hGuid] = tick()
                            if RE.HeroUseSkill then
                                pcall(function() RE.HeroUseSkill:FireServer({heroGuid=hGuid,attackType=1,userId=MY_USER_ID,enemyGuid=g}) end)
                                task.wait(0.1)
                                pcall(function() RE.HeroUseSkill:FireServer({heroGuid=hGuid,attackType=2,userId=MY_USER_ID,enemyGuid=g}) end)
                                task.wait(0.1)
                                pcall(function() RE.HeroUseSkill:FireServer({heroGuid=hGuid,attackType=3,userId=MY_USER_ID,enemyGuid=g}) end)
                            end
                        end
                        task.wait(0.05)
                    end
                end
                task.wait(0.05)
                if not IsEnemyGuidValid(g) then
                    handle.running = false
                end
            end
            _heroAtkThreads[g] = nil
        end)
    end

    local function StopHeroAtkThreadFor(g)
        if g and _heroAtkThreads[g] then
            _heroAtkThreads[g].running = false
            _heroAtkThreads[g] = nil
        end
    end

    --  TA Spam threads  unlimited attack per-target 
    -- [UNIFIED] Disamakan dgn pola attack thread RA (tAtk, lihat StartRA):
    --   RE.Atk:FireServer 1x/frame + RE.Click:InvokeServer 1x/frame (spawned)
    --   + EnsureHeroAtkThreadFor(g) untuk serangan hero.
    -- FireAttack/FireAllDamage (dual RE.Atk + hero attackType=1 throttle 0.04s
    -- terpisah dari EnsureHeroAtkThreadFor) DIHAPUS karena cuma dipakai di sini
    -- dan menyebabkan RE.Atk + hero attackType=1 ke-fire dobel per frame.
    local _taSpamThreads = {}

    local function TaSpamF(g, enemyHRP)
        if not g then return end
        if _taSpamThreads[g] and _taSpamThreads[g].running then return end
        local handle = {running = true}
        _taSpamThreads[g] = handle
        task.spawn(function()
            while handle.running do
                if IsEnemyGuidValid(g) then
                    if RE.Atk then
                        pcall(function() RE.Atk:FireServer({attackEnemyGUID=g}) end)
                    end
                    if RE.Click then
                        task.spawn(function()
                            pcall(function() RE.Click:InvokeServer({enemyGuid=g}) end)
                        end)
                    end
                    EnsureHeroAtkThreadFor(g)
                end
                task.wait()
            end
        end)
    end

    local function StopClickSpamF(g)
        if g and _taSpamThreads[g] then
            _taSpamThreads[g].running = false
            _taSpamThreads[g] = nil
        end
    end

    local function StopAllClickSpamF()
        for _, handle in pairs(_taSpamThreads) do
            handle.running = false
        end
        _taSpamThreads = {}
    end

    local function FCharF(g, enemyHRP)
        if not g then return end
        TaSpamF(g, enemyHRP)
    end

    --  Skill Effect Blocker 
    -- Source asli baris 5806-5907
    local _secBlocked  = false
    local _secOrigCast = {}

    local function BlockSkillEffects(on)
        if on == _secBlocked then return end
        _secBlocked = on
        pcall(function()
            local TARGET_FOLDERS = {"SkillEffectContainer", "Anims"}
            if on then
                for _, folderName in ipairs(TARGET_FOLDERS) do
                    local folder = workspace:FindFirstChild(folderName)
                    if not folder then continue end
                    for _, desc in ipairs(folder:GetDescendants()) do
                        if desc:IsA("Animator") then
                            pcall(function()
                                for _, track in ipairs(desc:GetPlayingAnimationTracks()) do
                                    track:Stop(0)
                                end
                            end)
                        elseif desc:IsA("ParticleEmitter") or desc:IsA("Trail") or desc:IsA("Beam") then
                            pcall(function()
                                desc.Enabled = false
                                if desc:IsA("ParticleEmitter") then desc:Clear() end
                            end)
                        elseif desc:IsA("BasePart") then
                            _secOrigCast[desc] = desc.CastShadow
                            pcall(function()
                                desc.Transparency = 1
                                desc.CastShadow   = false
                                desc.CanCollide   = false
                                desc.CanQuery     = false
                                desc.CanTouch     = false
                            end)
                        end
                    end
                    folder.DescendantAdded:Connect(function(desc)
                        if not _secBlocked then return end
                        if desc:IsA("Animator") then
                            task.defer(function()
                                pcall(function()
                                    for _, track in ipairs(desc:GetPlayingAnimationTracks()) do
                                        track:Stop(0)
                                    end
                                end)
                            end)
                        elseif desc:IsA("ParticleEmitter") or desc:IsA("Trail") or desc:IsA("Beam") then
                            pcall(function()
                                desc.Enabled = false
                                if desc:IsA("ParticleEmitter") then desc:Clear() end
                            end)
                        elseif desc:IsA("BasePart") then
                            pcall(function()
                                desc.Transparency = 1
                                desc.CanCollide   = false
                                desc.CanQuery     = false
                                desc.CanTouch     = false
                                desc.CastShadow   = false
                            end)
                        end
                    end)
                end
            else
                if RA.running or TA.running then return end
                for _, folderName in ipairs(TARGET_FOLDERS) do
                    local folder = workspace:FindFirstChild(folderName)
                    if not folder then continue end
                    for _, desc in ipairs(folder:GetDescendants()) do
                        if desc:IsA("ParticleEmitter") or desc:IsA("Trail") or desc:IsA("Beam") then
                            pcall(function() desc.Enabled = true end)
                        elseif desc:IsA("BasePart") then
                            pcall(function()
                                desc.Transparency = 0
                                desc.CanCollide   = true
                                desc.CanQuery     = true
                                desc.CanTouch     = true
                                desc.CastShadow   = _secOrigCast[desc] ~= nil and _secOrigCast[desc] or true
                            end)
                        end
                    end
                end
                _secOrigCast = {}
            end
        end)
    end

    --  StopRA     -- Source asli baris 6122-6145 (forward-declared, dipakai StartRA  StopRA)
    local function StopRA()
        RA.running = false
        BlockSkillEffects(false)
        if RA._lockConn then
            pcall(function() RA._lockConn:Disconnect() end)
            RA._lockConn = nil
        end
        for _,t in ipairs(RA.threads) do pcall(function() task.cancel(t) end) end
        -- Stop semua hero-atk thread
        for g in pairs(_heroAtkThreads) do StopHeroAtkThreadFor(g) end
        if RA.cur and RA.cur.guid then StopHeroAtkThreadFor(RA.cur.guid) end
        RA.threads={}; RA.cur=nil; RA.next=nil
        for _,c in ipairs(_raDiedConns or {}) do pcall(function() c:Disconnect() end) end
        _raDiedConns = {}
        if not TA.running then
            UnfreezePlayer()
        end
    end

    --  StopTA 
    -- Source asli baris 6274-6287
    local function StopTA()
        TA.running = false
        BlockSkillEffects(false)
        for _,t in ipairs(TA.threads) do pcall(function() task.cancel(t) end) end
        TA.threads = {}
        StopAllClickSpamF()
        if TA.cur and TA.cur.guid then
            StopHeroAtkThreadFor(TA.cur.guid)
        end
        TA.cur=nil; TA.targetName=nil
        if not RA.running then
            UnfreezePlayer()
        end
        -- [FIX v17] Hapus task.defer(TpToRA)  race condition dengan auto-switch dropdown.
        -- Combat Lock Heartbeat RA akan otomatis relock player ke musuh RA di frame berikutnya.
    end

    --  StartRA 
    -- Source asli baris 5909-6120
    local function StartRA()
        if #HERO_GUIDS == 0 then
            pcall(function()
                for _, obj in ipairs(LP.PlayerGui:GetChildren()) do
                    local g = obj:GetAttribute("heroGuid") or obj:GetAttribute("guid")
                    if type(g)=="string" and IsValidUUID(g) then
                        local dup=false
                        for _,ex in ipairs(HERO_GUIDS) do if ex==g then dup=true; break end end
                        if not dup then table.insert(HERO_GUIDS, g) end
                    end
                end
            end)
        end
        RA.running=true; RA.killed=0; RA.cur=nil; RA.next=nil; RA.threads={}
        BlockSkillEffects(true)

        local function IsTargetAliveRA(t)
            if not t or not t.model or not t.model.Parent then return false end
            local hum = t.model:FindFirstChildOfClass("Humanoid")
            if not hum or hum.Health <= 0 then return false end
            return true
        end

        -- RAFreezePlayer/RAUnfreezePlayer diganti dengan FreezePlayer/UnfreezePlayer global
        -- supaya StopRA -> UnfreezePlayer() selalu bisa melepas Anchored dengan benar

        local function TpToRA(tgt)
            if not tgt or not tgt.hrp then return end
            local char = LP.Character
            local hrp  = char and char:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            pcall(function()
                hrp.CFrame = tgt.hrp.CFrame * CFrame.new(0, 0, -3)
            end)
        end

        local function PickRandomEnemy(excludeGuids)
            local pool = {}
            local taGuid = TA.running and TA.cur and TA.cur.guid
            for _,e in ipairs(GetEnemiesF()) do
                if IsTargetAliveRA(e) then
                    local skip = false
                    if taGuid and e.guid == taGuid then skip = true end
                    if excludeGuids then
                        for _,ex in ipairs(excludeGuids) do
                            if e.guid == ex then skip = true; break end
                        end
                    end
                    if not skip then table.insert(pool, e) end
                end
            end
            if #pool == 0 then
                for _,e in ipairs(GetEnemiesF()) do
                    if IsTargetAliveRA(e) then table.insert(pool, e) end
                end
            end
            if #pool == 0 then return nil end
            return pool[math.random(1, #pool)]
        end

        local function LockNextTarget()
            local excludes = {}
            if RA.cur then table.insert(excludes, RA.cur.guid) end
            RA.next = PickRandomEnemy(excludes)
        end

        local _raDiedConnsLocal = {}
        local function WatchEnemyRA(e)
            if not e or not e.model then return end
            local hum = e.model:FindFirstChildOfClass("Humanoid"); if not hum then return end
            local conn; conn = hum.Died:Connect(function()
                _deadG_F[e.guid] = true
                if RA.running then RA.killed = RA.killed + 1 end
                if RA.cur and RA.cur.guid == e.guid then RA.cur = nil end
                pcall(function() conn:Disconnect() end)
            end)
            table.insert(_raDiedConnsLocal, conn)
        end

        -- Combat Lock via Heartbeat
        -- [FIX v17] Player nempel ke musuh RA (bukan musuh ke player).
        -- Skip saat TA running: player sedang di posisi musuh TA, biarkan saja.
        local _raLockFrame = 0
        local _raLockConn = RunService.Heartbeat:Connect(function()
            _raLockFrame = _raLockFrame + 1
            if _raLockFrame % 2 ~= 0 then return end
            if not RA.running then return end
            if TA.running then return end  -- TA ON: player harus di posisi musuh TA, bukan RA
            if not RA.cur or not IsTargetAliveRA(RA.cur) then return end
            local char = LP.Character
            local pHRP = char and char:FindFirstChild("HumanoidRootPart")
            local eHRP = RA.cur.hrp
            if pHRP and eHRP then
                pcall(function()
                    -- Player mengikuti musuh (3 stud di depan musuh)
                    pHRP.CFrame = eHRP.CFrame * CFrame.new(0, 0, -3)
                end)
            end
        end)
        RA._lockConn = _raLockConn

        -- Main thread
        local tMain = task.spawn(function()
            RA.cur = PickRandomEnemy({})
            if RA.cur then
                TpToRA(RA.cur); FreezePlayer()
                WatchEnemyRA(RA.cur)
                local hum = RA.cur.model:FindFirstChildOfClass("Humanoid")
                if hum then
                    local capturedGuid = RA.cur.guid
                    hum.Died:Connect(function()
                        RA.killed = RA.killed + 1
                        if RA.cur and RA.cur.guid == capturedGuid then RA.cur = nil end
                    end)
                end
                LockNextTarget()
            end
            while RA.running do
                if not RA.cur or not IsTargetAliveRA(RA.cur) then
                    local _oldGuid = RA.cur and RA.cur.guid
                    if _oldGuid then
                        StopHeroAtkThreadFor(_oldGuid)
                        _deadG_F[_oldGuid] = nil
                    end
                    RA.cur = IsTargetAliveRA(RA.next) and RA.next or PickRandomEnemy({})
                    RA.next = nil
                    if RA.cur then
                        if not TA.running then TpToRA(RA.cur); FreezePlayer() end  -- TA ON: jangan override posisi TA
                        WatchEnemyRA(RA.cur)
                        local hum = RA.cur.model:FindFirstChildOfClass("Humanoid")
                        if hum then
                            local capturedGuid = RA.cur.guid
                            hum.Died:Connect(function()
                                RA.killed = RA.killed + 1
                                if RA.cur and RA.cur.guid == capturedGuid then RA.cur = nil end
                            end)
                        end
                        LockNextTarget()
                    end
                end
                if not IsTargetAliveRA(RA.next) then LockNextTarget() end
                task.wait(0.15)
            end
        end)

        -- [v27] Attack thread RA: GASS terus, selalu serang guid musuh RA sendiri
        local tAtk = task.spawn(function()
            while RA.running do
                if RA.cur and IsTargetAliveRA(RA.cur) then
                    local g   = RA.cur.guid
                    if RE and RE.Atk then
                        pcall(function() RE.Atk:FireServer({attackEnemyGUID=g}) end)
                    end
                    if RE and RE.Click then
                        task.spawn(function()
                            pcall(function() RE.Click:InvokeServer({enemyGuid=g}) end)
                        end)
                    end
                    EnsureHeroAtkThreadFor(g)
                end
                task.wait()
            end
        end)

        RA.threads = {tMain, tAtk}
    end

    --  StartTA By ID 
    -- Source asli baris 6147-6198
    local function StartTA_ByID(targetGuid, targetName, onStatus, onStop)
        TA.running=true; TA.killed=0; TA.targetName=targetName; TA.cur=nil; TA.threads={}
        BlockSkillEffects(true)
        local tChar = task.spawn(function()
            local tgt = FindByGuidF(targetGuid)
            if tgt then
                TpToF(tgt); FreezePlayer()
                TA.cur = tgt
                local hum = tgt.model and tgt.model:FindFirstChildOfClass("Humanoid")
                if hum then
                    hum.Died:Connect(function()
                        _deadG_F[targetGuid] = true
                        if TA.running then TA.killed = TA.killed + 1 end
                        StopClickSpamF(targetGuid)
                        StopHeroAtkThreadFor(targetGuid)
                        TA.cur=nil; TA.running=false
                        if onStatus then onStatus(" ["..targetName.."] mati") end
                        if onStop   then task.defer(onStop) end
                    end)
                end
            end
            while TA.running do
                tgt = FindByGuidF(targetGuid)
                if not tgt then
                    StopClickSpamF(targetGuid)
                    StopHeroAtkThreadFor(targetGuid)
                    TA.cur = nil
                    if onStatus then onStatus(" ["..targetName.."] mati") end
                    TA.running = false
                    if onStop then onStop() end
                    break
                end
                if not IsDeadF(tgt) and tgt.model.Parent then
                    TA.cur = tgt
                    -- [v27] GASS terus tanpa jeda
                    ReassertFreeze()
                    FCharF(tgt.guid, tgt.hrp)
                    if onStatus then
                        onStatus(">> ["..targetName.."] "..(tgt.guid:sub(1,5)).." Kill: "..TA.killed)
                    end
                    task.wait()
                else
                    task.wait(0.1)
                end
            end
        end)
        TA.threads = {tChar}
    end

    --  StartTA By Name 
    -- Source asli baris 6200-6272
    local function StartTA_ByName(targetName, onStatus, onStop)
        TA.running=true; TA.killed=0; TA.targetName=targetName; TA.cur=nil; TA.threads={}
        BlockSkillEffects(true)
        local tChar = task.spawn(function()
            local rrIdx    = 1
            local _curDied = false
            local _diedConn = nil
            local function WatchTarget(tgt)
                if _diedConn then pcall(function() _diedConn:Disconnect() end); _diedConn=nil end
                if not tgt or not tgt.model then return end
                local hum = tgt.model:FindFirstChildOfClass("Humanoid"); if not hum then return end
                _diedConn = hum.Died:Connect(function()
                    _deadG_F[tgt.guid] = true
                    if TA.running then TA.killed = TA.killed + 1 end
                    _curDied = true
                    if TA.cur and TA.cur.guid == tgt.guid then TA.cur = nil end
                end)
            end
            while TA.running do
                local pool = FindAllByNameF(targetName)
                if #pool == 0 then
                    if onStatus then onStatus("WAITING ["..targetName.."] respawn...") end
                    while TA.running do
                        task.wait(0.1)
                        pool = FindAllByNameF(targetName)
                        if #pool > 0 then break end
                    end
                    if not TA.running then break end
                    _deadG_F={}; rrIdx=1; _curDied=false
                end
                if rrIdx > #pool then rrIdx = 1 end
                local tgt = pool[rrIdx]
                if not tgt or IsDeadF(tgt) then
                    rrIdx = rrIdx + 1
                    task.wait(0.1)
                else
                    TA.cur   = tgt
                    _curDied = false
                    TpToF(tgt); FreezePlayer()
                    WatchTarget(tgt)
                    while TA.running and not _curDied and not IsDeadF(tgt) and tgt.model.Parent do
                        -- [v27] GASS terus tanpa jeda
                        ReassertFreeze()
                        FCharF(tgt.guid, tgt.hrp)
                        if onStatus then
                            onStatus(">> ["..targetName.."] ["..rrIdx.."/"..#pool.."] Kill: "..TA.killed)
                        end
                        task.wait()
                    end
                    StopClickSpamF(tgt.guid)
                    StopHeroAtkThreadFor(tgt.guid)
                    if TA.running then
                        rrIdx    = rrIdx + 1
                        _curDied = false
                    end
                end
            end
            if _diedConn then pcall(function() _diedConn:Disconnect() end) end
        end)
        TA.threads = {tChar}
    end

    -- =========================================================================
    --  ENEMY HP MONITOR (WindUI Paragraph + Buttons) 
    -- Source asli baris 6289-6507
    -- WindUI tidak punya custom widget HP bar, jadi kita pakai:
    --   Paragraph untuk display HP + % + rate
    --   Button START / STOP / RESET stopwatch
    -- =========================================================================
    do
        local _ehpLastEnemyId = nil
        local _ehpMaxHp       = 0
        local _ehpConn        = nil
        local _ehpStartPct    = nil
        local _ehpCurPct      = 0

        local _swRunning    = false
        local _swStartTick  = nil
        local _swAccum      = 0
        local _swTimerConn  = nil

        local function FmtHp(n)
            if not n or n <= 0 then return "0" end
            if n < 1e4 then return tostring(math.floor(n)) end
            local exp  = math.floor(math.log10(n))
            local mant = n / (10 ^ exp)
            return string.format("%.2fE+%02d", mant, exp)
        end
        local function FmtTime(secs)
            local s = math.floor(secs)
            return string.format("%02d:%02d", math.floor(s/60), s%60)
        end
        local function HpColor(pct)
            if pct > 50 then return ""
            elseif pct > 25 then return ""
            else return "" end
        end

        local _ehpPara   = nil
        local _timerPara = nil
        local _ratePara  = nil

        local function SwGetElapsed()
            if _swRunning and _swStartTick then
                return _swAccum + (tick() - _swStartTick)
            end
            return _swAccum
        end

        local function SwUpdateDisplay()
            local elapsed = SwGetElapsed()
            if _timerPara then
                pcall(function()
                    _timerPara:SetDesc(" " .. FmtTime(elapsed) .. (_swRunning and " [RUNNING]" or " [PAUSED]"))
                end)
            end
            if _ratePara and _ehpStartPct and elapsed > 2 then
                local pctDone = _ehpStartPct - _ehpCurPct
                if pctDone > 0.01 then
                    pcall(function() _ratePara:SetDesc("1% setiap ~" .. FmtTime(elapsed / pctDone)) end)
                end
            end
        end

        FarmTab:Section({ Title = " ENEMY HP MONITOR", Icon = "heart-pulse" })

        _ehpPara = FarmTab:Paragraph({ Title = "HP", Desc = " / " })
        _timerPara = FarmTab:Paragraph({ Title = "Stopwatch", Desc = " 00:00 [STOPPED]" })
        _ratePara  = FarmTab:Paragraph({ Title = "Rate", Desc = "1% setiap ~--:--" })

        FarmTab:Button({
            Title    = " START Stopwatch",
            Desc     = "Mulai / lanjut hitung waktu",
            Callback = function()
                if _swRunning then return end
                _swRunning   = true
                _swStartTick = tick()
                if _ehpStartPct == nil then _ehpStartPct = _ehpCurPct end
                if not _swTimerConn then
                    local _swLastUpdate = 0
                    _swTimerConn = RunService.Heartbeat:Connect(function()
                        local now = tick()
                        if (now - _swLastUpdate) < 0.1 then return end
                        _swLastUpdate = now
                        SwUpdateDisplay()
                    end)
                end
            end,
        })
        FarmTab:Button({
            Title    = " STOP Stopwatch",
            Desc     = "Pause timer (bisa dilanjut)",
            Callback = function()
                if not _swRunning then return end
                _swAccum     = SwGetElapsed()
                _swRunning   = false
                _swStartTick = nil
                if _swTimerConn then
                    pcall(function() _swTimerConn:Disconnect() end)
                    _swTimerConn = nil
                end
                SwUpdateDisplay()
            end,
        })
        FarmTab:Button({
            Title    = " RESET Stopwatch",
            Desc     = "Reset timer ke 00:00",
            Callback = function()
                _swAccum     = 0
                _swRunning   = false
                _swStartTick = nil
                _ehpStartPct = nil
                if _swTimerConn then
                    pcall(function() _swTimerConn:Disconnect() end)
                    _swTimerConn = nil
                end
                if _timerPara then pcall(function() _timerPara:SetDesc(" 00:00 [STOPPED]") end) end
                if _ratePara   then pcall(function() _ratePara:SetDesc("1% setiap ~--:--") end) end
            end,
        })

        -- Pasang listener HP dari ShowEnemyTakeDamageInfo
        pcall(function()
            local RS  = game:GetService("ReplicatedStorage")
            local rem = RS:FindFirstChild("Remotes")
                     and RS.Remotes:FindFirstChild("ShowEnemyTakeDamageInfo")
            if rem then
                _ehpConn = rem.OnClientEvent:Connect(function(data)
                    if type(data) ~= "table" then return end
                    pcall(function()
                        local eid = tostring(data.enemyId or "")
                        local hp  = tonumber(data.hp)    or 0
                        local mhp = tonumber(data.maxHp) or 0
                        if eid ~= "" and eid ~= _ehpLastEnemyId then
                            _ehpLastEnemyId = eid
                            _ehpMaxHp       = mhp
                        end
                        if mhp > 0 and mhp > _ehpMaxHp then _ehpMaxHp = mhp end
                        local curMaxHp = (_ehpMaxHp > 0) and _ehpMaxHp or mhp
                        if curMaxHp <= 0 then return end
                        local pct = math.clamp(hp / curMaxHp * 100, 0, 100)
                        _ehpCurPct = pct
                        if _ehpPara then
                            pcall(function()
                                _ehpPara:SetDesc(
                                    HpColor(pct) .. " " .. FmtHp(hp) .. " / " .. FmtHp(curMaxHp)
                                    .. "  (" .. string.format("%.3f%%", pct) .. ")"
                                )
                            end)
                        end
                    end)
                end)
            end
        end)
    end -- end Enemy HP Monitor block

    -- =========================================================================
    --  RANDOM ATTACK (RA) 
    -- Source asli baris 6509-6517
    -- =========================================================================
    FarmTab:Section({ Title = " RANDOM ATTACK", Icon = "sword" })

    local _raToggleElement = FarmTab:Toggle({
        Flag     = "farmRA",
        Title    = "RANDOM ATTACK",
        Desc     = "Auto attack musuh random sampai mati, lalu ganti target",
        Value    = false,
        Callback = function(on)
            _raRunningState = on
            if on then StartRA() else StopRA() end
        end,
    })

    _setRAToggle = function(v)
        _raRunningState = v
        if _raToggleElement then pcall(function() _raToggleElement:Set(v) end) end
    end
    _visRandomAtk = function(v)
        if _raToggleElement then pcall(function() _raToggleElement:Set(v, false) end) end
    end

    -- =========================================================================
    --  SELECT ENEMY / TARGET ATTACK (TA) 
    -- Source asli baris 6519-6783
    --
    -- WindUI tidak punya dynamic scrollable row list, jadi pendekatan:
    --   1. Dropdown Mode (By ID / By Name)   Tab:Dropdown(Multi=false)
    --   2. Button "Refresh Enemies"          Tab:Button()
    --   3. Status Paragraph                  Tab:Paragraph() diupdate realtime
    --   4. Enemy rows disimulasikan via      Tab:Dropdown(Multi=false, Values=list)
    --      Single dropdown terpilih = target TA yang aktif
    --   5. Button "START TARGET ATTACK"      Tab:Button()
    --   6. Button "STOP TARGET ATTACK"       Tab:Button()
    --
    -- Logika identik, hanya UI layer yang beda (row individual  dropdown pilih target)
    -- =========================================================================
    FarmTab:Section({ Title = " TARGET ATTACK", Icon = "crosshair" })

    local _taStatusPara      = FarmTab:Paragraph({ Title = "Status TA", Desc = "Idle" })

    -- Mode dropdown: By ID / By Name
    local _listMode = "id"
    FarmTab:Dropdown({
        Flag     = "farmTAMode",
        Title    = "Mode Select",
        Desc     = "By ID = target individu | By Name = round-robin senama",
        Values   = {"By ID", "By Name"},
        Value    = "By ID",
        Multi    = false,
        Callback = function(val)
            local v = type(val)=="string" and val or nil
            if v == "By Name" then _listMode = "name"
            else _listMode = "id" end
        end,
    })

    -- Enemy dropdown  di-rebuild setiap klik Refresh Enemies
    local _enemyDropValues   = {}
    local _enemyDropSelected = nil
    local _enemyDropElement  = nil
    local _enemyDataById     = {}
    local _enemyDataByName   = {}

    _enemyDropElement = FarmTab:Dropdown({
        -- Flag tidak dipasang: list ini di-rebuild dinamis tiap REFRESH ENEMIES,
        -- nilai yang disimpan tidak bermakna lintas sesi (GUID enemy berubah).
        Title    = "Pilih Enemy",
        Desc     = "Klik REFRESH ENEMIES untuk load daftar musuh",
        Values   = {},
        Value    = nil,
        Multi    = false,
        Callback = function(val)
            _enemyDropSelected = type(val)=="string" and val or nil

            -- Auto-switch target jika TA sedang running  tidak perlu OFF/ON lagi
            if not _enemyDropSelected then return end
            if not TA.running then return end

            -- Stop TA lama
            StopTA()

            -- Start TA ke target baru sesuai mode
            if _listMode == "id" then
                local data = _enemyDataById[_enemyDropSelected]
                if not data then
                    if _taStatusPara then pcall(function() _taStatusPara:SetDesc("[!] Enemy tidak valid, Refresh dulu") end) end
                    -- Toggle kembali ke OFF karena target tidak valid
                    if _taToggleElement then pcall(function() _taToggleElement:Set(false, false) end) end
                    return
                end
                StartTA_ByID(data.guid, data.name,
                    function(msg)
                        if _taStatusPara then pcall(function() _taStatusPara:SetDesc(msg) end) end
                    end,
                    _taOnStop
                )
            else
                local data = _enemyDataByName[_enemyDropSelected]
                if not data then
                    if _taStatusPara then pcall(function() _taStatusPara:SetDesc("[!] Enemy tidak valid, Refresh dulu") end) end
                    if _taToggleElement then pcall(function() _taToggleElement:Set(false, false) end) end
                    return
                end
                StartTA_ByName(data.nm,
                    function(msg)
                        if _taStatusPara then pcall(function() _taStatusPara:SetDesc(msg) end) end
                    end,
                    _taOnStop
                )
            end
        end,
    })

    -- Refresh Enemies  scan workspace + rebuild dropdown sekaligus (soal 7 & 8)
    FarmTab:Button({
        Title    = " REFRESH ENEMIES",
        Desc     = "Scan workspace & isi dropdown dengan musuh hidup beserta ID-nya",
        Callback = function()
            -- Stop TA dulu jika sedang running
            if TA.running then
                StopTA()
                if _taStatusPara then pcall(function() _taStatusPara:SetDesc("Stopped (Refresh)") end) end
            end
            _enemyDataById   = {}
            _enemyDataByName = {}
            _enemyDropValues = {}
            _enemyDropSelected = nil

            local enemies = GetEnemiesF()
            if #enemies == 0 then
                if _taStatusPara then pcall(function() _taStatusPara:SetDesc("Map kosong  tidak ada musuh") end) end
                if _enemyDropElement then pcall(function() _enemyDropElement:Set({}) end) end
                return
            end

            if _listMode == "id" then
                table.sort(enemies, function(a,b) return a.name < b.name end)
                for _, e in ipairs(enemies) do
                    local label = e.name .. " [" .. e.guid:sub(1,8) .. "]"
                    table.insert(_enemyDropValues, label)
                    _enemyDataById[label] = {guid=e.guid, name=e.name}
                end
                if _taStatusPara then
                    pcall(function() _taStatusPara:SetDesc(#enemies .. " musuh (By ID)  pilih dari dropdown") end)
                end
            else
                local nc = {}
                for _, e in ipairs(enemies) do nc[e.name]=(nc[e.name] or 0)+1 end
                local names = {}
                for nm in pairs(nc) do table.insert(names, nm) end
                table.sort(names)
                for _, nm in ipairs(names) do
                    local label = nm .. " x" .. nc[nm]
                    table.insert(_enemyDropValues, label)
                    _enemyDataByName[label] = {nm=nm}
                end
                if _taStatusPara then
                    pcall(function() _taStatusPara:SetDesc(#names .. " jenis, " .. #enemies .. " total (By Name)") end)
                end
            end

            -- Rebuild dropdown dengan data baru
            if _enemyDropElement then
                pcall(function() _enemyDropElement:Refresh(_enemyDropValues, nil) end)
                -- Fallback jika Refresh tidak tersedia di versi WindUI ini
                pcall(function()
                    _enemyDropElement.Values = _enemyDropValues
                end)
            end
        end,
    })

    -- TARGET ATTACK Toggle (ON = START, OFF = STOP)  soal 9
    local _taToggleElement = nil
    local function _taOnStop()
        if _taToggleElement then
            pcall(function() _taToggleElement:Set(false, false) end)
        end
        if _taStatusPara then pcall(function() _taStatusPara:SetDesc("Target mati  pilih enemy baru & ON lagi") end) end
    end

    _taToggleElement = FarmTab:Toggle({
        Flag     = "farmTA",
        Title    = "TARGET ATTACK",
        Desc     = "ON = mulai serang target terpilih | OFF = stop",
        Value    = false,
        Callback = function(on)
            if on then
                if not _enemyDropSelected then
                    if _taStatusPara then pcall(function() _taStatusPara:SetDesc("[!] Pilih enemy dulu dari dropdown!") end) end
                    task.defer(function()
                        if _taToggleElement then
                            pcall(function() _taToggleElement:Set(false, false) end)
                        end
                    end)
                    return
                end
                if TA.running then StopTA() end

                if _listMode == "id" then
                    local data = _enemyDataById[_enemyDropSelected]
                    if not data then
                        if _taStatusPara then pcall(function() _taStatusPara:SetDesc("[!] Enemy tidak valid, Refresh dulu") end) end
                        task.defer(function()
                            if _taToggleElement then pcall(function() _taToggleElement:Set(false, false) end) end
                        end)
                        return
                    end
                    StartTA_ByID(data.guid, data.name,
                        function(msg)
                            if _taStatusPara then pcall(function() _taStatusPara:SetDesc(msg) end) end
                        end,
                        _taOnStop
                    )
                else
                    local data = _enemyDataByName[_enemyDropSelected]
                    if not data then
                        if _taStatusPara then pcall(function() _taStatusPara:SetDesc("[!] Enemy tidak valid, Refresh dulu") end) end
                        task.defer(function()
                            if _taToggleElement then pcall(function() _taToggleElement:Set(false, false) end) end
                        end)
                        return
                    end
                    StartTA_ByName(data.nm,
                        function(msg)
                            if _taStatusPara then pcall(function() _taStatusPara:SetDesc(msg) end) end
                        end,
                        _taOnStop
                    )
                end
            else
                StopTA()
                if _taStatusPara then pcall(function() _taStatusPara:SetDesc("Stop") end) end
            end
        end,
    })

end -- end do PANEL: FARM


-- ============================================================================
-- PANEL: MASS ATTACK
-- Dipindah dari 1.lua baris ~6785 (PANEL: ATTACK)
-- Ditulis ulang pakai WindUI native API
-- Perbedaan API vs source asli:
--   Source asli: NewPanel("attack") + MakeSimpleDD custom + ToggleRow custom
--   WindUI:      MassAttackTab:Section() + MassAttackTab:Paragraph() +
--                MassAttackTab:Dropdown() + MassAttackTab:Toggle()
-- Gold-collector (StartDestroyWorker/StartGoldMagnet) TIDAK dimasukkan di sini
-- -> sudah ada di PANEL: MAIN
-- Global expose:
--   _setMaToggleGlobal, _setKillDDGlobal, _setDelayDDGlobal
--   _visMassAtk, _killDDIdxState, _delayDDIdxState
--   _maStatusPara (Paragraph widget untuk status)
--   _maMapSelState, _maMapItemRefs, _maUpdateMapDDLbl
-- Logika bisnis:
--   MA, MR, SKL, MAPS, FLa_PressKey (inline), MODE, _deadG, ORIGIN_POS
--   TpMap, GetEnemies, IsDead, SaveOrigin, ReturnHRPToOrigin
--   IsEnemyGuidValid, EnsureHeroAtkThreadFor (shared dengan FARM)
--   FireAllDamage, FireHeroRemotes, AttackLoop_Mass
--   WaitRaidDone, DoMassAttack
-- ============================================================================
do
    --  Global state (dibaca Config panel saat save/load) 
    -- Identik dengan deklarasi 1.lua baris ~1519, ~1792-1803
    MA = MA or {running=false, thread=nil, killed=0, killTarget=7, autoCollect=true}

    _killDDIdxState  = _killDDIdxState  or 1
    _delayDDIdxState = _delayDDIdxState or 2

    _setMaToggleGlobal = nil
    _setKillDDGlobal   = nil
    _setDelayDDGlobal  = nil
    _visMassAtk        = nil
    _maMapSelState     = nil
    _maMapItemRefs     = nil
    _maUpdateMapDDLbl  = nil
    _maStatusPara      = nil  -- WindUI Paragraph widget (ganti _maStatusLbl)

    --  MODE priority system (identik 1.lua baris ~1828) 
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

    --  Interrupt flags (identik 1.lua baris ~2000-2003) 
    if _raidInterrupt  == nil then _raidInterrupt  = false end
    if _ascInterrupt   == nil then _ascInterrupt   = false end
    if _siegeInterrupt == nil then _siegeInterrupt = false end

    --  Atomic map-enter lock (identik 1.lua baris ~1895) 
    if _MAP_ENTER_LOCK == nil then _MAP_ENTER_LOCK = nil end
    if _MAP_ENTER_LOCK_TIME == nil then _MAP_ENTER_LOCK_TIME = 0 end

    --  IsAnyMapActive (identik 1.lua baris ~1916) 
    if not IsAnyMapActive then
        function IsAnyMapActive()
            if RAID   and RAID.inMap            then return true, "raid"    end
            if ASC    and ASC.inMap             then return true, "asc"     end
            if SIEGE  and SIEGE.inMap           then return true, "siege"   end
            if ST2    and ST2.inMap             then return true, "st2"     end
            if _MAP_ENTER_LOCK ~= nil           then return true, _MAP_ENTER_LOCK end
            return false, nil
        end
    end

    --  MAPS + MR (identik 1.lua baris ~2021-2025) 
    local MAPS = {}
    for i = 1, 20 do
        MAPS[i] = {name="Map "..i, id=50000+i, remote=i<=4 and "Start" or "Local"}
    end
    MR = MR or {selected={}, nextMapDelay=3, teleportDelay=3}

    --  TpMap (identik 1.lua baris ~2027) 
    if not TpMap then
        function TpMap(m)
            MR.lastMapId = m.id
            if m.remote == "Start" then
                pcall(function() RE.StartTp:FireServer({mapId=m.id}) end)
            else
                pcall(function() RE.LocalTp:FireServer({mapId=m.id}) end)
            end
        end
    end

    --  FLa_PressKey inline (identik 1.lua baris ~244, tanpa compat-layer besar)
    -- Diperlukan oleh SKL / SkFireOnce
    if not FLa_PressKey then
        function FLa_PressKey(keyCode)
            -- Method 1: VirtualInputManager
            local ok1 = pcall(function()
                local VIM = game:GetService("VirtualInputManager")
                VIM:SendKeyEvent(true,  keyCode, false, game)
                task.wait(0.05)
                VIM:SendKeyEvent(false, keyCode, false, game)
            end)
            if ok1 then return true end
            -- Method 2: UIS fire (mobile-friendly fallback)
            local ok3 = pcall(function()
                local UIS = game:GetService("UserInputService")
                local io  = Instance.new("InputObject")
                io.KeyCode       = keyCode
                io.UserInputType = Enum.UserInputType.Keyboard
                io.UserInputState = Enum.UserInputState.Begin
                UIS.InputBegan:Fire(io, false)
                task.wait(0.05)
                io.UserInputState = Enum.UserInputState.End
                UIS.InputEnded:Fire(io, false)
            end)
            if ok3 then return true end
            return false
        end
    end

    --  SKL (identik 1.lua baris ~2037) 
    if not SKL then
        SKL = {
            Z={on=false,t=nil,label="Z"},
            X={on=false,t=nil,label="X"},
            C={on=false,t=nil,label="C"},
            V={on=false,t=nil,label="V"},
            F={on=false,t=nil,label="F"},
            type_map = {Z=1,X=2,C=3,V=4,F=5},
            key_map  = {Z=Enum.KeyCode.Z,X=Enum.KeyCode.X,C=Enum.KeyCode.C,V=Enum.KeyCode.V,F=Enum.KeyCode.F},
            ui = {},
        }
    end

    local function PK(k) FLa_PressKey(k) end

    if not SkFireOnce then
        function SkFireOnce(n) PK(SKL.key_map[n]) end
    end

    if not SkSetUI then
        function SkSetUI(n, on)
            local u = SKL.ui[n]; if not u then return end
            u.btn.BackgroundColor3 = on and Color3.fromRGB(180,65,5) or Color3.fromRGB(30,30,30)
            u.lbl.Text = on and "ON" or "OFF"
            u.lbl.TextColor3 = on and Color3.fromRGB(255,255,255) or Color3.fromRGB(180,180,180)
            local stk = u.btn:FindFirstChildWhichIsA("UIStroke")
            if stk then
                stk.Color       = on and Color3.fromRGB(255,200,50) or Color3.fromRGB(80,80,80)
                stk.Transparency = on and 0 or 0.3
            end
        end
    end

    if not SkOn then
        function SkOn(n)
            local s = SKL[n]; if s.t then return end
            s.on = true; SkSetUI(n, true)
            s.t = task.spawn(function()
                while s.on do SkFireOnce(n); task.wait(0.8) end
                s.t = nil
            end)
        end
    end

    if not SkOff then
        function SkOff(n)
            local s = SKL[n]; s.on = false; SkSetUI(n, false)
            if s.t then pcall(function() task.cancel(s.t) end); s.t = nil end
        end
    end

    -- Keyboard listener Z/X/C/V/F toggle (identik 1.lua baris ~2108)
    if not _sklKeyListenerBound then
        _sklKeyListenerBound = true
        game:GetService("UserInputService").InputBegan:Connect(function(input, gameProcessed)
            if gameProcessed then return end
            local keyMap = {
                [Enum.KeyCode.Z]="Z", [Enum.KeyCode.X]="X",
                [Enum.KeyCode.C]="C", [Enum.KeyCode.V]="V", [Enum.KeyCode.F]="F",
            }
            local n = keyMap[input.KeyCode]; if not n then return end
            if SKL[n].on then SkOff(n) else SkOn(n) end
        end)
    end

    --  _deadG + SaveOrigin + ReturnHRPToOrigin (identik 1.lua baris ~2161)
    local _deadG = {}
    local ORIGIN_POS = Vector3.new(0, 0, 0)

    local function SaveOrigin()
        local char = LP.Character; if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then ORIGIN_POS = hrp.Position end
    end

    local function ReturnHRPToOrigin()
        local char = LP.Character; if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then hrp.CFrame = CFrame.new(ORIGIN_POS) end
    end

    --  IsEnemyGuidValid (identik 1.lua baris ~2195) 
    local function IsEnemyGuidValid(g)
        if not g then return false end
        local ENEMY_FOLDERS = {"Enemys","EnemyCityRaid","CityRaidEnemys","Enemies","Enemy"}
        for _, folderName in ipairs(ENEMY_FOLDERS) do
            local f = workspace:FindFirstChild(folderName)
            if f then
                for _, e in ipairs(f:GetChildren()) do
                    if e:IsA("Model") and e:GetAttribute("EnemyGuid") == g then
                        local hrp = e:FindFirstChild("HumanoidRootPart")
                        local hum = e:FindFirstChildOfClass("Humanoid")
                        if hrp and hum and hum.Health > 0 then return true end
                        return false
                    end
                end
            end
        end
        pcall(function()
            local mapF = workspace:FindFirstChild("Map")
            local cre  = mapF and mapF:FindFirstChild("CityRaidEnter")
            if cre then
                for _, e in ipairs(cre:GetDescendants()) do
                    if e:IsA("Model") and e:GetAttribute("EnemyGuid") == g then
                        local hrp = e:FindFirstChild("HumanoidRootPart")
                        local hum = e:FindFirstChildOfClass("Humanoid")
                        if hrp and hum and hum.Health > 0 then return true end
                    end
                end
            end
        end)
        return false
    end

    --  EnsureHeroAtkThreadFor per-GUID (identik 1.lua baris ~2224)
    -- Shared dengan FARM (jika sudah ada tidak buat ulang)
    local _heroAtkThreads_MA = {}
    local function EnsureHeroAtkThreadFor_MA(g)
        if not g then return end
        if _heroAtkThreads_MA[g] and _heroAtkThreads_MA[g].running then return end
        local handle = {running=true, tick=0}
        _heroAtkThreads_MA[g] = handle
        task.spawn(function()
            local _lastFire = {}
            while handle.running and ScreenGui and ScreenGui.Parent do
                if #HERO_GUIDS > 0 and (tick()-handle.tick) >= 0.5 and IsEnemyGuidValid(g) then
                    handle.tick = tick()
                    for _, hGuid in ipairs(HERO_GUIDS) do
                        local last = _lastFire[hGuid] or 0
                        if (tick()-last) >= 0.05 then
                            _lastFire[hGuid] = tick()
                            if RE.HeroUseSkill then
                                pcall(function() RE.HeroUseSkill:FireServer({heroGuid=hGuid,attackType=1,userId=MY_USER_ID,enemyGuid=g}) end)
                                PG_Wait(0.1)
                                pcall(function() RE.HeroUseSkill:FireServer({heroGuid=hGuid,attackType=2,userId=MY_USER_ID,enemyGuid=g}) end)
                                PG_Wait(0.1)
                                pcall(function() RE.HeroUseSkill:FireServer({heroGuid=hGuid,attackType=3,userId=MY_USER_ID,enemyGuid=g}) end)
                            end
                        end
                        PG_Wait(0.05)
                    end
                end
                PG_Wait(0.05)
                if not IsEnemyGuidValid(g) then
                    handle.running = false
                end
            end
            _heroAtkThreads_MA[g] = nil
        end)
    end

    --  GetEnemies (identik 1.lua baris ~2119) 
    local function GetEnemies()
        local list = {}
        local _curMap = pcall(function()
            return workspace:GetAttribute("MapId") or workspace:GetAttribute("mapId") or workspace:GetAttribute("CurrentMapId")
        end)
        do
            local ok, wm = pcall(function()
                return workspace:GetAttribute("MapId") or workspace:GetAttribute("mapId") or workspace:GetAttribute("CurrentMapId")
            end)
            if ok and type(wm) == "number" then
                local _inRaid    = wm >= 50101 and wm <= 50120
                local _inAsc     = wm >= 50301 and wm <= 50326
                local _inSiege   = wm >= 50201 and wm <= 50204
                local _inAnniv   = wm == 50401
                if _inRaid or _inAsc or _inSiege or _inAnniv then
                    return list
                end
            end
        end
        local ENEMY_FOLDERS = {"Enemys","EnemyCityRaid","CityRaidEnemys","Enemies","Enemy"}
        local seen = {}
        local MA_ATTACK_RADIUS = 2000
        local _lp = game:GetService("Players").LocalPlayer
        local _playerPos = nil
        if _lp and _lp.Character then
            local _hrp = _lp.Character:FindFirstChild("HumanoidRootPart")
            if _hrp then _playerPos = _hrp.Position end
        end
        local function _addEnemy(e)
            if not e:IsA("Model") then return end
            local g   = e:GetAttribute("EnemyGuid") or e:GetAttribute("BossGuid") or e:GetAttribute("Guid") or e:GetAttribute("GUID")
            local h   = e:FindFirstChild("HumanoidRootPart")
            local hum = e:FindFirstChildOfClass("Humanoid")
            if g and h and hum and hum.Health > 0 and not seen[g] then
                -- Filter radius 2000 studs dari posisi player
                if _playerPos and (h.Position - _playerPos).Magnitude > MA_ATTACK_RADIUS then return end
                seen[g] = true
                table.insert(list, {model=e, guid=g, hrp=h})
            end
        end
        for _, folderName in ipairs(ENEMY_FOLDERS) do
            local f = workspace:FindFirstChild(folderName)
            if f then for _, e in ipairs(f:GetChildren()) do _addEnemy(e) end end
        end
        if #list == 0 then
            for _, obj in ipairs(workspace:GetChildren()) do _addEnemy(obj) end
        end
        return list
    end

    --  IsDead (identik 1.lua baris ~2155) 
    local function IsDead(e)
        if _deadG[e.guid] then return true end
        if not e.model or not e.model.Parent then return true end
        local h = e.model:FindFirstChildOfClass("Humanoid")
        return not h or h.Health <= 0
    end

    --  FireAllDamage (identik 1.lua baris ~2284) 
    local function FireAllDamage(g, ep)
        if not IsEnemyGuidValid(g) then return end
        if RE.Click then
            task.spawn(function()
                pcall(function() RE.Click:InvokeServer({enemyGuid=g}) end)
            end)
        end
        if RE.Atk then
            pcall(function() RE.Atk:FireServer({attackEnemyGUID=g}) end)
        end
        EnsureHeroAtkThreadFor_MA(g)
        if not RE.HeroUseSkill and RE.HeroSkill then
            for _, hGuid in ipairs(HERO_GUIDS) do
                pcall(function() RE.HeroSkill:FireServer({heroGuid=hGuid,enemyGuid=g,skillType=1,masterId=MY_USER_ID}) end)
                pcall(function() RE.HeroSkill:FireServer({heroGuid=hGuid,enemyGuid=g,skillType=2,masterId=MY_USER_ID}) end)
                pcall(function() RE.HeroSkill:FireServer({heroGuid=hGuid,enemyGuid=g,skillType=3,masterId=MY_USER_ID}) end)
            end
        end
    end

    --  FireHeroRemotes (identik 1.lua baris ~2313) 
    local function FireHeroRemotes(enemyGuid, enemyPos)
        local pos = enemyPos or Vector3.new(0,0,0)
        if #HERO_GUIDS == 0 then return end
        local posInfos = {}
        for _, hGuid in ipairs(HERO_GUIDS) do
            table.insert(posInfos, {heroGuid=hGuid, targetPos=pos})
        end
        if RE.HeroMove then
            pcall(function() RE.HeroMove:FireServer({attackTarget=enemyGuid,userId=MY_USER_ID,heroTagetPosInfos=posInfos}) end)
            pcall(function() RE.HeroMove:FireServer({attackTarget=enemyGuid,userId=MY_USER_ID,heroTagetPosInfos=posInfos}) end)
        end
    end

    --  RE.Death listener untuk MA.killed (identik 1.lua baris ~2333)
    -- Guard: jangan bind dua kali
    if not _maDeathListenerBound then
        _maDeathListenerBound = true
        if RE.Death then
            RE.Death.OnClientEvent:Connect(function(d)
                if not d then return end
                local g = d.enemyGuid or d.guid
                if g then
                    _deadG[g] = true
                    if MA.running
                        and not (SIEGE  and SIEGE.inMap)
                        and not (RAID   and RAID.inMap)
                        and not (ST2    and ST2.running)
                    then
                        MA.killed = MA.killed + 1
                    end
                end
            end)
        end
    end

    --  AttackLoop_Mass (identik 1.lua baris ~2491) 
    local function AttackLoop_Mass(onStatus)
        _deadG = {}
        -- FASE 1: Tunggu musuh muncul maks 10 detik
        local wt = 0
        while wt < 10 and MA.running do
            if #GetEnemies() > 0 then break end
            if onStatus then onStatus("Nunggu musuh... ("..math.floor(10-wt).."s)") end
            task.wait(0.4); wt = wt + 0.4
        end
        if not MA.running then return false end
        if #GetEnemies() == 0 then
            if onStatus then onStatus("Kosong, skip map...") end
            return true
        end

        -- FASE 2: Attack loop
        local start    = MA.killed
        local lastKill = MA.killed
        local stuckT   = 0
        local STUCK_LIMIT = 5.0

        while MA.running do
            -- Guard IsAnyMapActive
            do
                local _mBusy, _mWho = IsAnyMapActive()
                if _mBusy then return "interrupted" end
            end
            -- Guard interrupt flags lama (kompatibilitas)
            do local _ni=(MODE.current~="idle" and MODE.current~="ma") or _raidInterrupt or _siegeInterrupt or (ST2 and ST2.running) or (SIEGE and SIEGE.inMap); if _ni then return "interrupted" end end
            -- Guard: hanya serang di basemap 50001-50020
            do
                local ok, wm = pcall(function()
                    return workspace:GetAttribute("MapId") or workspace:GetAttribute("mapId") or workspace:GetAttribute("CurrentMapId")
                end)
                if ok and type(wm) == "number" then
                    if wm < 50001 or wm > 50020 then return "interrupted" end
                end
            end

            local isAll = (MA.killTarget == 0)
            local here  = MA.killed - start

            local alive = 0
            for _, e in ipairs(GetEnemies()) do
                if not IsDead(e) then alive = alive + 1 end
            end

            -- Kondisi keluar A: semua musuh habis
            if alive == 0 then
                if onStatus then onStatus("[OK] Semua musuh habis!") end
                return true
            end
            -- Kondisi keluar B: kill target terpenuhi
            if not isAll and here >= MA.killTarget then
                if onStatus then onStatus("[OK] Target "..MA.killTarget.." tercapai!") end
                return true
            end

            -- Update status
            if isAll then
                if onStatus then onStatus("Kill All: "..alive.." sisa") end
            else
                if onStatus then onStatus(alive.." hidup | "..here.."/"..MA.killTarget) end
            end

            -- Stuck check
            if MA.killed > lastKill then
                lastKill = MA.killed; stuckT = 0
            else
                stuckT = stuckT + 0.08
                if stuckT >= STUCK_LIMIT then
                    if onStatus then onStatus("[!] Stuck "..STUCK_LIMIT.."s, skip map...") end
                    return true
                end
            end

            -- Serang semua musuh hidup
            for _, e in ipairs(GetEnemies()) do
                if not IsDead(e) then
                    local hrp = e.model and e.model:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        local g, p = e.guid, hrp.Position
                        task.spawn(function()
                            FireAllDamage(g, p)
                            FireHeroRemotes(g, p)
                        end)
                    end
                end
            end
            PG_Wait(0.08)
        end
        return false
    end

    --  WaitRaidDone (identik 1.lua baris ~2827) 
    local function WaitRaidDone()
        local t = 0
        local function shouldPause()
            if MODE.current == "siege" or (SIEGE and SIEGE.inMap) or _siegeInterrupt then
                return true, "Auto Siege"
            end
            if RAID and RAID.running then
                if _raidInterrupt or (MODE.current == "raid" and RAID.inMap) or RAID.inMap then
                    return true, "Auto Raid"
                end
            end
            if ASC and (_ascInterrupt or ASC.inMap) then
                return true, "Auto Ascension"
            end
            return false, nil
        end

        local pause, reason = shouldPause()
        while pause and MA.running do
            t = t + 0.5
            if t >= 120 then
                if MODE.current ~= "idle" and MODE.current ~= "ma" then
                    MODE.current = "idle"
                end
                break
            end
            local label = reason or "Other Feature"
            -- Update status via Paragraph (WindUI API, ganti _maStatusLbl.Text)
            if _maStatusPara then
                pcall(function() _maStatusPara:SetDesc("[||] Pause ("..label..") - "..math.floor(t).."s") end)
            end
            task.wait(0.5)
            pause, reason = shouldPause()
        end
        if MA.running then task.wait(0.5) end
        if _maStatusPara and MA.running then
            pcall(function() _maStatusPara:SetDesc("> Continue After pause...") end)
        end
    end

    --  DoMassAttack (identik 1.lua baris ~2914) 
    function DoMassAttack(on)
        if on then
            _mOn = true
            MA.running = true
            MA.killed  = 0
            MA.collected = 0
            -- Gold collector dipakai dari MAIN (StartDestroyWorker/StartGoldMagnet)
            -- Cukup panggil jika fungsi tersedia
            if StartGoldMagnet then
                if StopGoldMagnet then StopGoldMagnet() end
                StartGoldMagnet(function() return MA.running end)
            end
            if StartInstantGoldCollector then StartInstantGoldCollector(true) end
            if StartDestroyWorker then StartDestroyWorker(function() return MA.running end) end

            MA.thread = task.spawn(function()
                local _maStart = os.time()
                local function maStatus(msg)
                    if _maStatusPara then
                        local dur = os.time() - _maStart
                        local ts  = string.format("%02d:%02d:%02d",
                            math.floor(dur/3600), math.floor(dur/60)%60, dur%60)
                        pcall(function() _maStatusPara:SetDesc("["..ts.."] "..msg) end)
                    end
                end

                while MA.running do
                    -- Pause kalau ada fitur prioritas lebih tinggi
                    do local _np=(MODE.current~="idle" and MODE.current~="ma") or _raidInterrupt or _siegeInterrupt or _ascInterrupt or (ST2 and ST2.running); if _np then WaitRaidDone() end end
                    if not MA.running then break end

                    local mapsToUse = {}
                    for i = 1, 20 do
                        if MR.selected[i] then table.insert(mapsToUse, MAPS[i]) end
                    end

                    if #mapsToUse == 0 then
                        -- Mode tanpa rotasi map: serang di map sekarang
                        local cont = AttackLoop_Mass(function(msg) maStatus(msg) end)
                        if cont == "interrupted" then
                            WaitRaidDone()
                        elseif not cont or not MA.running then
                            break
                        end
                        do local _np=(MODE.current~="idle" and MODE.current~="ma") or _raidInterrupt or _siegeInterrupt or _ascInterrupt or (ST2 and ST2.running); if _np then WaitRaidDone() end end
                        task.wait(MR.nextMapDelay)
                    else
                        -- Mode rotasi map: loop memutar semua map yang dipilih
                        local _mapIdx = 1
                        while MA.running do
                            repeat
                                -- Rebuild fresh list tiap iterasi (respon perubahan selection)
                                local _fresh = {}
                                for i = 1, 20 do
                                    if MR.selected[i] then table.insert(_fresh, MAPS[i]) end
                                end
                                if #_fresh == 0 then mapsToUse = {}; break end
                                if _mapIdx > #_fresh then _mapIdx = 1 end
                                local m = _fresh[_mapIdx]

                                do local _np=(MODE.current~="idle" and MODE.current~="ma") or _raidInterrupt or _siegeInterrupt or _ascInterrupt or (ST2 and ST2.running); if _np then WaitRaidDone() end end
                                if not MA.running then break end
                                if _raidInterrupt then _mapIdx = _mapIdx + 1; break end

                                maStatus("-> TP ke "..m.name.."...")
                                TpMap(m)
                                task.wait(MR.teleportDelay)
                                if not MA.running then break end

                                local cont = AttackLoop_Mass(function(msg)
                                    maStatus("["..m.name.."] "..msg)
                                end)
                                if cont == "interrupted" then
                                    WaitRaidDone()
                                elseif not cont or not MA.running then
                                    break
                                end

                                do local _np=(MODE.current~="idle" and MODE.current~="ma") or _raidInterrupt or _siegeInterrupt or _ascInterrupt or (ST2 and ST2.running); if _np then WaitRaidDone() end end
                                if not MA.running then break end

                                maStatus("[OK] SUCCES "..m.name.." - Go to...")
                                task.wait(MR.nextMapDelay)
                                _mapIdx = _mapIdx + 1
                                if _mapIdx > #_fresh then _mapIdx = 1 end
                            until true
                        end
                    end
                end

                _mOn = false
                MA.running = false

                if _maStatusPara then
                    pcall(function() _maStatusPara:SetDesc("[.] IDLE") end)
                end
                if StartInstantGoldCollector then StartInstantGoldCollector(false) end
                if StopGoldMagnet then StopGoldMagnet() end
            end)
        else
            _mOn = false; MA.running = false
            if MA.thread then
                pcall(function() task.cancel(MA.thread) end)
                MA.thread = nil
            end
            if _maStatusPara then
                pcall(function() _maStatusPara:SetDesc("Idle") end)
            end
            if StartInstantGoldCollector then StartInstantGoldCollector(false) end
            if StopGoldMagnet then StopGoldMagnet() end
        end
    end

    -- =========================================================================
    -- WindUI ELEMENTS  (MassAttackTab)
    -- API: Tab:Section(), Tab:Paragraph(), Tab:Dropdown(), Tab:Toggle()
    -- =========================================================================

    --  Section header 
    MassAttackTab:Section({ Title = "Mass Attack" })

    --  Status paragraph (ganti _maStatusLbl dari 1.lua) 
    local statusPara = MassAttackTab:Paragraph({
        Title = "Status",
        Desc  = "Idle",
    })
    _maStatusPara = statusPara   -- expose global agar WaitRaidDone bisa update

    --  TARGET KILL dropdown (identik 1.lua baris ~6870) 
    -- WindUI Dropdown, Multi=false, Value=nil (bukan {})
    local _killOptVals  = {5, 10, 15, 20, 0}
    local _killOptNames = {"5", "10", "15", "20", "Kill All"}
    local killDD = MassAttackTab:Dropdown({
        Flag    = "maKillDD",
        Title   = "Target Kill",
        Desc    = "Jumlah kill sebelum pindah map",
        Multi   = false,
        Value   = nil,
        Values  = _killOptNames,
        Callback = function(val)
            -- Cari nilai dari nama
            for i, name in ipairs(_killOptNames) do
                if name == val then
                    MA.killTarget = _killOptVals[i]
                    _killDDIdxState = i
                    break
                end
            end
        end,
    })
    -- Expose setter (diperlukan Config restore)
    _setKillDDGlobal = function(idx)
        _killDDIdxState = idx
        if _killOptNames[idx] then
            pcall(function() killDD:SetValue(_killOptNames[idx]) end)
            MA.killTarget = _killOptVals[idx]
        end
    end
    -- Set default dari state tersimpan
    if _killOptNames[_killDDIdxState] then
        pcall(function() killDD:SetValue(_killOptNames[_killDDIdxState]) end)
        MA.killTarget = _killOptVals[_killDDIdxState]
    end

    --  Rotation Map dropdown (Multi, identik 1.lua baris ~6895) 
    local _mapOptNames = {"ALL MAP"}
    for i = 1, 20 do _mapOptNames[i+1] = "Map "..i end

    local mapSelSet   = {}
    local mapItemRefs = {}
    _maMapSelState  = mapSelSet
    _maMapItemRefs  = mapItemRefs

    -- Track apakah ALL MAP ada di selection iterasi sebelumnya
    local _prevHadAll = false

    local mapDD  -- forward ref untuk :Select() di dalam callback

    local _, mapDD = MassAttackTab:Dropdown({
        Flag     = "maMapDD",
        Title    = "Rotation Map",
        Desc     = "Pilih map untuk dirotasi (kosong = map sekarang)",
        Multi    = true,
        Value    = {},
        Values   = _mapOptNames,
        Callback = function(val)
            -- val = ap.Value saat ini (full array setelah klik)
            local hasAll = false
            if type(val) == "table" then
                for _, v in ipairs(val) do
                    if v == "ALL MAP" then hasAll = true; break end
                end
            end

            if hasAll and not _prevHadAll then
                -- ALL MAP baru di-CHECK: select semua Map 1-20 + update visual
                _prevHadAll = true
                for i = 1, 20 do mapSelSet[i] = true; MR.selected[i] = true end
                -- Force visual: inject semua Map 1-20 ke ap.Value via :Select()
                local allVal = {"ALL MAP"}
                for i = 1, 20 do table.insert(allVal, "Map "..i) end
                task.defer(function()
                    pcall(function() mapDD:Select(nil, allVal) end)
                end)

            elseif not hasAll and _prevHadAll then
                -- ALL MAP baru di-UNCHECK: clear semua
                _prevHadAll = false
                for i = 1, 20 do mapSelSet[i] = nil; MR.selected[i] = nil end
                -- Force visual: kosongkan semua via :Select(nil, nil)  ap.Value={}
                task.defer(function()
                    pcall(function() mapDD:Select(nil, {}) end)
                end)

            elseif hasAll and _prevHadAll then
                -- ALL MAP masih ada, user pilih Map individual tambahan  biarkan
                for i = 1, 20 do mapSelSet[i] = true; MR.selected[i] = true end

            else
                -- Mode pilihan manual biasa (tanpa ALL MAP)
                _prevHadAll = false
                for i = 1, 20 do mapSelSet[i] = nil; MR.selected[i] = nil end
                if type(val) == "table" then
                    for _, v in ipairs(val) do
                        local mi = tonumber(v:match("Map (%d+)"))
                        if mi then mapSelSet[mi] = true; MR.selected[mi] = true end
                    end
                end
            end
        end,
    })

    _maUpdateMapDDLbl = function()
        -- Sync visual dropdown map sesuai _maMapSelState saat ini
        -- Dipakai oleh ApplyConfig setelah restore data mapSel
        if not mapDD then return end
        pcall(function()
            local selVals = {}
            local allOn = true
            for i = 1, 20 do
                if mapSelSet[i] then
                    table.insert(selVals, "Map "..i)
                else
                    allOn = false
                end
            end
            if allOn and #selVals == 20 then
                table.insert(selVals, 1, "ALL MAP")
                _prevHadAll = true
            else
                _prevHadAll = false
            end
            mapDD:Select(nil, selVals)
        end)
    end

    --  DELAY PINDAH MAP dropdown (identik 1.lua baris ~6944) 
    local _delayOptVals  = {1, 3, 5, 7, 10}
    local _delayOptNames = {"1", "3", "5", "7", "10"}
    local delayDD = MassAttackTab:Dropdown({
        Flag    = "maDelayDD",
        Title   = "Delay Pindah Map",
        Desc    = "Detik tunggu sebelum pindah ke map berikutnya",
        Multi   = false,
        Value   = nil,
        Values  = _delayOptNames,
        Callback = function(val)
            for i, name in ipairs(_delayOptNames) do
                if name == val then
                    MR.nextMapDelay = _delayOptVals[i]
                    _delayDDIdxState = i
                    break
                end
            end
        end,
    })
    _setDelayDDGlobal = function(idx)
        _delayDDIdxState = idx
        if _delayOptNames[idx] then
            pcall(function() delayDD:SetValue(_delayOptNames[idx]) end)
            MR.nextMapDelay = _delayOptVals[idx]
        end
    end
    if _delayOptNames[_delayDDIdxState] then
        pcall(function() delayDD:SetValue(_delayOptNames[_delayDDIdxState]) end)
        MR.nextMapDelay = _delayOptVals[_delayDDIdxState]
    end

    --  MASS ATTACK master toggle (identik 1.lua baris ~7018) 
    MassAttackTab:Section({ Title = "Control" })

    local maToggle = MassAttackTab:Toggle({
        Flag     = "maToggle",
        Title    = "Mass Attack",
        Desc     = "Serang semua musuh di map sekaligus",
        Default  = false,
        Callback = function(on)
            DoMassAttack(on)
        end,
    })
    -- Expose setter dan visual toggle (kompatibilitas Config panel)
    _setMaToggleGlobal = function(on)
        pcall(function() maToggle:SetValue(on) end)
        DoMassAttack(on)
    end
    _visMassAtk = function(on)
        pcall(function() maToggle:SetValue(on) end)
    end

    --  AUTO SKILL section (identik 1.lua baris ~6954 skillCard) 
    MassAttackTab:Section({ Title = "Auto Skill" })

    local _skillKeys = {
        {n="Z", desc="Skill slot Z"},
        {n="X", desc="Skill slot X"},
        {n="C", desc="Skill slot C"},
        {n="V", desc="Skill slot V"},
        {n="F", desc="Skill slot F"},
    }
    -- Simpan elemen toggle per skill key agar bisa di-set saat restore Config
    local _skillToggleEls = {}
    for _, sk in ipairs(_skillKeys) do
        local key = sk.n
        local el = MassAttackTab:Toggle({
            Flag     = "maSkill_"..key,
            Title    = "Auto Skill "..key,
            Desc     = sk.desc,
            Default  = false,
            Callback = function(on)
                if on then SkOn(key) else SkOff(key) end
            end,
        })
        _skillToggleEls[key] = el
    end

    -- Expose setter skill visual ke global (dibaca Config panel saat restore)
    -- ApplyConfig memanggil SkOn/SkOff langsung untuk logika,
    -- tapi visual toggle WindUI perlu di-sync secara terpisah
    _setSkillToggleVis = function(key, v)
        local el = _skillToggleEls[key]
        if el then pcall(function() el:Set(v, false) end) end
    end

end -- end do PANEL: MASS ATTACK



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
if not FireHeroRemotes then
    function FireHeroRemotes(enemyGuid, enemyPos)
        local pos = enemyPos or Vector3.new(0,0,0)
        if #HERO_GUIDS == 0 then return end
        local posInfos = {}
        for _, hGuid in ipairs(HERO_GUIDS) do
            table.insert(posInfos, {heroGuid=hGuid, targetPos=pos})
        end
        if RE.HeroMove then
            pcall(function() RE.HeroMove:FireServer({attackTarget=enemyGuid,userId=MY_USER_ID,heroTagetPosInfos=posInfos}) end)
            pcall(function() RE.HeroMove:FireServer({attackTarget=enemyGuid,userId=MY_USER_ID,heroTagetPosInfos=posInfos}) end)
        end
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
-- Section slide up/down persis seperti 1.lua, menggunakan AutomationTab
-- ============================================================================

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
_setAscToggle    = nil
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
task.spawn(function()
    local lastRef = Remotes:FindFirstChild("UpdateRaidInfo")
    while true do
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

                -- [BLOCKED MAP v2] Map 1 dan 3 diblokir TOTAL di AUTO RAID Normal (semua mode & fallback).
                -- Easy   : kecualikan map 1 dan 3
                -- Default: kecualikan map 1, 3, dan 8
                local EASY_EXCLUDE_MAPS = {[1]=true, [3]=true}
                local DEFAULT_EXCLUDE_MAPS = {[1]=true, [3]=true, [8]=true}

                -- [RAID LIST ENTRY] Cek List Entry dulu sebelum logika normal
                if RAID.listEnabled and #RAID.listEntries > 0 then
                    local listResult = ResolveEntryFromList()
                    if listResult then
                        return listResult
                    end
                    -- [BLOCKED MAP v2] Tidak ada match -> fallback Easy (map terkecil)
                    -- Map 1 dan 3 diblokir TOTAL di seluruh AUTO RAID Normal, tanpa pengecualian.
                    local easyList = {}
                    for _, r in ipairs(RAID_ID_LIST) do
                        local isAsc = r.isAscension == true or (r.id and r.id >= 935001)
                        if not isAsc then
                            local live = r.id and RAID_LIVE[r.id]
                            if not (live and live.isAscension == true) then
                                local mn = r.mapId - 50000
                                if not EASY_EXCLUDE_MAPS[mn] then
                                    table.insert(easyList, r)
                                end
                            end
                        end
                    end
                    if #easyList > 0 then
                        table.sort(easyList, function(a, b) return a.mapId < b.mapId end)
                        return easyList[1]
                    end
                    return nil
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

                local pm = RAID.pickMode or "default"
                local runeOn = RAID.runeEnabled
                local runeTarget = runeOn and RAID.runeMapTarget or 0
                local hasPick = (pm == "byrank" or pm == "manual") and next(RAID.runeGrades) ~= nil

                -- [FIX] Helper grade yang sadar Ascension (pakai key cache negatif untuk AT)
                local function _getGrade(r)
                    return GetBestGrade(r.mapId - 50000, r.isAscension == true)
                end

                -- [Ascension Mode] Filter RAID_ID_LIST sesuai mode sebelum dipakai pick mode apapun
                local _filteredList = {}
                for _, r in ipairs(RAID_ID_LIST) do
                    if _ascFilter(r) then
                        table.insert(_filteredList, r)
                    end
                end
                -- Gunakan filtered list sebagai sumber utama semua pick mode
                local RAID_ID_LIST = _filteredList

                local function pickLowest(list)
                    table.sort(list, function(a, b) return a.mapId < b.mapId end)
                    return list[1]
                end

-- [LOGIKA MANUAL MODE DEWA]
                if pm == "manual" then
                    RAID.manualMatchMode = "none" -- Status: "primary", "updown", atau "fallback"
                    local valid_raids = {}
                    local hasPreferMaps = next(RAID.preferMaps) ~= nil

                    -- 1. Wadah/Gerbang: Ambil semua map yang diizinkan
                    for _, r in ipairs(RAID_ID_LIST) do
                        local mn = r.mapId - 50000
                        if not hasPreferMaps or RAID.preferMaps[mn] then
                            table.insert(valid_raids, r)
                        end
                    end
                    if #valid_raids == 0 then return nil end

                    -- Helper: Sort dari Rank tertinggi ke terendah
                    local function sortHighestRank(list)
                        table.sort(list, function(a, b)
                            local ga = _getGrade(a) or "?"
                            local gb = _getGrade(b) or "?"
                            local ra = GRADE_RANK[ga] or 0
                            local rb = GRADE_RANK[gb] or 0
                            if ra == rb then return a.mapId < b.mapId end 
                            return ra > rb 
                        end)
                    end

                    -- 2. TAHAP 1: Cari kecocokan Preferred Rank
                    local matched = {}
                    local hasPreferRank = next(RAID.runeGrades) ~= nil
                    if hasPreferRank then
                        for _, r in ipairs(valid_raids) do
                            local grade = _getGrade(r)
                            if grade and RAID.runeGrades[grade] then
                                table.insert(matched, r)
                            end
                        end
                    end

                    if #matched > 0 then
                        -- MATCH UTAMA KETEMU
                        sortHighestRank(matched)
                        RAID.manualMatchMode = "primary"
                        return matched[1]
                    end

                    -- 3. TAHAP 2: Jika Preferred Rank GAGAL, cari Target UP/DOWN di lobi!
                    if RAID.updownEnabled and RAID.updownTargetGrade then
                        local udMatched = {}
                        for _, r in ipairs(valid_raids) do
                            local grade = _getGrade(r)
                            if grade == RAID.updownTargetGrade then
                                table.insert(udMatched, r)
                            end
                        end
                        if #udMatched > 0 then
                            -- KETEMU MANGSA UP/DOWN!
                            sortHighestRank(udMatched)
                            RAID.manualMatchMode = "updown"
                            return udMatched[1]
                        end
                    end

                    -- 4. TAHAP 3: "Jangan Maksa Dong!" -> Fallback murni ke map terkecil
                    -- [BLOCKED MAP v2] Blokir Map 1 dan 3 bahkan di fallback Manual Mode.
                    RAID.manualMatchMode = "fallback"
                    local manualFiltered = {}
                    for _, r in ipairs(valid_raids) do
                        local mn = r.mapId - 50000
                        if not EASY_EXCLUDE_MAPS[mn] then table.insert(manualFiltered, r) end
                    end
                    if #manualFiltered == 0 then return nil end
                    table.sort(manualFiltered, function(a, b) return a.mapId < b.mapId end)
                    return manualFiltered[1]
                end

                -- [BLOCKED MAP v2] Map 1 dan 3 DIBLOKIR TOTAL di semua pick mode AUTO RAID Normal.
                -- Easy   : kecualikan map 1 dan 3 (dimulai dari Map 2)
                -- Default: kecualikan map 1, 3, dan 8 (dimulai dari Map 2)
                -- Manual : kecualikan map 1 dan 3 di semua tahap termasuk Fallback
                -- Semua Fallback (List, Manual, pickByDiff) ikut aturan yang sama.
                local EASY_EXCLUDE_MAPS = {[1]=true, [3]=true}
                local DEFAULT_EXCLUDE_MAPS = {[1]=true, [3]=true, [8]=true}

                local function pickByDiff(list)
                    if #list == 0 then return nil end
                    if pm == "easy" then
                        -- [BLOCKED MAP v2] Map 1 dan 3 diblokir TOTAL. Dimulai dari Map 2 (terkecil berikutnya).
                        -- Tidak ada fallback ke list asli  Map 1 & 3 tidak akan pernah dipilih.
                        local easyFiltered = {}
                        for _, r in ipairs(list) do
                            local mn = r.mapId - 50000
                            if not EASY_EXCLUDE_MAPS[mn] then table.insert(easyFiltered, r) end
                        end
                        if #easyFiltered == 0 then return nil end
                        table.sort(easyFiltered, function(a, b) return a.mapId < b.mapId end)
                        return easyFiltered[1]
                    elseif pm == "hard" then
                        table.sort(list, function(a, b) return a.mapId > b.mapId end)
                        return list[1]
                    elseif pm == "default" then
                        local maps1to8 = {}
                        for _, r in ipairs(list) do
                            local mn = r.mapId - 50000
                            -- [EXCLUDE MAP] Pool asli 1-8, lalu buang map yang dikecualikan
                            if mn >= 1 and mn <= 8 and not DEFAULT_EXCLUDE_MAPS[mn] then
                                table.insert(maps1to8, r)
                            end
                        end
                        if #maps1to8 == 0 then return nil end 
                        table.sort(maps1to8, function(a, b) return a.mapId < b.mapId end)
                        _defaultRRIdx = _defaultRRIdx + 1
                        if _defaultRRIdx > #maps1to8 then _defaultRRIdx = 1 end
                        return maps1to8[_defaultRRIdx]
                    elseif pm == "byrank" then
                        table.sort(list, function(a, b)
                            local ga = _getGrade(a) or "?"
                            local gb = _getGrade(b) or "?"
                            local ra = GRADE_RANK[ga] or 0
                            local rb = GRADE_RANK[gb] or 0
                            if ra == rb then return a.mapId < b.mapId end 
                            return ra > rb 
                        end)
                        return list[1]
                    elseif pm == "bymap" then
                        table.sort(list, function(a, b) return a.mapId < b.mapId end)
                        for _, r in ipairs(list) do
                            if RAID.preferMaps[r.mapId - 50000] then return r end
                        end
                        return list[1]
                    end
                    table.sort(list, function(a, b) return a.mapId < b.mapId end)
                    return list[1]
                end

                if not IsRaidLiveInGame() then
                    RAID_LIVE = {}; RAID_ID_LIST = {}; _defaultRRIdx = 0
                    if RebuildRaidList then pcall(RebuildRaidList) end
                    return nil
                end

                if hasPick then
                    local matched2 = {}
                    for _, r in ipairs(RAID_ID_LIST) do
                        local grade = _getGrade(r)
                        if grade and RAID.runeGrades[grade] == true then table.insert(matched2, r) end
                    end
                    if #matched2 > 0 then
                        local chosen = pickByDiff(matched2)
                        if chosen then return chosen end
                    end
                    if pm == "byrank" then return nil end
                end

                if pm == "bymap" and next(RAID.preferMaps) ~= nil then
                    local mapMatched = {}
                    for _, r in ipairs(RAID_ID_LIST) do
                        if RAID.preferMaps[r.mapId - 50000] then table.insert(mapMatched, r) end
                    end
                    if #mapMatched > 0 then return pickLowest(mapMatched) end
                    return nil
                end

                return pickByDiff(RAID_ID_LIST)
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

    -- 2) TP semua hero ke posisi RootPart boss
    pcall(function()
     local heroFolder = workspace:FindFirstChild("Heros")
     if heroFolder then
      for _, hModel in ipairs(heroFolder:GetChildren()) do
       local hHrp = hModel:FindFirstChild("HumanoidRootPart")
       if hHrp then hHrp.CFrame = _tpTargetCF end
      end
     end
    end)

    -- 3) UnEquip -> EquipBest (sama seperti flow lama)
    task.wait(0.3)
    if RE.UnEquipHero  then pcall(function() RE.UnEquipHero:FireServer()  end) end
    task.wait(0.3)
    if RE.EquipBestHero then pcall(function() RE.EquipBestHero:FireServer() end) end
    task.wait(0.3)

    -- 4) TP ulang semua hero setelah re-equip
    pcall(function()
     local heroFolder = workspace:FindFirstChild("Heros")
     if heroFolder then
      for _, hModel in ipairs(heroFolder:GetChildren()) do
       local hHrp = hModel:FindFirstChild("HumanoidRootPart")
       if hHrp then hHrp.CFrame = _tpTargetCF end
      end
     end
    end)

    -- 5) Kunci posisi player selama scan+attack (Heartbeat freeze)
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
       if hrp and hrp.Parent and _frozenCFrame then
        hrp.CFrame = _frozenCFrame
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

     -- Helper: hitung posisi 5 stud dari musuh ke arah player (sama seperti GetAtkPosF di Farm)
     local function _getBossAtkPos(enemyHRP)
      local char = LP and LP.Character
      local pHRP = char and char:FindFirstChild("HumanoidRootPart")
      if not pHRP or not enemyHRP then return enemyHRP and enemyHRP.Position or _tpTargetPos end
      local ePos = enemyHRP.Position
      local dir = pHRP.Position - ePos
      local dir2 = Vector3.new(dir.X, 0, dir.Z)
      if dir2.Magnitude < 0.1 then return ePos + Vector3.new(5,0,0) end
      return ePos + dir2.Unit * 5
     end

     -- Helper: attack 1 target (sama persis FCharF di Farm: FireAttack+FireAllDamage+FireHeroRemotes x2)
     local function _attackBoss(guid, enemyHRP)
      local atkPos = _getBossAtkPos(enemyHRP)
      FireAttack(guid, atkPos)
      FireAllDamage(guid, atkPos)
      FireHeroRemotes(guid, atkPos)
      FireAttack(guid, atkPos)
      FireAllDamage(guid, atkPos)
      FireHeroRemotes(guid, atkPos)
     end

     local _outOfMapCount = 0
     while RAID.running do
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
       PG_Wait(0.1) -- [PingGuard] RAID boss hrp wait
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
       RaidStatusUpdate("[FLa] Target baru: " .. target.model.Name, Color3.fromRGB(255,80,60))
      end
      pcall(function() _attackBoss(targetGuid, target.hrp) end)
      PG_Wait(0.1) -- [PingGuard] RAID boss attack cycle
     end

     _step4Cleanup()
     _raidSuccess = true
     RAID._raidDone = true
     RaidStatusUpdate("[FLa] Target Dead!", Color3.fromRGB(100,255,150))
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
-- AUTO ASCENSION: LOGIC (port dari 1.lua baris 10499-11916)
-- ResolveAscEntry & ResolveAscEntryFromList dibuat GLOBAL (bukan nested), independen dari RAID Normal
-- AUTO BOSS KILL: pakai metode lama 1.lua (scan nama boss + ChildAdded), damage call diganti
-- RaidFireDamage -> FireAttack+FireAllDamage+FireHeroRemotes (RaidFireDamage tidak ada di 2.lua)
-- ============================================================================
-- AUTO ASCENSION : LOGIC
function StopAscension()
 ASC.running = false
 ASC.inMap   = false
 _ascBusy    = false
 _eventOwner = nil
 ReleaseMapLock("asc")
 -- [v62 FIX] Reset status label agar tidak nyantol di "Dalam Tower x"
 AscStatusUpdate("OFF", Color3.fromRGB(120,120,120))
 if _raidWakeup then pcall(function() _raidWakeup:Fire() end) end
 if ASC.thread then
  pcall(function() task.cancel(ASC.thread) end)
  ASC.thread = nil
 end
 if _ascWakeup then
  pcall(function() _ascWakeup:Destroy() end)
  _ascWakeup = nil
 end
end

function AscCounterUpdate()
 if ASC.suksesLbl then ASC.suksesLbl.Text = tostring(ASC.sukses) end
end

-- Helper: ambil semua entry Ascension dari RAID_LIVE (sorted)
local function GetAscensionList()
 local list = {}
 for rid, ent in pairs(RAID_LIVE) do
  -- isAscension == true ATAU raidId >= 935001 (range Ascension Tower dari server)
  local ridAbs = rid < 0 and math.abs(rid) or rid
  -- [v34 FIX] Kecuali Anniversary Celebration (raidId 937101) - BUKAN ASC Tower
  -- Sebelumnya Anniversary masuk ke ASC list karena ridAbs >= 935001
  local _isAnniversaryEntry = (ridAbs == 937101)
  if _isAnniversaryEntry then continue end -- skip Anniversary, bukan ASC
  if ent.isAscension == true or ridAbs >= 935001 then
   if not ent.isAscension then ent.isAscension = true end -- auto-mark
   -- Resolve raidId positif jika entry chat (negatif)
   local resolvedId = rid
   if rid < 0 then
    -- Cari raidId positif dari RAID_LIVE yang sama mapId & isAscension
    for rid2, ent2 in pairs(RAID_LIVE) do
     if rid2 > 0 and ent2.isAscension and ent2.mapId == ent.mapId then
      resolvedId = rid2; break
     end
    end
    -- Jika masih negatif, berarti raidId dari server belum datang
    -- Gunakan nilai absolut sebagai ID sementara supaya CreateRaidTeam bisa dicoba
    -- (server akan reject jika ID tidak valid, dan loop akan retry)
    if resolvedId < 0 then resolvedId = math.abs(resolvedId) end
   end
   -- ASC mapId 50301-50326 -> mapNum 1-26; RAID mapId 50001-50020 -> mapNum 1-20
   local _mId = ent.mapId or 50000
   local mn = (_mId >= 50301 and _mId <= 50326) and (_mId - 50300) or (_mId - 50000)
   -- [FIX] Grade resolution: prioritas chat cache -> runeGradeCache -> ent.grade -> "?"
   -- ent.grade bisa nil jika workspace event datang sebelum chat notif
   local _resolvedGrade = ent.grade
   if (not _resolvedGrade or _resolvedGrade == "?") and _ASC_CHAT_CACHE and _ASC_CHAT_CACHE[mn] then
    _resolvedGrade = _ASC_CHAT_CACHE[mn].grade or _resolvedGrade
   end
   if (not _resolvedGrade or _resolvedGrade == "?") and _runeGradeCache then
    _resolvedGrade = _runeGradeCache[-mn] or _runeGradeCache[mn] or _resolvedGrade
   end
   _resolvedGrade = _resolvedGrade or "?"
   table.insert(list, {
    id      = resolvedId,
    rawId   = rid,
    mapId   = ent.mapId,
    mapNum  = mn,
    grade   = _resolvedGrade,
    bossName= ent.bossName,
    isAscension = true,
   })
  end
 end
 return list
end

-- [ADAPT 2.lua] GetCurrentMapId & GetPlayerPos sudah ada sebagai fungsi global di 2.lua, tidak perlu didefinisikan ulang

-- ResolveAscEntry / ResolveAscEntryFromList dibuat GLOBAL (bukan nested di StartAscensionLoop)
-- agar bisa diakses dari luar (independen, sesuai keputusan salflo)
 function ResolveAscEntryFromList()
  if not ASC.listEnabled then return nil end
  if #ASC.listEntries == 0 then return nil end
  local ascList = GetAscensionList()
  if #ascList == 0 then return nil end

  -- Grade helper
  local function _getGradeL(r)
   local g = GetBestGrade(r.mapNum, true)
   if not g or g == "?" then g = r.grade end
   return (g and g ~= "?") and g or nil
  end

  -- Kumpulkan semua tower yang match dari semua entry
  local function collectAllMatched(skipVisited)
   local allMatched = {}
   local seen = {}
   for i = 1, #ASC.listEntries do
    local ent = ASC.listEntries[i]
    local hasMaps  = next(ent.maps)  ~= nil
    local hasRanks = next(ent.ranks) ~= nil
    for _, r in ipairs(ascList) do
     if seen[r.mapNum] then continue end
     if skipVisited and ASC._listVisitedMaps[r.mapNum] then continue end
     local mapsOk = (not hasMaps) or ent.maps[r.mapNum]
     if not mapsOk then continue end
     if hasRanks then
      local grade = _getGradeL(r)
      if grade and ent.ranks[grade] then
       table.insert(allMatched, r); seen[r.mapNum] = true
      end
     else
      table.insert(allMatched, r); seen[r.mapNum] = true
     end
    end
   end
   return allMatched
  end

  -- Tahap 1: cari yang belum dikunjungi
  local allMatched = collectAllMatched(true)
  -- Tahap 2: kalau semua sudah dikunjungi -> reset visited dan loop ulang
  if #allMatched == 0 then
   for k in pairs(ASC._listVisitedMaps) do ASC._listVisitedMaps[k] = nil end
   allMatched = collectAllMatched(true)
  end
  if #allMatched == 0 then return nil end
  -- Pilih mapNum terkecil dari semua yang match
  table.sort(allMatched, function(a, b) return a.mapNum < b.mapNum end)
  return allMatched[1]
 end

function ResolveAscEntry()
  local ascList = GetAscensionList()
  if #ascList == 0 then return nil, "no_tower" end

  -- [LIST ENTRY ASC] Cek List Entry dulu sebelum logika Pick Mode
  if ASC.listEnabled and #ASC.listEntries > 0 then
   local listResult = ResolveAscEntryFromList()
   if listResult then return listResult end
   -- Tidak ada match -> fallback ke Pick Mode normal (lanjut ke bawah)
  end

  -- Prune expired entries (sama seperti RAID)
  local _now0 = os.time()
  local _pruned0 = false
  for rid, ent in pairs(RAID_LIVE) do
   if ent.isAscension and ent.endTime and ent.endTime < (_now0 - 10) then
    RAID_LIVE[rid] = nil; _pruned0 = true
   end
  end
  if _pruned0 then
   ascList = GetAscensionList()
   if #ascList == 0 then return nil, "no_tower" end
  end

  local pm = ASC.pickMode or "easy"
  local hasPick = (pm == "byrank" or pm == "manual") and next(ASC.runeGrades or {}) ~= nil

  -- Grade helper: GetBestGrade dulu, fallback ke r.grade (sudah di-resolve di GetAscensionList)
  local function _getGrade(r)
   local g = GetBestGrade(r.mapNum, true)
   if not g or g == "?" then g = r.grade end
   return (g and g ~= "?") and g or nil
  end

  -- pickLowest: ambil tower dengan mapNum terkecil
  local function pickLowest(list)
   table.sort(list, function(a, b) return a.mapNum < b.mapNum end)
   return list[1]
  end

  -- sortHighestRank: sort rank tertinggi, tie-break mapNum terkecil (identik RAID)
  local function sortHighestRank(list)
   table.sort(list, function(a, b)
    local ga = _getGrade(a) or "?"
    local gb = _getGrade(b) or "?"
    local ra = GRADE_RANK[ga] or 0
    local rb = GRADE_RANK[gb] or 0
    if ra == rb then return a.mapNum < b.mapNum end
    return ra > rb
   end)
  end

  -- pickByDiff: identik RAID pickByDiff, adaptasi mapNum
  local function pickByDiff(list)
   if #list == 0 then return nil end
   if pm == "easy" then
    table.sort(list, function(a, b) return a.mapNum < b.mapNum end)
    return list[1]
   elseif pm == "hard" then
    table.sort(list, function(a, b) return a.mapNum > b.mapNum end)
    return list[1]
   elseif pm == "default" then
    -- Round-robin Tower 1-8, fallback ke terkecil (identik RAID map 1-8)
    local low = {}
    for _, r in ipairs(list) do
     if r.mapNum >= 1 and r.mapNum <= 8 then table.insert(low, r) end
    end
    if #low == 0 then return pickLowest(list) end
    table.sort(low, function(a, b) return a.mapNum < b.mapNum end)
    ASC._rrIdx = (ASC._rrIdx or 0) + 1
    if ASC._rrIdx > #low then ASC._rrIdx = 1 end
    return low[ASC._rrIdx]
   elseif pm == "byrank" then
    sortHighestRank(list)
    return list[1]
   elseif pm == "bymap" then
    table.sort(list, function(a, b) return a.mapNum < b.mapNum end)
    for _, r in ipairs(list) do
     if ASC.preferMaps[r.mapNum] then return r end
    end
    return list[1]
   end
   return pickLowest(list)
  end

  -- MANUAL MODE — identik RAID: 3 tahap, fallback ke terkecil
  if pm == "manual" then
   ASC.manualMatchMode = "none"
   local valid_asc = {}
   local hasPreferMaps = next(ASC.preferMaps or {}) ~= nil

   -- Tahap 0: kumpulkan kandidat, filter PreferMap jika di-set
   for _, r in ipairs(ascList) do
    local mn = r.mapNum
    if not hasPreferMaps or ASC.preferMaps[mn] then
     table.insert(valid_asc, r)
    end
   end
   if #valid_asc == 0 then return nil, "no_match" end  -- ada tower tapi tidak ada yg cocok preferMaps

   -- Helper sort
   local function sortHighestRankLocal(list)
    table.sort(list, function(a, b)
     local ga = _getGrade(a) or "?"
     local gb = _getGrade(b) or "?"
     local ra = GRADE_RANK[ga] or 0
     local rb = GRADE_RANK[gb] or 0
     if ra == rb then return a.mapNum < b.mapNum end
     return ra > rb
    end)
   end

   -- TAHAP 1: Cari kecocokan Preferred Rank
   local matched = {}
   local hasPreferRank = next(ASC.runeGrades or {}) ~= nil
   if hasPreferRank then
    for _, r in ipairs(valid_asc) do
     local grade = _getGrade(r)
     if grade and ASC.runeGrades[grade] then
      table.insert(matched, r)
     end
    end
    if #matched > 0 then
     sortHighestRankLocal(matched)
     ASC.manualMatchMode = "primary"
     return matched[1]
    end
    -- Rank diset tapi tidak ada tower yang cocok -> return nil+"no_match" agar RAID bisa fallback
    ASC.manualMatchMode = "none"
    return nil, "no_match"
   end

   -- Tidak ada Preferred Rank diset -> fallback ke tower terkecil dari kandidat
   ASC.manualMatchMode = "fallback"
   table.sort(valid_asc, function(a, b) return a.mapNum < b.mapNum end)
   return valid_asc[1]
  end

  -- BYRANK + BYMAP + hasPick: identik RAID
  if hasPick then
   local matched2 = {}
   for _, r in ipairs(ascList) do
    local grade = _getGrade(r)
    if grade and ASC.runeGrades[grade] == true then table.insert(matched2, r) end
   end
   if #matched2 > 0 then
    local chosen = pickByDiff(matched2)
    if chosen then return chosen end
   end
   if pm == "byrank" then return nil, "no_match" end  -- byrank: ada tower tapi rank tidak cocok
  end

  if pm == "bymap" and next(ASC.preferMaps or {}) ~= nil then
   local mapMatched = {}
   for _, r in ipairs(ascList) do
    if ASC.preferMaps[r.mapNum] then table.insert(mapMatched, r) end
   end
   if #mapMatched > 0 then return pickLowest(mapMatched) end
   return nil, "no_match"  -- bymap: ada tower tapi map tidak cocok
  end

  return pickByDiff(ascList)
 end

-- [FIX BUG] ResolveAscTargetMapId tertinggal saat port (asalnya di 1.lua baris 1697,
-- di luar range StartAscensionLoop yang diekstrak) - tanpa ini, StartAscensionLoop
-- crash setiap kali mau ENTER Tower (ResolveAscTargetMapId = nil value), pcall
-- menelan error-nya diam-diam -> ASC keluar loop -> "Auto Ascension STOP".
-- Inilah sebab kedua bug: deteksi sebenarnya jalan, tapi begitu mau masuk Tower
-- langsung crash sebelum sempat TP, jadi user lihatnya "tidak masuk" / "STOP".
function ResolveAscTargetMapId(mapNum)
 -- mapNum = nomor Tower (1-26) dari chat "Ascension Tower X"
 -- Return: mapId untuk StartChallengeRaidMap (50301-50326)
 if not mapNum or mapNum < 1 or mapNum > 26 then return 50301 end
 return 50300 + mapNum
end

function StartAscensionLoop()
 StopAscension()
 ASC.running = true
 ASC.sukses  = 0
 AscCounterUpdate()
 -- [v56 FIX] Wakeup RAID segera saat ASC di-ON
 -- RAID yang lagi di waiting loop harus langsung sadar ASC aktif dan mundur
 -- (fire SETELAH ASC.running = true agar kondisi ASC.running and ResolveAscEntry() terbaca benar)
 if _raidWakeup then pcall(function() _raidWakeup:Fire() end) end
 if _ascWakeup then pcall(function() _ascWakeup:Destroy() end) end
 _ascWakeup = Instance.new("BindableEvent")

 AscStatusUpdate("Siap. Menunggu Ascension Tower...", Color3.fromRGB(180,180,60))

 -- ResolveAscEntry: Pick Mode logic IDENTIK dengan AUTO RAID
 -- Semua mode locked kecuali Manual -> hanya masuk Tower terkecil
 -- Manual: PREFERRED MAP + PREFERRED RANK aktif, fallback ke terkecil jika tidak match
 -- ResolveAscEntry: 100% IDENTIK dengan ResolveEntry (Auto Raid Normal)
 -- Satu-satunya perbedaan: pakai ASC.* dan ascList (mapNum) bukan RAID_ID_LIST (mapId)
 -- MapId masuk ke tower tetap 503xx — tidak diubah di sini
 -- Return: entry (match), nil+"no_tower" (tidak ada tower), nil+"no_match" (ada tower tapi filter tidak cocok)
 -- LIST ENTRY ASC: cari tower yang match list, fallback ke Pick Mode

 ASC.thread = task.spawn(function()
  pcall(function()
  while ASC.running do
   repeat

    -- [v48] Cek semua interrupt (sama seperti RAID)

    if ST2 and (ST2.running or ST2.inMap) then
     ASC.inMap = false
     AscStatusUpdate("[||] Tower aktif - Ascension pause...", Color3.fromRGB(255,140,0))
     while ST2 and (ST2.running or ST2.inMap) and ASC.running do task.wait(0.5) end
     if not ASC.running then break end
     AscStatusUpdate("> Tower selesai - lanjut Ascension...", C.ACC3)
     task.wait(0.1)
    end

    if (SIEGE and (SIEGE.inMap or SIEGE.teleporting)) or _siegeInterrupt then
     ASC.inMap = false
     AscStatusUpdate("[||] Siege aktif - Ascension pause...", Color3.fromRGB(255,140,0))
     while ((SIEGE and (SIEGE.inMap or SIEGE.teleporting)) or _siegeInterrupt) and ASC.running do task.wait(0.5) end
     if not ASC.running then break end
     AscStatusUpdate("> Siege selesai - lanjut Ascension...", C.ACC3)
     task.wait(0.1)
    end

    -- Blokir jika di dalam map RAID Normal atau Siege (bukan Ascension Tower sendiri)
    local curWm = workspace:GetAttribute("MapId") or 0
    if (curWm >= 50101 and curWm <= 50120) or (curWm >= 50201 and curWm <= 50205) then
     AscStatusUpdate("[||] Sedang di dalam map lain - tunggu...", Color3.fromRGB(255,140,0))
     task.wait(3); break
    end

    -- [v48] Resolve entry berdasarkan Pick Mode
    local raidEntry, _ascReason = ResolveAscEntry()

    -- [FALLBACK FIX] Jika ada tower tapi filter tidak match + RAID.running -> fallback ke RAID siklus ini
    if not raidEntry and _ascReason == "no_match" and RAID and RAID.running then
     AscStatusUpdate("[Fallback] Filter tidak match - giliran Auto Raid siklus ini...", Color3.fromRGB(140,80,200))
     if _raidWakeup then pcall(function() _raidWakeup:Fire() end) end
     _eventOwner = "raid"
     -- Tunggu sampai RAID selesai satu siklus atau ada tower baru yang match
     local _fbConn
     local _fbDone = false
     if _ascWakeup then
      _fbConn = _ascWakeup.Event:Connect(function()
       _fbDone = true  -- ada event baru, coba resolve lagi
      end)
     end
     while ASC.running and not _fbDone do
      task.wait(0.5)
      -- Cek apakah sekarang ada match (event baru bisa datang)
      local _recheck, _recheckReason = ResolveAscEntry()
      if _recheck then _fbDone = true; raidEntry = _recheck end
     end
     if _fbConn then pcall(function() _fbConn:Disconnect() end) end
     if not raidEntry then
      break  -- kembali ke outer while loop, cek kondisi fresh
     end
    end

    -- Waiting loop jika tidak ada Ascension Tower tersedia (no_tower atau ASC-only)
    while ASC.running and not raidEntry do
     local ascList = GetAscensionList()
     local _pm = ASC.pickMode or "easy"
     local _, _curReason = ResolveAscEntry()
     -- Jika ada tower tapi filter tidak match dan RAID running -> fallback
     -- (ini handle kasus dimana tower muncul SAAT waiting loop berjalan)
     if _curReason == "no_match" and RAID and RAID.running then
      AscStatusUpdate("[Fallback] Filter tidak match - giliran Auto Raid...", Color3.fromRGB(140,80,200))
      if _raidWakeup then pcall(function() _raidWakeup:Fire() end) end
      _eventOwner = "raid"
      break
     elseif _raidFallbackActive and RAID.running then
      AscStatusUpdate("[Standby] RAID fallback aktif siklus ini - tunggu siklus event baru...", Color3.fromRGB(140,80,200))
     elseif #ascList == 0 then
      if RAID.running then
       AscStatusUpdate("[Standby] Fallback ke Auto Raid - tunggu Ascension Tower...", Color3.fromRGB(140,100,200))
      else
       AscStatusUpdate("Waiting Ascension Tower [".._pm.."]...", Color3.fromRGB(140,140,60))
      end
     elseif _pm == "manual" then
      -- Manual mode: tampilkan filter aktif
      local _parts = {}
      local _hasMap = next(ASC.preferMaps or {}) ~= nil
      local _hasRank = next(ASC.runeGrades or {}) ~= nil
      if _hasMap then
       local _ms = {}
       for mn=1,26 do if ASC.preferMaps and ASC.preferMaps[mn] then table.insert(_ms,"T"..mn) end end
       table.insert(_parts, "Map["..table.concat(_ms,"|").."]")
      end
      if _hasRank then
       local _gr = {}
       for _, g in ipairs(GRADE_LIST) do if ASC.runeGrades[g] then table.insert(_gr, g) end end
       table.insert(_parts, "Rank["..table.concat(_gr,"||").."]")
      end
      if _hasRank and ASC.runeEnabled and ASC.runeMapTarget >= 1 and ASC.runeMapTarget <= 26 then
       table.insert(_parts, "Rune->T"..ASC.runeMapTarget)
      end
      local _filterStr = #_parts > 0 and table.concat(_parts," | ") or "no filter"
      -- Jika ada tower tapi tidak cocok filter rank -> beri keterangan lebih jelas
      local _ascListNow = GetAscensionList()
      local _noMatchNote = (#_ascListNow > 0 and _hasRank) and " [no rank match]" or "..."
      AscStatusUpdate("Waiting [Manual] "..(_filterStr).._noMatchNote, Color3.fromRGB(255,180,50))
     elseif _pm == "bymap" then
      local _ms = {}
      for mn=1,26 do if ASC.preferMaps and ASC.preferMaps[mn] then table.insert(_ms,"T"..mn) end end
      local _mapStr = #_ms > 0 and table.concat(_ms,"|") or "NOT SET"
      AscStatusUpdate("Waiting [ByMap] "..(_mapStr).." (fallback: terkecil)...", Color3.fromRGB(100,200,100))
     elseif _pm == "byrank" then
      local _gr = {}
      for _, g in ipairs(GRADE_LIST) do if ASC.runeGrades[g] then table.insert(_gr, g) end end
      local _rankStr = #_gr > 0 and table.concat(_gr,"||") or "NOT SET"
      AscStatusUpdate("Waiting [ByRank] "..(_rankStr).." (fallback: terkecil)...", Color3.fromRGB(200,120,255))
     elseif _pm == "hard" then
      AscStatusUpdate("Waiting Ascension Tower [Hard - Tower Terbesar]...", Color3.fromRGB(255,80,80))
     elseif _pm == "easy" then
      AscStatusUpdate("Waiting Ascension Tower [Easy - Tower Terkecil]...", Color3.fromRGB(80,220,80))
     else
      AscStatusUpdate("Waiting Ascension Tower [".._pm.."]...", Color3.fromRGB(255,200,60))
     end
     -- Wakeup cepat
     local _woken = false
     local _wConn
     if _ascWakeup then
      _wConn = _ascWakeup.Event:Connect(function() _woken = true end)
     end
     local _we = 0
     while not _woken and _we < 1 and ASC.running do
      task.wait(0.1); _we = _we + 0.1
     end
     if _wConn then pcall(function() _wConn:Disconnect() end) end
     -- [v62 RINO/RINI FIX] Jika TriggerEntryWakeup memutuskan ini giliran RAID ("rini"),
     -- ASC ("rino") tetap duduk. Tidak mencoba resolve apapun sampai siklus berikutnya.
     if _eventOwner == "raid" and RAID.running then
      raidEntry = nil  -- ASC standby, RAID yang jalan siklus ini
     elseif _raidFallbackActive and RAID.running then
      raidEntry = nil  -- fallback lama (v61 compat)
     else
      local _re2, _reason2 = ResolveAscEntry()
      raidEntry = _re2
      -- Jika ada tower tapi filter tidak match dan RAID running -> fallback ke RAID
      if not _re2 and _reason2 == "no_match" and RAID and RAID.running then
       AscStatusUpdate("[Fallback] Filter tidak match - giliran Auto Raid...", Color3.fromRGB(140,80,200))
       if _raidWakeup then pcall(function() _raidWakeup:Fire() end) end
       _eventOwner = "raid"
       break  -- keluar waiting loop, biarkan RAID jalan
      end
     end
    end
    if not ASC.running then break end
    if not raidEntry then break end

    -- [v56 FIX] ASC guard: tunggu fitur lain selesai sebelum masuk Tower
    -- RAID: tunggu sampai RAID.inMap = false (keluar dari map), lalu ASC boleh masuk
    do
     local _aWait = 0
     while ASC.running and _aWait < 90 do
      local _busy, _who = IsAnyMapActive()
      local _selfBusy = (_who == "asc")
      if not _busy or _selfBusy then break end
      AscStatusUpdate("[||] Tunggu "..(_who or "?").." selesai dulu...", Color3.fromRGB(255,140,0))
      task.wait(0.5); _aWait = _aWait + 0.5
     end
     if not ASC.running then break end
    end

    -- [v52 FIX] Atomic lock: cegah RAID masuk bersamaan saat ASC baru lolos guard
    -- Tanpa lock ini: RAID dan ASC bisa lolos guard hampir bersamaan (keduanya lihat inMap=false)
    -- lalu keduanya coba TP player ke map berbeda dalam waktu bersamaan
    do
     local _lockWait = 0
     while ASC.running and _lockWait < 15 do
      if TryClaimMapLock("asc") then break end
      AscStatusUpdate("[||] Tunggu slot masuk map bebas...", Color3.fromRGB(200,160,255))
      task.wait(0.2); _lockWait = _lockWait + 0.2
     end
     if not ASC.running then ReleaseMapLock("asc"); break end
    end

    local mn = raidEntry.mapNum
    -- [LIST ENTRY ASC] Tandai tower ini sudah dikunjungi di siklus ini
    if ASC.listEnabled and #ASC.listEntries > 0 then
     ASC._listVisitedMaps[mn] = true
    end
    local bossHint = raidEntry.bossName and (" - "..raidEntry.bossName) or ""
    AscStatusUpdate("Masuk: Tower "..mn..bossHint.." ["..raidEntry.grade.."]", Color3.fromRGB(100,200,255))

    -- Tunggu SIEGE selesai dulu jika sedang inMap
    if SIEGE and (SIEGE.inMap or SIEGE.teleporting) then
        AscStatusUpdate("[||] Tunggu SIEGE selesai...", Color3.fromRGB(255,180,50))
        local _ws = 0
        while (SIEGE.inMap or SIEGE.teleporting) and ASC.running and _ws < 120 do
            task.wait(0.5); _ws = _ws + 0.5
        end
        if not ASC.running then return end
    end

    -- Tunggu RAID selesai dulu jika sedang inMap
    if RAID and RAID.inMap then
        AscStatusUpdate("[||] Tunggu RAID selesai...", Color3.fromRGB(255,180,50))
        local _wr = 0
        while RAID.inMap and ASC.running and _wr < 120 do
            task.wait(0.5); _wr = _wr + 0.5
        end
        if not ASC.running then return end
    end

    _ascInterrupt = true  -- signal MA untuk pause (MA cek di guard tiap iterasi)

    ASC.inMap = true
    _ascInterrupt = false  -- inMap=true sudah aktif, WaitRaidDone cek ASC.inMap langsung
    _ascBusy  = true  -- RAID harus pause total selama ASC aktif (inMap+cooldown)
    _ascMatchedThisCycle = true   -- [v61 CYCLEFIX] ASC sudah match di siklus ini
    _raidFallbackActive  = false  -- [v61 CYCLEFIX] RAID tidak boleh fallback di siklus ini
    _ascPending = false -- [v57 FIX] inMap=true sudah cover, tidak perlu pending lagi
    -- [v52 FIX] Setelah inMap=true di-set, lock tidak diperlukan lagi (IsAnyMapActive sudah cover)
    ReleaseMapLock("asc")

    -- Entry ASC = identik RAID normal, beda hanya mapId dan RUNE_IDS:
    -- RAID: StartChallengeRaidMap({mapId = raidEntry.mapId + 100}) → 50101-50120
    -- ASC : StartChallengeRaidMap({mapId = 50300+mn})              → Tower X = 50301-50326
    -- mapNum sudah di-resolve oleh ResolveAscEntry (termasuk Preferred Map / Rank filter + fallback)
    local targetMapId = ResolveAscTargetMapId(mn)
    local _pm_now = ASC.pickMode or "easy"
    local mn_label = mn
    if _pm_now == "manual" and ASC.manualMatchMode == "primary" then
     mn_label = mn.." [Match]"
    elseif _pm_now == "manual" and ASC.manualMatchMode == "fallback" then
     mn_label = mn.." [Fallback]"
    elseif _pm_now == "bymap" then
     mn_label = mn.." [ByMap]"
    elseif _pm_now == "byrank" then
     mn_label = mn.." [ByRank]"
    end

    AscStatusUpdate("[~] Enter Tower "..mn_label.."...", Color3.fromRGB(100,200,255))

    -- [v64] ASC RUNE IDS (Preferred Rune / Item) - 26 Tower Ascension
    local ASC_RUNE_IDS = {
     [1]=10265,  -- Baran
     [2]=10266,  -- Baran+1
     [3]=10267,  -- Grendal
     [4]=10268,  -- Grendal+1
     [5]=10269,  -- Plague
     [6]=10314,  -- Plague+1
     [7]=10315,  -- Frostborne
     [8]=10316,  -- Frostborne+1
     [9]=10357,  -- Legia
     [10]=10358, -- Legia+1
     [11]=10359, -- Silas
     [12]=10360, -- Silas+1
     [13]=10361, -- Yogumunt
     [14]=10362, -- Yogumunt+1
     [15]=10363, -- Antares
     [16]=10364, -- Antares+1
     [17]=10365, -- Ashborn
     [18]=10366, -- Ashborn+1
     [19]=10367, -- Dominion
     [20]=10368, -- Dominion+1
     [21]=10369, -- Absolute
     [22]=10370, -- Absolute+1
     [23]=10371, -- Broly
     [24]=10372, -- Broly+1
     [25]=10373, -- Goku Super 4
     [26]=10374, -- Goku Super 4+1
    }

    -- [v64] LOGIKA KEPUTUSAN (disesuaikan untuk Tower 1-26)
    -- Identik AUTO RAID: rune aktif di semua mode selama runeEnabled=true dan runeMapTarget valid
    -- APM_UNLOCK hanya mengunci UI field (tidak bisa set baru), bukan memblokir eksekusi rune
    local useRune = false

    if ASC.runeEnabled and ASC.runeMapTarget >= 1 and ASC.runeMapTarget <= 26 then
     -- Anti-mubazir: kalau tower yang akan dimasuki sudah sama dengan target, simpan rune
     if mn == ASC.runeMapTarget then
      useRune = false
     else
      useRune = true
     end
    end

    -- [v64] EKSEKUSI (identik RAID - hanya RUNE_IDS dan mapId berbeda)
    if useRune then
     -- >>> MODE RUNE TOWER OVERRIDE <<<
     local targetTower = ASC.runeMapTarget
     AscStatusUpdate("Create Team...", C.ACC2)
     if RE.CreateRaidTeam then pcall(function() RE.CreateRaidTeam:InvokeServer(raidEntry.id) end) end
     task.wait(0.2)

     AscStatusUpdate("Use Item (Tower "..targetTower..")...", Color3.fromRGB(255,200,60))
     local itemId = ASC_RUNE_IDS[targetTower]
     if itemId and RE.UseRaidItem then
      pcall(function() RE.UseRaidItem:FireServer(itemId) end)
     end
     task.wait(0.3)

     local _runeTargetMapId = 50300 + targetTower
     if RE.StartChallengeRaidMap then
      pcall(function() RE.StartChallengeRaidMap:FireServer({mapId = _runeTargetMapId}) end)
     end

     ASC.serverMapId = nil
     local _wR = 0
     while ASC.serverMapId == nil and _wR < 10 and ASC.running do
      task.wait(0.1); _wR = _wR + 0.1
     end

     -- Jika serverMapId nil setelah timeout: material habis atau server reject
     if ASC.serverMapId == nil and ASC.running then
      -- Di Manual mode: JANGAN fallback masuk tower lain. Lapor dan nganggur.
      local _pm_rune = ASC.pickMode or "easy"
      if _pm_rune == "manual" then
       AscStatusUpdate("[!] Material Habis - Nganggur (Manual mode)...", Color3.fromRGB(255,80,80))
       ASC.inMap = false
       _ascBusy = false
       _ascInterrupt = false
       ReleaseMapLock("asc")
       -- Tunggu sampai wakeup event berikutnya (material diisi ulang / event baru)
       local _woken = false
       local _wConn
       if _ascWakeup then
        _wConn = _ascWakeup.Event:Connect(function() _woken = true end)
       end
       local _wt = 0
       while not _woken and _wt < 30 and ASC.running do
        task.wait(1); _wt = _wt + 1
        AscStatusUpdate("[!] Material Habis - Menunggu... ("..tostring(30-_wt).."s)", Color3.fromRGB(255,80,80))
       end
       if _wConn then pcall(function() _wConn:Disconnect() end) end
       break
      else
       -- Mode lain: fallback masuk tower original
       AscStatusUpdate("[!] Item Kosong - Fallback ke Tower "..mn.."...", Color3.fromRGB(255,140,0))
       if RE.CreateRaidTeam then pcall(function() RE.CreateRaidTeam:InvokeServer(raidEntry.id) end) end
       task.wait(0.2)
       if RE.StartChallengeRaidMap then pcall(function() RE.StartChallengeRaidMap:FireServer({mapId = targetMapId}) end) end
       local _wFb = 0
       while ASC.serverMapId == nil and _wFb < 5 and ASC.running do
        task.wait(0.05); _wFb = _wFb + 0.05
       end
      end
     end

    else
     -- >>> MODE NORMAL / FALLBACK <<<
     AscStatusUpdate("[~] Enter Tower "..mn_label.."...", Color3.fromRGB(100,200,255))
     -- Sama persis RAID: CreateRaidTeam(raidId)
     if RE.CreateRaidTeam then
      pcall(function() RE.CreateRaidTeam:InvokeServer(raidEntry.id) end)
     end
     task.wait(0.2)
     if not ASC.running then ASC.inMap = false; break end

     -- Sama persis RAID: StartChallengeRaidMap({mapId=targetMapId})
     local _cfail = false
     local _cfConn
     local _cfRe = Remotes:FindFirstChild("ChallengeRaidsFail")
     if _cfRe then _cfConn = _cfRe.OnClientEvent:Connect(function() _cfail = true end) end

     if RE.StartChallengeRaidMap then
      pcall(function() RE.StartChallengeRaidMap:FireServer({mapId = targetMapId}) end)
     end

     -- [v64 FIX] Tunggu ASC.serverMapId (bukan RAID.serverMapId!) max 5s
     ASC.serverMapId = nil
     local _w2 = 0
     while ASC.serverMapId == nil and _w2 < 5 and ASC.running and not _cfail do
      task.wait(0.05); _w2 = _w2 + 0.05
     end
     if _cfConn then pcall(function() _cfConn:Disconnect() end) end

     if _cfail then
      RAID_LIVE[raidEntry.rawId] = nil
      if raidEntry.rawId ~= raidEntry.id then RAID_LIVE[raidEntry.id] = nil end
      if RebuildRaidList then pcall(RebuildRaidList) end
      ASC.inMap = false; ReleaseMapLock("asc")
      -- [v64 FIX] Jangan biarkan _ascBusy=true saat gagal masuk -> RAID/MA akan stuck pause
      _ascBusy = false
      _ascInterrupt = false  -- [FIX] reset jika gagal masuk
      AscStatusUpdate("[!] Server reject (ChallengeRaidsFail) - retry...", Color3.fromRGB(255,80,80))
      task.wait(1); break
     end
    end

    -- Tunggu masuk Tower (max 10s) - sama persis RAID tapi cek range 50301-50326
    AscStatusUpdate("[~] Waiting Tower "..mn_label.."...", Color3.fromRGB(180,100,255))
    local _tpOk = false
    local _tpW  = 0
    while not _tpOk and _tpW < 10 and ASC.running do
     task.wait(0.3); _tpW = _tpW + 0.3
     pcall(function()
      local wm = workspace:GetAttribute("MapId") or workspace:GetAttribute("mapId") or workspace:GetAttribute("CurrentMapId")
      if wm then
       if wm >= 50301 and wm <= 50326 then _tpOk = true end
      end
     end)
     if not _tpOk and #GetRaidEnemies() > 0 then _tpOk = true end
    end

    if not _tpOk and ASC.running then
     RAID_LIVE[raidEntry.rawId] = nil
     if raidEntry.rawId ~= raidEntry.id then RAID_LIVE[raidEntry.id] = nil end
     if RebuildRaidList then pcall(RebuildRaidList) end
     ASC.inMap = false; ReleaseMapLock("asc")
     -- [v64 FIX] Reset _ascBusy agar RAID/MA tidak stuck pause selamanya saat gagal TP
     _ascBusy = false
     _ascInterrupt = false  -- [FIX] reset pada gagal TP
     AscStatusUpdate("[!] Gagal masuk Tower - retry...", Color3.fromRGB(255,80,80))
     task.wait(1); break
    end

    -- Setup event listener boss/done
    local _ascDone = false
    local _ascSuccess = false
    local connAS, connAF
    -- [BUG FIX 1&2] _ascServerDone = server bilang sukses, tapi TIDAK interrupt attack loop.
    -- _ascDone hanya di-set true dari Fail event (batal total) atau setelah attack loop selesai.
    local _ascServerDone = false
    local _reAS = Remotes:FindFirstChild("ChallengeRaidsSuccess")
    local _reAF = Remotes:FindFirstChild("ChallengeRaidsFail")
    if _reAS then connAS = _reAS.OnClientEvent:Connect(function() _ascServerDone = true; _ascSuccess = true end) end
    if _reAF then connAF = _reAF.OnClientEvent:Connect(function() _ascDone = true end) end

    -- STEP 4: Dalam map - equip hero
    if #HERO_GUIDS > 0 then
     task.spawn(function()
      task.wait(0.5)
      if RE.EquipHeroWithData then
       for _, hGuid in ipairs(HERO_GUIDS) do
        pcall(function() RE.EquipHeroWithData:FireServer({ heroGuid = hGuid, userId = MY_USER_ID }) end)
        task.wait(0.1)
       end
      end
      if RE.HeroStand then
       local char = LP.Character
       local hrp = char and char:FindFirstChild("HumanoidRootPart")
       local spawnPos = (hrp and hrp.Position) or Vector3.new(0,0,0)
       pcall(function() RE.HeroStand:FireServer({ userId=MY_USER_ID, standPos=spawnPos }) end)
      end
     end)
    end

    AscStatusUpdate("[~] Dalam Tower "..mn.." - loading...", Color3.fromRGB(100,200,255))

    -- [v64 FIX] Watchdog: reset ASC.inMap + _ascBusy jika player terdeteksi keluar Tower
    -- Ini handle kasus race condition: MA/RAID TP player keluar saat ASC masih "inMap=true"
    -- Tanpa ini: ASC stuck "Dalam Tower... Loading" selamanya karena state tidak pernah direset
    local _watchdogTh = task.spawn(function()
     while ASC.inMap and ASC.running do
      task.wait(1)
      local ok, wm = pcall(function()
       return workspace:GetAttribute("MapId") or workspace:GetAttribute("mapId") or 0
      end)
      if ok and type(wm) == "number" then
       -- Jika player tidak di Ascension Tower range, berarti sudah keluar secara paksa
       if wm > 0 and (wm < 50301 or wm > 50326) then
        -- Jangan langsung reset jika masih di fase loading awal (beri waktu 3s)
        task.wait(3)
        local ok2, wm2 = pcall(function()
         return workspace:GetAttribute("MapId") or workspace:GetAttribute("mapId") or 0
        end)
        if ok2 and type(wm2) == "number" and (wm2 < 50301 or wm2 > 50326) and wm2 > 0 then
         AscStatusUpdate("[!] Watchdog: Player keluar Tower paksa - reset state", Color3.fromRGB(255,80,80))
         ASC.inMap = false
         _ascBusy = false
         _ascInterrupt = false  -- [FIX] reset pada watchdog exit
         ReleaseMapLock("asc")
         break
        end
       end
      end
     end
    end)



    -- [v48] AUTO BOSS KILL - sama persis dengan AUTO RAID
    if ASC.autoKillBoss then
     -- BOSS_KEYS untuk Ascension Tower (semua boss AT + boss normal)
     local BOSS_KEYS_ASC = {
      "baran","grendal","plague","frostborne","legia",
      "silas","yogumunt","antares","ashborn",
      -- [CUSTOM] Boss Ascension Tower
     }
     local function IsBossAsc(name)
      local n = name:lower()
      for _, k in ipairs(BOSS_KEYS_ASC) do if n:find(k,1,true) then return true end end
      return false
     end
     -- Prioritaskan nama boss dari entry jika ada
     local _ascHintName = raidEntry.bossName and raidEntry.bossName:lower() or nil
     local function IsBossAscWithHint(name)
      local n = name:lower()
      if _ascHintName and n:find(_ascHintName,1,true) then return true end
      return IsBossAsc(name)
     end

     -- [FIX v50] Tunggu mapId ASC valid sebelum mulai scan boss
     -- Identik pola RAID: snapshot mapId + anchor posisi player diambil SETELAH mapId valid
     -- Tanpa ini: filter mapId di _tryAddBoss terlalu cepat return saat ChildAdded fire
     task.wait(0.3) -- beri server 1 tick untuk update workspace.MapId
     local _ascMapIdSnapshot = GetCurrentMapId()
     local _ascSnapWait = 0
     while (_ascMapIdSnapshot == nil or _ascMapIdSnapshot < 50301 or _ascMapIdSnapshot > 50326)
      and _ascSnapWait < 3 and ASC.running and not _ascDone do
      task.wait(0.3); _ascSnapWait = _ascSnapWait + 0.3
      _ascMapIdSnapshot = GetCurrentMapId()
     end
     -- _ascMapIdFilterActive: hanya aktifkan filter mapId jika snapshot benar-benar valid
     -- Jika server lambat update, filter dimatikan agar boss tidak ditolak salah
     local _ascMapIdFilterActive = _ascMapIdSnapshot ~= nil
      and (_ascMapIdSnapshot >= 50301 and _ascMapIdSnapshot <= 50326)
     -- Anchor posisi player diambil setelah mapId valid
     -- Jika diambil terlalu awal posisi masih di map lama -> semua enemy ditolak karena jarak
     local _ascAnchorPos = GetPlayerPos()
     local _ascAnchorValid = _ascAnchorPos and _ascAnchorPos.Magnitude > 10
     local MAX_DIST_ASC_BOSS = 2000

     -- [FIX v50] Early boss detection ASC - scan agresif semua sumber
     local _earlyBoss = nil
     local _loadWait = 0
     while _loadWait < 5 and ASC.running and not _ascDone do
      task.wait(0.5); _loadWait = _loadWait + 0.5
      if _loadWait >= 1 and not _earlyBoss then
       local _pp = GetPlayerPos()
       -- Sumber 1: GetRaidEnemies()
       local _eList = GetRaidEnemies()
       -- [ADAPT 2.lua] GetEnemiesLocal tidak ada di 2.lua, GetRaidEnemies() sudah cukup + fallback folder scan di bawah
       for _, e in ipairs(_eList) do
        if IsBossAscWithHint(e.model.Name) then
         -- [FIX] Validasi jarak 500 studs - cegah boss dari map lain
         local _hrp = e.model and e.model:FindFirstChild("HumanoidRootPart")
         if _hrp and _pp and _pp.Magnitude > 1 then
          if (_hrp.Position - _pp).Magnitude <= 500 then _earlyBoss = e; break end
         elseif _hrp then
          _earlyBoss = e; break
         end
        end
       end
       -- Sumber 3: scan folder langsung kalau masih belum ketemu
       if not _earlyBoss then
        pcall(function()
         for _, fname in ipairs({"Bosses","Boss","RaidBoss","Enemys","Enemy","Enemies","RaidEnemys","Monsters","Monster"}) do
          local f = workspace:FindFirstChild(fname)
          if f then
           for _, obj in ipairs(f:GetChildren()) do
            if obj:IsA("Model") and IsBossAscWithHint(obj.Name) then
             local g = obj:GetAttribute("EnemyGuid") or obj:GetAttribute("BossGuid") or obj:GetAttribute("Guid") or obj:GetAttribute("GUID")
             local hrp = obj:FindFirstChild("HumanoidRootPart")
             local hum = obj:FindFirstChildOfClass("Humanoid")
             if g and hrp and hum and hum.Health > 0 then
              -- [FIX] Validasi jarak 500 studs - cegah boss dari map lain
              if _pp and _pp.Magnitude > 1 then
               if (hrp.Position - _pp).Magnitude <= 500 then
                _earlyBoss = {guid=g, hrp=hrp, model=obj}; break
               end
              else
               _earlyBoss = {guid=g, hrp=hrp, model=obj}; break
              end
             end
            end
           end
          end
          if _earlyBoss then break end
         end
        end)
       end
      end
      if _earlyBoss then
       local _ep = _earlyBoss.hrp and _earlyBoss.hrp.Parent and _earlyBoss.hrp.Position
       if _ep and _ep.Y > -200 and _ep.Magnitude > 1 and _loadWait >= 1.5 then break end
       if _ep and (_ep.Y <= -200 or _ep.Magnitude <= 1) then _earlyBoss = nil end
      end
     end

     -- [FIX v50] Event-based boss detection - identik dengan RAID
     -- Tambah _bossFoundViaEvent flag + scan existing children tiap folder
     local boss = (_earlyBoss and IsBossAscWithHint(_earlyBoss.model.Name)) and _earlyBoss or nil
     local _bossEventConns = {}
     local _bossFoundViaEvent = false
     local function _tryAddBoss(obj)
      if boss or not obj:IsA("Model") then return end
      if IsBossAscWithHint(obj.Name) then
       -- [FIX v50] Filter mapId toleran: hanya blokir jika filter aktif DAN mapId jelas di luar range
       -- Sebelumnya: hard reject jika mapId nil/belum update -> boss dari ChildAdded diabaikan
       -- Sekarang: jika _ascMapIdFilterActive=false (server belum update), biarkan lolos dulu
       if _ascMapIdFilterActive then
        local _curMap = GetCurrentMapId()
        if _curMap and (_curMap < 50301 or _curMap > 50326) then return end
       end
       local g = obj:GetAttribute("EnemyGuid") or obj:GetAttribute("BossGuid") or obj:GetAttribute("Guid") or obj:GetAttribute("GUID")
       local hrp = obj:FindFirstChild("HumanoidRootPart")
       local hum = obj:FindFirstChildOfClass("Humanoid")
       if not (g and hrp and hum) then return end
       -- [FIX ZOMBIE] Validasi zombie: health, maxhealth, posisi
       if hum.Health <= 0 then return end
       if hum.MaxHealth <= 0 then return end
       local _ap = hrp.Position
       if _ap.Magnitude <= 10 then return end
       if _ap.Y < -200 or _ap.Y > 1500 then return end
       if not hrp:IsDescendantOf(workspace) then return end
       -- [FIX v50] Gunakan anchor posisi yang sudah divalidasi post-TP (identik pola RAID)
       -- Sebelumnya: GetPlayerPos() on-the-fly, bisa masih transit -> filter jarak tidak akurat
       if _ascAnchorValid then
        if (_ap - _ascAnchorPos).Magnitude > MAX_DIST_ASC_BOSS then return end
       else
        -- Anchor belum valid: fallback ke GetPlayerPos() on-the-fly
        local _pp = GetPlayerPos()
        if _pp and _pp.Magnitude > 1 then
         if (_ap - _pp).Magnitude > MAX_DIST_ASC_BOSS then return end
        end
       end
       boss = {guid=g, hrp=hrp, model=obj}
       _bossFoundViaEvent = true
      end
     end
     -- Pasang ChildAdded di semua folder enemy + scan existing children sekarang
     for _, fname in ipairs({"Bosses","Boss","RaidBoss","Enemys","Enemy","Enemies","RaidEnemys","Monsters","Monster"}) do
      local folder = workspace:FindFirstChild(fname)
      if folder then
       table.insert(_bossEventConns, folder.ChildAdded:Connect(_tryAddBoss))
       -- [FIX] Scan existing children - boss mungkin sudah ada sebelum listener dipasang
       for _, child in ipairs(folder:GetChildren()) do _tryAddBoss(child) end
      end
     end
     -- Listen workspace.ChildAdded untuk folder yang baru muncul
     table.insert(_bossEventConns, workspace.ChildAdded:Connect(function(obj)
      if obj:IsA("Folder") or obj:IsA("Model") then
       _tryAddBoss(obj)
       pcall(function()
        table.insert(_bossEventConns, obj.ChildAdded:Connect(_tryAddBoss))
        for _, child in ipairs(obj:GetChildren()) do _tryAddBoss(child) end
       end)
      end
     end))

     -- [FIX v50] Cari boss - max 5s
     -- [ADAPT 2.lua] Pakai GetRaidEnemies() (GetEnemiesLocal tidak ada di 2.lua)
     local waitBoss = 0
     while ASC.running and not boss and waitBoss < 5 and not _ascDone do
      local _pp = GetPlayerPos()
      -- Coba GetRaidEnemies() dulu
      local _bList = GetRaidEnemies()
      for _, e in ipairs(_bList) do
       if IsBossAscWithHint(e.model.Name) then
        -- [FIX] Validasi jarak 500 studs - cegah boss dari map lain
        local _hrp = e.model and e.model:FindFirstChild("HumanoidRootPart")
        if _hrp and _pp and _pp.Magnitude > 1 then
         if (_hrp.Position - _pp).Magnitude <= 500 then boss = e; break end
        elseif _hrp then
         boss = e; break
        end
       end
      end
      -- Fallback terakhir: scan workspace:GetDescendants() setelah 15s (dead code - waitBoss max 5s)
      if not boss and waitBoss >= 15 and waitBoss % 5 < 0.4 then
       pcall(function()
        for _, obj in ipairs(workspace:GetDescendants()) do
         if obj:IsA("Model") and IsBossAscWithHint(obj.Name) then
          local g = obj:GetAttribute("EnemyGuid") or obj:GetAttribute("BossGuid") or obj:GetAttribute("Guid") or obj:GetAttribute("GUID")
          local hrp = obj:FindFirstChild("HumanoidRootPart")
          local hum = obj:FindFirstChildOfClass("Humanoid")
          if g and hrp and hum and hum.Health > 0 then
           -- [FIX] Validasi jarak 500 studs - cegah boss dari map lain
           if _pp and _pp.Magnitude > 1 then
            if (hrp.Position - _pp).Magnitude <= 500 then
             boss = {guid=g, hrp=hrp, model=obj}; break
            end
           else
            boss = {guid=g, hrp=hrp, model=obj}; break
           end
          end
         end
        end
       end)
      end
      if not boss then
       AscStatusUpdate("Find Boss... ("..math.floor(waitBoss).."s/5s)", Color3.fromRGB(160,148,135))
       task.wait(0.3); waitBoss = waitBoss + 0.3
      end
     end
     for _, c in ipairs(_bossEventConns) do pcall(function() c:Disconnect() end) end
     _bossEventConns = {}

     -- Helper bossPos yang aman - [v34 FIX] prioritas HumanoidRootPart bukan Head
     local function GetSafeAscBossPos()
      -- [v34 FIX] HumanoidRootPart adalah anchor fisik yang benar untuk TP
      -- Head bisa floating di atas terrain / trigger animasi salah
      local headPart = boss and (
       boss.model:FindFirstChild("HumanoidRootPart")
       or boss.model.PrimaryPart
       or boss.model:FindFirstChild("Head")
      )
      if headPart and headPart.Parent then
       local p = headPart.Position
       -- [FIX ZOMBIE] Tolak: void (Y<-200), langit (Y>1500), posisi default (Magnitude<=10)
       if p.Y > -200 and p.Y < 1500 and p.Magnitude > 10 then return p end
      end
      return nil
     end

     -- [v35] Helper: offset posisi TP agar player tidak menindih HRP boss
     -- Berdiri 3 unit ke samping dari boss -> cegah part boss hilang/terpush physics
     local function _offsetFromBoss(basePos)
      if not basePos then return nil end
      local char = LP.Character
      local pHrp = char and char:FindFirstChild("HumanoidRootPart")
      local dir
      if pHrp then
       local d = (pHrp.Position - basePos)
       local dFlat = Vector3.new(d.X, 0, d.Z)
       dir = dFlat.Magnitude > 0.5 and dFlat.Unit or Vector3.new(1, 0, 0)
      else
       dir = Vector3.new(1, 0, 0)
      end
      return basePos + dir * 3
     end

     if boss and ASC.running and not _ascDone then
      local bossGuid = boss.guid
      local bossPos = GetSafeAscBossPos()
      if not bossPos then
       local _waitPos = 0
       while not bossPos and _waitPos < 3 and ASC.running and not _ascDone do
        task.wait(0.3); _waitPos = _waitPos + 0.3
        bossPos = GetSafeAscBossPos()
       end
      end

      -- [v48] Countdown bossDelay user-controlled (sama dengan RAID)
      local _bd = math.max(1, math.min(10, ASC.bossDelay or 3))
      for _ci = _bd, 1, -1 do
       if not ASC.running or _ascDone then break end
       AscStatusUpdate("[K] Boss: "..boss.model.Name.." - TP ".._ci.."s...", Color3.fromRGB(255,160,60))
       task.wait(1)
      end

      -- Refresh bossPos setelah countdown
      bossPos = GetSafeAscBossPos()
      local _refreshWait = 0
      while not bossPos and _refreshWait < 3 and ASC.running and not _ascDone do
       task.wait(0.3); _refreshWait = _refreshWait + 0.3
       bossPos = GetSafeAscBossPos()
      end

      if ASC.running and not _ascDone and bossPos then
       AscStatusUpdate("[K] Boss: "..boss.model.Name.." - Attack!", Color3.fromRGB(255,80,80))

       -- 1) TP Player ke posisi offset dari boss (3u samping) - cegah part boss hilang
       pcall(function()
        local char = LP.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local safePos = _offsetFromBoss(GetSafeAscBossPos())
        if hrp and safePos then hrp.CFrame = CFrame.new(safePos) end
       end)

       -- 2) TP semua hero client-side ke posisi offset dari boss
       pcall(function()
        local safePos2 = _offsetFromBoss(GetSafeAscBossPos())
        if not safePos2 then return end
        local heroFolder = workspace:FindFirstChild("Heros")
        if heroFolder then
         for _, hModel in ipairs(heroFolder:GetChildren()) do
          local hHrp = hModel:FindFirstChild("HumanoidRootPart")
          if hHrp then hHrp.CFrame = CFrame.new(safePos2) end
         end
        end
       end)

       -- 3) Fire hero remotes (pakai posisi boss asli untuk server-side damage)
       pcall(function()
        local safePos3 = GetSafeAscBossPos()
        if safePos3 then FireHeroRemotes(bossGuid, safePos3) end
       end)
       if RE.HeroStand and #HERO_GUIDS > 0 then
        local safePos3b = GetSafeAscBossPos()
        if safePos3b then
         for _, hGuid in ipairs(HERO_GUIDS) do
          pcall(function() RE.HeroStand:FireServer({ heroGuid=hGuid, userId=MY_USER_ID, standPos=safePos3b+Vector3.new(1,0,1) }) end)
         end
        end
       end

       -- 4) UnEquip -> EquipBest
       task.wait(0.3)
       if RE.UnEquipHero then pcall(function() RE.UnEquipHero:FireServer() end) end
       task.wait(0.3)
       if RE.EquipBestHero then pcall(function() RE.EquipBestHero:FireServer() end) end
       task.wait(0.3)

       -- 5) TP ulang hero setelah re-equip - offset dari boss
       pcall(function()
        local safePos5 = _offsetFromBoss(GetSafeAscBossPos())
        if not safePos5 then return end
        local heroFolder = workspace:FindFirstChild("Heros")
        if heroFolder then
         for _, hModel in ipairs(heroFolder:GetChildren()) do
          local hHrp = hModel:FindFirstChild("HumanoidRootPart")
          if hHrp then hHrp.CFrame = CFrame.new(safePos5) end
         end
        end
       end)
       pcall(function()
        local safePos5b = GetSafeAscBossPos()
        if safePos5b then FireHeroRemotes(bossGuid, safePos5b) end
       end)

       -- 6) KUNCI posisi player di titik offset dari boss - cegah physics overlap
       local _ascFrozenCFrame = nil
       local _ascFreezeConn = nil
       pcall(function()
        local char = LP.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local safePos6 = _offsetFromBoss(GetSafeAscBossPos())
        if hrp and safePos6 then
         _ascFrozenCFrame = CFrame.new(safePos6)
         hrp.Anchored = true
         hrp.CFrame = _ascFrozenCFrame
         _ascFreezeConn = RunService.Heartbeat:Connect(function()
          -- [FLa CPU] skip frame ganjil → efektif ~30fps
          if not _ascFreezeFrame then _ascFreezeFrame = 0 end
          _ascFreezeFrame = _ascFreezeFrame + 1
          if _ascFreezeFrame % 2 ~= 0 then return end
          if not ASC.running or _ascDone then
           pcall(function() hrp.Anchored = false end)
           if _ascFreezeConn then _ascFreezeConn:Disconnect(); _ascFreezeConn = nil end
           return
          end
          if hrp and hrp.Parent and _ascFrozenCFrame then
           hrp.CFrame = _ascFrozenCFrame
          end
         end)
        end
       end)

       local function UnfreezeAscPlayer()
        pcall(function()
         local char = LP.Character
         local hrp = char and char:FindFirstChild("HumanoidRootPart")
         if hrp then hrp.Anchored = false end
        end)
        if _ascFreezeConn then _ascFreezeConn:Disconnect(); _ascFreezeConn = nil end
       end

       local _tpTh = nil -- tidak ada background TP thread

       -- 7) Serang boss (sama dengan RAID: 0.08s per attack)
       AscStatusUpdate("[FLa] Attack: "..boss.model.Name, Color3.fromRGB(255,80,80))
       while ASC.running do
        -- Stop jika server sudah konfirmasi sukses
        if _ascServerDone then break end
        local _curMap = GetCurrentMapId()
        if _curMap and (_curMap < 50301 or _curMap > 50326) then
         AscStatusUpdate("[!] Player keluar Tower - stop attack", Color3.fromRGB(255,140,0))
         break
        end
        if not boss.model or not boss.model.Parent then break end
        local hum = boss.model:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then break end
        local p = GetSafeAscBossPos()
        if not p then
         PG_Wait(0.08) -- [PingGuard] ASC boss attack
         if not boss.model or not boss.model.Parent then break end
         local hum2 = boss.model:FindFirstChildOfClass("Humanoid")
         if not hum2 or hum2.Health <= 0 then break end
         continue
        end
        task.spawn(function() pcall(function()
         FireAttack(bossGuid, p); FireAllDamage(bossGuid, p); FireHeroRemotes(bossGuid, p)
         FireAttack(bossGuid, p); FireAllDamage(bossGuid, p); FireHeroRemotes(bossGuid, p)
        end) end)
        PG_Wait(0.08) -- [PingGuard] ASC boss attack cycle
       end

       pcall(function() task.cancel(_tpTh) end)
       UnfreezeAscPlayer() -- lepas freeze player setelah boss mati
       -- Boss mati. _ascSuccess selalu true setelah attack loop selesai dari dalam tower.
       _ascSuccess = true
       if _ascServerDone then _ascSuccess = true end
       _ascDone = true
       AscStatusUpdate("[FLa] Boss Dead!", Color3.fromRGB(100,255,150))
      end -- if bossPos
     else
      -- Boss tidak ditemukan setelah 30s - last chance scan
      if not boss then
       pcall(function()
        for _, obj in ipairs(workspace:GetDescendants()) do
         if obj:IsA("Model") and IsBossAscWithHint(obj.Name) then
          local g = obj:GetAttribute("EnemyGuid") or obj:GetAttribute("BossGuid") or obj:GetAttribute("Guid") or obj:GetAttribute("GUID")
          local hrp = obj:FindFirstChild("HumanoidRootPart")
          local hum = obj:FindFirstChildOfClass("Humanoid")
          if g and hrp and hum and hum.Health > 0 then
           boss = {guid=g, hrp=hrp, model=obj}; break
          end
         end
        end
       end)
      end
      if not boss and ASC.running then
       AscStatusUpdate("[FLa] Boss not found (30s) - Go Out...", Color3.fromRGB(255,150,50))
       task.wait(3)
      end
     end
    else
     -- Auto Kill Boss OFF - tunggu event ChallengeRaidsSuccess max 5 menit
     local _wt = 0
     while ASC.running and not _ascDone and _wt < 300 do
      task.wait(1); _wt = _wt + 1
      -- [v64 FIX] Guard keluar Tower: cek lebih komprehensif
      -- Jika player sudah tidak di Ascension Tower (50301-50326), berarti sudah keluar
      -- (bisa karena MA/RAID TP player keluar, atau server kick, atau kolisi event)
      local wm = workspace:GetAttribute("MapId") or workspace:GetAttribute("mapId") or 0
      if wm == 0 or (wm >= 50001 and wm <= 50028) then
       AscStatusUpdate("[!] Player keluar Tower (ext) - abort wait", Color3.fromRGB(255,140,0))
       break
      end
      -- Jika player tiba-tiba di map RAID normal atau Siege, juga keluar
      if (wm >= 50101 and wm <= 50120) or (wm >= 50201 and wm <= 50204) then
       AscStatusUpdate("[!] Player di map lain - abort wait", Color3.fromRGB(255,140,0))
       break
      end
     end
    end

    if connAS then pcall(function() connAS:Disconnect() end) end
    if connAF then pcall(function() connAF:Disconnect() end) end
    -- [v64 FIX] Cancel watchdog setelah keluar Tower normal
    if _watchdogTh then pcall(function() task.cancel(_watchdogTh) end) end

    if _ascSuccess then
     ASC.sukses = ASC.sukses + 1
     AscCounterUpdate()
     AscStatusUpdate("[OK] Sukses-"..ASC.sukses.." Tower "..mn, Color3.fromRGB(100,255,150))
    end
    if not ASC.running then break end

    -- Wait reward
    if _ascSuccess then
     AscStatusUpdate("[..] Wait 1s (Get reward)...", Color3.fromRGB(100,255,150))
     task.wait(1)
    end
    if not ASC.running then break end

    -- STEP 5: Collect + Exit Tower
    task.spawn(function() pcall(RaidCollectAll) end)
    AscStatusUpdate("[FLa] Go Out Tower...", Color3.fromRGB(100,200,255))

    RAID_LIVE[raidEntry.rawId] = nil
    if raidEntry.rawId ~= raidEntry.id then RAID_LIVE[raidEntry.id] = nil end
    if RebuildRaidList then pcall(RebuildRaidList) end

    -- Keluar dari Ascension Tower (kembali ke basemap Map 1)
    local _exitRe = Remotes:FindFirstChild("QuitRaidsMap")
    if _exitRe then
     pcall(function() _exitRe:FireServer({ currentSlotIndex = 2, toMapId = 50001 }) end)
    end
    task.wait(0.3)
    pcall(function() RE.LocalTp:FireServer({ mapId = 50001 }) end)
    -- Retry exit jika masih di Ascension Tower
    local _exitTry = 0
    local function _inAscArea()
     local ok, wm = pcall(function()
      return workspace:GetAttribute("MapId") or workspace:GetAttribute("mapId") or 0
     end)
     return (ok and wm >= 50301 and wm <= 50326)
    end
    while _inAscArea() and _exitTry < 5 and ASC.running do
     _exitTry = _exitTry + 1
     task.wait(1)
     if _exitRe then pcall(function() _exitRe:FireServer({ currentSlotIndex=2, toMapId=50001 }) end) end
     task.wait(0.2)
     pcall(function() RE.LocalTp:FireServer({ mapId=50001 }) end)
    end

    ASC.inMap = false
    ASC.serverMapId = nil -- [v64 FIX] Reset agar run berikutnya tidak pakai data stale
    ReleaseMapLock("asc") -- [v52 FIX] Pastikan lock selalu dilepas saat keluar map
    -- [v62 FIX] Reset status agar tidak nyantol di "Dalam Tower x" saat sudah di Lobby
    AscStatusUpdate("[>>] Keluar Tower - cooldown...", Color3.fromRGB(160,148,135))
    for cd = 14, 1, -1 do
     if not ASC.running then break end
     AscStatusUpdate("[..] Cooldown "..cd.."s...", Color3.fromRGB(160,148,135))
     if ASC.dot then ASC.dot.BackgroundColor3 = Color3.fromRGB(255,200,60) end
     task.wait(1)
    end

    -- [v48] STEP 7: Standby loop setelah cooldown (sama dengan RAID)
    if ASC.running then
     AscStatusUpdate("[>>] Waiting & Cooldown...", Color3.fromRGB(100,255,150))
     if ASC.dot then ASC.dot.BackgroundColor3 = Color3.fromRGB(100,100,100) end
     local _fw = 0
     while ASC.running do
      -- Cek busy (Siege / Dungeon)
      local isBusy = false
      if (SIEGE and (SIEGE.inMap or SIEGE.teleporting)) then isBusy = true end
      local _wm2 = workspace:GetAttribute("MapId") or 0
      if (_wm2 >= 50201 and _wm2 <= 50204) then isBusy = true end

      -- ASC cooldown loop tidak perlu reset flag ini lagi
      -- RAID sekarang independen: jalan saat ASC.inMap = false, pause saat ASC.inMap = true

      if isBusy then
       AscStatusUpdate("[!] PAUSE: Menunggu Siege/Dungeon Selesai...", Color3.fromRGB(255,100,100))
      else
       local nextEntry = ResolveAscEntry()
       if nextEntry then
        -- [FIX] Jangan set _ascBusy di sini -> MA bebas jalan selama cooldown
        -- _ascBusy di-set nanti saat ASC benar-benar masuk tower (setelah _ascInterrupt)
        -- Tapi RAID tetap perlu pause -> set _ascBusy agar RAID tidak rebutan masuk
        _ascBusy = true  -- RAID pause (tapi MA boleh jalan, MA cek ASC.inMap/_ascInterrupt)
        break
       end
       -- Tidak ada Tower yang cocok
       if #RAID_ID_LIST == 0 then
        -- Event habis total -> RAID boleh jalan, reset cycle flag
        _ascBusy = false
        _ascMatchedThisCycle = false  -- [v61 CYCLEFIX] siklus habis, reset
        _raidFallbackActive  = false
        _eventOwner = nil             -- [v62] reset penentu siapa yang dipanggil
        AscStatusUpdate("[>>] Menunggu event RAID baru dari server...", Color3.fromRGB(120,120,120))
       elseif #GetAscensionList() > 0 then
        -- Ada Ascension tapi tidak cocok filter (grade/map)
        -- [v61 CYCLEFIX] Jika ASC pernah match di siklus ini, pertahankan _ascBusy
        -- sampai siklus event benar-benar habis (RAID_LIVE kosong)
        if _ascMatchedThisCycle then
         _ascBusy = true  -- siklus ASC belum selesai, RAID tetap pause
         AscStatusUpdate("[||] ASC cycle aktif - RAID standby sampai event habis (".._fw.."s)", Color3.fromRGB(180,100,255))
        else
         AscStatusUpdate("[FLa] Waiting grade filter... (".._fw.."s)", Color3.fromRGB(200,255,150))
        end
       else
        -- Tidak ada Ascension, tapi masih ada Raid Normal di event ini
        -- [v61 CYCLEFIX] Jika ASC sudah dominasi siklus ini (pernah match),
        -- pertahankan _ascBusy sampai RAID_LIVE kosong (siklus habis)
        if _ascMatchedThisCycle then
         _ascBusy = true  -- siklus ASC belum habis, RAID tetap pause
         AscStatusUpdate("[||] Menunggu siklus event habis - RAID standby (".._fw.."s)", Color3.fromRGB(180,100,255))
        else
         -- ASC tidak pernah match di siklus ini -> lepas _ascBusy, RAID boleh fallback
         _ascBusy = false
         _raidFallbackActive = true   -- [v61 CYCLEFIX] tandai RAID sedang fallback
         _eventOwner = "raid"         -- [v62] giliran RAID di siklus ini
         if RAID.running then
          AscStatusUpdate("[Standby] Fallback ke Auto Raid (".._fw.."s)", Color3.fromRGB(140,100,200))
         else
          -- RAID OFF -> diam saja sampai event baru
          AscStatusUpdate("[FLa] Waiting Ascension Tower... (".._fw.."s)", Color3.fromRGB(160,120,60))
         end
        end
       end
      end
      -- Wakeup cepat
      local _woken2 = false
      local _wConn2
      if _ascWakeup then
       _wConn2 = _ascWakeup.Event:Connect(function() _woken2 = true end)
      end
      local _we2 = 0
      while not _woken2 and _we2 < 1 and ASC.running do
       task.wait(0.1); _we2 = _we2 + 0.1
      end
      if _wConn2 then pcall(function() _wConn2:Disconnect() end) end
      _fw = _fw + 1
     end
    end

   until true
  end -- while ASC.running
  end) -- pcall

  -- [v63 FIX] Cleanup dijamin jalan meskipun pcall catch error di dalam loop
  ASC.running = false
  ASC.inMap   = false
  _ascBusy    = false
  _ascInterrupt = false  -- [FIX] reset cleanup
  _ascOn      = false
  _ascDominatedThisEvent = false -- [v56 DEPRECATED] tidak dipakai lagi
  _ascMatchedThisCycle  = false  -- [v61 CYCLEFIX] reset saat ASC stop
  _raidFallbackActive   = false  -- [v61 CYCLEFIX] reset saat ASC stop
  ASC._rrIdx  = 0
  AscStatusUpdate("Auto Ascension STOP", Color3.fromRGB(160,148,135))
  if ASC.dot then ASC.dot.BackgroundColor3 = Color3.fromRGB(100,100,100) end
 end)
end


-- ============================================================================
-- PANEL: AUTOMATION - AUTO RAID UI (WindUI Section accordion, identik 1.lua)
-- ============================================================================
do

-- Variabel state untuk Section collapse (slide up/down)
-- WindUI Section built-in sudah support collapse, tapi untuk full control
-- kita buat Section manual dengan callback seperti 1.lua (raidOpen/raidBody)

--  Warna grade untuk dropdown 
local GRADE_COLORS_UI = {
    ["E"]=Color3.fromRGB(150,150,150),["D"]=Color3.fromRGB(100,200,100),
    ["C"]=Color3.fromRGB(80,200,120),["B"]=Color3.fromRGB(100,140,255),
    ["A"]=Color3.fromRGB(180,100,255),["S"]=Color3.fromRGB(255,180,50),
    ["SS"]=Color3.fromRGB(255,220,0),["G"]=Color3.fromRGB(255,60,60),
    ["N"]=Color3.fromRGB(255,100,200),["M"]=Color3.fromRGB(255,0,0),
    ["M+"]=Color3.fromRGB(255,50,50),["M++"]=Color3.fromRGB(255,100,100),
    ["XM"]=Color3.fromRGB(180,0,0),["ULT"]=Color3.fromRGB(255,255,255),
}

--  PM (Pick Mode) config 
local PM_OPTS  = {"Default","By Rank","By Map","Hard","Easy","Manual"}
local PM_KEYS  = {"default","byrank","bymap","hard","easy","manual"}
local PM_TO_DIFF = {default="easy",byrank="easy",bymap="easy",hard="hard",easy="easy",manual="easy"}
local PM_UNLOCK = {
    -- map=Preferred Maps, rank=Preferred Rank, rune=Auto Item,
    -- updown=UP/DOWN (toggle+dir+grade), list=Raid List Entry
    default={map=false,rank=false,rune=false,updown=false,list=false},
    byrank ={map=false,rank=true, rune=false,updown=false,list=false},
    bymap  ={map=true, rank=false,rune=false,updown=false,list=false},
    hard   ={map=false,rank=false,rune=false,updown=false,list=false},
    easy   ={map=false,rank=false,rune=false,updown=false,list=false},
    manual ={map=true, rank=true, rune=true, updown=true, list=true },
}

--  WindUI Section: AUTO RAID (slide up/down) 
-- WindUI Tab:Section() sudah punya built-in collapse behavior (klik header = toggle)
-- Kita daftarkan semua elemen di dalam section yang sama

local raidSection = AutomationTab:Section({ Title = "Auto Raid", Icon = "sword", Opened = false, Box = true })

-- Status paragraph
local raidStatusPara = raidSection:Paragraph({
    Title = "Status",
    Desc  = "Disabled",
})
-- Expose ke RAID.statusLbl via wrapper (WindUI Paragraph tidak punya .Text property langsung)
-- Kita buat proxy: simpan ref ke Paragraph dan gunakan :Set()
local _raidStatusParaRef = raidStatusPara
RAID.statusLbl = {
    Text = "Disabled",
    TextColor3 = Color3.fromRGB(160,148,135),
}
-- Override RaidStatusUpdate agar update Paragraph WindUI
local _origRaidStatusUpdate = RaidStatusUpdate
RaidStatusUpdate = function(msg, color)
    if _raidStatusParaRef then
        pcall(function() _raidStatusParaRef:SetDesc(msg) end)
    end
    RAID.statusLbl.Text = msg
    RAID.statusLbl.TextColor3 = color or Color3.fromRGB(255,210,160)
end

-- Active Raid paragraph
local raidActivePara = raidSection:Paragraph({
    Title = "Active Raid",
    Desc  = "Waiting",
})
RAID.activeRaidLbl = {
    Text = "Waiting",
    TextColor3 = Color3.fromRGB(160,160,160),
}
local function UpdateActiveRaidLabel()
    pcall(function()
        if RAID.inMap and RAID.raidMapId then
            local rawMn = RAID.raidMapId - 50000
            local mn = RAID.serverMapId and (RAID.serverMapId - 50100) or rawMn
            local nm = MAP_NAMES and MAP_NAMES[mn] or ("Map "..tostring(mn))
            local grade = (_runeGradeCache and _runeGradeCache[mn]) or ""
            local gs = grade ~= "" and grade ~= "?" and (" ["..grade.."]") or ""
            local txt = "Map "..mn.." - "..nm..gs
            if _raidStatusParaRef then pcall(function() raidActivePara:SetDesc(txt) end) end
            RAID.activeRaidLbl.Text = txt
        else
            pcall(function() raidActivePara:SetDesc("Waiting") end)
            RAID.activeRaidLbl.Text = "Waiting"
        end
    end)
end
RAID.updateActiveLabel = UpdateActiveRaidLabel
task.spawn(function() while true do task.wait(0.3); UpdateActiveRaidLabel() end end)

-- Raid Completed paragraph
local raidCompletedPara = raidSection:Paragraph({
    Title = "Raid Completed",
    Desc  = "0",
})
RAID.suksesLbl = {
    Text = "0",
    Parent = true, -- dummy agar RaidCounterUpdate tidak crash
}
local _origRaidCounterUpdate = RaidCounterUpdate
RaidCounterUpdate = function()
    RAID.suksesLbl.Text = tostring(RAID.sukses)
    pcall(function() raidCompletedPara:SetDesc(tostring(RAID.sukses)) end)
end

--  Enable Auto Raid Toggle 
local raidEnableToggle = raidSection:Toggle({
    Flag     = "raidEnable",
    Title    = "Enable Auto Raid",
    Desc     = "Aktifkan/matikan loop Auto Raid",
    Default  = false,
    Callback = function(on)
        _raidOn = on
        if on then StartRaidLoop()
        else StopRaid(); RaidStatusUpdate("Disabled", Color3.fromRGB(160,148,135)) end
    end,
})
_setRaidToggle = function(on)
    if on == _raidOn then return end
    _raidOn = on
    pcall(function() raidEnableToggle:SetValue(on) end)
    if on then StartRaidLoop()
    else StopRaid(); RaidStatusUpdate("Disabled", Color3.fromRGB(160,148,135)) end
end

--  PICK MODE 
local curPM = 1
RAID.pickMode = PM_KEYS[curPM]

local raidPickModeDD = raidSection:Dropdown({
    Flag     = "raidPickMode",
    Title    = "Pick Mode",
    Desc     = "Pilih strategi pemilihan raid",
    Multi    = false,
    Value    = PM_OPTS[curPM],
    Values   = PM_OPTS,
    Callback = function(val)
        for i, opt in ipairs(PM_OPTS) do
            if opt == val then
                curPM = i
                RAID.pickMode = PM_KEYS[i]
                RAID.difficulty = PM_TO_DIFF[PM_KEYS[i]]
                RAID.snapshotMapId = nil
                if _applyPickModeLock then _applyPickModeLock(PM_KEYS[i]) end
                break
            end
        end
    end,
})
_setRaidPMIdx = function(ii)
    if ii < 1 or ii > #PM_KEYS then return end
    curPM = ii; RAID.pickMode = PM_KEYS[ii]
    RAID.difficulty = PM_TO_DIFF[PM_KEYS[ii]]; RAID.snapshotMapId = nil
    pcall(function() raidPickModeDD:SetValue(PM_OPTS[ii]) end)
    if _applyPickModeLock then _applyPickModeLock(PM_KEYS[ii]) end
end

--  PREFERRED MAPS
-- Default: KOSONG (tidak ada map terpilih = masuk semua map)
-- JANGAN pre-fill semua map - user tidak bisa unselect di WindUI multi dropdown kalau semua dipilih

local _mapOptNames = {"-- NOT SELECTED --"}
for i = 1, 20 do table.insert(_mapOptNames, "Map "..i) end
local _mapInitVal = {}
for i = 1, 20 do if RAID.preferMaps[i] then table.insert(_mapInitVal, "Map "..i) end end
if #_mapInitVal == 0 then _mapInitVal = {"-- NOT SELECTED --"} end

local raidPrefMapDD = raidSection:Dropdown({
    Flag     = "raidPrefMaps",
    Title    = "Preferred Maps",
    Desc     = "Pilih map yang ingin dimasuki (kosong = semua)",
    Multi    = true,
    Value    = _mapInitVal,
    Values   = _mapOptNames,
    Callback = function(val)
        for mn = 1, 20 do RAID.preferMaps[mn] = nil end
        if type(val) == "table" then
            -- Jika user pilih NOT SELECTED, clear semua dan reset visual
            local hasNotSel = false
            for _, v in ipairs(val) do
                if v == "-- NOT SELECTED --" then hasNotSel = true; break end
            end
            if hasNotSel then
                pcall(function() raidPrefMapDD:SetValue({"-- NOT SELECTED --"}) end)
                return
            end
            for _, v in ipairs(val) do
                local mi = tonumber(v:match("Map (%d+)"))
                if mi then RAID.preferMaps[mi] = true end
            end
        end
    end,
})
local function UpdatePrefLabel()
    local n = 0; local ns = {}
    for mn in pairs(RAID.preferMaps) do n=n+1; table.insert(ns,"Map "..mn) end
    table.sort(ns)
    if n == 0 then
        pcall(function() raidPrefMapDD:SetValue({"-- NOT SELECTED --"}) end)
    else
        pcall(function() raidPrefMapDD:SetValue(ns) end)
    end
end
_raidUpdatePrefLabel = UpdatePrefLabel

--  PREFERRED RANK 
local _rankInitVal = {}
for _, g in ipairs(GRADE_LIST) do
    if RAID.runeGrades[g] then table.insert(_rankInitVal, g) end
end

local _rankOptNames = {"-- NOT SELECTED --"}
for _, g in ipairs(GRADE_LIST) do table.insert(_rankOptNames, g) end
if #_rankInitVal == 0 then _rankInitVal = {"-- NOT SELECTED --"} end

local raidRankDD = raidSection:Dropdown({
    Flag     = "raidRank",
    Title    = "Preferred Rank",
    Desc     = "Filter rank raid yang ingin dimasuki",
    Multi    = true,
    Value    = _rankInitVal,
    Values   = _rankOptNames,
    Callback = function(val)
        for _, g in ipairs(GRADE_LIST) do RAID.runeGrades[g] = nil end
        if type(val) == "table" then
            -- Jika user pilih NOT SELECTED, clear semua dan reset visual
            local hasNotSel = false
            for _, v in ipairs(val) do
                if v == "-- NOT SELECTED --" then hasNotSel = true; break end
            end
            if hasNotSel then
                pcall(function() raidRankDD:SetValue({"-- NOT SELECTED --"}) end)
                if _raidWakeup then pcall(function() _raidWakeup:Fire() end) end
                return
            end
            for _, v in ipairs(val) do
                if GRADE_RANK[v] then RAID.runeGrades[v] = true end
            end
        end
        if _raidWakeup then pcall(function() _raidWakeup:Fire() end) end
    end,
})
local function RefreshRankDDLabel()
    local ns = {}
    for _, g in ipairs(GRADE_LIST) do
        if RAID.runeGrades[g] then table.insert(ns, g) end
    end
    if #ns == 0 then
        pcall(function() raidRankDD:SetValue({"-- NOT SELECTED --"}) end)
    else
        pcall(function() raidRankDD:SetValue(ns) end)
    end
end
_raidUpdateRankLabel = RefreshRankDDLabel

--  PREFERRED RUNE (Auto Item) 
local _runeOptNames = {"-- NOT SELECTED --"}
for mn = 1, 20 do
    table.insert(_runeOptNames, "Map "..mn.." - "..(MAP_NAMES[mn] or "Map "..mn))
end

local _runeInitVal = nil
if RAID.runeMapTarget >= 1 and RAID.runeMapTarget <= 20 then
    _runeInitVal = "Map "..RAID.runeMapTarget.." - "..(MAP_NAMES[RAID.runeMapTarget] or "Map "..RAID.runeMapTarget)
end

local raidRuneDD = raidSection:Dropdown({
    Flag     = "raidRune",
    Title    = "Auto Item (Rune Map)",
    Desc     = "Pilih map target item rune (opsional)",
    Multi    = false,
    Value    = _runeInitVal,
    Values   = _runeOptNames,
    Callback = function(val)
        if not val or val == "-- NOT SELECTED --" then
            RAID.runeMapTarget = 0; RAID.runeEnabled = false
        else
            local mi = tonumber(val:match("Map (%d+)"))
            if mi and mi >= 1 and mi <= 20 then
                RAID.runeMapTarget = mi; RAID.runeEnabled = true
            end
        end
    end,
})
local function SyncRuneState()
    if RAID.runeMapTarget >= 1 and RAID.runeMapTarget <= 20 then RAID.runeEnabled = true
    else RAID.runeEnabled = false end
end
_syncRaidRuneState = SyncRuneState
_setRaidRuneMapTarget = function(ml)
    RAID.runeMapTarget = ml or 0; SyncRuneState()
    if ml and ml >= 1 and ml <= 20 then
        local txt = "Map "..ml.." - "..(MAP_NAMES[ml] or "Map "..ml)
        pcall(function() raidRuneDD:SetValue(txt) end)
    else
        pcall(function() raidRuneDD:SetValue("-- NOT SELECTED --") end)
    end
end

--  UP/DOWN RANK 
-- updownDir default nil = NOT SELECTED

local raidUDToggle = raidSection:Toggle({
    Flag     = "raidUD",
    Title    = "UP/DOWN Rank",
    Desc     = "Fire UseRaidItem setelah masuk raid untuk naik/turun rank",
    Default  = RAID.updownEnabled or false,
    Callback = function(on)
        RAID.updownEnabled = on
    end,
})
_raidUpdownToggleVis = function(on)
    RAID.updownEnabled = on
    pcall(function() raidUDToggle:SetValue(on) end)
end

local raidUDDirDD = raidSection:Dropdown({
    Flag     = "raidUDDir",
    Title    = "UP/DOWN Direction",
    Desc     = "Arah rank yang diinginkan",
    Multi    = false,
    Value    = RAID.updownDir == "up" and "UP" or RAID.updownDir == "down" and "DOWN" or "-- NOT SELECTED --",
    Values   = {"-- NOT SELECTED --","UP","DOWN"},
    Callback = function(val)
        if val == "-- NOT SELECTED --" then
            RAID.updownDir = nil
        elseif val == "UP" then
            RAID.updownDir = "up"
        else
            RAID.updownDir = "down"
        end
    end,
})
_raidUpdownDirVis = function(dir)
    RAID.updownDir = dir or nil
    local disp = dir == "up" and "UP" or dir == "down" and "DOWN" or "-- NOT SELECTED --"
    pcall(function() raidUDDirDD:SetValue(disp) end)
end

local _targetGrades = {}
for i = 6, #GRADE_LIST do table.insert(_targetGrades, GRADE_LIST[i]) end
table.insert(_targetGrades, 1, "-- NOT SELECTED --")

local raidUDGradeDD = raidSection:Dropdown({
    Flag     = "raidUDGrade",
    Title    = "UP/DOWN Target Grade",
    Desc     = "Grade target lobi untuk UP/DOWN Rank",
    Multi    = false,
    Value    = RAID.updownTargetGrade or "-- NOT SELECTED --",
    Values   = _targetGrades,
    Callback = function(val)
        if val == "-- NOT SELECTED --" then RAID.updownTargetGrade = nil
        else RAID.updownTargetGrade = val end
    end,
})
_setRaidUpdownGrade = function(grade)
    RAID.updownTargetGrade = grade or nil
    pcall(function() raidUDGradeDD:SetValue(grade or "-- NOT SELECTED --") end)
end

--  AUTO KILL BOSS 
local raidBossToggle = raidSection:Toggle({
    Flag     = "raidBoss",
    Title    = "AUTO KILL BOSS",
    Desc     = "Teleport ke boss dan auto attack sampai mati",
    Default  = RAID.autoKillBoss or false,
    Callback = function(on)
        RAID.autoKillBoss = on
    end,
})
_raidBossToggleVis = function(on)
    RAID.autoKillBoss = on
    pcall(function() raidBossToggle:SetValue(on) end)
end

--  TELEPORT DELAY SLIDER 
local raidBossDelaySlider = raidSection:Slider({
    Flag     = "raidBossDelay",
    Title    = "Teleport Delay (s)",
    Desc     = "Delay sebelum teleport ke boss (1-10 detik)",
    Value    = { Min = 1, Max = 10, Default = RAID.bossDelay or 3 },
    Step     = 1,
    Callback = function(val)
        RAID.bossDelay = math.clamp(math.floor(val + 0.5), 1, 10)
    end,
})
_raidBossDelaySet = function(val)
    RAID.bossDelay = math.clamp(math.round(val), 1, 10)
    pcall(function() raidBossDelaySlider:Set(RAID.bossDelay) end)
end

--  RAID LIST ENTRY 
local raidListSection = raidSection:Section({ Title = "Raid List Entry", Icon = "list", Opened = false, Box = true })

local raidListToggle = raidListSection:Toggle({
    Flag     = "raidListEnabled",
    Title    = "List Entry",
    Desc     = "Aktifkan sistem antrian entry map+rank",
    Default  = RAID.listEnabled or false,
    Callback = function(on)
        RAID.listEnabled = on
        if _raidWakeup then pcall(function() _raidWakeup:Fire() end) end
    end,
})
_setRaidListEnabledVis = function(on)
    RAID.listEnabled = on
    pcall(function() raidListToggle:SetValue(on) end)
end

-- Save Entry button: snapshot maps + rank sekarang ke list
local raidListSaveBtn = raidListSection:Button({
    Title    = "+ Save Entry",
    Desc     = "Simpan kombinasi map+rank sekarang ke list",
    Callback = function()
        local snapMaps = {}; for mn,v in pairs(RAID.preferMaps) do snapMaps[mn]=v end
        local snapRanks = {}; for g,v in pairs(RAID.runeGrades) do snapRanks[g]=v end
        table.insert(RAID.listEntries, {maps=snapMaps, ranks=snapRanks})
        -- Rebuild display
        if _raidRebuildListRows then _raidRebuildListRows() end
    end,
})

-- Entry list paragraph (tampilkan daftar entry)
local _raidListPara = raidListSection:Paragraph({
    Title = "Saved Entries",
    Desc  = "(kosong)",
})
local function RebuildListDisplay()
    if #RAID.listEntries == 0 then
        pcall(function() _raidListPara:SetDesc("(kosong)") end)
        return
    end
    local lines = {}
    for i, ent in ipairs(RAID.listEntries) do
        local mapsStr
        if not next(ent.maps) then mapsStr = "All Maps"
        else
            local ms = {}; for mn in pairs(ent.maps) do table.insert(ms,mn) end
            table.sort(ms); local parts = {}
            for _, mn in ipairs(ms) do table.insert(parts, "M"..mn) end
            mapsStr = table.concat(parts,",")
        end
        local ranksStr
        if not next(ent.ranks) then ranksStr = "All"
        else
            local rs = {}
            for _, g in ipairs(GRADE_LIST) do if ent.ranks[g] then table.insert(rs,g) end end
            ranksStr = table.concat(rs,"/")
        end
        table.insert(lines, "#"..i.." "..mapsStr.." | "..ranksStr)
    end
    pcall(function() _raidListPara:SetDesc(table.concat(lines,"\n")) end)
end
_raidRebuildListRows = RebuildListDisplay

-- Tombol hapus entry terakhir
local raidListDeleteBtn = raidListSection:Button({
    Title    = "- Hapus Entry Terakhir",
    Desc     = "Hapus entry paling bawah dari list",
    Callback = function()
        if #RAID.listEntries > 0 then
            table.remove(RAID.listEntries)
            RebuildListDisplay()
        end
    end,
})

--  APPLY PICK MODE LOCK 
-- Dipanggil saat Pick Mode berubah.
-- Lock = clear data + reset UI ke NOT SELECTED + update Desc sebagai indikator visual.
-- WindUI tidak punya :SetEnabled() native, jadi kita gunakan flag guard + Desc label.

local function _doApplyLock(pm)
    local u = PM_UNLOCK[pm] or {map=false,rank=false,rune=false,updown=false,list=false}
    local lockMsg = "Tidak tersedia di mode " .. pm

    -- Preferred Maps
    _prefLocked = not u.map
    if _prefLocked then
        for k in pairs(RAID.preferMaps) do RAID.preferMaps[k] = nil end
        pcall(function() raidPrefMapDD:SetValue({}) end)
        pcall(function() raidPrefMapDD:Lock(lockMsg) end)
    else
        pcall(function() raidPrefMapDD:Unlock() end)
    end

    -- Preferred Rank
    _rankLocked = not u.rank
    if _rankLocked then
        for _, g in ipairs(GRADE_LIST) do RAID.runeGrades[g] = nil end
        pcall(function() raidRankDD:SetValue({}) end)
        pcall(function() raidRankDD:Lock(lockMsg) end)
    else
        pcall(function() raidRankDD:Unlock() end)
    end

    -- Auto Item (Rune)
    _runeLocked = not u.rune
    if _runeLocked then
        RAID.runeMapTarget = 0; RAID.runeEnabled = false
        pcall(function() raidRuneDD:SetValue("-- NOT SELECTED --") end)
        pcall(function() raidRuneDD:Lock(lockMsg) end)
    else
        pcall(function() raidRuneDD:Unlock() end)
    end

    -- UP/DOWN Rank + Direction + Target Grade
    _updownLocked = not u.updown
    if _updownLocked then
        RAID.updownEnabled = false; RAID.updownDir = nil; RAID.updownTargetGrade = nil
        pcall(function() raidUDToggle:SetValue(false) end)
        pcall(function() raidUDDirDD:SetValue("-- NOT SELECTED --") end)
        pcall(function() raidUDGradeDD:SetValue("-- NOT SELECTED --") end)
        pcall(function() raidUDToggle:Lock(lockMsg) end)
        pcall(function() raidUDDirDD:Lock(lockMsg) end)
        pcall(function() raidUDGradeDD:Lock(lockMsg) end)
    else
        pcall(function() raidUDToggle:Unlock() end)
        pcall(function() raidUDDirDD:Unlock() end)
        pcall(function() raidUDGradeDD:Unlock() end)
    end

    -- Raid List Entry
    _listLocked = not u.list
    if _listLocked then
        RAID.listEnabled = false
        pcall(function() raidListToggle:SetValue(false) end)
        pcall(function() raidListToggle:Lock(lockMsg) end)
        pcall(function() raidListSaveBtn:Lock(lockMsg) end)
        pcall(function() raidListDeleteBtn:Lock(lockMsg) end)
    else
        pcall(function() raidListToggle:Unlock() end)
        pcall(function() raidListSaveBtn:Unlock() end)
        pcall(function() raidListDeleteBtn:Unlock() end)
    end
end

_applyPickModeLock = _doApplyLock

-- Inisialisasi flag lock sesuai pickMode awal
_prefLocked   = not (PM_UNLOCK[RAID.pickMode or "default"] or {}).map
_rankLocked   = not (PM_UNLOCK[RAID.pickMode or "default"] or {}).rank
_runeLocked   = not (PM_UNLOCK[RAID.pickMode or "default"] or {}).rune
_updownLocked = not (PM_UNLOCK[RAID.pickMode or "default"] or {}).updown
_listLocked   = not (PM_UNLOCK[RAID.pickMode or "default"] or {}).list

-- Apply lock saat script load (defer agar semua elemen sudah terdaftar ke WindUI)
task.defer(function() _doApplyLock(RAID.pickMode or "default") end)

RebuildListDisplay()

end -- end do: AUTO RAID UI


-- ============================================================================
-- PANEL: AUTOMATION - AUTO RAID ASCENSION UI (WindUI Section accordion)
-- Port dari 1.lua baris 14700-15506 ke WindUI, mengikuti pattern raidSection
-- Ditaruh DI BAWAH Auto Raid (AutomationTab:Section sendiri, slide up/down
-- bawaan WindUI Section), independen dari RAID Normal (sesuai keputusan)
-- ============================================================================
do

local ascSection = AutomationTab:Section({ Title = "Auto Raid Ascension", Icon = "swords", Opened = false, Box = true })

--  STATUS 
local ascStatusPara = ascSection:Paragraph({
    Title = "Status",
    Desc  = "Disabled",
})
ASC.statusLbl = {
    Text = "Disabled",
    TextColor3 = Color3.fromRGB(160,148,135),
}
local _origAscStatusUpdate = AscStatusUpdate
AscStatusUpdate = function(msg, color)
    pcall(function() ascStatusPara:SetDesc(msg) end)
    ASC.statusLbl.Text = msg
    ASC.statusLbl.TextColor3 = color or Color3.fromRGB(255,200,100)
end

--  ASCENSION COMPLETED 
local ascCompletedPara = ascSection:Paragraph({
    Title = "Ascension Completed",
    Desc  = "0",
})
ASC.suksesLbl = {
    Text = "0",
}
local _origAscCounterUpdate = AscCounterUpdate
AscCounterUpdate = function()
    ASC.suksesLbl.Text = tostring(ASC.sukses)
    pcall(function() ascCompletedPara:SetDesc(tostring(ASC.sukses)) end)
end

--  ENABLE AUTO ASCENSION TOGGLE 
local ascEnableToggle = ascSection:Toggle({
    Flag     = "ascEnable",
    Title    = "Enable Auto Ascension",
    Desc     = "Aktifkan/matikan loop Auto Raid Ascension",
    Default  = false,
    Callback = function(on)
        _ascOn = on
        if on then StartAscensionLoop()
        else StopAscension(); AscStatusUpdate("Disabled", Color3.fromRGB(160,148,135)) end
    end,
})
_setAscToggle = function(on)
    if on == _ascOn then return end
    _ascOn = on
    pcall(function() ascEnableToggle:SetValue(on) end)
    if on then StartAscensionLoop()
    else StopAscension(); AscStatusUpdate("Disabled", Color3.fromRGB(160,148,135)) end
end

--  PICK MODE 
local APM_OPTS   = {"Default","By Rank","By Map","Hard","Easy","Manual"}
local APM_KEYS   = {"default","byrank","bymap","hard","easy","manual"}
local APM_TO_DESC = {
    default = "Join Tower apapun tanpa filter",
    byrank  = "Filter by Preferred Rank",
    bymap   = "Filter by Preferred Map",
    hard    = "Selalu pilih Tower terbesar",
    easy    = "Selalu pilih Tower terkecil",
    manual  = "Setting manual: Map, Rank, Rune",
}
-- Unlock rule per mode (identik 1.lua APM_UNLOCK):
local APM_UNLOCK = {
    default = {map=false, rank=false, rune=false},
    byrank  = {map=false, rank=true,  rune=false},
    bymap   = {map=true,  rank=false, rune=false},
    hard    = {map=false, rank=false, rune=false},
    easy    = {map=false, rank=false, rune=false},
    manual  = {map=true,  rank=true,  rune=true },
}
local curAPM = 5 -- default: "easy" (sama seperti 1.lua)
ASC.pickMode = APM_KEYS[curAPM]

local ascPickModeDD = ascSection:Dropdown({
    Flag     = "ascPickMode",
    Title    = "Pick Mode",
    Desc     = APM_TO_DESC[ASC.pickMode],
    Multi    = false,
    Value    = APM_OPTS[curAPM],
    Values   = APM_OPTS,
    Callback = function(val)
        for i, opt in ipairs(APM_OPTS) do
            if opt == val then
                curAPM = i
                ASC.pickMode = APM_KEYS[i]
                pcall(function() ascPickModeDD:SetDesc(APM_TO_DESC[ASC.pickMode]) end)
                if _applyAscPickModeLock then _applyAscPickModeLock(ASC.pickMode) end
                break
            end
        end
    end,
})
_setAscPMIdx = function(ii)
    if ii < 1 or ii > #APM_KEYS then return end
    curAPM = ii; ASC.pickMode = APM_KEYS[ii]
    pcall(function() ascPickModeDD:SetValue(APM_OPTS[ii]) end)
    if _applyAscPickModeLock then _applyAscPickModeLock(ASC.pickMode) end
end

--  PREFERRED MAP (Tower tujuan masuk, 1-26) 
-- Default: KOSONG (tidak ada Tower terpilih = masuk semua Tower)
local ASC_TOWER_NAMES = {
    [1]="Baran",       [2]="Baran+1",
    [3]="Grendal",     [4]="Grendal+1",
    [5]="Plague",      [6]="Plague+1",
    [7]="Frostborne",  [8]="Frostborne+1",
    [9]="Legia",       [10]="Legia+1",
    [11]="Silas",      [12]="Silas+1",
    [13]="Yogumunt",   [14]="Yogumunt+1",
    [15]="Antares",    [16]="Antares+1",
    [17]="Ashborn",    [18]="Ashborn+1",
    [19]="Dominion",   [20]="Dominion+1",
    [21]="Absolute",   [22]="Absolute+1",
    [23]="Broly",      [24]="Broly+1",
    [25]="Goku Super 4", [26]="Goku Super 4+1",
}

local _ascMapOptNames = {"-- NOT SELECTED --"}
for i = 1, 26 do table.insert(_ascMapOptNames, "Tower "..i.." - "..(ASC_TOWER_NAMES[i] or ("Tower "..i))) end
local _ascMapInitVal = {}
for i = 1, 26 do if ASC.preferMaps[i] then table.insert(_ascMapInitVal, "Tower "..i.." - "..(ASC_TOWER_NAMES[i] or ("Tower "..i))) end end
if #_ascMapInitVal == 0 then _ascMapInitVal = {"-- NOT SELECTED --"} end

local ascPrefMapDD = ascSection:Dropdown({
    Flag     = "ascPrefMap",
    Title    = "Preferred Map",
    Desc     = "Pilih Tower yang ingin dimasuki (kosong = semua)",
    Multi    = true,
    Value    = _ascMapInitVal,
    Values   = _ascMapOptNames,
    Callback = function(val)
        for mn = 1, 26 do ASC.preferMaps[mn] = nil end
        if type(val) == "table" then
            local hasNotSel = false
            for _, v in ipairs(val) do
                if v == "-- NOT SELECTED --" then hasNotSel = true; break end
            end
            if hasNotSel then
                pcall(function() ascPrefMapDD:SetValue({"-- NOT SELECTED --"}) end)
                return
            end
            for _, v in ipairs(val) do
                local mi = tonumber(v:match("Tower (%d+)"))
                if mi then ASC.preferMaps[mi] = true end
            end
        end
    end,
})
local function UpdateAscPrefMapLabel()
    local ns = {}
    for mn = 1, 26 do
        if ASC.preferMaps[mn] then table.insert(ns, "Tower "..mn.." - "..(ASC_TOWER_NAMES[mn] or ("Tower "..mn))) end
    end
    if #ns == 0 then
        pcall(function() ascPrefMapDD:SetValue({"-- NOT SELECTED --"}) end)
    else
        pcall(function() ascPrefMapDD:SetValue(ns) end)
    end
end

--  PREFERRED RANK 
local _ascRankInitVal = {}
for _, g in ipairs(GRADE_LIST) do
    if ASC.runeGrades[g] then table.insert(_ascRankInitVal, g) end
end
local _ascRankOptNames = {"-- NOT SELECTED --"}
for _, g in ipairs(GRADE_LIST) do table.insert(_ascRankOptNames, g) end
if #_ascRankInitVal == 0 then _ascRankInitVal = {"-- NOT SELECTED --"} end

local ascRankDD = ascSection:Dropdown({
    Flag     = "ascRank",
    Title    = "Preferred Rank",
    Desc     = "Filter rank Tower yang ingin dimasuki",
    Multi    = true,
    Value    = _ascRankInitVal,
    Values   = _ascRankOptNames,
    Callback = function(val)
        for _, g in ipairs(GRADE_LIST) do ASC.runeGrades[g] = nil end
        if type(val) == "table" then
            local hasNotSel = false
            for _, v in ipairs(val) do
                if v == "-- NOT SELECTED --" then hasNotSel = true; break end
            end
            if hasNotSel then
                pcall(function() ascRankDD:SetValue({"-- NOT SELECTED --"}) end)
                if _ascWakeup then pcall(function() _ascWakeup:Fire() end) end
                return
            end
            for _, v in ipairs(val) do
                if GRADE_RANK[v] then ASC.runeGrades[v] = true end
            end
        end
        if _ascWakeup then pcall(function() _ascWakeup:Fire() end) end
    end,
})
local function RefreshAscRankLabel()
    local ns = {}
    for _, g in ipairs(GRADE_LIST) do if ASC.runeGrades[g] then table.insert(ns, g) end end
    if #ns == 0 then
        pcall(function() ascRankDD:SetValue({"-- NOT SELECTED --"}) end)
    else
        pcall(function() ascRankDD:SetValue(ns) end)
    end
end

--  PREFERRED RUNE (Auto Item) 
local _ascRuneOptNames = {"-- NOT SELECTED --"}
for mn = 1, 26 do
    table.insert(_ascRuneOptNames, "Tower "..mn.." - "..(ASC_TOWER_NAMES[mn] or ("Tower "..mn)))
end
local _ascRuneInitVal = nil
if ASC.runeMapTarget >= 1 and ASC.runeMapTarget <= 26 then
    _ascRuneInitVal = "Tower "..ASC.runeMapTarget.." - "..(ASC_TOWER_NAMES[ASC.runeMapTarget] or ("Tower "..ASC.runeMapTarget))
end

local ascRuneDD = ascSection:Dropdown({
    Flag     = "ascRune",
    Title    = "Auto Item (Rune Tower)",
    Desc     = "Pilih Tower target item rune (opsional)",
    Multi    = false,
    Value    = _ascRuneInitVal,
    Values   = _ascRuneOptNames,
    Callback = function(val)
        if not val or val == "-- NOT SELECTED --" then
            ASC.runeMapTarget = 0; ASC.runeEnabled = false
        else
            local mi = tonumber(val:match("Tower (%d+)"))
            if mi and mi >= 1 and mi <= 26 then
                ASC.runeMapTarget = mi; ASC.runeEnabled = true
            end
        end
    end,
})
local function AscSyncRuneState()
    if ASC.runeMapTarget >= 1 and ASC.runeMapTarget <= 26 then ASC.runeEnabled = true
    else ASC.runeEnabled = false end
end
AscSyncRuneState()

--  AUTO KILL BOSS 
local ascBossToggle = ascSection:Toggle({
    Flag     = "ascBoss",
    Title    = "AUTO KILL BOSS",
    Desc     = "Teleport ke boss dan auto attack sampai mati",
    Default  = ASC.autoKillBoss or false,
    Callback = function(on)
        ASC.autoKillBoss = on
    end,
})
_ascBossToggleVis = function(on)
    ASC.autoKillBoss = on
    pcall(function() ascBossToggle:SetValue(on) end)
end

--  TELEPORT DELAY SLIDER 
local ascBossDelaySlider = ascSection:Slider({
    Flag     = "ascBossDelay",
    Title    = "Teleport Delay (s)",
    Desc     = "Delay sebelum teleport ke boss (1-10 detik)",
    Value    = { Min = 1, Max = 10, Default = ASC.bossDelay or 3 },
    Step     = 1,
    Callback = function(val)
        ASC.bossDelay = math.clamp(math.floor(val + 0.5), 1, 10)
    end,
})
_ascBossDelaySet = function(val)
    ASC.bossDelay = math.clamp(math.round(val), 1, 10)
    pcall(function() ascBossDelaySlider:Set(ASC.bossDelay) end)
end

--  LIST ENTRY ASC 
local ascListSection = ascSection:Section({ Title = "Ascension List Entry", Icon = "list", Opened = false, Box = true })

local ascListToggle = ascListSection:Toggle({
    Flag     = "ascListEnabled",
    Title    = "List Entry",
    Desc     = "Aktifkan sistem antrian entry Tower+rank",
    Default  = ASC.listEnabled or false,
    Callback = function(on)
        ASC.listEnabled = on
        if _ascWakeup then pcall(function() _ascWakeup:Fire() end) end
    end,
})
_setAscListEnabledVis = function(on)
    ASC.listEnabled = on
    pcall(function() ascListToggle:SetValue(on) end)
end

local ascListSaveBtn = ascListSection:Button({
    Title    = "+ Save Entry",
    Desc     = "Simpan kombinasi Tower+rank sekarang ke list",
    Callback = function()
        local snapMaps = {}
        for mn = 1, 26 do if ASC.preferMaps[mn] then snapMaps[mn] = true end end
        local snapRanks = {}
        for _, g in ipairs(GRADE_LIST) do if ASC.runeGrades[g] then snapRanks[g] = true end end
        -- Cegah duplikat (identik 1.lua)
        for _, ent in ipairs(ASC.listEntries) do
            local dupMap, dupRank = true, true
            for mn = 1, 26 do
                if (snapMaps[mn] ~= nil) ~= (ent.maps[mn] ~= nil) then dupMap = false; break end
            end
            for _, g in ipairs(GRADE_LIST) do
                if (snapRanks[g] ~= nil) ~= (ent.ranks[g] ~= nil) then dupRank = false; break end
            end
            if dupMap and dupRank then return end
        end
        table.insert(ASC.listEntries, {maps=snapMaps, ranks=snapRanks})
        if _ascRebuildListRows then _ascRebuildListRows() end
    end,
})

local _ascListPara = ascListSection:Paragraph({
    Title = "Saved Entries",
    Desc  = "(kosong)",
})
local function AscRebuildListDisplay()
    if #ASC.listEntries == 0 then
        pcall(function() _ascListPara:SetDesc("(kosong)") end)
        return
    end
    local lines = {}
    for i, ent in ipairs(ASC.listEntries) do
        local mapsStr
        if not next(ent.maps) then mapsStr = "All Tower"
        else
            local ms = {}; for mn in pairs(ent.maps) do table.insert(ms, mn) end
            table.sort(ms); local parts = {}
            for _, mn in ipairs(ms) do table.insert(parts, "T"..mn) end
            mapsStr = table.concat(parts, ",")
        end
        local ranksStr
        if not next(ent.ranks) then ranksStr = "All"
        else
            local rs = {}
            for _, g in ipairs(GRADE_LIST) do if ent.ranks[g] then table.insert(rs, g) end end
            ranksStr = table.concat(rs, "/")
        end
        table.insert(lines, "#"..i.." "..mapsStr.." | "..ranksStr)
    end
    pcall(function() _ascListPara:SetDesc(table.concat(lines, "\n")) end)
end
_ascRebuildListRows = AscRebuildListDisplay

local ascListDeleteBtn = ascListSection:Button({
    Title    = "- Hapus Entry Terakhir",
    Desc     = "Hapus entry paling bawah dari list",
    Callback = function()
        if #ASC.listEntries > 0 then
            table.remove(ASC.listEntries)
            AscRebuildListDisplay()
        end
    end,
})

--  APPLY ASC PICK MODE LOCK 
-- Dipanggil saat Pick Mode berubah. Identik pattern RAID: lock = clear data + Lock()/Unlock()
local _ascPrefLocked, _ascRankLocked, _ascRuneLocked = false, false, false

local function _doApplyAscLock(pm)
    local u = APM_UNLOCK[pm] or {map=false, rank=false, rune=false}
    local lockMsg = "Tidak tersedia di mode " .. pm

    -- Preferred Map
    _ascPrefLocked = not u.map
    if _ascPrefLocked then
        for mn = 1, 26 do ASC.preferMaps[mn] = nil end
        pcall(function() ascPrefMapDD:SetValue({}) end)
        pcall(function() ascPrefMapDD:Lock(lockMsg) end)
    else
        pcall(function() ascPrefMapDD:Unlock() end)
    end

    -- Preferred Rank
    _ascRankLocked = not u.rank
    if _ascRankLocked then
        for _, g in ipairs(GRADE_LIST) do ASC.runeGrades[g] = nil end
        pcall(function() ascRankDD:SetValue({}) end)
        pcall(function() ascRankDD:Lock(lockMsg) end)
    else
        pcall(function() ascRankDD:Unlock() end)
    end

    -- Auto Item (Rune)
    _ascRuneLocked = not u.rune
    if _ascRuneLocked then
        ASC.runeMapTarget = 0; ASC.runeEnabled = false
        pcall(function() ascRuneDD:SetValue("-- NOT SELECTED --") end)
        pcall(function() ascRuneDD:Lock(lockMsg) end)
    else
        pcall(function() ascRuneDD:Unlock() end)
    end
end

_applyAscPickModeLock = _doApplyAscLock

-- Inisialisasi flag lock sesuai pickMode awal
_ascPrefLocked = not (APM_UNLOCK[ASC.pickMode or "easy"] or {}).map
_ascRankLocked = not (APM_UNLOCK[ASC.pickMode or "easy"] or {}).rank
_ascRuneLocked = not (APM_UNLOCK[ASC.pickMode or "easy"] or {}).rune

-- Apply lock saat script load (defer agar semua elemen sudah terdaftar ke WindUI)
task.defer(function() _doApplyAscLock(ASC.pickMode or "easy") end)

AscRebuildListDisplay()

end -- end do: AUTO RAID ASCENSION UI



-- ============================================================================
-- AUTO SIEGE - v100 [PORT dari 1.lua ke WindUI]
-- Flow:
--   1. Toggle ON -> tunggu UpdateCityRaidInfo dari server (SIEGE.live diisi scanner)
--   2. Notif masuk -> TP player ke baseMapId (LocalTp)
--   3. Delay 2 detik
--   4. Fire entry remotes: EnterCityRaidMap -> StartLocalPlayerTeleport
--      -> LocalPlayerTeleportSuccess -> EquipHeroWithData
--   5. Delay 4 detik (render musuh)
--   6. Validasi: scan workspace cari Map201-Map205
--   7. Serang semua musuh, pantau Map201-Map205 masih ada. Jika hilang -> stop
--   8. QuitCityRaidMap -> cleanup -> count -> tunggu notif berikutnya
-- ============================================================================

-- DATA & CONSTANTS
local SIEGE_DATA = {
    [3]  = {name="Map 3  - Shadow Castle",       cityRaidId=1000001, tpMapId=50201, baseMapId=50003, mapFolder="Map201"},
    [7]  = {name="Map 7  - Demon Castle Tier 2",  cityRaidId=1000002, tpMapId=50202, baseMapId=50007, mapFolder="Map202"},
    [10] = {name="Map 10 - Plagueheart",          cityRaidId=1000003, tpMapId=50203, baseMapId=50010, mapFolder="Map203"},
    [13] = {name="Map 13 - Lava Hell",            cityRaidId=1000004, tpMapId=50204, baseMapId=50013, mapFolder="Map204"},
    [18] = {name="Map 18 - Golden Throne",        cityRaidId=1000005, tpMapId=50205, baseMapId=50018, mapFolder="Map205"},
}
local SIEGE_MAP_NUMS = {3, 7, 10, 13, 18}

-- Kill target semua map Siege (paten)
local SIEGE_KILL_TARGET  = 30
-- Radius serang dari posisi player (studs)
local SIEGE_ATTACK_RADIUS = 2000

-- STATE TABLE
if not SIEGE then
    SIEGE = {
        running      = false,
        thread       = nil,
        inMap        = false,
        teleporting  = false,
        excludeMaps  = {[3]=false,[7]=false,[10]=false,[13]=false,[18]=false},
        statusLbl    = nil,
        dot          = nil,
        countSummaryLbl = nil,
        count        = {[3]=0,[7]=0,[10]=0,[13]=0,[18]=0},
        killed       = 0,
        live         = {},
        _lastExitTime = 0,
    }
end

_siegeToggleState = _siegeToggleState or false
_siegeSessionStart = _siegeSessionStart or nil
local _siegeWakeup = nil

-- Forward declare UI helpers (diisi oleh panel)
_setSiegeToggle      = _setSiegeToggle      or nil
_updateSiegeDdLabel  = _updateSiegeDdLabel  or nil

-- Status helper
SiegeStatus = function(msg, color)
    if SIEGE.statusLbl then
        local ts = ""
        if _siegeSessionStart then
            local dur = os.time() - _siegeSessionStart
            ts = string.format("[%02d:%02d:%02d] ", math.floor(dur/3600), math.floor(dur/60)%60, dur%60)
        end
        SIEGE.statusLbl.Text = ts .. msg
        SIEGE.statusLbl.TextColor3 = color or Color3.fromRGB(160,148,135)
    end
    if SIEGE.dot then
        SIEGE.dot.BackgroundColor3 = color or Color3.fromRGB(100,100,100)
    end
end

SiegeCounterUpdate = function()
    if SIEGE.countSummaryLbl then
        local parts = {}
        for _, mn in ipairs(SIEGE_MAP_NUMS) do
            table.insert(parts, "M"..mn..":"..(SIEGE.count[mn] or 0))
        end
        SIEGE.countSummaryLbl.Text = table.concat(parts, "  ")
    end
end

-- Stop
StopSiege = function()
    SIEGE.running     = false
    SIEGE.inMap       = false
    SIEGE.teleporting = false
    SIEGE._lastExitTime = os.time()
    _siegeInterrupt   = false
    MODE:Release("siege")
    if MODE.current == "siege" then MODE.current = "idle" end
    if SIEGE.thread then
        pcall(function() task.cancel(SIEGE.thread) end)
        SIEGE.thread = nil
    end
    SiegeStatus("[FLa] Idle", Color3.fromRGB(100,100,100))
end

-- Helper: cek player masih di Siege map (workspace scan)
local function IsInSiegeMapNow()
    for _, obj in ipairs(workspace:GetChildren()) do
        local n = obj.Name
        if n == "Map201" or n == "Map202" or n == "Map203"
        or n == "Map204" or n == "Map205" then
            return true
        end
    end
    local mf = workspace:FindFirstChild("Maps")
    if mf then
        for i = 1, 5 do
            if mf:FindFirstChild("Map20"..i) then return true end
        end
    end
    local ok, wm = pcall(function()
        return workspace:GetAttribute("MapId")
            or workspace:GetAttribute("mapId")
            or workspace:GetAttribute("CurrentMapId")
    end)
    if ok and type(wm) == "number" and wm >= 50201 and wm <= 50205 then
        return true
    end
    return false
end

-- Helper: scan musuh Siege dalam radius SIEGE_ATTACK_RADIUS dari posisi player
local function GetSiegeEnemies(mapFolder)
    local list, seen = {}, {}
    local FOLDERS = {"Enemys","EnemyCityRaid","CityRaidEnemys","Enemies","Enemy"}

    -- Ambil posisi player untuk filter radius
    local _playerPos = nil
    local _lp = game:GetService("Players").LocalPlayer
    if _lp and _lp.Character then
        local _hrp = _lp.Character:FindFirstChild("HumanoidRootPart")
        if _hrp then _playerPos = _hrp.Position end
    end

    local function _add(e)
        if not e:IsA("Model") then return end
        if not e:IsDescendantOf(workspace) then return end
        local g   = e:GetAttribute("EnemyGuid") or e:GetAttribute("BossGuid")
                 or e:GetAttribute("Guid")       or e:GetAttribute("GUID")
        local h   = e:FindFirstChild("HumanoidRootPart")
        local hum = e:FindFirstChildOfClass("Humanoid")
        if not (g and h and hum) then return end
        if seen[g] then return end
        if hum.Health <= 0 then return end
        if hum.MaxHealth <= 0 then return end
        local p = h.Position
        if p.Magnitude <= 10 then return end
        if p.Y < -200 or p.Y > 1500 then return end
        if not h:IsDescendantOf(workspace) then return end
        -- Filter radius: skip enemy yang lebih jauh dari SIEGE_ATTACK_RADIUS
        if _playerPos and (p - _playerPos).Magnitude > SIEGE_ATTACK_RADIUS then return end
        seen[g] = true
        table.insert(list, {model=e, guid=g, hrp=h})
    end
    -- Prioritas 1: nested di map folder aktif (anti-kontaminasi enemy Raid/ASC)
    if mapFolder then
        local mf = workspace:FindFirstChild(mapFolder)
        if mf then
            for _, fname in ipairs(FOLDERS) do
                local f = mf:FindFirstChild(fname)
                if f then for _, e in ipairs(f:GetChildren()) do _add(e) end end
            end
        end
    end
    -- Prioritas 2: fallback top-level workspace
    if #list == 0 then
        for _, fname in ipairs(FOLDERS) do
            local f = workspace:FindFirstChild(fname)
            if f then for _, e in ipairs(f:GetChildren()) do _add(e) end end
        end
    end
    if #list == 0 then
        for _, obj in ipairs(workspace:GetChildren()) do _add(obj) end
    end
    return list
end

-- FireAllDamage & FireHeroRemotes lokal untuk Siege
local function _SiegeFireDamage(g, ep)
    if RE.Click then
        task.spawn(function()
            pcall(function() RE.Click:InvokeServer({enemyGuid=g}) end)
        end)
    end
    if RE.Atk then
        pcall(function() RE.Atk:FireServer({attackEnemyGUID=g}) end)
    end
    if RE.HeroUseSkill then
        for _, hGuid in ipairs(HERO_GUIDS) do
            pcall(function() RE.HeroUseSkill:FireServer({heroGuid=hGuid, enemyGuid=g}) end)
        end
    elseif RE.HeroSkill then
        for _, hGuid in ipairs(HERO_GUIDS) do
            pcall(function() RE.HeroSkill:FireServer({heroGuid=hGuid,enemyGuid=g,skillType=1,masterId=MY_USER_ID}) end)
            pcall(function() RE.HeroSkill:FireServer({heroGuid=hGuid,enemyGuid=g,skillType=2,masterId=MY_USER_ID}) end)
            pcall(function() RE.HeroSkill:FireServer({heroGuid=hGuid,enemyGuid=g,skillType=3,masterId=MY_USER_ID}) end)
        end
    end
end

local function _SiegeFireHeroMoves(g, ep)
    local pos = ep or Vector3.new(0,0,0)
    if #HERO_GUIDS == 0 then return end
    local posInfos = {}
    for _, hGuid in ipairs(HERO_GUIDS) do
        table.insert(posInfos, {heroGuid=hGuid, targetPos=pos})
    end
    if RE.HeroMove then
        pcall(function() RE.HeroMove:FireServer({attackTarget=g,userId=MY_USER_ID,heroTagetPosInfos=posInfos}) end)
        pcall(function() RE.HeroMove:FireServer({attackTarget=g,userId=MY_USER_ID,heroTagetPosInfos=posInfos}) end)
    end
end

-- Core: SiegeAttackLoop
local function SiegeAttackLoop(onStatus, d)
    local MAX_TIME   = 120
    local totalTime  = 0
    local deadGuids  = {}
    local killCount  = 0

    local _deathConn = nil
    if RE.Death then
        _deathConn = RE.Death.OnClientEvent:Connect(function(dd)
            if not dd then return end
            local g = dd.enemyGuid or dd.guid
            if g and not deadGuids[g] then
                deadGuids[g] = true
                killCount = killCount + 1
                SIEGE.killed = SIEGE.killed + 1
            end
        end)
    end

    local function cleanup()
        if _deathConn then _deathConn:Disconnect(); _deathConn = nil end
    end

    while SIEGE.running and SIEGE.inMap do
        totalTime = totalTime + 0.08

        if totalTime >= MAX_TIME then
            if onStatus then onStatus("[!] Timeout - paksa keluar") end
            cleanup(); return "timeout"
        end

        if not IsInSiegeMapNow() then
            if onStatus then onStatus("[OK] Player keluar Siege map - stop serang") end
            cleanup(); return "exited"
        end

        -- Kill target tercapai (30 musuh) -> keluar map, anggap selesai
        if killCount >= SIEGE_KILL_TARGET then
            if onStatus then onStatus(string.format("[OK] %d kill tercapai - selesai!", killCount)) end
            cleanup(); return "success"
        end

        local enemies = GetSiegeEnemies(d and d.mapFolder)
        local targets = {}
        for _, e in ipairs(enemies) do
            if not deadGuids[e.guid] then
                table.insert(targets, e)
            end
        end

        if #targets == 0 then
            if onStatus then onStatus(string.format("[~] Tunggu musuh... kill: %d/%d", killCount, SIEGE_KILL_TARGET)) end
        else
            if onStatus then
                onStatus(string.format("[ATK] %d target | kill: %d/%d", #targets, killCount, SIEGE_KILL_TARGET))
            end
            for _, e in ipairs(targets) do
                if e.model and e.model.Parent then
                    local hrp = e.hrp
                    if hrp and hrp.Parent then
                        local g, pos = e.guid, hrp.Position
                        pcall(function() _SiegeFireDamage(g, pos) end)
                        if #HERO_GUIDS > 0 then
                            pcall(function() _SiegeFireHeroMoves(g, pos) end)
                        end
                    end
                end
            end
        end

        PG_Wait(0.08)
    end

    cleanup()
    return "loop_ended"
end

-- Main Loop
StartSiegeLoop = function()
    if SIEGE.running then StopSiege() end

    SIEGE.running      = true
    SIEGE.inMap        = false
    SIEGE.teleporting  = false
    SIEGE.killed       = 0
    _siegeSessionStart = os.time()
    for _, mn in ipairs(SIEGE_MAP_NUMS) do SIEGE.count[mn] = 0 end
    SiegeCounterUpdate()
    SiegeStatus("[.] Waiting notif SIEGE...", Color3.fromRGB(255,200,60))

    if _siegeWakeup then pcall(function() _siegeWakeup:Destroy() end) end
    _siegeWakeup = Instance.new("BindableEvent")
    pcall(function() _siegeWakeup:Fire() end)

    -- Helper: satu siklus penuh masuk-serang-keluar map untuk targetMap tertentu
    -- Mengembalikan true = berhasil selesai siklus, false = harus break loop utama
    local function _SiegeDoEntry(targetMap)
        -- [v60] Kesadaran diri: tunggu RAID/ASC keluar map dulu
        if (RAID and RAID.inMap) or (ASC and ASC.inMap) then
            local _waitWho = (RAID and RAID.inMap) and "RAID" or "ASC"
            SiegeStatus("[..] " .. _waitWho .. " masih di Map - SIEGE menunggu...", Color3.fromRGB(255,200,60))
            if SIEGE.dot then SIEGE.dot.BackgroundColor3 = Color3.fromRGB(255,200,60) end
            local _wg = 0
            while ((RAID and RAID.inMap) or (ASC and ASC.inMap)) and SIEGE.running and _wg < 600 do
                task.wait(0.5); _wg = _wg + 0.5
            end
            if not SIEGE.running then return false end
        end

        -- SIEGE sudah tunggu RAID/ASC selesai di blok atas (baris 9101-9110)
        -- Tidak perlu tunggu lagi di sini, langsung set interrupt
        _siegeInterrupt = true  -- signal MA untuk pause (MA cek di guard tiap iterasi)
        if not MODE:WaitAndRequest("siege", 15) then
            _siegeInterrupt = false
            task.wait(1)
            return true -- retry loop utama
        end

        local d = SIEGE_DATA[targetMap]
        SIEGE.teleporting = true
        SIEGE.live[d.cityRaidId] = nil

        -- PRE-ENTRY: TP ke BaseMap
        -- [PATCH v2] Deteksi via workspace.Maps folder, bukan MapId attribute
        -- Jika player sudah berada di base map siege (Map3/Map7/Map10/Map13/Map18),
        -- skip TP ke basemap — double-TP ditolak server dan menyebabkan stuck nil.
        local _BASEMAP_FOLDERS = {[3]="Map3",[7]="Map7",[10]="Map10",[13]="Map13",[18]="Map18"}
        local _baseFolder = _BASEMAP_FOLDERS[targetMap]
        local _alreadyAtBase = false
        if _baseFolder then
            local _mapsRoot = workspace:FindFirstChild("Maps")
            if _mapsRoot and _mapsRoot:FindFirstChild(_baseFolder) then
                _alreadyAtBase = true
            end
        end

        if _alreadyAtBase then
            -- Player sudah di basemap: bypass TP, langsung delay 2s lalu lanjut entry
            SiegeStatus("[>>] Sudah di "..(_baseFolder or "basemap").." - bypass TP, delay 2s...", Color3.fromRGB(120,180,255))
            if SIEGE.dot then SIEGE.dot.BackgroundColor3 = Color3.fromRGB(120,180,255) end
            task.wait(2)
        else
            -- Normal: TP ke basemap dulu
            SiegeStatus("[>>] LocalTp ke BaseMap "..d.baseMapId.."...", Color3.fromRGB(120,180,255))
            if SIEGE.dot then SIEGE.dot.BackgroundColor3 = Color3.fromRGB(120,180,255) end
            pcall(function()
                if RE.LocalTp then RE.LocalTp:FireServer({ mapId = d.baseMapId }) end
            end)
            if #HERO_GUIDS > 0 and RE.EquipHeroWithData then
                for _, hGuid in ipairs(HERO_GUIDS) do
                    pcall(function()
                        RE.EquipHeroWithData:FireServer({ heroGuid = hGuid, userId = MY_USER_ID })
                    end)
                    PG_Wait(0.05)
                end
            end
            SiegeStatus("[2s] Delay post-TP BaseMap...", Color3.fromRGB(120,180,255))
            task.wait(2)
        end

        if not SIEGE.running then
            SIEGE.teleporting = false; _siegeInterrupt = false; MODE:Release("siege"); return false
        end

        local _RE = Remotes

        -- EnterCityRaidMap
        SiegeStatus("[>>] Fire EnterCityRaidMap("..d.cityRaidId..")...", Color3.fromRGB(180,120,255))
        if SIEGE.dot then SIEGE.dot.BackgroundColor3 = Color3.fromRGB(180,120,255) end
        pcall(function()
            local re = _RE:FindFirstChild("EnterCityRaidMap")
            if re then re:FireServer(d.cityRaidId) end
        end)
        PG_Wait(0.8)

        if not SIEGE.running then
            SIEGE.teleporting = false; _siegeInterrupt = false; MODE:Release("siege"); return false
        end

        -- StartLocalPlayerTeleport
        SiegeStatus("[>>] Fire StartLocalPlayerTeleport(mapId="..d.tpMapId..")...", Color3.fromRGB(180,120,255))
        pcall(function()
            local re = _RE:FindFirstChild("StartLocalPlayerTeleport")
            if re then re:FireServer({mapId = d.tpMapId}) end
        end)
        PG_Wait(0.8)

        if not SIEGE.running then
            SIEGE.teleporting = false; _siegeInterrupt = false; MODE:Release("siege"); return false
        end

        -- LocalPlayerTeleportSuccess
        SiegeStatus("[>>] InvokeServer LocalPlayerTeleportSuccess...", Color3.fromRGB(180,120,255))
        pcall(function()
            local re = _RE:FindFirstChild("LocalPlayerTeleportSuccess")
            if re then re:InvokeServer() end
        end)
        PG_Wait(0.5)

        if not SIEGE.running then
            SIEGE.teleporting = false; _siegeInterrupt = false; MODE:Release("siege"); return false
        end

        -- Poll workspace.Maps.[mapFolder] max 15s
        SiegeStatus("[..] Poll "..d.mapFolder.." (max 15s)...", Color3.fromRGB(255,200,60))
        local mapAppeared = false
        local mapWait = 0
        while mapWait < 15 and SIEGE.running do
            if workspace:FindFirstChild(d.mapFolder) then
                mapAppeared = true; break
            end
            local mapsFolder = workspace:FindFirstChild("Maps")
            if mapsFolder and mapsFolder:FindFirstChild(d.mapFolder) then
                mapAppeared = true; break
            end
            task.wait(0.5); mapWait = mapWait + 0.5
        end

        if not SIEGE.running then
            SIEGE.teleporting = false; _siegeInterrupt = false; MODE:Release("siege"); return false
        end

        if not mapAppeared then
            SiegeStatus("[!] "..d.mapFolder.." tidak muncul - retry...", Color3.fromRGB(255,100,60))
            SIEGE.teleporting = false; _siegeInterrupt = false; MODE:Release("siege")
            task.wait(2)
            return true -- retry
        end

        SiegeStatus("[OK] "..d.mapFolder.." muncul! (+"..string.format("%.1f", mapWait).."s)", Color3.fromRGB(80,220,80))

        -- EquipHeroWithData setelah map muncul
        SiegeStatus("[>>] Fire EquipHeroWithData...", Color3.fromRGB(180,120,255))
        pcall(function()
            local re = _RE:FindFirstChild("EquipHeroWithData")
            if re then re:FireServer() end
        end)
        PG_Wait(0.5)

        if not SIEGE.running then
            SIEGE.teleporting = false; _siegeInterrupt = false; MODE:Release("siege"); return false
        end

        -- Delay render musuh
        SiegeStatus("[4s] Delay render musuh...", Color3.fromRGB(255,200,60))
        task.wait(4)

        if not SIEGE.running then
            SIEGE.teleporting = false; _siegeInterrupt = false; MODE:Release("siege"); return false
        end

        SIEGE.teleporting = false
        SIEGE.inMap = true
        SiegeStatus("[S] "..d.name.." - ATTACK!", Color3.fromRGB(80,220,80))
        if SIEGE.dot then SIEGE.dot.BackgroundColor3 = Color3.fromRGB(80,220,80) end

        local result = SiegeAttackLoop(function(msg)
            SiegeStatus("[S] "..msg, Color3.fromRGB(80,220,80))
        end, d)

        -- Exit phase
        if result == "timeout" then
            SiegeStatus("[!] Timeout 2m - Force TP basemap...", Color3.fromRGB(255,100,60))
            pcall(function()
                local reQuit = Remotes:FindFirstChild("QuitCityRaidMap")
                if reQuit then reQuit:FireServer(d.cityRaidId) end
            end)
            pcall(function()
                if RE.LocalTp then RE.LocalTp:FireServer({ mapId = d.baseMapId }) end
            end)
            task.wait(3)
        else
            SiegeStatus("[<<] QuitCityRaidMap("..d.cityRaidId..")...", Color3.fromRGB(100,200,255))
            pcall(function()
                local re = Remotes:FindFirstChild("QuitCityRaidMap")
                if re then re:FireServer(d.cityRaidId) end
            end)
            local _exitWait = 0
            while IsInSiegeMapNow() and _exitWait < 8 and SIEGE.running do
                task.wait(0.3); _exitWait = _exitWait + 0.3
            end
        end

        SIEGE.inMap       = false
        SIEGE.teleporting = false
        SIEGE._lastExitTime = os.time()
        _siegeInterrupt   = false
        pcall(function() if MODE.current == "siege" then MODE:Release("siege") end end)

        if not SIEGE.running then return false end

        SIEGE.live[d.cityRaidId] = nil
        if _siegeChatOpen then _siegeChatOpen[targetMap] = false end
        SIEGE.count[targetMap] = (SIEGE.count[targetMap] or 0) + 1
        SiegeCounterUpdate()

        if result == "success" or result == "exited" then
            SiegeStatus("[OK] "..d.name.." SUCCESS! Waiting notif berikutnya...", Color3.fromRGB(100,255,150))
            if SIEGE.dot then SIEGE.dot.BackgroundColor3 = Color3.fromRGB(255,200,60) end
        else
            SiegeStatus("[~] "..d.name.." ("..result..") - Waiting notif berikutnya...", Color3.fromRGB(255,200,60))
            if SIEGE.dot then SIEGE.dot.BackgroundColor3 = Color3.fromRGB(255,200,60) end
        end
        task.wait(1)
        return true
    end

    SIEGE.thread = task.spawn(function()
        while SIEGE.running do

            -- Cari map siege tersedia, urut mapNum terkecil dulu
            local targetMap = nil
            for _, mn in ipairs(SIEGE_MAP_NUMS) do
                if not (SIEGE.excludeMaps and SIEGE.excludeMaps[mn]) then
                    local cid = SIEGE_DATA[mn].cityRaidId
                    if SIEGE.live[cid] then targetMap = mn; break end
                end
            end

            -- Kalau tidak ada, tunggu wakeup dari scanner (max 90 detik per cycle)
            if not targetMap then
                local exNames = {}
                for _, mn in ipairs(SIEGE_MAP_NUMS) do
                    if SIEGE.excludeMaps and SIEGE.excludeMaps[mn] then
                        table.insert(exNames, "M"..mn)
                    end
                end
                local exStr = #exNames > 0 and (" | Skip: "..table.concat(exNames,",")) or ""
                SiegeStatus("[.] Waiting OpenCityRaid..."..exStr, Color3.fromRGB(255,200,60))
                if SIEGE.dot then SIEGE.dot.BackgroundColor3 = Color3.fromRGB(255,200,60) end

                local _waitConn = _siegeWakeup.Event:Connect(function() end)
                local guard = 0
                while SIEGE.running and guard < 90 do
                    for _, mn in ipairs(SIEGE_MAP_NUMS) do
                        if not (SIEGE.excludeMaps and SIEGE.excludeMaps[mn]) then
                            if SIEGE.live[SIEGE_DATA[mn].cityRaidId] then
                                targetMap = mn; break
                            end
                        end
                    end
                    if targetMap then break end
                    task.wait(0.5); guard = guard + 0.5
                end
                pcall(function() _waitConn:Disconnect() end)
                if not SIEGE.running then break end
            end

            if targetMap then
                local ok = _SiegeDoEntry(targetMap)
                if not ok then break end
            end

        end -- while SIEGE.running

        -- Cleanup akhir saat toggle OFF
        _siegeInterrupt   = false
        SIEGE.inMap       = false
        SIEGE.teleporting = false
        MODE:Release("siege")
        if MODE.current == "siege" then MODE.current = "idle" end
        SIEGE.running = false
        SiegeStatus("[.] Idle", Color3.fromRGB(100,100,100))
        if SIEGE.dot then SIEGE.dot.BackgroundColor3 = Color3.fromRGB(100,100,100) end
    end)
end


-- ============================================================================
-- PANEL: AUTO SIEGE (WindUI Section - di bawah Auto Raid Ascension)
-- ============================================================================
do

local siegeSection = AutomationTab:Section({ Title = "Auto Siege", Icon = "shield", Opened = false, Box = true })

-- Status
local siegeStatusPara = siegeSection:Paragraph({
    Title = "Status",
    Desc  = "Idle - SELECT MAP",
})
SIEGE.statusLbl = {
    Text = "Idle - SELECT MAP",
    TextColor3 = Color3.fromRGB(160,148,135),
}
local _origSiegeStatus = SiegeStatus
SiegeStatus = function(msg, color)
    pcall(function() siegeStatusPara:SetDesc(msg) end)
    SIEGE.statusLbl.Text = msg
    SIEGE.statusLbl.TextColor3 = color or Color3.fromRGB(160,148,135)
end

-- Counter ringkas
local siegeCountPara = siegeSection:Paragraph({
    Title = "Count",
    Desc  = "M3:0  M7:0  M10:0  M13:0  M18:0",
})
SIEGE.countSummaryLbl = {
    Text = "M3:0  M7:0  M10:0  M13:0  M18:0",
}
local _origSiegeCounterUpdate = SiegeCounterUpdate
SiegeCounterUpdate = function()
    local parts = {}
    for _, mn in ipairs(SIEGE_MAP_NUMS) do
        table.insert(parts, "M"..mn..":"..(SIEGE.count[mn] or 0))
    end
    local txt = table.concat(parts, "  ")
    SIEGE.countSummaryLbl.Text = txt
    pcall(function() siegeCountPara:SetDesc(txt) end)
end

-- Toggle utama
local siegeEnableToggle = siegeSection:Toggle({
    Flag     = "siegeEnable",
    Title    = "Enable Auto Siege",
    Desc     = "ON = Menunggu notif EnterCityRaid dari server",
    Default  = false,
    Callback = function(on)
        _siegeToggleState = on
        if on then StartSiegeLoop() else StopSiege() end
    end,
})
_setSiegeToggle = function(on)
    if on == _siegeToggleState then return end
    _siegeToggleState = on
    pcall(function() siegeEnableToggle:SetValue(on) end)
    if on then StartSiegeLoop() else StopSiege() end
end
-- Visual-only setter (tidak trigger logika, hanya sync UI)
_visSiege = function(on)
    pcall(function() siegeEnableToggle:SetValue(on, false) end)
end

-- Exclude Map Dropdown (multi-select style via Dropdown)
local MAP_NAMES_SIEGE = {
    [3]  = "Map 3  - Shadow Castle",
    [7]  = "Map 7  - Demon Castle Tier 2",
    [10] = "Map 10 - Plagueheart",
    [13] = "Map 13 - Lava Hell",
    [18] = "Map 18 - Golden Throne",
}
local MAP_LABEL_TO_NUM = {}
local DD_OPTIONS = {}
for _, mn in ipairs(SIEGE_MAP_NUMS) do
    local lbl = MAP_NAMES_SIEGE[mn]
    table.insert(DD_OPTIONS, lbl)
    MAP_LABEL_TO_NUM[lbl] = mn
end

local siegeExcludeDD = siegeSection:Dropdown({
    Flag     = "siegeExclude",
    Title    = "Exclude Map (Skip Siege)",
    Desc     = "Pilih map yang ingin di-SKIP (tidak dimasuki)",
    Values   = DD_OPTIONS,
    Multi    = true,
    Default  = {},
    Callback = function(selected)
        -- Reset semua ke false dulu
        for _, mn in ipairs(SIEGE_MAP_NUMS) do
            SIEGE.excludeMaps[mn] = false
        end
        -- Set yang dipilih jadi true (skip)
        if type(selected) == "table" then
            for lbl, active in pairs(selected) do
                if active then
                    local mn = MAP_LABEL_TO_NUM[lbl]
                    if mn then SIEGE.excludeMaps[mn] = true end
                end
            end
        end
    end,
})

-- Expose setter visual-only untuk restore dropdown exclude map Siege saat Load Config
-- ApplyConfig restore SIEGE.excludeMaps datanya, lalu panggil ini untuk sync tampilan DD
_visSiegeExcludeDD = function()
    if not siegeExcludeDD then return end
    pcall(function()
        -- Bangun tabel selected: { [label] = true } untuk setiap map yang di-exclude
        local sel = {}
        for _, mn in ipairs(SIEGE_MAP_NUMS) do
            if SIEGE.excludeMaps and SIEGE.excludeMaps[mn] then
                local lbl = MAP_NAMES_SIEGE[mn]
                if lbl then sel[lbl] = true end
            end
        end
        siegeExcludeDD:Set(sel)
    end)
end

end -- end do: AUTO SIEGE UI


-- ============================================================================
-- SIEGE SCANNER v102 - Hook UpdateCityRaidInfo
-- action=StartChallenge/OpenCityRaid -> SIEGE.live -> wakeup loop
-- action=CloseCityRaid/LeaveCityRaid -> hapus dari SIEGE.live
-- ============================================================================
task.spawn(function()
    task.wait(3)
    if not SIEGE then return end
    if not SIEGE.live then SIEGE.live = {} end

    local _cidToMap = {
        [1000001] = 3,
        [1000002] = 7,
        [1000003] = 10,
        [1000004] = 13,
        [1000005] = 18,
    }

    local _reCity = Remotes:FindFirstChild("UpdateCityRaidInfo")
    if not _reCity then
        task.wait(5)
        _reCity = Remotes:FindFirstChild("UpdateCityRaidInfo")
    end

    if _reCity then
        _reCity.OnClientEvent:Connect(function(data)
            if type(data) ~= "table" then return end
            local id     = data.id
            local action = data.action
            local mn     = _cidToMap[id]
            if not id or not action or not mn then return end

            if action == "StartChallenge" or action == "OpenCityRaid" then
                if not SIEGE.live[id] then
                    SIEGE.live[id] = mn
                    if _siegeWakeup then
                        pcall(function() _siegeWakeup:Fire() end)
                    end
                end
            elseif action == "CloseCityRaid" or action == "LeaveCityRaid" then
                SIEGE.live[id] = nil
                if _siegeChatOpen then _siegeChatOpen[mn] = false end
            end
        end)
    end
end)



-- ============================================================================
-- JOIN TO RAID PLAYER (JTR)
-- SCAN  = ambil semua player di server (Players:GetPlayers())
-- JOIN  = StartLocalPlayerTeleport {hostId, mapId}
--         + EquipHeroWithData + LocalPlayerTeleportSuccess
-- Port dari 1.lua baris 17800-18157 ke WindUI AutomationTab
-- ============================================================================
do

local jtrSection = AutomationTab:Section({ Title = "Join To Raid Player", Icon = "users", Opened = false, Box = true })

-- State
local JTR_players = {}     -- { {name, userId} }
local JTR_selIdx  = nil
local JTR_joining = false
local JTR_mapId   = 50101  -- default: Normal Map 1
local JTR_isAsc   = false
local JTR_mapNum  = 1

local MAP_NORMAL_BASE = 50101
local MAP_NORMAL_MAX  = 20
local MAP_ASC_BASE    = 50302
local MAP_ASC_MAX     = 18

-- Status Paragraph
local jtrStatusPara = jtrSection:Paragraph({
    Title = "Status",
    Desc  = "Tekan SCAN untuk muat daftar player.",
})

local function JTRStat(msg)
    pcall(function() jtrStatusPara:SetDesc(msg) end)
end

-- Info Paragraph
jtrSection:Paragraph({
    Title = "Cara Pakai",
    Desc  = "SCAN -> Pilih Player -> Pilih Map -> JOIN.\nSetelah keluar dari Raid, tekan SCAN ulang.",
})

-- Player List Paragraph (hasil SCAN)
local jtrListPara = jtrSection:Paragraph({
    Title = "Daftar Player",
    Desc  = "(belum di-scan)",
})

local function RenderPlayerList()
    if #JTR_players == 0 then
        pcall(function() jtrListPara:SetDesc("(tidak ada player lain di server ini)") end)
        return
    end
    local lines = {}
    for i, entry in ipairs(JTR_players) do
        local marker = (i == JTR_selIdx) and "[v] " or "[ ] "
        table.insert(lines, marker .. i .. ". " .. entry.name .. "  (UID:" .. tostring(entry.userId) .. ")")
    end
    pcall(function() jtrListPara:SetDesc(table.concat(lines, "\n")) end)
end

-- Tombol SCAN
local _jtrBusy = false

jtrSection:Button({
    Title    = "SCAN Player",
    Desc     = "Ambil daftar semua player di server ini",
    Callback = function()
        if _jtrBusy then JTRStat("[~] Sedang scanning..."); return end
        _jtrBusy = true
        JTRStat("[~] Mengambil daftar player di server...")
        JTR_selIdx = nil

        task.spawn(function()
            local found = {}
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LP then
                    table.insert(found, {name = plr.Name, userId = plr.UserId})
                end
            end
            JTR_players = found
            _jtrBusy = false

            if #found == 0 then
                JTRStat("[!] Tidak ada player lain di server ini.")
                pcall(function() jtrListPara:SetDesc("(tidak ada player lain)") end)
            else
                JTRStat("[OK] " .. #found .. " player ditemukan. Pilih nomor -> JOIN.")
                RenderPlayerList()
            end
        end)
    end,
})

-- Input: Pilih nomor player dari daftar
jtrSection:Input({
    Title       = "Pilih Player (Nomor)",
    Desc        = "Ketik nomor urut player dari daftar SCAN di atas",
    Placeholder = "Contoh: 1",
    Value       = "",
    Callback    = function(val)
        local n = tonumber(val)
        if n and n >= 1 and n <= #JTR_players then
            JTR_selIdx = math.floor(n)
            local entry = JTR_players[JTR_selIdx]
            JTRStat("[v] Dipilih: " .. entry.name .. "  (hostId=" .. entry.userId .. ")")
            RenderPlayerList()
        else
            JTR_selIdx = nil
            if #JTR_players > 0 then
                JTRStat("[!] Nomor tidak valid. Masukkan angka 1-" .. #JTR_players)
            else
                JTRStat("[!] Scan dulu sebelum memilih player.")
            end
        end
    end,
})

-- Map Target Paragraph (info mapId aktif)
local jtrMapTypePara = jtrSection:Paragraph({
    Title = "Map Target",
    Desc  = "Mode: Normal Raid | Map 1  (mapId=50101)",
})

local function UpdateJTRMapDisplay()
    if JTR_isAsc then
        JTR_mapId = MAP_ASC_BASE
        pcall(function() jtrMapTypePara:SetDesc(
            "Mode: Ascension | Tower " .. JTR_mapNum .. "  (mapId=" .. JTR_mapId .. ")"
        ) end)
    else
        JTR_mapId = MAP_NORMAL_BASE + (JTR_mapNum - 1)
        pcall(function() jtrMapTypePara:SetDesc(
            "Mode: Normal Raid | Map " .. JTR_mapNum .. "  (mapId=" .. JTR_mapId .. ")"
        ) end)
    end
end

-- Toggle: Normal / Ascension
jtrSection:Toggle({
    Title    = "Mode Ascension",
    Desc     = "OFF = Normal Raid (501xx)  |  ON = Ascension (50302)",
    Default  = false,
    Callback = function(on)
        JTR_isAsc = on
        local maxMap = on and MAP_ASC_MAX or MAP_NORMAL_MAX
        if JTR_mapNum > maxMap then JTR_mapNum = maxMap end
        UpdateJTRMapDisplay()
    end,
})

-- Input: Nomor Map atau Tower
jtrSection:Input({
    Title       = "Nomor Map / Tower",
    Desc        = "Normal: 1-20  |  Ascension: 1-18",
    Placeholder = "Contoh: 1",
    Value       = "1",
    Callback    = function(val)
        local n = tonumber(val)
        if not n then return end
        n = math.floor(n)
        local maxMap = JTR_isAsc and MAP_ASC_MAX or MAP_NORMAL_MAX
        if n < 1 then n = 1 end
        if n > maxMap then n = maxMap end
        JTR_mapNum = n
        UpdateJTRMapDisplay()
    end,
})

UpdateJTRMapDisplay()

-- Tombol JOIN
jtrSection:Button({
    Title    = "JOIN to Raid Player",
    Desc     = "Teleport masuk ke Raid player yang dipilih",
    Callback = function()
        if JTR_joining then JTRStat("[~] Sedang proses JOIN..."); return end
        if not JTR_selIdx then
            JTRStat("[!] Belum ada player yang dipilih! SCAN lalu ketik nomor.")
            return
        end
        local entry = JTR_players[JTR_selIdx]
        if not entry then
            JTRStat("[!] Data tidak valid, coba SCAN ulang.")
            return
        end

        JTR_joining = true
        local mapId   = JTR_mapId
        local mapType = JTR_isAsc and "ASC" or "NORMAL"
        JTRStat("[JOIN] -> " .. entry.name .. " | hostId=" .. entry.userId .. " | mapId=" .. mapId .. " (" .. mapType .. ")")

        task.spawn(function()
            local ok, err = pcall(function()
                local reStartTp = Remotes:FindFirstChild("StartLocalPlayerTeleport")
                local reEquip   = Remotes:FindFirstChild("EquipHeroWithData")
                local reTpSucc  = Remotes:FindFirstChild("LocalPlayerTeleportSuccess")

                if not reStartTp then error("Remote StartLocalPlayerTeleport tidak ditemukan!") end

                -- Step 1: StartLocalPlayerTeleport {hostId, mapId}
                JTRStat("[1/3] Teleport ke raid " .. entry.name .. "...")
                reStartTp:FireServer({hostId = entry.userId, mapId = mapId})
                task.wait(0.5)

                -- Step 2: EquipHeroWithData
                if reEquip then pcall(function() reEquip:FireServer() end) end
                task.wait(0.3)

                -- Step 3: LocalPlayerTeleportSuccess
                if reTpSucc then
                    pcall(function() reTpSucc:InvokeServer() end)
                end
            end)

            JTR_joining = false

            if ok then
                JTRStat("[OK] Berhasil join " .. entry.name .. "! (mapId=" .. mapId .. ")")
            else
                JTRStat("[ERR] " .. (tostring(err):sub(1, 80)))
            end
        end)
    end,
})

-- Tombol BACK TO MAP 2
-- Remote: StartLocalPlayerTeleport:FireServer({mapId=50002})
-- Identik dengan 1.lua baris 17691-17726 (JTP panel)
local _jtrBackBusy = false
jtrSection:Button({
    Title    = "BACK TO MAP 2  (Lobby)",
    Desc     = "Teleport keluar ke Map 2 Lobby (mapId=50002)",
    Callback = function()
        if _jtrBackBusy then JTRStat("[~] Sedang teleport ke Map 2..."); return end
        _jtrBackBusy = true
        JTRStat("[~] Kembali ke Map Lobby 2 (50002)...")

        task.spawn(function()
            local ok, err = pcall(function()
                local reStartTp = Remotes:FindFirstChild("StartLocalPlayerTeleport")
                if not reStartTp then error("Remote StartLocalPlayerTeleport tidak ditemukan!") end
                reStartTp:FireServer({mapId = 50002})
            end)

            _jtrBackBusy = false

            if ok then
                JTRStat("[OK] Berhasil teleport ke Map Lobby 2.")
            else
                JTRStat("[ERR] Gagal: " .. (tostring(err):sub(1, 80)))
            end
        end)
    end,
})

end -- do JTR






-- ============================================================
-- ANNIVERSARY CELEBRATION
-- Port dari 1.lua baris 18457-19090
-- Ditaruh DI BAWAH Join To Raid Player (AutomationTab:Section sendiri)
-- ============================================================

-- State
local ANNIV = {
    running     = false,
    thread      = nil,
    spinEnabled = false,
    spinThread  = nil,
}

local annivStatusPara   -- Paragraph WindUI untuk status bar
local _setAnnivRunFn    -- setter toggle Run (disimpan untuk auto-off saat gagal)
local _setAnnivSpinFn   -- setter toggle Spin Gems

-- Helper update status (tulis ke Paragraph WindUI + cetak ke output)
local function AnnivStatus(msg, _color)
    pcall(function()
        if annivStatusPara then annivStatusPara:SetDesc(msg) end
    end)
end

do
    local annivSection = AutomationTab:Section({
        Title  = "Anniversary Celebration",
        Icon   = "star",
        Opened = false,
        Box    = true,
    })

    -- ── Status bar ───────────────────────────────────────────────────
    annivStatusPara = annivSection:Paragraph({
        Title = "Status",
        Desc  = "Idle - Enable Run untuk START",
    })

    -- ── Toggle: Run ───────────────────────────────────────────────────
    annivSection:Toggle({
        Flag    = "annivRun",
        Title   = "Run",
        Desc    = "Jalankan loop Anniversary Celebration otomatis",
        Default = false,
        Callback = function(on)
            _setAnnivRunFn = function(v)
                -- WindUI tidak ekspos setter langsung; fallback via flag saja
                ANNIV.running = v
            end

            ANNIV.running = on
            if on then
                AnnivStatus("[..] Starting Anniversary Celebration...", nil)
                ANNIV.thread = task.spawn(function()
                    local RS      = game:GetService("ReplicatedStorage")
                    local Remotes = RS:WaitForChild("Remotes", 10)
                    if not Remotes then
                        AnnivStatus("[X] Remotes tidak ditemukan!", nil)
                        ANNIV.running = false
                        return
                    end

                    local RAID_ID  = 937101
                    local MAP_ID   = 50401
                    local LOBBY_ID = 50001
                    local hostId   = LP.UserId

                    -- Helper: apakah Player sudah ada di Anniversary map
                    -- Deteksi via workspace.Maps:FindFirstChild("MapAnniversary")
                    local function IsInAnnivMap()
                        local mf = workspace:FindFirstChild("Maps")
                        return mf and mf:FindFirstChild("MapAnniversary") ~= nil
                    end

                    -- Helper: apakah Player masih di lobby
                    local function IsInLobby()
                        local mf = workspace:FindFirstChild("Maps")
                        if not mf then return true end
                        return mf:FindFirstChild("MapAnniversary") == nil
                    end

                    -- Helper: get musuh anniversary (scan workspace langsung, bypass MapId guard)
                    -- IsDead inline supaya tidak bergantung pada lokal MA block
                    local function GetAnnivEnemies()
                        local list  = {}
                        local seen  = {}
                        local ENEMY_FOLDERS = { "Enemys", "EnemyCityRaid", "CityRaidEnemys", "Enemies", "Enemy" }
                        local function _add(e)
                            if not e:IsA("Model") then return end
                            local g   = e:GetAttribute("EnemyGuid") or e:GetAttribute("BossGuid") or e:GetAttribute("Guid") or e:GetAttribute("GUID")
                            local h   = e:FindFirstChild("HumanoidRootPart")
                            local hum = e:FindFirstChildOfClass("Humanoid")
                            if g and h and hum and hum.Health > 0 and not seen[g] then
                                seen[g] = true
                                list[#list + 1] = { guid = g, hrp = h, model = e }
                            end
                        end
                        for _, folderName in ipairs(ENEMY_FOLDERS) do
                            local f = workspace:FindFirstChild(folderName)
                            if f then for _, e in ipairs(f:GetChildren()) do _add(e) end end
                        end
                        -- fallback: scan workspace root
                        if #list == 0 then
                            for _, obj in ipairs(workspace:GetChildren()) do _add(obj) end
                        end
                        -- Filter: hanya yang hidup
                        local alive = {}
                        for i = 1, #list do
                            local e   = list[i]
                            local hum = e.model:FindFirstChildOfClass("Humanoid")
                            if e.model.Parent and hum and hum.Health > 0 then
                                alive[#alive + 1] = e
                            end
                        end
                        return alive
                    end

                    -- Helper: TP Player ke RaidsEnemys["4035"]
                    local function TpToAnnivEnemy()
                        local char = LP.Character
                        if not char then return false end
                        local hrp = char:FindFirstChild("HumanoidRootPart")
                        if not hrp then return false end
                        local mf = workspace:FindFirstChild("Maps")
                        if not mf then return false end
                        local mapAnniv = mf:FindFirstChild("MapAnniversary")
                        if not mapAnniv then return false end
                        local mapFolder = mapAnniv:FindFirstChild("Map")
                        if not mapFolder then return false end
                        local raidEnemyFolder = mapFolder:FindFirstChild("RaidsEnemys")
                        if not raidEnemyFolder then return false end
                        local rootPart = raidEnemyFolder:FindFirstChild("4035")
                        if not rootPart then return false end
                        hrp.CFrame = rootPart.CFrame + Vector3.new(0, 3, 0)
                        return true
                    end

                    -- Helper: exit ke lobby
                    local function ExitToLobby()
                        local quitRe = Remotes:FindFirstChild("QuitRaidsMap")
                        -- Tembak QuitRaidsMap sekali, tunggu server proses
                        if quitRe then
                            pcall(function() quitRe:FireServer({ currentSlotIndex = 2, toMapId = LOBBY_ID }) end)
                        end
                        task.wait(1.5) -- [PingGuard] beri waktu server proses quit
                        -- Cek apakah sudah di lobby; kalau belum, baru retry (maks 3x, jeda 2s)
                        local exitTry = 0
                        while not IsInLobby() and exitTry < 3 and ANNIV.running do
                            exitTry = exitTry + 1
                            AnnivStatus("[EXIT] Belum di lobby, retry " .. exitTry .. "/3...", nil)
                            if quitRe then
                                pcall(function() quitRe:FireServer({ currentSlotIndex = 2, toMapId = LOBBY_ID }) end)
                            end
                            task.wait(2) -- tunggu lebih lama antar retry
                        end
                    end

                    -- MAIN LOOP
                    local failCount = 0
                    local FAIL_LIMIT = 3

                    while ANNIV.running do

                        -- ── PHASE 1: ENTRY SEQUENCE (SimpleSpy) ─────────────────
                        -- Urutan sesuai capture SimpleSpy:
                        -- 1. CreateRaidTeam(937101)
                        -- 2. StartChallengeRaidMap:FireServer()
                        -- 3. LeaveRaidTeam:FireServer(hostId)
                        -- 4. StartLocalPlayerTeleport:FireServer({hostId,slotIndex=3,mapId=50401,raidId=937101})
                        -- 5. LocalPlayerTeleportSuccess:InvokeServer({slotIndex=3,mapId=50401})
                        -- 6. EquipHeroWithData:FireServer()

                        -- Step 1: CreateRaidTeam
                        AnnivStatus("[1/6] Creating raid team...", nil)
                        local ok1, err1 = pcall(function()
                            Remotes.CreateRaidTeam:InvokeServer(RAID_ID)
                        end)
                        if not ok1 or not ANNIV.running then
                            AnnivStatus("[X] Step 1 gagal: " .. (err1 or "?"), nil)
                            ANNIV.running = false
                            break
                        end
                        PG_Wait(0.5) -- [PingGuard] ANNIV step 1

                        -- Step 2: StartChallengeRaidMap
                        AnnivStatus("[2/6] Starting challenge raid map...", nil)
                        local ok2, err2 = pcall(function()
                            Remotes.StartChallengeRaidMap:FireServer()
                        end)
                        if not ok2 or not ANNIV.running then
                            AnnivStatus("[X] Step 2 gagal: " .. (err2 or "?"), nil)
                            ANNIV.running = false
                            break
                        end
                        PG_Wait(0.5) -- [PingGuard] ANNIV step 2

                        -- Step 3: LeaveRaidTeam (hostId player sendiri)
                        AnnivStatus("[3/6] Leaving raid team slot...", nil)
                        pcall(function()
                            Remotes.LeaveRaidTeam:FireServer(hostId)
                        end)
                        PG_Wait(0.5) -- [PingGuard] ANNIV step 3

                        -- Step 4: StartLocalPlayerTeleport (slotIndex=3)
                        AnnivStatus("[4/6] Teleporting to anniversary map...", nil)
                        local ok4, err4 = pcall(function()
                            Remotes.StartLocalPlayerTeleport:FireServer({
                                hostId    = hostId,
                                slotIndex = 3,
                                mapId     = MAP_ID,
                                raidId    = RAID_ID,
                            })
                        end)
                        if not ok4 or not ANNIV.running then
                            AnnivStatus("[X] Step 4 teleport gagal: " .. (err4 or "?"), nil)
                            ANNIV.running = false
                            break
                        end
                        PG_Wait(1) -- [PingGuard] ANNIV step 4 (TP butuh waktu lebih)

                        -- Step 5: LocalPlayerTeleportSuccess (kirim args slotIndex+mapId)
                        AnnivStatus("[5/6] Confirming teleport success...", nil)
                        local ok5, err5 = pcall(function()
                            Remotes.LocalPlayerTeleportSuccess:InvokeServer({
                                slotIndex = 3,
                                mapId     = MAP_ID,
                            })
                        end)
                        if not ok5 or not ANNIV.running then
                            AnnivStatus("[X] Step 5 TeleportSuccess gagal: " .. (err5 or "?"), nil)
                            ANNIV.running = false
                            break
                        end
                        PG_Wait(0.5) -- [PingGuard] ANNIV step 5

                        -- Step 6: EquipHeroWithData
                        AnnivStatus("[6/6] Equipping hero...", nil)
                        pcall(function() Remotes.EquipHeroWithData:FireServer() end)
                        PG_Wait(0.5) -- [PingGuard] ANNIV step 6

                        -- ── VALIDASI MASUK: cek workspace.Maps ───────────────────
                        -- Tunggu server proses TP (maks 4 detik)
                        AnnivStatus("[..] Validasi masuk map...", nil)
                        local checkT = 0
                        while checkT < 4 and not IsInAnnivMap() do
                            PG_Wait(0.5) -- [PingGuard] ANNIV masuk map validate
                            checkT = checkT + 0.5
                        end

                        if not IsInAnnivMap() then
                            -- Player masih di lobby setelah entry sequence
                            -- Kemungkinan tiket habis atau server tolak
                            failCount = failCount + 1
                            AnnivStatus(
                                "[!] Gagal masuk (" .. failCount .. "/" .. FAIL_LIMIT .. ") - mungkin tiket habis...",
                                nil
                            )
                            if failCount >= FAIL_LIMIT then
                                AnnivStatus("[X] Tiket habis / gagal masuk " .. FAIL_LIMIT .. "x! AUTO OFF.", nil)
                                ANNIV.running = false
                                break
                            end
                            -- Cooldown sebelum retry
                            task.wait(2)
                            -- Kembali ke atas while loop (coba entry lagi)
                        else
                            -- Berhasil masuk - reset fail counter
                            failCount = 0
                            AnnivStatus("[OK] Berhasil masuk Anniversary Map! Jeda 2s...", nil)
                            task.wait(2)

                            -- ── PHASE 2: TP KE MUSUH ─────────────────────────────
                            AnnivStatus("[TP] Teleport ke RaidsEnemys.4035...", nil)
                            local tpOk = false
                            for i = 1, 5 do
                                if TpToAnnivEnemy() then tpOk = true; break end
                                AnnivStatus("[TP] Tunggu RaidsEnemys.4035... (" .. i .. "/5)", nil)
                                task.wait(1)
                            end

                            if not tpOk or not ANNIV.running then
                                AnnivStatus("[X] RaidsEnemys.4035 tidak ditemukan, exit...", nil)
                                ExitToLobby()
                                task.wait(2)
                            else
                                -- ── PHASE 3: UNEQUIP + EQUIP BEST ────────────────
                                AnnivStatus("[EQUIP] UnequipAll & AutoEquipBest...", nil)
                                pcall(function() Remotes.UnequipAllHero:FireServer() end)
                                task.wait(0.4)
                                pcall(function() Remotes.AutoEquipBestHero:FireServer() end)
                                task.wait(0.6)

                                -- ── PHASE 4: ATTACK LOOP ──────────────────────────
                                -- Target: semua musuh dalam radius 50 studs dari posisi Player
                                -- setelah teleport ke RaidsEnemys.4035
                                -- Selesai jika semua musuh dalam radius sudah mati / hilang
                                AnnivStatus("[ATK] Menyerang musuh...", nil)

                                -- Tunggu musuh spawn (maks 8 detik)
                                local spawnWait = 0
                                while spawnWait < 8 and #GetAnnivEnemies() == 0 and ANNIV.running do
                                    AnnivStatus("[ATK] Tunggu musuh spawn... (" .. math.floor(8 - spawnWait) .. "s)", nil)
                                    task.wait(0.5); spawnWait = spawnWait + 0.5
                                end

                                -- Rekam posisi Player tepat setelah TP sebagai titik acuan radius
                                local ATTACK_RADIUS = 50
                                local originPos = Vector3.new(0, 0, 0)
                                local char0 = LP.Character
                                local hrp0  = char0 and char0:FindFirstChild("HumanoidRootPart")
                                if hrp0 then originPos = hrp0.Position end

                                -- Helper: filter musuh hidup dalam radius 50 studs dari originPos
                                local function GetEnemiesInRadius()
                                    local out = {}
                                    local all = GetAnnivEnemies()
                                    for i = 1, #all do
                                        local e = all[i]
                                        if e.hrp then
                                            local dist = (e.hrp.Position - originPos).Magnitude
                                            if dist <= ATTACK_RADIUS then
                                                out[#out + 1] = e
                                            end
                                        end
                                    end
                                    return out
                                end

                                local stuckTimer     = 0
                                local STUCK_LIMIT    = 15.0
                                local lastAliveCount = #GetEnemiesInRadius()

                                while ANNIV.running do
                                    local inRange = GetEnemiesInRadius()

                                    -- Kondisi selesai: tidak ada lagi musuh dalam radius
                                    if #inRange == 0 then
                                        AnnivStatus("[OK] Semua musuh dalam radius mati! Diam 1s...", nil)
                                        break
                                    end

                                    -- Serang semua musuh dalam radius
                                    -- [FLa CPU] Direct call bukan task.spawn per target
                                    for i = 1, #inRange do
                                        local e   = inRange[i]
                                        local pos = e.hrp and e.hrp.Position or Vector3.new(0, 0, 0)
                                        pcall(function() FireAllDamage(e.guid, pos) end)
                                        pcall(function() FireHeroRemotes(e.guid, pos) end)
                                    end

                                    -- Anti-stuck: progress diukur dari berkurangnya jumlah musuh dalam radius
                                    if #inRange < lastAliveCount then
                                        lastAliveCount = #inRange
                                        stuckTimer     = 0
                                    else
                                        stuckTimer = stuckTimer + 0.08
                                        if stuckTimer >= STUCK_LIMIT then
                                            AnnivStatus("[!] Stuck " .. STUCK_LIMIT .. "s, paksa keluar...", nil)
                                            break
                                        end
                                    end

                                    AnnivStatus("[ATK] Serang... (" .. #inRange .. " musuh <= " .. ATTACK_RADIUS .. "studs)", nil)
                                    PG_Wait(0.08) -- [PingGuard] Anniversary attack inner loop
                                end


                                if not ANNIV.running then break end

                                -- ── PHASE 5: DELAY 2s LALU LOOP ULANG ───────────
                                AnnivStatus("[..] Musuh mati, delay 10s lalu mulai ulang...", nil)
                                task.wait(10)
                                if ANNIV.running then
                                    AnnivStatus("[LOOP] Mulai ulang Anniversary...", nil)
                                end
                            end
                        end

                    end -- end while ANNIV.running

                    ANNIV.running = false
                    ANNIV.thread  = nil
                end) -- end task.spawn
            else
                -- Toggle OFF
                ANNIV.running = false
                if ANNIV.thread then
                    pcall(function() task.cancel(ANNIV.thread) end)
                    ANNIV.thread = nil
                end
                AnnivStatus("[.] Idle - Toggle OFF", nil)
            end
        end,
    })

    -- ── Toggle: Spin Gems ─────────────────────────────────────────────
    -- Loop InvokeServer StartAnniversarySpin arg=1
    annivSection:Toggle({
        Flag    = "annivSpinGems",
        Title   = "Spin Gems",
        Desc    = "Loop spin anniversary gem (StartAnniversarySpin:InvokeServer(1))",
        Default = false,
        Callback = function(on)
            ANNIV.spinEnabled = on
            if on then
                AnnivStatus("[..] Spin Gems loop aktif...", nil)
                ANNIV.spinThread = task.spawn(function()
                    local Remotes = game:GetService("ReplicatedStorage"):WaitForChild("Remotes", 5)
                    local spinRE  = Remotes and Remotes:WaitForChild("StartAnniversarySpin", 5)
                    if not spinRE then
                        AnnivStatus("[X] StartAnniversarySpin tidak ditemukan!", nil)
                        ANNIV.spinEnabled = false
                        return
                    end
                    while ANNIV.spinEnabled do
                        pcall(function()
                            spinRE:InvokeServer(1)
                        end)
                        AnnivStatus("[>>] Spinning Gems...", nil)
                        PG_Wait(1) -- [PingGuard] ANNIV spin loop
                    end
                    AnnivStatus("[||] Spin Gems OFF.", nil)
                end)
            else
                ANNIV.spinEnabled = false
                if ANNIV.spinThread then
                    pcall(function() task.cancel(ANNIV.spinThread) end)
                    ANNIV.spinThread = nil
                end
                AnnivStatus("[||] Spin Gems OFF.", nil)
            end
        end,
    })

    -- ── Button: Claim All Gem ─────────────────────────────────────────
    -- Fire ClaimAnniversarySpinTicket:InvokeServer(arg) untuk arg = 1,3,4,5,6,7,8
    annivSection:Button({
        Title = "Claim All Gem",
        Desc  = "Claim semua reward gem anniversary (7 slot: 1,3,4,5,6,7,8)",
        Callback = function()
            task.spawn(function()
                local RE_CLAIM   = game:GetService("ReplicatedStorage"):WaitForChild("Remotes", 5)
                if not RE_CLAIM then
                    AnnivStatus("[X] Remotes tidak ditemukan!", nil)
                    return
                end
                local spinTicket = RE_CLAIM:WaitForChild("ClaimAnniversarySpinTicket", 5)
                if not spinTicket then
                    AnnivStatus("[X] ClaimAnniversarySpinTicket tidak ditemukan!", nil)
                    return
                end
                local CLAIM_ARGS = { 1, 3, 4, 5, 6, 7, 8 }
                for i, arg in ipairs(CLAIM_ARGS) do
                    AnnivStatus("[..] Claiming Gem (" .. i .. "/" .. #CLAIM_ARGS .. ") arg=" .. arg .. "...", nil)
                    pcall(function()
                        spinTicket:InvokeServer(arg)
                    end)
                    task.wait(0.5)
                end
                AnnivStatus("[OK] ALL CLAIM DONE!", nil)
            end)
        end,
    })

end -- do Anniversary Celebration


-- ============================================================================
-- STUB SETTERS — panel belum diconvert ke 2.lua
-- Dipanggil oleh ApplyConfig saat Load Config. Tanpa definisi ini script crash
-- karena memanggil nil. Stub ini mencegah crash dan menyimpan state di variabel
-- backing sehingga logika tetap konsisten ketika panel akhirnya diconvert nanti.
-- ============================================================================

-- ── Dungeon toggle stub ───────────────────────────────────────────────────────
-- Panel Dungeon (JTR punya tombol join, bukan toggle persistent ON/OFF)
-- Belum diconvert ke 2.lua — stub simpan state saja, tidak ada visual.
if not _dungeonToggleState then _dungeonToggleState = false end
_setDungeonToggle = _setDungeonToggle or function(v)
    _dungeonToggleState = v == true
end
_visDungeon = _visDungeon or function(_v)
    -- tidak ada toggle visual di JTR panel — no-op
end

-- ── ST2 / Anniversary toggle stub ────────────────────────────────────────────
-- ST2 di 1.lua adalah panel terpisah yang belum diconvert ke 2.lua.
-- Di 2.lua ada ANNIV tapi strukturnya berbeda (tidak ada persistent toggle).
-- Stub ini simpan state ke ANNIV.running agar logika tetap tidak crash.
if not ST2 then
    ST2 = {
        running       = false,
        inMap         = false,
        enabled       = false,
        attackEnabled = false,
        waveCount     = 0,
        setAttackToggle = function(_v) end,
    }
end
_setST2Toggle = _setST2Toggle or function(v)
    ST2.enabled = v == true
    ST2.running = v == true
    if ANNIV then ANNIV.running = v == true end
end
_visST2 = _visST2 or function(_v)
    -- tidak ada toggle visual ST2 di 2.lua — no-op
end

-- ── Transparency slider stub ──────────────────────────────────────────────────
-- ThemeTab belum diimplementasi di 2.lua — stub simpan nilai saja.
if not _G then _G = {} end
_setTransSlider = _setTransSlider or function(v)
    _G.ThemeTransparency = v
end

-- ── Webhook mode dropdown stub ────────────────────────────────────────────────
-- WebhookTab di 2.lua belum punya dropdown mode (By ID / By Name).
-- Stub simpan index ke _webhookMode agar CollectConfig bisa baca kembali.
local _WH_MODE_KEYS = {"both", "name", "id"}
_webhookModeSetIdx = _webhookModeSetIdx or function(idx)
    if _WH_MODE_KEYS[idx] then
        _webhookMode = _WH_MODE_KEYS[idx]
    end
end


-- ============================================================
-- PLAYER TAB: Speed Run, No Clip, Anti Idle
-- Port dari 1.lua baris 7055-7237
-- Ditaruh di PlayerTab (tab Player)
-- ============================================================

-- ── State global ─────────────────────────────────────────────
local _walkSpeedState  = 160        -- default 1000%
local _noClipState     = false
local _antiIdleState   = false
local _noClipConn      = nil        -- RBXScriptConnection RunService.Stepped
local _antiIdleThread  = nil        -- task.spawn handle
local _antiIdleStart   = nil        -- os.time() saat aktif

-- ── Pastikan FLa_PressKey tersedia (guard — mungkin sudah ada dari MA block) ──
if not FLa_PressKey then
    local _FLa_VIM = nil
    pcall(function() _FLa_VIM = game:GetService("VirtualInputManager") end)
    local _FLa_VIM_ok = false
    if _FLa_VIM then
        local testOk = pcall(function() local _ = _FLa_VIM.SendKeyEvent; return type(_) == "function" end)
        _FLa_VIM_ok = testOk
    end
    local _FLa_keypress = nil
    if type(keypress) == "function" then
        _FLa_keypress = keypress
    elseif type(keyboard) == "table" and type(keyboard.press) == "function" then
        _FLa_keypress = function(kc) keyboard.press(kc); task.wait(0.05); keyboard.release(kc) end
    end
    local _FLa_keyrelease = nil
    if type(keyrelease) == "function" then _FLa_keyrelease = keyrelease end
    local _KC_MAP = {
        [Enum.KeyCode.Space] = 0x20,
        [Enum.KeyCode.W]     = 0x57,
        [Enum.KeyCode.A]     = 0x41,
        [Enum.KeyCode.S]     = 0x53,
        [Enum.KeyCode.D]     = 0x44,
    }
    function FLa_PressKey(keyCode)
        -- Method 1: VirtualInputManager (Delta Android, Xeno, Solara)
        if _FLa_VIM_ok and _FLa_VIM then
            local ok = pcall(function()
                _FLa_VIM:SendKeyEvent(true,  keyCode, false, game)
                task.wait(0.05)
                _FLa_VIM:SendKeyEvent(false, keyCode, false, game)
            end)
            if ok then return true end
        end
        -- Method 2: keypress/keyrelease UNC (KRNL, Xeno, Solara, Synapse)
        if _FLa_keypress then
            local kc = _KC_MAP[keyCode]
            if kc then
                local ok = pcall(function()
                    _FLa_keypress(kc)
                    if _FLa_keyrelease then task.wait(0.05); _FLa_keyrelease(kc) end
                end)
                if ok then return true end
            end
        end
        -- Method 3: UserInputService fire (mobile-friendly)
        local ok3 = pcall(function()
            local UIS = game:GetService("UserInputService")
            local io  = Instance.new("InputObject")
            io.KeyCode        = keyCode
            io.UserInputType  = Enum.UserInputType.Keyboard
            io.UserInputState = Enum.UserInputState.Begin
            UIS.InputBegan:Fire(io, false)
            task.wait(0.05)
            io.UserInputState = Enum.UserInputState.End
            UIS.InputEnded:Fire(io, false)
        end)
        if ok3 then return true end
        -- Method 4: no-op fallback — tidak crash, silent
        return false
    end
end

do
    -- ── Section: Speed Run ───────────────────────────────────────
    local speedSection = PlayerTab:Section({
        Title  = "Speed Run",
        Icon   = "zap",
        Opened = true,
        Box    = true,
    })

    -- Preset buttons (0%, 100%, 300%, 500%, 1000%)
    local presets = {
        { label = "0%",    v = 0   },
        { label = "100%",  v = 16  },
        { label = "300%",  v = 48  },
        { label = "500%",  v = 80  },
        { label = "1000%", v = 160 },
    }

    -- Paragraph untuk menampilkan speed saat ini
    local speedPara = speedSection:Paragraph({
        Title = "WalkSpeed",
        Desc  = "160 (1000%)",
    })

    local function SetSpeedValue(spd)
        spd = math.clamp(math.floor(spd), 0, 160)
        _walkSpeedState = spd
        local pct = math.floor(spd / 16 * 100)
        pcall(function() speedPara:SetDesc(spd .. " (" .. pct .. "%)") end)
        local char = LP.Character
        if char then
            local hum = char:FindFirstChild("Humanoid")
            if hum then hum.WalkSpeed = spd end
        end
    end

    -- Tombol preset
    for _, pr in ipairs(presets) do
        speedSection:Button({
            Title    = pr.label,
            Desc     = "Set WalkSpeed ke " .. pr.v .. " (" .. pr.label .. ")",
            Callback = function()
                SetSpeedValue(pr.v)
            end,
        })
    end

    -- Terapkan default speed 1000% saat karakter ready
    task.spawn(function()
        local char = LP.Character or LP.CharacterAdded:Wait()
        local hum  = char:WaitForChild("Humanoid", 5)
        if hum then hum.WalkSpeed = _walkSpeedState end
    end)
    -- Pertahankan speed saat respawn
    LP.CharacterAdded:Connect(function(char)
        local hum = char:WaitForChild("Humanoid", 5)
        if hum then hum.WalkSpeed = _walkSpeedState end
    end)

    -- ── Section: No Clip ─────────────────────────────────────────
    local noClipSection = PlayerTab:Section({
        Title  = "No Clip",
        Icon   = "ghost",
        Opened = true,
        Box    = true,
    })

    local _noClipToggleEl = noClipSection:Toggle({
        Flag     = "playerNoClip",
        Title    = "No Clip",
        Desc     = "Tembus tembok & objek apapun selama aktif",
        Default  = false,
        Callback = function(on)
            _noClipState = on
            -- Putus koneksi lama jika ada
            if _noClipConn then _noClipConn:Disconnect(); _noClipConn = nil end
            if on then
                -- [FLa CPU] Cache BasePart karakter, rebuild hanya saat karakter ganti
                local _ncCachedChar  = nil
                local _ncCachedParts = {}
                local _ncFrame       = 0
                local function _ncRebuildCache(char)
                    _ncCachedChar  = char
                    _ncCachedParts = {}
                    if not char then return end
                    for _, part in ipairs(char:GetDescendants()) do
                        if part:IsA("BasePart") then
                            table.insert(_ncCachedParts, part)
                        end
                    end
                end
                -- [FLa CPU] Throttle: jalan tiap 3 frame (~20fps), cukup untuk NoClip
                _noClipConn = RunService.Stepped:Connect(function()
                    _ncFrame = _ncFrame + 1
                    if _ncFrame % 3 ~= 0 then return end
                    local char = LP.Character; if not char then return end
                    -- Rebuild cache hanya saat karakter berubah
                    if char ~= _ncCachedChar then _ncRebuildCache(char) end
                    for _, part in ipairs(_ncCachedParts) do
                        if part and part.Parent and part.CanCollide then
                            part.CanCollide = false
                        end
                    end
                end)
            else
                -- Restore state karakter saat NoClip dimatikan
                local char = LP.Character
                if char then
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    if hrp and hum then
                        local pos = hrp.CFrame
                        hum:ChangeState(Enum.HumanoidStateType.GettingUp)
                        task.wait(0.1)
                        hrp.CFrame = pos
                    end
                end
            end
        end,
    })

    -- Expose setter NoClip ke global (dibaca Config panel saat restore)
    _setNoClipToggle = function(v)
        _noClipState = v
        if _noClipToggleEl then pcall(function() _noClipToggleEl:Set(v) end) end
    end
    _visNoClip = function(v)
        if _noClipToggleEl then pcall(function() _noClipToggleEl:Set(v, false) end) end
    end

    -- ── Section: Anti Idle ───────────────────────────────────────
    -- Logika: bukan sekedar Anti AFK (cegah kick), tapi ANTI IDLE —
    -- simulasi aktivitas nyata agar server tidak mendeteksi player diam:
    --   1. Humanoid:Move() micro-movement setiap interval acak (180-300s)
    --   2. HumanoidRootPart CFrame micro-nudge + restore (tidak visible)
    --   3. Camera CFrame micro-rotate + restore
    --   4. Remote benign (GetRaidTeamInfos / GetCityRaidInfos) setiap 60s
    --   5. FLa_PressKey(Space) simulasi input keyboard
    --   6. CharacterController: FireServer dummy movement setiap 30s via
    --      workspace.Physics / Humanoid:SetStateEnabled toggle (paksa engine
    --      kirim network update ke server — ini yang paling efektif mencegah
    --      server-side idle detection)
    local antiIdleSection = PlayerTab:Section({
        Title  = "Anti Idle",
        Icon   = "activity",
        Opened = true,
        Box    = true,
    })

    local antiIdleStatusPara = antiIdleSection:Paragraph({
        Title = "Status",
        Desc  = "Idle - Enable untuk START",
    })

    local function AntiIdleStat(msg)
        pcall(function() antiIdleStatusPara:SetDesc(msg) end)
    end

    local _antiIdleToggleEl = antiIdleSection:Toggle({
        Flag     = "playerAntiIdle",
        Title    = "Anti Idle",
        Desc     = "Simulasi aktivitas nyata agar server tidak deteksi player diam",
        Default  = false,
        Callback = function(on)
            _antiIdleState = on
            if _antiIdleThread then
                pcall(function() task.cancel(_antiIdleThread) end)
                _antiIdleThread = nil
            end
            if on then
                _antiIdleStart  = os.time()
                _antiIdleThread = task.spawn(function()
                    local _rng           = Random.new()
                    local _lastRemote    = 0   -- tick() tracker untuk remote benign
                    local _lastNetUpdate = 0   -- tick() tracker untuk force network update
                    local RS = game:GetService("ReplicatedStorage")

                    while _antiIdleState do
                        -- Interval acak 180-300 detik antar "aksi" utama
                        local interval = 180 + _rng:NextInteger(0, 120)
                        local waited   = 0
                        while waited < interval and _antiIdleState do
                            task.wait(1); waited = waited + 1
                            -- Update status timer setiap 10 detik
                            if waited % 10 == 0 then
                                local dur = os.time() - _antiIdleStart
                                AntiIdleStat(string.format(
                                    "[ON] Active %02d:%02d:%02d | next action: %ds",
                                    math.floor(dur/3600), math.floor(dur/60)%60, dur%60,
                                    interval - waited
                                ))
                            end

                            -- [ANTI IDLE 6] Force network update setiap 30 detik:
                            -- Toggle Humanoid StateEnabled sebentar — memaksa engine
                            -- mengirim network packet ke server, server tidak anggap idle
                            local now = tick()
                            if (now - _lastNetUpdate) >= 30 then
                                _lastNetUpdate = now
                                pcall(function()
                                    local char = LP.Character; if not char then return end
                                    local hum  = char:FindFirstChildOfClass("Humanoid")
                                    if not hum or hum.Health <= 0 then return end
                                    -- Toggle state briefly — tidak visible ke player, tapi server terima update
                                    hum:SetStateEnabled(Enum.HumanoidStateType.Running, false)
                                    task.wait(0.016) -- 1 frame
                                    hum:SetStateEnabled(Enum.HumanoidStateType.Running, true)
                                end)
                            end
                        end
                        if not _antiIdleState then break end

                        -- ── Aksi utama: simulasi aktivitas nyata ──────────────

                        pcall(function()
                            local char = LP.Character; if not char then return end
                            local hum  = char:FindFirstChildOfClass("Humanoid")
                            local hrp  = char:FindFirstChild("HumanoidRootPart")
                            if not hum or hum.Health <= 0 then return end

                            -- [ANTI IDLE 1] Humanoid:Move() micro-movement
                            pcall(function()
                                hum:Move(Vector3.new(0.001, 0, 0))
                                task.wait(0.05)
                                hum:Move(Vector3.new(0, 0, 0))
                            end)

                            -- [ANTI IDLE 2] HRP micro-nudge + restore (tidak terlihat)
                            pcall(function()
                                if hrp then
                                    local cf = hrp.CFrame
                                    local dx = (_rng:NextNumber() - 0.5) * 0.05
                                    local dz = (_rng:NextNumber() - 0.5) * 0.05
                                    hrp.CFrame = cf * CFrame.new(dx, 0, dz)
                                    task.wait(0.05)
                                    hrp.CFrame = cf
                                end
                            end)

                            task.wait(0.1)

                            -- [ANTI IDLE 3] Camera micro-rotate + restore
                            pcall(function()
                                local cam = workspace.CurrentCamera
                                if cam and cam.CameraType == Enum.CameraType.Custom then
                                    local cf = cam.CFrame
                                    cam.CFrame = cf * CFrame.Angles(0, 0.0001 * (_rng:NextNumber() - 0.5), 0)
                                    task.wait(0.05)
                                    cam.CFrame = cf
                                end
                            end)

                            task.wait(0.05)

                            -- [ANTI IDLE 4] Remote benign setiap 60 detik
                            pcall(function()
                                local now = tick()
                                if (now - _lastRemote) >= 60 then
                                    _lastRemote = now
                                    local Remotes = RS:FindFirstChild("Remotes")
                                    if Remotes then
                                        local safe = Remotes:FindFirstChild("GetRaidTeamInfos")
                                                  or Remotes:FindFirstChild("GetCityRaidInfos")
                                        if safe then pcall(function() safe:InvokeServer() end) end
                                    end
                                end
                            end)

                            -- [ANTI IDLE 5] Simulasi tekan Space via FLa_PressKey
                            pcall(function()
                                FLa_PressKey(Enum.KeyCode.Space)
                            end)
                        end)

                        AntiIdleStat("[ON] Aksi anti-idle dieksekusi!")
                    end -- end while

                    _antiIdleThread = nil
                    AntiIdleStat("Idle - Toggle OFF")
                end)
            else
                _antiIdleStart = nil
                AntiIdleStat("Idle - Enable untuk START")
            end
        end,
    })

    -- Expose setter Anti Idle ke global (dibaca Config panel saat restore)
    _setAntiAfkToggle = function(v)
        _antiIdleState = v
        if _antiIdleToggleEl then pcall(function() _antiIdleToggleEl:Set(v) end) end
    end
    _visAntiAfk = function(v)
        if _antiIdleToggleEl then pcall(function() _antiIdleToggleEl:Set(v, false) end) end
    end

    -- Expose setter WalkSpeed ke global (dibaca Config panel saat restore)
    _setSpeedSlider = function(v)
        pcall(function() SetSpeedValue(v) end)
    end

end -- do Player Tab



-- ============================================================================
-- HERO FASTROLL - WindUI Native API
-- Slide Up/Down: Section({ Opened=false, Box=true }) persis AutomationTab
-- GUID BUG FIX: spy intercept RandomHeroQuirk + HeroUseSkill, capture
--               arg1.heroGuid SEBELUM check _ourCall (manual reroll bukan ourCall)
-- ============================================================================

-- ── DATA: QUIRK LIST PER SLOT (persis 1.lua baris 3086-3120) ─────────────────
QUIRK_LIST_PER_SLOT = QUIRK_LIST_PER_SLOT or {
    {   -- Slot 1 (drawId=920001)
        {id=99013, name="Midas Touch"},
        {id=99014, name="Hyper Sprint"},
        {id=99015, name="Time Skipper"},
        {id=99016, name="Cosmic Luck"},
        {id=99017, name="Destiny Rewrite"},
        {id=99018, name="Final Judgment"},
        {id=99109, name="Golden Era"},
        {id=99110, name="The Chosen Singularity"},
        {id=99111, name="Axiom of Value"},
    },
    {   -- Slot 2 (drawId=920002)
        {id=99031, name="Resource Conqueror"},
        {id=99032, name="Elemental Overload"},
        {id=99033, name="Crimson Executioner"},
        {id=99034, name="God's Gift"},
        {id=99035, name="Apocalypse Carnival"},
        {id=99036, name="Divine Judgment"},
        {id=99112, name="Celestial Benediction"},
        {id=99113, name="Eclipse Masquerade"},
        {id=99114, name="Sovereign Verdict"},
    },
    {   -- Slot 3 (drawId=920003)
        {id=99049, name="Slayer's Instinct"},
        {id=99050, name="Harbinger of Ruin"},
        {id=99052, name="Godslayer's Fury"},
        {id=99053, name="Deicide's Endgame"},
        {id=99054, name="Final Arbiter"},
        {id=99115, name="Cosmic Cataclysm"},
        {id=99116, name="Omega Oblivion"},
        {id=99117, name="Sovereign Axiom"},
    },
}
MAX_PER_SLOT = math.huge

QUIRK_MAP = QUIRK_MAP or {}
for _, _ql in ipairs(QUIRK_LIST_PER_SLOT) do
    for _, _qq in ipairs(_ql) do QUIRK_MAP[_qq.id] = _qq.name end
end

-- ── GLOBALS ──────────────────────────────────────────────────────────────────
_HR_RPT            = _HR_RPT            or nil
_ourCall           = _ourCall           or false
DoAutoRollHero     = DoAutoRollHero     or nil
_setHeroRollToggle = _setHeroRollToggle or nil
_setHeroX100Toggle = _setHeroX100Toggle or nil
_layer0Active      = _layer0Active      or false
-- Weapon Fastroll globals
_WR_RPT              = _WR_RPT              or nil
DoAutoRollWeapon     = DoAutoRollWeapon     or nil
_setWeaponRollToggle = _setWeaponRollToggle or nil
_setWeaponX100Toggle = _setWeaponX100Toggle or nil

-- Pet Gear Fastroll globals
_PGR_RPT             = _PGR_RPT             or nil
DoAutoRollPetGear    = DoAutoRollPetGear    or nil
_setPetGearRollToggle= _setPetGearRollToggle or nil
_setPetGearX100Toggle= _setPetGearX100Toggle or nil
StartPG100Loop       = StartPG100Loop       or nil
StopPG100            = StopPG100            or nil

-- PG_GRADES_PER_MACHINE (persis 1.lua baris 3176-3210)
-- R-Pet (980001): 990001-990010 + 990031
-- Y-Pet (980002): 990011-990020 + 990041
-- B-Pet (980003): 990021-990030 + 990051
PG_DRAW_IDS = PG_DRAW_IDS or {980001, 980002, 980003}
PG_MACHINE_NAMES = PG_MACHINE_NAMES or {"R-Pet Gear", "Y-Pet Gear", "B-Pet Gear"}
PG_GRADES_PER_MACHINE = PG_GRADES_PER_MACHINE or {
    -- [1] R-Pet Gear (drawId 980001)
    {
        {id=990001, name="E"}, {id=990002, name="D"}, {id=990003, name="C"},
        {id=990004, name="B"}, {id=990005, name="A"}, {id=990006, name="S"},
        {id=990007, name="SS"}, {id=990008, name="G"}, {id=990009, name="N"},
        {id=990010, name="M"}, {id=990031, name="M+"},
    },
    -- [2] Y-Pet Gear (drawId 980002)
    {
        {id=990011, name="E"}, {id=990012, name="D"}, {id=990013, name="C"},
        {id=990014, name="B"}, {id=990015, name="A"}, {id=990016, name="S"},
        {id=990017, name="SS"}, {id=990018, name="G"}, {id=990019, name="N"},
        {id=990020, name="M"}, {id=990041, name="M+"},
    },
    -- [3] B-Pet Gear (drawId 980003)
    {
        {id=990021, name="E"}, {id=990022, name="D"}, {id=990023, name="C"},
        {id=990024, name="B"}, {id=990025, name="A"}, {id=990026, name="S"},
        {id=990027, name="SS"}, {id=990028, name="G"}, {id=990029, name="N"},
        {id=990030, name="M"}, {id=990051, name="M+"},
    },
}
PG_GRADE_MAP = PG_GRADE_MAP or {}
for _, _pgl in ipairs(PG_GRADES_PER_MACHINE) do
    for _, _pgg in ipairs(_pgl) do PG_GRADE_MAP[_pgg.id] = _pgg.name end
end

-- W_QUIRK_LIST_PER_SLOT (dari 1.lua baris 3131)
W_QUIRK_LIST_PER_SLOT = W_QUIRK_LIST_PER_SLOT or {
    -- Slot 1
    {
        {id=99067,name="Celestial Onslaught"},
        {id=99068,name="Lucky Scavenger"},
        {id=99069,name="Titan's Wrath"},
        {id=99070,name="Omnipotent Benefactor"},
        {id=99071,name="Archangel's Judgment"},
        {id=99072,name="Avatar of Destruction"},
        {id=99118,name="Eternal Sovereign"},
        {id=99119,name="Seraphic Verdict"},
        {id=99120,name="Doombringer Ascendant"},
    },
    -- Slot 2
    {
        {id=99085,name="Celestial Onslaught"},
        {id=99086,name="Lucky Scavenger"},
        {id=99087,name="Titan's Wrath"},
        {id=99088,name="Omnipotent Benefactor"},
        {id=99089,name="Archangel's Judgment"},
        {id=99090,name="Avatar of Destruction"},
        {id=99121,name="Eternal Sovereign"},
        {id=99122,name="Seraphic Verdict"},
        {id=99123,name="Doombringer Ascendant"},
    },
    -- Slot 3
    {
        {id=99103,name="Celestial Onslaught"},
        {id=99104,name="Lucky Scavenger"},
        {id=99105,name="Titan's Wrath"},
        {id=99106,name="Omnipotent Benefactor"},
        {id=99107,name="Archangel's Judgment"},
        {id=99108,name="Avatar of Destruction"},
        {id=99124,name="Eternal Sovereign"},
        {id=99125,name="Seraphic Verdict"},
        {id=99126,name="Doombringer Ascendant"},
    },
}
W_MAX_PER_SLOT = math.huge  -- tidak ada batasan jumlah target
W_QUIRK_MAP = W_QUIRK_MAP or {}
for _, _wl in ipairs(W_QUIRK_LIST_PER_SLOT) do
    for _, _wq in ipairs(_wl) do W_QUIRK_MAP[_wq.id] = _wq.name end
end

if not FLa_CanHook then
    FLa_CanHook = function()
        return type(getrawmetatable)    == "function"
            and type(setreadonly)       == "function"
            and type(newcclosure)       == "function"
            and type(getnamecallmethod) == "function"
    end
end

-- ============================================================================
-- PANEL: REROLL TAB → HERO FASTROLL
-- Pola persis AutomationTab: Section({ Opened=false, Box=true })
-- semua elemen pakai hrSection:Paragraph/Dropdown/Toggle
-- ============================================================================
do
    local DRAWID = {920001, 920002, 920003}

    -- Reverse map name->id per slot
    local SLOT_NAME2ID = {}
    for si = 1, 3 do
        SLOT_NAME2ID[si] = {}
        for _, q in ipairs(QUIRK_LIST_PER_SLOT[si]) do
            SLOT_NAME2ID[si][q.name] = q.id
        end
    end

    local function BuildSlotValues(si)
        local out = {}
        for _, q in ipairs(QUIRK_LIST_PER_SLOT[si]) do
            table.insert(out, q.name)
        end
        return out
    end

    -- _HR_RPT state
    _HR_RPT = {
        guid       = "",
        running    = false,
        x100       = false,
        x100Thread = nil,
        slotTarget = {{}, {}, {}},
        statusEl     = nil,
        slotEls      = {nil, nil, nil},
        ddEls        = {nil, nil, nil},
        needsRefresh = false,   -- flag untuk Heartbeat poller (avoid capability error)

        SetSlot = function(i, txt)
            if _HR_RPT.slotEls[i] then
                _HR_RPT.slotEls[i]:SetDesc(txt)
            end
        end,

        Refresh = function()
            -- CAPABILITY FIX: jangan panggil SetDesc dari __namecall/task.defer thread.
            -- Set flag saja di sini; Heartbeat poller yang panggil SetDesc dari main thread.
            if not _HR_RPT.statusEl then return end
            local desc
            if _HR_RPT.guid and _HR_RPT.guid ~= "" then
                desc = "[GUID OK] " .. tostring(_HR_RPT.guid):sub(1,13) .. "..."
            else
                desc = "[..] REROLL 1x dulu di Mesin"
            end
            -- Direct call (hanya boleh dari main-thread / Heartbeat context)
            _HR_RPT.statusEl:SetDesc(desc)
        end,

        SetToggleOff = function() end,
    }

    -- ── Section (Slide Up/Down, collapsed by default) ─────────────────────────
    local hrSection = RerollTab:Section({
        Title  = "Hero Fastroll",
        Icon   = "dices",
        Opened = false,
        Box    = true,
    })

    -- Status hero
    -- [FIX] Section:Paragraph() return 1 value langsung (object).
    -- Pola identik siegeStatusPara / annivStatusPara yang terbukti bekerja.
    _HR_RPT.statusEl = hrSection:Paragraph({ Title = "Hero", Desc = "[..] REROLL 1x dulu di Mesin" })

    -- Status slot 1-3
    for i = 1, 3 do
        _HR_RPT.slotEls[i] = hrSection:Paragraph({ Title = "Slot " .. i, Desc = "Idle" })
    end

    -- Dropdown target per slot (Multi=true)
    for si = 1, 3 do
        local si_l    = si
        local nameMap = SLOT_NAME2ID[si]
        local ddEl, _ = hrSection:Dropdown({
            Flag     = "hrSlot" .. si,
            Title    = "Target Slot " .. si,
            Desc     = "Pilih quirk target slot " .. si,
            Values   = BuildSlotValues(si),
            Value    = {},
            Multi    = true,
            Callback = function(selected)
                local tbl = {}
                if type(selected) == "table" then
                    for _, nm in ipairs(selected) do
                        local id = nameMap[nm]
                        if id then tbl[id] = true end
                    end
                end
                _HR_RPT.slotTarget[si_l] = tbl
            end,
        })
        _HR_RPT.ddEls[si] = ddEl
    end

    -- Toggle Auto Roll Hero
    local _hrToggleEl = hrSection:Toggle({
        Flag     = "hrEnable",
        Title    = "Auto Roll Hero",
        Desc     = "ON = mulai reroll otomatis per slot",
        Value    = false,
        Callback = function(on)
            _HR_RPT.running = on
            if on then
                -- [FIX BUG 3] Jika x100 lagi jalan, stop dulu tanpa panggil
                -- _setHeroX100Toggle (rekursif via Toggle:Set -> Callback)
                if _HR_RPT.x100 then
                    _HR_RPT.x100 = false
                    if _HR_RPT.x100Thread then
                        pcall(function() task.cancel(_HR_RPT.x100Thread) end)
                        _HR_RPT.x100Thread = nil
                    end
                    for i=1,3 do _HR_RPT.SetSlot(i,"Idle") end
                end
                if DoAutoRollHero then DoAutoRollHero(true) end
            else
                if DoAutoRollHero then DoAutoRollHero(false) end
            end
        end,
    })

    _setHeroRollToggle = function(on)
        if _hrToggleEl then pcall(function() _hrToggleEl:Set(on) end) end
    end

    _HR_RPT.SetToggleOff = function()
        _HR_RPT.running = false
        if _hrToggleEl then pcall(function() _hrToggleEl:Set(false) end) end
    end

    -- ── x100 Reroll ───────────────────────────────────────────────────────────
    local function ScanResForTarget(res, targets)
        if type(res) ~= "table" then return nil, nil end
        local gotId, rawId = nil, nil
        local PRIO = {"finalResultId","quirkId","resultId","id","Id","result","Result"}
        for _, key in ipairs(PRIO) do
            local v = res[key]
            if type(v)=="number" and v>0 then
                rawId = rawId or v
                if QUIRK_MAP[v] then gotId = gotId or v end
                if targets[v] then return v, v end
            end
        end
        for _, v in pairs(res) do
            if type(v)=="number" and v>0 then
                rawId = rawId or v
                if QUIRK_MAP[v] then gotId = gotId or v end
                if targets[v] then return v, v end
            elseif type(v)=="table" then
                for _, vv in pairs(v) do
                    if type(vv)=="number" and vv>0 then
                        rawId = rawId or vv
                        if QUIRK_MAP[vv] then gotId = gotId or vv end
                        if targets[vv] then return vv, vv end
                    elseif type(vv)=="table" then
                        for _, vvv in pairs(vv) do
                            if type(vvv)=="number" and vvv>0 then
                                rawId = rawId or vvv
                                if QUIRK_MAP[vvv] then gotId = gotId or vvv end
                                if targets[vvv] then return vvv, vvv end
                            end
                        end
                    end
                end
            end
        end
        return gotId, rawId
    end

    local function StopX100()
        -- [FIX BUG 3] Jangan panggil _setHeroX100Toggle di sini (rekursi):
        -- StopX100 dipanggil dari dalam Callback Toggle itu sendiri
        _HR_RPT.x100 = false
        if _HR_RPT.x100Thread then
            pcall(function() task.cancel(_HR_RPT.x100Thread) end)
            _HR_RPT.x100Thread = nil
        end
        for i=1,3 do _HR_RPT.SetSlot(i,"Idle") end
    end

    local function StartX100Loop()
        if _HR_RPT.x100Thread then
            pcall(function() task.cancel(_HR_RPT.x100Thread) end)
        end
        _HR_RPT.x100Thread = task.spawn(function()
            if not (_HR_RPT.guid and _HR_RPT.guid ~= "") then
                for i=1,3 do _HR_RPT.SetSlot(i,"[..] Klik 1x di Mesin Reroll dulu") end
                while _HR_RPT.x100 and not (_HR_RPT.guid and _HR_RPT.guid ~= "") do task.wait(0.5) end
                if not _HR_RPT.x100 then return end
                task.wait(1.5)
            end
            if not RE.AutoHeroQuirk then
                for i=1,3 do _HR_RPT.SetSlot(i,"[!] Remote AutoRandomHeroQuirk nil") end
                StopX100()
                return
            end
            local attempt  = 0
            local slotDone = {false,false,false}
            while _HR_RPT.x100 do
                local allDone = true
                for si=1,3 do
                    local stopIds={}
                    for _,q in ipairs(QUIRK_LIST_PER_SLOT[si]) do
                        if _HR_RPT.slotTarget[si][q.id] then table.insert(stopIds,q.id) end
                    end
                    if #stopIds>0 and not slotDone[si] then allDone=false; break end
                end
                if allDone then
                    -- [FIX BUG 3] Cukup StopX100() saja, tidak perlu _setHeroX100Toggle
                    -- (Toggle UI di-update lewat _HR_RPT.x100=false sudah cukup)
                    StopX100()
                    break
                end
                for si=1,3 do
                    if not slotDone[si] then
                        local targets = _HR_RPT.slotTarget[si]
                        local stopIds = {}
                        for _,q in ipairs(QUIRK_LIST_PER_SLOT[si]) do
                            if targets[q.id] then table.insert(stopIds,q.id) end
                        end
                        if #stopIds==0 then
                            _HR_RPT.SetSlot(si,"[!] SELECT TARGET!")
                        else
                            attempt = attempt+1
                            _HR_RPT.SetSlot(si,"[x100] Slot"..si.." #"..attempt.."...")
                            _ourCall = true
                            local ok,res = pcall(function()
                                return RE.AutoHeroQuirk:InvokeServer({
                                    heroGuid     = _HR_RPT.guid,
                                    drawId       = DRAWID[si],
                                    stopQuirkIds = stopIds,
                                })
                            end)
                            _ourCall = false
                            if not ok then
                                _HR_RPT.SetSlot(si,"[!] Error - retry")
                            else
                                local gotId,rawId = ScanResForTarget(res,targets)
                                if gotId and targets[gotId] then
                                    local gn = QUIRK_MAP[gotId] or "ID:"..tostring(gotId)
                                    _HR_RPT.SetSlot(si,"[DONE] "..gn.." (#"..attempt..")")
                                    slotDone[si] = true
                                else
                                    local gn=(gotId and QUIRK_MAP[gotId]) or (rawId and "ID:"..tostring(rawId)) or "?"
                                    _HR_RPT.SetSlot(si,"[x100] #"..attempt.." Last: "..gn)
                                end
                            end
                        end
                    end
                end
                task.wait(0.05)
            end
            _HR_RPT.x100Thread = nil
        end)
    end

    local _x100ToggleEl = hrSection:Toggle({
        Flag     = "hrX100",
        Title    = "x100 Reroll",
        Desc     = "ON = 1 roll = 100 hasil (AutoRandomHeroQuirk)",
        Value    = false,
        Callback = function(on)
            _HR_RPT.x100 = on
            if on then
                -- [FIX BUG 3] Jika Auto Roll Hero lagi jalan, stop dulu
                -- Tapi JANGAN panggil _setHeroRollToggle (rekursif via Toggle:Set)
                -- Cukup stop loop-nya dan update state manual
                if _HR_RPT.running then
                    _HR_RPT.running = false
                    if DoAutoRollHero then DoAutoRollHero(false) end
                end
                StartX100Loop()
            else
                StopX100()
            end
        end,
    })

    _setHeroX100Toggle = function(on)
        if _x100ToggleEl then pcall(function() _x100ToggleEl:Set(on) end) end
    end

    -- ── AUTO ROLL LOGIC ───────────────────────────────────────────────────────
    do
        local LOOPS_HR = {}

        local function StopHeroLoop(si)
            if LOOPS_HR[si] then
                pcall(function() task.cancel(LOOPS_HR[si]) end)
                LOOPS_HR[si] = nil
            end
        end

        local function StartHeroSlot(si)
            StopHeroLoop(si)
            local list    = QUIRK_LIST_PER_SLOT[si]
            local targets = _HR_RPT.slotTarget[si]
            if si==1 then _HR_RPT.Refresh() end

            LOOPS_HR[si] = task.spawn(function()
                local attempt = 0
                while true do
                    repeat
                        if not (_HR_RPT.guid and _HR_RPT.guid ~= "") then
                            _HR_RPT.SetSlot(si,"[..] Klik 1x di Mesin Reroll dulu")
                            task.wait(1); break
                        end
                        local hasTarget = false
                        for _ in pairs(targets) do hasTarget=true; break end
                        if not hasTarget then
                            _HR_RPT.SetSlot(si,"[!] SELECT TARGET!")
                            task.wait(1); break
                        end
                        if not RE.RandomHeroQuirk then
                            _HR_RPT.SetSlot(si,"[!] Remote RandomHeroQuirk nil")
                            task.wait(2); break
                        end
                        attempt = attempt+1
                        _HR_RPT.SetSlot(si,"Rolling #"..attempt.."...")

                        -- x100 path
                        if _HR_RPT.x100 then
                            if not RE.AutoHeroQuirk then
                                _HR_RPT.SetSlot(si,"[!] AutoHeroQuirk nil"); task.wait(2); break
                            end
                            local stopIds={}
                            for _,q in ipairs(list) do if targets[q.id] then table.insert(stopIds,q.id) end end
                            if #stopIds==0 then _HR_RPT.SetSlot(si,"[!] SELECT TARGET!"); task.wait(1); break end
                            _ourCall=true
                            local ok,res=pcall(function()
                                return RE.AutoHeroQuirk:InvokeServer({
                                    heroGuid=_HR_RPT.guid, drawId=DRAWID[si], stopQuirkIds=stopIds
                                })
                            end)
                            _ourCall=false
                            if not ok then _HR_RPT.SetSlot(si,"[!] x100 Error"); task.wait(1); break end
                            local gotId,_ = ScanResForTarget(res, targets)
                            if gotId and targets[gotId] then
                                _HR_RPT.SetSlot(si,"DONE: "..(QUIRK_MAP[gotId] or "?").." (#"..attempt..")")
                                StopHeroLoop(si)
                                local allDone=true
                                for i=1,3 do if LOOPS_HR[i] then allDone=false; break end end
                                if allDone then _HR_RPT.SetToggleOff() end
                                return
                            end
                            task.wait(0.05); break
                        end

                        -- Normal 1x path
                        _ourCall=true
                        local ok,res=pcall(function()
                            return RE.RandomHeroQuirk:InvokeServer({
                                heroGuid=_HR_RPT.guid, drawId=DRAWID[si],
                            })
                        end)
                        _ourCall=false
                        if not ok then task.wait(1); break end

                        local gotId,_rawId=nil,nil
                        if type(res)=="table" then
                            local PRIO={"finalResultId","quirkId","resultId","id","Id","result","Result"}
                            for _,key in ipairs(PRIO) do
                                local v=res[key]
                                if type(v)=="number" and v>0 then
                                    _rawId=_rawId or v
                                    if QUIRK_MAP[v] then gotId=v; break end
                                end
                            end
                            if not gotId then
                                for _,v in pairs(res) do
                                    if type(v)=="number" and v>0 then
                                        _rawId=_rawId or v
                                        if QUIRK_MAP[v] then gotId=v; break end
                                    end
                                end
                            end
                            if not gotId then
                                for _,v in pairs(res) do
                                    if type(v)=="table" then
                                        for _,vv in pairs(v) do
                                            if type(vv)=="number" and vv>0 then
                                                _rawId=_rawId or vv
                                                if QUIRK_MAP[vv] then gotId=vv; break end
                                            end
                                        end
                                        if gotId then break end
                                    end
                                end
                            end
                        end

                        if not gotId and _rawId and not QUIRK_MAP[_rawId] then
                            _HR_RPT.SetSlot(si,"[DBG] UnknownID:"..tostring(_rawId).." #"..attempt)
                            task.wait(0.3); break
                        end

                        if gotId and targets[gotId] then
                            _HR_RPT.SetSlot(si,"DONE: "..(QUIRK_MAP[gotId] or "?").." (#"..attempt..")")
                            StopHeroLoop(si)
                            local allDone=true
                            for i=1,3 do if LOOPS_HR[i] then allDone=false; break end end
                            if allDone then _HR_RPT.SetToggleOff() end
                            return
                        end
                        task.wait(0.05)
                    until true
                end
            end)
        end

        DoAutoRollHero = function(on)
            for i=1,3 do StopHeroLoop(i) end
            if not on then
                for i=1,3 do _HR_RPT.SetSlot(i, "Idle") end
                -- GUID tidak di-reset saat OFF: spy akan overwrite saat user reroll hero lain.
                _HR_RPT.Refresh()
                return
            end
            -- [FIX] GUID belum ada -> tampil pesan, polling sampai GUID tersedia, lalu auto-start
            if not (_HR_RPT.guid and _HR_RPT.guid ~= "") then
                for i=1,3 do _HR_RPT.SetSlot(i,"WAITING - Click 1x on Reroll Machine") end
                task.spawn(function()
                    while not (_HR_RPT.guid and _HR_RPT.guid ~= "") do task.wait(0.5) end
                    -- Jeda 1.5s agar server selesai proses manual click user
                    task.wait(1.5)
                    -- Pastikan toggle masih ON sebelum mulai
                    if _HR_RPT and _HR_RPT.running then
                        _HR_RPT.needsRefresh = true
                        for i=1,3 do StartHeroSlot(i) end
                    end
                end)
                return
            end
            for i=1,3 do StartHeroSlot(i) end
        end
    end

end -- do Hero Fastroll

-- ============================================================================
-- PANEL: REROLL TAB → WEAPON FASTROLL
-- Diconvert dari 1.lua baris 7633-7992 (UI) + 19698-19855 (logic)
-- Pakai pattern needsRefresh + Heartbeat (sama dengan Hero Fastroll)
-- ============================================================================
do
    -- ── State ────────────────────────────────────────────────────────────────
    _WR_RPT = {
        guid         = "",
        needsRefresh = false,
        statusEl     = nil,
        slotEls      = {nil, nil, nil},
        slotTarget   = {{}, {}, {}},
        running      = false,
        x100         = false,
        x100Thread   = nil,
        slotRefreshFns = {nil, nil, nil},
        SetSlot = function(i, txt)
            if _WR_RPT.slotEls[i] then
                _WR_RPT.slotEls[i]:SetDesc(txt)
            end
        end,
        Refresh = function()
            if not _WR_RPT.statusEl then return end
            local desc
            if _WR_RPT.guid and _WR_RPT.guid ~= "" then
                desc = "[GUID OK] " .. tostring(_WR_RPT.guid):sub(1,13) .. "..."
            else
                desc = "[..] REROLL 1x dulu di Mesin"
            end
            _WR_RPT.statusEl:SetDesc(desc)
        end,
        SetToggleOff = function() end,
    }

    -- ── Section ──────────────────────────────────────────────────────────────
    local wrSection = RerollTab:Section({
        Title  = "Weapon Fastroll",
        Icon   = "sword",
        Opened = false,
        Box    = true,
    })

    -- ── Status Paragraph ────────────────────────────────────────────────────
    _WR_RPT.statusEl = wrSection:Paragraph({ Title = "Weapon", Desc = "[..] REROLL 1x dulu di Mesin" })

    -- Slot status paragraphs
    for i = 1, 3 do
        _WR_RPT.slotEls[i] = wrSection:Paragraph({ Title = "Slot " .. i, Desc = "Idle" })
    end

    -- ── Target Dropdown per slot ─────────────────────────────────────────────
    for si = 1, 3 do
        local si_l = si
        local ddEl, _ = wrSection:Dropdown({
            Flag     = "wrSlot" .. si,
            Title    = "Target Slot " .. si,
            Values   = (function()
                local names = {}
                for _, q in ipairs(W_QUIRK_LIST_PER_SLOT[si_l]) do
                    table.insert(names, q.name)
                end
                return names
            end)(),
            Multi    = true,
            Value    = {},
            Callback = function(selected)
                -- selected = table of chosen names
                -- rebuild slotTarget dari selected names
                local tbl = {}
                for _, q in ipairs(W_QUIRK_LIST_PER_SLOT[si_l]) do
                    for _, selName in ipairs(selected) do
                        if selName == q.name then
                            tbl[q.id] = true
                        end
                    end
                end
                _WR_RPT.slotTarget[si_l] = tbl
            end,
        })
        -- Capture refresh fn untuk Config restore
        _WR_RPT.slotRefreshFns[si_l] = function()
            if ddEl and ddEl.Set then
                local names = {}
                for _, q in ipairs(W_QUIRK_LIST_PER_SLOT[si_l]) do
                    if _WR_RPT.slotTarget[si_l][q.id] then
                        table.insert(names, q.name)
                    end
                end
                ddEl:Set(names)
            end
        end
    end

    -- ── Toggle Auto Roll Weapon ──────────────────────────────────────────────
    local _wrToggleEl = wrSection:Toggle({
        Flag     = "wrEnable",
        Title    = "Auto Roll Weapon",
        Desc     = "ON = START REROLL",
        Value    = false,
        Callback = function(on)
            local _guard = false
            if _guard then return end
            _WR_RPT.running = on
            if on then
                -- matikan x100 jika sedang jalan
                if _WR_RPT.x100 then
                    _WR_RPT.x100 = false
                    if _WR_RPT.x100Thread then
                        pcall(function() task.cancel(_WR_RPT.x100Thread) end)
                        _WR_RPT.x100Thread = nil
                    end
                    for i=1,3 do _WR_RPT.SetSlot(i,"Idle") end
                end
                DoAutoRollWeapon(true)
            else
                DoAutoRollWeapon(false)
            end
        end,
    })

    _WR_RPT.SetToggleOff = function()
        _WR_RPT.running = false
        if _wrToggleEl then _wrToggleEl:Set(false) end
    end

    -- Expose ke global Config
    _setWeaponRollToggle = function(on)
        if on == _WR_RPT.running then return end
        _WR_RPT.running = on
        if _wrToggleEl then _wrToggleEl:Set(on) end
        if on then DoAutoRollWeapon(true) else DoAutoRollWeapon(false) end
    end

    -- ── Toggle x100 Reroll Weapon ────────────────────────────────────────────
    local _wx100ToggleEl = wrSection:Toggle({
        Flag     = "wrX100",
        Title    = "x100 Reroll",
        Desc     = "ON = 1 roll = 100 result",
        Value    = false,
        Callback = function(on)
            _WR_RPT.x100 = on
            if on then
                -- matikan Auto Roll jika sedang jalan
                if _WR_RPT.running then
                    _WR_RPT.running = false
                    -- [FIX C STACK OVERFLOW] JANGAN panggil _wrToggleEl:Set(false) di sini
                    -- (rekursif via Toggle:Set -> Callback toggle lain - pola sama dgn
                    -- "[FIX BUG 3]" di Hero Fastroll). DoAutoRollWeapon(false) sudah cukup.
                    DoAutoRollWeapon(false)
                end
                StartWRX100Loop()
            else
                StopWRX100()
            end
        end,
    })

    -- Expose ke global Config
    _setWeaponX100Toggle = function(on)
        if on == _WR_RPT.x100 then return end
        _WR_RPT.x100 = on
        if _wx100ToggleEl then _wx100ToggleEl:Set(on) end
        if on then
            if _WR_RPT.running then
                _WR_RPT.running = false
                -- [FIX C STACK OVERFLOW] sama dgn alasan di Callback di atas.
                DoAutoRollWeapon(false)
            end
            StartWRX100Loop()
        else
            StopWRX100()
        end
    end

    -- ── AUTO ROLL LOGIC - WEAPON (dari 1.lua baris 19698-19855) ─────────────
    local LOOPS_WR = {}

    local function StopWeaponLoop(si)
        if LOOPS_WR[si] then
            pcall(function() task.cancel(LOOPS_WR[si]) end)
            LOOPS_WR[si] = nil
        end
    end

    local function StartWeaponSlot(si)
        StopWeaponLoop(si)
        local list    = W_QUIRK_LIST_PER_SLOT[si]
        local targets = _WR_RPT.slotTarget[si] or {}
        local drawIds = {960001, 960002, 960003}

        -- Update status weapon saat slot 1 mulai
        if si == 1 then _WR_RPT.needsRefresh = true end

        _WR_RPT.SetSlot(si, "Memulai...")

        LOOPS_WR[si] = task.spawn(function()
            local attempt = 0
            while true do
                repeat
                    if not (_WR_RPT.guid and _WR_RPT.guid ~= "") then
                        _WR_RPT.SetSlot(si, "[..] Click 1x on Reroll Machine")
                        task.wait(1); break
                    end
                    local hasTarget = false
                    for _ in pairs(targets) do hasTarget = true; break end
                    if not hasTarget then
                        _WR_RPT.SetSlot(si, "[!] SELECT TARGET PLEASE!")
                        task.wait(1); break
                    end

                    attempt = attempt + 1
                    local names = {}
                    for _, q in ipairs(list) do
                        if targets[q.id] then table.insert(names, q.name) end
                    end
                    local tStr = table.concat(names, " / ")
                    _WR_RPT.SetSlot(si, "Rolling #"..attempt..(tStr~="" and " | "..tStr or ""))

                    _ourCall = true
                    local ok, res = pcall(function()
                        return RE.RandomWeaponQuirk:InvokeServer({
                            guid   = _WR_RPT.guid,
                            drawId = drawIds[si],
                        })
                    end)
                    _ourCall = false
                    if not ok then task.wait(0.5); break end

                    -- Scan hasil quirk (pass 1-3, dari 1.lua baris 19761-19799)
                    local gotId, _rawId = nil, nil
                    if type(res) == "table" then
                        local PRIO = {"finalResultId","quirkId","resultId","id","Id","result","Result"}
                        for _, key in ipairs(PRIO) do
                            local v = res[key]
                            if type(v)=="number" and v>0 then
                                _rawId = _rawId or v
                                if W_QUIRK_MAP[v] then gotId = v; break end
                            end
                        end
                        if not gotId then
                            for _, v in pairs(res) do
                                if type(v)=="number" and v>0 then
                                    _rawId = _rawId or v
                                    if W_QUIRK_MAP[v] then gotId = v; break end
                                end
                            end
                        end
                        if not gotId then
                            for _, v in pairs(res) do
                                if type(v)=="table" then
                                    for _, vv in pairs(v) do
                                        if type(vv)=="number" and vv>0 then
                                            _rawId = _rawId or vv
                                            if W_QUIRK_MAP[vv] then gotId = vv; break end
                                        end
                                    end
                                    if gotId then break end
                                end
                            end
                        end
                    end

                    local gotName = W_QUIRK_MAP[gotId] or (gotId and "ID:"..tostring(gotId) or "?")
                    local hit = gotId and hasTarget and targets[gotId] == true

                    if not hit and _rawId and not W_QUIRK_MAP[_rawId] then
                        _WR_RPT.SetSlot(si, "[DBG] UnknownID:"..tostring(_rawId).." #"..attempt)
                        task.wait(0.3); break
                    end

                    if hit then
                        _WR_RPT.SetSlot(si, "DONE: "..gotName.." (#"..attempt..")")
                        StopWeaponLoop(si)
                        local allDone = true
                        for i = 1, 3 do if LOOPS_WR[i] then allDone=false; break end end
                        if allDone then _WR_RPT.SetToggleOff() end
                        return
                    end

                    task.wait(0.05)
                until true
            end
        end)
    end

    DoAutoRollWeapon = function(on)
        for i = 1, 3 do StopWeaponLoop(i) end
        if not on then
            for i = 1, 3 do _WR_RPT.SetSlot(i, "Idle") end
            -- Pertahankan GUID; spy akan update sendiri saat user reroll weapon lain
            return
        end
        if not (_WR_RPT.guid and _WR_RPT.guid ~= "") then
            for i = 1, 3 do _WR_RPT.SetSlot(i, "Click 1x on Reroll Machine") end
            task.spawn(function()
                while not (_WR_RPT.guid and _WR_RPT.guid ~= "") do task.wait(0.5) end
                task.wait(1.5)
                if _WR_RPT.running then
                    _WR_RPT.needsRefresh = true
                    for i = 1, 3 do StartWeaponSlot(i) end
                end
            end)
            return
        end
        for i = 1, 3 do StartWeaponSlot(i) end
    end

    -- ── x100 Logic (dari 1.lua baris 7870-7989) ─────────────────────────────
    -- Helper scan nested 4 level untuk cari quirkId cocok target
    local function ScanWResForTarget(res, targets)
        if type(res) ~= "table" then return nil, nil end
        local gotId, rawId = nil, nil
        local PRIO = {"finalResultId","quirkId","resultId","id","Id","result","Result"}
        for _, key in ipairs(PRIO) do
            local v = res[key]
            if type(v)=="number" and v>0 then
                rawId = rawId or v
                if W_QUIRK_MAP[v] then gotId = gotId or v end
                if targets[v] then return v, v end
            end
        end
        for k, v in pairs(res) do
            if type(v)=="number" and v>0 then
                rawId = rawId or v
                if W_QUIRK_MAP[v] then gotId = gotId or v end
                if targets[v] then return v, v end
            elseif type(v)=="table" then
                for _, vv in pairs(v) do
                    if type(vv)=="number" and vv>0 then
                        rawId = rawId or vv
                        if W_QUIRK_MAP[vv] then gotId = gotId or vv end
                        if targets[vv] then return vv, vv end
                    elseif type(vv)=="table" then
                        for _, vvv in pairs(vv) do
                            if type(vvv)=="number" and vvv>0 then
                                rawId = rawId or vvv
                                if W_QUIRK_MAP[vvv] then gotId = gotId or vvv end
                                if targets[vvv] then return vvv, vvv end
                            end
                        end
                    end
                end
            end
        end
        return gotId, rawId
    end

    function StopWRX100()
        -- [FIX C STACK OVERFLOW] StopWRX100 dipanggil dari dalam Callback Toggle
        -- "x100 Reroll" itu sendiri (else branch saat on=false). :Set(false) di sini
        -- men-trigger Callback yg sama lagi -> rekursi tanpa henti sampai C stack
        -- overflow. Pola identik dgn StopX100 ("[FIX BUG 3]") di Hero Fastroll -
        -- state (_WR_RPT.x100) sudah cukup di-set manual, tidak perlu :Set() di sini.
        _WR_RPT.x100 = false
        if _WR_RPT.x100Thread then
            pcall(function() task.cancel(_WR_RPT.x100Thread) end)
            _WR_RPT.x100Thread = nil
        end
        for i = 1, 3 do _WR_RPT.SetSlot(i, "Idle") end
    end

    function StartWRX100Loop()
        if _WR_RPT.x100Thread then
            pcall(function() task.cancel(_WR_RPT.x100Thread) end)
        end
        _WR_RPT.x100Thread = task.spawn(function()
            -- Tunggu GUID
            if not (_WR_RPT.guid and _WR_RPT.guid ~= "") then
                for i=1,3 do _WR_RPT.SetSlot(i, "[..] Klik 1x di Mesin Reroll dulu") end
                while _WR_RPT.x100 and not (_WR_RPT.guid and _WR_RPT.guid ~= "") do task.wait(0.5) end
                if not _WR_RPT.x100 then return end
                task.wait(1.5)
            end
            if not RE.AutoWeaponQuirk then
                for i=1,3 do _WR_RPT.SetSlot(i, "[!] Remote AutoRandomWeaponQuirk nil") end
                StopWRX100(); return
            end
            local attempt = 0
            local slotDone = {false, false, false}

            while _WR_RPT.x100 do
                -- Cek apakah semua slot sudah DONE
                local allDone = true
                for si = 1, 3 do
                    local targets = _WR_RPT.slotTarget[si]
                    local hasStop = false
                    for _, q in ipairs(W_QUIRK_LIST_PER_SLOT[si]) do
                        if targets[q.id] then hasStop = true; break end
                    end
                    if hasStop and not slotDone[si] then allDone = false; break end
                end
                if allDone then StopWRX100(); break end

                for si = 1, 3 do
                    if not slotDone[si] then
                        local targets = _WR_RPT.slotTarget[si]
                        local drawId = ({960001,960002,960003})[si]
                        local stopIds = {}
                        for _, q in ipairs(W_QUIRK_LIST_PER_SLOT[si]) do
                            if targets[q.id] then table.insert(stopIds, q.id) end
                        end
                        if #stopIds == 0 then
                            _WR_RPT.SetSlot(si, "[!] SELECT TARGET!")
                        else
                            attempt = attempt + 1
                            _WR_RPT.SetSlot(si, "[x100] Slot"..si.." #"..attempt.."...")
                            _ourCall = true
                            local ok, res = pcall(function()
                                return RE.AutoWeaponQuirk:InvokeServer({
                                    guid         = _WR_RPT.guid,
                                    drawId       = drawId,
                                    stopQuirkIds = stopIds,
                                })
                            end)
                            _ourCall = false
                            if not ok then
                                _WR_RPT.SetSlot(si, "[!] Error - retry")
                            else
                                local gotId, rawId = ScanWResForTarget(res, targets)
                                local hit = gotId ~= nil and targets[gotId] == true
                                if hit then
                                    local gn = W_QUIRK_MAP[gotId] or "ID:"..tostring(gotId)
                                    _WR_RPT.SetSlot(si, "[DONE] "..gn.." (#"..attempt..")")
                                    slotDone[si] = true
                                else
                                    local gn = (gotId and W_QUIRK_MAP[gotId]) or (rawId and "ID:"..tostring(rawId)) or "?"
                                    _WR_RPT.SetSlot(si, "[x100] #"..attempt.." Last: "..gn)
                                end
                            end
                        end
                    end
                end
                task.wait(0.05)
            end
        end)
    end

    -- ── Heartbeat poller Weapon Fastroll ─────────────────────────────────────
    RunService.Heartbeat:Connect(function()
        if not (_WR_RPT and _WR_RPT.needsRefresh) then return end
        _WR_RPT.needsRefresh = false
        pcall(_WR_RPT.Refresh)
    end)

end -- do Weapon Fastroll

-- ============================================================================
-- PANEL: REROLL TAB → PET GEAR FASTROLL
-- Diconvert dari 1.lua baris 8002-8215 (UI) + 19858-20018 (logic 1x) +
--                  3340-3501 (logic 100x) + 20054-20070 (capture GUID)
-- BEDA dari Weapon/Hero Fastroll: Pet Gear = 3 MESIN INDEPENDEN (R/Y/B-Pet Gear),
-- masing-masing punya GUID, target grade, toggle Fastroll, dan toggle 100x SENDIRI
-- (bukan 1 toggle global untuk 3 slot seperti Weapon). Toggle OFF normal me-reset
-- GUID (wajib reroll manual 1x lagi) - 100x OFF TIDAK reset GUID. Pola asimetri ini
-- persis sama dengan 1.lua, dipertahankan sesuai sumber.
-- Pakai pattern needsRefresh + Heartbeat (sama dengan Hero/Weapon Fastroll)
-- ============================================================================
-- ── PET GEAR FASTROLL: logic functions (top-level, di luar do block) ────────
-- [DEPTH FIX] Semua fungsi logic diangkat ke top-level agar tidak menambah
-- kedalaman nesting block di dalam do..end. Fungsi UI (WindUI callback) di
-- dalam do block hanya memanggil fungsi-fungsi ini, bukan mendefinisikannya.
-- Ref: StartPetGearSlot, DoAutoRollPetGear, StartPG100Loop, dll.
_PG_LOOPS = {}  -- replaces local LOOPS_PG; must be global for top-level access

function _PG_StopLoop(si)
    if _PG_LOOPS[si] then
        pcall(function() task.cancel(_PG_LOOPS[si]) end)
        _PG_LOOPS[si] = nil
    end
end

function _PG_FindGradeId(t, d)
    if type(t) ~= "table" or d > 4 then return nil end
    for k, v in pairs(t) do
        if type(v) == "number" and v >= 990000 and v <= 999999 then
            return v
        elseif type(v) == "table" then
            local found = _PG_FindGradeId(v, d+1)
            if found then return found end
        end
    end
    return nil
end

function _PG_FindGradeId100(t, d)
    if type(t) ~= "table" or d > 4 then return nil end
    for k, v in pairs(t) do
        if type(v) == "number" and v > 0 then
            if _PGR_RPT and _PGR_RPT.targets then return nil end
        elseif type(v) == "table" then
            local found = _PG_FindGradeId100(v, d+1)
            if found then return found end
        end
    end
    return nil
end

function _PG_StartSlot(si)
    _PG_StopLoop(si)
    local drawId = PG_DRAW_IDS[si]
    if not (_PGR_RPT.guids[si] and _PGR_RPT.guids[si] ~= "") then
        _PGR_RPT.SetRoll(si, "[..] Click 1x on Reroll Machine")
        task.spawn(function()
            while _PGR_RPT.running[si] do
                if _PGR_RPT.guids[si] and _PGR_RPT.guids[si] ~= "" then
                    _PG_StartSlot(si)
                    return
                end
                task.wait(0.5)
            end
        end)
        return
    end
    local attempt = 0
    _PG_LOOPS[si] = task.spawn(function()
        while _PGR_RPT.running[si] do
            repeat
                if not (_PGR_RPT.guids[si] and _PGR_RPT.guids[si] ~= "") then
                    _PGR_RPT.SetRoll(si, "[..] Click 1x on Reroll Machine")
                    task.wait(1); break
                end
                local targets = _PGR_RPT.targets[si]
                local hasTarget = false
                for _ in pairs(targets) do hasTarget = true; break end
                if not hasTarget then
                    _PGR_RPT.SetRoll(si, "[!] SELECT TARGET PLEASE!")
                    task.wait(1); break
                end
                attempt = attempt + 1
                _PGR_RPT.SetRoll(si, "[~] Roll #" .. attempt)
                _ourCall = true
                local ok, res = pcall(function()
                    return RE.RandomPetGearGrade:InvokeServer({
                        guid   = _PGR_RPT.guids[si],
                        drawId = drawId,
                    })
                end)
                _ourCall = false
                if not ok then
                    _PGR_RPT.SetRoll(si, "[!] Error - retry...")
                    task.wait(0.5); break
                end
                local gotId = nil
                if type(res) == "table" then
                    gotId = res.gradeId or res.grade or res.id or res.resultId
                    if type(gotId) ~= "number" and type(res.data) == "table" then
                        gotId = res.data.grade or res.data.gradeId or res.data.id
                    end
                    if type(gotId) ~= "number" then
                        gotId = _PG_FindGradeId(res, 1)
                    end
                end
                local hit = gotId and hasTarget and targets[gotId] == true
                if hit then
                    _PGR_RPT.SetRoll(si, "[!] Target SUCCES! (#"..attempt..")")
                    local gradeName = PG_GRADE_MAP[gotId] or "?"
                    _PGR_RPT.SetLast(si, "Last: "..gradeName.." - TARGET!")
                    _PGR_RPT.running[si] = false
                    if _PGR_RPT.toggleEls[si] then _PGR_RPT.toggleEls[si]:Set(false) end
                    break
                else
                    _PGR_RPT.SetRoll(si, "[OK] Roll #"..attempt.." DONE")
                    local gradeName = gotId and PG_GRADE_MAP[gotId] or "?"
                    _PGR_RPT.SetLast(si, "Last: "..gradeName)
                end
                task.wait(0.05)
            until true
        end
        _PGR_RPT.SetRoll(si, "[.] Idle")
    end)
end

function DoAutoRollPetGear(si, on)
    _PG_StopLoop(si)
    _PGR_RPT.running[si] = on
    if not on then
        _PGR_RPT.guids[si] = ""
        _PGR_RPT.captured[si] = false
        _PGR_RPT.needsRefresh[si] = true
        _PGR_RPT.SetRoll(si, "[.] Idle")
        return
    end
    local hasTarget = false
    for _ in pairs(_PGR_RPT.targets[si]) do hasTarget = true; break end
    if not hasTarget then
        _PGR_RPT.SetRoll(si, "[!] SELECT TARGET PLEASE!")
    end
    _PG_StartSlot(si)
end

function _PG_SetOff100(si)
    -- [FIX C STACK OVERFLOW] _PG_SetOff100 dipanggil dari dalam Callback Toggle
    -- "100x Reroll" itu sendiri (else branch saat on=false). Memanggil :Set(false)
    -- di sini men-trigger Callback yang sama lagi secara synchronous -> Callback
    -- panggil _PG_SetOff100 lagi -> :Set(false) lagi -> rekursi tanpa henti sampai
    -- C stack overflow. Pola identik dgn yg sudah ditemukan & difix di Hero Fastroll
    -- StopX100 ("[FIX BUG 3]"). State (_PGR_RPT.x100[si]) sudah cukup di-set manual;
    -- tidak perlu :Set() di sini.
    _PGR_RPT.x100[si] = false
    if _PGR_RPT.x100Thread[si] then
        pcall(function() task.cancel(_PGR_RPT.x100Thread[si]) end)
        _PGR_RPT.x100Thread[si] = nil
    end
    _PGR_RPT.SetRoll(si, "[.] Idle")
end

function StartPG100Loop(si)
    if _PGR_RPT.x100Thread[si] then
        pcall(function() task.cancel(_PGR_RPT.x100Thread[si]) end)
    end
    _PGR_RPT.x100Thread[si] = task.spawn(function()
        local function CollectStopIds()
            local ids = {}
            for gradeId, isSelected in pairs(_PGR_RPT.targets[si]) do
                if isSelected then table.insert(ids, gradeId) end
            end
            return ids
        end
        if not (_PGR_RPT.guids[si] and _PGR_RPT.guids[si] ~= "") then
            _PGR_RPT.SetRoll(si, "[..] Click 1x on Reroll Machine")
            while _PGR_RPT.x100[si] do
                if _PGR_RPT.guids[si] and _PGR_RPT.guids[si] ~= "" then break end
                task.wait(0.5)
            end
            if not _PGR_RPT.x100[si] then return end
        end
        local stopIds = CollectStopIds()
        if #stopIds == 0 then
            _PGR_RPT.SetRoll(si, "[!] SELECT TARGET PLEASE!")
            _PG_SetOff100(si)
            return
        end
        local attempt = 0
        while _PGR_RPT.x100[si] do
            repeat
                if not (_PGR_RPT.guids[si] and _PGR_RPT.guids[si] ~= "") then
                    _PGR_RPT.SetRoll(si, "[..] Click 1x on Reroll Machine")
                    task.wait(1); break
                end
                local curStopIds = CollectStopIds()
                if #curStopIds == 0 then
                    _PGR_RPT.SetRoll(si, "[!] SELECT TARGET PLEASE!")
                    task.wait(1); break
                end
                attempt = attempt + 1
                _PGR_RPT.SetRoll(si, "[~] 100x Roll #"..attempt.."...")
                if not RE.AutoPetGearGrade then
                    _PGR_RPT.SetRoll(si, "[!] Remote Auto100x tidak ditemukan!")
                    task.wait(2); break
                end
                _ourCall = true
                local ok, res = pcall(function()
                    return RE.AutoPetGearGrade:InvokeServer({
                        drawId       = PG_DRAW_IDS[si],
                        stopGradeIds = curStopIds,
                        guid         = _PGR_RPT.guids[si],
                    })
                end)
                _ourCall = false
                if not ok then
                    _PGR_RPT.SetRoll(si, "[!] Error - retry...")
                    task.wait(0.5); break
                end
                local gotId = nil
                if type(res) == "table" then
                    gotId = res.gradeId or res.grade or res.id or res.resultId
                    if type(gotId) ~= "number" and type(res.data) == "table" then
                        gotId = res.data.grade or res.data.gradeId or res.data.id
                    end
                    if type(gotId) ~= "number" then
                        local deepHit = nil
                        local function _scan100(t, d)
                            if type(t) ~= "table" or d > 4 then return end
                            for k, v in pairs(t) do
                                if type(v) == "number" and v > 0 then
                                    if _PGR_RPT.targets[si][v] then deepHit = v; return end
                                    if PG_GRADE_MAP[v] then gotId = gotId or v end
                                elseif type(v) == "table" then
                                    _scan100(v, d+1)
                                    if deepHit then return end
                                end
                            end
                        end
                        _scan100(res, 1)
                        if deepHit then gotId = deepHit end
                    end
                end
                local hit = gotId ~= nil and _PGR_RPT.targets[si][gotId] == true
                if hit then
                    _PGR_RPT.SetRoll(si, "[DONE] Target FOUND! (100x Batch #"..attempt..")")
                    local gradeName = PG_GRADE_MAP[gotId] or "?"
                    _PGR_RPT.SetLast(si, "Last: "..gradeName.." - TARGET!")
                    _PG_SetOff100(si)
                    return
                else
                    _PGR_RPT.SetRoll(si, "[OK] 100x Batch #"..attempt.." DONE")
                    local gradeName = gotId and PG_GRADE_MAP[gotId] or "?"
                    _PGR_RPT.SetLast(si, "Last: "..gradeName)
                end
                task.wait(0.05)
            until true
        end
        _PG_SetOff100(si)
    end)
end

StopPG100 = _PG_SetOff100

-- ── PET GEAR FASTROLL: state init + UI (inside do block, thin wrapper only) ─
do
    -- ── State ────────────────────────────────────────────────────────────────
    _PGR_RPT = {
        guids         = {"", "", ""},
        captured      = {false, false, false},
        targets       = {{}, {}, {}},
        running       = {false, false, false},
        x100          = {false, false, false},
        x100Thread    = {nil, nil, nil},
        needsRefresh  = {false, false, false},
        statusEls     = {nil, nil, nil},
        rollEls       = {nil, nil, nil},
        lastEls       = {nil, nil, nil},
        toggleEls     = {nil, nil, nil},
        x100ToggleEls = {nil, nil, nil},
        ddRefreshFns  = {nil, nil, nil},
        SetRoll = function(si, txt)
            if _PGR_RPT.rollEls[si] then _PGR_RPT.rollEls[si]:SetDesc(txt) end
        end,
        SetLast = function(si, txt)
            if _PGR_RPT.lastEls[si] then _PGR_RPT.lastEls[si]:SetDesc(txt) end
        end,
        Refresh = function(si)
            if not _PGR_RPT.statusEls[si] then return end
            local desc
            if _PGR_RPT.guids[si] and _PGR_RPT.guids[si] ~= "" then
                desc = "[GUID OK] " .. tostring(_PGR_RPT.guids[si]):sub(1,13) .. "..."
            else
                desc = "[..] REROLL 1x dulu di Mesin"
            end
            _PGR_RPT.statusEls[si]:SetDesc(desc)
        end,
    }

    -- ── Section ──────────────────────────────────────────────────────────────
    local pgrSection = RerollTab:Section({
        Title  = "Pet Gear Fastroll",
        Icon   = "package",
        Opened = false,
        Box    = true,
    })

    -- ── UI per mesin (R/Y/B-Pet Gear) ────────────────────────────────────────
    for msi = 1, 3 do
        local msi_l = msi
        _PGR_RPT.statusEls[msi_l] = pgrSection:Paragraph({
            Title = PG_MACHINE_NAMES[msi_l],
            Desc  = "[..] REROLL 1x dulu di Mesin",
        })
        _PGR_RPT.rollEls[msi_l] = pgrSection:Paragraph({ Title = "Status", Desc = "Idle" })
        _PGR_RPT.lastEls[msi_l] = pgrSection:Paragraph({ Title = "Last", Desc = "-" })
        local ddEl, _ = pgrSection:Dropdown({
            Flag     = "pgrDD" .. msi,
            Title    = "Target " .. PG_MACHINE_NAMES[msi_l],
            Values   = (function()
                local names = {}
                for _, g in ipairs(PG_GRADES_PER_MACHINE[msi_l]) do
                    table.insert(names, g.name)
                end
                return names
            end)(),
            Multi    = true,
            Value    = {},
            Callback = function(selected)
                local tbl = {}
                for _, g in ipairs(PG_GRADES_PER_MACHINE[msi_l]) do
                    for _, selName in ipairs(selected) do
                        if selName == g.name then tbl[g.id] = true end
                    end
                end
                _PGR_RPT.targets[msi_l] = tbl
            end,
        })
        _PGR_RPT.ddRefreshFns[msi_l] = function()
            if ddEl and ddEl.Set then
                local names = {}
                for _, g in ipairs(PG_GRADES_PER_MACHINE[msi_l]) do
                    if _PGR_RPT.targets[msi_l][g.id] then table.insert(names, g.name) end
                end
                ddEl:Set(names)
            end
        end
        local toggleEl = pgrSection:Toggle({
            Flag     = "pgrToggle" .. msi,
            Title    = "Fastroll " .. PG_MACHINE_NAMES[msi_l],
            Desc     = "ON = START REROLL",
            Value    = false,
            Callback = function(on) DoAutoRollPetGear(msi_l, on) end,
        })
        _PGR_RPT.toggleEls[msi_l] = toggleEl
        local x100El = pgrSection:Toggle({
            Flag     = "pgrX100_" .. msi,
            Title    = "100x Reroll " .. PG_MACHINE_NAMES[msi_l],
            Desc     = "ON = 100x per invoke",
            Value    = false,
            Callback = function(on)
                _PGR_RPT.x100[msi_l] = on
                if on then
                    if _PGR_RPT.running[msi_l] then
                        _PGR_RPT.running[msi_l] = false
                        -- [FIX C STACK OVERFLOW] JANGAN panggil toggleEls[msi_l]:Set(false)
                        -- di sini (rekursif via Toggle:Set -> Callback toggle lain, lalu
                        -- balik lagi - sama dgn pola "[FIX BUG 3]" di Hero Fastroll).
                        -- State (_PGR_RPT.running) + DoAutoRollPetGear sudah cukup utk stop loop.
                        DoAutoRollPetGear(msi_l, false)
                    end
                    StartPG100Loop(msi_l)
                else
                    StopPG100(msi_l)
                end
            end,
        })
        _PGR_RPT.x100ToggleEls[msi_l] = x100El
    end

    -- ── Expose globals ────────────────────────────────────────────────────────
    _setPetGearRollToggle = function(si, on)
        if _PGR_RPT.running[si] == on then return end
        _PGR_RPT.running[si] = on
        if _PGR_RPT.toggleEls[si] then _PGR_RPT.toggleEls[si]:Set(on) end
        DoAutoRollPetGear(si, on)
    end
    _setPetGearX100Toggle = function(si, on)
        if _PGR_RPT.x100[si] == on then return end
        _PGR_RPT.x100[si] = on
        if _PGR_RPT.x100ToggleEls[si] then _PGR_RPT.x100ToggleEls[si]:Set(on) end
        if on then
            if _PGR_RPT.running[si] then
                _PGR_RPT.running[si] = false
                -- [FIX C STACK OVERFLOW] sama dgn alasan di Callback x100El di atas -
                -- jangan :Set() toggle lain dari sini.
                DoAutoRollPetGear(si, false)
            end
            StartPG100Loop(si)
        else
            StopPG100(si)
        end
    end

    -- ── Heartbeat poller (3 mesin independen) ─────────────────────────────────
    RunService.Heartbeat:Connect(function()
        for si = 1, 3 do
            if _PGR_RPT.needsRefresh[si] then
                _PGR_RPT.needsRefresh[si] = false
                pcall(_PGR_RPT.Refresh, si)
            end
        end
    end)

end -- do Pet Gear Fastroll

-- FIX BUG GUID: capture dilakukan SEBELUM check _ourCall untuk remote reroll
--               manual player. HeroUseSkill juga di-intercept untuk HERO_GUIDS.
-- Confirmed SimpleSpy: RandomHeroQuirk:InvokeServer({heroGuid=..., drawId=...})
-- ============================================================================
do
    local function IsValidGUID(s)
        return type(s)=="string" and #s>20 and s:find("-")~=nil
    end

    -- Capture heroGuid dari arg table ke _HR_RPT.guid dan HERO_GUIDS
    local function _captureHeroGuid(arg1)
        if type(arg1)~="table" then return end
        local g = arg1.heroGuid or arg1.HeroGuid or arg1.guid
        if not IsValidGUID(g) then return end
        -- Update _HR_RPT
        if _HR_RPT then
            _HR_RPT.guid = g
            -- CAPABILITY FIX: tidak panggil Refresh/SetDesc dari __namecall thread
            -- (menyebabkan 'lacking capability Plugin' error).
            -- Set flag; Heartbeat poller yang update UI dari main thread.
            _HR_RPT.needsRefresh = true
        end
        -- Update HERO_GUIDS global
        if HERO_GUIDS then
            local dup=false
            for _,ex in ipairs(HERO_GUIDS) do if ex==g then dup=true; break end end
            if not dup then table.insert(HERO_GUIDS,g) end
        end
    end

    local function SetupUniversalSpy()
        if _layer0Active then return end
        _layer0Active = true

        -- Cache remote objects saat setup
        local _rHero      = RE.RandomHeroQuirk
        local _rAuto      = RE.AutoHeroQuirk
        local _rWeapon    = RE.RandomWeaponQuirk
        local _rPetG      = RE.RandomPetGearGrade
        local _rHeroSkill = RE.HeroUseSkill  -- untuk capture GUID saat combat biasa

        -- Capture weaponGuid dari arg table ke _WR_RPT.guid
        local function _captureWeaponGuid(arg1)
            if type(arg1) ~= "table" then return end
            local g = arg1.guid or arg1.weaponGuid or arg1.id
            if not IsValidGUID(g) then return end
            if _WR_RPT then
                _WR_RPT.guid = g
                _WR_RPT.needsRefresh = true
            end
        end

        -- Capture petGearGuid dari arg table ke _PGR_RPT.guids[si] berdasarkan drawId
        -- (dari 1.lua baris 20055-20070: si ditentukan via drawId, BUKAN guid tunggal,
        --  karena Pet Gear punya 3 mesin independen dgn GUID masing-masing)
        local function _capturePetGearGuid(arg1)
            if type(arg1) ~= "table" then return end
            local g   = arg1.guid
            local dId = arg1.drawId
            if not IsValidGUID(g) then return end
            if type(dId) ~= "number" then return end
            local si = ({[980001]=1, [980002]=2, [980003]=3})[dId]
            if si and _PGR_RPT then
                _PGR_RPT.guids[si]        = g
                _PGR_RPT.captured[si]     = true
                _PGR_RPT.needsRefresh[si] = true
            end
        end

        local hookOk = false
        pcall(function()
            if not FLa_CanHook() then return end
            local mt = getrawmetatable(game)
            if not mt then return end
            local _old = mt.__namecall
            if not _old then return end

            setreadonly(mt, false)
            mt.__namecall = newcclosure(function(self, ...)
                local _m = ""
                pcall(function() _m = getnamecallmethod() end)

                -- Pass-through semua method selain FireServer/InvokeServer
                if _m ~= "FireServer" and _m ~= "InvokeServer" then
                    return _old(self, ...)
                end

                local arg1 = select(1, ...)

                -- ── HeroUseSkill: capture heroGuid ke HERO_GUIDS saat combat ──
                if self == _rHeroSkill and not _ourCall then
                    if type(arg1)=="table" and IsValidGUID(arg1.heroGuid) then
                        if HERO_GUIDS then
                            local dup=false
                            for _,g in ipairs(HERO_GUIDS) do
                                if g==arg1.heroGuid then dup=true; break end
                            end
                            if not dup then table.insert(HERO_GUIDS, arg1.heroGuid) end
                        end
                    end
                    return _old(self, ...)
                end

                -- ── Bukan remote target kita → pass through ──────────────────
                if self~=_rHero and self~=_rAuto and self~=_rWeapon and self~=_rPetG then
                    return _old(self, ...)
                end

                -- Jalankan remote DULU (tanpa pcall, jaga context namecall)
                local r1,r2,r3,r4,r5 = _old(self, ...)

                -- Capture hanya jika bukan panggilan kita sendiri
                if not _ourCall then
                    if self == _rHero or self == _rAuto then
                        pcall(_captureHeroGuid, arg1)
                    elseif self == _rWeapon then
                        pcall(_captureWeaponGuid, arg1)
                    elseif self == _rPetG then
                        pcall(_capturePetGearGuid, arg1)
                    end
                end

                return r1,r2,r3,r4,r5
            end)
            setreadonly(mt, true)
            hookOk = true
        end)

        if not hookOk then
            -- Fallback: polling PlayerManager tiap 2 detik
            task.spawn(function()
                while LP and LP.Parent do
                    task.wait(2)
                    pcall(function()
                        local _pm = require(game:GetService("ReplicatedStorage").Scripts.Client.Manager.PlayerManager)
                        if not _pm or not _pm.localPlayerData then return end
                        local heroes = _pm.localPlayerData.heros or _pm.localPlayerData.heroes
                        if heroes then
                            for guid, data in pairs(heroes) do
                                if IsValidGUID(guid) and data.isEquip then
                                    if HERO_GUIDS then
                                        local dup=false
                                        for _,ex in ipairs(HERO_GUIDS) do if ex==guid then dup=true; break end end
                                        if not dup then table.insert(HERO_GUIDS,guid) end
                                    end
                                    if _HR_RPT and (_HR_RPT.guid==nil or _HR_RPT.guid=="") then
                                        _HR_RPT.guid = guid
                                        _HR_RPT.needsRefresh = true
                                    end
                                end
                            end
                        end
                    -- Weapon GUID fallback
                        local weapons = _pm.localPlayerData.weapons
                        if weapons and _WR_RPT and (_WR_RPT.guid==nil or _WR_RPT.guid=="") then
                            for guid, data in pairs(weapons) do
                                if IsValidGUID(guid) and data.isEquip then
                                    _WR_RPT.guid = guid
                                    _WR_RPT.needsRefresh = true
                                    break
                                end
                            end
                        end
                    end)
                end
            end)
        end
    end

    InitAllCaptureLayers = function()
        SetupUniversalSpy()
    end

    task.delay(1, function()
        if InitAllCaptureLayers then InitAllCaptureLayers() end
    end)

    -- HEARTBEAT POLLER: update UI dari main-thread
    -- SetDesc tidak boleh dipanggil dari __namecall/task.defer thread karena
    -- menyebabkan 'lacking capability Plugin' error.
    -- Solusi: spy hanya set _HR_RPT.needsRefresh=true, Heartbeat yang eksekusi.
    RunService.Heartbeat:Connect(function()
        if not (_HR_RPT and _HR_RPT.needsRefresh) then return end
        _HR_RPT.needsRefresh = false
        pcall(_HR_RPT.Refresh)  -- pcall di sini AMAN: main-thread / Heartbeat context
    end)
end

-- ============================================================================
-- PANEL: REROLL TAB → AUTO GACHA HALO
-- Diconvert dari 1.lua: DoAutoRollHalo (baris 3254) + PANEL HALO (baris 8217)
-- Remote: RE.RerollHalo:InvokeServer(drawId)  (RemoteFunction)
-- 3 slot: Bronze Halo (drawId=1), Gold Halo (drawId=2), Diamond Halo (drawId=3)
-- ============================================================================
do
    -- ── Konstanta ──────────────────────────────────────────────────────────
    local HALO_NAMES   = { "Bronze Halo", "Gold Halo", "Diamond Halo" }
    local HALO_DRAW_ID = { 1, 2, 3 }

    -- ── State per slot ─────────────────────────────────────────────────────
    -- Semua state disimpan per-index (1=Bronze, 2=Gold, 3=Diamond)
    local _H = {
        running      = { false, false, false },
        attempt      = { 0, 0, 0 },
        threads      = { nil, nil, nil },
        needsRefresh = { false, false, false },
        -- UI refs (diisi saat Section dibuat)
        statusEls    = { nil, nil, nil },
        attemptEls   = { nil, nil, nil },
        toggleEls    = { nil, nil, nil }, -- ref Toggle WindUI per slot
    }

    -- ── UI Helper: Refresh satu slot (dipanggil dari Heartbeat) ────────────
    local function RefreshSlot(hi)
        if not _H.statusEls[hi] then return end
        local running = _H.running[hi]
        local att     = _H.attempt[hi]

        local statusTxt, attTxt
        if not running then
            statusTxt = "[.] Idle"
            attTxt    = "Attempt: -"
        else
            statusTxt = "[R] Rolling #" .. att .. "..."
            attTxt    = "Attempt: " .. att
        end

        pcall(function() _H.statusEls[hi]:SetDesc(statusTxt) end)
        pcall(function() _H.attemptEls[hi]:SetDesc(attTxt)   end)
    end

    -- ── Loop logic per slot (diport dari DoAutoRollHalo di 1.lua) ──────────
    local function StartHaloLoop(hi)
        -- Cancel thread lama kalau ada
        if _H.threads[hi] then
            task.cancel(_H.threads[hi])
            _H.threads[hi] = nil
        end

        if not _H.running[hi] then
            -- OFF: reset attempt display
            _H.attempt[hi]      = 0
            _H.needsRefresh[hi] = true
            return
        end

        local drawId = HALO_DRAW_ID[hi]

        _H.threads[hi] = task.spawn(function()
            while _H.running[hi] do
                _H.attempt[hi] = _H.attempt[hi] + 1
                _H.needsRefresh[hi] = true

                local ok = pcall(function()
                    -- RE.RerollHalo adalah RemoteFunction → InvokeServer(drawId)
                    if RE.RerollHalo then
                        RE.RerollHalo:InvokeServer(drawId)
                    end
                end)

                if not ok then
                    task.wait(1)
                else
                    task.wait(0.05)
                end
            end
            -- Loop selesai (di-toggle OFF dari dalam callback)
            _H.needsRefresh[hi] = true
        end)
    end

    -- ── Section ────────────────────────────────────────────────────────────
    local haloSection = RerollTab:Section({
        Title  = "Auto Gacha Halo",
        Icon   = "sparkles",
        Opened = false,
        Box    = true,
    })

    -- ── UI per slot Halo ──────────────────────────────────────────────────
    for hi = 1, 3 do
        local hi_l = hi

        -- Status paragraph (return 1 value langsung — CLAUDE.md §2 Pola Paragraph)
        _H.statusEls[hi] = haloSection:Paragraph({
            Title = HALO_NAMES[hi],
            Desc  = "[.] Idle",
        })

        -- Attempt paragraph
        _H.attemptEls[hi] = haloSection:Paragraph({
            Title = "Attempt " .. HALO_NAMES[hi],
            Desc  = "Attempt: -",
        })

        -- Toggle Enable (CLAUDE.md §5 Pola Toggle)
        _H.toggleEls[hi] = haloSection:Toggle({
            Flag     = "haloToggle" .. hi,
            Title    = "Auto Gacha " .. HALO_NAMES[hi],
            Desc     = "ON = START GACHA",
            Value    = false,
            Callback = function(on)
                _H.running[hi_l] = on
                if not on then
                    -- Stop loop
                    if _H.threads[hi_l] then
                        task.cancel(_H.threads[hi_l])
                        _H.threads[hi_l] = nil
                    end
                    _H.attempt[hi_l]      = 0
                    _H.needsRefresh[hi_l] = true
                else
                    -- Start loop
                    StartHaloLoop(hi_l)
                end
            end,
        })
    end

    -- ── Heartbeat poller (CLAUDE.md §3 — SetDesc tidak boleh dari spy/defer) ──
    -- Meski fitur ini tidak pakai spy, loop task.spawn juga butuh
    -- Heartbeat agar status update aman di main-thread context.
    RunService.Heartbeat:Connect(function()
        for hi = 1, 3 do
            if _H.needsRefresh[hi] then
                _H.needsRefresh[hi] = false
                RefreshSlot(hi)
            end
        end
    end)
end

-- ============================================================================
-- PANEL: REROLL TAB → AUTO ROLL ORNAMENT
-- Diconvert dari 1.lua: _ASH_ORN / _ASH_ORN.DoRoll (baris 3306) + PANEL (baris 8315)
-- Remote: RE.RerollOrnament:InvokeServer({machineId=..., isAuto=false})  (RemoteFunction)
-- 7 mesin: Headdress, Ornament Machine, Wealth Blessing, Shadowhunter,
--          Primordial Blessing, Monarch Power, Saiyan Blessing
-- Fitur: roll terus tanpa stop, parse ornamentId dari hasil, tampil "Last: <nama>"
-- TIDAK ada dropdown target (tidak pakai spy/GUID) — roll berjalan tanpa filter target.
-- ============================================================================
do
    -- ── Konstanta mesin (dari 1.lua baris 3308-3316) ──────────────────────
    local ORN_MACHINES = {
        { name = "Headdress",             machineId = 400001 },
        { name = "Ornament Machine",      machineId = 400002 },
        { name = "Wealth Blessing",       machineId = 400003 },
        { name = "Shadowhunter Blessing", machineId = 400004 },
        { name = "Primordial Blessing",   machineId = 400005 },
        { name = "Monarch Power",         machineId = 400006 },
        { name = "Saiyan Blessing",       machineId = 400007 },
    }
    local NM = #ORN_MACHINES  -- 7

    -- ── QUIRK_MAP: id → nama, diisi saat roll (diport dari _ASH_ORN.QUIRK_MAP) ──
    local ORN_QUIRK_MAP = {}

    local function OrnAddQuirk(id, name)
        if not id or not name then return end
        if not ORN_QUIRK_MAP[id] then
            ORN_QUIRK_MAP[id] = name
        elseif not ORN_QUIRK_MAP[id]:find("^ID:") then
            -- sudah punya nama asli, biarkan
        else
            ORN_QUIRK_MAP[id] = name
        end
    end

    -- ── State per mesin ────────────────────────────────────────────────────
    local _O = {
        running      = {},
        attempt      = {},
        threads      = {},
        needsRefresh = {},
        -- UI refs
        statusEls    = {},
        attemptEls   = {},
        lastEls      = {},
        toggleEls    = {},
    }
    for i = 1, NM do
        _O.running[i]      = false
        _O.attempt[i]      = 0
        _O.threads[i]      = nil
        _O.needsRefresh[i] = false
        _O.statusEls[i]    = nil
        _O.attemptEls[i]   = nil
        _O.lastEls[i]      = nil
        _O.toggleEls[i]    = nil
    end

    -- ── Parser ornamentId dari hasil InvokeServer (diport dari 1.lua baris 3586-3655) ──
    -- Kembalikan: gotId (number|nil), gotName (string)
    local function ParseOrnResult(res, mi)
        local gotId   = nil
        local gotName = ""
        if type(res) ~= "table" then return gotId, gotName end

        -- PRIORITY 1: res.ornamentIds = { [1]=410003, ... }
        if type(res.ornamentIds) == "table" then
            local oid = res.ornamentIds[1]
            if type(oid) == "number" and oid > 0 then
                gotId   = oid
                gotName = ORN_QUIRK_MAP[oid] or ("ID:"..tostring(oid))
                OrnAddQuirk(oid, gotName)
                return gotId, gotName
            end
        end

        -- PRIORITY 2: scan nested ornamentIds
        if not gotId then
            local function ScanOrnamentIds(tbl, depth)
                if depth > 4 or type(tbl) ~= "table" or gotId then return end
                if type(tbl.ornamentIds) == "table" then
                    local oid = tbl.ornamentIds[1]
                    if type(oid) == "number" and oid > 0 then
                        gotId   = oid
                        gotName = ORN_QUIRK_MAP[oid] or ("ID:"..tostring(oid))
                        OrnAddQuirk(oid, gotName)
                        return
                    end
                end
                for _, v in pairs(tbl) do
                    if type(v) == "table" then ScanOrnamentIds(v, depth + 1) end
                end
            end
            ScanOrnamentIds(res, 0)
        end

        -- PRIORITY 3: fallback scan quirkId / resultId / ornamentId + name
        if not gotId then
            local function ScanAndLearn(tbl, depth)
                if depth > 5 or type(tbl) ~= "table" or gotId then return end
                local id   = tbl.quirkId or tbl.finalResultId or tbl.resultId or tbl.ornamentId
                local name = tbl.quirkName or tbl.name or tbl.Name or tbl.title or tbl.displayName
                if type(id) == "number" and id > 0 then
                    if type(name) == "string" and #name > 0 and not name:find("^ID:") then
                        OrnAddQuirk(id, name)
                        if not gotId then gotId = id; gotName = name end
                    else
                        if not gotId then
                            gotId   = id
                            gotName = ORN_QUIRK_MAP[id] or ("ID:"..tostring(id))
                        end
                    end
                end
                for _, v in pairs(tbl) do
                    if type(v) == "table" then ScanAndLearn(v, depth + 1) end
                end
            end
            ScanAndLearn(res, 0)
        end

        -- PRIORITY 4: last resort — angka pertama dalam range 4xxxxx
        if not gotId then
            local function ScanNum(tbl, depth)
                if depth > 4 or gotId then return end
                for _, v in pairs(tbl) do
                    if type(v) == "number" and v >= 400000 and v < 500000 then
                        gotId   = v
                        gotName = ORN_QUIRK_MAP[v] or ("ID:"..tostring(v))
                        OrnAddQuirk(v, gotName)
                        return
                    elseif type(v) == "table" then
                        ScanNum(v, depth + 1)
                    end
                end
            end
            ScanNum(res, 0)
        end

        return gotId, gotName
    end

    -- ── UI refresh satu mesin (dipanggil dari Heartbeat saja) ─────────────
    -- Payload disimpan di _O.refreshPayload[mi] oleh loop thread
    local _refreshPayload = {}  -- [mi] = { status, attempt, last }
    for i = 1, NM do _refreshPayload[i] = nil end

    local function RefreshMachine(mi)
        local p = _refreshPayload[mi]
        if not p then return end
        _refreshPayload[mi] = nil
        if _O.statusEls[mi]  then pcall(function() _O.statusEls[mi]:SetDesc(p.status)   end) end
        if _O.attemptEls[mi] then pcall(function() _O.attemptEls[mi]:SetDesc(p.attempt) end) end
        if p.last ~= nil and _O.lastEls[mi] then
            pcall(function() _O.lastEls[mi]:SetDesc(p.last) end)
        end
    end

    local function PostRefresh(mi, status, attempt, last)
        _refreshPayload[mi] = { status = status, attempt = "Attempt: "..tostring(attempt), last = last }
        _O.needsRefresh[mi] = true
    end

    -- ── Loop logic per mesin (diport dari _ASH_ORN.DoRoll di 1.lua) ───────
    local function StartOrnLoop(mi)
        -- Cancel thread lama
        local loopKey = "ornroll" .. mi
        StopLoop(loopKey)
        if _O.threads[mi] then
            pcall(function() task.cancel(_O.threads[mi]) end)
            _O.threads[mi] = nil
        end

        if not _O.running[mi] then
            PostRefresh(mi, "[.] Idle", "-", "-")
            return
        end

        local mInfo = ORN_MACHINES[mi]

        _O.threads[mi] = task.spawn(function()
            local attempt = 0
            PostRefresh(mi, "[~] START...", 0, nil)

            while _O.running[mi] do
                repeat
                    -- Pastikan remote tersedia (lazy resolve jika nil awal)
                    if not RE.RerollOrnament then
                        RE.RerollOrnament = Remotes:FindFirstChild("RerollOrnament")
                    end
                    if not RE.RerollOrnament then
                        PostRefresh(mi, "[!] RerollOrnament NOT FOUND!", attempt, nil)
                        task.wait(2)
                        break
                    end

                    attempt = attempt + 1
                    PostRefresh(mi, "[~] Roll #" .. attempt, attempt, nil)

                    local ok, res = pcall(function()
                        return RE.RerollOrnament:InvokeServer({
                            machineId = mInfo.machineId,
                            isAuto    = false,
                        })
                    end)

                    if not ok then
                        PostRefresh(mi, "[!] Error (#" .. attempt .. ")", attempt, nil)
                        task.wait(0.5)
                        break
                    end

                    if res == false or res == nil then
                        task.wait(0.5)
                        break
                    end

                    local gotId, gotName = ParseOrnResult(res, mi)
                    local lastTxt = gotName ~= "" and ("Last: " .. gotName) or "Last: ?"
                    PostRefresh(mi, "[OK] Roll #" .. attempt .. " DONE", attempt, lastTxt)

                    task.wait(0.1)
                until true
            end

            PostRefresh(mi, "[.] STOPPED (" .. tostring(_O.attempt[mi]) .. "x roll)", _O.attempt[mi], nil)
        end)

        -- Simpan attempt ke state (untuk display saat stopped)
        task.spawn(function()
            while _O.threads[mi] do
                _O.attempt[mi] = _O.attempt[mi]  -- akan di-update via PostRefresh
                task.wait(0.5)
            end
        end)
    end

    -- ── Section ────────────────────────────────────────────────────────────
    local ornSection = RerollTab:Section({
        Title  = "Auto Roll Ornament",
        Icon   = "gem",
        Opened = false,
        Box    = true,
    })

    -- Info paragraph
    ornSection:Paragraph({
        Title = "Info",
        Desc  = "[i] Enable toggle mesin untuk start roll otomatis tanpa berhenti.",
    })

    -- ── UI per mesin (7 mesin) ─────────────────────────────────────────────
    for mi = 1, NM do
        local mi_l = mi

        -- Status paragraph
        _O.statusEls[mi] = ornSection:Paragraph({
            Title = ORN_MACHINES[mi].name,
            Desc  = "[.] Idle",
        })

        -- Attempt + Last paragraph
        _O.attemptEls[mi] = ornSection:Paragraph({
            Title = "Info " .. ORN_MACHINES[mi].name,
            Desc  = "Attempt: -  |  Last: -",
        })

        -- Toggle Fastroll per mesin
        _O.toggleEls[mi] = ornSection:Toggle({
            Flag     = "ornToggle" .. mi,
            Title    = "Fastroll " .. ORN_MACHINES[mi].name,
            Desc     = "ON = START REROLL",
            Value    = false,
            Callback = function(on)
                _O.running[mi_l] = on
                if not on then
                    -- Stop
                    if _O.threads[mi_l] then
                        pcall(function() task.cancel(_O.threads[mi_l]) end)
                        _O.threads[mi_l] = nil
                    end
                    _O.attempt[mi_l] = 0
                    PostRefresh(mi_l, "[.] Idle", "-", "-")
                else
                    -- Start
                    _O.attempt[mi_l] = 0
                    StartOrnLoop(mi_l)
                end
            end,
        })
    end

    -- ── Heartbeat poller ───────────────────────────────────────────────────
    -- SetDesc tidak boleh dari task.spawn thread (lacking capability Plugin).
    -- Loop hanya isi _refreshPayload + needsRefresh; Heartbeat yang eksekusi SetDesc.
    RunService.Heartbeat:Connect(function()
        for mi = 1, NM do
            if _O.needsRefresh[mi] then
                _O.needsRefresh[mi] = false
                RefreshMachine(mi)
            end
        end
    end)
end

-- ============================================================================
-- PANEL: SETTING TAB → GIFT CODE CLAIMER + SERVER TOOLS
-- Diconvert dari 1.lua: NewPanel("settings") (baris 19004)
-- Dependency baru yang di-declare di blok ini (belum ada di 2.lua):
--   FLa_GetRequest(), FLa_HttpGet(), GetCachedServerId()
--   RejoinServer(), ServerHop(), SmallServer()
-- ============================================================================

-- ── Helper: HTTP request function (adaptive semua executor) ─────────────────
-- Diport dari 1.lua baris 293
if not FLa_GetRequest then
    function FLa_GetRequest()
        local r = request or http_request or httprequest
        if r then return r end
        if syn    and type(syn.request)      == "function" then return syn.request      end
        if http   and type(http.request)     == "function" then return http.request     end
        if fluxus and type(fluxus.request)   == "function" then return fluxus.request   end
        if krnl   and type(krnl.request)     == "function" then return krnl.request     end
        if electron and type(electron.request) == "function" then return electron.request end
        if awp    and type(awp.request)      == "function" then return awp.request      end
        if comet  and type(comet.request)    == "function" then return comet.request    end
        if type(getgenv) == "function" then
            local ok, env = pcall(getgenv)
            if ok and env then
                r = env.request or env.http_request or env.httprequest
                if r then return r end
            end
        end
        return nil
    end
end

-- ── Helper: adaptive HTTP GET ────────────────────────────────────────────────
-- Diport dari 1.lua baris 320
if not FLa_HttpGet then
    function FLa_HttpGet(url)
        do
            local ok, result = pcall(function() return game:HttpGet(url) end)
            if ok and type(result) == "string" and #result > 0 then return result end
        end
        local reqF = FLa_GetRequest()
        if reqF then
            local ok, res = pcall(function()
                return reqF({ Url = url, Method = "GET" })
            end)
            if ok and res and type(res.Body) == "string" and #res.Body > 0 then
                return res.Body
            end
        end
        if syn and type(syn.request) == "function" then
            local ok, res = pcall(function()
                return syn.request({ Url = url, Method = "GET" })
            end)
            if ok and res and type(res.Body) == "string" then return res.Body end
        end
        return nil
    end
end

-- ── Helper: cached server ID ─────────────────────────────────────────────────
-- Diport dari 1.lua baris 432
if not GetCachedServerId then
    _CACHED_SERVER_ID = _CACHED_SERVER_ID or (function()
        -- PrivateServerId tidak bisa diakses dari client → pakai JobId saja
        local jobId = game.JobId ~= "" and game.JobId or nil
        if jobId then return jobId end
        return "N/A"
    end)()
    function GetCachedServerId()
        return _CACHED_SERVER_ID
    end
end

-- ── Server Tools functions ────────────────────────────────────────────────────
-- Diport dari 1.lua baris 3009
local _TS  = game:GetService("TeleportService")
local _HS  = game:GetService("HttpService")
local _PLR = game:GetService("Players")

local function RejoinServer()
    local lp = _PLR.LocalPlayer
    task.spawn(function()
        -- Deteksi private server: PrivateServerId terisi = private/reserved server
        -- TeleportToPlaceInstance ke private server butuh accessCode tidak bisa dari client
        local isPrivate = false
        pcall(function()
            isPrivate = game.PrivateServerId ~= nil and game.PrivateServerId ~= ""
        end)
        if isPrivate then
            warn("[REJOIN] Tidak support di Private Server. Jalankan di Public Server.")
            return
        end
        local ok = pcall(function()
            _TS:TeleportToPlaceInstance(game.PlaceId, game.JobId, lp)
        end)
        if not ok then
            pcall(function() _TS:Teleport(game.PlaceId, lp) end)
        end
    end)
end

-- Diport dari 1.lua baris 3028
local function ServerHop()
    local lp = _PLR.LocalPlayer
    task.spawn(function()
        local ok = pcall(function()
            local url = "https://games.roblox.com/v1/games/"..tostring(game.PlaceId).."/servers/Public?sortOrder=Desc&limit=100"
            local raw = FLa_HttpGet(url)
            if not raw then error("HTTP tidak supported") end
            local data = _HS:JSONDecode(raw)
            if data and data.data then
                local avail = {}
                for _, v in ipairs(data.data) do
                    if type(v) == "table" and v.id ~= game.JobId and v.playing < v.maxPlayers then
                        table.insert(avail, v.id)
                    end
                end
                if #avail > 0 then
                    _TS:TeleportToPlaceInstance(game.PlaceId, avail[math.random(1, #avail)], lp)
                    return
                end
            end
            _TS:Teleport(game.PlaceId, lp)
        end)
        if not ok then
            pcall(function() _TS:Teleport(game.PlaceId, lp) end)
        end
    end)
end

-- Diport dari 1.lua baris 3059
local function SmallServer()
    local lp = _PLR.LocalPlayer
    task.spawn(function()
        local ok = pcall(function()
            local url = "https://games.roblox.com/v1/games/"..tostring(game.PlaceId).."/servers/Public?sortOrder=Asc&limit=100"
            local raw = FLa_HttpGet(url)
            if not raw then error("HTTP tidak supported") end
            local data = _HS:JSONDecode(raw)
            if data and data.data then
                for _, v in ipairs(data.data) do
                    if type(v) == "table" and v.id ~= game.JobId and v.playing < v.maxPlayers and v.playing > 0 then
                        _TS:TeleportToPlaceInstance(game.PlaceId, v.id, lp)
                        return
                    end
                end
            end
            _TS:Teleport(game.PlaceId, lp)
        end)
        if not ok then
            pcall(function() _TS:Teleport(game.PlaceId, lp) end)
        end
    end)
end

-- ============================================================================
-- SETTING TAB UI
-- ============================================================================
do
    -- ── GIFT CODE CLAIMER ───────────────────────────────────────────────────
    -- Tidak pakai Section expand. 1 tombol, fire semua kode 1-150 sekaligus
    -- (semua pcall di-spawn paralel, tidak berurutan/sequential).
    SettingTab:Button({
        Title    = "CLAIM GIFT CODE",
        Desc     = "Claim semua kode 1–150 sekaligus",
        Callback = function()
            local gcRemote = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
                and game:GetService("ReplicatedStorage").Remotes:FindFirstChild("GiftCodeReceived")
            if not gcRemote then return end
            -- Fire semua kode 1-150 paralel sekaligus
            for i = 1, 150 do
                task.spawn(function()
                    pcall(function() gcRemote:InvokeServer(i) end)
                end)
            end
        end,
    })

    -- ── SERVER TOOLS ────────────────────────────────────────────────────────
    -- Tidak pakai Section expand. 3 tombol langsung di tab.
    SettingTab:Button({
        Title    = "REJOIN SERVER",
        Desc     = "Masuk ulang ke server ID yang sama",
        Callback = function() RejoinServer() end,
    })

    SettingTab:Button({
        Title    = "SERVER HOP",
        Desc     = "Join server lain secara random / acak",
        Callback = function() ServerHop() end,
    })

    SettingTab:Button({
        Title    = "SMALL SERVER",
        Desc     = "Join server dengan player paling sedikit (Ascending)",
        Callback = function() SmallServer() end,
    })
end

-- ============================================================================
-- WEBHOOK SYSTEM - Bersih, akurat, executor-agnostic
-- Diport dari 1.lua baris 9368-9840 (do-block webhook + raid logic)
-- Kirim notif ke Discord saat Raid Normal atau Ascension Tower OPEN
-- ============================================================================

-- ── Global state declarations ──────────────────────────────────────────────
_webhookEnabled  = _webhookEnabled  or false
_webhookUrl      = _webhookUrl      or ""
_webhookUrlBox   = _webhookUrlBox   or nil   -- TextBox reference untuk restore text
_visWebhookToggle = _visWebhookToggle or nil  -- setter visual-only toggle (fn(bool))
_setWebhookToggle = _setWebhookToggle or nil  -- setter logic toggle (fn(bool))
UpdatePlatformLbl = UpdatePlatformLbl or nil  -- fn() update label platform
FlushWebhookPending = FlushWebhookPending or nil -- fn() flush buffer webhook

do -- WEBHOOK SYSTEM wrapped do-block (free top-level locals)

-- Helper: dapatkan request function (support semua executor)
local function _getReqFunc()
    return FLa_GetRequest() -- [FLa COMPAT] adaptive semua executor
end

-- Helper: dapatkan string jam realtime (WIB UTC+7)
local function _getTimestamp()
    -- os.time() = Unix timestamp UTC
    -- Tambah 7 jam (25200 detik) untuk WIB
    local t = os.time() + 25200
    return os.date("!%d/%m/%Y %H:%M:%S WIB", t)
end

-- Helper: kirim HTTP POST ke Discord
-- return: true (sukses), false (gagal), string (error message)
local function _doSend(url, text)
    local reqFunc = _getReqFunc()
    if not reqFunc then
        pcall(function() warn("[ASH Webhook] ERROR: Executor tidak support HTTP request!") end)
        return false, "Executor tidak support HTTP"
    end
    local HS = game:GetService("HttpService")
    local ok, res, errMsg = false, nil, nil
    local callOk, callErr = pcall(function()
        res = reqFunc({
            Url     = url,
            Method  = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body    = HS:JSONEncode({ content = text }),
        })
    end)
    if not callOk then
        errMsg = "HTTP error: "..(tostring(callErr):sub(1,60))
        pcall(function() warn("[ASH Webhook] "..errMsg) end)
        return false, errMsg
    end
    if res and type(res) == "table" then
        local sc = res.StatusCode or res.status or 0
        ok = (sc >= 200 and sc < 300)
        if not ok then
            errMsg = "HTTP "..sc..(res.Body and (" - "..tostring(res.Body):sub(1,40)) or "")
            pcall(function() warn("[ASH Webhook] Gagal: "..errMsg) end)
        end
    elseif res ~= nil then
        ok = true
    else
        errMsg = "Tidak ada response dari server"
        ok = false
    end
    return ok, errMsg
end

-- Buffer teks mentah dari TipsPanel, diisi ParseChatLine
local _whBuffer      = {}   -- list of raw lines dari event ini
local _whBufferTimer = nil  -- debounce handle
local _whLastSent    = 0

-- [BUG FIX 4 v2] Cache teks webhook dengan TTL timestamp.
-- Anti-spam: cegah teks sama dikirim dalam 1 window event (5 menit).
local _WH_SENT_TTL  = 300 -- 5 menit
local _whSentCache  = {} -- [text] = timestamp
local function _whResetSentCache()
    _whSentCache = {}
end
local function _whPruneSentCache()
    local now = tick()
    for k, t in pairs(_whSentCache) do
        if (now - t) >= _WH_SENT_TTL then
            _whSentCache[k] = nil
        end
    end
end
-- Auto-reset setiap 5 menit
task.spawn(function()
    while task.wait(_WH_SENT_TTL) do
        _whResetSentCache()
    end
end)

local GRADE_COLOR = {
    ["E"]=9868950,  ["D"]=6604900,  ["C"]=5294200,  ["B"]=6589695,
    ["A"]=11822335, ["S"]=16757810, ["SS"]=16768000, ["G"]=16742440,
    ["N"]=16732240, ["M"]=16727160, ["M+"]=14428340, ["M++"]=13115135,
    ["XM"]=16732360,["ULT"]=16766720,["GOD"]=16777215,
}
local GRADE_RANK_W = {
    ["E"]=1,["D"]=2,["C"]=3,["B"]=4,["A"]=5,["S"]=6,["SS"]=7,
    ["G"]=8,["N"]=9,["M"]=10,["M+"]=11,["M++"]=12,["XM"]=15,["ULT"]=17,["GOD"]=18,
}

-- Ambil grade dari bracket TERAKHIR dalam teks
local function _extractGradeLast(t)
    for _, pat in ipairs({"M%+%+","M%+","SS","XM","ULT","GOD","M"}) do
        if t:find("%["..pat.."]", 1, false) then
            local last = nil
            for m in t:gmatch("%["..pat.."]") do last = m end
            if last then return last:match("%[(.+)%]"):upper() end
        end
    end
    local last = nil
    for bracket in t:gmatch("%[([^%]]+)%]") do
        local up = bracket:upper()
        if up:match("^[EDCBAGSN]$") then last = up end
    end
    return last
end

-- Kirim buffer ke Discord, lalu kosongkan buffer
local _whFlushBuffer
_whFlushBuffer = function(url)
    if #_whBuffer == 0 then return end
    local lines  = _whBuffer
    _whBuffer    = {}
    _whLastSent  = tick()

    local reqFunc = _getReqFunc()
    if not reqFunc then return end
    local HS = game:GetService("HttpService")

    -- Grade helper: AT pakai isAscension=true, RAID pakai false
    local function _gradeFor(mapNum, isAscension)
        local g = GetBestGrade(mapNum, isAscension)
        if g and g ~= "?" then return g end
        if isAscension then
            return (_runeGradeCache and (_runeGradeCache[-mapNum] or _runeGradeCache[mapNum])) or "?"
        else
            return (_runeGradeCache and _runeGradeCache[mapNum]) or "?"
        end
    end

    -- Parse baris jadi entries
    local entries_normal, entries_at = {}, {}
    local topGrade = "E"

    for _, line in ipairs(lines) do
        local isAT = line:find("Ascension Tower", 1, true)
        if isAT then
            local towerNum = tonumber(line:match("Ascension Tower (%d+)"))
            local grade    = towerNum and _gradeFor(towerNum, true) or _extractGradeLast(line) or "?"
            if (GRADE_RANK_W[grade] or 0) > (GRADE_RANK_W[topGrade] or 0) then topGrade = grade end
            table.insert(entries_at, { mapNum = towerNum, grade = grade, raw = line })
        else
            local mapNum = tonumber(line:match("appeared in (%d+)"))
            local grade  = mapNum and _gradeFor(mapNum, false) or _extractGradeLast(line) or "?"
            if (GRADE_RANK_W[grade] or 0) > (GRADE_RANK_W[topGrade] or 0) then topGrade = grade end
            local mapName = (MAP_NAMES and mapNum and MAP_NAMES[mapNum]) or (mapNum and ("Map "..mapNum)) or "?"
            table.insert(entries_normal, { mapNum = mapNum, mapName = mapName, grade = grade, raw = line })
        end
    end

    local total = #entries_normal + #entries_at

    local fields = {}
    if #entries_normal > 0 then
        local valLines = {}
        for _, e in ipairs(entries_normal) do
            local gradeStr = e.grade ~= "?" and ("**["..e.grade.."**]") or "[?]"
            local mapStr   = e.mapNum and ("Map "..e.mapNum.." - "..e.mapName) or e.raw
            table.insert(valLines, gradeStr.." "..mapStr)
        end
        table.insert(fields, {
            name   = "Normal Raid ("..#entries_normal..")",
            value  = table.concat(valLines, "\n"),
            inline = false,
        })
    end
    if #entries_at > 0 then
        local valLines = {}
        for _, e in ipairs(entries_at) do
            local gradeStr = e.grade ~= "?" and ("**["..e.grade.."]**") or "[?]"
            local tStr     = e.mapNum and ("Tower "..e.mapNum) or "Tower ?"
            table.insert(valLines, gradeStr.." "..tStr)
        end
        table.insert(fields, {
            name   = "Ascension Tower ("..#entries_at..")",
            value  = table.concat(valLines, "\n"),
            inline = false,
        })
    end
    local color   = GRADE_COLOR[topGrade] or GRADE_COLOR["E"]
    local payload = {embeds = {{
        title       = "[RAID OPEN] Rank "..topGrade,
        description = "Total: **"..total.."** raid aktif",
        color       = color,
        fields      = fields,
        footer      = {text = "Server Id : "..GetCachedServerId().."\nSent at : ".._getTimestamp()},
    }}}
    pcall(function()
        reqFunc({
            Url     = url,
            Method  = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body    = HS:JSONEncode(payload),
        })
    end)
end

-- Dipanggil dari ParseChatLine setiap kali TipsPanel tangkap 1 baris raid/AT
_WH.AddLine = function(text)
    if not _webhookEnabled or not _webhookUrl or _webhookUrl == "" then return end
    if _whSilent then return end
    local _now = tick()
    if _whSentCache[text] and (_now - _whSentCache[text]) < _WH_SENT_TTL then return end
    for _, existing in ipairs(_whBuffer) do
        if existing == text then return end
    end
    _whSentCache[text] = _now
    local _cacheSize = 0
    for _ in pairs(_whSentCache) do _cacheSize = _cacheSize + 1 end
    if _cacheSize > 100 then _whPruneSentCache() end
    table.insert(_whBuffer, text)
    -- Reset debounce: tunggu 3 detik setelah baris terakhir baru kirim
    if _whBufferTimer then pcall(function() task.cancel(_whBufferTimer) end) end
    _whBufferTimer = task.delay(3, function()
        _whBufferTimer = nil
        -- Cooldown 10 detik antar pengiriman
        if (tick() - _whLastSent) < 10 then
            local sisa = 10 - (tick() - _whLastSent)
            _whBufferTimer = task.delay(sisa, function()
                _whBufferTimer = nil
                _whFlushBuffer(_webhookUrl)
            end)
            return
        end
        _whFlushBuffer(_webhookUrl)
    end)
end

-- Alias agar kode lain tidak error
_WH.SendRaid     = function(url) _whFlushBuffer(url) end
SendWebhookRaid  = function(url) _whFlushBuffer(url) end
-- [v52+] SIEGE webhook dihapus: hanya Raid Normal + Ascension Tower
_WH.SendSiege    = function() end
SendWebhookSiege = function() end

TriggerWebhookDebounce = function() end -- no-op, compat
SendWebhookNotif       = TriggerWebhookDebounce -- alias compat

-- FlushWebhookPending: reset cooldown dan flush buffer
FlushWebhookPending = function()
    _whLastSent = 0
    if _WH and _whFlushBuffer and _webhookUrl and _webhookUrl ~= "" then
        _whFlushBuffer(_webhookUrl)
    end
end

-- SendCustomMessage: kirim pesan custom ke Discord webhook
_WH.SendCustomMessage = function(url, msg, onDone, onFail)
    if not url or url == "" then
        if onFail then onFail("URL kosong") end; return
    end
    if not url:find("discord%.com/api/webhooks") then
        if onFail then onFail("URL tidak dikenali (bukan Discord webhook)") end; return
    end
    if not _getReqFunc() then
        if onFail then onFail("Executor tidak support HTTP") end; return
    end
    task.spawn(function()
        local ok, errMsg = _doSend(url, msg)
        task.wait(0.3)
        if ok then
            if onDone then onDone() end
        else
            local reason = errMsg or "Gagal kirim"
            if onFail then onFail(reason) end
        end
    end)
end

-- SendTestEmbed: kirim embed test (format sama persis notif raid) ke Discord
_WH.SendTestEmbed = function(url, onDone, onFail)
    if not url or url == "" then
        if onFail then onFail("URL kosong") end; return
    end
    if not url:find("discord%.com/api/webhooks") then
        if onFail then onFail("URL tidak dikenali (bukan Discord webhook)") end; return
    end
    local reqFunc = _getReqFunc()
    if not reqFunc then
        if onFail then onFail("Executor tidak support HTTP") end; return
    end
    task.spawn(function()
        local HS = game:GetService("HttpService")
        local payload = {embeds = {{
            title       = "Test Succes",
            description = "Webhook aktif dan siap menerima notifikasi Raid !",
            color       = GRADE_COLOR["S"] or 16757810,
            fields      = {},
            footer      = {text = "Server Id : "..GetCachedServerId().."\nSent at : ".._getTimestamp()},
        }}}
        local callOk, callErr = pcall(function()
            reqFunc({
                Url     = url,
                Method  = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body    = HS:JSONEncode(payload),
            })
        end)
        task.wait(0.3)
        if callOk then
            if onDone then onDone() end
        else
            if onFail then onFail(tostring(callErr):sub(1,60)) end
        end
    end)
end

-- VerifyWebhookUrl: validasi format Discord webhook URL
_WH.VerifyWebhookUrl = function(url, onValid, onInvalid)
    if not url or url == "" then
        if onInvalid then onInvalid("URL kosong") end; return
    end
    if not url:find("discord%.com/api/webhooks/") then
        if onInvalid then onInvalid("Bukan URL Discord webhook valid") end; return
    end
    local id, token = url:match("webhooks/(%d+)/([%w_%-]+)")
    if id and token and #token > 10 then
        if onValid then onValid() end
    else
        if onInvalid then onInvalid("Format Discord webhook salah") end
    end
end

end -- end do WEBHOOK SYSTEM

-- ============================================================================
-- WEBHOOK TAB UI
-- Diconvert dari 1.lua: NewPanel("webhook") (baris 19113)
-- Ditulis ulang pakai WindUI native API
-- Notif: Raid Normal + Ascension Tower, Discord only
-- ============================================================================
do
    -- ── SECTION: Raid Notif/Webhook ─────────────────────────────────────────
    WebhookTab:Section({ Title = "Raid Notif / Webhook", Icon = "bell" })

    -- ── URL Input ──────────────────────────────────────────────────────────
    local _urlInputElement = WebhookTab:Input({
        Flag        = "webhookUrl",
        Title       = "URL Webhook",
        Desc        = "Paste Discord webhook URL kamu di sini",
        Placeholder = "PASTE YOUR DISCORD WEBHOOK URL HERE...",
        Value       = _webhookUrl,
        Callback    = function(val)
            _webhookUrl = (val or ""):match("^%s*(.-)%s*$") or ""
            if UpdatePlatformLbl then UpdatePlatformLbl() end
        end,
    })

    -- ── Platform detect Paragraph ──────────────────────────────────────────
    local _platformParagraph = WebhookTab:Paragraph({
        Title = "Platform",
        Desc  = "Content URL",
    })

    UpdatePlatformLbl = function()
        if not _platformParagraph then return end
        local url = _webhookUrl or ""
        local desc
        if url:find("discord%.com/api/webhooks") then
            desc = "[OK] Discord webhook DETECTED"
        elseif url == "" then
            desc = "Content URL"
        else
            desc = "URL not recognized (bukan Discord webhook)"
        end
        pcall(function() _platformParagraph:SetDesc(desc) end)
    end
    UpdatePlatformLbl()

    -- ── Toggle: ACTIVE Webhook ─────────────────────────────────────────────
    -- Saat di-ON: webhook langsung aktif & mulai kirim notif Raid Normal + ASC
    local _webhookToggleElement = WebhookTab:Toggle({
        Flag     = "webhookEnabled",
        Title    = "ACTIVE Webhook",
        Desc     = "Aktifkan notifikasi Raid Normal & Ascension Tower ke Discord",
        Value    = _webhookEnabled,
        Callback = function(on)
            if on then
                _webhookUrl = (_webhookUrl or ""):match("^%s*(.-)%s*$") or ""
                if _webhookUrl == "" or not _webhookUrl:find("discord%.com/api/webhooks") then
                    _webhookEnabled = false
                    if _webhookToggleElement then
                        pcall(function() _webhookToggleElement:Set(false, false) end)
                    end
                    pcall(function() warn("[ASH Webhook] Isi URL Discord webhook dulu sebelum mengaktifkan!") end)
                    if UpdatePlatformLbl then UpdatePlatformLbl() end
                    return
                end
            end
            _webhookEnabled = on
            if UpdatePlatformLbl then UpdatePlatformLbl() end
            if on then
                if FlushWebhookPending then task.spawn(FlushWebhookPending) end
            end
        end,
    })

    -- Expose setter visual-only dan setter logic ke global
    _visWebhookToggle = function(v)
        if _webhookToggleElement then
            pcall(function() _webhookToggleElement:Set(v, false) end)
        end
    end
    _setWebhookToggle = function(v)
        if v == _webhookEnabled then return end
        _webhookEnabled = v
        if _webhookToggleElement then
            pcall(function() _webhookToggleElement:Set(v) end)
        end
    end

    -- ── Button: Test Webhook ───────────────────────────────────────────────
    -- Kirim embed test (format sama persis notif raid) ke Discord webhook
    WebhookTab:Button({
        Title    = "Test Webhook",
        Desc     = "Kirim embed uji coba ke Discord webhook URL yang diisi",
        Callback = function()
            _webhookUrl = (_webhookUrl or ""):match("^%s*(.-)%s*$") or ""
            if UpdatePlatformLbl then UpdatePlatformLbl() end
            local _done = false
            task.delay(10, function()
                if not _done then
                    _done = true
                    pcall(function() warn("[ASH Webhook] Test: Timeout/No HTTP") end)
                end
            end)
            _WH.SendTestEmbed(_webhookUrl,
                function()
                    if _done then return end; _done = true
                    pcall(function() warn("[ASH Webhook] Test: [OK] Sent!") end)
                end,
                function(err)
                    if _done then return end; _done = true
                    pcall(function() warn("[ASH Webhook] Test: "..tostring(err)) end)
                end
            )
        end,
    })

end -- end do WEBHOOK TAB UI

-- ============================================================================
-- PANEL: CONFIG
-- Diconvert dari 1.lua: PANEL CONFIG (baris 20199-21362)
-- Ditulis ulang pakai WindUI native API (ConfigTab:Section/Paragraph/Button)
-- Karena WindUI tidak punya TextBox native yang bisa di-embed bebas,
-- UI sub-panel (save/load/delete) dibangun via Frame + Instance Roblox biasa
-- yang di-parent ke dalam sebuah WindUI "host frame" via ConfigTab:Custom()
-- atau diletakkan langsung di bawah ConfigTab's ScrollingFrame via Parent inject.
-- ============================================================================
do

    -- ─── CONFIG FILE PATH ────────────────────────────────────────────────────
    local CONFIG_FOLDER = "FLaConfigs"

    -- Helper: pastikan folder ada (aman di semua executor via polyfill)
    local function _ensureFolder()
        local ok, exists = pcall(isfolder, CONFIG_FOLDER)
        if not ok or not exists then
            pcall(makefolder, CONFIG_FOLDER)
        end
    end

    local function _cfgPath(name)
        return CONFIG_FOLDER .. "/" .. name .. ".json"
    end

    local function ListConfigs()
        _ensureFolder()
        local ok, files = pcall(listfiles, CONFIG_FOLDER)
        if not ok or type(files) ~= "table" then return {} end
        local names = {}
        for _, f in ipairs(files) do
            local n = tostring(f):match("([^/\\]+)%.json$")
            if n and n ~= "" then table.insert(names, n) end
        end
        table.sort(names)
        return names
    end

    -- ─── JSON ENCODE / DECODE MINIMAL (Luau tanpa loadstring) ────────────────
    local function jsonEncode(t, indent)
        indent = indent or 0
        local pad  = string.rep(" ", indent)
        local padI = string.rep(" ", indent + 2)
        if type(t) == "boolean" then return t and "true" or "false" end
        if type(t) == "number"  then return tostring(t) end
        if type(t) == "string"  then
            local s = t:gsub("\\","\\\\"):gsub('"','\\"'):gsub("\n","\\n"):gsub("\r","\\r")
            return '"' .. s .. '"'
        end
        if type(t) ~= "table" then return '"[unsupported]"' end
        local isArr = true; local n = 0
        for k in pairs(t) do n = n + 1; if type(k) ~= "number" then isArr = false; break end end
        if isArr and n == 0 then return "[]" end
        if isArr then
            local parts = {}
            for i = 1, #t do parts[i] = padI .. jsonEncode(t[i], indent + 2) end
            return "[\n" .. table.concat(parts, ",\n") .. "\n" .. pad .. "]"
        else
            local parts = {}
            for k, v in pairs(t) do
                if type(k) == "string" or type(k) == "number" then
                    table.insert(parts, padI .. '"' .. tostring(k) .. '": ' .. jsonEncode(v, indent + 2))
                end
            end
            table.sort(parts)
            return "{\n" .. table.concat(parts, ",\n") .. "\n" .. pad .. "}"
        end
    end

    local function jsonDecodeVal(s, pos)
        while pos <= #s and s:sub(pos, pos):match("%s") do pos = pos + 1 end
        local c = s:sub(pos, pos)
        if c == '"' then
            local i = pos + 1; local res = {}
            while i <= #s do
                local ch = s:sub(i, i)
                if ch == '"' then return table.concat(res), i + 1 end
                if ch == '\\' then
                    local nx = s:sub(i + 1, i + 1)
                    if     nx == '"'  then table.insert(res, '"')
                    elseif nx == '\\' then table.insert(res, '\\')
                    elseif nx == 'n'  then table.insert(res, '\n')
                    elseif nx == 'r'  then table.insert(res, '\r')
                    else                   table.insert(res, nx) end
                    i = i + 2
                else
                    table.insert(res, ch); i = i + 1
                end
            end
            return "", pos
        end
        if c == '{' then
            local obj = {}; pos = pos + 1
            while pos <= #s do
                while pos <= #s and s:sub(pos, pos):match("%s") do pos = pos + 1 end
                if s:sub(pos, pos) == '}' then return obj, pos + 1 end
                if s:sub(pos, pos) == ',' then pos = pos + 1 end
                while pos <= #s and s:sub(pos, pos):match("%s") do pos = pos + 1 end
                local key, p2 = jsonDecodeVal(s, pos); pos = p2
                while pos <= #s and s:sub(pos, pos):match("[%s:]") do pos = pos + 1 end
                local val, p3 = jsonDecodeVal(s, pos); pos = p3
                obj[key] = val
            end
            return obj, pos
        end
        if c == '[' then
            local arr = {}; pos = pos + 1
            while pos <= #s do
                while pos <= #s and s:sub(pos, pos):match("%s") do pos = pos + 1 end
                if s:sub(pos, pos) == ']' then return arr, pos + 1 end
                if s:sub(pos, pos) == ',' then pos = pos + 1 end
                local val, p2 = jsonDecodeVal(s, pos); pos = p2
                table.insert(arr, val)
            end
            return arr, pos
        end
        if s:sub(pos, pos + 3) == "true"  then return true,  pos + 4 end
        if s:sub(pos, pos + 4) == "false" then return false, pos + 5 end
        if s:sub(pos, pos + 3) == "null"  then return nil,   pos + 4 end
        local num = s:match("^-?%d+%.?%d*[eE]?[+-]?%d*", pos)
        if num then return tonumber(num), pos + #num end
        return nil, pos + 1
    end

    local function jsonDecode(s)
        local ok, val = pcall(function()
            local v, _ = jsonDecodeVal(s, 1)
            return v
        end)
        if ok then return val else return nil end
    end

    -- ─── COLLECT CONFIG STATE (snapshot semua state aktif saat ini) ──────────
    local function CollectConfig()
        local cfg = {}

        -- ── MAIN TAB ──────────────────────────────────────────────────────
        cfg.sellHeroOn        = _autoSellOnState or false
        cfg.autoCollectOn     = _autoCollectState or false
        cfg.sellWeaponOn      = _autoSellWeaponState or false
        cfg.swSelectAll       = _swSelectAllRef and _swSelectAllRef() or true
        cfg.swSelectedIds     = {}
        cfg.swSelNames        = {}
        if _swSelectedIdsGlobal then
            for k, v in pairs(_swSelectedIdsGlobal) do if v then cfg.swSelectedIds[tostring(k)] = true end end
        end
        if _swSelNamesGlobal then
            for k, v in pairs(_swSelNamesGlobal) do cfg.swSelNames[tostring(k)] = v end
        end
        cfg.decompGemOn       = _autoDecompGemState or false
        cfg.gemMinLevel       = _gemMinLevelState or 1
        cfg.gemMaxLevel       = _gemMaxLevelState or 1

        -- ── HIDE TAB ──────────────────────────────────────────────────────
        cfg.hideRerollChat    = _hideRerollChatState or false
        cfg.hideAllUI         = _hideAllUIState or false
        cfg.hideAllAnim       = _hideAllAnimState or false

        -- ── FARM TAB ──────────────────────────────────────────────────────
        cfg.randomAttackOn    = _raRunningState or false

        -- ── ATTACK TAB ────────────────────────────────────────────────────
        cfg.hideReward        = _hideRewardState or false
        cfg.massAttackOn      = MA and MA.running or false
        cfg.killDDIdx         = _killDDIdxState or 1
        cfg.delayDDIdx        = _delayDDIdxState or 2
        cfg.maMapSel          = {}
        if _maMapSelState then
            for k, v in pairs(_maMapSelState) do if v then cfg.maMapSel[tostring(k)] = true end end
        end
        cfg.skillZ = SKL and SKL.Z and SKL.Z.on or false
        cfg.skillX = SKL and SKL.X and SKL.X.on or false
        cfg.skillC = SKL and SKL.C and SKL.C.on or false
        cfg.skillV = SKL and SKL.V and SKL.V.on or false
        cfg.skillF = SKL and SKL.F and SKL.F.on or false

        -- ── PLAYER TAB ────────────────────────────────────────────────────
        cfg.noClipOn      = _noClipState or false
        cfg.antiAfkOn     = _antiAfkState or false
        cfg.walkSpeed     = _walkSpeedState or 16

        -- ── AUTOMATION TAB ────────────────────────────────────────────────
        cfg.raidOn        = _raidOn or false
        cfg.raidPMIdx     = 1
        cfg.raidPreferMaps  = {}
        cfg.raidRuneGrades  = {}
        cfg.raidRuneEnabled   = RAID and RAID.runeEnabled or false
        cfg.raidUpdownEnabled = RAID and RAID.updownEnabled or false
        cfg.raidUpdownDir     = RAID and RAID.updownDir or "up"
        cfg.raidUpdownTargetGrade = RAID and RAID.updownTargetGrade or nil
        cfg.raidRuneMapTarget = RAID and RAID.runeMapTarget or 0
        cfg.raidListEnabled   = RAID and RAID.listEnabled or false
        cfg.raidAutoKillBoss  = RAID and RAID.autoKillBoss or false
        cfg.raidBossDelay     = RAID and RAID.bossDelay or 3
        cfg.raidListEntries   = {}
        if RAID and RAID.listEntries then
            for i, ent in ipairs(RAID.listEntries) do
                local saveMaps = {}; local saveRanks = {}
                if ent.maps  then for mn, v in pairs(ent.maps)  do if v then saveMaps[tostring(mn)] = true end end end
                if ent.ranks then for g,  v in pairs(ent.ranks) do if v then saveRanks[g] = true end end end
                cfg.raidListEntries[i] = { maps = saveMaps, ranks = saveRanks }
            end
        end
        if RAID and RAID.preferMaps then
            for k, v in pairs(RAID.preferMaps) do if v then cfg.raidPreferMaps[tostring(k)] = true end end
        end
        if RAID and RAID.runeGrades then
            for k, v in pairs(RAID.runeGrades) do if v then cfg.raidRuneGrades[tostring(k)] = true end end
        end
        pcall(function()
            local PM_KEYS = {"default","byrank","bymap","hard","easy","manual"}
            for i, k in ipairs(PM_KEYS) do if RAID and k == RAID.pickMode then cfg.raidPMIdx = i; break end end
        end)

        cfg.ascOn        = _ascOn or false
        cfg.ascPMIdx     = 1
        cfg.ascPreferMaps= {}
        cfg.ascRuneGrades= {}
        cfg.ascRuneEnabled    = ASC and ASC.runeEnabled or false
        cfg.ascRuneMapTarget  = ASC and ASC.runeMapTarget or 0
        cfg.ascPreferMapTarget= ASC and ASC.preferMapTarget or 0
        cfg.ascAutoKillBoss   = ASC and ASC.autoKillBoss or false
        cfg.ascBossDelay      = ASC and ASC.bossDelay or 3
        if ASC and ASC.preferMaps then
            for k, v in pairs(ASC.preferMaps) do if v then cfg.ascPreferMaps[tostring(k)] = true end end
        end
        if ASC and ASC.runeGrades then
            for k, v in pairs(ASC.runeGrades) do if v then cfg.ascRuneGrades[tostring(k)] = true end end
        end
        pcall(function()
            local APM_KEYS = {"default","byrank","bymap","hard","easy","manual"}
            for i, k in ipairs(APM_KEYS) do if ASC and k == ASC.pickMode then cfg.ascPMIdx = i; break end end
        end)
        cfg.ascListEnabled = ASC and ASC.listEnabled or false
        cfg.ascListEntries = {}
        if ASC and ASC.listEntries then
            for i, ent in ipairs(ASC.listEntries) do
                local saveMaps = {}; local saveRanks = {}
                for k, v in pairs(ent.maps)  do if v then saveMaps[tostring(k)] = true end end
                for k, v in pairs(ent.ranks) do if v then saveRanks[tostring(k)] = true end end
                cfg.ascListEntries[i] = { maps = saveMaps, ranks = saveRanks }
            end
        end

        cfg.siegeOn      = _siegeToggleState or false
        cfg.siegeExclude = {}
        if SIEGE and SIEGE.excludeMaps then
            for k, v in pairs(SIEGE.excludeMaps) do cfg.siegeExclude[tostring(k)] = v end
        end

        cfg.dungeonOn    = _dungeonToggleState or false

        cfg.st2On        = ST2 and ST2.enabled or false
        cfg.st2AttackOn  = ST2 and ST2.attackEnabled or false
        cfg.st2WaveCount = ST2 and ST2.waveCount or 0

        -- ── REROLL TAB ────────────────────────────────────────────────────
        -- Hero Fastroll
        cfg.heroRollOn   = _HR_RPT and _HR_RPT.running or false
        cfg.heroX100On   = _HR_RPT and _HR_RPT.x100 or false
        cfg.heroSlotTarget = {{},{},{}}
        if _HR_RPT and _HR_RPT.slotTarget then
            for si = 1, 3 do
                for qid, v in pairs(_HR_RPT.slotTarget[si]) do
                    if v then cfg.heroSlotTarget[si][tostring(qid)] = true end
                end
            end
        end
        -- Weapon Fastroll
        cfg.weaponRollOn = _WR_RPT and _WR_RPT.running or false
        cfg.weaponX100On = _WR_RPT and _WR_RPT.x100 or false
        cfg.weaponSlotTarget = {{},{},{}}
        if _WR_RPT and _WR_RPT.slotTarget then
            for si = 1, 3 do
                for qid, v in pairs(_WR_RPT.slotTarget[si]) do
                    if v then cfg.weaponSlotTarget[si][tostring(qid)] = true end
                end
            end
        end
        -- PetGear
        cfg.pgrOn      = {false, false, false}
        cfg.pgr100On   = {false, false, false}
        cfg.pgrTargets = {{},{},{}}
        if PGR then
            for i = 1, 3 do
                cfg.pgrOn[i]  = PGR.enOnFlags[i] or false
                cfg.pgr100On[i] = PGR100 and PGR100.enOnFlags[i] or false
                for gid, v in pairs(PGR.targets[i]) do
                    if v then cfg.pgrTargets[i][tostring(gid)] = true end
                end
            end
        end
        -- Halo
        cfg.haloOn = {false, false, false}
        if HALO then
            for i = 1, 3 do cfg.haloOn[i] = HALO.enOnFlags[i] or false end
        end
        -- Ornament
        cfg.ornOn      = {}
        cfg.ornTargets = {}
        if ORN then
            local nm = #_ASH_ORN.MACHINES
            for i = 1, nm do
                cfg.ornOn[i]      = ORN.enOnFlags[i] or false
                cfg.ornTargets[i] = {}
                for qid, v in pairs(ORN.targets[i]) do
                    if v then cfg.ornTargets[i][tostring(qid)] = true end
                end
            end
        end
        -- Merge & Use Potion
        cfg.mergeOn = _mergeRunningState or false
        cfg.useOn   = _useRunningState or false

        -- ── SETTINGS / WEBHOOK TAB ────────────────────────────────────────
        cfg.webhookEnabled  = _webhookEnabled or false
        cfg.webhookUrl      = _webhookUrl or ""
        cfg.webhookMode     = _webhookMode or "both"
        cfg.webhookModeIdx  = 3
        pcall(function()
            local MODE_KEYS = {"raid","siege","both"}
            for i, k in ipairs(MODE_KEYS) do
                if k == (_webhookMode or "both") then cfg.webhookModeIdx = i; break end
            end
        end)

        -- ── THEME ─────────────────────────────────────────────────────────
        cfg.themeTransparency = _G.ThemeTransparency or 0
        cfg.themeName         = _G.CurrentTheme or "Solo Leveling"

        return cfg
    end

    -- ─── SAVE CONFIG ─────────────────────────────────────────────────────────
    local function SaveConfigAs(name)
        _ensureFolder()
        local ok, err = pcall(function()
            local cfg = CollectConfig()
            writefile(_cfgPath(name), jsonEncode(cfg))
        end)
        return ok, err
    end

    -- ─── APPLY CONFIG (restore semua state + visual) ─────────────────────────
    local function ApplyConfig(cfg)
        if type(cfg) ~= "table" then return false end

        -- ── MAIN TAB ──────────────────────────────────────────────────────
        pcall(function()
            if _setSellHeroToggle    then _setSellHeroToggle(cfg.sellHeroOn == true) end
            if _setAutoCollectToggle then _setAutoCollectToggle(cfg.autoCollectOn == true) end
            if _swRestoreFromConfig  then
                local isAll = cfg.swSelectAll ~= false
                _swRestoreFromConfig(isAll, cfg.swSelectedIds, cfg.swSelNames)
            end
            if _autoSellWeaponSet then _autoSellWeaponSet(cfg.sellWeaponOn == true) end
            if _autoDecompGemSet  then _autoDecompGemSet(cfg.decompGemOn == true) end
            if _setGemLevelRange and cfg.gemMinLevel and cfg.gemMaxLevel then
                _setGemLevelRange(cfg.gemMinLevel, cfg.gemMaxLevel)
            end
        end)

        -- ── HIDE TAB ──────────────────────────────────────────────────────
        task.delay(0.3, function()
            pcall(function()
                if _setHideRerollChat then _setHideRerollChat(cfg.hideRerollChat == true) end
                if _visHideRerollChat then _visHideRerollChat(cfg.hideRerollChat == true) end
            end)
            pcall(function()
                if _setHideAllUI then _setHideAllUI(cfg.hideAllUI == true) end
                if _visHideAllUI then _visHideAllUI(cfg.hideAllUI == true) end
            end)
            pcall(function()
                if _setHideAllAnim then _setHideAllAnim(cfg.hideAllAnim == true) end
                if _visHideAllAnim then _visHideAllAnim(cfg.hideAllAnim == true) end
            end)
        end)

        -- ── FARM TAB ──────────────────────────────────────────────────────
        pcall(function()
            if _setRAToggle  then _setRAToggle(cfg.randomAttackOn == true) end
            if _visRandomAtk then _visRandomAtk(cfg.randomAttackOn == true) end
        end)

        -- ── ATTACK TAB ────────────────────────────────────────────────────
        pcall(function()
            if _maMapSelState and cfg.maMapSel then
                for k in pairs(_maMapSelState) do _maMapSelState[k] = nil end
                if MR and MR.selected then for k in pairs(MR.selected) do MR.selected[k] = nil end end
                for k, v in pairs(cfg.maMapSel) do
                    local n = tonumber(k)
                    if n then _maMapSelState[n] = true; if MR then MR.selected[n] = true end end
                end
                if _maMapItemRefs then
                    local allOn = true
                    for j = 1, 20 do if not _maMapSelState[j] then allOn = false; break end end
                    if _maMapItemRefs[1] then
                        _maMapItemRefs[1].chk.Text = allOn and "v" or ""
                        _maMapItemRefs[1].lbl.TextColor3 = allOn and C.ACC2 or C.TXT
                    end
                    for j = 1, 20 do
                        local ref = _maMapItemRefs[j + 1]
                        if ref then
                            local sel = _maMapSelState[j] == true
                            ref.chk.Text = sel and "v" or ""
                            ref.lbl.TextColor3 = sel and C.ACC2 or C.TXT
                        end
                    end
                end
                if _maUpdateMapDDLbl then pcall(_maUpdateMapDDLbl) end
            end
            task.delay(0.1, function()
                pcall(function() if _setKillDDGlobal  and cfg.killDDIdx  then _setKillDDGlobal(cfg.killDDIdx)   end end)
                pcall(function() if _setDelayDDGlobal and cfg.delayDDIdx then _setDelayDDGlobal(cfg.delayDDIdx) end end)
            end)
            for _, n in ipairs({"Z","X","C","V","F"}) do
                local key = "skill" .. n
                if cfg[key] == true and not SKL[n].on then
                    SkOn(n)
                else
                    if cfg[key] == false and SKL[n].on then SkOff(n) end
                end
                -- Sync visual toggle WindUI
                if _setSkillToggleVis then
                    pcall(function() _setSkillToggleVis(n, cfg[key] == true) end)
                end
            end
            task.delay(0.5, function()
                if _setHideReward      then _setHideReward(cfg.hideReward == true) end
                if _visHideRewardPanel then _visHideRewardPanel(cfg.hideReward == true) end
                if _setMaToggleGlobal  then _setMaToggleGlobal(cfg.massAttackOn == true) end
                if _visMassAtk         then _visMassAtk(cfg.massAttackOn == true) end
            end)
        end)

        -- ── PLAYER TAB ────────────────────────────────────────────────────
        pcall(function()
            if _setNoClipToggle  then _setNoClipToggle(cfg.noClipOn == true) end
            if _visNoClip        then _visNoClip(cfg.noClipOn == true) end
            if _setAntiAfkToggle then _setAntiAfkToggle(cfg.antiAfkOn == true) end
            if _visAntiAfk       then _visAntiAfk(cfg.antiAfkOn == true) end
            if _setSpeedSlider and cfg.walkSpeed then _setSpeedSlider(cfg.walkSpeed) end
        end)

        -- ── AUTOMATION TAB ────────────────────────────────────────────────
        pcall(function()
            -- Restore RAID pick mode state langsung (tanpa trigger ApplyPickModeLock)
            if cfg.raidPMIdx then
                local PM_KEYS = {"default","byrank","bymap","hard","easy","manual"}
                local ii = math.clamp(cfg.raidPMIdx, 1, #PM_KEYS)
                RAID.pickMode = PM_KEYS[ii]
                local PM_TO_DIFF = {default="easy",byrank="easy",bymap="easy",hard="hard",easy="easy",manual="easy"}
                RAID.difficulty = PM_TO_DIFF[PM_KEYS[ii]] or "easy"
                RAID.snapshotMapId = nil
            end
            -- Restore preferMaps & runeGrades DULU sebelum apply lock
            if RAID.preferMaps and cfg.raidPreferMaps then
                for k in pairs(RAID.preferMaps) do RAID.preferMaps[k] = nil end
                for k, v in pairs(cfg.raidPreferMaps) do
                    local n = tonumber(k); if n then RAID.preferMaps[n] = true end
                end
            end
            if RAID.runeGrades and cfg.raidRuneGrades then
                for k in pairs(RAID.runeGrades) do RAID.runeGrades[k] = nil end
                for k, v in pairs(cfg.raidRuneGrades) do RAID.runeGrades[k] = true end
            end
            RAID.runeEnabled   = cfg.raidRuneEnabled   == true
            RAID.updownEnabled = cfg.raidUpdownEnabled  == true
            RAID.updownDir     = cfg.raidUpdownDir or "up"
            RAID.runeMapTarget = cfg.raidRuneMapTarget or 0

            task.delay(0.05, function()
                pcall(function()
                    if _raidUpdatePrefLabel then _raidUpdatePrefLabel() end
                    if _raidUpdateRankLabel then _raidUpdateRankLabel() end
                    if _setRaidPMIdx and cfg.raidPMIdx then _setRaidPMIdx(cfg.raidPMIdx) end
                    -- Restore ulang data yg mungkin ter-clear oleh ApplyPickModeLock
                    if RAID.preferMaps and cfg.raidPreferMaps then
                        for k in pairs(RAID.preferMaps) do RAID.preferMaps[k] = nil end
                        for k, v in pairs(cfg.raidPreferMaps) do
                            local n = tonumber(k); if n then RAID.preferMaps[n] = true end
                        end
                    end
                    if RAID.runeGrades and cfg.raidRuneGrades then
                        for k in pairs(RAID.runeGrades) do RAID.runeGrades[k] = nil end
                        for k, v in pairs(cfg.raidRuneGrades) do RAID.runeGrades[k] = true end
                    end
                    if _raidUpdatePrefLabel then _raidUpdatePrefLabel() end
                    if _raidUpdateRankLabel then _raidUpdateRankLabel() end
                end)
                pcall(function()
                    if _setRaidUpdownGrade   then _setRaidUpdownGrade(cfg.raidUpdownTargetGrade or nil) end
                    if _raidUpdownToggleVis  then _raidUpdownToggleVis(cfg.raidUpdownEnabled == true) end
                    if _raidUpdownDirVis     then _raidUpdownDirVis(cfg.raidUpdownDir or "up") end
                    if _setRaidRuneMapTarget then _setRaidRuneMapTarget(cfg.raidRuneMapTarget or 0) end
                    if _raidBossToggleVis    then _raidBossToggleVis(cfg.raidAutoKillBoss == true) end
                    if _raidBossDelaySet     then _raidBossDelaySet(cfg.raidBossDelay or 3) end
                    if _setRaidListEnabledVis then
                        _setRaidListEnabledVis(cfg.raidListEnabled == true)
                    else
                        RAID.listEnabled = cfg.raidListEnabled == true
                    end
                    if RAID.listEntries and cfg.raidListEntries then
                        for k in pairs(RAID.listEntries) do RAID.listEntries[k] = nil end
                        for i, ent in ipairs(cfg.raidListEntries) do
                            local maps = {}; local ranks = {}
                            if type(ent.maps)  == "table" then
                                for mk, mv in pairs(ent.maps)  do if mv then maps[tonumber(mk) or mk] = true end end
                            end
                            if type(ent.ranks) == "table" then
                                for rk, rv in pairs(ent.ranks) do if rv then ranks[rk] = true end end
                            end
                            RAID.listEntries[i] = { maps = maps, ranks = ranks }
                        end
                        if _raidRebuildListRows then pcall(_raidRebuildListRows) end
                    end
                end)
                task.delay(0.5, function()
                    if _setRaidToggle then _setRaidToggle(cfg.raidOn == true) end
                end)
            end)
        end)

        pcall(function()
            if _setAscPMIdx and cfg.ascPMIdx then _setAscPMIdx(cfg.ascPMIdx) end
            if ASC.preferMaps and cfg.ascPreferMaps then
                for k in pairs(ASC.preferMaps) do ASC.preferMaps[k] = nil end
                for k, v in pairs(cfg.ascPreferMaps) do
                    local n = tonumber(k); if n then ASC.preferMaps[n] = true end
                end
            end
            if ASC.runeGrades and cfg.ascRuneGrades then
                for k in pairs(ASC.runeGrades) do ASC.runeGrades[k] = nil end
                for k, v in pairs(cfg.ascRuneGrades) do ASC.runeGrades[k] = true end
            end
            ASC.runeEnabled     = cfg.ascRuneEnabled     == true
            ASC.runeMapTarget   = cfg.ascRuneMapTarget   or 0
            ASC.preferMapTarget = cfg.ascPreferMapTarget or 0
            if _ascBossToggleVis then
                _ascBossToggleVis(cfg.ascAutoKillBoss == true)
            else
                ASC.autoKillBoss = cfg.ascAutoKillBoss == true
            end
            if _ascBossDelaySet then
                _ascBossDelaySet(cfg.ascBossDelay or 3)
            else
                ASC.bossDelay = cfg.ascBossDelay or 3
            end
            if ASC.listEntries and cfg.ascListEntries then
                for k in pairs(ASC.listEntries) do ASC.listEntries[k] = nil end
                for i, ent in ipairs(cfg.ascListEntries) do
                    local maps = {}; local ranks = {}
                    if ent.maps  then for k, v in pairs(ent.maps)  do local n = tonumber(k); if n then maps[n] = true end end end
                    if ent.ranks then for k, v in pairs(ent.ranks) do ranks[k] = true end end
                    ASC.listEntries[i] = { maps = maps, ranks = ranks }
                end
            end
            if _setAscListEnabledVis then
                _setAscListEnabledVis(cfg.ascListEnabled == true)
            else
                ASC.listEnabled = cfg.ascListEnabled == true
            end
            if _ascRebuildListRows then _ascRebuildListRows() end
            task.delay(0.7, function()
                if _setAscToggle then _setAscToggle(cfg.ascOn == true) end
            end)
        end)

        pcall(function()
            if SIEGE.excludeMaps and cfg.siegeExclude then
                for k, v in pairs(cfg.siegeExclude) do
                    local n = tonumber(k); if n then SIEGE.excludeMaps[n] = v end
                end
            end
            -- Sync visual dropdown exclude maps setelah data ter-restore
            if _visSiegeExcludeDD then pcall(_visSiegeExcludeDD) end
            task.delay(0.9, function()
                if _setSiegeToggle then _setSiegeToggle(cfg.siegeOn == true) end
                if _visSiege       then _visSiege(cfg.siegeOn == true) end
            end)
        end)

        pcall(function()
            task.delay(1.1, function()
                if _setDungeonToggle then _setDungeonToggle(cfg.dungeonOn == true) end
                if _visDungeon       then _visDungeon(cfg.dungeonOn == true) end
            end)
        end)

        pcall(function()
            ST2.waveCount = cfg.st2WaveCount or 0
            task.delay(1.3, function()
                if _setST2Toggle then _setST2Toggle(cfg.st2On == true) end
                if _visST2       then _visST2(cfg.st2On == true) end
                if ST2.setAttackToggle and cfg.st2AttackOn ~= nil then
                    ST2.setAttackToggle(cfg.st2AttackOn == true)
                end
            end)
        end)

        -- ── REROLL TAB ────────────────────────────────────────────────────
        task.delay(0.3, function()
            pcall(function()
                if _HR_RPT and _HR_RPT.slotTarget and cfg.heroSlotTarget then
                    for si = 1, 3 do
                        for k in pairs(_HR_RPT.slotTarget[si]) do _HR_RPT.slotTarget[si][k] = nil end
                        if type(cfg.heroSlotTarget[si]) == "table" then
                            for qid, v in pairs(cfg.heroSlotTarget[si]) do
                                if v then _HR_RPT.slotTarget[si][tonumber(qid) or qid] = true end
                            end
                        end
                    end
                end
                if _setHeroX100Toggle then _setHeroX100Toggle(cfg.heroX100On == true) end
                task.delay(0.2, function()
                    if not cfg.heroX100On then
                        if _setHeroRollToggle then _setHeroRollToggle(cfg.heroRollOn == true) end
                    end
                end)
            end)
            pcall(function()
                if _WR_RPT and _WR_RPT.slotTarget and cfg.weaponSlotTarget then
                    for si = 1, 3 do
                        for k in pairs(_WR_RPT.slotTarget[si]) do _WR_RPT.slotTarget[si][k] = nil end
                        if type(cfg.weaponSlotTarget[si]) == "table" then
                            for qid, v in pairs(cfg.weaponSlotTarget[si]) do
                                if v then _WR_RPT.slotTarget[si][tonumber(qid) or qid] = true end
                            end
                        end
                    end
                end
                if _setWeaponX100Toggle then _setWeaponX100Toggle(cfg.weaponX100On == true) end
                task.delay(0.2, function()
                    if not cfg.weaponX100On then
                        if _setWeaponRollToggle then _setWeaponRollToggle(cfg.weaponRollOn == true) end
                    end
                end)
            end)
            pcall(function()
                if PGR and cfg.pgrTargets then
                    for i = 1, 3 do
                        for k in pairs(PGR.targets[i]) do PGR.targets[i][k] = nil end
                        if type(cfg.pgrTargets[i]) == "table" then
                            for gid, v in pairs(cfg.pgrTargets[i]) do
                                if v then PGR.targets[i][tonumber(gid) or gid] = true end
                            end
                        end
                        local enOn = cfg.pgrOn and cfg.pgrOn[i] == true or false
                        PGR.enOnFlags[i] = enOn
                        if PGR.toggleBtns[i] then
                            PGR.toggleBtns[i].BackgroundColor3 = enOn and C.ACC or C.BG3
                        end
                        if PGR.toggleKnobs[i] then
                            PGR.toggleKnobs[i].Position = enOn and UDim2.new(1,-20,0.5,-9) or UDim2.new(0,2,0.5,-9)
                        end
                        if enOn then DoAutoRollPetGear(i, true) end
                        if PGR100 then
                            local r100On = cfg.pgr100On and cfg.pgr100On[i] == true or false
                            if r100On and not enOn then
                                PGR100.enOnFlags[i] = true
                                if PGR100.toggleBtns[i] then
                                    PGR100.toggleBtns[i].BackgroundColor3 = Color3.fromRGB(0,180,200)
                                end
                                if PGR100.toggleKnobs[i] then
                                    PGR100.toggleKnobs[i].Position = UDim2.new(1,-20,0.5,-9)
                                end
                                PGR100.Loop(i)
                            end
                        end
                    end
                end
            end)
            pcall(function()
                if HALO and cfg.haloOn then
                    for i = 1, 3 do
                        local enOn = cfg.haloOn[i] == true
                        HALO.enOnFlags[i] = enOn
                        if HALO.toggleBtns[i] then
                            HALO.toggleBtns[i].BackgroundColor3 = enOn and C.ACC or C.BG3
                        end
                        if HALO.toggleKnobs[i] then
                            HALO.toggleKnobs[i].Position = enOn and UDim2.new(1,-20,0.5,-9) or UDim2.new(0,2,0.5,-9)
                        end
                        DoAutoRollHalo(i, enOn)
                    end
                end
            end)
            pcall(function()
                if ORN and cfg.ornTargets then
                    local nm = #_ASH_ORN.MACHINES
                    for i = 1, nm do
                        for k in pairs(ORN.targets[i]) do ORN.targets[i][k] = nil end
                        if type(cfg.ornTargets[i]) == "table" then
                            for qid, v in pairs(cfg.ornTargets[i]) do
                                if v then ORN.targets[i][tonumber(qid) or qid] = true end
                            end
                        end
                        local enOn = cfg.ornOn and cfg.ornOn[i] == true or false
                        ORN.enOnFlags[i] = enOn
                        if ORN.toggleBtns[i] then
                            ORN.toggleBtns[i].BackgroundColor3 = enOn and C.ACC or C.BG3
                        end
                        if ORN.toggleKnobs[i] then
                            ORN.toggleKnobs[i].Position = enOn and UDim2.new(1,-20,0.5,-9) or UDim2.new(0,2,0.5,-9)
                        end
                        if enOn then _ASH_ORN.DoRoll(i, true) end
                    end
                end
            end)
            pcall(function()
                if _setMergeToggle then _setMergeToggle(cfg.mergeOn == true) end
                if _visMerge       then _visMerge(cfg.mergeOn == true) end
                if _setUseToggle   then _setUseToggle(cfg.useOn == true) end
                if _visUse         then _visUse(cfg.useOn == true) end
            end)
        end)

        -- ── WEBHOOK TAB ───────────────────────────────────────────────────
        pcall(function()
            _webhookEnabled = cfg.webhookEnabled == true
            _webhookUrl     = cfg.webhookUrl or ""
            if _setWebhookToggle  then _setWebhookToggle(cfg.webhookEnabled == true) end
            if _visWebhookToggle  then _visWebhookToggle(cfg.webhookEnabled == true) end
            if _webhookModeSetIdx and cfg.webhookModeIdx then
                _webhookModeSetIdx(cfg.webhookModeIdx)
            end
        end)

        -- ── REROLL slot label refresh (setelah data restore) ──────────────
        task.delay(0.5, function()
            pcall(function()
                if _HR_RPT and _HR_RPT.slotRefreshFns then
                    for i = 1, 3 do
                        if _HR_RPT.slotRefreshFns[i] then _HR_RPT.slotRefreshFns[i]() end
                    end
                end
            end)
            pcall(function()
                if _WR_RPT and _WR_RPT.slotRefreshFns then
                    for i = 1, 3 do
                        if _WR_RPT.slotRefreshFns[i] then _WR_RPT.slotRefreshFns[i]() end
                    end
                end
            end)
        end)

        -- ── THEME ─────────────────────────────────────────────────────────
        pcall(function()
            if cfg.themeName and cfg.themeName ~= "" then
                pcall(function() ApplyTheme(cfg.themeName) end)
            end
            if cfg.themeTransparency ~= nil then
                _G.ThemeTransparency = cfg.themeTransparency
                Window.BackgroundTransparency = _G.ThemeTransparency
                if _setTransSlider then
                    local v = math.floor(cfg.themeTransparency * 99 + 1)
                    _setTransSlider(math.clamp(v, 1, 100))
                end
            end
        end)

        return true
    end

    -- ─── LOAD / DELETE CONFIG ─────────────────────────────────────────────────
    local function LoadConfigByName(name)
        local ok, result = pcall(function()
            local path = _cfgPath(name)
            local fileExists = false
            pcall(function() fileExists = isfile(path) end)
            if not fileExists then return nil end
            local raw = nil
            pcall(function() raw = readfile(path) end)
            if not raw or raw == "" then return nil end
            return jsonDecode(raw)
        end)
        if not ok then return nil end
        if type(result) ~= "table" then return nil end
        return result
    end

    local function DeleteConfigByName(name)
        local ok = pcall(function()
            local path = _cfgPath(name)
            local exists = pcall(isfile, path)
            if exists then pcall(delfile, path) end
        end)
        return ok
    end

    -- ─── SINGLE CONFIG SLOT (tidak multi-save lagi) ──────────────────────────
    -- Semua save/load/delete sekarang mengarah ke SATU file config tetap.
    -- Tidak ada lagi input nama, dropdown pilih config, atau tombol refresh.
    local SINGLE_CONFIG_NAME = "config"

    -- ─── PARAGRAPH STATUS (WindUI native) ────────────────────────────────────
    ConfigTab:Section({ Title = "Config Manager", Icon = "save" })

    local _statusPara = ConfigTab:Paragraph({
        Title = "Status",
        Desc  = "Pilih aksi di bawah.",
    })

    local function SetStatus(msg)
        pcall(function() _statusPara:SetDesc(msg) end)
    end

    -- ─── INISIALISASI STATUS AWAL ─────────────────────────────────────────────
    do
        local exists = false
        pcall(function() exists = isfile(_cfgPath(SINGLE_CONFIG_NAME)) end)
        if exists then
            SetStatus("Config tersimpan ditemukan. Klik LOAD CONFIG untuk menerapkan.")
        else
            SetStatus("Belum ada config tersimpan. Atur fitur lalu klik SAVE CONFIG.")
        end
    end

    -- ─── TOMBOL: SAVE CONFIG ──────────────────────────────────────────────────
    -- Menyimpan semua state/visual fitur yang sedang di-set user saat ini.
    -- Selalu menimpa (overwrite) file config tunggal yang sama -> tidak ada multi-save.
    ConfigTab:Button({
        Title    = "SAVE CONFIG",
        Desc     = "Simpan semua setting & fitur script saat ini (menimpa config sebelumnya)",
        Callback = function()
            SetStatus("Menyimpan config...")
            task.delay(0.05, function()
                local ok, err = SaveConfigAs(SINGLE_CONFIG_NAME)
                if ok then
                    SetStatus("Config tersimpan. (" .. os.date("%H:%M:%S") .. ")")
                else
                    SetStatus("[!] Gagal simpan: " .. tostring(err):sub(1, 60))
                end
            end)
        end,
    })

    -- ─── TOMBOL: LOAD CONFIG ──────────────────────────────────────────────────
    -- Restore sempurna semua state & tampilan menu/fitur sesuai config yang tersimpan.
    ConfigTab:Button({
        Title    = "LOAD CONFIG",
        Desc     = "Restore semua setting & fitur script sesuai config yang tersimpan",
        Callback = function()
            SetStatus("Memuat config...")
            task.delay(0.05, function()
                local cfg = LoadConfigByName(SINGLE_CONFIG_NAME)
                if type(cfg) == "table" then
                    ApplyConfig(cfg)
                    SetStatus("Config dimuat. (" .. os.date("%H:%M:%S") .. ")")
                else
                    SetStatus("[!] Tidak ada config tersimpan / gagal load.")
                end
            end)
        end,
    })

    -- ─── TOMBOL: DELETE CONFIG (double-confirm) ───────────────────────────────
    -- Klik pertama = konfirmasi, klik kedua (dalam 5 detik) = hapus permanen dari folder.
    local _pendingDel   = false
    local _pendingTimer = nil

    ConfigTab:Button({
        Title    = "DELETE CONFIG",
        Desc     = "Klik sekali untuk konfirmasi, klik lagi untuk hapus permanen",
        Callback = function()
            if _pendingDel then
                if _pendingTimer then pcall(task.cancel, _pendingTimer) end
                _pendingDel   = false
                _pendingTimer = nil
                local ok = DeleteConfigByName(SINGLE_CONFIG_NAME)
                if ok then
                    SetStatus("Config dihapus permanen.")
                else
                    SetStatus("[!] Gagal hapus config (mungkin belum ada yang tersimpan).")
                end
            else
                _pendingDel = true
                SetStatus("[!] YAKIN hapus config? Klik DELETE CONFIG sekali lagi untuk konfirmasi. (auto-cancel 5 detik)")
                _pendingTimer = task.delay(5, function()
                    _pendingDel   = false
                    _pendingTimer = nil
                    SetStatus("Hapus dibatalkan (timeout).")
                end)
            end
        end,
    })

end -- end do PANEL CONFIG
