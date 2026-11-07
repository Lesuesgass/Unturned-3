-- Client entry point.

local StarterGui = game:GetService("StarterGui")

-- The game draws its own hotbar and health bar.
local function hideCoreGui()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
end
if not pcall(hideCoreGui) then
	task.delay(1, hideCoreGui)
end

local Controllers = script.Parent.Controllers
local State = require(Controllers.State)
local Hud = require(Controllers.Hud)
local Panel = require(Controllers.Panel)
local Interaction = require(Controllers.Interaction)
local Build = require(Controllers.Build)
local Effects = require(Controllers.Effects)
local InputController = require(Controllers.Input)
local Keybinds = require(Controllers.Keybinds)

State.init()
Hud.init()
Panel.init()
Interaction.init()
Build.init()
Effects.init()
InputController.init()
Keybinds.init()
