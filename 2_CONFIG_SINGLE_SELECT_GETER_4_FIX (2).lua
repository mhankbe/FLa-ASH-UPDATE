-- DPS Display - Real-time dari ShowEnemyTakeDamageInfo
-- Draggable, minimize, close, tampilan mirip gambar referensi

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UIS          = game:GetService("UserInputService")
local RS           = game:GetService("ReplicatedStorage")
local LP           = Players.LocalPlayer
local PG           = LP:WaitForChild("PlayerGui")
local MY_ID        = tostring(LP.UserId)

-- Bersihkan instance lama
local old = PG:FindFirstChild("ASH_DPS")
if old then old:Destroy() end

local sg = Instance.new("ScreenGui")
sg.Name           = "ASH_DPS"
sg.ResetOnSpawn   = false
sg.IgnoreGuiInset = true
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
sg.Parent         = PG

-- ============================================================
-- WINDOW
-- ============================================================
local WIN_W = 280
local WIN_H = 110

local win = Instance.new("Frame")
win.Size             = UDim2.new(0, WIN_W, 0, WIN_H)
win.Position         = UDim2.new(0.5, -140, 0, 20)
win.BackgroundColor3 = Color3.fromRGB(18, 18, 28)
win.BackgroundTransparency = 0.1
win.BorderSizePixel  = 0
win.Active           = true
win.Parent           = sg

local winCorner = Instance.new("UICorner")
winCorner.CornerRadius = UDim.new(0, 12)
winCorner.Parent       = win

-- Stroke border
local stroke = Instance.new("UIStroke")
stroke.Color     = Color3.fromRGB(255, 180, 0)
stroke.Thickness = 1.5
stroke.Transparency = 0.4
stroke.Parent    = win

-- TITLE BAR
local titleBar = Instance.new("Frame")
titleBar.Size             = UDim2.new(1, 0, 0, 26)
titleBar.Position         = UDim2.new(0, 0, 0, 0)
titleBar.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
titleBar.BackgroundTransparency = 0.1
titleBar.BorderSizePixel  = 0
titleBar.Active           = true
titleBar.Parent           = win

local tbCorner = Instance.new("UICorner")
tbCorner.CornerRadius = UDim.new(0, 12)
tbCorner.Parent       = titleBar

local titleLbl = Instance.new("TextLabel")
titleLbl.Size               = UDim2.new(1, -60, 1, 0)
titleLbl.Position           = UDim2.new(0, 10, 0, 0)
titleLbl.BackgroundTransparency = 1
titleLbl.Text               = "⚔ DPS METER"
titleLbl.TextColor3         = Color3.fromRGB(255, 200, 50)
titleLbl.Font               = Enum.Font.GothamBold
titleLbl.TextSize           = 12
titleLbl.TextXAlignment     = Enum.TextXAlignment.Left
titleLbl.TextYAlignment     = Enum.TextYAlignment.Center
titleLbl.Parent             = titleBar

-- Tombol minimize
local btnMin = Instance.new("TextButton")
btnMin.Size             = UDim2.new(0, 24, 0, 20)
btnMin.Position         = UDim2.new(1, -52, 0, 3)
btnMin.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
btnMin.BorderSizePixel  = 0
btnMin.Text             = "_"
btnMin.TextColor3       = Color3.fromRGB(255, 255, 255)
btnMin.Font             = Enum.Font.GothamBold
btnMin.TextSize         = 12
btnMin.Parent           = titleBar
Instance.new("UICorner", btnMin).CornerRadius = UDim.new(0, 4)

-- Tombol close
local btnClose = Instance.new("TextButton")
btnClose.Size             = UDim2.new(0, 24, 0, 20)
btnClose.Position         = UDim2.new(1, -26, 0, 3)
btnClose.BackgroundColor3 = Color3.fromRGB(180, 30, 30)
btnClose.BorderSizePixel  = 0
btnClose.Text             = "✕"
btnClose.TextColor3       = Color3.fromRGB(255, 255, 255)
btnClose.Font             = Enum.Font.GothamBold
btnClose.TextSize         = 12
btnClose.Parent           = titleBar
Instance.new("UICorner", btnClose).CornerRadius = UDim.new(0, 4)

-- BODY
local body = Instance.new("Frame")
body.Size             = UDim2.new(1, 0, 1, -26)
body.Position         = UDim2.new(0, 0, 0, 26)
body.BackgroundTransparency = 1
body.Parent           = win

