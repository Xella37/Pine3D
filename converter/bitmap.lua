--[[
This single-file Lua library implements read/write support for the
`Windows Bitmap`/`device-independent bitmap` file format version 3.0.

Compatible with Lua5.1, LuaJIT, Lua5.2, Lua5.3, Lua5.4.

License: MIT (see included file LICENSE)
]]

-- offsets into a Windows Bitmap file header
local bmp_header_offset = 0
local bmp_header_filesize = 2
local bmp_header_pixel_offset = 10
local bmp_header_size = 14
local bmp_header_width = 18
local bmp_header_height = 22
local bmp_header_planes = 26
local bmp_header_bpp = 28
local bmp_header_compression = 30
local bmp_header_image_size = 34

local function get_data_size(width, height, bpp)
	local line_w = math.ceil(width/4)*4
	return height*line_w*(bpp/8)
end

local function new_bitmap()
	-- this table is returned as an interface for a Windows Bitmap to the user:
	local bmp = {}

	-- reading 8/16/32-bit little-endian integer values from a string
	function bmp:read(offset) -- read uint8
		offset = math.floor(assert(tonumber(offset)))
		local value = assert(self.data[offset]):byte()
		return value
	end
	function bmp:read_word(offset) -- read uint16
		return self:read(offset+1)*0x100 + self:read(offset)
	end
	function bmp:read_dword(offset) -- read uint32
		return self:read(offset+3)*0x1000000 + self:read(offset+2)*0x10000 + self:read(offset+1)*0x100 + self:read(offset)
	end
	function bmp:read_long(offset) -- read int32
		local value = self:read_dword(offset)
		if value >= 0x80000000 then -- bitmap format uses two's complement
			value = -(value - 0x80000000)
		end
		return value
	end

	-- writing 8/16/32-bit little-endian integer values from a string
	function bmp:write(offset, data) -- write uint8*
		offset = math.floor(assert(tonumber(offset)))
		for i=1, #data do
			local index = offset+i-1
			local value = data:sub(i,i)
			assert(self.data[index]) -- only update, don't create new entry
			self.data[index] = value
		end
	end
	function bmp:write_word(offset, value) -- write uint16
		local a = math.floor(value % 0x100)
		local b = math.floor(value / 0x100)
		local data = string.char(a,b)
		self:write(offset, data)
	end
	function bmp:write_dword(offset, value) -- write uint32
		local a = math.floor(value) % 0x100
		local b = math.floor(value / 0x100) % 0x100
		local c = math.floor(value / 0x10000) % 0x100
		local d = math.floor(value / 0x1000000) % 0x100
		local data = string.char(a,b,c,d)
		self:write(offset, data)
	end
	function bmp:write_long(offset, value)
		if value < 0 then
			value = -value + 0x80000000
		end
		self:write_dword(offset, value)
	end

	-- read bitmap headers and parse required metadata, update self
	function bmp:read_header()
		-- check the bitmap header
		if not self:read_word(bmp_header_offset) == 0x4D42 then
			return nil, "Bitmap magic header not found"
		end
		local compression = self:read_dword(bmp_header_compression)
		if compression ~= 0 then
			return nil, "Only uncompressed bitmaps supported. Is: "..tostring(compression)
		end

		-- get bits per pixel from the bitmap header
		-- this library only supports 24bpp and 32bpp pixel formats!
		self.bpp = self:read_word(bmp_header_bpp)
		if not ((self.bpp == 24) or (self.bpp == 32)) then
			return nil, "Only 24bpp/32bpp bitmaps supported. Is: "..tostring(self.bpp)
		end

		-- get other required info from the bitmap header
		self.pixel_offset = self:read_dword(bmp_header_pixel_offset)
		self.width = self:read_long(bmp_header_width)
		self.height = self:read_long(bmp_header_height)

		-- calculate expected size of the data region
		self.data_size = get_data_size(self.width, self.height, self.bpp)

		-- if height is <0, the image data is in topdown format
		self.topdown = true
		if self.height < 0 then
			self.topdown = false
			self.height = -self.height
		end

		return true
	end

	-- write bitmap headers from self
	function bmp:write_header(width, height, bpp)
		if (width < 0) or (height < 0) or (width >= 2^31) or (height >= 2^31) then
			return nil, "Invalid dimensions"
		end
		if not ((bpp == 24) or (bpp == 32)) then
			return nil, "Invalid bpp"
		end

		-- update expected data size
		self.data_size = get_data_size(width, height, bpp)

		-- Bitmap header
		self:write_word(bmp_header_offset, 0x4D42)

		self:write_dword(bmp_header_filesize, 54+self.data_size)
		self:write_dword(bmp_header_size, 40)
		self:write_word(bmp_header_planes, 1)

		-- image information
		self:write_dword(bmp_header_compression, 0)
		self:write_word(bmp_header_bpp, bpp)
		self:write_dword(bmp_header_pixel_offset, self.pixel_offset)

		local line_w = math.ceil(width/4)*4
		self:write_long(bmp_header_width, line_w)
		--self:write_long(bmp_header_width, width)
		self:write_dword(bmp_header_image_size, self.data_size)

		if self.topdown then
			self:write_long(bmp_header_height, height)
		else
			self:write_long(bmp_header_height, -height)
		end

		-- set all internal values accordingly
		self:read_header()

		return true
	end

	-- return the r,g,b,a[0-255] color value for a pixel by its x,y coordinates
	function bmp:get_pixel(x,y)
		if (x < 0) or (x >= self.width) or (y < 0) or (y >= self.height) then
			return nil, "Out of bounds"
		end

		-- calculate byte offset in data
		local Bpp = self.bpp/8
		local line_w = math.ceil(self.width/4)*4
		local index = self.pixel_offset + y*line_w*Bpp + x*Bpp
		if self.topdown then
			index = self.pixel_offset + (self.height-y-1)*Bpp*line_w + x*Bpp
		end

		-- read r,g,b color values
		local b = self:read(index)
		local g = self:read(index+1)
		local r = self:read(index+2)


		local a = nil
		if Bpp == 4 then -- on 32bpp, also get 4th channel value(alpha, not in spec)
			a = self:read(index+3)
		end

		return r,g,b,a
	end

	-- set the color value at x,y
	function bmp:set_pixel(x,y, r,g,b,a)
		if (x < 0) or (x >= self.width) or (y < 0) or (y >= self.height) then
			return nil, "out of bounds"
		end
		if (r < 0) or (r > 255) or (g < 0) or (g > 255) or (b < 0) or (b > 255) then
			return nil, "invalid color"
		end
		if a and ((a < 0) or (a > 255)) then
			return nil, "invalid alpha"
		end

		-- calculate byte offset in data
		local Bpp = self.bpp/8
		local line_w = math.ceil(self.width/4)*4
		local index = self.pixel_offset + y*line_w*Bpp + x*Bpp
		if self.topdown then
			index = self.pixel_offset + (self.height-y-1)*Bpp*line_w + x*Bpp
		end

		-- write new pixel value
		if Bpp == 3 then
			self:write(index, string.char(b,g,r))
		else
			self:write(index, string.char(b,g,r,a or 255))
		end

		return true
	end

	-- return the entire bitmap serialized
	function bmp:tostring()
		return self.data[0]..table.concat(self.data)
	end

	return bmp
