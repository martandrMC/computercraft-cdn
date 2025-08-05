local exports = {}

local dequant_lut = {
	{   1,    -1,    3,    -3,    5,    -5,     7,     -7},
	{   5,    -5,   18,   -18,   32,   -32,    49,    -49},
	{  16,   -16,   53,   -53,   95,   -95,   147,   -147},
	{  34,   -34,  113,  -113,  203,  -203,   315,   -315},
	{  63,   -63,  210,  -210,  378,  -378,   588,   -588},
	{ 104,  -104,  345,  -345,  621,  -621,   966,   -966},
	{ 158,  -158,  528,  -528,  950,  -950,  1477,  -1477},
	{ 228,  -228,  760,  -760, 1368, -1368,  2128,  -2128},
	{ 316,  -316, 1053, -1053, 1895, -1895,  2947,  -2947},
	{ 422,  -422, 1405, -1405, 2529, -2529,  3934,  -3934},
	{ 548,  -548, 1828, -1828, 3290, -3290,  5117,  -5117},
	{ 696,  -696, 2320, -2320, 4176, -4176,  6496,  -6496},
	{ 868,  -868, 2893, -2893, 5207, -5207,  8099,  -8099},
	{1064, -1064, 3548, -3548, 6386, -6386,  9933,  -9933},
	{1286, -1286, 4288, -4288, 7718, -7718, 12005, -12005},
	{1536, -1536, 5120, -5120, 9216, -9216, 14336, -14336},
}

----------------------
-- Helper Functions --
----------------------

-- QOA does numbers in big endian
local function readUnsigned(handle, count)
	local number = 0
	local data = handle.read(count)
	for i = 1, count do
		local byte = string.byte(data, i)
		number = bit.blshift(number, 8) + byte
	end
	return number
end

-- QOA does numbers in big endian
local function readSigned(handle, count)
	local number = 0
	local data = handle.read(count)
	local negative = string.byte(data) > 127
	for i = 1, count do
		local byte = string.byte(data, i)
		number = bit.blshift(number, 8) + byte
	end
	if not negative then return number
	else return number - bit.blshift(1, count * 8) end
end

-- Each slice is 4 bits `sf_quant` then 20 * 3 bits `qr`, 64 bits total
local function readSlice(handle)
	-- Since we don't have 64 bit integers, split into 3 parts
	-- The first part has the `sf_quant` then 4 `qr`s (4 + 4 * 3 = 16)
	-- The other two parts have 8 `qr`s (8 * 3 = 24)
	local part1 = readUnsigned(handle, 2)
	local part2 = readUnsigned(handle, 3)
	local part3 = readUnsigned(handle, 3)

	-- Convenience function that takes `size` bits at offset `offset`
	-- and brings them down to the least significant positions
	local function extract(number, size, offset)
		local mask = bit.blshift(1, size) - 1
		return bit.band(bit.brshift(number, offset), mask)
	end

	local residuals = {}
	local scale_factor = extract(part1, 4, 12) + 1
	for i = 1, 4 do residuals[i +  0] = extract(part1, 3, 12 - 3 * i) + 1 end
	for i = 1, 8 do residuals[i +  4] = extract(part2, 3, 24 - 3 * i) + 1 end
	for i = 1, 8 do residuals[i + 12] = extract(part3, 3, 24 - 3 * i) + 1 end
	for i = 1, 20 do residuals[i] = dequant_lut[scale_factor][residuals[i]] end

	return residuals
end

local function decodeFrame(handle)
	-- Only mono QOA files since the speaker is mono
	local channel_count = readUnsigned(handle, 1)
	if channel_count ~= 1 then return nil end

	-- Only 48kHz sample rate since the speaker only supports that
	local sample_rate = readUnsigned(handle, 3)
	if sample_rate ~= 48000 then return nil end

	-- Per the spec, all but the last frame have 256 slices
	local sample_count = readUnsigned(handle, 2)
	local slice_count = math.ceil(sample_count / 20)
	if slice_count > 256 then return nil end

	-- Only using this for verifying the integrity of the frame
	local byte_count = readUnsigned(handle, 2)
	local my_byte_count = 8 + (2 * 8 + 8 * slice_count) * channel_count
	if byte_count ~= my_byte_count then return nil end

	-- Assemble the predictor state and pull the residuals
	local history, weights, residuals, samples = {}, {}, {}, {}
	for i = 1, 4 do history[i] = readSigned(handle, 2) end
	for i = 1, 4 do weights[i] = readSigned(handle, 2) end
	for i = 1, slice_count do
		local slice = readSlice(handle)
		for _,r in ipairs(slice) do table.insert(residuals, r) end
	end

	-- Decoding algo straight from the spec
	for _,residual in ipairs(residuals) do
		-- Predicted sample is the dot product of the history and weights
		local prediction = 0
		for i = 1, 4 do prediction = prediction + history[i] * weights[i] end
		prediction = math.floor(prediction / 8192)

		-- The actual sample is our prediction plus the residual, clamped
		local sample = prediction + residual
		if sample < -32768 then sample = -32768 end
		if sample >  32767 then sample =  32767 end
		table.insert(samples, sample)

		-- Adjust the weights based on the residual
		local delta = math.floor(residual / 16)
		for i = 1, 4 do
			if history[i] < 0 then weights[i] = weights[i] - delta
			else weights[i] = weights[i] + delta end
		end

		-- Shift the history one sample over
		for i = 1, 3 do history[i] = history[i + 1] end
		history[4] = sample
	end

	return samples
end

------------------------
-- Exported Functions --
------------------------

function exports.makeDecoder(handle)
	local magic = handle.read(4)
	if magic ~= "qoaf" then return nil end

	local total_sample_count = readUnsigned(handle, 4)
	local frame_count = math.ceil(total_sample_count / 256 / 20)

	return function()
		if frame_count == 0 then return nil end
		
		local samples = decodeFrame(handle)
		if not samples then return nil end

		for i = 1, #samples do
			samples[i] = math.floor(samples[i] / 256)
		end

		frame_count = frame_count - 1
		return samples
	end
end

return exports