-- Label "DPS" (badge kuning, mirip referensi)
local dpsTag = Instance.new("TextLabel")
dpsTag.Size               = UDim2.new(0, 60, 0, 36)
dpsTag.Position           = UDim2.new(0, 10, 0, 10)
dpsTag.BackgroundColor3   = Color3.fromRGB(220, 160, 0)
dpsTag.BorderSizePixel    = 0
dpsTag.Text               = "DPS"
dpsTag.TextColor3         = Color3.fromRGB(255, 255, 255)
dpsTag.Font               = Enum.Font.GothamBold
dpsTag.TextSize           = 18
dpsTag.TextXAlignment     = Enum.TextXAlignment.Center
dpsTag.TextYAlignment     = Enum.TextYAlignment.Center
dpsTag.Parent             = body
Instance.new("UICorner", dpsTag).CornerRadius = UDim.new(0, 8)

-- Nilai DPS (teks besar merah-oranye, mirip referensi)
local dpsVal = Instance.new("TextLabel")
dpsVal.Size               = UDim2.new(1, -80, 0, 40)
dpsVal.Position           = UDim2.new(0, 76, 0, 6)
dpsVal.BackgroundTransparency = 1
dpsVal.Text               = "0"
dpsVal.TextColor3         = Color3.fromRGB(255, 80, 60)
dpsVal.Font               = Enum.Font.GothamBold
dpsVal.TextSize            = 28
dpsVal.TextXAlignment      = Enum.TextXAlignment.Left
dpsVal.TextYAlignment      = Enum.TextYAlignment.Center
dpsVal.TextScaled          = true
dpsVal.Parent              = body

-- Sub info: hits/s dan total damage
local subInfo = Instance.new("TextLabel")
subInfo.Size               = UDim2.new(1, -10, 0, 20)
subInfo.Position           = UDim2.new(0, 10, 0, 52)
subInfo.BackgroundTransparency = 1
subInfo.Text               = "Hits/s: 0   |   Total: 0   |   Crit: 0%"
subInfo.TextColor3         = Color3.fromRGB(180, 180, 220)
subInfo.Font               = Enum.Font.Gotham
subInfo.TextSize           = 11
subInfo.TextXAlignment     = Enum.TextXAlignment.Left
subInfo.TextYAlignment     = Enum.TextYAlignment.Center
subInfo.Parent             = body

-- Tombol RESET kecil
local btnReset = Instance.new("TextButton")
btnReset.Size             = UDim2.new(0, 50, 0, 16)
btnReset.Position         = UDim2.new(1, -58, 0, 58)
btnReset.BackgroundColor3 = Color3.fromRGB(50, 50, 80)
btnReset.BorderSizePixel  = 0
btnReset.Text             = "RESET"
btnReset.TextColor3       = Color3.fromRGB(200, 200, 255)
btnReset.Font             = Enum.Font.GothamBold
btnReset.TextSize         = 10
btnReset.Parent           = body
Instance.new("UICorner", btnReset).CornerRadius = UDim.new(0, 4)

-- ============================================================
-- DRAG
-- ============================================================
local dragging, dragStart, startPos = false, nil, nil

titleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true; dragStart = input.Position; startPos = win.Position
    end
end)
titleBar.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)
UIS.InputChanged:Connect(function(input)
    if not dragging then return end
    if input.UserInputType == Enum.UserInputType.MouseMovement
    or input.UserInputType == Enum.UserInputType.Touch then
        local d = input.Position - dragStart
        win.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset+d.X,
                                  startPos.Y.Scale, startPos.Y.Offset+d.Y)
    end
end)

-- ============================================================
-- MINIMIZE / CLOSE
-- ============================================================
local minimized = false
btnMin.MouseButton1Click:Connect(function()
    minimized = not minimized
    body.Visible = not minimized
    win.Size = minimized and UDim2.new(0, WIN_W, 0, 26) or UDim2.new(0, WIN_W, 0, WIN_H)
    btnMin.Text = minimized and "▲" or "_"
end)

btnClose.MouseButton1Click:Connect(function()
    sg:Destroy()
end)

