function errmsg(msg)
    printError("Bootstrap failure!")
    printError(msg)
    error()
end

local link = "https://raw.githubusercontent.com/martandrMC/computercraft-cdn/master/install.lua"

print("Downloading install script from github...")
local handle, errtxt, failhandle = http.get(link)
if not handle then errmsg(failhandle.getResponseCode() .. ": " .. errtxt) end
local content = handle.readAll()
handle.close()

print("Executing install script...")
local code, errtxt = loadstring(content)
if not code then errmsg(errtxt) end
code()
