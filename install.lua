-- This file will be downloaded by the bootstrap installer bootstrap.lua
-- which is available for download directly from pastebin. Pastebin was
-- chosen due to its presence in all ComputerCraft computers.

local tasks = {
	{
		type = "download",
		file = "/source/libcdn.lua",
		location = "/cccdn/libcdn/init.lua"
	}, {
		type = "download",
		file = "/source/main.cat.ref",
		location = "/cccdn/libcdn/catalogs/main.cat"
	}, {
		type = "download",
		file = "/source/libqoa.lua",
		location = "/cccdn/libqoa.lua"
	}, {
		type = "download",
		file = "/source/main.lua",
		location = "/cccdn/main.lua"
	}, {
		type = "execute",
		description = "Add Alias To Startup",
		code = [[ addAlias("cdn", "/cccdn/main.lua") ]]
	}, {
		type = "execute",
		description = "Finalize Aliases",
		code = [[ finalizeAliases() ]]
	}
}

local env = {}
function env.addAlias(name, target)
	if settings.get("cccdn.installed_aliases") then return end
	local file = fs.open("/startup.lua", "a")
	local chunk = string.format("shell.setAlias(\"%s\", \"%s\")", name, target)
	file.writeLine(chunk)
	file.close()
end

function env.finalizeAliases()
	settings.set("cccdn.installed_aliases", true)
	settings.save()
end

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
	local chunk, errtxt = load(code, description, "t", env)
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
