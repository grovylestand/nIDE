local selStartLine, selStartChar = nil, nil
local selEndLine, selEndChar = nil, nil
local isSelecting = false
local SCREEN_WIDTH = 318
local SCREEN_HEIGHT = 212
local TAB_BAR_HEIGHT = 24
local LINE_HEIGHT = 14
local MARGIN_LEFT = 10
local MARGIN_TOP = TAB_BAR_HEIGHT + 6
local VISIBLE_LINES = math.floor((SCREEN_HEIGHT - MARGIN_TOP) / LINE_HEIGHT)
local SCROLLBAR_WIDTH = 6
local _isTextSelected = false
local _selAnchorCol = 0
local _selStartCol = 0
local _selEndCol = 0

local _isTextSelected, _selAnchorCol, _selStartCol, _selEndCol = false, 0, 0, 0

toolpalette.enableCopy(true)
toolpalette.enablePaste(true)
local localClipboard = ""
local function has(tbl, val)
    for _, v in ipairs(tbl) do
        if v == val then return true end
    end
    return false
end
consoleBuffer = {}
maxLines = 10

local editor = {
    tabs = {
        { name = "Script1.lua", lines = {""}, row = 1, col = 0, scrollRow = 1 },
        { name = "Script2.lua", lines = {""}, row = 1, col = 0, scrollRow = 1 }
    },
    activeTab = 1,
    tabCounter = 2, 
    cursorVisible = true,
    font = {family = "sansserif", style = "r", size = 9},
    pendingClick = nil,
    shouldWrap = false
}

local function current()
    return editor.tabs[editor.activeTab]
