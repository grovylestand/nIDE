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

code1 = ""
function on.timer()
   code2 = var.recall("nidecurcode") or ""
   if code1 ~= code2 then
      code1 = code2
      pcall(loadstring(code1))
      platform.window:invalidate()
   end 
end
timer.start(1)
function on.charIn(ch)
    if ch == "r" then
        clearScreenRequested = true
        
        platform.window:invalidate() 
    end
end
function on.paint(gc)
    if clearScreenRequested then
        gc:setColorRGB(255, 255, 255)
        
        local w = platform.window:width()
        local h = platform.window:height()
        
        code1=""
        platform.window:invalidate() 
    else
    end
end
