self = PluginManager():CreatePlugin()

toolbar = self:CreateToolbar("InsertObject")

toolbarbutton = toolbar:CreateButton("SpawnLocation","Inserts a Spawn","")

toolbarbutton.Click:connect(function()

local place = game:GetService("Workspace")

spawn = Instance.new("SpawnLocation",place)
spawn.Anchored = true
spawn.Duration = math.random(1,8)
spawn.Size = Vector3.new(5,1,5)
spawn.Position = Vector3.new(1,2,1)
spawn.TopSurface = "Smooth"

end)