end

-- Create a new empty bitmap
local function new_empty_bitmap(width, height, alpha)
	local bmp = new_bitmap()
	local bpp = 24
	if alpha then
		bpp = 32
	end

	-- create empty data string
	bmp.data = {}
	for i=1, 54+get_data_size(width, height, bpp) do
		bmp.data[i-1] = "\000"
	end
	bmp.pixel_offset = 54
	bmp.topdown = true

	-- write a new header to the data
	local ok,err = bmp:write_header(width, height, bpp)
	if not ok then
		return nil, err
	end

	return bmp
end

-- Read a bitmap from a string and return it
local function new_bitmap_from_string(data)
	local bmp = new_bitmap()

	-- copy data from string to internal table
	bmp.data = {}
	for i=1, #data do
		bmp.data[i-1] = data:sub(i,i)
	end

	-- read the header from the data
	local ok,err = bmp:read_header()
	if not ok then
		return nil, err
	end

	return bmp
end

-- Read a bitmap from a file and return it
local function new_bitmap_from_file(path)
	-- open a file containing bitmap data
	local file = io.open(path, "rb")
	if not file then
		return nil, "can't open input file for reading: "..tostring(path)
	end

	-- try to read from the file
	local data = file:read("*a")
	if (not data) or (data == "") then
		return nil, "can't read input file: "..tostring(path)
	end

	return new_bitmap_from_string(data)
end


-- this is the module returned to the user when require()'d
local Bitmap = {
	empty_bitmap = new_empty_bitmap,
	from_string = new_bitmap_from_string,
	from_file = new_bitmap_from_file,
	_new_bitmap = new_bitmap
}

return Bitmap
