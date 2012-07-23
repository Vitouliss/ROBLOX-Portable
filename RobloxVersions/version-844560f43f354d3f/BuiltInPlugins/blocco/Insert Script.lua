local teleporter = PluginManager():CreatePlugin();
teleporter.Name = "TELEPORTER_PLUGIN";
local tb = teleporter:CreateToolbar("teleporter_toolbar");
local btn = tb:CreateButton("Teleport Menu", "", "")

local x;repeat wait()x = game:GetService("InsertService"):LoadAsset(59180480)until x

x = x.ScreenGui.Frame;
x.Parent.Parent = game.CoreGui;

x.Position = UDim2.new(0.5, -130, 0, -110);
x.Launch.MouseButton1Click:connect(function()
if tonumber(x.FakeInput.PlaceIDInput.Text) then
game:GetService("TeleportService"):TeleportImpl(x.FakeInput.PlaceIDInput.Text, "");
end
end)

local on = false;
local locked = false;

btn.Click:connect(function()

if locked then return end;
if on then
locked = true;
btn:SetActive(false)
x:TweenPosition(UDim2.new(0.5, -130, 0, -110), Enum.EasingDirection.In, Enum.EasingStyle.Back, 0.6)
wait(0.6)
on = false;
locked = false;
else
locked = true;
btn:SetActive(true)
x:TweenPosition(UDim2.new(0.5, -130, 0, 10), Enum.EasingDirection.Out, Enum.EasingStyle.Back, 0.6)
wait(0.6)
on = true;
locked = false;
end

end)