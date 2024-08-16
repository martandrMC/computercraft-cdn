local lib, errtxt = require("libcdn")("/libcdn/", "main")
if not lib then printError(errtxt) return end
local screen = term.current()

local base_color = colors.blue
local type_colors = {
    ["cat"] = colors.blue,
    ["dir"] = colors.lightBlue,
    ["pwm"] = colors.lime,
    ["lua"] = colors.yellow
}

local function printDirectory()
    local width, height = screen.getSize()
    local path = lib:getPath()
    local start = #path - width + 1
    if start > 0 then  path = string.sub(path, start, #path) end

    screen.setCursorPos(1, 1)
    screen.blit(path,
        string.rep(colors.toBlit(base_color), #path),
        string.rep(colors.toBlit(colors.black), #path)
    )

    local line = 2
    local dir = lib:getDirectoryEntries()
    for n,t in pairs(dir) do
        n = string.sub(n, 0, width - 2)
        screen.setCursorPos(1, line)
        screen.blit("| ",
            string.rep(colors.toBlit(base_color), 2),
            string.rep(colors.toBlit(colors.black), 2)
        )
        screen.blit(n,
            string.rep(colors.toBlit(type_colors[t] or colors.white), #n),
            string.rep(colors.toBlit(colors.black), #n)
        )
        line = line + 1
    end
    screen.setCursorPos(1, height)
end

while true do
    screen.clear()
    printDirectory()
    screen.write("> ")
    read()
end
