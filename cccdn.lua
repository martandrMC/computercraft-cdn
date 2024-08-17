local lib, errtxt = require("libcdn")("/libcdn/", "main")
if not lib then printError(errtxt) return end
local screen = term.current()
local width, height = screen.getSize()

local base_color = colors.blue
local type_colors = {
    ["cat"] = colors.blue,
    ["dir"] = colors.lightBlue,
    ["pwm"] = colors.lime,
    ["lua"] = colors.yellow
}

local function printDirectory()
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
    
    local names = {}
    for n,t in pairs(dir) do table.insert(names, n) end
    table.sort(names)

    for i,n in ipairs(names) do
        local t = dir[n]
        n = string.sub(n, 1, width - 2)
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
    screen.setCursorPos(1, height - 1)
end

local history = {}
while true do
    for i = 1, height - 1 do
        screen.setCursorPos(1, i)
        screen.clearLine()
    end

    printDirectory()
    screen.write("> ")
    local command = read(nil, history)
    if string.sub(command, 1, 1) ~= "`" then
        local succ, errtxt = lib:changeDirectory(command)
        if succ then
            screen.clearLine()
            if history[#history] ~= command then
                table.insert(history, command)
            end
        else screen.blit(errtxt,
            string.rep(colors.toBlit(colors.red), #errtxt),
            string.rep(colors.toBlit(colors.black), #errtxt)
        ) end
    elseif command == "`exit" then
        screen.clearLine()
        break
    end
end
