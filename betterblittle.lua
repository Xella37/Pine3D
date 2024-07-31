-- Made by Xella
local floor = math.floor
local min = math.min
local concat = table.concat

local colorMap = {}
for i = 1, 16 do colorMap[2 ^ (i - 1)] = i end

local colorChar = {}
for i = 1, 16 do colorChar[i] = ("0123456789abcdef"):sub(i, i) end

local colorDistances

local function getColorsFromPixelGroup(p1, p2, p3, p4, p5, p6)
	local freq = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
	freq[p1] = 1
	freq[p2] = freq[p2] + 1
	freq[p3] = freq[p3] + 1
	freq[p4] = freq[p4] + 1
	freq[p5] = freq[p5] + 1
	freq[p6] = freq[p6] + 1

	local c1 = p1
	local c2 = p1
	local totalColors = 0
	local highestCount = 0
	for color = 1, 16 do
		local count = freq[color]
		if count > 0 then
			totalColors = totalColors + 1
			if color ~= c1 then c2 = color end
			if count > highestCount then
				c2 = c1
				c1 = color
				highestCount = count
			end
		end
	end

	if totalColors <= 2 then return c1, c2 end

	local bestC2 = p1
	local lowestError = 99
	local c1Dists = colorDistances[c1]
	for c2 = 1, 16 do
		if c2 ~= c1 and freq[c2] > 0 then
			local c2Dists = colorDistances[c2]
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
			distances[c2] = (r2 - r1) ^ 2 + (g2 - g1) ^ 2 + (b2 - b1) ^ 2
		end
		colorDistances[c1] = distances
	end
end

local char = string.char
local allChars = {}
for i = 1, 32 do allChars[i] = char(i + 127) end
local function getCharFomPixelGroup(p1, p2, p3, p4, p5, p6)
	local c1, c2 = getColorsFromPixelGroup(p1, p2, p3, p4, p5, p6)
	local c1Dist = colorDistances[c1]
	local c2Dist = colorDistances[c2]
	if c1Dist[p6] < c2Dist[p6] then
		local charNr = (c1Dist[p1] < c2Dist[p1] and 31 or 32)
			- (c1Dist[p2] < c2Dist[p2] and 2 or 0)
			- (c1Dist[p3] < c2Dist[p3] and 4 or 0)
			- (c1Dist[p4] < c2Dist[p4] and 8 or 0)
			- (c1Dist[p5] < c2Dist[p5] and 16 or 0)
		return allChars[charNr], c2, c1
	else
		local charNr = (c1Dist[p1] < c2Dist[p1] and 2 or 1)
			+ (c1Dist[p2] < c2Dist[p2] and 2 or 0)
			+ (c1Dist[p3] < c2Dist[p3] and 4 or 0)
			+ (c1Dist[p4] < c2Dist[p4] and 8 or 0)
			+ (c1Dist[p5] < c2Dist[p5] and 16 or 0)
		return allChars[charNr], c1, c2
	end
end

---Draw a color buffer to the window
---@param buffer integer[][] 2D array of colors to display
---@param window Redirect
---@param wx integer? x position on monitor (in terminal character pixels)
---@param wy integer? y position on monitor (in terminal character pixels)
local function drawBuffer(buffer, window, wx, wy)
	wx = wx or 1
	wy = wy or 1

	local height = #buffer
	local width = #buffer[1]

	if not colorDistances then computeColorDistances(window) end

	local maxX = floor(width / 2)
	local setCursorPos = window.setCursorPos
	local blit = window.blit
	local colorChar = colorChar
	for y = 0, floor(height / 3) - 1 do
		local oy = y * 3 + 1

		local r1 = buffer[oy] -- first row from buffer for this row of characters
		local r2 = buffer[oy + 1] -- second row from buffer for this row of characters
		local r3 = buffer[oy + 2] -- third row from buffer for this row of characters

		local blitC1 = {nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil}
		local blitC2 = {nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil}
		local blitChar = {nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil}
		for x = 1, maxX do
			local ox = (x - 1) * 2 + 1

			local p1 = colorMap[r1[ox]]
			local p2 = colorMap[r1[ox + 1]]
			local p3 = colorMap[r2[ox]]
			local p4 = colorMap[r2[ox + 1]]
			local p5 = colorMap[r3[ox]]
			local p6 = colorMap[r3[ox + 1]]
			if p1 == p2 and p2 == p3 and p3 == p4 and p4 == p5 and p5 == p6 then
				local c = colorChar[p1]
				blitC1[x] = c
				blitC2[x] = c
				blitChar[x] = "\x80"
			else
				local char, c1, c2 = getCharFomPixelGroup(p1, p2, p3, p4, p5, p6)
				blitC1[x] = colorChar[c1]
				blitC2[x] = colorChar[c2]
				blitChar[x] = char
			end
		end
		local con = concat
		local c1 = con(blitChar)
		local c2 = con(blitC1)
		local c3 = con(blitC2)
		setCursorPos(wx, wy + y)
		blit(c1, c2, c3)
	end
end

return {
	drawBuffer = drawBuffer,
	recomputeColorDistances = computeColorDistances
}
