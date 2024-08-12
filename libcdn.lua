local exports = {}

local catalogs = "catalogs/"
local dircache = "dircache/"

----------------------
-- Helper Functions --
----------------------

local function base64Encode(str)
    local charset = {
        "A", "B", "C", "D", "E", "F", "G", "H",
        "I", "J", "K", "L", "M", "N", "O", "P",
        "Q", "R", "S", "T", "U", "V", "W", "X",
        "Y", "Z", "a", "b", "c", "d", "e", "f",
        "g", "h", "i", "j", "k", "l", "m", "n",
        "o", "p", "q", "r", "s", "t", "u", "v",
        "w", "x", "y", "z", "0", "1", "2", "3",
        "4", "5", "6", "7", "8", "9", "-", "_"
    }
    local idx, state, buffer = 1, 1, 0
    local result = ""
    while true do
        local byte = string.byte(str, idx)
        if not byte then break end
        local digit = bit.bor(bit.blogic_rshift(byte, 2 * state), buffer)
        buffer = bit.blshift(bit.band(byte, 4 ^ state - 1), 6 - 2 * state)
        result = result .. charset[digit + 1]
        if state == 3 then result, buffer = result .. charset[buffer + 1], 0 end
        idx, state = idx + 1, state + 1
        if state == 4 then state = 1 end
    end
    if state == 2 then result = result .. charset[buffer + 1] .. "=="
    elseif state == 3 then result = result .. charset[buffer + 1] .. "=" end
    return result
end

local function parsePath(path)
    local result = {}
    local loc = string.find(path, "@")
    if loc ~= nil then
        if loc < 2 then return nil end
        result.catalog = string.sub(path, 1, loc - 1)
        result.relative = false
        path = string.sub(path, loc + 1)
        if string.find(path, "@") ~= nil then return nil end
    else result.relative = (string.sub(path, 1, 1) ~= "/") end

    result.directories = {}
    if string.find(path, "/") ~= nill then
        local iter = string.gmatch(path, "[^/]+")
        while true do
            local part = iter()
            if not part then break end
            table.insert(result.directories, part)
        end
    elseif string.len(path) == 0 then return nil
    else table.insert(result.directories, path) end
    return result
end

local function parseCatalog(self, catalog)
    local fname = self.work_dir .. catalogs .. catalog .. ".cat"
    if not fs.exists(fname) then return nil, "Catalog doesn't exist!" end
    local result = {}

    local handle = fs.open(fname, "r")
    assert(handle ~= nil)
    while true do
        local line = handle.readLine()
        if not line then break end
        local iter = string.gmatch(line, "%S+")
        local key, value = iter(), iter()
        if iter() ~= nil then
            handle.close()
            return nil, "Malformed catalog descriptor!"
        end
        result[key] = value
    end
    handle.close()

    local checks = true
    checks = checks and (result.name ~= nil)
    checks = checks and (result.host ~= nil)
    checks = checks and (result.code ~= nil)
    if not checks then return nil, "Required category descriptor component missing!" end
    if not result.safe then result.safe = false
    elseif result.safe == "false" then result.safe = false
    elseif result.safe == "true" then result.safe = true
    else return nil, "Malformed catalog descriptor component!" end
    assert(result.name == catalog)

    return result
end

local function fetchDirectory(self, code)
    -- TODO
end

local function parseDirectory(self, fname)
    -- TODO
    return {}
end

------------------------
-- Exported Functions --
------------------------

function exports.listCatalogs(self)
    local result = fs.list(self.work_dir .. catalogs)
    for i, v in ipairs(result) do
        local limit = string.len(result[i]) - 4
        result[i] = string.sub(result[i], 0, limit)
    end
    return result
end

function exports.changeCatalog(self, catalog)
    local result, errtxt = parseCatalog(self, catalog)
    if not result then return false, errtxt end
    self.curr_cat = result
    self.curr_path = "/"
    local fname = fetchDirectory(self, self.curr_cat.code)
    self.curr_dir = parseDirectory(fname)
    return true
end

function exports.changeDirectory(self, path)
    local parts = parsePath(path)
    if not parts then return false, "Malformed path!" end

    -- TODO
    return true
end

-- The library, when require()'d, returns
-- a constructor function that mandates
-- correct initialization
return function (work_dir, initial_catalog)
    local new = {}
    for k,v in pairs(exports) do new[k] = v end

    local last_char = string.sub(work_dir, string.len(work_dir))
    if last_char ~= "/" then work_dir = work_dir .. "/" end

    if not fs.exists(work_dir) then
        fs.makeDir(work_dir)
        fs.makeDir(work_dir .. catalogs)
        fs.makeDir(work_dir .. dircache)
    end

    new.work_dir = work_dir
    local succ, errtxt = new:changeCatalog(initial_catalog)
    if not succ then return nil, errtxt end

    return new
end