end
function on.paint(gc)
    gc:setFont(editor.font.family, editor.font.style, editor.font.size)
    local doc = current()

    
    
    
    if editor.pendingClick then
        local px, py = editor.pendingClick.x, editor.pendingClick.y
        editor.pendingClick = nil
        
        
        if py <= TAB_BAR_HEIGHT then
            local availableWidth = SCREEN_WIDTH - 30 
            local tabWidth = math.floor(availableWidth / #editor.tabs)
            
            
            if px >= availableWidth then
                editor.tabCounter = editor.tabCounter + 1
                table.insert(editor.tabs, {
                    name = "Untitled" .. editor.tabCounter .. "",
                    lines = {""},
                    row = 1,
                    col = 17,
                    scrollRow = 1
                })
                editor.activeTab = #editor.tabs 
            else
                
                local chosenTab = math.floor(px / tabWidth) + 1
                if chosenTab >= 1 and chosenTab <= #editor.tabs then
                    local tabX = (chosenTab - 1) * tabWidth
                    
                    
                    if px >= (tabX + tabWidth - 16) and #editor.tabs > 1 then
                        table.remove(editor.tabs, chosenTab)
                        
                        if editor.activeTab > #editor.tabs then
                            editor.activeTab = #editor.tabs
                        elseif editor.activeTab == chosenTab and editor.activeTab > 1 then
                            editor.activeTab = editor.activeTab - 1
                        end
                    else
                        
                        editor.activeTab = chosenTab
                    end
                end
            end
            doc = current() 
        else
            
            local clickedVisualRow = math.floor((py - MARGIN_TOP) / LINE_HEIGHT)
            local targetRow = current().scrollRow + clickedVisualRow
            if targetRow < 1 then targetRow = 1 end
            if targetRow > #current().lines then targetRow = #current().lines end
            current().row = targetRow
            
            local lineText = current().lines[current().row] or ""
            local bestCol = 0
            local minDiff = math.huge
            for i = 0, string.len(lineText) do
                local testWidth = MARGIN_LEFT + gc:getStringWidth(string.sub(lineText, 1, i))
                local diff = math.abs(px - testWidth)
                if diff < minDiff then minDiff = diff; bestCol = i end
            end
            current().col = bestCol
        end
    end

    
    if editor.shouldWrap then
        editor.shouldWrap = false
        local currentText = current().lines[current().row] or ""
        local maxWidth = SCREEN_WIDTH - (MARGIN_LEFT * 2) - SCROLLBAR_WIDTH
        if gc:getStringWidth(currentText) > maxWidth then
            local left = string.sub(currentText, 1, current().col)
            local right = string.sub(currentText, current().col + 1)
            current().lines[current().row] = left
            table.insert(current().lines, current().row + 1, right)
            current().row = current().row + 1
            current().col = 0
        end
    end

    
    
    
    
    gc:setColorRGB(240, 240, 240)
    gc:fillRect(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)

    
    local availableWidth = SCREEN_WIDTH - 30
    local tabWidth = math.floor(availableWidth / #editor.tabs)
    
    for tIdx, tabItem in ipairs(editor.tabs) do
        local tx = (tIdx - 1) * tabWidth
        
        
        if tIdx == editor.activeTab then
            gc:setColorRGB(255, 255, 255)
            gc:fillRect(tx, 0, tabWidth, TAB_BAR_HEIGHT)
            gc:setColorRGB(0, 0, 0)
        else
            gc:setColorRGB(205, 205, 205)
            gc:fillRect(tx, 0, tabWidth, TAB_BAR_HEIGHT)
            gc:setColorRGB(110, 110, 110)
        end
        gc:drawRect(tx, 0, tabWidth, TAB_BAR_HEIGHT)
        
        
        local displayName = tabItem.name
        if gc:getStringWidth(displayName) > (tabWidth - 22) then
            displayName = string.sub(displayName, 1, 5) .. "..."
        end
        gc:drawString(displayName, tx + 4, 4, "top")
        
        
        if #editor.tabs > 1 then
            gc:setColorRGB(180, 50, 50)
            gc:drawString("x", tx + tabWidth - 14, 4, "top")
        end
    end

    
    gc:setColorRGB(220, 220, 220)
    gc:fillRect(availableWidth, 0, 30, TAB_BAR_HEIGHT)
    gc:setColorRGB(60, 60, 60)
    gc:drawRect(availableWidth, 0, 30, TAB_BAR_HEIGHT)
    gc:drawString("[+]", availableWidth + 6, 4, "top")

    
    for i = 0, VISIBLE_LINES - 1 do 
    local lineIdx = current().scrollRow + i 
    local lineText = current().lines[lineIdx] 
    
    if lineText then 
        local DRAWROW, yPos = MARGIN_LEFT, MARGIN_TOP + (i * LINE_HEIGHT)
        if _isTextSelected and lineIdx == current().row and _selEndCol > _selStartCol then
            local b, s, a = lineText:sub(1, _selStartCol), lineText:sub(_selStartCol + 1, _selEndCol), lineText:sub(_selEndCol + 1)
            gc:setColorRGB(0, 0, 0); gc:drawString(b, DRAWROW, yPos, "top")
            local wb, ws = gc:getStringWidth(b), gc:getStringWidth(s)
            gc:setColorRGB(0, 120, 240); gc:fillRect(DRAWROW + wb, yPos, ws, LINE_HEIGHT)
            gc:setColorRGB(255, 255, 255); gc:drawString(s, DRAWROW + wb, yPos, "top")
            DRAWROW, lineText = DRAWROW + wb + ws, a
        end
        
        
        for spaces, word in lineText:gmatch("([%s]*)(%S+)") do 
            gc:setColorRGB(255, 255, 255)
            gc:drawString(spaces, DRAWROW, yPos)
            DRAWROW = DRAWROW + gc:getStringWidth(spaces)
                if word == "and" then
                    gc:setColorRGB(0, 0, 255)
                elseif word == "or" then
                    gc:setColorRGB(0, 0, 255)
                elseif word == "not" then
                    gc:setColorRGB(0, 0, 255)
                elseif word == "if" then
                    gc:setColorRGB(0, 0, 255)
                elseif word == "then" then
                    gc:setColorRGB(0, 0, 255)
                elseif word == "else" then
                    gc:setColorRGB(0, 0, 255)
                elseif word == "elseif" then
                    gc:setColorRGB(0, 0, 255)
                elseif word == "end" then
                    gc:setColorRGB(0, 0, 255)
                elseif word == "for" then
                    gc:setColorRGB(0, 0, 255)
                elseif word == "while" then
                    gc:setColorRGB(0, 0, 255)
                elseif word == "do" then
                    gc:setColorRGB(0, 0, 255)
                elseif word == "repeat" then
                    gc:setColorRGB(0, 0, 255)
                elseif word == "until" then
                    gc:setColorRGB(0, 0, 255)
                elseif word == "function" then
                    gc:setColorRGB(0, 0, 255)
                elseif word == "return" then
                    gc:setColorRGB(0, 0, 255)
                elseif word == "local" then
                    gc:setColorRGB(0, 0, 255)
                elseif word == "true" then
                    gc:setColorRGB(255, 0, 0)
                elseif word == "false" then
                    gc:setColorRGB(255, 0, 0)
                elseif word == "break" then
                    gc:setColorRGB(0, 0, 255)
                elseif word == "in" then
                    gc:setColorRGB(0, 0, 255)
                elseif word == "nil" then
                    gc:setColorRGB(255, 0, 0)
                else
                    gc:setColorRGB(0, 0, 0)
                end
                 gc:drawString(word, DRAWROW, yPos,"top")
            DRAWROW = DRAWROW + gc:getStringWidth(word)
        end
        
        
        if lineIdx == current().row and editor.cursorVisible and not _isTextSelected then
                local cursorX = MARGIN_LEFT + gc:getStringWidth(lineText:sub(1, current().col))
                gc:setColorRGB(0, 0, 0)
                gc:fillRect(cursorX, yPos + 1, 1, LINE_HEIGHT - 1)
            end
        end
    end

    
    if #current().lines > VISIBLE_LINES then
        local trackHeight = SCREEN_HEIGHT - MARGIN_TOP - 4
        local thumbHeight = math.max(15, math.floor((VISIBLE_LINES / #current().lines) * trackHeight))
        local scrollPercentage = (current().scrollRow - 1) / (#current().lines - VISIBLE_LINES)
        local thumbY = MARGIN_TOP + math.floor(scrollPercentage * (trackHeight - thumbHeight))
        
        gc:setColorRGB(210, 210, 210)
        gc:fillRect(SCREEN_WIDTH - SCROLLBAR_WIDTH - 2, MARGIN_TOP, SCROLLBAR_WIDTH, trackHeight)
        gc:setColorRGB(140, 140, 140)
        gc:fillRect(SCREEN_WIDTH - SCROLLBAR_WIDTH - 2, thumbY, SCROLLBAR_WIDTH, thumbHeight)
    end
    Prompt.paint(gc)
    Menu.draw(gc)
end

local function scrollIntoView()
    local doc = current()
    if current().row < current().scrollRow then
        current().scrollRow = current().row
    end
    if current().row >= current().scrollRow + VISIBLE_LINES then
        current().scrollRow = current().row - VISIBLE_LINES + 1
    end
end

function on.tabKey()
    local doc = current()
    local currentText = current().lines[current().row] or ""
    local left = string.sub(currentText, 1, current().col)
    local right = string.sub(currentText, current().col + 1)
    
    current().lines[current().row] = left .. "    " .. right
    current().col = current().col + 4
    platform.window:invalidate()
end

function on.charIn(char)
    if Prompt.charIn(char) then return end
    character=char
    local doc = current()
    local currentText = current().lines[current().row] or ""
    local left = string.sub(currentText, 1, current().col)
    local right = string.sub(currentText, current().col + 1)
    if char=="^2" then character=":" end
    if char=="exp(" then character="[" end
    if char=="10^(" then character="]" end
    if char=="ln(" then character="{" end
    if char=="log(" then character="}" end
    current().lines[current().row] = left.. character .. right
    current().col = current().col + 1
    editor.shouldWrap = true
    
    scrollIntoView()
    platform.window:invalidate()
end

function on.enterKey()
    if Menu.enter() then return end
    if Prompt.enter() then return end
    local doc = current()
    local currentText = current().lines[current().row] or ""
    local left = string.sub(currentText, 1, current().col)
    local right = string.sub(currentText, current().col + 1)
    
    current().lines[current().row] = left
    table.insert(current().lines, current().row + 1, right)
    current().row = current().row + 1
    current().col = 0
    
    scrollIntoView()
    platform.window:invalidate()
end

function on.backspaceKey()
    if Prompt.backspace() then return end
    
    if _isTextSelected and _selEndCol > _selStartCol then current().lines[current().row] = string.sub(current().lines[current().row], 1, _selStartCol) .. string.sub(current().lines[current().row], _selEndCol + 1); current().col = _selStartCol; _isTextSelected = false; scrollIntoView(); platform.window:invalidate(); return end
    if Prompt.backspace() then return end
    local doc = current()
    local currentText = current().lines[current().row]
    
    if current().col > 0 then
        local left = string.sub(currentText, 1, current().col - 1)
        local right = string.sub(currentText, current().col + 1)
        current().lines[current().row] = left .. right
        current().col = current().col - 1
    elseif current().row > 1 then
        local prevText = current().lines[current().row - 1]
        current().col=string.len(prevText)
        current().lines[current().row-1]=prevText..currentText
        table.remove(current().lines, current().row)
        current().row=current().row-1
    end
    scrollIntoView()
    platform.window:invalidate()
end
local function handleSelectionKeys(direction)
    if not _isTextSelected then return false end
    local lineLength = string.len(current().lines[current().row] or "")
    if direction == "right" and current().col < lineLength then current().col = current().col + 1
    elseif direction == "left" and current().col > 0 then current().col = current().col - 1
    elseif direction == "up" then current().col = lineLength
    elseif direction == "down" then current().col = _selAnchorCol end
    _selStartCol = math.min(_selAnchorCol, current().col)
    _selEndCol = math.max(_selAnchorCol, current().col)
    scrollIntoView(); platform.window:invalidate()
    return true
end
function on.arrowKey(direction)
    if handleSelectionKeys(direction) then return end
    local doc = current()
    if direction == "up" then
        if Menu.arrowUp() then return end
        if current().row > 1 then
            current().row = current().row - 1
            local lineLength = string.len(current().lines[current().row] or "")
            if current().col > lineLength then
                current().col = lineLength
            end
        end
    elseif direction == "down" then
        if Menu.arrowDown() then return end
        if current().row < #current().lines then
            current().row = current().row + 1
            local lineLength = string.len(current().lines[current().row] or "")
            if current().col > lineLength then
                current().col = lineLength
            end
        end
    elseif direction == "left" then
        if current().col > 0 then
            current().col = current().col - 1
        elseif current().row > 1 then
            current().row = current().row - 1
            current().col = string.len(current().lines[current().row] or "")
        end
    elseif direction == "right" then
        local lineLength = string.len(current().lines[current().row] or "")
        if current().col < lineLength then
            current().col = current().col + 1
        elseif current().row < #current().lines then
            current().row = current().row + 1
            current().col = 0
        end
    end
    
    scrollIntoView()
    platform.window:invalidate()
end
function on.copy()
    local doc = current()
    clipboard.setText(current().lines[current().row] or "")
end
function on.paste()
    local pasteText = clipboard.getText()
    if not pasteText or pasteText == "" then return end
    
    local currentText = current().lines[current().row] or ""
    local left = string.sub(currentText, 1, current().col)
    local right = string.sub(currentText, current().col + 1)
    
    current().lines[current().row] = left .. pasteText .. right
    current().col = current().col + string.len(pasteText)
    
    editor.shouldWrap = true
    scrollIntoView()
    platform.window:invalidate()
end


function on.mouseDown(x, y)
    editor.pendingClick = {x = x, y = y}
    platform.window:invalidate()
end

function on.timer()
    editor.cursorVisible = not editor.cursorVisible
    platform.window:invalidate()
end
timer.start(0.4)
menu = {
    {"Tabs",
        {"New Tab", function()
            editor.tabCounter = editor.tabCounter + 1
            table.insert(editor.tabs, {
                name = "Untitled" .. editor.tabCounter .. ".lua",
                lines = {""},
                row = 1,
                col = 17,
                scrollRow = 1
            })
            editor.activeTab = #editor.tabs 
            platform.window:invalidate()
        end},
        {"Close Tab", function()
            if #editor.tabs > 1 then
                table.remove(editor.tabs, editor.activeTab)
                if editor.activeTab > #editor.tabs then
                    editor.activeTab = #editor.tabs
                elseif editor.activeTab > 1 then
                    editor.activeTab = editor.activeTab - 1
                end
                platform.window:invalidate()
            end
        end},
        {"Rename Tab", function()
            Prompt.show("Enter new tab name: ", current().name, function(result)
                if result and result ~= "" then
                    current().name = result
                    platform.window:invalidate()
                end
            end)
        end
        }
    },
    {"Font",
        {"Increase Size", function()
            editor.font.size = editor.font.size + 1
            platform.window:invalidate()
        end},
        {"Decrease Size", function()
            if editor.font.size > 1 then
                editor.font.size = editor.font.size - 1
                platform.window:invalidate()
            end
        end}
    },
    {"File",
        {"Save All", function()
            local varNames = var.recall("nidevarnames") or {}
    for i = 1, #editor.tabs do
        local varName = "nide_" .. editor.tabs[i].name
        
        varName = string.sub(varName, 1, 16) 
        if not has(varNames, varName) then
            table.insert(varNames, varName)
        end
        var.store(varName, editor.tabs[i].lines)
    end
    var.store("nidevarnames", varNames)
        end},
        {"Load",function()
            local varNames = var.recall("nidevarnames") or {}
            if #varNames == 0 then
                platform.window:invalidate()
                return
            end
            Menu.show("Select a file to load:", varNames, function(index, selected)
                if index and selected then
                    local loadedLines = var.recall(selected) or {""}
                    table.insert(editor.tabs, {
                        name = string.sub(selected, 6),
                        lines = loadedLines,
                        row = 1,
                        col = 0,
                        scrollRow = 1
                    })
                    editor.activeTab = #editor.tabs
                    platform.window:invalidate()
                end
            end)
        end}
    }
}
toolpalette.register(menu)
function on.contextMenu()
    code=""
    for e=1,#current().lines do
        code=code..current().lines[e].."\n"
    end
    var.store("nidecurcode", code)
end

Prompt = {
    text = "",
    label = "Prompt: ",
    active = false,
    callback = nil,

    
    show = function(label, default, callback)
        Prompt.label = label or "Enter value: "
        Prompt.text = default or ""
        Prompt.callback = callback
        Prompt.active = true
        platform.window:invalidate()
    end,

    
    charIn = function(char)
        if Prompt.active then Prompt.text = Prompt.text .. char; platform.window:invalidate(); return true end
    end,
    backspace = function()
        if Prompt.active then Prompt.text = string.sub(Prompt.text, 1, -2); platform.window:invalidate(); return true end
    end,
    enter = function()
        if Prompt.active then
            Prompt.active = false
            if Prompt.callback then Prompt.callback(Prompt.text) end
            platform.window:invalidate()
            return true
        end
    end,

    
    paint = function(gc)
        if not Prompt.active then return end
        
        gc:setColorRGB(240, 240, 240)
        gc:fillRect(10, 10, 300, 50)
        gc:setColorRGB(0, 0, 0)
        gc:drawRect(10, 10, 300, 50)
        
        gc:drawString(Prompt.label .. Prompt.text, 20, 25, "top")
    end
}
function on.save()
    local varNames = var.recall("nidevarnames") or {}
    for i = 1, #editor.tabs do
        local varName = "nide_" .. editor.tabs[i].name
        
        varName = string.sub(varName, 1, 16) 
        if not has(varNames, varName) then
            table.insert(varNames, varName)
        end
        var.store(varName, editor.tabs[i].lines)
    end
    var.store("nidevarnames", varNames)
end

Menu = {
    title = "Select Option",
    options = {},
    index = 1,
    active = false,
    callback = nil,

    
    show = function(title, options, callback)
        Menu.title = title or "Select:"
        Menu.options = options or {}
        Menu.index = 1
        Menu.callback = callback
        Menu.active = true
        platform.window:invalidate()
    end,

    
    arrowUp = function()
        if Menu.active then
            Menu.index = Menu.index > 1 and Menu.index - 1 or #Menu.options
            platform.window:invalidate()
            return true
        end
    end,
    arrowDown = function()
        if Menu.active then
            Menu.index = Menu.index < #Menu.options and Menu.index + 1 or 1
            platform.window:invalidate()
            return true
        end
    end,
    enter = function()
        if Menu.active then
            Menu.active = false
            if Menu.callback then Menu.callback(Menu.index, Menu.options[Menu.index]) end
            platform.window:invalidate()
            return true
        end
    end,

    
    draw = function(gc)
        if not Menu.active then return end
        local y = 20
        
        gc:setColorRGB(240, 240, 240)
        gc:fillRect(20, y, 280, 40 + (#Menu.options * 20))
        gc:setColorRGB(0, 0, 0)
        gc:drawRect(20, y, 280, 40 + (#Menu.options * 20))
        
        
        gc:setFont("sansserif", "b", 12)
        gc:drawString(Menu.title, 30, y + 10, "top")
        
        
        gc:setFont("sansserif", "r", 10)
        for i, opt in ipairs(Menu.options) do
            local itemY = y + 35 + ((i - 1) * 20)
            if i == Menu.index then
                
                gc:setColorRGB(200, 200, 200)
                gc:fillRect(25, itemY, 270, 18)
                gc:setColorRGB(0, 0, 0)
                gc:drawString("> " .. opt, 30, itemY, "top")
            else
                gc:drawString("  " .. opt, 30, itemY, "top")
            end
        end
    end
}
function on.grabDown(x, y)
    _isTextSelected = not _isTextSelected; _selAnchorCol, _selStartCol, _selEndCol = current().col, current().col, current().col; platform.window:invalidate()
end
