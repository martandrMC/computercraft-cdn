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
    local path = lib:getPath()
    local start = #path - width + 1
    if start > 0 then  path = string.sub(path, start, #path) end

    screen.setCursorPos(1, 1)
    screen.blit(path,
        string.rep(colors.toBlit(base_color), #path),
        string.rep(colors.toBlit(colors.black), #path)
    )

    local line = 2
    local dir = lib:getEntries()

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

local playing = false

local function handleUI()
    local history = {}
    while true do
        for i = 1, height - 1 do
            screen.setCursorPos(1, i)
            screen.clearLine()
        end

        printDirectory()
        screen.write("> ")
        local command = read(nil, history)
        local iter = string.gmatch(command, "%S+")
        local first_part = iter()
        local save = true

        if string.sub(command, 1, 1) ~= "`" then
            local succ, errtxt = lib:changeDirectory(command)
            if succ then writeStatus("", false)
            else writeStatus(errtxt, true) save = false end
        elseif first_part == "`add" then
            local fname = iter()
            local ftype = lib:getEntryType(fname)
            if not ftype then writeStatus("Catalog not found!", true)
            elseif ftype ~= "cat" then writeStatus("Not a catalog!", true)
            else
                local cname, errtxt = lib:addCatalog(fname)
                if cname ~= nil then
                    writeStatus(string.format("Added \"%s\" to the local catalogs.", cname), false)
                else writeStatus(errtxt, true) save = false end
            end
        elseif first_part == "`exit" then
            writeStatus("", false)
            break
        elseif first_part == "`play" then
            if playing then writeStatus("Player is already active!", true)
            else os.queueEvent("cccdn_start", iter()) end
        elseif first_part == "`stop" then
            if not playing then writeStatus("Player is already stopped!", true)
            else os.queueEvent("cccdn_stop") end
        else writeStatus("Unknown command!", true) save = false end
        if save and history[#history] ~= command then
            table.insert(history, command)
        end
    end
end

local function handleMusic()
    while true do while true do
        playing = false
        local _, fname = os.pullEvent("cccdn_start")
        playing = true
        local ftype = lib:getEntryType(fname)
        if not ftype then writeStatus("File not found!", true) break
        elseif ftype ~= "pwm" then writeStatus("Not a sound file!", true) break end
        local handle, ftype = lib:getFile(fname)
        assert(handle ~= nil and ftype == "pwm")

        local speaker = getSpeaker()
        if not speaker then writeStatus("No speaker attached!", true) break
        else writeStatus(string.format("Playing \"%s\" ...", fname), false) end
        local decoder = require("cc.audio.dfpwm").make_decoder()
        while playing do
            local bytes = handle.read(16384)
            if bytes == nil then break end
            
            local data = decoder(bytes)
            while not speaker.playAudio(data) do
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
