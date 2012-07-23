local c = game.Workspace.Terrain
local WorldToCellPreferEmpty = c.WorldToCellPreferEmpty
local WorldToCellPreferSolid = c.WorldToCellPreferSolid
local GetCell = c.GetCell
local SetCell = c.SetCell
local AutoWedge = c.AutowedgeCells

-----------------
--DEFAULT VALUES-
-----------------
loaded = false
on = false

DefaultTerrainMaterial = 1


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
toolbarbutton = toolbar:CreateButton("", "Builder", "builder.png")
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
		
		c = game.Workspace.Terrain
		
		local cellPos = WorldToCellPreferEmpty(c, Vector3.new(mouse.Hit.x, mouse.Hit.y, mouse.Hit.z))
		local x = cellPos.x
		local y = cellPos.y
		local z = cellPos.z

		local solidCellPos = WorldToCellPreferSolid(c, Vector3.new(mouse.Hit.x, mouse.Hit.y, mouse.Hit.z))

		local celMat = GetCell(c, solidCellPos.x, solidCellPos.y, solidCellPos.z)
		if celMat.Value > 0 then DefaultTerrainMaterial = celMat.Value end

		SetCell(c, x, y, z, DefaultTerrainMaterial, 0, 0)
		AutoWedge(c, Region3int16.new(Vector3int16.new(x - 1, y - 1, z - 1), Vector3int16.new(x + 1, y + 1, z + 1)))
		print("Block built at: "..x..", "..y..", "..z)
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
print("Builder Plugin Loaded")