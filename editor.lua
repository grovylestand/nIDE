local SCREEN_WIDTH = 318
local SCREEN_HEIGHT = 212
local TAB_BAR_HEIGHT = 24
local LINE_HEIGHT = 14
local MARGIN_LEFT = 10
local MARGIN_TOP = TAB_BAR_HEIGHT + 6
local SCROLLBAR_WIDTH = 6
local VISIBLE_LINES = math.floor((SCREEN_HEIGHT - MARGIN_TOP) / LINE_HEIGHT)

local isTextSelected = false
local selAnchorLine = 1
local selAnchorCol = 0
local selStartLine = nil
local selStartChar = nil
local selEndLine = nil
local selEndChar = nil
local selStartCol = 0
local selEndCol = 0
local isSelecting = false
local localClipboard = ""
consoleBuffer = {}
maxLines = 10

local editor = {
    tabs = {
        { name = "Untitled1", lines = {""}, row = 1, col = 0, scrollRow = 1 },
        { name = "Untitled2", lines = {""}, row = 1, col = 0, scrollRow = 1 }
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

local function has(tbl, val)
    for _, v in ipairs(tbl) do
        if v == val then return true end
    end
    return false
end

local function deleteSelectedText()
    if not isTextSelected then return false end
    local doc = current()
    local startLine, startCol, endLine, endCol
    if doc.row < selAnchorLine or (doc.row == selAnchorLine and doc.col < selAnchorCol) then
        startLine, startCol = doc.row, doc.col
        endLine, endCol = selAnchorLine, selAnchorCol
    else
        startLine, startCol = selAnchorLine, selAnchorCol
        endLine, endCol = doc.row, doc.col
    end
    local startLineText = doc.lines[startLine] or ""
    local endLineText = doc.lines[endLine] or ""
    if startLine == endLine then
        local left = string.sub(startLineText, 1, startCol)
        local right = string.sub(startLineText, endCol + 1)
        doc.lines[startLine] = left .. right
    else
        local left = string.sub(startLineText, 1, startCol)
        local right = string.sub(endLineText, endCol + 1)
        doc.lines[startLine] = left .. right
        for i = endLine, startLine + 1, -1 do
            table.remove(doc.lines, i)
        end
    end
    doc.row = startLine
    doc.col = startCol
    isTextSelected = false
    return true
end

local function isCharSelected(lineIdx, colIdx)
    if not isTextSelected then return false end
    local doc = current()
    local startLine, startCol, endLine, endCol
    if doc.row < selAnchorLine or (doc.row == selAnchorLine and doc.col < selAnchorCol) then
        startLine, startCol = doc.row, doc.col
        endLine, endCol = selAnchorLine, selAnchorCol
    else
        startLine, startCol = selAnchorLine, selAnchorCol
        endLine, endCol = doc.row, doc.col
    end
    if lineIdx < startLine or lineIdx > endLine then return false end
    if lineIdx > startLine and lineIdx < endLine then return true end
    if startLine == endLine then
        return colIdx >= startCol and colIdx < endCol
    elseif lineIdx == startLine then
        return colIdx >= startCol
    elseif lineIdx == endLine then
        return colIdx < endCol
    end
    return false
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

local function handleSelectionKeys(direction)
    if not isTextSelected then return false end
    local doc = current()
    if direction == "up" then
        if doc.row > 1 then
            doc.row = doc.row - 1
            local lineLength = string.len(doc.lines[doc.row] or "")
            if doc.col > lineLength then doc.col = lineLength end
        end
    elseif direction == "down" then
        if doc.row < #doc.lines then
            doc.row = doc.row + 1
            local lineLength = string.len(doc.lines[doc.row] or "")
            if doc.col > lineLength then doc.col = lineLength end
        end
    elseif direction == "left" then
        if doc.col > 0 then
            doc.col = doc.col - 1
        elseif doc.row > 1 then
            doc.row = doc.row - 1
            doc.col = string.len(doc.lines[doc.row] or "")
        end
    elseif direction == "right" then
        local lineLength = string.len(doc.lines[doc.row] or "")
        if doc.col < lineLength then
            doc.col = doc.col + 1
        elseif doc.row < #doc.lines then
            doc.row = doc.row + 1
            doc.col = 0
        end
    end
    scrollIntoView()
    platform.window:invalidate()
    return true
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

Menu = {
    title = "Select Option",
    options = {},
    index = 1,
    scrollRow = 1,
    maxVisible = 6,
    active = false,
    callback = nil,
    show = function(title, options, callback)
        Menu.title = title or "Select:"
        Menu.options = options or {}
        Menu.index = 1
        Menu.scrollRow = 1
        Menu.callback = callback
        Menu.active = true
        platform.window:invalidate()
    end,
    arrowUp = function()
        if Menu.active then
            Menu.index = Menu.index > 1 and Menu.index - 1 or #Menu.options
            if Menu.index < Menu.scrollRow then
                Menu.scrollRow = Menu.index
            elseif Menu.index == #Menu.options then
                Menu.scrollRow = math.max(1, #Menu.options - Menu.maxVisible + 1)
            end
            platform.window:invalidate()
            return true
        end
    end,
    arrowDown = function()
        if Menu.active then
            Menu.index = Menu.index < #Menu.options and Menu.index + 1 or 1
            if Menu.index >= Menu.scrollRow + Menu.maxVisible then
                Menu.scrollRow = Menu.index - Menu.maxVisible + 1
            elseif Menu.index == 1 then
                Menu.scrollRow = 1
            end
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
        local visibleCount = math.min(#Menu.options, Menu.maxVisible)
        local menuHeight = 40 + (visibleCount * 20)
        
        gc:setColorRGB(240, 240, 240)
        gc:fillRect(20, y, 280, menuHeight)
        gc:setColorRGB(0, 0, 0)
        gc:drawRect(20, y, 280, menuHeight)
        
        gc:setFont("sansserif", "b", 12)
        gc:drawString(Menu.title, 30, y + 10, "top")
        gc:setFont("sansserif", "r", 10)
        
        for i = 0, visibleCount - 1 do
            local itemIdx = Menu.scrollRow + i
            local opt = Menu.options[itemIdx]
            if opt then
                local itemY = y + 35 + (i * 20)
                if itemIdx == Menu.index then
                    gc:setColorRGB(200, 200, 200)
                    gc:fillRect(25, itemY, 255, 18)
                    gc:setColorRGB(0, 0, 0)
                    gc:drawString("> " .. opt, 30, itemY, "top")
                else
                    gc:drawString("  " .. opt, 30, itemY, "top")
                end
            end
        end
        
        if #Menu.options > Menu.maxVisible then
            local sbX = 20 + 280 - 10
            local sbY = y + 35
            local sbHeight = visibleCount * 20
            
            gc:setColorRGB(220, 220, 220)
            gc:fillRect(sbX, sbY, 6, sbHeight)
            
            local thumbHeight = math.max(10, math.floor((Menu.maxVisible / #Menu.options) * sbHeight))
            local maxScrollDist = #Menu.options - Menu.maxVisible
            local scrollPct = (Menu.scrollRow - 1) / maxScrollDist
            local thumbY = sbY + math.floor(scrollPct * (sbHeight - thumbHeight))
            
            gc:setColorRGB(120, 120, 120)
            gc:fillRect(sbX, thumbY, 6, thumbHeight)
        end
    end
}

toolpalette.enableCopy(true)
toolpalette.enablePaste(true)

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
        end}
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
        {"Load", function()
            local varNames = var.recall("nidevarnames") or {}
            if #varNames == 0 then
                platform.window:invalidate()
                return
            end
            Menu.show("Select a file to load:", varNames, function(index, selected)
                if index and selected then
                    local targetName = string.sub(selected, 6)
                    
                    local alreadyOpenIdx = nil
                    for i, tab in ipairs(editor.tabs) do
                        if tab.name == targetName then
                            alreadyOpenIdx = i
                            break
                        end
                    end
                    
                    if alreadyOpenIdx then
                        editor.activeTab = alreadyOpenIdx
                    else
                        local loadedLines = var.recall(selected) or {""}
                        table.insert(editor.tabs, {
                            name = targetName,
                            lines = loadedLines,
                            row = 1,
                            col = 0,
                            scrollRow = 1
                        })
                        editor.activeTab = #editor.tabs
                    end
                    platform.window:invalidate()
                end
            end)
        end}
    }
}
toolpalette.register(menu)

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
            local startLine, startCol, endLine, endCol
            if current().row < selAnchorLine or (current().row == selAnchorLine and current().col < selAnchorCol) then
                startLine, startCol = current().row, current().col
                endLine, endCol = selAnchorLine, selAnchorCol
            else
                startLine, startCol = selAnchorLine, selAnchorCol
                endLine, endCol = current().row, current().col
            end
            local lineSelStart, lineSelEnd = nil, nil
            if isTextSelected and lineIdx >= startLine and lineIdx <= endLine then
                if lineIdx == startLine and lineIdx == endLine then
                    lineSelStart, lineSelEnd = startCol, endCol
                elseif lineIdx == startLine then
                    lineSelStart, lineSelEnd = startCol, string.len(lineText)
                elseif lineIdx == endLine then
                    lineSelStart, lineSelEnd = 0, endCol
                else
                    lineSelStart, lineSelEnd = 0, string.len(lineText)
                end
            end
            if lineSelStart and lineSelEnd and lineSelEnd > lineSelStart then
                local sX = MARGIN_LEFT + gc:getStringWidth(lineText:sub(1, lineSelStart))
                local sW = gc:getStringWidth(lineText:sub(lineSelStart + 1, lineSelEnd))
                gc:setColorRGB(35, 128, 255)
                gc:fillRect(sX, yPos, sW, LINE_HEIGHT)
            end
            local charTracker = 0
            for spaces, word in lineText:gmatch("([%s]*)(%S+)") do 
                if spaces and spaces ~= "" then
                    for sIdx = 1, string.len(spaces) do
                        if lineSelStart and lineSelEnd and charTracker >= lineSelStart and charTracker < lineSelEnd then
                            gc:setColorRGB(255, 255, 255)
                        else
                            gc:setColorRGB(0, 0, 0)
                        end
                        local ch = spaces:sub(sIdx, sIdx)
                        gc:drawString(ch, DRAWROW, yPos, "top")
                        DRAWROW = DRAWROW + gc:getStringWidth(ch)
                        charTracker = charTracker + 1
                    end
                end
                local syntaxR, syntaxG, syntaxB = 0, 0, 0
                if word == "and" or word == "or" or word == "not" or word == "if" or 
                   word == "then" or word == "else" or word == "elseif" or word == "end" or 
                   word == "for" or word == "while" or word == "do" or word == "repeat" or 
                   word == "until" or word == "function" or word == "return" or word == "local" or 
                   word == "break" or word == "in" then
                    syntaxR, syntaxG, syntaxB = 0, 0, 255
                elseif word == "true" or word == "false" or word == "nil" then
                    syntaxR, syntaxG, syntaxB = 255, 0, 0
                end
                for wIdx = 1, string.len(word) do
                    if lineSelStart and lineSelEnd and charTracker >= lineSelStart and charTracker < lineSelEnd then
                        gc:setColorRGB(255, 255, 255)
                    else
                        gc:setColorRGB(syntaxR, syntaxG, syntaxB)
                    end
                    local ch = word:sub(wIdx, wIdx)
                    gc:drawString(ch, DRAWROW, yPos, "top")
                    DRAWROW = DRAWROW + gc:getStringWidth(ch)
                    charTracker = charTracker + 1
                end
            end
            if lineIdx == current().row and editor.cursorVisible and not isTextSelected then
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
    deleteSelectedText()
    character = char
    local doc = current()
    local currentText = doc.lines[doc.row] or ""
    local left = string.sub(currentText, 1, doc.col)
    local right = string.sub(currentText, doc.col + 1)
    if char == "^2" then character = ":" end
    if char == "exp(" then character = "[" end
    if char == "10^(" then character = "]" end
    if char == "ln(" then character = "{" end
    if char == "log(" then character = "}" end
    doc.lines[doc.row] = left .. character .. right
    doc.col = doc.col + 1
    editor.shouldWrap = true
    scrollIntoView()
    platform.window:invalidate()
end

function on.enterKey()
    if Menu.enter() then return end
    if Prompt.enter() then return end
    deleteSelectedText()
    local doc = current()
    local currentText = doc.lines[doc.row] or ""
    local left = string.sub(currentText, 1, doc.col)
    local right = string.sub(currentText, doc.col + 1)
    doc.lines[doc.row] = left
    table.insert(doc.lines, doc.row + 1, right)
    doc.row = doc.row + 1
    doc.col = 0
    scrollIntoView()
    platform.window:invalidate()
end

function on.backspaceKey()
    if Prompt.backspace() then return end
    if deleteSelectedText() then
        scrollIntoView()
        platform.window:invalidate()
        return
    end
    local doc = current()
    local currentText = doc.lines[doc.row] or ""
    if doc.col > 0 then
        local left = string.sub(currentText, 1, doc.col - 1)
        local right = string.sub(currentText, doc.col + 1)
        doc.lines[doc.row] = left .. right
        doc.col = doc.col - 1
    elseif doc.row > 1 then
        local prevText = doc.lines[doc.row - 1] or ""
        doc.col = string.len(prevText)
        doc.lines[doc.row - 1] = prevText .. currentText
        table.remove(doc.lines, doc.row)
        doc.row = doc.row - 1
    end
    scrollIntoView()
    platform.window:invalidate()
end

function on.arrowKey(direction)
    if Menu.active then
        if direction == "up" then 
            Menu.arrowUp() 
        elseif direction == "down" then 
            Menu.arrowDown() 
        end
        return
    end

    if Prompt.active then return end

    if isTextSelected then 
        handleSelectionKeys(direction) 
        return 
    end
    
    local doc = current()
    isTextSelected = false 
    if direction == "up" then
        if doc.row > 1 then
            doc.row = doc.row - 1
            local lineLength = string.len(doc.lines[doc.row] or "")
            if doc.col > lineLength then doc.col = lineLength end
        end
    elseif direction == "down" then
        if doc.row < #doc.lines then
            doc.row = doc.row + 1
            local lineLength = string.len(doc.lines[doc.row] or "")
            if doc.col > lineLength then doc.col = lineLength end
        end
    elseif direction == "left" then
        if doc.col > 0 then
            doc.col = doc.col - 1
        elseif doc.row > 1 then
            doc.row = doc.row - 1
            doc.col = string.len(doc.lines[doc.row] or "")
        end
    elseif direction == "right" then
        local lineLength = string.len(doc.lines[doc.row] or "")
        if doc.col < lineLength then
            doc.col = doc.col + 1
        elseif doc.row < #doc.lines then
            doc.row = doc.row + 1
            doc.col = 0
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
    local doc = current()
    local currentText = current().lines[current().row] or ""
    local left = string.sub(currentText, 1, current().col)
    local right = string.sub(currentText, current().col + 1)
    local pastedLines = {}
    for line in (pasteText .. ""):gmatch("([^]*)??") do
        table.insert(pastedLines, line)
    end
    if #pastedLines > 1 then table.remove(pastedLines) end
    if #pastedLines <= 1 then
        current().lines[current().row] = left .. pasteText .. right
        current().col = current().col + string.len(pasteText)
    else
        pastedLines[1] = left .. pastedLines[1]
        local lastLineIdx = #pastedLines
        local targetCol = string.len(pastedLines[lastLineIdx])
        pastedLines[lastLineIdx] = pastedLines[lastLineIdx] .. right
        current().lines[current().row] = pastedLines[1]
        for i = 2, lastLineIdx do
            table.insert(current().lines, current().row + i - 1, pastedLines[i])
        end
        current().row = current().row + lastLineIdx - 1
        current().col = targetCol
    end
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

function on.contextMenu()
    code=""
    for e=1,#current().lines do
        code=code..current().lines[e].."\n"
    end
    var.store("nidecurcode", code)
end

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

function on.grabDown(x, y)
    isTextSelected = not isTextSelected
    selAnchorLine = current().row
    selAnchorCol = current().col
    platform.window:invalidate()
end

timer.start(0.4)
