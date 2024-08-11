local exports = {}

local catalogs = "catalogs/"
local dircache = "dircache/"

function exports.listCatalogs(self)
    return fs.list(self.work_dir .. catalogs)
end

function exports.openCatalog(self, catalog)
    local exists = fs.exists(self.work_dir .. catalogs .. catalog .. ".cat")
    if not exists then return false end
    if self.curr_cat ~= nil then self:closeCatalog() end
    self.curr_cat = catalog
    return true
end

function exports.closeCatalog(self)
    self.curr_cat = nil
end

-- The library, when require()'d, returns
-- a constructor function that mandates
-- correct initialization
return function (work_dir)
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
    new.curr_cat = nil
    return new
end
