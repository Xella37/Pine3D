-- Made by Xella

local floor = math.floor
local min = math.min
local concat = table.concat

local colorChar = {}
for i = 1, 16 do colorChar[2 ^ (i - 1)] = ("0123456789abcdef"):sub(i, i) end

local colorDistances

local function getColorsFromPixelGroup(p1, p2, p3, p4, p5, p6)
	local freq = {}
	freq[p1] = 1
	freq[p2] = (freq[p2] or 0) + 1
	freq[p3] = (freq[p3] or 0) + 1
	freq[p4] = (freq[p4] or 0) + 1
	freq[p5] = (freq[p5] or 0) + 1
	freq[p6] = (freq[p6] or 0) + 1

	local c1 = p1
	local c2 = p1
	local totalColors = 0
	local highestCount = 0
	for color, count in pairs(freq) do
		totalColors = totalColors + 1
		if color ~= c1 then c2 = color end
		if count > highestCount then
			c2 = c1
			c1 = color
			highestCount = count
		end
	end

	if totalColors <= 2 then return c1, c2 end

	local bestC2 = p1
	local lowestError = 99
	local c1Dists = colorDistances[c1]
	for c2, _ in pairs(freq) do
		local c2Dists = colorDistances[c2]
		if c2 ~= c1 then
			local err = min(c1Dists[p1], c2Dists[p1]) + min(c1Dists[p2], c2Dists[p2]) + min(c1Dists[p3], c2Dists[p3])
				+ min(c1Dists[p4], c2Dists[p4]) + min(c1Dists[p5], c2Dists[p5]) + min(c1Dists[p6], c2Dists[p6])
			if err < lowestError then
				lowestError = err
				bestC2 = c2
			end
		end
	end

	return c1, bestC2
end

-- Based on https://bottosson.github.io/posts/oklab/#converting-from-linear-srgb-to-oklab
local function sRGBtoOklab(r, g, b)
	local function f(v) return v >= 0.04045 and ((v + 0.055) / (1 + 0.055)) ^ 2.4 or (v / 12.92) end
	r, g, b = f(r), f(g), f(b)
	local l = (0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b) ^ (1 / 3)
	local m = (0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b) ^ (1 / 3)
	local s = (0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b) ^ (1 / 3)
	return
		0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
		1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
		0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
end

---Compute distances between colors from current palette using a color space
---@param window Redirect
---@param colorSpace "Oklab" | "sRGB" | nil default: Oklab
local function computeColorDistances(window, colorSpace)
	colorDistances = {}
	for c1 = 1, 16 do
		local r1, g1, b1 = window.getPaletteColor(2 ^ (c1 - 1))
		if colorSpace ~= "sRGB" then r1, g1, b1 = sRGBtoOklab(r1, g1, b1) end
		local distances = {}
		for c2 = 1, 16 do
			local r2, g2, b2 = window.getPaletteColor(2 ^ (c2 - 1))
			if colorSpace ~= "sRGB" then r2, g2, b2 = sRGBtoOklab(r2, g2, b2) end
			local d = (r2 - r1) ^ 2 + (g2 - g1) ^ 2 + (b2 - b1) ^ 2
			distances[2 ^ (c2 - 1)] = d
		end
		colorDistances[2 ^ (c1 - 1)] = distances
	end
end

local function colorCloser(target, c1, c2)
	local dists = colorDistances[target]
	return dists[c1] < dists[c2]
end

local char = string.char
local allChars = {}
for i = 128, 128+31 do allChars[i] = char(i) end
local bxor = bit.bxor
local function getCharFomPixelGroup(c1, c2, p1, p2, p3, p4, p5, p6)
	local cc = colorCloser
	local charNr = 128
	if p1 == c1 or p1 ~= c2 and cc(p1, c1, c2) then charNr = charNr + 1 end
	if p2 == c1 or p2 ~= c2 and cc(p2, c1, c2) then charNr = charNr + 2 end
	if p3 == c1 or p3 ~= c2 and cc(p3, c1, c2) then charNr = charNr + 4 end
	if p4 == c1 or p4 ~= c2 and cc(p4, c1, c2) then charNr = charNr + 8 end
	if p5 == c1 or p5 ~= c2 and cc(p5, c1, c2) then charNr = charNr + 16 end
	if p6 == c1 or p6 ~= c2 and cc(p6, c1, c2) then
		return allChars[bxor(31, charNr)], true
	end
	return allChars[charNr], false
end

local function drawBuffer(buffer, win)
	local height = #buffer
	local width = #buffer[1]

	if not colorDistances then computeColorDistances(win) end

	local maxX = floor(width / 2)
	local setCursorPos = win.setCursorPos
	local blit = win.blit
	local colorChar = colorChar
	for y = 1, floor(height / 3) do
		local oy = (y-1) * 3 + 1

		local r1 = buffer[oy] -- first row from buffer for this row of characters
		local r2 = buffer[oy+1] -- second row from buffer for this row of characters
		local r3 = buffer[oy+2] -- third row from buffer for this row of characters

		local blitC1 = {nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil}
		local blitC2 = {nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil}
		local blitChar = {nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil}
		for x = 1, maxX do
			local ox = (x-1) * 2 + 1

			local p1 = r1[ox]
			local p2 = r1[ox+1]
			local p3 = r2[ox]
			local p4 = r2[ox+1]
			local p5 = r3[ox]
			local p6 = r3[ox+1]
			if p1 == p2 and p2 == p3 and p3 == p4 and p4 == p5 and p5 == p6 then
				local c = colorChar[p1]
				blitC1[x] = c
				blitC2[x] = c
				blitChar[x] = "\x80"
			else
				local c1, c2 = getColorsFromPixelGroup(p1, p2, p3, p4, p5, p6)
				local char, swapColors = getCharFomPixelGroup(c1, c2, p1, p2, p3, p4, p5, p6)
				if swapColors then
					local cC2 = colorChar[c2]
					local cC1 = colorChar[c1]
					blitC1[x] = cC2
					blitC2[x] = cC1
				else
					local cC2 = colorChar[c2]
					local cC1 = colorChar[c1]
					blitC1[x] = cC1
					blitC2[x] = cC2
				end
				blitChar[x] = char
			end
		end
		local con = concat
		local c1 = con(blitChar)
		local c2 = con(blitC1)
		local c3 = con(blitC2)
		setCursorPos(1, y)
		blit(c1, c2, c3)
	end
end

return {
	drawBuffer = drawBuffer,
	recomputeColorDistances = computeColorDistances
}
