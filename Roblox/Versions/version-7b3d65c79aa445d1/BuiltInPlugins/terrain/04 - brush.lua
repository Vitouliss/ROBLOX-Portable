-- Local function definitions
local c = game.Workspace.Terrain
local SetCell = c.SetCell
local GetCell = c.GetCell
local WorldToCellPreferSolid = c.WorldToCellPreferSolid
local AutoWedge = c.AutowedgeCell


-----------------
--DEFAULT VALUES-
-----------------
loaded = false
on = false
r = 5
d = 0
mousedown = false

DefaultTerrainMaterial = 1


---------------
--PLUGIN SETUP-
---------------
self = PluginManager():CreatePlugin()
self.Deactivation:connect(function()
	Off()
end)

toolbar = self:CreateToolbar("Terrain")
toolbarbutton = toolbar:CreateButton("", "Terrain Brush", "brush.png")
toolbarbutton.Click:connect(function()
	if on then
		Off()
	elseif loaded then
		On()
	end
end)

mouse = self:GetMouse()
mouse.Button1Down:connect(function()
	onClicked(mouse)
end)
mouse.Button1Up:connect(function() mousedown = false end)



-----------------------
--FUNCTION DEFINITIONS-
-----------------------

--makes a column of blocks from 1 up to height at location (x,z) in cluster c
--if add is true, blocks below height will be added
--if clear is true, blocks above height will be cleared
function coordHeight(x, z, height, add, clear)
	if add then
		for h = 1, height do
			SetCell(c, x, h, z, DefaultTerrainMaterial, 0, 0)
		end
	end
	if clear then
		ysize = c.MaxExtents.Max.Y
		for h = height + 1, ysize - 1 do
			SetCell(c, x, h, z, 0, 0, 0)
		end
	end
end


--find height at coordinate x, z
function getHeight(x, z)
	h = 0
	material, wedge, rotation = GetCell(c, x, h + 1, z)
	while material.Value > 0 do
		h = h + 1
		material, wedge, rotation = GetCell(c, x, h + 1, z)
	end
	return h
end


function dist(x1, y1, x2, y2)
	return math.sqrt(math.pow(x2-x1, 2) + math.pow(y2-y1, 2))
end


function dist3d(x1, y1, z1, x2, y2, z2)
	return math.sqrt(math.pow(dist(x1, z1, x2, z2), 2) + math.pow(math.abs(y2-y1)*100/d, 2))
end



--brushes terrain at point (x, y, z) in cluster c
function brush(x, y, z, r, d)
	for i = x - (r + 3), x + (r + 3) do
		for k = z - (r + 3), z + (r + 3) do

			if d >= 0 then
				inc = 1
				material = 1
				heightoffset = 0
				add = true
			else
				inc = -1
				material = 0
				heightoffset = 1
				add = false
			end

			heightmapi = heightmap[i]
			if heightmapi then
				heightmapik = heightmapi[k]
			else
				heightmap[i] = {}
			end

			if dist(x, z, i, k) < r then
				coordHeight(i, k, y + d, add, not add)
			end

			heightmap[i][k] = getHeight(i, k)

		end
	end

	for ri = 0, r + 2 do
		i = x - ri
		for k = z - (r + 2), z + (r + 2) do
			height = heightmap[i][k]
			if height == nil then
				height = -1
			end
			for h = height, 1, -1 do
				if not AutoWedge(c, i, h, k) then
					break
				end
			end
		end

		i = x + ri
		for k = z - (r + 2), z + (r + 2) do
			height = heightmap[i][k]
			if height == nil then
				height = -1
			end
			for h = height, 1, -1 do
				if not AutoWedge(c, i, h, k) then
					break
				end
			end
		end
	end

	wait(0)

end


