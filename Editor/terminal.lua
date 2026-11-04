local MAX_LINES = 100
_G.terminal_lines = {}
local last_raw_log = ""

local scroll_row = 1
local scroll_col = 0
local LINE_HEIGHT = 10
local CHAR_WIDTH = 5
local X_MARGIN = 6

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

        local h = platform.window:height() or 212
        local visible_lines = math.floor((h - 10) / LINE_HEIGHT)
        if #_G.terminal_lines > visible_lines then
            scroll_row = #_G.terminal_lines - visible_lines + 1
        else
            scroll_row = 1
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

    local start_y = 5
    local visible_lines = math.floor((h - start_y) / LINE_HEIGHT)

    for i = 0, visible_lines - 1 do
        local line_index = scroll_row + i
        local line = _G.terminal_lines[line_index]

        if line then
            local draw_y = start_y + (i * LINE_HEIGHT)
            gc:drawString(line, X_MARGIN - scroll_col, draw_y, "top")
        end
    end
end

function on.arrowKey(arrow)
    local h = platform.window:height() or 212
    local visible_lines = math.floor((h - 5) / LINE_HEIGHT)
    local redraw = false

    if arrow == "up" then
        if scroll_row > 1 then
            scroll_row = scroll_row - 1
            redraw = true
        end
    elseif arrow == "down" then
        if scroll_row + visible_lines <= #_G.terminal_lines then
            scroll_row = scroll_row + 1
            redraw = true
        end
    elseif arrow == "left" then
        if scroll_col > 0 then
            scroll_col = math.max(0, scroll_col - (CHAR_WIDTH * 3))
            redraw = true
        end
    elseif arrow == "right" then
        scroll_col = scroll_col + (CHAR_WIDTH * 3)
        redraw = true
    end

    if redraw then
        platform.window:invalidate()
    end
end

function on.charIn(char)
    if char == "c" then
        var.store("nidetermlog", "")
        _G.terminal_lines = {}
        last_raw_log = ""
        scroll_row = 1
        scroll_col = 0
        platform.window:invalidate()
    end
end
