# nIDE
A simple on-calc editor for TI-Nspire Lua. Has several features in v0.1 like a tab system, light syntax highlighting, and more!
- Syntax highlighting
- Tab system to keep track of all your code
- Save and load files!
- Run your code including a terminal for print() calls
- Rename tabs/files
- An editor outside of 2DEditor library
- Click ctrl+menu to save your code to the runner app! Then run your script!
- x^2 for :
- e^x and 10^x for [ and ] respectively
- ln( and log( for { and } respectively
- Autocompletion
- Themes
- Support for plugins
- Libraries, a missing feature in Nspire Lua
<img width="320" height="240" alt="nIDE3" src="https://github.com/user-attachments/assets/4fedbf3d-fb7f-4fd6-8127-b3fbf51016d0" />
<img width="320" height="240" alt="nIDE1" src="https://github.com/user-attachments/assets/7179c2a8-3f77-4a93-bba3-add9fe55f0af" />
<img width="320" height="240" alt="nIDE2" src="https://github.com/user-attachments/assets/2dc40418-d351-4b33-96a5-315a26a04acb" />

# Plugins

The plugins system was added in nIDE v1.1, and here are docs and samples!
For example, here is how you add a menu function to remove whitespace from the end of lines and format text: 

```lua
return {
    name = "AutoFormatter",
    author = "yourname",
    version = "1.0",
    onInit = function(ed)
        --Sets a direct editor variable
        ed.shouldWrap = true
    end,
    --How you add menu functions, which will appear in Plugins
    actions = {
        {
            --Label in the menu, activated through the menu key
            label = "Format Current Document",
                --What the menu action does
                fn = function()
                  local doc = current()
                  for i, lineText in ipairs(doc.lines) do
                    doc.lines[i] = lineText:gsub("%s+$", "")
                end
                platform.window:invalidate()
            end
        }
    }
}
```
Here is a theme pack example:
```lua
return {
    name = "NeonTheme",
    author = "yourname",
    version = "1.0",
    themePacks = {
        ["Neon Theme"] = {
            bg = {10, 10, 15},
            activeTab = {20, 20, 30},
            activeTabText = {255, 0, 128},
            inactiveTab = {15, 15, 20},
            inactiveTabText = {0, 255, 255},
            newTabBackground = {25, 25, 35},
            newTabBorders = {255, 0, 128},
            scrollTrack = {10, 10, 15},
            scrollThumb = {0, 255, 255},
            selectColor = {255, 255, 0},
            closeTab = {255, 0, 0},
            promptBg = {20, 20, 30},
            activeRow = {30, 30, 45},
            menuScrollTrack = {15, 15, 20},
            menuScrollThumb = {255, 0, 128},
            keywordsH = {255, 0, 128},
            boolnilH = {255, 255, 0},
            stdlibH = {0, 255, 255},
            codeH = {240, 240, 240}
        }
    }
}
```
And here are snippet examples:
```lua
return {
    name = "SnippetDemo",
    author = "yourname",
    version = "1.1",
    snippets = {
        "function new_component()",
        "local my_instance = {}",
        "return my_instance"
    }
}
```
Now more useful in case you package a plugin with a library, but still not super useful. Still can be helpful for larger codebases!
# Libraries

Use 
```lua
libvar = iderequire("docname")
```
to use functions of another tab or saved program from the active tab! Follow that simple syntax. For example, here is a geometry library:
```lua
local geom = {}

function geom.area(width, height)
    return width * height
end

function geom.perimeter(width, height)
    return (width + height) * 2
end

return geom
```
and you can call its functions through this!
```lua
local geo = iderequire("geom")
print(geo.area(5, 10))
print(geo.perimeter(5, 10))
```

Please enjoy the extension to the language itself, in the latest versions of nIDE, with new support for a missing lua feature, require!
