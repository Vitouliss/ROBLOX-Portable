self = PluginManager():CreatePlugin()

toolbar = self:CreateToolbar("InsertObject")

toolbarbutton = toolbar:CreateButton("Script","Inserts Server Script","")

toolbarbutton.Click:connect(function()

local names = {"InsertedScript","TheBestScript","Blah","Lua",
"Poopscript","LuaScript"}

local place = game:GetService("Workspace")

spawn = Instance.new("Script",place)
spawn.Disabled = true
spawn.Name = names[math.random(1,#names)]

end)

