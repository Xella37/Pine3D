
local path = "/objModels"

local termColors = {}
for i = 1, 16 do
	local color = 2 ^ (i - 1)
	local r, g, b = term.getPaletteColor(color)
	local char = ("0123456789abcdef"):sub(i, i)
	termColors[#termColors+1] = {r=r, g=g, b=b, code=char, color=color}
end

local abs = math.abs
local function closestCCColor(r, g, b)
	local closest = termColors[1]
	if not r or not g or not b then
		return closest
	end

	local closestDistance = math.huge

	for i, termColor in pairs(termColors) do
		local distance = abs(r - termColor.r) + abs(g - termColor.g) + abs(b - termColor.b)
		if (distance < closestDistance) then
			local color = 2 ^ (i - 1)
			closest = color
			closestDistance = distance
		end
	end

	return closest
end

local shrink = 1
local function loadTexture(filename)
	print("Loading texture " .. filename)

	local textureFile = fs.open(path .. "/" .. filename, "r")
	local raw = textureFile:readAll()
	textureFile:close()

	local texture = {}
	local lineNr = 0
	for line in raw:gmatch("[^\n]+") do
		if lineNr % shrink == 0 then
			local row = {}
			local columnNr = 0
			for char in line:gmatch(".") do
				if columnNr % shrink == 0 then
					row[#row+1] = char
				end
				columnNr = columnNr + 1
			end
			texture[#texture+1] = row
		end
		lineNr = lineNr + 1
	end

	print("Finished loading texture (" .. #texture[1] .. " x " .. #texture .. " px)")

	return texture
end

function loadMTLFile(dir, filename)
	local mtlFile = fs.open(path .. "/" .. dir .. "/" .. filename, "r")
	local raw = mtlFile:readAll()
	mtlFile:close()

	local materialList = {}
	local materialMap = {}

	local material = {}
	for line in raw:gmatch("[^\n]+") do
		local parts = {}
		for part in line:gmatch("[^%s]+") do
			parts[#parts+1] = part
		end

		if parts[1] == "newmtl" then
			material = {}

			materialList[#materialList+1] = material
			materialMap[parts[2]] = material
		elseif parts[1] == "map_Kd" then
			local filename = parts[2]:sub(1, parts[2]:find("%.")-1) .. ".nfp"
			material.texture = loadTexture(dir .. "/" .. filename)
		elseif parts[1] == "Kd" then
			local r = tonumber(parts[2])
			local g = tonumber(parts[3])
			local b = tonumber(parts[4])

			local function adjusted(c)
				local srgb = 0
				if c < 0.0031308 then
					if c < 0.0 then
					 	srgb = 0.0
					else
						srgb = c * 12.92
					end
				else
					srgb = 1.055 * math.pow(c, 1.0 / 2.4) - 0.055
				end

				return math.max(math.min(math.floor(srgb * 255 + 0.5), 255), 0)
			end

			r = adjusted(r)/255
			g = adjusted(g)/255
			b = adjusted(b)/255

			local color = closestCCColor(r, g, b)
			material.baseColor = color
		elseif not parts[1]:sub(1, 1) == "#" then
			if #parts == 2 then
				material[parts[1]] = parts[2]
			elseif #parts == 3 then
				material[parts[1]] = {parts[2], parts[3]}
			elseif #parts == 4 then
				material[parts[1]] = {parts[2], parts[3], parts[4]}
			end
		end
	end

	return {
		list = materialList,
		map = materialMap,
	}
end

function loadObjFile(id)
	local path = path .. "/" .. id .. "/" .. id .. ".obj"
	print("Opening " .. path)
	local ShrekFile = fs.open(path, "r")

	if not ShrekFile then
		error("Failed to load obj file from path " .. path)
	end

	local raw = ShrekFile:readAll()
	ShrekFile:close()

	local colorChar = {}
	for i = 1, 16 do
		local color = 2 ^ (i - 1)
		local char = ("0123456789abcdef"):sub(i, i)
		colorChar[char] = color
	end

	local materialsWarned = {}
	local quadsWarned = false

	local vertices = {}
	local vts = {}
	local material = "default"
	local materials = {}

	local convertedModel = {}

	for line in raw:gmatch("[^\n]+") do
		local parts = {}
		for part in line:gmatch("[^%s]+") do
			parts[#parts+1] = part
		end

		if parts[1] == "v" then
			vertices[#vertices+1] = {
				tonumber(parts[2]),
				tonumber(parts[3]),
				tonumber(parts[4]),
			}
		elseif parts[1] == "vt" then
			vts[#vts+1] = {
				tonumber(parts[2]),
				tonumber(parts[3]),
				tonumber(parts[4]),
			}
		elseif parts[1] == "mtllib" then
			materials = loadMTLFile(id, parts[2])
		elseif parts[1] == "usemtl" then
			material = parts[2]
		elseif parts[1] == "f" then
			local faceVertices = {}
			local faceVTs = {}
			for _, part in pairs({parts[2], parts[3], parts[4], parts[5]}) do
				local parts2 = {}
				for part2 in part:gmatch("-?%d+") do
					parts2[#parts2+1] = part2
				end

				local vIndex = tonumber(parts2[1])
				if vIndex > 0 then
					faceVertices[#faceVertices+1] = vertices[vIndex]
				else
					faceVertices[#faceVertices+1] = vertices[#vertices + vIndex + 1]
				end

				local vtIndex = tonumber(parts2[2])
				if vtIndex > 0 then
					faceVTs[#faceVTs+1] = vts[vtIndex]
				else
					faceVTs[#faceVTs+1] = vts[#vts + vtIndex + 1]
				end
			end

			local v1 = faceVertices[1]
			local v2 = faceVertices[2]
			local v3 = faceVertices[3]
			local v4 = faceVertices[4]

			local x1 = v1[1]
			local y1 = v1[2]
			local z1 = v1[3]
			local x2 = v2[1]
			local y2 = v2[2]
			local z2 = v2[3]
			local x3 = v3[1]
			local y3 = v3[2]
			local z3 = v3[3]
			local x4, y4, z4 = nil, nil, nil
			if v4 then
				x4, y4, z4 = v4[1], v4[2], v4[3]
			end

			local poly = {
				x1 = x1,
				y1 = y1,
				z1 = z1,
				x2 = x2,
				y2 = y2,
				z2 = z2,
				x3 = x3,
				y3 = y3,
				z3 = z3,
			}

			if material:sub(-3) == "[F]" then
				poly.forceRender = true
			end

			do
				local v1 = faceVTs[1]
				local v2 = faceVTs[2]
				local v3 = faceVTs[3]

				local avgVTX = (v1[1] + v2[1] + v3[1]) / 3
				local avgVTY = (v1[2] + v2[2] + v3[2]) / 3

				local mat = materials.map[material]
				local texture = mat.texture
				if texture then
					local width = #texture[1]
					local height = #texture
					local textureX = (math.floor(avgVTX * width) % width) + 1
					local textureY = (math.floor(avgVTY * height) % height) + 1
					local color = texture[height - textureY + 1][textureX]
					poly.c = colorChar[color] or colors.red
				else
					if mat.baseColor then
						poly.c = mat.baseColor
					else
						if not materialsWarned[material] then
							term.setTextColor(colors.orange)
							print("Warning: no texture found for material \"" .. material .. "\"")
							term.setTextColor(colors.white)
							materialsWarned[material] = true
						end
						poly.c = colors.red
					end
				end
			end

			convertedModel[#convertedModel+1] = poly

			if v4 then
				if not quadsWarned then
					term.setTextColor(colors.orange)
					print("Warning: model contains quads which will be converted to two triangles each, making this model less efficient!")
					term.setTextColor(colors.white)
					quadsWarned = true
				end

				local poly2 = {
					x1 = x4,
					y1 = y4,
					z1 = z4,
					x3 = x3,
					y3 = y3,
					z3 = z3,
					x2 = x1,
					y2 = y1,
					z2 = z1,
					c = poly.c,
				}

				local v1 = faceVTs[1]
				local v4 = faceVTs[4]
				local v3 = faceVTs[3]

				local avgVTX = (v1[1] + v4[1] + v3[1]) / 3
				local avgVTY = (v1[2] + v4[2] + v3[2]) / 3

				local mat = materials.map[material]
				local texture = mat.texture
				if texture then
					local width = #texture[1]
					local height = #texture
					local textureX = (math.floor(avgVTX * width) % width) + 1
					local textureY = (math.floor(avgVTY * height) % height) + 1
					local color = texture[height - textureY + 1][textureX]
					poly.c = colorChar[color] or colors.red
				else
					if mat.baseColor then
						poly.c = mat.baseColor
					else
						if not materialsWarned[material] then
							term.setTextColor(colors.orange)
							print("Warning: no texture found for material \"" .. material .. "\"")
							term.setTextColor(colors.white)
							materialsWarned[material] = true
						end
						poly.c = colors.red
					end
				end

				convertedModel[#convertedModel+1] = poly2
			end

			if #convertedModel % 10000 == 0 then
				print("Processed " .. (#convertedModel) .. " polygons...")
			end
		end
	end

	print("Finished loading the .obj model!")

	return convertedModel
end

return {
	load = loadObjFile,
}
