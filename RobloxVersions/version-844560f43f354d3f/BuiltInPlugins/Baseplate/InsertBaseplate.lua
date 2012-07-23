self = PluginManager():CreatePlugin()

toolbar = self:CreateToolbar("InsertObject")

toolbarbutton = toolbar:CreateButton("","Inserts Baseplate","bl.png")

toolbarbutton.Click:connect(function()

base = Instance.new("Part",Workspace)
base.Name = "Baseplate"
base.Size = Vector3.new(550,1,550)
base.Anchored = true
base.BrickColor = BrickColor.new("Bright green")
base.TopSurface = "Universal"
base.BottomSurface = "Universal"
base.Locked = true

end)

