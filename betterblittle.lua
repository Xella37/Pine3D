
-- Made by Xella#8655

local floor = math.floor
local concat = table.concat

local colorChar = {}
for i = 1, 16 do
	colorChar[2 ^ (i - 1)] = ("0123456789abcdef"):sub(i, i)
end

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

local relationsBlittle = {[0] = {8, 4, 3, 6, 5}, {4, 14, 8, 7}, {6, 10, 8, 7}, {9, 11, 8, 0}, {1, 14, 8, 0}, {13, 12, 8, 0}, {2, 10, 8, 0}, {15, 8, 10, 11, 12, 14},
		{0, 7, 1, 9, 2, 13}, {3, 11, 8, 7}, {2, 6, 7, 15}, {9, 3, 7, 15}, {13, 5, 7, 15}, {5, 12, 8, 7}, {1, 4, 7, 15}, {7, 10, 11, 12, 14}}
local relations = {}
for i = 0, 15 do
	local r = relationsBlittle[i]
	for i = 1, #r do
		r[i] = math.pow(2, r[i])
	end
	relations[math.pow(2, i)] = r
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

local lookup = {}
for i = 1, 16 do
	lookup[2 ^ (i - 1)] = {}
end
local function drawBuffer(buffer, win)
	local height = #buffer
	local width = #buffer[1]

	local maxX = floor(width / 2)
	local setCursorPos = win.setCursorPos
	local blit = win.blit
	local colorChar = colorChar
	local lookup = lookup
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
				local sum = p2 .. p3 .. p4 .. p5 .. p6
				local look = lookup[p1][sum]
				if look then
					blitC1[x] = look[1]
					blitC2[x] = look[2]
		            blitChar[x] = look[3]
				else
		            local c1, c2 = getColorsFromPixelGroup(p1, p2, p3, p4, p5, p6)
		            local char, swapColors = getCharFomPixelGroup(c1, c2, p1, p2, p3, p4, p5, p6)
		            if swapColors then
						local cC2 = colorChar[c2]
						local cC1 = colorChar[c1]
		                blitC1[x] = cC2
		                blitC2[x] = cC1
						if lookup[p1] then
							lookup[p1][sum] = {
								cC2,
								cC1,
								char,
							}
						else
							lookup[p1] = {
								[sum] = {
									cC2,
									cC1,
									char,
								}
							}
						end
		            else
						local cC2 = colorChar[c2]
						local cC1 = colorChar[c1]
		                blitC1[x] = cC1
		                blitC2[x] = cC2
						if lookup[p1] then
							lookup[p1][sum] = {
								cC1,
								cC2,
								char,
							}
						else
							lookup[p1] = {
								[sum] = {
									cC1,
									cC2,
									char,
								}
							}
						end
		            end
		            blitChar[x] = char
				end
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
}
