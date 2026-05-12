-- ASH Auto Farm - by FLa Project
do
 local _RS2 = game:GetService("ReplicatedStorage")
 local _LP2 = game:GetService("Players").LocalPlayer
 local _w = 0
 repeat
 task.wait(1); _w = _w + 1
 until (_RS2:FindFirstChild("Remotes") and _LP2.Character) or _w >= 15
 -- [v254] Kurangi fixed delay: 5s -> 2s (cukup untuk Delta Android)
 task.wait(2)
end

do
Players = game:GetService("Players")
TweenService = game:GetService("TweenService")
UserInputService = game:GetService("UserInputService")
RunService = game:GetService("RunService")
RS = game:GetService("ReplicatedStorage")
TeleportService = game:GetService("TeleportService")
GuiService = game:GetService("GuiService")
VIM = game:GetService("VirtualInputManager")

LP = Players.LocalPlayer
PG = LP.PlayerGui

-- ============================================================
-- [v232] UpdateCityRaidInfo listener dipindah ke SETELAH GUI load
-- (lihat ConnectUpdateCityRaidListener di bawah SwitchTab)
-- Variabel buffer tetap dideklarasi di sini agar tersedia global
-- ============================================================
CITY_TO_MAP_CONN = {[1000001]=3,[1000002]=7,[1000003]=10,[1000004]=13,[1000005]=18}

-- Forward declare siege snapshot functions (definisi ada di bawah setelah SIEGE table siap)

-- [v232] Placeholder: listener sesungguhnya dipasang setelah GUI load
-- Fungsi ini di-define ulang di bawah setelah SIEGE table siap
ConnectUpdateCityRaidListener = nil -- forward declare

-- [v232] GetCityRaidInfos sekarang dipanggil dari ConnectUpdateCityRaidListener
-- setelah GUI load + delay 5 detik (lihat di bawah SwitchTab)
end -- do globals

-- ============================================================
-- CLEANUP OLD GUI
-- ============================================================
for _, name in ipairs({"ASH_GUI", "ASH_NightFrost", "ASH_DD"}) do
 pcall(function()
 local old = PG:FindFirstChild(name)
 if old then old:Destroy() end
 end)
end


-- [v254] Loop wait duplikat dihapus - sudah ditangani di block pertama atas

-- ============================================================
-- REMOTES
-- ============================================================
Remotes = RS:WaitForChild("Remotes", 10)
if not Remotes then
 repeat task.wait(0.5) until RS:FindFirstChild("Remotes")
 Remotes = RS:FindFirstChild("Remotes")
end
RE = {
 CollectItem = Remotes:WaitForChild("CollectItem", 10),
 ExtraReward = Remotes:WaitForChild("ExtraReward", 10), -- [v112-FIX] WaitForChild agar tidak nil
 ShowReward = Remotes:FindFirstChild("ShowReward"),
 DropItems = Remotes:FindFirstChild("DropItems"),
 AutoHeroQuirk = Remotes:WaitForChild("AutoRandomHeroQuirk", 10),
 RandomHeroQuirk = Remotes:WaitForChild("RandomHeroQuirk", 10),
 Click = Remotes:FindFirstChild("ClickEnemy"),
 Atk = Remotes:FindFirstChild("PlayerClickAttackSkill"),
 Death = Remotes:FindFirstChild("EnemyDeath"),
 HeroMove = Remotes:FindFirstChild("HeroMoveToEnemyPos"),
 HeroStand = Remotes:FindFirstChild("HeroStandTo"),
 HeroSkill = Remotes:FindFirstChild("HeroPlaySkillAnim"),
 HeroUseSkill = Remotes:FindFirstChild("HeroUseSkill"),
 EquipWeapon = Remotes:WaitForChild("EquipWeapon", 10),
 RandomWeaponQuirk = Remotes:WaitForChild("RandomWeaponQuirk", 10),
 RandomHeroEquipGrade = Remotes:WaitForChild("RandomHeroEquipGrade", 10),
 RerollHalo = Remotes:FindFirstChild("RerollHalo"),
 RerollOrnament = Remotes:WaitForChild("RerollOrnament", 15),
 StartTp = Remotes:FindFirstChild("StartLocalPlayerTeleport"),
 LocalTp = Remotes:FindFirstChild("LocalPlayerTeleport"),
 CreateRaidTeam = Remotes:FindFirstChild("CreateRaidTeam"),
 StartChallengeRaidMap = Remotes:FindFirstChild("StartChallengeRaidMap"),
 EquipHeroWithData = Remotes:FindFirstChild("EquipHeroWithData"),
 LocalTpSuccess = Remotes:FindFirstChild("LocalPlayerTeleportSuccess"),
 GainRaidsRewards = Remotes:FindFirstChild("GainRaidsRewards"),
 UseRaidItem = Remotes:FindFirstChild("UseRaidItem"),

 GetDrawHeroId = Remotes:FindFirstChild("GetDrawHeroId"),
 GetRaidTeamInfos = Remotes:FindFirstChild("GetRaidTeamInfos"),
 UnEquipHero = Remotes:FindFirstChild("UnequipAllHero"),
 EquipBestHero = Remotes:FindFirstChild("AutoEquipBestHero"),
 DeleteWeapons = Remotes:FindFirstChild("DeleteWeapons"),
DecomposeItems = Remotes:FindFirstChild("DecomposeItems"),
}

-- [GODMODE v2] Global Instant Gold/Item Collector
-- FIX: Listen ke masing-masing folder (bukan workspace), karena gold/item jatuh ke dalam folder
-- FIX: Collect semua sekaligus (batch), tidak satu per satu
local _instantCollectConns = {}
local _instantCollected = {}

local function _collectObj(obj)
    local guid = obj:GetAttribute("GUID") or obj:GetAttribute("Guid") or obj:GetAttribute("guid")
    if not guid or _instantCollected[guid] then return end
    _instantCollected[guid] = true
    -- Teleport langsung ke player sebelum collect
    pcall(function()
        local char = LP.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
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
    -- Fire collect remote
    pcall(function() RE.CollectItem:InvokeServer(guid) end)
    if RE.ExtraReward then
        pcall(function() RE.ExtraReward:FireServer({isSell=true, guid=guid}) end)
    end
end

function StartInstantGoldCollector(on)
    -- Putuskan semua koneksi lama
    for _, c in ipairs(_instantCollectConns) do pcall(function() c:Disconnect() end) end
    _instantCollectConns = {}
    _instantCollected = {}

    if not on then return end

    local DROP_FOLDERS = {"Golds", "Items", "Drops", "Rewards", "Loot", "DropItems", "RewardItems"}

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

MY_USER_ID = LP.UserId
HERO_GUIDS, HERO_DATA = {}, {} -- hero data
-- { [heroGuid] = attackType } -- auto-populated via HeroUseSkill hook

-- HeroUseSkill capture: dilakukan via __namecall di SetupUniversalSpy (setelah 30s)
-- ExtraReward & GainRaidsRewards: dipanggil langsung di AttackLoop, tidak perlu hook

-- ============================================================
-- IsValidUUID
-- ============================================================
-- Versi diperkuat: Mengecek tipe data sebelum memproses match
function IsValidUUID(str)
    if type(str) ~= "string" then return false end -- [FIX] Cegah error jika tabel masuk
    return str:match("^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$")
end

-- ============================================================
-- WARNA
-- ============================================================
-- ============================================================
-- TEMA : Solo Leveling (1.lua T) - Dark Navy & Bright Accent + Glass
-- ============================================================
C = {
 -- Background & panel (maps to T.BgMain / BgContent / BgSidebar / TabHover)
 BG = Color3.fromRGB( 9,  11, 22),
 BG2 = Color3.fromRGB(13, 15, 32),
 BG3 = Color3.fromRGB(13, 15, 32),
 SURFACE = Color3.fromRGB(18, 28, 72),
 SURFACE2 = Color3.fromRGB(22, 32, 80),
 SIDEBAR = Color3.fromRGB(11, 13, 28),
 ACC = Color3.fromRGB(55, 105, 255),
 ACC2 = Color3.fromRGB(90, 145, 255),
 ACC3 = Color3.fromRGB(72, 125, 255),
 BORD = Color3.fromRGB(35,  55, 130),
 BORD2 = Color3.fromRGB(55, 105, 255),
 TXT = Color3.fromRGB(195, 210, 255),
 TXT2 = Color3.fromRGB(235, 242, 255),
 TXT3 = Color3.fromRGB( 90, 110, 170),
 TBAR = Color3.fromRGB( 7,  8, 18),
 SEL_BG = Color3.fromRGB(25, 45, 115),
 SEL_BORD = Color3.fromRGB(55, 105, 255),
 WIN_CLOSE= Color3.fromRGB(200,  50,  50),
 WIN_MIN = Color3.fromRGB(252, 211,  77),
 WIN_MAX = Color3.fromRGB(110, 231, 183),
 BLACK = Color3.fromRGB( 0, 0, 0),
 DD_BG = Color3.fromRGB(13, 15, 32),
 DD_HOVER = Color3.fromRGB(18, 28, 72),
 GRN = Color3.fromRGB( 25,  85,  25),
 RED = Color3.fromRGB(170,  35,  35),
 YEL = Color3.fromRGB(252, 211,  77),
 DIM = Color3.fromRGB( 90, 110, 170),
 DK = Color3.fromRGB(55, 105, 255),
 AG = Color3.fromRGB(55, 105, 255),
 ROW = Color3.fromRGB(18, 28, 72),
 NSEL = Color3.fromRGB(22, 32, 80),
 PILL_OFF = Color3.fromRGB(22, 32, 80),
 PILL_ON = Color3.fromRGB(25, 45, 115),
 KNOB_OFF = Color3.fromRGB( 90, 110, 170),
 KNOB_ON = Color3.fromRGB(235, 242, 255),
}

-- ============================================================
-- THEME SYSTEM CONFIGURATION
-- ============================================================
_G.CurrentTheme = "Solo Leveling"
_G.PotatoMode = false
_G.ThemeTransparency = 0.42
_G.DisableAnimations = false

local ThemePalettes = { 
    -- Batches 1-10 
    ["Solo Leveling"] = {BG = Color3.fromRGB(10, 15, 30), Accent = Color3.fromRGB(0, 200, 255), Text = Color3.fromRGB(255, 255, 255)}, 
    ["Naruto"] = {BG = Color3.fromRGB(0, 0, 0), Accent = Color3.fromRGB(255, 100, 0), Text = Color3.fromRGB(255, 0, 0)}, 
    ["Sasuke"] = {BG = Color3.fromRGB(20, 10, 30), Accent = Color3.fromRGB(100, 0, 255), Text = Color3.fromRGB(0, 220, 255)}, 
    ["One Piece"] = {BG = Color3.fromRGB(150, 0, 0), Accent = Color3.fromRGB(255, 215, 0), Text = Color3.fromRGB(0, 100, 255)}, 
    ["Demon Slayer"] = {BG = Color3.fromRGB(0, 50, 0), Accent = Color3.fromRGB(0, 0, 0), Text = Color3.fromRGB(100, 200, 255)}, 
    ["Dragon Ball"] = {BG = Color3.fromRGB(255, 120, 0), Accent = Color3.fromRGB(255, 255, 0), Text = Color3.fromRGB(0, 100, 255)}, 
    ["Transformer"] = {BG = Color3.fromRGB(0, 50, 200), Accent = Color3.fromRGB(200, 0, 0), Text = Color3.fromRGB(150, 150, 150)}, 
    ["God Of War"] = {BG = Color3.fromRGB(200, 200, 200), Accent = Color3.fromRGB(150, 0, 0), Text = Color3.fromRGB(215, 185, 0)}, 
    ["Devil May Cry"] = {BG = Color3.fromRGB(150, 0, 0), Accent = Color3.fromRGB(0, 0, 0), Text = Color3.fromRGB(200, 200, 200)}, 
    ["Tekken 5"] = {BG = Color3.fromRGB(10, 20, 50), Accent = Color3.fromRGB(255, 215, 0), Text = Color3.fromRGB(100, 100, 100)}, 
    -- Batches 11-20 
    ["GTA San Andreas"] = {BG = Color3.fromRGB(0, 100, 0), Accent = Color3.fromRGB(0, 0, 0), Text = Color3.fromRGB(255, 255, 255)}, 
    ["Final Fantasy X"] = {BG = Color3.fromRGB(50, 150, 255), Accent = Color3.fromRGB(255, 215, 0), Text = Color3.fromRGB(255, 255, 255)}, 
    ["NFS Underground 2"] = {BG = Color3.fromRGB(0, 255, 0), Accent = Color3.fromRGB(0, 0, 0), Text = Color3.fromRGB(255, 100, 0)}, 
    ["Windows 11"] = {BG = Color3.fromRGB(200, 220, 255), Accent = Color3.fromRGB(240, 240, 240), Text = Color3.fromRGB(100, 100, 100)}, 
    ["MacOS"] = {BG = Color3.fromRGB(200, 200, 200), Accent = Color3.fromRGB(0, 150, 255), Text = Color3.fromRGB(50, 50, 50)}, 
    ["Fortnite"] = {BG = Color3.fromRGB(0, 200, 255), Accent = Color3.fromRGB(150, 0, 255), Text = Color3.fromRGB(255, 255, 0)}, 
    ["CSGO"] = {BG = Color3.fromRGB(200, 200, 0), Accent = Color3.fromRGB(0, 100, 200), Text = Color3.fromRGB(80, 80, 80)}, 
    ["Roblox"] = {BG = Color3.fromRGB(200, 0, 0), Accent = Color3.fromRGB(0, 150, 255), Text = Color3.fromRGB(200, 200, 200)}, 
    ["Resident Evil"] = {BG = Color3.fromRGB(200, 0, 0), Accent = Color3.fromRGB(0, 150, 0), Text = Color3.fromRGB(0, 0, 0)}, 
    ["iPhone"] = {BG = Color3.fromRGB(180, 180, 180), Accent = Color3.fromRGB(80, 0, 150), Text = Color3.fromRGB(10, 10, 10)}, 
    -- Batches 21-30 
    ["Gojek"] = {BG = Color3.fromRGB(0, 180, 0), Accent = Color3.fromRGB(0, 0, 0), Text = Color3.fromRGB(255, 255, 255)}, 
    ["One Punch Man"] = {BG = Color3.fromRGB(255, 215, 0), Accent = Color3.fromRGB(255, 255, 255), Text = Color3.fromRGB(200, 0, 0)}, 
    ["Gundam"] = {BG = Color3.fromRGB(255, 255, 255), Accent = Color3.fromRGB(255, 215, 0), Text = Color3.fromRGB(0, 100, 255)}, 
    ["Jujutsu Kaisen"] = {BG = Color3.fromRGB(10, 10, 10), Accent = Color3.fromRGB(150, 0, 0), Text = Color3.fromRGB(150, 0, 255)}, 
    ["Nezuko"] = {BG = Color3.fromRGB(255, 182, 193), Accent = Color3.fromRGB(139, 0, 0), Text = Color3.fromRGB(139, 69, 19)}, 
    ["Rengoku Kyojuro"] = {BG = Color3.fromRGB(255, 215, 0), Accent = Color3.fromRGB(255, 100, 0), Text = Color3.fromRGB(255, 69, 0)}, 
    ["Kanroji Mitsuri"] = {BG = Color3.fromRGB(255, 182, 193), Accent = Color3.fromRGB(191, 255, 0), Text = Color3.fromRGB(255, 255, 255)}, 
    ["Tokito Muichiro"] = {BG = Color3.fromRGB(0, 128, 128), Accent = Color3.fromRGB(10, 10, 10), Text = Color3.fromRGB(180, 255, 220)}, 
    ["Shinazugawa Sanemi"] = {BG = Color3.fromRGB(85, 107, 47), Accent = Color3.fromRGB(255, 255, 255), Text = Color3.fromRGB(50, 50, 50)}, 
    ["Muzan"] = {BG = Color3.fromRGB(10, 10, 10), Accent = Color3.fromRGB(139, 0, 0), Text = Color3.fromRGB(255, 255, 255)} 
}

-- ============================================================
 -- UI HELPERS
 -- ============================================================
function SystemNotify(text, duration)
    local n = Instance.new("Frame", ScreenGui)
    n.Size = UDim2.new(0, 300, 0, 40)
    n.Position = UDim2.new(0.5, -150, 0, -50)
    n.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
    n.BackgroundTransparency = 0.1
    n.ZIndex = 1000
    
    local c = Instance.new("UICorner", n); c.CornerRadius = UDim.new(0, 8)
    local s = Instance.new("UIStroke", n ); s.Color = Color3.fromRGB(255, 100, 0); s.Thickness = 2
    
    local l = Instance.new("TextLabel", n)
    l.Size = UDim2.new(1, 0, 1, 0)
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = Color3.fromRGB(255, 255, 255)
    l.TextSize = 12
    l.Font = Enum.Font.GothamBold
    l.TextXAlignment = Enum.TextXAlignment.Center
    
    TweenService:Create(n, TweenInfo.new(0.5, Enum.EasingStyle.Back), {Position = UDim2.new(0.5, -150, 0.1, 20)}):Play()
    task.delay(duration or 3, function()
        TweenService:Create(n, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {Position = UDim2.new(0.5, -150, 0, -50), BackgroundTransparency = 1}):Play()
        task.delay(0.5, function() n:Destroy() end)
    end)
end

function New(class, props)
  local obj = Instance.new(class)
 for k, v in pairs(props) do pcall(function() obj[k] = v end) end
 return obj
end

function Frame(parent, color, size)
 return New("Frame", {
 Parent = parent, BackgroundColor3 = color,
 BackgroundTransparency = 0.42,
 Size = size or UDim2.new(1,0,1,0), BorderSizePixel = 0
 })
end

function Btn(parent, color, size)
 return New("TextButton", {
 Parent = parent, BackgroundColor3 = color,
 BackgroundTransparency = 0.2,
 Size = size or UDim2.new(1,0,1,0), BorderSizePixel = 0,
 Text = "", AutoButtonColor = false
 })
end

function Label(parent, text, size, color, font, xalign)
 return New("TextLabel", {
 Parent = parent, BackgroundTransparency = 1,
 Size = UDim2.new(1,0,1,0), Text = text, TextSize = size or 14,
 TextColor3 = color or C.TXT, Font = font or Enum.Font.Gotham,
 TextXAlignment = xalign or Enum.TextXAlignment.Left, BorderSizePixel = 0
 })
end

function Corner(obj, r)
 New("UICorner", {Parent = obj, CornerRadius = UDim.new(0, r or 10)})
end

function Stroke(obj, color, thickness, transparency)
 New("UIStroke", {
 Parent = obj, Color = color or C.BORD,
 Thickness = thickness or 1.5, Transparency = transparency or 0
 })
end

function Padding(obj, top, bottom, left, right)
 New("UIPadding", {
 Parent = obj,
 PaddingTop = UDim.new(0, top or 6),
 PaddingBottom = UDim.new(0, bottom or 6),
 PaddingLeft = UDim.new(0, left or 8),
 PaddingRight = UDim.new(0, right or 8),
 })
end

function ListLayout(parent, dir, align, spacing)
 return New("UIListLayout", {
 Parent = parent,
 FillDirection = dir or Enum.FillDirection.Vertical,
 HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
 SortOrder = Enum.SortOrder.LayoutOrder,
 Padding = UDim.new(0, spacing or 4),
 })
end

function GuiInsetY()
 local ok, y = pcall(function() return GuiService:GetGuiInset().Y end)
 return (ok and type(y) == "number") and y or 36
end

-- ============================================================
-- SCREEN GUI
-- ============================================================
ScreenGui = New("ScreenGui", {
 Parent = PG, Name = "ASH_NightFrost",
 ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
 DisplayOrder = 9999, IgnoreGuiInset = true,
 Active = false,
})

local _vp = workspace.CurrentCamera.ViewportSize
_isSmallScreen = _vp.X < 700
WIN_W = _isSmallScreen and math.min(math.floor(_vp.X * 0.96), 420) or 500
WIN_H = _isSmallScreen and math.min(math.floor(_vp.Y * 0.82), 380) or 360

Window = Frame(ScreenGui, C.BG, UDim2.new(0, WIN_W, 0, WIN_H))
Window.Position = UDim2.new(0.5, -WIN_W/2, 0.05, 0)
Window.ClipsDescendants = true
Window.Active = false
Corner(Window, 10)
Stroke(Window, C.BORD, 1.5, 0.88)
-- Glass rim (Solo Leveling accent)
New("UIStroke", { Color = C.ACC, Thickness = 1.5, Transparency = 0.65, Parent = Window })
-- ============================================================
Bubble = Btn(ScreenGui, C.TBAR, UDim2.new(0,58,0,58))
Bubble.Position = UDim2.new(0.5,-29,0,50)
Bubble.Visible = false
Bubble.ZIndex = 10
Corner(Bubble, 12) -- [v273] Rounded Square Style

do
 -- Solo Leveling glass bubble (accent gradient)
 local g = Instance.new("UIGradient", Bubble)
 g.Color = ColorSequence.new({
 ColorSequenceKeypoint.new(0, Color3.fromRGB( 25, 45, 115)),
 ColorSequenceKeypoint.new(0.55, Color3.fromRGB( 55, 105, 255)),
 ColorSequenceKeypoint.new(1, Color3.fromRGB( 90, 145, 255)),
 })
 g.Rotation = 135

 local s = Instance.new("UIStroke", Bubble)
 s.Color = Color3.fromRGB(130, 80, 255); -- [v273] Purple stroke (Premium Look)
 s.Thickness = 2
 s.Transparency = 0.1

 -- [v273 FIX: ULTRA COMPATIBILITY (rbxthumb)]
 local logo = Instance.new("ImageLabel", Bubble)
 logo.Name = "MainLogo"
 logo.Size = UDim2.new(0.7, 0, 0.7, 0)
 logo.Position = UDim2.new(0.15, 0, 0.15, 0)
 logo.BackgroundTransparency = 1
 logo.ZIndex = 25
 -- Gunakan rbxthumb agar Decal ID otomatis terbaca sebagai Image oleh Roblox
 logo.Image = "rbxthumb://type=Asset&id=133989674192597&w=420&h=420"
 logo.ImageColor3 = Color3.fromRGB(255, 255, 255)
 logo.ScaleType = Enum.ScaleType.Fit
 
 task.spawn(function()
     task.wait(2)
     if not logo.IsLoaded or logo.ContentImageSize == Vector2.new(0,0) then
         -- Fallback: Gunakan Headshot pemain jika ID tetap gagal (agar tidak blank hitam)
         local content, isReady = Players:GetUserThumbnailAsync(LP.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
         if isReady then  
         end
     end
 end)
end

-- Float Animation
function FloatBubble()
 task.spawn(function()
 local t = 0
 while Bubble.Visible do
 t = t + task.wait(0.03)
 local p = Bubble.Position
 Bubble.Position = UDim2.new(
 p.X.Scale, p.X.Offset,
 p.Y.Scale, p.Y.Offset + math.sin(t*2)*4 - math.sin((t-0.03)*2)*4
 )
 end
 end)
end

-- Drag Bubble
do
 local bd = false
 local bsm = Vector2.new()
 local bsp = Vector2.new()

 Bubble.InputBegan:Connect(function(i)
 if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
 bd = true
 bsm = Vector2.new(i.Position.X, i.Position.Y)
 bsp = Vector2.new(Bubble.AbsolutePosition.X, Bubble.AbsolutePosition.Y)
 end
 end)

 UserInputService.InputChanged:Connect(function(i)
 if bd and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
 local inset = GuiService:GetGuiInset()
 local vp = workspace.CurrentCamera.ViewportSize
 Bubble.Position = UDim2.new(
 0, math.clamp(bsp.X + (i.Position.X - bsm.X), 0, vp.X - 58),
 0, math.clamp(bsp.Y + (i.Position.Y - bsm.Y) - inset.Y, 0, vp.Y - 58)
 )
 end
 end)

 UserInputService.InputEnded:Connect(function(i)
 if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
 bd = false
 end
 end)
end

-- ============================================================
-- TOPBAR
-- ============================================================
function BuildTopBar()
 TopBar = Frame(Window, C.TBAR, UDim2.new(1,0,0,40))
 Corner(TopBar, 10)
 New("UIGradient", {
 Color = ColorSequence.new(
 C.ACC:Lerp(C.TBAR, 0.82),
 C.TBAR
 ),
 Rotation = 90,
 Parent = TopBar,
 })
 Stroke(TopBar, C.BORD, 1.5, 0.88)
 local TBFix = Frame(TopBar, C.TBAR, UDim2.new(1,0,0,14))
 TBFix.Position = UDim2.new(0,0,1,-14)

 -- [v239] Badge "AS" Night Frost style
 local IconBg = Frame(TopBar, C.ACC, UDim2.new(0,28,0,28))
 IconBg.Position = UDim2.new(0,8,0.5,-14)
 Corner(IconBg, 10); Stroke(IconBg, C.ACC, 1.5, 0.3)
 local IconLbl = Label(IconBg, "AS", 11, C.TXT, Enum.Font.GothamBold, Enum.TextXAlignment.Center)
 IconLbl.Size = UDim2.new(1,0,1,0)

 local TitleLbl = Label(TopBar, "Auto Farming ASH", 14, C.TXT, Enum.Font.GothamBold)
 TitleLbl.Size = UDim2.new(0,160,0,22); TitleLbl.Position = UDim2.new(0,44,0,5)
 local SubLbl = Label(TopBar, "by FLa Project", 11, C.TXT3, Enum.Font.Gotham)
 SubLbl.Size = UDim2.new(0,180,0,13); SubLbl.Position = UDim2.new(0,50,0,26)

 -- Buat tombol dengan posisi absolut (bukan anchor kanan)
 local function MkWinBtn(xPos, color, sym)
 local b = Btn(TopBar, color, UDim2.new(0,22,0,22))
 b.Position = UDim2.new(0, xPos, 0.5, -11)
 Corner(b, 11)
 local l = Label(b, sym, 12, Color3.fromRGB(255,255,255), Enum.Font.GothamBold, Enum.TextXAlignment.Center)
 l.Size = UDim2.new(1,0,1,0)
 return b
 end

 -- Minimize = kiri, Fullscreen = tengah, Close = kanan
 local BtnMin = MkWinBtn(WIN_W - 78, C.WIN_MIN, "-")
 local BtnMax = MkWinBtn(WIN_W - 52, C.WIN_MAX, "+")
 local BtnClose = MkWinBtn(WIN_W - 26, C.WIN_CLOSE, "x")

 -- Drag Window
 local dragging, dragStart, startPos = false, nil, nil
 TopBar.InputBegan:Connect(function(i)
 if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
 dragging = true; dragStart = i.Position; startPos = Window.Position
 end
 end)
 TopBar.InputEnded:Connect(function(i)
 if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
 dragging = false
 end
 end)
 UserInputService.InputChanged:Connect(function(i)
 if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
 local d = i.Position - dragStart
 Window.Position = UDim2.new(
 startPos.X.Scale, startPos.X.Offset + d.X,
 startPos.Y.Scale, startPos.Y.Offset + d.Y
 )
 end
 end)

 -- Show Bubble (minimize) - dari sc_baru
 function ShowBubble()
 Window.Visible = false
 local vp = workspace.CurrentCamera.ViewportSize
 Bubble.Position = UDim2.new(0, vp.X/2 - 29, 0, 50)
 Bubble.Size = UDim2.new(0,0,0,0)
 Bubble.Visible = true
 TweenService:Create(Bubble,
 TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
 {Size = UDim2.new(0,58,0,58)}
 ):Play()
 FloatBubble()
 end

 -- Show Window (restore) - dari sc_baru
 function ShowWin()
 TweenService:Create(Bubble,
 TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.In),
 {Size = UDim2.new(0,0,0,0)}
 ):Play()
 task.wait(0.19)
 Bubble.Visible = false
 Bubble.Size = UDim2.new(0,58,0,58)
 Window.Visible = true
 end

 BtnMin.MouseButton1Click:Connect(ShowBubble)
 Bubble.MouseButton1Click:Connect(ShowWin)

 -- Maximize tetap dari versi lama
 local isFS, prevSz, prevPs = false, Window.Size, Window.Position
 BtnMax.MouseButton1Click:Connect(function()
 isFS = not isFS
 if isFS then
 prevSz = Window.Size; prevPs = Window.Position
 TweenService:Create(Window, TweenInfo.new(0.2),
 {Size = UDim2.new(1,0,1,0), Position = UDim2.new(0,0,0,0)}):Play()
 else
 TweenService:Create(Window, TweenInfo.new(0.2),
 {Size = prevSz, Position = prevPs}):Play()
 end
 end)
 BtnClose.MouseButton1Click:Connect(function()
 -- [v243] Popup konfirmasi "Are you sure?" sebelum close GUI
 -- Cegah double-popup
 if ScreenGui:FindFirstChild("ASH_CloseConfirm") then return end

 local popupGui = New("Frame", {
 Parent = ScreenGui,
 Name = "ASH_CloseConfirm",
 Size = UDim2.new(0, 240, 0, 108),
 Position = UDim2.new(0.5, -120, 0.5, -54),
 BackgroundColor3 = C.BG2,
 BackgroundTransparency = 0.42,
 BorderSizePixel = 0,
 ZIndex = 200,
 })
 Corner(popupGui, 10)
 Stroke(popupGui, C.WIN_CLOSE, 1.5, 0)

 -- Judul
 local popTitle = New("TextLabel", {
 Parent = popupGui,
 Size = UDim2.new(1,0,0,36),
 Position = UDim2.new(0,0,0,0),
 BackgroundTransparency = 1,
 Text = " Are you Gay?",
 TextSize = 13,
 TextColor3 = C.WIN_CLOSE,
 Font = Enum.Font.GothamBold,
 TextXAlignment = Enum.TextXAlignment.Center,
 ZIndex = 201,
 })

 local popSub = New("TextLabel", {
 Parent = popupGui,
 Size = UDim2.new(1,-16,0,22),
 Position = UDim2.new(0,8,0,34),
 BackgroundTransparency = 1,
 Text = "all features will be reset.",
 TextSize = 10,
 TextColor3 = C.TXT3,
 Font = Enum.Font.Gotham,
 TextXAlignment = Enum.TextXAlignment.Center,
 TextWrapped = true,
 ZIndex = 201,
 })

 -- Tombol NO
 local btnNo = New("TextButton", {
 Parent = popupGui,
 Size = UDim2.new(0, 96, 0, 30),
 Position = UDim2.new(0, 12, 0, 66),
 BackgroundColor3 = C.SURFACE2,
 BackgroundTransparency = 0.2,
 BorderSizePixel = 0,
 Text = "NO",
 TextSize = 12,
 TextColor3 = C.TXT2,
 Font = Enum.Font.GothamBold,
 AutoButtonColor = false,
 ZIndex = 201,
 })
 Corner(btnNo, 10)
 Stroke(btnNo, C.BORD, 1.5, 0.5)

 -- Tombol YES
 local btnYes = New("TextButton", {
 Parent = popupGui,
 Size = UDim2.new(0, 96, 0, 30),
 Position = UDim2.new(0, 132, 0, 66),
 BackgroundColor3 = C.WIN_CLOSE,
 BackgroundTransparency = 0.2,
 BorderSizePixel = 0,
 Text = "YES",
 TextSize = 12,
 TextColor3 = Color3.fromRGB(255,255,255),
 Font = Enum.Font.GothamBold,
 AutoButtonColor = false,
 ZIndex = 201,
 })
 Corner(btnYes, 10)

 -- NO: tutup popup saja
 btnNo.MouseButton1Click:Connect(function()
 pcall(function() popupGui:Destroy() end)
 end)

 -- YES: stop semua fitur lalu destroy GUI
 btnYes.MouseButton1Click:Connect(function()
 pcall(function() popupGui:Destroy() end)
 -- [v238 FIX] Stop semua fitur sebelum destroy GUI
 pcall(function() if StopRaid then StopRaid() end end)
 pcall(function()
 if SIEGE then
 SIEGE.running = false
 SIEGE.inMap = false
 if SIEGE.thread then
 pcall(function() task.cancel(SIEGE.thread) end)
 SIEGE.thread = nil
 end
 end
 end)
 pcall(function()
 if MA then
 MA.running = false
 if MA.thread then
 pcall(function() task.cancel(MA.thread) end)
 MA.thread = nil
 end
 end
 end)
 -- Stop Merge Potion loop
 pcall(function()
 if _mergeRunning ~= nil then _mergeRunning = false end
 if _mergeThread ~= nil then
 pcall(function() task.cancel(_mergeThread) end)
 _mergeThread = nil
 end
 end)
 -- Stop Use Potion loop
 pcall(function()
 if _useRunning ~= nil then _useRunning = false end
 if _useThread ~= nil then
 pcall(function() task.cancel(_useThread) end)
 _useThread = nil
 end
 end)
 _raidOn = false
 _raidInterrupt = false
 _siegeInterrupt = false
 MODE.current = "idle" -- [v252] hard reset MODE dispatcher
 -- Destroy semua GUI ASH
 for _, gname in ipairs({"ASH_NightFrost","ASH_GUI","ASH_DD"}) do
 pcall(function()
 local g = LP.PlayerGui:FindFirstChild(gname)
 if g then g:Destroy() end
 end)
 end
 end)
 end)
end
BuildTopBar()

-- ============================================================
-- USER PROFILE SECTION (v273)
-- ============================================================
local function CreateUserProfile(parent)
    local profileFrame = Frame(parent, C.BLACK, UDim2.new(1, -12, 0, 50))
    profileFrame.Position = UDim2.new(0, 6, 1, -56)
    profileFrame.BackgroundTransparency = 0.8
    Corner(profileFrame, 8)
    
    local img = New("ImageLabel", {
        Parent = profileFrame,
        Size = UDim2.new(0, 36, 0, 36),
        Position = UDim2.new(0, 7, 0.5, -18),
        BackgroundColor3 = C.BLACK,
        BackgroundTransparency = 0.5,
        Image = "rbxassetid://0", -- Placeholder
        BorderSizePixel = 0
    })
    Corner(img, 18) -- Bulat sempurna
    New("UIStroke", {Parent = img, Color = C.ACC2, Thickness = 1, Transparency = 0.5})

    local nameLbl = Label(profileFrame, LP.DisplayName, 11, C.ACC2, Enum.Font.GothamBold, Enum.TextXAlignment.Left)
    nameLbl.Size = UDim2.new(1, -50, 0, 14)
    nameLbl.Position = UDim2.new(0, 50, 0, 10)
    nameLbl.TextTruncate = Enum.TextTruncate.AtEnd

    local userLbl = Label(profileFrame, "@"..LP.Name, 9, C.DIM, Enum.Font.GothamMedium, Enum.TextXAlignment.Left)
    userLbl.Size = UDim2.new(1, -50, 0, 12)
    userLbl.Position = UDim2.new(0, 50, 0, 24)
    userLbl.TextTruncate = Enum.TextTruncate.AtEnd

    local execName = "Unknown"
    pcall(function() execName = identifyexecutor() or "Executor" end)
    local idLbl = Label(profileFrame, "ID: "..LP.UserId.." | "..execName, 8, C.DIM, Enum.Font.GothamMedium, Enum.TextXAlignment.Left)
    idLbl.Size = UDim2.new(1, -50, 0, 10)
    idLbl.Position = UDim2.new(0, 50, 0, 36)
    idLbl.TextTransparency = 0.4
    idLbl.TextTruncate = Enum.TextTruncate.AtEnd

    -- Load Thumbnail asinkron
    task.spawn(function()
        local content, isReady = Players:GetUserThumbnailAsync(LP.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
        if isReady then img.Image = content end
    end)
end

-- ============================================================
-- BODY & SIDEBAR
-- ============================================================
local SIDEBAR_W = _isSmallScreen and 72 or 100

Body = Frame(Window, C.BG, UDim2.new(1,0,1,-44))
Body.Position = UDim2.new(0,0,0,44)
Body.Active = false

local SideBar = Frame(Body, C.SIDEBAR, UDim2.new(0, SIDEBAR_W, 1, 0))
local SideScroll = New("ScrollingFrame", {
 Parent = SideBar, Size = UDim2.new(1,0,1,-65), Position = UDim2.new(0,0,0,4),
 BackgroundTransparency = 1, BorderSizePixel = 0,
 ScrollBarThickness = _isSmallScreen and 4 or 2, ScrollBarImageColor3 = C.ACC,
 CanvasSize = UDim2.new(0,0,0,0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
})
ListLayout(SideScroll, nil, Enum.HorizontalAlignment.Center, 2)
Padding(SideScroll, 4, 4, 4, 4)

-- Render Profile Section di bawah SideBar
CreateUserProfile(SideBar)

ContentFrame = Frame(Body, C.BLACK, UDim2.new(1,-SIDEBAR_W,1,0))
ContentFrame.Position = UDim2.new(0, SIDEBAR_W, 0, 0)
ContentFrame.BackgroundTransparency = 1

-- ============================================================
-- TAB SYSTEM
-- ============================================================
local NAV_ITEMS = {
 {tag="main", ico="", lbl="Main"},
 {tag="hide", ico="", lbl="Hide"},
 {tag="farm", ico="", lbl="Farm"},
 {tag="attack", ico="", lbl="Attack"},
 {tag="autoraid", ico="", lbl="Automation"},
 {tag="player", ico="", lbl="Player"},
 {tag="autoroll", ico="", lbl="Reroll"},
 {tag="claim", ico="", lbl="Claim"},
 {tag="settings", ico="", lbl="Settings"},
 {tag="theme", ico="", lbl="Theme"},
}

Panels, NavRefs = {}, {}
ActiveTab = ""

function NewPanel(tag)
 local p = New("ScrollingFrame", {
 Parent = ContentFrame, Size = UDim2.new(1,0,1,0),
 BackgroundTransparency = 1, BorderSizePixel = 0,
 ScrollBarThickness = _isSmallScreen and 5 or 3,
 ScrollBarImageColor3 = C.ACC,
 CanvasSize = UDim2.new(0,0,0,0),
 AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = false,
 })
 ListLayout(p, nil, Enum.HorizontalAlignment.Center, 5)
 Padding(p, 10, 8, 10, 8)
 Panels[tag] = p; return p
end

function SwitchTab(tag)
 if ActiveTab == tag then return end
 ActiveTab = tag
 for t, p in pairs(Panels) do p.Visible = (t == tag) end
 for _, ref in ipairs(NavRefs) do
 local sel = ref.tag == tag
 -- Bubble selected: oranye solid + teks putih tebal
 -- Bubble unselected: oranye gelap semi-transparan + teks putih muda
 TweenService:Create(ref.bg, TweenInfo.new(0.15), {
 BackgroundTransparency = sel and 0.18 or 0.72,
 BackgroundColor3 = sel and C.SURFACE or C.BLACK,
 }):Play()
 ref.lbl.TextColor3 = sel and C.ACC2 or C.DIM
 ref.lbl.Font = sel and Enum.Font.GothamBold or Enum.Font.GothamBold
 local s = ref.bg:FindFirstChildWhichIsA("UIStroke")
 if sel then
 if not s then
 New("UIStroke", {Parent = ref.bg, Color = C.ACC2, Thickness = 1.5, Transparency = 0})
 else
 s.Color = C.ACC2; s.Thickness = 1.5; s.Transparency = 0
 end
 else
 if s then s:Destroy() end
 end
 end
end

for i, item in ipairs(NAV_ITEMS) do
 -- Bubble style: rounded pill, center text, no icon
 local bg = Btn(SideScroll, C.BLACK, UDim2.new(1,-6,0,32))
 bg.LayoutOrder = i
 bg.BackgroundTransparency = 1
 bg.AutoButtonColor = false
 Corner(bg, 10) -- Night Frost: slight round corners
 -- Dummy bar (tidak ditampilkan, tetap ada untuk kompatibilitas SwitchTab)
 local bar = Frame(bg, C.SIDEBAR, UDim2.new(0,0,0,0))
 bar.BackgroundTransparency = 1
 -- Label: full width, center aligned, tidak truncate
 local lblL = Label(bg, item.lbl, 11, C.DIM, Enum.Font.GothamBold, Enum.TextXAlignment.Center)
 lblL.Size = UDim2.new(1,0,1,0)
 lblL.Position = UDim2.new(0,0,0,0)
 lblL.TextScaled = false
 lblL.TextWrapped = false
 lblL.TextTruncate = Enum.TextTruncate.None
 -- Dummy ico label (kompatibilitas SwitchTab)
 local icoL = Label(bg, "", 1, C.TXT, Enum.Font.GothamBold, Enum.TextXAlignment.Center)
 icoL.Size = UDim2.new(0,0,0,0)
 icoL.BackgroundTransparency = 1
NavRefs[i] = {tag=item.tag, bg=bg, bar=bar, ico=icoL, lbl=lblL}
 bg.MouseButton1Click:Connect(function() SwitchTab(item.tag) end)
end

-- ============================================================
-- THEME ENGINE (VFX & COLORS)
-- ============================================================
local function CleanupVFX()
    for _, v in ipairs(Window:GetChildren()) do
        if v.Name == "VFX" or v:IsA("UIGradient") then
            v:Destroy()
        end
    end
end

local function SpawnVFXParticle(config)
    if _G.PotatoMode then return end
    local p = Instance.new("Frame")
    p.Name = "VFX"
    p.Size = config.Size or UDim2.fromOffset(4, 4)
    p.Position = config.StartPos
    p.BackgroundColor3 = config.Color
    p.BorderSizePixel = 0
    p.ZIndex = 10
    p.Parent = Window
    if config.Shape == "Circle" then Corner(p, 100) end
    if config.Rotation then p.Rotation = config.Rotation end

    local tween = TweenService:Create(p, TweenInfo.new(config.Duration, config.Easing or Enum.EasingStyle.Sine), {
        Position = config.EndPos,
        BackgroundTransparency = 1,
        Rotation = config.EndRotation or p.Rotation
    })
    tween:Play()
    tween.Completed:Connect(function() p:Destroy() end)
end

function ApplyTheme(name)
    local p = ThemePalettes[name]
    if not p then return end
    _G.CurrentTheme = name
    CleanupVFX()

    -- Phase 1: Color Tweens
    local ti = TweenInfo.new(0.6, Enum.EasingStyle.Exponential)
    TweenService:Create(Window, ti, {BackgroundColor3 = p.BG, BackgroundTransparency = _G.ThemeTransparency}):Play()
    
    -- Update UI Colors for future elements
    C.BG = p.BG; C.ACC = p.Accent; C.TXT = p.Text
    C.SURFACE = p.BG:Lerp(Color3.new(1,1,1), 0.05)
    C.ACC2 = p.Accent:Lerp(Color3.new(1,1,1), 0.2)
    C.DIM = p.Text:Lerp(p.BG, 0.4)

    -- Phase 2: VFX
    if _G.PotatoMode then return end
    
    task.spawn(function()
        local myTheme = name
        while _G.CurrentTheme == myTheme and not _G.PotatoMode do
            if name == "Rengoku Kyojuro" then
                if not Window:FindFirstChildWhichIsA("UIGradient") then
                    local g = Instance.new("UIGradient", Window)
                    g.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(255,0,0)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255,100,0)), ColorSequenceKeypoint.new(1, Color3.fromRGB(255,200,0))})
                    task.spawn(function() 
                        while _G.CurrentTheme == myTheme and g.Parent and not _G.PotatoMode do 
                            TweenService:Create(g, TweenInfo.new(1.5, Enum.EasingStyle.Linear), {Offset = Vector2.new(1, 0)}):Play()
                            task.wait(1.5)
                            g.Offset = Vector2.new(-1, 0)
                        end 
                    end)
                end
                SpawnVFXParticle({StartPos = UDim2.new(math.random(),0,1,0), EndPos = UDim2.new(math.random(),0,0,-50), Color = Color3.fromRGB(255,math.random(50,150),0), Size = UDim2.fromOffset(math.random(3,6),math.random(3,6)), Duration = math.random(1,2), Shape = "Circle"})
                task.wait(0.2)
            elseif name == "Nezuko" then
                SpawnVFXParticle({StartPos = UDim2.new(math.random(),0,-0.1,0), EndPos = UDim2.new(math.random()+0.2,0,1.1,0), Color = Color3.fromRGB(255,182,193), Size = UDim2.fromOffset(8,4), Duration = 4, Rotation = 45, EndRotation = 180})
                task.wait(0.5)
            elseif name == "Kanroji Mitsuri" then
                SpawnVFXParticle({StartPos = UDim2.new(math.random(),0,-0.1,0), EndPos = UDim2.new(math.random(),0,1.1,0), Color = math.random() > 0.5 and Color3.fromRGB(255,182,193) or Color3.fromRGB(191,255,0), Size = UDim2.fromOffset(6,6), Duration = 3, Shape = "Circle"})
                task.wait(0.4)
            elseif name == "Tokito Muichiro" then
                SpawnVFXParticle({StartPos = UDim2.new(-0.1,0,math.random(),0), EndPos = UDim2.new(1.1,0,math.random(),0), Color = Color3.fromRGB(0, 128, 128), Size = UDim2.fromOffset(math.random(20,50), 2), Duration = 5, BackgroundTransparency = 0.6})
                task.wait(0.8)
            elseif name == "Shinazugawa Sanemi" then
                SpawnVFXParticle({StartPos = UDim2.new(1.1,0,math.random(),0), EndPos = UDim2.new(-0.1,0,math.random()+0.2,0), Color = Color3.fromRGB(85, 107, 47), Size = UDim2.fromOffset(12, 2), Duration = 1.5, Rotation = math.random(-30,30)})
                task.wait(0.25)
            elseif name == "Muzan" then
                local b = Instance.new("Frame", Window); b.Name = "VFX"; b.Size = UDim2.fromOffset(15,15); b.Position = UDim2.new(math.random(),0,math.random(),0); b.BackgroundColor3 = Color3.fromRGB(139,0,0); b.BackgroundTransparency = 0.3; Corner(b, 10); TweenService:Create(b, TweenInfo.new(1.5), {Size = UDim2.fromOffset(0,0), BackgroundTransparency = 1, Rotation = 180}):Play(); task.delay(1.5, function() b:Destroy() end)
                task.wait(0.6)
            elseif name == "Naruto" then
                SpawnVFXParticle({StartPos = UDim2.new(math.random(),0,1,0), EndPos = UDim2.new(math.random(),0,0,-50), Color = Color3.fromRGB(255,100,0), Size = UDim2.fromOffset(5,5), Duration = 2, Shape = "Circle"})
                task.wait(0.4)
            elseif name == "Sasuke" then
                local l = Instance.new("Frame", Window); l.Name = "VFX"; l.Size = UDim2.new(0,2,0,math.random(40,120)); l.Position = UDim2.new(math.random(),0,math.random(),0); l.Rotation = math.random(0,360); l.BackgroundColor3 = Color3.fromRGB(100,200,255); l.BorderSizePixel = 0; l.ZIndex = 10; task.delay(0.1, function() l:Destroy() end)
                task.wait(math.random(0.5, 1.5))
            elseif name == "One Piece" then
                SpawnVFXParticle({StartPos = UDim2.new(math.random(),0,-0.1,0), EndPos = UDim2.new(math.random(),0,1.1,0), Color = Color3.fromRGB(255,215,0), Size = UDim2.fromOffset(6,6), Duration = 3, Shape = "Circle"})
                task.wait(0.5)
            elseif name == "Dragon Ball" then
                SpawnVFXParticle({StartPos = UDim2.new(math.random(),0,1,0), EndPos = UDim2.new(math.random(),0,0,-50), Color = Color3.fromRGB(255,255,0), Size = UDim2.fromOffset(4,15), Duration = 1, Easing = Enum.EasingStyle.Exponential})
                task.wait(0.2)
            elseif name == "One Punch Man" then
                SpawnVFXParticle({StartPos = UDim2.new(0.5,0,0.5,0), EndPos = UDim2.new(math.random(),0,math.random(),0), Color = Color3.fromRGB(255,0,0), Size = UDim2.fromOffset(10,2), Duration = 0.5, Easing = Enum.EasingStyle.Quad})
                task.wait(0.1)
            elseif name == "Jujutsu Kaisen" then
                local b = Instance.new("Frame", Window); b.Name = "VFX"; b.Size = UDim2.fromOffset(20,20); b.Position = UDim2.new(math.random(),0,math.random(),0); b.BackgroundColor3 = Color3.fromRGB(150,0,255); b.BackgroundTransparency = 0.5; Corner(b, 10); TweenService:Create(b, TweenInfo.new(1), {Size = UDim2.fromOffset(0,0), BackgroundTransparency = 1}):Play(); task.delay(1, function() b:Destroy() end)
                task.wait(0.8)
            elseif name == "Zenitsu" or name == "Demon Slayer" then
                local l = Instance.new("Frame", Window); l.Name = "VFX"; l.Size = UDim2.new(math.random(),0,0,1); l.Position = UDim2.new(0,0,math.random(),0); l.BackgroundColor3 = Color3.fromRGB(255,255,0); task.delay(0.1, function() l:Destroy() end)
                task.wait(1.5)
            elseif name == "Windows 11" or name == "MacOS" or name == "iPhone" then
                if not Window:FindFirstChildWhichIsA("UIGradient") then
                    local g = Instance.new("UIGradient", Window)
                    g.Color = ColorSequence.new(p.BG, p.Accent)
                    task.spawn(function() while _G.CurrentTheme == myTheme and g.Parent do TweenService:Create(g, TweenInfo.new(5, Enum.EasingStyle.Sine), {Offset = Vector2.new(0.5, 0)}):Play(); task.wait(5); TweenService:Create(g, TweenInfo.new(5, Enum.EasingStyle.Sine), {Offset = Vector2.new(-0.5, 0)}):Play(); task.wait(5) end end)
                end
                task.wait(2)
            else
                -- Generic Flowing Gradient for all other themes
                if not Window:FindFirstChildWhichIsA("UIGradient") then
                    local g = Instance.new("UIGradient", Window)
                    g.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, p.BG), ColorSequenceKeypoint.new(0.5, p.Accent), ColorSequenceKeypoint.new(1, p.BG)})
                    task.spawn(function() while _G.CurrentTheme == myTheme and g.Parent do TweenService:Create(g, TweenInfo.new(4, Enum.EasingStyle.Linear), {Rotation = 360}):Play(); task.wait(4); g.Rotation = 0 end end)
                end
                task.wait(1)
            end
        end
    end)
end

-- ============================================================
-- PANEL HELPERS
-- ============================================================
function SectionHeader(panel, title, order)
 local f = Frame(panel, C.BLACK, UDim2.new(1,0,0,20))
 f.BackgroundTransparency = 1; f.LayoutOrder = order or 0
 local l = Label(f, " "..title, 13, C.TXT, Enum.Font.GothamBold)
 l.Size = UDim2.new(1,0,1,0)
 local line = Frame(f, C.ACC, UDim2.new(1,0,0,1))
 line.Position = UDim2.new(0,0,1,-1); line.BackgroundTransparency = 0.42
end

function ToggleRow(panel, title, desc, order, onToggle)
 local row = Frame(panel, C.SURFACE, UDim2.new(1,0,0,44))
 row.LayoutOrder = order or 1; Corner(row, 10); Stroke(row, C.BORD, 1.5, 0.88)
 local lbl = Label(row, title, 13, C.TXT, Enum.Font.GothamBold)
 lbl.Size = UDim2.new(1,-68,0,20); lbl.Position = UDim2.new(0,14, 0.5, -10)
 local pill = Btn(row, C.PILL_OFF, UDim2.new(0,52,0,30))
 pill.AnchorPoint = Vector2.new(1, 0.5)
 pill.Position = UDim2.new(1,-12,0.5,0); Corner(pill, 15)
 local knob = Frame(pill, C.KNOB_OFF, UDim2.new(0,24,0,24))
 knob.AnchorPoint = Vector2.new(0, 0.5)
 knob.Position = UDim2.new(0,3,0.5,0); Corner(knob, 12)
 local state = false
 local function SetVisual(v)
  -- Update pill visual ONLY, tanpa trigger onToggle
  state = v
  TweenService:Create(pill, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {BackgroundColor3 = v and C.PILL_ON or C.PILL_OFF}):Play()
  TweenService:Create(knob, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {
   Position = v and UDim2.new(1,-27,0.5,0) or UDim2.new(0,3,0.5,0),
   BackgroundColor3 = v and C.KNOB_ON or C.KNOB_OFF,
  }):Play()
 end
 local function SetState(v)
  SetVisual(v)
  if onToggle then onToggle(v) end
 end
 pill.MouseButton1Click:Connect(function() SetState(not state) end)
 return row, SetState, SetVisual
end

function SliderRow(panel, title, min, max, default, onMove)
    local row = Frame(panel, C.SURFACE, UDim2.new(1,0,0,52))
    row.LayoutOrder = 1; Corner(row, 10); Stroke(row, C.BORD, 1.5, 0.88)
    local lbl = Label(row, title, 13, C.TXT, Enum.Font.GothamBold)
    lbl.Size = UDim2.new(1,-20,0,20); lbl.Position = UDim2.new(0,14, 0, 6)
    
    local bar = Frame(row, C.BLACK, UDim2.new(1,-28,0,6))
    bar.Position = UDim2.new(0.5,0,0,36); bar.AnchorPoint = Vector2.new(0.5,0)
    Corner(bar, 3)
    
    local fill = Frame(bar, C.ACC, UDim2.new((default-min)/(max-min), 0, 1, 0))
    Corner(fill, 3)
    
    local knob = Btn(bar, C.TXT, UDim2.new(0,14,0,14))
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.Position = UDim2.new((default-min)/(max-min), 0, 0.5, 0)
    Corner(knob, 7)
    
    local valLbl = Label(row, tostring(default), 11, C.DIM, Enum.Font.GothamBold, Enum.TextXAlignment.Right)
    valLbl.Position = UDim2.new(1,-25,0,6)

    local dragging = false
    local function Update(input)
        local pos = math.clamp((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        knob.Position = UDim2.new(pos, 0, 0.5, 0)
        fill.Size = UDim2.new(pos, 0, 1, 0)
        local val = math.floor(min + (pos * (max - min)))
        valLbl.Text = tostring(val)
        if onMove then onMove(val) end
    end
    
    knob.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            Update(input)
        end
    end)
    -- SetValue: restore slider ke nilai tertentu tanpa input event
    local function SetValue(val)
        val = math.clamp(val, min, max)
        local pos = (val - min) / (max - min)
        knob.Position = UDim2.new(pos, 0, 0.5, 0)
        fill.Size = UDim2.new(pos, 0, 1, 0)
        valLbl.Text = tostring(val)
        if onMove then onMove(val) end
    end
    return row, SetValue
end

-- ============================================================
-- STATE & LOOPS
-- ============================================================
STATE = {autoCollect=false, autoCollectGoldItem=false, autoDestroyer=false, autoArise=false, noClip=false, antiAfk=false, autoConfirm=false, autoClose=false}
LOOPS, COLLECTED = {}, {}

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

MA = {running=false, thread=nil, killed=0, killTarget=7, autoCollect=true}
AG = {running=false, thread=nil, killed=0, collected=0, currentTarget=nil, autoCollect=true}

-- RAID STATE
RAID = {
 running = false,
 inMap = false, -- true saat karakter sedang di dalam map raid
 thread = nil,
 sukses = 0, -- counter raid berhasil (masuk+bunuh bos+ambil reward)
 collected = 0,
 raidId = 0,
 raidMapId = 50001,
 slotIndex = 2, -- dapat dari EnterRaidsUpdateInfo
 fromMapId = nil, -- [v203] map asal sebelum masuk raid (dari EnterRaidsUpdateInfo)
 serverMapId = nil, -- [v172] mapId aktual dari EnterRaidsUpdateInfo server
 _raidDone = false, -- true saat ChallengeRaidsSuccess/Fail fire

 statusLbl = nil,
 suksesLbl = nil, -- label UI sukses (ganti killLbl/loopLbl)
 dot = nil,
 -- Difficulty & preferred maps
 difficulty = "easy", -- "easy" | "hard" (via PM_TO_DIFF)
 preferMaps = {}, -- set: {[mapNumber]=true} (1..18)
 runeGrades = {}, -- [v114] Rune Map: set grade aktif {["M++"]=true, ...}
 runeEnabled = false, -- [V147] Toggle utama Rune Map (grade + pindah)
 runeMapTarget = 0, -- [V147] Map tujuan Rune Map Pindah (1-18), 0 = nonaktif
 updownEnabled = false, -- UP/DOWN Rank: fire UseRaidItem setelah masuk raid byrank
 updownDir = "up", -- "up" = UseRaidItem(10270) | "down" = UseRaidItem(10271)
 diffLbl = nil, -- label UI difficulty
 snapshotMapId = nil, -- mapId hasil jepretan sesuai difficulty saat ini
}
_raidOn = false

-- ============================================================
-- AUTO ASCENSION STATE TABLE
-- ============================================================
ASC = {
 running  = false,
 inMap    = false,
 thread   = nil,
 sukses   = 0,
 pickMode = "easy",   -- "easy" | "hard" | "default" | "byrank" | "bymap" | "manual"
 preferMaps    = {},    -- [v48] map filter (mapNum -> true), sama seperti RAID.preferMaps
 runeGrades    = {},    -- filter grade (Preferred Rank)
 runeEnabled      = false, -- rune map item aktif (ASC Tower 1-26)
 runeMapTarget    = 0,     -- target Tower rune (1-26), 0 = nonaktif
 preferMapTarget  = 0,     -- [PREFERRED MAP] target Tower pilihan (1-26), 0 = nonaktif
 manualMatchMode   = "none", -- [v48] "primary" | "fallback" | "none"
 _rrIdx            = 0,      -- [v48] Round-robin index untuk Pick Mode Default
 autoKillBoss = false, -- AUTO BOSS KILL toggle
 bossDelay    = 3,     -- delay sebelum TP ke boss (1-10s)
 statusLbl = nil,
 dot       = nil,
 suksesLbl = nil,
}
_ascOn = false
_ascWakeup = nil -- BindableEvent untuk wakeup loop
_visAscension = nil -- visual pill toggle
_ascBusy = false -- true selama ASC inMap ATAU cooldown -> RAID pause total
_ASC_CHAT_CACHE = {} -- [mapNum] = {grade, bossName} dari chat parser; dipakai ParseRaidEntry
-- [v56 DEPRECATED] _ascDominatedThisEvent tidak dipakai lagi
-- Logika baru: RAID standby selama ASC.running=true DAN ResolveAscEntry()~=nil
-- RAID boleh jalan HANYA kalau ResolveAscEntry()=nil (tidak ada Tower match di event saat ini)
_ascDominatedThisEvent = false -- tetap ada agar tidak crash referensi lama

-- [v61 CYCLEFIX] Tracking siklus event server (~5m5s aktif + ~5m cooldown)
-- _ascMatchedThisCycle: true jika ASC sudah match/masuk di siklus event ini
--   -> RAID harus tunggu sampai RAID_LIVE benar-benar kosong (event habis) sebelum boleh jalan
-- _raidFallbackActive: true jika RAID sedang fallback (ASC tidak match di siklus ini)
--   -> ASC harus standby, tidak boleh "nyuri" RAID sampai siklus event baru datang dari server
_ascMatchedThisCycle  = false  -- ASC pernah match di siklus event saat ini
_raidFallbackActive   = false  -- RAID sedang jalan sebagai fallback (ASC tidak match siklus ini)

-- [v62 RINO/RINI FIX] Siapa yang "dipanggil" di siklus event ini.
-- Diset oleh TriggerEntryWakeup() berdasarkan evaluasi RAID_LIVE sebelum wakeup dikirim.
-- "asc"  = ada Tower match + ASC ON  -> hanya ASC yang bangun, RAID tetap duduk
-- "raid" = tidak ada Tower / ASC OFF -> hanya RAID yang bangun, ASC tetap duduk
-- nil    = belum ada keputusan (initial state atau sedang cooldown)
_eventOwner = nil

-- [v55 FIX] Mapping Ascension Tower: Tower X -> mapId = 50300 + X
-- Data confirmed: Tower 1=50301, Tower 2=50302, ..., Tower 26=50326
-- Formula langsung, tidak bergantung nama boss (yang bisa berubah setiap event)
-- ASC_BOSS_MAP dihapus - diganti formula ResolveAscTargetMapId(mapNum)
local function ResolveAscTargetMapId(mapNum)
 -- mapNum = nomor Tower (1-26) dari chat "Ascension Tower X"
 -- Return: mapId untuk StartLocalPlayerTeleport (50301-50326)
 if not mapNum or mapNum < 1 or mapNum > 26 then return 50301 end
 return 50300 + mapNum
end

-- Pre-deklarasi variabel expose antar-block (diisi saat masing-masing block UI terbentuk)
_setSiegeToggle     = nil  -- diisi oleh Auto Siege ToggleRow
_setDungeonToggle   = nil  -- diisi oleh Auto Dungeon ToggleRow
_siegeItemRefs      = nil  -- diisi oleh Siege exclude-map UI
_updateSiegeDdLabel = nil  -- diisi oleh Siege exclude-map UI
_siegeToggleState   = false -- tracking state pill toggle Siege (true=ON)
_dungeonToggleState = false -- tracking state pill toggle Dungeon (true=ON)
-- Global Config - expose setter dari setiap panel
_setAutoHideToggle  = nil  -- Main: Auto Hide Reward
_setAutoCollectToggle = nil -- Main: Auto Collect GOLD & ITEM
_setAnimToggle      = nil  -- Main: Disable All Animations
_setSellHeroToggle  = nil  -- Main: Auto Sell Hero Equip
_autoSellWeaponSet  = nil  -- Main: Auto Sell Weapon toggle setter
_swSelectAllState   = true -- Main: Auto Sell Weapon selectAll state
_autoSellOnState       = false -- tracking _autoSellOn (Main)
_autoSellWeaponState   = false -- tracking _autoSellWeaponOn (Main)
_autoDecompGemState    = false -- tracking _autoDecompGemOn (Main)
_mergeRunningState     = false -- tracking _mergeRunning (AutoRoll)
_useRunningState       = false -- tracking _useRunning (AutoRoll)
_raRunningState        = false -- tracking RA.running (Farm)
_autoDecompGemSet   = nil  -- Main: Auto Decompose Gem toggle setter
_gemMaxLevelState   = 9    -- Main: Gem max level slider value
_setRAToggle        = nil  -- Farm: Random Attack
_setMaToggleGlobal  = nil  -- Attack: Mass Attack
_setKillDDGlobal    = nil  -- Attack: Kill Target DD
_setDelayDDGlobal   = nil  -- Attack: Delay DD
_maMapSelState      = nil
_setNoClipToggle    = nil  -- Player: No Clip
_setAntiAfkToggle   = nil  -- Player: Anti AFK
_walkSpeedState     = 16   -- Player: WalkSpeed value
_setMergeToggle     = nil  -- AutoRoll: Merge Potion
_setUseToggle       = nil  -- AutoRoll: Use Potion
_setPotatoToggle    = nil  -- Settings: Potato Mode
_webhookModeSetIdx  = nil  -- Settings: webhook mode setter
_webhookUrlBox      = nil  -- Settings: urlBox reference untuk restore text
-- Visual-only setters (update pill tanpa trigger logic - untuk restore UI saat load config)
_visAutoHide    = nil  -- Main: Auto Hide Reward visual
_visAutoCollect = nil  -- Main: Auto Collect GOLD & ITEM visual
_visDisableAnim = nil  -- Main: Disable Anim visual
_visSellHero    = nil  -- Main: Sell Hero visual
_visRandomAtk   = nil  -- Farm: Random Attack visual
_visMassAtk     = nil  -- Attack: Mass Attack visual
_visNoClip      = nil  -- Player: No Clip visual
_visAntiAfk     = nil  -- Player: Anti AFK visual
_visMerge       = nil  -- AutoRoll: Merge Potion visual
_visUse         = nil  -- AutoRoll: Use Potion visual
_visSiege       = nil  -- Automation: Siege visual
_visDungeon     = nil  -- Automation: Dungeon visual
_visST2         = nil  -- Automation: ST2 visual
_visPotato      = nil  -- Settings: Potato Mode visual
_visWeaponSell  = nil  -- Main: Auto Sell Weapon visual (manual pill)
_visDecompGem   = nil  -- Main: Auto Decomp Gem visual (manual pill)
_setTransSlider = nil  -- Theme: UI Transparency slider setter
_visWebhookToggle = nil  -- Settings: Webhook toggle visual
_setWebhookToggle = nil  -- Settings: Webhook toggle logic
_setSpeedSlider = nil  -- Player: WalkSpeed slider setter
_setGemLevelSlider = nil -- Main: Gem Level slider setter

-- ============================================================
-- [v252] MODE DISPATCHER - Single source of truth
-- ============================================================
MODE = {
 current = "idle", -- "idle"|"ma"|"raid"|"siege"|"dungeon"|"asc"|"st2"
 -- PRIORITY: dungeon > siege > raid > asc > st2 > ma > idle
 -- Fitur HANYA boleh masuk jika MODE.current == "idle"
 -- (tidak ada override priority â€” setiap fitur harus tunggu giliran)
 priority = { dungeon=6, siege=5, raid=4, asc=3, st2=2, ma=1, idle=0 },
 _prev = {}, -- stack: simpan mode yang diinterrupt, untuk resume
}

function MODE:_p(name)
 return self.priority[name] or 0
end

function MODE:IsHigherPriority(incoming)
 return self:_p(incoming) > self:_p(self.current)
end

-- Request: boleh masuk kalau slot kosong ATAU priority lebih tinggi
function MODE:Request(name)
 if self.current == "idle" or self:IsHigherPriority(name) then
 self.current = name
 return true
 end
 return false
end

-- Release: hanya release kalau kamu yang pegang
function MODE:Release(name)
 if self.current == name then
 self.current = "idle"
 end
end

-- ForceSet: override tanpa cek (untuk dungeon yang priority max)
function MODE:ForceSet(name)
 self.current = name
end

-- WaitAndRequest: tunggu sampai bisa masuk (timeout detik)
-- Kembalikan true kalau berhasil, false kalau timeout
function MODE:WaitAndRequest(name, timeout)
 local t = 0
 local limit = timeout or 30
 while not self:Request(name) and t < limit do
 task.wait(0.5); t = t + 0.5
 end
 return self.current == name
end

--  Alias getter (baca-saja) 
-- ============================================================

-- ============================================================
-- [GUARD SYSTEM v50] Helper global: cek apakah ada fitur lain sedang di dalam map
-- Dipakai oleh SEMUA fitur sebelum join map apapun
-- ============================================================

-- [v52 FIX] Atomic map-enter lock untuk cegah race condition RAID vs ASC
-- Ketika dua fitur lolos guard bersamaan (keduanya lihat inMap=false),
-- hanya yang pertama klaim lock ini yang boleh masuk map.
-- Format: nil = bebas, "raid" / "asc" / "siege" / "dungeon" = sedang diklaim
_MAP_ENTER_LOCK = nil
_MAP_ENTER_LOCK_TIME = 0

-- Coba klaim lock. Return true jika berhasil (boleh lanjut masuk map).
-- featureName: "raid" | "asc" | "siege" | "dungeon"
-- Timeout 30 detik: jika lock pemilik sebelumnya tidak release > 30s, paksa reset.
function TryClaimMapLock(featureName)
 local now = os.clock()
 if _MAP_ENTER_LOCK == nil or _MAP_ENTER_LOCK == featureName then
  _MAP_ENTER_LOCK = featureName
  _MAP_ENTER_LOCK_TIME = now
  return true
 end
 -- Cek timeout: jika pemilik lock sudah > 30 detik tidak release, paksa ambil
 if (now - _MAP_ENTER_LOCK_TIME) > 30 then
  _MAP_ENTER_LOCK = featureName
  _MAP_ENTER_LOCK_TIME = now
  return true
 end
 return false
end

-- Release lock (panggil setelah inMap=false di-set atau setelah keluar map)
function ReleaseMapLock(featureName)
 if _MAP_ENTER_LOCK == featureName then
  _MAP_ENTER_LOCK = nil
  _MAP_ENTER_LOCK_TIME = 0
 end
end

function IsAnyMapActive()
 -- Cek semua state inMap secara independen (tidak rely on MODE.current)
 if RAID and RAID.inMap then return true, "raid" end
 if ASC and ASC.inMap then return true, "asc" end
 if SIEGE and SIEGE.inMap then return true, "siege" end
 if DUNGEON and DUNGEON.inMap then return true, "dungeon" end
 if DUNGEON and DUNGEON.interrupt then return true, "dungeon" end
 if ST2 and ST2.inMap then return true, "st2" end
 -- [v52 FIX] Cek juga atomic lock - fitur lain sedang dalam proses masuk map
 if _MAP_ENTER_LOCK ~= nil then return true, _MAP_ENTER_LOCK end
 return false, nil
end

-- Tunggu sampai tidak ada fitur lain di dalam map (timeout detik)
-- featureName: nama fitur yang lagi nunggu (untuk log)
function WaitUntilIdle(featureName, timeout)
 local t = 0
 local limit = timeout or 60
 while t < limit do
  local active, who = IsAnyMapActive()
  if not active then return true end
  task.wait(0.5); t = t + 0.5
 end
 return false
end

-- ============================================================
-- [GUARD SYSTEM v50] GetEnemiesLocal(folder_hint)
-- Setiap fitur baca musuh SENDIRI dari workspace.Enemys
-- Tidak ada shared state antar fitur
-- ============================================================
local ENEMY_FOLDERS_ALL = {"Enemys","EnemyCityRaid","CityRaidEnemys","Enemies","Enemy"}
function GetEnemiesLocal()
 local list = {}
 local seen = {}
 for _, fname in ipairs(ENEMY_FOLDERS_ALL) do
  local f = workspace:FindFirstChild(fname)
  if f then
   for _, e in ipairs(f:GetChildren()) do
    if e:IsA("Model") then
     local g = e:GetAttribute("EnemyGuid") or e:GetAttribute("BossGuid") or e:GetAttribute("Guid") or e:GetAttribute("GUID")
     local h = e:FindFirstChild("HumanoidRootPart")
           or e.PrimaryPart
           or e:FindFirstChild("Torso")
           or e:FindFirstChild("UpperTorso")
           or e:FindFirstChildWhichIsA("BasePart")
     local hum = e:FindFirstChildOfClass("Humanoid")
     if g and h and hum and hum.Health > 0 and not seen[g] then
      seen[g] = true
      table.insert(list, {model=e, guid=g, hrp=h})
     end
    end
   end
  end
 end
 -- Fallback: scan workspace langsung kalau folder kosong
 if #list == 0 then
  for _, obj in ipairs(workspace:GetChildren()) do
   if obj:IsA("Model") then
    local g = obj:GetAttribute("EnemyGuid") or obj:GetAttribute("BossGuid") or obj:GetAttribute("Guid") or obj:GetAttribute("GUID")
    local h = obj:FindFirstChild("HumanoidRootPart")
          or obj.PrimaryPart
          or obj:FindFirstChild("Torso")
          or obj:FindFirstChild("UpperTorso")
          or obj:FindFirstChildWhichIsA("BasePart")
    local hum = obj:FindFirstChildOfClass("Humanoid")
    if g and h and hum and hum.Health > 0 and not seen[g] then
     seen[g] = true
     table.insert(list, {model=obj, guid=g, hrp=h})
    end
   end
  end
 end
 return list
end

_raidInterrupt = false -- true saat raid muncul & Mass Attack harus pause
_ascInterrupt  = false -- true sesaat sebelum ASC masuk tower -> MA pause (mirip _raidInterrupt)
local _lastBossGuid = nil -- guid boss terakhir untuk ExtraReward auto-claim
_siegeInterrupt = false -- true saat siege pakai remote -> raid pause
local _gainRaidsLock = false -- flag cegah infinite loop di hook GainRaidsRewards
_webhookEnabled = false
_webhookUrl = ""
_whSilent = false -- true saat scan history awal (jangan fire webhook duplikat)


RAID.autoKillBoss = false -- toggle: teleport ke raja + auto attack sampai mati
RAID.ascensionMode = false -- [DEPRECATED] tetap ada agar tidak crash referensi lama
RAID.bossDelay = 3 -- detik delay sebelum TP ke boss (1-10, user-controlled)

_maStatusLbl, _noClipConn, _antiAfkThread, _antiAfkStart = nil, nil, nil, nil
local _deadG, _mOn, _agOn, _tgtThread = {}, false, false, nil
local _activeTbnRow = nil -- [v188-FIX] track row tbn yang sedang aktif
local ORIGIN_POS, _destroyerConn, _ariseConn = Vector3.new(0,0,0), nil, nil
local StatusDots, StatusLbls = {}, {}

-- ============================================================
-- MAPS
-- ============================================================
local MAPS = {}
for i = 1, 20 do
 MAPS[i] = {name="Map "..i, id=50000+i, remote=i<=4 and "Start" or "Local"}
end
MR = {selected={}, nextMapDelay=3, teleportDelay=3}

function TpMap(m)
 MR.lastMapId = m.id -- simpan map terakhir sebelum masuk raid
 if m.remote == "Start" then
 pcall(function() RE.StartTp:FireServer({mapId=m.id}) end)
 else
 pcall(function() RE.LocalTp:FireServer({mapId=m.id}) end)
 end
end

-- ============================================================
-- SKILL KEYS
-- ============================================================
SKL = {
 Z={on=false,t=nil,label="Z"},
 X={on=false,t=nil,label="X"},
 C={on=false,t=nil,label="C"},
 V={on=false,t=nil,label="V"},
 F={on=false,t=nil,label="F"},
 type_map = {Z=1,X=2,C=3,V=4,F=5},
 key_map = {Z=Enum.KeyCode.Z,X=Enum.KeyCode.X,C=Enum.KeyCode.C,V=Enum.KeyCode.V,F=Enum.KeyCode.F},
 ui = {},
}
-- SKL_TYPE, SKL_KEY, SKL_UI merged into SKL table below
-- Simulasi tekan tombol keyboard via VirtualInputManager (sama seperti script lama)
function PK(k)
 pcall(function()
 VIM:SendKeyEvent(true, k, false, game)
 task.wait(0.05)
 VIM:SendKeyEvent(false, k, false, game)
 end)
end

-- Referensi tombol UI skill (diisi saat panel dibuat)
-- SKL_UI merged into SKL table

function SkFireOnce(n)
 -- Simulasi tekan tombol Z/X/C/V/F langsung via VirtualInputManager
 -- Sama persis seperti player menekan tombol sendiri - tidak butuh enemyGuid
 PK(SKL.key_map[n])
end

function SkSetUI(n, on)
 local u = SKL.ui[n]
 if not u then return end
 -- ON: latar oranye terang, teks warna skill
 -- OFF: latar oranye gelap (C.BG3), teks putih
 u.btn.BackgroundColor3 = on and Color3.fromRGB(180,65,5) or C.BG3
 u.lbl.Text = on and "ON" or "OFF"
 u.lbl.TextColor3 = on and Color3.fromRGB(255,255,255) or C.TXT
 -- Stroke terang saat ON
 local stk = u.btn:FindFirstChildWhichIsA("UIStroke")
 if stk then stk.Color = on and C.ACC2 or C.BORD; stk.Transparency = on and 0 or 0.3 end
end

function SkOn(n)
 local s = SKL[n]; if s.t then return end
 s.on = true
 SkSetUI(n, true)
 s.t = task.spawn(function()
 while s.on do
 SkFireOnce(n)
 task.wait(0.8)
 end
 s.t = nil
 end)
end

function SkOff(n)
 local s = SKL[n]; s.on = false
 SkSetUI(n, false)
 if s.t then pcall(function() task.cancel(s.t) end); s.t = nil end
end

--  Keyboard listener: tekan Z/X/C/V/F untuk toggle skill 
-- Bekerja di PC (keyboard) dan Android (simulasi via Roblox touch-to-keycode)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
 if gameProcessed then return end
 local keyMap = {
 [Enum.KeyCode.Z] = "Z",
 [Enum.KeyCode.X] = "X",
 [Enum.KeyCode.C] = "C",
 [Enum.KeyCode.V] = "V",
 [Enum.KeyCode.F] = "F",
 }
 local n = keyMap[input.KeyCode]
 if not n then return end
 if SKL[n].on then SkOff(n) else SkOn(n) end
end)

-- ============================================================
-- ENEMY HELPERS
-- ============================================================
function GetEnemies()
 local list = {}
 -- [v51-FIX] Tambah "Enemy" ke folder list (konsisten dengan GetEnemiesLocal)
 local ENEMY_FOLDERS = {"Enemys", "EnemyCityRaid", "CityRaidEnemys", "Enemies", "Enemy"}
 local seen = {}
 local function _addEnemy(e)
  if not e:IsA("Model") then return end
  local g = e:GetAttribute("EnemyGuid") or e:GetAttribute("BossGuid") or e:GetAttribute("Guid") or e:GetAttribute("GUID")
  local h = e:FindFirstChild("HumanoidRootPart")
  local hum = e:FindFirstChildOfClass("Humanoid")
  if g and h and hum and hum.Health > 0 and not seen[g] then
   seen[g] = true
   table.insert(list, {model=e, guid=g, hrp=h})
  end
 end
 for _, folderName in ipairs(ENEMY_FOLDERS) do
  local f = workspace:FindFirstChild(folderName)
  if f then
   for _, e in ipairs(f:GetChildren()) do _addEnemy(e) end
  end
 end
 -- [v51-FIX] Fallback: scan workspace:GetChildren() jika semua folder kosong
 if #list == 0 then
  for _, obj in ipairs(workspace:GetChildren()) do _addEnemy(obj) end
 end
 return list
end

function IsDead(e)
 if _deadG[e.guid] then return true end
 if not e.model or not e.model.Parent then return true end
 local h = e.model:FindFirstChildOfClass("Humanoid")
 return not h or h.Health <= 0
end

function SaveOrigin()
 local char = LP.Character; if not char then return end
 local hrp = char:FindFirstChild("HumanoidRootPart")
 if hrp then ORIGIN_POS = hrp.Position end
end

function ReturnHRPToOrigin()
 local char = LP.Character; if not char then return end
 local hrp = char:FindFirstChild("HumanoidRootPart")
 if hrp then hrp.CFrame = CFrame.new(ORIGIN_POS) end
end

-- [FIX v242] Satu dedicated hero attack thread mengurus type 1+2+3
-- Interval tetap 0.5s antar siklus penuh - tidak overflow AnimationTrack limit 64
-- FireAllDamage hanya update target, tidak fire hero langsung
-- RE.Atk & RE.Click tetap sync karena itu attack player bukan hero
local _heroAtkTarget = nil -- guid target hero saat ini
local _heroAtkThread = nil -- thread hero attack
local _heroAtkTick = 0 -- [PERBAIKAN 1] Mencegah nil error pada siklus attack

-- [v256-FIX] Helper: validasi enemy guid masih punya HumanoidRootPart yang valid
local function IsEnemyGuidValid(g)
 if not g then return false end
 local ENEMY_FOLDERS = {"Enemys", "EnemyCityRaid", "CityRaidEnemys", "Enemies", "Enemy"}
 for _, folderName in ipairs(ENEMY_FOLDERS) do
  local f = workspace:FindFirstChild(folderName)
  if f then
   for _, e in ipairs(f:GetChildren()) do
    if e:IsA("Model") and e:GetAttribute("EnemyGuid") == g then
     local hrp = e:FindFirstChild("HumanoidRootPart")
     local hum = e:FindFirstChildOfClass("Humanoid")
     if hrp and hum and hum.Health > 0 then
      return true
     end
     return false
    end
   end
  end
 end
 -- Fallback: cek CityRaidEnter (enemy Siege nested di sini)
 pcall(function()
  local mapF = workspace:FindFirstChild("Map")
  local cre = mapF and mapF:FindFirstChild("CityRaidEnter")
  if cre then
   for _, e in ipairs(cre:GetDescendants()) do
    if e:IsA("Model") and e:GetAttribute("EnemyGuid") == g then
     local hrp = e:FindFirstChild("HumanoidRootPart")
     local hum = e:FindFirstChildOfClass("Humanoid")
     if hrp and hum and hum.Health > 0 then
      return true
     end
    end
   end
  end
 end)
 return false
end

local function EnsureHeroAtkThread()
 if _heroAtkThread then return end
 _heroAtkThread = task.spawn(function()
  local _lastFire = {}
  while ScreenGui and ScreenGui.Parent do
   local g = _heroAtkTarget
   if g and #HERO_GUIDS > 0 and (tick() - _heroAtkTick) >= 0.5 and IsEnemyGuidValid(g) then
    _heroAtkTick = tick()
    for _, hGuid in ipairs(HERO_GUIDS) do
     local last = _lastFire[hGuid] or 0 -- [PERBAIKAN 2] Tambahkan 'or 0'
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
  end
  _heroAtkThread = nil -- [PERBAIKAN 3] Memperbaiki memori bocor (sebelumnya terisi angka 5)
 end)
end

local _skillTarget = nil
local function EnsureSkillThread() EnsureHeroAtkThread() end

local _heroFireTick = {}
function FireAttack(g, pos)
 if not g then return end
 if RE.Atk then pcall(function() RE.Atk:FireServer({attackEnemyGUID=g}) end) end
 if RE.HeroUseSkill and #HERO_GUIDS > 0 then
  local now = tick()
  local last = _heroFireTick[g] or 0 -- [PERBAIKAN 4 UTAMA] Menyembuhkan error baris 1383
  if now - last >= 0.04 then
   _heroFireTick[g] = now
   for _, hGuid in ipairs(HERO_GUIDS) do
    pcall(function() RE.HeroUseSkill:FireServer({heroGuid=hGuid,attackType=1,userId=MY_USER_ID,enemyGuid=g}) end)
    pcall(function() RE.HeroUseSkill:FireServer({heroGuid=hGuid,attackType=2,userId=MY_USER_ID,enemyGuid=g}) end)
    pcall(function() RE.HeroUseSkill:FireServer({heroGuid=hGuid,attackType=3,userId=MY_USER_ID,enemyGuid=g}) end)
   end
  end
 end
end

function FireAllDamage(g, ep)
 if not IsEnemyGuidValid(g) then return end
 if RE.Click then
  task.spawn(function()
   pcall(function() RE.Click:InvokeServer({enemyGuid=g, enemyPos=ep}) end)
  end)
 end
 if RE.Atk then
  pcall(function() RE.Atk:FireServer({attackEnemyGUID=g}) end)
 end
 _heroAtkTarget = g
 _skillTarget = g
 EnsureHeroAtkThread()
 if not RE.HeroUseSkill and RE.HeroSkill then
  for _, hGuid in ipairs(HERO_GUIDS) do
   pcall(function() RE.HeroSkill:FireServer({heroGuid=hGuid,enemyGuid=g,skillType=1,masterId=MY_USER_ID}) end)
   pcall(function() RE.HeroSkill:FireServer({heroGuid=hGuid,enemyGuid=g,skillType=2,masterId=MY_USER_ID}) end)
   pcall(function() RE.HeroSkill:FireServer({heroGuid=hGuid,enemyGuid=g,skillType=3,masterId=MY_USER_ID}) end)
  end
 end
end

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

if RE.Death then
 RE.Death.OnClientEvent:Connect(function(d)
 if not d then return end
 local g = d.enemyGuid or d.guid
 if g then
 _deadG[g] = true
 if MA.running and not (SIEGE and SIEGE.inMap) and not (RAID and RAID.inMap) and not (DUNGEON and DUNGEON.inMap) and not (ST2 and ST2.running) then MA.killed = MA.killed + 1 end
 if AG.running then AG.killed = AG.killed + 1 end
 -- [v50] gabung counter siege di sini, hapus listener kedua di bawah
 if SIEGE and SIEGE.running then
 SIEGE.killed = SIEGE.killed + 1
 if SiegeCounterUpdate then SiegeCounterUpdate() end
 end
 end
 end)
end

-- ============================================================
-- DESTROY WORKER
-- ============================================================
function StartDestroyWorker(checkFn)
    local DROP_FOLDERS = {"Golds","Items","Drops","Rewards","Loot","DropItems","RewardItems"}
    local collected = {}
    local folderConns = {}

    local function collectObj(obj)
        local guid = obj:GetAttribute("GUID") or obj:GetAttribute("Guid") or obj:GetAttribute("guid")
        if not guid or collected[guid] then return end
        collected[guid] = true
        -- TP ke player dulu
        pcall(function()
            local char = LP.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
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
        pcall(function() RE.CollectItem:InvokeServer(guid) end)
        if RE.ExtraReward then
            pcall(function() RE.ExtraReward:FireServer({isSell=true, guid=guid}) end)
        end
        if AG.running then AG.collected = AG.collected + 1 end
        if MA.running then MA.collected = (MA.collected or 0) + 1 end
    end

    -- [FIX] Connect ChildAdded langsung ke folder (bukan workspace), no delay
    task.spawn(function()
        task.wait(1) -- Tunggu server siap
        for _, folderName in ipairs(DROP_FOLDERS) do
            local folder = workspace:FindFirstChild(folderName)
            if folder then
                -- Batch collect yang sudah ada
                for _, obj in ipairs(folder:GetChildren()) do
                    if not checkFn() then break end
                    collectObj(obj)
                end
                -- Listen new drops masuk folder
                local c = folder.ChildAdded:Connect(function(obj)
                    if checkFn() then collectObj(obj) end
                end)
                table.insert(folderConns, c)
            end
        end
        -- Polling fallback setiap 0.15s (batch semua sekaligus)
        while checkFn() do
            for _, folderName in ipairs(DROP_FOLDERS) do
                if not checkFn() then break end
                local folder = workspace:FindFirstChild(folderName)
                if folder then
                    for _, obj in ipairs(folder:GetChildren()) do
                        collectObj(obj)
                    end
                end
            end
            task.wait(0.15)
        end
        -- Cleanup connections
        for _, c in ipairs(folderConns) do pcall(function() c:Disconnect() end) end
    end)
end

-- ============================================================
-- [v257] AUTO GOLD MAGNET - TP semua gold/drop ke player
-- Gold di game hanya ter-collect kalau dekat player
-- Fungsi ini TP semua item di folder Golds/Items/Drops ke posisi player
-- Dipanggil periodik selama MA/AG/Raid aktif
-- ============================================================
-- ============================================================
-- [v258 FIXED] SUPER GOLD MAGNET - Batch TP + Collect, no delay, always aggressive
-- FIX: _goldMagnetRunning direset saat checkFn false (tidak stuck)
-- FIX: Semua item di-TP sekaligus ke posisi player, tidak satu per satu
local _goldMagnetRunning = false
function StartGoldMagnet(checkFn)
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
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
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
            task.wait(0.05) -- 20x per detik, batch semua item sekaligus
        end
        _goldMagnetRunning = false
    end)
end

function StopGoldMagnet()
    _goldMagnetRunning = false
end

-- [AUTO COLLECT GOLD & ITEM] Master toggle - kontrol semua collector sekaligus
function DoAutoCollectGoldItem(on)
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


-- ATTACK LOOPS
-- ============================================================
function AttackLoop_Mass(onStatus)
 _deadG = {}
 -- ============================================================
 -- FASE 1: Tunggu musuh muncul (maks 10 detik)
 -- ============================================================
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

 -- ============================================================
 -- FASE 2: Attack loop
 -- Keluar jika:
 --   A) alive == 0  -> langsung sukses (tanpa timer tambahan)
 --   B) killTarget terpenuhi (non-Kill-All mode)
 --   C) Tidak bisa bunuh 1 musuh dalam 5 detik -> anggap stuck, skip
 -- ============================================================
 local start    = MA.killed
 local lastKill = MA.killed
 local stuckT   = 0
 local STUCK_LIMIT = 5.0 -- detik tanpa kill baru -> skip map

 while MA.running do
  -- [GUARD v50] Cek IsAnyMapActive() langsung dari state terpusat
  do
   local _mBusy, _mWho = IsAnyMapActive()
   if _mBusy then return "interrupted" end
  end
  -- Cek interrupt prioritas lebih tinggi (kompatibilitas flag lama)
  if MODE.current ~= "idle" and MODE.current ~= "ma"
   or _raidInterrupt or _siegeInterrupt
   or (DUNGEON and DUNGEON.interrupt) or (DUNGEON and DUNGEON.inMap)
   or (ST2 and ST2.running)
   or (SIEGE and SIEGE.inMap) then
   return "interrupted"
  end
  -- [FIX GODMODE] Guard: STOP serang jika player bukan di basemap normal (50001-50020)
  -- Blok Siege (50201+), Raid (50101+), Tower (50300+), dan map lain di luar range
  do
   local ok, wm = pcall(function()
    return workspace:GetAttribute("MapId") or workspace:GetAttribute("mapId") or workspace:GetAttribute("CurrentMapId")
   end)
   if ok and type(wm) == "number" then
    if wm < 50001 or wm > 50020 then
     return "interrupted"
    end
   end
  end

  local isAll = (MA.killTarget == 0)
  local here  = MA.killed - start

  -- Hitung musuh hidup saat ini dari workspace langsung
  local alive = 0
  for _, e in ipairs(GetEnemies()) do
   if not IsDead(e) then alive = alive + 1 end
  end

  -- -- Kondisi keluar A: tidak ada musuh sama sekali -> langsung sukses --
  if alive == 0 then
   if onStatus then onStatus("[OK] Semua musuh habis!") end
   return true
  end

  -- -- Kondisi keluar B: kill target terpenuhi (non-Kill-All) --
  if not isAll and here >= MA.killTarget then
   if onStatus then onStatus("[OK] Target "..MA.killTarget.." tercapai!") end
   return true
  end

  -- -- Update status --
  if isAll then
   if onStatus then onStatus("Kill All: "..alive.." sisa") end
  else
   if onStatus then onStatus(alive.." hidup | "..here.."/"..MA.killTarget) end
  end

  -- -- Cek stuck: jika tidak ada kill baru dalam STUCK_LIMIT detik -> skip --
  if MA.killed > lastKill then
   lastKill = MA.killed
   stuckT   = 0
  else
   stuckT = stuckT + 0.08
   if stuckT >= STUCK_LIMIT then
    if onStatus then onStatus("[!] Stuck "..STUCK_LIMIT.."s, skip map...") end
    return true
   end
  end

  -- -- Serang semua musuh hidup --
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

  task.wait(0.08)
 end
 return false
end

-- Pilih musuh secara random dari daftar yang masih hidup
function GetRandomEnemy()
 local alive = {}
 for _, e in ipairs(GetEnemies()) do
 if not IsDead(e) and e.hrp then
 table.insert(alive, e)
 end
 end
 if #alive == 0 then return nil end
 return alive[math.random(1, #alive)]
end

function TpToEnemy(tgt)
 if not tgt or not tgt.hrp then return end
 local char = LP.Character
 if not char then return end
 local hrp = char:FindFirstChild("HumanoidRootPart")
 if not hrp then return end
 -- Raycast ke bawah dari posisi musuh untuk cari lantai aman
 local origin = tgt.hrp.Position + Vector3.new(1, 1, 1)
 local params = RaycastParams.new()
 params.FilterType = Enum.RaycastFilterType.Exclude
 local ex = {}
 if LP.Character then table.insert(ex, LP.Character) end
 local ef = workspace:FindFirstChild("Enemys")
 if ef then table.insert(ex, ef) end
 params.FilterDescendantsInstances = ex
 local result = workspace:Raycast(origin, Vector3.new(1, 1, 1), params)
 -- [v188] offset dinaikkan ke +5 agar tidak jatuh ke bawah tanah/jurang
 local safePos = result and (result.Position + Vector3.new(1, 1, 1)) or (tgt.hrp.Position + Vector3.new(1, 1, 1))
 hrp.CFrame = CFrame.new(safePos)
end

function AttackLoop_Goyang(onStatus)
 -- [v186-FIX] SaveOrigin hanya jika Target Musuh (tbnThread) tidak sedang aktif
 -- Jika tbnThread aktif, origin sudah disimpan olehnya -> jangan overwrite
 if not _tgtThread then
 SaveOrigin()
 end
 local currentTgt = nil
 local _tpTimer = 0 -- [v186-FIX] timer untuk TP periodik tiap 0.5s

 -- Mulai: gunakan AG.currentTarget jika Target Musuh sudah set, 
 -- jika tidak pakai musuh terdekat
 -- [v186-FIX] Prioritaskan AG.currentTarget agar sinkron dengan Target Musuh
 local first = AG.currentTarget or GetRandomEnemy()
 if first and not IsDead(first) and first.model.Parent then
 currentTgt = first
 TpToEnemy(currentTgt)
 task.wait(0)
 FireAttack(currentTgt.guid, currentTgt.hrp.Position)
 if onStatus then onStatus("Goyang -> ["..currentTgt.model.Name.."] (random) Kill: "..AG.killed) end
 end

 while AG.running do
 -- [v186-FIX] Jika Target Musuh aktif, selalu ikuti AG.currentTarget
 -- AG.currentTarget di-update oleh tbnThread secara real-time
 if _tgtThread and AG.currentTarget and not IsDead(AG.currentTarget) and AG.currentTarget.model.Parent then
 currentTgt = AG.currentTarget
 end
end


 -- Target mati / habis -> cari berikutnya
 if not currentTgt or IsDead(currentTgt) or not currentTgt.model.Parent then
 local waited = false
 while AG.running do
 -- [v186-FIX] Cek AG.currentTarget dulu sebelum random
 local next = (AG.currentTarget and not IsDead(AG.currentTarget) and AG.currentTarget.model.Parent and AG.currentTarget) or GetRandomEnemy()
 if next then
 currentTgt = next
 TpToEnemy(currentTgt)
 task.wait()
 FireAttack(currentTgt.guid, currentTgt.hrp.Position)
 _tpTimer = 0
 if onStatus then onStatus("Goyang -> ["..currentTgt.model.Name.."] Kill: "..AG.killed) end
 break
 else
 if onStatus then onStatus("Waiting Enemy Spawn...") end
 waited = false
 task.wait(0.3)
 end
 end
 if not AG.running then end
 end
end


 -- Serang musuh saat ini
 if currentTgt and not IsDead(currentTgt) and currentTgt.model.Parent then
 local pos = currentTgt.hrp and currentTgt.hrp.Position or Vector3.new(1,1,1)
 FireAttack(currentTgt.guid, pos)

 -- [v186-FIX] Hanya ReturnHRPToOrigin jika tbtThread tidak aktif
 -- Jika tbnThread masih jalan, biarkan tbnThread yang urus return origin
 if not _tgtThread then
 ReturnHRPToOrigin()
 end
 return false
end

function RunAG(onStatus, onDone)
    StopGoldMagnet() -- Reset dulu agar tidak stuck
    AG.running = true; AG.killed = 0; AG.collected = 0
    StartInstantGoldCollector(true)  -- [v258] Instant collect on (fix: listen ke folder)
    StartDestroyWorker(function() return AG.running end)
    StartGoldMagnet(function() return AG.running end) -- [v258] Super magnet
    AG.thread = task.spawn(function()
        AttackLoop_Goyang(onStatus)
        AG.running = false
        StopGoldMagnet()
        StartInstantGoldCollector(false)
        ReturnHRPToOrigin()
        if onDone then onDone() end
    end)
end


-- ============================================================
-- AUTO FUNCTIONS
-- ============================================================
function DoAutoCollect(on)
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
 task.wait(0.03)
 end
 end
 end
 end
 task.wait(0.2)
 end
 end)
end

local _destroyerThread = nil
function DoAutoDestroyer(on)
    StopLoop("destroyer")
    if _destroyerThread then task.cancel(_destroyerThread); _destroyerThread = nil end
    if not on then return end
    
    _destroyerThread = task.spawn(function()
        task.wait(4) -- [v112-FIX] Tunggu PlayerEntity server ready sebelum FireServer
        while STATE.autoDestroyer do
            repeat
            -- [v112-FIX] Guard nil: skip jika remote belum tersedia
            if not RE.ExtraReward then task.wait(2); break end
            pcall(function()
                for _, obj in ipairs(workspace:GetChildren()) do
                    if obj:IsA("Model") or obj:IsA("Part") then
                        local guid = obj:GetAttribute("GUID")
                        if guid then
                            RE.ExtraReward:FireServer({isSell=true, guid=guid})
                        end
                    end
                end
            end)
            task.wait(2)
            until true
        end
    end)
end

local _ariseThread = nil
function DoAutoArise(on)
    StopLoop("arise")
    if _ariseThread then task.cancel(_ariseThread); _ariseThread = nil end
    if not on then return end
    
    _ariseThread = task.spawn(function()
        task.wait(4) -- [v112-FIX] Tunggu PlayerEntity server ready sebelum FireServer
        while STATE.autoArise do
            repeat
            -- [v112-FIX] Guard nil: skip jika remote belum tersedia
            if not RE.ExtraReward then task.wait(2.5); break end
            pcall(function()
                for _, obj in ipairs(workspace:GetChildren()) do
                    if obj:IsA("Model") or obj:IsA("Part") then
                        local guid = obj:GetAttribute("GUID")
                        if guid then
                            RE.ExtraReward:FireServer({isSell=false, isAuto=false, guid=guid})
                        end
                    end
                end
            end)
            task.wait(2.5)
            until true
        end
    end)
end

function RefreshStatus()
 local map = {
 collect = {STATE.autoCollect, "Auto Collect Gold"},
 destroyer = {STATE.autoDestroyer, "Auto Destroyer"},
 arise = {STATE.autoArise, "Auto Arise"},
 noClip = {STATE.noClip, "NO CLIP"},
 antiAfk = {STATE.antiAfk, "ANTI AFK"},
 }
 for key, data in pairs(map) do
 local active, label = data[1], data[2]
 if StatusDots[key] then
 StatusDots[key].BackgroundColor3 = active and Color3.fromRGB(80,220,80) or Color3.fromRGB(100,100,100)
 end
 if StatusLbls[key] then
 StatusLbls[key].Text = label..(active and " - ON" or " - OFF")
 StatusLbls[key].TextColor3 = active and C.ACC2 or C.TXT2
 end
 end
end

-- [FIX] WaitRaidDone - Rem Tangan Mass Attack (Priority System)
function WaitRaidDone()
    local t = 0
    local function shouldPause()
        -- 1. KASTA RAJA (Auto Dungeon) WAJIB PAUSE MASS ATTACK!
        if MODE.current == "dungeon" or (DUNGEON and DUNGEON.inMap) or (DUNGEON and DUNGEON.interrupt) then 
            return true, "Auto Dungeon" 
        end
        
        -- 2. KASTA BANGSAWAN (Auto Siege) WAJIB PAUSE MASS ATTACK!
        if MODE.current == "siege" or (SIEGE and SIEGE.inMap) or _siegeInterrupt then 
            return true, "Auto Siege" 
        end

        -- 3. KASTA PRAJURIT (Auto Raid) PAUSE MASS ATTACK HANYA SAAT DI DALAM MAP
        if RAID and RAID.running then
            if _raidInterrupt or (MODE.current == "raid" and RAID.inMap) or RAID.inMap then 
                return true, "Auto Raid" 
            end
        end

        -- 4. Auto Ascension Tower - pause MA saat di dalam Tower ATAU sesaat sebelum masuk
        -- [FIX] _ascBusy tidak dipakai di sini - itu untuk RAID biar tidak rebutan masuk
        -- _ascInterrupt mirip _raidInterrupt: di-set sesaat sebelum masuk, clear setelah inMap=true
        -- MA boleh jalan bebas saat ASC cooldown, pause hanya saat _ascInterrupt atau ASC.inMap
        if ASC and (_ascInterrupt or ASC.inMap) then
            return true, "Auto Ascension"
        end

        return false, nil
    end

    local pause, reason = shouldPause()
    while pause and MA.running do
        t = t + 0.5
        -- [FIX] Timeout 60 detik (Dungeon butuh waktu lama, kita naikkan batas timeout)
        if t >= 120 then 
            if MODE.current ~= "idle" and MODE.current ~= "ma" then
                MODE.current = "idle"
            end
            break
        end

        local label = reason or "Other Fiture"
        if _maStatusLbl then
            _maStatusLbl.Text = "[||] Pause ("..label..") - "..math.floor(t).."s"
            _maStatusLbl.TextColor3 = Color3.fromRGB(255,140,0)
        end
        task.wait(0.5)
        pause, reason = shouldPause()
    end

    if MA.running then task.wait(0.5) end
    if _maStatusLbl and MA.running then
        _maStatusLbl.Text = "> Continue After pause..."
        _maStatusLbl.TextColor3 = C.ACC3
    end
end
-- ============================================================
function WaitSiegeDone()
    local waited = 0
    while (SIEGE and SIEGE.inMap) or _siegeInterrupt or MODE.current == "siege" do
        -- [FIX] Jika SIEGE sudah tidak running (toggle OFF), langsung break
        if not SIEGE or not SIEGE.running then
            _siegeInterrupt = false
            if MODE.current == "siege" then MODE.current = "idle" end
            MODE:Release("siege")
            if SIEGE then SIEGE.inMap = false end
            break
        end
        task.wait(0.5)
        waited = waited + 0.5
        local inSiege, _ = IsInSiegeMap()
        if not inSiege and not (SIEGE and SIEGE.inMap) then
            _siegeInterrupt = false
            if MODE.current == "siege" then MODE.current = "idle" end
            MODE:Release("siege")
            break
        end
        -- Timeout 30 detik: paksa release
        if waited >= 10 then
            _siegeInterrupt = false
            if MODE.current == "siege" then MODE.current = "idle" end
            MODE:Release("siege")
            if SIEGE then SIEGE.inMap = false end
            break
        end
    end
end
function DoMassAttack(on)
 if on then
 _mOn = true
 MA.running = true
 MA.killed = 0
 MA.collected = 0
 StopGoldMagnet() -- [v258] Reset magnet sebelum start
 StartInstantGoldCollector(true) -- [v258] Instant collect (fix: listen ke folder)
 StartDestroyWorker(function() return MA.running end)
 StartGoldMagnet(function() return MA.running end) -- [v258] Super magnet
 MA.thread = task.spawn(function()
 local _maStart = os.time()
 local function maStatus(msg, col)
 if _maStatusLbl then
 local dur = os.time() - _maStart
 local ts = string.format("%02d:%02d:%02d", math.floor(dur/3600), math.floor(dur/60)%60, dur%60)
 _maStatusLbl.Text = "["..ts.."] "..msg
 _maStatusLbl.TextColor3 = col or C.ACC2
 end
 end
 while MA.running do
 -- [v252] Pause kalau ada fitur prioritas lebih tinggi aktif
 if MODE.current ~= "idle" and MODE.current ~= "ma" or _raidInterrupt or _siegeInterrupt or _ascInterrupt or (DUNGEON and DUNGEON.interrupt) or (DUNGEON and DUNGEON.inMap) or (ST2 and ST2.running) then WaitRaidDone() end
 if not MA.running then break end

 local mapsToUse = {}
 for i = 1, 20 do if MR.selected[i] then table.insert(mapsToUse, MAPS[i]) end end

 if #mapsToUse == 0 then
 local cont = AttackLoop_Mass(function(msg)
 maStatus(msg)
 end)
 if cont == "interrupted" then
 WaitRaidDone()
 elseif not cont or not MA.running then
 break
 end
 if MODE.current ~= "idle" and MODE.current ~= "ma" or _raidInterrupt or _siegeInterrupt or _ascInterrupt or (DUNGEON and DUNGEON.interrupt) or (DUNGEON and DUNGEON.inMap) or (ST2 and ST2.running) then WaitRaidDone() end
 task.wait(MR.nextMapDelay)
 else
 -- [FIX] while+index manual: loop balik ke map pertama setelah map terakhir
 -- Rebuild _fresh tiap iterasi dari MR.selected terbaru
 -- -> langsung respon kalau user ubah selection di tengah jalan
 local _mapIdx = 1
 while MA.running do
 repeat
 local _fresh = {}
 for i = 1, 20 do
 if MR.selected[i] then table.insert(_fresh, MAPS[i]) end
 end
 if #_fresh == 0 then mapsToUse = {}; break end
 if _mapIdx > #_fresh then _mapIdx = 1 end
 local m = _fresh[_mapIdx]
 if MODE.current ~= "idle" and MODE.current ~= "ma" or _raidInterrupt or _siegeInterrupt or _ascInterrupt or (DUNGEON and DUNGEON.interrupt) or (DUNGEON and DUNGEON.inMap) or (ST2 and ST2.running) then WaitRaidDone() end
 if not MA.running then break end
 if _raidInterrupt then _mapIdx = _mapIdx + 1; break end
 maStatus("-> TP ke "..m.name.."...", Color3.fromRGB(180,220,255))
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
 if MODE.current ~= "idle" and MODE.current ~= "ma" or _raidInterrupt or _siegeInterrupt or _ascInterrupt or (DUNGEON and DUNGEON.interrupt) or (DUNGEON and DUNGEON.inMap) or (ST2 and ST2.running) then WaitRaidDone() end
 if not MA.running then break end
 maStatus("[OK] SUCCES "..m.name.." - Go to...", Color3.fromRGB(100,255,150))
 task.wait(MR.nextMapDelay)
 _mapIdx = _mapIdx + 1
 if _mapIdx > #_fresh then
 _mapIdx = 1
 end
 until true
 end
 end
 end
 _mOn = false
 MA.running = false
 if _maStatusLbl then
 _maStatusLbl.Text = "[.] SUCCES"
 _maStatusLbl.TextColor3 = C.DIM
 end
 end)
 else
 _mOn = false; MA.running = false
 if MA.thread then pcall(function() task.cancel(MA.thread) end); MA.thread = nil end
 if _maStatusLbl then _maStatusLbl.Text = "Idle" end
 end
end

-- ============================================================
-- [FIXED] FUNGSI REJOIN SERVER (ANTI-NIL)
-- ============================================================
local function RejoinServer()
    local TS = game:GetService("TeleportService")
    local Players = game:GetService("Players")
    local LP = Players.LocalPlayer

    -- Deteksi VIP Server agar tidak ditendang saat rejoin
    local isVIP = (game.VIPServerId ~= "" and game.VIPServerId ~= nil) or (game.VIPServerOwnerId ~= 0)

    task.spawn(function()
        while task.wait(2) do
            pcall(function()
                if isVIP then
                    -- Jika VIP, lempar ke server publik (biar tidak Unauthorized)
                    TS:Teleport(game.PlaceId, LP)
                elseif #Players:GetPlayers() <= 1 then
                    -- Jika sendirian, cari server baru (biar tidak shutdown)
                    TS:Teleport(game.PlaceId, LP)
                else
                    -- Jika ramai, masuk kembali ke JobId yang sama
                    TS:TeleportToPlaceInstance(game.PlaceId, game.JobId, LP)
                end
            end)
        end
    end)
end

-- ============================================================
-- QUIRK DATA
-- ============================================================
-- Hero: hanya tampilkan quirk tier tinggi per slot, max pilih 3
QUIRK_LIST_PER_SLOT = {
 -- Slot 1 (9 pilihan, max 3)
 {
 {id=99013,name="Midas Touch"},
 {id=99014,name="Hyper Sprint"},
 {id=99015,name="Time Skipper"},
 {id=99016,name="Cosmic Luck"},
 {id=99017,name="Destiny Rewrite"},
 {id=99018,name="Final Judgment"},
 {id=99109,name="Golden Era"},
 {id=99110,name="The Chosen Singularity"},
 {id=99111,name="Axiom of Value"},
 },
 -- Slot 2 (9 pilihan, max 3)
 {
 {id=99031,name="Resource Conqueror"},
 {id=99032,name="Elemental Overload"},
 {id=99033,name="Crimson Executioner"},
 {id=99034,name="God's Gift"},
 {id=99035,name="Apocalypse Carnival"},
 {id=99036,name="Divine Judgment"},
 {id=99112,name="Celestial Benediction"},
 {id=99113,name="Eclipse Masquerade"},
 {id=99114,name="Sovereign Verdict"},
 },
 -- Slot 3 (8 pilihan, max 3)
 {
 {id=99049,name="Slayer's Instinct"},
 {id=99050,name="Harbinger of Ruin"},
 {id=99052,name="Godslayer's Fury"},
 {id=99053,name="Deicide's Endgame"},
 {id=99054,name="Final Arbiter"},
 {id=99115,name="Cosmic Cataclysm"},
 {id=99116,name="Omega Oblivion"},
 {id=99117,name="Sovereign Axiom"},
 },
}
MAX_PER_SLOT = 3

QUIRK_MAP = {}
for _, list in ipairs(QUIRK_LIST_PER_SLOT) do
 for _, q in ipairs(list) do QUIRK_MAP[q.id] = q.name end
end

-- Weapon: hanya tampilkan quirk tier tinggi per slot, max pilih 3
W_QUIRK_LIST_PER_SLOT = {
 -- Slot 1 (6 pilihan, max 3)
 {
 {id=99067,name="Celestial Onslaught"},
 {id=99068,name="Lucky Scavenger"},
 {id=99069,name="Titan's Wrath"},
 {id=99070,name="Omnipotent Benefactor"},
 {id=99071,name="Archangel's Judgment"},
 {id=99072,name="Avatar of Destruction"},
 },
 -- Slot 2 (6 pilihan, max 3)
 {
 {id=99085,name="Celestial Onslaught"},
 {id=99086,name="Lucky Scavenger"},
 {id=99087,name="Titan's Wrath"},
 {id=99088,name="Omnipotent Benefactor"},
 {id=99089,name="Archangel's Judgment"},
 {id=99090,name="Avatar of Destruction"},
 },
 -- Slot 3 (6 pilihan, max 3)
 {
 {id=99103,name="Celestial Onslaught"},
 {id=99104,name="Lucky Scavenger"},
 {id=99105,name="Titan's Wrath"},
 {id=99106,name="Omnipotent Benefactor"},
 {id=99107,name="Archangel's Judgment"},
 {id=99108,name="Avatar of Destruction"},
 },
}
W_MAX_PER_SLOT = 3

W_QUIRK_MAP = {}
for _, list in ipairs(W_QUIRK_LIST_PER_SLOT) do
 for _, q in ipairs(list) do W_QUIRK_MAP[q.id] = q.name end
end

local PG_MACHINE_NAMES = {"R-Pet Gear", "Y-Pet Gear", "B-Pet Gear"}
local PG_DRAW_IDS = {980001, 980002, 980003}

-- [v215] PG_GRADES_PER_MACHINE FINAL confirmed sniff GUI + roll
-- R-Pet (980001): 990001-990010 + 990031
-- Y-Pet (980002): 990011-990020 + 990041
-- B-Pet (980003): 990021-990030 + 990051
local PG_GRADES_PER_MACHINE = {
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

local PG_GRADE_MAP = {}
for _, list in ipairs(PG_GRADES_PER_MACHINE) do
 for _, g in ipairs(list) do PG_GRADE_MAP[g.id] = g.name end
end

-- ============================================================
PGR = {
 guids = {"","",""},
 captured = {false,false,false},
 targets = {{},{},{}},
 running = {false,false,false},
 statLbls = {nil,nil,nil},
 dotRefs = {nil,nil,nil},
 sumLbls = {nil,nil,nil},
 attemptLbls = {nil,nil,nil},
 lastLbls = {nil,nil,nil},
 toggleBtns = {nil,nil,nil},
 toggleKnobs = {nil,nil,nil},
 enOnFlags = {false,false,false},
}

PGR100 = {
 running = {false,false,false},
 threads = {nil,nil,nil},
 toggleBtns = {nil,nil,nil},
 toggleKnobs = {nil,nil,nil},
 enOnFlags = {false,false,false},
 statLbls = {nil,nil,nil},
 dotRefs = {nil,nil,nil},
 attemptLbls = {nil,nil,nil},
 lastLbls = {nil,nil,nil},
}

local HALO_NAMES = {"Bronze Halo", "Gold Halo", "Diamond Halo"}
local HALO_DRAW_ID = {1, 2, 3}
HALO = {
 running = {false, false, false},
 statLbls = {nil, nil, nil},
 dotRefs = {nil, nil, nil},
 attemptLbls= {nil, nil, nil},
 toggleBtns = {nil, nil, nil},
 toggleKnobs= {nil, nil, nil},
 enOnFlags = {false, false, false},
}

--  HALO LOOP THREADS 
local HALO_THREADS = {nil, nil, nil}

DoAutoRollHalo = function(hi, on)
 -- Stop loop lama kalau ada
 if HALO_THREADS[hi] then
 task.cancel(HALO_THREADS[hi])
 HALO_THREADS[hi] = nil
 end

 HALO.running[hi] = on

 local function setStatus(txt, col)
 if HALO.statLbls[hi] then
 HALO.statLbls[hi].Text = txt
 HALO.statLbls[hi].TextColor3 = col or Color3.fromRGB(160,148,135)
 end
 if HALO.dotRefs[hi] then
 HALO.dotRefs[hi].BackgroundColor3 = on and Color3.fromRGB(80,220,80) or Color3.fromRGB(100,100,100)
 end
 end

 if not on then
 setStatus("[.] Idle", Color3.fromRGB(160,148,135))
 return
 end

 local drawId = HALO_DRAW_ID[hi]

 HALO_THREADS[hi] = task.spawn(function()
 local attempt = 0
 while HALO.running[hi] do
 attempt = attempt + 1
 if HALO.attemptLbls[hi] then
 HALO.attemptLbls[hi].Text = "Attempt: "..attempt
 end
 setStatus("[R] Rolling #"..attempt.."...", Color3.fromRGB(255,200,60))

 local ok, res = pcall(function()
 return RE.RerollHalo:InvokeServer(drawId)
 end)

 if not ok then
 setStatus("[!] Error - retry...", Color3.fromRGB(255,100,60))
 task.wait(1)
 else
 setStatus("[OK] Roll #"..attempt.." DONE", Color3.fromRGB(80,220,80))
 task.wait(0.05)
 end
 end
 setStatus("[.] Idle", Color3.fromRGB(160,148,135))
 end)
end

-- ============================================================
-- ORNAMENT DATA (di-wrap dalam 1 tabel untuk hemat local slot)
-- ============================================================
_ASH_ORN = {}

_ASH_ORN.MACHINES = {
 {name="Headdress", machineId=400001},
 {name="Ornament Machine", machineId=400002},
 {name="Wealth Blessing", machineId=400003},
 {name="Shadowhunter Blessing",machineId=400004},
 {name="Primordial Blessing", machineId=400005},
 {name="Monarch Power", machineId=400006},
 {name="Saiyan Blessing", machineId=400007},
}

_ASH_ORN.QUIRK_LIST = {}
_ASH_ORN.QUIRK_MAP = {}
_ASH_ORN.emptyHintRefs = {} -- ref ke emptyHint label per mesin
for i = 1, #_ASH_ORN.MACHINES do
 _ASH_ORN.QUIRK_LIST[i] = {}
end


_ASH_ORN.STATE = {
 running = {false,false,false,false,false,false,false},
 targets = {{},{},{},{},{},{},{}},
 statLbls = {nil,nil,nil,nil,nil,nil,nil},
 dotRefs = {nil,nil,nil,nil,nil,nil,nil},
 attemptLbls = {nil,nil,nil,nil,nil,nil,nil},
 lastLbls = {nil,nil,nil,nil,nil,nil,nil},
 sumLbls = {nil,nil,nil,nil,nil,nil,nil},
 toggleBtns = {nil,nil,nil,nil,nil,nil,nil},
 toggleKnobs = {nil,nil,nil,nil,nil,nil,nil},
 enOnFlags = {false,false,false,false,false,false,false},
}
ORN = _ASH_ORN.STATE

-- [v38] PGR100 100x Roll Loop Function
-- Perbedaan dari Fastroll biasa:
--   - Kirim remote AutoRandomHeroEquipGrade (100x dalam 1 invoke) dengan stopGradeIds dari dropdown
--   - Server akan berhenti sendiri kalau target ditemukan
--   - Setelah selesai, parse hasil -> tampilkan notifikasi sama seperti Fastroll
PGR100.Loop = function(msi)
  local thread = PGR100.threads[msi]
  if thread then pcall(task.cancel, thread) end

  local function setStatus100(txt, col)
    if PGR100.statLbls[msi] then
      PGR100.statLbls[msi].Text = txt
      PGR100.statLbls[msi].TextColor3 = col or C.TXT2
    end
    if PGR100.dotRefs[msi] then
      PGR100.dotRefs[msi].BackgroundColor3 = col or Color3.fromRGB(100,100,100)
    end
  end

  local function setOff100()
    PGR100.running[msi] = false
    PGR100.enOnFlags[msi] = false
    if PGR100.toggleBtns[msi] then PGR100.toggleBtns[msi].BackgroundColor3 = C.BG3 end
    if PGR100.toggleKnobs[msi] then PGR100.toggleKnobs[msi].Position = UDim2.new(0,2,0.5,-9) end
    setStatus100("[.] Idle", Color3.fromRGB(160,148,135))
  end

  PGR100.running[msi] = true
  PGR100.enOnFlags[msi] = true

  PGR100.threads[msi] = task.spawn(function()
    -- Kumpulkan stopGradeIds dari dropdown target (sama dengan PGR.targets[msi])
    local stopIds = {}
    for gradeId, isSelected in pairs(PGR.targets[msi]) do
      if isSelected then
        table.insert(stopIds, gradeId)
      end
    end

    -- Validasi: harus ada GUID dan target
    if not PGR.guids[msi] or PGR.guids[msi] == "" then
      setStatus100("[..] Click 1x on Reroll Machine", Color3.fromRGB(180,220,255))
      -- Tunggu GUID ter-capture lalu auto-start ulang
      task.spawn(function()
        while PGR100.enOnFlags[msi] do
          if PGR.guids[msi] and PGR.guids[msi] ~= "" then
            PGR100.Loop(msi)
            return
          end
          task.wait(0.5)
        end
      end)
      return
    end

    if #stopIds == 0 then
      setStatus100("[!] SELECT TARGET PLEASE!", Color3.fromRGB(255,100,60))
      setOff100()
      return
    end

    local attempt = 0
    while PGR100.enOnFlags[msi] do
      repeat
        -- [FIX] Cek GUID tiap iterasi (bukan sekali di luar)
        if not (PGR.guids[msi] and PGR.guids[msi] ~= "") then
          setStatus100("[..] Click 1x on Reroll Machine", Color3.fromRGB(180,220,255))
          task.wait(1); break
        end

        -- [FIX] Rebuild stopIds tiap iterasi agar selalu fresh (antisipasi target berubah)
        local stopIds = {}
        for gradeId, isSelected in pairs(PGR.targets[msi]) do
          if isSelected then table.insert(stopIds, gradeId) end
        end
        if #stopIds == 0 then
          setStatus100("[!] SELECT TARGET PLEASE!", Color3.fromRGB(255,100,60))
          task.wait(1); break
        end

        attempt = attempt + 1
        if PGR100.attemptLbls[msi] then
          PGR100.attemptLbls[msi].Text = "100x Batch: #"..attempt
        end
        setStatus100("[~] 100x Roll #"..attempt.."...", Color3.fromRGB(100,200,255))

        -- [FIX] Pastikan pakai AutoRandomHeroEquipGrade (100x remote), bukan fallback 1x
        -- [FIX] Set _ourCall agar spy hook tidak ikut campur
        local autoRemote = Remotes:FindFirstChild("AutoRandomHeroEquipGrade")
        if not autoRemote then
          setStatus100("[!] Remote Auto100x tidak ditemukan!", Color3.fromRGB(255,100,60))
          task.wait(2); break
        end
        _ourCall = true
        local ok, res = pcall(function()
          return autoRemote:InvokeServer({
            drawId = PG_DRAW_IDS[msi],
            stopGradeIds = stopIds,
            guid = PGR.guids[msi],
          })
        end)
        _ourCall = false

        if not ok then
          setStatus100("[!] Error - retry...", Color3.fromRGB(255,100,60))
          task.wait(0.5); break
        end

        -- [FIX] Parse gradeId rekursif deep scan (sama dengan Hero x100)
        local gotId = nil
        if type(res) == "table" then
          -- Pass 1: key prioritas root
          gotId = res.gradeId or res.grade or res.id or res.resultId
          -- Pass 2: res.data nested
          if type(gotId) ~= "number" and type(res.data) == "table" then
            gotId = res.data.grade or res.data.gradeId or res.data.id
          end
          -- Pass 3: scan rekursif seluruh table (termasuk array hasil 100x)
          if type(gotId) ~= "number" then
            local function FindGradeId100(t, depth)
              if type(t) ~= "table" or depth > 4 then return nil end
              -- Cek target dulu (bukan hanya range 990000-999999)
              for k, v in pairs(t) do
                if type(v) == "number" and v > 0 then
                  if PGR.targets[msi][v] then return v end -- langsung hit target
                  if PG_GRADE_MAP[v] then gotId = gotId or v end -- simpan candidate
                elseif type(v) == "table" then
                  local found = FindGradeId100(v, depth+1)
                  if found then return found end
                end
              end
              return nil
            end
            local deepHit = FindGradeId100(res, 1)
            if deepHit then gotId = deepHit end
          end
        end

        local hit = gotId ~= nil and PGR.targets[msi][gotId] == true

        if hit then
          -- TARGET FOUND
          setStatus100("[DONE] Target FOUND! (100x Batch #"..attempt..")", Color3.fromRGB(80,255,120))
          if PGR100.lastLbls[msi] then
            local gradeName = PG_GRADE_MAP[gotId] or "?"
            PGR100.lastLbls[msi].Text = "Last: "..gradeName.." - TARGET!"
          end
          setOff100()
          return
        else
          setStatus100("[OK] 100x Batch #"..attempt.." DONE", Color3.fromRGB(80,180,80))
          if PGR100.lastLbls[msi] then
            local gradeName = gotId and PG_GRADE_MAP[gotId] or "?"
            PGR100.lastLbls[msi].Text = "Last: "..gradeName
          end
        end
        task.wait(0.05)
      until true
    end
    setOff100()
  end)
end

function _ASH_ORN.AddQuirk(machineIdx, quirkId, quirkName)
 if not machineIdx or not quirkId then return end
 local list = _ASH_ORN.QUIRK_LIST[machineIdx]
 if not list then return end
 for _, q in ipairs(list) do
 if q.id == quirkId then
 if quirkName and not quirkName:find("^ID:") then q.name = quirkName end
 return
 end
 end
 table.insert(list, {id=quirkId, name=quirkName or ("ID:"..quirkId)})
 if not _ASH_ORN.QUIRK_MAP[quirkId] then _ASH_ORN.QUIRK_MAP[quirkId] = quirkName or ("ID:"..quirkId) end
end

function _ASH_ORN.GetSummary(mi)
 local names = {}
 for id in pairs(ORN.targets[mi]) do
 table.insert(names, _ASH_ORN.QUIRK_MAP[id] or ("ID:"..tostring(id)))
 end
 table.sort(names)
 if #names == 0 then return "--" end
 if #names == 1 then return names[1] end
 if #names <= 2 then return table.concat(names, ", ") end
 return names[1]..", "..names[2].." +"..(#names-2).." lagi"
end

function _ASH_ORN.SetToggleOff(mi)
 ORN.enOnFlags[mi] = false
 if ORN.toggleBtns[mi] then ORN.toggleBtns[mi].BackgroundColor3 = C.BG3 end
 if ORN.toggleKnobs[mi] then ORN.toggleKnobs[mi].Position = UDim2.new(0,2,0.5,-9) end
end

function _ASH_ORN.DoRoll(mi, on)
 local key = "ornroll"..mi
 ORN.running[mi] = false
 StopLoop(key)

 function setStatus(dot, txt, col)
 if ORN.dotRefs[mi] then ORN.dotRefs[mi].BackgroundColor3 = dot end
 if ORN.statLbls[mi] then ORN.statLbls[mi].Text = txt; ORN.statLbls[mi].TextColor3 = col end
 end

 if not on then
 setStatus(Color3.fromRGB(100,100,100), "[.] Idle", C.TXT2)
 if ORN.attemptLbls[mi] then ORN.attemptLbls[mi].Text = "Attempt: -" end
 if ORN.lastLbls[mi] then ORN.lastLbls[mi].Text = "Last: -" end
 return
 end

 ORN.running[mi] = true

 LOOPS[key] = task.spawn(function()
 local attempt = 0
 setStatus(Color3.fromRGB(255,200,60), "[~] START...", Color3.fromRGB(255,200,60))
 local mInfo = _ASH_ORN.MACHINES[mi]

 while ORN.running[mi] do
 repeat
 if not RE.RerollOrnament then
 RE.RerollOrnament = Remotes:FindFirstChild("RerollOrnament")
 end
 if not RE.RerollOrnament then
 setStatus(Color3.fromRGB(255,80,80), "[!] RerollOrnament NOT FOUND!", Color3.fromRGB(255,80,80))
 task.wait(2); break
 end
 attempt = attempt + 1
 setStatus(Color3.fromRGB(255,160,30), "[~] Roll #"..attempt, C.ACC2)
 if ORN.attemptLbls[mi] then
 ORN.attemptLbls[mi].Text = "Attempt: #"..attempt
 ORN.attemptLbls[mi].TextColor3 = C.TXT2
 end

 local ok, res = pcall(function()
 return RE.RerollOrnament:InvokeServer({machineId=mInfo.machineId, isAuto=false})
 end)
 if not ok then
 setStatus(Color3.fromRGB(255,80,80), "[!] Error (#"..attempt..")", Color3.fromRGB(255,80,80))
 task.wait(0.5); break
 end

 local gotId = nil
 local gotName = ""
 if type(res) == "table" then
 --  PRIORITY 1: Format baru ornament { ornamentIds={[1]=410003}, count=1 } 
 if type(res.ornamentIds) == "table" then
 local oid = res.ornamentIds[1]
 if type(oid) == "number" and oid > 0 then
 gotId = oid
 gotName = _ASH_ORN.QUIRK_MAP[oid] or ("ID:"..tostring(oid))
 _ASH_ORN.AddQuirk(mi, oid, gotName)
 end
 end
 --  PRIORITY 2: Scan nested ornamentIds di sub-table 
 if not gotId then
 local function ScanOrnamentIds(tbl, depth)
 if depth > 4 or type(tbl) ~= "table" or gotId then return end
 if type(tbl.ornamentIds) == "table" then
 local oid = tbl.ornamentIds[1]
 if type(oid) == "number" and oid > 0 then
 gotId = oid
 gotName = _ASH_ORN.QUIRK_MAP[oid] or ("ID:"..tostring(oid))
 _ASH_ORN.AddQuirk(mi, oid, gotName)
 return
 end
 end
 for _, v in pairs(tbl) do
 if type(v) == "table" then ScanOrnamentIds(v, depth+1) end
 end
 end
 ScanOrnamentIds(res, 0)
 end
 --  PRIORITY 3: Fallback scan generic quirkId/resultId/id 
 if not gotId then
 local function ScanAndLearn(tbl, depth)
 if depth > 5 or type(tbl) ~= "table" or gotId then return end
 local id = tbl.quirkId or tbl.finalResultId or tbl.resultId or tbl.ornamentId
 local name = tbl.quirkName or tbl.name or tbl.Name or tbl.title or tbl.displayName
 if type(id) == "number" and id > 0 then
 if type(name) == "string" and #name > 0 and not name:find("^ID:") then
 _ASH_ORN.AddQuirk(mi, id, name)
 if not gotId then gotId = id; gotName = name end
 elseif not gotId then
 gotId = id
 gotName = _ASH_ORN.QUIRK_MAP[id] or ("ID:"..tostring(id))
 end
 end
 for _, v in pairs(tbl) do
 if type(v) == "table" then ScanAndLearn(v, depth+1) end
 end
 end
 ScanAndLearn(res, 0)
 end
 --  PRIORITY 4: Last resort - ambil angka pertama yang masuk akal (4xxxxx) 
 if not gotId then
 local function ScanNum(tbl, depth)
 if depth > 4 or gotId then return end
 for _, v in pairs(tbl) do
 if type(v) == "number" and v >= 400000 and v < 500000 and not gotId then
 gotId = v
 gotName = _ASH_ORN.QUIRK_MAP[v] or ("ID:"..tostring(v))
 _ASH_ORN.AddQuirk(mi, v, gotName)
 elseif type(v) == "table" then ScanNum(v, depth+1) end
 end
 end
 ScanNum(res, 0)
 end
 elseif res == false or res == nil then
 task.wait(0.5); break
 end

 if ORN.lastLbls[mi] then
 ORN.lastLbls[mi].Text = "Last: "..gotName
 ORN.lastLbls[mi].TextColor3 = Color3.fromRGB(180,180,180)
 end

 task.wait(0.1)
 until true
 end
 setStatus(Color3.fromRGB(100,100,100), "[.] STOPPED ("..attempt.."x roll)", C.TXT2)
 if ORN.attemptLbls[mi] then
 ORN.attemptLbls[mi].Text = "Attempt: "..attempt.."x"
 ORN.attemptLbls[mi].TextColor3 = C.TXT2
 end
 end)
end


_spyLog = {}
_layer0Active = false
spyStatusLbl = nil
_HR_RPT = nil -- laporan hero fastroll
_WR_RPT = nil -- laporan weapon fastroll
_watcherConns = {}

-- ============================================================
-- DD LAYER
-- ============================================================
DDLayer = Frame(ScreenGui, C.BLACK, UDim2.new(1,0,1,0))
DDLayer.BackgroundTransparency = 1; DDLayer.ZIndex = 9998; DDLayer.Visible = false
DDLayer.Active = false
DDLayer.Name = "ASH_DD"

_activeDDClose = nil
-- Forward declare AutoRoll functions used in panels (global, cross-scope)
DoAutoRollHero = nil
DoAutoRollWeapon = nil
DoAutoRollPetGear = nil
InitAllCaptureLayers = nil

-- CloseActiveDD: tutup dropdown yang sedang terbuka
CloseActiveDD = function()
 if _activeDDClose then _activeDDClose(); _activeDDClose = nil end
end

-- DDLayer: klik di luar dropdown -> tutup
DDLayer.InputBegan:Connect(function(i)
 if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
 task.defer(CloseActiveDD)
 end
end)


-- DROPDOWN HELPER (shared)
-- ============================================================
MakeGenericDropdown = function(params)
 local ddBtn = params.ddBtn
 local list = params.list
 local maxSel = params.maxSel or 3
 local selTable = params.selTable
 local onRefresh = params.onRefresh
 local summaryLbl= params.summaryLbl
 local qMapRef = params.quirkMapRef or {}

 ddBtn.MouseButton1Click:Connect(function()
 CloseActiveDD()
 local absPos = ddBtn.AbsolutePosition
 local absSize = ddBtn.AbsoluteSize
 local ITEM_H = 28
 local contentH= #list * (ITEM_H + 2) + 10
 local scrollH = math.min(contentH, _isSmallScreen and 170 or 200)
 local popupW = absSize.X + 30
 local HEADER_H= 32

 local popup = Instance.new("Frame")
 popup.Parent = DDLayer; popup.BackgroundColor3 = C.DD_BG; popup.BorderSizePixel = 0
 popup.Size = UDim2.new(0, popupW, 0, HEADER_H + scrollH)
 popup.Position = UDim2.new(0, absPos.X, 0, absPos.Y + absSize.Y + 3)
 popup.ZIndex = 9999; popup.ClipsDescendants = true
 Corner(popup, 10); Stroke(popup, C.BORD2, 1.5, 0.2)

 local hdr = Frame(popup, C.TBAR, UDim2.new(1,0,0,HEADER_H)); hdr.ZIndex = 9999
 local countLbl = Label(hdr, "0/"..maxSel.." SELECTED", 12, C.TXT, Enum.Font.GothamBold)
 countLbl.Size = UDim2.new(0.6,0,1,0); countLbl.Position = UDim2.new(0,8,0,0); countLbl.ZIndex = 9999
 local clrBtn = Btn(hdr, Color3.fromRGB(180,50,50), UDim2.new(0,50,0,20))
 clrBtn.Position = UDim2.new(1,-56,0.5,-10); Corner(clrBtn,5); clrBtn.ZIndex = 9999
 local cL = Label(clrBtn,"Clear",10,Color3.fromRGB(255,255,255),Enum.Font.GothamBold,Enum.TextXAlignment.Center)
 cL.Size = UDim2.new(1,0,1,0); cL.ZIndex = 9999

 local sf = Instance.new("ScrollingFrame")
 sf.Parent = popup; sf.BackgroundTransparency = 1; sf.BorderSizePixel = 0
 sf.Position = UDim2.new(0,0,0,HEADER_H); sf.Size = UDim2.new(1,0,0,scrollH)
 sf.CanvasSize = UDim2.new(0,0,0,contentH)
 sf.ScrollBarThickness = 6; sf.ScrollBarImageColor3 = C.ACC
 sf.ScrollingDirection = Enum.ScrollingDirection.Y; sf.ZIndex = 9999
 Instance.new("UIListLayout",sf).SortOrder = Enum.SortOrder.LayoutOrder
 local sfp = Instance.new("UIPadding",sf)
 sfp.PaddingTop=UDim.new(0,4); sfp.PaddingBottom=UDim.new(0,4)
 sfp.PaddingLeft=UDim.new(0,4); sfp.PaddingRight=UDim.new(0, 10)

 local rowRefs = {}
 function UpdateCount()
 local n = 0; for _ in pairs(selTable) do n = n + 1 end
 countLbl.Text = n.."/"..maxSel.." SELECTED"
 countLbl.TextColor3 = n >= maxSel and Color3.fromRGB(255,100,80) or C.ACC2
 end

 for _, q in ipairs(list) do
 local qRow = Btn(sf, C.DD_BG, UDim2.new(1,-8,0,ITEM_H)); qRow.ZIndex = 9999; Corner(qRow,5)
 local tBox = Frame(qRow, C.SEL_BG, UDim2.new(0,16,0,16))
 tBox.Position = UDim2.new(0,6,0.5,-8); Corner(tBox,3); tBox.ZIndex = 9999; Stroke(tBox,C.BORD2, 1.5,0.4)
 local tMark = Label(tBox,"v",11,C.BLACK,Enum.Font.GothamBold,Enum.TextXAlignment.Center)
 tMark.Size = UDim2.new(1,0,1,0); tMark.ZIndex = 9999
 local isSelected = (selTable[q.id] == true or selTable[q.name] == true)
 tMark.Visible = isSelected
 local qLbl = Label(qRow," "..(q.name or q),11,isSelected and C.ACC2 or C.TXT,Enum.Font.GothamBold)
 qLbl.Size = UDim2.new(1,-30,1,0); qLbl.Position = UDim2.new(0,28,0,0); qLbl.ZIndex = 9999
 if isSelected then qRow.BackgroundColor3 = Color3.fromRGB(140,52,0) end
 local key = q.id or q.name or q
 rowRefs[key] = {bg=qRow, tick=tMark, lbl=qLbl}

 qRow.MouseButton1Click:Connect(function()
 if selTable[key] then
 selTable[key] = nil
 else
 local n = 0; for _ in pairs(selTable) do n = n + 1 end
 if n >= maxSel then
 local old = countLbl.Text
 countLbl.Text = "MAX "..maxSel.." SUCCES!"; countLbl.TextColor3 = Color3.fromRGB(255,60,60)
 task.delay(1.2, function() UpdateCount() end)
 return
 end
 selTable[key] = true
 end
 for k2, ref in pairs(rowRefs) do
 local sel = (selTable[k2] == true)
 ref.bg.BackgroundColor3 = sel and Color3.fromRGB(140,52,0) or C.DD_BG
 ref.tick.Visible = sel; ref.lbl.TextColor3 = sel and C.ACC2 or C.TXT
 end
 UpdateCount()
 if onRefresh then onRefresh() end
 end)
 end
 UpdateCount()
 clrBtn.MouseButton1Click:Connect(function()
 for k2 in pairs(selTable) do selTable[k2] = nil end
 for _, ref in pairs(rowRefs) do
 ref.bg.BackgroundColor3 = C.DD_BG; ref.tick.Visible = false; ref.lbl.TextColor3 = C.TXT
 end
 UpdateCount(); if onRefresh then onRefresh() end
 end)
 DDLayer.Visible = true
 _activeDDClose = function() popup:Destroy(); DDLayer.Visible = false end
 end)
end

-- ============================================================
-- PANEL : MAIN
-- ============================================================
do
 local p = NewPanel("main")
 -- [v186] FIX: deklarasi variabel yang hilang
 local _autoSellOn = false
 local _sellConn = nil
 local _lockedGuids = {}
 local _cnt = {R=0, Y=0, B=0, other=0, skipped=0}
 local _sellToggleCb = nil

 -- ============================================================
 -- LOGIKA AUTO HIDE REWARD
 -- ============================================================
 local _autoHideConn = nil
 local _autoHideRemotes = {}
 STATE.autoHideReward = false

 local function DoAutoHideReward(on)
        STATE.autoHideReward = on
        if on then
            local HIDE_PANELS = {"RewardsFrame", "ResultFrame", "RewardPanel", "ChallengeGarrisonBossSuccess"}
            local function forceHide(obj)
                if not obj or not obj.Parent then return end
                pcall(function()
                    if obj:IsA("GuiObject") then
                        obj.Visible = false
                        obj.Position = UDim2.new(2, 0, 2, 0)
                    elseif obj:IsA("ScreenGui") then
                        obj.Enabled = false
                    end
                end)
            end

         local function checkAndHide(obj)
             if not STATE.autoHideReward then return end
             if not (obj:IsA("GuiObject") or obj:IsA("ScreenGui")) then return end
             
             for _, name in ipairs(HIDE_PANELS) do
                 if obj.Name == name or obj.Name:find("GarrisonBoss") then
                     task.wait(0.1)
                     if STATE.autoHideReward then forceHide(obj) end
                     pcall(function()
                         if obj:IsA("GuiObject") then
                             obj:GetPropertyChangedSignal("Visible"):Connect(function()
                                 if STATE.autoHideReward and obj.Visible then forceHide(obj) end
                             end)
                         elseif obj:IsA("ScreenGui") then
                             obj:GetPropertyChangedSignal("Enabled"):Connect(function()
                                 if STATE.autoHideReward and obj.Enabled then forceHide(obj) end
                             end)
                         end
                     end)
                     break
                 end
             end
         end

         -- Scan existing
         for _, obj in ipairs(LP.PlayerGui:GetDescendants()) do checkAndHide(obj) end
        -- Ghost Polling untuk Auto Hide
            task.spawn(function()
                while STATE.autoHideReward do
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
    end-- ============================================================
-- FITUR: DISABLE ALL ANIMATIONS & DAMAGE TEXT (GHOST POLLING)
-- ============================================================
local _dmgTextConnWorkspace = nil
local _animLoopConn = nil
STATE.disableAnim = false

local function DoDisableAllAnimations(on)
        STATE.disableAnim = on
        if on then
            _animLoopConn = RunService.RenderStepped:Connect(function()
                pcall(function()
                    local hFolder = workspace:FindFirstChild("Heros") or workspace:FindFirstChild("Pets")
                    if hFolder then
                        for _, hero in ipairs(hFolder:GetChildren()) do
                            local hum = hero:FindFirstChildOfClass("Humanoid") or hero:FindFirstChildOfClass("AnimationController")
                            if hum then
                                local animator = hum:FindFirstChildOfClass("Animator")
                                if animator then
                                    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                                        track:Stop(); track:AdjustSpeed(0)
                                    end
                                end
                            end
                        end
                    end
                end)
            end)

        -- 2. RAZIA ALAM 3D (WORKSPACE) -> AMAN DARI CRASH
        _dmgTextConnWorkspace = workspace.DescendantAdded:Connect(function(obj)
            task.defer(function()
                pcall(function()
                    if obj:IsA("BillboardGui") then
                        local n = obj.Name:lower()
                        if not n:find("name") and not n:find("health") then
                            obj.Enabled = false
                        end
                    elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("PointLight") or obj:IsA("Fire") or obj:IsA("Sparkles") then
                        obj.Enabled = false
                    elseif obj:IsA("BasePart") then
                        local n = obj.Name:lower()
                        if n:find("effect") or n:find("skill") or n:find("slash") or n:find("hit") or n:find("blast") or n:find("projectile") or n:find("magic") then
                            obj.Transparency = 1
                            if obj:IsA("MeshPart") then obj.TextureID = "" end
                        end
                    end
                end)
            end)
        end)

        -- 3. RAZIA DI LAYAR 2D (PLAYER GUI) -> GHOST POLLING (ANTI CRASH)
        task.spawn(function()
            while STATE.disableAnim do
                task.wait(0.1)
                pcall(function()
                    for _, obj in ipairs(LP.PlayerGui:GetChildren()) do
                        -- Sembunyikan BillboardGui Damage
                        if obj:IsA("BillboardGui") and (obj.Name:lower():find("damage") or obj.Name:lower():find("hit")) then
                            obj.Enabled = false
                        end
                        -- Sembunyikan TextLabel Damage
                        if obj.Name:lower():find("damage") or obj.Name:lower():find("hit") or obj.Name:lower():find("msg") then
                            if obj:IsA("GuiObject") then 
                                obj.Visible = false
                                obj.Position = UDim2.new(2, 0, 2, 0) 
                            end
                            if obj:IsA("ScreenGui") then obj.Enabled = false end
                        end
                    end
                end)
            end
        end)

        -- 4. BASMI YANG SUDAH TERLANJUR ADA
        pcall(function()
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("BillboardGui") and not obj.Name:lower():find("name") and not obj.Name:lower():find("health") then 
                    obj.Enabled = false 
                elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") then
                    obj.Enabled = false
                end
            end
            for _, obj in ipairs(LP.PlayerGui:GetDescendants()) do
                if obj:IsA("TextLabel") and (obj.Text:match("^%-") or obj.Name:lower():find("damage")) then
                    obj.Visible = false
                end
            end
        end)

    else
        -- [RESTORE NORMAL]
        if _animLoopConn then _animLoopConn:Disconnect(); _animLoopConn = nil end
        if _dmgTextConnWorkspace then _dmgTextConnWorkspace:Disconnect(); _dmgTextConnWorkspace = nil end
        
        -- Nyalakan lagi efek aura pada hero
        pcall(function()
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") then
                    obj.Enabled = true
                end
            end
        end)
    end
end
 --  Counter laporan (DI ATAS toggle) 
 local cntCard = Frame(p, C.BG3, UDim2.new(1,0,0,0))
 cntCard.LayoutOrder=1; cntCard.AutomaticSize=Enum.AutomaticSize.Y
 Corner(cntCard, 10); Stroke(cntCard,C.BORD, 1.5,0.5)
 Padding(cntCard,4,4,8,8)
 New("UIListLayout",{Parent=cntCard,SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,3)})

 local cntRow1 = Frame(cntCard,C.BG2,UDim2.new(1,0,0,28))
 cntRow1.LayoutOrder=1; Corner(cntRow1,6)
 local rLbl=Label(cntRow1,"R-Pet: 0",13,Color3.fromRGB(255,110,110),Enum.Font.GothamBold)
 rLbl.Size=UDim2.new(0.25,0,1,0); rLbl.Position=UDim2.new(0,6,0,0)
 rLbl.TextXAlignment=Enum.TextXAlignment.Left
 local yLbl=Label(cntRow1,"Y-Pet: 0",13,Color3.fromRGB(255,230,60),Enum.Font.GothamBold)
 yLbl.Size=UDim2.new(0.25,0,1,0); yLbl.Position=UDim2.new(0.25,0,0,0)
 yLbl.TextXAlignment=Enum.TextXAlignment.Center
 local bLbl=Label(cntRow1,"B-Pet: 0",13,Color3.fromRGB(100,210,255),Enum.Font.GothamBold)
 bLbl.Size=UDim2.new(0.25,0,1,0); bLbl.Position=UDim2.new(0.5,0,0,0)
 bLbl.TextXAlignment=Enum.TextXAlignment.Center
 local skipLbl=Label(cntRow1,"Supreme: 0",13,C.ACC2,Enum.Font.GothamBold)
 skipLbl.Size=UDim2.new(0.25,0,1,0); skipLbl.Position=UDim2.new(0.75,0,0,0)
 skipLbl.TextXAlignment=Enum.TextXAlignment.Right

 local resetBtn=Btn(cntCard,C.BG2,UDim2.new(1,0,0,22))
 resetBtn.LayoutOrder=2; Corner(resetBtn,6); Stroke(resetBtn,C.BORD, 1.5,0.6)
 local resetLbl=Label(resetBtn,"RESET COUTER",11,C.DIM,Enum.Font.GothamBold,Enum.TextXAlignment.Center)
 resetLbl.Size=UDim2.new(1,0,1,0)

 local function RefreshCounters()
 pcall(function()
 rLbl.Text = "R-Pet: ".._cnt.R
 yLbl.Text = "Y-Pet: ".._cnt.Y
 bLbl.Text = "B-Pet: ".._cnt.B
 skipLbl.Text = "Supreme: ".._cnt.skipped
 end)
 end
 resetBtn.MouseButton1Click:Connect(function()
 _cnt={R=0,Y=0,B=0,other=0,skipped=0}; RefreshCounters()
 SetSellStatus("[OK] DONE RESET", Color3.fromRGB(160,220,160))
 end)

--  [NEW] Toggle Auto Hide Reward
 local _autoHideRow, _autoHideSet, _autoHideVis = ToggleRow(p, "AUTO HIDE REWARD", "Sembunyikan popup item", 1, function(on)
     DoAutoHideReward(on)
 end)
 _setAutoHideToggle = _autoHideSet
 _visAutoHide = _autoHideVis
 _autoHideRow.Name = "ZZZ_AutoHide" -- Trik aman! Memaksa posisinya di bawah Count RYB (LayoutOrder 1) tanpa merusak/menggeser LayoutOrder tombol lain.

 --  Toggle Auto Sell (DI BAWAH counter) 
 local _sellToggleRow, _sellToggleSet, _sellVis = ToggleRow(p,"AUTO SELL HERO EQUIP","Auto sell all items (except Locked)",4,function(on)
 _autoSellOn = on
 _autoSellOnState = on
 if _sellToggleCb then _sellToggleCb(on) end
 end)
 _setSellHeroToggle = _sellToggleSet
 _visSellHero = _sellVis

 --  Status bar 
 local function SetSellStatus(msg, col)
 pcall(function()
 sellStLbl.Text = msg
 sellStLbl.TextColor3 = col or C.DIM
 sellDot.BackgroundColor3 = col or C.BG3
 end)
 end

 -- GUID name cache
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

 -- Ambil tipe (R/Y/B) dari nama item
 local function getType(name)
 if not name or #name == 0 then return "other" end
 local f = name:sub(1,1):upper()
 if f=="R" then return "R" elseif f=="Y" then return "Y" elseif f=="B" then return "B"
 else return "other" end
 end

 -- Ambil grade dari nama item: "Y-Star Sapphire [M]" -> "M"
 -- Format: huruf/kode grade biasanya ada di awal nama setelah tipe
 -- misal "Y-Star [M+] ..." atau grade dari field data
 local function getGrade(item)
 local d = (item.data and type(item.data)=="table") and item.data or item
 -- Coba dari field grade di data
 local g = d.grade or d.Grade or d.gradeId or d.gradeType
 if g then return tostring(g):upper() end
 -- Coba parse dari nama item: cari bracket [X] atau [M+] dll
 local name = item.name or item.Name or item.itemName or d.name or ""
 local found = name:match("%[M%+%+%]") and "M++" or name:match("%[M%+%]") and "M+" or name:match("%[SS%]") and "SS" or name:match("%[([EDCBAGSNMedcbagsn])%]")
 if found then return found:upper() end
 return nil -- tidak diketahui
 end

 -- Cek apakah item harus dijual berdasarkan filter
 local function shouldSell(item, name, isLock)
 -- Rule 1: locked -> skip
 if isLock then return false, "locked" end
 -- Rule 2: Supreme -> skip
 if name and name:lower():find("supreme", 1, true) then return false, "Supreme" end
 -- Rule 3: cek tipe
 local typ = getType(name)
 if typ ~= "other" and not _sellTypes[typ] then return false, "tipe "..typ.." dimatikan" end
 -- Rule 4: cek grade
 local grade = getGrade(item)
 if grade then
 local itemRank = _SELL_GRADE_RANK[grade] or 0
 local minRank = _SELL_GRADE_RANK[_minGrade] or 1
 if itemRank >= minRank then return false, "grade "..grade.." >= min ".._minGrade end
 end
 return true, ""
 end

 local function doSell(guid, name)
 -- [v186] Confirmed SimpleSpy: DelectHeroEquips:FireServer({guid})
 local remote = Remotes:FindFirstChild("DelectHeroEquips")
 if not remote then return end
 pcall(function()
 remote:FireServer({guid})
 local prefix = getType(name)
 _cnt[prefix] = (_cnt[prefix] or 0) + 1
 RefreshCounters()
 SetSellStatus("Sold ["..((_cnt.R+_cnt.Y+_cnt.B+_cnt.other)).."] "..name:sub(1,24), Color3.fromRGB(255,160,40))
 end)
 end

 local function StartAutoSell()
 if _sellConn then pcall(function() _sellConn:Disconnect() end) end
 local updateRemote = Remotes:FindFirstChild("UpdateHeroEquip")
 if not updateRemote then SetSellStatus("[!] NOT FOUND!", C.RED); return end
 scanGuidNames()

 pcall(function()
 local lockR = Remotes:FindFirstChild("LockHeroEquip")
 local unlockR = Remotes:FindFirstChild("UnlockHeroEquip")
 if lockR then lockR.OnClientEvent:Connect(function(d)
 local g=type(d)=="string" and d or (type(d)=="table" and (d.guid or d[1])) or nil
 if g then _lockedGuids[g]=true end
 end) end
 if unlockR then unlockR.OnClientEvent:Connect(function(d)
 local g=type(d)=="string" and d or (type(d)=="table" and (d.guid or d[1])) or nil
 if g then _lockedGuids[g]=nil end
 end) end
 end)

 _sellConn = updateRemote.OnClientEvent:Connect(function(data)
 if not _autoSellOn then return end
 if type(data) ~= "table" then return end
 task.spawn(function()
 task.wait(0.3)
 -- [v186] Struktur confirmed dari sniff:
 -- item = { guid="...", data = { id=970002, isLock=bool, grade=990001, guid="..." } }
 local items = {}
 if data.heroEquips and type(data.heroEquips)=="table" then items=data.heroEquips
 elseif data[1] and type(data[1])=="table" then items=data
 elseif data.guid then items={data} end

 for _, item in ipairs(items) do
 if not _autoSellOn then break end

 local guid = item.guid
 if guid and #tostring(guid)>0 then
     local d = (item.data and type(item.data)=="table") and item.data or item
     local isLock = d.isLock or d.locked or d.isLocked or false
     if _lockedGuids[tostring(guid)] then isLock = true end

     if not isLock then
         -- Scan UI dulu biar nama item tersedia
         scanGuidNames()
         local name = _guidNames[tostring(guid)] or ""
         local prefix = getType(name)

         task.wait(0.15)
         local remote = Remotes:FindFirstChild("DelectHeroEquips")
         if remote then
             local ok = pcall(function() remote:FireServer({tostring(guid)}) end)
             if ok then
                 _cnt[prefix] = (_cnt[prefix] or 0) + 1
                 RefreshCounters()
                 local total = _cnt.R + _cnt.Y + _cnt.B + _cnt.other
                 local label = #name > 0 and name:sub(1,20) or ("ID:"..tostring(d.id or "?"))
                 SetSellStatus("Sold ["..total.."] "..prefix..": "..label, Color3.fromRGB(255,160,40))
             end
         end
     end
 end
 end
 task.delay(0.5, scanGuidNames)
 end)
 end)
 SetSellStatus("[OK] Monitoring Active - Sell All except Locked", Color3.fromRGB(100,220,100))
 end

 _sellToggleCb = function(on)
 if on then
 StartAutoSell()
 else
 if _sellConn then pcall(function() _sellConn:Disconnect() end); _sellConn = nil end
 local total = _cnt.R + _cnt.Y + _cnt.B + _cnt.other
 SetSellStatus("Idle - "..total.." SELL", C.BG3)
 end
 end

 -- Divider
 local divMain = Frame(p, C.BORD, UDim2.new(1,0,0,1))
 divMain.LayoutOrder=6; divMain.BackgroundTransparency=0.42

 -- ============================================================
 -- AUTO SELL WEAPON [v56b FIX] + WEAPON FILTER DROPDOWN
 -- Persistent listener di UpdateWeapon.OnClientEvent
 -- Dropdown pakai DDLayer (sistem existing) - no MaxSize bug
 -- LayoutOrder: swRow=6, swDropCard=7, swStatusCard=8
 --              dgRow=8, dgSliderCard=9 (geser +2)
 -- ============================================================

 local WEAPON_LIST = {
  {180002, "Nail", 1, Color3.fromRGB(200,200,200)},
  {180003, "Crimson Dragon", 2, Color3.fromRGB(100,200,255)},
  {180004, "Knight's Oath", 3, Color3.fromRGB(200,100,255)},
  {180005, "Staff", 4, Color3.fromRGB(255,160,40)},
  {180006, "ToothScepter", 5, Color3.fromRGB(255,80,80)},
  {180007, "Gleaming", 5, Color3.fromRGB(255,80,80)},
  {180008, "Underworld", 1, Color3.fromRGB(200,200,200)},
  {180009, "SwordOfDarkness", 2, Color3.fromRGB(100,200,255)},
  {180010, "BlackHoleSword", 3, Color3.fromRGB(200,100,255)},
  {180011, "Starlight", 4, Color3.fromRGB(255,160,40)},
  {180012, "VoidSword", 5, Color3.fromRGB(255,80,80)},
  {180013, "Cyberpunk", 5, Color3.fromRGB(255,80,80)},
  {180014, "Crescendo", 1, Color3.fromRGB(200,200,200)},
  {180015, "JupiterSword", 2, Color3.fromRGB(100,200,255)},
  {180016, "Obsidian Shard", 3, Color3.fromRGB(200,100,255)},
  {180017, "redtide", 4, Color3.fromRGB(255,160,40)},
  {180018, "Blazing Fury", 5, Color3.fromRGB(255,80,80)},
  {180019, "Ashbringer", 5, Color3.fromRGB(255,80,80)},
  {180020, "ValentineSword", 1, Color3.fromRGB(200,200,200)},
  {180021, "Frost Serpent", 2, Color3.fromRGB(100,200,255)},
  {180022, "OceanSamurai", 3, Color3.fromRGB(200,100,255)},
  {180023, "SnakeSpear", 4, Color3.fromRGB(255,160,40)},
  {180024, "Skywalker", 5, Color3.fromRGB(255,80,80)},
  {180025, "Crystalline", 5, Color3.fromRGB(255,80,80)},
  {180026, "MoonKatana", 1, Color3.fromRGB(200,200,200)},
  {180027, "Azure Blue", 2, Color3.fromRGB(100,200,255)},
  {180028, "PurpleMagicSword", 3, Color3.fromRGB(200,100,255)},
  {180029, "InternalDemonSword", 4, Color3.fromRGB(255,160,40)},
  {180030, "Abyssal Scythe", 5, Color3.fromRGB(255,80,80)},
  {180031, "Stellar Domain", 5, Color3.fromRGB(255,80,80)},
  {180032, "Skeletal", 1, Color3.fromRGB(200,200,200)},
  {180033, "Holy Sword", 2, Color3.fromRGB(100,200,255)},
  {180034, "The breath of water", 3, Color3.fromRGB(200,100,255)},
  {180035, "DiamondBladeSword", 4, Color3.fromRGB(255,160,40)},
  {180036, "Thunderfury", 5, Color3.fromRGB(255,80,80)},
  {180037, "Hailstorm", 5, Color3.fromRGB(255,80,80)},
  {180038, "LightningRage", 1, Color3.fromRGB(200,200,200)},
  {180039, "TechSword", 2, Color3.fromRGB(100,200,255)},
  {180040, "BatScythe", 3, Color3.fromRGB(200,100,255)},
  {180041, "Widowmaker", 4, Color3.fromRGB(255,160,40)},
  {180042, "Dragonscale", 5, Color3.fromRGB(255,80,80)},
  {180043, "DarkFire", 5, Color3.fromRGB(255,80,80)},
  {180044, "DullBlade", 1, Color3.fromRGB(200,200,200)},
  {180045, "Batwing", 2, Color3.fromRGB(100,200,255)},
  {180046, "CoolSteel", 3, Color3.fromRGB(200,100,255)},
  {180047, "WinterEdge", 4, Color3.fromRGB(255,160,40)},
  {180048, "IcedTomahawk", 5, Color3.fromRGB(255,80,80)},
  {180049, "TheFlute", 5, Color3.fromRGB(255,80,80)},
  {180050, "Wailing Eye\227\128\144\226\133\160\227\128\145", 5, Color3.fromRGB(255,80,80)},
  {180051, "GlareHammer\227\128\144\226\133\160\227\128\145", 5, Color3.fromRGB(255,80,80)},
  {180052, "Wailing Eye\227\128\144\226\133\161\227\128\145", 5, Color3.fromRGB(255,80,80)},
  {180053, "GlareHammer\227\128\144\226\133\161\227\128\145", 5, Color3.fromRGB(255,80,80)},
  {180054, "Wailing Eye\227\128\144\226\133\162\227\128\145", 5, Color3.fromRGB(255,80,80)},
  {180055, "GlareHammer\227\128\144\226\133\162\227\128\145", 5, Color3.fromRGB(255,80,80)},
  {180056, "InfiniteSword", 1, Color3.fromRGB(200,200,200)},
  {180057, "PeerlessSword", 2, Color3.fromRGB(100,200,255)},
  {180058, "SandSword", 3, Color3.fromRGB(200,100,255)},
  {180059, "FlyingSword", 4, Color3.fromRGB(255,160,40)},
  {180060, "Recursion's Edge", 5, Color3.fromRGB(255,80,80)},
  {180061, "Night", 5, Color3.fromRGB(255,80,80)},
  {180062, "Silence of Aporia", 1, Color3.fromRGB(200,200,200)},
  {180063, "Lacuna Blade", 2, Color3.fromRGB(100,200,255)},
  {180064, "Zephyr's Grief", 3, Color3.fromRGB(200,100,255)},
  {180065, "Axiom's Verdict", 4, Color3.fromRGB(255,160,40)},
  {180066, "Fractalized Borealis", 5, Color3.fromRGB(255,80,80)},
  {180067, "Destiny", 5, Color3.fromRGB(255,80,80)},
  {180068, "Violet Lightning", 1, Color3.fromRGB(200,200,200)},
  {180073, "Tech Sword", 5, Color3.fromRGB(255,80,80)},
  {180074, "BlueLaserSword", 1, Color3.fromRGB(200,200,200)},
  {180077, "SpiderSword", 4, Color3.fromRGB(255,160,40)},
  {180078, "DragonFireSword", 5, Color3.fromRGB(255,80,80)},
  {180079, "Scourge", 5, Color3.fromRGB(255,80,80)},
  {180081, "Molten Lava", 2, Color3.fromRGB(100,200,255)},
  {180082, "Venomous Eye", 3, Color3.fromRGB(200,100,255)},
  {180084, "Cursed Bone", 5, Color3.fromRGB(255,80,80)},
  {180085, "Thunder Breath", 5, Color3.fromRGB(255,80,80)},
  {180086, "DragonSlayer[gold]", 1, Color3.fromRGB(200,200,200)},
  {180087, "MoonKatana[gold]", 2, Color3.fromRGB(100,200,255)},
  {180088, "MoonSlasher[gold]", 3, Color3.fromRGB(200,100,255)},
  {180089, "Pills[gold]", 4, Color3.fromRGB(255,160,40)},
  {180090, "SixPathsStaff", 5, Color3.fromRGB(255,80,80)},
  {180091, "Reapers", 5, Color3.fromRGB(255,80,80)},
  {180092, "Infernal Saber", 1, Color3.fromRGB(200,200,200)},
  {180093, "Infernal Cross", 2, Color3.fromRGB(100,200,255)},
  {180096, "Sulfuras", 5, Color3.fromRGB(255,80,80)},
  {180097, "Emberclaw Edge", 5, Color3.fromRGB(255,80,80)},
  {180098, "Stellar Prism", 1, Color3.fromRGB(200,200,200)},
  {180099, "Legacy Argent", 2, Color3.fromRGB(100,200,255)},
  {180100, "Aether Wingblade", 3, Color3.fromRGB(200,100,255)},
  {180101, "Celestia's Crescent", 4, Color3.fromRGB(255,160,40)},
  {180102, "MechanicalKatana", 5, Color3.fromRGB(255,80,80)},
  {180103, "Shadow Sovereign Blade", 5, Color3.fromRGB(255,80,80)},
  {180104, "Starcrest Blade", 1, Color3.fromRGB(200,200,200)},
  {180105, "Jadevine Blade", 2, Color3.fromRGB(100,200,255)},
  {180106, "Scarlet Thornrose Blade", 3, Color3.fromRGB(200,100,255)},
  {180107, "Holy Azure Saber", 4, Color3.fromRGB(255,160,40)},
  {180108, "Aetherial Blade", 5, Color3.fromRGB(255,80,80)},
  {180109, "Solar Flare Reckoning", 5, Color3.fromRGB(255,80,80)},
  {180110, "Redwing Blade", 1, Color3.fromRGB(200,200,200)},
  {180111, "Silver Knight", 2, Color3.fromRGB(100,200,255)},
  {180112, "Starvein Petal", 3, Color3.fromRGB(200,100,255)},
  {180113, "Hornchain Scale", 4, Color3.fromRGB(255,160,40)},
  {180114, "Beastvine Amethyst", 5, Color3.fromRGB(255,80,80)},
  {180115, "Cloud Dragon", 5, Color3.fromRGB(255,80,80)},
  {180116, "SchoolKernel[gold]", 1, Color3.fromRGB(200,200,200)},
  {180117, "LightningRage[gold]", 2, Color3.fromRGB(100,200,255)},
  {180118, "GoldifiedLightning[gold]", 3, Color3.fromRGB(200,100,255)},
  {180119, "DoubleEdge[gold]", 4, Color3.fromRGB(255,160,40)},
  {180121, "RainbowSword", 5, Color3.fromRGB(255,80,80)},
  {180122, "SerratedSword[gold]", 1, Color3.fromRGB(200,200,200)},
  {180123, "AstralStaff[gold]", 2, Color3.fromRGB(100,200,255)},
  {180124, "PixelSword[gold]", 3, Color3.fromRGB(200,100,255)},
  {180125, "Underworld[gold]", 4, Color3.fromRGB(255,160,40)},
  {180127, "GoldenLegendary", 5, Color3.fromRGB(255,80,80)},
  {180128, "Glowbone", 5, Color3.fromRGB(255,80,80)},
  {180129, "Divine Purge Claymore", 5, Color3.fromRGB(255,80,80)},
  {180130, "Ember Blade\227\128\144\226\133\160\227\128\145", 5, Color3.fromRGB(255,80,80)},
  {180131, "Ember Blade\227\128\144\226\133\161\227\128\145", 5, Color3.fromRGB(255,80,80)},
  {180132, "Ember Blade\227\128\144\226\133\162\227\128\145", 5, Color3.fromRGB(255,80,80)},
  {180133, "Ember Blade+1\227\128\144\226\133\160\227\128\145", 5, Color3.fromRGB(255,80,80)},
  {180134, "Ember Blade+1\227\128\144\226\133\161\227\128\145", 5, Color3.fromRGB(255,80,80)},
  {180135, "Ember Blade+1\227\128\144\226\133\162\227\128\145", 5, Color3.fromRGB(255,80,80)},
  {180136, "Skullhorn Staff\227\128\144\226\133\160\227\128\145", 5, Color3.fromRGB(255,80,80)},
  {180137, "Skullhorn Staff\227\128\144\226\133\161\227\128\145", 5, Color3.fromRGB(255,80,80)},
  {180138, "Skullhorn Staff\227\128\144\226\133\162\227\128\145", 5, Color3.fromRGB(255,80,80)},
  {180139, "Skullhorn Staff+1\227\128\144\226\133\160\227\128\145", 5, Color3.fromRGB(255,80,80)},
  {180140, "Skullhorn Staff+1\227\128\144\226\133\161\227\128\145", 5, Color3.fromRGB(255,80,80)},
  {180141, "Skullhorn Staff+1\227\128\144\226\133\162\227\128\145", 5, Color3.fromRGB(255,80,80)},
  {180142, "Violet Briar Dagger\227\128\144\226\133\160\227\128\145", 5, Color3.fromRGB(255,80,80)},
  {180143, "Violet Briar Dagger\227\128\144\226\133\161\227\128\145", 5, Color3.fromRGB(255,80,80)},
  {180144, "Violet Briar Dagger\227\128\144\226\133\162\227\128\145", 5, Color3.fromRGB(255,80,80)},
  {180145, "Violet Briar Dagger+1\227\128\144\226\133\160\227\128\145", 5, Color3.fromRGB(255,80,80)},
  {180146, "Violet Briar Dagger+1\227\128\144\226\133\161\227\128\145", 5, Color3.fromRGB(255,80,80)},
  {180147, "Violet Briar Dagger+1\227\128\144\226\133\162\227\128\145", 5, Color3.fromRGB(255,80,80)},
  {180148, "GlareHammer+1\227\128\144\226\133\160\227\128\145", 5, Color3.fromRGB(255,80,80)},
  {180149, "GlareHammer+1\227\128\144\226\133\161\227\128\145", 5, Color3.fromRGB(255,80,80)},
  {180150, "GlareHammer+1\227\128\144\226\133\162\227\128\145", 5, Color3.fromRGB(255,80,80)},
  {180154, "Wailing Eye+1\227\128\144\226\133\160\227\128\145", 5, Color3.fromRGB(255,80,80)},
  {180155, "Wailing Eye+1\227\128\144\226\133\161\227\128\145", 5, Color3.fromRGB(255,80,80)},
  {180156, "Wailing Eye+1\227\128\144\226\133\162\227\128\145", 5, Color3.fromRGB(255,80,80)},
  {180160, "Stellarmoon Staff\227\128\144\226\133\160\227\128\145", 5, Color3.fromRGB(255,80,80)},
  {180161, "Stellarmoon Staff\227\128\144\226\133\161\227\128\145", 5, Color3.fromRGB(255,80,80)},
  {180162, "Stellarmoon Staff\227\128\144\226\133\162\227\128\145", 5, Color3.fromRGB(255,80,80)},
  {180163, "Stellarmoon Staff+1\227\128\144\226\133\160\227\128\145", 5, Color3.fromRGB(255,80,80)},
  {180164, "Stellarmoon Staff+1\227\128\144\226\133\161\227\128\145", 5, Color3.fromRGB(255,80,80)},
  {180165, "Stellarmoon Staff+1\227\128\144\226\133\162\227\128\145", 5, Color3.fromRGB(255,80,80)},
  {180166, "Crystalcrown Blade\227\128\144\226\133\160\227\128\145", 5, Color3.fromRGB(255,80,80)},
  {180167, "Crystalcrown Blade\227\128\144\226\133\161\227\128\145", 5, Color3.fromRGB(255,80,80)},
  {180168, "Crystalcrown Blade\227\128\144\226\133\162\227\128\145", 5, Color3.fromRGB(255,80,80)},
  {180169, "Crystalcrown Blade+1\227\128\144\226\133\160\227\128\145", 5, Color3.fromRGB(255,80,80)},
  {180170, "Crystalcrown Blade+1\227\128\144\226\133\161\227\128\145", 5, Color3.fromRGB(255,80,80)},
  {180171, "Crystalcrown Blade+1\227\128\144\226\133\162\227\128\145", 5, Color3.fromRGB(255,80,80)},
  {180172, "Redspine Claw\227\128\144\226\133\160\227\128\145", 5, Color3.fromRGB(255,80,80)},
  {180173, "Redspine Claw\227\128\144\226\133\161\227\128\145", 5, Color3.fromRGB(255,80,80)},
  {180174, "Redspine Claw\227\128\144\226\133\162\227\128\145", 5, Color3.fromRGB(255,80,80)},
  {180175, "Redspine Claw+1\227\128\144\226\133\160\227\128\145", 5, Color3.fromRGB(255,80,80)},
  {180176, "Redspine Claw+1\227\128\144\226\133\161\227\128\145", 5, Color3.fromRGB(255,80,80)},
  {180177, "Redspine Claw+1\227\128\144\226\133\162\227\128\145", 5, Color3.fromRGB(255,80,80)},
  {180178, "Purplecrack Blade\227\128\144\226\133\160\227\128\145", 5, Color3.fromRGB(255,80,80)},
  {180179, "Purplecrack Blade\227\128\144\226\133\161\227\128\145", 5, Color3.fromRGB(255,80,80)},
  {180180, "Purplecrack Blade\227\128\144\226\133\162\227\128\145", 5, Color3.fromRGB(255,80,80)},
  {180181, "Purplecrack Blade+1\227\128\144\226\133\160\227\128\145", 5, Color3.fromRGB(255,80,80)},
  {180182, "Purplecrack Blade+1\227\128\144\226\133\161\227\128\145", 5, Color3.fromRGB(255,80,80)},
  {180183, "Purplecrack Blade+1\227\128\144\226\133\162\227\128\145", 5, Color3.fromRGB(255,80,80)},
  {180184, "Holly Cane Sword", 5, Color3.fromRGB(255,80,80)},
  {180185, "CandyCanes2025", 5, Color3.fromRGB(255,80,80)},
  {180186, "Crimson Heart Katana", 5, Color3.fromRGB(255,80,80)},
  {180187, "Holy Vine Lance", 5, Color3.fromRGB(255,80,80)},
  {180188, "Wind Wing Saber", 5, Color3.fromRGB(255,80,80)},
  {180189, "Starfall Greatsword", 5, Color3.fromRGB(255,80,80)},
  {180190, "Celestial Wing Sword", 5, Color3.fromRGB(255,80,80)},
}

 -- Matcher: return function(itemId)->bool
 local function BuildWeaponMatcher(selectAll, selectedIds)
  if selectAll or not next(selectedIds) then
   return function() return true end
  end
  return function(itemId)
   return itemId and selectedIds[itemId] == true
  end
 end

 local _autoSellWeaponOn = false
 local _swConn           = nil
 local _swSoldCount      = 0
 local _swSelectAll      = true            -- true = jual semua
 local _swSelectedIds    = {}              -- {[equipId]=true}
 local _swSelNames       = {}              -- {[equipId]=name}

 -- -- Toggle row ----------------------------------------------
 local swRow = Frame(p, C.SURFACE, UDim2.new(1,0,0,44))
 swRow.LayoutOrder = 6; Corner(swRow,10); Stroke(swRow, C.BORD, 1.5, 0.3)
 local swLbl = Label(swRow, "AUTO SELL WEAPON", 13, C.TXT, Enum.Font.GothamBold)
 swLbl.Size = UDim2.new(1,-68,0,20); swLbl.Position = UDim2.new(0,14,0.5,-10)
 local swPill = Btn(swRow, C.PILL_OFF, UDim2.new(0,52,0,30))
 swPill.AnchorPoint = Vector2.new(1,0.5); swPill.Position = UDim2.new(1,-12,0.5,0); Corner(swPill,13)
 local swKnob = Frame(swPill, C.KNOB_OFF, UDim2.new(0,24,0,24))
 swKnob.AnchorPoint = Vector2.new(0,0.5); swKnob.Position = UDim2.new(0,3,0.5,0); Corner(swKnob,10)

 -- -- Dropdown filter card (LayoutOrder 6) --------------------
 local swDropCard = Frame(p, C.BG3, UDim2.new(1,0,0,0))
 swDropCard.LayoutOrder = 7
 swDropCard.AutomaticSize = Enum.AutomaticSize.Y
 Corner(swDropCard, 10); Stroke(swDropCard,C.BORD, 1.5,0.4)
 Padding(swDropCard,6,6,10,10)
 New("UIListLayout",{Parent=swDropCard,SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,4)})

 local swDTopRow = Frame(swDropCard, Color3.new(0,0,0), UDim2.new(1,0,0,16))
 swDTopRow.LayoutOrder=1; swDTopRow.BackgroundTransparency=1
 local swDFilterLbl = Label(swDTopRow,"Filter Item Weapon (jual item terpilih)",10,C.TXT3,Enum.Font.GothamBold)
 swDFilterLbl.Size=UDim2.new(0.65,0,1,0)
 local swDCountLbl = Label(swDTopRow,"Select All",10,C.ACC2,Enum.Font.GothamBold)
 swDCountLbl.Size=UDim2.new(0.35,0,1,0); swDCountLbl.Position=UDim2.new(0.65,0,0,0)
 swDCountLbl.TextXAlignment=Enum.TextXAlignment.Right

 local swDBtn = Btn(swDropCard, C.BG2, UDim2.new(1,0,0,32))
 swDBtn.LayoutOrder=2; Corner(swDBtn, 10); Stroke(swDBtn,C.BORD, 1.5,0.5)
 local swDBtnLbl = Label(swDBtn,"Select Item",12,C.TXT3,Enum.Font.GothamBold)
 swDBtnLbl.Size=UDim2.new(1,-30,1,0); swDBtnLbl.Position=UDim2.new(0,10,0,0)
 swDBtnLbl.TextXAlignment=Enum.TextXAlignment.Left
 swDBtnLbl.TextTruncate=Enum.TextTruncate.AtEnd
 local swDArrow = Label(swDBtn,"v",13,C.ACC,Enum.Font.GothamBold)
 swDArrow.Size=UDim2.new(0,22,1,0); swDArrow.Position=UDim2.new(1,-26,0,0)
 swDArrow.TextXAlignment=Enum.TextXAlignment.Center

 -- -- Status bar (LayoutOrder 7) -------------------------------
 local swStatusCard = Frame(p, C.BG3, UDim2.new(1,0,0,26))
 swStatusCard.LayoutOrder = 8; Corner(swStatusCard,6); Stroke(swStatusCard,C.BORD, 1.5,0.4)
 local swDot = Frame(swStatusCard, Color3.fromRGB(100,100,100), UDim2.new(0,8,0,8))
 swDot.Position = UDim2.new(0,7,0.5,-4); Corner(swDot,4)
 local swStatusLbl = Label(swStatusCard,"Idle",10,C.TXT3,Enum.Font.GothamBold)
 swStatusLbl.Size = UDim2.new(1,-22,1,0); swStatusLbl.Position = UDim2.new(0,21,0,0)
 swStatusLbl.TextTruncate = Enum.TextTruncate.AtEnd

 local function SetSWStatus(msg, col)
  pcall(function()
   swStatusLbl.Text = msg
   swStatusLbl.TextColor3 = col or C.TXT3
   swDot.BackgroundColor3 = col or Color3.fromRGB(100,100,100)
  end)
 end

 -- -- Update tampilan tombol dropdown -------------------------
 local function UpdateSwDropUI()
  if _swSelectAll then
   swDBtnLbl.Text   = "Select All"
   swDBtnLbl.TextColor3 = C.ACC2
   swDCountLbl.Text = "Select All"
  else
   local n = 0; for _ in pairs(_swSelectedIds) do n=n+1 end
   if n == 0 then
    swDBtnLbl.Text       = "Select Item"
    swDBtnLbl.TextColor3 = C.TXT3
    swDCountLbl.Text     = "0 dipilih"
   else
    local names = {}
    for _, nm in pairs(_swSelNames) do table.insert(names, nm) end
    table.sort(names)
    local preview = table.concat(names, ", ")
    if #preview > 38 then preview = preview:sub(1,35).."..." end
    swDBtnLbl.Text       = preview
    swDBtnLbl.TextColor3 = C.ACC
    swDCountLbl.Text     = n.." item"
   end
  end
 end

 -- -- Quality color map ----------------------------------------
 local SW_QCOL = {
  [1]=Color3.fromRGB(200,200,200),
  [2]=Color3.fromRGB(100,200,255),
  [3]=Color3.fromRGB(200,100,255),
  [4]=Color3.fromRGB(255,160,40),
  [5]=Color3.fromRGB(255,80,80),
 }

 -- -- Dropdown popup (pakai DDLayer existing) ------------------
 swDBtn.MouseButton1Click:Connect(function()
  CloseActiveDD()

  local absPos  = swDBtn.AbsolutePosition
  local absSize = swDBtn.AbsoluteSize
  local ITEM_H  = 28
  local totalH  = #WEAPON_LIST * (ITEM_H + 2) + 8
  local scrollH = math.min(totalH, 320)
  local HEADER_H = 72   -- Select All btn + padding

  local popup = Instance.new("Frame")
  popup.Parent = DDLayer
  popup.BackgroundColor3 = C.DD_BG
  popup.BorderSizePixel  = 0
  popup.Size     = UDim2.new(0, absSize.X + 20, 0, HEADER_H + scrollH)
  popup.Position = UDim2.new(0, absPos.X - 10, 0, absPos.Y + absSize.Y + 4)
  popup.ZIndex   = 9999
  popup.ClipsDescendants = true
  Corner(popup, 10); Stroke(popup, C.BORD2, 1.5, 0.2)

  -- Header: Select All btn + count label
  local hdr = Frame(popup, C.TBAR, UDim2.new(1,0,0,HEADER_H)); hdr.ZIndex=9999
  Corner(hdr, 10)

  local hdrCountLbl = Label(hdr, "Select Item", 11, C.TXT3, Enum.Font.GothamBold)
  hdrCountLbl.Size=UDim2.new(0.6,0,0,20); hdrCountLbl.Position=UDim2.new(0,8,0,6); hdrCountLbl.ZIndex=9999

  local hdrClose = Btn(hdr, Color3.fromRGB(150,40,40), UDim2.new(0,40,0,22))
  hdrClose.Position=UDim2.new(1,-46,0,6); Corner(hdrClose,5); hdrClose.ZIndex=9999
  local hdrCloseLbl = Label(hdrClose,"Close",10,C.TXT,Enum.Font.GothamBold,Enum.TextXAlignment.Center)
  hdrCloseLbl.Size=UDim2.new(1,0,1,0); hdrCloseLbl.ZIndex=9999

  local selAllBtn = Btn(hdr, Color3.fromRGB(30,100,60), UDim2.new(1,-16,0,26))
  selAllBtn.Position=UDim2.new(0,8,0,34); Corner(selAllBtn,6); selAllBtn.ZIndex=9999
  local selAllLbl = Label(selAllBtn,"*  Select All  (jual semua unlocked)",11,C.TXT,Enum.Font.GothamBold)
  selAllLbl.Size=UDim2.new(1,0,1,0); selAllLbl.ZIndex=9999

  -- ScrollingFrame list
  local sf = Instance.new("ScrollingFrame")
  sf.Parent=popup; sf.BackgroundTransparency=1; sf.BorderSizePixel=0
  sf.Position=UDim2.new(0,0,0,HEADER_H); sf.Size=UDim2.new(1,0,0,scrollH)
  sf.CanvasSize=UDim2.new(0,0,0,totalH)
  sf.ScrollBarThickness=5; sf.ScrollBarImageColor3=C.ACC
  sf.ScrollingDirection=Enum.ScrollingDirection.Y; sf.ZIndex=9999
  local sfLayout = Instance.new("UIListLayout",sf)
  sfLayout.SortOrder=Enum.SortOrder.LayoutOrder; sfLayout.Padding=UDim.new(0,2)
  local sfp = Instance.new("UIPadding",sf)
  sfp.PaddingTop=UDim.new(0,4); sfp.PaddingBottom=UDim.new(0,4)
  sfp.PaddingLeft=UDim.new(0,4); sfp.PaddingRight=UDim.new(0, 10)

  -- Working copy state (applied on close)
  local tempSel    = {}
  local tempSelAll = _swSelectAll
  if not tempSelAll then
   for k,v in pairs(_swSelectedIds) do tempSel[k]=v end
  end

  -- Update header count
  local rowRefs = {}
  local function RefreshHdr()
   if tempSelAll then
    hdrCountLbl.Text       = "Select All aktif"
    hdrCountLbl.TextColor3 = C.ACC2
    selAllLbl.Text         = "*  Select All  (aktif)"
    selAllLbl.TextColor3   = Color3.fromRGB(80,255,150)
   else
    local n=0; for _ in pairs(tempSel) do n=n+1 end
    hdrCountLbl.Text       = n.." item dipilih"
    hdrCountLbl.TextColor3 = n>0 and C.ACC or C.TXT3
    selAllLbl.Text         = "*  Select All  (jual semua unlocked)"
    selAllLbl.TextColor3   = C.TXT
   end
  end
  RefreshHdr()

  -- Build rows
  for idx, entry in ipairs(WEAPON_LIST) do
   local wid, wname, wquality, wcol = entry[1], entry[2], entry[3], entry[4]
   local isSel = tempSel[wid]==true

   local row = Btn(sf, isSel and Color3.fromRGB(30,70,30) or C.DD_BG, UDim2.new(1,-8,0,ITEM_H))
   row.LayoutOrder=idx; Corner(row,5); row.ZIndex=9999

   local tick = Frame(row, isSel and C.PILL_ON or C.PILL_OFF, UDim2.new(0,14,0,14))
   tick.AnchorPoint=Vector2.new(0,0.5); tick.Position=UDim2.new(0,5,0.5,0)
   Corner(tick,3); tick.ZIndex=9999
   local tickMark = Label(tick,"*",9,C.TXT,Enum.Font.GothamBold,Enum.TextXAlignment.Center)
   tickMark.Size=UDim2.new(1,0,1,0); tickMark.ZIndex=9999; tickMark.Visible=isSel

   local nmLbl = Label(row, wname, 11, wcol or C.TXT, Enum.Font.GothamBold)
   nmLbl.Size=UDim2.new(1,-26,1,0); nmLbl.Position=UDim2.new(0,24,0,0)
   nmLbl.TextXAlignment=Enum.TextXAlignment.Left; nmLbl.ZIndex=9999
   nmLbl.TextTruncate=Enum.TextTruncate.AtEnd

   rowRefs[wid]={row=row,tick=tick,tickMark=tickMark}

   row.MouseButton1Click:Connect(function()
    -- Keluar dari Select All mode jika ada
    if tempSelAll then
     tempSelAll=false
     for k in pairs(tempSel) do tempSel[k]=nil end
     for _, ref in pairs(rowRefs) do
      ref.tick.BackgroundColor3=C.PILL_OFF
      ref.tickMark.Visible=false
      ref.row.BackgroundColor3=C.DD_BG
     end
    end
    -- Toggle item
    if tempSel[wid] then
     tempSel[wid]=nil
     tick.BackgroundColor3=C.PILL_OFF; tickMark.Visible=false
     row.BackgroundColor3=C.DD_BG
    else
     tempSel[wid]=true
     tick.BackgroundColor3=C.PILL_ON; tickMark.Visible=true
     row.BackgroundColor3=Color3.fromRGB(30,70,30)
    end
    RefreshHdr()
   end)
  end

  -- Fungsi apply & close
  -- ApplyClose: simpan pilihan, tutup popup TANPA rekursi
  local _closed = false
  local function ApplyClose()
   if _closed then return end
   _closed = true
   -- Simpan state
   if tempSelAll then
    _swSelectAll=true; _swSelectedIds={}; _swSelNames={}; _swSelectAllState=true
   else
    _swSelectAll=false; _swSelectedIds={}; _swSelNames={}; _swSelectAllState=false
    for k in pairs(tempSel) do
     _swSelectedIds[k]=true
     for _, e in ipairs(WEAPON_LIST) do
      if e[1]==k then _swSelNames[k]=e[2]; break end
     end
    end
   end
   UpdateSwDropUI()
   if _autoSellWeaponOn then StartAutoSellWeapon() end
   -- Tutup langsung: destroy popup, hide DDLayer, clear callback
   _activeDDClose = nil
   DDLayer.Visible = false
   pcall(function() popup:Destroy() end)
  end

  selAllBtn.MouseButton1Click:Connect(function()
   tempSelAll=true
   for k in pairs(tempSel) do tempSel[k]=nil end
   for _, ref in pairs(rowRefs) do
    ref.tick.BackgroundColor3=C.PILL_OFF
    ref.tickMark.Visible=false
    ref.row.BackgroundColor3=C.DD_BG
   end
   RefreshHdr()
  end)

  hdrClose.MouseButton1Click:Connect(ApplyClose)

  DDLayer.Visible = true
  _activeDDClose  = ApplyClose
 end)

 -- -- StartAutoSellWeapon --------------------------------------
 -- Source data: PlayerManager.localPlayerData.weapons (confirmed accessible)
 -- Struktur: {guid, isLock, isEquip, isBuffer, isFavourite, itemId, ...}
 function StartAutoSellWeapon()
  if _swConn then pcall(function() task.cancel(_swConn) end); _swConn = nil end
  _swSoldCount = 0

  local re = Remotes:FindFirstChild("DeleteWeapons")
  if not re then
   SetSWStatus("[!] DeleteWeapons NOT FOUND!", Color3.fromRGB(255,80,80)); return
  end

  -- Ambil PlayerManager sekali
  local _pm = nil
  pcall(function()
   _pm = require(game:GetService("ReplicatedStorage").Scripts.Client.Manager.PlayerManager)
  end)
  if not _pm then
   SetSWStatus("[!] PlayerManager NOT FOUND!", Color3.fromRGB(255,80,80)); return
  end

  local function GetSellableWeapons()
   local guids = {}
   pcall(function()
    local weapons = _pm.localPlayerData and _pm.localPlayerData.weapons
    if not weapons then return end
    for guid, data in pairs(weapons) do
     repeat
     if data.isLock then break end
     if data.isEquip then break end
     if data.isBuffer then break end
     if data.isFavourite then break end
     -- Filter item spesifik kalau bukan Select All
     if not _swSelectAll and next(_swSelectedIds) then
      -- itemId dari data vs WEAPON_LIST equipId
      -- Coba match langsung, atau via offset (Item vs Equip config)
      local matched = false
      if data.itemId and _swSelectedIds[data.itemId] then
       matched = true
      end
      -- Fallback: cari di WEAPON_LIST berdasarkan itemId proximity
      if not matched then break end
     end
     table.insert(guids, guid)
     until true
    end
   end)
   return guids
  end

  _swConn = task.spawn(function()
   while _autoSellWeaponOn do
    local guids = GetSellableWeapons()
    if guids and #guids > 0 then
     SetSWStatus("Selling "..#guids.." weapon...", Color3.fromRGB(255,200,60))
     local BATCH = 20
     for i = 1, #guids, BATCH do
      if not _autoSellWeaponOn then break end
      local batch = {}
      for j = i, math.min(i+BATCH-1, #guids) do
       table.insert(batch, guids[j])
      end
      pcall(function() re:FireServer(batch) end)
      _swSoldCount = _swSoldCount + #batch
      SetSWStatus("[OK] Sold [".._swSoldCount.."] weapon", Color3.fromRGB(255,160,40))
      task.wait(0.5)
     end
    else
     local fd = _swSelectAll and "All" or (function()
      local n=0; for _ in pairs(_swSelectedIds) do n=n+1 end; return n.." item"
     end)()
     SetSWStatus("[OK] Active ("..fd..") - waiting...", Color3.fromRGB(100,220,100))
    end
    task.wait(2)
   end
  end)

  SetSWStatus("[OK] Active - scanning...", Color3.fromRGB(100,220,100))
 end

 swPill.MouseButton1Click:Connect(function()
  _autoSellWeaponOn = not _autoSellWeaponOn
  _autoSellWeaponState = _autoSellWeaponOn
  local on = _autoSellWeaponOn
  TweenService:Create(swPill,TweenInfo.new(0.16),{BackgroundColor3=on and C.PILL_ON or C.PILL_OFF}):Play()
  TweenService:Create(swKnob,TweenInfo.new(0.16),{
   Position=on and UDim2.new(1,-27,0.5,0) or UDim2.new(0,3,0.5,0),
   BackgroundColor3=on and C.KNOB_ON or C.KNOB_OFF,
  }):Play()
  if on then StartAutoSellWeapon()
  else
   if _swConn then pcall(function() task.cancel(_swConn) end); _swConn=nil end
   SetSWStatus("Idle - ".._swSoldCount.." SOLD", C.TXT3)
  end
 end)
 -- Expose setter weapon sell ke global
 _autoSellWeaponSet = function(v)
  if v == _autoSellWeaponOn then return end
  _autoSellWeaponOn = v
  _autoSellWeaponState = v
  TweenService:Create(swPill,TweenInfo.new(0.16),{BackgroundColor3=v and C.PILL_ON or C.PILL_OFF}):Play()
  TweenService:Create(swKnob,TweenInfo.new(0.16),{
   Position=v and UDim2.new(1,-27,0.5,0) or UDim2.new(0,3,0.5,0),
   BackgroundColor3=v and C.KNOB_ON or C.KNOB_OFF,
  }):Play()
  if v then StartAutoSellWeapon()
  else
   if _swConn then pcall(function() task.cancel(_swConn) end); _swConn=nil end
   SetSWStatus("Idle - ".._swSoldCount.." SOLD", C.TXT3)
  end
 end
 -- Visual-only untuk weapon sell (update pill tanpa logic)
 _visWeaponSell = function(v)
  _autoSellWeaponState = v
  TweenService:Create(swPill,TweenInfo.new(0.16),{BackgroundColor3=v and C.PILL_ON or C.PILL_OFF}):Play()
  TweenService:Create(swKnob,TweenInfo.new(0.16),{
   Position=v and UDim2.new(1,-27,0.5,0) or UDim2.new(0,3,0.5,0),
   BackgroundColor3=v and C.KNOB_ON or C.KNOB_OFF,
  }):Play()
 end
 -- Track selectAll state untuk config
 _swSelectAllState = _swSelectAll


 -- AUTO DECOMPOSE GEM [v54 FIX: scan itemId agresif, support Colorful/Rainbow Gem]
 -- Sumber GUID: GemsPanel.Frame.BgImage.List.ScrollingFrame
 -- Nama child = UUID gem. NumText "Lv.X" = level gem.
 -- Filter berdasarkan itemId dari config game.
 -- Remote: DecomposeItems:FireServer({itemType=7, data={guid1,...}})
 -- 
 local _autoDecompGemOn = false
 local _autoDecompGemThread = nil
 local GEM_ITEM_TYPE = 7
 local _gemMaxLevel = 9 -- default slider: decompose level 1-9

 -- Tabel itemId gem berdasarkan nama dan level (dari game config)
 -- Format: [itemId] = level
 -- Ruby 88001-88009 (L1-9), Emerald 88011-88019, Sapphire 88021-88029
 -- Deadly Gem 88031-88039, Purple Gem 88141-88149
 -- Colorful Gem 88041-88049 (L101-109=L1-9), Rainbow Gem 88051-88059
 local GEM_ID_RANGES = {
 -- {startId, endId, minLevel, maxLevel, displayName}
 {88001, 88009, 1, 9, "Ruby"},
 {88011, 88019, 1, 9, "Emerald"},
 {88021, 88029, 1, 9, "Sapphire"},
 {88031, 88039, 1, 9, "Deadly Gem"},
 {88141, 88149, 1, 9, "Purple Gem"},
 -- LV10-20: Ruby 88010,88061-88070 etc
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
 -- LV21-30
 {88171, 88180, 21, 30, "Ruby"},
 {88181, 88190, 21, 30, "Emerald"},
 {88191, 88200, 21, 30, "Sapphire"},
 -- Colorful Gem: game Level 101-109 = user level 1-9
 {88041, 88049, 1, 9, "Colorful Gem"},
 {88050, 88050, 10, 10, "Colorful Gem"},
 {88101, 88110, 11, 20, "Colorful Gem"},
 -- Rainbow Gem: game Level 101-109 = user level 1-9
 {88051, 88059, 1, 9, "Rainbow Gem"},
 {88060, 88060, 10, 10, "Rainbow Gem"},
 {88111, 88120, 11, 20, "Rainbow Gem"},
 }

 -- Build lookup: itemId -> userLevel (1-30)
 local GEM_ID_TO_LEVEL = {}
 for _, r in ipairs(GEM_ID_RANGES) do
 local startId, endId, minLv = r[1], r[2], r[3]
 for id = startId, endId do
 local offset = id - startId
 GEM_ID_TO_LEVEL[id] = minLv + offset
 end
 end

 -- Build lookup: itemId valid untuk decompose
 local function IsGemIdToDecomp(itemId, maxLv)
 local lv = GEM_ID_TO_LEVEL[itemId]
 if not lv then return false end
 return lv <= maxLv
 end

 -- UI 
 local dgRow = Frame(p, C.SURFACE, UDim2.new(1,0,0,44))
 dgRow.LayoutOrder = 9; Corner(dgRow,10); Stroke(dgRow, C.BORD, 1.5, 0.3)
 local dgLbl = Label(dgRow, "AUTO DECOMPOSE GEMS", 13, C.TXT, Enum.Font.GothamBold)
 dgLbl.Size = UDim2.new(1,-68,0,20); dgLbl.Position = UDim2.new(0,14,0.5,-10)
 local dgPill = Btn(dgRow, C.PILL_OFF, UDim2.new(0,52,0,30))
 dgPill.AnchorPoint = Vector2.new(1,0.5); dgPill.Position = UDim2.new(1,-12,0.5,0); Corner(dgPill,13)
 local dgKnob = Frame(dgPill, C.KNOB_OFF, UDim2.new(0,24,0,24))
 dgKnob.AnchorPoint = Vector2.new(0,0.5); dgKnob.Position = UDim2.new(0,3,0.5,0); Corner(dgKnob,10)

 -- Slider Max Level 
 local dgSliderCard = Frame(p, C.BG3, UDim2.new(1,0,0,44))
 dgSliderCard.LayoutOrder = 10; Corner(dgSliderCard, 10); Stroke(dgSliderCard,C.BORD, 1.5,0.4)
 Padding(dgSliderCard,6,6,10,10)
 New("UIListLayout",{Parent=dgSliderCard,FillDirection=Enum.FillDirection.Vertical,Padding=UDim.new(0,4)})

 local dgSliderTopRow = Frame(dgSliderCard, Color3.new(0,0,0), UDim2.new(1,0,0,14))
 dgSliderTopRow.BackgroundTransparency=1
 local dgSliderLbl = Label(dgSliderTopRow,"Min - Max Level Decompose",10,C.TXT3,Enum.Font.GothamBold)
 dgSliderLbl.Size=UDim2.new(0.6,0,1,0)
 local dgSliderVal = Label(dgSliderTopRow,"Lv 1 - 150",10,C.ACC2,Enum.Font.GothamBold)
 dgSliderVal.Size=UDim2.new(0.4,0,1,0); dgSliderVal.Position=UDim2.new(0.6,0,0,0)
 dgSliderVal.TextXAlignment=Enum.TextXAlignment.Right

 local dgSliderRow = Frame(dgSliderCard, Color3.new(0,0,0), UDim2.new(1,0,0,18))
 dgSliderRow.BackgroundTransparency=1

 local dgMinus = Btn(dgSliderRow,C.BG2,UDim2.new(0,18,0,18))
 dgMinus.Position=UDim2.new(0,0,0,0); Corner(dgMinus,6)
 Label(dgMinus,"-",12,C.TXT,Enum.Font.GothamBold).Size=UDim2.new(1,0,1,0)

 local dgTrackBg = Frame(dgSliderRow,C.BG2,UDim2.new(1,-42,0,6))
 dgTrackBg.Position=UDim2.new(0,22,0.5,-3); Corner(dgTrackBg,3)
 local dgFill = Frame(dgTrackBg,C.ACC2,UDim2.new(8/29,0,1,0))
 dgFill.Position=UDim2.new(0,0,0,0); Corner(dgFill,3)
 local dgThumb = Frame(dgTrackBg,C.TXT,UDim2.new(0,10,0,10))
 dgThumb.AnchorPoint=Vector2.new(0.5,0.5); dgThumb.Position=UDim2.new(8/29,0,0.5,0); Corner(dgThumb,5)

 local dgPlus = Btn(dgSliderRow,C.BG2,UDim2.new(0,18,0,18))
 dgPlus.Position=UDim2.new(1,-18,0,0); Corner(dgPlus,6)
 Label(dgPlus,"+",12,C.TXT,Enum.Font.GothamBold).Size=UDim2.new(1,0,1,0)

 local function SetDGLevel(lv)
 lv = math.clamp(lv, 1, 150)
 _gemMaxLevel = lv
 _gemMaxLevelState = lv
 local pct = (lv-1)/149
 dgSliderVal.Text = "Lv 1 - "..lv
 TweenService:Create(dgFill,TweenInfo.new(0.1),{Size=UDim2.new(pct,0,1,0)}):Play()
 TweenService:Create(dgThumb,TweenInfo.new(0.1),{Position=UDim2.new(pct,0,0.5,0)}):Play()
 end
 SetDGLevel(9)
 _setGemLevelSlider = SetDGLevel  -- expose ke global config

 dgMinus.MouseButton1Click:Connect(function() SetDGLevel(_gemMaxLevel - 1) end)
 dgPlus.MouseButton1Click:Connect(function() SetDGLevel(_gemMaxLevel + 1) end)

 -- Drag slider
 local dgDragging = false
 dgThumb.InputBegan:Connect(function(inp)
 if inp.UserInputType==Enum.UserInputType.Touch or inp.UserInputType==Enum.UserInputType.MouseButton1 then
 dgDragging=true
 end
 end)
 game:GetService("UserInputService").InputChanged:Connect(function(inp)
 if not dgDragging then return end
 if inp.UserInputType==Enum.UserInputType.MouseMovement or inp.UserInputType==Enum.UserInputType.Touch then
 local trackPos = dgTrackBg.AbsolutePosition.X
 local trackW = dgTrackBg.AbsoluteSize.X
 local pct = math.clamp((inp.Position.X - trackPos)/trackW, 0, 1)
 local lv = math.round(1 + pct * 149)
 SetDGLevel(lv)
 end
 end)
 game:GetService("UserInputService").InputEnded:Connect(function(inp)
 if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then
 dgDragging=false
 end
 end)

 -- Status bar
 local function SetDGStatus(msg, col)
 pcall(function()
 dgStatusLbl.Text = msg
 dgStatusLbl.TextColor3 = col or C.TXT3
 end)
 end

 -- Scan GemsPanel - ambil guid + itemId dari NumText / child name
 -- [v54 FIX] GetGemGuidsFromPanel: scan lebih agresif, support Colorful/Rainbow Gem
 -- Return: list of {guid=string, itemId=number} untuk dipakai di DecomposeItems
 local function GetGemGuidsFromPanel(maxLv)
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
 -- Hanya proses child dengan nama UUID (guid)
 if #guidStr ~= 36 or not guidStr:find("^%x+%-%x+%-%x+%-%x+%-%x+$") then break end

 -- [v54 FIX] Cari itemId dari semua sumber: attribute di child, attribute di descendants, value di ImageLabel
 local itemId = nil

 -- Sumber 1: attribute langsung di child
 itemId = child:GetAttribute("itemId") or child:GetAttribute("ItemId")
 or child:GetAttribute("id") or child:GetAttribute("Id")
 or child:GetAttribute("item_id")

 -- Sumber 2: scan descendants (attribute di child apapun)
 if not itemId then
 for _, c in ipairs(child:GetDescendants()) do
 local aid = c:GetAttribute("itemId") or c:GetAttribute("ItemId")
 or c:GetAttribute("id") or c:GetAttribute("Id")
 or c:GetAttribute("item_id")
 if aid and tonumber(aid) then itemId = tonumber(aid); break end
 end
 end

 -- Jika dapat itemId, gunakan GEM_ID_TO_LEVEL untuk filter
 if itemId and tonumber(itemId) then
 local id = tonumber(itemId)
 if IsGemIdToDecomp(id, maxLv) then
 table.insert(result, guidStr)
 end
 else
 -- Fallback: parse "Lv.X" dari NumText
 local lvFound = nil
 for _, c in ipairs(child:GetDescendants()) do
 if c:IsA("TextLabel") and (c.Name == "NumText" or c.Name:lower():find("lv") or c.Name:lower():find("level")) then
 local n = c.Text:match("[Ll][Vv]%.?%s*(%d+)")
 if n then lvFound = tonumber(n); break end
 end
 end
 if lvFound and lvFound <= maxLv then
 table.insert(result, guidStr)
 elseif not lvFound then
 -- Tidak bisa tentukan level sama sekali: masukkan (safe decompose)
 table.insert(result, guidStr)
 end
 end
 until true
 end
 end)
 return result
 end

 local function SetDGPillOff()
 _autoDecompGemOn = false
 TweenService:Create(dgPill,TweenInfo.new(0.16),{BackgroundColor3=C.PILL_OFF}):Play()
 TweenService:Create(dgKnob,TweenInfo.new(0.16),{
 Position=UDim2.new(0,3,0.5,0), BackgroundColor3=C.KNOB_OFF
 }):Play()
 end

 local function RunAutoDecompGem()
 SetDGStatus("SCAN Inventory...", C.ACC2)
 task.wait(0.5)

 local guids = GetGemGuidsFromPanel(_gemMaxLevel)

 if #guids == 0 then
 SetDGStatus("[!] OPEN GemsPanel First! (max Lv".._gemMaxLevel..")", Color3.fromRGB(255,180,60))
 task.wait(2); SetDGPillOff()
 SetDGStatus("Idle - OPEN GemsPanel First", C.TXT3)
 return
 end

 SetDGStatus("GOT "..#guids.." gem (max Lv".._gemMaxLevel..")...", C.ACC2)
 task.wait(0.3)

 local decomposed = 0
 local BATCH = 20
 local re = Remotes:FindFirstChild("DecomposeItems")
 if not re then
 SetDGStatus("[!] DecomposeItems remote NOT FOUND!", Color3.fromRGB(255,80,80))
 task.wait(2); SetDGPillOff()
 return
 end

 for i = 1, #guids, BATCH do
 if not _autoDecompGemOn then break end
 local batch = {}
 for j = i, math.min(i + BATCH - 1, #guids) do
 table.insert(batch, guids[j])
 end
 SetDGStatus("Decompose "..decomposed.."/"..#guids.."...", Color3.fromRGB(100,220,100))
 -- [v54 FIX] Kirim dua format sekaligus: string array DAN table array
 -- Format 1: {itemType=7, data={"guid1","guid2",...}} (confirmed SimpleSpy normal gem)
 -- Format 2: {itemType=7, guids=batch} (fallback beberapa versi game)
 pcall(function() re:FireServer({itemType=GEM_ITEM_TYPE, data=batch}) end)
 decomposed = decomposed + #batch
 task.wait(0.5)
 end

 SetDGStatus("[OK] "..decomposed.." gem DECOMPOSED!", Color3.fromRGB(110,231,183))
 task.wait(2); SetDGPillOff()
 SetDGStatus("Idle", C.TXT3)
 end

 dgPill.MouseButton1Click:Connect(function()
 _autoDecompGemOn = not _autoDecompGemOn
 _autoDecompGemState = _autoDecompGemOn
 local on = _autoDecompGemOn
 TweenService:Create(dgPill,TweenInfo.new(0.16),{BackgroundColor3=on and C.PILL_ON or C.PILL_OFF}):Play()
 TweenService:Create(dgKnob,TweenInfo.new(0.16),{
 Position=on and UDim2.new(1,-27,0.5,0) or UDim2.new(0,3,0.5,0),
 BackgroundColor3=on and C.KNOB_ON or C.KNOB_OFF,
 }):Play()
 if on then
 _autoDecompGemThread = task.spawn(RunAutoDecompGem)
 else
 if _autoDecompGemThread then pcall(function() task.cancel(_autoDecompGemThread) end) end
 SetDGStatus("Idle - STOPPED", C.TXT3)
 end
 end)
 -- Expose setter gem decompose + level ke global
 _autoDecompGemSet = function(v)
  if v == _autoDecompGemOn then return end
  _autoDecompGemOn = v
  _autoDecompGemState = v
  TweenService:Create(dgPill,TweenInfo.new(0.16),{BackgroundColor3=v and C.PILL_ON or C.PILL_OFF}):Play()
  TweenService:Create(dgKnob,TweenInfo.new(0.16),{
   Position=v and UDim2.new(1,-27,0.5,0) or UDim2.new(0,3,0.5,0),
   BackgroundColor3=v and C.KNOB_ON or C.KNOB_OFF,
  }):Play()
  if v then _autoDecompGemThread = task.spawn(RunAutoDecompGem)
  else
   if _autoDecompGemThread then pcall(function() task.cancel(_autoDecompGemThread) end) end
   SetDGStatus("Idle - STOPPED", C.TXT3)
  end
 end
 -- Visual-only untuk gem decomp
 _visDecompGem = function(v)
  _autoDecompGemState = v
  TweenService:Create(dgPill,TweenInfo.new(0.16),{BackgroundColor3=v and C.PILL_ON or C.PILL_OFF}):Play()
  TweenService:Create(dgKnob,TweenInfo.new(0.16),{
   Position=v and UDim2.new(1,-27,0.5,0) or UDim2.new(0,3,0.5,0),
   BackgroundColor3=v and C.KNOB_ON or C.KNOB_OFF,
  }):Play()
 end

end


-- ============================================================
-- AUTO COLLECT GOLD & ITEM TOGGLE (inject ke panel MAIN)
-- ============================================================
do
 local ok, err = pcall(function()
  local p = Panels["main"]
  if not p then warn("[FLa] Panels[main] is nil!") return end
  local row, setFn, visFn = ToggleRow(p, "AUTO COLLECT GOLD & ITEM", "TP & collect semua gold/item ke player", 5, function(on)
      DoAutoCollectGoldItem(on)
  end)
  if not row then warn("[FLa] ToggleRow returned nil!") return end
  row.LayoutOrder = 5
  _setAutoCollectToggle = setFn
  _visAutoCollect = visFn
  warn("[FLa] AUTO COLLECT GOLD & ITEM toggle injected OK, LayoutOrder="..tostring(row.LayoutOrder))
 end)
 if not ok then warn("[FLa] inject error: "..tostring(err)) end
end


-- ============================================================

-- ============================================================

-- ============================================================
-- PANEL : HIDE
-- ============================================================
do
 local p = NewPanel("hide")
 local _hideRerollOn = false
 local _hideUIOn     = false
 local _hideAnimOn   = false

 local _rerollConn   = nil
 local _animLoop     = nil
 local _animWsConn   = nil
 local _uiAddConn    = nil

 -- Cache untuk restore
 local _rerollHidden = {}  -- [Frame baris] = true
 local _uiCache      = {}  -- [obj] = state sebelum hide
 local _animBbCache  = {}
 local _animPcCache  = {}

 local _OUR_GUI = "ASH_NightFrost"

 -- Header
 local hCard = Frame(p, C.BG3, UDim2.new(1,0,0,52))
 hCard.LayoutOrder=0; Corner(hCard,10); Stroke(hCard,C.BORD,1.5,0.6); Padding(hCard,8,8,10,10)
 local hLbl = Label(hCard,"  HIDE MANAGER",12,C.ACC2,Enum.Font.GothamBold,Enum.TextXAlignment.Left)
 hLbl.Size=UDim2.new(1,0,0,20)
 local hSub = Label(hCard,"Sembunyikan elemen game. Toggle OFF untuk restore penuh.",10,C.DIM,Enum.Font.Gotham,Enum.TextXAlignment.Left)
 hSub.Size=UDim2.new(1,0,0,24); hSub.Position=UDim2.new(0,0,0,22); hSub.TextWrapped=true

 -- ============================================================
 -- 1. HIDE REROLL CHAT
 -- Struktur ExperienceChat:
 --   ScrollingFrame[scrollView]
 --     Frame[0-{uuid}]    <-- satu baris chat (INI yang di-hide)
 --       Frame[TextMessage]
 --         TextLabel[BodyText]  <-- teks "... just reroll a ..."
 -- ============================================================
 local function isRerollText(t)
     t = (t or ""):gsub("<[^>]+>",""):lower()
     return t:find("reroll a",1,true) ~= nil
 end

 -- Cari Frame baris (0-{uuid}) dari sebuah TextLabel BodyText
 -- Naik 2 level: BodyText -> Frame[TextMessage] -> Frame[0-{uuid}]
 local function getRowFrame(lbl)
     local p1 = lbl.Parent          -- Frame[TextMessage]
     if not p1 then return lbl end
     local p2 = p1.Parent           -- Frame[0-{uuid}] = baris chat
     if not p2 then return p1 end
     -- Pastikan p2 bukan ScrollingFrame (jangan terlalu naik)
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
         -- Cari semua BodyText di dalam scrollView
         for _, obj in ipairs(ec:GetDescendants()) do
             if obj.Name == "BodyText" and (obj:IsA("TextLabel") or obj:IsA("TextButton")) then
                 if isRerollText(obj.Text) then
                     hideRow(getRowFrame(obj))
                 end
             end
         end
     end)
 end

 local function ApplyHideReroll(on)
     _hideRerollOn = on
     if _rerollConn then _rerollConn:Disconnect(); _rerollConn = nil end

     if on then
         -- Scan history yang sudah ada
         scanAndHideReroll()

         -- Watch DescendantAdded: saat baris baru muncul
         pcall(function()
             local CG2 = game:GetService("CoreGui")
             local ec = CG2:FindFirstChild("ExperienceChat")
             if not ec then ec = CG2:WaitForChild("ExperienceChat",10) end
             if not ec then return end
             _rerollConn = ec.DescendantAdded:Connect(function(obj)
                 -- Tunggu teks terisi (BodyText sering kosong saat baru muncul)
                 task.delay(0.2, function()
                     pcall(function()
                         if not _hideRerollOn then return end
                         if obj.Name == "BodyText" and (obj:IsA("TextLabel") or obj:IsA("TextButton")) then
                             if isRerollText(obj.Text) then
                                 hideRow(getRowFrame(obj))
                             end
                         end
                     end)
                 end)
             end)
         end)

     else
         -- RESTORE: tampilkan kembali semua baris yang kita sembunyikan
         for row, _ in pairs(_rerollHidden) do
             pcall(function()
                 if row and row.Parent then
                     row.Visible = true
                 end
             end)
         end
         _rerollHidden = {}
     end
 end

 ToggleRow(p,"HIDE REROLL CHAT","Sembunyikan baris chat 'just reroll a...' tanpa menghilangkan chat box",1,function(on)
     ApplyHideReroll(on)
 end)

 -- ============================================================
 -- 2. HIDE ALL UI
 -- ============================================================
 local function ApplyHideUI(on)
     _hideUIOn = on
     if _uiAddConn then _uiAddConn:Disconnect(); _uiAddConn = nil end

     if on then
         _uiCache = {}
         pcall(function()
             for _, gui in ipairs(PG:GetChildren()) do
                 pcall(function()
                     if gui.Name == _OUR_GUI then return end
                     if gui:IsA("ScreenGui") or gui:IsA("GuiBase2d") then
                         _uiCache[gui] = gui.Enabled
                         gui.Enabled = false
                     elseif gui:IsA("GuiObject") then
                         _uiCache[gui] = gui.Visible
                         gui.Visible = false
                     end
                 end)
             end
         end)
         -- Watch GUI baru yang muncul saat hide aktif
         -- [FIX SIEGE] Panel Siege/CityRaid yang di-spawn server saat player masuk Siege
         -- WAJIB dikecualikan dari hide - panel ini menampilkan Count/Timer dan men-trigger reward server
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
                     -- [FIX SIEGE] Jangan hide panel Siege saat SIEGE.inMap = true
                     if _isSiegePanelGui(gui) then return end
                     if gui:IsA("ScreenGui") or gui:IsA("GuiBase2d") then
                         _uiCache[gui] = gui.Enabled
                         gui.Enabled = false
                     elseif gui:IsA("GuiObject") then
                         _uiCache[gui] = gui.Visible
                         gui.Visible = false
                     end
                 end)
             end)
         end)
     else
         if _uiAddConn then _uiAddConn:Disconnect(); _uiAddConn = nil end
         -- Restore dari cache (persis state sebelumnya)
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

 ToggleRow(p,"HIDE ALL UI","Sembunyikan semua panel game. Toggle OFF restore penuh.",2,function(on)
     ApplyHideUI(on)
 end)

 -- ============================================================
 -- 3. HIDE ALL ANIMATION (versi penuh, restore sempurna)
 -- ============================================================
 local function ApplyHideAnim(on)
     _hideAnimOn = on

     if on then
         _animBbCache = {}
         _animPcCache = {}

         -- Stop animation tracks via RenderStepped
         if _animLoop then _animLoop:Disconnect(); _animLoop = nil end
         _animLoop = game:GetService("RunService").RenderStepped:Connect(function()
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
         if _animLoop    then _animLoop:Disconnect();    _animLoop    = nil end
         if _animWsConn  then _animWsConn:Disconnect(); _animWsConn  = nil end

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

         -- Restore BillboardGui ke state sebelumnya (bukan selalu true)
         for obj, prev in pairs(_animBbCache) do
             pcall(function() if obj and obj.Parent then obj.Enabled = prev end end)
         end
         _animBbCache = {}

         -- Restore Particle/Trail/Beam ke state sebelumnya
         for obj, prev in pairs(_animPcCache) do
             pcall(function() if obj and obj.Parent then obj.Enabled = prev end end)
         end
         _animPcCache = {}
     end
 end

 ToggleRow(p,"HIDE ALL ANIMATION","Matikan animasi, efek, partikel. Restore penuh saat OFF.",3,function(on)
     ApplyHideAnim(on)
 end)

end -- end do PANEL HIDE
-- ============================================================

-- PANEL : FARM
-- ============================================================
do
 local p = NewPanel("farm")

 -- State
 local RA = { running=false, threads={}, killed=0, cur=nil }
 local TA = { running=false, threads={}, killed=0, cur=nil, targetName=nil }
 local _deadG_F = {}
 local HERO_GUIDS_F = {}

 -- [FIX] SetupFarmHook dihapus - hook __namecall cukup satu di SetupUniversalSpy
 -- HERO_GUIDS_F sekarang alias ke HERO_GUIDS global agar tidak ada duplikasi hook
 local HERO_GUIDS_F = HERO_GUIDS -- alias, bukan copy

 -- Death listener
 if RE.Death then
 RE.Death.OnClientEvent:Connect(function(d)
 if not d then return end
 local g = d.enemyGuid or d.guid
 if g then
 _deadG_F[g] = false
 if RA.running then RA.killed = RA.killed+1 end
 if TA.running then TA.killed = TA.killed+1 end
 end
 end)
 end

 -- Helpers
 local function IsPosValidF(hrp)
 if not hrp then return false end
 local pos = hrp.Position
 if pos.X~=pos.X or pos.Y~=pos.Y or pos.Z~=pos.Z then return false end
 if math.abs(pos.X)>1e10 or math.abs(pos.Y)>1e10 or math.abs(pos.Z)>1e10 then return false end
 return true
 end

 local function GetEnemiesF()
  local list = {}
  local seen = {}
  -- Primary + fallback folders
  local FOLDERS = {"Enemys","EnemyCityRaid","CityRaidEnemys","Enemies","Enemy"}
  for _, fname in ipairs(FOLDERS) do
   local f = workspace:FindFirstChild(fname)
   if f then
    for _,e in ipairs(f:GetChildren()) do
     if e:IsA("Model") then
      local g = e:GetAttribute("EnemyGuid")
      local h = e:FindFirstChild("HumanoidRootPart")
      local hum = e:FindFirstChildOfClass("Humanoid")
      if g and h and hum and hum.Health>0 and not seen[g] and IsPosValidF(h) then
       seen[g] = true
       table.insert(list, {model=e, guid=g, hrp=h})
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
 local h = e.model:FindFirstChildOfClass("Humanoid")
 return false
 end

 local function FindByNameF(nm)
 for _,e in ipairs(GetEnemiesF()) do
 if e.model.Name==nm and not IsDeadF(e) then return e end
 end
 return nil
 end

 local function TpToF(tgt)
 if not tgt or not tgt.hrp then return end
 local char = LP.Character; if not char then return end
 local hrp = char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
 local tgtPos = tgt.hrp.Position
 if tgtPos.Y < -10 then return end
 local dir = (hrp.Position - tgtPos)
 if dir.Magnitude < 0.5 then dir = Vector3.new(1,0,0) end
 dir = Vector3.new(dir.X, 0, dir.Z).Unit
 local nearPos = tgtPos + dir*8
 local params = RaycastParams.new()
 params.FilterType = Enum.RaycastFilterType.Exclude
 local ex = {}
 if LP.Character then table.insert(ex, LP.Character) end
 local ef = workspace:FindFirstChild("Enemys"); if ef then table.insert(ex, ef) end
 params.FilterDescendantsInstances = ex
 local safePos
 for _,orig in ipairs({nearPos+Vector3.new(0,20,0), nearPos+Vector3.new(0,10,0), tgtPos+Vector3.new(4,20,0)}) do
 local r = workspace:Raycast(orig, Vector3.new(0,-80,0), params)
 if r and r.Position.Y >= (tgtPos.Y-30) then safePos = r.Position+Vector3.new(0,3,0); break end
 end
 hrp.CFrame = CFrame.new(safePos or nearPos+Vector3.new(0,3,0))
 end

 local function FCharF(g, pos)
  if not g then return end
  -- [vDewaS] Logika ST2: Serang Player + Hero Skill All-in-One
  FireAttack(g, pos)
  FireAllDamage(g, pos)
  FireHeroRemotes(g, pos)
  FireAttack(g, pos)
  FireAllDamage(g, pos)
  FireHeroRemotes(g, pos)
 end

 local function FHeroF(g)
  -- Logic dipindah ke FCharF untuk efisiensi "Tingkat Dewa" (seperti ST2)
 end

 local function StartCollectF(checkFn)
 task.spawn(function()
 local col = {}
 while checkFn() do
 for _,fn in ipairs({"Golds","Items","Drops","Rewards"}) do
 local f = workspace:FindFirstChild(fn)
 if f then for _,o in ipairs(f:GetChildren()) do
 if not checkFn() then break end
 local g = o:GetAttribute("GUID") or o:GetAttribute("Guid")
 if g and not col[g] then
 col[g] = true
 pcall(function() RE.CollectItem:InvokeServer(g) end)
 task.wait(0.05)
 end
 end end
 end
 task.wait(0.25)
 end
 end)
 end

 -- Random Attack
 local function StartRA()
  -- Pastikan HERO_GUIDS terisi sebelum attack
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
  RA.running=true; RA.killed=0; RA.cur=nil; RA.threads={}
 local tChar = task.spawn(function()
  local tpT = 1
  while RA.running do
   if not RA.cur or IsDeadF(RA.cur) or not RA.cur.model.Parent then
    _deadG_F={}; RA.cur=nil
    for _,e in ipairs(GetEnemiesF()) do
     if not IsDeadF(e) then RA.cur=e; break end
    end
    if RA.cur and not TA.running then TpToF(RA.cur); tpT=1 end
   end
   if RA.cur and not IsDeadF(RA.cur) and RA.cur.model.Parent then
    FCharF(RA.cur.guid, RA.cur.hrp.Position)
    tpT = tpT + task.wait(0)
    if tpT>=1 and not TA.running then tpT=1; TpToF(RA.cur) end
   else
    task.wait(0.5)
   end
  end
 end)
 RA.threads = {tChar}
 StartCollectF(function() return RA.running end)
 end

 local function StopRA()
 RA.running = false
 for _,t in ipairs(RA.threads) do pcall(function() task.cancel(t) end) end
 RA.threads={}; RA.cur=nil
 end

 -- Target Attack
 local function StartTA(targetName, onStatus)
 TA.running=true; TA.killed=0; TA.targetName=targetName; TA.cur=nil; TA.threads={}
 local tChar = task.spawn(function()
 local lastGuid=nil; local tpT=0
 while TA.running do
 local tgt = FindByNameF(targetName)
 if not tgt then
 TA.cur = nil
 if onStatus then onStatus("WAITING ["..targetName.."] respawn...") end
 while TA.running do
 task.wait(); tgt=FindByNameF(targetName)
 if tgt then break end
 end
 if not TA.running then break end
 _deadG_F={}; lastGuid=nil
 end
 if tgt and not IsDeadF(tgt) and tgt.model.Parent then
 TA.cur = tgt
 if tgt.guid~=lastGuid then lastGuid=tgt.guid; TpToF(tgt); tpT=1 end
 FCharF(tgt.guid, tgt.hrp.Position)
 tpT = tpT + task.wait()
 if tpT>=0 then tpT=0; TpToF(tgt) end
 if onStatus then onStatus(">> ["..targetName.."] Kill: "..TA.killed) end
 else
 task.wait()
 end
 end
 end)
 TA.threads = {tChar}
 StartCollectF(function() return TA.running end)
 end

 local function StopTA()
 TA.running = false
 for _,t in ipairs(TA.threads) do pcall(function() task.cancel(t) end) end
 TA.threads={}; TA.cur=nil; TA.targetName=nil
 end

 -- GUI
 local _, SetRA, SetRAVis = ToggleRow(p, "Random Attack", "Attack Enemy", 1, function(on)
 _raRunningState = on
 if on then StartRA() else StopRA() end
 end)
 _setRAToggle = SetRA
 _visRandomAtk = SetRAVis

 local raKillLbl = Label(p, "Kill: 0", 10, C.DIM, Enum.Font.GothamBold)
 raKillLbl.Size = UDim2.new(1,0,0,14); raKillLbl.LayoutOrder = 2

 SectionHeader(p, "SELECT ENEMY", 3)

 -- Refresh button
 local refCard = Frame(p, C.SURFACE, UDim2.new(1,0,0,36))
 refCard.LayoutOrder = 4; Corner(refCard, 10); Stroke(refCard, C.BORD, 1.5, 0.5)

 local refBtn = Btn(refCard, C.BG2, UDim2.new(0,80,0,26))
 refBtn.Position = UDim2.new(1,-88,0.5,-13)
 refBtn.Text = "Refresh"; refBtn.TextSize = 10
 refBtn.Font = Enum.Font.GothamBold; refBtn.TextColor3 = C.ACC
 Corner(refBtn, 6); Stroke(refBtn, C.BORD, 1.5, 0.3)

 local statLbl = Label(refCard, "Click Refresh to reload the enemies", 10, C.DIM, Enum.Font.GothamBold)
 statLbl.Size = UDim2.new(1,-100,1,0); statLbl.Position = UDim2.new(0,10,0,0)

 -- Scroll list
 local eScroll = Instance.new("ScrollingFrame", p)
 eScroll.Size = UDim2.new(1,0,0,160); eScroll.LayoutOrder = 5
 eScroll.BackgroundColor3 = C.BG2; eScroll.BorderSizePixel = 0
 eScroll.ScrollBarThickness = 3; eScroll.ScrollBarImageColor3 = C.ACC
 eScroll.CanvasSize = UDim2.new(0,0,0,0)
 eScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
 Corner(eScroll, 9); Stroke(eScroll, C.BORD, 1.5, 0.5)
 Padding(eScroll, 5, 5, 6, 6)
 ListLayout(eScroll, nil, nil, 4)

 local ePH = Label(eScroll, "Click Refresh to reload the enemies", 10, C.DIM, Enum.Font.GothamBold, Enum.TextXAlignment.Center)
 ePH.Size = UDim2.new(1,0,0,44); ePH.TextWrapped = true

 local eRows = {}
 local activeRow = nil
 local taOn = false

 local function StopCurrentTA()
 taOn = false; StopTA()
 if activeRow then
 activeRow.f.BackgroundColor3 = C.BG2
 activeRow.s.Color = C.BORD
 activeRow.n.TextColor3 = C.DIM
 activeRow.pill.BackgroundColor3 = C.PILL_OFF
 activeRow.knob.Position = UDim2.new(0,3,0.5,0)
 activeRow = nil
 end
 statLbl.TextColor3 = C.DIM
 statLbl.Text = "Stop Kill: "..TA.killed
 end

 local function RefreshEnemies()
 if taOn then StopCurrentTA() end
 for _,r in pairs(eRows) do if r.f and r.f.Parent then r.f:Destroy() end end
 eRows = {}; ePH.Visible = false

 local enemies = GetEnemiesF()
 if #enemies == 0 then
 ePH.Text = "Tidak ada musuh di map ini"; ePH.Visible = true
 statLbl.Text = "Map kosong"; return
 end

 local nc = {}
 for _,e in ipairs(enemies) do nc[e.model.Name]=(nc[e.model.Name] or 0)+1 end
 local names = {}
 for nm in pairs(nc) do table.insert(names, nm) end
 table.sort(names)

 for idx, nm in ipairs(names) do
 local row = Frame(eScroll, C.BG2, UDim2.new(1,0,0,36))
 row.LayoutOrder = idx; Corner(row, 7)
 local rs = Instance.new("UIStroke", row); rs.Color = C.BORD; rs.Thickness = 1.5; rs.Transparency = 0.3

 local nL = Label(row, nm, 12, C.DIM, Enum.Font.GothamBold)
 nL.Size = UDim2.new(1,-80,1,0); nL.Position = UDim2.new(0,10,0,0)
 nL.TextTruncate = Enum.TextTruncate.AtEnd

 local cL = Label(row, "x"..nc[nm], 10, C.DIM, Enum.Font.GothamBold, Enum.TextXAlignment.Right)
 cL.Size = UDim2.new(0,28,1,0); cL.Position = UDim2.new(1,-72,0,0)

 local pill = Btn(row, C.PILL_OFF, UDim2.new(0,52,0,30))
 pill.AnchorPoint = Vector2.new(1,0.5)
 pill.Position = UDim2.new(1,-6,0.5,0); Corner(pill, 15)
 local knob = Frame(pill, C.KNOB_OFF, UDim2.new(0,24,0,24))
 knob.AnchorPoint = Vector2.new(0,0.5)
 knob.Position = UDim2.new(0,3,0.5,0); Corner(knob, 12)

 local rd = {f=row, s=rs, n=nL, c=cL, pill=pill, knob=knob}
 eRows[nm] = rd

 pill.MouseButton1Click:Connect(function()
 if taOn and activeRow == rd then
 StopCurrentTA()
 else
 if taOn then StopCurrentTA() end
 taOn = true; activeRow = rd
 row.BackgroundColor3 = C.SURFACE2
 rs.Color = C.ACC; nL.TextColor3 = C.TXT
 TweenService:Create(pill, TweenInfo.new(0.18), {BackgroundColor3=C.PILL_ON}):Play()
 TweenService:Create(knob, TweenInfo.new(0.18), {Position=UDim2.new(1,-27,0.5,0), BackgroundColor3=C.KNOB_ON}):Play()
 statLbl.TextColor3 = C.ACC
 statLbl.Text = ">> ["..nm.."]"
 StartTA(nm, function(msg) statLbl.Text = msg end)
 end
 end)
 end

 statLbl.Text = #names.." jenis "..#enemies.." total"
 statLbl.TextColor3 = C.DIM

 task.spawn(function()
 while p.Parent and #names > 0 do
 local live = {}
 for _,e in ipairs(GetEnemiesF()) do
 if not IsDeadF(e) then live[e.model.Name]=(live[e.model.Name] or 0)+1 end
 end
 for _,nm2 in ipairs(names) do
 repeat
 local r = eRows[nm2]; if not r then break end
 local a = live[nm2] or 0
 r.c.Text = "x"..a
 r.c.TextColor3 = a==0 and C.RED or C.DIM
 until true
 end
 if RA.running then raKillLbl.Text = "Kill: "..RA.killed end
 if taOn then statLbl.Text = ">> ["..(TA.targetName or "?").."] Kill: "..TA.killed end
 task.wait(0.5)
 end
 end)
 end

 refBtn.MouseButton1Click:Connect(function()
 refBtn.Text = "Loading..."
 task.spawn(function() RefreshEnemies(); task.wait(0.3); refBtn.Text = "Refresh" end)
 end)
end

-- ============================================================
-- PANEL : ATTACK
-- ============================================================
do
 local p = NewPanel("attack")

 local ddBackdrop = Instance.new("TextButton",ScreenGui)
 ddBackdrop.Size=UDim2.new(1,0,1,0); ddBackdrop.Position=UDim2.new(0,0,0,0)
 ddBackdrop.BackgroundTransparency=1; ddBackdrop.Text=""; ddBackdrop.ZIndex=49
 ddBackdrop.AutoButtonColor=false; ddBackdrop.Visible=false; ddBackdrop.Active=false
 local _openDDs = {}

 function OpenDD(list)
 for _, d in ipairs(_openDDs) do d.Visible = false end
 _openDDs = {}; list.Visible = true; table.insert(_openDDs, list); ddBackdrop.Visible = true
 end
 function CloseAllDD()
 for _, d in ipairs(_openDDs) do d.Visible = false end
 _openDDs = {}; ddBackdrop.Visible = false
 end
 ddBackdrop.MouseButton1Click:Connect(CloseAllDD)

 SectionHeader(p,"MASS ATTACK",0)

 local maCard = Frame(p,C.SURFACE,UDim2.new(1,0,0,44))
 maCard.LayoutOrder=1; Corner(maCard, 10); Stroke(maCard,C.BORD, 1.5,0.88)
 Padding(maCard,6,6,12,8)
 local maTitleLbl = Label(maCard,"Status",12,C.TXT,Enum.Font.GothamBold)
 maTitleLbl.Size=UDim2.new(0.4,0,0,16); maTitleLbl.Position=UDim2.new(0,0,0,4)
 local maStatusText = Label(maCard,"Idle",11,C.TXT2,Enum.Font.GothamBold,Enum.TextXAlignment.Right)
 maStatusText.Size=UDim2.new(0.6,0,0,16); maStatusText.Position=UDim2.new(0.4,0,0,4)
 maStatusText.TextTruncate=Enum.TextTruncate.AtEnd
 _maStatusLbl = maStatusText

 function MakeSimpleDD(card, title, opts, vals, defIdx, onSelect, lo)
 local c = Frame(p,C.SURFACE,UDim2.new(1,0,0,38))
 c.LayoutOrder=lo; Corner(c, 10); Stroke(c,C.BORD, 1.5,0.88); Padding(c,6,6,12,8)
 local lbl = Label(c,title,12,C.TXT,Enum.Font.GothamBold)
 lbl.Size=UDim2.new(0.5,0,1,0); lbl.Position=UDim2.new(0,0,0,0)
 local curIdx = defIdx
 local ddBtn = Btn(c,C.BG3,UDim2.new(0.5,-4,1,-4))
 ddBtn.Position=UDim2.new(0.5,0,0,2); Corner(ddBtn,6); Stroke(ddBtn,C.BORD, 1.5,0.2)
 local ddLbl = Label(ddBtn," "..opts[curIdx],11,C.ACC2,Enum.Font.GothamBold)
 ddLbl.Size=UDim2.new(1,-18,1,0)
 local arr = Label(ddBtn,"v",11,C.TXT2,Enum.Font.GothamBold,Enum.TextXAlignment.Center)
 arr.Size=UDim2.new(0,16,1,0); arr.Position=UDim2.new(1,-18,0,0)

 local list = Instance.new("Frame",ScreenGui)
 list.Size=UDim2.new(0,130,0,#opts*28+8)
 list.BackgroundColor3=C.BG3; list.BackgroundTransparency=0.42; list.BorderSizePixel=0
 list.ZIndex=50; list.Visible=false
 Instance.new("UICorner",list).CornerRadius=UDim.new(0, 10)
 do local _s=Instance.new("UIStroke",list); _s.Color=C.BORD; _s.Thickness=1.5; _s.Transparency=0 end
 local ll=Instance.new("UIListLayout",list); ll.Padding=UDim.new(0,2); ll.SortOrder=Enum.SortOrder.LayoutOrder
 Instance.new("UIPadding",list).PaddingTop=UDim.new(0,4)

 local irefs = {}
 for i, opt in ipairs(opts) do
 local item=Instance.new("TextButton",list)
 item.Size=UDim2.new(1,-8,0,26); item.LayoutOrder=i
 item.BackgroundColor3=i==curIdx and C.SURFACE2 or C.BG2
 item.BackgroundTransparency=i==curIdx and 0.18 or 0.42
 item.BorderSizePixel=0; item.Text=""; item.AutoButtonColor=false; item.ZIndex=51
 Instance.new("UICorner",item).CornerRadius=UDim.new(0,6)
 local iL=Instance.new("TextLabel",item)
 iL.Size=UDim2.new(1,-8,1,0); iL.Position=UDim2.new(0,8,0,0)
 iL.BackgroundTransparency=1; iL.Text=opt; iL.TextSize=13
 iL.Font=Enum.Font.Gotham; iL.TextColor3=i==curIdx and C.ACC2 or C.TXT
 iL.TextXAlignment=Enum.TextXAlignment.Left; iL.ZIndex=52
 irefs[i]={btn=item,lbl=iL}
 local ii=i
 item.MouseButton1Click:Connect(function()
 curIdx=ii; ddLbl.Text=" "..opts[ii]
 for j,r in ipairs(irefs) do
 r.btn.BackgroundColor3=j==ii and C.SURFACE2 or C.BG2
 r.btn.BackgroundTransparency=j==ii and 0.18 or 0.42
 r.lbl.TextColor3=j==ii and C.ACC2 or C.TXT
 end
 if vals then onSelect(vals[ii]) else onSelect(ii) end
 CloseAllDD()
 end)
 end
 ddBtn.MouseButton1Click:Connect(function()
      if list.Visible then CloseAllDD(); return end
      local ap=ddBtn.AbsolutePosition; local as=ddBtn.AbsoluteSize
      list.Position=UDim2.new(0,ap.X,0,ap.Y+as.Y+2-GuiInsetY())
      list.Size=UDim2.new(0,as.X,0,#opts*28+8)
      OpenDD(list)
    end)
    local function SetDDIndex(ii)
      if ii < 1 or ii > #opts then return end
      curIdx = ii; ddLbl.Text = " "..opts[ii]
      for j,r in ipairs(irefs) do
        r.btn.BackgroundColor3 = j==ii and C.SURFACE2 or C.BG2
        r.btn.BackgroundTransparency = j==ii and 0.18 or 0.42
        r.lbl.TextColor3 = j==ii and C.ACC2 or C.TXT
      end
      if vals then onSelect(vals[ii]) else onSelect(ii) end
    end
    return SetDDIndex
  end

 local _setKillDD = MakeSimpleDD(nil,"TARGET KILL",
    {"5","10","15","20","Kill All"},{5,10,15,20,0},1,
    function(v) MA.killTarget=v end, 2)
 _setKillDDGlobal = _setKillDD

 local mapSelSet={}
 local mapItemRefs={}
 _maMapSelState = mapSelSet  -- expose ke global config
 do
 local mapCard=Frame(p,C.SURFACE,UDim2.new(1,0,0,38))
 mapCard.LayoutOrder=3; Corner(mapCard, 10); Stroke(mapCard,C.BORD, 1.5,0.88); Padding(mapCard,6,6,12,8)
 local mapLbl=Label(mapCard,"Rotation Map",12,C.TXT,Enum.Font.GothamBold)
 mapLbl.Size=UDim2.new(0.5,0,1,0)
 local mapOpts={"ALL MAP"}
 for i=1,20 do mapOpts[i+1]="Map "..i end
 local mapDDBtn=Btn(mapCard,C.BG3,UDim2.new(0.5,-4,1,-4))
 mapDDBtn.Position=UDim2.new(0.5,0,0,2); Corner(mapDDBtn,6); Stroke(mapDDBtn,C.BORD, 1.5,0.2)
 local mapDDLbl=Label(mapDDBtn," SELECT MAP",11,C.ACC2,Enum.Font.GothamBold)
 mapDDLbl.Size=UDim2.new(1,-18,1,0)
 local mapArrow=Label(mapDDBtn,"v",11,C.TXT2,Enum.Font.GothamBold,Enum.TextXAlignment.Center)
 mapArrow.Size=UDim2.new(0,16,1,0); mapArrow.Position=UDim2.new(1,-18,0,0)

 function UpdateMapDDLbl()
 local count=0; for _ in pairs(mapSelSet) do count=count+1 end
 if count==0 then mapDDLbl.Text=" MAP NOW"
 elseif count==20 then mapDDLbl.Text=" ALL MAP"
 else mapDDLbl.Text=" "..count.." MAP SELECTED" end
 end

 local mapListH=math.min(#mapOpts*28+8,180)
 local mapList=Instance.new("Frame",ScreenGui)
 mapList.Size=UDim2.new(0,130,0,mapListH); mapList.BackgroundColor3=C.BG3
 mapList.BackgroundTransparency=0.42; mapList.BorderSizePixel=0; mapList.ZIndex=50; mapList.Visible=false; mapList.ClipsDescendants=true
 Instance.new("UICorner",mapList).CornerRadius=UDim.new(0, 10)
 do local _ms=Instance.new("UIStroke",mapList); _ms.Color=C.BORD; _ms.Thickness=1.5; _ms.Transparency=0 end

 local mapScroll=Instance.new("ScrollingFrame",mapList)
 mapScroll.Size=UDim2.new(1,0,1,0); mapScroll.BackgroundTransparency=1; mapScroll.BorderSizePixel=0
 mapScroll.ScrollBarThickness=3; mapScroll.ScrollBarImageColor3=C.ACC
 mapScroll.CanvasSize=UDim2.new(0,0,0,#mapOpts*28+8); mapScroll.ZIndex=51
 local mapScrollLayout=Instance.new("UIListLayout",mapScroll)
 mapScrollLayout.Padding=UDim.new(0,2); mapScrollLayout.SortOrder=Enum.SortOrder.LayoutOrder
 Instance.new("UIPadding",mapScroll).PaddingTop=UDim.new(0,4)

 for i,opt in ipairs(mapOpts) do
 local item=Instance.new("TextButton",mapScroll)
 item.Size=UDim2.new(1,-8,0,26); item.LayoutOrder=i
 item.BackgroundColor3=C.BG2; item.BackgroundTransparency=0.42
 item.BorderSizePixel=0; item.Text=""; item.AutoButtonColor=false; item.ZIndex=52
 Instance.new("UICorner",item).CornerRadius=UDim.new(0,6)
 local chk=Instance.new("TextLabel",item); chk.Size=UDim2.new(0,16,1,0); chk.Position=UDim2.new(0,4,0,0)
 chk.BackgroundTransparency=1; chk.Text=""; chk.TextSize=13
 chk.Font=Enum.Font.GothamBold; chk.TextColor3=C.GRN; chk.ZIndex=53
 local iLbl=Instance.new("TextLabel",item); iLbl.Size=UDim2.new(1,-24,1,0); iLbl.Position=UDim2.new(0,20,0,0)
 iLbl.BackgroundTransparency=1; iLbl.Text=opt; iLbl.TextSize=13
 iLbl.Font=Enum.Font.Gotham; iLbl.TextColor3=C.TXT; iLbl.TextXAlignment=Enum.TextXAlignment.Left; iLbl.ZIndex=53
 mapItemRefs[i]={btn=item,chk=chk,lbl=iLbl}
 local ii=i
 item.MouseButton1Click:Connect(function()
 if ii==1 then
 local anyOff=false
 for j=1,20 do if not mapSelSet[j] then anyOff=true; break end end
 if anyOff then
 for j=1,19 do mapSelSet[j]=true; MR.selected[j]=true end
 for j=2,#mapItemRefs do mapItemRefs[j].chk.Text="v"; mapItemRefs[j].lbl.TextColor3=C.ACC2 end
 mapItemRefs[1].chk.Text="v"; mapItemRefs[1].lbl.TextColor3=C.ACC2
 else
 for j=1,19 do mapSelSet[j]=nil; MR.selected[j]=nil end
 for j=1,#mapItemRefs do mapItemRefs[j].chk.Text=""; mapItemRefs[j].lbl.TextColor3=C.TXT end
 end
 else
 local mi=ii-1; mapSelSet[mi]=not mapSelSet[mi]; MR.selected[mi]=mapSelSet[mi]
 mapItemRefs[ii].chk.Text=mapSelSet[mi] and "v" or ""
 mapItemRefs[ii].lbl.TextColor3=mapSelSet[mi] and C.ACC2 or C.TXT
 local allOn=true; for j=1,20 do if not mapSelSet[j] then allOn=false; break end end
 mapItemRefs[1].chk.Text=allOn and "v" or ""; mapItemRefs[1].lbl.TextColor3=allOn and C.ACC2 or C.TXT
 end
 UpdateMapDDLbl()
 end)
 end
 mapDDBtn.MouseButton1Click:Connect(function()
 if mapList.Visible then CloseAllDD(); return end
 local ap=mapDDBtn.AbsolutePosition; local as=mapDDBtn.AbsoluteSize
 mapList.Position=UDim2.new(0,ap.X,0,ap.Y+as.Y+2-GuiInsetY())
 OpenDD(mapList)
 end)
 end

 local _setDelayDD = MakeSimpleDD(nil,"Delay Pindah Map",
    {"1","3","5","7","10"},{1,3,5,7,10},2,
    function(v) MR.nextMapDelay=v end, 4)
 _setDelayDDGlobal = _setDelayDD

 local skillCard=Frame(p,C.SURFACE,UDim2.new(1,0,0,64))
 skillCard.LayoutOrder=5; Corner(skillCard, 10); Stroke(skillCard,C.BORD, 1.5,0.88); Padding(skillCard,8,8,12,8)
 local skillTitle=Label(skillCard,"Auto Skill",12,C.TXT,Enum.Font.GothamBold)
 skillTitle.Size=UDim2.new(1,0,0,16); skillTitle.Position=UDim2.new(0,0,0,0)
 local skillRow=Frame(skillCard,C.BLACK,UDim2.new(1,0,0,32))
 skillRow.BackgroundTransparency=1; skillRow.Position=UDim2.new(0,0,0,20)
 New("UIListLayout",{Parent=skillRow,FillDirection=Enum.FillDirection.Horizontal,
 SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,4)})
 for i,d in ipairs({{n="Z",c=Color3.fromRGB(252,128,128)},{n="X",c=Color3.fromRGB(252,211,77)},{n="C",c=Color3.fromRGB(110,231,183)},{n="V",c=Color3.fromRGB(125,211,252)},{n="F",c=Color3.fromRGB(147,197,253)}}) do
 local sb=Btn(skillRow,C.BG3,UDim2.new(0,40,0,32)); sb.LayoutOrder=i; Corner(sb,6); Stroke(sb,C.BORD, 1.5,0.88)
 local sl=Label(sb,d.n,12,d.c,Enum.Font.GothamBold,Enum.TextXAlignment.Center)
 sl.Size=UDim2.new(1,0,0,18); sl.Position=UDim2.new(0,0,0,2)
 sl.TextYAlignment=Enum.TextYAlignment.Center
 local st=Label(sb,"OFF",8,C.TXT3,Enum.Font.GothamBold,Enum.TextXAlignment.Center)
 st.Size=UDim2.new(1,0,0,11); st.Position=UDim2.new(0,0,0,19)
 st.TextYAlignment=Enum.TextYAlignment.Center
 -- Simpan referensi ke SKL_UI supaya SkSetUI bisa update tampilan
 SKL.ui[d.n] = {btn=sb, lbl=st}
 local dn=d.n
 sb.MouseButton1Click:Connect(function()
 if SKL[dn].on then SkOff(dn) else SkOn(dn) end
 end)
 end

 local _maToggleRow, _setMaToggle, _maToglVis = ToggleRow(p,"Mass Attack","Serang semua musuh di map sekaligus",6,function(on)
    DoMassAttack(on)
  end)
 _setMaToggleGlobal = _setMaToggle
 _visMassAtk = _maToglVis

end

-- ============================================================
-- PANEL : PLAYER
-- ============================================================
do
 local p = NewPanel("player")

 local afkCard=Frame(p,C.SURFACE,UDim2.new(1,0,0,54))
 afkCard.LayoutOrder=-1; Corner(afkCard, 10); Stroke(afkCard,C.BORD, 1.5,0.88); Padding(afkCard,6,6,12,8)
 local afkTitle=Label(afkCard,"Session & Time (WIB) - Indonesia",12,C.TXT,Enum.Font.GothamBold)
 afkTitle.Size=UDim2.new(1,0,0,16); afkTitle.Position=UDim2.new(0,0,0,2)
 local afkTimeLbl=Label(afkCard,"WIB: --:--:-- | Active: 00:00:00",10.5,C.TXT2,Enum.Font.GothamBold)
 afkTimeLbl.Size=UDim2.new(1,0,0,13); afkTimeLbl.Position=UDim2.new(0,0,0,22)

 task.spawn(function()
 while ScreenGui and ScreenGui.Parent do
 task.wait(1)
 local utc=os.time(); local wib=utc+(7*3600)
 local h=math.floor(wib/3600)%24; local m=math.floor(wib/60)%60; local s=wib%60
 local wibStr=string.format("%02d:%02d:%02d",h,m,s)
 local durStr="00:00:00"
 if STATE.antiAfk and _antiAfkStart then
 local dur=os.time()-_antiAfkStart
 durStr=string.format("%02d:%02d:%02d",math.floor(dur/3600),math.floor(dur/60)%60,dur%60)
 end
 pcall(function()
 afkTimeLbl.Text="WIB: "..wibStr.." | Active: "..durStr
 afkTimeLbl.TextColor3=STATE.antiAfk and C.ACC2 or C.TXT2
 end)
 end
 end)

 SectionHeader(p,"PLAYER SETTINGS",0)

 local wsCard=Frame(p,C.SURFACE,UDim2.new(1,0,0,70))
 wsCard.LayoutOrder=1; Corner(wsCard, 10); Stroke(wsCard,C.BORD, 1.5,0.88); Padding(wsCard,8,8,12,8)
 local wsTitle=Label(wsCard,"SPEED RUN",12,C.TXT,Enum.Font.GothamBold)
 wsTitle.Size=UDim2.new(0.6,0,0,16); wsTitle.Position=UDim2.new(0,0,0,4)
 local wsValLbl=Label(wsCard,"16 (100%)",11,C.ACC2,Enum.Font.GothamBold,Enum.TextXAlignment.Right)
 wsValLbl.Size=UDim2.new(0.4,0,0,16); wsValLbl.Position=UDim2.new(0.6,0,0,4)
 local sliderTrack=Frame(wsCard,C.BG3,UDim2.new(1,0,0,8))
 sliderTrack.Position=UDim2.new(0,0,0,30); Corner(sliderTrack,4); Stroke(sliderTrack,C.BORD, 1.5,0.88)
 local sliderFill=Frame(sliderTrack,C.ACC,UDim2.new(0.1,0,1,0)); Corner(sliderFill,4)
 local sliderKnob=Frame(sliderTrack,C.ACC2,UDim2.new(0,14,0,14))
 sliderKnob.Position=UDim2.new(0.1,-7,0.5,-7); Corner(sliderKnob,7); Stroke(sliderKnob,C.ACC3,1.5,0)
 local presetRow=Frame(wsCard,C.BLACK,UDim2.new(1,0,0,16))
 presetRow.BackgroundTransparency=1; presetRow.Position=UDim2.new(0,0,0,46)
 local presets={{lbl="0%",v=0},{lbl="100%",v=16},{lbl="300%",v=48},{lbl="500%",v=80},{lbl="1000%",v=160}}
 local presetW=1/#presets
 for i,pr in ipairs(presets) do
 local pb=Btn(presetRow,C.BG3,UDim2.new(presetW,-2,1,0))
 pb.Position=UDim2.new((i-1)*presetW,1,0,0); Corner(pb,3)
 local pl=Label(pb,pr.lbl,9,C.TXT3,Enum.Font.GothamBold,Enum.TextXAlignment.Center)
 pl.Size=UDim2.new(1,0,1,0)
 pb.MouseButton1Click:Connect(function()
 local char=LP.Character
 if char then local hum=char:FindFirstChild("Humanoid"); if hum then hum.WalkSpeed=pr.v end end
 local pct=math.floor(pr.v/16*100)
 wsValLbl.Text=pr.v.." ("..pct.."%)"
 sliderFill.Size=UDim2.new(math.clamp(pr.v/160,0,1),0,1,0)
 sliderKnob.Position=UDim2.new(math.clamp(pr.v/160,0,1),-7,0.5,-7)
 end)
 end
 local isDragging=false
 function SetSpeed(relX)
 local frac=math.clamp(relX,0,1); local spd=math.floor(frac*160)
 _walkSpeedState = spd
 wsValLbl.Text=spd.." ("..math.floor(spd/16*100).."%)"
 sliderFill.Size=UDim2.new(frac,0,1,0); sliderKnob.Position=UDim2.new(frac,-7,0.5,-7)
 local char=LP.Character
 if char then local hum=char:FindFirstChild("Humanoid"); if hum then hum.WalkSpeed=spd end end
 end
 -- Expose setter berdasarkan speed value (bukan fraction)
 _setSpeedSlider = function(spd)
  SetSpeed(math.clamp(spd, 0, 160) / 160)
 end
 sliderTrack.InputBegan:Connect(function(i)
 if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
 isDragging=true; local rel=(i.Position.X-sliderTrack.AbsolutePosition.X)/sliderTrack.AbsoluteSize.X; SetSpeed(rel)
 end
 end)
 sliderTrack.InputEnded:Connect(function(i)
 if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then isDragging=false end
 end)
 UserInputService.InputChanged:Connect(function(i)
 if isDragging and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
 SetSpeed((i.Position.X-sliderTrack.AbsolutePosition.X)/sliderTrack.AbsoluteSize.X)
 end
 end)

 do
  local _r, _s, _v = ToggleRow(p,"No Clip","Tembus tembok & objek apapun selama aktif",2,function(on)
   STATE.noClip=on
   if _noClipConn then _noClipConn:Disconnect(); _noClipConn=nil end
   if on then
   _noClipConn=RunService.Stepped:Connect(function()
   local char=LP.Character; if not char then return end
   for _,part in ipairs(char:GetDescendants()) do
   if part:IsA("BasePart") and part.CanCollide then part.CanCollide=false end
   end
   end)
   else
   local char=LP.Character
   if char then
   local hrp=char:FindFirstChild("HumanoidRootPart"); local hum=char:FindFirstChildOfClass("Humanoid")
   if hrp and hum then
   local pos=hrp.CFrame; hum:ChangeState(Enum.HumanoidStateType.GettingUp)
   task.wait(0.1); hrp.CFrame=pos
   end
   end
   end
   RefreshStatus()
  end)
  _setNoClipToggle = _s
  _visNoClip = _v
 end

 do
  local _r, _s, _v = ToggleRow(p,"Anti AFK","Mencegah kick sistem idle 15 menit",4,function(on)
  STATE.antiAfk=on
  if _antiAfkThread then pcall(function() task.cancel(_antiAfkThread) end); _antiAfkThread=nil end
  if on then
  _antiAfkStart = os.time()
  _antiAfkThread = task.spawn(function()
  local _rng = Random.new()
  local _lastRemoteUse = 0
  while STATE.antiAfk do
  local interval = 180 + _rng:NextInteger(0, 120)
  local waited = 0
  while waited < interval and STATE.antiAfk do
  task.wait(1); waited = waited + 1
  end
  if not STATE.antiAfk then break end
  pcall(function()
  local char = LP.Character
  if not char then return end
  local hum = char:FindFirstChildOfClass("Humanoid")
  local hrp = char:FindFirstChild("HumanoidRootPart")
  if not hum or hum.Health <= 0 then return end
  pcall(function()
  if hum then hum:Move(Vector3.new(0.001,0,0)); task.wait(0.05); hum:Move(Vector3.new(0,0,0)) end
  end)
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
  pcall(function()
  local now = tick()
  if (now - _lastRemoteUse) >= 60 then
  _lastRemoteUse = now
  local safe = Remotes:FindFirstChild("GetRaidTeamInfos") or Remotes:FindFirstChild("GetCityRaidInfos")
  if safe then pcall(function() safe:InvokeServer() end) end
  end
  end)
  pcall(function()
  if VIM then
  VIM:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
  task.wait(0.04 + _rng:NextNumber() * 0.06)
  VIM:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
  end
  end)
  end)
  end
  end)
  else
  _antiAfkStart = nil
  end
  RefreshStatus()
  end)
  _setAntiAfkToggle = _s
  _visAntiAfk = _v
 end
 SectionHeader(p,"OTHER",10)
 local rejoinCard=Frame(p,C.SURFACE,UDim2.new(1,0,0,50))
 rejoinCard.LayoutOrder=11; Corner(rejoinCard, 10); Stroke(rejoinCard,C.BORD, 1.5,0.88); Padding(rejoinCard,8,8,12,8)
 local rejoinLbl=Label(rejoinCard,"REJOIN SERVER",12,C.TXT,Enum.Font.GothamBold)
 rejoinLbl.Size=UDim2.new(0.65,0,0,18); rejoinLbl.Position=UDim2.new(0,0,0,6)
 local rejoinSub=Label(rejoinCard,"Reconnect Same Server",10,C.TXT3,Enum.Font.GothamBold)
 rejoinSub.Size=UDim2.new(0.85,0,0,14); rejoinSub.Position=UDim2.new(0,0,0,26)
 local rejoinBtn=Btn(rejoinCard,C.ACC,UDim2.new(0,70,0,30))
 rejoinBtn.Position=UDim2.new(1,-76,0.5,-15); Corner(rejoinBtn, 10); Stroke(rejoinBtn,C.ACC2, 1.5,0.2)
 local rejoinBtnLbl=Label(rejoinBtn,"REJOIN",12,C.BLACK,Enum.Font.GothamBold,Enum.TextXAlignment.Center)
 rejoinBtnLbl.Size=UDim2.new(1,0,1,0)
 rejoinBtn.MouseButton1Click:Connect(function()
 rejoinBtnLbl.Text = "..."; 
    task.wait(0.5); 
    if RejoinServer then RejoinServer() end
 end)
end

-- ============================================================
-- PANEL : HERO FASTROLL
-- ============================================================
do
 local p = NewPanel("autoroll")
 local hrOpen = false

 -- State
 _HR_RPT = {
 guid = "",
 nameLbl = nil,
 slotLbls = {nil,nil,nil},
 slotTarget = {{},{},{}},
 running = false,
 SetSlot = function(i,txt,col)
 if _HR_RPT.slotLbls[i] then
 _HR_RPT.slotLbls[i].Text = txt
 _HR_RPT.slotLbls[i].TextColor3 = col or Color3.fromRGB(160,148,135)
 end
 end,
 Refresh = function()
 if not _HR_RPT.nameLbl then return end
 if _HR_RPT.guid and _HR_RPT.guid ~= "" then
 local found = nil
 pcall(function()
 for _, obj in ipairs(game.Players.LocalPlayer.PlayerGui:GetDescendants()) do
 if (obj:IsA("TextLabel") or obj:IsA("TextButton")) and obj.Name == "NameText" and obj.Parent and obj.Parent.Name == "HeroFrame" and obj.Parent.Parent and obj.Parent.Parent.Name == "SelectHeroBtn" then
 local t = obj.Text
 if t and #t > 2 and not t:match("^%s*$") then
 found = t; break
 end
 end
 end
 end)
 if found then
 _HR_RPT.nameLbl.Text = found
 _HR_RPT.nameLbl.TextColor3 = Color3.fromRGB(80,220,80)
 else
 _HR_RPT.nameLbl.Text = "captured"
 _HR_RPT.nameLbl.TextColor3 = Color3.fromRGB(255,200,60)
 end
 else
 _HR_RPT.nameLbl.Text = "PLEASE REROLL 1x First"
 _HR_RPT.nameLbl.TextColor3 = Color3.fromRGB(180,220,255)
 end
 end,
 SetToggleOff = function() end, -- diisi setelah toggle dibuat
 }

 -- Header dropdown
 local hrHeader = Btn(p, C.SURFACE, UDim2.new(1,0,0,38))
 hrHeader.LayoutOrder = 1; Corner(hrHeader, 10); Stroke(hrHeader,C.BORD, 1.5,0.88)
 local hrIcon = Label(hrHeader,">",12,C.ACC2,Enum.Font.GothamBold)
 hrIcon.Size = UDim2.new(0,20,1,0); hrIcon.Position = UDim2.new(0,10,0,0)
 local hrLabel = Label(hrHeader,"Hero Fastroll",13,C.TXT,Enum.Font.GothamBold)
 hrLabel.Size = UDim2.new(1,-40,1,0); hrLabel.Position = UDim2.new(0,30,0,0)

 local hrBody = Frame(p, C.BG2, UDim2.new(1,0,0,0))
 hrBody.LayoutOrder = 2; hrBody.ClipsDescendants = true
 Corner(hrBody, 10); Stroke(hrBody,C.BORD, 1.5,0.88); hrBody.Visible = false

 local hrInner = Frame(hrBody, C.BLACK, UDim2.new(1,-16,0,0))
 hrInner.BackgroundTransparency = 1; hrInner.Position = UDim2.new(0,8,0,8)
 local hrLayout = New("UIListLayout",{Parent=hrInner,SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0, 10)})

 local function ResizeHRBody()
 hrLayout:ApplyLayout()
 local h = hrLayout.AbsoluteContentSize.Y + 20
 hrInner.Size = UDim2.new(1,0,0,h); hrBody.Size = UDim2.new(1,0,0,h+16)
 end

 -- Card laporan (1 kotak besar)
 local rptCard = Frame(hrInner, C.SURFACE, UDim2.new(1,0,0,0))
 rptCard.LayoutOrder = 1; Corner(rptCard, 10); Stroke(rptCard,C.BORD, 1.5,0.88)
 rptCard.AutomaticSize = Enum.AutomaticSize.Y
 local rptPad = Instance.new("UIPadding", rptCard)
 rptPad.PaddingLeft=UDim.new(0,10); rptPad.PaddingRight=UDim.new(0,10)
 rptPad.PaddingTop=UDim.new(0, 10); rptPad.PaddingBottom=UDim.new(0, 10)
 New("UIListLayout",{Parent=rptCard,SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,4)})

 -- Nama hero
 local nameRow = Frame(rptCard, C.BG2, UDim2.new(1,0,0,26))
 nameRow.LayoutOrder = 0; Corner(nameRow,6)
 local namePre = Label(nameRow,"Hero :",11,C.TXT3,Enum.Font.GothamBold)
 namePre.Size=UDim2.new(0,46,1,0); namePre.Position=UDim2.new(0,8,0,0)
 namePre.TextXAlignment=Enum.TextXAlignment.Left
 local nameLbl = Label(nameRow,"PLEASE REROLL 1x First",11,Color3.fromRGB(180,220,255),Enum.Font.GothamBold)
 nameLbl.Size=UDim2.new(1,-58,1,0); nameLbl.Position=UDim2.new(0,54,0,0)
 nameLbl.TextXAlignment=Enum.TextXAlignment.Left
 nameLbl.TextTruncate=Enum.TextTruncate.AtEnd
 _HR_RPT.nameLbl = nameLbl

 -- Status slot 1-3
 local slotNames = {"Slot 1","Slot 2","Slot 3"}
 for i = 1, 3 do
 local sRow = Frame(rptCard, C.BG3, UDim2.new(1,0,0,24))
 sRow.LayoutOrder = i; Corner(sRow,5)
 local sPre = Label(sRow,slotNames[i].." :",11,C.TXT3,Enum.Font.GothamBold)
 sPre.Size=UDim2.new(0,46,1,0); sPre.Position=UDim2.new(0,8,0,0)
 sPre.TextXAlignment=Enum.TextXAlignment.Left
 local sLbl = Label(sRow,"Idle",11,Color3.fromRGB(160,148,135),Enum.Font.GothamBold)
 sLbl.Size=UDim2.new(1,-58,1,0); sLbl.Position=UDim2.new(0,54,0,0)
 sLbl.TextXAlignment=Enum.TextXAlignment.Left
 sLbl.TextTruncate=Enum.TextTruncate.AtEnd
 _HR_RPT.slotLbls[i] = sLbl
 end

 -- Divider
 local div1 = Frame(hrInner, C.BG3, UDim2.new(1,0,0,1))
 div1.LayoutOrder = 2; div1.BackgroundTransparency = 0.4

 -- Dropdown target per slot
 for si = 1, 3 do
 local si_l = si
 local tRow = Frame(hrInner, C.BG2, UDim2.new(1,0,0,32))
 tRow.LayoutOrder = 2 + si; Corner(tRow,6)

 local tLbl = Label(tRow,"Target "..slotNames[si].." :",11,C.TXT,Enum.Font.GothamBold)
 tLbl.Size=UDim2.new(0,92,1,0); tLbl.Position=UDim2.new(0,8,0,0)
 tLbl.TextXAlignment=Enum.TextXAlignment.Left

 local tDdBtn = Btn(tRow, C.DD_BG, UDim2.new(1,-108,0,24))
 tDdBtn.Position=UDim2.new(0,100,0.5,-12); Corner(tDdBtn,5); Stroke(tDdBtn,C.BORD2, 1.5,0.85)
 local tDdLbl = Label(tDdBtn,"-- SELECT TARGET --",10,C.TXT2,Enum.Font.GothamBold,Enum.TextXAlignment.Left)
 tDdLbl.Size=UDim2.new(1,-20,1,0); tDdLbl.Position=UDim2.new(0,7,0,0)
 tDdLbl.TextTruncate=Enum.TextTruncate.AtEnd
 local tArrow = Label(tDdBtn,"v",9,C.ACC,Enum.Font.GothamBold,Enum.TextXAlignment.Center)
 tArrow.Size=UDim2.new(0,14,1,0); tArrow.Position=UDim2.new(1,-16,0,0)

 MakeGenericDropdown({
 ddBtn = tDdBtn,
 list = QUIRK_LIST_PER_SLOT[si_l],
 maxSel = MAX_PER_SLOT,
 selTable = _HR_RPT.slotTarget[si_l],
 onRefresh = function()
 local names = {}
 for _, q in ipairs(QUIRK_LIST_PER_SLOT[si_l]) do
 if _HR_RPT.slotTarget[si_l][q.id] then
 table.insert(names, q.name)
 end
 end
 tDdLbl.Text = #names > 0 and table.concat(names," / ") or "-- SELECT TARGET --"
 tDdLbl.TextColor3 = #names > 0 and C.ACC2 or C.TXT2
 end,
 })
 end

 -- Toggle Auto Roll Hero
 local toggleRow = Frame(hrInner, C.BG2, UDim2.new(1,0,0,34))
 toggleRow.LayoutOrder = 7; Corner(toggleRow, 10); Stroke(toggleRow,C.ACC, 1.5,0.7)
 local tgLbl = Label(toggleRow,"Auto Roll Hero",12,C.TXT,Enum.Font.GothamBold)
 tgLbl.Size=UDim2.new(0.55,0,1,0); tgLbl.Position=UDim2.new(0,10,0,0)
 local tgSub = Label(toggleRow,"ON = START REROLL",9,C.TXT3,Enum.Font.GothamBold)
 tgSub.Size=UDim2.new(0.55,0,0,12); tgSub.Position=UDim2.new(0,10,1,-14)
 local hrPill = Btn(toggleRow,C.BG3,UDim2.new(0,40,0,22))
 hrPill.Position=UDim2.new(1,-50,0.5,-11); Corner(hrPill,11)
 local hrKnob = Frame(hrPill,C.TXT,UDim2.new(0,18,0,18))
 hrKnob.Position=UDim2.new(0,2,0.5,-9); Corner(hrKnob,9)

 local function SetHeroToggleUI(on)
 TweenService:Create(hrPill,TweenInfo.new(0.15),{BackgroundColor3=on and C.PILL_ON or C.BG3}):Play()
 TweenService:Create(hrKnob,TweenInfo.new(0.15),{
 Position=on and UDim2.new(1,-20,0.5,-9) or UDim2.new(0,2,0.5,-9),
 BackgroundColor3=on and Color3.fromRGB(255,255,255) or C.TXT,
 }):Play()
 end

 _HR_RPT.SetToggleOff = function()
 _HR_RPT.running = false
 SetHeroToggleUI(false)
 end

 hrPill.MouseButton1Click:Connect(function()
 _HR_RPT.running = not _HR_RPT.running
 SetHeroToggleUI(_HR_RPT.running)
 if _HR_RPT.running then
 DoAutoRollHero(true)
 else
 DoAutoRollHero(false)
 end
 end)

 -- Toggle x100 Reroll Hero
 local x100Row = Frame(hrInner, C.BG2, UDim2.new(1,0,0,34))
 x100Row.LayoutOrder = 8; Corner(x100Row, 10); Stroke(x100Row,C.ACC2, 1.5,0.7)
 local x100Lbl = Label(x100Row,"x100 Reroll",12,C.TXT,Enum.Font.GothamBold)
 x100Lbl.Size=UDim2.new(0.55,0,1,0); x100Lbl.Position=UDim2.new(0,10,0,0)
 local x100Sub = Label(x100Row,"ON = 1 roll = 100 result",9,C.TXT3,Enum.Font.GothamBold)
 x100Sub.Size=UDim2.new(0.55,0,0,12); x100Sub.Position=UDim2.new(0,10,1,-14)
 local x100Pill = Btn(x100Row,C.BG3,UDim2.new(0,40,0,22))
 x100Pill.Position=UDim2.new(1,-50,0.5,-11); Corner(x100Pill,11)
 local x100Knob = Frame(x100Pill,C.TXT,UDim2.new(0,18,0,18))
 x100Knob.Position=UDim2.new(0,2,0.5,-9); Corner(x100Knob,9)
 _HR_RPT.x100 = false
 _HR_RPT.x100Thread = nil

 local function SetX100UI(on)
  TweenService:Create(x100Pill,TweenInfo.new(0.15),{BackgroundColor3=on and C.PILL_ON or C.BG3}):Play()
  TweenService:Create(x100Knob,TweenInfo.new(0.15),{
   Position=on and UDim2.new(1,-20,0.5,-9) or UDim2.new(0,2,0.5,-9),
   BackgroundColor3=on and Color3.fromRGB(255,255,255) or C.TXT,
  }):Play()
 end

 local function StopX100()
  _HR_RPT.x100 = false
  SetX100UI(false)
  if _HR_RPT.x100Thread then
   pcall(function() task.cancel(_HR_RPT.x100Thread) end)
   _HR_RPT.x100Thread = nil
  end
  for i = 1, 3 do _HR_RPT.SetSlot(i, "Idle", Color3.fromRGB(160,148,135)) end
 end

 local function StartX100Loop()
  if _HR_RPT.x100Thread then
   pcall(function() task.cancel(_HR_RPT.x100Thread) end)
  end
  _HR_RPT.x100Thread = task.spawn(function()
   -- Tunggu GUID tersedia
   if not (_HR_RPT.guid and _HR_RPT.guid ~= "") then
    for i=1,3 do _HR_RPT.SetSlot(i,"[..] Klik 1x di Mesin Reroll dulu",Color3.fromRGB(180,220,255)) end
    while _HR_RPT.x100 and not (_HR_RPT.guid and _HR_RPT.guid ~= "") do task.wait(0.5) end
    if not _HR_RPT.x100 then return end
    task.wait(1.5)
   end
   -- Validasi remote
   if not RE.AutoHeroQuirk then
    for i=1,3 do _HR_RPT.SetSlot(i,"[!] Remote AutoRandomHeroQuirk nil",Color3.fromRGB(255,80,80)) end
    StopX100(); return
   end
   local attempt = 0
   -- [FIX] Track slot yang sudah DONE agar tidak di-roll ulang
   local slotDone = {false, false, false}

   -- [FIX] Helper: scan seluruh table (flat + nested + array) cari quirkId yang cocok target
   local function ScanResForTarget(res, targets)
    if type(res) ~= "table" then return nil, nil end
    local gotId, rawId = nil, nil
    local PRIO = {"finalResultId","quirkId","resultId","id","Id","result","Result"}
    -- Pass 1: key prioritas di root
    for _, key in ipairs(PRIO) do
     local v = res[key]
     if type(v) == "number" and v > 0 then
      rawId = rawId or v
      if QUIRK_MAP[v] then gotId = gotId or v end
      if targets[v] then return v, v end -- langsung hit target
     end
    end
    -- Pass 2: scan flat seluruh root (termasuk array index)
    for k, v in pairs(res) do
     if type(v) == "number" and v > 0 then
      rawId = rawId or v
      if QUIRK_MAP[v] then gotId = gotId or v end
      if targets[v] then return v, v end
     elseif type(v) == "table" then
      -- Pass 3: scan array/nested 1 level (cover {results={...}, data={...}})
      for _, vv in pairs(v) do
       if type(vv) == "number" and vv > 0 then
        rawId = rawId or vv
        if QUIRK_MAP[vv] then gotId = gotId or vv end
        if targets[vv] then return vv, vv end
       elseif type(vv) == "table" then
        -- Pass 4: nested 2 level (cover array of {quirkId=...} objects)
        for _, vvv in pairs(vv) do
         if type(vvv) == "number" and vvv > 0 then
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

   while _HR_RPT.x100 do
    -- [FIX] Cek apakah semua slot sudah DONE
    local allDone = true
    for si = 1, 3 do
     local list = QUIRK_LIST_PER_SLOT[si]
     local targets = _HR_RPT.slotTarget[si]
     local stopIds = {}
     for _, q in ipairs(list) do
      if targets[q.id] then table.insert(stopIds, q.id) end
     end
     if #stopIds > 0 and not slotDone[si] then allDone = false; break end
    end
    if allDone then StopX100(); break end

    for si = 1, 3 do
     -- [FIX] Skip slot yang sudah DONE, jangan di-roll lagi
     if slotDone[si] then
      -- Slot ini sudah selesai, tampilkan status DONE (no action)
     else
      local list = QUIRK_LIST_PER_SLOT[si]
      local targets = _HR_RPT.slotTarget[si]
      local drawId = ({920001,920002,920003})[si]
      -- Kumpulkan stopIds
      local stopIds = {}
      for _, q in ipairs(list) do
       if targets[q.id] then table.insert(stopIds, q.id) end
      end
      if #stopIds == 0 then
       _HR_RPT.SetSlot(si,"[!] SELECT TARGET!",Color3.fromRGB(255,100,60))
      else
       attempt = attempt + 1
       _HR_RPT.SetSlot(si,"[x100] Slot"..si.." #"..attempt.."..",Color3.fromRGB(100,200,255))
       _ourCall = true
       local ok, res = pcall(function()
        return RE.AutoHeroQuirk:InvokeServer({
         heroGuid = _HR_RPT.guid,
         drawId = drawId,
         stopQuirkIds = stopIds,
        })
       end)
       _ourCall = false
       if not ok then
        _HR_RPT.SetSlot(si,"[!] Error - retry",Color3.fromRGB(255,100,60))
       else
        -- [FIX] Scan SELURUH response (flat+nested+array) cari target
        local gotId, rawId = ScanResForTarget(res, targets)
        local hit = gotId ~= nil and targets[gotId] == true
        if hit then
         local gn = QUIRK_MAP[gotId] or "ID:"..tostring(gotId)
         _HR_RPT.SetSlot(si,"[DONE] "..gn.." (#"..attempt..")",Color3.fromRGB(80,220,80))
         slotDone[si] = true -- [FIX] Tandai slot ini selesai, tidak di-roll lagi
        else
         local gn = (gotId and QUIRK_MAP[gotId]) or (rawId and "ID:"..tostring(rawId)) or "?"
         _HR_RPT.SetSlot(si,"[x100] #"..attempt.." Last: "..gn,Color3.fromRGB(80,180,255))
        end
       end
      end
     end
    end
    task.wait(0.05)
   end
  end)
 end

 x100Pill.MouseButton1Click:Connect(function()
  _HR_RPT.x100 = not _HR_RPT.x100
  SetX100UI(_HR_RPT.x100)
  if _HR_RPT.x100 then
   -- Stop Auto Roll Hero kalau lagi jalan (2 mode tidak jalan bersamaan)
   if _HR_RPT.running then
    _HR_RPT.running = false
    SetHeroToggleUI(false)
    DoAutoRollHero(false)
   end
   StartX100Loop()
  else
   StopX100()
  end
 end)

 hrHeader.MouseButton1Click:Connect(function()
 hrOpen = not hrOpen
 hrBody.Visible = hrOpen
 hrIcon.Text = hrOpen and "v" or ">"
 if hrOpen then task.defer(ResizeHRBody) end
 end)
end

-- ============================================================
-- PANEL : WEAPON FASTROLL
-- ============================================================
do
 local p = Panels["autoroll"]
 local wrOpen = false

 _WR_RPT = {
 guid = "",
 nameLbl = nil,
 slotLbls = {nil,nil,nil},
 slotTarget = {{},{},{}},
 running = false,
 SetSlot = function(i,txt,col)
 if _WR_RPT.slotLbls[i] then
 _WR_RPT.slotLbls[i].Text = txt
 _WR_RPT.slotLbls[i].TextColor3 = col or Color3.fromRGB(160,148,135)
 end
 end,
 Refresh = function()
 if not _WR_RPT.nameLbl then return end
 if _WR_RPT.guid and _WR_RPT.guid ~= "" then
 _WR_RPT.nameLbl.Text = "Terdeteksi"
 _WR_RPT.nameLbl.TextColor3 = Color3.fromRGB(80,220,80)
 else
 _WR_RPT.nameLbl.Text = "PLEASE REROLL 1x First"
 _WR_RPT.nameLbl.TextColor3 = Color3.fromRGB(180,220,255)
 end
 end,
 SetToggleOff = function() end,
 }

 local wrHeader = Btn(p, C.SURFACE, UDim2.new(1,0,0,38))
 wrHeader.LayoutOrder = 10; Corner(wrHeader, 10); Stroke(wrHeader,C.BORD, 1.5,0.88)
 local wrIcon = Label(wrHeader,">",12,C.ACC2,Enum.Font.GothamBold)
 wrIcon.Size=UDim2.new(0,20,1,0); wrIcon.Position=UDim2.new(0,10,0,0)
 local wrLabel = Label(wrHeader,"Weapon Fastroll",13,C.TXT,Enum.Font.GothamBold)
 wrLabel.Size=UDim2.new(1,-40,1,0); wrLabel.Position=UDim2.new(0,30,0,0)

 local wrBody = Frame(p, C.BG2, UDim2.new(1,0,0,0))
 wrBody.LayoutOrder=11; wrBody.ClipsDescendants=true
 Corner(wrBody, 10); Stroke(wrBody,C.BORD, 1.5,0.88); wrBody.Visible=false

 local wrInner = Frame(wrBody, C.BLACK, UDim2.new(1,-16,0,0))
 wrInner.BackgroundTransparency=1; wrInner.Position=UDim2.new(0,8,0,8)
 local wrLayout = New("UIListLayout",{Parent=wrInner,SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0, 10)})

 local function ResizeWRBody()
 wrLayout:ApplyLayout()
 local h = wrLayout.AbsoluteContentSize.Y + 20
 wrInner.Size=UDim2.new(1,0,0,h); wrBody.Size=UDim2.new(1,0,0,h+16)
 end

 -- Card laporan
 local rptCard = Frame(wrInner, C.SURFACE, UDim2.new(1,0,0,0))
 rptCard.LayoutOrder=1; Corner(rptCard, 10); Stroke(rptCard,C.BORD, 1.5,0.88)
 rptCard.AutomaticSize=Enum.AutomaticSize.Y
 local rptPad = Instance.new("UIPadding",rptCard)
 rptPad.PaddingLeft=UDim.new(0,10); rptPad.PaddingRight=UDim.new(0,10)
 rptPad.PaddingTop=UDim.new(0, 10); rptPad.PaddingBottom=UDim.new(0, 10)
 New("UIListLayout",{Parent=rptCard,SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,4)})

 local nameRow = Frame(rptCard, C.BG2, UDim2.new(1,0,0,26))
 nameRow.LayoutOrder=0; Corner(nameRow,6)
 local namePre = Label(nameRow,"Weapon :",11,C.TXT3,Enum.Font.GothamBold)
 namePre.Size=UDim2.new(0,58,1,0); namePre.Position=UDim2.new(0,8,0,0)
 namePre.TextXAlignment=Enum.TextXAlignment.Left
 local nameLbl = Label(nameRow,"PLEASE REROLL 1x First",11,Color3.fromRGB(180,220,255),Enum.Font.GothamBold)
 nameLbl.Size=UDim2.new(1,-70,1,0); nameLbl.Position=UDim2.new(0,66,0,0)
 nameLbl.TextXAlignment=Enum.TextXAlignment.Left
 nameLbl.TextTruncate=Enum.TextTruncate.AtEnd
 _WR_RPT.nameLbl = nameLbl

 local slotNames = {"Slot 1","Slot 2","Slot 3"}
 for i = 1, 3 do
 local sRow = Frame(rptCard, C.BG3, UDim2.new(1,0,0,24))
 sRow.LayoutOrder=i; Corner(sRow,5)
 local sPre = Label(sRow,slotNames[i].." :",11,C.TXT3,Enum.Font.GothamBold)
 sPre.Size=UDim2.new(0,46,1,0); sPre.Position=UDim2.new(0,8,0,0)
 sPre.TextXAlignment=Enum.TextXAlignment.Left
 local sLbl = Label(sRow,"Idle",11,Color3.fromRGB(160,148,135),Enum.Font.GothamBold)
 sLbl.Size=UDim2.new(1,-58,1,0); sLbl.Position=UDim2.new(0,54,0,0)
 sLbl.TextXAlignment=Enum.TextXAlignment.Left
 sLbl.TextTruncate=Enum.TextTruncate.AtEnd
 _WR_RPT.slotLbls[i] = sLbl
 end

 local div1 = Frame(wrInner, C.BG3, UDim2.new(1,0,0,1))
 div1.LayoutOrder=2; div1.BackgroundTransparency=0.4

 for si = 1, 3 do
 local si_l = si
 local tRow = Frame(wrInner, C.BG2, UDim2.new(1,0,0,32))
 tRow.LayoutOrder=2+si; Corner(tRow,6)

 local tLbl = Label(tRow,"Target "..slotNames[si].." :",11,C.TXT,Enum.Font.GothamBold)
 tLbl.Size=UDim2.new(0,92,1,0); tLbl.Position=UDim2.new(0,8,0,0)
 tLbl.TextXAlignment=Enum.TextXAlignment.Left

 local tDdBtn = Btn(tRow, C.DD_BG, UDim2.new(1,-108,0,24))
 tDdBtn.Position=UDim2.new(0,100,0.5,-12); Corner(tDdBtn,5); Stroke(tDdBtn,C.BORD2, 1.5,0.85)
 local tDdLbl = Label(tDdBtn,"-- pilih quirk --",10,C.TXT2,Enum.Font.GothamBold,Enum.TextXAlignment.Left)
 tDdLbl.Size=UDim2.new(1,-20,1,0); tDdLbl.Position=UDim2.new(0,7,0,0)
 tDdLbl.TextTruncate=Enum.TextTruncate.AtEnd
 local tArrow = Label(tDdBtn,"v",9,C.ACC,Enum.Font.GothamBold,Enum.TextXAlignment.Center)
 tArrow.Size=UDim2.new(0,14,1,0); tArrow.Position=UDim2.new(1,-16,0,0)

 MakeGenericDropdown({
 ddBtn = tDdBtn,
 list = W_QUIRK_LIST_PER_SLOT[si_l],
 maxSel = W_MAX_PER_SLOT,
 selTable = _WR_RPT.slotTarget[si_l],
 onRefresh = function()
 local names = {}
 for _, q in ipairs(W_QUIRK_LIST_PER_SLOT[si_l]) do
 if _WR_RPT.slotTarget[si_l][q.id] then
 table.insert(names, q.name)
 end
 end
 tDdLbl.Text = #names > 0 and table.concat(names," / ") or "-- pilih quirk --"
 tDdLbl.TextColor3 = #names > 0 and C.ACC2 or C.TXT2
 end,
 })
 end

 local toggleRow = Frame(wrInner, C.BG2, UDim2.new(1,0,0,34))
 toggleRow.LayoutOrder=7; Corner(toggleRow, 10); Stroke(toggleRow,C.ACC, 1.5,0.7)
 local tgLbl = Label(toggleRow,"Auto Roll Weapon",12,C.TXT,Enum.Font.GothamBold)
 tgLbl.Size=UDim2.new(0.55,0,1,0); tgLbl.Position=UDim2.new(0,10,0,0)
 local tgSub = Label(toggleRow,"ON = START REROLL",9,C.TXT3,Enum.Font.GothamBold)
 tgSub.Size=UDim2.new(0.55,0,0,12); tgSub.Position=UDim2.new(0,10,1,-14)
 local wrPill = Btn(toggleRow,C.BG3,UDim2.new(0,40,0,22))
 wrPill.Position=UDim2.new(1,-50,0.5,-11); Corner(wrPill,11)
 local wrKnob = Frame(wrPill,C.TXT,UDim2.new(0,18,0,18))
 wrKnob.Position=UDim2.new(0,2,0.5,-9); Corner(wrKnob,9)

 local function SetWeaponToggleUI(on)
 TweenService:Create(wrPill,TweenInfo.new(0.15),{BackgroundColor3=on and C.PILL_ON or C.BG3}):Play()
 TweenService:Create(wrKnob,TweenInfo.new(0.15),{
 Position=on and UDim2.new(1,-20,0.5,-9) or UDim2.new(0,2,0.5,-9),
 BackgroundColor3=on and Color3.fromRGB(255,255,255) or C.TXT,
 }):Play()
 end

 _WR_RPT.SetToggleOff = function()
 _WR_RPT.running = false
 SetWeaponToggleUI(false)
 end

 wrPill.MouseButton1Click:Connect(function()
 _WR_RPT.running = not _WR_RPT.running
 SetWeaponToggleUI(_WR_RPT.running)
 if _WR_RPT.running then
 DoAutoRollWeapon(true)
 else
 DoAutoRollWeapon(false)
 end
 end)

 wrHeader.MouseButton1Click:Connect(function()
 wrOpen = not wrOpen
 wrBody.Visible = wrOpen
 wrIcon.Text = wrOpen and "v" or ">"
 if wrOpen then task.defer(ResizeWRBody) end
 end)
end

-- ============================================================
-- PANEL : AUTO ROLL - PET GEAR
-- ============================================================
do
 local p = Panels["autoroll"]
 local pgOpen = false

 local pgHeader = Btn(p, C.SURFACE, UDim2.new(1,0,0,38))
 pgHeader.LayoutOrder = 20; Corner(pgHeader, 10); Stroke(pgHeader,C.BORD, 1.5,0.88)
 local pgIcon = Label(pgHeader,">",12,C.ACC2,Enum.Font.GothamBold)
 pgIcon.Size = UDim2.new(0,20,1,0); pgIcon.Position = UDim2.new(0,10,0,0)
 local pgLabel = Label(pgHeader,"Pet Gear Fastroll",13,C.TXT,Enum.Font.GothamBold)
 pgLabel.Size = UDim2.new(1,-40,1,0); pgLabel.Position = UDim2.new(0,30,0,0)

 local pgBody = Frame(p, C.BG2, UDim2.new(1,0,0,0))
 pgBody.LayoutOrder = 21; pgBody.ClipsDescendants = true
 Corner(pgBody, 10); Stroke(pgBody,C.BORD, 1.5,0.88); pgBody.Visible = false

 local pgInner = Frame(pgBody, C.BLACK, UDim2.new(1,-16,0,0))
 pgInner.BackgroundTransparency = 1; pgInner.Position = UDim2.new(0,8,0,8)
 local pgLayout = New("UIListLayout",{Parent=pgInner,SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0, 10)})

 function ResizePGBody()
 pgLayout:ApplyLayout()
 local h = pgLayout.AbsoluteContentSize.Y + 20
 pgInner.Size = UDim2.new(1,0,0,h); pgBody.Size = UDim2.new(1,0,0,h+16)
 end

 for msi = 1, 3 do
 local msi_l = msi

 local mCard = Frame(pgInner, C.SURFACE, UDim2.new(1,0,0,0))
 mCard.LayoutOrder = msi; Corner(mCard, 10); Stroke(mCard,C.BORD, 1.5,0.88)
 mCard.AutomaticSize = Enum.AutomaticSize.Y
 local mPad = Instance.new("UIPadding", mCard)
 mPad.PaddingLeft=UDim.new(0,12); mPad.PaddingRight=UDim.new(0,12)
 mPad.PaddingTop=UDim.new(0,10); mPad.PaddingBottom=UDim.new(0,10)
 New("UIListLayout",{Parent=mCard,SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,6)})

 local mTitle = Label(mCard,""..PG_MACHINE_NAMES[msi],12,C.ACC2,Enum.Font.GothamBold)
 mTitle.Size = UDim2.new(1,0,0,18); mTitle.LayoutOrder = 0

 local statRow = Frame(mCard, C.BG2, UDim2.new(1,0,0,26))
 statRow.LayoutOrder = 1; Corner(statRow,6); Stroke(statRow,C.BORD2, 1.5,0.5)
 local mDot = Frame(statRow, Color3.fromRGB(100,100,100), UDim2.new(0,8,0,8))
 mDot.Position = UDim2.new(0,7,0.5,-4); Corner(mDot,4)
 PGR.dotRefs[msi] = mDot
 local mStLbl = Label(statRow,"Idle - Pilih target & aktifkan Roll",10,C.TXT2,Enum.Font.GothamBold)
 mStLbl.Size = UDim2.new(1,-22,1,0); mStLbl.Position = UDim2.new(0,21,0,0)
 mStLbl.TextTruncate = Enum.TextTruncate.AtEnd
 PGR.statLbls[msi] = mStLbl

 local infoRow = Frame(mCard, C.BG3, UDim2.new(1,0,0,22))
 infoRow.LayoutOrder = 2; Corner(infoRow,5)
 local attLbl = Label(infoRow,"Attempt: -",9.5,C.TXT3,Enum.Font.GothamBold)
 attLbl.Size = UDim2.new(0.5,0,1,0); attLbl.Position = UDim2.new(0,8,0,0)
 PGR.attemptLbls[msi] = attLbl
 local lastLbl = Label(infoRow,"Last: -",9.5,Color3.fromRGB(180,180,180),Enum.Font.GothamBold,Enum.TextXAlignment.Right)
 lastLbl.Size = UDim2.new(0.5,-10,1,0); lastLbl.Position = UDim2.new(0.5,0,0,0)
 PGR.lastLbls[msi] = lastLbl

 local divLine = Frame(mCard, C.BG3, UDim2.new(1,0,0,1))
 divLine.LayoutOrder = 3; divLine.BackgroundTransparency = 0.4

 local tRow = Frame(mCard, C.BG2, UDim2.new(1,0,0,32))
 tRow.LayoutOrder = 4; Corner(tRow,6)
 local tLbl = Label(tRow,"Target:",11,C.TXT,Enum.Font.GothamBold)
 tLbl.Size = UDim2.new(0,72,1,0); tLbl.Position = UDim2.new(0,8,0,0)

 local tDdBtn = Btn(tRow, C.DD_BG, UDim2.new(1,-88,0,24))
 tDdBtn.Position = UDim2.new(0,80,0.5,-12); Corner(tDdBtn,5); Stroke(tDdBtn,C.BORD2, 1.5,0.85)
 local tDdLbl = Label(tDdBtn,"-- pilih grade --",10,C.TXT2,Enum.Font.GothamBold,Enum.TextXAlignment.Left)
 tDdLbl.Size = UDim2.new(1,-20,1,0); tDdLbl.Position = UDim2.new(0,7,0,0)
 tDdLbl.TextTruncate = Enum.TextTruncate.AtEnd
 PGR.sumLbls[msi] = tDdLbl
 local tArrow = Label(tDdBtn,"v",9,C.ACC,Enum.Font.GothamBold,Enum.TextXAlignment.Center)
 tArrow.Size = UDim2.new(0,14,1,0); tArrow.Position = UDim2.new(1,-16,0,0)

 local tHint = Label(tRow,"(maks 3)",8.5,C.TXT3,Enum.Font.GothamBold,Enum.TextXAlignment.Right)
 tHint.Size = UDim2.new(0,0,1,0); tHint.AutomaticSize = Enum.AutomaticSize.X
 tHint.Position = UDim2.new(1,-4,0,0); tHint.AnchorPoint = Vector2.new(1,0)

 function onTargetChange()
 local names = {}
 for _, g in ipairs(PG_GRADES_PER_MACHINE[msi_l]) do
 if PGR.targets[msi_l][g.id] then names[#names+1] = g.name end
 end
 if PGR.sumLbls[msi_l] then
 PGR.sumLbls[msi_l].Text = #names > 0 and table.concat(names," / ") or "-- pilih grade --"
 PGR.sumLbls[msi_l].TextColor3 = #names > 0 and C.ACC2 or C.TXT2
 end
 if PGR.running[msi_l] and PGR.statLbls[msi_l] then
 if #names == 0 then
 PGR.statLbls[msi_l].Text = "Target dikosongkan!"
 PGR.statLbls[msi_l].TextColor3 = Color3.fromRGB(255,100,80)
 else
 PGR.statLbls[msi_l].Text = "Target -> "..table.concat(names," / ")
 PGR.statLbls[msi_l].TextColor3 = Color3.fromRGB(255,200,60)
 end
 end
 end

 MakeGenericDropdown({
 ddBtn = tDdBtn,
 list = PG_GRADES_PER_MACHINE[msi],
 maxSel = 3,
 selTable = PGR.targets[msi],
 onRefresh = onTargetChange,
 })

 local enRow = Frame(mCard, C.BG2, UDim2.new(1,0,0,34))
 enRow.LayoutOrder = 5; Corner(enRow, 10); Stroke(enRow,C.ACC, 1.5,0.7)

 local enLbl = Label(enRow,"Fastroll",12,C.TXT,Enum.Font.GothamBold)
 enLbl.Size = UDim2.new(0.55,0,1,0); enLbl.Position = UDim2.new(0,10,0,0)
 local enSub = Label(enRow,"ON = START REROLL",9,C.TXT3,Enum.Font.GothamBold)
 enSub.Size = UDim2.new(0.55,0,0,12); enSub.Position = UDim2.new(0,10,1,-14)

 local enToggle = Btn(enRow, C.BG3, UDim2.new(0,40,0,22))
 enToggle.Position = UDim2.new(1,-50,0.5,-11); Corner(enToggle,11)
 local enKnob = Frame(enToggle, C.TXT, UDim2.new(0,18,0,18))
 enKnob.Position = UDim2.new(0,2,0.5,-9); Corner(enKnob,9)

 PGR.toggleBtns[msi] = enToggle
    PGR.toggleKnobs[msi] = enKnob


  enToggle.MouseButton1Click:Connect(function()
  PGR.enOnFlags[msi_l] = not PGR.enOnFlags[msi_l]
  local enOn = PGR.enOnFlags[msi_l]
  enToggle.BackgroundColor3 = enOn and C.ACC or C.BG3
  enKnob.Position = enOn and UDim2.new(1,-20,0.5,-9) or UDim2.new(0,2,0.5,-9)
  enRow.BackgroundColor3 = enOn and C.SURFACE or C.BG2
  Stroke(enRow, enOn and Color3.fromRGB(255,140,0) or C.ACC, 1, enOn and 0.3 or 0.7)
  DoAutoRollPetGear(msi_l, enOn)
 end)

 -- ============================================================
 -- [v38] 100x Reroll Toggle Row
 -- ============================================================
 local r100Row = Frame(mCard, C.BG2, UDim2.new(1,0,0,34))
 r100Row.LayoutOrder = 6; Corner(r100Row, 10); Stroke(r100Row, Color3.fromRGB(0,180,200), 1.5, 0.7)

 -- Status dot
 local r100Dot = Frame(r100Row, Color3.fromRGB(100,100,100), UDim2.new(0,8,0,8))
 r100Dot.Position = UDim2.new(0,7,0.5,-4); Corner(r100Dot,4)
 PGR100.dotRefs[msi] = r100Dot

 local r100Lbl = Label(r100Row,"100x Reroll",12,Color3.fromRGB(80,220,255),Enum.Font.GothamBold)
 r100Lbl.Size = UDim2.new(0.55,0,1,0); r100Lbl.Position = UDim2.new(0,22,0,0)
 local r100Sub = Label(r100Row,"ON = 100x per invoke",9,C.TXT3,Enum.Font.GothamBold)
 r100Sub.Size = UDim2.new(0.55,0,0,12); r100Sub.Position = UDim2.new(0,22,1,-14)

 local r100Toggle = Btn(r100Row, C.BG3, UDim2.new(0,40,0,22))
 r100Toggle.Position = UDim2.new(1,-50,0.5,-11); Corner(r100Toggle,11)
 local r100Knob = Frame(r100Toggle, C.TXT, UDim2.new(0,18,0,18))
 r100Knob.Position = UDim2.new(0,2,0.5,-9); Corner(r100Knob,9)

 PGR100.toggleBtns[msi] = r100Toggle
 PGR100.toggleKnobs[msi] = r100Knob

 -- Status label (bersama, di bawah toggle row)
 local r100StatRow = Frame(mCard, C.BG3, UDim2.new(1,0,0,22))
 r100StatRow.LayoutOrder = 7; Corner(r100StatRow,5)
 local r100AttLbl = Label(r100StatRow,"100x Batch: -",9.5,C.TXT3,Enum.Font.GothamBold)
 r100AttLbl.Size = UDim2.new(0.5,0,1,0); r100AttLbl.Position = UDim2.new(0,8,0,0)
 PGR100.attemptLbls[msi] = r100AttLbl
 local r100LastLbl = Label(r100StatRow,"Last: -",9.5,Color3.fromRGB(180,180,180),Enum.Font.GothamBold,Enum.TextXAlignment.Right)
 r100LastLbl.Size = UDim2.new(0.5,-10,1,0); r100LastLbl.Position = UDim2.new(0.5,0,0,0)
 PGR100.lastLbls[msi] = r100LastLbl

 local r100StatFullRow = Frame(mCard, C.BG2, UDim2.new(1,0,0,26))
 r100StatFullRow.LayoutOrder = 8; Corner(r100StatFullRow,6); Stroke(r100StatFullRow, Color3.fromRGB(0,180,200), 1.5, 0.5)
 local r100StatDot = Frame(r100StatFullRow, Color3.fromRGB(100,100,100), UDim2.new(0,8,0,8))
 r100StatDot.Position = UDim2.new(0,7,0.5,-4); Corner(r100StatDot,4)
 local r100StLbl = Label(r100StatFullRow,"[100x] Idle",10,C.TXT2,Enum.Font.GothamBold)
 r100StLbl.Size = UDim2.new(1,-22,1,0); r100StLbl.Position = UDim2.new(0,21,0,0)
 r100StLbl.TextTruncate = Enum.TextTruncate.AtEnd
 PGR100.statLbls[msi] = r100StLbl

 local msi_r100 = msi
 r100Toggle.MouseButton1Click:Connect(function()
   PGR100.enOnFlags[msi_r100] = not PGR100.enOnFlags[msi_r100]
   local r100On = PGR100.enOnFlags[msi_r100]
   r100Toggle.BackgroundColor3 = r100On and Color3.fromRGB(0,180,200) or C.BG3
   r100Knob.Position = r100On and UDim2.new(1,-20,0.5,-9) or UDim2.new(0,2,0.5,-9)
   r100Row.BackgroundColor3 = r100On and C.SURFACE or C.BG2
   Stroke(r100Row, r100On and Color3.fromRGB(0,230,255) or Color3.fromRGB(0,180,200), 1.5, r100On and 0.3 or 0.7)
   if r100On then
     -- Stop Fastroll biasa dulu kalau aktif (tidak boleh 2 loop jalan bersamaan di slot yg sama)
     if PGR.enOnFlags[msi_r100] then
       PGR.enOnFlags[msi_r100] = false
       enToggle.BackgroundColor3 = C.BG3
       enKnob.Position = UDim2.new(0,2,0.5,-9)
       DoAutoRollPetGear(msi_r100, false)
     end
     PGR100.Loop(msi_r100)
   else
     PGR100.enOnFlags[msi_r100] = false
     if PGR100.threads[msi_r100] then
       pcall(task.cancel, PGR100.threads[msi_r100])
       PGR100.threads[msi_r100] = nil
     end
     PGR100.running[msi_r100] = false
     r100StLbl.Text = "[100x] Idle"
     r100StLbl.TextColor3 = C.TXT2
     r100StatDot.BackgroundColor3 = Color3.fromRGB(100,100,100)
   end
 end) -- end r100Toggle.MouseButton1Click
 end -- end for msi = 1, 3 do

 pgHeader.MouseButton1Click:Connect(function()
 pgOpen = not pgOpen
 pgBody.Visible = pgOpen
 pgIcon.Text = pgOpen and "v" or ">"
 if pgOpen then task.defer(ResizePGBody) end
 end)
end

-- ============================================================
-- PANEL : AUTO ROLL - HALO
-- ============================================================
do
 local p = Panels["autoroll"]
 local haloOpen = false

 local haloHeader = Btn(p, C.SURFACE, UDim2.new(1,0,0,38))
 haloHeader.LayoutOrder = 30; Corner(haloHeader, 10); Stroke(haloHeader,C.BORD, 1.5,0.88)
 local haloIcon = Label(haloHeader,">",12,C.ACC2,Enum.Font.GothamBold)
 haloIcon.Size = UDim2.new(0,20,1,0); haloIcon.Position = UDim2.new(0,10,0,0)
 local haloLabel = Label(haloHeader,"Auto Gacha Halo",13,C.TXT,Enum.Font.GothamBold)
 haloLabel.Size = UDim2.new(1,-40,1,0); haloLabel.Position = UDim2.new(0,30,0,0)

 local haloBody = Frame(p, C.BG2, UDim2.new(1,0,0,0))
 haloBody.LayoutOrder = 31; haloBody.ClipsDescendants = true
 Corner(haloBody, 10); Stroke(haloBody,C.BORD, 1.5,0.88); haloBody.Visible = false

 local haloInner = Frame(haloBody, C.BLACK, UDim2.new(1,-16,0,0))
 haloInner.BackgroundTransparency = 1; haloInner.Position = UDim2.new(0,8,0,8)
 local haloLayout = New("UIListLayout",{Parent=haloInner,SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0, 10)})

 function ResizeHaloBody()
 haloLayout:ApplyLayout()
 local h = haloLayout.AbsoluteContentSize.Y + 20
 haloInner.Size = UDim2.new(1,0,0,h); haloBody.Size = UDim2.new(1,0,0,h+16)
 end

 local HALO_COLORS = {C.ACC, C.ACC2, C.ACC3}
 local HALO_ICONS = {"","",""}

 for hi = 1, 3 do
 local hi_l = hi

 local hCard = Frame(haloInner, C.SURFACE, UDim2.new(1,0,0,0))
 hCard.LayoutOrder = hi; Corner(hCard, 10); Stroke(hCard,C.BORD, 1.5,0.88)
 hCard.AutomaticSize = Enum.AutomaticSize.Y
 local hPad = Instance.new("UIPadding", hCard)
 hPad.PaddingLeft=UDim.new(0,12); hPad.PaddingRight=UDim.new(0,12)
 hPad.PaddingTop=UDim.new(0,10); hPad.PaddingBottom=UDim.new(0,10)
 New("UIListLayout",{Parent=hCard,SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,6)})

 local hTitle = Label(hCard, HALO_NAMES[hi], 14, C.ACC, Enum.Font.GothamBold)
 hTitle.Size = UDim2.new(1,0,0,18); hTitle.LayoutOrder = 0

 local statRow = Frame(hCard, C.BG2, UDim2.new(1,0,0,26))
 statRow.LayoutOrder = 1; Corner(statRow,6); Stroke(statRow,C.BORD2, 1.5,0.5)
 local hDot = Frame(statRow, Color3.fromRGB(100,100,100), UDim2.new(0,8,0,8))
 hDot.Position = UDim2.new(0,7,0.5,-4); Corner(hDot,4)
 HALO.dotRefs[hi] = hDot
 local hStLbl = Label(statRow,"Idle - Enable to Start Gacha",10,C.TXT2,Enum.Font.GothamBold)
 hStLbl.Size = UDim2.new(1,-22,1,0); hStLbl.Position = UDim2.new(0,21,0,0)
 hStLbl.TextTruncate = Enum.TextTruncate.AtEnd
 HALO.statLbls[hi] = hStLbl

 local infoRow = Frame(hCard, C.BG3, UDim2.new(1,0,0,22))
 infoRow.LayoutOrder = 2; Corner(infoRow,5)
 local attLbl = Label(infoRow,"Attempt: -",9.5,C.TXT3,Enum.Font.GothamBold)
 attLbl.Size = UDim2.new(1,-8,1,0); attLbl.Position = UDim2.new(0,8,0,0)
 HALO.attemptLbls[hi] = attLbl

 local enRow = Frame(hCard, C.BG2, UDim2.new(1,0,0,34))
 enRow.LayoutOrder = 4; Corner(enRow, 10); Stroke(enRow, C.ACC, 1.5, 0.6)

 local enLbl = Label(enRow,"Auto Gacha",12,C.TXT,Enum.Font.GothamBold)
 enLbl.Size = UDim2.new(0.6,0,1,0); enLbl.Position = UDim2.new(0,10,0,0)
 local enSub = Label(enRow,"ON = START GACHA",9,C.TXT3,Enum.Font.GothamBold)
 enSub.Size = UDim2.new(0.6,0,0,12); enSub.Position = UDim2.new(0,10,1,-14)

 local enToggle = Btn(enRow, C.BG3, UDim2.new(0,40,0,22))
 enToggle.Position = UDim2.new(1,-50,0.5,-11); Corner(enToggle,11)
 local enKnob = Frame(enToggle, C.TXT, UDim2.new(0,18,0,18))
 enKnob.Position = UDim2.new(0,2,0.5,-9); Corner(enKnob,9)

 HALO.toggleBtns[hi] = enToggle
 HALO.toggleKnobs[hi] = enKnob

 enToggle.MouseButton1Click:Connect(function()
 HALO.enOnFlags[hi_l] = not HALO.enOnFlags[hi_l]
 local enOn = HALO.enOnFlags[hi_l]
 enToggle.BackgroundColor3 = enOn and C.ACC or C.BG3
 enKnob.Position = enOn and UDim2.new(1,-20,0.5,-9) or UDim2.new(0,2,0.5,-9)
 enRow.BackgroundColor3 = enOn and C.BG2 or C.BG2
 Stroke(enRow, C.ACC, 1.5, enOn and 0.2 or 0.6)
 DoAutoRollHalo(hi_l, enOn)
 end)
 end

 haloHeader.MouseButton1Click:Connect(function()
 haloOpen = not haloOpen
 haloBody.Visible = haloOpen
 haloIcon.Text = haloOpen and "v" or ">"
 if haloOpen then task.defer(ResizeHaloBody) end
 end)
end

-- ============================================================
-- PANEL : AUTO ROLL - ORNAMENT
-- ============================================================
do
 local p = Panels["autoroll"]
 local ornOpen = false

 local ornHeader = Btn(p, C.SURFACE, UDim2.new(1,0,0,38))
 ornHeader.LayoutOrder = 35; Corner(ornHeader, 10); Stroke(ornHeader,C.BORD, 1.5,0.88)
 local ornIcon = Label(ornHeader,">",12,C.ACC2,Enum.Font.GothamBold)
 ornIcon.Size = UDim2.new(0,20,1,0); ornIcon.Position = UDim2.new(0,10,0,0)
 local ornLabel = Label(ornHeader,"Auto Roll Ornament",13,C.TXT,Enum.Font.GothamBold)
 ornLabel.Size = UDim2.new(1,-40,1,0); ornLabel.Position = UDim2.new(0,30,0,0)

 local ornBody = Frame(p, C.BG2, UDim2.new(1,0,0,0))
 ornBody.LayoutOrder = 36; ornBody.ClipsDescendants = true
 Corner(ornBody, 10); Stroke(ornBody,C.BORD, 1.5,0.88); ornBody.Visible = false

 local ornInner = Frame(ornBody, C.BLACK, UDim2.new(1,-16,0,0))
 ornInner.BackgroundTransparency = 1; ornInner.Position = UDim2.new(0,8,0,8)
 ornInner.AutomaticSize = Enum.AutomaticSize.Y
 local ornLayout = New("UIListLayout",{Parent=ornInner,SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0, 10)})
 Instance.new("UIPadding", ornInner).PaddingBottom = UDim.new(0, 12)

 function ResizeOrnBody()
 ornLayout:ApplyLayout()
 local h = ornLayout.AbsoluteContentSize.Y + 28
 ornInner.Size = UDim2.new(1,0,0,h)
 ornBody.Size = UDim2.new(1,0,0,h+16)
 end

 local ORN_COLORS = {
 Color3.fromRGB(200,160,255),
 Color3.fromRGB(255,180,100),
 Color3.fromRGB(100,220,180),
 Color3.fromRGB(255,120,120),
 Color3.fromRGB(120,200,255),
 Color3.fromRGB(200,255,120),
 }
 local ORN_ICONS = {"","","","","",""}

 -- Info cara pakai
 local infoCard = Frame(ornInner, C.BG2, UDim2.new(1,0,0,0))
 infoCard.LayoutOrder = 0; infoCard.AutomaticSize = Enum.AutomaticSize.Y
 Corner(infoCard,7); Stroke(infoCard,C.ACC, 1.5,0.5)
 local infoPad = Instance.new("UIPadding",infoCard)
 infoPad.PaddingLeft=UDim.new(0,10); infoPad.PaddingRight=UDim.new(0,10)
 infoPad.PaddingTop=UDim.new(0,7); infoPad.PaddingBottom=UDim.new(0,7)
 local infoLbl = Label(infoCard,
 "[i] Enable the Fastroll toggle to start rolling automatically without stopping.",
 9.5, Color3.fromRGB(230,210,170), Enum.Font.GothamBold)
 infoLbl.Size = UDim2.new(1,0,0,0); infoLbl.AutomaticSize = Enum.AutomaticSize.Y
 infoLbl.TextWrapped = true; infoLbl.LayoutOrder = 0

 for mi = 1, #_ASH_ORN.MACHINES do
 local mi_l = mi
 local mInfo = _ASH_ORN.MACHINES[mi]

 local mCard = Frame(ornInner, C.SURFACE, UDim2.new(1,0,0,0))
 mCard.LayoutOrder = mi; Corner(mCard, 10); Stroke(mCard,C.BORD, 1.5,0.88)
 mCard.AutomaticSize = Enum.AutomaticSize.Y
 local mPad = Instance.new("UIPadding", mCard)
 mPad.PaddingLeft=UDim.new(0,12); mPad.PaddingRight=UDim.new(0,12)
 mPad.PaddingTop=UDim.new(0,10); mPad.PaddingBottom=UDim.new(0,10)
 New("UIListLayout",{Parent=mCard,SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,6)})

 -- Title
 local mTitle = Label(mCard, mInfo.name, 14, C.TXT, Enum.Font.GothamBold)
 mTitle.Size = UDim2.new(1,0,0,18); mTitle.LayoutOrder = 0

 -- Status row
 local statRow = Frame(mCard, C.BG2, UDim2.new(1,0,0,26))
 statRow.LayoutOrder = 1; Corner(statRow,6); Stroke(statRow,C.BORD2, 1.5,0.5)
 local mDot = Frame(statRow, Color3.fromRGB(100,100,100), UDim2.new(0,8,0,8))
 mDot.Position = UDim2.new(0,7,0.5,-4); Corner(mDot,4)
 ORN.dotRefs[mi] = mDot
 local mStLbl = Label(statRow,"Idle - SELECT TARGET & ENABLE",10,C.TXT2,Enum.Font.GothamBold)
 mStLbl.Size = UDim2.new(1,-22,1,0); mStLbl.Position = UDim2.new(0,21,0,0)
 mStLbl.TextTruncate = Enum.TextTruncate.AtEnd
 ORN.statLbls[mi] = mStLbl

 -- Info attempt & last
 local infoRow = Frame(mCard, C.BG3, UDim2.new(1,0,0,22))
 infoRow.LayoutOrder = 2; Corner(infoRow,5)
 local attLbl = Label(infoRow,"Attempt: -",9.5,C.TXT3,Enum.Font.GothamBold)
 attLbl.Size = UDim2.new(0.5,0,1,0); attLbl.Position = UDim2.new(0,8,0,0)
 ORN.attemptLbls[mi] = attLbl
 local lastLbl = Label(infoRow,"Last: -",9.5,Color3.fromRGB(180,180,180),Enum.Font.GothamBold,Enum.TextXAlignment.Right)
 lastLbl.Size = UDim2.new(0.5,-10,1,0); lastLbl.Position = UDim2.new(0.5,0,0,0)
 ORN.lastLbls[mi] = lastLbl

 local divLine = Frame(mCard, C.BG3, UDim2.new(1,0,0,1))
 divLine.LayoutOrder = 3; divLine.BackgroundTransparency = 0.4

 -- Enable toggle
 local enRow = Frame(mCard, C.BG2, UDim2.new(1,0,0,34))
 enRow.LayoutOrder = 6; Corner(enRow, 10); Stroke(enRow,ORN_COLORS[mi], 1.5,0.7)

 local enLbl = Label(enRow,"Fastroll",12,C.TXT,Enum.Font.GothamBold)
 enLbl.Size = UDim2.new(0.55,0,1,0); enLbl.Position = UDim2.new(0,10,0,0)
 local enSub = Label(enRow,"ON = START REROLL",9,C.TXT3,Enum.Font.GothamBold)
 enSub.Size = UDim2.new(0.55,0,0,12); enSub.Position = UDim2.new(0,10,1,-14)

 local enToggle = Btn(enRow, C.BG3, UDim2.new(0,40,0,22))
 enToggle.Position = UDim2.new(1,-50,0.5,-11); Corner(enToggle,11)
 local enKnob = Frame(enToggle, C.TXT, UDim2.new(0,18,0,18))
 enKnob.Position = UDim2.new(0,2,0.5,-9); Corner(enKnob,9)

 ORN.toggleBtns[mi] = enToggle
 ORN.toggleKnobs[mi] = enKnob

 enToggle.MouseButton1Click:Connect(function()
 ORN.enOnFlags[mi_l] = not ORN.enOnFlags[mi_l]
 local enOn = ORN.enOnFlags[mi_l]
 enToggle.BackgroundColor3 = enOn and C.ACC or C.BG3
 enKnob.Position = enOn and UDim2.new(1,-20,0.5,-9) or UDim2.new(0,2,0.5,-9)
 enRow.BackgroundColor3 = enOn and C.SURFACE or C.BG2
 Stroke(enRow, C.ACC, 1.5, enOn and 0.3 or 0.7)
 _ASH_ORN.DoRoll(mi_l, enOn)
 end)

 task.defer(ResizeOrnBody)
 end

 ornHeader.MouseButton1Click:Connect(function()
 ornOpen = not ornOpen
 ornBody.Visible = ornOpen
 ornIcon.Text = ornOpen and "v" or ">"
 if ornOpen then task.defer(ResizeOrnBody) end
 end)
end


do
 -- [v243] Merge & Use Potion dipindah ke panel MAIN (di bawah Auto Sell HeroEquip)
 local p = Panels["main"]

 -- ============================================================
 -- POTION DATA
 -- ============================================================
 local MERGE_POTIONS = {
 {name="Small Attack Potion", id=10048},
 {name="Small Gold Potion", id=10049},
 {name="Small Luck Potion", id=10047},
 {name="Big Potion DMG", id=10051},
 {name="Big Potion Gold", id=10052},
 {name="Big Potion Luck", id=10050},
 }

 local USE_POTIONS = {
 {name="Small Potion DMG", id=10048},
 {name="Small Potion Gold", id=10049},
 {name="Small Potion Luck", id=10047},
 {name="Big Potion DMG", id=10051},
 {name="Big Potion Gold", id=10052},
 {name="Big Potion Luck", id=10050},
 {name="Super Potion DMG", id=10060},
 {name="Super Potion Gold", id=10061},
 {name="Super Potion Luck", id=10059},
 }

 -- ============================================================
 -- HELPER: Dropdown list (arah ke bawah, single-select)
 -- [v243 FIX] Bug dropdown tidak bisa pilih item:
 -- Root cause: UserInputService.InputBegan terpicu lebih dulu dari
 -- Solusi final: pakai backdrop TextButton transparan di belakang list.
 -- Saat user klik item -> handler item jalan dulu (ZIndex lebih tinggi),
 -- backdrop tidak pernah racing dengan item click sama sekali.
 -- Default sel = nil (kosong) agar user pilih sendiri.
 -- ============================================================
 local _activeDD = nil

 local function MakeDropdown(parent, options, onChange)
 -- sel = nil berarti belum ada pilihan (tampil placeholder)
 local sel = nil
 local isOpen = false

 local wrap = Frame(parent, C.BLACK, UDim2.new(1,0,0,30))
 wrap.BackgroundTransparency = 1
 wrap.ClipsDescendants = false

 local btn = Btn(wrap, C.BG3, UDim2.new(1,0,0,30))
 btn.ZIndex = 10; Corner(btn,7); Stroke(btn,C.BORD, 1.5,0.6)
 local btnLbl = Label(btn, "-- SELECT Item --", 11, C.DIM, Enum.Font.GothamBold)
 btnLbl.Size = UDim2.new(1,-24,1,0); btnLbl.Position = UDim2.new(0,8,0,0); btnLbl.ZIndex = 11
 local arrow = Label(btn,"v",11,C.ACC,Enum.Font.GothamBold,Enum.TextXAlignment.Right)
 arrow.Size = UDim2.new(0,20,1,0); arrow.Position = UDim2.new(1,-22,0,0); arrow.ZIndex = 11

 -- Backdrop: menutup seluruh layar di belakang list, klik -> tutup
 local backdrop = Btn(ScreenGui, C.BLACK, UDim2.new(1,0,1,0))
 backdrop.BackgroundTransparency = 1
 backdrop.ZIndex = 19
 backdrop.Visible = false
 backdrop.Active = true

 -- List frame overlay langsung di ScreenGui
 local listFrame = Frame(ScreenGui, C.BG2, UDim2.new(0,1,0,1))
 listFrame.Visible = false; listFrame.ZIndex = 20
 Corner(listFrame,7); Stroke(listFrame,C.BORD, 1.5,0.5)
 New("UIListLayout",{Parent=listFrame,SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,2)})
 local pad = Instance.new("UIPadding",listFrame)
 pad.PaddingTop=UDim.new(0,4); pad.PaddingBottom=UDim.new(0,4)
 pad.PaddingLeft=UDim.new(0,4); pad.PaddingRight=UDim.new(0,4)

 local function closeDD()
 isOpen = false
 listFrame.Visible = false
 backdrop.Visible = false
 arrow.Text = "v"
 if _activeDD == listFrame then _activeDD = nil end
 end

 -- Backdrop klik -> tutup (tidak ada race, item ZIndex lebih tinggi)
 backdrop.MouseButton1Click:Connect(closeDD)

 -- Buat item list
 local itemLabels = {}
 for oi, opt in ipairs(options) do
 local oi_l = oi
 local item = Btn(listFrame, C.SURFACE, UDim2.new(1,0,0,28))
 item.LayoutOrder = oi; item.ZIndex = 21; Corner(item,5)
 local iLbl = Label(item, opt.label, 11, C.TXT, Enum.Font.GothamBold)
 iLbl.Size = UDim2.new(1,-8,1,0); iLbl.Position = UDim2.new(0,8,0,0); iLbl.ZIndex = 22
 itemLabels[oi] = iLbl

 item.MouseButton1Click:Connect(function()
 -- Update pilihan
 sel = oi_l
 btnLbl.Text = options[sel].label
 btnLbl.TextColor3 = C.TXT
 -- Reset warna semua label
 for _, lbl in pairs(itemLabels) do lbl.TextColor3 = C.TXT end
 iLbl.TextColor3 = C.ACC2
 -- Callback
 if onChange then onChange(options[sel].value, sel) end
 -- Tutup
 closeDD()
 end)
 end

 btn.MouseButton1Click:Connect(function()
 if isOpen then closeDD(); return end
 -- Tutup dropdown lain
 if _activeDD and _activeDD ~= listFrame then
 _activeDD.Visible = false
 if _activeDD.Parent then
 -- reset backdrop lain
 end
 end
 isOpen = true; _activeDD = listFrame; arrow.Text = "^"
 local abs = btn.AbsolutePosition
 local sz = btn.AbsoluteSize
 local lh = #options * 32 + 12
 listFrame.Position = UDim2.new(0, abs.X, 0, abs.Y + sz.Y + 2)
 listFrame.Size = UDim2.new(0, sz.X, 0, lh)
 listFrame.Visible = true
 backdrop.Visible = true
 end)

 local function GetSelected()
 if sel == nil then return nil, nil end
 return options[sel].value, sel
 end
 return wrap, GetSelected
 end

 -- ============================================================
 -- HELPER: Slider (min..max, step 1)
 -- ============================================================
 local function MakeSlider(parent, minV, maxV, defaultV, onChange)
 local val = defaultV or minV
 local wrap = Frame(parent, C.BLACK, UDim2.new(1,0,0,32))
 wrap.BackgroundTransparency = 1

 local track = Frame(wrap, C.BG3, UDim2.new(1,-50,0,6))
 track.Position = UDim2.new(0,0,0.5,-3); Corner(track,3)
 local fill = Frame(track, C.ACC, UDim2.new((val-minV)/(maxV-minV),0,1,0))
 Corner(fill,3)
 local knob = Btn(track, C.KNOB_ON, UDim2.new(0,16,0,16))
 knob.AnchorPoint = Vector2.new(0.5,0.5)
 knob.Position = UDim2.new((val-minV)/(maxV-minV),0,0.5,0)
 Corner(knob, 10); Stroke(knob,C.ACC, 1.5,0.3)

 local valLbl = Label(wrap, tostring(val), 11, C.ACC2, Enum.Font.GothamBold, Enum.TextXAlignment.Right)
 valLbl.Size = UDim2.new(0,40,1,0); valLbl.Position = UDim2.new(1,-40,0,0)

 local dragging = false
 local function updateFromPos(ax)
 local tAbs = track.AbsolutePosition
 local tSz = track.AbsoluteSize
 local t = math.clamp((ax - tAbs.X) / tSz.X, 0, 1)
 val = math.floor(minV + t * (maxV - minV) + 0.5)
 local tt = (val-minV)/(maxV-minV)
 fill.Size = UDim2.new(tt,0,1,0)
 knob.Position = UDim2.new(tt,0,0.5,0)
 valLbl.Text = tostring(val)
 if onChange then onChange(val) end
 end

 knob.InputBegan:Connect(function(i)
 if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then
 dragging = true
 end
 end)
 UserInputService.InputChanged:Connect(function(i)
 if dragging and (i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseMovement) then
 updateFromPos(i.Position.X)
 end
 end)
 UserInputService.InputEnded:Connect(function(i)
 if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then
 dragging = false
 end
 end)
 track.InputBegan:Connect(function(i)
 if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then
 updateFromPos(i.Position.X)
 end
 end)

 local function GetVal() return val end
 return wrap, GetVal
 end

 -- ============================================================
 -- PANEL: AUTO MERGE POTION
 -- ============================================================
 local mergeOpen = false
 local mergeHeader = Btn(p, C.SURFACE, UDim2.new(1,0,0,38))
 mergeHeader.LayoutOrder = 10; Corner(mergeHeader, 10); Stroke(mergeHeader,C.BORD, 1.5,0.88)
 local mergeIcon = Label(mergeHeader,">",12,C.ACC2,Enum.Font.GothamBold)
 mergeIcon.Size = UDim2.new(0,20,1,0); mergeIcon.Position = UDim2.new(0,10,0,0)
 local mergeTitleLbl = Label(mergeHeader,"AUTO MERGE POTION",13,C.TXT,Enum.Font.GothamBold)
 mergeTitleLbl.Size = UDim2.new(1,-40,1,0); mergeTitleLbl.Position = UDim2.new(0,30,0,0)

 local mergeBody = Frame(p, C.BG2, UDim2.new(1,0,0,0))
 mergeBody.LayoutOrder = 11; mergeBody.ClipsDescendants = false
 Corner(mergeBody, 10); Stroke(mergeBody,C.BORD, 1.5,0.25); mergeBody.Visible = false

 local mergeInner = Frame(mergeBody, C.BLACK, UDim2.new(1,-16,0,0))
 mergeInner.BackgroundTransparency = 1; mergeInner.Position = UDim2.new(0,8,0,8)
 mergeInner.AutomaticSize = Enum.AutomaticSize.Y
 local mergeLayout = New("UIListLayout",{Parent=mergeInner,SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0, 10)})
 Instance.new("UIPadding",mergeInner).PaddingBottom = UDim.new(0,10)

 local function ResizeMergeBody()
 mergeLayout:ApplyLayout()
 local h = mergeLayout.AbsoluteContentSize.Y + 28
 mergeInner.Size = UDim2.new(1,0,0,h)
 mergeBody.Size = UDim2.new(1,0,0,h+16)
 end

 -- State merge
 local _mergeSelectedId = nil -- nil = belum dipilih user
 local _mergeCount = 1
 local _mergeRunning = false
 local _mergeThread = nil
 local _mergeStatusLbl = nil

 -- Status bar
 local mStatusCard = Frame(mergeInner, C.BG3, UDim2.new(1,0,0,26))
 mStatusCard.LayoutOrder = 0; Corner(mStatusCard,6); Stroke(mStatusCard,C.ACC, 1.5,0.4)
 _mergeStatusLbl = Label(mStatusCard,"Idle - SELECT ITEM & ENABLE",9,C.TXT2,Enum.Font.GothamBold)
 _mergeStatusLbl.Size = UDim2.new(1,-10,1,0); _mergeStatusLbl.Position = UDim2.new(0,8,0,0)
 _mergeStatusLbl.TextTruncate = Enum.TextTruncate.AtEnd

 -- Row: SELECT ITEM dropdown
 local mSelectRow = Frame(mergeInner, C.SURFACE, UDim2.new(1,0,0,0))
 mSelectRow.LayoutOrder = 1; Corner(mSelectRow, 10); Stroke(mSelectRow,C.BORD, 1.5,0.88)
 mSelectRow.AutomaticSize = Enum.AutomaticSize.Y
 local mSelectPad = Instance.new("UIPadding",mSelectRow)
 mSelectPad.PaddingLeft=UDim.new(0,10); mSelectPad.PaddingRight=UDim.new(0,10)
 mSelectPad.PaddingTop=UDim.new(0, 10); mSelectPad.PaddingBottom=UDim.new(0, 10)
 New("UIListLayout",{Parent=mSelectRow,SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,6)})

 local mSelLabel = Label(mSelectRow,"SELECT ITEM",10,C.TXT3,Enum.Font.GothamBold)
 mSelLabel.Size = UDim2.new(1,0,0,14); mSelLabel.LayoutOrder = 0

 local mDDOpts = {}
 for _, pt in ipairs(MERGE_POTIONS) do
 table.insert(mDDOpts, {label=pt.name, value=pt.id})
 end

 local mDDWrap, mGetSel = MakeDropdown(mSelectRow, mDDOpts, function(val, idx)
 _mergeSelectedId = val
 if _mergeStatusLbl then _mergeStatusLbl.Text = "ITEM SELECTED: " .. mDDOpts[idx].label end
 end)
 mDDWrap.LayoutOrder = 1

 -- Row: COUNT slider 1-5
 local mCountRow = Frame(mergeInner, C.SURFACE, UDim2.new(1,0,0,0))
 mCountRow.LayoutOrder = 2; Corner(mCountRow, 10); Stroke(mCountRow,C.BORD, 1.5,0.88)
 mCountRow.AutomaticSize = Enum.AutomaticSize.Y
 local mCntPad = Instance.new("UIPadding",mCountRow)
 mCntPad.PaddingLeft=UDim.new(0,10); mCntPad.PaddingRight=UDim.new(0,10)
 mCntPad.PaddingTop=UDim.new(0, 10); mCntPad.PaddingBottom=UDim.new(0, 10)
 New("UIListLayout",{Parent=mCountRow,SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,4)})

 local mCntLabel = Label(mCountRow,"COUNT",10,C.TXT3,Enum.Font.GothamBold)
 mCntLabel.Size = UDim2.new(1,0,0,14); mCntLabel.LayoutOrder = 0

 local mSliderWrap, mGetCount = MakeSlider(mCountRow, 1, 5, 1, function(v)
 _mergeCount = v
 end)
 mSliderWrap.LayoutOrder = 1; mSliderWrap.Size = UDim2.new(1,0,0,32)

 -- Toggle ON/OFF
 local _, _mergeToggleSet, _mergeVis = ToggleRow(mergeInner,"Merge Potion","ON = START merge",3,function(on)
 if on then
 if not _mergeSelectedId then
 if _mergeStatusLbl then _mergeStatusLbl.Text = "[!] SELECT ITEM PLEASE!" end
 -- matikan toggle lagi
 if _mergeToggleSet then task.defer(function() _mergeToggleSet(false) end) end
 return
 end
 _mergeRunning = true
 _mergeRunningState = true
 if _mergeThread then pcall(function() task.cancel(_mergeThread) end) end
 _mergeThread = task.spawn(function()
 while _mergeRunning do
 local id = _mergeSelectedId
 local cnt = _mergeCount
 if _mergeStatusLbl then _mergeStatusLbl.Text = "[M] Merging id=" .. id .. " x" .. cnt end
 pcall(function()
 local re = Remotes:FindFirstChild("PotionMerge")
 if re then re:InvokeServer({id=id, count=cnt}) end
 end)
 if _mergeStatusLbl then _mergeStatusLbl.Text = "[OK] Merge DONE x" .. cnt end
 task.wait(0.5)
 end
 if _mergeStatusLbl then _mergeStatusLbl.Text = "Idle - toggle OFF" end
 end)
 else
 _mergeRunning = false
 _mergeRunningState = false
 if _mergeThread then pcall(function() task.cancel(_mergeThread) end); _mergeThread = nil end
 if _mergeStatusLbl then _mergeStatusLbl.Text = "Idle - SELECT ITEM & ENABLE" end
 end
 end)
 _setMergeToggle = _mergeToggleSet
 _visMerge = _mergeVis

 mergeHeader.MouseButton1Click:Connect(function()
 mergeOpen = not mergeOpen; mergeBody.Visible = mergeOpen
 mergeIcon.Text = mergeOpen and "v" or ">"
 if mergeOpen then task.defer(ResizeMergeBody) end
 end)
 task.defer(ResizeMergeBody)

 -- ============================================================
 -- PANEL: AUTO USE POTION
 -- ============================================================
 local useOpen = false
 local useHeader = Btn(p, C.SURFACE, UDim2.new(1,0,0,38))
 useHeader.LayoutOrder = 12; Corner(useHeader, 10); Stroke(useHeader,C.BORD, 1.5,0.88)
 local useIcon = Label(useHeader,">",12,C.ACC2,Enum.Font.GothamBold)
 useIcon.Size = UDim2.new(0,20,1,0); useIcon.Position = UDim2.new(0,10,0,0)
 local useTitleLbl = Label(useHeader,"AUTO USE POTION",13,C.TXT,Enum.Font.GothamBold)
 useTitleLbl.Size = UDim2.new(1,-40,1,0); useTitleLbl.Position = UDim2.new(0,30,0,0)

 local useBody = Frame(p, C.BG2, UDim2.new(1,0,0,0))
 useBody.LayoutOrder = 13; useBody.ClipsDescendants = false
 Corner(useBody, 10); Stroke(useBody,C.BORD, 1.5,0.25); useBody.Visible = false

 local useInner = Frame(useBody, C.BLACK, UDim2.new(1,-16,0,0))
 useInner.BackgroundTransparency = 1; useInner.Position = UDim2.new(0,8,0,8)
 useInner.AutomaticSize = Enum.AutomaticSize.Y
 local useLayout = New("UIListLayout",{Parent=useInner,SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0, 10)})
 Instance.new("UIPadding",useInner).PaddingBottom = UDim.new(0,10)

 local function ResizeUseBody()
 useLayout:ApplyLayout()
 local h = useLayout.AbsoluteContentSize.Y + 28
 useInner.Size = UDim2.new(1,0,0,h)
 useBody.Size = UDim2.new(1,0,0,h+16)
 end

 -- State use
 local _useSelectedId = nil -- nil = belum dipilih user
 local _useCount = 1
 local _useRunning = false
 local _useThread = nil
 local _useStatusLbl = nil

 -- Status bar
 local uStatusCard = Frame(useInner, C.BG3, UDim2.new(1,0,0,26))
 uStatusCard.LayoutOrder = 0; Corner(uStatusCard,6); Stroke(uStatusCard,C.ACC, 1.5,0.4)
 _useStatusLbl = Label(uStatusCard,"Idle - SELECT ITEM & ENABALE",9,C.TXT2,Enum.Font.GothamBold)
 _useStatusLbl.Size = UDim2.new(1,-10,1,0); _useStatusLbl.Position = UDim2.new(0,8,0,0)
 _useStatusLbl.TextTruncate = Enum.TextTruncate.AtEnd

 -- Row: SELECT ITEM dropdown
 local uSelectRow = Frame(useInner, C.SURFACE, UDim2.new(1,0,0,0))
 uSelectRow.LayoutOrder = 1; Corner(uSelectRow, 10); Stroke(uSelectRow,C.BORD, 1.5,0.88)
 uSelectRow.AutomaticSize = Enum.AutomaticSize.Y
 local uSelectPad = Instance.new("UIPadding",uSelectRow)
 uSelectPad.PaddingLeft=UDim.new(0,10); uSelectPad.PaddingRight=UDim.new(0,10)
 uSelectPad.PaddingTop=UDim.new(0, 10); uSelectPad.PaddingBottom=UDim.new(0, 10)
 New("UIListLayout",{Parent=uSelectRow,SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,6)})

 local uSelLabel = Label(uSelectRow,"SELECT ITEM",10,C.TXT3,Enum.Font.GothamBold)
 uSelLabel.Size = UDim2.new(1,0,0,14); uSelLabel.LayoutOrder = 0

 local uDDOpts = {}
 for _, pt in ipairs(USE_POTIONS) do
 table.insert(uDDOpts, {label=pt.name, value=pt.id})
 end

 local uDDWrap, uGetSel = MakeDropdown(uSelectRow, uDDOpts, function(val, idx)
 _useSelectedId = val
 if _useStatusLbl then _useStatusLbl.Text = "Item SELECTED: " .. uDDOpts[idx].label end
 end)
 uDDWrap.LayoutOrder = 1

 -- Row: COUNT slider 1-100
 local uCountRow = Frame(useInner, C.SURFACE, UDim2.new(1,0,0,0))
 uCountRow.LayoutOrder = 2; Corner(uCountRow, 10); Stroke(uCountRow,C.BORD, 1.5,0.88)
 uCountRow.AutomaticSize = Enum.AutomaticSize.Y
 local uCntPad = Instance.new("UIPadding",uCountRow)
 uCntPad.PaddingLeft=UDim.new(0,10); uCntPad.PaddingRight=UDim.new(0,10)
 uCntPad.PaddingTop=UDim.new(0, 10); uCntPad.PaddingBottom=UDim.new(0, 10)
 New("UIListLayout",{Parent=uCountRow,SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,4)})

 local uCntLabel = Label(uCountRow,"USE COUNT (1 - 100)",10,C.TXT3,Enum.Font.GothamBold)
 uCntLabel.Size = UDim2.new(1,0,0,14); uCntLabel.LayoutOrder = 0

 local uSliderWrap, uGetCount = MakeSlider(uCountRow, 1, 100, 1, function(v)
 _useCount = v
 end)
 uSliderWrap.LayoutOrder = 1; uSliderWrap.Size = UDim2.new(1,0,0,32)

 -- Toggle ON/OFF
 local _, _useToggleSet, _useVis = ToggleRow(useInner,"Use Potion","ON = start use potion",3,function(on)
 if on then
 if not _useSelectedId then
 if _useStatusLbl then _useStatusLbl.Text = "[!] SELECT ITEM PLEASE!" end
 if _useToggleSet then task.defer(function() _useToggleSet(false) end) end
 return
 end
 _useRunning = true
 _useRunningState = true
 if _useThread then pcall(function() task.cancel(_useThread) end) end
 _useThread = task.spawn(function()
 while _useRunning do
 local id = _useSelectedId
 local cnt = _useCount
 if _useStatusLbl then _useStatusLbl.Text = "[U] Using id=" .. id .. " x" .. cnt end
 pcall(function()
 local re = Remotes:FindFirstChild("UseItem")
 if re then re:InvokeServer({useCount=cnt, itemId=id}) end
 end)
 if _useStatusLbl then _useStatusLbl.Text = "[OK] Use DONE x" .. cnt end
 task.wait(0.5)
 end
 if _useStatusLbl then _useStatusLbl.Text = "Idle - toggle OFF" end
 end)
 else
 _useRunning = false
 _useRunningState = false
 if _useThread then pcall(function() task.cancel(_useThread) end); _useThread = nil end
 if _useStatusLbl then _useStatusLbl.Text = "Idle - SELECT ITEM & ENABLE" end
 end
 end)
 _setUseToggle = _useToggleSet
 _visUse = _useVis

 useHeader.MouseButton1Click:Connect(function()
 useOpen = not useOpen; useBody.Visible = useOpen
 useIcon.Text = useOpen and "v" or ">"
 if useOpen then task.defer(ResizeUseBody) end
 end)
 task.defer(ResizeUseBody)

end


-- ============================================================
do -- [FIX] AutoRaid+Webhook: isolated scope
-- AUTO RAID : LOGIC (Data dari RaidSniffer v2)
-- Format confirmed:
-- UpdateRaidInfo -> arg[1] = {
-- action = "RemoveRaidEnters" | "AddRaidEnters"
-- raidInfos = {
-- [raidId(number)] = {
-- spawnName = "RE1001"/"RE1002"
-- endTime = number
-- mapId = number (50011, 50007, dst)
-- raidId = number
-- }
-- }
-- }
-- ============================================================

-- RAID_LIVE: [raidId] = {raidId, mapId, spawnName, rank, label}
RAID_LIVE = {}
RAID_ID_LIST = {} -- sorted list untuk UI
_raidIdRefreshCb = nil
_defaultRRIdx = 0 -- [v265] Round-robin index untuk Pick Mode Default

-- [FIX v256] SPAWN_RANK: HANYA identifikasi SLOT SPAWN (lokasi portal di map)
-- CONFIRMED via sniffing: RE1001/RE1002 BUKAN indikator grade!
-- RE1001 bisa grade B, G, M++. RE1002 bisa grade D, S. Tidak ada korelasi.
-- Tetap disimpan karena dipakai ConnectRaidListeners untuk data slot.
SPAWN_RANK = {
 RE1001 = 1, RE1002 = 2, RE1003 = 3, RE1004 = 4, RE1005 = 5, RE1006 = 6,
}
-- RANK_LABEL: mapping grade number -> nama grade (dipakai chat parser + UI display)
-- TIDAK ADA hubungan dengan SPAWN_RANK. Grade HANYA dari chat announce.
RANK_LABEL = {
 [1]="E", [2]="D", [3]="C", [4]="B", [5]="A",
 [6]="S", [7]="SS", [8]="G", [9]="N", [10]="M",
 [11]="M+", [12]="M++", [15]="XM", [17]="ULT",
}
-- Nama map in-game (mapNum = mapId - 50000)
MAP_NAMES = {
 [1] = "Shadow Gate City",
 [2] = "Level Grinding Cavern",
 [3] = "Shadow Castle",
 [4] = "Seolhan Forest",
 [5] = "Demon Castle - Tier 1",
 [6] = "Orc Palace",
 [7] = "Demon Castle - Tier 2",
 [8] = "Ant Island",
 [9] = "Land of Giant",
 [10] = "Plagueheart",
 [11] = "Umbralfrost Domain",
 [12] = "Kamish's Demise",
 [13] = "Lava Hell",
 [14] = "Illusory World",
 [15] = "Inferno Altar",
 [16] = "Shadow Throne",
 [17] = "Angel Holy Realm",
 [18] = "Golden Throne",
 [19] = "Dragon Ball City",
 [20] = "Dragon Ball Wasteland",

}

-- Koordinat spawn boss per map Raid (tpMapId = raidMapId + 100)
-- Karakter + hero langsung TP ke sini setelah masuk map
RAID_SPAWN_POS = {
 [50101] = Vector3.new(2424.9, 8.5, 482.9), -- Map 1 Shadow Gate City
 [50102] = Vector3.new(1683.1, 8.6, -24.1), -- Map 2 Level Grinding Cavern
 [50103] = Vector3.new(1913.1, 12, -194.4), -- Map 3 Shadow Castle
 [50104] = Vector3.new( 515.8, 7.6, -98.0), -- Map 4 Seolhan Forest
 [50105] = Vector3.new(-229.3, 9.6, -2.3), -- Map 5 Demon Castle Tier 1
 [50106] = Vector3.new(1998.2, 8.0, 237.7), -- Map 6 Orc Palace
 [50107] = Vector3.new( -42.0, 8.4, 334.0), -- Map 7 Demon Castle Tier 2
 [50108] = Vector3.new(-925.8,-396.2, -901.6), -- Map 8 Ant Island
 [50109] = Vector3.new( 8.7, 13.0, 244.2), -- Map 9 Land of Giant
 [50110] = Vector3.new(2003.0, 8.1, 344.0), -- Map 10 Plagueheart
 [50111] = Vector3.new(2068.0, 49.4, -155.8), -- Map 11 Umbralfrost Domain
 [50112] = Vector3.new( 16.5, 9.0, 269.5), -- Map 12 Kamish's Demise
 [50113] = Vector3.new(2100.7, 63.1, 423.1), -- Map 13 Lava Hell
 [50114] = Vector3.new( 27.8, 49.8, 303.9), -- Map 14 Illusory World
 [50115] = Vector3.new( -0.9, 24.0, 185.3), -- Map 15 Inferno Altar
 [50116] = Vector3.new(1999.6, 17.0, 236.5), -- Map 16 Shadow Throne
 [50117] = Vector3.new( -0.4, 18.5, 93.5), -- Map 17 Angel Holy Realm
 [50118] = Vector3.new(2000.0, 45.4, 234.7), -- Map 18 Golden Throne
 [50119] = Vector3.new(0, 10.0, 0), -- Map 19 Dragon Ball City (update posisi jika perlu)
 [50120] = Vector3.new(0, 10.0, 0), -- Map 20 Dragon Ball Wasteland (update posisi jika perlu)
}
end -- chat listener + grade cache

-- ============================================================
-- GRADE CACHE & PARSER
-- Sumber grade: TipsFloatingPanel (primer) + chat history (backup)
-- Structure: TipsFloatingPanel > PopupFrame > PopupBg > ContentBg > TextLabel
-- ============================================================

GRADE_LIST = {"E","D","C","B","A","S","SS","G","N","M","M+","M++","XM","ULT"}
_runeGradeCache = {} -- {[mapNum]=grade} - diisi dari popup/chat
_pendingTowerNum  = nil -- [script lama FIX] nomor AT dari baris 1 chat, nunggu baris 2
_pendingTowerTime = 0   -- tick() saat baris 1 diterima, expire 10 detik
-- [FIX v267] GRADE_RANK: nilai numerik grade untuk perbandingan di ParseChatLine
-- shouldUpdate hanya update kalau grade baru LEBIH TINGGI dari yang di cache
GRADE_RANK = {
 ["E"]=1,["D"]=2,["C"]=3,["B"]=4,["A"]=5,["S"]=6,["SS"]=7,
 ["G"]=8,["N"]=9,["M"]=10,["M+"]=11,["M++"]=12,["XM"]=15,["ULT"]=17,["GOD"]=18,
}

-- RAID_CONFIG_GRADE: Formula grade dari raidId
-- RAID_NORMAL (930001-934999): (raidId - 930001) % 10 -> index ke grade
-- ASC_TOWER  (935001+)       : raidId % 100 -> index ke grade (CONFIRMED sniffer)
--
-- GRADE INDEX MAP (shared):
--  1=E  2=D  3=C  4=B  5=A  6=S  7=SS  8=G  9=N  10=M  11=M+  12=M++  13=XM  14=ULT  15=GOD
local _GRADE_IDX = {"E","D","C","B","A","S","SS","G","N","M","M+","M++","XM","ULT","GOD"}
-- RAID_NORMAL khusus pakai subset 10 grade (D,B,S,SS,G,N,M+,M++,XM,ULT)
local _GRADE_RAID = {"D","B","S","SS","G","N","M+","M++","XM","ULT"}

RAID_CONFIG_GRADE = setmetatable({}, {
 __index = function(_, raidId)
  if type(raidId) ~= "number" then return nil end
  -- ASC Tower: raidId >= 935001, formula = raidId % 100 (CONFIRMED via sniffer)
  if raidId >= 935001 then
   local idx = raidId % 100
   return _GRADE_IDX[idx] or "?"
  end
  -- RAID Normal: raidId >= 930001, formula = (raidId - 930001) % 10
  if raidId >= 930001 then
   local slot = (raidId - 930001) % 10
   return _GRADE_RAID[slot + 1] or "?"
  end
  return nil
 end
})


--  ParseChatLine: parse teks raid/siege, update cache 
function ParseChatLine(text)
 if type(text) ~= "string" or #text < 3 then return end
 text = text:gsub("<[^>]+>",""):gsub("[\r\n]+"," "):match("^%s*(.-)%s*$") or text

 -- ============================================================
 -- CONFIRMED dari sniffer: TipsPanel kirim 1 baris lengkap untuk keduanya:
 -- Normal : "The MaFissure appeared in 6,Orc Palace [B]"
 -- AT     : "The MaFissure appeared in Ascension Tower 4 - [Monarch] Grendal+1 [E]"
 -- Grade SELALU ada di bracket TERAKHIR dalam teks.
 -- ============================================================
 if text:find("MaFissure",1,true) and text:find("appeared",1,true) then

  -- Helper: ambil grade dari bracket TERAKHIR dalam teks
  -- Ini kunci fix: skip [Monarch], [King], dll -- ambil yang paling akhir
  local function extractGradeLast(t)
   local grade = nil
   -- Cek multi-char grade dulu (M++, M+, SS, XM, ULT, GOD)
   for _, pat in ipairs({"M%+%+","M%+","SS","XM","ULT","GOD","M"}) do
    if t:find("%["..pat.."]", 1, false) then
     -- Ambil posisi TERAKHIR
     local last = nil
     for m in t:gmatch("%["..pat.."]") do last = m end
     if last then
      grade = last:match("%[(.+)%]")
      break
     end
    end
   end
   if grade then return grade:upper() end
   -- Single char: ambil bracket TERAKHIR yang valid, skip [Monarch] dll
   local last = nil
   for bracket in t:gmatch("%[([^%]]+)%]") do
    local up = bracket:upper()
    if up:match("^[EDCBAGSN]$") then
     last = up
    end
   end
   return last
  end

  -- ASCENSION TOWER: "appeared in Ascension Tower 4 - [Monarch] Grendal+1 [E]"
  if text:find("Ascension Tower", 1, true) then
   local towerNum = tonumber(text:match("Ascension Tower (%d+)"))
   local grade    = extractGradeLast(text)
   if towerNum and grade then
    -- Cache key negatif agar tidak bentrok dengan normal raid (map 1-20)
    _runeGradeCache[-towerNum] = grade
    if not _ASC_CHAT_CACHE then _ASC_CHAT_CACHE = {} end
    _ASC_CHAT_CACHE[towerNum] = { grade = grade, time = os.time() }
    -- [FIX TIMING] update RAID_LIVE entry AT yang sudah ada tapi grade masih "?"
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
    -- [WEBHOOK PURE] Kirim teks mentah langsung ke buffer webhook
    if _WH and _WH.AddLine then
     _WH.AddLine("The MaFissure appeared in Ascension Tower "..towerNum.." ["..grade.."]")
    end
    TriggerEntryWakeup()
   end
   return
  end

  -- RAID NORMAL: "appeared in 6,Orc Palace [B]"
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
    -- [WEBHOOK PURE] Kirim teks mentah langsung dari TipsPanel ke buffer webhook
    -- Format persis seperti yang muncul di game
    if _WH and _WH.AddLine then
     local _mapName = MAP_NAMES and MAP_NAMES[mapNum] or ("Map "..mapNum)
     _WH.AddLine("The MaFissure appeared in "..mapNum..",".._mapName.." ["..grade.."]")
    end
    TriggerEntryWakeup()
   end
  end
  return
 end

--  Deduplicate seen messages (v273 FIX: Short-term memory 3 minutes)
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

    -- [v273 FIX] Unique key: gunakan seluruh teks (max 200) agar membedakan map/grade
    local key = txt:sub(1,200)
    local now = tick()

    -- [v273 FIX] Short-term memory: 3 menit (180 detik)
    if _chatSeen[key] and (now - _chatSeen[key]) < 180 then 
        return 
    end
    
    _chatSeen[key] = now
    ParseChatLine(txt)
    
    -- Cleanup cache lama setiap 10 pesan baru (agar memori tidak bocor)
    local count = 0
    for _ in pairs(_chatSeen) do count = count + 1 end
    if count > 50 then
        for k, t in pairs(_chatSeen) do
            if (now - t) > 180 then _chatSeen[k] = nil end
        end
    end
end

--  PRIMER: TipsFloatingPanel detector (GHOST POLLING - 100% ANTI CRASH)
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
end

--  BACKUP: Chat history setelah 5 detik 
-- TextChatService: reliable di semua executor
task.spawn(function()
 pcall(function()
 local TCS = game:GetService("TextChatService")
 -- Tunggu TextChannels ready max 10 detik
 local _w = 0
 repeat task.wait(0.5); _w = _w + 0.5
 until TCS:FindFirstChild("TextChannels") or _w >= 10

 local channels = TCS:FindFirstChild("TextChannels")
 if not channels then return end

 local function watchChannel(ch)
 if not ch:IsA("TextChannel") then return end
 ch.ChildAdded:Connect(function(obj)
 if obj:IsA("TextChatMessage") then
 -- Delay 5 detik: backup setelah popup selesai
 task.delay(5, function()
 pcall(function()
 -- TextChatMessage.Text bisa kosong, coba semua field
 local txt = obj.Text or ""
 if #txt < 5 then txt = (obj.PrefixText or "").." "..(obj.Text or "") end
 if #txt < 5 then
 -- Coba dari TextSource
 local ts = obj:FindFirstChildOfClass("TextSource")
 if ts then txt = ts.Text or "" end
 end
 _processMsg(txt)
 end)
 end)
 end
 end)
 end

 for _, ch in ipairs(channels:GetChildren()) do watchChannel(ch) end
 channels.ChildAdded:Connect(function(ch) task.wait(0.1); watchChannel(ch) end)

 -- Scan history awal saat startup (silent, jangan trigger webhook)
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
 _whResetSentCache() -- [BUG FIX 4] Scan awal selesai, reset cache agar notif server pertama kali bisa kirim
 end)
end)

--  FALLBACK 3: ExperienceChat BodyText watcher 
-- Ini yang paling reliable karena BodyText selalu berisi teks penuh
-- Terbukti dari diagnostic: chat "The MaFissure appeared in X" ada di ExperienceChat
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

 -- Scan yang sudah ada
 for _, obj in ipairs(ec:GetDescendants()) do
 checkBodyText(obj)
 end
 -- Watch yang baru muncul
 ec.ChildAdded:Connect(function(obj)
 task.wait(4) -- tunggu teks penuh (sudah pindah ke history)
 checkBodyText(obj)
 end)
 end)
end)


-- Forward declare raid+webhook functions
SendWebhookNotif=nil; RebuildRaidList=nil; ParseRaidEntry=nil
DisconnectRaidConns=nil; ConnectRaidListeners=nil; RaidFireDamage=nil

local _whFlushBuffer = nil -- forward declare agar FlushWebhookPending bisa akses
do -- [FIX] webhook + raid logic wrapped to free top-level locals

-- ============================================================
-- WEBHOOK SYSTEM - Bersih, akurat, executor-agnostic
-- Kirim notif ke Discord/Telegram saat Raid atau Siege OPEN
-- ============================================================
_WH = {}

-- Helper: dapatkan request function (support semua executor)
local function _getReqFunc()
 -- Support semua executor: Delta, Fluxus, Xeno, Solara, Synapse, KRNL, dll
 local _r = request or http_request or httprequest
  or (syn and syn.request)
  or (http and http.request)
  or (fluxus and fluxus.request)
  or (krnl and krnl.request)
  or (electron and electron.request)
  or (Drawing and Drawing.request) -- beberapa build custom
 -- getgenv fallback: executor expose request di env berbeda
 if not _r then
  pcall(function()
   local _env = getgenv and getgenv() or nil
   if _env then
    _r = _env.request or _env.http_request or _env.httprequest
   end
  end)
 end
 return _r or nil
end

-- Helper: kirim HTTP POST ke Discord atau Telegram
-- return: true (sukses), false (gagal), string (error message)
local function _doSend(url, text)
 local reqFunc = _getReqFunc()
 if not reqFunc then
  pcall(function() warn("[ASH Webhook] ERROR: Executor tidak support HTTP request!") end)
  return false, "Executor tidak support HTTP"
 end
 local HS = game:GetService("HttpService")
 local isDiscord = url:find("discord%.com/api/webhooks")
 local isTelegram = url:find("api%.telegram%.org")
 local ok, res, errMsg = false, nil, nil
 local callOk, callErr = pcall(function()
  if isDiscord then
   res = reqFunc({
    Url = url,
    Method = "POST",
    Headers = { ["Content-Type"] = "application/json" },
    Body = HS:JSONEncode({ content = text }),
   })
  elseif isTelegram then
   local enc = tostring(text):gsub("([^%w%-_%.%~])", function(c)
    return string.format("%%%02X", string.byte(c))
   end)
   res = reqFunc({ Url = url .. "&text=" .. enc, Method = "GET" })
  end
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

-- Kirim notif Raid ke webhook
-- ============================================================
-- WEBHOOK SYSTEM v2 - Pure TipsPanel
-- Buffer teks langsung dari TipsPanel, kirim ke Discord/Telegram
-- Tidak ada ketergantungan RAID_LIVE / ASC_LIVE apapun
-- ============================================================

-- Buffer: teks mentah dari TipsPanel, diisi ParseChatLine
-- { text = "The MaFissure appeared in ...", isAT = bool, time = tick() }
local _whBuffer        = {}   -- list of raw lines dari event ini

-- [v_FIX] Helper: resolve grade terbaik dari raidId (formula baru) atau fallback entry
local function _WH_resolveGrade(ent)
 if not ent then return "?" end
 -- 1. Formula langsung dari raidId (paling akurat, sudah fix ASC)
 if ent.raidId and RAID_CONFIG_GRADE then
  local g = RAID_CONFIG_GRADE[ent.raidId]
  if g and g ~= "?" then return g end
 end
 -- 2. TipsPanel cache
 if ent.isAscension then
  local mn = ent.mapId and (ent.mapId - 50300)
  if mn and _ASC_CHAT_CACHE and _ASC_CHAT_CACHE[mn] and _ASC_CHAT_CACHE[mn].grade then
   return _ASC_CHAT_CACHE[mn].grade
  end
  if mn and _runeGradeCache and _runeGradeCache[-mn] then
   return _runeGradeCache[-mn]
  end
 else
  local mn = ent.mapId and (ent.mapId - 50000)
  if mn and _runeGradeCache and _runeGradeCache[mn] then
   return _runeGradeCache[mn]
  end
 end
 -- 3. Entry grade field
 return ent.grade or "?"
end
local _whBufferTimer   = nil  -- debounce handle
local _whLastSent      = 0
-- [BUG FIX 4] Cache teks webhook yang sudah pernah dikirim di event server ini.
-- Reset hanya saat RAID_LIVE kosong total (event habis / server baru).
-- Ini cegah spam: ParseChatLine + RebuildRaidList + _onRaidChildAdded semua bisa
-- panggil AddLine untuk teks yang SAMA berkali-kali.
local _whSentCache     = {}
local function _whResetSentCache()
 _whSentCache = {}
end

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

-- Kirim buffer ke Discord/Telegram, lalu kosongkan buffer
-- AT dan RAID Normal diperlakukan IDENTIK â€” satu sumber grade: GetBestGrade
-- AT: isAscension=true, mapNum = towerNum. RAID: isAscension=false, mapNum = mapId-50000
_whFlushBuffer = function(url)
 if #_whBuffer == 0 then return end
 local lines   = _whBuffer
 _whBuffer     = {}
 _whLastSent   = tick()

 local reqFunc = _getReqFunc()
 if not reqFunc then return end
 local isDiscord  = url:find("discord%.com/api/webhooks")
 local isTelegram = url:find("api%.telegram%.org")
 local HS = game:GetService("HttpService")

 -- Satu helper grade untuk keduanya â€” identik cara RAID Normal baca grade
 -- AT   : GetBestGrade(towerNum, true)
 -- RAID : GetBestGrade(mapNum, false)
 local function _gradeFor(mapNum, isAscension)
  local g = GetBestGrade(mapNum, isAscension)
  if g and g ~= "?" then return g end
  -- last resort: baca langsung dari _runeGradeCache
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

 if isDiscord then
  local fields = {}

  if #entries_normal > 0 then
   local valLines = {}
   for _, e in ipairs(entries_normal) do
    local gradeStr = e.grade ~= "?" and ("**["..e.grade.."]**") or "[?]"
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
   footer      = {text = "ASH GUI FLa Project"},
  }}}
  pcall(function()
   reqFunc({
    Url     = url,
    Method  = "POST",
    Headers = {["Content-Type"] = "application/json"},
    Body    = HS:JSONEncode(payload),
   })
  end)

 elseif isTelegram then
  local out = {"[RAID OPEN] Rank "..topGrade}
  for _, e in ipairs(entries_normal) do
   local mapStr = e.mapNum and ("Map "..e.mapNum.." - "..e.mapName) or e.raw
   table.insert(out, "["..e.grade.."] "..mapStr)
  end
  for _, e in ipairs(entries_at) do
   local tStr = e.mapNum and ("Ascension Tower "..e.mapNum) or e.raw
   table.insert(out, "["..e.grade.."] "..tStr)
  end
  _doSend(url, table.concat(out, "\n"))
 end
end

-- Dipanggil dari ParseChatLine setiap kali TipsPanel tangkap 1 baris raid/AT
-- text = teks mentah sudah bersih (strip markup)
_WH.AddLine = function(text)
 if not _webhookEnabled or not _webhookUrl or _webhookUrl == "" then return end
 if _whSilent then return end
 -- [BUG FIX 4] Cek cache global per-event: jika teks ini sudah pernah dikirim di event ini, skip
 if _whSentCache[text] then return end
 -- Cek apakah sudah ada baris identik dalam buffer (anti duplikat)
 for _, existing in ipairs(_whBuffer) do
  if existing == text then return end
 end
 _whSentCache[text] = true  -- [BUG FIX 4] Tandai teks ini sudah masuk (tidak akan kirim lagi)
 table.insert(_whBuffer, text)
 -- Reset debounce: tunggu 3 detik setelah baris terakhir baru kirim
 if _whBufferTimer then pcall(function() task.cancel(_whBufferTimer) end) end
 _whBufferTimer = task.delay(3, function()
  _whBufferTimer = nil
  -- Cooldown 10 detik antar pengiriman
  if (tick() - _whLastSent) < 10 then
   -- Jadwalkan ulang setelah sisa cooldown
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

-- Alias lama agar kode lain yang memanggil SendWebhookRaid tidak error
_WH.SendRaid  = function(url) _whFlushBuffer(url) end
SendWebhookRaid  = function(url) _whFlushBuffer(url) end
_WH.SendSiege = function(url)
 -- Siege tetap pakai SIEGE.live (tidak ada TipsPanel untuk Siege)
 local SIEGE_NAMES = {
  [3]="Shadow Castle",[7]="Demon Castle Tier 2",
  [10]="Plagueheart",[13]="Lava Hell",[18]="Golden Throne",
 }
 local lines = {"**SIEGE OPEN**"}
 local found = false
 if SIEGE and SIEGE.live then
  for _, mn in pairs(SIEGE.live) do
   table.insert(lines, "- Map "..mn.." - "..(SIEGE_NAMES[mn] or "Map "..mn))
   found = true
  end
 end
 if not found then return end
 _doSend(url, table.concat(lines, "\n"))
end
SendWebhookSiege = function(url) _WH.SendSiege(url) end -- alias internal

-- [v_FIX] Deklarasi duplikat _whLastSent dihapus - sudah ada di atas (baris 7565)
-- [WEBHOOK PURE] TriggerWebhookDebounce tidak dipakai lagi
-- Webhook sekarang dikirim langsung dari ParseChatLine via _WH.AddLine
TriggerWebhookDebounce = function() end -- no-op, compat
SendWebhookNotif = TriggerWebhookDebounce -- alias untuk kompatibilitas

-- ============================================================
-- [v58] ENTRY WAKEUP DEBOUNCE - Gerbang masuk terpusat
-- ============================================================
-- Semua sumber notif (chat parser, workspace watcher, UpdateRaidInfo server)
-- wajib memanggil TriggerEntryWakeup() dan TIDAK boleh langsung fire wakeup.
--
-- Cara kerja:
--   1. Notif masuk -> data langsung masuk RAID_LIVE (seperti biasa)
--   2. TriggerEntryWakeup() dipanggil -> timer di-reset ke 3 detik
--   3. Selama 3 detik: notif-notif berikutnya terus update data, timer terus di-reset
--   4. Setelah 3 detik tidak ada notif baru -> BARU fire wakeup ke RAID dan ASC
--   5. RAID dan ASC masing-masing cek filter mereka sendiri dan masuk jika cocok
--   6. Karena keduanya dibangunkan dari titik yang SAMA setelah data stabil,
--      tidak ada race condition - siapa yang resolve entry lebih dulu itulah yang masuk
--
-- Keuntungan vs v57:
--   - Tidak perlu _ascPending flag
--   - Tidak ada pembedaan "ini notif ASC, jangan bangunkan RAID" yang rapuh
--   - Lebih toleran terhadap notif terlambat / out-of-order dari server
--   - Tetap ada TryClaimMapLock sebagai safety net terakhir

local _entryWakeupTimer = nil  -- handle task.delay aktif
local _ENTRY_DEBOUNCE_SEC = 3  -- detik tunggu setelah notif terakhir

TriggerEntryWakeup = function()
    -- Reset timer: kalau sudah ada timer berjalan, batalkan dan mulai lagi
    if _entryWakeupTimer then
        pcall(function() task.cancel(_entryWakeupTimer) end)
        _entryWakeupTimer = nil
    end
    _entryWakeupTimer = task.delay(_ENTRY_DEBOUNCE_SEC, function()
        _entryWakeupTimer = nil
        -- [v61 CYCLEFIX] Reset flag siklus lama
        _ascMatchedThisCycle = false
        _raidFallbackActive  = false

        -- ============================================================
        -- [v62 RINO/RINI FIX] "Si Pemanggil" memutuskan siapa yang dipanggil
        -- SEBELUM wakeup dikirim ke siapapun:
        --   Cek RAID_LIVE apakah ada Ascension Tower entry.
        --   Jika ada + ASC toggle ON  -> _eventOwner = "asc"  -> hanya ASC yang dibangunkan
        --   Jika tidak / ASC OFF      -> _eventOwner = "raid" -> hanya RAID yang dibangunkan
        -- Dengan ini tidak ada race: yang tidak dipanggil tidak pernah bangun sama sekali.
        -- ============================================================
        local _hasAscEntry = false
        if ASC and ASC.running then
            for rid, ent in pairs(RAID_LIVE) do
                -- rid adalah raidId integer (key tabel RAID_LIVE)
                local ridAbs = rid < 0 and math.abs(rid) or rid
                local isAscById  = ridAbs >= 935001
                local isAscByMap = ent.mapId and ent.mapId >= 50301 and ent.mapId <= 50326
                local isAscByFlag = ent.isAscension == true
                if isAscByFlag or isAscById or isAscByMap then
                    _hasAscEntry = true; break
                end
            end
        end

        if _hasAscEntry then
            -- ASC dipanggil. RAID tetap duduk.
            _eventOwner = "asc"
            _raidFallbackActive = false
            if _ascWakeup then pcall(function() _ascWakeup:Fire() end) end
        else
            -- RAID dipanggil. ASC tetap duduk.
            _eventOwner = "raid"
            _raidFallbackActive = true
            if _raidWakeup then pcall(function() _raidWakeup:Fire() end) end
        end
    end)
end
-- ============================================================
FlushWebhookPending = function()
 -- Reset cooldown dan flush buffer yang ada
 _whLastSent = 0
 if _WH and _whFlushBuffer and _webhookUrl and _webhookUrl ~= "" then
  _whFlushBuffer(_webhookUrl)
 end
end

_WH.SendCustomMessage = function(url, msg, onDone, onFail)
 if not url or url == "" then
 if onFail then onFail("URL kosong") end; return
 end
 if not url:find("discord%.com/api/webhooks") and not url:find("api%.telegram%.org") then
 if onFail then onFail("URL tidak dikenali (bukan Discord/Telegram)") end; return
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

_WH.VerifyWebhookUrl = function(url, onValid, onInvalid)
 if not url or url == "" then
 if onInvalid then onInvalid("URL kosong") end; return
 end
 local isDiscord = url:find("discord%.com/api/webhooks/")
 local isTelegram = url:find("api%.telegram%.org/bot[^/]+/sendMessage")
 if isDiscord then
 local id, token = url:match("webhooks/(%d+)/([%w_%-]+)")
 if id and token and #token > 10 then
 if onValid then onValid() end
 else
 if onInvalid then onInvalid("Format Discord webhook salah") end
 end
 elseif isTelegram then
 if url:find("chat_id=") then
 if onValid then onValid() end
 else
 if onInvalid then onInvalid("Telegram URL butuh chat_id=...") end
 end
 else
 if onInvalid then onInvalid("Bukan URL Discord/Telegram valid") end
 end
end

-- Koneksi raid listeners
_WH.raidConns = {}

RebuildRaidList = function()
 local sorted = {}
 for _, e in pairs(RAID_LIVE) do
  local mn = e.mapId and (e.mapId - 50000) or 0
  -- Auto-mark isAscension jika raidId >= 935001 (dari server, meskipun chat belum datang)
  local ridAbs = e.raidId and (e.raidId < 0 and math.abs(e.raidId) or e.raidId) or 0
  if ridAbs >= 935001 and not e.isAscension then
   e.isAscension = true
  end
  if e.isAscension then
   -- Ascension entry: selalu masuk tanpa filter mapNum
   table.insert(sorted, e)
  elseif e.mapId and mn >= 1 and mn <= 20 then
   -- Normal entry: filter mapNum 1-20
   table.insert(sorted, e)
  end
 end
 -- Sort: normal entries by mapId ascending, Ascension entries setelahnya
 -- [FIX] Normalisasi isAscension ke boolean agar sort tidak invalid (nil ~= false = true)
 table.sort(sorted, function(a, b)
  local aAsc = a.isAscension and true or false
  local bAsc = b.isAscension and true or false
  if aAsc ~= bAsc then
   return not aAsc -- normal dulu
  end
  return (a.mapId or 0) < (b.mapId or 0)
 end)
 RAID_ID_LIST = {}
 for _, e in ipairs(sorted) do
 local mn = e.mapId and (e.mapId - 50000) or 0
 local lbl
 if e.isAscension then
  -- [FIX] Tampilkan nama boss di label jika tersedia
  local _bn = e.bossName and (e.bossName:gsub("^%l",string.upper)) or nil
  lbl = "Ascension Tower "..mn..(_bn and (" - ".._bn) or "").." ["..(e.grade or "?").."]"
 else
  lbl = "Map "..mn.." - "..(MAP_NAMES[mn] or ("Map "..mn)).." - "..(RANK_LABEL[e.rank] or ("["..( e.spawnName or "?").."]")).." (ID:"..e.raidId..")"
 end
 table.insert(RAID_ID_LIST, {
 label = lbl,
 id = e.raidId,
 rank = e.rank,
 mapId = e.mapId,
 spawnName = e.spawnName,
 isAscension = e.isAscension,
 bossName = e.bossName, -- [FIX] nama boss Ascension Tower untuk prioritas scan
 })
 end
 if _raidIdRefreshCb then pcall(_raidIdRefreshCb) end
 -- [v_FIX] Kirim notif webhook untuk setiap raid/asc baru
 if _webhookEnabled and _webhookUrl ~= "" and not _whSilent then
  task.delay(0.5, function()
   for _, ent in pairs(RAID_LIVE) do
    if ent.label and ent.label ~= "" and _WH and _WH.AddLine then
     -- [v_FIX] Gunakan _WH_resolveGrade: formula baru ASC (raidId%100) + fallback TipsPanel
     local _grade = _WH_resolveGrade and _WH_resolveGrade(ent) or ent.grade or "?"
     if ent.isAscension then
      local mn = ent.mapId and (ent.mapId - 50300) or "?"
      local bn = ent.bossName and (" - "..ent.bossName) or ""
      _WH.AddLine("The MaFissure appeared in Ascension Tower "..tostring(mn)..bn.." [".._grade.."]")
     else
      local mn = ent.mapId and (ent.mapId - 50000) or "?"
      local nm = MAP_NAMES and MAP_NAMES[mn] or ("Map "..tostring(mn))
      _WH.AddLine("The MaFissure appeared in "..tostring(mn)..","..nm.." [".._grade.."]")
     end
    end
   end
  end)
 end
end

-- Parse satu entry raidInfos
-- [v202] Simpan grade dari _runeGradeCache (diisi chat parser)
-- raidType: "normal" (50101-50118)
ParseRaidEntry = function(k, info)
 if type(info) ~= "table" then return end
 local raidId = info.raidId or (type(k)=="number" and k) or tonumber(k)
 local mapId = info.mapId
 local spawnName = info.spawnName or "RE1001"
 if not raidId or not mapId then return end
 -- Normalize mapId: 50101-50120 -> 50001-50020 (RAID normal)
 if mapId >= 50101 and mapId <= 50120 then
  mapId = mapId - 100
 end
 -- ASC Tower: mapId 50301-50326 langsung valid (tidak perlu normalize)
 local isAscEntry = (mapId >= 50301 and mapId <= 50326)
 if not isAscEntry and (mapId < 50001 or mapId > 50020) then return end
 local rank = SPAWN_RANK[spawnName] or 0
 -- ASC: mapNum = mapId - 50300 (Tower 1-26), RAID: mapNum = mapId - 50000 (Map 1-20)
 local mapNum = isAscEntry and (mapId - 50300) or (mapId - 50000)
 local mapName = MAP_NAMES[mapNum] or ("Map "..mapNum)
 -- Grade: ASC pakai _runeGradeCache[negatif] dari chat parser, RAID pakai RAID_CONFIG_GRADE
 local _ascCacheKey = isAscEntry and (-mapNum) or nil
 local grade = (RAID_CONFIG_GRADE and RAID_CONFIG_GRADE[raidId])
  or (_ascCacheKey and _runeGradeCache and _runeGradeCache[_ascCacheKey])
  or (isAscEntry and _ASC_CHAT_CACHE and _ASC_CHAT_CACHE[mapNum] and _ASC_CHAT_CACHE[mapNum].grade)
  or (_runeGradeCache and _runeGradeCache[mapNum])
  or "?"
 local rankLbl = grade ~= "?" and ("["..grade.."]") or "[?]"
 -- BossName dari _ASC_CHAT_CACHE (cache bersih dari chat parser, bukan entry negatif)
 local _prevBossName = _ASC_CHAT_CACHE and _ASC_CHAT_CACHE[mapNum] and _ASC_CHAT_CACHE[mapNum].bossName or nil
 -- Hapus entry temp negatif jika masih ada (cleanup)
 if RAID_LIVE[-(mapId)] then RAID_LIVE[-(mapId)] = nil end
 if _ascCacheKey and RAID_LIVE[_ascCacheKey] then RAID_LIVE[_ascCacheKey] = nil end
 RAID_LIVE[raidId] = {
  raidId = raidId,
  mapId = mapId,
  spawnName = spawnName,
  rank = rank,
  grade = grade,
  isAscension = isAscEntry,
  bossName = _prevBossName,
  endTime = info.endTime,
  label = isAscEntry
   and ("Ascension Tower "..mapNum..(_prevBossName and (" - "..(_prevBossName:gsub("^%l",string.upper))) or "").." ["..grade.."]")
   or ("Map "..mapNum.." - "..mapName.." "..rankLbl),
 }
end
end

-- [v270] GetBestGrade: grade dari RAID_CONFIG_GRADE via raidId (akurat 100%)
-- Fallback: _runeGradeCache (chat/popup), lalu RAID_LIVE entry grade field
-- mapNum = angka map (1-18), return string grade atau nil
-- [FIX v272] Ascension: prioritaskan _ASC_CHAT_CACHE DULU sebelum RAID_CONFIG_GRADE
-- karena RAID_CONFIG_GRADE butuh raidId positif dari server (belum tentu ada saat ResolveAscEntry dipanggil)
-- _ASC_CHAT_CACHE diisi ParseChatLine dari TipsPanel (datang LEBIH AWAL dari UpdateRaidInfo server)
function GetBestGrade(mapNum, isAscension)
 local mapId = isAscension and (50300 + mapNum) or (50000 + mapNum)
 local cacheKey = isAscension and (-mapNum) or mapNum

 -- [FIX v272] PRIORITAS 0 (khusus Ascension): _ASC_CHAT_CACHE adalah sumber tercepat dan paling akurat
 -- TipsPanel (ParseChatLine) datang SEBELUM UpdateRaidInfo dari server, jadi ini harus dicek PERTAMA
 if isAscension and _ASC_CHAT_CACHE then
  local _ascEntry = _ASC_CHAT_CACHE[mapNum]
  if _ascEntry and _ascEntry.grade and _ascEntry.grade ~= "?" then
   return _ascEntry.grade
  end
 end

 -- PRIORITAS 1: _runeGradeCache dengan key negatif (diisi ParseChatLine bersamaan dengan _ASC_CHAT_CACHE)
 if isAscension and _runeGradeCache then
  local _cg = _runeGradeCache[-mapNum] or _runeGradeCache[cacheKey]
  if _cg and _cg ~= "?" then return _cg end
 end

 -- PRIORITAS 2: RAID_CONFIG_GRADE via raidId positif dari server (datang LEBIH LAMBAT)
 -- Berlaku untuk RAID normal DAN ASC (struktur raidId sama)
 for _, ent in pairs(RAID_LIVE) do
  local entMapMatch = (ent.mapId == mapId)
  local entAscMatch = (isAscension and ent.isAscension) or (not isAscension and not ent.isAscension)
  if entMapMatch and entAscMatch and ent.raidId and ent.raidId > 0 then
   local g = RAID_CONFIG_GRADE and RAID_CONFIG_GRADE[ent.raidId]
   if g and g ~= "?" then return g end
  end
 end

 -- PRIORITAS 3: _runeGradeCache normal (untuk RAID Normal key positif)
 if not isAscension and _runeGradeCache then
  if _runeGradeCache[cacheKey] and _runeGradeCache[cacheKey] ~= "?" then
   return _runeGradeCache[cacheKey]
  end
 end

 -- PRIORITAS 4: RAID_LIVE entry grade field (last resort)
 for _, ent in pairs(RAID_LIVE) do
  if ent.mapId == mapId and ent.grade and ent.grade ~= "?" then
   if isAscension and ent.isAscension then return ent.grade end
   if not isAscension and not ent.isAscension then return ent.grade end
  end
 end
 return nil
end


--
-- Sumber 1 (UTAMA) - workspace.Maps.Map.RaidEnter:
-- ChildAdded di RE1001/RE1002 -> RaidEnterX muncul = raid Map X buka
-- ChildRemoved di RE1001/RE1002 -> RaidEnterX hilang = raid Map X tutup
-- INSTANT, tidak bisa miss/stale.
--
-- Sumber 2 (raidId saja) - UpdateRaidInfo remote:
-- Hanya untuk dapat raidId yang dibutuhkan CreateRaidTeam.
-- ============================================================

_WH.raidConns = {}

DisconnectRaidConns = function()
 for _, conn in ipairs(_WH.raidConns) do
 pcall(function() conn:Disconnect() end)
 end
 _WH.raidConns = {}
end

-- Ekstrak mapNum dari nama child (mis. "RaidEnter7" -> 7)
local function _parseRaidEnterName(name)
 local n = name:match("^RaidEnter(%d+)$")
 return n and tonumber(n) or nil
end

-- Child RaidEnterX muncul di RE1001/RE1002 = raid Map X buka
local function _onRaidChildAdded(child, slotName)
 local mapNum = _parseRaidEnterName(child.Name)
 if not mapNum or mapNum < 1 or mapNum > 26 then return end -- Map 1-20 normal, 1-26 AT
 local mapId = 50000 + mapNum
 -- Cek sudah ada entry raidId asli untuk map ini
 for _, ent in pairs(RAID_LIVE) do
 if ent.mapId == mapId and not ent._tempEntry then return end
 end
 -- Buat entry sementara (tempKey negatif agar tidak bentrok raidId server)
 local tempKey = -(mapId)
 -- [FIX] Preserve isAscension & bossName jika chat parser sudah buat entry Ascension di key ini
 -- Chat notif bisa datang SEBELUM workspace event, jangan timpa flag isAscension-nya
 local _prevIsAsc = false
 local _prevBossName = nil
 local _prevGrade = "?"
 if RAID_LIVE[tempKey] and RAID_LIVE[tempKey].isAscension then
  _prevIsAsc = true
  _prevBossName = RAID_LIVE[tempKey].bossName
  _prevGrade = RAID_LIVE[tempKey].grade or "?"
 end
 local _mn = mapNum
 RAID_LIVE[tempKey] = {
  raidId = tempKey,
  mapId = mapId,
  spawnName = slotName or "RE1001",
  rank = 0,
  grade = _prevGrade,
  endTime = nil,
  _tempEntry = true,
  isAscension = _prevIsAsc,
  bossName = _prevBossName,
  label = _prevIsAsc
   and ("Ascension Tower ".._mn..(_prevBossName and (" - "..(_prevBossName:gsub("^%l",string.upper))) or "").." [".._prevGrade.."]")
   or ("Map ".._mn.." - "..(MAP_NAMES[_mn] or "Map ".._mn).." [?]"),
 }
 RebuildRaidList()
 -- [v58] Gunakan debounce terpusat: jangan langsung bangunkan siapapun
 -- TriggerEntryWakeup() akan tunggu 3 detik setelah notif terakhir baru fire RAID & ASC
 if TriggerEntryWakeup then TriggerEntryWakeup() end
 -- [v_FIX] Webhook langsung dari workspace watcher
 if not _whSilent and _webhookEnabled and _webhookUrl and _webhookUrl ~= "" then
  task.spawn(function()
   task.wait(0.5)
   for _, ent in pairs(RAID_LIVE) do
    if ent.label and ent.label ~= "" and _WH and _WH.AddLine then
     -- [v_FIX] Gunakan _WH_resolveGrade: formula baru ASC (raidId%100) + fallback TipsPanel
     local _grade = _WH_resolveGrade and _WH_resolveGrade(ent) or ent.grade or "?"
     if ent.isAscension then
      local mn = ent.mapId and (ent.mapId - 50300) or "?"
      local bn = ent.bossName and (" - "..ent.bossName) or ""
      _WH.AddLine("The MaFissure appeared in Ascension Tower "..tostring(mn)..bn.." [".._grade.."]")
     else
      local mn = ent.mapId and (ent.mapId - 50000) or "?"
      local nm = MAP_NAMES and MAP_NAMES[mn] or ("Map "..tostring(mn))
      _WH.AddLine("The MaFissure appeared in "..tostring(mn)..","..nm.." [".._grade.."]")
     end
    end
   end
  end)
 end
end

-- Child RaidEnterX hilang = raid Map X tutup
local function _onRaidChildRemoved(child)
 local mapNum = _parseRaidEnterName(child.Name)
 if not mapNum then return end
 local mapId = 50000 + mapNum
 local changed = false
 for rid, ent in pairs(RAID_LIVE) do
 if ent.mapId == mapId then
 RAID_LIVE[rid] = nil; changed = true
 end
 end
 if changed then
  RebuildRaidList()
  -- [BUG FIX 4] Jika RAID_LIVE kosong total, reset sent-cache agar event berikutnya bisa kirim notif baru
  local anyLeft = false
  for _ in pairs(RAID_LIVE) do anyLeft = true; break end
  if not anyLeft then _whResetSentCache() end
 end
end
-- Pasang watcher ke satu slot (RE1001 atau RE1002)
local function _watchRaidSlot(reFolder)
 if not reFolder then return end
 for _, child in ipairs(reFolder:GetChildren()) do
 _onRaidChildAdded(child, reFolder.Name)
 end
 reFolder.ChildAdded:Connect(function(child)
 _onRaidChildAdded(child, reFolder.Name)
 -- [v268] Scan RaidCoolingGui untuk dapat grade dari ValueText/TextLabel
 task.spawn(function()
 task.wait(1) -- tunggu descendants terisi
 pcall(function()
 -- Scan semua TextLabel di dalam child (RaidEnterX atau RaidCoolingGui)
 local function scanForGrade(obj)
 for _, desc in ipairs(obj:GetDescendants()) do
 if desc:IsA("TextLabel") or desc:IsA("TextBox") then
 local txt = (desc.Text or ""):gsub("<[^>]+>","")
 -- Cari teks yang mengandung grade bracket [X]
 local grade = txt:match("%[M%+%+%]") and "M++" or txt:match("%[M%+%]") and "M+" or txt:match("%[SS%]") and "SS" or txt:match("%[XM%]") and "XM" or txt:match("%[ULT%]") and "ULT" or txt:match("%[GOD%]") and "GOD" or txt:match("%[([EDCBAGSNMedcbagsn])%]") or (txt:find("%[M%]") and "M")
 if grade then
 -- Cari mapNum dari nama child (RaidEnterX)
 local mn = _parseRaidEnterName(child.Name)
 if mn and _runeGradeCache then
 local prev = _runeGradeCache[mn]
 if not prev or prev == "?" then
 _runeGradeCache[mn] = grade:upper()
 -- [v58] Gunakan debounce terpusat
 if TriggerEntryWakeup then TriggerEntryWakeup() end
 end
 end
 end
 -- Watch Text changes juga
 pcall(function()
 desc:GetPropertyChangedSignal("Text"):Connect(function()
 local t2 = (desc.Text or ""):gsub("<[^>]+>","")
 local g2 = t2:match("%[M%+%+%]") and "M++" or t2:match("%[M%+%]") and "M+" or t2:match("%[SS%]") and "SS" or t2:match("%[XM%]") and "XM" or t2:match("%[ULT%]") and "ULT" or t2:match("%[GOD%]") and "GOD" or t2:match("%[([EDCBAGSNMedcbagsn])%]") or (t2:find("%[M%]") and "M")
 if g2 then
 local mn2 = _parseRaidEnterName(child.Name)
 if mn2 and _runeGradeCache then
 local prev2 = _runeGradeCache[mn2]
 if not prev2 or prev2 == "?" then
 _runeGradeCache[mn2] = g2:upper()
 -- [v58] Gunakan debounce terpusat
 if TriggerEntryWakeup then TriggerEntryWakeup() end
 end
 end
 end
 end)
 end)
 end
 end
 end
 scanForGrade(child)
 -- Cari RaidCoolingGui khusus
 for _, desc in ipairs(child:GetDescendants()) do
 if desc.Name == "RaidCoolingGui" then
 scanForGrade(desc)
 end
 end
 end)
 end)
 end)
 reFolder.ChildRemoved:Connect(function(child)
 _onRaidChildRemoved(child)
 end)
end

-- Tunggu workspace.Maps.Map.RaidEnter lalu pasang watcher
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

-- UpdateRaidInfo: HANYA untuk dapat raidId + grade dari server
-- Bukan lagi sumber utama exist/tidak-nya raid
ConnectRaidListeners = function()
 DisconnectRaidConns()

 local _RE_Update = Remotes:FindFirstChild("UpdateRaidInfo")
 local _RE_Enter = Remotes:FindFirstChild("EnterRaidsUpdateInfo")

 if _RE_Update then
 local conn = _RE_Update.OnClientEvent:Connect(function(data)
 if type(data) ~= "table" then return end
 local action = data.action
 local raidInfos = data.raidInfos
 if type(raidInfos) ~= "table" then return end

 if action == "RemoveRaidEnters" then
 for k, info in pairs(raidInfos) do
 local raidId = type(k)=="number" and k or tonumber(k)
 if raidId then
  local ent = RAID_LIVE[raidId]
  -- [FIX] Clear grade cache AT saat raid tutup agar tidak cemari raid baru
  if ent and ent.isAscension and ent.mapId then
   local _mn = ent.mapId >= 50301 and (ent.mapId - 50300)
    or (ent.mapId >= 50001 and ent.mapId <= 50026 and (ent.mapId - 50000))
    or nil
   if _mn then
    if _runeGradeCache then _runeGradeCache[-_mn] = nil end
    if _ASC_CHAT_CACHE then _ASC_CHAT_CACHE[_mn] = nil end
   end
  end
  RAID_LIVE[raidId] = nil
 end
 end
 RebuildRaidList()
 else
 for k, info in pairs(raidInfos) do
 repeat
 if type(info) ~= "table" then break end
 local raidId = info.raidId or (type(k)=="number" and k) or tonumber(k)
 local mapId = info.mapId
 if not raidId or not mapId then break end
 -- Normalize mapId ke lobby range (RAID normal)
 if mapId >= 50101 and mapId <= 50120 then mapId = mapId - 100 end
 -- ASC Tower 50301-50326 langsung valid, RAID normal 50001-50020
 local _isAscMapId = (mapId >= 50301 and mapId <= 50326)
 -- [v63 FIX] raidId >= 935001 = pasti ASC Tower meskipun mapId di luar range normal
 -- Jangan buang entry ini hanya karena mapId tidak dikenali
 local _isAscById = (raidId >= 935001)
 if not _isAscMapId and not _isAscById and (mapId < 50001 or mapId > 50020) then break end
 -- Normalize mapId ASC: server bisa kirim berbagai format
 if _isAscById and not _isAscMapId then
  -- Format: mapId = 50001-50020 (pakai base raid normal, Tower N = mapId 50000+N)
  if mapId >= 50001 and mapId <= 50026 then mapId = mapId + 300 end -- 50005 -> 50305
  -- Format: mapId = 50101-50126 (in-map raid, +100 dari base)
  if mapId >= 50101 and mapId <= 50126 then mapId = mapId + 200 end -- 50105 -> 50305
  -- Format: mapId = 50401-50426
  if mapId >= 50401 and mapId <= 50426 then mapId = mapId - 100 end -- 50405 -> 50305
  -- Format: mapId = 50201-50226
  if mapId >= 50201 and mapId <= 50226 then mapId = mapId + 100 end -- 50205 -> 50305
  -- Jika masih tidak dikenali, fallback parsial
  if not (mapId >= 50301 and mapId <= 50326) then
   local _mn = math.max(1, math.min(26, math.abs(mapId - 50300)))
   mapId = 50300 + _mn
  end
  _isAscMapId = true
 end

 local mapNum = _isAscMapId and (mapId - 50300) or (mapId - 50000)
 local spawnName = info.spawnName or "RE1001"
 local rank = SPAWN_RANK[spawnName] or 0
 -- [v271] Grade dari RAID_CONFIG_GRADE (formula matematika, cover semua seri)
 -- [FIX] AT: cache key negatif (-mapNum), RAID normal: positif (mapNum)
 local _grCacheKey = _isAscMapId and (-mapNum) or mapNum
 local grade = (RAID_CONFIG_GRADE and RAID_CONFIG_GRADE[raidId])
  or (_runeGradeCache and _runeGradeCache[_grCacheKey])
  or (_ASC_CHAT_CACHE and _isAscMapId and _ASC_CHAT_CACHE[mapNum] and _ASC_CHAT_CACHE[mapNum].grade)
  or "?"
 local tempKey = -(mapId) -- key entry chat Ascension (negatif)
 -- Detect isAscension: 3 sumber (makin akurat, tidak rely on chat saja)
 -- 1. raidId >= 935001 -> pasti Ascension Tower (confirmed SimpleSPY: 936501)
 -- 2. Entry negatif dari chat parser masih hidup di RAID_LIVE
 -- 3. Entry sebelumnya sudah di-mark Ascension (preserve)
 local _isAsc = false
 local _bnAsc = nil
 if raidId >= 935001 then
  -- Sumber paling akurat: raidId range Ascension Tower
  _isAsc = true
  if RAID_LIVE[tempKey] and RAID_LIVE[tempKey].bossName then
   _bnAsc = RAID_LIVE[tempKey].bossName
  elseif RAID_LIVE[raidId] and RAID_LIVE[raidId].bossName then
   _bnAsc = RAID_LIVE[raidId].bossName
  end
 elseif RAID_LIVE[tempKey] and RAID_LIVE[tempKey].isAscension then
  -- Entry temp Ascension dari chat parser masih ada
  _isAsc = true; _bnAsc = RAID_LIVE[tempKey].bossName
 elseif RAID_LIVE[raidId] and RAID_LIVE[raidId].isAscension then
  -- Entry sudah ada sebelumnya dan sudah di-mark Ascension -> preserve
  _isAsc = true; _bnAsc = RAID_LIVE[raidId].bossName
 end
 -- Build label
 local _lbl = _isAsc
  and ("Ascension Tower "..mapNum..(_bnAsc and (" - "..(_bnAsc:gsub("^%l",string.upper))) or "").." ["..grade.."]")
  or ("Map "..mapNum.." - "..(MAP_NAMES[mapNum] or "Map "..mapNum).." ["..grade.."](ID:"..raidId..")")
 local entryData = {
 raidId = raidId,
 mapId = mapId,
 spawnName = spawnName,
 rank = rank,
 grade = grade,
 isAscension = _isAsc,
 bossName = _bnAsc,
 endTime = info.endTime,
 label = _lbl,
 }
 -- Kalau ada entry temp Ascension dari chat (negatif), replace dengan raidId asli server
 if RAID_LIVE[tempKey] then
  -- Preserve grade dari temp entry jika entryData masih "?"
  if grade == "?" and RAID_LIVE[tempKey].grade and RAID_LIVE[tempKey].grade ~= "?" then
   entryData.grade = RAID_LIVE[tempKey].grade
   entryData.label = entryData.label:gsub("%[%?%]", "["..RAID_LIVE[tempKey].grade.."]")
  end
  RAID_LIVE[raidId] = entryData
  RAID_LIVE[tempKey] = nil
 elseif not RAID_LIVE[raidId] then
  -- Entry baru dari server: langsung pakai entryData (grade sudah dihitung di atas)
  -- termasuk fallback _ASC_CHAT_CACHE dan _runeGradeCache
  RAID_LIVE[raidId] = entryData
 else
  -- Sudah ada entry: update grade/rank/label, preserve isAscension yang sudah true
  RAID_LIVE[raidId].grade = grade
  RAID_LIVE[raidId].rank = rank
  RAID_LIVE[raidId].label = _lbl
  if _isAsc then
   RAID_LIVE[raidId].isAscension = true
   if _bnAsc then RAID_LIVE[raidId].bossName = _bnAsc end
  end
 end
 until true
 end
 RebuildRaidList()
 -- [v58] Gunakan debounce terpusat
 if TriggerEntryWakeup then TriggerEntryWakeup() end
 -- [v_FIX] Ganti TriggerWebhookDebounce (no-op)
 if not _whSilent and _webhookEnabled and _webhookUrl and _webhookUrl ~= "" then
  for _, ent in pairs(RAID_LIVE) do
   if ent.label and ent.label ~= "" and _WH and _WH.AddLine then
    -- [v_FIX] Gunakan _WH_resolveGrade: formula baru ASC (raidId%100) + fallback TipsPanel
    local _grade = _WH_resolveGrade and _WH_resolveGrade(ent) or ent.grade or "?"
    if ent.isAscension then
     local mn = ent.mapId and (ent.mapId - 50300) or "?"
     local bn = ent.bossName and (" - "..ent.bossName) or ""
     _WH.AddLine("The MaFissure appeared in Ascension Tower "..tostring(mn)..bn.." [".._grade.."]")
    else
     local mn = ent.mapId and (ent.mapId - 50000) or "?"
     local nm = MAP_NAMES and MAP_NAMES[mn] or ("Map "..tostring(mn))
     _WH.AddLine("The MaFissure appeared in "..tostring(mn)..","..nm.." [".._grade.."]")
    end
   end
  end
 end
 end
 end)
 table.insert(_WH.raidConns, conn)
 end

 -- EnterRaidsUpdateInfo: slotIndex + serverMapId saat masuk map
 -- [FIX] Skip event dari Tower/JTP map (50300+) agar tidak mencemari RAID state
 if _RE_Enter then
 local conn = _RE_Enter.OnClientEvent:Connect(function(data)
 if type(data) ~= "table" then return end
 -- Abaikan jika tidak ada slotIndex sama sekali (bukan raid event)
 if data.slotIndex == nil and data.fromMapId == nil and data.mapId == nil then return end
 local evMapId = data.mapId or data.fromMapId or 0
 -- [BUG FIX v49] Pisahkan handler Ascension vs RAID Normal secara tegas:
 -- Event dari map 50300+ HANYA boleh diproses jika ASC sedang aktif (ASC.running atau ASC.inMap)
 -- Event dari map 50101-50120 HANYA boleh masuk ke RAID jika ASC.inMap == false
 -- Ini mencegah serverMapId RAID tercemar oleh event Ascension Tower dan sebaliknya
 if evMapId >= 50300 then
  -- [v64 FIX] Event Ascension Tower: tulis ke ASC.serverMapId (bukan RAID state)
  if evMapId >= 50301 and evMapId <= 50326 and ASC and (ASC.running or ASC.inMap) then
   ASC.serverMapId = evMapId
  end
  return
 end
 -- Dari sini: event adalah RAID normal (mapId 50101-50120 atau 0)
 -- Guard: jika ASC sedang di dalam map, event ini bisa jadi spurious dari sisi server
 -- Tulis ke RAID state HANYA jika RAID.running dan ASC.inMap = false
 if ASC.inMap then return end
 if data.slotIndex then RAID.slotIndex = data.slotIndex end
 if data.fromMapId then RAID.fromMapId = data.fromMapId end
 if data.mapId then
  local mid = data.mapId
  if mid >= 50101 and mid <= 50120 then
   RAID.serverMapId = mid
  end
 end
 end)
 table.insert(_WH.raidConns, conn)
 end
end

-- Pasang listener saat start
task.spawn(function() ConnectRaidListeners() end)

-- Auto-reconnect kalau Remotes refresh (mis. setelah rejoin)
task.spawn(function()
 local lastRef = Remotes:FindFirstChild("UpdateRaidInfo")
 while ScreenGui.Parent do
 task.wait(3)
 local cur = Remotes:FindFirstChild("UpdateRaidInfo")
 if cur ~= lastRef then
 lastRef = cur
 if cur then ConnectRaidListeners() end
 end
 end
end)
--  Helpers 
function StopRaid()
 _raidInterrupt = false
 MODE:Release("raid") -- [v252]
 RAID.running = false
 RAID.inMap = false
 ReleaseMapLock("raid") -- [v52 FIX] pastikan lock terlepas saat stop paksa
 if RAID.thread then
 pcall(function() task.cancel(RAID.thread) end)
 RAID.thread = nil
 end
 -- [FIX] Destroy wakeup event agar tidak leak
 if _raidWakeup then
 pcall(function() _raidWakeup:Destroy() end)
 _raidWakeup = nil
 end
 -- Reset state sesi
 RAID.raidId = nil
 RAID.raidMapId = nil
 RAID.serverMapId = nil
 RAID.fromMapId = nil
 RAID.slotIndex = 2
 RAID._raidDone = false
 RAID._cooldownActive = false -- reset agar tidak stuck di standby loop
 RAID_LIVE = {}
 _defaultRRIdx = 0 -- reset RR saat RAID habis
 RAID_ID_LIST = {}
 if _runeGradeCache then
  -- Reset semua cache grade saat sesi RAID baru dimulai (StopRaid dipanggil sebelum StartRaid)
  -- Ini memastikan batch notif lama tidak mencemari sesi baru
  for k in pairs(_runeGradeCache) do _runeGradeCache[k] = nil end
 end
 if RebuildRaidList then pcall(RebuildRaidList) end
 -- [FIX] JANGAN reset setting user (difficulty/rune/grades/preferMaps) di sini!
 -- StopRaid dipanggil oleh StartRaidLoop setiap kali Start ditekan
 -- kalau di-reset di sini, semua pilihan user (Hard, Rune Map, Pick Rank) hilang
 -- Setting user hanya boleh direset dari UI (tombol difficulty/rune/grade)
end

_raidSessionStart = nil -- waktu mulai raid session

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
 if RAID.dot then
 RAID.dot.BackgroundColor3 = color or Color3.fromRGB(100,100,100)
 end
end

function RaidCounterUpdate()
 if RAID.suksesLbl then RAID.suksesLbl.Text = tostring(RAID.sukses) end
end

-- ============================================================
-- AUTO ASCENSION : LOGIC
-- ============================================================
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

function AscStatusUpdate(msg, color)
 if ASC.statusLbl then
  ASC.statusLbl.Text = msg
  ASC.statusLbl.TextColor3 = color or Color3.fromRGB(255,200,100)
 end
 if ASC.dot then
  ASC.dot.BackgroundColor3 = color or Color3.fromRGB(100,100,100)
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

-- [FIX GODMODE] Helper: baca mapId player saat ini secara realtime
local function GetCurrentMapId()
 local ok, wm = pcall(function()
  return workspace:GetAttribute("MapId") or workspace:GetAttribute("mapId") or workspace:GetAttribute("CurrentMapId")
 end)
 return (ok and type(wm) == "number") and wm or nil
end

-- [FIX GODMODE] Helper: player posisi realtime
local function GetPlayerPos()
 local char = LP and LP.Character
 local hrp = char and char:FindFirstChild("HumanoidRootPart")
 return hrp and hrp.Position or nil
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
 -- ============================================================
 -- ResolveAscEntry: 100% IDENTIK dengan ResolveEntry (Auto Raid Normal)
 -- Satu-satunya perbedaan: pakai ASC.* dan ascList (mapNum) bukan RAID_ID_LIST (mapId)
 -- MapId masuk ke tower tetap 503xx â€” tidak diubah di sini
 -- ============================================================
 local function ResolveAscEntry()
  local ascList = GetAscensionList()
  if #ascList == 0 then return nil end

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
   if #ascList == 0 then return nil end
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

  -- ============================================================
  -- MANUAL MODE â€” identik RAID: 3 tahap, fallback ke terkecil
  -- ============================================================
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
   if #valid_asc == 0 then return nil end

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
    -- Rank diset tapi tidak ada tower yang cocok -> return nil, tunggu event berikutnya
    ASC.manualMatchMode = "none"
    return nil
   end

   -- Tidak ada Preferred Rank diset -> fallback ke tower terkecil dari kandidat
   ASC.manualMatchMode = "fallback"
   table.sort(valid_asc, function(a, b) return a.mapNum < b.mapNum end)
   return valid_asc[1]
  end

  -- ============================================================
  -- BYRANK + BYMAP + hasPick: identik RAID
  -- ============================================================
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
   if pm == "byrank" then return nil end
  end

  if pm == "bymap" and next(ASC.preferMaps or {}) ~= nil then
   local mapMatched = {}
   for _, r in ipairs(ascList) do
    if ASC.preferMaps[r.mapNum] then table.insert(mapMatched, r) end
   end
   if #mapMatched > 0 then return pickLowest(mapMatched) end
   return nil
  end

  return pickByDiff(ascList)
 end

 ASC.thread = task.spawn(function()
  pcall(function()
  while ASC.running do
   repeat

    -- [v48] Cek semua interrupt (sama seperti RAID)
    if MODE.current == "dungeon" or (DUNGEON and DUNGEON.interrupt) then
     ASC.inMap = false
     AscStatusUpdate("[||] Dungeon aktif - menunggu...", Color3.fromRGB(255,140,0))
     while (MODE.current == "dungeon" or (DUNGEON and DUNGEON.interrupt)) and ASC.running do task.wait(0.5) end
     if not ASC.running then break end
     AscStatusUpdate("> Dungeon selesai - lanjut Ascension...", C.ACC3)
     task.wait(0.1)
    end

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
    if (curWm >= 50101 and curWm <= 50120) or (curWm >= 50201 and curWm <= 50205) or curWm == 50303 then
     AscStatusUpdate("[||] Sedang di dalam map lain - tunggu...", Color3.fromRGB(255,140,0))
     task.wait(3); break
    end

    -- [v48] Resolve entry berdasarkan Pick Mode
    local raidEntry = ResolveAscEntry()

    -- Waiting loop jika tidak ada Ascension Tower tersedia
    while ASC.running and not raidEntry do
     local ascList = GetAscensionList()
     local _pm = ASC.pickMode or "easy"
     -- [v61 CYCLEFIX] Jika RAID sedang fallback di siklus ini, ASC harus standby
     -- Tidak boleh masuk Tower sampai siklus event baru datang (TriggerEntryWakeup reset flag)
     if _raidFallbackActive and RAID.running then
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
      raidEntry = ResolveAscEntry()
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
    local bossHint = raidEntry.bossName and (" - "..raidEntry.bossName) or ""
    AscStatusUpdate("Masuk: Tower "..mn..bossHint.." ["..raidEntry.grade.."]", Color3.fromRGB(100,200,255))

    -- [FIX] Set _ascInterrupt dulu -> MA pause segera (mirip _raidInterrupt di RAID)
    -- Lalu tunggu sebentar biar MA sempat pause sebelum kita masuk tower
    _ascInterrupt = true
    if MA.running then
        local _wma = 0
        while MA.running and _ascInterrupt and _wma < 1 do task.wait(0.05); _wma = _wma + 0.05 end
    end

    ASC.inMap = true
    _ascInterrupt = false  -- inMap=true sudah aktif, WaitRaidDone cek ASC.inMap langsung
    _ascBusy  = true  -- RAID harus pause total selama ASC aktif (inMap+cooldown)
    _ascMatchedThisCycle = true   -- [v61 CYCLEFIX] ASC sudah match di siklus ini
    _raidFallbackActive  = false  -- [v61 CYCLEFIX] RAID tidak boleh fallback di siklus ini
    _ascPending = false -- [v57 FIX] inMap=true sudah cover, tidak perlu pending lagi
    -- [v56 FIX] _ascDominatedThisEvent dihapus - RAID dan ASC sekarang independen
    -- [v52 FIX] Setelah inMap=true di-set, lock tidak diperlukan lagi (IsAnyMapActive sudah cover)
    ReleaseMapLock("asc")

    -- Entry ASC = identik RAID normal, beda hanya mapId dan RUNE_IDS:
    -- RAID: StartChallengeRaidMap({mapId = raidEntry.mapId + 100}) â†’ 50101-50120
    -- ASC : StartChallengeRaidMap({mapId = 50300+mn})              â†’ Tower X = 50301-50326
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
        pcall(function()
         RE.EquipHeroWithData:FireServer({ heroGuid = hGuid, userId = MY_USER_ID })
        end)
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
      "goblin king","giant arachnid","buryura","igris",
      "leader of the polar","arch lich","kargalgan","baran",
      "beru","grendal","monarch plague","frostborne","legia",
      "monarch beastly","beastly fangs","silas","unbreakable monarch",
      "yogumunt","monarch of transfiguration","transfiguration",
      "antares","ashborn","dominion","absolute","monarch","fragment","boss",
      "legendary super saiyan","broly",
      "goku[super4]","goku super4","goku super 4",
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

     -- [FIX v50] Early boss detection ASC - scan agresif semua sumber
     local _earlyBoss = nil
     local _loadWait = 0
     while _loadWait < 10 and ASC.running and not _ascDone do
      task.wait(0.5); _loadWait = _loadWait + 0.5
      if _loadWait >= 1 and not _earlyBoss then
       -- Sumber 1: GetRaidEnemies()
       local _eList = GetRaidEnemies()
       -- Sumber 2: fallback GetEnemiesLocal() kalau kosong
       if #_eList == 0 then _eList = GetEnemiesLocal() end
       for _, e in ipairs(_eList) do
        if IsBossAscWithHint(e.model.Name) then _earlyBoss = e; break end
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
              _earlyBoss = {guid=g, hrp=hrp, model=obj}; break
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
       local g = obj:GetAttribute("EnemyGuid") or obj:GetAttribute("BossGuid") or obj:GetAttribute("Guid") or obj:GetAttribute("GUID")
       local hrp = obj:FindFirstChild("HumanoidRootPart")
       local hum = obj:FindFirstChildOfClass("Humanoid")
       if g and hrp and hum and hum.Health > 0 then
        boss = {guid=g, hrp=hrp, model=obj}
        _bossFoundViaEvent = true
       end
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

     -- [FIX v50] Cari boss - max 40s (Tower butuh lebih lama dari RAID)
     -- Pakai GetRaidEnemies() + fallback GetEnemiesLocal() tiap iterasi
     local waitBoss = 0
     while ASC.running and not boss and waitBoss < 5 and not _ascDone do
      -- Coba GetRaidEnemies() dulu
      local _bList = GetRaidEnemies()
      -- Fallback: kalau kosong (mapId belum update), pakai GetEnemiesLocal()
      if #_bList == 0 then _bList = GetEnemiesLocal() end
      for _, e in ipairs(_bList) do
       if IsBossAscWithHint(e.model.Name) then boss = e; break end
      end
      -- Fallback terakhir: scan workspace:GetDescendants() setelah 15s
      if not boss and waitBoss >= 15 and waitBoss % 5 < 0.4 then
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
      if not boss then
       AscStatusUpdate("Find Boss... ("..math.floor(waitBoss).."s/5s)", Color3.fromRGB(160,148,135))
       task.wait(0.3); waitBoss = waitBoss + 0.3
      end
     end
     for _, c in ipairs(_bossEventConns) do pcall(function() c:Disconnect() end) end
     _bossEventConns = {}

     -- Helper bossPos yang aman
     local function GetSafeAscBossPos()
      if boss and boss.hrp and boss.hrp.Parent then
       local p = boss.hrp.Position
       if p.Y > -200 then return p end
      end
      return nil
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

       -- 1) TP Player ke boss
       pcall(function()
        local char = LP.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local safePos = GetSafeAscBossPos()
        if hrp and safePos then hrp.CFrame = CFrame.new(safePos + Vector3.new(3,0,0)) end
       end)

       -- 2) TP semua hero client-side ke boss
       pcall(function()
        local safePos2 = GetSafeAscBossPos()
        if not safePos2 then return end
        local heroFolder = workspace:FindFirstChild("Heros")
        if heroFolder then
         for _, hModel in ipairs(heroFolder:GetChildren()) do
          local hHrp = hModel:FindFirstChild("HumanoidRootPart")
          if hHrp then
           hHrp.CFrame = CFrame.new(safePos2 + Vector3.new(math.random(-2,2),0,math.random(-2,2)))
          end
         end
        end
       end)

       -- 3) Fire hero remotes
       pcall(function()
        local safePos3 = GetSafeAscBossPos()
        if safePos3 then FireHeroRemotes(bossGuid, safePos3) end
       end)
       if RE.HeroStand and #HERO_GUIDS > 0 then
        local safePos3b = GetSafeAscBossPos()
        if safePos3b then
         for _, hGuid in ipairs(HERO_GUIDS) do
          pcall(function()
           RE.HeroStand:FireServer({ heroGuid=hGuid, userId=MY_USER_ID, standPos=safePos3b+Vector3.new(1,0,1) })
          end)
         end
        end
       end

       -- 4) UnEquip -> EquipBest
       task.wait(0.3)
       if RE.UnEquipHero then pcall(function() RE.UnEquipHero:FireServer() end) end
       task.wait(0.3)
       if RE.EquipBestHero then pcall(function() RE.EquipBestHero:FireServer() end) end
       task.wait(0.3)

       -- 5) TP ulang hero setelah re-equip
       pcall(function()
        local safePos5 = GetSafeAscBossPos()
        if not safePos5 then return end
        local heroFolder = workspace:FindFirstChild("Heros")
        if heroFolder then
         for _, hModel in ipairs(heroFolder:GetChildren()) do
          local hHrp = hModel:FindFirstChild("HumanoidRootPart")
          if hHrp then
           hHrp.CFrame = CFrame.new(safePos5 + Vector3.new(math.random(-2,2),0,math.random(-2,2)))
          end
         end
        end
       end)
       pcall(function()
        local safePos5b = GetSafeAscBossPos()
        if safePos5b then FireHeroRemotes(bossGuid, safePos5b) end
       end)

       -- 6) Background thread: TP player+hero terus ke boss tiap 0.5s
       local _tpTh = task.spawn(function()
        while ASC.running and not _ascDone do
         -- [v48] Stop TP jika sudah keluar Ascension Tower
         local _tpMap = GetCurrentMapId()
         if _tpMap and (_tpMap < 50301 or _tpMap > 50326) then break end
         pcall(function()
          local pos = GetSafeAscBossPos()
          if not pos then return end
          local char = LP.Character
          local hrp = char and char:FindFirstChild("HumanoidRootPart")
          if hrp then hrp.CFrame = CFrame.new(pos + Vector3.new(3,0,0)) end
          local heroFolder = workspace:FindFirstChild("Heros")
          if heroFolder then
           for _, hModel in ipairs(heroFolder:GetChildren()) do
            local hHrp = hModel:FindFirstChild("HumanoidRootPart")
            if hHrp then
             hHrp.CFrame = CFrame.new(pos + Vector3.new(math.random(-2,2),0,math.random(-2,2)))
            end
           end
          end
          FireHeroRemotes(bossGuid, pos)
          if RE.HeroStand then
           for _, hGuid in ipairs(HERO_GUIDS) do
            pcall(function()
             RE.HeroStand:FireServer({ heroGuid=hGuid, userId=MY_USER_ID, standPos=pos+Vector3.new(1,0,1) })
            end)
           end
          end
         end)
         task.wait(0.5)
        end
       end)

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
         task.wait(0.08)
         if not boss.model or not boss.model.Parent then break end
         local hum2 = boss.model:FindFirstChildOfClass("Humanoid")
         if not hum2 or hum2.Health <= 0 then break end
         continue
        end
        task.spawn(function() pcall(function() RaidFireDamage(bossGuid, p) end) end)
        task.wait(0.08)
       end

       pcall(function() task.cancel(_tpTh) end)
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
     pcall(function()
      _exitRe:FireServer({ currentSlotIndex = 2, toMapId = 50001 })
     end)
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
      if (SIEGE and (SIEGE.inMap or SIEGE.teleporting)) or (DUNGEON and DUNGEON.inMap) then isBusy = true end
      local _wm2 = workspace:GetAttribute("MapId") or 0
      if (_wm2 >= 50201 and _wm2 <= 50204) or _wm2 == 50303 then isBusy = true end

      -- [v56 FIX] _ascDominatedThisEvent dihapus dari logika RAID
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

-- ============================================================
-- [v73 FIX] RaidCollectAll - scan lebih agresif:
-- 1. Scan semua folder reward yang mungkin
-- 2. Scan workspace root langsung (ada item yang tidak di-folder)
-- 3. Retry 1x setelah 1.5 detik untuk item yang spawn delayed
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
 -- [v112-FIX] Nil guard ExtraReward
 if RE.ExtraReward then
  pcall(function() RE.ExtraReward:FireServer({isSell=true, guid=guid}) end)
 end
 task.wait(0.05)
 end
 end
 end

 -- Round 1: scan semua folder reward
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
 -- [v112-FIX] Nil guard ExtraReward
 if RE.ExtraReward then
  pcall(function() RE.ExtraReward:FireServer({isSell=true, guid=guid}) end)
 end
 task.wait(0.05)
 end
 end
 end

 -- [v73] Round 2: tunggu 1.5 detik lalu scan ulang (item spawn delayed)
 task.wait(1.5)
 for _, folderName in ipairs(folders) do
 collectFolder(workspace:FindFirstChild(folderName))
 end
end


-- Scan enemy/boss di workspace
-- [GODMODE FIX] Relax filter jarak, tambah fallback scan seluruh workspace
-- [GODMODE FIX 2] Validasi mapId realtime - pastikan player di dalam raid map
function GetRaidEnemies()
 local list = {}
 local seen = {}

 -- [v51-FIX] Hapus hard early-return berdasarkan MapId â€” terlalu agresif.
 -- Guard lama menyebabkan scan gagal saat MapId belum update (race condition Delta Android)
 -- atau saat workspace.MapId pakai attribute name berbeda dari yang di-read.
 -- Sekarang: tetap scan workspace, hanya matikan distFilter jika mapId tidak dikenali.
 local currentMapId = GetCurrentMapId()
 local _inNormalRaid = currentMapId and (currentMapId >= 50101 and currentMapId <= 50120)
 local _inAscTower  = currentMapId and (currentMapId >= 50301 and currentMapId <= 50326)
 -- (tidak ada early return di sini â€” biarkan scan tetap berjalan)

 -- spawnPos hanya relevan untuk Normal Raid (Ascension Tower tidak pakai RAID_SPAWN_POS)
 local activeMapId = (_inNormalRaid and RAID and RAID.serverMapId) or nil
 local spawnPos = activeMapId and RAID_SPAWN_POS and RAID_SPAWN_POS[activeMapId]
 -- [FIX] Perbesar radius 2000->8000 agar boss yang spawn jauh tetap terdeteksi
 -- Map 19/20 punya spawnPos 0,0,0 - jika spawnPos tidak valid (magnitude<1), nonaktifkan filter
 local MAX_DIST = 8000
 local useDistFilter = spawnPos and spawnPos.Magnitude > 1

 local function addEnemy(e)
 if not e:IsA("Model") then return end
 local g = e:GetAttribute("EnemyGuid") or e:GetAttribute("BossGuid") or e:GetAttribute("Guid") or e:GetAttribute("GUID")
 if not g or seen[g] then return end
 -- Fallback: beberapa boss (Giant Arachnid, dll) tidak punya HumanoidRootPart
 -- Coba HumanoidRootPart -> PrimaryPart -> Torso -> UpperTorso -> bagian apapun
 local hrp = e:FindFirstChild("HumanoidRootPart")
       or e.PrimaryPart
       or e:FindFirstChild("Torso")
       or e:FindFirstChild("UpperTorso")
       or e:FindFirstChildWhichIsA("BasePart")
 local hum = e:FindFirstChildOfClass("Humanoid")
 if not (hrp and hum and hum.Health > 0) then return end
 if useDistFilter then
 local dist = (hrp.Position - spawnPos).Magnitude
 if dist > MAX_DIST then return end
 end
 seen[g] = true
 table.insert(list, {guid=g, hrp=hrp, model=e})
 end

 -- Scan folder-folder utama
 for _, fname in ipairs({"Bosses","Boss","RaidBoss","Enemys","Enemy","Enemies","RaidEnemys","Monsters","Monster"}) do
 local folder = workspace:FindFirstChild(fname)
 if folder then
 for _, e in ipairs(folder:GetChildren()) do addEnemy(e) end
 end
 end

 -- [GODMODE FIX] Fallback: scan langsung children workspace jika folder tidak ketemu / list kosong
 if #list == 0 then
 for _, obj in ipairs(workspace:GetChildren()) do
 if obj:IsA("Model") then
 addEnemy(obj)
 -- Scan nested (beberapa game taruh enemy di sub-model)
 for _, child in ipairs(obj:GetChildren()) do
 addEnemy(child)
 end
 end
 end
 end

 return list
end

-- Serang semua enemy raid
-- [v73 FIX] Fire attackType 1+2+3 supaya damage konsisten (sebelumnya hanya 1)
RaidFireDamage = function(g, p)
 if RE.Click then
 task.spawn(function()
 pcall(function() RE.Click:InvokeServer({enemyGuid=g, enemyPos=p}) end)
 end)
 end
 if RE.Atk then
 pcall(function() RE.Atk:FireServer({attackEnemyGUID=g}) end)
 end
 for _, hGuid in ipairs(HERO_GUIDS) do
 if RE.HeroUseSkill then
 -- [v73 FIX] Fire semua attackType 1, 2, 3 bukan hanya 1
 -- [FIX v240] Jeda 0.3s antar type agar animasi tidak overflow limit 64
 for _, aType in ipairs({1, 2, 3}) do
 pcall(function() RE.HeroUseSkill:FireServer({
 heroGuid = hGuid,
 attackType = aType,
 userId = MY_USER_ID,
 enemyGuid = g,
 }) end)
 task.wait(0.3)
 end
 elseif RE.HeroSkill then
 pcall(function() RE.HeroSkill:FireServer({
 heroGuid=hGuid, enemyGuid=g, skillType=1, masterId=MY_USER_ID
 }) end)
 end
 end
end

-- ============================================================
-- GLOBAL RADAR RAID (100% GERCEP & BEBAS MANCING)
-- Membaca langsung dari memori RaidsManager milik game.
-- Mengabaikan jarak map, langsung deteksi semua Raid di seluruh server!
-- ============================================================
local _lastRescanTime = 0
local function ForceRescanRaidEnter()
    local now = tick()
    if now - _lastRescanTime < 1.5 then return end
    _lastRescanTime = now
    
    pcall(function()
        -- [TEKNIK DEWA] Membajak memori Module RaidsManager bawaan game
        local RM = require(game:GetService("ReplicatedStorage").Scripts.Client.Manager.RaidsManager)
        if type(RM) ~= "table" then return end
        
        local newFound = false
        local currentActiveIds = {}
        
        -- 1. Sedot semua data raid yang sedang aktif dari otak game
        for _, val in pairs(RM) do
            if type(val) == "table" then
                for k, info in pairs(val) do
                    repeat
                    if type(info) == "table" and info.raidId and info.mapId then
                        local raidId = info.raidId
                        local mapId = info.mapId
                        local spawnName = info.spawnName or "RE1001"
                        
                        -- Sinkronisasi Map ID
                        if mapId >= 50101 and mapId <= 50118 then mapId = mapId - 100 end
                        if mapId < 50001 or mapId > 50019 then break end
                        
                        currentActiveIds[raidId] = true
                        
                        local mapNum = mapId - 50000
                        local grade = (RAID_CONFIG_GRADE and RAID_CONFIG_GRADE[raidId]) or (_runeGradeCache and _runeGradeCache[mapNum]) or "?"
                        
                        -- Hapus data pancingan (dummy) lama jika ada
                        local tempKey = -(mapId)
                        if RAID_LIVE[tempKey] then RAID_LIVE[tempKey] = nil end
                        
                        -- Masukkan ke sistem Script kita!
                        if not RAID_LIVE[raidId] then
                            RAID_LIVE[raidId] = {
                                raidId = raidId, mapId = mapId, spawnName = spawnName,
                                rank = SPAWN_RANK[spawnName] or 0, grade = grade,
                                endTime = info.endTime,
                                label = "Map "..mapNum.." - "..(MAP_NAMES[mapNum] or "Map "..mapNum).." ["..grade.."](ID:"..raidId..")"
                            }
                            newFound = true
                        else
                            -- Auto-update informasi grade jika ada perubahan
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
        
        -- 2. Sapu bersih raid yang sudah mati/kadaluarsa dari memori game
        for rid, ent in pairs(RAID_LIVE) do
            if rid > 0 and not currentActiveIds[rid] then
                RAID_LIVE[rid] = nil
                newFound = true
            end
        end
        
        -- 3. Jika ada perubahan, refresh UI dan lapor ke bot
        if newFound then
            RebuildRaidList()
            -- [v58] Gunakan debounce terpusat
            if TriggerEntryWakeup then TriggerEntryWakeup() end
            -- [v_FIX] Ganti TriggerWebhookDebounce (no-op)
            if not _whSilent and _webhookEnabled and _webhookUrl and _webhookUrl ~= "" then
             for _, ent in pairs(RAID_LIVE) do
              if ent.label and ent.label ~= "" and _WH and _WH.AddLine then
               if ent.isAscension then
                local mn = ent.mapId and (ent.mapId - 50300) or "?"
                _WH.AddLine("The MaFissure appeared in Ascension Tower "..tostring(mn).." ["..(ent.grade or "?").."]")
               else
                local mn = ent.mapId and (ent.mapId - 50000) or "?"
                local nm = MAP_NAMES and MAP_NAMES[mn] or ("Map "..tostring(mn))
                _WH.AddLine("The MaFissure appeared in "..tostring(mn)..","..nm.." ["..(ent.grade or "?").."]")
               end
              end
             end
            end
        end
    end)
end

-- [NEW] Pasang radar global berjalan otomatis setiap 1.5 detik.
-- UI daftar Raid akan selalu penuh ter-update meski kamu sedang AFK di Lobby!
task.spawn(function()
    while task.wait(1.5) do
        ForceRescanRaidEnter()
    end
end)

-- Main loop
-- [v200] REWRITE: Flow final MA+AutoRaid
-- 
-- Range mapId:
-- Lobby : 50001-50018 (normal) | 50001-50028 (incl AT)
-- Normal : 50101-50118 (area raid)
-- Siege : 50201-50204 (BUKAN raid, skip total)
--
-- NORMAL mode (Default/Easy/Hard/ByMap/ByRank/Manual):
-- STEP1 : Workspace watcher RaidEnter -> RAID_LIVE (instant)
-- STEP2 : CreateRaidTeam(raidId) ->
-- StartChallengeRaidMap:FireServer({mapId})
-- mapId = lobby+100 (50101-50118)
-- pilihan berdasar Default/Easy=terkecil, Hard=terbesar, ByMap/Manual=preferMaps
-- STEP3 : Tunggu masuk map (workspace mapId / enemy, max 10s)
-- STEP4 : Diam 5s -> cari boss -> TP player+hero -> serang (ClickEnemy+HeroUseSkill 1-3)
-- STEP5 : Boss mati -> collect -> hide reward -> TP ke MR.lastMapId
-- STEP6 : _raidInterrupt=false -> MA resume -> cooldown 10s
--
-- RUNE MAP mode:
-- STEP2 : CreateRaidTeam(raidId) -> UseRaidItem(10265-10282) ->
-- tunggu LocalPlayerTeleportSuccess (server handle TP)
-- STEP4-6: sama seperti Normal
-- 
local function IsRaidLiveInGame()
 -- Cukup cek RAID_ID_LIST ada entry (workspace ChildRemoved handle expire)
 -- Entry _tempEntry (belum ada raidId asli) tetap dianggap valid
 -- karena workspace sudah konfirmasi raid ada
 return #RAID_ID_LIST > 0
end

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
 -- Dungeon (priority tertinggi) -> ST2/Tower -> Siege -> baru Raid boleh jalan
 if MODE.current == "dungeon" or (DUNGEON and DUNGEON.interrupt) then
 RAID.inMap = false
 RaidStatusUpdate("[||] Dungeon aktif - menunggu...", Color3.fromRGB(255,140,0))
 while (MODE.current == "dungeon" or (DUNGEON and DUNGEON.interrupt)) and RAID.running do
 task.wait(0.5)
 end
 if not RAID.running then break end
 RaidStatusUpdate("> Dungeon selesai - lanjut raid...", C.ACC3)
 task.wait(0.1)
 end

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
local function ResolveEntry()
                if #RAID_ID_LIST == 0 then return nil end
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
                    RAID.manualMatchMode = "fallback"
                    table.sort(valid_raids, function(a, b) return a.mapId < b.mapId end)
                    return valid_raids[1]
                end

                local function pickByDiff(list)
                    if #list == 0 then return nil end
                    if pm == "easy" then
                        table.sort(list, function(a, b) return a.mapId < b.mapId end)
                        return list[1]
                    elseif pm == "hard" then
                        table.sort(list, function(a, b) return a.mapId > b.mapId end)
                        return list[1]
                    elseif pm == "default" then
                        local maps1to8 = {}
                        for _, r in ipairs(list) do
                            local mn = r.mapId - 50000
                            if mn >= 1 and mn <= 8 then table.insert(maps1to8, r) end
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
 if (SIEGE and (SIEGE.inMap or SIEGE.teleporting)) or (DUNGEON and DUNGEON.inMap) then
     RaidStatusUpdate("[!] PAUSE: Menunggu Siege/Dungeon Selesai...", Color3.fromRGB(255, 100, 100))
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
 if (currentWm >= 50201 and currentWm <= 50204) or currentWm == 50303 then
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
 _raidInterrupt = true -- sync flag lama

 -- [v52 FIX] Atomic lock: cegah ASC masuk bersamaan saat RAID baru lolos guard
 -- Tanpa lock ini: RAID dan ASC bisa lolos guard hampir bersamaan karena Lua coroutine
 -- yield di task.wait(), sehingga keduanya lihat inMap=false dan keduanya lanjut
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

                    if MA.running then
                        local _wma = 0
                        while MA.running and _raidInterrupt and _wma < 1 do task.wait(0.05); _wma = _wma + 0.05 end
                    end
                    
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
                        local dir = RAID.updownDir or "up"
                        local udId = (dir == "up") and 10270 or 10271
                        
                        -- Cuma pencet 1x, tidak perlu maksa spam!
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
 while not _tpOk and _tpWait < 10 and RAID.running do
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
 task.wait(0.1)
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

 -- 
 -- STEP 4: Di dalam raid - cari boss, TP, serang
 -- 
 RAID._raidDone = false
 local _raidSuccess = false

 local connS, connF
 -- [BUG FIX 1&2] _raidDone hanya diset SETELAH attack loop selesai.
 -- ChallengeRaidsSuccess tidak boleh interrupt attack di tengah jalan.
 -- _raidServerDone = flag bahwa server sudah bilang sukses (tapi attack tetap jalan sampai boss mati)
 local _raidServerDone = false
 local _reS = Remotes:FindFirstChild("ChallengeRaidsSuccess")
 local _reF = Remotes:FindFirstChild("ChallengeRaidsFail")
 if _reS then connS = _reS.OnClientEvent:Connect(function()
 _raidServerDone = true; _raidSuccess = true
 end) end
 if _reF then connF = _reF.OnClientEvent:Connect(function()
 RAID._raidDone = true -- fail: langsung keluar
 end) end

 -- [v62 FIX] Loading wait: tunggu sampai minimal ada 1 enemy di workspace ATAU boss early detect
 -- Ini mencegah script menyerang map kosong (musuh belum spawn dari server)
 RaidStatusUpdate("[..] Enter Map - loading...", Color3.fromRGB(160,148,135))
 local _loadWait = 0
 local _earlyBoss = nil
 local _mapHasEnemies = false

 -- Definisi BOSS_KEYS lebih awal agar bisa dipakai di early detection juga
 local BOSS_KEYS_EARLY = {
 "goblin king","giant arachnid","buryura","igris",
 "leader of the polar","arch lich","kargalgan","baran",
 "beru","grendal","monarch plague","frostborne","legia",
 "monarch beastly","beastly fangs","silas","unbreakable monarch",
 "yogumunt","monarch of transfiguration","transfiguration",
 "antares","ashborn","dominion","absolute","monarch","fragment","boss",
 "legendary super saiyan","broly",
 "goku[super4]","goku super4","goku super 4",
 }
 local function IsBossEarly(name)
 local n = name:lower()
 for _, k in ipairs(BOSS_KEYS_EARLY) do if n:find(k,1,true) then return true end end
 return false
 end

 -- [FIX Ascension] Ambil hint bossName dari raidEntry sedini mungkin untuk early detect
 local _earlyAscHint = (raidEntry and raidEntry.isAscension and raidEntry.bossName) or nil
 local function IsBossEarlyWithHint(name)
  local n = name:lower()
  if _earlyAscHint and n:find(_earlyAscHint, 1, true) then return true end
  return IsBossEarly(name)
 end

 while _loadWait < 12 and RAID.running and not RAID._raidDone do
      task.wait(0.5); _loadWait = _loadWait + 0.5
      -- Cek apakah sudah ada enemy di workspace (map sudah populated)
      local _bList = GetRaidEnemies()
      if #_bList == 0 then _bList = GetEnemiesLocal() end
      if #_bList > 0 then _mapHasEnemies = true end
      if _loadWait >= 1 and not _earlyBoss and _mapHasEnemies then
       for _, e in ipairs(_bList) do
   if IsBossEarlyWithHint(e.model.Name) then
    _earlyBoss = e; break
   end
  end
 end
 -- Break jika boss sudah ada dan posisi valid
 if _earlyBoss then
  local _ep = _earlyBoss.hrp and _earlyBoss.hrp.Parent and _earlyBoss.hrp.Position
  if _ep and _ep.Y > -200 and _ep.Magnitude > 1 and _loadWait >= 1.5 then
   break
  end
  if _ep and (_ep.Y <= -200 or _ep.Magnitude <= 1) then
   _earlyBoss = nil
  end
 end
 -- [v62 FIX] Break awal jika enemies sudah ada (min 2s loading) - tidak perlu tunggu boss untuk mode tanpa autoKillBoss
 if _mapHasEnemies and _loadWait >= 2 and not RAID.autoKillBoss then break end
 end

 if RAID.running and not RAID._raidDone and RAID.autoKillBoss then
 local BOSS_KEYS = {
 "goblin king","giant arachnid","buryura","igris",
 "leader of the polar","arch lich","kargalgan","baran",
 "beru","grendal","monarch plague","frostborne","legia",
 "monarch beastly","beastly fangs","silas","unbreakable monarch",
 "yogumunt","monarch of transfiguration","transfiguration",
 "antares","ashborn","dominion","absolute","monarch","fragment","boss",
 -- Map 19 Dragon Ball City
 "legendary super saiyan","broly",
 -- Goku Super Saiyan 4
 "goku[super4]","goku super4","goku super 4",
 }
 local function IsBoss(name)
 local n = name:lower()
 for _, k in ipairs(BOSS_KEYS) do if n:find(k,1,true) then return true end end
 return false
 end

 -- [FIX Ascension] Ambil bossName hint dari raidEntry jika Ascension Tower
 -- Nama boss sudah diketahui dari teks notifikasi -> pakai sebagai filter prioritas tertinggi
 local _ascHintName = nil
 if raidEntry and raidEntry.isAscension and raidEntry.bossName then
  _ascHintName = raidEntry.bossName -- lowercase, misal "frostborne"
 end

 -- Helper IsBoss yang sadar Ascension hint
 local function IsBossWithHint(name)
  local n = name:lower()
  -- Jika ada hint nama boss Ascension, prioritaskan kecocokan tepat
  if _ascHintName then
   if n:find(_ascHintName, 1, true) then return true end
  end
  return IsBoss(name)
 end

 -- Pakai boss dari early detection kalau sudah ada DAN valid
 local boss = (_earlyBoss and IsBossWithHint(_earlyBoss.model.Name)) and _earlyBoss or nil
 -- Juga retry dengan IsBossWithHint jika early boss ditolak IsBoss tapi cocok dengan hint
 if not boss and _earlyBoss and _ascHintName then
  local n = _earlyBoss.model.Name:lower()
  if n:find(_ascHintName, 1, true) then boss = _earlyBoss end
 end

 -- [GODMODE FIX] Tingkatkan timeout: 15s -> 30s, scan lebih agresif tiap 0.3s
 -- Tambah retry: jika folder kosong, tunggu folder muncul via ChildAdded
 local waitBoss = 0
 local _bossFoundViaEvent = false

 -- [GODMODE FIX] Listen ChildAdded di semua folder enemy agar deteksi instan
 local _bossEventConns = {}
 local function _tryAddBossFromObj(obj)
 if boss or not obj:IsA("Model") then return end
 if IsBossWithHint(obj.Name) then
 local g = obj:GetAttribute("EnemyGuid") or obj:GetAttribute("BossGuid") or obj:GetAttribute("Guid") or obj:GetAttribute("GUID")
 local hrp = obj:FindFirstChild("HumanoidRootPart")
       or obj.PrimaryPart
       or obj:FindFirstChild("Torso")
       or obj:FindFirstChild("UpperTorso")
       or obj:FindFirstChildWhichIsA("BasePart")
 local hum = obj:FindFirstChildOfClass("Humanoid")
 if g and hrp and hum and hum.Health > 0 then
 boss = {guid=g, hrp=hrp, model=obj}
 _bossFoundViaEvent = true
 end
 end
 end
 for _, fname in ipairs({"Bosses","Boss","RaidBoss","Enemys","Enemy","Enemies","RaidEnemys","Monsters"}) do
 local folder = workspace:FindFirstChild(fname)
 if folder then
 table.insert(_bossEventConns, folder.ChildAdded:Connect(_tryAddBossFromObj))
 end
 end
 -- Juga listen workspace ChildAdded untuk folder baru
 table.insert(_bossEventConns, workspace.ChildAdded:Connect(function(obj)
 if obj:IsA("Folder") or obj:IsA("Model") then
 -- Coba langsung
 _tryAddBossFromObj(obj)
 -- Kalau folder, pantau isinya
 pcall(function()
 table.insert(_bossEventConns, obj.ChildAdded:Connect(_tryAddBossFromObj))
 for _, child in ipairs(obj:GetChildren()) do _tryAddBossFromObj(child) end
 end)
 end
 end))

 while RAID.running and not boss and waitBoss < 5 and not RAID._raidDone do
 for _, e in ipairs(GetRaidEnemies()) do
 if IsBossWithHint(e.model.Name) then boss = e; break end
 end
 if not boss then
 RaidStatusUpdate("Find Boss... (" .. math.floor(waitBoss) .. "s/5s)", Color3.fromRGB(160,148,135))
 task.wait(0.3); waitBoss = waitBoss + 0.3
 end
 end

 -- Lepaskan semua event listener boss
 for _, c in ipairs(_bossEventConns) do pcall(function() c:Disconnect() end) end
 _bossEventConns = {}

 if boss and RAID.running and not RAID._raidDone then
 local bossGuid = boss.guid
 -- [FIX] Validasi bossPos - cegah TP ke 0,0,0 atau jurang/void
 local function GetSafeBossPos()
 if boss.hrp and boss.hrp.Parent then
 local p = boss.hrp.Position
 if p.Y > -200 then return p end
 end
 return nil
 end
 local bossPos = GetSafeBossPos()
 if not bossPos then
 local _waitPos = 0
 while not bossPos and _waitPos < 3 and RAID.running and not RAID._raidDone do
 task.wait(0.3); _waitPos = _waitPos + 0.3
 bossPos = GetSafeBossPos()
 end
 end
 if not bossPos then
 RaidStatusUpdate("[!] Boss pos tidak valid - skip TP boss", Color3.fromRGB(255,80,80))
 end
 -- [v259] Teleport delay user-controlled (RAID.bossDelay 1-10s)
 local _bd = math.max(1, math.min(10, RAID.bossDelay or 3))
 for _ci = _bd, 1, -1 do
  if not RAID.running or RAID._raidDone then break end
  RaidStatusUpdate("[K] Boss: "..boss.model.Name.." - TP ".._ci.."s...", Color3.fromRGB(255,160,60))
  task.wait(1)
 end
 -- [FIX] Refresh bossPos SETELAH countdown - posisi boss saat countdown mungkin belum stabil
 -- Boss yang baru spawn butuh beberapa detik sebelum posisinya final di terrain
 local _refreshWait = 0
 bossPos = GetSafeBossPos()
 while not bossPos and _refreshWait < 3 and RAID.running and not RAID._raidDone do
  task.wait(0.3); _refreshWait = _refreshWait + 0.3
  bossPos = GetSafeBossPos()
 end
 -- Validasi tambahan: pastikan posisi Y cukup tinggi (bukan void/jurang)
 if bossPos and bossPos.Y < -100 then
  RaidStatusUpdate("[!] Posisi boss terlalu rendah - tunggu stabilisasi...", Color3.fromRGB(255,160,60))
  task.wait(1)
  bossPos = GetSafeBossPos()
 end
 if RAID.running and not RAID._raidDone and bossPos then
 RaidStatusUpdate("[K] Boss: " .. boss.model.Name .. " - Attack!", Color3.fromRGB(255,80,80))

 -- 
 -- [v256] TP PLAYER + SEMUA HERO KE BOSS BARENG
 -- Tidak ada jeda - langsung TP semua sekaligus
 -- 

 -- 1) TP Player ke boss SEKARANG
 pcall(function()
 local char = LP.Character
 local hrp = char and char:FindFirstChild("HumanoidRootPart")
 -- [FIX] Hanya teleport jika Y valid (bukan void/jurang)
 local safePos = GetSafeBossPos()
 if hrp and safePos then hrp.CFrame = CFrame.new(safePos + Vector3.new(3,0,0)) end
 end)

 -- 2) TP SEMUA hero client-side ke boss SEKARANG
 pcall(function()
 local safePos2 = GetSafeBossPos()
 if not safePos2 then return end
 local heroFolder = workspace:FindFirstChild("Heros")
 if heroFolder then
 for _, hModel in ipairs(heroFolder:GetChildren()) do
 local hHrp = hModel:FindFirstChild("HumanoidRootPart")
 if hHrp then
 hHrp.CFrame = CFrame.new(safePos2 + Vector3.new(math.random(-2,2), 0, math.random(-2,2)))
 end
 end
 end
 end)

 -- 3) Fire SEMUA hero remote ke boss SEKARANG
 pcall(function()
 local safePos3 = GetSafeBossPos()
 if safePos3 then FireHeroRemotes(bossGuid, safePos3) end
 end)
 if RE.HeroStand and #HERO_GUIDS > 0 then
 local safePos3b = GetSafeBossPos()
 if safePos3b then
 for _, hGuid in ipairs(HERO_GUIDS) do
 pcall(function()
 RE.HeroStand:FireServer({
 heroGuid = hGuid,
 userId = MY_USER_ID,
 standPos = safePos3b + Vector3.new(1, 0, 1),
 })
 end)
 end
 end
 end

 -- 4) UnEquip -> EquipBest (refresh hero di posisi boss)
 task.wait(0.3)
 if RE.UnEquipHero then
 pcall(function() RE.UnEquipHero:FireServer() end)
 end
 task.wait(0.3)
 if RE.EquipBestHero then
 pcall(function() RE.EquipBestHero:FireServer() end)
 end
 task.wait(0.3)

 -- 5) TP ulang semua hero setelah re-equip (hero spawn ulang di posisi baru)
 pcall(function()
 local safePos5 = GetSafeBossPos()
 if not safePos5 then return end
 local heroFolder = workspace:FindFirstChild("Heros")
 if heroFolder then
 for _, hModel in ipairs(heroFolder:GetChildren()) do
 local hHrp = hModel:FindFirstChild("HumanoidRootPart")
 if hHrp then
 hHrp.CFrame = CFrame.new(safePos5 + Vector3.new(math.random(-2,2), 0, math.random(-2,2)))
 end
 end
 end
 end)
 pcall(function()
 local safePos5b = GetSafeBossPos()
 if safePos5b then FireHeroRemotes(bossGuid, safePos5b) end
 end)

 -- 6) Background thread: TP player+hero terus ke boss tiap 0.5s
 local _tpTh = task.spawn(function()
 while RAID.running and not RAID._raidDone do
 -- [FIX GODMODE] Stop TP jika player sudah keluar dari raid map
 local _tpMap = GetCurrentMapId()
 if _tpMap and (_tpMap < 50101 or _tpMap > 50120) then break end
 pcall(function()
 -- [FIX] Selalu ambil posisi live dari boss.hrp, validasi Y sebelum TP
 -- Jangan pernah fallback ke bossPos lama yang mungkin sudah tidak valid
 local pos = GetSafeBossPos()
 if not pos then return end -- skip frame ini jika posisi tidak valid
 -- TP player
 local char = LP.Character
 local hrp = char and char:FindFirstChild("HumanoidRootPart")
 if hrp then hrp.CFrame = CFrame.new(pos + Vector3.new(3,0,0)) end
 -- TP semua hero
 local heroFolder = workspace:FindFirstChild("Heros")
 if heroFolder then
 for _, hModel in ipairs(heroFolder:GetChildren()) do
 local hHrp = hModel:FindFirstChild("HumanoidRootPart")
 if hHrp then
 hHrp.CFrame = CFrame.new(pos + Vector3.new(math.random(-2,2), 0, math.random(-2,2)))
 end
 end
 end
 -- Fire hero remotes
 FireHeroRemotes(bossGuid, pos)
 if RE.HeroStand then
 for _, hGuid in ipairs(HERO_GUIDS) do
 pcall(function()
 RE.HeroStand:FireServer({
 heroGuid = hGuid,
 userId = MY_USER_ID,
 standPos = pos + Vector3.new(1, 0, 1),
 })
 end)
 end
 end
 end)
 task.wait(0.5)
 end
 end)

 -- 7) SERANG BOSS - langsung tanpa jeda
 RaidStatusUpdate("[FLa] Attack: " .. boss.model.Name, Color3.fromRGB(255,80,80))
 local _outOfMapCount = 0
 while RAID.running do
 -- Stop jika server sudah konfirmasi sukses
 if _raidServerDone then break end
 local _curMap = GetCurrentMapId()
 if _curMap and (_curMap < 50101 or _curMap > 50120) then
  _outOfMapCount = _outOfMapCount + 1
  if _outOfMapCount >= 3 then
   RaidStatusUpdate("[!] Player keluar raid map - stop attack boss", Color3.fromRGB(255,140,0))
   break
  end
 else
  _outOfMapCount = 0
 end
 -- Boss model hilang dari workspace = mati
 if not boss.model or not boss.model.Parent then break end
 local hum = boss.model:FindFirstChildOfClass("Humanoid")
 -- HP <= 0 atau Humanoid hilang = boss mati
 if not hum or hum.Health <= 0 then break end
 local p = GetSafeBossPos()
 -- Jika posisi boss tidak valid tapi boss masih ada: coba maksimal 2 detik, setelah itu anggap mati
 if not p then
  task.wait(0.08)
  -- Cek lagi apakah boss masih ada
  if not boss.model or not boss.model.Parent then break end
  local hum2 = boss.model:FindFirstChildOfClass("Humanoid")
  if not hum2 or hum2.Health <= 0 then break end
  continue
 end
 task.spawn(function() pcall(function() RaidFireDamage(bossGuid, p) end) end)
 task.wait(0.08)
 end

 pcall(function() task.cancel(_tpTh) end)
 -- Boss mati (apapun yang menyebabkan break dari attack loop).
 -- _raidSuccess = true selalu setelah attack loop selesai dari dalam map.
 _raidSuccess = true
 if _raidServerDone then _raidSuccess = true end -- preserve
 RAID._raidDone = true
 RaidStatusUpdate("[FLa] Boss Dead!", Color3.fromRGB(100,255,150))
 end -- if RAID.running after delay
 else
 -- [GODMODE FIX] Boss tidak ditemukan setelah 30s - coba sekali lagi scan penuh workspace sebelum menyerah
 local _lastChance = nil
 pcall(function()
 for _, obj in ipairs(workspace:GetDescendants()) do
 if obj:IsA("Model") and IsBossWithHint(obj.Name) then
 local g = obj:GetAttribute("EnemyGuid") or obj:GetAttribute("BossGuid") or obj:GetAttribute("Guid") or obj:GetAttribute("GUID")
 local hrp = obj:FindFirstChild("HumanoidRootPart")
 local hum = obj:FindFirstChildOfClass("Humanoid")
 if g and hrp and hum and hum.Health > 0 then
 _lastChance = {guid=g, hrp=hrp, model=obj}; break
 end
 end
 end
 end)
 if _lastChance and RAID.running and not RAID._raidDone then
 -- Dapat dari last chance scan, set boss dan lanjut ke serangan
 boss = _lastChance
 RaidStatusUpdate("[!] Boss found (last chance): " .. boss.model.Name, Color3.fromRGB(255,200,50))
 end
 -- Jika masih tidak ada boss setelah last chance, keluar
 if not boss and RAID.running then
 RaidStatusUpdate("[FLa] Boss not found (30s) - Go Out...", Color3.fromRGB(255,150,50))
 task.wait(3)
 end
 end -- if boss
 elseif RAID.running and not RAID._raidDone then
 -- Auto Kill Boss OFF - tunggu event ChallengeRaidsSuccess max 5 menit
 local _wt = 0
 while RAID.running and not RAID._raidDone and _wt < 300 do
 task.wait(1); _wt = _wt + 1
 end
 end

 if connS then pcall(function() connS:Disconnect() end) end
 if connF then pcall(function() connF:Disconnect() end) end

 if _raidSuccess then
 RAID.sukses = RAID.sukses + 1
 RaidCounterUpdate()
 RaidStatusUpdate("[OK] Succes-" .. RAID.sukses .. " Map " .. mn, Color3.fromRGB(100,255,150))
 end
 if not RAID.running then break end

 -- 
 if _raidSuccess then
  RaidStatusUpdate("[..] Wait 1s (Get reward)...", Color3.fromRGB(100,255,150))
  task.wait(1)
 end
 if not RAID.running then break end

 -- STEP 5: Collect + Exit raid
 -- 
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
 ok = (wm >= 50101 and wm <= 50118)
 end
 end)
 return ok
 end

 if true then -- [INDEPENDEN] tidak cek siege
 -- Kirim QuitRaidsMap + TpRemote berlapis
 local _quitRe = Remotes:FindFirstChild("QuitRaidsMap")
 if _quitRe then
 pcall(function()
 _quitRe:FireServer({ currentSlotIndex = RAID.slotIndex or 2, toMapId = _toMapId })
 end)
 end
 task.wait(0.3)
 _fireTpRaid(_toMapId)

 -- Retry max 5x kalau masih di raid area
 local _exitTry = 0
 while _inRaidArea() and _exitTry < 5 and RAID.running do
 _exitTry = _exitTry + 1
 task.wait(1)
 if _quitRe then
 pcall(function()
 _quitRe:FireServer({ currentSlotIndex = RAID.slotIndex or 2, toMapId = _toMapId })
 end)
 end
 task.wait(0.2)
 _fireTpRaid(_toMapId)
 end
 end

 RAID.fromMapId = nil
 RAID.inMap = false

 -- 
 -- STEP 6: Resume MA -> cooldown
 -- 
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
            if (SIEGE and (SIEGE.inMap or SIEGE.teleporting)) or (DUNGEON and DUNGEON.inMap) then
                isBusy = true
            end
            local mapId = workspace:GetAttribute("MapId") or 0
            if (mapId >= 50201 and mapId <= 50204) or mapId == 50303 then
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

-- 

-- ============================================================
-- do (webhook + raid logic)

-- ============================================================

-- ============================================================
-- PANEL : AUTOMATION - Auto Raid UI [v259 REWRITE]
-- ============================================================
do
 local p = NewPanel("autoraid")
 SectionHeader(p,"Automation",0)

 -- 
 -- DROPDOWN: AUTO RAID [v262 REWRITE]
 -- 
 local raidOpen = false

 local raidHeader = Btn(p, C.SURFACE, UDim2.new(1,0,0,42))
 raidHeader.LayoutOrder=1; Corner(raidHeader,10); Stroke(raidHeader,C.ACC, 1.5,0.4)
 local raidArrow = Label(raidHeader,">",13,C.ACC2,Enum.Font.GothamBold)
 raidArrow.Size=UDim2.new(0,22,1,0); raidArrow.Position=UDim2.new(0,10,0,0)
 local raidHeaderLbl = Label(raidHeader,"Auto Raid",14,C.TXT,Enum.Font.GothamBold)
 raidHeaderLbl.Size=UDim2.new(1,-50,1,0); raidHeaderLbl.Position=UDim2.new(0,34,0,0)

 local raidBody = Frame(p, C.BG2, UDim2.new(1,0,0,0))
 raidBody.LayoutOrder=2; raidBody.ClipsDescendants=true
 Corner(raidBody,10); Stroke(raidBody,C.ACC, 1.5,0.25); raidBody.Visible=false

 local raidInner = Frame(raidBody, C.BLACK, UDim2.new(1,-16,0,0))
 raidInner.BackgroundTransparency=1; raidInner.Position=UDim2.new(0,8,0,8)
 local raidLayout = New("UIListLayout",{Parent=raidInner,SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,6)})

 function ResizeRaidBody()
 task.spawn(function()
 task.wait(0)
 raidLayout:ApplyLayout()
 local h = raidLayout.AbsoluteContentSize.Y + 16
 raidInner.Size = UDim2.new(1,0,0,h)
 raidBody.Size = UDim2.new(1,0,0,h+16)
 end)
 end

 raidHeader.MouseButton1Click:Connect(function()
 raidOpen = not raidOpen; raidBody.Visible = raidOpen
 raidArrow.Text = raidOpen and "v" or ">"
 if raidOpen then task.defer(ResizeRaidBody) end
 end)

 --  ICON GEMBOK HELPER 
 local LOCK_ICON = ""

 --  ROW 1: STATUS 
 local statusCard = Frame(raidInner, C.SURFACE, UDim2.new(1,0,0,38))
 statusCard.LayoutOrder=1; Corner(statusCard, 10); Stroke(statusCard,C.BORD, 1.5,0.3)
 Padding(statusCard,6,6,10,10)
 local _raidDot = Frame(statusCard, Color3.fromRGB(100,100,100), UDim2.new(0,9,0,9))
 _raidDot.AnchorPoint=Vector2.new(0,0.5); _raidDot.Position=UDim2.new(0,0,0.5,0); Corner(_raidDot,5)
 RAID.dot = _raidDot
 local _statusKeyL = Label(statusCard,"Status",11,C.TXT3,Enum.Font.GothamBold)
 _statusKeyL.Size=UDim2.new(0,54,1,0); _statusKeyL.Position=UDim2.new(0,16,0,0)
 local _raidStatusLbl = Label(statusCard,"Disabled",11,Color3.fromRGB(160,148,135),Enum.Font.GothamBold)
 _raidStatusLbl.Size=UDim2.new(1,-76,1,0); _raidStatusLbl.Position=UDim2.new(0,70,0,0)
 _raidStatusLbl.TextXAlignment=Enum.TextXAlignment.Right
 _raidStatusLbl.TextTruncate=Enum.TextTruncate.AtEnd
 RAID.statusLbl = _raidStatusLbl

 --  ROW 2: ACTIVE RAID 
 -- Hanya tampil saat RAID.inMap=true (sedang di dalam raid)
 local activeCard = Frame(raidInner, C.SURFACE, UDim2.new(1,0,0,38))
 activeCard.LayoutOrder=2; Corner(activeCard, 10); Stroke(activeCard,C.BORD, 1.5,0.3)
 Padding(activeCard,6,6,10,10)
 local _activeKeyL = Label(activeCard,"Active Raid",11,C.TXT3,Enum.Font.GothamBold)
 _activeKeyL.Size=UDim2.new(0,74,1,0)
 local _activeRaidLbl = Label(activeCard,"Waiting",11,C.TXT2,Enum.Font.GothamBold)
 _activeRaidLbl.Size=UDim2.new(1,-84,1,0); _activeRaidLbl.Position=UDim2.new(0,82,0,0)
 _activeRaidLbl.TextXAlignment=Enum.TextXAlignment.Right
 _activeRaidLbl.TextTruncate=Enum.TextTruncate.AtEnd
 RAID.activeRaidLbl = _activeRaidLbl

 -- [v262] Fungsi update Active Raid label - dipanggil langsung saat state berubah
 local function UpdateActiveRaidLabel()
 pcall(function()
 if not _activeRaidLbl or not _activeRaidLbl.Parent then return end
 if RAID.inMap and RAID.raidMapId then
 local rawMn = RAID.raidMapId - 50000
 -- Kalau Rune Map aktif, tampilkan map tujuan (bukan kendaraan)
 local mn = (RAID.runeEnabled and RAID.runeMapTarget >= 1 and RAID.runeMapTarget <= 20) and RAID.runeMapTarget or rawMn
 local nm = MAP_NAMES and MAP_NAMES[mn] or ("Map "..tostring(mn))
 local grade = (_runeGradeCache and _runeGradeCache[mn]) or ""
 local gs = grade ~= "" and grade ~= "?" and (" ["..grade.."]") or ""
 _activeRaidLbl.Text = "Map "..mn.." - "..nm..gs
 _activeRaidLbl.TextColor3 = Color3.fromRGB(100,220,180)
 else
 _activeRaidLbl.Text = "Waiting"
 _activeRaidLbl.TextColor3 = C.TXT3
 end
 end)
 end
 -- Expose agar bisa dipanggil dari luar blok UI
 RAID.updateActiveLabel = UpdateActiveRaidLabel

 -- Polling ringan 0.3s sebagai safety net (update utama via RAID.updateActiveLabel)
 task.spawn(function()
 while true do
 task.wait(0.3)
 UpdateActiveRaidLabel()
 end
 end)

 --  ROW 3: RAID COMPLETED 
 local completedCard = Frame(raidInner, C.SURFACE, UDim2.new(1,0,0,38))
 completedCard.LayoutOrder=3; Corner(completedCard, 10); Stroke(completedCard,C.BORD, 1.5,0.3)
 Padding(completedCard,6,6,10,10)
 local _compKeyL = Label(completedCard,"Raid Completed",11,C.TXT3,Enum.Font.GothamBold)
 _compKeyL.Size=UDim2.new(0.65,0,1,0)
 local _raidSuksesLbl = Label(completedCard,"0",11,Color3.fromRGB(110,231,183),Enum.Font.GothamBold)
 _raidSuksesLbl.Size=UDim2.new(0.35,0,1,0); _raidSuksesLbl.Position=UDim2.new(0.65,0,0,0)
 _raidSuksesLbl.TextXAlignment=Enum.TextXAlignment.Right
 RAID.suksesLbl = _raidSuksesLbl
 RAID.loopLbl = nil; RAID.killLbl = nil

 --  ROW 4: ENABLE AUTO RAID TOGGLE 
 local ctrlRow = Frame(raidInner, C.SURFACE, UDim2.new(1,0,0,44))
 ctrlRow.LayoutOrder=4; Corner(ctrlRow,10); Stroke(ctrlRow,C.ACC,1.5,0.2)
 local mL = Label(ctrlRow,"Enable Auto Raid",13,C.TXT,Enum.Font.GothamBold)
 mL.Size=UDim2.new(1,-68,0,20); mL.Position=UDim2.new(0,14,0.5,-10)
 local pill = Btn(ctrlRow,C.PILL_OFF,UDim2.new(0,52,0,30))
 pill.AnchorPoint=Vector2.new(1,0.5); pill.Position=UDim2.new(1,-12,0.5,0); Corner(pill,13)
 local knob = Frame(pill,C.KNOB_OFF,UDim2.new(0,24,0,24))
 knob.AnchorPoint=Vector2.new(0,0.5); knob.Position=UDim2.new(0,3,0.5,0); Corner(knob,10)
 pill.MouseButton1Click:Connect(function()
 _raidOn = not _raidOn
 TweenService:Create(pill,TweenInfo.new(0.16),{BackgroundColor3=_raidOn and C.PILL_ON or C.PILL_OFF}):Play()
 TweenService:Create(knob,TweenInfo.new(0.16),{
 Position=_raidOn and UDim2.new(1,-27,0.5,0) or UDim2.new(0,3,0.5,0),
 BackgroundColor3=_raidOn and C.KNOB_ON or C.KNOB_OFF,
 }):Play()
 if _raidOn then
 StartRaidLoop()
 else
 StopRaid()
 RaidStatusUpdate("Disabled",Color3.fromRGB(160,148,135))
 end
 end)

 --  PICK MODE 
 -- Default/By Rank/By Map/Hard/Easy/Manual
 local PM_OPTS = {"Default","By Rank","By Map","Hard","Easy","Manual"}
 local PM_KEYS = {"default","byrank","bymap","hard","easy","manual"}
 local PM_COLORS = {
 Color3.fromRGB(148,195,255), -- Default: biru es
 Color3.fromRGB(200,120,255), -- By Rank: ungu
 Color3.fromRGB(100,200,100), -- By Map: hijau
 Color3.fromRGB(255,80,80), -- Hard: merah
 Color3.fromRGB(80,220,80), -- Easy: hijau muda
 Color3.fromRGB(255,180,50), -- Manual: kuning
 }
 local PM_DESC = {
 "Join a random raid without filters",
 "Filter by preferred rank",
 "Filter by selected map",
 "Always choose the largest map",
 "Always choose the smallest map",
 "Manually set up your map, rank, and runes",
 }
 local PM_TO_DIFF = {
 default="easy", byrank="easy", bymap="easy",
 hard="hard", easy="easy", manual="easy"
 }
 -- Unlock rule per mode:
 -- mapUnlock : bymap, manual
 -- rankUnlock : byrank, manual
 -- runeUnlock : manual
 local PM_UNLOCK = {
 default = {map=false, rank=false, rune=false},
 byrank = {map=false, rank=true, rune=false},
 bymap = {map=true, rank=false, rune=false},
 hard = {map=false, rank=false, rune=false},
 easy = {map=false, rank=false, rune=false},
 manual = {map=true, rank=true, rune=true},
 }
 local curPM = 1
 RAID.pickMode = PM_KEYS[curPM]

 local pmHdr = Label(raidInner,"PICK MODE",10,C.TXT3,Enum.Font.GothamBold)
 pmHdr.LayoutOrder=5; pmHdr.Size=UDim2.new(1,0,0,14)
 local pmCard = Frame(raidInner,C.SURFACE,UDim2.new(1,0,0,40))
 pmCard.LayoutOrder=6; Corner(pmCard, 10); Stroke(pmCard,C.BORD, 1.5,0.3); Padding(pmCard,6,6,10,10)
 local _pmKeyL = Label(pmCard,"Pick Mode",11,C.TXT2,Enum.Font.GothamBold)
 _pmKeyL.Size=UDim2.new(0,72,1,0)
 local pmDDBtn = Btn(pmCard,C.BG3,UDim2.new(1,-82,0,28))
 pmDDBtn.Position=UDim2.new(0,80,0.5,-14); Corner(pmDDBtn,6); Stroke(pmDDBtn,C.BORD, 1.5,0.25)
 local pmDDLbl = Label(pmDDBtn," "..PM_OPTS[curPM],11,PM_COLORS[curPM],Enum.Font.GothamBold)
 pmDDLbl.Size=UDim2.new(1,-20,1,0)
 local pmArr = Label(pmDDBtn,"v",10,C.TXT3,Enum.Font.GothamBold,Enum.TextXAlignment.Center)
 pmArr.Size=UDim2.new(0,18,1,0); pmArr.Position=UDim2.new(1,-20,0,0)
 local pmDescLbl = Label(raidInner,PM_DESC[curPM],10,C.TXT3,Enum.Font.GothamBold)
 pmDescLbl.LayoutOrder=7; pmDescLbl.Size=UDim2.new(1,0,0,14)

 local ApplyPickModeLock -- forward declare
 local prefCard, rankCard, runeCard -- forward declare untuk lock function

 pmDDBtn.MouseButton1Click:Connect(function()
 CloseActiveDD()
 local aP=pmDDBtn.AbsolutePosition; local aS=pmDDBtn.AbsoluteSize; local IH=28
 local popup=Instance.new("Frame")
 popup.Parent=DDLayer; popup.BackgroundColor3=C.DD_BG; popup.BorderSizePixel=0
 popup.Size=UDim2.new(0,aS.X+10,0,#PM_OPTS*(IH+2)+12)
 popup.Position=UDim2.new(0,aP.X,0,aP.Y+aS.Y+3)
 popup.ZIndex=9999; Corner(popup, 10); Stroke(popup,C.BORD2, 1.5,0.85)
 local ll=Instance.new("UIListLayout",popup)
 ll.Padding=UDim.new(0,2); ll.SortOrder=Enum.SortOrder.LayoutOrder
 Instance.new("UIPadding",popup).PaddingTop=UDim.new(0,4)
 for i,opt in ipairs(PM_OPTS) do
 local item=Instance.new("TextButton",popup)
 item.Size=UDim2.new(1,-8,0,IH); item.LayoutOrder=i
 item.BackgroundColor3=i==curPM and C.SURFACE or C.BG3
 item.BackgroundTransparency=i==curPM and 0.18 or 0.42
 item.BorderSizePixel=0; item.Text=""; item.AutoButtonColor=false; item.ZIndex=9999
 Instance.new("UICorner",item).CornerRadius=UDim.new(0,6)
 local iL=Instance.new("TextLabel",item)
 iL.Size=UDim2.new(1,-8,1,0); iL.Position=UDim2.new(0,8,0,0)
 iL.BackgroundTransparency=1; iL.Text=opt; iL.TextSize=12
 iL.Font=Enum.Font.Gotham; iL.TextColor3=PM_COLORS[i]
 iL.TextXAlignment=Enum.TextXAlignment.Left; iL.ZIndex=9999
 local ii=i
 item.MouseButton1Click:Connect(function()
 CloseActiveDD()
 curPM=ii; RAID.pickMode=PM_KEYS[ii]
 RAID.difficulty=PM_TO_DIFF[PM_KEYS[ii]]; RAID.snapshotMapId=nil
 pmDDLbl.Text=" "..PM_OPTS[ii]; pmDDLbl.TextColor3=PM_COLORS[ii]
 pmDescLbl.Text=PM_DESC[ii]
 ApplyPickModeLock(); task.defer(ResizeRaidBody)
 end)
 end
 DDLayer.Visible=true
 _activeDDClose=function() popup:Destroy(); DDLayer.Visible=false end
 end)

-- PREFERRED MAPS
 local prefHdr=Label(raidInner,"PREFERRED MAPS",10,C.TXT3,Enum.Font.GothamBold)
 prefHdr.LayoutOrder=8; prefHdr.Size=UDim2.new(1,0,0,14)
 prefCard=Frame(raidInner,C.SURFACE,UDim2.new(1,0,0,40))
 prefCard.LayoutOrder=9; Corner(prefCard, 10); Stroke(prefCard,C.BORD, 1.5,0.3); Padding(prefCard,6,6,10,10)

 local prefRow=Frame(prefCard,C.BLACK,UDim2.new(1,0,1,0)); prefRow.BackgroundTransparency=1
 _prefLockLbl=Label(prefRow,"[x]",11,C.TXT3,Enum.Font.GothamBold)
 _prefLockLbl.Size=UDim2.new(0,20,1,0); _prefLockLbl.Visible=false
 _prefKeyL=Label(prefRow,"Select Map",11,C.TXT2,Enum.Font.GothamBold)
 _prefKeyL.Size=UDim2.new(0,72,1,0); _prefKeyL.Position=UDim2.new(0,20,0,0)

 local prefDDBtn=Btn(prefRow,C.BG3,UDim2.new(1,-102,1,0))
 prefDDBtn.Position=UDim2.new(0,92,0,0); Corner(prefDDBtn,6); Stroke(prefDDBtn,C.BORD, 1.5,0.25)
 local prefDDLbl=Label(prefDDBtn," -- SELECT MAP --",11,C.TXT3,Enum.Font.GothamBold)
 prefDDLbl.Size=UDim2.new(1,-20,1,0); prefDDLbl.TextTruncate=Enum.TextTruncate.AtEnd
 local prefArr=Label(prefDDBtn,"v",10,C.TXT3,Enum.Font.GothamBold,Enum.TextXAlignment.Center)
 prefArr.Size=UDim2.new(0,18,1,0); prefArr.Position=UDim2.new(1,-20,0,0)

 -- [PERBAIKAN 1: Default All Maps terpilih otomatis]
 if not next(RAID.preferMaps) then
     for mn=1, 20 do RAID.preferMaps[mn] = true end
 end

 local function UpdatePrefLabel()
    local n=0; for _ in pairs(RAID.preferMaps) do n=n+1 end
    if n==0 then
        prefDDLbl.Text=" -- SELECT MAP --"; prefDDLbl.TextColor3=C.TXT3
    else
        local ns={}
        for mn in pairs(RAID.preferMaps) do table.insert(ns,"Map "..mn) end
        table.sort(ns); prefDDLbl.Text=" "..table.concat(ns,", ")
        prefDDLbl.TextColor3=Color3.fromRGB(100,180,255)
    end
 end
 UpdatePrefLabel()

 prefDDBtn.MouseButton1Click:Connect(function()
    if _prefLocked then return end
    CloseActiveDD()
    local aP=prefDDBtn.AbsolutePosition; local aS=prefDDBtn.AbsoluteSize
    local IH=26
    local scrollH=math.min(18*(IH+2)+8,_isSmallScreen and 180 or 220)
    local HDR=32
    local popup=Instance.new("Frame")
    popup.Parent=DDLayer; popup.BackgroundColor3=C.DD_BG; popup.BorderSizePixel=0
    popup.Size=UDim2.new(0,aS.X+20,0,HDR+scrollH)
    popup.Position=UDim2.new(0,aP.X,0,aP.Y+aS.Y+3)
    popup.ZIndex=9999; popup.ClipsDescendants=true
    Corner(popup, 10); Stroke(popup,Color3.fromRGB(100,180,255),1,0.2)
    local hdr=Frame(popup,C.BG3,UDim2.new(1,0,0,HDR)); hdr.ZIndex=9999
    local cntL=Label(hdr,"0/20 Selected",10.5,Color3.fromRGB(100,180,255),Enum.Font.GothamBold)
    cntL.Size=UDim2.new(0.6,0,1,0); cntL.Position=UDim2.new(0,8,0,0); cntL.ZIndex=9999
    local clrB=Btn(hdr,Color3.fromRGB(120,30,30),UDim2.new(0,48,0,20))
    clrB.Position=UDim2.new(1,-54,0.5,-10); Corner(clrB,5); clrB.ZIndex=9999
    local clrL=Label(clrB,"Clear",10,Color3.fromRGB(255,255,255),Enum.Font.GothamBold,Enum.TextXAlignment.Center)
    clrL.Size=UDim2.new(1,0,1,0); clrL.ZIndex=9999
    local sf=Instance.new("ScrollingFrame"); sf.Parent=popup
    sf.BackgroundTransparency=1; sf.BorderSizePixel=0
    sf.Position=UDim2.new(0,0,0,HDR); sf.Size=UDim2.new(1,0,0,scrollH)
    sf.CanvasSize=UDim2.new(0,0,0,21*(IH+2)+8)
    sf.ScrollBarThickness=5; sf.ScrollBarImageColor3=Color3.fromRGB(100,180,255)
    sf.ZIndex=9999
    local sfl=Instance.new("UIListLayout",sf); sfl.SortOrder=Enum.SortOrder.LayoutOrder
    local sfp=Instance.new("UIPadding",sf)
    sfp.PaddingTop=UDim.new(0,4); sfp.PaddingLeft=UDim.new(0,4); sfp.PaddingRight=UDim.new(0,6)
    local rr={}
    local function UpdCnt()
        local n=0; for _ in pairs(RAID.preferMaps) do n=n+1 end
        cntL.Text=n.."/20 Selected"
    end
    for mn=1,20 do
        local it=Instance.new("TextButton",sf)
        it.Size=UDim2.new(1,-4,0,IH); it.LayoutOrder=mn
        it.BackgroundColor3=RAID.preferMaps[mn] and C.BORD or C.BG3
        it.BackgroundTransparency=0.25; it.BorderSizePixel=0
        it.Text=""; it.AutoButtonColor=false; it.ZIndex=9999
        Instance.new("UICorner",it).CornerRadius=UDim.new(0,5)
        local tk=Instance.new("TextLabel",it)
        tk.Size=UDim2.new(0,18,1,0); tk.BackgroundTransparency=1
        tk.Text=RAID.preferMaps[mn] and "[v]" or ""; tk.TextSize=13
        tk.Font=Enum.Font.GothamBold; tk.TextColor3=Color3.fromRGB(100,180,255); tk.ZIndex=9999
        local il=Instance.new("TextLabel",it)
        il.Size=UDim2.new(1,-24,1,0); il.Position=UDim2.new(0,20,0,0)
        il.BackgroundTransparency=1
        il.Text=" Map "..mn.." - "..(MAP_NAMES[mn] or "Map "..mn)
        il.TextSize=11; il.Font=Enum.Font.GothamBold
        il.TextColor3=RAID.preferMaps[mn] and Color3.fromRGB(100,180,255) or C.TXT
        il.TextXAlignment=Enum.TextXAlignment.Left; il.ZIndex=9999
        il.TextTruncate=Enum.TextTruncate.AtEnd
        rr[mn]={btn=it,tick=tk,lbl=il}
        local ml=mn
        it.MouseButton1Click:Connect(function()
            if RAID.preferMaps[ml] then RAID.preferMaps[ml]=nil else RAID.preferMaps[ml]=true end
            rr[ml].tick.Text=RAID.preferMaps[ml] and "[v]" or ""
            rr[ml].btn.BackgroundColor3=RAID.preferMaps[ml] and C.BORD or C.BG3
            rr[ml].lbl.TextColor3=RAID.preferMaps[ml] and Color3.fromRGB(100,180,255) or C.TXT
            UpdCnt(); UpdatePrefLabel()
        end)
    end
    UpdCnt()
    clrB.MouseButton1Click:Connect(function()
        for mn=1,20 do
            RAID.preferMaps[mn]=nil
            if rr[mn] then
                rr[mn].tick.Text=""
                rr[mn].btn.BackgroundColor3=C.BG3
                rr[mn].lbl.TextColor3=C.TXT
            end
        end
        UpdCnt(); UpdatePrefLabel()
    end)
    DDLayer.Visible=true
    _activeDDClose=function() popup:Destroy(); DDLayer.Visible=false end
 end)

 -- PREFERRED RANK
 local rankHdr=Label(raidInner,"PREFERRED RANK",10,C.TXT3,Enum.Font.GothamBold)
 rankHdr.LayoutOrder=10; rankHdr.Size=UDim2.new(1,0,0,14)
 local GRADE_COLORS_UI={
 ["E"]=Color3.fromRGB(150,150,150),["D"]=Color3.fromRGB(100,200,100),
 ["C"]=Color3.fromRGB(80,200,120), ["B"]=Color3.fromRGB(100,140,255),
 ["A"]=Color3.fromRGB(180,100,255),["S"]=Color3.fromRGB(255,180,50),
 ["SS"]=Color3.fromRGB(255,220,0), ["G"]=Color3.fromRGB(255,60,60),
 ["N"]=Color3.fromRGB(255,100,200),["M"]=Color3.fromRGB(255,0,0),
 ["M+"]=Color3.fromRGB(255,50,50), ["M++"]=Color3.fromRGB(255,100,100),
 ["XM"]=Color3.fromRGB(180,0,0),   ["ULT"]=Color3.fromRGB(255,255,255),
 }
 local GRADE_VALUE_UI = GRADE_RANK or {}

 rankCard=Frame(raidInner,C.SURFACE,UDim2.new(1,0,0,40))
 rankCard.LayoutOrder=11; Corner(rankCard, 10); Stroke(rankCard,C.BORD, 1.5,0.3); Padding(rankCard,6,6,10,10)
 local rankRow=Frame(rankCard,C.BLACK,UDim2.new(1,0,1,0)); rankRow.BackgroundTransparency=1
 _rankLockLbl=Label(rankRow,"[x]",11,C.TXT3,Enum.Font.GothamBold)
 _rankLockLbl.Size=UDim2.new(0,20,1,0); _rankLockLbl.Visible=false
 _rankKeyL=Label(rankRow,"Select Rank",11,C.TXT2,Enum.Font.GothamBold)
 _rankKeyL.Size=UDim2.new(0,72,1,0); _rankKeyL.Position=UDim2.new(0,20,0,0)
 local rankDDBtn=Btn(rankRow,C.BG3,UDim2.new(1,-102,1,0))
 rankDDBtn.Position=UDim2.new(0,92,0,0); Corner(rankDDBtn,6); Stroke(rankDDBtn,C.BORD, 1.5,0.25)
 local rankDDWrap=Frame(rankDDBtn,C.BLACK,UDim2.new(1,0,1,0)); rankDDWrap.BackgroundTransparency=1
 local rankDDVal=Label(rankDDWrap," -- SELECT RANK --",11,C.TXT3,Enum.Font.GothamBold)
 rankDDVal.Size=UDim2.new(1,-20,1,0); rankDDVal.TextTruncate=Enum.TextTruncate.AtEnd
 local rankDDArr=Label(rankDDWrap,"v",10,C.TXT3,Enum.Font.GothamBold,Enum.TextXAlignment.Center)
 rankDDArr.Size=UDim2.new(0,18,1,0); rankDDArr.Position=UDim2.new(1,-20,0,0)

 local function RefreshRankDDLabel()
    local ns={}
    for _,g in ipairs(GRADE_LIST) do
        if RAID.runeGrades[g] then table.insert(ns,"["..g.."]") end
    end
    if #ns==0 then
        rankDDVal.Text=" -- SELECT RANK --"; rankDDVal.TextColor3=C.TXT3
    else
        rankDDVal.Text=" "..table.concat(ns," ")
        rankDDVal.TextColor3=Color3.fromRGB(200,120,255)
    end
 end
 RefreshRankDDLabel()

 rankDDBtn.MouseButton1Click:Connect(function()
    if _rankLocked then return end
    CloseActiveDD()
    local IH=30
    local SFH=math.min(#GRADE_LIST*(IH+4)+44,280)
    local ab=rankDDWrap.AbsolutePosition; local sz=rankDDWrap.AbsoluteSize
    local cam=workspace.CurrentCamera
    local vpH=cam and cam.ViewportSize.Y or 800
    local goUp=(ab.Y+SFH+44 > vpH*0.85)
    local popup=Instance.new("Frame")
    popup.Parent=DDLayer; popup.BackgroundColor3=C.DD_BG; popup.BorderSizePixel=0
    popup.Size=UDim2.new(0,sz.X,0,SFH+8)
    if goUp then popup.Position=UDim2.new(0,ab.X,0,ab.Y-SFH-12)
    else popup.Position=UDim2.new(0,ab.X,0,ab.Y+sz.Y+4) end
    popup.ZIndex=9999; Corner(popup, 10); Stroke(popup,C.BORD, 1.5,0.3)
    local sf=Instance.new("ScrollingFrame",popup)
    sf.Size=UDim2.new(1,0,0,SFH); sf.BackgroundTransparency=1; sf.BorderSizePixel=0
    sf.ScrollBarThickness=4; sf.CanvasSize=UDim2.new(0,0,0,#GRADE_LIST*(IH+4)+44)
    sf.ZIndex=9999
    local sfp=Instance.new("UIPadding",sf)
    sfp.PaddingTop=UDim.new(0,4); sfp.PaddingBottom=UDim.new(0,4)
    sfp.PaddingLeft=UDim.new(0,4); sfp.PaddingRight=UDim.new(0,4)
    local sfLayout=Instance.new("UIListLayout",sf)
    sfLayout.SortOrder=Enum.SortOrder.LayoutOrder; sfLayout.Padding=UDim.new(0,4)
    
    local rb=Instance.new("TextButton",sf); rb.Size=UDim2.new(1,-8,0,IH); rb.LayoutOrder=0
    rb.BackgroundColor3=C.RED; rb.BackgroundTransparency=0.55; rb.BorderSizePixel=0
    rb.Text=""; rb.AutoButtonColor=false; rb.ZIndex=9999
    Instance.new("UICorner",rb).CornerRadius=UDim.new(0,6)
    local rl=Instance.new("TextLabel",rb)
    rl.Size=UDim2.new(1,-8,1,0); rl.Position=UDim2.new(0,8,0,0)
    rl.BackgroundTransparency=1; rl.Text="x Reset ALL"; rl.TextSize=10
    rl.Font=Enum.Font.GothamBold; rl.TextColor3=C.RED
    rl.TextXAlignment=Enum.TextXAlignment.Left; rl.ZIndex=9999
    rb.MouseButton1Click:Connect(function()
        for _,g in ipairs(GRADE_LIST) do RAID.runeGrades[g]=nil end
        CloseActiveDD(); RefreshRankDDLabel()
        if _raidWakeup then pcall(function() _raidWakeup:Fire() end) end
    end)
    
    for i,grade in ipairs(GRADE_LIST) do
        local gl=grade; local col=GRADE_COLORS_UI[grade] or C.ACC
        local gv=GRADE_VALUE_UI[grade] or "?"; local isSel=RAID.runeGrades[gl]==true
        local item=Instance.new("TextButton",sf)
        item.Size=UDim2.new(1,-8,0,IH); item.LayoutOrder=i
        item.BackgroundColor3=isSel and C.SURFACE or C.DD_BG
        item.BackgroundTransparency=isSel and 0.18 or 0.42
        item.BorderSizePixel=0; item.Text=""; item.AutoButtonColor=false; item.ZIndex=9999
        Instance.new("UICorner",item).CornerRadius=UDim.new(0,6)
        
        local ck=Instance.new("TextLabel",item)
        ck.Size=UDim2.new(0,20,1,0); ck.Position=UDim2.new(0,4,0,0)
        ck.BackgroundTransparency=1; ck.Text=isSel and "v" or ""; ck.TextSize=11
        ck.Font=Enum.Font.GothamBold; ck.TextColor3=col
        ck.TextXAlignment=Enum.TextXAlignment.Center; ck.ZIndex=9999
        
        local nl=Instance.new("TextLabel",item)
        nl.Size=UDim2.new(0,56,1,0); nl.Position=UDim2.new(0,26,0,0)
        nl.BackgroundTransparency=1; nl.Text="Rank "..grade; nl.TextSize=11
        nl.Font=Enum.Font.GothamBold
        nl.TextColor3=isSel and Color3.fromRGB(255,255,255) or col
        nl.TextXAlignment=Enum.TextXAlignment.Left; nl.ZIndex=9999
        
        local vl=Instance.new("TextLabel",item)
        vl.Size=UDim2.new(1,-86,1,0); vl.Position=UDim2.new(0,84,0,0)
        vl.BackgroundTransparency=1; vl.Text="Grade "..tostring(gv)
        vl.TextSize=9; vl.Font=Enum.Font.Gotham
        vl.TextColor3=isSel and C.TXT2 or C.TXT3
        vl.TextXAlignment=Enum.TextXAlignment.Left; vl.ZIndex=9999
        
        item.MouseButton1Click:Connect(function()
            -- [PERBAIKAN 2: Batas Max 3 Rank dicabut!]
            local ns = not RAID.runeGrades[gl]
            RAID.runeGrades[gl] = ns and true or nil
            
            item.BackgroundColor3 = ns and C.SURFACE or C.DD_BG
            item.BackgroundTransparency = ns and 0.18 or 0.42
            ck.Text = ns and "v" or ""
            nl.TextColor3 = ns and Color3.fromRGB(255,255,255) or col
            vl.TextColor3 = ns and C.TXT2 or C.TXT3
            RefreshRankDDLabel()
            if _raidWakeup then pcall(function() _raidWakeup:Fire() end) end
        end)
    end
    DDLayer.Visible=true
    _activeDDClose=function() popup:Destroy(); DDLayer.Visible=false end
 end)

 -- PREFERRED RUNE / ITEM
 local runeHdr=Label(raidInner,"PREFERRED RUNE (Item)",10,C.TXT3,Enum.Font.GothamBold)
 runeHdr.LayoutOrder=12; runeHdr.Size=UDim2.new(1,0,0,14)
 runeCard=Frame(raidInner,C.SURFACE,UDim2.new(1,0,0,40))
 runeCard.LayoutOrder=13; Corner(runeCard, 10); Stroke(runeCard,C.BORD, 1.5,0.3); Padding(runeCard,6,6,10,10)
 local runeRow=Frame(runeCard,C.BLACK,UDim2.new(1,0,1,0)); runeRow.BackgroundTransparency=1
 _runeLockLbl=Label(runeRow,"[x]",11,C.TXT3,Enum.Font.GothamBold)
 _runeLockLbl.Size=UDim2.new(0,20,1,0); _runeLockLbl.Visible=false
 _runeKeyL=Label(runeRow,"Auto Item",11,C.TXT2,Enum.Font.GothamBold)
 _runeKeyL.Size=UDim2.new(0,72,1,0); _runeKeyL.Position=UDim2.new(0,20,0,0)

 local runeDDBtn=Btn(runeRow,C.BG3,UDim2.new(1,-102,1,0))
 runeDDBtn.Position=UDim2.new(0,92,0,0); Corner(runeDDBtn,6); Stroke(runeDDBtn,C.BORD, 1.5,0.25)
 local runeDDVal=Label(runeDDBtn," -- NOT SELECTED --",11,C.TXT3,Enum.Font.GothamBold)
 runeDDVal.Size=UDim2.new(1,-20,1,0); runeDDVal.TextTruncate=Enum.TextTruncate.AtEnd
 local runeArr=Label(runeDDBtn,"v",10,C.TXT3,Enum.Font.GothamBold,Enum.TextXAlignment.Center)
 runeArr.Size=UDim2.new(0,18,1,0); runeArr.Position=UDim2.new(1,-20,0,0)

 local function SyncRuneState()
    if RAID.runeMapTarget >= 1 and RAID.runeMapTarget <= 20 then RAID.runeEnabled=true
    else RAID.runeEnabled=false end
 end
 SyncRuneState()
 if RAID.runeMapTarget >= 1 and RAID.runeMapTarget <= 20 then
    runeDDVal.Text=" Map "..RAID.runeMapTarget.." - "..(MAP_NAMES[RAID.runeMapTarget] or "")
    runeDDVal.TextColor3=C.ACC2
 end

 runeDDBtn.MouseButton1Click:Connect(function()
    if _runeLocked then return end
    CloseActiveDD()
    local aP=runeDDBtn.AbsolutePosition; local aS=runeDDBtn.AbsoluteSize
    local IH=28; local VI=8
    local cam=workspace.CurrentCamera
    local vpH=cam and cam.ViewportSize.Y or 800
    local popH=VI*(IH+2)+12
    local goUp=(aP.Y+popH > vpH*0.85)
    local popup=Instance.new("Frame")
    popup.Parent=DDLayer; popup.BackgroundColor3=C.DD_BG; popup.BorderSizePixel=0
    popup.Size=UDim2.new(0,aS.X+10,0,popH)
    if goUp then popup.Position=UDim2.new(0,aP.X,0,aP.Y-popH-4)
    else popup.Position=UDim2.new(0,aP.X,0,aP.Y+aS.Y+4) end
    popup.ZIndex=9999; popup.ClipsDescendants=true
    Corner(popup, 10); Stroke(popup,C.BORD2, 1.5,0.2)
    local sf=Instance.new("ScrollingFrame",popup)
    sf.Size=UDim2.new(1,0,1,0); sf.BackgroundTransparency=1; sf.BorderSizePixel=0
    sf.ScrollBarThickness=4; sf.ScrollBarImageColor3=C.ACC; sf.ZIndex=9999
    sf.CanvasSize=UDim2.new(0,0,0,21*(IH+2)+8)
    local sfl=Instance.new("UIListLayout",sf)
    sfl.Padding=UDim.new(0,2); sfl.SortOrder=Enum.SortOrder.LayoutOrder
    Instance.new("UIPadding",sf).PaddingTop=UDim.new(0,4)
    
    local i0=Instance.new("TextButton",sf)
    i0.Size=UDim2.new(1,-8,0,IH); i0.LayoutOrder=0
    local s0=(RAID.runeMapTarget==0)
    i0.BackgroundColor3=s0 and C.SURFACE or C.DD_BG
    i0.BackgroundTransparency=s0 and 0.18 or 0.42
    i0.BorderSizePixel=0; i0.Text=""; i0.AutoButtonColor=false; i0.ZIndex=9999
    Instance.new("UICorner",i0).CornerRadius=UDim.new(0,6)
    local l0=Instance.new("TextLabel",i0)
    l0.Size=UDim2.new(1,-8,1,0); l0.Position=UDim2.new(0,8,0,0)
    l0.BackgroundTransparency=1; l0.Text="-- NOT SELECTED --"; l0.TextSize=10
    l0.Font=Enum.Font.GothamBold; l0.TextColor3=s0 and C.ACC2 or C.TXT3
    l0.TextXAlignment=Enum.TextXAlignment.Left; l0.ZIndex=9999
    i0.MouseButton1Click:Connect(function()
        CloseActiveDD(); RAID.runeMapTarget=0; SyncRuneState()
        runeDDVal.Text=" -- NOT SELECTED --"; runeDDVal.TextColor3=C.TXT3
    end)
    
    for mn=1,20 do
        local ml=mn; local mnm=MAP_NAMES[mn] or ("Map "..mn)
        local it=Instance.new("TextButton",sf)
        it.Size=UDim2.new(1,-8,0,IH); it.LayoutOrder=mn
        local iS=(RAID.runeMapTarget==mn)
        it.BackgroundColor3=iS and C.SURFACE or C.DD_BG
        it.BackgroundTransparency=iS and 0.18 or 0.42
        it.BorderSizePixel=0; it.Text=""; it.AutoButtonColor=false; it.ZIndex=9999
        Instance.new("UICorner",it).CornerRadius=UDim.new(0,6)
        local il=Instance.new("TextLabel",it)
        il.Size=UDim2.new(1,-8,1,0); il.Position=UDim2.new(0,8,0,0)
        il.BackgroundTransparency=1
        il.Text="Map "..mn.." - "..mnm; il.TextSize=10; il.Font=Enum.Font.GothamBold
        il.TextColor3=iS and C.ACC2 or C.TXT
        il.TextXAlignment=Enum.TextXAlignment.Left; il.ZIndex=9999
        il.TextTruncate=Enum.TextTruncate.AtEnd
        it.MouseButton1Click:Connect(function()
            CloseActiveDD(); RAID.runeMapTarget=ml; SyncRuneState()
            runeDDVal.Text=" Map "..ml.." - "..mnm; runeDDVal.TextColor3=C.ACC2
        end)
    end
    DDLayer.Visible=true
    _activeDDClose=function() popup:Destroy(); DDLayer.Visible=false end
 end)

-- UP/DOWN RANK UI (LayoutOrder 14)
 local udHdr = Label(raidInner, "UP/DOWN RANK", 10, C.TXT3, Enum.Font.GothamBold)
 udHdr.LayoutOrder = 14; udHdr.Size = UDim2.new(1,0,0,14)

 local udCard = Frame(raidInner, C.SURFACE, UDim2.new(1,0,0,76))
 udCard.LayoutOrder = 15; Corner(udCard,10); Stroke(udCard,C.BORD, 1.5,0.3)
 
 local udRowTop = Frame(udCard, C.BLACK, UDim2.new(1,0,0,38))
 udRowTop.BackgroundTransparency = 1; udRowTop.Position = UDim2.new(0,0,0,0)
 
 local udPill = Btn(udRowTop, C.PILL_OFF, UDim2.new(0,52,0,30))
 udPill.AnchorPoint = Vector2.new(1,0.5); udPill.Position = UDim2.new(1,-12,0.5,0); Corner(udPill,13)
 local udKnob = Frame(udPill, C.KNOB_OFF, UDim2.new(0,24,0,24))
 udKnob.AnchorPoint = Vector2.new(0,0.5); udKnob.Position = UDim2.new(0,3,0.5,0); Corner(udKnob,10)
 
 local udLbl = Label(udRowTop, "UP/DOWN Rank", 14, C.TXT, Enum.Font.GothamBold)
 udLbl.Size = UDim2.new(0,110,0,20); udLbl.Position = UDim2.new(0,12,0.5,-10)

 local udRowBot = Frame(udCard, C.BLACK, UDim2.new(1,-24,0,30))
 udRowBot.BackgroundTransparency = 1; udRowBot.Position = UDim2.new(0,12,0,38)
 
 -- Dropdown Arah (UP/DOWN)
 if not RAID.updownDir then RAID.updownDir = "up" end
 local dirDDBtn = Btn(udRowBot, C.BG3, UDim2.new(0.45, -4, 1, -4))
 dirDDBtn.Position = UDim2.new(0,0,0,2); Corner(dirDDBtn,6); Stroke(dirDDBtn,C.BORD, 1.5,0.2)
 local dirDDLbl = Label(dirDDBtn, RAID.updownDir=="up" and " UP (UP)" or " DOWN (DN)", 11, C.ACC, Enum.Font.GothamBold)
 dirDDLbl.Size = UDim2.new(1,-16,1,0)
 local dirArr = Label(dirDDBtn,"v",10,C.TXT3,Enum.Font.GothamBold,Enum.TextXAlignment.Center)
 dirArr.Size = UDim2.new(0,16,1,0); dirArr.Position = UDim2.new(1,-16,0,0)
 
 -- Dropdown Target Grade
 local gradeDDBtn = Btn(udRowBot, C.BG3, UDim2.new(0.55, -4, 1, -4))
 gradeDDBtn.Position = UDim2.new(0.45,8,0,2); Corner(gradeDDBtn,6); Stroke(gradeDDBtn,C.BORD, 1.5,0.2)
 local gradeDDLbl = Label(gradeDDBtn, RAID.updownTargetGrade and (" Target: ["..RAID.updownTargetGrade.."]") or " -- SELECT TARGET --", 11, RAID.updownTargetGrade and C.ACC2 or C.TXT3, Enum.Font.GothamBold)
 gradeDDLbl.Size = UDim2.new(1,-16,1,0)
 local gradeArr = Label(gradeDDBtn,"v",10,C.TXT3,Enum.Font.GothamBold,Enum.TextXAlignment.Center)
 gradeArr.Size = UDim2.new(0,16,1,0); gradeArr.Position = UDim2.new(1,-16,0,0)

 -- FUNCTION TOGGLE
 local function updateUpDownToggle()
    local on = RAID.updownEnabled
    TweenService:Create(udPill,TweenInfo.new(0.18,Enum.EasingStyle.Quad),{BackgroundColor3=on and C.PILL_ON or C.PILL_OFF}):Play()
    TweenService:Create(udKnob,TweenInfo.new(0.16),{
        Position=on and UDim2.new(1,-27,0.5,0) or UDim2.new(0,3,0.5,0),
        BackgroundColor3=on and C.KNOB_ON or C.KNOB_OFF,
    }):Play()
 end
 updateUpDownToggle()

 udPill.MouseButton1Click:Connect(function()
    RAID.updownEnabled = not RAID.updownEnabled
    updateUpDownToggle()
 end)
 
 -- FUNCTION DIR DD
 dirDDBtn.MouseButton1Click:Connect(function()
    CloseActiveDD()
    local aP = dirDDBtn.AbsolutePosition; local aS = dirDDBtn.AbsoluteSize
    local IH = 32
    local popup = Instance.new("Frame")
    popup.Parent = DDLayer; popup.BackgroundColor3 = C.DD_BG; popup.BorderSizePixel = 0
    popup.Size = UDim2.new(0, aS.X+10, 0, IH*2+12)
    popup.Position = UDim2.new(0, aP.X-5, 0, aP.Y+aS.Y+4)
    popup.ZIndex = 9999; Corner(popup, 10); Stroke(popup,C.BORD2, 1.5,0.2)
    local sfL = Instance.new("UIListLayout",popup)
    sfL.Padding = UDim.new(0,2); sfL.SortOrder = Enum.SortOrder.LayoutOrder
    Instance.new("UIPadding",popup).PaddingTop = UDim.new(0,4)
    
    local opts = {
        {dir="up", label=" UP (UP)", col=Color3.fromRGB(100,220,100)},
        {dir="down", label=" DOWN (DN)", col=Color3.fromRGB(255,140,80)},
    }
    for i, opt in ipairs(opts) do
        local row = Instance.new("TextButton",popup)
        row.Size = UDim2.new(1,-8,0,IH); row.LayoutOrder = i
        local isSel = RAID.updownDir == opt.dir
        row.BackgroundColor3 = isSel and C.SURFACE or C.DD_BG
        row.BackgroundTransparency = isSel and 0.18 or 0.42
        row.BorderSizePixel = 0; row.Text = ""; row.AutoButtonColor = false; row.ZIndex = 9999
        Instance.new("UICorner",row).CornerRadius = UDim.new(0,6)
        local lbl = Instance.new("TextLabel",row)
        lbl.Size = UDim2.new(1,-8,1,0); lbl.Position = UDim2.new(0,8,0,0)
        lbl.BackgroundTransparency = 1; lbl.Text = opt.label; lbl.TextSize = 11
        lbl.Font = Enum.Font.GothamBold; lbl.TextColor3 = isSel and opt.col or C.TXT
        lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.ZIndex = 9999
        local d = opt.dir; local c2 = opt.col; local lb2 = opt.label
        row.MouseButton1Click:Connect(function()
            RAID.updownDir = d
            dirDDLbl.Text = lb2:sub(1,7)
            dirDDLbl.TextColor3 = c2
            CloseActiveDD()
        end)
    end
    DDLayer.Visible = true
    _activeDDClose = function() popup:Destroy(); DDLayer.Visible = false end
 end)

 -- FUNCTION GRADE DD
 gradeDDBtn.MouseButton1Click:Connect(function()
    CloseActiveDD()
    local aP = gradeDDBtn.AbsolutePosition; local aS = gradeDDBtn.AbsoluteSize
    local IH = 28
    local targetGrades = {}
    for i=6, #GRADE_LIST do table.insert(targetGrades, GRADE_LIST[i]) end
    
    local SFH = math.min((#targetGrades+1)*(IH+2)+8, 200)
    local popup = Instance.new("Frame")
    popup.Parent = DDLayer; popup.BackgroundColor3 = C.DD_BG; popup.BorderSizePixel = 0
    popup.Size = UDim2.new(0, aS.X+20, 0, SFH)
    popup.Position = UDim2.new(0, aP.X-10, 0, aP.Y-SFH-12)
    popup.ZIndex = 9999; Corner(popup, 10); Stroke(popup,C.BORD2, 1.5,0.2)
    local sf = Instance.new("ScrollingFrame", popup)
    sf.Size = UDim2.new(1,0,1,0); sf.BackgroundTransparency = 1; sf.BorderSizePixel = 0
    sf.ScrollBarThickness = 4; sf.CanvasSize = UDim2.new(0,0,0,(#targetGrades+1)*(IH+2)+8)
    local sfL = Instance.new("UIListLayout",sf)
    sfL.Padding = UDim.new(0,2); sfL.SortOrder = Enum.SortOrder.LayoutOrder
    Instance.new("UIPadding",sf).PaddingTop = UDim.new(0,4)
    
    -- TOMBOL UNSELECT / CLEAR
    local cRow = Instance.new("TextButton",sf)
    cRow.Size = UDim2.new(1,-8,0,IH); cRow.LayoutOrder = 0
    cRow.BackgroundColor3 = not RAID.updownTargetGrade and C.SURFACE or C.DD_BG
    cRow.BackgroundTransparency = not RAID.updownTargetGrade and 0.18 or 0.42
    cRow.BorderSizePixel = 0; cRow.Text = ""; cRow.AutoButtonColor = false; cRow.ZIndex = 9999
    Instance.new("UICorner",cRow).CornerRadius = UDim.new(0,6)
    local cLbl = Instance.new("TextLabel",cRow)
    cLbl.Size = UDim2.new(1,-8,1,0); cLbl.Position = UDim2.new(0,8,0,0)
    cLbl.BackgroundTransparency = 1; cLbl.Text = "-- NOT SELECTED --"; cLbl.TextSize = 10
    cLbl.Font = Enum.Font.GothamBold; cLbl.TextColor3 = not RAID.updownTargetGrade and C.ACC2 or C.TXT3
    cLbl.TextXAlignment = Enum.TextXAlignment.Left; cLbl.ZIndex = 9999
    cRow.MouseButton1Click:Connect(function()
        RAID.updownTargetGrade = nil
        gradeDDLbl.Text = " -- SELECT TARGET --"
        gradeDDLbl.TextColor3 = C.TXT3
        CloseActiveDD()
    end)

    for i, g in ipairs(targetGrades) do
        local row = Instance.new("TextButton",sf)
        row.Size = UDim2.new(1,-8,0,IH); row.LayoutOrder = i
        local isSel = RAID.updownTargetGrade == g
        row.BackgroundColor3 = isSel and C.SURFACE or C.DD_BG
        row.BackgroundTransparency = isSel and 0.18 or 0.42
        row.BorderSizePixel = 0; row.Text = ""; row.AutoButtonColor = false; row.ZIndex = 9999
        Instance.new("UICorner",row).CornerRadius = UDim.new(0,6)
        local lbl = Instance.new("TextLabel",row)
        lbl.Size = UDim2.new(1,-8,1,0); lbl.Position = UDim2.new(0,8,0,0)
        lbl.BackgroundTransparency = 1; lbl.Text = "Target: ["..g.."]"; lbl.TextSize = 11
        lbl.Font = Enum.Font.GothamBold; lbl.TextColor3 = isSel and C.ACC2 or C.TXT
        lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.ZIndex = 9999
        local selGrade = g
        row.MouseButton1Click:Connect(function()
            RAID.updownTargetGrade = selGrade
            gradeDDLbl.Text = " Target: ["..selGrade.."]"
            gradeDDLbl.TextColor3 = C.ACC2
            CloseActiveDD()
        end)
    end
    DDLayer.Visible = true
    _activeDDClose = function() popup:Destroy(); DDLayer.Visible = false end
 end)
--  AUTO BOSS KILL TOGGLE 
 local bossRow=Frame(raidInner,C.SURFACE,UDim2.new(1,0,0,44))
 bossRow.LayoutOrder=16; Corner(bossRow,10); Stroke(bossRow,C.BORD, 1.5,0.3)
 local bL=Label(bossRow,"AUTO KILL BOSS",13,C.TXT,Enum.Font.GothamBold)
 bL.Size=UDim2.new(1,-68,0,20); bL.Position=UDim2.new(0,14,0.5,-10)
 local bPill=Btn(bossRow,C.PILL_OFF,UDim2.new(0,52,0,30))
 bPill.AnchorPoint=Vector2.new(1,0.5); bPill.Position=UDim2.new(1,-12,0.5,0); Corner(bPill,13)
 local bKnob=Frame(bPill,C.KNOB_OFF,UDim2.new(0,24,0,24))
 bKnob.AnchorPoint=Vector2.new(0,0.5); bKnob.Position=UDim2.new(0,3,0.5,0); Corner(bKnob,10)
 bPill.MouseButton1Click:Connect(function()
 RAID.autoKillBoss=not RAID.autoKillBoss; local on=RAID.autoKillBoss
 TweenService:Create(bPill,TweenInfo.new(0.18,Enum.EasingStyle.Quad),{BackgroundColor3=on and C.PILL_ON or C.PILL_OFF}):Play()
 TweenService:Create(bKnob,TweenInfo.new(0.16),{
 Position=on and UDim2.new(1,-27,0.5,0) or UDim2.new(0,3,0.5,0),
 BackgroundColor3=on and C.KNOB_ON or C.KNOB_OFF,
 }):Play()
 end)

 --  TELEPORT DELAY SLIDER (1-10s) 
 local tpCard=Frame(raidInner,C.SURFACE,UDim2.new(1,0,0,54))
 tpCard.LayoutOrder=17; Corner(tpCard, 10); Stroke(tpCard,C.BORD, 1.5,0.3); Padding(tpCard,6,6,10,10)
 New("UIListLayout",{Parent=tpCard,SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,4)})
 -- Baris label + nilai
 local tpTop=Frame(tpCard,C.BLACK,UDim2.new(1,0,0,18)); tpTop.BackgroundTransparency=1; tpTop.LayoutOrder=0
 local _tpKeyL=Label(tpTop,"Teleport Delay",11,C.TXT2,Enum.Font.GothamBold); _tpKeyL.Size=UDim2.new(0.7,0,1,0)
 local tpValLbl=Label(tpTop,tostring(RAID.bossDelay).."s",11,C.ACC2,Enum.Font.GothamBold,Enum.TextXAlignment.Right)
 tpValLbl.Size=UDim2.new(0.3,0,1,0); tpValLbl.Position=UDim2.new(0.7,0,0,0)
 -- Baris slider: - [track] +
 local tpBot=Frame(tpCard,C.BLACK,UDim2.new(1,0,0,22)); tpBot.BackgroundTransparency=1; tpBot.LayoutOrder=1
 New("UIListLayout",{Parent=tpBot,SortOrder=Enum.SortOrder.LayoutOrder,
 FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,4),
 VerticalAlignment=Enum.VerticalAlignment.Center})
 -- Tombol minus
 local tpMinus=Btn(tpBot,C.BG3,UDim2.new(0,26,0,22))
 tpMinus.LayoutOrder=0; Corner(tpMinus,6); Stroke(tpMinus,C.BORD, 1.5,0.4)
 Label(tpMinus,"-",14,C.TXT,Enum.Font.GothamBold,Enum.TextXAlignment.Center).Size=UDim2.new(1,0,1,0)
 -- Track slider (TextButton untuk support input Delta)
 local tpTrackBtn=Btn(tpBot,C.BG3,UDim2.new(1,-60,0,22))
 tpTrackBtn.LayoutOrder=1; Corner(tpTrackBtn,11); Stroke(tpTrackBtn,C.BORD, 1.5,0.4)
 local tpFill=Frame(tpTrackBtn,C.ACC,UDim2.new((RAID.bossDelay-1)/9,1,1,-2))
 tpFill.Position=UDim2.new(0,0,0,1); Corner(tpFill,10)
 local tpKnob=Frame(tpTrackBtn,C.KNOB_ON,UDim2.new(0,18,0,18))
 tpKnob.AnchorPoint=Vector2.new(0.5,0.5); tpKnob.Position=UDim2.new((RAID.bossDelay-1)/9,0,0.5,0)
 Corner(tpKnob,9); Stroke(tpKnob,C.ACC, 1.5,0.6)
 -- Tombol plus
 local tpPlus=Btn(tpBot,C.BG3,UDim2.new(0,26,0,22))
 tpPlus.LayoutOrder=2; Corner(tpPlus,6); Stroke(tpPlus,C.BORD, 1.5,0.4)
 Label(tpPlus,"+",14,C.TXT,Enum.Font.GothamBold,Enum.TextXAlignment.Center).Size=UDim2.new(1,0,1,0)
 -- Update fungsi slider
 local function UpdateTpSlider(val)
 val=math.clamp(math.round(val),1,10)
 RAID.bossDelay=val; tpValLbl.Text=val.."s"
 tpFill.Size=UDim2.new((val-1)/9,1,1,-2)
 tpKnob.Position=UDim2.new((val-1)/9,0,0.5,0)
 end
 tpMinus.MouseButton1Click:Connect(function() UpdateTpSlider(RAID.bossDelay-1) end)
 tpPlus.MouseButton1Click:Connect(function() UpdateTpSlider(RAID.bossDelay+1) end)
 -- Drag slider
 local _tpDrag=false
 tpTrackBtn.InputBegan:Connect(function(inp)
 if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then
 _tpDrag=true
 local tA=tpTrackBtn.AbsolutePosition; local tS=tpTrackBtn.AbsoluteSize
 UpdateTpSlider(math.round(math.clamp((inp.Position.X-tA.X)/tS.X,0,1)*9)+1)
 end
 end)
 tpTrackBtn.InputChanged:Connect(function(inp)
 if not _tpDrag then return end
 if inp.UserInputType~=Enum.UserInputType.MouseMovement and inp.UserInputType~=Enum.UserInputType.Touch then return end
 local tA=tpTrackBtn.AbsolutePosition; local tS=tpTrackBtn.AbsoluteSize
 UpdateTpSlider(math.round(math.clamp((inp.Position.X-tA.X)/tS.X,0,1)*9)+1)
 end)
 tpTrackBtn.InputEnded:Connect(function(inp)
 if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then
 _tpDrag=false
 end
 end)

 --  APPLY PICK MODE LOCK 
 -- Lock/unlock field berdasarkan Pick Mode
 -- Tampilkan gembok pada field yang terkunci
 local function SetFieldLock(card, lockLbl, keyLbl, ddBtn, locked)
 -- Visual: dimming card
 card.BackgroundTransparency = locked and 0.65 or 0.42
 -- Gembok: tampil saat locked
 if lockLbl then lockLbl.Visible = locked end
 -- Label judul: warna redup saat locked
 if keyLbl then keyLbl.TextColor3 = locked and C.TXT3 or C.TXT2 end
 -- Tombol DD: transparansi
 if ddBtn then
 ddBtn.BackgroundTransparency = locked and 0.72 or 0.25
 for _,ch in ipairs(ddBtn:GetDescendants()) do
 if ch:IsA("TextLabel") then
 ch.TextTransparency = locked and 0.5 or 0
 end
 end
 end
 end

 ApplyPickModeLock=function()
 local pm=RAID.pickMode
 local unlock=PM_UNLOCK[pm] or {map=false,rank=false,rune=false}
 -- Update state variabel lock
 _prefLocked = not unlock.map
 _rankLocked = not unlock.rank
 _runeLocked = not unlock.rune
 -- Apply visual
 SetFieldLock(prefCard, _prefLockLbl, _prefKeyL, prefDDBtn, _prefLocked)
 SetFieldLock(rankCard, _rankLockLbl, _rankKeyL, rankDDWrap, _rankLocked)
 SetFieldLock(runeCard, _runeLockLbl, _runeKeyL, runeDDBtn, _runeLocked)
 -- Clear data dari field yang terkunci
 if _prefLocked then
 for k in pairs(RAID.preferMaps) do RAID.preferMaps[k]=nil end
 UpdatePrefLabel()
 end
 if _rankLocked then
 for _,g in ipairs(GRADE_LIST) do RAID.runeGrades[g]=nil end
 RefreshRankDDLabel()
 end
 if _runeLocked then
 RAID.runeMapTarget=0; RAID.runeEnabled=false
 runeDDVal.Text=" -- NOT SELECTED --"; runeDDVal.TextColor3=C.TXT3
 end
 -- Sync difficulty ke logic lama
 RAID.difficulty=PM_TO_DIFF[pm] or "easy"
 task.defer(ResizeRaidBody)
 end

 ApplyPickModeLock()
 task.defer(ResizeRaidBody)

end -- end Auto Raid do block


-- ============================================================
-- PANEL : AUTOMATION - Auto Ascension [v46 NEW]
-- ============================================================
do
 local p = Panels["autoraid"] -- reuse panel yg sudah dibuat oleh Auto Raid (JANGAN NewPanel lagi!)

 -- ACCORDION HEADER
 local ascOpen = false
 local ascHeader = Btn(p, C.SURFACE, UDim2.new(1,0,0,42))
 ascHeader.LayoutOrder = 3 -- setelah Auto Raid (LayoutOrder 1=header, 2=body)
 Corner(ascHeader, 10)
 -- Border warna emas/kuning untuk beda dari Auto Raid
 New("UIStroke",{Parent=ascHeader, Color=Color3.fromRGB(220,180,50), Thickness=1.5, Transparency=0.35})
 local ascArr = Label(ascHeader, ">", 13, Color3.fromRGB(220,180,50), Enum.Font.GothamBold)
 ascArr.Size = UDim2.new(0,22,1,0); ascArr.Position = UDim2.new(0,10,0,0)
 local ascHeaderLbl = Label(ascHeader, "Auto RAID Ascension", 14, C.TXT, Enum.Font.GothamBold)
 ascHeaderLbl.Size = UDim2.new(1,-50,1,0); ascHeaderLbl.Position = UDim2.new(0,34,0,0)

 local ascBody = Frame(p, C.BG2, UDim2.new(1,0,0,0))
 ascBody.LayoutOrder = 4
 ascBody.ClipsDescendants = true
 Corner(ascBody, 10)
 New("UIStroke",{Parent=ascBody, Color=Color3.fromRGB(220,180,50), Thickness=1.5, Transparency=0.25})
 ascBody.Visible = false

 local ascInner = Frame(ascBody, C.BLACK, UDim2.new(1,-16,0,0))
 ascInner.BackgroundTransparency = 1; ascInner.Position = UDim2.new(0,8,0,8)
 local ascLayout = New("UIListLayout",{Parent=ascInner, SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,6)})

 local function ResizeAscBody()
  task.spawn(function()
   task.wait(0)
   ascLayout:ApplyLayout()
   local h = ascLayout.AbsoluteContentSize.Y + 16
   ascInner.Size = UDim2.new(1,0,0,h)
   ascBody.Size = UDim2.new(1,0,0,h+16)
  end)
 end

 ascHeader.MouseButton1Click:Connect(function()
  ascOpen = not ascOpen; ascBody.Visible = ascOpen
  ascArr.Text = ascOpen and "v" or ">"
  if ascOpen then task.defer(ResizeAscBody) end
 end)

 -- ROW 1: STATUS
 local aStatusCard = Frame(ascInner, C.SURFACE, UDim2.new(1,0,0,38))
 aStatusCard.LayoutOrder = 1; Corner(aStatusCard,10); Stroke(aStatusCard,C.BORD,1.5,0.3); Padding(aStatusCard,6,6,10,10)
 local _ascDot = Frame(aStatusCard, Color3.fromRGB(100,100,100), UDim2.new(0,9,0,9))
 _ascDot.AnchorPoint = Vector2.new(0,0.5); _ascDot.Position = UDim2.new(0,0,0.5,0); Corner(_ascDot,5)
 ASC.dot = _ascDot
 local _ascStKeyL = Label(aStatusCard,"Status",11,C.TXT3,Enum.Font.GothamBold)
 _ascStKeyL.Size = UDim2.new(0,54,1,0); _ascStKeyL.Position = UDim2.new(0,16,0,0)
 local _ascStatusLbl = Label(aStatusCard,"Disabled",11,Color3.fromRGB(160,148,135),Enum.Font.GothamBold)
 _ascStatusLbl.Size = UDim2.new(1,-76,1,0); _ascStatusLbl.Position = UDim2.new(0,70,0,0)
 _ascStatusLbl.TextXAlignment = Enum.TextXAlignment.Right
 _ascStatusLbl.TextTruncate = Enum.TextTruncate.AtEnd
 ASC.statusLbl = _ascStatusLbl

 -- ROW 2: COMPLETED
 local aCompCard = Frame(ascInner, C.SURFACE, UDim2.new(1,0,0,38))
 aCompCard.LayoutOrder = 2; Corner(aCompCard,10); Stroke(aCompCard,C.BORD,1.5,0.3); Padding(aCompCard,6,6,10,10)
 local _acKeyL = Label(aCompCard,"Ascension Completed",11,C.TXT3,Enum.Font.GothamBold)
 _acKeyL.Size = UDim2.new(0.7,0,1,0)
 local _ascSuksesLbl = Label(aCompCard,"0",11,Color3.fromRGB(220,180,50),Enum.Font.GothamBold)
 _ascSuksesLbl.Size = UDim2.new(0.3,0,1,0); _ascSuksesLbl.Position = UDim2.new(0.7,0,0,0)
 _ascSuksesLbl.TextXAlignment = Enum.TextXAlignment.Right
 ASC.suksesLbl = _ascSuksesLbl

 -- ROW 3: ENABLE TOGGLE
 local aCtrlRow = Frame(ascInner, C.SURFACE, UDim2.new(1,0,0,44))
 aCtrlRow.LayoutOrder = 3; Corner(aCtrlRow,10)
 New("UIStroke",{Parent=aCtrlRow, Color=Color3.fromRGB(220,180,50), Thickness=1.5, Transparency=0.2})
 local aTogLbl = Label(aCtrlRow,"Enable Auto Ascension",13,C.TXT,Enum.Font.GothamBold)
 aTogLbl.Size = UDim2.new(1,-68,0,20); aTogLbl.Position = UDim2.new(0,14,0.5,-10)
 local aPill = Btn(aCtrlRow, C.PILL_OFF, UDim2.new(0,52,0,30))
 aPill.AnchorPoint = Vector2.new(1,0.5); aPill.Position = UDim2.new(1,-12,0.5,0); Corner(aPill,13)
 local aKnob = Frame(aPill, C.KNOB_OFF, UDim2.new(0,24,0,24))
 aKnob.AnchorPoint = Vector2.new(0,0.5); aKnob.Position = UDim2.new(0,3,0.5,0); Corner(aKnob,10)

 local function SetAscPill(on)
  TweenService:Create(aPill,TweenInfo.new(0.16),{BackgroundColor3=on and Color3.fromRGB(180,140,20) or C.PILL_OFF}):Play()
  TweenService:Create(aKnob,TweenInfo.new(0.16),{
   Position=on and UDim2.new(1,-27,0.5,0) or UDim2.new(0,3,0.5,0),
   BackgroundColor3=on and C.KNOB_ON or C.KNOB_OFF,
  }):Play()
 end

 aPill.MouseButton1Click:Connect(function()
  _ascOn = not _ascOn
  SetAscPill(_ascOn)
  if _ascOn then
   StartAscensionLoop()
  else
   StopAscension()
   AscStatusUpdate("Disabled", Color3.fromRGB(160,148,135))
   if ASC.dot then ASC.dot.BackgroundColor3 = Color3.fromRGB(100,100,100) end
  end
 end)

 -- ============================================================
 -- ROW 4: PREFERRED RANK (always visible, mirip Auto Raid)
 -- ============================================================
 local GRADE_COLORS_ASC = {
  ["E"]=Color3.fromRGB(150,150,150),["D"]=Color3.fromRGB(100,200,100),
  ["C"]=Color3.fromRGB(80,200,120), ["B"]=Color3.fromRGB(100,140,255),
  ["A"]=Color3.fromRGB(180,100,255),["S"]=Color3.fromRGB(255,180,50),
  ["SS"]=Color3.fromRGB(255,220,0), ["G"]=Color3.fromRGB(255,60,60),
  ["N"]=Color3.fromRGB(255,100,200),["M"]=Color3.fromRGB(255,0,0),
  ["M+"]=Color3.fromRGB(255,50,50), ["M++"]=Color3.fromRGB(255,100,100),
  ["XM"]=Color3.fromRGB(180,0,0),   ["ULT"]=Color3.fromRGB(255,255,255),
 }
 local GRADE_VALUE_ASC = GRADE_RANK or {}

 local ascRankHdr = Label(ascInner,"PREFERRED RANK",10,C.TXT3,Enum.Font.GothamBold)
 ascRankHdr.LayoutOrder = 4; ascRankHdr.Size = UDim2.new(1,0,0,14)
 local ascRankCard = Frame(ascInner,C.SURFACE,UDim2.new(1,0,0,40))
 ascRankCard.LayoutOrder = 5; Corner(ascRankCard,10); Stroke(ascRankCard,C.BORD,1.5,0.3); Padding(ascRankCard,6,6,10,10)
 local ascRankRow = Frame(ascRankCard,C.BLACK,UDim2.new(1,0,1,0)); ascRankRow.BackgroundTransparency=1
 local ascRankKeyL = Label(ascRankRow,"Select Rank",11,C.TXT2,Enum.Font.GothamBold)
 ascRankKeyL.Size = UDim2.new(0,72,1,0)
 local ascRankDDBtn = Btn(ascRankRow,C.BG3,UDim2.new(1,-82,1,0))
 ascRankDDBtn.Position = UDim2.new(0,80,0,0); Corner(ascRankDDBtn,6); Stroke(ascRankDDBtn,C.BORD,1.5,0.25)
 local ascRankDDVal = Label(ascRankDDBtn," -- SELECT RANK --",11,C.TXT3,Enum.Font.GothamBold)
 ascRankDDVal.Size = UDim2.new(1,-20,1,0); ascRankDDVal.TextTruncate = Enum.TextTruncate.AtEnd
 local ascRankArr = Label(ascRankDDBtn,"v",10,C.TXT3,Enum.Font.GothamBold,Enum.TextXAlignment.Center)
 ascRankArr.Size = UDim2.new(0,18,1,0); ascRankArr.Position = UDim2.new(1,-20,0,0)

 local function RefreshAscRankLabel()
  local ns={}
  for _,g in ipairs(GRADE_LIST or {}) do
   if ASC.runeGrades[g] then table.insert(ns,"["..g.."]") end
  end
  if #ns==0 then ascRankDDVal.Text=" -- SELECT RANK --"; ascRankDDVal.TextColor3=C.TXT3
  else ascRankDDVal.Text=" "..table.concat(ns," "); ascRankDDVal.TextColor3=Color3.fromRGB(200,120,255) end
 end
 RefreshAscRankLabel()

 ascRankDDBtn.MouseButton1Click:Connect(function()
  CloseActiveDD()
  local IH=30
  local gl = GRADE_LIST or {"E","D","C","B","A","S","SS","G","N","M","M+","M++","XM","ULT"}
  local SFH=math.min(#gl*(IH+4)+44,280)
  local ab=ascRankDDBtn.AbsolutePosition; local sz=ascRankDDBtn.AbsoluteSize
  local cam=workspace.CurrentCamera; local vpH=cam and cam.ViewportSize.Y or 800
  local goUp=(ab.Y+SFH+44 > vpH*0.85)
  local popup=Instance.new("Frame")
  popup.Parent=DDLayer; popup.BackgroundColor3=C.DD_BG; popup.BorderSizePixel=0
  popup.Size=UDim2.new(0,sz.X,0,SFH+8)
  if goUp then popup.Position=UDim2.new(0,ab.X,0,ab.Y-SFH-12)
  else popup.Position=UDim2.new(0,ab.X,0,ab.Y+sz.Y+4) end
  popup.ZIndex=9999; Corner(popup,10); Stroke(popup,C.BORD,1.5,0.3)
  local sf=Instance.new("ScrollingFrame",popup)
  sf.Size=UDim2.new(1,0,0,SFH); sf.BackgroundTransparency=1; sf.BorderSizePixel=0
  sf.ScrollBarThickness=4; sf.CanvasSize=UDim2.new(0,0,0,#gl*(IH+4)+44); sf.ZIndex=9999
  local sfp=Instance.new("UIPadding",sf)
  sfp.PaddingTop=UDim.new(0,4); sfp.PaddingBottom=UDim.new(0,4); sfp.PaddingLeft=UDim.new(0,4); sfp.PaddingRight=UDim.new(0,4)
  local sfLayout=Instance.new("UIListLayout",sf)
  sfLayout.SortOrder=Enum.SortOrder.LayoutOrder; sfLayout.Padding=UDim.new(0,4)
  local rb=Instance.new("TextButton",sf); rb.Size=UDim2.new(1,-8,0,IH); rb.LayoutOrder=0
  rb.BackgroundColor3=C.RED; rb.BackgroundTransparency=0.55; rb.BorderSizePixel=0; rb.Text=""; rb.AutoButtonColor=false; rb.ZIndex=9999
  Instance.new("UICorner",rb).CornerRadius=UDim.new(0,6)
  local rl=Instance.new("TextLabel",rb); rl.Size=UDim2.new(1,-8,1,0); rl.Position=UDim2.new(0,8,0,0)
  rl.BackgroundTransparency=1; rl.Text="x Reset ALL"; rl.TextSize=10
  rl.Font=Enum.Font.GothamBold; rl.TextColor3=C.RED; rl.TextXAlignment=Enum.TextXAlignment.Left; rl.ZIndex=9999
  rb.MouseButton1Click:Connect(function()
   for _,g in ipairs(gl) do ASC.runeGrades[g]=nil end
   CloseActiveDD(); RefreshAscRankLabel()
  end)
  for i,grade in ipairs(gl) do
   local gc=grade; local col=GRADE_COLORS_ASC[grade] or C.ACC
   local gv=GRADE_VALUE_ASC[grade] or "?"; local isSel=ASC.runeGrades[gc]==true
   local item=Instance.new("TextButton",sf)
   item.Size=UDim2.new(1,-8,0,IH); item.LayoutOrder=i
   item.BackgroundColor3=isSel and C.SURFACE or C.DD_BG; item.BackgroundTransparency=isSel and 0.18 or 0.42
   item.BorderSizePixel=0; item.Text=""; item.AutoButtonColor=false; item.ZIndex=9999
   Instance.new("UICorner",item).CornerRadius=UDim.new(0,6)
   local ck=Instance.new("TextLabel",item); ck.Size=UDim2.new(0,20,1,0); ck.Position=UDim2.new(0,4,0,0)
   ck.BackgroundTransparency=1; ck.Text=isSel and "v" or ""; ck.TextSize=11
   ck.Font=Enum.Font.GothamBold; ck.TextColor3=col; ck.TextXAlignment=Enum.TextXAlignment.Center; ck.ZIndex=9999
   local nl=Instance.new("TextLabel",item); nl.Size=UDim2.new(0,56,1,0); nl.Position=UDim2.new(0,26,0,0)
   nl.BackgroundTransparency=1; nl.Text="Rank "..grade; nl.TextSize=11
   nl.Font=Enum.Font.GothamBold; nl.TextColor3=isSel and Color3.fromRGB(255,255,255) or col
   nl.TextXAlignment=Enum.TextXAlignment.Left; nl.ZIndex=9999
   local vl=Instance.new("TextLabel",item); vl.Size=UDim2.new(1,-86,1,0); vl.Position=UDim2.new(0,84,0,0)
   vl.BackgroundTransparency=1; vl.Text="Grade "..tostring(gv); vl.TextSize=9; vl.Font=Enum.Font.Gotham
   vl.TextColor3=isSel and C.TXT2 or C.TXT3; vl.TextXAlignment=Enum.TextXAlignment.Left; vl.ZIndex=9999
   item.MouseButton1Click:Connect(function()
    local ns=not ASC.runeGrades[gc]; ASC.runeGrades[gc]=ns and true or nil
    item.BackgroundColor3=ns and C.SURFACE or C.DD_BG; item.BackgroundTransparency=ns and 0.18 or 0.42
    ck.Text=ns and "v" or ""; nl.TextColor3=ns and Color3.fromRGB(255,255,255) or col
    vl.TextColor3=ns and C.TXT2 or C.TXT3; RefreshAscRankLabel()
    if _ascWakeup then pcall(function() _ascWakeup:Fire() end) end
   end)
  end
  DDLayer.Visible=true
  _activeDDClose=function() popup:Destroy(); DDLayer.Visible=false end
 end)

 -- ============================================================
 -- ROW 5-6: PREFERRED RUNE (Item) - always visible
 -- ============================================================
 local ascRuneHdr = Label(ascInner,"PREFERRED RUNE (Item)",10,C.TXT3,Enum.Font.GothamBold)
 ascRuneHdr.LayoutOrder = 6; ascRuneHdr.Size = UDim2.new(1,0,0,14)
 local ascRuneCard = Frame(ascInner,C.SURFACE,UDim2.new(1,0,0,40))
 ascRuneCard.LayoutOrder = 7; Corner(ascRuneCard,10); Stroke(ascRuneCard,C.BORD,1.5,0.3); Padding(ascRuneCard,6,6,10,10)
 local ascRuneRow = Frame(ascRuneCard,C.BLACK,UDim2.new(1,0,1,0)); ascRuneRow.BackgroundTransparency=1
 local ascRuneKeyL = Label(ascRuneRow,"Auto Item",11,C.TXT2,Enum.Font.GothamBold)
 ascRuneKeyL.Size = UDim2.new(0,72,1,0)
 local ascRuneDDBtn = Btn(ascRuneRow,C.BG3,UDim2.new(1,-82,1,0))
 ascRuneDDBtn.Position = UDim2.new(0,80,0,0); Corner(ascRuneDDBtn,6); Stroke(ascRuneDDBtn,C.BORD,1.5,0.25)
 local ascRuneDDVal = Label(ascRuneDDBtn," -- NOT SELECTED --",11,C.TXT3,Enum.Font.GothamBold)
 ascRuneDDVal.Size = UDim2.new(1,-20,1,0); ascRuneDDVal.TextTruncate = Enum.TextTruncate.AtEnd
 local ascRuneArr = Label(ascRuneDDBtn,"v",10,C.TXT3,Enum.Font.GothamBold,Enum.TextXAlignment.Center)
 ascRuneArr.Size = UDim2.new(0,18,1,0); ascRuneArr.Position = UDim2.new(1,-20,0,0)

 local function AscSyncRuneState()
  if ASC.runeMapTarget >= 1 and ASC.runeMapTarget <= 26 then ASC.runeEnabled=true
  else ASC.runeEnabled=false end
 end
 AscSyncRuneState()

 -- [v64] Nama boss per Tower (sesuai ASC_RUNE_IDS data)
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

 if ASC.runeMapTarget >= 1 and ASC.runeMapTarget <= 26 then
  local _tn = ASC_TOWER_NAMES[ASC.runeMapTarget] or ("Tower "..ASC.runeMapTarget)
  ascRuneDDVal.Text=" Tower "..ASC.runeMapTarget.." - ".._tn
  ascRuneDDVal.TextColor3=C.ACC2
 end

 ascRuneDDBtn.MouseButton1Click:Connect(function()
  CloseActiveDD()
  local aP=ascRuneDDBtn.AbsolutePosition; local aS=ascRuneDDBtn.AbsoluteSize; local IH=28
  local popH=(27*(IH+2)+8); local cam=workspace.CurrentCamera
  local vpH=cam and cam.ViewportSize.Y or 800
  local goUp=(aP.Y+popH > vpH*0.85)
  local popup=Instance.new("Frame")
  popup.Parent=DDLayer; popup.BackgroundColor3=C.DD_BG; popup.BorderSizePixel=0
  popup.Size=UDim2.new(0,aS.X+10,0,math.min(popH,220))
  if goUp then popup.Position=UDim2.new(0,aP.X,0,aP.Y-math.min(popH,220)-4)
  else popup.Position=UDim2.new(0,aP.X,0,aP.Y+aS.Y+4) end
  popup.ZIndex=9999; popup.ClipsDescendants=true; Corner(popup,10); Stroke(popup,C.BORD2,1.5,0.2)
  local sf=Instance.new("ScrollingFrame",popup); sf.Size=UDim2.new(1,0,1,0)
  sf.BackgroundTransparency=1; sf.BorderSizePixel=0; sf.ScrollBarThickness=4; sf.ScrollBarImageColor3=C.ACC
  sf.ZIndex=9999; sf.CanvasSize=UDim2.new(0,0,0,27*(IH+2)+8)
  local sfl=Instance.new("UIListLayout",sf); sfl.Padding=UDim.new(0,2); sfl.SortOrder=Enum.SortOrder.LayoutOrder
  Instance.new("UIPadding",sf).PaddingTop=UDim.new(0,4)
  -- Item: NOT SELECTED
  local i0=Instance.new("TextButton",sf); i0.Size=UDim2.new(1,-8,0,IH); i0.LayoutOrder=0
  local s0=(ASC.runeMapTarget==0)
  i0.BackgroundColor3=s0 and C.SURFACE or C.DD_BG; i0.BackgroundTransparency=s0 and 0.18 or 0.42
  i0.BorderSizePixel=0; i0.Text=""; i0.AutoButtonColor=false; i0.ZIndex=9999
  Instance.new("UICorner",i0).CornerRadius=UDim.new(0,6)
  local l0=Instance.new("TextLabel",i0); l0.Size=UDim2.new(1,-8,1,0); l0.Position=UDim2.new(0,8,0,0)
  l0.BackgroundTransparency=1; l0.Text="-- NOT SELECTED --"; l0.TextSize=10
  l0.Font=Enum.Font.GothamBold; l0.TextColor3=s0 and C.ACC2 or C.TXT3; l0.TextXAlignment=Enum.TextXAlignment.Left; l0.ZIndex=9999
  i0.MouseButton1Click:Connect(function()
   CloseActiveDD(); ASC.runeMapTarget=0; AscSyncRuneState()
   ascRuneDDVal.Text=" -- NOT SELECTED --"; ascRuneDDVal.TextColor3=C.TXT3
  end)
  -- Items: Tower 1-26 dengan nama boss
  for mn=1,26 do
   local ml=mn; local bossName=ASC_TOWER_NAMES[mn] or ("Tower "..mn)
   local it=Instance.new("TextButton",sf); it.Size=UDim2.new(1,-8,0,IH); it.LayoutOrder=mn
   local iS=(ASC.runeMapTarget==mn)
   it.BackgroundColor3=iS and C.SURFACE or C.DD_BG; it.BackgroundTransparency=iS and 0.18 or 0.42
   it.BorderSizePixel=0; it.Text=""; it.AutoButtonColor=false; it.ZIndex=9999
   Instance.new("UICorner",it).CornerRadius=UDim.new(0,6)
   local il=Instance.new("TextLabel",it); il.Size=UDim2.new(1,-8,1,0); il.Position=UDim2.new(0,8,0,0)
   il.BackgroundTransparency=1
   il.Text="Tower "..mn.." - "..bossName; il.TextSize=10; il.Font=Enum.Font.GothamBold
   il.TextColor3=iS and C.ACC2 or C.TXT; il.TextXAlignment=Enum.TextXAlignment.Left; il.ZIndex=9999; il.TextTruncate=Enum.TextTruncate.AtEnd
   it.MouseButton1Click:Connect(function()
    CloseActiveDD(); ASC.runeMapTarget=ml; AscSyncRuneState()
    local _bn2=ASC_TOWER_NAMES[ml] or ("Tower "..ml)
    ascRuneDDVal.Text=" Tower "..ml.." - ".._bn2; ascRuneDDVal.TextColor3=C.ACC2
   end)
  end
  DDLayer.Visible=true
  _activeDDClose=function() popup:Destroy(); DDLayer.Visible=false end
 end)



 -- ============================================================
 -- ROW 8: PREFERRED MAP (Tower tujuan masuk)
 -- ============================================================
 local ascPrefMapCard = Frame(ascInner,C.SURFACE,UDim2.new(1,0,0,40))
 ascPrefMapCard.LayoutOrder = 8; Corner(ascPrefMapCard,10); Stroke(ascPrefMapCard,C.BORD,1.5,0.3); Padding(ascPrefMapCard,6,6,10,10)
 local ascPrefMapRow = Frame(ascPrefMapCard,C.BLACK,UDim2.new(1,0,1,0)); ascPrefMapRow.BackgroundTransparency=1
 local ascPrefMapKeyL = Label(ascPrefMapRow,"Preferred Map",11,C.TXT2,Enum.Font.GothamBold)
 ascPrefMapKeyL.Size = UDim2.new(0,86,1,0)
 local ascPrefMapDDBtn = Btn(ascPrefMapRow,C.BG3,UDim2.new(1,-96,1,0))
 ascPrefMapDDBtn.Position = UDim2.new(0,94,0,0); Corner(ascPrefMapDDBtn,6); Stroke(ascPrefMapDDBtn,C.BORD,1.5,0.25)
 local ascPrefMapDDVal = Label(ascPrefMapDDBtn," -- NOT SELECTED --",11,C.TXT3,Enum.Font.GothamBold)
 ascPrefMapDDVal.Size = UDim2.new(1,-20,1,0); ascPrefMapDDVal.TextTruncate = Enum.TextTruncate.AtEnd
 local ascPrefMapArr = Label(ascPrefMapDDBtn,"v",10,C.TXT3,Enum.Font.GothamBold,Enum.TextXAlignment.Center)
 ascPrefMapArr.Size = UDim2.new(0,18,1,0); ascPrefMapArr.Position = UDim2.new(1,-20,0,0)

 -- Nama Tower (sama persis dengan Preferred Rune)
 local ASC_PREFMAP_NAMES = {
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

 -- Sync tampilan awal dari ASC.preferMaps
 local function UpdateAscPrefMapLabel()
  local ms = {}
  for mn=1,26 do if ASC.preferMaps and ASC.preferMaps[mn] then table.insert(ms,"T"..mn) end end
  if #ms == 0 then
   ascPrefMapDDVal.Text = " -- NOT SELECTED --"; ascPrefMapDDVal.TextColor3 = C.TXT3
  else
   ascPrefMapDDVal.Text = " "..table.concat(ms," | "); ascPrefMapDDVal.TextColor3 = Color3.fromRGB(100,220,255)
  end
 end
 UpdateAscPrefMapLabel()

 ascPrefMapDDBtn.MouseButton1Click:Connect(function()
  CloseActiveDD()
  local aP=ascPrefMapDDBtn.AbsolutePosition; local aS=ascPrefMapDDBtn.AbsoluteSize; local IH=28
  local popH=(28*(IH+2)+44); local cam=workspace.CurrentCamera
  local vpH=cam and cam.ViewportSize.Y or 800
  local goUp=(aP.Y+popH > vpH*0.85)
  local popup=Instance.new("Frame")
  popup.Parent=DDLayer; popup.BackgroundColor3=C.DD_BG; popup.BorderSizePixel=0
  popup.Size=UDim2.new(0,aS.X+10,0,math.min(popH,220))
  if goUp then popup.Position=UDim2.new(0,aP.X,0,aP.Y-math.min(popH,220)-4)
  else popup.Position=UDim2.new(0,aP.X,0,aP.Y+aS.Y+4) end
  popup.ZIndex=9999; popup.ClipsDescendants=true; Corner(popup,10); Stroke(popup,C.BORD2,1.5,0.2)
  local sf=Instance.new("ScrollingFrame",popup); sf.Size=UDim2.new(1,0,1,0)
  sf.BackgroundTransparency=1; sf.BorderSizePixel=0; sf.ScrollBarThickness=4; sf.ScrollBarImageColor3=Color3.fromRGB(100,220,255)
  sf.ZIndex=9999; sf.CanvasSize=UDim2.new(0,0,0,28*(IH+2)+44)
  local sfl=Instance.new("UIListLayout",sf); sfl.Padding=UDim.new(0,2); sfl.SortOrder=Enum.SortOrder.LayoutOrder
  Instance.new("UIPadding",sf).PaddingTop=UDim.new(0,4)

  -- Tombol Reset ALL
  local rb=Instance.new("TextButton",sf); rb.Size=UDim2.new(1,-8,0,IH); rb.LayoutOrder=0
  rb.BackgroundColor3=C.RED; rb.BackgroundTransparency=0.55; rb.BorderSizePixel=0; rb.Text=""; rb.AutoButtonColor=false; rb.ZIndex=9999
  Instance.new("UICorner",rb).CornerRadius=UDim.new(0,6)
  local rl=Instance.new("TextLabel",rb); rl.Size=UDim2.new(1,-8,1,0); rl.Position=UDim2.new(0,8,0,0)
  rl.BackgroundTransparency=1; rl.Text="x Reset ALL"; rl.TextSize=10
  rl.Font=Enum.Font.GothamBold; rl.TextColor3=C.RED; rl.TextXAlignment=Enum.TextXAlignment.Left; rl.ZIndex=9999
  rb.MouseButton1Click:Connect(function()
   for mn=1,26 do ASC.preferMaps[mn]=nil end
   CloseActiveDD(); UpdateAscPrefMapLabel()
  end)

  -- Tower 1-26 dengan multi-select (checkmark)
  local itemBtns = {}
  for mn=1,26 do
   local ml=mn; local bossName=ASC_PREFMAP_NAMES[mn] or ("Tower "..mn)
   local it=Instance.new("TextButton",sf); it.Size=UDim2.new(1,-8,0,IH); it.LayoutOrder=mn
   local iS=(ASC.preferMaps and ASC.preferMaps[mn]==true)
   it.BackgroundColor3=iS and C.SURFACE or C.DD_BG; it.BackgroundTransparency=iS and 0.18 or 0.42
   it.BorderSizePixel=0; it.Text=""; it.AutoButtonColor=false; it.ZIndex=9999
   Instance.new("UICorner",it).CornerRadius=UDim.new(0,6)
   local ck=Instance.new("TextLabel",it); ck.Size=UDim2.new(0,20,1,0); ck.Position=UDim2.new(0,4,0,0)
   ck.BackgroundTransparency=1; ck.Text=iS and "v" or ""; ck.TextSize=11
   ck.Font=Enum.Font.GothamBold; ck.TextColor3=Color3.fromRGB(100,220,255)
   ck.TextXAlignment=Enum.TextXAlignment.Center; ck.ZIndex=9999
   local il=Instance.new("TextLabel",it); il.Size=UDim2.new(1,-28,1,0); il.Position=UDim2.new(0,26,0,0)
   il.BackgroundTransparency=1
   il.Text="Tower "..mn.." - "..bossName; il.TextSize=10; il.Font=Enum.Font.GothamBold
   il.TextColor3=iS and Color3.fromRGB(100,220,255) or C.TXT
   il.TextXAlignment=Enum.TextXAlignment.Left; il.ZIndex=9999; il.TextTruncate=Enum.TextTruncate.AtEnd
   itemBtns[ml] = {btn=it, ck=ck, lbl=il}
   it.MouseButton1Click:Connect(function()
    -- Toggle pilihan (multi-select)
    if ASC.preferMaps[ml] then
     ASC.preferMaps[ml] = nil
    else
     ASC.preferMaps[ml] = true
    end
    local nowSel = (ASC.preferMaps[ml] == true)
    it.BackgroundTransparency = nowSel and 0.18 or 0.42
    it.BackgroundColor3 = nowSel and C.SURFACE or C.DD_BG
    ck.Text = nowSel and "v" or ""
    il.TextColor3 = nowSel and Color3.fromRGB(100,220,255) or C.TXT
    UpdateAscPrefMapLabel()
   end)
  end
  DDLayer.Visible=true
  _activeDDClose=function() popup:Destroy(); DDLayer.Visible=false end
 end)



 -- ============================================================
 -- ROW 10: AUTO BOSS KILL TOGGLE
 -- ============================================================
 local ascBossRow = Frame(ascInner,C.SURFACE,UDim2.new(1,0,0,44))
 ascBossRow.LayoutOrder=10; Corner(ascBossRow,10); Stroke(ascBossRow,C.BORD,1.5,0.3)
 local ascBossL = Label(ascBossRow,"AUTO KILL BOSS",13,C.TXT,Enum.Font.GothamBold)
 ascBossL.Size=UDim2.new(1,-68,0,20); ascBossL.Position=UDim2.new(0,14,0.5,-10)
 local ascBossPill = Btn(ascBossRow,C.PILL_OFF,UDim2.new(0,52,0,30))
 ascBossPill.AnchorPoint=Vector2.new(1,0.5); ascBossPill.Position=UDim2.new(1,-12,0.5,0); Corner(ascBossPill,13)
 local ascBossKnob = Frame(ascBossPill,C.KNOB_OFF,UDim2.new(0,24,0,24))
 ascBossKnob.AnchorPoint=Vector2.new(0,0.5); ascBossKnob.Position=UDim2.new(0,3,0.5,0); Corner(ascBossKnob,10)
 ascBossPill.MouseButton1Click:Connect(function()
  ASC.autoKillBoss=not ASC.autoKillBoss; local on=ASC.autoKillBoss
  TweenService:Create(ascBossPill,TweenInfo.new(0.18,Enum.EasingStyle.Quad),{BackgroundColor3=on and C.PILL_ON or C.PILL_OFF}):Play()
  TweenService:Create(ascBossKnob,TweenInfo.new(0.16),{
   Position=on and UDim2.new(1,-27,0.5,0) or UDim2.new(0,3,0.5,0),
   BackgroundColor3=on and C.KNOB_ON or C.KNOB_OFF,
  }):Play()
 end)

 -- ============================================================
 -- ROW 11: TELEPORT DELAY SLIDER (1-10s)
 -- ============================================================
 local ascTpCard = Frame(ascInner,C.SURFACE,UDim2.new(1,0,0,54))
 ascTpCard.LayoutOrder=11; Corner(ascTpCard,10); Stroke(ascTpCard,C.BORD,1.5,0.3); Padding(ascTpCard,6,6,10,10)
 New("UIListLayout",{Parent=ascTpCard,SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,4)})
 local ascTpTop = Frame(ascTpCard,C.BLACK,UDim2.new(1,0,0,18)); ascTpTop.BackgroundTransparency=1; ascTpTop.LayoutOrder=0
 local _ascTpKeyL = Label(ascTpTop,"Teleport Delay",11,C.TXT2,Enum.Font.GothamBold); _ascTpKeyL.Size=UDim2.new(0.7,0,1,0)
 local ascTpValLbl = Label(ascTpTop,tostring(ASC.bossDelay).."s",11,C.ACC2,Enum.Font.GothamBold,Enum.TextXAlignment.Right)
 ascTpValLbl.Size=UDim2.new(0.3,0,1,0); ascTpValLbl.Position=UDim2.new(0.7,0,0,0)
 local ascTpBot = Frame(ascTpCard,C.BLACK,UDim2.new(1,0,0,22)); ascTpBot.BackgroundTransparency=1; ascTpBot.LayoutOrder=1
 New("UIListLayout",{Parent=ascTpBot,SortOrder=Enum.SortOrder.LayoutOrder,
  FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,4),VerticalAlignment=Enum.VerticalAlignment.Center})
 local ascTpMinus = Btn(ascTpBot,C.BG3,UDim2.new(0,26,0,22))
 ascTpMinus.LayoutOrder=0; Corner(ascTpMinus,6); Stroke(ascTpMinus,C.BORD,1.5,0.4)
 Label(ascTpMinus,"-",14,C.TXT,Enum.Font.GothamBold,Enum.TextXAlignment.Center).Size=UDim2.new(1,0,1,0)
 local ascTpTrackBtn = Btn(ascTpBot,C.BG3,UDim2.new(1,-60,0,22))
 ascTpTrackBtn.LayoutOrder=1; Corner(ascTpTrackBtn,11); Stroke(ascTpTrackBtn,C.BORD,1.5,0.4)
 local ascTpFill = Frame(ascTpTrackBtn,C.ACC,UDim2.new((ASC.bossDelay-1)/9,1,1,-2))
 ascTpFill.Position=UDim2.new(0,0,0,1); Corner(ascTpFill,10)
 local ascTpKnob = Frame(ascTpTrackBtn,C.KNOB_ON,UDim2.new(0,18,0,18))
 ascTpKnob.AnchorPoint=Vector2.new(0.5,0.5); ascTpKnob.Position=UDim2.new((ASC.bossDelay-1)/9,0,0.5,0)
 Corner(ascTpKnob,9); Stroke(ascTpKnob,C.ACC,1.5,0.6)
 local ascTpPlus = Btn(ascTpBot,C.BG3,UDim2.new(0,26,0,22))
 ascTpPlus.LayoutOrder=2; Corner(ascTpPlus,6); Stroke(ascTpPlus,C.BORD,1.5,0.4)
 Label(ascTpPlus,"+",14,C.TXT,Enum.Font.GothamBold,Enum.TextXAlignment.Center).Size=UDim2.new(1,0,1,0)
 local function UpdateAscTpSlider(val)
  val=math.clamp(math.round(val),1,10)
  ASC.bossDelay=val; ascTpValLbl.Text=val.."s"
  ascTpFill.Size=UDim2.new((val-1)/9,1,1,-2); ascTpKnob.Position=UDim2.new((val-1)/9,0,0.5,0)
 end
 ascTpMinus.MouseButton1Click:Connect(function() UpdateAscTpSlider(ASC.bossDelay-1) end)
 ascTpPlus.MouseButton1Click:Connect(function() UpdateAscTpSlider(ASC.bossDelay+1) end)
 local _ascTpDrag=false
 ascTpTrackBtn.InputBegan:Connect(function(inp)
  if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then
   _ascTpDrag=true
   local tA=ascTpTrackBtn.AbsolutePosition; local tS=ascTpTrackBtn.AbsoluteSize
   UpdateAscTpSlider(math.round(math.clamp((inp.Position.X-tA.X)/tS.X,0,1)*9)+1)
  end
 end)
 ascTpTrackBtn.InputChanged:Connect(function(inp)
  if not _ascTpDrag then return end
  if inp.UserInputType~=Enum.UserInputType.MouseMovement and inp.UserInputType~=Enum.UserInputType.Touch then return end
  local tA=ascTpTrackBtn.AbsolutePosition; local tS=ascTpTrackBtn.AbsoluteSize
  UpdateAscTpSlider(math.round(math.clamp((inp.Position.X-tA.X)/tS.X,0,1)*9)+1)
 end)
 ascTpTrackBtn.InputEnded:Connect(function(inp)
  if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then
   _ascTpDrag=false
  end
 end)

 -- ============================================================
 -- ROW 12-13: PICK MODE (sama persis dengan AUTO RAID)
 -- ============================================================
 local APM_OPTS  = {"Default","By Rank","By Map","Hard","Easy","Manual"}
 local APM_KEYS  = {"default","byrank","bymap","hard","easy","manual"}
 local APM_COLORS= {
  Color3.fromRGB(148,195,255), -- Default: biru es
  Color3.fromRGB(200,120,255), -- By Rank: ungu
  Color3.fromRGB(100,200,100), -- By Map: hijau
  Color3.fromRGB(255,80,80),   -- Hard: merah
  Color3.fromRGB(80,220,80),   -- Easy: hijau muda
  Color3.fromRGB(255,180,50),  -- Manual: kuning
 }
 local APM_DESC  = {
  "Join Tower apapun tanpa filter",
  "Filter by Preferred Rank",
  "Filter by Preferred Map",
  "Selalu pilih Tower terbesar",
  "Selalu pilih Tower terkecil",
  "Setting manual: Map, Rank, Rune",
 }
 -- Unlock rule per mode (sama persis RAID):
 -- mapUnlock  : bymap, manual
 -- rankUnlock : byrank, manual
 -- runeUnlock : manual
 local APM_UNLOCK = {
  default = {map=false, rank=false, rune=false},
  byrank  = {map=false, rank=true,  rune=false},
  bymap   = {map=true,  rank=false, rune=false},
  hard    = {map=false, rank=false, rune=false},
  easy    = {map=false, rank=false, rune=false},
  manual  = {map=true,  rank=true,  rune=true},
 }
 local curAPM = 5  -- default: "easy"
 ASC.pickMode = APM_KEYS[curAPM]

 local ApplyAscPickModeLock -- forward declare

 local apmHdr = Label(ascInner,"PICK MODE",10,C.TXT3,Enum.Font.GothamBold)
 apmHdr.LayoutOrder = 12; apmHdr.Size = UDim2.new(1,0,0,14)
 local apmCard = Frame(ascInner, C.SURFACE, UDim2.new(1,0,0,40))
 apmCard.LayoutOrder = 13; Corner(apmCard,10); Stroke(apmCard,C.BORD,1.5,0.3); Padding(apmCard,6,6,10,10)
 local _apmKeyL = Label(apmCard,"Pick Mode",11,C.TXT2,Enum.Font.GothamBold)
 _apmKeyL.Size = UDim2.new(0,72,1,0)
 local apmDDBtn = Btn(apmCard, C.BG3, UDim2.new(1,-82,0,28))
 apmDDBtn.Position = UDim2.new(0,80,0.5,-14); Corner(apmDDBtn,6); Stroke(apmDDBtn,C.BORD,1.5,0.25)
 local apmDDLbl = Label(apmDDBtn," "..APM_OPTS[curAPM],11,APM_COLORS[curAPM],Enum.Font.GothamBold)
 apmDDLbl.Size = UDim2.new(1,-20,1,0)
 local apmArr = Label(apmDDBtn,"v",10,C.TXT3,Enum.Font.GothamBold,Enum.TextXAlignment.Center)
 apmArr.Size = UDim2.new(0,18,1,0); apmArr.Position = UDim2.new(1,-20,0,0)
 local apmDescLbl = Label(ascInner, APM_DESC[curAPM], 10, C.TXT3, Enum.Font.GothamBold)
 apmDescLbl.LayoutOrder = 14; apmDescLbl.Size = UDim2.new(1,0,0,14)

 apmDDBtn.MouseButton1Click:Connect(function()
  CloseActiveDD()
  local aP = apmDDBtn.AbsolutePosition; local aS = apmDDBtn.AbsoluteSize; local IH = 28
  local popup = Instance.new("Frame")
  popup.Parent = DDLayer; popup.BackgroundColor3 = C.DD_BG; popup.BorderSizePixel = 0
  popup.Size = UDim2.new(0,aS.X+10,0,#APM_OPTS*(IH+2)+12)
  popup.Position = UDim2.new(0,aP.X,0,aP.Y+aS.Y+3)
  popup.ZIndex = 9999; Corner(popup,10); Stroke(popup,C.BORD2,1.5,0.85)
  local ll = Instance.new("UIListLayout",popup)
  ll.Padding = UDim.new(0,2); ll.SortOrder = Enum.SortOrder.LayoutOrder
  Instance.new("UIPadding",popup).PaddingTop = UDim.new(0,4)
  for i, opt in ipairs(APM_OPTS) do
   local item = Instance.new("TextButton",popup)
   item.Size = UDim2.new(1,-8,0,IH); item.LayoutOrder = i
   item.BackgroundColor3 = i==curAPM and C.SURFACE or C.BG3
   item.BackgroundTransparency = i==curAPM and 0.18 or 0.42
   item.BorderSizePixel = 0; item.Text = ""; item.AutoButtonColor = false; item.ZIndex = 9999
   Instance.new("UICorner",item).CornerRadius = UDim.new(0,6)
   local iL = Instance.new("TextLabel",item)
   iL.Size = UDim2.new(1,-8,1,0); iL.Position = UDim2.new(0,8,0,0)
   iL.BackgroundTransparency = 1; iL.Text = opt; iL.TextSize = 12
   iL.Font = Enum.Font.Gotham; iL.TextColor3 = APM_COLORS[i]
   iL.TextXAlignment = Enum.TextXAlignment.Left; iL.ZIndex = 9999
   local ii = i
   item.MouseButton1Click:Connect(function()
    CloseActiveDD()
    curAPM = ii; ASC.pickMode = APM_KEYS[ii]
    apmDDLbl.Text = " "..APM_OPTS[ii]; apmDDLbl.TextColor3 = APM_COLORS[ii]
    apmDescLbl.Text = APM_DESC[ii]
    ApplyAscPickModeLock()
    task.defer(ResizeAscBody)
   end)
  end
  DDLayer.Visible = true
  _activeDDClose = function() popup:Destroy(); DDLayer.Visible=false end
 end)

 -- ============================================================
 --  APPLY ASC PICK MODE LOCK (sama persis dengan AUTO RAID)
 -- ============================================================
 local _ascPrefLocked  = false
 local _ascRankLocked  = false
 local _ascRuneLocked  = false

 local function SetAscFieldLock(card, lockLbl, keyLbl, ddBtn, locked)
  card.BackgroundTransparency = locked and 0.65 or 0.42
  if lockLbl then lockLbl.Visible = locked end
  if keyLbl  then keyLbl.TextColor3 = locked and C.TXT3 or C.TXT2 end
  if ddBtn   then
   ddBtn.BackgroundTransparency = locked and 0.72 or 0.25
   for _,ch in ipairs(ddBtn:GetDescendants()) do
    if ch:IsA("TextLabel") then ch.TextTransparency = locked and 0.5 or 0 end
   end
  end
 end

 -- Label gembok (dibuat di sini, setelah semua card sudah ada)
 local _ascPrefMapLockLbl = Instance.new("TextLabel", ascPrefMapCard)
 _ascPrefMapLockLbl.Size = UDim2.new(1,0,1,0); _ascPrefMapLockLbl.BackgroundTransparency = 1
 _ascPrefMapLockLbl.Text = "ðŸ”’ Hanya aktif di Manual mode"; _ascPrefMapLockLbl.TextSize = 10
 _ascPrefMapLockLbl.Font = Enum.Font.GothamBold; _ascPrefMapLockLbl.TextColor3 = C.TXT3
 _ascPrefMapLockLbl.ZIndex = 5; _ascPrefMapLockLbl.Visible = false

 local _ascRankLockLbl = Instance.new("TextLabel", ascRankCard)
 _ascRankLockLbl.Size = UDim2.new(1,0,1,0); _ascRankLockLbl.BackgroundTransparency = 1
 _ascRankLockLbl.Text = "ðŸ”’ Hanya aktif di Manual / By Rank"; _ascRankLockLbl.TextSize = 10
 _ascRankLockLbl.Font = Enum.Font.GothamBold; _ascRankLockLbl.TextColor3 = C.TXT3
 _ascRankLockLbl.ZIndex = 5; _ascRankLockLbl.Visible = false

 local _ascRuneLockLbl = Instance.new("TextLabel", ascRuneCard)
 _ascRuneLockLbl.Size = UDim2.new(1,0,1,0); _ascRuneLockLbl.BackgroundTransparency = 1
 _ascRuneLockLbl.Text = "ðŸ”’ Hanya aktif di Manual mode"; _ascRuneLockLbl.TextSize = 10
 _ascRuneLockLbl.Font = Enum.Font.GothamBold; _ascRuneLockLbl.TextColor3 = C.TXT3
 _ascRuneLockLbl.ZIndex = 5; _ascRuneLockLbl.Visible = false

 ApplyAscPickModeLock = function()
  local pm     = ASC.pickMode
  local unlock = APM_UNLOCK[pm] or {map=false, rank=false, rune=false}
  _ascPrefLocked = not unlock.map
  _ascRankLocked = not unlock.rank
  _ascRuneLocked = not unlock.rune

  SetAscFieldLock(ascPrefMapCard, _ascPrefMapLockLbl, ascPrefMapKeyL, ascPrefMapDDBtn, _ascPrefLocked)
  SetAscFieldLock(ascRankCard,    _ascRankLockLbl,    ascRankKeyL,    ascRankDDBtn,    _ascRankLocked)
  SetAscFieldLock(ascRuneCard,    _ascRuneLockLbl,    ascRuneKeyL,    ascRuneDDBtn,    _ascRuneLocked)

  -- Clear data field yang terkunci (sama seperti RAID)
  if _ascPrefLocked then
   for mn=1,26 do ASC.preferMaps[mn]=nil end
   if UpdateAscPrefMapLabel then UpdateAscPrefMapLabel() end
  end
  if _ascRankLocked then
   for _,g in ipairs(GRADE_LIST or {}) do ASC.runeGrades[g] = nil end
   RefreshAscRankLabel()
  end
  if _ascRuneLocked then
   ASC.runeMapTarget = 0; ASC.runeEnabled = false
   ascRuneDDVal.Text = " -- NOT SELECTED --"; ascRuneDDVal.TextColor3 = C.TXT3
  end
  task.defer(ResizeAscBody)
 end

 ApplyAscPickModeLock()
 task.defer(ResizeAscBody)
end -- end Auto Ascension do block


-- ============================================================
-- AUTO SIEGE - v97 [v54 FIX: dead code removed, _exitConfirmCount reset on alive>0, threshold 3->5]
-- Flow: EnterCityRaidMap -> GetRaidTeamInfos -> StartLocalPlayerTeleport -> LocalTpSuccess -> GetRaidTeamInfos
-- -> MA V2 serang semua enemy sampai habis -> GainRaidsRewards(1)
-- -> TipsPanel hide/restore -> MA biasa resume setelah 3 detik
-- Trigger: Listener notif UpdateCityRaidInfo + polling fallback tiap 30 detik
-- ============================================================

local SIEGE_DATA = {
 -- baseMapId = MapId map asal (Script Viewer confirmed)
 -- tpMapId = RaidId siege map (50201-50204)
 -- [v245 FIX] Nama map disesuaikan dengan MAP_NAMES (referensi resmi)
 [3] = {name="Map 3 - Shadow Castle", cityRaidId=1000001, tpMapId=50201, baseMapId=50003},
 [7] = {name="Map 7 - Demon Castle Tier 2", cityRaidId=1000002, tpMapId=50202, baseMapId=50007},
 [10] = {name="Map 10 - Plagueheart", cityRaidId=1000003, tpMapId=50203, baseMapId=50010},
 [13] = {name="Map 13 - Lava Hell", cityRaidId=1000004, tpMapId=50204, baseMapId=50013},
 [18] = {name="Map 18 - Golden Throne", cityRaidId=1000005, tpMapId=50205, baseMapId=50018},
}
local SIEGE_MAP_NUMS = {3, 7, 10, 13, 18}

SIEGE = {
 running = false,
 thread = nil,
 inMap = false,
 excludeMaps = {[3]=false,[7]=false,[10]=false,[13]=false,[18]=false},
 statusLbl = nil,
 dot = nil,
 countLbls = {},
 count = {[3]=0,[7]=0,[10]=0,[13]=0,[18]=0},
 countSummaryLbl = nil, -- [v41] single summary label
 killed = 0, -- [v150] FIX: inisialisasi killed agar tidak nil saat EnemyDeath event
 live = {}, -- {[cityRaidId] = mapNum} - diisi notif server
}

--  UI helpers 
_siegeSessionStart = nil -- waktu mulai siege session

SiegeStatus = function(msg, color)
 if SIEGE.statusLbl then
 local ts = ""
 if _siegeSessionStart then
 local dur = os.time() - _siegeSessionStart
 ts = string.format("[%02d:%02d:%02d] ", math.floor(dur/3600), math.floor(dur/60)%60, dur%60)
 end
 SIEGE.statusLbl.Text = ts..msg
 SIEGE.statusLbl.TextColor3 = color or C.TXT2
 end
 if SIEGE.dot then
 SIEGE.dot.BackgroundColor3 = color or Color3.fromRGB(100,100,100)
 end
end

SiegeCounterUpdate = function()
 if SIEGE.countSummaryLbl then
  local parts = {}
  for _, mn in ipairs(SIEGE_MAP_NUMS) do
   table.insert(parts, "M"..mn..":".. (SIEGE.count[mn] or 0))
  end
  SIEGE.countSummaryLbl.Text = table.concat(parts, "  ")
 end
end

StopSiege = function()
 SIEGE.running = false
 SIEGE.inMap = false
 _siegeInterrupt = false
 MODE:Release("siege")
 -- [FIX] Hard reset MODE jika masih stuck di siege
 if MODE.current == "siege" then MODE.current = "idle" end
 if SIEGE.thread then
 pcall(function() task.cancel(SIEGE.thread) end)
 SIEGE.thread = nil
 end
 SiegeStatus("[FLa] Idle", Color3.fromRGB(100,100,100))
end

-- ============================================================
--  Wakeup event untuk siege loop 
-- [v113] Listener UpdateCityRaidInfo sudah dipasang di awal script (pre-wait).
-- ConnectSiegeNotif hanya dipakai untuk reconnect di StartSiegeLoop.
-- [v54] _siegeNotifConn & ConnectSiegeNotif dihapus - sudah tidak dipakai (listener permanen di pre-listen block)
local _siegeWakeup = nil

--  Masuk Siege 
-- ============================================================
-- AUTO SIEGE - REWRITE
-- Flow:
-- 1. Tunggu SIEGE.live ada entry (dari UpdateCityRaidInfo listener)
-- 2. Tunggu RAID.inMap = false (raid selesai dulu)
-- 3. Set _siegeInterrupt = true (pause MA/Raid)
-- 4. EnterCityRaidMap + konfirmasi masuk via workspace MapId (bukan LocalPlayerTeleportSuccess)
-- 5. Attack loop sampai enemy habis (max 60s)
-- 6. GainRaidsRewards + TP keluar pakai StartTp/LocalTp
-- 7. Reset _siegeInterrupt = false, resume MA/Raid
-- ============================================================

-- Helper: cek apakah player sedang di dalam siege map
-- Sumber: workspace MapId (50201-50204) ATAU workspace.Map.CityRaidEnter (Dex confirmed)
-- ============================================================
-- AUTO SIEGE - REWRITE (WITH KASTA PRIORITY & HUKUM HARAM)
-- ============================================================

local function IsInSiegeMap()
    local ok, wm = pcall(function()
        return workspace:GetAttribute("MapId") or workspace:GetAttribute("mapId") or workspace:GetAttribute("CurrentMapId")
    end)
    if ok and type(wm) == "number" then
        if wm >= 50201 and wm <= 50205 then return true, wm end
    end
    local ok2, hasCRE = pcall(function()
        local mapFolder = workspace:FindFirstChild("Map")
        return mapFolder and mapFolder:FindFirstChild("CityRaidEnter") ~= nil
    end)
    if ok2 and hasCRE then return true, nil end
    if ok and type(wm) == "number" and wm >= 50001 then return false, wm end
    return false, nil
end

local function GetSiegeEnemies()
    -- [FIX v8] Deteksi musuh identik dengan GetEnemiesF() di panel Farm:
    -- Wajib punya EnemyGuid attribute + HumanoidRootPart + Humanoid.Health > 0
    -- TIDAK scan workspace.Heros (bisa false-detect hero player)
    -- TIDAK pakai fallback key Name..DebugId (menyebabkan musuh mati tetap terhitung)
    local list = {}
    local seen = {}
    local FOLDERS = {"Enemys", "EnemyCityRaid", "CityRaidEnemys", "Enemies", "Enemy"}
    local function _addSiegeEnemy(e)
        if not e:IsA("Model") then return end
        local g   = e:GetAttribute("EnemyGuid") or e:GetAttribute("BossGuid") or e:GetAttribute("Guid") or e:GetAttribute("GUID")
        local h   = e:FindFirstChild("HumanoidRootPart")
        local hum = e:FindFirstChildOfClass("Humanoid")
        if g and h and hum and hum.Health > 0 and not seen[g] then
            seen[g] = true
            table.insert(list, {model=e, guid=g, hrp=h, hasGuid=true})
        end
    end
    for _, fname in ipairs(FOLDERS) do
        local f = workspace:FindFirstChild(fname)
        if f then
            for _, e in ipairs(f:GetChildren()) do _addSiegeEnemy(e) end
        end
    end
    -- [v51-FIX] Fallback: scan workspace:GetChildren() jika semua folder kosong/tidak ada
    -- Penting untuk Siege & Dungeon agar tidak miss musuh saat folder name berubah di update game
    if #list == 0 then
        for _, obj in ipairs(workspace:GetChildren()) do
            _addSiegeEnemy(obj)
        end
    end
    return list
end

local function SiegeBlindFire()
    local targets = {}
    pcall(function()
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("Model") then
                local hum = obj:FindFirstChildOfClass("Humanoid")
                local hrp = obj:FindFirstChild("HumanoidRootPart")
                if hum and hum.Health > 0 and hrp then
                    local isPlayer = false
                    for _, p in ipairs(Players:GetPlayers()) do
                        if p.Character == obj then isPlayer = true; break end
                    end
                    if not isPlayer then table.insert(targets, {hrp=hrp, model=obj}) end
                end
            end
        end
    end)

    if #targets == 0 then return false end

    for _, t in ipairs(targets) do
        local pos = t.hrp.Position
        local pseudoGuid = t.model:GetAttribute("EnemyGuid") or t.model:GetAttribute("GUID") or t.model:GetAttribute("Guid") or t.model:GetAttribute("guid")
        local RE = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
        if pseudoGuid and RE then
            pcall(function() if RE:FindFirstChild("Atk") then RE.Atk:FireServer({attackEnemyGUID=pseudoGuid}) end end)
            pcall(function() if RE:FindFirstChild("Click") then RE.Click:InvokeServer({enemyGuid=pseudoGuid, enemyPos=pos}) end end)
            for _, hGuid in ipairs(HERO_GUIDS) do
                pcall(function()
                    if RE:FindFirstChild("HeroUseSkill") then
                        RE.HeroUseSkill:FireServer({heroGuid=hGuid, attackType=1, userId=MY_USER_ID, enemyGuid=pseudoGuid})
                    end
                end)
            end
        else
            pcall(function() if RE and RE:FindFirstChild("Atk") then RE.Atk:FireServer({attackEnemyPos=pos}) end end)
        end
        task.wait(0.05)
    end
    return true
end

local function SiegeAttackV2_Independent(onStatus, baseMapId)
    -- Scan HERO_GUIDS jika belum ada
    if #HERO_GUIDS == 0 then
        if onStatus then onStatus("[~] Scan HERO_GUIDS...") end
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
    end

    -- [FIX v8] Gunakan _deadG_Siege lokal agar tidak ganggu _deadG global (Mass Attack)
    local _deadG_Siege = {}

    -- Helper: cek apakah player sudah kembali ke baseMapId (server TP keluar)
    -- [FIX] _confirmedInSiege: hanya anggap "balik ke lobby" jika player PERNAH masuk 50201-50205 dulu
    -- Tanpa ini, cek range 50001-50020 bisa false-positive saat player masih di baseMapId sebelum masuk siege
    local _confirmedInSiege = false
    local function isBackAtBase()
        local ok, wm = pcall(function()
            return workspace:GetAttribute("MapId") or workspace:GetAttribute("mapId") or workspace:GetAttribute("CurrentMapId")
        end)
        if ok and type(wm) == "number" then
            -- Track: player sudah masuk siege map?
            if wm >= 50201 and wm <= 50205 then _confirmedInSiege = true end
            -- Prioritas 1: exact baseMapId
            if baseMapId and wm == baseMapId and _confirmedInSiege then return true end
            -- Prioritas 2: range lobby 50001-50020 HANYA setelah pernah masuk siege
            if _confirmedInSiege and wm >= 50001 and wm <= 50020 then return true end
        end
        return false
    end
    local totalTime   = 0
    local MAX_TIME    = 300
    local WARMUP      = 3.0
    local STUCK_LIMIT = 5.0  -- sama dengan Mass Attack: 5 detik tanpa kill = skip

    -- lastKill = jumlah SIEGE.killed saat masuk fungsi ini
    local lastKill    = SIEGE.killed
    local stuckT      = 0
    local _everSawEnemy = false

    -- Pasang listener EnemyDeath lokal untuk Siege (tidak ganggu _deadG global)
    local _deathConn = nil
    if RE.Death then
        _deathConn = RE.Death.OnClientEvent:Connect(function(d)
            if not d then return end
            local g = d.enemyGuid or d.guid
            if g then _deadG_Siege[g] = true end
        end)
    end

    local function cleanup()
        if _deathConn then _deathConn:Disconnect(); _deathConn = nil end
        SIEGE.inMap     = false
        _siegeInterrupt = false
        MODE:Release("siege")
    end

    -- ============================================================
    -- FASE 1: Tunggu musuh muncul (maks 10 detik, sama dengan MA)
    -- ============================================================
    local wt = 0
    while wt < 10 and SIEGE.running and SIEGE.inMap do
        -- Track konfirmasi masuk siege
        pcall(function()
            local wm = workspace:GetAttribute("MapId") or workspace:GetAttribute("mapId") or workspace:GetAttribute("CurrentMapId")
            if type(wm) == "number" and wm >= 50201 and wm <= 50205 then _confirmedInSiege = true end
        end)
        local enemies = GetSiegeEnemies()
        -- filter dead lokal
        local liveNow = 0
        for _, e in ipairs(enemies) do
            if not _deadG_Siege[e.guid] then liveNow = liveNow + 1 end
        end
        if liveNow > 0 then break end
        if onStatus then onStatus("[~] Nunggu musuh Siege... ("..math.floor(10-wt).."s)") end
        task.wait(0.4); wt = wt + 0.4
        totalTime = totalTime + 0.4
    end

    if not SIEGE.running or not SIEGE.inMap then
        cleanup(); return "loop_ended"
    end

    -- Cek setelah tunggu: kalau tetap kosong -> anggap selesai langsung
    do
        local enemies = GetSiegeEnemies()
        local liveNow = 0
        for _, e in ipairs(enemies) do
            if not _deadG_Siege[e.guid] then liveNow = liveNow + 1 end
        end
        if liveNow == 0 then
            if onStatus then onStatus("[OK] Tidak ada musuh, SIEGE DONE") end
            cleanup(); return "exited_clean"
        end
    end

    -- ============================================================
    -- FASE 2: Attack loop - logika identik Mass Attack (Kill All)
    -- Keluar jika:
    --   A) alive == 0  -> langsung sukses (tanpa timer tambahan)
    --   B) Tidak ada kill baru dalam STUCK_LIMIT detik -> skip
    --   C) Timeout MAX_TIME
    -- ============================================================
    while SIEGE.running and SIEGE.inMap do
        totalTime = totalTime + 0.08

        -- [FIX GODMODE] Guard realtime: STOP jika player sudah kembali ke basemap (50001-50020)
        -- Mencegah Siege terus menyerang musuh di portal basemap setelah keluar dari Siege map
        do
            local _ok, _wm = pcall(function()
                return workspace:GetAttribute("MapId") or workspace:GetAttribute("mapId") or workspace:GetAttribute("CurrentMapId")
            end)
            if _ok and type(_wm) == "number" then
                if _wm >= 50001 and _wm <= 50020 then
                    -- Player sudah di basemap, stop attack siege
                    cleanup(); return "exited_clean"
                end
            end
        end

        -- Timeout global
        if totalTime >= MAX_TIME then
            if onStatus then onStatus("[!] Timeout "..MAX_TIME.."s - Force OUT") end
            cleanup(); return "timeout"
        end

        -- Ambil musuh hidup dari workspace (sama persis logika MA Kill All)
        local rawEnemies = GetSiegeEnemies()
        local alive = 0
        local targets = {}
        for _, e in ipairs(rawEnemies) do
            if not _deadG_Siege[e.guid] then
                alive = alive + 1
                table.insert(targets, e)
            end
        end

        -- -- Kondisi UTAMA: Server sudah TP player keluar ke baseMapId --
        if isBackAtBase() then
            if onStatus then onStatus("[OK] Server TP keluar - Siege DONE!") end
            -- [FIX] Panggil GainRaidsRewards untuk trigger reward dari server
            if RE.GainRaidsRewards then
                pcall(function() RE.GainRaidsRewards:InvokeServer(1) end)
            end
            cleanup(); return "exited_clean"
        end

        -- -- Kondisi A: musuh habis tapi belum di-TP server (fallback) --
        if alive == 0 and _everSawEnemy then
            if onStatus then onStatus("[..] Musuh habis, tunggu server TP keluar...") end
            -- Tunggu server TP max 2 detik
            local _waitOut = 0
            while _waitOut < 2 and SIEGE.running do
                task.wait(0.3); _waitOut = _waitOut + 0.3
                if isBackAtBase() then
                    if onStatus then onStatus("[OK] Server TP keluar - Siege DONE!") end
                    cleanup(); return "exited_clean"
                end
            end
            -- Timeout tunggu TP -> anggap selesai juga
            if onStatus then onStatus("[OK] Siege DONE (timeout tunggu TP)") end
            cleanup(); return "exited_clean"
        end

        -- Ada musuh -> serang semua
        _everSawEnemy = true
        stuckT = 0  -- reset stuck karena masih ada musuh (berarti belum habis)

        -- Cek apakah kill bertambah (dari SIEGE.killed yang di-update oleh EnemyDeath global)
        if SIEGE.killed > lastKill then
            lastKill = SIEGE.killed
            stuckT   = 0
        else
            stuckT = stuckT + 0.08
            -- -- Kondisi B: tidak bisa bunuh 1 musuh dalam STUCK_LIMIT detik -> skip --
            if stuckT >= STUCK_LIMIT then
                if onStatus then onStatus("[!] Stuck "..STUCK_LIMIT.."s - Force exit Siege") end
                cleanup(); return "stuck_exit"
            end
        end

        if onStatus then onStatus("[S] "..alive.." musuh ("..math.floor(totalTime).."s) stuck:"..string.format("%.1f",stuckT).."s") end

        -- Serang semua target
        for _, e in ipairs(targets) do
            if e.model and e.model.Parent then
                local hrp = e.model:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local g, pos = e.guid, hrp.Position
                    task.spawn(function()
                        pcall(function() FireAllDamage(g, pos) end)
                        if #HERO_GUIDS > 0 then
                            pcall(function() FireHeroRemotes(g, pos) end)
                        end
                    end)
                end
            end
        end

        task.wait(0.08)
    end

    cleanup()
    return "loop_ended"
end

StartSiegeLoop = function()
    if SIEGE.running then StopSiege() end
    SIEGE.running = true
    SIEGE.inMap = false
    SIEGE.killed = 0
    _siegeSessionStart = os.time()
    for _, mn in ipairs(SIEGE_MAP_NUMS) do SIEGE.count[mn] = 0 end
    SiegeCounterUpdate()
    -- [FIX] Gold Magnet + Drop Collector
    StartDestroyWorker(function() return SIEGE.running end)
    StopGoldMagnet()
    StartInstantGoldCollector(true)
    StartGoldMagnet(function() return SIEGE.running end)

    if _siegeWakeup then pcall(function() _siegeWakeup:Destroy() end) end
    _siegeWakeup = Instance.new("BindableEvent")
    if _siegeWakeup then pcall(function() _siegeWakeup:Fire() end) end
    
    task.spawn(function()
        if _pollSiegeLive then _pollSiegeLive("toggle_on") end
    end)

    SIEGE.thread = task.spawn(function()
        while SIEGE.running do
            repeat
            
            -- [HUKUM NGALAH: PRIORITAS KASTA TERTINGGI]
            -- Jika Auto Dungeon nyala dan sedang di map, Siege WAJIB diam!
            if DUNGEON and DUNGEON.inMap then
                SiegeStatus("[!] PAUSE: Menunggu Auto Dungeon...", Color3.fromRGB(255,100,100))
                task.wait(2)
                break
            end

            local targetMap = nil
            for _, mn in ipairs(SIEGE_MAP_NUMS) do
                if not (SIEGE.excludeMaps and SIEGE.excludeMaps[mn]) then
                    local cid = SIEGE_DATA[mn].cityRaidId
                    if SIEGE.live[cid] then targetMap = mn; break end
                end
            end

            if not targetMap then
                local featStr = ""
                if MA.running then featStr = ".." end
                if RAID.running then featStr = featStr..".." end
                local exNames = {}
                if SIEGE.excludeMaps then
                    for _, mn in ipairs(SIEGE_MAP_NUMS) do
                        if SIEGE.excludeMaps[mn] then table.insert(exNames,"M"..mn) end
                    end
                end
                local exStr = #exNames > 0 and (" skip:"..table.concat(exNames,",")) or ""
                SiegeStatus("[..] Waiting Siege"..exStr..featStr.."...", Color3.fromRGB(255,200,60))
                if SIEGE.dot then SIEGE.dot.BackgroundColor3 = Color3.fromRGB(255,200,60) end
                local conn = _siegeWakeup.Event:Connect(function() end)
                task.wait(1); conn:Disconnect()
                break
            end

            local d = SIEGE_DATA[targetMap]
            -- [GUARD v50] Tunggu SEMUA fitur lain selesai sebelum masuk Siege
            do
                local _sGuard = 0
                while SIEGE.running and _sGuard < 90 do
                    local _busy, _who = IsAnyMapActive()
                    local _selfBusy = (_who == "siege")
                    if not _busy or _selfBusy then break end
                    SiegeStatus("[||] Tunggu "..(_who or "?").." selesai...", Color3.fromRGB(255,140,0))
                    task.wait(0.5); _sGuard = _sGuard + 0.5
                end
                if not SIEGE.running then break end
            end

            _siegeInterrupt = true
            if not MODE:WaitAndRequest("siege", 15) then
                _siegeInterrupt = false
                task.wait(2); break
            end
                -- [FIX v39] TP ke BaseMap dulu, tunggu konfirmasi sebelum EnterCityRaidMap
                local baseMapId = d.baseMapId -- gunakan baseMapId dari SIEGE_DATA (lebih reliable)
                if baseMapId then
                    SiegeStatus(("[TP] BaseMap %d (for %s)..."):format(baseMapId, d.name), Color3.fromRGB(255,200,100))
                    pcall(function() RE.LocalTp:FireServer({mapId = baseMapId}) end)
                    
                    -- [FIX v39] Timeout diperbesar: 1s -> 5s (Map 7/10/13 butuh lebih lama load)
                    local tpWait = 0
                    while tpWait < 5 and SIEGE.running do
                        task.wait(0.5); tpWait = tpWait + 0.5
                        local curMap = workspace:GetAttribute("MapId") or workspace:GetAttribute("mapId") or workspace:GetAttribute("CurrentMapId")
                        if curMap == baseMapId then break end
                    end
                    local curMapNow = workspace:GetAttribute("MapId") or workspace:GetAttribute("mapId") or workspace:GetAttribute("CurrentMapId")
                    if curMapNow == baseMapId then
                        SiegeStatus(("[OK] TP %d sukses, stabilize..."):format(baseMapId), Color3.fromRGB(80,220,80))
                        task.wait(0.5) -- beri waktu server register posisi player di map
                    else
                        SiegeStatus(("[!] TP %d belum confirm (%s), lanjut..."):format(baseMapId, tostring(curMapNow)), Color3.fromRGB(255,140,0))
                    end
                end
                
                task.wait(0.3)
            if not SIEGE.running then _siegeInterrupt = false; MODE:Release("siege"); break end

            SiegeStatus("[>>] Masuk "..d.name.."...", Color3.fromRGB(180,120,255))
            if SIEGE.dot then SIEGE.dot.BackgroundColor3 = Color3.fromRGB(180,120,255) end

            -- Helper lokal: kirim seluruh sequence remote untuk masuk siege
            -- Dipanggil pertama kali + di-retry tiap 4 detik jika belum masuk
            local function _fireSiegeEntry()
                local _RE = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
                if not _RE then return false end
                local enterRe = _RE:FindFirstChild("EnterCityRaidMap")
                if not enterRe then return false end
                -- Step 1: EnterCityRaidMap (daftarkan player ke city raid di server)
                pcall(function() enterRe:FireServer(d.cityRaidId) end)
                task.wait(0.8)
                if not SIEGE.running then return false end
                -- Step 2: GetRaidTeamInfos (sync tim)
                local grtRe = _RE:FindFirstChild("GetRaidTeamInfos")
                if grtRe then task.spawn(function() pcall(function() grtRe:InvokeServer() end) end) end
                task.wait(0.3)
                -- Step 3: StartLocalPlayerTeleport TANPA hostId (confirmed v41)
                -- hostId menyebabkan server treat player sebagai host, bukan peserta
                -- -> count/timer/reward hilang karena tidak terdaftar sebagai participant
                local stpRe = _RE:FindFirstChild("StartLocalPlayerTeleport")
                if stpRe then pcall(function() stpRe:FireServer({mapId=d.tpMapId}) end) end
                task.wait(0.5)
                -- Step 4: EquipHeroWithData
                local eqRe = _RE:FindFirstChild("EquipHeroWithData")
                if eqRe then pcall(function() eqRe:FireServer() end) end
                task.wait(0.3)
                -- Step 5: LocalPlayerTeleportSuccess (konfirmasi ke server)
                local ltpRe = _RE:FindFirstChild("LocalPlayerTeleportSuccess")
                if ltpRe then task.spawn(function() pcall(function() ltpRe:InvokeServer() end) end) end
                task.wait(0.3)
                -- Step 6: GetRaidTeamInfos kedua (final sync)
                local grtRe2 = _RE:FindFirstChild("GetRaidTeamInfos")
                if grtRe2 then task.spawn(function() pcall(function() grtRe2:InvokeServer() end) end) end
                task.wait(0.3)
                return true
            end

            -- Cek remote tersedia sebelum mulai
            do
                local _RE0 = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
                if not (_RE0 and _RE0:FindFirstChild("EnterCityRaidMap")) then
                    _siegeInterrupt = false; MODE:Release("siege")
                    SiegeStatus("[!] EnterCityRaidMap Not Found - retry 5s...", Color3.fromRGB(255,100,60))
                    task.wait(5); break
                end
            end
            if not SIEGE.running then _siegeInterrupt = false; MODE:Release("siege"); break end

            -- Fire entry sequence pertama kali
            if not _fireSiegeEntry() then _siegeInterrupt = false; MODE:Release("siege"); break end
            if not SIEGE.running then _siegeInterrupt = false; MODE:Release("siege"); break end

            -- Tunggu konfirmasi masuk siege, retry fire tiap 4 detik jika belum masuk (max 15s total)
            SiegeStatus("[FLa] Waiting Enter Siege...", Color3.fromRGB(180,120,255))
            local _entered = false
            local _entWait = 0
            local _sinceLastFire = 2.5 -- sudah fire di atas, beri jeda 4s sebelum retry pertama
            while not _entered and _entWait < 15 and SIEGE.running do
                task.wait(0.5); _entWait = _entWait + 0.5; _sinceLastFire = _sinceLastFire + 0.5
                -- Cek 1: MapId sudah di range Siege (50201-50205)
                local inSiege, _ = IsInSiegeMap()
                if inSiege then _entered = true; break end
                -- Cek 2: Musuh Siege sudah spawn
                if #GetSiegeEnemies() > 0 then _entered = true; break end
                -- Retry fire jika sudah 4 detik sejak fire terakhir dan belum masuk
                if _sinceLastFire >= 4.0 then
                    SiegeStatus("[~] Retry Enter "..d.name.."...", Color3.fromRGB(255,200,60))
                    _sinceLastFire = 0
                    if not _fireSiegeEntry() then break end
                end
            end

            if not _entered then
                _siegeInterrupt = false; MODE:Release("siege")
                SiegeStatus("[!] Failure Enter - retry 3s...", Color3.fromRGB(255,100,60))
                task.wait(3); break
            end

            SIEGE.inMap = true

            -- [FIX SIEGE PANEL] Restore panel Siege/CityRaid yang sudah terlanjur di-hide
            -- oleh _hideUIOn sebelum SIEGE.inMap = true di-set.
            -- Tanpa ini: panel Count/Timer/Reward tidak tampil -> reward tidak trigger.
            pcall(function()
                local _SIEGE_KW = {
                    "cityraid","city_raid","garrisoncityraid","garrisonboss",
                    "siege","cityraidpanel","cityraidenterpanel",
                    "raidcityresult","garrisonraidresult","citycount","citytimer",
                }
                for _, gui in ipairs(PG:GetChildren()) do
                    pcall(function()
                        if not gui or not gui.Parent then return end
                        local n = gui.Name:lower()
                        local isSiege = false
                        for _, kw in ipairs(_SIEGE_KW) do
                            if n:find(kw, 1, true) then isSiege = true; break end
                        end
                        if isSiege then
                            if gui:IsA("ScreenGui") or gui:IsA("GuiBase2d") then
                                gui.Enabled = true
                            elseif gui:IsA("GuiObject") then
                                gui.Visible = true
                            end
                        end
                    end)
                end
            end)
            SiegeStatus("[S] "..d.name.." - Masuk map, standby 2s...", Color3.fromRGB(255,200,60))
            if SIEGE.dot then SIEGE.dot.BackgroundColor3 = Color3.fromRGB(255,200,60) end
            task.wait(2)  -- jeda 2 detik setelah benar-benar masuk map sebelum serang
            if not SIEGE.running then SIEGE.inMap = false; break end

            SiegeStatus("[S] "..d.name.." - Attack!", Color3.fromRGB(80,220,80))
            if SIEGE.dot then SIEGE.dot.BackgroundColor3 = Color3.fromRGB(80,220,80) end

            local siegeResult = SiegeAttackV2_Independent(function(msg)
                SiegeStatus("[S] "..msg, Color3.fromRGB(80,220,80))
            end, d.baseMapId)
            if not SIEGE.running then break end

            SIEGE.inMap = false
            _siegeInterrupt = false
            MODE:Release("siege")

            task.wait(0.3)
            SIEGE.live[d.cityRaidId] = nil
            if _siegeChatOpen then _siegeChatOpen[targetMap] = false end
            SIEGE.count[targetMap] = (SIEGE.count[targetMap] or 0) + 1
            SiegeCounterUpdate()
            _siegeInterrupt = false
            MODE:Release("siege")
            SiegeStatus("[OK] "..d.name.." SUCCES! Waiting Next Siege...", Color3.fromRGB(100,255,150))
            if SIEGE.dot then SIEGE.dot.BackgroundColor3 = Color3.fromRGB(255,200,60) end
            task.wait(2)
            until true
        end 

        _siegeInterrupt = false
        MODE:Release("siege")
        SIEGE.running = false
        SIEGE.inMap = false
        SiegeStatus("[.] Idle", Color3.fromRGB(100,100,100))
        if SIEGE.dot then SIEGE.dot.BackgroundColor3 = Color3.fromRGB(100,100,100) end
    end)
end


-- PANEL : AUTO SIEGE (UI) - di dalam panel Automation yang sama
-- ============================================================
do
 local p = Panels["autoraid"]
 if not p then return end

 -- 
 -- AUTO SIEGE - Collapsible (seperti Auto Raid)
 -- 
 local siegeOpen = false

 local siegeHeader = Btn(p, C.SURFACE, UDim2.new(1,0,0,42))
 siegeHeader.LayoutOrder = 20; Corner(siegeHeader,10); Stroke(siegeHeader,C.BORD, 1.5,0.88)
 local siegeArrow = Label(siegeHeader,">",13,C.ACC,Enum.Font.GothamBold)
 siegeArrow.Size = UDim2.new(0,22,1,0); siegeArrow.Position = UDim2.new(0,10,0,0)
 local siegeHeaderLbl = Label(siegeHeader,"Auto Siege",14,C.TXT,Enum.Font.GothamBold)
 siegeHeaderLbl.Size = UDim2.new(1,-50,1,0); siegeHeaderLbl.Position = UDim2.new(0,34,0,0)

 local siegeBody = Frame(p, C.BG2, UDim2.new(1,0,0,0))
 siegeBody.LayoutOrder = 21; siegeBody.ClipsDescendants = true
 Corner(siegeBody,10); Stroke(siegeBody,C.BORD, 1.5,0.25); siegeBody.Visible = false

 local siegeInner = Frame(siegeBody, C.BLACK, UDim2.new(1,-16,0,0))
 siegeInner.BackgroundTransparency = 1; siegeInner.Position = UDim2.new(0,8,0,8)
 local siegeLayout = New("UIListLayout",{Parent=siegeInner,SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,6)})

 local function ResizeSiegeBody()
 siegeLayout:ApplyLayout()
 local h = siegeLayout.AbsoluteContentSize.Y + 16
 siegeInner.Size = UDim2.new(1,0,0,h)
 siegeBody.Size = UDim2.new(1,0,0,h+16)
 end

 siegeHeader.MouseButton1Click:Connect(function()
 siegeOpen = not siegeOpen; siegeBody.Visible = siegeOpen
 siegeArrow.Text = siegeOpen and "v" or ">"
 if siegeOpen then task.defer(ResizeSiegeBody) end
 end)

 -- Gunakan siegeInner sebagai parent untuk semua konten siege
 local p = siegeInner -- shadow p agar kode di bawah tetap pakai p

 -- Status bar
 local statusCard = Frame(p, C.BG3, UDim2.new(1,0,0,32))
 statusCard.LayoutOrder = 0; Corner(statusCard, 10); Stroke(statusCard,C.ACC, 1.5,0.3)
 SIEGE.dot = Frame(statusCard, Color3.fromRGB(100,100,100), UDim2.new(0,8,0,8))
 SIEGE.dot.Position = UDim2.new(0,8,0.5,-4); Corner(SIEGE.dot,4)
 SIEGE.statusLbl = Label(statusCard,"Idle - SELECT MAP",10,C.TXT2,Enum.Font.GothamBold)
 SIEGE.statusLbl.Size = UDim2.new(1,-24,1,0)
 SIEGE.statusLbl.Position = UDim2.new(0,22,0,0)
 SIEGE.statusLbl.TextTruncate = Enum.TextTruncate.AtEnd

 -- Toggle utama - capture SetState (pill+knob visual) ke global _setSiegeToggle
 do
  local _row, _set, _vis = ToggleRow(p,"Auto Siege","ON = Waiting Enter SIEGE",1,function(on)
   _siegeToggleState = on
   if on then StartSiegeLoop() else StopSiege() end
  end)
  _setSiegeToggle = _set
  _visSiege = _vis
 end

 -- [v41] Count ringkas: 1 baris teks "M3:0  M7:0  M10:0  M13:0  M18:0"
 local cntCard = Frame(p, C.SURFACE, UDim2.new(1,0,0,26))
 cntCard.LayoutOrder = 2; Corner(cntCard, 8); Stroke(cntCard,C.BORD, 1.5,0.5)
 New("UIPadding",{Parent=cntCard,PaddingLeft=UDim.new(0,10),PaddingRight=UDim.new(0,10)})
 local cntSummary = Label(cntCard,"M3:0  M7:0  M10:0  M13:0  M18:0",9,C.ACC2,Enum.Font.GothamBold,Enum.TextXAlignment.Left)
 cntSummary.Size = UDim2.new(1,0,1,0)
 SIEGE.countSummaryLbl = cntSummary

    -- ============================================================
    -- EXCLUDE MAP: Dropdown list pilih map yang di-skip
    -- ============================================================

    -- Dropdown button + list
    local ddCard = Frame(p, C.SURFACE, UDim2.new(1,0,0,0))
    ddCard.LayoutOrder = 3; ddCard.AutomaticSize = Enum.AutomaticSize.Y
    Corner(ddCard, 10); Stroke(ddCard,C.BORD, 1.5,0.5)
    New("UIPadding",{Parent=ddCard,PaddingTop=UDim.new(0, 10),PaddingBottom=UDim.new(0, 10),PaddingLeft=UDim.new(0, 10),PaddingRight=UDim.new(0, 10)})

    local ddInner = Frame(ddCard, C.BLACK, UDim2.new(1,0,0,0))
    ddInner.BackgroundTransparency = 1; ddInner.AutomaticSize = Enum.AutomaticSize.Y
    New("UIListLayout",{Parent=ddInner,SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,6)})

    -- Label judul
    local ddTitleRow = Frame(ddInner, C.BLACK, UDim2.new(1,0,0,16))
    ddTitleRow.BackgroundTransparency = 1; ddTitleRow.LayoutOrder = 0
    local ddTitleLbl = Label(ddTitleRow,"Exclude Map (Skip Siege):",10,C.TXT3,Enum.Font.GothamBold)
    ddTitleLbl.Size = UDim2.new(1,0,1,0)

    -- Dropdown button
    local ddBtn = Btn(ddInner, C.BG3, UDim2.new(1,0,0,32))
    ddBtn.LayoutOrder = 1; Corner(ddBtn, 10); Stroke(ddBtn,C.BORD, 1.5,0.5)
    local ddBtnLbl = Label(ddBtn,"  SELECT MAP to SKIP...",11,C.TXT2,Enum.Font.Gotham,Enum.TextXAlignment.Left)
    ddBtnLbl.Size = UDim2.new(1,-30,1,0)
    ddBtnLbl.Position = UDim2.new(0,0,0,0)
    local ddArrow = Label(ddBtn,"v",11,C.TXT3,Enum.Font.GothamBold,Enum.TextXAlignment.Right)
    ddArrow.Size = UDim2.new(0,24,1,0)
    ddArrow.Position = UDim2.new(1,-26,0,0)

    -- List container (dropdown menu, collapse/expand)
    local ddList = Frame(ddInner, C.BG2, UDim2.new(1,0,0,0))
    ddList.LayoutOrder = 2; ddList.AutomaticSize = Enum.AutomaticSize.Y
    ddList.Visible = false; Corner(ddList, 10); Stroke(ddList,C.BORD, 1.5,0.3)
    New("UIPadding",{Parent=ddList,PaddingTop=UDim.new(0,4),PaddingBottom=UDim.new(0,4),PaddingLeft=UDim.new(0,6),PaddingRight=UDim.new(0,6)})
    New("UIListLayout",{Parent=ddList,SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,3)})

    local MAP_NAMES_SIEGE = {
        [3]  = "Map 3  - Shadow Castle",
        [7]  = "Map 7  - Demon Castle Tier 2",
        [10] = "Map 10 - Plagueheart",
        [13] = "Map 13 - Lava Hell",
        [18] = "Map 18 - Golden Throne",
    }

    -- Helper: update label ringkasan di button
    local function updateDdLabel()
        local exNames = {}
        for _, mn in ipairs(SIEGE_MAP_NUMS) do
            if SIEGE.excludeMaps[mn] then table.insert(exNames,"Map "..mn) end
        end
        if #exNames == 0 then
            ddBtnLbl.Text = "  ALL MAP ACTIVE"
            ddBtnLbl.TextColor3 = C.GRN
        else
            ddBtnLbl.Text = "  Skip: "..table.concat(exNames,", ")
            ddBtnLbl.TextColor3 = Color3.fromRGB(255,160,60)
        end
    end
    _updateSiegeDdLabel = updateDdLabel  -- expose ke tombol gabungan

    -- Buat row untuk tiap map
    local itemRefs = {}
    _siegeItemRefs = itemRefs  -- expose ke tombol gabungan
    for _, mn in ipairs(SIEGE_MAP_NUMS) do
        local mn_l = mn
        local row = Btn(ddList, C.SURFACE, UDim2.new(1,0,0,30))
        row.LayoutOrder = mn; Corner(row,6); row.AutoButtonColor = false

        -- Checkbox indicator
        local chk = Frame(row, C.BG3, UDim2.new(0,16,0,16))
        chk.Position = UDim2.new(0,6,0.5,-8); Corner(chk,4)
        Stroke(chk, C.BORD, 1.5, 0.3)
        local chkMark = Label(chk,"",10,Color3.fromRGB(255,255,255),Enum.Font.GothamBold,Enum.TextXAlignment.Center)
        chkMark.Size = UDim2.new(1,0,1,0)
        chkMark.Text = SIEGE.excludeMaps[mn] and "x" or ""

        -- Map name label
        local rowLbl = Label(row, MAP_NAMES_SIEGE[mn], 11, C.TXT, Enum.Font.Gotham, Enum.TextXAlignment.Left)
        rowLbl.Size = UDim2.new(1,-30,1,0)
        rowLbl.Position = UDim2.new(0,28,0,0)

        -- Badge "SKIP" / "MASUK"
        local badge = Frame(row, C.BG3, UDim2.new(0,44,0,18))
        badge.Position = UDim2.new(1,-50,0.5,-9); Corner(badge,5)
        local badgeLbl = Label(badge, SIEGE.excludeMaps[mn] and "SKIP" or "ENTER", 9,
            SIEGE.excludeMaps[mn] and Color3.fromRGB(255,120,60) or C.GRN,
            Enum.Font.GothamBold, Enum.TextXAlignment.Center)
        badgeLbl.Size = UDim2.new(1,0,1,0)

        itemRefs[mn] = {row=row, chkMark=chkMark, rowLbl=rowLbl, badge=badge, badgeLbl=badgeLbl}

        row.MouseButton1Click:Connect(function()
            SIEGE.excludeMaps[mn_l] = not SIEGE.excludeMaps[mn_l]
            local excl = SIEGE.excludeMaps[mn_l]
            -- Update visual
            chkMark.Text = excl and "x" or ""
            chk.BackgroundColor3 = excl and Color3.fromRGB(180,50,50) or C.BG3
            badge.BackgroundColor3 = excl and Color3.fromRGB(60,20,20) or Color3.fromRGB(20,60,30)
            badgeLbl.Text = excl and "SKIP" or "ENTER"
            badgeLbl.TextColor3 = excl and Color3.fromRGB(255,120,60) or C.GRN
            rowLbl.TextColor3 = excl and C.DIM or C.TXT
            TweenService:Create(row, TweenInfo.new(0.12), {
                BackgroundColor3 = excl and Color3.fromRGB(50,20,20) or C.SURFACE
            }):Play()
            updateDdLabel()
        end)
    end
    updateDdLabel()

    -- Toggle dropdown open/close
    local ddOpen = false
    ddBtn.MouseButton1Click:Connect(function()
        ddOpen = not ddOpen
        ddList.Visible = ddOpen
        ddArrow.Text = ddOpen and "^" or "v"
        task.defer(ResizeSiegeBody)
    end)

    task.defer(ResizeSiegeBody)


end


-- ============================================================
-- AUTO DUNGEON - Tower Defense (Map 5 -> MapId 50303)
-- Source: TowerManager client script (decompiled)
-- Event server: ChangeTowerState {towerState, endTimestamp}
-- towerState: 1=WaitPhase(tutup), 2=PreparatoryPhase(OPEN 30dtk), 3=BattlePhase(sedang battle)
-- Masuk : StartLocalPlayerTeleport {mapId=50303} + LocalPlayerTeleportSuccess
-- Keluar : StartLocalPlayerTeleport {mapId=50005}
-- Prioritas tertinggi di Automation (di atas MA, Raid, Siege)
-- ============================================================

DUNGEON = {
 running = false,
 inMap = false,
 thread = nil,
 -- State dari server
 towerState = 1, -- 1=Wait 2=Prep(Open) 3=Battle
 endTimestamp = 0, -- UTC timestamp kapan fase berakhir
 -- Statistik
 count = 0, -- berapa kali sukses masuk
 killed = 0,
 -- UI
 statusLbl = nil,
 dot = nil,
 -- Timing: simpan os.time() saat terakhir dungeon BUKA, untuk re-entry cooldown
 lastOpenTime = 0,
 lastEntryTime = 0,
 -- Flag interrupt (pause semua fitur lain saat dalam dungeon)
 interrupt = false,
}
-- wakeup event (difire saat ChangeTowerState masuk)
local _dungeonWakeup = nil

-- Konstanta
local DUNGEON_MAP_ID = 50303 -- MapId dalam dungeon
local DUNGEON_LOBBY_ID = 50005 -- MapId Map 5 (lobby dungeon)
local DUNGEON_WAIT_ENEMY = 30 -- detik tunggu enemy muncul setelah masuk
local DUNGEON_MAX_TIME = 3600 -- 60 menit max di dalam dungeon
local DUNGEON_KILL_TIMEOUT = 120 -- 2 menit: kalau 1 enemy tidak mati -> TP keluar
local DUNGEON_COOLDOWN = 3600 -- 60 menit cooldown setelah keluar

DungeonStatus = function(msg, color)
 if DUNGEON.statusLbl then
 DUNGEON.statusLbl.Text = msg
 DUNGEON.statusLbl.TextColor3 = color or C.TXT2
 end
 if DUNGEON.dot then
 DUNGEON.dot.BackgroundColor3 = color or Color3.fromRGB(100,100,100)
 end
end

local function IsInDungeonMap()
 local ok, wm = pcall(function()
 return workspace:GetAttribute("MapId") or workspace:GetAttribute("mapId") or workspace:GetAttribute("CurrentMapId")
 end)
 if ok and type(wm) == "number" then
 if wm == DUNGEON_MAP_ID then return true, wm end
 end
 -- Fallback: cek folder Map di workspace
 local ok2, hasMap = pcall(function()
 local mf = workspace:FindFirstChild("Map")
 return mf and mf:FindFirstChild("MessageBoard") ~= nil
 end)
 if ok2 and hasMap then return true, nil end
 -- [FIX v38] Fallback tambahan: cek ada enemy di workspace.Enemys
 local ok3, enemies = pcall(function()
 return #workspace:FindFirstChild("Enemys"):GetChildren() > 3
 end)
 if ok3 and enemies then return true, nil end
 if DUNGEON and DUNGEON.inMap then return true, nil end
 return false, nil
end

-- Listener ChangeTowerState dari server
-- Dipasang satu kali setelah GUI load
local _dungeonListenerReady = false
local function ConnectDungeonListener()
 if _dungeonListenerReady then return end
 _dungeonListenerReady = true

 -- Method 1: coba lewat NotifyManager event (nama: ChangeTowerState)
 -- Method 2: hook OnClientEvent di semua RemoteEvent bernama relevan
 -- Karena game pakai internal event bus, kita hook via __namecall + polling workspace

 -- Coba pasang via Remotes (kalau ada ChangeTowerState sebagai RemoteEvent)
 local re = Remotes:FindFirstChild("ChangeTowerState") or Remotes:FindFirstChild("UpdateTowerState") or Remotes:FindFirstChild("TowerStateUpdate")
 if re and re:IsA("RemoteEvent") then
 re.OnClientEvent:Connect(function(data)
 if type(data) ~= "table" then return end
 local ts = data.towerState or data.state
 local et = data.endTimestamp or data.timestamp
 if ts then
 DUNGEON.towerState = ts
 if et then DUNGEON.endTimestamp = et end
 if _dungeonWakeup then pcall(function() _dungeonWakeup:Fire() end) end
 end
 end)
 return
 end

 -- Fallback: hook __namecall untuk tangkap FireClient/OnClientEvent dari game
 -- Sambil itu, poll workspace.Map.MessageBoard setiap 2s sebagai fallback state detector
 task.spawn(function()
 while ScreenGui and ScreenGui.Parent do
 task.wait(2)
 pcall(function()
 -- Deteksi PreparatoryPhase via TowerUnlock effect di workspace
 local mf = workspace:FindFirstChild("Map")
 local tp = mf and mf:FindFirstChild("TeleportPoints")
 local tower= tp and tp:FindFirstChild("Tower")
 if tower then
 local unlocked = tower:FindFirstChild("TowerUnlock") ~= nil
 local locked = tower:FindFirstChild("TowerLock") ~= nil
 if unlocked and not locked then
 if DUNGEON.towerState ~= 2 then
 DUNGEON.towerState = 2
 if _dungeonWakeup then pcall(function() _dungeonWakeup:Fire() end) end
 end
 elseif locked and not unlocked then
 if DUNGEON.towerState ~= 1 then
 DUNGEON.towerState = 1
 end
 end
 end
 end)
 end
 end)
end

StopDungeon = function()
 DUNGEON.running = false
 DUNGEON.inMap = false
 DUNGEON.interrupt = false
 _siegeInterrupt = false -- [v252] sync flag lama
 _raidInterrupt = false -- [v252] sync flag lama
 MODE:Release("dungeon") -- [v252]
 if DUNGEON.thread then
 pcall(function() task.cancel(DUNGEON.thread) end)
 DUNGEON.thread = nil
 end
 DungeonStatus("[.] Idle", Color3.fromRGB(100,100,100))
end

-- Attack loop dalam dungeon
local function DungeonAttackLoop(onStatus)
    -- ============================================================
    -- Identik dengan logika Mass Attack:
    -- - GetEnemies() scan semua folder (sama persis MA)
    -- - FireAllDamage + FireHeroRemotes (sama persis MA)
    -- - Berhenti jika keluar dari MapId 50303 (server TP keluar)
    -- - Berhenti jika 5 menit musuh tidak update di workspace
    -- ============================================================
    local _deadG_D      = {}    -- dead list lokal dungeon
    local noUpdateT     = 0    -- timer musuh tidak berkurang di workspace
    local NO_UPDATE_LIMIT = 300 -- 5 menit (300 detik)
    local lastAliveCount = -1  -- jumlah musuh hidup di iterasi sebelumnya

    -- Pasang listener EnemyDeath lokal (tidak ganggu _deadG global MA)
    local _deathConn = nil
    if RE.Death then
        _deathConn = RE.Death.OnClientEvent:Connect(function(d)
            if not d then return end
            local g = d.enemyGuid or d.guid
            if g then _deadG_D[g] = true end
        end)
    end

    local function cleanup()
        if _deathConn then _deathConn:Disconnect(); _deathConn = nil end
        DUNGEON.inMap = false
        DUNGEON.interrupt = false
        MODE:Release("dungeon")
    end

    -- -- FASE 1: Tunggu musuh muncul (maks 30 detik) --------------
    local wt = 0
    while wt < 30 and DUNGEON.running and DUNGEON.inMap do
        local inDungeon = IsInDungeonMap()
        if not inDungeon then
            if onStatus then onStatus("[!] Keluar map dungeon") end
            cleanup(); return "exited_by_server"
        end
        if #GetEnemies() > 0 then break end
        if onStatus then onStatus("[~] Tunggu musuh dungeon... (" .. math.floor(30-wt) .. "s)") end
        task.wait(0.4); wt = wt + 0.4
    end

    -- -- FASE 2: Attack loop (identik Mass Attack) -----------------
    while DUNGEON.running and DUNGEON.inMap do

        -- Hukum: wajib stop jika keluar dari MapId 50303
        local inDungeon = IsInDungeonMap()
        if not inDungeon then
            if onStatus then onStatus("[OK] Server TP keluar Dungeon - DONE!") end
            cleanup(); return "exited_by_server"
        end

        -- Ambil semua musuh hidup (SAMA PERSIS dengan GetEnemies() Mass Attack)
        local alive   = 0
        local targets = {}
        for _, e in ipairs(GetEnemies()) do
            if not _deadG_D[e.guid] then
                if e.model and e.model.Parent then
                    local hum = e.model:FindFirstChildOfClass("Humanoid")
                    if hum and hum.Health > 0 then
                        alive  = alive + 1
                        table.insert(targets, e)
                    end
                end
            end
        end

        -- -- Cek apakah jumlah musuh di workspace BERKURANG ----------
        -- Jika berkurang = ada kill = workspace update -> reset timer
        -- Jika tidak berkurang (musuh tetap/tidak mati) -> naikkan timer
        if lastAliveCount < 0 then
            -- Iterasi pertama, set baseline
            lastAliveCount = alive
        elseif alive < lastAliveCount then
            -- Musuh berkurang = ada kill = reset timer
            noUpdateT = 0
        else
            -- Musuh tidak berkurang -> naikkan timer
            noUpdateT = noUpdateT + 0.08
        end
        lastAliveCount = alive

        -- -- Cek timeout 5 menit --------------------------------------
        if noUpdateT >= NO_UPDATE_LIMIT then
            if onStatus then onStatus("[!] 5 menit musuh tidak berkurang - TP keluar Dungeon") end
            cleanup(); return "no_enemy_timeout"
        end

        -- -- Serang atau tunggu ----------------------------------------
        if alive > 0 then
            if onStatus then
                local sisa = math.floor(NO_UPDATE_LIMIT - noUpdateT)
                onStatus(string.format("[D] %d musuh dungeon (timeout: %ds)", alive, sisa))
            end
            for _, e in ipairs(targets) do
                if e.model and e.model.Parent then
                    local hrp = e.model:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        local g, pos = e.guid, hrp.Position
                        task.spawn(function()
                            pcall(function() FireAllDamage(g, pos) end)
                            if #HERO_GUIDS > 0 then
                                pcall(function() FireHeroRemotes(g, pos) end)
                            end
                        end)
                    end
                end
            end
        else
            -- Tidak ada musuh
            if onStatus then
                local sisa = math.floor(NO_UPDATE_LIMIT - noUpdateT)
                onStatus(string.format("[~] Map bersih, tunggu wave... (%ds)", sisa))
            end
        end

        task.wait(0.08)
    end

    cleanup()
    return "loop_ended"
end

-- TP keluar dungeon ke Map 5
local function DungeonTpOut()
 local startTpRe = Remotes:FindFirstChild("StartLocalPlayerTeleport")
 if startTpRe then
 pcall(function() startTpRe:FireServer({mapId = DUNGEON_LOBBY_ID}) end)
 end
 task.wait(0.3)
 -- Konfirmasi
 local ltpSucc = Remotes:FindFirstChild("LocalPlayerTeleportSuccess")
 if ltpSucc then
 task.spawn(function()
 pcall(function() ltpSucc:InvokeServer() end)
 end)
 end
end

-- Masuk dungeon
local function DungeonTpIn()
 local startTpRe = Remotes:FindFirstChild("StartLocalPlayerTeleport")
 if startTpRe then
 pcall(function() startTpRe:FireServer({mapId = DUNGEON_MAP_ID}) end)
 end
 task.wait(0.3)
 local ltpSucc = Remotes:FindFirstChild("LocalPlayerTeleportSuccess")
 if ltpSucc then
 task.spawn(function()
 pcall(function() ltpSucc:InvokeServer() end)
 end)
 end
end

StartDungeonLoop = function()
 if DUNGEON.running then StopDungeon() end
 DUNGEON.running = true
 DUNGEON.inMap = false
 DUNGEON.interrupt = false
    -- [FIX] Gold Magnet + Drop Collector
    StartDestroyWorker(function() return DUNGEON.running end)
    StopGoldMagnet()
    StartInstantGoldCollector(true)
    StartGoldMagnet(function() return DUNGEON.running end)

 if _dungeonWakeup then pcall(function() _dungeonWakeup:Destroy() end) end
 _dungeonWakeup = Instance.new("BindableEvent")

 ConnectDungeonListener()

 DUNGEON.thread = task.spawn(function()
 while DUNGEON.running do
 repeat

 -- 
 -- STEP 1: Cek cooldown sejak entry terakhir
 -- Cooldown 60 menit - tapi timing SYNC dengan server (os.time)
 -- 
 local now = os.time()
 local elapsed = now - DUNGEON.lastEntryTime
 local cooldownLeft = DUNGEON_COOLDOWN - elapsed

 if DUNGEON.lastEntryTime > 0 and cooldownLeft > 0 then
 local mm = math.floor(cooldownLeft / 60)
 local ss = cooldownLeft % 60
 DungeonStatus(string.format("[..] Cooldown %02d:%02d - Waiting Dungeon OPEN", mm, ss), Color3.fromRGB(255,200,60))
 if DUNGEON.dot then DUNGEON.dot.BackgroundColor3 = Color3.fromRGB(255,200,60) end

 -- Tunggu cooldown habis atau wakeup event (ChangeTowerState)
 local _wt = 0
 while DUNGEON.running and _wt < cooldownLeft do
 -- Cek apakah server beri sinyal OPEN (PreparatoryPhase)
 if DUNGEON.towerState == 2 then
 break
 end
 local _rem = DUNGEON_COOLDOWN - (os.time() - DUNGEON.lastEntryTime)
 if _rem <= 0 then break end
 local _mm = math.floor(_rem/60)
 local _ss = _rem % 60
 DungeonStatus(string.format("[..] Cooldown %02d:%02d | Dungeon state=%d", _mm, _ss, DUNGEON.towerState), Color3.fromRGB(255,200,60))
 local conn = _dungeonWakeup.Event:Connect(function() end)
 task.wait(1); conn:Disconnect()
 _wt = _wt + 1
 end
 if not DUNGEON.running then break end
 end

 -- 
 -- STEP 2: Tunggu state PreparatoryPhase (dungeon OPEN)
 -- Window hanya 30 detik! Harus masuk segera.
 -- 
 if DUNGEON.towerState ~= 2 then
 DungeonStatus("[..] Waiting Dungeon OPEN (PreparatoryPhase)...", Color3.fromRGB(255,200,60))
 if DUNGEON.dot then DUNGEON.dot.BackgroundColor3 = Color3.fromRGB(255,200,60) end
 local _wt2 = 0
 while DUNGEON.running and DUNGEON.towerState ~= 2 do
 local conn = _dungeonWakeup.Event:Connect(function() end)
 task.wait(1); conn:Disconnect()
 _wt2 = _wt2 + 1
 if _wt2 % 10 == 0 then
 -- Periodic check setiap 10 detik
 end
 end
 if not DUNGEON.running then break end
 end

 -- 
 -- STEP 3: PRIORITAS - Interrupt MA + Raid + Siege
 -- [v252] Dungeon priority max -> ForceSet override semua
 -- 
 MODE:ForceSet("dungeon") -- override apapun yang sedang jalan
 -- [GUARD v50] Tunggu fitur lain selesai max 10s sebelum force interrupt
 do
  local _dGuard = 0
  while _dGuard < 10 do
   local _busy, _who = IsAnyMapActive()
   if not _busy or _who == "dungeon" then break end
   DungeonStatus("[||] Tunggu "..(_who or "?").." selesai...", Color3.fromRGB(255,200,60))
   task.wait(0.5); _dGuard = _dGuard + 0.5
  end
 end
 DUNGEON.interrupt = true -- sync flag lama
 _siegeInterrupt = true
 _raidInterrupt = true

 -- Tunggu sebentar agar MA/Raid/Siege pause (mereka cek MODE.current)
 task.wait(0.5)
 if not DUNGEON.running then
 DUNGEON.interrupt = false; _siegeInterrupt = false; _raidInterrupt = false
 MODE:Release("dungeon")
 break
 end

 -- 
 -- STEP 4: Cek apakah sudah di dalam dungeon
 -- 
 local alreadyIn, _ = IsInDungeonMap()
 if not alreadyIn then
 DungeonStatus("[>>] ENTER dungeon...", Color3.fromRGB(180,120,255))
 if DUNGEON.dot then DUNGEON.dot.BackgroundColor3 = Color3.fromRGB(180,120,255) end

 DungeonTpIn()

 -- Tunggu konfirmasi masuk max 15 detik
 local _entered = false
 local _entWait = 0
 while not _entered and _entWait < 15 and DUNGEON.running do
 task.wait(0.3); _entWait = _entWait + 0.3
 local inD, _ = IsInDungeonMap()
 if inD then _entered = true; break end
 -- Fallback: cek ada enemy di workspace.Enemys
 if #GetSiegeEnemies() > 0 then _entered = true; break end
 end

 if not _entered then
 DungeonStatus("[!] Failure Enter - Waiting Next DUNGEON", Color3.fromRGB(255,100,60))
 DUNGEON.towerState = 1
 DUNGEON.interrupt = false
 _siegeInterrupt = false
 _raidInterrupt = false
 MODE:Release("dungeon") -- [v252]
 task.wait(3); break
 end
 else
 end

 -- 
 -- STEP 5: Attack loop
 -- 
 DUNGEON.inMap = true
 DUNGEON.lastEntryTime = os.time()
 DUNGEON.count = DUNGEON.count + 1
 DungeonStatus("[FLa] Dungeon - Attack ALL Enemy!", Color3.fromRGB(80,220,80))
 if DUNGEON.dot then DUNGEON.dot.BackgroundColor3 = Color3.fromRGB(80,220,80) end

 local result = DungeonAttackLoop(function(msg)
 DungeonStatus(msg, Color3.fromRGB(80,220,80))
 end)
 -- 
 -- STEP 6: Keluar dungeon
 -- Kalau low_damage atau timeout: TP manual ke Map 5
 -- Kalau exited_by_server: server sudah handle
 -- 
 DUNGEON.inMap = false

 if result == "low_damage" or result == "timeout" or result == "no_enemy_timeout" then
 DungeonStatus("[TP] Go to Map 5...", Color3.fromRGB(255,140,0))
 DungeonTpOut()
 task.wait(1.5)
 end

 -- Auto hide reward popup
 DungeonHideRewardPopup()

 -- Reset towerState ke WaitPhase (server akan update via ChangeTowerState)
 DUNGEON.towerState = 1

 -- [v252] Release MODE dispatcher + sync flag lama
 DUNGEON.interrupt = false
 _siegeInterrupt = false
 _raidInterrupt = false
 MODE:Release("dungeon")

 -- Status: cooldown menunggu dungeon berikutnya
 local _cd = DUNGEON_COOLDOWN
 local _mm = math.floor(_cd/60)
 DungeonStatus(string.format("[OK] Dungeon #%d DONE (%s) - Cooldown %dm", DUNGEON.count, result, _mm), Color3.fromRGB(100,255,150))
 if DUNGEON.dot then DUNGEON.dot.BackgroundColor3 = Color3.fromRGB(255,200,60) end

 task.wait(2)

 until true
 end -- while DUNGEON.running

 DUNGEON.interrupt = false
 DUNGEON.running = false
 DUNGEON.inMap = false
 _siegeInterrupt = false
 _raidInterrupt = false
 MODE:Release("dungeon") -- [v252] safety release
 DungeonStatus("[.] Idle", Color3.fromRGB(100,100,100))
 if DUNGEON.dot then DUNGEON.dot.BackgroundColor3 = Color3.fromRGB(100,100,100) end
 end)
end

--  Tambahkan DUNGEON.interrupt ke WaitRaidDone agar MA juga pause saat dungeon aktif 
-- [v252] WaitRaidDone override dihapus - versi v252 sudah handle dungeon check via MODE dispatcher



--  PANEL UI: AUTO DUNGEON 
do
 local p = Panels["autoraid"]
 if not p then return end

 local dungeonOpen = false

 local dungeonHeader = Btn(p, C.SURFACE, UDim2.new(1,0,0,42))
 dungeonHeader.LayoutOrder = 22; Corner(dungeonHeader,10); Stroke(dungeonHeader,C.BORD, 1.5,0.88)
 local dungeonArrow = Label(dungeonHeader,">",13,C.ACC,Enum.Font.GothamBold)
 dungeonArrow.Size = UDim2.new(0,22,1,0); dungeonArrow.Position = UDim2.new(0,10,0,0)
 local dungeonHeaderLbl = Label(dungeonHeader,"Auto Dungeon",14,C.TXT,Enum.Font.GothamBold)
 dungeonHeaderLbl.Size = UDim2.new(1,-50,1,0); dungeonHeaderLbl.Position = UDim2.new(0,34,0,0)
 -- Badge "PRIORITY" kecil
 local prioBadge = Frame(dungeonHeader, Color3.fromRGB(252,211,77), UDim2.new(0,52,0,16))
 prioBadge.AnchorPoint = Vector2.new(1,0.5); prioBadge.Position = UDim2.new(1,-10,0.5,0)
 Corner(prioBadge,5)
 local prioLbl = Label(prioBadge,"EXLUSIVE",8,Color3.fromRGB(10,10,10),Enum.Font.GothamBold,Enum.TextXAlignment.Center)
 prioLbl.Size = UDim2.new(1,0,1,0)

 local dungeonBody = Frame(p, C.BG2, UDim2.new(1,0,0,0))
 dungeonBody.LayoutOrder = 23; dungeonBody.ClipsDescendants = true
 Corner(dungeonBody,10); Stroke(dungeonBody,C.BORD, 1.5,0.25); dungeonBody.Visible = false

 local dungeonInner = Frame(dungeonBody, C.BLACK, UDim2.new(1,-16,0,0))
 dungeonInner.BackgroundTransparency = 1; dungeonInner.Position = UDim2.new(0,8,0,8)
 local dungeonLayout = New("UIListLayout",{Parent=dungeonInner,SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,6)})

 local function ResizeDungeonBody()
 dungeonLayout:ApplyLayout()
 local h = dungeonLayout.AbsoluteContentSize.Y + 16
 dungeonInner.Size = UDim2.new(1,0,0,h)
 dungeonBody.Size = UDim2.new(1,0,0,h+16)
 end

 dungeonHeader.MouseButton1Click:Connect(function()
 dungeonOpen = not dungeonOpen; dungeonBody.Visible = dungeonOpen
 dungeonArrow.Text = dungeonOpen and "v" or ">"
 if dungeonOpen then task.defer(ResizeDungeonBody) end
 end)

 local p2 = dungeonInner -- alias

 -- Status bar
 local statusCard = Frame(p2, C.BG3, UDim2.new(1,0,0,32))
 statusCard.LayoutOrder = 0; Corner(statusCard, 10); Stroke(statusCard,C.ACC, 1.5,0.3)
 DUNGEON.dot = Frame(statusCard, Color3.fromRGB(100,100,100), UDim2.new(0,8,0,8))
 DUNGEON.dot.Position = UDim2.new(0,8,0.5,-4); Corner(DUNGEON.dot,4)
 DUNGEON.statusLbl = Label(statusCard,"Idle - Enable to RUN",10,C.TXT2,Enum.Font.GothamBold)
 DUNGEON.statusLbl.Size = UDim2.new(1,-24,1,0)
 DUNGEON.statusLbl.Position = UDim2.new(0,22,0,0)
 DUNGEON.statusLbl.TextTruncate = Enum.TextTruncate.AtEnd

 -- Info bar
 local infoCard = Frame(p2, C.SURFACE, UDim2.new(1,0,0,28))
 infoCard.LayoutOrder = 1; Corner(infoCard, 10); Stroke(infoCard,C.BORD, 1.5,0.88)
 local infoLbl = Label(infoCard,"Map 5 -> Dungeon| Cooldown: 60m | KillTimeout: 2m",9,C.TXT3,Enum.Font.GothamBold)
 infoLbl.Size = UDim2.new(1,-8,1,0); infoLbl.Position = UDim2.new(0,8,0,0)

 -- Toggle utama - capture SetState (pill+knob visual) ke global _setDungeonToggle
 do
  local _row, _set, _vis = ToggleRow(p2,"Auto Dungeon","PRIORITY",2,function(on)
   _dungeonToggleState = on
   if on then
    StartDungeonLoop()
    task.spawn(ConnectDungeonListener)
   else
    StopDungeon()
    DungeonStatus("[.] OFF - Waiting", Color3.fromRGB(160,148,135))
   end
  end)
  _setDungeonToggle = _set
  _visDungeon = _vis
 end

 -- Counter row
 local countCard = Frame(p2, C.SURFACE, UDim2.new(1,0,0,28))
 countCard.LayoutOrder = 3; Corner(countCard, 10); Stroke(countCard,C.BORD, 1.5,0.88)
 local _dungeonCountLbl = Label(countCard,"SUCCES ENTER: 0x",10,C.TXT2,Enum.Font.GothamBold)
 _dungeonCountLbl.Size = UDim2.new(0.5,0,1,0); _dungeonCountLbl.Position = UDim2.new(0,8,0,0)
 local _dungeonStateLbl = Label(countCard,"State: Wait",10,C.TXT3,Enum.Font.GothamBold,Enum.TextXAlignment.Right)
 _dungeonStateLbl.Size = UDim2.new(0.5,-8,1,0); _dungeonStateLbl.Position = UDim2.new(0.5,0,0,0)

 -- Update counter UI setiap 1 detik
 task.spawn(function()
 local STATE_NAMES = {[1]="Wait",[2]="OPEN!",[3]="Battle"}
 local STATE_COLS = {[1]=Color3.fromRGB(180,180,180),[2]=Color3.fromRGB(80,220,80),[3]=Color3.fromRGB(255,140,0)}
 while ScreenGui and ScreenGui.Parent do
 task.wait(1)
 pcall(function()
 _dungeonCountLbl.Text = "SUCCES ENTER: " .. (DUNGEON.count or 0) .. "x"
 local st = DUNGEON.towerState or 1
 _dungeonStateLbl.Text = "State: " .. (STATE_NAMES[st] or "?")
 _dungeonStateLbl.TextColor3 = STATE_COLS[st] or C.TXT3
 end)
 end
 end)

 task.defer(ResizeDungeonBody)
end

-- ============================================================
-- AUTO SINGLE TOWER MAP 2 (MapId 50301)
-- Remote: StartLocalPlayerTeleport:FireServer({mapId=50301})
-- Keluar : StartLocalPlayerTeleport:FireServer({mapId=50002})
-- Logic: masuk map -> Mass Attack max 10 menit -> keluar -> delay 2s -> ulang
-- Dropdown: "Non Stop" (tanpa batas wave) atau Wave 1-10 (hitung reset enemy di Workspace.Enemy)
-- ============================================================

ST2 = {
    running        = false,
    thread         = nil,
    inMap          = false,
    attacking      = false,  -- flag mass attack sedang berjalan
    waveCount      = 0,      -- 0 = Non Stop, 1-10 = jumlah wave sebelum keluar
    enabled        = false,  -- [FIX] toggle utama ON/OFF - default OFF
    attackEnabled  = false,  -- toggle Attack ON/OFF (dari UI) - default OFF
    statusLbl      = nil,
    dot            = nil,
    count          = 0,
    setAttackToggle= nil,    -- callback untuk sync UI toggle Attack
}

local function ST2Status(msg, color)
    if ST2.statusLbl then
        ST2.statusLbl.Text = msg
        ST2.statusLbl.TextColor3 = color or C.TXT2
    end
    if ST2.dot then
        ST2.dot.BackgroundColor3 = color or Color3.fromRGB(100,100,100)
    end
end

-- [v283] ST2: track mapId aktual via EnterRaidsUpdateInfo (sama seperti RAID system)
-- workspace:GetAttribute("MapId") tidak reliable - game update via remote event ini
local _st2CurrentMapId = nil  -- diisi oleh listener di bawah

-- Pasang listener EnterRaidsUpdateInfo untuk ST2 (standalone, tidak ganggu RAID)
task.spawn(function()
    local _reEnter = Remotes:FindFirstChild("EnterRaidsUpdateInfo")
    if not _reEnter then return end
    _reEnter.OnClientEvent:Connect(function(data)
        if type(data) ~= "table" then return end
        if data.mapId then
            _st2CurrentMapId = data.mapId
        end
    end)
end)

-- 

local function ST2IsInMap()
    -- Sumber 1: cek workspace MapId via attribute (berbagai nama)
    local ok, wm = pcall(function()
        return workspace:GetAttribute("MapId") or workspace:GetAttribute("mapId") or workspace:GetAttribute("CurrentMapId")
    end)
    if ok and type(wm) == "number" and wm > 50000 and wm ~= 50001 and wm ~= 50002 then
        return true
    end
    -- Sumber 2: dari EnterRaidsUpdateInfo
    if type(_st2CurrentMapId) == "number" and _st2CurrentMapId > 50000 and _st2CurrentMapId ~= 50001 and _st2CurrentMapId ~= 50002 then
        return true
    end
    -- Sumber 3 (paling reliable): ada enemy hidup di Enemys folder
    local FOLDERS = {"Enemys","EnemyCityRaid","CityRaidEnemys","Enemies","Enemy"}
    for _, fname in ipairs(FOLDERS) do
        local f = workspace:FindFirstChild(fname)
        if f then
            for _, e in ipairs(f:GetChildren()) do
                if e:IsA("Model") and e:GetAttribute("EnemyGuid") then
                    local hum = e:FindFirstChildOfClass("Humanoid")
                    if hum and hum.Health > 0 then return true end
                end
            end
        end
    end
    return false
end

local function ST2TpIn()
    -- Reset mapId tracker dulu agar ST2ConfirmIn tidak pakai nilai lama
    _st2CurrentMapId = nil
    pcall(function()
        local reStart  = Remotes:FindFirstChild("StartLocalPlayerTeleport")
        local reGet    = Remotes:FindFirstChild("GetNewSingleTowerData")
        local reEquip  = Remotes:FindFirstChild("EquipHeroWithData")
        local reTpSucc = Remotes:FindFirstChild("LocalPlayerTeleportSuccess")
        local reLocal  = Remotes:FindFirstChild("LocalPlayerTeleport")

        -- [FIX STUCK] Urutan remote: lobby dulu -> konfirmasi -> TP ke tower
        -- Step 1: StartLocalPlayerTeleport mapId 50002 (masuk lobby dulu)
        if reStart then reStart:FireServer({mapId = 50002}) end
        task.wait(0.5)

        -- Step 2: GetNewSingleTowerData (invoke) - ambil data tower baru
        if reGet then pcall(function() reGet:InvokeServer() end) end
        task.wait(0.4)

        -- Step 3: EquipHeroWithData - pastikan hero terpasang
        if reEquip then pcall(function() reEquip:FireServer() end) end
        task.wait(0.4)

        -- Step 4: LocalPlayerTeleportSuccess (konfirmasi di lobby)
        if reTpSucc then pcall(function() reTpSucc:InvokeServer() end) end
        task.wait(0.5)

        -- Step 5: StartLocalPlayerTeleport mapId 50301 + hostId (TP ke Tower Map 2)
        if reStart then reStart:FireServer({mapId = 50301, hostId = LP.UserId}) end
        task.wait(0.5)

        -- Step 6: [FIX STUCK] LocalPlayerTeleport tambahan agar game akui masuk tower
        if reLocal then pcall(function() reLocal:FireServer({mapId = 50301, hostId = LP.UserId}) end) end
        task.wait(0.3)

        -- Step 7: EquipHeroWithData (setelah TP ke 50301)
        if reEquip then pcall(function() reEquip:FireServer() end) end
        task.wait(0.4)

        -- Step 8: LocalPlayerTeleportSuccess (konfirmasi masuk 50301)
        if reTpSucc then pcall(function() reTpSucc:InvokeServer() end) end
        task.wait(0.3)

        -- Step 9: [FIX STUCK] Ulangi StartLocalPlayerTeleport ke 50301 sekali lagi
        -- Sebagian user butuh 2x fire untuk benar-benar masuk ke dalam tower
        if not ST2IsInMap() then
            task.wait(0.5)
            if reStart then reStart:FireServer({mapId = 50301, hostId = LP.UserId}) end
            task.wait(0.4)
            if reTpSucc then pcall(function() reTpSucc:InvokeServer() end) end
        end
    end)
end

local function ST2TpOut()
    -- Keluar ke Lobby (MapId 50002) - Mass Attack harus sudah STOP sebelum ini dipanggil
    pcall(function()
        local re = Remotes:FindFirstChild("StartLocalPlayerTeleport")
        if re then re:FireServer({mapId = 50002}) end
    end)
    task.wait(0.3)
    pcall(function()
        local re2 = Remotes:FindFirstChild("LocalPlayerTeleportSuccess")
        if re2 then
            task.spawn(function() pcall(function() re2:InvokeServer() end) end)
        end
    end)
end

-- [v282] ST2ConfirmIn tidak lagi dipanggil langsung (ST2TpIn sudah handle confirm)
-- Dipakai sebagai fallback cek MapId saja
local function ST2ConfirmIn(maxWait)
    local t = 0
    while t < maxWait do
        task.wait(0.3); t = t + 0.3
        if ST2IsInMap() then return true end
    end
    return false
end

local function ST2ConfirmOut(maxWait)
    local t = 0
    while t < maxWait do
        task.wait(0.3); t = t + 0.3
        if not ST2IsInMap() then return true end
    end
    return false
end

function StartST2Loop()
    -- 1. Matikan yang lama jika masih jalan (Clean Start)
    if ST2.running then
        ST2.running = false
        if ST2.thread then pcall(function() task.cancel(ST2.thread) end); ST2.thread = nil end
    end

    -- 2. Set status mulai
    ST2.running = true
    ST2.inMap   = false
    ST2Status("[..] START Auto Single Tower...", Color3.fromRGB(255,200,60))
    -- [FIX] Gold Magnet + Drop Collector saat ST2 berjalan
    StartDestroyWorker(function() return ST2.running end)
    StopGoldMagnet()
    StartInstantGoldCollector(true)
    StartGoldMagnet(function() return ST2.running end)

    -- 3. Thread Utama
    ST2.thread = task.spawn(function()
        pcall(function()
            while ST2.running do
                repeat
                -- [FIX] Jika running di-OFF saat loop sedang berjalan, langsung stop
                if not ST2.running then return end

                -- [FIX] Jika toggle utama OFF, STOP TOTAL - tidak masuk map sama sekali
                if not ST2.enabled then
                    ST2Status("[||] Toggle OFF - STOP masuk map.", Color3.fromRGB(180,60,60))
                    while ST2.running and not ST2.enabled do
                        task.wait(0.3)
                    end
                    if not ST2.running then return end
                end

                -- [FIX] Jika Attack OFF, standby di luar map (bukan di dalam)
                -- Waiting di dalam map -> IsAnyMapActive() true -> semua fitur freeze
                if not ST2.attackEnabled then
                    ST2Status("[||] Attack OFF - standby...", Color3.fromRGB(180,100,60))
                    while ST2.running and not ST2.attackEnabled do
                        task.wait(0.5)
                    end
                    if not ST2.running then return end
                end

                -- -- STEP 0: Delay 2 detik sebelum masuk ------------------
                ST2Status("[..] Delay 2s Before Enter Single Tower...", Color3.fromRGB(160,148,135))
                for _i = 1, 20 do
                    if not ST2.running then return end
                    task.wait(0.1)
                end
                if not ST2.running then return end

                -- [GUARD v50] ST2 tunggu semua fitur lain selesai dulu
                do
                 local _t2Wait = 0
                 while ST2.running and _t2Wait < 90 do
                  local _busy, _who = IsAnyMapActive()
                  local _selfBusy = (_who == "st2")
                  if not _busy or _selfBusy then break end
                  ST2Status("[||] Tunggu "..(_who or "?").." selesai...", Color3.fromRGB(255,140,0))
                  task.wait(0.5); _t2Wait = _t2Wait + 0.5
                 end
                 if not ST2.running then return end
                end

                -- -- STEP 1: TP ke Single Tower Map 2 ----------------------------
                ST2Status("[>>] TP to Single Tower...", Color3.fromRGB(180,120,255))
                ST2TpIn()

                -- -- STEP 1b: Konfirmasi masuk map --
                pcall(function()
                    local reTpSucc = Remotes:FindFirstChild("LocalPlayerTeleportSuccess")
                    if reTpSucc then pcall(function() reTpSucc:InvokeServer() end) end
                end)

                ST2Status("[..] Waiting to Enter...", Color3.fromRGB(180,120,255))
                local entered = ST2ConfirmIn(15)
                if not entered then
                    ST2Status("[!] Failure Enter - retry...", Color3.fromRGB(255,100,60))
                    task.wait(3)
                    break -- Kembali ke awal loop
                end

                ST2Status("[OK] ENTER", Color3.fromRGB(80,220,80))
                task.wait(1)
                if not ST2.running then return end

                -- -- STEP 2: Cek toggle Attack ------------------------------------
                -- [v62 FIX] Jika Attack OFF, keluar dari Tower dulu (tidak tunggu di dalam)
                -- Waiting di dalam map menyebabkan IsAnyMapActive() = true -> semua fitur lain freeze
                if not ST2.attackEnabled then
                    ST2Status("[||] Attack OFF - keluar Tower...", Color3.fromRGB(255,140,0))
                    -- Keluar map segera
                    pcall(function()
                        local _exitRe = Remotes:FindFirstChild("ExitChallengeRaid") or Remotes:FindFirstChild("LeaveDungeon")
                        if _exitRe then _exitRe:FireServer({ currentSlotIndex=2, toMapId=50001 }) end
                    end)
                    pcall(function() RE.LocalTp:FireServer({ mapId=50001 }) end)
                    ST2.inMap = false
                    ReleaseMapLock("st2")
                    task.wait(2)
                    break -- kembali ke atas loop, tunggu sampai Attack ON
                end

                -- -- STEP 3: SCAN HERO_GUIDS --
                if #HERO_GUIDS == 0 then
                    ST2Status("[~] Scan HERO_GUIDS...", Color3.fromRGB(255,200,60))
                    local function addHero(g)
                        if type(g) == "string" and #g > 0 and IsValidUUID(g) then
                            local dup = false
                            for _, ex in ipairs(HERO_GUIDS) do if ex == g then dup = true; break end end
                            if not dup then table.insert(HERO_GUIDS, g) end
                        end
                    end

                    pcall(function()
                        for _, obj in ipairs(LP.PlayerGui:GetChildren()) do
                            addHero(obj:GetAttribute("heroGuid") or obj:GetAttribute("guid"))
                        end
                        local hFolder = workspace:FindFirstChild("Heros")
                        if hFolder then
                            for _, h in ipairs(hFolder:GetChildren()) do
                                addHero(h:GetAttribute("heroGuid") or h:GetAttribute("guid") or h:GetAttribute("GUID"))
                            end
                        end
                    end)
                    ST2Status("[~] HERO_GUIDS: "..#HERO_GUIDS.." found", Color3.fromRGB(255,200,60))
                    task.wait(0.3)
                end

                -- Inisialisasi Data Map
                ST2.inMap     = true
                ST2.attacking = true
                ST2.count     = ST2.count + 1
                local targetWaves = ST2.waveCount
                local wavesDone   = 0
                local _everSawEnemy = false
                local _exitConfirm = 0
                local _waveDetectCooldown = 0
                local _lastEnemySet = {}

                -- Fungsi pembantu
                local function ST2GetCurrentEnemyGuids()
                    local guids = {}
                    local FOLDERS = {"Enemys","EnemyCityRaid","CityRaidEnemys","Enemies","Enemy","Heros"}
                    for _, fname in ipairs(FOLDERS) do
                        local f = workspace:FindFirstChild(fname)
                        if f then
                            for _, e in ipairs(f:GetChildren()) do
                                local g = e:GetAttribute("EnemyGuid") or e:GetAttribute("GUID") or e:GetAttribute("Guid") or e:GetAttribute("guid") or e:GetAttribute("heroGuid")
                                if type(g) == "string" and #g > 0 then guids[g] = true end
                            end
                        end
                    end
                    return guids
                end

                local function ST2GetTargets()
                    local targets = {}
                    local FOLDERS = {"Enemys","EnemyCityRaid","CityRaidEnemys","Enemies","Enemy","Heros"}
                    local seen = {}
                    for _, fname in ipairs(FOLDERS) do
                        local f = workspace:FindFirstChild(fname)
                        if f then
                            for _, e in ipairs(f:GetChildren()) do
                                if e:IsA("Model") then
                                    local g = e:GetAttribute("EnemyGuid") or e:GetAttribute("GUID") or e:GetAttribute("Guid") or e:GetAttribute("guid") or e:GetAttribute("heroGuid")
                                    if g and type(g) == "string" and #g > 0 then
                                        local hrp = e:FindFirstChild("HumanoidRootPart")
                                        local hum = e:FindFirstChildOfClass("Humanoid")
                                        if hrp and hum and hum.Health > 0 and not seen[g] then
                                            seen[g] = true
                                            table.insert(targets, {model=e, guid=g, hrp=hrp})
                                        end
                                    end
                                end
                            end
                        end
                    end
                    return targets
                end

                _lastEnemySet = ST2GetCurrentEnemyGuids()
                ST2Status("[S] START Attack! Wave: 0/"..(targetWaves>0 and tostring(targetWaves) or "inf"), Color3.fromRGB(80,220,80))

                -- -- STEP 4: ATTACK LOOP -------------------------------------------
                while ST2.running and ST2.inMap and ST2.attacking do
                    if not ST2.attackEnabled then
                        ST2Status("[||] PAUSE Attack...", Color3.fromRGB(255,140,0))
                        while ST2.running and not ST2.attackEnabled do task.wait(0.3) end
                        if not ST2.running then return end
                    end

                    if not ST2IsInMap() then
                        _exitConfirm = _exitConfirm + 1
                        if _exitConfirm >= 3 then break end
                    else
                        _exitConfirm = 0
                    end

                    -- Deteksi Wave
                    if targetWaves > 0 and _waveDetectCooldown <= 0 then
                        local currentSet = ST2GetCurrentEnemyGuids()
                        local totalCurrent, newCount = 0, 0
                        for g in pairs(currentSet) do
                            totalCurrent = totalCurrent + 1
                            if not _lastEnemySet[g] then newCount = newCount + 1 end
                        end
                        
                        if totalCurrent > 0 and newCount > 0 then
                            wavesDone = wavesDone + 1
                            _lastEnemySet = currentSet
                            _waveDetectCooldown = 30
                            if wavesDone >= targetWaves then
                                ST2Status("[W] Wave "..wavesDone.."/"..targetWaves.." DONE!", Color3.fromRGB(100,200,255))
                                break
                            end
                        end
                    end
                    if _waveDetectCooldown > 0 then _waveDetectCooldown = _waveDetectCooldown - 1 end

                    -- Eksekusi Serangan
                    local targets = ST2GetTargets()
                    if #targets > 0 then
                        _everSawEnemy = true
                        for _, e in ipairs(targets) do
                            FireAttack(e.guid, e.hrp.Position)
                            FireAllDamage(e.guid, e.hrp.Position)
                            FireHeroRemotes(e.guid, e.hrp.Position)
                        end
                        ST2Status("[S] "..#targets.." enemy | Wave "..wavesDone.."/"..targetWaves, Color3.fromRGB(80,220,80))
                    end
                    task.wait(0.3)
                end -- end attack loop

                if not ST2.running then return end

                -- -- STEP 5: EXIT MAP -----------------------------------------------
                ST2.attacking = false
                ST2.inMap     = false
                ST2Status("[<] DONE - Go to Lobby...", Color3.fromRGB(100,200,255))
                ST2TpOut()
                ST2ConfirmOut(8)

                ST2Status("[..] Delay 2s...", Color3.fromRGB(160,148,135))
                for _i = 1, 20 do
                    if not ST2.running then return end
                    task.wait(0.1)
                end
                if not ST2.running then return end 
                until true
            end -- end while ST2.running
        end) -- end pcall
        
        -- Reset Status Saat Berhenti
        ST2.inMap = false
        ST2.attacking = false
        ST2.running = false
        ST2Status("[.] Idle", Color3.fromRGB(100,100,100))
    end) -- end task.spawn
end

-- ============================================================
-- PANEL : AUTO SINGLE TOWER MAP 2 (UI)
-- ============================================================
do
    local p = Panels["autoraid"]
    if not p then return end

    local st2Open = false

    local st2Header = Btn(p, C.SURFACE, UDim2.new(1,0,0,42))
    st2Header.LayoutOrder = 24; Corner(st2Header,10); Stroke(st2Header,C.BORD, 1.5,0.88)
    local st2Arrow = Label(st2Header,">",13,C.ACC,Enum.Font.GothamBold)
    st2Arrow.Size = UDim2.new(0,22,1,0); st2Arrow.Position = UDim2.new(0,10,0,0)
    local st2HeaderLbl = Label(st2Header,"Auto Single Tower Map 2",14,C.TXT,Enum.Font.GothamBold)
    st2HeaderLbl.Size = UDim2.new(1,-50,1,0); st2HeaderLbl.Position = UDim2.new(0,34,0,0)

    local st2Body = Frame(p, C.BG2, UDim2.new(1,0,0,0))
    st2Body.LayoutOrder = 25; st2Body.ClipsDescendants = true
    Corner(st2Body,10); Stroke(st2Body,C.BORD, 1.5,0.25); st2Body.Visible = false

    local st2Inner = Frame(st2Body, C.BLACK, UDim2.new(1,-16,0,0))
    st2Inner.BackgroundTransparency = 1; st2Inner.Position = UDim2.new(0,8,0,8)
    local st2Layout = New("UIListLayout",{Parent=st2Inner,SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,6)})

    local function ResizeST2Body()
        st2Layout:ApplyLayout()
        local h = st2Layout.AbsoluteContentSize.Y + 16
        st2Inner.Size = UDim2.new(1,0,0,h)
        st2Body.Size = UDim2.new(1,0,0,h+16)
    end

    st2Header.MouseButton1Click:Connect(function()
        st2Open = not st2Open; st2Body.Visible = st2Open
        st2Arrow.Text = st2Open and "v" or ">"
        if st2Open then task.defer(ResizeST2Body) end
    end)

    local inner = st2Inner

    -- Status bar
    local statusCard = Frame(inner, C.BG3, UDim2.new(1,0,0,32))
    statusCard.LayoutOrder = 0; Corner(statusCard, 10); Stroke(statusCard,C.ACC, 1.5,0.3)
    ST2.dot = Frame(statusCard, Color3.fromRGB(100,100,100), UDim2.new(0,8,0,8))
    ST2.dot.Position = UDim2.new(0,8,0.5,-4); Corner(ST2.dot,4)
    ST2.statusLbl = Label(statusCard,"Idle - Enable To START",10,C.TXT2,Enum.Font.GothamBold)
    ST2.statusLbl.Size = UDim2.new(1,-24,1,0)
    ST2.statusLbl.Position = UDim2.new(0,22,0,0)
    ST2.statusLbl.TextTruncate = Enum.TextTruncate.AtEnd

    -- Toggle ON/OFF - default OFF
    local _st2ToggleRow, _setST2Toggle, _st2Vis = ToggleRow(inner,"Auto Single Tower Map 2","ON = ENTER",1,function(on)
        ST2.enabled = on
        if on then
            StartST2Loop()
        else
            -- [FIX] Toggle OFF: langsung stop masuk map
            ST2.enabled = false
            if ST2.running then
                ST2.running = false
                if ST2.thread then pcall(function() task.cancel(ST2.thread) end); ST2.thread = nil end
            end
            ST2.inMap = false
            ST2.attacking = false
            ST2Status("[.] Idle - Toggle OFF", Color3.fromRGB(100,100,100))
        end
    end)
    _visST2 = _st2Vis

    -- Wave dropdown
    local ddCard = Frame(inner, C.SURFACE, UDim2.new(1,0,0,0))
    ddCard.LayoutOrder = 2; ddCard.AutomaticSize = Enum.AutomaticSize.Y
    Corner(ddCard, 10); Stroke(ddCard,C.BORD, 1.5,0.5)
    New("UIPadding",{Parent=ddCard,PaddingTop=UDim.new(0, 10),PaddingBottom=UDim.new(0, 10),PaddingLeft=UDim.new(0, 10),PaddingRight=UDim.new(0, 10)})

    local ddInner = Frame(ddCard, C.BLACK, UDim2.new(1,0,0,0))
    ddInner.BackgroundTransparency = 1; ddInner.AutomaticSize = Enum.AutomaticSize.Y
    New("UIListLayout",{Parent=ddInner,SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,6)})

    local ddTitleRow = Frame(ddInner, C.BLACK, UDim2.new(1,0,0,16))
    ddTitleRow.BackgroundTransparency = 1; ddTitleRow.LayoutOrder = 0
    local ddTitleLbl = Label(ddTitleRow,"Wave (RESET ENEMY):",10,C.TXT3,Enum.Font.GothamBold)
    ddTitleLbl.Size = UDim2.new(1,0,1,0)

    -- Dropdown button
    local ddBtn = Btn(ddInner, C.BG3, UDim2.new(1,0,0,32))
    ddBtn.LayoutOrder = 1; Corner(ddBtn, 10); Stroke(ddBtn,C.BORD, 1.5,0.5)
    local ddBtnLbl = Label(ddBtn,"  Non Stop (default)",11,C.GRN,Enum.Font.GothamBold,Enum.TextXAlignment.Left)
    ddBtnLbl.Size = UDim2.new(1,-30,1,0)
    local ddArrow = Label(ddBtn,"v",11,C.TXT3,Enum.Font.GothamBold,Enum.TextXAlignment.Right)
    ddArrow.Size = UDim2.new(0,24,1,0); ddArrow.Position = UDim2.new(1,-26,0,0)

    -- Dropdown list
    local ddList = Frame(ddInner, C.BG2, UDim2.new(1,0,0,0))
    ddList.LayoutOrder = 2; ddList.AutomaticSize = Enum.AutomaticSize.Y
    ddList.Visible = false; Corner(ddList, 10); Stroke(ddList,C.BORD, 1.5,0.3)
    New("UIPadding",{Parent=ddList,PaddingTop=UDim.new(0,4),PaddingBottom=UDim.new(0,4),PaddingLeft=UDim.new(0,6),PaddingRight=UDim.new(0,6)})
    New("UIListLayout",{Parent=ddList,SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,3)})

    -- Wave list: Non Stop (default) + Wave 1-10
    local OPTIONS = {"Non Stop", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10"}
    local OPTION_VALS = {0,1,2,3,4,5,6,7,8,9,10}

    local ddOpen2 = false
    local selectedIdx = 1  -- default Non Stop

    local function updateDdBtn()
        ddBtnLbl.Text = "  "..OPTIONS[selectedIdx]
        ddBtnLbl.TextColor3 = selectedIdx == 1 and C.GRN or C.ACC2
        ST2.waveCount = OPTION_VALS[selectedIdx]
    end

    for i, opt in ipairs(OPTIONS) do
        local ii = i
        local row = Btn(ddList, C.SURFACE, UDim2.new(1,0,0,28))
        row.LayoutOrder = i; Corner(row,6); row.AutoButtonColor = false
        local rowLbl = Label(row, opt, 11, i==1 and C.GRN or C.TXT, Enum.Font.Gotham, Enum.TextXAlignment.Left)
        rowLbl.Size = UDim2.new(1,-8,1,0); rowLbl.Position = UDim2.new(0,8,0,0)
        -- Badge saat dipilih
        local selDot = Frame(row, C.ACC, UDim2.new(0,6,0,6))
        selDot.Position = UDim2.new(1,-14,0.5,-3); Corner(selDot,3)
        selDot.Visible = (i == 1)

        row.MouseButton1Click:Connect(function()
            -- Deselect all
            for _, child in ipairs(ddList:GetChildren()) do
                if child:IsA("TextButton") then
                    local dot = child:FindFirstChildOfClass("Frame")
                    if dot then dot.Visible = false end
                    local lbl = child:FindFirstChildOfClass("TextLabel")
                    if lbl then lbl.TextColor3 = OPTION_VALS[child.LayoutOrder] == 0 and C.GRN or C.TXT end
                end
            end
            selDot.Visible = true
            rowLbl.TextColor3 = ii==1 and C.GRN or C.ACC2
            selectedIdx = ii
            updateDdBtn()
            ddOpen2 = false; ddList.Visible = false; ddArrow.Text = "v"
            task.defer(ResizeST2Body)
        end)
    end

    ddBtn.MouseButton1Click:Connect(function()
        ddOpen2 = not ddOpen2
        ddList.Visible = ddOpen2
        ddArrow.Text = ddOpen2 and "^" or "v"
        task.defer(ResizeST2Body)
    end)

    -- -- Toggle Attack ---------------------------------------------------------
    -- Toggle ON/OFF untuk fungsi Attack (Mass Attack Kill All)
    -- Default OFF: user harus aktifkan manual
    local _, setAtkToggle = ToggleRow(inner, "Attack", "ATTACK ALL ENEMY", 3, function(on)
        ST2.attackEnabled = on
    end)
    -- [FIX] Default OFF - user aktifkan manual
    ST2.attackEnabled  = false
    ST2.setAttackToggle = setAtkToggle
    -- Pastikan visual juga OFF saat init
    task.defer(function()
        if setAtkToggle then setAtkToggle(false) end
    end)

    -- Info card
    local infoCard = Frame(inner, C.BG3, UDim2.new(1,0,0,0))
    infoCard.LayoutOrder = 4; infoCard.AutomaticSize = Enum.AutomaticSize.Y
    Corner(infoCard, 10)
    New("UIPadding",{Parent=infoCard,PaddingTop=UDim.new(0,6),PaddingBottom=UDim.new(0,6),PaddingLeft=UDim.new(0, 10),PaddingRight=UDim.new(0, 10)})
    local infoLbl = Label(infoCard,"Delay 2s -> TP Map 2 -> LocalPlayerTeleportSuccess -> Delay 1s -> Attack (jika ON) -> Exit -> Delay 2s -> Loop. Attack OFF: loop tetap masuk map tapi tidak menyerang.",10,C.TXT3,Enum.Font.Gotham)
    infoLbl.Size = UDim2.new(1,0,0,0); infoLbl.AutomaticSize = Enum.AutomaticSize.Y
    infoLbl.TextWrapped = true

    -- Count label
    local cntCard = Frame(inner, C.SURFACE, UDim2.new(1,0,0,26))
    cntCard.LayoutOrder = 5; Corner(cntCard, 10)
    New("UIPadding",{Parent=cntCard,PaddingLeft=UDim.new(0, 10),PaddingRight=UDim.new(0, 10)})
    local cntLbl = Label(cntCard,"ENTER: 0x",11,C.ACC2,Enum.Font.GothamBold,Enum.TextXAlignment.Left)
    cntLbl.Size = UDim2.new(1,0,1,0)

    -- Watch count changes
    task.spawn(function()
        local last = -1
        while true do
            task.wait(1)
            if ST2 and ST2.count ~= last then
                last = ST2.count
                cntLbl.Text = "ENTER: "..ST2.count.."x"
            end
        end
    end)

    task.defer(ResizeST2Body)

end


-- ============================================================
-- PANEL : JOIN TO TOWER PLAYER (UI) - mapId 50301
-- SCAN = ambil semua player dari Players service (global workspace)
-- JOIN = LocalPlayerTeleport:FireServer({mapId=50301, hostId=UserId})
-- Tidak ada cara mengetahui siapa yg ada di Tower Map 2 dari client,
-- jadi semua player di server ditampilkan -> user pilih sendiri -> JOIN.
-- ============================================================
do
    local p = Panels["autoraid"]
    if p then

    -- -- State --------------------------------------------------------------
    local JTP_players    = {}   -- { {name=string, userId=number} } semua player di server
    local JTP_selIdx     = nil  -- index row yang dipilih
    local JTP_joining    = false
    local JTP_MAPID      = 50301

    -- -- Header collapsible ------------------------------------------------
    local jtpOpen = false

    local jtpHeader = Btn(p, C.SURFACE, UDim2.new(1,0,0,42))
    jtpHeader.LayoutOrder = 26; Corner(jtpHeader,10)
    Stroke(jtpHeader, Color3.fromRGB(80,200,120), 1.5, 0.3)

    local jtpArrow = Label(jtpHeader,">",13,Color3.fromRGB(80,200,120),Enum.Font.GothamBold)
    jtpArrow.Size = UDim2.new(0,22,1,0); jtpArrow.Position = UDim2.new(0,10,0,0)

    local jtpHeaderLbl = Label(jtpHeader,"JOIN TO TOWER MAP 2",14,C.TXT2,Enum.Font.GothamBold)
    jtpHeaderLbl.Size = UDim2.new(1,-50,1,0); jtpHeaderLbl.Position = UDim2.new(0,34,0,0)

    local jtpBody = Frame(p, C.BG2, UDim2.new(1,0,0,0))
    jtpBody.LayoutOrder = 27; jtpBody.ClipsDescendants = true
    Corner(jtpBody,10); Stroke(jtpBody,Color3.fromRGB(80,200,120),1.5,0.25)
    jtpBody.Visible = false

    local jtpInner = Frame(jtpBody, C.BLACK, UDim2.new(1,-16,0,0))
    jtpInner.BackgroundTransparency = 1; jtpInner.Position = UDim2.new(0,8,0,8)
    local jtpLayout = New("UIListLayout",{
        Parent=jtpInner, SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,6)
    })

    local function ResizeJTPBody()
        task.spawn(function()
            task.wait(0)
            jtpLayout:ApplyLayout()
            local h = jtpLayout.AbsoluteContentSize.Y + 16
            jtpInner.Size = UDim2.new(1,0,0,h)
            jtpBody.Size  = UDim2.new(1,0,0,h+16)
        end)
    end

    jtpHeader.MouseButton1Click:Connect(function()
        jtpOpen = not jtpOpen
        jtpBody.Visible = jtpOpen
        jtpArrow.Text = jtpOpen and "v" or ">"
        if jtpOpen then task.defer(ResizeJTPBody) end
    end)

    -- -- Info card --------------------------------------------------------?
    local infoCard = Frame(jtpInner, C.BG3, UDim2.new(1,0,0,0))
    infoCard.LayoutOrder = 0; infoCard.AutomaticSize = Enum.AutomaticSize.Y; Corner(infoCard,10)
    New("UIPadding",{Parent=infoCard,
        PaddingTop=UDim.new(0,6),PaddingBottom=UDim.new(0,6),
        PaddingLeft=UDim.new(0,10),PaddingRight=UDim.new(0,10)})
    local infoLbl = Label(infoCard,
        "SCAN = ambil semua player di server (global).\nPilih player yg kamu yakin ada di Tower Map 2,\nlalu tekan JOIN -> masuk via hostId = UserId mereka.",
        10, C.TXT3, Enum.Font.Gotham)
    infoLbl.Size = UDim2.new(1,0,0,0); infoLbl.AutomaticSize = Enum.AutomaticSize.Y
    infoLbl.TextWrapped = true; infoLbl.LineHeight = 1.3

    -- -- Status bar --------------------------------------------------------
    local jtpStatCard = Frame(jtpInner, C.SURFACE, UDim2.new(1,0,0,28))
    jtpStatCard.LayoutOrder = 1; Corner(jtpStatCard,10)
    New("UIPadding",{Parent=jtpStatCard,PaddingLeft=UDim.new(0,10),PaddingRight=UDim.new(0,10)})
    local jtpStatLbl = Label(jtpStatCard,"Tekan SCAN untuk muat daftar player.", 10, C.TXT3, Enum.Font.Gotham)
    jtpStatLbl.Size = UDim2.new(1,0,1,0)
    jtpStatLbl.TextTruncate = Enum.TextTruncate.AtEnd

    local function JTPStat(msg, col)
        pcall(function() jtpStatLbl.Text = msg; jtpStatLbl.TextColor3 = col or C.TXT3 end)
    end

    -- -- SCAN button ------------------------------------------------------?
    local scanBtn = Btn(jtpInner, Color3.fromRGB(25,65,45), UDim2.new(1,0,0,36))
    scanBtn.LayoutOrder = 2; Corner(scanBtn,10)
    Stroke(scanBtn, Color3.fromRGB(80,200,120), 1.5, 0.15)
    local scanLbl = Label(scanBtn,"[SCAN]  SCAN  Player (Global Server)",13,
        Color3.fromRGB(100,230,150), Enum.Font.GothamBold, Enum.TextXAlignment.Center)
    scanLbl.Size = UDim2.new(1,0,1,0)

    -- -- Player list box --------------------------------------------------?
    -- Scrollable frame agar list panjang tetap rapi
    local listOuter = Frame(jtpInner, C.BG3, UDim2.new(1,0,0,0))
    listOuter.LayoutOrder = 3; listOuter.AutomaticSize = Enum.AutomaticSize.Y
    listOuter.Visible = false; Corner(listOuter,10)
    Stroke(listOuter, C.BORD, 1.5, 0.5)
    New("UIPadding",{Parent=listOuter,
        PaddingTop=UDim.new(0,4),PaddingBottom=UDim.new(0,4),
        PaddingLeft=UDim.new(0,6),PaddingRight=UDim.new(0,6)})

    local listTitleLbl = Label(listOuter,"Pilih player -> tap untuk select :",10,C.TXT3,Enum.Font.GothamBold)
    listTitleLbl.LayoutOrder = 0; listTitleLbl.Size = UDim2.new(1,0,0,20)

    local listInner = Frame(listOuter, C.BLACK, UDim2.new(1,0,0,0))
    listInner.BackgroundTransparency = 1; listInner.LayoutOrder = 1
    listInner.AutomaticSize = Enum.AutomaticSize.Y
    local listLL = New("UIListLayout",{Parent=listInner,
        SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,4)})

    local playerRows = {}  -- frame per row

    -- -- JOIN button ------------------------------------------------------?
    local joinBtn = Btn(jtpInner, Color3.fromRGB(15,35,110), UDim2.new(1,0,0,40))
    joinBtn.LayoutOrder = 4; Corner(joinBtn,10)
    Stroke(joinBtn, Color3.fromRGB(55,105,255), 2, 0.05)
    local joinLbl = Label(joinBtn,"[JOIN]  JOIN  ke Tower Map 2",15,
        Color3.fromRGB(148,195,255), Enum.Font.GothamBold, Enum.TextXAlignment.Center)
    joinLbl.Size = UDim2.new(1,0,1,0)

    -- -- Helper: hapus semua row lama ------------------------------------?
    local function ClearRows()
        for _, r in ipairs(playerRows) do pcall(function() r:Destroy() end) end
        playerRows = {}
        JTP_selIdx = nil
    end

    -- -- Helper: render daftar player ------------------------------------?
    local function RenderList()
        ClearRows()
        listOuter.Visible = (#JTP_players > 0)
        for i, entry in ipairs(JTP_players) do
            local ii = i
            local row = Btn(listInner, C.SURFACE, UDim2.new(1,0,0,34))
            row.LayoutOrder = i; Corner(row,8)
            Stroke(row, C.BORD, 1.5, 0.65)

            -- Nama player (kiri)
            local nLbl = Label(row, entry.name, 11, C.TXT2, Enum.Font.GothamBold)
            nLbl.Size = UDim2.new(0.6,0,1,0); nLbl.Position = UDim2.new(0,10,0,0)
            nLbl.TextTruncate = Enum.TextTruncate.AtEnd

            -- UserId (kanan, sebagai hostId nanti)
            local uLbl = Label(row,"UID: "..tostring(entry.userId),9,C.TXT3,Enum.Font.Gotham,Enum.TextXAlignment.Right)
            uLbl.Size = UDim2.new(0.4,-14,1,0); uLbl.Position = UDim2.new(0.6,0,0,0)
            uLbl.TextTruncate = Enum.TextTruncate.AtEnd

            -- Indikator pilihan
            local dot = Frame(row, Color3.fromRGB(80,210,130), UDim2.new(0,7,0,7))
            dot.AnchorPoint = Vector2.new(0,0.5); dot.Position = UDim2.new(0,1,0.5,0)
            Corner(dot,4); dot.Visible = false

            row.MouseButton1Click:Connect(function()
                JTP_selIdx = ii
                for j, r2 in ipairs(playerRows) do
                    local d2 = r2:FindFirstChildOfClass("Frame")
                    if d2 then d2.Visible = (j == ii) end
                    r2.BackgroundColor3 = (j == ii)
                        and Color3.fromRGB(18,52,32)
                        or  C.SURFACE
                end
                JTPStat("[v] Dipilih: "..entry.name.." (hostId = "..entry.userId..")",
                    Color3.fromRGB(100,230,150))
            end)

            table.insert(playerRows, row)
        end
        task.defer(ResizeJTPBody)
    end

    -- -- SCAN logic : Players:GetPlayers() global ? tidak filter mapId ----?
    local _jtpBusy = false
    scanBtn.MouseButton1Click:Connect(function()
        if _jtpBusy then return end
        _jtpBusy = true
        scanLbl.Text = "[...]  Scanning..."
        JTPStat("[~] Mengambil daftar player di server...", C.YEL)
        listOuter.Visible = false
        JTP_selIdx = nil
        ClearRows()

        task.spawn(function()
            local found = {}
            -- Ambil semua player di game (global workspace Players service)
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LP then   -- skip diri sendiri
                    table.insert(found, {
                        name   = plr.Name,
                        userId = plr.UserId,  -- UserId = hostId untuk remote
                    })
                end
            end

            JTP_players = found
            _jtpBusy = false
            scanLbl.Text = "[SCAN]  SCAN  Player (Global Server)"

            if #found == 0 then
                JTPStat("[!] Tidak ada player lain di server ini.", C.YEL)
                listOuter.Visible = false
                task.defer(ResizeJTPBody)
            else
                JTPStat("[OK] "..#found.." player ditemukan. Pilih -> JOIN.", Color3.fromRGB(100,230,150))
                RenderList()
            end
        end)
    end)

    -- -- JOIN logic --------------------------------------------------------
    -- Remote: LocalPlayerTeleport:FireServer({mapId=50301, hostId=UserId})
    joinBtn.MouseButton1Click:Connect(function()
        if JTP_joining then return end
        if not JTP_selIdx then
            JTPStat("[!] Belum ada player yang dipilih!", C.YEL)
            return
        end
        local entry = JTP_players[JTP_selIdx]
        if not entry then
            JTPStat("[!] Data tidak valid, coba SCAN ulang.", C.YEL)
            return
        end

        JTP_joining = true
        joinLbl.Text = "[...]  JOINING..."
        joinLbl.TextColor3 = C.YEL
        JTPStat("[JOIN] Menuju room "..entry.name.." (hostId="..entry.userId..")...", C.YEL)

        task.spawn(function()
            local ok, err = pcall(function()
                -- Ambil remote
                local reLocalTp = Remotes:WaitForChild("LocalPlayerTeleport", 5)
                local reStartTp = Remotes:FindFirstChild("StartLocalPlayerTeleport")
                local reEquip   = Remotes:FindFirstChild("EquipHeroWithData")
                local reTpSucc  = Remotes:FindFirstChild("LocalPlayerTeleportSuccess")

                if not reLocalTp then error("Remote LocalPlayerTeleport tidak ditemukan!") end

                -- == Step 1: LocalPlayerTeleport (sesuai SimpleSpy capture) ==
                -- args[1] = { mapId = 50301, hostId = UserId_target }
                reLocalTp:FireServer({mapId = JTP_MAPID, hostId = entry.userId})
                task.wait(0.35)

                -- == Step 2: StartLocalPlayerTeleport ==
                if reStartTp then
                    reStartTp:FireServer({mapId = JTP_MAPID, hostId = entry.userId})
                end
                task.wait(0.4)

                -- == Step 3: EquipHeroWithData ==
                if reEquip then
                    pcall(function() reEquip:FireServer() end)
                end
                task.wait(0.3)

                -- == Step 4: LocalPlayerTeleportSuccess ==
                if reTpSucc then
                    pcall(function() reTpSucc:InvokeServer() end)
                end
            end)

            JTP_joining = false
            joinLbl.Text = "[JOIN]  JOIN  ke Tower Map 2"
            joinLbl.TextColor3 = Color3.fromRGB(148,195,255)

            if ok then
                JTPStat("[OK] Berhasil join room "..entry.name.."!", Color3.fromRGB(80,220,140))
                SystemNotify("[OK] Joined Tower: "..entry.name, 4)
            else
                JTPStat("[ERR] Gagal: "..(tostring(err):sub(1,60)), Color3.fromRGB(220,80,80))
                SystemNotify("[ERR] Join Tower gagal!", 3)
            end
        end)
    end)

    task.defer(ResizeJTPBody)

    end -- if p
end -- do JTP

-- Pasang listener dungeon segera setelah GUI load (scan state walau toggle OFF)
task.spawn(function()
 task.wait(6) -- buffer setelah ConnectUpdateCityRaidListener
 ConnectDungeonListener()
end)


-- PANEL : CLAIM REWARD
-- ============================================================
do
 local p = NewPanel("claim")
 SectionHeader(p,"AUTO CLAIM REWARD",0)

 -- Status label
 local statusCard = Frame(p, C.BG3, UDim2.new(1,0,0,32))
 statusCard.LayoutOrder = 1; Corner(statusCard, 10); Stroke(statusCard,C.ACC, 1.5,0.3)
 local statusLbl = Label(statusCard,"Idle - PRESS CLAIM ALL",10,C.TXT2,Enum.Font.GothamBold)
 statusLbl.Size = UDim2.new(1,-16,1,0); statusLbl.Position = UDim2.new(0,8,0,0)

 -- Log panel (snipping output)
 local logCard = Frame(p, C.BG3, UDim2.new(1,0,0,120))
 logCard.LayoutOrder = 2; Corner(logCard, 10); Stroke(logCard,C.BORD, 1.5,0.88)
 local logScroll = New("ScrollingFrame",{
 Parent=logCard, Size=UDim2.new(1,-8,1,-8),
 Position=UDim2.new(0,4,0,4),
 BackgroundTransparency=1, BorderSizePixel=0,
 ScrollBarThickness=3, ScrollBarImageColor3=C.ACC,
 CanvasSize=UDim2.new(0,0,0,0),
 AutomaticCanvasSize=Enum.AutomaticSize.Y,
 })
 ListLayout(logScroll,nil,Enum.HorizontalAlignment.Left,2)
 local logLines = {}

 function Log(msg, col)
 -- Print ke console juga
 print("[ASH CLAIM] " .. msg)
 -- Tambah ke GUI log
 local lbl = Label(logScroll, msg, 10, col or C.TXT2, Enum.Font.RobotoMono)
 lbl.Size = UDim2.new(1,0,0,13)
 lbl.TextXAlignment = Enum.TextXAlignment.Left
 lbl.TextTruncate = Enum.TextTruncate.AtEnd
 table.insert(logLines, lbl)
 -- Hapus baris lama kalau lebih dari 30
 if #logLines > 30 then
 logLines[1]:Destroy()
 table.remove(logLines, 1)
 end
 -- Auto scroll ke bawah
 task.defer(function()
 logScroll.CanvasPosition = Vector2.new(0, logScroll.AbsoluteCanvasSize.Y)
 end)
 end

 function SetStatus(msg, col)
 statusLbl.Text = msg
 statusLbl.TextColor3 = col or C.TXT2
 Log(msg, col)
 end

 -- Helper buat row claim
 function ClaimRow(order, icon, title, desc, fn)
 local row = Frame(p, C.SURFACE, UDim2.new(1,0,0,54))
 row.LayoutOrder = order; Corner(row,9); Stroke(row,C.BORD, 1.5,0.88)
 Padding(row,6,6,10,8)

 local ico = Label(row, icon, 18, C.TXT, Enum.Font.GothamBold, Enum.TextXAlignment.Center)
 ico.Size = UDim2.new(0,24,0,24); ico.Position = UDim2.new(0,0,0.5,-12)

 local ttl = Label(row, title, 13, C.TXT, Enum.Font.GothamBold)
 ttl.Size = UDim2.new(1,-90,0,16); ttl.Position = UDim2.new(0,28,0,4)

 local sub = Label(row, desc, 11, C.TXT, Enum.Font.GothamBold)
 sub.Size = UDim2.new(1,-90,0,13); sub.Position = UDim2.new(0,28,0,22)

 local btn = Btn(row, C.ACC, UDim2.new(0,52,0,26))
 btn.AnchorPoint = Vector2.new(1,0.5); btn.Position = UDim2.new(1,-6,0.5,0)
 Corner(btn, 10)
 local btnLbl = Label(btn,"CLAIM",9,C.BLACK,Enum.Font.GothamBold,Enum.TextXAlignment.Center)
 btnLbl.Size = UDim2.new(1,0,1,0)

 btn.MouseButton1Click:Connect(function()
 btn.BackgroundColor3 = C.DIM
 btnLbl.Text = "..."
 task.spawn(function()
 fn(sub, SetStatus)
 btn.BackgroundColor3 = C.GRN
 btnLbl.Text = "v"
 task.wait(2)
 btn.BackgroundColor3 = C.ACC
 btnLbl.Text = "CLAIM"
 end)
 end)

 return row, sub
 end

 --  Online Reward 
 ClaimRow(2, "", "Online Reward", "Auto scan & Claim ALL online reward", function(sub, status)
 local RE = Remotes:FindFirstChild("ClaimOnlineReward")
 if not RE then status("[X] NOT FOUND", C.RED); return end
 local claimed = 0
 local tried = 0
 local consecutive_fail = 0

 -- Strategy: scan id 1-500
 -- consecutive_fail hanya mulai dihitung SETELAH claim pertama berhasil
 -- Sebelum claim pertama: tetap scan terus tanpa stop
 -- Setelah claim pertama: stop kalau 15 id berturut-turut gagal (reward habis)
 local ever_claimed = false
 status("[] SCAN...", C.YEL)

 for id = 1, 200 do
 local ok, res = pcall(function()
 return RE:InvokeServer({id = tostring(id)})
 end)
 tried = tried + 1

 if ok and res == true then
 claimed = claimed + 1
 consecutive_fail = 0
 ever_claimed = true
 Log("[OK] id="..id.." CLAIMED!", C.GRN)
 status("[G] Claimed "..claimed.." reward (id "..id..")", C.GRN)
 else
 if ever_claimed then
 -- Sudah pernah claim -> mulai hitung fail
 consecutive_fail = consecutive_fail + 1
 if consecutive_fail >= 15 then
 Log("[S] Stop - 15 fail Before claim Latest (id "..id..")", C.DIM)
 break
 end
 end
 -- Sebelum claim pertama: scan terus tanpa stop
 end

 task.wait(0.05)
 end

 if claimed > 0 then
 status("[OK] Online Reward DONE - "..claimed.." CLAIM from "..tried.." scan", C.GRN)
 sub.Text = "LAST: "..claimed.." reward CLAIM"
 sub.TextColor3 = C.GRN
 else
 status("[i] There are no online rewards that can be claimed", C.YEL)
 sub.Text = "All have been claimed / not yet available"
 end
 end)

 --  Season Task Reward 
 ClaimRow(3, "", "Season Task Reward", "CLAIM ALL season task reward", function(sub, status)
 local RE = Remotes:FindFirstChild("ClaimSeasonTaskReward")
 if not RE then status("[X] NOT FOUND", C.RED); return end
 status("[..] Claiming season task reward...", C.YEL)
 local ok, res = pcall(function() return RE:FireServer() end)
 Log("[C] SeasonTask -> ok="..tostring(ok).." res="..tostring(res), ok and C.GRN or C.RED)
 task.wait(0.5)
 status("[OK] Season Task Reward diklaim", C.GRN)
 sub.Text = "Last: CLAIM SUCCES"
 sub.TextColor3 = C.GRN
 end)

 --  Season Pass Reward 
 ClaimRow(4, "", "Season Pass Reward", "CLAIM ALL season pass reward", function(sub, status)
 local RE = Remotes:FindFirstChild("ClaimSeasonPassReward")
 if not RE then status("[X] NOT FOUND", C.RED); return end
 status("[..] Claiming season pass reward...", C.YEL)
 local ok, res = pcall(function() return RE:FireServer() end)
 Log("[T] SeasonPass -> ok="..tostring(ok).." res="..tostring(res), ok and C.GRN or C.RED)
 task.wait(0.5)
 status("[OK] Season Pass Reward DONE", C.GRN)
 sub.Text = "LAST: DONE"
 sub.TextColor3 = C.GRN
 end)

 --  Season Reward [v117] 
 ClaimRow(5, "", "Season Reward", "Claim completed season rewards", function(sub, status)
 local RE = Remotes:FindFirstChild("ClaimSeasonReward")
 if not RE then
 RE = Remotes:FindFirstChild("ClaimSeason") or Remotes:FindFirstChild("SeasonReward")
 end
 if not RE then status("[X] NOT FOUND", C.RED); return end
 status("[..] Claiming season reward...", C.YEL)
 local ok, res = pcall(function() return RE:FireServer() end)
 Log("[W] SeasonReward -> ok="..tostring(ok).." res="..tostring(res), ok and C.GRN or C.RED)
 task.wait(0.5)
 status("[OK] Season Reward DONE", C.GRN)
 sub.Text = "LAST: DONE"
 sub.TextColor3 = C.GRN
 end)

 --  7 Day Login Reward 
 ClaimRow(6, "", "7 Day Login Reward", "CLAIM ALL DAY (1-7)", function(sub, status)
 local RE = Remotes:FindFirstChild("ClaimSevenLoginReward")
 if not RE then status("[X] NOT FOUND", C.RED); return end
 local claimed = 0
 status("[..] Claiming 7 day login reward...", C.YEL)
 for day = 1, 7 do
 local ok, res = pcall(function() return RE:FireServer(day) end)
 Log("[D] Day "..day.." -> ok="..tostring(ok).." res="..tostring(res), ok and C.GRN or C.DIM)
 if ok then claimed = claimed + 1 end
 task.wait(0.3)
 end
 status("[OK] 7 Day Login DONE - "..claimed.."/7 CLAIM", C.GRN)
 sub.Text = "LAST: "..claimed.."/7 DAY CLAIM"
 sub.TextColor3 = C.GRN
 end)

 --  Raid Reward 
 ClaimRow(7, "", "Daily Task Reward", "Claim rewards for completed daily tasks", function(sub, status)
 local RE = Remotes:FindFirstChild("ClaimDailyTaskReward")
 if not RE then status("[X] NOT FOUND", C.RED); return end
 status("[..] Claiming daily task reward...", C.YEL)
 local ok, res = pcall(function() return RE:FireServer() end)
 Log("[D] DailyTask -> ok="..tostring(ok).." res="..tostring(res), ok and C.GRN or C.RED)
 task.wait(0.5)
 if ok then
 status("[OK] Daily Task Reward DONE", C.GRN)
 sub.Text = "LAST: DONE"
 sub.TextColor3 = C.GRN
 else
 status("[!] Daily Task FAILURE", C.YEL)
 end
 end)

 --  Claim ALL button 
 local allBtn = Btn(p, C.ACC, UDim2.new(1,0,0,38))
 allBtn.LayoutOrder = 8; Corner(allBtn,10); Stroke(allBtn,C.ACC2, 1.5,0.2)
 local allLbl = Label(allBtn,"CLAIM ALL",13,C.BLACK,Enum.Font.GothamBold,Enum.TextXAlignment.Center)
 allLbl.Size = UDim2.new(1,0,1,0)

 allBtn.MouseButton1Click:Connect(function()
 allBtn.BackgroundColor3 = C.DIM
 allLbl.Text = "... Claiming..."
 task.spawn(function()
 SetStatus("[..] START CLAIM ALL...", C.YEL)

 -- Online Reward (smart scan)
 local RE1 = Remotes:FindFirstChild("ClaimOnlineReward")
 if RE1 then
 SetStatus("[G] Online Reward SCAN...", C.YEL)
 local fail, ever = 0, false
 for id = 1, 200 do
 local ok, res = pcall(function() return RE1:InvokeServer({id = tostring(id)}) end)
 if ok and res == true then
 fail = 0; ever = true
 Log("[OK] OnlineReward id="..id.." CLAIM", C.GRN)
 elseif ever then
 fail = fail + 1
 if fail >= 15 then break end
 end
 task.wait(0.05)
 end
 end

 -- Season Task
 local RE2 = Remotes:FindFirstChild("ClaimSeasonTaskReward")
 if RE2 then
 SetStatus("[C] Season Task...", C.YEL)
 pcall(function() RE2:FireServer() end)
 task.wait(0.3)
 end

 -- Season Pass
 local RE3 = Remotes:FindFirstChild("ClaimSeasonPassReward")
 if RE3 then
 SetStatus("[T] Season Pass...", C.YEL)
 pcall(function() RE3:FireServer() end)
 task.wait(0.3)
 end

 -- 7 Day Login
 local RE4 = Remotes:FindFirstChild("ClaimSevenLoginReward")
 if RE4 then
 SetStatus("[D] 7 Day Login...", C.YEL)
 for day = 1, 7 do
 pcall(function() RE4:FireServer(day) end)
 task.wait(0.2)
 end
 end

 -- Daily Task Reward
 local RE6 = Remotes:FindFirstChild("ClaimDailyTaskReward")
 if RE6 then
 SetStatus("[D] Daily Task Reward...", C.YEL)
 pcall(function() RE6:FireServer() end)
 task.wait(0.3)
 end

 SetStatus("[OK] Claim All DONE!", C.GRN)
 allBtn.BackgroundColor3 = C.GRN
 allLbl.Text = "CLAIM ALL DONE"
 task.wait(1)
 allBtn.BackgroundColor3 = C.ACC
 allLbl.Text = "CLAIM ALL"
 end)
 end)
end

-- ============================================================
-- WEBHOOK SENDER
-- ============================================================
-- ============================================================
-- PANEL : SETTINGS
-- ============================================================
do
 local p = NewPanel("settings")



 SectionHeader(p,"UI & Performance",1)
 
 do
  local _r, _s, _v = ToggleRow(p, "Potato Mode (Anti-Lag)", "Disable all VFX for performance", 2, function(v)
     _G.PotatoMode = v
     if v then
         CleanupVFX()
         pcall(function()
             for _, obj in ipairs(ScreenGui:GetDescendants()) do
                 if obj:IsA("ParticleEmitter") or obj:IsA("UIGradient") or obj:IsA("UIStroke") then
                     obj:Destroy()
                 end
             end
             Window.BackgroundTransparency = 0
         end)
         SystemNotify("[SYSTEM]: Potato Mode Activated!", 3)
     else
         Window.BackgroundTransparency = _G.ThemeTransparency
         ApplyTheme(_G.CurrentTheme)
     end
  end)
  _setPotatoToggle = _s
  _visPotato = _v
 end

 SectionHeader(p,"Raid Notif/Webhook",10)

 -- Info card
 -- info card dihapus (V142)

 --  [v115] Mode Dropdown: Raid / Siege / Keduanya 
 local modeCard = Frame(p, C.SURFACE, UDim2.new(1,0,0,0))
 modeCard.LayoutOrder=25; modeCard.AutomaticSize=Enum.AutomaticSize.Y
 Corner(modeCard,9); Stroke(modeCard,C.BORD, 1.5,0.88)
 Padding(modeCard,8,8,10,10)
 New("UIListLayout",{Parent=modeCard,SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,6)})

 local modeHdr = Label(modeCard," Mode Notifikasi Webhook",11,C.TXT,Enum.Font.GothamBold)
 modeHdr.Size=UDim2.new(1,0,0,16); modeHdr.LayoutOrder=0

 local modeSub = Label(modeCard,"Select the type of notification sent to Discord",9.5,C.TXT3,Enum.Font.GothamBold)
 modeSub.Size=UDim2.new(1,0,0,13); modeSub.LayoutOrder=1

 -- Dropdown button
 local MODE_OPTS = {
 {key="raid", label="Raid", desc="Notif saat Raid muncul/update", col=Color3.fromRGB(255,180,60)},
 {key="siege", label="Siege", desc="Notif saat Siege buka/tutup", col=Color3.fromRGB(100,180,255)},
 {key="both", label="Raid + Siege", desc="Notif Raid dan Siege", col=C.TXT},
 }
 local curModeIdx = 3 -- default: both

 local modeDDBtn = Btn(modeCard, C.DD_BG, UDim2.new(1,0,0,28))
 modeDDBtn.LayoutOrder=2; Corner(modeDDBtn,7); Stroke(modeDDBtn,C.BORD, 1.5,0.88)
 local modeDDLbl = Label(modeDDBtn," "..MODE_OPTS[curModeIdx].label,10.5,MODE_OPTS[curModeIdx].col,Enum.Font.GothamBold)
 modeDDLbl.Size=UDim2.new(1,-22,1,0); modeDDLbl.Position=UDim2.new(0,4,0,0)
 local modeArr = Label(modeDDBtn,"v",10,Color3.fromRGB(180,120,255),Enum.Font.GothamBold,Enum.TextXAlignment.Center)
 modeArr.Size=UDim2.new(0,18,1,0); modeArr.Position=UDim2.new(1,-20,0,0)

 local modeDescLbl = Label(modeCard,MODE_OPTS[curModeIdx].desc,9,C.TXT3,Enum.Font.GothamBold)
 modeDescLbl.Size=UDim2.new(1,0,0,13); modeDescLbl.LayoutOrder=3

 modeDDBtn.MouseButton1Click:Connect(function()
 CloseActiveDD()
 local absPos = modeDDBtn.AbsolutePosition
 local absSize = modeDDBtn.AbsoluteSize
 local ITEM_H = 36

 local popup = Instance.new("Frame")
 popup.Parent=DDLayer; popup.BackgroundColor3=C.DD_BG; popup.BorderSizePixel=0
 popup.Size=UDim2.new(0,absSize.X+10,0,#MODE_OPTS*(ITEM_H+2)+12)
 popup.Position=UDim2.new(0,absPos.X,0,absPos.Y+absSize.Y+3)
 popup.ZIndex=9999
 Corner(popup, 10); Stroke(popup,C.BORD, 1.5,0.2)

 local ll=Instance.new("UIListLayout",popup)
 ll.Padding=UDim.new(0,2); ll.SortOrder=Enum.SortOrder.LayoutOrder
 Instance.new("UIPadding",popup).PaddingTop=UDim.new(0,5)

 for i, opt in ipairs(MODE_OPTS) do
 local item=Instance.new("TextButton",popup)
 item.Size=UDim2.new(1,-8,0,ITEM_H); item.LayoutOrder=i
 item.BackgroundColor3=i==curModeIdx and C.SURFACE or C.BG3
 item.BackgroundTransparency=i==curModeIdx and 0.18 or 0.42
 item.BorderSizePixel=0; item.Text=""; item.AutoButtonColor=false; item.ZIndex=9999
 Instance.new("UICorner",item).CornerRadius=UDim.new(0,6)

 local iL=Instance.new("TextLabel",item)
 iL.Size=UDim2.new(1,-8,0,16); iL.Position=UDim2.new(0,10,0,4)
 iL.BackgroundTransparency=1; iL.Text=opt.label; iL.TextSize=13
 iL.Font=Enum.Font.Gotham; iL.TextColor3=opt.col
 iL.TextXAlignment=Enum.TextXAlignment.Left; iL.ZIndex=9999

 local iD=Instance.new("TextLabel",item)
 iD.Size=UDim2.new(1,-8,0,13); iD.Position=UDim2.new(0,10,0,20)
 iD.BackgroundTransparency=1; iD.Text=opt.desc; iD.TextSize=11
 iD.Font=Enum.Font.GothamBold; iD.TextColor3=C.DIM
 iD.TextXAlignment=Enum.TextXAlignment.Left; iD.ZIndex=9999

 local ii=i
 item.MouseButton1Click:Connect(function()
 CloseActiveDD()
 curModeIdx = ii
 _webhookMode = opt.key
 modeDDLbl.Text = " "..opt.label
 modeDDLbl.TextColor3 = opt.col
 modeDescLbl.Text = opt.desc
 end)
 end
 -- Expose webhook mode setter ke global
 _webhookModeSetIdx = function(idx)
  for i, opt in ipairs(MODE_OPTS) do
   if i == idx then
    curModeIdx = idx
    _webhookMode = opt.key
    modeDDLbl.Text = " "..opt.label
    modeDDLbl.TextColor3 = opt.col
    modeDescLbl.Text = opt.desc
    break
   end
  end
 end
 DDLayer.Visible=true
 _activeDDClose=function() popup:Destroy(); DDLayer.Visible=false end
 end)

 -- URL input
 local urlCard = Frame(p, C.SURFACE, UDim2.new(1,0,0,58))
 urlCard.LayoutOrder=3; Corner(urlCard,9); Stroke(urlCard,C.BORD, 1.5,0.88); Padding(urlCard,8,8,10,10)
 New("UIListLayout",{Parent=urlCard,SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,5)})
 local urlHdr=Label(urlCard,"URL Webhook",10.5,C.TXT2,Enum.Font.GothamBold)
 urlHdr.Size=UDim2.new(1,0,0,14); urlHdr.LayoutOrder=0
 local urlBox = Instance.new("TextBox")
 urlBox.Parent=urlCard; urlBox.LayoutOrder=1
 urlBox.Size=UDim2.new(1,0,0,24); urlBox.BackgroundColor3=C.BG3
 urlBox.BorderSizePixel=0; urlBox.TextSize=11; urlBox.Font=Enum.Font.GothamBold
 urlBox.TextColor3=C.TXT2; urlBox.PlaceholderColor3=C.DIM
 urlBox.PlaceholderText="PASTE YOUR LINK DISCORD HERE..."
 urlBox.Text=_webhookUrl; urlBox.TextXAlignment=Enum.TextXAlignment.Left
 urlBox.ClearTextOnFocus=false
 _webhookUrlBox = urlBox  -- expose ke global config
 Corner(urlBox,5); Stroke(urlBox,C.BORD, 1.5,0.88)
 local urlPad=Instance.new("UIPadding",urlBox)
 urlPad.PaddingLeft=UDim.new(0,6); urlPad.PaddingRight=UDim.new(0,6)
 urlBox.FocusLost:Connect(function()
 _webhookUrl = urlBox.Text:match("^%s*(.-)%s*$") or ""
 end)

 -- Platform detect label
 local platformLbl = Label(p,"",9.5,C.DIM,Enum.Font.GothamBold)
 platformLbl.LayoutOrder=4; platformLbl.Size=UDim2.new(1,0,0,13)
 function UpdatePlatformLbl()
 local url = _webhookUrl
 if url:find("discord%.com/api/webhooks") then
 platformLbl.Text="[OK] Discord webhook DETECTED"; platformLbl.TextColor3=Color3.fromRGB(100,220,100)
 elseif url:find("api%.telegram%.org") then
 platformLbl.Text="[OK] Telegram bot API DETECTED"; platformLbl.TextColor3=Color3.fromRGB(100,180,255)
 elseif url=="" then
 platformLbl.Text="Content URL"; platformLbl.TextColor3=C.DIM
 else
 platformLbl.Text="URL not recognized (Discord/Telegram)"; platformLbl.TextColor3=Color3.fromRGB(255,180,60)
 end
 end
 urlBox.FocusLost:Connect(function() UpdatePlatformLbl() end)
 UpdatePlatformLbl()

 -- Toggle aktifkan webhook
 local wRow = Frame(p,C.BG3,UDim2.new(1,0,0,50))
 wRow.LayoutOrder=5; Corner(wRow,9); Stroke(wRow,C.BORD, 1.5,0.88)
 local wL=Label(wRow," ACTIVE Webhook",13,C.TXT,Enum.Font.GothamBold)
 wL.Size=UDim2.new(0.65,0,0,20); wL.Position=UDim2.new(0,10,0,6)
 local wS=Label(wRow,"Send notifications for every update",9.5,C.TXT3,Enum.Font.GothamBold)
 wS.Size=UDim2.new(0.65,0,0,14); wS.Position=UDim2.new(0,10,0,26)
 local wPill=Btn(wRow,C.TBAR,UDim2.new(0,50,0,26))
 wPill.AnchorPoint=Vector2.new(1,0.5); wPill.Position=UDim2.new(1,-10,0.5,0); Corner(wPill,13)
 local wKnob=Frame(wPill,Color3.fromRGB(120,50,8),UDim2.new(0,20,0,20))
 wKnob.AnchorPoint=Vector2.new(0,0.5); wKnob.Position=UDim2.new(0,3,0.5,0); Corner(wKnob,10)
 wPill.MouseButton1Click:Connect(function()
    _webhookEnabled = not _webhookEnabled
    local on = _webhookEnabled
    _webhookUrl = (urlBox.Text or ""):match("^%s*(.-)%s*$") or ""
    if on and (_webhookUrl == "" or not _webhookUrl:find("discord%.com/api/webhooks") and not _webhookUrl:find("api%.telegram%.org")) then
        -- URL kosong atau tidak valid, batalkan
        _webhookEnabled = false
        on = false
        pcall(function() warn("[ASH Webhook] Isi URL webhook dulu sebelum mengaktifkan!") end)
    end
    TweenService:Create(wPill,TweenInfo.new(0.16),{BackgroundColor3=on and Color3.fromRGB(200,80,10) or C.TBAR}):Play()
    TweenService:Create(wKnob,TweenInfo.new(0.16),{
        Position=on and UDim2.new(1,-23,0.5,0) or UDim2.new(0,3,0.5,0),
        BackgroundColor3=on and Color3.fromRGB(255,255,255) or Color3.fromRGB(120,50,8),
    }):Play()
    wRow.BackgroundColor3 = on and C.BG2 or C.BG3
    pcall(UpdatePlatformLbl)
    if on then
        -- Reset cooldown agar tidak terblok pengiriman sebelumnya
        _whLastSent = 0
        if FlushWebhookPending then task.spawn(FlushWebhookPending) end
    end
 end)
 -- Visual-only setter untuk webhook toggle (update pill tanpa trigger logic)
 _visWebhookToggle = function(v)
  TweenService:Create(wPill,TweenInfo.new(0.16),{BackgroundColor3=v and Color3.fromRGB(200,80,10) or C.TBAR}):Play()
  TweenService:Create(wKnob,TweenInfo.new(0.16),{
   Position=v and UDim2.new(1,-23,0.5,0) or UDim2.new(0,3,0.5,0),
   BackgroundColor3=v and Color3.fromRGB(255,255,255) or Color3.fromRGB(120,50,8),
  }):Play()
  wRow.BackgroundColor3=v and C.BG2 or C.BG3
 end
 -- Logic setter untuk webhook toggle
 _setWebhookToggle = function(v)
  if v == _webhookEnabled then return end
  _webhookEnabled = v
  TweenService:Create(wPill,TweenInfo.new(0.16),{BackgroundColor3=v and Color3.fromRGB(200,80,10) or C.TBAR}):Play()
  TweenService:Create(wKnob,TweenInfo.new(0.16),{
   Position=v and UDim2.new(1,-23,0.5,0) or UDim2.new(0,3,0.5,0),
   BackgroundColor3=v and Color3.fromRGB(255,255,255) or Color3.fromRGB(120,50,8),
  }):Play()
  wRow.BackgroundColor3=v and C.BG2 or C.BG3
  pcall(UpdatePlatformLbl)
  if v and FlushWebhookPending then task.spawn(FlushWebhookPending) end
 end

 --  Row: Test Webhook + Verify Link 
 local btnRow = Frame(p, C.BLACK, UDim2.new(1,0,0,36))
 btnRow.LayoutOrder=6; btnRow.BackgroundTransparency=1
 New("UIListLayout",{Parent=btnRow,FillDirection=Enum.FillDirection.Horizontal,
 SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0, 10)})

 -- Test Webhook
 local testRow=Frame(btnRow,C.BG3,UDim2.new(0.5,-4,1,0))
 testRow.LayoutOrder=1; Corner(testRow,9); Stroke(testRow,C.BORD, 1.5,0.88)
 local testBtn=Btn(testRow,Color3.fromRGB(160,65,8),UDim2.new(1,-16,0,24))
 testBtn.AnchorPoint=Vector2.new(0.5,0.5); testBtn.Position=UDim2.new(0.5,0,0.5,0)
 Corner(testBtn,7); Stroke(testBtn,C.BORD, 1.5,0.88)
 local testLbl=Label(testBtn," Test Webhook",10,C.TXT,Enum.Font.GothamBold,Enum.TextXAlignment.Center)
 testLbl.Size=UDim2.new(1,0,1,0)
 testBtn.MouseButton1Click:Connect(function()
 _webhookUrl = urlBox.Text:match("^%s*(.-)%s*$") or ""
 UpdatePlatformLbl()
 local msg = "[OK] **[ASH GUI - FLa Project]** Test Webhook berhasil!\n> Mode: `"..(_webhookMode or "both"):upper().."`\n> Webhook aktif dan siap menerima notifikasi Raid/Siege."
 testLbl.Text="[..] Sending..."; testLbl.TextColor3=Color3.fromRGB(255,220,60)
 -- [FIX] Timeout UI 10s: HTTP Discord butuh 1-3 detik, jangan timeout terlalu cepat
 local _done = false
 task.delay(10, function()
 if not _done then
 _done = true
 testLbl.Text="[!] Timeout/No HTTP"; testLbl.TextColor3=Color3.fromRGB(255,80,60)
 task.delay(3, function() testLbl.Text=" Test Webhook"; testLbl.TextColor3=C.TXT end)
 end
 end)
 _WH.SendCustomMessage(_webhookUrl, msg,
 function()
 if _done then return end; _done = true
 task.spawn(function()
 testLbl.Text="[OK] Sent!"; testLbl.TextColor3=Color3.fromRGB(100,255,100)
 task.wait(2.5)
 testLbl.Text=" Test Webhook"; testLbl.TextColor3=C.TXT
 end)
 end,
 function(err)
 if _done then return end; _done = true
 task.spawn(function()
 testLbl.Text=""..err; testLbl.TextColor3=Color3.fromRGB(255,80,60)
 task.wait(2.5)
 testLbl.Text=" Test Webhook"; testLbl.TextColor3=C.TXT
 end)
 end
 )
 end)

 -- Verify Link
 local verRow=Frame(btnRow,C.BG3,UDim2.new(0.5,-4,1,0))
 verRow.LayoutOrder=2; Corner(verRow,9); Stroke(verRow,C.BORD, 1.5,0.88)
 local verBtn=Btn(verRow,C.BG2,UDim2.new(1,-16,0,24))
 verBtn.AnchorPoint=Vector2.new(0.5,0.5); verBtn.Position=UDim2.new(0.5,0,0.5,0)
 Corner(verBtn,7); Stroke(verBtn,C.BORD, 1.5,0.88)
 local verLbl=Label(verBtn,"[] Verify Link",10,C.TXT,Enum.Font.GothamBold,Enum.TextXAlignment.Center)
 verLbl.Size=UDim2.new(1,0,1,0)
 verBtn.MouseButton1Click:Connect(function()
 _webhookUrl = urlBox.Text:match("^%s*(.-)%s*$") or ""
 UpdatePlatformLbl()
 verLbl.Text="[..] Cek..."; verLbl.TextColor3=Color3.fromRGB(255,220,60)
 _WH.VerifyWebhookUrl(_webhookUrl,
 function()
 task.spawn(function()
 verLbl.Text="[OK] Link Valid!"; verLbl.TextColor3=Color3.fromRGB(100,255,100)
 task.wait(1)
 verLbl.Text="[] Verify Link"; verLbl.TextColor3=C.TXT
 end)
 end,
 function(err)
 task.spawn(function()
 verLbl.Text=""..err; verLbl.TextColor3=Color3.fromRGB(255,80,60)
 task.wait(1)
 verLbl.Text="[] Verify Link"; verLbl.TextColor3=C.TXT
 end)
 end
 )
 end)

 --  Kirim Sekarang (manual trigger sesuai mode) 
 local sendNowCard = Frame(p, C.BG3, UDim2.new(1,0,0,38))
 sendNowCard.LayoutOrder=7; Corner(sendNowCard,9); Stroke(sendNowCard,C.BORD, 1.5,0.88)
 local sendNowBtn = Btn(sendNowCard,C.BG2,UDim2.new(0.7,0,0,26))
 sendNowBtn.AnchorPoint=Vector2.new(0.5,0.5); sendNowBtn.Position=UDim2.new(0.5,0,0.5,0)
 Corner(sendNowBtn, 10); Stroke(sendNowBtn,C.BORD, 1.5,0.88)
 local sendNowLbl=Label(sendNowBtn," Send Notify Now",10.5,C.TXT,Enum.Font.GothamBold,Enum.TextXAlignment.Center)
 sendNowLbl.Size=UDim2.new(1,0,1,0)
 sendNowBtn.MouseButton1Click:Connect(function()
 _webhookUrl = urlBox.Text:match("^%s*(.-)%s*$") or ""
 if _webhookUrl == "" then
 sendNowLbl.Text="URL kosong!"; sendNowLbl.TextColor3=Color3.fromRGB(255,180,60)
 task.delay(2, function() sendNowLbl.Text=" Send Notify Now"; sendNowLbl.TextColor3=C.TXT end)
 return
 end
 sendNowLbl.Text="[..] Mengirim..."; sendNowLbl.TextColor3=Color3.fromRGB(255,220,60)
 -- [FIX] Timeout UI 12s: reset label kalau pengiriman hang
 local _snDone = false
 task.delay(12, function()
 if not _snDone then
 _snDone = true
 sendNowLbl.Text="[!] Timeout"; sendNowLbl.TextColor3=Color3.fromRGB(255,80,60)
 task.delay(2.5, function() sendNowLbl.Text=" Send Notify Now"; sendNowLbl.TextColor3=C.TXT end)
 end
 end)
 task.spawn(function()
 local mode = _webhookMode or "both"
 local url = _webhookUrl
 local sent = false
 local hasRaid = next(RAID_LIVE or {}) ~= nil
 local hasSiege = SIEGE and SIEGE.live and next(SIEGE.live) ~= nil
 if (mode == "raid" or mode == "both") and hasRaid then
 if _WH.SendRaid then _WH.SendRaid(url) end; sent = true
 end
 if (mode == "siege" or mode == "both") and hasSiege then
 task.wait(0.3)
 if _WH.SendSiege then _WH.SendSiege(url) end; sent = true
 end
 if not sent then
 -- Tidak ada data raid/siege aktif saat tombol ditekan
 if _snDone then return end; _snDone = true
 sendNowLbl.Text="[!] No Raid Data"; sendNowLbl.TextColor3=Color3.fromRGB(255,180,60)
 task.delay(2.5, function() sendNowLbl.Text=" Send Notify Now"; sendNowLbl.TextColor3=C.TXT end)
 return
 end
 _whLastSent = tick()
 if _snDone then return end; _snDone = true
 task.wait(0.5)
 sendNowLbl.Text="[OK] Sent!"; sendNowLbl.TextColor3=Color3.fromRGB(100,255,100)
 task.wait(2.5)
 sendNowLbl.Text=" Send Notify Now"; sendNowLbl.TextColor3=C.TXT
 end)
 end)
end


-- ============================================================
-- INIT
-- ============================================================
-- Pre-populate semua Ornament Quirk dengan nama lengkap
-- Urutan: common (atas) -> rare (bawah)
-- Format: {machineIdx, quirkId, "nama"}
do
 local ORN_KNOWN = {
 -- 
 -- [1] HEADDRESS - machineId=400001
 -- 
 {1, 410001, "Glowing Blue Eyes"},
 {1, 410002, "Fox Ears"},
 {1, 410003, "Blossom Crown of the Abyss"},
 {1, 410004, "Demon Horns"},
 {1, 410005, "Wizard Hat"},
 {1, 410006, "Sharktooth Hood"},
 {1, 410007, "Bunny Boom Helmet"},
 {1, 410008, "Cursed Harvest Helmet"},
 {1, 410009, "Bloodforged Casque"},
 {1, 410010, "Jester's Madness Cap"}, -- [*] RAREST

 -- 
 -- [2] ORNAMENT MACHINE - machineId=400002
 -- 
 {2, 410011, "Fox Brush"},
 {2, 410012, "Whale's Tail"},
 {2, 410013, "Dragon's Tail"},
 {2, 410014, "Dinosaur Swimming Circle"},
 {2, 410015, "Ghastroot Parasite"},
 {2, 410016, "Wishy Star Bunny"},
 {2, 410017, "Mechanical Wing"},
 {2, 410018, "Demon Wing"},
 {2, 410019, "Prism Wings"},
 {2, 410020, "Omenwing of the Void"}, -- [*] RAREST

 -- 
 -- [3] WEALTH BLESSING - machineId=400003
 -- 
 {3, 410021, "Single Glow Bless"},
 {3, 410022, "Double Stack Bless"},
 {3, 410023, "Slant Bless"},
 {3, 410024, "Misstack Bless"},
 {3, 410025, "High Stack Bless"},
 {3, 410026, "Initial Bag Bless"},
 {3, 410027, "Full Bag Bless"},
 {3, 410028, "Bag Scatter Bless"},
 {3, 410029, "Supreme Crown Gold"},
 {3, 410030, "Imperial Crown Full Bag"}, -- [*] RAREST

 -- 
 -- [4] SHADOWHUNTER BLESSING - machineId=400004
 -- 
 {4, 410031, "Shadowfelin Gaze"},
 {4, 410032, "Techowl Capture"},
 {4, 410033, "Beastglow Frame"},
 {4, 410034, "Croucharmor Beam"},
 {4, 410035, "Silveraura Agile"},
 {4, 410036, "Demonwing Aura"},
 {4, 410037, "Spikedial Gothic"},
 {4, 410038, "Galaxyvortex Lightning"},
 {4, 410039, "Demonhand Lightning"}, -- [*] RAREST

 -- 
 -- [5] PRIMORDIAL BLESSING - machineId=400005
 -- 
 {5, 410040, "Dawn's Spark"},
 {5, 410041, "Blade's Guide"},
 {5, 410042, "Edge's Glow"},
 {5, 410043, "Power's Nudge"},
 {5, 410044, "Resurgent Edge"},
 {5, 410045, "Sixth Dawn's Gift"},
 {5, 410046, "Flame's Fuel"},
 {5, 410047, "Gold Star's Whisper"},
 {5, 410048, "Stardust's Fury"}, -- [*] RAREST

 -- 
 -- [6] MONARCH POWER - machineId=400006
 -- 
 {6, 410049, "Flames Power"},
 {6, 410050, "Giant Power"},
 {6, 410051, "Beast Power"},
 {6, 410052, "Plague Power"},
 {6, 410053, "Frosh Power"},
 {6, 410054, "Unbreakable Power"},
 {6, 410057, "Transfiguration Power"},
 {6, 410056, "Destruction Power"},
 {6, 410055, "Shadow Power"}, -- [*] RAREST
 }
 for _, e in ipairs(ORN_KNOWN) do
 _ASH_ORN.AddQuirk(e[1], e[2], e[3])
 end
end

-- ============================================================
-- AUTO ROLL LOGIC - HERO
-- ============================================================
do
 local LOOPS_HR = {}

 local function StopHeroLoop(si)
 if LOOPS_HR[si] then
 task.cancel(LOOPS_HR[si])
 LOOPS_HR[si] = nil
 end
 end

 local function StartHeroSlot(si)
 StopHeroLoop(si)
 local list = QUIRK_LIST_PER_SLOT[si]
 local targets = _HR_RPT and _HR_RPT.slotTarget and _HR_RPT.slotTarget[si] or {}
 local drawId = {920001, 920002, 920003}

 -- Update nama hero saat slot 1 mulai
 if si == 1 and _HR_RPT then _HR_RPT.Refresh() end

 local function setSlot(txt, col)
 if _HR_RPT then _HR_RPT.SetSlot(si, txt, col) end
 end

 setSlot("Memulai...", Color3.fromRGB(255,200,60))

 LOOPS_HR[si] = task.spawn(function()
 local attempt = 0
 while true do
 repeat
 -- Cek GUID tersedia
 if not (_HR_RPT and _HR_RPT.guid and _HR_RPT.guid ~= "") then
 setSlot("[..] Klik 1x di Mesin Reroll dulu", Color3.fromRGB(255,150,50))
 task.wait(1); break
 end
 -- Cek target dipilih - wajib ada sebelum roll
 local hasTarget = false
 for _ in pairs(targets) do hasTarget = true; break end
 if not hasTarget then
 setSlot("[!] SELECT TARGET PLEASE!", Color3.fromRGB(255,100,60))
 task.wait(1); break
 end

 attempt = attempt + 1
 local tStr = ""
 if hasTarget then
 local names = {}
 for _, q in ipairs(list) do
 if targets[q.id] then table.insert(names, q.name) end
 end
 tStr = table.concat(names, " / ")
 end
 setSlot("Rolling #"..attempt..(tStr~="" and " | "..tStr or ""), Color3.fromRGB(255,200,60))

 -- [v231] FIX: guard heroGuid & drawId sebelum InvokeServer
 -- mencegah server crash "attempt to index nil with drawHeroid"
 if not _HR_RPT or not _HR_RPT.guid or _HR_RPT.guid == "" then
 setSlot("[!] HERO NOT FOUND - WAITING", Color3.fromRGB(255,150,50))
 task.wait(1); break
 end
 if not drawId[si] or type(drawId[si]) ~= "number" then
 setSlot("[!] invalid"..si, Color3.fromRGB(255,100,60))
 task.wait(1); break
 end
 if not RE.RandomHeroQuirk then
 setSlot("[!] Remote RandomHeroQuirk nil", Color3.fromRGB(255,80,80))
 task.wait(2); break
 end
 -- x100 path
 if _HR_RPT.x100 then
  if not RE.AutoHeroQuirk then
   setSlot("[!] Remote AutoRandomHeroQuirk nil", Color3.fromRGB(255,80,80))
   task.wait(2); break
  end
  local stopIds = {}
  for _, q in ipairs(list) do
   if targets[q.id] then table.insert(stopIds, q.id) end
  end
  if #stopIds == 0 then
   setSlot("[!] SELECT TARGET PLEASE!", Color3.fromRGB(255,100,60))
   task.wait(1); break
  end
  setSlot("[x100] Rolling #"..attempt.."..", Color3.fromRGB(100,200,255))
  _ourCall = true
  local ok100, res100 = pcall(function()
   return RE.AutoHeroQuirk:InvokeServer({
    heroGuid = _HR_RPT.guid,
    drawId = drawId[si],
    stopQuirkIds = stopIds,
   })
  end)
  _ourCall = false
  if not ok100 then
   setSlot("[!] x100 Error - retry", Color3.fromRGB(255,100,60))
   task.wait(1); break
  end
  -- [FIX] Parse result x100: scan DEEP (flat+nested+array) agar tidak kelewatan
  local gotId100, rawId100 = nil, nil
  local hit100 = false
  if type(res100) == "table" then
   -- Fungsi scan rekursif sampai 3 level
   local function DeepScan(t, depth)
    if type(t) ~= "table" or depth > 3 then return nil, nil end
    local foundHit, foundRaw = nil, nil
    local PRIO = {"finalResultId","quirkId","resultId","id","Id","result","Result"}
    for _, key in ipairs(PRIO) do
     local v = t[key]
     if type(v) == "number" and v > 0 then
      foundRaw = foundRaw or v
      if QUIRK_MAP[v] then foundHit = foundHit or v end
      if targets[v] then return v, v end -- target ketemu, berhenti
     end
    end
    for _, v in pairs(t) do
     if type(v) == "number" and v > 0 then
      foundRaw = foundRaw or v
      if QUIRK_MAP[v] then foundHit = foundHit or v end
      if targets[v] then return v, v end
     elseif type(v) == "table" then
      local h, r = DeepScan(v, depth + 1)
      if h and targets[h] then return h, h end
      foundHit = foundHit or h
      foundRaw = foundRaw or r
     end
    end
    return foundHit, foundRaw
   end
   gotId100, rawId100 = DeepScan(res100, 1)
  end
  hit100 = gotId100 ~= nil and targets[gotId100] == true
  if hit100 then
   local gn = QUIRK_MAP[gotId100] or "ID:"..tostring(gotId100)
   setSlot("DONE: "..gn.." (#"..attempt..")", Color3.fromRGB(80,220,80))
   StopHeroLoop(si)
   local allDone = true
   for i=1,3 do if LOOPS_HR[i] then allDone=false; break end end
   if allDone and _HR_RPT then _HR_RPT.SetToggleOff() end
   return
  else
   local gn = (gotId100 and QUIRK_MAP[gotId100]) or (rawId100 and "ID:"..tostring(rawId100)) or "?"
   setSlot("[x100] #"..attempt.." Last: "..gn, Color3.fromRGB(80,180,255))
  end
  task.wait(0.05); break
 end

 -- Normal 1x path
 _ourCall = true
 local ok, res = pcall(function()
  return RE.RandomHeroQuirk:InvokeServer({
   heroGuid = _HR_RPT.guid,
   drawId = drawId[si],
  })
 end)
 _ourCall = false
 if not ok then
  task.wait(1); break
 end

 -- [FIX v38] Tangkap hasil quirk - scan luas tanpa filter QUIRK_MAP
 local gotId = nil
 local _rawId = nil
 if type(res) == "table" then
 -- Pass 1: prioritas key nama spesifik
 local PRIO = {"finalResultId","quirkId","resultId","id","Id","result","Result"}
 for _, key in ipairs(PRIO) do
 local v = res[key]
 if type(v) == "number" and v > 0 then
 _rawId = _rawId or v
 if QUIRK_MAP[v] then gotId = v; break end
 end
 end
 -- Pass 2: scan flat seluruh table
 if not gotId then
 for _, v in pairs(res) do
 if type(v) == "number" and v > 0 then
 _rawId = _rawId or v
 if QUIRK_MAP[v] then gotId = v; break end
 end
 end
 end
 -- Pass 3: scan nested 1 level (cover {data={quirkId=...}})
 if not gotId then
 for _, v in pairs(res) do
 if type(v) == "table" then
 for _, vv in pairs(v) do
 if type(vv) == "number" and vv > 0 then
 _rawId = _rawId or vv
 if QUIRK_MAP[vv] then gotId = vv; break end
 end
 end
 if gotId then break end
 end
 end
 end
 end

 local gotName = QUIRK_MAP[gotId] or (gotId and "ID:"..tostring(gotId) or "?")
 -- x100: server sudah handle stop logic, kalau ok=true dan ada gotId valid = hit
 local hit
 if _HR_RPT.x100 then
  hit = ok and gotId and hasTarget and (targets[gotId] == true)
  -- Jika x100 dan server return ok tapi gotId tidak dikenal, cek semua target
  -- (server stop berarti salah satu target tercapai)
  if ok and not hit and hasTarget and _rawId then
   for id, _ in pairs(targets) do
    if _rawId == id then hit = true; gotName = QUIRK_MAP[id] or "ID:"..tostring(id); break end
   end
  end
 else
  -- [FIX] Hanya stop kalau target dipilih DAN hasil cocok
  hit = gotId and hasTarget and targets[gotId] == true
 end

 -- [FIX DEBUG] Tampilkan raw ID jika tidak dikenal di QUIRK_MAP
 if not hit and _rawId and not QUIRK_MAP[_rawId] then
 setSlot("[DBG] UnknownID:"..tostring(_rawId).." #"..attempt, Color3.fromRGB(200,150,255))
 task.wait(0.3); break
 end

 if hit then
 setSlot("DONE: "..gotName.." (#"..attempt..")", Color3.fromRGB(80,220,80))
 StopHeroLoop(si)
 -- Cek apakah semua slot sudah selesai
 local allDone = true
 for i = 1, 3 do if LOOPS_HR[i] then allDone = false; break end end
 if allDone and _HR_RPT then _HR_RPT.SetToggleOff() end
 return
 end

 task.wait(0.05)
 until true
 end
 end)
 end

 DoAutoRollHero = function(on)
 for i = 1, 3 do StopHeroLoop(i) end
 if not on then
 for i = 1, 3 do
 if _HR_RPT then _HR_RPT.SetSlot(i, "Idle", Color3.fromRGB(160,148,135)) end
 end
 -- Reset GUID agar bisa capture ulang saat ganti hero
 if _HR_RPT then
 _HR_RPT.guid = ""
 _HR_RPT.Refresh()
 end
 return
 end
 -- GUID belum ada -> tampil pesan, tunggu GUID, lalu auto-start
 if not (_HR_RPT and _HR_RPT.guid and _HR_RPT.guid ~= "") then
 for i = 1, 3 do
 if _HR_RPT then _HR_RPT.SetSlot(i, "WAITING - Click 1x on Reroll Machine", Color3.fromRGB(180,220,255)) end
 end
 -- Polling sampai GUID tersedia, lalu langsung mulai
 task.spawn(function()
 while not (_HR_RPT and _HR_RPT.guid and _HR_RPT.guid ~= "") do
 task.wait(0.5)
 end
 -- [FIX RACE] Jeda 1.5s agar server selesai proses manual click user
 task.wait(1.5)
 -- Pastikan toggle masih ON sebelum mulai
 if _HR_RPT and _HR_RPT.running then
 _HR_RPT.Refresh()
 for i = 1, 3 do StartHeroSlot(i) end
 end
 end)
 return
 end
 for i = 1, 3 do StartHeroSlot(i) end
 end
end

-- ============================================================
-- AUTO ROLL LOGIC - WEAPON
-- ============================================================
do
 local LOOPS_WR = {}

 local function StopWeaponLoop(si)
 if LOOPS_WR[si] then
 task.cancel(LOOPS_WR[si])
 LOOPS_WR[si] = nil
 end
 end

 local function StartWeaponSlot(si)
 StopWeaponLoop(si)
 local list = W_QUIRK_LIST_PER_SLOT[si]
 local targets = _WR_RPT and _WR_RPT.slotTarget and _WR_RPT.slotTarget[si] or {}
 local drawId = {960001, 960002, 960003}

 -- Update nama weapon saat slot 1 mulai (cukup sekali)
 if si == 1 and _WR_RPT then _WR_RPT.Refresh() end

 local function setSlot(txt, col)
 if _WR_RPT then _WR_RPT.SetSlot(si, txt, col) end
 end

 setSlot("Memulai...", Color3.fromRGB(255,200,60))

 LOOPS_WR[si] = task.spawn(function()
 local attempt = 0
 while true do
 repeat
 if not (_WR_RPT and _WR_RPT.guid and _WR_RPT.guid ~= "") then
 setSlot("[..] Click 1x on Reroll Machine", Color3.fromRGB(255,150,50))
 task.wait(1); break
 end
 local hasTarget = false
 for _ in pairs(targets) do hasTarget = true; break end
 -- Wajib ada target sebelum roll
 if not hasTarget then
 setSlot("[!] SELECT TARGET PLEASE!", Color3.fromRGB(255,100,60))
 task.wait(1); break
 end

 attempt = attempt + 1
 local tStr = ""
 if hasTarget then
 local names = {}
 for _, q in ipairs(list) do
 if targets[q.id] then table.insert(names, q.name) end
 end
 tStr = table.concat(names, " / ")
 end
 setSlot("Rolling #"..attempt..(tStr~="" and " | "..tStr or ""), Color3.fromRGB(255,200,60))

 _ourCall = true
 local ok, res = pcall(function()
 return RE.RandomWeaponQuirk:InvokeServer({
 guid = _WR_RPT.guid,
 drawId = drawId[si],
 })
 end)
 _ourCall = false
 if not ok then task.wait(0.5); break end

 -- [FIX v38] Tangkap hasil quirk weapon - scan luas tanpa filter W_QUIRK_MAP
 local gotId = nil
 local _rawId = nil
 if type(res) == "table" then
 -- Pass 1: prioritas key nama spesifik
 local PRIO = {"finalResultId","quirkId","resultId","id","Id","result","Result"}
 for _, key in ipairs(PRIO) do
 local v = res[key]
 if type(v) == "number" and v > 0 then
 _rawId = _rawId or v
 if W_QUIRK_MAP[v] then gotId = v; break end
 end
 end
 -- Pass 2: scan flat seluruh table
 if not gotId then
 for _, v in pairs(res) do
 if type(v) == "number" and v > 0 then
 _rawId = _rawId or v
 if W_QUIRK_MAP[v] then gotId = v; break end
 end
 end
 end
 -- Pass 3: scan nested 1 level
 if not gotId then
 for _, v in pairs(res) do
 if type(v) == "table" then
 for _, vv in pairs(v) do
 if type(vv) == "number" and vv > 0 then
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
 -- [FIX] Hanya stop kalau target dipilih DAN hasil cocok
 local hit = gotId and hasTarget and targets[gotId] == true

 -- [FIX DEBUG] Tampilkan raw ID jika tidak dikenal di W_QUIRK_MAP
 if not hit and _rawId and not W_QUIRK_MAP[_rawId] then
 setSlot("[DBG] UnknownID:"..tostring(_rawId).." #"..attempt, Color3.fromRGB(200,150,255))
 task.wait(0.3); break
 end

 if hit then
 setSlot("DONE: "..gotName.." (#"..attempt..")", Color3.fromRGB(80,220,80))
 StopWeaponLoop(si)
 local allDone = true
 for i = 1, 3 do if LOOPS_WR[i] then allDone = false; break end end
 if allDone and _WR_RPT then _WR_RPT.SetToggleOff() end
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
 for i = 1, 3 do
 if _WR_RPT then _WR_RPT.SetSlot(i, "Idle", Color3.fromRGB(160,148,135)) end
 end
 -- Reset GUID agar bisa capture ulang saat ganti weapon
 if _WR_RPT then
 _WR_RPT.guid = ""
 _WR_RPT.Refresh()
 end
 return
 end
 -- GUID belum ada -> tampil pesan, tunggu GUID, lalu auto-start
 if not (_WR_RPT and _WR_RPT.guid and _WR_RPT.guid ~= "") then
 for i = 1, 3 do
 if _WR_RPT then _WR_RPT.SetSlot(i, "Click 1x on Reroll Machine", Color3.fromRGB(180,220,255)) end
 end
 task.spawn(function()
 while not (_WR_RPT and _WR_RPT.guid and _WR_RPT.guid ~= "") do
 task.wait(0.5)
 end
 -- [FIX RACE] Jeda 1.5s agar server selesai proses manual click user
 task.wait(1.5)
 if _WR_RPT and _WR_RPT.running then
 _WR_RPT.Refresh()
 for i = 1, 3 do StartWeaponSlot(i) end
 end
 end)
 return
 end
 for i = 1, 3 do StartWeaponSlot(i) end
 end

 --  DoAutoRollPetGear 
 -- drawId fixed: 980001=slot1, 980002=slot2, 980003=slot3
 local PG_DRAW_IDS = {980001, 980002, 980003}
 local LOOPS_PG = {}

 local function StopPetGearLoop(si)
 if LOOPS_PG[si] then
 pcall(function() task.cancel(LOOPS_PG[si]) end)
 LOOPS_PG[si] = nil
 end
 end

 local function StartPetGearSlot(si)
 StopPetGearLoop(si)
 local guid = PGR.guids[si]
 local drawId = PG_DRAW_IDS[si]
 local targets = PGR.targets[si]

 local function setStatus(txt, col)
 if PGR.statLbls[si] then
 PGR.statLbls[si].Text = txt
 PGR.statLbls[si].TextColor3 = col or C.TXT2
 end
 if PGR.dotRefs[si] then
 PGR.dotRefs[si].BackgroundColor3 = col or Color3.fromRGB(100,100,100)
 end
 end

 if not guid or guid == "" then
 setStatus("[..] Click 1x on Reroll Machine", Color3.fromRGB(180,220,255))
 -- Tunggu GUID ter-capture lalu auto-start
 task.spawn(function()
 while PGR.enOnFlags[si] do
 if PGR.guids[si] and PGR.guids[si] ~= "" then
 StartPetGearSlot(si)
 return
 end
 task.wait(0.5)
 end
 end)
 return
 end

 local attempt = 0
 LOOPS_PG[si] = task.spawn(function()
 while PGR.enOnFlags[si] do
 repeat
 -- Cek GUID
 if not (PGR.guids[si] and PGR.guids[si] ~= "") then
 setStatus("[..] Click 1x on Reroll Machine", Color3.fromRGB(180,220,255))
 task.wait(1); break
 end
 -- Cek target - wajib ada sebelum roll
 local hasTarget = false
 for _ in pairs(PGR.targets[si]) do hasTarget = true; break end
 if not hasTarget then
 setStatus("[!] SELECT TARGET PLEASE!", Color3.fromRGB(255,100,60))
 task.wait(1); break
 end

 attempt = attempt + 1
 if PGR.attemptLbls[si] then
 PGR.attemptLbls[si].Text = "Attempt: #"..attempt
 end
 setStatus("[~] Roll #"..attempt, Color3.fromRGB(255,160,30))

                        _ourCall = true
                        local ok, res = pcall(function()
                            return RE.RandomHeroEquipGrade:InvokeServer({
                                guid   = PGR.guids[si],
                                drawId = PG_DRAW_IDS[si],
                            })
                        end)
                        _ourCall = false

 if not ok then
 setStatus("[!] Error - retry...", Color3.fromRGB(255,100,60))
 task.wait(0.5); break
 end

 -- [v216] Parse gradeId rekursif - confirmed ada di res.data.grade
 local gotId = nil
 if type(res) == "table" then
 -- Cara 1: root level
 gotId = res.gradeId or res.grade or res.id or res.resultId
 -- Cara 2: res.data.grade (confirmed dari sniff)
 if type(gotId) ~= "number" and type(res.data) == "table" then
 gotId = res.data.grade or res.data.gradeId or res.data.id
 end
 -- Cara 3: scan rekursif seluruh table
 if type(gotId) ~= "number" then
 local function FindGradeId(t, depth)
 if type(t) ~= "table" or depth > 4 then return nil end
 for k, v in pairs(t) do
 if type(v) == "number" and v >= 990000 and v <= 999999 then
 return v
 elseif type(v) == "table" then
 local found = FindGradeId(v, depth+1)
 if found then return found end
 end
 end
 return nil
 end
 gotId = FindGradeId(res, 1)
 end
 end

 -- [v103] Hanya stop kalau target dipilih DAN hasil cocok
 local hit = gotId and hasTarget and PGR.targets[si][gotId] == true

 if hit then
 setStatus("[!] Target SUCCES! (#"..attempt..")", Color3.fromRGB(80,255,120))
 if PGR.lastLbls[si] then
 local gradeName = PG_GRADE_MAP[gotId] or "?"
 PGR.lastLbls[si].Text = "Last: "..gradeName.." - TARGET!"
 end
 PGR.enOnFlags[si] = false
 if PGR.toggleBtns[si] then PGR.toggleBtns[si].BackgroundColor3 = C.BG3 end
 if PGR.toggleKnobs[si] then PGR.toggleKnobs[si].Position = UDim2.new(0,2,0.5,-9) end
 break
 else
 setStatus("[OK] Roll #"..attempt.." DONE", Color3.fromRGB(80,180,80))
 if PGR.lastLbls[si] then
 local gradeName = gotId and PG_GRADE_MAP[gotId] or "?"
 PGR.lastLbls[si].Text = "Last: "..gradeName
 end
 end
 task.wait(0.05)
 until true
 end
 setStatus("[.] Idle", Color3.fromRGB(160,148,135))
 end)
 end

 DoAutoRollPetGear = function(si, on)
 StopPetGearLoop(si)
 if not on then
 -- [v103] Reset GUID saat toggle OFF - wajib Reroll 1x lagi
 PGR.guids[si] = ""
 PGR.captured[si] = false
 if PGR.statLbls[si] then
 PGR.statLbls[si].Text = "Click 1x on Reroll Machine"
 PGR.statLbls[si].TextColor3 = C.TXT2
 end
 if PGR.dotRefs[si] then
 PGR.dotRefs[si].BackgroundColor3 = Color3.fromRGB(100,100,100)
 end
 return
 end
 -- Cek target dipilih dulu
 local hasTarget = false
 for _ in pairs(PGR.targets[si]) do hasTarget = true; break end
 if not hasTarget then
 if PGR.statLbls[si] then
 PGR.statLbls[si].Text = "SELECT TARGET PLEASE!"
 PGR.statLbls[si].TextColor3 = Color3.fromRGB(255,100,60)
 end
 -- Tetap jalankan slot, dia akan loop tunggu target
 end
 StartPetGearSlot(si)
 end
end

-- ============================================================
-- ============================================================
-- CAPTURE SYSTEM - TRIPLE METHOD (100% Reliable semua executor)
-- ============================================================
do
-- ============================================================
-- CAPTURE SYSTEM - __namecall hook + flag _ourCall
-- Struktur identik dengan v42.lua yang terbukti bekerja benar:
--   1. Bandingkan self dengan remote OBJECT (bukan string name)
--   2. _old(self,...) dipanggil LANGSUNG - JANGAN dibungkus pcall
--      karena pcall memutus __namecall context di Roblox/Delta
--   3. _ourCall guard: saat script kita InvokeServer, bypass capture
-- ============================================================

-- Helper: validasi GUID
local function IsValidGUID(s)
    return type(s) == "string" and #s > 20 and s:find("-") ~= nil
end

-- Helper capture GUID hero dari arg
local function _captureHeroGuid(arg1)
    if type(arg1) ~= "table" then return end
    local g = arg1.heroGuid or arg1.HeroGuid or arg1.guid
    if not IsValidGUID(g) then return end
    if _HR_RPT then _HR_RPT.guid = g; pcall(_HR_RPT.Refresh) end
    local dup = false
    for _, ex in ipairs(HERO_GUIDS) do if ex == g then dup = true; break end end
    if not dup then table.insert(HERO_GUIDS, g) end
end

-- Helper capture GUID weapon dari arg
local function _captureWeaponGuid(arg1)
    if type(arg1) ~= "table" then return end
    local g = arg1.guid or arg1.weaponGuid or arg1.id
    if not IsValidGUID(g) then return end
    if _WR_RPT then _WR_RPT.guid = g; pcall(_WR_RPT.Refresh) end
end

-- Helper capture GUID pet gear dari arg
local function _capturePetGearGuid(arg1)
    if type(arg1) ~= "table" then return end
    local g   = arg1.guid
    local dId = arg1.drawId
    if not IsValidGUID(g) then return end
    if type(dId) ~= "number" then return end
    local si = ({[980001]=1,[980002]=2,[980003]=3})[dId]
    if si and PGR then
        PGR.guids[si]    = g
        PGR.captured[si] = true
        if PGR.statLbls[si] then
            PGR.statLbls[si].Text       = "GUID captured - siap roll"
            PGR.statLbls[si].TextColor3 = Color3.fromRGB(80, 220, 80)
        end
    end
end

local function SetupUniversalSpy()
    if _layer0Active then return end
    _layer0Active = true

    -- Cache remote objects saat setup (bukan string, bukan GetAttribute)
    local _rHero      = RE.RandomHeroQuirk
    local _rAuto      = RE.AutoHeroQuirk
    local _rWeapon    = RE.RandomWeaponQuirk
    local _rPetG      = RE.RandomHeroEquipGrade
    local _rHeroSkill = RE.HeroUseSkill

    -- Coba pasang __namecall hook (Delta/Xeno support)
    local hookOk = false
    pcall(function()
        if type(getrawmetatable)  ~= "function" then return end
        if type(setreadonly)      ~= "function" then return end
        if type(newcclosure)      ~= "function" then return end
        if type(getnamecallmethod)~= "function" then return end

        local mt = getrawmetatable(game)
        if not mt then return end
        local _old = mt.__namecall
        if not _old then return end

        setreadonly(mt, false)
        mt.__namecall = newcclosure(function(self, ...)
            -- [v254 FIX] Bypass semua method selain FireServer/InvokeServer
            -- TANPA pcall agar tidak rusak context (require, dll langsung pass-through)
            local _m = ""
            pcall(function() _m = getnamecallmethod() end)
            if _m ~= "FireServer" and _m ~= "InvokeServer" then
                return _old(self, ...)
            end

            local arg1 = select(1, ...)

            -- Capture HeroUseSkill -> HERO_GUIDS (untuk MA/Raid/Siege)
            -- Hanya saat bukan panggilan kita sendiri
            if self == _rHeroSkill and not _ourCall then
                if type(arg1) == "table" and IsValidGUID(arg1.heroGuid) then
                    local dup = false
                    for _, g in ipairs(HERO_GUIDS) do
                        if g == arg1.heroGuid then dup = true; break end
                    end
                    if not dup then table.insert(HERO_GUIDS, arg1.heroGuid) end
                end
                return _old(self, ...)
            end

            -- Bukan remote reroll target -> pass through langsung
            if self ~= _rHero and self ~= _rAuto and self ~= _rWeapon and self ~= _rPetG then
                return _old(self, ...)
            end

            -- Saat script kita sendiri yang call reroll remote -> skip capture, langsung teruskan
            if _ourCall then
                return _old(self, ...)
            end

            -- Jalankan remote asli DULU, baru capture GUID dari arg
            -- PENTING: _old(self,...) TANPA pcall wrapper agar context namecall terjaga
            local r1, r2, r3, r4, r5 = _old(self, ...)

            -- Capture setelah remote sukses
            if self == _rHero or self == _rAuto then
                pcall(_captureHeroGuid, arg1)
            elseif self == _rWeapon then
                pcall(_captureWeaponGuid, arg1)
            elseif self == _rPetG then
                pcall(_capturePetGearGuid, arg1)
            end

            return r1, r2, r3, r4, r5
        end)
        setreadonly(mt, true)
        hookOk = true
    end)

    if not hookOk then
        -- Fallback: polling PlayerManager setiap 2 detik
        task.spawn(function()
            while ScreenGui and ScreenGui.Parent do
                task.wait(2)
                pcall(function()
                    local _pm = require(game:GetService("ReplicatedStorage").Scripts.Client.Manager.PlayerManager)
                    if not _pm or not _pm.localPlayerData then return end
                    -- Hero GUID
                    local heroes = _pm.localPlayerData.heros or _pm.localPlayerData.heroes
                    if heroes then
                        for guid, data in pairs(heroes) do
                            if IsValidGUID(guid) and data.isEquip then
                                local dup = false
                                for _, ex in ipairs(HERO_GUIDS) do if ex == guid then dup = true; break end end
                                if not dup then table.insert(HERO_GUIDS, guid) end
                                if _HR_RPT and (_HR_RPT.guid == nil or _HR_RPT.guid == "") then
                                    _HR_RPT.guid = guid
                                    if _HR_RPT.Refresh then pcall(_HR_RPT.Refresh) end
                                end
                            end
                        end
                    end
                    -- Weapon GUID
                    local weapons = _pm.localPlayerData.weapons
                    if weapons and _WR_RPT and (_WR_RPT.guid == nil or _WR_RPT.guid == "") then
                        for guid, data in pairs(weapons) do
                            if IsValidGUID(guid) and data.isEquip then
                                _WR_RPT.guid = guid
                                if _WR_RPT.Refresh then pcall(_WR_RPT.Refresh) end
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
end

-- Eksekusi Akhir
ApplyTheme("Solo Leveling")
SwitchTab("main")
RefreshStatus()
if InitAllCaptureLayers then InitAllCaptureLayers() end

-- ============================================================
-- PANEL : THEME
-- ============================================================
do
    local p = NewPanel("theme")
    SectionHeader(p, "Theme Selection", 1)
    
    local _, _setTransSliderLocal = SliderRow(p, "UI Transparency", 1, 100, 42, function(v)
        _G.ThemeTransparency = (v - 1) / 99
        if not _G.PotatoMode then
            TweenService:Create(Window, TweenInfo.new(0.3), {BackgroundTransparency = _G.ThemeTransparency}):Play()
        end
    end)
    _setTransSlider = _setTransSliderLocal
    
    SectionHeader(p, "Color Palettes (30 Themes)", 10)
    
    local themeGrid = Frame(p, C.BLACK, UDim2.new(1,0,0,0))
    themeGrid.BackgroundTransparency = 1; themeGrid.AutomaticSize = Enum.AutomaticSize.Y
    themeGrid.LayoutOrder = 11
    local gl = New("UIGridLayout", {
        Parent = themeGrid, CellPadding = UDim2.new(0,5,0,5),
        CellSize = UDim2.new(0, math.floor(WIN_W/3)-12, 0, 34),
        SortOrder = Enum.SortOrder.Name
    })
    
    for name, colors in pairs(ThemePalettes) do
        local b = Btn(themeGrid, C.SURFACE, UDim2.new(1,0,1,0))
        b.Name = name; Corner(b, 6); Stroke(b, C.BORD, 1, 0.8)
        local l = Label(b, name, 8, C.TXT, Enum.Font.GothamBold, Enum.TextXAlignment.Center)
        l.Size = UDim2.new(1,0,1,0); l.TextWrapped = true
        
        b.MouseButton1Click:Connect(function()
            ApplyTheme(name)
        end)
    end
end
 
 ApplyTheme("Solo Leveling")
 SwitchTab("main")
 RefreshStatus()
 InitAllCaptureLayers()

-- ============================================================

-- SIEGE SCANNER (OPTIMIZED & CLEAN) - FINAL REPAIR
-- ============================================================
task.spawn(function()
    task.wait(5) 
    local _reCity = Remotes:FindFirstChild("UpdateCityRaidInfo")
    local getCR = Remotes:FindFirstChild("GetCityRaidInfos")

    if not SIEGE then return end
    if not SIEGE.live then SIEGE.live = {} end

    if getCR then
        pcall(function()
            local result = getCR:InvokeServer()
            if type(result) == "table" then
                for _, entry in ipairs(result) do
                    if entry.id and entry.rankInfo then 
                        local mn = CITY_TO_MAP_CONN[entry.id]
                        if mn then SIEGE.live[entry.id] = mn end
                    end 
                end 
            end 
        end)
    end

    if _reCity then
        _reCity.OnClientEvent:Connect(function(data)
            if type(data) ~= "table" then return end
            local id, action = data.id, data.action
            local mn = CITY_TO_MAP_CONN[id]
            
            -- [[ FIX KRITIS: JANGAN PAKAI 'END' SETELAH RETURN ]]
            if not id or not action or not mn then 
                return 
            elseif action == "OpenCityRaid" then
                SIEGE.live[id] = mn
                if _siegeWakeup then pcall(function() _siegeWakeup:Fire() end) end
                -- [v_FIX] TriggerWebhookDebounce sudah no-op, kirim langsung via _WH.SendSiege
                if not _whSilent and _webhookEnabled and _webhookUrl and _webhookUrl ~= "" then
                    task.delay(1, function()
                        if _WH and _WH.SendSiege then
                            pcall(function() _WH.SendSiege(_webhookUrl) end)
                        end
                    end)
                end
            elseif action == "CloseCityRaid" or action == "LeaveCityRaid" then
                SIEGE.live[id] = nil
                if _siegeChatOpen then _siegeChatOpen[mn] = false end
            end
        end) 
    end 
end)


-- ============================================================
-- CLEANUP: Stop semua loop saat script di-close / ScreenGui destroy
-- ============================================================
ScreenGui.AncestryChanged:Connect(function()
 if ScreenGui.Parent then return end -- hanya saat di-destroy
 -- Ascension Tower
 pcall(function() if ASC and ASC.running then StopAscension() end end)
 -- Auto Raid
 pcall(function() if RAID and RAID.running then StopRaid() end end)
 -- Auto Siege
 pcall(function() if SIEGE and StopSiege then StopSiege() end end)
 -- Auto Dungeon
 pcall(function() if DUNGEON and StopDungeon then StopDungeon() end end)
 -- Auto ST2
 pcall(function() if ST2 and ST2.running and StartST2Loop then
  ST2.running = false
  if ST2.thread then pcall(function() task.cancel(ST2.thread) end); ST2.thread = nil end
 end end)
 -- Mass Attack
 pcall(function() if MA and MA.running then MA.running = false end end)
 -- Hero Fastroll
 pcall(function() if _HR_RPT then
  _HR_RPT.running = false
  if _HR_RPT.x100 then _HR_RPT.x100 = false end
  if _HR_RPT.x100Thread then pcall(function() task.cancel(_HR_RPT.x100Thread) end); _HR_RPT.x100Thread = nil end
 end end)
 -- Ornament loops
 pcall(function() if ORN then
  for i = 1, #_ASH_ORN.MACHINES do
   ORN.running[i] = false
   ORN.enOnFlags[i] = false
  end
 end end)
 -- Pet Gear
 pcall(function() if PGR then
  for i = 1, 3 do PGR.enOnFlags[i] = false end
 end end)
 pcall(function() if PGR100 then
  for i = 1, 3 do
   PGR100.running[i] = false
   PGR100.enOnFlags[i] = false
   if PGR100.threads[i] then pcall(function() task.cancel(PGR100.threads[i]) end); PGR100.threads[i] = nil end
  end
 end end)
 -- Stop semua loop via LOOPS table
 pcall(function() if LOOPS then
  for k, t in pairs(LOOPS) do
   pcall(function() task.cancel(t) end)
   LOOPS[k] = nil
  end
 end end)
end)
