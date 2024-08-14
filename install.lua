-- This file will be downloaded by the bootstrap installer bootstrap.lua
-- which is available for download directly from pastebin. Pastebin was
-- chosen due to its presence in all ComputerCraft computers.

local tasks = {
    { type = "download", file = "/libcdn.lua", location = "/libcdn.lua"},
    {
        type = "execute", description = "Initialise LibCDN folder structure",
        code = "loadfile(\"/libcdn.lua\")()(\"/libcdn\", \"\")"
    },
    { type = "download", file = "/cccdn.lua", location = "/cccdn.lua"},
    { type = "download", file = "/main.cat.ref", location = "/libcdn/catalogs/main.cat"}
}

local function taskDownload(file, location)
    local link_prefix = "https://raw.githubusercontent.com/martandrMC/computercraft-cdn/master"
    write(string.format("Performing download task: %s -> %s ... ", file, location))
    local handle, errtxt, failhandle = http.get(link_prefix .. file)
    if not handle then printError("Fail!") return false end
    local content = handle.readAll()
    handle.close()

    local handle, errtxt = fs.open(location, "w")
    if not handle then printError("Fail!") return false end
    handle.write(content)
    handle.close()
    
    print("Success!")
    return true
end

local function taskExecute(description, code)
    write(string.format("Performing execute task \"%s\" ... ", description))
    local chunk, errtxt = loadstring(code)
    if not code then printError("Fail!") return false end
    chunk()
    print("Success!")
    return true
end

print("-- CC CDN Installer Start --")
for i,v in ipairs(tasks) do
    write(string.format("[%d/%d] ", i, #tasks))
    if v.type == "download" then taskDownload(v.file, v.location)
    elseif v.type == "execute" then taskExecute(v.description, v.code)
    else printError("Fail!") end
end
print("-- CC CDN Installer Finish --")
