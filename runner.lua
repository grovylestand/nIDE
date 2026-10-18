_G.print = function(...)
    local args = {...}
    local str_pieces = {}
    for i = 1, #args do
        table.insert(str_pieces, tostring(args[i]))
    end
    local message = table.concat(str_pieces, "    ")
    
    local current_logs = var.recall("nidetermlog") or ""
    if current_logs ~= "" then
        current_logs = current_logs .. "\n" .. message
    else
        current_logs = message
    end
    var.store("nidetermlog", current_logs)
end

_G.ide_packages = _G.ide_packages or {}

_G.iderequire = function(filename)
    if _G.ide_packages[filename] then
        return _G.ide_packages[filename]
    end

    local codeStr = nil
    local varName = "nide_" .. filename
    local savedLines = var.recall(varName)

    if not savedLines or (type(savedLines) ~= "table" and type(savedLines) ~= "string") then
        savedLines = var.recall(filename)
    end

    if savedLines and type(savedLines) == "table" then
        codeStr = table.concat(savedLines, "\n")
    elseif type(savedLines) == "string" then
        codeStr = savedLines
    end

    if not codeStr or codeStr == "" then
        error("require: document variable '" .. filename .. "' not found or holds no code data.")
    end

    local chunk, err = loadstring(codeStr)
    if not chunk then
        error("require: syntax error in doc var '" .. filename .. "': " .. tostring(err))
    end

    local env = setmetatable({}, { __index = _G })
    setfenv(chunk, env)

    local status, result = pcall(chunk)
    if not status then
        error("require: runtime execution error in doc var '" .. filename .. "': " .. tostring(result))
    end

    if result == nil or type(result) ~= "table" then
        result = env
    end

    _G[filename] = nil
    
    _G.ide_packages[filename] = result
    return result
end

menu = {
    {"Script",
    {"Restart Script", function() 
        _G.ide_packages = {} 
        clearScreenRequested = true 
    end}}
}

local function loadcode(code)
    ERR = nil
    local chunk, errload = loadstring(code)
    if not chunk then
        ERR = errload
        print(ERR)
        platform.window:invalidate()
    else
        local status, errcall = pcall(chunk)
        if not status then
            ERR = errcall
            print(ERR)
        end
        platform.window:invalidate()
    end
end

toolpalette.register(menu)
code1 = ""
function on.timer()
   code2 = var.recall("nidecurcode") or ""
   if code1 ~= code2 then
      code1 = code2
      loadcode(code1)
      platform.window:invalidate()
   end 
end
timer.start(1)

function on.paint(gc)
    if clearScreenRequested then
        gc:setColorRGB(255, 255, 255)
        local w = platform.window:width()
        local h = platform.window:height()
        code1=""
        platform.window:invalidate() 
        clearScreenRequested=false
    end
end
