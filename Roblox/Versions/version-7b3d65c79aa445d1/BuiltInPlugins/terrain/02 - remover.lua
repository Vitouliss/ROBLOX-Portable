local c = game.Workspace.Terrain
local WorldToCellPreferSolid = c.WorldToCellPreferSolid
local SetCell = c.SetCell
local AutoWedge = c.AutowedgeCells


-----------------
--DEFAULT VALUES-
-----------------
loaded = false
on = false



---------------
--PLUGIN SETUP-
---------------
self = PluginManager():CreatePlugin()
mouse = self:GetMouse()
mouse.Button1Down:connect(function() onClicked(mouse) end)
self.Deactivation:connect(function()
	Off()
end)
toolbar = self:CreateToolbar("Terrain")
toolbarbutton = toolbar:CreateButton("", "Remover", "remover.png")
toolbarbutton.Click:connect(function()
	if on then
		Off()
	elseif loaded then
		On()
	end
end)



-----------------------
--FUNCTION DEFINITIONS-
-----------------------

function onClicked(mouse)
	if on then		
		local cellPos = WorldToCellPreferSolid(c, Vector3.new(mouse.Hit.x, mouse.Hit.y, mouse.Hit.z))
		local x = cellPos.x
		local y = cellPos.y
		local z = cellPos.z		

		SetCell(c, x, y, z, 0, 0, 0)
		AutoWedge(c, Region3int16.new(Vector3int16.new(x - 1, y - 1, z - 1), Vector3int16.new(x + 1, y + 1, z + 1)))
		print("Block destroyed at: "..x..", "..y..", "..z)
	end
end

function On()
	self:Activate(true)
	toolbarbutton:SetActive(true)
	on = true
end

function Off()
	toolbarbutton:SetActive(false)
	on = false
end



------
--GUI-
------

--screengui
g = Instance.new("ScreenGui", game:GetService("CoreGui"))




--------------------------
--SUCCESSFUL LOAD MESSAGE-
--------------------------
loaded = true
print("Remover Plugin Loaded")