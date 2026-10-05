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
local autocompleteHint = ""
local autocompleteFullWord = ""
local autocompleteMatchLen = 0
consoleBuffer = {}
maxLines = 10  
local themes = {
    {
        bg = {245, 245, 245},
        activeTab = {255, 255, 255},
        activeTabText = {0,0,0},
        inactiveTab = {220, 220, 220},
        inactiveTabText = {100, 100, 100},
        newTabBackground = {230, 230, 230},
        newTabBorders = {180, 180, 180},
        scrollTrack = {235, 235, 235},
        scrollThumb = {170, 170, 170},
        selectColor = {180, 210, 255},
        closeTab = {200, 60, 60},
        promptBg = {245, 245, 245},
        activeRow = {230, 235, 245},
        menuScrollTrack = {230, 230, 230},
        menuScrollThumb = {160, 160, 160},
        keywordsH = {0, 0, 200},
        boolnilH = {180, 0, 0},
        stdlibH = {0, 130, 0},
        codeH = {30, 30, 30}
    },
    {
        bg = {25, 25, 25},
        activeTab = {40, 40, 40},
        activeTabText = {240,240,240},
        inactiveTab = {18, 18, 18},
        inactiveTabText = {130, 130, 130},
        newTabBackground = {30, 30, 30},
        newTabBorders = {70, 70, 70},
        scrollTrack = {20, 20, 20},
        scrollThumb = {70, 70, 70},
        selectColor = {40, 80, 140},
        closeTab = {180, 70, 70},
        promptBg = {25, 25, 25},
        activeRow = {45, 45, 45},
        menuScrollTrack = {30, 30, 30},
        menuScrollThumb = {80, 80, 80},
        keywordsH = {86, 156, 214},
        boolnilH = {206, 145, 120},
        stdlibH = {78, 201, 176},
        codeH = {220, 220, 220}
    }
}

local editor = {
    tabs = {
        { name = "Untitled1", lines = {""}, row = 1, col = 0, scrollRow = 1 },
        { name = "Untitled2", lines = {""}, row = 1, col = 0, scrollRow = 1 }
    },
    currentTheme = 2,
    activeTab = 1,
    tabCounter = 2, 
    cursorVisible = true,
    font = {family = "sansserif", style = "r", size = 9},
    pendingClick = nil,
    shouldWrap = false
}

function c(themeColor,num)
  return themes[editor.currentTheme][themeColor][num]
end
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
function saveCustomThemes()
    local customThemes = {}
    for i = 3, #themes do
        table.insert(customThemes, themes[i])
    end
    var.store("nide_themes", customThemes)
end

function loadCustomThemes()
    local saved = var.recall("nide_themes")
    if saved and type(saved) == "table" then
        for _, t in ipairs(saved) do
            table.insert(themes, t)
        end
    end
end

