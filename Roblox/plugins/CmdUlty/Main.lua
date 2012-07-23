self = PluginManager():CreatePlugin()

toolbar = self:CreateToolbar("Anaminus")

toolbarbutton = toolbar:CreateButton("CmdUltl","Made by Anaminus","")

toolbarbutton.Click:connect(function()

-- Configuration variables
config = {
    button_font             = Enum.Font.Legacy;
    button_font_size        = Enum.FontSize.Size10;
    button_size_x           = 80;
    button_size_y           = 20;
    control_size            = 16;
    desc_padding            = 40;
    desc_width_max          = 300;
    menu_auto_collapse      = true;
    menu_indent             = 16;
    plugin_safe_mode        = true;
    shortcut_keys_enabled   = true;
    tool_menu_length        = 8;
    tool_sounds_enabled     = true;
    tween_panel_enabled     = true;
    tween_speed             = 0.25;
}

-- Plugin locations
plugins = {
	-- add asset IDs or script locations here;
--	56563025;	-- Circles by Anaminus
}

-- Key remapping
shortcuts = {
    ["Move.Axis"]           = "r";
    ["Move.AxisSnap"]       = "";
    ["Move.First"]          = "t";
    ["Move.FirstSnap"]      = "";
    ["Move.Object"]         = "y";
    ["Rotate.Object"]       = "f";
    ["Rotate.ObjectSnap"]   = "";
    ["Rotate.Pivot"]        = "g";
    ["Rotate.PivotSnap"]    = "";
    ["Rotate.Group"]        = "h";
    ["Resize.Object"]       = "v";
    ["Resize.ObjectSnap"]   = "";
    ["Resize.Center"]       = "b";
    ["Weld.Join"]           = "";
    ["Weld.Break"]          = "";
    ["Scale.Scale"]         = "";
    ["Other.Delete"]        = "-";
    ["Other.Slope"]         = "";
    ["Other.Midpoint"]      = "";
    ["Control.Expand"]      = "q";
    ["Control.Help"]        = "?";
    ["Control.Close"]       = "";
}

--------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------
-- Begin CmdUtl ----

-- check for valid lua version
assert(
	function()
		return _VERSION == "Lua 5.1"
	end,
	"CmdUtl cannot run in ".._VERSION
)

-- check for valid security context
assert(
	pcall(function()
		return game:GetService("Selection"):Get()
		and game:GetService("CoreGui"):GetChildren()
	end),
	"CmdUtl cannot run in the current security context! See the Documentation for a proper setup"
)

-- Close other CmdUtls
if type(_G.CloseCmdUtl) == "function" then
	pcall(_G.CloseCmdUtl)
end

-- remove any remaining panels
for i,v in pairs(game:GetService("CoreGui"):GetChildren()) do
	if v.Name == "CmdUtl" then
		v:Remove()
	end
end

-- management for resource disposal
local Disposal = {
	normal = {};		-- items here will be recursively removed and handled
	limited = {};		-- items here will simply be unreferenced with no recursion or handles
}

-- Add Disposal Reference: adds item to disposal management
function ADR(item,limit)
	if limit then
		table.insert(Disposal.limited,item)
	else
		table.insert(Disposal.normal,item)
	end
end

-- Remove Disposal Reference: removes item from disposal management
function RDR(item,limit)
	if limit then
		for i,v in pairs(Disposal.limited) do
			if v == item then
				table.remove(Disposal.limited,i)
				break
			end
		end
	else
		for i,v in pairs(Disposal.normal) do
			if v == item then
				table.remove(Disposal.normal,i)
				break
			end
		end
	end
end

-- notes: any globally set variables are available to built-in plugins

-- create panel
Screen = Instance.new("ScreenGui"); ADR(Screen)
Screen.Name = "CmdUtl"
Screen.Parent = game:GetService("CoreGui")
Panel = Instance.new("Frame"); ADR(Panel)
Panel.BackgroundTransparency = 1
Panel.Position = UDim2.new(0, 0, 0.05, 0)
Panel.Name = "Panel"
Panel.Parent = Screen
Div = Instance.new("Frame"); ADR(Div)
Div.Position = UDim2.new(0, 0, 0, config.control_size)
Div.Style = Enum.FrameStyle.RobloxRound
Div.Name = "Items"
Div.Parent = Panel

Resource = {
	control_color			= Color3.new(0,0,0);
	control_selected_color	= Color3.new(0.5,0.5,0.5);
	output_color			= Color3.new(1,1,1);
	warning_color			= Color3.new(1,0.8,0);
	error_color				= Color3.new(0.8,0,0);
}
ADR(Resource)

ID = {}; ADR(ID)	-- identity table for panel elements
Control = {}; ADR(Control)	-- identity table for panel controls
ControlData = {}; ADR(ControlData)	-- holds control data
Commands = {}	-- holds command line functions
Shortcut = {}; ADR(Shortcut)	-- holds key/tool shortcut associations

ToolSelectListener = {}; ADR(ToolSelectListener)	-- ondown
ToolDeselectListener = {}; ADR(ToolDeselectListener) -- onup
ButtonDescription = {}; ADR(ButtonDescription)
ToolWarnings = {}; ADR(ToolWarnings)
ToolSafeMode = {}; ADR(ToolSafeMode)

ToolState = {}; ADR(ToolState)
ValueState = {}; ADR(ValueState)
MenuState = {}; ADR(MenuState)

PluginDataFromName = {}; ADR(PluginDataFromName)
PluginDataFromButton = {}; ADR(PluginDataFromButton)
PluginResources = {}; ADR(PluginResources)
ToolsFromMenu = {}; ADR(ToolsFromMenu)
MenuFromTool = {}; ADR(MenuFromTool)

Mode = {
	Enabled = true;
	PanelExpanded = true;
	DivTweenEnabled = true;
	HelpModeEnabled = false;
}
ADR(Mode)

version = "3.0.0"

local floor = math.floor
local cframe = CFrame.new
local Selection = game:GetService("Selection")
local ContentProvider = game:GetService("ContentProvider")
local SoundService = game:GetService("SoundService")
local GuiService = game:GetService("GuiService")

local restrict_mt = {
	__newindex = function(t,k,v)
		if getfenv(2) == getfenv() then	-- only this env is allowed to set new values
			rawset(t,k,v)
		else
			error("Cannot set value \""..tostring(k).."\"",2)
		end
	end;
}
ADR(restrict_mt)

-- holds sound objects referenced by sound id
local SoundRef = {}; ADR(SoundRef)

-- create default overlay objects
local DefaultOverlay = Instance.new("Part"); ADR(DefaultOverlay)
DefaultOverlay.Name = "SelectionOverlay"
DefaultOverlay.Anchored = true
DefaultOverlay.CanCollide = false
DefaultOverlay.Locked = true
DefaultOverlay.formFactor = "Custom"
DefaultOverlay.TopSurface = 0
DefaultOverlay.BottomSurface = 0
DefaultOverlay.Transparency = 1
local OverlayAdornments = {}; ADR(OverlayAdornments)
OverlayAdornments.Handles = Instance.new("Handles"); ADR(OverlayAdornments.Handles)
OverlayAdornments.Handles.Adornee = DefaultOverlay
OverlayAdornments.Handles.Visible = false
OverlayAdornments.ArcHandles = Instance.new("ArcHandles"); ADR(OverlayAdornments.ArcHandles)
OverlayAdornments.ArcHandles.Adornee = DefaultOverlay
OverlayAdornments.ArcHandles.Visible = false
OverlayAdornments.SelectionBox = Instance.new("SelectionBox"); ADR(OverlayAdornments.SelectionBox)
OverlayAdornments.SelectionBox.Adornee = DefaultOverlay
OverlayAdornments.SelectionBox.Visible = false
OverlayAdornments.SurfaceSelection = Instance.new("SurfaceSelection"); ADR(OverlayAdornments.SurfaceSelection)
OverlayAdornments.SurfaceSelection.Adornee = DefaultOverlay
OverlayAdornments.SurfaceSelection.Visible = false

-- go-to for outputting info
function Log(...)
	local out = ""
	local inp = {...}
	local n = #inp
	for i,msg in pairs(inp) do
		out = out .. tostring(msg)
	end
	----------------
	print("LOG:",out)
end

function LogWarning(...)
	local out = ""
	local inp = {...}
	local n = #inp
	for i,msg in pairs(inp) do
		out = out .. tostring(msg)
	end
	----------------
	print("LOG_WARNING:",out)
end

function LogError(...)
	local out = ""
	local inp = {...}
	local n = #inp
	for i,msg in pairs(inp) do
		out = out .. tostring(msg)
	end
	----------------
	print("LOG_ERROR:",out)
end

-- checks if the value is a positive integer
function IsPositiveInteger(n)
	return type(n) == "number" and n > 0 and math.floor(n) == n
end

-- checks if the table contains a sequence of keys
function IsSequential(array, m)
	for i=1,m do
		if array[i] == nil then return false end
	end
	return true
end

-- checks if a table is an array
function IsArray(array)
	local m = 0
	for k, _ in pairs(array) do
		if not IsPositiveInteger(k) then return false end
		if k > m then m = k end
	end
	return IsSequential(array, m)
end

-- checks if the string contains only letters, numbers, and underscores, with the first character not being a number
function IsVarName(name)
	return name:match("^[%a_][%w_]-$") == name
end

local valid_protocols = {
	["http"] = true;
	["https"] = true;
	["rbxhttp"] = true;
	["rbxasset"] = true;
	["rbxassetid"] = true;
}
ADR(valid_protocols)

-- checks if the value is a Content string
function IsContent(link)
	if type(link) == "string" then
		local protocol = link:match("^(.+)://(.+)$")
		return valid_protocols[protocol] or false
	else
		return false
	end
end

-- recursive for GetFilteredSelection
local function RecurseSelectionFilter(object,class,out)
	if object:IsA(class) then
		table.insert(out,object)
	end
	for _,child in pairs(object:GetChildren()) do
		RecurseSelectionFilter(child,class,out)
	end
end

local points = {
	Vector3.new(-1,-1,-1);
	Vector3.new( 1,-1,-1);
	Vector3.new(-1, 1,-1);
	Vector3.new( 1, 1,-1);
	Vector3.new(-1,-1, 1);
	Vector3.new( 1,-1, 1);
	Vector3.new(-1, 1, 1);
	Vector3.new( 1, 1, 1);
}
ADR(points)

-- recursive for GetBoundingBox
local function RecurseGetBoundingBox(object,sides,out)
	if object:IsA"BasePart" then
		local mod = object.Size/2
		local rot = object.CFrame
		for _,mult in pairs(points) do
			local point = rot*cframe(mod*mult).p
			if point.x > sides[1] then sides[1] = point.x end
			if point.x < sides[2] then sides[2] = point.x end
			if point.y > sides[3] then sides[3] = point.y end
			if point.y < sides[4] then sides[4] = point.y end
			if point.z > sides[5] then sides[5] = point.z end
			if point.z < sides[6] then sides[6] = point.z end
		end
		table.insert(out,object)
	end
	for _,child in pairs(object:GetChildren()) do
		RecurseGetBoundingBox(child,sides,out)
	end
end

function GetBoundingBox(objects)
	local sides = {-math.huge;math.huge;-math.huge;math.huge;-math.huge;math.huge}
	local out = {}
	for _,object in pairs(objects) do
		RecurseGetBoundingBox(object,sides,out)
	end
	return
		Vector3.new(sides[1]-sides[2],sides[3]-sides[4],sides[5]-sides[6]),
		Vector3.new((sides[1]+sides[2])/2,(sides[3]+sides[4])/2,(sides[5]+sides[6])/2),
		out
end

local ToolEnvMetadata = {}; ADR(ToolEnvMetadata)
local ToolButtonMetadata = {}; ADR(ToolButtonMetadata)

-- gets metadata from a button or the env calling the function calling this
function GetToolMetadata(button)
	local md
	if button then
		md = ToolButtonMetadata[button]
	else
		md = ToolEnvMetadata[getfenv(3)]
	end
	if not md then error("Invalid call",3) end
	return md
end

local CommandEnvMetadata = {}; ADR(CommandEnvMetadata)

-- gets metadata from the env calling the function calling this
function GetCommandMetadata()
	local md = CommandEnvMetadata[getfenv(3)]
	if not md then error("Invalid call",3) end
	return md
end

function SetDescription(button,visible)
	local desc = ButtonDescription[button]
	if desc then
		if visible then
			local y = button.AbsolutePosition.y
			local m,s = y + desc.AbsoluteSize.y,Screen.AbsoluteSize.y-4
			if m > s then y = y-(m-s) end
			desc.Position = UDim2.new(0,0,0,y-DescriptionFrame.AbsolutePosition.y)
			desc.Visible = true
		elseif not state then
			desc.Visible = false
		end
	end
end

-- selects a tool using its button
function SelectTool(button,stop_prev)
	local prev
	if not stop_prev then
		for button,b in pairs(ToolState) do
			if b then
				DeselectTool(button)
				prev = button
			end
		end
	end
	ToolState[button] = true
	button.Selected = true
	local listener = ToolSelectListener[button]
	local md = GetToolMetadata(button)
	local overlay = md.Overlay
	local env = md.Env
	for i,v in pairs(overlay) do
		v:Remove()
		overlay[i] = nil
		env["Overlay"..i] = nil
	end
	overlay.Part = DefaultOverlay:Clone()
	overlay.Part.archivable = false
	env["OverlayPart"] = overlay.Part
	for i,v in pairs(OverlayAdornments) do
		local c = v:Clone()
		c.Adornee = overlay.Part
		c.archivable = false
		overlay[i] = c
		c.Parent = Screen.Parent
		env["Overlay"..i] = c
	end
	md.PreviousTool = prev
	local e,o = pcall(listener)
	if not e then
		LogError("Tool:",button.Name,": ",o)
	end
end

-- deselects a tool using its button
function DeselectTool(button)
	ToolState[button] = false
	button.Selected = false
	local listener = ToolDeselectListener[button]
	if listener then
		local e,o = pcall(listener)
		if not e then
			LogError("Tool:",button.Name,": ",o)
		end
	end
	local md = GetToolMetadata(button)
	local overlay = md.Overlay
	local env = md.Env
	for i,v in pairs(overlay) do
		v:Remove()
		overlay[i] = nil
		env["Overlay"..i] = nil
	end
	local connections = md.Connections
	for i,v in pairs(connections) do
		v:disconnect()
		connections[i] = nil
	end
end

-- toggles the visibility of a menu with its menu button; optional force true or false
function ToggleMenu(button,force)
	local state = MenuState[button]
	if Mode.Enabled and Mode.PanelExpanded then
		if force == nil then
			state[1] = not state[1]
		else
			state[1] = not not force
		end
		if not state[1] then									-- if menu is collapsing
			for i,tool in pairs(ToolsFromMenu[state[2]]) do	-- deselect tools of that menu
				if ToolState[tool] then
					DeselectTool(tool)
				end
			end
		end
		button.Selected = state[1]
		state[2].Visible = state[1]
	end
end

-- holds various environments that will be set or copied
Environment = {
	Source = {	-- plugin source
		Safe = {
			Axes = Axes; BrickColor = BrickColor; CFrame = CFrame; Color3 = Color3; Faces = Faces; Instance = Instance; Ray = Ray; Region3 = Region3; UDim = UDim; UDim2 = UDim2; Vector2 = Vector2; Vector3 = Vector3;
			math = math; string = string; table = table;
			Enum = Enum; 
		};
		Unsafe = {
			_VERSION = _VERSION;
			ipairs = ipairs; next = next; pairs = pairs; pcall = pcall; print = print; select = select; tonumber = tonumber; tostring = tostring; type = type; unpack = unpack; xpcall = xpcall;
			coroutine = coroutine; math = math; string = string; table = table;
			Delay = Delay; delay = delay; LoadLibrary = LoadLibrary; LoadRobloxLibrary = LoadRobloxLibrary; printidentity = printidentity; Spawn = Spawn; tick = tick; time = time; Version = Version; version = version; Wait = Wait; wait = wait;
			game = game; Game = Game; workspace = workspace; Workspace = Workspace;
			assert = assert; collectgarbage = collectgarbage; dofile = dofile; error = error; gcinfo = gcinfo; getfenv = getfenv; getmetatable = getmetatable; load = load; loadfile = loadfile; loadstring = loadstring; newproxy = newproxy; rawequal = rawequal; rawget = rawget; rawset = rawset; setfenv = setfenv; setmetatable = setmetatable;
			_G = _G;
			shared = shared;
			crash__ = crash__; settings = settings; Stats = Stats; stats = stats; UserSettings = UserSettings;
		};
	};
	Listener = {	-- tool listeners
		Global = {
			Safe = {
				_VERSION = _VERSION;
				ipairs = ipairs; next = next; pairs = pairs; pcall = pcall; print = print; select = select; tonumber = tonumber; tostring = tostring; type = type; unpack = unpack; xpcall = xpcall;
				coroutine = coroutine; math = math; string = string; table = table;
				Delay = Delay; delay = delay; LoadLibrary = LoadLibrary; LoadRobloxLibrary = LoadRobloxLibrary; printidentity = printidentity; Spawn = Spawn; tick = tick; time = time; Version = Version; version = version; Wait = Wait; wait = wait;
				Axes = Axes; BrickColor = BrickColor; CFrame = CFrame; Color3 = Color3; Faces = Faces; Instance = Instance; Ray = Ray; Region3 = Region3; UDim = UDim; UDim2 = UDim2; Vector2 = Vector2; Vector3 = Vector3;
				Enum = Enum; game = game; Game = Game; workspace = workspace; Workspace = Workspace;
			};
			Unsafe = {
				assert = assert; collectgarbage = collectgarbage; dofile = dofile; error = error; gcinfo = gcinfo; getfenv = getfenv; getmetatable = getmetatable; load = load; loadfile = loadfile; loadstring = loadstring; newproxy = newproxy; rawequal = rawequal; rawget = rawget; rawset = rawset; setfenv = setfenv; setmetatable = setmetatable;
				_G = _G;
				shared = shared;
				crash__ = crash__; settings = settings; Stats = Stats; stats = stats; UserSettings = UserSettings;
			};
		};
		API = {
			Safe = {
				WrapOverlay = function(object,isbb)
					local md = GetToolMetadata()
					local overlay = md.Overlay.Part
					if type(object) == "table" then
						local size,pos = GetBoundingBox(object)
						overlay.Size = size
						overlay.CFrame = CFrame.new(pos)
						overlay.Parent = workspace
					elseif object:IsA"BasePart" then
						if isbb then
							local size,pos = GetBoundingBox{object}
							overlay.Size = size
							overlay.CFrame = CFrame.new(pos)
						else
							overlay.Size = object.Size
							overlay.CFrame = object.CFrame
						end
						overlay.Parent = workspace
					end
				end;
				GetOverlaySize = function()
					local md = GetToolMetadata()
					return md.Overlay.Part.Size
				end;
				GetOverlayCFrame = function()
					local md = GetToolMetadata()
					return md.Overlay.Part.CFrame
				end;
				SetOverlaySize = function(v)
					local md = GetToolMetadata()
					local overlay = md.Overlay.Part
					local cf = overlay.CFrame
					overlay.Size = v
					overlay.CFrame = cf
				end;
				SetOverlayCFrame = function(cf)
					local md = GetToolMetadata()
					md.Overlay.Part.CFrame = cf
				end;
				SetOverlay = function(v,cf)
					local md = GetToolMetadata()
					local overlay = md.Overlay.Part
					overlay.Size = v
					overlay.CFrame = cf
				end;
				Round = function(number,by)
					if by == 0 then
						return number
					else
						return floor(number/by+0.5)*by
					end
				end;
				Resource = function(key)
					local md = GetToolMetadata()
					local resource = md.Resource[key]
					if resource then
						return resource
					else
						error("\""..key.."\" is not a valid resource key",2)
					end
				end;
				Config = function(key)
					return config[key]
				end;
				GetSelection = function()
					return Selection:Get()
				end;
				SetSelection = function(set)
					Selection:Set(set)
				end;
				GetFilteredSelection = function(class)
					local out = {}
					for _,object in pairs(Selection:Get()) do
						RecurseSelectionFilter(object,class,out)
					end
					return out
				end;
				GetFiltered = function(class,objects)
					local out = {}
					for _,object in pairs(objects) do
						RecurseSelectionFilter(object,class,out)
					end
					return out
				end;
				GetBoundingBox = GetBoundingBox;
				GetSelectionBoundingBox = function()
					local size,pos,out = GetBoundingBox(Selection:Get())
					return out,size,pos
				end;
				GetMidpoint = function(set)
					local mid = Vector3.new()
					for i,v in pairs(set) do
						mid = mid+v.Position
					end
					return mid/#set
				end;
				GetButtonValue = function(id)
					local md = GetToolMetadata()
					local vbutton = md.ButtonFromId[id]
					if vbutton then
						local vstate = ValueState[vbutton]
						if vstate then
							return vstate[1]
						else
							error("cannot get value of button \""..id.."\"",2)
						end
					else
						error("\""..id.."\" is not a defined button",2)
					end
				end;
				SetButtonValue = function(id,value)
					local md = GetToolMetadata()
					local vbutton = md.ButtonFromId[id]
					if vbutton then
						local vstate = ValueState[vbutton]
						if vstate then
							vstate[2](value)
						else
							error("cannot get value of button \""..id.."\"",2)
						end
					else
						error("\""..id.."\" is not a defined button",2)
					end
				end;
				Deselect = function()
					local md = GetToolMetadata()
					DeselectTool(md.Button)
				end;
				SetWarning = function(index)
					local md = GetToolMetadata()
					DeselectTool(md.Button)
					local warnings = md.Warnings
					if warnings then
						local msg = warnings[index or 1]
						LogWarning("Tool \"",md.ID,"\": ",msg)
					end
				end;
				Connect = function(event,listener)
					local md = GetToolMetadata()
					local connections = md.Connections
					table.insert(connections,event:connect(listener))
				end;
				SelectPreviousTool = function()
					local md = GetToolMetadata()
					DeselectTool(md.Button)
					local prev = md.PreviousTool
					if prev then
						SelectTool(prev)
					end
				end;
				PlaySound = function(key)
					if config.tool_sounds_enabled then
						local md = GetToolMetadata()
						local resource = md.Resource[key]
						if resource then
							if IsContent(resource) then
								local sound = SoundRef[resource]
								if not sound then
									sound = Instance.new("StockSound")
									sound.Name = "CmdUtl:"..key
									sound.SoundId = resource
									sound.archivable = false
									sound.Parent = SoundService
									SoundRef[resource] = sound
								end
								sound:Play()
							end
						end
					end
				end;
			};
			Unsafe = {};
		};
	};
	Command = {
		Global = {
			Safe = {
				_VERSION = _VERSION;
				assert = assert; error = error; ipairs = ipairs; next = next; pairs = pairs; pcall = pcall; print = print; select = select; tonumber = tonumber; tostring = tostring; type = type; unpack = unpack; xpcall = xpcall;
				coroutine = coroutine; math = math; string = string; table = table;
				Delay = Delay; delay = delay; LoadLibrary = LoadLibrary; LoadRobloxLibrary = LoadRobloxLibrary; printidentity = printidentity; Spawn = Spawn; tick = tick; time = time; Version = Version; version = version; Wait = Wait; wait = wait;
				Axes = Axes; BrickColor = BrickColor; CFrame = CFrame; Color3 = Color3; Faces = Faces; Instance = Instance; Ray = Ray; Region3 = Region3; UDim = UDim; UDim2 = UDim2; Vector2 = Vector2; Vector3 = Vector3;
				Enum = Enum; game = game; Game = Game; workspace = workspace; Workspace = Workspace;
			};
			Unsafe = {
				collectgarbage = collectgarbage; dofile = dofile; gcinfo = gcinfo; getfenv = getfenv; getmetatable = getmetatable; load = load; loadfile = loadfile; loadstring = loadstring; newproxy = newproxy; rawequal = rawequal; rawget = rawget; rawset = rawset; setfenv = setfenv; setmetatable = setmetatable;
				_G = _G;
				shared = shared;
				crash__ = crash__; settings = settings; Stats = Stats; stats = stats; UserSettings = UserSettings;
			};
		};
		API = {
			Safe = {
				Round = function(number,by)
					if by == 0 then
						return number
					else
						return floor(number/by+0.5)*by
					end
				end;
				Resource = function(key)
					local md = GetCommandMetadata()
					local resource = md.Resource[key]
					if resource then
						return resource
					else
						error("\""..key.."\" is not a valid resource key",2)
					end
				end;
				Config = function(key)
					return config[key]
				end;
				GetSelection = function()
					return Selection:Get()
				end;
				SetSelection = function(set)
					Selection:Set(set)
				end;
				GetFilteredSelection = function(class)
					local out = {}
					for _,object in pairs(Selection:Get()) do
						RecurseSelectionFilter(object,class,out)
					end
					return out
				end;
				GetFiltered = function(class,objects)
					local out = {}
					for _,object in pairs(objects) do
						RecurseSelectionFilter(object,class,out)
					end
					return out
				end;
				GetBoundingBox = GetBoundingBox;
				GetSelectionBoundingBox = function()
					local size,pos,out = GetBoundingBox(Selection:Get())
					return out,size,pos
				end;
				GetMidpoint = function(set)
					local mid = Vector3.new()
					for i,v in pairs(set) do
						mid = mid+v.Position
					end
					return mid/#set
				end;
			};
			Unsafe = {};
		};
	};
	BuiltIn = getfenv();
}
ADR(Environment.Listener.API)
ADR(Environment.Command.API)
ADR(Environment,true)
ADR(Environment.Source,true)
ADR(Environment.Source.Safe,true)
ADR(Environment.Source.Unsafe,true)
ADR(Environment.Listener,true)
ADR(Environment.Listener.Global,true)
ADR(Environment.Listener.Global.Safe,true)
ADR(Environment.Listener.Global.Unsafe,true)
ADR(Environment.Command,true)
ADR(Environment.Command.Global,true)
ADR(Environment.Command.Global.Safe,true)
ADR(Environment.Command.Global.Unsafe,true)

--	notes: icon theme:
--		all-white over transparent
--		no curves
--		1/8 padding (32/256)
--		5/32 weight (40/256)

-- most of the style is controlled here

local frame_width = 8	-- RobloxRound

-- tags that change text color
local ColorTags = {
	["h"] = Color3.new(0.6,0.6,1);
}

MakeGuiObject = {
	["tool"] = function(name,text)
		local button = Instance.new("TextButton"); ADR(button)
		button.Name = name or button.Name
		button.Text = text or button.Text
		button.Font = config.button_font
		button.FontSize = config.button_font_size
		button.BackgroundColor3 = Color3.new(1, 1, 1)
		button.Size = UDim2.new(1, 0, 1, 0)
		button.Style = Enum.ButtonStyle.RobloxButton
		button.TextColor3 = Color3.new(1, 1, 1)
		button.BorderColor3 = Color3.new(0, 0, 0)
		return button
	end;
	["field"] = function(name,text)
		local button = Instance.new("TextBox"); ADR(button)
		button.Name = name or button.Name
		button.Text = text or button.Text
		button.Font = config.button_font
		button.FontSize = config.button_font_size
		button.BackgroundColor3 = Color3.new(0, 0, 0)
		button.Size = UDim2.new(1, 0, 1, 0)
		button.TextColor3 = Color3.new(1, 1, 1)
		button.BorderColor3 = Color3.new(1, 1, 1)
		button.BackgroundTransparency = 0.5
		return button
	end;
	["label"] = function(name,text)
		local button = Instance.new("TextLabel"); ADR(button)
		button.Name = name or button.Name
		button.Text = text or button.Text
		button.Font = config.button_font
		button.FontSize = config.button_font_size
		button.Size = UDim2.new(1, 0, 1, 0)
		button.TextColor3 = Color3.new(1, 1, 1)
		button.BorderColor3 = Color3.new(1, 1, 1)
		button.BackgroundColor3 = Color3.new(0, 0, 0)
		button.Position = UDim2.new(1, 0, 3, 0)
		button.BackgroundTransparency = 0.5
		return button
	end;
	["toggle"] = function(name,value,text)
		local button = Instance.new("TextButton"); ADR(button)
		button.Name = name or button.Name
		button.Text = text or name or button.Name
		button.Font = config.button_font
		button.FontSize = config.button_font_size
		button.BackgroundColor3 = Color3.new(1, 1, 1)
		button.Selected = value or false
		button.Size = UDim2.new(1, 0, 1, 0)
		button.Style = Enum.ButtonStyle.RobloxButton
		button.TextColor3 = Color3.new(1, 1, 1)
		button.BorderColor3 = Color3.new(0, 0, 0)
		return button
	end;
	["container"] = function(name)
		local button = Instance.new("Frame"); ADR(button)
		button.Name = name or button.Name
		button.BorderSizePixel = 0
		button.Size = UDim2.new(1, 0, 1, 0)
		button.BorderColor3 = Color3.new(0, 0, 0)
		button.BackgroundTransparency = 1
		button.BackgroundColor3 = Color3.new(0, 0, 0)
		return button
	end;
	["title"] = function()
		local title = Instance.new("TextLabel"); ADR(button)
		title.Name = "Title"
		title.BackgroundColor3 = Color3.new(0,0,0)
		title.BackgroundTransparency = 0.3
		title.BorderSizePixel = 0
		title.Font = config.button_font
		title.FontSize = config.button_font_size
		title.TextColor3 = Color3.new(1,1,1)
		title.Size = UDim2.new(1,0,0,config.control_size)
		title.Position = UDim2.new(0,0,0,-config.control_size-frame_width)
		return title
	end;
	["descframe"] = function()
		local frame = Instance.new("Frame"); ADR(frame)
		frame.Name = "Descriptions"
		frame.BackgroundTransparency = 1
		frame.Position = UDim2.new(1,frame_width+config.control_size+config.desc_padding,0,0)
		return frame
	end;
	
	["description"] = function()
		local desc = Instance.new("TextLabel"); ADR(desc)
		desc.Name = "Description"
		desc.Font = config.button_font
		desc.FontSize = config.button_font_size
		desc.TextColor3 = Color3.new(1, 1, 1)
		desc.BorderColor3 = Color3.new(1, 1, 1)
		desc.BackgroundColor3 = Color3.new(0, 0, 0)
		desc.TextTransparency = 1
		desc.ZIndex = 2
		return desc
	end;
	["paragraph"] = function()
		local pad = Instance.new("Frame"); ADR(pad)
		pad.Name = "Padding"
		pad.BackgroundTransparency = 1
		local para = Instance.new("TextLabel"); ADR(para)
		para.Name = "Paragraph"
		para.BackgroundTransparency = 1
		para.Font = config.button_font
		para.FontSize = config.button_font_size
		para.TextXAlignment = "Left"
		para.TextColor3 = Color3.new(1, 1, 1)
		para.TextWrap = true
		para.Position = UDim2.new(0,4,0,0)
		para.Size = UDim2.new(1,-4,1,0)
		para.ZIndex = 2
		para.Parent = pad
		return pad,para
	end;
	["controlframe"] = function()
		local frame = Instance.new("Frame"); ADR(frame)
		frame.Name = "Controls"
		frame.BackgroundTransparency = 1
		frame.Position = UDim2.new(1,frame_width,0,0)
		frame.Size = UDim2.new(0,config.control_size,0,config.control_size)
		return frame
	end;
	["controlbutton"] = function(name,image)
		local button = Instance.new("ImageButton"); ADR(button)
		button.BackgroundColor3 = Color3.new(0,0,0)
		button.BackgroundTransparency = 0.3
		button.BorderSizePixel = 0
		button.Name = name or button.Name
		button.Image = image or ""
		button.Size = UDim2.new(1,0,1,0)
		return button
	end;
	["menubutton"] = function(name,text)
		local button = Instance.new("TextButton"); ADR(button)
		button.Name = name or button.Name
		button.Text = text or button.Text
		button.Font = config.button_font
		button.FontSize = config.button_font_size
		button.BackgroundColor3 = Color3.new(1, 1, 1)
		button.Size = UDim2.new(0, config.button_size_x, 0, config.button_size_y)
		button.Style = Enum.ButtonStyle.RobloxButton
		button.TextColor3 = Color3.new(1, 1, 1)
		button.BorderColor3 = Color3.new(0, 0, 0)
		local tag = Instance.new("StringValue"); ADR(tag)
		tag.Name = "ElementType"
		tag.Value = "MenuButton"
		tag.Parent = button
		return button
	end;
	["menu"] = function(name,x,y)
		local menu = Instance.new("Frame"); ADR(menu)
		menu.Size = UDim2.new(0, x, 0, y)
		menu.BackgroundTransparency = 1
		menu.Position = UDim2.new(0, config.menu_indent, 0, 20)
		menu.Name = name or menu.Name
		local item = Instance.new("Frame"); ADR(item)
		item.Size = UDim2.new(0, config.button_size_x, 0, config.button_size_y)
		item.BorderColor3 = Color3.new(0, 0, 0)
		item.BackgroundTransparency = 1
		item.Name = "Items"
		item.BackgroundColor3 = Color3.new(1, 1, 1)
		item.Parent = menu
		local tag = Instance.new("StringValue"); ADR(tag)
		tag.Name = "ElementType"
		tag.Value = "Menu"
		tag.Parent = menu
		return menu
	end;
	["seperator"] = function(y)
		local sep = Instance.new("Frame"); ADR(sep)
		sep.BorderSizePixel = 0
		sep.Size = UDim2.new(1, 0, 0, 7)
		sep.BorderColor3 = Color3.new(0, 0, 0)
		sep.BackgroundTransparency = 1
		sep.Position = UDim2.new(0, 0, 0, 0)
		sep.Name = "Seperator"
		sep.BackgroundColor3 = Color3.new(0, 0, 0)
		local line = Instance.new("Frame"); ADR(line)
		line.BackgroundTransparency = 0.5
		line.Size = UDim2.new(1, 8, 0, 1)
		line.BorderSizePixel = 0
		line.Position = UDim2.new(0, -4, 0.5, 0)
		line.Name = "Line"
		line.BackgroundColor3 = Color3.new(1, 1, 1)
		line.Parent = sep
		local tag = Instance.new("StringValue"); ADR(tag)
		tag.Name = "ElementType"
		tag.Value = "Seperator"
		tag.Parent = sep
		return sep
	end;
}
ADR(MakeGuiObject)
-- handles specific element types found in div
local HandleElementType = {
	[true] = {	-- tween
		["MenuButton"] = function(element,length)
			if element.Visible then
				local abs = element.AbsoluteSize
				local x = abs.x + element.AbsolutePosition.x
				element:TweenPosition(UDim2.new(0,0,0,length),"Out","Quad",config.tween_speed,true)
				return abs.y,x
			end
		end;
		["Menu"] = function(element,length,object)
			if element.Visible then
				if element == object then
					element.Items.Visible = false
				end
				local abs = element.AbsoluteSize
				local x = abs.x + element.AbsolutePosition.x
				element:TweenPosition(UDim2.new(0,config.menu_indent,0,length),"Out","Quad",config.tween_speed,true,function()
					element.Items.Visible = true
				end)
				return abs.y,x
			end
		end;
		["Seperator"] = function(element,length)
			if element.Visible then
				local abs = element.AbsoluteSize
				local next = element.Position
				element:TweenPosition(UDim2.new(0,0,0,length),"Out","Quad",config.tween_speed,true)
				return abs.y,0
			end
		end;
	};
	[false] = {	-- no tween
		["MenuButton"] = function(element,length)
			if element.Visible then
				element.Position = UDim2.new(0,0,0,length)
				local abs = element.AbsoluteSize
				local x = abs.x + element.AbsolutePosition.x
				return abs.y,x
			end
		end;
		["Menu"] = function(element,length)
			if element.Visible then
				element.Position = UDim2.new(0,config.menu_indent,0,length)
				local abs = element.AbsoluteSize
				local x = abs.x + element.AbsolutePosition.x
				return abs.y,x
			end
		end;
		["Seperator"] = function(element,length)
			if element.Visible then
				element.Position = UDim2.new(0,0,0,length)
				local abs = element.AbsoluteSize
				return abs.y,0
			end
		end;
	};
}
ADR(HandleElementType)

--	makes the frame arrange its contents so that they stack
--	Notes on menu arrangement:
--		Content is ordered by child order
--		So, buttons and menus should be paired up when parented (1=button1, 2=menu1, 3=button2, 4=menu2, etc)
local function MakeDiv(frame)
	local children = {}
	local types = {}
	local connections = {}
	local in_con = {}

	local function recalculate(object)								-- recalculates panel's size
		if Mode.Enabled then
			Mode.Enabled = false
			local width = 0
			local length = 0

			local tweening = config.tween_panel_enabled and Mode.DivTweenEnabled
			local handles = HandleElementType[tweening]
			for i,child in pairs(children) do
				local l,w = handles[types[child]](child,length,object)
				if l then
					width = w > width and w or width
					length = length + l
				end
			end
			if tweening then
				if #children > 0 then
					frame:TweenSize(UDim2.new(0,width - frame.AbsolutePosition.x+frame_width,0,length+frame_width*2),"Out","Quad",config.tween_speed,false,function() Mode.Enabled = true end)
				else
					frame:TweenSize(UDim2.new(0,0,0,length),"Out","Quad",config.tween_speed,false,function() Mode.Enabled = true end)
				end
			else
				if #children > 0 then
					frame.Size = UDim2.new(0,width - frame.AbsolutePosition.x+frame_width,0,length+frame_width*2)
				else
					frame.Size = UDim2.new(0,0,0,length)
				end
				Mode.Enabled = true
			end
		end
	end

	local function add(object)
		local type_tag = object:FindFirstChild("ElementType")
		if type_tag and type_tag.className == "StringValue" then
			if HandleElementType[config.tween_panel_enabled][type_tag.Value] then
				table.insert(children,object)
				types[object] = type_tag.Value
				connections[object] = object.Changed:connect(function(p)
					if not Mode.Enabled and p == "AbsoluteSize" or p == "Visible" then
						recalculate(object)
					end
				end)
				recalculate(object)
			end
		end
	end

	in_con.add = frame.ChildAdded:connect(add)
	in_con.remove = frame.ChildRemoved:connect(function(child)
		if types[object] then
			types[object] = nil
			if connections[child] then
				connections[child]:disconnect()
				connections[child] = nil
			end
			for i,v in pairs(children) do
				if v == child then
					table.remove(children,i)
					break
				end
			end
			recalculate()
		end
	end)

	for _,child in pairs(frame:GetChildren()) do
		add(child)
	end
	recalculate()

	local function dispose()	-- undos everything
		for i,con in pairs(in_con) do
			con:disconnect()
			in_con[i] = nil
		end
		for i,v in pairs(children) do
			if connections[v] then
				connections[v]:disconnect()
				connections[v] = nil
			end
			types[v] = nil
			children[i] = nil
		end
		for i,con in pairs(connections) do
			con:disconnect()
			connections[i] = nil
		end
		children = nil
		types = nil
		connections = nil
		in_con = nil
		recalculate = nil
		add = nil
		dispose = nil
	end

	return dispose
end

local function MakeStackingList(frame)
	local children = {}
	local connections = {}
	local in_con = {}

	local function recalculate(object)								-- recalculates panel's size
		local width = 0
		local length = 0
		for i,child in pairs(children) do
			if child.Visible then
				child.Position = UDim2.new(0,0,0,length)
				local abs = child.AbsoluteSize
				local x = abs.x + child.AbsolutePosition.x
				width = x > width and x or width
				length = length + abs.y
			end
		end
		if #children > 0 then
			frame.Size = UDim2.new(0,width - frame.AbsolutePosition.x,0,length)
		else
			frame.Size = UDim2.new(0,0,0,length)
		end
	end

	local function add(object)
		if object:IsA"GuiObject" then
			table.insert(children,object)
			connections[object] = object.Changed:connect(function(p)
				if p == "AbsoluteSize" or p == "Visible" then
					recalculate(object)
				end
			end)
			recalculate(object)
		end
	end

	in_con.add = frame.ChildAdded:connect(add)
	in_con.remove = frame.ChildRemoved:connect(function(child)
		if connections[child] then
			connections[child]:disconnect()
			connections[child] = nil
		end
		for i,v in pairs(children) do
			if v == child then
				table.remove(children,i)
				break
			end
		end
		recalculate()
	end)

	for _,child in pairs(frame:GetChildren()) do
		add(child)
	end
	recalculate()

	local function dispose()	-- undos everything
		for i,con in pairs(in_con) do
			con:disconnect()
			in_con[i] = nil
		end
		for i,v in pairs(children) do
			if connections[v] then
				connections[v]:disconnect()
				connections[v] = nil
			end
			children[i] = nil
		end
		for i,con in pairs(connections) do
			con:disconnect()
			connections[i] = nil
		end
		children = nil
		connections = nil
		in_con = nil
		recalculate = nil
		add = nil
		dispose = nil
	end

	return dispose
end

local InitData = {
	Main = {
		Tools = {};
		Menus = {};
		Controls = {};
		Commands = {};
	};
	Plugins = {
		Tools = {};
		Menus = {};
		Commands = {};
	};
}
ADR(InitData)

local ColorTags = {
	["h"] = Color3.new(0.6,0.6,1);
}

-- creates a description label for an object
local function SetupDescription(button,text)
	if text and #text > 0 then
		local desc = MakeGuiObject["description"]()
		desc.Parent = Screen
		for line in text:gmatch("[^\r\n]+") do
			local pad,para = MakeGuiObject["paragraph"]()
			pad.Parent = desc
			para.Size = UDim2.new(0,0,0,0)
			local tag,text = line:match("^{(.+)}(.-)$")
			if tag then
				local c = ColorTags[tag:lower()]
				if c then para.TextColor3 = c end
				para.Text = text
			else
				para.Text = line
			end
			local bounds = para.TextBounds
			local x,y = bounds.x,bounds.y
			if x > config.desc_width_max then
				x = config.desc_width_max
				y = 100*y
			end
			x,y = math.ceil(x),math.ceil(y)
			para.Position = UDim2.new(0,4,0,2)
			para.Size = UDim2.new(0,x,0,y)
			local tb = para.TextBounds
			tb = Vector2.new(math.ceil(tb.x),math.ceil(tb.y))
			para.Size = UDim2.new(0,tb.x,0,tb.y)
			pad.Size = UDim2.new(0,tb.x+8,0,tb.y+4)
		end
		desc.Visible = false
		desc.Name = button.Name.."Description"
		desc.Parent = DescriptionFrame
		ADR(MakeStackingList(desc))
		ButtonDescription[button] = desc
		ADR(button.MouseEnter:connect(function()
			if Mode.HelpModeEnabled then
				SetDescription(button,true)
			end
		end))
		ADR(button.MouseLeave:connect(function()
			if Mode.HelpModeEnabled then
				SetDescription(button,false)
			end
		end))
	end
end

local function SetupToolState(button)
	ADR(button.MouseButton1Click:connect(function()
		if ToolState[button] then
			DeselectTool(button)
		else
			SelectTool(button)
		end
	end))
end

local function SetupMenuState(menubutton,state)
	ADR(menubutton.MouseButton1Click:connect(function()
		ToggleMenu(menubutton)
	end))
end

local SetupValueState = {
	["field"] = function(button,state,safe)
		local stype = type(state)
		local function update(input)
			button.Text = tostring(input)
		end
		if stype == "string" then
			local vstate = {state,update}
			ValueState[button] = vstate
			ADR(button.Changed:connect(function(p)
				if p == "Text" then
					vstate[1] = button.Text
				end
			end))
			button.Text = vstate[1]
		elseif stype == "number" then
			local vstate = {state,update}
			ValueState[button] = vstate
			ADR(button.Changed:connect(function(p)
				if p == "Text" then
					local check = tonumber(button.Text)
					if check then
						vstate[1] = check
					else
						button.Text = vstate[1]
					end
				end
			end))
			button.Text = vstate[1]
		elseif stype == "boolean" then
			local vstate = {state,update}
			ValueState[button] = vstate
			ADR(button.Changed:connect(function(p)
				if p == "Text" then
					local check = button.Text:lower()
					if check == "false" or check == "0" then
						vstate[1] = false
					elseif check == "true" or check == "1" then
						vstate[1] = true
					else
						button.Text = vstate[1] and "true" or "false"
					end
				end
			end))
			button.Text = state[1] and "true" or "false"
		elseif stype == "table" then
			local vstate = {state[1],update}
			ValueState[button] = vstate
			local func = state[2]
			local env = {}; ADR(env,true)
			for i,v in pairs(Environment.Listener.Global.Safe) do
				env[i] = v
			end
			if not safe then
				for i,v in pairs(Environment.Listener.Global.Unsafe) do
					env[i] = v
				end
			end
			if safe then
				setmetatable(env,{__newindex = function(t,k) error("Cannot set value \""..tostring(k).."\"",2) end})
			end
			setfenv(func,env)
			local con = button.Changed:connect(function(p)
				if p == "Text" then
					local e,s,v = pcall(func,button.Text)
					if e then
						if s then
							vstate[1] = v
						else
							button.Text = tostring(vstate[1])
						end
					else
						con:disconnect(); RDR(con)
						vstate[2] = function()end
						LogError("Field \"",button.Name,"\" listener: ",s)
						LogWarning("Disconnected listener from field \"",button.Name,"\"")
					end
				end
			end)
			ADR(con)
			button.Text = tostring(state[1])
		end
	end;
	["label"] = function(button,state)
		local vstate = {state,function(input)
			button.Text = tostring(input)
		end}
		ValueState[button] = vstate
		ADR(button.Changed:connect(function(p)
			if p == "Text" then
				vstate[1] = button.Text
			end
		end))
		button.Text = state
	end;
	["toggle"] = function(button,state)
		local vstate = {state,function(input)
			if type(input) == "boolean" then
				vstate[1] = input
				button.Selected = input
			end
		end}
		ValueState[button] = vstate
		ADR(button.MouseButton1Click:connect(function()
			local state = not vstate[1]
			vstate[1] = state
			button.Selected = state
		end))
		button.Selected = state
	end;
}

local MakeButton
MakeButton = {
	["tool"] = function(info)
		return MakeGuiObject["tool"](info[1],info[3])
	end;
	["field"] = function(info)
		if type(info[3]) == "table" then
			return MakeGuiObject["field"](info[1],info[3][1])
		else
			return MakeGuiObject["field"](info[1],info[3])
		end
	end;
	["label"] = function(info)
		return MakeGuiObject["label"](info[1],info[3])
	end;
	["toggle"] = function(info)
		return MakeGuiObject["toggle"](info[1],info[3],info[4] and tostring(info[4]) or info[1])
	end;
	["container"] = function(info,data,id)
		local container = MakeGuiObject["container"](info[1])
		local n = #info[3]
		for i,sub in pairs(info[3]) do
			local button = MakeButton[sub[2]](sub,data,id)
			SetupDescription(button,data.ButtonDescription[sub[1]])
			button.Size = UDim2.new(1/n,0,1,0)
			button.Position = UDim2.new((i-1)/n,0,0,0)
			button.Parent = container
			if SetupValueState[sub[2]] then
				SetupValueState[sub[2]](button,sub[3],data.SafeMode)
			end
			id[sub[1]] = button
		end
		return container
	end;
}

local function PositionButtonsAsGrid(tools,l)
	local x,y = 0,0
	local sx,sy = 0,0
	for i=1,#tools do
		tools[i].Position = UDim2.new(x,0,y,0)
		sx = x > sx-1 and x+1 or sx
		sy = y > sy-1 and y+1 or sy
		if (i-1)%l+1 == l then
			x = x + 1
			y = 0
		else
			y = y + 1
		end
	end
	return sx,sy
end

local InitDataType
InitDataType = {
	["tool"] = function(data,ref)
		for i,v in pairs(data.Resources) do
			if IsContent(v) then
				ContentProvider:Preload(v)
			end
		end
		local button = MakeGuiObject["tool"](data.Name,data.Text)
		ToolState[button] = false
		ToolWarnings[button] = data.Warnings
		ToolSafeMode[button] = data.SafeMode
		SetupDescription(button,data.Description)
		ToolSelectListener[button] = data.SelectListener
		local env = {}; ADR(env,true)
		local metadata = {
			Button = button;
			ID = data.Name;
			Resource = data.Resources;
			Warnings = data.Warnings;
			Connections = {};
			Overlay = {};
			Env = env;
			PreviousTool = nil;
		}
		ADR(metatdata)
		ToolEnvMetadata[env] = metadata
		ToolButtonMetadata[button] = metadata
		if data.BuiltIn then
			for i,v in pairs(Environment.BuiltIn) do
				env[i] = v
			end
		end
		for i,v in pairs(Environment.Listener.Global.Safe) do
			env[i] = v
		end
		for i,v in pairs(Environment.Listener.API.Safe) do
			env[i] = v
		end
		if not data.SafeMode then
			for i,v in pairs(Environment.Listener.Global.Unsafe) do
				env[i] = v
			end
			for i,v in pairs(Environment.Listener.API.Unsafe) do
				env[i] = v
			end
		end
		if data.SafeMode then
			setmetatable(env,restrict_mt)
		end
		setfenv(data.SelectListener,env)
		if data.DeselectListener then
			ToolDeselectListener[button] = data.DeselectListener
			setfenv(data.DeselectListener,env)
		end
		SetupToolState(button)
		local key = data.ShortcutKey
		if key then
			if Shortcut[key] then
				LogWarning("Tool \""..data.Name.."\": shortcut key \""..key.."\" was already bound")
			else
				Shortcut[key] = button
			end
		end
		ref[data.Name] = button
		return button,metadata
	end;
	["menu"] = function(data,ref)
		for i,v in pairs(data.Resources) do
			if IsContent(v) then
				ContentProvider:Preload(v)
			end
		end
		local id = {}
		ref[data.Name] = id
		local menubutton = MakeGuiObject["menubutton"](data.Name.."MenuButton",data.MenuText)
		local menu = MakeGuiObject["menu"](data.Name.."Menu",0,0)
		SetupDescription(menubutton,data.MenuDescription)
		menu.Visible = false
		id.MenuButton = menubutton
		id.Menu = menu
		local tools = {}; ADR(tools)
		ToolsFromMenu[menu] = tools
		local mds = {}
		local X,Y = 0,#data.MenuLayout
		for y,row in pairs(data.MenuLayout) do
			for x,info in pairs(row) do
				local button
				if info[2] == "tool" then
					local tdata = {
						Name = info[1];
						Type = "tool";
						SafeMode = data.SafeMode;
						BuiltIn = data.BuiltIn;
						Resources = data.Resources;
						Text = info[3];
						SelectListener = data.SelectListener[info[1]];
						DeselectListener = data.DeselectListener[info[1]];
						Description = data.ButtonDescription[info[1]];
						Warnings = data.ToolWarnings[info[1]];
						ShortcutKey = data.ShortcutKey[info[1]];
					}
					ADR(tdata)
					button,md = InitDataType["tool"](tdata,id)
					table.insert(tools,button)
					MenuFromTool[button] = menubutton
					table.insert(mds,md)
				else
					button = MakeButton[info[2]](info,data,id)
					if SetupValueState[info[2]] then
						SetupValueState[info[2]](button,info[3],data.SafeMode)
					end
					SetupDescription(button,data.ButtonDescription[info[1]])
					id[info[1]] = button
				end
				button.Position = UDim2.new(x-1,0,y-1,0)
				button.Parent = menu.Items
				X = x > X and x or X
			end
		end
		-- add the list of ids to buttons to each tool's metadata
		for _,md in pairs(mds) do
			md.ButtonFromId = id
		end
		menu.Size = UDim2.new(0,X*config.button_size_x,0,Y*config.button_size_y)
		local state = {false;menu}; ADR(state)
		MenuState[menubutton] = state
		SetupMenuState(menubutton)
		menubutton.Parent = Div
		menu.Parent = Div
	end;
	["command"] = function(data,ref,doc,help)
		for i,v in pairs(data.Resources) do
			if IsContent(v) then
				ContentProvider:Preload(v)
			end
		end
		if ref[data.CommandName] then
			LogError("Command \"",data.CommandName,"\" already exists")
		else
			local env = {}; ADR(env,true)
			local metadata = {
				Resource = data.Resources;
			}
			ADR(metadata)
			CommandEnvMetadata[env] = metadata
			if data.BuiltIn then
				for i,v in pairs(Environment.BuiltIn) do
					env[i] = v
				end
			end
			for i,v in pairs(Environment.Command.Global.Safe) do
				env[i] = v
			end
			for i,v in pairs(Environment.Command.API.Safe) do
				env[i] = v
			end
			if not data.SafeMode then
				for i,v in pairs(Environment.Command.Global.Unsafe) do
					env[i] = v
				end
				for i,v in pairs(Environment.Command.API.Unsafe) do
					env[i] = v
				end
			end
			setfenv(data.CommandFunction,env)
			local h = {name = data.Name}
			if data.ArgDoc then
				h.args = data.CommandName..data.ArgDoc
				table.insert(doc,data.CommandName..data.ArgDoc)
			else
				h.args = data.CommandName.."( )"
				table.insert(doc,data.CommandName.."( )")
			end
			local d = {}
			if data.Description then
				for line in data.Description:gmatch("[^\r\n]+") do
					table.insert(d,line)
				end
			end
			h.desc = d
			help[data.CommandName] = h
			help[data.CommandFunction] = h
			ref[data.CommandName] = data.CommandFunction
		end
	end;
	["control"] = function(data,ref)
		for i,v in pairs(data.Resources) do
			if IsContent(v) then
				ContentProvider:Preload(v)
			end
		end
		ContentProvider:Preload(data.ControlIcon)
		local control = MakeGuiObject["controlbutton"](data.ControlName,data.ControlIcon)
		for i,v in pairs(data.Resources) do
			Resource[i] = v
		end
		ref[data.Name] = control
		local listener = data.ControlListener
		if listener then
			setfenv(listener,Environment.BuiltIn)
			control.MouseButton1Click:connect(listener)
		end
		SetupDescription(control,data.Description)
		ControlData[control] = data
		local key = data.ShortcutKey
		if key then
			if Shortcut[key] then
				LogWarning("Control \""..data.Name.."\": shortcut key \""..key.."\" was already bound")
			else
				Shortcut[key] = control
			end
		end
		return control
	end;
}

-- uses element data to generate the panel's meat
local function InitializePanel()
	wait(1) -- give gui time to initialize abs size/pos
	-- create title
	Title = MakeGuiObject["title"]()
	Title.Text = "CmdUtl"
	Title.Parent = Div
	-- Change title text based on size; neat!
	ADR(Title.Changed:connect(function(p)
		if p == "AbsoluteSize" then
			Title.Text = "Command Utility"
			if not Title.TextFits then
				Title.Text = "CmdUtl"
			end
		end
	end))
	-- create frame for description
	DescriptionFrame = MakeGuiObject["descframe"]()
	DescriptionFrame.Parent = Div
	-- create control frame
	if #InitData.Main.Controls > 0 then
		local controlframe = MakeGuiObject["controlframe"]()
		for i,data in pairs(InitData.Main.Controls) do
			local control = InitDataType["control"](data,Control)
			control.Position = UDim2.new(0,0,i-1,0)
			control.Parent = controlframe
		end
		controlframe.Parent = Div
	end
	-- create menus for main tools
	for i,data in pairs(InitData.Main.Menus) do
		InitDataType["menu"](data,ID)
	end
	-- create menu for other tools
	if #InitData.Main.Tools > 0 then
		local tools = {}; ADR(tools)
		local id = {}; ADR(id)
		ID.Other = id
		for i,data in pairs(InitData.Main.Tools) do
			local button = InitDataType["tool"](data,id)
			table.insert(tools,button)
		end
		local sx,sy = PositionButtonsAsGrid(tools,config.tool_menu_length)
		local menubutton = MakeGuiObject["menubutton"]("OtherMenuButton","Other")
		local menu = MakeGuiObject["menu"]("OtherMenu",sx*config.button_size_x,sy*config.button_size_y)
		SetupDescription(menubutton,"{h}Other Menu\nContains miscellaneous tools.")
		menu.Visible = false
		id.MenuButton = menubutton
		id.Menu = menu
		for i,tool in pairs(tools) do
			tool.Parent = menu.Items
			MenuFromTool[tool] = menubutton
		end
		ToolsFromMenu[menu] = tools
		local state = {false;menu}; ADR(state)
		MenuState[menubutton] = state
		SetupMenuState(menubutton,state)
		menubutton.Parent = Div
		menu.Parent = Div
	end
	-- create menu for plugin tools
	if #InitData.Plugins.Tools > 0 then
		local tools = {}; ADR(tools)
		local id = {}; ADR(id)
		ID.PluginTools = id
		for i,data in pairs(InitData.Plugins.Tools) do
			local button = InitDataType["tool"](data,id)
			table.insert(tools,button)
		end
		local sx,sy = PositionButtonsAsGrid(tools,config.tool_menu_length)
		local menubutton = MakeGuiObject["menubutton"]("PluginToolsMenuButton","Plugins")
		local menu = MakeGuiObject["menu"]("PluginToolsMenu",sx*config.button_size_x,sy*config.button_size_y)
		SetupDescription(menubutton,"{h}Plugin Menu\nContains tools generated by plugins.")
		menu.Visible = false
		id.MenuButton = menubutton
		id.Menu = menu
		for i,tool in pairs(tools) do
			tool.Parent = menu.Items
			MenuFromTool[tool] = menubutton
		end
		ToolsFromMenu[menu] = tools
		local state = {false;menu}; ADR(state)
		MenuState[menubutton] = state
		SetupMenuState(menubutton,state)
		menubutton.Parent = Div
		menu.Parent = Div
	end
	-- make plugin menus
	if #InitData.Plugins.Menus > 0 then
		-- add a seperator
		local sep = MakeGuiObject["seperator"]()
		sep.Parent = Div
		ID.Plugins = {}; ADR(ID.Plugins)
		-- add the menus
		for i,data in pairs(InitData.Plugins.Menus) do
			InitDataType["menu"](data,ID.Plugins)
		end
	end
	-- start div
	Mode.DivTweenEnabled = false
	ADR(MakeDiv(Div))
	Mode.DivTweenEnabled = true
	-- start up shortcut keys
	if config.shortcut_keys_enabled then
		local go = false
		for key in pairs(Shortcut) do
			go = true
			GuiService:AddKey(key)
		end
		if go then
			ADR(GuiService.KeyPressed:connect(function(key)
				local button = Shortcut[key]
				if button then
					if ToolState[button] ~= nil then
						if Mode.PanelExpanded then
							if ToolState[button] then
								DeselectTool(button)
								if config.menu_auto_collapse then
									ToggleMenu(MenuFromTool[button],false)
								end
							else
								SelectTool(button)
								ToggleMenu(MenuFromTool[button],ToolState[button])
							end
						end
					elseif ControlData[button] then
						ControlData[button].ControlListener()
					end
				end
			end))
		end
	end
end

local CommandShortcuts = {
	G	= game;
	W	= game:GetService("Workspace");
	P	= game:GetService("Players");
	L	= game:GetService("Lighting");
	S	= game:GetService("Selection");
	IS	= game:GetService("InsertService");
	BS	= game:GetService("BadgeService");
	CS	= game:GetService("CollectionService");
	SC	= game:GetService("ScriptContext");
	CP	= game:GetService("ContentProvider");
	CG	= game:GetService("CoreGui");
	JS	= game:FindFirstChild("JointsService");
	D	= game:GetService("Debris");
	SP	= game:GetService("StarterPack");
	SG	= game:GetService("StarterGui");
	SS	= game:GetService("SoundService");
	RS	= game:GetService("RunService");
}
ADR(CommandShortcuts,true)

local function InitializeCommands()
	local Doc = {}; ADR(Doc)
	local Help = {}; ADR(Help)
	Commands["list"] = function()
		for _,line in pairs(Doc) do
			print(line)
		end
	end;
	Help["list"] = {
		name = "ListCommands";
		args = "list( )";
		desc = {"Shows a list of commands with their possible arguments, along with any shortcut variables."};
	}
	Help[Commands["list"]] = Help["list"]
	Commands["help"] = function(f)
		ft = type(f)
		if ft == "nil" then
			local ordered = {}
			for i in pairs(Help) do
				if type(i) == "string" then
					table.insert(ordered,i)
				end
			end
			table.sort(ordered)
			print("---- Type \"help(command)\" for help on that specific command.")
			for i,v in pairs(ordered) do
				local line = Help[v].desc[1]
				if line then
					print(v .. " : " .. line)
				else
					print(v)
				end
			end
		else
			local h = Help[f]
			if h then
				if #h.desc > 0 then
					print("---- Command \""..h.name.."\" ----------------")
					if h.args then print("> "..h.args) end
					for i,v in pairs(h.desc) do
						print(v)
					end
				else
					print("No help information was found for \""..f.."\".")
				end
			else
				print("\""..tostring(f).."\" is not a valid command.")
			end
		end
	end;
	Help["help"] = {
		name = "Help";
		args = "help( * command = nil )";
		desc = {"Shows help information for a command.";"'command' may be a string (the command's name), or a function (the command function itself).";"If 'command' is not specified, then a list of possible commands will be displayed."};
	}
	Help[Commands["help"]] = Help["help"]
	Commands["close"] = function()
		DisposeResources()
	end;
	Help["close"] = {
		name = "CloseCmdUtl";
		args = "close( )";
		desc = {"Closes CmdUtl.";"nMost resources taken up by CmdUtl are released and collected."};
	}
	Help[Commands["help"]] = Help["help"]
	table.insert(Doc,[[---- Commands ----------------]])
	table.insert(Doc,[[list( )]])
	table.insert(Doc,[[help( string command = nil )]])
	table.insert(Doc,[[close( )]])
	for i,v in pairs(CommandShortcuts) do
		Commands[i] = v
	end
	for i,data in pairs(InitData.Main.Commands) do
		InitDataType["command"](data,Commands,Doc,Help)
	end
	for i,data in pairs(InitData.Plugins.Commands) do
		InitDataType["command"](data,Commands,Doc,Help)
	end
	table.insert(Doc,[[---- Shortcut Variables ----------------]])
	-- alphabetize shortcut docs
	local shortcuts = {}
	for i in pairs(CommandShortcuts) do
		table.insert(shortcuts,i)
	end
	table.sort(shortcuts)
	for _,i in pairs(shortcuts) do
		local v = CommandShortcuts[i]
		table.insert(Doc,i .. " = " .. v.className)
	end

	local CommandEnv
	
	local function add()
		CommandEnv = getfenv(2)
		for i,v in pairs(Commands) do
			CommandEnv[i] = v
		end
		print [[---- CmdUtl has been loaded --------------------------------]]
		print [[-- Type "list()" for a list of commands]]
		print [[-- or "help()" for help on commands]]
	end
	
	local function dispose()
		if CommandEnv then
			for i,v in pairs(Commands) do
				if CommandEnv[i] == v then
					CommandEnv[i] = nil
				end
				Commands[i] = nil
			end
		end
	end
	ADR(dispose)

	settings().Diagnostics:LegacyScriptMode()
	game:GetService("ScriptContext"):SetCollectScriptStats(true)
	game:GetService("InsertService"):SetFreeModelUrl("http://www.roblox.com/Game/Tools/InsertAsset.ashx?type=fm&q=%s&pg=%d&rs=%d")
	game:GetService("InsertService"):SetFreeDecalUrl("http://www.roblox.com/Game/Tools/InsertAsset.ashx?type=fd&q=%s&pg=%d&rs=%d")
	
	_G.CmdUtl = add
	_G.cu = add
	_G.CloseCmdUtl = function()
		DisposeResources()
	end
end

local AddInitDataType = {
	["tool"] = function(data,built_in)
		if built_in then
			table.insert(InitData.Main.Tools,data)
		else
			table.insert(InitData.Plugins.Tools,data)
		end
	end;
	["menu"] = function(data,built_in)
		if built_in then
			table.insert(InitData.Main.Menus,data)
		else
			table.insert(InitData.Plugins.Menus,data)
		end
	end;
	["control"] = function(data)
		table.insert(InitData.Main.Controls,data)
	end;
	["command"] = function(data,built_in)
		if built_in then
			table.insert(InitData.Main.Commands,data)
		else
			table.insert(InitData.Plugins.Commands,data)
		end
	end;
}
ADR(AddInitDataType)

function BuildElement(data,built_in)
	if not built_in then
		PluginDataFromName[data.Name] = data
		PluginResources[data.Name] = data.Resources
	end
	for key,value in pairs(data.Resources) do
		if type(value) == "string" then
			if IsContent(value) then
				ContentProvider:Preload(value)
			end
		end
	end
	AddInitDataType[data.Type](data,built_in)
end

local HandleButtonInfo

local button_type = {
	["tool"] = function(value)
		if type(value) ~= "string" then return false,"must be a string" end
		return true
	end;
	["field"] = function(value)
		local vtype = type(value)
		if vtype ~= "string" and vtype ~= "number" and vtype ~= "boolean" and vtype ~= "table" then
			return false,"must be a string, number, or boolean"
		elseif vtype == "table" then
			if type(value[2]) ~= "function" then
				return false,"2nd entry in table must be a function"
			end
		end
		return true
	end;
	["label"] = function(value)
		if type(value) ~= "string" then return false,"must be a string" end
		return true
	end;
	["toggle"] = function(value)
		if type(value) ~= "boolean" then return false,"must be a boolean" end
		return true
	end;
	["container"] = function(value,uids)
		if type(value) ~= "table" then return false,"must be a table" end
		if not IsArray(value) then return false,"must be an array" end
		for i,button in pairs(value) do
			local e,o = HandleButtonInfo(button,uids,{"tool";"container"})
			if not e then
				return false,o
			end
		end
		return true
	end;
}
ADR(button_type)

HandleButtonInfo = function(button,uids,invalid_types)
	local id,btype,value = button[1],button[2],button[3]
	if type(id) ~= "string" then return false,"1st index of button info must be a string (ButtonId)" end
	if #id == 0 then return false,"ButtonId cannot have 0 characters" end
	if uids[id] then return false,"Button \""..id.."\" already exists" end
	if id == "Menu" or id == "MenuButton" then return false,"ButtonId cannot be \"Menu\" or \"MenuButton\"" end
	if type(btype) ~= "string" then return false,"2nd index of button info \""..id.."\" must be a string (ButtonType)" end
	button[2] = btype:lower()
	btype = button[2]
	invalid_types = invalid_types or {}
	local type_handle = button_type[btype]
	if type_handle and not invalid_types[btype] then
		local e,o = type_handle(value,uids)
		if e then
			uids[id] = button
			return true
		else
			return false,"3rd index of button info \""..id.."\" ("..btype.."):[ "..o.." ]"
		end
	else
		return false,"2nd index of button info \""..id.."\" is not a valid button type"
	end
end

local EnvMetadata = {}; ADR(EnvMetadata)

local function GetSourceMetadata()
	local env = getfenv(3)
	local md = EnvMetadata[env]
	if not md then error("Invalid call",3) end
	if md.context.Validated then error("Function is no longer active",3) end
	return md.context,md.data
end

---- Source Processing Framework ------------

local SourceAPI = {}; ADR(SourceAPI)
--	contains declarations for processing the element source
--	comes in two parts:
--		Main: declares the initial environment that the source will use
--		Type: declares the environment added by SetPluginType

--	contexts: contexts that must be present in order to pass validation
--	data_init: initial data values that should be added when the environment is added
--	validate: custom validates the data; called by Validate
--	env: contains the functions that will be added to the source

SourceAPI.Type = {
	["tool"] = {
		contexts = {"ButtonText";"ToolSelect"};
		data_init = function() end;
		validate = function(data)
			if data.Name == "Menu" or data.Name == "MenuButton" then
				return false,"Tool cannot have a name of \"Menu\" or \"MenuButton\""
			else
				return true
			end
		end;
		env = {
			SetButtonText = function(text)
				local context,data = GetSourceMetadata()
				if context.ButtonText then error("$SetButtonText: Button text has already been set",2) end
				if type(text) ~= "string" then error("$SetButtonText: 1st argument must be a string",2) end
				data.Text = text
				context.ButtonText = true
			end;
			SetOnSelect = function(listener)
				local context,data = GetSourceMetadata()
				if context.ToolSelect then error("$SetOnSelect: Selection has already been set",2) end
				if type(listener) ~= "function" then error("$SetOnSelect: 1st argument must be a function",2) end
				data.SelectListener = listener
				context.ToolSelect = true
			end;
			SetOnDeselect = function(listener)
				local context,data = GetSourceMetadata()
				if context.ToolDeselect then error("$SetOnDeselect: Deselection has already been set",2) end
				if type(listener) ~= "function" then error("$SetOnDeselect: 1st argument must be a function",2) end
				data.DeselectListener = listener
				context.ToolDeselect = true
			end;
			SetDescription = function(desc)
				local context,data = GetSourceMetadata()
				if context.ToolDescription then error("$SetDescription: Description has already been set",2) end
				if type(desc) ~= "string" then error("$SetDescription: 1st argument must be a string",2) end
				data.Description = desc
				context.ToolDescription = true
			end;
			SetWarnings = function(warn)
				local context,data = GetSourceMetadata()
				if context.ToolWarnings then error("$SetWarnings: Warnings have already been set",2) end
				if type(warn) == "string" then
					warn = {warn}
				elseif type(warn) == "table" then
					if not IsArray(warn) then error("$SetWarnings: Table must be an array",2) end
					for i,v in pairs(warn) do
						if type(v) ~= "string" then error("$SetWarnings: Table may only contain strings",2) end
					end
				else
					error("$SetWarnings: 1st argument must be a string or table",2)
				end

				data.Warnings = warn
				context.ToolWarnings = true
			end;
			SetShortcutKey = function(key)
				local context,data = GetSourceMetadata()
				if context.ShortcutKey then error("$SetShortcutKey: Shortcut key has already been set",2) end
				if type(key) ~= "string" then error("$SetShortcutKey: 1st argument must be a string",2) end
				local map = shortcuts[key]
				if type(map) == "string" and #map == 1 then
					key = map
				end
				if #key == 1 then
					data.ShortcutKey = key
				end
				context.ShortcutKey = true
			end
		};
	};
	["menu"] = {
		contexts = {"MenuText";"MenuLayout"};
		data_init = function(data)
			data.SelectListener = {}
			data.DeselectListener = {}
			data.ButtonDescription = {}
			data.ToolWarnings = {}
			data.ShortcutKey = {}
		end;
		validate = function(context,data)
			local bids = data.ButtonIDs
			-- check if layout has all needed fields
			for id,button in pairs(bids) do
				local btype = button[2]
				if btype == "tool" then
					if not data.SelectListener[id] then return false,"Button \""..id.."\" (tool) does not have a tool select listener" end
				else
					if data.SelectListener[id] then return false,"Button \""..id.."\" ("..btype..") cannot have a tool select listener" end
					if data.DeselectListener[id] then return false,"Button \""..id.."\" ("..btype..") cannot have a tool deselect listener" end
					if data.ToolWarnings[id] then return false,"Button \""..id.."\" ("..btype..") cannot have tool warnings" end
					if data.ShortcutKey[id] then return false,"Button \""..id.."\" ("..btype..") cannot have a shortcut key" end
				end
			end
			-- check if fields have existing layout
			for id in pairs(data.SelectListener) do
				if not bids[id] then
					return false,"SetOnToolSelect: \""..id.."\" was not defined in layout"
				end
			end
			for id in pairs(data.DeselectListener) do
				if not bids[id] then
					return false,"SetOnToolDeselect: \""..id.."\" was not defined in layout"
				end
			end
			for id in pairs(data.ButtonDescription) do
				if not bids[id] then
					return false,"SetButtonDescription: \""..id.."\" was not defined in layout"
				end
			end
			for id in pairs(data.ToolWarnings) do
				if not bids[id] then
					return false,"SetToolWarnings: \""..id.."\" was not defined in layout"
				end
			end
			for id in pairs(data.ShortcutKey) do
				if not bids[id] then
					return false,"SetToolShortcutKey: \""..id.."\" was not defined in layout"
				end
			end
			return true
		end;
		env = {
			SetMenuText = function(text)
				local context,data = GetSourceMetadata()
				if context.MenuText then error("$SetMenuText: Text has already been set",2) end
				if type(text) ~= "string" then error("$SetMenuText: 1st argument must be a string",2) end
				data.MenuText = text
				context.MenuText = true
			end;
			SetMenuDescription = function(desc)
				local context,data = GetSourceMetadata()
				if context.MenuDescription then error("$SetMenuDescription: Description has already been set",2) end
				if type(desc) ~= "string" then error("$SetMenuDescription: 1st argument must be a string",2) end
				data.MenuDescription = desc
				context.MenuDescription = true
			end;
			SetLayout = function(layout)
				local context,data = GetSourceMetadata()
				if context.MenuLayout then error("$SetLayout: Menu layout has already been set",2) end
				if type(layout) ~= "table" then error("$SetLayout: 1st argument must be a table",2) end
				if not IsArray(layout) then error("$SetLayout: Layout must be an array") end
				local unique_ids = {}
				for i,row in pairs(layout) do
					if type(row) ~= "table" then error("$SetLayout: Layout may only contain tables (rows)",2) end
					if not IsArray(row) then error("$SetLayout: Row ("..i..") must be an array",2) end
					for i,button in pairs(row) do
						local e,o = HandleButtonInfo(button,unique_ids)
						if not e then
							error("$SetLayout: "..o,2)
						end
					end
				end
				data.MenuLayout = layout
				data.ButtonIDs = unique_ids
				context.MenuLayout = true
			end;
			SetOnSelect = function(id, listener)
				local context,data = GetSourceMetadata()
				if type(id) ~= "string" then error("$SetOnSelect: 1st argument must be a string",2) end
				if data.SelectListener[id] then error("$SetOnSelect: The \""..id.."\" tool's selection has already been set",2) end
				if type(listener) ~= "function" then error("$SetOnSelect: 2nd argument must be a function",2) end
				data.SelectListener[id] = listener
			end;
			SetOnDeselect = function(id, listener)
				local context,data = GetSourceMetadata()
				if type(id) ~= "string" then error("$SetOnDeselect: 1st argument must be a string",2) end
				if data.DeselectListener[id] then error("$SetOnDeselect: The \""..id.."\" tool's deselection has already been set",2) end
				if type(listener) ~= "function" then error("$SetOnDeselect: 2nd argument must be a function",2) end
				data.DeselectListener[id] = listener
			end;
			SetButtonDescription = function(id, text)
				local context,data = GetSourceMetadata()
				if type(id) ~= "string" then error("$SetButtonDescription: 1st argument must be a string",2) end
				if data.ButtonDescription[id] then error("$SetButtonDescription: The \""..id.."\" button's description has already been set",2) end
				if type(text) ~= "string" then error("$SetButtonDescription: 2nd argument must be a string",2) end
				data.ButtonDescription[id] = text
			end;
			SetWarnings = function(id,warn)
				local context,data = GetSourceMetadata()
				if type(id) ~= "string" then error("$SetWarnings: 1st argument must be a string",2) end
				if data.ToolWarnings[id] then error("$SetWarnings: The \""..id.."\" tool's warnings have already been set",2) end
				if type(warn) == "string" then
					warn = {warn}
				elseif type(warn) == "table" then
					if not IsArray(warn) then error("$SetWarnings: Table must be an array",2) end
					for i,v in pairs(warn) do
						if type(v) ~= "string" then error("$SetWarnings: Table may only contain strings",2) end
					end
				else
					error("$SetWarnings: 2nd argument must be a string or table",2)
				end
				data.ToolWarnings[id] = warn
			end;
			SetShortcutKey = function(id,key)
				local context,data = GetSourceMetadata()
				if type(id) ~= "string" then error("$SetShortcutKey: 1st argument must be a string",2) end
				if data.ShortcutKey[id] then error("$SetShortcutKey: The \""..id.."\" tool's shortcut key has already been set",2) end
				if type(key) ~= "string" then error("$SetShortcutKey: 2nd argument must be a string",2) end
				local map = shortcuts[key]
				if type(map) == "string" and #map == 1 then
					key = map
				end
				if #key == 1 then
					data.ShortcutKey[id] = key
				end
			end;
		};
	};
	["command"] = {
		contexts = {"CommandName";"CommandFunction"};
		data_init = function()end;
		validate = function() return true end;
		env = {	
			SetCommandName = function(name)
				local context,data = GetSourceMetadata()
				if context.CommandName then error("$SetCommandName: Command name has already been set",2) end
				if type(name) ~= "string" then error("$SetCommandName: 1st argument must be a string",2) end
				if #name == 0 then error("$SetCommandName: 1st argument cannot have 0 characters",2) end
				if not IsVarName(name) then error("$SetCommandName: Name must contain only letters, numbers, and underscores, with the first character not being a number") end
				if #name > 16 then error("$SetCommandName: Name should not contain more than 16 characters",2) end
				data.CommandName = name
				context.CommandName = true
			end;
			SetFunction = function(func)
				local context,data = GetSourceMetadata()
				if context.CommandFunction then error("$SetFunction: Command function has already been set",2) end
				if type(func) ~= "function" then error("$SetFunction: 1st argument must be a function",2) end
				data.CommandFunction = func
				context.CommandFunction = true
			end;
			SetDescription = function(desc)
				local context,data = GetSourceMetadata()
				if context.Description then error("$SetDescription: Command description has already been set",2) end
				if type(desc) ~= "string" then error("$SetDescription: 1st argument must be a string",2) end
				data.Description = desc
				context.Description = true
			end;
			SetArgumentDoc = function(args)
				local context,data = GetSourceMetadata()
				if context.Arguments then error("$SetArgumentDoc: Argument documentation has already been set",2) end
				if type(args) ~= "table" then error("$SetArgumentDoc: 1st argument must be a table",2) end
				if not IsArray(args) then error("$SetArgumentDoc: Argument doc must be an array",2) end
				local doc = {}
				for i,arg in pairs(args) do
					if type(arg) ~= "table" then error("$SetArgumentDoc: Argument doc may only contain tables (args)",2) end
					local atype,name,default = arg[1],arg[2],arg[3]
					if type(atype) ~= "string" then error("$SetArgumentDoc: 1st entry to Argument must be a string",2) end
					if #atype == 0 then error("$SetArgumentDoc: 1st entry to Argument cannot have 0 characters",2) end
					if atype:match("*") then
						if #atype ~= 1 then
							error("$SetArgumentDoc: If 1st enty contains \"*\", it must have a length of 1",2)
						end
					elseif atype:match("[^%w _]") then
						error("$SetArgumentDoc: 1st entry contains invalid characters",2)
					end
					if #atype > 32 then error("$SetArgumentDoc: 1st entry to Argument cannot contain more than 32 characters",2) end
					if type(name) ~= "string" then error("$SetArgumentDoc: 2nd entry to Argument must be a string",2) end
					if #name == 0 then error("$SetArgumentDoc: 2nd entry to Argument cannot have 0 characters",2) end
					if not IsVarName(name) then error("$SetArgumentDoc: 2nd entry to Argument must contain only letters, numbers, and underscores, with the first character not being a number",2) end
					if #name > 16 then error("$SetArgumentDoc: 2nd entry to Argument cannot contain more than 16 characters",2) end
					local d = atype .. " " .. name
					if default ~= nil then
						if type(default) ~= "string" then error("$SetArgumentDoc: 3rd entry to Argument must be a string",2) end
						if default:match("%c") then error("$SetArgumentDoc: 3rd entry to Argument cannot contain non-printable characters",2) end
						if #default > 64 then error("$SetArgumentDoc: 3rd entry to Argument cannot contain more than 64 characters",2) end
						d = d .. " = " .. default
					end
					table.insert(doc,d)
				end
				local final = "( " .. table.concat(doc,", ") .. (#doc > 0 and " " or "") .. ")"
				data.ArgDoc = final
			end;
		};
	};
	["control"] = {
		contexts = {"ControlName";"ControlIcon"};
		data_init = function()end;
		validate = function(context,data)
			if data.BuiltIn then
				return true
			else
				return false,"Controls may only be built-in"
			end
		end;
		env = {
			SetControlName = function(name)
				local context,data = GetSourceMetadata()
				if context.ControlName then error("$SetControlName: Control name has already been set",2) end
				if type(name) ~= "string" then error("$SetControlName: 1st argument must be a string",2) end
				if #name == 0 then error("$SetControlName: 1st argument cannot have 0 characters",2) end
				data.ControlName = name
				context.ControlName = true
			end;
			SetDescription = function(desc)
				local context,data = GetSourceMetadata()
				if context.Description then error("$SetDescription: Control description has already been set",2) end
				if type(desc) ~= "string" then error("$SetDescription: 1st argument must be a string",2) end
				data.Description = desc
				context.Description = true
			end;
			SetIcon = function(icon)
				local context,data = GetSourceMetadata()
				if context.ControlIcon then error("$SetIcon: Control icon has already been set",2) end
				if not IsContent(icon) then error("$SetIcon: 1st argument must be a valid Content string",2) end
				data.ControlIcon = icon
				context.ControlIcon = true
			end;
			SetOnClick = function(listener)
				local context,data = GetSourceMetadata()
				if context.ControlListener then error("$SetOnClick: Control listener has already been set",2) end
				if type(listener) ~= "function" then error("$SetOnClick: 1st argument must be a function",2) end
				data.ControlListener = listener
				context.ControlListener = true
			end;
			SetShortcutKey = function(key)
				local context,data = GetSourceMetadata()
				if context.ShortcutKey then error("$SetShortcutKey: Shortcut key has already been set",2) end
				if type(key) ~= "string" then error("$SetShortcutKey: 1st argument must be a string",2) end
				local map = shortcuts[key]
				if type(map) == "string" and #map == 1 then
					key = map
				end
				if #key == 1 then
					data.ShortcutKey = key
				end
				context.ShortcutKey = true
			end
		};
	};
}
SourceAPI.Main = {
	contexts = {"PluginName";"PluginType"};
	data_init = function(data)
		data.Name = "<unknown>"
		data.SafeMode = true;
		data.Resources = {};
	end;
	validate = function(context,data)
		if context.Version then	-- if plugin has opted in to version control, verify plugin version
			local major,minor,revision,extra = version:match("^(%d+)%.(%d+)%.(%d+)(.-)$")
			local vmajor,vminor,vrevision,vextra = data.Version:match("^(%d+)%.(%d+)%.(%d+)(.-)$")
			if vmajor == major then	-- major matches
				if vminor == minor then	-- minor matches; success
					-- revisions do not need checking; they should always be compatible
					-- extra can be ignored; generally used for beta releases
					return true
				elseif vminor < minor then	-- minor less than; incompatible
					return false,"version "..data.Version.." is not compatible with the current version of CmdUtl ("..version..")"
				elseif vminor > minor then	-- minor greater than; possibly incompatible
					LogWarning("Plugin \""..data.Name.."\" (v"..data.Version..") may not be compatible with the current version of CmdUtl (v"..version..")")
				end
			elseif vmajor < major then	-- major thess than; incompatible
				return false,"version "..data.Version.." is not compatible with the current version of CmdUtl ("..version..")"
			elseif vmajor > major then	-- major greater than; possible incompatible
				LogWarning("Plugin \""..data.Name.."\" (v"..data.Version..") may not be compatible with the current version of CmdUtl (v"..version..")")
			end
		end
		return true
	end;
	env = {
		SetPluginName = function(name)
			local context,data = GetSourceMetadata()
			if context.PluginName then error("$SetPluginName: Plugin name has already been set",2) end
			if type(name) ~= "string" then error("$SetPluginName: 1st argument must be a string",2) end
			if #name == 0 then error("$SetPluginName: 1st argument cannot have 0 characters",2) end
			if not IsVarName(name) then error("$SetPluginName: 1st argument may only contain letters, numbers, and underscores, and cannot start with a number",2) end
			if PluginDataFromName[name] then error("$SetPluginName: There is already a plugin with the name of \""..name.."\"",2) end
			data.Name = name
			context.PluginName = true
		end;
		SetPluginType = function(extype)
			local context,data = GetSourceMetadata()
			if context.PluginType then error("$SetPluginType: Plugin type has already been set",2) end
			if type(extype) ~= "string" then error("$SetPluginType: 1st argument must be a string",2) end
			extype = extype:lower()
			local ctype = SourceAPI.Type[extype]
			if not ctype then error("$SetPluginType: "..extype.." is not a valid plugin type",2) end
			data.Type = extype
			ctype.data_init(data)
			local env = getfenv(2)
			for i,v in pairs(ctype.env) do
				env[i] = v
			end
			context.PluginType = true
		end;
		SetPluginSafe = function(safe)
			local context,data = GetSourceMetadata()
			if context.SafeMode then error("$SetPluginSafe: Safe mode has already been set",2) end
			if type(safe) ~= "boolean" then error("$SetPluginSafe: 1st argument must be a boolean",2) end
			data.SafeMode = safe
			if not safe then
				local env = getfenv(2)
				setmetatable(env,nil)
				for i,v in pairs(Environment.Source.Unsafe) do
					env[i] = v
				end
			end
			context.SafeMode = true
		end;
		AddResource = function(key,value)
			local context,data = GetSourceMetadata()
			if type(key) ~= "string" then error("$AddResource: 1st argument must be a string",2) end
			if data.Resources[key] then error("$AddResource: Index \""..key.."\" has already been added",2) end
			if type(value) == "function" then error("$AddResource: 2nd argument cannot be a function",2) end
			if type(value) == "thread" then error("$AddResource: 2nd argument cannot be a thread",2) end
			if type(value) == "nil" then error("$AddResource: 2nd argument cannot be nil",2) end
			data.Resources[key] = value
		end;
		SetVersion = function(vers)
			local context,data = GetSourceMetadata()
			if context.Version then error("$Version: Version has already been set",2) end
			if type(vers) ~= "string" then
				error("$Version: 1st argument must be a string or table",2)
			end
			if not vers:match("^%d+%.%d+%.%d+.-$") then
				error("$Version: \""..vers.."\" is not a valid version number")
			end
			data.Version = vers
			context.Version = true
		end;
		Validate = function()
			local context,data = GetSourceMetadata()
			for _,key in pairs(SourceAPI.Main.contexts) do
				if not context[key] then
					error("$Validate: validation failed (\""..tostring(key).."\" was not set)",2)
				end
			end
			local mval = SourceAPI.Main.validate
			local e,o = mval(context,data)
			if not e then
				error("$Validate: "..tostring(o),2)
			end
			for _,key in pairs(SourceAPI.Type[data.Type].contexts) do
				if not context[key] then
					error("$Validate: validation failed (\""..tostring(key).."\" was not set)",2)
				end
			end
			local tval = SourceAPI.Type[data.Type].validate
			local e,o = tval(context,data)
			if not e then
				error("$Validate: "..tostring(o),2)
			end
			context.Validated = true
		end;
	};
}

-- processes plugin sources and whatnot
function ProcessElementSource(init,built_in)
	local context = {}; ADR(context)	-- contains values for controlling what functions may and may no longer be called
	local data = {	-- contains the data generated by the source
		BuiltIn = built_in;
	}
	ADR(data)
	SourceAPI.Main.data_init(data)
	local env = {}; ADR(env,true)
	local metadata = {
		context = context;
		data = data;
	}
	ADR(metadata)
	EnvMetadata[env] = metadata
	for i,v in pairs(Environment.Source.Safe) do
		env[i] = v
	end
	for i,v in pairs(SourceAPI.Main.env) do
		env[i] = v
	end
	if built_in then
		for i,v in pairs(Environment.BuiltIn) do
			env[i] = v
		end
	end
	setmetatable(env,restrict_mt)
	setfenv(init,env)
	local e,o = pcall(init)
	if e then
		if context.Validated then
			if config.plugin_safe_mode then
				if data.SafeMode or built_in then	-- BuiltIn overrides SafeMode
					BuildElement(data,built_in)
				else
					LogWarning("Plugin:",data.Name," was not loaded because Safe Mode is on")
				end
			else
				BuildElement(data,built_in)
			end
		else
			LogError("Plugin ",data.Name,": plugin was not validated")
		end
	else
		LogError("Plugin ",data.Name,": "..o)
	end
	EnvMetadata[env] = nil
end

-- attempts to find plugin locations from 'plugins' table
local function GetPluginSources()
	local InsertService = game:GetService("InsertService")
	for _,id in pairs(plugins) do
		local children = {}
		-- gets children from asset or object path
		if IsPositiveInteger(id) then
			local asset = InsertService:LoadAsset(id)
			if asset then
				children = asset:GetChildren()
				asset.Parent = nil
			else
				LogError("plugin source: \"",id,"\": cannot access asset")
			end
		elseif pcall(function() return id:IsA"Instance" end) then	-- that type check would be useful
			children = {id}
		else
			LogError("plugin source: \"",id,"\": not an asset id or Object path")
		end
		-- if the 1st child is a model; make the children the model's children
		local first = children[1]
		if first then
			if first.className == "Model" or first.className == "Backpack" then
				if #children == 1 then
					local fchildren = first:GetChildren()
					if #fchildren > 0 then
						children = fchildren
					else
						LogError("plugin source: \"",id,"\": model does not contain any scripts")
					end
				else
					LogError("plugin source: \"",id,"\": model contains invalid objects")
				end
			end
		else
			LogError("plugin source: \"",id,"\": model contains no objects")
		end
		-- finally process children
		for _,child in pairs(children) do
			if child.className == "Script" then
				if #child:GetChildren() == 0 then
					local func,msg = loadstring(child.Source,"")
					if func then
						ProcessElementSource(func)
					else
						LogError("plugin source: \"",id,"\": syntax error: ",msg)
					end
				else
					LogError("plugin source: \"",id,"\": model contains invalid objects")
				end
			else
				LogError("plugin source: \"",id,"\": model contains invalid objects")
			end
		end

	end
end

local HandleConnection
local HandleObject
local HandleTable

local function LimitRecurse(item)
	if item ~= getfenv() then
		for i,v in pairs(item) do
			if type(v) == "table" then
				LimitRecurse(v)
			end
			item[i] = nil
		end
	end
end

local function LimitedHandle(item)
	local itype = type(item)
	if itype == "userdata" then
		if pcall(function() return item.disconnect end) then	-- Connection
			item:disconnect()
		else	-- try Instance
			pcall(item.Remove,item)
		end
	elseif itype == "table" and item ~= getfenv() then	-- table
		for i,v in pairs(item) do
			item[i] = nil
		end
	end
end

local function GetHandle(item)
	local itype = type(item)
	if itype == "userdata" then
		if pcall(function() return item.GetChildren end) then	-- Instance
			return HandleObject
		elseif pcall(function() return item.disconnect end) then	-- Connection
			return HandleConnection
		end
	elseif itype == "table" then	-- table
		return HandleTable
	end
end

HandleConnection = function(item)
	item:disconnect()
end

HandleObject = function(item)
	pcall(item.Remove,item)
end

HandleTable = function(item,dis)
	if item ~= getfenv() then
		for i,v in pairs(item) do
			if type(v) == "function" and dis then
				v()	-- call custom disposal function
			end
			local handle = GetHandle(v)
			if handle then handle(v) end
			item[i] = nil
		end
	end
end


-- attempts to get rid of everything
function DisposeResources()
	-- deselect tools
	for button,b in pairs(ToolState) do
		if b then
			DeselectTool(button)
		end
	end
	-- activate disposal management
	for _,item in pairs(Disposal.limited) do
		LimitedHandle(item)
	end
	HandleTable(Disposal.normal,true)
	-- clear out command env
	if CommandEnv then
		for i,v in pairs(Commands) do
			if CommandEnv[i] == v then
				CommandEnv[i] = nil
			end
		end
	end
	_G.CmdUtl = nil
	_G.cu = nil
	_G.CloseCmdUtl = nil
	-- clear out top env
	local env = getfenv()
	for i in pairs(env) do
		env[i] = nil
	end
	-- attempt to collect garbage
	pcall(collectgarbage)
	-- all done!
	print("CmdUtl removed")
end

---- Generate built-in goods ------------

-- controls
ProcessElementSource(function()
	SetPluginName("Expand")
	SetPluginType("control")
	SetControlName("ExpandButton")
	SetDescription("{h}Show/Hide Panel\nShows or hides the Utility Panel.")
	SetIcon("http://www.roblox.com/asset/?id=54479709")
	AddResource("collapse_icon","http://www.roblox.com/asset/?id=54479709")
	AddResource("expand_icon","http://www.roblox.com/asset/?id=54479716")
	SetShortcutKey("Control.Expand")
	SetOnClick(function()
		if Mode.Enabled then
			Mode.Enabled = false
			Mode.PanelExpanded = not Mode.PanelExpanded
			for _,desc in pairs(ButtonDescription) do
				desc.Visible = false
			end
			for button,b in pairs(ToolState) do
				if b then
					DeselectTool(button)
				end
			end
			if Mode.PanelExpanded then
				if config.tween_panel_enabled then
					Panel:TweenPosition(UDim2.new(0,0,0.05,0),"Out","Quad",config.tween_speed,true,function()
						Control.Expand.Image = Resource.collapse_icon
						Mode.Enabled = true
					end)
				else
					Control.Expand.Image = Resource.collapse_icon
					Panel.Position = UDim2.new(0,0,0.05,0)
					Mode.Enabled = true
				end
			else
				if config.tween_panel_enabled then
					Panel:TweenPosition(UDim2.new(0,-Div.AbsoluteSize.x,0.05,0),"Out","Quad",config.tween_speed,true,function()
						Control.Expand.Image = Resource.expand_icon
						Mode.Enabled = true
					end)
				else
					Panel.Position = UDim2.new(0,-Div.AbsoluteSize.x,0.05,0)
					Control.Expand.Image = Resource.expand_icon
					Mode.Enabled = true
				end
			end
		end
	end)
	Validate()
end,true)

ProcessElementSource(function()
	SetPluginName("Help")
	SetPluginType("control")
	SetControlName("HelpButton")
	SetDescription("{h}Help\nToggles Help Mode.\nIf Help Mode is on, descriptions will be displayed when a button is hovered over.")
	SetIcon("http://www.roblox.com/asset/?id=54479720")
	SetShortcutKey("Control.Help")
	SetOnClick(function()
		for _,desc in pairs(ButtonDescription) do
			desc.Visible = false
		end
		if Mode.HelpModeEnabled then
			Control.Help.BackgroundColor3 = Resource.control_color
			Mode.HelpModeEnabled = false
		else
			Control.Help.BackgroundColor3 = Resource.control_selected_color
			Mode.HelpModeEnabled = true
		end
	end)
	Validate()
end,true)

ProcessElementSource(function()
	SetPluginName("Close")
	SetPluginType("control")
	SetControlName("CloseButton")
	SetDescription("{h}Close\nCloses CmdUtl.\nThis includes the Utility Panel and Command functions.\nMost resources taken up by CmdUtl are released and collected.")
	SetIcon("http://www.roblox.com/asset/?id=54479706")
	SetOnClick(function() DisposeResources() end)
	Validate()
end,true)

-- tools and menus

ProcessElementSource(function()
	SetPluginName("Move")
	SetPluginType("menu")
	SetMenuText("Movement")
	SetMenuDescription("{h}Movement Menu\nContains tools for moving parts around.")

	AddResource("HandleColor",BrickColor.new("Br. yellowish orange"))
	AddResource("SnapSound","rbxasset://Sounds/snap.wav")

	SetLayout{
		{	-- row 1
			{"Inc","field",0.1};
			{"AxisSnap","container",{
				{"XButton","toggle",true,"X"};
				{"YButton","toggle",true,"Y"};
				{"ZButton","toggle",true,"Z"};
			}}
		};
		{	-- row 2
			{"AxisButton","tool","Axis"};
			{"AxisSnapButton","tool","Snap"};
		};
		{	-- row 3
			{"FirstButton","tool","First"};
			{"FirstSnapButton","tool","Snap"};
		};
		{	-- row 4
			{"ObjectButton","tool","Object"};
			{"Delta","label","0"};
		};
	}

	SetButtonDescription("AxisButton","{h}Move on Axis\nThis tool moves parts on the world axis.\nWhen selected, axis-aligned Handles will appear around all selected parts. When dragged, all the parts will move on the world axis.\nWhen dragging, parts will be snapped by the current Movement Increment.")
	SetButtonDescription("AxisSnapButton","{h}Snap on Axis\nThis tool rounds the position of all selected parts to the nearest Movement Increment. This tool depends on the Axis Lock toggle buttons.\nFor example, if a part has a position of (2.6, 3.4, 3.8), and the Movement Increment were 2, it would get snapped to (2, 4, 4). If the Y Axis Lock was deselected, it would be round to (2, 3.4, 4), ignoring the Y axis.")
	SetButtonDescription("FirstButton","{h}Move by First\nThis tool moves parts based on the rotation of one part.\nWhen selected, part-aligned Handles will appear around the first selected part. When dragged, the first part will move in the direction of its rotation, and all other parts will move relative to it.\nFor example, if the first part faced upward and to the left, not only would it be dragged upward and left, but so would every other part.")
	SetButtonDescription("FirstSnapButton","{h}Snap by First\nThis tool is very similar to the Snap on Axis tool. The only difference is that only the first selection gets snapped. The rest of the selection is moved relative to that part.")
	SetButtonDescription("ObjectButton","{h}Move by Object\nThis tool moves parts in the direction of their rotation. When selected, part-aligned Handles will appear around the first selection. When dragged, every part will move based only on it's own rotation, independant of any other part.")
	SetButtonDescription("Inc","{h}Movement Increment\nThis number defines how many studs to snap by when moving parts. For example, if it were 3, parts would move every 3 studs.\nIt is used to tell what to round a part's position by when using a snap tool. For example, if it were 3, a part's position would round to the nearest 3rd.")
	SetButtonDescription("XButton","{h}X Axis Lock\nThis button toggles whether the X axis will be considered when using a snap tool. If selected, parts will be snapped on the X axis. If not selected, snapping is ignored on the X axis.")
	SetButtonDescription("YButton","{h}Y Axis Lock\nThis button toggles whether the Y axis will be considered when using a snap tool. If selected, parts will be snapped on the Y axis. If not selected, snapping is ignored on the Y axis.")
	SetButtonDescription("ZButton","{h}Z Axis Lock\nThis button toggles whether the Z axis will be considered when using a snap tool. If selected, parts will be snapped on the Z axis. If not selected, snapping is ignored on the Z axis.")
	SetButtonDescription("Delta","{h}Movement Delta\nThis number displays the distance that parts have been dragged, in studs.")

	SetWarnings("AxisButton","No parts selected")
	SetWarnings("AxisSnapButton","No parts selected")
	SetWarnings("FirstButton","No parts selected")
	SetWarnings("FirstSnapButton","No parts selected")
	SetWarnings("ObjectButton","No parts selected")

	SetShortcutKey("AxisButton","Move.Axis")
	SetShortcutKey("AxisSnapButton","Move.AxisSnap")
	SetShortcutKey("FirstButton","Move.First")
	SetShortcutKey("FirstSnapButton","Move.FirstSnap")
	SetShortcutKey("ObjectButton","Move.Object")

	local facevector = {
		[Enum.NormalId.Back]	= Vector3.FromNormalId(Enum.NormalId.Back);
		[Enum.NormalId.Bottom]	= Vector3.FromNormalId(Enum.NormalId.Bottom);
		[Enum.NormalId.Front]	= Vector3.FromNormalId(Enum.NormalId.Front);
		[Enum.NormalId.Left]	= Vector3.FromNormalId(Enum.NormalId.Left);
		[Enum.NormalId.Right]	= Vector3.FromNormalId(Enum.NormalId.Right);
		[Enum.NormalId.Top]		= Vector3.FromNormalId(Enum.NormalId.Top);
	}

	SetOnSelect("AxisButton",function()
		local selection = GetFilteredSelection("BasePart")
		if #selection > 0 then
			OverlayHandles.Color = Resource("HandleColor")
			OverlayHandles.Visible = true
			WrapOverlay(selection,true)
			local origin = {}
			local ocf = GetOverlayCFrame()
			local inc = GetButtonValue("Inc")
			Connect(OverlayHandles.MouseButton1Down,function(face)
				inc = GetButtonValue("Inc")
				for _,part in pairs(selection) do
					origin[part] = part.CFrame
				end
				ocf = GetOverlayCFrame()
				SetButtonValue("Delta",0)
			end)
			Connect(OverlayHandles.MouseDrag,function(face,distance)
				local rdis = Round(distance,inc)
				local pos = facevector[face]*rdis
				for part,cframe in pairs(origin) do
					part.CFrame = cframe + pos
				end
				SetOverlayCFrame(ocf+pos)
				SetButtonValue("Delta",Round(math.abs(rdis),0.00001))
			end)
		else
			SetWarning()
		end
	end)
	SetOnSelect("AxisSnapButton",function()
		local selection = GetFilteredSelection("BasePart")
		if #selection > 0 then
			local inc = GetButtonValue("Inc")
			local incx = GetButtonValue("XButton") and inc or 0
			local incy = GetButtonValue("YButton") and inc or 0
			local incz = GetButtonValue("ZButton") and inc or 0
			for _,part in pairs(selection) do
				local pos = part.CFrame.p
				part.CFrame = (part.CFrame-pos) + Vector3.new(Round(pos.x,incx),Round(pos.y,incy),Round(pos.z,incz))
			end
			PlaySound("SnapSound")
			SelectPreviousTool()
		else
			SetWarning()
		end
	end)
	SetOnSelect("FirstButton",function()
		local selection = GetFilteredSelection("BasePart")
		if #selection > 0 then
			OverlayHandles.Color = Resource("HandleColor")
			OverlayHandles.Visible = true
			local center = selection[1]
			WrapOverlay(center)
			local origin = {}
			local corigin = center.CFrame
			local ocf = GetOverlayCFrame()
			local inc = GetButtonValue("Inc")
			Connect(OverlayHandles.MouseButton1Down,function(face)
				inc = GetButtonValue("Inc")
				corigin = center.CFrame
				for _,part in pairs(selection) do
					origin[part] = corigin:toObjectSpace(part.CFrame)
				end
				ocf = corigin:toObjectSpace(GetOverlayCFrame())
				SetButtonValue("Delta",0)
			end)
			Connect(OverlayHandles.MouseDrag,function(face,distance)
				local rdis = Round(distance,inc)
				local cf = corigin * CFrame.new(facevector[face]*rdis)
				for part,cframe in pairs(origin) do
					part.CFrame = cf:toWorldSpace(cframe)
				end
				SetOverlayCFrame(cf:toWorldSpace(ocf))
				SetButtonValue("Delta",Round(math.abs(rdis),0.00001))
			end)
		else
			SetWarning()
		end
	end)
	SetOnSelect("FirstSnapButton",function()
		local selection = GetFilteredSelection("BasePart")
		if #selection > 0 then
			local corigin = selection[1].CFrame
			local pos = corigin.p
			local inc = GetButtonValue("Inc")
			local incx = GetButtonValue("XButton") and inc or 0
			local incy = GetButtonValue("YButton") and inc or 0
			local incz = GetButtonValue("ZButton") and inc or 0
			local new = (corigin-pos) + Vector3.new(Round(pos.x,incx),Round(pos.y,incy),Round(pos.z,incz))
			for _,part in pairs(selection) do
				part.CFrame = new:toWorldSpace(corigin:toObjectSpace(part.CFrame))
			end
			PlaySound("SnapSound")
			SelectPreviousTool()
		else
			SetWarning()
		end
	end)
	SetOnSelect("ObjectButton",function()
		local selection = GetFilteredSelection("BasePart")
		if #selection > 0 then
			OverlayHandles.Color = Resource("HandleColor")
			OverlayHandles.Visible = true
			WrapOverlay(selection[1])
			local origin = {}
			local ocf = GetOverlayCFrame()
			local inc = GetButtonValue("Inc")
			Connect(OverlayHandles.MouseButton1Down,function(face)
				inc = GetButtonValue("Inc")
				for _,part in pairs(selection) do
					origin[part] = part.CFrame
				end
				ocf = GetOverlayCFrame()
				SetButtonValue("Delta",0)
			end)
			Connect(OverlayHandles.MouseDrag,function(face,distance)
				local rdis = Round(distance,inc)
				local cf = CFrame.new(facevector[face]*rdis)
				for part,cframe in pairs(origin) do
					part.CFrame = cframe * cf
				end
				SetOverlayCFrame(ocf*cf)
				SetButtonValue("Delta",Round(math.abs(rdis),0.00001))
			end)
		else
			SetWarning()
		end
	end)
	Validate()
end,true)

ProcessElementSource(function()
	SetPluginName("Rotate")
	SetPluginType("menu")
	SetMenuText("Rotation")
	SetMenuDescription("{h}Rotation Menu\nContains tools for rotating parts.")

	AddResource("HandleColor",BrickColor.new("Bright green"))
	AddResource("SnapSound","rbxasset://Sounds/snap.wav")

	SetLayout{
		{	-- row 1
			{"Inc","field",0.1};
			{"RotateSnap","container",{
				{"XButton","toggle",true,"X"};
				{"YButton","toggle",true,"Y"};
				{"ZButton","toggle",true,"Z"};
			}}
		};
		{	-- row 2
			{"ObjectButton","tool","Object"};
			{"ObjectSnapButton","tool","Snap"};
		};
		{	-- row 3
			{"PivotButton","tool","Pivot"};
			{"PivotSnapButton","tool","Snap"};
		};
		{	-- row 4
			{"GroupButton","tool","Group"};
			{"Delta","label","0"};
		};
	}

	SetButtonDescription("ObjectButton","{h}Rotate by Object\nThis tool rotates parts. When selected, ArcHandles will appear around the first selected part. When dragged, each selected part will rotate around it's own center, independant of any other part.\nThe angle of each part will be snapped by the Rotation Increment.")
	SetButtonDescription("ObjectSnapButton","{h}Snap Angle by Object\nThis tool rounds the angle of all selected parts to the nearest Rotation Increment.\nFor example, if a part had one axis rotated by 80 degrees, and the Rotation Increment was 45, that axis would be rounded to 90 degrees.\nThis tool depends on the Axis Lock toggle buttons. For example, If the X Axis Lock was deselected, only the Y and Z axes would be rounded.")
	SetButtonDescription("PivotButton","{h}Rotate by First\nThis tool rotates parts around one part.\nWhen selected, ArcHandles will appear around the first selected part. When dragged, the first part will be rotated, and the rest of the selected will keep their relative positions and rotations to it.")
	SetButtonDescription("PivotSnapButton","{h}Snap Angle by First\nThis tool is very similar to the Snap Angle by Object tool. The difference is that only the first selected part is snapped, and the rest of the selection is moved relative to it.")
	SetButtonDescription("GroupButton","{h}Rotate as Group\nThis tool rotates parts as a group, around the center of the group.\nWhen selected, ArcHandles will appear around all selected parts. When dragged, these parts will be rotated around the center of the group.\nNote that the rotation of the ArcHandles resets every time you select the tool.")
	SetButtonDescription("Inc","{h}Rotation Increment\nThis number defines how many degrees to snap an angle by when rotating parts. For example, if it were 45, parts would rotate every 45 degrees\nIt is also used to tell what to round a part's rotation by when using a snap tool. For example, if it were 45, a part's position would round to the nearest 45th degree.")
	SetButtonDescription("XButton","{h}X Axis Lock\nThis button toggles whether the X axis will be considered when using a snap tool. If selected, parts will be snapped on the X axis. If not selected, snapping is ignored on the X axis.")
	SetButtonDescription("YButton","{h}Y Axis Lock\nThis button toggles whether the Y axis will be considered when using a snap tool. If selected, parts will be snapped on the Y axis. If not selected, snapping is ignored on the Y axis.")
	SetButtonDescription("ZButton","{h}Z Axis Lock\nThis button toggles whether the Z axis will be considered when using a snap tool. If selected, parts will be snapped on the Z axis. If not selected, snapping is ignored on the Z axis.")
	SetButtonDescription("Delta","{h}Rotation Delta\nThis number displays the anglular distance that parts have been dragged, in degrees.")

	SetWarnings("ObjectButton","No parts selected")
	SetWarnings("ObjectSnapButton","No parts selected")
	SetWarnings("PivotButton","No parts selected")
	SetWarnings("PivotSnapButton","No parts selected")
	SetWarnings("GroupButton","No parts selected")

	SetShortcutKey("ObjectButton","Rotate.Object")
	SetShortcutKey("ObjectSnapButton","Rotate.ObjectSnap")
	SetShortcutKey("PivotButton","Rotate.Pivot")
	SetShortcutKey("PivotSnapButton","Rotate.PivotSnap")
	SetShortcutKey("GroupButton","Rotate.Group")

	local axisnum = {
		[Enum.Axis.X] = 1;
		[Enum.Axis.Y] = 2;
		[Enum.Axis.Z] = 3;
	}

	SetOnSelect("ObjectButton",function()
		local selection = GetFilteredSelection("BasePart")
		if #selection > 0 then
			OverlayArcHandles.Color = Resource("HandleColor")
			OverlayArcHandles.Visible = true
			WrapOverlay(selection[1])
			local origin = {}
			local ocf = GetOverlayCFrame()
			local inc = GetButtonValue("Inc")
			Connect(OverlayArcHandles.MouseButton1Down,function(axis)
				for _,part in pairs(selection) do
					origin[part] = part.CFrame
				end
				ocf = GetOverlayCFrame()
				inc = GetButtonValue("Inc")
				SetButtonValue("Delta",0)
			end)
			Connect(OverlayArcHandles.MouseDrag,function(axis,angle)
				local rdis = Round(math.deg(angle),inc)
				local input = {0;0;0}
				input[axisnum[axis]] = math.rad(rdis)
				local new = CFrame.Angles(unpack(input))
				for part,cframe in pairs(origin) do
					part.CFrame = cframe * new
				end
				SetOverlayCFrame(ocf * new)
				SetButtonValue("Delta",Round(math.abs(rdis),0.00001))
			end)
		else
			SetWarning()
		end
	end)
	SetOnSelect("ObjectSnapButton",function()
		local selection = GetFilteredSelection("BasePart")
		if #selection > 0 then
			local inc = GetButtonValue("Inc")
			local incx = GetButtonValue("XButton") and inc or 0
			local incy = GetButtonValue("YButton") and inc or 0
			local incz = GetButtonValue("ZButton") and inc or 0
			if inc >= 360 then
				for _,part in pairs(selection) do
					part.CFrame = CFrame.new(part.CFrame.p)
				end
			elseif inc ~= 0 then
				for _,part in pairs(selection) do
					local x,y,z = part.CFrame:toEulerAnglesXYZ()
					part.CFrame = CFrame.Angles(
						math.rad(Round(math.deg(x),incx)),
						math.rad(Round(math.deg(y),incy)),
						math.rad(Round(math.deg(z),incz))
					) + part.CFrame.p
				end
			end
			PlaySound("SnapSound")
			SelectPreviousTool()
		else
			SetWarning()
		end
	end)
	SetOnSelect("PivotButton",function()
		local selection = GetFilteredSelection("BasePart")
		if #selection > 0 then
			OverlayArcHandles.Color = Resource("HandleColor")
			OverlayArcHandles.Visible = true
			local center = selection[1]
			WrapOverlay(center)
			local origin = {}
			local corigin = center.CFrame
			local ocf = corigin:toObjectSpace(GetOverlayCFrame())
			local inc = GetButtonValue("Inc")
			Connect(OverlayArcHandles.MouseButton1Down,function(axis)
				corigin = center.CFrame
				for _,part in pairs(selection) do
					origin[part] = corigin:toObjectSpace(part.CFrame)
				end
				ocf = corigin:toObjectSpace(GetOverlayCFrame())
				inc = GetButtonValue("Inc")
				SetButtonValue("Delta",0)
			end)
			Connect(OverlayArcHandles.MouseDrag,function(axis,angle)
				local rdis = Round(math.deg(angle),inc)
				local input = {0;0;0}
				input[axisnum[axis]] = math.rad(rdis)
				local new = corigin * CFrame.Angles(unpack(input))
				for part,cframe in pairs(origin) do
					part.CFrame = new:toWorldSpace(cframe)
				end
				SetOverlayCFrame(new:toWorldSpace(ocf))
				SetButtonValue("Delta",Round(math.abs(rdis),0.00001))
			end)
		else
			SetWarning()
		end
	end)
	SetOnSelect("PivotSnapButton",function()
		local selection = GetFilteredSelection("BasePart")
		if #selection > 0 then
			local corigin = selection[1].CFrame
			local x,y,z = corigin:toEulerAnglesXYZ()
			local inc = GetButtonValue("Inc")
			local incx = GetButtonValue("XButton") and inc or 0
			local incy = GetButtonValue("YButton") and inc or 0
			local incz = GetButtonValue("ZButton") and inc or 0
			local new = CFrame.Angles(
				math.rad(Round(math.deg(x),incx)),
				math.rad(Round(math.deg(y),incy)),
				math.rad(Round(math.deg(z),incz))
			) + corigin.p
			for _,part in pairs(selection) do
				part.CFrame = new:toWorldSpace(corigin:toObjectSpace(part.CFrame))
			end
			PlaySound("SnapSound")
			SelectPreviousTool()
		else
			SetWarning()
		end
	end)
	SetOnSelect("GroupButton",function()
		local selection,bbsize,bbpos = GetSelectionBoundingBox()
		if #selection > 0 then
			OverlayArcHandles.Color = Resource("HandleColor")
			OverlayArcHandles.Visible = true
			SetOverlay(bbsize,CFrame.new(bbpos))
			local origin = {}
			local corigin = GetOverlayCFrame()
			local inc = GetButtonValue("Inc")
			Connect(OverlayArcHandles.MouseButton1Down,function(axis)
				corigin = GetOverlayCFrame()
				for _,part in pairs(selection) do
					origin[part] = corigin:toObjectSpace(part.CFrame)
				end
				inc = GetButtonValue("Inc")
				SetButtonValue("Delta",0)
			end)
			Connect(OverlayArcHandles.MouseDrag,function(axis,angle)
				local rdis = Round(math.deg(angle),inc)
				local input = {0;0;0}
				input[axisnum[axis]] = math.rad(rdis)
				local new = corigin * CFrame.Angles(unpack(input))
				for part,cframe in pairs(origin) do
					part.CFrame = new:toWorldSpace(cframe)
				end
				SetOverlayCFrame(new)
				SetButtonValue("Delta",Round(math.abs(rdis),0.00001))
			end)
		else
			SetWarning()
		end
	end)
	Validate()
end,true)

ProcessElementSource(function()
	SetPluginName("Resize")
	SetPluginType("menu")
	SetMenuText("Resizing")
	SetMenuDescription("{h}Resizing Menu\nContains tools for resizing parts.")

	AddResource("HandleColor",BrickColor.new("Cyan"))
	AddResource("SnapSound","rbxasset://Sounds/snap.wav")

	SetLayout{
		{	-- row 1
			{"Inc","field",0.1};
			{"ResizeSnap","container",{
				{"XButton","toggle",true,"X"};
				{"YButton","toggle",true,"Y"};
				{"ZButton","toggle",true,"Z"};
			}}
		};
		{	-- row 2
			{"ObjectButton","tool","Object"};
			{"ObjectSnapButton","tool","Snap"};
		};
		{	-- row 3
			{"CenterButton","tool","Center"};
			{"Delta","label","0"};
		};
	}

	SetButtonDescription("ObjectButton","{h}Resize by Object\nThis tool resizes parts. When selected, Handles will appear around the first selected part. When dragged, each selected part will be resized accordingly.\nThe amount a part is snapped is described in the description of the Resize Increment.\nRemember that multiple selected parts can have different FormFactors. All parts will be resized depending only on their own FormFactor.")
	SetButtonDescription("ObjectSnapButton","{h}Snap Size by Object\nThis tool rounds the size of all selected parts. Unlike the other tools, this tool only rounds the size of each selected part to the nearest Resize Increment.\nThis tool depends on the Axis Lock toggle buttons. For example, If the X Axis Lock was deselected, only the Y and Z axes would be rounded.")
	SetButtonDescription("CenterButton","{h}Resize from Center\nThis tool is is similar to the Resize by Object tool. The difference is that it resizes each part from the center of that part, instead of from the face.")
	SetButtonDescription("Inc","{h}Resize Increment\nThis number defines how many studs to snap by when resizing parts. How much a part is snapped is an amount depending on the part's FormFactor, multiplied by the Resize Increment.\nFor example, if the Resize Increment were 2, and you were to resize the top face of a part with the Brick FormFactor (1.2), the part would be snapped every 2.4 studs.\nIf the FormFactor is Custom, this is ignored, and it is simply snapped by the Resize Increment.")
	SetButtonDescription("XButton","{h}X Axis Lock\nThis button toggles whether the X axis will be considered when snapping. If selected, parts will be snapped on the X axis. If not selected, snapping is ignored on the X axis.")
	SetButtonDescription("YButton","{h}Y Axis Lock\nThis button toggles whether the Y axis will be considered when snapping. If selected, parts will be snapped on the Y axis. If not selected, snapping is ignored on the Y axis.")
	SetButtonDescription("ZButton","{h}Z Axis Lock\nThis button toggles whether the Z axis will be considered when snapping. If selected, parts will be snapped on the Z axis. If not selected, snapping is ignored on the Z axis.")
	SetButtonDescription("Delta","{h}Resize Delta\nThis number displays the size distance a part has been dragged, in studs.")

	SetWarnings("ObjectButton","No parts selected")
	SetWarnings("ObjectSnapButton","No parts selected")
	SetWarnings("CenterButton","No parts selected")

	SetShortcutKey("ObjectButton","Resize.Object")
	SetShortcutKey("ObjectSnapButton","Resize.ObjectSnap")
	SetShortcutKey("CenterButton","Resize.Center")

	local facevector = {
		[Enum.NormalId.Back]	= Vector3.FromNormalId(Enum.NormalId.Back);
		[Enum.NormalId.Bottom]	= Vector3.FromNormalId(Enum.NormalId.Bottom);
		[Enum.NormalId.Front]	= Vector3.FromNormalId(Enum.NormalId.Front);
		[Enum.NormalId.Left]	= Vector3.FromNormalId(Enum.NormalId.Left);
		[Enum.NormalId.Right]	= Vector3.FromNormalId(Enum.NormalId.Right);
		[Enum.NormalId.Top]		= Vector3.FromNormalId(Enum.NormalId.Top);
	}
	local facemult = {
		[Enum.NormalId.Back]	=  1;
		[Enum.NormalId.Bottom]	= -1;
		[Enum.NormalId.Front]	= -1;
		[Enum.NormalId.Left]	= -1;
		[Enum.NormalId.Right]	=  1;
		[Enum.NormalId.Top]		=  1;
	}
	local facesize = {
		[Enum.NormalId.Back]	= "z";
		[Enum.NormalId.Bottom]	= "y";
		[Enum.NormalId.Front]	= "z";
		[Enum.NormalId.Left]	= "x";
		[Enum.NormalId.Right]	= "x";
		[Enum.NormalId.Top]		= "y";
	}

	local FFXZ = {
		[Enum.FormFactor.Symmetric]	= 1;
		[Enum.FormFactor.Brick]		= 1;
		[Enum.FormFactor.Plate]		= 1;
		[Enum.FormFactor.Custom]	= 0.2;
		["TrussPart"]				= 2;
	}

	local FFY = {
		[Enum.FormFactor.Symmetric]	= 1;
		[Enum.FormFactor.Brick]		= 1.2;
		[Enum.FormFactor.Plate]		= 0.4;
		[Enum.FormFactor.Custom]	= 0.2;
		["TrussPart"]				= 2;
	}

	local formfactormult = {
		[Enum.NormalId.Back]	= FFXZ;
		[Enum.NormalId.Bottom]	= FFY;
		[Enum.NormalId.Front]	= FFXZ;
		[Enum.NormalId.Left]	= FFXZ;
		[Enum.NormalId.Right]	= FFXZ;
		[Enum.NormalId.Top]		= FFY;
	}

	local function GetFormFactor(object)
		if object:IsA"FormFactorPart" then
			return object.formFactor
		elseif object:IsA"TrussPart" then
			return "TrussPart"
		else
			return Enum.FormFactor.Symmetric
		end
	end

	SetOnSelect("ObjectButton",function()
		local selection = GetFilteredSelection("BasePart")
		if #selection > 0 then
			local first = selection[1]
			OverlayHandles.Color = Resource("HandleColor")
			OverlayHandles.Visible = true
			WrapOverlay(first)
			local origin = {}
			Connect(OverlayHandles.MouseButton1Down,function(face)
				for _,part in pairs(selection) do
					local ff = GetFormFactor(part)
					origin[part] = {part.CFrame,part.Size,ff,formfactormult[face][ff]}
				end
				SetButtonValue("Delta",0)
			end)
			Connect(OverlayHandles.MouseDrag,function(face,distance)
				local fm,fs = facemult[face],facesize[face]
				local dis = distance*fm
				local fvec = facevector[face]
				local inc = GetButtonValue("Inc")
				local cinc = inc
				if inc == 0 then
					inc = 1
				else
					inc = Round(inc,1)
				end
				for part,info in pairs(origin) do
					local sz,ff,ffm = info[2],info[3],info[4]
					local mult
					if ff == Enum.FormFactor.Custom then
						mult = Round(dis,cinc)
					else
						mult = Round(dis,inc*ffm)
					end
					local mod = fvec*mult
					local fsize = sz[fs]
					mod = fsize + mult*fm < ffm and fvec*((ffm-fsize)*fm) or mod
					part.Size = sz + mod
					part.CFrame = info[1] * CFrame.new(mod*fm/2)
					if part == first then SetButtonValue("Delta",Round(mod.magnitude,0.00001)) end
				end
				SetOverlay(first.Size,first.CFrame)
			end)
		else
			SetWarning()
		end
	end)
	SetOnSelect("ObjectSnapButton",function()
		local selection = GetFilteredSelection("BasePart")
		if #selection > 0 then
			local inc = GetButtonValue("Inc")
			local incx = GetButtonValue("XButton") and inc or 0
			local incy = GetButtonValue("YButton") and inc or 0
			local incz = GetButtonValue("ZButton") and inc or 0
			for _,part in pairs(selection) do
				local cf = part.CFrame
				part.Size = Vector3.new(
					Round(part.Size.x,incx),
					Round(part.Size.y,incy),
					Round(part.Size.z,incz)
				)
				part.CFrame = cf
			end
			PlaySound("SnapSound")
			SelectPreviousTool()
		else
			SetWarning()
		end
	end)
	SetOnSelect("CenterButton",function()
		local selection = GetFilteredSelection("BasePart")
		if #selection > 0 then
			local first = selection[1]
			OverlayHandles.Color = Resource("HandleColor")
			OverlayHandles.Visible = true
			WrapOverlay(first)
			local origin = {}
			Connect(OverlayHandles.MouseButton1Down,function(face)
				for _,part in pairs(selection) do
					local ff = GetFormFactor(part)
					origin[part] = {part.CFrame,part.Size,ff,formfactormult[face][ff]}
				end
				SetButtonValue("Delta",0)
			end)
			Connect(OverlayHandles.MouseDrag,function(face,distance)
				local fm,fs = facemult[face],facesize[face]
				local dis = distance*2*fm
				local fvec = facevector[face]
				local inc = GetButtonValue("Inc")
				local cinc = inc
				if inc == 0 then
					inc = 1
				else
					inc = Round(inc,1)
				end
				for part,info in pairs(origin) do
					local sz,ff,ffm = info[2],info[3],info[4]
					local mult
					if ff == Enum.FormFactor.Custom then
						mult = Round(dis,cinc)
					else
						mult = Round(dis,inc*ffm)
					end
					local mod = fvec*mult
					local fsize = sz[fs]
					mod = fsize + mult*fm < ffm and fvec*((ffm-fsize)*fm) or mod
					part.Size = sz + mod
					part.CFrame = info[1]
					if part == first then SetButtonValue("Delta",Round(mod.magnitude,0.00001)) end
				end
				SetOverlay(first.Size,first.CFrame)
			end)
		else
			SetWarning()
		end
	end)
	Validate()
end,true)

ProcessElementSource(function()
	SetPluginName("Weld")
	SetPluginType("menu")
	SetMenuText("Welding")
	SetMenuDescription("{h}Welding Menu\nContains tools for handling welds.")

	AddResource("JoinSound","rbxasset://Sounds/splat.wav")
	AddResource("BreakSound","rbxasset://Sounds/snap.wav")

	SetLayout{
		{	-- row 1
			{"Type","field",{"Motor6D";
				function(text)
					local e,o = pcall(Instance.new,text)		-- check by attempting to create an instance of the classname
					if e and o and o:IsA"JointInstance" then	-- only instancable JointInstances are valid
						return true,o.className					-- success; set value to className
					else										-- if invalid
						return false							-- fail; use previous value
					end
				end};
			};
		};
		{	-- row 2
			{"JoinButton","tool","Join"};
		};
		{	-- row 3
			{"BreakButton","tool","Break"};
		};
	}

	SetButtonDescription("JoinButton","{h}Join Objects\nWhen this tool is selected, the first selected part is weld to each remaining selected part with a joint of the current Weld Type.\nThe relative positions between each object are maintained.\nThe resulting joint object is placed under the first selected part.")
	SetButtonDescription("BreakButton","{h}Break Objects\nWhen this tool is selected, one of two things will happen, depending on how many parts are selected.\nIf multiple parts are selected, then any joints of any involved parts, and of the current Weld Type, are removed. That is, if a joint in the first selection is joined with another selected part, that joint is removed.\nIn other words, a reverse of the Join Button occurs.\nIf only one part is selected, then the last weld found, of the current Weld Type, is removed from that part.")
	SetButtonDescription("Type","{h}Weld Type\nThis defines what kind of weld to use when joining or breaking.\nThe only valid classes are those that inherit from the JointInstance class, and are instancable.")

	SetWarnings("JoinButton",{"No parts selected","Not enough valid selections"})
	SetWarnings("BreakButton","No parts selected")

	SetShortcutKey("JoinButton","Weld.Join")
	SetShortcutKey("BreakButton","Weld.Break")

	SetOnSelect("JoinButton",function()
		local selection = GetFilteredSelection("BasePart")
		if #selection > 1 then
			local x = table.remove(selection,1)
			local c = CFrame.new(x.Position)
			local xcf = x.CFrame:toObjectSpace(c)
			local type = GetButtonValue("Type")
			for _,y in pairs(selection) do
				local w = Instance.new(type)
				w.Part0 = x
				w.Part1 = y
				w.C0 = xcf
				w.C1 = y.CFrame:toObjectSpace(c)
				w.Parent = x
			end
			PlaySound("JoinSound")
			Deselect()
		elseif #selection > 0 then
			SetWarning(2)
		else
			SetWarning()
		end
	end)
	SetOnSelect("BreakButton",function()
		local selection = GetFilteredSelection("BasePart")
		if #selection > 0 then
			local part = table.remove(selection,1)
			local type = GetButtonValue("Type")
			local joints = {}
			for _,joint in pairs(part:GetChildren()) do
				if joint.className == type then
					table.insert(joints,joint)
				end
			end
			if #selection > 0 then
				local joined = {}
				for i,v in pairs(selection) do
					joined[v] = true
				end
				for _,joint in pairs(joints) do
					if joined[joint.Part1] then
						joint:Remove()
					end
				end
			else
				local joint = joints[#joints]
				if joint then
					joint:Remove()
				end
			end
			PlaySound("BreakSound")
			Deselect()
		else
			SetWarning()
		end
	end)
	Validate()
end,true)

ProcessElementSource(function()
	SetPluginName("Scale")
	SetPluginType("menu")
	SetMenuText("Scaling")
	SetMenuDescription("{h}Scaling Menu\nContains tools for scaling objects.")

	AddResource("ScaleSound","rbxasset://Sounds/electronicpingshort.wav")

	SetLayout{
		{	-- row 1
			{"Factor","field",0.1};
		};
		{	-- row 2
			{"ScaleButton","tool","Scale"};
		};
	}

	SetButtonDescription("ScaleButton","{h}Scale Objects\nThis tool scales a group of objects up or down.\nWhen selected, a copy of the selection is made, which is scaled depending o the Scale Factor.\nTo keep relative sizes, parts have their FormFactor automatically converted to Custom. Note that parts that do not inherit from the FormFactorPart class cannot be converted, so they may not scale properly.\nAs well as parts, a few other things are scaled:\n- A mesh's Offset\n- A SpecialMesh's Scale\n- A BevelMesh's Bevel\n- A Texture's StudsPerTile(U/V)\nNote that the selection must contain parts in order to be scaled.")
	SetButtonDescription("Factor","{h}Scale Factor\nThis is the factor that the selection will be scaled by. For example, a factor of 2 produces a copy twice the size, while a factor of 0.5 produces a copy half the size.")

	SetWarnings("ScaleButton","No parts selected")

	SetShortcutKey("ScaleButton","Scale.Scale")

	SetOnSelect("ScaleButton",function()
		local function RecurseScale(object,scale,center)
			if object:IsA"BasePart" then
				if object:IsA"FormFactorPart" then
					object.formFactor = "Custom"
				end
				local cf = center:toObjectSpace(object.CFrame)
				object.Size = object.Size*scale
				object.CFrame = center:toWorldSpace(cf + cf.p * (scale - 1))
			elseif object:IsA"DataModelMesh" then
				object.Offset = object.Offset * scale
				if object:IsA"FileMesh" then
					if object:IsA"SpecialMesh" then
						if object.MeshType == Enum.MeshType.FileMesh then
							object.Scale = object.Scale * scale
						end
					else
						object.Scale = object.Scale * scale
					end
				elseif object:IsA"BevelMesh" then
					object.Bevel = object.Bevel * scale
				end
			elseif object:IsA"Texture" then
				object.StudsPerTileU = object.StudsPerTileU * scale
				object.StudsPerTileV = object.StudsPerTileV * scale
			end	
			for _,child in pairs(object:GetChildren()) do
				RecurseScale(child,scale,center)
			end
		end
		local selection = GetSelection()
		local parts = GetFilteredSelection("BasePart")
		if #parts > 0 then
			local center = CFrame.new(GetMidpoint(parts))
			local scale = GetButtonValue("Factor")
			local model = Instance.new("Model",workspace)
			model.Name = "ScaledModel"
			for _,object in pairs(selection) do
				local new = object:Clone()
				RecurseScale(new,scale,center)
				new.Parent = model
			end
			PlaySound("ScaleSound")
			Deselect()
		else
			SetWarning()
		end
	end)
	Validate()
end,true)

-- other menu
ProcessElementSource(function()
	SetPluginName("DeleteButton")
	SetPluginType("tool")
	SetButtonText("Delete")
	SetDescription("{h}Delete Selection\nDeletes the entire selection.\nThe idea is that deleting doesn't work outside of Studio Mode.")

	AddResource("DeleteSound","rbxasset://Sounds/pageturn.wav")

	SetShortcutKey("Other.Delete")

	SetOnSelect(function()
		local selection = GetSelection()
		if #selection > 0 then
			for i,object in pairs(selection) do
				object:Remove()
			end
			PlaySound("DeleteSound")
		end
		Deselect()
	end)
	Validate()
end,true)

ProcessElementSource(function()
	SetPluginName("SlopeButton")
	SetPluginType("tool")
	SetButtonText("Slope")
	SetDescription("{h}Slope Objects\nWhen this tool is selected, the first and second selected parts are used as points. The rest of the selection will be rotated to the slope between those two points. Their positions remain the same.")
	SetWarnings{"Invalid 1st selection";"Invalid 2nd selection";"Not enough valid selections"}

	AddResource("SlopeSound","rbxasset://Sounds/electronicpingshort.wav")

	SetShortcutKey("Other.Slope")

	SetOnSelect(function()
		local selection = GetFilteredSelection("BasePart")
		if #selection > 2 then
			local p1 = table.remove(selection,2)
			local p0 = table.remove(selection,1)
			for _,part in pairs(selection) do
				part.CFrame = CFrame.new(part.CFrame.p,part.CFrame.p+(p1.CFrame.p-p0.CFrame.p))
			end
			PlaySound("SlopeSound")
			Deselect()
		elseif #selection > 1 then
			SetWarning(3)
		elseif #selection > 0 then
			SetWarning(2)		
		else
			SetWarning()
		end
	end)
	Validate()
end,true)

ProcessElementSource(function()
	SetPluginName("MidpointButton")
	SetPluginType("tool")
	SetButtonText("Midpoint")
	SetDescription("{h}Move to Midpoint\nWhen this tool is selected, the first selected part will be moved to the center of the rest of the selection.")
	SetWarnings{"No parts selected";"Not enough valid selections"}

	AddResource("MidpointSound","rbxasset://Sounds/electronicpingshort.wav")

	SetShortcutKey("Other.Midpoint")

	SetOnSelect(function()
		local selection = GetFilteredSelection("BasePart")
		if #selection > 1 then
			local center = table.remove(selection,1)
			center.CFrame = (center.CFrame-center.CFrame.p) + GetMidpoint(selection)
			PlaySound("MidpointSound")
			Deselect()
		elseif #selection > 0 then
			SetWarning(2)
		else
			SetWarning()
		end
	end)
	Validate()
end,true)

-- commands

ProcessElementSource(function()
	SetPluginName("GetSelection")
	SetPluginType("command")
	SetCommandName("get")

	SetFunction(
		function()
			return GetSelection()
		end
	)

	SetDescription("Returns the current selection.")

	Validate()
end)

ProcessElementSource(function()
	SetPluginName("SetSelection")
	SetPluginType("command")
	SetCommandName("set")

	SetFunction(
		function(objects)
			SetSelection(objects or {})
		end
	)

	SetDescription("Sets the current selection.\n'objects' should be a table that contains Instances. If 'object' is not specified, the selection will be set to nothing.")
	SetArgumentDoc({
		{"table";"objects";"{}"};
	})

	Validate()
end)


ProcessElementSource(function()
	SetPluginName("PropertySet")
	SetPluginType("command")
	SetCommandName("pset")

	SetFunction(
		function(property,value,selection)
			if type(property) ~= "string" then error("1st argument needs a string",0) end
			local function precurse(object,property,value,out)
				local e,o = pcall(function() return object[property] == value end)
				if e and o then
					table.insert(out,object)
				end
				for _,child in pairs(object:GetChildren()) do
					precurse(child,property,value,out)
				end
			end
			local out = {}
			if selection then
				for _,object in pairs(GetSelection()) do
					precurse(object,property,value,out)
				end
			else
				precurse(game,property,value,out)
			end
			SetSelection(out)
			return out
		end
	)

	SetDescription("Recurses through the game and selects Instances with specified properties.\nObjects whose 'property' has a value of 'value' are selected.\nIf the optional 'selection' argument is true, this function will recurse through the current selection instead.\nThis function will also return the resulting selection.\nThis function does not select objects that are not part of the game hierarchy.")
	SetArgumentDoc({
		{"string";"property"};
		{"*";"value"};
		{"bool";"selection";"false"};
	})

	Validate()
end)

ProcessElementSource(function()
	SetPluginName("ClassSet")
	SetPluginType("command")
	SetCommandName("cset")

	SetFunction(
		function(class_name,selection)
			if type(class_name) ~= "string" then error("1st argument needs a string",0) end
			local function crecurse(object,class_name,out)
				if object:IsA(class_name) then
					table.insert(out,object)
				end
				for _,child in pairs(object:GetChildren()) do
					crecurse(child,class_name,out)
				end
			end
			local out = {}
			if selection then
				for _,object in pairs(GetSelection()) do
					crecurse(object,class_name,out)
				end
			else
				crecurse(game,class_name,out)
			end
			SetSelection(out)
			return out
		end
	)

	SetDescription("Recurses through the game and selects Instances that inherit from a specified class.\nObjects that inherit from 'class_name' are selected.\nIf the optional 'selection' argument is true, this function will recurse through the current selection instead.\nThis function will also return the resulting selection.\nThis function does not select objects that are not part of the game hierarchy.")
	SetArgumentDoc({
		{"string";"class_name"};
		{"bool";"selection";"false"};
	})

	Validate()
end)

ProcessElementSource(function()
	SetPluginName("FunctionSet")
	SetPluginType("command")
	SetCommandName("fset")

	SetFunction(
		function(check,selection)
			if type(check) ~= "function" then error("1st argument needs a function",0) end
			local function frecurse(object,check,out)
				if check(object) then
					table.insert(out,object)
				end
				for _,child in pairs(object:GetChildren()) do
					frecurse(child,check,out)
				end
			end
			local out = {}
			if selection then
				for _,object in pairs(GetSelection()) do
					frecurse(object,check,out)
				end
			else
				frecurse(game,check,out)
			end
			SetSelection(out)
			return out
		end
	)

	SetDescription("Recurses through the game and selects Instances that pass a specified test.\nAny instance to which 'check' returns true are selected.\n'check' receives an object, and should return a bool, indicating whether the object should be added.\nIf the optional 'selection' argument is true, this function will recurse through the current selection instead.\nThis function will also return the resulting selection.\nThis function does not select objects that are not part of the game hierarchy.")
	SetArgumentDoc({
		{"function";"check"};
		{"bool";"selection";"false"};
	})

	Validate()
end)

ProcessElementSource(function()
	SetPluginName("Query")
	SetPluginType("command")
	SetCommandName("q")

	SetFunction(
		function(test,scope)
			if type(test) ~= "function" then error("1st argument must be a function",0) end
			if type(scope) ~= "table" then error("2nd argument must be a table",0) end
			local function recurse(object,test,results)
				if test(object) then
					table.insert(results,object)
				end
				local ot = type(object)
				if ot == "userdata" then
					local e,o = pcall(function() return object:IsA"Instance" end)
					if e and o then
						for _,child in pairs(object:GetChildren()) do
							recurse(child,test,results)
						end
					end
				elseif ot == "table" then
					for i,v in pairs(object) do
						recurse(v,test,results)
					end
				end
			end
			local results = {}
			for i,v in pairs(scope) do
				recurse(v,test,results)
			end
			return results
		end
	)

	SetDescription("Gathers a list of results from a scope of values based on provided criteria.\n'test' is a function that receives a value, and returns a bool.\n'scope' is a table of values to be recursively searched through.\nIf a value is a table, it's contents are searched.\nIf a value is an Instance, it's children are searched.")
	SetArgumentDoc({
		{"function";"test"};
		{"table";"scope"};
	})

	Validate()
end)

ProcessElementSource(function()
	SetPluginName("WorldPosition")
	SetPluginType("command")
	SetCommandName("wp")
	SetFunction(
		function(x,y,z)
			x,y,z = x or 0,y or 0,z or 0
			for _,object in pairs(GetFilteredSelection("BasePart")) do
				object.CFrame = object.CFrame + Vector3.new(x,y,z)
			end
		end
	)
	SetDescription("Moves each selected part based on it's location, but not its rotation.\n'x', 'y', and 'z' represent how many studs to move on their respective axes.")
	SetArgumentDoc({
		{"number";"x";"0"};
		{"number";"y";"0"};
		{"number";"z";"0"};
	})
	Validate()
end)

ProcessElementSource(function()
	SetPluginName("SnapPosition")
	SetPluginType("command")
	SetCommandName("sp")
	SetFunction(
		function(xinc,yinc,zinc)
			xinc,yinc,zinc = xinc or 0,yinc or 0,zinc or 0
			for _,object in pairs(GetFilteredSelection("BasePart")) do
				local pos = object.CFrame.p
				object.CFrame = (object.CFrame-pos) + Vector3.new(Round(pos.x,xinc),Round(pos.y,yinc),Round(pos.z,zinc))
			end
		end
	)
	SetDescription("Snaps the position of each selection on each axis by its respective increment.\nFor example, if 'xinc' were 1, each part would be snapped to the nearest 1 on the X axis.")
	SetArgumentDoc({
		{"number";"xinc";"0"};
		{"number";"yinc";"0"};
		{"number";"zinc";"0"};
	})
	Validate()
end)

ProcessElementSource(function()
	SetPluginName("FirstPosition")
	SetPluginType("command")
	SetCommandName("fp")

	SetFunction(
		function(x,y,z)
			x,y,z = x or 0,y or 0,z or 0
			local selection = GetFilteredSelection("BasePart")
			if #selection > 1 then
				local corigin = selection[1].CFrame
				local new = corigin * CFrame.new(x,y,z)
				for _,part in pairs(selection) do
					part.CFrame = new:toWorldSpace(corigin:toObjectSpace(part.CFrame))
				end
			else
				error("no vaild selections",0)
			end
		end
	)

	SetDescription("Moves the first selection, then moves the rest relative to it.\nThe first selection is moved based on its rotation.\nThe position and rotation of the rest of the selection is kept relative to the first.")
	SetArgumentDoc({
		{"number";"x";"0"};
		{"number";"y";"0"};
		{"number";"z";"0"};
	})

	Validate()
end)

ProcessElementSource(function()
	SetPluginName("SnapFirstPosition")
	SetPluginType("command")
	SetCommandName("sfp")

	SetFunction(
		function(xinc,yinc,zinc)
			xinc,yinc,zinc = xinc or 0,yinc or 0,zinc or 0
			local selection = GetFilteredSelection("BasePart")
			if #selection > 1 then
				local corigin = selection[1].CFrame
				local pos = corigin.p
				local new = (corigin-pos) + Vector3.new(Round(pos.x,xinc or 0),Round(pos.y,yinc or 0),Round(pos.z,zinc or 0))
				for _,part in pairs(selection) do
					part.CFrame = new:toWorldSpace(corigin:toObjectSpace(part.CFrame))
				end
			else
				error("no vaild selections",0)
			end
		end
	)

	SetDescription("Snaps the position of the first selection, then moves the rest relative to it.\nThe position and rotation of the rest of the selection is kept relative to the first.\nThe first selection is snapped on each axis by its respective increment.\nFor example, if 'xinc' were 1, each part would be snapped to the nearest 1 on the X axis.")
	SetArgumentDoc({
		{"number";"xinc";"0"};
		{"number";"yinc";"0"};
		{"number";"zinc";"0"};
	})

	Validate()
end)

ProcessElementSource(function()
	SetPluginName("ObjectPosition")
	SetPluginType("command")
	SetCommandName("op")

	SetFunction(
		function(x,y,z)
			x,y,z = x or 0,y or 0,z or 0
			for _,object in pairs(GetFilteredSelection("BasePart")) do
				object.CFrame = object.CFrame * CFrame.new(x,y,z)
			end
		end
	)

	SetDescription("Moves each selection based on its rotation.\nEach part is moved in the direction of its rotation, independent of any other part.")
	SetArgumentDoc({
		{"number";"x";"0"};
		{"number";"y";"0"};
		{"number";"z";"0"};
	})

	Validate()
end)

ProcessElementSource(function()
	SetPluginName("Position")
	SetPluginType("command")
	SetCommandName("p")

	SetFunction(
		function(x,y,z)
	x,y,z = x or 0,y or 0,z or 0
			for _,object in pairs(GetFilteredSelection("BasePart")) do
				object.CFrame = (object.CFrame-object.CFrame.p) + Vector3.new(x,y,z)
			end
		end
	)

	SetDescription("Directly sets the position of each selection.\n'x', 'y', and 'z' represent their respective positions on each axis.\nThe rotation of each selection is not affected.")
	SetArgumentDoc({
		{"number";"x";"0"};
		{"number";"y";"0"};
		{"number";"z";"0"};
	})

	Validate()
end)

ProcessElementSource(function()
	SetPluginName("RelativeRotation")
	SetPluginType("command")
	SetCommandName("rr")

	SetFunction(
		function(x,y,z)
			x,y,z = x or 0,y or 0,z or 0
			for _,object in pairs(GetFilteredSelection("BasePart")) do
				object.CFrame = object.CFrame * CFrame.Angles(math.rad(x),math.rad(y),math.rad(z))
			end
		end
	)

	SetDescription("Rotates each selection based on its current rotation.\n'x', 'y', and 'z' represent their respective rotational axes, in degrees.\nRotation by this command is accumulative.")
	SetArgumentDoc({
		{"number";"x";"0"};
		{"number";"y";"0"};
		{"number";"z";"0"};
	})

	Validate()
end)

ProcessElementSource(function()
	SetPluginName("SnapRotation")
	SetPluginType("command")
	SetCommandName("sr")

	SetFunction(
		function(xinc,yinc,zinc)
			xinc,yinc,zinc = xinc or 0,yinc or 0,zinc or 0
			for _,object in pairs(GetFilteredSelection("BasePart")) do
				local x,y,z = object.CFrame:toEulerAnglesXYZ()
				object.CFrame = CFrame.Angles(
					math.rad(Round(math.deg(x),xinc)),
					math.rad(Round(math.deg(y),yinc)),
					math.rad(Round(math.deg(z),zinc))
				) + object.CFrame.p
			end
		end
	)

	SetDescription("Snaps the rotation of each selection on each axis by its respective increment.\nFor example, if 'xinc' were 45, each part's rotation would be snapped to the nearest 45th degree on the X axis.")
	SetArgumentDoc({
		{"number";"xinc";"0"};
		{"number";"yinc";"0"};
		{"number";"zinc";"0"};
	})

	Validate()
end)

ProcessElementSource(function()
	SetPluginName("PivotRotation")
	SetPluginType("command")
	SetCommandName("pv")

	SetFunction(
		function(x,y,z)
			x,y,z = x or 0,y or 0,z or 0
			local selection = GetFilteredSelection("BasePart")
			if #selection > 1 then
				local corigin = selection[1].CFrame
				local new = corigin * CFrame.Angles(math.rad(x),math.rad(y),math.rad(z))
				for _,object in pairs(selection) do
					object.CFrame = new:toWorldSpace(corigin:toObjectSpace(object.CFrame))
				end
			else
				error("no vaild selections",0)
			end
		end
	)

	SetDescription("Rotates the first selection, then moves the rest of the selection relative to it.\nThe position and rotation of the rest of the selection is kept relative to the first.\nRotation by this command is accumulative.")
	SetArgumentDoc({
		{"number";"x";"0"};
		{"number";"y";"0"};
		{"number";"z";"0"};
	})

	Validate()
end)

ProcessElementSource(function()
	SetPluginName("SnapPivotRotation")
	SetPluginType("command")
	SetCommandName("spv")

	SetFunction(
		function(xinc,yinc,zinc)
			xinc,yinc,zinc = xinc or 0,yinc or 0,zinc or 0
			local selection = GetFilteredSelection("BasePart")
			if #selection > 1 then
				local corigin = selection[1].CFrame
				local x,y,z = corigin:toEulerAnglesXYZ()
				local new = CFrame.Angles(
					math.rad(Round(math.deg(x),xinc)),
					math.rad(Round(math.deg(y),yinc)),
					math.rad(Round(math.deg(z),zinc))
				) + corigin.p
				for _,object in pairs(selection) do
					object.CFrame = new:toWorldSpace(corigin:toObjectSpace(object.CFrame))
				end
			else
				error("no vaild selections",0)
			end
		end
	)

	SetDescription("Snaps the rotation of the first selection, then moves the rest relative to it.\nThe position and rotation of the rest of the selection is kept relative to the first.\nThe first selection is snapped on each rotational axis by its respective increment.\nFor example, if 'xinc' were 45, the first part would be snapped to the nearest 45th degree on the X axis.")
	SetArgumentDoc({
		{"number";"xinc";"0"};
		{"number";"yinc";"0"};
		{"number";"zinc";"0"};
	})

	Validate()
end)

ProcessElementSource(function()
	SetPluginName("GroupRotation")
	SetPluginType("command")
	SetCommandName("gr")

	SetFunction(
		function(x,y,z)
			x,y,z = x or 0,y or 0,z or 0
			local selection = GetFilteredSelection("BasePart")
			if #selection > 0 then
				local corigin = CFrame.new(GetMidpoint(selection))
				local new = corigin * CFrame.Angles(math.rad(x),math.rad(y),math.rad(z))
				for _,object in pairs(selection) do
					object.CFrame = new:toWorldSpace(corigin:toObjectSpace(object.CFrame))
				end
			else
				error("no vaild selections",0)
			end
		end
	)

	SetDescription("Rotates the entire selection around the center of that selection.\n'x', 'y', and 'z' represent their respective rotational axes, in degrees.\nRotation by this command is accumulative.")
	SetArgumentDoc({
		{"number";"x";"0"};
		{"number";"y";"0"};
		{"number";"z";"0"};
	})

	Validate()
end)

ProcessElementSource(function()
	SetPluginName("Rotation")
	SetPluginType("command")
	SetCommandName("r")

	SetFunction(
		function(x,y,z)
			x,y,z = x or 0,y or 0,z or 0
			for _,object in pairs(GetFilteredSelection("BasePart")) do
				object.CFrame = CFrame.new(object.CFrame.p) * CFrame.Angles(math.rad(x),math.rad(y),math.rad(z))
			end
		end
	)

	SetDescription("Directly sets the rotation of each selection, in degrees.\n'x', 'y', and 'z' represent their respective rotational axes, in degrees.\nRotation is set indenpendently of the part's current rotation.\nFor example, if 'xinc' were 90 degrees, the part's rotation would be reset, then rotated to 90 degrees.")
	SetArgumentDoc({
		{"number";"x";"0"};
		{"number";"y";"0"};
		{"number";"z";"0"};
	})

	Validate()
end)

ProcessElementSource(function()
	SetPluginName("Resize")
	SetPluginType("command")
	SetCommandName("rs")

	local facevector = {
		[Enum.NormalId.Back]	= Vector3.FromNormalId(Enum.NormalId.Back);
		[Enum.NormalId.Bottom]	= Vector3.FromNormalId(Enum.NormalId.Bottom);
		[Enum.NormalId.Front]	= Vector3.FromNormalId(Enum.NormalId.Front);
		[Enum.NormalId.Left]	= Vector3.FromNormalId(Enum.NormalId.Left);
		[Enum.NormalId.Right]	= Vector3.FromNormalId(Enum.NormalId.Right);
		[Enum.NormalId.Top]		= Vector3.FromNormalId(Enum.NormalId.Top);
	}
	local facemult = {
		[Enum.NormalId.Back]	=  1;
		[Enum.NormalId.Bottom]	= -1;
		[Enum.NormalId.Front]	= -1;
		[Enum.NormalId.Left]	= -1;
		[Enum.NormalId.Right]	=  1;
		[Enum.NormalId.Top]		=  1;
	}
	local facesize = {
		[Enum.NormalId.Back]	= "z";
		[Enum.NormalId.Bottom]	= "y";
		[Enum.NormalId.Front]	= "z";
		[Enum.NormalId.Left]	= "x";
		[Enum.NormalId.Right]	= "x";
		[Enum.NormalId.Top]		= "y";
	}

	local FFXZ = {
		[Enum.FormFactor.Symmetric]	= 1;
		[Enum.FormFactor.Brick]		= 1;
		[Enum.FormFactor.Plate]		= 1;
		[Enum.FormFactor.Custom]	= 0.2;
		["TrussPart"]				= 2;
	}

	local FFY = {
		[Enum.FormFactor.Symmetric]	= 1;
		[Enum.FormFactor.Brick]		= 1.2;
		[Enum.FormFactor.Plate]		= 0.4;
		[Enum.FormFactor.Custom]	= 0.2;
		["TrussPart"]				= 2;
	}

	local formfactormult = {
		[Enum.NormalId.Back]	= FFXZ;
		[Enum.NormalId.Bottom]	= FFY;
		[Enum.NormalId.Front]	= FFXZ;
		[Enum.NormalId.Left]	= FFXZ;
		[Enum.NormalId.Right]	= FFXZ;
		[Enum.NormalId.Top]		= FFY;
	}

	local function GetFormFactor(object)
		if object:IsA"FormFactorPart" then
			return object.formFactor
		elseif object:IsA"TrussPart" then
			return "TrussPart"
		else
			return Enum.FormFactor.Symmetric
		end
	end

	SetFunction(
		function(face,distance)
			if type(face) ~= "string" then error("1st argument needs a string",0) end
			local stringface = {
				["back"]	= Enum.NormalId.Back;
				["bottom"]	= Enum.NormalId.Bottom;
				["front"]	= Enum.NormalId.Front;
				["left"]	= Enum.NormalId.Left;
				["right"]	= Enum.NormalId.Right;
				["top"]		= Enum.NormalId.Top;
			}
			distance = distance or 0
			face = stringface[face]

			local selection = GetFilteredSelection("BasePart")
			local fm,fs = facemult[face],facesize[face]
			local dis = distance*fm
			local fvec = facevector[face]
			for i,part in pairs(GetFilteredSelection("BasePart")) do
				local cf,sz,ff = part.CFrame,part.Size,GetFormFactor(part)
				local ffm = formfactormult[face][ff]
				local mult
				if ff == Enum.FormFactor.Custom then
					mult = dis
				else
					mult = Round(dis,ffm)
				end
				local mod = fvec*mult
				local fsize = sz[fs]
				mod = fsize + mult*fm < ffm and fvec*((ffm-fsize)*fm) or mod
				part.Size = sz + mod
				part.CFrame = cf * CFrame.new(mod*fm/2)
			end
		end
	)

	SetDescription("Resizes each selection on a specified face by a specified distance.\n'face' should be a string that represents the face resize on.\n\"top\", \"bottom\", \"front\", \"back\", \"right\", and \"left\" are valid spellings.\nCapitalization does not matter.\n'distance' is the distance to resize by.\nNote that a part's size may be rounded, depending on its FormFactor.")
	SetArgumentDoc({
		{"string";"face"};
		{"number";"distance";"0"};
	})

	Validate()
end)

ProcessElementSource(function()
	SetPluginName("SnapSize")
	SetPluginType("command")
	SetCommandName("ss")

	SetFunction(
		function(xinc,yinc,zinc)
			xinc,yinc,zinc = xinc or 0,yinc or 0,zinc or 0
			for _,object in pairs(GetFilteredSelection("BasePart")) do
				local cf = object.CFrame
				object.Size = Vector3.new(
					Round(object.Size.x,xinc),
					Round(object.Size.y,yinc),
					Round(object.Size.z,zinc)
				)
				object.CFrame = cf
			end
		end
	)

	SetDescription("Snaps the size of each selection on each axis by its repective increment.\nFor example, if 'xinc' were 1, each part's size would be snapped to the nearest 1 on the X axis.\nNote that a part's size may be rounded depending on its FormFactor.")
	SetArgumentDoc({
		{"number";"xinc";"0"};
		{"number";"yinc";"0"};
		{"number";"zinc";"0"};
	})

	Validate()
end)

ProcessElementSource(function()
	SetPluginName("CenterResize")
	SetPluginType("command")
	SetCommandName("crs")

	local facevector = {
		[Enum.NormalId.Back]	= Vector3.FromNormalId(Enum.NormalId.Back);
		[Enum.NormalId.Bottom]	= Vector3.FromNormalId(Enum.NormalId.Bottom);
		[Enum.NormalId.Front]	= Vector3.FromNormalId(Enum.NormalId.Front);
		[Enum.NormalId.Left]	= Vector3.FromNormalId(Enum.NormalId.Left);
		[Enum.NormalId.Right]	= Vector3.FromNormalId(Enum.NormalId.Right);
		[Enum.NormalId.Top]		= Vector3.FromNormalId(Enum.NormalId.Top);
	}
	local facemult = {
		[Enum.NormalId.Back]	=  1;
		[Enum.NormalId.Bottom]	= -1;
		[Enum.NormalId.Front]	= -1;
		[Enum.NormalId.Left]	= -1;
		[Enum.NormalId.Right]	=  1;
		[Enum.NormalId.Top]		=  1;
	}
	local facesize = {
		[Enum.NormalId.Back]	= "z";
		[Enum.NormalId.Bottom]	= "y";
		[Enum.NormalId.Front]	= "z";
		[Enum.NormalId.Left]	= "x";
		[Enum.NormalId.Right]	= "x";
		[Enum.NormalId.Top]		= "y";
	}

	local FFXZ = {
		[Enum.FormFactor.Symmetric]	= 1;
		[Enum.FormFactor.Brick]		= 1;
		[Enum.FormFactor.Plate]		= 1;
		[Enum.FormFactor.Custom]	= 0.2;
		["TrussPart"]				= 2;
	}

	local FFY = {
		[Enum.FormFactor.Symmetric]	= 1;
		[Enum.FormFactor.Brick]		= 1.2;
		[Enum.FormFactor.Plate]		= 0.4;
		[Enum.FormFactor.Custom]	= 0.2;
		["TrussPart"]				= 2;
	}

	local formfactormult = {
		[Enum.NormalId.Back]	= FFXZ;
		[Enum.NormalId.Bottom]	= FFY;
		[Enum.NormalId.Front]	= FFXZ;
		[Enum.NormalId.Left]	= FFXZ;
		[Enum.NormalId.Right]	= FFXZ;
		[Enum.NormalId.Top]		= FFY;
	}

	local function GetFormFactor(object)
		if object:IsA"FormFactorPart" then
			return object.formFactor
		elseif object:IsA"TrussPart" then
			return "TrussPart"
		else
			return Enum.FormFactor.Symmetric
		end
	end

	SetFunction(
		function(face,distance)
			if type(face) ~= "string" then error("1st argument needs a string",0) end
			local stringface = {
				["back"]	= Enum.NormalId.Back;
				["bottom"]	= Enum.NormalId.Bottom;
				["front"]	= Enum.NormalId.Front;
				["left"]	= Enum.NormalId.Left;
				["right"]	= Enum.NormalId.Right;
				["top"]		= Enum.NormalId.Top;
			}
			distance = distance or 0
			face = stringface[face]

			local selection = GetFilteredSelection("BasePart")
			local fm,fs = facemult[face],facesize[face]
			local dis = distance*2*fm
			local fvec = facevector[face]
			for i,part in pairs(GetFilteredSelection("BasePart")) do
				local cf,sz,ff = part.CFrame,part.Size,GetFormFactor(part)
				local ffm = formfactormult[face][ff]
				local mult
				if ff == Enum.FormFactor.Custom then
					mult = dis
				else
					mult = Round(dis,ffm)
				end
				local mod = fvec*mult
				local fsize = sz[fs]
				mod = fsize + mult*fm < ffm and fvec*((ffm-fsize)*fm) or mod
				part.Size = sz + mod
				part.CFrame = cf
			end
		end
	)

	SetDescription("Resizes each selection on a specified face by a specified distance, out from the center of the selection.\n'face' should be a string that represents the face resize on.\n\"top\", \"bottom\", \"front\", \"back\", \"right\", and \"left\" are valid spellings.\nCapitalization does not matter.\n'distance' is the distance to resize by.\nNote that a part's size may be rounded, depending on its FormFactor.")
	SetArgumentDoc({
		{"string";"face"};
		{"number";"distance";"0"};
	})

	Validate()
end)

ProcessElementSource(function()
	SetPluginName("Size")
	SetPluginType("command")
	SetCommandName("s")

	SetFunction(
		function(x,y,z)
			x,y,z = x or 0,y or 0,z or 0
			for _,object in pairs(GetFilteredSelection("BasePart")) do
				local cf = object.CFrame
				object.Size = Vector3.new(x,y,z)
				object.CFrame = cf
			end
		end
	)

	SetDescription("Directly sets the size of each selection.\n'x', 'y', and 'z' represent their respective size axes on a part.\n")
	SetArgumentDoc({
		{"number";"x";"0"};
		{"number";"y";"0"};
		{"number";"z";"0"};
	})

	Validate()
end)

ProcessElementSource(function()
	SetPluginName("JoinWeld")
	SetPluginType("command")
	SetCommandName("jw")

	SetFunction(
		function(type)
			type = type or "Motor6D"
			local selection = GetFilteredSelection("BasePart")
			if #selection > 1 then
				local x = table.remove(selection,1)
				local c = CFrame.new(x.Position)
				local xcf = x.CFrame:toObjectSpace(c)
				for _,y in pairs(selection) do
					local w = Instance.new(type)
					w.Part0 = x
					w.Part1 = y
					w.C0 = xcf
					w.C1 = y.CFrame:toObjectSpace(c)
					w.Parent = x
				end
			elseif #selection > 0 then
				error("not enough valid selections",0)
			else
				error("no valid selections",0)
			end
		end
	)

	SetDescription("Welds each selection to the first selection using a specified joint.\n'type' can be the ClassName of any Instance that inherits from the JointInstance, as long as it's instancable.\n'type' is case-sensitive.")
	SetArgumentDoc({
		{"string";"type";"Motor6D"};
	})

	Validate()
end)

ProcessElementSource(function()
	SetPluginName("BreakWeld")
	SetPluginType("command")
	SetCommandName("bw")

	SetFunction(
		function(type)
			type = type or "Motor6D"
			local selection = GetFilteredSelection("BasePart")
			if #selection > 0 then
				local part = table.remove(selection,1)
				local joints = {}
				for _,joint in pairs(part:GetChildren()) do
					if joint.className == type then
						table.insert(joints,joint)
					end
				end
				if #selection > 0 then
					local joined = {}
					for i,v in pairs(selection) do
						joined[v] = true
					end
					for _,joint in pairs(joints) do
						if joined[joint.Part1] then
							joint:Remove()
						end
					end
				else
					local joint = joints[#joints]
					if joint then
						joint:Remove()
					end
				end
			else
				error("no valid selections",0)
			end
		end
	)

	SetDescription("Removes joints, depending on how many parts are selected.\nIf multiple parts are selected, then any joints of any involved parts, and of 'type', are removed.\nThat is, if a joint in the first selection is joined with another selected part, that joint is removed.\nIn other words, a reverse of the JoinWeld command occurs.\nIf only one part is selected, then the last weld of 'type' found, is removed from that part.")
	SetArgumentDoc({
		{"string";"type";"Motor6D"};
	})

	Validate()
end)

ProcessElementSource(function()
	SetPluginName("Scale")
	SetPluginType("command")
	SetCommandName("sc")

	SetFunction(
		function(factor)
			local function RecurseScale(object,factor,center)
				if object:IsA"BasePart" then
					if object:IsA"FormFactorPart" then
						object.formFactor = "Custom"
					end
					local cf = center:toObjectSpace(object.CFrame)
					object.Size = object.Size*factor
					object.CFrame = center:toWorldSpace(cf + cf.p * (factor - 1))
				elseif object:IsA"DataModelMesh" then
					object.Offset = object.Offset * factor
					if object:IsA"FileMesh" then
						if object:IsA"SpecialMesh" then
							if object.MeshType == Enum.MeshType.FileMesh then
								object.Scale = object.Scale * factor
							end
						else
							object.Scale = object.Scale * factor
						end
					elseif object:IsA"BevelMesh" then
						object.Bevel = object.Bevel * factor
					end
				elseif object:IsA"Texture" then
					object.StudsPerTileU = object.StudsPerTileU * factor
					object.StudsPerTileV = object.StudsPerTileV * factor
				end	
				for _,child in pairs(object:GetChildren()) do
					RecurseScale(child,factor,center)
				end
			end
			local selection = GetSelection()
			local parts = GetFilteredSelection("BasePart")
			if #parts > 0 then
				local center = CFrame.new(GetMidpoint(parts))
				local model = Instance.new("Model",workspace)
				model.Name = "ScaledModel"
				for _,object in pairs(selection) do
					local new = object:Clone()
					RecurseScale(new,factor,center)
					new.Parent = model
				end
			else
				error("no valid selections",0)
			end
		end
	)

	SetDescription("Copies then scales the entire selection as a group by a specified factor.\n'factor' is a number that scales the selection up or down.\nFor example, if the factor were 0.5, then the result would be half the size.\nIf the factor were 2, then the result would be twice the size.")
	SetArgumentDoc({
		{"number";"factor";"1"};
	})

	Validate()
end)

ProcessElementSource(function()
	SetPluginName("Slope")
	SetPluginType("command")
	SetCommandName("sl")

	SetFunction(
		function()
			local selection = GetFilteredSelection("BasePart")
			if #selection > 2 then
				local p1 = table.remove(selection,2)
				local p0 = table.remove(selection,1)
				for _,part in pairs(selection) do
					part.CFrame = CFrame.new(part.CFrame.p,part.CFrame.p+(p1.CFrame.p-p0.CFrame.p))
				end
			elseif #selection > 1 then
				error("not enough valid selections",0)
			elseif #selection > 0 then
				error("invalid second selection",0)
			else
				error("invalid first selection",0)
			end
		end
	)

	SetDescription("Rotates the selection by using the slope between the first and second selections.\nThe first and second selected parts are used as points.\nThe rest of the selection will then be rotated to the slope between those two points. Their positions remain the same.")

	Validate()
end)
ProcessElementSource(function()
	SetPluginName("Midpoint")
	SetPluginType("command")
	SetCommandName("mp")

	SetFunction(
		function()
			local selection = GetFilteredSelection("BasePart")
			if #selection > 1 then
				local center = table.remove(selection,1)
				center.CFrame = (center.CFrame-center.CFrame.p) + GetMidpoint(selection)
			elseif #selection > 0 then
				error("not enough valid selections",0)	
			else
				error("no valid selections",0)
			end
		end
	)

	SetDescription("Moves the first selection to the center of the rest of the selection.\nThe part's rotation is not affected.")

	Validate()
end)

ProcessElementSource(function()
	SetPluginName("Skew")
	SetPluginType("command")
	SetCommandName("sk")

	SetFunction(
		function(x,y,z,precision)
			x,y,z,precision = x or 0,y or 0,z or 0, precision or 1
			x,y,z = math.rad(x*precision),math.rad(y*precision),math.rad(z*precision)
			for _,object in pairs(GetFilteredSelection("BasePart")) do
				object.CFrame = object.CFrame * CFrame.Angles(
					math.random(-x,x)/precision,
					math.random(-y,y)/precision,
					math.random(-z,z)/precision
				)
			end
		end
	)

	SetDescription("Rotates each selection with random angles.\n'x', 'y', and 'z' represent the maximum possible amount to skew by on each axis.\n'precision' represents the number of decimal places possible.\n(1 yields results like 0 or 1, 100 yields results like 0.01 or 0.99)")
	SetArgumentDoc({
		{"number";"x";"0"};
		{"number";"y";"0"};
		{"number";"z";"0"};
		{"number";"precision";"1"};
	})

	Validate()
end)

-- Start!
GetPluginSources()
InitializePanel()
InitializeCommands()

-- All done!
print("CmdUtl v"..version.." loaded")

end)

