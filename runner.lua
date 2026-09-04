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
menu = {
    {"Script",
    {"Restart Script",function() clearScreenRequested=true end}}
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
    else
    end
end
