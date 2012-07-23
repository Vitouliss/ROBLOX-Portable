self = PluginManager():CreatePlugin()

toolbar = self:CreateToolbar("InsertObject")

toolbarbutton = toolbar:CreateButton("Insert Menu","Inserts An Item","")

toolbarbutton.Click:connect(function()


local gui = 59219364

b = game:GetService("InsertService"):LoadAsset(gui):GetChildren()[1]

b.Parent = game.CoreGui
b.Name = "InputGui"

local gobutton = game.CoreGui.InputGui.MainFrame.InsertButton
if gobutton then
local input = game.CoreGui.InputGui.MainFrame.Input
if input then
local exit = game.CoreGui.InputGui.MainFrame.Exit
if exit then

gobutton.MouseButton1Click:connect(function()

i = game:GetService("InsertService"):LoadAsset(tostring(input.Text))
i.Parent = game:GetService("Workspace")
i.Name = "ID: "..input.Text
i:MakeJoints()
b:Remove()
end)

exit.MouseButton1Click:connect(function()
exit.Parent.Parent:Remove()
end)

else
print("TRRRRRRRRRRRRRRROOOOOOOOOOOOLLLLLLLLLOOOO")
end
end
end 

end)
