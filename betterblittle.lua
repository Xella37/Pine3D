
-- Made by Xella

local floor = math.floor
local concat = table.concat

local colorChar = {}
for i = 1, 16 do colorChar[2 ^ (i - 1)] = ("0123456789abcdef"):sub(i, i) end

local function getColorsFromPixelGroup(p1, p2, p3, p4, p5, p6)
	local freq = {}
	freq[p1] = 1
	freq[p2] = (freq[p2] or 0) + 1
	freq[p3] = (freq[p3] or 0) + 1
	freq[p4] = (freq[p4] or 0) + 1
	freq[p5] = (freq[p5] or 0) + 1
	freq[p6] = (freq[p6] or 0) + 1

	local highest = p1
	local highestCount = 0
	local secondHighest = p1
	local secondHighestCount = 0
	for color, count in pairs(freq) do
		if count > secondHighestCount then
			if count > highestCount then
				secondHighest = highest
				secondHighestCount = highestCount
				highest = color
				highestCount = count
			else
				secondHighest = color
				secondHighestCount = count
			end
		end
	end

	return highest, secondHighest
end

local relations
local function computeClosestColors(win)
	relations = {}
	for c1 = 1, 16 do
		local r1, g1, b1 = win.getPaletteColor(2 ^ (c1 - 1))
		local closestColors = {}
		local distances = {}
		for c2 = 1, 16 do
			local r2, g2, b2 = win.getPaletteColor(2 ^ (c2 - 1))
			local d = (r2 - r1) ^ 2 + (g2 - g1) ^ 2 + (b2 - b1) ^ 2
			local i = 1
			while distances[i] and distances[i] < d do i = i + 1 end
			table.insert(closestColors, i, 2 ^ (c2 - 1))
			table.insert(distances, i, d)
		end
		relations[2 ^ (c1 - 1)] = closestColors
	end
end

local function colorCloser(target, c1, c2)
	local r = relations[target]
	for i = 1, #r do
		if r[i] == c1 then return true
		elseif r[i] == c2 then return false end
	end

	return false
end

local char = string.char
local allChars = {}
for i = 128, 128+31 do
	allChars[i] = char(i)
end
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

	if not relations then computeClosestColors(win) end

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
	recomputeClosestColors = computeClosestColors
}
