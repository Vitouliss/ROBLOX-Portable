self = PluginManager():CreatePlugin()

toolbar = self:CreateToolbar("InsertObject")

toolbarbutton = toolbar:CreateButton("TStudio","Toggles Studio","")

toolbarbutton.Click:connect(function()

local k = '.'; game:GetService("GuiService"):AddKey(k); game:GetService("GuiService").KeyPressed:connect(function(key) if key==k then game:ToggleTools() end end) local button = Instance.new("TextButton", game:GetService("CoreGui").RobloxGui) button.Name = "StudioButton"; button.Text = "Toggle Studio"; button.Size = UDim2.new(0.1,0,0.05,0); button.Position = UDim2.new(0.45,0,0,0); button:SetVerb("TogglePlayMode")

end)

