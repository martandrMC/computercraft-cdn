local vfs, errtxt = require("libcdn")("/libcdn/", "main")
if not vfs then printError(errtxt) return end

local screen = term.current()
local width, height = screen.getSize()

local running = true
local playing = false

local base_color = colors.blue
local type_colors = {
    ["cat"] = colors.blue,
    ["dir"] = colors.lightBlue,
    ["pwm"] = colors.lime,
    ["qoa"] = colors.lime,
    ["lua"] = colors.yellow
}

--------------------------------------------------

local function writeStatus(str, err)
    local old_x, old_y = screen.getCursorPos()
    screen.setCursorPos(1, height)
    screen.clearLine()

    local text_color = colors.white
    if err then text_color = colors.red end
    screen.blit(str,
        string.rep(colors.toBlit(text_color), #str),
        string.rep(colors.toBlit(colors.black), #str)
    )

    screen.setCursorPos(old_x, old_y)
end

local function printDirectory()
    local path = vfs:getPath()
    local start = #path - width + 1
    if start > 0 then  path = string.sub(path, start, #path) end

    screen.setCursorPos(1, 1)
    screen.blit(path,
        string.rep(colors.toBlit(base_color), #path),
        string.rep(colors.toBlit(colors.black), #path)
    )

    local line = 2
    local dir = vfs:getEntries()

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

local function getSpeaker()
    local speakers = { peripheral.find("speaker") }
    if #speakers == 0 then return nil end
    return speakers[1]
end

--------------------------------------------------

local commands = {}

function commands.exit(iter)
    writeStatus("", false)
    running = false
end

function commands.add(iter)
    local fname = iter()
    local ftype = vfs:getEntryType(fname)
    if not ftype then writeStatus("Catalog not found!", true)
    elseif ftype ~= "cat" then writeStatus("Not a catalog!", true)
    else
        local cname, errtxt = vfs:addCatalog(fname)
        if cname ~= nil then
            writeStatus(string.format("Added \"%s\" to the local catalogs.", cname), false)
        else writeStatus(errtxt, true) save = false end
    end
end

function commands.play(iter)
    if playing then writeStatus("Player is already active!", true)
    else os.queueEvent("cccdn_start", iter()) end
end

function commands.stop(iter)
    if not playing then writeStatus("Player is already stopped!", true)
    else os.queueEvent("cccdn_stop") end
end

--------------------------------------------------

local function promptOptions(input)
    local choice = require("cc.completion").choice
    local function keyset(tbl)
        local keys = {}
        for k,v in pairs(tbl) do
            table.insert(keys, k)
        end
        table.sort(keys)
        return keys
    end

    if not input or #input == 0 then return {} end

    local last_part = {}
    for p in string.gmatch(input, "%S+") do last_part = p end

    if string.sub(last_part, 1, 1) == "`" then
        local command_names = keyset(commands)
        return choice(string.sub(last_part, 2, -1), command_names)
    else
        local entry_names = keyset(vfs:getEntries())
        if not vfs:isRoot() then table.insert(entry_names, "..") end
        return choice(last_part, entry_names)
    end

    return {}
end

--------------------------------------------------

local function handleUI()
    local history = {}
    while running do
        for i = 1, height - 1 do
            screen.setCursorPos(1, i)
            screen.clearLine()
        end

        printDirectory()
        screen.write("> ")
        local command = read(nil, history, promptOptions)
        local iter = string.gmatch(command, "%S+")
        local first_part = iter()

        if string.sub(command, 1, 1) ~= "`" then
            local succ, errtxt = vfs:changeDirectory(command)
            if succ then writeStatus("", false)
            else writeStatus(errtxt, true) save = false end
        else
            local cmd_func = commands[string.sub(first_part, 2, -1)]
            if not cmd_func then writeStatus("Unknown command!", true)
            else cmd_func(iter) end
        end

        if history[#history] ~= command then
            table.insert(history, command)
        end
    end
end

local function handleMusic()
    local decoders = {}

    decoders["pwm"] = function(handle)
        local pwm = require("cc.audio.dfpwm").make_decoder()
        return function()
            local bytes = handle.read(16384)
            if bytes == nil then return nil end
            return pwm(bytes)
        end
    end

    decoders["qoa"] = function(handle)
        return require("libqoa").makeDecoder(handle)
    end

    while true do while true do
        playing = false
        local _, fname = os.pullEvent("cccdn_start")
        playing = true

        local ftype = vfs:getEntryType(fname)
        if not ftype then writeStatus("File not found!", true) break end

        local decoder = decoders[ftype]
        if not decoder then writeStatus("Not a sound file!", true) break end

        local handle, ftype = vfs:getFile(fname)
        if not handle then writeStatus(ftype, true) break end

        local speaker = getSpeaker()
        if not speaker then writeStatus("No speaker attached!", true) break
        else writeStatus(string.format("Playing \"%s\" ...", fname), false) end

        local callback = decoder(handle)
        while playing do
            local data = callback()
            while not speaker.playAudio(data, 3) do
                while true do
                    local event_data = {os.pullEvent()}
                    local event = event_data[1]
                    if event == "speaker_audio_empty" then break
                    elseif event == "cccdn_stop" then playing = false break end
                end
            end
        end

        writeStatus("Finished playing.", false)
        handle.close()
        speaker.stop()
    end end
end

parallel.waitForAny(handleUI, handleMusic)
