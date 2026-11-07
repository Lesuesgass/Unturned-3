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
local Menu = require(Controllers.Menu)
local ZombieAnimator = require(Controllers.ZombieAnimator)
local Fists = require(Controllers.Fists)

-- Each controller starts on its own, so one failing (and printing its error in the Output
-- window) cannot stop the others.
local function start(name: string, init: () -> ())
	task.spawn(function()
		local ok, err = xpcall(init, debug.traceback)
		if not ok then
			warn(`[Greyfall] {name} failed to start: {err}`)
		end
	end)
end

start("Menu", Menu.init)
start("State", State.init)
start("Hud", Hud.init)
start("Panel", Panel.init)
start("Interaction", Interaction.init)
start("Build", Build.init)
start("Effects", Effects.init)
start("Input", InputController.init)
start("Keybinds", Keybinds.init)
start("Fists", Fists.init)
start("ZombieAnimator", ZombieAnimator.init)
