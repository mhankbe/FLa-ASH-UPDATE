-- Extract suffix langsung dari UtilHelper game
-- Panggil NumberToString dan TransferNumber dengan berbagai nilai

local RS = game:GetService("ReplicatedStorage")

print("=== EXTRACT SUFFIX FROM UtilHelper ===")

local ok, UtilHelper = pcall(require, RS.Scripts.Share.UtilHelper)
if not ok then
    print("GAGAL require UtilHelper: " .. tostring(UtilHelper))
    return
end

print("Required OK!")
print("")

-- Test NumberToString dengan berbagai nilai
local testValues = {
    1, 10, 100, 999,
    1e3, 1e4, 1e5, 1e6,
    1e7, 1e8, 1e9,
    1e10, 1e11, 1e12,
    1e13, 1e14, 1e15,
    1e16, 1e17, 1e18,
    1e19, 1e20, 1e21,
    1e22, 1e23, 1e24,
    1e25, 1e26, 1e27,
    1e28, 1e29, 1e30,
    1e31, 1e32, 1e33,
    1e34, 1e35, 1e36,
    1e37, 1e38, 1e39,
    1e40, 1e41, 1e42,
    1e43, 1e44, 1e45,
    1e46, 1e47, 1e48,
    1e49, 1e50, 1e51,
    1e52, 1e53, 1e54,
    1e55, 1e56, 1e57,
    1e58, 1e59, 1e60,
    1e61, 1e62, 1e63,
    1e64, 1e65, 1e66,
    1e67, 1e68, 1e69,
    1e70, 1e75, 1e78,
    1e80, 1e81, 1e83,
    1e84, 1e87, 1e90,
}

-- Test NumberToString
if UtilHelper.NumberToString then
    print("--- NumberToString ---")
    for _, v in ipairs(testValues) do
        local ok2, result = pcall(UtilHelper.NumberToString, v)
        if ok2 then
            print(string.format("1e%02d -> %s", math.floor(math.log10(v+1)), tostring(result)))
        end
    end
end

print("")

-- Test TransferNumber
if UtilHelper.TransferNumber then
    print("--- TransferNumber ---")
    for _, v in ipairs(testValues) do
        local ok2, result = pcall(UtilHelper.TransferNumber, v)
        if ok2 then
            print(string.format("1e%02d -> %s", math.floor(math.log10(v+1)), tostring(result)))
        end
    end
end

print("")

-- Test TransferNumber1
if UtilHelper.TransferNumber1 then
    print("--- TransferNumber1 ---")
    for _, v in ipairs(testValues) do
        local ok2, result = pcall(UtilHelper.TransferNumber1, v)
        if ok2 then
            print(string.format("1e%02d -> %s", math.floor(math.log10(v+1)), tostring(result)))
        end
    end
end

print("=== DONE ===")
