-- Local function definitions
local c = game.Workspace.Terrain
local SetCell = c.SetCell
local GetCell = c.GetCell
local WorldToCellPreferEmpty = c.WorldToCellPreferEmpty
local WorldToCellPreferSolid = c.WorldToCellPreferSolid
local AutoWedge = c.AutowedgeCell

-----------------
--DEFAULT VALUES-
-----------------
loaded = false
on = false
r = 20
d = 50

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
toolbarbutton = toolbar:CreateButton("", "Orb", "orbs.png")
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


--makes an orb at point (x, y, z) in cluster c
--d is the depth factor, a percent of the depth of a perfect sphere
function makeBall(x, y, z, r, d)
	local heightmap = {}
	for i = x - (r + 1), x + (r + 1) do
		heightmap[i] = {}
	end

	for j = 0, r + 1 do
		local cellschanged = false
		for i = x - (r + 1), x + (r + 1) do
			for k = z - (r + 1), z + (r + 1) do
				distance = math.sqrt(math.pow(dist(x, z, i, k), 2) + math.pow(j*(100/d), 2))
				if distance < r then
					SetCell(c, i, y - j, k, DefaultTerrainMaterial, 0, 1)
					SetCell(c, i, y + j, k, DefaultTerrainMaterial, 0, 1)
					cellschanged = true
					heightmap[i][k] = y + j
				elseif heightmap[i][k] == nil then
					heightmap[i][k] = getHeight(i, k)
				end
			end
		end
		if cellschanged == false then
			break
		end
		wait(0)
	end

	for ri = 0, r do
		wait(0)

		i = x - ri
		for k = z - r, z + r do
			height = heightmap[i][k]
			if height == nil then
				height = -1
			end
			for h = height, 0, -1 do
				if not AutoWedge(c, i, h, k) then
					break
				end
			end
		end

		i = x + ri
		for k = z - r, z + r do
			height = heightmap[i][k]
			if height == nil then
				height = -1
			end
			for h = height, 0, -1 do
				if not AutoWedge(c, i, h, k) then
					break
				end
			end
		end

	end

end


function dist(x1, y1, x2, y2)
	return math.sqrt(math.pow(x2-x1, 2) + math.pow(y2-y1, 2))
end

local debounce = false
function onClicked(mouse)
	if on and not debounce then
		debounce = true

		local cellPos = WorldToCellPreferEmpty(c, Vector3.new(mouse.Hit.x, mouse.Hit.y, mouse.Hit.z))
		local x = cellPos.x
		local y = cellPos.y
		local z = cellPos.z

		local cellPosSolid = WorldToCellPreferSolid(c, Vector3.new(mouse.Hit.x, mouse.Hit.y, mouse.Hit.z))
		local celMat = GetCell(c, cellPosSolid.x, cellPosSolid.y, cellPosSolid.z)
		if celMat.Value > 0 then DefaultTerrainMaterial = celMat.Value end

		makeBall(x, y, z, r, d)
		print("Orb created at: "..x..", "..y..", "..z)
		debounce = false
	end
end

function On()
	self:Activate(true)
	toolbarbutton:SetActive(true)
	frame.Visible = true
	for w = 0, 0.3, 0.06 do
		frame.Size = UDim2.new(w, 0, w/2, 0)
		wait(0)
	end
	radl.Text = "Radius: "..r
	dfl.Text = "Height: "..d.."%"
	on = true
end

function Off()
	toolbarbutton:SetActive(false)
	radl.Text = ""
	dfl.Text = ""
	for w = 0.3, 0, -0.06 do
		frame.Size = UDim2.new(w, 0, w/2, 0)
		wait(0)
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
radSliderGui, radSliderPosition = RbxGui.CreateSlider(128, 0, UDim2.new(0.3, 0, 0.26, 0))
radSliderGui.Parent = frame
radBar = radSliderGui:FindFirstChild("Bar")
radBar.Size = UDim2.new(0.65, 0, 0, 5)
radSliderPosition.Value = r
radSliderPosition.Changed:connect(function()
	r = radSliderPosition.Value
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
dfSliderGui, dfSliderPosition = RbxGui.CreateSlider(100, 0, UDim2.new(0.3, 0, 0.71, 0))
dfSliderGui.Parent = frame
dfBar = dfSliderGui:FindFirstChild("Bar")
dfBar.Size = UDim2.new(0.65, 0, 0, 5)
dfSliderPosition.Value = d
dfSliderPosition.Changed:connect(function()
	d = dfSliderPosition.Value
	dfl.Text = "Height: "..d.."%"
end)




--------------------------
--SUCCESSFUL LOAD MESSAGE-
--------------------------
loaded = true
print("Orbs Plugin Loaded")
