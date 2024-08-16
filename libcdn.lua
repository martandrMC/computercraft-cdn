local exports = {}

local catalogs = "catalogs/"
local dircache = "dircache/"

----------------------
-- Helper Functions --
----------------------

local function deepCopy(original)
    if type(original) ~= "table" then
        return original
    end
    local copy = {}
    for k,v in pairs(original) do
        copy[k] = deepCopy(v)
    end
    return copy
end

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
    result.local_path = path

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
    if not fs.exists(fname) then return nil, "Catalog not found!" end
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
    local fname = self.work_dir .. dircache .. self.curr_cat.name .. "/"
    if not fs.exists(fname) then fs.makeDir(fname) end
    if self.curr_cat.safe then
        local check = (string.find(code, "[^A-Za-z0-9-_]") == nil)
        if check then fname = fname .. code .. ".sav"
        else return nil, "Unsafe code in reportedly safe catalog!" end
    else fname = fname .. base64Encode(code) .. ".sav" end

    if not fs.exists(fname) then
        local hyperlink = self.curr_cat.host .. code
        local handle, errtxt, failhandle = http.get(hyperlink)
        if not handle then return nil, failhandle.getResponseCode() .. ": " .. errtxt end
        local content = handle.readAll()
        handle.close()

        local handle, errtxt = fs.open(fname, "w")
        if not handle then return nil, errtxt end
        handle.write(content)
        handle.close()
    end

    return fname
end

local function parseDirectory(self, fname)
    local result = {}
    result.entries = {}

    local handle, errtxt = fs.open(fname, "r")
    if not handle then return nil, errtxt end
    while true do
        local line = handle.readLine()
        if not line then break end
        local iter = string.gmatch(line, "%S+")
        local header = iter()
        if header == "$" then
            local type = iter()
            if type == "dir" then
                result.is_root = false
                result.parent = iter()
                if not result.parent then return nil, "Malformed directory header!" end
            elseif type == "cat" then
                result.is_root = true
                if self.curr_cat.name ~= iter() then return nil, "Catalog name mismatch!" end
            else return nil, "Directory type error!" end
        else
            local entry = {}
            local name = iter()
            if not name then return nil, "Malformed directory entry!" end
            entry.type = header
            entry.code = iter()
            if not entry.code then return nil, "Malformed directory entry!" end
            result.entries[name] = entry
        end
    end
    handle.close()

    return result
end

------------------------
-- Exported Functions --
------------------------

function exports.addCatalog(self, name)
    local entry = self.curr_dir.entries[name]
    if not entry then return nil, "Catalog not found!" end
    if entry.type ~= "cat" then return nil, "Not a catalog!" end

    local hyperlink = self.curr_cat.host .. entry.code
    local handle, errtxt, failhandle = http.get(hyperlink)
    if not handle then return nil, failhandle.getResponseCode() .. ": " .. errtxt end
    local content = handle.readAll()
    handle.close()

    local name = string.gsub(content, ".*name (%S+).*", "%1")
    local fname = self.work_dir .. catalogs .. name .. ".cat"
    if fs.exists(fname) then return nil, "Catalog has already been added!" end

    local handle, errtxt = fs.open(fname, "w")
    if not handle then return nil, errtxt end
    handle.write(content)
    handle.close()

    return name
end

function exports.changeCatalog(self, catalog)
    local old_cat = deepCopy(self.curr_cat)
    -- local old_dir = deepCopy(self.curr_dir)
    local old_path = self.curr_path
    local function restore(errtxt)
        -- self.curr_dir = old_dir
        self.curr_cat = old_cat
        self.curr_path = old_path
        return false, errtxt
    end

    local new_cat, errtxt = parseCatalog(self, catalog)
    if not new_cat then return restore(errtxt) end
    self.curr_cat = new_cat
    self.curr_path = "/"

    local fname, errtxt = fetchDirectory(self, self.curr_cat.code)
    if not fname then return restore(errtxt) end

    local new_dir, errtxt = parseDirectory(self, fname)
    if not new_dir then return restore(errtxt) end
    if not new_dir.is_root then return restore("Catalog root not marked as root!") end
    self.curr_dir = new_dir

    return true