loadCustomThemes()
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
        gc:setColorRGB(c("promptBg",1), c("promptBg",2), c("promptBg",3))
        gc:fillRect(10, 10, 300, 50)
        gc:setColorRGB(c("codeH",1),c("codeH",2),c("codeH",3))
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
        
        gc:setColorRGB(c("promptBg",1),c("promptBg",2),c("promptBg",3))
        gc:fillRect(20, y, 280, menuHeight)
        gc:setColorRGB(c("codeH",1),c("codeH",2),c("codeH",3))
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
                    gc:setColorRGB(c("activeRow",1),c("activeRow",2),c("activeRow",3))
                    gc:fillRect(25, itemY, 255, 18)
                    gc:setColorRGB(c("codeH",1),c("codeH",2),c("codeH",3))
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
            
            gc:setColorRGB(c("menuScrollTrack",1),c("menuScrollTrack",2),c("menuScrollTrack",3))
            gc:fillRect(sbX, sbY, 6, sbHeight)
            
            local thumbHeight = math.max(10, math.floor((Menu.maxVisible / #Menu.options) * sbHeight))
            local maxScrollDist = #Menu.options - Menu.maxVisible
            local scrollPct = (Menu.scrollRow - 1) / maxScrollDist
            local thumbY = sbY + math.floor(scrollPct * (sbHeight - thumbHeight))
            
            gc:setColorRGB(c("menuScrollThumb",1),c("menuScrollThumb",2),c("menuScrollThumb",3))
            gc:fillRect(sbX, thumbY, 6, thumbHeight)
        end
    end
}

toolpalette.enableCopy(true)
toolpalette.enablePaste(true)

menu = {
    {"View",
        {"Toggle Theme", function()
            editor.currentTheme = (editor.currentTheme % #themes) + 1
            platform.window:invalidate()
        end},
        {"Edit Theme Properties", function()
        local propNames = {
            "1. Background",
            "2. Active Tab",
            "3. Inactive Tab",
            "4. Inactive Tab Text",
            "5. New Tab BG",
            "6. New Tab Borders",
            "7. Scroll Track",
            "8. Scroll Thumb",
            "9. Selection Color",
            "10. Close Tab Button",
            "11. Prompt BG",
            "12. Active Row Highlight",
            "13. Menu Scroll Track",
            "14. Menu Scroll Thumb",
            "15. Keywords Highlight",
            "16. Boolean/Nil Highlight",
            "17. Stdlib Highlight",
            "18. Code Text"
        }

        local keys = {
            "bg", "activeTab", "inactiveTab", "inactiveTabText",
            "newTabBackground", "newTabBorders", "scrollTrack", "scrollThumb",
            "selectColor", "closeTab", "promptBg", "activeRow",
            "menuScrollTrack", "menuScrollThumb", "keywordsH", "boolnilH",
            "stdlibH", "codeH"
        }

        Menu.show("Select Property to Edit:", propNames, function(index)
            if not index or not keys[index] then return end

            local key = keys[index]
            local curTheme = themes[editor.currentTheme] or themes[1]
            local defaultVal = curTheme[key] and table.concat(curTheme[key], ",") or "255,255,255"

            Prompt.show("Enter RGB for " .. key .. " (R,G,B):", defaultVal, function(input)
                if not input or input == "" then return end

                local r, g, b = input:match("(%d+),%s*(%d+),%s*(%d+)")
                if r and g and b then
                    if editor.currentTheme <= 2 then
                        local newTheme = {}
                        for k, v in pairs(curTheme) do
                            newTheme[k] = {v[1], v[2], v[3]}
                        end
                        table.insert(themes, newTheme)
                        editor.currentTheme = #themes
                    end

                    themes[editor.currentTheme][key] = {tonumber(r), tonumber(g), tonumber(b)}
                    
                    saveCustomThemes()
                    platform.window:invalidate()
                end
            end)
        end)
    end}
},
    {"Code",
    {"Go to Line", function()
            Prompt.show("Go to line: ", "", function(result)
                local targetLine = tonumber(result)
                if targetLine then
                    local doc = current()
                    doc.row = math.max(1, math.min(targetLine, #doc.lines))
                    doc.col = 0
                    scrollIntoView()
                    platform.window:invalidate()
                end
            end)
        end}
    },
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
    gc:setColorRGB(c("bg",1),c("bg",2),c("bg",3))
    gc:fillRect(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
    local availableWidth = SCREEN_WIDTH - 30
    local tabWidth = math.floor(availableWidth / #editor.tabs)
    for tIdx, tabItem in ipairs(editor.tabs) do
        local tx = (tIdx - 1) * tabWidth
        if tIdx == editor.activeTab then
            gc:setColorRGB(c("activeTab",1),c("activeTab",2),c("activeTab",3))
            gc:fillRect(tx, 0, tabWidth, TAB_BAR_HEIGHT)
            gc:setColorRGB(c("codeH",1),c("codeH",2),c("codeH",3))
        else
            gc:setColorRGB(c("inactiveTab",1),c("inactiveTab",2),c("inactiveTab",3))
            gc:fillRect(tx, 0, tabWidth, TAB_BAR_HEIGHT)
            gc:setColorRGB(c("inactiveTabText",1),c("inactiveTabText",2),c("inactiveTabText",3))
        end
        gc:drawRect(tx, 0, tabWidth, TAB_BAR_HEIGHT)
        local displayName = tabItem.name
        if gc:getStringWidth(displayName) > (tabWidth - 22) then
            displayName = string.sub(displayName, 1, 5) .. "..."
        end
        gc:drawString(displayName, tx + 4, 4, "top")
        if #editor.tabs > 1 then
            gc:setColorRGB(c("closeTab",1),c("closeTab",2),c("closeTab",3))
            gc:drawString("x", tx + tabWidth - 14, 4, "top")
        end
    end
    gc:setColorRGB(c("newTabBackground",1),c("newTabBackground",2),c("newTabBackground",3))
    gc:fillRect(availableWidth, 0, 30, TAB_BAR_HEIGHT)
    gc:setColorRGB(c("newTabBorders",1),c("newTabBorders",2),c("newTabBorders",3))
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
                gc:setColorRGB(c("selectColor",1),c("selectColor",2),c("selectColor",3))
                gc:fillRect(sX, yPos, sW, LINE_HEIGHT)
            end
            local charTracker = 0
            local hintDrawX = nil 
            for spaces, token in lineText:gmatch("([%s]*)([%w_%p]+)") do 
                if spaces and spaces ~= "" then
                    for sIdx = 1, string.len(spaces) do
                      if charTracker == current().col then hintDrawX = DRAWROW end 
                        if lineSelStart and lineSelEnd and charTracker >= lineSelStart and charTracker < lineSelEnd then
    gc:setColorRGB(c("bg",1), c("bg",2), c("bg",3))
else
    gc:setColorRGB(c("codeH",1), c("codeH",2), c("codeH",3))
end

                        local ch = spaces:sub(sIdx, sIdx)
                        gc:drawString(ch, DRAWROW, yPos, "top")
                        DRAWROW = DRAWROW + gc:getStringWidth(ch)
                        charTracker = charTracker + 1
                    end
                end

                local subPos = 1
                while subPos <= string.len(token) do
                    local wStart, wEnd = token:find("^([%w_]+)", subPos)
                    local word = ""
                    local isSymbol = false

                    if wStart then
                        word = token:sub(wStart, wEnd)
                        subPos = wEnd + 1
                    else
                        word = token:sub(subPos, subPos)
                        isSymbol = true
                        subPos = subPos + 1
                    end

                    local syntaxR, syntaxG, syntaxB = c("codeH",1),c("codeH",2),c("codeH",3)
                    if not isSymbol then
                        if word == "and" or word == "or" or word == "not" or word == "if" or 
                           word == "then" or word == "else" or word == "elseif" or word == "end" or 
                           word == "for" or word == "while" or word == "do" or word == "repeat" or 
                           word == "until" or word == "function" or word == "return" or word == "local" or 
                           word == "break" or word == "in" then
                            syntaxR, syntaxG, syntaxB = c("keywordsH",1),c("keywordsH",2),c("keywordsH",3)
                        elseif word == "true" or word == "false" or word == "nil" then
                            syntaxR, syntaxG, syntaxB = c("boolnilH",1),c("boolnilH",2),c("boolnilH",3)
                        elseif word == "assert" or word=="collectgarbage" or word=="error" or word=="_G" or word=="getfenv" or word=="getmetatable" or word=="ipairs" or word=="load" or word=="loadstring"  or word=="next" or word=="pairs" or word=="pcall" or word=="print" or word=="rawequal" or word=="rawget" or word=="rawset" or word=="select" or word=="setfenv" or word=="setmetatable" or word=="tonumber" or word=="tostring" or word=="type" or word=="unpack" or word=="xpcall" or word=="_VERSION" then
                            syntaxR, syntaxG, syntaxB = c("stdlibH",1),c("stdlibH",2),c("stdlibH",3)
                        end
                    end

                    for wIdx = 1, string.len(word) do
                        if lineSelStart and lineSelEnd and charTracker >= lineSelStart and charTracker < lineSelEnd then
                            gc:setColorRGB(c("activeTab",1),c("activeTab",2),c("activeTab",3))
                        else
                            gc:setColorRGB(syntaxR, syntaxG, syntaxB)
                        end
                        local ch = word:sub(wIdx, wIdx)
                        gc:drawString(ch, DRAWROW, yPos, "top")
                        DRAWROW = DRAWROW + gc:getStringWidth(ch)
                        charTracker = charTracker + 1
                    end
                end
            end
            if lineIdx == current().row and editor.cursorVisible and not isTextSelected then
                local cursorX = MARGIN_LEFT + gc:getStringWidth(lineText:sub(1, current().col))
                gc:setColorRGB(c("codeH",1),c("codeH",2),c("codeH",3))
                gc:fillRect(cursorX, yPos + 1, 1, LINE_HEIGHT - 1)
            end
            if lineIdx == current().row and autocompleteHint ~= "" and not isTextSelected then
    local cursorX = MARGIN_LEFT + gc:getStringWidth(lineText:sub(1, current().col))
    
    if editor.currentTheme == 2 then
        gc:setColorRGB(90, 90, 90)
    else
        gc:setColorRGB(160, 160, 160)
    end
    
    gc:drawString(autocompleteHint, cursorX, yPos, "top")
end

        end
    end
    if #current().lines > VISIBLE_LINES then
        local trackHeight = SCREEN_HEIGHT - MARGIN_TOP - 4
        local thumbHeight = math.max(15, math.floor((VISIBLE_LINES / #current().lines) * trackHeight))
        local scrollPercentage = (current().scrollRow - 1) / (#current().lines - VISIBLE_LINES)
        local thumbY = MARGIN_TOP + math.floor(scrollPercentage * (trackHeight - thumbHeight))
        gc:setColorRGB(c("scrollTrack",1),c("scrollTrack",2),c("scrollTrack",3))
        gc:fillRect(SCREEN_WIDTH - SCROLLBAR_WIDTH - 2, MARGIN_TOP, SCROLLBAR_WIDTH, trackHeight)
        gc:setColorRGB(c("scrollThumb",1),c("scrollThumb",2),c("scrollThumb",3))
        gc:fillRect(SCREEN_WIDTH - SCROLLBAR_WIDTH - 2, thumbY, SCROLLBAR_WIDTH, thumbHeight)
    end
    Prompt.paint(gc)
    Menu.draw(gc)
end

function on.tabKey()
    local doc = current()
    local currentText = doc.lines[doc.row] or ""
    local left = string.sub(currentText, 1, doc.col)
    local right = string.sub(currentText, doc.col + 1)
    
    if autocompleteHint ~= "" then
        doc.lines[doc.row] = left .. autocompleteHint .. right
        doc.col = doc.col + string.len(autocompleteHint)
        autocompleteHint = ""
        platform.window:invalidate()
        return
    end

    doc.lines[doc.row] = left .. "    " .. right
    doc.col = doc.col + 4
    platform.window:invalidate()
end


function on.charIn(char)
    if Prompt.charIn(char) then return end
    deleteSelectedText()
    
    local character = char
    local doc = current()
    local currentText = doc.lines[doc.row] or ""
    local left = string.sub(currentText, 1, doc.col)
    local right = string.sub(currentText, doc.col + 1)
    
    if char == "^2" then character = ":" end
    if char == "exp(" then character = "[" end
    if char == "10^(" then character = "]" end
    if char == "ln(" then character = "{" end
    if char == "log(" then character = "}" end
    
    local nextChar = string.sub(right, 1, 1)
    if (character == ")" or character == "]" or character == "}" or character == '"') and nextChar == character then
        doc.col = doc.col + 1
        autocompleteHint = ""
        platform.window:invalidate()
        return
    end

    local closingPair = ""
    if character == "(" then closingPair = ")"
    elseif character == "[" then closingPair = "]"
    elseif character == "{" then closingPair = "}"
    elseif character == '"' then closingPair = '"'
    end
    
    local newLeft = left .. character
    doc.lines[doc.row] = newLeft .. closingPair .. right
    doc.col = doc.col + string.len(character)
    
    local leadingSpaces, keyword = string.match(newLeft, "^(%s*)([eE][nN][dD])$")
    if not keyword then leadingSpaces, keyword = string.match(newLeft, "^(%s*)([eE][lL][sS][eE])$") end
    if not keyword then leadingSpaces, keyword = string.match(newLeft, "^(%s*)([eE][lL][sS][eE][iI][fF])$") end
    
    if keyword and string.len(leadingSpaces) >= 4 then
        local strippedSpaces = string.sub(leadingSpaces, 1, -5)
        doc.lines[doc.row] = strippedSpaces .. keyword .. closingPair .. right
        doc.col = string.len(strippedSpaces) + string.len(keyword)
    end
    
    local currentWord = string.match(doc.lines[doc.row]:sub(1, doc.col), "([%w_.:]+)$")
    autocompleteHint = "" 
    if currentWord and currentWord ~= "" then
        local lastSegment = string.match(currentWord, "([%w_]+)$")
        local prefix
        
        if lastSegment then
            prefix = string.sub(currentWord, 1, string.len(currentWord) - string.len(lastSegment))
        else
            lastSegment = ""
            prefix = currentWord
        end
        
        local keywords = {
            "assert", "collectgarbage", "error", "_G", "getfenv", "getmetatable", "ipairs", "load", "loadstring", "next", "pairs", "pcall", "print", "rawequal", "rawget", "rawset", "select", "setfenv", "setmetatable", "tonumber", "tostring", "type", "unpack", "_VERSION", "xpcall", "coroutine.create", "coroutine.resume", "coroutine.running", "coroutine.status", "coroutine.wrap", "coroutine.yield", "string.byte", "string.char", "string.dump", "string.find", "string.format", "string.gmatch", "string.gsub", "string.len", "string.lower", "string.match", "string.rep", "string.reverse", "string.sub", "string.upper", "table.concat", "table.insert", "table.maxn", "table.remove", "table.sort", "math.abs", "math.acos", "math.asin", "math.atan", "math.atan2", "math.ceil", "math.cos", "math.cosh", "math.deg", "math.exp", "math.floor", "math.fmod", "math.frexp", "math.huge", "math.ldexp", "math.log", "math.log10", "math.max", "math.min", "math.modf", "math.pi", "math.pow", "math.rad", "math.random", "math.randomseed", "math.sin", "math.sinh", "math.sqrt", "math.tan", "math.tanh", "touch.ppi", "touch.xppi", "touch.yppi", "touch.enabled", "touch.isKeyboardAvailable", "touch.isKeyboardVisible", "touch.showKeyboard", "D2Editor.newRichText", "D2Editor:createChemBox", "D2Editor:createMathBox", "D2Editor:getExpression", "D2Editor:getExpressionSelection", "D2Editor:getText", "D2Editor:hasFocus", "D2Editor:isVisible", "D2Editor:move", "D2Editor:registerFilter", "D2Editor:resize", "D2Editor:setBorder", "D2Editor:setBorderColor", "D2Editor:setColorable", "D2Editor:setDisable2DinRT", "D2Editor:setExpression", "D2Editor:setFocus", "D2Editor:setFontSize", "D2Editor:setMainFont", "D2Editor:setReadOnly", "D2Editor:setSelectable", "D2Editor:setSizeChangeListener", "D2Editor:setText", "D2Editor:setTextChangeListener", "D2Editor:setTextColor", "D2Editor:setVisible", "D2Editor:setWordWrapWidth", "class", "clipboard.addText", "clipboard.getText", "cursor.set", "cursor.hide", "cursor.show", "document.markChanged", "on.activate", "on.arrowDown", "on.arrowKey", "on.arrowLeft", "on.arrowRight", "on.arrowUp", "on.charIn", "on.backspaceKey", "on.backTabKey", "on.clearKey", "on.construction", "on.contextMenu", "on.copy", "on.create", "on.createMathBox", "on.cut", "on.deactivate", "on.deleteKey", "on.destroy", "on.enterKey", "on.escapeKey", "on.getFocus", "on.getSymbolList", "on.grabDown", "on.grabUp", "on.help", "on.keyboardDown", "on.keyboardUp", "on.loseFocus", "on.mouseDown", "on.mouseMove", "on.mouseUp", "on.paint", "on.paste", "on.propertiesChanged", "on.resize", "on.restore", "on.returnKey", "on.rightMouseDown", "on.rightMouseUp", "on.save", "on.tabKey", "on.timer", "on.varChange", "image.new", "image:copy", "image:height", "image:rotate", "image:width", "locale.name", "math.eval", "math.evalStr", "math.getEvalSettings", "math.setEvalSettings", "platform.apiLevel", "platform.hw", "platform.isColorDisplay", "platform.isDeviceModeRendering", "platform.isTabletModeRendering", "platform.registerErrorHandler", "platform.window.height", "platform.window.width", "platform.window.invalidate", "platform.window.setBackgroundColor", "platform.window.setFocus", "platform.window.getScrollHeight", "platform.window.setScrollHeight", "platform.window.displayInvalidatedRectangles", "platform.withGC", "platform.getDeviceID", "string.split", "string.uchar", "string.usub", "string.pack", "string.unpack", "timer.getMilliSecCounter", "timer.start", "timer.stop", "toolpalette.register", "toolpalette.enable", "toolpalette.enableCut", "toolpalette.enableCopy", "toolpalette.enablePaste", "var.list", "var.makeNumericList", "var.monitor", "var.recall", "var.recallAt", "var.recallStr", "var.store", "var.storeAt", "var.unmonitor", "physics.INFINITY", "physics.momentForBox", "physics.momentForCircle", "physics.momentForPoly", "physics.momentForSegment", "physics.Vect", "physics.Vect:add", "physics.Vect:clamp", "physics.Vect:cross", "physics.Vect:dist", "physics.Vect:distsq", "physics.Vect:dot", "physics.Vect:eql", "physics.Vect:length", "physics.Vect:lengthsq", "physics.Vect:lerp", "physics.Vect:lerpconst", "physics.Vect:mult", "physics.Vect:near", "physics.Vect:neg", "physics.Vect:normalize", "physics.Vect:normalizeSafe", "physics.Vect:perp", "physics.Vect:project", "physics.Vect:rotate", "physics.Vect:rperp", "physics.Vect:setx", "physics.Vect:sety", "physics.Vect:slerp", "physics.Vect:slerpconst", "physics.Vect:sub", "physics.Vect:toangle", "physics.Vect:unrotate", "physics.Vect:x", "physics.Vect:y", "physics.BB", "physics.BB:b", "physics.BB:clampVect", "physics.BB:containsBB", "physics.BB:containsVect", "physics.BB:expand", "physics.BB:intersects", "physics.BB:l", "physics.BB:merge", "physics.BB:setb", "physics.BB:r", "physics.BB:setl", "physics.BB:setr", "physics.BB:sett", "physics.BB:t", "physics.BB:wrapVect", "physics.Body", "physics.Body:activate", "physics.Body:angle", "physics.Body:angVel", "physics.Body:applyForce", "physics.Body:applyImpulse", "physics.Body:data", "physics.Body:force", "physics.Body:isRogue", "physics.Body:isSleeping", "physics.Body:local2World", "physics.Body:kineticEnergy", "physics.Body:mass", "physics.Body:moment", "physics.Body:pos", "physics.Body:resetForces", "physics.Body:rot", "physics.Body:setAngle", "physics.Body:setAngVel", "physics.Body:setData", "physics.Body:setForce", "physics.Body:setMass", "physics.Body:setMoment", "physics.Body:setPos", "physics.Body:setPositionFunc", "physics.Body:setTorque", "physics.Body:setVel", "physics.Body:setVelocityFunc", "physics.Body:setVLimit", "physics.Body:setWLimit", "physics.Body:sleep", "physics.Body:sleepWithGroup", "physics.Body:torque", "physics.Body:updatePosition", "physics.Body:updateVelocity", "physics.Body:vel", "physics.Body:vLimit", "physics.Body:wLimit", "physics.Body:world2Local", "physics.Shape:BB", "physics.Shape:body", "physics.Shape:collisionType", "physics.Shape:data", "physics.Shape:friction", "physics.Shape:group", "physics.Shape:layers", "physics.Shape:rawBB", "physics.Shape:restitution", "physics.Shape:sensor", "physics.Shape:setCollisionType", "physics.Shape:setData", "physics.Shape:setFriction", "physics.Shape:setGroup", "physics.Shape:setLayers", "physics.Shape:setRestitution", "physics.Shape:setSensor", "physics.Shape:setSurfaceV", "physics.Shape:surfaceV", "physics.CircleShape", "physics.CircleShape:offset", "physics.CircleShape:radius", "physics.PolyShape", "physics.PolyShape:numVerts", "physics.PolyShape:points", "physics.PolyShape:vert", "physics.SegmentShape", "physics.SegmentShape:a", "physics.SegmentShape:b", "physics.SegmentShape:normal", "physics.SegmentShape:radius", "physics.Space", "physics.Space:addBody", "physics.Space:addConstraint", "physics.Space:addCollisionHandler", "physics.Space:addPostStepCallback", "physics.Space:addShape", "physics.Space:addStaticShape", "physics.Space:damping", "physics.Space:data", "physics.Space:elasticIterations", "physics.Space:gravity", "physics.Space:idleSpeedThreshold", "physics.Space:iterations", "physics.Space:rehashShape", "physics.Space:rehashStatic", "physics.Space:removeBody", "physics.Space:removeConstraint", "physics.Space:removeShape", "physics.Space:removeStaticShape", "physics.Space:resizeActiveHash", "physics.Space:resizeStaticHash", "physics.Space:setDamping", "physics.Space:setData", "physics.Space:setElasticIterations", "physics.Space:setGravity", "physics.Space:setIdleSpeedThreshold", "physics.Space:setIterations", "physics.Space:setSleepTimeThreshold", "physics.Space:sleepTimeThreshold", "physics.Space:step", "physics.Constraint:Damped Rotary Spring", "physics.Constraint:Damped Spring", "physics.Constraint:Gear Joint", "physics.Constraint:Groove Joint", "physics.Constraint:Pin Joint", "physics.Constraint:Pivot Joint", "physics.Constraint:Ratchet Joint", "physics.Constraint:Rotary Limit Joint", "physics.Constraint:Simple Motor", "physics.Constraint:Slide Joints", "physics.Arbiter:#", "physics.Arbiter:a", "physics.Arbiter:b", "physics.Arbiter:bodies", "physics.Arbiter:depth", "physics.Arbiter:elasticity", "physics.Arbiter:friction", "physics.Arbiter:impulse", "physics.Arbiter:isFirstContact", "physics.Arbiter:normal", "physics.Arbiter:point", "physics.Arbiter:setElasticity", "physics.Arbiter:setFriction", "physics.Arbiter:shapes", "physics.Arbiter:totalImpulse", "physics.Arbiter:totalImpulseWithFriction", "physics.Space:pointQuery", "physics.Space:segmentQuery", "physics.Space:pointQueryFirst", "physics.Space:segmentQueryFirst", "physics.SegmentQueryInfo:hitDist", "physics.SegmentQueryInfo:hitPoint", "bluetooth.LE.addStateListener", "bluetooth.LE.removeStateListener", "bluetooth.LE.pack", "bluetooth.LE.unpack", "bluetooth.LE.Central.startScanning", "bluetooth.LE.Central.stopScanning", "bluetooth.LE.Central.isScanning", "bluetooth.Peripheral:getName", "bluetooth.Peripheral:getState", "bluetooth.Peripheral:connect", "bluetooth.Peripheral:disconnect", "bluetooth.Peripheral:discoverServices", "bluetooth.Peripheral:getServices", "bluetooth.Service:getUUID", "bluetooth.Service:discoverCharacteristics", "bluetooth.Service:getCharacteristics", "bluetooth.Characteristic:getUUID", "bluetooth.Characteristic:setValueUpdateListener", "bluetooth.Characteristic:setWriteCompleteListener", "bluetooth.Characteristic:read", "bluetooth.Characteristic:setNotify", "bluetooth.Characteristic:getValue", "bluetooth.Characteristic:write", "asi.require", "asi.addStateListener", "asi.removeStateListener", "asi.isScanning", "asi.startScanning", "asi.stopScanning", "asi.Port:getName", "asi.Port:getIdentifier", "asi.Port:getState", "asi.Port:setBaudRate", "asi.Port:connect", "asi.Port:disconnect", "asi.Port:setWriteListener", "asi.Port:write", "asi.Port:setReadListener", "asi.Port:setReadTimeout", "asi.Port:read", "asi.Port:getValue", "gc:clipRect", "gc:drawArc", "gc:drawImage", "gc:drawLine", "gc:drawPolyLine", "gc:drawRect", "gc:drawString", "gc:fillArc", "gc:fillPolygon", "gc:fillRect", "gc:getStringHeight", "gc:getStringWidth", "gc:setColorRGB", "gc:setFont", "gc:setPen"
        }
                for _, kw in ipairs(keywords) do
            if string.sub(kw, 1, string.len(prefix)) == prefix then
                local kwSegment = string.sub(kw, string.len(prefix) + 1)
                
                if lastSegment == "" or (string.sub(kwSegment, 1, string.len(lastSegment)) == lastSegment and kwSegment ~= lastSegment) then
                    autocompleteHint = string.sub(kwSegment, string.len(lastSegment) + 1)
                    autocompleteFullWord = kw
                    autocompleteMatchLen = string.len(currentWord)
                    break
                end
            end
        end
    end
end



function on.enterKey()
    if Menu.enter() then return end
    if Prompt.enter() then return end
    deleteSelectedText()
    
    autocompleteHint = ""
    
    local doc = current()
    local currentText = doc.lines[doc.row] or ""
    local left = string.sub(currentText, 1, doc.col)
    local right = string.sub(currentText, doc.col + 1)
    local leadingSpaces = string.match(left, "^(%s*)") or ""
    local trimmedLeft = string.gsub(left, "%s*$", "")
    
    if string.match(trimmedLeft, "%f[%w]then$") or 
       string.match(trimmedLeft, "%f[%w]do$") or 
       string.match(trimmedLeft, "%f[%w]function%s*%b()$") or 
       string.match(trimmedLeft, "%f[%w]function%s*[%w_.:]*%s*%b()$") or
       string.match(trimmedLeft, "%f[%w]repeat$") or 
       string.match(trimmedLeft, "%f[%w]else$") or 
       string.match(trimmedLeft, "%f[%w]elseif%s.*$") then
        leadingSpaces = leadingSpaces .. "    "
    end
    
    doc.lines[doc.row] = left
    table.insert(doc.lines, doc.row + 1, leadingSpaces .. right)
    doc.row = doc.row + 1
    doc.col = string.len(leadingSpaces)
    
    scrollIntoView()
    platform.window:invalidate()
end


function on.backspaceKey()
    if Prompt.backspace() then return end
    if deleteSelectedText() then
        autocompleteHint = ""
        scrollIntoView()
        platform.window:invalidate()
        return
    end
    
    local doc = current()
    local currentText = doc.lines[doc.row] or ""
    if doc.col > 0 then
        local left = string.sub(currentText, 1, doc.col)
        local right = string.sub(currentText, doc.col + 1)
        if string.match(left, "^%s+$") and string.len(left) % 4 == 0 then
            left = string.sub(left, 1, -5)
            doc.lines[doc.row] = left .. right
            doc.col = doc.col - 4
        else
            left = string.sub(currentText, 1, doc.col - 1)
            doc.lines[doc.row] = left .. right
            doc.col = doc.col - 1
        end
    elseif doc.row > 1 then
        local prevText = doc.lines[doc.row - 1] or ""
        doc.col = string.len(prevText)
        doc.lines[doc.row - 1] = prevText .. currentText
        table.remove(doc.lines, doc.row)
        doc.row = doc.row - 1
    end
    
    local currentWord = string.match(doc.lines[doc.row]:sub(1, doc.col), "([%w_.:]+)$")
    autocompleteHint = ""
    if currentWord and currentWord ~= "" then
        local keywords = {
            "function", "local", "return", "if", "then", "else", "elseif", 
            "end", "for", "while", "do", "repeat", "until", "break", "true", "false", "nil"
        }
        for _, kw in ipairs(keywords) do
            if string.sub(kw, 1, string.len(currentWord)) == currentWord and kw ~= currentWord then
                autocompleteHint = string.sub(kw, string.len(currentWord) + 1)
                break
            end
        end
    end
    
    scrollIntoView()
    platform.window:invalidate()
end


function on.arrowKey(direction)
    if Prompt.active then return end
    if Menu.active then
        if direction == "up" then 
            Menu.arrowUp() 
        elseif direction == "down" then 
            Menu.arrowDown() 
        end
        return
    end
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
    if not isTextSelected then
        clipboard.setText(doc.lines[doc.row] or "")
        return
    elseif doc.row == selAnchorLine and doc.col == selAnchorCol then
        return
    end

    local startLine, startCol, endLine, endCol
    if doc.row < selAnchorLine or (doc.row == selAnchorLine and doc.col < selAnchorCol) then
        startLine, startCol = doc.row, doc.col
        endLine, endCol = selAnchorLine, selAnchorCol
    else
        startLine, startCol = selAnchorLine, selAnchorCol
        endLine, endCol = doc.row, doc.col
    end

    local copiedText = ""
    if startLine == endLine then
        local lineText = doc.lines[startLine] or ""
        copiedText = string.sub(lineText, startCol + 1, endCol)
    else
        local firstLineText = doc.lines[startLine] or ""
        copiedText = string.sub(firstLineText, startCol + 1) .. "\n"
        
        for i = startLine + 1, endLine - 1 do
            copiedText = copiedText .. (doc.lines[i] or "") .. "\n"
        end
        
        local lastLineText = doc.lines[endLine] or ""
        copiedText = copiedText .. string.sub(lastLineText, 1, endCol)
    end

    clipboard.addText(copiedText)
end


function on.paste()
    local pasteText = clipboard.getText()
    if not pasteText or pasteText == "" then return end
    
    local doc = current()
    local currentText = doc.lines[doc.row] or ""
    local left = string.sub(currentText, 1, doc.col)
    local right = string.sub(currentText, doc.col + 1)
    
    local pastedLines = {}
    for line in string.gmatch(pasteText, "[^\r\n]+") do
        table.insert(pastedLines, line)
    end
    
    if #pastedLines == 0 then
        table.insert(pastedLines, "")
    end
    
    if #pastedLines <= 1 then
        doc.lines[doc.row] = left .. pasteText .. right
        doc.col = doc.col + string.len(pasteText)
    else
        pastedLines = left .. pastedLines
        local lastLineIdx = #pastedLines
        local targetCol = string.len(pastedLines[lastLineIdx])
        pastedLines[lastLineIdx] = pastedLines[lastLineIdx] .. right
        
        doc.lines[doc.row] = pastedLines
        for i = 2, lastLineIdx do
            table.insert(doc.lines, doc.row + i - 1, pastedLines[i])
        end
        doc.row = doc.row + lastLineIdx - 1
        doc.col = targetCol
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
    saveCustomThemes()
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