-- ============================================================
-- FORMAT angka besar -> scientific (mirip game: 1.89E+26)
-- ============================================================
local function fmtDps(n)
    if not n or n <= 0 then return "0" end
    if n < 1 then return string.format("%.1f", n) end
    -- Format game asli: eksponen selalu kelipatan 3 (SI style: E78, E81, E84...)
    -- Mantissa menyesuaikan: bisa 1.X, 12.X, atau 123.X
    -- Contoh: 6.03e79 -> 60.3E78 | 1.26e83 -> 126.5E81 | 1.1e81 -> 1.1E81
    local exp  = math.floor(math.log10(n))
    local exp3 = math.floor(exp / 3) * 3   -- bulatkan ke bawah ke kelipatan 3
    local mant = n / (10 ^ exp3)
    return string.format("%.1fE%d", mant, exp3)
end

local function fmtShort(n)
    if n >= 1e12 then return string.format("%.1fT", n/1e12)
    elseif n >= 1e9 then return string.format("%.1fB", n/1e9)
    elseif n >= 1e6 then return string.format("%.1fM", n/1e6)
    elseif n >= 1e3 then return string.format("%.1fK", n/1e3)
    else return string.format("%.0f", n) end
end

-- ============================================================
-- DPS ENGINE
-- Window = 1 detik geser (sliding window)
-- Setiap hit dari ShowEnemyTakeDamageInfo masuk ke bucket
-- ============================================================
local WINDOW_SEC = 1.0   -- hitung DPS per 1 detik terakhir

local hits = {}          -- list {t=tick(), dmg=n, isCrit=bool}
local totalDmg  = 0
local totalHits = 0
local totalCrit = 0

local function resetStats()
    hits      = {}
    totalDmg  = 0
    totalHits = 0
    totalCrit = 0
    dpsVal.Text  = "0"
    subInfo.Text = "Hits/s: 0   |   Total: 0   |   Crit: 0%"
end

btnReset.MouseButton1Click:Connect(resetStats)

-- Listen remote ShowEnemyTakeDamageInfo
local remote = RS:WaitForChild("Remotes", 10)
remote = remote and remote:WaitForChild("ShowEnemyTakeDamageInfo", 10)

if remote then
    remote.OnClientEvent:Connect(function(data)
        if type(data) ~= "table" then return end
        -- Filter: hanya damage dari player kita
        local uid = tostring(data.attackUserId or "")
        if uid ~= MY_ID then return end
        -- Ambil nilai damage (pakai attack, fallback ke realityHarm)
        local dmg = tonumber(data.attack) or tonumber(data.realityHarm) or 0
        if dmg <= 0 then return end
        local isCrit = data.isCrit == true
        local now    = tick()
        -- Masukkan ke sliding window
        table.insert(hits, {t=now, dmg=dmg, isCrit=isCrit})
        totalDmg  = totalDmg + dmg
        totalHits = totalHits + 1
        if isCrit then totalCrit = totalCrit + 1 end
    end)
else
    dpsVal.Text  = "NO REMOTE"
    subInfo.Text = "ShowEnemyTakeDamageInfo tidak ditemukan"
end

-- Update display setiap 0.1 detik
task.spawn(function()
    while sg and sg.Parent do
        local now    = tick()
        local cutoff = now - WINDOW_SEC

        -- Buang hit yang sudah di luar window
        local i = 1
        while i <= #hits do
            if hits[i].t < cutoff then
                table.remove(hits, i)
            else
                i = i + 1
            end
        end

        -- Hitung DPS dari window sekarang
        local windowDmg  = 0
        local windowHits = #hits
        local windowCrit = 0
        for _, h in ipairs(hits) do
            windowDmg  = windowDmg + h.dmg
            if h.isCrit then windowCrit = windowCrit + 1 end
        end

        local dps      = windowDmg / WINDOW_SEC
        local critRate = (windowHits > 0) and (windowCrit / windowHits * 100) or 0

        -- Update UI
        dpsVal.Text  = fmtDps(dps)
        subInfo.Text = string.format(
            "Hits/s: %d   |   Total: %s   |   Crit: %.0f%%",
            windowHits, fmtShort(totalDmg), critRate
        )

        -- Warna DPS: merah makin tinggi
        if dps <= 0 then
            dpsVal.TextColor3 = Color3.fromRGB(120, 120, 140)
        elseif critRate > 50 then
            dpsVal.TextColor3 = Color3.fromRGB(255, 60, 60)
        else
            dpsVal.TextColor3 = Color3.fromRGB(255, 140, 40)
        end

        task.wait(0.1)
    end
end)
