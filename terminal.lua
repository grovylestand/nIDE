
local MAX_LINES = 20  
_G.terminal_lines = {}
local last_raw_log = ""


function on.timer()
    local raw_log = var.recall("nidetermlog") or ""
    
    if raw_log ~= last_raw_log then
        last_raw_log = raw_log
        _G.terminal_lines = {}
        
        
        for line in string.gmatch(raw_log, "[^\r\n]+") do
            table.insert(_G.terminal_lines, line)
        end
        
        
        while #_G.terminal_lines > MAX_LINES do
            table.remove(_G.terminal_lines, 1)
        end
        
        platform.window:invalidate()
    end
end
timer.start(0.2)


function on.paint(gc)
    local w = platform.window:width() or 318
    local h = platform.window:height() or 212
    
    
    gc:setColorRGB(240, 240, 240)
    gc:fillRect(0, 0, w, h)
    
    
    gc:setColorRGB(0, 0, 0)
    gc:setFont("sansserif", "r", 8)
    
    local line_height = 10
    local start_y = 5  
    
    for i, line in ipairs(_G.terminal_lines) do
        local draw_y = start_y + ((i - 1) * line_height)
        if draw_y + line_height <= h then
            gc:drawString(line, 6, draw_y, "top")
        end
    end
end


function on.charIn(char)
    if char == "c" then
        var.store("nidetermlog", "")
        _G.terminal_lines = {}
        last_raw_log = ""
        platform.window:invalidate()
    end
end
