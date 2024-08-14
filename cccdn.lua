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

local function getSpeaker()
    local speakers = { peripheral.find("speaker") }
    if #speakers == 0 then return nil end
    return speakers[1]
end

local function playAudio(handle)
    local speaker = getSpeaker()
    local decoder = require("cc.audio.dfpwm").make_decoder()
    while true do
        local bytes = handle.read(16384)
        if bytes == nil then break end
        
        local data = decoder(bytes)
        while not speaker.playAudio(data) do
            os.pullEvent("speaker_audio_empty")
        end
    end
    handle.close()
    speaker.stop()
end

local lib, errtxt = require("libcdn")("/libcdn/", "main")
if not lib then printError(errtxt) return end

lib:addCatalog("mart-music")
lib:changeDirectory("mart@/")
parallel.waitForAny(
    function () playAudio(lib:getFile("uranium-fever")) end,
    function () while true do print("Playing") os.sleep(1) end end
)
