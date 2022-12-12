
-- Made by Xella#8655

local function randomValue()
	return math.random(0, 1023) / 1023
end

local function getRawLayer(layerWidth, x, y, seed)
	math.randomseed(seed + x * 1000 + y * 1000000)
	local prelayer = {}
	for x = 1, layerWidth + 2 do
		prelayer[x] = {}
		for y = 1, layerWidth + 2 do
			local value = randomValue()
			prelayer[x][y] = value
		end
	end

	return prelayer
end

local function getValueLinear(X1, X2, Y1, Y2, X3)
	local a = (Y2 - Y1) / (X2 - X1)
	local b = Y2 - a * X2

	local Y3 = a * X3 + b

	return Y3
end

local function getValueCosine(X1, X2, Y1, Y2, X3)
	local Y3 = (1-math.cos(math.pi/(X1-X2) * (X3-X1))) / 2 * (Y2-Y1) + Y1

	return Y3
end

local function createNoiseLayer(size, layerWidth, x, y, seed)
	local prelayer = getRawLayer(layerWidth, x, y, seed)

	local prelayerUp = getRawLayer(layerWidth, x, y - 1, seed)
	local prelayerDown = getRawLayer(layerWidth, x, y + 1, seed)
	local prelayerLeft = getRawLayer(layerWidth, x - 1, y, seed)
	local prelayerRight = getRawLayer(layerWidth, x + 1, y, seed)

	for x = 2, layerWidth + 1 do
		prelayer[x][1] = prelayerUp[x][layerWidth + 1]
	end
	for x = 2, layerWidth + 1 do
		prelayer[x][layerWidth + 2] = prelayerDown[x][2]
	end
	for y = 2, layerWidth + 1 do
		prelayer[1][y] = prelayerLeft[layerWidth + 1][y]
	end
	for y = 2, layerWidth + 1 do
		prelayer[layerWidth + 2][y] = prelayerRight[2][y]
	end

	local layer = {}
	for x = 2, layerWidth + 1 do
		for y = 2, layerWidth + 1 do
			local value = prelayer[x][y]
			local valueUp = prelayer[x][y - 1]
			local valueDown = prelayer[x][y + 1]
			local valueLeft = prelayer[x - 1][y]
			local valueRight = prelayer[x + 1][y]

			for x2 = (x - 1 - 1) * size / layerWidth + 1, (x - 1) * size / layerWidth do
				if (layer[x2] == nil) then
					layer[x2] = {}
				end
				for y2 = (y - 1 - 1) * size / layerWidth + 1, (y - 1) * size / layerWidth do
					local localX = x2 - (x - 1 - 1) * size / layerWidth
					local localY = y2 - (y - 1 - 1) * size / layerWidth

					if localX == size / layerWidth / 2 and localY == size / layerWidth / 2 then
						layer[x2][y2] = value
					elseif localX - localY > 0 then -- upper right
						if size / layerWidth - localX - localY > 0 then -- upper left
							local X1 = -size / layerWidth / 2
							local X2 = size / layerWidth / 2
							local Y1 = valueUp
							local Y2 = value
							local X3 = localY

							local newValue = getValueCosine(X1, X2, Y1, Y2, X3)
							layer[x2][y2] = newValue -- up
						else -- bottom right
							local X1 = size / layerWidth / 2
							local X2 = size / layerWidth / 2 * 3
							local Y1 = value
							local Y2 = valueRight
							local X3 = localX

							local newValue = getValueCosine(X1, X2, Y1, Y2, X3)
							layer[x2][y2] = newValue -- right
						end
					else -- bottom left
						if (size / layerWidth - localX - localY > 0) then -- upper left
							local X1 = -size / layerWidth / 2
							local X2 = size / layerWidth / 2
							local Y1 = valueLeft
							local Y2 = value
							local X3 = localX

							local newValue = getValueCosine(X1, X2, Y1, Y2, X3)
							layer[x2][y2] = newValue -- left
						else -- bottom right
							local X1 = size / layerWidth / 2
							local X2 = size / layerWidth / 2 * 3
							local Y1 = value
							local Y2 = valueDown
							local X3 = localY

							local newValue = getValueCosine(X1, X2, Y1, Y2, X3)
							layer[x2][y2] = newValue -- bottom
						end
					end
				end
			end
		end
	end
	return layer
end

local function compressNoiseLayers(noiseLayers)
	local noise = {}
	noiseSize = #noiseLayers[1]

	for layerNr, layer in pairs(noiseLayers) do
		for x = 1, noiseSize do
			if not noise[x] then
				noise[x] = {}
			end
			for y = 1, noiseSize do
				if layerNr == 1 then
					noise[x][y] = layer[x][y]
				else
					noise[x][y] = (noise[x][y] * (layerNr - 1) + layer[x][y]) / layerNr
				end
			end
		end
	end

	return noise
end

function createNoise(size, x, y, seed, smoothness)
	local smoothness = smoothness or 1
	if not size then
		error("createNoise arg#1: integer expected, got nil")
	elseif type(size) ~= "number" then
		error("createNoise arg#1: integer expected, got "..type(size))
	else
		if (size / (2 ^ smoothness)) / 2 % 1 ~= 0 then
			error("createNoise arg#1 and/or arg#5: the size must be at least 2 and divisible by 2^(smoothness+1)")
		end
	end
	if not x then
		error("createNoiseLayers arg#2 integer expected, got nil")
	elseif type(x) ~= "number" then
		error("createNoiseLayers arg#2: integer expected, got "..type(x))
	end
	if not y then
		error("createNoiseLayers arg#3: integer expected, got nil")
	elseif type(y) ~= "number" then
		error("createNoiseLayers arg#3: integer expected, got "..type(y))
	end
	if not seed then
		error("createNoiseLayers arg#4: integer expected, got nil")
	elseif type(seed) ~= "number" then
		error("createNoiseLayers arg#4: integer expected, got "..type(seed))
	end

	local noiseLayers = {}

	local layerWidth = 2
	while layerWidth <= size / (2 ^ smoothness) do
		local layer = createNoiseLayer(size, layerWidth, x, y, seed)
		noiseLayers[#noiseLayers+1] = layer
		layerWidth = layerWidth * 2
	end

	local compressedNoise = compressNoiseLayers(noiseLayers)

	return compressedNoise
end

return {
	createNoise = createNoise,
}