end

function exports.changeDirectory(self, path)
    local old_cat = deepCopy(self.curr_cat)
    local old_dir = deepCopy(self.curr_dir)
    -- local old_path = self.curr_path
    local function restore(errtxt)
        self.curr_dir = old_dir
        self.curr_cat = old_cat
        -- self.curr_path = old_path
        return false, errtxt
    end

    local path = parsePath(path)
    if not path then return restore("Malformed path!") end

    if path.catalog ~= nil then
        local succ, errtxt = self:changeCatalog(path.catalog)
        if not succ then return restore(errtxt) end
    elseif not path.relative then
        local succ, errtxt = self:changeCatalog(self.curr_cat.name)
        if not succ then return restore(errtxt) end
    end

    for i,v in ipairs(path.directories) do
        local entry = self.curr_dir.entries[v]
        if not entry then return restore("Directory not found!") end
        if entry.type ~= "dir" then return restore("Not a directory!") end

        local result, errtxt = fetchDirectory(self, entry.code)
        if not result then return restore(errtxt) end
        local result, errtxt = parseDirectory(self, result)
        if not result then return restore(errtxt) end

        self.curr_dir = result
    end

    self.curr_path = path.local_path
    return true
end

--------------------------------------------------

function exports.getSavedCatalogs(self)
    local result = fs.list(self.work_dir .. catalogs)
    for i, v in ipairs(result) do
        local limit = string.len(result[i]) - 4
        result[i] = string.sub(result[i], 0, limit)
    end
    return result
end

function exports.getCatalogs(self)
    local result = {}
    for k,v in pairs(self.curr_dir.entries) do
        if v.type == "cat" then table.insert(result, k) end
    end
    return result
end

function exports.getDirectories(self)
    local result = {}
    for k,v in pairs(self.curr_dir.entries) do
        if v.type == "dir" then table.insert(result, k) end
    end
    return result
end

function exports.getDirectoryEntries(self)
    local result = {}
    for k,v in pairs(self.curr_dir.entries) do
        result[k] = v.type
    end
    return result
end

function exports.getFiles(self, filter)
    local result = {}
    for k,v in pairs(self.curr_dir.entries) do
        if not (v.type == "cat" or v.type == "dir") then
            if not filter or v.type == filter then
                table.insert(result, k)
            end
        end
    end
    return result
end

--------------------------------------------------

function exports.getPath(self)
    return self.curr_cat.name .. "@" .. self.curr_path
end

function exports.getFile(self, name)
    local entry = self.curr_dir.entries[name]
    if not entry then return nil, "File not found!" end
    if entry.type == "cat" or entry.type == "dir" then return nil, "Not a file!" end

    local hyperlink = self.curr_cat.host .. entry.code
    local handle, errtxt, failhandle = http.get(hyperlink)
    if not handle then return nil, failhandle.getResponseCode() .. ": " .. errtxt end
    return handle, entry.type
end

function exports.clearCache(self, catalog)
    if not catalog then
        local list = fs.list(self.work_dir .. dircache)
        for i,v in ipairs(list) do fs.delete(self.work_dir .. dircache .. v) end
    else
        local fname = self.work_dir .. catalogs .. catalog .. ".cat"
        if not fs.exists(fname) then return false, "Catalog doesn't exist!" end
        fs.delete(self.work_dir .. dircache .. catalog)
    end
    return true
end

-- The library, when require()'d, returns a constructor function that mandates
-- correct initialization. To successfully initialize the library, provide it
-- a directory wherein catalogs and cached directories will be located. An
-- initial catalog is required so that the library is always in a valid state.
-- The library will be initialized pointing at the root of the initial catalog.
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