function onClicked(mouse)
	if on then
		heightmap = {}
		mousedown = true
		brushheight = nil

		local firstCellPos = WorldToCellPreferSolid(c, Vector3.new(mouse.Hit.x, mouse.Hit.y, mouse.Hit.z))
		local celMat = GetCell(c, firstCellPos.x, firstCellPos.y, firstCellPos.z)
		if celMat.Value > 0 then DefaultTerrainMaterial = celMat.Value end

		while mousedown == true do
			local cellPos = WorldToCellPreferSolid(c, Vector3.new(mouse.Hit.x, mouse.Hit.y, mouse.Hit.z))
			local x = cellPos.x
			local y = cellPos.y
			local z = cellPos.z

			if brushheight == nil then
				brushheight = y
			end
			brush(x, brushheight, z, r, d)
			print("Brushed at: "..x..", "..brushheight..", "..z)
		end

	end
end

function On()
	self:Activate(true)
	toolbarbutton:SetActive(true)
	frame.Visible = true
	for w = 0, 0.3, 0.06 do
		frame.Size = UDim2.new(w, 0, w/2, 0)
		wait(0.0000001)
	end
	radl.Text = "Radius: "..r
	dfl.Text = "Height: "..d
	on = true
end

function Off()
	toolbarbutton:SetActive(false)
	radl.Text = ""
	dfl.Text = ""
	for w = 0.3, 0, -0.06 do
		frame.Size = UDim2.new(w, 0, w/2, 0)
		wait(0.0000001)
	end
	frame.Visible = false
	on = false
end




------
--GUI-
------

--load library for with sliders
local RbxGui = LoadLibrary("RbxGui")

--screengui
g = Instance.new("ScreenGui", game:GetService("CoreGui"))

--frame
frame = Instance.new("Frame", g)
frame.Position = UDim2.new(0.35, 0, 0.8, 0)
frame.Size = UDim2.new(0.3, 0, 0.15, 0)
frame.BackgroundTransparency = 0.5
frame.Visible = false

--current radius display label
radl = Instance.new("TextLabel", frame)
radl.Position = UDim2.new(0.05, 0, 0.1, 0)
radl.Size = UDim2.new(0.2, 0, 0.35, 0)
radl.Text = ""
radl.BackgroundColor3 = Color3.new(0.4, 0.4, 0.4)
radl.TextColor3 = Color3.new(0.95, 0.95, 0.95)
radl.Font = Enum.Font.ArialBold
radl.FontSize = Enum.FontSize.Size14
radl.BorderColor3 = Color3.new(0, 0, 0)
radl.BackgroundTransparency = 1

--radius slider
radSliderGui, radSliderPosition = RbxGui.CreateSlider(5, 0, UDim2.new(0.3, 0, 0.26, 0))
radSliderGui.Parent = frame
radBar = radSliderGui:FindFirstChild("Bar")
radBar.Size = UDim2.new(0.65, 0, 0, 5)
radSliderPosition.Value = r - 1
radSliderPosition.Changed:connect(function()
	r = radSliderPosition.Value + 1
	radl.Text = "Radius: "..r
end)

--current depth factor display label
dfl = Instance.new("TextLabel", frame)
dfl.Position = UDim2.new(0.05, 0, 0.55, 0)
dfl.Size = UDim2.new(0.2, 0, 0.35, 0)
dfl.Text = ""
dfl.BackgroundColor3 = Color3.new(0.4, 0.4, 0.4)
dfl.TextColor3 = Color3.new(0.95, 0.95, 0.95)
dfl.Font = Enum.Font.ArialBold
dfl.FontSize = Enum.FontSize.Size14
dfl.BorderColor3 = Color3.new(0, 0, 0)
dfl.BackgroundTransparency = 1

--depth factor slider
dfSliderGui, dfSliderPosition = RbxGui.CreateSlider(63, 0, UDim2.new(0.3, 0, 0.71, 0))
dfSliderGui.Parent = frame
dfBar = dfSliderGui:FindFirstChild("Bar")
dfBar.Size = UDim2.new(0.65, 0, 0, 5)
dfSliderPosition.Value = d + 32
dfSliderPosition.Changed:connect(function()
	d = dfSliderPosition.Value - 32
	dfl.Text = "Height: "..d
end)




--------------------------
--SUCCESSFUL LOAD MESSAGE-
--------------------------
loaded = true
print("Elevation Plugin Loaded")
