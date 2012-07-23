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
mousedown = false
r = 0
s = 1

DefaultTerrainMaterial = 1


---------------
--PLUGIN SETUP-
---------------
self = PluginManager():CreatePlugin()
self.Deactivation:connect(function()
	Off()
end)

toolbar = self:CreateToolbar("Terrain")
toolbarbutton = toolbar:CreateButton("", "Elevation Adjuster", "elevation.png")
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

--find height at coordinate x, z
function findHeight(x, z)
	h = 0
	material, wedge, rotation = GetCell(c, x, h + 1, z)
	while material.Value > 0 do
		h = h + 1
		material, wedge, rotation = GetCell(c, x, h + 1, z)
	end
	return h
end


--makes a shell around block at coordinate x, z using heightmap
function makeShell(x, z, heightmap, shellheightmap)
	local originalheight = heightmap[x][z]
	for i = x - 1, x + 1 do
		for k = z - 1, z + 1 do
			if shellheightmap[i][k] < originalheight then
				for h = originalheight, shellheightmap[i][k] - 2, -1 do
					if h > 0 then
						SetCell(c, i, h, k, DefaultTerrainMaterial, 0, 0)
					end
				end
				shellheightmap[i][k] = originalheight
			end
		end
	end
	return shellheightmap
end



--elevates terrain at point (x, y, z) in cluster c
--within radius r1 from x, z the elevation should become y + d
--from radius r1 to r2 the elevation should be a gradient
function elevate(x, y, z, r1, r2, d, range)
	for i = x - (range + 2), x + (range + 2) do
		if oldheightmap[i] == nil then
			oldheightmap[i] = {}
		end
		for k = z - (range + 2), z + (range + 2) do
			if oldheightmap[i][k] == nil then
				oldheightmap[i][k] = findHeight(i, k)
			end
		
		
			--figure out the height to make coordinate (i, k)
			local distance = dist(i, k, x, z)
			if distance < r1 then
				height = y + d
			elseif distance < r2 then
				height = math.floor((y + d) * (1 - (distance - r1)/(r2 - r1)) + oldheightmap[i][k] * (distance - r1)/(r2 - r1))
			else
				height = oldheightmap[i][k]
			end
			if height == 0 then
				height = -1
			end
			
			--heightmap[i][k] should be the current height of coordinate (i, k)
			if heightmap[i] == nil then
				heightmap[i] = {}
			end
			if heightmap[i][k] == nil then
				heightmap[i][k] = oldheightmap[i][k]
			end
			
			--the height is either greater than or less than the current height
			if height > heightmap[i][k] then
				for h = heightmap[i][k] - 2, height do
					SetCell(c, i, h, k, DefaultTerrainMaterial, 0, 0)
				end
				heightmap[i][k] = height
			elseif height < heightmap[i][k] then
				for h = heightmap[i][k], height + 1, -1 do
					SetCell(c, i, h, k, 0, 0, 0)
				end
				heightmap[i][k] = height
			end
		end
	end
	
	--copy heightmap into shellheightmap
	shellheightmap = {}
	for i = x - (range + 2), x + (range + 2) do
		if shellheightmap[i] == nil then
			shellheightmap[i] = {}
		end
		for k = z - (range + 2), z + (range + 2) do
			shellheightmap[i][k] = heightmap[i][k]
		end
	end
	--shell everything
	for i = x - range , x + range do
		for k = z - range, z + range do
			if shellheightmap[i][k] ~= oldheightmap[i][k] then
				shellheightmap = makeShell(i, k, heightmap, shellheightmap)
			end
		end
	end
	
	for i = x - (range + 2), x + (range + 2) do
		for k = z - (range + 2), z + (range + 2) do
			heightmap[i][k] = shellheightmap[i][k]
		end
	end
	
	for k = z - (range + 1), z + (range + 1) do
		for i = x - (range + 1), x + (range + 1) do
			local height = heightmap[i][k]
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
end

function dist(x1, y1, x2, y2)
	return math.sqrt(math.pow(x2-x1, 2) + math.pow(y2-y1, 2))
end

function dist3d(x1, y1, z1, x2, y2, z2)
	return math.sqrt(math.pow(dist(x1, z1, x2, z2), 2) + math.pow(math.abs(y2-y1)*100/d, 2))
end

function onClicked(mouse)
	if on then
		oldheightmap = {}
		heightmap = {}
		local cellPos = WorldToCellPreferSolid(c, Vector3.new(mouse.Hit.x, mouse.Hit.y, mouse.Hit.z))
		local x = cellPos.X
		local y = cellPos.Y
		local z = cellPos.Z

		local celMat = GetCell(c, x, y, z)
		if celMat.Value > 0 then DefaultTerrainMaterial = celMat.Value end

		mousedown = true
		local originalY = mouse.Y
		local prevY = originalY
		local d = 0
		local range = 0
		while mousedown == true do
			
			if math.abs(mouse.Y - prevY) >= 5 then
				prevY = mouse.Y
				r2 = r + math.floor(50 * 1/s * math.abs(originalY - prevY)/mouse.ViewSizeY)
				if r2 > range then
					range = r2
				end
				d = math.floor(50 * (originalY - prevY)/mouse.ViewSizeY)
				elevate(x, y, z, r, r2, d, range)
			end
			wait(0)
		end
		print("Elevated at: "..x..", "..y..", "..z)
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
	sfl.Text = "Slope: "..s
	on = true
end

function Off()
	toolbarbutton:SetActive(false)
	radl.Text = ""
	sfl.Text = ""
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
radSliderGui, radSliderPosition = RbxGui.CreateSlider(11, 0, UDim2.new(0.3, 0, 0.26, 0))
radSliderGui.Parent = frame
radBar = radSliderGui:FindFirstChild("Bar")
radBar.Size = UDim2.new(0.65, 0, 0, 5)
radSliderPosition.Value = r + 1
radSliderPosition.Changed:connect(function()
	r = radSliderPosition.Value - 1
	radl.Text = "Radius: "..r
end)

--current slope factor display label
sfl = Instance.new("TextLabel", frame)
sfl.Position = UDim2.new(0.05, 0, 0.55, 0)
sfl.Size = UDim2.new(0.2, 0, 0.35, 0)
sfl.Text = ""
sfl.BackgroundColor3 = Color3.new(0.4, 0.4, 0.4)
sfl.TextColor3 = Color3.new(0.95, 0.95, 0.95)
sfl.Font = Enum.Font.ArialBold
sfl.FontSize = Enum.FontSize.Size14
sfl.BorderColor3 = Color3.new(0, 0, 0)
sfl.BackgroundTransparency = 1

--slope factor slider
sfSliderGui, sfSliderPosition = RbxGui.CreateSlider(16, 0, UDim2.new(0.3, 0, 0.71, 0))
sfSliderGui.Parent = frame
sfBar = sfSliderGui:FindFirstChild("Bar")
sfBar.Size = UDim2.new(0.65, 0, 0, 5)
sfSliderPosition.Value = s * 10 - 0.4
sfSliderPosition.Changed:connect(function()
	s = sfSliderPosition.Value / 10 + 0.4
	sfl.Text = "Slope: "..s
end)




--------------------------
--SUCCESSFUL LOAD MESSAGE-
--------------------------
loaded = true
print("Elevation Plugin Loaded")