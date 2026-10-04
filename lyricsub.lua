-- LyricSub
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation.

local current_target_item = nil
local last_fetched_item = nil
local log_file_path = ""

function descriptor()
    return {
        title = "LyricSub",
        version = "1.1.0",
        author = "AkshuAgrwl",
        url = 'https://github.com/AkshuAgrwl/LyricSub',
        description = "A VLC Media Player extension that automatically fetches and injects synchronized lyrics via LRCLIB as subtitles.",
        shortdesc = "LyricSub",
        capabilities = { "input-listener", "meta-listener", "playing-listener" }
    }
end

function init_logger()
    local config_dir = ""
    if vlc.config and vlc.config.configdir then
        local s, dir = pcall(vlc.config.configdir)
        if s and dir then config_dir = dir end
    end
    
    local platform = get_platform()
    
    if config_dir == "" then
        if platform == "windows" then
            config_dir = os.getenv("APPDATA") .. "\\vlc"
        else
            config_dir = os.getenv("HOME") .. "/.config/vlc"
        end
    end
    
    if platform == "windows" then
        log_file_path = config_dir .. "\\lyricsub_debug.log"
    else
        log_file_path = config_dir .. "/lyricsub_debug.log"
    end
    
    local f = io.open(log_file_path, "w")
    if f then
        local time_str = os.date("%Y-%m-%d %H:%M:%S")
        f:write(string.format("[%s] [INFO] === LyricSub Activated ===\n", time_str))
        f:write(string.format("[%s] [INFO] Platform: %s | Version: %s\n", time_str, platform, descriptor().version))
        f:write(string.format("[%s] [INFO] Log location: %s\n", time_str, log_file_path))
        f:close()
    end
end

function log_msg(level, message)
    if not log_file_path or log_file_path == "" then return end
    local f = io.open(log_file_path, "a")
    if f then
        local time_str = os.date("%Y-%m-%d %H:%M:%S")
        f:write(string.format("[%s] [%s] %s\n", time_str, tostring(level), tostring(message)))
        f:close()
    end
end

function get_item_id(item)
    if not item then return "" end
    local s, uri = pcall(function() return item:uri() end)
    if s and uri then return uri end
    return tostring(item)
end

function activate()
    init_logger()
    if vlc.input then
        local s, i = pcall(function() return vlc.input.item() end)
        if s and i then current_target_item = get_item_id(i) end
    end
    update_lyrics()
    return true
end

function close() deactivate() end

function deactivate()
    log_msg("INFO", "=== LyricSub Deactivated ===")
    vlc.deactivate()
    return true
end

function seconds_to_srt_time(seconds)
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = math.floor(seconds % 60)
    local ms = math.floor((seconds - math.floor(seconds)) * 1000)
    return string.format("%02d:%02d:%02d,%03d", h, m, s, ms)
end

