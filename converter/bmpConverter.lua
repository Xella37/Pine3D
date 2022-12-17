
-- Made by Xella#8655

local bitmap = require("bitmap")

term.write("> filename: ")
local path = shell.dir() .. "/" .. read()

print("Loading " .. path .. ".bmp")
local file = fs.open(path .. ".bmp", "rb")

if not file then
	error("Failed to load file from path " .. path .. ".bmp")
end

local raw = file:readAll()
file:close()

local bmp = bitmap.from_string(raw)

if not bmp then
	error("Failed to parse the bmp!")
end

local termColors = {}
for i = 1, 16 do
    local color = 2 ^ (i - 1)
    local r, g, b = term.getPaletteColor(color)
    local char = ("0123456789abcdef"):sub(i, i)
    termColors[#termColors+1] = {r=r, g=g, b=b, code=char, color=color}
end

local huge = math.huge
local abs = math.abs
local function closestCCColor(r, g, b)
    local closest = termColors[1]
    if not r or not g or not b then
        return closest
    end

    local closestDistance = huge

    for _, termColor in pairs(termColors) do
        local distance = abs(r/255 - termColor.r) + abs(g/255 - termColor.g) + abs(b/255 - termColor.b)
        if (distance < closestDistance) then
            closest = termColor
            closestDistance = distance
        end
    end

    return closest
end

local paintutilsImg = ""
for y = 1, bmp.height do
    local row = {}
    for x = 1, bmp.width do
        local r, g, b = bmp:get_pixel(x, y)
        local closest = closestCCColor(r, g, b)
        row[x] = closest.code
    end
    paintutilsImg = paintutilsImg .. table.concat(row) .. "\n"
end

print("Got " .. (#paintutilsImg) .. " px")

local outFile = fs.open(path .. ".nfp", "w")
outFile.write(paintutilsImg)
outFile:close()

print("Saved to " .. path .. ".nfp !")
