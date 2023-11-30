
-- Made by Xella (not all of it)
-- Lookup table and "magicLookup" function by HaruCoded <3
-- Works like magic :3

local floor = math.floor
local concat = table.concat

local colorChar = {}
for i = 1, 16 do
	colorChar[2 ^ (i - 1)] = ("0123456789abcdef"):sub(i, i)
end

local teletext_lookup_c1 = {}
local teletext_lookup_c2 = {}
local teletext_lookup_c3 = {}
for i=0,46656 do
	local p1, p2, p3, p4, p5, p6 =
		5 - math.floor(i / (6 ^ 0)) % 6,
		5 - math.floor(i / (6 ^ 1)) % 6,
		5 - math.floor(i / (6 ^ 2)) % 6,
		5 - math.floor(i / (6 ^ 3)) % 6,
		5 - math.floor(i / (6 ^ 4)) % 6,
		5 - math.floor(i / (6 ^ 5)) % 6

	local lookup = {}
	lookup[p6] = 5
	lookup[p5] = 4
	lookup[p4] = 3
	lookup[p3] = 2
	lookup[p2] = 1
	lookup[p1] = 0

	local id =
		lookup[p2] +
		lookup[p3] * 3 +
		lookup[p4] * 4 +
		lookup[p5] * 20 +
		lookup[p6] * 100

	if teletext_lookup_c1[id] == nil then
		-- Calculate the colors
		local freq = {}
		freq[p1] = 1
		freq[p2] = (freq[p2] or 0) + 1
		freq[p3] = (freq[p3] or 0) + 1
		freq[p4] = (freq[p4] or 0) + 1
		freq[p5] = (freq[p5] or 0) + 1
		freq[p6] = (freq[p6] or 0) + 1

		-- Calculate the most frequent color
		local A, A_C = p1, 0
		local B, B_C = p1, 0
		for color, count in pairs(freq) do
			if count > B_C then
				if count > A_C then
					B = A
					B_C = A_C
					A = color
					A_C = count
				else
					B = color
					B_C = count
				end
			end
		end

		local mask = 0
		if p1 == A then mask = mask +  1 end
		if p2 == A then mask = mask +  2 end
		if p3 == A then mask = mask +  4 end
		if p4 == A then mask = mask +  8 end
		if p5 == A then mask = mask + 16 end
		if p6 == A then mask = mask + 32 end

		A = lookup[A] + 1
		B = lookup[B] + 1

		local mask_f = bit32.bxor(mask, 63)
		if mask > mask_f then
			teletext_lookup_c1[id] = B
			teletext_lookup_c2[id] = A
			teletext_lookup_c3[id] = string.char(128 + mask_f)
		else
			teletext_lookup_c1[id] = A
			teletext_lookup_c2[id] = B
			teletext_lookup_c3[id] = string.char(128 + mask)
		end
	end
end

local lookup = {}
local teletext_part = { 0, 0, 0, 0, 0, 0 }
local function magicLookup(p1, p2, p3, p4, p5, p6)
	teletext_part[1] = p1
	teletext_part[2] = p2
	teletext_part[3] = p3
	teletext_part[4] = p4
	teletext_part[5] = p5
	teletext_part[6] = p6

	lookup[p6] = 5
	lookup[p5] = 4
	lookup[p4] = 3
	lookup[p3] = 2
	lookup[p2] = 1
	lookup[p1] = 0

	local id =
		lookup[p2] +
		lookup[p3] * 3 +
		lookup[p4] * 4 +
		lookup[p5] * 20 +
		lookup[p6] * 100

	lookup[p1] = nil
	lookup[p2] = nil
	lookup[p3] = nil
	lookup[p4] = nil
	lookup[p5] = nil
	lookup[p6] = nil

	local fg = teletext_lookup_c1[id]
	local bg = teletext_lookup_c2[id]
	local cc = teletext_lookup_c3[id]
	return teletext_part[fg], teletext_part[bg], cc
end

local function drawBuffer(buffer, win)
	local height = #buffer
	local width = #buffer[1]

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
				local c1, c2, char = magicLookup(p1, p2, p3, p4, p5, p6)
				local cC2 = colorChar[c2]
				local cC1 = colorChar[c1]
				blitC1[x] = cC1
				blitC2[x] = cC2
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
}