function inject_subtitles(plain_lyrics, synced_lyrics, is_not_found)
    local item = nil
    if vlc.input then 
        local s, i = pcall(function() return vlc.input.item() end)
        if s then item = i end
    end
    if not item and vlc.item then item = vlc.item end
    if not item then return end
    
    local duration = 240
    local s_dur, d = pcall(function() return item:duration() end)
    if s_dur and type(d) == "number" and d > 0 then
        duration = d
    end
    
    local srt_content = ""

    if is_not_found then
        srt_content = "1\r\n"
        srt_content = srt_content .. seconds_to_srt_time(2) .. " --> " .. seconds_to_srt_time(8) .. "\r\n"
        srt_content = srt_content .. "Lyrics not found\r\n\r\n"
    else
        if not plain_lyrics or plain_lyrics == "" then return end
        
        if synced_lyrics and synced_lyrics ~= "" then
            local lines = {}
            for line in string.gmatch(synced_lyrics, "(.-)\n") do
                line = string.gsub(line, "\r", "")
                local m, sec, text = string.match(line, "%[(%d+)%:(%d+%.%d+)%]%s*(.*)")
                if m and sec then
                    local time_in_sec = tonumber(m) * 60 + tonumber(sec)
                    table.insert(lines, {time = time_in_sec, text = trim(text)})
                end
            end
            
            if #lines > 0 then
                for i, l in ipairs(lines) do
                    local start_time = l.time
                    local end_time = (i < #lines) and lines[i+1].time or (start_time + 10)
                    if end_time - start_time > 15 then end_time = start_time + 15 end
                    
                    if l.text ~= "" then
                        srt_content = srt_content .. tostring(i) .. "\r\n"
                        srt_content = srt_content .. seconds_to_srt_time(start_time) .. " --> " .. seconds_to_srt_time(end_time) .. "\r\n"
                        srt_content = srt_content .. l.text .. "\r\n\r\n"
                    end
                end
            end
        end

        if srt_content == "" then
            local clean_text = string.gsub(plain_lyrics, "<br%s*/?>", "\r\n")
            srt_content = "1\r\n"
            srt_content = srt_content .. seconds_to_srt_time(0) .. " --> " .. seconds_to_srt_time(duration) .. "\r\n"
            srt_content = srt_content .. trim(clean_text) .. "\r\n\r\n"
        end
    end

    math.randomseed(os.time())
    local rnd = math.random(10000, 99999)
    local platform = get_platform()
    local path = (platform == "unix") and ("/tmp/lyricsub_" .. rnd .. ".srt") or ((os.getenv("TEMP") or os.getenv("TMP") or "C:\\Temp") .. "\\lyricsub_" .. rnd .. ".srt")
    
    local f = io.open(path, "wb")
    if f then
        f:write("\239\187\191") 
        f:write(srt_content)
        f:close()
        
        if vlc.input and vlc.input.add_subtitle then
            pcall(function() vlc.input.add_subtitle(path, true) end)
        end
    end
end

function url_encode(str)
    if not str then return "" end
    str = string.gsub(str, "\n", "\r\n")
    str = string.gsub(str, "([^%w %-%_%.%~])", function(c)
        return string.format("%%%02X", string.byte(c))
    end)
    return string.gsub(str, " ", "%%20")
end

function fetch_lrclib(title_x, artist_x)
    local status, plain, synced = pcall(function()
        local url = "https://lrclib.net/api/get?track_name=" .. url_encode(title_x) .. "&artist_name=" .. url_encode(artist_x)
        local s = vlc.stream(url)
        if not s then return nil, nil end
        
        local data = ""
        while true do
            local chunk = s:read(65535)
            if not chunk or chunk == "" then break end
            data = data .. chunk
        end
        
        if data == "" or data:find("404 Not Found") then return nil, nil end
        
        data = string.gsub(data, '\\"', "'") 
        local syn = string.match(data, '"syncedLyrics"%s*:%s*"(.-)"')
        local pln = string.match(data, '"plainLyrics"%s*:%s*"(.-)"')
        
        if syn == "null" or syn == "" then syn = nil end
        if pln == "null" or pln == "" then pln = nil end
        
        if syn then 
            syn = string.gsub(syn, "\\r", "")
            syn = string.gsub(syn, "\\n", "\n") 
        end
        if pln then 
            pln = string.gsub(pln, "\\r", "")
            pln = string.gsub(pln, "\\n", "\n") 
        end
        
        return pln, syn
    end)
    
    if not status then return nil, nil end
    return plain, synced
end

function input_changed()
    collectgarbage()
    if vlc.input then
        local s, i = pcall(function() return vlc.input.item() end)
        if s and i then current_target_item = get_item_id(i) end
    end
    update_lyrics()
    collectgarbage()
    return true
end

function playing_changed() end
function meta_changed() end

function update_lyrics()
    local songtitle = get_title()
    local songartist = get_artist()
    
    if not songtitle or songtitle == "" or not songartist or songartist == "" then
        return false
    end
    
    local plain_lrc, synced_lrc = fetch_lrclib(songtitle, songartist)
    if plain_lrc and plain_lrc ~= "" then
        local formatted_plain = string.gsub(plain_lrc, "\n", "<br>")
        inject_subtitles(formatted_plain, synced_lrc, false)
    else
        inject_subtitles(nil, nil, true)
    end
    
    return true
end

function get_title()
    local item = vlc.item or vlc.input.item()
    if item then
        local metas = item:metas()
        if metas["title"] and metas["title"] ~= "" then return metas["title"] end
        local name = item:name()
        if name then
            local filename = string.gsub(name, "^(.+)%.%w+$", "%1")
            local pos = filename:find("-")
            if pos then
                return trim(filename:sub(pos + 1))
            end
            return filename
        end
    end
    return ""
end

function get_artist()
    local item = vlc.item or vlc.input.item()
    if item then
        local metas = item:metas()
        if metas["artist"] and metas["artist"] ~= "" then return metas["artist"] end
        local name = item:name()
        if name then
            local filename = string.gsub(name, "^(.+)%.%w+$", "%1")
            local pos = filename:find("-")
            if pos then
                return trim(filename:sub(1, pos - 1))
            end
        end
    end
    return ""
end

function trim(str)
    if not str then return "" end
    return (string.gsub(str, "^%s*(.-)%s*$", "%1"))
end

function is_window_path(path)
    return string.match(path, "^(%a:\\).+$")
end

function get_platform()
    if is_window_path(vlc.config.datadir()) then return "windows" else return "unix" end
end