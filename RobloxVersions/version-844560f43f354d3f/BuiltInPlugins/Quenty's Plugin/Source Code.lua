local Active = false
local SG
local TB

PluginManager()
:CreatePlugin()
:CreateToolbar("Chat toolbar")
:CreateButton(
"Enable Chat",
"Click on this button to enable chat in studio.",
""
).Click:connect(function()
if not Active then
Active = true
CoreGui = game:GetService("CoreGui")
SG = Instance.new("ScreenGui",CoreGui)
SG.Name = "ChatterGui"
TB = Instance.new("TextBox",SG)
TB.BackgroundColor = BrickColor.new("Really black")
TB.BackgroundTransparency = 0.3
TB.TextColor3 = Color3.new(1,1,1)
TB.Size = UDim2.new(1,0,0,15)
TB.Position = UDim2.new(0,0,1,-15)
TB.BorderSizePixel = 0
TB.Name = "Chatbox"
TB.FontSize = "Size8"
TB.Text = [==[To chat click her or press the "/" key]==]
TB.TextXAlignment = "Left"
game:GetService("GuiService"):AddSpecialKey(Enum.SpecialKey.ChatHotkey)
game:GetService("GuiService").SpecialKeyPressed:connect(function(k)
if k.Name == "ChatHotkey" then
TB:CaptureFocus()
end
end)

TB.FocusLost:connect(function(EnterPressed)
if EnterPressed and TB.Text ~= "" then
TB.ClearTextOnFocus = true
NetworkServer = game:GetService("NetworkServer")
NetworkServer.archivable = false
coroutine.resume(coroutine.create(function() game:GetService("Players"):Chat(TB.Text) end))
else
TB.ClearTextOnFocus = false
end
TB.Text = [==[To chat click her or press the "/" key]==]
end)

else
SG:Destroy()
Active = false
end
end)